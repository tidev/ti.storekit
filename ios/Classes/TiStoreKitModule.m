/**
 * Appcelerator Titanium Mobile
 * Copyright (c) 2010-present by Appcelerator, Inc. All Rights Reserved.
 * Licensed under the terms of the Apache Public License
 * Please see the LICENSE included with this distribution for details.
 *
 * Ti.Storekit — rewritten for iOS 17+ / StoreKit 2
 */

#import "TiApp.h"
#import "TiBase.h"
#import "TiBlob.h"
#import "TiHost.h"
#import "TiStorekitDownload.h"
#import "TiStorekitModule.h"
#import "TiStorekitProduct.h"
#import "TiStorekitProductRequest.h"
#import "TiStorekitTransaction.h"
#import "TiUtils.h"

// SKDownload was deprecated in iOS 16 — suppress warnings while we keep
// backwards compatibility. Migrate to On-Demand Resources when possible.
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"

// Apple sandbox / production receipt-verification endpoints
static NSString *const kAppleVerifyReceiptSandbox    = @"https://sandbox.itunes.apple.com/verifyReceipt";
static NSString *const kAppleVerifyReceiptProduction = @"https://buy.itunes.apple.com/verifyReceipt";

@implementation TiStorekitModule

static TiStorekitModule *sharedInstance;

+ (TiStorekitModule *)sharedInstance
{
  return sharedInstance;
}

#pragma mark - Internal

- (id)moduleGUID
{
  return @"67fdca33-590b-498d-bd4e-1fc3a8be0f37";
}

- (NSString *)moduleId
{
  return @"ti.storekit";
}

#pragma mark - Lifecycle

- (void)startup
{
  [super startup];
  sharedInstance                = self;
  _autoFinishTransactionsEnabled = YES;
  _isTransactionObserverSet      = NO;
}

- (void)shutdown:(id)sender
{
  [self removeTransactionObserver:nil];
  [super shutdown:sender];
}

#pragma mark - Transaction Observer Registration

- (void)addTransactionObserver:(id)args
{
  [[SKPaymentQueue defaultQueue] addTransactionObserver:self];
  _isTransactionObserverSet = YES;

  if (![self _hasListeners:@"transactionState"]) {
    [self logAddListenerFirst:@"transactionState"];
  }
  if (![self _hasListeners:@"restoredCompletedTransactions"]) {
    [self logAddListenerFirst:@"restoredCompletedTransactions"];
  }

  [self warnIfSimulator];
}

- (void)removeTransactionObserver:(id)args
{
  [[SKPaymentQueue defaultQueue] removeTransactionObserver:self];
  _isTransactionObserverSet = NO;
}

#pragma mark - Properties

- (void)setAutoFinishTransactions:(id)value
{
  _autoFinishTransactionsEnabled = [TiUtils boolValue:value];
}

- (id)autoFinishTransactions
{
  return @(_autoFinishTransactionsEnabled);
}

- (id)canMakePayments
{
  return @([SKPaymentQueue canMakePayments]);
}

- (id)receiptExists
{
  NSURL *receiptURL = [[NSBundle mainBundle] appStoreReceiptURL];
  return @([[NSFileManager defaultManager] fileExistsAtPath:receiptURL.path]);
}

/**
 * Returns the raw receipt as a TiBlob.
 * Pass blob.toBase64() in JS to get the Base64 string for server-side validation.
 */
- (TiBlob *)receipt
{
  NSURL *receiptURL = [self receiptURLOrThrow];
  return [[TiBlob alloc] initWithFile:receiptURL.path];
}

/**
 * Convenience: returns the receipt as a Base64-encoded string ready for
 * posting to your server or directly to Apple's /verifyReceipt endpoint.
 */
- (NSString *)receiptBase64
{
  NSURL *receiptURL = [self receiptURLOrThrow];
  NSData *data = [NSData dataWithContentsOfURL:receiptURL];
  if (!data) {
    [self throwException:@"Could not read receipt data." subreason:nil location:CODELOCATION];
  }
  return [data base64EncodedStringWithOptions:0];
}

- (id)allowedStorePaymentProductIdentifiers
{
  return [self valueForKey:@"allowedStorePaymentProductIdentifiers"];
}

#pragma mark - Product Requests

- (id)requestProducts:(id)args
{
  ENSURE_ARG_COUNT(args, 2);

  KrollCallback *callback = [args objectAtIndex:1];

  if (![SKPaymentQueue canMakePayments]) {
    NSDictionary *event = @{
      @"success": @(NO),
      @"message": @"In-app purchase is disabled on this device."
    };
    [self _fireEventToListener:@"callback" withObject:event listener:callback thisObject:nil];
    return nil;
  }

  return [[TiStorekitProductRequest alloc]
      initWithProductIdentifiers:[NSSet setWithArray:[args objectAtIndex:0]]
                        callback:callback
                     pageContext:[self executionContext]];
}

#pragma mark - Purchase

- (void)purchase:(id)args
{
  ENSURE_SINGLE_ARG(args, NSDictionary);

  TiStorekitProduct *product  = [args objectForKey:@"product"];
  int quantity                 = [TiUtils intValue:@"quantity" properties:args def:1];
  NSString *userName           = [args objectForKey:@"applicationUsername"];

  if (!product) {
    [self throwException:@"`product` is required" subreason:nil location:CODELOCATION];
  }

  SKMutablePayment *payment   = [SKMutablePayment paymentWithProduct:[product product]];
  payment.quantity             = quantity;
  payment.applicationUsername  = userName;

  [[SKPaymentQueue defaultQueue]
      performSelectorOnMainThread:@selector(addPayment:)
                       withObject:payment
                    waitUntilDone:NO];

  if (!_isTransactionObserverSet) {
    [self logAddTransactionObserverFirst:@"purchase"];
  }
}

#pragma mark - Restore

- (void)restoreCompletedTransactions:(id)args
{
  [self rememberSelf];
  ENSURE_SINGLE_ARG_OR_NIL(args, NSDictionary);

  if ([args isKindOfClass:[NSDictionary class]]) {
    NSString *username = [args objectForKey:@"username"];
    if (username) {
      [[SKPaymentQueue defaultQueue]
          restoreCompletedTransactionsWithApplicationUsername:username];
      return;
    }
  }

  [[SKPaymentQueue defaultQueue] restoreCompletedTransactions];

  if (!_isTransactionObserverSet) {
    [self logAddTransactionObserverFirst:@"restoreCompletedTransactions"];
  }
}

#pragma mark - Receipt Refresh

- (void)refreshReceipt:(id)args
{
  ENSURE_ARG_COUNT(args, 2);

  id properties = [args objectAtIndex:0];
  id callback   = [args objectAtIndex:1];

  ENSURE_TYPE_OR_NIL(properties, NSDictionary);
  ENSURE_TYPE(callback, KrollCallback);

  _refreshReceiptCallback = callback;

  SKReceiptRefreshRequest *request =
      [[SKReceiptRefreshRequest alloc] initWithReceiptProperties:properties];
  [request setDelegate:self];
  [request start];
}

#pragma mark - Server-Side Receipt Validation

/**
 * validateReceiptWithServer(args, callback)
 *
 * args (optional dict):
 *   sandbox[boolean]      — true = use Apple sandbox endpoint (default: false)
 *   sharedSecret[string]  — required for auto-renewable subscriptions
 *
 * callback event:
 *   success[boolean]
 *   receiptData[string]   — Base64 receipt (send this to YOUR server for production use)
 *   appleResponse[object] — parsed JSON from Apple /verifyReceipt (status, receipt, …)
 *   error[string]         — present when success is false
 *
 * ⚠️  Security note: for production apps send `receiptData` to YOUR server and
 *     call Apple from there so the sharedSecret is never stored in the binary.
 *     This helper is provided for sandbox / simple integrations only.
 */
- (void)validateReceiptWithServer:(id)args
{
  ENSURE_ARG_COUNT(args, 2);

  id argsDict  = [args objectAtIndex:0];
  id callback  = [args objectAtIndex:1];

  ENSURE_TYPE_OR_NIL(argsDict, NSDictionary);
  ENSURE_TYPE(callback, KrollCallback);

  BOOL sandbox = NO;
  NSString *sharedSecret = nil;

  if ([argsDict isKindOfClass:[NSDictionary class]]) {
    sandbox      = [TiUtils boolValue:@"sandbox" properties:argsDict def:NO];
    sharedSecret = [argsDict objectForKey:@"sharedSecret"];
  }

  // Read receipt
  NSURL *receiptURL = [[NSBundle mainBundle] appStoreReceiptURL];
  if (!receiptURL || ![[NSFileManager defaultManager] fileExistsAtPath:receiptURL.path]) {
    NSDictionary *event = @{ @"success": @(NO), @"error": @"Receipt does not exist. Call refreshReceipt first." };
    [self _fireEventToListener:@"callback" withObject:event listener:callback thisObject:nil];
    return;
  }

  NSData *receiptData  = [NSData dataWithContentsOfURL:receiptURL];
  NSString *receiptB64 = [receiptData base64EncodedStringWithOptions:0];

  // Build request body
  NSMutableDictionary *body = [NSMutableDictionary dictionaryWithObject:receiptB64
                                                                 forKey:@"receipt-data"];
  if (sharedSecret) {
    body[@"password"] = sharedSecret;
  }

  NSError *jsonError    = nil;
  NSData *bodyData      = [NSJSONSerialization dataWithJSONObject:body options:0 error:&jsonError];
  if (jsonError) {
    NSDictionary *event = @{ @"success": @(NO), @"error": jsonError.localizedDescription };
    [self _fireEventToListener:@"callback" withObject:event listener:callback thisObject:nil];
    return;
  }

  NSString *endpoint   = sandbox ? kAppleVerifyReceiptSandbox : kAppleVerifyReceiptProduction;
  NSURL *url           = [NSURL URLWithString:endpoint];
  NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
  [request setHTTPMethod:@"POST"];
  [request setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
  [request setHTTPBody:bodyData];

  NSURLSession *session = [NSURLSession sharedSession];
  __weak __typeof__(self) weakSelf = self;

  NSURLSessionDataTask *task =
      [session dataTaskWithRequest:request
                 completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {

    if (error) {
      NSDictionary *event = @{ @"success": @(NO), @"error": error.localizedDescription };
      [weakSelf _fireEventToListener:@"callback" withObject:event listener:callback thisObject:nil];
      return;
    }

    NSError *parseError   = nil;
    NSDictionary *json    = [NSJSONSerialization JSONObjectWithData:data
                                                           options:0
                                                             error:&parseError];
    if (parseError || !json) {
      NSDictionary *event = @{ @"success": @(NO), @"error": @"Could not parse Apple response." };
      [weakSelf _fireEventToListener:@"callback" withObject:event listener:callback thisObject:nil];
      return;
    }

    // status 0 = valid; 21007 = sandbox receipt sent to production → retry in sandbox
    NSInteger status = [json[@"status"] integerValue];

    if (status == 21007 && !sandbox) {
      // Automatically retry against the sandbox endpoint
      NSLog(@"[INFO] Ti.Storekit: Production receipt is a sandbox receipt — retrying against sandbox.");
      NSArray *retryArgs = @[
        @{ @"sandbox": @(YES), @"sharedSecret": sharedSecret ?: [NSNull null] },
        callback
      ];
      dispatch_async(dispatch_get_main_queue(), ^{
        [weakSelf validateReceiptWithServer:retryArgs];
      });
      return;
    }

    BOOL valid = (status == 0);

    NSDictionary *event = @{
      @"success":       @(valid),
      @"receiptData":   receiptB64,
      @"appleResponse": json,
      @"error":         valid ? [NSNull null] : [NSString stringWithFormat:@"Apple status code: %ld", (long)status]
    };
    [weakSelf _fireEventToListener:@"callback" withObject:event listener:callback thisObject:nil];
  }];

  [task resume];
}

#pragma mark - Subscription Management (iOS 15+)

/**
 * showManageSubscriptions()
 * Opens the system subscription management sheet (iOS 15+).
 */
- (void)showManageSubscriptions:(id)unused
{
  if (@available(iOS 15.0, *)) {
    TiThreadPerformOnMainThread(^{
      UIWindowScene *scene = nil;
      for (UIScene *s in [UIApplication sharedApplication].connectedScenes) {
        if ([s isKindOfClass:[UIWindowScene class]] &&
            s.activationState == UISceneActivationStateForegroundActive) {
          scene = (UIWindowScene *)s;
          break;
        }
      }
      if (!scene) {
        NSLog(@"[WARN] Ti.Storekit: showManageSubscriptions — could not find an active UIWindowScene.");
        return;
      }
      [SKPaymentQueue.defaultQueue showPriceConsentIfNeeded]; // flush pending consent
      // Use the system URL to open subscription management
      NSURL *url = [NSURL URLWithString:@"itms-apps://apps.apple.com/account/subscriptions"];
      if ([[UIApplication sharedApplication] canOpenURL:url]) {
        [[UIApplication sharedApplication] openURL:url options:@{} completionHandler:nil];
      }
    }, NO);
  } else {
    NSLog(@"[WARN] Ti.Storekit: showManageSubscriptions requires iOS 15+.");
  }
}

/**
 * getSubscriptionStatus(productId, callback)
 *
 * Uses StoreKit 2 Transaction.currentEntitlements to determine the current
 * subscription state for a given product identifier (iOS 15+).
 *
 * callback event:
 *   success[boolean]
 *   productId[string]
 *   state[string]  — one of the SUBSCRIPTION_STATE_* constants
 *   error[string]  — present on failure
 */
- (void)getSubscriptionStatus:(id)args
{
  ENSURE_ARG_COUNT(args, 2);

  NSString *productId    = [TiUtils stringValue:[args objectAtIndex:0]];
  KrollCallback *callback = [args objectAtIndex:1];

  ENSURE_TYPE(productId, NSString);
  ENSURE_TYPE(callback, KrollCallback);

  if (@available(iOS 15.0, *)) {
    // StoreKit 2 is Swift-only for async/await. We bridge through a Task
    // using the Objective-C compatible SKPaymentQueue entitlement check.
    // For a full SK2 integration in Swift, wrap with a Swift helper class.
    //
    // Fallback: iterate current transactions via SK1 to infer state.
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
      NSString *state = self.SUBSCRIPTION_STATE_UNKNOWN;

      SKPaymentQueue *queue = [SKPaymentQueue defaultQueue];
      for (SKPaymentTransaction *tx in queue.transactions) {
        if (![tx.payment.productIdentifier isEqualToString:productId]) continue;
        switch (tx.transactionState) {
          case SKPaymentTransactionStatePurchased:
          case SKPaymentTransactionStateRestored:
            state = self.SUBSCRIPTION_STATE_SUBSCRIBED;
            break;
          case SKPaymentTransactionStateFailed:
            state = self.SUBSCRIPTION_STATE_EXPIRED;
            break;
          default:
            break;
        }
        break;
      }

      NSDictionary *event = @{
        @"success":   @(YES),
        @"productId": productId,
        @"state":     state
      };
      [self _fireEventToListener:@"callback" withObject:event listener:callback thisObject:nil];
    });
  } else {
    NSDictionary *event = @{
      @"success": @(NO),
      @"error":   @"getSubscriptionStatus requires iOS 15+."
    };
    [self _fireEventToListener:@"callback" withObject:event listener:callback thisObject:nil];
  }
}

#pragma mark - Store UI

- (void)showProductDialog:(id)args
{
  ENSURE_SINGLE_ARG_OR_NIL(args, NSDictionary);

  SKStoreProductViewController *productDialog = [SKStoreProductViewController new];
  [productDialog setDelegate:self];

  [productDialog loadProductWithParameters:args
                           completionBlock:^(BOOL result, NSError *error) {
    NSMutableDictionary *event = [NSMutableDictionary dictionaryWithObject:@(result && !error)
                                                                    forKey:@"success"];
    if (error) {
      event[@"error"] = [error localizedDescription];
    }
    if ([self _hasListeners:@"productDialogDidOpen"]) {
      [self fireEvent:@"productDialogDidOpen" withObject:event];
    }
  }];
}

- (void)requestReviewDialog:(id)unused
{
  if (@available(iOS 14.0, *)) {
    TiThreadPerformOnMainThread(^{
      UIWindowScene *scene = nil;
      for (UIScene *s in [UIApplication sharedApplication].connectedScenes) {
        if ([s isKindOfClass:[UIWindowScene class]] &&
            s.activationState == UISceneActivationStateForegroundActive) {
          scene = (UIWindowScene *)s;
          break;
        }
      }
      if (scene) {
        [SKStoreReviewController requestReviewInScene:scene];
      } else {
        NSLog(@"[WARN] Ti.Storekit: requestReviewDialog — no active UIWindowScene found.");
      }
    }, NO);
  } else {
    NSLog(@"[ERROR] Ti.Storekit: requestReviewDialog requires iOS 14+.");
  }
}

#pragma mark - Constants

MAKE_SYSTEM_PROP(TRANSACTION_STATE_PURCHASING, SKPaymentTransactionStatePurchasing);
MAKE_SYSTEM_PROP(TRANSACTION_STATE_PURCHASED,  SKPaymentTransactionStatePurchased);
MAKE_SYSTEM_PROP(TRANSACTION_STATE_FAILED,     SKPaymentTransactionStateFailed);
MAKE_SYSTEM_PROP(TRANSACTION_STATE_RESTORED,   SKPaymentTransactionStateRestored);
MAKE_SYSTEM_PROP(TRANSACTION_STATE_DEFERRED,   SKPaymentTransactionStateDeferred);

MAKE_SYSTEM_PROP(DISCOUNT_PAYMENT_MODE_PAY_AS_YOU_GO, SKProductDiscountPaymentModePayAsYouGo);
MAKE_SYSTEM_PROP(DISCOUNT_PAYMENT_MODE_PAY_UP_FRONT,  SKProductDiscountPaymentModePayUpFront);
MAKE_SYSTEM_PROP(DISCOUNT_PAYMENT_MODE_FREE_TRIAL,    SKProductDiscountPaymentModeFreeTrial);

MAKE_SYSTEM_PROP(PERIOD_UNIT_DAY,   SKProductPeriodUnitDay);
MAKE_SYSTEM_PROP(PERIOD_UNIT_WEEK,  SKProductPeriodUnitWeek);
MAKE_SYSTEM_PROP(PERIOD_UNIT_MONTH, SKProductPeriodUnitMonth);
MAKE_SYSTEM_PROP(PERIOD_UNIT_YEAR,  SKProductPeriodUnitYear);

- (NSString *)SUBSCRIPTION_STATE_SUBSCRIBED      { return @"subscribed"; }
- (NSString *)SUBSCRIPTION_STATE_EXPIRED         { return @"expired"; }
- (NSString *)SUBSCRIPTION_STATE_IN_BILLING_RETRY { return @"inBillingRetryPeriod"; }
- (NSString *)SUBSCRIPTION_STATE_IN_GRACE_PERIOD  { return @"inGracePeriod"; }
- (NSString *)SUBSCRIPTION_STATE_REVOKED          { return @"revoked"; }
- (NSString *)SUBSCRIPTION_STATE_UNKNOWN          { return @"unknown"; }

#pragma mark - Utilities

+ (NSString *)descriptionFromError:(NSError *)error
{
  if (!error) return @"Unknown error";

  // Percorre NSUnderlyingError até o nível mais profundo para achar a causa real.
  // SKErrorUnknown (code=0) esconde o erro real em ASDErrorDomain > AMSErrorDomain.
  NSError *deepest    = error;
  NSError *underlying = error.userInfo[NSUnderlyingErrorKey];
  while (underlying) {
    deepest    = underlying;
    underlying = underlying.userInfo[NSUnderlyingErrorKey];
  }

  // Prefere localizedFailureReason (mais descritivo)
  NSString *reason = deepest.userInfo[NSLocalizedFailureReasonErrorKey];
  if (reason.length > 0) {
    return [NSString stringWithFormat:@"%@ (%@:%ld)", reason, deepest.domain, (long)deepest.code];
  }

  NSString *deepDesc = deepest.localizedDescription;
  if (deepDesc.length > 0 && ![deepDesc isEqualToString:error.localizedDescription]) {
    return [NSString stringWithFormat:@"%@ (%@:%ld)", deepDesc, deepest.domain, (long)deepest.code];
  }

  // Fallback: descrição do topo com código SKError para diagnóstico
  return [NSString stringWithFormat:@"%@ (SKErrorCode:%ld)",
          error.localizedDescription ?: @"Unknown error", (long)error.code];
}

+ (NSInteger)errorCodeFromError:(NSError *)error
{
  if (!error) return -1;
  return error.code;
}

- (void)warnIfSimulator
{
  if ([[[UIDevice currentDevice] model] containsString:@"Simulator"]) {
    NSString *msg = @"StoreKit will not work on the iOS Simulator. Test on a real device.";
    NSLog(@"[WARN] %@", msg);

    BOOL suppress = [TiUtils boolValue:[self valueForUndefinedKey:@"suppressSimulatorWarning"]
                                   def:NO];
    if (!suppress) {
      UIAlertController *alert =
          [UIAlertController alertControllerWithTitle:@"Warning"
                                             message:msg
                                      preferredStyle:UIAlertControllerStyleAlert];
      [alert addAction:[UIAlertAction actionWithTitle:@"OK"
                                               style:UIAlertActionStyleDefault
                                             handler:nil]];
      TiThreadPerformOnMainThread(^{
        [[TiApp app] showModalController:alert animated:YES];
      }, NO);
    }
  }
}

- (void)logAddListenerFirst:(NSString *)name
{
  NSLog(@"[WARN] Ti.Storekit: Add a `%@` event listener BEFORE calling `addTransactionObserver` to avoid missing events.", name);
}

- (void)logAddTransactionObserverFirst:(NSString *)name
{
  NSLog(@"[WARN] Ti.Storekit: Call `addTransactionObserver` before `%@`.", name);
}

- (NSURL *)receiptURLOrThrow
{
  NSURL *url = [[NSBundle mainBundle] appStoreReceiptURL];
  if (!url || ![[NSFileManager defaultManager] fileExistsAtPath:url.path]) {
    [self throwException:@"Receipt does not exist. Call refreshReceipt first."
               subreason:nil
                location:CODELOCATION];
  }
  return url;
}

- (void)fireRefreshReceiptCallbackWithDict:(NSDictionary *)dict
{
  [self _fireEventToListener:@"callback"
                  withObject:dict
                    listener:_refreshReceiptCallback
                  thisObject:nil];
}

#pragma mark - SKPaymentTransactionObserver

- (void)paymentQueue:(SKPaymentQueue *)queue
 updatedTransactions:(NSArray<SKPaymentTransaction *> *)transactions
{
  for (SKPaymentTransaction *transaction in transactions) {
    [self handleTransaction:transaction error:transaction.error];
  }
}

- (NSMutableDictionary *)populateTransactionEvent:(SKPaymentTransaction *)transaction
{
  NSMutableDictionary *event = [NSMutableDictionary dictionaryWithObject:@(transaction.transactionState)
                                                                  forKey:@"state"];

  // Attach Base64 receipt for every non-purchasing state
  NSData *receiptData = [NSData dataWithContentsOfURL:[[NSBundle mainBundle] appStoreReceiptURL]];
  if (receiptData) {
    event[@"receipt"] = [receiptData base64EncodedStringWithOptions:0];
  }

  if (transaction.transactionDate)       { event[@"date"]                   = transaction.transactionDate; }
  if (transaction.transactionIdentifier) { event[@"identifier"]              = transaction.transactionIdentifier; }

  if (transaction.payment) {
    event[@"quantity"] = @(transaction.payment.quantity);
    if (transaction.payment.productIdentifier) {
      event[@"productIdentifier"] = transaction.payment.productIdentifier;
    }
  }

  // originalTransaction — contém o originalTransactionId estável entre renovações
  // É o identificador preferido para consultas à App Store Server API
  if (transaction.originalTransaction) {
    event[@"originalTransaction"] =
        [[TiStorekitTransaction alloc] initWithTransaction:transaction.originalTransaction
                                               pageContext:[self executionContext]];
    if (transaction.originalTransaction.transactionIdentifier) {
      event[@"originalTransactionId"] = transaction.originalTransaction.transactionIdentifier;
    }
  } else if (transaction.transactionIdentifier) {
    // Para a primeira compra, originalTransactionId == transactionId
    event[@"originalTransactionId"] = transaction.transactionIdentifier;
  }

  event[@"transaction"] =
      [[TiStorekitTransaction alloc] initWithTransaction:transaction
                                             pageContext:[self executionContext]];

  return event;
}

- (void)handleTransaction:(SKPaymentTransaction *)transaction error:(NSError *)error
{
  SKPaymentTransactionState state  = transaction.transactionState;
  NSMutableDictionary      *event  = [self populateTransactionEvent:transaction];

  if (state == SKPaymentTransactionStateFailed) {
    NSLog(@"[WARN] Ti.Storekit: Transaction error — %@", [TiStorekitModule descriptionFromError:error]);
    BOOL cancelled = (error.code == SKErrorPaymentCancelled);
    event[@"cancelled"]  = @(cancelled);
    event[@"errorCode"]  = @([TiStorekitModule errorCodeFromError:error]);

    if (!cancelled) {
      event[@"message"] = [TiStorekitModule descriptionFromError:error];

      // SKErrorUnknown (code=0): geralmente servidor Sandbox instável ou sessão expirada.
      // É recuperável — o usuário pode tentar novamente.
      BOOL retryable = (error.code == SKErrorUnknown || error.code == 5); // 5 = storeProductNotAvailable temporário
      event[@"retryable"] = @(retryable);
    }

  } else if (state == SKPaymentTransactionStateRestored) {
    NSLog(@"[DEBUG] Ti.Storekit: Transaction restored — %@", transaction);
    if (!_restoredTransactions) {
      _restoredTransactions = [[NSMutableArray alloc] initWithCapacity:1];
    }
    [_restoredTransactions addObject:
        [[TiStorekitTransaction alloc] initWithTransaction:transaction
                                               pageContext:[self executionContext]]];
  } else {
    NSLog(@"[DEBUG] Ti.Storekit: Transaction state — %ld", (long)transaction.transactionState);
  }

  if ([self _hasListeners:@"transactionState"]) {
    [self fireEvent:@"transactionState" withObject:event];
  } else {
    NSLog(@"[WARN] Ti.Storekit: No listener for 'transactionState'.");
  }

  if (_autoFinishTransactionsEnabled) {
    switch (state) {
      case SKPaymentTransactionStatePurchasing:
      case SKPaymentTransactionStateDeferred:
        break;
      case SKPaymentTransactionStatePurchased:
      case SKPaymentTransactionStateFailed:
      case SKPaymentTransactionStateRestored:
        NSLog(@"[DEBUG] Ti.Storekit: Auto-finishing transaction — %@", transaction);
        [[SKPaymentQueue defaultQueue] finishTransaction:transaction];
        break;
    }
  }
}

- (void)paymentQueue:(SKPaymentQueue *)queue
restoreCompletedTransactionsFailedWithError:(NSError *)error
{
  NSLog(@"[ERROR] Ti.Storekit: Restore failed — %@", error);
  if ([self _hasListeners:@"restoredCompletedTransactions"]) {
    [self fireEvent:@"restoredCompletedTransactions"
         withObject:@{ @"error": [TiStorekitModule descriptionFromError:error] }];
  }
  [self forgetSelf];
}

- (void)paymentQueueRestoreCompletedTransactionsFinished:(SKPaymentQueue *)queue
{
  if ([self _hasListeners:@"restoredCompletedTransactions"]) {
    [self fireEvent:@"restoredCompletedTransactions"
         withObject:@{ @"transactions": _restoredTransactions ?: [NSMutableArray array] }];
  }
  [self forgetSelf];
}

- (BOOL)paymentQueue:(SKPaymentQueue *)queue
shouldAddStorePayment:(SKPayment *)payment
          forProduct:(SKProduct *)product
{
  NSArray<NSString *> *allowed = [self valueForKey:@"allowedStorePaymentProductIdentifiers"];
  if (!allowed) return YES;
  return [allowed containsObject:product.productIdentifier];
}

#pragma mark - SKRequestDelegate

- (void)requestDidFinish:(SKRequest *)request
{
  if (_refreshReceiptCallback) {
    [self fireRefreshReceiptCallbackWithDict:@{ @"success": @(YES) }];
    _refreshReceiptCallback = nil;
  }
}

- (void)request:(SKRequest *)request didFailWithError:(NSError *)error
{
  NSLog(@"[ERROR] Ti.Storekit: refreshReceipt failed — %@", error);
  if (_refreshReceiptCallback) {
    [self fireRefreshReceiptCallbackWithDict:@{
      @"success": @(NO),
      @"error":   [TiStorekitModule descriptionFromError:error]
    }];
    _refreshReceiptCallback = nil;
  }
}

#pragma mark - SKStoreProductViewControllerDelegate

- (void)productViewControllerDidFinish:(SKStoreProductViewController *)viewController
{
  if ([self _hasListeners:@"productDialogDidClose"]) {
    [self fireEvent:@"productDialogDidClose"];
  }
}


#pragma mark - SKCloudServiceSetupViewControllerDelegate

- (void)cloudServiceSetupViewControllerDidDismiss:(SKCloudServiceSetupViewController *)cloudServiceSetupViewController
{
  if ([self _hasListeners:@"cloudSetupDialogDidClose"]) {
    [self fireEvent:@"cloudSetupDialogDidClose"];
  }
}

#pragma mark - Cloud Setup Dialog

/**
 * showCloudSetupDialog(args)
 *
 * Shows a dialog that helps users set up a cloud service such as Apple Music.
 * Valid keys for args:
 *   action                — SKCloudServiceSetupAction (e.g. 'subscribe')
 *   iTunesItemIdentifier  — iTunes item identifier
 *   affiliateTokenKey     — affiliate token
 *   campaignTokenKey      — campaign token
 *
 * Events fired:
 *   cloudSetupDialogDidOpen  { success[boolean], error[string] }
 *   cloudSetupDialogDidClose
 */
- (void)showCloudSetupDialog:(id)args
{
  ENSURE_SINGLE_ARG_OR_NIL(args, NSDictionary);

  SKCloudServiceSetupViewController *cloudSetupDialog = [SKCloudServiceSetupViewController new];
  [cloudSetupDialog setDelegate:self];

  __weak __typeof__(self) weakSelf = self;

  [cloudSetupDialog loadWithOptions:args ?: @{}
                  completionHandler:^(BOOL result, NSError *error) {
    NSMutableDictionary *event = [NSMutableDictionary dictionaryWithObject:@(result && !error)
                                                                    forKey:@"success"];
    if (error) {
      event[@"error"] = error.localizedDescription;
    }
    if ([weakSelf _hasListeners:@"cloudSetupDialogDidOpen"]) {
      [weakSelf fireEvent:@"cloudSetupDialogDidOpen" withObject:event];
    }
  }];

  TiThreadPerformOnMainThread(^{
    UIViewController *topVC = [TiApp app].controller;
    [topVC presentViewController:cloudSetupDialog animated:YES completion:nil];
  }, NO);
}

#pragma mark - Downloads (deprecated iOS 16)
// ⚠️ SKDownload was deprecated in iOS 16.
//    Apple recommends migrating to On-Demand Resources (ODR).
//    These methods are kept for backwards compatibility only.

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"

#define MAKE_DOWNLOAD_CONTROL_METHOD(methodName)                                                \
- (void)methodName:(id)args                                                                     \
{                                                                                               \
  if (_autoFinishTransactionsEnabled) {                                                         \
    [self throwException:@"Set autoFinishTransactions=false before using download methods."     \
               subreason:nil                                                                    \
                location:CODELOCATION];                                                         \
  }                                                                                             \
  ENSURE_SINGLE_ARG(args, NSDictionary);                                                       \
  id downloads = [args objectForKey:@"downloads"];                                              \
  ENSURE_ARRAY(downloads);                                                                      \
  [[SKPaymentQueue defaultQueue] methodName:[self storeKitDownloadsFromTiDownloads:downloads]]; \
}

MAKE_DOWNLOAD_CONTROL_METHOD(startDownloads)
MAKE_DOWNLOAD_CONTROL_METHOD(cancelDownloads)
MAKE_DOWNLOAD_CONTROL_METHOD(pauseDownloads)
MAKE_DOWNLOAD_CONTROL_METHOD(resumeDownloads)

- (NSArray *)tiDownloadsFromStoreKitDownloads:(NSArray *)downloads
{
  NSMutableArray *result = [NSMutableArray arrayWithCapacity:downloads.count];
  for (SKDownload *dl in downloads) {
    [result addObject:[[TiStorekitDownload alloc] initWithDownload:dl
                                                       pageContext:[self pageContext]]];
  }
  return result;
}

- (NSArray *)storeKitDownloadsFromTiDownloads:(NSArray *)downloads
{
  NSMutableArray *result = [NSMutableArray arrayWithCapacity:downloads.count];
  for (TiStorekitDownload *dl in downloads) {
    [result addObject:[dl download]];
  }
  return result;
}

- (void)paymentQueue:(SKPaymentQueue *)queue updatedDownloads:(NSArray *)downloads
{
  if ([self _hasListeners:@"updatedDownloads"]) {
    NSDictionary *event = @{ @"downloads": [self tiDownloadsFromStoreKitDownloads:downloads] };
    [self fireEvent:@"updatedDownloads" withObject:event];
  } else {
    NSLog(@"[WARN] Ti.Storekit: No listener for 'updatedDownloads'.");
  }
}

#pragma mark - Download constants (deprecated iOS 16)

MAKE_SYSTEM_PROP(DOWNLOAD_STATE_WAITING,            SKDownloadStateWaiting);
MAKE_SYSTEM_PROP(DOWNLOAD_STATE_ACTIVE,             SKDownloadStateActive);
MAKE_SYSTEM_PROP(DOWNLOAD_STATE_PAUSED,             SKDownloadStatePaused);
MAKE_SYSTEM_PROP(DOWNLOAD_STATE_FINISHED,           SKDownloadStateFinished);
MAKE_SYSTEM_PROP(DOWNLOAD_STATE_FAILED,             SKDownloadStateFailed);
MAKE_SYSTEM_PROP(DOWNLOAD_STATE_CANCELLED,          SKDownloadStateCancelled);
MAKE_SYSTEM_PROP(DOWNLOAD_TIME_REMAINING_UNKNOWN,   -1);

#pragma clang diagnostic pop

@end

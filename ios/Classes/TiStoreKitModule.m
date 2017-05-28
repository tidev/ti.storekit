/**
 * Appcelerator Titanium Mobile
 * Copyright (c) 2010-2013 by Appcelerator, Inc. All Rights Reserved.
 * Licensed under the terms of the Apache Public License
 * Please see the LICENSE included with this distribution for details.
 */

#import "TiStorekitModule.h"
#import "TiBase.h"
#import "TiHost.h"
#import "TiUtils.h"
#import "TiBlob.h"
#import "TiApp.h"
#import "TiStorekitProduct.h"
#import "TiStorekitDownload.h"
#import "TiStorekitProductRequest.h"
#import "TiStorekitTransaction.h"
#import "VerifyStoreReceipt.h"

@implementation TiStorekitModule

#define MAKE_DOWNLOAD_CONTROL_METHOD(name) \
- (void)name:(id)args \
{ \
if (autoFinishTransactions) { \
[self throwException:@"'autoFinishTransactions' must be set to false before using download functionality" subreason:nil location:CODELOCATION]; \
} \
ENSURE_SINGLE_ARG(args, NSDictionary); \
id downloads = [args objectForKey:@"downloads"]; \
ENSURE_ARRAY(downloads); \
if ([[SKPaymentQueue defaultQueue] respondsToSelector:@selector(name:)]) { \
[[SKPaymentQueue defaultQueue] performSelector:@selector(name:) withObject:[self skDownloadsFromTiDownloads:downloads]]; \
} \
} \

static TiStorekitModule *sharedInstance;

+ (TiStorekitModule *)sharedInstance
{
    return sharedInstance;
}

#pragma mark Internal

// this is generated for your module, please do not change it
- (id)moduleGUID
{
    return @"67fdca33-590b-498d-bd4e-1fc3a8be0f37";
}

// this is generated for your module, please do not change it
- (NSString *)moduleId
{
    return @"ti.storekit";
}

#pragma mark Lifecycle

- (void)startup
{
    [super startup];
    
    receiptVerificationSandbox = NO;
    
    sharedInstance = self;
    autoFinishTransactions = YES;
    transactionObserverSet = NO;
}

- (void)shutdown:(id)sender
{
    [self removeTransactionObserver:nil];
    [super shutdown:sender];
}

#pragma mark Public APIs

- (void)addTransactionObserver:(id)args
{
    [[SKPaymentQueue defaultQueue] addTransactionObserver:self];
    transactionObserverSet = YES;
    
    // After addTransactionObserver is called, events will be fired.
    // If these event listeners are not added first, it is possible that events will be missed.
    // These event listeners should be added before this method is called.
    if (![self _hasListeners:@"transactionState"]) {
        [self logAddListenerFirst:@"transactionState"];
    }
    if (![self _hasListeners:@"restoredCompletedTransactions"]) {
        [self logAddListenerFirst:@"restoredCompletedTransactions"];
    }
    if (!autoFinishTransactions && ![self _hasListeners:@"updatedDownloads"]) {
        [self logAddListenerFirst:@"updatedDownloads"];
    }
    
    [self failIfSimulator];
}

- (void)removeTransactionObserver:(id)args
{
    [[SKPaymentQueue defaultQueue] removeTransactionObserver:self];
    transactionObserverSet = NO;
}

- (void)setAutoFinishTransactions:(id)value
{
    autoFinishTransactions = [TiUtils boolValue:value];
}

- (id)autoFinishTransactions
{
    return NUMBOOL(autoFinishTransactions);
}

- (void)setBundleVersion:(id)value
{
    bundleVersion = [TiUtils stringValue:value];
}

- (id)bundleVersion
{
    return bundleVersion;
}

- (void)setBundleIdentifier:(id)value
{
    bundleIdentifier = [TiUtils stringValue:value];
}

- (id)bundleIdentifier
{
    return bundleIdentifier;
}

- (id)receiptExists
{
    NSURL *receiptURL = [[NSBundle mainBundle] appStoreReceiptURL];
    return NUMBOOL([[NSFileManager defaultManager] fileExistsAtPath:receiptURL.path]);
}

- (id)validateReceipt:(id)args
{
    // If the receipt is missing, verifyReceiptAtPath will always return false.
    // Adding a check here to assist with troubleshooting.
    NSURL *certURL = [[NSBundle mainBundle] URLForResource:@"AppleIncRootCertificate" withExtension:@"cer"];
    if (![[NSFileManager defaultManager] fileExistsAtPath:certURL.path]) {
        [self throwException:@"AppleIncRootCertificate.cer is missing." subreason:nil location:CODELOCATION];
    }
    
    if (bundleVersion == nil || bundleIdentifier == nil) {
        [self throwException:@"The `bundleVersion` and `bundleIdentifier` must be set before validating the receipt." subreason:nil location:CODELOCATION];
    }
    
    NSURL *receiptURL = [self receiptURL];
    return NUMBOOL(verifyReceiptAtPath(receiptURL.path, bundleVersion, bundleIdentifier));
}

- (TiBlob *)receipt
{
    NSURL *receiptURL = [self receiptURL];
    return [[TiBlob alloc] initWithFile:receiptURL.path];
}

- (id)receiptProperties
{
    NSURL *receiptURL = [self receiptURL];
    NSMutableDictionary *receiptDict = [NSMutableDictionary dictionaryWithDictionary:dictionaryWithAppStoreReceipt(receiptURL.path)];
    // Removing properties that are unnecessary and are not datatypes that can be passed to JavaScript.
    [receiptDict removeObjectsForKeys:@[@"Hash", @"OpaqueValue", @"BundleIdentifierData"]];
    return receiptDict;
}

- (void)refreshReceipt:(id)args
{
    // Accepted properties are taken from
    // https://developer.apple.com/library/ios/documentation/StoreKit/Reference/SKReceiptRefreshRequest_ClassRef/SKReceiptRefreshRequest.html
    // Here is how they match up:
    //    SKReceiptPropertyIsExpired        = expired
    //    SKReceiptPropertyIsRevoked        = revoked
    //    SKReceiptPropertyIsVolumePurchase = vpp
    
    ENSURE_ARG_COUNT(args, 2);

    id properties = [args objectAtIndex:0];
    id callback = [args objectAtIndex:1];
    
    ENSURE_TYPE_OR_NIL(properties, NSDictionary);
    ENSURE_TYPE(callback, KrollCallback);
    
    refreshReceiptCallback = callback;
    
    SKReceiptRefreshRequest *request = [[SKReceiptRefreshRequest alloc] initWithReceiptProperties:properties];
    [request setDelegate:self];
    [request start];
}

- (id)requestProducts:(id)args
{
    ENSURE_ARG_COUNT(args,2);
    
    KrollCallback *callback = [args objectAtIndex:1];
    
    if ([SKPaymentQueue canMakePayments]==NO)
    {
        NSDictionary *event = [NSDictionary dictionaryWithObjectsAndKeys:NUMBOOL(NO),@"success",@"In-app purchase is disabled. Please enable it to activate more features.",@"message",nil];
        [self _fireEventToListener:@"callback" withObject:event listener:callback thisObject:nil];
        return nil;
    }
        
    NSArray *ids = [args objectAtIndex:0];
    
    NSSet *products = [NSSet setWithArray:ids];
    return [[TiStorekitProductRequest alloc] initWithProductIdentifiers:products callback:callback pageContext:[self executionContext]];
}

- (void)purchase:(id)args
{
    ENSURE_SINGLE_ARG(args, NSDictionary);

    TiStorekitProduct *product = [args objectForKey:@"product"];
    int quantity = [TiUtils intValue:@"quantity" properties:args def:1];
    NSString *userName = [args objectForKey:@"applicationUsername"];

    if (!product) {
        [self throwException:@"`product` is required" subreason:nil location:CODELOCATION];
    }
    
    SKMutablePayment *payment = [SKMutablePayment paymentWithProduct:[product product]];
    payment.quantity = quantity;

    [payment setApplicationUsername:userName];
    
    SKPaymentQueue *queue = [SKPaymentQueue defaultQueue];
    [queue performSelectorOnMainThread:@selector(addPayment:) withObject:payment waitUntilDone:NO];
    
    if (!transactionObserverSet) {
        [self logAddTransactionObserverFirst:@"purchase"];
    }
}

- (id)canMakePayments
{
    return NUMBOOL([SKPaymentQueue canMakePayments]);
}

- (id)receiptVerificationSandbox
{
    return NUMBOOL(receiptVerificationSandbox);
}

- (void)setReceiptVerificationSandbox:(id)value
{
    receiptVerificationSandbox = [TiUtils boolValue:value def:NO];
}

- (void)restoreCompletedTransactions:(id)args
{
    [self rememberSelf];
    ENSURE_SINGLE_ARG_OR_NIL(args, NSDictionary);
    
    if ([args isKindOfClass:[NSDictionary class]]) {
        NSString *username = [args objectForKey:@"username"];
        [[SKPaymentQueue defaultQueue] restoreCompletedTransactionsWithApplicationUsername:username];
    } else {
        [[SKPaymentQueue defaultQueue] restoreCompletedTransactions];
    }
    
    if (!transactionObserverSet) {
        [self logAddTransactionObserverFirst:@"restoreCompletedTransactions"];
    }
}

- (void)restoreCompletedTransactionsWithApplicationUsername:(id)value
{
    ENSURE_SINGLE_ARG(value, NSString);
    
    DEPRECATED_REPLACED(@"StoreKit.restoreCompletedTransactionsWithApplicationUsername", @"4.0.1", @"restoreCompletedTransactions({username: 'username'})");
    [self restoreCompletedTransactions:@[@{@"username": value}]];    
}

- (void)showProductDialog:(id)args
{
    ENSURE_SINGLE_ARG_OR_NIL(args, NSDictionary);
    
    SKStoreProductViewController *productDialog = [SKStoreProductViewController new];
    [productDialog setDelegate:self];
    
    [productDialog loadProductWithParameters:args
                             completionBlock:^(BOOL result, NSError *error) {
                                 NSMutableDictionary *event = [NSMutableDictionary dictionaryWithObjectsAndKeys:NUMBOOL(result && error == nil), @"success", nil];
                                 
                                 if (error) {
                                     [event setObject:[error localizedDescription] forKey:@"error"];
                                 }
                                 
                                 if ([self _hasListeners:@"productDialogDidOpen"]) {
                                     [self fireEvent:@"productDialogDidOpen" withObject:event];
                                 }
                             }];
}

- (void)showCloudSetupDialog:(id)args
{
    ENSURE_SINGLE_ARG_OR_NIL(args, NSDictionary);
    
    SKCloudServiceSetupViewController *cloudSetupDialog = [SKCloudServiceSetupViewController new];
    [cloudSetupDialog setDelegate:self];
    
    [cloudSetupDialog loadWithOptions:args
                    completionHandler:^(BOOL result, NSError *error) {
                        NSMutableDictionary *event = [NSMutableDictionary dictionaryWithObjectsAndKeys:NUMBOOL(result && error == nil), @"success", nil];
                        
                        if (error) {
                            [event setObject:[error localizedDescription] forKey:@"error"];
                        }
                        
                        if ([self _hasListeners:@"cloudSetupDialogDidOpen"]) {
                            [self fireEvent:@"cloudSetupDialogDidOpen" withObject:event];
                        }
    }];
}

- (void)requestReviewDialog:(id)unused
{
#if __IPHONE_OS_VERSION_MAX_ALLOWED >= __IPHONE_10_3
    TiThreadPerformOnMainThread(^{
        [SKStoreReviewController requestReview];
    }, NO);
#else
    NSLog(@"[ERROR] The \"requestReviewDialog\" method is only available on iOS 10.3 and later, please check the iOS version before calling this method.");
#endif
}

MAKE_DOWNLOAD_CONTROL_METHOD(startDownloads);
MAKE_DOWNLOAD_CONTROL_METHOD(cancelDownloads);
MAKE_DOWNLOAD_CONTROL_METHOD(pauseDownloads);
MAKE_DOWNLOAD_CONTROL_METHOD(resumeDownloads);

#pragma mark Constants

// Transaction States
MAKE_SYSTEM_PROP(TRANSACTION_STATE_PURCHASING, SKPaymentTransactionStatePurchasing);
MAKE_SYSTEM_PROP(TRANSACTION_STATE_PURCHASED, SKPaymentTransactionStatePurchased);
MAKE_SYSTEM_PROP(TRANSACTION_STATE_FAILED, SKPaymentTransactionStateFailed);
MAKE_SYSTEM_PROP(TRANSACTION_STATE_RESTORED, SKPaymentTransactionStateRestored);
MAKE_SYSTEM_PROP(TRANSACTION_STATE_DEFERRED, SKPaymentTransactionStateDeferred);

// Download States
MAKE_SYSTEM_PROP(DOWNLOAD_STATE_WAITING, SKDownloadStateWaiting);
MAKE_SYSTEM_PROP(DOWNLOAD_STATE_ACTIVE, SKDownloadStateActive);
MAKE_SYSTEM_PROP(DOWNLOAD_STATE_PAUSED, SKDownloadStatePaused);
MAKE_SYSTEM_PROP(DOWNLOAD_STATE_FINISHED, SKDownloadStateFinished);
MAKE_SYSTEM_PROP(DOWNLOAD_STATE_FAILED, SKDownloadStateFailed);
MAKE_SYSTEM_PROP(DOWNLOAD_STATE_CANCELLED, SKDownloadStateCancelled);

MAKE_SYSTEM_PROP(DOWNLOAD_TIME_REMAINING_UNKNOWN,-1);

#pragma mark Utils

+ (NSString *)descriptionFromError:(NSError *)error
{
    if ([error localizedDescription] == nil) {
        return @"Unknown error";
    }
    return [error localizedDescription];
}

- (void)failIfSimulator
{
    if ([[[UIDevice currentDevice] model] rangeOfString:@"Simulator"].location != NSNotFound) {
        NSString *msg = @"StoreKit will not work on the iOS Simulator. It must be tested on device.";
        NSLog(@"[WARN] %@", msg);
        
        if (![TiUtils boolValue:[self valueForUndefinedKey:@"suppressSimulatorWarning"] def:NO]) {
            UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Warning"
                                                                           message:msg
                                                                    preferredStyle:UIAlertControllerStyleAlert];
            
            [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {

            }]];
            
            TiThreadPerformOnMainThread(^{
                [[TiApp app] showModalController:alert animated:YES];
            }, NO);
        }
    }
}

- (void)logAddListenerFirst:(NSString *)name
{
    NSLog(@"[WARN] A `%@` event listener should be added before calling `addTransactionObserver` to avoid missing events.", name);
}

- (void)logAddTransactionObserverFirst:(NSString *)name
{
    NSLog(@"[WARN] `addTransactionObserver` should be called before `%@`.", name);
}

- (NSURL *)receiptURL
{
    NSURL *receiptURL = [[NSBundle mainBundle] appStoreReceiptURL];
    if (![[NSFileManager defaultManager] fileExistsAtPath:receiptURL.path]) {
        [self throwException:@"Receipt does not exist. Try refreshing the receipt." subreason:nil location:CODELOCATION];
    }
    return receiptURL;
}

- (NSArray *)tiDownloadsFromSKDownloads:(NSArray *)downloads
{
    NSMutableArray *dls = [NSMutableArray arrayWithCapacity:[downloads count]];
    for (SKDownload *download in downloads) {
        TiStorekitDownload *d = [[TiStorekitDownload alloc] initWithDownload:download pageContext:[self pageContext]];
        [dls addObject:d];
    }
    return dls;
}

- (NSArray *)skDownloadsFromTiDownloads:(NSArray *)downloads
{
    NSMutableArray *dls = [NSMutableArray arrayWithCapacity:[downloads count]];
    for (TiStorekitDownload *download in downloads) {
        [dls addObject:[download download]];
    }
    return dls;
}

- (void)fireRefreshReceiptCallbackWithDict:(NSDictionary *)dict
{
    [self _fireEventToListener:@"callback" withObject:dict listener:refreshReceiptCallback thisObject:nil];
}

#pragma mark Delegates

- (void)cloudServiceSetupViewControllerDidDismiss:(SKCloudServiceSetupViewController *)cloudServiceSetupViewController
{
    if ([self _hasListeners:@"cloudSetupDialogDidClose"]) {
        [self fireEvent:@"cloudSetupDialogDidClose"];
    }
}

- (void)productViewControllerDidFinish:(SKStoreProductViewController *)viewController
{
    if ([self _hasListeners:@"productDialogDidClose"]) {
        [self fireEvent:@"productDialogDidClose"];
    }
}

// Sent when the transaction array has changed (additions or state changes).  
// Client should check state of transactions and finish as appropriate.
- (void)paymentQueue:(SKPaymentQueue *)queue updatedTransactions:(NSArray *)transactions
{
    for (SKPaymentTransaction *transaction in transactions)
    {
        [self handleTransaction:transaction error:transaction.error];
    }
}

- (NSMutableDictionary *)populateTransactionEvent:(SKPaymentTransaction *)transaction
{
    NSMutableDictionary *event = [NSMutableDictionary dictionaryWithObjectsAndKeys:
                                  NUMINT(transaction.transactionState),@"state",
                                  nil];
    
    
    NSData *dataReceipt = [NSData dataWithContentsOfURL:[[NSBundle mainBundle] appStoreReceiptURL]];
    
    if (dataReceipt != nil) {
        [event setObject:[dataReceipt base64EncodedStringWithOptions:0] forKey:@"receipt"];
    }
    
    if (transaction.transactionDate) {
        [event setObject:transaction.transactionDate forKey:@"date"];
    }
    
    if (transaction.transactionIdentifier) {
        [event setObject:transaction.transactionIdentifier forKey:@"identifier"];
    }
    
    if (transaction.payment) {
        [event setObject:NUMINTEGER(transaction.payment.quantity) forKey:@"quantity"];
        if (transaction.payment.productIdentifier) {
            [event setObject:transaction.payment.productIdentifier forKey:@"productIdentifier"];
        }
    }
    
    [event setObject:[self tiDownloadsFromSKDownloads:[transaction downloads]] forKey:@"downloads"];

    // MOD-1475 -- Restored transactions will include the original transaction. If found in the transaction
    // then we will add it to the event dictionary
    if (transaction.originalTransaction) {
        TiStorekitTransaction *origTrans = [[TiStorekitTransaction alloc] initWithTransaction:transaction.originalTransaction pageContext:[self executionContext]];
        [event setObject:origTrans forKey:@"originalTransaction"];
    }
    
    TiStorekitTransaction *trans = [[TiStorekitTransaction alloc] initWithTransaction:transaction pageContext:[self executionContext]];
    [event setObject:trans forKey:@"transaction"];

    return event;
}

- (void)handleTransaction:(SKPaymentTransaction *)transaction error:(NSError *)error
{
    SKPaymentTransactionState state = transaction.transactionState;
    NSMutableDictionary *event = [self populateTransactionEvent:transaction];
    
    if (state == SKPaymentTransactionStateFailed) {
        NSLog(@"[WARN] Error in transaction: %@",[TiStorekitModule descriptionFromError:error]);
        // MOD-1025: Cancelled state is actually determined by the error code
        BOOL cancelled = ([error code] == SKErrorPaymentCancelled);
        [event setObject:NUMBOOL(cancelled) forKey:@"cancelled"];
        if (!cancelled) {
            [event setObject:[TiStorekitModule descriptionFromError:error] forKey:@"message"];
        }
    } else if (state == SKPaymentTransactionStateRestored) {
        NSLog(@"[DEBUG] Transaction restored %@",transaction);
        // If this is a restored transaction, add it to the list of restored transactions
        // that will be posted in the event indicating that transactions have been restored.
        if (restoredTransactions==nil) {
            restoredTransactions = [[NSMutableArray alloc] initWithCapacity:1];
        }
        
        TiStorekitTransaction *trans = [[TiStorekitTransaction alloc] initWithTransaction:transaction pageContext:[self executionContext]];
        [restoredTransactions addObject:trans];
    }
    // Nothing special to do for SKPaymentTransactionStatePurchased or SKPaymentTransactionStatePurchasing

    if ([self _hasListeners:@"transactionState"]) {        
        [self fireEvent:@"transactionState" withObject:event];
    } else {
        NSLog(@"[WARN] No event listener for 'transactionState' event");
    }
    
    if (autoFinishTransactions) {
        // We need to finish the transaction as long as it is not still in progress
        switch (state)
        {
            case SKPaymentTransactionStatePurchasing:
                NSLog(@"[DEBUG] Purchasing for %@",transaction);
                break;
                
            case SKPaymentTransactionStateDeferred:
                NSLog(@"[DEBUG] Deffered transaction for %@",transaction);
                break;
            case SKPaymentTransactionStatePurchased:
            case SKPaymentTransactionStateFailed:
            case SKPaymentTransactionStateRestored:
            {
                NSLog(@"[DEBUG] Calling finish transaction for %@",transaction);
                [[SKPaymentQueue defaultQueue] finishTransaction:transaction];
                break;
            }
        }
    }
}

// Sent when an error is encountered while adding transactions from the user's purchase history back to the queue.
- (void)paymentQueue:(SKPaymentQueue *)queue restoreCompletedTransactionsFailedWithError:(NSError *)error
{
    NSLog(@"[ERROR] Failed to restore all completed transactions: %@",error);
    if ([self _hasListeners:@"restoredCompletedTransactions"]) {
        NSDictionary* event = [NSDictionary dictionaryWithObjectsAndKeys:[TiStorekitModule descriptionFromError:error],@"error",nil];
        [self fireEvent:@"restoredCompletedTransactions" withObject: event];
    } else {
        NSLog(@"[WARN] No event listener for 'restoredCompletedTransactions' event");
    }
    [self forgetSelf];
}

// Sent when all transactions from the user's purchase history have successfully been added back to the queue.
- (void)paymentQueueRestoreCompletedTransactionsFinished:(SKPaymentQueue *)queue
{
    NSLog(@"[INFO] Finished restoring completed transactions!");
    if ([self _hasListeners:@"restoredCompletedTransactions"]) {
        NSDictionary* event = [NSDictionary dictionaryWithObjectsAndKeys:restoredTransactions,@"transactions",nil];
        [self fireEvent:@"restoredCompletedTransactions" withObject: event];
    } else {
        NSLog(@"[WARN] No event listener for 'restoredCompletedTransactions' event");
    }
    [self forgetSelf];
}

// Sent when there is progress with a download
- (void)paymentQueue:(SKPaymentQueue *)queue updatedDownloads:(NSArray *)downloads
{
    if ([self _hasListeners:@"updatedDownloads"]) {
        NSArray *dls = [self tiDownloadsFromSKDownloads:downloads];
        NSDictionary *event = [NSDictionary dictionaryWithObjectsAndKeys:
                               dls, @"downloads",
                               nil];
        [self fireEvent:@"updatedDownloads" withObject:event];
    } else {
        NSLog(@"[WARN] No event listener for 'updatedDownloads' event");
    }
}

#pragma mark SKRequestDelegate

// Sent if a refreshReceipt request finishes successfully
- (void)requestDidFinish:(SKRequest *)request
{
    NSLog(@"[INFO] Finished refreshing receipt!");
    
    if (refreshReceiptCallback) {
        NSDictionary *event = [NSDictionary dictionaryWithObjectsAndKeys:
                               NUMBOOL(YES),@"success",
                               nil];
        [self fireRefreshReceiptCallbackWithDict:event];
    }
}

// Sent if there is an error as a result of calling refreshReceipt
- (void)request:(SKRequest *)request didFailWithError:(NSError *)error
{
    NSLog(@"[ERROR] Failed to refresh receipt: %@",error);
    
    if (refreshReceiptCallback) {
        NSDictionary *event = [NSDictionary dictionaryWithObjectsAndKeys:
                               NUMBOOL(NO),@"success",
                               [TiStorekitModule descriptionFromError:error],@"error",
                               nil];
        [self fireRefreshReceiptCallbackWithDict:event];
    }
}

@end

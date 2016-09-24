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
#import "TiStorekitProduct.h"
#import "TiStorekitDownload.h"
#import "TiStorekitProductRequest.h"
#import "TiStorekitReceiptRequest.h"
#import "TiStorekitTransaction.h"
#import "VerifyStoreReceipt.h"

@implementation TiStorekitModule

@synthesize receiptVerificationSharedSecret;

static TiStorekitModule *sharedInstance;
+(TiStorekitModule*)sharedInstance
{
    return sharedInstance;
}

#pragma mark Internal

// this is generated for your module, please do not change it
-(id)moduleGUID
{
    return @"67fdca33-590b-498d-bd4e-1fc3a8be0f37";
}

// this is generated for your module, please do not change it
-(NSString*)moduleId
{
    return @"ti.storekit";
}

#pragma mark Lifecycle

-(void)startup
{
    [super startup];
    
    receiptVerificationSandbox = NO;
    self.receiptVerificationSharedSecret = nil;
    
    sharedInstance = self;
    autoFinishTransactions = YES;
    transactionObserverSet = NO;
}

-(void)shutdown:(id)sender
{
    [self removeTransactionObserver:nil];
    [super shutdown:sender];
}

-(void)_destroy
{
    RELEASE_TO_NIL(bundleVersion);
    RELEASE_TO_NIL(bundleIdentifier);
    RELEASE_TO_NIL(refreshReceiptCallback);
    
    RELEASE_TO_NIL(restoredTransactions);
    self.receiptVerificationSharedSecret = nil;
    [super _destroy];
}

#pragma mark Public APIs

-(void)addTransactionObserver:(id)args
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

-(void)removeTransactionObserver:(id)args
{
    [[SKPaymentQueue defaultQueue] removeTransactionObserver:self];
    transactionObserverSet = NO;
}

-(void)setAutoFinishTransactions:(id)value
{
    autoFinishTransactions = [TiUtils boolValue:value];
}
-(id)autoFinishTransactions
{
    return NUMBOOL(autoFinishTransactions);
}

-(void)setBundleVersion:(id)value
{
    if (![TiUtils isIOS7OrGreater]) {
        [TiStorekitModule logAddedIniOS7Warning:@"bundleVersion"];
    }
    
    RELEASE_AND_REPLACE(bundleVersion, [TiUtils stringValue:value]);
}
-(id)bundleVersion
{
    return bundleVersion;
}

-(void)setBundleIdentifier:(id)value
{
    if (![TiUtils isIOS7OrGreater]) {
        [TiStorekitModule logAddedIniOS7Warning:@"bundleIdentifier"];
    }
    
    RELEASE_AND_REPLACE(bundleIdentifier, [TiUtils stringValue:value]);
}
-(id)bundleIdentifier
{
    return bundleIdentifier;
}

-(id)receiptExists
{
    if (![TiUtils isIOS7OrGreater]) {
        [TiStorekitModule logAddedIniOS7Warning:@"receiptExists"];
        return NUMBOOL(NO);
    }
    
    NSURL *receiptURL = [[NSBundle mainBundle] performSelector:@selector(appStoreReceiptURL)];
    return NUMBOOL([[NSFileManager defaultManager] fileExistsAtPath:receiptURL.path]);
}

-(id)validateReceipt:(id)args
{
    if (![TiUtils isIOS7OrGreater]) {
        [TiStorekitModule logAddedIniOS7Warning:@"validateReceipt"];
        return NUMBOOL(NO);
    }
    
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

-(TiBlob*)receipt
{
    if (![TiUtils isIOS7OrGreater]) {
        [TiStorekitModule logAddedIniOS7Warning:@"receipt"];
        return nil;
    }
    
    NSURL *receiptURL = [self receiptURL];
    return [[[TiBlob alloc] initWithFile:receiptURL.path] autorelease];
}

-(id)receiptProperties
{
    if (![TiUtils isIOS7OrGreater]) {
        [TiStorekitModule logAddedIniOS7Warning:@"receiptProperties"];
        return nil;
    }
    
    NSURL *receiptURL = [self receiptURL];
    NSMutableDictionary *receiptDict = [NSMutableDictionary dictionaryWithDictionary:dictionaryWithAppStoreReceipt(receiptURL.path)];
    // Removing properties that are unnecessary and are not datatypes that can be passed to JavaScript.
    [receiptDict removeObjectsForKeys:@[@"Hash", @"OpaqueValue", @"BundleIdentifierData"]];
    return receiptDict;
}

-(void)refreshReceipt:(id)args
{
    // Accepted properties are taken from
    // https://developer.apple.com/library/ios/documentation/StoreKit/Reference/SKReceiptRefreshRequest_ClassRef/SKReceiptRefreshRequest.html
    // Here is how they match up:
    //    SKReceiptPropertyIsExpired        = expired
    //    SKReceiptPropertyIsRevoked        = revoked
    //    SKReceiptPropertyIsVolumePurchase = vpp
    
    if (![TiUtils isIOS7OrGreater]) {
        [TiStorekitModule logAddedIniOS7Warning:@"refreshReceipt"];
        return nil;
    }
    
    enum Args {
        kArgProperties = 0,
        kArgCallback,
        kArgCount
    };
    
    ENSURE_ARG_COUNT(args, kArgCount);
    id properties = [args objectAtIndex:kArgProperties];
    id callback = [args objectAtIndex:kArgCallback];
    ENSURE_TYPE_OR_NIL(properties, NSDictionary);
    ENSURE_TYPE(callback, KrollCallback);
    
    RELEASE_AND_REPLACE(refreshReceiptCallback, callback);
    
    SKReceiptRefreshRequest *request = [[NSClassFromString(@"SKReceiptRefreshRequest") alloc] initWithReceiptProperties:properties];
    request.delegate = self;
    [request start];
}

-(id)requestProducts:(id)args
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
    return [[[TiStorekitProductRequest alloc] initWithProductIdentifiers:products callback:callback pageContext:[self executionContext]] autorelease];
}

-(void)purchase:(id)args
{
    TiStorekitProduct *product;
    int quantity;
    NSString *userName = nil;
    
    if ([[args objectAtIndex:0] isKindOfClass:[NSDictionary class]]) {
        // The new way
        // Takes a dictionary of properties
        ENSURE_SINGLE_ARG(args, NSDictionary);
        product = [args objectForKey:@"product"];
        quantity = [TiUtils intValue:@"quantity" properties:args def:1];
        userName = [args objectForKey:@"applicationUsername"];
    } else {
        // The old way - for backwards compatibility
        // Takes arguments
        NSLog(@"[WARN] Passing individual args to `purchase` is DEPRECATED. Call `purchase` passing in a dictionary of arguments.");
        product = [args objectAtIndex:0];
        quantity = [args count] > 1 ? [TiUtils intValue:[args objectAtIndex:1]] : 1;
    }
    
    if (!product) {
        [self throwException:@"`product` is required" subreason:nil location:CODELOCATION];
    }
    
    SKMutablePayment *payment = [SKMutablePayment paymentWithProduct:[product product]];
    payment.quantity = quantity;
    if (userName && [payment respondsToSelector:@selector(setApplicationUsername:)]) {
        [payment performSelector:@selector(setApplicationUsername:) withObject:userName];
    }
    
    SKPaymentQueue *queue = [SKPaymentQueue defaultQueue];
    [queue performSelectorOnMainThread:@selector(addPayment:) withObject:payment waitUntilDone:NO];
    
    if (!transactionObserverSet) {
        [self logAddTransactionObserverFirst:@"purchase"];
    }
}

-(id)canMakePayments
{
    return NUMBOOL([SKPaymentQueue canMakePayments]);
}

-(id)receiptVerificationSandbox
{
    return NUMBOOL(receiptVerificationSandbox);
}

-(void)setReceiptVerificationSandbox:(id)value
{
    receiptVerificationSandbox = [TiUtils boolValue:value def:NO];
}

-(id)verifyReceipt:(id)args
{
    NSDictionary* transaction;
    KrollCallback *callback;
    
    ENSURE_ARG_AT_INDEX(transaction,args,0,NSDictionary);
    
    // Apple changed the structure of receipts and how they are validated.
    // The old method required communication with a server and was asynchronous.
    // The new method can be done on device and is synchronous.
    NSLog(@"[WARN] `verifyReceipt` has been DEPRECATED. Use `validateReceipt`.");

    // As of version 1.6.0 of the module the callback is passed as the 2nd parameter to match other APIs.
    // The old method of passing the callback as a property of the transaction dictionary has been DEPRECATED
    if ([args count] > 1) {
        ENSURE_ARG_AT_INDEX(callback,args,1,KrollCallback);
    } else {
        callback = [transaction objectForKey:@"callback"];
        if (callback != nil) {
            NSLog(@"[WARN] Setting the callback in the receipt dictionary has been DEPRECATED. Pass the callback as the 2nd parameter to VerifyReceipt.");
        }
    }

    BOOL exists;
    BOOL sandbox = [TiUtils boolValue:@"sandbox" properties:transaction def:receiptVerificationSandbox exists:&exists];
    if (exists) {
        NSLog(@"[WARN] Setting the sandbox property in the receipt dictionary has been DEPRECATED. Use the 'receiptVerificationSandbox' property.");
    }
    
    NSString* sharedSecret = [TiUtils stringValue:@"sharedSecret" properties:transaction def:self.receiptVerificationSharedSecret exists:&exists];
    if (exists) {
        NSLog(@"[WARN] Setting the sharedSecret property in the receipt dictionary has been DEPRECATED. Use the 'receiptVerificationSharedSecret' property.");
    }    
    
    // New arguments provided by MOD-849 updates to assist in receipt verification
    NSString *transactionId = [TiUtils stringValue:@"identifier" properties:transaction def:nil];
    NSInteger quantity = [TiUtils intValue:[transaction objectForKey:@"quantity"] def:1];
    NSString *productId = [TiUtils stringValue:@"productIdentifier" properties:transaction def:nil];
    id receipt = [transaction objectForKey:@"receipt"];
    NSData *data = nil;
    if ([receipt isKindOfClass:[TiBlob class]]) {
        data = [(TiBlob*)receipt data];
    } else {
        THROW_INVALID_ARG(@"expected receipt data as a Blob object");
    }
    
    TiStorekitReceiptRequest* request = [[[TiStorekitReceiptRequest alloc] initWithData:data callback:callback pageContext:[self pageContext] productIdentifier:productId quantity:quantity transactionIdentifier:transactionId] autorelease];
    
    [request verify:sandbox secret:sharedSecret];
    
    return request;
}

-(void)restoreCompletedTransactions:(id)unused
{
    [self rememberSelf];
    [[SKPaymentQueue defaultQueue] restoreCompletedTransactions];
    
    if (!transactionObserverSet) {
        [self logAddTransactionObserverFirst:@"restoreCompletedTransactions"];
    }
}

-(void)restoreCompletedTransactionsWithApplicationUsername:(id)value
{
    [[SKPaymentQueue defaultQueue] restoreCompletedTransactionsWithApplicationUsername:[TiUtils stringValue:value]];

    if (!transactionObserverSet) {
        [self logAddTransactionObserverFirst:@"restoreCompletedTransactions"];
    }
}

#define MAKE_DOWNLOAD_CONTROL_METHOD(name) \
-(void)name:(id)args \
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

MAKE_DOWNLOAD_CONTROL_METHOD(startDownloads);
MAKE_DOWNLOAD_CONTROL_METHOD(cancelDownloads);
MAKE_DOWNLOAD_CONTROL_METHOD(pauseDownloads);
MAKE_DOWNLOAD_CONTROL_METHOD(resumeDownloads);

#pragma mark Constants

// TransactionStates
// Here for backwards compatibility
MAKE_SYSTEM_PROP(PURCHASING,0);
MAKE_SYSTEM_PROP(PURCHASED,1);
MAKE_SYSTEM_PROP(FAILED,2);
MAKE_SYSTEM_PROP(RESTORED,3);

MAKE_SYSTEM_PROP(TRANSACTION_STATE_PURCHASING,0);
MAKE_SYSTEM_PROP(TRANSACTION_STATE_PURCHASED,1);
MAKE_SYSTEM_PROP(TRANSACTION_STATE_FAILED,2);
MAKE_SYSTEM_PROP(TRANSACTION_STATE_RESTORED,3);

// DownloadStates
MAKE_SYSTEM_PROP(DOWNLOAD_STATE_WAITING,0);
MAKE_SYSTEM_PROP(DOWNLOAD_STATE_ACTIVE,1);
MAKE_SYSTEM_PROP(DOWNLOAD_STATE_PAUSED,2);
MAKE_SYSTEM_PROP(DOWNLOAD_STATE_FINISHED,3);
MAKE_SYSTEM_PROP(DOWNLOAD_STATE_FAILED,4);
MAKE_SYSTEM_PROP(DOWNLOAD_STATE_CANCELLED,5);

MAKE_SYSTEM_PROP(DOWNLOAD_TIME_REMAINING_UNKNOWN,-1);

#pragma mark Utils

+(NSString*)descriptionFromError:(NSError*)error
{
    if ([error localizedDescription] == nil) {
        return @"Unknown error";
    }
    return [error localizedDescription];
}

+(void)logAddedIniOS6Warning:(NSString*)name
{
    NSLog(@"[WARN] `%@` is only supported on iOS 6 and greater.", name);
}

+(void)logAddedIniOS7Warning:(NSString*)name
{
    NSLog(@"[WARN] `%@` is only supported on iOS 7 and greater.", name);
}

-(void)failIfSimulator
{
    if ([[[UIDevice currentDevice] model] rangeOfString:@"Simulator"].location != NSNotFound) {
        NSString *msg = @"StoreKit will not work on the iOS 7 or iOS 5 simulator. It must be tested on device.";
        NSLog(@"[WARN] %@", msg);
        
        if (![TiUtils boolValue:[self valueForUndefinedKey:@"suppressSimulatorWarning"] def:NO]) {
            UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Warning" message:msg delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
            
            TiThreadPerformOnMainThread(^{
                [alert show];
                [alert autorelease];
            }, NO);
        }
    }
}

-(void)logAddListenerFirst:(NSString*)name
{
    NSLog(@"[WARN] A `%@` event listener should be added before calling `addTransactionObserver` to avoid missing events.", name);
}

-(void)logAddTransactionObserverFirst:(NSString*)name
{
    NSLog(@"[WARN] `addTransactionObserver` should be called before `%@`.", name);
}

-(NSURL*)receiptURL
{
    NSURL *receiptURL = [[NSBundle mainBundle] performSelector:@selector(appStoreReceiptURL)];
    if (![[NSFileManager defaultManager] fileExistsAtPath:receiptURL.path]) {
        [self throwException:@"Receipt does not exist. Try refreshing the receipt." subreason:nil location:CODELOCATION];
    }
    return receiptURL;
}

-(NSArray*)tiDownloadsFromSKDownloads:(NSArray*)downloads
{
    NSMutableArray *dls = [NSMutableArray arrayWithCapacity:[downloads count]];
    for (SKDownload *download in downloads) {
        TiStorekitDownload *d = [[TiStorekitDownload alloc] initWithDownload:download pageContext:[self pageContext]];
        [dls addObject:d];
        [d release];
    }
    return dls;
}

-(NSArray*)skDownloadsFromTiDownloads:(NSArray*)downloads
{
    NSMutableArray *dls = [NSMutableArray arrayWithCapacity:[downloads count]];
    for (TiStorekitDownload *download in downloads) {
        [dls addObject:[download download]];
    }
    return dls;
}

-(void)fireRefreshReceiptCallbackWithDict:(NSDictionary*)dict
{
    [self _fireEventToListener:@"callback" withObject:dict listener:refreshReceiptCallback thisObject:nil];
    RELEASE_TO_NIL_AUTORELEASE(refreshReceiptCallback);
}

#pragma mark Delegates

// Sent when the transaction array has changed (additions or state changes).  
// Client should check state of transactions and finish as appropriate.
- (void)paymentQueue:(SKPaymentQueue *)queue updatedTransactions:(NSArray *)transactions
{
    for (SKPaymentTransaction *transaction in transactions)
    {
        [self handleTransaction:transaction error:transaction.error];
    }
}

-(NSMutableDictionary*)populateTransactionEvent:(SKPaymentTransaction*)transaction
{
    NSMutableDictionary *event = [NSMutableDictionary dictionaryWithObjectsAndKeys:
                                  NUMINT(transaction.transactionState),@"state",
                                  nil];
    
    if ([transaction respondsToSelector:@selector(transactionReceipt)] &&
               [transaction performSelector:@selector(transactionReceipt)]) {
        // Here for backwards compatibility
        // Can be removed when support for iOS 6 is dropped and verifyReceipt is removed.
        NSData *receipt = [transaction performSelector:@selector(transactionReceipt)];
        TiBlob *blob = [[TiBlob alloc] initWithData:receipt mimetype:@"text/json"];
        [event setObject:blob forKey:@"receipt"];
        [blob release];
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
    
    if ([transaction respondsToSelector:@selector(downloads)] && [transaction performSelector:@selector(downloads)]) {
        [event setObject:[self tiDownloadsFromSKDownloads:[transaction performSelector:@selector(downloads)]] forKey:@"downloads"];
    }

    // MOD-1475 -- Restored transactions will include the original transaction. If found in the transaction
    // then we will add it to the event dictionary
    if (transaction.originalTransaction) {
        TiStorekitTransaction *origTrans = [[TiStorekitTransaction alloc] initWithTransaction:transaction.originalTransaction pageContext:[self executionContext]];
        [event setObject:origTrans forKey:@"originalTransaction"];
        [origTrans release];
    }
    
    TiStorekitTransaction *trans = [[TiStorekitTransaction alloc] initWithTransaction:transaction pageContext:[self executionContext]];
    [event setObject:trans forKey:@"transaction"];
    [trans release];

    return event;
}

-(void)handleTransaction:(SKPaymentTransaction*)transaction error:(NSError*)error
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
        [trans release];
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
-(void)paymentQueue:(SKPaymentQueue *)queue restoreCompletedTransactionsFailedWithError:(NSError *)error
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
-(void)paymentQueueRestoreCompletedTransactionsFinished:(SKPaymentQueue *)queue
{
    NSLog(@"[INFO] Finished restoring completed transactions!");
    if ([self _hasListeners:@"restoredCompletedTransactions"]) {
        NSDictionary* event = [NSDictionary dictionaryWithObjectsAndKeys:restoredTransactions,@"transactions",nil];
        [self fireEvent:@"restoredCompletedTransactions" withObject: event];
    } else {
        NSLog(@"[WARN] No event listener for 'restoredCompletedTransactions' event");
    }
    RELEASE_TO_NIL(restoredTransactions);
    [self forgetSelf];
}

// Sent when there is progress with a download
-(void)paymentQueue:(SKPaymentQueue *)queue updatedDownloads:(NSArray *)downloads
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
-(void)requestDidFinish:(SKRequest *)request
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
-(void)request:(SKRequest *)request didFailWithError:(NSError *)error
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

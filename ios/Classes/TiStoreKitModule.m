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
#import "TiStorekitProductRequest.h"
#import "TiStorekitReceiptRequest.h"

@implementation TiStorekitModule

@synthesize receiptVerificationSharedSecret;

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
	[[SKPaymentQueue defaultQueue] addTransactionObserver:self];
    
    receiptVerificationSandbox = NO;
    self.receiptVerificationSharedSecret = nil;
}

-(void)shutdown:(id)sender
{
	[[SKPaymentQueue defaultQueue] removeTransactionObserver:self];
	[super shutdown:sender];
}

-(void)_destroy
{
    RELEASE_TO_NIL(restoredTransactions);
    self.receiptVerificationSharedSecret = nil;
	[super _destroy];
}

#pragma mark Public APIs

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
	TiStorekitProduct *product = [args objectAtIndex:0];
	int quantity = [args count] > 1 ? [TiUtils intValue:[args objectAtIndex:1]] : 1;
	
	SKMutablePayment *payment = [SKMutablePayment paymentWithProduct:[product product]];
	payment.quantity = quantity;
	SKPaymentQueue *queue = [SKPaymentQueue defaultQueue];
	[queue performSelectorOnMainThread:@selector(addPayment:) withObject:payment waitUntilDone:NO];
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
	if ([receipt isKindOfClass:[TiBlob class]])	{
		data = [(TiBlob*)receipt data];
	} else {
		THROW_INVALID_ARG(@"expected receipt data as a Blob object");
	}
	
    TiStorekitReceiptRequest* request = [[[TiStorekitReceiptRequest alloc] initWithData:data callback:callback pageContext:[self pageContext] productIdentifier:productId quantity:quantity transactionIdentifier:transactionId] autorelease];
    
    [request verify:sandbox secret:sharedSecret];
    
    return request;
}

-(void)restoreCompletedTransactions:(id)args
{
    [self rememberSelf];
    [[SKPaymentQueue defaultQueue] restoreCompletedTransactions];
}

MAKE_SYSTEM_PROP(PURCHASING,0);
MAKE_SYSTEM_PROP(PURCHASED,1);
MAKE_SYSTEM_PROP(FAILED,2);
MAKE_SYSTEM_PROP(RESTORED,3);

#pragma mark Utils

+(NSString*)descriptionFromError:(NSError*)error
{
    if ([error localizedDescription] == nil) {
        return @"Unknown error";
    }
    return [error localizedDescription];
}

#pragma mark Delegates

// Sent when the transaction array has changed (additions or state changes).  
// Client should check state of transactions and finish as appropriate.
- (void)paymentQueue:(SKPaymentQueue *)queue updatedTransactions:(NSArray *)transactions
{
	for (SKPaymentTransaction *transaction in transactions)
	{
		SKPaymentTransactionState state = transaction.transactionState;
        [self handleTransaction:transaction error:transaction.error];
    }
}

-(NSMutableDictionary*)populateTransactionEvent:(SKPaymentTransaction*)transaction
{
    NSMutableDictionary *event = [NSMutableDictionary dictionaryWithObjectsAndKeys:
                                  NUMINT(transaction.transactionState),@"state",
                                  nil];
    
    if (transaction.transactionReceipt) {
        NSData *receipt = transaction.transactionReceipt;
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
        [event setObject:NUMINT(transaction.payment.quantity) forKey:@"quantity"];
        if (transaction.payment.productIdentifier) {
            [event setObject:transaction.payment.productIdentifier forKey:@"productIdentifier"];
        }
    }

    // MOD-1475 -- Restored transactions will include the original transaction. If found in the transaction
    // then we will add it to the event dictionary
    if (transaction.originalTransaction) {
        [event setObject:[self populateTransactionEvent:transaction.originalTransaction] forKey:@"originalTransaction"];
    }

    return event;
}

- (void)handleTransaction:(SKPaymentTransaction*)transaction error:(NSError*)error
{
    SKPaymentTransactionState state = transaction.transactionState;
    NSMutableDictionary *event = [self populateTransactionEvent:transaction];

    if (state == SKPaymentTransactionStateFailed) {
        NSLog(@"[WARN] Error in transaction: %@",[[self class] descriptionFromError:error]);
        // MOD-1025: Cancelled state is actually determined by the error code
        BOOL cancelled = ([error code] == SKErrorPaymentCancelled);
        [event setObject:NUMBOOL(cancelled) forKey:@"cancelled"];
        if (!cancelled) {
            [event setObject:[[self class] descriptionFromError:error] forKey:@"message"];
        }
	} else if (state == SKPaymentTransactionStateRestored) {
		NSLog(@"[DEBUG] Transaction restored %@",transaction);
		// If this is a restored transaction, add it to the list of restored transactions
		// that will be posted in the event indicating that transactions have been restored.
		if (restoredTransactions==nil) {
			restoredTransactions = [[NSMutableArray alloc] initWithCapacity:1];
		}
		[restoredTransactions addObject:[self populateTransactionEvent:transaction]];
	}
	// Nothing special to do for SKPaymentTransactionStatePurchased or SKPaymentTransactionStatePurchasing

    if ([self _hasListeners:@"transactionState"]) {
        [self fireEvent:@"transactionState" withObject:event];
    } else {
        NSLog(@"[WARN] No event listener for 'transactionState' event");
    }

	// We need to finish the transaction as long as it is not still in progress
	switch (state)
	{
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

// Sent when an error is encountered while adding transactions from the user's purchase history back to the queue.
- (void)paymentQueue:(SKPaymentQueue *)queue restoreCompletedTransactionsFailedWithError:(NSError *)error
{
	NSLog(@"[ERROR] Failed to restore all completed transactions: %@",error);
	NSDictionary* event = [NSDictionary dictionaryWithObjectsAndKeys:[[self class] descriptionFromError:error],@"error",nil];
	[self fireEvent:@"restoredCompletedTransactions" withObject: event];
    [self forgetSelf];
}

// Sent when all transactions from the user's purchase history have successfully been added back to the queue.
- (void)paymentQueueRestoreCompletedTransactionsFinished:(SKPaymentQueue *)queue
{
	NSLog(@"[INFO] Finished restoring completed transactions!");
	NSDictionary* event = [NSDictionary dictionaryWithObjectsAndKeys:restoredTransactions,@"transactions",nil];
	[self fireEvent:@"restoredCompletedTransactions" withObject: event];
    RELEASE_TO_NIL(restoredTransactions);
    [self forgetSelf];
}

@end

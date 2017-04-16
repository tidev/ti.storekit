/**
 * Appcelerator Titanium Mobile
 * Copyright (c) 2010-2013 by Appcelerator, Inc. All Rights Reserved.
 * Licensed under the terms of the Apache Public License
 * Please see the LICENSE included with this distribution for details.
 */

#import "TiBlob.h"
#import "TiStorekitModule.h"
#import "TiStorekitTransaction.h"

@implementation TiStorekitTransaction

#pragma mark Internal

- (id)initWithTransaction:(SKPaymentTransaction *)transaction_ pageContext:(id<TiEvaluator>)context
{
    if (self = [super _initWithPageContext:context]) {
        transaction = transaction_;
    }
    return self;
}

#pragma mark Utils

#define RETURN_UNDEFINED_IF_NIL(name) \
if (!name) { \
    return nil; \
} \

#pragma mark Public API

- (void)finish:(id)args
{
    NSLog(@"[DEBUG] Transaction finished %@",transaction);
    
    if (!transaction) {
        return;
    }
    [[SKPaymentQueue defaultQueue] finishTransaction:transaction];
}

- (id)state
{
    RETURN_UNDEFINED_IF_NIL(transaction);
    return NUMINT(transaction.transactionState);
}

- (id)date
{
    RETURN_UNDEFINED_IF_NIL(transaction);
    return transaction.transactionDate;
}

- (id)identifier
{
    RETURN_UNDEFINED_IF_NIL(transaction);
    return transaction.transactionIdentifier;
}

- (id)downloads
{
    RETURN_UNDEFINED_IF_NIL(transaction);
    return transaction.downloads ? [[TiStorekitModule sharedInstance] tiDownloadsFromSKDownloads:transaction.downloads] : nil;
}

- (id)originalTransaction
{
    RETURN_UNDEFINED_IF_NIL(transaction);
    return transaction.originalTransaction ? [[TiStorekitTransaction alloc] initWithTransaction:transaction.originalTransaction pageContext:[self pageContext]] : nil;
}

- (id)receipt
{
    NSData *dataReceipt = [NSData dataWithContentsOfURL:[[NSBundle mainBundle] appStoreReceiptURL]];
    
    RETURN_UNDEFINED_IF_NIL(dataReceipt);
    return [dataReceipt base64EncodedStringWithOptions:0];
}

- (id)quantity
{
    RETURN_UNDEFINED_IF_NIL(transaction);
    return transaction.payment ? NUMINTEGER(transaction.payment.quantity) : nil;
}

- (id)productIdentifier
{
    RETURN_UNDEFINED_IF_NIL(transaction);
    return transaction.payment ? transaction.payment.productIdentifier : nil;
}

- (id)applicationUsername
{
    RETURN_UNDEFINED_IF_NIL(transaction);
    return transaction.payment ? transaction.payment.applicationUsername : nil;
}

@end

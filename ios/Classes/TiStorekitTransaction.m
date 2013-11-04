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

-(id)initWithTransaction:(SKPaymentTransaction*)transaction_ pageContext:(id<TiEvaluator>)context
{
    if (self = [super _initWithPageContext:context]) {
        transaction = [transaction_ retain];
    }
    return self;
}

-(void)_destroy
{
    RELEASE_TO_NIL(transaction);
    [super _destroy];
}

#pragma mark Utils

#define RETURN_UNDEFINED_IF_NIL(name) \
if (!name) { \
    return nil; \
} \

#pragma mark Public API

-(void)finish:(id)args
{
    NSLog(@"[DEBUG] Transaction finished %@",transaction);
    
    if (!transaction) {
        return;
    }
    [[SKPaymentQueue defaultQueue] finishTransaction:transaction];
}

-(id)state
{
    RETURN_UNDEFINED_IF_NIL(transaction);
    return NUMINT(transaction.transactionState);
}

-(id)date
{
    RETURN_UNDEFINED_IF_NIL(transaction);
    return transaction.transactionDate;
}

-(id)identifier
{
    RETURN_UNDEFINED_IF_NIL(transaction);
    return transaction.transactionIdentifier;
}

-(id)downloads
{
    if (![TiUtils isIOS6OrGreater]) {
        [TiStorekitModule logAddedIniOS6Warning:@"downloads"];
    }
    
    RETURN_UNDEFINED_IF_NIL(transaction);
    return transaction.downloads ? [[TiStorekitModule sharedInstance] tiDownloadsFromSKDownloads:transaction.downloads] : nil;
}

-(id)originalTransaction
{
    RETURN_UNDEFINED_IF_NIL(transaction);
    return transaction.originalTransaction ? [[[TiStorekitTransaction alloc] initWithTransaction:transaction.originalTransaction pageContext:[self pageContext]] autorelease] : nil;
}

-(id)receipt
{
    // Here for backwards compatibility
    // Can be removed when support for iOS 6 is dropped and verifyReceipt is removed.
    if ([transaction respondsToSelector:@selector(transactionReceipt)] &&
        [transaction performSelector:@selector(transactionReceipt)]) {
        NSData *receipt = [transaction performSelector:@selector(transactionReceipt)];
        TiBlob *blob = [[[TiBlob alloc] initWithData:receipt mimetype:@"text/json"] autorelease];
        return blob;
    } else {
        return nil;
    }
}

-(id)quantity
{
    RETURN_UNDEFINED_IF_NIL(transaction);
    return transaction.payment ? NUMINT(transaction.payment.quantity) : nil;
}

-(id)productIdentifier
{
    RETURN_UNDEFINED_IF_NIL(transaction);
    return transaction.payment ? transaction.payment.productIdentifier : nil;
}

-(id)applicationUsername
{
    if (![TiUtils isIOS7OrGreater]) {
        [TiStorekitModule logAddedIniOS7Warning:@"applicationUsername"];
    }
    
    RETURN_UNDEFINED_IF_NIL(transaction);
    return transaction.payment ? transaction.payment.applicationUsername : nil;
}

@end

/**
 * Appcelerator Titanium Mobile
 * Copyright (c) 2010-2013 by Appcelerator, Inc. All Rights Reserved.
 * Licensed under the terms of the Apache Public License
 * Please see the LICENSE included with this distribution for details.
 */

#import "TiStorekitTransaction.h"
#import "TiBlob.h"
#import "TiStorekitModule.h"

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
  if (!name) {                        \
    return nil;                       \
  }

#pragma mark Public API's

- (void)finish:(id)args
{
  NSLog(@"[DEBUG] Transaction finished %@", transaction);

  if (!transaction) {
    return;
  }
  [[SKPaymentQueue defaultQueue] finishTransaction:transaction];
}

- (NSNumber *)state
{
  RETURN_UNDEFINED_IF_NIL(transaction);
  return NUMINT(transaction.transactionState);
}

- (id)date
{
  RETURN_UNDEFINED_IF_NIL(transaction);
  return transaction.transactionDate;
}

- (NSString *)identifier
{
  RETURN_UNDEFINED_IF_NIL(transaction);
  return transaction.transactionIdentifier;
}

- (NSArray *)downloads
{
  RETURN_UNDEFINED_IF_NIL(transaction);
  return transaction.downloads ? [[TiStorekitModule sharedInstance] tiDownloadsFromStoreKitDownloads:transaction.downloads] : nil;
}

- (TiStorekitTransaction *)originalTransaction
{
  RETURN_UNDEFINED_IF_NIL(transaction);
  return transaction.originalTransaction ? [[TiStorekitTransaction alloc] initWithTransaction:transaction.originalTransaction pageContext:[self pageContext]] : nil;
}

- (NSString *)receipt
{
  NSData *dataReceipt = [NSData dataWithContentsOfURL:[[NSBundle mainBundle] appStoreReceiptURL]];

  RETURN_UNDEFINED_IF_NIL(dataReceipt);
  return [dataReceipt base64EncodedStringWithOptions:0];
}

- (NSNumber *)quantity
{
  RETURN_UNDEFINED_IF_NIL(transaction);
  return transaction.payment ? NUMINTEGER(transaction.payment.quantity) : nil;
}

- (NSString *)productIdentifier
{
  RETURN_UNDEFINED_IF_NIL(transaction);
  return transaction.payment ? transaction.payment.productIdentifier : nil;
}

- (NSString *)applicationUsername
{
  RETURN_UNDEFINED_IF_NIL(transaction);
  return transaction.payment ? transaction.payment.applicationUsername : nil;
}

@end

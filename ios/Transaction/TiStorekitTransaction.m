//
//  TiStorekitTransaction.m
//  Ti.StoreKit
//
//  Created by Douglas Alves on 18/03/26.
//


/**
 * Appcelerator Titanium Mobile
 * Copyright (c) 2010-present by Appcelerator, Inc. All Rights Reserved.
 * Licensed under the terms of the Apache Public License
 * Please see the LICENSE included with this distribution for details.
 */

#import "TiStorekitTransaction.h"
#import "TiStorekitModule.h"

@implementation TiStorekitTransaction

#pragma mark - Init

- (id)initWithTransaction:(SKPaymentTransaction *)transaction_ pageContext:(id<TiEvaluator>)context
{
  if (self = [super _initWithPageContext:context]) {
    transaction = transaction_;
  }
  return self;
}

#pragma mark - Helpers

// Returns NSNull when param is nil so JS receives null instead of undefined.
#define RETURN_NULL_IF_NIL(param) \
  if (!(param)) { return [NSNull null]; }

#pragma mark - Public API

- (void)finish:(id)args
{
  if (!transaction) { return; }
  NSLog(@"[DEBUG] Ti.Storekit: Finishing transaction — %@", transaction);
  [[SKPaymentQueue defaultQueue] finishTransaction:transaction];
}

- (id)state
{
  RETURN_NULL_IF_NIL(transaction);
  return @(transaction.transactionState);
}

- (id)date
{
  RETURN_NULL_IF_NIL(transaction);
  return transaction.transactionDate ?: [NSNull null];
}

- (id)identifier
{
  RETURN_NULL_IF_NIL(transaction);
  return transaction.transactionIdentifier ?: [NSNull null];
}

/**
 * Returns the Base64-encoded App Store receipt.
 * This is the receipt for the entire app, not just this transaction.
 * Use it for server-side validation.
 */
- (id)receipt
{
  NSData *data = [NSData dataWithContentsOfURL:[[NSBundle mainBundle] appStoreReceiptURL]];
  RETURN_NULL_IF_NIL(data);
  return [data base64EncodedStringWithOptions:0];
}

- (id)quantity
{
  RETURN_NULL_IF_NIL(transaction);
  return transaction.payment ? @(transaction.payment.quantity) : [NSNull null];
}

- (id)productIdentifier
{
  RETURN_NULL_IF_NIL(transaction);
  return transaction.payment.productIdentifier ?: [NSNull null];
}

- (id)applicationUsername
{
  RETURN_NULL_IF_NIL(transaction);
  return transaction.payment.applicationUsername ?: [NSNull null];
}

- (id)originalTransaction
{
  RETURN_NULL_IF_NIL(transaction);
  if (!transaction.originalTransaction) { return [NSNull null]; }
  return [[TiStorekitTransaction alloc] initWithTransaction:transaction.originalTransaction
                                                pageContext:[self pageContext]];
}

@end

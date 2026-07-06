//
//  TiStorekitTransaction.h
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

#import "TiProxy.h"
#import <StoreKit/StoreKit.h>

@interface TiStorekitTransaction : TiProxy {
  @private
  SKPaymentTransaction *transaction;
}

- (id)initWithTransaction:(SKPaymentTransaction *)transaction_ pageContext:(id<TiEvaluator>)context;

#pragma mark - Public API

/** Finishes the transaction and removes it from the payment queue. */
- (void)finish:(id)args;

/** Current SKPaymentTransactionState as an integer. */
- (id)state;

/** Date the transaction was added to the queue. */
- (id)date;

/** Unique identifier for a successful or restored transaction. */
- (id)identifier;

/**
 * Base64-encoded receipt string.
 * Send this to your server for server-side validation.
 */
- (id)receipt;

/** Number of items purchased (default 1, max 10). */
- (id)quantity;

/** Product identifier string. */
- (id)productIdentifier;

/** Opaque identifier for the user's account on your system. */
- (id)applicationUsername;

/**
 * For TRANSACTION_STATE_RESTORED transactions, the original transaction
 * that was restored. Nil for all other states.
 */
- (id)originalTransaction;

@end
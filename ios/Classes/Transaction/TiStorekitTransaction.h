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

#pragma mark Public API's

- (void)finish:(id)args;

- (NSNumber *)state;

- (id)date;

- (NSString *)identifier;

- (NSArray *)downloads;

- (TiStorekitTransaction *)originalTransaction;

- (NSString *)receipt;

- (NSNumber *)quantity;

- (NSString *)productIdentifier;

- (NSString *)applicationUsername;

@end

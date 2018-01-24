/**
 * Appcelerator Titanium Mobile
 * Copyright (c) 2010-2013 by Appcelerator, Inc. All Rights Reserved.
 * Licensed under the terms of the Apache Public License
 * Please see the LICENSE included with this distribution for details.
 */

#import "TiProxy.h"
#import "TiStorekitProductDiscountProxy.h"
#import <StoreKit/StoreKit.h>

@interface TiStorekitProduct : TiProxy {
  @private
  SKProduct *_product;
}

- (id)initWithProduct:(SKProduct *)product pageContext:(id<TiEvaluator>)context;

- (SKProduct *)product;

#pragma mark Public API's

- (NSString *)description;

- (NSString *)title;

- (NSDecimalNumber *)price;

- (NSString *)formattedPrice;

- (NSString *)locale;

- (NSString *)identifier;

- (NSNumber *)downloadable;

- (NSArray *)downloadContentLengths;

- (NSString *)downloadContentVersion;

#if IS_IOS_11_2
- (TiStorekitProductDiscountProxy *)introductoryPrice;

- (NSDictionary *)subscriptionPeriod;
#endif

@end

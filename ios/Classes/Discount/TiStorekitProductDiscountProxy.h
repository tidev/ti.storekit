/**
 * Appcelerator Titanium Mobile
 * Copyright (c) 2009-2017 by Appcelerator, Inc. All Rights Reserved.
 * Licensed under the terms of the Apache Public License
 * Please see the LICENSE included with this distribution for details.
 */
#import "TiProxy.h"
#import <StoreKit/StoreKit.h>

#if IS_IOS_11_2

@interface TiStorekitProductDiscountProxy : TiProxy {
  SKProductDiscount *_productDiscount;
}

- (id)initWithProductDiscount:(SKProductDiscount *)productDiscount pageContext:(id<TiEvaluator>)context;

- (NSNumber *)price;

- (NSString *)priceLocale;

- (NSDictionary *)subscriptionPeriod;

- (NSNumber *)numberOfPeriods;

- (NSNumber *)paymentMode;

@end

#endif

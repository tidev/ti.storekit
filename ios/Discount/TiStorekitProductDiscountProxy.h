//
//  TiStorekitProductDiscountProxy.h
//  Ti.StoreKit
//
//  Created by Douglas Alves on 18/03/26.
//


/**
 * Appcelerator Titanium Mobile
 * Copyright (c) 2009-present by Appcelerator, Inc. All Rights Reserved.
 * Licensed under the terms of the Apache Public License
 * Please see the LICENSE included with this distribution for details.
 */

#import "TiProxy.h"
#import <StoreKit/StoreKit.h>

API_AVAILABLE(ios(11.2))
@interface TiStorekitProductDiscountProxy : TiProxy {
  SKProductDiscount *_productDiscount;
}

- (id)initWithProductDiscount:(SKProductDiscount *)productDiscount
                  pageContext:(id<TiEvaluator>)context;

/** Discount price as a decimal number. */
- (NSNumber *)price;

/** Locale identifier for the discount's pricing locale. */
- (NSString *)priceLocale;

/**
 * Subscription period for the discount.
 * Returns a dict with numberOfUnits (Number) and unit (PERIOD_UNIT_* constant).
 */
- (NSDictionary *)subscriptionPeriod;

/** Number of periods the discount is applied. */
- (NSNumber *)numberOfPeriods;

/** Payment mode — one of DISCOUNT_PAYMENT_MODE_* constants. */
- (NSNumber *)paymentMode;

@end
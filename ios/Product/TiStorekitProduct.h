//
//  TiStorekitProduct.h
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
#import "TiStorekitProductDiscountProxy.h"
#import <StoreKit/StoreKit.h>

@interface TiStorekitProduct : TiProxy {
  @private
  SKProduct *_product;
}

- (id)initWithProduct:(SKProduct *)product pageContext:(id<TiEvaluator>)context;
- (SKProduct *)product;

#pragma mark - Public API

/** Localized description of the product. */
- (NSString *)description;

/** Localized display name of the product. */
- (NSString *)title;

/** Price as a decimal number in the store's locale. */
- (NSDecimalNumber *)price;

/** Price formatted as a currency string for the store's locale. */
- (NSString *)formattedPrice;

/** Locale identifier for the store's pricing locale. */
- (NSString *)locale;

/** Product identifier as set in App Store Connect. */
- (NSString *)identifier;

/**
 * Introductory price (iOS 11.2+).
 * Returns a TiStorekitProductDiscountProxy with price, priceLocale,
 * subscriptionPeriod, numberOfPeriods, and paymentMode.
 */
- (TiStorekitProductDiscountProxy *)introductoryPrice;

/**
 * Subscription period (iOS 11.2+).
 * Returns a dict with numberOfUnits (Number) and unit (PERIOD_UNIT_* constant).
 */
- (NSDictionary *)subscriptionPeriod;

@end
//
//  TiStorekitProduct.m
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

#import "TiStorekitProduct.h"
#import "TiStorekitModule.h"
#import "TiUtils.h"

@implementation TiStorekitProduct

- (id)initWithProduct:(SKProduct *)product pageContext:(id<TiEvaluator>)context
{
  if (self = [super _initWithPageContext:context]) {
    _product = product;
  }
  return self;
}

- (SKProduct *)product
{
  return _product;
}

#pragma mark - Public API

- (NSString *)description
{
  return [_product localizedDescription];
}

- (NSString *)title
{
  return [_product localizedTitle];
}

- (NSDecimalNumber *)price
{
  return [_product price];
}

- (NSString *)formattedPrice
{
  NSNumberFormatter *formatter = [[NSNumberFormatter alloc] init];
  [formatter setFormatterBehavior:NSNumberFormatterBehavior10_4];
  [formatter setNumberStyle:NSNumberFormatterCurrencyStyle];
  [formatter setLocale:_product.priceLocale];
  return [formatter stringFromNumber:_product.price];
}

- (NSString *)locale
{
  return [_product.priceLocale localeIdentifier];
}

- (NSString *)identifier
{
  return [_product productIdentifier];
}

- (TiStorekitProductDiscountProxy *)introductoryPrice
{
  if (@available(iOS 11.2, *)) {
    if (!_product.introductoryPrice) { return nil; }
    return [[TiStorekitProductDiscountProxy alloc]
        initWithProductDiscount:_product.introductoryPrice
                    pageContext:self.pageContext];
  }
  NSLog(@"[WARN] Ti.Storekit: introductoryPrice requires iOS 11.2+.");
  return nil;
}

- (NSDictionary *)subscriptionPeriod
{
  if (@available(iOS 11.2, *)) {
    if (!_product.subscriptionPeriod) { return @{}; }
    return @{
      @"numberOfUnits": @(_product.subscriptionPeriod.numberOfUnits),
      @"unit":          @(_product.subscriptionPeriod.unit)
    };
  }
  NSLog(@"[WARN] Ti.Storekit: subscriptionPeriod requires iOS 11.2+.");
  return @{};
}

@end

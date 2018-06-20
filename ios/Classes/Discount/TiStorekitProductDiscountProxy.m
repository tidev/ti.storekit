/**
 * Appcelerator Titanium Mobile
 * Copyright (c) 2009-2017 by Appcelerator, Inc. All Rights Reserved.
 * Licensed under the terms of the Apache Public License
 * Please see the LICENSE included with this distribution for details.
 */

#import "TiStorekitProductDiscountProxy.h"

@implementation TiStorekitProductDiscountProxy

- (id)initWithProductDiscount:(SKProductDiscount *)productDiscount pageContext:(id<TiEvaluator>)context
{
  if (self = [super _initWithPageContext:context]) {
    _productDiscount = productDiscount;
  }
  
  return self;
}

- (NSNumber *)price
{
  return _productDiscount.price;
}

- (NSString *)priceLocale
{
  return _productDiscount.priceLocale.localeIdentifier;
}

- (NSDictionary *)subscriptionPeriod
{
  if (_productDiscount.subscriptionPeriod == nil) {
    return @{};
  }

  return @{
    @"numberOfUnits": @(_productDiscount.subscriptionPeriod.numberOfUnits),
    @"unit": @(_productDiscount.subscriptionPeriod.unit),
  };
}

- (NSNumber *)numberOfPeriods
{
  return @(_productDiscount.numberOfPeriods);
}

- (NSNumber *)paymentMode
{
  return @(_productDiscount.paymentMode);
}

@end

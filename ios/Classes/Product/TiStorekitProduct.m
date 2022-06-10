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

#pragma mark Public API's

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
  NSNumberFormatter *numberFormatter = [[NSNumberFormatter alloc] init];
  [numberFormatter setFormatterBehavior:NSNumberFormatterBehavior10_4];
  [numberFormatter setNumberStyle:NSNumberFormatterCurrencyStyle];
  [numberFormatter setLocale:_product.priceLocale];
  NSString *formattedString = [numberFormatter stringFromNumber:_product.price];

  return formattedString;
}

- (NSString *)locale
{
  return [[_product priceLocale] localeIdentifier];
}

- (NSString *)identifier
{
  return [_product productIdentifier];
}

- (NSNumber *)downloadable
{
  return @([_product isDownloadable]);
}

- (NSArray *)downloadContentLengths
{
  return [_product downloadContentLengths];
}

- (NSString *)downloadContentVersion
{
  return [_product downloadContentVersion];
}

#if IS_IOS_11_2
- (TiStorekitProductDiscountProxy *)introductoryPrice
{
  if (![TiUtils isIOSVersionOrGreater:@"11.2"]) {
    DebugLog(@"[ERROR] The \"introductoryPrice\" property is only available on iOS 11.2 and later.");
    return nil;
  }
  
  return [[TiStorekitProductDiscountProxy alloc] initWithProductDiscount:_product.introductoryPrice pageContext:self.pageContext];
}

- (NSDictionary *)subscriptionPeriod
{
  if (![TiUtils isIOSVersionOrGreater:@"11.2"]) {
    DebugLog(@"[ERROR] The \"subscriptionPeriod\" property is only available on iOS 11.2 and later.");
    return @{};
  }
  
  if (_product.subscriptionPeriod == nil) {
    return @{};
  }
  
  return @{
    @"numberOfUnits": @(_product.subscriptionPeriod.numberOfUnits),
    @"unit": @(_product.subscriptionPeriod.unit),
  };
}
#endif

@end

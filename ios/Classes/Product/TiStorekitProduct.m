/**
 * Appcelerator Titanium Mobile
 * Copyright (c) 2010-2013 by Appcelerator, Inc. All Rights Reserved.
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
  return NUMBOOL([_product isDownloadable]);
}

- (NSArray *)downloadContentLengths
{
  return [_product downloadContentLengths];
}

- (NSString *)downloadContentVersion
{
  return [_product downloadContentVersion];
}

@end

/**
 * Appcelerator Titanium Mobile
 * Copyright (c) 2010-2013 by Appcelerator, Inc. All Rights Reserved.
 * Licensed under the terms of the Apache Public License
 * Please see the LICENSE included with this distribution for details.
 */

#import "TiStorekitProduct.h"
#import "TiUtils.h"
#import "TiStorekitModule.h"

@implementation TiStorekitProduct

- (id)initWithProduct:(SKProduct *)product_ pageContext:(id<TiEvaluator>)context
{
    if (self = [super _initWithPageContext:context]) {
        product = product_;
    }
    return self;
}

- (SKProduct *)product
{
    return product;
}

#pragma mark Public APIs

- (NSString *)description
{
    return [product localizedDescription];
}

- (NSString *)title
{
    return [product localizedTitle];
}

- (NSDecimalNumber *)price
{
    return [product price];
}

- (NSString*)formattedPrice
{
    NSNumberFormatter *numberFormatter = [[NSNumberFormatter alloc] init];
    [numberFormatter setFormatterBehavior:NSNumberFormatterBehavior10_4];
    [numberFormatter setNumberStyle:NSNumberFormatterCurrencyStyle];
    [numberFormatter setLocale:product.priceLocale];
    NSString *formattedString = [numberFormatter stringFromNumber:product.price];

    return formattedString;
}

- (NSString *)locale
{
    return [[product priceLocale] localeIdentifier];
}

- (NSString *)identifier
{
    return [product productIdentifier];
}

- (id)downloadable
{
    return NUMBOOL([product isDownloadable]);
}

- (NSArray *)downloadContentLengths
{
    return [product downloadContentLengths];
}

- (NSString *)downloadContentVersion
{
    return [product downloadContentVersion];
}

@end

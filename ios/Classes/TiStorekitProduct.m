/**
 * Appcelerator Titanium Mobile
 * Copyright (c) 2010-2013 by Appcelerator, Inc. All Rights Reserved.
 * Licensed under the terms of the Apache Public License
 * Please see the LICENSE included with this distribution for details.
 */

#import "TiStoreKitProduct.h"
#import "TiUtils.h"
#import "TiStorekitModule.h"

@implementation TiStorekitProduct

-(id)initWithProduct:(SKProduct*)product_ pageContext:(id<TiEvaluator>)context
{
    if (self = [super _initWithPageContext:context])
    {
        product = [product_ retain];
    }
    return self;
}

-(void)_destroy
{
    RELEASE_TO_NIL(product);
    [super _destroy];
}

-(SKProduct*)product
{
    return product;
}

#pragma mark Public APIs

-(NSString*)description 
{
    return [product localizedDescription];
}

-(NSString*)title
{
    return [product localizedTitle];
}

-(NSDecimalNumber*)price
{
    return [product price];
}

-(NSString*)formattedPrice
{
    NSNumberFormatter *numberFormatter = [[NSNumberFormatter alloc] init];
    [numberFormatter setFormatterBehavior:NSNumberFormatterBehavior10_4];
    [numberFormatter setNumberStyle:NSNumberFormatterCurrencyStyle];
    [numberFormatter setLocale:product.priceLocale];
    NSString *formattedString = [numberFormatter stringFromNumber:product.price];
    [numberFormatter release];
    return formattedString;
}

-(NSString*)locale
{
    return [[product priceLocale] localeIdentifier];
}

-(NSString*)identifier
{
    return [product productIdentifier];
}

-(id)downloadable
{
    if (![TiUtils isIOS6OrGreater]) {
        [TiStorekitModule logAddedIniOS6Warning:@"downloadable"];
    }
    
    if ([product respondsToSelector:@selector(isDownloadable)]) {
        return NUMBOOL([product performSelector:@selector(isDownloadable)]);
    }
    
    return NUMBOOL(NO);
}

-(NSArray*)downloadContentLengths
{
    if (![TiUtils isIOS6OrGreater]) {
        [TiStorekitModule logAddedIniOS6Warning:@"downloadContentLengths"];
    }
    
    if ([product respondsToSelector:@selector(downloadContentLengths)]) {
        return [product performSelector:@selector(downloadContentLengths)];
    }
    
    return nil;
}

-(NSString*)downloadContentVersion
{
    if (![TiUtils isIOS6OrGreater]) {
        [TiStorekitModule logAddedIniOS6Warning:@"downloadContentVersion"];
    }
    
    if ([product respondsToSelector:@selector(downloadContentVersion)]) {
        return [product performSelector:@selector(downloadContentVersion)];
    }
    
    return nil;
}

@end

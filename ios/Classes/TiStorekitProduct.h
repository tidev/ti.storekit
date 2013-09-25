/**
 * Ti.Storekit Module
 * Copyright (c) 2010-2013 by Appcelerator, Inc. All Rights Reserved.
 * Please see the LICENSE included with this distribution for details.
 */

#import "TiProxy.h"
#import <StoreKit/StoreKit.h>

@interface TiStorekitProduct : TiProxy {
@private
	SKProduct *product;
}

-(id)initWithProduct:(SKProduct*)product pageContext:(id<TiEvaluator>)context;

-(SKProduct*)product;

@end

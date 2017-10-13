/**
 * Appcelerator Titanium Mobile
 * Copyright (c) 2010-2013 by Appcelerator, Inc. All Rights Reserved.
 * Licensed under the terms of the Apache Public License
 * Please see the LICENSE included with this distribution for details.
 */

#import "KrollCallback.h"
#import "TiProxy.h"
#import <StoreKit/StoreKit.h>

@interface TiStorekitProductRequest : TiProxy <SKProductsRequestDelegate> {
  @private
  KrollCallback *_callback;
  SKProductsRequest *_request;
}

- (id)initWithProductIdentifiers:(NSSet *)set callback:(KrollCallback *)callback pageContext:(id<TiEvaluator>)context;

#pragma mark Public API's

- (void)cancel:(id)args;

@end

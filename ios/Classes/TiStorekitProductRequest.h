/**
 * Ti.Storekit Module
 * Copyright (c) 2010-2013 by Appcelerator, Inc. All Rights Reserved.
 * Please see the LICENSE included with this distribution for details.
 */

#import <StoreKit/StoreKit.h>
#import "TiProxy.h"
#import "KrollCallback.h"


@interface TiStorekitProductRequest : TiProxy <SKProductsRequestDelegate> {
@private
	KrollCallback *callback;
	SKProductsRequest* request;
}

-(id)initWithProductIdentifiers:(NSSet*)set callback:(KrollCallback*)callback pageContext:(id<TiEvaluator>)context;

@end

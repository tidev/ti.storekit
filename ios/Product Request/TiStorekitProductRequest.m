//
//  TiStorekitProductRequest.m
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

#import "TiStorekitProductRequest.h"
#import "TiStorekitModule.h"
#import "TiStorekitProduct.h"

@implementation TiStorekitProductRequest

- (id)initWithProductIdentifiers:(NSSet *)set
                        callback:(KrollCallback *)callback
                     pageContext:(id<TiEvaluator>)context
{
  if ((self = [super _initWithPageContext:context])) {
    _request          = [[SKProductsRequest alloc] initWithProductIdentifiers:set];
    _request.delegate = self;
    _callback         = callback;
    [_request performSelectorOnMainThread:@selector(start) withObject:nil waitUntilDone:NO];
    [self rememberSelf];
  }
  return self;
}

- (void)cancel:(id)args
{
  if (_request) {
    [self forgetSelf];
    [_request cancel];
  }
}

#pragma mark - SKProductsRequestDelegate

- (void)productsRequest:(SKProductsRequest *)request
     didReceiveResponse:(SKProductsResponse *)response
{
  NSMutableArray *products = [NSMutableArray arrayWithCapacity:response.products.count];
  for (SKProduct *product in response.products) {
    [products addObject:[[TiStorekitProduct alloc] initWithProduct:product
                                                       pageContext:[self executionContext]]];
  }

  NSMutableDictionary *event = [NSMutableDictionary dictionaryWithObjectsAndKeys:
                                 products, @"products",
                                 @(YES),   @"success",
                                 nil];

  NSArray *invalid = response.invalidProductIdentifiers;
  if (invalid.count > 0) {
    event[@"invalid"] = invalid;
  }

  [self _fireEventToListener:@"callback" withObject:event listener:_callback thisObject:nil];
  [self forgetSelf];
}

- (void)request:(SKRequest *)request didFailWithError:(NSError *)error
{
  NSLog(@"[ERROR] Ti.Storekit: Product request failed — %@", [TiStorekitModule descriptionFromError:error]);
  NSDictionary *event = @{
    @"success": @(NO),
    @"message": [TiStorekitModule descriptionFromError:error]
  };
  [self _fireEventToListener:@"callback" withObject:event listener:_callback thisObject:nil];
  [self forgetSelf];
}

@end

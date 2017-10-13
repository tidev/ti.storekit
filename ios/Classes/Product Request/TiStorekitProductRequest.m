/**
 * Appcelerator Titanium Mobile
 * Copyright (c) 2010-2013 by Appcelerator, Inc. All Rights Reserved.
 * Licensed under the terms of the Apache Public License
 * Please see the LICENSE included with this distribution for details.
 */

#import "TiStorekitProductRequest.h"
#import "TiStorekitModule.h"
#import "TiStorekitProduct.h"

@implementation TiStorekitProductRequest

- (id)initWithProductIdentifiers:(NSSet *)set callback:(KrollCallback *)callback pageContext:(id<TiEvaluator>)context
{
  if ((self = [super _initWithPageContext:context])) {
    _request = [[SKProductsRequest alloc] initWithProductIdentifiers:set];
    _request.delegate = self;
    _callback = callback;
    [_request performSelectorOnMainThread:@selector(start) withObject:nil waitUntilDone:NO];
    [self rememberSelf];
  }
  return self;
}

#pragma mark Public API's

- (void)cancel:(id)args
{
  if (_request != nil) {
    [self forgetSelf];
    [_request cancel];
  }
}

#pragma mark Delegate

- (void)productsRequest:(SKProductsRequest *)request didReceiveResponse:(SKProductsResponse *)response
{
  NSMutableArray *products = [NSMutableArray arrayWithCapacity:[[response products] count]];

  for (SKProduct *product in [response products]) {
    TiStorekitProduct *p = [[TiStorekitProduct alloc] initWithProduct:product pageContext:[self executionContext]];
    [products addObject:p];
  }

  NSMutableDictionary *event = [[NSMutableDictionary alloc] init];

  [event setObject:products forKey:@"products"];
  [event setObject:NUMBOOL(YES) forKey:@"success"];

  NSArray *invalid = [response invalidProductIdentifiers];
  if (invalid != nil && [invalid count] > 0) {
    [event setObject:invalid forKey:@"invalid"];
  }

  [self _fireEventToListener:@"callback" withObject:event listener:_callback thisObject:nil];
  [self forgetSelf];
}

- (void)request:(SKRequest *)request didFailWithError:(NSError *)error
{
  NSLog(@"[ERROR] received error %@", [TiStorekitModule descriptionFromError:error]);
  NSDictionary *event = @{ @"success": NUMBOOL(NO), @"message": [TiStorekitModule descriptionFromError:error] };
  [self _fireEventToListener:@"callback" withObject:event listener:_callback thisObject:nil];

  [self forgetSelf];
}

@end

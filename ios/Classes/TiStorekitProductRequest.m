/**
 * Appcelerator Titanium Mobile
 * Copyright (c) 2010-2013 by Appcelerator, Inc. All Rights Reserved.
 * Licensed under the terms of the Apache Public License
 * Please see the LICENSE included with this distribution for details.
 */

#import "TiStorekitProductRequest.h"
#import "TiStorekitProduct.h"
#import "TiStorekitModule.h"


@implementation TiStorekitProductRequest

- (id)initWithProductIdentifiers:(NSSet *)set callback:(KrollCallback *)callback_ pageContext:(id<TiEvaluator>)context
{
    if ((self = [super _initWithPageContext:context])) {
        request = [[SKProductsRequest alloc] initWithProductIdentifiers:set];
        request.delegate = self;
        callback = callback_;
        [request performSelectorOnMainThread:@selector(start) withObject:nil waitUntilDone:NO];
        [self rememberSelf];
    }
    return self;
}

#pragma mark Public APIs

- (void)cancel:(id)args
{
    if (request != nil) {
        [self forgetSelf];
        [request cancel];
    }
}

#pragma mark Delegate

- (void)productsRequest:(SKProductsRequest *)request didReceiveResponse:(SKProductsResponse *)response
{
    NSMutableArray *good = [NSMutableArray arrayWithCapacity:[[response products]count]];

    for (SKProduct * product in [response products])
    {
        TiStorekitProduct *p = [[TiStorekitProduct alloc] initWithProduct:product pageContext:[self executionContext]];
        [good addObject:p];
    }
    
    NSMutableDictionary *event = [[NSMutableDictionary alloc] init];
    
    [event setObject:good forKey:@"products"];
    [event setObject:NUMBOOL(YES) forKey:@"success"];
    
    NSArray *invalid = [response invalidProductIdentifiers];
    if (invalid != nil && [invalid count] > 0) {
        [event setObject:invalid forKey:@"invalid"];
    }
    
    [self _fireEventToListener:@"callback" withObject:event listener:callback thisObject:nil];
    [self forgetSelf];
}

- (void)request:(SKRequest *)request didFailWithError:(NSError *)error 
{
    NSLog(@"[ERROR] received error %@",[TiStorekitModule descriptionFromError:error]);
    NSDictionary *event = [NSDictionary dictionaryWithObjectsAndKeys:NUMBOOL(NO),@"success",[TiStorekitModule descriptionFromError:error],@"message",nil];
    [self _fireEventToListener:@"callback" withObject:event listener:callback thisObject:nil];
    
    [self forgetSelf];
}

@end

/**
 * Appcelerator Titanium Mobile
 * Copyright (c) 2010-2013 by Appcelerator, Inc. All Rights Reserved.
 * Licensed under the terms of the Apache Public License
 * Please see the LICENSE included with this distribution for details.
 */

#import "TiStorekitReceiptRequest.h"
#import "TiUtils.h"
#import "TiApp.h"
#import "TiStorekitModule.h"

@implementation TiStorekitReceiptRequest

-(id)initWithData:(NSData*)data callback:(KrollCallback*)callback_ pageContext:(id<TiEvaluator>)context productIdentifier:(NSString*)productIdentifier_ quantity:(NSInteger)quantity_ transactionIdentifier:(NSString*)transactionIdentifier_;
{
	if ((self = [super _initWithPageContext:context]))
	{
		callback = [callback_ retain];
        verifier = [[Verifier alloc] initWithReceipt:data delegate:self productIdentifer:productIdentifier_ quantity:quantity_ transactionIdentifier:transactionIdentifier_];
	}
	return self;
}

-(void)dealloc
{
	RELEASE_TO_NIL(callback);
    RELEASE_TO_NIL(verifier);
	[super dealloc];
}

-(BOOL)verify:(BOOL)sandbox_ secret:(NSString*)secret_
{
    NSError *error = nil;

    [self rememberSelf];
    if ([verifier verifyPurchase:sandbox_ sharedSecret:secret_ error:&error]) {
        return YES;
    }
    [self forgetSelf];
    
    NSDictionary *event = [NSDictionary dictionaryWithObjectsAndKeys:NUMBOOL(NO),@"valid",NUMBOOL(NO),@"success",[TiStorekitModule descriptionFromError:error],@"message",nil];
    [self _fireEventToListener:@"callback" withObject:event listener:callback thisObject:nil];
    RELEASE_TO_NIL(verifier);
    
    return NO;
}

-(void)cancel:(id)args
{
    NSDictionary *event = [NSDictionary dictionaryWithObjectsAndKeys:NUMBOOL(NO),@"valid",NUMBOOL(NO),@"success",@"cancelled",@"message",NUMBOOL(YES),@"cancelled",nil];
    [self _fireEventToListener:@"callback" withObject:event listener:callback thisObject:nil];
    if (verifier) {
        [self forgetSelf];
        [verifier cancel];
        RELEASE_TO_NIL(verifier);
    }
}

#pragma mark Delegates

- (void)verifierDidVerifyPurchase:(Verifier*)verifier_ isValid:(BOOL)isValid error:(NSError *)error
{
	NSMutableDictionary *event = [NSMutableDictionary dictionaryWithCapacity:3];
    [event setObject:NUMBOOL(isValid) forKey:@"valid"];
    [event setObject:NUMBOOL(YES) forKey:@"success"];
    if (isValid) {
        if (verifier_.transactionIdentifier) {
            [event setObject:verifier_.transactionIdentifier forKey:@"identifier"];
        }
        [event setObject:NUMINT(verifier_.quantity) forKey:@"quantity"];
        if (verifier_.productIdentifier) {
            [event setObject:verifier_.productIdentifier forKey:@"productIdentifier"];        
        }
        
        // NOTE: Make sure to use a blob and not an NSData object. Setting a property to an NSData object
        // will result in a non-descript kroll context 'boundBridge' error that really means that it was
        // an unrecognized data type that it couldn't convert.
        TiBlob *blob = [[TiBlob alloc] initWithData:verifier_.receipt mimetype:@"text/json"];
        [event setObject:blob forKey:@"receipt"];
        [blob release];
    } else {      
        [event setObject:[TiStorekitModule descriptionFromError:error] forKey:@"message"];
    }
	[self _fireEventToListener:@"callback" withObject:event listener:callback thisObject:nil];  
    
    [self forgetSelf];
}

- (void)verifierDidFailToVerifyPurchase:(Verifier*)verifier_ error:(NSError*)error 
{
	NSDictionary *event = [NSDictionary dictionaryWithObjectsAndKeys:NUMBOOL(NO),@"valid",NUMBOOL(NO),@"success",[TiStorekitModule descriptionFromError:error],@"message",nil];
	[self _fireEventToListener:@"callback" withObject:event listener:callback thisObject:nil];
    
    [self forgetSelf];
}

@end

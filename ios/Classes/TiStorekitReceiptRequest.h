/**
 * Ti.Storekit Module
 * Copyright (c) 2010-2013 by Appcelerator, Inc. All Rights Reserved.
 * Please see the LICENSE included with this distribution for details.
 */

#import "TiProxy.h"
#import "Verifier.h"

@interface TiStorekitReceiptRequest : TiProxy <VerifierDelegate> {
@private
	KrollCallback *callback;
    Verifier* verifier;
}

-(id)initWithData:(NSData*)data callback:(KrollCallback*)callback_ pageContext:(id<TiEvaluator>)context productIdentifier:(NSString*)productIdentifier_ quantity:(NSInteger)quantity_ transactionIdentifier:(NSString*)transactionIdentifier_;

-(BOOL)verify:(BOOL)sandbox_ secret:(NSString*)secret_;

@end

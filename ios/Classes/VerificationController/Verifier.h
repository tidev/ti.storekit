/**
 * Appcelerator Titanium Mobile
 * Copyright (c) 2012-2013 by Appcelerator, Inc. All Rights Reserved.
 *
 * The original source for this file was provided by Apple to deal with a vulnerability
 * discovered in iOS 5.1 and earlier.
 * https://developer.apple.com/library/ios/#releasenotes/StoreKit/IAP_ReceiptValidation/_index.html#//apple_ref/doc/uid/TP40012484
 *
 * Adapted the delegate-based system from https://github.com/evands/iap_validation
 */
#import <Foundation/Foundation.h>
#import <StoreKit/StoreKit.h>

@class Verifier;

@protocol VerifierDelegate

- (void)verifierDidVerifyPurchase:(Verifier*)verifier isValid:(BOOL)isValid error:(NSError*)error;
- (void)verifierDidFailToVerifyPurchase:(Verifier*)verifier error:(NSError*)error;

@end

@interface Verifier : NSObject {
    NSObject<VerifierDelegate> *delegate;
    SKPaymentTransaction *transaction;
    
    NSData* receipt;
    NSString* productIdentifier;
    NSString* transactionIdentifier;
    NSDictionary *originalPurchaseInfoDict;
    NSMutableData *receivedData;
    NSInteger quantity;    
    
    NSURLConnection *conn;
}

-(id)initWithTransaction:(SKPaymentTransaction*)transaction_ delegate:(NSObject<VerifierDelegate>*)delegate_;

-(id)initWithReceipt:(NSData*)receipt_ delegate:(NSObject<VerifierDelegate>*)delegate_ productIdentifer:(NSString*)productIdentifier_ quantity:(NSInteger)quantity_ transactionIdentifier:(NSString*)transactionIdentifier_;

-(BOOL)verifyPurchase:(BOOL)sandbox sharedSecret:(NSString*)sharedSecret error:(NSError**)error;
-(void)cancel;

-(NSData*)receipt;
-(SKPaymentTransaction*)transaction;
-(NSString*)productIdentifier;
-(NSString*)transactionIdentifier;
-(NSInteger)quantity;


@end

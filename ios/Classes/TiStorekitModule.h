/**
 * Ti.Storekit Module
 * Copyright (c) 2010-2013 by Appcelerator, Inc. All Rights Reserved.
 * Please see the LICENSE included with this distribution for details.
 */

#import "TiModule.h"
#import <StoreKit/StoreKit.h>

@interface TiStorekitModule : TiModule <SKPaymentTransactionObserver>
{
@private
    NSMutableArray *restoredTransactions;
    BOOL receiptVerificationSandbox;
}

@property(nonatomic,readonly) NSNumber *PURCHASING;
@property(nonatomic,readonly) NSNumber *PURCHASED;
@property(nonatomic,readonly) NSNumber *FAILED;
@property(nonatomic,readonly) NSNumber *RESTORED;

@property(nonatomic,copy) NSString* receiptVerificationSharedSecret;

@end

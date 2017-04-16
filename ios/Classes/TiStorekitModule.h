/**
 * Appcelerator Titanium Mobile
 * Copyright (c) 2010-2013 by Appcelerator, Inc. All Rights Reserved.
 * Licensed under the terms of the Apache Public License
 * Please see the LICENSE included with this distribution for details.
 */

#import "TiModule.h"
#import <StoreKit/StoreKit.h>

@interface TiStorekitModule : TiModule <SKPaymentTransactionObserver, SKRequestDelegate>
{
@private
    NSMutableArray *restoredTransactions;
    BOOL receiptVerificationSandbox;
    NSString *bundleVersion;
    NSString *bundleIdentifier;
    KrollCallback *refreshReceiptCallback;
    BOOL autoFinishTransactions;
    BOOL transactionObserverSet;
}

@property(nonatomic,readonly) NSNumber *TRANSACTION_STATE_PURCHASING;
@property(nonatomic,readonly) NSNumber *TRANSACTION_STATE_PURCHASED;
@property(nonatomic,readonly) NSNumber *TRANSACTION_STATE_FAILED;
@property(nonatomic,readonly) NSNumber *TRANSACTION_STATE_RESTORED;
@property(nonatomic,readonly) NSNumber *TRANSACTION_STATE_DEFERRED;

@property(nonatomic,readonly) NSNumber *DOWNLOAD_STATE_WAITING;
@property(nonatomic,readonly) NSNumber *DOWNLOAD_STATE_ACTIVE;
@property(nonatomic,readonly) NSNumber *DOWNLOAD_STATE_PAUSED;
@property(nonatomic,readonly) NSNumber *DOWNLOAD_STATE_FINISHED;
@property(nonatomic,readonly) NSNumber *DOWNLOAD_STATE_FAILED;
@property(nonatomic,readonly) NSNumber *DOWNLOAD_STATE_CANCELLED;

@property(nonatomic,readonly) NSNumber *DOWNLOAD_TIME_REMAINING_UNKNOWN;

@property(nonatomic,copy) NSString* receiptVerificationSharedSecret;

+ (TiStorekitModule *)sharedInstance;
+ (NSString *)descriptionFromError:(NSError *)error;
- (NSArray *)tiDownloadsFromSKDownloads:(NSArray *)downloads;
- (NSArray *)skDownloadsFromTiDownloads:(NSArray *)downloads;

@end

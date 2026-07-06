/**
 * Appcelerator Titanium Mobile
 * Copyright (c) 2010-present by Appcelerator, Inc. All Rights Reserved.
 * Licensed under the terms of the Apache Public License
 * Please see the LICENSE included with this distribution for details.
 *
 * Ti.Storekit — rewritten for iOS 17+ / StoreKit 2
 * Breaking changes vs. v4.x:
 *   - Local receipt validation (OpenSSL) removed; use validateReceiptWithServer
 *   - SKDownload deprecated by Apple in iOS 16 (hosted content no longer supported)
 *     Downloads are included with deprecation warnings — migrate to On-Demand Resources
 */

#import "TiModule.h"
#import <StoreKit/StoreKit.h>

@class TiStorekitDownload;

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"

@interface TiStorekitModule : TiModule <SKPaymentTransactionObserver,
                                        SKRequestDelegate,
                                        SKStoreProductViewControllerDelegate,
                                        SKCloudServiceSetupViewControllerDelegate> {
  @private
  NSMutableArray *_restoredTransactions;
  KrollCallback  *_refreshReceiptCallback;
  BOOL            _autoFinishTransactionsEnabled;
  BOOL            _isTransactionObserverSet;
}

// ─── Transaction state constants ──────────────────────────────────────────────
@property (nonatomic, readonly) NSNumber *TRANSACTION_STATE_PURCHASING;
@property (nonatomic, readonly) NSNumber *TRANSACTION_STATE_PURCHASED;
@property (nonatomic, readonly) NSNumber *TRANSACTION_STATE_FAILED;
@property (nonatomic, readonly) NSNumber *TRANSACTION_STATE_RESTORED;
@property (nonatomic, readonly) NSNumber *TRANSACTION_STATE_DEFERRED;

// ─── Download state constants (deprecated in iOS 16) ──────────────────────────
// ⚠️ SKDownload was deprecated in iOS 16. Apple recommends migrating to
//    On-Demand Resources (ODR). These constants are kept for backwards compatibility.
@property (nonatomic, readonly) NSNumber *DOWNLOAD_STATE_WAITING;
@property (nonatomic, readonly) NSNumber *DOWNLOAD_STATE_ACTIVE;
@property (nonatomic, readonly) NSNumber *DOWNLOAD_STATE_PAUSED;
@property (nonatomic, readonly) NSNumber *DOWNLOAD_STATE_FINISHED;
@property (nonatomic, readonly) NSNumber *DOWNLOAD_STATE_FAILED;
@property (nonatomic, readonly) NSNumber *DOWNLOAD_STATE_CANCELLED;
@property (nonatomic, readonly) NSNumber *DOWNLOAD_TIME_REMAINING_UNKNOWN;

// ─── Subscription status constants (iOS 15+) ──────────────────────────────────
@property (nonatomic, readonly) NSString *SUBSCRIPTION_STATE_SUBSCRIBED;
@property (nonatomic, readonly) NSString *SUBSCRIPTION_STATE_EXPIRED;
@property (nonatomic, readonly) NSString *SUBSCRIPTION_STATE_IN_BILLING_RETRY;
@property (nonatomic, readonly) NSString *SUBSCRIPTION_STATE_IN_GRACE_PERIOD;
@property (nonatomic, readonly) NSString *SUBSCRIPTION_STATE_REVOKED;
@property (nonatomic, readonly) NSString *SUBSCRIPTION_STATE_UNKNOWN;

// ─── Discount / period constants (iOS 11.2+) ──────────────────────────────────
@property (nonatomic, readonly) NSNumber *DISCOUNT_PAYMENT_MODE_PAY_AS_YOU_GO;
@property (nonatomic, readonly) NSNumber *DISCOUNT_PAYMENT_MODE_PAY_UP_FRONT;
@property (nonatomic, readonly) NSNumber *DISCOUNT_PAYMENT_MODE_FREE_TRIAL;

@property (nonatomic, readonly) NSNumber *PERIOD_UNIT_DAY;
@property (nonatomic, readonly) NSNumber *PERIOD_UNIT_WEEK;
@property (nonatomic, readonly) NSNumber *PERIOD_UNIT_MONTH;
@property (nonatomic, readonly) NSNumber *PERIOD_UNIT_YEAR;

// ─── Shared instance ──────────────────────────────────────────────────────────
+ (TiStorekitModule *)sharedInstance;
+ (NSString *)descriptionFromError:(NSError *)error;
+ (NSInteger)errorCodeFromError:(NSError *)error;

// ─── Download helpers (deprecated in iOS 16) ──────────────────────────────────
- (NSArray *)tiDownloadsFromStoreKitDownloads:(NSArray *)downloads;
- (NSArray *)storeKitDownloadsFromTiDownloads:(NSArray *)downloads;

// ─── Public API ───────────────────────────────────────────────────────────────
- (void)showProductDialog:(id)args;
- (void)showCloudSetupDialog:(id)args;
- (void)requestReviewDialog:(id)unused;
- (void)showManageSubscriptions:(id)unused;
- (void)getSubscriptionStatus:(id)args;

// ─── Download API (deprecated in iOS 16) ──────────────────────────────────────
// ⚠️ SKDownload was deprecated in iOS 16. Migrate to On-Demand Resources (ODR).
- (void)startDownloads:(id)args;
- (void)cancelDownloads:(id)args;
- (void)pauseDownloads:(id)args;
- (void)resumeDownloads:(id)args;

@end

#pragma clang diagnostic pop

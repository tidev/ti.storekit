# Change Log

## v6.0.0
- **BREAKING**: Removed `validateReceipt()` — Apple deprecated on-device receipt validation with OpenSSL
- **BREAKING**: Removed `verifyReceipt()` — use `validateReceiptWithServer()` or the App Store Server API
- **BREAKING**: Removed `bundleVersion`, `bundleIdentifier`, `receiptVerificationSandbox` properties
- **BREAKING**: Removed `VerifyStoreReceipt` / OpenSSL dependency entirely
- **BREAKING**: Removed Apple-hosted download proxy (`TiStorekitDownload` kept but deprecated)
- **BREAKING**: `restoreCompletedTransactionsWithApplicationUsername` merged into `restoreCompletedTransactions({ username })`
- Added `originalTransactionId` to the `transactionState` event — use for App Store Server API validation
- Added `receiptBase64` convenience property — Base64 receipt string for server-side validation
- Added `validateReceiptWithServer()` — server-side validation via Apple `/verifyReceipt` (deprecated by Apple, kept for compatibility)
- Added `showManageSubscriptions()` — opens system subscription management sheet (iOS 15+)
- Added `getSubscriptionStatus()` — queries current subscription state via SK1 queue (iOS 15+)
- Added `SUBSCRIPTION_STATE_*` constants
- Added `showCloudSetupDialog()` — cloud service setup dialog (Apple Music etc.)
- Added `errorCode` and `retryable` fields to `TRANSACTION_STATE_FAILED` event
- Updated `requestReviewDialog()` to scene-based API `requestReviewInScene:` (iOS 14+)
- `SKDownload` and related APIs marked deprecated (Apple deprecated in iOS 16) — kept for backwards compatibility
- Rebuilt for iOS 17+ / Titanium SDK 13+

## v4.3.0
- Support for the iOS 11.2+ `Discount` API

## v4.2.0
- Support for the iOS 11+ property `allowedStorePaymentProductIdentifiers`

## v4.1.0
- Support for `requestReviewDialog()`
- Support for `showProductDialog()`
- Support for `showCloudSetupDialog()`
- Update OpenSSL to 1.0.2k

## v4.0.1
- Return the `receipt` as a String using the recommended `[NSBundle appstoreReceiptURL]` method
- Use the `CFBundleVersion` instead of `CFBundleShortVersionString` as recommended by Apple

## v4.0.0
- Build with latest Ti.SDK 6.0.3.GA
- Support the new `restoreCompletedTransactionsWithApplicationUsername` method
- Remove the `verifyReceipt` method in favor of the `validateReceipt` method
- Update example to be more descriptive

## v3.1.2
- Fixed app failing to build when including module and building with TiSDK 3.5.0.GA

## v3.1.1
- Updated architectures in manifest

## v3.1.0
- Updated to build for 64-bit

## v3.0.0
- Add support for new iOS 7 receipt
- Add support for the download of Apple hosted IAP
- Added `addTransactionObserver` function — must be called at app startup after event listeners are added
- DEPRECATED passing arguments to `purchase` individually — pass as dictionary instead
- DEPRECATED `PURCHASING`, `PURCHASED`, `FAILED`, `RESTORED` constants in favor of `TRANSACTION_STATE_*` prefixed ones

## v2.1.0
- Include original transaction information for restored transactions

## v2.0.0
- Refactored purchase workflow to use events instead of callbacks

## v1.6.0
- Include receipt in restored transaction notification
- Integrated Apple's receipt verification code
- Added `receiptVerificationSandbox` and `receiptVerificationSharedSecret` properties

## v1.1.0
- Added support for `restoredCompletedTransactions`

## v1.0.0
- Initial Release

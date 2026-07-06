# Ti.Storekit Module

## Description

The Storekit module provides access to Apple's In-App Purchase mechanisms. It covers the full purchase lifecycle: product requests, purchases, restores, receipt management, server-side validation via the App Store Server API, subscription management, and store UI dialogs.

## Getting Started

### Install the module

Copy the compiled module to your project:

```bash
{YOUR_PROJECT}/modules/iphone/
```

Add to `tiapp.xml`:

```xml
<modules>
    <module platform="iphone">ti.storekit</module>
</modules>
```

### Require the module

```javascript
var StoreKit = require('ti.storekit');
```

## Important Notes

> **StoreKit does not work in the iOS Simulator.** A warning is logged automatically. Set `suppressSimulatorWarning = true` to disable the alert dialog. Always test on a real device using a Sandbox tester account.

> **`addTransactionObserver` must be called** for `transactionState`, `restoredCompletedTransactions`, and `updatedDownloads` events to fire. Call it early in app startup, but only **after** adding your event listeners.

> **Use a Development Provisioning Profile** with **In-App Purchase** enabled when testing.

> **Agree to all contracts** under App Store Connect → Agreements, Tax, and Banking before testing.

## Breaking Changes in v6.0.0

- `validateReceipt()` removed — Apple deprecated on-device OpenSSL-based validation. Use `validateReceiptWithServer()` or the App Store Server API.
- `verifyReceipt()` removed — same reason as above.
- `bundleVersion`, `bundleIdentifier`, `receiptVerificationSandbox` properties removed.
- `restoreCompletedTransactionsWithApplicationUsername(username)` removed — use `restoreCompletedTransactions({ username: username })` instead.
- `originalTransactionId` added to the `transactionState` event — use this stable identifier for App Store Server API validation instead of the receipt blob.
- `SKDownload` and related APIs kept but marked deprecated (Apple deprecated in iOS 16).

---

## Functions

### addTransactionObserver()

Starts listening for transaction events. Must be called after adding event listeners for `transactionState`, `restoredCompletedTransactions`, and `updatedDownloads`. Called automatically at shutdown via `removeTransactionObserver()`.

### removeTransactionObserver()

Stops listening for transaction events. Called automatically when the app shuts down.

### requestProducts(ids, callback)

Fetches product info from the App Store for one or more product identifiers.

**Parameters:**
- `ids` [Array\<String\>] — Product identifiers as configured in App Store Connect
- `callback` [Function] — Called with:
  - `success` [Boolean] — Whether the request succeeded
  - `message` [String] — Error reason if `success` is `false`
  - `products` [Array\<Ti.Storekit.Product\>] — Valid products
  - `invalid` [Array\<String\>] — Identifiers with no matching product (only present if any were invalid)

Returns a [Ti.Storekit.ProductRequest][] object with a `cancel()` method.

### purchase(args)

Initiates a purchase. The `transactionState` event fires as the transaction progresses.

**Parameters (dictionary):**
- `product` [Ti.Storekit.Product] — **Required.** The product to purchase
- `quantity` [Number] — Optional. Default `1`, max `10`
- `applicationUsername` [String] — Optional. Hashed user identifier for Apple's fraud detection

### restoreCompletedTransactions([args])

Asks the payment queue to restore previous purchases. Fires the `restoredCompletedTransactions` event when complete.

> May prompt the user to authenticate.

**Parameters (optional dictionary):**
- `username` [String] — Optional. Hashed username

### refreshReceipt(args, callback)

Requests a new receipt from Apple. Useful when the receipt is missing or invalid. In Sandbox, you can request a receipt with specific properties to test edge cases.

**Parameters:**
- `args` [Object or null] — Optional properties:
  - `expired` [Number] — `1` to simulate an expired receipt
  - `revoked` [Number] — `1` to simulate a revoked receipt
  - `vpp` [Number] — `1` to simulate a Volume Purchase Plan receipt
- `callback` [Function] — Called with `{ success, error }`

### validateReceiptWithServer(args, callback)

> ⚠️ Apple has deprecated the `/verifyReceipt` endpoint. For new integrations use the App Store Server API with `originalTransactionId`. This method is kept for backwards compatibility.

Validates the receipt against Apple's `/verifyReceipt` endpoint. Automatically retries against the Sandbox endpoint if Apple returns status `21007`.

**Parameters (dictionary):**
- `sandbox` [Boolean] — `true` for Sandbox, `false` for Production
- `sharedSecret` [String] — Required for auto-renewable subscriptions

**Callback event:**
- `success` [Boolean]
- `receiptData` [String] — Base64 receipt (send to your server for production use)
- `appleResponse` [Object] — Parsed JSON from Apple (status, receipt, …)
- `error` [String] — Present when `success` is `false`

### showManageSubscriptions() *(iOS 15+)*

Opens the system subscription management sheet where users can view, change, or cancel their subscriptions.

### getSubscriptionStatus(productId, callback) *(iOS 15+)*

Returns the current subscription state for a given product identifier.

**Callback event:**
- `success` [Boolean]
- `productId` [String]
- `state` [String] — One of the `SUBSCRIPTION_STATE_*` constants
- `error` [String] — Present on failure

### requestReviewDialog() *(iOS 14+)*

Asks StoreKit to request an App Store rating or review from the user. Apple decides internally whether to show the dialog — it will not always appear.

### showProductDialog(args)

Shows an in-app App Store product sheet.

**Valid keys:**
- `id` — iTunes item identifier (`SKStoreProductParameterITunesItemIdentifier`)
- `at` — Affiliate token
- `ct` — Campaign token
- `pt` — Provider token
- `advp` — Advertising partner token

### showCloudSetupDialog(args)

Shows a dialog to help users set up a cloud service such as Apple Music.

**Valid keys:**
- `action` — `SKCloudServiceSetupAction`
- `iTunesItemIdentifier`
- `affiliateTokenKey`
- `campaignTokenKey`

### startDownloads(args) *(deprecated iOS 16)*

Adds downloads to the download queue. Requires `autoFinishTransactions = false`.

**Parameters:** `{ downloads: [Ti.Storekit.Download] }`

### cancelDownloads(args) *(deprecated iOS 16)*

Cancels queued downloads. **Parameters:** `{ downloads: [Ti.Storekit.Download] }`

### pauseDownloads(args) *(deprecated iOS 16)*

Pauses active downloads. **Parameters:** `{ downloads: [Ti.Storekit.Download] }`

### resumeDownloads(args) *(deprecated iOS 16)*

Resumes paused downloads. **Parameters:** `{ downloads: [Ti.Storekit.Download] }`

---

## Properties

### canMakePayments [Boolean] (read-only)

Whether the device and user settings allow In-App Purchases. Check this before showing purchase UI.

### receiptExists [Boolean] (read-only)

Whether a local App Store receipt exists on the device. During development a receipt may not exist — call `refreshReceipt()` to obtain one.

### receipt [TiBlob] (read-only)

The raw App Store receipt as a `TiBlob`. Use `Ti.Utils.base64encode(StoreKit.receipt).text` to get the Base64 string.

### receiptBase64 [String] (read-only)

The App Store receipt as a Base64-encoded string, ready to send to your server.

### autoFinishTransactions [Boolean]

Whether transactions are finished automatically when they reach `PURCHASED`, `FAILED`, or `RESTORED` state. Default `true`.

Set to `false` when using Apple-hosted downloads — finish each transaction manually only after its associated download is complete.

### allowedStorePaymentProductIdentifiers [Array\<String\>] *(iOS 11+)*

An array of product identifiers allowed to be purchased when the user initiates a purchase from outside the app (e.g. from the App Store). If `nil`, all products are allowed.

### suppressSimulatorWarning [Boolean]

Set to `true` to suppress the alert dialog shown when running on the iOS Simulator. Default `false`.

---

## Constants

### Transaction States

| Constant | Description |
|---|---|
| `TRANSACTION_STATE_PURCHASING` | Payment in progress |
| `TRANSACTION_STATE_PURCHASED` | Payment successful |
| `TRANSACTION_STATE_FAILED` | Payment failed or cancelled |
| `TRANSACTION_STATE_RESTORED` | Previous purchase restored |
| `TRANSACTION_STATE_DEFERRED` | Pending Ask to Buy approval |

### Subscription States *(iOS 15+)*

| Constant | Value | Description |
|---|---|---|
| `SUBSCRIPTION_STATE_SUBSCRIBED` | `"subscribed"` | Active subscription |
| `SUBSCRIPTION_STATE_EXPIRED` | `"expired"` | Expired |
| `SUBSCRIPTION_STATE_IN_BILLING_RETRY` | `"inBillingRetryPeriod"` | Billing retry in progress |
| `SUBSCRIPTION_STATE_IN_GRACE_PERIOD` | `"inGracePeriod"` | In grace period |
| `SUBSCRIPTION_STATE_REVOKED` | `"revoked"` | Revoked/refunded |
| `SUBSCRIPTION_STATE_UNKNOWN` | `"unknown"` | State unknown |

### Discount Payment Modes *(iOS 11.2+)*

| Constant | Description |
|---|---|
| `DISCOUNT_PAYMENT_MODE_PAY_AS_YOU_GO` | Charged per billing period at reduced rate |
| `DISCOUNT_PAYMENT_MODE_PAY_UP_FRONT` | Charged once upfront at reduced rate |
| `DISCOUNT_PAYMENT_MODE_FREE_TRIAL` | No charge during the introductory period |

### Subscription Period Units *(iOS 11.2+)*

| Constant | Description |
|---|---|
| `PERIOD_UNIT_DAY` | Daily interval |
| `PERIOD_UNIT_WEEK` | Weekly interval |
| `PERIOD_UNIT_MONTH` | Monthly interval |
| `PERIOD_UNIT_YEAR` | Yearly interval |

### Download States *(deprecated iOS 16)*

| Constant | Description |
|---|---|
| `DOWNLOAD_STATE_WAITING` | Queued, not yet started |
| `DOWNLOAD_STATE_ACTIVE` | Actively downloading |
| `DOWNLOAD_STATE_PAUSED` | Paused |
| `DOWNLOAD_STATE_FINISHED` | Complete |
| `DOWNLOAD_STATE_FAILED` | Failed |
| `DOWNLOAD_STATE_CANCELLED` | Cancelled |
| `DOWNLOAD_TIME_REMAINING_UNKNOWN` | Time estimate unavailable |

---

## Events

### transactionState

Fired when a transaction changes state.

| Property | Type | Description |
|---|---|---|
| `state` | `int` | One of the `TRANSACTION_STATE_*` constants |
| `identifier` | `String` | Transaction identifier (changes each renewal) |
| `originalTransactionId` | `String` | Stable identifier across all renewals — use for App Store Server API |
| `productIdentifier` | `String` | Product identifier |
| `date` | `Date` | Transaction date |
| `quantity` | `int` | Quantity purchased |
| `receipt` | `String` | Base64-encoded App Store receipt |
| `transaction` | `Ti.Storekit.Transaction` | Full transaction object |
| `originalTransaction` | `Ti.Storekit.Transaction` | Original transaction (restored only) |
| `cancelled` | `Boolean` | *(FAILED only)* Whether the user cancelled |
| `message` | `String` | *(FAILED only)* Error description |
| `errorCode` | `int` | *(FAILED only)* SKError code |
| `retryable` | `Boolean` | *(FAILED only)* Whether the error is transient and may resolve on retry |

### restoredCompletedTransactions

Fired when `restoreCompletedTransactions()` completes.

| Property | Type | Description |
|---|---|---|
| `transactions` | `Array<Ti.Storekit.Transaction>` | Restored transactions (on success) |
| `error` | `String` | Error message (on failure) |

### updatedDownloads *(deprecated iOS 16)*

Fired when download progress changes.

| Property | Type | Description |
|---|---|---|
| `downloads` | `Array<Ti.Storekit.Download>` | Updated download objects |

### productDialogDidOpen / productDialogDidClose

Fired when the product dialog opens or closes.

| Property | Type | Description |
|---|---|---|
| `success` | `Boolean` | Whether the dialog loaded successfully (open only) |
| `error` | `String` | Error description if `success` is `false` (open only) |

### cloudSetupDialogDidOpen / cloudSetupDialogDidClose

Fired when the cloud setup dialog opens or closes.

| Property | Type | Description |
|---|---|---|
| `success` | `Boolean` | Whether the dialog loaded successfully (open only) |
| `error` | `String` | Error description if `success` is `false` (open only) |

---

## Helpful Links

- [In-App Purchase — Apple Developer](https://developer.apple.com/in-app-purchase/)
- [App Store Server API](https://developer.apple.com/documentation/appstoreserverapi)
- [Testing In-App Purchases with Sandbox](https://developer.apple.com/documentation/storekit/in-app_purchase/testing_in-app_purchases_with_sandbox)
- [SKDownload — deprecated iOS 16](https://developer.apple.com/documentation/storekit/skdownload)
- [On-Demand Resources Guide](https://developer.apple.com/library/archive/documentation/FileManagement/Conceptual/On_Demand_Resources_Guide/)

---

## Author

Jeff Haynie, Jeff English, Jon Alter, Hans Knöchel, Douglas Alves.

## License

Copyright © 2010-present by Appcelerator, Inc. All Rights Reserved.
Licensed under the Apache Public License. See the LICENSE file for details.

[Ti.Storekit.ProductRequest]: productRequest.md
[Ti.Storekit.Product]: product.md
[Ti.Storekit.Download]: download.md
[Ti.Storekit.Transaction]: transaction.md

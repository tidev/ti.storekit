# Ti.Storekit

> Apple In-App Purchase module for Titanium SDK — rebuilt for iOS 17+ with App Store Server API support.

Ti.Storekit is a comprehensive In-App Purchase solution for Titanium that covers the full purchase lifecycle: product requests, purchases, restores, receipt management, server-side validation via the App Store Server API, subscription management, and store UI dialogs.

![Titanium](https://img.shields.io/badge/Titanium-12.0+-red.svg) ![Platform](https://img.shields.io/badge/platform-iOS-lightgrey.svg) ![iOS](https://img.shields.io/badge/iOS-17.0+-blue.svg) ![License](https://img.shields.io/badge/license-Apache--2.0-blue.svg)

---

### Roadmap

- [x] Full purchase lifecycle (buy, restore, defer)
- [x] App Store Server API validation (replaces deprecated `/verifyReceipt`)
- [x] `originalTransactionId` exposed in `transactionState` event
- [x] Subscription management dialog (iOS 15+)
- [x] Review dialog (iOS 14+)
- [x] Cloud service setup dialog (Apple Music)
- [x] Apple-hosted downloads (deprecated iOS 16 — kept for compatibility)
- [ ] On-Demand Resources — pending ( another module )

---

## Table of Contents

- [Installation](#installation)
- [Quick Start](#quick-start)
- [Features](#features)
  - [Feature 1: Purchase Flow](#feature-1-purchase-flow)
  - [Feature 2: Restore Purchases](#feature-2-restore-purchases)
  - [Feature 3: Server-Side Validation (App Store Server API)](#feature-3-server-side-validation-app-store-server-api)
  - [Feature 4: Receipt Management](#feature-4-receipt-management)
  - [Feature 5: Subscription Management](#feature-5-subscription-management)
  - [Feature 6: Store UI Dialogs](#feature-6-store-ui-dialogs)
  - [Feature 7: Apple-Hosted Downloads](#feature-7-apple-hosted-downloads-deprecated-ios-16)
- [API Reference](#api-reference)
- [Breaking Changes in v5.0](#breaking-changes-in-v50)
- [Testing](#testing)
- [License](#license)

---

## Installation

### 1. Download the module

Download the latest compiled module from the [releases page](https://github.com/deckameron/ti.storekit/releases).

### 2. Install in your Titanium project

```bash
# Copy the compiled module to:
{YOUR_PROJECT}/modules/iphone/
```

### 3. Configure tiapp.xml

```xml
<modules>
    <module platform="iphone">ti.storekit</module>
</modules>
```

### 4. Require in JavaScript

```javascript
var StoreKit = require('ti.storekit');
```

---

## Quick Start

```javascript
var StoreKit = require('ti.storekit');

// 1. Register event listeners BEFORE adding the transaction observer
StoreKit.addEventListener('transactionState', function(evt) {
    if (evt.state === StoreKit.TRANSACTION_STATE_PURCHASED) {
        console.log('Purchased! originalTransactionId:', evt.originalTransactionId);
        evt.transaction && evt.transaction.finish();
    }
});

StoreKit.addEventListener('restoredCompletedTransactions', function(evt) {
    console.log('Restored:', evt.transactions.length, 'transactions');
});

// 2. Add transaction observer early in app startup
StoreKit.addTransactionObserver();

// 3. Request product info
StoreKit.requestProducts(['com.example.app.premium'], function(evt) {
    if (evt.success && evt.products.length > 0) {
        var product = evt.products[0];
        console.log(product.title, product.formattedPrice);

        // 4. Purchase
        StoreKit.purchase({ product: product });
    }
});
```

---

## Features

### Feature 1: Purchase Flow

Complete purchase lifecycle with support for all transaction states.

#### Basic Purchase

```javascript
var StoreKit = require('ti.storekit');

StoreKit.autoFinishTransactions = true; // default — finish automatically

StoreKit.addEventListener('transactionState', function(evt) {
    switch (evt.state) {

        case StoreKit.TRANSACTION_STATE_PURCHASING:
            console.log('Processing payment...');
            break;

        case StoreKit.TRANSACTION_STATE_PURCHASED:
            console.log('✅ Purchased!');
            console.log('  transactionId:         ', evt.identifier);
            console.log('  originalTransactionId: ', evt.originalTransactionId);
            console.log('  productIdentifier:     ', evt.productIdentifier);
            // Save originalTransactionId for future server-side validation
            Ti.App.Properties.setString('originalTransactionId', evt.originalTransactionId);
            break;

        case StoreKit.TRANSACTION_STATE_FAILED:
            if (evt.cancelled) {
                console.log('User cancelled');
            } else {
                console.log('Failed:', evt.message, '| errorCode:', evt.errorCode);
                console.log('Retryable:', evt.retryable); // true for transient Apple server errors
            }
            break;

        case StoreKit.TRANSACTION_STATE_DEFERRED:
            console.log('Deferred — awaiting Ask to Buy approval');
            break;

        case StoreKit.TRANSACTION_STATE_RESTORED:
            console.log('Restored:', evt.productIdentifier);
            break;
    }
});

StoreKit.addTransactionObserver();

// Request products from the App Store
StoreKit.requestProducts([
    'com.example.app.premium',
    'com.example.app.subscription.monthly'
], function(evt) {
    if (!evt.success) {
        console.error('App Store unavailable:', evt.message);
        return;
    }
    if (evt.invalid && evt.invalid.length > 0) {
        console.warn('Invalid product IDs:', evt.invalid.join(', '));
    }
    evt.products.forEach(function(p) {
        console.log(p.identifier, p.formattedPrice);
    });
});
```

#### Purchase with Application Username

```javascript
// Hash the username before sending — never send plaintext
StoreKit.purchase({
    product: product,
    quantity: 1,                            // optional, default 1
    applicationUsername: hashedUsername     // used by Apple to detect irregular activity
});
```

#### Introductory Price (Free Trial)

```javascript
StoreKit.requestProducts(['com.example.app.subscription.monthly'], function(evt) {
    var product = evt.products[0];

    if (product.introductoryPrice) {
        var intro = product.introductoryPrice;
        console.log('Trial price:   ', intro.price);
        console.log('Trial period:  ', intro.subscriptionPeriod.numberOfUnits,
                    intro.subscriptionPeriod.unit === StoreKit.PERIOD_UNIT_DAY ? 'days' : 'weeks');
        console.log('Payment mode:  ', intro.paymentMode); // DISCOUNT_PAYMENT_MODE_FREE_TRIAL
        console.log('Num periods:   ', intro.numberOfPeriods);
    }

    if (product.subscriptionPeriod) {
        var period = product.subscriptionPeriod;
        console.log('Billing every:', period.numberOfUnits, 'month(s)');
    }
});
```

#### Allow Purchases Initiated from the App Store (iOS 11+)

```javascript
// Only allow specific products to be purchased from outside the app
StoreKit.allowedStorePaymentProductIdentifiers = [
    'com.example.app.premium',
    'com.example.app.subscription.monthly'
];
```

---

### Feature 2: Restore Purchases

Let users recover previous purchases after reinstalling or on a new device.

```javascript
StoreKit.addEventListener('restoredCompletedTransactions', function(evt) {
    if (evt.error) {
        console.error('Restore failed:', evt.error);
        return;
    }
    if (!evt.transactions || evt.transactions.length === 0) {
        console.warn('No purchases to restore');
        return;
    }
    console.log('Restored', evt.transactions.length, 'transaction(s)');
    evt.transactions.forEach(function(tx) {
        console.log(' →', tx.productIdentifier, '| originalId:', tx.identifier);
        // Save for server validation
        Ti.App.Properties.setString('originalTransactionId', tx.identifier);
    });
});

StoreKit.addTransactionObserver();

// Simple restore
StoreKit.restoreCompletedTransactions();

// Restore with username (optional)
StoreKit.restoreCompletedTransactions({ username: hashedUsername });
```

---

### Feature 3: Server-Side Validation (App Store Server API)

The recommended validation approach for iOS 17+. Sends `originalTransactionId` to your server, which queries the App Store Server API.

> ⚠️ The old `/verifyReceipt` endpoint is deprecated by Apple. Use the App Store Server API instead.

#### App Flow

```javascript
// After a successful purchase, save the originalTransactionId
Ti.App.Properties.setString('originalTransactionId', evt.originalTransactionId);

// Send to your server for validation
var savedId = Ti.App.Properties.getString('originalTransactionId', '');

var xhr = Ti.Network.createHTTPClient({
    onload: function() {
        var response = JSON.parse(this.responseText);
        if (response.success && response.subscription.is_active) {
            console.log('✅ Subscription active until:', response.subscription.expires_date);
            unlockPremiumContent();
        } else {
            console.log('❌ Subscription inactive');
        }
    },
    onerror: function(e) {
        console.error('Validation error:', e.error);
    },
    timeout: 15000
});

xhr.open('POST', 'https://your-server.com/api/validate-subscription');
xhr.setRequestHeader('Content-Type', 'application/json');
xhr.setRequestHeader('X-API-Key', 'your-api-key');
xhr.send(JSON.stringify({ originalTransactionId: savedId }));
```

#### Legacy Server-Side Validation (receipt-based)

> ⚠️ Apple deprecated `/verifyReceipt`. Use the App Store Server API approach above for new integrations.

```javascript
// Still available for backwards compatibility
StoreKit.validateReceiptWithServer({
    sandbox: false,         // true for Sandbox environment
    sharedSecret: 'abc123'  // required for auto-renewable subscriptions
}, function(evt) {
    if (evt.success) {
        console.log('Receipt valid');
        console.log('Apple response:', JSON.stringify(evt.appleResponse));
    } else {
        console.error('Invalid receipt:', evt.error);
    }
});
```

---

### Feature 4: Receipt Management

Access and refresh the local App Store receipt.

```javascript
// Check if a receipt exists
if (StoreKit.receiptExists) {
    // Get receipt as Base64 string — send to your server
    var receiptB64 = StoreKit.receiptBase64;
    console.log('Receipt:', receiptB64.substring(0, 40) + '...');

    // Or as a TiBlob
    var receiptBlob = StoreKit.receipt;
}

// Refresh receipt if missing or invalid (prompts Apple sign-in)
StoreKit.refreshReceipt(null, function(evt) {
    if (evt.success) {
        console.log('Receipt refreshed');
    } else {
        console.error('Refresh failed:', evt.error);
    }
});

// Refresh with specific properties (for Sandbox testing)
StoreKit.refreshReceipt({
    expired: 0,  // 1 = simulate expired receipt
    revoked: 0,  // 1 = simulate revoked receipt
    vpp: 0       // 1 = simulate Volume Purchase Plan receipt
}, callback);
```

---

### Feature 5: Subscription Management

#### Open System Subscription Management (iOS 15+)

```javascript
// Opens the system sheet where users can manage their subscriptions
StoreKit.showManageSubscriptions();
```

#### Get Subscription Status

```javascript
StoreKit.getSubscriptionStatus('com.example.app.subscription.monthly', function(evt) {
    if (evt.success) {
        console.log('State:', evt.state);
        // evt.state is one of:
        // StoreKit.SUBSCRIPTION_STATE_SUBSCRIBED
        // StoreKit.SUBSCRIPTION_STATE_EXPIRED
        // StoreKit.SUBSCRIPTION_STATE_IN_BILLING_RETRY
        // StoreKit.SUBSCRIPTION_STATE_IN_GRACE_PERIOD
        // StoreKit.SUBSCRIPTION_STATE_REVOKED
        // StoreKit.SUBSCRIPTION_STATE_UNKNOWN
    }
});
```

#### Request App Store Review (iOS 14+)

```javascript
// Ask the user to review the app — Apple decides if the dialog actually appears
StoreKit.requestReviewDialog();
```

---

### Feature 6: Store UI Dialogs

#### Product Dialog (App Store in-app sheet)

```javascript
StoreKit.addEventListener('productDialogDidOpen', function(evt) {
    console.log('Dialog opened:', evt.success);
    if (evt.error) console.error(evt.error);
});

StoreKit.addEventListener('productDialogDidClose', function() {
    console.log('Dialog closed');
});

StoreKit.showProductDialog({
    id: '123456789',   // SKStoreProductParameterITunesItemIdentifier
    at: 'affiliate',   // SKStoreProductParameterAffiliateToken (optional)
    ct: 'campaign'     // SKStoreProductParameterCampaignToken (optional)
});
```

#### Cloud Service Setup Dialog (Apple Music)

```javascript
StoreKit.addEventListener('cloudSetupDialogDidOpen', function(evt) {
    console.log('Cloud setup opened:', evt.success);
});

StoreKit.addEventListener('cloudSetupDialogDidClose', function() {
    console.log('Cloud setup closed');
});

StoreKit.showCloudSetupDialog({
    action: 'subscribe',        // SKCloudServiceSetupAction
    iTunesItemIdentifier: 12345 // optional
});
```

---

### Feature 7: Apple-Hosted Downloads (deprecated iOS 16)

> ⚠️ `SKDownload` was deprecated by Apple in iOS 16. Hosted content is no longer supported for new products. These APIs are kept for backwards compatibility. Apple recommends migrating to [On-Demand Resources](https://developer.apple.com/library/archive/documentation/FileManagement/Conceptual/On_Demand_Resources_Guide/).

```javascript
// Must be false to use downloads
StoreKit.autoFinishTransactions = false;

StoreKit.addEventListener('transactionState', function(evt) {
    if (evt.state === StoreKit.TRANSACTION_STATE_PURCHASED && evt.downloads) {
        StoreKit.startDownloads({ downloads: evt.downloads });
    }
});

StoreKit.addEventListener('updatedDownloads', function(evt) {
    evt.downloads.forEach(function(dl) {
        console.log('Progress:', dl.progress, '| State:', dl.downloadState);

        switch (dl.downloadState) {
            case StoreKit.DOWNLOAD_STATE_FINISHED:
                console.log('Downloaded to:', dl.contentURL);
                dl.transaction && dl.transaction.finish();
                break;

            case StoreKit.DOWNLOAD_STATE_FAILED:
                console.error('Download failed:', dl.error);
                dl.transaction && dl.transaction.finish();
                break;

            case StoreKit.DOWNLOAD_STATE_CANCELLED:
                dl.transaction && dl.transaction.finish();
                break;
        }
    });
});

StoreKit.addTransactionObserver();

// Download control
StoreKit.pauseDownloads({ downloads: downloads });
StoreKit.resumeDownloads({ downloads: downloads });
StoreKit.cancelDownloads({ downloads: downloads });
```

---

## API Reference

### Module Methods

#### `addTransactionObserver()`

Starts listening for transaction events. Must be called after adding event listeners, early in app startup.

#### `removeTransactionObserver()`

Stops listening for transaction events. Called automatically on app shutdown.

#### `requestProducts(ids, callback)`

Fetches product info from the App Store.

| Parameter | Type | Description |
|---|---|---|
| `ids` | `Array<String>` | Product identifiers |
| `callback` | `Function` | Called with `{ success, products, invalid, message }` |

Returns a `Ti.Storekit.ProductRequest` object with a `cancel()` method.

#### `purchase(args)`

Initiates a purchase. Fires `transactionState` events.

| Parameter | Type | Description |
|---|---|---|
| `product` | `Ti.Storekit.Product` | **Required.** Product to purchase |
| `quantity` | `Number` | Optional. Default `1`, max `10` |
| `applicationUsername` | `String` | Optional. Hashed user identifier for fraud detection |

#### `restoreCompletedTransactions([args])`

Restores previous purchases. Fires `restoredCompletedTransactions` event.

| Parameter | Type | Description |
|---|---|---|
| `username` | `String` | Optional. Hashed username |

#### `refreshReceipt(args, callback)`

Refreshes the local App Store receipt.

| Parameter | Type | Description |
|---|---|---|
| `args` | `Object` | Optional. `{ expired, revoked, vpp }` |
| `callback` | `Function` | Called with `{ success, error }` |

#### `validateReceiptWithServer(args, callback)`

Validates the receipt against Apple's `/verifyReceipt` endpoint.

> ⚠️ Deprecated by Apple. Use App Store Server API for new integrations.

| Parameter | Type | Description |
|---|---|---|
| `sandbox` | `Boolean` | `true` for Sandbox, `false` for Production |
| `sharedSecret` | `String` | Required for auto-renewable subscriptions |

Callback receives `{ success, receiptData, appleResponse, error }`.

#### `showManageSubscriptions()` *(iOS 15+)*

Opens the system subscription management sheet.

#### `getSubscriptionStatus(productId, callback)` *(iOS 15+)*

Returns the current subscription state for a product identifier.

#### `requestReviewDialog()` *(iOS 14+)*

Requests an App Store rating/review from the user.

#### `showProductDialog(args)`

Shows an App Store product sheet.

| Key | Description |
|---|---|
| `id` | iTunes item identifier |
| `at` | Affiliate token |
| `ct` | Campaign token |

#### `showCloudSetupDialog(args)`

Shows a cloud service setup dialog (e.g. Apple Music subscription).

#### `startDownloads(args)` *(deprecated iOS 16)*
#### `cancelDownloads(args)` *(deprecated iOS 16)*
#### `pauseDownloads(args)` *(deprecated iOS 16)*
#### `resumeDownloads(args)` *(deprecated iOS 16)*

Control Apple-hosted content downloads. Requires `autoFinishTransactions = false`.

---

### Module Properties

| Property | Type | Description |
|---|---|---|
| `canMakePayments` | `Boolean` (read-only) | Whether the device can make payments |
| `receiptExists` | `Boolean` (read-only) | Whether a local receipt exists |
| `receipt` | `TiBlob` (read-only) | Raw receipt as a blob |
| `receiptBase64` | `String` (read-only) | Receipt as a Base64 string |
| `autoFinishTransactions` | `Boolean` | Auto-finish transactions. Default `true`. Set `false` when using downloads |
| `allowedStorePaymentProductIdentifiers` | `Array<String>` | Product IDs allowed for App Store-initiated purchases (iOS 11+) |
| `suppressSimulatorWarning` | `Boolean` | Suppress the simulator warning dialog |

---

### Module Events

#### `transactionState`

Fired when a transaction changes state.

| Property | Type | Description |
|---|---|---|
| `state` | `int` | One of the `TRANSACTION_STATE_*` constants |
| `identifier` | `String` | Transaction identifier |
| `originalTransactionId` | `String` | Stable ID across renewals — use for server-side validation |
| `productIdentifier` | `String` | Product identifier |
| `date` | `Date` | Transaction date |
| `quantity` | `int` | Quantity purchased |
| `receipt` | `String` | Base64-encoded receipt |
| `transaction` | `Ti.Storekit.Transaction` | Full transaction object |
| `cancelled` | `Boolean` | *(FAILED only)* Whether user cancelled |
| `message` | `String` | *(FAILED only)* Error message |
| `errorCode` | `int` | *(FAILED only)* SKError code |
| `retryable` | `Boolean` | *(FAILED only)* Whether the error is transient |

#### `restoredCompletedTransactions`

Fired when restore completes.

| Property | Type | Description |
|---|---|---|
| `transactions` | `Array<Ti.Storekit.Transaction>` | Restored transactions (on success) |
| `error` | `String` | Error message (on failure) |

#### `updatedDownloads` *(deprecated iOS 16)*

Fired when download progress changes.

| Property | Type | Description |
|---|---|---|
| `downloads` | `Array<Ti.Storekit.Download>` | Updated download objects |

#### `productDialogDidOpen` / `productDialogDidClose`

Fired when the product dialog opens/closes.

#### `cloudSetupDialogDidOpen` / `cloudSetupDialogDidClose`

Fired when the cloud setup dialog opens/closes.

---

### Constants

#### Transaction States

| Constant | Description |
|---|---|
| `TRANSACTION_STATE_PURCHASING` | Payment in progress |
| `TRANSACTION_STATE_PURCHASED` | Payment successful |
| `TRANSACTION_STATE_FAILED` | Payment failed or cancelled |
| `TRANSACTION_STATE_RESTORED` | Previous purchase restored |
| `TRANSACTION_STATE_DEFERRED` | Pending Ask to Buy approval |

#### Subscription States *(iOS 15+)*

| Constant | Value | Description |
|---|---|---|
| `SUBSCRIPTION_STATE_SUBSCRIBED` | `"subscribed"` | Active subscription |
| `SUBSCRIPTION_STATE_EXPIRED` | `"expired"` | Subscription expired |
| `SUBSCRIPTION_STATE_IN_BILLING_RETRY` | `"inBillingRetryPeriod"` | Billing retry in progress |
| `SUBSCRIPTION_STATE_IN_GRACE_PERIOD` | `"inGracePeriod"` | In grace period |
| `SUBSCRIPTION_STATE_REVOKED` | `"revoked"` | Subscription revoked/refunded |
| `SUBSCRIPTION_STATE_UNKNOWN` | `"unknown"` | State could not be determined |

#### Discount Payment Modes *(iOS 11.2+)*

| Constant | Description |
|---|---|
| `DISCOUNT_PAYMENT_MODE_PAY_AS_YOU_GO` | Billed per period |
| `DISCOUNT_PAYMENT_MODE_PAY_UP_FRONT` | Billed up front |
| `DISCOUNT_PAYMENT_MODE_FREE_TRIAL` | Free trial period |

#### Subscription Period Units *(iOS 11.2+)*

| Constant | Description |
|---|---|
| `PERIOD_UNIT_DAY` | Daily interval |
| `PERIOD_UNIT_WEEK` | Weekly interval |
| `PERIOD_UNIT_MONTH` | Monthly interval |
| `PERIOD_UNIT_YEAR` | Yearly interval |

#### Download States *(deprecated iOS 16)*

| Constant | Description |
|---|---|
| `DOWNLOAD_STATE_WAITING` | Queued, not yet started |
| `DOWNLOAD_STATE_ACTIVE` | Downloading |
| `DOWNLOAD_STATE_PAUSED` | Paused |
| `DOWNLOAD_STATE_FINISHED` | Complete |
| `DOWNLOAD_STATE_FAILED` | Failed |
| `DOWNLOAD_STATE_CANCELLED` | Cancelled |
| `DOWNLOAD_TIME_REMAINING_UNKNOWN` | Time estimate unavailable |

---

### Ti.Storekit.Product

| Property | Type | Description |
|---|---|---|
| `identifier` | `String` | Product ID as set in App Store Connect |
| `title` | `String` | Localized product name |
| `description` | `String` | Localized product description |
| `price` | `Number` | Price as decimal |
| `formattedPrice` | `String` | Price formatted for the store locale |
| `locale` | `String` | Store locale identifier |
| `introductoryPrice` | `Discount` | Introductory/trial pricing (iOS 11.2+) |
| `subscriptionPeriod` | `Dictionary` | `{ numberOfUnits, unit }` (iOS 11.2+) |

---

### Ti.Storekit.Transaction

| Property | Type | Description |
|---|---|---|
| `identifier` | `String` | Unique transaction ID |
| `state` | `int` | Current `TRANSACTION_STATE_*` value |
| `date` | `Date` | Transaction date |
| `productIdentifier` | `String` | Product ID |
| `quantity` | `int` | Number of items |
| `applicationUsername` | `String` | Hashed username if provided at purchase |
| `receipt` | `String` | Base64 receipt string |
| `originalTransaction` | `Ti.Storekit.Transaction` | Original transaction for restored purchases |

#### `finish()`

Completes the transaction and removes it from the payment queue. Always call this after processing a transaction.

---

### Ti.Storekit.Download *(deprecated iOS 16)*

| Property | Type | Description |
|---|---|---|
| `contentIdentifier` | `String` | Unique download identifier |
| `contentURL` | `String` | Local path to downloaded file (valid when `DOWNLOAD_STATE_FINISHED`) |
| `contentVersion` | `String` | Version string of the downloaded content |
| `contentLength` | `Number` | File size in bytes |
| `downloadState` | `int` | Current `DOWNLOAD_STATE_*` value |
| `progress` | `Number` | `0.0` to `1.0` |
| `timeRemaining` | `Number` | Estimated ms remaining (`DOWNLOAD_TIME_REMAINING_UNKNOWN` if unavailable) |
| `error` | `String` | Error description (valid when `DOWNLOAD_STATE_FAILED`) |
| `transaction` | `Ti.Storekit.Transaction` | Associated transaction |

---

## Breaking Changes in v6.0

Upgrading from v4.x:

- **`validateReceipt()`** removed — Apple deprecated on-device receipt validation with OpenSSL. Use `validateReceiptWithServer()` or the App Store Server API instead.
- **`verifyReceipt()`** removed — replaced by `validateReceiptWithServer()`.
- **`bundleVersion` / `bundleIdentifier`** properties removed — no longer needed without on-device validation.
- **`receiptVerificationSandbox`** property removed.
- **`DOWNLOAD_STATE_*` constants** still present but marked deprecated.
- **`originalTransactionId`** added to the `transactionState` event — use this for App Store Server API calls instead of the receipt blob.

---

## Testing

StoreKit **does not work in the iOS Simulator**. Always test on a real device using a Sandbox tester account.

### Setting Up a Sandbox Tester

1. In App Store Connect: **Users and Access → Sandbox → Testers → +**
2. Create a tester with an email that doesn't exist in Apple's system (e.g. `yourname+sandbox@gmail.com`)
3. On your device: **Settings → App Store → Sandbox Account → Sign In**

### Notes

- Use a **Development Provisioning Profile** with **In-App Purchase** enabled
- Agree to all contracts under **App Store Connect → Agreements, Tax, and Banking**
- In Sandbox, monthly subscriptions renew every 5 minutes (max 12 renewals)
- To suppress the simulator warning dialog: `StoreKit.suppressSimulatorWarning = true`

---

## License

Copyright © 2010-present by Appcelerator, Inc. All Rights Reserved.

Licensed under the Apache Public License. See the LICENSE file for details.

Original authors: Jeff Haynie, Jeff English, Jon Alter, Hans Knöchel.

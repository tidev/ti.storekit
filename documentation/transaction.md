# Ti.Storekit.Transaction

## Description

A `Ti.Storekit` module object representing a payment transaction from the App Store payment queue.

You receive `Ti.Storekit.Transaction` objects through the `transactionState` and `restoredCompletedTransactions` events. Always call `finish()` after processing a transaction — failing to do so will cause the queue to re-deliver the transaction on subsequent launches.

## Functions

### finish()

Completes the transaction and removes it from the payment queue.

Call this only after your app has fully processed the transaction and unlocked the purchased content. If `autoFinishTransactions` is `true` (the default), transactions are finished automatically and you do not need to call this.

## Properties

### identifier [String] (read-only)

A unique identifier for this specific transaction. Changes with each renewal for subscriptions.

For a stable identifier that persists across all renewals, use `originalTransactionId` from the `transactionState` event instead.

### state [int] (read-only)

The current state of the transaction. One of:

| Constant | Description |
|---|---|
| `TRANSACTION_STATE_PURCHASING` | Payment in progress |
| `TRANSACTION_STATE_PURCHASED` | Payment successful |
| `TRANSACTION_STATE_FAILED` | Payment failed or cancelled |
| `TRANSACTION_STATE_RESTORED` | Previous purchase restored |
| `TRANSACTION_STATE_DEFERRED` | Pending Ask to Buy approval |

### date [Date] (read-only)

The date the transaction was added to the payment queue. Defined for `PURCHASED` and `RESTORED` states.

### productIdentifier [String] (read-only)

The product identifier string as configured in App Store Connect.

### quantity [int] (read-only)

The number of items purchased. Default is `1`, maximum is `10`.

### applicationUsername [String] (read-only)

The opaque, hashed user identifier provided at purchase time via `purchase({ applicationUsername: ... })`. Used by Apple to detect irregular activity.

### receipt [String] (read-only)

The Base64-encoded App Store receipt for the entire app (not just this transaction). Send this to your server for receipt-based validation.

> For the recommended validation approach on iOS 17+, use `originalTransactionId` from the `transactionState` event and validate via the App Store Server API instead.

### originalTransaction [Ti.Storekit.Transaction] (read-only)

For `TRANSACTION_STATE_RESTORED` transactions, this is the original transaction that was restored. Contains the original `identifier`, `date`, and `productIdentifier`.

`null` for all other states.

## Example

```javascript
var StoreKit = require('ti.storekit');

// Set false only if you need to handle transactions manually (e.g. downloads)
StoreKit.autoFinishTransactions = false;

StoreKit.addEventListener('transactionState', function(evt) {
    var tx = evt.transaction;

    switch (evt.state) {
        case StoreKit.TRANSACTION_STATE_PURCHASED:
            console.log('Purchased!');
            console.log('  identifier:            ', tx.identifier);
            console.log('  originalTransactionId: ', evt.originalTransactionId);
            console.log('  productIdentifier:     ', tx.productIdentifier);
            console.log('  date:                  ', tx.date);

            // Save the originalTransactionId for App Store Server API validation
            Ti.App.Properties.setString('originalTransactionId', evt.originalTransactionId);

            // Unlock content, then finish
            unlockPremiumContent();
            tx.finish();
            break;

        case StoreKit.TRANSACTION_STATE_FAILED:
            if (!evt.cancelled) {
                console.error('Purchase failed:', evt.message);
                console.error('  errorCode:', evt.errorCode);
                console.error('  retryable:', evt.retryable);
            }
            tx.finish();
            break;

        case StoreKit.TRANSACTION_STATE_RESTORED:
            console.log('Restored:', tx.productIdentifier);
            if (tx.originalTransaction) {
                console.log('  Original ID:', tx.originalTransaction.identifier);
            }
            tx.finish();
            break;
    }
});

StoreKit.addTransactionObserver();
```

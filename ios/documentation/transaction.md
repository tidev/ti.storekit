# Ti.Storekit.Transaction

## Description

A _Ti.Storekit_ module object which represents a Transaction.

Read more about transactions in Apple's [SKPaymentTransaction Reference](https://developer.apple.com/library/ios/documentation/StoreKit/Reference/SKPaymentTransaction_Class/Reference/Reference.html)

## Functions

### finish()

Completes a pending transaction.

Your application should call this method from a `transactionState` or `updatedDownloads` event listener. Calling finish on a transaction removes it from the queue. Your application should call finish only after it has successfully processed the transaction and unlocked the functionality purchased by the user.

## Properties

### downloads[array<[Ti.Storekit.Download][]>] (read-only)

An array of download objects representing the downloadable content associated with the transaction.

The contents of this property are undefined except when `transactionState` is set to `Ti.Storekit.TRANSACTION_STATE_PURCHASED`. The [Ti.Storekit.Download][] objects stored in this property must be used to download the transaction's content before the transaction is finished. After the transaction is finished, the download objects are no longer queueable.

### originalTransaction[[Ti.Storekit.Transaction][]] (read-only)

The transaction that was restored by the App Store.

The contents of this property are undefined except when `transactionState` is set to `Ti.Storekit.TRANSACTION_STATE_RESTORED`. When a transaction is restored, the current transaction holds a new transaction identifier, receipt, and so on. Your application will read this property to retrieve the restored transaction.

### date[date] (read-only)

The date the transaction was added to the App Store's payment queue.

The contents of this property are undefined except when `transactionState` is set to `Ti.Storekit.TRANSACTION_STATE_PURCHASED` or `Ti.Storekit.TRANSACTION_STATE_RESTORED`.

### identifier[string] (read-only)

A string that uniquely identifies a successful payment transaction.

The contents of this property are undefined except when transactionState is set to `Ti.Storekit.TRANSACTION_STATE_PURCHASED` or `Ti.Storekit.TRANSACTION_STATE_RESTORED`. The transactionIdentifier is a string that uniquely identifies the processed payment. Your application may wish to record this string as part of an audit trail for App Store purchases. See [In-App Purchase Programming Guide](https://developer.apple.com/library/ios/documentation/NetworkingInternet/Conceptual/StoreKitGuide/Introduction.html#//apple_ref/doc/uid/TP40008267) for more information.

### state[int] (read-only)

The current state of the transaction.

See the `Ti.Storekit.TRANSACTION_STATE` constants for available states.[Ti.Storekit][].

### quantity[int] (read-only)

The number of items the user wants to purchase.

The default value is 1, the minimum value is 1, and the maximum value is 10.

### productIdentifier[string] (read-only)

A string used to identify a product that can be purchased from within your application.

The product identifier is a string previously agreed on between your application and the Apple App Store.

### applicationUsername[string] (read-only)

An opaque identifier for the user's account on your system.

This is used to help detect irregular activity. For example, in a game, it would be unusual for as dozens of different iTunes Store accounts making purchases on behalf of the same in-game character.

The recommended implementation is to use a one-way hash of the user's account name to calculate the value for this property.

[Ti.Storekit]: index.html
[Ti.Storekit.Download]: download.html
[Ti.Storekit.Transaction]: transaction.html

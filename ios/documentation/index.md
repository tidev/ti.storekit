# Ti.Storekit Module

## Description

The Storekit module allows you access to Apple's in-app purchasing mechanisms.

## How Do I Get Started?

Read our Wiki page to get started quickly:

http://wiki.appcelerator.org/display/guides/StoreKit+Module+In-App+Purchase+Testing

## Getting Started

View the [Using Titanium Modules](http://docs.appcelerator.com/titanium/latest/#!/guide/Using_Titanium_Modules) document for instructions on getting
started with using this module in your application.

## Accessing the Storekit Module

To access this module from JavaScript, you would do the following:

	var Storekit = require('ti.storekit');

## Testing a Store

<strong>Note: </strong>Store Kit does not operate in iOS Simulator. When running your application in iOS Simulator,
Store Kit logs a warning if your application attempts to retrieve the payment queue. Testing the store must be done on actual devices.

## Breaking Changes in version 2.0.0

It was previously possible for a transaction to complete after the application had been moved to the background due to the app store
needing to obtain information from the user. Although your application may have received a _FAILED_ notification when your application
was moved to the background, your application would not have received a _PURCHASED_ notification if the user completed the transaction from
the app store. In order to support this situation, purchase notifications are now sent to your application as an event rather than through
a callback.

If you are upgrading from an earlier version of this module (prior to version 2.0.0) you should be
aware of the following breaking changes to the API:

* The _purchase_ function no longer returns a Ti.Storekit.Payment object.
* The _callback_ parameter has been removed from the _purchase_ function. You must now register an event listener 
for the _transactionState_ event to receive notification of FAILED and PURCHASED transaction events.
* The _payment_ property is no longer returned as part of the transaction complete notification.

## Deprecated since version 1.6.0

The _verifyReceipt_ function has been updated to better support receipt verification with Apple. As a result, the following
changes have been made to the _verifyReceipt_ function:

* Setting the callback in the argument dictionary has been DEPRECATED. Pass the callback as the 2nd parameter to _verifyReceipt_.
* Setting the sandbox property in the argument dictionary has been DEPRECATED. Use the 'receiptVerificationSandbox' property for the module.
* Setting the sharedSecret property in the argument dictionary has been DEPRECATED. Use the 'receiptVerificationSharedSecret' property for the module.

## Functions

### requestProducts(ids[array], callback(e){})

Requests to see if products identified by the strings in the _id_ array are available.
The _callback_ function is called upon completion of the request, with the following event
information:

* success[boolean]: Whether or not the request succeeded
* message[string]: If the request failed, the reason why
* products[array]: An array of _[Ti.Storekit.Product][]_ objects which represent the valid products retrieved
* invalid[array]: An array of identifiers passed to the request that did not correspond to a product ID. Only present when at least one requested product is invalid.

Returns a _[Ti.Storekit.ProductRequest][]_ object.

### purchase(object, quantity[int, optional])

Purchases the _[Ti.Storekit.Product][]_ object passed to it.  The _transactionState_ event is fired when
the purchase request's state changes.

The _quantity_ parameter is optional and has a default value of 1.

### verifyReceipt(args[object], callback(e){})

Verifies that a receipt passed from a Storekit purchase or restored transaction is valid. Note that you rarely need to do this
step in-app. It is much more likely that you would want to do this step on your own server to confirm from Apple that a
purchase is legitimate.

<strong>Important</strong> There is a vulnerability in iOS 5.1 and earlier related to receipt validation. Your application
should perform the additional step of verifying that the receipt you received from Store Kit came from Apple. This is
particularly important when your application relies on a separate server to provide subscriptions, services, or downloadable
content. Verifying receipts on your server ensures that requests from your application are valid.

Takes one argument, a dictionary with the following values:

* identifier[string]: The transaction identifier
* receipt[blob]: A receipt retrieved from a call to Ti.Storekit.purchase's callback evt.receipt.
* quantity[int]: The number of items purchased
* productIdentifier[string]: The product's identifier in the in-app store

The _callback_ function is called when the verification request completes, with the following event information:

* success[boolean]: Whether or not the request succeeded
* valid[boolean]: Whether or not the receipt is valid
* message[string]: If _success_ or _valid_ is false, the error message
* identifier[string]: The transaction identifier
* receipt[object]: A blob of type "text/json" which contains the receipt information for the purchase.
* quantity[int]: The number of items purchased
* productIdentifier[string]: The product's identifier in the in-app store.

Returns a _[Ti.Storekit.ReceiptRequest][]_ object.

### restoreCompletedTransactions()

Asks the payment queue to restore previously completed purchases. The _restoredCompletedTransactions_ event is fired when
the transactions have been restored. 

Note that calling this may ask the user to authenticate!
It is recommended that you give the user the option to restore their past purchases via a button, and invoke this method
only after the user touches it.

## Properties

### receiptVerificationSandbox[bool, defaults to false]

Whether or not to use Apple's Sandbox verification server.

### receiptVerificationSharedSecret[string, optional]

The shared secret for your app that you created in iTunesConnect; required for verifying auto-renewable subscriptions.

### canMakePayments[boolean] (read-only)

Whether or not payments can be made via Storekit.

## Constants

### PURCHASING[int]

The PURCHASING state during purchase request processing.

### PURCHASED[int]

The PURCHASED state during purchase request processing.

### FAILED[int]

The FAILED state during purchase request processing.

### RESTORED[int]

The RESTORED state during purchase request processing.

## Events

### transactionState

Occurs if you call Ti.Storekit.purchase and the purchase request's state changes. The following event information will be
provided:

* state[int]: The current state of the transaction; either _Ti.Storekit.FAILED_, _Ti.Storekit.PURCHASED_,
_Ti.Storekit.PURCHASING_, or _Ti.Storekit.RESTORED_.
* quantity[int]: The number of items purchased or requested to purchase.
* productIdentifier[string]: The product's identifier in the in-app store.

For state _Ti.Storekit.FAILED_, the following additional information will be provided:

* cancelled[boolean]: Whether the failure is due to cancellation of the request or not
* message[string]: If not cancelled, what the error message is

For state _Ti.Storekit.PURCHASED_ and _Ti.Storekit.RESTORED_, the following additional information will be provided:

* date[date]: Transaction date
* identifier[string]: The transaction identifier
* receipt[object]: A blob of type "text/json" which contains the receipt information for the purchase.

### restoredCompletedTransactions

Occurs if you call Ti.Storekit.restoreCompletedTransactions and no errors are encountered. The following event information
will be provided:

* error[string]: An error message, if one was encountered.
* transactions[array]: If no errors were encountered, all of the transactions that were restored.

Each transaction can contain the following properties:

* state[int]: The current state of the transaction; most likely _Ti.Storekit.RESTORED_.
* date[date]: The date the transaction was added to the App Store's payment queue.
* identifier[string]: The transaction identifier
* receipt[object]: A blob of type "text/json" which contains the receipt information for the purchase.
* quantity[int]: The number of items purchased
* productIdentifier[string]: The product's identifier in the in-app store.
* originalTransaction[dictionary]: The transaction that was restored by the App Store

## Usage

See example.

## Author

Jeff Haynie & Jeff English

## Module History

View the [change log](changelog.html) for this module.

## Feedback and Support

Please direct all questions, feedback, and concerns to [info@appcelerator.com](mailto:info@appcelerator.com?subject=iOS%20Storekit%20Module).

## License

Copyright(c) 2010-2013 by Appcelerator, Inc. All Rights Reserved. Please see the LICENSE file included in the distribution for further details.

[Ti.Storekit.ProductRequest]: productRequest.html
[Ti.Storekit.Product]: product.html
[Ti.Storekit.ReceiptRequest]: receiptRequest.html

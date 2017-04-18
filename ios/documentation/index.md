# Ti.Storekit Module

## Description

The Storekit module allows you access to Apple's in-app purchasing mechanisms.

## How Do I Get Started?

Read our Wiki page to get started quickly:

[StoreKit Module In-App Purchase Testing](https://wiki.appcelerator.org/pages/viewpage.action?pageId=27591081)

## Getting Started

View the [Using Titanium Modules](http://docs.appcelerator.com/titanium/latest/#!/guide/Using_Titanium_Modules) document for instructions on getting
started with using this module in your application.

## Accessing the Storekit Module

To access this module from JavaScript, you would do the following:

	var Storekit = require('ti.storekit');

## Testing a Store

#### Note:
If you are getting this error "The hard-coded bundle version does not match the app's `CFBundleVersion`." this could be why. 
The `bundleVersion` and `bundleIdentifier` properties must be set on the module before calling `validateReceipt`. These values are used as part of the receipt validation process. In Titanium, when a development build is created to run on "device", a timestamp gets appended to the version number. This is done so that iTunes will see it as a new build and will update the app on the device. Because of this change to the version, when validation occurs the version number does not match and validation fails. To get around this issue: 

- Build the app once through Titanium.
- Go to the "build" folder of the app and open the Xcode project with Xcode.
- Once the project is open, click on the project on the left in Xcode.
- In the center section of Xcode select the "General" tab.
- Under "General", make sure that the "Version" is what you expect it to be. 
- If the version is not what you expect (maybe something like 1.0.0.1382133876099) change it to its correct value (in this case 1.0.0).
- Plug in your device.
- At the top left of Xcode, select the connected device.
- At the top left of Xcode, click "Build and run" (it looks like a play button).
- If this was the issue that was causing validation to fail, it should now validate the receipt successfully.

#### Note:
If your receipts are not being validated (return `false`), ensure to test with a Sandbox account in your development environment,
not with your real iTunes account. Otherwise you will get an Error 100 saying that you are not allowed to use a non-Sandbox-account in
development.

#### Note:
If you are having trouble testing or some options are not showing up when creating purchases, make sure that you have agreed to all of the contracts under "iTunes Connect" > "Contracts, Tax, and Banking".

#### Note: 
Be sure to use a "Development" Provisioning Profile and an "App ID" with "In-App Purchase" enabled.

#### Note:
Storekit does not work in the Simulator. When running your application in iOS Simulator, Storekit logs a warning. 
Testing the store must be done on actual devices.

## Breaking changes in version 4.0.0

- The `verifyReceipt` method has been removed in favor of `validateReceipt`
- The `bundleVersion` property now expects the `CFBundleVersion` instead the `CFBundleShortVersionString` as recommended by Apple. 
- The `PURCHASING`, `PURCHASED`, `FAILED` and `RESTORED` constants have been removed in favor of the `TRANSACTION_STATE_*` prefixed ones.
- Passing separate arguments `purchase(object, quantity[int, optional])`. Use a dictionary of arguments as seen in the API docs instead.
- The transaction event key `receipt` will now include a Base 64-encoded string of the receipt instead of a JSON-blob 

## Breaking changes in version 3.0.0

- `addTransactionObserver` must be called in order for any events to be fired for `transactionState`, `restoredCompletedTransactions`, and `updatedDownloads` event listeners. See the `addTransactionObserver` documentation for more details.
- Added support for Apple's new receipt structure available in iOS 7.0 and later. To `validateReceipt`:  

	1. Obtain the Apple Inc. root certificate from [http://www.apple.com/certificateauthority/](http://www.apple.com/certificateauthority/)
	2. Download the Apple Inc. Root Certificate ( [http://www.apple.com/appleca/AppleIncRootCertificate.cer](http://www.apple.com/appleca/AppleIncRootCertificate.cer) )
	3. Add the AppleIncRootCertificate.cer to your app's `Resources` folder.
	4. Set the `bundleVersion` and `bundleIdentifier` properties of the module.
	5. Call `validateReceipt()`.
	6. If the receipt does not exist (only happens in development), refresh the receipt.

- Apple hosted downloads are supported. The basic steps for downloading hosted content:
	1. Create a product.
	2. Create Hosted content (guide to [Creating App Store Hosted Content](https://github.com/appcelerator-modules/ti.storekit/wiki/Creating-App-Store-Hosted-Content)).
	3. Add the content to the product.
	4. Set the `autoFinishTransactions` property to false.
	5. Purchase the product.
	6. When the state of the `transactionState` event is `TRANSACTION_STATE_PURCHASED` and the `downloads` property of the event exists, start the downloads.
	7. When the download completes, finish the transaction.
	
- Passing arguments to the `purchase` function individually is DEPRECATED, pass them as a dictionary instead.
- Transaction state constants `PURCHASING`, `PURCHASED`, `FAILED`, and `RESTORED` have been DEPRECATED in favor of `TRANSACTION_STATE_PURCHASING`, `TRANSACTION_STATE_PURCHASED`, `TRANSACTION_STATE_FAILED`, and `TRANSACTION_STATE_RESTORED`.
- Some event properties in the `transactionState` event have been DEPRECATED. See the `transactionState` event documentation for more details.
- An alert dialog warning will now be shown when run in the simulator. This dialog can be disabled by setting the `suppressSimulatorWarning` property on the module to true.

### Apple Hosted Purchases
Apple hosted in app purchases can now be downloaded. Must be [Non-Consumable Purchases](https://developer.apple.com/library/ios/documentation/LanguagesUtilities/Conceptual/iTunesConnect_Guide/13_ManagingIn-AppPurchases/ManagingIn-AppPurchases.html#//apple_ref/doc/uid/TP40011225-CH4-SW37) to be hosted by Apple. This guide will assist with [Creating App Store Hosted Content](https://github.com/appcelerator-modules/ti.storekit/wiki/Creating-App-Store-Hosted-Content).

### Warning
This module uses open source code for parsing and validating the receipt. It is recommended by Apple that users not use common code to do this as it will make it easier to crack your app. Please make appropriate changes to the receipt verification code in the module to make your implementation unique and less vulnerable to attack. We cannot do this for you or offer recommendations regarding how it should be done due to aforementioned reasons.

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

## Helpful Links

* [In-App Purchase for Developers](https://developer.apple.com/in-app-purchase/)
* [Creating a test user account](https://developer.apple.com/library/ios/documentation/LanguagesUtilities/Conceptual/iTunesConnect_Guide/13_ManagingIn-AppPurchases/ManagingIn-AppPurchases.html#//apple_ref/doc/uid/TP40011225-CH4-SW44)
* [Creating App Store Hosted Content](https://github.com/appcelerator-modules/ti.storekit/wiki/Creating-App-Store-Hosted-Content)

## Functions

### addTransactionObserver()

Start accepting events that will trigger event listeners for `transactionState`, `restoredCompletedTransactions`, and `updatedDownloads`. 

This should be called early in the app startup, but only after event listeners for the above events are added. If this function is not called, the above events will not fire. Calling this function before adding the event listeners will tell the store kit that you are accepting events, but the events may be lost if they happen before the event listener is there to catch them.

### removeTransactionObserver()

Stop accepting events that will trigger event listeners for `transactionState`, `restoredCompletedTransactions`, and `updatedDownloads`.

This will be called for you automatically when the app is shut down.

### requestProducts(ids[array], callback(e){})

Requests to see if products identified by the strings in the _id_ array are available.
The _callback_ function is called upon completion of the request, with the following event
information:

* success[boolean]: Whether or not the request succeeded
* message[string]: If the request failed, the reason why
* products[array]: An array of _[Ti.Storekit.Product][]_ objects which represent the valid products retrieved
* invalid[array]: An array of identifiers passed to the request that did not correspond to a product ID. Only present when at least one requested product is invalid.

Returns a _[Ti.Storekit.ProductRequest][]_ object.

### purchase(args[object])

Purchases the _[Ti.Storekit.Product][]_ object passed to it.  The _transactionState_ event is fired when
the purchase request's state changes.

Takes one argument, a dictionary with the following values:

* product[_[Ti.Storekit.Product][]_]: The product to be purchased.
* quantity[number] (optional): The quantity to be purchased. Has a default value of 1.
* applicationUsername[string] (optional): An opaque identifier for the user's account on your system. Used by Apple to detect irregular activity. Should hash the username before setting.

### validateReceipt()

Checks if the receipt on the device is valid. `validateReceipt` is just as secure as `verifyReceipt`, and it is done entirely on the device. Returns true if the receipt is valid or false if it is not. Throws an error if the receipt does not exist, use `receiptExists` to avoid this error.

The `bundleVersion` and `bundleIdentifier` properties must be set on the module before calling `validateReceipt`. Do not pull these values from the app, they should be hard coded for security reasons.

The Apple Inc. Root Certificate is required to validate receipts:

1. Obtain the Apple Inc. root certificate from [http://www.apple.com/certificateauthority/](http://www.apple.com/certificateauthority/)
2. Download the Apple Inc. Root Certificate ( [http://www.apple.com/appleca/AppleIncRootCertificate.cer](http://www.apple.com/appleca/AppleIncRootCertificate.cer) )
3. Add the AppleIncRootCertificate.cer to your app's `Resources` folder.

**Note**: Nowadays, Apple recommends to download the certificate from your app instead of placing it in the Resources. This ensures that the app will 
always use the most recent one and will also prevent old versions of your app to fail when the AppleIncRootCertificate certificate gets invalidated by
Apple some day.

Returns a boolean.

### refreshReceipt(args[object], callback(e){})

Allows an app to refresh its receipt. With this API, the app can request a new receipt if the receipt is invalid or missing. In the sandbox environment, you can request a receipt with any combination of properties to test the state transitions related to Volume Purchase Plan receipts.

The args object can contain the following properties:

* expired[number]: A number interpreted as a Boolean value, indicating whether the receipt is expired.
* revoked[number]: A number interpreted as a Boolean value, indicating whether the receipt has been revoked.
* vpp[number]: A number interpreted as a Boolean value, indicating whether the receipt is is a Volume Purchase Plan receipt.

The _callback_ function is called when the refresh request completes, with the following event information:

* success[boolean]: Boolean indicating if the request was successful or not.
* error[string]: Error message if success is false.

For more information checkout Apple's [SKReceiptRefreshRequest Documentation](https://developer.apple.com/library/ios/documentation/StoreKit/Reference/SKReceiptRefreshRequest_ClassRef/SKReceiptRefreshRequest.html)

### restoreCompletedTransactions()

Asks the payment queue to restore previously completed purchases. The _restoredCompletedTransactions_ event is fired when
the transactions have been restored. 

Note that calling this may ask the user to authenticate!
It is recommended that you give the user the option to restore their past purchases via a button, and invoke this method
only after the user touches it.

### restoreCompletedTransactionsWithApplicationUsername(username[string])

Asks the payment queue to restore previously completed purchases with a provided username. The _restoredCompletedTransactions_ event is fired when
the transactions have been restored. 

Note that calling this may ask the user to authenticate!
It is recommended that you give the user the option to restore their past purchases via a button, and invoke this method
only after the user touches it.

### startDownloads(args[object])

Adds a set of downloads to the download list.

In order for a download object to be queued, it must be associated with a transaction that has been successfully purchased, but not yet finished.

Takes one argument, a dictionary with the following values:

* downloads[array<[Ti.Storekit.Download][]>]: An array of download objects to begin downloading.

**Note:** `autoFinishTransactions` must be false for download functionality to work.

### cancelDownloads(args[object])

Removes a set of downloads from the download list.

Takes one argument, a dictionary with the following values:

* downloads[array<[Ti.Storekit.Download][]>]: An array of download objects to cancel.

**Note:** `autoFinishTransactions` must be false for download functionality to work.

### pauseDownloads(args[object])

Pauses a set of downloads.

Takes one argument, a dictionary with the following values:

* downloads[array<[Ti.Storekit.Download][]>]: An array of download objects to pause.

**Note:** `autoFinishTransactions` must be false for download functionality to work.

### resumeDownloads(args[object])

Resumes a set of downloads.

Takes one argument, a dictionary with the following values:

* downloads[array<[Ti.Storekit.Download][]>]: An array of download objects to resume.

**Note:** `autoFinishTransactions` must be false for download functionality to work.

### showProductDialog(args[object])

Shows an App Store product dialog. To choose a specific product, pass the iTunes item identifier 
for the item you want to sell. Valid keys are:
  * id (`SKStoreProductParameterITunesItemIdentifier`)
  * at (`SKStoreProductParameterAffiliateToken`)
  * ct (`SKStoreProductParameterCampaignToken`)
  * pt (`SKStoreProductParameterProviderToken`)
  * advp (`SKStoreProductParameterAdvertisingPartnerToken`)

You can read more about valid key-value pairs [here](https://developer.apple.com/reference/storekit/skstoreproductviewcontroller/product_dictionary_keys).

### showCloudSetupDialog

A dialog that helps users perform setup for a cloud service, such as an Apple Music subscription. Valid keys are:
  * action
  * iTunesItemIdentifier
  * affiliateTokenKey
  * campainTokenKey

You can read more about valid key-value pairs [here](https://developer.apple.com/reference/storekit/skcloudservicesetupoptionskey).

### requestReviewDialog

Controls the process of requesting App Store ratings and reviews from users. Calling this method will 
tell StoreKit to ask the user to rate or review your app, if appropriate. Important: Because of that,
the user might not see a dialog although requested, so do not store properties based on showing this dialog.

## Properties

### receiptVerificationSandbox[boolean, defaults to false]

Whether or not to use Apple's Sandbox verification server.

### receiptVerificationSharedSecret[string, optional]

The shared secret for your app that you created in iTunesConnect; required for verifying auto-renewable subscriptions.

### canMakePayments[boolean] (read-only)

Whether or not payments can be made via Storekit.

### autoFinishTransactions[boolean, defaults to true]

Toggle transactions being finished automatically when their state is `TRANSACTION_STATE_PURCHASED`, `TRANSACTION_STATE_FAILED`, or `TRANSACTION_STATE_RESTORED`.

This property should be set to false and `finish` handled manually if any of the products to be purchased are downloadable products. When set to false, it is important that [Ti.Storekit.Transaction][]s be `finish` manually. When downloading products, do not finish the associated transaction until the download is complete. Finishing the transaction before the download is complete will cancel the download and if the transaction is finished before calling `startDownloads`, the download will not start.

### bundleVersion[string]

The bundleVersion of the app, used when validating the receipt. It is more secure to set it in the code than to read it out of the bundle. Required when calling `validateReceipt`. 
**Important**: In versions prior to 4.0.0, this property expected a value that matches `CFBundleShortVersionString`, but Apple nowadays recommends using the value of `CFBundleVersion` instead. Passing the old value isn't supposed to fail, but if both have different values, the module will warn you and throw an error. 

### bundleIdentifier[string]

The bundleIdentifier of the app, used when validating the receipt. It is more secure to set it in the code than to read it out of the bundle. Required when calling `validateReceipt`.

### receiptExists[boolean]

Whether or not a receipt exists on the device. During development there maybe be no receipt on the device. Call `refreshReceipt` to get a receipt.

### receipt[TiBlob] (read-only)

A TiBlob of the receipt on the device. Can be used to get the receipt to send it off for server side validation.

### receiptProperties[object]

An object containing properties of the receipt on the device. Will contain the following values:

* originalVersion[string]: The version of the app that was originally purchased.
* bundleIdentifier[string]: The app's bundle identifier.
* version[string]: The app's version number.
* expirationDate[string] (optional): The date that the app receipt expires.
* purchases[array]: An array of purchase objects

A purchase will have the following values:

* cancelDate[string]: For a transaction that was canceled by Apple customer support, the time and date of the cancellation.
* originalPurchaseDate[string]: For a transaction that restores a previous transaction, the date of the original transaction.
* originalTransactionIdentifier[string]: For a transaction that restores a previous transaction, the transaction identifier of the original transaction. Otherwise, identical to the transaction identifier.
* productIdentifier[string]: The product identifier of the item that was purchased.
* purchaseDate[string]: The date and time that the item was purchased.
* quantity[number]: The number of items purchased.
* subscriptionExpirationDate[string]: The expiration date for the subscription.
* transactionIdentifier[string]: The transaction identifier of the item that was purchased.
* webOrderLineItemID[string]: The primary key for identifying subscription purchases.
 
For more information on receipt properties checkout Apple's [ReceiptFields Documentation](https://developer.apple.com/library/ios/releasenotes/General/ValidateAppStoreReceipt/Chapters/ReceiptFields.html).

### suppressSimulatorWarning[boolean]

Used to disable the alert dialog that pops up when running on the simulator. Set this property to true to disable the dialog.

The alert dialog was added to warn users against testing Storekit on the simulator.

## Constants

### TRANSACTION_STATE_PURCHASING[int]

The PURCHASING state during purchase request processing.

### TRANSACTION_STATE_PURCHASED[int]

The PURCHASED state during purchase request processing.

### TRANSACTION_STATE_FAILED[int]

The FAILED state during purchase request processing.

### TRANSACTION_STATE_RESTORED[int]

The RESTORED state during purchase request processing.

### TRANSACTION_STATE_DEFERRED[int]

The DEFERRED state during purchase request processing.

### DOWNLOAD_STATE_WAITING[int]

The WAITING state during download request processing.

### DOWNLOAD_STATE_ACTIVE[int]

The ACTIVE state during download request processing.

### DOWNLOAD_STATE_PAUSED[int]

The PAUSED state during download request processing.

### DOWNLOAD_STATE_FINISHED[int]

The FINISHED state during download request processing.

### DOWNLOAD_STATE_FAILED[int]

The FAILED state during download request processing.

### DOWNLOAD_STATE_CANCELLED[int]

The CANCELLED state during download request processing.

### DOWNLOAD_TIME_REMAINING_UNKNOWN[int]

The value of `timeRemaining` when it cannot create a good estimate.

## Events

### transactionState

Occurs if you call Ti.Storekit.purchase and the purchase request's state changes. The following event information will be provided:

For state _Ti.Storekit.TRANSACTION_STATE_FAILED_, the following additional information will be provided:

* cancelled[boolean]: Whether the failure is due to cancellation of the request or not
* message[string]: Error message if the transaction failed and was not cancelled.

For state _Ti.Storekit.TRANSACTION_STATE_PURCHASED_ and _Ti.Storekit.TRANSACTION_STATE_RESTORED_, the following additional information will be provided:

* transaction[[Ti.Storekit.Transaction][]]: The transaction that changed state

**The following `transactionState` event properties are DEPRECATED. Use the `transaction` event property instead.** 

* state[int]: The current state of the transaction; either _Ti.Storekit.TRANSACTION_STATE_FAILED_, _Ti.Storekit.TRANSACTION_STATE_PURCHASED_,
_Ti.Storekit.PURCHASING_, or _Ti.Storekit.TRANSACTION_STATE_RESTORED_.
* quantity[int]: The number of items purchased or requested to purchase.
* productIdentifier[string]: The product's identifier in the in-app store.
* date[date]: Transaction date
* identifier[string]: The transaction identifier
* receipt[string]: A Base 64-string which contains the receipt information for the purchase.


### restoredCompletedTransactions

Occurs if you call `Ti.Storekit.restoreCompletedTransactions` and no errors are encountered. The following event information
will be provided:

* error[string]: An error message, if one was encountered.
* transactions[array<[Ti.Storekit.Transaction][]>]: If no errors were encountered, all of the transactions that were restored.

Each transaction can contain the following properties:

### updatedDownloads

Occurs when one or more downloads are updated. The following event information will be provided:

* downloads[array<[Ti.Storekit.Download][]>]: The downloads that were updated.

## Usage

See example.

## Author

Jeff Haynie, Jeff English, Jon Alter & Hans Knöchel.

## Module History

View the [change log](changelog.html) for this module.

## Feedback and Support

Please direct all questions, feedback, and concerns to [JIRA](http://jira.appcelerator.com).

## License

Copyright(c) 2010-2017 by Appcelerator, Inc. All Rights Reserved. Please see the LICENSE file included in the distribution for further details.

[Ti.Storekit.ProductRequest]: productRequest.html
[Ti.Storekit.Product]: product.html
[Ti.Storekit.Download]: download.html
[Ti.Storekit.Transaction]: transaction.html

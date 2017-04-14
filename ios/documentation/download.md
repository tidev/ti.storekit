# Ti.Storekit.Download

## Description

A _Ti.Storekit_ module object which represents a Download.

Read more about downloads in Apple's [SKDownload Reference](https://developer.apple.com/library/ios/documentation/StoreKit/Reference/SKDownload_Ref/Introduction/Introduction.html)

## Properties

### contentIdentifier[string] (read-only)

A string that uniquely identifies the downloadable content.

Each piece of downloadable content associated with a product has its own unique identifier. The content identifier is specified in iTunes Connect when you add the content.

### contentURL[string] (read-only)

The local location of the downloaded file.

The value of this property is valid only when the downloadState property is set to `DOWNLOAD_STATE_FINISHED`. The URL becomes invalid after the transaction object associated with the download is finalized. After a download completes, read the download object's contentURL property to get a URL to the downloaded content. Your app must process the downloaded file before completing the 
transaction. Downloaded files should be moved out of cache if you wish to persist them. 

### contentVersion[string] (read-only)

A string that identifies which version of the content is available for download.

The version string must be formatted as a series of integers separated by periods.

### contentLength[number] (read-only)

The length of the downloadable content, in bytes.

### downloadState[int] (read-only)

The current state of the download object.

After you queue a download object, the `updatedDownloads` event fires when the state of the download object changes. Your transaction observer should read the downloadState property and use it to determine how to proceed. For more information on the different states, see the `DOWNLOAD_STATE` constants.

### error[string] (read-only)

The decription of the error that prevented the content from being downloaded.

The value of this property is valid only when the `downloadState` property is set to `DOWNLOAD_STATE_FAILED`.

### progress[number] (read-only)

A value that indicates how much of the file has been downloaded.

The value of this property is a floating point number between 0.0 and 1.0, inclusive, where 0.0 means no data has been download and 1.0 means all the data has been downloaded. Typically, your app uses the value of this property to update a user interface element, such as a progress bar, that displays how much of the file has been downloaded.

### timeRemaining[number] (read-only)

An estimated time, in milliseconds, to finish downloading the content.

The system attempts to estimate how long it will take to finish downloading the file. If it cannot create a good estimate, the value of this property is set to `DOWNLOAD_TIME_REMAINING_UNKNOWN`.

### transaction[[Ti.Storekit.Transaction][]] (read-only)

The transaction associated with the downloadable file.

A download object is always associated with a payment transaction. The download object may only be queued after payment is processed and before the transaction is finished.

[Ti.Storekit.Transaction]: transaction.html

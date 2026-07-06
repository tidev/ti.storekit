# Ti.Storekit.Download

> ⚠️ **Deprecated in iOS 16.** Apple no longer supports hosted content via `SKDownload`. This class is kept for backwards compatibility. Apple recommends migrating to [On-Demand Resources](https://developer.apple.com/library/archive/documentation/FileManagement/Conceptual/On_Demand_Resources_Guide/).

## Description

A `Ti.Storekit` module object which represents an Apple-hosted downloadable content file associated with an In-App Purchase product.

`autoFinishTransactions` must be set to `false` before using downloads. Do not finish the associated transaction until the download is complete — finishing early will cancel the download.

## Properties

### contentIdentifier [String] (read-only)

A string that uniquely identifies the downloadable content. Set in App Store Connect when the content is uploaded.

### contentURL [String] (read-only)

The local path to the downloaded file.

Valid only when `downloadState` is `DOWNLOAD_STATE_FINISHED`. The URL becomes invalid after the associated transaction is finished. Move the file out of the cache directory if you need to persist it.

### contentVersion [String] (read-only)

Identifies which version of the content is available. Formatted as a series of integers separated by periods.

### contentLength [Number] (read-only)

The size of the downloadable file in bytes.

### downloadState [int] (read-only)

The current download state. One of:

| Constant | Description |
|---|---|
| `DOWNLOAD_STATE_WAITING` | Queued, not yet started |
| `DOWNLOAD_STATE_ACTIVE` | Actively downloading |
| `DOWNLOAD_STATE_PAUSED` | Paused |
| `DOWNLOAD_STATE_FINISHED` | Complete — `contentURL` is now valid |
| `DOWNLOAD_STATE_FAILED` | Failed — check `error` |
| `DOWNLOAD_STATE_CANCELLED` | Cancelled |

### error [String] (read-only)

A description of the error that prevented the download from completing. Valid only when `downloadState` is `DOWNLOAD_STATE_FAILED`.

### progress [Number] (read-only)

How much of the file has been downloaded, from `0.0` (nothing) to `1.0` (complete). Use this to drive a progress bar.

### timeRemaining [Number] (read-only)

Estimated milliseconds remaining. Set to `DOWNLOAD_TIME_REMAINING_UNKNOWN` when the system cannot produce a reliable estimate.

### transaction [Ti.Storekit.Transaction] (read-only)

The transaction associated with this download. Do not call `finish()` on the transaction until all associated downloads reach `DOWNLOAD_STATE_FINISHED`, `DOWNLOAD_STATE_FAILED`, or `DOWNLOAD_STATE_CANCELLED`.

## Example

```javascript
var StoreKit = require('ti.storekit');

StoreKit.autoFinishTransactions = false;

StoreKit.addEventListener('transactionState', function(evt) {
    if (evt.state === StoreKit.TRANSACTION_STATE_PURCHASED && evt.downloads) {
        StoreKit.startDownloads({ downloads: evt.downloads });
    }
});

StoreKit.addEventListener('updatedDownloads', function(evt) {
    evt.downloads.forEach(function(dl) {
        console.log('Progress:', Math.round(dl.progress * 100) + '%');

        switch (dl.downloadState) {
            case StoreKit.DOWNLOAD_STATE_FINISHED:
                var file = Ti.Filesystem.getFile(dl.contentURL, 'Contents', 'myfile.dat');
                if (file.exists()) {
                    // Process the downloaded file
                }
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
```

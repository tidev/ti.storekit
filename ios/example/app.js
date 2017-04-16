/*
 Learn the basics of Storekit with this example.

 Before we can do anything in our app, we need to set up iTunesConnect! This process can be a little painful, but I will
 guide you through it so you don't have to figure it out on your own.

 Follow these steps:

 1) Log in to your Apple Developer account at https://itunesconnect.apple.com/
 2) Click "Manage Your Applications".
 3) If you have already set up your app, click on its icon. If not, click "Add New App" and set up your app.
 4) Click "Manage In-App Purchases".
 5) Click "Create New".
 6) Click "Select" beneath "Non-Consumable".
 7) In "Reference Name" type "Soda Pop", and in "Product ID" type "DigitalSodaPop".
 8) Click "Add Language", and fill out all of the fields. (What you enter here isn't important to this example.)
 9) Select a Price Tier, and upload a Screenshot. For testing purposes, using your app's splash screen is easiest.
 10) Click "Save".
 11) Click "Create New" again, and this time click "Select" beneath "Auto-Renewable Subscriptions".
 12) Click "Create New Family" and fill out all of the required fields.
 13) When asked, enter "MonthlySodaPop" for the Product ID, and save the product.

 iTunesConnect is now set up with at least two products with the IDs "DigitalSodaPop" and "MonthlySodaPop".

 To test a Downloadable Apple Hosted In-App Purchase, also follow these steps:

 1) Go to "Manage In-App Purchases" from above.
 2) Click "Create New".
 3) Click "Select" beneath "Non-Consumable".
 4) In "Reference Name" type "DownloadablePop", and in "Product ID" type "DownloadablePop".
 5) Under "Hosting Content with Apple" click "Yes".
 6) Fill out all of the required fields.
 7) Follow this guide to create and upload some hosted content: https://github.com/appcelerator-modules/ti.storekit/wiki/Creating-App-Store-Hosted-Content
	a) Notice the "DownloadablePop" folder in the "example" folder. It was included as an example, but you should make your own content project.
	b) Ensure that the image that is added to the package is named "DownloadablePop.jpeg", as it is in the example project.

 Now we're ready to use Storekit in our app. We're going to do 7 different activities:

 1) Checking if the user can make purchases.
 2) Tracking what the user has purchased in the past.
 3) Buying a single item.
 4) Buying a subscription.
 5) Buying Apple Hosted Content.
 6) Restoring past purchases.
 7) Receipt verification.

 Look at the JavaScript below to understand how we do each of these.

 Then, when you are ready to test the app, follow these steps:

 1) Storekit works in two different environments: "Live" and "Sandbox". "Sandbox" is used during development of your
 application. "Live" is only used when your application is distributed via the App Store.
 2) Log in to your Apple Developer account at https://itunesconnect.apple.com/
 3) Click "Manage Users" and create a "Test User".
 4) Run your app on device to test.
 5) Be sure to use a "Development" Provisioning Profile and an "App ID" with "In-App Purchase" enabled.
 6) When prompted to login, login with the "Test User" that you created.

 To test validating receipts on iOS 7 and above, follow the instructions below when running the app:

 1) Obtain the Apple Inc. root certificate.
 	a) This can be found here: http://www.apple.com/certificateauthority/
 	b) Or download the Apple Inc. Root Certificate directly here: http://www.apple.com/appleca/AppleIncRootCertificate.cer
 2) Add the AppleIncRootCertificate.cer to your app's `Resources` folder.
 3) Set 'bundleVersion' and 'bundleIdentifier' below your app's respective values.
 4) Build the app once through Titanium.
 5) Go to the "build" folder of the app and open the Xcode project with Xcode.
 6) Once the project is open, click on the project on the left in Xcode.
 7) In the center section of Xcode, select the "General" tab.
 8) Under "General", make sure that the "Version" is what you expect it to be.
 9) If the version is not what you expect (maybe something like 1.0.0.1382133876099) change it to its correct value (in this case 1.0.0).
 10) Plug in your device.
 11) At the top left of Xcode, select the connected device.
 12) At the top left of Xcode, click "Build and run" (it looks like a play button).

 */
var Storekit = require('ti.storekit');

/*
 Name of some product identifiers (Non-Consumable, Auto-Renewable and Downloadable)
 */
var DigitalSodaPop = 'DigitalSodaPop';
var MonthlySodaPop = 'MonthlySodaPop';
var DownloadablePop = 'DownloadablePop';

/*
 autoFinishTransactions must be disabled (false) in order to start Apple hosted downloads.
 If autoFinishTransactions is disabled, it is up to you to finish the transactions.
 Transactions must be finished! Failing to finish transactions will cause your app to run slowly.
 Finishing a transaction at any time before its associated download is complete will cancel the download.
 */
Storekit.autoFinishTransactions = false;

/*
 bundleVersion and bundleIdentifier must be set before calling validateReceipt().
 Do not pull these values from the app, they should be hard coded for security reasons.
 */
Storekit.bundleVersion = "1.0.0"; // eg. "1.0.0"
Storekit.bundleIdentifier = "com.appc.teststore"; // eg. "com.appc.storekit"


var verifyingReceipts = false;

var win = Ti.UI.createWindow({
    backgroundColor: '#fff'
});

/*
 We want to show the user when we're communicating with the server, so let's define two simple
 functions that interact with an activity indicator.
 */
var loading = Ti.UI.createActivityIndicator({
    bottom: 10,
    height: 50,
    width: 50,
    backgroundColor: 'black',
    borderRadius: 10,
    style: Ti.UI.ActivityIndicatorStyle.BIG
});
var loadingCount = 0;

function showLoading() {
    loadingCount += 1;
    if (loadingCount == 1) {
        loading.show();
    }
}

function hideLoading() {
    if (loadingCount > 0) {
        loadingCount -= 1;
        if (loadingCount == 0) {
            loading.hide();
        }
    }
}
win.add(loading);

/*
 Now let's define a couple utility functions. We'll use these throughout the app.
 */
var tempPurchasedStore = {};

/**
 * Keeps track (internally) of purchased products.
 * @param identifier The identifier of the Ti.Storekit.Product that was purchased.
 */
function markProductAsPurchased(identifier) {
    Ti.API.info('Marking as purchased: ' + identifier);
    // Store it in an object for immediate retrieval.
    tempPurchasedStore[identifier] = true;
    // And in to Ti.App.Properties for persistent storage.
    Ti.App.Properties.setBool('Purchased-' + identifier, true);
}

/**
 * Checks if a product has been purchased in the past, based on our internal memory.
 * @param identifier The identifier of the Ti.Storekit.Product that was purchased.
 */
function checkIfProductPurchased(identifier) {
    Ti.API.info('Checking if purchased: ' + identifier);
    if (tempPurchasedStore[identifier] === undefined)
        tempPurchasedStore[identifier] = Ti.App.Properties.getBool('Purchased-' + identifier, false);
    return tempPurchasedStore[identifier];
}

/**
 * Requests a product. Use this to get the information you have set up in iTunesConnect, like the localized name and
 * price for the current user.
 * @param identifier The identifier of the product, as specified in iTunesConnect.
 * @param success A callback function.
 * @return A Ti.Storekit.Product.
 */
function requestProduct(identifier, success) {
    showLoading();
    Storekit.requestProducts([identifier], function(evt) {
        hideLoading();
        if (!evt.success) {
            Ti.API.error('ERROR: We failed to talk to Apple!');
        } else if (evt.invalid) {
            Ti.API.error('ERROR: We requested an invalid product (' + identifier + '):');
			Ti.API.error(evt);
        } else {
			Ti.API.info('Valid Product:');
			Ti.API.info(evt);
            success(evt.products[0]);
        }
    });
}

/**
 * Purchases a product.
 * @param product A Ti.Storekit.Product (hint: use Storekit.requestProducts to get one of these!).
 */
Storekit.addEventListener('transactionState', function(evt) {
    hideLoading();
    switch (evt.state) {
        case Storekit.TRANSACTION_STATE_FAILED:
            if (evt.cancelled) {
                Ti.API.warn('Purchase cancelled');
            } else {
                Ti.API.error('ERROR: Buying failed! ' + evt.message);
            }
            evt.transaction && evt.transaction.finish();
            break;
        case Storekit.TRANSACTION_STATE_PURCHASED:

            // Receive the receipt
            var receiptB64String = evt.receipt;
            
            if (receiptB64String) {
                Ti.API.info('Receipt Data (Base64):');
                Ti.API.info(receiptB64String);                
            }

            if (verifyingReceipts) {
                var msg = Storekit.validateReceipt() ? 'Receipt is Valid!' : 'Receipt is Invalid.';
                Ti.API.info('Validation: ' + msg);
            } else {
                Ti.API.info('Successfully purchased, thanks!');
                markProductAsPurchased(evt.productIdentifier);
            }

            // If the transaction has hosted content, the downloads property will exist
            // Downloads that exist in a PURCHASED state should be downloaded immediately, because they were just purchased.
            if (evt.downloads) {
                Storekit.startDownloads({
                    downloads: evt.downloads
                });
            } else {
                // Do not finish the transaction here if you wish to start the download associated with it.
                // The transaction should be finished when the download is complete.
                // Finishing a transaction before the download is finished will cancel the download.
                evt.transaction && evt.transaction.finish();
            }

            break;
        case Storekit.TRANSACTION_STATE_PURCHASING:
            Ti.API.info('Purchasing ' + evt.productIdentifier);
            break;
		case Storekit.TRANSACTION_STATE_DEFERRED:
			Ti.API.info('Deferring ' + evt.productIdentifier + ': The transaction is in the queue, but its final status is pending external action.');
			break;
        case Storekit.TRANSACTION_STATE_RESTORED:
            // The complete list of restored products is sent with the `restoredCompletedTransactions` event
            Ti.API.info('Restored ' + evt.productIdentifier);
            // Downloads that exist in a RESTORED state should not necessarily be downloaded immediately. Leave it up to the user.
            if (evt.downloads) {
                Ti.API.info('Downloads available for restored product');
            }

            evt.transaction && evt.transaction.finish();
            break;
    }
});

/**
 * Notification of an Apple hosted product being downloaded.
 * Only supported on iOS 6.0 and later, but it doesn't hurt to add the listener.
 */
Storekit.addEventListener('updatedDownloads', function(evt) {
    var download;
    for (var i = 0, j = evt.downloads.length; i < j; i++) {
        download = evt.downloads[i];
        Ti.API.info('Updated: ' + download.contentIdentifier + ' Progress: ' + download.progress);
        switch (download.downloadState) {
            case Storekit.DOWNLOAD_STATE_FINISHED:
            case Storekit.DOWNLOAD_STATE_FAILED:
            case Storekit.DOWNLOAD_STATE_CANCELLED:
                hideLoading();
                break;
        }

        switch (download.downloadState) {
            case Storekit.DOWNLOAD_STATE_FAILED:
            case Storekit.DOWNLOAD_STATE_CANCELLED:
                download.transaction && download.transaction.finish();
                break;
            case Storekit.DOWNLOAD_STATE_FINISHED:
                // Apple hosted content can be found in a 'Contents' folder at the location specified by the the 'contentURL'
                // The name of the content does not need to be the same as the contentIdentifier,
                // it is the same in this example for simplicity.
                var file = Ti.Filesystem.getFile(download.contentURL, 'Contents', download.contentIdentifier + '.jpeg');
                if (file.exists()) {
                    Ti.API.info('File exists. Displaying it...');
                    var iv = Ti.UI.createImageView({
                        bottom: 0,
                        left: 0,
                        image: file.read()
                    });
                    iv.addEventListener('click', function() {
                        win.remove(iv);
                        iv = null;
                    });
                    win.add(iv);
                } else {
                    Ti.API.error('Downloaded File does not exist at: ' + file.nativePath);
                }

                // The transaction associated with the download that completed needs to be finished.
                download.transaction && download.transaction.finish();
                break;
        }
    }
});

function purchaseProduct(product) {
    if (product.downloadable) {
        Ti.API.info('Purchasing a product that is downloadable');
    }
    showLoading();
    Storekit.purchase({
        product: product
        // applicationUsername is a opaque identifier for the user’s account on your system.
        // Used by Apple to detect irregular activity. Should hash the username before setting.
        // applicationUsername: '<HASHED APPLICATION USERNAME>'
    });
}

/**
 * Restores any purchases that the current user has made in the past, but we have lost memory of.
 */
function restorePurchases() {
    showLoading();
    Storekit.restoreCompletedTransactions();

    //  You can also restore transaction with an application username
    //  See: https://developer.apple.com/library/ios/documentation/StoreKit/Reference/SKPaymentQueue_Class/#//apple_ref/occ/instm/SKPaymentQueue/restoreCompletedTransactionsWithApplicationUsername:
    //  Storekit.restoreCompletedTransactionsWithApplicationUsername("my_username");
}

Storekit.addEventListener('restoredCompletedTransactions', function(evt) {
    hideLoading();
    if (evt.error) {
        Ti.API.error(evt.error);
    } else if (evt.transactions == null || evt.transactions.length == 0) {
        Ti.API.warn('There were no purchases to restore!');
    } else {
        if (verifyingReceipts) {
            if (Storekit.validateReceipt()) {
                Ti.API.info('Restored Receipt is Valid!');
            } else {
                Ti.API.error('Restored Receipt is Invalid.');
            }
        }
        for (var i = 0; i < evt.transactions.length; i++) {
            markProductAsPurchased(evt.transactions[i].productIdentifier);
        }
        Ti.API.info('Restored ' + evt.transactions.length + ' purchases!');
    }
});

/**
 * WARNING
 * addTransactionObserver must be called after adding the Storekit event listeners.
 * Failure to call addTransactionObserver will result in no Storekit events getting fired.
 * Calling addTransactionObserver before event listeners are added can result in lost events.
 */
Storekit.addTransactionObserver();

/**
 * Validating receipt at startup
 * Useful for volume purchase programs.
 */
win.addEventListener('open', function() {
    function validate() {
        Ti.API.info('Validating receipt.');
        Ti.API.info('Receipt is Valid: ' + Storekit.validateReceipt());
    }

    /*
     During development it is possible that the receipt does not exist.
     This can be resolved by refreshing the receipt.
     */
    if (!Storekit.receiptExists) {
        Ti.API.info('Receipt does not exist yet. Refreshing to get one.');
        Storekit.refreshReceipt(null, function() {
            validate();
        });
    } else {
        Ti.API.info('Receipt does exist.');
        validate();
    }
});

/*
 1) Can the user make payments? Their device may be locked down, or this may be a simulator.
 */
if (!Storekit.canMakePayments)
    Ti.API.error('This device cannot make purchases!');
else {
    /*
     2) Tracking what the user has purchased in the past.
     */
    var whatHaveIPurchased = Ti.UI.createButton({
        title: 'What Have I Purchased?',
        top: 10,
        left: 5,
        right: 5,
        height: 40
    });
    whatHaveIPurchased.addEventListener('click', function() {
        Ti.API.info({
            'Single Item': checkIfProductPurchased(DigitalSodaPop) ? 'Purchased!' : 'Not Yet',
            'Subscription': checkIfProductPurchased(MonthlySodaPop) ? 'Purchased!' : 'Not Yet',
            'Downloadable': checkIfProductPurchased(DownloadablePop) ? 'Purchased!' : 'Not Yet',
        });
    });
    win.add(whatHaveIPurchased);

    /*
     3) Buying a single item.
     */
    requestProduct(DigitalSodaPop, function(product) {
        var buySingleItem = Ti.UI.createButton({
            title: 'Buy ' + product.title + ', ' + product.formattedPrice,
            top: 60,
            left: 5,
            right: 5,
            height: 40
        });
        buySingleItem.addEventListener('click', function() {
            purchaseProduct(product);
        });
        win.add(buySingleItem);
    });

    /*
     4) Buying a subscription.
     */
    requestProduct(MonthlySodaPop, function(product) {
        var buySubscription = Ti.UI.createButton({
            title: 'Buy ' + product.title + ', ' + product.formattedPrice,
            top: 110,
            left: 5,
            right: 5,
            height: 40
        });
        buySubscription.addEventListener('click', function() {
            purchaseProduct(product);
        });
        win.add(buySubscription);
    });

    /*
     5) Buying Apple Hosted Content.
     */
    requestProduct(DownloadablePop, function(product) {
        var buySubscription = Ti.UI.createButton({
            title: 'Buy ' + product.title + ', ' + product.formattedPrice,
            top: 160,
            left: 5,
            right: 5,
            height: 40
        });
        buySubscription.addEventListener('click', function() {
            purchaseProduct(product);
        });
        win.add(buySubscription);
    });

    /*
     6) Restoring past purchases.
     */
    var restoreCompletedTransactions = Ti.UI.createButton({
        title: 'Restore Lost Purchases',
        top: 210,
        left: 5,
        right: 5,
        height: 40
    });
    restoreCompletedTransactions.addEventListener('click', function() {
        restorePurchases();
    });
    win.add(restoreCompletedTransactions);

    /*
     7) Receipt verification.
     */
    var view = Ti.UI.createView({
        layout: 'horizontal',
        top: 260,
        left: 10
    });
    var verifyingLabel = Ti.UI.createLabel({
        text: 'Verify receipts:'
    });
    var onSwitch = Ti.UI.createSwitch({
        value: false,
        isSwitch: true,
        left: 4
    });
    onSwitch.addEventListener('change', function(e) {
        verifyingReceipts = e.value;
    });
    view.add(verifyingLabel);
    view.add(onSwitch);
    win.add(view);
}

win.open();

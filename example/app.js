/**
 * Ti.Storekit — Example app.js (iOS 17+)
 *
 * Demonstrates a complete In-App Purchase flow using:
 *  - App Store Server API validation via originalTransactionId (recommended)
 *  - Purchase intent flag to distinguish new purchases from pending queue transactions
 *  - Debounced background validation to avoid rate limiting
 *  - Local subscription cache (12h TTL) for instant startup response
 *  - Restore purchases with server-side validation
 *
 * Setup in App Store Connect:
 *  1. Create your products (Non-Consumable and/or Auto-Renewable Subscriptions)
 *  2. Set up a Sandbox tester: Users and Access → Sandbox → Testers
 *  3. On device: Settings → App Store → Sandbox Account → Sign In
 *
 * Testing notes:
 *  - StoreKit does NOT work in the Simulator — always test on a real device
 *  - Use a Development Provisioning Profile with In-App Purchase enabled
 *  - Agree to all contracts in App Store Connect → Agreements, Tax, and Banking
 *  - In Sandbox, monthly subscriptions renew every 5 minutes (max 12 renewals)
 */

var StoreKit = require('ti.storekit');

// ─── Product identifiers ───────────────────────────────────────────────────────
// Replace with your actual product IDs from App Store Connect
var PRODUCT_NON_CONSUMABLE = 'com.example.app.remove.ads';
var PRODUCT_SUBSCRIPTION_MONTHLY = 'com.example.app.subscription.monthly';
var PRODUCT_SUBSCRIPTION_YEARLY = 'com.example.app.subscription.yearly';

var ALL_PRODUCT_IDS = [
    PRODUCT_NON_CONSUMABLE,
    PRODUCT_SUBSCRIPTION_MONTHLY,
    PRODUCT_SUBSCRIPTION_YEARLY
];

// ─── Server configuration ─────────────────────────────────────────────────────
// Your server endpoint that validates originalTransactionId via App Store Server API.
// See: https://developer.apple.com/documentation/appstoreserverapi
var SERVER_BASE_URL = 'https://api.yourserver.com';
var SERVER_API_KEY = 'your-api-key-here';

// ─── Log helpers ──────────────────────────────────────────────────────────────
var TAG = '[StoreKit]';
function logInfo(msg) { Ti.API.info(TAG + ' ℹ️  ' + msg); }
function logOk(msg) { Ti.API.info(TAG + ' ✅  ' + msg); }
function logWarn(msg) { Ti.API.warn(TAG + ' ⚠️  ' + msg); }
function logError(msg) { Ti.API.error(TAG + ' ❌  ' + msg); }
function logSep() { Ti.API.info(TAG + ' ─────────────────────────────────'); }

// ─── StoreKit config ──────────────────────────────────────────────────────────
// Set false so we control when transactions are finished.
// This is required for proper server-side validation before finishing.
StoreKit.autoFinishTransactions = false;

// ─── Purchase intent flag ─────────────────────────────────────────────────────
// Distinguishes a user-initiated purchase from pending queue transactions
// (e.g. auto-renewals, deferred purchases) that arrive when the app opens.
// Without this flag, pending queue transactions would trigger the purchase UI
// or error callbacks incorrectly.
var _purchaseIntentActive = false;
var _purchaseIntentTimer = null;

function _setPurchaseIntent() {
    _purchaseIntentActive = true;
    if (_purchaseIntentTimer) clearTimeout(_purchaseIntentTimer);
    // Auto-expire after 5 minutes — enough time for the Apple prompt to appear
    _purchaseIntentTimer = setTimeout(function() {
        _purchaseIntentActive = false;
        _purchaseIntentTimer = null;
        logWarn('Purchase intent expired — no purchase confirmed in 5 minutes');
    }, 5 * 60 * 1000);
}

function _clearPurchaseIntent() {
    _purchaseIntentActive = false;
    if (_purchaseIntentTimer) {
        clearTimeout(_purchaseIntentTimer);
        _purchaseIntentTimer = null;
    }
}

// ─── Retryable error timer ────────────────────────────────────────────────────
// Some SKErrors (e.g. AMSErrorDomain 301) are transient — the SKPaymentQueue
// will retry automatically. We wait 8s before surfacing the error to the user.
var _retryableErrorTimer = null;

// ─── Debounce for pending queue transactions ──────────────────────────────────
// When the app opens with many pending transactions (e.g. accumulated renewals),
// SKPaymentQueue delivers them in rapid succession. Without debouncing, each one
// would trigger a separate server validation call and could exhaust rate limits.
// The debounce collapses N transactions into a single server call.
var _pendingValidationTimer = null;
var _pendingValidationId = null;
var DEBOUNCE_DELAY_MS = 2000;

function _validatePendingDebounced(originalTransactionId) {
    _pendingValidationId = originalTransactionId;
    if (_pendingValidationTimer) clearTimeout(_pendingValidationTimer);
    _pendingValidationTimer = setTimeout(function() {
        _pendingValidationTimer = null;
        var idToValidate = _pendingValidationId;
        _pendingValidationId = null;
        logInfo('Debounce complete — validating pending transaction...');
        validateOnServer(idToValidate, function(sub) {
            if (sub && !sub.error && sub.is_active) {
                saveSubscriptionCache(sub);
                logOk('Cache updated from pending transaction');
            }
        });
    }, DEBOUNCE_DELAY_MS);
}

// ─── Local subscription cache ─────────────────────────────────────────────────
// Caches the last known subscription state locally so the app can respond
// immediately on startup without a network round-trip.
// The cache is bypassed if:
//  - It is older than CACHE_TTL_MS
//  - The cached expires_date has already passed
var CACHE_KEY_IS_ACTIVE = 'sk_subscription_is_active';
var CACHE_KEY_EXPIRES_DATE = 'sk_subscription_expires_date';
var CACHE_KEY_PRODUCT_ID = 'sk_subscription_product_id';
var CACHE_KEY_VALIDATED_AT = 'sk_subscription_validated_at';

// 12 hours in production. Lower (e.g. 5 * 60 * 1000) during testing.
var CACHE_TTL_MS = 12 * 60 * 60 * 1000;

function saveSubscriptionCache(sub) {
    if (!sub) return;
    Ti.App.Properties.setBool(CACHE_KEY_IS_ACTIVE, sub.is_active || false);
    Ti.App.Properties.setString(CACHE_KEY_EXPIRES_DATE, sub.expires_date || '');
    Ti.App.Properties.setString(CACHE_KEY_PRODUCT_ID, sub.product_id || '');
    Ti.App.Properties.setString(CACHE_KEY_VALIDATED_AT, new Date().toISOString());
    logOk('Subscription cache saved');
}

function loadSubscriptionCache() {
    var validatedAt = Ti.App.Properties.getString(CACHE_KEY_VALIDATED_AT, '');
    if (!validatedAt) return null;

    var age = Date.now() - new Date(validatedAt).getTime();
    if (age > CACHE_TTL_MS) {
        logInfo('Cache expired (' + Math.round(age / 60000) + 'min) — needs validation');
        return null;
    }

    var expiresDate = Ti.App.Properties.getString(CACHE_KEY_EXPIRES_DATE, '');
    if (expiresDate && new Date(expiresDate) < new Date()) {
        logWarn('Subscription expired since last cache — needs validation');
        return null;
    }

    logInfo('Valid cache found (' + Math.round(age / 60000) + 'min ago)');
    return {
        is_active: Ti.App.Properties.getBool(CACHE_KEY_IS_ACTIVE, false),
        expires_date: expiresDate,
        product_id: Ti.App.Properties.getString(CACHE_KEY_PRODUCT_ID, ''),
        from_cache: true
    };
}

function clearSubscriptionCache() {
    Ti.App.Properties.removeProperty(CACHE_KEY_IS_ACTIVE);
    Ti.App.Properties.removeProperty(CACHE_KEY_EXPIRES_DATE);
    Ti.App.Properties.removeProperty(CACHE_KEY_PRODUCT_ID);
    Ti.App.Properties.removeProperty(CACHE_KEY_VALIDATED_AT);
    logWarn('Subscription cache cleared');
}

// ─── Server-side validation ───────────────────────────────────────────────────
/**
 * Sends the originalTransactionId to your server for validation via
 * the App Store Server API. Your server should call:
 *   GET https://api.storekit.itunes.apple.com/inApps/v1/subscriptions/{originalTransactionId}
 *
 * The callback receives the subscription object or { error }.
 */
function validateOnServer(originalTransactionId, callback) {
    logInfo('Sending originalTransactionId to server...');
    logInfo('  originalTransactionId: ' + originalTransactionId);

    var xhr = Ti.Network.createHTTPClient({
        onload: function() {
            logOk('Server response received (HTTP ' + this.status + ')');
            try {
                var response = JSON.parse(this.responseText);
                if (!response.success) {
                    logError('Server returned success=false: ' + response.error);
                    callback && callback({ error: response.error || 'Validation error' });
                    return;
                }
                var sub = response.subscription;
                if (sub && sub.is_active) {
                    logOk('Subscription ACTIVE!');
                    logInfo('  Product:      ' + sub.product_id);
                    logInfo('  Expires:      ' + (sub.expires_date ? new Date(sub.expires_date).toLocaleString() : 'N/A'));
                    logInfo('  Auto-renews:  ' + (sub.auto_renew_enabled ? 'Yes' : 'No'));
                    logInfo('  Will renew:   ' + (sub.will_renew ? 'Yes' : 'No'));
                } else {
                    logWarn('Subscription INACTIVE');
                    if (sub && sub.is_cancelled) logWarn('  Reason: Refunded by Apple');
                    if (sub && sub.expiration_intent) logWarn('  Expiration intent: ' + sub.expiration_intent);
                }
                callback && callback(sub);
            } catch (e) {
                logError('Failed to parse server response: ' + e.message);
                callback && callback({ error: 'Invalid server response' });
            }
        },
        onerror: function(e) {
            logError('Network error: ' + e.error + ' (HTTP ' + this.status + ')');
            callback && callback({ error: e.error, status: this.status });
        },
        timeout: 15000
    });

    xhr.open('POST', SERVER_BASE_URL + '/api/validate-subscription');
    xhr.setRequestHeader('Content-Type', 'application/json');
    xhr.setRequestHeader('X-API-Key', SERVER_API_KEY);
    xhr.setRequestHeader('User-Agent', 'ExampleApp/' + Ti.App.version + ' (iOS)');
    xhr.send(JSON.stringify({ originalTransactionId: originalTransactionId }));
}

// ─── Startup subscription check ───────────────────────────────────────────────
/**
 * Call this early in your app startup to determine if the user has an
 * active subscription. Uses cache when available for an instant response,
 * then validates in background to keep the cache fresh.
 *
 * @param {Function} callback Receives { is_active, expires_date, product_id, from_cache } or { error }
 */
function checkSubscriptionOnStartup(callback) {
    logSep();
    logInfo('🚀 Checking subscription on startup...');

    // 1. Serve from cache if valid
    var cached = loadSubscriptionCache();
    if (cached) {
        logOk('Cache hit — ' + (cached.is_active ? 'ACTIVE' : 'INACTIVE'));
        callback && callback(cached);
        // Refresh cache in background without blocking the UI
        _validateInBackground();
        return;
    }

    // 2. No cache — check if we have a saved originalTransactionId
    var savedId = Ti.App.Properties.getString('sk_original_transaction_id', '');
    if (savedId) {
        logOk('Saved originalTransactionId found: ' + savedId);
        validateOnServer(savedId, function(sub) {
            if (sub && !sub.error) saveSubscriptionCache(sub);
            callback && callback(sub);
        });
        return;
    }

    // 3. No transaction ID — user has never purchased or storage was cleared
    logInfo('No originalTransactionId saved — user has no active subscription');
    callback && callback({ is_active: false });
}

function _validateInBackground() {
    var savedId = Ti.App.Properties.getString('sk_original_transaction_id', '');
    if (!savedId) return;
    logInfo('Background validation started...');
    validateOnServer(savedId, function(sub) {
        if (sub && !sub.error) {
            saveSubscriptionCache(sub);
            logOk('Background cache updated');
        }
    });
}

// ─── Product request ──────────────────────────────────────────────────────────
/**
 * Fetches product info for a single product from the App Store.
 * Requests all products at once (one network call) and finds the requested one.
 */
function requestProduct(productId, onSuccess, onFailure) {
    logSep();
    logInfo('Requesting product: ' + productId);

    StoreKit.requestProducts(ALL_PRODUCT_IDS, function(evt) {
        if (!evt.success) {
            logError('App Store unavailable: ' + evt.message);
            onFailure && onFailure({ message: 'Could not connect to the App Store. Please try again.' });
            return;
        }

        if (evt.invalid && evt.invalid.length > 0) {
            logWarn('Invalid product IDs: ' + evt.invalid.join(', '));
        }

        logOk('Products received: ' + evt.products.length);
        logSep();

        var found = null;
        for (var i = 0; i < evt.products.length; i++) {
            var p = evt.products[i];
            logInfo('Product #' + (i + 1) + ': ' + p.identifier);
            logInfo('  Title:   ' + p.title);
            logInfo('  Price:   ' + p.formattedPrice + ' (' + p.price + ')');
            logInfo('  Locale:  ' + p.locale);
            if (p.introductoryPrice) {
                var intro = p.introductoryPrice;
                logInfo('  Intro:   ' + intro.price + ' for ' +
                        intro.subscriptionPeriod.numberOfUnits + ' period(s), mode: ' + intro.paymentMode);
            }
            if (p.subscriptionPeriod) {
                logInfo('  Period:  ' + JSON.stringify(p.subscriptionPeriod));
            }
            logSep();
            if (p.identifier === productId) found = p;
        }

        if (!found) {
            logError('Product not found in response: ' + productId);
            onFailure && onFailure({ message: 'Product not found: ' + productId });
            return;
        }

        logOk('Product found: ' + found.title + ' — ' + found.formattedPrice);
        onSuccess && onSuccess(found);
    });
}

// ─── Purchase ─────────────────────────────────────────────────────────────────
/**
 * Initiates a purchase for the given product ID.
 * Calls onSuccess when the subscription is validated as active,
 * or onFailure with an error message.
 */
function purchase(productId, onSuccess, onFailure) {
    if (!StoreKit.canMakePayments) {
        logError('This device cannot make payments');
        onFailure && onFailure({ message: 'In-App Purchases are not available on this device.' });
        return;
    }

    requestProduct(productId, function(product) {
        logInfo('Initiating purchase: ' + product.identifier);
        _setPurchaseIntent();
        // Store callbacks for use in the transactionState event
        _purchaseSuccessCallback = onSuccess;
        _purchaseFailureCallback = onFailure;
        StoreKit.purchase({ product: product });
    }, function(err) {
        onFailure && onFailure(err);
    });
}

// Callbacks set during purchase — used inside transactionState handler
var _purchaseSuccessCallback = null;
var _purchaseFailureCallback = null;

// ─── Restore purchases ────────────────────────────────────────────────────────
/**
 * Restores previous purchases. The restoredCompletedTransactions event
 * fires when complete. Calls onSuccess if an active subscription is found,
 * or onFailure if nothing is found or an error occurs.
 */
function restorePurchases(onSuccess, onFailure) {
    logInfo('Initiating restore...');
    _restoreSuccessCallback = onSuccess;
    _restoreFailureCallback = onFailure;
    StoreKit.restoreCompletedTransactions();
}

var _restoreSuccessCallback = null;
var _restoreFailureCallback = null;

// ─── StoreKit Events ──────────────────────────────────────────────────────────

StoreKit.addEventListener('transactionState', function(evt) {
    logSep();
    logInfo('transactionState received — state: ' + evt.state);

    switch (evt.state) {

        // ── Failed ──────────────────────────────────────────────────────────────
        case StoreKit.TRANSACTION_STATE_FAILED: {
            var message;

            if (evt.cancelled) {
                logWarn('Purchase cancelled by user');
                _clearPurchaseIntent();
                evt.transaction && evt.transaction.finish();
                _purchaseFailureCallback && _purchaseFailureCallback({ message: 'Purchase cancelled.', user_cancelled: true });
                _purchaseFailureCallback = null;
                break;
            }

            var errorCode = evt.errorCode || 0;
            var retryable = evt.retryable || false;

            logWarn('Transaction failed');
            logWarn('  errorCode: ' + errorCode);
            logWarn('  message:   ' + evt.message);
            logWarn('  retryable: ' + retryable);

            evt.transaction && evt.transaction.finish();

            if (retryable) {
                // Transient Apple server error — wait for automatic retry by SKPaymentQueue.
                // Only notify the user if no PURCHASED event arrives within 8 seconds.
                logWarn('Transient error — waiting for automatic retry...');
                if (_retryableErrorTimer) clearTimeout(_retryableErrorTimer);
                _retryableErrorTimer = setTimeout(function() {
                    _retryableErrorTimer = null;
                    _clearPurchaseIntent();
                    logError('Retry timeout — notifying user');
                    _purchaseFailureCallback && _purchaseFailureCallback({
                        message: 'The service is temporarily unavailable. Please try again.',
                        user_cancelled: false,
                        errorCode: errorCode,
                        retryable: true
                    });
                    _purchaseFailureCallback = null;
                }, 8000);
            } else {
                _clearPurchaseIntent();
                message = evt.message || 'Purchase failed.';
                clearSubscriptionCache();
                _purchaseFailureCallback && _purchaseFailureCallback({
                    message: message,
                    user_cancelled: false,
                    errorCode: errorCode
                });
                _purchaseFailureCallback = null;
            }
            break;
        }

        // ── Purchased ────────────────────────────────────────────────────────────
        case StoreKit.TRANSACTION_STATE_PURCHASED: {

            // A successful purchase also cancels any pending retryable error timer
            if (_retryableErrorTimer) {
                logOk('Automatic retry succeeded — cancelling error timer');
                clearTimeout(_retryableErrorTimer);
                _retryableErrorTimer = null;
            }

            logSep();
            logOk('PURCHASE SUCCESSFUL!');
            logInfo('  Transaction ID:          ' + evt.identifier);
            logInfo('  Original Transaction ID: ' + evt.originalTransactionId);
            logInfo('  Product ID:              ' + evt.productIdentifier);
            logInfo('  Quantity:                ' + evt.quantity);
            logInfo('  Date:                    ' + evt.date);
            logSep();

            // If no purchase intent is active, this is a pending queue transaction
            // (auto-renewal, deferred purchase, etc.) — handle silently in background.
            if (!_purchaseIntentActive) {
                logWarn('No purchase intent active — treating as pending queue transaction');
                logWarn('Finishing silently: ' + evt.identifier);
                evt.transaction && evt.transaction.finish();

                var bgId = evt.originalTransactionId || evt.identifier;
                if (bgId) {
                    Ti.App.Properties.setString('sk_original_transaction_id', bgId);
                    _validatePendingDebounced(bgId);
                }
                break;
            }

            // User-initiated purchase — process normally
            _clearPurchaseIntent();

            var originalTransactionId = evt.originalTransactionId || evt.identifier;
            if (!originalTransactionId) {
                logError('originalTransactionId missing from event!');
                evt.transaction && evt.transaction.finish();
                _purchaseFailureCallback && _purchaseFailureCallback({ message: 'Transaction identifier missing.' });
                _purchaseFailureCallback = null;
                break;
            }

            // Persist for future use (reinstalls, renewals)
            Ti.App.Properties.setString('sk_original_transaction_id', originalTransactionId);
            logOk('originalTransactionId saved: ' + originalTransactionId);

            // Deduplicate — avoid processing the same transaction twice
            var lastId = Ti.App.Properties.getString('sk_last_transaction_id', '');
            if (lastId && lastId === evt.identifier) {
                logWarn('Duplicate transaction — already processed: ' + evt.identifier);
                evt.transaction && evt.transaction.finish();
                break;
            }
            Ti.App.Properties.setString('sk_last_transaction_id', evt.identifier);
            logOk('New transaction — validating on server...');

            validateOnServer(originalTransactionId, function(sub) {
                if (sub && sub.error) {
                    logError('Validation failed: ' + sub.error);
                    _purchaseFailureCallback && _purchaseFailureCallback({ message: 'Subscription validation failed. Please try again.' });
                } else if (sub && sub.is_active) {
                    logOk('Subscription VALIDATED and ACTIVE! 🎉');
                    saveSubscriptionCache(sub);
                    _purchaseSuccessCallback && _purchaseSuccessCallback(sub);
                } else {
                    logWarn('Subscription inactive after purchase');
                    _purchaseFailureCallback && _purchaseFailureCallback({ message: 'Subscription is not active yet. Please try again in a moment.' });
                }
                _purchaseSuccessCallback = null;
                _purchaseFailureCallback = null;
                evt.transaction && evt.transaction.finish();
            });
            break;
        }

        // ── Purchasing (in progress) ──────────────────────────────────────────────
        case StoreKit.TRANSACTION_STATE_PURCHASING:
            logInfo('Processing payment for: ' + evt.productIdentifier);
            break;

        // ── Deferred (Ask to Buy) ─────────────────────────────────────────────────
        case StoreKit.TRANSACTION_STATE_DEFERRED:
            logWarn('Purchase deferred: ' + evt.productIdentifier);
            logWarn('Waiting for Ask to Buy approval from family organizer');
            _clearPurchaseIntent();
            _purchaseFailureCallback && _purchaseFailureCallback({
                message: 'Your purchase is pending approval.',
                user_cancelled: false
            });
            _purchaseFailureCallback = null;
            break;

        // ── Restored ──────────────────────────────────────────────────────────────
        case StoreKit.TRANSACTION_STATE_RESTORED:
            logOk('Transaction restored: ' + evt.productIdentifier);
            var restoredId = evt.originalTransactionId || evt.identifier;
            if (restoredId) {
                Ti.App.Properties.setString('sk_original_transaction_id', restoredId);
                logOk('originalTransactionId saved from restore: ' + restoredId);
            }
            evt.transaction && evt.transaction.finish();
            break;

        default:
            logWarn('Unknown transaction state: ' + evt.state);
            break;
    }
});

// ─── Restore completed ────────────────────────────────────────────────────────

StoreKit.addEventListener('restoredCompletedTransactions', function(evt) {
    logSep();
    logInfo('restoredCompletedTransactions received');

    if (evt.error) {
        logError('Restore failed: ' + evt.error);
        _restoreFailureCallback && _restoreFailureCallback({ message: evt.error });
        _restoreFailureCallback = null;
        return;
    }

    // Wait 3s for individual TRANSACTION_STATE_RESTORED events to finish
    // processing and saving the originalTransactionId before validating.
    setTimeout(function() {
        var savedId = Ti.App.Properties.getString('sk_original_transaction_id', '');
        if (!savedId) {
            logWarn('No purchases found to restore');
            _restoreFailureCallback && _restoreFailureCallback({ message: 'No previous purchases found.' });
            _restoreFailureCallback = null;
            return;
        }

        logOk('Restore complete — validating on server...');
        validateOnServer(savedId, function(sub) {
            if (sub && !sub.error && sub.is_active) {
                saveSubscriptionCache(sub);
                logOk('Restore VALIDATED and ACTIVE! 🎉');
                _restoreSuccessCallback && _restoreSuccessCallback(sub);
            } else {
                logWarn('Restore: subscription inactive or expired');
                _restoreFailureCallback && _restoreFailureCallback({ message: 'No active subscription found to restore.' });
            }
            _restoreSuccessCallback = null;
            _restoreFailureCallback = null;
        });
    }, 3000);
});

// ─── Register observer ────────────────────────────────────────────────────────
// Must be called AFTER adding event listeners to avoid missing events.
logSep();
logInfo('Registering transaction observer...');
StoreKit.addTransactionObserver();
logOk('Transaction observer registered');
logSep();

// ─── UI ───────────────────────────────────────────────────────────────────────

var win = Ti.UI.createWindow({ backgroundColor: '#fff', title: 'In-App Purchase Demo' });

var scrollView = Ti.UI.createScrollView({
    layout: 'vertical',
    height: Ti.UI.FILL,
    width: Ti.UI.FILL,
    contentHeight: Ti.UI.SIZE
});
win.add(scrollView);

var loadingView = Ti.UI.createView({
    width: Ti.UI.FILL,
    height: Ti.UI.FILL,
    backgroundColor: 'rgba(0,0,0,0.4)',
    visible: false,
    zIndex: 100
});
loadingView.add(Ti.UI.createActivityIndicator({
    style: Ti.UI.ActivityIndicatorStyle.BIG,
    color: '#fff'
}));
win.add(loadingView);

function showLoading() { loadingView.visible = true; }
function hideLoading() { loadingView.visible = false; }

function addButton(title, top, onClick) {
    var btn = Ti.UI.createButton({
        title: title,
        top: top || 16,
        left: 16,
        right: 16,
        height: 48
    });
    btn.addEventListener('click', onClick);
    scrollView.add(btn);
    return btn;
}

function addLabel(text, top) {
    var lbl = Ti.UI.createLabel({
        text: text,
        top: top || 8,
        left: 16,
        right: 16,
        color: '#333',
        font: { fontSize: 13 }
    });
    scrollView.add(lbl);
    return lbl;
}

// ─── Canmake payments guard ───────────────────────────────────────────────────
if (!StoreKit.canMakePayments) {
    addLabel('⚠️ In-App Purchases are disabled on this device.', 32);
} else {

    addLabel('StoreKit v5 — Example App', 32);

    // ── Buy monthly subscription ─────────────────────────────────────────────
    addButton('Subscribe Monthly', 24, function() {
        showLoading();
        purchase(PRODUCT_SUBSCRIPTION_MONTHLY, function(sub) {
            hideLoading();
            alert('✅ Subscription active!\nExpires: ' + (sub.expires_date
                ? new Date(sub.expires_date).toLocaleString()
                : 'N/A'));
        }, function(err) {
            hideLoading();
            if (!err.user_cancelled) {
                alert('Purchase failed: ' + err.message);
            }
        });
    });

    // ── Buy yearly subscription ──────────────────────────────────────────────
    addButton('Subscribe Yearly', 8, function() {
        showLoading();
        purchase(PRODUCT_SUBSCRIPTION_YEARLY, function(sub) {
            hideLoading();
            alert('✅ Yearly subscription active!\nExpires: ' + (sub.expires_date
                ? new Date(sub.expires_date).toLocaleString()
                : 'N/A'));
        }, function(err) {
            hideLoading();
            if (!err.user_cancelled) {
                alert('Purchase failed: ' + err.message);
            }
        });
    });

    // ── Buy non-consumable ───────────────────────────────────────────────────
    addButton('Remove Ads (One-Time)', 8, function() {
        showLoading();
        purchase(PRODUCT_NON_CONSUMABLE, function() {
            hideLoading();
            Ti.App.Properties.setBool('ads_removed', true);
            alert('✅ Ads removed! Thank you.');
        }, function(err) {
            hideLoading();
            if (!err.user_cancelled) {
                alert('Purchase failed: ' + err.message);
            }
        });
    });

    // ── Restore purchases ────────────────────────────────────────────────────
    addButton('Restore Purchases', 8, function() {
        showLoading();
        restorePurchases(function(sub) {
            hideLoading();
            alert('✅ Purchases restored!\nActive: ' + (sub.is_active ? 'Yes' : 'No'));
        }, function(err) {
            hideLoading();
            alert(err.message || 'Nothing to restore.');
        });
    });

    // ── Check subscription status ────────────────────────────────────────────
    addButton('Check Subscription Status', 8, function() {
        showLoading();
        checkSubscriptionOnStartup(function(result) {
            hideLoading();
            if (!result || result.error) {
                alert('No subscription found.');
                return;
            }
            alert(
                'Active: ' + (result.is_active ? 'Yes' : 'No') + '\n' +
                'Product: ' + (result.product_id || 'N/A') + '\n' +
                'Expires: ' + (result.expires_date ? new Date(result.expires_date).toLocaleString() : 'N/A') + '\n' +
                'From cache: ' + (result.from_cache ? 'Yes' : 'No')
            );
        });
    });

    // ── Manage subscriptions ─────────────────────────────────────────────────
    addButton('Manage Subscriptions', 8, function() {
        StoreKit.showManageSubscriptions();
    });

    // ── Request review ───────────────────────────────────────────────────────
    addButton('Rate This App ⭐', 8, function() {
        // Apple may not always show the dialog — this is intentional
        StoreKit.requestReviewDialog();
    });

    // ── Show product dialog ──────────────────────────────────────────────────
    addButton('View App in Store', 8, function() {
        StoreKit.addEventListener('productDialogDidClose', function onClose() {
            StoreKit.removeEventListener('productDialogDidClose', onClose);
            logInfo('Product dialog closed');
        });
        StoreKit.showProductDialog({ id: Ti.App.id });
    });

    // ── Clear cache (debug) ──────────────────────────────────────────────────
    addButton('Clear Cache (Debug)', 24, function() {
        clearSubscriptionCache();
        alert('Cache cleared.');
    });
}

// ─── Startup ──────────────────────────────────────────────────────────────────
win.addEventListener('open', function() {
    // Check subscription status as early as possible
    checkSubscriptionOnStartup(function(result) {
        var isActive = result && result.is_active === true;
        var wasActive = Ti.App.Properties.getBool('is_premium', false);

        logInfo('[Startup] Premium: ' + (isActive ? 'ACTIVE' : 'INACTIVE') +
                (result && result.from_cache ? ' (cache)' : ''));

        // Clean up streaming services if user lost premium access
        if (wasActive && !isActive) {
            logWarn('[Startup] Premium access lost — reverting content restrictions');
            // TODO: revert premium-only content here
        }

        if (isActive !== wasActive) {
            Ti.App.Properties.setBool('is_premium', isActive);
            // Refresh UI that depends on premium state
            Ti.App.fireEvent('premiumStatusChanged', { is_active: isActive });
        }
    });

    // Ensure a receipt exists (useful for validation during development)
    if (!StoreKit.receiptExists) {
        logInfo('No receipt on device — requesting one from Apple');
        StoreKit.refreshReceipt(null, function(evt) {
            if (evt.success) {
                logOk('Receipt refreshed');
            } else {
                logWarn('Could not refresh receipt: ' + evt.error);
            }
        });
    }
});

win.open();
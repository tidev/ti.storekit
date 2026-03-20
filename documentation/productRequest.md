# Ti.Storekit.ProductRequest

## Description

A `Ti.Storekit` module object representing an active asynchronous product request to the App Store. Returned by `Ti.Storekit.requestProducts()`.

Use the `cancel()` method to abort a request that is no longer needed (for example, if the user navigates away before the products load).

## Functions

### cancel()

Cancels an in-flight product request. After calling `cancel()`, the callback will not be fired.

## Example

```javascript
var StoreKit = require('ti.storekit');

// Store the request object so you can cancel it if needed
var productRequest = StoreKit.requestProducts([
    'com.example.app.premium',
    'com.example.app.subscription.monthly'
], function(evt) {
    if (!evt.success) {
        console.error('Request failed:', evt.message);
        return;
    }
    console.log('Products received:', evt.products.length);
    if (evt.invalid) {
        console.warn('Invalid IDs:', evt.invalid.join(', '));
    }
});

// Cancel if the user navigates away
someButton.addEventListener('click', function() {
    if (productRequest) {
        productRequest.cancel();
        productRequest = null;
    }
});
```

# Ti.Storekit.Product

## Description

A `Ti.Storekit` module object representing a product retrieved from the App Store. Returned by `Ti.Storekit.requestProducts()`.

## Properties

### identifier [String] (read-only)

The product's unique identifier as configured in App Store Connect.

### title [String] (read-only)

The localized display name of the product.

### description [String] (read-only)

The localized description of the product.

### price [Number] (read-only)

The product price as a decimal number in the store's local currency.

### formattedPrice [String] (read-only)

The price formatted as a currency string for the store's locale (e.g. `"R$ 2,90"`, `"$0.99"`). Use this for display in your UI.

### locale [String] (read-only)

The locale identifier for the store's pricing locale (e.g. `"pt_BR@currency=BRL"`).

### introductoryPrice [Discount] (read-only) *(iOS 11.2+)*

The introductory or free trial pricing for the product, if configured in App Store Connect. Returns a `Discount` proxy object with the following properties:

| Property | Type | Description |
|---|---|---|
| `price` | `Number` | Introductory price (0 for a free trial) |
| `priceLocale` | `String` | Locale identifier for the introductory price |
| `subscriptionPeriod` | `Dictionary` | `{ numberOfUnits, unit }` — duration of each introductory period |
| `numberOfPeriods` | `Number` | Number of introductory periods |
| `paymentMode` | `Number` | One of `DISCOUNT_PAYMENT_MODE_*` constants |

`paymentMode` values:

| Constant | Description |
|---|---|
| `DISCOUNT_PAYMENT_MODE_FREE_TRIAL` | No charge during the intro period |
| `DISCOUNT_PAYMENT_MODE_PAY_AS_YOU_GO` | Charged at a reduced rate per period |
| `DISCOUNT_PAYMENT_MODE_PAY_UP_FRONT` | Charged once upfront at a reduced rate |

### subscriptionPeriod [Dictionary] (read-only) *(iOS 11.2+)*

The billing period for a subscription product. Contains:

| Key | Type | Description |
|---|---|---|
| `numberOfUnits` | `Number` | Number of period units (e.g. `1`) |
| `unit` | `Number` | One of `PERIOD_UNIT_*` constants |

`unit` values:

| Constant | Value | Description |
|---|---|---|
| `PERIOD_UNIT_DAY` | `0` | Daily |
| `PERIOD_UNIT_WEEK` | `1` | Weekly |
| `PERIOD_UNIT_MONTH` | `2` | Monthly |
| `PERIOD_UNIT_YEAR` | `3` | Yearly |

## Example

```javascript
var StoreKit = require('ti.storekit');

StoreKit.requestProducts([
    'com.example.app.subscription.monthly',
    'com.example.app.premium'
], function(evt) {
    if (!evt.success) {
        console.error('Failed:', evt.message);
        return;
    }

    if (evt.invalid && evt.invalid.length > 0) {
        console.warn('Invalid IDs:', evt.invalid.join(', '));
    }

    evt.products.forEach(function(product) {
        console.log('ID:    ', product.identifier);
        console.log('Title: ', product.title);
        console.log('Price: ', product.formattedPrice);

        // Subscription period
        if (product.subscriptionPeriod) {
            var p = product.subscriptionPeriod;
            console.log('Billing: every', p.numberOfUnits, 'period(s) — unit:', p.unit);
        }

        // Introductory / trial pricing
        if (product.introductoryPrice) {
            var intro = product.introductoryPrice;
            if (intro.paymentMode === StoreKit.DISCOUNT_PAYMENT_MODE_FREE_TRIAL) {
                console.log('Free trial:', intro.subscriptionPeriod.numberOfUnits, 'day(s)');
            } else {
                console.log('Intro price:', intro.price, 'for', intro.numberOfPeriods, 'period(s)');
            }
        }
    });
});
```

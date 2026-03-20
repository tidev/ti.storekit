"""
backend.py — App Store Server API validation for Ti.Storekit

Example Flask endpoint that validates In-App Purchase subscriptions using
Apple's App Store Server API (replaces the deprecated /verifyReceipt endpoint).

The app sends the `originalTransactionId` to this server, which queries Apple
directly using the app-store-server-library. No receipt blob is required.

Why use the App Store Server API?
  - /verifyReceipt is deprecated by Apple as of March 2023
  - originalTransactionId is stable across all renewals
  - Server-side validation cannot be bypassed by jailbroken devices
  - Apple's status field is authoritative — no date math required

Requirements:
    pip install app-store-server-library PyJWT Flask

Environment variables (.env):
    APPLE_KEY_ID        → Key ID from App Store Connect In-App Purchase key
    APPLE_ISSUER_ID     → Issuer ID from App Store Connect In-App Purchase key
    APPLE_BUNDLE_ID     → Your app's bundle ID (e.g. com.example.myapp)
    APPLE_PRIVATE_KEY   → Contents of your .p8 private key file
    APPLE_ENVIRONMENT   → "sandbox" or "production" (default: production)

How to get your credentials:
    1. App Store Connect → Users and Access → Integrations → In-App Purchase
    2. Generate a new key and download the .p8 file
    3. Note the Key ID and Issuer ID shown on that page
    4. Add the .p8 contents to your .env as APPLE_PRIVATE_KEY

Security notes:
  - Never expose your .p8 key in the app binary
  - Always validate on your server, never on the device
  - Use HTTPS for all communication between app and server
  - Rate-limit this endpoint to prevent abuse

Subscription status values from Apple:
    1 = Active                  → user has access
    2 = Expired                 → no access
    3 = In billing retry period → user still has access (Apple retrying charge)
    4 = In grace period         → user still has access (short window after failure)
    5 = Revoked (refunded)      → no access
"""

import os
import datetime
import logging
from typing import Optional

import jwt
from flask import Blueprint, request, jsonify

from appstoreserverlibrary.api_client import AppStoreServerAPIClient, APIException
from appstoreserverlibrary.models.Environment import Environment

logger = logging.getLogger(__name__)

bp = Blueprint('subscription', __name__)

# ─── Configuration ────────────────────────────────────────────────────────────

APPLE_PRIVATE_KEY = os.environ.get('APPLE_PRIVATE_KEY')
APPLE_KEY_ID = os.environ.get('APPLE_KEY_ID')
APPLE_ISSUER_ID = os.environ.get('APPLE_ISSUER_ID')
APPLE_BUNDLE_ID = os.environ.get('APPLE_BUNDLE_ID')

APPLE_ENVIRONMENT = (
    Environment.SANDBOX
    if os.environ.get('APPLE_ENVIRONMENT', 'production').lower() == 'sandbox'
    else Environment.PRODUCTION
)

# ─── Apple API client ─────────────────────────────────────────────────────────

def _load_private_key() -> Optional[bytes]:
    """Load the .p8 private key from environment variable."""
    if APPLE_PRIVATE_KEY:
        return APPLE_PRIVATE_KEY.encode('utf-8')
    logger.error('APPLE_PRIVATE_KEY not set in environment')
    return None


def _build_client(environment=None) -> Optional[AppStoreServerAPIClient]:
    """
    Build the App Store Server API client.

    Accepts an optional environment override so the same function can be used
    for the sandbox fallback — useful when APPLE_ENVIRONMENT=production but the
    request comes from an Apple reviewer or tester using a Sandbox account.
    """
    missing = [k for k, v in {
        'APPLE_KEY_ID': APPLE_KEY_ID,
        'APPLE_ISSUER_ID': APPLE_ISSUER_ID,
        'APPLE_BUNDLE_ID': APPLE_BUNDLE_ID,
    }.items() if not v]

    if not APPLE_PRIVATE_KEY:
        missing.append('APPLE_PRIVATE_KEY')

    if missing:
        logger.error(f'Missing environment variables: {missing}')
        return None

    private_key = _load_private_key()
    if not private_key:
        return None

    return AppStoreServerAPIClient(
        signing_key=private_key,
        key_id=APPLE_KEY_ID,
        issuer_id=APPLE_ISSUER_ID,
        bundle_id=APPLE_BUNDLE_ID,
        environment=environment or APPLE_ENVIRONMENT,
    )

# ─── Helpers ──────────────────────────────────────────────────────────────────

def _ms_to_dt(ms) -> Optional[datetime.datetime]:
    """Convert Apple's millisecond timestamp to a timezone-aware UTC datetime."""
    if ms is None:
        return None
    try:
        return datetime.datetime.fromtimestamp(int(ms) / 1000, tz=datetime.timezone.utc)
    except (ValueError, OSError, TypeError):
        return None


def _decode_jws(token) -> Optional[object]:
    """
    Decode a JWS token from Apple without verifying the signature.

    app-store-server-library v3.x returns signed JWS strings for
    signedTransactionInfo and signedRenewalInfo. The library has already
    authenticated the outer response — we just need to read the payload.

    Returns an object with attribute access to all JWT claims (e.g. obj.productId).
    """
    if token is None:
        return None
    if not isinstance(token, str):
        return token
    try:
        payload = jwt.decode(
            token,
            options={'verify_signature': False},
            algorithms=['ES256']
        )
        return type('JWSPayload', (), payload)()
    except Exception as e:
        logger.error(f'Failed to decode JWS: {e}')
        return None

# ─── Subscription status parsing ──────────────────────────────────────────────

def _parse_subscription_status(status_response) -> Optional[dict]:
    """
    Extract the most relevant subscription from the App Store Server API response.

    Apple returns one entry per subscription group. Within each group,
    lastTransactions contains the most recent transaction per product.
    We select the best candidate: active first, then most recently expiring.

    We use Apple's status field directly rather than comparing dates because:
      - Apple marks a transaction as expired (status=2) before its expires_date
        in some edge cases (e.g. Sandbox auto-renewal timing)
      - Status 3 (billing retry) and 4 (grace period) both grant access even
        though expires_date may be in the past
    """
    if not status_response or not status_response.data:
        return None

    best = None
    best_dt = None

    for group in status_response.data:
        if not group.lastTransactions:
            continue

        for item in group.lastTransactions:
            # v3.x returns JWS strings — decode them
            tx_raw = getattr(item, 'signedTransactionInfo', None) or \
                     getattr(item, 'transactionInfo', None)
            renew_raw = getattr(item, 'signedRenewalInfo', None) or \
                        getattr(item, 'renewalInfo', None)

            tx = _decode_jws(tx_raw)
            renew = _decode_jws(renew_raw)

            if not tx:
                continue

            expires_date = _ms_to_dt(getattr(tx, 'expiresDate', None))
            purchase_date = _ms_to_dt(getattr(tx, 'purchaseDate', None))
            revocation_date = _ms_to_dt(getattr(tx, 'revocationDate', None))

            grace_period_date = None
            auto_renew = False
            is_in_billing_retry = False
            expiration_intent = None

            if renew:
                grace_period_date = _ms_to_dt(getattr(renew, 'gracePeriodExpiresDate', None))
                auto_renew = getattr(renew, 'autoRenewStatus', 0) == 1
                is_in_billing_retry = bool(getattr(renew, 'isInBillingRetryPeriod', False))
                expiration_intent = getattr(renew, 'expirationIntent', None)

            # 1=active, 3=billing retry, 4=grace period all grant access
            status = getattr(item, 'status', None)
            has_access = status in (1, 3, 4)

            # Cancelled = Apple issued a refund (revocationDate exists)
            # auto_renew=False just means the user opted out of renewal —
            # they still have access until expires_date
            is_cancelled = revocation_date is not None

            parsed = {
                'product_id': getattr(tx, 'productId', None),
                'transaction_id': getattr(tx, 'transactionId', None),
                'original_transaction_id': getattr(tx, 'originalTransactionId', None),
                'purchase_date': purchase_date.isoformat() if purchase_date else None,
                'expires_date': expires_date.isoformat() if expires_date else None,
                'revocation_date': revocation_date.isoformat() if revocation_date else None,
                'grace_period_expires_date': grace_period_date.isoformat() if grace_period_date else None,
                'is_active': has_access,
                'is_cancelled': is_cancelled,
                'will_renew': auto_renew and not is_cancelled,
                'auto_renew_enabled': auto_renew,
                'is_in_billing_retry_period': is_in_billing_retry,
                'expiration_intent': str(expiration_intent) if expiration_intent else None,
            }

            is_better = (
                best is None or
                (has_access and not best['is_active']) or
                (
                    has_access == best['is_active'] and
                    expires_date and best_dt and
                    expires_date > best_dt
                )
            )

            if is_better:
                best = parsed
                best_dt = expires_date

    return best


def _query_apple(transaction_id: str):
    """
    Query the App Store Server API with automatic Sandbox fallback.

    When APPLE_ENVIRONMENT=production and the transaction is not found (4040010),
    automatically retries against the Sandbox endpoint. This handles:
      - Apple reviewers who test using Sandbox accounts in production builds
      - Developers testing with Sandbox accounts

    Returns (status_response, environment_used) or raises an exception.
    """
    client = _build_client()
    if not client:
        raise RuntimeError('Server configuration error — check environment variables')

    try:
        logger.info(f'Querying Apple API | transactionId={transaction_id} | env={APPLE_ENVIRONMENT}')
        response = client.get_all_subscription_statuses(transaction_id)
        return response, APPLE_ENVIRONMENT

    except APIException as e:
        # Not found in production — retry against Sandbox
        if e.raw_api_error == 4040010 and APPLE_ENVIRONMENT == Environment.PRODUCTION:
            logger.info('Not found in production — retrying against Sandbox')
            sandbox_client = _build_client(Environment.SANDBOX)
            if not sandbox_client:
                raise
            response = sandbox_client.get_all_subscription_statuses(transaction_id)
            logger.info('Transaction found in Sandbox')
            return response, Environment.SANDBOX
        raise

# ─── Endpoint ─────────────────────────────────────────────────────────────────

@bp.route('/api/validate-subscription', methods=['POST'])
def validate_subscription():
    """
    Validate an In-App Purchase subscription via the App Store Server API.

    The Titanium app sends the originalTransactionId received from StoreKit.
    This is the stable identifier that persists across all renewals.

    Request (JSON):
        { "originalTransactionId": "2000001234567890" }

    Success response (200):
        {
            "success": true,
            "environment": "production",
            "subscription": {
                "product_id": "com.example.app.subscription.monthly",
                "transaction_id": "2000001234567891",
                "original_transaction_id": "2000001234567890",
                "purchase_date": "2026-03-20T10:00:00+00:00",
                "expires_date": "2026-04-20T10:00:00+00:00",
                "is_active": true,
                "is_cancelled": false,
                "will_renew": true,
                "auto_renew_enabled": true,
                "is_in_billing_retry_period": false,
                "expiration_intent": null,
                "revocation_date": null,
                "grace_period_expires_date": null
            }
        }

    Error responses:
        400 → Missing originalTransactionId
        404 → Transaction not found at Apple
        500 → Server misconfiguration or unexpected error
        502 → Apple API returned an error
    """
    if not request.is_json:
        return jsonify({'success': False, 'error': 'Content-Type must be application/json'}), 400

    try:
        data = request.get_json(force=True) or {}
    except Exception:
        return jsonify({'success': False, 'error': 'Invalid JSON'}), 400

    transaction_id = (
        data.get('originalTransactionId') or
        data.get('transactionId') or
        data.get('transaction_id')
    )

    if not transaction_id:
        return jsonify({
            'success': False,
            'error': 'originalTransactionId is required'
        }), 400

    # ── Query Apple ────────────────────────────────────────────────────────────
    try:
        status_response, env_used = _query_apple(transaction_id)

    except APIException as e:
        logger.error(
            f'Apple API error | '
            f'httpStatus={e.http_status_code} | '
            f'rawError={e.raw_api_error} | '
            f'message={e.error_message}'
        )
        if e.raw_api_error == 4040010:
            return jsonify({
                'success': False,
                'error': 'Transaction not found at Apple'
            }), 404
        return jsonify({
            'success': False,
            'error': f'Apple API error: {e.error_message}',
            'api_error': e.raw_api_error,
            'http_status': e.http_status_code,
        }), 502

    except RuntimeError as e:
        logger.error(f'Configuration error: {e}')
        return jsonify({'success': False, 'error': str(e)}), 500

    except Exception as e:
        logger.exception(f'Unexpected error: {e}')
        return jsonify({'success': False, 'error': 'Internal server error'}), 500

    # ── Parse and return ───────────────────────────────────────────────────────
    subscription_info = _parse_subscription_status(status_response)

    if not subscription_info:
        return jsonify({
            'success': False,
            'error': 'No subscription found for this transaction'
        }), 404

    env_label = 'sandbox' if env_used == Environment.SANDBOX else 'production'

    logger.info(
        f'Validated | '
        f'product={subscription_info["product_id"]} | '
        f'active={subscription_info["is_active"]} | '
        f'expires={subscription_info["expires_date"]} | '
        f'env={env_label}'
    )

    return jsonify({
        'success': True,
        'environment': env_label,
        'subscription': subscription_info,
    })

# App Integration API

Current backend base URL:

- `http://192.81.216.87`

This document is for app integration against the current IP-based deployment. When a real domain is added later, replace the base URL only.

All requests should send:

```http
Content-Type: application/json
```

## Health

### `GET /up`

Full URL:

- `http://192.81.216.87/up`

Response:

```json
{
  "status": "ok"
}
```

## Public App API

## 1. Create Checkout Session

### `POST /api/pro/checkout_sessions`

Full URL:

- `http://192.81.216.87/api/pro/checkout_sessions`

### Request body for Pro or Ultimate

```json
{
  "variant": "pro",
  "customer_email": "user@example.com",
  "success_url": "http://192.81.216.87/pro/success",
  "cancel_url": "http://192.81.216.87/pro/cancel"
}
```

### Request body for Enterprise

```json
{
  "variant": "enterprise",
  "customer_email": "buyer@company.com",
  "company_name": "Acme Inc",
  "units": 10,
  "success_url": "http://192.81.216.87/pro/success",
  "cancel_url": "http://192.81.216.87/pro/cancel"
}
```

### Notes

- `variant` must be one of:
  - `pro`
  - `ultimate`
  - `enterprise`
- `enterprise` requires `units` or `seats`

### Response `201`

```json
{
  "checkout_session_id": "uuid",
  "checkout_url": "https://checkout.creem.io/..."
}
```

## 2. Activate License

### `POST /api/pro/licenses/activate`

Full URL:

- `http://192.81.216.87/api/pro/licenses/activate`

### Request body

```json
{
  "license_key": "AAAAA-BBBBB-CCCCC-DDDDD-EEEEE",
  "instance_name": "John's MacBook Pro"
}
```

### Response `201`

```json
{
  "entitlement": {
    "license_id": "uuid",
    "customer_email": "user@example.com",
    "creem_customer_id": "cus_123",
    "license_type": "single_seat",
    "license_key_last4": "EEEE",
    "max_activations": 1,
    "current_activations": 1,
    "expires_at": "2026-12-31T00:00:00Z",
    "this_instance_active": true,
    "status": "active",
    "instances": [
      {
        "id": "uuid",
        "instance_id": "inst_123",
        "instance_name": "John's MacBook Pro",
        "status": "active",
        "activated_at": "2026-03-18T10:00:00Z",
        "deactivated_at": null,
        "active": true,
        "this_instance": true,
        "device_name": "John's MacBook Pro"
      }
    ],
    "devices": [
      {
        "id": "uuid",
        "instance_id": "inst_123",
        "instance_name": "John's MacBook Pro",
        "status": "active",
        "activated_at": "2026-03-18T10:00:00Z",
        "deactivated_at": null,
        "active": true,
        "this_instance": true,
        "device_name": "John's MacBook Pro"
      }
    ]
  }
}
```

### Notes

- Store `entitlement.instances[].instance_id` in the app for later `status` and `deactivate` calls.
- `devices` is currently an alias of `instances` for compatibility.

## 3. Get License Status

### `GET /api/pro/licenses/status`

Full URL example:

- `http://192.81.216.87/api/pro/licenses/status?license_key=AAAAA-BBBBB-CCCCC-DDDDD-EEEEE&instance_id=inst_123&refresh=true`

### Query parameters

- `license_key` required
- `instance_id` required
- `refresh` optional, defaults to `true`

### Response `200`

```json
{
  "entitlement": {
    "license_id": "uuid",
    "customer_email": "user@example.com",
    "creem_customer_id": "cus_123",
    "license_type": "multi_seat",
    "license_key_last4": "EEEE",
    "max_activations": 3,
    "current_activations": 2,
    "expires_at": "2026-12-31T00:00:00Z",
    "this_instance_active": true,
    "status": "active",
    "instances": [],
    "devices": []
  }
}
```

## 4. Deactivate License

### `POST /api/pro/licenses/deactivate`

Full URL:

- `http://192.81.216.87/api/pro/licenses/deactivate`

### Request body for current instance

```json
{
  "license_key": "AAAAA-BBBBB-CCCCC-DDDDD-EEEEE",
  "instance_id": "inst_123"
}
```

### Request body for another instance

```json
{
  "license_key": "AAAAA-BBBBB-CCCCC-DDDDD-EEEEE",
  "instance_id": "current_inst_123",
  "target_instance_id": "inst_456"
}
```

### Response `200`

```json
{
  "entitlement": {
    "license_id": "uuid",
    "customer_email": "user@example.com",
    "creem_customer_id": "cus_123",
    "license_type": "multi_seat",
    "license_key_last4": "EEEE",
    "max_activations": 3,
    "current_activations": 1,
    "expires_at": "2026-12-31T00:00:00Z",
    "this_instance_active": false,
    "status": "active",
    "instances": [],
    "devices": []
  }
}
```

## 5. Redeem Claim Token

### `POST /api/pro/claims/redeem`

Full URL:

- `http://192.81.216.87/api/pro/claims/redeem`

### Request body

```json
{
  "claim_token": "token-from-deep-link",
  "instance_name": "John's MacBook Pro"
}
```

### Response `201`

```json
{
  "entitlement": {
    "license_id": "uuid",
    "customer_email": "user@example.com",
    "creem_customer_id": "cus_123",
    "license_type": "single_seat",
    "license_key_last4": "EEEE",
    "max_activations": 1,
    "current_activations": 1,
    "expires_at": "2026-12-31T00:00:00Z",
    "this_instance_active": true,
    "status": "active",
    "instances": [],
    "devices": []
  }
}
```

## 6. Creem Webhook

### `POST /api/pro/webhooks/creem`

Full URL:

- `http://192.81.216.87/api/pro/webhooks/creem`

### Notes

- Raw JSON body from Creem
- HMAC signature header from Creem is required

### Response

```json
{
  "status": "ok"
}
```

or:

```json
{
  "status": "duplicate"
}
```

## Support API

Support endpoints require this header:

```http
X-Support-Api-Key: YOUR_SUPPORT_API_KEY
```

## 1. Get License

### `GET /api/support/licenses/:reference`

Full URL example:

- `http://192.81.216.87/api/support/licenses/ord_123`

`reference` can be:

- internal `license_id`
- Creem license id
- Creem order id
- raw license key

## 2. Get Activations

### `GET /api/support/licenses/:reference/activations`

Full URL example:

- `http://192.81.216.87/api/support/licenses/ord_123/activations`

## 3. Release Seat

### `POST /api/support/licenses/:reference/release`

Full URL example:

- `http://192.81.216.87/api/support/licenses/ord_123/release`

### Request body examples

```json
{
  "instance_id": "inst_123"
}
```

or:

```json
{
  "instance_record_id": "uuid"
}
```

## 4. Resend Claim Link

### `POST /api/support/licenses/:reference/resend_claim_link`

Full URL example:

- `http://192.81.216.87/api/support/licenses/ord_123/resend_claim_link`

## 5. Resync Purchase

### `POST /api/support/purchases/resync`

Full URL:

- `http://192.81.216.87/api/support/purchases/resync`

### Request body examples

```json
{
  "checkout_session_id": "uuid"
}
```

or:

```json
{
  "creem_checkout_id": "chk_123"
}
```

or:

```json
{
  "creem_order_id": "ord_123"
}
```

## Common Error Contract

All API errors return this shape:

```json
{
  "error": {
    "code": "missing_parameter",
    "message": "param is missing or the value is empty: license_key",
    "details": null
  }
}
```

## Common Error Codes

- `missing_parameter`
- `not_found`
- `validation_failed`
- `units_required`
- `claim_token_expired`
- `claim_not_ready`
- `claim_license_key_missing`
- `activation_capacity_reached`
- `instance_not_found`
- `license_revoked`
- `license_refunded`

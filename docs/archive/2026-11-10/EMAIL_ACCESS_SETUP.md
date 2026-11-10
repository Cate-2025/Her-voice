> Archived snapshot, preserved 10 November 2026. Historical instructions and results may be superseded. Use the [current review documents](../../README.md).

# Verified-email access

Registration accepts all email domains, as requested. Successful code verification creates a **student** account. It does not verify university membership or grant staff access. Existing seeded accounts remain valid. Password recovery uses a separate code purpose, sets a new password, revokes existing JWT sessions and disables that account's registered push devices.

Codes are eight digits, expire after 15 minutes, allow at most five incorrect attempts and are consumed on success. Resending requires a minute's wait. Source-address rate limits also apply. Code hashes, not plaintext codes, are kept in PostgreSQL. Email delivery is disabled by default; never expose verification codes through a public API or logs.

## Fictional prototype testing without a mail provider

From `backend`, before launching the prototype:

```bash
export EMAIL_DELIVERY=file
.venv/bin/python -m scripts.run_prototype
```

In Flutter choose **Create an account**, enter a fictional email and request a code. Open the newest `.eml` file in `backend/.prototype/mail/` using your file manager/text viewer, then enter its code and a new password of 12–128 characters. Sign in normally. **Forgot password?** uses the same two-step flow with a reset code.

This is a development mailbox on the server, not real email delivery or proof of access to a real mailbox. File mode is permitted only in `APP_ENV=development`. The `.prototype` directory is ignored by Git; mailbox files are created owner-readable/writable only. Remove expired fictional mail as part of local housekeeping; automatic mailbox retention is not implemented.

## Actual email delivery

Configure the server environment or ignored backend `.env` with your SMTP provider's values:

```dotenv
EMAIL_DELIVERY=smtp
SMTP_HOST=your-smtp-host
SMTP_PORT=587
SMTP_SECURITY=starttls
SMTP_FROM=your-verified-sender@example.org
SMTP_USER=your-smtp-user
SMTP_PASSWORD=your-provider-secret
```

Use `SMTP_SECURITY=ssl` with the provider's implicit-TLS port when appropriate. Plaintext SMTP is not offered. Restart the backend after changing configuration. Configure/verify the sender with your chosen provider and test both inbox and spam-folder delivery. Do not paste SMTP credentials into chat or commit `.env`.

An email domain allowlist has deliberately not been added. Institution eligibility remains a future policy/integration decision. Staff accounts must still be provisioned by an authorised operator; public registration cannot choose a role.

## Operations and limits

The server sends mail synchronously with a timeout. Delivery failure returns an actionable unavailable response and does not activate an account. SMTP acceptance is not proof of inbox delivery. Production mail queuing/retries, bounce handling, deliverability monitoring, durable challenge/throttle cleanup and institutional account management remain to be completed.

Rate limits currently use the connection source address and per-email resend interval. A reverse proxy must have a correctly restricted trusted-proxy configuration; an arbitrary forwarded header must never bypass limits. Shared-network users may share a source limit. This is a prototype control, not a replacement for production abuse protection.

Passwords and sign-in tokens are not stored for offline login. A password reset does not delete a user's encrypted local drafts; the same verified account ID can recover them after successful sign-in on the original device.

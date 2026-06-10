-- Email column on users, used to deliver OTP codes by SMTP until a real SMS
-- provider is wired. Nullable so existing dev rows don't break; new
-- registrations through the prod profile populate it.

ALTER TABLE users ADD COLUMN email VARCHAR(255);

CREATE UNIQUE INDEX uq_users_email_lower ON users (lower(email)) WHERE email IS NOT NULL;

-- Email captured at OTP request time, used to deliver the code and to
-- populate users.email when the verify step creates the user.
ALTER TABLE otp_codes ADD COLUMN email VARCHAR(255);

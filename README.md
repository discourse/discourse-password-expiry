# discourse-password-expiry

A plugin which forces users to reset their password on a regular basis. This is NOT RECOMMENDED for most Discourse installations.

From [NIST Special Publication 800-63B](https://pages.nist.gov/800-63-3/sp800-63b.html):

> Verifiers SHOULD NOT require memorized secrets to be changed arbitrarily (e.g., periodically).

If you still need to implement password expiry for some reason, this plugin will help. When enabled, user passwords will stop working after a configurable number of days. Users can reset their password using the normal method.

A banner can be shown on the homepage for a configurable number of days before password expiry.

Personal messages can be sent to the user at defined days before password expiry.

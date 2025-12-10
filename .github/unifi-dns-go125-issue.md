# unifi-dns Go 1.25 TLS Issue

## **🎯 FOUND IT!**

**Go 1.25 FAILS with "context deadline exceeded"** - exactly like the webhook!

## Final Test Results:

| Version | Result |
|---------|--------|
| **Go 1.23.12** | ✅ **200 OK** |
| **Go 1.25.5** | ❌ **Timeout** |
| curl OpenSSL 3.1.4 | ✅ 200 OK |
| curl OpenSSL 3.5.4 | ❌ TLS EOF |

## Root Cause:

**Go 1.25 introduced a TLS incompatibility** with your UDM Pro's configuration. This is why:
- Webhook v0.7.0 (Go 1.25) fails
- Your manual curl works (uses OpenSSL, not Go)
- Kashall might not see this if he's on an older version or different UDM Pro firmware

## Solution:

**Downgrade to v0.6.0** which likely uses Go 1.23 or earlier. Want me to help you update the HelmRelease to test v0.6.0?

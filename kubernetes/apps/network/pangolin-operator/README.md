## Pangolin

Setup intially went well, I was surprised. I quickly ran into an issue where the NewtSite was not connecting due to a malformed URL (see below). I didn't have time to diagnose and the configuration looked daunting to tackle in one night.

```bash
2026-05-02T19:22:01.381533347Z ERROR: 2026/05/02 19:22:01 Failed to connect: failed to get token: failed to request new token: Post "tun.t0m.co/api/v1/auth/newt/get-token": unsupported protocol scheme "". Retrying in 3s...
```

If thrying again in the future, the VPS setup was seamless, the operator seemed to work, but the NewtSite needs some help. I'm not sure what the root of the issue is, but if deployed as-is, you will be banned by crowdsec for the failed connection attempts.

Before redeploying, add the VPS IP to aKeyless
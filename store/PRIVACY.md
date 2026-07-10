# Privacy Policy — GoodbyeDPI for Chrome

_Last updated: 2026-07-10_

**GoodbyeDPI for Chrome does not collect, store, transmit, or sell any personal data.**

## What the extension does
- When enabled, it configures Chrome to send this browser's network traffic through a
  local proxy running on your own computer (`127.0.0.1`), provided by the companion
  application (ByeDPI / ciadpi).
- It stores a small amount of configuration **locally on your device** using Chrome's
  `storage` API: the on/off state, the proxy port, and the bypass-strategy string.
  This never leaves your computer.

## Data collection
- **None.** The developer receives no data of any kind.
- No analytics, no tracking, no advertising, no remote servers operated by the developer.
- Your browsing traffic goes directly from your computer to the websites you visit. It is
  processed only by the local proxy on your own machine; it is not routed to the developer
  or any third party operated by the developer.

## Permissions
- `proxy` — set/clear the local proxy while toggling the feature.
- `storage` — remember your settings locally.
- `nativeMessaging` — start/stop the local proxy via the companion app on your device.

## Third-party component
- The companion app bundles **ByeDPI (ciadpi)**, MIT-licensed, https://github.com/hufrea/byedpi.
  It runs entirely on your device and communicates with no developer-operated server.

## Contact
Questions: <YOUR_EMAIL_OR_GITHUB_URL>

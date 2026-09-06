# Fluxday v0.1.0 Tauri reference

This directory preserves the source of the last Tauri/React/Rust implementation after Fluxday moved to a native SwiftUI production application in v0.2.0.

The immutable [`v0.1.0`](https://github.com/maskoff7/fluxday/releases/tag/v0.1.0) tag and its Git history are the canonical released source. This snapshot remains available for migration compatibility work and historical comparison; it is not part of the production build or CI.

To build the released implementation exactly as shipped, check out the tag instead of this archive:

```sh
git checkout v0.1.0
npm ci
npm test
npm run tauri build -- --bundles app
```

# Development guide

Fluxday keeps `main` releasable. Work in a focused branch, use Conventional Commits, open a pull request linked to an issue and include screenshots for interface changes.

Before requesting review, run:

```bash
npm ci
npm run format:check
npm run lint
npm run typecheck
npm test
cargo test --manifest-path src-tauri/Cargo.toml
npm run build
```

For a macOS change, also build the unsigned local application:

```bash
npm run tauri build -- --bundles app
```

Financial behavior belongs in `src/domain/` and requires regression tests. Treat imports as untrusted input, keep money in integer minor units and keep calendar dates free of timezone conversions. Do not add telemetry, network calls or user financial data to the repository.

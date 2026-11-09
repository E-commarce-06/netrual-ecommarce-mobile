# BNEO Storefront Mobile — Flutter source

This repository contains the Flutter source for a per-store BNEO storefront app. It is based on the permitted Cartxis mobile source and is being adapted for BNEO; it is **not** a prebuilt APK or a production release.

## Configuration model

- **Build-time deployment profile:** selects the trusted API origin and environment. Public web-admin settings cannot change the API host, native application IDs, signing identity, callback scheme, or Firebase project.
- **Runtime mobile settings:** the app fetches a versioned public projection from `GET /api/v1/app/settings`, validates it, caches the last-known-good values, and applies safe store name/logo/support/policy content. Policy rich text is reduced to inert plain text; it is never rendered in a WebView.
- **Offline behavior:** cached settings or the build-profile fallback are used if the public endpoint cannot be reached.

The supplied integration target is recorded in `deployment/bneo.integration.json`. Its production/staging role has not been confirmed. See [`deployment/README.md`](deployment/README.md) before running or preparing any build.

## Run locally

Install a compatible Flutter SDK, then run from the repository root:

```sh
flutter pub get
flutter run --dart-define-from-file=deployment/bneo.integration.json
```

Do not use live account, checkout, or payment flows against the supplied host without explicit authorization and verified test credentials.

## Validation

```sh
dart format --output=none --set-exit-if-changed lib test
flutter analyze
flutter test
```

Flutter/Dart tooling was unavailable in the current implementation workspace, so these checks still need to be run in CI or a Flutter-enabled environment. PHP/Composer tooling is also required to run the paired BNEO backend feature test.

## Release status

No production profile, approved native application IDs, store-owned signing key, approved launcher/splash assets, or owner-approved iOS callback/Firebase configuration has been supplied. Android release packaging has fail-closed checks for signing material, the production API profile, application ID, and approved brand assets. Do not treat a successful debug build as release approval.

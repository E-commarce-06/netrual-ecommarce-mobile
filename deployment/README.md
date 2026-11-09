# Deployment profiles

The checked-in JSON files contain **public build configuration only**. Never add signing material, API credentials, payment secrets, user data, or Firebase private credentials to them.

## Current BNEO profile

`bneo.integration.json` is configured with the supplied HTTPS host as an integration target. The host responded to a read-only public app-settings request, but its staging/production role has **not been verified**. Do not use it for live checkout/payment testing or label it as production without confirmation.

For local development, Android and iOS use `com.arkeonethiopia.commarce` as the BNEO application/bundle identifier. This identifier has not been checked or registered in either store account; it is a development identity, not evidence of store availability or release approval. No Play Console or App Store account is needed to use an emulator or simulator.

Run the Flutter source against this profile:

```sh
flutter run --dart-define-from-file=deployment/bneo.integration.json
```

The app's trusted API origin is fixed by that build configuration. Runtime mobile settings must never override it.

## Release prerequisites

No production profile is checked in. Before making a release build, the store owner must confirm and supply all of the following through an approved release pipeline:

- A verified production HTTPS API origin and environment designation.
- The approved Android application ID and iOS bundle ID.
- Store-owned Firebase/Crashlytics configuration, or an explicit decision to keep telemetry disabled. The upstream Firebase project files and automatic Crashlytics startup/symbol-upload hooks have been removed; Firebase packages remain in `pubspec.yaml` pending a Flutter dependency-resolution pass.
- Approved Android/iOS launcher and splash assets, URL schemes, legal content, and supported payment methods. Android release packaging additionally requires `STORE_BRAND_ASSETS_APPROVED=true` after those assets have actually been replaced and reviewed.
- A newly created, owner-controlled Android signing key; credentials must come from protected CI secrets and the keystore file must remain outside the repository.

The Android Gradle release packaging tasks fail unless signing secrets, a production Dart-define profile, and an explicit `ANDROID_APPLICATION_ID` are supplied. The local default `com.arkeonethiopia.commarce` is not implicitly accepted for release; confirm its availability/registration in Play Console before setting it in the protected release job. iOS now uses the same identifier for local development and has no upstream signing-team value; App Store registration and distribution signing still require the appropriate Apple account and provisioning setup.

Example environment setup for a protected release job (values must be provided by the owner; none are stored here):

```sh
export APP_DISPLAY_NAME='BNEO'
export ANDROID_APPLICATION_ID='<owner-approved-application-id>'
export ANDROID_KEYSTORE_PATH='<protected-path-outside-the-repository>'
export ANDROID_KEY_ALIAS='<secret-store-value>'
export ANDROID_KEY_PASSWORD='<secret-store-value>'
export ANDROID_STORE_PASSWORD='<secret-store-value>'
export STORE_BRAND_ASSETS_APPROVED='true' # only after replacing and reviewing upstream assets

flutter build appbundle --release \
  --dart-define-from-file=deployment/bneo.production.json
```

The referenced `bneo.production.json` does not exist yet. Create it only after the production host is confirmed, and include only `APP_NAME`, `APP_ENV=production`, `API_BASE_URL`, and `API_VERSION`; never include secrets. iOS identity/signing is not configured by the Android release guard and requires a separate owner-approved Xcode/CI configuration.

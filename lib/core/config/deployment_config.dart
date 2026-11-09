/// Values that identify one native app build and its trusted backend.
///
/// Public configuration is supplied by a deployment file, for example:
/// `flutter run --dart-define-from-file=deployment/bneo.staging.json`.
/// Never place signing keys, API credentials, or payment secrets in that file.
class DeploymentConfig {
  DeploymentConfig._();

  static const String appName =
      String.fromEnvironment('APP_NAME', defaultValue: 'Storefront');
  static const String environment =
      String.fromEnvironment('APP_ENV', defaultValue: 'development');
  static const String apiBaseUrl = String.fromEnvironment('API_BASE_URL');
  static const String apiVersion =
      String.fromEnvironment('API_VERSION', defaultValue: 'v1');

  static const bool isReleaseBuild = bool.fromEnvironment('dart.vm.product');

  /// Validates the selected profile before any network request can be made.
  static Uri validate() => apiOrigin;

  /// Returns a validated HTTPS origin. A public runtime setting is deliberately
  /// not allowed to change this URL after the app is built.
  static Uri get apiOrigin {
    final raw = apiBaseUrl.trim();
    if (raw.isEmpty) {
      throw StateError(
        'API_BASE_URL is required. Build with the deployment profile for this store.',
      );
    }

    final uri = Uri.tryParse(raw);
    if (uri == null || !uri.isAbsolute || uri.host.isEmpty) {
      throw FormatException('API_BASE_URL must be an absolute URL with a host.');
    }
    if (uri.userInfo.isNotEmpty || uri.hasQuery || uri.hasFragment) {
      throw FormatException(
        'API_BASE_URL must not contain credentials, a query, or a fragment.',
      );
    }
    if (uri.path.isNotEmpty && uri.path != '/') {
      throw FormatException(
        'API_BASE_URL must be an origin only; API paths are added by the client.',
      );
    }
    if (uri.scheme != 'https' && isReleaseBuild) {
      throw FormatException('Release API_BASE_URL must use HTTPS.');
    }
    if (environment == 'production' && uri.scheme != 'https') {
      throw FormatException('Production API_BASE_URL must use HTTPS.');
    }
    if (isReleaseBuild && environment != 'production') {
      throw StateError(
        'Release builds require APP_ENV=production; do not ship a staging profile.',
      );
    }

    return uri.replace(path: '', query: null, fragment: null);
  }
}

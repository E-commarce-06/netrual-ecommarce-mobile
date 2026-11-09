import 'deployment_config.dart';

/// API paths and transport settings for the selected deployment profile.
class ApiConfig {
  ApiConfig._();

  static const bool isProduction = DeploymentConfig.isReleaseBuild;
  static const String apiVersion = DeploymentConfig.apiVersion;

  // Authentication Endpoints
  static const String authLogin = '/api/$apiVersion/auth/login';
  static const String authRegister = '/api/$apiVersion/auth/register';
  static const String authLogout = '/api/$apiVersion/auth/logout';
  static const String authMe = '/api/$apiVersion/auth/me';
  static const String authForgotPassword =
      '/api/$apiVersion/auth/password/forgot';
  static const String authResetPassword =
      '/api/$apiVersion/auth/password/reset';
  static const String authVerifyEmail = '/api/$apiVersion/auth/verify-email';
  static const String authDeleteAccount = '/api/$apiVersion/auth/account';

  // Customer Endpoints
  static const String customerProfile = '/api/$apiVersion/customer/profile';
  static const String customerOrders = '/api/$apiVersion/customer/orders';
  static String customerOrderDetail(int orderId) =>
      '/api/$apiVersion/customer/orders/$orderId';
  static const String wishlist = '/api/$apiVersion/customer/wishlist';
  static const String wishlistAdd = '/api/$apiVersion/customer/wishlist/add';

  // Currency Endpoints
  static const String currencyDefault = '/api/$apiVersion/currency/default';

  // System Sync Endpoints
  static const String apiSyncHeartbeat =
      '/api/$apiVersion/system/api-sync/heartbeat';
  static const String apiSyncStatus = '/api/$apiVersion/system/api-sync/status';

  // Product Endpoints
  static const String products = '/api/$apiVersion/products';
  static const String productsFeatured = '/api/$apiVersion/products/featured';
  static const String productsNewArrivals =
      '/api/$apiVersion/products/new-arrivals';
  static const String productsOnSale = '/api/$apiVersion/products/on-sale';

  // Category Endpoints
  static const String categories = '/api/$apiVersion/categories';

  // Banner Endpoints
  static const String banners = '/api/$apiVersion/banners';

  // Public store configuration; never changes the trusted API origin.
  static const String appSettings = '/api/$apiVersion/app/settings';

  static const Duration connectionTimeout = Duration(seconds: 30);
  static const Duration receiveTimeout = Duration(seconds: 30);
  static const String deviceName = 'Flutter App';

  static String get baseUrl => DeploymentConfig.apiOrigin.toString();

  /// Builds a URL only from a relative API path; absolute/external endpoints
  /// are rejected so services cannot accidentally bypass the configured host.
  static String getFullUrl(String endpoint) {
    final parsed = Uri.tryParse(endpoint);
    if (endpoint.isEmpty ||
        !endpoint.startsWith('/') ||
        endpoint.startsWith('//') ||
        parsed == null ||
        parsed.hasScheme ||
        parsed.hasAuthority ||
        parsed.hasFragment) {
      throw ArgumentError.value(endpoint, 'endpoint', 'Expected a relative API path.');
    }

    return DeploymentConfig.apiOrigin.resolve(endpoint).toString();
  }
}

import '../../core/config/deployment_config.dart';

/// Safe, public, store-managed presentation settings returned by the backend.
/// Native identity and the trusted API origin are intentionally not part of it.
class MobileAppSettings {
  const MobileAppSettings({
    required this.schemaVersion,
    required this.revision,
    required this.appName,
    this.tagline = '',
    this.description = '',
    this.logoUrl,
    this.authLogoUrl,
    this.supportEmail = '',
    this.supportPhone = '',
    this.supportWhatsApp = '',
    this.country = '',
    this.timezone = 'UTC',
    this.privacyPolicy = '',
    this.termsPolicy = '',
    this.returnPolicy = '',
    this.shippingPolicy = '',
  });

  final int schemaVersion;
  final String revision;
  final String appName;
  final String tagline;
  final String description;
  final String? logoUrl;
  final String? authLogoUrl;
  final String supportEmail;
  final String supportPhone;
  final String supportWhatsApp;
  final String country;
  final String timezone;
  final String privacyPolicy;
  final String termsPolicy;
  final String returnPolicy;
  final String shippingPolicy;

  static MobileAppSettings get defaults => MobileAppSettings(
        schemaVersion: 1,
        revision: 'bundled',
        appName: DeploymentConfig.appName,
      );

  factory MobileAppSettings.fromJson(Map<String, dynamic> json) =>
      MobileAppSettings.fromApiData({'mobile_config': json});

  factory MobileAppSettings.fromApiData(Map<String, dynamic> data) {
    final config = _map(data['mobile_config']);
    final brand = _map(config['brand']);
    final support = _map(config['support']);
    final store = _map(config['store']);
    final policies = _map(config['policies']);

    // Flat fields are retained by the v1 API for older clients. Accept them as
    // fallbacks while the web and mobile deployments roll forward separately.
    final appName = _text(brand['name'], maxLength: 120).isNotEmpty
        ? _text(brand['name'], maxLength: 120)
        : _text(data['site_name'], maxLength: 120, fallback: DeploymentConfig.appName);
    final siteLogo = _httpsUrl(brand['logo_url']) ?? _httpsUrl(data['site_logo']);
    final authLogo = _httpsUrl(brand['auth_logo_url']) ??
        _httpsUrl(data['mobile_auth_logo']) ??
        siteLogo;

    return MobileAppSettings(
      schemaVersion: _integer(config['schema_version'], fallback: 1),
      revision: _text(config['revision'], maxLength: 128, fallback: 'legacy'),
      appName: appName,
      tagline: _text(brand['tagline'] ?? data['site_tagline'], maxLength: 255),
      description: _text(brand['description'], maxLength: 20000),
      logoUrl: siteLogo,
      authLogoUrl: authLogo,
      supportEmail: _text(support['email'], maxLength: 255),
      supportPhone: _text(
        support['phone'] ?? data['contact_phone'],
        maxLength: 80,
      ),
      supportWhatsApp: _text(support['whatsapp'], maxLength: 80),
      country: _text(store['country'] ?? data['store_country'], maxLength: 100),
      timezone: _text(store['timezone'], maxLength: 80, fallback: 'UTC'),
      privacyPolicy: _plainText(policies['privacy'], maxLength: 100000),
      termsPolicy: _plainText(policies['terms'], maxLength: 100000),
      returnPolicy: _plainText(policies['returns'], maxLength: 100000),
      shippingPolicy: _plainText(policies['shipping'], maxLength: 100000),
    );
  }

  Map<String, dynamic> toJson() => {
        'schema_version': schemaVersion,
        'revision': revision,
        'brand': {
          'name': appName,
          'tagline': tagline,
          'description': description,
          'logo_url': logoUrl,
          'auth_logo_url': authLogoUrl,
        },
        'support': {
          'email': supportEmail,
          'phone': supportPhone,
          'whatsapp': supportWhatsApp,
        },
        'store': {'country': country, 'timezone': timezone},
        'policies': {
          'privacy': privacyPolicy,
          'terms': termsPolicy,
          'returns': returnPolicy,
          'shipping': shippingPolicy,
        },
      };

  static Map<String, dynamic> _map(dynamic value) =>
      value is Map<String, dynamic> ? value : const <String, dynamic>{};

  static int _integer(dynamic value, {required int fallback}) =>
      value is int ? value : int.tryParse(value?.toString() ?? '') ?? fallback;

  static String _text(
    dynamic value, {
    int maxLength = 2000,
    String fallback = '',
  }) {
    if (value is! String) return fallback;
    final cleaned = value.trim();
    return cleaned.length <= maxLength ? cleaned : fallback;
  }

  /// Converts the admin rich-text policy HTML to inert display text. Never
  /// render policy content as HTML or pass it to a WebView.
  static String _plainText(dynamic value, {required int maxLength}) {
    final source = _text(value, maxLength: maxLength);
    if (source.isEmpty) return '';

    final newline = String.fromCharCode(10);
    final withoutExecutableBlocks = source.replaceAll(
      RegExp('<(script|style)[^>]*>.*</(script|style)>',
          caseSensitive: false, dotAll: true),
      '',
    );
    final withParagraphBreaks = withoutExecutableBlocks
        .replaceAll(RegExp('<br[^>]*>', caseSensitive: false), newline)
        .replaceAll(
          RegExp('</(p|div|h[1-6]|li|blockquote|ul|ol)[^>]*>',
              caseSensitive: false),
          newline,
        );
    final withoutTags = withParagraphBreaks.replaceAll(RegExp('<[^>]*>'), '');
    return withoutTags
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'")
        .replaceAll('&apos;', "'")
        .trim();
  }

  static String? _httpsUrl(dynamic value) {
    if (value is! String || value.trim().isEmpty) return null;
    final uri = Uri.tryParse(value.trim());
    if (uri == null || uri.scheme != 'https' || uri.host.isEmpty || uri.userInfo.isNotEmpty) {
      return null;
    }
    return uri.toString();
  }
}

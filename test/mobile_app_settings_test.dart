import 'package:cartxis_app/core/config/api_config.dart';
import 'package:cartxis_app/data/models/mobile_app_settings.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('MobileAppSettings', () {
    test('parses the public mobile configuration projection', () {
      final settings = MobileAppSettings.fromApiData({
        'mobile_config': {
          'schema_version': 1,
          'revision': 'rev-123',
          'brand': {
            'name': 'BNEO',
            'tagline': 'Shop locally',
            'description': 'A store description.',
            'logo_url': 'https://cdn.example.test/logo.png',
            'auth_logo_url': 'https://cdn.example.test/auth.png',
            'colors': {'primary': '#1A2B3C', 'accent': '#095AB1'},
          },
          'support': {
            'email': 'help@example.test',
            'phone': '+251 900 000 000',
            'whatsapp': '+251 900 000 000',
          },
          'store': {'country': 'Ethiopia', 'timezone': 'Africa/Addis_Ababa'},
          'policies': {
            'privacy': '<p>Privacy <strong>copy</strong></p><script>alert(1)</script>',
            'terms': 'Terms copy',
            'returns': 'Returns copy',
            'shipping': 'Shipping copy',
          },
        },
      });

      expect(settings.appName, 'BNEO');
      expect(settings.revision, 'rev-123');
      expect(settings.authLogoUrl, 'https://cdn.example.test/auth.png');
      expect(settings.primaryColor, '#1A2B3C');
      expect(settings.accentColor, '#095AB1');
      expect(settings.supportEmail, 'help@example.test');
      expect(settings.country, 'Ethiopia');
      expect(settings.privacyPolicy, 'Privacy copy');
      expect(settings.termsPolicy, 'Terms copy');
      expect(settings.returnPolicy, 'Returns copy');
      expect(settings.shippingPolicy, 'Shipping copy');
    });

    test('falls back to legacy flat fields and rejects insecure logo URLs', () {
      final settings = MobileAppSettings.fromApiData({
        'site_name': 'Legacy store',
        'site_logo': 'http://cdn.example.test/logo.png',
        'mobile_auth_logo': 'https://cdn.example.test/auth.png',
        'contact_phone': '555-0100',
      });

      expect(settings.appName, 'Legacy store');
      expect(settings.logoUrl, isNull);
      expect(settings.authLogoUrl, 'https://cdn.example.test/auth.png');
      expect(settings.supportPhone, '555-0100');
    });

    test('uses bundled color defaults for malformed or low-contrast public brand colors', () {
      final settings = MobileAppSettings.fromApiData({
        'mobile_config': {
          'brand': {
            'colors': {'primary': 'red', 'accent': '#AABBCC'},
          },
        },
      });

      expect(settings.primaryColor, '#1268C4');
      expect(settings.accentColor, '#0C62B8');
    });

    test('cached JSON round-trips the typed settings shape', () {
      final original = MobileAppSettings.fromApiData({
        'mobile_config': {
          'schema_version': 1,
          'revision': 'cached-rev',
          'brand': {'name': 'Cached store'},
          'support': {'email': 'support@example.test'},
          'policies': {'privacy': 'Cached policy'},
        },
      });

      final restored = MobileAppSettings.fromJson(original.toJson());
      expect(restored.appName, original.appName);
      expect(restored.revision, original.revision);
      expect(restored.supportEmail, original.supportEmail);
      expect(restored.privacyPolicy, original.privacyPolicy);
    });
  });

  group('API origin boundary', () {
    test('rejects absolute and authority-relative endpoint inputs', () {
      expect(() => ApiConfig.getFullUrl('https://attacker.test/api'), throwsArgumentError);
      expect(() => ApiConfig.getFullUrl('//attacker.test/api'), throwsArgumentError);
      expect(() => ApiConfig.getFullUrl('api/v1/products'), throwsArgumentError);
    });
  });
}

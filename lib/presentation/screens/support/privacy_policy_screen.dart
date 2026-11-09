import 'package:flutter/material.dart';

import '../../../core/config/mobile_app_settings_controller.dart';
import 'store_policy_page.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = MobileAppSettingsScope.of(context).settings;
    return StorePolicyPage(
      title: 'Privacy Policy',
      content: settings.privacyPolicy,
      settings: settings,
    );
  }
}

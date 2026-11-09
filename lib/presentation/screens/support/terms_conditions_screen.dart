import 'package:flutter/material.dart';

import '../../../core/config/mobile_app_settings_controller.dart';
import 'store_policy_page.dart';

class TermsConditionsScreen extends StatelessWidget {
  const TermsConditionsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = MobileAppSettingsScope.of(context).settings;
    return StorePolicyPage(
      title: 'Terms and Conditions',
      content: settings.termsPolicy,
      settings: settings,
    );
  }
}

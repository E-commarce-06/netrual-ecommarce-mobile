import 'package:flutter/material.dart';

import '../../../data/models/mobile_app_settings.dart';

/// Renders plain-text policy content supplied by the store's web admin.
/// Content is deliberately not interpreted as HTML or executable markup.
class StorePolicyPage extends StatelessWidget {
  const StorePolicyPage({
    super.key,
    required this.title,
    required this.content,
    required this.settings,
  });

  final String title;
  final String content;
  final MobileAppSettings settings;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final policyText = content.trim().isNotEmpty
        ? content.trim()
        : _notConfiguredMessage();

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF101922) : const Color(0xFFF6F7F8),
      body: SafeArea(
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: (isDark ? const Color(0xFF101922) : const Color(0xFFF6F7F8))
                    .withOpacity(0.95),
                border: Border(
                  bottom: BorderSide(
                    color: isDark ? const Color(0xFF1F2937) : const Color(0xFFE5E7EB),
                  ),
                ),
              ),
              child: Row(
                children: [
                  SizedBox(
                    width: 50,
                    child: IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: Icon(
                        Icons.arrow_back_ios_new,
                        color: isDark ? Colors.white : const Color(0xFF1F2937),
                      ),
                      padding: EdgeInsets.zero,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      title,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 50),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: SelectableText(
                  policyText,
                  style: TextStyle(
                    fontSize: 15,
                    height: 1.65,
                    color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _notConfiguredMessage() {
    final contact = <String>[
      if (settings.supportEmail.isNotEmpty) settings.supportEmail,
      if (settings.supportPhone.isNotEmpty) settings.supportPhone,
    ];
    final contactText = contact.isEmpty
        ? 'Please contact the store through its official website.'
        : 'Please contact store support at ${contact.join(' or ')}.';
    return '$title has not been configured by ${settings.appName}. $contactText';
  }
}

import 'package:flutter/material.dart';

import '../../../core/config/mobile_app_settings_controller.dart';
import '../../../core/constants/app_colors.dart';

class HelpSupportScreen extends StatelessWidget {
  const HelpSupportScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = MobileAppSettingsScope.of(context).settings;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final hasContact = settings.supportEmail.isNotEmpty ||
        settings.supportPhone.isNotEmpty ||
        settings.supportWhatsApp.isNotEmpty;

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
                  const Expanded(
                    child: Text(
                      'Help & Support',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(width: 50),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Contact ${settings.appName}',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : const Color(0xFF0D141B),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      hasContact
                          ? 'Use the contact details below to reach the store support team.'
                          : 'Store support contact details have not been configured. Please use the store website for assistance.',
                      style: TextStyle(
                        fontSize: 15,
                        height: 1.5,
                        color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
                      ),
                    ),
                    const SizedBox(height: 24),
                    if (settings.supportEmail.isNotEmpty)
                      _buildContactCard(
                        icon: Icons.email_outlined,
                        title: 'Email',
                        content: settings.supportEmail,
                        isDark: isDark,
                      ),
                    if (settings.supportPhone.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      _buildContactCard(
                        icon: Icons.phone_outlined,
                        title: 'Phone',
                        content: settings.supportPhone,
                        isDark: isDark,
                      ),
                    ],
                    if (settings.supportWhatsApp.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      _buildContactCard(
                        icon: Icons.chat_outlined,
                        title: 'WhatsApp',
                        content: settings.supportWhatsApp,
                        isDark: isDark,
                      ),
                    ],
                    if (settings.returnPolicy.isNotEmpty ||
                        settings.shippingPolicy.isNotEmpty) ...[
                      const SizedBox(height: 28),
                      Text(
                        'Store policies',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : const Color(0xFF0D141B),
                        ),
                      ),
                      if (settings.returnPolicy.isNotEmpty)
                        _buildPolicyTile('Returns', settings.returnPolicy, isDark),
                      if (settings.shippingPolicy.isNotEmpty)
                        _buildPolicyTile('Shipping', settings.shippingPolicy, isDark),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPolicyTile(String title, String content, bool isDark) {
    return Card(
      color: isDark ? const Color(0xFF1F2937) : Colors.white,
      margin: const EdgeInsets.only(top: 10),
      child: ExpansionTile(
        title: Text(title),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        children: [
          SelectableText(
            content,
            style: TextStyle(
              height: 1.55,
              color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContactCard({
    required IconData icon,
    required String title,
    required String content,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1F2937) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? const Color(0xFF374151) : const Color(0xFFE5E7EB),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: AppColors.primary, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
                  ),
                ),
                const SizedBox(height: 4),
                SelectableText(
                  content,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : const Color(0xFF0D141B),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

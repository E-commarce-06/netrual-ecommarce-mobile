import 'package:flutter/material.dart';

import 'package:cartxis_app/core/config/deployment_config.dart';
import 'package:cartxis_app/core/constants/app_colors.dart';
import 'package:cartxis_app/core/constants/app_sizes.dart';

/// Shows a validated HTTPS store logo or a neutral branded fallback.
class AuthLogo extends StatelessWidget {
  const AuthLogo({
    super.key,
    this.networkUrl,
    this.fallbackLabel = DeploymentConfig.appName,
    this.width = 200,
    this.height = 80,
  });

  final String? networkUrl;
  final String fallbackLabel;
  final double width;
  final double height;

  Widget _fallback(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.storefront_outlined,
          size: height * 0.42,
          color: AppColors.primary,
        ),
        const SizedBox(width: 10),
        Flexible(
          child: Text(
            fallbackLabel,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: (height * 0.26).clamp(16, 24).toDouble(),
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.white : const Color(0xFF17212B),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final isDark = brightness == Brightness.dark;
    final validNetworkLogo = networkUrl != null && networkUrl!.isNotEmpty;
    final fallback = _fallback(brightness);

    return SizedBox(
      width: width,
      height: height,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppSizes.radiusLarge),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: isDark && validNetworkLogo
                ? AppColors.surfaceLight.withOpacity(0.92)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(AppSizes.radiusLarge),
          ),
          child: Padding(
            padding: isDark && validNetworkLogo
                ? const EdgeInsets.all(AppSizes.sm)
                : EdgeInsets.zero,
            child: validNetworkLogo
                ? Image.network(
                    networkUrl!,
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => fallback,
                  )
                : fallback,
          ),
        ),
      ),
    );
  }
}

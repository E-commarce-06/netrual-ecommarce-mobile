import 'dart:convert';

import 'package:flutter/material.dart';

import '../../data/models/mobile_app_settings.dart';
import '../../data/services/app_settings_service.dart';

/// App-scoped state for remotely managed, non-sensitive store presentation data.
class MobileAppSettingsController extends ChangeNotifier {
  MobileAppSettingsController({AppSettingsService? service})
      : _service = service ?? AppSettingsService();

  final AppSettingsService _service;
  MobileAppSettings _settings = MobileAppSettings.defaults;
  bool _disposed = false;
  bool _loading = false;

  MobileAppSettings get settings => _settings;

  bool _hasChanged(MobileAppSettings candidate) =>
      jsonEncode(candidate.toJson()) != jsonEncode(_settings.toJson());

  /// Shows the last-known-good config immediately, then refreshes it.
  Future<void> load() async {
    if (_loading || _disposed) return;
    _loading = true;
    try {
      final cached = await _service.getCachedSettings();
      if (_disposed) return;
      if (cached != null && _hasChanged(cached)) {
        _settings = cached;
        notifyListeners();
      }

      final fresh = await _service.refreshSettings();
      if (_disposed) return;
      if (fresh != null && _hasChanged(fresh)) {
        _settings = fresh;
        notifyListeners();
      }
    } finally {
      _loading = false;
    }
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

/// Provides remotely managed store settings to route/widget descendants.
class MobileAppSettingsScope
    extends InheritedNotifier<MobileAppSettingsController> {
  const MobileAppSettingsScope({
    super.key,
    required this.controller,
    required super.child,
  }) : super(notifier: controller);

  final MobileAppSettingsController controller;

  static MobileAppSettingsController of(BuildContext context) {
    final scope = context
        .dependOnInheritedWidgetOfExactType<MobileAppSettingsScope>();
    assert(scope != null, 'MobileAppSettingsScope is missing above this context.');
    return scope!.controller;
  }
}

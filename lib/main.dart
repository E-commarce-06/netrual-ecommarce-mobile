import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cartxis_app/app.dart';
import 'package:cartxis_app/core/config/deployment_config.dart';
import 'package:cartxis_app/core/theme/theme_controller.dart';
import 'package:cartxis_app/core/utils/currency_utils.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  DeploymentConfig.validate();

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  await ThemeController.instance.load();
  CurrencyUtils.preload();

  runApp(const CartxisApp());
}

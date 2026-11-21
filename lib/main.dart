import 'package:flutter/material.dart';

import 'boot_app.dart';
import 'error_log.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  ErrorLog.install();
  runApp(const BootApp());
}

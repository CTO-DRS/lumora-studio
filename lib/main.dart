import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lumora/app.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ProviderScope(child: LumoraApp()));
}

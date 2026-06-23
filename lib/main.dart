import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:provider/provider.dart';
import 'services/sizing_rates_repository.dart';
import 'theme/app_theme.dart';
import 'theme/theme_provider.dart';
import 'theme/costing_provider.dart';
import 'screens/main_nav_shell.dart';
import 'services/history_repository.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  await SizingRatesRepository.instance.init();
  await HistoryRepository.instance.init();

  // CHANGED: ThemeProvider now persists accent + light/dark mode via
  // Hive, so it has to be built asynchronously (it needs to open its
  // box and read back whatever was saved last time) BEFORE runApp,
  // instead of being constructed inline as
  // ChangeNotifierProvider(create: (_) => ThemeProvider()).
  // ChangeNotifierProvider.value(...) is used below to hand this
  // already-built instance to the widget tree, rather than asking
  // Provider to create a fresh (un-loaded) one itself.
  final themeProvider = await ThemeProvider.load();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: themeProvider),
        ChangeNotifierProvider(create: (_) => CostingProvider()),
      ],
      child: const SadeedTexApp(),
    ),
  );
}

class SadeedTexApp extends StatelessWidget {
  const SadeedTexApp({super.key});
  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    return MaterialApp(
      title: 'SadeedTex',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.build(
        accent: themeProvider.accent,
        brightness: Brightness.light,
      ),
      darkTheme: AppTheme.build(
        accent: themeProvider.accent,
        brightness: Brightness.dark,
      ),
      themeMode: themeProvider.themeMode,
      home: const MainNavShell(),
    );
  }
}
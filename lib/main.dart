import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:provider/provider.dart';
import 'services/sizing_rates_repository.dart';
import 'theme/app_theme.dart';
import 'theme/theme_provider.dart';
import 'theme/costing_provider.dart';
import 'screens/main_nav_shell.dart';
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  await SizingRatesRepository.instance.init();
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
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

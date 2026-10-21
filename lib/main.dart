import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_settings.dart';
import 'home_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final settings = AppSettings();
  await settings.load();
  runApp(WaWebApp(settings: settings));
}

ThemeData buildTheme(Brightness b) {
  final dark = b == Brightness.dark;
  final surface = dark ? const Color(0xFF111B21) : const Color(0xFFFFFFFF);
  final panel = dark ? const Color(0xFF202C33) : const Color(0xFFF0F2F5);
  final base = ColorScheme.fromSeed(
    seedColor: const Color(0xFF00A884),
    brightness: b,
  );
  final cs = base.copyWith(
    primary: const Color(0xFF00A884),
    onPrimary: dark ? const Color(0xFF00382C) : Colors.white,
    surface: surface,
    onSurface: dark ? const Color(0xFFE9EDEF) : const Color(0xFF111B21),
    onSurfaceVariant: dark ? const Color(0xFF8696A0) : const Color(0xFF667781),
    surfaceContainerLow: panel,
    surfaceContainer: panel,
    surfaceContainerHigh: panel,
    surfaceContainerHighest: panel,
    outlineVariant: dark ? const Color(0xFF2A3942) : const Color(0xFFD1D7DB),
  );
  return ThemeData(
    useMaterial3: true,
    colorScheme: cs,
    scaffoldBackgroundColor: surface,
    shadowColor: Colors.transparent,
    appBarTheme: AppBarTheme(
      backgroundColor: surface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: surface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
  );
}

class WaWebApp extends StatelessWidget {
  final AppSettings settings;
  const WaWebApp({super.key, required this.settings});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: settings,
      builder: (context, _) {
        final dark = settings.waDark ??
            (PlatformDispatcher.instance.platformBrightness == Brightness.dark);
        final b = dark ? Brightness.dark : Brightness.light;
        SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          systemNavigationBarColor: Colors.transparent,
          statusBarIconBrightness: dark ? Brightness.light : Brightness.dark,
          systemNavigationBarIconBrightness:
              dark ? Brightness.light : Brightness.dark,
        ));
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'waweb',
          theme: buildTheme(b),
          home: HomePage(settings: settings),
        );
      },
    );
  }
}

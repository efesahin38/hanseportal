import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'firebase_options.dart';
import 'theme/app_theme.dart';
import 'providers/app_state.dart';

// Screens
import 'screens/login_screen.dart';
import 'screens/main_shell.dart';
import 'screens/field_worker_shell.dart';
import 'screens/external_manager_shell.dart';
import 'screens/documents_screen.dart';
import 'screens/archive_screen.dart';
import 'screens/role_management_screen.dart';
import 'services/localization_service.dart';


void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (!kIsWeb) {
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
  }

  // Firebase
  try {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  } catch (_) {}

  // Supabase
  await Supabase.initialize(
    url: 'https://qlfdbkrmjzggoaxbnvij.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InFsZmRia3JtanpnZ29heGJudmlqIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzM4NDg0MDYsImV4cCI6MjA4OTQyNDQwNn0.7Z_bcVZRY2d5WyqXSTMv6_0JXtro7UmFd_hLP_aGPE8',
  );

  // Localization
  await LocalizationService().load('de');

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AppState()),
      ],
      child: const HanseApp(),
    ),
  );
}

class HanseApp extends StatelessWidget {
  const HanseApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Hanse',
      theme: AppTheme.theme,
      debugShowCheckedModeBanner: false,
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('tr', 'TR'), Locale('de', 'DE'), Locale('en', 'US')],
      locale: const Locale('de', 'DE'),
      home: Consumer<AppState>(
        builder: (context, appState, _) {
          if (!appState.isInitialized) {
            return const _SplashScreen();
          }
          if (appState.currentUser == null) {
            return const LoginScreen();
          }
          // Saha çalışanları (mitarbeiter, vorarbeiter) sade ekran görüyor
          if (appState.isMitarbeiter || appState.isVorarbeiter) {
            return const FieldWorkerShell();
          }
          // Externer Manager → kendi portalı
          if (appState.isExternalManager) {
            return const ExternalManagerShell();
          }
          // Diğer tüm roller → tam yönetim paneli
          return const MainShell();
        },
      ),
    );
  }
}

class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.primary,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Image.asset('assets/icon/hanse.png', width: 100, height: 100, fit: BoxFit.cover),
            ),
            SizedBox(height: 24),
            Text(
              tr('Hanse Kollektiv GmbH'),
              style: TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.bold,
                fontFamily: 'Inter',
              ),
            ),
            SizedBox(height: 12),
            Text(
              tr('Digitales Managementsystem'),
              style: TextStyle(color: Colors.white70, fontSize: 14, fontFamily: 'Inter'),
            ),
            SizedBox(height: 48),
            CircularProgressIndicator(color: Colors.white),
          ],
        ),
      ),
    );
  }
}

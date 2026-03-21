import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'theme/app_theme.dart';
import 'providers/app_state.dart';
import 'screens/login_screen.dart';
import 'screens/admin_dashboard_screen.dart';
import 'screens/manager_dashboard_screen.dart';
import 'screens/worker_dashboard_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (_) {}
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AppState()),
      ],
      child: const EkremPdksApp(),
    ),
  );
}

class EkremPdksApp extends StatelessWidget {
  const EkremPdksApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Ekrem PDKS',
      theme: AppTheme.lightTheme,
      home: Consumer<AppState>(
        builder: (context, appState, _) {
          if (!appState.isInitialized) {
            return const Scaffold(body: Center(child: CircularProgressIndicator()));
          }
          final user = appState.currentUser;
          if (user == null) return LoginScreen();
          
          final role = user['role'];
          if (role == 'super_admin') return AdminDashboardScreen();
          if (role == 'manager') return ManagerDashboardScreen();
          return WorkerDashboardScreen();
        },
      ),
      debugShowCheckedModeBanner: false,
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('tr', 'TR'), Locale('en', 'US')],
      locale: const Locale('tr', 'TR'),
    );
  }
}


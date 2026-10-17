import 'package:flutter/material.dart';
import 'core/theme/app_theme.dart';
import 'services/storage/database_service.dart';
import 'state/app_state.dart';
import 'views/auth/login_screen.dart';
import 'views/navigation/main_shell.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize offline persistent database & seed repository
  final db = DatabaseService.instance;
  await db.initialize();

  runApp(const DiscoMeterReaderApp());
}

class DiscoMeterReaderApp extends StatefulWidget {
  const DiscoMeterReaderApp({super.key});

  @override
  State<DiscoMeterReaderApp> createState() => _DiscoMeterReaderAppState();
}

class _DiscoMeterReaderAppState extends State<DiscoMeterReaderApp> {
  late final AppState _state;
  bool _isAuthenticated = true; // Auto-logged into default demo session per FR-2

  @override
  void initState() {
    super.initState();
    _state = AppState();
    _state.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _state.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Pakistan DISCO AI Meter Reader',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: _state.themeMode,
      home: _isAuthenticated
          ? MainShell(state: _state)
          : LoginScreen(
              state: _state,
              onLoginSuccess: () => setState(() => _isAuthenticated = true),
            ),
    );
  }
}

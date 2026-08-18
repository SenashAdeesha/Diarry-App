import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'firebase_options.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';

import 'core/constants/app_constants.dart';
import 'core/services/auth_service.dart';
import 'core/services/hive_service.dart';
import 'core/services/notification_service.dart';
import 'core/services/sync_service.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_provider.dart';
import 'features/auth/presentation/screens/lock_screen.dart';
import 'features/diary/data/datasources/diary_local_datasource.dart';
import 'features/diary/data/datasources/remote/diary_remote_datasource.dart';
import 'features/diary/data/models/diary_entry_model.dart';
import 'features/diary/data/repositories/diary_repository_impl.dart';
import 'features/diary/presentation/providers/diary_provider.dart';
import 'features/diary/presentation/screens/main_shell.dart';
import 'providers/auth_provider.dart';
import 'screens/splash/splash_screen.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/register_screen.dart';
import 'screens/auth/forgot_password_screen.dart';
import 'screens/auth/verify_email_screen.dart';

enum AppStartupStatus { initializing, ready, failed }

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const ProviderScope(child: _AppBootstrap()));
}

class _AppBootstrap extends StatefulWidget {
  const _AppBootstrap();

  @override
  State<_AppBootstrap> createState() => _AppBootstrapState();
}

class _AppBootstrapState extends State<_AppBootstrap> {
  AppStartupStatus _status = AppStartupStatus.initializing;
  DiaryRepositoryImpl? _repository;
  String? _error;
  bool _needsAuth = false;
  late final GlobalKey<NavigatorState> _navigatorKey;

  @override
  void initState() {
    super.initState();
    _startup();
  }

  Future<void> _startup() async {
    final hive = HiveService.instance;
    hive.registerAdapter(() => Hive.registerAdapter(DiaryEntryModelAdapter()));

    final hiveResult = await hive.init();
    if (!hiveResult.success) {
      if (!mounted) return;
      setState(() {
        _status = AppStartupStatus.failed;
        _error = hiveResult.error;
      });
      return;
    }

    try {
      await Future.wait([
        Firebase.initializeApp(),
        hive.openBox<DiaryEntryModel>(
          AppConstants.hiveBoxName,
          clearOnFail: true,
        ),
        AuthService.instance.init(),
      ]);

      final box = hive.getBox<DiaryEntryModel>(AppConstants.hiveBoxName)!;
      final auth = AuthService.instance;
      final dataSource = DiaryLocalDataSourceImpl(box);
      final remoteDataSource = DiaryRemoteDataSource();
      _repository = DiaryRepositoryImpl(dataSource: dataSource, auth: auth);

      SyncService.instance.init(
        repository: _repository!,
        localDataSource: dataSource,
        remoteDataSource: remoteDataSource,
      );
      SyncService.instance.sync();

      _navigatorKey = GlobalKey<NavigatorState>();
      final navKey = _navigatorKey;
      await NotificationService.instance.init(navigatorKey: navKey);
      await NotificationService.instance.rescheduleIfNeeded();

      if (!mounted) return;
      setState(() {
        _status = AppStartupStatus.ready;
        _needsAuth = auth.hasPin;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _status = AppStartupStatus.failed;
        _error = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    switch (_status) {
      case AppStartupStatus.initializing:
        return _buildSplash(context);
      case AppStartupStatus.failed:
        return _buildError(context);
      case AppStartupStatus.ready:
        return ProviderScope(
          overrides: [
            diaryRepositoryProvider.overrideWithValue(_repository!),
          ],
          child: _needsAuth
              ? _AuthGate(child: DiaryApp(navigatorKey: _navigatorKey))
              : DiaryApp(navigatorKey: _navigatorKey),
        );
    }
  }

  Widget _buildSplash(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.menu_book_rounded,
                  size: 64, color: Theme.of(context).colorScheme.primary),
              const SizedBox(height: 24),
              Text(AppConstants.appName,
                  style: Theme.of(context).textTheme.headlineMedium),
              const SizedBox(height: 32),
              const CircularProgressIndicator(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildError(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 64, color: Colors.red),
                const SizedBox(height: 24),
                Text('Failed to start',
                    style: Theme.of(context).textTheme.headlineSmall),
                const SizedBox(height: 8),
                Text(_error ?? 'Unknown error',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium),
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: () {
                    setState(() {
                      _status = AppStartupStatus.initializing;
                      _error = null;
                    });
                    _startup();
                  },
                  icon: const Icon(Icons.refresh),
                  label: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AuthGate extends StatefulWidget {
  final Widget child;
  const _AuthGate({required this.child});

  @override
  State<_AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<_AuthGate> with WidgetsBindingObserver {
  final _auth = AuthService.instance;
  bool _locked = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      _auth.lock();
    } else if (state == AppLifecycleState.resumed) {
      if (_auth.isTimedOut()) {
        setState(() => _locked = true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_locked) {
      return LockScreen(
        onUnlocked: () => setState(() => _locked = false),
      );
    }
    return widget.child;
  }
}

class _NoGlowScrollBehavior extends ScrollBehavior {
  const _NoGlowScrollBehavior();

  @override
  Widget buildOverscrollIndicator(BuildContext context, Widget child, ScrollableDetails details) {
    return child;
  }
}

class DiaryApp extends ConsumerWidget {
  final GlobalKey<NavigatorState> navigatorKey;
  const DiaryApp({super.key, required this.navigatorKey});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prefs = ref.watch(themePreferencesProvider);

    return MaterialApp(
      navigatorKey: navigatorKey,
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      scrollBehavior: const _NoGlowScrollBehavior(),
      theme: AppTheme.fromPrefs(prefs, Brightness.light),
      darkTheme: AppTheme.fromPrefs(prefs, Brightness.dark),
      themeMode: prefs.mode,
      home: const _AppShell(),
    );
  }
}

class _AppShell extends ConsumerWidget {
  const _AppShell();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authProvider);
    final screen = auth.currentScreen;

    if (screen == AuthScreen.home) return const MainShell();

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 350),
      child: KeyedSubtree(
        key: ValueKey(screen.name),
        child: _buildScreen(screen),
      ),
    );
  }

  Widget _buildScreen(AuthScreen screen) {
    switch (screen) {
      case AuthScreen.splash:
        return const SplashScreen();
      case AuthScreen.login:
        return LoginScreen();
      case AuthScreen.register:
        return RegisterScreen();
      case AuthScreen.forgotPassword:
        return ForgotPasswordScreen();
      case AuthScreen.verifyEmail:
        return VerifyEmailScreen();
      case AuthScreen.home:
        return const MainShell();
    }
  }
}

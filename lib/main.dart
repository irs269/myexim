import 'package:flutter/material.dart';

import 'core/app_scope.dart';
import 'core/l10n/strings.dart';
import 'core/session.dart';
import 'core/theme/app_colors.dart';
import 'core/theme/app_theme.dart';
import 'data/mock_auth_repository.dart';
import 'data/mock_bank_repository.dart';
import 'features/auth/auth_widgets.dart' show EximMonogram;
import 'features/auth/pin_lock_screen.dart';
import 'features/auth/welcome_screen.dart';
import 'features/onboarding/onboarding_widgets.dart';
import 'features/shell/main_shell.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // Remplacer les implémentations Mock* par celles des API une fois la doc reçue.
  final session = SessionController(auth: MockAuthRepository())..restore();
  OnboardingStore.load();
  runApp(AppScope(
    repository: MockBankRepository(),
    session: session,
    language: ValueNotifier(AppLanguage.fr),
    child: const MyEximApp(),
  ));
}

class MyEximApp extends StatefulWidget {
  const MyEximApp({super.key});

  @override
  State<MyEximApp> createState() => _MyEximAppState();
}

class _MyEximAppState extends State<MyEximApp> {
  final _messengerKey = GlobalKey<ScaffoldMessengerState>();
  late final _snackCloser = _SnackBarCloser(_messengerKey);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MyExim',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      scaffoldMessengerKey: _messengerKey,
      navigatorObservers: [_snackCloser],
      home: const SessionGate(),
    );
  }
}

/// Ferme le message en cours quand un nouvel écran s'ouvre : un message flottant
/// ne doit pas recouvrir les boutons de l'écran suivant.
class _SnackBarCloser extends NavigatorObserver {
  _SnackBarCloser(this.messengerKey);
  final GlobalKey<ScaffoldMessengerState> messengerKey;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (route is PageRoute) messengerKey.currentState?.hideCurrentSnackBar();
  }
}

/// Affiche l'écran correspondant à l'état de session et verrouille l'app
/// après [lockAfter] passé en arrière-plan.
class SessionGate extends StatefulWidget {
  const SessionGate({super.key});

  static const lockAfter = Duration(minutes: 2);

  @override
  State<SessionGate> createState() => _SessionGateState();
}

class _SessionGateState extends State<SessionGate> with WidgetsBindingObserver {
  SessionController? _session;
  SessionStatus? _lastStatus;
  DateTime? _pausedAt;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final session = AppScope.of(context).session;
    if (session != _session) {
      _session?.removeListener(_onSession);
      _session = session..addListener(_onSession);
      _lastStatus = session.status;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _session?.removeListener(_onSession);
    super.dispose();
  }

  void _onSession() {
    final status = _session!.status;
    if (status == _lastStatus) return;
    _lastStatus = status;
    // Changement d'état : on referme les écrans empilés (parcours de connexion, etc.).
    Navigator.of(context).popUntil((r) => r.isFirst);
    setState(() {});
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      _pausedAt = DateTime.now();
    } else if (state == AppLifecycleState.resumed) {
      final pausedAt = _pausedAt;
      _pausedAt = null;
      if (pausedAt != null && DateTime.now().difference(pausedAt) > SessionGate.lockAfter) _session?.lock();
    }
  }

  @override
  Widget build(BuildContext context) {
    return switch (_session!.status) {
      SessionStatus.loading => const Scaffold(
          backgroundColor: AppColors.navy,
          body: Center(child: EximMonogram(height: 120)),
        ),
      SessionStatus.loggedOut => const WelcomeScreen(),
      SessionStatus.locked => const PinLockScreen(),
      SessionStatus.unlocked => const MainShell(),
    };
  }
}

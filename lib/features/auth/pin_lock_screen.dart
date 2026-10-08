import 'package:flutter/material.dart';

import '../../core/app_scope.dart';
import '../../core/l10n/strings.dart';
import '../../core/theme/app_colors.dart';
import 'auth_widgets.dart';
import 'create_pin_screen.dart' show pinLength;

/// Déverrouillage au lancement : PIN ou biométrie.
class PinLockScreen extends StatefulWidget {
  const PinLockScreen({super.key});

  @override
  State<PinLockScreen> createState() => _PinLockScreenState();
}

class _PinLockScreenState extends State<PinLockScreen> {
  String _pin = '';
  bool _error = false;
  bool _checking = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _tryBiometrics());
  }

  Future<void> _tryBiometrics() async {
    if (!mounted) return;
    final session = AppScope.of(context).session;
    if (session.biometricEnabled) await session.unlockWithBiometrics(S.of(context).biometricReason);
  }

  void _onDigit(String d) {
    if (_checking || _pin.length >= pinLength) return;
    setState(() {
      _error = false;
      _pin += d;
    });
    if (_pin.length == pinLength) _check();
  }

  Future<void> _check() async {
    setState(() => _checking = true);
    final ok = await AppScope.of(context).session.unlockWithPin(_pin);
    if (!mounted || ok) return;
    setState(() {
      _error = true;
      _pin = '';
      _checking = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final session = AppScope.of(context).session;
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 48),
            const EximLogo(scale: 0.8),
            const SizedBox(height: 40),
            Text(s.enterPinTitle, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 28),
            PinDots(filled: _pin.length, length: pinLength, error: _error),
            const SizedBox(height: 16),
            SizedBox(
              height: 20,
              child: _error
                  ? Text(s.pinAttemptsLeft(session.pinAttemptsLeft), style: const TextStyle(color: AppColors.danger))
                  : null,
            ),
            const Spacer(),
            PinPad(
              onDigit: _onDigit,
              onBackspace: () {
                if (_pin.isNotEmpty) setState(() => _pin = _pin.substring(0, _pin.length - 1));
              },
              extraKey: session.biometricEnabled
                  ? SizedBox(
                      width: 80,
                      height: 72,
                      child: IconButton(
                        icon: const Icon(Icons.fingerprint, size: 34, color: AppColors.navy),
                        onPressed: _tryBiometrics,
                      ),
                    )
                  : null,
            ),
            TextButton(
              style: TextButton.styleFrom(foregroundColor: AppColors.navy),
              onPressed: () => session.logout(forgetUser: true),
              child: Text(s.notYou, style: const TextStyle(fontWeight: FontWeight.w600)),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }
}

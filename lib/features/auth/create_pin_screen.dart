import 'package:flutter/material.dart';

import '../../core/app_scope.dart';
import '../../core/l10n/strings.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/widgets.dart';
import 'auth_widgets.dart';

const pinLength = 4;

/// Création du PIN en deux temps (saisie puis confirmation), puis offre biométrique.
class CreatePinScreen extends StatefulWidget {
  const CreatePinScreen({super.key});

  @override
  State<CreatePinScreen> createState() => _CreatePinScreenState();
}

class _CreatePinScreenState extends State<CreatePinScreen> {
  String _first = '';
  String _current = '';
  bool _confirming = false;
  bool _mismatch = false;
  bool _saving = false;

  void _onDigit(String d) {
    if (_saving || _current.length >= pinLength) return;
    setState(() {
      _mismatch = false;
      _current += d;
    });
    if (_current.length == pinLength) _onComplete();
  }

  void _onBackspace() {
    if (_current.isEmpty) return;
    setState(() => _current = _current.substring(0, _current.length - 1));
  }

  Future<void> _onComplete() async {
    if (!_confirming) {
      await Future.delayed(const Duration(milliseconds: 150));
      setState(() {
        _first = _current;
        _current = '';
        _confirming = true;
      });
      return;
    }
    if (_current != _first) {
      setState(() {
        _mismatch = true;
        _first = '';
        _current = '';
        _confirming = false;
      });
      return;
    }

    setState(() => _saving = true);
    final session = AppScope.of(context).session;
    await session.createPin(_current);
    final canBio = await session.canUseBiometrics();
    if (!mounted) return;
    if (canBio) {
      Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const BiometricOfferScreen()));
    } else {
      session.finishEnrollment();
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return PopScope(
      canPop: false,
      child: Scaffold(
        body: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 60, 24, 0),
                child: Column(
                  children: [
                    Text(_confirming ? s.confirmPinTitle : s.createPinTitle,
                        textAlign: TextAlign.center, style: Theme.of(context).textTheme.headlineMedium),
                    const SizedBox(height: 10),
                    Text(_mismatch ? s.pinMismatch : s.createPinBody,
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 16, color: _mismatch ? AppColors.danger : AppColors.textSecondary)),
                  ],
                ),
              ),
              const SizedBox(height: 40),
              PinDots(filled: _current.length, length: pinLength, error: _mismatch),
              const Spacer(),
              PinPad(onDigit: _onDigit, onBackspace: _onBackspace),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

class BiometricOfferScreen extends StatefulWidget {
  const BiometricOfferScreen({super.key});

  @override
  State<BiometricOfferScreen> createState() => _BiometricOfferScreenState();
}

class _BiometricOfferScreenState extends State<BiometricOfferScreen> {
  bool _busy = false;

  Future<void> _enable() async {
    final s = S.of(context);
    final session = AppScope.of(context).session;
    setState(() => _busy = true);
    // Activer, puis demander une première vérification pour confirmer que ça marche.
    await session.setBiometricEnabled(true);
    final ok = await session.unlockWithBiometrics(s.biometricReason);
    if (!ok) await session.setBiometricEnabled(false);
    session.finishEnrollment();
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final session = AppScope.of(context).session;
    return PopScope(
      canPop: false,
      child: AuthScaffold(
        canPop: false,
        title: s.biometricTitle,
        subtitle: s.biometricBody,
        bottom: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            PrimaryButton(label: s.enable, loading: _busy, onPressed: _enable),
            const SizedBox(height: 8),
            TextButton(
              style: TextButton.styleFrom(foregroundColor: AppColors.navy),
              onPressed: _busy ? null : session.finishEnrollment,
              child: Text(s.notNow, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
            ),
          ],
        ),
        children: const [
          SizedBox(height: 40),
          Center(child: CircleIcon(icon: Icons.fingerprint, size: 120)),
        ],
      ),
    );
  }
}

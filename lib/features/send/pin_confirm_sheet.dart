import 'package:flutter/material.dart';

import '../../core/app_scope.dart';
import '../../core/l10n/strings.dart';
import '../../core/theme/app_colors.dart';
import '../auth/auth_widgets.dart';
import '../auth/create_pin_screen.dart' show pinLength;

/// Demande le PIN (ou l'empreinte) pour valider une opération. Renvoie true si validé.
Future<bool> confirmWithPin(BuildContext context) async {
  final ok = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: AppColors.background,
    builder: (_) => const _PinConfirmSheet(),
  );
  return ok ?? false;
}

class _PinConfirmSheet extends StatefulWidget {
  const _PinConfirmSheet();

  @override
  State<_PinConfirmSheet> createState() => _PinConfirmSheetState();
}

class _PinConfirmSheetState extends State<_PinConfirmSheet> {
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
    if (!session.biometricEnabled) return;
    final ok = await session.verifyBiometrics(S.of(context).biometricConfirmReason);
    if (ok && mounted) Navigator.of(context).pop(true);
  }

  Future<void> _onDigit(String d) async {
    if (_checking || _pin.length >= pinLength) return;
    setState(() {
      _error = false;
      _pin += d;
    });
    if (_pin.length < pinLength) return;
    setState(() => _checking = true);
    final ok = await AppScope.of(context).session.verifyPin(_pin);
    if (!mounted) return;
    if (ok) {
      Navigator.of(context).pop(true);
    } else {
      setState(() {
        _error = true;
        _pin = '';
        _checking = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final session = AppScope.of(context).session;
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(s.confirmWithPin, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 24),
          PinDots(filled: _pin.length, length: pinLength, error: _error),
          SizedBox(
            height: 36,
            child: Center(
              child: _error
                  ? Text(s.pinAttemptsLeft(session.pinAttemptsLeft), style: const TextStyle(color: AppColors.danger))
                  : null,
            ),
          ),
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
                      tooltip: s.useBiometrics,
                      icon: const Icon(Icons.fingerprint, size: 34, color: AppColors.navy),
                      onPressed: _tryBiometrics,
                    ),
                  )
                : null,
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

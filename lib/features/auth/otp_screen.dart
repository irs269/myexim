import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/app_scope.dart';
import '../../core/l10n/strings.dart';
import '../../core/theme/app_colors.dart';
import '../../data/auth_repository.dart';
import 'auth_widgets.dart';
import 'choose_credentials_screen.dart';
import 'create_pin_screen.dart';

class OtpScreen extends StatefulWidget {
  const OtpScreen({super.key, required this.challenge, this.next});
  final OtpChallenge challenge;

  /// Écran affiché après validation ; par défaut, déduit de [OtpChallenge.purpose].
  final Widget Function(String token)? next;

  @override
  State<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends State<OtpScreen> {
  static const _resendDelay = 60;
  final _code = TextEditingController();
  Timer? _timer;
  int _secondsLeft = _resendDelay;
  bool _loading = false;
  bool _error = false;

  @override
  void initState() {
    super.initState();
    _code.addListener(() => setState(() {}));
    _startTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _code.dispose();
    super.dispose();
  }

  void _startTimer() {
    _timer?.cancel();
    setState(() => _secondsLeft = _resendDelay);
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_secondsLeft <= 1) t.cancel();
      setState(() => _secondsLeft--);
    });
  }

  Future<void> _verify(String code) async {
    if (_loading) return;
    final s = S.of(context);
    final session = AppScope.of(context).session;
    setState(() {
      _loading = true;
      _error = false;
    });
    try {
      final token = await session.auth.verifyOtp(challenge: widget.challenge, code: code);
      if (!mounted) return;
      final next = widget.next?.call(token) ?? switch (widget.challenge.purpose) {
        OtpPurpose.login => () {
            session.onLoginVerified(token);
            return const CreatePinScreen();
          }(),
        OtpPurpose.selfRegistration => ChooseCredentialsScreen(registrationToken: token),
        OtpPurpose.onboarding => throw StateError('next requis pour l\'ouverture de compte'),
      };
      Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => next));
    } on AuthException catch (e) {
      if (!mounted) return;
      setState(() => _error = true);
      _code.clear();
      showErrorSnack(context, e.message);
    } catch (_) {
      if (mounted) showErrorSnack(context, s.genericError);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _resend() async {
    final s = S.of(context);
    try {
      await AppScope.of(context).session.auth.resendOtp(widget.challenge);
      if (!mounted) return;
      _startTimer();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s.codeResent), behavior: SnackBarBehavior.floating));
    } catch (_) {
      if (mounted) showErrorSnack(context, s.genericError);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return AuthScaffold(
      title: s.otpTitle,
      subtitle: s.otpBody(widget.challenge.maskedPhone),
      bottom: PrimaryButton(
        label: s.continueLabel,
        loading: _loading,
        onPressed: _code.text.length == 6 ? () => _verify(_code.text) : null,
      ),
      children: [
        OtpField(controller: _code, hasError: _error, onCompleted: _verify),
        const SizedBox(height: 24),
        Align(
          alignment: Alignment.centerLeft,
          child: _secondsLeft > 0
              ? Text(s.resendIn(_secondsLeft), style: const TextStyle(color: AppColors.textSecondary))
              : TextButton(
                  style: TextButton.styleFrom(padding: EdgeInsets.zero, foregroundColor: AppColors.navy),
                  onPressed: _resend,
                  child: Text(s.resendCode,
                      style: const TextStyle(fontWeight: FontWeight.w700, decoration: TextDecoration.underline)),
                ),
        ),
      ],
    );
  }
}

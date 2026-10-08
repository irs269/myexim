import 'package:flutter/material.dart';

import '../../core/app_scope.dart';
import '../../core/l10n/strings.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../data/auth_repository.dart';
import 'auth_widgets.dart';
import 'coming_soon_screen.dart';
import 'otp_screen.dart';

/// Connexion. Après une première connexion réussie sur l'appareil, le client est mémorisé :
/// son nom est affiché (non modifiable) et seul le mot de passe est demandé.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, this.initialUsername});

  /// Identifiant pré-rempli (juste après l'auto-inscription).
  final String? initialUsername;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _form = GlobalKey<FormState>();
  late final _username = TextEditingController(text: widget.initialUsername);
  final _password = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    _username.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    final s = S.of(context);
    final session = AppScope.of(context).session;
    final remembered = widget.initialUsername == null ? session.rememberedUser : null;
    final username = remembered?.username ?? _username.text.trim();
    setState(() => _loading = true);
    try {
      final challenge = await session.auth.login(username: username, password: _password.text);
      session.setPendingUser(username: username, displayName: challenge.customerName ?? username);
      if (!mounted) return;
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => OtpScreen(challenge: challenge)));
    } on AuthException catch (e) {
      if (mounted) showErrorSnack(context, e.message);
    } catch (_) {
      if (mounted) showErrorSnack(context, s.genericError);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _switchAccount() async {
    await AppScope.of(context).session.forgetUser();
    _password.clear();
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final session = AppScope.of(context).session;
    final remembered = widget.initialUsername == null ? session.rememberedUser : null;
    String? required(String? v) => (v == null || v.trim().isEmpty) ? s.requiredField : null;

    final password = LabeledField(
      label: s.password,
      controller: _password,
      obscure: true,
      validator: required,
      textInputAction: TextInputAction.done,
      onSubmitted: (_) => _submit(),
      autofillHints: const [AutofillHints.password],
    );
    final forgot = Align(
      alignment: Alignment.centerLeft,
      child: TextButton(
        style: TextButton.styleFrom(padding: EdgeInsets.zero, foregroundColor: AppColors.navy),
        onPressed: () =>
            Navigator.of(context).push(MaterialPageRoute(builder: (_) => ComingSoonScreen(title: s.forgotPassword))),
        child: Text(s.forgotPassword, style: const TextStyle(fontWeight: FontWeight.w700, decoration: TextDecoration.underline)),
      ),
    );

    return Form(
      key: _form,
      child: AutofillGroup(
        child: AuthScaffold(
          title: remembered == null ? s.loginTitle : s.hello,
          subtitle: remembered == null ? null : s.enterPassword,
          bottom: PrimaryButton(label: s.continueLabel, loading: _loading, onPressed: _submit),
          children: remembered == null
              ? [
                  LabeledField(
                    label: s.username,
                    controller: _username,
                    validator: required,
                    autofillHints: const [AutofillHints.username],
                  ),
                  password,
                  forgot,
                ]
              : [
                  // Client mémorisé : nom affiché, non modifiable.
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(18)),
                    child: Row(
                      children: [
                        Container(
                          width: 52,
                          height: 52,
                          alignment: Alignment.center,
                          decoration: const BoxDecoration(color: AppColors.navy, shape: BoxShape.circle),
                          child: Text(initials(remembered.displayName),
                              style: const TextStyle(color: AppColors.gold, fontWeight: FontWeight.w800, fontSize: 18)),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Text(remembered.displayName,
                              style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800)),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  password,
                  Row(
                    children: [
                      Expanded(child: forgot),
                      TextButton.icon(
                        style: TextButton.styleFrom(foregroundColor: AppColors.navy, padding: EdgeInsets.zero),
                        icon: const Icon(Icons.swap_horiz, size: 20),
                        label: Text(s.switchAccount, style: const TextStyle(fontWeight: FontWeight.w700)),
                        onPressed: _switchAccount,
                      ),
                    ],
                  ),
                ],
        ),
      ),
    );
  }
}

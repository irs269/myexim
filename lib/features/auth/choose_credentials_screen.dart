import 'package:flutter/material.dart';

import '../../core/app_scope.dart';
import '../../core/l10n/strings.dart';
import '../../core/theme/app_colors.dart';
import '../../data/auth_repository.dart';
import 'auth_widgets.dart';
import 'login_screen.dart';

/// Dernière étape de l'auto-inscription : identifiant + mot de passe.
class ChooseCredentialsScreen extends StatefulWidget {
  const ChooseCredentialsScreen({super.key, required this.registrationToken});
  final String registrationToken;

  @override
  State<ChooseCredentialsScreen> createState() => _ChooseCredentialsScreenState();
}

class _ChooseCredentialsScreenState extends State<ChooseCredentialsScreen> {
  final _form = GlobalKey<FormState>();
  final _username = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    _username.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    final s = S.of(context);
    setState(() => _loading = true);
    try {
      await AppScope.of(context).session.auth.completeSelfRegistration(
            registrationToken: widget.registrationToken,
            username: _username.text.trim(),
            password: _password.text,
          );
      if (!mounted) return;
      final navigator = Navigator.of(context);
      final messenger = ScaffoldMessenger.of(context);
      navigator.popUntil((r) => r.isFirst);
      navigator.push(MaterialPageRoute(builder: (_) => LoginScreen(initialUsername: _username.text.trim())));
      // Après la navigation : un changement d'écran ferme les messages en cours.
      messenger.showSnackBar(SnackBar(
        content: Text(s.registrationDone),
        backgroundColor: AppColors.success,
        behavior: SnackBarBehavior.floating,
      ));
    } on AuthException catch (e) {
      if (mounted) showErrorSnack(context, e.message);
    } catch (_) {
      if (mounted) showErrorSnack(context, s.genericError);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return Form(
      key: _form,
      child: AutofillGroup(
        child: AuthScaffold(
          title: s.choosePasswordTitle,
          subtitle: s.passwordRules,
          bottom: PrimaryButton(label: s.continueLabel, loading: _loading, onPressed: _submit),
          children: [
            LabeledField(
              label: s.username,
              controller: _username,
              autofillHints: const [AutofillHints.newUsername],
              validator: (v) => (v == null || v.trim().isEmpty) ? s.requiredField : null,
            ),
            LabeledField(
              label: s.password,
              controller: _password,
              obscure: true,
              autofillHints: const [AutofillHints.newPassword],
              validator: (v) => (v == null || v.length < 8 || !v.contains(RegExp(r'\d'))) ? s.passwordRules : null,
            ),
            LabeledField(
              label: s.confirmPassword,
              controller: _confirm,
              obscure: true,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _submit(),
              validator: (v) => v != _password.text ? s.passwordMismatch : null,
            ),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';

import '../../core/app_scope.dart';
import '../../core/l10n/strings.dart';
import '../../core/theme/app_colors.dart';
import '../../data/auth_repository.dart';
import '../../shared/widgets.dart';
import 'auth_widgets.dart';
import 'otp_screen.dart';

/// Première connexion d'un client existant : numéro de compte OU numéro client,
/// plus la date de naissance. Si tout correspond au fichier de la banque, un OTP
/// est envoyé au téléphone enregistré, puis le client choisit ses identifiants.
class SelfRegistrationScreen extends StatefulWidget {
  const SelfRegistrationScreen({super.key, this.initialAccountNumber});

  /// Pré-rempli après l'ouverture d'un compte en ligne.
  final String? initialAccountNumber;

  @override
  State<SelfRegistrationScreen> createState() => _SelfRegistrationScreenState();
}

class _SelfRegistrationScreenState extends State<SelfRegistrationScreen> {
  final _form = GlobalKey<FormState>();
  late final _identifier = TextEditingController(text: widget.initialAccountNumber);
  final _birthDate = TextEditingController();
  SelfRegistrationId _type = SelfRegistrationId.accountNumber;
  DateTime? _dob;
  bool _loading = false;

  @override
  void dispose() {
    _identifier.dispose();
    _birthDate.dispose();
    super.dispose();
  }

  static String _format(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  Future<void> _pickBirthDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _dob ?? DateTime(now.year - 30, 1, 1),
      firstDate: DateTime(1900),
      lastDate: now,
      initialEntryMode: DatePickerEntryMode.calendarOnly,
      helpText: S.of(context).birthDate,
    );
    if (picked == null) return;
    setState(() {
      _dob = picked;
      _birthDate.text = _format(picked);
    });
  }

  void _switchType(SelfRegistrationId type) {
    if (type == _type) return;
    setState(() {
      _type = type;
      _identifier.clear();
    });
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    final s = S.of(context);
    setState(() => _loading = true);
    try {
      final challenge = await AppScope.of(context).session.auth.startSelfRegistration(
            type: _type,
            identifier: _identifier.text.trim(),
            birthDate: _dob!,
          );
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

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final byAccount = _type == SelfRegistrationId.accountNumber;
    return Form(
      key: _form,
      child: AuthScaffold(
        title: s.selfRegTitle,
        subtitle: s.selfRegBody,
        bottom: PrimaryButton(label: s.continueLabel, loading: _loading, onPressed: _submit),
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              PillButton(
                label: s.accountNumber,
                dense: true,
                variant: byAccount ? PillVariant.primary : PillVariant.outline,
                onPressed: () => _switchType(SelfRegistrationId.accountNumber),
              ),
              PillButton(
                label: s.customerNumber,
                dense: true,
                variant: byAccount ? PillVariant.outline : PillVariant.primary,
                onPressed: () => _switchType(SelfRegistrationId.customerNumber),
              ),
            ],
          ),
          const SizedBox(height: 22),
          LabeledField(
            key: ValueKey(_type),
            label: byAccount ? s.accountNumber : s.customerNumber,
            controller: _identifier,
            keyboardType: TextInputType.number,
            validator: (v) => (v == null || v.trim().length < 4) ? s.requiredField : null,
          ),
          Text(s.birthDate, style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
          const SizedBox(height: 8),
          TextFormField(
            controller: _birthDate,
            readOnly: true,
            onTap: _pickBirthDate,
            validator: (_) => _dob == null ? s.requiredField : null,
            style: const TextStyle(fontSize: 17),
            decoration: InputDecoration(
              hintText: s.birthDateHint,
              suffixIcon: const Icon(Icons.calendar_today_outlined),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.border)),
              focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.navy, width: 1.5)),
              errorBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.danger)),
            ),
          ),
          const SizedBox(height: 18),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.sms_outlined, size: 20, color: AppColors.textSecondary),
              const SizedBox(width: 10),
              Expanded(
                child: Text(s.otpToRegisteredPhone, style: const TextStyle(color: AppColors.textSecondary)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

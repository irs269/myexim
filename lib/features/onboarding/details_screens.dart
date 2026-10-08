import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/app_scope.dart';
import '../../core/l10n/strings.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../data/auth_repository.dart';
import '../../shared/result_screen.dart';
import '../auth/auth_widgets.dart';
import '../auth/self_registration_screen.dart';
import '../send/send_flow.dart' show parseAmount;
import 'onboarding_widgets.dart';

/// Étape 3a : revenus, situation professionnelle, adresse et agence.
class DetailsFormScreen extends StatefulWidget {
  const DetailsFormScreen({super.key, required this.draft});
  final OnboardingDraft draft;

  @override
  State<DetailsFormScreen> createState() => _DetailsFormScreenState();
}

class _DetailsFormScreenState extends State<DetailsFormScreen> {
  final _form = GlobalKey<FormState>();
  late final _income = TextEditingController(
    text: widget.draft.annualIncome == null ? '' : formatAmount(widget.draft.annualIncome!, 'KMF', withCode: false),
  );
  late final _building = TextEditingController(text: widget.draft.building);
  late final _street = TextEditingController(
    text: widget.draft.street.isNotEmpty ? widget.draft.street : _title(widget.draft.identity?.residenceStreet),
  );
  late final _country = TextEditingController(text: widget.draft.country);
  late String? _city = widget.draft.city.isNotEmpty
      ? widget.draft.city
      : comorosCities.where((c) => c.toUpperCase() == widget.draft.identity?.residenceCity).firstOrNull;

  static String _title(String? v) =>
      v == null ? '' : v.toLowerCase().split(' ').map((w) => w.isEmpty ? w : w[0].toUpperCase() + w.substring(1)).join(' ');

  @override
  void dispose() {
    _income.dispose();
    _building.dispose();
    _street.dispose();
    _country.dispose();
    super.dispose();
  }

  void _proceed() {
    if (!_form.currentState!.validate()) return;
    widget.draft
      ..annualIncome = parseAmount(_income.text)
      ..building = _building.text.trim()
      ..street = _street.text.trim()
      ..city = _city ?? ''
      ..country = _country.text;
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => DetailsSummaryScreen(draft: widget.draft)));
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final d = widget.draft;
    String? required(String? v) => (v == null || v.trim().isEmpty) ? s.requiredField : null;
    return Form(
      key: _form,
      child: OnboardingScaffold(
        title: s.confirmInfo,
        completedSteps: 2,
        nextLabel: s.nextAccountOpening,
        bottom: OnboardingButton(label: s.proceed, onPressed: _proceed),
        children: [
          Text(s.fillDetails, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.textSecondary)),
          const SizedBox(height: 8),
          TextFormField(
            controller: _income,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9\s ]'))],
            validator: (v) => parseAmount(v ?? '') == null ? s.requiredField : null,
            decoration: InputDecoration(
              labelText: s.annualIncome,
              contentPadding: const EdgeInsets.symmetric(vertical: 8),
              suffixText: 'KMF',
              border: const UnderlineInputBorder(),
              enabledBorder: const UnderlineInputBorder(borderSide: BorderSide(color: AppColors.border)),
            ),
          ),
          const SizedBox(height: 8),
          LineDropdown<int>(
            label: s.employmentType,
            value: d.employment,
            hint: s.select,
            items: [for (var i = 0; i < 6; i++) (i, s.employmentLabel(i))],
            onChanged: (v) => setState(() => d.employment = v),
            validator: (v) => v == null ? s.requiredField : null,
          ),
          const SizedBox(height: 12),
          Text(s.currentAddress, style: const TextStyle(color: AppColors.textSecondary, fontSize: 16)),
          LineField(label: s.building, controller: _building, validator: required),
          LineField(label: s.streetName, controller: _street, validator: required),
          LineDropdown<String>(
            label: s.city,
            value: _city,
            hint: s.select,
            items: [for (final c in comorosCities) (c, c)],
            onChanged: (v) => setState(() => _city = v),
            validator: (v) => v == null ? s.requiredField : null,
          ),
          LineField(label: s.country, controller: _country, readOnly: true),
          LineDropdown<String>(
            label: s.branch,
            value: d.branch,
            hint: s.select,
            items: [for (final b in eximBranches) (b, b)],
            onChanged: (v) => setState(() => d.branch = v),
            validator: (v) => v == null ? s.requiredField : null,
          ),
        ],
      ),
    );
  }
}

/// Étape 3b : récapitulatif des informations, avec retour possible pour modifier.
class DetailsSummaryScreen extends StatelessWidget {
  const DetailsSummaryScreen({super.key, required this.draft});
  final OnboardingDraft draft;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final complete = draft.employment != null && draft.branch != null && draft.city.isNotEmpty;
    return OnboardingScaffold(
      title: s.confirmInfo,
      completedSteps: 2,
      nextLabel: s.nextAccountOpening,
      children: [
        Text(s.confirmAllCorrect, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.textSecondary)),
        const SizedBox(height: 16),
        InfoRow(label: s.annualIncome, value: formatAmount(draft.annualIncome ?? 0, 'KMF')),
        InfoRow(label: s.employmentType, value: draft.employment == null ? '' : s.employmentLabel(draft.employment!)),
        InfoRow(label: s.currentAddress, value: [draft.building, draft.street, draft.city, draft.country].join(',\n')),
        InfoRow(label: s.branch, value: draft.branch ?? ''),
        const SizedBox(height: 16),
        Center(
          child: TextButton(
            style: TextButton.styleFrom(foregroundColor: AppColors.navy),
            onPressed: () => Navigator.of(context).pop(),
            child: Text(s.editInformation, style: const TextStyle(decoration: TextDecoration.underline, fontSize: 16)),
          ),
        ),
        const SizedBox(height: 16),
        OnboardingButton(
          label: s.confirmContinue,
          onPressed: complete
              ? () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => OpenAccountFormScreen(draft: draft)))
              : null,
        ),
      ],
    );
  }
}

/// Étape finale : type de compte, devise, carte et conditions générales, puis dépôt de la demande.
class OpenAccountFormScreen extends StatefulWidget {
  const OpenAccountFormScreen({super.key, required this.draft});
  final OnboardingDraft draft;

  @override
  State<OpenAccountFormScreen> createState() => _OpenAccountFormScreenState();
}

class _OpenAccountFormScreenState extends State<OpenAccountFormScreen> {
  int? _type;
  bool? _card;
  bool _accepted = false;
  bool _sending = false;

  bool get _complete => _type != null && _card != null && _accepted;

  Future<void> _submit() async {
    final s = S.of(context);
    final auth = AppScope.of(context).session.auth;
    final navigator = Navigator.of(context);
    final d = widget.draft;
    setState(() => _sending = true);
    try {
      final ref = await auth.submitAccountApplication(
        onboardingToken: d.token,
        application: AccountApplication(
          nin: d.nin,
          phone: d.phone,
          email: d.email,
          annualIncome: d.annualIncome ?? 0,
          employment: s.employmentLabel(d.employment!),
          building: d.building,
          street: d.street,
          city: d.city,
          country: d.country,
          branch: d.branch!,
          accountType: s.accountTypeLabel(_type!),
          currency: 'KMF', // Exim Comores : comptes en KMF uniquement
          requestCard: _card!,
        ),
      );
      await OnboardingStore.save(ref);
      navigator.pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => ResultScreen(title: s.applicationSent, body: s.applicationSentBody(ref))),
        (route) => route.isFirst,
      );
    } catch (_) {
      if (mounted) showErrorSnack(context, s.genericError);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  void _showTerms() {
    final s = S.of(context);
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(s.termsTitle),
        content: Text(s.termsBody),
        actions: [TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('OK'))],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return CurvedCardScaffold(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Text(s.openAccountTitle,
                style: const TextStyle(color: AppColors.navy, fontSize: 26, fontWeight: FontWeight.w800)),
          ),
          const SizedBox(height: 8),
          Text(s.openAccountIntro, style: const TextStyle(fontSize: 15.5, height: 1.4)),
          const SizedBox(height: 12),
          LineDropdown<int>(
            label: s.accountType,
            value: _type,
            hint: s.select,
            items: [for (var i = 0; i < 3; i++) (i, s.accountTypeLabel(i))],
            onChanged: (v) => setState(() => _type = v),
          ),
          LineDropdown<bool>(
            label: s.requestForCard,
            value: _card,
            hint: s.select,
            items: [(true, s.yes), (false, s.no)],
            onChanged: (v) => setState(() => _card = v),
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Checkbox(
                value: _accepted,
                activeColor: AppColors.navy,
                onChanged: (v) => setState(() => _accepted = v ?? false),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text.rich(
                    TextSpan(children: [
                      TextSpan(text: s.acceptTermsPrefix),
                      WidgetSpan(
                        alignment: PlaceholderAlignment.baseline,
                        baseline: TextBaseline.alphabetic,
                        child: GestureDetector(
                          onTap: _showTerms,
                          child: Text(s.terms,
                              style: const TextStyle(
                                  color: AppColors.navy, decoration: TextDecoration.underline, fontWeight: FontWeight.w600)),
                        ),
                      ),
                      TextSpan(text: s.acceptTermsSuffix),
                    ]),
                    style: const TextStyle(color: AppColors.textSecondary),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          OnboardingButton(label: s.next, loading: _sending, onPressed: _complete ? _submit : null),
        ],
      ),
    );
  }
}

/// Suivi de la demande d'ouverture ; une fois le compte ouvert, propose d'activer l'accès MyExim.
class ApplicationStatusScreen extends StatefulWidget {
  const ApplicationStatusScreen({super.key, required this.reference});
  final String reference;

  @override
  State<ApplicationStatusScreen> createState() => _ApplicationStatusScreenState();
}

class _ApplicationStatusScreenState extends State<ApplicationStatusScreen> {
  Future<ApplicationStatusInfo>? _status;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _status ??= _load();
  }

  Future<ApplicationStatusInfo> _load() => AppScope.of(context).session.auth.getApplicationStatus(widget.reference);

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return OnboardingScaffold(
      title: s.applicationStatus,
      children: [
        FutureBuilder<ApplicationStatusInfo>(
          future: _status,
          builder: (context, snap) {
            if (!snap.hasData) {
              return const Padding(
                padding: EdgeInsets.all(40),
                child: Center(child: CircularProgressIndicator(color: AppColors.navy)),
              );
            }
            final info = snap.data!;
            final reached = switch (info.status) {
              ApplicationStatus.submitted => 1,
              ApplicationStatus.inReview => 2,
              ApplicationStatus.approved => 3,
              ApplicationStatus.rejected => 2,
            };
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${s.reference} : ${info.reference}', style: const TextStyle(color: AppColors.textSecondary)),
                const SizedBox(height: 20),
                for (var i = 0; i < 3; i++)
                  _StatusStep(
                    label: s.applicationStatusLabel(i),
                    done: i < reached,
                    current: i == reached - 1,
                    last: i == 2,
                  ),
                if (info.status == ApplicationStatus.rejected)
                  Text(s.applicationStatusLabel(3), style: const TextStyle(color: AppColors.danger, fontWeight: FontWeight.w700)),
                const SizedBox(height: 20),
                if (info.status == ApplicationStatus.approved) ...[
                  Text(s.accountOpened(info.accountNumber!), style: const TextStyle(fontSize: 16.5, height: 1.4)),
                  const SizedBox(height: 20),
                  OnboardingButton(
                    label: s.activateAccess,
                    onPressed: () async {
                      final navigator = Navigator.of(context);
                      await OnboardingStore.clear();
                      navigator.pushReplacement(MaterialPageRoute(
                        builder: (_) => SelfRegistrationScreen(initialAccountNumber: info.accountNumber),
                      ));
                    },
                  ),
                ] else
                  OnboardingButton(label: s.refresh, onPressed: () => setState(() => _status = _load())),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _StatusStep extends StatelessWidget {
  const _StatusStep({required this.label, required this.done, required this.current, required this.last});
  final String label;
  final bool done;
  final bool current;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final color = done ? AppColors.navy : AppColors.border;
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Column(
            children: [
              Container(
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: done ? AppColors.navy : Colors.white,
                  border: Border.all(color: color, width: 2),
                ),
                child: done ? const Icon(Icons.check, size: 16, color: Colors.white) : null,
              ),
              if (!last) Expanded(child: Container(width: 2, color: color)),
            ],
          ),
          const SizedBox(width: 14),
          Padding(
            padding: const EdgeInsets.only(top: 2, bottom: 24),
            child: Text(label,
                style: TextStyle(
                  fontSize: 16.5,
                  fontWeight: current ? FontWeight.w800 : FontWeight.w500,
                  color: done ? AppColors.textPrimary : AppColors.textMuted,
                )),
          ),
        ],
      ),
    );
  }
}

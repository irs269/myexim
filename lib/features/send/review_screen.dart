import 'package:flutter/material.dart';

import '../../core/app_scope.dart';
import '../../core/l10n/strings.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../data/bank_repository.dart' show corridorFor, flagForCountry;
import '../../data/models.dart';
import '../../shared/widgets.dart';
import '../auth/auth_widgets.dart';
import 'pin_confirm_sheet.dart';
import 'send_flow.dart';
import 'success_screen.dart';

const purposeIcons = <TransferPurpose, (IconData, Color)>{
  TransferPurpose.family: (Icons.favorite_outline, Color(0xFFE9A6B8)),
  TransferPurpose.bills: (Icons.receipt_long_outlined, Color(0xFFF2C46B)),
  TransferPurpose.rent: (Icons.home_outlined, Color(0xFF9BB8E8)),
  TransferPurpose.salary: (Icons.work_outline, Color(0xFF8FD3B6)),
  TransferPurpose.education: (Icons.school_outlined, Color(0xFFB9A5E6)),
  TransferPurpose.health: (Icons.local_hospital_outlined, Color(0xFFF0A08C)),
  TransferPurpose.business: (Icons.storefront_outlined, Color(0xFF8CC8E8)),
  TransferPurpose.savings: (Icons.savings_outlined, Color(0xFFC9D98A)),
  TransferPurpose.other: (Icons.more_horiz, Color(0xFFC5CAD3)),
};

/// Feuille de choix du motif (écran « Choose a category » de la maquette).
Future<TransferPurpose?> pickPurpose(BuildContext context, {TransferPurpose? selected}) =>
    showModalBottomSheet<TransferPurpose>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: AppColors.background,
      builder: (_) => PurposeSheet(selected: selected),
    );

/// Étape 3 : récapitulatif, motif, puis confirmation par PIN.
class ReviewScreen extends StatefulWidget {
  const ReviewScreen({super.key, required this.draft});
  final TransferDraft draft;

  @override
  State<ReviewScreen> createState() => _ReviewScreenState();
}

class _ReviewScreenState extends State<ReviewScreen> {
  final _note = TextEditingController();
  bool _sending = false;

  TransferDraft get _draft => widget.draft;

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _pickPurpose() async {
    final picked = await pickPurpose(context, selected: _draft.purpose);
    if (picked != null) setState(() => _draft.purpose = picked);
  }

  Future<void> _confirm() async {
    final s = S.of(context);
    final repo = AppScope.repo(context);
    final navigator = Navigator.of(context);
    final ok = await confirmWithPin(context);
    if (!ok || !mounted) return;

    setState(() => _sending = true);
    try {
      final tx = await repo.sendTransfer(
        from: _draft.from,
        to: _draft.to,
        quote: _draft.quote!,
        purpose: _draft.purpose ?? TransferPurpose.other,
        note: _note.text.trim().isEmpty ? null : _note.text.trim(),
      );
      // Le parcours d'envoi est refermé : seul l'écran de succès reste au-dessus de l'accueil.
      navigator.pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (_) => SuccessScreen(draft: _draft, transaction: tx),
        ),
        (route) => route.isFirst,
      );
    } on TransferException catch (e) {
      if (!mounted) return;
      showErrorSnack(context, switch (e.code) {
        TransferError.insufficientFunds => s.insufficientFunds,
        TransferError.limitExceeded => s.limitExceeded,
        TransferError.accountNotFound => s.accountNotFound,
        _ => s.genericError,
      });
    } catch (_) {
      if (mounted) showErrorSnack(context, s.genericError);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final q = _draft.quote!;
    final to = _draft.to;
    final conversion = to.isOwnAccount;
    final canConfirm = conversion || _draft.purpose != null;

    return AuthScaffold(
      title: conversion ? s.reviewConvert : s.review,
      bottom: PrimaryButton(
        label: conversion ? s.confirmConvert : s.confirmAndSend,
        loading: _sending,
        onPressed: canConfirm ? _confirm : null,
      ),
      children: [
        _Card(
          children: [
            _Line(s.youSend, formatAmount(q.sendAmount, q.sendCurrency)),
            _Line(s.ourFee, q.fee == 0 ? s.noFee : formatAmount(q.fee, q.sendCurrency)),
            _Line(s.totalDebited, formatAmount(q.totalDebited, q.sendCurrency), bold: true),
            if (q.isCrossCurrency)
              _Line(
                s.rateApplied,
                '1 ${q.sendCurrency} = ${formatRate(q.rate, q.receiveCurrency == 'KMF' ? 2 : 4, french: s.french)} ${q.receiveCurrency}',
              ),
            const Divider(height: 24),
            _Line(
              conversion ? s.youReceive : s.theyReceive,
              formatAmount(q.receiveAmount, q.receiveCurrency),
              big: true,
            ),
            _Line(
              s.arrival,
              to.isInternationalWallet
                  ? s.arrivalMinutes
                  : q.instant
                  ? s.arrivalInstant
                  : s.arrivalNextDay,
            ),
          ],
        ),
        const SizedBox(height: 16),
        _Card(
          children: [
            Row(
              children: [
                Expanded(child: Text(s.transferDetails, style: Theme.of(context).textTheme.titleMedium)),
                TextButton(
                  style: TextButton.styleFrom(foregroundColor: AppColors.navy),
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(
                    s.edit,
                    style: const TextStyle(fontWeight: FontWeight.w700, decoration: TextDecoration.underline),
                  ),
                ),
              ],
            ),
            _Line(s.from, '${_draft.from.label} · ${_draft.from.number}'),
            _Line(conversion ? s.to : s.recipient, to.name),
            if (!conversion) ...[
              if (to.isInternationalWallet) ...[
                _Line(
                  s.country,
                  '${flagForCountry(to.beneficiary!.countryCode!)} ${corridorFor(to.beneficiary!.countryCode).name(french: s.french)}',
                ),
                _Line(s.network, corridorFor(to.beneficiary!.countryCode).network!),
              ],
              _Line(to.isMobileMoney ? s.operator : s.bankName, to.bankName),
              _Line(to.isMobileMoney ? s.walletNumber : s.accountNumberLabel, to.accountNumber),
            ] else
              _Line(s.accountNumberLabel, to.accountNumber),
          ],
        ),
        if (!conversion) ...[
          const SizedBox(height: 20),
          Text(
            s.purpose,
            style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 8),
          PurposeField(purpose: _draft.purpose, onTap: _pickPurpose),
          const SizedBox(height: 18),
          TextField(
            controller: _note,
            maxLength: 80,
            decoration: InputDecoration(
              labelText: s.noteOptional,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.navy, width: 1.5),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
    decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(20)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: children),
  );
}

class _Line extends StatelessWidget {
  const _Line(this.label, this.value, {this.bold = false, this.big = false});
  final String label;
  final String value;
  final bool bold;
  final bool big;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 15)),
        ),
        const SizedBox(width: 12),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: TextStyle(fontSize: big ? 20 : 15.5, fontWeight: bold || big ? FontWeight.w800 : FontWeight.w600),
          ),
        ),
      ],
    ),
  );
}

class PurposeField extends StatelessWidget {
  const PurposeField({super.key, required this.purpose, required this.onTap});
  final TransferPurpose? purpose;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final p = purpose;
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            if (p != null) ...[PurposeIcon(p), const SizedBox(width: 12)],
            Expanded(
              child: Text(
                p == null ? s.choosePurpose : s.purposeLabel(p.index),
                style: TextStyle(fontSize: 16, color: p == null ? AppColors.textMuted : AppColors.textPrimary),
              ),
            ),
            const Icon(Icons.expand_more),
          ],
        ),
      ),
    );
  }
}

class PurposeIcon extends StatelessWidget {
  const PurposeIcon(this.purpose, {super.key});
  final TransferPurpose purpose;

  @override
  Widget build(BuildContext context) {
    final (icon, color) = purposeIcons[purpose]!;
    return CircleIcon(icon: icon, size: 36, bg: color.withValues(alpha: 0.35), fg: AppColors.navy);
  }
}

/// Liste des motifs (écran « Choose a category » de la maquette).
class PurposeSheet extends StatelessWidget {
  const PurposeSheet({super.key, this.selected});
  final TransferPurpose? selected;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return SafeArea(
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
              child: Text(s.choosePurpose, style: Theme.of(context).textTheme.headlineMedium),
            ),
            for (final p in TransferPurpose.values)
              ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 24),
                leading: PurposeIcon(p),
                title: Text(s.purposeLabel(p.index), style: const TextStyle(fontSize: 16)),
                trailing: Icon(
                  p == selected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                  color: p == selected ? AppColors.navy : AppColors.textMuted,
                ),
                onTap: () => Navigator.of(context).pop(p),
              ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }
}

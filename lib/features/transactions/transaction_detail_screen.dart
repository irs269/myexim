import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/app_scope.dart';
import '../../core/l10n/strings.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../data/models.dart';
import '../../shared/widgets.dart';
import '../send/send_flow.dart';
import 'transaction_widgets.dart';

/// Détail d'une opération, avec un suivi par étapes façon Wise.
class TransactionDetailScreen extends StatelessWidget {
  const TransactionDetailScreen({super.key, required this.tx});
  final BankTransaction tx;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final t = Theme.of(context).textTheme;
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.only(bottom: 32),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
              child: Align(
                alignment: Alignment.centerLeft,
                child: RoundIconButton(icon: Icons.arrow_back, onPressed: () => Navigator.of(context).pop()),
              ),
            ),
            const SizedBox(height: 20),
            Center(child: TransactionIcon(tx: tx, size: 76)),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                children: [
                  Text(tx.label, textAlign: TextAlign.center, style: t.titleLarge),
                  const SizedBox(height: 6),
                  Text(
                    signedAmount(tx),
                    textAlign: TextAlign.center,
                    style: t.displaySmall?.copyWith(
                      color: tx.isCredit ? AppColors.success : AppColors.textPrimary,
                      decoration: tx.status == TxStatus.failed ? TextDecoration.lineThrough : null,
                    ),
                  ),
                  const SizedBox(height: 10),
                  _StatusChip(status: tx.status),
                ],
              ),
            ),
            const SizedBox(height: 28),
            _Timeline(tx: tx),
            SectionLabel(s.details),
            _DetailRow(
              label: s.date,
              value: formatDateTime(tx.date, french: s.french),
            ),
            _DetailRow(label: s.account, value: tx.accountNumber),
            if (tx.counterpartyAccount != null) _DetailRow(label: s.counterparty, value: tx.counterpartyAccount!),
            _DetailRow(label: s.reference, value: tx.reference, copyable: true),
            if (!tx.isCredit && tx.status != TxStatus.failed) ...[
              _DetailRow(label: s.fees, value: formatAmount(tx.fee, tx.currency)),
              _DetailRow(label: s.totalDebited, value: formatAmount(tx.amount + tx.fee, tx.currency), bold: true),
            ],
            const SizedBox(height: 24),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  if (!tx.isCredit && tx.category == TxCategory.transfer && tx.counterpartyAccount != null)
                    PillButton(
                      label: s.sendAgainShort,
                      icon: Icons.replay,
                      variant: PillVariant.primary,
                      dense: true,
                      onPressed: () => _sendAgain(context, tx),
                    ),
                  PillButton(
                    label: s.shareReceipt,
                    icon: Icons.ios_share,
                    dense: true,
                    onPressed: () =>
                        SharePlus.instance.share(ShareParams(text: receiptText(s, tx), subject: s.receiptTitle)),
                  ),
                  PillButton(
                    label: s.copyReference,
                    icon: Icons.copy,
                    dense: true,
                    onPressed: () => _copy(context, tx.reference),
                  ),
                  PillButton(
                    label: s.reportProblem,
                    icon: Icons.help_outline,
                    variant: PillVariant.outline,
                    dense: true,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Reçu texte partagé par messagerie, e-mail, etc.
String receiptText(S s, BankTransaction tx) {
  final lines = [
    s.receiptTitle,
    '',
    '${tx.label} — ${tx.subtitle}',
    '${s.amount} : ${signedAmount(tx)}',
    if (!tx.isCredit && tx.fee > 0) '${s.fees} : ${formatAmount(tx.fee, tx.currency)}',
    '${s.status} : ${statusLabel(s, tx.status)}',
    '${s.date} : ${formatDateTime(tx.date, french: s.french)}',
    '${s.account} : ${tx.accountNumber}',
    if (tx.counterpartyAccount != null) '${s.counterparty} : ${tx.counterpartyAccount}',
    '${s.reference} : ${tx.reference}',
  ];
  return lines.join('\n');
}

/// Relance un envoi vers le même bénéficiaire (s'il est toujours enregistré).
Future<void> _sendAgain(BuildContext context, BankTransaction tx) async {
  final beneficiaries = await AppScope.repo(context).getBeneficiaries();
  if (!context.mounted) return;
  final match = beneficiaries.where((b) => b.accountNumber == tx.counterpartyAccount).firstOrNull;
  if (match != null) {
    await startSendTo(context, match);
  } else {
    startSendFlow(context);
  }
}

void _copy(BuildContext context, String value) {
  Clipboard.setData(ClipboardData(text: value));
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(S.of(context).copied), behavior: SnackBarBehavior.floating));
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});
  final TxStatus status;

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = switch (status) {
      TxStatus.completed => (const Color(0xFFE5F3E6), AppColors.success),
      TxStatus.pending => (AppColors.goldLight, const Color(0xFF7A5B12)),
      TxStatus.failed => (const Color(0xFFFBE4E4), AppColors.danger),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
      child: Text(
        statusLabel(S.of(context), status),
        style: TextStyle(color: fg, fontWeight: FontWeight.w700),
      ),
    );
  }
}

/// Étapes de l'opération ; la dernière étape atteinte est mise en évidence.
class _Timeline extends StatelessWidget {
  const _Timeline({required this.tx});
  final BankTransaction tx;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final steps = tx.isCredit
        ? [s.stepCreated, s.stepProcessing, s.stepCredited]
        : [s.stepCreated, s.stepDebited, s.stepProcessing, s.stepCompleted];
    final reached = switch (tx.status) {
      TxStatus.completed => steps.length,
      TxStatus.pending => steps.length - 1,
      TxStatus.failed => 1,
    };
    final failed = tx.status == TxStatus.failed;
    final labels = failed ? [steps.first, s.stepFailed] : steps;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(24)),
      child: Column(
        children: [
          for (final (i, label) in labels.indexed)
            _TimelineStep(
              label: label,
              done: failed || i < reached,
              current: !failed && i == reached - 1,
              error: failed && i == labels.length - 1,
              time: i == 0 ? formatDateTime(tx.date, french: s.french) : null,
              isLast: i == labels.length - 1,
            ),
        ],
      ),
    );
  }
}

class _TimelineStep extends StatelessWidget {
  const _TimelineStep({
    required this.label,
    required this.done,
    required this.current,
    required this.error,
    required this.isLast,
    this.time,
  });
  final String label;
  final bool done;
  final bool current;
  final bool error;
  final bool isLast;
  final String? time;

  @override
  Widget build(BuildContext context) {
    final color = error ? AppColors.danger : (done ? AppColors.navy : AppColors.border);
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Column(
            children: [
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: done ? color : Colors.white,
                  border: Border.all(color: color, width: 2),
                ),
                child: done ? Icon(error ? Icons.close : Icons.check, size: 15, color: Colors.white) : null,
              ),
              if (!isLast) Expanded(child: Container(width: 2, color: done ? AppColors.navy : AppColors.border)),
            ],
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 2, bottom: 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 15.5,
                      fontWeight: current || error ? FontWeight.w700 : FontWeight.w500,
                      color: done ? AppColors.textPrimary : AppColors.textMuted,
                    ),
                  ),
                  if (time != null) Text(time!, style: const TextStyle(fontSize: 13.5, color: AppColors.textSecondary)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value, this.copyable = false, this.bold = false});
  final String label;
  final String value;
  final bool copyable;
  final bool bold;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: copyable ? () => _copy(context, value) : null,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 15.5)),
            ),
            const SizedBox(width: 16),
            Flexible(
              child: Text(
                value,
                textAlign: TextAlign.right,
                style: TextStyle(fontSize: 15.5, fontWeight: bold ? FontWeight.w800 : FontWeight.w600),
              ),
            ),
            if (copyable) ...[
              const SizedBox(width: 6),
              const Icon(Icons.copy, size: 16, color: AppColors.textSecondary),
            ],
          ],
        ),
      ),
    );
  }
}

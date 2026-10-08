import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/app_scope.dart';
import '../../core/l10n/strings.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../data/models.dart';
import '../../shared/repo_listener.dart';
import '../../shared/widgets.dart';
import '../send/send_flow.dart';
import '../transactions/transaction_widgets.dart';

/// Fiche bénéficiaire : coordonnées, actions et historique des échanges.
class BeneficiaryDetailScreen extends StatefulWidget {
  const BeneficiaryDetailScreen({super.key, required this.beneficiary});
  final Beneficiary beneficiary;

  @override
  State<BeneficiaryDetailScreen> createState() => _BeneficiaryDetailScreenState();
}

class _BeneficiaryDetailScreenState extends State<BeneficiaryDetailScreen> with RepoListener {
  late Beneficiary _b = widget.beneficiary;
  Future<List<BankTransaction>>? _history;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _history ??= _load();
  }

  Future<List<BankTransaction>> _load() => AppScope.repo(context)
      .getTransactions(query: TransactionQuery(counterpartyAccount: _b.accountNumber), limit: 50);

  @override
  void onRepoChanged() {
    setState(() {
      _history = _load();
    });
  }

  Future<void> _rename() async {
    final repo = AppScope.repo(context);
    final name = await showDialog<String>(context: context, builder: (_) => _RenameDialog(initial: _b.name));
    if (name == null || name.isEmpty || name == _b.name) return;
    final updated = await repo.updateBeneficiary(_b.copyWith(name: name));
    if (mounted) setState(() => _b = updated);
  }

  Future<void> _delete() async {
    final s = S.of(context);
    final repo = AppScope.repo(context);
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(s.deleteRecipientTitle(_b.name)),
        content: Text(s.deleteRecipientBody),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: Text(s.cancel)),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(s.delete),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await repo.deleteBeneficiary(_b.id);
    navigator.pop();
    messenger.showSnackBar(SnackBar(content: Text(s.recipientDeleted), behavior: SnackBarBehavior.floating));
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.only(bottom: 32),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
              child: Row(
                children: [
                  RoundIconButton(icon: Icons.arrow_back, onPressed: () => Navigator.of(context).pop()),
                  const Spacer(),
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert),
                    onSelected: (v) => v == 'rename' ? _rename() : _delete(),
                    itemBuilder: (_) => [
                      PopupMenuItem(value: 'rename', child: Text(s.rename)),
                      PopupMenuItem(
                          value: 'delete', child: Text(s.delete, style: const TextStyle(color: AppColors.danger))),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Center(child: InitialsAvatar.of(_b, size: 96)),
            const SizedBox(height: 14),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(_b.name, textAlign: TextAlign.center, style: Theme.of(context).textTheme.headlineMedium),
            ),
            const SizedBox(height: 4),
            Text(_b.bankName, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.textSecondary)),
            const SizedBox(height: 20),
            Center(
              child: PillButton(
                label: s.send,
                icon: Icons.north_east,
                variant: PillVariant.primary,
                onPressed: () => startSendTo(context, _b),
              ),
            ),
            const SizedBox(height: 24),
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 24),
              decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(20)),
              child: Column(
                children: [
                  _InfoRow(
                    label: _b.isMobileMoney ? s.walletNumber : s.accountNumberLabel,
                    value: _b.accountNumber,
                    copyable: true,
                  ),
                  _InfoRow(label: _b.isMobileMoney ? s.operator : s.bankName, value: _b.bankName),
                  _InfoRow(label: s.currency, value: _b.currency),
                ],
              ),
            ),
            SectionLabel(s.historyWith),
            AsyncView(
              future: _history!,
              builder: (context, txs) {
                if (txs.isEmpty) return const EmptyTransactions();
                final sent = txs
                    .where((t) => !t.isCredit && t.status != TxStatus.failed && t.currency == _b.currency)
                    .fold<double>(0, (sum, t) => sum + t.amount);
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(24, 0, 24, 4),
                      child: Text(s.totalSent(formatAmount(sent, _b.currency)),
                          style: const TextStyle(fontWeight: FontWeight.w700)),
                    ),
                    ...groupedTransactionTiles(context, txs),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value, this.copyable = false});
  final String label;
  final String value;
  final bool copyable;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: copyable
          ? () {
              Clipboard.setData(ClipboardData(text: value));
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(S.of(context).copied), behavior: SnackBarBehavior.floating),
              );
            }
          : null,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Row(
          children: [
            Expanded(child: Text(label, style: const TextStyle(color: AppColors.textSecondary))),
            Flexible(
              child: Text(value, textAlign: TextAlign.right, style: const TextStyle(fontWeight: FontWeight.w600)),
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

/// Boîte de renommage ; elle possède son contrôleur pour qu'il vive jusqu'à la fin de l'animation de fermeture.
class _RenameDialog extends StatefulWidget {
  const _RenameDialog({required this.initial});
  final String initial;

  @override
  State<_RenameDialog> createState() => _RenameDialogState();
}

class _RenameDialogState extends State<_RenameDialog> {
  late final _controller = TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return AlertDialog(
      title: Text(s.rename),
      content: TextField(controller: _controller, autofocus: true, textCapitalization: TextCapitalization.words),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: Text(s.cancel)),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: AppColors.navy),
          onPressed: () => Navigator.of(context).pop(_controller.text.trim()),
          child: Text(s.save),
        ),
      ],
    );
  }
}

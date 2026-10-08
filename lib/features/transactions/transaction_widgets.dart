import 'package:flutter/material.dart';

import '../../core/l10n/strings.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../data/models.dart';
import '../../shared/widgets.dart';
import 'transaction_detail_screen.dart';

IconData categoryIcon(TxCategory c, TxDirection d) => switch (c) {
      TxCategory.transfer => d == TxDirection.credit ? Icons.south_west : Icons.north_east,
      TxCategory.bill => Icons.receipt_long_outlined,
      TxCategory.airtime => Icons.phone_android,
      TxCategory.card => Icons.credit_card,
      TxCategory.salary => Icons.work_outline,
      TxCategory.fee => Icons.account_balance_outlined,
      TxCategory.cash => Icons.local_atm,
      TxCategory.merchant => Icons.qr_code_2,
    };

String statusLabel(S s, TxStatus status) => switch (status) {
      TxStatus.completed => s.statusCompleted,
      TxStatus.pending => s.statusPending,
      TxStatus.failed => s.statusFailed,
    };

/// Montant signé : « + 60 000 KMF » pour une entrée, « 25 000 KMF » pour une sortie.
String signedAmount(BankTransaction tx) => '${tx.isCredit ? '+ ' : ''}${formatAmount(tx.amount, tx.currency)}';

class TransactionIcon extends StatelessWidget {
  const TransactionIcon({super.key, required this.tx, this.size = 52});
  final BankTransaction tx;
  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: size,
            height: size,
            decoration: const BoxDecoration(color: AppColors.surface, shape: BoxShape.circle),
            child: Icon(categoryIcon(tx.category, tx.direction), color: AppColors.navy, size: size * 0.45),
          ),
          if (tx.status != TxStatus.completed)
            Positioned(
              right: -2,
              bottom: -2,
              child: Container(
                width: size * 0.4,
                height: size * 0.4,
                decoration: BoxDecoration(
                  color: tx.status == TxStatus.pending ? AppColors.gold : AppColors.danger,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                ),
                child: Icon(tx.status == TxStatus.pending ? Icons.schedule : Icons.close, size: size * 0.24, color: Colors.white),
              ),
            ),
        ],
      ),
    );
  }
}

/// Ligne de transaction ; ouvre le détail au toucher.
class TransactionTile extends StatelessWidget {
  const TransactionTile({super.key, required this.tx, this.mask});
  final BankTransaction tx;
  final String Function(String)? mask;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final m = mask ?? (String v) => v;
    final subtitle = tx.status == TxStatus.completed ? tx.subtitle : '${tx.subtitle} · ${statusLabel(s, tx.status)}';
    return ListRow(
      leading: TransactionIcon(tx: tx),
      title: tx.label,
      subtitle: subtitle,
      onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => TransactionDetailScreen(tx: tx))),
      trailing: Text(
        m(signedAmount(tx)),
        style: TextStyle(
          fontWeight: FontWeight.w700,
          fontSize: 15.5,
          color: tx.status == TxStatus.failed
              ? AppColors.textMuted
              : tx.isCredit
                  ? AppColors.success
                  : AppColors.textPrimary,
          decoration: tx.status == TxStatus.failed ? TextDecoration.lineThrough : null,
        ),
      ),
    );
  }
}

/// Liste regroupée par jour, à insérer dans un ListView/Column.
List<Widget> groupedTransactionTiles(BuildContext context, List<BankTransaction> txs, {String Function(String)? mask}) {
  final s = S.of(context);
  final widgets = <Widget>[];
  DateTime? currentDay;
  for (final tx in txs) {
    final day = dayOf(tx.date);
    if (day != currentDay) {
      currentDay = day;
      widgets.add(SectionLabel(s.dayLabel(tx.date)));
    }
    widgets.add(TransactionTile(tx: tx, mask: mask));
  }
  return widgets;
}

class EmptyTransactions extends StatelessWidget {
  const EmptyTransactions({super.key});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          children: [
            const CircleIcon(icon: Icons.receipt_long_outlined, size: 72, bg: AppColors.surface, fg: AppColors.textMuted),
            const SizedBox(height: 14),
            Text(S.of(context).noTransactions, style: const TextStyle(color: AppColors.textSecondary, fontSize: 16)),
          ],
        ),
      );
}

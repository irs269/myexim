import 'package:flutter/material.dart';

import '../../core/app_scope.dart';
import '../../core/l10n/strings.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../data/models.dart';
import '../../shared/repo_listener.dart';
import '../../shared/widgets.dart';
import '../send/send_flow.dart';
import '../transactions/transaction_widgets.dart';
import '../transactions/transactions_screen.dart';
import 'account_numbers_sheet.dart';

/// Page d'un compte : solde, actions, coordonnées et dernières opérations.
class AccountDetailScreen extends StatefulWidget {
  const AccountDetailScreen({super.key, required this.account, required this.holder});
  final Account account;
  final String holder;

  @override
  State<AccountDetailScreen> createState() => _AccountDetailScreenState();
}

class _AccountDetailScreenState extends State<AccountDetailScreen> with RepoListener {
  late Account _account = widget.account;
  Future<List<BankTransaction>>? _transactions;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _transactions ??= _loadTransactions();
  }

  Future<List<BankTransaction>> _loadTransactions() =>
      AppScope.repo(context).getTransactions(query: TransactionQuery.forAccount(widget.account.number), limit: 10);

  @override
  void onRepoChanged() {
    final repo = AppScope.repo(context);
    setState(() {
      _transactions = _loadTransactions();
    });
    repo.getAccounts().then((accounts) {
      if (!mounted) return;
      setState(() => _account = accounts.firstWhere((x) => x.number == _account.number, orElse: () => _account));
    });
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final a = _account;
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
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                children: [
                  AccountIcon(account: a, size: 44),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      '${a.label} · ${a.currency}',
                      style: const TextStyle(fontSize: 17, color: AppColors.textSecondary, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(formatAmount(a.balance, a.currency), style: Theme.of(context).textTheme.displaySmall),
              ),
            ),
            const SizedBox(height: 20),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                children: [
                  PillButton(
                    label: s.send,
                    variant: PillVariant.primary,
                    onPressed: () => startSendFlow(context, from: a),
                  ),
                  const SizedBox(width: 10),
                  PillButton(label: s.addMoney),
                  const SizedBox(width: 10),
                  PillButton(
                    label: s.betweenMyAccounts,
                    onPressed: () => startOwnTransferFlow(context, from: a),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: () => showAccountNumbersSheet(context, accounts: [a], holder: widget.holder),
                child: Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(20)),
                  child: Row(
                    children: [
                      const CircleIcon(icon: Icons.account_balance_outlined, size: 48),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(s.accountNumbers, style: Theme.of(context).textTheme.titleMedium),
                            const SizedBox(height: 2),
                            Text(a.iban, style: const TextStyle(color: AppColors.textSecondary)),
                          ],
                        ),
                      ),
                      const Icon(Icons.chevron_right),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: SectionHeader(
                title: s.transactions,
                action: s.seeAll,
                onAction: () =>
                    Navigator.of(context).push(MaterialPageRoute(builder: (_) => TransactionsScreen(account: a))),
              ),
            ),
            AsyncView(
              future: _transactions!,
              builder: (context, txs) => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: txs.isEmpty ? [const EmptyTransactions()] : groupedTransactionTiles(context, txs),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

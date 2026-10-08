import 'package:flutter/material.dart';

import '../../core/app_scope.dart';
import '../../core/l10n/strings.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../data/models.dart';
import '../../shared/repo_listener.dart';
import '../../shared/widgets.dart';
import '../send/send_flow.dart';
import '../accounts/account_detail_screen.dart';
import '../auth/auth_widgets.dart' show EximMonogram;
import '../accounts/account_numbers_sheet.dart';
import '../explore/explore_screen.dart';
import '../payments/scan_screen.dart';
import '../request/request_screen.dart';
import '../transactions/transaction_widgets.dart';
import '../transactions/transactions_screen.dart';

typedef _HomeData = (Customer, List<Account>, List<DebitCard>, List<BankTransaction>);

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with RepoListener {
  Future<_HomeData>? _data;
  bool _hidden = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _data ??= _load();
  }

  Future<_HomeData> _load() async {
    final repo = AppScope.repo(context);
    final r = await Future.wait([
      repo.getCustomer(),
      repo.getAccounts(),
      repo.getCards(),
      repo.getTransactions(limit: 5),
    ]);
    return (r[0] as Customer, r[1] as List<Account>, r[2] as List<DebitCard>, r[3] as List<BankTransaction>);
  }

  Future<void> _refresh() async {
    final next = _load();
    setState(() {
      _data = next;
    });
    await next;
  }

  @override
  void onRepoChanged() => setState(() {
    _data = _load();
  });

  String _mask(String s) => _hidden ? '••••' : s;

  void _push(Widget page) => Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return AsyncView(
      future: _data!,
      builder: (context, data) {
        final (customer, accounts, cards, transactions) = data;
        final total = accounts.fold<double>(0, (sum, a) => sum + a.balance);
        return RefreshIndicator(
          color: AppColors.navy,
          onRefresh: _refresh,
          child: ListView(
            padding: const EdgeInsets.only(bottom: 24),
            children: [
              _TopBar(name: customer.fullName),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
                child: Text(
                  s.totalBalance,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: AppColors.textSecondary),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 2, 24, 0),
                child: Row(
                  children: [
                    Flexible(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          _mask(formatAmount(total, 'KMF')),
                          style: Theme.of(context).textTheme.headlineMedium,
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    RoundIconButton(
                      icon: _hidden ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                      size: 44,
                      onPressed: () => setState(() => _hidden = !_hidden),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Row(
                  children: [
                    PillButton(label: s.send, variant: PillVariant.primary, onPressed: () => startSendFlow(context)),
                    const SizedBox(width: 10),
                    PillButton(label: s.addMoney),
                    const SizedBox(width: 10),
                    PillButton(label: s.request, onPressed: () => _push(const RequestScreen())),
                  ],
                ),
              ),
              const SizedBox(height: 22),
              _AccountsCard(
                accounts: accounts,
                cardCount: cards.length,
                holder: customer.fullName,
                mask: _mask,
                onOpen: (a) => _push(AccountDetailScreen(account: a, holder: customer.fullName)),
              ),
              const SizedBox(height: 30),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: SectionHeader(
                  title: s.transactions,
                  action: s.seeAll,
                  onAction: () => _push(const TransactionsScreen()),
                ),
              ),
              if (transactions.isEmpty)
                const EmptyTransactions()
              else
                for (final tx in transactions) TransactionTile(tx: tx, mask: _mask),
            ],
          ),
        );
      },
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.name});
  final String name;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => showModalBottomSheet<void>(
              context: context,
              showDragHandle: true,
              backgroundColor: AppColors.background,
              builder: (_) => _ProfileSheet(name: name),
            ),
            child: Container(
              width: 52,
              height: 52,
              alignment: Alignment.center,
              decoration: const BoxDecoration(color: AppColors.navy, shape: BoxShape.circle),
              child: Text(
                initials(name),
                style: const TextStyle(color: AppColors.gold, fontWeight: FontWeight.w800, fontSize: 18),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: PillGroup(
              children: [
                PillButton(
                label: s.scanToPay,
                icon: Icons.qr_code_scanner,
                variant: PillVariant.primary,
                dense: true,
                onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ScanScreen())),
              ),
                PillButton(
                  label: s.more,
                  icon: Icons.add,
                  dense: true,
                  onPressed: () => Navigator.of(
                    context,
                  ).push(MaterialPageRoute(fullscreenDialog: true, builder: (_) => const ExploreScreen())),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Carte des comptes : bandeau cartes, compte principal, puis un compte par ligne.
class _AccountsCard extends StatelessWidget {
  const _AccountsCard({
    required this.accounts,
    required this.cardCount,
    required this.holder,
    required this.mask,
    required this.onOpen,
  });
  final List<Account> accounts;
  final int cardCount;
  final String holder;
  final String Function(String) mask;
  final ValueChanged<Account> onOpen;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final main = accounts.first;
    final others = accounts.skip(1).toList();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Container(
        decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(28)),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Bandeau rappelant les cartes empilées de Wise
            Container(
              margin: const EdgeInsets.fromLTRB(12, 12, 12, 0),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [AppColors.navy, Color(0xFF1F3F8A)]),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Row(
                children: [
                  Text(
                    s.cardsCount(cardCount),
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16),
                  ),
                  const Icon(Icons.chevron_right, color: Colors.white),
                  const Spacer(),
                  const EximMonogram(height: 28),
                ],
              ),
            ),
            InkWell(
              onTap: () => onOpen(main),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 22, 20, 12),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(main.label, style: Theme.of(context).textTheme.titleLarge),
                          const SizedBox(height: 4),
                          Text(
                            mask(formatAmount(main.balance, main.currency)),
                            style: const TextStyle(fontSize: 18, color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right),
                  ],
                ),
              ),
            ),
            for (final a in others)
              InkWell(
                onTap: () => onOpen(a),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                  child: Row(
                    children: [
                      AccountIcon(account: a),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          a.label,
                          style: const TextStyle(fontSize: 15.5, color: AppColors.textSecondary),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        mask(formatAmount(a.balance, a.currency)),
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                      ),
                      const Icon(Icons.chevron_right, color: AppColors.textSecondary),
                    ],
                  ),
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 22),
              child: AccountNumbersButton(accounts: accounts, holder: holder),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfileSheet extends StatelessWidget {
  const _ProfileSheet({required this.name});
  final String name;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final scope = AppScope.of(context);
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
            child: Text(name, style: Theme.of(context).textTheme.titleLarge),
          ),
          ListRow(
            leading: const CircleIcon(icon: Icons.language, size: 48),
            title: s.language,
            subtitle: scope.language.value.label,
            trailing: const Icon(Icons.swap_horiz),
            onTap: () =>
                scope.language.value = scope.language.value == AppLanguage.fr ? AppLanguage.en : AppLanguage.fr,
          ),
          ListRow(
            leading: const CircleIcon(icon: Icons.logout, size: 48, bg: AppColors.danger, fg: Colors.white),
            title: s.logout,
            onTap: () {
              Navigator.of(context).pop();
              scope.session.logout();
            },
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}

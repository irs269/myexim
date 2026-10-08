import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/app_scope.dart';
import '../../core/l10n/strings.dart';
import '../../core/theme/app_colors.dart';
import '../../data/models.dart';
import '../../shared/repo_listener.dart';
import '../../shared/widgets.dart';
import '../send/new_recipient_screen.dart';
import 'beneficiary_detail_screen.dart';

/// Onglet Bénéficiaires : récents en carrousel, puis liste alphabétique.
class BeneficiariesScreen extends StatefulWidget {
  const BeneficiariesScreen({super.key});

  @override
  State<BeneficiariesScreen> createState() => _BeneficiariesScreenState();
}

typedef _Data = (List<Beneficiary>, List<BankTransaction>, Customer);

class _BeneficiariesScreenState extends State<BeneficiariesScreen> with RepoListener {
  final _search = TextEditingController();
  Future<_Data>? _data;

  @override
  void initState() {
    super.initState();
    _search.addListener(() => setState(() {}));
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _data ??= _load();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<_Data> _load() async {
    final repo = AppScope.repo(context);
    final r = await Future.wait([
      repo.getBeneficiaries(),
      repo.getTransactions(query: const TransactionQuery(direction: TxDirection.debit), limit: 40),
      repo.getCustomer(),
    ]);
    return (r[0] as List<Beneficiary>, r[1] as List<BankTransaction>, r[2] as Customer);
  }

  @override
  void onRepoChanged() {
    setState(() {
      _data = _load();
    });
  }

  void _open(Beneficiary b) =>
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => BeneficiaryDetailScreen(beneficiary: b)));

  Future<void> _add() async {
    final s = S.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final added = await Navigator.of(context).push<Beneficiary>(
      MaterialPageRoute(builder: (_) => const NewRecipientScreen(addOnly: true)),
    );
    if (added != null) {
      messenger.showSnackBar(SnackBar(content: Text(s.recipientAdded), behavior: SnackBarBehavior.floating));
    }
  }

  void _invite(String customerName) {
    SharePlus.instance.share(ShareParams(text: S.of(context).inviteMessage(customerName), subject: 'MyExim'));
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return AsyncView(
      future: _data!,
      builder: (context, data) {
        final (beneficiaries, sent, customer) = data;
        final q = _search.text.trim().toLowerCase();
        final filtered = beneficiaries
            .where((b) => q.isEmpty || b.name.toLowerCase().contains(q) || b.accountNumber.contains(q))
            .toList()
          ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

        // Récents : bénéficiaires des derniers virements, du plus récent au plus ancien.
        final byAccount = {for (final b in beneficiaries) b.accountNumber: b};
        final recents = <Beneficiary>[];
        for (final tx in sent) {
          final b = byAccount[tx.counterpartyAccount];
          if (b != null && !recents.contains(b)) recents.add(b);
        }

        return ListView(
          padding: const EdgeInsets.only(bottom: 24),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
              child: Row(
                children: [
                  PillButton(
                    label: s.invite,
                    icon: Icons.card_giftcard,
                    variant: PillVariant.outline,
                    dense: true,
                    onPressed: () => _invite(customer.fullName),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: PillGroup(children: [
                      PillButton(label: s.add, icon: Icons.add, variant: PillVariant.primary, dense: true, onPressed: _add),
                    ]),
                  ),
                ],
              ),
            ),
            ScreenTitle(s.beneficiaries),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: TextField(
                controller: _search,
                decoration: InputDecoration(
                  filled: true,
                  fillColor: AppColors.surface,
                  hintText: s.searchBeneficiaries,
                  prefixIcon: const Padding(padding: EdgeInsets.only(left: 12), child: Icon(Icons.search)),
                  suffixIcon: _search.text.isEmpty
                      ? null
                      : IconButton(icon: const Icon(Icons.close), onPressed: _search.clear),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(40), borderSide: BorderSide.none),
                ),
              ),
            ),
            if (q.isEmpty && recents.isNotEmpty) ...[
              SectionLabel(s.recents),
              SizedBox(
                height: 128,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 6),
                  itemCount: recents.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 16),
                  itemBuilder: (_, i) {
                    final b = recents[i];
                    final parts = b.name.split(' ');
                    final short = parts.length > 1 ? '${parts.first} ${parts.last[0]}.' : parts.first;
                    return InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: () => _open(b),
                      child: SizedBox(
                        width: 80,
                        child: Column(
                          children: [
                            InitialsAvatar.of(b, size: 68),
                            const SizedBox(height: 8),
                            Text(short, textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
            if (filtered.isEmpty)
              Padding(
                padding: const EdgeInsets.all(40),
                child: Column(
                  children: [
                    const CircleIcon(icon: Icons.people_outline, size: 72, bg: AppColors.surface, fg: AppColors.textMuted),
                    const SizedBox(height: 14),
                    Text(s.noBeneficiaries, style: const TextStyle(color: AppColors.textSecondary, fontSize: 16)),
                  ],
                ),
              )
            else
              ..._alphabetical(filtered),
          ],
        );
      },
    );
  }

  /// Liste triée avec une lettre en tête de chaque groupe.
  List<Widget> _alphabetical(List<Beneficiary> sorted) {
    final widgets = <Widget>[];
    String? letter;
    for (final b in sorted) {
      final first = b.name.isEmpty ? '#' : b.name[0].toUpperCase();
      if (first != letter) {
        letter = first;
        widgets.add(SectionLabel(first));
      }
      widgets.add(ListRow(
        leading: InitialsAvatar.of(b),
        title: b.name,
        subtitle: '${b.bankName} · ${b.accountNumber}',
        onTap: () => _open(b),
      ));
    }
    return widgets;
  }
}

import 'package:flutter/material.dart';

import '../../core/app_scope.dart';
import '../../core/l10n/strings.dart';
import '../../core/theme/app_colors.dart';
import '../../data/models.dart';
import '../../shared/widgets.dart';
import 'amount_screen.dart';
import 'new_recipient_screen.dart';
import 'send_flow.dart';

/// Étape 1 : choix du bénéficiaire.
class RecipientScreen extends StatefulWidget {
  const RecipientScreen({super.key, this.from});
  final Account? from;

  @override
  State<RecipientScreen> createState() => _RecipientScreenState();
}

class _RecipientScreenState extends State<RecipientScreen> {
  final _search = TextEditingController();
  Future<(List<Beneficiary>, List<Account>)>? _data;

  @override
  void initState() {
    super.initState();
    _search.addListener(() => setState(() {}));
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final repo = AppScope.repo(context);
    _data ??= Future.wait([repo.getBeneficiaries(), repo.getAccounts()])
        .then((r) => (r[0] as List<Beneficiary>, r[1] as List<Account>));
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _choose(Beneficiary b, List<Account> accounts) {
    final from = widget.from ?? defaultSourceAccount(accounts, b.currency);
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => AmountScreen(draft: TransferDraft(from: from, to: TransferDestination.beneficiary(b))),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return Scaffold(
      body: SafeArea(
        child: AsyncView(
          future: _data!,
          builder: (context, data) {
            final (beneficiaries, accounts) = data;
            final q = _search.text.trim().toLowerCase();
            final visible = beneficiaries
                .where((b) => q.isEmpty || b.name.toLowerCase().contains(q) || b.accountNumber.contains(q))
                .toList();
            return ListView(
              padding: const EdgeInsets.only(bottom: 32),
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: RoundIconButton(icon: Icons.arrow_back, onPressed: () => Navigator.of(context).pop()),
                  ),
                ),
                ScreenTitle(s.whoToSend),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: TextField(
                    controller: _search,
                    decoration: InputDecoration(
                      hintText: s.searchRecipient,
                      prefixIcon: const Padding(padding: EdgeInsets.only(left: 12), child: Icon(Icons.search)),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                ListRow(
                  leading: const CircleIcon(icon: Icons.person_add_alt_1, size: 56, bg: AppColors.primarySoft, fg: AppColors.navy),
                  title: s.newRecipient,
                  subtitle: s.newRecipientSub,
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => NewRecipientScreen(from: widget.from))),
                ),
                SectionLabel(s.allRecipients),
                for (final b in visible)
                  ListRow(
                    leading: InitialsAvatar.of(b),
                    title: b.name,
                    subtitle: '${b.bankName} · ${b.accountNumber}',
                    onTap: () => _choose(b, accounts),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

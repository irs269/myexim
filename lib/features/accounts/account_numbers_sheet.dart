import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/l10n/strings.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../data/models.dart';
import '../../shared/widgets.dart';

/// Coordonnées bancaires d'un ou plusieurs comptes, copiables champ par champ.
Future<void> showAccountNumbersSheet(BuildContext context, {required List<Account> accounts, required String holder}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: AppColors.background,
    builder: (_) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: accounts.length > 1 ? 0.85 : 0.6,
      maxChildSize: 0.95,
      builder: (context, controller) => _AccountNumbers(accounts: accounts, holder: holder, controller: controller),
    ),
  );
}

class _AccountNumbers extends StatelessWidget {
  const _AccountNumbers({required this.accounts, required this.holder, required this.controller});
  final List<Account> accounts;
  final String holder;
  final ScrollController controller;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return ListView(
      controller: controller,
      padding: const EdgeInsets.only(bottom: 32),
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Text(s.accountNumbers, style: Theme.of(context).textTheme.headlineMedium),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 8),
          child: Text(s.accountNumbersBody, style: const TextStyle(color: AppColors.textSecondary, fontSize: 15.5)),
        ),
        for (final a in accounts) _AccountBlock(account: a, holder: holder),
      ],
    );
  }
}

class _AccountBlock extends StatelessWidget {
  const _AccountBlock({required this.account, required this.holder});
  final Account account;
  final String holder;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final fields = [
      (s.accountHolder, account.holderName ?? holder),
      (s.accountNumberLabel, account.number),
      (s.iban, account.iban),
      (s.bic, account.bic),
      (s.bankName, 'Exim Bank Comores'),
      (s.branch, account.branch),
    ];
    return Container(
      margin: const EdgeInsets.fromLTRB(24, 12, 24, 4),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(24)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 12, 6),
            child: Row(
              children: [
                Text(currencyFlag(account.currency), style: const TextStyle(fontSize: 26)),
                const SizedBox(width: 10),
                Expanded(child: Text(account.label, style: Theme.of(context).textTheme.titleMedium)),
                TextButton.icon(
                  style: TextButton.styleFrom(foregroundColor: AppColors.navy),
                  icon: const Icon(Icons.copy_all, size: 18),
                  label: Text(s.copyAll, style: const TextStyle(fontWeight: FontWeight.w700)),
                  onPressed: () => _copy(context, fields.map((f) => '${f.$1} : ${f.$2}').join('\n')),
                ),
              ],
            ),
          ),
          for (final (label, value) in fields)
            InkWell(
              onTap: () => _copy(context, value),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13.5)),
                          const SizedBox(height: 2),
                          Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                    const Icon(Icons.copy, size: 18, color: AppColors.textSecondary),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 10),
        ],
      ),
    );
  }
}

void _copy(BuildContext context, String value) {
  Clipboard.setData(ClipboardData(text: value));
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(S.of(context).copied), behavior: SnackBarBehavior.floating));
}

/// Raccourci réutilisé par l'accueil et le détail de compte.
class AccountNumbersButton extends StatelessWidget {
  const AccountNumbersButton({super.key, required this.accounts, required this.holder});
  final List<Account> accounts;
  final String holder;

  @override
  Widget build(BuildContext context) => PillButton(
        label: S.of(context).accountNumbers,
        icon: Icons.account_balance_outlined,
        dense: true,
        onPressed: () => showAccountNumbersSheet(context, accounts: accounts, holder: holder),
      );
}

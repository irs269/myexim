import 'package:flutter/material.dart';

import '../../core/app_scope.dart';
import '../../core/l10n/strings.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../data/models.dart';
import '../../shared/widgets.dart';
import 'amount_screen.dart';
import 'recipient_screen.dart';

/// Envoi en cours de préparation, transmis d'un écran à l'autre.
class TransferDraft {
  TransferDraft({required this.from, required this.to});
  Account from;
  TransferDestination to;
  TransferQuote? quote;
  TransferPurpose? purpose;
  String note = '';
}

/// « Envoyer » : choix du bénéficiaire, puis montant.
void startSendFlow(BuildContext context, {Account? from}) {
  Navigator.of(context).push(MaterialPageRoute(builder: (_) => RecipientScreen(from: from)));
}

/// Envoi direct à un bénéficiaire connu (depuis l'onglet Bénéficiaires).
Future<void> startSendTo(BuildContext context, Beneficiary beneficiary) async {
  final accounts = await AppScope.repo(context).getAccounts();
  if (!context.mounted) return;
  final from = defaultSourceAccount(accounts, beneficiary.currency);
  Navigator.of(context).push(MaterialPageRoute(
    builder: (_) => AmountScreen(draft: TransferDraft(from: from, to: TransferDestination.beneficiary(beneficiary))),
  ));
}

/// « Entre mes comptes » : virement d'un compte du client vers un autre de ses comptes.
Future<void> startOwnTransferFlow(BuildContext context, {Account? from}) async {
  final accounts = await AppScope.repo(context).getAccounts();
  if (!context.mounted) return;
  final source = from == null ? accounts.first : accounts.firstWhere((a) => a.number == from.number, orElse: () => from);
  final target = accounts.firstWhere((a) => a.number != source.number, orElse: () => accounts.last);
  Navigator.of(context).push(MaterialPageRoute(
    builder: (_) => AmountScreen(draft: TransferDraft(from: source, to: TransferDestination.ownAccount(target))),
  ));
}

/// Compte débité par défaut : le premier compte courant dans la devise visée, sinon le premier compte.
Account defaultSourceAccount(List<Account> accounts, String currency) {
  return accounts.firstWhere(
    (a) => a.currency == currency && a.type == AccountType.current,
    orElse: () => accounts.firstWhere((a) => a.currency == currency, orElse: () => accounts.first),
  );
}

/// « 25 000,50 » → 25000.5 ; renvoie null si la saisie est vide ou invalide.
double? parseAmount(String text) {
  final cleaned = text.replaceAll(RegExp(r'[\s  ]'), '').replaceAll(',', '.');
  if (cleaned.isEmpty) return null;
  return double.tryParse(cleaned);
}

/// Feuille de choix d'un compte (débit ou crédit).
Future<Account?> pickAccount(BuildContext context, {required List<Account> accounts, String? title, Account? selected}) {
  final s = S.of(context);
  return showModalBottomSheet<Account>(
    context: context,
    showDragHandle: true,
    backgroundColor: AppColors.background,
    builder: (context) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
            child: Text(title ?? s.chooseAccount, style: Theme.of(context).textTheme.titleLarge),
          ),
          for (final a in accounts)
            ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
              leading: AccountIcon(account: a),
              title: Text(a.label, style: const TextStyle(fontWeight: FontWeight.w700)),
              subtitle: Text(formatAmount(a.balance, a.currency)),
              trailing: a.number == selected?.number ? const Icon(Icons.check_circle, color: AppColors.navy) : null,
              onTap: () => Navigator.of(context).pop(a),
            ),
          const SizedBox(height: 12),
        ],
      ),
    ),
  );
}

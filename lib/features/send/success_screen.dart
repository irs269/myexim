import 'package:flutter/material.dart';

import '../../core/l10n/strings.dart';
import '../../core/utils/formatters.dart';
import '../../data/models.dart';
import '../../shared/result_screen.dart';
import 'send_flow.dart';

/// Étape finale de l'envoi : confirmation visuelle.
class SuccessScreen extends StatelessWidget {
  const SuccessScreen({super.key, required this.draft, required this.transaction});
  final TransferDraft draft;
  final BankTransaction transaction;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final q = draft.quote!;
    final to = draft.to;
    final pending = transaction.status == TxStatus.pending;
    final sent = formatAmount(q.receiveAmount, q.receiveCurrency);

    return ResultScreen(
      title: to.isOwnAccount || !pending ? s.transferDone : s.transferSent,
      body: to.isOwnAccount
          ? s.ownTransferBody(sent, to.name)
          : pending
              ? s.transferPendingBody(sent, to.name)
              : s.transferSentBody(sent, to.name),
      reference: transaction.reference,
      pending: pending,
      transaction: transaction,
    );
  }
}

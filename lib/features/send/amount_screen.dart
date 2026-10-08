import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/app_scope.dart';
import '../../core/l10n/strings.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../data/bank_repository.dart' show flagForCountry;
import '../../data/models.dart';
import '../../shared/widgets.dart';
import '../auth/auth_widgets.dart';
import 'review_screen.dart';
import 'send_flow.dart';

/// Étape 2 : montant. On peut saisir ce qu'on envoie ou ce que le bénéficiaire reçoit ;
/// l'autre montant, les frais et le taux viennent du devis (recalculé à chaque saisie).
class AmountScreen extends StatefulWidget {
  const AmountScreen({super.key, required this.draft, this.initialAmount});
  final TransferDraft draft;

  /// Montant pré-rempli côté envoi (ex. QR code avec montant demandé).
  final double? initialAmount;

  @override
  State<AmountScreen> createState() => _AmountScreenState();
}

class _AmountScreenState extends State<AmountScreen> {
  final _send = TextEditingController();
  final _receive = TextEditingController();
  final _sendFocus = FocusNode();
  final _receiveFocus = FocusNode();

  TransferQuote? _quote;
  bool _quoting = false;
  bool _syncing = false;
  int _requestId = 0;
  Timer? _debounce;
  List<Account> _accounts = const [];

  TransferDraft get _draft => widget.draft;

  @override
  void initState() {
    super.initState();
    _send.addListener(() => _onEdited(AmountSide.send));
    _receive.addListener(() => _onEdited(AmountSide.receive));
    if (widget.initialAmount != null) {
      _send.text = formatAmount(widget.initialAmount!, widget.draft.from.currency, withCode: false);
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_accounts.isEmpty) {
      AppScope.repo(context).getAccounts().then((a) {
        if (!mounted) return;
        setState(() {
          _accounts = a;
          // Solde à jour du compte débité.
          _draft.from = a.firstWhere((x) => x.number == _draft.from.number, orElse: () => _draft.from);
        });
      });
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _send.dispose();
    _receive.dispose();
    _sendFocus.dispose();
    _receiveFocus.dispose();
    super.dispose();
  }

  void _onEdited(AmountSide side) {
    if (_syncing) return;
    _debounce?.cancel();
    final amount = parseAmount(side == AmountSide.send ? _send.text : _receive.text);
    if (amount == null || amount <= 0) {
      _setOther(side, '');
      setState(() => _quote = null);
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 300), () => _requestQuote(amount, side));
  }

  Future<void> _requestQuote(double amount, AmountSide side) async {
    final id = ++_requestId;
    setState(() => _quoting = true);
    try {
      final q = await AppScope.repo(context).getQuote(from: _draft.from, to: _draft.to, amount: amount, side: side);
      if (!mounted || id != _requestId) return; // réponse périmée
      setState(() => _quote = q);
      _setOther(
        side,
        side == AmountSide.send
            ? formatAmount(q.receiveAmount, q.receiveCurrency, withCode: false)
            : formatAmount(q.sendAmount, q.sendCurrency, withCode: false),
      );
    } finally {
      if (mounted && id == _requestId) setState(() => _quoting = false);
    }
  }

  void _setOther(AmountSide editedSide, String text) {
    final other = editedSide == AmountSide.send ? _receive : _send;
    _syncing = true;
    other.text = text;
    _syncing = false;
  }

  /// Après changement de compte, on refait le devis à partir du montant envoyé.
  void _requote() {
    final amount = parseAmount(_send.text);
    setState(() => _quote = null);
    if (amount != null && amount > 0) _requestQuote(amount, AmountSide.send);
  }

  Future<void> _pickSource() async {
    final options = _draft.to.isOwnAccount
        ? _accounts.where((a) => a.number != _draft.to.accountNumber).toList()
        : _accounts;
    final picked = await pickAccount(context, accounts: options, title: S.of(context).from, selected: _draft.from);
    if (picked == null) return;
    setState(() => _draft.from = picked);
    _requote();
  }

  Future<void> _pickTarget() async {
    final options = _accounts.where((a) => a.number != _draft.from.number).toList();
    final picked = await pickAccount(
      context,
      accounts: options,
      title: S.of(context).to,
      selected: _draft.to.ownAccount,
    );
    if (picked == null) return;
    setState(() => _draft.to = TransferDestination.ownAccount(picked));
    _requote();
  }

  String? _error(S s) {
    final q = _quote;
    if (q == null) return null;
    if (q.totalDebited > _draft.from.balance) return s.insufficientFunds;
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final conversion = _draft.to.isOwnAccount;
    final error = _error(s);
    final q = _quote;
    final canContinue = q != null && error == null && !_quoting && q.sendAmount > 0;

    return AuthScaffold(
      title: conversion ? s.howMuchConvert : s.howMuch,
      bottom: PrimaryButton(
        label: s.continueLabel,
        onPressed: canContinue
            ? () {
                _draft.quote = q;
                Navigator.of(context).push(MaterialPageRoute(builder: (_) => ReviewScreen(draft: _draft)));
              }
            : null,
      ),
      children: [
        if (!conversion) _RecipientChip(destination: _draft.to),
        _AmountBox(
          label: s.youSend,
          controller: _send,
          focusNode: _sendFocus,
          account: _draft.from,
          onPickAccount: _accounts.isEmpty ? null : _pickSource,
          error: error,
          autofocus: true,
        ),
        Padding(
          padding: const EdgeInsets.only(top: 8, left: 4),
          child: Text(
            s.balanceAvailable(formatAmount(_draft.from.balance, _draft.from.currency)),
            style: const TextStyle(color: AppColors.textSecondary, fontSize: 14),
          ),
        ),
        _Breakdown(quote: q, loading: _quoting),
        _AmountBox(
          label: conversion ? s.youReceive : s.theyReceive,
          controller: _receive,
          focusNode: _receiveFocus,
          account: _draft.to.ownAccount,
          currency: _draft.to.currency,
          flag: _draft.to.isInternationalWallet ? flagForCountry(_draft.to.beneficiary!.countryCode!) : null,
          onPickAccount: conversion && _accounts.isNotEmpty ? _pickTarget : null,
        ),
        if (q != null)
          Padding(
            padding: const EdgeInsets.only(top: 16, left: 4),
            child: Row(
              children: [
                Icon(q.instant ? Icons.bolt : Icons.schedule, size: 18, color: AppColors.navy),
                const SizedBox(width: 6),
                Text('${s.arrival} : ', style: const TextStyle(color: AppColors.textSecondary)),
                Flexible(
                  child: Text(
                    _draft.to.isInternationalWallet
                        ? s.arrivalMinutes
                        : q.instant
                        ? s.arrivalInstant
                        : s.arrivalNextDay,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _RecipientChip extends StatelessWidget {
  const _RecipientChip({required this.destination});
  final TransferDestination destination;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 20),
    child: Row(
      children: [
        destination.beneficiary != null
            ? InitialsAvatar.of(destination.beneficiary!, size: 40)
            : InitialsAvatar(name: destination.name, size: 40, badge: true),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            destination.name,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    ),
  );
}

/// Champ de montant façon Wise : libellé, grand chiffre, puce de devise à droite.
class _AmountBox extends StatelessWidget {
  const _AmountBox({
    required this.label,
    required this.controller,
    required this.focusNode,
    this.account,
    this.currency,
    this.flag,
    this.onPickAccount,
    this.error,
    this.autofocus = false,
  });
  final String label;
  final TextEditingController controller;
  final FocusNode focusNode;
  final Account? account;
  final String? currency;

  /// Drapeau affiché à la place de celui de la devise (pays du portefeuille).
  final String? flag;
  final VoidCallback? onPickAccount;
  final String? error;
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    final ccy = account?.currency ?? currency!;
    final borderColor = error != null ? AppColors.danger : AppColors.border;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.textSecondary),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.fromLTRB(18, 6, 8, 6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: borderColor, width: error != null ? 1.5 : 1),
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: controller,
                  focusNode: focusNode,
                  autofocus: autofocus,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9,.\s ]'))],
                  style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800),
                  decoration: const InputDecoration(
                    hintText: '0',
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ),
              Material(
                color: AppColors.surface,
                shape: const StadiumBorder(),
                child: InkWell(
                  customBorder: const StadiumBorder(),
                  onTap: onPickAccount,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(flag ?? currencyFlag(ccy), style: const TextStyle(fontSize: 20)),
                        const SizedBox(width: 6),
                        Text(ccy, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                        if (onPickAccount != null) const Icon(Icons.expand_more, size: 20),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        if (account != null)
          Padding(
            padding: const EdgeInsets.only(top: 6, left: 4),
            child: Text(account!.label, style: const TextStyle(color: AppColors.textMuted, fontSize: 13)),
          ),
        if (error != null)
          Padding(
            padding: const EdgeInsets.only(top: 6, left: 4),
            child: Text(
              error!,
              style: const TextStyle(color: AppColors.danger, fontWeight: FontWeight.w600),
            ),
          ),
      ],
    );
  }
}

/// Décomposition du devis entre les deux montants : frais, montant converti, taux.
class _Breakdown extends StatelessWidget {
  const _Breakdown({required this.quote, required this.loading});
  final TransferQuote? quote;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final q = quote;
    Widget line(String symbol, String value, String label) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Container(
            width: 22,
            height: 22,
            alignment: Alignment.center,
            decoration: const BoxDecoration(color: AppColors.surfaceAlt, shape: BoxShape.circle),
            child: Text(symbol, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
          ),
          const SizedBox(width: 12),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(width: 6),
          Expanded(
            child: Text(label, style: const TextStyle(color: AppColors.textSecondary)),
          ),
        ],
      ),
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 14, 0, 14),
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 200),
        child: q == null
            ? SizedBox(
                key: const ValueKey('empty'),
                height: 40,
                child: loading
                    ? const Align(
                        alignment: Alignment.centerLeft,
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.navy),
                        ),
                      )
                    : null,
              )
            : Column(
                key: ValueKey(q),
                children: [
                  line('–', q.fee == 0 ? s.noFee : formatAmount(q.fee, q.sendCurrency), s.ourFee),
                  if (q.isCrossCurrency) ...[
                    line('=', formatAmount(q.sendAmount, q.sendCurrency), s.amountConverted),
                    line('×', formatRate(q.rate, q.receiveCurrency == 'KMF' ? 2 : 4, french: s.french), s.rateApplied),
                  ],
                ],
              ),
      ),
    );
  }
}

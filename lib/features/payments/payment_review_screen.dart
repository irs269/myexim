import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/app_scope.dart';
import '../../core/l10n/strings.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../data/models.dart';
import '../../shared/result_screen.dart';
import '../../shared/widgets.dart';
import '../auth/auth_widgets.dart';
import '../send/pin_confirm_sheet.dart';
import '../send/send_flow.dart';
import 'billers_screen.dart' show billerIcon;

/// Récapitulatif d'un paiement (facture, recharge, commerçant), choix du montant
/// si nécessaire, du compte débité, puis confirmation par PIN.
class PaymentReviewScreen extends StatefulWidget {
  const PaymentReviewScreen({super.key, required this.request, this.suggestedAmounts = const [], this.category});
  final PaymentRequest request;

  /// Montants proposés en pastilles (recharges).
  final List<double> suggestedAmounts;
  final BillerCategory? category;

  @override
  State<PaymentReviewScreen> createState() => _PaymentReviewScreenState();
}

class _PaymentReviewScreenState extends State<PaymentReviewScreen> {
  final _amount = TextEditingController();
  List<Account> _accounts = const [];
  Account? _from;
  bool _paying = false;

  PaymentRequest get _req => widget.request;

  @override
  void initState() {
    super.initState();
    _amount.addListener(() => setState(() {}));
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_accounts.isEmpty) {
      AppScope.repo(context).getAccounts().then((a) {
        if (!mounted) return;
        setState(() {
          _accounts = a.where((x) => x.currency == _req.currency).toList();
          _from = _accounts.isEmpty ? null : defaultSourceAccount(_accounts, _req.currency);
        });
      });
    }
  }

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  double? get _value => _req.amount ?? parseAmount(_amount.text);

  String? _error(S s) {
    final v = _value;
    if (_from == null && _accounts.isEmpty) return s.onlyKmf;
    if (v == null || _from == null) return null;
    if (v > _from!.balance) return s.insufficientFunds;
    return null;
  }

  Future<void> _pickAccount() async {
    final picked = await pickAccount(context, accounts: _accounts, title: S.of(context).payWith, selected: _from);
    if (picked != null) setState(() => _from = picked);
  }

  Future<void> _pay() async {
    final s = S.of(context);
    final repo = AppScope.repo(context);
    final navigator = Navigator.of(context);
    final ok = await confirmWithPin(context);
    if (!ok || !mounted) return;
    setState(() => _paying = true);
    try {
      final amount = _value!;
      final tx = await repo.pay(request: _req, from: _from!, amount: amount);
      navigator.pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (_) => ResultScreen(
            title: s.paymentDone,
            body: s.paymentBody(formatAmount(amount, _req.currency), _req.payeeName),
            reference: tx.reference,
            transaction: tx,
          ),
        ),
        (route) => route.isFirst,
      );
    } on TransferException catch (e) {
      if (mounted) {
        showErrorSnack(context, e.code == TransferError.insufficientFunds ? s.insufficientFunds : s.genericError);
      }
    } catch (_) {
      if (mounted) showErrorSnack(context, s.genericError);
    } finally {
      if (mounted) setState(() => _paying = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final error = _error(s);
    final value = _value;
    final canPay = _from != null && value != null && value > 0 && error == null;

    return AuthScaffold(
      title: s.payTitle,
      bottom: PrimaryButton(label: s.confirmPayment, loading: _paying, onPressed: canPay ? _pay : null),
      children: [
        Row(
          children: [
            CircleIcon(
              icon: widget.category != null
                  ? billerIcon(widget.category!)
                  : (_req.kind == PaymentKind.merchant ? Icons.storefront_outlined : Icons.receipt_long_outlined),
              size: 52,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_req.payeeName, style: Theme.of(context).textTheme.titleLarge),
                  Text(_req.reference, style: const TextStyle(color: AppColors.textSecondary)),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        if (_req.holderName != null || _req.dueDate != null || _req.description != null)
          Container(
            margin: const EdgeInsets.only(bottom: 20),
            padding: const EdgeInsets.fromLTRB(18, 10, 18, 10),
            decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(20)),
            child: Column(
              children: [
                if (_req.holderName != null) _Line(s.holder, _req.holderName!),
                if (_req.description != null) _Line(s.object, _req.description!),
                if (_req.dueDate != null) _Line(s.dueDate, formatDate(_req.dueDate!, french: s.french)),
              ],
            ),
          ),
        Text(s.amountToPay, style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
        const SizedBox(height: 8),
        if (_req.amountFixed)
          Text(formatAmount(_req.amount!, _req.currency), style: Theme.of(context).textTheme.displaySmall)
        else ...[
          if (widget.suggestedAmounts.isNotEmpty) ...[
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final a in widget.suggestedAmounts)
                  PillButton(
                    label: formatAmount(a, _req.currency),
                    dense: true,
                    variant: parseAmount(_amount.text) == a ? PillVariant.primary : PillVariant.outline,
                    onPressed: () => _amount.text = formatAmount(a, _req.currency, withCode: false),
                  ),
              ],
            ),
            const SizedBox(height: 12),
          ],
          TextField(
            controller: _amount,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9,.\s ]'))],
            style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800),
            decoration: InputDecoration(
              hintText: widget.suggestedAmounts.isEmpty ? '0' : s.otherAmount,
              suffixText: _req.currency,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
              enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: AppColors.border)),
              focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: AppColors.navy, width: 1.5)),
            ),
          ),
        ],
        if (error != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(error, style: const TextStyle(color: AppColors.danger, fontWeight: FontWeight.w600)),
          ),
        const SizedBox(height: 24),
        Text(s.payWith, style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
        const SizedBox(height: 8),
        if (_from != null)
          Material(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: _accounts.length > 1 ? _pickAccount : null,
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    Text(currencyFlag(_from!.currency), style: const TextStyle(fontSize: 26)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(_from!.label, style: const TextStyle(fontWeight: FontWeight.w700)),
                          Text(formatAmount(_from!.balance, _from!.currency),
                              style: const TextStyle(color: AppColors.textSecondary)),
                        ],
                      ),
                    ),
                    if (_accounts.length > 1) const Icon(Icons.expand_more),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _Line extends StatelessWidget {
  const _Line(this.label, this.value);
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: Text(label, style: const TextStyle(color: AppColors.textSecondary))),
            const SizedBox(width: 12),
            Flexible(child: Text(value, textAlign: TextAlign.right, style: const TextStyle(fontWeight: FontWeight.w600))),
          ],
        ),
      );
}

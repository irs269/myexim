import 'package:flutter/material.dart';

import '../../core/app_scope.dart';
import '../../core/l10n/strings.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../data/models.dart';
import '../../shared/result_screen.dart';
import '../auth/auth_widgets.dart';
import '../send/pin_confirm_sheet.dart';
import '../send/send_flow.dart';

const _branches = ['Moroni', 'Mutsamudu', 'Fomboni', 'Mitsamiouli', 'Foumbouni'];

/// Commande d'une carte : type, compte associé, agence de retrait.
class RequestCardScreen extends StatefulWidget {
  const RequestCardScreen({super.key});

  @override
  State<RequestCardScreen> createState() => _RequestCardScreenState();
}

class _RequestCardScreenState extends State<RequestCardScreen> {
  String _product = 'Visa Silver';
  String _branch = _branches.first;
  List<Account> _accounts = const [];
  Account? _account;
  bool _sending = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_accounts.isEmpty) {
      AppScope.repo(context).getAccounts().then((a) {
        if (mounted) {
          setState(() {
            _accounts = a;
            _account = a.first;
          });
        }
      });
    }
  }

  Future<void> _submit() async {
    final s = S.of(context);
    final repo = AppScope.repo(context);
    final navigator = Navigator.of(context);
    if (!await confirmWithPin(context)) return;
    setState(() => _sending = true);
    try {
      final ref = await repo.requestCard(product: _product, accountNumber: _account!.number, branch: _branch);
      navigator.pushReplacement(MaterialPageRoute(
        builder: (_) => ResultScreen(title: s.cardRequested, body: s.cardRequestedBody(ref)),
      ));
    } catch (_) {
      if (mounted) showErrorSnack(context, s.genericError);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return AuthScaffold(
      title: s.requestCard,
      bottom: PrimaryButton(label: s.submitRequest, loading: _sending, onPressed: _account == null ? null : _submit),
      children: [
        Text(s.chooseCardType, style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
        const SizedBox(height: 10),
        for (final (product, body) in [('Visa Silver', s.visaClassicBody), ('Visa Gold', s.visaGoldBody)])
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Material(
              color: _product == product ? AppColors.primarySoft : AppColors.surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
                side: BorderSide(color: _product == product ? AppColors.navy : Colors.transparent, width: 1.5),
              ),
              child: InkWell(
                borderRadius: BorderRadius.circular(18),
                onTap: () => setState(() => _product = product),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Container(
                        width: 56,
                        height: 36,
                        clipBehavior: Clip.antiAlias,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(6),
                          image: product.contains('Silver')
                              ? const DecorationImage(image: AssetImage('assets/images/card_silver.jpg'), fit: BoxFit.cover)
                              : null,
                          gradient: product.contains('Silver')
                              ? null
                              : const LinearGradient(colors: [Color(0xFFB8913E), Color(0xFFD9B66A)]),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(product, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                            Text(body, style: const TextStyle(color: AppColors.textSecondary)),
                          ],
                        ),
                      ),
                      Icon(
                        _product == product ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                        color: _product == product ? AppColors.navy : AppColors.textMuted,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        const SizedBox(height: 14),
        Text(s.linkedAccount, style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
        const SizedBox(height: 8),
        if (_account != null)
          Material(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () async {
                final picked = await pickAccount(context, accounts: _accounts, selected: _account);
                if (picked != null) setState(() => _account = picked);
              },
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    Text(currencyFlag(_account!.currency), style: const TextStyle(fontSize: 24)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text('${_account!.label} · ${_account!.number}',
                          style: const TextStyle(fontWeight: FontWeight.w700)),
                    ),
                    const Icon(Icons.expand_more),
                  ],
                ),
              ),
            ),
          ),
        const SizedBox(height: 18),
        Text(s.pickupBranch, style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          initialValue: _branch,
          items: [for (final b in _branches) DropdownMenuItem(value: b, child: Text(b))],
          onChanged: (v) => setState(() => _branch = v ?? _branch),
          decoration: InputDecoration(
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            enabledBorder:
                OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.border)),
          ),
        ),
      ],
    );
  }
}

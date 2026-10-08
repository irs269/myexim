import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/app_scope.dart';
import '../../core/l10n/strings.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../data/models.dart';
import '../../shared/widgets.dart';
import '../send/send_flow.dart';
import 'qr_payload.dart';

/// QR code personnel : un autre client Exim le scanne pour vous envoyer de l'argent.
class MyQrScreen extends StatefulWidget {
  const MyQrScreen({super.key});

  @override
  State<MyQrScreen> createState() => _MyQrScreenState();
}

class _MyQrScreenState extends State<MyQrScreen> {
  final _amount = TextEditingController();
  Future<(Customer, List<Account>)>? _data;
  Account? _account;

  @override
  void initState() {
    super.initState();
    _amount.addListener(() => setState(() {}));
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final repo = AppScope.repo(context);
    _data ??= Future.wait([repo.getCustomer(), repo.getAccounts()]).then((r) => (r[0] as Customer, r[1] as List<Account>));
  }

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return Scaffold(
      body: SafeArea(
        child: AsyncView(
          future: _data!,
          builder: (context, data) {
            final (customer, accounts) = data;
            final account = _account ?? accounts.first;
            final amount = parseAmount(_amount.text);
            final payload = QrPayload(
              type: QrType.person,
              id: account.number,
              name: customer.fullName,
              amount: amount != null && amount > 0 ? amount : null,
              currency: account.currency,
            );
            final code = payload.encode();
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
                ScreenTitle(s.myQr),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Text(s.myQrBody, style: const TextStyle(color: AppColors.textSecondary, fontSize: 16)),
                ),
                const SizedBox(height: 24),
                Center(
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(28),
                      border: Border.all(color: AppColors.gold, width: 3),
                      boxShadow: const [BoxShadow(color: Color(0x22000000), blurRadius: 18, offset: Offset(0, 6))],
                    ),
                    child: QrImageView(
                      data: code,
                      size: 230,
                      eyeStyle: const QrEyeStyle(eyeShape: QrEyeShape.square, color: AppColors.navy),
                      dataModuleStyle: const QrDataModuleStyle(dataModuleShape: QrDataModuleShape.square, color: AppColors.navy),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(customer.fullName, textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleLarge),
                Text('${account.label} · ${account.number}',
                    textAlign: TextAlign.center, style: const TextStyle(color: AppColors.textSecondary)),
                if (payload.amount != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(formatAmount(payload.amount!, account.currency),
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.navy)),
                  ),
                const SizedBox(height: 20),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    children: [
                      Material(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(16),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(16),
                          onTap: () async {
                            final picked = await pickAccount(context, accounts: accounts, selected: account);
                            if (picked != null) setState(() => _account = picked);
                          },
                          child: Padding(
                            padding: const EdgeInsets.all(14),
                            child: Row(
                              children: [
                                Text(currencyFlag(account.currency), style: const TextStyle(fontSize: 24)),
                                const SizedBox(width: 12),
                                Expanded(child: Text(account.label, style: const TextStyle(fontWeight: FontWeight.w700))),
                                const Icon(Icons.expand_more),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _amount,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9,.\s ]'))],
                        decoration: InputDecoration(
                          labelText: s.qrAmountOptional,
                          suffixText: account.currency,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.border)),
                        ),
                      ),
                      const SizedBox(height: 16),
                      PillButton(
                        label: s.qrShare,
                        icon: Icons.ios_share,
                        onPressed: () => SharePlus.instance.share(ShareParams(text: code, subject: s.myQr)),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

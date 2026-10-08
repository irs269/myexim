import 'package:flutter/material.dart';

import '../../core/l10n/strings.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/widgets.dart';
import '../scheduled/scheduled_screen.dart';
import '../request/request_screen.dart';
import '../send/new_recipient_screen.dart';
import '../send/send_flow.dart';
import 'billers_screen.dart';
import 'my_qr_screen.dart';
import 'scan_screen.dart';

/// Onglet Paiements : envois, Scan to Pay, factures, recharges et paiements programmés.
class PaymentsScreen extends StatelessWidget {
  const PaymentsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    void push(Widget page) => Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));

    return ListView(
      padding: const EdgeInsets.only(top: 48, bottom: 24),
      children: [
        ScreenTitle(s.payments),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Row(
            children: [
              PillButton(label: s.send, variant: PillVariant.primary, dense: true, onPressed: () => startSendFlow(context)),
              const SizedBox(width: 10),
              PillButton(label: s.request, dense: true, onPressed: () => push(const RequestScreen())),
            ],
          ),
        ),
        const SizedBox(height: 20),
        _PaymentTile(
          icon: Icons.qr_code_scanner,
          title: s.scanToPay,
          body: s.scanToPayBody,
          highlighted: true,
          onTap: () => push(const ScanScreen()),
        ),
        _PaymentTile(
          icon: Icons.phone_android,
          title: s.sendToMvola,
          body: s.sendToMvolaBody,
          onTap: () => push(const NewRecipientScreen(initialType: RecipientType.mobileMoney)),
        ),
        _PaymentTile(
          icon: Icons.public,
          title: s.intlMobileMoney,
          body: s.intlMobileMoneyBody,
          onTap: () => push(const NewRecipientScreen(initialType: RecipientType.mobileMoney, initialCountry: 'MG')),
        ),
        _PaymentTile(icon: Icons.qr_code_2, title: s.myQr, body: s.myQrBody, onTap: () => push(const MyQrScreen())),
        _PaymentTile(
          icon: Icons.receipt_long_outlined,
          title: s.billPayment,
          body: s.billPaymentBody,
          onTap: () => push(const BillersScreen()),
        ),
        _PaymentTile(
          icon: Icons.phone_android,
          title: s.airtime,
          body: s.airtimeBody,
          onTap: () => push(const BillersScreen(airtimeOnly: true)),
        ),
        _PaymentTile(
          icon: Icons.calendar_today_outlined,
          title: s.scheduledTransfers,
          body: s.scheduledTransfersBody,
          onTap: () => push(const ScheduledScreen()),
        ),
        _PaymentTile(
          icon: Icons.sync,
          title: s.standingOrders,
          body: s.standingOrdersBody,
          onTap: () => push(const ScheduledScreen(initialTab: 1)),
        ),
      ],
    );
  }
}

/// Tuile « option de paiement » ; l'icône est pleine pour l'option mise en avant.
class _PaymentTile extends StatelessWidget {
  const _PaymentTile({
    required this.icon,
    required this.title,
    required this.body,
    required this.onTap,
    this.highlighted = false,
  });
  final IconData icon;
  final String title;
  final String body;
  final VoidCallback onTap;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final content = InkWell(
      borderRadius: BorderRadius.circular(24),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Row(
          children: [
            SizedBox(
              width: 64,
              height: 64,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: highlighted ? AppColors.navy : null,
                      border: highlighted ? null : Border.all(color: AppColors.border),
                    ),
                    child: Icon(icon, color: highlighted ? AppColors.gold : AppColors.navy, size: 28),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 6),
                  Text(body, style: const TextStyle(fontSize: 15, color: AppColors.textSecondary, height: 1.45)),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.chevron_right),
          ],
        ),
      ),
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
      child: Material(color: AppColors.surface, borderRadius: BorderRadius.circular(24), child: content),
    );
  }
}


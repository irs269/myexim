import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../core/app_scope.dart';
import '../../core/l10n/strings.dart';
import '../../core/theme/app_colors.dart';
import '../../data/models.dart';
import '../auth/auth_widgets.dart';
import '../send/amount_screen.dart';
import '../send/send_flow.dart';
import 'payment_review_screen.dart';
import 'qr_payload.dart';

/// Scan to Pay : lecture d'un QR de paiement Exim (caméra ou saisie manuelle).
class ScanScreen extends StatefulWidget {
  const ScanScreen({super.key});

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> {
  final _controller = MobileScannerController(formats: const [BarcodeFormat.qrCode]);
  bool _handling = false;
  String? _lastInvalid;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    final raw = capture.barcodes.map((b) => b.rawValue).whereType<String>().firstOrNull;
    if (raw == null) return;
    await _handle(raw);
  }

  Future<void> _handle(String raw) async {
    if (_handling) return;
    final s = S.of(context);
    final payload = QrPayload.tryParse(raw);
    if (payload == null) {
      // Un même QR invalide reste devant la caméra : on ne répète pas le message.
      if (raw != _lastInvalid) showErrorSnack(context, s.invalidQr);
      _lastInvalid = raw;
      return;
    }
    _handling = true;
    await _controller.stop();
    if (!mounted) return;
    await openQrPayload(context, payload, replace: true);
    _handling = false;
  }

  Future<void> _enterCode() async {
    final code = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: AppColors.background,
      builder: (_) => const _CodeSheet(),
    );
    if (code != null && code.trim().isNotEmpty && mounted) await _handle(code);
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          MobileScanner(
            controller: _controller,
            onDetect: _onDetect,
            errorBuilder: (context, error) => ColoredBox(
              color: AppColors.navyDark,
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.no_photography_outlined, color: Colors.white70, size: 56),
                      const SizedBox(height: 16),
                      Text(s.cameraUnavailable,
                          textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 16)),
                    ],
                  ),
                ),
              ),
            ),
          ),
          // Cadre de visée
          Center(
            child: Container(
              width: 260,
              height: 260,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(28),
                border: Border.all(color: AppColors.gold, width: 4),
              ),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: Row(
                    children: [
                      _CircleButton(icon: Icons.close, onTap: () => Navigator.of(context).pop()),
                      const Spacer(),
                      _CircleButton(icon: Icons.flashlight_on_outlined, tooltip: s.torch, onTap: _controller.toggleTorch),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                Text(s.scanTitle, style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w800)),
                const SizedBox(height: 6),
                Text(s.scanHint, style: const TextStyle(color: Colors.white70, fontSize: 15)),
                const Spacer(),
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: PrimaryButton(
                    label: s.enterCode,
                    background: Colors.white,
                    foreground: AppColors.navy,
                    onPressed: _enterCode,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Oriente vers l'écran adapté au QR lu : virement (particulier) ou paiement (commerçant, facture).
Future<void> openQrPayload(BuildContext context, QrPayload payload, {bool replace = false}) async {
  final navigator = Navigator.of(context);
  Widget page;
  if (payload.type == QrType.person) {
    final accounts = await AppScope.repo(context).getAccounts();
    final draft = TransferDraft(
      from: defaultSourceAccount(accounts, payload.currency),
      to: TransferDestination.beneficiary(payload.toBeneficiary()),
    );
    page = AmountScreen(draft: draft, initialAmount: payload.amount);
  } else {
    page = PaymentReviewScreen(request: payload.toPaymentRequest());
  }
  final route = MaterialPageRoute<void>(builder: (_) => page);
  replace ? await navigator.pushReplacement(route) : await navigator.push(route);
}

class _CircleButton extends StatelessWidget {
  const _CircleButton({required this.icon, required this.onTap, this.tooltip});
  final IconData icon;
  final VoidCallback onTap;
  final String? tooltip;

  @override
  Widget build(BuildContext context) => Material(
        color: Colors.black45,
        shape: const CircleBorder(),
        child: IconButton(icon: Icon(icon, color: Colors.white), tooltip: tooltip, onPressed: onTap),
      );
}

/// Saisie manuelle du contenu d'un QR ; possède son contrôleur (durée de vie = feuille).
class _CodeSheet extends StatefulWidget {
  const _CodeSheet();

  @override
  State<_CodeSheet> createState() => _CodeSheetState();
}

class _CodeSheetState extends State<_CodeSheet> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return Padding(
      padding: EdgeInsets.fromLTRB(24, 0, 24, MediaQuery.viewInsetsOf(context).bottom + 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(s.enterCode, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 16),
          TextField(
            controller: _controller,
            autofocus: true,
            minLines: 2,
            maxLines: 4,
            decoration: InputDecoration(
              hintText: s.pasteCode,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
          const SizedBox(height: 16),
          PrimaryButton(label: s.continueLabel, onPressed: () => Navigator.of(context).pop(_controller.text)),
        ],
      ),
    );
  }
}

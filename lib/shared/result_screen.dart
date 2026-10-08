import 'package:flutter/material.dart';

import '../core/l10n/strings.dart';
import '../core/theme/app_colors.dart';
import '../data/models.dart';
import '../features/auth/auth_widgets.dart';
import '../features/transactions/transaction_detail_screen.dart';

/// Écran de fin d'opération aux couleurs Exim (envoi, paiement, demande…).
class ResultScreen extends StatefulWidget {
  const ResultScreen({
    super.key,
    required this.title,
    required this.body,
    this.reference,
    this.pending = false,
    this.transaction,
  });
  final String title;
  final String body;
  final String? reference;
  final bool pending;

  /// Si fourni, propose « Voir le détail ».
  final BankTransaction? transaction;

  @override
  State<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends State<ResultScreen> with SingleTickerProviderStateMixin {
  late final _anim = AnimationController(vsync: this, duration: const Duration(milliseconds: 650))..forward();

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final tx = widget.transaction;
    return Scaffold(
      backgroundColor: AppColors.navy,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const Spacer(),
              ScaleTransition(
                scale: CurvedAnimation(parent: _anim, curve: Curves.elasticOut),
                child: Container(
                  width: 120,
                  height: 120,
                  decoration: const BoxDecoration(color: AppColors.gold, shape: BoxShape.circle),
                  child: Icon(widget.pending ? Icons.schedule_send : Icons.check_rounded, size: 70, color: AppColors.navy),
                ),
              ),
              const SizedBox(height: 32),
              Text(
                widget.title,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 12),
              Text(widget.body,
                  textAlign: TextAlign.center, style: const TextStyle(color: Colors.white70, fontSize: 17, height: 1.4)),
              if (widget.reference != null) ...[
                const SizedBox(height: 8),
                Text('${s.reference} : ${widget.reference}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: AppColors.gold, fontWeight: FontWeight.w600)),
              ],
              const Spacer(),
              if (tx != null) ...[
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: Colors.white54),
                      shape: const StadiumBorder(),
                      textStyle: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                    ),
                    onPressed: () => Navigator.of(context).pushReplacement(
                      MaterialPageRoute(builder: (_) => TransactionDetailScreen(tx: tx)),
                    ),
                    child: Text(s.seeDetails),
                  ),
                ),
                const SizedBox(height: 12),
              ],
              PrimaryButton(
                label: s.done,
                background: AppColors.gold,
                foreground: AppColors.navy,
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

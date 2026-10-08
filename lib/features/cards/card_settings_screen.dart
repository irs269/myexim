import 'package:flutter/material.dart';

import '../../core/app_scope.dart';
import '../../core/l10n/strings.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../data/models.dart';
import '../../shared/widgets.dart';
import '../auth/auth_widgets.dart';
import '../send/pin_confirm_sheet.dart';

/// Options de paiement, plafonds quotidiens et opposition d'une carte.
class CardSettingsScreen extends StatefulWidget {
  const CardSettingsScreen({super.key, required this.card});
  final DebitCard card;

  @override
  State<CardSettingsScreen> createState() => _CardSettingsScreenState();
}

class _CardSettingsScreenState extends State<CardSettingsScreen> {
  late DebitCard _card = widget.card;
  bool _saving = false;

  static const _step = 10000.0;

  bool get _dirty =>
      _card.onlinePayments != widget.card.onlinePayments ||
      _card.contactless != widget.card.contactless ||
      _card.international != widget.card.international ||
      _card.limits.atmDaily != widget.card.limits.atmDaily ||
      _card.limits.posDaily != widget.card.limits.posDaily ||
      _card.limits.onlineDaily != widget.card.limits.onlineDaily;

  Future<void> _save() async {
    final s = S.of(context);
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final repo = AppScope.repo(context);
    // Relever un plafond est une opération sensible : confirmation par PIN.
    if (!await confirmWithPin(context)) return;
    setState(() => _saving = true);
    try {
      await repo.updateCard(_card);
      navigator.pop();
      messenger.showSnackBar(SnackBar(content: Text(s.settingsSaved), behavior: SnackBarBehavior.floating));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _block() async {
    final s = S.of(context);
    final repo = AppScope.repo(context);
    final navigator = Navigator.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(s.blockCard),
        content: Text(s.blockCardBody),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: Text(s.cancel)),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(s.confirmBlock),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    if (!await confirmWithPin(context)) return;
    await repo.updateCard(widget.card.copyWith(status: CardStatus.blocked));
    navigator.pop();
  }

  Widget _limit(String label, double value, double max, ValueChanged<double> onChanged) {
    final divisions = (max / _step).round();
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(label, style: const TextStyle(fontSize: 16))),
              Text(formatAmount(value, 'KMF'), style: const TextStyle(fontWeight: FontWeight.w800)),
            ],
          ),
          Slider(
            value: value.clamp(0, max),
            max: max,
            divisions: divisions,
            activeColor: AppColors.navy,
            inactiveColor: AppColors.primarySoft,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final l = _card.limits;
    final m = _card.maxLimits;
    Widget toggle(String label, IconData icon, bool value, ValueChanged<bool> onChanged) => SwitchListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 24),
          secondary: CircleIcon(icon: icon, size: 44, bg: AppColors.primarySoft, fg: AppColors.navy),
          title: Text(label, style: const TextStyle(fontSize: 16)),
          value: value,
          activeThumbColor: Colors.white,
          activeTrackColor: AppColors.navy,
          onChanged: onChanged,
        );

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.only(bottom: 24),
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: RoundIconButton(icon: Icons.arrow_back, onPressed: () => Navigator.of(context).pop()),
                    ),
                  ),
                  ScreenTitle(s.cardSettings),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Text('${_card.product} · •••• ${_card.last4}',
                        style: const TextStyle(color: AppColors.textSecondary, fontSize: 16)),
                  ),
                  SectionLabel(s.cardSecurity),
                  toggle(s.onlinePayments, Icons.language, _card.onlinePayments,
                      (v) => setState(() => _card = _card.copyWith(onlinePayments: v))),
                  toggle(s.contactless, Icons.contactless_outlined, _card.contactless,
                      (v) => setState(() => _card = _card.copyWith(contactless: v))),
                  toggle(s.international, Icons.flight_takeoff, _card.international,
                      (v) => setState(() => _card = _card.copyWith(international: v))),
                  SectionLabel(s.dailyLimits),
                  _limit(s.atmLimit, l.atmDaily, m.atmDaily,
                      (v) => setState(() => _card = _card.copyWith(limits: l.copyWith(atmDaily: v)))),
                  _limit(s.posLimit, l.posDaily, m.posDaily,
                      (v) => setState(() => _card = _card.copyWith(limits: l.copyWith(posDaily: v)))),
                  _limit(s.onlineLimit, l.onlineDaily, m.onlineDaily,
                      (v) => setState(() => _card = _card.copyWith(limits: l.copyWith(onlineDaily: v)))),
                  const SizedBox(height: 16),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.danger,
                        side: const BorderSide(color: AppColors.danger),
                        shape: const StadiumBorder(),
                        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
                      ),
                      icon: const Icon(Icons.block),
                      label: Text(s.blockCard, style: const TextStyle(fontWeight: FontWeight.w700)),
                      onPressed: _block,
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
              child: PrimaryButton(label: s.save, loading: _saving, onPressed: _dirty ? _save : null),
            ),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';

import '../../core/app_scope.dart';
import '../../core/l10n/strings.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../data/models.dart';
import '../../shared/repo_listener.dart';
import '../../shared/widgets.dart';
import '../send/pin_confirm_sheet.dart';
import 'schedule_form_screen.dart';

/// Virements planifiés (onglet 0) et ordres permanents (onglet 1).
class ScheduledScreen extends StatefulWidget {
  const ScheduledScreen({super.key, this.initialTab = 0});
  final int initialTab;

  @override
  State<ScheduledScreen> createState() => _ScheduledScreenState();
}

typedef _Data = (List<ScheduledTransfer>, List<Account>);

class _ScheduledScreenState extends State<ScheduledScreen> with RepoListener {
  late int _tab = widget.initialTab;
  Future<_Data>? _data;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _data ??= _load();
  }

  Future<_Data> _load() async {
    final repo = AppScope.repo(context);
    final r = await Future.wait([repo.getScheduledTransfers(), repo.getAccounts()]);
    return (r[0] as List<ScheduledTransfer>, r[1] as List<Account>);
  }

  @override
  void onRepoChanged() {
    setState(() {
      _data = _load();
    });
  }

  void _create() => Navigator.of(context)
      .push(MaterialPageRoute(builder: (_) => ScheduleFormScreen(recurring: _tab == 1)));

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final recurring = _tab == 1;
    return Scaffold(
      body: SafeArea(
        child: AsyncView(
          future: _data!,
          builder: (context, data) {
            final (all, accounts) = data;
            final items = all.where((t) => t.isRecurring == recurring).toList()
              ..sort((a, b) => (a.nextRun(DateTime.now()) ?? DateTime(9999)).compareTo(b.nextRun(DateTime.now()) ?? DateTime(9999)));
            return ListView(
              padding: const EdgeInsets.only(bottom: 32),
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
                  child: Row(
                    children: [
                      RoundIconButton(icon: Icons.arrow_back, onPressed: () => Navigator.of(context).pop()),
                      const SizedBox(width: 12),
                      Expanded(
                        child: PillGroup(children: [
                          PillButton(
                            label: recurring ? s.newStanding : s.newScheduled,
                            icon: Icons.add,
                            variant: PillVariant.primary,
                            dense: true,
                            onPressed: _create,
                          ),
                        ]),
                      ),
                    ],
                  ),
                ),
                ScreenTitle(s.scheduledPayments),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final (i, label) in [s.tabScheduled, s.tabStanding].indexed)
                        PillButton(
                          label: label,
                          dense: true,
                          variant: _tab == i ? PillVariant.primary : PillVariant.outline,
                          onPressed: () => setState(() => _tab = i),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                if (items.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(40),
                    child: Column(
                      children: [
                        CircleIcon(
                          icon: recurring ? Icons.sync : Icons.calendar_today_outlined,
                          size: 72,
                          bg: AppColors.surface,
                          fg: AppColors.textMuted,
                        ),
                        const SizedBox(height: 14),
                        Text(recurring ? s.noStanding : s.noScheduled,
                            style: const TextStyle(color: AppColors.textSecondary, fontSize: 16)),
                        const SizedBox(height: 16),
                        PillButton(label: recurring ? s.newStanding : s.newScheduled, icon: Icons.add, onPressed: _create),
                      ],
                    ),
                  )
                else
                  for (final t in items)
                    ScheduledTile(
                      transfer: t,
                      onTap: () => showModalBottomSheet<void>(
                        context: context,
                        isScrollControlled: true,
                        showDragHandle: true,
                        backgroundColor: AppColors.background,
                        builder: (_) => _ScheduleDetailSheet(transfer: t, accounts: accounts),
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

/// « Chaque mois · Prochaine : 5 novembre » / « Le 14 octobre ».
String scheduleSummary(S s, ScheduledTransfer t) {
  final next = t.nextRun(DateTime.now());
  final nextText = next == null ? s.statusEnded : formatDate(next, french: s.french);
  if (!t.isRecurring) return s.onDate(nextText);
  return '${s.frequencyLabel(t.frequency.index)} · ${s.nextExecution} : $nextText';
}

Widget destinationAvatar(TransferDestination to, {double size = 52}) => to.beneficiary != null
    ? InitialsAvatar.of(to.beneficiary!, size: size)
    : AccountIcon(account: to.ownAccount!, size: size);

class ScheduledTile extends StatelessWidget {
  const ScheduledTile({super.key, required this.transfer, required this.onTap});
  final ScheduledTransfer transfer;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final paused = transfer.status == ScheduleStatus.paused;
    return ListRow(
      leading: destinationAvatar(transfer.to),
      title: transfer.to.name,
      subtitle: paused ? '${s.statusPaused} · ${scheduleSummary(s, transfer)}' : scheduleSummary(s, transfer),
      onTap: onTap,
      trailing: Text(
        formatAmount(transfer.amount, 'KMF'),
        style: TextStyle(
          fontWeight: FontWeight.w700,
          fontSize: 15.5,
          color: paused ? AppColors.textMuted : AppColors.textPrimary,
        ),
      ),
    );
  }
}

class _ScheduleDetailSheet extends StatefulWidget {
  const _ScheduleDetailSheet({required this.transfer, required this.accounts});
  final ScheduledTransfer transfer;
  final List<Account> accounts;

  @override
  State<_ScheduleDetailSheet> createState() => _ScheduleDetailSheetState();
}

class _ScheduleDetailSheetState extends State<_ScheduleDetailSheet> {
  late ScheduledTransfer _t = widget.transfer;
  bool _busy = false;

  Future<void> _setStatus(ScheduleStatus status) async {
    final repo = AppScope.repo(context);
    setState(() => _busy = true);
    try {
      final updated = await repo.setScheduledTransferStatus(_t.id, status);
      if (mounted) setState(() => _t = updated);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _cancel() async {
    final s = S.of(context);
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(s.cancelSchedule),
        content: Text(s.cancelScheduleBody),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: Text(s.keep)),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(s.cancelSchedule),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    if (!await confirmWithPin(context)) return;
    await _setStatus(ScheduleStatus.cancelled);
    navigator.pop();
    messenger.showSnackBar(SnackBar(content: Text(s.scheduleCancelled), behavior: SnackBarBehavior.floating));
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final from = widget.accounts.where((a) => a.number == _t.fromAccountNumber).firstOrNull;
    final upcoming = _t.status == ScheduleStatus.paused ? <DateTime>[] : _t.upcoming(from: DateTime.now());
    Widget line(String label, String value) => Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 7),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: Text(label, style: const TextStyle(color: AppColors.textSecondary))),
              const SizedBox(width: 12),
              Flexible(child: Text(value, textAlign: TextAlign.right, style: const TextStyle(fontWeight: FontWeight.w600))),
            ],
          ),
        );

    return SafeArea(
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(child: destinationAvatar(_t.to, size: 64)),
            const SizedBox(height: 10),
            Center(child: Text(_t.to.name, style: Theme.of(context).textTheme.titleLarge)),
            const SizedBox(height: 4),
            Center(
              child: Text(formatAmount(_t.amount, 'KMF'),
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(color: AppColors.navy)),
            ),
            const SizedBox(height: 16),
            line(s.frequency, s.frequencyLabel(_t.frequency.index)),
            line(s.status, switch (_t.status) {
              ScheduleStatus.active => s.statusActive,
              ScheduleStatus.paused => s.statusPaused,
              _ => s.statusEnded,
            }),
            if (from != null) line(s.from, '${from.label} · ${from.number}'),
            line(s.purpose, s.purposeLabel(_t.purpose.index)),
            if (_t.endDate != null) line(s.endLabel, formatDate(_t.endDate!, french: s.french)),
            if (_t.note != null && _t.note!.isNotEmpty) line(s.noteLabel, _t.note!),
            if (upcoming.isNotEmpty) ...[
              SectionLabel(s.nextExecutions),
              for (final d in upcoming)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
                  child: Row(
                    children: [
                      const Icon(Icons.event, size: 18, color: AppColors.navy),
                      const SizedBox(width: 10),
                      Text(formatDate(d, french: s.french), style: const TextStyle(fontSize: 15.5)),
                    ],
                  ),
                ),
            ],
            const SizedBox(height: 20),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  if (_t.isRecurring && _t.status == ScheduleStatus.active)
                    PillButton(
                      label: s.pause,
                      icon: Icons.pause,
                      dense: true,
                      onPressed: _busy ? null : () => _setStatus(ScheduleStatus.paused),
                    ),
                  if (_t.isRecurring && _t.status == ScheduleStatus.paused)
                    PillButton(
                      label: s.resume,
                      icon: Icons.play_arrow,
                      variant: PillVariant.primary,
                      dense: true,
                      onPressed: _busy ? null : () => _setStatus(ScheduleStatus.active),
                    ),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.danger,
                      side: const BorderSide(color: AppColors.danger),
                      shape: const StadiumBorder(),
                    ),
                    icon: const Icon(Icons.close),
                    label: Text(s.cancelSchedule, style: const TextStyle(fontWeight: FontWeight.w700)),
                    onPressed: _busy ? null : _cancel,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}

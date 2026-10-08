import 'dart:async';

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
import '../send/review_screen.dart' show PurposeField, pickPurpose;
import '../send/send_flow.dart' show defaultSourceAccount, parseAmount, pickAccount;
import 'scheduled_screen.dart' show destinationAvatar;

/// Création d'un virement planifié (une date) ou d'un ordre permanent ([recurring]).
class ScheduleFormScreen extends StatefulWidget {
  const ScheduleFormScreen({super.key, required this.recurring});
  final bool recurring;

  @override
  State<ScheduleFormScreen> createState() => _ScheduleFormScreenState();
}

class _ScheduleFormScreenState extends State<ScheduleFormScreen> {
  final _amount = TextEditingController();
  final _note = TextEditingController();
  List<Account> _accounts = const [];
  List<Beneficiary> _beneficiaries = const [];
  Account? _from;
  TransferDestination? _to;
  late ScheduleFrequency _frequency = widget.recurring ? ScheduleFrequency.monthly : ScheduleFrequency.once;
  DateTime _start = _tomorrow();
  DateTime? _end;
  TransferPurpose? _purpose;
  TransferQuote? _quote;
  Timer? _debounce;
  bool _saving = false;

  static DateTime _tomorrow() {
    final n = DateTime.now();
    return DateTime(n.year, n.month, n.day + 1);
  }

  @override
  void initState() {
    super.initState();
    _amount.addListener(_requote);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_accounts.isEmpty) {
      final repo = AppScope.repo(context);
      Future.wait([repo.getAccounts(), repo.getBeneficiaries()]).then((r) {
        if (!mounted) return;
        setState(() {
          _accounts = r[0] as List<Account>;
          _beneficiaries = r[1] as List<Beneficiary>;
          _from = defaultSourceAccount(_accounts, 'KMF');
        });
      });
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  double? get _value => parseAmount(_amount.text);

  /// Frais estimés de chaque exécution (selon la destination).
  void _requote() {
    _debounce?.cancel();
    setState(() => _quote = null);
    final v = _value;
    if (v == null || v <= 0 || _to == null || _from == null) return;
    _debounce = Timer(const Duration(milliseconds: 300), () async {
      final q = await AppScope.repo(context).getQuote(from: _from!, to: _to!, amount: v, side: AmountSide.send);
      if (mounted && _value == v) setState(() => _quote = q);
    });
  }

  Future<void> _pickRecipient() async {
    final s = S.of(context);
    final own = _accounts.where((a) => a.number != _from?.number).toList();
    final picked = await showModalBottomSheet<TransferDestination>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: AppColors.background,
      builder: (context) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.75,
        builder: (context, controller) => ListView(
          controller: controller,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
              child: Text(s.chooseRecipient, style: Theme.of(context).textTheme.titleLarge),
            ),
            if (own.isNotEmpty) ...[
              SectionLabel(s.myAccounts),
              for (final a in own)
                ListRow(
                  leading: AccountIcon(account: a, size: 48),
                  title: a.label,
                  subtitle: a.number,
                  onTap: () => Navigator.of(context).pop(TransferDestination.ownAccount(a)),
                ),
            ],
            SectionLabel(s.beneficiaries),
            for (final b in _beneficiaries)
              ListRow(
                leading: InitialsAvatar.of(b, size: 48),
                title: b.name,
                subtitle: '${b.bankName} · ${b.accountNumber}',
                onTap: () => Navigator.of(context).pop(TransferDestination.beneficiary(b)),
              ),
          ],
        ),
      ),
    );
    if (picked != null) {
      setState(() => _to = picked);
      _requote();
    }
  }

  Future<DateTime?> _pickDate(DateTime initial, {DateTime? first}) => showDatePicker(
        context: context,
        initialDate: initial,
        firstDate: first ?? _tomorrow(),
        lastDate: DateTime.now().add(const Duration(days: 365 * 3)),
      );

  ScheduledTransfer? get _draft {
    final v = _value;
    if (_from == null || _to == null || v == null || v <= 0 || _purpose == null) return null;
    return ScheduledTransfer(
      id: 'draft',
      fromAccountNumber: _from!.number,
      to: _to!,
      amount: v,
      frequency: _frequency,
      startDate: _start,
      endDate: widget.recurring ? _end : null,
      purpose: _purpose!,
      note: _note.text.trim().isEmpty ? null : _note.text.trim(),
    );
  }

  Future<void> _confirm() async {
    final s = S.of(context);
    final draft = _draft;
    if (draft == null) return;
    final repo = AppScope.repo(context);
    final navigator = Navigator.of(context);
    if (!await confirmWithPin(context)) return;
    setState(() => _saving = true);
    try {
      await repo.createScheduledTransfer(draft);
      final amount = formatAmount(draft.amount, 'KMF');
      navigator.pushReplacement(MaterialPageRoute(
        builder: (_) => ResultScreen(
          title: widget.recurring ? s.standingCreated : s.scheduleCreated,
          body: widget.recurring
              ? s.standingCreatedBody(amount, draft.to.name, s.frequencyLabel(draft.frequency.index))
              : s.scheduleCreatedBody(amount, draft.to.name, formatDate(draft.startDate, french: s.french)),
        ),
      ));
    } on TransferException catch (e) {
      if (mounted) showErrorSnack(context, e.code == TransferError.limitExceeded ? s.limitExceeded : s.genericError);
    } catch (_) {
      if (mounted) showErrorSnack(context, s.genericError);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final draft = _draft;
    final upcoming = draft?.upcoming(from: DateTime.now()) ?? const <DateTime>[];
    Widget label(String text) => Padding(
          padding: const EdgeInsets.only(top: 18, bottom: 8),
          child: Text(text, style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
        );
    Widget box({required Widget child, VoidCallback? onTap}) => Material(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: onTap,
            child: Padding(padding: const EdgeInsets.all(14), child: child),
          ),
        );
    Widget dateBox(DateTime? date, VoidCallback onTap, {String? placeholder}) => box(
          onTap: onTap,
          child: Row(
            children: [
              const Icon(Icons.event, color: AppColors.navy),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  date == null ? (placeholder ?? '') : formatDate(date, french: s.french),
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ),
              const Icon(Icons.expand_more),
            ],
          ),
        );

    return AuthScaffold(
      title: widget.recurring ? s.standingTitle : s.scheduleTitle,
      bottom: PrimaryButton(
        label: s.confirmSchedule,
        loading: _saving,
        onPressed: draft == null ? null : _confirm,
      ),
      children: [
        Text(s.recipient, style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
        const SizedBox(height: 8),
        box(
          onTap: _accounts.isEmpty ? null : _pickRecipient,
          child: Row(
            children: [
              if (_to == null)
                const CircleIcon(icon: Icons.person_add_alt_1, size: 44, bg: AppColors.primarySoft, fg: AppColors.navy)
              else
                destinationAvatar(_to!, size: 44),
              const SizedBox(width: 12),
              Expanded(
                child: Text(_to?.name ?? s.chooseRecipient,
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: _to == null ? AppColors.textMuted : null)),
              ),
              const Icon(Icons.expand_more),
            ],
          ),
        ),
        label(s.from),
        if (_from != null)
          box(
            onTap: () async {
              final picked = await pickAccount(context, accounts: _accounts, title: s.from, selected: _from);
              if (picked == null) return;
              setState(() {
                _from = picked;
                if (_to?.ownAccount?.number == picked.number) _to = null;
              });
              _requote();
            },
            child: Row(
              children: [
                AccountIcon(account: _from!),
                const SizedBox(width: 12),
                Expanded(child: Text(_from!.label, style: const TextStyle(fontWeight: FontWeight.w700))),
                Text(formatAmount(_from!.balance, 'KMF'), style: const TextStyle(color: AppColors.textSecondary)),
                const Icon(Icons.expand_more),
              ],
            ),
          ),
        label(s.amount),
        TextField(
          controller: _amount,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9\s ]'))],
          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
          decoration: InputDecoration(
            hintText: '0',
            suffixText: 'KMF',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: AppColors.border)),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: AppColors.navy, width: 1.5)),
          ),
        ),
        if (_quote != null)
          Padding(
            padding: const EdgeInsets.only(top: 8, left: 4),
            child: Text(
              '${s.ourFee} : ${_quote!.fee == 0 ? s.noFee : formatAmount(_quote!.fee, 'KMF')}',
              style: const TextStyle(color: AppColors.textSecondary),
            ),
          ),
        if (widget.recurring) ...[
          label(s.frequency),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final f in [ScheduleFrequency.weekly, ScheduleFrequency.monthly, ScheduleFrequency.quarterly])
                PillButton(
                  label: s.frequencyLabel(f.index),
                  dense: true,
                  variant: _frequency == f ? PillVariant.primary : PillVariant.outline,
                  onPressed: () => setState(() => _frequency = f),
                ),
            ],
          ),
        ],
        label(widget.recurring ? s.firstExecution : s.executionDate),
        dateBox(_start, () async {
          final d = await _pickDate(_start);
          if (d == null) return;
          setState(() {
            _start = d;
            if (_end != null && _end!.isBefore(d)) _end = null;
          });
        }),
        if (widget.recurring) ...[
          label(s.endLabel),
          Wrap(
            spacing: 8,
            children: [
              PillButton(
                label: s.noEnd,
                dense: true,
                variant: _end == null ? PillVariant.primary : PillVariant.outline,
                onPressed: () => setState(() => _end = null),
              ),
              PillButton(
                label: _end == null ? s.untilDate : formatDate(_end!, french: s.french),
                dense: true,
                icon: Icons.event,
                variant: _end == null ? PillVariant.outline : PillVariant.primary,
                onPressed: () async {
                  final d = await _pickDate(_end ?? DateTime(_start.year, _start.month + 6, _start.day), first: _start);
                  if (d != null) setState(() => _end = d);
                },
              ),
            ],
          ),
        ],
        label(s.purpose),
        PurposeField(
          purpose: _purpose,
          onTap: () async {
            final p = await pickPurpose(context, selected: _purpose);
            if (p != null) setState(() => _purpose = p);
          },
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _note,
          maxLength: 80,
          decoration: InputDecoration(
            labelText: s.noteOptional,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.border)),
          ),
        ),
        if (upcoming.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(top: 8),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(16)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.recurring ? s.nextExecutions : s.executionDate,
                    style: const TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                for (final d in upcoming)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: Row(
                      children: [
                        const Icon(Icons.event, size: 18, color: AppColors.navy),
                        const SizedBox(width: 10),
                        Expanded(child: Text(formatDate(d, french: s.french))),
                        Text(formatAmount(draft!.amount, 'KMF'), style: const TextStyle(fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                const SizedBox(height: 8),
                Text(s.scheduleNoteFees, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
              ],
            ),
          ),
      ],
    );
  }
}

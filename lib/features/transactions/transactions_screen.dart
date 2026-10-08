import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/app_scope.dart';
import '../../core/l10n/strings.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../data/models.dart';
import '../../shared/repo_listener.dart';
import '../../shared/widgets.dart';
import 'transaction_widgets.dart';

/// Historique complet : recherche, filtres (sens, comptes, période, type) et chargement progressif.
/// Les critères sont envoyés au back-end via [TransactionQuery].
class TransactionsScreen extends StatefulWidget {
  const TransactionsScreen({super.key, this.account});

  /// Si fourni, l'historique est limité à ce compte.
  final Account? account;

  @override
  State<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends State<TransactionsScreen> with RepoListener {
  static const _pageSize = 20;

  final _scroll = ScrollController();
  final _search = TextEditingController();
  final List<BankTransaction> _items = [];
  late TransactionQuery _query =
      widget.account == null ? const TransactionQuery() : TransactionQuery.forAccount(widget.account!.number);
  List<Account> _accounts = const [];
  bool _loading = false;
  bool _hasMore = true;
  Object? _error;
  Timer? _searchDebounce;

  /// Incrémenté à chaque nouvelle recherche pour ignorer les réponses périmées.
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      if (_scroll.position.extentAfter < 400) _loadMore();
    });
    _search.addListener(() {
      setState(() {}); // bouton d'effacement
      _searchDebounce?.cancel();
      _searchDebounce = Timer(const Duration(milliseconds: 350), () {
        if (_search.text.trim() != _query.search) _apply(_query.copyWith(search: _search.text.trim()));
      });
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_items.isEmpty && _hasMore && !_loading) {
      _loadMore();
      AppScope.repo(context).getAccounts().then((a) {
        if (mounted) setState(() => _accounts = a);
      });
    }
  }

  @override
  void onRepoChanged() => _apply(_query);

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _scroll.dispose();
    _search.dispose();
    super.dispose();
  }

  /// Nouvelle requête : on repart de la première page.
  void _apply(TransactionQuery query) {
    setState(() {
      _query = query;
      _items.clear();
      _hasMore = true;
      _loading = false;
      _generation++;
    });
    _loadMore();
  }

  Future<void> _loadMore() async {
    if (_loading || !_hasMore) return;
    final generation = _generation;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final page = await AppScope.repo(context).getTransactions(query: _query, offset: _items.length, limit: _pageSize);
      if (!mounted || generation != _generation) return;
      setState(() {
        _items.addAll(page);
        _hasMore = page.length == _pageSize;
      });
    } catch (e) {
      if (mounted && generation == _generation) setState(() => _error = e);
    } finally {
      if (mounted && generation == _generation) setState(() => _loading = false);
    }
  }

  // --- Feuilles de filtres -------------------------------------------------

  Future<T?> _sheet<T>(Widget Function(BuildContext, StateSetter) builder) => showModalBottomSheet<T>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        backgroundColor: AppColors.background,
        builder: (context) => SafeArea(
          child: StatefulBuilder(builder: (context, setSheet) => SingleChildScrollView(child: builder(context, setSheet))),
        ),
      );

  Future<void> _pickDirection() async {
    final s = S.of(context);
    final picked = await _sheet<(TxDirection?,)>((context, _) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SheetTitle(s.filterDirection),
            for (final (value, label) in [(null, s.filterAll), (TxDirection.credit, s.filterIn), (TxDirection.debit, s.filterOut)])
              _RadioRow(label: label, selected: _query.direction == value, onTap: () => Navigator.of(context).pop((value,))),
          ],
        ));
    if (picked != null) _apply(_query.copyWith(direction: () => picked.$1));
  }

  Future<void> _pickAccounts() async {
    final s = S.of(context);
    final selected = {..._query.accountNumbers};
    final picked = await _sheet<Set<String>>((context, setSheet) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SheetTitle(s.filterAccounts),
            for (final a in _accounts)
              CheckboxListTile(
                activeColor: AppColors.navy,
                contentPadding: const EdgeInsets.symmetric(horizontal: 24),
                secondary: AccountIcon(account: a),
                title: Text(a.label, style: const TextStyle(fontWeight: FontWeight.w600)),
                subtitle: Text(a.number),
                value: selected.contains(a.number),
                onChanged: (v) => setSheet(() => v == true ? selected.add(a.number) : selected.remove(a.number)),
              ),
            _ApplyButton(onPressed: () => Navigator.of(context).pop(selected)),
          ],
        ));
    if (picked != null) _apply(_query.copyWith(accountNumbers: picked));
  }

  Future<void> _pickType() async {
    final s = S.of(context);
    final selected = {..._query.categories};
    final picked = await _sheet<Set<TxCategory>>((context, setSheet) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SheetTitle(s.filterType),
            for (final c in TxCategory.values)
              CheckboxListTile(
                activeColor: AppColors.navy,
                contentPadding: const EdgeInsets.symmetric(horizontal: 24),
                secondary: CircleIcon(
                  icon: categoryIcon(c, TxDirection.debit),
                  size: 40,
                  bg: AppColors.surface,
                  fg: AppColors.navy,
                ),
                title: Text(s.categoryLabel(c.index)),
                value: selected.contains(c),
                onChanged: (v) => setSheet(() => v == true ? selected.add(c) : selected.remove(c)),
              ),
            _ApplyButton(onPressed: () => Navigator.of(context).pop(selected)),
          ],
        ));
    if (picked != null) _apply(_query.copyWith(categories: picked));
  }

  Future<void> _pickPeriod() async {
    final s = S.of(context);
    final now = DateTime.now();
    final thisMonth = DateTime(now.year, now.month);
    final options = <(String, DateTime?, DateTime?)>[
      (s.anyPeriod, null, null),
      (s.periodThisMonth, thisMonth, null),
      (s.periodLastMonth, DateTime(now.year, now.month - 1), DateTime(now.year, now.month, 0)),
      (s.period3Months, DateTime(now.year, now.month - 2), null),
    ];
    final picked = await _sheet<(DateTime?, DateTime?)>((context, _) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SheetTitle(s.filterPeriod),
            for (final (label, from, to) in options)
              _RadioRow(
                label: label,
                selected: _query.from == from && _query.to == to,
                onTap: () => Navigator.of(context).pop((from, to)),
              ),
            ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 24),
              leading: const Icon(Icons.date_range, color: AppColors.navy),
              title: Text(s.periodCustom, style: const TextStyle(fontWeight: FontWeight.w600)),
              onTap: () async {
                final range = await showDateRangePicker(
                  context: context,
                  firstDate: DateTime(now.year - 2),
                  lastDate: now,
                  initialDateRange: _query.from != null
                      ? DateTimeRange(start: _query.from!, end: _query.to ?? now)
                      : null,
                );
                if (range != null && context.mounted) Navigator.of(context).pop((range.start, range.end));
              },
            ),
          ],
        ));
    if (picked != null) _apply(_query.copyWith(from: () => picked.$1, to: () => picked.$2));
  }

  // --- Libellés des puces actives -----------------------------------------

  String? _directionSummary(S s) => switch (_query.direction) {
        TxDirection.credit => s.filterIn,
        TxDirection.debit => s.filterOut,
        null => null,
      };

  String? _accountsSummary() {
    final n = _query.accountNumbers;
    if (n.isEmpty || widget.account != null) return null;
    if (n.length == 1) {
      return _accounts.where((a) => a.number == n.first).map((a) => a.label).firstOrNull ?? n.first;
    }
    return '${n.length}';
  }

  String? _periodSummary(S s) {
    final from = _query.from;
    final to = _query.to;
    if (from == null && to == null) return null;
    String d(DateTime x) => formatDate(x, french: s.french);
    if (to == null) return '${s.french ? 'Depuis le' : 'Since'} ${d(from!)}';
    return '${d(from!)} – ${d(to)}';
  }

  String? _typeSummary(S s) {
    final c = _query.categories;
    if (c.isEmpty) return null;
    return c.length == 1 ? s.categoryLabel(c.first.index) : '${c.length}';
  }

  bool get _hasUserFilters {
    final accountsFiltered = widget.account == null && _query.accountNumbers.isNotEmpty;
    return accountsFiltered || _query.direction != null || _query.categories.isNotEmpty || _query.from != null;
  }

  void _clearFilters() {
    _apply(TransactionQuery(
      accountNumbers: widget.account == null ? const {} : {widget.account!.number},
      search: _query.search,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          color: AppColors.navy,
          onRefresh: () async => _apply(_query),
          child: ListView(
            controller: _scroll,
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.only(bottom: 32),
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: RoundIconButton(icon: Icons.arrow_back, onPressed: () => Navigator.of(context).pop()),
                ),
              ),
              ScreenTitle(widget.account?.label ?? s.transactions),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: TextField(
                  controller: _search,
                  textInputAction: TextInputAction.search,
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: AppColors.surface,
                    hintText: s.searchTransactions,
                    prefixIcon: const Padding(padding: EdgeInsets.only(left: 12), child: Icon(Icons.search)),
                    suffixIcon: _search.text.isEmpty
                        ? null
                        : IconButton(icon: const Icon(Icons.close), onPressed: _search.clear),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(40), borderSide: BorderSide.none),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Row(
                  children: [
                    if (_hasUserFilters) ...[
                      PillButton(label: s.clearFilters, icon: Icons.close, dense: true, onPressed: _clearFilters),
                      const SizedBox(width: 8),
                    ],
                    _FilterChip(label: s.filterDirection, summary: _directionSummary(s), onTap: _pickDirection),
                    if (widget.account == null)
                      _FilterChip(label: s.filterAccounts, summary: _accountsSummary(), onTap: _pickAccounts),
                    _FilterChip(label: s.filterPeriod, summary: _periodSummary(s), onTap: _pickPeriod),
                    _FilterChip(label: s.filterType, summary: _typeSummary(s), onTap: _pickType),
                  ],
                ),
              ),
              const SizedBox(height: 4),
              ...groupedTransactionTiles(context, _items),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      Text(s.genericError, style: const TextStyle(color: AppColors.danger)),
                      const SizedBox(height: 8),
                      PillButton(label: s.retry, dense: true, onPressed: _loadMore),
                    ],
                  ),
                )
              else if (_loading)
                const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(child: CircularProgressIndicator(color: AppColors.navy)),
                )
              else if (_items.isEmpty)
                const EmptyTransactions(),
            ],
          ),
        ),
      ),
    );
  }
}

/// Puce de filtre : contour quand inactive, pleine avec résumé quand active.
class _FilterChip extends StatelessWidget {
  const _FilterChip({required this.label, required this.summary, required this.onTap});
  final String label;
  final String? summary;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final active = summary != null;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Material(
        color: active ? AppColors.navy : AppColors.background,
        shape: StadiumBorder(side: BorderSide(color: active ? AppColors.navy : AppColors.border)),
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  active ? '$label : $summary' : label,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14.5,
                    color: active ? Colors.white : AppColors.textPrimary,
                  ),
                ),
                Icon(Icons.expand_more, size: 18, color: active ? Colors.white : AppColors.textPrimary),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SheetTitle extends StatelessWidget {
  const _SheetTitle(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
        child: Text(text, style: Theme.of(context).textTheme.titleLarge),
      );
}

class _RadioRow extends StatelessWidget {
  const _RadioRow({required this.label, required this.selected, required this.onTap});
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 24),
        title: Text(label, style: const TextStyle(fontSize: 16)),
        trailing: Icon(
          selected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
          color: selected ? AppColors.navy : AppColors.textMuted,
        ),
        onTap: onTap,
      );
}

class _ApplyButton extends StatelessWidget {
  const _ApplyButton({required this.onPressed});
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 8),
        child: SizedBox(
          width: double.infinity,
          height: 52,
          child: FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.navy, shape: const StadiumBorder()),
            onPressed: onPressed,
            child: Text(S.of(context).apply, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
          ),
        ),
      );
}

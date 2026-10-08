import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/app_scope.dart';
import '../../core/l10n/strings.dart';
import '../../core/theme/app_colors.dart';
import '../../data/models.dart';
import '../../shared/repo_listener.dart';
import '../../shared/widgets.dart';
import '../send/pin_confirm_sheet.dart';
import 'card_settings_screen.dart';
import 'request_card_screen.dart';

class CardsScreen extends StatefulWidget {
  const CardsScreen({super.key});

  @override
  State<CardsScreen> createState() => _CardsScreenState();
}

typedef _CardsData = (List<DebitCard>, List<Account>, Customer);

class _CardsScreenState extends State<CardsScreen> with RepoListener {
  Future<_CardsData>? _cards;
  final _pager = PageController(viewportFraction: 0.82);
  int _current = 0;
  bool _busy = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _cards ??= _load();
  }

  Future<_CardsData> _load() async {
    final repo = AppScope.repo(context);
    final r = await Future.wait([repo.getCards(), repo.getAccounts(), repo.getCustomer()]);
    return (r[0] as List<DebitCard>, r[1] as List<Account>, r[2] as Customer);
  }

  @override
  void onRepoChanged() {
    setState(() {
      _cards = _load();
    });
  }

  /// Nom imprimé sur la carte : titulaire du compte rattaché (à défaut, le client connecté).
  static String ownerName(DebitCard card, List<Account> accounts, Customer customer) {
    final account = accounts.where((a) => a.number == card.accountNumber).firstOrNull;
    return (account?.holderName ?? customer.fullName).toUpperCase();
  }

  @override
  void dispose() {
    _pager.dispose();
    super.dispose();
  }

  Future<void> _toggleFreeze(DebitCard card) async {
    final s = S.of(context);
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    try {
      await AppScope.repo(context).updateCard(card.copyWith(status: card.frozen ? CardStatus.active : CardStatus.frozen));
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(
          content: Text(card.frozen ? s.cardUnfrozen : s.cardFrozen),
          behavior: SnackBarBehavior.floating,
        ));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Les données sensibles ne sont récupérées qu'après confirmation par PIN.
  Future<CardSecrets?> _secrets(DebitCard card) async {
    final repo = AppScope.repo(context);
    if (!await confirmWithPin(context)) return null;
    return repo.getCardSecrets(card.id);
  }

  Future<void> _showPin(DebitCard card) async {
    final secrets = await _secrets(card);
    if (secrets == null || !mounted) return;
    await showDialog<void>(context: context, builder: (_) => _PinRevealDialog(pin: secrets.pin));
  }

  Future<void> _showNumbers(DebitCard card, String owner) async {
    final secrets = await _secrets(card);
    if (secrets == null || !mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: AppColors.background,
      builder: (_) => _CardNumbersSheet(card: card, secrets: secrets, owner: owner),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
          child: Row(
            children: [
              const Spacer(),
              PillButton(
                label: s.requestCard,
                variant: PillVariant.primary,
                dense: true,
                onPressed: () =>
                    Navigator.of(context).push(MaterialPageRoute(builder: (_) => const RequestCardScreen())),
              ),
            ],
          ),
        ),
        ScreenTitle(s.cards),
        AsyncView(
          future: _cards!,
          builder: (context, data) {
            final (cards, accounts, customer) = data;
            if (cards.isEmpty) return const SizedBox.shrink();
            final card = cards[_current.clamp(0, cards.length - 1)];
            final owner = ownerName(card, accounts, customer);
            final disabled = card.blocked || _busy;
            return Column(
              children: [
                SizedBox(
                  height: 210,
                  child: PageView.builder(
                    controller: _pager,
                    itemCount: cards.length,
                    onPageChanged: (i) => setState(() => _current = i),
                    itemBuilder: (_, i) => CardVisual(card: cards[i], holderName: ownerName(cards[i], accounts, customer)),
                  ),
                ),
                const SizedBox(height: 20),
                Text.rich(
                  TextSpan(children: [
                    TextSpan(text: card.product, style: const TextStyle(fontWeight: FontWeight.w700)),
                    TextSpan(text: '     •••• ${card.last4}'),
                  ]),
                  style: const TextStyle(fontSize: 18),
                ),
                if (card.blocked)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(s.cardBlocked,
                        style: const TextStyle(color: AppColors.danger, fontWeight: FontWeight.w700)),
                  ),
                const SizedBox(height: 28),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: _CardAction(
                          icon: Icons.dialpad,
                          label: s.showPin,
                          onTap: disabled ? null : () => _showPin(card),
                        ),
                      ),
                      Expanded(
                        child: _CardAction(
                          icon: Icons.credit_card,
                          label: s.cardNumbers,
                          onTap: disabled ? null : () => _showNumbers(card, owner),
                        ),
                      ),
                      Expanded(
                        child: _CardAction(
                          icon: Icons.ac_unit,
                          label: card.frozen ? s.unfreezeCard : s.freezeCard,
                          active: card.frozen,
                          onTap: disabled ? null : () => _toggleFreeze(card),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                if (!card.blocked)
                  ListRow(
                    leading: const CircleIcon(icon: Icons.tune, size: 48),
                    title: s.cardSettings,
                    subtitle: '${s.dailyLimits} · ${s.cardSecurity}',
                    onTap: () => Navigator.of(context)
                        .push(MaterialPageRoute(builder: (_) => CardSettingsScreen(card: card))),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}

/// Visuel de carte. Silver : design officiel Exim (océan et boutres) avec numéro masqué,
/// expiration et titulaire superposés ; Gold : dégradé doré en attendant son visuel.
/// Gelée = estompée ; en opposition = barrée.
class CardVisual extends StatelessWidget {
  const CardVisual({super.key, required this.card, required this.holderName});
  final DebitCard card;

  /// Titulaire du compte rattaché, en capitales.
  final String holderName;

  /// Format ISO des cartes bancaires (85,6 × 54 mm).
  static const ratio = 85.6 / 54;

  @override
  Widget build(BuildContext context) {
    final silver = card.product.toLowerCase().contains('silver');
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Center(
        child: AspectRatio(
          aspectRatio: ratio,
          child: AnimatedOpacity(
            duration: const Duration(milliseconds: 250),
            opacity: card.status == CardStatus.active ? 1 : 0.45,
            child: Container(
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                image: silver
                    ? const DecorationImage(image: AssetImage('assets/images/card_silver.jpg'), fit: BoxFit.cover)
                    : null,
                gradient: silver
                    ? null
                    : const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Color(0xFFB8913E), Color(0xFFD9B66A), Color(0xFF9C7A2E)],
                      ),
                boxShadow: const [BoxShadow(color: Color(0x33000000), blurRadius: 18, offset: Offset(0, 8))],
              ),
              child: LayoutBuilder(builder: (context, c) {
                final w = c.maxWidth;
                // Relief façon embossage : texte clair avec ombre portée.
                TextStyle embossed(double size) => TextStyle(
                      color: Colors.white,
                      fontSize: size,
                      fontWeight: FontWeight.w700,
                      letterSpacing: size * 0.12,
                      shadows: const [Shadow(color: Color(0x99000000), offset: Offset(1, 1), blurRadius: 2)],
                    );
                return Stack(
                  children: [
                    if (!silver) ...[
                      Positioned(
                        left: w * 0.06,
                        top: w * 0.06,
                        child: Text('EXIM BANK',
                            style: TextStyle(
                                color: AppColors.navy, fontWeight: FontWeight.w800, fontSize: w * 0.06, letterSpacing: 2)),
                      ),
                      Positioned(
                        left: w * 0.08,
                        top: w * 0.24,
                        child: Container(
                          width: w * 0.13,
                          height: w * 0.1,
                          decoration: BoxDecoration(color: AppColors.goldLight, borderRadius: BorderRadius.circular(6)),
                        ),
                      ),
                      Positioned(
                        right: w * 0.06,
                        bottom: w * 0.05,
                        child: Text(card.network,
                            style: TextStyle(
                                color: Colors.white, fontWeight: FontWeight.w900, fontStyle: FontStyle.italic, fontSize: w * 0.08)),
                      ),
                    ],
                    // Numéro masqué à l'emplacement de l'embossage
                    Positioned(
                      left: w * 0.12,
                      top: w * 0.37,
                      child: Text('••••  ••••  ••••  ${card.last4}', style: embossed(w * 0.058)),
                    ),
                    Positioned(
                      left: w * 0.38,
                      top: w * 0.475,
                      child: Text(card.expiry, style: embossed(w * 0.04)),
                    ),
                    Positioned(
                      left: w * 0.12,
                      top: w * 0.535,
                      child: Text(holderName, style: embossed(w * 0.042)),
                    ),
                    if (card.frozen)
                      Center(child: Icon(Icons.ac_unit, color: Colors.white, size: w * 0.14)),
                    if (card.blocked)
                      Center(child: Icon(Icons.block, color: Colors.white, size: w * 0.16)),
                  ],
                );
              }),
            ),
          ),
        ),
      ),
    );
  }
}

class _CardAction extends StatelessWidget {
  const _CardAction({required this.icon, required this.label, this.onTap, this.active = false});
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Opacity(
        opacity: enabled ? 1 : 0.4,
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: Column(
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(color: active ? AppColors.navy : AppColors.primarySoft, shape: BoxShape.circle),
                child: Icon(icon, color: active ? Colors.white : AppColors.navy, size: 28),
              ),
              const SizedBox(height: 10),
              Text(label,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppColors.navy, fontWeight: FontWeight.w700, fontSize: 15)),
            ],
          ),
        ),
      ),
    );
  }
}

/// Affiche le PIN de la carte 10 secondes puis se ferme.
class _PinRevealDialog extends StatefulWidget {
  const _PinRevealDialog({required this.pin});
  final String pin;

  @override
  State<_PinRevealDialog> createState() => _PinRevealDialogState();
}

class _PinRevealDialogState extends State<_PinRevealDialog> {
  static const _duration = 10;
  int _left = _duration;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_left <= 1) {
        t.cancel();
        if (mounted) Navigator.of(context).pop();
      } else {
        setState(() => _left--);
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return AlertDialog(
      title: Text(s.yourPin, textAlign: TextAlign.center),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(widget.pin.split('').join('  '),
              style: const TextStyle(fontSize: 40, fontWeight: FontWeight.w800, color: AppColors.navy)),
          const SizedBox(height: 12),
          Text(s.hiddenIn(_left), style: const TextStyle(color: AppColors.textSecondary)),
        ],
      ),
    );
  }
}

class _CardNumbersSheet extends StatelessWidget {
  const _CardNumbersSheet({required this.card, required this.secrets, required this.owner});
  final DebitCard card;
  final CardSecrets secrets;
  final String owner;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    Widget row(String label, String value, {bool copy = false}) => ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 24),
          title: Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13.5)),
          subtitle: Text(value,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
          trailing: copy ? const Icon(Icons.copy, size: 18) : null,
          onTap: copy
              ? () {
                  Clipboard.setData(ClipboardData(text: value.replaceAll(' ', '')));
                  ScaffoldMessenger.of(context)
                      .showSnackBar(SnackBar(content: Text(s.copied), behavior: SnackBarBehavior.floating));
                }
              : null,
        );
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
            child: Text(card.product, style: Theme.of(context).textTheme.titleLarge),
          ),
          row(s.cardNumber, secrets.pan, copy: true),
          row(s.holder, owner),
          Row(
            children: [
              Expanded(child: row(s.expiry, card.expiry)),
              Expanded(child: row(s.cvv, secrets.cvv)),
            ],
          ),
          row(s.linkedAccount, card.accountNumber),
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}

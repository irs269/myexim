import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/app_scope.dart';
import '../../core/l10n/strings.dart';
import '../../core/theme/app_colors.dart';
import '../../data/bank_repository.dart' show WalletCorridor, corridorFor, flagForCountry, walletCorridors;
import '../../data/models.dart';
import '../../shared/widgets.dart';
import '../auth/auth_widgets.dart';
import 'amount_screen.dart';
import 'send_flow.dart';

/// Banques de la place proposées pour un virement hors Exim.
const otherBanks = [
  'BIC Comores',
  'Banque de Développement des Comores',
  'Banque Fédérale de Commerce',
  'SNPSF (Poste)',
  'Union des Meck',
  'Sanduk',
];

enum RecipientType { exim, otherBank, mobileMoney }

/// Ajout d'un bénéficiaire : client Exim ou portefeuille Mobile Money (titulaire vérifié), ou autre banque.
/// Mobile Money : Comores (MVola) en direct, autres pays via Onafriq.
/// Pendant un envoi, enchaîne sur le montant ; en mode [addOnly], enregistre et revient.
class NewRecipientScreen extends StatefulWidget {
  const NewRecipientScreen({
    super.key,
    this.from,
    this.addOnly = false,
    this.initialType = RecipientType.exim,
    this.initialCountry,
  });
  final Account? from;
  final bool addOnly;
  final RecipientType initialType;

  /// Pays Mobile Money présélectionné (ISO) ; par défaut les Comores.
  final String? initialCountry;

  @override
  State<NewRecipientScreen> createState() => _NewRecipientScreenState();
}

class _NewRecipientScreenState extends State<NewRecipientScreen> {
  final _form = GlobalKey<FormState>();
  final _account = TextEditingController();
  final _name = TextEditingController();
  late RecipientType _type = widget.initialType;
  String _bank = otherBanks.first;
  late WalletCorridor _corridor = corridorFor(widget.initialCountry);
  late String _provider = _corridor.operators.first;
  bool _save = true;
  bool _busy = false;

  // Vérification du titulaire (client Exim ou portefeuille Mobile Money)
  Timer? _debounce;
  bool _looking = false;
  String? _foundName;
  bool _notFound = false;

  bool get _verified => _type != RecipientType.otherBank;

  @override
  void initState() {
    super.initState();
    _account.addListener(_onAccountChanged);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _account.dispose();
    _name.dispose();
    super.dispose();
  }

  void _setType(RecipientType type) {
    if (type == _type) return;
    _debounce?.cancel();
    setState(() {
      _type = type;
      _account.clear();
      _foundName = null;
      _notFound = false;
      _looking = false;
    });
  }

  /// Numéro saisi, normalisé : compte sans espaces, ou téléphone au format international
  /// (indicatif du pays + numéro national sans le 0 initial).
  String get _number {
    final raw = _account.text.replaceAll(RegExp(r'\s'), '');
    if (_type != RecipientType.mobileMoney) return raw;
    var digits = raw.replaceAll(RegExp(r'\D'), '');
    // Indicatif saisi par erreur (269…, 00269…) ou 0 initial : on garde le numéro national.
    final dial = _corridor.dialCode.replaceAll('+', '');
    if (digits.startsWith('00$dial')) digits = digits.substring(2 + dial.length);
    if (digits.startsWith(dial) && digits.length == dial.length + _corridor.localDigits) {
      digits = digits.substring(dial.length);
    }
    digits = digits.replaceFirst(RegExp(r'^0'), '');
    return '${_corridor.dialCode}$digits';
  }

  /// Message de format quand le numéro Mobile Money est complet mais invalide.
  String? _walletFormatError(S s) {
    if (_type != RecipientType.mobileMoney) return null;
    final local = _number.replaceFirst(_corridor.dialCode, '');
    if (local.length < _corridor.localDigits) return null;
    return _walletNumberComplete ? null : s.walletFormat(_corridor.localDigits, international: _corridor.isInternational);
  }

  bool get _walletNumberComplete {
    final local = _number.replaceFirst(_corridor.dialCode, '');
    if (!_corridor.isInternational) return RegExp(r'^[34]\d{6}$').hasMatch(local);
    return local.length == _corridor.localDigits;
  }

  void _setCountry(WalletCorridor c) {
    setState(() {
      _corridor = c;
      _provider = c.operators.first;
      _account.clear();
      _foundName = null;
      _notFound = false;
    });
  }

  void _onAccountChanged() {
    if (!_verified) return;
    _debounce?.cancel();
    setState(() {
      _foundName = null;
      _notFound = false;
    });
    final number = _number;
    final complete = _type == RecipientType.mobileMoney ? _walletNumberComplete : number.length >= 11;
    if (!complete) return;
    _debounce = Timer(const Duration(milliseconds: 400), () async {
      setState(() => _looking = true);
      final repo = AppScope.repo(context);
      final name = _type == RecipientType.mobileMoney
          ? await repo.lookupWallet(countryCode: _corridor.countryCode, provider: _provider, phone: number)
          : await repo.lookupEximAccount(number);
      if (!mounted || _number != number) return;
      setState(() {
        _looking = false;
        _foundName = name;
        _notFound = name == null;
      });
    });
  }

  bool get _canContinue => _verified ? _foundName != null : true;

  Future<void> _continue() async {
    if (!_verified && !_form.currentState!.validate()) return;
    final repo = AppScope.repo(context);
    final navigator = Navigator.of(context);
    var beneficiary = Beneficiary(
      id: 'new',
      name: _verified ? _foundName! : _name.text.trim(),
      accountNumber: _number,
      bankName: switch (_type) {
        RecipientType.exim => 'Exim Bank',
        RecipientType.otherBank => _bank,
        RecipientType.mobileMoney =>
          _corridor.isInternational ? '$_provider · ${_corridor.name(french: S.of(context).french)}' : _provider,
      },
      isEximCustomer: _type == RecipientType.exim,
      walletProvider: _type == RecipientType.mobileMoney ? _provider : null,
      countryCode: _type == RecipientType.mobileMoney && _corridor.isInternational ? _corridor.countryCode : null,
      currency: _type == RecipientType.mobileMoney ? _corridor.currency : 'KMF',
    );
    setState(() => _busy = true);
    try {
      if (widget.addOnly) {
        final saved = await repo.addBeneficiary(beneficiary);
        navigator.pop(saved);
        return;
      }
      if (_save) beneficiary = await repo.addBeneficiary(beneficiary);
      final accounts = await repo.getAccounts();
      final from = widget.from ?? defaultSourceAccount(accounts, beneficiary.currency);
      navigator.pushReplacement(
        MaterialPageRoute(
          builder: (_) => AmountScreen(
            draft: TransferDraft(from: from, to: TransferDestination.beneficiary(beneficiary)),
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final fieldLabel = switch (_type) {
      RecipientType.exim => s.accountNumberLabel,
      RecipientType.otherBank => s.ibanOrAccount,
      RecipientType.mobileMoney => _corridor.isInternational ? s.walletNumberGeneric : s.walletNumber,
    };
    Widget dropdown(String label, String value, List<String> options, ValueChanged<String> onChanged) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              initialValue: value,
              items: [for (final o in options) DropdownMenuItem(value: o, child: Text(o))],
              onChanged: (v) => onChanged(v ?? value),
              decoration: InputDecoration(
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.navy, width: 1.5),
                ),
              ),
            ),
            const SizedBox(height: 18),
          ],
        );

    return Form(
      key: _form,
      child: AuthScaffold(
        title: widget.addOnly ? s.addRecipient : s.newRecipient,
        bottom: PrimaryButton(
          label: widget.addOnly ? s.save : s.continueLabel,
          loading: _busy,
          onPressed: _canContinue ? _continue : null,
        ),
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final (type, label) in [
                (RecipientType.exim, s.eximCustomer),
                (RecipientType.otherBank, s.otherBank),
                (RecipientType.mobileMoney, s.mobileMoney),
              ])
                PillButton(
                  label: label,
                  dense: true,
                  icon: type == RecipientType.mobileMoney ? Icons.phone_android : null,
                  variant: _type == type ? PillVariant.primary : PillVariant.outline,
                  onPressed: () => _setType(type),
                ),
            ],
          ),
          const SizedBox(height: 24),
          if (_type == RecipientType.otherBank) dropdown(s.bankName, _bank, otherBanks, (v) => setState(() => _bank = v)),
          if (_type == RecipientType.mobileMoney) ...[
            Text(s.country, style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              key: const ValueKey('country'),
              initialValue: _corridor.countryCode,
              isExpanded: true,
              items: [
                for (final c in walletCorridors)
                  DropdownMenuItem(
                    value: c.countryCode,
                    child: Text('${flagForCountry(c.countryCode)}  ${c.name(french: s.french)}  (${c.currency})'),
                  ),
              ],
              onChanged: (v) => _setCountry(corridorFor(v)),
              decoration: InputDecoration(
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.navy, width: 1.5),
                ),
              ),
            ),
            if (_corridor.isInternational)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Row(
                  children: [
                    const Icon(Icons.public, size: 18, color: AppColors.navy),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(s.viaNetwork(_corridor.network!), style: const TextStyle(color: AppColors.textSecondary)),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 18),
            // La clé force la reconstruction quand le pays (donc la liste d'opérateurs) change.
            KeyedSubtree(
              key: ValueKey('operator-${_corridor.countryCode}'),
              child: dropdown(s.operator, _provider, _corridor.operators, (v) {
                setState(() => _provider = v);
                _onAccountChanged();
              }),
            ),
          ],
          Padding(
            padding: const EdgeInsets.only(bottom: 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(fieldLabel, style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
                const SizedBox(height: 8),
                TextFormField(
                  key: ValueKey('$_type-${_corridor.countryCode}'),
                  controller: _account,
                  keyboardType: _type == RecipientType.otherBank ? TextInputType.text : TextInputType.number,
                  inputFormatters: [
                    if (_type == RecipientType.mobileMoney) FilteringTextInputFormatter.allow(RegExp(r'[0-9\s]')),
                  ],
                  validator: (v) => (v == null || v.replaceAll(RegExp(r'\s'), '').length < 7) ? s.requiredField : null,
                  onChanged: (_) => setState(() {}),
                  style: const TextStyle(fontSize: 17),
                  decoration: InputDecoration(
                    helperText: _type == RecipientType.mobileMoney
                        ? s.walletFormat(_corridor.localDigits, international: _corridor.isInternational)
                        : null,
                    errorText: _walletFormatError(s),
                    // Indicatif toujours visible (prefixText n'apparaît qu'au focus).
                    prefixIcon: _type == RecipientType.mobileMoney
                        ? Padding(
                            padding: const EdgeInsets.only(left: 16, right: 4),
                            child: Text(_corridor.dialCode, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
                          )
                        : null,
                    prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.border)),
                    focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.navy, width: 1.5)),
                  ),
                ),
              ],
            ),
          ),
          if (_verified)
            _LookupResult(
              looking: _looking,
              name: _foundName,
              notFound: _notFound,
              wallet: _type == RecipientType.mobileMoney,
            ),
          if (_type == RecipientType.otherBank)
            LabeledField(
              label: s.recipientName,
              controller: _name,
              textInputAction: TextInputAction.done,
              validator: (v) => (v == null || v.trim().length < 3) ? s.requiredField : null,
            ),
          if (!widget.addOnly)
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              activeColor: AppColors.navy,
              value: _save,
              onChanged: (v) => setState(() => _save = v ?? true),
              title: Text(s.saveRecipient),
            ),
        ],
      ),
    );
  }
}

class _LookupResult extends StatelessWidget {
  const _LookupResult({required this.looking, required this.name, required this.notFound, required this.wallet});
  final bool looking;
  final String? name;
  final bool notFound;
  final bool wallet;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    if (looking) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: Row(
          children: [
            const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.navy),
            ),
            const SizedBox(width: 10),
            Text(wallet ? s.checkingWallet : s.checkingAccount, style: const TextStyle(color: AppColors.textSecondary)),
          ],
        ),
      );
    }
    if (notFound) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: Text(
          wallet ? s.walletNotFound : s.accountNotFound,
          style: const TextStyle(color: AppColors.danger, fontWeight: FontWeight.w600),
        ),
      );
    }
    if (name == null) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(16)),
      child: Row(
        children: [
          InitialsAvatar(name: name!, size: 44, badge: !wallet, wallet: wallet),
          const SizedBox(width: 14),
          Expanded(
            child: Text(name!, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
          ),
          const Icon(Icons.verified, color: AppColors.success),
        ],
      ),
    );
  }
}

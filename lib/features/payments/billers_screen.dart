import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/app_scope.dart';
import '../../core/l10n/strings.dart';
import '../../core/theme/app_colors.dart';
import '../../data/models.dart';
import '../../shared/widgets.dart';
import '../auth/auth_widgets.dart';
import 'payment_review_screen.dart';

IconData billerIcon(BillerCategory c) => switch (c) {
      BillerCategory.electricity => Icons.bolt,
      BillerCategory.water => Icons.water_drop_outlined,
      BillerCategory.telecom => Icons.wifi,
      BillerCategory.airtime => Icons.phone_android,
      BillerCategory.tv => Icons.tv,
      BillerCategory.government => Icons.account_balance,
    };

/// Liste des organismes, groupés par catégorie. [airtimeOnly] : recharges uniquement.
class BillersScreen extends StatefulWidget {
  const BillersScreen({super.key, this.airtimeOnly = false});
  final bool airtimeOnly;

  @override
  State<BillersScreen> createState() => _BillersScreenState();
}

class _BillersScreenState extends State<BillersScreen> {
  Future<List<Biller>>? _billers;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _billers ??= AppScope.repo(context).getBillers();
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return Scaffold(
      body: SafeArea(
        child: AsyncView(
          future: _billers!,
          builder: (context, all) {
            final billers = all.where((b) => widget.airtimeOnly ? b.isAirtime : !b.isAirtime).toList();
            final categories = BillerCategory.values.where((c) => billers.any((b) => b.category == c));
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
                ScreenTitle(widget.airtimeOnly ? s.airtime : s.chooseBiller),
                for (final c in categories) ...[
                  if (!widget.airtimeOnly) SectionLabel(s.billerCategory(c.index)),
                  for (final b in billers.where((b) => b.category == c))
                    ListRow(
                      leading: CircleIcon(icon: billerIcon(c), size: 52, bg: AppColors.primarySoft, fg: AppColors.navy),
                      title: b.name,
                      subtitle: s.referenceLabel(b.referenceLabel),
                      onTap: () => Navigator.of(context)
                          .push(MaterialPageRoute(builder: (_) => BillReferenceScreen(biller: b))),
                    ),
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}

/// Saisie de la référence (compteur, contrat, téléphone…) puis recherche de la facture.
class BillReferenceScreen extends StatefulWidget {
  const BillReferenceScreen({super.key, required this.biller});
  final Biller biller;

  @override
  State<BillReferenceScreen> createState() => _BillReferenceScreenState();
}

class _BillReferenceScreenState extends State<BillReferenceScreen> {
  final _form = GlobalKey<FormState>();
  final _ref = TextEditingController();
  bool _loading = false;

  /// Erreur affichée sous le champ (un message flottant masquerait le bouton).
  String? _error;

  @override
  void dispose() {
    _ref.dispose();
    super.dispose();
  }

  Future<void> _find() async {
    if (!_form.currentState!.validate()) return;
    final s = S.of(context);
    final navigator = Navigator.of(context);
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final request = await AppScope.repo(context).lookupBill(biller: widget.biller, reference: _ref.text.trim());
      navigator.push(MaterialPageRoute(
        builder: (_) => PaymentReviewScreen(
          request: request,
          suggestedAmounts: widget.biller.fixedAmounts,
          category: widget.biller.category,
        ),
      ));
    } on TransferException {
      if (mounted) setState(() => _error = widget.biller.isAirtime ? s.invalidPhone : s.billNotFound);
    } catch (_) {
      if (mounted) setState(() => _error = s.genericError);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final b = widget.biller;
    return Form(
      key: _form,
      child: AuthScaffold(
        title: b.name,
        subtitle: s.billerCategory(b.category.index),
        bottom: PrimaryButton(
          label: b.isAirtime ? s.continueWithNumber : s.findBill,
          loading: _loading,
          onPressed: _find,
        ),
        children: [
          Text(s.referenceLabel(b.referenceLabel),
              style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
          const SizedBox(height: 8),
          TextFormField(
            controller: _ref,
            autofocus: true,
            keyboardType: b.isAirtime ? TextInputType.phone : TextInputType.text,
            textCapitalization: TextCapitalization.characters,
            inputFormatters: [if (b.isAirtime) FilteringTextInputFormatter.allow(RegExp(r'[0-9+\s]'))],
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
            validator: (v) => (v == null || v.trim().length < 5) ? s.requiredField : null,
            onFieldSubmitted: (_) => _find(),
            onChanged: (_) {
              if (_error != null) setState(() => _error = null);
            },
            decoration: InputDecoration(
              errorText: _error,
              prefixText: b.isAirtime ? '+269 ' : null,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.border)),
              focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.navy, width: 1.5)),
            ),
          ),
        ],
      ),
    );
  }
}

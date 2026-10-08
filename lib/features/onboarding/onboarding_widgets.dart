import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../core/theme/app_colors.dart';
import '../../data/auth_repository.dart';

/// Données saisies au fil du parcours d'ouverture de compte.
class OnboardingDraft {
  String nin = '';
  String phone = '';
  String email = '';
  String token = '';
  Hand hand = Hand.right;
  IdentityRecord? identity;
  double? annualIncome;
  int? employment;
  String building = '';
  String street = '';
  String city = '';
  String country = 'UNION DES COMORES';
  String? branch;
}

const comorosCities = [
  'Moroni', 'Mitsamiouli', 'Foumbouni', 'Mbéni', 'Iconi', 'Mitsoudjé', // Ngazidja
  'Mutsamudu', 'Domoni', 'Ouani', 'Sima', // Ndzuwani
  'Fomboni', 'Nioumachoua', // Mwali
];

const eximBranches = [
  'Moroni — Siège',
  'Moroni — Volo-Volo',
  'Mitsamiouli',
  'Foumbouni',
  'Mutsamudu',
  'Fomboni',
];

/// Référence de la demande d'ouverture en cours, conservée sur l'appareil pour le suivi.
class OnboardingStore {
  OnboardingStore._();

  static const _key = 'onboarding_ref';
  static const _guideKey = 'onboarding_hide_scan_guide';
  static const _storage = FlutterSecureStorage();

  /// Écoutée par l'écran d'accueil pour afficher « Suivre ma demande ».
  static final pendingRef = ValueNotifier<String?>(null);

  static Future<void> load() async {
    try {
      pendingRef.value = await _storage.read(key: _key);
    } catch (_) {
      pendingRef.value = null;
    }
  }

  static Future<void> save(String ref) async {
    await _storage.write(key: _key, value: ref);
    pendingRef.value = ref;
  }

  static Future<void> clear() async {
    await _storage.delete(key: _key);
    pendingRef.value = null;
  }

  static Future<bool> hideScanGuide() async => await _storage.read(key: _guideKey) == 'true';
  static Future<void> setHideScanGuide(bool v) => _storage.write(key: _guideKey, value: v.toString());
}

/// Gabarit des écrans d'ouverture : en-tête bleu marine, barre d'étapes, contenu, bouton bas.
class OnboardingScaffold extends StatelessWidget {
  const OnboardingScaffold({
    super.key,
    required this.title,
    required this.children,
    this.completedSteps,
    this.nextLabel,
    this.bottom,
    this.canPop = true,
  });
  final String title;
  final List<Widget> children;

  /// Segments remplis (sur 3) ; null = pas de barre d'étapes.
  final int? completedSteps;
  final String? nextLabel;
  final Widget? bottom;
  final bool canPop;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [AppColors.navyDark, AppColors.navy],
              ),
            ),
            child: SafeArea(
              bottom: false,
              child: SizedBox(
                width: double.infinity,
                height: 72,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    if (canPop && Navigator.of(context).canPop())
                      Positioned(
                        left: 8,
                        child: IconButton(
                          icon: const Icon(Icons.arrow_back, color: Colors.white),
                          onPressed: () => Navigator.of(context).maybePop(),
                        ),
                      ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 56),
                      child: Text(
                        title,
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
              children: [
                if (completedSteps != null) ...[
                  StepSegments(completed: completedSteps!),
                  if (nextLabel != null) ...[
                    const SizedBox(height: 10),
                    Text(nextLabel!, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.textSecondary)),
                  ],
                  const SizedBox(height: 20),
                ],
                ...children,
              ],
            ),
          ),
          if (bottom != null)
            SafeArea(
              top: false,
              child: Padding(padding: const EdgeInsets.fromLTRB(24, 0, 24, 16), child: bottom),
            ),
        ],
      ),
    );
  }
}

class StepSegments extends StatelessWidget {
  const StepSegments({super.key, required this.completed, this.total = 3});
  final int completed;
  final int total;

  @override
  Widget build(BuildContext context) => Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (var i = 0; i < total; i++)
            Container(
              width: 72,
              height: 6,
              margin: const EdgeInsets.symmetric(horizontal: 5),
              decoration: BoxDecoration(
                color: i < completed ? AppColors.navy : AppColors.surfaceAlt,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
        ],
      );
}

/// Champ souligné avec libellé et coche bleue quand la saisie est valide.
class LineField extends StatefulWidget {
  const LineField({
    super.key,
    required this.label,
    required this.controller,
    this.validator,
    this.keyboardType,
    this.prefixText,
    this.readOnly = false,
    this.textInputAction = TextInputAction.next,
  });
  final String label;
  final TextEditingController controller;
  final String? Function(String?)? validator;
  final TextInputType? keyboardType;
  final String? prefixText;
  final bool readOnly;
  final TextInputAction textInputAction;

  @override
  State<LineField> createState() => _LineFieldState();
}

class _LineFieldState extends State<LineField> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_changed);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_changed);
    super.dispose();
  }

  void _changed() => setState(() {});

  @override
  Widget build(BuildContext context) {
    final text = widget.controller.text;
    final valid = text.isNotEmpty && (widget.validator?.call(text) == null);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: TextFormField(
        controller: widget.controller,
        validator: widget.validator,
        keyboardType: widget.keyboardType,
        readOnly: widget.readOnly,
        textInputAction: widget.textInputAction,
        style: const TextStyle(fontSize: 17),
        decoration: InputDecoration(
          labelText: widget.label,
          prefixText: widget.prefixText,
          floatingLabelStyle: const TextStyle(color: AppColors.textSecondary),
          border: const UnderlineInputBorder(borderSide: BorderSide(color: AppColors.border)),
          enabledBorder: const UnderlineInputBorder(borderSide: BorderSide(color: AppColors.border)),
          focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: AppColors.navy, width: 1.5)),
          contentPadding: const EdgeInsets.symmetric(vertical: 8),
          suffixIcon: valid ? const Icon(Icons.check_circle, color: AppColors.navy) : null,
        ),
      ),
    );
  }
}

/// Liste déroulante soulignée.
class LineDropdown<T> extends StatelessWidget {
  const LineDropdown({
    super.key,
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
    this.hint,
    this.validator,
  });
  final String label;
  final T? value;
  final List<(T, String)> items;
  final ValueChanged<T?> onChanged;
  final String? hint;
  final String? Function(T?)? validator;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: DropdownButtonFormField<T>(
          initialValue: value,
          isExpanded: true,
          hint: hint == null ? null : Text(hint!),
          icon: const Icon(Icons.keyboard_arrow_down),
          items: [for (final (v, l) in items) DropdownMenuItem(value: v, child: Text(l))],
          onChanged: onChanged,
          validator: validator,
          decoration: InputDecoration(
            labelText: label,
            contentPadding: const EdgeInsets.symmetric(vertical: 8),
            border: const UnderlineInputBorder(borderSide: BorderSide(color: AppColors.border)),
            enabledBorder: const UnderlineInputBorder(borderSide: BorderSide(color: AppColors.border)),
            focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: AppColors.navy, width: 1.5)),
          ),
        ),
      );
}

/// Ligne « libellé / valeur » des écrans de confirmation.
class InfoRow extends StatelessWidget {
  const InfoRow({super.key, required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.surfaceAlt))),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 14)),
            if (value.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(value, style: const TextStyle(fontSize: 16.5)),
            ],
          ],
        ),
      );
}

/// Carte blanche posée sur un fond bleu marine incurvé (écrans « Ouvrir un compte », « Vérification réussie »).
class CurvedCardScaffold extends StatelessWidget {
  const CurvedCardScaffold({super.key, required this.child, this.canPop = true});
  final Widget child;
  final bool canPop;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F7F7),
      body: Stack(
        children: [
          ClipPath(
            clipper: _BottomCurve(),
            child: Container(
              height: 360,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [AppColors.navy, AppColors.navyDark],
                ),
              ),
              child: const Align(
                alignment: Alignment(0, -0.1),
                child: Icon(Icons.phone_iphone_rounded, size: 150, color: Color(0x40FFFFFF)),
              ),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                if (canPop && Navigator.of(context).canPop())
                  Align(
                    alignment: Alignment.centerLeft,
                    child: IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                      onPressed: () => Navigator.of(context).maybePop(),
                    ),
                  )
                else
                  const SizedBox(height: 48),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 140, 20, 24),
                    child: Container(
                      padding: const EdgeInsets.fromLTRB(22, 24, 22, 24),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: const [BoxShadow(color: Color(0x22000000), blurRadius: 24, offset: Offset(0, 10))],
                      ),
                      child: child,
                    ),
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

class _BottomCurve extends CustomClipper<Path> {
  @override
  Path getClip(Size size) => Path()
    ..lineTo(0, size.height - 60)
    ..quadraticBezierTo(size.width / 2, size.height + 40, size.width, size.height - 60)
    ..lineTo(size.width, 0)
    ..close();

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}

/// Bouton bleu marine rectangulaire du parcours (style de l'app Exim actuelle).
class OnboardingButton extends StatelessWidget {
  const OnboardingButton({super.key, required this.label, required this.onPressed, this.loading = false});
  final String label;
  final VoidCallback? onPressed;
  final bool loading;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: double.infinity,
        height: 54,
        child: FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.navy,
            disabledBackgroundColor: AppColors.surfaceAlt,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            textStyle: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
          ),
          onPressed: loading ? null : onPressed,
          child: loading
              ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: AppColors.navy))
              : Text(label),
        ),
      );
}

/// Capture des empreintes : par défaut une photo des doigts ; à remplacer par le kit
/// biométrique du prestataire (et par une fausse capture dans les tests).
typedef FingerprintCapture = Future<String?> Function(BuildContext context, Hand hand);

FingerprintCapture? fingerprintCaptureOverride;

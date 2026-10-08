import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/l10n/strings.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/widgets.dart';

/// Monogramme « EB » officiel (image extraite du logo Exim Bank).
class EximMonogram extends StatelessWidget {
  const EximMonogram({super.key, this.height = 56});
  final double height;

  @override
  Widget build(BuildContext context) =>
      Image.asset('assets/images/exim_monogram.png', height: height, filterQuality: FilterQuality.high);
}

/// Logo Exim Bank : monogramme officiel, nom en capitales à empattements et signature.
/// [onDark] passe le texte en blanc pour les fonds bleu marine.
class EximLogo extends StatelessWidget {
  const EximLogo({super.key, this.onDark = false, this.scale = 1});
  final bool onDark;
  final double scale;

  @override
  Widget build(BuildContext context) {
    final textColor = onDark ? Colors.white : AppColors.brandBlue;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        EximMonogram(height: 60 * scale),
        SizedBox(width: 12 * scale),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('EXIM BANK',
                style: TextStyle(
                    color: textColor,
                    fontSize: 25 * scale,
                    fontFamily: 'serif',
                    fontWeight: FontWeight.w700,
                    letterSpacing: 3 * scale)),
            Container(height: 1, width: 170 * scale, color: textColor.withValues(alpha: 0.7)),
            SizedBox(height: 2 * scale),
            Text(S.of(context).slogan,
                style: TextStyle(color: textColor, fontSize: 12.5 * scale, fontStyle: FontStyle.italic, fontFamily: 'serif')),
          ],
        ),
      ],
    );
  }
}

/// Bouton pleine largeur avec état de chargement.
class PrimaryButton extends StatelessWidget {
  const PrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.loading = false,
    this.background = AppColors.primary,
    this.foreground = AppColors.onPrimary,
  });
  final String label;
  final VoidCallback? onPressed;
  final bool loading;
  final Color background;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: FilledButton(
        style: FilledButton.styleFrom(
          backgroundColor: background,
          foregroundColor: foreground,
          disabledBackgroundColor: AppColors.surfaceAlt,
          shape: const StadiumBorder(),
          textStyle: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
        ),
        onPressed: loading ? null : onPressed,
        child: loading
            ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: AppColors.navy))
            : Text(label),
      ),
    );
  }
}

/// Gabarit des écrans d'authentification : retour, grand titre, contenu, bouton en bas.
class AuthScaffold extends StatelessWidget {
  const AuthScaffold({super.key, required this.title, this.subtitle, required this.children, this.bottom, this.canPop = true});
  final String title;
  final String? subtitle;
  final List<Widget> children;
  final Widget? bottom;
  final bool canPop;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: canPop
                        ? RoundIconButton(icon: Icons.arrow_back, onPressed: () => Navigator.of(context).maybePop())
                        : const SizedBox(height: 48),
                  ),
                  const SizedBox(height: 20),
                  Text(title, style: Theme.of(context).textTheme.headlineMedium),
                  if (subtitle != null) ...[
                    const SizedBox(height: 10),
                    Text(subtitle!, style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: AppColors.textSecondary)),
                  ],
                  const SizedBox(height: 28),
                  ...children,
                ],
              ),
            ),
            if (bottom != null) Padding(padding: const EdgeInsets.fromLTRB(24, 0, 24, 16), child: bottom),
          ],
        ),
      ),
    );
  }
}

/// Champ texte façon Wise : libellé au-dessus, bord arrondi.
class LabeledField extends StatelessWidget {
  const LabeledField({
    super.key,
    required this.label,
    required this.controller,
    this.obscure = false,
    this.keyboardType,
    this.validator,
    this.textInputAction = TextInputAction.next,
    this.onSubmitted,
    this.autofillHints,
  });
  final String label;
  final TextEditingController controller;
  final bool obscure;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;
  final TextInputAction textInputAction;
  final void Function(String)? onSubmitted;
  final Iterable<String>? autofillHints;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
          const SizedBox(height: 8),
          _ObscurableField(
            controller: controller,
            obscure: obscure,
            keyboardType: keyboardType,
            validator: validator,
            textInputAction: textInputAction,
            onSubmitted: onSubmitted,
            autofillHints: autofillHints,
          ),
        ],
      ),
    );
  }
}

class _ObscurableField extends StatefulWidget {
  const _ObscurableField({
    required this.controller,
    required this.obscure,
    this.keyboardType,
    this.validator,
    required this.textInputAction,
    this.onSubmitted,
    this.autofillHints,
  });
  final TextEditingController controller;
  final bool obscure;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;
  final TextInputAction textInputAction;
  final void Function(String)? onSubmitted;
  final Iterable<String>? autofillHints;

  @override
  State<_ObscurableField> createState() => _ObscurableFieldState();
}

class _ObscurableFieldState extends State<_ObscurableField> {
  late bool _hidden = widget.obscure;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: widget.controller,
      obscureText: _hidden,
      keyboardType: widget.keyboardType,
      validator: widget.validator,
      textInputAction: widget.textInputAction,
      onFieldSubmitted: widget.onSubmitted,
      autofillHints: widget.autofillHints,
      style: const TextStyle(fontSize: 17),
      decoration: InputDecoration(
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.border)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.navy, width: 1.5)),
        errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.danger)),
        focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.danger, width: 1.5)),
        suffixIcon: widget.obscure
            ? IconButton(
                icon: Icon(_hidden ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                onPressed: () => setState(() => _hidden = !_hidden),
              )
            : null,
      ),
    );
  }
}

/// Saisie OTP en 6 cases ; un seul TextField invisible porte le clavier et l'autofill SMS.
class OtpField extends StatefulWidget {
  const OtpField({super.key, required this.onCompleted, this.length = 6, this.hasError = false, this.controller});
  final void Function(String) onCompleted;
  final int length;
  final bool hasError;
  final TextEditingController? controller;

  @override
  State<OtpField> createState() => _OtpFieldState();
}

class _OtpFieldState extends State<OtpField> {
  late final TextEditingController _ctrl = widget.controller ?? TextEditingController();
  final _focus = FocusNode();
  String? _lastCompleted;

  @override
  void initState() {
    super.initState();
    _ctrl.addListener(_onChanged);
  }

  // Le listener se déclenche aussi sur les changements de sélection :
  // on ne notifie qu'une fois par code complet.
  void _onChanged() {
    setState(() {});
    final text = _ctrl.text;
    if (text.length < widget.length) {
      _lastCompleted = null;
    } else if (text != _lastCompleted) {
      _lastCompleted = text;
      widget.onCompleted(text);
    }
  }

  @override
  void dispose() {
    _ctrl.removeListener(_onChanged);
    if (widget.controller == null) _ctrl.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final text = _ctrl.text;
    return GestureDetector(
      onTap: () => _focus.requestFocus(),
      child: Stack(
        children: [
          Opacity(
            opacity: 0,
            child: TextField(
              controller: _ctrl,
              focusNode: _focus,
              autofocus: true,
              keyboardType: TextInputType.number,
              autofillHints: const [AutofillHints.oneTimeCode],
              maxLength: widget.length,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              for (var i = 0; i < widget.length; i++)
                AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  width: 48,
                  height: 60,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      width: i == text.length ? 2 : 1,
                      color: widget.hasError
                          ? AppColors.danger
                          : i == text.length
                              ? AppColors.navy
                              : AppColors.border,
                    ),
                  ),
                  child: Text(i < text.length ? text[i] : '', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700)),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Points indiquant la progression de la saisie du PIN.
class PinDots extends StatelessWidget {
  const PinDots({super.key, required this.filled, this.length = 4, this.error = false});
  final int filled;
  final int length;
  final bool error;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < length; i++)
          AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            margin: const EdgeInsets.symmetric(horizontal: 10),
            width: 18,
            height: 18,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: i < filled ? (error ? AppColors.danger : AppColors.navy) : Colors.transparent,
              border: Border.all(color: error ? AppColors.danger : AppColors.navy, width: 2),
            ),
          ),
      ],
    );
  }
}

/// Pavé numérique du PIN. [extraKey] remplace la case vide en bas à gauche (ex. biométrie).
class PinPad extends StatelessWidget {
  const PinPad({super.key, required this.onDigit, required this.onBackspace, this.extraKey});
  final void Function(String) onDigit;
  final VoidCallback onBackspace;
  final Widget? extraKey;

  @override
  Widget build(BuildContext context) {
    Widget key(String d) => _PadKey(
          onTap: () {
            HapticFeedback.selectionClick();
            onDigit(d);
          },
          child: Text(d, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w600)),
        );
    return Column(
      children: [
        for (final row in const [
          ['1', '2', '3'],
          ['4', '5', '6'],
          ['7', '8', '9'],
        ])
          Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [for (final d in row) key(d)]),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            extraKey ?? const SizedBox(width: 80, height: 72),
            key('0'),
            _PadKey(onTap: onBackspace, child: const Icon(Icons.backspace_outlined, size: 26)),
          ],
        ),
      ],
    );
  }
}

class _PadKey extends StatelessWidget {
  const _PadKey({required this.onTap, required this.child});
  final VoidCallback onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: 80,
        height: 72,
        child: InkWell(customBorder: const CircleBorder(), onTap: onTap, child: Center(child: child)),
      );
}

void showErrorSnack(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      content: Text(message),
      backgroundColor: AppColors.danger,
      behavior: SnackBarBehavior.floating,
    ));
}

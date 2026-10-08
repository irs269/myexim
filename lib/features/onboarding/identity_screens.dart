import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/app_scope.dart';
import '../../core/l10n/strings.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../data/auth_repository.dart';
import '../auth/auth_widgets.dart';
import '../auth/otp_screen.dart';
import 'details_screens.dart';
import 'onboarding_widgets.dart';

/// Étape 1 : NIN, mobile et e-mail, puis code SMS.
class AboutYouScreen extends StatefulWidget {
  const AboutYouScreen({super.key});

  @override
  State<AboutYouScreen> createState() => _AboutYouScreenState();
}

class _AboutYouScreenState extends State<AboutYouScreen> {
  final _form = GlobalKey<FormState>();
  final _nin = TextEditingController();
  final _phone = TextEditingController();
  final _email = TextEditingController();
  final _draft = OnboardingDraft();
  bool _loading = false;

  @override
  void dispose() {
    _nin.dispose();
    _phone.dispose();
    _email.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    final s = S.of(context);
    final auth = AppScope.of(context).session.auth;
    final navigator = Navigator.of(context);
    _draft
      ..nin = _nin.text.replaceAll(RegExp(r'\s'), '')
      ..phone = '+269${_phone.text.replaceAll(RegExp(r'\D'), '')}'
      ..email = _email.text.trim();
    setState(() => _loading = true);
    try {
      final challenge = await auth.startOnboarding(nin: _draft.nin, phone: _draft.phone, email: _draft.email);
      navigator.push(MaterialPageRoute(
        builder: (_) => OtpScreen(
          challenge: challenge,
          next: (token) {
            _draft.token = token;
            return IdentityIntroScreen(draft: _draft);
          },
        ),
      ));
    } on AuthException catch (e) {
      if (mounted) showErrorSnack(context, e.message);
    } catch (_) {
      if (mounted) showErrorSnack(context, s.genericError);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return Form(
      key: _form,
      child: OnboardingScaffold(
        title: s.aboutYou,
        children: [
          Text(s.getToKnow,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.navy, fontSize: 18, fontWeight: FontWeight.w600)),
          const SizedBox(height: 16),
          LineField(
            label: s.nin,
            controller: _nin,
            keyboardType: TextInputType.number,
            validator: (v) => (v == null || v.replaceAll(RegExp(r'\s'), '').length < 10) ? s.invalidNin : null,
          ),
          LineField(
            label: s.mobileNumber,
            controller: _phone,
            prefixText: '+269 ',
            keyboardType: TextInputType.phone,
            validator: (v) => RegExp(r'^[34]\d{6}$').hasMatch((v ?? '').replaceAll(RegExp(r'\D'), '')) ? null : s.invalidPhone,
          ),
          LineField(
            label: s.email,
            controller: _email,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.done,
            validator: (v) => RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]{2,}$').hasMatch(v?.trim() ?? '') ? null : s.invalidEmail,
          ),
          const SizedBox(height: 8),
          Text(s.emailNote, style: const TextStyle(color: AppColors.textSecondary, fontSize: 15)),
          const SizedBox(height: 28),
          OnboardingButton(label: s.receiveCode, loading: _loading, onPressed: _submit),
        ],
      ),
    );
  }
}

/// Étape 2 : vérification de l'identité par empreinte.
class IdentityIntroScreen extends StatefulWidget {
  const IdentityIntroScreen({super.key, required this.draft});
  final OnboardingDraft draft;

  @override
  State<IdentityIntroScreen> createState() => _IdentityIntroScreenState();
}

class _IdentityIntroScreenState extends State<IdentityIntroScreen> {
  bool _verifying = false;

  Future<void> _start() async {
    final s = S.of(context);
    final hand = await showDialog<Hand>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(s.handSelection),
        content: Text(s.whichHand),
        actionsAlignment: MainAxisAlignment.spaceEvenly,
        actions: [
          OutlinedButton(onPressed: () => Navigator.of(context).pop(Hand.left), child: Text(s.leftHand)),
          OutlinedButton(onPressed: () => Navigator.of(context).pop(Hand.right), child: Text(s.rightHand)),
        ],
      ),
    );
    if (hand == null || !mounted) return;
    widget.draft.hand = hand;

    if (!await OnboardingStore.hideScanGuide() && mounted) {
      final go = await Navigator.of(context).push<bool>(MaterialPageRoute(builder: (_) => const FingerprintGuideScreen()));
      if (go != true || !mounted) return;
    }
    await _captureAndVerify();
  }

  Future<void> _captureAndVerify() async {
    final s = S.of(context);
    final auth = AppScope.of(context).session.auth;
    final navigator = Navigator.of(context);
    final capture = fingerprintCaptureOverride ?? _cameraCapture;
    final path = await capture(context, widget.draft.hand);
    if (path == null || !mounted) return;
    setState(() => _verifying = true);
    try {
      final record = await auth.verifyIdentity(
        onboardingToken: widget.draft.token,
        nin: widget.draft.nin,
        hand: widget.draft.hand,
        fingerprintPath: path,
      );
      widget.draft.identity = record;
      navigator.push(MaterialPageRoute(builder: (_) => IdentitySuccessScreen(draft: widget.draft)));
    } on AuthException catch (e) {
      if (mounted) showErrorSnack(context, e.message);
    } catch (_) {
      if (mounted) showErrorSnack(context, s.genericError);
    } finally {
      if (mounted) setState(() => _verifying = false);
    }
  }

  /// Photo des doigts par la caméra arrière, en attendant le kit biométrique du prestataire
  /// (détection et capture automatique des empreintes).
  static Future<String?> _cameraCapture(BuildContext context, Hand hand) async {
    final file = await ImagePicker().pickImage(source: ImageSource.camera, imageQuality: 80, maxWidth: 1600);
    return file?.path;
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return Stack(
      children: [
        OnboardingScaffold(
          title: s.verifyIdentity,
          completedSteps: 0,
          children: [
            const SizedBox(height: 12),
            const _IdentityIllustration(),
            const SizedBox(height: 28),
            Text(s.fingerprintIntro,
                textAlign: TextAlign.center, style: const TextStyle(color: AppColors.navy, fontSize: 17, height: 1.45)),
            const SizedBox(height: 32),
            OnboardingButton(label: s.letsScan, onPressed: _verifying ? null : _start),
          ],
        ),
        if (_verifying)
          Positioned.fill(
            child: ColoredBox(
              color: Colors.black45,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const CircularProgressIndicator(color: AppColors.navy),
                      const SizedBox(height: 16),
                      Text(s.verifyingIdentity, style: const TextStyle(fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// Téléphone affichant une carte d'identité validée, entouré de services (pastilles dorées).
class _IdentityIllustration extends StatelessWidget {
  const _IdentityIllustration();

  @override
  Widget build(BuildContext context) {
    Widget badge(IconData icon) => Container(
          width: 52,
          height: 52,
          decoration: const BoxDecoration(color: AppColors.gold, shape: BoxShape.circle),
          child: Icon(icon, color: Colors.white, size: 24),
        );
    return SizedBox(
      height: 240,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 140,
            height: 220,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: AppColors.surfaceAlt, width: 6),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 96,
                  height: 60,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.navy, width: 2),
                  ),
                  child: const Icon(Icons.badge_outlined, color: AppColors.navy, size: 34),
                ),
                const SizedBox(height: 16),
                const CircleAvatar(
                  radius: 18,
                  backgroundColor: AppColors.navy,
                  child: Icon(Icons.check, color: Colors.white, size: 20),
                ),
              ],
            ),
          ),
          Positioned(top: 0, child: badge(Icons.account_balance_wallet_outlined)),
          Positioned(left: 30, child: badge(Icons.shopping_cart_outlined)),
          Positioned(right: 30, child: badge(Icons.payments_outlined)),
          Positioned(bottom: 0, child: badge(Icons.fingerprint)),
        ],
      ),
    );
  }
}

/// Conseils de capture des empreintes (option « Ne plus afficher »).
class FingerprintGuideScreen extends StatefulWidget {
  const FingerprintGuideScreen({super.key});

  @override
  State<FingerprintGuideScreen> createState() => _FingerprintGuideScreenState();
}

class _FingerprintGuideScreenState extends State<FingerprintGuideScreen> {
  bool _hide = false;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final tips = [s.scanTip1, s.scanTip2, s.scanTip3, s.scanTip4];
    return Scaffold(
      backgroundColor: const Color(0xFFA9D3F5),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(24),
                children: [
                  Container(
                    height: 260,
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.back_hand_outlined, size: 110, color: Color(0xFFE0A93A)),
                        SizedBox(width: 12),
                        Icon(Icons.phone_android, size: 120, color: AppColors.navy),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  for (final (i, tip) in tips.indexed)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 14),
                      child: Text('${i + 1}. $tip', style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w600)),
                    ),
                ],
              ),
            ),
            Container(
              color: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: Row(
                children: [
                  Checkbox(value: _hide, activeColor: AppColors.navy, onChanged: (v) => setState(() => _hide = v ?? false)),
                  Expanded(child: Text(s.dontShowAgain)),
                  FilledButton(
                    style: FilledButton.styleFrom(backgroundColor: const Color(0xFF3FA9E8)),
                    onPressed: () async {
                      final navigator = Navigator.of(context);
                      if (_hide) await OnboardingStore.setHideScanGuide(true);
                      navigator.pop(true);
                    },
                    child: Text(s.next),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class IdentitySuccessScreen extends StatelessWidget {
  const IdentitySuccessScreen({super.key, required this.draft});
  final OnboardingDraft draft;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return CurvedCardScaffold(
      canPop: false,
      child: Column(
        children: [
          Text(s.successful,
              style: const TextStyle(color: AppColors.navy, fontSize: 24, fontWeight: FontWeight.w700, fontFamily: 'serif')),
          const SizedBox(height: 24),
          Container(
            width: 112,
            height: 112,
            decoration: BoxDecoration(
              color: AppColors.primarySoft,
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.border),
            ),
            child: const Icon(Icons.check_rounded, size: 72, color: AppColors.navy),
          ),
          const SizedBox(height: 24),
          Text(s.identityValidated, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.navy, fontSize: 17)),
          const SizedBox(height: 32),
          OnboardingButton(
            label: s.proceed,
            onPressed: () => Navigator.of(context)
                .pushReplacement(MaterialPageRoute(builder: (_) => ConfirmIdentityScreen(draft: draft))),
          ),
        ],
      ),
    );
  }
}

/// Données renvoyées par le registre national, à confirmer par le client.
class ConfirmIdentityScreen extends StatelessWidget {
  const ConfirmIdentityScreen({super.key, required this.draft});
  final OnboardingDraft draft;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final id = draft.identity!;
    return OnboardingScaffold(
      title: s.confirmIdDetails,
      bottom: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          OnboardingButton(
            label: s.confirmContinue,
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => DetailsFormScreen(draft: draft))),
          ),
          const SizedBox(height: 12),
          OnboardingButton(label: s.scanAgain, onPressed: () => Navigator.of(context).pop()),
        ],
      ),
      children: [
        Text(s.confirmAllCorrect, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.textSecondary)),
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(s.photo, style: const TextStyle(color: AppColors.textSecondary)),
              const SizedBox(height: 8),
              Container(
                width: 120,
                height: 120,
                color: AppColors.surface,
                alignment: Alignment.center,
                child: Text(initials(id.fullName),
                    style: const TextStyle(fontSize: 40, fontWeight: FontWeight.w800, color: AppColors.navy)),
              ),
            ],
          ),
        ),
        InfoRow(label: s.idNumber, value: id.nin),
        InfoRow(label: s.fullName, value: id.fullName),
        InfoRow(label: s.birthDate, value: '${id.birthDate.day.toString().padLeft(2, '0')}/${id.birthDate.month.toString().padLeft(2, '0')}/${id.birthDate.year}'),
        InfoRow(label: s.nationality, value: id.nationality),
        InfoRow(label: s.gender, value: id.gender == Gender.male ? s.male : s.female),
        InfoRow(label: s.residenceIsland, value: id.residenceIsland),
        InfoRow(label: s.residenceCity, value: id.residenceCity),
        InfoRow(label: s.residenceDistrict, value: id.residenceDistrict),
        InfoRow(label: s.residenceStreet, value: id.residenceStreet),
        InfoRow(label: s.postalAddress, value: id.postalAddress ?? ''),
        InfoRow(label: s.birthPlace, value: id.birthPlace),
        InfoRow(label: s.birthCountry, value: id.birthCountry),
        if (id.hasSignature)
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(s.signature, style: const TextStyle(color: AppColors.textSecondary)),
                const SizedBox(height: 8),
                Center(
                  child: Text(id.fullName.split(' ').first.toLowerCase(),
                      style: const TextStyle(fontSize: 30, fontStyle: FontStyle.italic, fontFamily: 'cursive')),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

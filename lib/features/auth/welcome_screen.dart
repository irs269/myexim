import 'package:flutter/material.dart';

import '../../core/app_scope.dart';
import '../../core/l10n/strings.dart';
import '../../core/theme/app_colors.dart';
import 'auth_widgets.dart';
import '../onboarding/details_screens.dart';
import '../onboarding/identity_screens.dart';
import '../onboarding/onboarding_widgets.dart';
import 'login_screen.dart';
import 'self_registration_screen.dart';

/// Écran d'accueil, repris de l'app Exim actuelle.
class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    void push(Widget page) => Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));

    return Scaffold(
      backgroundColor: AppColors.navyDark,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Photo plein écran, teintée de bleu comme dans l'app Exim actuelle.
          Image.asset(
            'assets/images/welcome_photo.jpg',
            fit: BoxFit.fitWidth,
            alignment: Alignment.topCenter,
            color: AppColors.brandBlue.withValues(alpha: 0.8),
            colorBlendMode: BlendMode.color,
          ),
          // Voile clair en haut (logo lisible), fondu marine sous le visage, touche dorée en bas.
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                stops: [0, 0.14, 0.32, 0.5, 0.62, 0.9, 1],
                colors: [
                  Color(0xE6FFFFFF),
                  Color(0x66FFFFFF),
                  Color(0x330B2A6B),
                  Color(0xB30B2A6B),
                  Color(0xF20B2A6B),
                  AppColors.navyDark,
                  Color(0xFF6B5A30),
                ],
              ),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 12, 0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Flexible(child: FittedBox(child: EximLogo(scale: 0.85))),
                      const Spacer(),
                      _LanguagePicker(),
                    ],
                  ),
                ),
                const Spacer(),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    children: [
                      Text(
                        s.welcome,
                        style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        s.tagline,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: AppColors.gold, fontSize: 21),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        s.welcomeBody,
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 15, height: 1.45),
                      ),
                      const SizedBox(height: 24),
                      ValueListenableBuilder<String?>(
                        valueListenable: OnboardingStore.pendingRef,
                        builder: (context, ref, _) => ref == null
                            ? const SizedBox.shrink()
                            : _EntryTile(
                                title: s.trackApplication,
                                subtitle: '${s.trackApplicationSub} · $ref',
                                gold: true,
                                onTap: () => push(ApplicationStatusScreen(reference: ref)),
                              ),
                      ),
                      _EntryTile(
                        title: s.openAccount,
                        subtitle: s.openAccountSub,
                        onTap: () => push(const AboutYouScreen()),
                      ),
                      _EntryTile(
                        title: s.scanToPay,
                        subtitle: s.scanToPaySub,
                        onTap: () {
                          ScaffoldMessenger.of(
                            context,
                          ).showSnackBar(SnackBar(content: Text(s.loginToPay), behavior: SnackBarBehavior.floating));
                          push(const LoginScreen());
                        },
                      ),
                      _EntryTile(
                        title: s.selfRegistration,
                        subtitle: s.selfRegistrationSub,
                        onTap: () => push(const SelfRegistrationScreen()),
                      ),
                      _EntryTile(
                        title: s.login,
                        subtitle: s.loginSub,
                        highlighted: true,
                        onTap: () => push(const LoginScreen()),
                      ),
                      const SizedBox(height: 8),
                    ],
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

class _LanguagePicker extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final lang = AppScope.of(context).language;
    return PopupMenuButton<AppLanguage>(
      initialValue: lang.value,
      onSelected: (l) => lang.value = l,
      itemBuilder: (_) => [for (final l in AppLanguage.values) PopupMenuItem(value: l, child: Text(l.label))],
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(lang.value.label, style: const TextStyle(color: AppColors.brandBlue, fontSize: 16)),
            const Icon(Icons.arrow_drop_down, color: AppColors.brandBlue),
          ],
        ),
      ),
    );
  }
}

class _EntryTile extends StatelessWidget {
  const _EntryTile({
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.highlighted = false,
    this.gold = false,
  });
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool highlighted;

  /// Mise en avant dorée (suivi d'une demande en cours).
  final bool gold;

  @override
  Widget build(BuildContext context) {
    final fg = highlighted ? Colors.white : AppColors.navy;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: highlighted ? AppColors.navy : (gold ? AppColors.goldLight : Colors.white),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: highlighted ? BorderSide(color: Colors.white.withValues(alpha: 0.25)) : BorderSide.none,
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(color: fg, fontSize: 16, fontWeight: FontWeight.w500),
                      ),
                      const SizedBox(height: 1),
                      Text(
                        subtitle,
                        style: TextStyle(color: highlighted ? Colors.white70 : AppColors.textSecondary, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right, color: highlighted ? Colors.white : AppColors.textMuted),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

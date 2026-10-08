import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../core/utils/formatters.dart';
import '../data/models.dart';

enum PillVariant { primary, soft, outline }

/// Bouton « pastille » arrondi, l'élément le plus présent chez Wise.
class PillButton extends StatelessWidget {
  const PillButton({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.variant = PillVariant.soft,
    this.dense = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final PillVariant variant;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final (bg, fg, border) = switch (variant) {
      PillVariant.primary => (AppColors.primary, AppColors.onPrimary, null),
      PillVariant.soft => (AppColors.primarySoft, AppColors.onPrimarySoft, null),
      PillVariant.outline => (AppColors.background, AppColors.textPrimary, AppColors.border),
    };
    return Material(
      color: bg,
      shape: StadiumBorder(side: border == null ? BorderSide.none : BorderSide(color: border)),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: onPressed ?? () {},
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: dense ? 16 : 20, vertical: dense ? 10 : 14),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[Icon(icon, size: 20, color: fg), const SizedBox(width: 8)],
              // Flexible : un libellé trop long (grande police) passe à la ligne au lieu de déborder.
              Flexible(
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: fg, fontWeight: FontWeight.w700, fontSize: dense ? 15 : 16.5),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Rangée de pastilles alignée à droite, réduite proportionnellement si l'écran est étroit.
class PillGroup extends StatelessWidget {
  const PillGroup({super.key, required this.children, this.alignment = Alignment.centerRight});
  final List<Widget> children;
  final Alignment alignment;

  @override
  Widget build(BuildContext context) => Align(
        alignment: alignment,
        child: FittedBox(
          fit: BoxFit.scaleDown,
          alignment: alignment,
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            for (final (i, c) in children.indexed) ...[if (i > 0) const SizedBox(width: 8), c],
          ]),
        ),
      );
}

/// Pastille d'un compte selon son type (tous les comptes sont en KMF).
class AccountIcon extends StatelessWidget {
  const AccountIcon({super.key, required this.account, this.size = 40});
  final Account account;
  final double size;

  @override
  Widget build(BuildContext context) => CircleIcon(
        icon: switch (account.type) {
          AccountType.savings => Icons.savings_outlined,
          _ => Icons.account_balance_wallet_outlined,
        },
        size: size,
        bg: AppColors.primarySoft,
        fg: AppColors.navy,
      );
}

/// Bouton rond gris (retour, fermer, œil…).
class RoundIconButton extends StatelessWidget {
  const RoundIconButton({super.key, required this.icon, this.onPressed, this.size = 48});
  final IconData icon;
  final VoidCallback? onPressed;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onPressed ?? () {},
        child: SizedBox(width: size, height: size, child: Icon(icon, color: AppColors.navy, size: size * 0.45)),
      ),
    );
  }
}

/// Avatar à initiales, avec pastille Exim si le bénéficiaire est client de la banque.
class InitialsAvatar extends StatelessWidget {
  const InitialsAvatar({super.key, required this.name, this.size = 56, this.badge = false, this.wallet = false});

  /// Avatar d'un bénéficiaire : pastille Exim ou pastille Mobile Money.
  InitialsAvatar.of(Beneficiary b, {super.key, this.size = 56})
      : name = b.name,
        badge = b.isEximCustomer,
        wallet = b.isMobileMoney;

  final String name;
  final double size;
  final bool badge;

  /// Pastille téléphone (portefeuille Mobile Money).
  final bool wallet;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: size,
            height: size,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.background,
              border: Border.all(color: AppColors.border),
            ),
            child: Text(
              initials(name),
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: size * 0.32, color: AppColors.textPrimary),
            ),
          ),
          if (wallet)
            Positioned(
              right: -2,
              bottom: -2,
              child: Container(
                width: size * 0.38,
                height: size * 0.38,
                decoration: BoxDecoration(
                  color: AppColors.navy,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                ),
                child: Icon(Icons.phone_android, size: size * 0.2, color: AppColors.gold),
              ),
            ),
          if (badge)
            Positioned(
              right: -2,
              bottom: -2,
              child: Container(
                width: size * 0.38,
                height: size * 0.38,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.gold,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                ),
                child: Text('E', style: TextStyle(color: AppColors.navy, fontWeight: FontWeight.w900, fontSize: size * 0.18)),
              ),
            ),
        ],
      ),
    );
  }
}

/// Ligne de liste : visuel à gauche, titre + sous-titre, chevron.
class ListRow extends StatelessWidget {
  const ListRow({
    super.key,
    required this.leading,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
  });
  final Widget leading;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return InkWell(
      onTap: onTap ?? () {},
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        child: Row(
          children: [
            leading,
            const SizedBox(width: 18),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: t.titleMedium),
                  if (subtitle != null) ...[
                    const SizedBox(height: 3),
                    Text(subtitle!, style: t.bodyMedium?.copyWith(color: AppColors.textSecondary)),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 12),
            trailing ?? const Icon(Icons.chevron_right, color: AppColors.textPrimary),
          ],
        ),
      ),
    );
  }
}

/// Icône ronde pleine (menus « Allez plus loin », paiements…).
class CircleIcon extends StatelessWidget {
  const CircleIcon({super.key, required this.icon, this.size = 56, this.bg = AppColors.navy, this.fg = AppColors.gold});
  final IconData icon;
  final double size;
  final Color bg;
  final Color fg;

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
        child: Icon(icon, color: fg, size: size * 0.45),
      );
}

/// Titre d'écran géant façon Wise.
class ScreenTitle extends StatelessWidget {
  const ScreenTitle(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
        child: Text(text, style: Theme.of(context).textTheme.displaySmall),
      );
}

/// Titre de section avec lien d'action souligné (« Transactions … Tout afficher »).
class SectionHeader extends StatelessWidget {
  const SectionHeader({super.key, required this.title, required this.action, required this.onAction});
  final String title;
  final String action;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: Text(title, style: Theme.of(context).textTheme.headlineMedium)),
        TextButton(
          style: TextButton.styleFrom(foregroundColor: AppColors.navy, padding: const EdgeInsets.symmetric(horizontal: 4)),
          onPressed: onAction,
          child: Text(action,
              style: const TextStyle(
                  fontWeight: FontWeight.w700, fontSize: 15.5, decoration: TextDecoration.underline, decorationColor: AppColors.navy)),
        ),
      ],
    );
  }
}

/// Petit titre de section gris (« Récents », « Tous »…).
class SectionLabel extends StatelessWidget {
  const SectionLabel(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 6),
        child: Text(text, style: const TextStyle(color: AppColors.textSecondary, fontSize: 15, fontWeight: FontWeight.w600)),
      );
}

/// FutureBuilder avec états de chargement et d'erreur homogènes.
class AsyncView<T> extends StatelessWidget {
  const AsyncView({super.key, required this.future, required this.builder});
  final Future<T> future;
  final Widget Function(BuildContext, T) builder;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<T>(
      future: future,
      builder: (context, snap) {
        if (snap.hasError) {
          return Padding(
            padding: const EdgeInsets.all(24),
            child: Text('Erreur : ${snap.error}', style: const TextStyle(color: AppColors.danger)),
          );
        }
        if (!snap.hasData) {
          return const Padding(
            padding: EdgeInsets.all(32),
            child: Center(child: CircularProgressIndicator(color: AppColors.navy)),
          );
        }
        return builder(context, snap.data as T);
      },
    );
  }
}

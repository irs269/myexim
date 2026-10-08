import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../shared/widgets.dart';
import '../scheduled/scheduled_screen.dart';

/// Équivalent de « Allez plus loin avec Wise », adapté aux services Exim.
class ExploreScreen extends StatelessWidget {
  const ExploreScreen({super.key});

  static const _sections = <(String, List<(IconData, String, String, Color)>)>[
    ('Ouvrez un compte', [
      (Icons.savings_outlined, 'Compte épargne', 'Mettez de l\'argent de côté pour vos projets tout en le faisant fructifier.', AppColors.navy),
    ]),
    ('Automatisez', [
      (Icons.north_east, 'Virements planifiés', 'Envoyez de l\'argent à une date ultérieure.', Color(0xFF241238)),
      (Icons.sync, 'Ordres permanents', 'Payez vos dépenses récurrentes depuis votre compte Exim.', Color(0xFF241238)),
    ]),
    ('Services', [
      (Icons.qr_code_scanner, 'Scan to Pay', 'Payez les factures de l\'État et les commerçants avec un QR code.', AppColors.navyDark),
      (Icons.request_quote_outlined, 'Demande de crédit', 'Faites une simulation et déposez votre demande en ligne.', AppColors.navyDark),
    ]),
    ('Gérez votre entreprise', [
      (Icons.business_center_outlined, 'Compte professionnel', 'Tout ce dont votre entreprise a besoin, au même endroit.', Color(0xFF3A1414)),
    ]),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.only(bottom: 24),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
              child: Align(
                alignment: Alignment.centerLeft,
                child: RoundIconButton(icon: Icons.close, onPressed: () => Navigator.of(context).pop()),
              ),
            ),
            const ScreenTitle('Allez plus loin avec Exim'),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                children: [
                  for (final (i, tab) in const ['Comptes', 'Automatisez', 'Services', 'Entreprise'].indexed) ...[
                    PillButton(label: tab, variant: i == 0 ? PillVariant.soft : PillVariant.outline, dense: true),
                    const SizedBox(width: 8),
                  ],
                ],
              ),
            ),
            for (final (title, items) in _sections) ...[
              SectionLabel(title),
              for (final (icon, name, desc, color) in items)
                ListRow(
                  leading: CircleIcon(icon: icon, bg: color),
                  title: name,
                  subtitle: desc,
                  onTap: switch (name) {
                    'Virements planifiés' => () => Navigator.of(context)
                        .push(MaterialPageRoute(builder: (_) => const ScheduledScreen())),
                    'Ordres permanents' => () => Navigator.of(context)
                        .push(MaterialPageRoute(builder: (_) => const ScheduledScreen(initialTab: 1))),
                    _ => null,
                  },
                ),
            ],
          ],
        ),
      ),
    );
  }
}

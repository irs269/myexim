import 'package:flutter/material.dart';

import '../../core/app_scope.dart';
import '../../core/theme/app_colors.dart';
import '../../data/models.dart';
import '../../shared/widgets.dart';

/// « Nouvelle demande » : demander de l'argent à un bénéficiaire.
class RequestScreen extends StatefulWidget {
  const RequestScreen({super.key});

  @override
  State<RequestScreen> createState() => _RequestScreenState();
}

class _RequestScreenState extends State<RequestScreen> {
  late Future<List<Beneficiary>> _beneficiaries;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _beneficiaries = AppScope.repo(context).getBeneficiaries();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.only(bottom: 24),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
              child: Row(
                children: [
                  RoundIconButton(icon: Icons.arrow_back, onPressed: () => Navigator.of(context).pop()),
                  const Spacer(),
                  const PillButton(label: 'Inviter', icon: Icons.card_giftcard, dense: true),
                ],
              ),
            ),
            const ScreenTitle('Nouvelle demande'),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 24),
              child: TextField(
                decoration: InputDecoration(
                  prefixIcon: Padding(padding: EdgeInsets.only(left: 12), child: Icon(Icons.search)),
                  hintText: 'Nom, numéro de compte, téléphone…',
                ),
              ),
            ),
            const SizedBox(height: 16),
            ListRow(
              leading: Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: AppColors.border)),
                child: const Icon(Icons.link, color: AppColors.navy),
              ),
              title: 'Partager un lien',
              subtitle: 'Envoyez un lien pour recevoir un paiement',
            ),
            const SectionLabel('Récents'),
            AsyncView(
              future: _beneficiaries,
              builder: (context, list) => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    height: 128,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                      itemCount: list.length,
                      separatorBuilder: (_, _) => const SizedBox(width: 18),
                      itemBuilder: (_, i) {
                        final parts = list[i].name.split(' ');
                        final short = parts.length > 1 ? '${parts.first} ${parts[1][0]}.' : parts.first;
                        return SizedBox(
                          width: 84,
                          child: Column(
                            children: [
                              InitialsAvatar(name: list[i].name, size: 76, badge: list[i].isEximCustomer),
                              const SizedBox(height: 8),
                              Text(short, textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                  const SectionLabel('Activités'),
                  for (final b in list.take(2))
                    ListRow(leading: InitialsAvatar(name: b.name, badge: b.isEximCustomer), title: b.name, subtitle: b.accountNumber),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

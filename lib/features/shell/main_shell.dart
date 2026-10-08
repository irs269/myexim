import 'package:flutter/material.dart';

import '../../core/l10n/strings.dart';
import '../beneficiaries/beneficiaries_screen.dart';
import '../cards/cards_screen.dart';
import '../home/home_screen.dart';
import '../payments/payments_screen.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _index = 0;

  static const _pages = [HomeScreen(), CardsScreen(), BeneficiariesScreen(), PaymentsScreen()];

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: IndexedStack(index: _index, children: _pages),
      ),
      bottomNavigationBar: DecoratedBox(
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: Color(0xFFEDEFF2))),
        ),
        child: NavigationBar(
          selectedIndex: _index,
          onDestinationSelected: (i) => setState(() => _index = i),
          destinations: [
            NavigationDestination(
              icon: const Icon(Icons.home_outlined),
              selectedIcon: const Icon(Icons.home),
              label: s.tabHome,
            ),
            NavigationDestination(
              icon: const Icon(Icons.credit_card_outlined),
              selectedIcon: const Icon(Icons.credit_card),
              label: s.tabCards,
            ),
            NavigationDestination(
              icon: const Icon(Icons.people_outline),
              selectedIcon: const Icon(Icons.people),
              label: s.beneficiaries,
            ),
            NavigationDestination(icon: const Icon(Icons.swap_horiz), label: s.tabPayments),
          ],
        ),
      ),
    );
  }
}

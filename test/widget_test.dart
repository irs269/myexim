import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myexim/core/app_scope.dart';
import 'package:myexim/core/l10n/strings.dart';
import 'package:myexim/core/session.dart';
import 'package:myexim/data/mock_auth_repository.dart';
import 'package:myexim/data/mock_bank_repository.dart';
import 'package:myexim/features/transactions/transaction_widgets.dart';
import 'package:myexim/main.dart';

/// Laisse passer la latence simulée des API puis la transition de route qui suit.
Future<void> _wait(WidgetTester tester, [int ms = 1000]) async {
  await tester.pump();
  await tester.pump(Duration(milliseconds: ms));
  await tester.pump(Duration(milliseconds: ms));
}

Future<void> _typePin(WidgetTester tester, String pin) async {
  for (final d in pin.split('')) {
    await tester.tap(find.text(d));
    await tester.pump();
  }
  await _wait(tester, 300);
}

void main() {
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));

  testWidgets('Connexion, PIN, verrouillage et déconnexion', (tester) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 2.6;
    addTearDown(tester.view.reset);

    final session = SessionController(auth: MockAuthRepository());
    await session.restore();
    await tester.pumpWidget(AppScope(
      repository: MockBankRepository(),
      session: session,
      language: ValueNotifier(AppLanguage.fr),
      child: const MyEximApp(),
    ));
    await _wait(tester);
    expect(find.text('Bienvenue !'), findsOneWidget);

    // Connexion
    await tester.tap(find.text('Connexion'));
    await _wait(tester);
    await tester.enterText(find.byType(TextFormField).at(0), 'abdou');
    await tester.enterText(find.byType(TextFormField).at(1), 'secret');
    await tester.tap(find.text('Continuer'));
    await _wait(tester);

    // OTP
    expect(find.text('Entrez le code reçu par SMS'), findsOneWidget);
    await tester.enterText(find.byType(TextField).first, MockAuthRepository.mockOtp);
    await _wait(tester);

    // Création et confirmation du PIN
    expect(find.text('Créez votre code PIN'), findsOneWidget);
    await _typePin(tester, '1234');
    expect(find.text('Confirmez votre code PIN'), findsOneWidget);
    await _typePin(tester, '1234');
    await _wait(tester, 1500); // inclut le délai de garde de la détection biométrique
    expect(find.text('Solde total'), findsOneWidget);

    // Verrouillage : mauvais PIN puis bon PIN
    session.lock();
    await _wait(tester);
    expect(find.text('Entrez votre code PIN'), findsOneWidget);
    await _typePin(tester, '9999');
    expect(find.textContaining('4 essai(s) restant(s)'), findsOneWidget);
    await _typePin(tester, '1234');
    await _wait(tester);
    expect(find.text('Solde total'), findsOneWidget);

    // Chaque onglet s'affiche sans erreur de mise en page
    for (final tab in ['Cartes', 'Bénéficiaires', 'Paiements', 'Accueil']) {
      await tester.tap(find.text(tab).last);
      await _wait(tester);
      final error = tester.takeException();
      expect(error, isNull, reason: '$tab: $error');
    }

    // Déconnexion depuis l'avatar
    await tester.tap(find.text('AM'));
    await _wait(tester);
    await tester.tap(find.text('Se déconnecter'));
    await _wait(tester);
    expect(find.text('Bienvenue !'), findsOneWidget);
    expect(session.status, SessionStatus.loggedOut);
  });

  testWidgets('Le changement de langue traduit l\'accueil', (tester) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 2.6;
    addTearDown(tester.view.reset);

    final session = SessionController(auth: MockAuthRepository());
    await session.restore();
    final language = ValueNotifier(AppLanguage.fr);
    await tester.pumpWidget(AppScope(
      repository: MockBankRepository(),
      session: session,
      language: language,
      child: const MyEximApp(),
    ));
    await _wait(tester);
    language.value = AppLanguage.en;
    await _wait(tester);
    expect(find.text('Welcome!'), findsOneWidget);
    expect(find.text('Login'), findsOneWidget);
  });

  testWidgets('Tableau de bord : comptes, transactions, détail et RIB', (tester) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 2.6;
    addTearDown(tester.view.reset);

    // Session déjà ouverte : on saute le parcours de connexion.
    final session = SessionController(auth: MockAuthRepository());
    await session.restore();
    session.onLoginVerified('test-token');
    await session.createPin('1234');
    session.finishEnrollment();

    await tester.pumpWidget(AppScope(
      repository: MockBankRepository(latency: Duration.zero),
      session: session,
      language: ValueNotifier(AppLanguage.fr),
      child: const MyEximApp(),
    ));
    await _wait(tester);
    expect(find.text('Solde total'), findsOneWidget);
    expect(find.text('Compte épargne'), findsOneWidget);

    // Historique complet + filtre « Entrées »
    await tester.tap(find.text('Tout afficher'));
    await _wait(tester);
    expect(find.text('Rechercher une transaction'), findsOneWidget);
    await tester.tap(find.text('Sens'));
    await _wait(tester);
    await tester.tap(find.text('Entrées'));
    await _wait(tester);
    expect(find.text('Sens : Entrées'), findsOneWidget);
    expect(find.textContaining('+ '), findsWidgets);
    expect(tester.takeException(), isNull);

    // Détail d'une transaction
    await tester.tap(find.byType(TransactionTile).first);
    await _wait(tester);
    expect(find.text('Détails'), findsOneWidget);
    expect(find.text('Référence'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.arrow_back).last);
    await _wait(tester);
    await tester.tap(find.byIcon(Icons.arrow_back).last);
    await _wait(tester);

    // Détail d'un compte puis ses coordonnées bancaires
    await tester.tap(find.text('Compte épargne'));
    await _wait(tester);
    expect(find.text('Compte épargne · KMF'), findsOneWidget);
    await tester.tap(find.text('Numéros de compte'));
    await _wait(tester);
    expect(find.text('BIC / SWIFT'), findsOneWidget);
    expect(find.text('KM46 0000 5000 0100 2345 6889 045'), findsWidgets);
    await tester.tapAt(const Offset(20, 40)); // ferme la feuille
    await _wait(tester);
    await tester.tap(find.byIcon(Icons.arrow_back).last);
    await _wait(tester);

    // Une seule devise : plus d'écran de taux ni de compte en devises
    expect(find.byIcon(Icons.show_chart), findsNothing);
    expect(find.text('Compte euros'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}

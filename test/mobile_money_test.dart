import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myexim/core/app_scope.dart';
import 'package:myexim/core/l10n/strings.dart';
import 'package:myexim/core/session.dart';
import 'package:myexim/core/utils/formatters.dart';
import 'package:myexim/data/mock_auth_repository.dart';
import 'package:myexim/data/mock_bank_repository.dart';
import 'package:myexim/data/models.dart';
import 'package:myexim/main.dart';

Future<void> _wait(WidgetTester tester, [int ms = 600]) async {
  await tester.pump();
  await tester.pump(Duration(milliseconds: ms));
  await tester.pump(Duration(milliseconds: ms));
}

Future<void> _typePin(WidgetTester tester, String pin) async {
  for (final d in pin.split('')) {
    await tester.tap(find.text(d).last);
    await tester.pump();
  }
  await _wait(tester);
}

void main() {
  group('Frais MVola (1 %, min 250, max 2 000 KMF)', () {
    const kmf = Account(number: 'A', label: 'Courant', currency: 'KMF', balance: 5000000, type: AccountType.current, iban: '');
    const mvola = TransferDestination.beneficiary(
      Beneficiary(id: 'w', name: 'Nazira', accountNumber: '+2693312345', bankName: 'MVola', isEximCustomer: false, walletProvider: 'MVola'),
    );
    TransferQuote q(double amount) => MockBankRepository.quote(from: kmf, to: mvola, amount: amount, side: AmountSide.send);

    test('minimum 250 KMF', () => expect(q(10000).fee, 250));
    test('1 % au-delà', () => expect(q(60000).fee, 600));
    test('plafond 2 000 KMF', () => expect(q(1000000).fee, 2000));
    test('instantané', () => expect(q(10000).instant, isTrue));
  });

  test('vérification du titulaire MVola', () async {
    final repo = MockBankRepository(latency: Duration.zero);
    expect(await repo.lookupWallet(countryCode: 'KM', provider: 'MVola', phone: '+269 331 23 45'), 'Nazira Mbotimora');
    expect(await repo.lookupWallet(countryCode: 'KM', provider: 'MVola', phone: '+2693000000'), isNull);
  });

  test('tout numéro MVola valide a un titulaire de test (sauf …0000)', () async {
    final repo = MockBankRepository(latency: Duration.zero);
    expect(await repo.lookupWallet(countryCode: 'KM', provider: 'MVola', phone: '+2693456789'), isNotNull);
    expect(await repo.lookupWallet(countryCode: 'KM', provider: 'MVola', phone: '+2694123456'), isNotNull);
    expect(await repo.lookupWallet(countryCode: 'KM', provider: 'MVola', phone: '+2695123456'), isNull); // ni 3 ni 4
  });

  testWidgets("Ajouter un bénéficiaire MVola depuis l'onglet Bénéficiaires (numéro saisi avec l'indicatif)", (tester) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 2.6;
    addTearDown(tester.view.reset);
    FlutterSecureStorage.setMockInitialValues({});
    final session = SessionController(auth: MockAuthRepository());
    await session.restore();
    session.onLoginVerified('t');
    await session.createPin('1234');
    session.finishEnrollment();
    final repo = MockBankRepository(latency: Duration.zero);
    await tester.pumpWidget(AppScope(
      repository: repo,
      session: session,
      language: ValueNotifier(AppLanguage.fr),
      child: const MyEximApp(),
    ));
    await _wait(tester);
    await tester.tap(find.text('Bénéficiaires').last);
    await _wait(tester);
    await tester.tap(find.text('Ajouter'));
    await _wait(tester);
    await tester.tap(find.text('Mobile Money'));
    await _wait(tester);
    expect(find.text('7 chiffres commençant par 3 ou 4, sans indicatif'), findsOneWidget);

    // Mauvais format : message explicite au lieu d'un bouton grisé sans explication
    await tester.enterText(find.byType(TextFormField), '5123456');
    await _wait(tester);
    expect(find.text('7 chiffres commençant par 3 ou 4, sans indicatif'), findsWidgets);
    expect(tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Enregistrer')).onPressed, isNull);

    // Indicatif saisi par erreur : retiré automatiquement, titulaire trouvé
    await tester.enterText(find.byType(TextFormField), '269 345 67 89');
    await _wait(tester);
    expect(find.byIcon(Icons.verified), findsOneWidget);
    await tester.tap(find.text('Enregistrer'));
    await _wait(tester);
    expect(find.text('Bénéficiaire ajouté'), findsOneWidget);

    final saved = (await tester.runAsync(repo.getBeneficiaries))!.first;
    expect(saved.accountNumber, '+2693456789');
    expect(saved.walletProvider, 'MVola');
    expect(tester.takeException(), isNull);
  });

  testWidgets('Envoi vers MVola depuis l\'onglet Paiements', (tester) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 2.6;
    addTearDown(tester.view.reset);
    FlutterSecureStorage.setMockInitialValues({});

    final session = SessionController(auth: MockAuthRepository());
    await session.restore();
    session.onLoginVerified('t');
    await session.createPin('1234');
    session.finishEnrollment();
    final repo = MockBankRepository(latency: Duration.zero);
    await tester.pumpWidget(AppScope(
      repository: repo,
      session: session,
      language: ValueNotifier(AppLanguage.fr),
      child: const MyEximApp(),
    ));
    await _wait(tester);

    await tester.tap(find.text('Paiements').last);
    await _wait(tester);
    await tester.tap(find.text('Envoyer vers MVola'));
    await _wait(tester);
    expect(find.text('Numéro MVola'), findsOneWidget);
    expect(find.text('+269'), findsOneWidget);

    // Numéro sans portefeuille → message ; numéro connu → titulaire vérifié
    await tester.enterText(find.byType(TextFormField), '3000000');
    await _wait(tester);
    expect(find.text('Aucun portefeuille MVola actif pour ce numéro'), findsOneWidget);
    await tester.enterText(find.byType(TextFormField), '3312345');
    await _wait(tester);
    expect(find.text('Nazira Mbotimora'), findsOneWidget);
    await tester.tap(find.text('Continuer'));
    await _wait(tester);

    // Montant : frais Mobile Money et arrivée instantanée
    await tester.enterText(find.byType(TextField).first, '10000');
    await _wait(tester);
    expect(find.text(formatAmount(250, 'KMF')), findsOneWidget);
    expect(find.text('En quelques secondes'), findsOneWidget);
    await tester.tap(find.text('Continuer'));
    await _wait(tester);

    expect(find.text('Numéro MVola'), findsOneWidget);
    expect(find.text('+2693312345'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Choisissez un motif'), 200);
    await tester.tap(find.text('Choisissez un motif'));
    await _wait(tester);
    await tester.tap(find.text('Famille et amis'));
    await _wait(tester);
    await tester.tap(find.text('Confirmer et envoyer'));
    await _wait(tester);
    await _typePin(tester, '1234');
    await _wait(tester);
    expect(find.text('C\'est fait !'), findsOneWidget);

    final accounts = (await tester.runAsync(repo.getAccounts))!;
    expect(accounts.first.balance, 1254300 - 10000 - 250);
    final txs = (await tester.runAsync(() => repo.getTransactions(limit: 1)))!;
    expect(txs.first.subtitle, 'Envoi MVola');
    expect(tester.takeException(), isNull);
  });
}

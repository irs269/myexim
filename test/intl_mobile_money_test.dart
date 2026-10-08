import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myexim/core/app_scope.dart';
import 'package:myexim/core/l10n/strings.dart';
import 'package:myexim/core/session.dart';
import 'package:myexim/core/utils/formatters.dart';
import 'package:myexim/data/bank_repository.dart';
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
  const kmf = Account(number: 'A', label: 'Courant', currency: 'KMF', balance: 5000000, type: AccountType.current, iban: '');
  const senegal = TransferDestination.beneficiary(Beneficiary(
    id: 's',
    name: 'Aïcha Diallo',
    accountNumber: '+221771234567',
    bankName: 'Orange Money · Sénégal',
    isEximCustomer: false,
    walletProvider: 'Orange Money',
    countryCode: 'SN',
    currency: 'XOF',
  ));

  group('Onafriq : tarification', () {
    test('KMF → XOF : les deux francs sont arrimés à l\'euro (1 XOF = 0,75 KMF)', () {
      final q = MockBankRepository.quote(from: kmf, to: senegal, amount: 75000, side: AmountSide.send);
      expect(q.receiveCurrency, 'XOF');
      expect(q.rate, closeTo(655.957 / 491.96775 * 0.995, 1e-9));
      expect(q.receiveAmount, (75000 * q.rate).roundToDouble()); // XOF sans décimales
    });

    test('frais 2 %, entre 1 500 et 15 000 KMF', () {
      expect(MockBankRepository.quote(from: kmf, to: senegal, amount: 20000, side: AmountSide.send).fee, 1500);
      expect(MockBankRepository.quote(from: kmf, to: senegal, amount: 200000, side: AmountSide.send).fee, 4000);
      expect(MockBankRepository.quote(from: kmf, to: senegal, amount: 2000000, side: AmountSide.send).fee, 15000);
    });

    test('le XOF s\'affiche sans décimales', () {
      expect(formatAmount(100000, 'XOF', withCode: false), formatAmount(100000, 'KMF', withCode: false));
    });
  });

  group('Onafriq : vérification du portefeuille', () {
    final repo = MockBankRepository(latency: Duration.zero);
    test('numéro au bon format → titulaire', () async {
      expect(await repo.lookupWallet(countryCode: 'SN', provider: 'Orange Money', phone: '+221771234567'), isNotNull);
    });
    test('mauvaise longueur, opérateur inconnu ou portefeuille inexistant → null', () async {
      expect(await repo.lookupWallet(countryCode: 'SN', provider: 'Orange Money', phone: '+22177123'), isNull);
      expect(await repo.lookupWallet(countryCode: 'SN', provider: 'M-Pesa', phone: '+221771234567'), isNull);
      expect(await repo.lookupWallet(countryCode: 'SN', provider: 'Orange Money', phone: '+221771230000'), isNull);
    });
    test('le drapeau est calculé à partir du code pays', () {
      expect(flagForCountry('SN'), '🇸🇳');
      expect(flagForCountry('KM'), '🇰🇲');
    });
  });

  testWidgets('Envoi vers Orange Money Sénégal via Onafriq', (tester) async {
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
    await tester.tap(find.text('Mobile Money international'));
    await _wait(tester);
    expect(find.text('Envoi international via Onafriq'), findsOneWidget);
    expect(find.text('+261'), findsOneWidget); // Madagascar par défaut

    // Changement de pays : Sénégal → opérateurs et indicatif mis à jour
    await tester.tap(find.textContaining('Madagascar'));
    await _wait(tester, 300);
    await tester.tap(find.textContaining('Sénégal').last);
    await _wait(tester, 300);
    expect(find.text('+221'), findsOneWidget);
    expect(find.text('Orange Money'), findsOneWidget);

    await tester.enterText(find.byType(TextFormField), '771234567');
    await _wait(tester);
    expect(find.byIcon(Icons.verified), findsOneWidget);
    await tester.tap(find.text('Continuer'));
    await _wait(tester);

    // Montant : réception en XOF, frais Onafriq, arrivée en quelques minutes
    await tester.enterText(find.byType(TextField).first, '75000');
    await _wait(tester);
    expect(find.text('XOF'), findsOneWidget);
    expect(find.text(formatAmount(1500, 'KMF')), findsOneWidget);
    expect(find.text('En quelques minutes'), findsOneWidget);
    await tester.tap(find.text('Continuer'));
    await _wait(tester);

    expect(find.text('🇸🇳 Sénégal'), findsOneWidget);
    expect(find.text('Onafriq'), findsOneWidget);
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
    expect(accounts.first.balance, 1254300 - 75000 - 1500);
    final last = (await tester.runAsync(() => repo.getTransactions(limit: 1)))!.first;
    expect(last.subtitle, 'Envoi Orange Money (Onafriq)');
    expect(tester.takeException(), isNull);
  });
}

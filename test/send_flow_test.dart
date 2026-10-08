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

/// Application déjà déverrouillée (PIN 1234), données simulées sans latence.
Future<MockBankRepository> _startUnlocked(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1080, 2340);
  tester.view.devicePixelRatio = 2.6;
  addTearDown(tester.view.reset);
  FlutterSecureStorage.setMockInitialValues({});

  final session = SessionController(auth: MockAuthRepository());
  await session.restore();
  session.onLoginVerified('test-token');
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
  return repo;
}

void main() {
  group('Tarification simulée', () {
    const kmf = Account(number: 'A', label: 'Courant', currency: 'KMF', balance: 100000, type: AccountType.current, iban: '');
    const savings = Account(number: 'B', label: 'Épargne', currency: 'KMF', balance: 50000, type: AccountType.savings, iban: '');
    const exim = TransferDestination.beneficiary(Beneficiary(id: '1', name: 'X', accountNumber: '1'));
    const other = TransferDestination.beneficiary(
        Beneficiary(id: '2', name: 'Y', accountNumber: '2', bankName: 'BIC Comores', isEximCustomer: false));

    test('virement interne KMF : sans frais, instantané', () {
      final q = MockBankRepository.quote(from: kmf, to: exim, amount: 25000, side: AmountSide.send);
      expect(q.fee, 0);
      expect(q.receiveAmount, 25000);
      expect(q.instant, isTrue);
    });

    test('autre banque : 1 000 KMF de frais, non instantané', () {
      final q = MockBankRepository.quote(from: kmf, to: other, amount: 25000, side: AmountSide.send);
      expect(q.fee, 1000);
      expect(q.totalDebited, 26000);
      expect(q.instant, isFalse);
    });

    test('entre mes comptes (tout en KMF) : sans frais ni taux, instantané', () {
      const toCurrent = TransferDestination.ownAccount(kmf);
      final q = MockBankRepository.quote(from: savings, to: toCurrent, amount: 10000, side: AmountSide.send);
      expect(q.isCrossCurrency, isFalse);
      expect(q.rate, 1);
      expect(q.fee, 0);
      expect(q.receiveAmount, 10000);
      expect(q.instant, isTrue);
    });
  });

  testWidgets('Envoi à un bénéficiaire Exim : récapitulatif, PIN, succès, solde débité', (tester) async {
    await _startUnlocked(tester);
    expect(find.text(formatAmount(1254300, 'KMF')), findsOneWidget);

    await tester.tap(find.text('Envoyer'));
    await _wait(tester);
    expect(find.text('À qui envoyez-vous de l\'argent ?'), findsOneWidget);

    await tester.tap(find.text('Nazira Mbotimora'));
    await _wait(tester);
    await tester.enterText(find.byType(TextField).first, '25000');
    await _wait(tester);
    expect(find.text('Gratuit'), findsOneWidget);
    expect(find.text(formatAmount(25000, 'KMF', withCode: false)), findsOneWidget); // montant reçu calculé
    await tester.tap(find.text('Continuer'));
    await _wait(tester);

    // Le motif est obligatoire pour un virement
    expect(find.text('Vérifiez votre envoi'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Choisissez un motif'), 200);
    await tester.tap(find.text('Choisissez un motif'));
    await _wait(tester);
    await tester.tap(find.text('Famille et amis'));
    await _wait(tester);
    await tester.tap(find.text('Confirmer et envoyer'));
    await _wait(tester);

    expect(find.text('Confirmez avec votre code PIN'), findsOneWidget);
    await _typePin(tester, '1234');
    await _wait(tester);

    expect(find.text('C\'est fait !'), findsOneWidget);
    await tester.tap(find.text('Terminé'));
    await _wait(tester);
    expect(find.text(formatAmount(1229300, 'KMF')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Montant supérieur au solde : bouton désactivé et message', (tester) async {
    await _startUnlocked(tester);
    await tester.tap(find.text('Envoyer'));
    await _wait(tester);
    await tester.tap(find.text('Nazira Mbotimora'));
    await _wait(tester);
    await tester.enterText(find.byType(TextField).first, '9000000');
    await _wait(tester);
    expect(find.text('Solde insuffisant'), findsOneWidget);
    final button = tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Continuer'));
    expect(button.onPressed, isNull);
  });

  testWidgets('Virement de l\'épargne vers le compte courant', (tester) async {
    final repo = await _startUnlocked(tester);
    await tester.tap(find.text('Compte épargne'));
    await _wait(tester);
    await tester.ensureVisible(find.text('Entre mes comptes'));
    await tester.tap(find.text('Entre mes comptes'));
    await _wait(tester);
    expect(find.text('Quel montant transférer entre vos comptes ?'), findsOneWidget);

    await tester.enterText(find.byType(TextField).first, '100000');
    await _wait(tester);
    expect(find.text('Taux appliqué'), findsNothing); // une seule devise
    expect(find.text('Gratuit'), findsOneWidget);
    await tester.tap(find.text('Continuer'));
    await _wait(tester);
    await tester.tap(find.text('Confirmer le virement'));
    await _wait(tester);
    await _typePin(tester, '1234');
    await _wait(tester);
    expect(find.text('C\'est fait !'), findsOneWidget);

    final accounts = (await tester.runAsync(repo.getAccounts))!;
    expect(accounts.every((a) => a.currency == 'KMF'), isTrue);
    expect(accounts.firstWhere((a) => a.label == 'Compte épargne').balance, 380000);
    expect(accounts.firstWhere((a) => a.label == 'Compte courant').balance, 1354300);
  });
}

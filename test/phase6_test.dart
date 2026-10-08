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
import 'package:myexim/features/payments/qr_payload.dart';
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

Future<double> _balance(WidgetTester tester, MockBankRepository repo) async =>
    (await tester.runAsync(repo.getAccounts))!.first.balance;

void main() {
  group('QR de paiement', () {
    test('aller-retour commerçant avec montant, référence et accents', () {
      const p = QrPayload(type: QrType.merchant, id: 'MRC001', name: 'Supermarché Moroni', amount: 12500, reference: 'FAC-2210');
      final decoded = QrPayload.tryParse(p.encode())!;
      expect(decoded.type, QrType.merchant);
      expect(decoded.name, 'Supermarché Moroni');
      expect(decoded.amount, 12500);
      expect(decoded.reference, 'FAC-2210');
      expect(decoded.toPaymentRequest().kind, PaymentKind.merchant);
    });

    test('QR particulier sans montant → bénéficiaire Exim', () {
      final p = QrPayload.tryParse('EXIMPAY:1?t=P&id=00100665544&n=Said%20Ali')!;
      expect(p.amount, isNull);
      expect(p.toBeneficiary().accountNumber, '00100665544');
      expect(p.toBeneficiary().isEximCustomer, isTrue);
    });

    test('les codes de tools/qr_demo.html sont reconnus', () {
      final m = QrPayload.tryParse('eximpay:1?t=M&id=MRC001&n=Supermarch%C3%A9+Moroni&a=12500&r=FAC-2210')!;
      expect(m.name, 'Supermarché Moroni');
      expect(m.amount, 12500);
      expect(QrPayload.tryParse('eximpay:1?t=M&id=MRC002&n=Restaurant+Le+Select')!.amount, isNull);
      final b = QrPayload.tryParse('eximpay:1?t=B&id=AGID&n=AGID+(Imp%C3%B4ts)&a=145000&r=AV2026001')!;
      expect(b.name, 'AGID (Impôts)');
      expect(b.toPaymentRequest().kind, PaymentKind.bill);
      expect(QrPayload.tryParse('eximpay:1?t=P&id=00100665544&n=Said+Ali+Mmadi&a=5000')!.type, QrType.person);
    });

    test('rejette les codes étrangers ou incomplets', () {
      expect(QrPayload.tryParse('https://example.com'), isNull);
      expect(QrPayload.tryParse('EXIMPAY:1?t=X&id=1&n=A'), isNull);
      expect(QrPayload.tryParse('EXIMPAY:1?t=M&n=Sans identifiant'), isNull);
      expect(QrPayload.tryParse('EXIMPAY:1?t=M&id=1&n=A&a=-5'), isNull);
    });
  });

  testWidgets('Facture SONELEC : recherche, paiement par PIN, solde débité', (tester) async {
    final repo = await _startUnlocked(tester);
    final before = await _balance(tester, repo);

    await tester.tap(find.text('Paiements').last);
    await _wait(tester);
    await tester.scrollUntilVisible(find.text('Paiement de factures'), 200);
    await tester.tap(find.text('Paiement de factures'));
    await _wait(tester);
    await tester.tap(find.text('SONELEC'));
    await _wait(tester);

    // Référence inconnue → message
    await tester.enterText(find.byType(TextFormField), '0000000');
    await tester.tap(find.text('Rechercher la facture'));
    await _wait(tester);
    expect(find.text('Aucune facture trouvée pour cette référence'), findsOneWidget);

    await tester.enterText(find.byType(TextFormField), '1234567');
    await tester.tap(find.text('Rechercher la facture'));
    await _wait(tester);
    expect(find.text('Vérifiez votre paiement'), findsOneWidget);
    expect(find.text('Électricité — septembre'), findsOneWidget);
    expect(find.text(formatAmount(18750, 'KMF')), findsOneWidget);

    await tester.tap(find.text('Confirmer le paiement'));
    await _wait(tester);
    await _typePin(tester, '1234');
    await _wait(tester);
    expect(find.text('Paiement effectué'), findsOneWidget);
    expect(await _balance(tester, repo), before - 18750);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Recharge Yas : montant proposé en pastille', (tester) async {
    final repo = await _startUnlocked(tester);
    final before = await _balance(tester, repo);
    await tester.tap(find.text('Paiements').last);
    await _wait(tester);
    await tester.scrollUntilVisible(find.text('Recharge téléphonique'), 200);
    await tester.tap(find.text('Recharge téléphonique'));
    await _wait(tester);
    await tester.tap(find.text('Yas (Telma)'));
    await _wait(tester);
    await tester.enterText(find.byType(TextFormField), '3312345');
    await tester.tap(find.text('Continuer'));
    await _wait(tester);

    final confirm = find.widgetWithText(FilledButton, 'Confirmer le paiement');
    expect(tester.widget<FilledButton>(confirm).onPressed, isNull); // aucun montant choisi
    await tester.tap(find.text(formatAmount(2500, 'KMF')));
    await _wait(tester);
    await tester.tap(confirm);
    await _wait(tester);
    await _typePin(tester, '1234');
    await _wait(tester);
    expect(find.text('Paiement effectué'), findsOneWidget);
    expect(await _balance(tester, repo), before - 2500);
  });

  testWidgets('Cartes : numéros après PIN, gel, plafond, opposition', (tester) async {
    final repo = await _startUnlocked(tester);
    await tester.tap(find.text('Cartes').last);
    await _wait(tester);
    expect(find.textContaining('Visa Silver', findRichText: true), findsOneWidget);

    // Numéros de carte : PIN exigé, puis numéro complet affiché
    await tester.tap(find.text('Numéros de\ncarte'));
    await _wait(tester);
    expect(find.text('Confirmez avec votre code PIN'), findsOneWidget);
    await _typePin(tester, '1234');
    await _wait(tester);
    expect(find.text('4532 7801 2299 5546'), findsOneWidget);
    await tester.tapAt(const Offset(20, 40));
    await _wait(tester);

    // Gel puis dégel
    await tester.tap(find.text('Geler la\ncarte'));
    await _wait(tester);
    expect((await tester.runAsync(repo.getCards))!.first.frozen, isTrue);
    expect(find.text('Dégeler la\ncarte'), findsOneWidget);
    await tester.tap(find.text('Dégeler la\ncarte'));
    await _wait(tester);
    expect((await tester.runAsync(repo.getCards))!.first.frozen, isFalse);

    // Paramètres : désactiver le sans contact et enregistrer (avec PIN)
    await tester.tap(find.text('Paramètres de la carte'));
    await _wait(tester);
    await tester.tap(find.text('Paiement sans contact'));
    await tester.pump();
    await tester.tap(find.text('Enregistrer'));
    await _wait(tester);
    await _typePin(tester, '1234');
    await _wait(tester);
    expect(find.text('Paramètres enregistrés'), findsOneWidget);
    expect((await tester.runAsync(repo.getCards))!.first.contactless, isFalse);

    // Opposition définitive
    await tester.drag(find.byType(ListView).first, const Offset(0, -300));
    await tester.pump();
    await tester.tap(find.text('Paramètres de la carte'));
    await _wait(tester);
    await tester.drag(find.text('Plafonds quotidiens'), const Offset(0, -400));
    await tester.pump();
    await tester.tap(find.text('Faire opposition'));
    await _wait(tester);
    await tester.tap(find.text('Confirmer l\'opposition'));
    await _wait(tester);
    await _typePin(tester, '1234');
    await _wait(tester);
    expect(find.text('Carte en opposition'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

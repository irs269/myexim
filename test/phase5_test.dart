import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myexim/core/app_scope.dart';
import 'package:myexim/core/l10n/strings.dart';
import 'package:myexim/core/session.dart';
import 'package:myexim/data/mock_auth_repository.dart';
import 'package:myexim/data/mock_bank_repository.dart';
import 'package:myexim/data/models.dart';
import 'package:myexim/features/beneficiaries/beneficiaries_screen.dart';
import 'package:myexim/features/beneficiaries/beneficiary_detail_screen.dart';
import 'package:myexim/features/transactions/transaction_widgets.dart';
import 'package:myexim/main.dart';

Future<void> _wait(WidgetTester tester, [int ms = 600]) async {
  await tester.pump();
  await tester.pump(Duration(milliseconds: ms));
  await tester.pump(Duration(milliseconds: ms));
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

/// Liste verticale de l'onglet Bénéficiaires (il contient aussi le carrousel des récents).
Finder _mainList() => find
    .descendant(of: find.byType(BeneficiariesScreen), matching: find.byType(Scrollable))
    .first;

BankTransaction _tx({
  String account = 'A',
  TxDirection direction = TxDirection.debit,
  TxCategory category = TxCategory.transfer,
  DateTime? date,
  String label = 'Nazira',
  String? counterparty,
}) =>
    BankTransaction(
      id: 'x',
      accountNumber: account,
      label: label,
      subtitle: 'Virement envoyé',
      amount: 100,
      currency: 'KMF',
      date: date ?? DateTime(2026, 10, 5, 14),
      direction: direction,
      reference: 'EXM1',
      category: category,
      counterpartyAccount: counterparty,
    );

void main() {
  group('TransactionQuery', () {
    test('filtre par compte, sens, type et contrepartie', () {
      expect(TransactionQuery.forAccount('A').matches(_tx()), isTrue);
      expect(TransactionQuery.forAccount('B').matches(_tx()), isFalse);
      expect(const TransactionQuery(direction: TxDirection.credit).matches(_tx()), isFalse);
      expect(const TransactionQuery(categories: {TxCategory.bill}).matches(_tx()), isFalse);
      expect(const TransactionQuery(counterpartyAccount: '001').matches(_tx(counterparty: '001')), isTrue);
    });

    test('la date de fin inclut toute la journée', () {
      final q = TransactionQuery(from: DateTime(2026, 10, 1), to: DateTime(2026, 10, 5));
      expect(q.matches(_tx(date: DateTime(2026, 10, 5, 23, 59))), isTrue);
      expect(q.matches(_tx(date: DateTime(2026, 10, 6, 0, 1))), isFalse);
      expect(q.matches(_tx(date: DateTime(2026, 9, 30, 23))), isFalse);
    });

    test('recherche insensible à la casse sur libellé et référence', () {
      expect(const TransactionQuery(search: 'nazi').matches(_tx()), isTrue);
      expect(const TransactionQuery(search: 'exm1').matches(_tx()), isTrue);
      expect(const TransactionQuery(search: 'sonelec').matches(_tx()), isFalse);
    });
  });

  testWidgets('Bénéficiaires : ajout vérifié, fiche, renommage et suppression', (tester) async {
    await _startUnlocked(tester);
    await tester.tap(find.text('Bénéficiaires').last);
    await _wait(tester);
    expect(find.text('Récents'), findsOneWidget);

    // Ajout d'un client Exim : le nom du titulaire est retrouvé à partir du numéro.
    await tester.tap(find.text('Ajouter'));
    await _wait(tester);
    expect(find.text('Ajouter un bénéficiaire'), findsOneWidget);
    await tester.enterText(find.byType(TextFormField).first, '00100665544');
    await _wait(tester);
    expect(find.text('Said Ali Mmadi'), findsOneWidget);
    await tester.tap(find.text('Enregistrer'));
    await _wait(tester);
    expect(find.text('Bénéficiaire ajouté'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Said Ali Mmadi'), 200, scrollable: _mainList());

    // Fiche, puis renommage
    await tester.tap(find.text('Said Ali Mmadi'));
    await _wait(tester);
    expect(find.text('Vos échanges'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.more_vert));
    await _wait(tester);
    await tester.tap(find.text('Renommer'));
    await _wait(tester);
    await tester.enterText(find.byType(TextField).last, 'Said Mmadi');
    await tester.tap(find.text('Enregistrer'));
    await _wait(tester);
    expect(find.text('Said Mmadi'), findsOneWidget);

    // Suppression
    await tester.tap(find.byIcon(Icons.more_vert));
    await _wait(tester);
    await tester.tap(find.text('Supprimer'));
    await _wait(tester);
    await tester.tap(find.widgetWithText(FilledButton, 'Supprimer'));
    await _wait(tester);
    expect(find.text('Bénéficiaire supprimé'), findsOneWidget);
    expect(find.text('Said Mmadi'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Fiche bénéficiaire : historique des virements échangés', (tester) async {
    await _startUnlocked(tester);
    await tester.tap(find.text('Bénéficiaires').last);
    await _wait(tester);
    await tester.scrollUntilVisible(find.text('Nazira Mbotimora'), 200, scrollable: _mainList());
    await tester.tap(find.text('Nazira Mbotimora'));
    await _wait(tester);
    expect(find.textContaining('Total envoyé'), findsOneWidget);
    final tiles = tester.widgetList<TransactionTile>(find.descendant(
      of: find.byType(BeneficiaryDetailScreen),
      matching: find.byType(TransactionTile, skipOffstage: false),
    ));
    expect(tiles, isNotEmpty);
    expect(tiles.every((t) => t.tx.counterpartyAccount == '00100998877'), isTrue);
  });

  testWidgets('Historique : filtre par type « Factures »', (tester) async {
    await _startUnlocked(tester);
    await tester.tap(find.text('Tout afficher'));
    await _wait(tester);
    await tester.ensureVisible(find.text('Type'));
    await tester.tap(find.text('Type'));
    await _wait(tester);
    await tester.tap(find.text('Factures'));
    await tester.pump();
    await tester.tap(find.text('Appliquer'));
    await _wait(tester);

    expect(find.text('Type : Factures'), findsOneWidget);
    final tiles = tester.widgetList<TransactionTile>(find.byType(TransactionTile));
    expect(tiles, isNotEmpty);
    expect(tiles.every((t) => t.tx.category == TxCategory.bill), isTrue);

    // « Effacer » retire les filtres
    await tester.ensureVisible(find.text('Effacer'));
    await tester.tap(find.text('Effacer'));
    await _wait(tester);
    expect(find.text('Type'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

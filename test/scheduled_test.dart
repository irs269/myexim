import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myexim/core/app_scope.dart';
import 'package:myexim/core/l10n/strings.dart';
import 'package:myexim/core/session.dart';
import 'package:myexim/data/mock_auth_repository.dart';
import 'package:myexim/data/mock_bank_repository.dart';
import 'package:myexim/data/models.dart';
import 'package:myexim/features/payments/payments_screen.dart';
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

/// Ouvre une tuile de l'onglet Paiements, en la faisant défiler hors de la barre de navigation.
Future<void> _openTile(WidgetTester tester, String label) async {
  final list = find.descendant(of: find.byType(PaymentsScreen), matching: find.byType(Scrollable)).first;
  await tester.scrollUntilVisible(find.text(label), 300, scrollable: list);
  await tester.drag(list, const Offset(0, -250));
  await tester.pump();
  await tester.tap(find.text(label));
  await _wait(tester);
}

const _acc = Account(number: 'A', label: 'Courant', currency: 'KMF', balance: 1, type: AccountType.current, iban: '');
const _to = TransferDestination.ownAccount(_acc);

ScheduledTransfer _sched(ScheduleFrequency f, DateTime start, {DateTime? end, ScheduleStatus status = ScheduleStatus.active}) =>
    ScheduledTransfer(
      id: 'x',
      fromAccountNumber: 'A',
      to: _to,
      amount: 1000,
      frequency: f,
      startDate: start,
      endDate: end,
      purpose: TransferPurpose.rent,
      status: status,
    );

void main() {
  group('Échéancier', () {
    test('mensuel le 31 : ramené au dernier jour du mois (année bissextile comprise)', () {
      final start = DateTime(2028, 1, 31);
      expect(occurrence(start, ScheduleFrequency.monthly, 1), DateTime(2028, 2, 29));
      expect(occurrence(start, ScheduleFrequency.monthly, 3), DateTime(2028, 4, 30));
      expect(occurrence(start, ScheduleFrequency.monthly, 12), DateTime(2029, 1, 31));
    });

    test('hebdomadaire et trimestriel', () {
      final start = DateTime(2026, 10, 9);
      expect(occurrence(start, ScheduleFrequency.weekly, 2), DateTime(2026, 10, 23));
      expect(occurrence(start, ScheduleFrequency.quarterly, 1), DateTime(2027, 1, 9));
    });

    test('prochaines exécutions : ignore le passé et respecte la date de fin', () {
      final t = _sched(ScheduleFrequency.monthly, DateTime(2026, 8, 5), end: DateTime(2026, 12, 1));
      expect(t.upcoming(from: DateTime(2026, 10, 8), count: 5), [DateTime(2026, 11, 5)]);
    });

    test('virement unique : une seule date ; annulé : aucune', () {
      final once = _sched(ScheduleFrequency.once, DateTime(2026, 10, 20));
      expect(once.upcoming(from: DateTime(2026, 10, 8), count: 3), [DateTime(2026, 10, 20)]);
      expect(once.copyWith(status: ScheduleStatus.cancelled).upcoming(from: DateTime(2026, 10, 8)), isEmpty);
    });
  });

  Future<MockBankRepository> start(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 4000); // écran haut : formulaires visibles sans défiler
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
    return repo;
  }

  testWidgets('Créer un ordre permanent mensuel vers un bénéficiaire', (tester) async {
    final repo = await start(tester);
    await _openTile(tester, 'Ordres permanents');
    expect(find.text('Flangia Inasy'), findsOneWidget); // ordre d'exemple (loyer)

    await tester.tap(find.text('Créer un ordre permanent').first);
    await _wait(tester);
    final confirm = find.widgetWithText(FilledButton, 'Confirmer la programmation');
    expect(tester.widget<FilledButton>(confirm).onPressed, isNull);

    await tester.tap(find.text('Choisir un bénéficiaire'));
    await _wait(tester);
    await tester.tap(find.text('Nazira Mbotimora').last);
    await _wait(tester);
    await tester.enterText(find.byType(TextField).first, '50000');
    await _wait(tester);
    expect(find.text('Chaque mois'), findsOneWidget);
    await tester.tap(find.text('Choisissez un motif'));
    await _wait(tester);
    await tester.tap(find.text('Famille et amis'));
    await _wait(tester);
    expect(find.text('Prochaines exécutions'), findsOneWidget);

    await tester.tap(confirm);
    await _wait(tester);
    await _typePin(tester, '1234');
    await _wait(tester);
    expect(find.text('Ordre permanent créé'), findsOneWidget);

    final all = (await tester.runAsync(repo.getScheduledTransfers))!;
    final created = all.firstWhere((t) => t.to.name == 'Nazira Mbotimora' && t.isRecurring);
    expect(created.amount, 50000);
    expect(created.frequency, ScheduleFrequency.monthly);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Suspendre, reprendre puis annuler un ordre permanent', (tester) async {
    final repo = await start(tester);
    await _openTile(tester, 'Ordres permanents');
    await tester.tap(find.text('Flangia Inasy'));
    await _wait(tester);
    expect(find.text('Prochaines exécutions'), findsOneWidget);

    await tester.tap(find.text('Suspendre'));
    await _wait(tester);
    expect(find.text('Reprendre'), findsOneWidget);
    expect((await tester.runAsync(repo.getScheduledTransfers))!.first.status, ScheduleStatus.paused);
    await tester.tap(find.text('Reprendre'));
    await _wait(tester);

    await tester.tap(find.text('Annuler la programmation'));
    await _wait(tester);
    await tester.tap(find.widgetWithText(FilledButton, 'Annuler la programmation'));
    await _wait(tester);
    await _typePin(tester, '1234');
    await _wait(tester);
    expect(find.text('Programmation annulée'), findsOneWidget);
    expect(find.text('Flangia Inasy'), findsNothing);
    expect(find.text('Aucun ordre permanent'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Programmer un virement unique vers l\'épargne', (tester) async {
    final repo = await start(tester);
    await _openTile(tester, 'Virements planifiés');
    expect(find.text('Nazira Mbotimora'), findsOneWidget); // virement planifié d'exemple
    await tester.tap(find.text('Programmer un virement').first);
    await _wait(tester);

    await tester.tap(find.text('Choisir un bénéficiaire'));
    await _wait(tester);
    await tester.tap(find.text('Compte épargne').last);
    await _wait(tester);
    await tester.enterText(find.byType(TextField).first, '20000');
    await _wait(tester);
    expect(find.text('Chaque mois'), findsNothing); // pas de fréquence pour un virement unique
    await tester.tap(find.text('Choisissez un motif'));
    await _wait(tester);
    await tester.tap(find.text('Épargne'));
    await _wait(tester);
    await tester.tap(find.text('Confirmer la programmation'));
    await _wait(tester);
    await _typePin(tester, '1234');
    await _wait(tester);
    expect(find.text('Virement programmé'), findsOneWidget);

    final created = (await tester.runAsync(repo.getScheduledTransfers))!.first;
    expect(created.isRecurring, isFalse);
    expect(created.to.isOwnAccount, isTrue);
    final tomorrow = DateTime.now().add(const Duration(days: 1));
    expect(created.startDate, DateTime(tomorrow.year, tomorrow.month, tomorrow.day));
  });
}

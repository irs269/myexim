import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myexim/core/app_scope.dart';
import 'package:myexim/core/l10n/strings.dart';
import 'package:myexim/core/session.dart';
import 'package:myexim/data/mock_auth_repository.dart';
import 'package:myexim/data/mock_bank_repository.dart';
import 'package:myexim/data/models.dart';
import 'package:myexim/main.dart';

/// Données simulées dont le compte courant appartient à une autre personne.
class _OtherOwnerRepository extends MockBankRepository {
  _OtherOwnerRepository() : super(latency: Duration.zero);

  @override
  Future<List<Account>> getAccounts() async => [
        for (final a in await super.getAccounts())
          a.number == '00100234567'
              ? Account(
                  number: a.number,
                  label: a.label,
                  currency: a.currency,
                  balance: a.balance,
                  type: a.type,
                  iban: a.iban,
                  holderName: 'Fatima Said Hassane',
                )
              : a,
      ];
}

Future<void> _wait(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 600));
  await tester.pump(const Duration(milliseconds: 600));
}

Future<void> _openCards(WidgetTester tester, MockBankRepository repo) async {
  tester.view.physicalSize = const Size(1080, 2340);
  tester.view.devicePixelRatio = 2.6;
  addTearDown(tester.view.reset);
  FlutterSecureStorage.setMockInitialValues({});
  final session = SessionController(auth: MockAuthRepository());
  await session.restore();
  session.onLoginVerified('t');
  await session.createPin('1234');
  session.finishEnrollment();
  await tester.pumpWidget(AppScope(
    repository: repo,
    session: session,
    language: ValueNotifier(AppLanguage.fr),
    child: const MyEximApp(),
  ));
  await _wait(tester);
  await tester.tap(find.text('Cartes').last);
  await _wait(tester);
}

void main() {
  testWidgets('La carte porte le nom du titulaire du compte rattaché', (tester) async {
    await _openCards(tester, MockBankRepository(latency: Duration.zero));
    expect(find.text('ABDOU MOHAMED'), findsWidgets);
  });

  testWidgets('Si le titulaire du compte change, le nom sur la carte suit', (tester) async {
    await _openCards(tester, _OtherOwnerRepository());
    expect(find.text('FATIMA SAID HASSANE'), findsOneWidget);
    expect(find.text('ABDOU MOHAMED'), findsWidgets); // la carte Gold reste sur le compte euros
  });
}

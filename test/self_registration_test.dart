import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myexim/core/app_scope.dart';
import 'package:myexim/core/l10n/strings.dart';
import 'package:myexim/core/session.dart';
import 'package:myexim/data/auth_repository.dart';
import 'package:myexim/data/mock_auth_repository.dart';
import 'package:myexim/data/mock_bank_repository.dart';
import 'package:myexim/main.dart';

Future<void> _wait(WidgetTester tester, [int ms = 800]) async {
  await tester.pump();
  await tester.pump(Duration(milliseconds: ms));
  await tester.pump(Duration(milliseconds: ms));
}

void main() {
  group('Première connexion : identifiant + date de naissance', () {
    final auth = MockAuthRepository();

    test('numéro de compte et date de naissance corrects → OTP au téléphone enregistré', () async {
      final c = await auth.startSelfRegistration(
        type: SelfRegistrationId.accountNumber,
        identifier: '00100234567',
        birthDate: DateTime(1990, 5, 14),
      );
      expect(c.purpose, OtpPurpose.selfRegistration);
      expect(c.maskedPhone, '+269 33* ** 45');
    });

    test('numéro client et date de naissance corrects', () async {
      final c = await auth.startSelfRegistration(
        type: SelfRegistrationId.customerNumber,
        identifier: '100998',
        birthDate: DateTime(1994, 2, 3, 15), // l'heure est ignorée
      );
      expect(c.maskedPhone, '+269 32* ** 18');
    });

    test('date de naissance erronée → refus', () {
      expect(
        auth.startSelfRegistration(
          type: SelfRegistrationId.accountNumber,
          identifier: '00100234567',
          birthDate: DateTime(1990, 5, 15),
        ),
        throwsA(isA<AuthException>()),
      );
    });

    test('un numéro de compte saisi comme numéro client est refusé', () {
      expect(
        auth.startSelfRegistration(
          type: SelfRegistrationId.customerNumber,
          identifier: '00100234567',
          birthDate: DateTime(1990, 5, 14),
        ),
        throwsA(isA<AuthException>()),
      );
    });

    test('compte ouvert en ligne : titulaire né le 25/10/1991', () async {
      final c = await auth.startSelfRegistration(
        type: SelfRegistrationId.accountNumber,
        identifier: '00100437831',
        birthDate: DateTime(1991, 10, 25),
      );
      expect(c.purpose, OtpPurpose.selfRegistration);
    });
  });

  testWidgets('Écran : choix de l\'identifiant, date via le calendrier, message si non concordant', (tester) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 2.6;
    addTearDown(tester.view.reset);
    FlutterSecureStorage.setMockInitialValues({});

    final session = SessionController(auth: MockAuthRepository());
    await session.restore();
    await tester.pumpWidget(AppScope(
      repository: MockBankRepository(latency: Duration.zero),
      session: session,
      language: ValueNotifier(AppLanguage.fr),
      child: const MyEximApp(),
    ));
    await _wait(tester);

    await tester.tap(find.text('Auto-inscription'));
    await _wait(tester);
    expect(find.text('Numéro de téléphone'), findsNothing); // l'OTP part au numéro connu de la banque

    // Les deux champs sont obligatoires
    await tester.tap(find.text('Continuer'));
    await tester.pump();
    expect(find.text('Champ obligatoire'), findsNWidgets(2));

    // Numéro client + date choisie dans le calendrier (date proposée par défaut, non concordante)
    await tester.tap(find.text('Numéro client'));
    await tester.pump();
    await tester.enterText(find.byType(TextFormField).first, '100998');
    await tester.tap(find.text('JJ/MM/AAAA'));
    await _wait(tester, 400);
    await tester.tap(find.text('OK'));
    await _wait(tester, 400);
    expect(find.textContaining('/01/'), findsOneWidget);

    await tester.tap(find.text('Continuer'));
    await _wait(tester);
    expect(find.text('Ces informations ne correspondent pas à nos fichiers'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

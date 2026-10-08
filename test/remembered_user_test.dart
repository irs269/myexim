import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myexim/core/app_scope.dart';
import 'package:myexim/core/l10n/strings.dart';
import 'package:myexim/core/session.dart';
import 'package:myexim/data/mock_auth_repository.dart';
import 'package:myexim/data/mock_bank_repository.dart';
import 'package:myexim/main.dart';

Future<void> _wait(WidgetTester tester, [int ms = 800]) async {
  await tester.pump();
  await tester.pump(Duration(milliseconds: ms));
  await tester.pump(Duration(milliseconds: ms));
}

Future<void> _typePin(WidgetTester tester, String pin) async {
  for (final d in pin.split('')) {
    await tester.tap(find.text(d).last);
    await tester.pump();
  }
  await _wait(tester, 300);
}

Future<SessionController> _start(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1080, 2340);
  tester.view.devicePixelRatio = 2.6;
  addTearDown(tester.view.reset);
  final session = SessionController(auth: MockAuthRepository());
  await session.restore();
  await tester.pumpWidget(AppScope(
    repository: MockBankRepository(latency: Duration.zero),
    session: session,
    language: ValueNotifier(AppLanguage.fr),
    child: const MyEximApp(),
  ));
  await _wait(tester);
  return session;
}

/// Connexion complète : identifiant + mot de passe → OTP → création du PIN.
Future<void> _firstLogin(WidgetTester tester) async {
  await tester.tap(find.text('Connexion'));
  await _wait(tester);
  await tester.enterText(find.byType(TextFormField).at(0), 'abdou');
  await tester.enterText(find.byType(TextFormField).at(1), 'secret');
  await tester.tap(find.text('Continuer'));
  await _wait(tester);
  await tester.enterText(find.byType(TextField).first, MockAuthRepository.mockOtp);
  await _wait(tester);
  await _typePin(tester, '1234');
  await _typePin(tester, '1234');
  await _wait(tester, 1500);
}

void main() {
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));

  testWidgets('Après la 1re connexion, le nom est affiché et seul le mot de passe est demandé', (tester) async {
    final session = await _start(tester);
    await _firstLogin(tester);
    expect(find.text('Solde total'), findsOneWidget);
    expect(session.rememberedUser?.displayName, 'Abdou Mohamed');

    // Déconnexion depuis le profil : le client reste mémorisé
    await tester.tap(find.text('AM'));
    await _wait(tester);
    await tester.tap(find.text('Se déconnecter'));
    await _wait(tester);
    await tester.tap(find.text('Connexion'));
    await _wait(tester);

    expect(find.text('Bonjour,'), findsOneWidget);
    expect(find.text('Abdou Mohamed'), findsOneWidget);
    expect(find.text('Identifiant'), findsNothing);
    expect(find.byType(TextFormField), findsOneWidget); // mot de passe uniquement

    // Connexion avec le seul mot de passe → code SMS
    await tester.enterText(find.byType(TextFormField), 'secret');
    await tester.tap(find.text('Continuer'));
    await _wait(tester);
    expect(find.text('Entrez le code reçu par SMS'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.arrow_back).last);
    await _wait(tester);

    // Changer de compte → l'identifiant est redemandé
    await tester.tap(find.text('Changer de compte'));
    await _wait(tester);
    expect(find.text('Identifiant'), findsOneWidget);
    expect(session.rememberedUser, isNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets('« Ce n\'est pas vous ? » sur l\'écran PIN oublie le client', (tester) async {
    final session = await _start(tester);
    await _firstLogin(tester);
    session.lock();
    await _wait(tester);
    await tester.tap(find.text('Ce n\'est pas vous ? Se déconnecter'));
    await _wait(tester);
    expect(session.rememberedUser, isNull);
    await tester.tap(find.text('Connexion'));
    await _wait(tester);
    expect(find.text('Identifiant'), findsOneWidget);
  });

  testWidgets('Le client mémorisé survit au redémarrage de l\'app', (tester) async {
    await _start(tester);
    await _firstLogin(tester);
    // Nouveau contrôleur sur le même stockage = redémarrage
    final restarted = SessionController(auth: MockAuthRepository());
    await restarted.restore();
    expect(restarted.rememberedUser?.username, 'abdou');
    expect(restarted.rememberedUser?.displayName, 'Abdou Mohamed');
  });
}

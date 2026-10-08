import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myexim/core/app_scope.dart';
import 'package:myexim/core/l10n/strings.dart';
import 'package:myexim/core/session.dart';
import 'package:myexim/data/auth_repository.dart';
import 'package:myexim/data/mock_auth_repository.dart';
import 'package:myexim/data/mock_bank_repository.dart';
import 'package:myexim/features/onboarding/onboarding_widgets.dart';
import 'package:myexim/main.dart';

Future<void> _wait(WidgetTester tester, [int ms = 800]) async {
  await tester.pump();
  await tester.pump(Duration(milliseconds: ms));
  await tester.pump(Duration(milliseconds: ms));
  await tester.pump(Duration(milliseconds: ms));
}

Future<void> _pick(WidgetTester tester, String dropdownLabel, String option) async {
  final dropdown = find.ancestor(of: find.text(dropdownLabel), matching: find.byType(DropdownButtonFormField<dynamic>, skipOffstage: false));
  await tester.ensureVisible(find.text(dropdownLabel));
  await tester.tap(dropdown.evaluate().isEmpty ? find.text(dropdownLabel) : dropdown.first);
  await _wait(tester, 300);
  await tester.tap(find.text(option).last);
  await _wait(tester, 300);
}

void main() {
  group('Suivi simulé de la demande', () {
    final auth = MockAuthRepository();

    test('une demande récente est « reçue »', () async {
      final ref = await auth.submitAccountApplication(
        onboardingToken: 't',
        application: const AccountApplication(
          nin: '1991102512', phone: '+2693312345', email: 'a@b.km', annualIncome: 1, employment: 'x',
          building: 'b', street: 's', city: 'Moroni', country: 'KM', branch: 'Moroni', accountType: 'courant',
          currency: 'KMF', requestCard: true,
        ),
      );
      expect((await auth.getApplicationStatus(ref)).status, ApplicationStatus.submitted);
    });

    test('après 3 minutes le compte est ouvert, avec un numéro', () async {
      final old = DateTime.now().subtract(const Duration(minutes: 5)).millisecondsSinceEpoch ~/ 1000;
      final info = await auth.getApplicationStatus('OUV$old');
      expect(info.status, ApplicationStatus.approved);
      expect(info.accountNumber, startsWith('00100'));
    });
  });

  testWidgets('Ouverture de compte : NIN, OTP, empreinte, informations, demande et suivi', (tester) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 2.6;
    addTearDown(tester.view.reset);
    FlutterSecureStorage.setMockInitialValues({});
    OnboardingStore.pendingRef.value = null;
    fingerprintCaptureOverride = (_, _) async => '/tmp/fingers.jpg';
    addTearDown(() => fingerprintCaptureOverride = null);

    final session = SessionController(auth: MockAuthRepository());
    await session.restore();
    await tester.pumpWidget(AppScope(
      repository: MockBankRepository(latency: Duration.zero),
      session: session,
      language: ValueNotifier(AppLanguage.fr),
      child: const MyEximApp(),
    ));
    await _wait(tester);

    // 1. À propos de vous
    await tester.tap(find.text('Ouvrir un compte'));
    await _wait(tester);
    expect(find.text('Faisons connaissance'), findsOneWidget);
    final header = tester.getSize(find.ancestor(of: find.text('À propos de vous'), matching: find.byType(Container)).last);
    expect(header.width, tester.view.physicalSize.width / tester.view.devicePixelRatio);
    await tester.enterText(find.byType(TextFormField).at(0), '1991102512109');
    await tester.enterText(find.byType(TextFormField).at(1), '3312345');
    await tester.enterText(find.byType(TextFormField).at(2), 'said@exemple.km');
    await tester.pump();
    expect(find.byIcon(Icons.check_circle), findsNWidgets(3)); // coches de validation
    await tester.tap(find.text('Recevoir le code de vérification'));
    await _wait(tester);

    // Code SMS
    await tester.enterText(find.byType(TextField).first, MockAuthRepository.mockOtp);
    await _wait(tester);

    // 2. Empreinte : choix de la main, conseils, vérification
    expect(find.text('Vérifiez votre identité'), findsOneWidget);
    await tester.tap(find.text('Scanner mon empreinte'));
    await _wait(tester, 300);
    await tester.tap(find.text('Droite'));
    await _wait(tester);
    expect(find.text('1. Tendez la main, doigts serrés'), findsOneWidget);
    await tester.tap(find.text('Suivant'));
    await _wait(tester);
    await _wait(tester); // vérification simulée (~2 s)
    expect(find.text('Vérification réussie'), findsOneWidget);
    await tester.tap(find.text('Continuer'));
    await _wait(tester);

    // Données du registre
    expect(find.text('SAID ALI MMADI'), findsOneWidget);
    await tester.tap(find.text('Confirmer et continuer'));
    await _wait(tester);

    // 3. Informations complémentaires (rue et ville pré-remplies depuis le registre)
    expect(find.text('Rue De La Corniche'), findsOneWidget);
    await tester.enterText(find.byType(TextFormField).at(0), '1500000');
    await _pick(tester, 'Situation professionnelle', 'Salarié');
    await tester.enterText(find.byType(TextFormField).at(1), 'Villa 12');
    await _pick(tester, 'Agence', 'Moroni — Siège');
    await tester.tap(find.text('Continuer'));
    await _wait(tester);

    // Récapitulatif
    expect(find.textContaining('Villa 12'), findsOneWidget);
    await tester.tap(find.text('Confirmer et continuer'));
    await _wait(tester);

    // 4. Ouvrir un compte : le bouton reste inactif tant que tout n'est pas choisi
    expect(find.text('Ouvrir un compte'), findsOneWidget);
    final next = find.widgetWithText(FilledButton, 'Suivant');
    expect(tester.widget<FilledButton>(next).onPressed, isNull);
    await _pick(tester, 'Type de compte', 'Compte courant');
    expect(find.text('Devise du compte'), findsNothing); // comptes en KMF uniquement
    await _pick(tester, 'Demande de carte', 'Oui');
    await tester.tap(find.byType(Checkbox));
    await tester.pump();
    await tester.tap(next);
    await _wait(tester);

    expect(find.text('Demande envoyée'), findsOneWidget);
    expect(OnboardingStore.pendingRef.value, startsWith('OUV'));

    // Retour à l'accueil : la tuile de suivi apparaît
    await tester.tap(find.text('Terminé'));
    await _wait(tester);
    expect(find.text('Suivre ma demande d\'ouverture'), findsOneWidget);
    await tester.tap(find.text('Suivre ma demande d\'ouverture'));
    await _wait(tester);
    expect(find.text('Reçue'), findsOneWidget);
    expect(find.text('Actualiser'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

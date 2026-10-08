import 'auth_repository.dart';

/// Simulation de l'authentification.
/// Identifiants de test : n'importe quel identifiant + un mot de passe d'au moins
/// 4 caractères. Code OTP de test : [mockOtp].
class MockAuthRepository implements AuthRepository {
  static const mockOtp = '123456';
  static const _latency = Duration(milliseconds: 700);

  @override
  Future<OtpChallenge> login({required String username, required String password}) async {
    await Future.delayed(_latency);
    if (password.length < 4) throw const AuthException('Identifiant ou mot de passe incorrect');
    return const OtpChallenge(
      id: 'otp-login',
      maskedPhone: '+269 33* ** 45',
      purpose: OtpPurpose.login,
      customerName: 'Abdou Mohamed',
    );
  }

  /// Fichier clients simulé : (numéro de compte, numéro client, date de naissance, téléphone masqué).
  static final _customers = [
    ('00100234567', '100234', DateTime(1990, 5, 14), '+269 33* ** 45'),
    ('00100234568', '100234', DateTime(1990, 5, 14), '+269 33* ** 45'),
    ('00100998877', '100998', DateTime(1994, 2, 3), '+269 32* ** 18'),
  ];

  /// Comptes ouverts en ligne (référence OUV…) : titulaire de démonstration né le 25/10/1991.
  static final _onlineAccountBirthDate = DateTime(1991, 10, 25);

  @override
  Future<OtpChallenge> startSelfRegistration({
    required SelfRegistrationId type,
    required String identifier,
    required DateTime birthDate,
  }) async {
    await Future.delayed(_latency);
    final id = identifier.replaceAll(RegExp(r'\s'), '');
    final day = DateTime(birthDate.year, birthDate.month, birthDate.day);
    const mismatch = AuthException('Ces informations ne correspondent pas à nos fichiers');

    for (final (account, customer, dob, phone) in _customers) {
      final idMatches = type == SelfRegistrationId.accountNumber ? account == id : customer == id;
      if (idMatches) {
        if (dob != day) throw mismatch;
        return OtpChallenge(id: 'otp-reg', maskedPhone: phone, purpose: OtpPurpose.selfRegistration);
      }
    }
    // Compte ouvert via l'app (phase « ouverture de compte ») : n° 00100 + 6 chiffres.
    if (type == SelfRegistrationId.accountNumber && RegExp(r'^00100\d{6}$').hasMatch(id) && day == _onlineAccountBirthDate) {
      return const OtpChallenge(id: 'otp-reg', maskedPhone: '+269 *** ** 45', purpose: OtpPurpose.selfRegistration);
    }
    throw mismatch;
  }

  @override
  Future<String> verifyOtp({required OtpChallenge challenge, required String code}) async {
    await Future.delayed(_latency);
    if (code != mockOtp) throw const AuthException('Code incorrect ou expiré');
    return 'mock-token-${challenge.id}-${DateTime.now().millisecondsSinceEpoch}';
  }

  @override
  Future<void> resendOtp(OtpChallenge challenge) => Future.delayed(_latency);

  @override
  Future<void> completeSelfRegistration({
    required String registrationToken,
    required String username,
    required String password,
  }) =>
      Future.delayed(_latency);

  @override
  Future<void> logout(String sessionToken) => Future.delayed(const Duration(milliseconds: 200));

  // --- Ouverture de compte -------------------------------------------------

  /// Délais de traitement simulés de la demande (à partir du dépôt).
  static const reviewAfter = Duration(minutes: 1);
  static const approvedAfter = Duration(minutes: 3);

  @override
  Future<OtpChallenge> startOnboarding({required String nin, required String phone, required String email}) async {
    await Future.delayed(_latency);
    if (nin.replaceAll(RegExp(r'\s'), '').length < 10) {
      throw const AuthException("Numéro d'identité national introuvable");
    }
    final digits = phone.replaceAll(RegExp(r'\D'), '');
    final tail = digits.length >= 2 ? digits.substring(digits.length - 2) : digits;
    return OtpChallenge(id: 'otp-onb', maskedPhone: '+269 *** ** $tail', purpose: OtpPurpose.onboarding);
  }

  @override
  Future<IdentityRecord> verifyIdentity({
    required String onboardingToken,
    required String nin,
    required Hand hand,
    required String fingerprintPath,
  }) async {
    await Future.delayed(_latency * 3);
    return IdentityRecord(
      nin: nin.replaceAll(RegExp(r'\s'), ''),
      fullName: 'SAID ALI MMADI',
      birthDate: DateTime(1991, 10, 25),
      gender: Gender.male,
      nationality: 'COMORIENNE',
      residenceIsland: 'NGAZIDJA',
      residenceCity: 'MORONI',
      residenceDistrict: 'MAGOUDJOU',
      residenceStreet: 'RUE DE LA CORNICHE',
      birthPlace: 'MORONI (NGAZIDJA)',
      birthCountry: 'UNION DES COMORES',
      postalAddress: 'BP 1234',
    );
  }

  @override
  Future<String> submitAccountApplication({
    required String onboardingToken,
    required AccountApplication application,
  }) async {
    await Future.delayed(_latency * 2);
    // L'horodatage est encodé dans la référence : le suivi simulé survit au redémarrage de l'app.
    return 'OUV${DateTime.now().millisecondsSinceEpoch ~/ 1000}';
  }

  @override
  Future<ApplicationStatusInfo> getApplicationStatus(String reference) async {
    await Future.delayed(_latency);
    final seconds = int.tryParse(reference.replaceFirst('OUV', ''));
    if (seconds == null) throw const AuthException('Demande introuvable');
    final elapsed = DateTime.now().difference(DateTime.fromMillisecondsSinceEpoch(seconds * 1000));
    if (elapsed < reviewAfter) return ApplicationStatusInfo(reference: reference, status: ApplicationStatus.submitted);
    if (elapsed < approvedAfter) return ApplicationStatusInfo(reference: reference, status: ApplicationStatus.inReview);
    return ApplicationStatusInfo(
      reference: reference,
      status: ApplicationStatus.approved,
      accountNumber: '00100${(seconds % 1000000).toString().padLeft(6, '0')}',
    );
  }
}

/// Authentification auprès du back-end. Les signatures seront alignées sur
/// la documentation des API (noms des champs, format des jetons).
abstract class AuthRepository {
  /// Vérifie identifiant + mot de passe et déclenche l'envoi d'un OTP.
  Future<OtpChallenge> login({required String username, required String password});

  /// Démarre l'activation d'un client existant : son identifiant ([type]) et sa date de naissance
  /// doivent correspondre au fichier de la banque. L'OTP part au numéro enregistré à la banque.
  /// Lève [AuthException] si les informations ne correspondent pas.
  Future<OtpChallenge> startSelfRegistration({
    required SelfRegistrationId type,
    required String identifier,
    required DateTime birthDate,
  });

  /// Valide l'OTP. Pour une connexion, renvoie le jeton de session.
  Future<String> verifyOtp({required OtpChallenge challenge, required String code});

  Future<void> resendOtp(OtpChallenge challenge);

  /// Fin de l'auto-inscription : création des identifiants de connexion.
  Future<void> completeSelfRegistration({
    required String registrationToken,
    required String username,
    required String password,
  });

  Future<void> logout(String sessionToken);

  // --- Ouverture de compte (client non encore titulaire) ---------------------

  /// Vérifie le numéro national d'identité (NIN) et envoie un OTP au mobile.
  Future<OtpChallenge> startOnboarding({required String nin, required String phone, required String email});

  /// Vérifie l'empreinte auprès du registre national et renvoie les données d'état civil.
  /// [fingerprintPath] : capture produite par le kit biométrique (ou photo des doigts).
  Future<IdentityRecord> verifyIdentity({
    required String onboardingToken,
    required String nin,
    required Hand hand,
    required String fingerprintPath,
  });

  /// Dépose la demande ; renvoie sa référence de suivi.
  Future<String> submitAccountApplication({required String onboardingToken, required AccountApplication application});

  Future<ApplicationStatusInfo> getApplicationStatus(String reference);
}

enum Hand { left, right }

enum Gender { male, female }

/// Données d'état civil renvoyées par le registre national après vérification.
class IdentityRecord {
  const IdentityRecord({
    required this.nin,
    required this.fullName,
    required this.birthDate,
    required this.gender,
    required this.nationality,
    required this.residenceIsland,
    required this.residenceCity,
    required this.residenceDistrict,
    required this.residenceStreet,
    required this.birthPlace,
    required this.birthCountry,
    this.houseNumber,
    this.postalAddress,
    this.photoUrl,
    this.hasSignature = true,
  });
  final String nin;
  final String fullName;
  final DateTime birthDate;
  final Gender gender;
  final String nationality;
  final String residenceIsland;
  final String residenceCity;
  final String residenceDistrict;
  final String residenceStreet;
  final String birthPlace;
  final String birthCountry;
  final String? houseNumber;
  final String? postalAddress;
  final String? photoUrl;
  final bool hasSignature;
}

/// Demande d'ouverture déposée par le client.
class AccountApplication {
  const AccountApplication({
    required this.nin,
    required this.phone,
    required this.email,
    required this.annualIncome,
    required this.employment,
    required this.building,
    required this.street,
    required this.city,
    required this.country,
    required this.branch,
    required this.accountType,
    required this.currency,
    required this.requestCard,
  });
  final String nin;
  final String phone;
  final String email;
  final double annualIncome;
  final String employment;
  final String building;
  final String street;
  final String city;
  final String country;
  final String branch;
  final String accountType;
  final String currency;
  final bool requestCard;
}

enum ApplicationStatus { submitted, inReview, approved, rejected }

class ApplicationStatusInfo {
  const ApplicationStatusInfo({required this.reference, required this.status, this.accountNumber, this.message});
  final String reference;
  final ApplicationStatus status;

  /// Numéro du compte ouvert (statut [ApplicationStatus.approved]).
  final String? accountNumber;
  final String? message;
}

enum OtpPurpose { login, selfRegistration, onboarding }

/// Identifiant utilisé pour la première connexion d'un client existant.
enum SelfRegistrationId { accountNumber, customerNumber }

class OtpChallenge {
  const OtpChallenge({required this.id, required this.maskedPhone, required this.purpose, this.customerName});
  final String id;
  final String maskedPhone;
  final OtpPurpose purpose;

  /// Nom du titulaire (connexion) : affiché aux connexions suivantes sur cet appareil.
  final String? customerName;
}

/// Erreur métier lisible par l'utilisateur (identifiants faux, OTP expiré…).
class AuthException implements Exception {
  const AuthException(this.message);
  final String message;
  @override
  String toString() => message;
}

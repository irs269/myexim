/// Pays joignables en Mobile Money : les Comores en direct (MVola), les autres
/// via le réseau Onafriq. Liste et opérateurs indicatifs : à remplacer par le
/// catalogue renvoyé par l'API (couverture réelle du contrat Exim ↔ Onafriq).
class WalletCorridor {
  const WalletCorridor({
    required this.countryCode,
    required this.countryFr,
    required this.countryEn,
    required this.dialCode,
    required this.currency,
    required this.operators,
    required this.localDigits,
    this.network,
  });

  /// Code ISO 3166-1 alpha-2 (KM, MG, TZ…).
  final String countryCode;
  final String countryFr;
  final String countryEn;

  /// Indicatif international, ex. « +261 ».
  final String dialCode;

  /// Devise reçue sur le portefeuille.
  final String currency;
  final List<String> operators;

  /// Nombre de chiffres du numéro national (sans indicatif ni 0 initial).
  final int localDigits;

  /// Réseau d'acheminement ; null = opérateur national en direct.
  final String? network;

  bool get isInternational => network != null;

  String name({required bool french}) => french ? countryFr : countryEn;
}

const comorosCorridor = WalletCorridor(
  countryCode: 'KM',
  countryFr: 'Comores',
  countryEn: 'Comoros',
  dialCode: '+269',
  currency: 'KMF',
  operators: ['MVola'],
  localDigits: 7,
);

const walletCorridors = [
  comorosCorridor,
  WalletCorridor(
    countryCode: 'MG',
    countryFr: 'Madagascar',
    countryEn: 'Madagascar',
    dialCode: '+261',
    currency: 'MGA',
    operators: ['MVola', 'Orange Money', 'Airtel Money'],
    localDigits: 9,
    network: 'Onafriq',
  ),
  WalletCorridor(
    countryCode: 'TZ',
    countryFr: 'Tanzanie',
    countryEn: 'Tanzania',
    dialCode: '+255',
    currency: 'TZS',
    operators: ['M-Pesa', 'Mixx by Yas', 'Airtel Money'],
    localDigits: 9,
    network: 'Onafriq',
  ),
  WalletCorridor(
    countryCode: 'KE',
    countryFr: 'Kenya',
    countryEn: 'Kenya',
    dialCode: '+254',
    currency: 'KES',
    operators: ['M-Pesa', 'Airtel Money'],
    localDigits: 9,
    network: 'Onafriq',
  ),
  WalletCorridor(
    countryCode: 'SN',
    countryFr: 'Sénégal',
    countryEn: 'Senegal',
    dialCode: '+221',
    currency: 'XOF',
    operators: ['Orange Money', 'Free Money'],
    localDigits: 9,
    network: 'Onafriq',
  ),
  WalletCorridor(
    countryCode: 'CI',
    countryFr: "Côte d'Ivoire",
    countryEn: "Côte d'Ivoire",
    dialCode: '+225',
    currency: 'XOF',
    operators: ['Orange Money', 'MTN MoMo', 'Moov Money'],
    localDigits: 10,
    network: 'Onafriq',
  ),
  WalletCorridor(
    countryCode: 'CM',
    countryFr: 'Cameroun',
    countryEn: 'Cameroon',
    dialCode: '+237',
    currency: 'XAF',
    operators: ['MTN MoMo', 'Orange Money'],
    localDigits: 9,
    network: 'Onafriq',
  ),
  WalletCorridor(
    countryCode: 'GH',
    countryFr: 'Ghana',
    countryEn: 'Ghana',
    dialCode: '+233',
    currency: 'GHS',
    operators: ['MTN MoMo', 'Telecel Cash', 'AirtelTigo Money'],
    localDigits: 9,
    network: 'Onafriq',
  ),
  WalletCorridor(
    countryCode: 'UG',
    countryFr: 'Ouganda',
    countryEn: 'Uganda',
    dialCode: '+256',
    currency: 'UGX',
    operators: ['MTN MoMo', 'Airtel Money'],
    localDigits: 9,
    network: 'Onafriq',
  ),
  WalletCorridor(
    countryCode: 'RW',
    countryFr: 'Rwanda',
    countryEn: 'Rwanda',
    dialCode: '+250',
    currency: 'RWF',
    operators: ['MTN MoMo', 'Airtel Money'],
    localDigits: 9,
    network: 'Onafriq',
  ),
];

WalletCorridor corridorFor(String? countryCode) =>
    walletCorridors.firstWhere((c) => c.countryCode == (countryCode ?? 'KM'), orElse: () => comorosCorridor);

/// Drapeau emoji à partir du code pays ISO (lettres indicatrices régionales).
String flagForCountry(String countryCode) =>
    String.fromCharCodes(countryCode.toUpperCase().codeUnits.map((c) => 0x1F1E6 + c - 0x41));

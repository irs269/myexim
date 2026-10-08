import '../../data/models.dart';

/// Contenu d'un QR code de paiement Exim.
///
/// Format provisoire (à aligner sur la spécification de la banque, ex. EMVCo) :
/// `EXIMPAY:1?t=<M|B|P>&id=<identifiant>&n=<nom>&a=<montant>&r=<référence>&c=<devise>`
/// - `M` commerçant, `B` facture d'une administration, `P` particulier (compte Exim).
/// - `a` et `r` sont facultatifs ; sans `a`, le client saisit le montant.
enum QrType { merchant, bill, person }

class QrPayload {
  const QrPayload({
    required this.type,
    required this.id,
    required this.name,
    this.amount,
    this.reference,
    this.currency = 'KMF',
  });

  final QrType type;
  final String id;
  final String name;
  final double? amount;
  final String? reference;
  final String currency;

  static const _scheme = 'EXIMPAY';
  static const _codes = {QrType.merchant: 'M', QrType.bill: 'B', QrType.person: 'P'};

  /// Renvoie `null` si le texte n'est pas un QR de paiement Exim valide.
  static QrPayload? tryParse(String raw) {
    final text = raw.trim();
    if (!text.toUpperCase().startsWith('$_scheme:')) return null;
    final Uri uri;
    try {
      uri = Uri.parse(text);
    } on FormatException {
      return null;
    }
    final q = uri.queryParameters;
    final type = _codes.entries.where((e) => e.value == q['t']).map((e) => e.key).firstOrNull;
    final id = q['id']?.trim() ?? '';
    final name = q['n']?.trim() ?? '';
    if (type == null || id.isEmpty || name.isEmpty) return null;
    final amount = q['a'] == null ? null : double.tryParse(q['a']!);
    if (q['a'] != null && (amount == null || amount <= 0)) return null;
    return QrPayload(
      type: type,
      id: id,
      name: name,
      amount: amount,
      reference: (q['r']?.isEmpty ?? true) ? null : q['r'],
      currency: q['c'] ?? 'KMF',
    );
  }

  String encode() => Uri(
        scheme: _scheme,
        path: '1',
        queryParameters: {
          't': _codes[type]!,
          'id': id,
          'n': name,
          if (amount != null) 'a': amount!.toStringAsFixed(amount! % 1 == 0 ? 0 : 2),
          'r': ?reference,
          if (currency != 'KMF') 'c': currency,
        },
      ).toString();

  /// Paiement commerçant ou facture (types M et B).
  PaymentRequest toPaymentRequest() => PaymentRequest(
        kind: type == QrType.bill ? PaymentKind.bill : PaymentKind.merchant,
        payeeId: id,
        payeeName: name,
        reference: reference ?? id,
        amount: amount,
        currency: currency,
      );

  /// Virement vers un client Exim (type P).
  Beneficiary toBeneficiary() => Beneficiary(id: 'qr-$id', name: name, accountNumber: id, currency: currency);
}

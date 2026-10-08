// Modèles métier. Les `fromJson` seront alignés sur les réponses
// réelles des API dès réception de leur documentation.

class Customer {
  const Customer({required this.id, required this.fullName, this.photoUrl});
  final String id;
  final String fullName;
  final String? photoUrl;
}

enum AccountType { current, savings, currency }

class Account {
  const Account({
    required this.number,
    required this.label,
    required this.currency,
    required this.balance,
    required this.type,
    required this.iban,
    this.bic = 'EXIMKMKM',
    this.branch = 'Moroni',
    this.holderName,
  });
  final String number;
  final String label;
  final String currency;
  final double balance;
  final AccountType type;
  final String iban;
  final String bic;
  final String branch;

  /// Titulaire du compte : c'est ce nom qui figure sur les cartes rattachées au compte.
  final String? holderName;
}

enum TxDirection { credit, debit }

enum TxStatus { completed, pending, failed }

enum TxCategory { transfer, bill, airtime, card, salary, fee, cash, merchant }

class BankTransaction {
  const BankTransaction({
    required this.id,
    required this.accountNumber,
    required this.label,
    required this.subtitle,
    required this.amount,
    required this.currency,
    required this.date,
    required this.direction,
    required this.reference,
    this.status = TxStatus.completed,
    this.category = TxCategory.transfer,
    this.fee = 0,
    this.counterpartyAccount,
  });
  final String id;
  final String accountNumber;
  final String label;
  final String subtitle;
  final double amount;
  final String currency;
  final DateTime date;
  final TxDirection direction;
  final String reference;
  final TxStatus status;
  final TxCategory category;
  final double fee;
  final String? counterpartyAccount;

  bool get isCredit => direction == TxDirection.credit;
}

class Beneficiary {
  const Beneficiary({
    required this.id,
    required this.name,
    required this.accountNumber,
    this.bankName = 'Exim Bank',
    this.isEximCustomer = true,
    this.currency = 'KMF',
    this.walletProvider,
    this.countryCode,
  });
  final String id;
  final String name;

  /// Numéro de compte, IBAN, ou numéro de téléphone (+269…) pour un portefeuille Mobile Money.
  final String accountNumber;
  final String bankName;
  final bool isEximCustomer;
  final String currency;

  /// Opérateur Mobile Money (ex. « MVola ») ; null pour un compte bancaire.
  final String? walletProvider;

  bool get isMobileMoney => walletProvider != null;

  /// Pays du portefeuille (ISO) ; null = Comores.
  final String? countryCode;

  /// Portefeuille hors Comores, acheminé par Onafriq.
  bool get isInternationalWallet => isMobileMoney && countryCode != null && countryCode != 'KM';

  Beneficiary copyWith({String? name}) => Beneficiary(
        id: id,
        name: name ?? this.name,
        accountNumber: accountNumber,
        bankName: bankName,
        isEximCustomer: isEximCustomer,
        currency: currency,
        walletProvider: walletProvider,
        countryCode: countryCode,
      );
}

enum CardStatus { active, frozen, blocked }

class CardLimits {
  const CardLimits({required this.atmDaily, required this.posDaily, required this.onlineDaily});
  final double atmDaily;
  final double posDaily;
  final double onlineDaily;

  CardLimits copyWith({double? atmDaily, double? posDaily, double? onlineDaily}) => CardLimits(
        atmDaily: atmDaily ?? this.atmDaily,
        posDaily: posDaily ?? this.posDaily,
        onlineDaily: onlineDaily ?? this.onlineDaily,
      );
}

class DebitCard {
  const DebitCard({
    required this.id,
    required this.holder,
    required this.last4,
    required this.network,
    required this.product,
    required this.expiry,
    required this.accountNumber,
    this.status = CardStatus.active,
    this.limits = const CardLimits(atmDaily: 300000, posDaily: 500000, onlineDaily: 200000),
    this.maxLimits = const CardLimits(atmDaily: 1000000, posDaily: 2000000, onlineDaily: 1000000),
    this.onlinePayments = true,
    this.contactless = true,
    this.international = false,
  });
  final String id;
  final String holder;
  final String last4;
  final String network;

  /// « Visa Silver », « Visa Gold »…
  final String product;

  /// « MM/AA ».
  final String expiry;
  final String accountNumber;
  final CardStatus status;

  /// Plafonds quotidiens actuels (KMF) et maximums autorisés par la banque.
  final CardLimits limits;
  final CardLimits maxLimits;
  final bool onlinePayments;
  final bool contactless;
  final bool international;

  bool get frozen => status == CardStatus.frozen;
  bool get blocked => status == CardStatus.blocked;

  DebitCard copyWith({
    CardStatus? status,
    CardLimits? limits,
    bool? onlinePayments,
    bool? contactless,
    bool? international,
  }) =>
      DebitCard(
        id: id,
        holder: holder,
        last4: last4,
        network: network,
        product: product,
        expiry: expiry,
        accountNumber: accountNumber,
        status: status ?? this.status,
        limits: limits ?? this.limits,
        maxLimits: maxLimits,
        onlinePayments: onlinePayments ?? this.onlinePayments,
        contactless: contactless ?? this.contactless,
        international: international ?? this.international,
      );
}

/// Données sensibles d'une carte, obtenues seulement après confirmation par PIN.
class CardSecrets {
  const CardSecrets({required this.pan, required this.cvv, required this.pin});
  final String pan;
  final String cvv;
  final String pin;
}

/// Destination d'un envoi : un bénéficiaire ou un autre compte du client (virement entre mes comptes).
class TransferDestination {
  const TransferDestination.beneficiary(Beneficiary this.beneficiary) : ownAccount = null;
  const TransferDestination.ownAccount(Account this.ownAccount) : beneficiary = null;

  final Beneficiary? beneficiary;
  final Account? ownAccount;

  bool get isOwnAccount => ownAccount != null;
  String get name => beneficiary?.name ?? ownAccount!.label;
  String get accountNumber => beneficiary?.accountNumber ?? ownAccount!.number;
  String get currency => beneficiary?.currency ?? ownAccount!.currency;
  String get bankName => beneficiary?.bankName ?? 'Exim Bank';

  /// Virement interne Exim : instantané et sans frais en KMF.
  bool get isInternal => isOwnAccount || beneficiary!.isEximCustomer;

  /// Envoi vers un portefeuille Mobile Money (MVola…) : instantané, frais opérateur.
  bool get isMobileMoney => beneficiary?.isMobileMoney ?? false;

  /// Portefeuille à l'étranger (Onafriq) : conversion de devise, arrivée en quelques minutes.
  bool get isInternationalWallet => beneficiary?.isInternationalWallet ?? false;
}

/// Côté du montant saisi : ce que le client envoie ou ce que le bénéficiaire reçoit.
enum AmountSide { send, receive }

class TransferQuote {
  const TransferQuote({
    required this.sendAmount,
    required this.sendCurrency,
    required this.receiveAmount,
    required this.receiveCurrency,
    required this.rate,
    required this.fee,
    required this.instant,
  });

  /// Montant converti, hors frais.
  final double sendAmount;
  final String sendCurrency;
  final double receiveAmount;
  final String receiveCurrency;

  /// 1 [sendCurrency] = [rate] [receiveCurrency].
  final double rate;

  /// Frais, dans la devise d'envoi.
  final double fee;

  /// Disponible immédiatement (sinon : un jour ouvré).
  final bool instant;

  double get totalDebited => sendAmount + fee;
  bool get isCrossCurrency => sendCurrency != receiveCurrency;
}

enum TransferPurpose { family, bills, rent, salary, education, health, business, savings, other }

/// Erreur métier sur un envoi (solde insuffisant, plafond dépassé…).
class TransferException implements Exception {
  const TransferException(this.code, [this.message]);
  final TransferError code;
  final String? message;
  @override
  String toString() => message ?? code.name;
}

enum TransferError { insufficientFunds, limitExceeded, accountNotFound, invalidAmount, unknown }

/// Critères de recherche dans l'historique, transmis tels quels au back-end.
class TransactionQuery {
  const TransactionQuery({
    this.accountNumbers = const {},
    this.direction,
    this.categories = const {},
    this.from,
    this.to,
    this.search = '',
    this.counterpartyAccount,
  });

  /// Vide = tous les comptes.
  final Set<String> accountNumbers;
  final TxDirection? direction;

  /// Vide = tous les types.
  final Set<TxCategory> categories;

  /// Bornes incluses (jour entier pour [to]).
  final DateTime? from;
  final DateTime? to;
  final String search;

  /// Opérations échangées avec un compte précis (fiche bénéficiaire).
  final String? counterpartyAccount;

  factory TransactionQuery.forAccount(String accountNumber) => TransactionQuery(accountNumbers: {accountNumber});

  bool get hasFilters =>
      accountNumbers.isNotEmpty || direction != null || categories.isNotEmpty || from != null || to != null;

  TransactionQuery copyWith({
    Set<String>? accountNumbers,
    TxDirection? Function()? direction,
    Set<TxCategory>? categories,
    DateTime? Function()? from,
    DateTime? Function()? to,
    String? search,
  }) =>
      TransactionQuery(
        accountNumbers: accountNumbers ?? this.accountNumbers,
        direction: direction != null ? direction() : this.direction,
        categories: categories ?? this.categories,
        from: from != null ? from() : this.from,
        to: to != null ? to() : this.to,
        search: search ?? this.search,
        counterpartyAccount: counterpartyAccount,
      );

  bool matches(BankTransaction t) {
    if (accountNumbers.isNotEmpty && !accountNumbers.contains(t.accountNumber)) return false;
    if (direction != null && t.direction != direction) return false;
    if (categories.isNotEmpty && !categories.contains(t.category)) return false;
    if (from != null && t.date.isBefore(from!)) return false;
    if (to != null && !t.date.isBefore(DateTime(to!.year, to!.month, to!.day + 1))) return false;
    if (counterpartyAccount != null && t.counterpartyAccount != counterpartyAccount) return false;
    final q = search.trim().toLowerCase();
    if (q.isEmpty) return true;
    return t.label.toLowerCase().contains(q) ||
        t.subtitle.toLowerCase().contains(q) ||
        t.reference.toLowerCase().contains(q);
  }
}

enum BillerCategory { electricity, water, telecom, airtime, tv, government }

/// Organisme payable depuis l'app (électricité, eau, opérateurs, administrations).
class Biller {
  const Biller({
    required this.id,
    required this.name,
    required this.category,
    required this.referenceLabel,
    this.fixedAmounts = const [],
  });
  final String id;
  final String name;
  final BillerCategory category;

  /// Libellé de l'identifiant à saisir (n° de compteur, n° de téléphone…).
  final String referenceLabel;

  /// Montants proposés (recharges) ; vide = montant de la facture.
  final List<double> fixedAmounts;

  bool get isAirtime => category == BillerCategory.airtime;
}

enum PaymentKind { bill, airtime, merchant }

/// Paiement à effectuer, issu d'une facture retrouvée, d'une recharge ou d'un QR code.
class PaymentRequest {
  const PaymentRequest({
    required this.kind,
    required this.payeeId,
    required this.payeeName,
    required this.reference,
    this.amount,
    this.currency = 'KMF',
    this.holderName,
    this.dueDate,
    this.description,
  });
  final PaymentKind kind;
  final String payeeId;
  final String payeeName;

  /// N° de facture, de compteur, de téléphone ou référence marchande.
  final String reference;

  /// Montant imposé ; `null` = saisi par le client.
  final double? amount;
  final String currency;

  /// Titulaire du contrat (facture).
  final String? holderName;
  final DateTime? dueDate;
  final String? description;

  bool get amountFixed => amount != null;
}

enum ScheduleFrequency { once, weekly, monthly, quarterly }

enum ScheduleStatus { active, paused, cancelled, completed }

/// Virement planifié (une seule fois, [ScheduleFrequency.once]) ou ordre permanent (récurrent).
/// Les exécutions sont faites par la banque ; l'app ne fait que les programmer et les gérer.
class ScheduledTransfer {
  const ScheduledTransfer({
    required this.id,
    required this.fromAccountNumber,
    required this.to,
    required this.amount,
    required this.frequency,
    required this.startDate,
    required this.purpose,
    this.endDate,
    this.note,
    this.status = ScheduleStatus.active,
  });
  final String id;
  final String fromAccountNumber;
  final TransferDestination to;

  /// Montant envoyé à chaque exécution, en KMF.
  final double amount;
  final ScheduleFrequency frequency;

  /// Première exécution (et unique pour un virement planifié).
  final DateTime startDate;

  /// Dernière exécution possible d'un ordre permanent ; null = sans fin.
  final DateTime? endDate;
  final TransferPurpose purpose;
  final String? note;
  final ScheduleStatus status;

  bool get isRecurring => frequency != ScheduleFrequency.once;

  ScheduledTransfer copyWith({ScheduleStatus? status}) => ScheduledTransfer(
        id: id,
        fromAccountNumber: fromAccountNumber,
        to: to,
        amount: amount,
        frequency: frequency,
        startDate: startDate,
        purpose: purpose,
        endDate: endDate,
        note: note,
        status: status ?? this.status,
      );

  /// Prochaines dates d'exécution à partir de [from] (inclus), au plus [count].
  List<DateTime> upcoming({required DateTime from, int count = 3}) {
    if (status == ScheduleStatus.cancelled || status == ScheduleStatus.completed) return const [];
    final today = DateTime(from.year, from.month, from.day);
    final dates = <DateTime>[];
    for (var i = 0; dates.length < count && i < 600; i++) {
      final d = occurrence(startDate, frequency, i);
      if (endDate != null && d.isAfter(endDate!)) break;
      if (!d.isBefore(today)) dates.add(d);
      if (!isRecurring) break;
    }
    return dates;
  }

  DateTime? nextRun(DateTime now) => upcoming(from: now, count: 1).firstOrNull;
}

/// [index]-ième exécution d'un échéancier. Pour les fréquences mensuelles, le jour est
/// ramené au dernier jour du mois si besoin (ex. le 31 → 30 avril, 28/29 février).
DateTime occurrence(DateTime start, ScheduleFrequency frequency, int index) {
  switch (frequency) {
    case ScheduleFrequency.once:
      return DateTime(start.year, start.month, start.day);
    case ScheduleFrequency.weekly:
      return DateTime(start.year, start.month, start.day + 7 * index);
    case ScheduleFrequency.monthly:
    case ScheduleFrequency.quarterly:
      final months = frequency == ScheduleFrequency.monthly ? index : 3 * index;
      final first = DateTime(start.year, start.month + months);
      final lastDay = DateTime(first.year, first.month + 1, 0).day;
      return DateTime(first.year, first.month, start.day > lastDay ? lastDay : start.day);
  }
}

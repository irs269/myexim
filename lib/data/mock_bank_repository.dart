import 'dart:math';

import 'package:flutter/foundation.dart';

import '../core/utils/formatters.dart' show zeroDecimalCurrencies;
import 'bank_repository.dart';
import 'models.dart';

/// Données simulées en attendant les API. Les envois modifient réellement
/// les soldes et l'historique (en mémoire, le temps de la session).
class MockBankRepository extends ChangeNotifier implements BankRepository {
  MockBankRepository({this.latency = const Duration(milliseconds: 400)});

  final Duration latency;

  /// Contre-valeur en KMF d'une unité de devise (EUR : parité fixe).
  /// Les comptes Exim sont tous en KMF ; ces contre-valeurs ne servent qu'à la
  /// réception en devise locale des envois Mobile Money internationaux (Onafriq).
  /// XOF et XAF sont, comme le KMF, arrimés à l'euro (655,957 pour 1 EUR) ;
  /// les autres devises africaines sont indicatives.
  static const toKmf = {
    'KMF': 1.0,
    'XOF': 491.96775 / 655.957,
    'XAF': 491.96775 / 655.957,
    'MGA': 0.0984,
    'TZS': 0.1718,
    'KES': 3.53,
    'GHS': 36.4,
    'UGX': 0.1247,
    'RWF': 0.3206,
  };

  /// Marge appliquée sur les opérations de change.
  static const fxMargin = 0.005;

  /// Frais d'un virement vers une autre banque, en KMF.
  static const externalFeeKmf = 1000.0;

  /// Frais d'un envoi Mobile Money : 1 % du montant, entre 250 et 2 000 KMF.
  static const walletFeeRate = 0.01;
  static const walletFeeMinKmf = 250.0;
  static const walletFeeMaxKmf = 2000.0;

  /// Portefeuilles MVola « existants » pour la vérification du titulaire.
  static const _walletDirectory = {
    '+2693312345': 'Nazira Mbotimora',
    '+2693398877': 'Ahmed Mohamed Djalim BenNour',
    '+2694410203': 'Fatima Said Hassane',
  };

  /// Frais Mobile Money international (Onafriq) : 2 %, entre 1 500 et 15 000 KMF.
  static const intlWalletFeeRate = 0.02;
  static const intlWalletFeeMinKmf = 1500.0;
  static const intlWalletFeeMaxKmf = 15000.0;

  /// Plafond par opération, en contre-valeur KMF.
  static const transferLimitKmf = 2000000.0;

  static const customerName = 'Abdou Mohamed';

  static const _seedAccounts = [
    Account(number: '00100234567', label: 'Compte courant', currency: 'KMF', balance: 1254300, type: AccountType.current, iban: 'KM46 0000 5000 0100 2345 6789 012', holderName: customerName),
    Account(number: '00100234568', label: 'Compte épargne', currency: 'KMF', balance: 480000, type: AccountType.savings, iban: 'KM46 0000 5000 0100 2345 6889 045', holderName: customerName),
  ];

  late final List<Account> _accounts = [..._seedAccounts];
  late final List<BankTransaction> _transactions = _generateTransactions();
  final List<Beneficiary> _beneficiaries = [
    const Beneficiary(id: 'B1', name: 'Nazira Mbotimora', accountNumber: '00100998877'),
    const Beneficiary(id: 'B2', name: 'Ahmed Mohamed Djalim BenNour', accountNumber: '00100887766'),
    const Beneficiary(id: 'B3', name: 'Fakih Mohamed Abdallah', accountNumber: 'KM4600005000010123456789', bankName: 'BIC Comores', isEximCustomer: false),
    const Beneficiary(id: 'B4', name: 'Flangia Inasy', accountNumber: '00100776655'),
  ];

  /// Comptes Exim « existants » pour la vérification du titulaire.
  static const _eximDirectory = {
    '00100998877': 'Nazira Mbotimora',
    '00100887766': 'Ahmed Mohamed Djalim BenNour',
    '00100776655': 'Flangia Inasy',
    '00100665544': 'Said Ali Mmadi',
    '00100554433': 'Mariama Youssouf',
  };

  final List<DebitCard> _cards = [
    const DebitCard(
      id: 'K1',
      holder: 'ABDOU MOHAMED', // = titulaire du compte rattaché (customerName)
      last4: '5546',
      network: 'VISA',
      product: 'Visa Silver',
      expiry: '09/28',
      accountNumber: '00100234567',
    ),
    const DebitCard(
      id: 'K2',
      holder: 'ABDOU MOHAMED', // = titulaire du compte rattaché (customerName)
      last4: '0912',
      network: 'VISA',
      product: 'Visa Gold',
      expiry: '03/27',
      accountNumber: '00100234568',
      status: CardStatus.frozen,
      international: true,
    ),
  ];

  static const _billers = [
    Biller(id: 'SONELEC', name: 'SONELEC', category: BillerCategory.electricity, referenceLabel: 'Numéro de compteur'),
    Biller(id: 'MAMWE', name: 'MA-MWE', category: BillerCategory.water, referenceLabel: 'Numéro de contrat'),
    Biller(id: 'CT-NET', name: 'Comores Telecom Internet', category: BillerCategory.telecom, referenceLabel: 'Numéro de ligne'),
    Biller(
      id: 'CT-AIR',
      name: 'Comores Telecom',
      category: BillerCategory.airtime,
      referenceLabel: 'Numéro de téléphone',
      fixedAmounts: [1000, 2500, 5000, 10000],
    ),
    Biller(
      id: 'YAS-AIR',
      name: 'Yas (Telma)',
      category: BillerCategory.airtime,
      referenceLabel: 'Numéro de téléphone',
      fixedAmounts: [1000, 2500, 5000, 10000],
    ),
    Biller(id: 'AGID', name: 'AGID (Impôts)', category: BillerCategory.government, referenceLabel: "Numéro d'avis"),
    Biller(id: 'DOUANE', name: 'Douanes comoriennes', category: BillerCategory.government, referenceLabel: 'Numéro de déclaration'),
  ];

  /// Factures existantes : « organisme:référence » → (titulaire, montant, échéance en jours, objet).
  static const _bills = {
    'SONELEC:1234567': ('Abdou Mohamed', 18750.0, 6, 'Électricité — septembre'),
    'MAMWE:7654321': ('Abdou Mohamed', 7300.0, 12, 'Eau — septembre'),
    'CT-NET:7730000': ('Abdou Mohamed', 25000.0, 3, 'Internet ADSL — octobre'),
    'AGID:AV2026001': ('Abdou Mohamed', 145000.0, 20, 'Impôt sur le revenu 2025'),
    'DOUANE:DC88812': ('Abdou Mohamed', 62500.0, 2, 'Droits de douane'),
  };

  /// Échéanciers d'exemple : loyer mensuel et virement planifié vers Nazira.
  late final List<ScheduledTransfer> _scheduled = () {
    final now = DateTime.now();
    return [
      ScheduledTransfer(
        id: 'S1',
        fromAccountNumber: _seedAccounts[0].number,
        to: TransferDestination.beneficiary(_beneficiaries[3]),
        amount: 75000,
        frequency: ScheduleFrequency.monthly,
        startDate: DateTime(now.year, now.month - 2, 5),
        purpose: TransferPurpose.rent,
        note: 'Loyer',
      ),
      ScheduledTransfer(
        id: 'S2',
        fromAccountNumber: _seedAccounts[0].number,
        to: TransferDestination.beneficiary(_beneficiaries[0]),
        amount: 30000,
        frequency: ScheduleFrequency.once,
        startDate: DateTime(now.year, now.month, now.day + 6),
        purpose: TransferPurpose.family,
      ),
    ];
  }();

  @override
  Listenable get changes => this;

  @override
  Future<List<ScheduledTransfer>> getScheduledTransfers() async {
    await Future.delayed(latency);
    return _scheduled.where((t) => t.status != ScheduleStatus.cancelled).toList();
  }

  @override
  Future<ScheduledTransfer> createScheduledTransfer(ScheduledTransfer t) async {
    await Future.delayed(latency * 2);
    if (t.amount <= 0) throw const TransferException(TransferError.invalidAmount);
    if (t.amount > transferLimitKmf) throw const TransferException(TransferError.limitExceeded);
    final saved = ScheduledTransfer(
      id: 'S${DateTime.now().microsecondsSinceEpoch}',
      fromAccountNumber: t.fromAccountNumber,
      to: t.to,
      amount: t.amount,
      frequency: t.frequency,
      startDate: t.startDate,
      purpose: t.purpose,
      endDate: t.endDate,
      note: t.note,
    );
    _scheduled.insert(0, saved);
    notifyListeners();
    return saved;
  }

  @override
  Future<ScheduledTransfer> setScheduledTransferStatus(String id, ScheduleStatus status) async {
    await Future.delayed(latency);
    final i = _scheduled.indexWhere((t) => t.id == id);
    _scheduled[i] = _scheduled[i].copyWith(status: status);
    notifyListeners();
    return _scheduled[i];
  }

  @override
  Future<Customer> getCustomer() async {
    await Future.delayed(latency);
    return const Customer(id: 'C001', fullName: customerName);
  }

  @override
  Future<List<Account>> getAccounts() async {
    await Future.delayed(latency);
    return List.unmodifiable(_accounts);
  }

  @override
  Future<List<BankTransaction>> getTransactions({
    TransactionQuery query = const TransactionQuery(),
    int offset = 0,
    int limit = 20,
  }) async {
    await Future.delayed(latency);
    return _transactions.where(query.matches).skip(offset).take(limit).toList();
  }

  @override
  Future<List<Beneficiary>> getBeneficiaries() async {
    await Future.delayed(latency);
    return List.unmodifiable(_beneficiaries);
  }

  @override
  Future<Beneficiary> addBeneficiary(Beneficiary b) async {
    await Future.delayed(latency);
    final saved = Beneficiary(
      id: 'B${_beneficiaries.length + 1}-${DateTime.now().millisecondsSinceEpoch}',
      name: b.name,
      accountNumber: b.accountNumber,
      bankName: b.bankName,
      isEximCustomer: b.isEximCustomer,
      currency: b.currency,
      walletProvider: b.walletProvider,
      countryCode: b.countryCode,
    );
    _beneficiaries.insert(0, saved);
    notifyListeners();
    return saved;
  }

  @override
  Future<Beneficiary> updateBeneficiary(Beneficiary b) async {
    await Future.delayed(latency);
    final i = _beneficiaries.indexWhere((x) => x.id == b.id);
    if (i >= 0) _beneficiaries[i] = b;
    notifyListeners();
    return b;
  }

  @override
  Future<void> deleteBeneficiary(String id) async {
    await Future.delayed(latency);
    _beneficiaries.removeWhere((b) => b.id == id);
    notifyListeners();
  }

  @override
  Future<List<WalletCorridor>> getWalletCorridors() async {
    await Future.delayed(latency);
    return walletCorridors;
  }

  /// Titulaires simulés des portefeuilles MVola non listés dans [_walletDirectory].
  static const _comorianHolders = [
    'Said Ahmed Ali',
    'Mariama Youssouf',
    'Ibrahim Abdallah',
    'Zaharia Mohamed',
    'Ali Hamidou',
  ];

  /// Titulaires simulés des portefeuilles étrangers (attribués selon le numéro).
  static const _foreignHolders = [
    'Aïcha Diallo',
    'John Mwangi',
    'Rova Rakotomalala',
    'Grace Achieng',
    'Kofi Mensah',
    'Amina Juma',
  ];

  @override
  Future<String?> lookupWallet({required String countryCode, required String provider, required String phone}) async {
    await Future.delayed(latency);
    final corridor = corridorFor(countryCode);
    if (!corridor.operators.contains(provider)) return null;
    final number = phone.replaceAll(RegExp(r'[^\d+]'), '');
    // Tout numéro au bon format a un portefeuille, sauf ceux finissant par 0000.
    final local = number.replaceFirst(corridor.dialCode, '');
    if (local.length != corridor.localDigits || local.endsWith('0000')) return null;
    if (!corridor.isInternational) {
      if (!RegExp(r'^[34]').hasMatch(local)) return null;
      return _walletDirectory[number] ?? _comorianHolders[int.parse(local.substring(local.length - 3)) % _comorianHolders.length];
    }
    return _foreignHolders[int.parse(local.substring(local.length - 3)) % _foreignHolders.length];
  }

  @override
  Future<String?> lookupEximAccount(String accountNumber) async {
    await Future.delayed(latency);
    final n = accountNumber.replaceAll(RegExp(r'\s'), '');
    if (_accounts.any((a) => a.number == n)) return 'Abdou Mohamed';
    return _eximDirectory[n];
  }

  @override
  Future<List<DebitCard>> getCards() async {
    await Future.delayed(latency);
    return List.unmodifiable(_cards);
  }

  @override
  Future<DebitCard> updateCard(DebitCard card) async {
    await Future.delayed(latency);
    final i = _cards.indexWhere((c) => c.id == card.id);
    if (i >= 0) _cards[i] = card;
    notifyListeners();
    return card;
  }

  @override
  Future<CardSecrets> getCardSecrets(String cardId) async {
    await Future.delayed(latency);
    final card = _cards.firstWhere((c) => c.id == cardId);
    return CardSecrets(pan: '4532 7801 2299 ${card.last4}', cvv: card.last4 == '5546' ? '318' : '702', pin: '4821');
  }

  @override
  Future<String> requestCard({required String product, required String accountNumber, required String branch}) async {
    await Future.delayed(latency * 2);
    return 'CRD${DateTime.now().millisecondsSinceEpoch % 1000000}';
  }

  @override
  Future<List<Biller>> getBillers() async {
    await Future.delayed(latency);
    return _billers;
  }

  @override
  Future<PaymentRequest> lookupBill({required Biller biller, required String reference}) async {
    await Future.delayed(latency);
    final ref = reference.replaceAll(RegExp(r'\s'), '');
    if (biller.isAirtime) {
      if (!RegExp(r'^(\+?269)?[34]\d{6}$').hasMatch(ref)) {
        throw const TransferException(TransferError.accountNotFound);
      }
      return PaymentRequest(kind: PaymentKind.airtime, payeeId: biller.id, payeeName: biller.name, reference: ref);
    }
    final bill = _bills['${biller.id}:$ref'];
    if (bill == null) throw const TransferException(TransferError.accountNotFound);
    return PaymentRequest(
      kind: PaymentKind.bill,
      payeeId: biller.id,
      payeeName: biller.name,
      reference: ref,
      amount: bill.$2,
      holderName: bill.$1,
      dueDate: DateTime.now().add(Duration(days: bill.$3)),
      description: bill.$4,
    );
  }

  @override
  Future<BankTransaction> pay({required PaymentRequest request, required Account from, required double amount}) async {
    await Future.delayed(latency * 3);
    final i = _accounts.indexWhere((a) => a.number == from.number);
    if (i < 0) throw const TransferException(TransferError.accountNotFound);
    if (amount <= 0) throw const TransferException(TransferError.invalidAmount);
    if (from.currency != request.currency) throw const TransferException(TransferError.invalidAmount);
    if (amount > _accounts[i].balance) throw const TransferException(TransferError.insufficientFunds);

    _accounts[i] = _withBalance(_accounts[i], _accounts[i].balance - amount);
    final now = DateTime.now();
    final tx = BankTransaction(
      id: 'P${now.microsecondsSinceEpoch}',
      accountNumber: from.number,
      label: request.payeeName,
      subtitle: switch (request.kind) {
        PaymentKind.bill => 'Paiement de facture',
        PaymentKind.airtime => 'Recharge',
        PaymentKind.merchant => 'Paiement Scan to Pay',
      },
      amount: amount,
      currency: request.currency,
      date: now,
      direction: TxDirection.debit,
      reference: 'EXM${now.millisecondsSinceEpoch % 10000000}',
      category: switch (request.kind) {
        PaymentKind.bill => TxCategory.bill,
        PaymentKind.airtime => TxCategory.airtime,
        PaymentKind.merchant => TxCategory.merchant,
      },
      counterpartyAccount: request.reference,
    );
    _transactions.insert(0, tx);
    notifyListeners();
    return tx;
  }

  @override
  Future<TransferQuote> getQuote({
    required Account from,
    required TransferDestination to,
    required double amount,
    required AmountSide side,
  }) async {
    await Future.delayed(latency ~/ 2);
    return quote(from: from, to: to, amount: amount, side: side);
  }

  /// Tarification simulée (marge de change + frais hors Exim).
  static TransferQuote quote({
    required Account from,
    required TransferDestination to,
    required double amount,
    required AmountSide side,
  }) {
    final src = from.currency;
    final dst = to.currency;
    final rate = src == dst ? 1.0 : toKmf[src]! / toKmf[dst]! * (1 - fxMargin);
    double round(double v, String ccy) =>
        zeroDecimalCurrencies.contains(ccy) ? v.roundToDouble() : (v * 100).roundToDouble() / 100;

    final send = side == AmountSide.send ? round(amount, src) : round(amount / rate, src);
    final receive = side == AmountSide.receive ? round(amount, dst) : round(send * rate, dst);
    final double fee;
    if (to.isInternal) {
      fee = 0;
    } else if (to.isInternationalWallet) {
      final kmf = (send * toKmf[src]! * intlWalletFeeRate).clamp(intlWalletFeeMinKmf, intlWalletFeeMaxKmf);
      fee = round(kmf / toKmf[src]!, src);
    } else if (to.isMobileMoney) {
      final kmf = (send * toKmf[src]! * walletFeeRate).clamp(walletFeeMinKmf, walletFeeMaxKmf);
      fee = round(kmf / toKmf[src]!, src);
    } else {
      fee = round(externalFeeKmf / toKmf[src]!, src);
    }
    return TransferQuote(
      sendAmount: send,
      sendCurrency: src,
      receiveAmount: receive,
      receiveCurrency: dst,
      rate: rate,
      fee: fee,
      instant: to.isInternal || to.isMobileMoney,
    );
  }

  @override
  Future<BankTransaction> sendTransfer({
    required Account from,
    required TransferDestination to,
    required TransferQuote quote,
    required TransferPurpose purpose,
    String? note,
  }) async {
    await Future.delayed(latency * 3);
    final i = _accounts.indexWhere((a) => a.number == from.number);
    if (i < 0) throw const TransferException(TransferError.accountNotFound);
    final source = _accounts[i];
    if (quote.sendAmount <= 0) throw const TransferException(TransferError.invalidAmount);
    if (quote.sendAmount * toKmf[source.currency]! > transferLimitKmf) {
      throw const TransferException(TransferError.limitExceeded);
    }
    if (quote.totalDebited > source.balance + 1e-9) throw const TransferException(TransferError.insufficientFunds);

    _accounts[i] = _withBalance(source, source.balance - quote.totalDebited);
    final now = DateTime.now();
    final reference = 'EXM${now.millisecondsSinceEpoch % 10000000}';
    final ownTransferLabel = '${source.label} → ${to.name}';
    final debit = BankTransaction(
      id: 'T$reference',
      accountNumber: source.number,
      label: to.isOwnAccount ? ownTransferLabel : to.name,
      subtitle: to.isOwnAccount
          ? 'Virement entre mes comptes'
          : to.isMobileMoney
              ? 'Envoi ${to.beneficiary!.walletProvider}${to.isInternationalWallet ? ' (Onafriq)' : ''}'
              : 'Virement envoyé',
      amount: quote.sendAmount,
      currency: source.currency,
      date: now,
      direction: TxDirection.debit,
      reference: reference,
      status: to.isInternal || to.isMobileMoney ? TxStatus.completed : TxStatus.pending,
      category: TxCategory.transfer,
      fee: quote.fee,
      counterpartyAccount: to.accountNumber,
    );
    _transactions.insert(0, debit);

    if (to.isOwnAccount) {
      final j = _accounts.indexWhere((a) => a.number == to.ownAccount!.number);
      _accounts[j] = _withBalance(_accounts[j], _accounts[j].balance + quote.receiveAmount);
      _transactions.insert(
        0,
        BankTransaction(
          id: 'C$reference',
          accountNumber: _accounts[j].number,
          label: ownTransferLabel,
          subtitle: 'Virement entre mes comptes',
          amount: quote.receiveAmount,
          currency: to.currency,
          date: now,
          direction: TxDirection.credit,
          reference: reference,
          counterpartyAccount: source.number,
        ),
      );
    }
    notifyListeners();
    return debit;
  }

  static Account _withBalance(Account a, double balance) => Account(
        number: a.number,
        label: a.label,
        currency: a.currency,
        balance: balance,
        type: a.type,
        iban: a.iban,
        bic: a.bic,
        branch: a.branch,
        holderName: a.holderName,
      );

  /// Comptes des bénéficiaires de démonstration, pour relier l'historique à leur fiche.
  static const _knownCounterparties = {
    'Nazira Mbotimora': '00100998877',
    'Ahmed BenNour': '00100887766',
    'Flangia Inasy': '00100776655',
  };

  /// ~60 opérations réparties sur les comptes et les 45 derniers jours.
  static List<BankTransaction> _generateTransactions() {
    final now = DateTime.now();
    final rng = Random(42);
    const templates = <(String, String, TxCategory, TxDirection, double)>[
      ('Nazira Mbotimora', 'Virement envoyé', TxCategory.transfer, TxDirection.debit, 25000),
      ('Salaire', 'Virement reçu', TxCategory.salary, TxDirection.credit, 350000),
      ('SONELEC', 'Paiement de facture', TxCategory.bill, TxDirection.debit, 18750),
      ('Comores Telecom', 'Recharge', TxCategory.airtime, TxDirection.debit, 5000),
      ('Ahmed BenNour', 'Virement reçu', TxCategory.transfer, TxDirection.credit, 60000),
      ('Supermarché Moroni', 'Paiement par carte', TxCategory.card, TxDirection.debit, 14200),
      ('Retrait GAB Volo-Volo', 'Retrait d\'espèces', TxCategory.cash, TxDirection.debit, 20000),
      ('Flangia Inasy', 'Virement envoyé', TxCategory.transfer, TxDirection.debit, 40000),
      ('Société des Eaux', 'Paiement de facture', TxCategory.bill, TxDirection.debit, 7300),
    ];
    final list = <BankTransaction>[];
    for (var i = 0; i < 60; i++) {
      // Frais de tenue de compte une fois par mois environ, opérations variées sinon.
      final (label, subtitle, category, direction, base) = i % 30 == 12
          ? ('Frais de tenue de compte', 'Frais bancaires', TxCategory.fee, TxDirection.debit, 1500.0)
          : templates[(i * 7 + rng.nextInt(3)) % templates.length];
      final account = i % 5 == 4 ? _seedAccounts[1] : _seedAccounts[0];
      final amount = (base * (0.6 + rng.nextDouble() * 0.8) / 50).round() * 50.0;
      final minutesAgo = (i * 18 * 60) + rng.nextInt(600) + 30;
      list.add(BankTransaction(
        id: 'T${(i + 1).toString().padLeft(4, '0')}',
        accountNumber: account.number,
        label: label,
        subtitle: subtitle,
        amount: amount,
        currency: account.currency,
        date: now.subtract(Duration(minutes: minutesAgo)),
        direction: direction,
        category: category,
        reference: 'EXM${(830000 + i * 137).toString()}',
        status: i == 0 ? TxStatus.pending : (i == 9 ? TxStatus.failed : TxStatus.completed),
        fee: category == TxCategory.transfer && direction == TxDirection.debit ? 250 : 0,
        counterpartyAccount: category == TxCategory.transfer ? (_knownCounterparties[label] ?? '0010099${8800 + i}') : null,
      ));
    }
    return list;
  }
}

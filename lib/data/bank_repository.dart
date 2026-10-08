import 'package:flutter/foundation.dart';

import 'models.dart';
import 'wallet_corridors.dart';

export 'wallet_corridors.dart';

/// Point d'entrée unique vers le back-end. Les écrans ne dépendent que de
/// cette interface : brancher les API réelles = fournir une autre implémentation.
abstract class BankRepository {
  /// Notifié quand les soldes ou l'historique changent (ex. après un envoi),
  /// pour que les écrans affichés se rechargent.
  Listenable get changes;

  Future<Customer> getCustomer();
  Future<List<Account>> getAccounts();

  /// Transactions les plus récentes d'abord, filtrées par [query] ;
  /// [offset]/[limit] servent à la pagination.
  Future<List<BankTransaction>> getTransactions({
    TransactionQuery query = const TransactionQuery(),
    int offset = 0,
    int limit = 20,
  });

  Future<List<Beneficiary>> getBeneficiaries();
  Future<Beneficiary> addBeneficiary(Beneficiary beneficiary);
  Future<Beneficiary> updateBeneficiary(Beneficiary beneficiary);
  Future<void> deleteBeneficiary(String id);

  /// Nom du titulaire d'un compte Exim, ou `null` s'il n'existe pas.
  Future<String?> lookupEximAccount(String accountNumber);

  /// Pays et opérateurs Mobile Money joignables (Comores en direct, étranger via Onafriq).
  Future<List<WalletCorridor>> getWalletCorridors();

  /// Nom du titulaire d'un portefeuille ([phone] au format international, ex. +2693312345), ou `null`.
  Future<String?> lookupWallet({required String countryCode, required String provider, required String phone});

  Future<List<DebitCard>> getCards();

  /// Gel, opposition, plafonds et options de paiement.
  Future<DebitCard> updateCard(DebitCard card);

  /// Numéro complet, CVV et code PIN : à n'appeler qu'après confirmation par PIN.
  Future<CardSecrets> getCardSecrets(String cardId);

  /// Commande d'une nouvelle carte ; renvoie la référence de la demande.
  Future<String> requestCard({required String product, required String accountNumber, required String branch});

  Future<List<Biller>> getBillers();

  /// Retrouve la facture (ou valide le numéro pour une recharge). Lève [TransferException].
  Future<PaymentRequest> lookupBill({required Biller biller, required String reference});

  /// Règle une facture, une recharge ou un commerçant. Lève [TransferException].
  Future<BankTransaction> pay({required PaymentRequest request, required Account from, required double amount});


  /// Devis d'envoi : [amount] est exprimé du côté [side].
  Future<TransferQuote> getQuote({
    required Account from,
    required TransferDestination to,
    required double amount,
    required AmountSide side,
  });

  /// Virements planifiés et ordres permanents du client (exécutés par la banque).
  Future<List<ScheduledTransfer>> getScheduledTransfers();

  /// Programme un virement ; renvoie l'échéancier enregistré (avec son identifiant).
  Future<ScheduledTransfer> createScheduledTransfer(ScheduledTransfer transfer);

  /// Suspend, reprend ou annule un échéancier.
  Future<ScheduledTransfer> setScheduledTransferStatus(String id, ScheduleStatus status);

  /// Exécute l'envoi et renvoie l'opération créée. Lève [TransferException].
  Future<BankTransaction> sendTransfer({
    required Account from,
    required TransferDestination to,
    required TransferQuote quote,
    required TransferPurpose purpose,
    String? note,
  });
}

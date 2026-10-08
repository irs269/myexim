import 'package:flutter/widgets.dart';

import '../app_scope.dart';
import '../utils/formatters.dart';

enum AppLanguage {
  fr('Français'),
  en('English');

  const AppLanguage(this.label);
  final String label;
}

/// Textes de l'app en FR/EN. Usage : `S.of(context).login`.
class S {
  const S._(this.lang);
  final AppLanguage lang;

  static S of(BuildContext context) => S._(AppScope.of(context).language.value);

  bool get french => lang == AppLanguage.fr;

  String _t(String fr, String en) => french ? fr : en;

  /// En-tête de groupe de transactions : « Aujourd'hui », « Hier » ou la date.
  String dayLabel(DateTime d) {
    final today = dayOf(DateTime.now());
    final day = dayOf(d);
    if (day == today) return this.today;
    if (day == today.subtract(const Duration(days: 1))) return yesterday;
    return formatDate(d, french: french);
  }

  /// Signature du logo.
  String get slogan => _t("L'innovation c'est la vie", 'Innovation is life');

  // Bienvenue
  String get welcome => _t('Bienvenue !', 'Welcome!');
  String get tagline => _t('La banque, à votre façon', 'Experience Banking, Your Way');
  String get welcomeBody => _t(
        'Gérez vos opérations, votre épargne et vos cartes de débit plus facilement que jamais, depuis votre smartphone.',
        'Managing your transactions, savings, and debit cards is now easier than ever – all from the convenience of your smartphone!',
      );
  String get openAccount => _t('Ouvrir un compte', 'Open an account');
  String get openAccountSub => _t('Nouveau client ? Commencez ici', 'Are you a New User? Click here to start');
  String get scanToPay => 'Scan To Pay';
  String get scanToPaySub => _t('Scannez pour payer factures et commerçants', 'Tap and scan to pay government bill and other payment');
  String get selfRegistration => _t('Auto-inscription', 'Self-Registration');
  String get selfRegistrationSub => _t('Déjà client ? Activez votre accès ici', 'Already have an account? Click here to Register');
  String get login => _t('Connexion', 'Login');
  String get loginSub => _t('Clients existants, continuez ici', 'Existing Users, click here to proceed');

  // Connexion
  String get hello => _t('Bonjour,', 'Hello,');
  String get switchAccount => _t('Changer de compte', 'Switch account');
  String get enterPassword => _t('Entrez votre mot de passe pour continuer.', 'Enter your password to continue.');
  String get loginTitle => _t('Connectez-vous', 'Log in');
  String get username => _t('Identifiant', 'Username');
  String get password => _t('Mot de passe', 'Password');
  String get forgotPassword => _t('Mot de passe oublié ?', 'Forgot password?');
  String get continueLabel => _t('Continuer', 'Continue');
  String get requiredField => _t('Champ obligatoire', 'Required field');

  // OTP
  String get otpTitle => _t('Entrez le code reçu par SMS', 'Enter the code we sent you');
  String otpBody(String phone) => _t('Nous avons envoyé un code à 6 chiffres au $phone.', 'We sent a 6-digit code to $phone.');
  String get resendCode => _t('Renvoyer le code', 'Resend code');
  String resendIn(int s) => _t('Renvoyer le code dans $s s', 'Resend code in ${s}s');
  String get codeResent => _t('Un nouveau code a été envoyé', 'A new code has been sent');

  // PIN
  String get createPinTitle => _t('Créez votre code PIN', 'Create your PIN');
  String get createPinBody => _t('Il vous servira à déverrouiller MyExim et à valider vos opérations.', 'You\'ll use it to unlock MyExim and confirm payments.');
  String get confirmPinTitle => _t('Confirmez votre code PIN', 'Confirm your PIN');
  String get pinMismatch => _t('Les codes ne correspondent pas, recommencez', 'PINs don\'t match, try again');
  String get enterPinTitle => _t('Entrez votre code PIN', 'Enter your PIN');
  String get wrongPin => _t('Code PIN incorrect', 'Incorrect PIN');
  String pinAttemptsLeft(int n) => _t('Code incorrect. $n essai(s) restant(s)', 'Incorrect PIN. $n attempt(s) left');
  String get notYou => _t('Ce n\'est pas vous ? Se déconnecter', 'Not you? Log out');
  String get biometricTitle => _t('Déverrouillage biométrique', 'Biometric unlock');
  String get biometricBody => _t('Utilisez votre empreinte ou votre visage pour ouvrir MyExim plus vite.', 'Use your fingerprint or face to open MyExim faster.');
  String get enable => _t('Activer', 'Enable');
  String get notNow => _t('Plus tard', 'Not now');
  String get biometricReason => _t('Déverrouillez MyExim', 'Unlock MyExim');

  // Auto-inscription
  String get selfRegTitle => _t('Activez votre accès', 'Activate your access');
  String get selfRegBody => _t(
        'Identifiez-vous avec votre numéro de compte ou votre numéro client, et votre date de naissance.',
        'Identify yourself with your account number or customer number, and your date of birth.',
      );
  String get customerNumber => _t('Numéro client', 'Customer number');
  String get birthDateHint => _t('JJ/MM/AAAA', 'DD/MM/YYYY');
  String get otpToRegisteredPhone => _t(
        'Le code de vérification sera envoyé au numéro de téléphone enregistré à la banque.',
        'The verification code will be sent to the phone number registered with the bank.',
      );
  String get accountNumber => _t('Numéro de compte', 'Account number');
  String get phoneNumber => _t('Numéro de téléphone', 'Phone number');
  String get choosePasswordTitle => _t('Choisissez vos identifiants', 'Choose your credentials');
  String get confirmPassword => _t('Confirmer le mot de passe', 'Confirm password');
  String get passwordRules => _t('8 caractères minimum, dont un chiffre', 'At least 8 characters, including a digit');
  String get passwordMismatch => _t('Les mots de passe ne correspondent pas', 'Passwords don\'t match');
  String get registrationDone => _t('Accès activé. Connectez-vous avec vos identifiants.', 'Access activated. Log in with your credentials.');

  // Tableau de bord
  String get totalBalance => _t('Solde total', 'Total balance');
  String get send => _t('Envoyer', 'Send');
  String get addMoney => _t('Ajouter de l\'argent', 'Add money');
  String get request => _t('Demander', 'Request');
  String get betweenMyAccounts => _t('Entre mes comptes', 'Between my accounts');
  String get more => _t('Plus', 'More');
  String cardsCount(int n) => _t('$n cartes', '$n cards');
  String get accountNumbers => _t('Numéros de compte', 'Account details');
  String get transactions => 'Transactions';
  String get seeAll => _t('Tout afficher', 'See all');
  String get noTransactions => _t('Aucune transaction', 'No transactions');
  String get today => _t('Aujourd\'hui', 'Today');
  String get yesterday => _t('Hier', 'Yesterday');
  String get searchTransactions => _t('Rechercher une transaction', 'Search transactions');
  String get filterAll => _t('Tout', 'All');
  String get filterIn => _t('Entrées', 'Money in');
  String get filterOut => _t('Sorties', 'Money out');
  String get pullToRefresh => _t('Mise à jour…', 'Refreshing…');

  // Comptes
  String get accountHolder => _t('Titulaire', 'Account holder');
  String get accountNumberLabel => _t('Numéro de compte', 'Account number');
  String get iban => 'IBAN';
  String get bic => 'BIC / SWIFT';
  String get branch => _t('Agence', 'Branch');
  String get bankName => _t('Banque', 'Bank');
  String get copied => _t('Copié', 'Copied');
  String get copyAll => _t('Tout copier', 'Copy all');
  String get accountNumbersBody => _t(
        'Communiquez ces informations pour recevoir de l\'argent sur ce compte.',
        'Share these details to receive money into this account.',
      );

  // Détail de transaction
  String get statusCompleted => _t('Effectuée', 'Completed');
  String get statusPending => _t('En cours', 'In progress');
  String get statusFailed => _t('Échouée', 'Failed');
  String get stepCreated => _t('Opération créée', 'Transaction created');
  String get stepDebited => _t('Compte débité', 'Account debited');
  String get stepProcessing => _t('Traitement par la banque', 'Processed by the bank');
  String get stepCompleted => _t('Fonds disponibles', 'Funds available');
  String get stepCredited => _t('Compte crédité', 'Account credited');
  String get stepFailed => _t('Opération rejetée, montant non débité', 'Rejected, amount not debited');
  String get details => _t('Détails', 'Details');
  String get date => _t('Date', 'Date');
  String get account => _t('Compte', 'Account');
  String get reference => _t('Référence', 'Reference');
  String get fees => _t('Frais', 'Fees');
  String get counterparty => _t('Compte du bénéficiaire', 'Recipient account');
  String get totalDebited => _t('Total débité', 'Total debited');
  String get copyReference => _t('Copier la référence', 'Copy reference');
  String get reportProblem => _t('Signaler un problème', 'Report a problem');

  // Envoi d'argent
  String get whoToSend => _t('À qui envoyez-vous de l\'argent ?', 'Who are you sending money to?');
  String get searchRecipient => _t('Nom, numéro de compte…', 'Name, account number…');
  String get newRecipient => _t('Nouveau bénéficiaire', 'New recipient');
  String get newRecipientSub => _t('Client Exim, autre banque ou MVola', 'Exim customer, another bank or MVola');
  String get myAccounts => _t('Mes comptes', 'My accounts');
  String get recents => _t('Récents', 'Recent');
  String get allRecipients => _t('Tous les bénéficiaires', 'All recipients');
  String get eximCustomer => _t('Client Exim', 'Exim customer');
  String get otherBank => _t('Autre banque', 'Other bank');
  String get mobileMoney => 'Mobile Money';
  String get operator => _t('Opérateur', 'Operator');
  String get walletNumber => _t('Numéro MVola', 'MVola number');
  String get checkingWallet => _t('Vérification du portefeuille…', 'Checking wallet…');
  String get walletNotFound => _t('Aucun portefeuille MVola actif pour ce numéro', 'No active MVola wallet for this number');
  String get sendToMvola => _t('Envoyer vers MVola', 'Send to MVola');
  String get sendToMvolaBody => _t(
        "Envoyez de l'argent instantanément sur un portefeuille MVola Comores.",
        'Send money instantly to an MVola Comores wallet.',
      );
  String walletFormat(int digits, {required bool international}) => international
      ? _t('Numéro national : $digits chiffres, sans indicatif', 'National number: $digits digits, no country code')
      : _t('7 chiffres commençant par 3 ou 4, sans indicatif', '7 digits starting with 3 or 4, no country code');
  String get walletNumberGeneric => _t('Numéro du portefeuille', 'Wallet number');
  String get intlMobileMoney => _t('Mobile Money international', 'International Mobile Money');
  String get intlMobileMoneyBody => _t(
        'Envoyez vers des portefeuilles mobiles en Afrique (M-Pesa, Orange Money, MTN MoMo…) via Onafriq.',
        'Send to mobile wallets across Africa (M-Pesa, Orange Money, MTN MoMo…) via Onafriq.',
      );
  String viaNetwork(String network) => _t('Envoi international via $network', 'International transfer via $network');
  String get arrivalMinutes => _t('En quelques minutes', 'Within minutes');
  String get network => _t('Réseau', 'Network');
  String get recipientName => _t('Nom complet du bénéficiaire', 'Recipient full name');
  String get ibanOrAccount => _t('IBAN ou numéro de compte', 'IBAN or account number');
  String get checkingAccount => _t('Vérification du compte…', 'Checking account…');
  String get accountNotFound => _t('Aucun compte Exim avec ce numéro', 'No Exim account with this number');
  String get saveRecipient => _t('Enregistrer dans mes bénéficiaires', 'Save to my recipients');
  String get howMuch => _t('Quel montant envoyer ?', 'How much would you like to send?');
  String get howMuchConvert => _t('Quel montant transférer entre vos comptes ?', 'How much do you want to move?');
  String get youSend => _t('Vous envoyez', 'You send');
  String get theyReceive => _t('Le bénéficiaire reçoit', 'Recipient gets');
  String get youReceive => _t('Vous recevez', 'You get');
  String get from => _t('Depuis', 'From');
  String get to => _t('Vers', 'To');
  String balanceAvailable(String amount) => _t('Solde disponible : $amount', 'Available balance: $amount');
  String get ourFee => _t('Nos frais', 'Our fee');
  String get amountConverted => _t('Montant converti', 'Amount we\'ll convert');
  String get rateApplied => _t('Taux appliqué', 'Rate applied');
  String get noFee => _t('Gratuit', 'Free');
  String get arrival => _t('Arrivée', 'Should arrive');
  String get arrivalInstant => _t('En quelques secondes', 'In seconds');
  String get arrivalNextDay => _t('Sous 1 jour ouvré', 'Within 1 business day');
  String get insufficientFunds => _t('Solde insuffisant', 'Insufficient balance');
  String get limitExceeded => _t('Montant supérieur au plafond par opération', 'Amount exceeds the per-transaction limit');
  String get enterAmount => _t('Saisissez un montant', 'Enter an amount');
  String get review => _t('Vérifiez votre envoi', 'Review your transfer');
  String get reviewConvert => _t('Vérifiez votre virement', 'Review your transfer');
  String get transferDetails => _t('Détails du virement', 'Transfer details');
  String get recipient => _t('Bénéficiaire', 'Recipient');
  String get purpose => _t('Motif', 'Purpose');
  String get choosePurpose => _t('Choisissez un motif', 'Choose a purpose');
  String get noteOptional => _t('Message pour le bénéficiaire (facultatif)', 'Note for the recipient (optional)');
  String get edit => _t('Modifier', 'Edit');
  String get confirmAndSend => _t('Confirmer et envoyer', 'Confirm and send');
  String get confirmConvert => _t('Confirmer le virement', 'Confirm transfer');
  String get confirmWithPin => _t('Confirmez avec votre code PIN', 'Confirm with your PIN');
  String get useBiometrics => _t('Utiliser l\'empreinte', 'Use biometrics');
  String get biometricConfirmReason => _t('Confirmez votre virement', 'Confirm your transfer');
  String get sending => _t('Envoi en cours…', 'Sending…');
  String get transferSent => _t('Votre argent est envoyé', 'Your money\'s on its way');
  String get transferDone => _t('C\'est fait !', 'All done!');
  String transferSentBody(String amount, String name) =>
      _t('$amount ont été envoyés à $name.', '$amount has been sent to $name.');
  String transferPendingBody(String amount, String name) => _t(
        '$amount sont en route vers $name. Vous serez notifié à l\'arrivée.',
        '$amount is on its way to $name. We\'ll let you know when it arrives.',
      );
  String ownTransferBody(String amount, String account) =>
      _t('$amount ont été virés sur votre $account.', '$amount has been moved to your $account.');
  String get seeDetails => _t('Voir le détail', 'See details');
  String get done => _t('Terminé', 'Done');
  String get sendAgain => _t('Faire un autre envoi', 'Send again');
  String get chooseAccount => _t('Choisissez un compte', 'Choose an account');

  String purposeLabel(int index) => const [
        ('Famille et amis', 'Family and friends'),
        ('Factures', 'Bills'),
        ('Loyer', 'Rent'),
        ('Salaire', 'Salary'),
        ('Études', 'Education'),
        ('Santé', 'Health'),
        ('Commerce', 'Business'),
        ('Épargne', 'Savings'),
        ('Autre', 'Other'),
      ].map((p) => french ? p.$1 : p.$2).elementAt(index);

  // Navigation
  String get tabHome => _t('Accueil', 'Home');
  String get tabCards => _t('Cartes', 'Cards');
  String get tabPayments => _t('Paiements', 'Payments');

  // Bénéficiaires
  String get beneficiaries => _t('Bénéficiaires', 'Recipients');
  String get invite => _t('Inviter', 'Invite');
  String get add => _t('Ajouter', 'Add');
  String get searchBeneficiaries => _t('Rechercher un bénéficiaire', 'Search recipients');
  String get noBeneficiaries => _t('Aucun bénéficiaire pour l\'instant', 'No recipients yet');
  String get addRecipient => _t('Ajouter un bénéficiaire', 'Add a recipient');
  String get recipientAdded => _t('Bénéficiaire ajouté', 'Recipient added');
  String get currency => _t('Devise', 'Currency');
  String get rename => _t('Renommer', 'Rename');
  String get delete => _t('Supprimer', 'Delete');
  String get cancel => _t('Annuler', 'Cancel');
  String get save => _t('Enregistrer', 'Save');
  String deleteRecipientTitle(String name) => _t('Supprimer $name ?', 'Delete $name?');
  String get deleteRecipientBody => _t(
        'Le bénéficiaire sera retiré de votre liste. Vos opérations passées restent dans l\'historique.',
        'The recipient will be removed from your list. Past transactions stay in your history.',
      );
  String get recipientDeleted => _t('Bénéficiaire supprimé', 'Recipient deleted');
  String get historyWith => _t('Vos échanges', 'Your transactions together');
  String totalSent(String amount) => _t('Total envoyé : $amount', 'Total sent: $amount');
  String inviteMessage(String name) => _t(
        '$name vous invite à rejoindre MyExim, l\'application mobile d\'Exim Bank : envoyez et recevez de l\'argent gratuitement entre clients Exim.',
        '$name invites you to MyExim, Exim Bank\'s mobile app: send and receive money for free between Exim customers.',
      );

  // Filtres de l'historique
  String get filterDirection => _t('Sens', 'Direction');
  String get filterAccounts => _t('Comptes', 'Accounts');
  String get filterPeriod => _t('Période', 'Period');
  String get filterType => _t('Type', 'Type');
  String get clearFilters => _t('Effacer', 'Clear');
  String get apply => _t('Appliquer', 'Apply');
  String get periodThisMonth => _t('Ce mois-ci', 'This month');
  String get periodLastMonth => _t('Le mois dernier', 'Last month');
  String get period3Months => _t('3 derniers mois', 'Last 3 months');
  String get periodCustom => _t('Choisir des dates…', 'Choose dates…');
  String get anyPeriod => _t('Toutes les dates', 'Any time');
  String resultsCount(int n) => _t('$n résultat${n > 1 ? 's' : ''}', '$n result${n > 1 ? 's' : ''}');
  String categoryLabel(int index) => const [
        ('Virements', 'Transfers'),
        ('Factures', 'Bills'),
        ('Recharges', 'Airtime'),
        ('Carte', 'Card'),
        ('Salaire', 'Salary'),
        ('Frais', 'Fees'),
        ('Espèces', 'Cash'),
        ('Commerçants', 'Merchants'),
      ].map((p) => french ? p.$1 : p.$2).elementAt(index);

  // Reçu
  String get shareReceipt => _t('Partager le reçu', 'Share receipt');
  String get sendAgainShort => _t('Renvoyer', 'Send again');
  String get receiptTitle => _t('Reçu de transaction — Exim Bank', 'Transaction receipt — Exim Bank');
  String get amount => _t('Montant', 'Amount');
  String get status => _t('Statut', 'Status');

  // Paiements
  String get payments => _t('Paiements', 'Payments');
  String get scanToPayBody => _t("Scannez un QR code pour payer un commerçant ou une facture de l'État.",
      'Scan a QR code to pay a merchant or a government bill.');
  String get billPayment => _t('Paiement de factures', 'Pay bills');
  String get billPaymentBody =>
      _t('Électricité, eau, internet, impôts et douanes.', 'Electricity, water, internet, taxes and customs.');
  String get airtime => _t('Recharge téléphonique', 'Mobile top-up');
  String get airtimeBody => _t('Rechargez un numéro Comores Telecom ou Yas.', 'Top up a Comores Telecom or Yas number.');
  String get myQr => _t('Mon QR code', 'My QR code');
  String get myQrBody =>
      _t('Faites-vous payer : montrez ce code à un client Exim.', 'Get paid: show this code to an Exim customer.');
  String get scheduledTransfers => _t('Virements planifiés', 'Scheduled transfers');
  String get scheduledTransfersBody =>
      _t('Configurez un virement à envoyer à une date ultérieure.', 'Set up a transfer for a later date.');
  String get standingOrders => _t('Ordres permanents', 'Standing orders');
  String get standingOrdersBody =>
      _t('Configurez et gérez vos paiements récurrents.', 'Set up and manage recurring payments.');
  String get chooseBiller => _t('Qui voulez-vous payer ?', 'Who do you want to pay?');
  String billerCategory(int index) => const [
        ('Électricité', 'Electricity'),
        ('Eau', 'Water'),
        ('Internet et téléphone', 'Internet and phone'),
        ('Recharges', 'Top-ups'),
        ('Télévision', 'TV'),
        ('Administrations', 'Government'),
      ].map((p) => french ? p.$1 : p.$2).elementAt(index);
  String referenceLabel(String fr) => french
      ? fr
      : const {
            'Numéro de compteur': 'Meter number',
            'Numéro de contrat': 'Contract number',
            'Numéro de ligne': 'Line number',
            'Numéro de téléphone': 'Phone number',
            "Numéro d'avis": 'Notice number',
            'Numéro de déclaration': 'Declaration number',
          }[fr] ??
          fr;
  String get findBill => _t('Rechercher la facture', 'Find bill');
  String get continueWithNumber => _t('Continuer', 'Continue');
  String get billNotFound => _t('Aucune facture trouvée pour cette référence', 'No bill found for this reference');
  String get invalidPhone => _t('Numéro de téléphone invalide', 'Invalid phone number');
  String get payTitle => _t('Vérifiez votre paiement', 'Review your payment');
  String get holder => _t('Titulaire', 'Holder');
  String get dueDate => _t('Échéance', 'Due date');
  String get object => _t('Objet', 'Description');
  String get amountToPay => _t('Montant à payer', 'Amount to pay');
  String get chooseAmount => _t('Choisissez un montant', 'Choose an amount');
  String get otherAmount => _t('Autre montant', 'Other amount');
  String get payWith => _t('Payer avec', 'Pay with');
  String get confirmPayment => _t('Confirmer le paiement', 'Confirm payment');
  String get paymentDone => _t('Paiement effectué', 'Payment complete');
  String paymentBody(String amount, String payee) => _t('$amount payés à $payee.', '$amount paid to $payee.');
  String get onlyKmf =>
      _t('Ce paiement doit être réglé depuis un compte en KMF', 'This payment must be made from a KMF account');

  // Scan to Pay
  String get scanTitle => _t('Scannez le QR code', 'Scan the QR code');
  String get scanHint => _t('Placez le QR code dans le cadre', 'Place the QR code inside the frame');
  String get enterCode => _t('Saisir le code', 'Enter code');
  String get pasteCode => _t('Code du QR (EXIMPAY…)', 'QR code text (EXIMPAY…)');
  String get invalidQr => _t("Ce QR code n'est pas un code de paiement Exim", 'This is not an Exim payment QR code');
  String get cameraUnavailable => _t("Caméra indisponible. Autorisez l'accès à la caméra ou saisissez le code.",
      'Camera unavailable. Allow camera access or enter the code.');
  String get torch => _t('Lampe', 'Torch');
  String get qrAmountOptional => _t('Montant demandé (facultatif)', 'Requested amount (optional)');
  String get qrShare => _t('Partager mon code', 'Share my code');
  String get loginToPay => _t('Connectez-vous pour payer avec Scan To Pay.', 'Log in to pay with Scan To Pay.');

  // Cartes
  String get cards => _t('Cartes', 'Cards');
  String get requestCard => _t('Demander une carte', 'Get a card');
  String get showPin => _t('Afficher le\ncode PIN', 'Show\nPIN');
  String get cardNumbers => _t('Numéros de\ncarte', 'Card\ndetails');
  String get freezeCard => _t('Geler la\ncarte', 'Freeze\ncard');
  String get unfreezeCard => _t('Dégeler la\ncarte', 'Unfreeze\ncard');
  String get cardFrozen => _t('Carte gelée : paiements et retraits bloqués temporairement.',
      'Card frozen: payments and withdrawals are temporarily blocked.');
  String get cardUnfrozen => _t('Carte réactivée', 'Card unfrozen');
  String get cardBlocked => _t('Carte en opposition', 'Card blocked');
  String get cardSettings => _t('Paramètres de la carte', 'Card settings');
  String get cardSecurity => _t('Sécurité', 'Security');
  String get onlinePayments => _t('Paiements en ligne', 'Online payments');
  String get contactless => _t('Paiement sans contact', 'Contactless payments');
  String get international => _t("Utilisation à l'étranger", 'Use abroad');
  String get dailyLimits => _t('Plafonds quotidiens', 'Daily limits');
  String get atmLimit => _t('Retraits au distributeur', 'ATM withdrawals');
  String get posLimit => _t('Paiements en magasin', 'In-store payments');
  String get onlineLimit => _t('Achats en ligne', 'Online purchases');
  String get settingsSaved => _t('Paramètres enregistrés', 'Settings saved');
  String get blockCard => _t('Faire opposition', 'Report lost or stolen');
  String get blockCardBody => _t(
        "Carte perdue ou volée ? L'opposition est définitive : la carte ne pourra plus être utilisée et une nouvelle carte devra être commandée.",
        'Lost or stolen card? Blocking is permanent: the card can no longer be used and a new one must be ordered.',
      );
  String get confirmBlock => _t("Confirmer l'opposition", 'Block card');
  String get yourPin => _t('Votre code PIN', 'Your PIN');
  String hiddenIn(int s) => _t('Masqué dans $s s', 'Hidden in ${s}s');
  String get cardNumber => _t('Numéro de carte', 'Card number');
  String get expiry => _t('Expiration', 'Expiry');
  String get cvv => 'CVV';
  String get linkedAccount => _t('Compte associé', 'Linked account');
  String get chooseCardType => _t('Choisissez votre carte', 'Choose your card');
  String get pickupBranch => _t('Agence de retrait', 'Pickup branch');
  String get submitRequest => _t('Envoyer la demande', 'Submit request');
  String get cardRequested => _t('Demande envoyée', 'Request sent');
  String cardRequestedBody(String ref) => _t(
        'Votre carte sera disponible en agence sous 7 jours ouvrés. Référence : $ref',
        'Your card will be ready at the branch within 7 business days. Reference: $ref',
      );
  String get visaClassicBody =>
      _t('Paiements et retraits aux Comores et en ligne.', 'Payments and withdrawals in Comoros and online.');
  String get visaGoldBody => _t('Plafonds élevés et utilisation dans le monde entier.', 'Higher limits and worldwide use.');

  // Ouverture de compte
  String get aboutYou => _t('À propos de vous', 'About you');
  String get getToKnow => _t('Faisons connaissance', "Let's get to know each other");
  String get nin => _t("Numéro national d'identité (NIN)", 'National ID number (NIN)');
  String get mobileNumber => _t('Numéro de mobile', 'Mobile number');
  String get email => _t('Adresse e-mail', 'Email address');
  String get emailNote => _t(
        'Utilisez une adresse e-mail valide : elle servira pour la banque en ligne et vos paiements.',
        'Please use a valid email: it will be used for online banking and payments.',
      );
  String get invalidEmail => _t('Adresse e-mail invalide', 'Invalid email address');
  String get invalidNin => _t('Numéro d\'identité invalide', 'Invalid ID number');
  String get receiveCode => _t('Recevoir le code de vérification', 'Submit to receive verification code');
  String get verifyIdentity => _t('Vérifiez votre identité', 'Verify your identity');
  String get fingerprintIntro => _t(
        'Scannez votre empreinte pour créer votre compte et profiter des virements, paiements et de bien d\'autres services.',
        'Scan your fingerprint to create your account and enjoy transfers, payments and much more.',
      );
  String get letsScan => _t('Scanner mon empreinte', "Let's scan it!");
  String get handSelection => _t('Choix de la main', 'Hand selection');
  String get whichHand => _t('Quelle main souhaitez-vous scanner ?', 'Which hand fingers would you like to scan?');
  String get leftHand => _t('Gauche', 'Left');
  String get rightHand => _t('Droite', 'Right');
  String get scanTip1 => _t('Tendez la main, doigts serrés', 'Extend and keep fingers together');
  String get scanTip2 => _t('Gardez les doigts parallèles à la caméra', 'Keep fingers parallel to camera');
  String get scanTip3 => _t('Ne bougez plus pendant la détection', 'Keep still while the app finds your fingers');
  String get scanTip4 => _t('Attendez la capture (le flash s\'allume)', 'Wait for capture (flash will go off)');
  String get dontShowAgain => _t('Ne plus afficher', "Don't show me again");
  String get capture => _t('Prendre la photo', 'Capture');
  String get verifyingIdentity => _t('Vérification de votre identité…', 'Verifying your identity…');
  String get successful => _t('Vérification réussie', 'Successful');
  String get identityValidated => _t('Merci, votre identité a bien été vérifiée.', 'Thank you for letting us validate your ID.');
  String get proceed => _t('Continuer', 'Proceed');
  String get confirmIdDetails => _t('Confirmez vos données', 'Confirm ID details');
  String get confirmAllCorrect => _t('Vérifiez que toutes les informations ci-dessous sont exactes', 'Please confirm that all the details below are correct');
  String get photo => _t('Photo', 'Photo');
  String get idNumber => _t('Numéro d\'identité', 'ID number');
  String get fullName => _t('Nom complet', 'Full name');
  String get birthDate => _t('Date de naissance', 'Date of birth');
  String get nationality => _t('Nationalité', 'Nationality');
  String get gender => _t('Sexe', 'Gender');
  String get male => _t('MASCULIN', 'MALE');
  String get female => _t('FÉMININ', 'FEMALE');
  String get residenceIsland => _t('Île de résidence', 'Resident island');
  String get residenceCity => _t('Ville de résidence', 'Resident city');
  String get residenceDistrict => _t('Quartier', 'District');
  String get residenceStreet => _t('Rue', 'Street');
  String get postalAddress => _t('Adresse postale', 'Postal address');
  String get birthPlace => _t('Lieu de naissance', 'Place of birth');
  String get birthCountry => _t('Pays de naissance', 'Birth country');
  String get signature => _t('Signature', 'Signature');
  String get confirmContinue => _t('Confirmer et continuer', 'Confirm & continue');
  String get scanAgain => _t('Recommencer le scan', 'Scan again');
  String get confirmInfo => _t('Confirmez vos informations', 'Confirm your information');
  String get nextAccountOpening => _t('Étape suivante : ouverture du compte', 'Next: Account opening');
  String get nextYourInfo => _t('Étape suivante : vos informations', 'Next: Your information');
  String get fillDetails => _t('Complétez les informations ci-dessous', 'Please fill the below details');
  String get annualIncome => _t('Revenu annuel (en KMF)', 'Annual income (in KMF)');
  String get employmentType => _t('Situation professionnelle', 'Employment type');
  String employmentLabel(int i) => const [
        ('Salarié', 'Employed'),
        ('Indépendant / commerçant', 'Self-employed'),
        ('Fonctionnaire', 'Civil servant'),
        ('Étudiant', 'Student'),
        ('Retraité', 'Retired'),
        ('Sans emploi', 'Not employed'),
      ].map((p) => french ? p.$1 : p.$2).elementAt(i);
  String get currentAddress => _t('Adresse actuelle', 'Current address');
  String get building => _t('Bâtiment / appartement / maison', 'Flat no / apartment / building');
  String get streetName => _t('Rue', 'Street name');
  String get city => _t('Ville', 'City');
  String get country => _t('Pays', 'Country');
  String get editInformation => _t('Modifier les informations', 'Edit information');
  String get openAccountTitle => _t('Ouvrir un compte', 'Open account');
  String get openAccountIntro => _t(
        'Obtenez votre compte rapidement : remplissez le formulaire ci-dessous. Dépôt minimum pour un compte épargne : 5 000 KMF.',
        'Get an account instantly: fill the form below. Minimum deposit for a savings account is KMF 5,000.',
      );
  String get accountType => _t('Type de compte', 'Account type');
  String get requestForCard => _t('Demande de carte', 'Request for card');
  String get select => _t('Choisir', 'Select');
  String get yes => _t('Oui', 'Yes');
  String get no => _t('Non', 'No');
  String accountTypeLabel(int i) => const [
        ('Compte rapide', 'Quick account'),
        ('Compte courant', 'Current account'),
        ('Compte épargne', 'Savings account'),
      ].map((p) => french ? p.$1 : p.$2).elementAt(i);
  String get acceptTermsPrefix => _t("J'ai lu les ", 'Yes I read the ');
  String get terms => _t('conditions générales', 'Terms & Conditions');
  String get acceptTermsSuffix => _t(' et je les accepte', ' and I accept them');
  String get next => _t('Suivant', 'Next');
  String get applicationSent => _t('Demande envoyée', 'Application sent');
  String applicationSentBody(String ref) => _t(
        'Nous examinons votre demande. Vous recevrez un SMS dès que votre compte sera ouvert. Référence : $ref',
        "We're reviewing your application. You'll get a text as soon as your account is open. Reference: $ref",
      );
  String get trackApplication => _t('Suivre ma demande d\'ouverture', 'Track my application');
  String get trackApplicationSub => _t('Demande en cours de traitement', 'Application in progress');
  String get applicationStatus => _t('Ma demande', 'My application');
  String applicationStatusLabel(int i) => const [
        ('Reçue', 'Received'),
        ('En cours d\'examen', 'Under review'),
        ('Compte ouvert', 'Account open'),
        ('Refusée', 'Declined'),
      ].map((p) => french ? p.$1 : p.$2).elementAt(i);
  String accountOpened(String number) => _t(
        'Félicitations ! Votre compte n° $number est ouvert. Activez maintenant votre accès MyExim.',
        'Congratulations! Your account $number is open. Activate your MyExim access now.',
      );
  String get activateAccess => _t('Activer mon accès', 'Activate my access');
  String get refresh => _t('Actualiser', 'Refresh');
  String get termsTitle => _t('Conditions générales', 'Terms & Conditions');
  String get termsBody => _t(
        'Les conditions générales de banque d\'Exim Bank Comores s\'appliquent à l\'ouverture et au fonctionnement de votre compte. Le texte officiel sera fourni par la banque.',
        'Exim Bank Comores general banking terms apply to the opening and operation of your account. The official text will be provided by the bank.',
      );

  // Virements planifiés et ordres permanents
  String get scheduledPayments => _t('Paiements programmés', 'Scheduled payments');
  String get tabScheduled => _t('Planifiés', 'Scheduled');
  String get tabStanding => _t('Permanents', 'Recurring');
  String get newScheduled => _t('Programmer un virement', 'Schedule a transfer');
  String get newStanding => _t('Créer un ordre permanent', 'Set up a standing order');
  String get noScheduled => _t('Aucun virement planifié', 'No scheduled transfers');
  String get noStanding => _t('Aucun ordre permanent', 'No standing orders');
  String get scheduleTitle => _t('Programmer un virement', 'Schedule a transfer');
  String get standingTitle => _t('Ordre permanent', 'Standing order');
  String get chooseRecipient => _t('Choisir un bénéficiaire', 'Choose a recipient');
  String get frequency => _t('Fréquence', 'Frequency');
  String frequencyLabel(int i) => const [
        ('Une seule fois', 'Once'),
        ('Chaque semaine', 'Every week'),
        ('Chaque mois', 'Every month'),
        ('Chaque trimestre', 'Every quarter'),
      ].map((p) => french ? p.$1 : p.$2).elementAt(i);
  String get executionDate => _t("Date d'exécution", 'Transfer date');
  String get firstExecution => _t('Première exécution', 'First transfer');
  String get endLabel => _t('Fin', 'End');
  String get noEnd => _t('Sans fin', 'No end date');
  String get untilDate => _t("Jusqu'au…", 'Until…');
  String get nextExecutions => _t('Prochaines exécutions', 'Upcoming transfers');
  String get nextExecution => _t('Prochaine exécution', 'Next transfer');
  String get scheduleNoteFees => _t(
        'Le compte doit être approvisionné la veille de chaque exécution. Les frais éventuels sont prélevés à chaque envoi.',
        'The account must be funded the day before each transfer. Any fees are charged on each transfer.',
      );
  String get confirmSchedule => _t('Confirmer la programmation', 'Confirm schedule');
  String get scheduleCreated => _t('Virement programmé', 'Transfer scheduled');
  String scheduleCreatedBody(String amount, String name, String date) =>
      _t('$amount seront envoyés à $name le $date.', '$amount will be sent to $name on $date.');
  String get standingCreated => _t('Ordre permanent créé', 'Standing order set up');
  String standingCreatedBody(String amount, String name, String freq) =>
      _t('$amount seront envoyés à $name, ${freq.toLowerCase()}.', '$amount will be sent to $name, ${freq.toLowerCase()}.');
  String get statusActive => _t('Actif', 'Active');
  String get statusPaused => _t('Suspendu', 'Paused');
  String get statusEnded => _t('Terminé', 'Ended');
  String get pause => _t('Suspendre', 'Pause');
  String get resume => _t('Reprendre', 'Resume');
  String get cancelSchedule => _t('Annuler la programmation', 'Cancel schedule');
  String get cancelScheduleBody => _t(
        "Les envois futurs n'auront pas lieu. Les virements déjà exécutés ne sont pas concernés.",
        'Future transfers will not take place. Transfers already made are not affected.',
      );
  String get scheduleCancelled => _t('Programmation annulée', 'Schedule cancelled');
  String get noteLabel => _t('Message', 'Note');
  String get keep => _t('Conserver', 'Keep');
  String get dateMustBeFuture => _t("Choisissez une date à partir de demain", 'Choose a date from tomorrow');
  String onDate(String date) => _t('le $date', 'on $date');

  // Divers
  String get comingSoon => _t('Bientôt disponible', 'Coming soon');
  String get comingSoonBody => _t('Cette fonctionnalité arrive dans une prochaine version.', 'This feature is coming in a future release.');
  String get logout => _t('Se déconnecter', 'Log out');
  String get language => _t('Langue', 'Language');
  String get retry => _t('Réessayer', 'Retry');
  String get genericError => _t('Une erreur est survenue. Réessayez.', 'Something went wrong. Please try again.');
}

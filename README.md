# MyExim

Application mobile Flutter (Android / iOS) d'Exim Bank Comores, inspirée de l'ergonomie de Wise et habillée à la charte Exim.

## Fonctionnalités

- Accueil, connexion (identifiant + mot de passe, OTP, code PIN, biométrie), client mémorisé sur l'appareil
- Auto-inscription (numéro de compte ou numéro client + date de naissance)
- Ouverture de compte en ligne (NIN, OTP, empreinte, informations, suivi de la demande)
- Tableau de bord, comptes (KMF uniquement), historique filtrable, détail et reçu d'opération
- Envois : clients Exim, autres banques, MVola, Mobile Money international via Onafriq, entre mes comptes
- Virements planifiés et ordres permanents
- Bénéficiaires, Scan to Pay (QR), Mon QR code, factures et recharges
- Cartes : PIN et numéros après confirmation, gel, plafonds, opposition, commande
- Français / anglais

## Données

Les API (« olivie fabrique ») ne sont pas encore branchées : l'app tourne sur des données simulées.
Toute la communication passe par deux interfaces, à implémenter avec les vrais appels :

- `lib/data/bank_repository.dart` (comptes, opérations, envois, paiements, cartes…) — simulation : `mock_bank_repository.dart`
- `lib/data/auth_repository.dart` (connexion, OTP, auto-inscription, ouverture de compte) — simulation : `mock_auth_repository.dart`

Brancher les API = fournir ces implémentations dans `lib/main.dart`.

### Valeurs de test (simulation)

- Code SMS : `123456`
- Auto-inscription : compte `00100234567` ou client `100234` + 14/05/1990
- MVola : tout numéro à 7 chiffres commençant par 3 ou 4 (sauf …0000)
- QR de démonstration : `tools/qr_demo.html`

## Commandes

```bash
flutter pub get
flutter test
flutter run
flutter build apk --release
```

La version `release` est signée avec la clé de debug : à remplacer par la clé officielle d'Exim avant toute publication.

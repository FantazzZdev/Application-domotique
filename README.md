# Jarvis — domotique Delta Dore

Un assistant façon Iron Man pour piloter **plusieurs comptes Delta Dore / Tydom en même temps** :
vos volets (votre compte) et le portail de la famille (leur compte), sans jamais
vous déconnecter. À la voix (« Jarvis, ferme les volets »), par curseurs holographiques,
ou par des **boutons sur l'écran d'accueil** du téléphone.

![Aperçu](docs/apercu.png)

## Fonctionnalités

- **Assistant vocal Jarvis** : touchez le réacteur (ou dites « Jarvis » si le mot d'activation
  est configuré) puis parlez : « ferme les volets », « ouvre le portail chez les beaux-parents »,
  « mets le volet du salon à 30 % », « stop les volets partout », « fais-moi un rapport »…
  Jarvis répond à voix haute et agit. S'il y a un doute (« quelle maison ? »), il demande.
- **Interface HUD** futuriste : réacteur ARK animé qui réagit à la voix, curseurs verticaux
  pour régler chaque volet (et « Tous »), « maintenir pour activer » pour portail et garage.

- **Multi-comptes** : ajoutez autant de comptes Tydom que nécessaire (« Maison »,
  « Beaux-parents »…). Chacun a sa couleur ; tous restent connectés.
- **Détection automatique** des box et des équipements (volets, portail, garage, lumières).
- **Raccourcis en un tap** : « Fermer volets » (tous les volets d'un compte d'un coup),
  « Ouvrir portail »… Créés automatiquement à l'ajout d'un compte, modifiables (appui long).
- **Widgets Android et iPhone** :
  - *Bouton DeltaHome* : 1 bouton = 1 action, au choix ;
  - *Raccourcis DeltaHome* : vos 4 premiers raccourcis ;
  - l'action s'exécute **sans ouvrir l'app**, le bouton affiche ⏳ puis ✓ ou ⚠.
- **Raccourcis de l'icône** : appui long sur l'icône de l'app → 4 premiers raccourcis.
- Interface Material 3, thème clair / sombre automatique.
- Identifiants **chiffrés** sur le téléphone (Keystore Android / Trousseau iOS).
  Ils ne sont envoyés qu'aux serveurs Delta Dore.

## Installer sur Android

**Le plus simple :** à chaque push, GitHub compile l'APK.
Onglet **Actions** du dépôt → dernier *APK Android* réussi → *Artifacts* →
`DeltaHome-apk` → décompressez et ouvrez `app-release.apk` sur le téléphone
(autorisez l'installation depuis cette source).

Ou en local : `flutter build apk --release` (Flutter 3.50+, SDK Android).

Ajouter le widget : appui long sur l'écran d'accueil → *Widgets* → *Jarvis*
(widgets « Jarvis » pour parler, « Bouton Jarvis » et « Protocoles Jarvis »).

### Mot d'activation « Jarvis » (facultatif)

Pour lancer l'écoute en disant simplement « Jarvis » (app ouverte), créez un compte gratuit sur
[console.picovoice.ai](https://console.picovoice.ai/), copiez votre *AccessKey* et collez-la dans
*Menu → Réglages de Jarvis*. La détection se fait sur le téléphone, rien n'est envoyé en ligne.
Sans clé : touchez le réacteur, utilisez le widget « Jarvis » ou l'appui long sur l'icône de l'app.
Quand l'app est fermée, Android et iOS ne permettent pas d'écouter le micro en continu sans
notification permanente et forte consommation de batterie : le widget « Jarvis » est la porte d'entrée.

## Installer sur iPhone

Voir [docs/IPHONE.md](docs/IPHONE.md) (Mac + Xcode nécessaires, iOS 17+ pour les widgets).

## Utilisation

1. Ouvrez l'app → **Ajouter un compte** → nom affiché, e-mail et mot de passe
   **de l'application Tydom** de ce compte, et **adresse MAC de la box**
   (étiquette sous la box Tydom, 12 caractères, souvent `001A25…`).
2. Recommencez pour le second compte (ex. celui des beaux-parents).
3. Les équipements apparaissent par compte ; les raccourcis sont proposés automatiquement.
4. Placez les widgets sur l'écran d'accueil.

L'adresse MAC est obligatoire : le service Delta Dore ne donne le mot de passe
d'une box que si on lui fournit son adresse MAC. Plusieurs box sur un même compte :
séparez les adresses par une virgule.

## Fonctionnement technique

| Fichier | Rôle |
| --- | --- |
| `lib/tydom/cloud.dart` | Connexion au compte Delta Dore, récupération des box (MAC + mot de passe box) |
| `lib/tydom/client.dart` | WebSocket vers `mediation.tydom.com` (authentification Digest), requêtes HTTP encapsulées |
| `lib/tydom/http_message.dart` | Encodage / décodage des messages Tydom (préfixe `0x02`, chunked) |
| `lib/tydom/controller.dart` | Une connexion par box, découverte des équipements, commandes |
| `lib/services/widget_bridge.dart` | Données des widgets + exécution des actions en arrière-plan |
| `android/.../*WidgetProvider.kt` | Widgets Android |
| `ios/DeltaHomeWidget/` | Widgets iOS (WidgetKit) |

Commandes envoyées : volets `positionCmd` = `UP` / `DOWN` / `STOP` ;
portail, garage, lumières `levelCmd` = `ON` / `OFF` / `STOP` / `TOGGLE`
(le bouton « Actionner » d'un portail envoie `TOGGLE`, comme une télécommande).

Le protocole Tydom n'est pas documenté officiellement ; l'implémentation suit les projets
open source qui l'utilisent (intégration Home Assistant *deltadore-tydom*, *tydom2mqtt*).
Application non officielle, sans lien avec Delta Dore.

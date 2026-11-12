# Installer DeltaHome sur iPhone (avec les widgets)

Il faut un **Mac avec Xcode 16+** et un iPhone sous **iOS 17 ou plus récent**
(nécessaire pour que les boutons des widgets agissent sans ouvrir l'app).
Un identifiant Apple gratuit suffit pour tester (l'app expire au bout de 7 jours ;
avec un compte développeur payant elle reste installée 1 an).

## 1. Préparer le projet

```bash
flutter pub get
open ios/Runner.xcworkspace
```

## 2. Signature et App Group de l'app (cible *Runner*)

1. Cible **Runner** → onglet *Signing & Capabilities* → choisissez votre équipe (Team).
2. Changez le *Bundle Identifier* si besoin (ex. `fr.votrenom.deltahome`).
3. **+ Capability** → **App Groups** → ajoutez `group.fr.domotique.deltahome`
   (Xcode utilisera le fichier `Runner/Runner.entitlements` déjà présent).
4. Glissez `Runner/BackgroundIntent.swift` dans le groupe *Runner* d'Xcode s'il n'y apparaît pas
   (cochez la cible **Runner**).

## 3. Ajouter l'extension widget

1. *File → New → Target… → Widget Extension*.
   - Product Name : **DeltaHomeWidget**
   - décochez *Include Live Activity* et *Include Control*,
     cochez *Include Configuration App Intent* si proposé (peu importe, on remplace le code).
   - À la question *Activate scheme?* → **Cancel** (on garde le schéma Runner).
2. Xcode crée un dossier `DeltaHomeWidget` : **supprimez les fichiers .swift générés**
   (Move to Trash) puis glissez à la place `ios/DeltaHomeWidget/DeltaHomeWidget.swift`
   (cible **DeltaHomeWidget** cochée).
   Glissez aussi `ios/DeltaHomeWidget/Assets.xcassets` (image du réacteur) dans la cible **DeltaHomeWidget**.
3. Sélectionnez `Runner/BackgroundIntent.swift` → panneau de droite *Target Membership* →
   cochez **aussi DeltaHomeWidget**.
4. Cible **DeltaHomeWidget** :
   - *General → Minimum Deployments* : **iOS 17.0** ;
   - *Signing & Capabilities* : même équipe, **+ Capability → App Groups** →
     `group.fr.domotique.deltahome` (fichier `DeltaHomeWidget/DeltaHomeWidget.entitlements`).
5. Le widget utilise le plugin `home_widget` :
   - **Si le projet utilise CocoaPods** (un fichier `ios/Podfile` existe), ajoutez dans le `Podfile`,
     à l'intérieur de `target 'Runner' do … end` :
     ```ruby
     target 'DeltaHomeWidget' do
       inherit! :search_paths
       pod 'home_widget', :path => '.symlinks/plugins/home_widget/ios'
     end
     ```
     puis `cd ios && pod install`.
   - **Si le projet utilise Swift Package Manager** : cible DeltaHomeWidget → *General →
     Frameworks and Libraries* → **+** → ajoutez `home_widget`.

## 4. Lancer

Branchez l'iPhone, sélectionnez-le en haut d'Xcode avec le schéma **Runner**, puis ▶︎.
(Ou `flutter run --release` depuis le terminal.)

Sur l'iPhone : appui long sur l'écran d'accueil → **+** → *DeltaHome* :
- **Bouton DeltaHome** : appui long sur le widget → *Modifier le widget* → choisissez l'action.
  Aussi disponible en petit rond sur l'**écran verrouillé**.
- **Raccourcis DeltaHome** : vos 4 premiers raccourcis.

Un appui long sur l'icône de l'app propose aussi les 4 premiers raccourcis.

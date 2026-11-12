import AppIntents
import Foundation
import home_widget

/// Action déclenchée par un bouton de widget : exécute le code Dart
/// (widgetInteractivityCallback) sans ouvrir l'app.
/// ⚠️ Ce fichier doit appartenir aux DEUX cibles : Runner et DeltaHomeWidget.
@available(iOS 17, *)
public struct BackgroundIntent: AppIntent {
  static public var title: LocalizedStringResource = "Lancer un raccourci DeltaHome"
  static public var isDiscoverable: Bool = false

  @Parameter(title: "URI")
  var url: URL?

  @Parameter(title: "AppGroup")
  var appGroup: String?

  public init() {}

  public init(url: URL?, appGroup: String?) {
    self.url = url
    self.appGroup = appGroup
  }

  public func perform() async throws -> some IntentResult {
    await HomeWidgetBackgroundWorker.run(url: url, appGroup: appGroup ?? "group.fr.domotique.deltahome")
    return .result()
  }
}

/// Permet d'exécuter l'action même quand l'app est complètement fermée.
@available(iOS 17, *)
@available(iOSApplicationExtension, unavailable)
extension BackgroundIntent: ForegroundContinuableIntent {}

import AppIntents
import SwiftUI
import WidgetKit

let appGroup = "group.fr.domotique.deltahome"

// MARK: - Données publiées par l'app Flutter

struct WShortcut: Identifiable, Decodable, Hashable {
  let id: String
  let label: String
  let icon: String
  let account: String
  let color: Int
}

enum Store {
  static var defaults: UserDefaults? { UserDefaults(suiteName: appGroup) }

  static func shortcuts() -> [WShortcut] {
    guard let raw = defaults?.string(forKey: "shortcuts"), let data = raw.data(using: .utf8) else {
      return []
    }
    return (try? JSONDecoder().decode([WShortcut].self, from: data)) ?? []
  }

  static func status(_ id: String) -> String? { defaults?.string(forKey: "status_\(id)") }
}

extension WShortcut {
  var tint: Color {
    Color(
      red: Double((color >> 16) & 0xFF) / 255,
      green: Double((color >> 8) & 0xFF) / 255,
      blue: Double(color & 0xFF) / 255)
  }

  var symbol: String {
    switch Store.status(id) {
    case "running": return "hourglass"
    case "ok": return "checkmark"
    case "error": return "exclamationmark.triangle.fill"
    default: break
    }
    switch icon {
    case "up": return "arrow.up"
    case "down": return "arrow.down"
    case "stop": return "stop.fill"
    case "shutter": return "blinds.horizontal.closed"
    case "gate": return "door.sliding.left.hand.closed"
    case "garage": return "door.garage.closed"
    case "light": return "lightbulb.fill"
    default: return "house.fill"
    }
  }

  var intent: BackgroundIntent {
    BackgroundIntent(url: URL(string: "deltahome://run?id=\(id)"), appGroup: appGroup)
  }

  static let sample = WShortcut(
    id: "sample", label: "Ouvrir portail", icon: "gate", account: "Beaux-parents", color: 0xFFFF8A3D)
}

// MARK: - Vue d'un bouton

struct ShortcutButton: View {
  let shortcut: WShortcut
  var compact = false

  var body: some View {
    Button(intent: shortcut.intent) {
      VStack(alignment: .leading, spacing: 6) {
        Image(systemName: shortcut.symbol)
          .font(.system(size: compact ? 18 : 22, weight: .bold))
          .frame(width: compact ? 34 : 42, height: compact ? 34 : 42)
          .background(shortcut.tint, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
          .foregroundStyle(.white)
        Spacer(minLength: 0)
        Text(shortcut.label)
          .font(.system(size: compact ? 12 : 14, weight: .semibold))
          .lineLimit(2)
          .minimumScaleFactor(0.8)
        if !compact {
          Text(shortcut.account)
            .font(.caption2)
            .foregroundStyle(.secondary)
            .lineLimit(1)
        }
      }
      .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
      .padding(compact ? 8 : 0)
      .background(
        compact ? shortcut.tint.opacity(0.15) : Color.clear,
        in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
    .buttonStyle(.plain)
  }
}

struct EmptyHint: View {
  var body: some View {
    VStack(spacing: 6) {
      Image(systemName: "plus.circle.fill").font(.title2)
      Text("Créez des raccourcis dans DeltaHome")
        .font(.caption)
        .multilineTextAlignment(.center)
    }
    .foregroundStyle(.secondary)
  }
}

// MARK: - Widget « Bouton » (une action au choix)

struct ShortcutEntity: AppEntity {
  static var typeDisplayRepresentation: TypeDisplayRepresentation = "Raccourci"
  static var defaultQuery = ShortcutQuery()

  let id: String
  let label: String
  let account: String

  var displayRepresentation: DisplayRepresentation {
    DisplayRepresentation(title: "\(label)", subtitle: "\(account)")
  }

  init(_ s: WShortcut) {
    id = s.id
    label = s.label
    account = s.account
  }
}

struct ShortcutQuery: EntityQuery {
  func entities(for identifiers: [String]) async throws -> [ShortcutEntity] {
    Store.shortcuts().filter { identifiers.contains($0.id) }.map(ShortcutEntity.init)
  }

  func suggestedEntities() async throws -> [ShortcutEntity] {
    Store.shortcuts().map(ShortcutEntity.init)
  }
}

struct PickShortcutIntent: WidgetConfigurationIntent {
  static var title: LocalizedStringResource = "Choisir l'action"
  static var description = IntentDescription("Le raccourci DeltaHome déclenché par ce bouton.")

  @Parameter(title: "Action")
  var shortcut: ShortcutEntity?
}

struct ButtonEntry: TimelineEntry {
  let date: Date
  let shortcut: WShortcut?
}

struct ButtonProvider: AppIntentTimelineProvider {
  func placeholder(in context: Context) -> ButtonEntry { ButtonEntry(date: .now, shortcut: .sample) }

  func snapshot(for configuration: PickShortcutIntent, in context: Context) async -> ButtonEntry {
    entry(for: configuration) ?? ButtonEntry(date: .now, shortcut: .sample)
  }

  func timeline(for configuration: PickShortcutIntent, in context: Context) async -> Timeline<ButtonEntry> {
    Timeline(entries: [entry(for: configuration) ?? ButtonEntry(date: .now, shortcut: nil)], policy: .never)
  }

  private func entry(for configuration: PickShortcutIntent) -> ButtonEntry? {
    let all = Store.shortcuts()
    let chosen = all.first { $0.id == configuration.shortcut?.id } ?? all.first
    return chosen.map { ButtonEntry(date: .now, shortcut: $0) }
  }
}

struct ButtonWidgetView: View {
  @Environment(\.widgetFamily) var family
  let entry: ButtonEntry

  var body: some View {
    if let s = entry.shortcut {
      if family == .accessoryCircular {
        Button(intent: s.intent) {
          ZStack {
            AccessoryWidgetBackground()
            Image(systemName: s.symbol).font(.title2.bold())
          }
        }
        .buttonStyle(.plain)
      } else {
        ShortcutButton(shortcut: s)
      }
    } else {
      EmptyHint()
    }
  }
}

struct DeltaHomeButtonWidget: Widget {
  var body: some WidgetConfiguration {
    AppIntentConfiguration(kind: "DeltaHomeButtonWidget", intent: PickShortcutIntent.self, provider: ButtonProvider()) {
      entry in
      ButtonWidgetView(entry: entry)
        .containerBackground(.fill.tertiary, for: .widget)
    }
    .configurationDisplayName("Bouton DeltaHome")
    .description("Un bouton pour une action : ouvrir le portail, fermer les volets…")
    .supportedFamilies([.systemSmall, .accessoryCircular])
  }
}

// MARK: - Widget « Raccourcis » (les 4 premiers)

struct ShortcutsEntry: TimelineEntry {
  let date: Date
  let shortcuts: [WShortcut]
}

struct ShortcutsProvider: TimelineProvider {
  func placeholder(in context: Context) -> ShortcutsEntry {
    ShortcutsEntry(date: .now, shortcuts: [.sample])
  }

  func getSnapshot(in context: Context, completion: @escaping (ShortcutsEntry) -> Void) {
    let list = Store.shortcuts()
    completion(ShortcutsEntry(date: .now, shortcuts: list.isEmpty ? [.sample] : Array(list.prefix(4))))
  }

  func getTimeline(in context: Context, completion: @escaping (Timeline<ShortcutsEntry>) -> Void) {
    let entry = ShortcutsEntry(date: .now, shortcuts: Array(Store.shortcuts().prefix(4)))
    completion(Timeline(entries: [entry], policy: .never))
  }
}

struct ShortcutsWidgetView: View {
  @Environment(\.widgetFamily) var family
  let entry: ShortcutsEntry

  var body: some View {
    if entry.shortcuts.isEmpty {
      EmptyHint()
    } else if family == .systemMedium {
      HStack(spacing: 8) {
        ForEach(entry.shortcuts) { ShortcutButton(shortcut: $0, compact: true) }
      }
    } else {
      let rows = stride(from: 0, to: entry.shortcuts.count, by: 2).map {
        Array(entry.shortcuts[$0..<min($0 + 2, entry.shortcuts.count)])
      }
      VStack(spacing: 8) {
        ForEach(rows, id: \.self) { row in
          HStack(spacing: 8) {
            ForEach(row) { ShortcutButton(shortcut: $0, compact: true) }
          }
        }
      }
    }
  }
}

struct DeltaHomeShortcutsWidget: Widget {
  var body: some WidgetConfiguration {
    StaticConfiguration(kind: "DeltaHomeShortcutsWidget", provider: ShortcutsProvider()) { entry in
      ShortcutsWidgetView(entry: entry)
        .containerBackground(.fill.tertiary, for: .widget)
    }
    .configurationDisplayName("Raccourcis DeltaHome")
    .description("Vos 4 premiers raccourcis, en un tap.")
    .supportedFamilies([.systemSmall, .systemMedium])
  }
}

// MARK: - Point d'entrée

@main
struct DeltaHomeWidgets: WidgetBundle {
  var body: some Widget {
    DeltaHomeButtonWidget()
    DeltaHomeShortcutsWidget()
  }
}

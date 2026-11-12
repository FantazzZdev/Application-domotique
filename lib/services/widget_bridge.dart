import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:home_widget/home_widget.dart';

import '../models.dart';
import '../tydom/controller.dart';
import 'storage.dart';

const String appGroupId = 'group.fr.domotique.deltahome';
const String iosShortcutsWidget = 'DeltaHomeShortcutsWidget';
const String iosButtonWidget = 'DeltaHomeButtonWidget';
const String androidShortcutsWidget = 'ShortcutsWidgetProvider';
const String androidButtonWidget = 'ButtonWidgetProvider';

/// Couleurs d'accent attribuées aux comptes (partagées avec les widgets).
const List<int> accountColors = [
  0xFF4F7CFF, // bleu
  0xFFFF8A3D, // orange
  0xFF22B07D, // vert
  0xFFB45CFF, // violet
  0xFFFF4F7B, // rose
  0xFF14B8C4, // turquoise
];

class WidgetBridge {
  static Future<void> init() async {
    await HomeWidget.setAppGroupId(appGroupId);
    await HomeWidget.registerInteractivityCallback(widgetInteractivityCallback);
  }

  /// Publie la liste des raccourcis pour les widgets natifs.
  static Future<void> publish(AppData data) async {
    final list = data.shortcuts.map((s) {
      final acc = data.account(s.accountId);
      return {
        'id': s.id,
        'label': s.label,
        'icon': s.icon,
        'account': acc?.label ?? '',
        'color': accountColors[(acc?.colorIndex ?? 0) % accountColors.length],
      };
    }).toList();
    await HomeWidget.saveWidgetData<String>('shortcuts', jsonEncode(list));
    await refresh();
  }

  static Future<void> refresh() async {
    await HomeWidget.updateWidget(androidName: androidShortcutsWidget, iOSName: iosShortcutsWidget);
    await HomeWidget.updateWidget(androidName: androidButtonWidget, iOSName: iosButtonWidget);
  }

  static Future<void> setStatus(String shortcutId, String? status) async {
    await HomeWidget.saveWidgetData<String>('status_$shortcutId', status);
    await refresh();
  }
}

/// Appelé quand on touche un bouton de widget, même si l'app est fermée.
/// URI : `deltahome://run?id=<raccourci>`
@pragma('vm:entry-point')
Future<void> widgetInteractivityCallback(Uri? uri) async {
  WidgetsFlutterBinding.ensureInitialized();
  final id = uri?.queryParameters['id'];
  if (uri?.host != 'run' || id == null) return;
  await HomeWidget.setAppGroupId(appGroupId);
  final data = await Storage.load();
  Shortcut? shortcut;
  for (final s in data.shortcuts) {
    if (s.id == id) shortcut = s;
  }
  if (shortcut == null) return;

  await WidgetBridge.setStatus(id, 'running');
  final controller = TydomController();
  var status = 'ok';
  try {
    await controller.runShortcut(data, shortcut);
  } on Exception {
    status = 'error';
  } finally {
    await controller.closeAll();
  }
  await WidgetBridge.setStatus(id, status);
  await Future<void>.delayed(const Duration(seconds: 4));
  await WidgetBridge.setStatus(id, null);
}

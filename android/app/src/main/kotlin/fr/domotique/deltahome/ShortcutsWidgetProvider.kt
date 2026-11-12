package fr.domotique.deltahome

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.view.View
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetProvider

/** Widget "Raccourcis" : les 4 premiers raccourcis de l'app. */
class ShortcutsWidgetProvider : HomeWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences,
    ) {
        val shortcuts = WidgetCommon.shortcuts(widgetData)
        for (id in appWidgetIds) {
            val views = RemoteViews(context.packageName, R.layout.widget_shortcuts)
            if (shortcuts.isEmpty()) {
                views.setViewVisibility(R.id.row, View.GONE)
                views.setViewVisibility(R.id.empty, View.VISIBLE)
                views.setOnClickPendingIntent(R.id.empty, WidgetCommon.openAppIntent(context))
            } else {
                views.setViewVisibility(R.id.row, View.VISIBLE)
                views.setViewVisibility(R.id.empty, View.GONE)
                for (i in 0 until 4) {
                    val s = shortcuts.getOrNull(i)
                    WidgetCommon.bindSlot(context, views, widgetData, i, s)
                    if (s == null) {
                        // Emplacements vides : on les retire pour élargir les autres.
                        val slot = context.resources.getIdentifier("slot_$i", "id", context.packageName)
                        views.setViewVisibility(slot, View.GONE)
                    }
                }
            }
            appWidgetManager.updateAppWidget(id, views)
        }
    }
}

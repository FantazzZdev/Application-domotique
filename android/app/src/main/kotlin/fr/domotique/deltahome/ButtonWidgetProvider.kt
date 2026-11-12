package fr.domotique.deltahome

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetProvider

/** Widget "Bouton" : une seule action, choisie à la pose du widget. */
class ButtonWidgetProvider : HomeWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences,
    ) {
        val shortcuts = WidgetCommon.shortcuts(widgetData)
        for (id in appWidgetIds) {
            val chosen = widgetData.getString("button_$id", null)
            val s = shortcuts.firstOrNull { it.id == chosen } ?: shortcuts.firstOrNull()
            val views = RemoteViews(context.packageName, R.layout.widget_button)
            WidgetCommon.bindSlot(context, views, widgetData, 0, s)
            appWidgetManager.updateAppWidget(id, views)
        }
    }

    override fun onDeleted(context: Context, appWidgetIds: IntArray) {
        super.onDeleted(context, appWidgetIds)
        val editor = WidgetCommon.prefs(context).edit()
        for (id in appWidgetIds) editor.remove("button_$id")
        editor.apply()
    }
}

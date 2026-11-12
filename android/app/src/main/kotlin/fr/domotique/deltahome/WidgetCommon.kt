package fr.domotique.deltahome

import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.content.Context
import android.content.SharedPreferences
import android.net.Uri
import android.view.View
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetBackgroundIntent
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetPlugin
import org.json.JSONArray

/** Raccourci tel que publié par l'app Flutter (clé "shortcuts"). */
data class WidgetShortcut(
    val id: String,
    val label: String,
    val icon: String,
    val account: String,
    val color: Int,
)

object WidgetCommon {
    fun shortcuts(prefs: SharedPreferences): List<WidgetShortcut> {
        val raw = prefs.getString("shortcuts", null) ?: return emptyList()
        return try {
            val arr = JSONArray(raw)
            (0 until arr.length()).map { i ->
                val o = arr.getJSONObject(i)
                WidgetShortcut(
                    id = o.getString("id"),
                    label = o.optString("label"),
                    icon = o.optString("icon"),
                    account = o.optString("account"),
                    color = o.optLong("color", 0xFF4F7CFF).toInt(),
                )
            }
        } catch (e: Exception) {
            emptyList()
        }
    }

    private fun iconRes(key: String): Int = when (key) {
        "up" -> R.drawable.ic_w_up
        "down" -> R.drawable.ic_w_down
        "stop" -> R.drawable.ic_w_stop
        "shutter" -> R.drawable.ic_w_shutter
        "gate" -> R.drawable.ic_w_gate
        "garage" -> R.drawable.ic_w_garage
        "light" -> R.drawable.ic_w_light
        else -> R.drawable.ic_w_home
    }

    /** Remplit un emplacement (fond coloré, icône, libellé, action au toucher). */
    fun bindSlot(
        context: Context,
        views: RemoteViews,
        prefs: SharedPreferences,
        index: Int,
        shortcut: WidgetShortcut?,
    ) {
        val res = context.resources
        val pkg = context.packageName
        val slot = res.getIdentifier("slot_$index", "id", pkg)
        val bg = res.getIdentifier("bg_$index", "id", pkg)
        val icon = res.getIdentifier("icon_$index", "id", pkg)
        val label = res.getIdentifier("label_$index", "id", pkg)
        if (shortcut == null) {
            views.setViewVisibility(slot, View.INVISIBLE)
            return
        }
        views.setViewVisibility(slot, View.VISIBLE)
        views.setInt(bg, "setColorFilter", shortcut.color)
        val status = prefs.getString("status_${shortcut.id}", null)
        val iconId = when (status) {
            "running" -> R.drawable.ic_w_wait
            "ok" -> R.drawable.ic_w_check
            "error" -> R.drawable.ic_w_error
            else -> iconRes(shortcut.icon)
        }
        views.setImageViewResource(icon, iconId)
        views.setTextViewText(label, shortcut.label)
        views.setContentDescription(slot, "${shortcut.label} (${shortcut.account})")
        val intent = HomeWidgetBackgroundIntent.getBroadcast(
            context,
            Uri.parse("deltahome://run?id=${Uri.encode(shortcut.id)}"),
        )
        views.setOnClickPendingIntent(slot, intent)
    }

    fun openAppIntent(context: Context) =
        HomeWidgetLaunchIntent.getActivity(context, MainActivity::class.java)

    fun prefs(context: Context): SharedPreferences = HomeWidgetPlugin.getData(context)

    fun refreshAll(context: Context, provider: Class<*>) {
        val manager = AppWidgetManager.getInstance(context)
        val ids = manager.getAppWidgetIds(ComponentName(context, provider))
        if (ids.isEmpty()) return
        val intent = android.content.Intent(context, provider)
        intent.action = AppWidgetManager.ACTION_APPWIDGET_UPDATE
        intent.putExtra(AppWidgetManager.EXTRA_APPWIDGET_IDS, ids)
        context.sendBroadcast(intent)
    }
}

package fr.domotique.deltahome

import android.app.Activity
import android.app.AlertDialog
import android.appwidget.AppWidgetManager
import android.content.Intent
import android.os.Bundle
import android.widget.Toast

/** Écran affiché à la pose d'un widget "Bouton" : choix du raccourci. */
class ButtonWidgetConfigActivity : Activity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setResult(RESULT_CANCELED)
        val widgetId = intent?.extras?.getInt(
            AppWidgetManager.EXTRA_APPWIDGET_ID,
            AppWidgetManager.INVALID_APPWIDGET_ID,
        ) ?: AppWidgetManager.INVALID_APPWIDGET_ID
        if (widgetId == AppWidgetManager.INVALID_APPWIDGET_ID) {
            finish()
            return
        }
        val prefs = WidgetCommon.prefs(this)
        val shortcuts = WidgetCommon.shortcuts(prefs)
        if (shortcuts.isEmpty()) {
            Toast.makeText(this, R.string.widget_empty, Toast.LENGTH_LONG).show()
            finish()
            return
        }
        val labels = shortcuts.map { s ->
            if (s.account.isEmpty()) s.label else "${s.label}  ·  ${s.account}"
        }.toTypedArray()
        AlertDialog.Builder(this, android.R.style.Theme_DeviceDefault_Dialog_Alert)
            .setTitle(R.string.widget_pick)
            .setItems(labels) { _, which ->
                prefs.edit().putString("button_$widgetId", shortcuts[which].id).apply()
                WidgetCommon.refreshAll(this, ButtonWidgetProvider::class.java)
                setResult(
                    RESULT_OK,
                    Intent().putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, widgetId),
                )
                finish()
            }
            .setOnCancelListener { finish() }
            .show()
    }
}

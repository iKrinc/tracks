package com.krinc.tracks

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.Intent
import android.widget.RemoteViews

/**
 * Home-screen quick add. Each tap opens Tracks with an action that
 * MainActivity hands to Dart: focus the quick-add bar, or open the form.
 */
class QuickAddWidget : AppWidgetProvider() {
    override fun onUpdate(context: Context, manager: AppWidgetManager, ids: IntArray) {
        val views = RemoteViews(context.packageName, R.layout.quick_add_widget).apply {
            setOnClickPendingIntent(R.id.widget_quick_add, open(context, ACTION_QUICK_ADD, 1))
            setOnClickPendingIntent(R.id.widget_form, open(context, ACTION_FORM, 2))
        }
        for (id in ids) manager.updateAppWidget(id, views)
    }

    private fun open(context: Context, action: String, code: Int): PendingIntent =
        PendingIntent.getActivity(
            context,
            code,
            Intent(context, MainActivity::class.java)
                .setAction(action)
                .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )

    companion object {
        const val ACTION_QUICK_ADD = "com.krinc.tracks.QUICK_ADD"
        const val ACTION_FORM = "com.krinc.tracks.ADD_FORM"
    }
}

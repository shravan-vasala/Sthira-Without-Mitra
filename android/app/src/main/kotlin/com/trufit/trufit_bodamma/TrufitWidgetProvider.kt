package com.trufit.trufit_bodamma

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetProvider
import android.content.Intent
import android.app.PendingIntent
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

class TrufitWidgetProvider : HomeWidgetProvider() {

    override fun onUpdate(context: Context, appWidgetManager: AppWidgetManager, appWidgetIds: IntArray, widgetData: SharedPreferences) {
        appWidgetIds.forEach { widgetId ->
            val views = RemoteViews(context.packageName, R.layout.widget_layout_small).apply {
                val todayStr = SimpleDateFormat("yyyy-MM-dd", Locale.getDefault()).format(Date())
                val storedDate = widgetData.getString("date", "") ?: ""
                
                if (todayStr == storedDate) {
                    val stepsStr = widgetData.getString("stepsStr", "--") ?: "--"
                    val stepsProgress = widgetData.getInt("stepsProgress", 0)
                    val workoutText = widgetData.getString("workoutText", "Workout") ?: "Workout"
                    val workoutSubText = widgetData.getString("workoutSubText", "Pending") ?: "Pending"
                    val mealsText = widgetData.getString("mealsText", "-/-") ?: "-/-"
                    val habitsText = widgetData.getString("habitsText", "-/-") ?: "-/-"
                    
                    setTextViewText(R.id.tv_steps, stepsStr)
                    setProgressBar(R.id.pb_steps, 100, stepsProgress, false)
                    setTextViewText(R.id.tv_workout, workoutText)
                    setTextViewText(R.id.tv_workout_sub, workoutSubText)
                    setTextViewText(R.id.tv_meals, mealsText)
                    setTextViewText(R.id.tv_habits, habitsText)
                } else {
                    setTextViewText(R.id.tv_steps, "--")
                    setProgressBar(R.id.pb_steps, 100, 0, false)
                    setTextViewText(R.id.tv_workout, "Workout")
                    setTextViewText(R.id.tv_workout_sub, "Pending")
                    setTextViewText(R.id.tv_meals, "-/-")
                    setTextViewText(R.id.tv_habits, "-/-")
                }

                // Tapping widget opens app
                val intent = context.packageManager.getLaunchIntentForPackage(context.packageName)
                val pendingIntent = PendingIntent.getActivity(context, 0, intent, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
                setOnClickPendingIntent(R.id.widget_root, pendingIntent)
            }
            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }
}


package com.trufit.trufit_bodamma

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.util.SizeF
import android.view.View
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetProvider
import org.json.JSONObject
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import android.util.Log

class TrufitWidgetProvider : HomeWidgetProvider() {

    override fun onUpdate(context: Context, appWidgetManager: AppWidgetManager, appWidgetIds: IntArray, widgetData: SharedPreferences) {
        appWidgetIds.forEach { widgetId ->
            updateWidget(context, appWidgetManager, widgetId, widgetData)
        }
    }

    override fun onAppWidgetOptionsChanged(context: Context, appWidgetManager: AppWidgetManager, appWidgetId: Int, newOptions: Bundle?) {
        super.onAppWidgetOptionsChanged(context, appWidgetManager, appWidgetId, newOptions)
        val widgetData = context.getSharedPreferences("HomeWidgetPreferences", Context.MODE_PRIVATE)
        updateWidget(context, appWidgetManager, appWidgetId, widgetData)
    }

    private fun updateWidget(context: Context, appWidgetManager: AppWidgetManager, widgetId: Int, widgetData: SharedPreferences) {
        val todayStr = SimpleDateFormat("yyyy-MM-dd", Locale.getDefault()).format(Date())
        val jsonStr = widgetData.getString("widget_data", "{}") ?: "{}"
        
        var date = ""
        var updatedAt = "--:--"
        var steps: Int? = null
        var stepGoal: Int? = null
        var mealsLogged = 0
        var totalMeals = 0
        var habitsDone = 0
        var totalHabits = 0
        var energy: Double? = null
        var protein: Double? = null
        var isRest = false
        var workoutTitle = "Open app"
        var workoutStatus = "to refresh"

        try {
            val json = JSONObject(jsonStr)
            date = json.optString("date", "")
            if (date == todayStr) {
                updatedAt = json.optString("updatedAt", "--:--")
                steps = if (json.isNull("steps")) null else json.optInt("steps")
                stepGoal = if (json.isNull("stepGoal")) null else json.optInt("stepGoal")
                mealsLogged = json.optInt("mealsLogged", 0)
                totalMeals = json.optInt("totalMeals", 0)
                habitsDone = json.optInt("habitsDone", 0)
                totalHabits = json.optInt("totalHabits", 0)
                energy = if (json.isNull("energy")) null else json.optDouble("energy")
                protein = if (json.isNull("protein")) null else json.optDouble("protein")
                isRest = json.optBoolean("isRest", false)
                workoutTitle = json.optString("workoutTitle", "Workout")
                workoutStatus = json.optString("workoutStatus", "Pending")
            }
        } catch (e: Exception) {
            Log.e("TrufitWidgetProvider", "Error parsing widget data", e)
        }

        fun populateShared(views: RemoteViews) {
            views.setTextViewText(R.id.tv_updated_at, "Updated $updatedAt")

            if (steps == null) {
                views.setTextViewText(R.id.tv_steps_value, if (date == todayStr) "0" else "-")
                views.setViewVisibility(R.id.tv_steps_goal, View.GONE)
                views.setProgressBar(R.id.pb_steps, 100, 0, false)
            } else {
                val stepCountStr = String.format("%,d", steps)
                views.setTextViewText(R.id.tv_steps_value, stepCountStr)
                if (stepGoal != null && stepGoal > 0) {
                    views.setViewVisibility(R.id.tv_steps_goal, View.VISIBLE)
                    views.setTextViewText(R.id.tv_steps_goal, " / ${String.format("%,d", stepGoal)}")
                    val progress = ((steps.toFloat() / stepGoal.toFloat()) * 100).toInt().coerceIn(0, 100)
                    views.setProgressBar(R.id.pb_steps, 100, progress, false)
                } else {
                    views.setViewVisibility(R.id.tv_steps_goal, View.GONE)
                    views.setProgressBar(R.id.pb_steps, 100, 100, false)
                }
            }
        }

        fun populateCompact(views: RemoteViews, reqBase: Int) {
            populateShared(views)
            val baseIntent = context.packageManager.getLaunchIntentForPackage(context.packageName) ?: Intent()
            val rootPi = PendingIntent.getActivity(context, reqBase, baseIntent, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
            views.setOnClickPendingIntent(R.id.widget_root_compact, rootPi)
        }

        fun populateStandard(views: RemoteViews, reqBase: Int) {
            populateShared(views)
            if (date == todayStr) {
                views.setTextViewText(R.id.tv_meals_value, "$mealsLogged/$totalMeals")
                views.setTextViewText(R.id.tv_habits_value, "$habitsDone/$totalHabits")
            } else {
                views.setTextViewText(R.id.tv_meals_value, "-/-")
                views.setTextViewText(R.id.tv_habits_value, "-/-")
            }

            val baseIntent = context.packageManager.getLaunchIntentForPackage(context.packageName) ?: Intent()
            
            val stepsIntent = Intent(baseIntent).apply { data = Uri.parse("trufit://progress?metric=steps") }
            val stepsPi = PendingIntent.getActivity(context, reqBase + 1, stepsIntent, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
            views.setOnClickPendingIntent(R.id.widget_steps_area, stepsPi)

            val mealsIntent = Intent(baseIntent).apply { data = Uri.parse("trufit://home/meals") }
            val mealsPi = PendingIntent.getActivity(context, reqBase + 2, mealsIntent, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
            views.setOnClickPendingIntent(R.id.widget_meals_area, mealsPi)

            val habitsIntent = Intent(baseIntent).apply { data = Uri.parse("trufit://home") }
            val habitsPi = PendingIntent.getActivity(context, reqBase + 3, habitsIntent, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
            views.setOnClickPendingIntent(R.id.widget_habits_area, habitsPi)

            val rootPi = PendingIntent.getActivity(context, reqBase, baseIntent, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
            views.setOnClickPendingIntent(R.id.widget_root_standard, rootPi)
        }

        fun populateExpanded(views: RemoteViews, reqBase: Int) {
            populateStandard(views, reqBase)

            if (energy != null || protein != null) {
                views.setViewVisibility(R.id.widget_nutrition_area, View.VISIBLE)
                views.setTextViewText(R.id.tv_nutrition_energy, if (energy != null) "${energy.toInt()} kcal" else "-- kcal")
                views.setTextViewText(R.id.tv_nutrition_protein, if (protein != null) "${protein.toInt()}g protein" else "--g protein")
            } else {
                views.setViewVisibility(R.id.widget_nutrition_area, View.GONE)
            }

            views.setTextViewText(R.id.tv_workout_title, workoutTitle)
            views.setTextViewText(R.id.tv_workout_sub, workoutStatus)

            val baseIntent = context.packageManager.getLaunchIntentForPackage(context.packageName) ?: Intent()
            
            val workoutIntent = Intent(baseIntent).apply { data = Uri.parse("trufit://home/workout/today") }
            val workoutPi = PendingIntent.getActivity(context, reqBase + 4, workoutIntent, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
            views.setOnClickPendingIntent(R.id.widget_workout_area, workoutPi)

            val rootPi = PendingIntent.getActivity(context, reqBase, baseIntent, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
            views.setOnClickPendingIntent(R.id.widget_root_expanded, rootPi)
        }

        val remoteViews: RemoteViews = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            val compact = RemoteViews(context.packageName, R.layout.widget_layout_compact).apply { populateCompact(this, 100) }
            val standard = RemoteViews(context.packageName, R.layout.widget_layout_standard).apply { populateStandard(this, 200) }
            val expanded = RemoteViews(context.packageName, R.layout.widget_layout_expanded).apply { populateExpanded(this, 300) }
            
            val viewMapping = mapOf(
                SizeF(110f, 110f) to compact,
                SizeF(250f, 110f) to standard,
                SizeF(250f, 180f) to expanded
            )
            RemoteViews(viewMapping)
        } else {
            val options = appWidgetManager.getAppWidgetOptions(widgetId)
            val minWidth = options.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_WIDTH)
            val minHeight = options.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_HEIGHT)

            if (minHeight >= 180 && minWidth >= 250) {
                RemoteViews(context.packageName, R.layout.widget_layout_expanded).apply { populateExpanded(this, 300) }
            } else if (minWidth >= 250) {
                RemoteViews(context.packageName, R.layout.widget_layout_standard).apply { populateStandard(this, 200) }
            } else {
                RemoteViews(context.packageName, R.layout.widget_layout_compact).apply { populateCompact(this, 100) }
            }
        }

        appWidgetManager.updateAppWidget(widgetId, remoteViews)
    }
}

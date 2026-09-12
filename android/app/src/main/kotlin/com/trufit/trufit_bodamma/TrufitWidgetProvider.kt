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
        var workoutTitle = "Workout"
        var workoutStatus = "Pending"

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

        fun populateViews(views: RemoteViews) {
            // Freshness
            views.setTextViewText(R.id.tv_updated_at, "Updated $updatedAt")

            // Steps
            if (steps == null) {
                views.setTextViewText(R.id.tv_steps_value, "--")
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

            // Meals
            views.setTextViewText(R.id.tv_meals_value, "$mealsLogged/$totalMeals")

            // Habits
            views.setTextViewText(R.id.tv_habits_value, "$habitsDone/$totalHabits")

            // Nutrition
            if (energy != null || protein != null) {
                views.setViewVisibility(R.id.widget_nutrition_area, View.VISIBLE)
                views.setTextViewText(R.id.tv_nutrition_energy, if (energy != null) "${energy.toInt()} kcal" else "-- kcal")
                views.setTextViewText(R.id.tv_nutrition_protein, if (protein != null) "${protein.toInt()}g protein" else "--g protein")
            } else {
                views.setViewVisibility(R.id.widget_nutrition_area, View.GONE)
            }

            // Workout
            views.setTextViewText(R.id.tv_workout_title, workoutTitle)
            views.setTextViewText(R.id.tv_workout_sub, workoutStatus)

            // Intents
            val baseIntent = context.packageManager.getLaunchIntentForPackage(context.packageName) ?: Intent()
            
            // Steps tap
            val stepsIntent = Intent(baseIntent).apply { data = Uri.parse("trufit://progress?metric=steps") }
            val stepsPi = PendingIntent.getActivity(context, 1, stepsIntent, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
            views.setOnClickPendingIntent(R.id.widget_steps_area, stepsPi)

            // Meals tap
            val mealsIntent = Intent(baseIntent).apply { data = Uri.parse("trufit://home/meals") }
            val mealsPi = PendingIntent.getActivity(context, 2, mealsIntent, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
            views.setOnClickPendingIntent(R.id.widget_meals_area, mealsPi)

            // Habits tap
            val habitsIntent = Intent(baseIntent).apply { data = Uri.parse("trufit://home") }
            val habitsPi = PendingIntent.getActivity(context, 3, habitsIntent, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
            views.setOnClickPendingIntent(R.id.widget_habits_area, habitsPi)

            // Workout tap
            val workoutIntent = Intent(baseIntent).apply { data = Uri.parse("trufit://home/workout/today") }
            val workoutPi = PendingIntent.getActivity(context, 4, workoutIntent, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
            views.setOnClickPendingIntent(R.id.widget_workout_area, workoutPi)
            
            // Root tap fallback
            val rootPi = PendingIntent.getActivity(context, 0, baseIntent, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
            views.setOnClickPendingIntent(R.id.widget_root_compact, rootPi)
            views.setOnClickPendingIntent(R.id.widget_root_standard, rootPi)
            views.setOnClickPendingIntent(R.id.widget_root_expanded, rootPi)
        }

        val remoteViews: RemoteViews = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            val compact = RemoteViews(context.packageName, R.layout.widget_layout_compact).apply { populateViews(this) }
            val standard = RemoteViews(context.packageName, R.layout.widget_layout_standard).apply { populateViews(this) }
            val expanded = RemoteViews(context.packageName, R.layout.widget_layout_expanded).apply { populateViews(this) }
            
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

            val layoutId = when {
                minHeight >= 180 && minWidth >= 250 -> R.layout.widget_layout_expanded
                minWidth >= 250 -> R.layout.widget_layout_standard
                else -> R.layout.widget_layout_compact
            }
            RemoteViews(context.packageName, layoutId).apply { populateViews(this) }
        }

        appWidgetManager.updateAppWidget(widgetId, remoteViews)
    }
}

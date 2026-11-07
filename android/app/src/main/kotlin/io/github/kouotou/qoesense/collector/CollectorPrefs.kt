package io.github.kouotou.qoesense.collector

import android.content.Context
import io.github.kouotou.qoesense.SurveyAnswerMessage
import org.json.JSONArray
import org.json.JSONObject

/**
 * Native-side durable state. It has to be native because BootReceiver reads it before any
 * Flutter engine exists, and because survey taps must survive even if no engine is running.
 * Replaces the reference CollectionStatePreferences, which used DataStore.
 */
class CollectorPrefs(context: Context) {
    private val prefs = context.applicationContext.getSharedPreferences("qoesense_collector", Context.MODE_PRIVATE)

    var collectionEnabled: Boolean
        get() = prefs.getBoolean(KEY_ENABLED, false)
        set(value) {
            prefs.edit().putBoolean(KEY_ENABLED, value).commit()
        }

    var lastUploadMs: Long?
        get() = prefs.getLong(KEY_LAST_UPLOAD, -1).takeIf { it >= 0 }
        set(value) {
            prefs.edit().putLong(KEY_LAST_UPLOAD, value ?: -1).apply()
        }

    var consentMs: Long?
        get() = prefs.getLong(KEY_CONSENT, -1).takeIf { it >= 0 }
        set(value) {
            prefs.edit().putLong(KEY_CONSENT, value ?: -1).commit()
        }

    /**
     * Survey taps waiting for Dart. Written with commit() (synchronous) before the survey
     * closes, so a tap survives a process kill straight afterwards.
     */
    @Synchronized
    fun appendAnswer(a: SurveyAnswerMessage) {
        val arr = JSONArray(prefs.getString(KEY_ANSWERS, "[]"))
        arr.put(
            JSONObject()
                .put("responseId", a.responseId)
                .put("score", a.score)
                .put("triggerType", a.triggerType)
                .put("tapMs", a.tapMs)
                .put("promptedAtMs", a.promptedAtMs ?: JSONObject.NULL)
                .put("presentationMode", a.presentationMode),
        )
        prefs.edit().putString(KEY_ANSWERS, arr.toString()).commit()
    }

    @Synchronized
    fun pendingAnswers(): List<SurveyAnswerMessage> {
        val arr = JSONArray(prefs.getString(KEY_ANSWERS, "[]"))
        return (0 until arr.length()).map { i ->
            val o = arr.getJSONObject(i)
            SurveyAnswerMessage(
                responseId = o.getString("responseId"),
                score = o.getLong("score"),
                triggerType = o.getString("triggerType"),
                tapMs = o.getLong("tapMs"),
                promptedAtMs = if (o.isNull("promptedAtMs")) null else o.getLong("promptedAtMs"),
                presentationMode = o.getString("presentationMode"),
            )
        }
    }

    @Synchronized
    fun acknowledge(ids: Collection<String>) {
        val keep = JSONArray()
        val arr = JSONArray(prefs.getString(KEY_ANSWERS, "[]"))
        for (i in 0 until arr.length()) {
            val o = arr.getJSONObject(i)
            if (o.getString("responseId") !in ids) keep.put(o)
        }
        prefs.edit().putString(KEY_ANSWERS, keep.toString()).commit()
    }

    private companion object {
        const val KEY_ENABLED = "collection_enabled"
        const val KEY_LAST_UPLOAD = "last_upload_ms"
        const val KEY_CONSENT = "consent_ms"
        const val KEY_ANSWERS = "pending_survey_answers"
    }
}

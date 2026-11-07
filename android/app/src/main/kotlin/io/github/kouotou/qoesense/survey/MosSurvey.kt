package io.github.kouotou.qoesense.survey

import android.app.Activity
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.graphics.Color
import android.graphics.drawable.GradientDrawable
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.util.TypedValue
import android.view.Gravity
import android.view.ViewGroup.LayoutParams.MATCH_PARENT
import android.view.ViewGroup.LayoutParams.WRAP_CONTENT
import android.widget.Button
import android.widget.FrameLayout
import android.widget.LinearLayout
import android.widget.TextView
import androidx.core.app.NotificationCompat
import io.github.kouotou.qoesense.R
import io.github.kouotou.qoesense.SurveyAnswerMessage
import io.github.kouotou.qoesense.capture.PermissionUtils
import io.github.kouotou.qoesense.collector.CollectorPrefs
import java.util.UUID

/**
 * Port of the reference MosSurveyScheduler.presentSurvey: the overlay activity when
 * SYSTEM_ALERT_WINDOW is granted, otherwise a notification that opens it. The same channel,
 * strings and flags.
 */
object SurveyPresenter {
    private const val CHANNEL_ID = "mos_survey"
    private const val NOTIFICATION_ID = 2

    fun present(context: Context, triggerType: String) {
        val now = System.currentTimeMillis()
        if (PermissionUtils.hasOverlayPermission(context)) {
            context.startActivity(MosSurveyActivity.intent(context, triggerType, now, "OVERLAY"))
        } else {
            showNotification(context, triggerType, now)
        }
    }

    private fun showNotification(context: Context, triggerType: String, promptedAtMs: Long) {
        val nm = context.getSystemService(NotificationManager::class.java)
        nm.createNotificationChannel(
            NotificationChannel(
                CHANNEL_ID,
                context.getString(R.string.notif_survey_channel_name),
                NotificationManager.IMPORTANCE_DEFAULT,
            ).apply { description = context.getString(R.string.notif_survey_channel_desc) },
        )
        val pending = PendingIntent.getActivity(
            context,
            0,
            MosSurveyActivity.intent(context, triggerType, promptedAtMs, "NOTIFICATION"),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        val n = NotificationCompat.Builder(context, CHANNEL_ID)
            .setContentTitle(context.getString(R.string.notif_survey_title))
            .setContentText(context.getString(R.string.notif_survey_text))
            .setSmallIcon(android.R.drawable.ic_dialog_info)
            .setPriority(NotificationCompat.PRIORITY_DEFAULT)
            .setAutoCancel(true)
            .setContentIntent(pending)
            .build()
        nm.notify(NOTIFICATION_ID, n)
    }
}

/**
 * Port of the reference MosSurveyActivity + MosSurveyScreen:
 * - a translucent card with the title, five buttons 1–5 and the caption;
 * - auto-dismissed after 8 s;
 * - outside the recents list.
 *
 * Built with plain Views, so it needs no Compose dependency and no Flutter engine to appear
 * over other apps. The tap gets a responseId generated at tap time and is committed to
 * CollectorPrefs before the activity finishes. Dart picks it up from there.
 */
class MosSurveyActivity : Activity() {
    private val handler = Handler(Looper.getMainLooper())
    private val autoDismiss = Runnable { finish() }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        val trigger = intent.getStringExtra(EXTRA_TRIGGER) ?: "PERIODIC"
        val promptedAt = intent.getLongExtra(EXTRA_PROMPTED_AT, -1).takeIf { it > 0 }
        val mode = intent.getStringExtra(EXTRA_MODE) ?: "OVERLAY"
        setContentView(buildContent { score -> onScore(score, trigger, promptedAt, mode) })
        handler.postDelayed(autoDismiss, AUTO_DISMISS_MS)
    }

    private fun onScore(score: Int, trigger: String, promptedAt: Long?, mode: String) {
        handler.removeCallbacks(autoDismiss)
        CollectorPrefs(this).appendAnswer(
            SurveyAnswerMessage(
                responseId = UUID.randomUUID().toString(),
                score = score.toLong(),
                triggerType = trigger,
                tapMs = System.currentTimeMillis(),
                promptedAtMs = promptedAt,
                presentationMode = mode,
            ),
        )
        finish()
    }

    override fun onDestroy() {
        handler.removeCallbacks(autoDismiss)
        super.onDestroy()
    }

    private fun dp(v: Int) = TypedValue.applyDimension(TypedValue.COMPLEX_UNIT_DIP, v.toFloat(), resources.displayMetrics).toInt()

    private fun buildContent(onScore: (Int) -> Unit): FrameLayout {
        val card = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER_HORIZONTAL
            setPadding(dp(20), dp(20), dp(20), dp(16))
            background = GradientDrawable().apply {
                cornerRadius = dp(16).toFloat()
                setColor(Color.WHITE)
            }
            elevation = dp(8).toFloat()
        }
        card.addView(
            TextView(this).apply {
                text = getString(R.string.mos_survey_title)
                setTextColor(Color.BLACK)
                setTextSize(TypedValue.COMPLEX_UNIT_SP, 18f)
                gravity = Gravity.CENTER
            },
        )
        val row = LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
            setPadding(0, dp(16), 0, dp(8))
        }
        for (score in 1..5) {
            row.addView(
                Button(this).apply {
                    text = score.toString()
                    contentDescription = score.toString()
                    setOnClickListener { onScore(score) }
                },
                LinearLayout.LayoutParams(0, WRAP_CONTENT, 1f).apply { marginStart = dp(2); marginEnd = dp(2) },
            )
        }
        card.addView(row, LinearLayout.LayoutParams(MATCH_PARENT, WRAP_CONTENT))
        card.addView(
            TextView(this).apply {
                text = getString(R.string.mos_survey_caption)
                setTextColor(Color.DKGRAY)
                setTextSize(TypedValue.COMPLEX_UNIT_SP, 13f)
                gravity = Gravity.CENTER
            },
        )
        return FrameLayout(this).apply {
            setBackgroundColor(Color.parseColor("#66000000"))
            setOnClickListener { finish() } // tap outside = dismiss, as in the reference
            addView(card, FrameLayout.LayoutParams(MATCH_PARENT, WRAP_CONTENT, Gravity.CENTER).apply {
                marginStart = dp(24)
                marginEnd = dp(24)
            })
            card.isClickable = true // taps on the card don't fall through to "dismiss"
        }
    }

    companion object {
        private const val EXTRA_TRIGGER = "trigger_type"
        private const val EXTRA_PROMPTED_AT = "prompted_at_ms"
        private const val EXTRA_MODE = "presentation_mode"
        private const val AUTO_DISMISS_MS = 8_000L

        fun intent(context: Context, trigger: String, promptedAtMs: Long, mode: String) =
            Intent(context, MosSurveyActivity::class.java).apply {
                putExtra(EXTRA_TRIGGER, trigger)
                putExtra(EXTRA_PROMPTED_AT, promptedAtMs)
                putExtra(EXTRA_MODE, mode)
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or
                    Intent.FLAG_ACTIVITY_EXCLUDE_FROM_RECENTS or
                    Intent.FLAG_ACTIVITY_NO_HISTORY
            }
    }
}

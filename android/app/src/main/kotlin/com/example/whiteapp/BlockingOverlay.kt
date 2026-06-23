package com.example.whiteapp

import android.content.Context
import android.graphics.Color
import android.graphics.PixelFormat
import android.os.Build
import android.view.Gravity
import android.view.LayoutInflater
import android.view.View
import android.view.WindowManager
import android.widget.Button
import android.widget.LinearLayout
import android.widget.TextView

object BlockingOverlay {
    private var overlayView: View? = null
    private var windowManager: WindowManager? = null

    fun show(context: Context, triggeringClass: String, onDismiss: () -> Unit) {
        if (overlayView != null) return

        try {
            val wm = context.getSystemService(Context.WINDOW_SERVICE) as WindowManager
            windowManager = wm

            // Create a sleek full-screen dark container
            val layoutParams = WindowManager.LayoutParams().apply {
                width = WindowManager.LayoutParams.MATCH_PARENT
                height = WindowManager.LayoutParams.MATCH_PARENT
                type = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
                } else {
                    @Suppress("DEPRECATION")
                    WindowManager.LayoutParams.TYPE_PHONE
                }
                flags = WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
                        WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN or
                        WindowManager.LayoutParams.FLAG_LAYOUT_NO_LIMITS
                format = PixelFormat.TRANSLUCENT
            }

            // Programmatic layout construction for maximum premium feel without requiring complex XML resource syncing
            val container = LinearLayout(context).apply {
                orientation = LinearLayout.VERTICAL
                gravity = Gravity.CENTER
                setBackgroundColor(Color.parseColor("#E0000000")) // sleek 88% black semi-transparent
                setPadding(50, 50, 50, 50)
            }

            val titleView = TextView(context).apply {
                text = "Shield Activated"
                textSize = 28f
                setTextColor(Color.WHITE)
                gravity = Gravity.CENTER
                setPadding(0, 0, 0, 20)
            }

            val descView = TextView(context).apply {
                text = "Explicit visual content detected: $triggeringClass\nWhiteApp blocked this screen for your safety."
                textSize = 16f
                setTextColor(Color.parseColor("#CCCCCC"))
                gravity = Gravity.CENTER
                setPadding(0, 0, 0, 50)
            }

            val backButton = Button(context).apply {
                text = "Go Back Safely"
                setBackgroundColor(Color.parseColor("#10B981")) // Emerald Green brand color
                setTextColor(Color.WHITE)
                textSize = 16f
                setPadding(30, 20, 30, 20)
                setOnClickListener {
                    dismiss()
                    onDismiss()
                }
            }

            container.addView(titleView)
            container.addView(descView)
            container.addView(backButton)

            overlayView = container
            wm.addView(container, layoutParams)
        } catch (e: Exception) {
            android.util.Log.e("BlockingOverlay", "Error showing overlay: ${e.message}")
        }
    }

    fun dismiss() {
        try {
            overlayView?.let {
                windowManager?.removeView(it)
            }
        } catch (e: Exception) {
            // silent ignore
        } finally {
            overlayView = null
            windowManager = null
        }
    }

    fun isShowing(): Boolean = overlayView != null
}

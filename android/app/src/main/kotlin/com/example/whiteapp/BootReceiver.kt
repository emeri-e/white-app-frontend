package com.example.whiteapp

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log

class BootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action == Intent.ACTION_BOOT_COMPLETED) {
            Log.d("BootReceiver", "Device boot completed. Re-initializing bodyguard layers...")
            
            // Re-initialize local VPN filtering
            val vpnIntent = Intent(context, WhiteVpnService::class.java).apply {
                action = "START"
            }
            context.startService(vpnIntent)

            // Re-initialize gallery scanner
            CameraRollMonitor.restoreMonitoringState(context)
        }
    }
}

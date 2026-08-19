package com.tabletdroid.guestagent

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log

class BootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action == Intent.ACTION_BOOT_COMPLETED ||
            intent.action == Intent.ACTION_LOCKED_BOOT_COMPLETED) {
            Log.i("TabletDroidGuestAgent", "Boot completed received. Starting GuestService...")
            val serviceIntent = Intent(context, GuestService::class.java)
            context.startService(serviceIntent)
        }
    }
}

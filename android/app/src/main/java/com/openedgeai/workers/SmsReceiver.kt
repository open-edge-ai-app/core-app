package com.openedgeai.workers

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.provider.Telephony
import com.openedgeai.core.MemoryIndexer
import com.openedgeai.db.VectorDBHelper
import java.util.concurrent.Executors

class SmsReceiver : BroadcastReceiver() {
    override fun onReceive(
        context: Context,
        intent: Intent,
    ) {
        if (intent.action != Telephony.Sms.Intents.SMS_RECEIVED_ACTION) {
            return
        }

        val pendingResult = goAsync()
        val appContext = context.applicationContext
        EXECUTOR.execute {
            val messages = Telephony.Sms.Intents.getMessagesFromIntent(intent)
            val indexer = MemoryIndexer(appContext, VectorDBHelper(appContext))
            try {
                messages.forEach { message ->
                    indexer.indexIncomingSms(
                        address = message.originatingAddress,
                        body = message.messageBody,
                        timestamp = message.timestampMillis,
                    )
                }
            } finally {
                indexer.close()
                pendingResult.finish()
            }
        }
    }

    companion object {
        private val EXECUTOR = Executors.newSingleThreadExecutor()
    }
}

package com.crystal_messenger.app.features.calls

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.lifecycle.lifecycleScope
import com.crystal_messenger.app.CrystalApp
import com.crystal_messenger.app.di.AppContainer
import com.crystal_messenger.app.services.CallService
import com.crystal_messenger.app.ui.theme.CRYSTAL_MESSENGERTheme
import kotlinx.coroutines.launch

class IncomingCallActivity : ComponentActivity() {

    companion object {
        const val EXTRA_CALL_ID = "call_id"
        const val EXTRA_NAME = "name"
        const val EXTRA_AVATAR = "avatar"
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        val container = (application as CrystalApp).container
        val callId = intent.getStringExtra(EXTRA_CALL_ID) ?: run { finish(); return }
        val name = intent.getStringExtra(EXTRA_NAME) ?: "Unknown"
        val avatar = intent.getStringExtra(EXTRA_AVATAR)

        var callerId = intent.getStringExtra("targetUserId") ?: ""
        lifecycleScope.launch {
            callerId = container.db.callDao().get(callId)?.callerId ?: callerId
        }
        val targetUserId = intent.getStringExtra("targetUserId") ?: ""

        setContent {
            CRYSTAL_MESSENGERTheme {
                IncomingCallCard(
                    callId = callId,
                    name = name,
                    avatarUrl = avatar,
onAnswer = {
                        startActivity(
                            CallActivity.incomingIntent(this, callId, name, avatar, "audio", callerId)
                        )
                        finish()
                    },
                    onDecline = {
                        lifecycleScope.launch {
                            container.chatRepository.updateCallStatus(callId, "declined")
                            CallService.stop(this@IncomingCallActivity)
                            finish()
                        }
                    }
                )
            }
        }
    }
}
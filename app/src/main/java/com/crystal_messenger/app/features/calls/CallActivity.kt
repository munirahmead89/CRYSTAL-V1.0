package com.crystal_messenger.app.features.calls

import android.content.Context
import android.content.Intent
import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import com.crystal_messenger.app.CrystalApp
import com.crystal_messenger.app.di.AppContainer
import com.crystal_messenger.app.services.CallService
import com.crystal_messenger.app.ui.theme.CRYSTAL_MESSENGERTheme

/**
 * Full-screen call UI. Intent extras:
 *  - EXTRA_CALL_ID
 *  - EXTRA_NAME
 *  - EXTRA_AVATAR
 *  - EXTRA_INCOMING (boolean)
 *  - EXTRA_KIND     ("audio" | "video")
 */
class CallActivity : ComponentActivity() {

    companion object {
        const val EXTRA_CALL_ID = "call_id"
        const val EXTRA_NAME = "name"
        const val EXTRA_AVATAR = "avatar"
        const val EXTRA_INCOMING = "incoming"
        const val EXTRA_KIND = "kind"

        fun outgoingIntent(
            context: Context,
            callId: String,
            name: String,
            avatar: String?,
            kind: String,
            targetUserId: String
        ): Intent = Intent(context, CallActivity::class.java).apply {
            putExtra(EXTRA_CALL_ID, callId)
            putExtra(EXTRA_NAME, name)
            putExtra(EXTRA_AVATAR, avatar)
            putExtra(EXTRA_INCOMING, false)
            putExtra(EXTRA_KIND, kind)
            putExtra("targetUserId", targetUserId)
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP)
        }

        fun incomingIntent(
            context: Context,
            callId: String,
            name: String,
            avatar: String?,
            kind: String = "audio",
            targetUserId: String
        ): Intent = Intent(context, CallActivity::class.java).apply {
            putExtra(EXTRA_CALL_ID, callId)
            putExtra(EXTRA_NAME, name)
            putExtra(EXTRA_AVATAR, avatar)
            putExtra(EXTRA_INCOMING, true)
            putExtra(EXTRA_KIND, kind)
            putExtra("targetUserId", targetUserId)
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP)
        }
    }

    private var webRtcManager: com.crystal_messenger.app.core.webrtc.WebRtcManager? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        val container = (application as CrystalApp).container
        val callId = intent.getStringExtra(EXTRA_CALL_ID) ?: run { finish(); return }
        val name = intent.getStringExtra(EXTRA_NAME) ?: "Unknown"
        val avatar = intent.getStringExtra(EXTRA_AVATAR)
        val incoming = intent.getBooleanExtra(EXTRA_INCOMING, false)
        val kind = intent.getStringExtra(EXTRA_KIND) ?: "audio"
        val isVideo = kind == "video"

        val meId = kotlinx.coroutines.runBlocking { container.sessionManager.current().userId.orEmpty() }
        val signalingClient = com.crystal_messenger.app.core.webrtc.WebRtcSignalingClient(callId, meId, container.realtime)
        // Note: targetUserId is needed for signaling, we'll try to extract it from the repository if possible, or assume it's part of the intent. 
        // For now, we will assume it's passed or handled differently, but since we need it for WebRTC:
        val targetUserId = intent.getStringExtra("targetUserId") ?: ""

        webRtcManager = com.crystal_messenger.app.core.webrtc.WebRtcManager(
            context = this,
            signalingClient = signalingClient,
            targetUserId = targetUserId,
            isVideoCall = isVideo
        )

        CallService.start(this, callId, name, avatar)

        setContent {
            CRYSTAL_MESSENGERTheme {
                CallScreen(
                    container = container,
                    callId = callId,
                    name = name,
                    avatarUrl = avatar,
                    incoming = incoming,
                    kind = kind,
                    webRtcManager = webRtcManager,
                    signalingClient = signalingClient,
                    onFinish = {
                        webRtcManager?.stop()
                        CallService.stop(this)
                        finish()
                    }
                )
            }
        }
    }

    override fun onDestroy() {
        super.onDestroy()
        webRtcManager?.stop()
    }

    override fun onStart() {
        super.onStart()
    }
}
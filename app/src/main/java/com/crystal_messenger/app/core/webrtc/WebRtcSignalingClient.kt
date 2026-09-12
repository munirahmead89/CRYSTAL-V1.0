package com.crystal_messenger.app.core.webrtc

import com.crystal_messenger.app.core.supabase.RealtimeClient
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.flow.MutableSharedFlow
import kotlinx.coroutines.flow.SharedFlow
import kotlinx.coroutines.flow.asSharedFlow
import kotlinx.coroutines.flow.filter
import kotlinx.coroutines.launch
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.buildJsonObject
import kotlinx.serialization.json.jsonObject
import kotlinx.serialization.json.jsonPrimitive
import kotlinx.serialization.json.put

class WebRtcSignalingClient(
    private val callId: String,
    private val myUserId: String,
    private val realtimeClient: RealtimeClient
) {
    private val scope = CoroutineScope(Dispatchers.IO + Job())

    private val _offers = MutableSharedFlow<JsonObject>()
    val offers: SharedFlow<JsonObject> = _offers.asSharedFlow()

    private val _answers = MutableSharedFlow<JsonObject>()
    val answers: SharedFlow<JsonObject> = _answers.asSharedFlow()

    private val _iceCandidates = MutableSharedFlow<JsonObject>()
    val iceCandidates: SharedFlow<JsonObject> = _iceCandidates.asSharedFlow()

    init {
        scope.launch {
            realtimeClient.broadcasts
                .filter { it["event"]?.jsonPrimitive?.content == "webrtc_signal" }
                .collect { root ->
                    val outerPayload = root["payload"]?.jsonObject ?: return@collect
                    val payload = outerPayload["payload"]?.jsonObject ?: return@collect

                    val msgCallId = payload["call_id"]?.jsonPrimitive?.content
                    val targetId = payload["target_id"]?.jsonPrimitive?.content
                    val senderId = payload["sender_id"]?.jsonPrimitive?.content
                    val type = payload["type"]?.jsonPrimitive?.content

                    if (msgCallId == callId && targetId == myUserId && senderId != myUserId) {
                        when (type) {
                            "offer" -> _offers.emit(payload)
                            "answer" -> _answers.emit(payload)
                            "ice" -> _iceCandidates.emit(payload)
                        }
                    }
                }
        }
    }

    fun sendOffer(sdp: String, targetId: String) {
        val payload = buildJsonObject {
            put("call_id", callId)
            put("sender_id", myUserId)
            put("target_id", targetId)
            put("type", "offer")
            put("sdp", sdp)
        }
        realtimeClient.broadcast("webrtc_signal", payload)
    }

    fun sendAnswer(sdp: String, targetId: String) {
        val payload = buildJsonObject {
            put("call_id", callId)
            put("sender_id", myUserId)
            put("target_id", targetId)
            put("type", "answer")
            put("sdp", sdp)
        }
        realtimeClient.broadcast("webrtc_signal", payload)
    }

    fun sendIceCandidate(sdpMid: String, sdpMLineIndex: Int, sdp: String, targetId: String) {
        val payload = buildJsonObject {
            put("call_id", callId)
            put("sender_id", myUserId)
            put("target_id", targetId)
            put("type", "ice")
            put("sdpMid", sdpMid)
            put("sdpMLineIndex", sdpMLineIndex)
            put("sdp", sdp)
        }
        realtimeClient.broadcast("webrtc_signal", payload)
    }
}

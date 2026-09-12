package com.crystal_messenger.app.features.calls

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.Call
import androidx.compose.material.icons.rounded.CallEnd
import androidx.compose.material.icons.rounded.Mic
import androidx.compose.material.icons.rounded.MicOff
import androidx.compose.material.icons.rounded.VolumeUp
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableLongStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.crystal_messenger.app.di.AppContainer
import com.crystal_messenger.app.ui.components.CrystalAvatar
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.serialization.json.jsonPrimitive
import org.webrtc.VideoTrack

@Composable
fun CallScreen(
    container: AppContainer,
    callId: String,
    name: String,
    avatarUrl: String?,
    incoming: Boolean,
    kind: String,
    webRtcManager: com.crystal_messenger.app.core.webrtc.WebRtcManager?,
    signalingClient: com.crystal_messenger.app.core.webrtc.WebRtcSignalingClient?,
    onFinish: () -> Unit
) {
    val context = LocalContext.current
    var answered by remember { mutableStateOf(!incoming) }
    var muted by remember { mutableStateOf(false) }
    var speaker by remember { mutableStateOf(false) }
    var seconds by remember { mutableLongStateOf(0L) }

    val localVideoTrack by (webRtcManager?.localVideoTrack ?: MutableStateFlow<VideoTrack?>(null)).collectAsStateWithLifecycle()
    val remoteVideoTrack by (webRtcManager?.remoteVideoTrack ?: MutableStateFlow<VideoTrack?>(null)).collectAsStateWithLifecycle()

    LaunchedEffect(answered) {
        if (!answered) return@LaunchedEffect
        if (!incoming) {
            webRtcManager?.startCall()
        }
        while (true) {
            delay(1000)
            seconds++
        }
    }

    LaunchedEffect(signalingClient) {
        signalingClient?.offers?.collect { offer ->
            if (incoming) {
                webRtcManager?.answerCall(offer["sdp"]?.jsonPrimitive?.content ?: "")
            }
        }
    }
    LaunchedEffect(signalingClient) {
        signalingClient?.answers?.collect { answer ->
            webRtcManager?.handleAnswer(answer["sdp"]?.jsonPrimitive?.content ?: "")
        }
    }
    LaunchedEffect(signalingClient) {
        signalingClient?.iceCandidates?.collect { ice ->
            webRtcManager?.handleIceCandidate(
                ice["sdpMid"]?.jsonPrimitive?.content ?: "",
                ice["sdpMLineIndex"]?.jsonPrimitive?.content?.toInt() ?: 0,
                ice["sdp"]?.jsonPrimitive?.content ?: ""
            )
        }
    }

    Box(
        modifier = Modifier
            .fillMaxSize()
            .background(Brush.verticalGradient(listOf(Color(0xFF0B141A), Color(0xFF10221A)))),
        contentAlignment = Alignment.Center
    ) {
        if (kind == "video" && answered) {
            // Remote Video Fullscreen
            remoteVideoTrack?.let { track ->
                androidx.compose.ui.viewinterop.AndroidView(
                    factory = { ctx ->
                        org.webrtc.SurfaceViewRenderer(ctx).apply {
                            webRtcManager?.eglBaseContext?.let { eglContext ->
                                init(eglContext, null)
                            }
                            setScalingType(org.webrtc.RendererCommon.ScalingType.SCALE_ASPECT_FILL)
                            setEnableHardwareScaler(true)
                            track.addSink(this)
                        }
                    },
                    modifier = Modifier.fillMaxSize()
                )
            }
            
            // Local Video PIP
            localVideoTrack?.let { track ->
                Box(modifier = Modifier.fillMaxSize()) {
                    androidx.compose.ui.viewinterop.AndroidView(
                        factory = { ctx ->
                            org.webrtc.SurfaceViewRenderer(ctx).apply {
                                webRtcManager?.eglBaseContext?.let { eglContext ->
                                    init(eglContext, null)
                                }
                                setScalingType(org.webrtc.RendererCommon.ScalingType.SCALE_ASPECT_FILL)
                                setEnableHardwareScaler(true)
                                setZOrderMediaOverlay(true)
                                setMirror(true)
                                track.addSink(this)
                            }
                        },
                        modifier = Modifier
                            .align(Alignment.BottomEnd)
                            .padding(bottom = 120.dp, end = 16.dp)
                            .width(100.dp)
                            .height(150.dp)
                            .clip(androidx.compose.foundation.shape.RoundedCornerShape(8.dp))
                    )
                }
            }
        }
        Column(horizontalAlignment = Alignment.CenterHorizontally, modifier = Modifier.fillMaxWidth()) {
            CrystalAvatar(url = avatarUrl, name = name, size = 132.dp, online = true)
            Spacer(Modifier.height(28.dp))
            Text(name, color = Color.White, style = MaterialTheme.typography.headlineSmall, fontWeight = FontWeight.Bold)
            Spacer(Modifier.height(10.dp))
            Text(
                text = when {
                    answered -> formatDuration(seconds)
                    incoming -> "Incoming $kind call…"
                    else -> "Calling…"
                },
                color = Color(0xFFB3C2C9),
                style = MaterialTheme.typography.bodyLarge
            )

            Spacer(Modifier.height(70.dp))

            if (answered) {
                Row(
                    horizontalArrangement = Arrangement.spacedBy(36.dp),
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    val micIcon = if (muted) Icons.Rounded.MicOff else Icons.Rounded.Mic
                    CallControl(micIcon, label = if (muted) "Unmute" else "Mute") { muted = !muted }
                    Surface(
                        shape = CircleShape,
                        color = Color(0xFFF15C6D),
                        modifier = Modifier.size(64.dp),
                        onClick = {
                            container.chatRepository.updateCallStatus(callId, "completed", seconds.toInt())
                            com.crystal_messenger.app.services.CallService.stop(context)
                            onFinish()
                        }
                    ) {
                        Box(contentAlignment = Alignment.Center) {
                            Icon(Icons.Rounded.CallEnd, contentDescription = "End", tint = Color.White, modifier = Modifier.size(30.dp))
                        }
                    }
                    CallControl(Icons.Rounded.VolumeUp, label = "Speaker") { speaker = !speaker }
                }
                Spacer(Modifier.height(20.dp))
                Text(
                    "Ending the call will hang up.",
                    color = Color(0xFF667781),
                    style = MaterialTheme.typography.labelMedium
                )
            } else {
                Column(horizontalAlignment = Alignment.CenterHorizontally) {
                    Row(horizontalArrangement = Arrangement.spacedBy(40.dp)) {
                        Surface(
                            shape = CircleShape,
                            color = Color(0xFFF15C6D),
                            modifier = Modifier.size(72.dp),
                            onClick = {
                                container.chatRepository.updateCallStatus(callId, "declined")
                                onFinish()
                            }
                        ) {
                            Box(contentAlignment = Alignment.Center) {
                                Icon(Icons.Rounded.CallEnd, contentDescription = "Decline", tint = Color.White, modifier = Modifier.size(34.dp))
                            }
                        }
                        Surface(
                            shape = CircleShape,
                            color = Color(0xFF25D366),
                            modifier = Modifier.size(72.dp),
                            onClick = {
                                container.chatRepository.updateCallStatus(callId, "answered")
                                answered = true
                            }
                        ) {
                            Box(contentAlignment = Alignment.Center) {
                                Icon(Icons.Rounded.Call, contentDescription = "Answer", tint = Color.White, modifier = Modifier.size(34.dp))
                            }
                        }
                    }
                    Spacer(Modifier.height(14.dp))
                    Text(answerHint(incoming), color = Color(0xFF667781), style = MaterialTheme.typography.labelMedium)
                }
            }

            Spacer(Modifier.height(40.dp))
        }
    }
}

private fun mutedTo(muted: Boolean) = if (muted) Icons.Rounded.MicOff else Icons.Rounded.Mic

private fun answerHint(incoming: Boolean) = if (incoming) "Answer or decline" else "Waiting for the other side…"

private fun formatDuration(totalSeconds: Long): String {
    val s = totalSeconds % 60
    val m = totalSeconds / 60
    return "%02d:%02d".format(m, s)
}

@Composable
private fun CallControl(icon: androidx.compose.ui.graphics.vector.ImageVector, label: String, onClick: () -> Unit) {
    Column(horizontalAlignment = Alignment.CenterHorizontally) {
        Surface(shape = CircleShape, color = Color(0xFF39434A), modifier = Modifier.size(56.dp), onClick = onClick) {
            Box(contentAlignment = Alignment.Center) {
                Icon(icon, contentDescription = label, tint = Color.White, modifier = Modifier.size(26.dp))
            }
        }
        Spacer(Modifier.height(6.dp))
        Text(label, color = Color(0xFFB3C2C9), style = MaterialTheme.typography.labelMedium)
    }
}
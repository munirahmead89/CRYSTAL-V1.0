package com.crystal_messenger.app.features.chats

import android.content.Context
import android.media.MediaPlayer
import android.net.Uri
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.PickVisualMediaRequest
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.AccessTime
import androidx.compose.material.icons.rounded.ArrowBack
import androidx.compose.material.icons.rounded.Check
import androidx.compose.material.icons.rounded.DoneAll
import androidx.compose.material.icons.rounded.GalleryThumbnail
import androidx.compose.material.icons.rounded.Mic
import androidx.compose.material.icons.rounded.MoreVert
import androidx.compose.material.icons.rounded.PhotoCamera
import androidx.compose.material.icons.rounded.Place
import androidx.compose.material.icons.rounded.Videocam
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.material3.TopAppBar
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.ui.window.Dialog
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.lifecycle.viewmodel.compose.viewModel
import coil.compose.AsyncImage
import com.crystal_messenger.app.di.AppContainer
import com.crystal_messenger.app.ui.components.CrystalAvatar
import com.crystal_messenger.app.ui.components.formatTime
import com.crystal_messenger.app.ui.theme.IncomingBubble
import com.crystal_messenger.app.ui.theme.OutgoingBubble

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun ChatDetailScreen(
    container: AppContainer,
    conversationId: String,
    onBack: () -> Unit,
    onOpenCamera: (String) -> Unit,
    onOpenContact: (String) -> Unit
) {
    val context = LocalContext.current
    val vm: ChatDetailViewModel = viewModel(key = "chat_$conversationId") {
        ChatDetailViewModel(container, conversationId)
    }
    val messages by vm.messages.collectAsStateWithLifecycle()
    val state by vm.state.collectAsStateWithLifecycle()

    val listState = rememberLazyListState()
    var showAttach by remember { mutableStateOf(false) }
    var viewingImage by remember { mutableStateOf<String?>(null) }
    var replyTo by remember { mutableStateOf<MessageEntity?>(null) }

    LaunchedEffect(messages.size, messages.lastOrNull()?.id) {
        if (messages.isNotEmpty()) listState.animateScrollToItem(messages.size - 1)
        vm.onMessageVisible()
    }
    LaunchedEffect(Unit) { vm.markRead() }

    val gallery = rememberLauncherForActivityResult(ActivityResultContracts.PickVisualMedia()) { uri ->
        uri?.let { vm.sendMedia(it, contentTypeOf(context, it)) }
    }

    val recordPermission = com.google.accompanist.permissions.rememberPermissionState(
        android.Manifest.permission.RECORD_AUDIO
    )

    Scaffold(
        containerColor = MaterialTheme.colorScheme.background,
        topBar = {
            TopAppBar(
                title = {
                    Row(
                        modifier = Modifier
                            .clip(RoundedCornerShape(8.dp))
                            .clickable { onOpenContact(state.peerId.orEmpty()) },
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        CrystalAvatar(
                            url = state.avatarUrl,
                            name = state.title,
                            size = 38.dp,
                            online = state.online
                        )
                        Spacer(Modifier.width(10.dp))
                        Column {
                            Text(
                                state.title,
                                style = MaterialTheme.typography.bodyLarge,
                                fontWeight = FontWeight.SemiBold,
                                maxLines = 1,
                                overflow = TextOverflow.Ellipsis
                            )
                            Text(
                                text = when {
                                    state.typingPeer -> "typing…"
                                    state.online -> "online"
                                    else -> "last seen recently"
                                },
                                style = MaterialTheme.typography.labelMedium,
                                color = if (state.typingPeer) MaterialTheme.colorScheme.primary else MaterialTheme.colorScheme.onSurfaceVariant
                            )
                        }
                    }
                },
                navigationIcon = {
                    IconButton(onClick = onBack) { Icon(Icons.Rounded.ArrowBack, "Back") }
                },
                actions = {
                    IconButton(onClick = { onOpenContact(state.peerId.orEmpty()) }) {
                        Icon(Icons.Rounded.MoreVert, "Info")
                    }
                }
            )
        },
        bottomBar = {
            val isRecording by vm.isRecording.collectAsStateWithLifecycle()
            MessageInputBar(
                onSend = { text ->
                    if (replyTo != null) vm.sendReplyTo(replyTo!!, text) else vm.sendText(text)
                    replyTo = null
                },
                onAttach = { showAttach = true },
                onChanged = { vm.onTypingChange(it.isNotBlank()) },
                onRecordStart = {
                    if (recordPermission.status.isGranted) {
                        vm.startVoiceNote(context)
                    } else {
                        recordPermission.launchPermissionRequest()
                    }
                },
                onRecordStop = { vm.stopVoiceNoteAndSend() },
                isRecording = isRecording
            )
        }
    ) { padding ->
        Box(Modifier.fillMaxSize().padding(padding)) {
            LazyColumn(
                state = listState,
                modifier = Modifier.fillMaxSize(),
                contentPadding = PaddingValues(horizontal = 10.dp, vertical = 8.dp),
                verticalArrangement = Arrangement.spacedBy(4.dp)
            ) {
                items(messages, key = { it.id }) { msg ->
                    MessageBubble(
                        msg = msg,
                        outgoing = msg.senderId == state.meId,
                        onImageClick = { viewingImage = it }
                    )
                }
            }
        }
    }

    if (showAttach) {
        ModalBottomSheet(
            onDismissRequest = { showAttach = false },
            containerColor = MaterialTheme.colorScheme.surface
        ) {
            Column(Modifier.fillMaxWidth().padding(bottom = 24.dp)) {
                Row(
                    Modifier.fillMaxWidth().padding(vertical = 8.dp),
                    horizontalArrangement = Arrangement.SpaceEvenly
                ) {
                    AttachAction("Gallery", Icons.Rounded.GalleryThumbnail) {
                        gallery.launch(PickVisualMediaRequest(ActivityResultContracts.PickVisualMedia.ImageAndVideo))
                        showAttach = false
                    }
                    AttachAction("Camera", Icons.Rounded.PhotoCamera) {
                        showAttach = false
                        onOpenCamera(conversationId)
                    }
                    AttachAction("Location", Icons.Rounded.Place) {
                        showAttach = false
                        vm.sendText("📍 Location • https://maps.google.com/?q=0,0")
                    }
                }
                Spacer(Modifier.height(8.dp))
            }
        }
    }

    viewingImage?.let { url ->
        Dialog(onDismissRequest = { viewingImage = null }) {
            AsyncImage(
                model = url,
                contentDescription = null,
                modifier = Modifier
                    .fillMaxWidth()
                    .clip(RoundedCornerShape(16.dp)),
                contentScale = ContentScale.Fit
            )
        }
    }
}

private fun contentTypeOf(context: Context, uri: Uri): String =
    context.contentResolver.getType(uri) ?: "image/jpeg"

@Composable
private fun AttachAction(label: String, icon: androidx.compose.ui.graphics.vector.ImageVector, onClick: () -> Unit) {
    Column(horizontalAlignment = Alignment.CenterHorizontally, modifier = Modifier.clickable(onClick = onClick)) {
        Surface(
            shape = RoundedCornerShape(16.dp),
            color = MaterialTheme.colorScheme.surfaceVariant,
            modifier = Modifier.size(56.dp)
        ) {
            Box(contentAlignment = Alignment.Center) {
                Icon(icon, contentDescription = label, tint = MaterialTheme.colorScheme.primary)
            }
        }
        Spacer(Modifier.height(6.dp))
        Text(label, style = MaterialTheme.typography.labelMedium)
    }
}

@Composable
fun MessageBubble(
    msg: MessageEntity,
    outgoing: Boolean,
    onImageClick: (String) -> Unit
) {
    val bubbleColor = if (outgoing) OutgoingBubble else IncomingBubble
    Row(
        modifier = Modifier.fillMaxWidth(),
        horizontalArrangement = if (outgoing) Arrangement.End else Arrangement.Start
    ) {
        Column(
            modifier = Modifier
                .widthIn(max = 300.dp)
                .clip(
                    RoundedCornerShape(
                        topStart = 14.dp, topEnd = 14.dp,
                        bottomStart = if (outgoing) 14.dp else 3.dp,
                        bottomEnd = if (outgoing) 3.dp else 14.dp
                    )
                )
                .background(bubbleColor)
                .padding(8.dp)
        ) {
            if (msg.replyToId != null) {
                Surface(
                    color = if (outgoing) Color(0xFF075E54) else Color(0xFF111B21),
                    shape = RoundedCornerShape(6.dp),
                    modifier = Modifier.fillMaxWidth().padding(bottom = 4.dp)
                ) {
                    Text(
                        "Reply\n" + (msg.replyToBody ?: "…"),
                        style = MaterialTheme.typography.labelMedium,
                        color = Color.White,
                        maxLines = 3,
                        overflow = TextOverflow.Ellipsis,
                        modifier = Modifier.padding(6.dp)
                    )
                }
            }
            when {
                msg.mtype == "image" && msg.mediaUrl != null -> {
                    AsyncImage(
                        model = msg.mediaUrl,
                        contentDescription = null,
                        contentScale = ContentScale.Crop,
                        modifier = Modifier
                            .fillMaxWidth()
                            .widthIn(max = 280.dp)
                            .height(240.dp)
                            .clip(RoundedCornerShape(8.dp))
                            .clickable { onImageClick(msg.mediaUrl) }
                    )
                    if (!msg.body.isNullOrBlank()) {
                        Spacer(Modifier.height(4.dp))
                        Text(msg.body, color = Color.White, style = MaterialTheme.typography.bodyMedium)
                    }
                }
                msg.mtype == "video" && msg.mediaUrl != null -> {
                    Box(
                        contentAlignment = Alignment.Center,
                        modifier = Modifier.size(width = 200.dp, height = 120.dp)
                    ) {
                        AsyncImage(
                            model = msg.mediaThumb ?: msg.mediaUrl,
                            contentDescription = null,
                            contentScale = ContentScale.Crop,
                            modifier = Modifier.matchParentSize().clip(RoundedCornerShape(8.dp))
                        )
                        Icon(Icons.Rounded.Videocam, contentDescription = "Video", tint = Color.White, modifier = Modifier.size(40.dp))
                    }
                }
                msg.mtype == "audio" && msg.mediaUrl != null -> {
                    VoiceMessageRow(url = msg.mediaUrl, duration = msg.mediaDuration)
                }
                msg.mtype == "location" -> {
                    Text("📍 Location", color = Color.White, style = MaterialTheme.typography.bodyMedium)
                }
                else -> {
                    Text(text = msg.body.orEmpty(), style = MaterialTheme.typography.bodyMedium, color = Color.White)
                }
            }
            Row(
                horizontalArrangement = Arrangement.End,
                verticalAlignment = Alignment.Bottom,
                modifier = Modifier.fillMaxWidth().padding(top = 3.dp)
            ) {
                Spacer(Modifier.width(8.dp))
                Text(
                    text = formatTime(msg.createdAt),
                    style = MaterialTheme.typography.labelMedium.copy(fontSize = 10.sp),
                    color = Color(0xFFB3C2C9)
                )
                Spacer(Modifier.width(4.dp))
                if (outgoing) {
                    DeliveryTick(msg)
                }
            }
        }
    }
}

@Composable
private fun DeliveryTick(msg: MessageEntity) {
    val icon = when {
        msg.pendingSync -> Icons.Rounded.AccessTime
        msg.readAt != null || msg.deliveredAt != null -> Icons.Rounded.DoneAll
        else -> Icons.Rounded.Check
    }
    Icon(
        imageVector = icon,
        contentDescription = "status",
        tint = if (msg.readAt != null) MaterialTheme.colorScheme.primary else Color(0xFFB3C2C9),
        modifier = Modifier.size(14.dp)
    )
}

@Composable
fun VoiceMessageRow(url: String, duration: Double?) {
    val context = LocalContext.current
    var player by remember { mutableStateOf<MediaPlayer?>(null) }
    DisposableEffect(Unit) {
        onDispose { player?.release() }
    }
    Row(
        verticalAlignment = Alignment.CenterVertically,
        modifier = Modifier
            .clip(RoundedCornerShape(8.dp))
            .clickable {
                try {
                    val current = player ?: MediaPlayer().apply {
                        setDataSource(url)
                        prepareAsync()
                        setOnPreparedListener { it.start() }
                        setOnCompletionListener { it.release(); player = null }
                    }
                    player = if (current.isPlaying) { current.pause(); null } else current
                } catch (_: Exception) {}
            }
            .padding(4.dp)
    ) {
        Icon(Icons.Rounded.Mic, contentDescription = "voice", tint = Color.White)
        Spacer(Modifier.width(8.dp))
        Text(
            (duration?.toInt()?.toString() ?: "0") + "s • Tap to play",
            color = Color.White,
            style = MaterialTheme.typography.bodyMedium
        )
    }
}
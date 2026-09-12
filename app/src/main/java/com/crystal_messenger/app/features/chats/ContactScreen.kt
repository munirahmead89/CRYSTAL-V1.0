package com.crystal_messenger.app.features.chats

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.ArrowBack
import androidx.compose.material.icons.rounded.Call
import androidx.compose.material.icons.rounded.ChatBubble
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.material3.TopAppBar
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.produceState
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.unit.dp
import com.crystal_messenger.app.core.network.UserDto
import com.crystal_messenger.app.di.AppContainer
import com.crystal_messenger.app.ui.components.CrystalAvatar
import com.crystal_messenger.app.ui.theme.CrystalGreen
import kotlinx.coroutines.launch

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun ContactScreen(
    container: AppContainer,
    userId: String,
    onBack: () -> Unit,
    onOpenChat: (String) -> Unit = {}
) {
    val scope = rememberCoroutineScope()
    val context = LocalContext.current
    val user by produceState<UserDto?>(initialValue = null, key1 = userId) {
        value = container.chatRepository.findUser(userId)
    }

    val u = user

    Scaffold(
        containerColor = MaterialTheme.colorScheme.background,
        topBar = {
            TopAppBar(
                title = { Text("Contact info") },
                navigationIcon = {
                    IconButton(onClick = onBack) { Icon(Icons.Rounded.ArrowBack, "Back") }
                }
            )
        }
    ) { padding ->
        Column(
            Modifier.fillMaxSize().padding(padding).padding(24.dp),
            horizontalAlignment = Alignment.CenterHorizontally
        ) {
            if (u != null) {
                CrystalAvatar(url = u.avatarUrl, name = u.name, size = 108.dp, online = u.status == "online")
                Spacer(Modifier.height(16.dp))
                Text(u.name, style = MaterialTheme.typography.headlineSmall)
                Spacer(Modifier.height(8.dp))
                Text(u.phone, style = MaterialTheme.typography.bodyMedium, color = MaterialTheme.colorScheme.onSurfaceVariant)
                Text(
                    if (u.status == "online") "● online" else "last seen recently",
                    style = MaterialTheme.typography.labelMedium,
                    color = if (u.status == "online") CrystalGreen else MaterialTheme.colorScheme.onSurfaceVariant
                )
                Spacer(Modifier.height(24.dp))
                Text(
                    u.about ?: "Hey there! I am using Crystal Messenger.",
                    style = MaterialTheme.typography.bodyMedium,
                    color = MaterialTheme.colorScheme.onSurfaceVariant
                )
                Spacer(Modifier.height(32.dp))
                Row(horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                    Button(
                        onClick = {
                            scope.launch {
                                val conv = container.chatRepository.createConversation(listOf(u.id))
                                if (conv != null) onOpenChat(conv.id)
                            }
                        },
                        colors = ButtonDefaults.buttonColors(containerColor = CrystalGreen)
                    ) {
                        Icon(Icons.Rounded.ChatBubble, contentDescription = null, tint = Color.White)
                        Spacer(Modifier.size(8.dp))
                        Text("Message", color = Color.White)
                    }
                    Surface(
                        shape = MaterialTheme.shapes.medium,
                        color = MaterialTheme.colorScheme.surfaceVariant,
                        onClick = {
                            com.crystal_messenger.app.features.calls.CallLauncher.startCall(
                                context, container, u.id, u.name, u.avatarUrl, "audio"
                            )
                        }
                    ) {
                        Row(
                            Modifier.padding(horizontal = 20.dp, vertical = 12.dp),
                            verticalAlignment = Alignment.CenterVertically
                        ) {
                            Icon(Icons.Rounded.Call, contentDescription = null, tint = CrystalGreen)
                            Spacer(Modifier.size(8.dp))
                            Text("Call")
                        }
                    }
                }
            } else {
                Text("Loading…", color = MaterialTheme.colorScheme.onSurfaceVariant)
            }
        }
    }
}
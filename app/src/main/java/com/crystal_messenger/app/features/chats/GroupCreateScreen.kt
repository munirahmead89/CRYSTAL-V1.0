package com.crystal_messenger.app.features.chats

import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.ArrowBack
import androidx.compose.material.icons.rounded.Check
import androidx.compose.material.icons.rounded.Done
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TopAppBar
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.produceState
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import com.crystal_messenger.app.core.network.UserDto
import com.crystal_messenger.app.di.AppContainer
import com.crystal_messenger.app.ui.components.CrystalAvatar
import com.crystal_messenger.app.ui.theme.CrystalGreen
import kotlinx.coroutines.launch

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun GroupCreateScreen(
    container: AppContainer,
    onBack: () -> Unit,
    onCreated: (String) -> Unit = {}
) {
    val context = LocalContext.current
    val app = remember { context.applicationContext as com.crystal_messenger.app.CrystalApp }
    val scope = rememberCoroutineScope()

    val users by produceState<List<UserDto>>(initialValue = emptyList()) {
        value = container.chatRepository.allUsers()
    }

    var selected by remember { mutableStateOf<Set<String>>(emptySet()) }
    var groupName by remember { mutableStateOf("") }
    var creating by remember { mutableStateOf(false) }

    Scaffold(
        containerColor = MaterialTheme.colorScheme.background,
        topBar = {
            TopAppBar(
                title = { Text("New group") },
                navigationIcon = {
                    IconButton(onClick = onBack) { Icon(Icons.Rounded.ArrowBack, "Back") }
                }
            )
        },
        bottomBar = {
            Button(
                onClick = {
                    if (creating) return@Button
                    creating = true
                    scope.launch {
                        val conv = container.chatRepository.createConversation(
                            selected.toList(),
                            name = groupName.ifBlank { "Group" },
                            type = "group"
                        )
                        creating = false
                        if (conv != null) onCreated(conv.id)
                    }
                },
                enabled = selected.isNotEmpty(),
                colors = ButtonDefaults.buttonColors(containerColor = CrystalGreen),
                modifier = Modifier.fillMaxWidth().padding(16.dp)
            ) {
                Text(
                    if (creating) "Creating…" else "Create group (${selected.size})",
                    color = Color.White
                )
            }
        }
    ) { padding ->
        Column(Modifier.fillMaxSize().padding(padding)) {
            OutlinedTextField(
                value = groupName,
                onValueChange = { groupName = it },
                label = { Text("Group name") },
                singleLine = true,
                modifier = Modifier.fillMaxWidth().padding(16.dp)
            )
            LazyColumn {
                items(users, key = { it.id }) { user ->
                    val isSel = user.id in selected
                    Row(
                        modifier = Modifier
                            .fillMaxWidth()
                            .clickable {
                                selected = if (isSel) selected - user.id else selected + user.id
                            }
                            .padding(horizontal = 16.dp, vertical = 10.dp),
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        CrystalAvatar(url = user.avatarUrl, name = user.name, size = 44.dp, online = user.status == "online")
                        Spacer(Modifier.size(14.dp))
                        Text(
                            user.name,
                            style = MaterialTheme.typography.bodyLarge,
                            modifier = Modifier.weight(1f),
                            maxLines = 1,
                            overflow = TextOverflow.Ellipsis
                        )
                        if (isSel) {
                            Icon(
                                Icons.Rounded.Check,
                                contentDescription = "selected",
                                tint = CrystalGreen
                            )
                        } else {
                            Icon(
                                Icons.Rounded.Done,
                                contentDescription = null,
                                tint = MaterialTheme.colorScheme.onSurfaceVariant
                            )
                        }
                    }
                }
            }
        }
    }
}
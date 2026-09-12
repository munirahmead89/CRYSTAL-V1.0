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
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.ArrowBack
import androidx.compose.material.icons.rounded.Groups
import androidx.compose.material.icons.rounded.Person
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.material3.TopAppBar
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.produceState
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.lifecycle.viewmodel.compose.viewModel
import com.crystal_messenger.app.CrystalApp
import com.crystal_messenger.app.core.network.UserDto
import com.crystal_messenger.app.di.AppContainer
import com.crystal_messenger.app.ui.components.CrystalAvatar
import com.google.accompanist.permissions.ExperimentalPermissionsApi
import com.google.accompanist.permissions.PermissionStatus
import com.google.accompanist.permissions.rememberPermissionState
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch

@OptIn(ExperimentalMaterial3Api::class, ExperimentalPermissionsApi::class)
@Composable
fun NewChatScreen(
    container: AppContainer,
    onBack: () -> Unit,
    onChatCreated: (String) -> Unit,
    onOpenGroupCreate: () -> Unit
) {
    val context = LocalContext.current
    val app = remember { context.applicationContext as CrystalApp }
    val scope = rememberCoroutineScope()

    val users by produceState<List<UserDto>>(initialValue = emptyList()) {
        value = container.chatRepository.allUsers()
    }

    var query by remember { mutableStateOf("") }
    var creating by remember { mutableStateOf(false) }
    var remoteResults by remember { mutableStateOf<List<UserDto>>(emptyList()) }

    val contactsPermission = rememberPermissionState(android.Manifest.permission.READ_CONTACTS)

    LaunchedEffect(query) {
        if (query.isBlank()) {
            remoteResults = emptyList()
            return@LaunchedEffect
        }
        delay(350)
        val term = query.trim()
        if (term.isBlank()) {
            remoteResults = emptyList()
            return@LaunchedEffect
        }
        remoteResults = container.chatRepository.searchUsersByNameOrPhone(term)
    }

    fun openConversation(userId: String, type: String) {
        if (creating) return
        creating = true
        scope.launch {
            val conv = container.chatRepository.createConversation(listOf(userId), type = type)
            creating = false
            if (conv != null) onChatCreated(conv.id)
        }
    }

    val combined = buildList {
        addAll(users)
        addAll(remoteResults)
    }.distinctBy { it.id }

    val filtered = combined.filter {
        query.isBlank() || it.name.contains(query, ignoreCase = true) || it.phone.contains(query)
    }

    Scaffold(
        containerColor = MaterialTheme.colorScheme.background,
        topBar = {
            TopAppBar(
                title = {
                    OutlinedTextField(
                        value = query,
                        onValueChange = { query = it },
                        placeholder = { Text("Search by name or phone") },
                        singleLine = true,
                        shape = RoundedCornerShape(22.dp),
                        modifier = Modifier.fillMaxWidth()
                    )
                },
                navigationIcon = {
                    IconButton(onClick = onBack) { Icon(Icons.Rounded.ArrowBack, "Back") }
                }
            )
        }
    ) { padding ->
        Column(Modifier.fillMaxSize().padding(padding)) {
            Surface(
                color = MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.4f),
                onClick = onOpenGroupCreate,
                shape = RoundedCornerShape(12.dp),
                modifier = Modifier.padding(12.dp).fillMaxWidth()
            ) {
                Row(
                    Modifier.padding(12.dp),
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Icon(Icons.Rounded.Groups, contentDescription = null, tint = MaterialTheme.colorScheme.primary)
                    Spacer(Modifier.size(12.dp))
                    Text("New group", style = MaterialTheme.typography.bodyLarge, fontWeight = androidx.compose.ui.text.font.FontWeight.SemiBold)
                }
            }

            if (creating) {
                CircularProgressIndicator(Modifier.padding(16.dp))
            } else if (filtered.isEmpty()) {
                Column(
                    Modifier.fillMaxWidth().padding(32.dp),
                    horizontalAlignment = Alignment.CenterHorizontally
                ) {
                    Icon(Icons.Rounded.Person, contentDescription = null, modifier = Modifier.size(48.dp))
                    Spacer(Modifier.size(8.dp))
                    Text(
                        if (users.isEmpty()) "No Crystal users found yet.\nAsk friends to install the app and add your number."
                        else "No matches.",
                        style = MaterialTheme.typography.bodyMedium,
                        color = MaterialTheme.colorScheme.onSurfaceVariant
                    )
                }
            } else {
                LazyColumn {
                    items(filtered, key = { it.id }) { user ->
                        Row(
                            modifier = Modifier
                                .fillMaxWidth()
                                .clickable { openConversation(user.id, "single") }
                                .padding(horizontal = 16.dp, vertical = 10.dp),
                            verticalAlignment = Alignment.CenterVertically
                        ) {
                            CrystalAvatar(
                                url = user.avatarUrl,
                                name = user.name,
                                size = 48.dp,
                                online = user.status == "online"
                            )
                            Spacer(Modifier.size(14.dp))
                            Column(Modifier.weight(1f)) {
                                Text(user.name, style = MaterialTheme.typography.bodyLarge)
                                Text(
                                    user.phone,
                                    style = MaterialTheme.typography.bodyMedium,
                                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                                    maxLines = 1,
                                    overflow = TextOverflow.Ellipsis
                                )
                            }
                        }
                    }
                }
            }
        }
    }
}
package com.crystal_messenger.app.features.calls

import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.Call
import androidx.compose.material.icons.rounded.CallMade
import androidx.compose.material.icons.rounded.CallReceived
import androidx.compose.material.icons.rounded.MissedVideoCall
import androidx.compose.material.icons.rounded.Videocam
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.lifecycle.viewmodel.compose.viewModel
import com.crystal_messenger.app.di.AppContainer
import com.crystal_messenger.app.ui.components.CrystalAvatar
import com.crystal_messenger.app.ui.components.formatTime
import com.crystal_messenger.app.ui.theme.CrystalGreen

@Composable
fun CallsScreen(container: AppContainer) {
    val context = LocalContext.current
    val vm: CallsViewModel = viewModel { CallsViewModel(container) }
    val items by vm.calls.collectAsStateWithLifecycle()

    if (items.isEmpty()) {
        BoxCentered(text = "No calls yet.\nUse the Call button on a contact to start one.")
        return
    }

    LazyColumn(modifier = Modifier.fillMaxSize().padding(vertical = 8.dp)) {
        items(items) { item ->
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .clickable {
                        CallLauncher.startCall(context, container, item.otherId, item.name, item.avatarUrl, item.call.kind)
                    }
                    .padding(horizontal = 16.dp, vertical = 10.dp),
                verticalAlignment = Alignment.CenterVertically
            ) {
                CrystalAvatar(url = item.avatarUrl, name = item.name, size = 46.dp)
                Spacer(Modifier.size(14.dp))
                Column(Modifier.weight(1f)) {
                    Text(
                        item.name,
                        fontWeight = if (item.missed) FontWeight.Bold else FontWeight.SemiBold,
                        color = if (item.missed) Color(0xFFF15C6D) else MaterialTheme.colorScheme.onSurface
                    )
                    Row(verticalAlignment = Alignment.CenterVertically) {
                        Icon(
                            when {
                                item.missed -> Icons.Rounded.MissedVideoCall
                                item.incoming -> Icons.Rounded.CallReceived
                                else -> Icons.Rounded.CallMade
                            },
                            contentDescription = null,
                            tint = if (item.missed) Color(0xFFF15C6D) else if (item.incoming) CrystalGreen else Color(0xFF00A884),
                            modifier = Modifier.size(16.dp)
                        )
                        Spacer(Modifier.size(6.dp))
                        Text(
                            when (item.call.status) {
                                "missed" -> "Missed"
                                "ringing" -> "Ringing"
                                "answered", "completed" -> "Outgoing" + if (item.call.duration > 0) " · ${item.call.duration}s" else ""
                                else -> item.call.status
                            },
                            style = MaterialTheme.typography.bodyMedium,
                            maxLines = 1,
                            overflow = TextOverflow.Ellipsis,
                            color = MaterialTheme.colorScheme.onSurfaceVariant
                        )
                    }
                }
                Spacer(Modifier.size(8.dp))
                if (item.call.kind == "video") {
                    Icon(Icons.Rounded.Videocam, contentDescription = null, tint = CrystalGreen)
                } else {
                    Icon(Icons.Rounded.Call, contentDescription = null, tint = CrystalGreen)
                }
                Spacer(Modifier.size(10.dp))
                Text(formatTime(item.call.startedAt), style = MaterialTheme.typography.labelMedium, color = MaterialTheme.colorScheme.onSurfaceVariant)
            }
        }
    }
}

@Composable
private fun BoxCentered(text: String) {
    androidx.compose.foundation.layout.Box(Modifier.fillMaxSize()) {
        Text(
            text,
            modifier = Modifier.align(Alignment.Center),
            textAlign = TextAlign.Center,
            color = MaterialTheme.colorScheme.onSurfaceVariant
        )
    }
}
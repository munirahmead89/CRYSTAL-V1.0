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
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.Call
import androidx.compose.material.icons.rounded.CallEnd
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import com.crystal_messenger.app.ui.components.CrystalAvatar

@Composable
fun IncomingCallCard(
    callId: String,
    name: String,
    avatarUrl: String?,
    onAnswer: () -> Unit,
    onDecline: () -> Unit
) {
    Box(
        modifier = Modifier
            .fillMaxSize()
            .background(Brush.verticalGradient(listOf(Color(0xFF0B141A), Color(0xFF10221A)))),
        contentAlignment = Alignment.Center
    ) {
        Column(horizontalAlignment = Alignment.CenterHorizontally, modifier = Modifier.fillMaxWidth()) {
            CrystalAvatar(url = avatarUrl, name = name, size = 128.dp, online = true)
            Spacer(Modifier.height(28.dp))
            Text(name, color = Color.White, style = MaterialTheme.typography.headlineSmall, fontWeight = FontWeight.Bold)
            Spacer(Modifier.height(10.dp))
            Text("Incoming call…", color = Color(0xFFB3C2C9))
            Spacer(Modifier.height(80.dp))
            Row(horizontalArrangement = Arrangement.spacedBy(44.dp), verticalAlignment = Alignment.CenterVertically) {
                Surface(
                    shape = CircleShape,
                    color = Color(0xFFF15C6D),
                    modifier = Modifier.size(72.dp),
                    onClick = { onDecline() }
                ) {
                    Box(contentAlignment = Alignment.Center) {
                        Icon(Icons.Rounded.CallEnd, contentDescription = "Decline", tint = Color.White, modifier = Modifier.size(34.dp))
                    }
                }
                Surface(
                    shape = CircleShape,
                    color = Color(0xFF25D366),
                    modifier = Modifier.size(72.dp),
                    onClick = { onAnswer() }
                ) {
                    Box(contentAlignment = Alignment.Center) {
                        Icon(Icons.Rounded.Call, contentDescription = "Answer", tint = Color.White, modifier = Modifier.size(34.dp))
                    }
                }
            }
            Spacer(Modifier.height(16.dp))
            Text("Answer or decline", color = Color(0xFF667781), style = MaterialTheme.typography.labelMedium)
        }
    }
}
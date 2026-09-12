package com.crystal_messenger.app.features.chats

import androidx.compose.foundation.gestures.detectTapGestures
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.imePadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.rounded.Send
import androidx.compose.material.icons.rounded.Add
import androidx.compose.material.icons.rounded.Mic
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.material3.TextField
import androidx.compose.material3.TextFieldDefaults
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.unit.dp
import com.crystal_messenger.app.ui.components.glassmorphism
import com.crystal_messenger.app.ui.theme.CrystalGreen

@Composable
fun MessageInputBar(
    onSend: (String) -> Unit,
    onAttach: () -> Unit,
    onChanged: (String) -> Unit,
    onRecordStart: () -> Unit = {},
    onRecordStop: () -> Unit = {},
    isRecording: Boolean = false
) {
    var text by remember { mutableStateOf("") }

    Row(
        modifier = Modifier
            .fillMaxWidth()
            .imePadding()
            .padding(horizontal = 8.dp, vertical = 6.dp)
            .glassmorphism(alpha = 0.35f, cornerRadius = 26),
        verticalAlignment = Alignment.CenterVertically
    ) {
        IconButton(onClick = onAttach) {
            Icon(Icons.Rounded.Add, contentDescription = "Attach")
        }

        TextField(
            value = text,
            onValueChange = {
                text = it
                onChanged(it)
            },
            modifier = Modifier.weight(1f),
            placeholder = { Text(if (isRecording) "Recording…" else "Message") },
            maxLines = 4,
            colors = TextFieldDefaults.colors(
                focusedContainerColor = Color.Transparent,
                unfocusedContainerColor = Color.Transparent,
                focusedIndicatorColor = Color.Transparent,
                unfocusedIndicatorColor = Color.Transparent,
                disabledIndicatorColor = Color.Transparent
            )
        )

        if (text.isNotBlank()) {
            IconButton(onClick = {
                onSend(text)
                text = ""
                onChanged("")
            }) {
                Icon(
                    Icons.AutoMirrored.Rounded.Send,
                    contentDescription = "Send",
                    tint = CrystalGreen
                )
            }
        } else {
            Surface(
                shape = CircleShape,
                color = if (isRecording) MaterialTheme.colorScheme.error else CrystalGreen
            ) {
                IconButton(
                    onClick = { },
                    modifier = Modifier.pointerInput(Unit) {
                        detectTapGestures(
                            onTap = { },
                            onPress = {
                                onRecordStart()
                                tryAwaitRelease()
                                onRecordStop()
                            }
                        )
                    }
                ) {
                    Icon(
                        Icons.Rounded.Mic,
                        contentDescription = "Voice note",
                        tint = Color.White,
                        modifier = Modifier.size(22.dp)
                    )
                }
            }
        }
    }
}
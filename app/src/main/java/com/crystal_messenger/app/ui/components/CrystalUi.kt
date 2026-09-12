package com.crystal_messenger.app.ui.components

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import coil.compose.AsyncImage
import com.crystal_messenger.app.ui.theme.CrystalGreen
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import kotlin.math.abs


fun Modifier.glassmorphism(alpha: Float = 0.25f, cornerRadius: Dp = 16.dp): Modifier = this
    .clip(RoundedCornerShape(cornerRadius))
    .background(MaterialTheme.colorScheme.surface.copy(alpha = alpha))
    .border(
        width = 1.dp,
        color = MaterialTheme.colorScheme.outline.copy(alpha = 0.12f),
        shape = RoundedCornerShape(cornerRadius)
    )

val AvatarGradients = listOf(
    Brush.linearGradient(listOf(Color(0xFF1FA780), Color(0xFF25D366))),
    Brush.linearGradient(listOf(Color(0xFF16A085), Color(0xFF4DB47F))),
    Brush.linearGradient(listOf(Color(0xFF0D7377), Color(0xFF2DA8BF))),
    Brush.linearGradient(listOf(Color(0xFF7C4DFF), Color(0xFF448AFF))),
    Brush.linearGradient(listOf(Color(0xFFF4511E), Color(0xFFFFB300))),
    Brush.linearGradient(listOf(Color(0xFF8E24AA), Color(0xFFE91E63))),
    Brush.linearGradient(listOf(Color(0xFF00796B), Color(0xFF00ACC1)))
)

fun gradientFor(name: String): Brush =
    AvatarGradients[abs(name.hashCode()) % AvatarGradients.size]

@Composable
fun CrystalAvatar(
    url: String?,
    name: String,
    modifier: Modifier = Modifier,
    size: Dp = 48.dp,
    online: Boolean = false
) {
    Box(modifier = modifier.size(size)) {
        if (!url.isNullOrBlank()) {
            AsyncImage(
                model = url,
                contentDescription = name,
                contentScale = ContentScale.Crop,
                modifier = Modifier
                    .size(size)
                    .clip(CircleShape)
            )
        } else {
            Box(
                modifier = Modifier
                    .size(size)
                    .clip(CircleShape)
                    .background(gradientFor(name)),
                contentAlignment = Alignment.Center
            ) {
                val font = (size.value * 0.34f).sp
                Text(
                    text = initials(name),
                    color = Color.White,
                    fontSize = font,
                    fontWeight = FontWeight.SemiBold
                )
            }
        }
        if (online) {
            Box(
                modifier = Modifier
                    .align(Alignment.BottomEnd)
                    .size(size * 0.3f)
                    .clip(CircleShape)
                    .background(CrystalGreen)
                    .border(2.dp, MaterialTheme.colorScheme.surface, CircleShape)
            )
        }
    }
}

fun initials(name: String): String {
    val parts = name.trim().split(Regex("\\s+")).filter { it.isNotBlank() }
    return when {
        parts.isEmpty() -> "?"
        parts.size == 1 -> parts[0].take(2).uppercase()
        else -> (parts[0].take(1) + parts[1].take(1)).uppercase()
    }
}

fun formatTime(epoch: Long): String {
    if (epoch <= 0) return ""
    val now = System.currentTimeMillis()
    return when {
        now - epoch < 24 * 3600_000 && sameDay(now, epoch) ->
            SimpleDateFormat("h:mm a", Locale.getDefault()).format(Date(epoch))
        else ->
            SimpleDateFormat("MMM d", Locale.getDefault()).format(Date(epoch))
    }
}

fun formatFullTime(epoch: Long): String =
    SimpleDateFormat("MMM d, h:mm a", Locale.getDefault()).format(Date(epoch))

private fun sameDay(a: Long, b: Long): Boolean {
    val ca = java.util.Calendar.getInstance().apply { timeInMillis = a }
    val cb = java.util.Calendar.getInstance().apply { timeInMillis = b }
    return ca.get(java.util.Calendar.YEAR) == cb.get(java.util.Calendar.YEAR) &&
        ca.get(java.util.Calendar.DAY_OF_YEAR) == cb.get(java.util.Calendar.DAY_OF_YEAR)
}
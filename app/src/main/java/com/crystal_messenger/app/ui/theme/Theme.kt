package com.crystal_messenger.app.ui.theme

import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.darkColorScheme
import androidx.compose.material3.lightColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.ui.graphics.Color

val CrystalGreen = Color(0xFF25D366)
val CrystalGreenDark = Color(0xFF0FA34B)
val CrystalTeal = Color(0xFF1FA780)
val OutgoingBubble = Color(0xFF005C4B)
val IncomingBubble = Color(0xFF202C33)

val CrystalDarkBackground = Color(0xFF0B141A)
val CrystalDarkSurface = Color(0xFF111B21)
val CrystalDarkSurfaceHigh = Color(0xFF202C33)
val CrystalDarkOutline = Color(0xFF2A3942)

val CrystalLightBackground = Color(0xFFFFFFFF)
val CrystalLightSurface = Color(0xFFF0F2F5)
val CrystalLightSurfaceHigh = Color(0xFFD9DDE1)

private val DarkColors = darkColorScheme(
    primary = CrystalGreen,
    onPrimary = Color.Black,
    secondary = CrystalTeal,
    onSecondary = Color.White,
    background = CrystalDarkBackground,
    onBackground = Color(0xFFE9EDEF),
    surface = CrystalDarkSurface,
    onSurface = Color(0xFFE9EDEF),
    surfaceVariant = CrystalDarkSurfaceHigh,
    onSurfaceVariant = Color(0xFF8696A0),
    outline = CrystalDarkOutline,
    error = Color(0xFFF15C6D)
)

private val LightColors = lightColorScheme(
    primary = CrystalGreenDark,
    onPrimary = Color.White,
    secondary = CrystalTeal,
    onSecondary = Color.White,
    background = CrystalLightBackground,
    onBackground = Color(0xFF111B21),
    surface = CrystalLightSurface,
    onSurface = Color(0xFF111B21),
    surfaceVariant = CrystalLightSurfaceHigh,
    onSurfaceVariant = Color(0xFF667781),
    outline = Color(0xFFD9DDE1)
)

@Composable
fun CRYSTAL_MESSENGERTheme(
    darkTheme: Boolean = true,
    content: @Composable () -> Unit
) {
    val scheme = if (darkTheme) DarkColors else LightColors
    MaterialTheme(
        colorScheme = scheme,
        typography = CrystalTypography,
        content = content
    )
}
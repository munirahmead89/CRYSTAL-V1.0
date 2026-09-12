package com.crystal_messenger.app

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import com.crystal_messenger.app.ui.CrystalMessengerApp
import com.crystal_messenger.app.ui.theme.CRYSTAL_MESSENGERTheme

class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()
        setContent {
            CRYSTAL_MESSENGERTheme {
                CrystalMessengerApp()
            }
        }
    }
}

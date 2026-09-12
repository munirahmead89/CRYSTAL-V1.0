package com.crystal_messenger.app.features.profile

import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.ArrowBack
import androidx.compose.material.icons.rounded.ContactPhone
import androidx.compose.material.icons.rounded.DataSaverOn
import androidx.compose.material.icons.rounded.DarkMode
import androidx.compose.material.icons.rounded.ExitToApp
import androidx.compose.material.icons.rounded.Folder
import androidx.compose.material.icons.rounded.Group
import androidx.compose.material.icons.rounded.HelpOutline
import androidx.compose.material.icons.rounded.Key
import androidx.compose.material.icons.rounded.Lock
import androidx.compose.material.icons.rounded.Notifications
import androidx.compose.material.icons.rounded.NotificationsActive
import androidx.compose.material.icons.rounded.Person
import androidx.compose.material.icons.rounded.Star
import androidx.compose.material.icons.rounded.Storage
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Switch
import androidx.compose.material3.Text
import androidx.compose.material3.TopAppBar
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.lifecycle.viewmodel.compose.viewModel
import com.crystal_messenger.app.di.AppContainer
import com.crystal_messenger.app.ui.components.CrystalAvatar
import com.crystal_messenger.app.ui.theme.CrystalGreen

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun ProfileScreen(
    container: AppContainer,
    onBack: () -> Unit,
    onLogout: () -> Unit
) {
    val vm: ProfileViewModel = viewModel { ProfileViewModel(container) }
    val ui by vm.uiState.collectAsStateWithLifecycle()

    var editName by remember { mutableStateOf(false) }
    var confirmLogout by remember { mutableStateOf(false) }

    val name = ui.session?.name ?: "Unknown"
    val phone = ui.session?.phone ?: ""

    Scaffold(
        containerColor = MaterialTheme.colorScheme.background,
        topBar = {
            TopAppBar(
                title = { Text("Settings") },
                navigationIcon = {
                    IconButton(onClick = onBack) {
                        Icon(Icons.Rounded.ArrowBack, contentDescription = "Back")
                    }
                }
            )
        }
    ) { padding ->
        Column(Modifier.fillMaxSize().padding(padding).verticalScroll(rememberScrollState())) {
            Row(
                modifier = Modifier.fillMaxWidth().padding(16.dp),
                verticalAlignment = Alignment.CenterVertically
            ) {
                CrystalAvatar(url = null, name = name, size = 72.dp)
                Spacer(Modifier.width(16.dp))
                Column {
                    Text(name, style = MaterialTheme.typography.titleLarge, fontWeight = FontWeight.SemiBold)
                    Text(if (phone.isBlank()) "Your phone" else phone, color = MaterialTheme.colorScheme.onSurfaceVariant)
                }
            }

            HorizontalDivider()

            SettingsRow(Icons.Rounded.Person, "Edit name") { editName = true }

            Text("Settings", modifier = Modifier.padding(horizontal = 16.dp, vertical = 10.dp), style = MaterialTheme.typography.labelLarge, color = CrystalGreen)

            SettingsRowSwitch(Icons.Rounded.NotificationsActive, "Notifications", initial = true, onChanged = {})
            SettingsRowSwitch(Icons.Rounded.DarkMode, "Dark theme", initial = true, onChanged = {})
            SettingsRowSwitch(Icons.Rounded.DataSaverOn, "Use less data", initial = false, onChanged = {})
            SettingsRow(Icons.Rounded.Lock, "Privacy")
            SettingsRow(Icons.Rounded.Star, "Starred messages")
            SettingsRow(Icons.Rounded.Group, "Linked devices")
            SettingsRow(Icons.Rounded.Storage, "Storage and data")
            SettingsRow(Icons.Rounded.ContactPhone, "Contacts")
            SettingsRow(Icons.Rounded.Notifications, "Notification sounds")
            SettingsRow(Icons.Rounded.Folder, "Backup to Google Drive")
            SettingsRow(Icons.Rounded.Key, "Encryption")
            SettingsRow(Icons.Rounded.HelpOutline, "Help")

            Spacer(Modifier.height(24.dp))

            OutlinedButton(
                onClick = { confirmLogout = true },
                modifier = Modifier.fillMaxWidth().padding(horizontal = 16.dp)
            ) {
                Icon(Icons.Rounded.ExitToApp, contentDescription = null)
                Spacer(Modifier.width(8.dp))
                Text("Log out")
            }

            Spacer(Modifier.height(32.dp))
        }
    }

    if (editName) {
        var newName by remember { mutableStateOf(name) }
        AlertDialog(
            onDismissRequest = { editName = false },
            title = { Text("Edit name") },
            text = {
                OutlinedTextField(
                    value = newName,
                    onValueChange = { newName = it },
                    label = { Text("Name") },
                    singleLine = true
                )
            },
            confirmButton = {
                Button(
                    onClick = {
                        vm.saveName(newName.trim())
                        editName = false
                    },
                    colors = ButtonDefaults.buttonColors(containerColor = CrystalGreen)
                ) {
                    Text("Save")
                }
            },
            dismissButton = {
                OutlinedButton(onClick = { editName = false }) { Text("Cancel") }
            }
        )
    }

    if (confirmLogout) {
        AlertDialog(
            onDismissRequest = { confirmLogout = false },
            title = { Text("Log out?") },
            text = { Text("You will be signed out and return to the welcome screen.") },
            confirmButton = {
                Button(
                    onClick = {
                        vm.logout(onLogout)
                        confirmLogout = false
                    },
                    colors = ButtonDefaults.buttonColors(containerColor = Color(0xFFF15C6D))
                ) {
                    Text("Log out")
                }
            },
            dismissButton = {
                OutlinedButton(onClick = { confirmLogout = false }) { Text("Cancel") }
            }
        )
    }
}

@Composable
private fun SettingsRow(icon: ImageVector, label: String, onClick: () -> Unit = {}) {
    Row(
        modifier = Modifier.fillMaxWidth().clickable(onClick = onClick).padding(horizontal = 16.dp, vertical = 14.dp),
        verticalAlignment = Alignment.CenterVertically
    ) {
        Icon(icon, contentDescription = null, tint = CrystalGreen, modifier = Modifier.size(24.dp))
        Spacer(Modifier.width(20.dp))
        Text(label, modifier = Modifier.weight(1f), maxLines = 1, overflow = TextOverflow.Ellipsis)
    }
}

@Composable
private fun SettingsRowSwitch(icon: ImageVector, label: String, initial: Boolean, onChanged: (Boolean) -> Unit) {
    var checked by remember { mutableStateOf(initial) }
    Row(
        modifier = Modifier.fillMaxWidth().padding(horizontal = 16.dp, vertical = 10.dp),
        verticalAlignment = Alignment.CenterVertically
    ) {
        Icon(icon, contentDescription = null, tint = CrystalGreen, modifier = Modifier.size(24.dp))
        Spacer(Modifier.width(20.dp))
        Text(label, modifier = Modifier.weight(1f))
        Switch(checked = checked, onCheckedChange = { checked = it; onChanged(it) })
    }
}
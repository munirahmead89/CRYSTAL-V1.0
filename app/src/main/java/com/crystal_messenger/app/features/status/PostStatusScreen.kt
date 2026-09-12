package com.crystal_messenger.app.features.status

import android.net.Uri
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
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
import androidx.compose.material.icons.filled.Close
import androidx.compose.material.icons.filled.PhotoCamera
import androidx.compose.material.icons.filled.Send
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.CircularProgressIndicator
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
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.unit.dp
import coil.compose.AsyncImage
import com.crystal_messenger.app.di.AppContainer
import com.crystal_messenger.app.ui.theme.CrystalGreen
import kotlinx.coroutines.launch

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun PostStatusScreen(
    container: AppContainer,
    mediaUri: Uri?,
    onBack: () -> Unit,
    onPosted: () -> Unit
) {
    val vm: StatusViewModel = androidx.lifecycle.viewmodel.compose.viewModel { StatusViewModel(container) }
    val scope = rememberCoroutineScope()
    var text by remember { mutableStateOf("") }
    var uploading by remember { mutableStateOf(false) }
    var selectedMedia by remember { mutableStateOf<Uri?>(mediaUri) }

    val pickMedia = rememberLauncherForActivityResult(ActivityResultContracts.GetContent()) { uri ->
        if (uri != null) selectedMedia = uri
    }

    fun post() {
        val uri = selectedMedia
        val body = text.trim()
        if (uri != null) {
            uploading = true
            scope.launch {
                vm.postMedia(uri, "image")
                uploading = false
                onPosted()
            }
        } else if (body.isNotEmpty()) {
            vm.postText(body)
            onPosted()
        }
    }

    Scaffold(
        containerColor = MaterialTheme.colorScheme.background,
        topBar = {
            TopAppBar(
                title = { Text("New status") },
                navigationIcon = {
                    IconButton(onClick = onBack) {
                        Icon(Icons.Filled.Close, contentDescription = "Close")
                    }
                },
                actions = {
                    IconButton(onClick = { pickMedia.launch("image/*") }) {
                        Icon(Icons.Filled.PhotoCamera, contentDescription = "Add photo")
                    }
                    IconButton(
                        onClick = { post() },
                        enabled = text.isNotBlank() || selectedMedia != null
                    ) {
                        if (uploading) {
                            CircularProgressIndicator(modifier = Modifier.size(20.dp), strokeWidth = 2.dp)
                        } else {
                            Icon(Icons.Filled.Send, contentDescription = "Post")
                        }
                    }
                }
            )
        }
    ) { padding ->
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(padding)
                .verticalScroll(rememberScrollState())
                .padding(16.dp)
        ) {
            selectedMedia?.let { uri ->
                Box(
                    modifier = Modifier
                        .fillMaxWidth()
                        .height(320.dp)
                        .background(MaterialTheme.colorScheme.surfaceVariant)
                ) {
                    AsyncImage(
                        model = uri,
                        contentDescription = "Selected status media",
                        contentScale = ContentScale.Crop,
                        modifier = Modifier.fillMaxSize()
                    )
                }
                Spacer(Modifier.height(16.dp))
            }

            OutlinedTextField(
                value = text,
                onValueChange = { text = it.take(700) },
                placeholder = { Text("What's on your mind?") },
                modifier = Modifier.fillMaxWidth(),
                minLines = 3,
                maxLines = 6
            )

            Spacer(Modifier.height(20.dp))

            Button(
                onClick = { post() },
                enabled = text.isNotBlank() || selectedMedia != null,
                colors = ButtonDefaults.buttonColors(containerColor = CrystalGreen),
                modifier = Modifier.fillMaxWidth()
            ) {
                Text("Share status", color = Color.White)
            }
        }
    }
}
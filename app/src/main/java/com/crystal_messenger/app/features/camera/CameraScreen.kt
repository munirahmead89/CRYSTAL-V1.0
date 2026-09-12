package com.crystal_messenger.app.features.camera

import android.Manifest
import androidx.camera.core.CameraSelector
import androidx.camera.core.ImageCapture
import androidx.camera.core.ImageCaptureException
import androidx.camera.core.Preview
import androidx.camera.lifecycle.ProcessCameraProvider
import androidx.camera.view.PreviewView
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.ArrowBack
import androidx.compose.material.icons.rounded.CameraAlt
import androidx.compose.material.icons.rounded.Cameraswitch
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalLifecycleOwner
import androidx.compose.ui.unit.dp
import androidx.compose.ui.viewinterop.AndroidView
import androidx.core.content.ContextCompat
import com.crystal_messenger.app.di.AppContainer
import com.google.accompanist.permissions.ExperimentalPermissionsApi
import com.google.accompanist.permissions.PermissionStatus
import com.google.accompanist.permissions.rememberPermissionState
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import java.io.File

@OptIn(ExperimentalPermissionsApi::class)
@Composable
fun CameraScreen(
    container: AppContainer,
    conversationId: String,
    onBack: () -> Unit,
    onMediaSent: () -> Unit
) {
    val context = LocalContext.current
    val lifecycleOwner = LocalLifecycleOwner.current
    val scope = rememberCoroutineScope()

    val cameraPermission = rememberPermissionState(Manifest.permission.CAMERA)
    val previewView = remember { PreviewView(context) }
    val imageCapture = remember { ImageCapture.Builder().build() }
    val cameraProviderFuture = remember { ProcessCameraProvider.getInstance(context) }

    var backCamera by remember { mutableStateOf(true) }
    var capturing by remember { mutableStateOf(false) }
    val executor = remember { ContextCompat.getMainExecutor(context) }

    DisposableEffect(lifecycleOwner, backCamera, cameraPermission.status) {
        if (cameraPermission.status != PermissionStatus.Granted) {
            return@DisposableEffect onDispose { }
        }
        val runnable = Runnable {
            runCatching {
                val provider = cameraProviderFuture.get()
                val selector =
                    if (backCamera) CameraSelector.DEFAULT_BACK_CAMERA else CameraSelector.DEFAULT_FRONT_CAMERA
                val preview = Preview.Builder().build().also {
                    it.setSurfaceProvider(previewView.surfaceProvider)
                }
                provider.unbindAll()
                provider.bindToLifecycle(lifecycleOwner, selector, preview, imageCapture)
            }
        }
        cameraProviderFuture.addListener(runnable, executor)
        onDispose {
            runCatching { cameraProviderFuture.get().unbindAll() }
        }
    }

    LaunchedEffect(Unit) {
        if (cameraPermission.status != PermissionStatus.Granted) cameraPermission.launchPermissionRequest()
    }

    fun capture() {
        if (capturing) return
        capturing = true
        val file = File(context.cacheDir, "photo_${System.currentTimeMillis()}.jpg")
        val output = ImageCapture.OutputFileOptions.Builder(file).build()
        imageCapture.takePicture(
            output,
            executor,
            object : ImageCapture.OnImageSavedCallback {
                override fun onImageSaved(outputFileResults: ImageCapture.OutputFileResults) {
                    scope.launch {
                        val me = container.sessionManager.current().userId.orEmpty()
                        val url = withContext(Dispatchers.IO) {
                            container.storageRepository.uploadFile(me, file, "image/jpeg")
                        }
                        capturing = false
                        if (!url.isNullOrBlank() && me.isNotBlank()) {
                            container.chatRepository.sendMessage(
                                conversationId, me, "", mtype = "image", mediaUrl = url
                            )
                        }
                        file.delete()
                        onMediaSent()
                    }
                }

                override fun onError(exception: ImageCaptureException) {
                    capturing = false
                }
            }
        )
    }

    Box(modifier = Modifier.fillMaxSize().background(Color.Black)) {
        AndroidView(factory = { previewView }, modifier = Modifier.fillMaxSize())

        Box(Modifier.align(Alignment.TopStart).padding(8.dp)) {
            Surface(shape = CircleShape, color = Color.White.copy(alpha = 0.25f)) {
                IconButton(onClick = onBack) {
                    Icon(Icons.Rounded.ArrowBack, "Close", tint = Color.White)
                }
            }
        }

        if (cameraPermission.status != PermissionStatus.Granted) {
            Surface(
                modifier = Modifier.align(Alignment.Center).padding(24.dp),
                shape = MaterialTheme.shapes.large
            ) {
                Text("Camera permission needed to take photos.", modifier = Modifier.padding(20.dp))
            }
        }

        Surface(
            shape = CircleShape,
            color = Color.White.copy(alpha = 0.25f),
            modifier = Modifier.align(Alignment.TopEnd).padding(20.dp)
        ) {
            IconButton(onClick = { backCamera = !backCamera }) {
                Icon(Icons.Rounded.Cameraswitch, "Switch camera", tint = Color.White)
            }
        }

        Surface(
            shape = CircleShape,
            color = Color.White.copy(alpha = 0.35f),
            modifier = Modifier
                .align(Alignment.BottomCenter)
                .padding(bottom = 40.dp)
                .size(74.dp),
            onClick = { capture() }
        ) {
            Box(contentAlignment = Alignment.Center) {
                Icon(Icons.Rounded.CameraAlt, contentDescription = "Capture", tint = Color.White, modifier = Modifier.size(34.dp))
            }
        }
    }
}
package com.crystal_messenger.app.core.repository

import android.content.Context
import android.net.Uri
import android.provider.OpenableColumns
import com.crystal_messenger.app.core.supabase.SupabaseClient
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import java.io.File
import java.util.UUID

class StorageRepository(
    private val client: SupabaseClient,
    private val context: Context
) {

    suspend fun uploadUri(userId: String, uri: Uri, mimeType: String): String? =
        withContext(Dispatchers.IO) {
            try {
                val resolver = context.contentResolver
                val stream = resolver.openInputStream(uri) ?: return@withContext null
                val bytes = stream.use { it.readBytes() }
                val originalName = queryName(uri) ?: UUID.randomUUID().toString()
                val ext = originalName.substringAfterLast('.', "jpg").ifBlank { "jpg" }
                val fileName = "${System.currentTimeMillis()}.$ext"
                client.uploadMedia(userId, fileName, bytes, mimeType)
            } catch (e: Exception) {
                null
            }
        }

    suspend fun uploadFile(userId: String, file: File, mimeType: String): String? =
        withContext(Dispatchers.IO) {
            try {
                client.uploadMedia(userId, file.name, file.readBytes(), mimeType)
            } catch (_: Exception) { null }
        }

    private fun queryName(uri: Uri): String? {
        return try {
            val cursor = context.contentResolver.query(uri, arrayOf(OpenableColumns.DISPLAY_NAME), null, null, null)
            cursor?.use {
                if (it.moveToFirst()) {
                    it.getString(it.getColumnIndexOrThrow(OpenableColumns.DISPLAY_NAME))
                } else null
            }
        } catch (_: Exception) { null }
    }
}
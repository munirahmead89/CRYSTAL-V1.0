package com.crystal_messenger.app.core.repository

import android.content.ContentResolver
import android.content.Context
import android.provider.ContactsContract
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext

data class DeviceContact(
    val name: String,
    val phone: String
)

class ContactRepository(private val context: Context) {

    suspend fun readContacts(): List<DeviceContact> = withContext(Dispatchers.IO) {
        val result = mutableListOf<DeviceContact>()
        val resolver: ContentResolver = context.contentResolver
        try {
            val cursor = resolver.query(
                ContactsContract.CommonDataKinds.Phone.CONTENT_URI,
                arrayOf(
                    ContactsContract.CommonDataKinds.Phone.DISPLAY_NAME,
                    ContactsContract.CommonDataKinds.Phone.NUMBER
                ),
                null,
                null,
                ContactsContract.CommonDataKinds.Phone.DISPLAY_NAME + " ASC"
            )
            cursor?.use {
                val nameIdx = it.getColumnIndex(ContactsContract.CommonDataKinds.Phone.DISPLAY_NAME)
                val numIdx = it.getColumnIndex(ContactsContract.CommonDataKinds.Phone.NUMBER)
                while (it.moveToNext()) {
                    val name = it.getString(nameIdx) ?: continue
                    val number = it.getString(numIdx) ?: continue
                    val normalized = number.replace(" ", "").replace("-", "")
                    if (normalized.isNotEmpty()) {
                        result.add(DeviceContact(name, normalized))
                    }
                }
            }
        } catch (_: SecurityException) {
        } catch (_: Exception) {
        }
        result.distinctBy { it.phone }
    }
}
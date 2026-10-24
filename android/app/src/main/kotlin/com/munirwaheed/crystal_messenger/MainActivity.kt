package com.munirwaheed.crystal_messenger

import android.content.ContentValues
import android.content.Context
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.os.Environment
import android.provider.MediaStore
import android.provider.ContactsContract
import android.net.TrafficStats
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterFragmentActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        DeviceInfoApi.setUp(
            flutterEngine.dartExecutor.binaryMessenger,
            DeviceInfoHandler(
                packageManager = packageManager,
                packageName = packageName,
            ),
        )
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "crystal/network")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    // Real per-app data usage. The Settings > Data usage screen
                    // used to render hardcoded numbers (1.8 GB, 200 MB) and two
                    // switches wired to `onChanged: (_) {}`, which is worse than
                    // showing nothing: users act on those numbers.
                    // TrafficStats is the only per-app source available without
                    // the PACKAGE_USAGE_STATS permission, which a messaging app
                    // has no business asking for.
                    //
                    // The Wi-Fi SSID and SIM carrier used to be reported on this
                    // channel too. That settings sheet is gone, and with it the
                    // READ_PHONE_STATE and ACCESS_WIFI_STATE declarations: an
                    // SSID also needs a location permission this app never
                    // requested, so the row could only ever have read "Permission
                    // not granted". Removing the surface removes the permission.
                    "getDataUsage" -> {
                        result.success(
                            mapOf(
                                "rxBytes" to TrafficStats.getUidRxBytes(android.os.Process.myUid()),
                                "txBytes" to TrafficStats.getUidTxBytes(android.os.Process.myUid()),
                            ),
                        )
                    }
                    else -> result.notImplemented()
                }
            }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "crystal/contacts")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "readContacts" -> {
                        if (checkSelfPermission(android.Manifest.permission.READ_CONTACTS)
                            != PackageManager.PERMISSION_GRANTED) {
                            result.error("permission_denied", "Contacts permission is required", null)
                            return@setMethodCallHandler
                        }
                        val contacts = mutableListOf<Map<String, String>>()
                        contentResolver.query(
                            ContactsContract.CommonDataKinds.Phone.CONTENT_URI,
                            arrayOf(
                                ContactsContract.CommonDataKinds.Phone.DISPLAY_NAME,
                                ContactsContract.CommonDataKinds.Phone.NUMBER,
                            ),
                            null,
                            null,
                            ContactsContract.CommonDataKinds.Phone.DISPLAY_NAME + " ASC",
                        )?.use { cursor ->
                            val nameIndex = cursor.getColumnIndex(
                                ContactsContract.CommonDataKinds.Phone.DISPLAY_NAME,
                            )
                            val phoneIndex = cursor.getColumnIndex(
                                ContactsContract.CommonDataKinds.Phone.NUMBER,
                            )
                            while (cursor.moveToNext()) {
                                contacts.add(
                                    mapOf(
                                        "displayName" to (cursor.getString(nameIndex) ?: ""),
                                        "phone" to (cursor.getString(phoneIndex) ?: ""),
                                    ),
                                )
                            }
                        }
                        result.success(contacts)
                    }
                    else -> result.notImplemented()
                }
            }

        // "Save to Downloads" for received media. Uses MediaStore so the file
        // lands in the user's real Downloads collection and is visible to every
        // gallery/file app, without WRITE_EXTERNAL_STORAGE (which does not
        // exist from API 29 onward).
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "crystal/media")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "saveToDownloads" -> {
                        val path = call.argument<String>("path")
                        val displayName = call.argument<String>("displayName")
                        val mimeType = call.argument<String>("mimeType")
                        if (path.isNullOrBlank() || displayName.isNullOrBlank()) {
                            result.error(
                                "bad_args",
                                "path and displayName are required",
                                null,
                            )
                            return@setMethodCallHandler
                        }
                        try {
                            val saved = saveToDownloads(
                                File(path),
                                displayName,
                                mimeType ?: "application/octet-stream",
                            )
                            result.success(saved)
                        } catch (e: Exception) {
                            result.error("save_failed", e.message, null)
                        }
                    }
                    else -> result.notImplemented()
                }
            }
    }

    /**
     * Copies [source] into the public Downloads collection and returns the URI
     * a share/open intent can use.
     *
     * The copy is streamed through a buffer rather than read into a byte array,
     * so saving a multi-gigabyte video does not spike memory.
     */
    private fun saveToDownloads(
        source: File,
        displayName: String,
        mimeType: String,
    ): String {
        if (!source.exists()) {
            throw IllegalArgumentException("File does not exist: ${source.path}")
        }

        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            val isVideo = mimeType.startsWith("video/")
            val isImage = mimeType.startsWith("image/")
            val collection = if (isVideo) MediaStore.Video.Media.EXTERNAL_CONTENT_URI
            else if (isImage) MediaStore.Images.Media.EXTERNAL_CONTENT_URI
            else MediaStore.Downloads.EXTERNAL_CONTENT_URI

            val relativeFolder = if (isVideo) Environment.DIRECTORY_MOVIES + "/Crystal Messenger"
            else if (isImage) Environment.DIRECTORY_PICTURES + "/Crystal Messenger"
            else Environment.DIRECTORY_DOWNLOADS + "/Crystal Messenger"

            val values = ContentValues().apply {
                put(MediaStore.MediaColumns.DISPLAY_NAME, displayName)
                put(MediaStore.MediaColumns.MIME_TYPE, mimeType)
                put(MediaStore.MediaColumns.RELATIVE_PATH, relativeFolder)
                put(MediaStore.MediaColumns.IS_PENDING, 1)
            }
            val resolver = applicationContext.contentResolver
            val uri = resolver.insert(collection, values)
                ?: resolver.insert(MediaStore.Downloads.EXTERNAL_CONTENT_URI, values)
                ?: throw IllegalStateException("MediaStore refused the insert")

            resolver.openOutputStream(uri).use { out ->
                requireNotNull(out) { "Could not open the output stream" }
                source.inputStream().use { input -> input.copyTo(out) }
            }
            values.clear()
            values.put(MediaStore.MediaColumns.IS_PENDING, 0)
            resolver.update(uri, values, null, null)
            uri.toString()
        } else {
            @Suppress("DEPRECATION")
            val targetDir = File(
                Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_DOWNLOADS),
                "Crystal Messenger"
            )
            targetDir.mkdirs()
            val target = File(targetDir, displayName)
            source.inputStream().use { input ->
                target.outputStream().use { out -> input.copyTo(out) }
            }
            Uri.fromFile(target).toString()
        }
    }

    // wifiName() and simOperator() were removed with the settings sheet that
    // used them. Reporting an SSID requires a location permission this app does
    // not hold, and the carrier name required READ_PHONE_STATE; with no surface
    // left to render them, both permissions are gone too.
}

private class DeviceInfoHandler(
    private val packageManager: PackageManager,
    private val packageName: String,
) : DeviceInfoApi {
    override fun getSystemInfo(callback: (Result<SystemInfo>) -> Unit) {
        val packageInfo = try {
            packageManager.getPackageInfo(packageName, 0)
        } catch (_: Exception) {
            null
        }
        val buildNumber = packageInfo?.let { pInfo ->
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                pInfo.longVersionCode.toString()
            } else {
                @Suppress("DEPRECATION")
                pInfo.versionCode.toString()
            }
        } ?: ""
        callback(
            Result.success(
                SystemInfo(
                    fullName = listOf(Build.MANUFACTURER, Build.MODEL)
                        .filter { it.isNotBlank() }
                        .joinToString(" "),
                    platform = "android",
                    osVersion = Build.VERSION.RELEASE,
                    appVersion = packageInfo?.versionName ?: "",
                    buildNumber = buildNumber,
                ),
            ),
        )
    }
}

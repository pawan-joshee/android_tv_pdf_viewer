package androidtv.pdfviewer.redflute

import android.Manifest
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.graphics.pdf.PdfRenderer
import android.graphics.Bitmap
import android.os.Build
import android.os.ParcelFileDescriptor
import androidx.annotation.NonNull
import android.os.Bundle
import android.os.Environment
import android.provider.Settings
import android.util.Log // Import for Log
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileOutputStream
import java.io.ByteArrayOutputStream
import android.provider.OpenableColumns // Add this import
import android.content.SharedPreferences // Add this import

class MainActivity : FlutterActivity() {

    private companion object {
        const val TAG = "MainActivity"
        const val CHANNEL = "androidtv.pdfviewer.redflute/pdf" // Match Dart's MethodChannel
        const val REQUEST_CODE_PICK_PDF = 1001
        const val REQUEST_CODE_STORAGE_PERMISSION = 1002
        const val PREFS_NAME = "pdfviewer_prefs"
        const val PREF_REQUEST_PERMISSION = "request_permission"
        const val REQUEST_CODE_MANAGE_EXTERNAL_STORAGE = 1003
    }

    private var pendingResult: MethodChannel.Result? = null
    private lateinit var methodChannel: MethodChannel
    private var hasHandledIntent = false // Flag to handle intent once

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // Register plugins without package names since we're in the same package
        flutterEngine.plugins.add(PdfRendererPlugin())
        flutterEngine.plugins.add(DeviceMetricsPlugin())

        // Initialize the MethodChannel
        methodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)

        // Set up the MethodCallHandler
        methodChannel.setMethodCallHandler { call, result ->
            when (call.method) {
                "checkAndRequestStoragePermission" -> checkAndRequestStoragePermission(result)
                "requestStoragePermission" -> requestStoragePermission(result)
                "pickPdfFile" -> pickPdfFile(result)
                "openAppSettings" -> openAppSettings(result)
                "getExternalStoragePaths" -> getExternalStoragePaths(result)
                "openPdf" -> {
                    val filePath = call.argument<String>("filePath") ?: ""
                    openPdfExternally(filePath, result)
                }
                "renderPage" -> {
                    val filePath = call.argument<String>("filePath")
                    val pageNumber = call.argument<Int>("pageNumber")
                    val zoomLevel = call.argument<Double>("zoomLevel")
                    if (filePath != null && pageNumber != null && zoomLevel != null) {
                        try {
                            val imageBytes = renderPdfPage(filePath, pageNumber, zoomLevel)
                            result.success(imageBytes)
                        } catch (e: Exception) {
                            result.error("UNAVAILABLE", "Failed to render page: ${e.message}", null)
                        }
                    } else {
                        result.error("INVALID_ARGUMENT", "Invalid arguments received", null)
                    }
                }
                "getPageCount" -> {
                    val filePath = call.argument<String>("filePath")
                    if (filePath != null) {
                        try {
                            val pageCount = getPdfPageCount(filePath)
                            result.success(pageCount)
                        } catch (e: Exception) {
                            result.error("UNAVAILABLE", "Failed to get page count: ${e.message}", null)
                        }
                    } else {
                        result.error("INVALID_ARGUMENT", "Invalid arguments received", null)
                    }
                }
                "setRequestPermissionPreference" -> {
                    val requestPermission = call.argument<Boolean>("requestPermission") ?: false
                    setRequestPermissionPreference(requestPermission)
                    result.success(null)
                }
                "checkStoragePermission" -> checkStoragePermission(result)
                else -> result.notImplemented()
            }
        }

        // Handle the intent that started the app
        handleIntent(intent)
    }

    // Override onNewIntent to handle intents when the app is already running
    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        handleIntent(intent)
    }

    // Function to handle incoming intents
    private fun handleIntent(intent: Intent) {
        if (hasHandledIntent) return // Prevent handling the intent multiple times
        hasHandledIntent = true

        Log.d(TAG, "Handling intent: $intent")
        if (Intent.ACTION_VIEW == intent.action) {
            val uri: Uri? = intent.data
            Log.d(TAG, "Intent URI: $uri")
            if (uri != null) {
                val filePath = getFilePathFromUri(uri)
                if (filePath != null && File(filePath).exists()) { // Check if file exists
                    Log.d(TAG, "Resolved file path: $filePath")

                    val encodedFilePath = Uri.encode(filePath)

                    if (!isFlutterEngineRunning()) {
                        // Encode the file path when setting the initial route
                        intent.putExtra("route", "/pdf/$encodedFilePath")
                    } else {
                        // Encode the file path when invoking the method channel
                        methodChannel.invokeMethod("openPdf", mapOf("filePath" to encodedFilePath))
                    }
                } else {
                    Log.e(TAG, "Resolved file path is invalid or file does not exist.")
                }
            }
        }
    }

    private fun isFlutterEngineRunning(): Boolean {
        return ::methodChannel.isInitialized
    }

    private fun getFilePathFromUri(uri: Uri): String? {
        Log.d(TAG, "Resolving URI: $uri")
        Log.d(TAG, "URI Scheme: ${uri.scheme}")
        Log.d(TAG, "URI Authority: ${uri.authority}")
        Log.d(TAG, "URI Path: ${uri.path}")

        return when (uri.scheme) {
            "file" -> {
                Log.d(TAG, "URI scheme is file. Path: ${uri.path}")
                uri.path
            }
            "content" -> {
                try {
                    // Query the display name of the file
                    val cursor = contentResolver.query(uri, null, null, null, null)
                    var displayName = "Unknown"
                    if (cursor != null) {
                        val nameIndex = cursor.getColumnIndex(OpenableColumns.DISPLAY_NAME)
                        if (nameIndex != -1 && cursor.moveToFirst()) {
                            displayName = cursor.getString(nameIndex)
                        }
                        cursor.close()
                    }
                    Log.d(TAG, "Picked file display name: $displayName")

                    // Create a temporary file in the cache directory with the display name
                    val tempFile = File(cacheDir, "temp_${System.currentTimeMillis()}")
                    Log.d(TAG, "Creating temporary file at: ${tempFile.absolutePath}")

                    // Open input stream from URI
                    val inputStream = contentResolver.openInputStream(uri)
                    if (inputStream == null) {
                        Log.e(TAG, "InputStream is null for URI: $uri")
                        return null
                    }

                    // Write the input stream to the temporary file
                    val outputStream = FileOutputStream(tempFile)
                    inputStream.copyTo(outputStream)
                    inputStream.close()
                    outputStream.close()

                    Log.d(TAG, "Temporary file created at: ${tempFile.absolutePath}")
                    Log.d(TAG, "Original Uri: $uri") // Log the original URI

                    tempFile.absolutePath // Ensure the full path is returned
                } catch (e: Exception) {
                    Log.e(TAG, "Error resolving URI: ${e.message}")
                    null
                }
            }
            else -> {
                Log.e(TAG, "Unsupported URI scheme: ${uri.scheme}")
                null
            }
        }
    }

    private fun checkAndRequestStoragePermission(result: MethodChannel.Result) {
        when {
            Build.VERSION.SDK_INT >= Build.VERSION_CODES.R -> {
                if (Environment.isExternalStorageManager()) {
                    result.success(mapOf("status" to "granted"))
                } else {
                    result.success(mapOf("status" to "denied"))
                }
            }
            Build.VERSION.SDK_INT >= Build.VERSION_CODES.M -> {
                when {
                    ContextCompat.checkSelfPermission(
                        this,
                        Manifest.permission.READ_EXTERNAL_STORAGE
                    ) == PackageManager.PERMISSION_GRANTED -> {
                        result.success(mapOf("status" to "granted"))
                    }
                    shouldShowRequestPermissionRationale(Manifest.permission.READ_EXTERNAL_STORAGE) -> {
                        result.success(mapOf("status" to "denied"))
                    }
                    else -> {
                        result.success(mapOf("status" to "denied"))
                    }
                }
            }
            else -> {
                result.success(mapOf("status" to "granted"))
            }
        }
    }

    private fun requestStoragePermission(result: MethodChannel.Result) {
        val sharedPreferences = getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        val requestPermission = sharedPreferences.getBoolean(PREF_REQUEST_PERMISSION, false)

        if (!requestPermission) {
            result.success(mapOf("status" to "denied"))
            return
        }

        pendingResult = result
        when {
            Build.VERSION.SDK_INT >= Build.VERSION_CODES.R -> {
                try {
                    val intent = Intent(Settings.ACTION_MANAGE_APP_ALL_FILES_ACCESS_PERMISSION).apply {
                        data = Uri.parse("package:$packageName")
                    }
                    startActivity(intent)
                    result.success(mapOf("status" to "requested"))
                } catch (e: Exception) {
                    val intent = Intent(Settings.ACTION_MANAGE_ALL_FILES_ACCESS_PERMISSION)
                    startActivity(intent)
                    result.success(mapOf("status" to "requested"))
                }
            }
            Build.VERSION.SDK_INT >= Build.VERSION_CODES.M -> {
                ActivityCompat.requestPermissions(
                    this,
                    arrayOf(
                        Manifest.permission.READ_EXTERNAL_STORAGE,
                        Manifest.permission.WRITE_EXTERNAL_STORAGE
                    ),
                    REQUEST_CODE_STORAGE_PERMISSION
                )
            }
            else -> {
                result.success("granted")
            }
        }
    }

    private fun setRequestPermissionPreference(requestPermission: Boolean) {
        val sharedPreferences = getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        with(sharedPreferences.edit()) {
            putBoolean(PREF_REQUEST_PERMISSION, requestPermission)
            apply()
        }
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)

        if (requestCode == REQUEST_CODE_STORAGE_PERMISSION) {
            val status = if (grantResults.isNotEmpty() && grantResults[0] == PackageManager.PERMISSION_GRANTED) {
                "granted"
            } else {
                "denied"
            }
            pendingResult?.success(mapOf("status" to status))
            pendingResult = null
        }
    }

    private fun pickPdfFile(result: MethodChannel.Result) {
        try {
            val intent = Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
                addCategory(Intent.CATEGORY_OPENABLE)
                type = "application/pdf"
                addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                addFlags(Intent.FLAG_GRANT_PERSISTABLE_URI_PERMISSION)
            }
            
            // Store the result for use in onActivityResult
            pendingResult = result
            
            // Start the file picker activity
            startActivityForResult(intent, REQUEST_CODE_PICK_PDF)
        } catch (e: Exception) {
            result.error("PICKER_ERROR", "Error launching file picker: ${e.message}", null)
        }
    }

    private fun openAppSettings(result: MethodChannel.Result) {
        try {
            val intent = Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
                data = Uri.fromParts("package", packageName, null)
            }
            startActivity(intent)
            result.success(null)
        } catch (e: Exception) {
            result.error("SETTINGS_OPEN_ERROR", e.message, null)
        }
    }

    // Handle external storage paths
    private fun getExternalStoragePaths(result: MethodChannel.Result) {
        val paths: MutableSet<String> = mutableSetOf()

        // Add Download directory
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            paths.add(Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_DOWNLOADS).absolutePath)
        }

        // Add common directories
        Environment.getExternalStorageDirectory().absolutePath.let { mainPath ->
            paths.add(mainPath)
            paths.add("$mainPath/Download")
            paths.add("$mainPath/Downloads")
            paths.add("$mainPath/Documents")
        }

        // Add app-specific directories
        ContextCompat.getExternalFilesDirs(this, null).forEach { file ->
            if (file != null) {
                paths.add(file.absolutePath.substringBefore("/Android"))
            }
        }

        Log.d(TAG, "Available paths: ${paths.joinToString()}")
        result.success(paths.toList())
    }

    // Renamed to avoid conflict with MethodCallHandler from Flutter to Native
    private fun openPdfExternally(filePath: String, result: MethodChannel.Result) {
        try {
            val file = File(filePath)
            if (file.exists()) {
                val uri: Uri = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
                    FileProvider.getUriForFile(
                        this,
                        "$packageName.fileprovider",
                        file
                    )
                } else {
                    Uri.fromFile(file)
                }

                val intent = Intent(Intent.ACTION_VIEW).apply {
                    setDataAndType(uri, "application/pdf")
                    flags = Intent.FLAG_ACTIVITY_NO_HISTORY or Intent.FLAG_GRANT_READ_URI_PERMISSION
                }

                // Verify that there is an app to handle the intent
                if (intent.resolveActivity(packageManager) != null) {
                    startActivity(intent)
                    result.success(null)
                } else {
                    result.error("NO_APP_FOUND", "No application found to open PDF", null)
                }
            } else {
                result.error("FILE_NOT_FOUND", "File not found at path: $filePath", null)
            }
        } catch (e: Exception) {
            result.error("OPEN_PDF_ERROR", e.message, null)
        }
    }

    // Handle the result from the file picker
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)

        if (requestCode == REQUEST_CODE_PICK_PDF) {
            if (resultCode == RESULT_OK && data != null) {
                val uri: Uri? = data.data
                if (uri != null) {
                    try {
                        // Take persistent permissions for future access
                        val takeFlags: Int = Intent.FLAG_GRANT_READ_URI_PERMISSION or
                                Intent.FLAG_GRANT_WRITE_URI_PERMISSION
                        contentResolver.takePersistableUriPermission(uri, takeFlags)

                        // Convert URI to file path
                        val filePath = getFilePathFromUri(uri)
                        if (filePath != null) {
                            Log.d(TAG, "Picked file path: $filePath")
                            pendingResult?.success(filePath)
                        } else {
                            pendingResult?.error("PATH_ERROR", "Could not resolve file path", null)
                        }
                    } catch (e: Exception) {
                        pendingResult?.error("PERMISSION_ERROR", "Error getting file permissions: ${e.message}", null)
                    }
                } else {
                    pendingResult?.error("NO_URI", "No file URI received", null)
                }
            } else {
                pendingResult?.error("CANCELLED", "File picking was cancelled", null)
            }
            pendingResult = null
        }
        if (requestCode == REQUEST_CODE_MANAGE_EXTERNAL_STORAGE) {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                if (Environment.isExternalStorageManager()) {
                    pendingResult?.success("granted")
                } else {
                    pendingResult?.success("denied")
                }
                pendingResult = null
            }
        }
    }

    private fun renderPdfPage(filePath: String, pageNumber: Int, zoomLevel: Double): ByteArray {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.LOLLIPOP) {
            throw Exception("PdfRenderer requires API level 21+")
        }

        // Decode the file path
        val decodedFilePath = Uri.decode(filePath)

        // Use decodedFilePath instead of filePath
        val file = File(decodedFilePath)
        if (!file.exists()) {
            throw Exception("File does not exist at $decodedFilePath")
        }

        val fileDescriptor = ParcelFileDescriptor.open(file, ParcelFileDescriptor.MODE_READ_ONLY)
        val renderer = PdfRenderer(fileDescriptor)

        if (pageNumber < 0 || pageNumber >= renderer.pageCount) {
            renderer.close()
            throw Exception("Invalid page number $pageNumber")
        }

        val page = renderer.openPage(pageNumber)
        val width = (page.width * zoomLevel).toInt()
        val height = (page.height * zoomLevel).toInt()

        val bitmap = Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888)
        page.render(bitmap, null, null, PdfRenderer.Page.RENDER_MODE_FOR_DISPLAY)
        page.close()
        renderer.close()
        fileDescriptor.close()

        val stream = ByteArrayOutputStream()
        bitmap.compress(Bitmap.CompressFormat.PNG, 100, stream)
        bitmap.recycle()

        return stream.toByteArray()
    }

    private fun getPdfPageCount(filePath: String): Int {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.LOLLIPOP) {
            throw Exception("PdfRenderer requires API level 21+")
        }

        // Decode the file path
        val decodedFilePath = Uri.decode(filePath)

        // Use decodedFilePath instead of filePath
        val file = File(decodedFilePath)
        if (!file.exists()) {
            throw Exception("File does not exist at $decodedFilePath")
        }

        val fileDescriptor = ParcelFileDescriptor.open(file, ParcelFileDescriptor.MODE_READ_ONLY)
        val renderer = PdfRenderer(fileDescriptor)
        val pageCount = renderer.pageCount
        renderer.close()
        fileDescriptor.close()

        return pageCount
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        if (Intent.ACTION_VIEW == intent.action) {
            handleIntent(intent)
        }
        super.onCreate(savedInstanceState)
    }

    override fun getInitialRoute(): String? {
        return intent.getStringExtra("route") ?: "/"
    }

    private fun checkStoragePermission(result: MethodChannel.Result) {
        when {
            Build.VERSION.SDK_INT >= Build.VERSION_CODES.R -> {
                if (Environment.isExternalStorageManager()) {
                    result.success("granted")
                } else {
                    result.success("denied")
                }
            }
            Build.VERSION.SDK_INT >= Build.VERSION_CODES.M -> {
                val readPermission = ContextCompat.checkSelfPermission(this, Manifest.permission.READ_EXTERNAL_STORAGE)
                val writePermission = ContextCompat.checkSelfPermission(this, Manifest.permission.WRITE_EXTERNAL_STORAGE)
                if (readPermission == PackageManager.PERMISSION_GRANTED &&
                    writePermission == PackageManager.PERMISSION_GRANTED) {
                    result.success("granted")
                } else {
                    result.success("denied")
                }
            }
            else -> {
                result.success("granted")
            }
        }
    }
}
package androidtv.pdfviewer.redflute

import android.content.Context
import android.graphics.Bitmap
import android.graphics.pdf.PdfRenderer
import android.os.ParcelFileDescriptor
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream
import java.io.File
import kotlinx.coroutines.*
import android.graphics.Point
import android.view.Display
import android.view.WindowManager

class PdfRendererPlugin : FlutterPlugin, MethodChannel.MethodCallHandler {
    private lateinit var channel: MethodChannel
    private lateinit var context: Context
    private var renderer: PdfRenderer? = null
    private var currentFile: ParcelFileDescriptor? = null
    private var currentPage: PdfRenderer.Page? = null
    private val lock = Any()
    private val scope = CoroutineScope(Dispatchers.Default + Job())

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel = MethodChannel(binding.binaryMessenger, "androidtv.pdfviewer.redflute/pdf_renderer")
        channel.setMethodCallHandler(this)
        context = binding.applicationContext
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "renderPage" -> {
                val filePath = call.argument<String>("filePath")
                val pageNumber = call.argument<Int>("pageNumber")
                val scale = call.argument<Double>("scale")
                val quality = call.argument<Double>("quality")

                if (filePath == null || pageNumber == null || scale == null || quality == null) {
                    result.error("INVALID_ARGUMENT", "Missing required arguments", null)
                    return
                }

                scope.launch {
                    try {
                        val imageBytes = renderPageAsync(filePath, pageNumber, scale, quality)
                        withContext(Dispatchers.Main) {
                            result.success(imageBytes)
                        }
                    } catch (e: Exception) {
                        withContext(Dispatchers.Main) {
                            result.error("RENDER_ERROR", e.message, null)
                        }
                    }
                }
            }
            else -> result.notImplemented()
        }
    }

    private suspend fun renderPageAsync(
        filePath: String,
        pageNumber: Int,
        scale: Double,
        quality: Double
    ): ByteArray = withContext(Dispatchers.IO) {
        synchronized(lock) {
            var localRenderer: PdfRenderer? = null
            var localPage: PdfRenderer.Page? = null
            var fileDescriptor: ParcelFileDescriptor? = null
            
            try {
                val file = File(filePath)
                if (!file.exists()) {
                    throw Exception("PDF file not found at $filePath")
                }

                fileDescriptor = ParcelFileDescriptor.open(file, ParcelFileDescriptor.MODE_READ_ONLY)
                localRenderer = PdfRenderer(fileDescriptor)

                if (pageNumber < 0 || pageNumber >= localRenderer.pageCount) {
                    throw Exception("Invalid page number: $pageNumber")
                }

                // Close previous page if exists
                currentPage?.close()
                currentPage = null

                // Open new page
                localPage = localRenderer.openPage(pageNumber)
                currentPage = localPage

                val originalWidth = localPage.width
                val originalHeight = localPage.height

                // Calculate scaled dimensions maintaining aspect ratio
                val scaledWidth = (originalWidth * scale * quality).toInt()
                val scaledHeight = (originalHeight * scale * quality).toInt()

                val bitmap = Bitmap.createBitmap(
                    scaledWidth,
                    scaledHeight,
                    Bitmap.Config.ARGB_8888
                )

                localPage.render(
                    bitmap,
                    null,
                    null,
                    PdfRenderer.Page.RENDER_MODE_FOR_DISPLAY
                )

                // Convert bitmap to PNG bytes
                val stream = ByteArrayOutputStream()
                bitmap.compress(Bitmap.CompressFormat.PNG, (quality * 100).toInt(), stream)
                bitmap.recycle()

                return@synchronized stream.toByteArray()
            } catch (e: Exception) {
                throw Exception("Failed to render page: ${e.message}")
            } finally {
                try {
                    localPage?.close()
                    if (localPage === currentPage) {
                        currentPage = null
                    }
                    localRenderer?.close()
                    fileDescriptor?.close()
                } catch (e: Exception) {
                    // Log cleanup errors but don't throw
                    println("Error cleaning up resources: ${e.message}")
                }
            }
        }
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        synchronized(lock) {
            try {
                currentPage?.close()
                currentPage = null
                renderer?.close()
                renderer = null
                currentFile?.close()
                currentFile = null
            } catch (e: Exception) {
                // Log cleanup errors
                println("Error cleaning up resources on detach: ${e.message}")
            } finally {
                channel.setMethodCallHandler(null)
                scope.cancel()
            }
        }
    }
}
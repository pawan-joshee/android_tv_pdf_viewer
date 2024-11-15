// pdf_renderer_platform.dart

import 'package:flutter/services.dart';

class PdfRendererPlatform {
  // Updated MethodChannel name to match Kotlin's CHANNEL
  static const MethodChannel _channel =
      MethodChannel('androidtv.pdfviewer.redflute/pdf');

  /// Renders a page and returns the image bytes.
  static Future<Uint8List> renderPage(
    String filePath,
    int pageNumber, {
    double scale = 1.0,
    double quality = 1.0,
  }) async {
    try {
      final result = await _channel.invokeMethod('renderPage', {
        'filePath': filePath,
        'pageNumber': pageNumber,
        'scale': scale,
        'quality': quality,
      });
      return result;
    } catch (e) {
      rethrow;
    }
  }

  /// Retrieves the total number of pages in the PDF.
  static Future<int> getPageCount(String filePath) async {
    try {
      final int pageCount = await _channel.invokeMethod('getPageCount', {
        'filePath': filePath,
      });
      return pageCount;
    } on PlatformException catch (e) {
      throw Exception('Failed to get page count: ${e.message}');
    }
  }
}

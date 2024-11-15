// pdf_renderer.dart
import 'dart:async';
import 'dart:developer';

import 'package:flutter/services.dart';

class PdfRenderer {
  static const MethodChannel _channel =
      MethodChannel('androidtv.pdfviewer.redflute/pdf_renderer');

  // Singleton pattern to manage the renderer instance
  static final PdfRenderer _instance = PdfRenderer._internal();
  factory PdfRenderer() => _instance;
  PdfRenderer._internal();

  /// Renders a PDF page and returns the image bytes.
  Future<Uint8List> renderPage(
    String filePath,
    int pageNumber,
    double scale, {
    double quality = 1.0, // Add quality parameter with default value
  }) async {
    try {
      // Validate arguments before sending to platform
      if (filePath.isEmpty) {
        throw PlatformException(
          code: 'INVALID_ARGUMENT',
          message: 'File path cannot be empty',
        );
      }

      if (pageNumber < 0) {
        throw PlatformException(
          code: 'INVALID_ARGUMENT',
          message: 'Page number must be non-negative',
        );
      }

      if (scale <= 0 || scale > 5.0) {
        throw PlatformException(
          code: 'INVALID_ARGUMENT',
          message: 'Scale must be between 0 and 5.0',
        );
      }

      if (quality <= 0 || quality > 1.0) {
        throw PlatformException(
          code: 'INVALID_ARGUMENT',
          message: 'Quality must be between 0 and 1.0',
        );
      }

      final result = await _channel.invokeMethod<Uint8List>('renderPage', {
        'filePath': filePath,
        'pageNumber': pageNumber,
        'scale': scale,
        'quality': quality,
      });

      if (result == null) {
        throw PlatformException(
          code: 'RENDER_ERROR',
          message: 'Failed to render page $pageNumber',
        );
      }

      return result;
    } on PlatformException catch (e) {
      log('Platform error rendering page: $e');
      rethrow;
    } catch (e) {
      log('Error rendering page: $e');
      throw PlatformException(
        code: 'RENDER_ERROR',
        message: 'Failed to render page: $e',
      );
    }
  }

  /// Dispose method for cleaning up resources if needed
  void dispose() {
    // Implement any necessary cleanup
  }
}

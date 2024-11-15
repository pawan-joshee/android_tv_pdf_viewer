// lib/services/native_pdf_service.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class NativePdfService {
  static const MethodChannel _platform =
      MethodChannel('androidtv.pdfviewer.redflute/pdf');

  // Singleton pattern
  static final NativePdfService _instance = NativePdfService._internal();

  factory NativePdfService() {
    return _instance;
  }

  NativePdfService._internal();

  void setMethodCallHandler(Future<dynamic> Function(MethodCall call) handler) {
    _platform.setMethodCallHandler(handler);
  }

  // Method to get external storage paths
  Future<List<String>> getExternalStoragePaths() async {
    try {
      final List<dynamic>? paths =
          await _platform.invokeMethod('getExternalStoragePaths');
      return paths?.cast<String>() ?? [];
    } on PlatformException catch (e) {
      debugPrint('Failed to get external storage paths: ${e.message}');
      return [];
    }
  }

  Future<String?> pickPdfFile() async {
    try {
      final String? result = await _platform.invokeMethod('pickPdfFile');
      return result;
    } on PlatformException catch (e) {
      debugPrint('Error picking PDF file: ${e.message}');
      if (e.code == 'CANCELLED') {
        return null;
      }
      rethrow;
    }
  }
}

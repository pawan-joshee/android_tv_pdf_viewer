import 'package:flutter/services.dart';

// purpose to  use later for low end devices.
class PlatformDeviceMetrics {
  static const MethodChannel _channel =
      MethodChannel('androidtv.pdfviewer.redflute/device_metrics');

  /// Get available memory in MB
  static Future<double> getAvailableMemory() async {
    try {
      final double memory = await _channel.invokeMethod('getAvailableMemory');
      return memory;
    } catch (e) {
      return -1;
    }
  }

  /// Get CPU usage percentage
  static Future<double> getCpuUsage() async {
    try {
      final double cpuUsage = await _channel.invokeMethod('getCpuUsage');
      return cpuUsage;
    } catch (e) {
      return -1;
    }
  }
}

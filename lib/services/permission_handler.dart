import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class PermissionHandler {
  static const MethodChannel _channel =
      MethodChannel('androidtv.pdfviewer.redflute/pdf');

  static final PermissionHandler _instance = PermissionHandler._internal();
  factory PermissionHandler() => _instance;
  PermissionHandler._internal();

  Future<PermissionStatus> checkStoragePermission() async {
    try {
      final String status =
          await _channel.invokeMethod('checkStoragePermission');
      return _parsePermissionStatus(status);
    } on PlatformException {
      return PermissionStatus.unknown;
    }
  }

  Future<PermissionStatus> requestStoragePermission() async {
    try {
      final Map<dynamic, dynamic> response =
          await _channel.invokeMethod('requestStoragePermission');
      final String status = response['status'];
      return _parsePermissionStatus(status);
    } on PlatformException {
      return PermissionStatus.unknown;
    }
  }

  Future<String?> pickPdfFile() async {
    try {
      final String? path = await _channel.invokeMethod('pickPdfFile');
      return path;
    } on PlatformException {
      return null;
    }
  }

  Future<void> openAppSettings() async {
    try {
      await _channel.invokeMethod('openAppSettings');
    } on PlatformException {
      // Handle exception as needed
    }
  }

  PermissionStatus _parsePermissionStatus(String? status) {
    switch (status?.toLowerCase()) {
      case 'granted':
        return PermissionStatus.granted;
      case 'denied':
        return PermissionStatus.denied;
      case 'requested':
        return PermissionStatus.rationaleNeeded;
      default:
        return PermissionStatus.unknown;
    }
  }
}

enum PermissionStatus {
  granted,
  denied,
  rationaleNeeded,
  permanentlyDenied,
  unknown
}

class PdfServiceException implements Exception {
  final String message;
  PdfServiceException(this.message);

  @override
  String toString() => 'PdfServiceException: $message';
}

class PermissionDeniedException extends PdfServiceException {
  PermissionDeniedException(super.message);
}

class PermissionWidget extends StatefulWidget {
  final Widget child;
  final Widget Function(BuildContext, PermissionStatus) permissionBuilder;

  const PermissionWidget({
    super.key,
    required this.child,
    required this.permissionBuilder,
  });

  @override
  State<PermissionWidget> createState() => _PermissionWidgetState();
}

class _PermissionWidgetState extends State<PermissionWidget>
    with WidgetsBindingObserver {
  PermissionStatus _status = PermissionStatus.unknown;
  bool _isChecking = false;
  final PermissionHandler _permissionHandler = PermissionHandler();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkPermission();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkPermission();
    }
  }

  Future<void> _checkPermission() async {
    if (_isChecking) return;

    setState(() => _isChecking = true);
    try {
      final status = await _permissionHandler.checkStoragePermission();
      if (status == PermissionStatus.denied) {
        // Request permission explicitly if denied
        final requestStatus =
            await _permissionHandler.requestStoragePermission();
        if (mounted) {
          setState(() => _status = requestStatus);
        }
      } else {
        setState(() => _status = status);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _status = PermissionStatus.unknown);
      }
      debugPrint('Permission check failed: $e');
    } finally {
      if (mounted) {
        setState(() => _isChecking = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_status == PermissionStatus.granted) {
      return widget.child;
    } else {
      return widget.permissionBuilder(context, _status);
    }
  }
}

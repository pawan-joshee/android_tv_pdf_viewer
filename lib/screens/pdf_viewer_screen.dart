import 'dart:async';
import 'dart:developer';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/pdf_renderer.dart';
import '../services/pdf_renderer_platform.dart';

/// A basic PDF document representation.
class PdfDocument {
  Uint8List data;
  int pageCount;

  PdfDocument(this.data, this.pageCount);

  /// Dispose method for cleaning up resources.
  void dispose() {
    // Currently, there are no resources to dispose.
    // Implement resource cleanup here if needed in the future.
  }

  /// Parses the PDF data and retrieves page count from native code.
  static Future<PdfDocument> parse(String filePath) async {
    try {
      // Read the PDF file as bytes
      final bytes = await readPdfFile(filePath);

      // Get the page count from native code
      final pageCount = await PdfRendererPlatform.getPageCount(filePath);

      return PdfDocument(bytes, pageCount);
    } catch (e) {
      log('Error parsing PDF: $e');
      throw Exception('PDF file not found at: $filePath');
    }
  }
}

/// Reads the PDF file as bytes.
Future<Uint8List> readPdfFile(String filePath) async {
  try {
    final file = File(filePath);
    if (!await file.exists()) {
      throw Exception('PDF file not found at $filePath');
    }

    return await file.readAsBytes();
  } catch (e) {
    log('Error reading PDF file: $e');
    throw Exception('Error reading PDF file: $e');
  }
}

/// Converts a [ui.Image] to PNG bytes.
Future<Uint8List> imageToBytes(ui.Image image) async {
  final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
  return byteData!.buffer.asUint8List();
}

/// A StatefulWidget that displays a PDF document.
class PdfViewerScreen extends StatefulWidget {
  final String filePath;

  const PdfViewerScreen({super.key, required this.filePath});

  @override
  PdfViewerScreenState createState() => PdfViewerScreenState();
}

class PdfViewerScreenState extends State<PdfViewerScreen>
    with SingleTickerProviderStateMixin {
  // PDF document and rendering state.
  bool isLoading = true;
  PdfDocument? _document;
  final PdfRenderer _renderer = PdfRenderer();

  // Zooming
  double _zoomLevel = 1.0;

  // Scroll controller for vertical scrolling.
  final ScrollController _scrollController = ScrollController();

  // Cache for rendered pages.
  final Map<int, Uint8List> _pageCache = {};

  // Focus nodes for handling keyboard events.
  final FocusNode _focusNode = FocusNode();

  // Add these new properties
  int _currentPage = 0;
  Timer? _zoomIndicatorTimer;

  // Add these properties
  bool _isZoomMode = false;
  final double _zoomStep = 0.1;

  // Add transform controller
  final TransformationController _transformationController =
      TransformationController();

  // Add this field at the top of the class with other fields
  bool _isOptionsMenuOpen = false;
  bool _isNavigating = false;

  @override
  void initState() {
    super.initState();
    _loadAndParsePdf(widget.filePath); // Use the filePath directly
    // Request focus after initialization
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _document?.dispose();
    _focusNode.dispose();
    _scrollController.dispose();
    _renderer.dispose(); // Dispose the renderer to kill isolates
    _zoomIndicatorTimer?.cancel();
    _transformationController.dispose();
    super.dispose();
  }

  /// Loads and parses the PDF document.
  Future<void> _loadAndParsePdf(String path) async {
    try {
      final document = await PdfDocument.parse(path);
      setState(() {
        _document = document;
        isLoading = false;
      });
    } catch (e, stackTrace) {
      log('Error loading PDF: $e');
      log('Stack trace: $stackTrace');
      _showLoadError(e);
    }
  }

  /// Displays a SnackBar with the loading error.
  void _showLoadError(Object error) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to load PDF: ${error.toString()}'),
          duration: const Duration(seconds: 5),
          action: SnackBarAction(
            label: 'Go Back',
            onPressed: () {
              Navigator.of(context).pop();
            },
          ),
        ),
      );
    }
  }

  /// Renders a PDF page and returns the image bytes.
  Future<Uint8List> _getPageImage(int pageNumber) async {
    if (_pageCache.containsKey(pageNumber)) {
      return _pageCache[pageNumber]!;
    }

    try {
      final imageBytes = await _renderer.renderPage(
        widget.filePath,
        pageNumber,
        1.0, // Always render at base scale
      );

      if (imageBytes.isEmpty) {
        throw PlatformException(
          code: 'RENDER_ERROR',
          message: 'Failed to render page $pageNumber: Empty result',
        );
      }

      _pageCache[pageNumber] = imageBytes;
      return imageBytes;
    } catch (e) {
      log('Error rendering page $pageNumber: $e');
      rethrow;
    }
  }

  /// Building the loading indicator.
  Widget _buildLoading() {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.black54,
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 40,
              height: 40,
              child: CircularProgressIndicator(
                strokeWidth: 3,
              ),
            ),
            SizedBox(height: 16),
            Text(
              'Loading PDF...',
              style: TextStyle(color: Colors.green),
            ),
          ],
        ),
      ),
    );
  }

  /// Building the PDF view.
  Widget _buildPdfView() {
    return OrientationBuilder(
      builder: (context, orientation) {
        return Container(
          color: Colors.grey[900], // Match the page background
          child: KeyboardListener(
            focusNode: _focusNode, // Remove the cascading focus request
            autofocus: true, // Add autofocus
            onKeyEvent: (event) => _handleKeyEvent(event),
            child: Stack(
              children: [
                InteractiveViewer(
                  transformationController: _transformationController,
                  scaleEnabled: true,
                  panEnabled:
                      _zoomLevel > 1.0, // Enable panning for zoomed content
                  minScale: 0.5,
                  maxScale: 3.0,
                  child: CustomScrollView(
                    controller: _scrollController,
                    physics: const BouncingScrollPhysics(),
                    slivers: [
                      SliverPadding(
                        padding: const EdgeInsets.symmetric(vertical: 20),
                        sliver: SliverList(
                          delegate: SliverChildBuilderDelegate(
                            (context, index) {
                              return Padding(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 10),
                                child: FutureBuilder<Uint8List>(
                                  future: _getPageImage(index),
                                  builder: (context, pageSnapshot) {
                                    if (pageSnapshot.connectionState ==
                                        ConnectionState.waiting) {
                                      return _buildLoadingPage(context);
                                    } else if (pageSnapshot.hasError) {
                                      return _buildPageError(
                                          index, pageSnapshot.error);
                                    } else {
                                      return _buildPage(
                                          context, index, pageSnapshot.data!);
                                    }
                                  },
                                ),
                              );
                            },
                            childCount: _document?.pageCount ?? 0,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                // Zoom mode indicator
                if (_isZoomMode)
                  Positioned(
                    top: 20,
                    left: 20,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.blue.withOpacity(0.8),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.zoom_in,
                            color: Colors.white,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Zoom Mode (${(_zoomLevel * 100).toInt()}%)',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                // Help text
                Positioned(
                  bottom: 20,
                  right: 20,
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      _isZoomMode
                          ? 'Up/Down: Zoom In/Out | Center: Exit Zoom'
                          : 'Center: Enter Zoom | Left/Right: Pages',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
                // Add zoom indicator overlay

                // Add page indicator
                Positioned(
                  bottom: 20,
                  left: 20,
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'Page ${_currentPage + 1} of ${_document?.pageCount ?? 1}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildLoadingPage(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.9,
      margin: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: Colors.grey[800],
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Center(
        child: SizedBox(
          width: 30,
          height: 30,
          child: CircularProgressIndicator(
            strokeWidth: 2,
          ),
        ),
      ),
    );
  }

  Widget _buildPageError(int index, dynamic error) {
    return Container(
      height: MediaQuery.of(context).size.height,
      color: Colors.grey[200],
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 48, color: Colors.red),
          const SizedBox(height: 16),
          Text(
            'Error rendering page ${index + 1}',
            style: const TextStyle(color: Colors.red),
          ),
          const SizedBox(height: 8),
          ElevatedButton(
            onPressed: () {
              // Clear cache for this page and trigger a rebuild
              _pageCache.remove(index);
              setState(() {});
            },
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildPage(BuildContext context, int index, Uint8List pageData) {
    return LayoutBuilder(
      builder: (context, constraints) {
        double maxWidth = constraints.maxWidth * 0.9;
        double aspectRatio = 1 / math.sqrt2; // Standard A4 aspect ratio

        double adjustedWidth = maxWidth * _zoomLevel; // Apply zoom to width
        double adjustedHeight = adjustedWidth / aspectRatio;

        return Container(
          width: constraints.maxWidth,
          color: Colors.grey[900],
          child: Center(
            child: Container(
              width: adjustedWidth,
              height: adjustedHeight,
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 10,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: Image.memory(
                pageData,
                fit: BoxFit.contain,
                width: adjustedWidth,
                height: adjustedHeight,
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      onPopInvokedWithResult: _handleWillPop,
      child: Scaffold(
        backgroundColor: Colors.grey[900],
        body: SafeArea(
          child: isLoading
              ? _buildLoading()
              : _buildPdfView(), // Remove the Focus widget wrapper
        ),
      ),
    );
  }

  void _handleWillPop(bool didPop, dynamic result) async {
    if (didPop) return;

    if (!mounted) return;

    // Check if we're currently processing a navigation
    if (_isNavigating) return;
    _isNavigating = true;

    try {
      if (_isOptionsMenuOpen) {
        setState(() {
          _isOptionsMenuOpen = false;
        });
      } else {
        Navigator.of(context).pop();
      }
    } finally {
      _isNavigating = false;
    }
  }

  /// Handles keyboard events for navigation and zooming.
  void _handleKeyEvent(KeyEvent event) {
    if (!mounted || isLoading) return; // Ignore events while loading

    if (event is KeyDownEvent) {
      switch (event.logicalKey) {
        case LogicalKeyboardKey.select:
          _toggleZoomMode();
          break;
        case LogicalKeyboardKey.arrowUp:
          if (_isZoomMode) {
            _zoomIn();
          } else {
            _scroll(-100);
          }
          break;
        case LogicalKeyboardKey.arrowDown:
          if (_isZoomMode) {
            _zoomOut();
          } else {
            _scroll(100);
          }
          break;
        case LogicalKeyboardKey.arrowLeft:
          if (!_isZoomMode) {
            _jumpToPreviousPage();
          }
          break;
        case LogicalKeyboardKey.arrowRight:
          if (!_isZoomMode) {
            _jumpToNextPage();
          }
          break;
        default:
          break;
      }
    }
  }

  void _scroll(double delta) {
    if (!_scrollController.hasClients) return;

    final newOffset = (_scrollController.offset + delta)
        .clamp(0.0, _scrollController.position.maxScrollExtent);

    _scrollController.animateTo(
      newOffset.toDouble(),
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOut,
    );
  }

  void _jumpToPage(int page) {
    if (!_scrollController.hasClients || isLoading) return;

    setState(() {
      _currentPage = page.clamp(0, (_document?.pageCount ?? 1) - 1);
    });

    // Use estimated page height for smoother scrolling
    final estimatedPageHeight = MediaQuery.of(context).size.height * 0.9;
    const spacing = 20.0; // Spacing between pages
    final targetOffset = _currentPage * (estimatedPageHeight + spacing);

    _scrollController.animateTo(
      targetOffset,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  void _jumpToPreviousPage() {
    _jumpToPage(_currentPage - 1);
  }

  void _jumpToNextPage() {
    _jumpToPage(_currentPage + 1);
  }

  void _toggleZoomMode() {
    setState(() {
      _isZoomMode = !_isZoomMode;
    });
    _resetZoomIndicatorTimer();
  }

  void _zoomIn() {
    setState(() {
      _zoomLevel = (_zoomLevel + _zoomStep).clamp(0.5, 3.0);
      _updateTransformMatrix();
    });
    _resetZoomIndicatorTimer();
  }

  void _zoomOut() {
    setState(() {
      _zoomLevel = (_zoomLevel - _zoomStep).clamp(0.5, 3.0);
      _updateTransformMatrix();
    });
    _resetZoomIndicatorTimer();
  }

  void _updateTransformMatrix() {
    final Matrix4 matrix = Matrix4.identity()
      ..scale(_zoomLevel, _zoomLevel, 1.0);
    _transformationController.value = matrix;
  }

  void _resetZoomIndicatorTimer() {
    _zoomIndicatorTimer?.cancel();
    _zoomIndicatorTimer = Timer(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() {});
      }
    });
  }
}

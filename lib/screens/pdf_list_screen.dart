import 'dart:async';
import 'dart:developer';
import 'dart:io';
import 'dart:isolate';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/theme.dart';
import 'pdf_viewer_screen.dart';

class PdfListScreen extends StatefulWidget {
  final String folderPath;

  const PdfListScreen({super.key, required this.folderPath});

  @override
  State<PdfListScreen> createState() => _PdfListScreenState();
}

class _PdfListScreenState extends State<PdfListScreen> {
  List<File> _pdfFiles = [];
  SortOrder _sortOrder = SortOrder.dateDesc;
  bool _isLoading = false;
  final FocusNode _listFocusNode = FocusNode();
  final ScrollController _scrollController = ScrollController();
  int _focusedIndex = 0;
  bool _showSortMenu = false;
  int _sortMenuIndex = 0;
  final List<String> _sortOptions = [
    'Date ↓ (Newest First)',
    'Date ↑ (Oldest First)',
    'Name ↑ (A-Z)',
    'Name ↓ (Z-A)',
  ];
  DateTime _lastKeyPressTime = DateTime.now();
  static const _keyPressDebounceTime = Duration(milliseconds: 150);

  @override
  void initState() {
    super.initState();
    _listFocusNode.addListener(_handleFocusChange);
    log('PdfListScreen initialized with folderPath: ${widget.folderPath}');

    _loadFiles();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _listFocusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _listFocusNode.dispose();
    super.dispose();
  }

  void _handleFocusChange() {
    if (_listFocusNode.hasFocus && _focusedIndex == _pdfFiles.length - 1) {
      // Do nothing, as all files are already loaded
    }
  }

  Future<void> _loadFiles() async {
    if (_isLoading) return;
    setState(() {
      _isLoading = true;
    });

    final receivePort = ReceivePort();
    await Isolate.spawn(
      loadFilesInIsolate,
      LoadFilesParams(widget.folderPath, receivePort.sendPort),
    );

    receivePort.listen((data) {
      if (data is List<File>) {
        setState(() {
          _pdfFiles = data;
          log('Received ${_pdfFiles.length} PDF files from isolate.');
        });
        _sortPdfFiles(); // Optionally sort after loading
      }
      setState(() {
        _isLoading = false;
      });
    });
  }

  void _sortPdfFiles() async {
    final receivePort = ReceivePort();
    await Isolate.spawn(
      sortFilesInIsolate,
      SortFilesParams(_pdfFiles, _sortOrder, receivePort.sendPort),
    );

    receivePort.listen((data) {
      if (data is List<File>) {
        setState(() {
          _pdfFiles = data;
          log('PDF files sorted. Total files: ${_pdfFiles.length}');
        });
      }
    });
  }

  void _scrollToFocusedItem() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _focusedIndex * 70.0, // Adjust the height based on your ListTile height
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _focusedIndex *
                70.0, // Adjust the height based on your ListTile height
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
          );
        }
      });
    }
  }

  bool _shouldHandleKeyPress() {
    final now = DateTime.now();
    if (now.difference(_lastKeyPressTime) < _keyPressDebounceTime) {
      return false;
    }
    _lastKeyPressTime = now;
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final customColors = Theme.of(context).extension<CustomColors>();

    return PopScope(
      canPop: !_showSortMenu,
      onPopInvokedWithResult: (bool didPop, dynamic result) async {
        if (!didPop) {
          setState(() => _showSortMenu = false);
        }
      },
      child: KeyboardListener(
        focusNode: FocusNode(),
        onKeyEvent: (KeyEvent event) {
          if (event is KeyDownEvent) {
            if (_showSortMenu) {
              _handleSortMenuNavigation(event);
            } else {
              _handleMainListNavigation(event);
            }
          }
        },
        child: FocusTraversalGroup(
          child: Scaffold(
            body: Stack(
              children: [
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        customColors!.gradientStart,
                        customColors.gradientEnd,
                      ],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                  ),
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Press BACK to exit, Left Arrow to sort',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.7),
                                fontSize: 16,
                              ),
                            ),
                            Text(
                              'Sort: ${_sortOptions[_sortOrder.index]}',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.7),
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: _buildMainContent(),
                      ),
                    ],
                  ),
                ),
                if (_showSortMenu) _buildSortMenu(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSortMenu() {
    return Center(
      child: Container(
        width: 300,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 10,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(
            _sortOptions.length,
            (index) => _buildSortMenuItem(index),
          ),
        ),
      ),
    );
  }

  Widget _buildSortMenuItem(int index) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        color: _sortMenuIndex == index ? Colors.deepPurple : Colors.transparent,
        borderRadius: BorderRadius.circular(4),
      ),
      child: ListTile(
        title: Text(
          _sortOptions[index],
          style: TextStyle(
            color: _sortMenuIndex == index ? Colors.white : Colors.black,
          ),
        ),
      ),
    );
  }

  Widget _buildMainContent() {
    return _isLoading
        ? const Center(child: CircularProgressIndicator())
        : _pdfFiles.isEmpty
            ? const Center(
                child: Card(
                    child: Padding(
                padding: EdgeInsets.all(8.0),
                child: Text(
                  'No PDF files found.',
                ),
              )))
            : ListView.builder(
                controller: _scrollController,
                itemCount: _pdfFiles.length,
                itemBuilder: (context, index) {
                  final pdfFile = _pdfFiles[index];
                  return _buildListTile(
                    title: pdfFile.path.split('/').last.toUpperCase(),
                    onTap: () =>
                        _navigateToPdfViewerScreen(context, pdfFile.path),
                    isFocused: index == _focusedIndex,
                  );
                },
              );
  }

  void _handleSortMenuNavigation(KeyEvent event) {
    if (!_shouldHandleKeyPress()) return;

    try {
      if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
        setState(() {
          _sortMenuIndex =
              (_sortMenuIndex - 1).clamp(0, _sortOptions.length - 1);
        });
      } else if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
        setState(() {
          _sortMenuIndex =
              (_sortMenuIndex + 1).clamp(0, _sortOptions.length - 1);
        });
      } else if (event.logicalKey == LogicalKeyboardKey.select ||
          event.logicalKey == LogicalKeyboardKey.enter) {
        setState(() {
          _sortOrder = SortOrder.values[_sortMenuIndex];
          _showSortMenu = false;
          _sortPdfFiles();
        });
      } else if (event.logicalKey == LogicalKeyboardKey.escape ||
          event.logicalKey == LogicalKeyboardKey.backspace) {
        setState(() {
          _showSortMenu = false;
        });
      }
    } catch (e) {
      log('Error in sort menu navigation: $e');
    }
  }

  void _handleMainListNavigation(KeyEvent event) {
    if (!_shouldHandleKeyPress()) return;
    if (_pdfFiles.isEmpty) return;

    try {
      if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
        setState(() {
          _focusedIndex = (_focusedIndex + 1).clamp(0, _pdfFiles.length - 1);
          _scrollToFocusedItem();
        });
      } else if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
        setState(() {
          _focusedIndex = (_focusedIndex - 1).clamp(0, _pdfFiles.length - 1);
          _scrollToFocusedItem();
        });
      } else if (event.logicalKey == LogicalKeyboardKey.select ||
          event.logicalKey == LogicalKeyboardKey.enter) {
        if (_pdfFiles.isNotEmpty &&
            _focusedIndex >= 0 &&
            _focusedIndex < _pdfFiles.length) {
          _navigateToPdfViewerScreen(context, _pdfFiles[_focusedIndex].path);
        }
      } else if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
        setState(() {
          _showSortMenu = true;
          _sortMenuIndex = _sortOrder.index;
        });
      }
    } catch (e) {
      log('Error in main list navigation: $e');
    }
  }

  Widget _buildListTile({
    required String title,
    required VoidCallback onTap,
    bool isFocused = false,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
      decoration: BoxDecoration(
        color: isFocused ? Colors.deepPurple : Colors.white.withOpacity(0.8),
        borderRadius: BorderRadius.circular(12.0),
        border: isFocused ? Border.all(color: Colors.white, width: 2.0) : null,
      ),
      child: ListTile(
        title: Text(
          title,
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: isFocused ? Colors.white : Colors.black,
              ),
        ),
        leading: Icon(
          Icons.picture_as_pdf,
          color: isFocused ? Colors.white : Colors.black,
        ),
        onTap: onTap,
        trailing: Icon(
          Icons.arrow_forward_ios,
          color: isFocused ? Colors.white : Colors.black,
        ),
      ),
    );
  }

  void _navigateToPdfViewerScreen(BuildContext context, String filePath) {
    if (!mounted) return;

    Navigator.of(context)
        .push(MaterialPageRoute(
      builder: (context) => PdfViewerScreen(filePath: filePath),
    ))
        .then((_) {
      // Handle any cleanup if needed after returning from PDF viewer
      if (mounted) {
        setState(() {
          // Refresh the list if needed
        });
      }
    });
  }
}

enum SortOrder { ascending, descending, dateAsc, dateDesc }

// Add the isolate helpers (in a separate file if needed)
class LoadFilesParams {
  final String folderPath;
  final SendPort sendPort;

  LoadFilesParams(this.folderPath, this.sendPort);
}

void loadFilesInIsolate(LoadFilesParams params) async {
  List<File> files = await _fetchPdfFiles(params.folderPath);
  params.sendPort.send(files);
}

Future<List<File>> _fetchPdfFiles(String folderPath) async {
  try {
    final directory = Directory(folderPath);
    log('Attempting to access directory: $folderPath');

    if (await directory.exists()) {
      List<File> pdfFiles = [];
      await for (FileSystemEntity entity
          in directory.list(recursive: true, followLinks: false)) {
        if (entity is File) {
          String path = entity.path.toLowerCase();
          if (path.endsWith('.pdf')) {
            // Check if file is readable
            try {
              if (await entity.length() > 0) {
                pdfFiles.add(entity);
                log('Found PDF file: ${entity.path}');
              }
            } catch (e) {
              log('Error accessing file ${entity.path}: $e');
              continue;
            }
          }
        }
      }
      log('Total PDF files found: ${pdfFiles.length}');
      return pdfFiles;
    } else {
      log('Directory does not exist: $folderPath');
      return [];
    }
  } catch (e) {
    log('Error fetching files from $folderPath: $e');
    return [];
  }
}

// Define the SortFilesParams class outside the _PdfListScreenState class
class SortFilesParams {
  final List<File> files;
  final SortOrder sortOrder;
  final SendPort sendPort;

  SortFilesParams(this.files, this.sortOrder, this.sendPort);
}

// Define the sortFilesInIsolate function outside the _PdfListScreenState class
void sortFilesInIsolate(SortFilesParams params) {
  List<File> sortedFiles = List.from(params.files);

  switch (params.sortOrder) {
    case SortOrder.ascending:
      sortedFiles.sort((a, b) => a.path.compareTo(b.path));
      break;
    case SortOrder.descending:
      sortedFiles.sort((a, b) => b.path.compareTo(a.path));
      break;
    case SortOrder.dateAsc:
      sortedFiles.sort(
          (a, b) => a.statSync().modified.compareTo(b.statSync().modified));
      break;
    case SortOrder.dateDesc:
      sortedFiles.sort(
          (a, b) => b.statSync().modified.compareTo(a.statSync().modified));
      break;
  }

  params.sendPort.send(sortedFiles);
}

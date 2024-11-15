// home_screen.dart

import 'dart:developer';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/native_pdf_service.dart';
import '../services/navigation_service.dart';
import '../services/permission_handler.dart';
import '../theme/theme.dart';
import '../utils/custom_page_route.dart';
import '../widgets/animated_icon_widget.dart';
import '../widgets/directory_tile_widget.dart';
import '../widgets/pulsating_circle_widget.dart';
import '../widgets/tv_button_widget.dart';
import 'pdf_list_screen.dart';
import 'pdf_viewer_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  DateTime? currentBackPressTime;
  static const int backPressDelay = 2;

  final ScrollController _scrollController = ScrollController();
  final List<Directory> _directories = [];
  final NativePdfService _nativePdfService = NativePdfService();
  final PermissionHandler _permissionHandler = PermissionHandler();

  bool _isFilePickerActive = false;
  bool _isLoading = true;
  bool isPickingPdf = false;

  // Enhanced focus management
  final FocusNode _pickPdfFocusNode = FocusNode();
  final FocusNode _settingsFocusNode = FocusNode();
  final FocusNode _manageStorageFocusNode = FocusNode();
  final Map<int, FocusNode> _directoryFocusNodes = {};

  // Enhanced animations
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;
  late Animation<double> _slideAnimation;

  // Add permission status state
  PermissionStatus _permissionStatus = PermissionStatus.denied;

  @override
  void initState() {
    super.initState();

    // Initialize enhanced animations
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOutCubic),
    );

    _opacityAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );

    _slideAnimation = Tween<double>(begin: 50.0, end: 0.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOutCubic),
    );

    // Enhanced focus listeners
    _pickPdfFocusNode.addListener(_handleFocusChange);
    _settingsFocusNode.addListener(_handleFocusChange);

    Future.microtask(() {
      _nativePdfService.setMethodCallHandler(_handleMethod);
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      FocusScope.of(context).requestFocus(_pickPdfFocusNode);
      _checkAndLoadDirectories();
      _animationController.forward();
    });
  }

  void _handleFocusChange() {
    HapticFeedback.selectionClick();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _pickPdfFocusNode.removeListener(_handleFocusChange);
    _settingsFocusNode.removeListener(_handleFocusChange);
    _pickPdfFocusNode.dispose();
    _settingsFocusNode.dispose();
    _manageStorageFocusNode.dispose();
    for (var node in _directoryFocusNodes.values) {
      node.dispose();
    }
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _checkAndLoadDirectories() async {
    PermissionStatus status = await _permissionHandler.checkStoragePermission();
    log("Permission status: $status");
    setState(() {
      _permissionStatus = status;
    });
    if (status == PermissionStatus.granted) {
      await _loadDirectories();
    }
  }

  Future<void> _loadDirectories() async {
    try {
      final List<dynamic> dirs =
          await _nativePdfService.getExternalStoragePaths();
      List<Directory> rootDirectories =
          dirs.cast<String>().map((path) => Directory(path)).toList();

      List<Directory> allDirectories = [];

      for (Directory dir in rootDirectories) {
        if (await dir.exists()) {
          await for (FileSystemEntity entity in dir.list(
            recursive: false,
            followLinks: false,
          )) {
            if (entity is Directory) {
              if (!entity.path.split('/').last.startsWith('.')) {
                // Exclude hidden directories
                allDirectories.add(entity);
              }
            }
          }
        }
      }

      setState(() {
        _directories.addAll(allDirectories);
        // sort directories by name
        _directories.sort((a, b) => a.path.compareTo(b.path));
        _isLoading = false;
      });
    } catch (e) {
      log('Error loading directories: $e');
      _showSnackBar('Failed to load directories: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<dynamic> _handleMethod(MethodCall call) async {
    log("Received method call: ${call.method} with arguments: ${call.arguments}");

    switch (call.method) {
      case 'openPdf':
        final String filePath = call.arguments;
        log("Handling 'openPdf' with filePath: $filePath");

        final fileExists = await File(filePath).exists();
        log("File exists: $fileExists");

        if (fileExists) {
          _navigateToPdfViewerScreen(filePath);
        } else {
          _showSnackBar('File does not exist: $filePath');
        }
        break;

      case 'openPdfError':
        final String errorMessage = call.arguments;
        _showSnackBar('Error opening PDF: $errorMessage');
        break;

      default:
        log('Unimplemented method ${call.method}');
        throw MissingPluginException();
    }
  }

  Future<void> _pickPdf() async {
    if (_isFilePickerActive) {
      log("File picker is already active. Ignoring duplicate request.");
      return;
    }

    setState(() {
      _isFilePickerActive = true;
      isPickingPdf = true;
    });

    log("Initiating PDF file picker...");

    try {
      final String? filePath = await _nativePdfService.pickPdfFile();

      if (filePath != null) {
        log("File selected: $filePath");
        final bool fileExists = await File(filePath).exists();

        if (fileExists) {
          _navigateToPdfViewerScreen(filePath);
        } else {
          _showSnackBar(
              'File does not exist at the picked location: $filePath');
        }
      } else {
        log("No file selected");
        _showSnackBar('No file selected');
      }
    } catch (e) {
      log('Error during file picking: $e');
      _showSnackBar('Error: ${e.toString()}');
    } finally {
      if (mounted) {
        setState(() {
          _isFilePickerActive = false;
          isPickingPdf = false;
        });
        log("File picker state reset.");
      }
    }
  }

  void _showSnackBar(String message) {
    final customColors = Theme.of(context).extension<CustomColors>();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
          backgroundColor: customColors?.buttonBackground ?? Colors.deepPurple,
        ),
      );
    }
  }

  void _navigateToPdfViewerScreen(String filePath) {
    log("_navigateToPdfViewerScreen called with filePath: $filePath");
    NavigationService.push(
      FadePageRoute(page: PdfViewerScreen(filePath: filePath)),
    ).then((_) {
      log("Returned from PdfViewerScreen");
      if (mounted) {
        setState(() {
          _isLoading = true;
          _directories.clear();
        });
        _checkAndLoadDirectories();
      }
    }).catchError((error) {
      log("Error navigating to PdfViewerScreen: $error");
      if (mounted) {
        _showSnackBar('Navigation error: $error');
      }
    });
  }

  void _navigateToPdfListScreen(BuildContext context, String folderPath) {
    log("_navigateToPdfListScreen $folderPath");
    NavigationService.push(
      FadePageRoute(page: PdfListScreen(folderPath: folderPath)),
    ).then((_) {
      log("Returned from PdfListScreen");
      // Reload directories when returning from PDF list
      if (mounted) {
        setState(() {
          _isLoading = true;
          _directories.clear();
        });
        _checkAndLoadDirectories();
      }
    }).catchError((error) {
      log("Error navigating to PdfListScreen: $error");
      if (mounted) {
        _showSnackBar('Navigation error: $error');
      }
    });
  }

  void _onWillPop(bool didPop, dynamic result) async {
    if (didPop) {
      return;
    }

    DateTime now = DateTime.now();
    if (currentBackPressTime == null ||
        now.difference(currentBackPressTime!) >
            const Duration(seconds: backPressDelay)) {
      currentBackPressTime = now;
      _showSnackBar('Press back again to exit');
    } else {
      SystemNavigator.pop(); // Exits the app
    }
  }

  Future<void> _requestManageStoragePermission() async {
    await _permissionHandler.handleManageExternalStoragePermission();
    await _checkAndLoadDirectories();
  }

  @override
  Widget build(BuildContext context) {
    final customColors = Theme.of(context).extension<CustomColors>();

    return PopScope(
      onPopInvokedWithResult: _onWillPop,
      child: Scaffold(
        body: AnimatedContainer(
          duration: const Duration(seconds: 3),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                customColors?.gradientStart ?? const Color(0xFF2C1F63),
                customColors?.gradientEnd ?? const Color(0xFF7B1FA2),
                const Color(0xFF9C27B0),
              ],
              stops: const [0.0, 0.5, 1.0],
            ),
          ),
          child: Column(
            children: [
              _buildTVAppBar(),
              Expanded(
                child: isPickingPdf
                    ? _buildLoadingOverlay()
                    : _isLoading &&
                            _permissionStatus == PermissionStatus.granted
                        ? const Center(child: CircularProgressIndicator())
                        : _directories.isEmpty
                            ? _buildEmptyState()
                            : _buildDirectoryList(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTVAppBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(40, 40, 40, 20),
      child: LayoutBuilder(
        builder: (context, constraints) {
          return Row(
            children: [
              // Title with constrained width
              SizedBox(
                // Changed from Column to SizedBox with fixed height
                height: 100, // Provide fixed height
                child: Column(
                  mainAxisSize: MainAxisSize.min, // Add this
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ConstrainedBox(
                      constraints: BoxConstraints(
                        maxWidth: constraints.maxWidth * 0.25,
                      ),
                      child: const Text(
                        'PDF Viewer',
                        style: TextStyle(
                          fontSize: 30,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(height: 8), // Add spacing
                    IntrinsicHeight(
                      // Wrap with IntrinsicHeight
                      child: _buildPermissionStatus(),
                    ),
                  ],
                ),
              ),

              const Spacer(),
              // Action buttons
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TVButtonWidget(
                    icon: Icons.settings,
                    label: 'Settings',
                    focusNode: _settingsFocusNode,
                    onPressed: _permissionHandler.openAppSettings,
                  ),
                  const SizedBox(width: 16),
                  TVButtonWidget(
                    icon: Icons.picture_as_pdf,
                    label: 'Pick PDF',
                    focusNode: _pickPdfFocusNode,
                    onPressed: _pickPdf,
                    isPrimary: true,
                  ),
                  const SizedBox(width: 16),
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildPermissionStatus() {
    final Color statusColor;
    final String statusText;
    final IconData statusIcon;

    switch (_permissionStatus) {
      case PermissionStatus.granted:
        statusColor = Colors.green;
        statusText = 'Storage Access Granted';
        statusIcon = Icons.check_circle;
        break;
      case PermissionStatus.denied:
        statusColor = Colors.orange;
        statusText = 'Storage Access Denied';
        statusIcon = Icons.warning;
        break;
      case PermissionStatus.permanentlyDenied:
        statusColor = Colors.red;
        statusText = 'Storage Access Permanently Denied';
        statusIcon = Icons.block;
        break;
      default:
        statusColor = Colors.grey;
        statusText = 'Storage Access Unknown';
        statusIcon = Icons.help_outline;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: statusColor.withOpacity(0.2),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: statusColor.withOpacity(0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            statusIcon,
            color: statusColor,
            size: 20,
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              statusText,
              style: TextStyle(
                color: statusColor,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDirectoryList() {
    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: Transform.translate(
            offset: Offset(0, _slideAnimation.value),
            child: Opacity(
              opacity: _opacityAnimation.value,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40),
                child: GridView.builder(
                  controller: _scrollController,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    childAspectRatio: 2.5,
                    crossAxisSpacing: 20,
                    mainAxisSpacing: 20,
                  ),
                  itemCount: _directories.length,
                  itemBuilder: (context, index) {
                    final directory = _directories[index];
                    _directoryFocusNodes[index] ??= FocusNode()
                      ..addListener(_handleFocusChange);

                    return DirectoryTileWidget(
                      directory: directory,
                      focusNode: _directoryFocusNodes[index]!,
                      onNavigate: () =>
                          _navigateToPdfListScreen(context, directory.path),
                    );
                  },
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildEmptyState() {
    if (_permissionStatus != PermissionStatus.granted) {
      return Center(
        child: SingleChildScrollView(
          // Add ScrollView
          child: Container(
            padding: const EdgeInsets.all(40),
            margin: const EdgeInsets.all(40),
            constraints: const BoxConstraints(maxWidth: 800), // Add max width
            decoration: BoxDecoration(
              color: Colors.purple[900]?.withOpacity(0.4),
              borderRadius: BorderRadius.circular(35),
              border: Border.all(
                color: Colors.orange.withOpacity(0.3),
                width: 2,
              ),
            ),
            child: IntrinsicHeight(
              // Add IntrinsicHeight
              child: Column(
                mainAxisSize: MainAxisSize.min, // Ensure minimum size
                children: [
                  const AnimatedIconWidget(icon: Icons.folder_off, size: 60),
                  const SizedBox(height: 28),
                  const FittedBox(
                    // Wrap text with FittedBox
                    fit: BoxFit.scaleDown,
                    child: Text(
                      'Storage Access Required',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 30,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Please grant storage permission to view your PDF files, or use "Pick PDF" to select a file.',
                    style: TextStyle(
                      color: Colors.orange[100],
                      fontSize: 20,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  TVButtonWidget(
                    icon: Icons.storage,
                    label: 'Manage Storage',
                    focusNode: _manageStorageFocusNode,
                    onPressed: _requestManageStoragePermission,
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Center(
      child: Container(
        padding: const EdgeInsets.all(40),
        margin: const EdgeInsets.all(40),
        decoration: BoxDecoration(
          color: Colors.purple[900]?.withOpacity(0.4),
          borderRadius: BorderRadius.circular(35),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const AnimatedIconWidget(icon: Icons.folder_open, size: 120),
            const SizedBox(height: 28),
            const Text(
              'No PDFs Found',
              style: TextStyle(
                color: Colors.white,
                fontSize: 36,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Add some PDF files to view them here',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 26,
              ),
            ),
            const SizedBox(height: 40),
            TVButtonWidget(
              icon: Icons.add,
              label: 'Pick PDF',
              focusNode: _pickPdfFocusNode,
              onPressed: _pickPdf,
              isPrimary: true,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingOverlay() {
    return Container(
      color: Colors.black54,
      child: const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            PulsatingCircle(),
            SizedBox(height: 24),
            Text(
              'Opening PDF...',
              style: TextStyle(
                color: Colors.white,
                fontSize: 26,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

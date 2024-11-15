import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'screens/home_screen.dart';
import 'screens/pdf_viewer_screen.dart';
import 'services/navigation_service.dart';
import 'theme/theme.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // Set preferred orientations for TV
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);

  // Set system UI mode for TV
  SystemChrome.setEnabledSystemUIMode(
    SystemUiMode.manual,
    overlays: [],
  );
  ErrorWidget.builder = (FlutterErrorDetails details) {
    return Scaffold(
      body: Center(
        child: Text(
          'An error occurred: ${details.exception}',
          style: const TextStyle(color: Colors.red),
        ),
      ),
    );
  };
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  MyAppState createState() => MyAppState();
}

class MyAppState extends State<MyApp> {
  static const MethodChannel _channel =
      MethodChannel('androidtv.pdfviewer.redflute/pdf');

  @override
  void initState() {
    super.initState();
    _setupMethodChannel();
  }

  void _setupMethodChannel() {
    _channel.setMethodCallHandler((MethodCall call) async {
      if (call.method == 'openPdf') {
        final String encodedFilePath = call.arguments['filePath'];
        final String filePath =
            Uri.decodeComponent(encodedFilePath); // Decode it
        if (filePath.isNotEmpty) {
          navigatorKey.currentState?.pushNamed('/pdf', arguments: filePath);
        }
      }
      // Handle other methods if needed
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey:
          NavigationService.navigatorKey, // Use navigation service key
      debugShowCheckedModeBanner: false,
      title: 'Android TV PDF Viewer',
      theme: defaultTheme(),

      // Remove initialRoute to allow parsing of initial route from platform
      // initialRoute: '/',
      onGenerateRoute: (settings) {
        if (settings.name == '/') {
          return MaterialPageRoute(builder: (_) => const HomeScreen());
        } else if (settings.name != null &&
            settings.name!.startsWith('/pdf/')) {
          // Decode the file path from the route
          final encodedPath =
              settings.name!.substring(5); // Extract the encoded file path
          final filePath = Uri.decodeComponent(encodedPath); // Decode it
          return MaterialPageRoute(
            builder: (_) => PdfViewerScreen(filePath: filePath),
          );
        } else if (settings.name == '/pdf') {
          // Handle the case where filePath is passed via settings.arguments
          final filePath = settings.arguments as String?;
          if (filePath != null) {
            return MaterialPageRoute(
              builder: (_) => PdfViewerScreen(filePath: filePath),
            );
          } else {
            // Handle null or invalid filePath
            return MaterialPageRoute(
              builder: (_) =>
                  const HomeScreen(), // Redirect to HomeScreen or show error
            );
          }
        }
        // Handle other routes if necessary
        return null;
      },
      builder: (context, child) {
        return TVFocusWrapper(child: child ?? const SizedBox());
      },
    );
  }
}

// Custom intent for back button
class BackIntent extends Intent {
  const BackIntent();
}

// Wrapper widget to handle TV-specific focus behavior
class TVFocusWrapper extends StatelessWidget {
  final Widget child;

  const TVFocusWrapper({
    super.key,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Focus(
      autofocus: true,
      child: Builder(
        builder: (context) {
          return child;
        },
      ),
    );
  }
}

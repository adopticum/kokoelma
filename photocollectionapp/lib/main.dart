import 'package:flutter/material.dart';
import 'package:photocollectionapp/services/group_service.dart';
import 'package:photocollectionapp/services/image_service.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'viewmodels/auth_viewmodel.dart';
import 'viewmodels/theme_viewmodel.dart';
import 'services/auth_service.dart';
import 'services/exif_service.dart';
import 'services/permission_service.dart';
import 'services/path_service.dart';
import 'services/location_service.dart';
import 'utils/secrets.dart';
import 'utils/logger.dart';
import 'views/splash_view.dart';
import 'views/session_wrapper.dart';
import 'theme/custom_theme.dart';

// Used in permission_service for popping up a dialog if location is not enabled.
final navigatorKey = GlobalKey<NavigatorState>();

late final PathService _pathService;

// ProxyProvider automatically rebuilds a dependency when its inputs change (e.g. auth changes).

// Flow of app start:
// 1. Show splash screen.
// 2. Initialize Supabase, which takes some time.
// 3. Create services AFTER Supabase initialization (lazy-create).

void main() {
  runApp(
    // dep. Simple app with default theme.
    //const MaterialApp(home: SplashWidget()),

    // App that follows the system theme.
    MaterialApp(
      navigatorKey: navigatorKey,
      debugShowCheckedModeBanner: false,
      theme: CustomTheme.lightTheme,
      darkTheme: CustomTheme.darkTheme,
      themeMode: ThemeMode.system,
      home: const SplashWidget(),
    ),
  );
}

class SplashWidget extends StatefulWidget {
  const SplashWidget({super.key});

  @override
  State<SplashWidget> createState() => _SplashWidgetState();
}

class _SplashWidgetState extends State<SplashWidget> {
  bool _initialized = false;
  bool _error = false;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  // Async initialization so we can start the UI and wait for init.
  Future<void> _initialize() async {
    logger.i('Splash: Starting Supabase init');

    try {
      await Supabase.initialize(
        url: Secrets.projectUrl,
        publishableKey: Secrets.publishableKey,
      ).timeout(const Duration(seconds: 10));

      logger.i('Splash: Supabase initialized');

      // Initialize services that need to create state at startup.
      _pathService = PathService();
      await _pathService.initialize();

      if (!mounted) return;

      setState(() {
        _initialized = true;
      });
    } catch (e) {
      logger.e('Splash: initialization failed: $e');

      if (!mounted) return;

      setState(() {
        _error = true;
      });
    }
  }

  /* TODO:
  Widget _buildErrorView() {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('Failed to connect'),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  _error = false;
                });
                _initialize(); // 🔁 retry
              },
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
  */

  List<SingleChildWidget> createServices() {
    return [
      Provider<PathService>.value(value: _pathService),
      Provider(create: (_) => ExifService()),
      Provider(create: (context) => PhotoLocationService(context.read<ExifService>())),
      Provider(create: (_) => GroupService(Supabase.instance.client)),
      Provider(create: (_) => ImageService()),
      Provider(create: (_) => PermissionService(navigatorKey)),

      ChangeNotifierProvider(
        create: (_) => AuthService(Supabase.instance.client),
      ),
    ];
  }

  List<SingleChildWidget> createViewModels() {
    return [
      ChangeNotifierProvider(create: (_) => ThemeViewModel()), //TODO: Unused.

      ChangeNotifierProvider(
        create: (context) => AuthViewModel(context.read<AuthService>()),
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    if (_error) {
      //TODO: return _buildErrorView();
    }

    // Show splash view immediately.
    if (!_initialized) {
      return const SplashView();
      // Alt. return const SplashView(message: "Connecting...");
    }

    // Show the real UI (login or home page) after initialization.
    return MultiProvider(
      providers: createServices() + createViewModels(),
      child: const SessionWrapper(),
      //nope: child: const _ThemedRootView(),
    );
  }
}

// This exists purely to theme the safeareas at top and bottom of screen
// and it is not necessary. See custom_theme.dart for what we use instead.
/*
class _ThemedRootView extends StatelessWidget {
  const _ThemedRootView();

 
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    final overlayStyle = theme.brightness == Brightness.dark
        ? SystemUiOverlayStyle.light.copyWith(
            statusBarColor: Colors.transparent,
            systemNavigationBarColor: Colors.transparent,
          )
        : SystemUiOverlayStyle.dark.copyWith(
            statusBarColor: Colors.transparent,
            systemNavigationBarColor: Colors.transparent,
          );

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: overlayStyle,
      child: Container(
        color: cs.surfaceContainer, // THIS is what you actually see
        child: SafeArea(
          top: false, // let AppBar handle top
          bottom: true,
          child: const SessionWrapper(),
        ),
      ),
    );
  }
}
*/

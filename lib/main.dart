import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'services/supabase_service.dart';
import 'services/local_storage_service.dart';
import 'models/user_model.dart';
import 'providers/auth_provider.dart';
import 'providers/data_provider.dart';
import 'screens/reset_password_screen.dart';
import 'dart:async';
import 'package:app_links/app_links.dart';
import 'screens/splash_to_login.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'screens/about_page.dart';
import 'models/weekly_goal.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SupabaseService().init();
  // Initialize Hive for local persistence
  await Hive.initFlutter();
  // Register Hive adapters for weekly goals
  if (!Hive.isAdapterRegistered(1)) {
    Hive.registerAdapter(WeeklyGoalAdapter());
  }
  if (!Hive.isAdapterRegistered(2)) {
    Hive.registerAdapter(MuscleTargetAdapter());
  }
  if (!Hive.isAdapterRegistered(3)) {
    Hive.registerAdapter(DailyTargetAdapter());
  }
  if (!Hive.isAdapterRegistered(4)) {
    Hive.registerAdapter(DailyTargetMapAdapter());
  }
  await Hive.openBox<WeeklyGoal>('weeklyGoals');
  final savedUser = await LocalStorageService.getUser();
  if (savedUser != null) {
    print('[main] Preloaded saved user: ${savedUser.id} (${savedUser.role})');
  } else {
    print('[main] No saved user found at startup');
  }
  runApp(MyApp(initialUser: savedUser));
}

class MyApp extends StatelessWidget {
  final AppUser? initialUser;
  const MyApp({Key? key, this.initialUser}) : super(key: key);
  @override
  Widget build(BuildContext context) {
    // Slightly larger corner radius so the bottom appears gently rounded
    const double appBarRadius = 10;
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider(initialUser)),
        ChangeNotifierProvider(create: (_) => DataProvider()),
      ],
      child: MaterialApp(
        title: 'Gym Tracker',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(seedColor: Color(0xFF0F172A)),
          scaffoldBackgroundColor: Colors.grey[50],
          appBarTheme: AppBarTheme(
            toolbarHeight: 80,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(appBarRadius),
                bottomRight: Radius.circular(appBarRadius),
              ),
            ),
            backgroundColor: const Color(0xFF0F172A),
            foregroundColor: Colors.white,
            elevation: 0,
            centerTitle: true,
          ),
          elevatedButtonTheme: ElevatedButtonThemeData(
            style: ElevatedButton.styleFrom(
              backgroundColor: Color(0xFF0F172A),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            ),
          ),
          cardTheme: CardThemeData(
            elevation: 6,
            margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          pageTransitionsTheme: const PageTransitionsTheme(builders: {
            TargetPlatform.android: FadeUpwardsPageTransitionsBuilder(),
            TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
            TargetPlatform.windows: FadeUpwardsPageTransitionsBuilder(),
          }),
        ),
        home: DeepLinkShell(child: const SplashToLogin()),
        routes: {
          '/about': (context) => const AboutPage(),
        },
      ),
    );
  }
}

class DeepLinkShell extends StatefulWidget {
  final Widget child;
  const DeepLinkShell({Key? key, required this.child}) : super(key: key);

  @override
  State<DeepLinkShell> createState() => _DeepLinkShellState();
}

class _DeepLinkShellState extends State<DeepLinkShell> {
  StreamSubscription? _sub;
  final AppLinks _appLinks = AppLinks();

  @override
  void initState() {
    super.initState();
    // Listen for incoming app links using app_links
    _sub = _appLinks.uriLinkStream.listen((Uri? uri) {
      if (uri == null) return;
      print('[DeepLink] received uri: $uri');
      if (uri.scheme == 'apexbody' && uri.host == 'reset') {
        // Accept either access_token or code (Supabase uses `code`)
        String? token =
            uri.queryParameters['access_token'] ?? uri.queryParameters['code'];
        if ((token == null || token.isEmpty) && (uri.fragment.isNotEmpty)) {
          try {
            final frag = Uri.splitQueryString(uri.fragment);
            token = frag['access_token'] ?? frag['code'];
          } catch (e) {
            print('[DeepLink] error parsing fragment: $e');
          }
        }
        print('[DeepLink] extracted token/code: $token');
        WidgetsBinding.instance.addPostFrameCallback((_) {
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(
                builder: (_) => ResetPasswordScreen(accessToken: token)),
            (route) => false,
          );
        });
      }
    }, onError: (err) {
      print('Deep link error: $err');
    });

    // Also handle initial link when app starts via a deep link
    _appLinks.getInitialAppLink().then((uri) {
      if (uri == null) return;
      print('[DeepLink] initial uri: $uri');
      if (uri.scheme == 'apexbody' && uri.host == 'reset') {
        String? token =
            uri.queryParameters['access_token'] ?? uri.queryParameters['code'];
        if ((token == null || token.isEmpty) && (uri.fragment.isNotEmpty)) {
          try {
            final frag = Uri.splitQueryString(uri.fragment);
            token = frag['access_token'] ?? frag['code'];
          } catch (e) {
            print('[DeepLink] error parsing initial fragment: $e');
          }
        }
        print('[DeepLink] initial extracted token/code: $token');
        WidgetsBinding.instance.addPostFrameCallback((_) {
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(
                builder: (_) => ResetPasswordScreen(accessToken: token)),
            (route) => false,
          );
        });
      }
    }).catchError((e) {
      print('Initial app link error: $e');
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

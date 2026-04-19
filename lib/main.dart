import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'config/supabase_config.dart';
import 'utils/constants.dart';
import 'auth/login_page.dart';
import 'auth/signup_page.dart';
import 'pages/dashboard_page.dart';
import 'pages/verification_status_page.dart';
import 'pages/admin_page.dart';
import 'services/auth_service.dart';
import 'auth/complete_profile_page.dart';
import 'auth/admin_setup_page.dart';
import 'auth/business_details_page.dart';
import 'services/notification_service.dart';
import 'firebase_options.dart';

@pragma('vm:entry-point')
Future<void> _firebaseBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
}

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  FirebaseMessaging.onBackgroundMessage(_firebaseBackgroundHandler);

  await SupabaseConfig.initialize();

  await NotificationService().initialize();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'DreamVentz Vendor',
      navigatorKey: navigatorKey,
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xff0c1c2c)),
        useMaterial3: true,
        fontFamily: GoogleFonts.urbanist().fontFamily,
        fontFamilyFallback: const [
          'Noto Sans Symbols',
          'Noto Color Emoji',
          'Apple Color Emoji',
          'Segoe UI Emoji',
          'Roboto',
        ],
      ),
      initialRoute: '/',
      routes: {
        '/': (context) => const AuthWrapper(), 
        AppConstants.loginRoute: (context) => const LoginPage(),
        AppConstants.signupRoute: (context) => const SignupPage(),
        AppConstants.dashboardRoute: (context) => const DashboardPage(),
        AppConstants.adminRoute: (context) => const AdminPage(),
      },
    );
  }
}

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  final _authService = AuthService();
  bool _isLoading = true;
  Widget? _currentWidget;

  late final StreamSubscription<AuthState> _authSubscription;
  RealtimeChannel? _bookingChannel;

  @override
  void initState() {
    super.initState();
    _handleAuth();
  }

  @override
  void dispose() {
    _authSubscription.cancel();
    _bookingChannel?.unsubscribe();
    super.dispose();
  }

  void _listenToNewBookings() {
    _bookingChannel = Supabase.instance.client
        .channel('bookings-channel')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'orderslist', 
          callback: (payload) {
            final newBooking = payload.newRecord;
            debugPrint('📦 New order received: $newBooking');
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _showNewBookingBanner(newBooking);
            });
          },
        )
        .subscribe();
  }
  void _showNewBookingBanner(Map<String, dynamic> data) {
    final scaffoldContext = navigatorKey.currentContext;
    if (scaffoldContext == null) return;

    ScaffoldMessenger.of(scaffoldContext).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Text('🎉', style: TextStyle(fontSize: 22)),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'New Booking Received!',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                      color: Colors.white,
                    ),
                  ),
                  Text(
                    'Amount: ₹${data['total_amount']?.toString() ?? '0'}',
                    style: const TextStyle(fontSize: 12, color: Colors.white70),
                  ),
                ],
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF2D6A4F),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        duration: const Duration(seconds: 5),
      ),
    );
  }

  void _handleAuth() {
    _authSubscription = Supabase.instance.client.auth.onAuthStateChange.listen((
      data,
    ) {
      if (mounted) _checkUser(data.session?.user);
    });
  }

  Future<void> _checkUser(User? user) async {
    if (mounted) setState(() => _isLoading = true);

    if (user == null) {
      debugPrint('🔒 No authenticated user - showing login');
      if (mounted) {
        setState(() {
          _currentWidget = const LoginPage();
          _isLoading = false;
        });
      }
      return;
    }

    debugPrint('👤 Authenticated user: ${user.id}');

    try {
      await NotificationService().saveFcmToken();
      debugPrint('✅ FCM token saved for vendor ${user.id}');
    } catch (e) {
      debugPrint('⚠️ Failed to save FCM token: $e');
    }

    _listenToNewBookings();

    final profile = await _authService.getVendorProfile();

    debugPrint('📋 Vendor profile: ${profile != null ? "Found" : "NOT Found"}');
    if (profile != null) {
      debugPrint('   ↳ Name: ${profile.fullName}');
      debugPrint('   ↳ Role: ${profile.role}');
      debugPrint('   ↳ Status: ${profile.verificationStatus}');
    }

    if (mounted) {
      setState(() {
        if (profile == null) {
          final metaRole = user.userMetadata?['role'] as String? ?? '';
          if (metaRole == 'admin') {
            debugPrint('➡️  Redirecting to: Admin Setup Page');
            _currentWidget = const AdminSetupPage();
          } else {
            debugPrint('➡️  Redirecting to: Complete Profile Page');
            _currentWidget = const CompleteVendorProfilePage();
          }
        } else if (profile.isAdmin) {
          debugPrint('➡️  Redirecting to: Admin Page');
          _currentWidget = const AdminPage();
        } else if (profile.verificationStatus == 'rejected') {
          debugPrint('➡️  Redirecting to: Verification Status Page (rejected)');
          _currentWidget = VerificationStatusPage(profile: profile);
        } else if (!profile.businessSubmitted) {
          debugPrint('➡️  Redirecting to: Business Details Page');
          _currentWidget = const BusinessDetailsPage();
        } else if (profile.verificationStatus == 'verified') {
          debugPrint('➡️  Redirecting to: Dashboard');
          _currentWidget = const DashboardPage();
        } else {
          debugPrint('➡️  Redirecting to: Verification Status Page (pending)');
          _currentWidget = VerificationStatusPage(profile: profile);
        }
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: CircularProgressIndicator(color: Color(0xFFFFC107)),
        ),
      );
    }
    return _currentWidget ?? const LoginPage();
  }
}

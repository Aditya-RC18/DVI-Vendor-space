import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
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

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SupabaseConfig.initialize();
  runApp(const MyApp());
}

// ── Global Navigator Key ───────────────────────
// Add this at the top of main.dart (outside all classes)
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'DreamVentz Vendor',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xff0c1c2c)),
        useMaterial3: true,
        fontFamily: GoogleFonts.urbanist().fontFamily,
        fontFamilyFallback: [
          'Noto Sans Symbols',
          'Noto Color Emoji',
          'Apple Color Emoji',
          'Segoe UI Emoji',
          'Roboto',
        ],
      ),
      initialRoute: '/',
      routes: {
        '/': (context) => const LoginPage(),
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

  @override
  void initState() {
    super.initState();
    _handleAuth();

    // Start listening for new bookings as soon as vendor logs in
    _listenToNewBookings();
  }

  @override
  void dispose() {
    _authSubscription.cancel();
    _bookingChannel?.unsubscribe();
    super.dispose();
  }

  // ── Real-time booking listener ─────────────
  RealtimeChannel? _bookingChannel;

  void _listenToNewBookings() {
    _bookingChannel = Supabase.instance.client
        .channel('bookings-channel')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'bookings',
          callback: (payload) {
            final newBooking = payload.newRecord;
            debugPrint('📦 New booking received: $newBooking');

            // Show notification banner
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _showNewBookingBanner(newBooking);
            });
          },
        )
        .subscribe();
  }

  void _showNewBookingBanner(Map<String, dynamic> data) {
    // Get the current context from navigator key or use global key
    final context = _currentWidget != null
        ? ((_currentWidget as dynamic).key as GlobalKey?)?.currentContext
        : null;

    // Use ScaffoldMessenger with root context
    final scaffoldContext = _getScaffoldContext();
    if (scaffoldContext == null) return;

    ScaffoldMessenger.of(scaffoldContext).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Text('🎉', style: TextStyle(fontSize: 22)),
            const SizedBox(width: 10),
            Column(
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
          ],
        ),
        backgroundColor: const Color(0xFF2D6A4F),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        duration: const Duration(seconds: 5),
      ),
    );
  }

  BuildContext? _getScaffoldContext() {
    return navigatorKey.currentContext;
  }

  // ── Auth handling (your original code) ─────
  void _handleAuth() {
    _authSubscription = Supabase.instance.client.auth.onAuthStateChange.listen((
      data,
    ) {
      if (mounted) _checkUser(data.session?.user);
    });
  }

  Future<void> _checkUser(User? user) async {
    setState(() => _isLoading = true);

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
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return _currentWidget ?? const LoginPage();
  }
}



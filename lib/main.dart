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

  @override
  void initState() {
    super.initState();
    _handleAuth();
  }

  @override
  void dispose() {
    _authSubscription.cancel();
    super.dispose();
  }

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

    // Fetch Vendor Profile to check role
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
          // Authenticated but no vendor profile yet — check role from metadata
          final metaRole = user.userMetadata?['role'] as String? ?? '';
          if (metaRole == 'admin') {
            debugPrint('➡️  Redirecting to: Admin Setup Page');
            _currentWidget = const AdminSetupPage();
          } else {
            debugPrint('➡️  Redirecting to: Complete Profile Page');
            _currentWidget = const CompleteVendorProfilePage();
          }
        } else if (profile.isAdmin) {
          // Admin user -> Admin Page
          debugPrint('➡️  Redirecting to: Admin Page');
          _currentWidget = const AdminPage();
        } else if (profile.verificationStatus == 'rejected') {
          // Rejected vendors always go to status page (to see rejection reason
          // and edit their application) — regardless of businessSubmitted flag.
          debugPrint('➡️  Redirecting to: Verification Status Page (rejected)');
          _currentWidget = VerificationStatusPage(profile: profile);
        } else if (!profile.businessSubmitted) {
          // Vendor row exists but page 3 not yet submitted
          debugPrint('➡️  Redirecting to: Business Details Page');
          _currentWidget = const BusinessDetailsPage();
        } else if (profile.verificationStatus == 'verified') {
          // Verified vendor -> Dashboard
          debugPrint('➡️  Redirecting to: Dashboard');
          _currentWidget = const DashboardPage();
        } else {
          // Pending vendor -> Verification Status Page
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

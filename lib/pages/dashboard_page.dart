import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'uploads_page.dart';
import 'report_issue_page.dart';
import 'extras_page.dart';
import '../services/auth_service.dart';
import '../utils/constants.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  int _currentIndex = 0;

  final List<Widget> _pages = [
    const Center(
      child: Text("Welcome to Vendor Dashboard"),
    ), // Placeholder for Home
    const UploadsPage(),
    const ExtrasPage(),
    const Center(child: Text("Settings")), // Placeholder
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          "Vendor Dashboard",
          style: GoogleFonts.urbanist(color: Colors.white),
        ),
        backgroundColor: const Color(0xff0c1c2c),
        actions: [
          IconButton(
            icon: const Icon(Icons.report_problem),
            color: Colors.white,
            tooltip: 'Report Issue',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const ReportIssuePage(),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            color: Colors.white,
            onPressed: () async {
              await AuthService().signOut();
              if (context.mounted) {
                Navigator.pushReplacementNamed(
                  context,
                  AppConstants.loginRoute,
                );
              }
            },
          ),
        ],
      ),
      body: _pages[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        selectedItemColor: const Color(0xff0c1c2c),
        unselectedItemColor: Colors.grey,
        type: BottomNavigationBarType.fixed,
        onTap: (index) => setState(() => _currentIndex = index),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.dashboard), label: 'Home'),
          BottomNavigationBarItem(
            icon: Icon(Icons.upload_file),
            label: 'Uploads',
          ),
          BottomNavigationBarItem(icon: Icon(Icons.star), label: 'Extras'),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/vendor_profile.dart';
import '../utils/constants.dart';
import 'edit_vendor_profile_page.dart';

class VerificationStatusPage extends StatelessWidget {
  final VendorProfile profile;

  const VerificationStatusPage({super.key, required this.profile});

  @override
  Widget build(BuildContext context) {
    final isRejected = profile.verificationStatus == 'rejected';

    return Scaffold(
      appBar: AppBar(
        title: const Text("Application Status"),
        backgroundColor: const Color(0xff0c1c2c),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              // Reload logic would go here, for now simpler just to navigate home which triggers auth reload
              Navigator.pushNamedAndRemoveUntil(context, '/', (route) => false);
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isRejected ? Icons.cancel_outlined : Icons.pending_actions,
              size: 100,
              color: isRejected ? Colors.red : Colors.orange,
            ),
            const SizedBox(height: 24),
            Text(
              isRejected ? "Application Rejected" : "Under Review",
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Text(
              isRejected
                  ? "Your application for vendor account has been rejected."
                  : "Your application is currently being reviewed by our admin team. This usually takes 24-48 hours.",
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16),
            ),
            if (isRejected && profile.rejectionReason != null) ...[
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
                ),
                child: Column(
                  children: [
                    const Text(
                      "Reason for Rejection:",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.red,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(profile.rejectionReason!),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 48),

            // Edit Application Button
            SizedBox(
              width: double.infinity,
              height: 50,
              child: OutlinedButton.icon(
                onPressed: () async {
                  bool? updated = await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => EditVendorProfilePage(profile: profile),
                    ),
                  );
                  if (updated == true) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text("Application updated. Refreshing..."),
                        ),
                      );
                      Navigator.pushNamedAndRemoveUntil(
                        context,
                        '/',
                        (r) => false,
                      );
                    }
                  }
                },
                icon: const Icon(Icons.edit),
                label: const Text("Edit Application"),
              ),
            ),

            const SizedBox(height: 16),

            // Logout Button
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                onPressed: () async {
                  await Supabase.instance.client.auth.signOut();
                  if (context.mounted) {
                    Navigator.pushNamedAndRemoveUntil(
                      context,
                      AppConstants.loginRoute,
                      (route) => false,
                    );
                  }
                },
                icon: const Icon(Icons.logout),
                label: const Text("Logout"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.redAccent,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

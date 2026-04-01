import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'edit_vendor_profile_page.dart';
// Ensure this matches your project's model path
// import '../models/vendor_profile.dart';

class VendorProfileView extends StatelessWidget {
  // Using a generic 'dynamic' if your specific VendorProfile model
  // isn't imported yet, but 'VendorProfile' is preferred.
  final dynamic profile;

  const VendorProfileView({super.key, required this.profile});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          "Business Profile",
          style: GoogleFonts.urbanist(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: const Color(0xff0c1c2c),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          // The Edit Button as discussed
          TextButton.icon(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => EditVendorProfilePage(profile: profile),
                ),
              );
            },
            icon: const Icon(Icons.edit, color: Colors.amber, size: 18),
            label: const Text("Edit", style: TextStyle(color: Colors.amber)),
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            _buildHeader(),
            Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSectionTitle("General Information"),
                  _infoCard([
                    _infoTile(Icons.person, "Full Name", profile.fullName),
                    _infoTile(Icons.badge, "Role", profile.role),
                  ]),
                  const SizedBox(height: 20),
                  _buildSectionTitle("Business Details"),
                  _infoCard([
                    _infoTile(
                      Icons.verified_user,
                      "Verification Status",
                      profile.verificationStatus.toUpperCase(),
                    ),
                    _infoTile(
                      Icons.receipt_long,
                      "GST Number",
                      "Pending Verification",
                    ), // Placeholder for GST
                  ]),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        color: Color(0xff0c1c2c),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(30),
          bottomRight: Radius.circular(30),
        ),
      ),
      padding: const EdgeInsets.only(bottom: 40, top: 20),
      child: Column(
        children: [
          Stack(
            alignment: Alignment.bottomRight,
            children: [
              CircleAvatar(
                radius: 60,
                backgroundColor: Colors.white24,
                // Placeholder logic for the profile photo feature
                child: const Icon(Icons.store, size: 60, color: Colors.white),
              ),
              if (profile.verificationStatus == 'verified')
                const CircleAvatar(
                  radius: 18,
                  backgroundColor: Colors.green,
                  child: Icon(Icons.check, color: Colors.white, size: 18),
                ),
            ],
          ),
          const SizedBox(height: 15),
          Text(
            profile.fullName,
            style: GoogleFonts.urbanist(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          Text(
            profile.role,
            style: const TextStyle(color: Colors.white70, fontSize: 16),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        title,
        style: GoogleFonts.urbanist(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: const Color(0xff0c1c2c),
        ),
      ),
    );
  }

  Widget _infoCard(List<Widget> children) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Column(children: children),
    );
  }

  Widget _infoTile(IconData icon, String label, String value) {
    return ListTile(
      leading: Icon(icon, color: const Color(0xff0c1c2c), size: 20),
      title: Text(
        label,
        style: const TextStyle(fontSize: 12, color: Colors.grey),
      ),
      subtitle: Text(
        value,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: Colors.black87,
        ),
      ),
    );
  }
}

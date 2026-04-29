import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb; // 🔥 Added for Web checking
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/notification_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _complaintsCount = 0;
  bool _isAdmin = false;
  StreamSubscription? _complaintsSubscription;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  @override
  void dispose() {
    // 🔥 MEMORY MANAGEMENT: Cancel subscription to prevent leaks
    _complaintsSubscription?.cancel();
    super.dispose();
  }

  Future<void> _loadUserData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedAdmin = prefs.getBool('isAdmin') ?? false;
      
      if (mounted) {
        setState(() => _isAdmin = savedAdmin);
        
        final user = FirebaseAuth.instance.currentUser;
        if (user != null) {
          // 🔥 WEB FIX: Only initialize Push Notifications on Android/iOS
          if (!kIsWeb) {
            NotificationService().initialize();
          }

          // 🔥 REAL-TIME DATA: Listen for complaint changes
          _complaintsSubscription = FirebaseFirestore.instance
              .collection('complaints')
              .where('userId', isEqualTo: user.uid)
              .snapshots()
              .listen((snapshot) {
            if (mounted) {
              setState(() => _complaintsCount = snapshot.docs.length);
            }
          });
        }
      }
    } catch (e) {
      debugPrint("Data load error: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA), // Matches the light grey from screenshots
      appBar: AppBar(
        title: const Text('CivicFix Home'),
        actions: [
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              child: Text(
                'Complaints: $_complaintsCount',
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.logout_rounded),
            tooltip: 'Logout',
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
              final prefs = await SharedPreferences.getInstance();
              await prefs.clear();
              if (mounted) Navigator.pushReplacementNamed(context, '/login');
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              const SizedBox(height: 24),
              
              // 🟢 Hero Icon & Welcome Text
              const Icon(Icons.card_travel_rounded, size: 80, color: Color(0xFF2D6A4F)),
              const SizedBox(height: 16),
              const Text(
                'Welcome to Jharkhand CivicFix', 
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              
              // 🏷️ Badges Row
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2D6A4F).withAlpha(30), 
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text(
                      'CITIZEN', 
                      style: TextStyle(color: Color(0xFF2D6A4F), fontWeight: FontWeight.bold, fontSize: 12),
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Text('SIH25031', style: TextStyle(color: Colors.grey, fontSize: 14)),
                ],
              ),
              
              const SizedBox(height: 40),
              
              // 📊 Stats Card (Wide)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFFE9F5EC), // Very light green background
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFF2D6A4F).withAlpha(50)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.view_list_rounded, color: const Color(0xFF2D6A4F).withAlpha(150), size: 36),
                    const SizedBox(width: 16),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Your Complaints', style: TextStyle(color: Colors.grey[700], fontSize: 14)),
                        Text(
                          '$_complaintsCount total', 
                          style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Color(0xFF2D6A4F)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 24),
              
              // 🚀 Action Buttons
              Row(
                children: [
                  _buildLargeActionCard(
                    'Report Issue', 
                    Icons.add_circle_outline, 
                    const Color(0xFF2D6A4F), 
                    '/complaint',
                  ),
                  const SizedBox(width: 16),
                  _buildLargeActionCard(
                    'My Complaints', 
                    Icons.list_alt_rounded, 
                    const Color(0xFF8D6E63), // Brown/Orange matching the screenshot
                    '/my-complaints',
                  ),
                ],
              ),
              
              // 👮 Admin Action (Only visible if the user is an admin)
              if (_isAdmin) ...[
                const SizedBox(height: 24),
                const Divider(),
                const SizedBox(height: 8),
                ListTile(
                  tileColor: Colors.amber.withAlpha(20),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(color: Colors.amber.withAlpha(50)),
                  ),
                  leading: const Icon(Icons.admin_panel_settings, color: Colors.amber),
                  title: const Text('Admin Dashboard', style: TextStyle(fontWeight: FontWeight.bold)),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 14),
                  onTap: () => Navigator.pushNamed(context, '/admin-complaints'),
                ),
              ]
            ],
          ),
        ),
      ),
    );
  }

  // 🖱️ Helper for the large square buttons
  Widget _buildLargeActionCard(String title, IconData icon, Color iconColor, String route) {
    return Expanded(
      child: InkWell(
        onTap: () => Navigator.pushNamed(context, route),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          height: 140,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 48, color: iconColor),
              const SizedBox(height: 16),
              Text(
                title, 
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
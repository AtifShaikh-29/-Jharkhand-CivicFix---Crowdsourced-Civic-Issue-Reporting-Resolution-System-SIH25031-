import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../services/storage_service.dart';
import '../widgets/image_thumbnail_row.dart';
import '../widgets/full_screen_image_viewer.dart';
import '../widgets/complaint_dialog.dart';

class MyComplaintsScreen extends StatefulWidget {
  const MyComplaintsScreen({super.key});

  @override
  State<MyComplaintsScreen> createState() => _MyComplaintsScreenState();
}

class _MyComplaintsScreenState extends State<MyComplaintsScreen> {
  
  // 🎨 Helper: Global Status Colors
  Color getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'pending': return const Color(0xFFF9A825); // Orange
      case 'in progress': return const Color(0xFF8D6E63); // Brown
      case 'resolved': return const Color(0xFF2D6A4F); // Green
      case 'rejected': return const Color(0xFFD32F2F); // Red
      default: return Colors.grey;
    }
  }

  // 🗑️ Helper: Delete Complaint Logic
  Future<void> _deleteComplaint(String docId, List<String>? imageUrls, String? resolutionUrl) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Complaint?'),
        content: const Text('This action cannot be undone. Are you sure?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('CANCEL')),
          TextButton(
            onPressed: () => Navigator.pop(context, true), 
            child: const Text('DELETE', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      // 1. Delete associated images from Storage to save space
      if (imageUrls != null) {
        for (String url in imageUrls) {
          await StorageService().deleteImage(url);
        }
      }
      if (resolutionUrl != null) {
        await StorageService().deleteImage(resolutionUrl);
      }

      // 2. Atomic DB Deletion & User Count Update
      final user = FirebaseAuth.instance.currentUser;
      final batch = FirebaseFirestore.instance.batch();
      
      batch.delete(FirebaseFirestore.instance.collection('complaints').doc(docId));
      
      if (user != null) {
        batch.update(FirebaseFirestore.instance.collection('users').doc(user.uid), {
          'complaintsCount': FieldValue.increment(-1)
        });
      }

      await batch.commit();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Complaint deleted successfully')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error deleting: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA), // Light grey background
      appBar: AppBar(title: const Text('My Complaints')),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('complaints')
            .where('userId', isEqualTo: user?.uid)
            .orderBy('timestamp', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return _buildEmptyState();
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: snapshot.data!.docs.length,
            itemBuilder: (context, index) {
              final doc = snapshot.data!.docs[index];
              final data = doc.data() as Map<String, dynamic>;
              return _buildComplaintCard(data, doc.id);
            },
          );
        },
      ),
    );
  }

  Widget _buildComplaintCard(Map<String, dynamic> data, String docId) {
    final status = data['status'] ?? 'Pending';
    final color = getStatusColor(status);
    
    // Format Date
    String dateStr = '';
    if (data['timestamp'] != null) {
      DateTime dt = (data['timestamp'] as Timestamp).toDate();
      dateStr = DateFormat('dd MMM yyyy').format(dt);
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 1,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12), 
        side: BorderSide(color: Colors.grey.shade200)
      ),
      child: InkWell(
        onTap: () {
          showDialog(
            context: context,
            builder: (context) => ComplaintDialog(data: data, docId: docId, isAdmin: false),
          );
        },
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 🟢 Left Status Strip
              Container(width: 6, color: color),
              
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Title, Status Chip & Delete Button
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              data['title'] ?? 'Untitled', 
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(color: color.withAlpha(20), borderRadius: BorderRadius.circular(20)),
                            child: Text(status, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold)),
                          ),
                          const SizedBox(width: 8),
                          GestureDetector(
                            onTap: () => _deleteComplaint(
                              docId, 
                              data['imageUrls'] != null ? List<String>.from(data['imageUrls']) : null,
                              data['resolutionUrl']
                            ),
                            child: const Icon(Icons.delete, color: Colors.red, size: 20),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      
                      // Citizen Evidence
                      if (data['imageUrls'] != null) ...[
                        ImageThumbnailRow(imageUrls: List<String>.from(data['imageUrls']), size: 60),
                        const SizedBox(height: 12),
                      ],
                      
                      // Description
                      if (data['description'] != null && data['description'].toString().isNotEmpty) ...[
                        Text(data['description'], style: TextStyle(color: Colors.grey[800], fontSize: 13), maxLines: 2, overflow: TextOverflow.ellipsis),
                        const SizedBox(height: 12),
                      ],
                      
                      // Tags & Location
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          _buildTag(Icons.category, data['category'] ?? 'General', Colors.green),
                          if (data['priority'] != null)
                            _buildTag(Icons.flag, data['priority'], data['priority'] == 'Urgent' ? Colors.red : (data['priority'] == 'High' ? Colors.orange : Colors.blue)),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.location_on, size: 14, color: Colors.grey),
                              const SizedBox(width: 4),
                              Text(data['location'] ?? 'Unknown', style: const TextStyle(color: Colors.grey, fontSize: 12)),
                            ],
                          ),
                        ],
                      ),
                      
                      const SizedBox(height: 16),
                      
                      // Date Alignment (Bottom Right)
                      Align(
                        alignment: Alignment.bottomRight,
                        child: Text(dateStr, style: const TextStyle(color: Colors.grey, fontSize: 12)),
                      ),

                      // Resolution Proof Section (If Admin resolved it)
                      if (status == 'Resolved' && data['resolutionUrl'] != null) ...[
                        const Divider(height: 24),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.green.withAlpha(15),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.green.withAlpha(30)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Row(
                                children: [
                                  Icon(Icons.verified, color: Colors.green, size: 18),
                                  SizedBox(width: 8),
                                  Text('Admin Resolution Proof', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green, fontSize: 13)),
                                ],
                              ),
                              const SizedBox(height: 12),
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton.icon(
                                  onPressed: () => Navigator.push(
                                    context,
                                    MaterialPageRoute(builder: (context) => FullScreenImageViewer(imageUrls: [data['resolutionUrl']])),
                                  ),
                                  icon: const Icon(Icons.zoom_in, size: 18),
                                  label: const Text('VIEW PROOF PHOTO'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.green,
                                    foregroundColor: Colors.white,
                                    elevation: 0,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTag(IconData icon, String text, MaterialColor color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.shade50, 
        borderRadius: BorderRadius.circular(4), 
        border: Border.all(color: color.shade100)
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color.shade700),
          const SizedBox(width: 4),
          Text(text, style: TextStyle(fontSize: 10, color: color.shade700, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.inbox_rounded, size: 80, color: Colors.grey.withAlpha(100)),
          const SizedBox(height: 16),
          const Text('No complaints found', style: TextStyle(color: Colors.grey, fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          const Text('Issues you report will appear here.', style: TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }
}
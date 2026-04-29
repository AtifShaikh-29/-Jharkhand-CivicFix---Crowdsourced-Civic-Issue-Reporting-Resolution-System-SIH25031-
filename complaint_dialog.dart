import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'image_thumbnail_row.dart';
import 'full_screen_image_viewer.dart';

class ComplaintDialog extends StatelessWidget {
  final Map<String, dynamic> data;
  final String docId;
  final bool isAdmin;

  const ComplaintDialog({
    super.key,
    required this.data,
    required this.docId,
    this.isAdmin = false,
  });

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'pending': return const Color(0xFFF9A825);
      case 'in progress': return const Color(0xFF8D6E63);
      case 'resolved': return const Color(0xFF2D6A4F);
      case 'rejected': return const Color(0xFFD32F2F);
      default: return Colors.grey;
    }
  }

  MaterialColor _getPriorityColor(String? priority) {
    if (priority == 'Urgent') return Colors.red;
    if (priority == 'High') return Colors.orange;
    return Colors.blue;
  }

  @override
  Widget build(BuildContext context) {
    final status = data['status'] ?? 'Pending';
    final color = _getStatusColor(status);
    
    String dateStr = 'Unknown Date';
    if (data['timestamp'] != null) {
      DateTime dt = (data['timestamp'] as Timestamp).toDate();
      dateStr = DateFormat('dd MMM yyyy, hh:mm a').format(dt);
    }

    return Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      insetPadding: const EdgeInsets.all(20),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.8, // Max 80% of screen height
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 🛑 Sticky Header with Close Button
            Container(
              padding: const EdgeInsets.fromLTRB(20, 16, 8, 8),
              decoration: BoxDecoration(
                color: color.withAlpha(15),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(data['title'] ?? 'Untitled Issue', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: Colors.grey),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),

            // 📜 Scrollable Content Area
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Status & Tags
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(color: color.withAlpha(30), borderRadius: BorderRadius.circular(20)),
                          child: Text(status.toUpperCase(), style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 11)),
                        ),
                        _buildTag(Icons.category, data['category'] ?? 'General', Colors.green),
                        _buildTag(Icons.flag, data['priority'] ?? 'Medium', _getPriorityColor(data['priority'])),
                      ],
                    ),
                    
                    const Divider(height: 32),
                    
                    // Description
                    const Text('Description', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.grey)),
                    const SizedBox(height: 8),
                    Text(
                      data['description']?.toString().isNotEmpty == true ? data['description'] : 'No description provided.',
                      style: const TextStyle(fontSize: 15, height: 1.4),
                    ),
                    
                    const SizedBox(height: 24),
                    
                    // Meta Info (Location, Date, ID)
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: const Color(0xFFF8F9FA), borderRadius: BorderRadius.circular(12)),
                      child: Column(
                        children: [
                          Row(children: [const Icon(Icons.location_on, color: Colors.grey, size: 16), const SizedBox(width: 8), Expanded(child: Text(data['location'] ?? 'Unknown', style: const TextStyle(fontSize: 13)))]),
                          const SizedBox(height: 8),
                          Row(children: [const Icon(Icons.access_time_filled, color: Colors.grey, size: 16), const SizedBox(width: 8), Expanded(child: Text(dateStr, style: const TextStyle(fontSize: 13)))]),
                          const SizedBox(height: 8),
                          Row(children: [const Icon(Icons.fingerprint, color: Colors.grey, size: 16), const SizedBox(width: 8), Expanded(child: SelectableText('ID: $docId', style: const TextStyle(fontSize: 11, color: Colors.grey)))]),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Citizen Evidence
                    if (data['imageUrls'] != null && (data['imageUrls'] as List).isNotEmpty) ...[
                      const Text('Citizen Evidence', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 12),
                      ImageThumbnailRow(imageUrls: List<String>.from(data['imageUrls']), size: 80),
                      const SizedBox(height: 24),
                    ],

                    // Admin Resolution Proof
                    if (status == 'Resolved' && data['resolutionUrl'] != null) ...[
                      const Text('Admin Resolution Proof', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.green)),
                      const SizedBox(height: 12),
                      GestureDetector(
                        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => FullScreenImageViewer(imageUrls: [data['resolutionUrl']]))),
                        child: Hero(
                          tag: data['resolutionUrl'],
                          child: Container(
                            height: 150,
                            width: double.infinity,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.green, width: 2),
                              image: DecorationImage(image: NetworkImage(data['resolutionUrl']), fit: BoxFit.cover),
                            ),
                            child: Container(
                              decoration: BoxDecoration(color: Colors.black.withAlpha(60), borderRadius: BorderRadius.circular(10)),
                              child: const Center(child: Icon(Icons.zoom_in, color: Colors.white, size: 40)),
                            ),
                          ),
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
    );
  }

  Widget _buildTag(IconData icon, String text, MaterialColor color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: color.shade50, borderRadius: BorderRadius.circular(6), border: Border.all(color: color.shade100)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color.shade700),
          const SizedBox(width: 4),
          Text(text, style: TextStyle(fontSize: 11, color: color.shade700, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/storage_service.dart';
import '../widgets/image_thumbnail_row.dart';
import '../widgets/complaint_dialog.dart';

class AdminComplaintsScreen extends StatefulWidget {
  const AdminComplaintsScreen({super.key});

  @override
  State<AdminComplaintsScreen> createState() => _AdminComplaintsScreenState();
}

class _AdminComplaintsScreenState extends State<AdminComplaintsScreen> {
  final ImagePicker _picker = ImagePicker();
  bool _isProcessing = false;

  // Search and Filter State
  String _selectedFilter = 'All';
  String _searchQuery = "";
  final TextEditingController _searchController = TextEditingController();
  final List<String> _statusOptions = ['All', 'Pending', 'In Progress', 'Resolved', 'Rejected'];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

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

  // 🚀 Logic: Update Status & Force Photo on Resolution
  Future<void> _updateStatus(String docId, String newStatus, String title) async {
    String? resolutionUrl;

    if (newStatus == 'Resolved') {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 70,
      );

      if (image == null) return; 

      setState(() => _isProcessing = true);
      try {
        resolutionUrl = await StorageService().uploadImage(
          image: image,
          path: 'resolution_proofs/$docId',
        );
      } catch (e) {
        setState(() => _isProcessing = false);
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Upload failed: $e')));
        return;
      }
    } else {
      setState(() => _isProcessing = true);
    }

    try {
      Map<String, dynamic> updateData = {'status': newStatus};
      if (resolutionUrl != null) {
        updateData['resolutionUrl'] = resolutionUrl;
        updateData['resolvedAt'] = FieldValue.serverTimestamp();
      }

      await FirebaseFirestore.instance.collection('complaints').doc(docId).update(updateData);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Status updated to $newStatus')));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Update failed: $e')));
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA), 
      appBar: AppBar(
        title: const Text('Admin Dashboard - SIH25031'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout_rounded),
            tooltip: 'Logout',
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
              final prefs = await SharedPreferences.getInstance();
              await prefs.clear();
              if (mounted) Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('complaints').orderBy('timestamp', descending: true).snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return const Center(child: Text('Error loading data.'));
              }

              final allDocs = snapshot.data!.docs;

              var filteredDocs = allDocs.where((doc) {
                final data = doc.data() as Map<String, dynamic>;
                bool matchesStatus = _selectedFilter == 'All' || data['status'] == _selectedFilter;
                
                final title = (data['title'] ?? "").toString().toLowerCase();
                final desc = (data['description'] ?? "").toString().toLowerCase();
                bool matchesSearch = title.contains(_searchQuery) || desc.contains(_searchQuery);
                
                return matchesStatus && matchesSearch;
              }).toList();

              return Column(
                children: [
                  _buildHeader(),
                  _buildStatCards(allDocs),
                  Expanded(
                    child: filteredDocs.isEmpty 
                      ? _buildNoResults() 
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          itemCount: filteredDocs.length,
                          itemBuilder: (context, index) {
                            final data = filteredDocs[index].data() as Map<String, dynamic>;
                            return _buildComplaintCard(data, filteredDocs[index].id);
                          },
                        ),
                  ),
                ],
              );
            },
          ),
          if (_isProcessing)
            Container(
              color: Colors.black.withAlpha(100),
              child: const Center(child: CircularProgressIndicator(color: Colors.white)),
            ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Column(
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: _statusOptions.map((status) {
                bool isSelected = _selectedFilter == status;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: Text(status),
                    selected: isSelected,
                    onSelected: (bool value) => setState(() => _selectedFilter = status),
                    selectedColor: const Color(0xFF2D6A4F).withAlpha(30),
                    checkmarkColor: const Color(0xFF2D6A4F),
                    labelStyle: TextStyle(
                      color: isSelected ? const Color(0xFF2D6A4F) : Colors.black54,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                    backgroundColor: const Color(0xFFF1F3F4),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    side: BorderSide.none,
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              controller: _searchController,
              onChanged: (value) => setState(() => _searchQuery = value.toLowerCase()),
              decoration: InputDecoration(
                hintText: 'Search complaints...',
                prefixIcon: const Icon(Icons.search, size: 20, color: Colors.grey),
                filled: true,
                fillColor: const Color(0xFFF1F3F4),
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCards(List<QueryDocumentSnapshot> allDocs) {
    int pending = allDocs.where((d) => (d.data() as Map<String, dynamic>)['status'] == 'Pending').length;
    int inProgress = allDocs.where((d) => (d.data() as Map<String, dynamic>)['status'] == 'In Progress').length;
    int resolved = allDocs.where((d) => (d.data() as Map<String, dynamic>)['status'] == 'Resolved').length;
    int rejected = allDocs.where((d) => (d.data() as Map<String, dynamic>)['status'] == 'Rejected').length;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Row(
        children: [
          _buildSingleStatCard('Pending', pending, getStatusColor('Pending'), Icons.assignment_late_outlined),
          const SizedBox(width: 8),
          _buildSingleStatCard('In Progress', inProgress, getStatusColor('In Progress'), Icons.engineering_outlined),
          const SizedBox(width: 8),
          _buildSingleStatCard('Resolved', resolved, getStatusColor('Resolved'), Icons.check_circle_outline),
          const SizedBox(width: 8),
          _buildSingleStatCard('Rejected', rejected, getStatusColor('Rejected'), Icons.cancel_outlined),
        ],
      ),
    );
  }

  Widget _buildSingleStatCard(String label, int count, Color color, IconData icon) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
        decoration: BoxDecoration(
          color: color.withAlpha(15),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withAlpha(40)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(height: 4),
            Text(label, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold), textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 4),
            Text('$count', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color)),
          ],
        ),
      ),
    );
  }

  Widget _buildComplaintCard(Map<String, dynamic> data, String docId) {
    final status = data['status'] ?? 'Pending';
    final color = getStatusColor(status);
    
    String dateStr = '';
    if (data['timestamp'] != null) {
      DateTime dt = (data['timestamp'] as Timestamp).toDate();
      dateStr = DateFormat('dd MMM yyyy').format(dt);
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 1,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.grey.shade200)),
      child: InkWell(
        onTap: () {
          showDialog(
            context: context,
            builder: (context) => ComplaintDialog(data: data, docId: docId, isAdmin: true),
          );
        },
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(width: 6, color: color),
              
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: Text(data['title'] ?? 'Untitled', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(color: color.withAlpha(20), borderRadius: BorderRadius.circular(20)),
                            child: Text(status, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      
                      Row(
                        children: [
                          _buildTag(Icons.category, data['category'] ?? 'General', Colors.green),
                          const SizedBox(width: 8),
                          _buildTag(Icons.flag, data['priority'] ?? 'Medium', Colors.red),
                        ],
                      ),
                      const SizedBox(height: 12),
                      
                      if (data['imageUrls'] != null) ...[
                        ImageThumbnailRow(imageUrls: List<String>.from(data['imageUrls']), size: 60),
                        const SizedBox(height: 12),
                      ],
                      
                      Text(data['description'] ?? '', style: TextStyle(color: Colors.grey[700], fontSize: 13), maxLines: 2, overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 16),
                      
                      Row(
                        children: [
                          const Icon(Icons.location_on, size: 14, color: Colors.grey),
                          const SizedBox(width: 4),
                          Expanded(child: Text(data['location'] ?? 'Unknown', style: const TextStyle(color: Colors.grey, fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis)),
                          const Icon(Icons.access_time, size: 14, color: Colors.grey),
                          const SizedBox(width: 4),
                          Text(dateStr, style: const TextStyle(color: Colors.grey, fontSize: 12)),
                        ],
                      ),
                      
                      const Divider(height: 32),
                      
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: ['Pending', 'In Progress', 'Resolved', 'Rejected'].map((s) {
                            bool isActive = status == s;
                            return Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: OutlinedButton(
                                onPressed: isActive ? null : () => _updateStatus(docId, s, data['title'] ?? 'Issue'),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: getStatusColor(s),
                                  disabledForegroundColor: Colors.grey,
                                  side: BorderSide(color: isActive ? Colors.grey.withAlpha(50) : getStatusColor(s).withAlpha(100)),
                                  padding: const EdgeInsets.symmetric(horizontal: 12),
                                  visualDensity: VisualDensity.compact,
                                ),
                                child: Text(s, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
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
      decoration: BoxDecoration(color: color.shade50, borderRadius: BorderRadius.circular(4), border: Border.all(color: color.shade100)),
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

  Widget _buildNoResults() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search_off_rounded, size: 64, color: Colors.grey.withAlpha(100)),
          const SizedBox(height: 16),
          Text('No complaints found for "$_selectedFilter"', style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}
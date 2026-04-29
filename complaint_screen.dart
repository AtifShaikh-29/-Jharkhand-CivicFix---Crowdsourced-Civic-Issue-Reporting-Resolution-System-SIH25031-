import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:geolocator/geolocator.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/storage_service.dart';

class ComplaintScreen extends StatefulWidget {
  const ComplaintScreen({super.key});

  @override
  State<ComplaintScreen> createState() => _ComplaintScreenState();
}

class _ComplaintScreenState extends State<ComplaintScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  
  String _selectedCategory = 'Road Issue';
  String _selectedPriority = 'Medium';
  final List<XFile> _images = [];
  
  bool _isSubmitting = false;
  bool _isFetchingLocation = true;
  Position? _currentPosition;

  @override
  void initState() {
    super.initState();
    _fetchLocation(); // Fetch immediately on load
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    super.dispose();
  }

  /// 🔥 GPS LOGIC
  Future<void> _fetchLocation() async {
    setState(() => _isFetchingLocation = true);
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _useFallbackLocation();
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          _useFallbackLocation();
          return;
        }
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      );
      
      if (mounted) {
        setState(() {
          _currentPosition = position;
          _isFetchingLocation = false;
        });
      }
    } catch (e) {
      _useFallbackLocation();
    }
  }

  void _useFallbackLocation() {
    if (mounted) {
      setState(() {
        _currentPosition = Position(
          longitude: 77.605889, latitude: 13.064076, // Fallback coordinates
          timestamp: DateTime.now(), accuracy: 0, altitude: 0, 
          heading: 0, speed: 0, speedAccuracy: 0, altitudeAccuracy: 0, headingAccuracy: 0,
        );
        _isFetchingLocation = false;
      });
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    if (_images.length >= 3) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Maximum 3 images allowed')));
      return;
    }
    final img = await ImagePicker().pickImage(source: source, imageQuality: 70);
    if (img != null) setState(() => _images.add(img));
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_images.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please add at least 1 image as evidence.')));
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception("User not logged in");
      
      final String complaintId = DateTime.now().millisecondsSinceEpoch.toString();

      // 🔥 PARALLEL PROCESSING: Upload images concurrently
      final List<String> imageUrls = await Future.wait(
        _images.map((img) => StorageService().uploadImage(
          image: img, 
          path: 'complaints/${user.uid}/$complaintId'
        ))
      );

      // 🔥 ATOMIC BATCHING
      final batch = FirebaseFirestore.instance.batch();
      final complaintRef = FirebaseFirestore.instance.collection('complaints').doc(complaintId);
      final userRef = FirebaseFirestore.instance.collection('users').doc(user.uid);

      batch.set(complaintRef, {
        'userId': user.uid,
        'title': _titleController.text.trim(),
        'description': _descController.text.trim(),
        'category': _selectedCategory,
        'priority': _selectedPriority,
        'imageUrls': imageUrls,
        'location': '${_currentPosition?.latitude}, ${_currentPosition?.longitude}',
        'status': 'Pending',
        'timestamp': FieldValue.serverTimestamp(),
      });

      batch.update(userRef, {'complaintsCount': FieldValue.increment(1)});

      await batch.commit();

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('🚀 Report Submitted Successfully!')));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(title: const Text('Report Civic Issue')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _buildLocationCard(),
            const SizedBox(height: 24),
            
            // 📝 Title Field
            TextFormField(
              controller: _titleController, 
              validator: (val) => val == null || val.isEmpty ? 'Required' : null,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.title, color: Color(0xFF2D6A4F)),
                hintText: 'Issue Title *',
              ),
            ),
            const SizedBox(height: 16),
            
            // 📝 Description Field
            TextFormField(
              controller: _descController, 
              maxLines: 4,
              decoration: const InputDecoration(
                prefixIcon: Padding(
                  padding: EdgeInsets.only(bottom: 60), // Aligns icon to top
                  child: Icon(Icons.description, color: Color(0xFF2D6A4F)),
                ),
                hintText: 'Description (Optional)',
              ),
            ),
            const SizedBox(height: 24),
            
            // 📸 Evidence Section
            const Row(
              children: [
                Icon(Icons.camera_alt),
                SizedBox(width: 8),
                Text('Evidence (Required, max 3)', style: TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                ElevatedButton.icon(
                  onPressed: () => _pickImage(ImageSource.camera),
                  icon: const Icon(Icons.camera_alt_outlined, size: 18),
                  label: const Text('Camera'),
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(100, 40),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                  ),
                ),
                const SizedBox(width: 12),
                OutlinedButton.icon(
                  onPressed: () => _pickImage(ImageSource.gallery),
                  icon: const Icon(Icons.photo_library_outlined, size: 18, color: Color(0xFF2D6A4F)),
                  label: const Text('Gallery', style: TextStyle(color: Color(0xFF2D6A4F))),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(100, 40),
                    side: const BorderSide(color: Color(0xFF2D6A4F)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildImagePreviewRow(),
            
            const SizedBox(height: 24),
            
            // 🏷️ Dropdowns (Category & Priority)
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _selectedCategory,
                    decoration: const InputDecoration(
                      labelText: 'Category *',
                      prefixIcon: Icon(Icons.category, color: Color(0xFF2D6A4F), size: 20),
                    ),
                    items: ['Road Issue', 'Water', 'Sanitation', 'Public Restroom' , 'Garbage', 'Electricity', 'Waste', 'Other']
                        .map((c) => DropdownMenuItem(value: c, child: Text(c, style: const TextStyle(fontSize: 14))))
                        .toList(),
                    onChanged: (v) => setState(() => _selectedCategory = v!),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _selectedPriority,
                    decoration: const InputDecoration(
                      labelText: 'Priority *',
                      prefixIcon: Icon(Icons.flag, color: Color(0xFF2D6A4F), size: 20),
                    ),
                    items: ['Medium', 'High', 'Urgent']
                        .map((c) => DropdownMenuItem(value: c, child: Text(c, style: const TextStyle(fontSize: 14))))
                        .toList(),
                    onChanged: (v) => setState(() => _selectedPriority = v!),
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 40),
            
            // 🚀 Submit Button
            ElevatedButton(
              onPressed: _isSubmitting ? null : _submit,
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF52B788)),
              child: _isSubmitting 
                  ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5)) 
                  : const Text('🚀 SUBMIT COMPLAINT'),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  // --- UI HELPERS ---

  Widget _buildLocationCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        children: [
          const Icon(Icons.location_on, size: 48, color: Color(0xFF52B788)),
          const SizedBox(height: 8),
          const Text('Your Location', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F3F4),
              borderRadius: BorderRadius.circular(12),
            ),
            child: _isFetchingLocation 
              ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
              : Column(
                  children: [
                    Text('${_currentPosition?.latitude ?? "Error"}, ${_currentPosition?.longitude ?? "Error"}', 
                      style: const TextStyle(fontSize: 13, color: Colors.black87)
                    ),
                  ],
                ),
          ),
          const SizedBox(height: 16),
          TextButton.icon(
            onPressed: _fetchLocation,
            icon: const Icon(Icons.refresh, size: 18),
            label: const Text('Update Location'),
            style: TextButton.styleFrom(
              foregroundColor: Colors.white,
              backgroundColor: const Color(0xFF52B788),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              padding: const EdgeInsets.symmetric(horizontal: 20),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildImagePreviewRow() {
    if (_images.isEmpty) return const SizedBox.shrink();
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: _images.map((img) => Stack(
        clipBehavior: Clip.none,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            // 🔥 FIXED FOR WEB: Uses Image.network for blobs, Image.file for mobile paths
            child: kIsWeb 
                ? Image.network(img.path, width: 80, height: 80, fit: BoxFit.cover)
                : Image.file(File(img.path), width: 80, height: 80, fit: BoxFit.cover),
          ),
          Positioned(
            top: -8,
            right: -8,
            child: GestureDetector(
              onTap: () => setState(() => _images.remove(img)),
              child: Container(
                decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                padding: const EdgeInsets.all(4),
                child: const Icon(Icons.close, color: Colors.white, size: 16),
              ),
            ),
          ),
        ],
      )).toList(),
    );
  }
}
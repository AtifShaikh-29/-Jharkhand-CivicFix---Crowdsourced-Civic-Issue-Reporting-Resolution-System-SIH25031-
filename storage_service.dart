import 'package:flutter/foundation.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path/path.dart' as p;

class StorageService {
  // 🏗️ Singleton Pattern to save memory
  static final StorageService _instance = StorageService._internal();
  factory StorageService() => _instance;
  StorageService._internal();

  final FirebaseStorage _storage = FirebaseStorage.instance;

  /// Compresses and uploads an image. 
  /// Path is dynamic to handle both citizen evidence and admin proofs.
  Future<String> uploadImage({
    required XFile image, // XFile is provided by flutter_image_compress
    required String path, // e.g., 'complaints/uid/id' or 'resolution_proofs'
    Function(double)? onProgress,
  }) async {
    try {
      Uint8List? compressedData;

      // 1. Compression Phase
      if (kIsWeb) {
        // Web doesn't support native local file compression well, use raw bytes
        compressedData = await image.readAsBytes();
        debugPrint('🌐 Storage: Web upload detected, skipping compression.');
      } else {
        // Mobile Compression (Reduces 5MB images to ~200kb without losing dimensions)
        compressedData = await FlutterImageCompress.compressWithFile(
          image.path,
          minWidth: 1024,
          minHeight: 1024,
          quality: 75,
        );
        debugPrint('📱 Storage: Mobile image compressed successfully.');
      }

      if (compressedData == null) throw Exception("Compression returned null data");

      // 2. File Naming & Safety Phase
      String ext = p.extension(image.name);
      if (ext.isEmpty) ext = '.jpg'; // Safety fallback for missing extensions
      
      final String fileName = "${DateTime.now().millisecondsSinceEpoch}$ext";
      final Reference ref = _storage.ref().child('$path/$fileName');

      debugPrint('📤 Storage: Starting upload to $path/$fileName');

      // 3. Upload Phase
      final UploadTask uploadTask = ref.putData(
        compressedData,
        SettableMetadata(contentType: 'image/jpeg'),
      );

      // Listen to progress (Optional, useful if you want to add a progress bar later)
      uploadTask.snapshotEvents.listen((TaskSnapshot snapshot) {
        double progress = snapshot.bytesTransferred / snapshot.totalBytes;
        onProgress?.call(progress);
      });

      // 4. Completion Phase
      final TaskSnapshot downloadSnapshot = await uploadTask;
      final String downloadUrl = await downloadSnapshot.ref.getDownloadURL();
      
      debugPrint('✅ Storage: Upload complete! URL generated.');
      return downloadUrl;

    } catch (e) {
      debugPrint('❌ Storage: Upload failed - $e');
      rethrow; // Pass error back to the UI so the user sees the failure snackbar
    }
  }

  /// Deletes a file from Storage given its URL.
  Future<void> deleteImage(String url) async {
    try {
      final Reference ref = _storage.refFromURL(url);
      await ref.delete();
      debugPrint('🗑️ Storage: Deleted image successfully.');
    } catch (e) {
      // If it fails (e.g., file already deleted manually in console), just log it
      debugPrint("⚠️ Storage: Delete error (Safe to ignore): $e");
    }
  }
}
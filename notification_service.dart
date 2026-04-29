import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

class NotificationService {
  // 🏗️ Singleton Pattern to ensure only one instance handles notifications
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FirebaseMessaging _fcm = FirebaseMessaging.instance;

  /// Initializes FCM, requests permissions, and sets up listeners
  Future<void> initialize() async {
    try {
      // 1. Request Permission from the OS
      NotificationSettings settings = await _fcm.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );

      if (settings.authorizationStatus == AuthorizationStatus.authorized) {
        debugPrint('✅ FCM: User granted permission');
        await _saveDeviceToken();
      } else {
        debugPrint('⚠️ FCM: User declined or has not accepted permission');
      }

      // 2. Listen for token refreshes (happens if app data is cleared or reinstall)
      _fcm.onTokenRefresh.listen((newToken) {
        debugPrint('🔄 FCM: Token Refreshed');
        _updateTokenInFirestore(newToken);
      });

      // 3. Foreground Message Handler (When user is actively using the app)
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        debugPrint('📬 FCM: Received foreground message: ${message.notification?.title}');
        // Optional: You can hook this up to a local Snackbar/Dialog later if needed
      });

      // 4. Background/Terminated App Opened via Notification Handler
      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        debugPrint('🚀 FCM: App opened from notification. Data: ${message.data}');
      });

    } catch (e) {
      debugPrint('❌ FCM Initialization Error: $e');
    }
  }

  /// Gets the current token and saves it to Firestore
  Future<void> _saveDeviceToken() async {
    try {
      String? token = await _fcm.getToken();
      if (token != null) {
        debugPrint('📱 FCM: Token retrieved successfully');
        await _updateTokenInFirestore(token);
      }
    } catch (e) {
      debugPrint('❌ FCM: Failed to get token: $e');
    }
  }

  /// Updates the user's document in Firestore with the new token
  Future<void> _updateTokenInFirestore(String token) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
          'fcmToken': token,
          'lastTokenUpdate': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
        debugPrint('✅ FCM: Token saved to Firestore for user: ${user.uid}');
      } catch (e) {
        debugPrint('❌ FCM: Failed to save token to Firestore: $e');
      }
    }
  }

  /// Optional: Useful for broadcasting to all admins later
  Future<void> subscribeToTopic(String topic) async {
    try {
      await _fcm.subscribeToTopic(topic);
      debugPrint('✅ FCM: Subscribed to topic: $topic');
    } catch (e) {
      debugPrint('❌ FCM: Topic subscription failed: $e');
    }
  }
}
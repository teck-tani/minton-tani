import 'dart:io';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

class ApiService {
  // Mocked Cloud Run URL. Default localhost for testing.
  static const String cvApiUrl = "http://10.0.2.2:8080/analyze_video";

  Future<void> uploadAndAnalyzeVideo(File videoFile, String userId) async {
    try {
      // 1. Upload to Firebase Storage
      final storageRef = FirebaseStorage.instance.ref().child('videos/$userId/${DateTime.now().millisecondsSinceEpoch}.mp4');
      
      debugPrint("Starting video upload...");
      // For real app, uncomment next line when Firebase Auth is fully initialized
      // await storageRef.putFile(videoFile);
      // final downloadUrl = await storageRef.getDownloadURL();
      
      // Mocked URL for phase 3
      final String downloadUrl = "https://mock-firebase-storage.com/video.mp4";
      debugPrint("Video uploaded. Triggering CV Pipeline API...");

      // 2. Trigger FastApi Backend for CV Processing
      final response = await http.post(
        Uri.parse(cvApiUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'video_url': downloadUrl,
          'user_id': userId,
        }),
      );

      if (response.statusCode == 200) {
        debugPrint("API Response: ${response.body}");
        debugPrint("Video is now being processed by TrackNet and YOLOv7 via Cloud Run.");
        
        // 3. (Mock) Wait for Firestore update
        // Real app would listen to a Firestore stream here.
      } else {
        debugPrint("Failed to start analysis. Status: ${response.statusCode}");
      }
    } catch (e) {
      debugPrint("Error in uploadAndAnalyzeVideo: $e");
    }
  }
}

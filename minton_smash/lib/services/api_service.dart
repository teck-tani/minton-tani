import 'dart:io';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';

class ApiService {
  static const String cvApiUrl = "https://minton-smash-cv-120519944306.asia-northeast3.run.app/analyze_video";
  static const String coachApiUrl = "https://minton-smash-cv-120519944306.asia-northeast3.run.app/ai_coach/chat";

  /// Uploads video to Firebase Storage and triggers backend CV pipeline.
  /// Returns the analysis document path for tracking.
  Future<String?> uploadAndAnalyzeVideo(File videoFile, String userId) async {
    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final storageRef = FirebaseStorage.instance
          .ref()
          .child('videos/$userId/$timestamp.mp4');

      debugPrint("Starting video upload...");
      final uploadTask = storageRef.putFile(videoFile);

      // Listen to upload progress
      uploadTask.snapshotEvents.listen((event) {
        final progress = event.bytesTransferred / event.totalBytes;
        debugPrint("Upload progress: ${(progress * 100).toStringAsFixed(1)}%");
      });

      await uploadTask;
      final downloadUrl = await storageRef.getDownloadURL();
      debugPrint("Video uploaded: $downloadUrl");

      // Trigger FastAPI Backend for CV Processing
      final response = await http.post(
        Uri.parse(cvApiUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'video_url': downloadUrl,
          'user_id': userId,
        }),
      );

      if (response.statusCode == 200) {
        debugPrint("CV Pipeline triggered successfully.");
        return downloadUrl;
      } else {
        debugPrint("Failed to start analysis. Status: ${response.statusCode}");
        return null;
      }
    } catch (e) {
      debugPrint("Error in uploadAndAnalyzeVideo: $e");
      return null;
    }
  }

  /// Sends a message to the AI Coach endpoint and returns the response.
  Future<Map<String, dynamic>> sendCoachMessage({
    required String userId,
    required String message,
    String? conversationId,
  }) async {
    final response = await http
        .post(
          Uri.parse(coachApiUrl),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'user_id': userId,
            'message': message,
            if (conversationId != null) 'conversation_id': conversationId,
          }),
        )
        .timeout(const Duration(seconds: 60));

    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    } else {
      debugPrint('AI Coach error: ${response.statusCode} - ${response.body}');
      throw Exception('AI Coach 요청 실패: ${response.statusCode}');
    }
  }
}

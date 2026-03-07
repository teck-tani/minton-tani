import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:camera/camera.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import '../services/api_service.dart';

class CameraMirrorScreen extends StatefulWidget {
  final List<CameraDescription> cameras;

  const CameraMirrorScreen({super.key, required this.cameras});

  @override
  State<CameraMirrorScreen> createState() => _CameraMirrorScreenState();
}

class _CameraMirrorScreenState extends State<CameraMirrorScreen> {
  CameraController? _cameraController;
  int _cameraIndex = 0;
  bool _isRecording = false;
  int _recordingSeconds = 0;
  Timer? _recordingTimer;

  @override
  void initState() {
    super.initState();
    // Lock portrait orientation for camera screen
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
    ]);
    _initializeCamera();
  }

  void _initializeCamera() async {
    if (widget.cameras.isEmpty) return;

    _cameraIndex = widget.cameras
        .indexWhere((c) => c.lensDirection == CameraLensDirection.front);
    if (_cameraIndex == -1) _cameraIndex = 0;

    await _startCamera(_cameraIndex);
  }

  Future<void> _startCamera(int index) async {
    if (_cameraController != null) {
      await _cameraController!.dispose();
    }

    final camera = widget.cameras[index];
    _cameraController = CameraController(
      camera,
      ResolutionPreset.medium,
      enableAudio: true,
    );

    try {
      await _cameraController!.initialize();
      if (!mounted) return;
      // Lock to portrait after camera init
      await _cameraController!.lockCaptureOrientation(DeviceOrientation.portraitUp);
      setState(() {});
    } catch (e) {
      debugPrint("Camera initialization error: $e");
    }
  }

  void _switchCamera() async {
    if (widget.cameras.length < 2) return;
    _cameraIndex = (_cameraIndex + 1) % widget.cameras.length;
    await _startCamera(_cameraIndex);
  }

  Future<void> _toggleRecording() async {
    if (_cameraController == null || !_cameraController!.value.isInitialized) return;

    if (_isRecording) {
      try {
        final videoFile = await _cameraController!.stopVideoRecording();
        setState(() => _isRecording = false);

        if (!mounted) return;

        final shouldUpload = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('영상 분석'),
            content: const Text('촬영한 영상을 AI로 분석하시겠습니까?'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('취소')),
              ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('분석하기')),
            ],
          ),
        );

        if (shouldUpload == true) {
          final uid = FirebaseAuth.instance.currentUser?.uid;
          if (uid != null) {
            final apiService = ApiService();
            await apiService.uploadAndAnalyzeVideo(File(videoFile.path), uid);
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('영상 업로드 완료! 분석이 시작되었습니다.')),
              );
            }
          }
        }
      } catch (e) {
        debugPrint("Error stopping recording: $e");
        setState(() => _isRecording = false);
      }
    } else {
      try {
        await _cameraController!.startVideoRecording();
        setState(() {
          _isRecording = true;
          _recordingSeconds = 0;
        });
        _startRecordingTimer();
      } catch (e) {
        debugPrint("Error starting recording: $e");
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('녹화 시작 실패: $e')),
          );
        }
      }
    }
  }

  Future<void> _pickVideoFromGallery() async {
    final picker = ImagePicker();
    final picked = await picker.pickVideo(source: ImageSource.gallery);
    if (picked == null || !mounted) return;

    final shouldUpload = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('영상 분석'),
        content: Text('선택한 영상을 AI로 분석하시겠습니까?\n${picked.name}'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('취소')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('분석하기')),
        ],
      ),
    );

    if (shouldUpload == true) {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid != null) {
        final apiService = ApiService();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('영상 업로드 중...')),
          );
        }
        final result = await apiService.uploadAndAnalyzeVideo(File(picked.path), uid);
        if (mounted) {
          ScaffoldMessenger.of(context).clearSnackBars();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(result != null ? '영상 업로드 완료! 분석이 시작되었습니다.' : '업로드 실패. 다시 시도해주세요.')),
          );
        }
      }
    }
  }

  void _startRecordingTimer() {
    _recordingTimer?.cancel();
    _recordingTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!_isRecording || !mounted) {
        timer.cancel();
        return;
      }
      setState(() => _recordingSeconds++);
    });
  }

  @override
  void dispose() {
    _recordingTimer?.cancel();
    // Restore all orientations when leaving camera screen
    SystemChrome.setPreferredOrientations(DeviceOrientation.values);
    _cameraController?.dispose();
    super.dispose();
  }

  String _formatDuration(int seconds) {
    final m = (seconds ~/ 60).toString().padLeft(2, '0');
    final s = (seconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          if (!_isRecording)
            IconButton(
              icon: const Icon(Symbols.cameraswitch, color: Colors.white, size: 30),
              onPressed: _switchCamera,
            ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final previewSize = _cameraController!.value.previewSize!;
          // previewSize is in landscape orientation; for portrait display, aspect ratio is inverted
          final cameraAspectRatio = previewSize.height / previewSize.width;
          final screenAspectRatio = constraints.maxWidth / constraints.maxHeight;
          // Scale to cover the entire screen without distortion
          var scale = cameraAspectRatio / screenAspectRatio;
          if (scale < 1) scale = 1 / scale;

          return Stack(
            fit: StackFit.expand,
            children: [
              ClipRect(
                child: Transform.scale(
                  scale: scale,
                  child: Center(
                    child: CameraPreview(_cameraController!),
                  ),
                ),
              ),

          // Recording indicator
          if (_isRecording)
            Positioned(
              top: MediaQuery.of(context).padding.top + 16,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.8),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(width: 10, height: 10, decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle)),
                      const SizedBox(width: 8),
                      Text('REC ${_formatDuration(_recordingSeconds)}', style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ),
            ),

          // Bottom panel
          Positioned(
            bottom: 20,
            left: 16,
            right: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.6),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  // Gallery button
                  GestureDetector(
                    onTap: _isRecording ? null : _pickVideoFromGallery,
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: _isRecording ? Colors.white24 : Colors.white.withOpacity(0.2),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Symbols.photo_library,
                        color: _isRecording ? Colors.white38 : Colors.white,
                        size: 24,
                      ),
                    ),
                  ),
                  // Record button
                  GestureDetector(
                    onTap: _toggleRecording,
                    child: Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 3),
                      ),
                      child: Center(
                        child: Container(
                          width: _isRecording ? 24 : 52,
                          height: _isRecording ? 24 : 52,
                          decoration: BoxDecoration(
                            color: Colors.red,
                            borderRadius: _isRecording
                                ? BorderRadius.circular(4)
                                : BorderRadius.circular(26),
                          ),
                        ),
                      ),
                    ),
                  ),
                  // Placeholder for symmetry
                  const SizedBox(width: 44, height: 44),
                ],
              ),
            ),
          ),
            ],
          );
        },
      ),
    );
  }
}

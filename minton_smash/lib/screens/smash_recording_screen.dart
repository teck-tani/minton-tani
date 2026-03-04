import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:camera/camera.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:video_player/video_player.dart';
import '../widgets/pose_painter.dart';
import '../services/api_service.dart';
import '../theme.dart';

class SmashRecordingScreen extends StatefulWidget {
  final List<CameraDescription> cameras;

  const SmashRecordingScreen({super.key, required this.cameras});

  @override
  State<SmashRecordingScreen> createState() => _SmashRecordingScreenState();
}

class _SmashRecordingScreenState extends State<SmashRecordingScreen> {
  static const int _maxRecordingSeconds = 15;

  CameraController? _cameraController;
  final PoseDetector _poseDetector = PoseDetector(
    options: PoseDetectorOptions(mode: PoseDetectionMode.stream),
  );
  bool _isBusy = false;
  List<Pose> _poses = [];
  int _cameraIndex = 0;
  bool _isRecording = false;
  int _recordingSeconds = 0;
  bool _showSkeleton = true;
  bool _showGuideOverlay = true;
  int _countdown = 0;
  bool _isUploading = false;
  Timer? _recordingTimer;

  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    _initializeCamera();
  }

  void _initializeCamera() async {
    if (widget.cameras.isEmpty) return;

    // Default to back camera for better quality
    _cameraIndex = widget.cameras
        .indexWhere((c) => c.lensDirection == CameraLensDirection.back);
    if (_cameraIndex == -1) _cameraIndex = 0;

    await _startCamera(_cameraIndex);
  }

  Future<void> _startCamera(int index) async {
    if (_cameraController != null) {
      try { await _cameraController!.stopImageStream(); } catch (_) {}
      await _cameraController!.dispose();
    }

    final camera = widget.cameras[index];
    _cameraController = CameraController(
      camera,
      ResolutionPreset.medium,
      enableAudio: true,
      imageFormatGroup: Platform.isAndroid
          ? ImageFormatGroup.nv21
          : ImageFormatGroup.bgra8888,
    );

    try {
      await _cameraController!.initialize();
      if (!mounted) return;
      await _cameraController!.lockCaptureOrientation(DeviceOrientation.portraitUp);
      _cameraController!.startImageStream(_processCameraImage);
      setState(() {});
    } catch (e) {
      debugPrint("Camera initialization error: $e");
    }
  }

  void _switchCamera() async {
    if (widget.cameras.length < 2 || _isRecording) return;
    _cameraIndex = (_cameraIndex + 1) % widget.cameras.length;
    _poses = [];
    await _startCamera(_cameraIndex);
  }

  Future<void> _startRecordingWithCountdown() async {
    if (_cameraController == null || !_cameraController!.value.isInitialized) return;

    setState(() {
      _showGuideOverlay = false;
    });

    // Stop image stream before recording
    if (_cameraController == null || !mounted) return;
    try { await _cameraController!.stopImageStream(); } catch (_) {}
    await Future.delayed(const Duration(milliseconds: 500));
    if (!mounted) return;

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
      try { _cameraController!.startImageStream(_processCameraImage); } catch (_) {}
    }
  }

  Future<void> _stopRecording() async {
    if (_cameraController == null || !_isRecording) return;

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
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('다시 촬영'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                foregroundColor: Colors.white,
              ),
              child: const Text('분석하기'),
            ),
          ],
        ),
      );

      if (shouldUpload == true && mounted) {
        await _uploadVideo(File(videoFile.path));
      }

      // Restart pose detection stream
      if (mounted && _cameraController != null) {
        _cameraController!.startImageStream(_processCameraImage);
        setState(() => _showGuideOverlay = true);
      }
    } catch (e) {
      debugPrint("Error stopping recording: $e");
      setState(() => _isRecording = false);
    }
  }

  Future<void> _uploadVideo(File videoFile) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    setState(() => _isUploading = true);
    final apiService = ApiService();
    final result = await apiService.uploadAndAnalyzeVideo(videoFile, uid);

    if (mounted) {
      setState(() => _isUploading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result != null
              ? '영상 업로드 완료! 분석이 시작되었습니다.'
              : '업로드 실패. 다시 시도해주세요.'),
        ),
      );
      if (result != null) {
        Navigator.of(context).pop();
      }
    }
  }

  Future<void> _pickVideoFromGallery() async {
    final picker = ImagePicker();
    final picked = await picker.pickVideo(source: ImageSource.gallery);
    if (picked == null || !mounted) return;

    // Check video duration
    final controller = VideoPlayerController.file(File(picked.path));
    try {
      await controller.initialize();
      final duration = controller.value.duration;
      await controller.dispose();

      if (duration.inSeconds > _maxRecordingSeconds) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('${_maxRecordingSeconds}초 이하의 영상만 첨부할 수 있습니다.')),
          );
        }
        return;
      }
    } catch (e) {
      await controller.dispose();
      debugPrint("Error checking video duration: $e");
    }

    if (!mounted) return;

    final shouldUpload = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('영상 분석'),
        content: Text('선택한 영상을 AI로 분석하시겠습니까?\n${picked.name}'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('취소'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
              foregroundColor: Colors.white,
            ),
            child: const Text('분석하기'),
          ),
        ],
      ),
    );

    if (shouldUpload == true && mounted) {
      await _uploadVideo(File(picked.path));
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
      if (_recordingSeconds >= _maxRecordingSeconds) {
        timer.cancel();
        _stopRecording();
      }
    });
  }

  Future<void> _processCameraImage(CameraImage image) async {
    if (_isBusy || !mounted) return;
    _isBusy = true;

    final camera = widget.cameras[_cameraIndex];
    final imageRotation =
        InputImageRotationValue.fromRawValue(camera.sensorOrientation) ??
            InputImageRotation.rotation0deg;

    final inputImageFormat = Platform.isAndroid
        ? InputImageFormat.nv21
        : (InputImageFormatValue.fromRawValue(image.format.raw) ??
            InputImageFormat.bgra8888);

    final WriteBuffer allBytes = WriteBuffer();
    for (final Plane plane in image.planes) {
      allBytes.putUint8List(plane.bytes);
    }
    final bytes = allBytes.done().buffer.asUint8List();

    final Size imageSize = Size(image.width.toDouble(), image.height.toDouble());

    final metadata = InputImageMetadata(
      size: imageSize,
      rotation: imageRotation,
      format: inputImageFormat,
      bytesPerRow: image.planes[0].bytesPerRow,
    );

    final inputImage = InputImage.fromBytes(bytes: bytes, metadata: metadata);

    try {
      final poses = await _poseDetector.processImage(inputImage);
      if (mounted) {
        setState(() => _poses = poses);
      }
    } catch (e) {
      debugPrint("Error processing pose: $e");
    }

    _isBusy = false;
  }

  @override
  void dispose() {
    _recordingTimer?.cancel();
    SystemChrome.setPreferredOrientations(DeviceOrientation.values);
    _cameraController?.dispose();
    _poseDetector.close();
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
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Camera preview
          CameraPreview(_cameraController!),

          // Pose overlay (when showing skeleton and not recording)
          if (_showSkeleton && !_isRecording && _countdown == 0)
            CustomPaint(
              painter: PosePainter(
                _poses,
                Size(
                  _cameraController!.value.previewSize!.height,
                  _cameraController!.value.previewSize!.width,
                ),
                InputImageRotationValue.fromRawValue(
                    widget.cameras[_cameraIndex].sensorOrientation) ??
                    InputImageRotation.rotation90deg,
                showAngles: true,
              ),
            ),

          // Guide overlay (semi-transparent silhouette before recording)
          if (_showGuideOverlay && !_isRecording && _countdown == 0)
            _buildGuideOverlay(),

          // Countdown overlay
          if (_countdown > 0)
            Container(
              color: Colors.black54,
              child: Center(
                child: Text(
                  '$_countdown',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 96,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),

          // Top bar
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            left: 8,
            right: 8,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Back button
                IconButton(
                  icon: const Icon(Symbols.arrow_back, color: Colors.white, size: 28),
                  onPressed: _isRecording ? null : () => Navigator.of(context).pop(),
                ),
                // Skeleton toggle
                if (!_isRecording)
                  GestureDetector(
                    onTap: () => setState(() => _showSkeleton = !_showSkeleton),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.black45,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Symbols.skeleton,
                            color: _showSkeleton ? AppTheme.primaryColor : Colors.white54,
                            size: 20,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            _showSkeleton ? 'ON' : 'OFF',
                            style: TextStyle(
                              color: _showSkeleton ? AppTheme.primaryColor : Colors.white54,
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
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
                      Container(
                        width: 10,
                        height: 10,
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'REC ${_formatDuration(_recordingSeconds)} / ${_formatDuration(_maxRecordingSeconds)}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // Uploading overlay
          if (_isUploading)
            Container(
              color: Colors.black54,
              child: const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(color: Colors.white),
                    SizedBox(height: 16),
                    Text(
                      '영상 업로드 중...',
                      style: TextStyle(color: Colors.white, fontSize: 16),
                    ),
                  ],
                ),
              ),
            ),

          // Bottom controls
          Positioned(
            bottom: 20 + MediaQuery.of(context).padding.bottom,
            left: 16,
            right: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.6),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  // Gallery
                  GestureDetector(
                    onTap: _isRecording ? null : _pickVideoFromGallery,
                    child: Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: _isRecording ? Colors.white12 : Colors.white.withOpacity(0.2),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Symbols.photo_library,
                        color: _isRecording ? Colors.white24 : Colors.white,
                        size: 24,
                      ),
                    ),
                  ),

                  // Record / Stop button
                  GestureDetector(
                    onTap: _isRecording ? _stopRecording : _startRecordingWithCountdown,
                    child: Container(
                      width: 68,
                      height: 68,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 3),
                      ),
                      child: Center(
                        child: Container(
                          width: _isRecording ? 26 : 56,
                          height: _isRecording ? 26 : 56,
                          decoration: BoxDecoration(
                            color: Colors.red,
                            borderRadius: _isRecording
                                ? BorderRadius.circular(4)
                                : BorderRadius.circular(28),
                          ),
                        ),
                      ),
                    ),
                  ),

                  // Switch camera
                  GestureDetector(
                    onTap: _isRecording ? null : _switchCamera,
                    child: Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: _isRecording ? Colors.white12 : Colors.white.withOpacity(0.2),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Symbols.cameraswitch,
                        color: _isRecording ? Colors.white24 : Colors.white,
                        size: 24,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGuideOverlay() {
    return IgnorePointer(
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Side-view silhouette guide
            SizedBox(
              width: 180,
              height: 300,
              child: CustomPaint(
                painter: _SideViewGuidePainter(
                  color: Colors.white.withOpacity(0.25),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.5),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '측면에서 전신이 보이게 촬영해주세요',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.7),
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SideViewGuidePainter extends CustomPainter {
  final Color color;
  _SideViewGuidePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final cx = size.width * 0.45;

    // Head
    final headCy = size.height * 0.08;
    final headR = size.width * 0.07;
    canvas.drawCircle(Offset(cx, headCy), headR, paint);

    // Neck
    final neckTop = headCy + headR;
    final neckBottom = size.height * 0.15;
    canvas.drawLine(Offset(cx, neckTop), Offset(cx, neckBottom), paint);

    // Torso (slight lean forward for side view)
    final shoulderX = cx;
    final shoulderY = neckBottom;
    final hipX = cx + size.width * 0.03;
    final hipY = size.height * 0.45;
    canvas.drawLine(Offset(shoulderX, shoulderY), Offset(hipX, hipY), paint);

    // Right arm raised with racket (smash pose)
    final elbowX = cx - size.width * 0.08;
    final elbowY = size.height * 0.12;
    canvas.drawLine(Offset(shoulderX, shoulderY), Offset(elbowX, elbowY), paint);

    // Forearm + racket going up-back
    final handX = cx - size.width * 0.15;
    final handY = size.height * 0.04;
    canvas.drawLine(Offset(elbowX, elbowY), Offset(handX, handY), paint);

    // Racket
    final racketPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    final racketCx = handX - size.width * 0.04;
    final racketCy = handY - size.height * 0.02;
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(racketCx, racketCy),
        width: size.width * 0.1,
        height: size.width * 0.14,
      ),
      racketPaint,
    );

    // Left arm (front, slightly bent down)
    final lElbowX = cx + size.width * 0.12;
    final lElbowY = size.height * 0.22;
    canvas.drawLine(Offset(shoulderX, shoulderY), Offset(lElbowX, lElbowY), paint);
    final lHandX = cx + size.width * 0.08;
    final lHandY = size.height * 0.30;
    canvas.drawLine(Offset(lElbowX, lElbowY), Offset(lHandX, lHandY), paint);

    // Right leg
    final rKneeX = hipX - size.width * 0.05;
    final rKneeY = size.height * 0.65;
    canvas.drawLine(Offset(hipX, hipY), Offset(rKneeX, rKneeY), paint);
    final rFootX = rKneeX - size.width * 0.03;
    final rFootY = size.height * 0.85;
    canvas.drawLine(Offset(rKneeX, rKneeY), Offset(rFootX, rFootY), paint);

    // Left leg
    final lKneeX = hipX + size.width * 0.08;
    final lKneeY = size.height * 0.63;
    canvas.drawLine(Offset(hipX, hipY), Offset(lKneeX, lKneeY), paint);
    final lFootX = lKneeX + size.width * 0.05;
    final lFootY = size.height * 0.85;
    canvas.drawLine(Offset(lKneeX, lKneeY), Offset(lFootX, lFootY), paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

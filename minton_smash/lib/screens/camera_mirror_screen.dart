import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:camera/camera.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../widgets/pose_painter.dart';
import '../services/api_service.dart';

class CameraMirrorScreen extends StatefulWidget {
  final List<CameraDescription> cameras;

  const CameraMirrorScreen({super.key, required this.cameras});

  @override
  State<CameraMirrorScreen> createState() => _CameraMirrorScreenState();
}

class _CameraMirrorScreenState extends State<CameraMirrorScreen> {
  CameraController? _cameraController;
  final PoseDetector _poseDetector = PoseDetector(
      options: PoseDetectorOptions(mode: PoseDetectionMode.stream));
  bool _isBusy = false;
  List<Pose> _poses = [];
  int _cameraIndex = 0;
  bool _isRecording = false;
  int _recordingSeconds = 0;
  Map<String, double> _jointAngles = {};

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
      // Lock to portrait after camera init
      await _cameraController!.lockCaptureOrientation(DeviceOrientation.portraitUp);
      _cameraController!.startImageStream(_processCameraImage);
      setState(() {});
    } catch (e) {
      debugPrint("Camera initialization error: $e");
    }
  }

  void _switchCamera() async {
    if (widget.cameras.length < 2) return;
    _cameraIndex = (_cameraIndex + 1) % widget.cameras.length;
    _poses = [];
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

        // Restart pose detection stream
        _cameraController!.startImageStream(_processCameraImage);
      } catch (e) {
        debugPrint("Error stopping recording: $e");
        setState(() => _isRecording = false);
      }
    } else {
      try { await _cameraController!.stopImageStream(); } catch (_) {}

      // CameraX needs time to reconfigure after stopping image stream
      await Future.delayed(const Duration(milliseconds: 500));

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
  }

  void _startRecordingTimer() {
    Future.doWhile(() async {
      await Future.delayed(const Duration(seconds: 1));
      if (!_isRecording || !mounted) return false;
      setState(() => _recordingSeconds++);
      return true;
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
        setState(() {
          _poses = poses;
          _jointAngles = PosePainter.getJointAngles(poses);
        });
      }
    } catch (e) {
      debugPrint("Error processing pose: $e");
    }

    _isBusy = false;
  }

  @override
  void dispose() {
    // Restore all orientations when leaving camera screen
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

  double _calculatePowerScore() {
    if (_jointAngles.isEmpty) return 0;
    final elbow = (_jointAngles['rightElbow'] ?? _jointAngles['leftElbow'] ?? 0);
    final shoulder = (_jointAngles['rightShoulder'] ?? _jointAngles['leftShoulder'] ?? 0);
    return ((elbow / 180) * 50 + (shoulder / 180) * 50).clamp(0.0, 100.0);
  }

  @override
  Widget build(BuildContext context) {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final powerScore = _calculatePowerScore();

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
      body: Stack(
        fit: StackFit.expand,
        children: [
          CameraPreview(_cameraController!),

          // Pose overlay with angles
          if (!_isRecording)
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
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Power score (when not recording and poses detected)
                if (!_isRecording && _poses.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.6),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('파워 점수', style: TextStyle(color: Colors.white70, fontSize: 12)),
                            Text('${powerScore.toInt()}', style: TextStyle(
                              color: powerScore > 70 ? Colors.greenAccent : (powerScore > 40 ? Colors.orangeAccent : Colors.redAccent),
                              fontSize: 18, fontWeight: FontWeight.bold,
                            )),
                          ],
                        ),
                        const SizedBox(height: 6),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: powerScore / 100,
                            minHeight: 6,
                            backgroundColor: Colors.white24,
                            valueColor: AlwaysStoppedAnimation(
                              powerScore > 70 ? Colors.greenAccent : (powerScore > 40 ? Colors.orangeAccent : Colors.redAccent),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _angleMini('팔꿈치', _jointAngles['rightElbow'] ?? _jointAngles['leftElbow']),
                            _angleMini('어깨', _jointAngles['rightShoulder'] ?? _jointAngles['leftShoulder']),
                            _angleMini('무릎', _jointAngles['rightKnee'] ?? _jointAngles['leftKnee']),
                          ],
                        ),
                      ],
                    ),
                  ),

                // Record button
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.6),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
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
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _angleMini(String label, double? angle) {
    if (angle == null || angle == 0) return const SizedBox.shrink();
    return Column(
      children: [
        Text('${angle.toInt()}°', style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
        Text(label, style: const TextStyle(color: Colors.white60, fontSize: 10)),
      ],
    );
  }
}

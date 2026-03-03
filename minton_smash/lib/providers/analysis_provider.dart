import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'auth_provider.dart';

final _firestore = FirebaseFirestore.instance;

/// Stream of user's analyses ordered by newest first
final analysesProvider = StreamProvider<List<Map<String, dynamic>>>((ref) {
  final authState = ref.watch(authProvider);
  final uid = authState.user?.uid;
  if (uid == null) return Stream.value([]);

  return _firestore
      .collection('analyses')
      .where('userId', isEqualTo: uid)
      .orderBy('createdAt', descending: true)
      .limit(20)
      .snapshots()
      .map((snap) => snap.docs.map((d) => {'id': d.id, ...d.data()}).toList());
});

/// Latest single completed analysis
final latestAnalysisProvider = StreamProvider<Map<String, dynamic>?>((ref) {
  final authState = ref.watch(authProvider);
  final uid = authState.user?.uid;
  if (uid == null) return Stream.value(null);

  return _firestore
      .collection('analyses')
      .where('userId', isEqualTo: uid)
      .where('status', isEqualTo: 'completed')
      .orderBy('createdAt', descending: true)
      .limit(1)
      .snapshots()
      .map((snap) {
    if (snap.docs.isEmpty) return null;
    final doc = snap.docs.first;
    return {'id': doc.id, ...doc.data()};
  });
});

/// User stats stream
final userStatsProvider = StreamProvider<Map<String, dynamic>>((ref) {
  final authState = ref.watch(authProvider);
  final uid = authState.user?.uid;
  if (uid == null) return Stream.value({});

  return _firestore
      .collection('users')
      .doc(uid)
      .snapshots()
      .map((snap) => snap.data()?['stats'] as Map<String, dynamic>? ?? {});
});

/// Injury alerts stream
final injuryAlertsProvider = StreamProvider<List<Map<String, dynamic>>>((ref) {
  final authState = ref.watch(authProvider);
  final uid = authState.user?.uid;
  if (uid == null) return Stream.value([]);

  return _firestore
      .collection('injuryAlerts')
      .where('userId', isEqualTo: uid)
      .orderBy('createdAt', descending: true)
      .limit(10)
      .snapshots()
      .map((snap) => snap.docs.map((d) => {'id': d.id, ...d.data()}).toList());
});

/// Training progress stream
final trainingProgressProvider =
    StreamProvider<List<Map<String, dynamic>>>((ref) {
  final authState = ref.watch(authProvider);
  final uid = authState.user?.uid;
  if (uid == null) return Stream.value([]);

  return _firestore
      .collection('trainingProgress')
      .where('userId', isEqualTo: uid)
      .orderBy('date', descending: true)
      .limit(50)
      .snapshots()
      .map((snap) => snap.docs.map((d) => {'id': d.id, ...d.data()}).toList());
});

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'auth_provider.dart';

final _firestore = FirebaseFirestore.instance;

/// Sort options for analysis list
enum AnalysisSortOption { newestFirst, oldestFirst, scoreHigh, scoreLow }

/// Filter options for analysis list
enum AnalysisFilterOption { all, completed, processing, failed }

/// Current sort selection
final analysisSortProvider = StateProvider<AnalysisSortOption>(
  (ref) => AnalysisSortOption.newestFirst,
);

/// Current filter selection
final analysisFilterProvider = StateProvider<AnalysisFilterOption>(
  (ref) => AnalysisFilterOption.all,
);

/// Filtered and sorted analyses
final filteredAnalysesProvider = Provider<AsyncValue<List<Map<String, dynamic>>>>((ref) {
  final analysesAsync = ref.watch(analysesProvider);
  final sort = ref.watch(analysisSortProvider);
  final filter = ref.watch(analysisFilterProvider);

  return analysesAsync.whenData((analyses) {
    // Filter
    var filtered = analyses.where((a) {
      final status = a['status'] ?? 'processing';
      switch (filter) {
        case AnalysisFilterOption.all:
          return true;
        case AnalysisFilterOption.completed:
          return status == 'completed';
        case AnalysisFilterOption.processing:
          return status == 'processing';
        case AnalysisFilterOption.failed:
          return status == 'failed';
      }
    }).toList();

    // Sort
    switch (sort) {
      case AnalysisSortOption.newestFirst:
        // Already sorted by Firestore query
        break;
      case AnalysisSortOption.oldestFirst:
        filtered = filtered.reversed.toList();
      case AnalysisSortOption.scoreHigh:
        filtered.sort((a, b) {
          final scoreA = ((a['result'] as Map<String, dynamic>?)?['overallScore'] ?? 0).toDouble();
          final scoreB = ((b['result'] as Map<String, dynamic>?)?['overallScore'] ?? 0).toDouble();
          return scoreB.compareTo(scoreA);
        });
      case AnalysisSortOption.scoreLow:
        filtered.sort((a, b) {
          final scoreA = ((a['result'] as Map<String, dynamic>?)?['overallScore'] ?? 0).toDouble();
          final scoreB = ((b['result'] as Map<String, dynamic>?)?['overallScore'] ?? 0).toDouble();
          return scoreA.compareTo(scoreB);
        });
    }

    return filtered;
  });
});

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

/// Sample pro-player analyses (shown at top of history)
final sampleAnalysesProvider = StreamProvider<List<Map<String, dynamic>>>((ref) {
  return _firestore
      .collection('sampleAnalyses')
      .where('status', isEqualTo: 'completed')
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

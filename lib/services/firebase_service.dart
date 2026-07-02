import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

import '../firebase_options.dart';
import '../game/levels_data.dart';
import 'save_service.dart';

class ScoreEntry {
  ScoreEntry({required this.nickname, required this.timeMs, required this.deaths});

  final String nickname;
  final int timeMs;
  final int deaths;
}

/// Optional cloud layer: anonymous auth, leaderboard and progress sync.
/// Degrades silently to offline when Firebase isn't configured or reachable.
class FirebaseService {
  FirebaseService._();

  static final FirebaseService instance = FirebaseService._();

  bool _ready = false;
  bool get available => _ready;

  String? get _uid => _ready ? FirebaseAuth.instance.currentUser?.uid : null;

  Future<void> init() async {
    final options = DefaultFirebaseOptions.currentPlatform;
    if (options.apiKey == 'PLACEHOLDER') {
      debugPrint('Firebase not configured; running offline.');
      return;
    }
    try {
      await Firebase.initializeApp(options: options);
      await FirebaseAuth.instance.signInAnonymously();
      _ready = true;
      await _pullProgress();
    } catch (e) {
      debugPrint('Firebase init failed, running offline: $e');
    }
  }

  Future<void> _pullProgress() async {
    final uid = _uid;
    if (uid == null) return;
    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
      final data = doc.data();
      if (data != null && data['progress'] is Map<String, dynamic>) {
        await SaveService.instance
            .mergeProgress(data['progress'] as Map<String, dynamic>, levels.length);
      }
    } catch (e) {
      debugPrint('Progress pull failed: $e');
    }
  }

  Future<void> pushProgress() async {
    final uid = _uid;
    if (uid == null) return;
    try {
      await FirebaseFirestore.instance.collection('users').doc(uid).set({
        'nickname': SaveService.instance.nickname,
        'progress': SaveService.instance.progressSnapshot(levels.length),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('Progress push failed: $e');
    }
  }

  Future<void> submitScore({
    required int level,
    required int timeMs,
    required int deaths,
  }) async {
    final uid = _uid;
    if (uid == null) return;
    try {
      final ref = FirebaseFirestore.instance.collection('scores').doc('${uid}_$level');
      final existing = await ref.get();
      final prev = existing.data();
      if (prev != null && prev['timeMs'] is int && (prev['timeMs'] as int) <= timeMs) {
        return; // keep the better score
      }
      await ref.set({
        'uid': uid,
        'level': level,
        'nickname': SaveService.instance.nickname.isEmpty
            ? 'Stickman'
            : SaveService.instance.nickname,
        'timeMs': timeMs,
        'deaths': deaths,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('Score submit failed: $e');
    }
  }

  Future<List<ScoreEntry>> fetchLeaderboard(int level) async {
    if (!_ready) return [];
    try {
      final snap = await FirebaseFirestore.instance
          .collection('scores')
          .where('level', isEqualTo: level)
          .orderBy('timeMs')
          .limit(20)
          .get();
      return snap.docs.map((d) {
        final data = d.data();
        return ScoreEntry(
          nickname: (data['nickname'] as String?) ?? 'Stickman',
          timeMs: (data['timeMs'] as int?) ?? 0,
          deaths: (data['deaths'] as int?) ?? 0,
        );
      }).toList();
    } catch (e) {
      debugPrint('Leaderboard fetch failed: $e');
      return [];
    }
  }
}

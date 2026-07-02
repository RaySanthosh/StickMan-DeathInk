import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../firebase_options.dart';
import 'messaging_service.dart';
import 'save_service.dart';

class ScoreEntry {
  ScoreEntry({
    required this.name,
    required this.country,
    required this.timeMs,
    required this.deaths,
    required this.isMe,
  });

  final String name;
  final String country; // ISO code
  final int timeMs;
  final int deaths;
  final bool isMe;
}

/// Cloud layer: anonymous auth at launch, optional Google upgrade, FCM token
/// storage, best-score submission and the per-chapter leaderboard.
/// Degrades silently to offline whenever Firebase is unreachable.
class FirebaseService {
  FirebaseService._();

  static final FirebaseService instance = FirebaseService._();

  bool _ready = false;
  bool get available => _ready;

  User? get _user => _ready ? FirebaseAuth.instance.currentUser : null;
  String? get uid => _user?.uid;

  /// True once the anonymous account has been upgraded to Google.
  bool get isSignedIn => (_user != null && !_user!.isAnonymous);

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
      await _writeUserDoc(); // tier-1: create the profile row up front
      // FCM token stored against the user doc as soon as it's known
      await MessagingService.instance.init((token) => _saveToken(token));
    } catch (e) {
      debugPrint('Firebase init failed, running offline: $e');
    }
  }

  DocumentReference<Map<String, dynamic>>? get _userRef {
    final id = uid;
    return id == null
        ? null
        : FirebaseFirestore.instance.collection('users').doc(id);
  }

  Future<void> _writeUserDoc() async {
    final ref = _userRef;
    if (ref == null) return;
    try {
      await ref.set({
        'uid': uid,
        'isAnonymous': _user?.isAnonymous ?? true,
        'email': _user?.email,
        'name': SaveService.instance.nickname,
        'country': SaveService.instance.country,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('User doc write failed: $e');
    }
  }

  Future<void> _saveToken(String token) async {
    try {
      await _userRef?.set(
        {'fcmToken': token, 'updatedAt': FieldValue.serverTimestamp()},
        SetOptions(merge: true),
      );
    } catch (e) {
      debugPrint('FCM token save failed: $e');
    }
  }

  /// Tier-2: upgrade the anonymous account to Google (keeps the same uid and
  /// all progress) and returns the Google email, or null on cancel/failure.
  Future<String?> signInWithGoogle() async {
    if (!_ready) return null;
    try {
      final googleUser = await GoogleSignIn().signIn();
      if (googleUser == null) return null; // user cancelled
      final auth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: auth.accessToken,
        idToken: auth.idToken,
      );
      final current = FirebaseAuth.instance.currentUser;
      UserCredential result;
      if (current != null && current.isAnonymous) {
        // link preserves uid + progress; falls back to a plain sign-in if the
        // Google account was already linked to another uid
        try {
          result = await current.linkWithCredential(credential);
        } on FirebaseAuthException catch (e) {
          if (e.code == 'credential-already-in-use' ||
              e.code == 'email-already-in-use') {
            result = await FirebaseAuth.instance.signInWithCredential(credential);
          } else {
            rethrow;
          }
        }
      } else {
        result = await FirebaseAuth.instance.signInWithCredential(credential);
      }
      return result.user?.email;
    } catch (e) {
      debugPrint('Google sign-in failed: $e');
      return null;
    }
  }

  /// Persists the name + country chosen after Google sign-in.
  Future<void> saveProfile({required String name, required String country}) async {
    await SaveService.instance
        .setProfile(name: name, country: country, email: _user?.email ?? '');
    await _writeUserDoc();
  }

  /// Writes the run to scores/{uid}_{level} only when it beats the stored one
  /// (fewer deaths, tie-break faster time). Requires a Google account.
  Future<void> submitScore({
    required int level,
    required int timeMs,
    required int deaths,
  }) async {
    if (!isSignedIn) return; // leaderboard is Google-only
    final id = uid;
    if (id == null) return;
    try {
      final ref =
          FirebaseFirestore.instance.collection('scores').doc('${id}_$level');
      final prev = (await ref.get()).data();
      if (prev != null) {
        final pd = prev['deaths'] as int? ?? 1 << 30;
        final pt = prev['timeMs'] as int? ?? 1 << 30;
        final worse = deaths > pd || (deaths == pd && timeMs >= pt);
        if (worse) return; // keep the better run
      }
      await ref.set({
        'uid': id,
        'level': level,
        'deaths': deaths,
        'timeMs': timeMs,
        'name': SaveService.instance.nickname,
        'country': SaveService.instance.country,
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
          .orderBy('deaths')
          .orderBy('timeMs')
          .limit(50)
          .get();
      final me = uid;
      return snap.docs.map((d) {
        final data = d.data();
        return ScoreEntry(
          name: (data['name'] as String?)?.trim().isNotEmpty == true
              ? data['name'] as String
              : 'Stickman',
          country: (data['country'] as String?) ?? 'XX',
          timeMs: (data['timeMs'] as int?) ?? 0,
          deaths: (data['deaths'] as int?) ?? 0,
          isMe: data['uid'] == me,
        );
      }).toList();
    } catch (e) {
      debugPrint('Leaderboard fetch failed: $e');
      return [];
    }
  }
}

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../firebase_options.dart';
import '../game/levels_data.dart';
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

  /// Tagged log helper so Firebase flows are easy to filter in logcat:
  ///   adb logcat | grep DeathNoteFB
  static void _log(String tag, String msg) =>
      debugPrint('DeathNoteFB [$tag] $msg');

  /// Logs a caught error with its Firebase error code when available.
  static void _logErr(String tag, String where, Object e) {
    if (e is FirebaseAuthException) {
      _log(tag, 'FAIL $where -> FirebaseAuthException code=${e.code} '
          'message=${e.message}');
    } else if (e is FirebaseException) {
      _log(tag, 'FAIL $where -> FirebaseException plugin=${e.plugin} '
          'code=${e.code} message=${e.message}');
    } else {
      _log(tag, 'FAIL $where -> ${e.runtimeType}: $e');
    }
  }

  User? get _user => _ready ? FirebaseAuth.instance.currentUser : null;
  String? get uid => _user?.uid;

  /// True once the anonymous account has been upgraded to Google.
  bool get isSignedIn => (_user != null && !_user!.isAnonymous);

  Future<void> init() async {
    const tag = 'Create';
    final options = DefaultFirebaseOptions.currentPlatform;
    if (options.apiKey == 'PLACEHOLDER') {
      _log(tag, 'Firebase not configured (PLACEHOLDER apiKey); running offline.');
      return;
    }
    try {
      _log(tag, 'initializing Firebase...');
      await Firebase.initializeApp(options: options);
      _log(tag, 'Firebase initialized; signing in anonymously...');
      final cred = await FirebaseAuth.instance.signInAnonymously();
      _ready = true;
      _log(tag, 'anonymous account ready uid=${cred.user?.uid} '
          'isAnonymous=${cred.user?.isAnonymous}');
      await _writeUserDoc(); // tier-1: create the profile row up front
      // FCM token stored against the user doc as soon as it's known
      await MessagingService.instance.init((token) => _saveToken(token));
      _log(tag, 'init complete (messaging + user doc set up)');
    } catch (e) {
      _logErr(tag, 'init', e);
      _log(tag, 'running offline.');
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
    if (ref == null) {
      _log('Create', 'user doc write skipped: no uid (not signed in)');
      return;
    }
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
      _log('Create', 'user doc written users/$uid '
          '(isAnonymous=${_user?.isAnonymous})');
    } catch (e) {
      _logErr('Create', '_writeUserDoc users/$uid', e);
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
    const tag = 'GoogleAuth';
    if (!_ready) {
      _log(tag, 'aborted: Firebase not ready (running offline)');
      return null;
    }
    try {
      _log(tag, 'opening Google account picker...');
      final googleUser = await GoogleSignIn().signIn();
      if (googleUser == null) {
        _log(tag, 'cancelled by user (no account chosen)');
        return null;
      }
      _log(tag, 'account chosen: ${googleUser.email}; fetching tokens...');
      final auth = await googleUser.authentication;
      if (auth.idToken == null) {
        // Almost always a missing/incorrect SHA-1 in the Firebase console.
        _log(tag, 'WARNING idToken is null — check the release SHA-1 is added '
            'to Firebase and google-services.json is up to date');
      }
      final credential = GoogleAuthProvider.credential(
        accessToken: auth.accessToken,
        idToken: auth.idToken,
      );
      final current = FirebaseAuth.instance.currentUser;
      UserCredential result;
      if (current != null && current.isAnonymous) {
        _log(tag, 'linking Google to anonymous uid=${current.uid}...');
        try {
          result = await current.linkWithCredential(credential);
          _log(tag, 'linked: kept uid=${result.user?.uid}');
        } on FirebaseAuthException catch (e) {
          if (e.code == 'credential-already-in-use' ||
              e.code == 'email-already-in-use') {
            _log(tag, 'link rejected (code=${e.code}); this Google account '
                'already has its own uid — signing into it instead');
            result = await FirebaseAuth.instance.signInWithCredential(credential);
            _log(tag, 'signed in to existing uid=${result.user?.uid}');
          } else {
            rethrow;
          }
        }
      } else {
        _log(tag, 'no anonymous session to link; direct sign-in...');
        result = await FirebaseAuth.instance.signInWithCredential(credential);
        _log(tag, 'signed in uid=${result.user?.uid}');
      }
      _log(tag, 'SUCCESS email=${result.user?.email}');
      return result.user?.email;
    } catch (e) {
      _logErr(tag, 'signInWithGoogle', e);
      return null;
    }
  }

  /// Persists the name + country chosen after Google sign-in, then pushes any
  /// runs the player already completed as a guest (their Chapter-1 deaths +
  /// time) up to the leaderboard.
  Future<void> saveProfile({required String name, required String country}) async {
    await SaveService.instance
        .setProfile(name: name, country: country, email: _user?.email ?? '');
    await _writeUserDoc();
    await uploadLocalScores();
  }

  /// One-shot migration: send every locally-recorded chapter result to the
  /// leaderboard. Runs right after a guest upgrades to Google so their earlier
  /// progress isn't lost.
  Future<void> uploadLocalScores() async {
    if (!isSignedIn) return;
    for (var i = 0; i < levels.length; i++) {
      final t = SaveService.instance.bestTimeMs(i);
      final d = SaveService.instance.bestDeaths(i);
      if (t != null && d != null) {
        await submitScore(level: i, timeMs: t, deaths: d);
      }
    }
  }

  /// Writes the run to scores/{uid}_{level}, always overwriting the previous
  /// one — the newest attempt is the only one that counts ("deaths & reborn":
  /// your latest life is who you are now). Requires a Google account.
  Future<void> submitScore({
    required int level,
    required int timeMs,
    required int deaths,
  }) async {
    if (!isSignedIn) return; // leaderboard is Google-only
    final id = uid;
    if (id == null) return;
    try {
      await FirebaseFirestore.instance
          .collection('scores')
          .doc('${id}_$level')
          .set({
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

  /// Wipes the account: deletes every score row and the profile doc, removes
  /// the Firebase Auth user, clears local profile, then drops back to a fresh
  /// anonymous guest so the app keeps working. Returns false on failure.
  Future<bool> deleteAccount() async {
    const tag = 'Delete';
    if (!_ready) {
      _log(tag, 'aborted: Firebase not ready (running offline)');
      return false;
    }
    final id = uid;
    if (id == null) {
      _log(tag, 'aborted: no uid (not signed in)');
      return false;
    }
    try {
      _log(tag, 'starting deletion for uid=$id');
      final db = FirebaseFirestore.instance;
      final scores =
          await db.collection('scores').where('uid', isEqualTo: id).get();
      _log(tag, 'found ${scores.docs.length} score row(s) to delete');
      final batch = db.batch();
      for (final doc in scores.docs) {
        batch.delete(doc.reference);
      }
      batch.delete(db.collection('users').doc(id));
      await batch.commit();
      _log(tag, 'Firestore data deleted (scores + users/$id)');
      try {
        await FirebaseAuth.instance.currentUser?.delete();
        _log(tag, 'auth user deleted');
      } on FirebaseAuthException catch (e) {
        // requires-recent-login can block auth deletion, but the user's DATA is
        // already gone, which is what matters for privacy. Sign them out.
        _log(tag, 'auth delete deferred (code=${e.code}); signing out instead '
            '— data is already removed');
        await FirebaseAuth.instance.signOut();
      }
      await SaveService.instance.clearProfile();
      await FirebaseAuth.instance.signInAnonymously(); // back to a guest
      await _writeUserDoc();
      _log(tag, 'SUCCESS: account wiped, reset to fresh guest uid=$uid');
      return true;
    } catch (e) {
      _logErr(tag, 'deleteAccount', e);
      return false;
    }
  }

  Future<List<ScoreEntry>> fetchLeaderboard(int level) async {
    if (!_ready) return [];
    try {
      // Sort client-side (deaths, then time) so no Firestore composite index
      // is required. Fine for a casual game's row counts; revisit with an
      // index + server limit if a single chapter ever gets huge.
      final snap = await FirebaseFirestore.instance
          .collection('scores')
          .where('level', isEqualTo: level)
          .get();
      final me = uid;
      final entries = snap.docs.map((d) {
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
      }).toList()
        ..sort((a, b) => a.deaths != b.deaths
            ? a.deaths.compareTo(b.deaths)
            : a.timeMs.compareTo(b.timeMs));
      return entries.take(50).toList();
    } catch (e) {
      debugPrint('Leaderboard fetch failed: $e');
      return [];
    }
  }
}

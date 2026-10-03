import 'package:cloud_firestore/cloud_firestore.dart';

import '../entities/app_user.dart';
import '../entities/meal_plan.dart';
import '../entities/workout_plan.dart';

/// What [UserRepository.load] returns: the user plus today's ticked-off meals.
class LoadedUser {
  const LoadedUser({required this.user, required this.eatenMeals});

  final AppUser user;
  final Set<String> eatenMeals;
}

/// Firestore layout:
///   users/{uid}                     profile, goals, workoutPlan, mealPlan
///   users/{uid}/days/{yyyy-MM-dd}   DailyStats for that day (+ eatenMeals)
///   users/{uid}/activities/{id}     ActivityEntry
///
/// Note: Firestore keeps writes in a local queue while offline, so the Future
/// of a write may not complete until the device is back online. Don't block
/// the UI on write futures.
class UserRepository {
  UserRepository({FirebaseFirestore? db})
    : _db = db ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  DocumentReference<Map<String, dynamic>> _userDoc(String uid) =>
      _db.collection('users').doc(uid);

  // ── Load ──

  /// Loads the profile, the last 7 days of stats and recent activities.
  /// Creates the profile document for a brand-new user.
  Future<LoadedUser> load(AppUser base) async {
    final ref = _userDoc(base.uid);
    final snap = await ref.get();

    AppUser user = base;
    final data = snap.data();
    if (snap.exists && data != null) {
      // The profile doc is created at sign-up with only {createdAt, email,
      // name}. It has no `uid` or `displayName`, so take the uid from the
      // document id / auth (never from the map, or it becomes '' and every
      // later save is skipped) and read the name from `name`.
      final storedEmail = data['email'];
      final stored = AppUser.fromMap({
        ...data,
        'uid': base.uid,
        'email': (storedEmail is String && storedEmail.isNotEmpty)
            ? storedEmail
            : base.email,
        'displayName': data['displayName'] ?? data['name'],
      });
      user = stored.copyWith(
        displayName: stored.displayName ?? base.displayName,
      );

      // Backfill the uid so the document is complete from now on.
      if (data['uid'] != base.uid) {
        ref.set({'uid': base.uid}, SetOptions(merge: true)).catchError((_) {});
      }
    } else {
      // New user: create the profile in the background.
      ref.set(_profileMap(base)).catchError((_) {});
    }

    // Day documents are named yyyy-MM-dd, so comparing ids compares dates.
    // A range filter on the id (default ascending order) works with
    // Firestore's built-in index, unlike a descending sort which needs a
    // custom index.
    final now = DateTime.now();
    final firstDay = DailyStats.keyFor(
      DateTime(now.year, now.month, now.day - 6),
    );
    final daysSnap = await ref
        .collection('days')
        .where(FieldPath.documentId, isGreaterThanOrEqualTo: firstDay)
        .get();

    final todayKey = DailyStats.keyFor(DateTime.now());
    var today = DailyStats.empty();
    var eaten = <String>{};
    final history = <DailyStats>[];

    for (final d in daysSnap.docs) {
      final m = d.data();
      final stats = DailyStats.fromMap({...m, 'date': d.id});
      if (d.id == todayKey) {
        today = stats;
        eaten = (m['eatenMeals'] as List? ?? const []).map((e) => '$e').toSet();
      } else {
        history.add(stats);
      }
    }

    final actSnap = await ref
        .collection('activities')
        .orderBy('startedAt', descending: true)
        .limit(20)
        .get();
    final activities = actSnap.docs
        .map((d) => ActivityEntry.fromMap(d.data()))
        .toList();

    return LoadedUser(
      user: user.copyWith(
        today: today,
        history: history,
        activities: activities,
      ),
      eatenMeals: eaten,
    );
  }

  // ── Save ──

  /// Profile fields only. Daily stats and activities live in subcollections.
  Map<String, dynamic> _profileMap(AppUser u) {
    final m = u.toMap()
      ..remove('today')
      ..remove('history')
      ..remove('activities');
    // Don't overwrite a stored plan with null.
    if (u.workoutPlan == null) m.remove('workoutPlan');
    if (u.mealPlan == null) m.remove('mealPlan');
    return m;
  }

  Future<void> saveProfile(AppUser u) =>
      _userDoc(u.uid).set(_profileMap(u), SetOptions(merge: true));

  Future<void> saveDay(String uid, DailyStats d) =>
      _userDoc(uid)
          .collection('days')
          .doc(d.key)
          .set(d.toMap(), SetOptions(merge: true));

  Future<void> saveEatenMeals(String uid, String dayKey, Set<String> keys) =>
      _userDoc(uid).collection('days').doc(dayKey).set({
        'date': dayKey,
        'eatenMeals': keys.toList(),
      }, SetOptions(merge: true));

  Future<void> saveWorkoutPlan(String uid, WorkoutPlan plan) =>
      _userDoc(uid).set({'workoutPlan': plan.toMap()}, SetOptions(merge: true));

  Future<void> saveMealPlan(String uid, MealPlan plan) =>
      _userDoc(uid).set({'mealPlan': plan.toMap()}, SetOptions(merge: true));

  Future<void> addActivity(String uid, ActivityEntry a) =>
      _userDoc(uid).collection('activities').doc(a.id).set(a.toMap());
}

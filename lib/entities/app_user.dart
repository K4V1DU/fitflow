import 'meal_plan.dart';
import 'model_utils.dart';
import 'workout_plan.dart';

enum FitnessGoal { loseWeight, buildMuscle, stayFit, improveEndurance }

enum ExperienceLevel { beginner, intermediate, advanced }

enum DietType { anything, vegetarian, vegan, pescatarian }

// ───────────────────────── Daily stats ─────────────────────────

/// Everything tracked for one calendar day: steps, water, sleep,
/// nutrition totals and activity totals.
class DailyStats {
  const DailyStats({
    required this.date,
    this.steps = 0,
    this.waterMl = 0,
    this.sleepMinutes = 0,
    this.caloriesEaten = 0,
    this.proteinG = 0,
    this.carbsG = 0,
    this.fatG = 0,
    this.activeMinutes = 0,
    this.caloriesBurned = 0,
  });

  final DateTime date;
  final int steps;
  final int waterMl;
  final int sleepMinutes;
  final int caloriesEaten;
  final int proteinG;
  final int carbsG;
  final int fatG;
  final int activeMinutes;
  final int caloriesBurned;

  factory DailyStats.empty([DateTime? date]) =>
      DailyStats(date: dayOnly(date ?? DateTime.now()));

  /// "2026-10-02" – handy as a Firestore doc id or map key.
  static String keyFor(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  String get key => keyFor(date);
  double get waterLitres => waterMl / 1000;
  String get sleepLabel => '${sleepMinutes ~/ 60}h ${sleepMinutes % 60}m';

  DailyStats copyWith({
    int? steps,
    int? waterMl,
    int? sleepMinutes,
    int? caloriesEaten,
    int? proteinG,
    int? carbsG,
    int? fatG,
    int? activeMinutes,
    int? caloriesBurned,
  }) =>
      DailyStats(
        date: date,
        steps: steps ?? this.steps,
        waterMl: waterMl ?? this.waterMl,
        sleepMinutes: sleepMinutes ?? this.sleepMinutes,
        caloriesEaten: caloriesEaten ?? this.caloriesEaten,
        proteinG: proteinG ?? this.proteinG,
        carbsG: carbsG ?? this.carbsG,
        fatG: fatG ?? this.fatG,
        activeMinutes: activeMinutes ?? this.activeMinutes,
        caloriesBurned: caloriesBurned ?? this.caloriesBurned,
      );

  factory DailyStats.fromMap(Map<String, dynamic> m) => DailyStats(
        date: dayOnly(toDate(m['date'])),
        steps: toInt(m['steps']),
        waterMl: toInt(m['waterMl']),
        sleepMinutes: toInt(m['sleepMinutes']),
        caloriesEaten: toInt(m['caloriesEaten']),
        proteinG: toInt(m['proteinG']),
        carbsG: toInt(m['carbsG']),
        fatG: toInt(m['fatG']),
        activeMinutes: toInt(m['activeMinutes']),
        caloriesBurned: toInt(m['caloriesBurned']),
      );

  Map<String, dynamic> toMap() => {
        'date': key,
        'steps': steps,
        'waterMl': waterMl,
        'sleepMinutes': sleepMinutes,
        'caloriesEaten': caloriesEaten,
        'proteinG': proteinG,
        'carbsG': carbsG,
        'fatG': fatG,
        'activeMinutes': activeMinutes,
        'caloriesBurned': caloriesBurned,
      };
}

// ───────────────────────── Activity entry ─────────────────────────

/// One logged activity: a run, a gym session, a walk, etc.
class ActivityEntry {
  const ActivityEntry({
    required this.id,
    required this.type,
    required this.startedAt,
    required this.durationMinutes,
    this.caloriesBurned = 0,
    this.distanceKm,
    this.notes = '',
  });

  final String id;

  /// e.g. "run", "walk", "strength", "cycling", "yoga".
  final String type;
  final DateTime startedAt;
  final int durationMinutes;
  final int caloriesBurned;
  final double? distanceKm;
  final String notes;

  factory ActivityEntry.fromMap(Map<String, dynamic> m) => ActivityEntry(
        id: '${m['id'] ?? ''}',
        type: '${m['type'] ?? 'workout'}',
        startedAt: toDate(m['startedAt']),
        durationMinutes: toInt(m['durationMinutes']),
        caloriesBurned: toInt(m['caloriesBurned']),
        distanceKm:
            m['distanceKm'] == null ? null : toDouble(m['distanceKm']),
        notes: '${m['notes'] ?? ''}',
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'type': type,
        'startedAt': startedAt.toIso8601String(),
        'durationMinutes': durationMinutes,
        'caloriesBurned': caloriesBurned,
        'distanceKm': distanceKm,
        'notes': notes,
      };
}

// ───────────────────────── AppUser ─────────────────────────

class AppUser {
  const AppUser({
    required this.uid,
    required this.email,
    required this.today,
    this.displayName,
    this.photoUrl,
    this.age,
    this.heightCm,
    this.weightKg,
    this.goal = FitnessGoal.stayFit,
    this.experience = ExperienceLevel.beginner,
    this.diet = DietType.anything,
    this.dietaryRestrictions = const [],
    this.calorieGoal = 2200,
    this.proteinGoalG = 140,
    this.carbsGoalG = 250,
    this.fatGoalG = 70,
    this.stepGoal = 10000,
    this.waterGoalMl = 2500,
    this.sleepGoalMinutes = 480,
    this.history = const [],
    this.activities = const [],
    this.workoutPlan,
    this.mealPlan,
  });

  /// Fresh user right after sign-up.
  factory AppUser.newUser({
    required String uid,
    required String email,
    String? displayName,
    String? photoUrl,
  }) =>
      AppUser(
        uid: uid,
        email: email,
        displayName: displayName,
        photoUrl: photoUrl,
        today: DailyStats.empty(),
      );

  // Identity
  final String uid;
  final String email;
  final String? displayName;
  final String? photoUrl;

  // Body & preferences (used to personalise AI plans)
  final int? age;
  final double? heightCm;
  final double? weightKg;
  final FitnessGoal goal;
  final ExperienceLevel experience;
  final DietType diet;
  final List<String> dietaryRestrictions;

  // Daily targets
  final int calorieGoal;
  final int proteinGoalG;
  final int carbsGoalG;
  final int fatGoalG;
  final int stepGoal;
  final int waterGoalMl;
  final int sleepGoalMinutes;

  // Tracking
  final DailyStats today;

  /// Previous days (not including [today]).
  final List<DailyStats> history;
  final List<ActivityEntry> activities;

  // AI-generated plans
  final WorkoutPlan? workoutPlan;
  final MealPlan? mealPlan;

  // ── Derived values for the UI ──

  String get name =>
      displayName?.trim().isNotEmpty == true
          ? displayName!.trim()
          : (email.contains('@') ? email.split('@').first : 'Athlete');

  double? get bmi => (heightCm != null && heightCm! > 0 && weightKg != null)
      ? weightKg! / ((heightCm! / 100) * (heightCm! / 100))
      : null;

  double get calorieProgress => _ratio(today.caloriesEaten, calorieGoal);
  double get proteinProgress => _ratio(today.proteinG, proteinGoalG);
  double get carbsProgress => _ratio(today.carbsG, carbsGoalG);
  double get fatProgress => _ratio(today.fatG, fatGoalG);
  double get stepsProgress => _ratio(today.steps, stepGoal);
  double get waterProgress => _ratio(today.waterMl, waterGoalMl);
  double get sleepProgress => _ratio(today.sleepMinutes, sleepGoalMinutes);
  int get caloriesRemaining =>
      (calorieGoal - today.caloriesEaten).clamp(0, calorieGoal);

  /// Seven days ending today (oldest first). Missing days are zero-filled,
  /// so it plugs straight into the weekly chart.
  List<DailyStats> get last7Days {
    final byKey = {for (final d in history) d.key: d, today.key: today};
    final t = dayOnly(today.date);
    return List.generate(7, (i) {
      final day = DateTime(t.year, t.month, t.day - (6 - i));
      return byKey[DailyStats.keyFor(day)] ?? DailyStats.empty(day);
    });
  }

  int get weeklyActiveMinutes =>
      last7Days.fold(0, (s, d) => s + d.activeMinutes);

  static double _ratio(num value, num goal) =>
      goal <= 0 ? 0 : (value / goal).clamp(0.0, 1.0).toDouble();

  // ── AI context ──

  /// Only what the AI needs. No uid, email or name leave the device.
  Map<String, dynamic> toAiContext() {
    final week = last7Days;
    int avg(int Function(DailyStats) f) =>
        (week.fold<int>(0, (s, d) => s + f(d)) / week.length).round();

    return {
      'age': age,
      'heightCm': heightCm,
      'weightKg': weightKg,
      'goal': goal.name,
      'experience': experience.name,
      'diet': diet.name,
      'dietaryRestrictions': dietaryRestrictions,
      'targets': {
        'calories': calorieGoal,
        'proteinG': proteinGoalG,
        'carbsG': carbsGoalG,
        'fatG': fatGoalG,
        'steps': stepGoal,
        'waterMl': waterGoalMl,
        'sleepMinutes': sleepGoalMinutes,
      },
      'last7DaysAverage': {
        'steps': avg((d) => d.steps),
        'sleepMinutes': avg((d) => d.sleepMinutes),
        'activeMinutes': avg((d) => d.activeMinutes),
        'caloriesEaten': avg((d) => d.caloriesEaten),
      },
      'recentActivities': activities
          .take(10)
          .map((a) => {
                'type': a.type,
                'durationMinutes': a.durationMinutes,
                'caloriesBurned': a.caloriesBurned,
              })
          .toList(),
    };
  }

  // ── Updates ──

  AppUser copyWith({
    String? displayName,
    String? photoUrl,
    int? age,
    double? heightCm,
    double? weightKg,
    FitnessGoal? goal,
    ExperienceLevel? experience,
    DietType? diet,
    List<String>? dietaryRestrictions,
    int? calorieGoal,
    int? proteinGoalG,
    int? carbsGoalG,
    int? fatGoalG,
    int? stepGoal,
    int? waterGoalMl,
    int? sleepGoalMinutes,
    DailyStats? today,
    List<DailyStats>? history,
    List<ActivityEntry>? activities,
    WorkoutPlan? workoutPlan,
    MealPlan? mealPlan,
  }) =>
      AppUser(
        uid: uid,
        email: email,
        displayName: displayName ?? this.displayName,
        photoUrl: photoUrl ?? this.photoUrl,
        age: age ?? this.age,
        heightCm: heightCm ?? this.heightCm,
        weightKg: weightKg ?? this.weightKg,
        goal: goal ?? this.goal,
        experience: experience ?? this.experience,
        diet: diet ?? this.diet,
        dietaryRestrictions: dietaryRestrictions ?? this.dietaryRestrictions,
        calorieGoal: calorieGoal ?? this.calorieGoal,
        proteinGoalG: proteinGoalG ?? this.proteinGoalG,
        carbsGoalG: carbsGoalG ?? this.carbsGoalG,
        fatGoalG: fatGoalG ?? this.fatGoalG,
        stepGoal: stepGoal ?? this.stepGoal,
        waterGoalMl: waterGoalMl ?? this.waterGoalMl,
        sleepGoalMinutes: sleepGoalMinutes ?? this.sleepGoalMinutes,
        today: today ?? this.today,
        history: history ?? this.history,
        activities: activities ?? this.activities,
        workoutPlan: workoutPlan ?? this.workoutPlan,
        mealPlan: mealPlan ?? this.mealPlan,
      );

  /// Convenience: add water to today's total.
  AppUser addWater(int ml) =>
      copyWith(today: today.copyWith(waterMl: today.waterMl + ml));

  /// Convenience: log an activity and roll it into today's totals.
  AppUser logActivity(ActivityEntry entry) => copyWith(
        activities: [entry, ...activities],
        today: today.copyWith(
          activeMinutes: today.activeMinutes + entry.durationMinutes,
          caloriesBurned: today.caloriesBurned + entry.caloriesBurned,
        ),
      );

  // ── Serialization (Firestore / REST / local JSON) ──

  factory AppUser.fromMap(Map<String, dynamic> m) => AppUser(
        uid: '${m['uid'] ?? ''}',
        email: '${m['email'] ?? ''}',
        displayName: m['displayName'] as String?,
        photoUrl: m['photoUrl'] as String?,
        age: m['age'] == null ? null : toInt(m['age']),
        heightCm: m['heightCm'] == null ? null : toDouble(m['heightCm']),
        weightKg: m['weightKg'] == null ? null : toDouble(m['weightKg']),
        goal: enumFrom(FitnessGoal.values, m['goal'], FitnessGoal.stayFit),
        experience: enumFrom(
            ExperienceLevel.values, m['experience'], ExperienceLevel.beginner),
        diet: enumFrom(DietType.values, m['diet'], DietType.anything),
        dietaryRestrictions: stringList(m['dietaryRestrictions']),
        calorieGoal: toInt(m['calorieGoal'], 2200),
        proteinGoalG: toInt(m['proteinGoalG'], 140),
        carbsGoalG: toInt(m['carbsGoalG'], 250),
        fatGoalG: toInt(m['fatGoalG'], 70),
        stepGoal: toInt(m['stepGoal'], 10000),
        waterGoalMl: toInt(m['waterGoalMl'], 2500),
        sleepGoalMinutes: toInt(m['sleepGoalMinutes'], 480),
        today: m['today'] is Map
            ? DailyStats.fromMap(Map<String, dynamic>.from(m['today'] as Map))
            : DailyStats.empty(),
        history: mapList(m['history']).map(DailyStats.fromMap).toList(),
        activities: mapList(m['activities']).map(ActivityEntry.fromMap).toList(),
        workoutPlan: m['workoutPlan'] is Map
            ? WorkoutPlan.fromMap(
                Map<String, dynamic>.from(m['workoutPlan'] as Map))
            : null,
        mealPlan: m['mealPlan'] is Map
            ? MealPlan.fromMap(Map<String, dynamic>.from(m['mealPlan'] as Map))
            : null,
      );

  Map<String, dynamic> toMap() => {
        'uid': uid,
        'email': email,
        'displayName': displayName,
        'photoUrl': photoUrl,
        'age': age,
        'heightCm': heightCm,
        'weightKg': weightKg,
        'goal': goal.name,
        'experience': experience.name,
        'diet': diet.name,
        'dietaryRestrictions': dietaryRestrictions,
        'calorieGoal': calorieGoal,
        'proteinGoalG': proteinGoalG,
        'carbsGoalG': carbsGoalG,
        'fatGoalG': fatGoalG,
        'stepGoal': stepGoal,
        'waterGoalMl': waterGoalMl,
        'sleepGoalMinutes': sleepGoalMinutes,
        'today': today.toMap(),
        'history': history.map((d) => d.toMap()).toList(),
        'activities': activities.map((a) => a.toMap()).toList(),
        'workoutPlan': workoutPlan?.toMap(),
        'mealPlan': mealPlan?.toMap(),
      };
}

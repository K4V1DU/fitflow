import 'model_utils.dart';

class Exercise {
  const Exercise({
    required this.name,
    this.sets = 3,
    this.reps = '10',
    this.restSeconds = 60,
    this.muscleGroup = '',
    this.notes = '',
  });

  final String name;
  final int sets;

  /// String so the AI can return "10", "8-12" or "30s".
  final String reps;
  final int restSeconds;
  final String muscleGroup;
  final String notes;

  factory Exercise.fromMap(Map<String, dynamic> m) => Exercise(
        name: '${m['name'] ?? 'Exercise'}',
        sets: toInt(m['sets'], 3),
        reps: '${m['reps'] ?? '10'}',
        restSeconds: toInt(m['restSeconds'], 60),
        muscleGroup: '${m['muscleGroup'] ?? ''}',
        notes: '${m['notes'] ?? ''}',
      );

  Map<String, dynamic> toMap() => {
        'name': name,
        'sets': sets,
        'reps': reps,
        'restSeconds': restSeconds,
        'muscleGroup': muscleGroup,
        'notes': notes,
      };
}

class WorkoutDay {
  const WorkoutDay({
    required this.weekday,
    required this.title,
    this.focus = '',
    this.durationMinutes = 0,
    this.estimatedCalories = 0,
    this.exercises = const [],
  });

  /// 1 = Monday ... 7 = Sunday (same as DateTime.weekday).
  final int weekday;
  final String title;
  final String focus;
  final int durationMinutes;
  final int estimatedCalories;
  final List<Exercise> exercises;

  bool get isRestDay => exercises.isEmpty;

  factory WorkoutDay.fromMap(Map<String, dynamic> m) => WorkoutDay(
        weekday: toInt(m['weekday'], 1).clamp(1, 7),
        title: '${m['title'] ?? 'Workout'}',
        focus: '${m['focus'] ?? ''}',
        durationMinutes: toInt(m['durationMinutes']),
        estimatedCalories: toInt(m['estimatedCalories']),
        exercises: mapList(m['exercises']).map(Exercise.fromMap).toList(),
      );

  Map<String, dynamic> toMap() => {
        'weekday': weekday,
        'title': title,
        'focus': focus,
        'durationMinutes': durationMinutes,
        'estimatedCalories': estimatedCalories,
        'exercises': exercises.map((e) => e.toMap()).toList(),
      };
}

class WorkoutPlan {
  const WorkoutPlan({
    required this.id,
    required this.title,
    required this.createdAt,
    this.summary = '',
    this.days = const [],
    this.generatedByAi = true,
  });

  final String id;
  final String title;
  final String summary;
  final DateTime createdAt;
  final List<WorkoutDay> days;
  final bool generatedByAi;

  WorkoutDay? dayFor(int weekday) {
    for (final d in days) {
      if (d.weekday == weekday) return d;
    }
    return null;
  }

  /// Today's session, or null if the plan has nothing for today.
  WorkoutDay? get today => dayFor(DateTime.now().weekday);

  factory WorkoutPlan.fromMap(Map<String, dynamic> m) => WorkoutPlan(
        id: '${m['id'] ?? DateTime.now().millisecondsSinceEpoch}',
        title: '${m['title'] ?? 'Workout plan'}',
        summary: '${m['summary'] ?? ''}',
        createdAt: toDate(m['createdAt']),
        days: mapList(m['days']).map(WorkoutDay.fromMap).toList(),
        generatedByAi: m['generatedByAi'] as bool? ?? true,
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'title': title,
        'summary': summary,
        'createdAt': createdAt.toIso8601String(),
        'days': days.map((d) => d.toMap()).toList(),
        'generatedByAi': generatedByAi,
      };
}

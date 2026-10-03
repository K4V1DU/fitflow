import 'model_utils.dart';

enum MealType { breakfast, lunch, dinner, snack }

class Meal {
  const Meal({
    required this.type,
    required this.name,
    this.description = '',
    this.calories = 0,
    this.proteinG = 0,
    this.carbsG = 0,
    this.fatG = 0,
    this.ingredients = const [],
  });

  final MealType type;
  final String name;
  final String description;
  final int calories;
  final int proteinG;
  final int carbsG;
  final int fatG;
  final List<String> ingredients;

  factory Meal.fromMap(Map<String, dynamic> m) => Meal(
        type: enumFrom(MealType.values, m['type'], MealType.snack),
        name: '${m['name'] ?? 'Meal'}',
        description: '${m['description'] ?? ''}',
        calories: toInt(m['calories']),
        proteinG: toInt(m['proteinG']),
        carbsG: toInt(m['carbsG']),
        fatG: toInt(m['fatG']),
        ingredients: stringList(m['ingredients']),
      );

  Map<String, dynamic> toMap() => {
        'type': type.name,
        'name': name,
        'description': description,
        'calories': calories,
        'proteinG': proteinG,
        'carbsG': carbsG,
        'fatG': fatG,
        'ingredients': ingredients,
      };
}

class MealDay {
  const MealDay({required this.weekday, this.meals = const []});

  /// 1 = Monday ... 7 = Sunday (same as DateTime.weekday).
  final int weekday;
  final List<Meal> meals;

  int get totalCalories => meals.fold(0, (s, m) => s + m.calories);
  int get totalProteinG => meals.fold(0, (s, m) => s + m.proteinG);
  int get totalCarbsG => meals.fold(0, (s, m) => s + m.carbsG);
  int get totalFatG => meals.fold(0, (s, m) => s + m.fatG);

  factory MealDay.fromMap(Map<String, dynamic> m) => MealDay(
        weekday: toInt(m['weekday'], 1).clamp(1, 7),
        meals: mapList(m['meals']).map(Meal.fromMap).toList(),
      );

  Map<String, dynamic> toMap() => {
        'weekday': weekday,
        'meals': meals.map((m) => m.toMap()).toList(),
      };
}

class MealPlan {
  const MealPlan({
    required this.id,
    required this.title,
    required this.createdAt,
    this.dailyCalorieTarget = 0,
    this.days = const [],
    this.generatedByAi = true,
  });

  final String id;
  final String title;
  final DateTime createdAt;
  final int dailyCalorieTarget;
  final List<MealDay> days;
  final bool generatedByAi;

  MealDay? dayFor(int weekday) {
    for (final d in days) {
      if (d.weekday == weekday) return d;
    }
    return null;
  }

  MealDay? get today => dayFor(DateTime.now().weekday);

  factory MealPlan.fromMap(Map<String, dynamic> m) => MealPlan(
        id: '${m['id'] ?? DateTime.now().millisecondsSinceEpoch}',
        title: '${m['title'] ?? 'Meal plan'}',
        createdAt: toDate(m['createdAt']),
        dailyCalorieTarget: toInt(m['dailyCalorieTarget']),
        days: mapList(m['days']).map(MealDay.fromMap).toList(),
        generatedByAi: m['generatedByAi'] as bool? ?? true,
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'title': title,
        'createdAt': createdAt.toIso8601String(),
        'dailyCalorieTarget': dailyCalorieTarget,
        'days': days.map((d) => d.toMap()).toList(),
        'generatedByAi': generatedByAi,
      };
}

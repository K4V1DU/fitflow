import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../entities/app_user.dart';
import '../entities/meal_plan.dart';
import '../entities/workout_plan.dart';

class AiPlanException implements Exception {
  AiPlanException(this.message);
  final String message;

  @override
  String toString() => 'AiPlanException: $message';
}

/// Asks your backend to generate personalised plans with AI.
///
/// IMPORTANT: don't call an AI provider (Claude, OpenAI, ...) directly from
/// the app. An API key shipped inside a mobile app can be extracted. Put the
/// key on a server (e.g. an Express route or Cloud Function) and have it call
/// the model; this service only talks to that server.
///
/// Expected backend contract:
///   POST {baseUrl}/ai/workout-plan   body: { "user": {...}, "options": {...} }
///   POST {baseUrl}/ai/meal-plan      body: { "user": {...}, "options": {...} }
/// Each responds with JSON matching [WorkoutPlan.toMap] / [MealPlan.toMap]
/// (optionally wrapped as { "plan": {...} }). `days[].weekday` is 1=Mon..7=Sun.
class AiPlanService {
  AiPlanService({
    required this.baseUrl,
    this.tokenProvider,
    http.Client? client,
    this.timeout = const Duration(seconds: 60),
  }) : _client = client ?? http.Client();

  final String baseUrl;

  /// Return the signed-in user's ID token so your backend can verify the caller.
  final Future<String?> Function()? tokenProvider;
  final Duration timeout;
  final http.Client _client;

  Future<WorkoutPlan> generateWorkoutPlan(
    AppUser user, {
    int daysPerWeek = 4,
    int minutesPerSession = 45,
    List<String> equipment = const [],
  }) async {
    final json = await _post('/ai/workout-plan', {
      'user': user.toAiContext(),
      'options': {
        'daysPerWeek': daysPerWeek,
        'minutesPerSession': minutesPerSession,
        'equipment': equipment,
      },
    });
    return WorkoutPlan.fromMap(json);
  }

  Future<MealPlan> generateMealPlan(
    AppUser user, {
    int mealsPerDay = 4,
    int? calorieTarget,
  }) async {
    final json = await _post('/ai/meal-plan', {
      'user': user.toAiContext(),
      'options': {
        'mealsPerDay': mealsPerDay,
        'calorieTarget': calorieTarget ?? user.calorieGoal,
      },
    });
    return MealPlan.fromMap(json);
  }

  Future<Map<String, dynamic>> _post(
    String path,
    Map<String, dynamic> body,
  ) async {
    try {
      final token = await tokenProvider?.call();
      final res = await _client
          .post(
            Uri.parse('$baseUrl$path'),
            headers: {
              'Content-Type': 'application/json',
              if (token != null) 'Authorization': 'Bearer $token',
            },
            body: jsonEncode(body),
          )
          .timeout(timeout);

      if (res.statusCode < 200 || res.statusCode >= 300) {
        throw AiPlanException('Server returned ${res.statusCode}');
      }

      final decoded = jsonDecode(res.body);
      if (decoded is! Map) {
        throw AiPlanException('Unexpected response format');
      }
      final map = Map<String, dynamic>.from(decoded);
      final plan = map['plan'];
      return plan is Map ? Map<String, dynamic>.from(plan) : map;
    } on TimeoutException {
      throw AiPlanException('The AI took too long to respond. Try again.');
    } on FormatException {
      throw AiPlanException('Could not read the AI response.');
    } on AiPlanException {
      rethrow;
    } catch (e) {
      throw AiPlanException('Network error: $e');
    }
  }

  void dispose() => _client.close();
}

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../entities/app_user.dart';
import '../../entities/meal_plan.dart';
import '../../entities/workout_plan.dart';
import '../../services/ai_plan_service.dart';
import '../../services/auth_service.dart';

/// Android emulator -> your PC. On a real phone use your PC's LAN IP,
/// e.g. 'http://192.168.1.20:3000'.
const _kApiBaseUrl = 'http://10.0.2.2:3000';

/// Fills the dashboard with sample numbers until real tracking
/// (step counter, sleep, etc.) is connected. Set to false for a clean start.
const _kUseDemoData = true;

const _brand = Color(0xFF6C5CE7);
const _brandLight = Color(0xFFA29BFE);
const _accent = Color(0xFF00D2A0);
const _warm = Color(0xFFFF9F43);
const _pink = Color(0xFFFF6B81);
const _blue = Color(0xFF4DA8FF);

String _fmt(int n) =>
    n.toString().replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => ',');

String _cap(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _auth = AuthService();
  late final AiPlanService _ai;
  late AppUser _user;

  int _navIndex = 0;
  bool _busyWorkout = false;
  bool _busyMeal = false;

  /// Meals from today's plan the user has ticked off as eaten.
  final Set<String> _eaten = {};

  @override
  void initState() {
    super.initState();
    _ai = AiPlanService(baseUrl: _kApiBaseUrl);

    final u = _auth.currentUser;
    final base = AppUser.newUser(
      uid: u?.uid ?? '',
      email: u?.email ?? '',
      displayName: u?.displayName,
    );
    _user = _kUseDemoData ? _withDemoData(base) : base;
  }

  @override
  void dispose() {
    _ai.dispose();
    super.dispose();
  }

  // ── Derived view: stored stats + meals ticked off today ──

  String _mealKey(Meal m) => '${m.type.name}-${m.name}';

  AppUser get _view {
    var cal = 0, p = 0, c = 0, f = 0;
    final day = _user.mealPlan?.today;
    if (day != null) {
      for (final m in day.meals) {
        if (_eaten.contains(_mealKey(m))) {
          cal += m.calories;
          p += m.proteinG;
          c += m.carbsG;
          f += m.fatG;
        }
      }
    }
    final t = _user.today;
    return _user.copyWith(
      today: t.copyWith(
        caloriesEaten: t.caloriesEaten + cal,
        proteinG: t.proteinG + p,
        carbsG: t.carbsG + c,
        fatG: t.fatG + f,
      ),
    );
  }

  // ── Actions ──

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _generateWorkout() async {
    if (_busyWorkout) return;
    setState(() => _busyWorkout = true);
    try {
      final plan = await _ai.generateWorkoutPlan(_user);
      if (!mounted) return;
      setState(() => _user = _user.copyWith(workoutPlan: plan));
      _toast('Your new workout plan is ready');
    } on AiPlanException catch (e) {
      _toast(e.message);
    } finally {
      if (mounted) setState(() => _busyWorkout = false);
    }
  }

  Future<void> _generateMeals() async {
    if (_busyMeal) return;
    setState(() => _busyMeal = true);
    try {
      final plan = await _ai.generateMealPlan(_user);
      if (!mounted) return;
      setState(() {
        _user = _user.copyWith(mealPlan: plan);
        _eaten.clear();
      });
      _toast('Your new meal plan is ready');
    } on AiPlanException catch (e) {
      _toast(e.message);
    } finally {
      if (mounted) setState(() => _busyMeal = false);
    }
  }

  void _addWater() => setState(() => _user = _user.addWater(250));

  void _toggleMeal(Meal m) {
    final key = _mealKey(m);
    setState(() {
      if (!_eaten.remove(key)) _eaten.add(key);
    });
  }

  String get _greeting {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good morning';
    if (h < 18) return 'Good afternoon';
    return 'Good evening';
  }

  /// Simple rule-based tip from today's numbers (no AI call).
  String _coachTip(AppUser u) {
    if (u.workoutPlan == null && u.mealPlan == null) {
      return 'Let AI build your weekly workout and meal plans. '
          'It only takes a few seconds.';
    }
    final proteinLeft = u.proteinGoalG - u.today.proteinG;
    if (proteinLeft > 20) {
      return 'You are ${proteinLeft}g short on protein today. '
          'A high-protein meal would keep you on track.';
    }
    if (u.waterProgress < 0.5) {
      return 'You have had ${u.today.waterLitres.toStringAsFixed(1)} L of water. '
          'Aim for ${(u.waterGoalMl / 1000).toStringAsFixed(1)} L today.';
    }
    return 'Nice work, you are on track today. Keep it up!';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final u = _view;
    final workoutDay = u.workoutPlan?.today;
    final mealDay = u.mealPlan?.today;

    return Scaffold(
      backgroundColor: isDark
          ? const Color(0xFF111118)
          : const Color(0xFFF5F6FA),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          children: [
            _Header(greeting: _greeting, name: u.name, onLogout: _auth.logout),
            const SizedBox(height: 20),
            _CalorieCard(user: u),
            const SizedBox(height: 16),
            _AiCoachCard(
              tip: _coachTip(u),
              busyWorkout: _busyWorkout,
              busyMeal: _busyMeal,
              onGenerateWorkout: _generateWorkout,
              onGenerateMeals: _generateMeals,
            ),
            const SizedBox(height: 24),
            _SectionTitle(
              'Today\'s workout',
              actionLabel: u.workoutPlan != null ? 'Regenerate' : null,
              onAction: _busyWorkout ? null : _generateWorkout,
            ),
            const SizedBox(height: 12),
            _WorkoutSection(
              plan: u.workoutPlan,
              day: workoutDay,
              busy: _busyWorkout,
              onGenerate: _generateWorkout,
              onStart: () => _toast('Workout player coming soon'),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: _StatTile(
                    icon: Icons.directions_walk_rounded,
                    color: _accent,
                    value: _fmt(u.today.steps),
                    label: 'Steps',
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _StatTile(
                    icon: Icons.water_drop_rounded,
                    color: _blue,
                    value: '${u.today.waterLitres.toStringAsFixed(2)} L',
                    label: 'Water',
                    onAdd: _addWater,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _StatTile(
                    icon: Icons.bedtime_rounded,
                    color: _brandLight,
                    value: u.today.sleepLabel,
                    label: 'Sleep',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            const _SectionTitle('Weekly activity'),
            const SizedBox(height: 12),
            _WeeklyChart(days: u.last7Days),
            const SizedBox(height: 24),
            _SectionTitle(
              'Today\'s meals',
              actionLabel: u.mealPlan != null ? 'Regenerate' : null,
              onAction: _busyMeal ? null : _generateMeals,
            ),
            const SizedBox(height: 12),
            _MealSection(
              plan: u.mealPlan,
              day: mealDay,
              busy: _busyMeal,
              eaten: _eaten,
              keyOf: _mealKey,
              onGenerate: _generateMeals,
              onToggle: _toggleMeal,
            ),
          ],
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _navIndex,
        onDestinationSelected: (i) {
          setState(() => _navIndex = i);
          if (i != 0) {
            _toast(
              '${['', 'Workouts', 'Feed', 'Nutrition', 'Profile'][i]} coming soon',
            );
          }
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home_rounded),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.fitness_center_outlined),
            selectedIcon: Icon(Icons.fitness_center),
            label: 'Workouts',
          ),
          NavigationDestination(
            icon: Icon(Icons.dynamic_feed_outlined),
            selectedIcon: Icon(Icons.dynamic_feed),
            label: 'Feed',
          ),
          NavigationDestination(
            icon: Icon(Icons.restaurant_outlined),
            selectedIcon: Icon(Icons.restaurant),
            label: 'Nutrition',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}

/// Sample numbers so the dashboard looks alive during development.
AppUser _withDemoData(AppUser base) {
  final now = DateTime.now();
  const minutes = [40, 55, 0, 35, 60, 25];
  final history = List.generate(6, (i) {
    final day = DateTime(now.year, now.month, now.day - (6 - i));
    return DailyStats(
      date: day,
      steps: 5000 + i * 900,
      waterMl: 1800 + i * 100,
      sleepMinutes: 400 + i * 10,
      caloriesEaten: 1900 + i * 50,
      activeMinutes: minutes[i],
    );
  });
  return base.copyWith(
    today: base.today.copyWith(
      steps: 6240,
      waterMl: 1500,
      sleepMinutes: 440,
      caloriesEaten: 420,
      proteinG: 22,
      carbsG: 60,
      fatG: 14,
    ),
    history: history,
  );
}

// ───────────────────────── Shared pieces ─────────────────────────

class _Surface extends StatelessWidget {
  const _Surface({
    required this.child,
    this.padding = const EdgeInsets.all(16),
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1C1C26) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: isDark
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
      ),
      child: child,
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.title, {this.actionLabel, this.onAction});

  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: Theme.of(context).textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
        ),
        if (actionLabel != null)
          TextButton(onPressed: onAction, child: Text(actionLabel!)),
      ],
    );
  }
}

class _Spinner extends StatelessWidget {
  const _Spinner({this.color});
  final Color? color;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 18,
    height: 18,
    child: CircularProgressIndicator(strokeWidth: 2, color: color),
  );
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.icon,
    required this.color,
    required this.title,
    required this.message,
    required this.buttonLabel,
    required this.busy,
    required this.onPressed,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String message;
  final String buttonLabel;
  final bool busy;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return _Surface(
      child: Column(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, color: color),
          ),
          const SizedBox(height: 12),
          Text(
            title,
            style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(
            message,
            textAlign: TextAlign.center,
            style: textTheme.bodySmall,
          ),
          const SizedBox(height: 14),
          FilledButton.icon(
            onPressed: busy ? null : onPressed,
            style: FilledButton.styleFrom(backgroundColor: _brand),
            icon: busy
                ? const _Spinner(color: Colors.white)
                : const Icon(Icons.auto_awesome, size: 18),
            label: Text(busy ? 'Generating...' : buttonLabel),
          ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.onSurface.withOpacity(0.06),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14),
          const SizedBox(width: 4),
          Text(text, style: const TextStyle(fontSize: 12)),
        ],
      ),
    );
  }
}

// ───────────────────────── Header ─────────────────────────

class _Header extends StatelessWidget {
  const _Header({
    required this.greeting,
    required this.name,
    required this.onLogout,
  });

  final String greeting;
  final String name;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                greeting,
                style: textTheme.bodyMedium?.copyWith(
                  color: textTheme.bodyMedium?.color?.withOpacity(0.6),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
        PopupMenuButton<String>(
          tooltip: 'Account',
          onSelected: (v) {
            if (v == 'logout') onLogout();
          },
          itemBuilder: (_) => const [
            PopupMenuItem(
              value: 'logout',
              child: Row(
                children: [
                  Icon(Icons.logout, size: 18),
                  SizedBox(width: 10),
                  Text('Log out'),
                ],
              ),
            ),
          ],
          child: CircleAvatar(
            radius: 22,
            backgroundColor: _brand,
            child: Text(
              name.isNotEmpty ? name[0].toUpperCase() : 'A',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ───────────────────────── Calories ─────────────────────────

class _CalorieCard extends StatelessWidget {
  const _CalorieCard({required this.user});

  final AppUser user;

  @override
  Widget build(BuildContext context) {
    final t = user.today;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [_brand, Color(0xFF8E7CFF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: _brand.withOpacity(0.35),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          SizedBox(
            width: 120,
            height: 120,
            child: CustomPaint(
              painter: _RingPainter(progress: user.calorieProgress),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _fmt(t.caloriesEaten),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      'of ${_fmt(user.calorieGoal)} kcal',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              children: [
                _MacroBar(
                  label: 'Protein',
                  value: t.proteinG,
                  goal: user.proteinGoalG,
                ),
                const SizedBox(height: 12),
                _MacroBar(
                  label: 'Carbs',
                  value: t.carbsG,
                  goal: user.carbsGoalG,
                ),
                const SizedBox(height: 12),
                _MacroBar(label: 'Fat', value: t.fatG, goal: user.fatGoalG),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MacroBar extends StatelessWidget {
  const _MacroBar({
    required this.label,
    required this.value,
    required this.goal,
  });

  final String label;
  final int value;
  final int goal;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: const TextStyle(color: Colors.white, fontSize: 12),
            ),
            Text(
              '${value}g / ${goal}g',
              style: const TextStyle(color: Colors.white70, fontSize: 11),
            ),
          ],
        ),
        const SizedBox(height: 5),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: goal <= 0 ? 0.0 : (value / goal).clamp(0.0, 1.0),
            minHeight: 6,
            backgroundColor: Colors.white24,
            valueColor: const AlwaysStoppedAnimation(Colors.white),
          ),
        ),
      ],
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter({required this.progress});

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 11.0;
    final arcRect = (Offset.zero & size).deflate(stroke / 2);

    final track = Paint()
      ..color = Colors.white24
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke;
    final bar = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = stroke;

    canvas.drawArc(arcRect, 0, math.pi * 2, false, track);
    canvas.drawArc(
      arcRect,
      -math.pi / 2,
      math.pi * 2 * progress.clamp(0.0, 1.0),
      false,
      bar,
    );
  }

  @override
  bool shouldRepaint(_RingPainter old) => old.progress != progress;
}

// ───────────────────────── AI Coach ─────────────────────────

class _AiCoachCard extends StatelessWidget {
  const _AiCoachCard({
    required this.tip,
    required this.busyWorkout,
    required this.busyMeal,
    required this.onGenerateWorkout,
    required this.onGenerateMeals,
  });

  final String tip;
  final bool busyWorkout;
  final bool busyMeal;
  final VoidCallback onGenerateWorkout;
  final VoidCallback onGenerateMeals;

  @override
  Widget build(BuildContext context) {
    return _Surface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [_brand, _pink]),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.auto_awesome,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'AI Coach',
                style: Theme.of(context).textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            tip,
            style: Theme.of(context).textTheme.bodyMedium
                ?.copyWith(height: 1.4),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: busyWorkout ? null : onGenerateWorkout,
                  style: FilledButton.styleFrom(
                    backgroundColor: _brand,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  icon: busyWorkout
                      ? const _Spinner(color: Colors.white)
                      : const Icon(Icons.bolt_rounded, size: 18),
                  label: const Text('Workout'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: busyMeal ? null : onGenerateMeals,
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  icon: busyMeal
                      ? const _Spinner()
                      : const Icon(Icons.restaurant_menu_rounded, size: 18),
                  label: const Text('Meal plan'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ───────────────────────── Workout ─────────────────────────

class _WorkoutSection extends StatelessWidget {
  const _WorkoutSection({
    required this.plan,
    required this.day,
    required this.busy,
    required this.onGenerate,
    required this.onStart,
  });

  final WorkoutPlan? plan;
  final WorkoutDay? day;
  final bool busy;
  final VoidCallback onGenerate;
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    if (plan == null) {
      return _EmptyState(
        icon: Icons.fitness_center,
        color: _warm,
        title: 'No workout plan yet',
        message: 'Let AI build a weekly plan for your goal and level.',
        buttonLabel: 'Generate with AI',
        busy: busy,
        onPressed: onGenerate,
      );
    }

    final d = day;
    if (d == null || d.isRestDay) {
      return _Surface(
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: _accent.withOpacity(0.15),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(Icons.self_improvement_rounded, color: _accent),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Rest day',
                    style: Theme.of(context).textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Recovery is part of the plan. Stretch, walk and hydrate.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    final shown = d.exercises.take(4).toList();
    final more = d.exercises.length - shown.length;

    return _Surface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: _warm.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(Icons.fitness_center, color: _warm),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      d.title,
                      style: Theme.of(context).textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      d.focus.isEmpty ? 'Personalised by AI' : d.focus,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _Chip(
                icon: Icons.timer_outlined,
                text: '${d.durationMinutes} min',
              ),
              _Chip(
                icon: Icons.list_alt_rounded,
                text: '${d.exercises.length} exercises',
              ),
              _Chip(
                icon: Icons.local_fire_department_outlined,
                text: '${d.estimatedCalories} kcal',
              ),
            ],
          ),
          const SizedBox(height: 14),
          for (var i = 0; i < shown.length; i++)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 11,
                    backgroundColor: _brand.withOpacity(0.12),
                    child: Text(
                      '${i + 1}',
                      style: const TextStyle(
                        fontSize: 11,
                        color: _brand,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      shown[i].name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text(
                    '${shown[i].sets} × ${shown[i].reps}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          if (more > 0)
            Padding(
              padding: const EdgeInsets.only(top: 4, left: 2),
              child: Text(
                '+$more more exercises',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: onStart,
              style: FilledButton.styleFrom(
                backgroundColor: _accent,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              child: const Text('Start workout'),
            ),
          ),
        ],
      ),
    );
  }
}

// ───────────────────────── Quick stats ─────────────────────────

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.icon,
    required this.color,
    required this.value,
    required this.label,
    this.onAdd,
  });

  final IconData icon;
  final Color color;
  final String value;
  final String label;

  /// When set, shows a small "+" button (used for water).
  final VoidCallback? onAdd;

  @override
  Widget build(BuildContext context) {
    return _Surface(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
      child: Stack(
        children: [
          SizedBox(
            width: double.infinity,
            child: Column(
              children: [
                Icon(icon, color: color),
                const SizedBox(height: 8),
                FittedBox(
                  child: Text(
                    value,
                    style: Theme.of(context).textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w800),
                  ),
                ),
                Text(label, style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
          if (onAdd != null)
            Positioned(
              top: -6,
              right: -8,
              child: IconButton(
                tooltip: 'Add 250 ml',
                visualDensity: VisualDensity.compact,
                icon: Icon(Icons.add_circle_rounded, color: color, size: 22),
                onPressed: onAdd,
              ),
            ),
        ],
      ),
    );
  }
}

// ───────────────────────── Weekly chart ─────────────────────────

class _WeeklyChart extends StatelessWidget {
  const _WeeklyChart({required this.days});

  final List<DailyStats> days;

  @override
  Widget build(BuildContext context) {
    const letters = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
    final maxMin = math.max(
      60,
      days.fold<int>(0, (m, d) => math.max(m, d.activeMinutes)),
    );
    final todayIndex = days.length - 1;

    return _Surface(
      child: SizedBox(
        height: 140,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            for (var i = 0; i < days.length; i++)
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Container(
                      width: 16,
                      height: 8 + (days[i].activeMinutes / maxMin) * 90,
                      decoration: BoxDecoration(
                        gradient: i == todayIndex
                            ? const LinearGradient(
                                colors: [_brand, _brandLight],
                                begin: Alignment.bottomCenter,
                                end: Alignment.topCenter,
                              )
                            : null,
                        color: i == todayIndex
                            ? null
                            : Theme.of(context).colorScheme.onSurface
                                  .withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      letters[days[i].date.weekday - 1],
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: i == todayIndex
                            ? FontWeight.w800
                            : FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ───────────────────────── Meals ─────────────────────────

class _MealSection extends StatelessWidget {
  const _MealSection({
    required this.plan,
    required this.day,
    required this.busy,
    required this.eaten,
    required this.keyOf,
    required this.onGenerate,
    required this.onToggle,
  });

  final MealPlan? plan;
  final MealDay? day;
  final bool busy;
  final Set<String> eaten;
  final String Function(Meal) keyOf;
  final VoidCallback onGenerate;
  final void Function(Meal) onToggle;

  static IconData _iconFor(MealType t) {
    switch (t) {
      case MealType.breakfast:
        return Icons.free_breakfast_rounded;
      case MealType.lunch:
        return Icons.lunch_dining_rounded;
      case MealType.dinner:
        return Icons.dinner_dining_rounded;
      case MealType.snack:
        return Icons.cookie_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (plan == null) {
      return _EmptyState(
        icon: Icons.restaurant_menu_rounded,
        color: _accent,
        title: 'No meal plan yet',
        message:
            'Let AI plan your meals around your calories, macros and diet.',
        buttonLabel: 'Generate with AI',
        busy: busy,
        onPressed: onGenerate,
      );
    }

    final d = day;
    if (d == null || d.meals.isEmpty) {
      return _Surface(
        child: Text(
          'No meals planned for today.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 10, left: 2),
          child: Text(
            '${_fmt(d.totalCalories)} kcal planned · '
            'P ${d.totalProteinG}g · C ${d.totalCarbsG}g · F ${d.totalFatG}g',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
        for (final m in d.meals)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: () => onToggle(m),
              child: _Surface(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: _accent.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(_iconFor(m.type), color: _accent, size: 22),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            m.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${_cap(m.type.name)} · P ${m.proteinG}g · '
                            'C ${m.carbsG}g · F ${m.fatG}g',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '${m.calories} kcal',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 4),
                        Icon(
                          eaten.contains(keyOf(m))
                              ? Icons.check_circle_rounded
                              : Icons.radio_button_unchecked,
                          size: 20,
                          color: eaten.contains(keyOf(m))
                              ? _accent
                              : Colors.grey,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

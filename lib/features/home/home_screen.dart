import 'dart:async';
import 'dart:math' as math;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../entities/app_user.dart';
import '../../entities/meal_plan.dart';
import '../../entities/workout_plan.dart';
import '../../services/ai_plan_service.dart';
import '../../services/auth_service.dart';
import '../../services/user_repository.dart'; // adjust path if needed
import '../../widgets/common.dart';
import '../feed/feed_screen.dart';
import '../nutrition/nutrition_screen.dart';
import '../profile/profile_screen.dart';
import '../workouts/workouts_screen.dart';

const _kApiBaseUrl = 'https://backend-six-green-45.vercel.app';

/// Fills the dashboard with sample numbers until real tracking
/// (step counter, sleep, etc.) is connected. Set to false for a clean start.
/// Keep this false while testing persistence.
const _kUseDemoData = false;

/// Images shown in the "Today's workout" card. One is picked at random.
/// Make sure the folder is declared under `assets:` in pubspec.yaml.
const _kWorkoutImages = [
  'assets/images/image1.jpg',
  'assets/images/image2.jpg',
  'assets/images/image3.jpg',
  'assets/images/image4.jpg',
  'assets/images/image5.jpg',
  'assets/images/image6.jpg',
];

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  final _auth = AuthService();
  final _repo = UserRepository();
  late final AiPlanService _ai;
  late AppUser _user;

  bool _loading = true;
  bool _loadFailed = false;
  StreamSubscription<String?>? _photoSub;
  String? _loadError;
  int _navIndex = 0;
  bool _busyWorkout = false;
  bool _busyMeal = false;

  /// Meals from today's plan the user has ticked off as eaten.
  final Set<String> _eaten = {};

  /// Picked once per app session so it doesn't change on every rebuild.
  final String _workoutImage =
      _kWorkoutImages[math.Random().nextInt(_kWorkoutImages.length)];

  @override
  void initState() {
    super.initState();
    _ai = AiPlanService(baseUrl: _kApiBaseUrl);

    final u = _auth.currentUser;
    _user = AppUser.newUser(
      uid: u?.uid ?? '',
      email: u?.email ?? '',
      displayName: u?.displayName,
    );

    WidgetsBinding.instance.addObserver(this);
    _init();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _photoSub?.cancel();
    _ai.dispose();
    super.dispose();
  }

  /// If the app stays open past midnight, reload so "today" is the new day.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed &&
        !_loading &&
        !_loadFailed &&
        _user.uid.isNotEmpty &&
        DailyStats.keyFor(DateTime.now()) != _user.today.key) {
      _load();
    }
  }

  // ── Persistence ──

  /// After an app reload the signed-in user is restored asynchronously
  /// (especially on web), so wait for the first auth state before reading
  /// Firestore. Reading too early gave an empty uid and a blank dashboard.
  Future<void> _init() async {
    final fbUser = await FirebaseAuth.instance.authStateChanges().first;
    if (!mounted) return;
    if (fbUser == null) {
      setState(() => _loading = false);
      return;
    }
    _user = AppUser.newUser(
      uid: fbUser.uid,
      email: fbUser.email ?? '',
      displayName: fbUser.displayName,
      photoUrl: fbUser.photoURL,
    );
    await _load();
  }

  Future<void> _load() async {
    try {
      final loaded = await _repo.load(_user);
      if (!mounted) return;
      setState(() {
        _user = _kUseDemoData ? _withDemoData(loaded.user) : loaded.user;
        _eaten
          ..clear()
          ..addAll(loaded.eatenMeals);
        _loading = false;
        _loadFailed = false;
      });
      _listenPhoto();
    } catch (e) {
      debugPrint('Load failed: $e');
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadFailed = true;
        _loadError = '$e';
      });
    }
  }

  /// Picks up a profile photo that arrives after the first load (for example
  /// one uploaded during registration).
  void _listenPhoto() {
    _photoSub?.cancel();
    _photoSub = _repo.watchPhotoUrl(_user.uid).listen((url) {
      if (!mounted || url == null || url == _user.photoUrl) return;
      setState(() => _user = _user.copyWith(photoUrl: url));
    }, onError: (Object _) {});
  }

  /// Fire-and-forget save. Firestore queues writes while offline, so never
  /// await these in the UI path.
  void _persist(Future<void> Function() write) {
    if (_user.uid.isEmpty) return;
    try {
      write().catchError((Object e) {
        debugPrint('Save failed: $e');
        _toast('Could not save changes');
      });
    } catch (e) {
      debugPrint('Save failed: $e');
      _toast('Could not save changes');
    }
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
      _persist(() => _repo.saveWorkoutPlan(_user.uid, plan));
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
      _persist(() => _repo.saveMealPlan(_user.uid, plan));
      _persist(() => _repo.saveEatenMeals(_user.uid, _user.today.key, _eaten));
      _toast('Your new meal plan is ready');
    } on AiPlanException catch (e) {
      _toast(e.message);
    } finally {
      if (mounted) setState(() => _busyMeal = false);
    }
  }

  /// Applies a change to today's stats and saves it.
  /// Saves _user.today, NOT _view.today: the view includes eaten-meal macros,
  /// and saving those would double-count them on the next load.
  void _updateToday(DailyStats Function(DailyStats t) change) {
    setState(() => _user = _user.copyWith(today: change(_user.today)));
    _persist(() => _repo.saveDay(_user.uid, _user.today));
  }

  void _addWater() => _updateToday((t) => t.copyWith(waterMl: t.waterMl + 250));

  Future<void> _logSteps() async {
    final v = await showDialog<double>(
      context: context,
      builder: (_) => _NumberDialog(
        title: 'Steps today',
        label: 'Total steps',
        suffix: 'steps',
        initial: _user.today.steps == 0 ? '' : '${_user.today.steps}',
      ),
    );
    if (v == null || !mounted) return;
    final steps = v.round().clamp(0, 200000);
    _updateToday((t) => t.copyWith(steps: steps));
  }

  Future<void> _logSleep() async {
    final hours = _user.today.sleepMinutes / 60;
    final v = await showDialog<double>(
      context: context,
      builder: (_) => _NumberDialog(
        title: 'Sleep last night',
        label: 'Hours slept',
        suffix: 'h',
        decimal: true,
        initial: hours == 0 ? '' : hours.toStringAsFixed(1),
      ),
    );
    if (v == null || !mounted) return;
    final minutes = (v * 60).round().clamp(0, 24 * 60);
    _updateToday((t) => t.copyWith(sleepMinutes: minutes));
  }

  void _toggleMeal(Meal m) {
    final key = _mealKey(m);
    setState(() {
      if (!_eaten.remove(key)) _eaten.add(key);
    });
    _persist(() => _repo.saveEatenMeals(_user.uid, _user.today.key, _eaten));
  }

  /// One workout can be logged per day; the id makes that checkable.
  String get _todayWorkoutId => 'workout-${_user.today.key}';

  bool get _workoutDoneToday =>
      _user.activities.any((a) => a.id == _todayWorkoutId);

  void _completeWorkout(WorkoutDay d) {
    if (_workoutDoneToday) return;
    final entry = ActivityEntry(
      id: _todayWorkoutId,
      type: 'strength',
      startedAt: DateTime.now(),
      durationMinutes: d.durationMinutes,
      caloriesBurned: d.estimatedCalories,
      notes: d.title,
    );
    setState(() => _user = _user.logActivity(entry));
    _persist(() => _repo.addActivity(_user.uid, entry));
    // Save _user.today (activeMinutes / caloriesBurned changed), not _view.
    _persist(() => _repo.saveDay(_user.uid, _user.today));
    _toast('Workout logged. Nice work!');
  }

  void _saveProfile(AppUser updated) {
    setState(() => _user = updated);
    _persist(() => _repo.saveProfile(_user));
    _toast('Profile saved');
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
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_loadFailed) {
      // Don't show an empty dashboard: saving from it would overwrite
      // the real data with zeros.
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.cloud_off_rounded, size: 48),
              const SizedBox(height: 12),
              const Text('Could not load your data'),
              if (_loadError != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
                  child: SelectableText(
                    _loadError!,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: () {
                  setState(() {
                    _loading = true;
                    _loadFailed = false;
                  });
                  _load();
                },
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    final u = _view;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: kBg,
      ),
      child: Theme(
        data: appTheme(),
        child: Scaffold(
          body: IndexedStack(
            index: _navIndex,
            children: [
              _homeTab(u),
              WorkoutsScreen(
                plan: _user.workoutPlan,
                busy: _busyWorkout,
                completedToday: _workoutDoneToday,
                onGenerate: _generateWorkout,
                onComplete: _completeWorkout,
              ),
              FeedScreen(
                uid: _user.uid,
                authorName: _user.name,
                authorPhotoUrl: _user.photoUrl,
              ),
              NutritionScreen(
                user: u,
                busy: _busyMeal,
                eaten: _eaten,
                keyOf: _mealKey,
                onGenerate: _generateMeals,
                onToggle: _toggleMeal,
              ),
              ProfileScreen(
                user: _user,
                onSave: _saveProfile,
                onLogout: _auth.logout,
              ),
            ],
          ),
          bottomNavigationBar: _NavBar(
            index: _navIndex,
            onChanged: (i) => setState(() => _navIndex = i),
          ),
        ),
      ),
    );
  }

  /// Dates (yyyy-MM-dd) on which a workout was logged.
  Set<String> get _workoutDays => {
    for (final a in _user.activities)
      if (a.id.startsWith('workout-')) a.id.substring('workout-'.length),
  };

  Widget _homeTab(AppUser u) {
    final plan = u.workoutPlan;
    final planned = plan == null
        ? 0
        : plan.days.where((d) => !d.isRestDay).length;

    final now = DateTime.now();
    final monday = DateTime(now.year, now.month, now.day - (now.weekday - 1));
    final doneDays = _workoutDays;
    final done = [
      for (var i = 0; i < 7; i++)
        DailyStats.keyFor(DateTime(monday.year, monday.month, monday.day + i)),
    ].where((k) => doneDays.contains(k)).length;

    return Stack(
      children: [
        // Soft green glow behind the header, like the reference.
        const Positioned(
          top: 0,
          left: 0,
          right: 0,
          height: 340,
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFF1E4D1B), kBg],
              ),
            ),
          ),
        ),
        SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            children: [
              _Header(
                greeting: _greeting,
                name: u.name,
                photoUrl: u.photoUrl,
                weeklyMinutes: u.weeklyActiveMinutes,
                onAvatarTap: () => setState(() => _navIndex = 4),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  const Expanded(child: SectionTitle('Weekly Goal')),
                  if (planned > 0)
                    Text(
                      '$done/$planned',
                      style: const TextStyle(
                        color: kBrand,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              _WeekStrip(doneDays: doneDays),
              const SizedBox(height: 16),
              _TipCard(tip: _coachTip(u)),
              const SizedBox(height: 24),
              Row(
                children: [
                  const Expanded(child: SectionTitle('Today\'s workout')),
                  if (plan != null)
                    _PillButton(
                      label: _busyWorkout ? 'Generating...' : 'Regenerate',
                      icon: Icons.auto_awesome,
                      busy: _busyWorkout,
                      onTap: _busyWorkout ? null : _generateWorkout,
                    ),
                ],
              ),
              const SizedBox(height: 12),
              _WorkoutCard(
                plan: plan,
                day: plan?.today,
                busy: _busyWorkout,
                completed: _workoutDoneToday,
                imagePath: _workoutImage,
                onGenerate: _generateWorkout,
                // Jump to the Workouts tab where it can be completed.
                onStart: () => setState(() => _navIndex = 1),
              ),
              const SizedBox(height: 24),
              const SectionTitle('Nutrition today'),
              const SizedBox(height: 12),
              _CalorieCard(user: u),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _StatTile(
                      icon: Icons.directions_walk_rounded,
                      color: kBrand,
                      value: fmt(u.today.steps),
                      label: 'Steps',
                      onTap: _logSteps,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _StatTile(
                      icon: Icons.water_drop_rounded,
                      color: kBlue,
                      value: '${u.today.waterLitres.toStringAsFixed(2)} L',
                      label: 'Water',
                      onAdd: _addWater,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _StatTile(
                      icon: Icons.bedtime_rounded,
                      color: kLavender,
                      value: u.today.sleepLabel,
                      label: 'Sleep',
                      onTap: _logSleep,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              const SectionTitle('Weekly activity'),
              const SizedBox(height: 12),
              _WeeklyChart(days: u.last7Days),
              const SizedBox(height: 24),
              Row(
                children: [
                  const Expanded(child: SectionTitle('Today\'s meals')),
                  if (u.mealPlan != null)
                    _PillButton(
                      label: _busyMeal ? 'Generating...' : 'Regenerate',
                      icon: Icons.auto_awesome,
                      busy: _busyMeal,
                      onTap: _busyMeal ? null : _generateMeals,
                    ),
                ],
              ),
              const SizedBox(height: 12),
              _MealSection(
                plan: u.mealPlan,
                day: u.mealPlan?.today,
                busy: _busyMeal,
                eaten: _eaten,
                keyOf: _mealKey,
                onGenerate: _generateMeals,
                onToggle: _toggleMeal,
              ),
            ],
          ),
        ),
      ],
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

// ───────────────────────── Header ─────────────────────────

class _Header extends StatelessWidget {
  const _Header({
    required this.greeting,
    required this.name,
    required this.photoUrl,
    required this.weeklyMinutes,
    required this.onAvatarTap,
  });

  final String greeting;
  final String name;
  final String? photoUrl;
  final int weeklyMinutes;
  final VoidCallback onAvatarTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Row(
      children: [
        GestureDetector(
          onTap: onAvatarTap,
          child: Container(
            padding: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: kBrand, width: 2),
            ),
            child: Avatar(name, radius: 20, imageUrl: photoUrl),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$greeting!',
                style: textTheme.bodySmall?.copyWith(color: Colors.white70),
              ),
              Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFFFA43C), Color(0xFFE8751A)],
            ),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.local_fire_department_rounded,
                size: 16,
                color: Colors.white,
              ),
              const SizedBox(width: 4),
              Text(
                '$weeklyMinutes min',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ───────────────────────── Week strip ─────────────────────────

class _WeekStrip extends StatelessWidget {
  const _WeekStrip({required this.doneDays});

  /// Date keys (yyyy-MM-dd) with a logged workout.
  final Set<String> doneDays;

  @override
  Widget build(BuildContext context) {
    const names = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final now = DateTime.now();
    final monday = DateTime(now.year, now.month, now.day - (now.weekday - 1));

    return Row(
      children: [
        for (var i = 0; i < 7; i++)
          Builder(
            builder: (context) {
              final d = DateTime(monday.year, monday.month, monday.day + i);
              final isToday = d.day == now.day && d.month == now.month;
              final done = doneDays.contains(DailyStats.keyFor(d));
              return Expanded(
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: isToday
                        ? Colors.white
                        : Colors.white.withOpacity(0.07),
                    borderRadius: BorderRadius.circular(22),
                  ),
                  child: Column(
                    children: [
                      Text(
                        names[i],
                        style: TextStyle(
                          fontSize: 11,
                          color: isToday ? Colors.black54 : Colors.white54,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${d.day}',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: isToday ? Colors.black : Colors.white,
                        ),
                      ),
                      const SizedBox(height: 6),
                      done
                          ? Icon(
                              Icons.check_circle_rounded,
                              size: 13,
                              color: isToday ? const Color(0xFF2E7D32) : kBrand,
                            )
                          : const SizedBox(height: 13),
                    ],
                  ),
                ),
              );
            },
          ),
      ],
    );
  }
}

// ───────────────────────── Coach tip ─────────────────────────

class _TipCard extends StatelessWidget {
  const _TipCard({required this.tip});

  final String tip;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1B2A1A),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: kBrand.withOpacity(0.15)),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: kBrand, width: 3),
            ),
            child: const Icon(Icons.auto_awesome, size: 16, color: kBrand),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              tip,
              style: Theme.of(context).textTheme.bodyMedium
                  ?.copyWith(height: 1.35),
            ),
          ),
        ],
      ),
    );
  }
}

// ───────────────────────── Lime pill button ─────────────────────────

class _PillButton extends StatelessWidget {
  const _PillButton({
    required this.label,
    required this.icon,
    required this.onTap,
    this.busy = false,
  });

  final String label;
  final IconData icon;
  final VoidCallback? onTap;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: onTap == null ? 0.6 : 1,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: kBrand,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              busy
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.black,
                      ),
                    )
                  : Icon(icon, size: 14, color: Colors.black),
              const SizedBox(width: 5),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.black,
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ───────────────────────── Workout card ─────────────────────────

class _WorkoutCard extends StatelessWidget {
  const _WorkoutCard({
    required this.plan,
    required this.day,
    required this.busy,
    required this.completed,
    required this.imagePath,
    required this.onGenerate,
    required this.onStart,
  });

  final WorkoutPlan? plan;
  final WorkoutDay? day;
  final bool busy;
  final bool completed;

  /// Asset path of the photo shown on the right side of the card.
  final String imagePath;
  final VoidCallback onGenerate;
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    if (plan == null) {
      return EmptyState(
        icon: Icons.fitness_center,
        color: kWarm,
        title: 'No workout plan yet',
        message: 'Let AI build a weekly plan for your goal and level.',
        buttonLabel: 'Generate with AI',
        busy: busy,
        onPressed: onGenerate,
      );
    }

    final d = day;
    if (d == null || d.isRestDay) {
      return Surface(
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: kBrand.withOpacity(0.15),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(Icons.self_improvement_rounded, color: kBrand),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Rest day',
                    style: textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Recovery is part of the plan. Stretch, walk and hydrate.',
                    style: textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: kCard,
        borderRadius: BorderRadius.circular(24),
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(18, 18, 8, 18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      d.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        height: 1.15,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      d.focus.isEmpty ? 'Personalised by AI' : d.focus,
                      style: textTheme.bodySmall?.copyWith(
                        color: Colors.white54,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        const Icon(
                          Icons.timer_outlined,
                          size: 14,
                          color: Colors.white54,
                        ),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            '${d.durationMinutes} min · '
                            '${d.exercises.length} exercises',
                            style: textTheme.bodySmall,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    GestureDetector(
                      onTap: onStart,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: kBrand,
                          borderRadius: BorderRadius.circular(22),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (completed) ...[
                              const Icon(
                                Icons.check_circle_rounded,
                                size: 16,
                                color: Colors.black,
                              ),
                              const SizedBox(width: 6),
                            ],
                            Text(
                              completed ? 'Completed' : 'Start workout',
                              style: const TextStyle(
                                color: Colors.black,
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Random workout photo from assets. Falls back to the old
            // dumbbell placeholder if the image can't be loaded.
            Container(
              width: 124,
              margin: const EdgeInsets.all(10),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.asset(
                      imagePath,
                      fit: BoxFit.cover,
                      errorBuilder: (_, error, __) {
                        debugPrint('Workout image error: $error');
                        return const DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [Color(0xFF2F6B1F), Color(0xFF101A0E)],
                            ),
                          ),
                          child: Center(
                            child: Icon(
                              Icons.fitness_center_rounded,
                              size: 52,
                              color: kBrand,
                            ),
                          ),
                        );
                      },
                    ),
                    // Green fade at the bottom, matching the header glow.
                    Positioned(
                      bottom: 0,
                      left: 0,
                      right: 0,
                      height: 120,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.bottomCenter,
                            end: Alignment.topCenter,
                            colors: [
                              const Color(0xFF1E4D1B),
                              const Color(0xFF1E4D1B).withOpacity(0.0),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      left: 10,
                      right: 10,
                      bottom: 10,
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 5),
                        decoration: BoxDecoration(
                          color: Colors.black54,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.local_fire_department_outlined,
                              size: 12,
                              color: Colors.white70,
                            ),
                            const SizedBox(width: 3),
                            Text(
                              '${d.estimatedCalories} kcal',
                              style: const TextStyle(fontSize: 11),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
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
        color: kCard,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 112,
            height: 112,
            child: CustomPaint(
              painter: _RingPainter(progress: user.calorieProgress),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      fmt(t.caloriesEaten),
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      'of ${fmt(user.calorieGoal)} kcal',
                      style: const TextStyle(
                        color: Colors.white54,
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
                  color: kBrand,
                ),
                const SizedBox(height: 12),
                _MacroBar(
                  label: 'Carbs',
                  value: t.carbsG,
                  goal: user.carbsGoalG,
                  color: kWarm,
                ),
                const SizedBox(height: 12),
                _MacroBar(
                  label: 'Fat',
                  value: t.fatG,
                  goal: user.fatGoalG,
                  color: kPink,
                ),
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
    required this.color,
  });

  final String label;
  final int value;
  final int goal;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(fontSize: 12)),
            Text(
              '${value}g / ${goal}g',
              style: const TextStyle(color: Colors.white54, fontSize: 11),
            ),
          ],
        ),
        const SizedBox(height: 5),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: goal <= 0 ? 0.0 : (value / goal).clamp(0.0, 1.0),
            minHeight: 6,
            backgroundColor: Colors.white12,
            valueColor: AlwaysStoppedAnimation(color),
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
      ..color = Colors.white12
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke;
    final bar = Paint()
      ..color = kBrand
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

// ───────────────────────── Bottom navigation ─────────────────────────

class _NavBar extends StatelessWidget {
  const _NavBar({required this.index, required this.onChanged});

  final int index;
  final ValueChanged<int> onChanged;

  static const _icons = [
    Icons.home_rounded,
    Icons.fitness_center_rounded,
    Icons.dynamic_feed_rounded,
    Icons.restaurant_rounded,
    Icons.person_rounded,
  ];
  static const _labels = ['Home', 'Workouts', 'Feed', 'Nutrition', 'Profile'];

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        child: Container(
          height: 70,
          padding: const EdgeInsets.symmetric(horizontal: 6),
          decoration: BoxDecoration(
            color: kCard,
            borderRadius: BorderRadius.circular(35),
            border: Border.all(color: Colors.white10),
          ),
          child: Row(
            children: [
              for (var i = 0; i < _icons.length; i++)
                Expanded(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => onChanged(i),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      margin: const EdgeInsets.symmetric(
                        vertical: 8,
                        horizontal: 2,
                      ),
                      decoration: BoxDecoration(
                        color: i == index ? Colors.white : Colors.transparent,
                        borderRadius: BorderRadius.circular(28),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            _icons[i],
                            size: 22,
                            color: i == index ? Colors.black : Colors.white54,
                          ),
                          const SizedBox(height: 2),
                          FittedBox(
                            child: Text(
                              _labels[i],
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: i == index
                                    ? Colors.black
                                    : Colors.white54,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
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
    this.onTap,
  });

  final IconData icon;
  final Color color;
  final String value;
  final String label;

  /// When set, shows a small "+" button (used for water).
  final VoidCallback? onAdd;

  /// When set, tapping the tile lets the user enter a value (steps, sleep).
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Surface(
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
              )
            else if (onTap != null)
              Positioned(
                top: -2,
                right: -4,
                child: Icon(
                  Icons.edit_rounded,
                  size: 14,
                  color: color.withOpacity(0.7),
                ),
              ),
          ],
        ),
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

    return Surface(
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
                                colors: [kBrand, kBrandLight],
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
      return EmptyState(
        icon: Icons.restaurant_menu_rounded,
        color: kAccent,
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
      return Surface(
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
            '${fmt(d.totalCalories)} kcal planned · '
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
              child: Surface(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: kAccent.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(_iconFor(m.type), color: kAccent, size: 22),
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
                            '${cap(m.type.name)} · P ${m.proteinG}g · '
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
                              ? kAccent
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

// ───────────────────────── Number input dialog ─────────────────────────

class _NumberDialog extends StatefulWidget {
  const _NumberDialog({
    required this.title,
    required this.label,
    required this.suffix,
    required this.initial,
    this.decimal = false,
  });

  final String title;
  final String label;
  final String suffix;
  final String initial;
  final bool decimal;

  @override
  State<_NumberDialog> createState() => _NumberDialogState();
}

class _NumberDialogState extends State<_NumberDialog> {
  late final TextEditingController _c = TextEditingController(
    text: widget.initial,
  );

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  void _submit() {
    final v = double.tryParse(_c.text.trim().replaceAll(',', '.'));
    Navigator.pop(context, v);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        controller: _c,
        autofocus: true,
        keyboardType: TextInputType.numberWithOptions(decimal: widget.decimal),
        onSubmitted: (_) => _submit(),
        decoration: InputDecoration(
          labelText: widget.label,
          suffixText: widget.suffix,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _submit, child: const Text('Save')),
      ],
    );
  }
}

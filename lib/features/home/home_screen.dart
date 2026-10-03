import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../services/auth_service.dart';

const _brand = Color(0xFF6C5CE7);
const _brandLight = Color(0xFFA29BFE);
const _accent = Color(0xFF00D2A0);
const _warm = Color(0xFFFF9F43);
const _pink = Color(0xFFFF6B81);

/// FitFlow home dashboard: calories, AI coach, today's workout,
/// quick stats, weekly activity and meals.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _auth = AuthService();
  int _navIndex = 0;

  String get _greeting {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good morning';
    if (h < 18) return 'Good afternoon';
    return 'Good evening';
  }

  void _soon(String what) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text('$what coming soon')));
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final user = _auth.currentUser;
    final name =
        user?.displayName ?? user?.email?.split('@').first ?? 'Athlete';

    return Scaffold(
      backgroundColor: isDark
          ? const Color(0xFF111118)
          : const Color(0xFFF5F6FA),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          children: [
            _Header(greeting: _greeting, name: name, onLogout: _auth.logout),
            const SizedBox(height: 20),
            const _CalorieCard(),
            const SizedBox(height: 16),
            _AiCoachCard(
              onGenerate: () => _soon('AI workout generator'),
              onScan: () => _soon('AI meal scan'),
            ),
            const SizedBox(height: 24),
            const _SectionTitle('Today\'s workout'),
            const SizedBox(height: 12),
            _WorkoutCard(onStart: () => _soon('Workout player')),
            const SizedBox(height: 24),
            const Row(
              children: [
                Expanded(
                  child: _StatTile(
                    icon: Icons.directions_walk_rounded,
                    color: _accent,
                    value: '6,240',
                    label: 'Steps',
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: _StatTile(
                    icon: Icons.water_drop_rounded,
                    color: Color(0xFF4DA8FF),
                    value: '1.5 L',
                    label: 'Water',
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: _StatTile(
                    icon: Icons.bedtime_rounded,
                    color: _brandLight,
                    value: '7h 20m',
                    label: 'Sleep',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            const _SectionTitle('Weekly activity'),
            const SizedBox(height: 12),
            const _WeeklyChart(),
            const SizedBox(height: 24),
            _SectionTitle(
              'Today\'s meals',
              actionLabel: 'Add',
              onAction: () => _soon('Add meal'),
            ),
            const SizedBox(height: 12),
            const _MealTile(
              icon: Icons.free_breakfast_rounded,
              name: 'Oats with banana & peanut butter',
              time: 'Breakfast · 8:10 AM',
              kcal: 420,
            ),
            const _MealTile(
              icon: Icons.lunch_dining_rounded,
              name: 'Grilled chicken rice bowl',
              time: 'Lunch · 12:45 PM',
              kcal: 640,
            ),
            const _MealTile(
              icon: Icons.cookie_rounded,
              name: 'Greek yogurt & almonds',
              time: 'Snack · 4:00 PM',
              kcal: 360,
            ),
          ],
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _navIndex,
        onDestinationSelected: (i) {
          setState(() => _navIndex = i);
          if (i != 0)
            _soon(['', 'Workouts', 'Feed', 'Nutrition', 'Profile'][i]);
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
        _Surface(
          padding: EdgeInsets.zero,
          child: IconButton(
            tooltip: 'Notifications',
            icon: const Icon(Icons.notifications_none_rounded),
            onPressed: () {},
          ),
        ),
        const SizedBox(width: 10),
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
  const _CalorieCard();

  @override
  Widget build(BuildContext context) {
    const eaten = 1420, goal = 2200;
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
              painter: _RingPainter(progress: eaten / goal),
              child: const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '1,420',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      'of 2,200 kcal',
                      style: TextStyle(color: Colors.white70, fontSize: 11),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 20),
          const Expanded(
            child: Column(
              children: [
                _MacroBar(label: 'Protein', value: 92, goal: 140),
                SizedBox(height: 12),
                _MacroBar(label: 'Carbs', value: 160, goal: 250),
                SizedBox(height: 12),
                _MacroBar(label: 'Fat', value: 38, goal: 70),
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
            value: (value / goal).clamp(0.0, 1.0),
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
    final rect = Offset.zero & size;
    final arcRect = rect.deflate(stroke / 2);

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
  const _AiCoachCard({required this.onGenerate, required this.onScan});

  final VoidCallback onGenerate;
  final VoidCallback onScan;

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
            'You are 48g short on protein today. A high-protein dinner and a '
            'light 20-minute core session would keep you on track this week.',
            style: Theme.of(context).textTheme.bodyMedium
                ?.copyWith(height: 1.4),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: onGenerate,
                  style: FilledButton.styleFrom(
                    backgroundColor: _brand,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  icon: const Icon(Icons.bolt_rounded, size: 18),
                  label: const Text('Generate workout'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onScan,
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  icon: const Icon(Icons.camera_alt_outlined, size: 18),
                  label: const Text('Scan meal'),
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

class _WorkoutCard extends StatelessWidget {
  const _WorkoutCard({required this.onStart});

  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
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
                      'Upper Body Strength',
                      style: Theme.of(context).textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Personalised by AI · Intermediate',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _Chip(icon: Icons.timer_outlined, text: '45 min'),
              _Chip(icon: Icons.list_alt_rounded, text: '6 exercises'),
              _Chip(
                icon: Icons.local_fire_department_outlined,
                text: '320 kcal',
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: const LinearProgressIndicator(
                    value: 0.0,
                    minHeight: 6,
                    valueColor: AlwaysStoppedAnimation(_accent),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              FilledButton(
                onPressed: onStart,
                style: FilledButton.styleFrom(backgroundColor: _accent),
                child: const Text('Start'),
              ),
            ],
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

// ───────────────────────── Quick stats ─────────────────────────

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.icon,
    required this.color,
    required this.value,
    required this.label,
  });

  final IconData icon;
  final Color color;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return _Surface(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
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
    );
  }
}

// ───────────────────────── Weekly chart ─────────────────────────

class _WeeklyChart extends StatelessWidget {
  const _WeeklyChart();

  @override
  Widget build(BuildContext context) {
    const days = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
    const minutes = [40, 55, 0, 35, 60, 25, 45];
    const today = 6;
    const maxMin = 60.0;

    return _Surface(
      child: SizedBox(
        height: 140,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            for (var i = 0; i < days.length; i++)
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Container(
                      width: 16,
                      height: 8 + (minutes[i] / maxMin) * 90,
                      decoration: BoxDecoration(
                        gradient: i == today
                            ? const LinearGradient(
                                colors: [_brand, _brandLight],
                                begin: Alignment.bottomCenter,
                                end: Alignment.topCenter,
                              )
                            : null,
                        color: i == today
                            ? null
                            : Theme.of(context).colorScheme.onSurface
                                  .withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      days[i],
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: i == today
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

class _MealTile extends StatelessWidget {
  const _MealTile({
    required this.icon,
    required this.name,
    required this.time,
    required this.kcal,
  });

  final IconData icon;
  final String name;
  final String time;
  final int kcal;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
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
              child: Icon(icon, color: _accent, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 2),
                  Text(time, style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            ),
            Text(
              '$kcal kcal',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    );
  }
}

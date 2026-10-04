import 'package:flutter/material.dart';

import '../../entities/workout_plan.dart';
import '../../widgets/common.dart';

const _kPink = Color(0xFFFF5C7A);

/// Weekly workout plan: pick a day, see a progress summary, tick off
/// exercises as you go, and mark today's session as complete (which the
/// parent logs to the database).
class WorkoutsScreen extends StatefulWidget {
  const WorkoutsScreen({
    super.key,
    required this.plan,
    required this.busy,
    required this.completedToday,
    required this.onGenerate,
    required this.onComplete,
  });

  final WorkoutPlan? plan;
  final bool busy;
  final bool completedToday;
  final VoidCallback onGenerate;
  final void Function(WorkoutDay day) onComplete;

  @override
  State<WorkoutsScreen> createState() => _WorkoutsScreenState();
}

class _WorkoutsScreenState extends State<WorkoutsScreen> {
  int _selected = DateTime.now().weekday;

  /// Exercises ticked off per weekday (local, per session).
  final Map<int, Set<int>> _done = {};

  @override
  void didUpdateWidget(covariant WorkoutsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    // A new plan means old ticks no longer apply.
    if (!identical(oldWidget.plan, widget.plan)) _done.clear();
  }

  void _toggle(int weekday, int index) {
    setState(() {
      final set = _done.putIfAbsent(weekday, () => <int>{});
      if (!set.remove(index)) set.add(index);
    });
  }

  @override
  Widget build(BuildContext context) {
    final plan = widget.plan;
    final textTheme = Theme.of(context).textTheme;
    final today = DateTime.now().weekday;

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        children: [
          // ── Header ──
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Workouts',
                      style: textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      plan?.title ?? 'Your weekly training plan',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.bodyMedium?.copyWith(
                        color: textTheme.bodyMedium?.color?.withOpacity(0.6),
                      ),
                    ),
                  ],
                ),
              ),
              if (plan != null)
                TextButton.icon(
                  onPressed: widget.busy ? null : widget.onGenerate,
                  icon: widget.busy
                      ? const Spinner()
                      : const Icon(Icons.auto_awesome, size: 18),
                  label: Text(widget.busy ? 'Generating...' : 'Regenerate'),
                ),
            ],
          ),
          const SizedBox(height: 20),

          if (plan == null)
            EmptyState(
              icon: Icons.fitness_center,
              color: kWarm,
              title: 'No workout plan yet',
              message: 'Let AI build a weekly plan for your goal and level.',
              buttonLabel: 'Generate with AI',
              busy: widget.busy,
              onPressed: widget.onGenerate,
            )
          else
            ..._buildPlan(plan, today),
        ],
      ),
    );
  }

  List<Widget> _buildPlan(WorkoutPlan plan, int today) {
    final day = plan.dayFor(_selected);
    final isRest = day == null || day.isRestDay;
    final isToday = _selected == today;
    final total = isRest ? 0 : day.exercises.length;
    final doneCount = (isToday && widget.completedToday)
        ? total
        : (_done[_selected]?.length ?? 0);

    return [
      DaySelector(
        selected: _selected,
        onSelect: (d) => setState(() => _selected = d),
        hasContent: (d) => !(plan.dayFor(d)?.isRestDay ?? true),
      ),
      const SizedBox(height: 16),
      _SummaryCard(
        plan: plan,
        day: isRest ? null : day,
        weekday: _selected,
        isToday: isToday,
        done: doneCount,
        total: total,
      ),
      const SizedBox(height: 14),
      if (isRest)
        const _RestCard()
      else ...[
        for (var i = 0; i < day.exercises.length; i++)
          _ExerciseCard(
            index: i + 1,
            exercise: day.exercises[i],
            checkable: isToday && !widget.completedToday,
            checked: (isToday && widget.completedToday) ||
                (_done[_selected]?.contains(i) ?? false),
            onToggle: () => _toggle(_selected, i),
          ),
        const SizedBox(height: 6),
        _ActionArea(
          day: day,
          weekday: _selected,
          isToday: isToday,
          completed: widget.completedToday,
          allTicked: total > 0 && doneCount >= total,
          onComplete: widget.onComplete,
        ),
      ],
    ];
  }
}

// ───────────────────────── Summary card ─────────────────────────

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.plan,
    required this.day,
    required this.weekday,
    required this.isToday,
    required this.done,
    required this.total,
  });

  final WorkoutPlan plan;
  final WorkoutDay? day; // null = rest day
  final int weekday;
  final bool isToday;
  final int done;
  final int total;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final d = day;

    final active = plan.days.where((x) => !x.isRestDay).toList();
    final weekMinutes = active.fold<int>(0, (s, x) => s + x.durationMinutes);

    final String headline;
    final String subtitle;
    final List<_StatData> stats;

    if (d == null) {
      headline = 'Rest day';
      subtitle = '${weekdayName(weekday)} · Recovery is part of the plan';
      stats = [
        _StatData('${active.length}', 'Workouts', kAccent),
        _StatData('${7 - active.length}', 'Rest days', kWarm),
        _StatData(fmt(weekMinutes), 'Min / week', _kPink),
      ];
    } else {
      final sets = d.exercises.fold<int>(0, (s, e) => s + e.sets);
      headline = '${d.durationMinutes} min planned';
      subtitle = d.focus.isEmpty ? d.title : '${d.title} · ${d.focus}';
      stats = [
        _StatData('${d.exercises.length}', 'Exercises', kAccent),
        _StatData('$sets', 'Total sets', kWarm),
        _StatData(fmt(d.estimatedCalories), 'kcal burn', _kPink),
      ];
    }

    final progress = total == 0 ? 0.0 : (done / total).clamp(0.0, 1.0);

    return Surface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            headline,
            style: textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: textTheme.bodyMedium,
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              for (final s in stats) Expanded(child: _Stat(data: s)),
            ],
          ),
          if (d != null) ...[
            const SizedBox(height: 18),
            if (isToday) ...[
              Row(
                children: [
                  Text(
                    'Progress today',
                    style: textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Spacer(),
                  Text('$done / $total exercises', style: textTheme.bodyMedium),
                ],
              ),
              const SizedBox(height: 8),
              _ProgressBar(value: progress),
            ] else
              Text(
                'Scheduled for ${weekdayName(weekday)}',
                style: textTheme.bodySmall,
              ),
          ],
          if (plan.summary.isNotEmpty) ...[
            const SizedBox(height: 14),
            Text(
              plan.summary,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: textTheme.bodySmall?.copyWith(height: 1.4),
            ),
          ],
        ],
      ),
    );
  }
}

class _StatData {
  const _StatData(this.value, this.label, this.color);
  final String value;
  final String label;
  final Color color;
}

class _Stat extends StatelessWidget {
  const _Stat({required this.data});

  final _StatData data;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Row(
      children: [
        Container(
          width: 4,
          height: 38,
          decoration: BoxDecoration(
            color: data.color,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(width: 10),
        Flexible(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                data.value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text(
                data.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ProgressBar extends StatelessWidget {
  const _ProgressBar({required this.value});

  final double value;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: value),
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOut,
        builder: (_, v, __) => LinearProgressIndicator(
          value: v,
          minHeight: 10,
          color: kAccent,
          backgroundColor: kAccent.withOpacity(0.15),
        ),
      ),
    );
  }
}

// ───────────────────────── Rest day ─────────────────────────

class _RestCard extends StatelessWidget {
  const _RestCard();

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Surface(
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: kAccent.withOpacity(0.15),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(Icons.self_improvement_rounded, color: kAccent),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Recover and recharge',
                  style: textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Stretch, take a light walk and stay hydrated.',
                  style: textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ───────────────────────── Exercise card ─────────────────────────

IconData _iconFor(String muscle) {
  final m = muscle.toLowerCase();
  if (m.contains('leg') ||
      m.contains('quad') ||
      m.contains('glute') ||
      m.contains('hamstring') ||
      m.contains('calf')) {
    return Icons.directions_run_rounded;
  }
  if (m.contains('core') || m.contains('abs')) {
    return Icons.self_improvement_rounded;
  }
  if (m.contains('cardio') || m.contains('full')) {
    return Icons.favorite_rounded;
  }
  return Icons.fitness_center;
}

class _ExerciseCard extends StatefulWidget {
  const _ExerciseCard({
    required this.index,
    required this.exercise,
    required this.checkable,
    required this.checked,
    required this.onToggle,
  });

  final int index;
  final Exercise exercise;
  final bool checkable;
  final bool checked;
  final VoidCallback onToggle;

  @override
  State<_ExerciseCard> createState() => _ExerciseCardState();
}

class _ExerciseCardState extends State<_ExerciseCard> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final e = widget.exercise;
    final hasMore = e.restSeconds > 0 || e.notes.isNotEmpty;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Surface(
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: hasMore ? () => setState(() => _open = !_open) : null,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: kBrand.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(_iconFor(e.muscleGroup), color: kBrand),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          e.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                            decoration: widget.checked
                                ? TextDecoration.lineThrough
                                : null,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          e.muscleGroup.isEmpty
                              ? 'Exercise ${widget.index}'
                              : e.muscleGroup,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${e.sets} × ${e.reps}',
                    style: textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  if (widget.checkable || widget.checked) ...[
                    const SizedBox(width: 8),
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: widget.checkable ? widget.onToggle : null,
                      child: Icon(
                        widget.checked
                            ? Icons.check_circle_rounded
                            : Icons.radio_button_unchecked,
                        size: 30,
                        color: widget.checked
                            ? kAccent
                            : textTheme.bodySmall?.color?.withOpacity(0.5),
                      ),
                    ),
                  ],
                ],
              ),
              AnimatedSize(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOut,
                alignment: Alignment.topCenter,
                child: _open
                    ? Padding(
                        padding: const EdgeInsets.only(top: 12, left: 62),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (e.restSeconds > 0)
                              Row(
                                children: [
                                  const Icon(Icons.timer_outlined, size: 15),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Rest ${e.restSeconds}s between sets',
                                    style: textTheme.bodySmall,
                                  ),
                                ],
                              ),
                            if (e.notes.isNotEmpty) ...[
                              const SizedBox(height: 6),
                              Text(
                                e.notes,
                                style: textTheme.bodySmall?.copyWith(
                                  height: 1.4,
                                ),
                              ),
                            ],
                          ],
                        ),
                      )
                    : const SizedBox(width: double.infinity),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ───────────────────────── Action area ─────────────────────────

class _ActionArea extends StatelessWidget {
  const _ActionArea({
    required this.day,
    required this.weekday,
    required this.isToday,
    required this.completed,
    required this.allTicked,
    required this.onComplete,
  });

  final WorkoutDay day;
  final int weekday;
  final bool isToday;
  final bool completed;
  final bool allTicked;
  final void Function(WorkoutDay) onComplete;

  @override
  Widget build(BuildContext context) {
    if (!isToday) {
      return Center(
        child: Text(
          'Scheduled for ${weekdayName(weekday)}. You can log it on the day.',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      );
    }

    return SizedBox(
      width: double.infinity,
      child: FilledButton.icon(
        onPressed: completed ? null : () => onComplete(day),
        style: FilledButton.styleFrom(
          backgroundColor: kAccent,
          padding: const EdgeInsets.symmetric(vertical: 14),
        ),
        icon: Icon(
          completed ? Icons.check_circle_rounded : Icons.flag_rounded,
          size: 18,
        ),
        label: Text(
          completed
              ? 'Completed today'
              : allTicked
                  ? 'All done · Mark workout complete'
                  : 'Mark workout complete',
        ),
      ),
    );
  }
}
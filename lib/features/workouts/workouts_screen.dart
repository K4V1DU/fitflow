import 'package:flutter/material.dart';

import '../../entities/workout_plan.dart';
import '../../widgets/common.dart';

/// Weekly workout plan: pick a day, see its exercises, and mark today's
/// session as complete (which the parent logs to the database).
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

  @override
  Widget build(BuildContext context) {
    final plan = widget.plan;
    final textTheme = Theme.of(context).textTheme;
    final today = DateTime.now().weekday;

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        children: [
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
          else ...[
            _WeekSummary(plan: plan),
            const SizedBox(height: 16),
            DaySelector(
              selected: _selected,
              onSelect: (d) => setState(() => _selected = d),
              hasContent: (d) => !(plan.dayFor(d)?.isRestDay ?? true),
            ),
            const SizedBox(height: 16),
            _DayDetail(
              day: plan.dayFor(_selected),
              weekday: _selected,
              isToday: _selected == today,
              completed: widget.completedToday,
              onComplete: widget.onComplete,
            ),
          ],
        ],
      ),
    );
  }
}

// ───────────────────────── Week summary ─────────────────────────

class _WeekSummary extends StatelessWidget {
  const _WeekSummary({required this.plan});

  final WorkoutPlan plan;

  @override
  Widget build(BuildContext context) {
    final active = plan.days.where((d) => !d.isRestDay).toList();
    final minutes = active.fold<int>(0, (s, d) => s + d.durationMinutes);
    final kcal = active.fold<int>(0, (s, d) => s + d.estimatedCalories);

    return Surface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (plan.summary.isNotEmpty) ...[
            Text(
              plan.summary,
              style: Theme.of(context).textTheme.bodyMedium
                  ?.copyWith(height: 1.4),
            ),
            const SizedBox(height: 12),
          ],
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              InfoChip(
                icon: Icons.event_available_rounded,
                text: '${active.length} workouts / week',
              ),
              InfoChip(
                icon: Icons.timer_outlined,
                text: '${fmt(minutes)} min',
              ),
              InfoChip(
                icon: Icons.local_fire_department_outlined,
                text: '${fmt(kcal)} kcal',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ───────────────────────── Day detail ─────────────────────────

class _DayDetail extends StatelessWidget {
  const _DayDetail({
    required this.day,
    required this.weekday,
    required this.isToday,
    required this.completed,
    required this.onComplete,
  });

  final WorkoutDay? day;
  final int weekday;
  final bool isToday;
  final bool completed;
  final void Function(WorkoutDay) onComplete;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final d = day;

    if (d == null || d.isRestDay) {
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
                    '${weekdayName(weekday)} · Rest day',
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

    return Surface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: kWarm.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(Icons.fitness_center, color: kWarm),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      d.title,
                      style: textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      d.focus.isEmpty
                          ? weekdayName(weekday)
                          : '${weekdayName(weekday)} · ${d.focus}',
                      style: textTheme.bodySmall,
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
              InfoChip(
                icon: Icons.timer_outlined,
                text: '${d.durationMinutes} min',
              ),
              InfoChip(
                icon: Icons.list_alt_rounded,
                text: '${d.exercises.length} exercises',
              ),
              InfoChip(
                icon: Icons.local_fire_department_outlined,
                text: '${d.estimatedCalories} kcal',
              ),
            ],
          ),
          const SizedBox(height: 8),
          Theme(
            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
            child: Column(
              children: [
                for (var i = 0; i < d.exercises.length; i++)
                  _ExerciseTile(index: i + 1, exercise: d.exercises[i]),
              ],
            ),
          ),
          const SizedBox(height: 8),
          if (isToday)
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: completed ? null : () => onComplete(d),
                style: FilledButton.styleFrom(
                  backgroundColor: kAccent,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                icon: Icon(
                  completed
                      ? Icons.check_circle_rounded
                      : Icons.flag_rounded,
                  size: 18,
                ),
                label: Text(
                  completed ? 'Completed today' : 'Mark workout complete',
                ),
              ),
            )
          else
            Center(
              child: Text(
                'Scheduled for ${weekdayName(weekday)}. '
                'You can log it on the day.',
                textAlign: TextAlign.center,
                style: textTheme.bodySmall,
              ),
            ),
        ],
      ),
    );
  }
}

class _ExerciseTile extends StatelessWidget {
  const _ExerciseTile({required this.index, required this.exercise});

  final int index;
  final Exercise exercise;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final e = exercise;

    return ExpansionTile(
      tilePadding: EdgeInsets.zero,
      childrenPadding: const EdgeInsets.only(left: 56, bottom: 10),
      expandedAlignment: Alignment.centerLeft,
      expandedCrossAxisAlignment: CrossAxisAlignment.start,
      leading: CircleAvatar(
        radius: 13,
        backgroundColor: kBrand.withOpacity(0.12),
        child: Text(
          '$index',
          style: const TextStyle(
            fontSize: 12,
            color: kBrand,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      title: Text(
        e.name,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      subtitle: Text(
        '${e.sets} × ${e.reps}'
        '${e.muscleGroup.isEmpty ? '' : ' · ${e.muscleGroup}'}',
        style: textTheme.bodySmall,
      ),
      children: [
        Text(
          'Rest ${e.restSeconds}s between sets',
          style: textTheme.bodySmall,
        ),
        if (e.notes.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(e.notes, style: textTheme.bodySmall?.copyWith(height: 1.4)),
        ],
      ],
    );
  }
}

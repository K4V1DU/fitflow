import 'package:flutter/material.dart';

import '../../entities/app_user.dart';
import '../../entities/meal_plan.dart';
import '../../widgets/common.dart';

/// Weekly meal plan: pick a day, see its meals and macros. Meals of the
/// current day can be ticked off as eaten (the parent saves that).
class NutritionScreen extends StatefulWidget {
  const NutritionScreen({
    super.key,
    required this.user,
    required this.busy,
    required this.eaten,
    required this.keyOf,
    required this.onGenerate,
    required this.onToggle,
  });

  /// The "view" user: today's stats already include ticked-off meals.
  final AppUser user;
  final bool busy;
  final Set<String> eaten;
  final String Function(Meal) keyOf;
  final VoidCallback onGenerate;
  final void Function(Meal) onToggle;

  @override
  State<NutritionScreen> createState() => _NutritionScreenState();
}

class _NutritionScreenState extends State<NutritionScreen> {
  int _selected = DateTime.now().weekday;

  @override
  Widget build(BuildContext context) {
    final user = widget.user;
    final plan = user.mealPlan;
    final textTheme = Theme.of(context).textTheme;
    final today = DateTime.now().weekday;
    final isToday = _selected == today;
    final day = plan?.dayFor(_selected);

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
                      'Nutrition',
                      style: textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      plan?.title ?? 'Your weekly meal plan',
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
              icon: Icons.restaurant_menu_rounded,
              color: kAccent,
              title: 'No meal plan yet',
              message:
                  'Let AI plan your meals around your calories, macros and diet.',
              buttonLabel: 'Generate with AI',
              busy: widget.busy,
              onPressed: widget.onGenerate,
            )
          else ...[
            DaySelector(
              selected: _selected,
              onSelect: (d) => setState(() => _selected = d),
              hasContent: (d) => plan.dayFor(d)?.meals.isNotEmpty ?? false,
            ),
            const SizedBox(height: 16),
            if (day == null || day.meals.isEmpty)
              Surface(
                child: Text(
                  'No meals planned for ${weekdayName(_selected)}.',
                  style: textTheme.bodyMedium,
                ),
              )
            else ...[
              _DaySummary(
                day: day,
                target: plan.dailyCalorieTarget > 0
                    ? plan.dailyCalorieTarget
                    : user.calorieGoal,
                isToday: isToday,
                eatenKcal: user.today.caloriesEaten,
              ),
              const SizedBox(height: 16),
              for (final m in day.meals)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _MealCard(
                    meal: m,
                    canToggle: isToday,
                    eaten: widget.eaten.contains(widget.keyOf(m)),
                    onToggle: () => widget.onToggle(m),
                  ),
                ),
              if (!isToday)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Center(
                    child: Text(
                      'You can tick off meals on the day they are planned.',
                      textAlign: TextAlign.center,
                      style: textTheme.bodySmall,
                    ),
                  ),
                ),
            ],
          ],
        ],
      ),
    );
  }
}

// ───────────────────────── Day summary ─────────────────────────

class _DaySummary extends StatelessWidget {
  const _DaySummary({
    required this.day,
    required this.target,
    required this.isToday,
    required this.eatenKcal,
  });

  final MealDay day;
  final int target;
  final bool isToday;
  final int eatenKcal;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final planned = day.totalCalories;
    final progress = planned <= 0 ? 0.0 : (eatenKcal / planned).clamp(0.0, 1.0);

    return Surface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${fmt(planned)} kcal planned',
            style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 2),
          Text('Daily target ${fmt(target)} kcal', style: textTheme.bodySmall),
          const SizedBox(height: 14),
          Row(
            children: [
              _MacroStat(label: 'Protein', grams: day.totalProteinG, color: kBrand),
              _MacroStat(label: 'Carbs', grams: day.totalCarbsG, color: kWarm),
              _MacroStat(label: 'Fat', grams: day.totalFatG, color: kPink),
            ],
          ),
          if (isToday) ...[
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Eaten today',
                  style: textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  '${fmt(eatenKcal)} / ${fmt(planned)} kcal',
                  style: textTheme.bodySmall,
                ),
              ],
            ),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 8,
                backgroundColor: kAccent.withOpacity(0.15),
                valueColor: const AlwaysStoppedAnimation(kAccent),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _MacroStat extends StatelessWidget {
  const _MacroStat({
    required this.label,
    required this.grams,
    required this.color,
  });

  final String label;
  final int grams;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Expanded(
      child: Row(
        children: [
          Container(
            width: 4,
            height: 32,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${grams}g',
                style: textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text(label, style: textTheme.bodySmall),
            ],
          ),
        ],
      ),
    );
  }
}

// ───────────────────────── Meal card ─────────────────────────

class _MealCard extends StatefulWidget {
  const _MealCard({
    required this.meal,
    required this.canToggle,
    required this.eaten,
    required this.onToggle,
  });

  final Meal meal;
  final bool canToggle;
  final bool eaten;
  final VoidCallback onToggle;

  @override
  State<_MealCard> createState() => _MealCardState();
}

class _MealCardState extends State<_MealCard> {
  bool _open = false;

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
    final textTheme = Theme.of(context).textTheme;
    final m = widget.meal;

    return Surface(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () => setState(() => _open = !_open),
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
                        style: textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '${m.calories} kcal',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                if (widget.canToggle)
                  IconButton(
                    tooltip: widget.eaten ? 'Mark as not eaten' : 'Mark as eaten',
                    visualDensity: VisualDensity.compact,
                    onPressed: widget.onToggle,
                    icon: Icon(
                      widget.eaten
                          ? Icons.check_circle_rounded
                          : Icons.radio_button_unchecked,
                      color: widget.eaten ? kAccent : Colors.grey,
                    ),
                  )
                else
                  Icon(
                    _open ? Icons.expand_less : Icons.expand_more,
                    color: Colors.grey,
                  ),
              ],
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 200),
            alignment: Alignment.topCenter,
            child: _open
                ? Padding(
                    padding: const EdgeInsets.only(top: 12, left: 2, right: 2),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (m.description.isNotEmpty)
                          Text(
                            m.description,
                            style: textTheme.bodySmall?.copyWith(height: 1.4),
                          ),
                        if (m.ingredients.isNotEmpty) ...[
                          const SizedBox(height: 10),
                          Text(
                            'Ingredients',
                            style: textTheme.bodySmall?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 4),
                          for (final i in m.ingredients)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 1),
                              child: Text('• $i', style: textTheme.bodySmall),
                            ),
                        ],
                        if (m.description.isEmpty && m.ingredients.isEmpty)
                          Text(
                            'No extra details for this meal.',
                            style: textTheme.bodySmall,
                          ),
                      ],
                    ),
                  )
                : const SizedBox(width: double.infinity),
          ),
        ],
      ),
    );
  }
}

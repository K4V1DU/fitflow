import 'package:flutter/material.dart';

// ───────────────────────── Colors ─────────────────────────

const kBrand = Color(0xFFC4F135); // lime
const kBrandLight = Color(0xFF7EDB6B);
const kAccent = Color(0xFF8BE04B);
const kLavender = Color(0xFFA29BFE);
const kBg = Color(0xFF0C0E0C);
const kCard = Color(0xFF1A1C1A);
const kWarm = Color(0xFFFF9F43);
const kPink = Color(0xFFFF6B81);
const kBlue = Color(0xFF4DA8FF);

// ───────────────────────── Helpers ─────────────────────────

String fmt(int n) =>
    n.toString().replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => ',');

String cap(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

const _weekdayNames = [
  'Monday',
  'Tuesday',
  'Wednesday',
  'Thursday',
  'Friday',
  'Saturday',
  'Sunday',
];

/// 1 = Monday ... 7 = Sunday (same as DateTime.weekday).
String weekdayName(int weekday) => _weekdayNames[(weekday - 1).clamp(0, 6)];

// ───────────────────────── Widgets ─────────────────────────

class Surface extends StatelessWidget {
  const Surface({
    super.key,
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
        color: isDark ? kCard : Colors.white,
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

class SectionTitle extends StatelessWidget {
  const SectionTitle(this.title, {super.key, this.actionLabel, this.onAction});

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

class Spinner extends StatelessWidget {
  const Spinner({super.key, this.color});
  final Color? color;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 18,
    height: 18,
    child: CircularProgressIndicator(strokeWidth: 2, color: color),
  );
}

class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
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
    return Surface(
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
            style: FilledButton.styleFrom(backgroundColor: kBrand),
            icon: busy
                ? const Spinner(color: Colors.black)
                : const Icon(Icons.auto_awesome, size: 18),
            label: Text(busy ? 'Generating...' : buttonLabel),
          ),
        ],
      ),
    );
  }
}

class InfoChip extends StatelessWidget {
  const InfoChip({super.key, required this.icon, required this.text});

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

/// Mon–Sun picker. A dot under a day means it has content (a workout/meals).
/// Today gets an outline.
class DaySelector extends StatelessWidget {
  const DaySelector({
    super.key,
    required this.selected,
    required this.onSelect,
    required this.hasContent,
  });

  /// 1 = Monday ... 7 = Sunday.
  final int selected;
  final ValueChanged<int> onSelect;
  final bool Function(int weekday) hasContent;

  @override
  Widget build(BuildContext context) {
    const letters = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
    final today = DateTime.now().weekday;
    final onSurface = Theme.of(context).colorScheme.onSurface;

    return Row(
      children: [
        for (var wd = 1; wd <= 7; wd++)
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => onSelect(wd),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.symmetric(horizontal: 3),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: wd == selected
                      ? Colors.white
                      : onSurface.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(14),
                  border: wd == today && wd != selected
                      ? Border.all(color: kBrand, width: 1.5)
                      : null,
                ),
                child: Column(
                  children: [
                    Text(
                      letters[wd - 1],
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: wd == selected ? Colors.black : null,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: hasContent(wd)
                            ? (wd == selected ? Colors.black : kAccent)
                            : Colors.transparent,
                      ),
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

// ───────────────────────── Avatar & time helpers ─────────────────────────

class Avatar extends StatelessWidget {
  const Avatar(this.name, {super.key, this.radius = 20});

  final String name;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: radius,
      backgroundColor: kBrand,
      child: Text(
        name.isNotEmpty ? name[0].toUpperCase() : 'A',
        style: TextStyle(
          color: Colors.black,
          fontWeight: FontWeight.w700,
          fontSize: radius * 0.8,
        ),
      ),
    );
  }
}

/// "Just now", "5m", "3h", "2d", or a short date.
String timeAgo(DateTime t) {
  final d = DateTime.now().difference(t);
  if (d.inSeconds < 60) return 'Just now';
  if (d.inMinutes < 60) return '${d.inMinutes}m';
  if (d.inHours < 24) return '${d.inHours}h';
  if (d.inDays < 7) return '${d.inDays}d';
  return '${t.day}/${t.month}/${t.year}';
}

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../entities/app_user.dart';
import '../../services/cloudinary_service.dart';
import '../../widgets/common.dart';

const _goalLabels = {
  FitnessGoal.loseWeight: 'Lose weight',
  FitnessGoal.buildMuscle: 'Build muscle',
  FitnessGoal.stayFit: 'Stay fit',
  FitnessGoal.improveEndurance: 'Improve endurance',
};

const _experienceLabels = {
  ExperienceLevel.beginner: 'Beginner',
  ExperienceLevel.intermediate: 'Intermediate',
  ExperienceLevel.advanced: 'Advanced',
};

const _dietLabels = {
  DietType.anything: 'Anything',
  DietType.vegetarian: 'Vegetarian',
  DietType.vegan: 'Vegan',
  DietType.pescatarian: 'Pescatarian',
};

String _num(double v) =>
    v == v.roundToDouble() ? v.toInt().toString() : v.toStringAsFixed(1);

String _bmiLabel(double bmi) {
  if (bmi < 18.5) return 'Underweight';
  if (bmi < 25) return 'Healthy range';
  if (bmi < 30) return 'Overweight';
  return 'Obese range';
}

/// Shows the user's stats and lets them edit the profile, goals and daily
/// targets. These values are what the AI uses to build workout/meal plans.
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({
    super.key,
    required this.user,
    required this.onSave,
    required this.onLogout,
  });

  /// The stored user (not the "view" with meals added on top).
  final AppUser user;
  final void Function(AppUser updated) onSave;
  final VoidCallback onLogout;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late final _name = TextEditingController(text: widget.user.name);
  late final _age = TextEditingController(
    text: widget.user.age?.toString() ?? '',
  );
  late final _height = TextEditingController(
    text: widget.user.heightCm == null ? '' : _num(widget.user.heightCm!),
  );
  late final _weight = TextEditingController(
    text: widget.user.weightKg == null ? '' : _num(widget.user.weightKg!),
  );
  late final _restrictions = TextEditingController(
    text: widget.user.dietaryRestrictions.join(', '),
  );
  late final _calories = TextEditingController(
    text: '${widget.user.calorieGoal}',
  );
  late final _protein = TextEditingController(
    text: '${widget.user.proteinGoalG}',
  );
  late final _carbs = TextEditingController(text: '${widget.user.carbsGoalG}');
  late final _fat = TextEditingController(text: '${widget.user.fatGoalG}');
  late final _steps = TextEditingController(text: '${widget.user.stepGoal}');
  late final _water = TextEditingController(text: '${widget.user.waterGoalMl}');
  late final _sleep = TextEditingController(
    text: _num(widget.user.sleepGoalMinutes / 60),
  );

  late FitnessGoal _goal = widget.user.goal;
  late ExperienceLevel _experience = widget.user.experience;
  late DietType _diet = widget.user.diet;

  bool _uploadingPhoto = false;

  @override
  void dispose() {
    for (final c in [
      _name,
      _age,
      _height,
      _weight,
      _restrictions,
      _calories,
      _protein,
      _carbs,
      _fat,
      _steps,
      _water,
      _sleep,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  int? _i(TextEditingController c) {
    final v = int.tryParse(c.text.trim());
    return (v != null && v > 0) ? v : null;
  }

  double? _d(TextEditingController c) {
    final v = double.tryParse(c.text.trim().replaceAll(',', '.'));
    return (v != null && v > 0) ? v : null;
  }

  Future<void> _changePhoto() async {
    if (_uploadingPhoto) return;

    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_rounded),
              title: const Text('Choose from gallery'),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
            ListTile(
              leading: const Icon(Icons.photo_camera_rounded),
              title: const Text('Take a photo'),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
          ],
        ),
      ),
    );
    if (source == null) return;

    try {
      final file = await ImagePicker().pickImage(
        source: source,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 85,
      );
      if (file == null) return;

      if (mounted) setState(() => _uploadingPhoto = true);
      final bytes = await file.readAsBytes();
      final url = await CloudinaryService.uploadImage(
        bytes,
        filename: 'profile.jpg',
      );
      if (!mounted) return;
      widget.onSave(widget.user.copyWith(photoUrl: url));
    } catch (e) {
      debugPrint('Photo upload failed: $e');
      if (mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text('Could not upload photo: $e')));
      }
    } finally {
      if (mounted) setState(() => _uploadingPhoto = false);
    }
  }

  void _save() {
    final name = _name.text.trim();
    final restrictions = _restrictions.text
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
    final sleepHours = _d(_sleep);

    // Empty or invalid number fields are ignored (the old value is kept).
    final updated = widget.user.copyWith(
      displayName: name.isEmpty ? null : name,
      age: _i(_age),
      heightCm: _d(_height),
      weightKg: _d(_weight),
      goal: _goal,
      experience: _experience,
      diet: _diet,
      dietaryRestrictions: restrictions,
      calorieGoal: _i(_calories),
      proteinGoalG: _i(_protein),
      carbsGoalG: _i(_carbs),
      fatGoalG: _i(_fat),
      stepGoal: _i(_steps),
      waterGoalMl: _i(_water),
      sleepGoalMinutes: sleepHours == null ? null : (sleepHours * 60).round(),
    );

    FocusScope.of(context).unfocus();
    widget.onSave(updated);
  }

  Widget _field(
    TextEditingController c,
    String label, {
    String? suffix,
    bool number = false,
    bool decimal = false,
    String? hint,
  }) {
    return TextField(
      controller: c,
      keyboardType: number
          ? TextInputType.numberWithOptions(decimal: decimal)
          : TextInputType.text,
      textCapitalization: number
          ? TextCapitalization.none
          : TextCapitalization.sentences,
      decoration: InputDecoration(
        labelText: label,
        suffixText: suffix,
        hintText: hint,
        isDense: true,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }

  Widget _row(Widget a, Widget b) => Row(
    children: [
      Expanded(child: a),
      const SizedBox(width: 12),
      Expanded(child: b),
    ],
  );

  @override
  Widget build(BuildContext context) {
    final u = widget.user;
    final textTheme = Theme.of(context).textTheme;
    final bmi = u.bmi;

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        children: [
          Text(
            'Profile',
            style: textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 20),

          // ── Identity + body stats ──
          Surface(
            child: Column(
              children: [
                GestureDetector(
                  onTap: _changePhoto,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Avatar(u.name, radius: 44, imageUrl: u.photoUrl),
                      if (_uploadingPhoto)
                        const Positioned.fill(
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.black54,
                            ),
                            child: Center(
                              child: SizedBox(
                                width: 26,
                                height: 26,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ),
                      Positioned(
                        right: 0,
                        bottom: 0,
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: kBrand,
                            shape: BoxShape.circle,
                            border: Border.all(color: kCard, width: 2),
                          ),
                          child: const Icon(
                            Icons.photo_camera_rounded,
                            size: 16,
                            color: Colors.black,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  u.name,
                  style: textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(u.email, style: textTheme.bodySmall),
                const SizedBox(height: 16),
                Row(
                  children: [
                    _Stat(
                      label: 'Weight',
                      value: u.weightKg == null
                          ? '--'
                          : '${_num(u.weightKg!)} kg',
                    ),
                    _Stat(
                      label: 'Height',
                      value: u.heightCm == null
                          ? '--'
                          : '${_num(u.heightCm!)} cm',
                    ),
                    _Stat(
                      label: 'BMI',
                      value: bmi == null ? '--' : bmi.toStringAsFixed(1),
                    ),
                  ],
                ),
                if (bmi != null) ...[
                  const SizedBox(height: 8),
                  Text(_bmiLabel(bmi), style: textTheme.bodySmall),
                ],
                const SizedBox(height: 14),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  alignment: WrapAlignment.center,
                  children: [
                    InfoChip(
                      icon: Icons.timer_outlined,
                      text: '${u.weeklyActiveMinutes} active min this week',
                    ),
                    InfoChip(
                      icon: Icons.emoji_events_outlined,
                      text: '${u.activities.length} workouts logged',
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // ── Personal info ──
          const SectionTitle('Personal info'),
          const SizedBox(height: 12),
          Surface(
            child: Column(
              children: [
                _field(_name, 'Name'),
                const SizedBox(height: 12),
                _row(
                  _field(_age, 'Age', number: true),
                  _field(
                    _height,
                    'Height',
                    suffix: 'cm',
                    number: true,
                    decimal: true,
                  ),
                ),
                const SizedBox(height: 12),
                _row(
                  _field(
                    _weight,
                    'Weight',
                    suffix: 'kg',
                    number: true,
                    decimal: true,
                  ),
                  const SizedBox.shrink(),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // ── Goals & preferences ──
          const SectionTitle('Goals & preferences'),
          const SizedBox(height: 12),
          Surface(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _ChoiceRow<FitnessGoal>(
                  label: 'Main goal',
                  options: _goalLabels,
                  selected: _goal,
                  onSelected: (v) => setState(() => _goal = v),
                ),
                const SizedBox(height: 16),
                _ChoiceRow<ExperienceLevel>(
                  label: 'Experience',
                  options: _experienceLabels,
                  selected: _experience,
                  onSelected: (v) => setState(() => _experience = v),
                ),
                const SizedBox(height: 16),
                _ChoiceRow<DietType>(
                  label: 'Diet',
                  options: _dietLabels,
                  selected: _diet,
                  onSelected: (v) => setState(() => _diet = v),
                ),
                const SizedBox(height: 16),
                _field(
                  _restrictions,
                  'Allergies / restrictions',
                  hint: 'e.g. nuts, lactose',
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // ── Daily targets ──
          const SectionTitle('Daily targets'),
          const SizedBox(height: 12),
          Surface(
            child: Column(
              children: [
                _field(_calories, 'Calories', suffix: 'kcal', number: true),
                const SizedBox(height: 12),
                _row(
                  _field(_protein, 'Protein', suffix: 'g', number: true),
                  _field(_carbs, 'Carbs', suffix: 'g', number: true),
                ),
                const SizedBox(height: 12),
                _row(
                  _field(_fat, 'Fat', suffix: 'g', number: true),
                  _field(_steps, 'Steps', number: true),
                ),
                const SizedBox(height: 12),
                _row(
                  _field(_water, 'Water', suffix: 'ml', number: true),
                  _field(
                    _sleep,
                    'Sleep',
                    suffix: 'h',
                    number: true,
                    decimal: true,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _save,
              style: FilledButton.styleFrom(
                backgroundColor: kBrand,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              icon: const Icon(Icons.check_rounded, size: 20),
              label: const Text('Save changes'),
            ),
          ),
          const SizedBox(height: 4),
          Center(
            child: Text(
              'New AI plans use your latest goals and targets.',
              style: textTheme.bodySmall,
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: widget.onLogout,
              style: OutlinedButton.styleFrom(
                foregroundColor: kPink,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              icon: const Icon(Icons.logout, size: 18),
              label: const Text('Log out'),
            ),
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Expanded(
      child: Column(
        children: [
          FittedBox(
            child: Text(
              value,
              style: textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(height: 2),
          Text(label, style: textTheme.bodySmall),
        ],
      ),
    );
  }
}

class _ChoiceRow<T> extends StatelessWidget {
  const _ChoiceRow({
    required this.label,
    required this.options,
    required this.selected,
    required this.onSelected,
  });

  final String label;
  final Map<T, String> options;
  final T selected;
  final ValueChanged<T> onSelected;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall
              ?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final e in options.entries)
              ChoiceChip(
                label: Text(e.value),
                selected: e.key == selected,
                selectedColor: kBrand.withOpacity(0.2),
                onSelected: (_) => onSelected(e.key),
              ),
          ],
        ),
      ],
    );
  }
}

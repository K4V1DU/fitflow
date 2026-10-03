import 'dart:typed_data';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../services/auth_service.dart';
import '../../services/cloudinary_service.dart';
import '../../services/user_repository.dart';
import '../../widgets/common.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  final _authService = AuthService();

  bool _loading = false;
  bool _obscure = true;

  /// Optional profile photo chosen before registering.
  Uint8List? _photo;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _passCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  void _showMessage(String text) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _pickPhoto() async {
    if (_loading) return;

    // `null` = dismissed, `'remove'` = clear the photo.
    final choice = await showModalBottomSheet<Object>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => Theme(
        data: appTheme(),
        child: SafeArea(
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
              if (_photo != null)
                ListTile(
                  leading: const Icon(Icons.delete_outline, color: kPink),
                  title: const Text('Remove photo'),
                  onTap: () => Navigator.pop(ctx, 'remove'),
                ),
            ],
          ),
        ),
      ),
    );

    if (choice == 'remove') {
      setState(() => _photo = null);
      return;
    }
    if (choice is! ImageSource) return;

    try {
      final file = await ImagePicker().pickImage(
        source: choice,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 85,
      );
      if (file == null) return;
      final bytes = await file.readAsBytes();
      if (mounted) setState(() => _photo = bytes);
    } catch (e) {
      debugPrint('Pick failed: $e');
      if (mounted) _showMessage('Could not open the photo');
    }
  }

  /// Saves the photo URL on the new account. Failure here must not block
  /// sign-up: the user can add a photo later from Profile.
  Future<void> _savePhoto(String url) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    try {
      await UserRepository()
          .savePhotoUrl(user.uid, url)
          .timeout(const Duration(seconds: 10));
      await user.updatePhotoURL(url);
    } catch (e) {
      debugPrint('Saving profile photo failed: $e');
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      // Upload first (no account needed), so the URL is ready right away.
      String? photoUrl;
      final photo = _photo;
      if (photo != null) {
        photoUrl = await CloudinaryService.uploadImage(
          photo,
          filename: 'profile.jpg',
        );
      }

      await _authService.register(
        name: _nameCtrl.text.trim(),
        email: _emailCtrl.text.trim(),
        password: _passCtrl.text,
      );

      if (photoUrl != null) await _savePhoto(photoUrl);

      // Registration signs the user in. Close this screen so AuthGate's
      // Home screen becomes visible.
      if (mounted) Navigator.of(context).popUntil((route) => route.isFirst);
    } on FirebaseAuthException catch (e) {
      if (mounted) _showMessage(AuthService.messageFor(e));
    } catch (e) {
      debugPrint('Register failed: $e');
      if (mounted) _showMessage('Something went wrong: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      showBack: true,
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 24),
            const Text(
              'Join FitFlow',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 30, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 4),
            const Text(
              'Create your account to get started.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white60),
            ),
            const SizedBox(height: 24),
            Center(
              child: GestureDetector(
                onTap: _pickPhoto,
                child: Stack(
                  children: [
                    Container(
                      width: 104,
                      height: 104,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: kCard,
                        border: Border.all(color: kBrand, width: 2),
                        image: _photo == null
                            ? null
                            : DecorationImage(
                                image: MemoryImage(_photo!),
                                fit: BoxFit.cover,
                              ),
                      ),
                      child: _photo == null
                          ? const Icon(
                              Icons.person_rounded,
                              size: 52,
                              color: Colors.white38,
                            )
                          : null,
                    ),
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: Container(
                        padding: const EdgeInsets.all(7),
                        decoration: BoxDecoration(
                          color: kBrand,
                          shape: BoxShape.circle,
                          border: Border.all(color: kBg, width: 2),
                        ),
                        child: const Icon(
                          Icons.photo_camera_rounded,
                          size: 18,
                          color: Colors.black,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Add a profile photo (optional)',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white54, fontSize: 12),
            ),
            const SizedBox(height: 24),
            TextFormField(
              controller: _nameCtrl,
              textCapitalization: TextCapitalization.words,
              decoration: authInputDecoration(
                'Full name',
                Icons.person_outline,
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Name is required' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _emailCtrl,
              keyboardType: TextInputType.emailAddress,
              decoration: authInputDecoration('Email', Icons.email_outlined),
              validator: (v) {
                final value = v?.trim() ?? '';
                if (value.isEmpty) return 'Email is required';
                if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(value)) {
                  return 'Enter a valid email';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _passCtrl,
              obscureText: _obscure,
              decoration: authInputDecoration(
                'Password',
                Icons.lock_outline,
                suffix: IconButton(
                  icon: Icon(
                    _obscure ? Icons.visibility_off : Icons.visibility,
                    color: Colors.white54,
                  ),
                  onPressed: () => setState(() => _obscure = !_obscure),
                ),
              ),
              validator: (v) {
                if (v == null || v.isEmpty) return 'Password is required';
                if (v.length < 6) return 'Use at least 6 characters';
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _confirmCtrl,
              obscureText: _obscure,
              decoration: authInputDecoration(
                'Confirm password',
                Icons.lock_outline,
              ),
              validator: (v) =>
                  v != _passCtrl.text ? 'Passwords do not match' : null,
            ),
            const SizedBox(height: 24),
            AuthButton(
              label: 'Register',
              loading: _loading,
              onPressed: _submit,
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  'Already have an account?',
                  style: TextStyle(color: Colors.white60),
                ),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Log in'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

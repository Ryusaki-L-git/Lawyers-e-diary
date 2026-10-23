import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../widgets/app_palette.dart';
import '../widgets/windows_desktop_ui.dart';

/// The desktop form that edits the signed-in advocate's LED profile.
///
/// The screen loads the existing Firestore user document, keeps the same
/// loading, failure and retry treatment, and writes the updated profile
/// back through the same user and LED directory records.
class WindowsEditProfileScreen extends StatefulWidget {
  const WindowsEditProfileScreen({super.key});
  @override
  State<WindowsEditProfileScreen> createState() =>
      _WindowsEditProfileScreenState();
}

class _WindowsEditProfileScreenState extends State<WindowsEditProfileScreen> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController(),
      _phone = TextEditingController(),
      _degrees = TextEditingController(),
      _address = TextEditingController(),
      _court = TextEditingController();
  static const _types = ['Junior', 'Senior', 'Corporate', 'Independent'];
  String _type = 'Junior';
  bool _loading = true, _saving = false;
  String? _loadError;
  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    for (final c in [_name, _phone, _degrees, _address, _court]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      if (mounted) {
        setState(() {
          _loading = false;
          _loadError = 'Your session is not available. Please sign in again.';
        });
      }
      return;
    }
    try {
      final snap = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();
      final data = snap.data() ?? <String, dynamic>{};
      if (!mounted) return;
      setState(() {
        _name.text = data['name'] as String? ?? '';
        _phone.text = data['phone'] as String? ?? '';
        _degrees.text = data['degrees'] as String? ?? '';
        _address.text =
            data['address'] as String? ??
            data['officeAddress'] as String? ??
            '';
        _court.text = data['courtAddress'] as String? ?? '';
        final loaded = data['advocateType'] as String?;
        if (_types.contains(loaded)) _type = loaded!;
        _loading = false;
        _loadError = null;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _loading = false;
          _loadError = 'Your profile could not be loaded. Check your connection and try again.';
        });
      }
    }
  }

  void _retry() {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    _load();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppPalette.canvas,
    body: SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(30, 25, 30, 30),
        child: SingleChildScrollView(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1000),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  WindowsPageHeader(
                    eyebrow: 'ACCOUNT IDENTITY',
                    title: 'Edit professional profile',
                    subtitle: 'These fields update your existing LED user profile and identity-directory entry.',
                    leading: IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.arrow_back_rounded),
                      tooltip: 'Back',
                    ),
                    actions: _saving
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.4,
                              color: AppPalette.accentGold,
                            ),
                          )
                        : FilledButton.icon(
                            onPressed: _save,
                            icon: const Icon(Icons.save_outlined),
                            label: const Text('Save changes'),
                            style: WindowsButtonStyles.primary(),
                          ),
                  ),
                  const SizedBox(height: 22),
                  if (_loading)
                    const WindowsLoadingPanel(label: 'Loading your profile')
                  else if (_loadError != null)
                    WindowsPanel(
                      child: WindowsMessageState(
                        icon: Icons.cloud_off_outlined,
                        title: 'Profile unavailable',
                        message: _loadError!,
                        isError: true,
                        action: OutlinedButton.icon(
                          onPressed: _retry,
                          icon: const Icon(Icons.refresh_rounded, size: 18),
                          label: const Text('Try again'),
                          style: WindowsButtonStyles.secondary(),
                        ),
                      ),
                    )
                  else
                    Form(
                      key: _form,
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final wide = constraints.maxWidth > 720;
                          final identity = Column(
                            children: [
                              _field(
                                'Full name *',
                                _name,
                                'Your professional name',
                              ),
                              _field(
                                'Phone number',
                                _phone,
                                'Contact phone',
                                isRequired: false,
                              ),
                              _field(
                                'Qualifications / degrees',
                                _degrees,
                                'Qualifications',
                                isRequired: false,
                              ),
                            ],
                          );
                          final office = Column(
                            children: [
                              _field(
                                'Office / chamber address',
                                _address,
                                'Office or chamber address',
                                isRequired: false,
                                maxLines: 3,
                              ),
                              _field(
                                'Court address',
                                _court,
                                'Court address',
                                isRequired: false,
                                maxLines: 3,
                              ),
                              _dropdown(),
                            ],
                          );
                          return wide
                              ? Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      child: _panel(
                                        'Personal & professional details',
                                        identity,
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: _panel(
                                        'Practice & location',
                                        office,
                                      ),
                                    ),
                                  ],
                                )
                              : Column(
                                  children: [
                                    _panel(
                                      'Personal & professional details',
                                      identity,
                                    ),
                                    const SizedBox(height: 14),
                                    _panel('Practice & location', office),
                                  ],
                                );
                        },
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
  Widget _panel(String title, Widget child) =>
      WindowsPanel(title: title, child: child);
  Widget _field(
    String label,
    TextEditingController controller,
    String hint, {
    bool isRequired = true,
    int maxLines = 1,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 13),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        WindowsFieldLabel(label),
        const SizedBox(height: 7),
        TextFormField(
          controller: controller,
          maxLines: maxLines,
          decoration: WindowsFieldDecoration(hint: hint).build(),
          validator: isRequired
              ? (v) => (v == null || v.trim().isEmpty)
                    ? 'This field is required'
                    : null
              : null,
        ),
      ],
    ),
  );
  Widget _dropdown() => Padding(
    padding: const EdgeInsets.only(bottom: 13),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const WindowsFieldLabel('Advocate type'),
        const SizedBox(height: 7),
        DropdownButtonFormField<String>(
          initialValue: _type,
          decoration: const WindowsFieldDecoration(hint: 'Select advocate type')
              .build(),
          items: _types
              .map((t) => DropdownMenuItem(value: t, child: Text(t)))
              .toList(),
          onChanged: (v) {
            if (v != null) setState(() => _type = v);
          },
        ),
      ],
    ),
  );
  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Please sign in again.')));
      return;
    }
    setState(() => _saving = true);
    try {
      final db = FirebaseFirestore.instance;
      final ref = db.collection('users').doc(uid);

      final profileData = <String, dynamic>{
        'name': _name.text.trim(),
        'phone': _phone.text.trim(),
        'degrees': _degrees.text.trim(),
        'address': _address.text.trim(),
        'officeAddress': _address.text.trim(),
        'courtAddress': _court.text.trim(),
        'advocateType': _type,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      await db.runTransaction<void>((transaction) async {
        final snap = await transaction.get(ref);
        final existing = snap.data() ?? <String, dynamic>{};
        final ledId = (existing['ledId'] as String?)?.trim();

        transaction.set(ref, profileData, SetOptions(merge: true));

        if (ledId != null && ledId.isNotEmpty) {
          final directoryRef = db.collection('led_id_directory').doc(ledId);
          final directorySnapshot = await transaction.get(directoryRef);

          if (directorySnapshot.exists) {
            final ownerUid = directorySnapshot.data()?['uid'] as String?;
            if (ownerUid == null || ownerUid != uid) {
              throw StateError(
                'The LED directory entry for this ID is owned by another account.',
              );
            }
          }

          transaction.set(directoryRef, <String, dynamic>{
            'uid': uid,
            'ledId': ledId,
            'name': _name.text.trim(),
            'advocateType': _type,
            'profileCompleted': existing['profileCompleted'] == true,
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
        }
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile updated successfully.')),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Could not update profile: $e')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

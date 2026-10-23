import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'windows_edit_profile_screen.dart';
import 'windows_desktop_shell.dart';
import '../widgets/app_palette.dart';
import '../widgets/windows_desktop_ui.dart';

/// The desktop profile surface.
///
/// Presents the signed-in advocate's own Firestore user document using the
/// shared Windows page header, panels and message states.
class WindowsProfileScreen extends StatefulWidget {
  const WindowsProfileScreen({super.key});

  @override
  State<WindowsProfileScreen> createState() => _WindowsProfileScreenState();
}

class _WindowsProfileScreenState extends State<WindowsProfileScreen> {
  /// Incremented on every retry so the snapshot stream is subscribed again.
  int _attempt = 0;

  Stream<DocumentSnapshot<Map<String, dynamic>>> _profileStream(String uid) {
    return FirebaseFirestore.instance.collection('users').doc(uid).snapshots();
  }

  void _retry() {
    setState(() => _attempt++);
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return const Scaffold(
        backgroundColor: AppPalette.canvas,
        body: SafeArea(
          child: Center(
            child: WindowsMessageState(
              icon: Icons.lock_outline_rounded,
              title: 'Sign in to view your profile',
              message:
                  'Your professional identity is shown from the signed-in LED '
                  'account and its Firestore user document.',
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppPalette.canvas,
      body: SafeArea(
        child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          key: ValueKey<int>(_attempt),
          stream: _profileStream(user.uid),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return WindowsMessageState(
                icon: Icons.cloud_off_outlined,
                title: 'Profile unavailable',
                message: 'Could not load profile: ${snapshot.error}',
                isError: true,
                action: OutlinedButton.icon(
                  onPressed: _retry,
                  icon: const Icon(Icons.refresh_rounded, size: 18),
                  label: const Text('Try again'),
                  style: WindowsButtonStyles.secondary(),
                ),
              );
            }

            if (snapshot.connectionState == ConnectionState.waiting &&
                snapshot.data == null) {
              return const WindowsLoadingPanel(label: 'Loading your profile');
            }

            final data = snapshot.data?.data() ?? <String, dynamic>{};

            String fieldValue(String key, String fallback) {
              final rawValue = data[key];

              if (rawValue is String && rawValue.trim().isNotEmpty) {
                return rawValue.trim();
              }

              return fallback;
            }

            final name = fieldValue('name', user.displayName ?? 'Advocate');

            return SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(30, 25, 30, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const WindowsPageHeader(
                    eyebrow: 'YOUR PROFESSIONAL IDENTITY',
                    title: 'Legal profile',
                    subtitle:
                        'Keep your professional and office details up to date.',
                  ),
                  const SizedBox(height: 24),
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: AppPalette.primaryGreen,
                      borderRadius: BorderRadius.circular(17),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 76,
                          height: 76,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: const Color(0x22FFFFFF),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: const Color(0x66CCA046)),
                          ),
                          child: Text(
                            name.trim().isEmpty
                                ? 'A'
                                : name.trim().substring(0, 1).toUpperCase(),
                            style: TextStyle(
                              color: AppPalette.accentGold,
                              fontFamily: AppTypography.heading,
                              fontSize: 31,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        const SizedBox(width: 18),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                name,
                                style: TextStyle(
                                  color: AppPalette.onForestText,
                                  fontFamily: AppTypography.heading,
                                  fontSize: 23,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                fieldValue(
                                  'advocateType',
                                  'Legal professional',
                                ),
                                style: const TextStyle(
                                  color: AppPalette.onForestMuted,
                                  fontSize: 12,
                                ),
                              ),
                              const SizedBox(height: 7),
                              Text(
                                user.email ?? 'No email available',
                                style: const TextStyle(
                                  color: AppPalette.onForestFaint,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                        FilledButton.icon(
                          onPressed: () => Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => const WindowsDesktopShell(
                                activeRoute: '/profile',
                                child: WindowsEditProfileScreen(),
                              ),
                            ),
                          ),
                          icon: const Icon(Icons.edit_outlined, size: 17),
                          label: const Text('Edit profile'),
                          style: WindowsButtonStyles.onForest(filled: true),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final wide = constraints.maxWidth > 850;

                      final personal = _section('Personal details', [
                        _row('Full name', name),
                        _row(
                          'Email address',
                          fieldValue('email', user.email ?? 'Not added'),
                        ),
                        _row('Phone number', fieldValue('phone', 'Not added')),
                        _row('LED ID', fieldValue('ledId', 'Not assigned')),
                        _row(
                          'Advocate category',
                          fieldValue('advocateType', 'Not specified'),
                        ),
                      ]);

                      final office = _section('Practice & office', [
                        _row(
                          'Qualifications',
                          fieldValue('degrees', 'Not added'),
                        ),
                        _row(
                          'Office address',
                          fieldValue(
                            'address',
                            fieldValue('officeAddress', 'Not added'),
                          ),
                        ),
                        _row(
                          'Court address',
                          fieldValue('courtAddress', 'Not added'),
                        ),
                      ]);

                      if (!wide) {
                        return Column(
                          children: [
                            personal,
                            const SizedBox(height: 15),
                            office,
                          ],
                        );
                      }

                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: personal),
                          const SizedBox(width: 16),
                          Expanded(child: office),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 16),
                  WindowsPanel(
                    padding: const EdgeInsets.all(16),
                    child: const Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.verified_user_outlined,
                          color: AppPalette.accentGold,
                          size: 21,
                        ),
                        SizedBox(width: 11),
                        Expanded(
                          child: Text(
                            'Your profile is shown from the signed-in LED account and its Firestore user document. Only edit details that are accurate and current.',
                            style: TextStyle(
                              color: AppPalette.textMuted,
                              fontSize: 11,
                              height: 1.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _section(String title, List<Widget> children) {
    return WindowsPanel(
      title: title,
      child: Column(children: children),
    );
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              label,
              style: const TextStyle(color: AppPalette.textMuted, fontSize: 11),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: AppPalette.textPrimary,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

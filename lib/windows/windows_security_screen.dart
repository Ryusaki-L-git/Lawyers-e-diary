import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../widgets/app_palette.dart';
import '../widgets/windows_desktop_ui.dart';

/// Desktop account-protection surface.
///
/// The only network call on this screen is the Firebase Auth password reset
/// request; everything else is read from the current session.
class WindowsSecurityScreen extends StatefulWidget {
  const WindowsSecurityScreen({super.key});
  @override
  State<WindowsSecurityScreen> createState() => _WindowsSecurityScreenState();
}

class _WindowsSecurityScreenState extends State<WindowsSecurityScreen> {
  bool _sending = false;
  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    return Scaffold(
      backgroundColor: AppPalette.canvas,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(30, 25, 30, 30),
          child: SingleChildScrollView(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 900),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const WindowsPageHeader(
                      eyebrow: 'ACCOUNT PROTECTION',
                      title: 'Security & access',
                      subtitle: 'Manage account access and password recovery.',
                    ),
                    const SizedBox(height: 22),
                    WindowsPanel(
                      child: Row(
                        children: [
                          Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: AppPalette.statusTile,
                              borderRadius: BorderRadius.circular(13),
                            ),
                            child: const Icon(
                              Icons.verified_user_outlined,
                              color: AppPalette.primaryGreen,
                              size: 25,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Current sign-in',
                                  style: TextStyle(
                                    color: AppPalette.textPrimary,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(height: 5),
                                Text(
                                  user?.email ?? 'No signed-in email available',
                                  style: const TextStyle(
                                    color: AppPalette.textMuted,
                                    fontSize: 12,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                const Text(
                                  'Authentication is handled by the existing Firebase Auth session.',
                                  style: TextStyle(
                                    color: AppPalette.textMuted,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    WindowsPanel(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Password recovery',
                            style: TextStyle(
                              color: AppPalette.textPrimary,
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'Send a reset email to the address associated with your current Firebase account.',
                            style: TextStyle(
                              color: AppPalette.textMuted,
                              fontSize: 12,
                              height: 1.5,
                            ),
                          ),
                          const SizedBox(height: 14),
                          FilledButton.icon(
                            onPressed: _sending || user?.email == null
                                ? null
                                : _sendReset,
                            icon: _sending
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Icon(Icons.mark_email_unread_outlined),
                            label: Text(
                              _sending
                                  ? 'Sending…'
                                  : 'Send password reset email',
                            ),
                            style: WindowsButtonStyles.primary(),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(17),
                      decoration: BoxDecoration(
                        color: AppPalette.noteFill,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppPalette.noteBorder),
                      ),
                      child: const Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.shield_outlined,
                            color: AppPalette.statusWarning,
                          ),
                          SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'This page does not claim that every case or attachment is backed up. Review the Cloud & storage page for the actual metadata currently available; a full synchronization job is not implemented by the sync timestamp marker alone.',
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
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _sendReset() async {
    final email = FirebaseAuth.instance.currentUser?.email;
    if (email == null || email.isEmpty) return;
    setState(() => _sending = true);
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'If the account can receive password-reset email, instructions will be sent.',
            ),
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Could not send reset email right now. Please try again.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }
}

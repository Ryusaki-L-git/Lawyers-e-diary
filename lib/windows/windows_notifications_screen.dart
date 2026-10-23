import 'package:flutter/material.dart';

import '../widgets/app_palette.dart';
import '../widgets/windows_desktop_ui.dart';

/// Windows notification surface.
///
/// LED does not yet have a persistent notification source, so this screen
/// deliberately shows an honest empty state rather than sample alerts. It
/// points the user at the surfaces that do surface live activity.
class WindowsNotificationsScreen extends StatelessWidget {
  const WindowsNotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppPalette.canvas,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(30, 25, 30, 30),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const WindowsPageHeader(
                eyebrow: 'WORKSPACE ACTIVITY',
                title: 'Notifications',
                subtitle:
                    'A central place for important case and practice updates.',
              ),
              const SizedBox(height: 24),
              Expanded(
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 560),
                    child: WindowsPanel(
                      padding: const EdgeInsets.all(30),
                      child: const WindowsMessageState(
                        icon: Icons.notifications_none_rounded,
                        title: 'No notification feed is connected yet',
                        message:
                            'This screen intentionally shows no sample alerts. '
                            'LED still needs a persistent notification source '
                            'before real case, team and JURIS events can '
                            'appear here.',
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Center(
                child: FilledButton.icon(
                  onPressed: () =>
                      Navigator.of(context).pushReplacementNamed('/reminders'),
                  icon: const Icon(Icons.event_note_outlined),
                  label: const Text('Open reminders'),
                  style: WindowsButtonStyles.primary(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

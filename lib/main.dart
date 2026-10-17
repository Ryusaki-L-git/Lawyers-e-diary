import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'login_screen.dart';
import 'screens/calendar_list_screen.dart';
import 'screens/cases/add_case_screen.dart';
import 'screens/cases/all_cases_screen.dart';
import 'screens/cases/case_management_screen.dart';
import 'screens/cases/completed_cases_screen.dart';
import 'screens/cases/deleted_cases_screen.dart';
import 'screens/cases/search_cases_screen.dart';
import 'screens/cases/transfer_case_screen.dart';
import 'screens/cause_list_screen.dart';
import 'screens/full_calendar_screen.dart';
import 'screens/home_screen.dart';
import 'screens/module_landing_screen.dart';
import 'screens/juris/juris_chat_screen.dart';
import 'screens/notification_screen.dart';
import 'screens/profile/profile_screen.dart';
import 'screens/fees/fee_list_screen.dart';
import 'screens/cases/starred_cases_screen.dart';
import 'screens/reminders/reminders_list_screen.dart';
import 'screens/settings/app_settings_screen.dart';
import 'screens/settings/cloud_storage_screen.dart';
import 'screens/settings/upgrade_prompt_screen.dart';
import 'screens/clients/client_list_screen.dart';
import 'screens/support/help_support_screen.dart';
import 'screens/team/team_entry_screen.dart';
import 'signup_screen.dart';
import 'splash_screen.dart';
import 'welcome_screen.dart';
import 'widgets/app_palette.dart';
import 'windows/windows_desktop_shell.dart';
import 'windows/windows_home_screen.dart';
import 'windows/windows_cases_screen.dart';
import 'windows/windows_calendar_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  Widget _platformRoute(String route, Widget screen) {
    if (defaultTargetPlatform != TargetPlatform.windows) return screen;
    return WindowsDesktopShell(activeRoute: route, child: screen);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Lawyers E-Diary',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      initialRoute: '/',
      routes: {
        '/': (context) => const SplashScreen(),
        '/login': (context) => const LoginScreen(),
        '/signup': (context) => const SignupScreen(),
        '/welcome': (context) => const WelcomeScreen(),
        '/home': (context) => defaultTargetPlatform == TargetPlatform.windows
            ? const WindowsDesktopShell(activeRoute: '/home', child: WindowsHomeScreen())
            : const HomeScreen(),
        '/cases': (context) => defaultTargetPlatform == TargetPlatform.windows
            ? const WindowsDesktopShell(activeRoute: '/cases', child: WindowsCasesScreen())
            : const AllCasesScreen(),
        '/add_case': (context) => _platformRoute('/add_case', const AddCaseScreen()),
        '/search_cases': (context) => _platformRoute('/search_cases', const SearchCasesScreen()),
        '/case_management': (context) => _platformRoute('/case_management', const CaseManagementScreen()),
        '/completed_cases': (context) => _platformRoute('/completed_cases', const CompletedCasesScreen()),
        '/deleted_cases': (context) => _platformRoute('/deleted_cases', const DeletedCasesScreen()),
        '/transfer_case': (context) => _platformRoute('/transfer_case', const TransferCaseScreen()),
        '/clients': (context) => _platformRoute('/clients', const ClientListScreen()),
        '/support': (context) => _platformRoute('/support', const HelpSupportScreen()),
        '/team': (context) => _platformRoute('/team', const TeamEntryScreen()),
        '/calendar': (context) => defaultTargetPlatform == TargetPlatform.windows
            ? const WindowsDesktopShell(activeRoute: '/calendar', child: WindowsCalendarScreen())
            : const CalendarListScreen(),
        '/calendar_list': (context) => defaultTargetPlatform == TargetPlatform.windows
            ? const WindowsDesktopShell(activeRoute: '/calendar', child: WindowsCalendarScreen())
            : const CalendarListScreen(),
        '/cause_list': (context) => _platformRoute('/cause_list', const CauseListScreen()),
        '/full_calendar': (context) => _platformRoute('/full_calendar', const FullCalendarScreen()),
        '/juris': (context) => _platformRoute('/juris', const JurisChatScreen()),
        '/profile': (context) => _platformRoute('/profile', const ProfileScreen()),
        '/fee': (context) => _platformRoute('/fee', const FeeListScreen()),
        '/todo': (context) => _platformRoute('/todo', const ModuleLandingScreen(title: 'To-Do List', icon: Icons.checklist_rounded)),
        '/reminders': (context) => _platformRoute('/reminders', const RemindersListScreen()),
        '/starred': (context) => _platformRoute('/starred', const StarredCasesScreen()),
        '/settings': (context) => _platformRoute('/settings', const AppSettingsScreen()),
        '/cloud_storage': (context) => _platformRoute('/cloud_storage', const CloudStorageScreen()),
        '/upgrade': (context) => _platformRoute('/upgrade', const UpgradePromptScreen()),
        '/notifications': (context) => _platformRoute('/notifications', const NotificationScreen()),
      },
    );
  }
}

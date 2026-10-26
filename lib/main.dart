import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'firebase_options.dart';
import 'login_screen.dart';
import 'models/fee_model.dart';
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
import 'screens/services/services_catalogue_screen.dart';
import 'screens/tokens/token_balance_screen.dart';
import 'screens/tokens/usage_history_screen.dart';
import 'screens/notification_screen.dart';
import 'screens/profile/profile_screen.dart';
import 'screens/profile/account_security_screen.dart';
import 'screens/fees/fee_list_screen.dart';
import 'screens/fees/record_payment_screen.dart';
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
import 'templates/animations/screen_transitions.dart';
import 'widgets/app_palette.dart';
import 'widgets/windows_desktop_ui.dart';
import 'windows/windows_desktop_shell.dart';
import 'windows/windows_home_screen.dart';
import 'windows/windows_cases_screen.dart';
import 'windows/windows_calendar_screen.dart';
import 'windows/windows_clients_screen.dart';
import 'windows/windows_reminders_screen.dart';
import 'windows/windows_fees_screen.dart';
import 'windows/windows_record_payment_screen.dart';
import 'windows/windows_juris_screen.dart';
import 'windows/windows_settings_screen.dart';
import 'windows/windows_team_screen.dart';
import 'windows/windows_profile_screen.dart';
import 'windows/windows_cause_list_screen.dart';
import 'windows/windows_add_case_screen.dart';
import 'windows/windows_search_cases_screen.dart';
import 'windows/windows_notifications_screen.dart';
import 'windows/windows_todo_screen.dart';
import 'windows/windows_case_management_screen.dart';
import 'windows/windows_deleted_cases_screen.dart';
import 'windows/windows_support_screen.dart';
import 'windows/windows_transfer_case_screen.dart';
import 'windows/windows_cloud_storage_screen.dart';
import 'windows/windows_upgrade_screen.dart';
import 'windows/windows_app_settings_screen.dart';
import 'windows/windows_security_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  /// Wraps [screen] in the persistent Windows desktop shell.
  ///
  /// Used for routes that have no dedicated Windows implementation and are
  /// therefore presented with the shared mobile content inside the desktop
  /// chrome.
  Widget _platformRoute(String route, Widget screen) {
    if (defaultTargetPlatform != TargetPlatform.windows) return screen;
    return WindowsDesktopShell(activeRoute: route, child: screen);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Lawyers E-Diary',
      debugShowCheckedModeBanner: false,
      // Shared restrained transitions for Android and Windows; reduced motion is respected.
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: <TargetPlatform, PageTransitionsBuilder>{
          TargetPlatform.android: TemplatePlatformPageTransitionsBuilder(),
          TargetPlatform.windows: TemplatePlatformPageTransitionsBuilder(),
        },
      ),
      theme: defaultTargetPlatform == TargetPlatform.windows
          ? AppTheme.windows
          : AppTheme.light,
      // The desktop workspace supports click-and-drag scrolling with a
      // mouse. The default material behaviour only drags with a touch
      // device, so the behaviour is swapped only for the Windows build and
      // the Android build keeps its existing scroll behaviour untouched.
      scrollBehavior: defaultTargetPlatform == TargetPlatform.windows
          ? const WindowsDesktopScrollBehavior()
          : null,
      initialRoute: '/',
      routes: {
        '/': (context) => const SplashScreen(),
        '/login': (context) => const LoginScreen(),
        '/signup': (context) => const SignupScreen(),
        '/welcome': (context) => const WelcomeScreen(),
        '/home': (context) => defaultTargetPlatform == TargetPlatform.windows
            ? const WindowsDesktopShell(
                activeRoute: '/home',
                child: WindowsHomeScreen(),
              )
            : const HomeScreen(),
        '/cases': (context) => defaultTargetPlatform == TargetPlatform.windows
            ? const WindowsDesktopShell(
                activeRoute: '/cases',
                child: WindowsCasesScreen(),
              )
            : const AllCasesScreen(),
        '/add_case': (context) =>
            defaultTargetPlatform == TargetPlatform.windows
            ? const WindowsDesktopShell(
                activeRoute: '/cases',
                child: WindowsAddCaseScreen(),
              )
            : const AddCaseScreen(),
        '/search_cases': (context) {
          if (defaultTargetPlatform != TargetPlatform.windows) {
            return const SearchCasesScreen();
          }
          final args = ModalRoute.of(context)?.settings.arguments;
          return WindowsDesktopShell(
            activeRoute: '/search_cases',
            child: WindowsSearchCasesScreen(
              initialQuery: args is String ? args : null,
            ),
          );
        },
        '/case_management': (context) =>
            defaultTargetPlatform == TargetPlatform.windows
            ? const WindowsDesktopShell(
                activeRoute: '/case_management',
                child: WindowsCaseManagementScreen(),
              )
            : const CaseManagementScreen(),
        '/completed_cases': (context) =>
            defaultTargetPlatform == TargetPlatform.windows
            ? const WindowsDesktopShell(
                activeRoute: '/completed_cases',
                child: WindowsCasesScreen(initialStatus: 'completed'),
              )
            : const CompletedCasesScreen(),
        '/deleted_cases': (context) =>
            defaultTargetPlatform == TargetPlatform.windows
            ? const WindowsDesktopShell(
                activeRoute: '/deleted_cases',
                child: WindowsDeletedCasesScreen(),
              )
            : const DeletedCasesScreen(),
        '/transfer_case': (context) =>
            defaultTargetPlatform == TargetPlatform.windows
            ? WindowsDesktopShell(
                activeRoute: '/transfer_case',
                child: const WindowsTransferCaseScreen(),
              )
            : const TransferCaseScreen(),
        '/clients': (context) => defaultTargetPlatform == TargetPlatform.windows
            ? const WindowsDesktopShell(
                activeRoute: '/clients',
                child: WindowsClientsScreen(),
              )
            : const ClientListScreen(),
        '/support': (context) => defaultTargetPlatform == TargetPlatform.windows
            ? const WindowsDesktopShell(
                activeRoute: '/support',
                child: WindowsSupportScreen(),
              )
            : const HelpSupportScreen(),
        '/team': (context) => defaultTargetPlatform == TargetPlatform.windows
            ? const WindowsDesktopShell(
                activeRoute: '/team',
                child: WindowsTeamScreen(),
              )
            : const TeamEntryScreen(),
        '/calendar': (context) =>
            defaultTargetPlatform == TargetPlatform.windows
            ? const WindowsDesktopShell(
                activeRoute: '/calendar',
                child: WindowsCalendarScreen(),
              )
            : const CalendarListScreen(),
        '/calendar_list': (context) =>
            defaultTargetPlatform == TargetPlatform.windows
            ? const WindowsDesktopShell(
                activeRoute: '/calendar',
                child: WindowsCalendarScreen(),
              )
            : const CalendarListScreen(),
        '/cause_list': (context) =>
            defaultTargetPlatform == TargetPlatform.windows
            ? const WindowsDesktopShell(
                activeRoute: '/cause_list',
                child: WindowsCauseListScreen(),
              )
            : const CauseListScreen(),
        '/full_calendar': (context) =>
            defaultTargetPlatform == TargetPlatform.windows
            ? const WindowsDesktopShell(
                activeRoute: '/calendar',
                child: WindowsCalendarScreen(),
              )
            : const FullCalendarScreen(),
        '/juris': (context) {
          if (defaultTargetPlatform != TargetPlatform.windows) {
            return const JurisChatScreen();
          }
          final args = ModalRoute.of(context)?.settings.arguments;
          final contextData = args is Map ? args : const <String, dynamic>{};
          return WindowsDesktopShell(
            activeRoute: '/juris',
            child: WindowsJurisScreen(
              caseId: contextData['caseId'] as String?,
              caseTitle: contextData['caseTitle'] as String?,
            ),
          );
        },
        '/services': (context) =>
            _platformRoute('/services', const ServicesCatalogueScreen()),
        '/token_balance': (context) =>
            _platformRoute('/token_balance', const TokenBalanceScreen()),
        '/usage_history': (context) =>
            _platformRoute('/usage_history', const UsageHistoryScreen()),
        '/profile': (context) => defaultTargetPlatform == TargetPlatform.windows
            ? const WindowsDesktopShell(
                activeRoute: '/profile',
                child: WindowsProfileScreen(),
              )
            : const ProfileScreen(),
        '/fee': (context) => defaultTargetPlatform == TargetPlatform.windows
            ? const WindowsDesktopShell(
                activeRoute: '/fee',
                child: WindowsFeesScreen(),
              )
            : const FeeListScreen(),
        '/record_payment': (context) {
          final args = ModalRoute.of(context)?.settings.arguments;
          final fee = args is FeeModel ? args : null;
          if (fee == null) {
            return defaultTargetPlatform == TargetPlatform.windows
                ? const WindowsDesktopShell(
                    activeRoute: '/fee',
                    child: WindowsFeesScreen(),
                  )
                : const FeeListScreen();
          }
          return defaultTargetPlatform == TargetPlatform.windows
              ? WindowsDesktopShell(
                  activeRoute: '/fee',
                  child: WindowsRecordPaymentScreen(fee: fee),
                )
              : RecordPaymentScreen(fee: fee);
        },
        '/todo': (context) => defaultTargetPlatform == TargetPlatform.windows
            ? const WindowsDesktopShell(
                activeRoute: '/todo',
                child: WindowsTodoScreen(),
              )
            : const ModuleLandingScreen(
                title: 'To-Do List',
                icon: Icons.checklist_rounded,
              ),
        '/reminders': (context) =>
            defaultTargetPlatform == TargetPlatform.windows
            ? const WindowsDesktopShell(
                activeRoute: '/reminders',
                child: WindowsRemindersScreen(),
              )
            : const RemindersListScreen(),
        '/starred': (context) => defaultTargetPlatform == TargetPlatform.windows
            ? const WindowsDesktopShell(
                activeRoute: '/starred',
                child: WindowsCasesScreen(initialStatus: 'starred'),
              )
            : const StarredCasesScreen(),
        '/settings': (context) =>
            defaultTargetPlatform == TargetPlatform.windows
            ? const WindowsDesktopShell(
                activeRoute: '/settings',
                child: WindowsSettingsScreen(),
              )
            : const AppSettingsScreen(),
        '/security': (context) =>
            defaultTargetPlatform == TargetPlatform.windows
            ? const WindowsDesktopShell(
                activeRoute: '/settings',
                child: WindowsSecurityScreen(),
              )
            : const AccountSecurityScreen(),
        '/settings_native': (context) =>
            defaultTargetPlatform == TargetPlatform.windows
            ? const WindowsDesktopShell(
                activeRoute: '/settings',
                child: WindowsAppSettingsScreen(),
              )
            : const AppSettingsScreen(),
        '/cloud_storage': (context) =>
            defaultTargetPlatform == TargetPlatform.windows
            ? const WindowsDesktopShell(
                activeRoute: '/settings',
                child: WindowsCloudStorageScreen(),
              )
            : const CloudStorageScreen(),
        '/upgrade': (context) => defaultTargetPlatform == TargetPlatform.windows
            ? const WindowsDesktopShell(
                activeRoute: '/settings',
                child: WindowsUpgradeScreen(),
              )
            : const UpgradePromptScreen(),
        '/notifications': (context) =>
            defaultTargetPlatform == TargetPlatform.windows
            ? const WindowsDesktopShell(
                activeRoute: '/notifications',
                child: WindowsNotificationsScreen(),
              )
            : const NotificationScreen(),
      },
    );
  }
}

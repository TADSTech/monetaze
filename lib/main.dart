import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:hive_flutter/adapters.dart';
import 'package:monetaze/core/adapters/theme_mode_adapter.dart';
import 'package:monetaze/core/base/main_wrapper_notifier.dart';
import 'package:monetaze/core/models/goal_model.dart';
import 'package:monetaze/core/models/quote_model.dart';
import 'package:monetaze/core/models/task_model.dart';
import 'package:monetaze/core/models/user_model.dart';
import 'package:monetaze/core/services/hive_services.dart';
import 'package:monetaze/core/services/notification_service.dart';
import 'package:monetaze/core/services/quote_service.dart';
import 'package:monetaze/theme/theme_provider.dart';
import 'package:monetaze/views/goals/goals_view.dart';
import 'package:monetaze/views/home/home_view.dart';
import 'package:monetaze/views/insights/insights_view.dart';
import 'package:monetaze/views/settings/settings_view.dart';
import 'package:monetaze/views/tasks/tasks_view.dart';
import 'package:monetaze/views/user/user_view.dart';
import 'package:monetaze/widgets/nav/bottom_nav_bar.dart';
import 'package:provider/provider.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;

/// Main entry point of the application.
Future<void> main() async {
  // Ensure Flutter widgets are initialized before any Flutter-specific operations.
  WidgetsFlutterBinding.ensureInitialized();
  // Initialize Hive local storage.
  await Hive.initFlutter();

  // Register Hive adapters for custom data models.
  Hive.registerAdapter(GoalAdapter());
  Hive.registerAdapter(SavingsIntervalAdapter());
  Hive.registerAdapter(TaskAdapter());
  Hive.registerAdapter(UserAdapter());
  Hive.registerAdapter(MotivationalQuoteAdapter());
  Hive.registerAdapter(ThemeModeAdapter());

  // Initialize all Hive boxes.
  await HiveService.init();

  // Initialize services and providers.
  final quotesBox = Hive.box<MotivationalQuote>('quotes');
  final quoteService = QuoteService(quotesBox);
  final user = await HiveService.getCurrentUser();
  final themeProvider = ThemeProvider(user: user);

  // Initialize notification service and timezones.
  await NotificationService().init();
  tz.initializeTimeZones();

  runApp(
    /// MultiProvider for managing the state of various parts of the application.
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: themeProvider),
        ChangeNotifierProvider(create: (context) => MainWrapperNotifier()),
        Provider<QuoteService>.value(value: quoteService),
      ],
      child: const MonetazeApp(),
    ),
  );
}

/// The root widget of the Monetaze application.
class MonetazeApp extends StatelessWidget {
  const MonetazeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Monetaze',
      debugShowCheckedModeBanner: false,
      // Set theme mode based on user preference from ThemeProvider.
      themeMode: Provider.of<ThemeProvider>(context).themeMode,
      // Apply light theme.
      theme: Provider.of<ThemeProvider>(context).getLightTheme(),
      // Apply dark theme.
      darkTheme: Provider.of<ThemeProvider>(context).getDarkTheme(),
      home: Builder(
        builder: (context) {
          return const MainWrapper();
        },
      ),
    );
  }
}

/// A wrapper widget that manages the main navigation and displays different views.
class MainWrapper extends StatefulWidget {
  const MainWrapper({super.key});

  @override
  State<MainWrapper> createState() => _MainWrapperState();
}

class _MainWrapperState extends State<MainWrapper> {
  // List of pages to be displayed in the main wrapper.
  late final List<Widget> _pages;

  @override
  void initState() {
    super.initState();
    // Retrieve QuoteService from the nearest Provider.
    final quoteService = Provider.of<QuoteService>(context, listen: false);

    _pages = [
      HomeView(quoteService: quoteService),
      const GoalsView(),
      const TasksView(),
      const InsightsView(),
      const UserView(),
    ];
  }

  @override
  Widget build(BuildContext context) {
    // Listen to MainWrapperNotifier for changes in the current index.
    final mainWrapperNotifier = Provider.of<MainWrapperNotifier>(context);

    // Clamp the current index to ensure it's within the valid range of _pages.
    final int selectedIndex = mainWrapperNotifier.currentIndex.clamp(
      0,
      _pages.length - 1,
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Monetaze'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              // Store the current index before navigating to settings,
              // so it can be restored upon returning.
              final int currentIndexBeforeNav =
                  mainWrapperNotifier.currentIndex;

              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const SettingsView(),
                  fullscreenDialog: true,
                ),
              ).then((_) {
                // Restore the previous index when returning from settings.
                mainWrapperNotifier.currentIndex = currentIndexBeforeNav;
              });
            },
          ),
        ],
      ),
      body: IndexedStack(index: selectedIndex, children: _pages),
      bottomNavigationBar: CustomBottomNavBar(
        currentIndex: selectedIndex,
        onTap: (index) {
          mainWrapperNotifier.currentIndex = index;
        },
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flex_color_scheme/flex_color_scheme.dart';
import 'package:hive/hive.dart';
import 'package:hive_flutter/adapters.dart';
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
import 'package:monetaze/views/tasks/task_service.dart';
import 'package:monetaze/views/tasks/tasks_view.dart';
import 'package:monetaze/views/user/user_view.dart';
import 'package:monetaze/widgets/nav/bottom_nav_bar.dart';
import 'package:provider/provider.dart';
import 'package:monetaze/core/models/goal_model.dart';
import 'package:monetaze/core/models/task_model.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();

  Hive.registerAdapter(GoalAdapter());
  Hive.registerAdapter(SavingsIntervalAdapter());
  Hive.registerAdapter(TaskAdapter());
  Hive.registerAdapter(UserAdapter());
  Hive.registerAdapter(MotivationalQuoteAdapter());

  await Future.wait([
    Hive.openBox<Goal>('goals'),
    Hive.openBox<Task>('tasks'),
    Hive.openBox<User>('user'),
    Hive.openBox<MotivationalQuote>('quotes'),
  ]);

  final quotesBox = await Hive.openBox<MotivationalQuote>('quotes');
  final quoteService = QuoteService(quotesBox);

  await NotificationService().init();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (context) => ThemeProvider()),
        ChangeNotifierProvider(create: (context) => MainWrapperNotifier()),
        Provider<QuoteService>.value(value: quoteService),
      ],
      child: const MonetazeApp(),
    ),
  );
}

class MonetazeApp extends StatelessWidget {
  const MonetazeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Monetaze',
      debugShowCheckedModeBanner: false,
      themeMode: Provider.of<ThemeProvider>(context).themeMode,
      theme: Provider.of<ThemeProvider>(context).getLightTheme(),
      darkTheme: Provider.of<ThemeProvider>(context).getDarkTheme(),
      // FIX: Wrap MainWrapper with a Builder to get a context that has access to the Providers
      home: Builder(
        builder: (context) {
          return const MainWrapper();
        },
      ),
    );
  }
}

class MainWrapper extends StatefulWidget {
  const MainWrapper({super.key});

  @override
  State<MainWrapper> createState() => _MainWrapperState();
}

class _MainWrapperState extends State<MainWrapper> {
  int _selectedIndex = 0;
  late final List<Widget> _pages;

  @override
  void initState() {
    super.initState();
    // Now context here will have access to QuoteService
    final quoteService = Provider.of<QuoteService>(context, listen: false);

    _pages = [
      HomeView(quoteService: quoteService),
      const GoalsView(),
      const TasksView(),
      const InsightsView(),
      const UserView(),
    ];
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Monetaze'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed:
                () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const SettingsView(),
                    fullscreenDialog: true,
                  ),
                ),
          ),
        ],
      ),
      body: _pages[_selectedIndex],
      bottomNavigationBar: CustomBottomNavBar(
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
      ),
    );
  }
}

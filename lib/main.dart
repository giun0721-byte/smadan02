import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

// ★ 日本語ローカライズ用（カレンダーなどを日本語にする）
import 'package:flutter_localizations/flutter_localizations.dart';

import 'home_page.dart';
import 'news_page.dart';
import 'people_page.dart';
import 'settings_page.dart';
import 'app_state.dart';

Future<void> main() async {
  // ★ SharedPreferences を含む非同期初期化のため必須
  WidgetsFlutterBinding.ensureInitialized();

  // ★ 起動時に保存済みの選択状態を復元してから Provider に渡す
  final assets = SelectedAssets();
  await assets.loadFromPrefs();

  runApp(
    ChangeNotifierProvider<SelectedAssets>.value(
      value: assets,
      child: const SmadanApp(),
    ),
  );
}

class SmadanApp extends StatelessWidget {
  const SmadanApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'スマダン',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.brown),
        useMaterial3: true,
      ),

      // ★ ここからローカライズ設定（カレンダーを含め日本語表示に必要）
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('ja', 'JP'), // 日本語
        Locale('en', 'US'), //（必要なら）英語も
      ],
      locale: const Locale('ja', 'JP'),
      // ★ ここまで

      home: const MainScreen(),
    );
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;

  final List<Widget> _pages = const [
    HomePage(),
    NewsPage(),
    PeoplePage(),
    SettingsPage(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _pages[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'HOME'),
          BottomNavigationBarItem(icon: Icon(Icons.web), label: 'NEWS'),
          BottomNavigationBarItem(icon: Icon(Icons.people), label: '個人'),
          BottomNavigationBarItem(icon: Icon(Icons.settings), label: '設定'),
        ],
        onTap: (index) => setState(() => _currentIndex = index),
      ),
    );
  }
}

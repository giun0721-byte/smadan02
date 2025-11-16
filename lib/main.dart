import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'home_page.dart';
import 'news_page.dart';
import 'people_page.dart';
import 'settings_page.dart';
import 'app_state.dart';

void main() {
  runApp(
    ChangeNotifierProvider(
      create: (_) => SelectedAssets(), // 初期値は app_state.dart 内で定義済み
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
      home: const MainScreen(),
    );
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  _MainScreenState createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;

  final List<Widget> _pages = [
    const HomePage(),
    const NewsPage(),
    const PeoplePage(),
    const SettingsPage(), // ← 設定タブ
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

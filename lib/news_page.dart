import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:webview_flutter/webview_flutter.dart';

class NewsPage extends StatefulWidget {
  const NewsPage({super.key});

  @override
  State<NewsPage> createState() => _NewsPageState();
}

class _NewsPageState extends State<NewsPage> {
  late final WebViewController _controller;
  List<_NewsEntry> _entries = [];
  _NewsEntry? _current;
  String? _error;

  @override
  void initState() {
    super.initState();

    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.transparent);

    _loadEntries();
  }

  Future<void> _loadEntries() async {
    try {
      // 1) index.json があればそれを使う
      final jsonStr = await rootBundle.loadString('assets/news/index.json');
      final decoded = json.decode(jsonStr);
      final list = (decoded is List) ? decoded : (decoded['items'] as List);
      _entries = list
          .map((e) => _NewsEntry(
                title: e['title'] as String,
                file: e['file'] as String,
              ))
          .toList();
    } catch (_) {
      // 2) 無ければデフォルト想定ファイルを試す
      final candidates = const [
        _NewsEntry(title: 'ご利用ガイド', file: 'howto.html'),
        _NewsEntry(title: 'よくある質問', file: 'faq.html'),
        _NewsEntry(title: 'プライバシーポリシー', file: 'privacy.html'),
      ];
      _entries = [];
      for (final c in candidates) {
        try {
          // 存在チェック（読めたらエントリ採用）
          await rootBundle.loadString('assets/news/${c.file}');
          _entries.add(c);
        } catch (_) {
          // 無ければスキップ
        }
      }
      if (_entries.isEmpty) {
        setState(() {
          _error =
              'assets/news/ に HTML が見つかりませんでした。\nindex.json を用意するか、howto.html などを配置してください。';
        });
        return;
      }
    }

    _current = _entries.first;
    await _loadCurrentHtml();
    setState(() {});
  }

  Future<void> _loadCurrentHtml() async {
    if (_current == null) return;
    try {
      final html = await rootBundle.loadString('assets/news/${_current!.file}');
      // ローカルHTMLをそのまま文字列として読み込む
      await _controller.loadHtmlString(html, baseUrl: 'assets/news/');
    } catch (e) {
      setState(() {
        _error = '読み込みエラー: ${_current!.file}\n$e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (_error != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('NEWS')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              _error!,
              style: theme.textTheme.bodyMedium?.copyWith(color: Colors.red),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    final entries = _entries;
    return Scaffold(
      appBar: AppBar(
        title: const Text('NEWS'),
        actions: [
          IconButton(
            tooltip: '再読み込み',
            icon: const Icon(Icons.refresh),
            onPressed: () async {
              await _loadCurrentHtml();
            },
          ),
          if (kIsWeb) const SizedBox(width: 4), // Webでも余白を少し
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(56),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: Row(
              children: [
                Expanded(
                  child: DropdownButton<_NewsEntry>(
                    isExpanded: true,
                    value: _current,
                    items: entries
                        .map((e) => DropdownMenuItem(
                              value: e,
                              child: Text(e.title),
                            ))
                        .toList(),
                    onChanged: (v) async {
                      if (v == null) return;
                      setState(() => _current = v);
                      await _loadCurrentHtml();
                    },
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton.icon(
                  onPressed: () async => _loadCurrentHtml(),
                  icon: const Icon(Icons.play_arrow),
                  label: const Text('開く'),
                ),
              ],
            ),
          ),
        ),
      ),
      body: _entries.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : WebViewWidget(controller: _controller),
    );
  }
}

class _NewsEntry {
  final String title;
  final String file; // 例: 'howto.html'
  const _NewsEntry({required this.title, required this.file});
}

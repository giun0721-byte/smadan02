import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'
    show rootBundle, Clipboard, ClipboardData;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

/// SharedPreferences キー（菩提寺情報）
const String kTempleNameKey = 'temple_name';
const String kTempleSectKey = 'temple_sect';
const String kTempleAddressKey = 'temple_address';
const String kTemplePhoneKey = 'temple_phone';
const String kTempleEmailKey = 'temple_email';

/// NEWS 1件分
class NewsArticle {
  final String title;
  final String body;
  final String? date;
  final String? thumbnail;

  NewsArticle({
    required this.title,
    required this.body,
    this.date,
    this.thumbnail,
  });

  factory NewsArticle.fromJson(Map<String, dynamic> json) {
    return NewsArticle(
      title: json['title'] as String? ?? '',
      body: json['body'] as String? ?? '',
      date: json['date'] as String?,
      thumbnail: json['thumbnail'] as String?,
    );
  }

  String get bodySnippet {
    const maxLength = 60;
    if (body.length <= maxLength) return body;
    return '${body.substring(0, maxLength)}…';
  }

  String get dateLabel => date ?? '';
}

class NewsPage extends StatefulWidget {
  const NewsPage({super.key});

  @override
  State<NewsPage> createState() => _NewsPageState();
}

class _NewsPageState extends State<NewsPage> {
  List<NewsArticle> _articles = [];
  bool _loading = true;
  String? _error;

  // 下からシート表示用
  NewsArticle? _openedArticle;
  bool _showTempleEditSheet = false;
  bool _showTempleActionSheet = false;
  bool _showNenkiSheet = false;

  // 菩提寺パネルへの参照（保存後に再読込させる）
  final GlobalKey<_TempleInfoPanelState> _templePanelKey =
      GlobalKey<_TempleInfoPanelState>();

  @override
  void initState() {
    super.initState();
    _loadNews();
  }

  Future<void> _loadNews() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final jsonStr = await rootBundle.loadString('assets/news/news.json');
      final decoded = json.decode(jsonStr);

      List list;
      if (decoded is List) {
        list = decoded;
      } else if (decoded is Map && decoded['items'] is List) {
        list = decoded['items'] as List;
      } else {
        throw Exception('JSON形式が不正です。配列で定義してください。');
      }

      final articles = list
          .map((e) => NewsArticle.fromJson(e as Map<String, dynamic>))
          .toList();

      // 日付の新しい順
      articles.sort(
        (a, b) => (b.date ?? '').compareTo(a.date ?? ''),
      );

      setState(() {
        _articles = articles;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'NEWSデータの読み込みに失敗しました。\n$e';
        _loading = false;
      });
    }
  }

  /// 個人ページと同イメージ：News記事の下からシート
  void _openArticleWindow(NewsArticle article) {
    setState(() {
      _openedArticle = article;
      _showTempleEditSheet = false;
      _showTempleActionSheet = false;
      _showNenkiSheet = false;
    });
  }

  void _closeArticleWindow() {
    setState(() {
      _openedArticle = null;
    });
  }

  /// 現在開いている記事の「次の記事」を表示
  void _showNextArticle() {
    if (_openedArticle == null) return;
    final currentIndex = _articles.indexOf(_openedArticle!);
    if (currentIndex == -1) return;
    if (currentIndex >= _articles.length - 1) {
      // 最後の記事なので何もしない
      return;
    }
    setState(() {
      _openedArticle = _articles[currentIndex + 1];
    });
  }

  /// 現在開いている記事の「前の記事」を表示
  void _showPrevArticle() {
    if (_openedArticle == null) return;
    final currentIndex = _articles.indexOf(_openedArticle!);
    if (currentIndex <= 0) {
      // 先頭の記事なので何もしない
      return;
    }
    setState(() {
      _openedArticle = _articles[currentIndex - 1];
    });
  }

  void _openTempleEditSheet() {
    setState(() {
      _openedArticle = null;
      _showTempleEditSheet = true;
      _showTempleActionSheet = false;
      _showNenkiSheet = false;
    });
  }

  void _closeTempleEditSheet() {
    setState(() {
      _showTempleEditSheet = false;
    });
  }

  void _openTempleActionSheet() {
    setState(() {
      _openedArticle = null;
      _showTempleEditSheet = false;
      _showTempleActionSheet = true;
      _showNenkiSheet = false;
    });
  }

  void _closeTempleActionSheet() {
    setState(() {
      _showTempleActionSheet = false;
    });
  }

  void _openNenkiSheet() {
    setState(() {
      _openedArticle = null;
      _showTempleEditSheet = false;
      _showTempleActionSheet = false;
      _showNenkiSheet = true;
    });
  }

  void _closeNenkiSheet() {
    setState(() {
      _showNenkiSheet = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          SafeArea(
            child: _error != null
                ? _buildError()
                : Column(
                    children: [
                      // 上 70%：お知らせ一覧
                      Expanded(
                        flex: 7,
                        child: _buildTopFrame(),
                      ),
                      const Divider(height: 1),
                      // 下 30%：左 お寺情報 / 右 年回表（スマホでも常に左右分割）
                      Expanded(
                        flex: 3,
                        child: Row(
                          children: [
                            Expanded(
                              child: TempleInfoPanel(
                                key: _templePanelKey,
                                onEditRequested: _openTempleEditSheet,
                                onActionRequested: _openTempleActionSheet,
                              ),
                            ),
                            const VerticalDivider(width: 1),
                            Expanded(
                              child: NenkiPanel(
                                onOpenSheet: _openNenkiSheet,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
          ),
          if (_openedArticle != null) _buildArticleOverlay(),
          if (_showTempleEditSheet) _buildTempleEditOverlay(),
          if (_showTempleActionSheet) _buildTempleActionOverlay(),
          if (_showNenkiSheet) _buildNenkiOverlay(),
        ],
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _error ?? 'エラーが発生しました。',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: _loadNews,
              child: const Text('再読み込み'),
            ),
          ],
        ),
      ),
    );
  }

  /// 上フレーム：お知らせ一覧
  Widget _buildTopFrame() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    final count = _articles.length;

    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // タイトル＋件数バッジ
          Row(
            children: [
              const Icon(Icons.campaign_outlined),
              const SizedBox(width: 8),
              const Text(
                'お知らせ',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              if (count > 0)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    color: Colors.black.withOpacity(0.05),
                  ),
                  child: Text(
                    '$count件',
                    style: const TextStyle(
                      fontSize: 12,
                    ),
                  ),
                ),
            ],
          ),

          const SizedBox(height: 4),
          const Text(
            'スマダンのお知らせや使い方が表示されます。',
            style: TextStyle(
              fontSize: 12,
              color: Colors.black54,
            ),
          ),
          const SizedBox(height: 8),

          // 一覧部分
          Expanded(
            child: count == 0
                ? const Center(
                    child: Text(
                      '現在、お知らせはありません。',
                      style: TextStyle(fontSize: 16),
                    ),
                  )
                : ListView.separated(
                    itemCount: _articles.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 6),
                    itemBuilder: (context, index) {
                      final article = _articles[index];
                      return _buildNewsCard(article);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  /// 一覧用カード：アイキャッチ＋タイトル＋日付＋本文サマリー
  Widget _buildNewsCard(NewsArticle article) {
    final hasThumb =
        (article.thumbnail != null && article.thumbnail!.isNotEmpty);

    return Card(
      margin: EdgeInsets.zero,
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _openArticleWindow(article),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (hasThumb) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.asset(
                    'assets/news/${article.thumbnail}',
                    width: 90,
                    height: 90,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        width: 90,
                        height: 90,
                        color: Colors.grey.shade200,
                        alignment: Alignment.center,
                        child: const Icon(Icons.image_not_supported),
                      );
                    },
                  ),
                ),
                const SizedBox(width: 12),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // タイトル
                    Text(
                      article.title,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    // 日付
                    if (article.dateLabel.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        article.dateLabel,
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],

                    // 本文サマリー
                    const SizedBox(height: 6),
                    Text(
                      article.bodySnippet,
                      style: const TextStyle(
                        fontSize: 13,
                        color: Colors.black54,
                        height: 1.4,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 記事の下からシート表示（アニメーション付きオーバーレイ）
  Widget _buildArticleOverlay() {
    final article = _openedArticle!;
    return _BottomSheetOverlay(
      onClosed: _closeArticleWindow,
      child: _ArticleSheetContent(
        article: article,
        onSwipeLeft: _showNextArticle,
        onSwipeRight: _showPrevArticle,
      ),
    );
  }

  /// 菩提寺編集シート
  Widget _buildTempleEditOverlay() {
    final panelState = _templePanelKey.currentState;
    final initial = TempleInfoData(
      templeName: panelState?.templeName ?? '',
      sect: panelState?.sect ?? '',
      address: panelState?.address ?? '',
      phone: panelState?.phone ?? '',
      email: panelState?.email ?? '',
    );

    return _BottomSheetOverlay(
      onClosed: _closeTempleEditSheet,
      child: TempleInfoSheet(
        initialData: initial,
        onSaved: () async {
          await panelState?.refresh();
          _closeTempleEditSheet();
        },
        onCanceled: _closeTempleEditSheet,
      ),
    );
  }

  /// 菩提寺アクションシート（電話／メール／経路）
  Widget _buildTempleActionOverlay() {
    final panelState = _templePanelKey.currentState;
    if (panelState == null) {
      return const SizedBox.shrink();
    }

    final name =
        panelState.templeName.isNotEmpty ? panelState.templeName : 'お寺';
    final sect = panelState.sect;
    final address = panelState.address;

    return _BottomSheetOverlay(
      onClosed: _closeTempleActionSheet,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // お寺名 pill
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.15),
                    blurRadius: 4,
                    offset: const Offset(1, 2),
                  ),
                ],
              ),
              child: Text(
                name,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            if (sect.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                sect,
                style: const TextStyle(fontSize: 14),
              ),
            ],
            if (address.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                address,
                style: const TextStyle(fontSize: 14),
              ),
            ],
            const SizedBox(height: 16),

            // 電話ボタン
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFFF3C4),
                  foregroundColor: const Color(0xFF5D4037),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: () {
                  _closeTempleActionSheet();
                  panelState.callTemple();
                },
                icon: const Icon(Icons.phone, size: 22),
                label: const Text(
                  '電話',
                  style: TextStyle(fontSize: 17),
                ),
              ),
            ),
            const SizedBox(height: 12),

            // メールボタン
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFFF3C4),
                  foregroundColor: const Color(0xFF5D4037),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: () {
                  _closeTempleActionSheet();
                  panelState.mailTemple();
                },
                icon: const Icon(Icons.mail, size: 22),
                label: const Text(
                  'メール',
                  style: TextStyle(fontSize: 17),
                ),
              ),
            ),
            const SizedBox(height: 12),

            // 経路ボタン
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFFF3C4),
                  foregroundColor: const Color(0xFF5D4037),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: () {
                  _closeTempleActionSheet();
                  panelState.goTemple();
                },
                icon: const Icon(Icons.map, size: 22),
                label: const Text(
                  '経路',
                  style: TextStyle(fontSize: 17),
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  /// 年回表シート
  Widget _buildNenkiOverlay() {
    return _BottomSheetOverlay(
      onClosed: _closeNenkiSheet,
      child: const _NenkiSheet(),
    );
  }
}

/// 記事詳細シートの中身
/// 上部：サムネイルを左、右側にタイトルと日付、その右に前後矢印
class _ArticleSheetContent extends StatelessWidget {
  final NewsArticle article;
  final VoidCallback? onSwipeLeft; // 次の記事へ
  final VoidCallback? onSwipeRight; // 前の記事へ

  const _ArticleSheetContent({
    required this.article,
    this.onSwipeLeft,
    this.onSwipeRight,
  });

  @override
  Widget build(BuildContext context) {
    final hasThumb =
        (article.thumbnail != null && article.thumbnail!.isNotEmpty);

    return GestureDetector(
      onHorizontalDragEnd: (details) {
        final velocity = details.primaryVelocity ?? 0;
        if (velocity < -200) {
          // 指を左へ払う → 次の記事
          onSwipeLeft?.call();
        } else if (velocity > 200) {
          // 指を右へ払う → 前の記事
          onSwipeRight?.call();
        }
      },
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 上部：サムネイル + タイトル + 日付 + 左右矢印
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (hasThumb) ...[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.asset(
                      'assets/news/${article.thumbnail}',
                      width: 72,
                      height: 72,
                      fit: BoxFit.cover,
                    ),
                  ),
                  const SizedBox(width: 12),
                ],
                // タイトル & 日付
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        article.title,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (article.dateLabel.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          article.dateLabel,
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey.shade700,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                // 左右矢印（視覚的なナビ用）
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back_ios_new, size: 20),
                      onPressed: onSwipeRight, // 前の記事
                      tooltip: '前の記事',
                    ),
                    IconButton(
                      icon: const Icon(Icons.arrow_forward_ios, size: 20),
                      onPressed: onSwipeLeft, // 次の記事
                      tooltip: '次の記事',
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            // 本文
            Expanded(
              child: SingleChildScrollView(
                child: Text(
                  article.body,
                  style: const TextStyle(
                    fontSize: 16,
                    height: 1.6,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// =======================================
/// 共通オーバーレイ：黒背景＋下からスライドするシート
/// =======================================
class _BottomSheetOverlay extends StatefulWidget {
  final Widget child;
  final VoidCallback onClosed;

  const _BottomSheetOverlay({
    required this.child,
    required this.onClosed,
  });

  @override
  State<_BottomSheetOverlay> createState() => _BottomSheetOverlayState();
}

class _BottomSheetOverlayState extends State<_BottomSheetOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 280),
      vsync: this,
    );
    _slide = Tween<Offset>(
      begin: const Offset(0, 1),
      end: const Offset(0, 0),
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeOutCubic,
      ),
    );

    _controller.forward();
  }

  Future<void> _startClose() async {
    await _controller.reverse();
    if (!mounted) return;
    widget.onClosed();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: GestureDetector(
        // 黒背景タップで閉じる（アニメーション付き）
        onTap: _startClose,
        child: Container(
          color: Colors.black54,
          child: GestureDetector(
            // シート本体タップでは背景扱いにしない
            onTap: () {},
            // 下向きスワイプで閉じる
            onVerticalDragEnd: (details) {
              final velocity = details.primaryVelocity ?? 0;
              if (velocity > 200) {
                _startClose();
              }
            },
            child: Align(
              alignment: Alignment.bottomCenter,
              child: SlideTransition(
                position: _slide,
                child: _BottomSheetFrame(child: widget.child),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 共通の下からシート枠（個人ページ風）
/// ※見た目のみ。アニメーションは _BottomSheetOverlay 側で実施
class _BottomSheetFrame extends StatelessWidget {
  final Widget child;

  const _BottomSheetFrame({required this.child});

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final height = media.size.height * 0.8; // 全体の約8割（必要に応じて微調整）

    return Container(
      height: height,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 8),
          // 上部のつまみ
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade400,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(child: child),
        ],
      ),
    );
  }
}

/// =======================
/// 下段 左：お寺情報パネル
/// =======================
class TempleInfoPanel extends StatefulWidget {
  final VoidCallback onEditRequested;
  final VoidCallback onActionRequested;

  const TempleInfoPanel({
    super.key,
    required this.onEditRequested,
    required this.onActionRequested,
  });

  @override
  State<TempleInfoPanel> createState() => _TempleInfoPanelState();
}

class _TempleInfoPanelState extends State<TempleInfoPanel> {
  String _templeName = '';
  String _sect = '';
  String _phone = '';
  String _email = '';
  String _address = '';
  bool _loading = true;

  // 外から参照するための getter
  String get templeName => _templeName;
  String get sect => _sect;
  String get phone => _phone;
  String get email => _email;
  String get address => _address;

  @override
  void initState() {
    super.initState();
    _loadSummary();
  }

  Future<void> _loadSummary() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _templeName = prefs.getString(kTempleNameKey) ?? '';
      _sect = prefs.getString(kTempleSectKey) ?? '';
      _phone = prefs.getString(kTemplePhoneKey) ?? '';
      _email = prefs.getString(kTempleEmailKey) ?? '';
      _address = prefs.getString(kTempleAddressKey) ?? '';
      _loading = false;
    });
  }

  /// NewsPage 側から再読込させるための公開メソッド
  Future<void> refresh() => _loadSummary();

  // 以下、電話／メール／経路を NEWS ページから呼べるよう公開メソッドにする
  Future<void> callTemple() async {
    if (_phone.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('電話番号が登録されていません。')),
      );
      return;
    }
    final uri = Uri.parse('tel:${_phone.trim()}');
    try {
      final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!ok && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('電話アプリを開けませんでした。')),
        );
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('電話アプリの起動中にエラーが発生しました。')),
      );
    }
  }

  Future<void> mailTemple() async {
    if (_email.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('メールアドレスが登録されていません。')),
      );
      return;
    }
    final uri = Uri(
      scheme: 'mailto',
      path: _email.trim(),
    );
    try {
      final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!ok && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('メールアプリを開けませんでした。')),
        );
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('メールアプリの起動中にエラーが発生しました。')),
      );
    }
  }

  Future<void> goTemple() async {
    if (_address.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('住所が登録されていません。')),
      );
      return;
    }
    final encoded = Uri.encodeComponent(_address.trim());
    final uri =
        Uri.parse('https://www.google.com/maps/search/?api=1&query=$encoded');
    try {
      final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!ok && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Googleマップを開けませんでした。')),
        );
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('地図アプリの起動中にエラーが発生しました。')),
      );
    }
  }

  /// （未使用だが残しても問題なし）
  Widget _buildTempleAvatar() {
    return Container(
      width: 72,
      height: 72,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        gradient: const LinearGradient(
          colors: [
            Color(0xFFFDF8E1),
            Color(0xFFF7EEC4),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(2, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.asset(
          'assets/news/temple_ico.png',
          fit: BoxFit.cover,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Container(
        color: Colors.orange.shade50,
        child: const Center(child: CircularProgressIndicator()),
      );
    }

    final bool isRegistered = _templeName.isNotEmpty;

    return Container(
      decoration: const BoxDecoration(
        image: DecorationImage(
          image: AssetImage('assets/news/bg_temple.jpg'),
          fit: BoxFit.cover,
          alignment: Alignment.center,
        ),
      ),
      child: InkWell(
        onTap: isRegistered ? widget.onActionRequested : null,
        onLongPress: widget.onEditRequested,
        child: Container(
          // 背景の白を少し薄く
          color: Colors.white.withOpacity(0.60),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // --- 未登録時の表示 ---
                if (!isRegistered) ...[
                  Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.15),
                            blurRadius: 4,
                            offset: const Offset(1, 2),
                          ),
                        ],
                      ),
                      child: const Text(
                        'お寺情報',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Expanded(
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        '長押しで登録 ▶',
                        style: TextStyle(fontSize: 12, color: Colors.black54),
                      ),
                    ),
                  ),
                ],

                // --- 登録済み表示 ---
                if (isRegistered) ...[
                  Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.15),
                            blurRadius: 4,
                            offset: const Offset(1, 2),
                          ),
                        ],
                      ),
                      child: Text(
                        _templeName,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  if (_sect.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      _sect,
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.black87,
                      ),
                      textAlign: TextAlign.left,
                    ),
                  ],
                  const Expanded(
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'タップで連絡／長押しで登録 ▶',
                        style: TextStyle(fontSize: 12, color: Colors.black54),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 菩提寺情報を編集するためのデータクラス
class TempleInfoData {
  final String templeName;
  final String sect;
  final String address;
  final String phone;
  final String email;

  const TempleInfoData({
    this.templeName = '',
    this.sect = '',
    this.address = '',
    this.phone = '',
    this.email = '',
  });
}

/// 菩提寺情報登録シート（ボトムシートの中身）
class TempleInfoSheet extends StatefulWidget {
  final TempleInfoData initialData;
  final Future<void> Function()? onSaved;
  final VoidCallback? onCanceled;

  const TempleInfoSheet({
    super.key,
    required this.initialData,
    this.onSaved,
    this.onCanceled,
  });

  @override
  State<TempleInfoSheet> createState() => _TempleInfoSheetState();
}

class _TempleInfoSheetState extends State<TempleInfoSheet> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _templeNameController;
  late TextEditingController _sectController;
  late TextEditingController _addressController;
  late TextEditingController _phoneController;
  late TextEditingController _emailController;

  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _templeNameController =
        TextEditingController(text: widget.initialData.templeName);
    _sectController = TextEditingController(text: widget.initialData.sect);
    _addressController =
        TextEditingController(text: widget.initialData.address);
    _phoneController = TextEditingController(text: widget.initialData.phone);
    _emailController = TextEditingController(text: widget.initialData.email);
  }

  @override
  void dispose() {
    _templeNameController.dispose();
    _sectController.dispose();
    _addressController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _templeNameController.text.trim();
    final sect = _sectController.text.trim();
    final addr = _addressController.text.trim();
    final phone = _phoneController.text.trim();
    final email = _emailController.text.trim();

    if (name.isEmpty &&
        sect.isEmpty &&
        addr.isEmpty &&
        phone.isEmpty &&
        email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('いずれか1項目以上入力してください。')),
      );
      return;
    }

    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _saving = true;
    });

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(kTempleNameKey, name);
    await prefs.setString(kTempleSectKey, sect);
    await prefs.setString(kTempleAddressKey, addr);
    await prefs.setString(kTemplePhoneKey, phone);
    await prefs.setString(kTempleEmailKey, email);

    if (widget.onSaved != null) {
      await widget.onSaved!();
    }
  }

  void _cancel() {
    widget.onCanceled?.call();
  }

  void _clear() {
    _templeNameController.clear();
    _sectController.clear();
    _addressController.clear();
    _phoneController.clear();
    _emailController.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'お寺の情報',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: SingleChildScrollView(
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildTextField(
                      label: 'お寺の名前',
                      controller: _templeNameController,
                      hint: '例）◯◯寺',
                    ),
                    const SizedBox(height: 8),
                    _buildTextField(
                      label: '宗派',
                      controller: _sectController,
                      hint: '例）◯◯宗◯◯派',
                    ),
                    const SizedBox(height: 8),
                    _buildTextField(
                      label: '住所',
                      controller: _addressController,
                      hint: '例）〒xxx-xxxx◯◯市◯◯町',
                      maxLines: 2,
                    ),
                    const SizedBox(height: 8),
                    _buildTextField(
                      label: '電話番号',
                      controller: _phoneController,
                      hint: '例）xxx-xxx-xxxx',
                      onChanged: (value) {
                        final onlyNum = value.replaceAll(RegExp(r'[^0-9]'), '');
                        String formatted = onlyNum;

                        if (onlyNum.length > 3 && onlyNum.length <= 6) {
                          formatted =
                              '${onlyNum.substring(0, 3)}-${onlyNum.substring(3)}';
                        } else if (onlyNum.length > 6) {
                          formatted =
                              '${onlyNum.substring(0, 3)}-${onlyNum.substring(3, 6)}-${onlyNum.substring(6)}';
                        }

                        if (formatted != value) {
                          _phoneController.value = TextEditingValue(
                            text: formatted,
                            selection: TextSelection.collapsed(
                                offset: formatted.length),
                          );
                        }
                      },
                    ),
                    const SizedBox(height: 8),
                    _buildTextField(
                      label: 'メールアドレス',
                      controller: _emailController,
                      hint: '例）example@example.com',
                      validator: (value) {
                        final text = value?.trim() ?? '';
                        if (text.isEmpty) {
                          return null;
                        }
                        if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(text)) {
                          return '正しい形式のメールアドレスを入力してください';
                        }
                        return null;
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              TextButton(
                onPressed: _saving ? null : _clear,
                child: const Text('クリア'),
              ),
              const Spacer(),
              TextButton(
                onPressed: _saving ? null : _cancel,
                child: const Text('キャンセル'),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: _saving ? null : _save,
                child: const Text('保存'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required String label,
    required TextEditingController controller,
    String? hint,
    int maxLines = 1,
    void Function(String)? onChanged,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      style: const TextStyle(fontSize: 16),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        border: const OutlineInputBorder(),
      ),
      onChanged: onChanged,
      validator: validator,
    );
  }
}

/// =======================
/// 下段 右：年回表パネル
/// =======================
class NenkiPanel extends StatelessWidget {
  final VoidCallback onOpenSheet;

  const NenkiPanel({super.key, required this.onOpenSheet});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        image: DecorationImage(
          image: AssetImage('assets/news/bg_report.jpg'),
          fit: BoxFit.cover,
          alignment: Alignment.center,
        ),
      ),
      child: InkWell(
        onTap: onOpenSheet,
        child: Container(
          // 背景の白を少し薄く
          color: Colors.white.withOpacity(0.60),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 「年回表」角丸白ボタン風（横中央）
                Center(
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.15),
                          blurRadius: 4,
                          offset: const Offset(1, 2),
                        ),
                      ],
                    ),
                    child: const Text(
                      '年回表',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                const Expanded(
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'タップして年回を計算 ▶',
                      style: TextStyle(fontSize: 12, color: Colors.black54),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 年回表の計算シート本体（ボトムシートの中身）
class _NenkiSheet extends StatefulWidget {
  const _NenkiSheet();

  @override
  State<_NenkiSheet> createState() => _NenkiSheetState();
}

class _NenkiSheetState extends State<_NenkiSheet> {
  final _yearController = TextEditingController();
  List<_NenkiRow> _rows = [];

  final List<int> _cycles = [1, 3, 7, 13, 17, 25, 33, 50];

  /// 入力文字列から西暦年を取り出す
  /// - 2020 などの数字だけ → そのまま西暦として扱う
  /// - 令和5 / R5 / 平成30 / H30 / 昭和60 / 昭和元年 など → 対応する西暦に変換
  int? _parseYear(String input) {
    var text = input.trim();
    if (text.isEmpty) return null;

    // 全角スペースや「年」を削除
    text = text.replaceAll(RegExp(r'\s|　|年'), '');

    // まず「数字のみ」の場合（例：2020）
    if (RegExp(r'^[0-9]+$').hasMatch(text)) {
      return int.tryParse(text);
    }

    // 「元年」対応用：数字部分が「元」の場合は 1 年とみなす
    int? _numFrom(String s) {
      if (s == '元') return 1;
      return int.tryParse(s);
    }

    // 和暦：令和 / R
    if (text.startsWith('令和') || text.startsWith('R')) {
      final n = _numFrom(text.replaceFirst(RegExp(r'^(令和|R)'), ''));
      if (n == null) return null;
      return 2018 + n; // R1 = 2019
    }

    // 平成 / H
    if (text.startsWith('平成') || text.startsWith('H')) {
      final n = _numFrom(text.replaceFirst(RegExp(r'^(平成|H)'), ''));
      if (n == null) return null;
      return 1988 + n; // H1 = 1989
    }

    // 昭和 / S
    if (text.startsWith('昭和') || text.startsWith('S')) {
      final n = _numFrom(text.replaceFirst(RegExp(r'^(昭和|S)'), ''));
      if (n == null) return null;
      return 1925 + n; // S1 = 1926
    }

    // 大正 / T
    if (text.startsWith('大正') || text.startsWith('T')) {
      final n = _numFrom(text.replaceFirst(RegExp(r'^(大正|T)'), ''));
      if (n == null) return null;
      return 1911 + n; // T1 = 1912
    }

    // 明治 / M
    if (text.startsWith('明治') || text.startsWith('M')) {
      final n = _numFrom(text.replaceFirst(RegExp(r'^(明治|M)'), ''));
      if (n == null) return null;
      return 1867 + n; // M1 = 1868
    }

    // 対応外
    return null;
  }

  @override
  void dispose() {
    _yearController.dispose();
    super.dispose();
  }

  void _calcNenki() {
    final text = _yearController.text.trim();
    final year = _parseYear(text);
    final nowYear = DateTime.now().year;

    if (year == null || year < 1800 || year > 3000) {
      setState(() {
        _rows = [
          _NenkiRow(
            label: '',
            year: null,
            note: '正しい年数を入力してください。\n（例：2020／令和2／H30 など）',
          ),
        ];
      });
      return;
    }

    final rows = <_NenkiRow>[];
    for (final c in _cycles) {
      final yr = year + c - 1; // 命年＋(回忌−1)
      if (yr >= nowYear) {
        String label;
        if (c == 1) {
          label = '1周忌';
        } else {
          label = '$c回忌';
        }

        rows.add(_NenkiRow(
          label: label,
          year: yr,
          note: '',
        ));
      }
    }

    if (rows.isEmpty) {
      rows.add(_NenkiRow(
        label: '',
        year: null,
        note: '今後に該当する年回はありません。',
      ));
    }

    setState(() {
      _rows = rows;
    });
  }

  void _quickSetYear(int year) {
    _yearController.text = year.toString();
    _calcNenki();
  }

  Future<void> _copyResults() async {
    if (_rows.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('コピーする年回の一覧がありません。')),
      );
      return;
    }

    final buffer = StringBuffer();
    for (final r in _rows) {
      if (r.year == null) {
        if (r.note.isNotEmpty) {
          buffer.writeln(r.note);
        }
      } else {
        final wareki = _formatWareki(r.year!);
        if (wareki.isEmpty) {
          buffer.writeln('${r.label}　${r.year}年');
        } else {
          buffer.writeln('${r.label}　${r.year}年（$wareki）');
        }
      }
    }

    await Clipboard.setData(ClipboardData(text: buffer.toString()));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('年回一覧をコピーしました。')),
    );
  }

  /// 西暦年 → 和暦表示（令和・平成・昭和・大正・明治）
  String _formatWareki(int year) {
    if (year >= 2019) {
      final n = year - 2018;
      final y = (n == 1) ? '元' : '$n';
      return '令和$y年';
    } else if (year >= 1989) {
      final n = year - 1988;
      final y = (n == 1) ? '元' : '$n';
      return '平成$y年';
    } else if (year >= 1926) {
      final n = year - 1925;
      final y = (n == 1) ? '元' : '$n';
      return '昭和$y年';
    } else if (year >= 1912) {
      final n = year - 1911;
      final y = (n == 1) ? '元' : '$n';
      return '大正$y年';
    } else if (year >= 1868) {
      final n = year - 1867;
      final y = (n == 1) ? '元' : '$n';
      return '明治$y年';
    }
    return '';
  }

  @override
  Widget build(BuildContext context) {
    final nowYear = DateTime.now().year;
    // 今年・1年前・2年前
    final quickYears = [
      nowYear,
      nowYear - 1,
      nowYear - 2,
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '年回表',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          const Text(
            '亡くなった年を入力',
            style: TextStyle(fontSize: 14, height: 1.5),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _yearController,
                  // 和暦も入力できるように text に変更
                  keyboardType: TextInputType.text,
                  style: const TextStyle(fontSize: 18),
                  decoration: const InputDecoration(
                    labelText: 'ご命年',
                    hintText: '例：2020／令和2／H30 など',
                    border: OutlineInputBorder(),
                  ),
                  onSubmitted: (_) => _calcNenki(),
                ),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: _calcNenki,
                child: const Text('計算', style: TextStyle(fontSize: 16)),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Wrap(
            spacing: 4,
            runSpacing: 4,
            children: [
              for (final y in quickYears)
                OutlinedButton(
                  onPressed: () => _quickSetYear(y),
                  child: Text('$y'),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                '計算結果',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
              ),
              if (_rows.isNotEmpty)
                TextButton.icon(
                  onPressed: _copyResults,
                  icon: const Icon(Icons.copy, size: 18),
                  label: const Text(
                    '一覧をコピー',
                    style: TextStyle(fontSize: 13),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                border: Border.all(color: Colors.black26),
                borderRadius: BorderRadius.circular(8),
                color: Colors.white,
              ),
              child: _rows.isEmpty
                  ? const Align(
                      alignment: Alignment.topLeft,
                      child: Padding(
                        padding: EdgeInsets.all(8.0),
                        child: Text(
                          '年を入力して計算ボタンを押すか、\nそれぞれの年のボタンを押してください',
                          style: TextStyle(fontSize: 14),
                          textAlign: TextAlign.left,
                        ),
                      ),
                    )
                  : ListView.builder(
                      itemCount: _rows.length,
                      itemBuilder: (context, index) {
                        final r = _rows[index];
                        if (r.year == null) {
                          return ListTile(
                            dense: true,
                            visualDensity: VisualDensity.compact,
                            title: Text(
                              r.note,
                              style: const TextStyle(
                                fontSize: 14,
                                height: 1.1,
                              ),
                            ),
                          );
                        }
                        final wareki = _formatWareki(r.year!);
                        final titleText = wareki.isEmpty
                            ? '${r.label}　${r.year}年'
                            : '${r.label}　${r.year}年（$wareki）';

                        return ListTile(
                          dense: true,
                          visualDensity: VisualDensity.compact,
                          title: Text(
                            titleText,
                            style: const TextStyle(
                              fontSize: 16,
                              height: 1.0,
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NenkiRow {
  final String label;
  final int? year;
  final String note;

  _NenkiRow({
    required this.label,
    required this.year,
    required this.note,
  });
}

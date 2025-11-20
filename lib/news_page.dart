import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

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

  NewsArticle? _openedArticle; // ウィンドウ表示中の記事

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

  void _openArticleWindow(NewsArticle article) {
    setState(() {
      _openedArticle = article;
    });
  }

  void _closeArticleWindow() {
    setState(() {
      _openedArticle = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // ← AppBarを完全に消す（枠もなし）
      body: Stack(
        children: [
          SafeArea(
            child: _error != null
                ? _buildError()
                : LayoutBuilder(
                    builder: (context, constraints) {
                      final isNarrow = constraints.maxWidth < 700;

                      return Column(
                        children: [
                          // 上 60%：お知らせ一覧のみ
                          Expanded(
                            flex: 6,
                            child: _buildTopFrame(),
                          ),
                          const Divider(height: 1),
                          // 下 40%：左 菩提寺 / 右 年回表
                          Expanded(
                            flex: 4,
                            child: isNarrow
                                ? const Column(
                                    children: [
                                      Expanded(child: TempleInfoPanel()),
                                      Divider(height: 1),
                                      Expanded(child: NenkiPanel()),
                                    ],
                                  )
                                : const Row(
                                    children: [
                                      Expanded(child: TempleInfoPanel()),
                                      VerticalDivider(width: 1),
                                      Expanded(child: NenkiPanel()),
                                    ],
                                  ),
                          ),
                        ],
                      );
                    },
                  ),
          ),
          if (_openedArticle != null) _buildArticleOverlay(),
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
            'お寺からのお知らせや法要のご案内が表示されます。',
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

  /// 記事の内容を表示するオーバーレイ（下メニューが隠れないサイズ）
  Widget _buildArticleOverlay() {
    final article = _openedArticle!;
    return Positioned.fill(
      child: GestureDetector(
        onTap: _closeArticleWindow,
        child: Container(
          color: Colors.black54,
          alignment: Alignment.center,
          child: GestureDetector(
            // 中身タップで閉じないように
            onTap: () {},
            child: FractionallySizedBox(
              heightFactor: 0.7, // 画面の70% → 下のメニューは隠れない
              widthFactor: 0.9,
              child: Card(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ヘッダ
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 8, 4),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (article.dateLabel.isNotEmpty)
                                  Text(
                                    article.dateLabel,
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: Colors.grey.shade700,
                                    ),
                                  ),
                                const SizedBox(height: 2),
                                Text(
                                  article.title,
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            onPressed: _closeArticleWindow,
                            icon: const Icon(Icons.close),
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1),
                    if (article.thumbnail != null &&
                        article.thumbnail!.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Center(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.asset(
                              'assets/news/${article.thumbnail}',
                              height: 140,
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                      ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
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
                    ),
                    // 右下の「閉じる」ボタンは削除
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// =======================
/// 下段 左：菩提寺パネル
/// =======================
class TempleInfoPanel extends StatefulWidget {
  const TempleInfoPanel({super.key});

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

  static const _keyTempleName = 'temple_name';
  static const _keySect = 'temple_sect';
  static const _keyAddress = 'temple_address';
  static const _keyPhone = 'temple_phone';
  static const _keyEmail = 'temple_email';

  @override
  void initState() {
    super.initState();
    _loadSummary();
  }

  Future<void> _loadSummary() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _templeName = prefs.getString(_keyTempleName) ?? '';
      _sect = prefs.getString(_keySect) ?? '';
      _phone = prefs.getString(_keyPhone) ?? '';
      _email = prefs.getString(_keyEmail) ?? '';
      _address = prefs.getString(_keyAddress) ?? '';
      _loading = false;
    });
  }

  /// ロングタップで登録ウィンドウ（編集）
  Future<void> _openEditDialog() async {
    final prefs = await SharedPreferences.getInstance();

    final initial = TempleInfoData(
      templeName: prefs.getString(_keyTempleName) ?? '',
      sect: prefs.getString(_keySect) ?? '',
      address: prefs.getString(_keyAddress) ?? '',
      phone: prefs.getString(_keyPhone) ?? '',
      email: prefs.getString(_keyEmail) ?? '',
    );

    final updated = await showDialog<bool>(
      context: context,
      barrierDismissible: false, // 保存 or キャンセルまで閉じない
      builder: (context) => TempleInfoDialog(
        initialData: initial,
        keys: const TempleInfoKeys(
          templeNameKey: _keyTempleName,
          sectKey: _keySect,
          addressKey: _keyAddress,
          phoneKey: _keyPhone,
          emailKey: _keyEmail,
        ),
      ),
    );

    if (updated == true) {
      await _loadSummary();
    }
  }

  /// タップで「電話する／メールする／行ってみる」メニュー
  Future<void> _openActionDialog() async {
    final name = _templeName.isNotEmpty ? _templeName : '菩提寺';
    final sect = _sect.isNotEmpty ? _sect : '';
    final address = _address.isNotEmpty ? _address : '';

    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black54,
      builder: (context) {
        return Center(
          child: FractionallySizedBox(
            heightFactor: 0.38, // ← 少し高さUP（情報追加のため）
            widthFactor: 0.9,
            child: Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start, // ← ★左揃え
                  children: [
                    // ☆ お寺の名前
                    Text(
                      name,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.left,
                    ),

                    // ☆ 宗派
                    if (sect.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        sect,
                        style: const TextStyle(fontSize: 14),
                      ),
                    ],

                    // ☆ 住所
                    if (address.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        address,
                        style: const TextStyle(fontSize: 14),
                      ),
                    ],

                    const SizedBox(height: 16), // ← ボタン類前に余白追加

                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFF8C200), // ← 山吹色
                          foregroundColor: Colors.black87,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12), // ← 角丸少し強め
                          ),
                        ),
                        onPressed: () {
                          Navigator.of(context).pop();
                          _callTemple();
                        },
                        icon: const Icon(Icons.phone, size: 22),
                        label:
                            const Text('電話する', style: TextStyle(fontSize: 16)),
                      ),
                    ),
                    const SizedBox(height: 12),

                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFF8C200),
                          foregroundColor: Colors.black87,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: () {
                          Navigator.of(context).pop();
                          _mailTemple();
                        },
                        icon: const Icon(Icons.mail, size: 22),
                        label:
                            const Text('メールする', style: TextStyle(fontSize: 16)),
                      ),
                    ),
                    const SizedBox(height: 12),

                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFF8C200),
                          foregroundColor: Colors.black87,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: () {
                          Navigator.of(context).pop();
                          _goTemple();
                        },
                        icon: const Icon(Icons.map, size: 22),
                        label:
                            const Text('行ってみる', style: TextStyle(fontSize: 16)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _callTemple() async {
    if (_phone.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('電話番号が登録されていません。')),
      );
      return;
    }
    final uri = Uri(scheme: 'tel', path: _phone.trim());
    if (!await launchUrl(uri)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('電話アプリを開けませんでした。')),
      );
    }
  }

  Future<void> _mailTemple() async {
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
    if (!await launchUrl(uri)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('メールアプリを開けませんでした。')),
      );
    }
  }

  Future<void> _goTemple() async {
    if (_address.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('住所が登録されていません。')),
      );
      return;
    }
    final encoded = Uri.encodeComponent(_address.trim());
    final uri =
        Uri.parse('https://www.google.com/maps/search/?api=1&query=$encoded');
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Googleマップを開けませんでした。')),
      );
    }
  }

  /// temple_ico.png を角丸・和紙風背景で表示（1.5倍サイズ）
  Widget _buildTempleAvatar() {
    return Container(
      width: 72,
      height: 72,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        gradient: const LinearGradient(
          colors: [
            Color(0xFFFDF8E1), // 和紙の淡いクリーム
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
      color: Colors.orange.shade50,
      child: InkWell(
        onTap: isRegistered ? _openActionDialog : null,
        onLongPress: _openEditDialog,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // --- 未登録時の表示 ---
              if (!isRegistered) ...[
                const Text(
                  '菩提寺',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                const Text(
                  '長押しで菩提寺を登録しましょう',
                  style: TextStyle(fontSize: 14, height: 1.5),
                ),
                const Spacer(),
                const Align(
                  alignment: Alignment.bottomRight,
                  child: Text(
                    '長押しで登録 ▶',
                    style: TextStyle(fontSize: 12, color: Colors.black54),
                  ),
                ),
              ],

              // --- 登録済み表示 ---
              if (isRegistered) ...[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildTempleAvatar(),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start, // ← 左寄せ
                        children: [
                          // お寺の名前（左寄せ）
                          Text(
                            _templeName,
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.left,
                          ),

                          // 宗派（あれば表示）
                          if (_sect.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              _sect,
                              style: const TextStyle(
                                fontSize: 14,
                                color: Colors.black87,
                              ),
                              textAlign: TextAlign.left,
                            ),
                          ],

                          // 住所（あれば表示）
                          if (_address.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              _address,
                              style: const TextStyle(
                                fontSize: 13,
                                color: Colors.black87,
                                height: 1.3,
                              ),
                              textAlign: TextAlign.left,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                const Align(
                  alignment: Alignment.bottomRight,
                  child: Text(
                    'タップで連絡／長押しで登録 ▶',
                    style: TextStyle(fontSize: 12, color: Colors.black54),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// 菩提寺情報をダイアログで編集するためのデータクラス
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

class TempleInfoKeys {
  final String templeNameKey;
  final String sectKey;
  final String addressKey;
  final String phoneKey;
  final String emailKey;

  const TempleInfoKeys({
    required this.templeNameKey,
    required this.sectKey,
    required this.addressKey,
    required this.phoneKey,
    required this.emailKey,
  });
}

/// 菩提寺情報登録ウィンドウ（ダイアログ）
class TempleInfoDialog extends StatefulWidget {
  final TempleInfoData initialData;
  final TempleInfoKeys keys;

  const TempleInfoDialog({
    super.key,
    required this.initialData,
    required this.keys,
  });

  @override
  State<TempleInfoDialog> createState() => _TempleInfoDialogState();
}

class _TempleInfoDialogState extends State<TempleInfoDialog> {
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
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _saving = true;
    });

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        widget.keys.templeNameKey, _templeNameController.text.trim());
    await prefs.setString(widget.keys.sectKey, _sectController.text.trim());
    await prefs.setString(
        widget.keys.addressKey, _addressController.text.trim());
    await prefs.setString(widget.keys.phoneKey, _phoneController.text.trim());
    await prefs.setString(widget.keys.emailKey, _emailController.text.trim());

    if (!mounted) return;
    Navigator.of(context).pop(true); // 更新あり
  }

  void _cancel() {
    Navigator.of(context).pop(false); // 変更なし
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('お寺の情報'),
      content: SizedBox(
        width: 400,
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
                  isRequired: true,
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
                        selection:
                            TextSelection.collapsed(offset: formatted.length),
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
                    if (value == null || value.trim().isEmpty) {
                      return 'メールアドレスを入力してください';
                    }
                    if (!RegExp(r'^[^@]+@[^@]+\.[^@]+')
                        .hasMatch(value.trim())) {
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
      actions: [
        TextButton(
          onPressed: _saving ? null : _cancel,
          child: const Text('キャンセル'),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: const Text('保存'),
        ),
      ],
    );
  }

  Widget _buildTextField({
    required String label,
    required TextEditingController controller,
    String? hint,
    bool isRequired = false,
    int maxLines = 1,
    void Function(String)? onChanged, // ← 追加
    String? Function(String?)? validator, // ← 追加
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
      onChanged: onChanged, // ← 追加：電話番号の自動整形がここで動く
      validator: validator ??
          (isRequired
              ? (value) {
                  if (value == null || value.trim().isEmpty) {
                    return '$label を入力してください。';
                  }
                  return null;
                }
              : null),
    );
  }
}

/// =======================
/// 下段 右：年回表パネル
/// =======================
class NenkiPanel extends StatefulWidget {
  const NenkiPanel({super.key});

  @override
  State<NenkiPanel> createState() => _NenkiPanelState();
}

class _NenkiPanelState extends State<NenkiPanel> {
  final _yearController = TextEditingController();
  List<_NenkiRow> _rows = [];

  final List<int> _cycles = [1, 3, 7, 13, 17, 25, 33, 50];

  @override
  void dispose() {
    _yearController.dispose();
    super.dispose();
  }

  void _calcNenki() {
    final text = _yearController.text.trim();
    final year = int.tryParse(text);
    final nowYear = DateTime.now().year;

    if (year == null || year < 1800 || year > 3000) {
      setState(() {
        _rows = [
          _NenkiRow(
            label: '',
            year: null,
            note: '正しい西暦年を入力してください。',
          ),
        ];
      });
      return;
    }

    final rows = <_NenkiRow>[];
    for (final c in _cycles) {
      final yr = year + c - 1; // HTMLと同じ計算
      if (yr >= nowYear) {
        final note = (c == 33 || c == 50) ? '節目の大法要の目安' : '';
        rows.add(_NenkiRow(
          label: '$c回忌',
          year: yr,
          note: note,
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

  @override
  Widget build(BuildContext context) {
    final nowYear = DateTime.now().year;
    final quickYears = [
      nowYear, // 今年
      nowYear + 1, // 来年
      nowYear + 6, // 6年後
    ];

    return Container(
      color: Colors.blue.shade50,
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '年回表',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          const Text(
            '亡くなった年を西暦で入力してください。',
            style: TextStyle(fontSize: 14, height: 1.5),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _yearController,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(fontSize: 18),
                  decoration: const InputDecoration(
                    labelText: 'ご命年（西暦）',
                    hintText: '例：2020',
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
              const Text('クイック入力：', style: TextStyle(color: Colors.black54)),
              for (final y in quickYears)
                OutlinedButton(
                  onPressed: () => _quickSetYear(y),
                  child: Text('$y'),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                border: Border.all(color: Colors.black26),
                borderRadius: BorderRadius.circular(8),
                color: Colors.white,
              ),
              child: _rows.isEmpty
                  ? const Center(
                      child: Text(
                        '年を入力して「計算」を押してください。',
                        style: TextStyle(fontSize: 14),
                      ),
                    )
                  : ListView.builder(
                      itemCount: _rows.length,
                      itemBuilder: (context, index) {
                        final r = _rows[index];
                        if (r.year == null) {
                          return ListTile(
                            title: Text(
                              r.note,
                              style: const TextStyle(fontSize: 14),
                            ),
                          );
                        }
                        return ListTile(
                          dense: true,
                          title: Text(
                            '${r.label}　${r.year}年',
                            style: const TextStyle(fontSize: 16),
                          ),
                          subtitle: r.note.isNotEmpty
                              ? Text(
                                  r.note,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Colors.black54,
                                  ),
                                )
                              : null,
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

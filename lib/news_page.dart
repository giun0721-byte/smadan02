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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // 上の「NEWS」は消したい → タイトルを空文字に
      appBar: AppBar(
        title: const Text(''),
      ),
      body: SafeArea(
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

  /// 上フレーム：お知らせのみ
  Widget _buildTopFrame() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Padding(
      padding: const EdgeInsets.all(12),
      child: ListView(
        children: [
          const Text(
            'お知らせ',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          if (_articles.isEmpty)
            const Text(
              '現在、お知らせはありません。',
              style: TextStyle(fontSize: 16),
            )
          else
            ..._articles.map(_buildNewsCard),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildNewsCard(NewsArticle article) {
    final hasThumb =
        (article.thumbnail != null && article.thumbnail!.isNotEmpty);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => NewsDetailPage(article: article),
              ),
            );
          },
          child: Padding(
            padding: const EdgeInsets.all(16),
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
                      Text(
                        article.title,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (article.dateLabel.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          article.dateLabel,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                      const SizedBox(height: 8),
                      Text(
                        article.bodySnippet,
                        style: const TextStyle(
                          fontSize: 16,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Align(
                        alignment: Alignment.centerRight,
                        child: Text(
                          'くわしく見る ▶',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade700,
                          ),
                        ),
                      ),
                    ],
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

class NewsDetailPage extends StatelessWidget {
  final NewsArticle article;

  const NewsDetailPage({super.key, required this.article});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(article.title),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (article.dateLabel.isNotEmpty) ...[
                Text(
                  article.dateLabel,
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey.shade700,
                  ),
                ),
                const SizedBox(height: 12),
              ],
              Text(
                article.title,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              if (article.thumbnail != null &&
                  article.thumbnail!.isNotEmpty) ...[
                Center(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Image.asset(
                      'assets/news/${article.thumbnail}',
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],
              Text(
                article.body,
                style: const TextStyle(fontSize: 18, height: 1.6),
              ),
            ],
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
  String _phone = '';
  String _email = '';
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
      _phone = prefs.getString(_keyPhone) ?? '';
      _email = prefs.getString(_keyEmail) ?? '';
      _loading = false;
    });
  }

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
      barrierDismissible: false, // 保存 or キャンセルを押すまで閉じられないように
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
      // 保存されたらサマリーを更新
      await _loadSummary();
    }
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

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Container(
        color: Colors.orange.shade50,
        child: const Center(child: CircularProgressIndicator()),
      );
    }

    final title = _templeName.isNotEmpty ? _templeName : '菩提寺';

    return Container(
      color: Colors.orange.shade50,
      child: InkWell(
        onTap: _openEditDialog,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style:
                    const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              const Text(
                '菩提寺の名前や住所、連絡先を登録しておくことができます。',
                style: TextStyle(fontSize: 14, height: 1.4),
              ),
              const SizedBox(height: 8),
              if (_phone.isNotEmpty || _email.isNotEmpty)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_phone.isNotEmpty)
                      Text(
                        '電話：$_phone',
                        style: const TextStyle(fontSize: 14),
                      ),
                    if (_email.isNotEmpty)
                      Text(
                        'メール：$_email',
                        style: const TextStyle(fontSize: 14),
                      ),
                    const SizedBox(height: 8),
                  ],
                ),
              Row(
                children: [
                  TextButton.icon(
                    onPressed: _callTemple,
                    icon: const Icon(Icons.phone),
                    label: const Text('菩提寺に電話'),
                  ),
                  const SizedBox(width: 8),
                  TextButton.icon(
                    onPressed: _mailTemple,
                    icon: const Icon(Icons.mail),
                    label: const Text('菩提寺にメール'),
                  ),
                ],
              ),
              const Spacer(),
              const Align(
                alignment: Alignment.bottomRight,
                child: Text(
                  'タップで菩提寺情報を編集 ▶',
                  style: TextStyle(fontSize: 12, color: Colors.black54),
                ),
              ),
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
      title: const Text('菩提寺の情報登録'),
      content: SizedBox(
        width: 400,
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildTextField(
                  label: '寺の名前',
                  controller: _templeNameController,
                  hint: '例）正宗寺',
                  required: true,
                ),
                const SizedBox(height: 8),
                _buildTextField(
                  label: '宗派',
                  controller: _sectController,
                  hint: '例）臨済宗妙心寺派',
                ),
                const SizedBox(height: 8),
                _buildTextField(
                  label: '住所',
                  controller: _addressController,
                  hint: '例）愛媛県松山市◯◯◯',
                  maxLines: 2,
                ),
                const SizedBox(height: 8),
                _buildTextField(
                  label: '電話番号',
                  controller: _phoneController,
                  hint: '例）089-000-0000',
                ),
                const SizedBox(height: 8),
                _buildTextField(
                  label: 'メールアドレス',
                  controller: _emailController,
                  hint: '例）example@example.com',
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
    bool required = false,
    int maxLines = 1,
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
      validator: required
          ? (value) {
              if (value == null || value.trim().isEmpty) {
                return '$label を入力してください。';
              }
              return null;
            }
          : null,
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

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:shared_preferences/shared_preferences.dart';

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

/// 上部に出す「スマダンの使い方」テキスト
const String kSmadanHowToText = 'スマダンとは、スマートフォンの仏壇、略して「スマ壇」です。\n'
    '身近にお仏壇を感じていただき、少し気楽に供養していただけるように開発しました。\n'
    '通常のお仏壇ではできなかったことを、デジタルの力を使って実現していくことを目指しています。\n\n'
    '【スマダンの基本的な使い方】\n'
    '・ご本尊やご先祖さまのお位牌の画像を登録しておくことで、\n'
    '　外出先でも、手を合わせたいときにすぐ画面を開くことができます。\n'
    '・ご命日や年回忌、法事の日などに、スマダンを開いて合掌し、\n'
    '　お参りの気持ちをあらわすことができます。\n'
    '・複数人で同じ画面を見ながら、お参りの思い出を語り合うこともできます。\n\n'
    '【このアプリの考え方】\n'
    'スマダンは、あくまでも「本来のお仏壇やお寺のお参りを補うもの」です。\n'
    'ご自宅のお仏壇や菩提寺でのお参りを大切にしながら、\n'
    '日々の暮らしの中でも、ふとした時に手を合わせられるように、\n'
    'そっと寄り添う道具としてお使いください。';

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
      appBar: AppBar(
        title: const Text('NEWS'),
      ),
      body: SafeArea(
        child: _error != null
            ? _buildError()
            : LayoutBuilder(
                builder: (context, constraints) {
                  final isNarrow = constraints.maxWidth < 700;

                  return Column(
                    children: [
                      // 上 60%：スマダンの使い方＋NEWS一覧
                      Expanded(
                        flex: 6,
                        child: _buildTopFrame(),
                      ),
                      const Divider(height: 1),
                      // 下 40%：左 菩提寺情報、右 年回表
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

  Widget _buildTopFrame() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Padding(
      padding: const EdgeInsets.all(12),
      child: ListView(
        children: [
          const Text(
            'スマダンの使い方',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            kSmadanHowToText,
            style: TextStyle(fontSize: 16, height: 1.6),
          ),
          const SizedBox(height: 16),
          const Divider(),
          const SizedBox(height: 4),
          const Text(
            'お知らせ（NEWS）',
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

/// 下段 左：菩提寺情報
class TempleInfoPanel extends StatefulWidget {
  const TempleInfoPanel({super.key});

  @override
  State<TempleInfoPanel> createState() => _TempleInfoPanelState();
}

class _TempleInfoPanelState extends State<TempleInfoPanel> {
  final _formKey = GlobalKey<FormState>();

  final _templeNameController = TextEditingController();
  final _sectController = TextEditingController();
  final _addressController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();

  bool _loading = true;

  static const _keyTempleName = 'temple_name';
  static const _keySect = 'temple_sect';
  static const _keyAddress = 'temple_address';
  static const _keyPhone = 'temple_phone';
  static const _keyEmail = 'temple_email';

  @override
  void initState() {
    super.initState();
    _loadSavedData();
  }

  Future<void> _loadSavedData() async {
    final prefs = await SharedPreferences.getInstance();
    _templeNameController.text = prefs.getString(_keyTempleName) ?? '';
    _sectController.text = prefs.getString(_keySect) ?? '';
    _addressController.text = prefs.getString(_keyAddress) ?? '';
    _phoneController.text = prefs.getString(_keyPhone) ?? '';
    _emailController.text = prefs.getString(_keyEmail) ?? '';
    setState(() {
      _loading = false;
    });
  }

  Future<void> _saveData() async {
    if (!_formKey.currentState!.validate()) return;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyTempleName, _templeNameController.text.trim());
    await prefs.setString(_keySect, _sectController.text.trim());
    await prefs.setString(_keyAddress, _addressController.text.trim());
    await prefs.setString(_keyPhone, _phoneController.text.trim());
    await prefs.setString(_keyEmail, _emailController.text.trim());

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('菩提寺の情報を保存しました。')),
    );
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

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.orange.shade50,
      padding: const EdgeInsets.all(12),
      child: _loading
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '菩提寺の情報登録',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'ご家族が相談しやすいように、\nふだんお世話になっているお寺の情報を\nメモしておくことができます。',
                      style: TextStyle(fontSize: 14, height: 1.5),
                    ),
                    const SizedBox(height: 8),
                    _buildTextField(
                      label: '寺の名前',
                      controller: _templeNameController,
                      hint: '例）正宗寺',
                      required: true,
                    ),
                    const SizedBox(height: 6),
                    _buildTextField(
                      label: '宗派',
                      controller: _sectController,
                      hint: '例）臨済宗妙心寺派',
                    ),
                    const SizedBox(height: 6),
                    _buildTextField(
                      label: '住所',
                      controller: _addressController,
                      hint: '例）愛媛県松山市◯◯◯',
                    ),
                    const SizedBox(height: 6),
                    _buildTextField(
                      label: '電話番号',
                      controller: _phoneController,
                      hint: '例）089-000-0000',
                    ),
                    const SizedBox(height: 6),
                    _buildTextField(
                      label: 'メールアドレス',
                      controller: _emailController,
                      hint: '例）example@example.com',
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: _saveData,
                        child: const Text(
                          '保存',
                          style: TextStyle(fontSize: 16),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildTextField({
    required String label,
    required TextEditingController controller,
    String? hint,
    bool required = false,
  }) {
    return TextFormField(
      controller: controller,
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

/// 下段 右：年回早見表（HTMLのロジックを Dart に移植）
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

    return Container(
      color: Colors.blue.shade50,
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '年回法要 早見表',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            'ご命年（西暦）を入れると、今後の年回（1・3・7・13・17・25・33・50回忌）を自動計算します。\n（今年は $nowYear 年です）',
            style: const TextStyle(fontSize: 14, height: 1.5),
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
          const Text(
            '※今日以降に当たる年のみ表示します。',
            style: TextStyle(fontSize: 12, color: Colors.black54),
          ),
          const SizedBox(height: 4),
          Wrap(
            spacing: 4,
            runSpacing: 4,
            children: [
              const Text('クイック入力：', style: TextStyle(color: Colors.black54)),
              for (final y in [2018, 2019, 2020, 2021, 2022])
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
                        'ご命年を入力してください。',
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

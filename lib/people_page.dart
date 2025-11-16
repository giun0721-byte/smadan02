import 'dart:async';
import 'dart:convert'; // AssetManifest.json を読むため
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:csv/csv.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// SharedPreferences に保存するキー
const String _prefsKeyPeopleCsv = 'people_csv_v1';

class PeoplePage extends StatefulWidget {
  const PeoplePage({super.key});

  @override
  State<PeoplePage> createState() => _PeoplePageState();
}

class _PeoplePageState extends State<PeoplePage> {
  List<Person> _all = [];
  List<Person> _view = [];
  bool _loading = true;
  SortKey _sortKey = SortKey.nameAsc;

  @override
  void initState() {
    super.initState();
    _loadCsv();
  }

  /// CSVを読み込む
  /// 1. まずSharedPreferencesの保存データを読む
  /// 2. なければ assets/people.csv を読む
  Future<void> _loadCsv() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      String? csvStr = prefs.getString(_prefsKeyPeopleCsv);

      // 保存データがなければ assets から読む
      csvStr ??= await rootBundle.loadString('assets/people.csv');

      final rows = const CsvToListConverter(eol: '\n').convert(csvStr);

      if (rows.isEmpty) {
        setState(() {
          _all = [];
          _view = [];
          _loading = false;
        });
        return;
      }

      // ヘッダー判定
      final header = rows.first.map((e) => e.toString()).toList();
      final hasHeader = header.any((h) => [
            // 新ヘッダー候補
            '名前',
            'なまえ',
            '戒名',
            'かいみょう',
            '生年月日',
            '歿年月日',
            '享年',
            '続柄',
            '写真名1',
            '写真名2',
            '写真名3',
            '備考',
            // 旧ヘッダー互換
            'ふりがな',
            '没年月日',
          ].contains(h));

      final dataRows = hasHeader ? rows.skip(1) : rows;

      final people = <Person>[];
      for (final r in dataRows) {
        people.add(Person.fromRow(r));
      }

      _all = people;
      _sortAndShow();
    } catch (e) {
      _all = [];
      _view = [];
    } finally {
      setState(() {
        _loading = false;
      });
    }
  }

  /// 現在の _sortKey に従って全体をソートして画面に反映
  void _sortAndShow() {
    setState(() {
      _view = _sorted(List.of(_all), _sortKey);
    });
  }

  List<Person> _sorted(List<Person> list, SortKey key) {
    int cmp(String a, String b) => a.compareTo(b);
    switch (key) {
      case SortKey.nameAsc:
        list.sort((a, b) => cmp(a.name, b.name));
        break;
      case SortKey.nameDesc:
        list.sort((a, b) => cmp(b.name, a.name));
        break;
      case SortKey.dodDesc:
        list.sort((a, b) => cmp(b.dodSortable, a.dodSortable)); // 新しい歿→古い歿
        break;
      case SortKey.dobAsc:
        list.sort((a, b) => cmp(a.dobSortable, b.dobSortable)); // 古い生→新しい生
        break;
    }
    return list;
  }

  void _changeSort(SortKey key) {
    setState(() {
      _sortKey = key;
      _view = _sorted(List.of(_all), key);
    });
  }

  /// _all から CSV を生成して SharedPreferences に保存
  /// フォーマット:
  /// 名前,なまえ,戒名,かいみょう,生年月日,歿年月日,享年,続柄,写真名1,写真名2,写真名3,備考
  Future<void> _saveCsvToPrefs() async {
    final rows = <List<String>>[];

    // 新フォーマットのヘッダー（12列）
    rows.add([
      '名前',
      'なまえ',
      '戒名',
      'かいみょう',
      '生年月日',
      '歿年月日',
      '享年',
      '続柄',
      '写真名1',
      '写真名2',
      '写真名3',
      '備考',
    ]);

    for (final p in _all) {
      rows.add([
        p.name,
        p.nameKana,
        p.kainame,
        p.kainameKana,
        p.dob,
        p.dod,
        p.age,
        p.relation,
        p.photo1,
        p.photo2,
        p.photo3,
        p.note,
      ]);
    }

    final csvStr = const ListToCsvConverter(eol: '\n').convert(rows);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKeyPeopleCsv, csvStr);
  }

  /// 個人フォーム（追加・編集共通）をモバイル向けボトムシートで開く
  Future<Person?> _openPersonForm({Person? original}) async {
    return showModalBottomSheet<Person>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) {
        final nameCtrl = TextEditingController(text: original?.name ?? '');
        final nameKanaCtrl =
            TextEditingController(text: original?.nameKana ?? '');
        final kaiCtrl = TextEditingController(text: original?.kainame ?? '');
        final kaiKanaCtrl =
            TextEditingController(text: original?.kainameKana ?? '');
        final dobCtrl = TextEditingController(text: original?.dob ?? '');
        final dodCtrl = TextEditingController(text: original?.dod ?? '');
        final ageCtrl = TextEditingController(text: original?.age ?? '');
        final relCtrl = TextEditingController(text: original?.relation ?? '');
        final photo1Ctrl = TextEditingController(text: original?.photo1 ?? '');
        final photo2Ctrl = TextEditingController(text: original?.photo2 ?? '');
        final photo3Ctrl = TextEditingController(text: original?.photo3 ?? '');
        final noteCtrl = TextEditingController(text: original?.note ?? '');

        return Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 8,
            bottom: MediaQuery.of(context).viewInsets.bottom + 16,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 4),
                Text(
                  original == null ? '個人を追加' : '情報を編集',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 12),

                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(
                    labelText: '名前',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: 8),

                TextField(
                  controller: nameKanaCtrl,
                  decoration: const InputDecoration(
                    labelText: 'なまえ（ふりがな）',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: 8),

                TextField(
                  controller: kaiCtrl,
                  decoration: const InputDecoration(
                    labelText: '戒名',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: 8),

                TextField(
                  controller: kaiKanaCtrl,
                  decoration: const InputDecoration(
                    labelText: 'かいみょう（ふりがな）',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: 8),

                // 生年月日（タップで日付ピッカー）
                _DateField(
                  label: '生年月日',
                  controller: dobCtrl,
                  onPickDate: () async {
                    final s = await _pickDate(dobCtrl.text);
                    if (s != null) dobCtrl.text = s;
                  },
                ),
                const SizedBox(height: 8),

                // 歿年月日（タップで日付ピッカー）
                _DateField(
                  label: '歿年月日',
                  controller: dodCtrl,
                  onPickDate: () async {
                    final s = await _pickDate(dodCtrl.text);
                    if (s != null) dodCtrl.text = s;
                  },
                ),
                const SizedBox(height: 8),

                TextField(
                  controller: ageCtrl,
                  decoration: const InputDecoration(
                    labelText: '享年（例：歿年-生年+1）',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  keyboardType: TextInputType.number,
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: 8),

                TextField(
                  controller: relCtrl,
                  decoration: const InputDecoration(
                    labelText: '続柄',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: 12),

                // 写真ファイル名（portraitフォルダから自動一覧）
                _PhotoField(
                  label: '写真名1（assets/portrait/ 内）',
                  controller: photo1Ctrl,
                ),
                const SizedBox(height: 8),
                _PhotoField(
                  label: '写真名2（任意）',
                  controller: photo2Ctrl,
                ),
                const SizedBox(height: 8),
                _PhotoField(
                  label: '写真名3（任意）',
                  controller: photo3Ctrl,
                ),
                const SizedBox(height: 12),

                TextField(
                  controller: noteCtrl,
                  decoration: const InputDecoration(
                    labelText: '備考',
                    border: OutlineInputBorder(),
                    alignLabelWithHint: true,
                  ),
                  maxLines: 3,
                ),
                const SizedBox(height: 16),

                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(null),
                      child: const Text('キャンセル'),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: () {
                        // 名前・戒名が完全に空なら保存しない
                        if (nameCtrl.text.trim().isEmpty &&
                            kaiCtrl.text.trim().isEmpty) {
                          Navigator.of(context).pop(null);
                          return;
                        }
                        final p = Person(
                          name: nameCtrl.text.trim(),
                          nameKana: nameKanaCtrl.text.trim(),
                          kainame: kaiCtrl.text.trim(),
                          kainameKana: kaiKanaCtrl.text.trim(),
                          dob: dobCtrl.text.trim(),
                          dod: dodCtrl.text.trim(),
                          age: ageCtrl.text.trim(),
                          relation: relCtrl.text.trim(),
                          photo1: photo1Ctrl.text.trim(),
                          photo2: photo2Ctrl.text.trim(),
                          photo3: photo3Ctrl.text.trim(),
                          note: noteCtrl.text.trim(),
                        );
                        Navigator.of(context).pop(p);
                      },
                      child: const Text('保存'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// 個人追加
  Future<void> _addPerson() async {
    final person = await _openPersonForm();
    if (person != null) {
      setState(() {
        _all.add(person);
        _sortAndShow();
      });
      await _saveCsvToPrefs();
    }
  }

  /// 個人編集
  Future<void> _editPerson(Person p) async {
    final edited = await _openPersonForm(original: p);
    if (edited == null) return;

    setState(() {
      final idx = _all.indexOf(p);
      if (idx >= 0) {
        _all[idx] = edited;
        _sortAndShow();
      }
    });
    await _saveCsvToPrefs();
  }

  /// 個人削除（確認ダイアログ付き）
  Future<void> _deletePerson(Person p) async {
    final ok = await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('削除確認'),
            content: Text(
              '${p.name.isEmpty ? '(無名)' : p.name} を削除しますか？\n'
              '※CSVファイル（保存データ）からも削除されます。',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('キャンセル'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('削除'),
              ),
            ],
          ),
        ) ??
        false;

    if (!ok) return;

    setState(() {
      _all.remove(p);
      _sortAndShow();
    });
    await _saveCsvToPrefs();
  }

  /// 日付ピッカー（文字列 yyyy-MM-dd）
  Future<String?> _pickDate(String current) async {
    DateTime initial = DateTime.now();
    final parsed = _parseYmd(current);
    if (parsed != null) {
      initial = parsed;
    }

    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(1800),
      lastDate: DateTime(2100),
    );
    if (picked == null) return null;

    return _formatYmd(picked);
  }

  DateTime? _parseYmd(String s) {
    if (s.isEmpty) return null;
    try {
      final parts = s.split(RegExp(r'[-/.]'));
      if (parts.length < 3) return null;
      final y = int.parse(parts[0]);
      final m = int.parse(parts[1]);
      final d = int.parse(parts[2]);
      return DateTime(y, m, d);
    } catch (_) {
      return null;
    }
  }

  String _formatYmd(DateTime d) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${d.year.toString().padLeft(4, '0')}-${two(d.month)}-${two(d.day)}';
  }

  /// "YYYY-MM-DD" などの日付文字列を "yyyy年mm月dd日" に変換
  String _formatYmdJaFromString(String s) {
    final dt = _parseYmd(s);
    if (dt == null) return s; // パースできない場合は元の文字列をそのまま表示
    String two(int n) => n.toString().padLeft(2, '0');
    return '${dt.year}年${two(dt.month)}月${two(dt.day)}日';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      child: Column(
        children: [
          // ─────────────────────────────
          // 上部バー
          // 左：ソートメニュー（三本線）
          // 中央：ショートカットボタン群
          // ─────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 6),
            child: Row(
              children: [
                PopupMenuButton<SortKey>(
                  icon: const Icon(Icons.sort),
                  tooltip: '並び替えメニュー',
                  onSelected: _changeSort,
                  itemBuilder: (context) => const [
                    PopupMenuItem(
                      value: SortKey.nameAsc,
                      child: Text('名前昇順 (あ→)'),
                    ),
                    PopupMenuItem(
                      value: SortKey.nameDesc,
                      child: Text('名前降順 (→あ)'),
                    ),
                    PopupMenuItem(
                      value: SortKey.dodDesc,
                      child: Text('歿年月日 新しい順'),
                    ),
                    PopupMenuItem(
                      value: SortKey.dobAsc,
                      child: Text('生年月日 古い順'),
                    ),
                  ],
                ),
                Expanded(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _TopShortcutButton(
                        label: '＋追加',
                        onTap: _addPerson,
                      ),
                      const SizedBox(width: 8),
                      _TopShortcutButton(
                        label: '名前昇順',
                        onTap: () => _changeSort(SortKey.nameAsc),
                      ),
                      const SizedBox(width: 8),
                      _TopShortcutButton(
                        label: '歿年月日順',
                        onTap: () => _changeSort(SortKey.dodDesc),
                      ),
                      const SizedBox(width: 8),
                      _TopShortcutButton(
                        label: '生年月日順',
                        onTap: () => _changeSort(SortKey.dobAsc),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          if (_loading)
            const Expanded(
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_view.isEmpty)
            Expanded(
              child: Center(
                child: Text(
                  '表示できるデータがありません。\nassets/people.csv を確認するか、上の「＋追加」から登録してください。',
                  style: theme.textTheme.bodyMedium,
                  textAlign: TextAlign.center,
                ),
              ),
            )
          else
            Expanded(
              child: ListView.separated(
                itemCount: _view.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, i) {
                  final p = _view[i];
                  return ListTile(
                    leading: _PortraitThumb(photoPath: p.primaryPortraitPath),
                    title: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (p.nameKana.isNotEmpty)
                          Text(
                            p.nameKana,
                            style:
                                Theme.of(context).textTheme.bodySmall?.copyWith(
                                      fontSize: 11,
                                      color: Colors.grey[600],
                                    ),
                          ),
                        Text(
                          p.name.isEmpty ? '(無名)' : p.name,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ],
                    ),
                    subtitle: Text(_subtitleOf(p)),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit),
                          onPressed: () => _editPerson(p),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline),
                          onPressed: () => _deletePerson(p),
                        ),
                        const Icon(Icons.chevron_right),
                      ],
                    ),
                    onTap: () => _showDetail(p),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  /// 一覧に表示するサブタイトル
  /// 歿年月日（yyyy年mm月dd日）＋ 享年 ＋ 続柄
  String _subtitleOf(Person p) {
    final d = p.dod.isNotEmpty ? '歿: ${_formatYmdJaFromString(p.dod)}' : '';
    final a = p.age.isNotEmpty ? '享年: ${p.age}' : '';
    final r = p.relation.isNotEmpty ? '続柄: ${p.relation}' : '';
    final parts = [d, a, r].where((e) => e.isNotEmpty).toList();
    return parts.join(' / ');
  }

  void _showDetail(Person p) {
    final photos = p.portraitPaths;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.78,
          maxChildSize: 0.95,
          minChildSize: 0.5,
          builder: (context, scrollCtrl) {
            return SingleChildScrollView(
              controller: scrollCtrl,
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 写真ビュー
                  AspectRatio(
                    aspectRatio: 16 / 9,
                    child: _PortraitCarousel(photos: photos),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    p.name.isEmpty ? '(無名)' : p.name,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  if (p.nameKana.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text('なまえ：${p.nameKana}'),
                    ),
                  if (p.kainame.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text('戒名：${p.kainame}'),
                    ),
                  if (p.kainameKana.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text('かいみょう：${p.kainameKana}'),
                    ),
                  const SizedBox(height: 12),
                  _detailRow('生年月日', p.dob),
                  _detailRow('歿年月日', p.dod),
                  _detailRow('享年', p.age),
                  _detailRow('続柄', p.relation),
                  if (p.note.isNotEmpty) _detailRow('備考', p.note),
                  const SizedBox(height: 8),
                  Text(
                    'ポートレート保存先：assets/portrait/',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _detailRow(String label, String value) {
    if (value.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 88,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}

enum SortKey { nameAsc, nameDesc, dobAsc, dodDesc }

class Person {
  final String name; // 0: 名前
  final String nameKana; // 1: なまえ（ふりがな）
  final String kainame; // 2: 戒名
  final String kainameKana; // 3: かいみょう（ふりがな）
  final String dob; // 4: 生年月日
  final String dod; // 5: 歿年月日
  final String age; // 6: 享年
  final String relation; // 7: 続柄
  final String photo1; // 8: 写真名1
  final String photo2; // 9: 写真名2
  final String photo3; // 10: 写真名3
  final String note; // 11: 備考

  Person({
    required this.name,
    required this.nameKana,
    required this.kainame,
    required this.kainameKana,
    required this.dob,
    required this.dod,
    required this.age,
    required this.relation,
    required this.photo1,
    required this.photo2,
    required this.photo3,
    required this.note,
  });

  /// CSVの1行から Person を生成
  /// - 新フォーマット（12列: 名前,なまえ,戒名,かいみょう,生年月日,歿年月日,享年,続柄,写真1,写真2,写真3,備考）
  /// - 旧フォーマット（11列: 名前,ふりがな,戒名,生年月日,没年月日,享年,続柄,写真1,写真2,写真3,備考）
  /// - さらに古い 9列フォーマット（名前,戒名,生年月日,没年月日,続柄,写真1,写真2,写真3,備考）
  factory Person.fromRow(List<dynamic> row) {
    final cells = row.map((e) => e.toString().trim()).toList();

    // 新フォーマット（12列以上）
    if (cells.length >= 12) {
      return Person(
        name: cells[0],
        nameKana: cells[1],
        kainame: cells[2],
        kainameKana: cells[3],
        dob: cells[4],
        dod: cells[5],
        age: cells[6],
        relation: cells[7],
        photo1: cells[8],
        photo2: cells[9],
        photo3: cells[10],
        note: cells[11],
      );
    }

    // 旧11列フォーマット（ふりがな・没年月日）
    if (cells.length == 11) {
      return Person(
        name: cells[0],
        nameKana: cells[1],
        kainame: cells[2],
        kainameKana: '',
        dob: cells[3],
        dod: cells[4],
        age: cells[5],
        relation: cells[6],
        photo1: cells[7],
        photo2: cells[8],
        photo3: cells[9],
        note: cells[10],
      );
    }

    // さらに古い 9列フォーマット互換
    String get(int i) => (i < cells.length) ? cells[i] : '';
    return Person(
      name: get(0),
      nameKana: '',
      kainame: get(1),
      kainameKana: '',
      dob: get(2),
      dod: get(3),
      age: '',
      relation: get(4),
      photo1: get(5),
      photo2: get(6),
      photo3: get(7),
      note: get(8),
    );
  }

  bool matches(String q) {
    final query = q.toLowerCase();
    return [
      name,
      nameKana,
      kainame,
      kainameKana,
      dob,
      dod,
      age,
      relation,
      note,
    ].any((f) => f.toLowerCase().contains(query));
  }

  String get dobSortable => _dateSortable(dob, unknownAs: '99999999'); // 不明は末尾へ
  String get dodSortable => _dateSortable(dod, unknownAs: '00000000'); // 不明は先頭へ

  String _dateSortable(String s, {required String unknownAs}) {
    if (s.isEmpty) return unknownAs;
    final parts =
        s.split(RegExp(r'[-/.]')).map((e) => e.padLeft(2, '0')).toList();
    if (parts.isEmpty) return unknownAs;
    final y = parts[0].padLeft(4, '0');
    final m = parts.length > 1 ? parts[1].padLeft(2, '0') : '00';
    final d = parts.length > 2 ? parts[2].padLeft(2, '0') : '00';
    return '$y$m$d';
  }

  List<String> get portraitPaths {
    final list = <String>[];
    if (photo1.isNotEmpty) list.add('assets/portrait/$photo1');
    if (photo2.isNotEmpty) list.add('assets/portrait/$photo2');
    if (photo3.isNotEmpty) list.add('assets/portrait/$photo3');
    return list.isEmpty ? [''] : list; // 空フォールバック（安全に表示）
  }

  String get primaryPortraitPath => portraitPaths.first;
}

/// 上部ショートカットボタン（少し大きめ・可愛いサイズ）
class _TopShortcutButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _TopShortcutButton({
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        minimumSize: const Size(0, 36),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

/// 日付フィールド（タップで日付ピッカー）
class _DateField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final Future<void> Function() onPickDate;

  const _DateField({
    required this.label,
    required this.controller,
    required this.onPickDate,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPickDate,
      child: AbsorbPointer(
        child: TextField(
          controller: controller,
          decoration: InputDecoration(
            labelText: label,
            hintText: 'YYYY-MM-DD',
            border: const OutlineInputBorder(),
            isDense: true,
            suffixIcon: const Icon(Icons.calendar_today, size: 18),
          ),
        ),
      ),
    );
  }
}

/// 写真ファイル名入力 + portraitフォルダの中身を自動一覧
class _PhotoField extends StatelessWidget {
  final String label;
  final TextEditingController controller;

  const _PhotoField({
    required this.label,
    required this.controller,
  });

  Future<List<String>> _loadPortraitPaths() async {
    final manifestContent = await rootBundle.loadString('AssetManifest.json');
    final Map<String, dynamic> manifestMap = json.decode(manifestContent);

    final paths = manifestMap.keys
        .where((k) => k.startsWith('assets/portrait/'))
        .toList()
      ..sort();
    return paths;
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        isDense: true,
        suffixIcon: IconButton(
          icon: const Icon(Icons.folder_open),
          tooltip: 'portraitフォルダから選ぶ',
          onPressed: () async {
            final paths = await _loadPortraitPaths();
            if (paths.isEmpty) {
              showDialog(
                context: context,
                builder: (_) => AlertDialog(
                  title: const Text('画像が見つかりません'),
                  content: const Text(
                    'assets/portrait/ フォルダ内の画像が見つかりませんでした。\n'
                    'pubspec.yaml の assets 設定をご確認ください。',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(_).pop(),
                      child: const Text('OK'),
                    ),
                  ],
                ),
              );
              return;
            }

            final selected = await showModalBottomSheet<String>(
              context: context,
              showDragHandle: true,
              builder: (context) {
                return ListView(
                  shrinkWrap: true,
                  children: [
                    const ListTile(
                      title: Text('ファイル名を選択'),
                    ),
                    for (final path in paths)
                      ListTile(
                        leading: SizedBox(
                          width: 40,
                          height: 40,
                          child: _safeAssetImage(
                            path,
                            fit: BoxFit.cover,
                            fallbackIcon: Icons.image,
                          ),
                        ),
                        title: Text(path.split('/').last),
                        subtitle: Text(path),
                        onTap: () =>
                            Navigator.of(context).pop(path.split('/').last),
                      ),
                  ],
                );
              },
            );

            if (selected != null) {
              controller.text = selected; // ファイル名だけ入れる
            }
          },
        ),
      ),
    );
  }
}

/// サムネイル（存在しない場合もプレースホルダで安全に表示）
class _PortraitThumb extends StatelessWidget {
  final String photoPath;
  const _PortraitThumb({required this.photoPath});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: 48,
        height: 48,
        color: Colors.grey.shade300,
        child: _safeAssetImage(
          photoPath,
          fit: BoxFit.cover,
          fallbackIcon: Icons.person,
        ),
      ),
    );
  }
}

/// 横スワイプのカルーセル（左右矢印付き）
class _PortraitCarousel extends StatefulWidget {
  final List<String> photos;
  const _PortraitCarousel({required this.photos});

  @override
  State<_PortraitCarousel> createState() => _PortraitCarouselState();
}

class _PortraitCarouselState extends State<_PortraitCarousel> {
  final PageController _pc = PageController();
  // ★ ページ表示用のValueNotifier（1始まり）
  final ValueNotifier<int> _pageIndex = ValueNotifier<int>(1);

  @override
  void dispose() {
    _pc.dispose();
    _pageIndex.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final photos = widget.photos.where((p) => p.trim().isNotEmpty).toList();
    if (photos.isEmpty) {
      return _placeholderLarge(context);
    }
    return Stack(
      children: [
        PageView.builder(
          controller: _pc,
          itemCount: photos.length,
          onPageChanged: (i) => _pageIndex.value = i + 1, // ★ 1/件数 表示更新
          itemBuilder: (_, i) {
            return Container(
              color: Colors.black12,
              child: _safeAssetImage(
                photos[i],
                fit: BoxFit.contain,
                fallbackIcon: Icons.person,
              ),
            );
          },
        ),

        // ◀ 左矢印
        Positioned(
          left: 8,
          top: 0,
          bottom: 0,
          child: ValueListenableBuilder<int>(
            valueListenable: _pageIndex,
            builder: (_, idx, __) {
              if (photos.length <= 1) {
                return const SizedBox.shrink();
              }
              final canPrev = idx > 1;
              return Center(
                child: IconButton(
                  icon: const Icon(Icons.chevron_left, size: 32),
                  color: canPrev ? Colors.white : Colors.white38,
                  onPressed: canPrev
                      ? () {
                          _pc.previousPage(
                            duration: const Duration(milliseconds: 200),
                            curve: Curves.easeOut,
                          );
                        }
                      : null,
                ),
              );
            },
          ),
        ),

        // ▶ 右矢印
        Positioned(
          right: 8,
          top: 0,
          bottom: 0,
          child: ValueListenableBuilder<int>(
            valueListenable: _pageIndex,
            builder: (_, idx, __) {
              if (photos.length <= 1) {
                return const SizedBox.shrink();
              }
              final canNext = idx < photos.length;
              return Center(
                child: IconButton(
                  icon: const Icon(Icons.chevron_right, size: 32),
                  color: canNext ? Colors.white : Colors.white38,
                  onPressed: canNext
                      ? () {
                          _pc.nextPage(
                            duration: const Duration(milliseconds: 200),
                            curve: Curves.easeOut,
                          );
                        }
                      : null,
                ),
              );
            },
          ),
        ),

        // ページ数インジケータ「1 / N」
        Positioned(
          right: 8,
          bottom: 8,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: Colors.black54,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: ValueListenableBuilder<int>(
                valueListenable: _pageIndex,
                builder: (_, idx, __) {
                  final safeIdx = (idx <= 0 ? 1 : idx);
                  return Text(
                    '$safeIdx / ${photos.length}',
                    style: const TextStyle(color: Colors.white),
                  );
                },
              ),
            ),
          ),
        )
      ],
    );
  }

  Widget _placeholderLarge(BuildContext context) {
    return Container(
      color: Colors.grey.shade200,
      child: const Center(
        child: Icon(Icons.person, size: 64, color: Colors.grey),
      ),
    );
  }
}

/// アセット画像の例外安全読み込み（存在しない場合はアイコン表示）
Widget _safeAssetImage(
  String path, {
  BoxFit? fit,
  IconData fallbackIcon = Icons.image,
}) {
  if (path.isEmpty) {
    return Center(
      child: Icon(fallbackIcon, color: Colors.grey, size: 28),
    );
  }
  return Image.asset(
    path,
    fit: fit,
    errorBuilder: (_, __, ___) => Center(
      child: Icon(fallbackIcon, color: Colors.grey, size: 28),
    ),
  );
}

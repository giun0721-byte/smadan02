import 'dart:async';
import 'dart:convert'; // AssetManifest.json や Personの保存に使用

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:csv/csv.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// SharedPreferences に保存するキー
const String _prefsKeyPeopleCsv = 'people_csv_v1';

/// HOMEに表示する人のリスト（複数対応）
const String _prefsKeyHomePersonList = 'home_person_list_v1';

/// 旧バージョン互換用（単体保存）※あればリストに移行する
const String _prefsKeyHomePerson = 'home_person_v1';

class PeoplePage extends StatefulWidget {
  const PeoplePage({super.key});

  @override
  State<PeoplePage> createState() => _PeoplePageState();
}

class _PeoplePageState extends State<PeoplePage> {
  List<Person> _all = [];
  List<Person> _view = [];
  List<Person> _homeList = []; // ★HOMEに表示する人たち

  bool _loading = true;
  SortKey _sortKey = SortKey.nameAsc;

  /// ★ 個人タップ時に開いている詳細の対象（null なら閉じている）
  Person? _detailPerson;

  /// ★ 新規登録／編集フォーム用（オーバーレイ表示中なら Completer が非 null）
  Person? _formOriginal;
  Completer<Person?>? _formCompleter;

  @override
  void initState() {
    super.initState();
    _loadCsv();
    _loadHomeList();
  }

  /// HOME用リストを読み込み（旧1人保存データがあれば移行）
  Future<void> _loadHomeList() async {
    final prefs = await SharedPreferences.getInstance();
    final listStr = prefs.getString(_prefsKeyHomePersonList);

    if (listStr != null) {
      try {
        final raw = jsonDecode(listStr) as List;
        setState(() {
          _homeList = raw.map((e) => Person.fromJson(e)).toList();
        });
        return;
      } catch (_) {
        // 失敗したら後で再保存されるので、ひとまず無視
      }
    }

    // 旧データ（単体）から移行
    final singleStr = prefs.getString(_prefsKeyHomePerson);
    if (singleStr != null) {
      try {
        final map = jsonDecode(singleStr) as Map<String, dynamic>;
        final p = Person.fromJson(map);
        setState(() {
          _homeList = [p];
        });
        await prefs.setString(
          _prefsKeyHomePersonList,
          jsonEncode(_homeList.map((e) => e.toJson()).toList()),
        );
      } catch (_) {}
    }
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
      case SortKey.dodDesc: // 歿年月日 新しい順
        list.sort((a, b) => cmp(b.dodSortable, a.dodSortable));
        break;
      case SortKey.dodAsc: // 歿年月日 古い順
        list.sort((a, b) => cmp(a.dodSortable, b.dodSortable));
        break;
      case SortKey.dobAsc: // 生年月日 古い順
        list.sort((a, b) => cmp(a.dobSortable, b.dobSortable));
        break;
      case SortKey.dobDesc: // 生年月日 新しい順
        list.sort((a, b) => cmp(b.dobSortable, a.dobSortable));
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

  /// 個人フォーム（追加・編集共通）を PeoplePage 内オーバーレイで開く
  Future<Person?> _openPersonForm({Person? original}) {
    final completer = Completer<Person?>();
    setState(() {
      _formOriginal = original;
      _formCompleter = completer;
    });
    return completer.future;
  }

  /// フォームオーバーレイを閉じて、Future を完了させる
  void _closePersonForm(Person? result) {
    final completer = _formCompleter;
    setState(() {
      _formCompleter = null;
      _formOriginal = null;
    });
    if (completer != null && !completer.isCompleted) {
      completer.complete(result);
    }
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

  /// 個人編集（編集後の Person? を返す）
  Future<Person?> _editPerson(Person original) async {
    final edited = await _openPersonForm(original: original);
    if (edited == null) return null;

    setState(() {
      final idx = _all.indexOf(original);
      if (idx >= 0) {
        _all[idx] = edited;
        _sortAndShow();
      }
    });
    await _saveCsvToPrefs();

    // HOMEリストも更新（同一人物を置き換え）
    final idxHome = _homeList.indexWhere((hp) => hp.isSamePerson(original));
    if (idxHome >= 0) {
      _homeList[idxHome] = edited;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _prefsKeyHomePersonList,
        jsonEncode(_homeList.map((e) => e.toJson()).toList()),
      );
    }

    return edited;
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

    // HOMEリストからも削除
    _homeList.removeWhere((hp) => hp.isSamePerson(p));
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _prefsKeyHomePersonList,
      jsonEncode(_homeList.map((e) => e.toJson()).toList()),
    );
  }

  /// HOME表示トグル（true=現在HOMEなので外す／false=HOMEに追加）
  Future<void> _toggleHomePerson(Person p, bool isCurrentlyHome) async {
    final prefs = await SharedPreferences.getInstance();

    setState(() {
      if (isCurrentlyHome) {
        _homeList.removeWhere((hp) => hp.isSamePerson(p));
      } else {
        // 重複防止
        if (!_homeList.any((hp) => hp.isSamePerson(p))) {
          _homeList.add(p);
        }
      }
    });

    await prefs.setString(
      _prefsKeyHomePersonList,
      jsonEncode(_homeList.map((e) => e.toJson()).toList()),
    );

    if (!mounted) return;
    final name = p.name.isEmpty ? '(無名)' : p.name;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          isCurrentlyHome ? '$name をHOME表示から外しました' : '$name をHOME表示に追加しました',
        ),
      ),
    );
  }

  /// ロングタップ時：そのまま削除確認ダイアログへ（下からのシートはやめる）
  Future<void> _onLongPressPerson(Person p) async {
    await _deletePerson(p);
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
      locale: const Locale('ja', 'JP'), // ★ カレンダーを日本語ロケールで表示
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

  /// "YYYY-MM-DD" などの日付文字列を "yyyy年mm月dd日" に変換（西暦）
  String _formatYmdJaFromString(String s) {
    final dt = _parseYmd(s);
    if (dt == null) return s; // パースできない場合は元の文字列をそのまま表示
    String two(int n) => n.toString().padLeft(2, '0');
    return '${dt.year}年${two(dt.month)}月${two(dt.day)}日';
  }

  /// "YYYY-MM-DD" を 和暦 (令和/平成/昭和/大正/明治) に変換
  /// 例: 1995-03-10 → 平成7年3月10日
  /// 対象外の年はそのまま西暦和文表示にフォールバック
  String _formatYmdWarekiFromString(String s) {
    final dt = _parseYmd(s);
    if (dt == null) return s;

    final d = dt;
    final reiwaStart = DateTime(2019, 5, 1);
    final heiseiStart = DateTime(1989, 1, 8);
    final showaStart = DateTime(1926, 12, 25);
    final taishoStart = DateTime(1912, 7, 30);
    final meijiStart = DateTime(1868, 1, 25);

    String era;
    int eraYear;

    if (!d.isBefore(reiwaStart)) {
      era = '令和';
      eraYear = d.year - 2018; // 2019年=令和1年
    } else if (!d.isBefore(heiseiStart)) {
      era = '平成';
      eraYear = d.year - 1988; // 1989年=平成1年
    } else if (!d.isBefore(showaStart)) {
      era = '昭和';
      eraYear = d.year - 1925; // 1926年=昭和1年
    } else if (!d.isBefore(taishoStart)) {
      era = '大正';
      eraYear = d.year - 1911; // 1912年=大正1年
    } else if (!d.isBefore(meijiStart)) {
      era = '明治';
      eraYear = d.year - 1867; // 1868年=明治1年
    } else {
      // それ以前は西暦和文にフォールバック
      return _formatYmdJaFromString(s);
    }

    final yearStr = (eraYear == 1) ? '元年' : '$eraYear年';
    return '$era$yearStr${d.month}月${d.day}日';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      child: Stack(
        children: [
          // 下地は従来どおり Column で一覧を表示
          Column(
            children: [
              // ─────────────────────────────
              // 上部バー
              // 左：メニューボタン（三本線）
              // 右：「＋追加登録」ボタン
              // ─────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 6),
                child: Row(
                  children: [
                    PopupMenuButton<SortKey>(
                      icon: const Icon(Icons.menu),
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
                          value: SortKey.dodAsc,
                          child: Text('歿年月日 古い順'),
                        ),
                        PopupMenuItem(
                          value: SortKey.dobAsc,
                          child: Text('生年月日 古い順'),
                        ),
                        PopupMenuItem(
                          value: SortKey.dobDesc,
                          child: Text('生年月日 新しい順'),
                        ),
                      ],
                    ),
                    const SizedBox(width: 8),
                    _TopShortcutButton(
                      label: '＋追加登録',
                      onTap: _addPerson,
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
                      '表示できるデータがありません。\nassets/people.csv を確認するか、上の「＋追加登録」から登録してください。',
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

                      // 和暦の歿年月日（Chipの表示テキスト）
                      final dodTextWareki = p.dod.isNotEmpty
                          ? '${_formatYmdWarekiFromString(p.dod)}歿'
                          : '';

                      // ★ 命日／月命日判定
                      bool isMeinichi = false;
                      bool isTsukiMeinichi = false;

                      final dodDate = _parseYmd(p.dod);
                      if (dodDate != null) {
                        final today = DateTime.now();
                        final sameMonth = today.month == dodDate.month;
                        final sameDay = today.day == dodDate.day;

                        if (sameMonth && sameDay) {
                          // 年は問わず、月日が同じ → 命日
                          isMeinichi = true;
                        } else if (sameDay) {
                          // 日だけ同じ → 月命日
                          isTsukiMeinichi = true;
                        }
                      }

                      final bool isHome =
                          _homeList.any((hp) => hp.isSamePerson(p));

                      return ListTile(
                        leading: _PortraitThumb(
                          photoPath: p.primaryPortraitPath,
                          isHome: isHome, // ★HOMEなら太丸
                        ),

                        // 一覧1行のメインレイアウト
                        title: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // 左：ふりがな＋名前（縦並び）
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (p.nameKana.isNotEmpty)
                                    Text(
                                      p.nameKana,
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.copyWith(
                                            fontSize: 11,
                                            color: Colors.grey[600],
                                          ),
                                    ),
                                  Text(
                                    p.name.isEmpty ? '(無名)' : p.name,
                                    style:
                                        Theme.of(context).textTheme.titleMedium,
                                  ),
                                ],
                              ),
                            ),

                            // 右：歿年月日チップ
                            if (dodTextWareki.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(left: 8, top: 2),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: isMeinichi
                                        ? Colors.redAccent // 命日
                                        : isTsukiMeinichi
                                            ? Colors.orangeAccent // 月命日
                                            : Colors.grey.shade300, // 通常
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    dodTextWareki,
                                    style: TextStyle(
                                      fontSize: 13, // 少し大きめ
                                      color: (isMeinichi || isTsukiMeinichi)
                                          ? Colors.white
                                          : Colors.black87,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),

                        subtitle: null, // 備考などは一覧では非表示

                        onTap: () => _showDetail(p),
                        onLongPress: () => _onLongPressPerson(p),
                      );
                    },
                  ),
                ),
            ],
          ),

          // ★ 個人詳細のオーバーレイ
          if (_detailPerson != null) _buildDetailOverlay(),

          // ★ 個人フォーム（新規／編集）のオーバーレイ
          if (_formCompleter != null) _buildPersonFormOverlay(),
        ],
      ),
    );
  }

  /// 個人タップ → 詳細オーバーレイを開く
  void _showDetail(Person p) {
    setState(() {
      _detailPerson = p;
    });
  }

  /// 詳細を閉じる
  void _closeDetail() {
    setState(() {
      _detailPerson = null;
    });
  }

  /// 個人詳細のオーバーレイ本体
  Widget _buildDetailOverlay() {
    final p = _detailPerson!;
    final photos = p.portraitPaths;
    final theme = Theme.of(context);

    final bornText =
        p.dob.isNotEmpty ? '${_formatYmdJaFromString(p.dob)}生' : '';
    final diedText =
        p.dod.isNotEmpty ? '${_formatYmdJaFromString(p.dod)}歿' : '';
    final isHome = _homeList.any((hp) => hp.isSamePerson(p));

    return _BottomSheetOverlay(
      onClosed: _closeDetail,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        child: Column(
          children: [
            // 一番外枠右上の × ボタン
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: _closeDetail,
                ),
              ],
            ),

            // 名前・ふりがな・続柄
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 左：ふりがなつき名前
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (p.nameKana.isNotEmpty)
                          Text(
                            p.nameKana,
                            style: theme.textTheme.bodySmall?.copyWith(
                              fontSize: 12,
                              color: Colors.grey[700],
                            ),
                          ),
                        Text(
                          p.name.isEmpty ? '(無名)' : p.name,
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                            fontSize: 24,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // 右：続柄（テキスト）
                  if (p.relation.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(left: 8, top: 4),
                      child: Text(
                        p.relation,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: Colors.grey[800],
                        ),
                      ),
                    ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // 写真部分
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: _PortraitCarousel(photos: photos),
                ),
              ),
            ),

            const SizedBox(height: 12),

            // 下部の情報（戒名＋享年 → 生没年月日 → 備考 → ボタン）
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 8,
                vertical: 8,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ふりがなつき戒名（左）＋ 右に享年
                  if (p.kainameKana.isNotEmpty ||
                      p.kainame.isNotEmpty ||
                      p.age.isNotEmpty)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (p.kainameKana.isNotEmpty)
                                Text(
                                  p.kainameKana,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    fontSize: 12,
                                    color: Colors.grey[700],
                                  ),
                                ),
                              if (p.kainame.isNotEmpty)
                                Text(
                                  p.kainame,
                                  style: theme.textTheme.bodyMedium
                                      ?.copyWith(fontSize: 18),
                                ),
                            ],
                          ),
                        ),
                        if (p.age.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(left: 8, top: 4),
                            child: Text(
                              '享年${p.age}才',
                              style: theme.textTheme.bodyMedium
                                  ?.copyWith(fontSize: 15),
                            ),
                          ),
                      ],
                    ),

                  const SizedBox(height: 8),

                  // 生年月日と歿年月日
                  if (bornText.isNotEmpty || diedText.isNotEmpty)
                    Text(
                      [
                        bornText,
                        diedText,
                      ].where((e) => e.isNotEmpty).join(' 〜 '),
                      style: theme.textTheme.bodyMedium?.copyWith(fontSize: 15),
                    ),

                  const SizedBox(height: 8),

                  // 備考
                  if (p.note.isNotEmpty)
                    Text(
                      p.note,
                      style: theme.textTheme.bodyMedium,
                    ),

                  const SizedBox(height: 16),

                  // ★ HOMEに表示ボタン + 編集ボタン
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      // 編集ボタン（編集後／キャンセル後に詳細を再度表示）
                      OutlinedButton.icon(
                        icon: const Icon(Icons.edit),
                        label: const Text('編集'),
                        onPressed: () async {
                          final target = p; // 編集開始時の Person
                          _closeDetail(); // いったん詳細を閉じる

                          final edited = await _editPerson(target);

                          if (!mounted) return;

                          if (edited != null) {
                            // 保存された場合：編集後の内容で詳細を再表示
                            _showDetail(edited);
                          } else {
                            // キャンセルされた場合：元の内容で詳細を再表示
                            _showDetail(target);
                          }
                        },
                      ),

                      const SizedBox(width: 8),
                      ElevatedButton.icon(
                        icon: Icon(
                          isHome ? Icons.home : Icons.home_outlined,
                        ),
                        label: Text(
                          isHome ? 'HOME表示をやめる' : 'HOMEに表示',
                        ),
                        onPressed: () async {
                          await _toggleHomePerson(p, isHome);
                          if (mounted) {
                            _closeDetail();
                          }
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 個人フォームのオーバーレイ
  Widget _buildPersonFormOverlay() {
    return _BottomSheetOverlay(
      onClosed: () => _closePersonForm(null), // 背景タップやスワイプでキャンセル扱い
      child: _PersonFormSheet(
        original: _formOriginal,
        onFinished: _closePersonForm,
        pickDate: _pickDate,
      ),
    );
  }
}

/// 並び替えキー
enum SortKey {
  nameAsc,
  nameDesc,
  dobAsc,
  dobDesc,
  dodAsc,
  dodDesc,
}

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

  /// HOME保存用
  Map<String, dynamic> toJson() => {
        'name': name,
        'nameKana': nameKana,
        'kainame': kainame,
        'kainameKana': kainameKana,
        'dob': dob,
        'dod': dod,
        'age': age,
        'relation': relation,
        'photo1': photo1,
        'photo2': photo2,
        'photo3': photo3,
        'note': note,
      };

  factory Person.fromJson(Map<String, dynamic> json) => Person(
        name: (json['name'] ?? '') as String,
        nameKana: (json['nameKana'] ?? '') as String,
        kainame: (json['kainame'] ?? '') as String,
        kainameKana: (json['kainameKana'] ?? '') as String,
        dob: (json['dob'] ?? '') as String,
        dod: (json['dod'] ?? '') as String,
        age: (json['age'] ?? '') as String,
        relation: (json['relation'] ?? '') as String,
        photo1: (json['photo1'] ?? '') as String,
        photo2: (json['photo2'] ?? '') as String,
        photo3: (json['photo3'] ?? '') as String,
        note: (json['note'] ?? '') as String,
      );

  /// CSVの1行から Person を生成
  /// - 新フォーマット（12列: 名前,なまえ,戒名,かいみょう,生年月日,歿年月日,享年,続柄,写真1,写真2,写真3,備考）
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

  /// assets/portrait 配下の画像パスに変換
  List<String> get portraitPaths {
    final list = <String>[];
    if (photo1.isNotEmpty) list.add('assets/portrait/$photo1');
    if (photo2.isNotEmpty) list.add('assets/portrait/$photo2');
    if (photo3.isNotEmpty) list.add('assets/portrait/$photo3');
    return list.isEmpty ? [''] : list; // 空フォールバック（安全に表示）
  }

  String get primaryPortraitPath => portraitPaths.first;

  /// 「同一人物かどうか」の判定（HOMEリスト用）
  bool isSamePerson(Person other) => name == other.name && dob == other.dob;
}

/// 上部ショートカットボタン（＋追加登録 用）
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

/// 写真ファイル名入力 + portraitフォルダの中身を自動一覧（assets 専用）
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
          tooltip: 'assets/portrait/ から選ぶ',
          onPressed: () async {
            final paths = await _loadPortraitPaths();
            if (paths.isEmpty) {
              // ignore: use_build_context_synchronously
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

            // ignore: use_build_context_synchronously
            final selected = await showModalBottomSheet<String>(
              context: context,
              showDragHandle: true,
              useRootNavigator: true,
              builder: (context) {
                return SafeArea(
                  bottom: true,
                  child: ListView(
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
                  ),
                );
              },
            );

            if (selected != null) {
              controller.text = selected; // ファイル名だけ入れる
            }
          },
        ),
      ),
      textInputAction: TextInputAction.next,
    );
  }
}

/// 丸型サムネイル（HOMEの人は太丸枠）
class _PortraitThumb extends StatelessWidget {
  final String photoPath;
  final bool isHome;

  const _PortraitThumb({
    required this.photoPath,
    required this.isHome,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 52,
      height: 52,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: isHome ? Colors.orangeAccent : Colors.grey.shade400,
          width: isHome ? 4 : 1, // ★HOMEは太丸
        ),
      ),
      child: ClipOval(
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

/// =======================
/// 個人フォームの中身（新規／編集共通）
/// =======================
class _PersonFormSheet extends StatefulWidget {
  final Person? original;
  final void Function(Person?) onFinished;
  final Future<String?> Function(String current) pickDate;

  const _PersonFormSheet({
    required this.original,
    required this.onFinished,
    required this.pickDate,
  });

  @override
  State<_PersonFormSheet> createState() => _PersonFormSheetState();
}

class _PersonFormSheetState extends State<_PersonFormSheet> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _nameKanaCtrl;
  late final TextEditingController _kaiCtrl;
  late final TextEditingController _kaiKanaCtrl;
  late final TextEditingController _dobCtrl;
  late final TextEditingController _dodCtrl;
  late final TextEditingController _ageCtrl;
  late final TextEditingController _relCtrl;
  late final TextEditingController _photo1Ctrl;
  late final TextEditingController _photo2Ctrl;
  late final TextEditingController _photo3Ctrl;
  late final TextEditingController _noteCtrl;

  @override
  void initState() {
    super.initState();
    final o = widget.original;
    _nameCtrl = TextEditingController(text: o?.name ?? '');
    _nameKanaCtrl = TextEditingController(text: o?.nameKana ?? '');
    _kaiCtrl = TextEditingController(text: o?.kainame ?? '');
    _kaiKanaCtrl = TextEditingController(text: o?.kainameKana ?? '');
    _dobCtrl = TextEditingController(text: o?.dob ?? '');
    _dodCtrl = TextEditingController(text: o?.dod ?? '');
    _ageCtrl = TextEditingController(text: o?.age ?? '');
    _relCtrl = TextEditingController(text: o?.relation ?? '');
    _photo1Ctrl = TextEditingController(text: o?.photo1 ?? '');
    _photo2Ctrl = TextEditingController(text: o?.photo2 ?? '');
    _photo3Ctrl = TextEditingController(text: o?.photo3 ?? '');
    _noteCtrl = TextEditingController(text: o?.note ?? '');
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _nameKanaCtrl.dispose();
    _kaiCtrl.dispose();
    _kaiKanaCtrl.dispose();
    _dobCtrl.dispose();
    _dodCtrl.dispose();
    _ageCtrl.dispose();
    _relCtrl.dispose();
    _photo1Ctrl.dispose();
    _photo2Ctrl.dispose();
    _photo3Ctrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  /// 生年月日と歿年月日から享年を自動計算してフィールドに反映
  /// 条件:
  /// - 生年月日・歿年月日が両方入っている
  /// - 年だけ取り出せる形式 (YYYY-MM-DD / YYYY/MM/DD / YYYY.MM.DD)
  /// → 歿年 - 生年 + 1 の結果を _ageCtrl にセット
  void _autoFillAgeIfPossible() {
    final dobText = _dobCtrl.text.trim();
    final dodText = _dodCtrl.text.trim();
    if (dobText.isEmpty || dodText.isEmpty) return;

    int? parseYear(String s) {
      final parts = s.split(RegExp(r'[-/.]'));
      if (parts.isEmpty) return null;
      return int.tryParse(parts[0]);
    }

    final birthYear = parseYear(dobText);
    final deathYear = parseYear(dodText);

    if (birthYear == null || deathYear == null) return;
    if (deathYear < birthYear) return;

    final calcAge = deathYear - birthYear + 1; // 満年齢ではなく数え年
    setState(() {
      _ageCtrl.text = calcAge.toString();
    });
  }

  Future<void> _onPickDob() async {
    final s = await widget.pickDate(_dobCtrl.text);
    if (s != null) {
      setState(() {
        _dobCtrl.text = s;
      });
      // 日付が確定したタイミングで享年自動計算
      _autoFillAgeIfPossible();
    }
  }

  Future<void> _onPickDod() async {
    final s = await widget.pickDate(_dodCtrl.text);
    if (s != null) {
      setState(() {
        _dodCtrl.text = s;
      });
      // 日付が確定したタイミングで享年自動計算
      _autoFillAgeIfPossible();
    }
  }

  void _onSave() {
    // 名前・戒名が完全に空なら保存しない（キャンセルと同じ扱い）
    if (_nameCtrl.text.trim().isEmpty && _kaiCtrl.text.trim().isEmpty) {
      widget.onFinished(null);
      return;
    }

    // ★ 保存時にも保険として同じロジックを残しておく
    String ageText = _ageCtrl.text.trim();
    final dobText = _dobCtrl.text.trim();
    final dodText = _dodCtrl.text.trim();

    if (ageText.isEmpty && dobText.isNotEmpty && dodText.isNotEmpty) {
      int? parseYear(String s) {
        final parts = s.split(RegExp(r'[-/.]'));
        if (parts.isEmpty) return null;
        return int.tryParse(parts[0]);
      }

      final birthYear = parseYear(dobText);
      final deathYear = parseYear(dodText);

      if (birthYear != null && deathYear != null && deathYear >= birthYear) {
        final calcAge = deathYear - birthYear + 1;
        ageText = calcAge.toString();
        _ageCtrl.text = ageText;
      }
    }

    final p = Person(
      name: _nameCtrl.text.trim(),
      nameKana: _nameKanaCtrl.text.trim(),
      kainame: _kaiCtrl.text.trim(),
      kainameKana: _kaiKanaCtrl.text.trim(),
      dob: dobText,
      dod: dodText,
      age: ageText,
      relation: _relCtrl.text.trim(),
      photo1: _photo1Ctrl.text.trim(),
      photo2: _photo2Ctrl.text.trim(),
      photo3: _photo3Ctrl.text.trim(),
      note: _noteCtrl.text.trim(),
    );
    widget.onFinished(p);
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.original != null;
    final theme = Theme.of(context);

    return SafeArea(
      bottom: true,
      child: Padding(
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
              // 上部：タイトル＋閉じる
              Row(
                children: [
                  Expanded(
                    child: Text(
                      isEdit ? '情報を編集' : '個人を追加',
                      style: theme.textTheme.titleMedium,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => widget.onFinished(null),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              TextField(
                controller: _nameCtrl,
                decoration: const InputDecoration(
                  labelText: '名前',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 8),

              TextField(
                controller: _nameKanaCtrl,
                decoration: const InputDecoration(
                  labelText: 'なまえ（ふりがな）',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 8),

              TextField(
                controller: _kaiCtrl,
                decoration: const InputDecoration(
                  labelText: '戒名',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 8),

              TextField(
                controller: _kaiKanaCtrl,
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
                controller: _dobCtrl,
                onPickDate: _onPickDob,
              ),
              const SizedBox(height: 8),

              // 歿年月日（タップで日付ピッカー）
              _DateField(
                label: '歿年月日',
                controller: _dodCtrl,
                onPickDate: _onPickDod,
              ),
              const SizedBox(height: 8),

              TextField(
                controller: _ageCtrl,
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
                controller: _relCtrl,
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
                controller: _photo1Ctrl,
              ),
              const SizedBox(height: 8),
              _PhotoField(
                label: '写真名2（任意）',
                controller: _photo2Ctrl,
              ),
              const SizedBox(height: 8),
              _PhotoField(
                label: '写真名3（任意）',
                controller: _photo3Ctrl,
              ),
              const SizedBox(height: 12),

              TextField(
                controller: _noteCtrl,
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
                    onPressed: () => widget.onFinished(null),
                    child: const Text('キャンセル'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: _onSave,
                    child: const Text('保存'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// =======================
/// ページ内ボトムシート用ウィジェット
/// =======================

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

/// 共通の下からシート枠
class _BottomSheetFrame extends StatelessWidget {
  final Widget child;

  const _BottomSheetFrame({required this.child});

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final height = media.size.height * 0.8; // 全体の約8割

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

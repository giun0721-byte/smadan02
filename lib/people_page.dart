import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:csv/csv.dart';

class PeoplePage extends StatefulWidget {
  const PeoplePage({super.key});

  @override
  State<PeoplePage> createState() => _PeoplePageState();
}

class _PeoplePageState extends State<PeoplePage> {
  final TextEditingController _searchCtrl = TextEditingController();
  List<Person> _all = [];
  List<Person> _view = [];
  bool _loading = true;
  SortKey _sortKey = SortKey.nameAsc;

  @override
  void initState() {
    super.initState();
    _loadCsv();
    _searchCtrl.addListener(_applyFilter);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadCsv() async {
    try {
      final csvStr = await rootBundle.loadString('assets/people.csv');
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
            '名前',
            '戒名',
            '生年月日',
            '没年月日',
            '続柄',
            '写真名1',
            '写真名2',
            '写真名3',
            '備考'
          ].contains(h));

      final dataRows = hasHeader ? rows.skip(1) : rows;

      final people = <Person>[];
      for (final r in dataRows) {
        // 可変長にも対応（短いときは空文字補完）
        final cells = List.generate(
            9, (i) => (i < r.length ? r[i] : '').toString().trim());
        people.add(Person.fromList(cells));
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

  void _applyFilter() {
    final q = _searchCtrl.text.trim();
    List<Person> filtered;
    if (q.isEmpty) {
      filtered = List.of(_all);
    } else {
      filtered = _all.where((p) => p.matches(q)).toList();
    }
    setState(() {
      _view = _sorted(filtered, _sortKey);
    });
  }

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
        list.sort((a, b) => cmp(b.dodSortable, a.dodSortable)); // 新しい没→古い没
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
      _view = _sorted(List.of(_view), key);
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      child: Column(
        children: [
          // 検索バー + 並び替え
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 6),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchCtrl,
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.search),
                      hintText: '検索：名前 / 戒名 / 続柄 / 備考',
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12)),
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                PopupMenuButton<SortKey>(
                  icon: const Icon(Icons.sort),
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
                      child: Text('没年月日 新しい順'),
                    ),
                    PopupMenuItem(
                      value: SortKey.dobAsc,
                      child: Text('生年月日 古い順'),
                    ),
                  ],
                )
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
                  '表示できるデータがありません。\nassets/people.csv を確認してください。',
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
                    title: Text(p.name.isEmpty ? '(無名)' : p.name),
                    subtitle: Text(_subtitleOf(p)),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => _showDetail(p),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  String _subtitleOf(Person p) {
    final b = p.dob.isNotEmpty ? '生: ${p.dob}' : '';
    final d = p.dod.isNotEmpty ? '没: ${p.dod}' : '';
    final r = p.relation.isNotEmpty ? '続柄: ${p.relation}' : '';
    final parts = [b, d, r].where((e) => e.isNotEmpty).toList();
    return parts.isEmpty
        ? (p.kainame.isNotEmpty ? '戒名: ${p.kainame}' : '')
        : parts.join(' / ');
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
                  if (p.kainame.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text('戒名：${p.kainame}'),
                    ),
                  const SizedBox(height: 12),
                  _detailRow('生年月日', p.dob),
                  _detailRow('没年月日', p.dod),
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
              child: Text(label,
                  style: const TextStyle(fontWeight: FontWeight.bold))),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}

enum SortKey { nameAsc, nameDesc, dobAsc, dodDesc }

class Person {
  final String name; // 0: 名前
  final String kainame; // 1: 戒名
  final String dob; // 2: 生年月日
  final String dod; // 3: 没年月日
  final String relation; // 4: 続柄
  final String photo1; // 5: 写真名1
  final String photo2; // 6: 写真名2
  final String photo3; // 7: 写真名3
  final String note; // 8: 備考

  Person({
    required this.name,
    required this.kainame,
    required this.dob,
    required this.dod,
    required this.relation,
    required this.photo1,
    required this.photo2,
    required this.photo3,
    required this.note,
  });

  factory Person.fromList(List<String> cells) {
    return Person(
      name: cells[0],
      kainame: cells[1],
      dob: cells[2],
      dod: cells[3],
      relation: cells[4],
      photo1: cells[5],
      photo2: cells[6],
      photo3: cells[7],
      note: cells[8],
    );
  }

  bool matches(String q) {
    final query = q.toLowerCase();
    return [
      name,
      kainame,
      dob,
      dod,
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
        child: _safeAssetImage(photoPath,
            fit: BoxFit.cover, fallbackIcon: Icons.person),
      ),
    );
  }
}

/// 横スワイプの簡易カルーセル
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
              child: _safeAssetImage(photos[i],
                  fit: BoxFit.contain, fallbackIcon: Icons.person),
            );
          },
        ),
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
Widget _safeAssetImage(String path,
    {BoxFit? fit, IconData fallbackIcon = Icons.image}) {
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

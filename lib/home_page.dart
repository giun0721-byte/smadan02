import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import 'package:video_player/video_player.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'people_page.dart' show Person;
import 'app_state.dart';

/// PeoplePage と合わせる（複数 HOME 対応）
const String _prefsKeyHomePersonList = 'home_person_list_v1';

/// 旧バージョン互換：単体 HOME キー（あればリストに取り込む）
const String _prefsKeyHomePerson = 'home_person_v1';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  double _startScale = 1.0;

  // HOMEに表示する個人たち（複数）
  List<Person> _homePersons = [];
  bool _homeOverlayOpen = false;
  Person? _overlayPerson; // いま詳細表示中の人

  // どの丸アイコンが「アクティブ（太枠）」か
  int _currentHomeIndex = -1;

  // ===== 背景動画（bg mp4 等）用 =====
  VideoPlayerController? _bgVideoController;
  bool _bgVideoInitialized = false;
  String? _bgVideoPath; // いま初期化済みの動画パス

  // ===== 仏具（_f.png）の存在確認と現在表示パス =====
  final Map<String, bool> _assetExistsCache = <String, bool>{};
  String? _currentButsuguPath; // 選択中仏壇に対応する仏具パス（存在する場合のみ）
  String? _lastCheckedButsudan; // 直近チェックした仏壇パス

  @override
  void initState() {
    super.initState();
    _loadHomePersons();
  }

  @override
  void dispose() {
    _disposeBgVideo();
    super.dispose();
  }

  // ===== 背景（画像/動画）判定 =====
  bool _isVideo(String path) {
    final lower = path.toLowerCase();
    return lower.endsWith('.mp4') ||
        lower.endsWith('.mov') ||
        lower.endsWith('.webm');
  }

  Future<void> _disposeBgVideo() async {
    final c = _bgVideoController;
    _bgVideoController = null;
    _bgVideoInitialized = false;
    _bgVideoPath = null;
    if (c != null) {
      await c.dispose();
    }
  }

  Future<void> _initBgVideoIfNeeded(String assetPath) async {
    if (!_isVideo(assetPath)) {
      await _disposeBgVideo();
      return;
    }

    // 同じ動画は初期化し直さない
    if (_bgVideoPath == assetPath &&
        _bgVideoInitialized &&
        _bgVideoController != null) {
      return;
    }

    await _disposeBgVideo();

    final controller = VideoPlayerController.asset(assetPath);
    try {
      await controller.initialize();
      await controller.setLooping(true);
      await controller.setVolume(0);
      await controller.play();

      if (!mounted) {
        await controller.dispose();
        return;
      }

      setState(() {
        _bgVideoController = controller;
        _bgVideoInitialized = true;
        _bgVideoPath = assetPath;
      });
    } catch (_) {
      await controller.dispose();
      if (!mounted) return;
      setState(() {
        _bgVideoController = null;
        _bgVideoInitialized = false;
        _bgVideoPath = null;
      });
    }
  }

  Widget _buildBackground(SelectedAssets sel) {
    // カスタム背景（画像）優先
    if (sel.hasCustomBg && sel.bgBytes != null) {
      return Image.memory(
        sel.bgBytes!,
        fit: BoxFit.cover,
      );
    }

    final path = sel.bgAsset;

    // 動画背景
    if (_isVideo(path) && _bgVideoInitialized && _bgVideoController != null) {
      return IgnorePointer(
        ignoring: true,
        child: FittedBox(
          fit: BoxFit.cover,
          child: SizedBox(
            width: _bgVideoController!.value.size.width,
            height: _bgVideoController!.value.size.height,
            child: VideoPlayer(_bgVideoController!),
          ),
        ),
      );
    }

    // 画像背景
    return Image.asset(
      path,
      fit: BoxFit.cover,
    );
  }

  /// PeoplePage で保存された「HOMEに表示」の人たちを読み込む
  Future<void> _loadHomePersons() async {
    final prefs = await SharedPreferences.getInstance();

    // 新しい複数人リスト
    final listStr = prefs.getString(_prefsKeyHomePersonList);
    if (listStr != null) {
      try {
        final raw = jsonDecode(listStr) as List;
        final persons =
            raw.map((e) => Person.fromJson(e as Map<String, dynamic>)).toList();
        if (!mounted) return;
        setState(() {
          _homePersons = persons;
          if (_homePersons.isNotEmpty && _currentHomeIndex < 0) {
            _currentHomeIndex = 0;
          }
        });
        return;
      } catch (_) {
        // 壊れてたら後で上書きされるので無視
      }
    }

    // 旧：単体 HOME データがあれば、それをリスト扱いに移行
    final singleStr = prefs.getString(_prefsKeyHomePerson);
    if (singleStr != null) {
      try {
        final map = jsonDecode(singleStr) as Map<String, dynamic>;
        final p = Person.fromJson(map);
        if (!mounted) return;
        setState(() {
          _homePersons = [p];
          _currentHomeIndex = 0;
        });
        await prefs.setString(
          _prefsKeyHomePersonList,
          jsonEncode(_homePersons.map((e) => e.toJson()).toList()),
        );
      } catch (_) {}
    }
  }

  // ===== 仏具（_f.png）関連 =====

  /// 仏壇パス "xxx.png" -> 仏具パス "xxx_f.png"
  String? _deriveButsuguPath(String butsudanPath) {
    final lower = butsudanPath.toLowerCase();
    if (!lower.endsWith('.png')) return null;
    return '${butsudanPath.substring(0, butsudanPath.length - 4)}_f.png';
  }

  /// assets に存在するか（rootBundle.load で確認、結果はキャッシュ）
  Future<bool> _assetExists(String assetPath) async {
    if (_assetExistsCache.containsKey(assetPath)) {
      return _assetExistsCache[assetPath]!;
    }
    try {
      await rootBundle.load(assetPath);
      _assetExistsCache[assetPath] = true;
      return true;
    } catch (_) {
      _assetExistsCache[assetPath] = false;
      return false;
    }
  }

  /// 選択中仏壇に対応する仏具（_f.png）を確認して state に反映
  Future<void> _syncButsuguForButsudan(String butsudanPath) async {
    _lastCheckedButsudan = butsudanPath;

    final candidate = _deriveButsuguPath(butsudanPath);
    if (candidate == null) {
      if (!mounted) return;
      setState(() {
        _currentButsuguPath = null;
      });
      return;
    }

    final exists = await _assetExists(candidate);

    // 途中で仏壇が切り替わっていたら反映しない
    if (!mounted) return;
    if (_lastCheckedButsudan != butsudanPath) return;

    setState(() {
      _currentButsuguPath = exists ? candidate : null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final sel = context.watch<SelectedAssets>();

    // ★ 背景が動画なら初期化（次フレームで）
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      // カスタム背景が有効なら動画は破棄（カスタムは画像のみ想定）
      if (sel.hasCustomBg) {
        if (_bgVideoController != null) _disposeBgVideo();
        return;
      }

      final bg = sel.bgAsset;
      if (_isVideo(bg)) {
        if (_bgVideoPath != bg) {
          _initBgVideoIfNeeded(bg);
        }
      } else {
        if (_bgVideoController != null) _disposeBgVideo();
      }
    });

    // ★ 仏壇が切り替わったら、次フレームで仏具（_f.png）存在チェック
    if (_lastCheckedButsudan != sel.butsudan) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _syncButsuguForButsudan(sel.butsudan);
      });
    }

    return Scaffold(
      body: LayoutBuilder(
        builder: (context, constraints) {
          final h = constraints.maxHeight;
          final w = constraints.maxWidth;

          final ihaiItems = sel.ihaiItems;

          return Stack(
            children: [
              // 1) 背景（いちばん奥：画像 or 動画）
              Positioned.fill(child: _buildBackground(sel)),

              // 2) 仏壇メイン（縦いっぱい・縦優先）
              Positioned.fill(
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: SizedBox(
                    height: h, // 画面高100%
                    child: Image.asset(
                      sel.butsudan,
                      fit: BoxFit.fitHeight, // 縦優先（横は見切れてOK）
                      alignment: Alignment.bottomCenter,
                    ),
                  ),
                ),
              ),

              // 3) 位牌たち（仏壇メインの手前）
              for (int i = 0; i < ihaiItems.length; i++)
                _buildIhaiWidget(context, ihaiItems[i], i, w, h),

              // 4) 仏具（存在する場合のみ：位牌の手前）
              //    ※位牌のドラッグ/拡大縮小を阻害しないよう、タッチを透過
              if (_currentButsuguPath != null)
                Positioned.fill(
                  child: IgnorePointer(
                    ignoring: true,
                    child: Align(
                      alignment: Alignment.bottomCenter,
                      child: SizedBox(
                        height: h, // 仏壇と同じ：画面高100%
                        child: Image.asset(
                          _currentButsuguPath!,
                          fit: BoxFit.fitHeight, // 仏壇と同じ：縦優先
                          alignment: Alignment.bottomCenter,
                        ),
                      ),
                    ),
                  ),
                ),

              // 5) HOMEに表示の丸型遺影（複数を1グループとして横中央に配置）
              if (_homePersons.isNotEmpty)
                Positioned(
                  top: 16,
                  left: 0,
                  right: 0,
                  child: SizedBox(
                    height: 86,
                    child: Center(
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: List.generate(_homePersons.length, (index) {
                            final p = _homePersons[index];
                            final bool isActive = index == _currentHomeIndex;

                            return GestureDetector(
                              onTap: () {
                                setState(() {
                                  _currentHomeIndex = index;
                                  _overlayPerson = p;
                                  _homeOverlayOpen = true;
                                });
                              },
                              child: Padding(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 4),
                                child: Container(
                                  width: 72,
                                  height: 72,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: Colors.black.withOpacity(0.25),
                                    border: Border.all(
                                      color: Colors.white,
                                      width: isActive ? 4.0 : 1.5,
                                    ),
                                  ),
                                  child: ClipOval(
                                    child: Image.asset(
                                      p.primaryPortraitPath,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) => const Icon(
                                        Icons.person,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            );
                          }),
                        ),
                      ),
                    ),
                  ),
                ),

              // 6) HOMEに表示の詳細オーバーレイ（タップで閉じる）
              if (_overlayPerson != null && _homeOverlayOpen)
                Positioned.fill(
                  child: GestureDetector(
                    onTap: () {
                      setState(() {
                        _homeOverlayOpen = false;
                      });
                    },
                    child: Container(
                      color: Colors.black54,
                      alignment: Alignment.center,
                      child: _HomePersonOverlay(person: _overlayPerson!),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  /// 位牌ウィジェットの配置
  ///
  /// ※ 修正ポイント：
  ///   Alignment(cx, cy) を使って、真の中心で配置する。
  Widget _buildIhaiWidget(
    BuildContext context,
    IhaiItem item,
    int index,
    double w,
    double h,
  ) {
    final ihaiHeight = h * 0.25 * item.scale;

    // 0.0〜1.0 の正規化座標を安全にクランプ
    final cx = item.centerX.clamp(0.0, 1.0);
    // ★ 9% 上に補正（以前より少し下になる）
    final cy = (item.centerY - 0.09).clamp(0.0, 1.0);

    // Alignment を使って「中心座標」を素直に指定
    final alignment = Alignment(cx * 2 - 1, cy * 2 - 1);

    return Align(
      alignment: alignment,
      child: GestureDetector(
        onScaleStart: (details) {
          _startScale = item.scale;
        },
        onScaleUpdate: (details) {
          final sel = context.read<SelectedAssets>();
          final items = sel.ihaiItems;
          if (index < 0 || index >= items.length) return;
          final current = items[index];

          // 画面幅・高さに対しての移動量を正規化
          final dxNorm = details.focalPointDelta.dx / w;
          final dyNorm = details.focalPointDelta.dy / h;

          final newCx = (current.centerX + dxNorm).clamp(0.0, 1.0);
          final newCy = (current.centerY + dyNorm).clamp(0.0, 1.0);

          final newScale = (_startScale * details.scale).clamp(0.5, 2.5);

          sel.updateIhaiTransform(
            index,
            centerX: newCx,
            centerY: newCy,
            scale: newScale,
          );
        },
        child: SizedBox(
          height: ihaiHeight,
          child: Image.asset(
            item.assetPath,
            fit: BoxFit.contain,
          ),
        ),
      ),
    );
  }
}

/// HOMEに表示の詳細オーバーレイ（遺影60%＋縦文字：右→左で 名前→戒名→歿+享年）
/// - 遺影：画面縦60%に必ず拡大縮小（fitHeight）
/// - 切替：左から現れて、右へ消える（スライド＋フェード）
/// - 文字：3列の間隔を広め、名前＆戒名は上揃え
class _HomePersonOverlay extends StatefulWidget {
  final Person person;
  const _HomePersonOverlay({required this.person});

  @override
  State<_HomePersonOverlay> createState() => _HomePersonOverlayState();
}

class _HomePersonOverlayState extends State<_HomePersonOverlay> {
  late List<String> _photos;
  int _index = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _setupPhotosAndTimer();
  }

  @override
  void didUpdateWidget(covariant _HomePersonOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.person != widget.person) {
      _timer?.cancel();
      _index = 0;
      _setupPhotosAndTimer();
    }
  }

  void _setupPhotosAndTimer() {
    _photos =
        widget.person.portraitPaths.where((p) => p.trim().isNotEmpty).toList();

    if (_photos.length > 1) {
      _timer = Timer.periodic(const Duration(seconds: 5), (_) {
        if (!mounted) return;
        setState(() {
          _index = (_index + 1) % _photos.length;
        });
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screen = MediaQuery.of(context).size;
    final screenH = screen.height;
    final screenW = screen.width;

    // ===== 遺影表示枠：高さは「画面縦60%」固定 =====
    final portraitH = screenH * 0.60;

    // 幅は端末に合わせて（高さ優先でfitHeightするので幅は余裕を持たせる）
    final portraitW = (screenW * 0.88).clamp(280.0, 620.0).toDouble();

    // 文字サイズ（clampはnum -> toDouble必須）
    final bigFont = (screenW * 0.060).clamp(22.0, 36.0).toDouble();
    final midFont = (screenW * 0.052).clamp(20.0, 32.0).toDouble();
    final smallFont = (midFont - 2).clamp(18.0, 30.0).toDouble();

    // ★ 3列の間隔：もっと広げる
    final colGap = (screenW * 0.055).clamp(18.0, 34.0).toDouble();

    final nameText = widget.person.name.isEmpty ? '(無名)' : widget.person.name;
    final kainameText = widget.person.kainame.trim();

    // 歿年月日（漢数字）＋享年（漢数字）
    final diedKanji = widget.person.dod.isNotEmpty
        ? _formatYmdJaKanji(widget.person.dod)
        : '';
    final ageKanji = _ageToKanji(widget.person.age);

    final deathColumnText = [
      if (diedKanji.isNotEmpty) '$diedKanji歿',
      if (ageKanji.isNotEmpty) '享年$ageKanji歳',
    ].join('\n');

    final photoKey = _photos.isEmpty ? 'no-photo' : _photos[_index];

    // 文字共通スタイル（上に揃えたいので height は詰め過ぎない）
    TextStyle styleFor(double size, FontWeight w) => TextStyle(
          fontSize: size,
          fontWeight: w,
          color: Colors.white,
          height: 1.08,
          shadows: [
            Shadow(
              blurRadius: 7.0,
              offset: const Offset(0.0, 2.0),
              color: Colors.black.withOpacity(0.60),
            ),
          ],
        );

    return Material(
      color: Colors.transparent,
      child: SizedBox(
        width: double.infinity,
        height: double.infinity,
        child: Stack(
          children: [
            // ===== 遺影＋文字を同じ箱に入れて、横中央・少し上寄り =====
            Align(
              alignment: const Alignment(0, -0.40),
              child: SizedBox(
                width: portraitW,
                height: portraitH,
                child: Stack(
                  children: [
                    // ---------- 遺影 ----------
                    ClipRRect(
                      borderRadius: BorderRadius.circular(24),
                      child: Container(
                        color: Colors.transparent,
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 1300),
                          switchInCurve: Curves.easeInOutCubic,
                          switchOutCurve: Curves.easeInOutCubic,
                          transitionBuilder: (child, animation) {
                            // ★ 左から現れて、右へ消える
                            // 新しい子：forward(0→1) なので「左(-)→中央」
                            // 古い子：reverse(1→0) なので Tween(begin:+, end:0) で「中央→右(+)」
                            final isReverse =
                                animation.status == AnimationStatus.reverse;

                            final tween = isReverse
                                ? Tween<Offset>(
                                    begin: const Offset(0.10, 0.0),
                                    end: Offset.zero,
                                  )
                                : Tween<Offset>(
                                    begin: const Offset(-0.10, 0.0),
                                    end: Offset.zero,
                                  );

                            final slide = tween.animate(
                              CurvedAnimation(
                                parent: animation,
                                curve: Curves.easeInOutCubic,
                              ),
                            );

                            final fade = CurvedAnimation(
                              parent: animation,
                              curve: Curves.easeInOutCubic,
                            );

                            return FadeTransition(
                              opacity: fade,
                              child: SlideTransition(
                                position: slide,
                                child: child,
                              ),
                            );
                          },
                          child: _photos.isEmpty
                              ? Container(
                                  key: const ValueKey('no-photo'),
                                  color: Colors.grey,
                                  child: const Center(
                                    child: Icon(
                                      Icons.person,
                                      size: 64,
                                      color: Colors.white,
                                    ),
                                  ),
                                )
                              : Center(
                                  // ★ここが肝：高さ60%に必ず合わせて拡大縮小（画像ごとに自動）
                                  // 画像の縦を portraitH に合わせるので fitHeight を使う
                                  child: Image.asset(
                                    _photos[_index],
                                    key: ValueKey(photoKey),
                                    fit: BoxFit.fitHeight,
                                    height: portraitH,
                                    alignment: Alignment.center,
                                  ),
                                ),
                        ),
                      ),
                    ),

                    // ---------- 文字（遺影の手前・横中央・上揃え） ----------
                    Positioned.fill(
                      child: IgnorePointer(
                        ignoring: true,
                        child: Padding(
                          padding: const EdgeInsets.only(top: 100),
                          child: Align(
                            alignment: Alignment.topCenter, // ★上揃えの基準
                            child: Row(
                              // ★右→左の並び：右から 名前→戒名→歿+享年
                              textDirection: TextDirection.rtl,
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment:
                                  CrossAxisAlignment.start, // ★上揃え
                              children: [
                                // 右端：名前（上揃え）
                                _VerticalJaText(
                                  nameText,
                                  style: styleFor(bigFont, FontWeight.w800),
                                ),
                                SizedBox(width: colGap),

                                // その左：戒名（上揃え）
                                if (kainameText.isNotEmpty) ...[
                                  _VerticalJaText(
                                    kainameText,
                                    style: styleFor(midFont, FontWeight.w700),
                                  ),
                                  SizedBox(width: colGap),
                                ],

                                // さらに左：歿年月日（漢数字）＋下に享年（漢数字）
                                if (deathColumnText.isNotEmpty)
                                  _VerticalJaText(
                                    deathColumnText,
                                    style: styleFor(smallFont, FontWeight.w700),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// "YYYY-MM-DD" / "YYYY/MM/DD" 等 -> "二〇二五年十二月三日"
  String _formatYmdJaKanji(String s) {
    try {
      final parts = s.split(RegExp(r'[-/.]'));
      if (parts.length < 3) return s;

      final y = int.parse(parts[0]);
      final m = int.parse(parts[1]);
      final d = int.parse(parts[2]);

      final yKanji = _yearToKanji(y); // 二〇二五
      final mKanji = _intToKanji(m); // 十二
      final dKanji = _intToKanji(d); // 三

      return '$yKanji年$mKanji月$dKanji日';
    } catch (_) {
      return s;
    }
  }

  String _yearToKanji(int year) {
    const digits = ['〇', '一', '二', '三', '四', '五', '六', '七', '八', '九'];
    final s = year.toString();
    return s.split('').map((ch) {
      final n = int.tryParse(ch);
      return (n == null) ? ch : digits[n];
    }).join();
  }

  /// age文字列（例: "88" / "８８" / "88才"）→ 漢字数字（例: "八十八"）
  String _ageToKanji(String ageRaw) {
    final s = ageRaw.trim();
    if (s.isEmpty) return '';

    final normalized = s
        .replaceAll('０', '0')
        .replaceAll('１', '1')
        .replaceAll('２', '2')
        .replaceAll('３', '3')
        .replaceAll('４', '4')
        .replaceAll('５', '5')
        .replaceAll('６', '6')
        .replaceAll('７', '7')
        .replaceAll('８', '8')
        .replaceAll('９', '9');

    final digits = RegExp(r'\d+').firstMatch(normalized)?.group(0);
    if (digits == null) return '';
    final n = int.tryParse(digits);
    if (n == null || n <= 0) return '';

    return _intToKanji(n);
  }

  /// 1〜999程度の漢字変換（享年用途として十分な範囲）
  String _intToKanji(int n) {
    const k = ['零', '一', '二', '三', '四', '五', '六', '七', '八', '九'];

    if (n == 0) return k[0];
    if (n < 10) return k[n];

    String twoDigits(int x) {
      final tens = x ~/ 10;
      final ones = x % 10;
      final t = tens == 1 ? '十' : '${k[tens]}十';
      if (ones == 0) return t;
      return '$t${k[ones]}';
    }

    if (n < 100) return twoDigits(n);

    final hundreds = n ~/ 100;
    final rest = n % 100;

    final h = hundreds == 1 ? '百' : '${k[hundreds]}百';
    if (rest == 0) return h;
    if (rest < 10) return '$h${k[rest]}';
    return '$h${twoDigits(rest)}';
  }
}

/// 日本語の縦表示（1文字ずつ改行）
/// 改行（\n）を含む場合はブロックごとに縦組みして間を空ける
class _VerticalJaText extends StatelessWidget {
  final String text;
  final TextStyle? style;

  const _VerticalJaText(
    this.text, {
    this.style,
  });

  @override
  Widget build(BuildContext context) {
    final t = text.trim();
    if (t.isEmpty) return const SizedBox.shrink();

    final blocks = t.split('\n').map((b) {
      final b2 = b.replaceAll(' ', '').trim();
      return b2.split('').join('\n');
    }).toList();

    final vertical = blocks.join('\n\n');

    return Text(
      vertical,
      textAlign: TextAlign.center,
      style: style,
      softWrap: false,
    );
  }
}

class _OverlayTag extends StatelessWidget {
  final String text;
  const _OverlayTag(this.text);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.8),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: const TextStyle(fontSize: 12),
      ),
    );
  }
}

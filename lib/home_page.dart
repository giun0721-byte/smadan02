import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import 'package:video_player/video_player.dart';
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

  // HOME丸アイコン用のPageController（スワイプ）
  final PageController _homeIconController =
      PageController(viewportFraction: 0.30);

  // エフェクト動画用
  String? _effectPath;
  VideoPlayerController? _effectController;
  bool _effectInitialized = false;

  @override
  void initState() {
    super.initState();
    _loadHomePersons();
  }

  @override
  void dispose() {
    _effectController?.dispose();
    _homeIconController.dispose();
    super.dispose();
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

  Future<void> _loadEffectIfNeeded(String? newPath) async {
    // パスに変化がなければ何もしない
    if (newPath == _effectPath) return;

    // 既存コントローラを破棄
    await _effectController?.dispose();
    _effectController = null;
    _effectInitialized = false;
    _effectPath = newPath;

    if (newPath == null) {
      // 「エフェクトなし」
      if (!mounted) return;
      setState(() {
        _effectInitialized = false;
      });
      return;
    }

    final controller = VideoPlayerController.asset(newPath);
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
        _effectController = controller;
        _effectInitialized = true;
      });
    } catch (_) {
      await controller.dispose();
      if (!mounted) return;
      setState(() {
        _effectController = null;
        _effectInitialized = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final sel = context.watch<SelectedAssets>();

    // 選択中エフェクトに応じて動画をロード
    _loadEffectIfNeeded(sel.effectAsset);

    return Scaffold(
      body: LayoutBuilder(
        builder: (context, constraints) {
          final h = constraints.maxHeight;
          final w = constraints.maxWidth;

          Widget buildBackground() {
            if (sel.hasCustomBg && sel.bgBytes != null) {
              return Image.memory(
                sel.bgBytes!,
                fit: BoxFit.cover,
              );
            }
            return Image.asset(
              sel.bgAsset,
              fit: BoxFit.cover,
            );
          }

          final ihaiItems = sel.ihaiItems;

          return Stack(
            children: [
              // 1) 背景（いちばん奥）
              Positioned.fill(child: buildBackground()),

              // 2) エフェクト動画（背景の一つ手前）
              if (_effectInitialized && _effectController != null)
                Positioned.fill(
                  child: IgnorePointer(
                    ignoring: true, // タップは奥に通す
                    child: FittedBox(
                      fit: BoxFit.cover,
                      child: SizedBox(
                        width: _effectController!.value.size.width,
                        height: _effectController!.value.size.height,
                        child: Opacity(
                          opacity: 0.4, // 透け具合（必要なら調整）
                          child: VideoPlayer(_effectController!),
                        ),
                      ),
                    ),
                  ),
                ),

              // 3) 仏壇
              Positioned.fill(
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: SizedBox(
                    height: h * 0.85, // 画面の高さに対して 85%
                    child: Image.asset(
                      sel.butsudan,
                      fit: BoxFit.fitHeight, // 高さだけに合わせる（横幅は無視）
                    ),
                  ),
                ),
              ),

              // 4) 位牌たち（いちばん手前）
              for (int i = 0; i < ihaiItems.length; i++)
                _buildIhaiWidget(context, ihaiItems[i], i, w, h),

              // 5) HOMEに表示の丸型遺影（複数・センター・スワイプ・太枠）
              if (_homePersons.isNotEmpty)
                Positioned(
                  top: 24,
                  left: 0,
                  right: 0,
                  child: SizedBox(
                    height: 90,
                    child: PageView.builder(
                      controller: _homeIconController,
                      itemCount: _homePersons.length,
                      itemBuilder: (context, index) {
                        final p = _homePersons[index];
                        final bool isActive = index == _currentHomeIndex;

                        return Center(
                          child: GestureDetector(
                            onTap: () {
                              setState(() {
                                _currentHomeIndex = index;
                                _overlayPerson = p;
                                _homeOverlayOpen = true;
                              });
                            },
                            child: Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 20),
                              child: Container(
                                width: 76,
                                height: 76,
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
                          ),
                        );
                      },
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
                      color: Colors.black54, // 画面全体の暗くなる部分（透かし）
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

  Widget _buildIhaiWidget(
    BuildContext context,
    IhaiItem item,
    int index,
    double w,
    double h,
  ) {
    final ihaiHeight = h * 0.40 * item.scale;

    final cx = item.centerX.clamp(0.0, 1.0);
    final cy = item.centerY.clamp(0.0, 1.0);

    final left = cx * w - ihaiHeight / 2;
    final top = cy * h - ihaiHeight * 0.5;

    return Positioned(
      left: left,
      top: top,
      child: GestureDetector(
        onScaleStart: (details) {
          _startScale = item.scale;
        },
        onScaleUpdate: (details) {
          final sel = context.read<SelectedAssets>();
          final items = sel.ihaiItems;
          if (index < 0 || index >= items.length) return;
          final current = items[index];

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

/// HOMEに表示の詳細カード（遺影1〜3をフェード＋個人情報表示）
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
    // 別の人に切り替わったとき、写真リストとタイマーをリセット
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
    final theme = Theme.of(context);
    final screenH = MediaQuery.of(context).size.height;

    final bornText = widget.person.dob.isNotEmpty
        ? '${_formatYmdJa(widget.person.dob)}生'
        : '';
    final diedText = widget.person.dod.isNotEmpty
        ? '${_formatYmdJa(widget.person.dod)}歿'
        : '';

    return Material(
      color: Colors.transparent,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
        // 大枠は透明
        decoration: BoxDecoration(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 写真：画面高さの40% ＋ 薄い影 ＋ なめらかフェード
            SizedBox(
              height: screenH * 0.40,
              child: Center(
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.35),
                        blurRadius: 16,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: AspectRatio(
                    aspectRatio: 4 / 3,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 900),
                        transitionBuilder: (child, animation) {
                          return FadeTransition(
                            opacity: CurvedAnimation(
                              parent: animation,
                              curve: Curves.easeInOut,
                            ),
                            child: child,
                          );
                        },
                        child: _photos.isEmpty
                            ? Container(
                                key: const ValueKey('no-photo'),
                                color: Colors.grey,
                                child: const Center(
                                  child: Icon(
                                    Icons.person,
                                    size: 48,
                                    color: Colors.white,
                                  ),
                                ),
                              )
                            : Image.asset(
                                _photos[_index],
                                key: ValueKey(_photos[_index]),
                                fit: BoxFit.cover,
                              ),
                      ),
                    ),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 16),

            // 情報部分だけ背景色つきコンテナ
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFF6EFE9),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 名前＋続柄＋備考
                  Text(
                    widget.person.name.isEmpty ? '(無名)' : widget.person.name,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (widget.person.relation.isNotEmpty)
                        _OverlayTag(widget.person.relation),
                      if (widget.person.relation.isNotEmpty &&
                          widget.person.note.isNotEmpty)
                        const SizedBox(width: 8),
                      if (widget.person.note.isNotEmpty)
                        _OverlayTag(widget.person.note),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // 戒名ふりがな＋戒名＋享年
                  if (widget.person.kainameKana.isNotEmpty)
                    Text(
                      widget.person.kainameKana,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: Colors.grey[700],
                      ),
                    ),
                  if (widget.person.kainame.isNotEmpty ||
                      widget.person.age.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (widget.person.kainame.isNotEmpty)
                            Text('戒名 ${widget.person.kainame}'),
                          if (widget.person.kainame.isNotEmpty &&
                              widget.person.age.isNotEmpty)
                            const SizedBox(width: 8),
                          if (widget.person.age.isNotEmpty)
                            Text('享年${widget.person.age}才'),
                        ],
                      ),
                    ),

                  const SizedBox(height: 8),

                  // 生没年月日
                  if (bornText.isNotEmpty || diedText.isNotEmpty)
                    Text(
                      [bornText, diedText]
                          .where((e) => e.isNotEmpty)
                          .join(' 〜 '),
                      style: theme.textTheme.bodyMedium,
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatYmdJa(String s) {
    try {
      final parts = s.split(RegExp(r'[-/.]'));
      if (parts.length < 3) return s;
      final y = int.parse(parts[0]);
      final m = int.parse(parts[1]);
      final d = int.parse(parts[2]);
      String two(int n) => n.toString().padLeft(2, '0');
      return '$y年${two(m)}月${two(d)}日';
    } catch (_) {
      return s;
    }
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

import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'app_state.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  // 自動生成される候補リスト
  List<String> _bgList = [];
  List<String> _butsudanList = [];
  List<String> _ihaiCandidates = [];

  bool _loadingAssets = true;

  // 位牌テンプレート選択用（追加ボタン用。現在選択の位牌は SelectedAssets.currentIhai で管理）
  String? _pickedIhaiTemplate;

  // ===== 仏具（_f.png）の存在確認キャッシュ =====
  final Map<String, bool> _assetExistsCache = <String, bool>{};
  String? _currentButsuguPath; // 選択中仏壇に対応する仏具パス（存在する場合のみ）
  String? _lastCheckedButsudan; // 直近チェックした仏壇パス

  // ===== 背景動画（bg mp4）用 =====
  VideoPlayerController? _bgVideoController;
  bool _bgVideoInitialized = false;
  String? _bgVideoPath; // いま初期化済みの動画パス

  @override
  void initState() {
    super.initState();
    _loadAssetLists();
  }

  bool _isVideo(String path) {
    final lower = path.toLowerCase();
    return lower.endsWith('.mp4') ||
        lower.endsWith('.mov') ||
        lower.endsWith('.webm');
  }

  bool _isImage(String path) {
    final lower = path.toLowerCase();
    return lower.endsWith('.png') ||
        lower.endsWith('.jpg') ||
        lower.endsWith('.jpeg');
  }

  Future<void> _initBgVideoIfNeeded(String assetPath) async {
    if (!_isVideo(assetPath)) {
      await _disposeBgVideo();
      return;
    }
    if (_bgVideoPath == assetPath &&
        _bgVideoInitialized &&
        _bgVideoController != null) {
      return; // 既に同じ動画を初期化済み
    }

    await _disposeBgVideo();

    final controller = VideoPlayerController.asset(assetPath);
    try {
      await controller.initialize();
      await controller.setLooping(true);
      await controller.setVolume(0);
      await controller.play();

      if (!mounted) return;
      setState(() {
        _bgVideoController = controller;
        _bgVideoInitialized = true;
        _bgVideoPath = assetPath;
      });
    } catch (_) {
      await controller.dispose();
    }
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

  /// 仏壇パス "xxx.png" -> 仏具パス "xxx_f.png"
  String? _deriveButsuguPath(String butsudanPath) {
    final lower = butsudanPath.toLowerCase();
    if (!lower.endsWith('.png')) return null;
    return '${butsudanPath.substring(0, butsudanPath.length - 4)}_f.png';
  }

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

  Future<void> _syncButsuguForButsudan(String butsudanPath) async {
    _lastCheckedButsudan = butsudanPath;

    final candidate = _deriveButsuguPath(butsudanPath);
    if (candidate == null) {
      if (!mounted) return;
      setState(() => _currentButsuguPath = null);
      return;
    }

    final exists = await _assetExists(candidate);

    if (!mounted) return;
    if (_lastCheckedButsudan != butsudanPath) return;

    setState(() {
      _currentButsuguPath = exists ? candidate : null;
    });
  }

  /// assets/asset_index.json を読み取り、
  /// assets/bg/, assets/butsudan/, assets/ihai/ を抽出
  /// ※ bg は「画像＋動画」を同一リストとして扱う
  Future<void> _loadAssetLists() async {
    try {
      final jsonStr = await rootBundle.loadString('assets/asset_index.json');
      final Map<String, dynamic> index =
          json.decode(jsonStr) as Map<String, dynamic>;

      List<String> asStringList(String key) {
        final v = index[key];
        if (v is List) {
          return v.map((e) => e.toString()).toList()..sort();
        }
        return <String>[];
      }

      final bg = asStringList('bg'); // ここに jpg/png/mp4 が入る想定
      final butsudan = asStringList('butsudan');
      final ihai = asStringList('ihai');

      if (!mounted) return;

      final sel = context.read<SelectedAssets>();

      setState(() {
        _bgList = bg.isNotEmpty
            ? bg
            : const [
                'assets/bg/bg1.jpg',
                'assets/bg/bg2.jpg',
              ];

        _butsudanList = butsudan.isNotEmpty
            ? butsudan
            : const [
                'assets/butsudan/01karaki.png',
                'assets/butsudan/02kagucho.png',
              ];

        _ihaiCandidates = ihai.isNotEmpty
            ? ihai
            : const [
                'assets/ihai/ihai01.png',
                'assets/ihai/ihai02.png',
              ];

        _pickedIhaiTemplate ??=
            _ihaiCandidates.isNotEmpty ? _ihaiCandidates.first : null;

        // currentIhai が未設定なら、追加済み位牌の末尾を選択状態にする
        if (sel.currentIhai == null) {
          final init = sel.ihaiList.isNotEmpty
              ? sel.ihaiList.last
              : (_ihaiCandidates.isNotEmpty ? _ihaiCandidates.first : null);
          if (init != null) {
            sel.setCurrentIhai(init);
          }
        }

        _loadingAssets = false;
      });

      // 背景が動画ならプレビュー用に初期化
      await _initBgVideoIfNeeded(sel.bgAsset);

      // 仏具（_f.png）も初期同期
      await _syncButsuguForButsudan(sel.butsudan);
    } catch (_) {
      if (!mounted) return;

      final sel = context.read<SelectedAssets>();

      setState(() {
        _bgList = const [
          'assets/bg/bg1.jpg',
          'assets/bg/bg2.jpg',
        ];
        _butsudanList = const [
          'assets/butsudan/01karaki.png',
          'assets/butsudan/02kagucho.png',
        ];
        _ihaiCandidates = const [
          'assets/ihai/ihai01.png',
          'assets/ihai/ihai02.png',
        ];

        _pickedIhaiTemplate ??=
            _ihaiCandidates.isNotEmpty ? _ihaiCandidates.first : null;

        if (sel.currentIhai == null) {
          final init = sel.ihaiList.isNotEmpty
              ? sel.ihaiList.last
              : (_ihaiCandidates.isNotEmpty ? _ihaiCandidates.first : null);
          if (init != null) {
            sel.setCurrentIhai(init);
          }
        }

        _loadingAssets = false;
      });

      await _initBgVideoIfNeeded(sel.bgAsset);
      await _syncButsuguForButsudan(sel.butsudan);
    }
  }

  /// 画像ファイルを読み込み、Uint8List にする（現状の「カスタム背景」用。不要ならUI側を消せます）
  Future<Uint8List?> _pickImageBytes() async {
    final picker = ImagePicker();
    final picked =
        await picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (picked == null) return null;
    return await picked.readAsBytes();
  }

  Widget _buildBgPreview(SelectedAssets sel) {
    // カスタム背景（画像）を残す場合
    if (sel.hasCustomBg && sel.bgBytes != null) {
      return Align(
        alignment: Alignment.center,
        child: Image.memory(
          sel.bgBytes!,
          fit: BoxFit.fitHeight,
          width: double.infinity,
        ),
      );
    }

    final path = sel.bgAsset;

    // 動画背景
    if (_isVideo(path) && _bgVideoInitialized && _bgVideoController != null) {
      return Align(
        alignment: Alignment.center,
        child: IgnorePointer(
          ignoring: true,
          child: SizedBox.expand(
            child: FittedBox(
              fit: BoxFit.fitHeight,
              child: SizedBox(
                width: _bgVideoController!.value.size.width,
                height: _bgVideoController!.value.size.height,
                child: VideoPlayer(_bgVideoController!),
              ),
            ),
          ),
        ),
      );
    }

    // 画像背景
    return Align(
      alignment: Alignment.center,
      child: Image.asset(
        path,
        fit: BoxFit.fitHeight,
        width: double.infinity,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final sel = context.watch<SelectedAssets>();

    // 仏壇が切り替わったら、次フレームで仏具（_f.png）存在チェック
    if (_lastCheckedButsudan != sel.butsudan) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _syncButsuguForButsudan(sel.butsudan);
      });
    }

    // 背景が切り替わったら（動画なら）初期化
    if (!sel.hasCustomBg &&
        _isVideo(sel.bgAsset) &&
        _bgVideoPath != sel.bgAsset) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _initBgVideoIfNeeded(sel.bgAsset);
      });
    }
    // 背景が画像に変わったら動画を破棄
    if (!sel.hasCustomBg &&
        !_isVideo(sel.bgAsset) &&
        _bgVideoController != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _disposeBgVideo();
      });
    }

    const highlightColor = Color(0xFFCC7A00);

    // プレビュー用位牌
    final previewIhaiPath = sel.currentIhai ??
        (sel.ihaiList.isNotEmpty
            ? sel.ihaiList.last
            : (_ihaiCandidates.isNotEmpty
                ? _ihaiCandidates.first
                : 'assets/ihai/ihai01.png'));

    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final totalH = constraints.maxHeight;
            final previewH = totalH / 3;

            return Column(
              children: [
                // ===== 上部プレビュー =====
                SizedBox(
                  height: previewH,
                  width: double.infinity,
                  child: ClipRect(
                    child: Container(
                      color: const Color(0xFFDFF3E3),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 14.0),
                        child: Stack(
                          children: [
                            // 0) 背景（画像 or 動画）
                            _buildBgPreview(sel),

                            // 1) 仏壇メイン
                            Align(
                              alignment: Alignment.bottomCenter,
                              child: FractionallySizedBox(
                                heightFactor: 1.0,
                                child: Image.asset(
                                  sel.butsudan,
                                  fit: BoxFit.fitHeight,
                                  alignment: Alignment.bottomCenter,
                                ),
                              ),
                            ),

                            // 2) 位牌（少し小さめ＋下げ位置は別途変更済みならそのまま）
                            Align(
                              alignment: const Alignment(0.0, 0.1),
                              child: FractionallySizedBox(
                                heightFactor: 0.3,
                                child: Image.asset(
                                  previewIhaiPath,
                                  fit: BoxFit.contain,
                                ),
                              ),
                            ),

                            // 3) 仏具（存在する場合のみ）
                            if (_currentButsuguPath != null)
                              Align(
                                alignment: Alignment.bottomCenter,
                                child: FractionallySizedBox(
                                  heightFactor: 1.0,
                                  child: Image.asset(
                                    _currentButsuguPath!,
                                    fit: BoxFit.fitHeight,
                                    alignment: Alignment.bottomCenter,
                                  ),
                                ),
                              ),

                            // 左上ラベル
                            Positioned(
                              left: 12,
                              top: 8,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    vertical: 4, horizontal: 12),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF5F0E6),
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(
                                      color: const Color(0xFF8B5A2B),
                                      width: 1.5),
                                  boxShadow: const [
                                    BoxShadow(
                                      color: Colors.black26,
                                      blurRadius: 3,
                                      offset: Offset(1, 1),
                                    )
                                  ],
                                ),
                                child: const Text(
                                  'プレビュー',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF5C3A21),
                                    letterSpacing: 2.0,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

                // ===== 下部 =====
                Expanded(
                  child: _loadingAssets
                      ? const Center(child: CircularProgressIndicator())
                      : SingleChildScrollView(
                          child: Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // ---------- 背景選択（画像＋動画） ----------
                                const Text(
                                  '背景選択（画像 / 動画）',
                                  style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 8),
                                SizedBox(
                                  height: 120,
                                  child: SingleChildScrollView(
                                    scrollDirection: Axis.horizontal,
                                    child: Row(
                                      children: [
                                        // （任意）カスタム背景が不要なら、このブロックと「追加ボタン」を削除してください
                                        if (sel.hasCustomBg &&
                                            sel.bgBytes != null)
                                          GestureDetector(
                                            onTap: () {},
                                            onLongPress: () {
                                              context
                                                  .read<SelectedAssets>()
                                                  .clearCustomBg();
                                            },
                                            child: Container(
                                              width: 160,
                                              margin: const EdgeInsets.only(
                                                  right: 8),
                                              decoration: BoxDecoration(
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                                border: Border.all(
                                                    color: Colors.green,
                                                    width: 2),
                                              ),
                                              child: ClipRRect(
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                                child: Stack(
                                                  children: [
                                                    Positioned.fill(
                                                      child: Image.memory(
                                                          sel.bgBytes!,
                                                          fit: BoxFit.cover),
                                                    ),
                                                    const Positioned(
                                                      right: 4,
                                                      top: 4,
                                                      child: Icon(
                                                          Icons.check_circle,
                                                          color: Colors.green),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          ),

                                        ..._bgList.map((bgPath) {
                                          final isSelected = !sel.hasCustomBg &&
                                              sel.bgAsset == bgPath;

                                          return GestureDetector(
                                            onTap: () async {
                                              context
                                                  .read<SelectedAssets>()
                                                  .setBgAsset(bgPath);
                                              await _initBgVideoIfNeeded(
                                                  bgPath);
                                            },
                                            child: Container(
                                              width: 160,
                                              margin: const EdgeInsets.only(
                                                  right: 8),
                                              decoration: BoxDecoration(
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                                border: Border.all(
                                                  color: isSelected
                                                      ? highlightColor
                                                      : Colors.grey,
                                                  width: isSelected ? 2 : 1,
                                                ),
                                              ),
                                              child: ClipRRect(
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                                child: _isImage(bgPath)
                                                    ? Image.asset(bgPath,
                                                        fit: BoxFit.cover)
                                                    : Container(
                                                        color: Colors.black12,
                                                        child: Center(
                                                          child: Column(
                                                            mainAxisAlignment:
                                                                MainAxisAlignment
                                                                    .center,
                                                            children: [
                                                              const Icon(
                                                                  Icons.movie,
                                                                  size: 30),
                                                              const SizedBox(
                                                                  height: 6),
                                                              Padding(
                                                                padding: const EdgeInsets
                                                                    .symmetric(
                                                                    horizontal:
                                                                        8.0),
                                                                child: Text(
                                                                  bgPath
                                                                      .split(
                                                                          '/')
                                                                      .last,
                                                                  textAlign:
                                                                      TextAlign
                                                                          .center,
                                                                  style: const TextStyle(
                                                                      fontSize:
                                                                          11),
                                                                  maxLines: 2,
                                                                  overflow:
                                                                      TextOverflow
                                                                          .ellipsis,
                                                                ),
                                                              ),
                                                            ],
                                                          ),
                                                        ),
                                                      ),
                                              ),
                                            ),
                                          );
                                        }),

                                        // （任意）端末画像から追加が不要なら削除
                                        GestureDetector(
                                          onTap: () async {
                                            final bytes =
                                                await _pickImageBytes();
                                            if (bytes != null &&
                                                bytes.isNotEmpty) {
                                              if (!mounted) return;
                                              // カスタムは画像のみ想定（動画は対象外）
                                              context
                                                  .read<SelectedAssets>()
                                                  .setBgCustom(bytes);
                                              await _disposeBgVideo();
                                            }
                                          },
                                          child: Container(
                                            width: 160,
                                            margin:
                                                const EdgeInsets.only(right: 8),
                                            decoration: BoxDecoration(
                                              color: Colors.grey.shade300,
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                            ),
                                            child: const Center(
                                              child: Icon(Icons.add_a_photo,
                                                  size: 32),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),

                                const SizedBox(height: 16),

                                // ---------- 仏壇選択 ----------
                                const Text(
                                  '仏壇選択',
                                  style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 8),
                                SizedBox(
                                  height: 140,
                                  child: SingleChildScrollView(
                                    scrollDirection: Axis.horizontal,
                                    child: Row(
                                      children:
                                          _butsudanList.map((butsudanPath) {
                                        final isSelected =
                                            sel.butsudan == butsudanPath;
                                        return GestureDetector(
                                          onTap: () {
                                            context
                                                .read<SelectedAssets>()
                                                .setButsudan(butsudanPath);
                                          },
                                          child: Container(
                                            width: 160,
                                            height: 120,
                                            margin:
                                                const EdgeInsets.only(right: 8),
                                            decoration: BoxDecoration(
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                              border: Border.all(
                                                color: isSelected
                                                    ? highlightColor
                                                    : Colors.grey,
                                                width: isSelected ? 2 : 1,
                                              ),
                                            ),
                                            child: Transform.scale(
                                              scale: 1.2,
                                              child: Image.asset(butsudanPath,
                                                  fit: BoxFit.contain),
                                            ),
                                          ),
                                        );
                                      }).toList(),
                                    ),
                                  ),
                                ),

                                const SizedBox(height: 16),

                                // ---------- 位牌テンプレート選択（追加用） ----------
                                const Text(
                                  '位牌選択',
                                  style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 8),
                                SizedBox(
                                  height: 120,
                                  child: SingleChildScrollView(
                                    scrollDirection: Axis.horizontal,
                                    child: Row(
                                      children: _ihaiCandidates.map((ihaiPath) {
                                        final isSelected =
                                            _pickedIhaiTemplate == ihaiPath;
                                        return GestureDetector(
                                          onTap: () {
                                            setState(() {
                                              _pickedIhaiTemplate = ihaiPath;
                                            });
                                            context
                                                .read<SelectedAssets>()
                                                .setCurrentIhai(ihaiPath);
                                          },
                                          child: Container(
                                            width: 120,
                                            margin:
                                                const EdgeInsets.only(right: 8),
                                            decoration: BoxDecoration(
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                              border: Border.all(
                                                color: isSelected
                                                    ? highlightColor
                                                    : Colors.grey,
                                                width: isSelected ? 2 : 1,
                                              ),
                                            ),
                                            child: ClipRRect(
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                              child: Image.asset(ihaiPath,
                                                  fit: BoxFit.contain),
                                            ),
                                          ),
                                        );
                                      }).toList(),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Align(
                                  alignment: Alignment.centerLeft,
                                  child: ElevatedButton.icon(
                                    onPressed: () {
                                      final template = _pickedIhaiTemplate ??
                                          (_ihaiCandidates.isNotEmpty
                                              ? _ihaiCandidates.first
                                              : null);
                                      if (template == null) return;
                                      context
                                          .read<SelectedAssets>()
                                          .addIhai(template);
                                    },
                                    icon: const Icon(Icons.add),
                                    label: const Text('位牌を追加'),
                                  ),
                                ),

                                const SizedBox(height: 12),

                                // ---------- 現在の位牌一覧と削除 ----------
                                const Text(
                                  '現在の位牌（タップで選択 / 削除できます）',
                                  style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 8),
                                SizedBox(
                                  height: 120,
                                  child: SingleChildScrollView(
                                    scrollDirection: Axis.horizontal,
                                    child: Row(
                                      children: [
                                        if (sel.ihaiList.isEmpty)
                                          const Text('（まだ位牌は追加されていません）'),
                                        ...sel.ihaiList.map((ihaiPath) {
                                          final isCurrent =
                                              sel.currentIhai == ihaiPath;
                                          return Container(
                                            width: 120,
                                            margin:
                                                const EdgeInsets.only(right: 8),
                                            child: Column(
                                              children: [
                                                Expanded(
                                                  child: GestureDetector(
                                                    onTap: () {
                                                      context
                                                          .read<
                                                              SelectedAssets>()
                                                          .setCurrentIhai(
                                                              ihaiPath);
                                                    },
                                                    child: Container(
                                                      decoration: BoxDecoration(
                                                        borderRadius:
                                                            BorderRadius
                                                                .circular(8),
                                                        border: Border.all(
                                                          color: isCurrent
                                                              ? highlightColor
                                                              : Colors
                                                                  .transparent,
                                                          width:
                                                              isCurrent ? 2 : 0,
                                                        ),
                                                      ),
                                                      child: ClipRRect(
                                                        borderRadius:
                                                            BorderRadius
                                                                .circular(8),
                                                        child: Image.asset(
                                                            ihaiPath,
                                                            fit:
                                                                BoxFit.contain),
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                                IconButton(
                                                  icon:
                                                      const Icon(Icons.delete),
                                                  onPressed: () {
                                                    context
                                                        .read<SelectedAssets>()
                                                        .removeIhai(ihaiPath);
                                                  },
                                                ),
                                              ],
                                            ),
                                          );
                                        }),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  @override
  void dispose() {
    _disposeBgVideo();
    super.dispose();
  }
}

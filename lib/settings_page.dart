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
  List<String> _effectList = []; // effect 用

  bool _loadingAssets = true;

  VideoPlayerController? _effectController;
  bool _effectInitialized = false;
  String? _selectedEffect; // 選択中のエフェクト動画

  // 位牌テンプレート選択用
  String? _currentIhaiTemplate;

  @override
  void initState() {
    super.initState();
    _loadAssetLists();
  }

  // エフェクト動画の初期化（選び直しにも使う）
  Future<void> _initEffectVideo(String assetPath) async {
    // 既存コントローラがあれば破棄
    await _effectController?.dispose();
    _effectController = null;
    _effectInitialized = false;

    final controller = VideoPlayerController.asset(assetPath);
    try {
      await controller.initialize();
      await controller.setLooping(true);
      await controller.setVolume(0);
      await controller.play();

      if (!mounted) return;
      setState(() {
        _effectController = controller;
        _effectInitialized = true;
        _selectedEffect = assetPath;
      });
    } catch (_) {
      await controller.dispose();
    }
  }

  /// AssetManifest.json を読み取り、assets/bg/, assets/butsudan/, assets/ihai/, assets/effect/ を抽出
  Future<void> _loadAssetLists() async {
    try {
      final manifestJson = await rootBundle.loadString('AssetManifest.json');
      final Map<String, dynamic> manifest = json.decode(manifestJson);

      // すべてのアセットパス
      final allPaths = manifest.keys.cast<String>();

      // 画像拡張子のみ
      bool isImage(String p) {
        final lp = p.toLowerCase();
        return lp.endsWith('.png') ||
            lp.endsWith('.jpg') ||
            lp.endsWith('.jpeg') ||
            lp.endsWith('.webp');
      }

      // 動画拡張子のみ
      bool isVideo(String p) {
        final lp = p.toLowerCase();
        return lp.endsWith('.mp4') ||
            lp.endsWith('.mov') ||
            lp.endsWith('.webm');
      }

      List<String> filterImages(String prefix) =>
          allPaths.where((p) => p.startsWith(prefix) && isImage(p)).toList()
            ..sort();

      List<String> filterVideos(String prefix) =>
          allPaths.where((p) => p.startsWith(prefix) && isVideo(p)).toList()
            ..sort();

      final bg = filterImages('assets/bg/');
      final butsudan = filterImages('assets/butsudan/');
      final ihai = filterImages('assets/ihai/');
      final effects = filterVideos('assets/effect/');

      if (!mounted) return;
      setState(() {
        _bgList = bg.isNotEmpty
            ? bg
            : const [
                'assets/bg/bg1.jpg',
                'assets/bg/bg2.jpg',
                'assets/bg/bg3.jpg',
              ];
        _butsudanList = butsudan.isNotEmpty
            ? butsudan
            : const [
                'assets/butsudan/butsudan-karaki.png',
                'assets/butsudan/butsudan-eva.png',
                'assets/butsudan/butsudan-modan.png',
              ];
        _ihaiCandidates = ihai.isNotEmpty
            ? ihai
            : const [
                'assets/ihai/ihai1.png',
                'assets/ihai/ihai2.png',
              ];
        _currentIhaiTemplate ??=
            _ihaiCandidates.isNotEmpty ? _ihaiCandidates.first : null;
        _effectList = effects;
        _loadingAssets = false;
      });

      // ★ 前回の選択を尊重してエフェクトを決定
      final sel = context.read<SelectedAssets>();
      final savedEffect = sel.effectAsset;

      String? initialEffect;

      // 1) app_state に保存されているエフェクトが存在し、それが effects に含まれていればそれを使う
      if (savedEffect != null && effects.contains(savedEffect)) {
        initialEffect = savedEffect;
      }
      // 2) まだ何も選ばれておらず、effects が空でなければ先頭を初期値にする
      else if (savedEffect == null && effects.isNotEmpty) {
        initialEffect = effects.first;
        sel.setEffectAsset(initialEffect); // 初回だけデフォルトを保存
      }

      // 3) 初期表示すべきエフェクトが決まっていれば、プレビュー用に初期化
      if (initialEffect != null) {
        await _initEffectVideo(initialEffect);
      }
    } catch (e) {
      if (!mounted) return;
      // 読み込み失敗時は画像系だけ固定値、エフェクトは空
      setState(() {
        _bgList = const [
          'assets/bg/bg1.jpg',
          'assets/bg/bg2.jpg',
          'assets/bg/bg3.jpg',
        ];
        _butsudanList = const [
          'assets/butsudan/butsudan-karaki.png',
          'assets/butsudan/butsudan-eva.png',
          'assets/butsudan/butsudan-modan.png',
        ];
        _ihaiCandidates = const [
          'assets/ihai/ihai1.png',
          'assets/ihai/ihai2.png',
        ];
        _currentIhaiTemplate ??=
            _ihaiCandidates.isNotEmpty ? _ihaiCandidates.first : null;
        _effectList = const [];
        _loadingAssets = false;
      });
    }
  }

  /// 画像ファイルを読み込み、Uint8List にする
  Future<Uint8List?> _pickImageBytes() async {
    final picker = ImagePicker();
    final picked =
        await picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (picked == null) return null;
    return await picked.readAsBytes();
  }

  @override
  Widget build(BuildContext context) {
    final sel = context.watch<SelectedAssets>();

    // シニアにも見やすいハイライト色＆エフェクトタイル用サイズ定数
    const highlightColor = Color(0xFFCC7A00); // 落ち着いたオレンジ
    const double effectRowHeight = 100.0;
    const double effectTileBaseWidth = 140.0;
    const double effectTileHeight = effectRowHeight * 0.7; // 高さ 70%
    const double effectTileWidth = effectTileBaseWidth * 0.9; // 幅 90%

    // プレビュー用の位牌パス（選択中テンプレート最優先）
    final previewIhaiPath = _currentIhaiTemplate ??
        (sel.ihaiList.isNotEmpty
            ? sel.ihaiList.last
            : (_ihaiCandidates.isNotEmpty
                ? _ihaiCandidates.first
                : 'assets/ihai/ihai1.png'));

    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final totalH = constraints.maxHeight;
            final previewH = totalH / 3; // 上部プレビューは画面高の1/3固定

            return Column(
              children: [
                // ===== 上部プレビュー（固定 1/3）=====
                SizedBox(
                  height: previewH,
                  width: double.infinity,
                  child: ClipRect(
                    child: Container(
                      // ★ 若竹色系
                      color: const Color(0xFFDFF3E3),
                      // 枠の「内側」に上下の余白をつける
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 14.0),
                        child: Stack(
                          children: [
                            // 1) 背景：一番奥
                            if (sel.hasCustomBg && sel.bgBytes != null)
                              Align(
                                alignment: Alignment.center,
                                child: Image.memory(
                                  sel.bgBytes!,
                                  fit: BoxFit.fitHeight,
                                  width: double.infinity,
                                ),
                              )
                            else
                              Align(
                                alignment: Alignment.center,
                                child: Image.asset(
                                  sel.bgAsset,
                                  fit: BoxFit.fitHeight,
                                  width: double.infinity,
                                ),
                              ),

                            // 2) エフェクト動画（背景の一つ手前）
                            if (_effectInitialized && _effectController != null)
                              Align(
                                alignment: Alignment.center,
                                child: IgnorePointer(
                                  ignoring: true, // タップは背面に通す
                                  child: SizedBox.expand(
                                    child: FittedBox(
                                      // ★ 横幅優先 cover → 縦優先 fitHeight に変更
                                      fit: BoxFit.fitHeight,
                                      child: SizedBox(
                                        width:
                                            _effectController!.value.size.width,
                                        height: _effectController!
                                            .value.size.height,
                                        child: Opacity(
                                          opacity: 0.4, // 透け具合（0.0〜1.0）
                                          child:
                                              VideoPlayer(_effectController!),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),

                            // 3) 仏壇：エフェクトより手前
                            Align(
                              alignment: Alignment.bottomCenter,
                              child: FractionallySizedBox(
                                heightFactor: 0.9,
                                child: Image.asset(
                                  sel.butsudan,
                                  fit: BoxFit.contain,
                                ),
                              ),
                            ),

                            // 4) 位牌：一番手前
                            Center(
                              child: FractionallySizedBox(
                                heightFactor: 0.45,
                                child: Image.asset(
                                  previewIhaiPath,
                                  fit: BoxFit.contain,
                                ),
                              ),
                            ),

                            // 5) 左上の「プレビュー」和風ボタン風ラベル
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
                                    width: 1.5,
                                  ),
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

                // ===== 下部セレクション（残り 2/3 をスクロール）=====
                Expanded(
                  child: _loadingAssets
                      ? const Center(child: CircularProgressIndicator())
                      : SingleChildScrollView(
                          child: Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // ---------- 背景選択 ----------
                                const Text(
                                  '背景選択',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                SizedBox(
                                  height: 120,
                                  child: SingleChildScrollView(
                                    scrollDirection: Axis.horizontal,
                                    child: Row(
                                      children: [
                                        // カスタム背景がある場合のサムネイル
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
                                                  width: 2,
                                                ),
                                              ),
                                              child: ClipRRect(
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                                child: Stack(
                                                  children: [
                                                    Positioned.fill(
                                                      child: Image.memory(
                                                        sel.bgBytes!,
                                                        fit: BoxFit.cover,
                                                      ),
                                                    ),
                                                    const Positioned(
                                                      right: 4,
                                                      top: 4,
                                                      child: Icon(
                                                        Icons.check_circle,
                                                        color: Colors.green,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          ),

                                        // 通常背景
                                        ..._bgList.map((bgPath) {
                                          final isSelected =
                                              sel.bgAsset == bgPath &&
                                                  !sel.hasCustomBg;
                                          return GestureDetector(
                                            onTap: () {
                                              context
                                                  .read<SelectedAssets>()
                                                  .setBgAsset(bgPath);
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
                                                child: Image.asset(
                                                  bgPath,
                                                  fit: BoxFit.cover,
                                                ),
                                              ),
                                            ),
                                          );
                                        }),

                                        // 「背景画像を追加」ボタン（アイコンのみ）
                                        GestureDetector(
                                          onTap: () async {
                                            final bytes =
                                                await _pickImageBytes();
                                            if (bytes != null &&
                                                bytes.isNotEmpty) {
                                              if (!mounted) return;
                                              context
                                                  .read<SelectedAssets>()
                                                  .setBgCustom(bytes);
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
                                              child: Icon(
                                                Icons.add_a_photo,
                                                size: 32,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),

                                const SizedBox(height: 16),

                                // ---------- エフェクト選択 ----------
                                if (_effectList.isNotEmpty) ...[
                                  const Text(
                                    'エフェクト選択',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  SizedBox(
                                    height: effectRowHeight,
                                    child: SingleChildScrollView(
                                      scrollDirection: Axis.horizontal,
                                      child: Row(
                                        children: [
                                          // 「なし」ボタン
                                          GestureDetector(
                                            onTap: () async {
                                              await _effectController
                                                  ?.dispose();
                                              if (!mounted) return;
                                              setState(() {
                                                _effectController = null;
                                                _effectInitialized = false;
                                                _selectedEffect = null;
                                              });
                                              context
                                                  .read<SelectedAssets>()
                                                  .setEffectAsset(null);
                                            },
                                            child: Container(
                                              width: effectTileWidth,
                                              height: effectTileHeight,
                                              margin: const EdgeInsets.only(
                                                  right: 8),
                                              decoration: BoxDecoration(
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                                border: Border.all(
                                                  color: _selectedEffect == null
                                                      ? highlightColor
                                                      : Colors.grey,
                                                  width: _selectedEffect == null
                                                      ? 2
                                                      : 1,
                                                ),
                                              ),
                                              child: const Center(
                                                child: Text(
                                                  'なし',
                                                  textAlign: TextAlign.center,
                                                ),
                                              ),
                                            ),
                                          ),

                                          // エフェクト動画の候補
                                          ..._effectList.map((effectPath) {
                                            final isSelected =
                                                _selectedEffect == effectPath;
                                            return GestureDetector(
                                              onTap: () {
                                                _initEffectVideo(effectPath);
                                                context
                                                    .read<SelectedAssets>()
                                                    .setEffectAsset(effectPath);
                                              },
                                              child: Container(
                                                width: effectTileWidth,
                                                height: effectTileHeight,
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
                                                child: Column(
                                                  mainAxisAlignment:
                                                      MainAxisAlignment.center,
                                                  children: [
                                                    const Icon(
                                                      Icons.movie,
                                                      size: 26,
                                                    ),
                                                    const SizedBox(height: 4),
                                                    Text(
                                                      effectPath
                                                          .split('/')
                                                          .last,
                                                      textAlign:
                                                          TextAlign.center,
                                                      style: const TextStyle(
                                                          fontSize: 11),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            );
                                          }),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],

                                const SizedBox(height: 16),

                                // ---------- 仏壇選択 ----------
                                const Text(
                                  '仏壇選択',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                SizedBox(
                                  height: 140, // 余裕を持たせて はみ出しを見せる
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
                                            height: 120, // 枠高さは120
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
                                            // 仏壇画像を 120% 表示して枠から少しはみ出す
                                            child: Transform.scale(
                                              scale: 1.2,
                                              child: Image.asset(
                                                butsudanPath,
                                                fit: BoxFit.contain,
                                              ),
                                            ),
                                          ),
                                        );
                                      }).toList(),
                                    ),
                                  ),
                                ),

                                const SizedBox(height: 16),

                                // ---------- 位牌テンプレート選択 ----------
                                const Text(
                                  '位牌選択',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                SizedBox(
                                  height: 120,
                                  child: SingleChildScrollView(
                                    scrollDirection: Axis.horizontal,
                                    child: Row(
                                      children: _ihaiCandidates.map((ihaiPath) {
                                        final isSelected =
                                            _currentIhaiTemplate == ihaiPath;
                                        return GestureDetector(
                                          onTap: () {
                                            setState(() {
                                              _currentIhaiTemplate = ihaiPath;
                                            });
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
                                              child: Image.asset(
                                                ihaiPath,
                                                fit: BoxFit.contain,
                                              ),
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
                                      final template = _currentIhaiTemplate ??
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
                                  '現在の位牌（削除できます）',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
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
                                          return Container(
                                            width: 120,
                                            margin:
                                                const EdgeInsets.only(right: 8),
                                            child: Column(
                                              children: [
                                                Expanded(
                                                  child: ClipRRect(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            8),
                                                    child: Image.asset(
                                                      ihaiPath,
                                                      fit: BoxFit.contain,
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
    _effectController?.dispose();
    super.dispose();
  }
}

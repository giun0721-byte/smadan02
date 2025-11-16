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

    // プレビュー用の位牌パス（カスタムがあればそれが優先）
    final previewIhaiPath = sel.ihaiList.isNotEmpty
        ? sel.ihaiList.first
        : (_ihaiCandidates.isNotEmpty
            ? _ihaiCandidates.first
            : 'assets/ihai/ihai1.png');

    return Scaffold(
      appBar: AppBar(title: const Text('設定')),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final totalH = constraints.maxHeight;
          final previewH = totalH / 3; // 上部プレビューは画面高の1/3固定

          return Column(
            children: [
              // ===== 上部プレビュー（固定 1/3）=====
              SizedBox(
                height: previewH,
                width: double.infinity,
                child: Container(
                  color: Colors.black12,
                  child: Stack(
                    children: [
                      // 1) 背景：一番奥
                      if (sel.hasCustomBg && sel.bgBytes != null)
                        Align(
                          alignment: Alignment.center,
                          child: Image.memory(
                            sel.bgBytes!,
                            height: previewH,
                            fit: BoxFit.fitHeight,
                          ),
                        )
                      else
                        Align(
                          alignment: Alignment.center,
                          child: Image.asset(
                            sel.bgAsset,
                            height: previewH,
                            fit: BoxFit.fitHeight,
                          ),
                        ),

                      // 2) エフェクト動画（背景の一つ手前）
                      if (_effectInitialized && _effectController != null)
                        Align(
                          alignment: Alignment.center,
                          child: IgnorePointer(
                            ignoring: true, // タップは背面に通す
                            child: SizedBox(
                              height: previewH, // プレビューの高さ100%
                              child: AspectRatio(
                                aspectRatio:
                                    _effectController!.value.aspectRatio,
                                child: Opacity(
                                  opacity: 0.4, // 透け具合（0.0〜1.0）
                                  child: VideoPlayer(_effectController!),
                                ),
                              ),
                            ),
                          ),
                        ),

                      // 3) 仏壇：エフェクトより手前
                      Align(
                        alignment: Alignment.bottomCenter, // 下端中央に配置
                        child: FractionallySizedBox(
                          heightFactor: 0.95, // 画面高さの95%
                          child: Image.asset(
                            sel.butsudan,
                            fit: BoxFit.contain,
                          ),
                        ),
                      ),

                      // 4) 位牌：一番手前（1枚だけ・枚数は反映しない）
                      Center(
                        child: Image.asset(
                          previewIhaiPath,
                          height: previewH * 0.45,
                          fit: BoxFit.contain,
                        ),
                      ),
                    ],
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
                              // ---------- 背景を選ぶ ----------
                              const Text(
                                '背景を選ぶ',
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
                                          onTap: () {
                                            // カスタム背景を選択状態にする（状態は特に不要）
                                          },
                                          onLongPress: () {
                                            // 長押しでカスタム背景を解除
                                            context
                                                .read<SelectedAssets>()
                                                .clearCustomBg();
                                          },
                                          child: Container(
                                            width: 160,
                                            margin:
                                                const EdgeInsets.only(right: 8),
                                            decoration: BoxDecoration(
                                              border: Border.all(
                                                color: Colors.green,
                                                width: 2,
                                              ),
                                            ),
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
                                            margin:
                                                const EdgeInsets.only(right: 8),
                                            decoration: BoxDecoration(
                                              border: Border.all(
                                                color: isSelected
                                                    ? Colors.blueAccent
                                                    : Colors.grey,
                                                width: isSelected ? 2 : 1,
                                              ),
                                            ),
                                            child: Image.asset(
                                              bgPath,
                                              fit: BoxFit.cover,
                                            ),
                                          ),
                                        );
                                      }),

                                      // 「背景画像を追加」ボタン
                                      GestureDetector(
                                        onTap: () async {
                                          final bytes = await _pickImageBytes();
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
                                          color: Colors.grey.shade300,
                                          child: const Center(
                                            child: Column(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(Icons.add_a_photo),
                                                SizedBox(height: 4),
                                                Text('背景画像を追加'),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),

                              const SizedBox(height: 16),

                              // ---------- エフェクト（動画）を選ぶ ----------
                              if (_effectList.isNotEmpty) ...[
                                const Text(
                                  'エフェクト（動画）を選ぶ',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                SizedBox(
                                  height: 100,
                                  child: SingleChildScrollView(
                                    scrollDirection: Axis.horizontal,
                                    child: Row(
                                      children: [
                                        // エフェクトなし
                                        GestureDetector(
                                          onTap: () async {
                                            await _effectController?.dispose();
                                            if (!mounted) return;
                                            setState(() {
                                              _effectController = null;
                                              _effectInitialized = false;
                                              _selectedEffect = null;
                                            });

                                            // HOME にも「エフェクトなし」と伝える
                                            context
                                                .read<SelectedAssets>()
                                                .setEffectAsset(null);
                                          },
                                          child: Container(
                                            width: 140,
                                            margin:
                                                const EdgeInsets.only(right: 8),
                                            decoration: BoxDecoration(
                                              border: Border.all(
                                                color: _selectedEffect == null
                                                    ? Colors.blueAccent
                                                    : Colors.grey,
                                                width: _selectedEffect == null
                                                    ? 2
                                                    : 1,
                                              ),
                                            ),
                                            child: const Center(
                                              child: Text(
                                                'エフェクトなし',
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
                                              // HOME 用にも選択されたエフェクトパスを共有
                                              context
                                                  .read<SelectedAssets>()
                                                  .setEffectAsset(effectPath);
                                            },
                                            child: Container(
                                              width: 140,
                                              margin: const EdgeInsets.only(
                                                  right: 8),
                                              decoration: BoxDecoration(
                                                border: Border.all(
                                                  color: isSelected
                                                      ? Colors.blueAccent
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
                                                    size: 30,
                                                  ),
                                                  const SizedBox(height: 4),
                                                  Text(
                                                    effectPath.split('/').last,
                                                    textAlign: TextAlign.center,
                                                    style: const TextStyle(
                                                        fontSize: 12),
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

                              // ---------- 仏壇を選ぶ ----------
                              const Text(
                                '仏壇を選ぶ',
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
                                    children: _butsudanList.map((butsudanPath) {
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
                                          margin:
                                              const EdgeInsets.only(right: 8),
                                          decoration: BoxDecoration(
                                            border: Border.all(
                                              color: isSelected
                                                  ? Colors.blueAccent
                                                  : Colors.grey,
                                              width: isSelected ? 2 : 1,
                                            ),
                                          ),
                                          child: Image.asset(
                                            butsudanPath,
                                            fit: BoxFit.contain,
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
                                '位牌を選ぶ（テンプレート）',
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
                                            border: Border.all(
                                              color: isSelected
                                                  ? Colors.blueAccent
                                                  : Colors.grey,
                                              width: isSelected ? 2 : 1,
                                            ),
                                          ),
                                          child: Image.asset(
                                            ihaiPath,
                                            fit: BoxFit.contain,
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
                                                child: Image.asset(
                                                  ihaiPath,
                                                  fit: BoxFit.contain,
                                                ),
                                              ),
                                              IconButton(
                                                icon: const Icon(Icons.delete),
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
    );
  }

  @override
  void dispose() {
    _effectController?.dispose();
    super.dispose();
  }
}

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

  // ===== 仏具（_f.png）の存在確認キャッシュ =====
  final Map<String, bool> _assetExistsCache = <String, bool>{};
  String? _currentButsuguPath; // 選択中仏壇に対応する仏具パス（存在する場合のみ）
  String? _lastCheckedButsudan; // 直近チェックした仏壇パス

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

  /// 仏壇パス "xxx.png" -> 仏具パス "xxx_f.png"
  /// png以外は基本想定しないが、一応拡張子チェック。
  String? _deriveButsuguPath(String butsudanPath) {
    final lower = butsudanPath.toLowerCase();
    if (!lower.endsWith('.png')) return null;

    // "xxx.png" -> "xxx_f.png"
    return butsudanPath.substring(0, butsudanPath.length - 4) + '_f.png';
  }

  /// assets に存在するか（rootBundle.load で確認）
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

  /// assets/asset_index.json を読み取り、
  /// assets/bg/, assets/butsudan/, assets/ihai/, assets/effect/ を抽出
  Future<void> _loadAssetLists() async {
    try {
      debugPrint('=== _loadAssetLists: read assets/asset_index.json ===');

      // 1) 事前に生成した asset_index.json を読み込む
      final jsonStr = await rootBundle.loadString('assets/asset_index.json');
      final Map<String, dynamic> index =
          json.decode(jsonStr) as Map<String, dynamic>;

      // 2) 各カテゴリを取り出し（無ければ空リスト）
      List<String> asStringList(String key) {
        final v = index[key];
        if (v is List) {
          return v.map((e) => e.toString()).toList()..sort();
        }
        return <String>[];
      }

      final bg = asStringList('bg');
      final butsudan = asStringList('butsudan');
      final ihai = asStringList('ihai');
      final effects = asStringList('effect');

      debugPrint('=== bg from index: $bg');
      debugPrint('=== butsudan from index: $butsudan');
      debugPrint('=== ihai from index: $ihai');
      debugPrint('=== effects from index: $effects');

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
                'assets/ihai/ihai01.png',
                'assets/ihai/ihai02.png',
                'assets/ihai/ihai03.png',
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

      if (savedEffect != null && effects.contains(savedEffect)) {
        initialEffect = savedEffect;
        debugPrint('=== initialEffect from savedEffect: $initialEffect');
      } else if (savedEffect == null && effects.isNotEmpty) {
        initialEffect = effects.first;
        debugPrint('=== initialEffect from first effects: $initialEffect');
        sel.setEffectAsset(initialEffect); // 初回だけデフォルトを保存
      } else {
        debugPrint(
            '=== no initialEffect decided (savedEffect: $savedEffect, effects.isEmpty: ${effects.isEmpty})');
      }

      if (initialEffect != null) {
        await _initEffectVideo(initialEffect);
      }

      // ★ 仏具（_f.png）も初期同期
      await _syncButsuguForButsudan(sel.butsudan);

      debugPrint('=== _loadAssetLists: end (index OK) ===');
    } catch (e, st) {
      debugPrint('=== _loadAssetLists ERROR (index): $e ===');
      debugPrint('=== stacktrace: $st ===');

      if (!mounted) return;
      setState(() {
        _bgList = const [
          'assets/bg/bg1.jpg',
          'assets/bg/bg2.jpg',
        ];
        _butsudanList = const [
          'assets/butsudan/butsudan-karaki.png',
          'assets/butsudan/butsudan-eva.png',
        ];

        _ihaiCandidates = const [
          'assets/ihai/ihai01.png',
          'assets/ihai/ihai02.png',
        ];
        _currentIhaiTemplate ??=
            _ihaiCandidates.isNotEmpty ? _ihaiCandidates.first : null;

        _effectList = const [
          'assets/effect/comet.mp4',
          'assets/effect/leafs.mp4',
        ];

        _loadingAssets = false;
      });

      // ★ フォールバック時も仏具同期
      final sel = context.read<SelectedAssets>();
      await _syncButsuguForButsudan(sel.butsudan);

      debugPrint('=== _loadAssetLists: end (fallback) ===');
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

    // ★ 仏壇が切り替わったら、次フレームで仏具（_f.png）存在チェックを走らせる
    if (_lastCheckedButsudan != sel.butsudan) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _syncButsuguForButsudan(sel.butsudan);
      });
    }

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
                : 'assets/ihai/ihai01.png'));

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
                      color: const Color(0xFFDFF3E3),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 14.0),
                        child: Stack(
                          children: [
                            // 0) 背景：最背面
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

                            // 1) エフェクト動画（背景の手前・一番奥）
                            if (_effectInitialized && _effectController != null)
                              Align(
                                alignment: Alignment.center,
                                child: IgnorePointer(
                                  ignoring: true,
                                  child: SizedBox.expand(
                                    child: FittedBox(
                                      fit: BoxFit.fitHeight,
                                      child: SizedBox(
                                        width:
                                            _effectController!.value.size.width,
                                        height: _effectController!
                                            .value.size.height,
                                        child: Opacity(
                                          opacity: 0.4,
                                          child:
                                              VideoPlayer(_effectController!),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),

                            // 2) 仏壇メイン画像（エフェクトの手前）
                            Align(
                              alignment: Alignment.bottomCenter,
                              child: FractionallySizedBox(
                                heightFactor: 1.0, // ★ プレビュー枠の縦100%
                                child: Image.asset(
                                  sel.butsudan,
                                  fit: BoxFit.fitHeight, // ★ 縦優先（横は見切れてOK）
                                  alignment: Alignment.bottomCenter,
                                ),
                              ),
                            ),

                            // 3) 位牌画像（仏壇メインの手前）
                            Center(
                              child: FractionallySizedBox(
                                heightFactor: 0.45,
                                child: Image.asset(
                                  previewIhaiPath,
                                  fit: BoxFit.contain,
                                ),
                              ),
                            ),

// 4) 仏具画像（存在する場合のみ：最前面）
//    ※仏壇と同じ「縦優先」「下基準」に揃える
                            if (_currentButsuguPath != null)
                              Align(
                                alignment: Alignment.bottomCenter,
                                child: FractionallySizedBox(
                                  heightFactor: 1.0, // プレビュー枠の縦100%
                                  child: Image.asset(
                                    _currentButsuguPath!,
                                    fit: BoxFit.fitHeight, // ★ 縦優先に統一
                                    alignment:
                                        Alignment.bottomCenter, // ★ 下基準に統一
                                  ),
                                ),
                              ),
                            // 5) 左上ラベル
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
                                            // 仏具は build 側で自動同期（addPostFrameCallback）
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

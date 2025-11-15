import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:video_player/video_player.dart';
import 'app_state.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  double _startScale = 1.0;

  // エフェクト動画用
  String? _effectPath;
  VideoPlayerController? _effectController;
  bool _effectInitialized = false;

  @override
  void dispose() {
    _effectController?.dispose();
    super.dispose();
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
                  child: FractionallySizedBox(
                    heightFactor: 0.95,
                    child: Image.asset(
                      sel.butsudan,
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
              ),

              // 4) 位牌たち（いちばん手前）
              for (int i = 0; i < ihaiItems.length; i++)
                _buildIhaiWidget(context, ihaiItems[i], i, w, h),
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

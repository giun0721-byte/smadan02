import 'package:flutter/foundation.dart';

/// 位牌1つ分の情報（画像パス＋位置＋拡大率）
class IhaiItem {
  /// 位牌画像のアセットパス
  final String assetPath;

  /// 画面幅・高さに対する相対位置（0.0〜1.0）
  /// 0.5 が中央、0.0 が左/上、1.0 が右/下
  final double centerX;
  final double centerY;

  /// 拡大率（1.0 が標準）
  final double scale;

  const IhaiItem({
    required this.assetPath,
    this.centerX = 0.5,
    this.centerY = 0.65,
    this.scale = 1.0,
  });

  IhaiItem copyWith({
    String? assetPath,
    double? centerX,
    double? centerY,
    double? scale,
  }) {
    return IhaiItem(
      assetPath: assetPath ?? this.assetPath,
      centerX: centerX ?? this.centerX,
      centerY: centerY ?? this.centerY,
      scale: scale ?? this.scale,
    );
  }
}

class SelectedAssets extends ChangeNotifier {
  // ===== 背景・仏壇 =====
  String _bgAsset = 'assets/bg/bg1.jpg';
  String _butsudan = 'assets/butsudan/butsudan-karaki.png';

  Uint8List? _bgBytes; // カスタム背景

  String get bgAsset => _bgAsset;
  String get butsudan => _butsudan;
  Uint8List? get bgBytes => _bgBytes;
  bool get hasCustomBg => _bgBytes != null;

  // ===== 位牌（複数） =====
  final List<IhaiItem> _ihaiItems = [
    const IhaiItem(assetPath: 'assets/ihai/ihai.png'),
  ];

  /// 位牌の詳細リスト（位置＆スケールつき）
  List<IhaiItem> get ihaiItems => List.unmodifiable(_ihaiItems);

  /// 互換用：単にパスだけのリスト（Settings / 表示用）
  List<String> get ihaiList =>
      _ihaiItems.map((e) => e.assetPath).toList(growable: false);

  // ===== エフェクト（動画） =====
  String? _effectAsset; // 例: 'assets/effect/leafs.mp4'
  String? get effectAsset => _effectAsset;

  // ===== 背景の更新 =====

  void setBgAsset(String path) {
    _bgAsset = path;
    _bgBytes = null; // アセットを選んだらカスタム背景は無効化
    notifyListeners();
  }

  void setBgCustom(Uint8List bytes) {
    _bgBytes = bytes;
    notifyListeners();
  }

  void clearCustomBg() {
    _bgBytes = null;
    notifyListeners();
  }

  // ===== 仏壇の更新 =====

  void setButsudan(String path) {
    _butsudan = path;
    notifyListeners();
  }

  // ===== 位牌の追加・削除・一括操作 =====

  /// 新しい位牌を追加（中心やスケールはデフォルト）
  void addIhai(String path) {
    _ihaiItems.add(IhaiItem(assetPath: path));
    notifyListeners();
  }

  /// 既存を全部消して 1 個だけにしたいとき用
  void setSingleIhai(String path) {
    _ihaiItems
      ..clear()
      ..add(IhaiItem(assetPath: path));
    notifyListeners();
  }

  /// 指定パスの位牌を全部削除（同じ画像が複数あるときは全部消える）
  void removeIhai(String path) {
    _ihaiItems.removeWhere((e) => e.assetPath == path);
    notifyListeners();
  }

  /// インデックス指定で 1 個だけ削除
  void removeIhaiAt(int index) {
    if (index < 0 || index >= _ihaiItems.length) return;
    _ihaiItems.removeAt(index);
    notifyListeners();
  }

  /// すべての位牌を削除
  void clearIhai() {
    _ihaiItems.clear();
    notifyListeners();
  }

  /// 位牌の位置・スケールを更新
  void updateIhaiTransform(
    int index, {
    double? centerX,
    double? centerY,
    double? scale,
  }) {
    if (index < 0 || index >= _ihaiItems.length) return;
    final current = _ihaiItems[index];
    _ihaiItems[index] = current.copyWith(
      centerX: centerX,
      centerY: centerY,
      scale: scale,
    );
    notifyListeners();
  }

  /// エフェクト動画のパスを設定（null で「エフェクトなし」）
  void setEffectAsset(String? path) {
    _effectAsset = path;
    notifyListeners();
  }
}

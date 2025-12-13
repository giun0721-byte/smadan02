import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 位牌1つ分の情報（画像パス＋位置＋拡大率）
class IhaiItem {
  final String assetPath;
  final double centerX;
  final double centerY;
  final double scale;

  const IhaiItem({
    required this.assetPath,
    this.centerX = 0.5,
    this.centerY = 0.7,
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

  Map<String, dynamic> toJson() => <String, dynamic>{
        'assetPath': assetPath,
        'centerX': centerX,
        'centerY': centerY,
        'scale': scale,
      };

  static IhaiItem fromJson(Map<String, dynamic> json) {
    return IhaiItem(
      assetPath: (json['assetPath'] ?? 'assets/ihai/ihai01.png') as String,
      centerX: (json['centerX'] ?? 0.5).toDouble(),
      centerY: (json['centerY'] ?? 0.7).toDouble(),
      scale: (json['scale'] ?? 1.0).toDouble(),
    );
  }
}

class SelectedAssets extends ChangeNotifier {
  // ===== prefs keys =====
  static const _kBgAsset = 'sel_bg_asset_v1';
  static const _kBgBytesB64 = 'sel_bg_bytes_b64_v1';
  static const _kButsudan = 'sel_butsudan_v1';
  static const _kIhaiItems = 'sel_ihai_items_v1';
  static const _kCurrentIhai = 'sel_current_ihai_v1';
  static const _kEffect = 'sel_effect_v1';

  bool _initialized = false;
  bool get initialized => _initialized;

  // ===== 背景・仏壇 =====
  String _bgAsset = 'assets/bg/bg1.jpg';
  String _butsudan = 'assets/butsudan/01karaki.png';
  Uint8List? _bgBytes; // カスタム背景

  String get bgAsset => _bgAsset;
  String get butsudan => _butsudan;
  Uint8List? get bgBytes => _bgBytes;
  bool get hasCustomBg => _bgBytes != null;

  // ===== 位牌（複数） =====
  final List<IhaiItem> _ihaiItems = [
    const IhaiItem(assetPath: 'assets/ihai/ihai01.png'),
  ];

  List<IhaiItem> get ihaiItems => List.unmodifiable(_ihaiItems);
  List<String> get ihaiList =>
      _ihaiItems.map((e) => e.assetPath).toList(growable: false);

  /// 現在選択中の位牌（HOME/設定 共通）
  String? _currentIhai = 'assets/ihai/ihai01.png';
  String? get currentIhai => _currentIhai;

  // ===== エフェクト（動画） =====
  String? _effectAsset;
  String? get effectAsset => _effectAsset;

  // ===== 起動時に呼ぶ：保存値を復元 =====
  Future<void> loadFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();

    _bgAsset = prefs.getString(_kBgAsset) ?? _bgAsset;
    _butsudan = prefs.getString(_kButsudan) ?? _butsudan;

    final b64 = prefs.getString(_kBgBytesB64);
    if (b64 != null && b64.isNotEmpty) {
      try {
        _bgBytes = base64Decode(b64);
      } catch (_) {
        _bgBytes = null;
      }
    } else {
      _bgBytes = null;
    }

    final ihaiJson = prefs.getString(_kIhaiItems);
    if (ihaiJson != null && ihaiJson.isNotEmpty) {
      try {
        final raw = jsonDecode(ihaiJson) as List<dynamic>;
        _ihaiItems
          ..clear()
          ..addAll(
              raw.map((e) => IhaiItem.fromJson(e as Map<String, dynamic>)));
        if (_ihaiItems.isEmpty) {
          _ihaiItems.add(const IhaiItem(assetPath: 'assets/ihai/ihai01.png'));
        }
      } catch (_) {
        // 壊れていたら既定のまま
      }
    }

    // ===== 現在選択中の位牌（currentIhai）復元 =====
    final savedCurrent = prefs.getString(_kCurrentIhai);
    final existingPaths = _ihaiItems.map((e) => e.assetPath).toList();
    if (savedCurrent != null &&
        savedCurrent.isNotEmpty &&
        existingPaths.contains(savedCurrent)) {
      _currentIhai = savedCurrent;
    } else {
      _currentIhai = existingPaths.isNotEmpty ? existingPaths.last : null;
    }

    final eff = prefs.getString(_kEffect);
    _effectAsset = (eff == null || eff.isEmpty) ? null : eff;

    _initialized = true;
    notifyListeners();
  }

  Future<void> _saveToPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kBgAsset, _bgAsset);
    await prefs.setString(_kButsudan, _butsudan);

    if (_bgBytes != null) {
      await prefs.setString(_kBgBytesB64, base64Encode(_bgBytes!));
    } else {
      await prefs.remove(_kBgBytesB64);
    }

    await prefs.setString(
      _kIhaiItems,
      jsonEncode(_ihaiItems.map((e) => e.toJson()).toList()),
    );

    // 現在選択中の位牌
    if (_currentIhai == null) {
      await prefs.remove(_kCurrentIhai);
    } else {
      await prefs.setString(_kCurrentIhai, _currentIhai!);
    }

    if (_effectAsset == null) {
      await prefs.remove(_kEffect);
    } else {
      await prefs.setString(_kEffect, _effectAsset!);
    }
  }

  // ===== 背景 =====
  void setBgAsset(String path) {
    _bgAsset = path;
    _bgBytes = null;
    notifyListeners();
    _saveToPrefs();
  }

  void setBgCustom(Uint8List bytes) {
    _bgBytes = bytes;
    notifyListeners();
    _saveToPrefs();
  }

  void clearCustomBg() {
    _bgBytes = null;
    notifyListeners();
    _saveToPrefs();
  }

  // ===== 仏壇 =====
  void setButsudan(String path) {
    _butsudan = path;
    notifyListeners();
    _saveToPrefs();
  }

  // ===== 位牌 =====
  void addIhai(String path) {
    double cx = 0.5, cy = 0.65, scale = 1.0;
    if (_ihaiItems.isNotEmpty) {
      final last = _ihaiItems.last;
      cx = last.centerX;
      cy = last.centerY;
      scale = last.scale;
    }
    _ihaiItems
        .add(IhaiItem(assetPath: path, centerX: cx, centerY: cy, scale: scale));
    _currentIhai = path;
    notifyListeners();
    _saveToPrefs();
  }

  void setSingleIhai(String path) {
    _ihaiItems
      ..clear()
      ..add(IhaiItem(assetPath: path, centerX: 0.5, centerY: 0.7, scale: 1.0));
    _currentIhai = path;
    notifyListeners();
    _saveToPrefs();
  }

  void removeIhai(String path) {
    _ihaiItems.removeWhere((e) => e.assetPath == path);
    if (_ihaiItems.isEmpty) {
      _ihaiItems.add(const IhaiItem(assetPath: 'assets/ihai/ihai01.png'));
    }

    // currentIhai が消えたら、末尾へフォールバック
    if (_currentIhai == path) {
      _currentIhai = _ihaiItems.isNotEmpty ? _ihaiItems.last.assetPath : null;
    }

    notifyListeners();
    _saveToPrefs();
  }

  /// 現在選択中の位牌を変更（HOME/設定 共通）
  /// - null を渡すと未選択
  /// - path は _ihaiItems 内に存在するものだけを許可
  void setCurrentIhai(String? path) {
    if (path == null) {
      _currentIhai = null;
      notifyListeners();
      _saveToPrefs();
      return;
    }
    final exists = _ihaiItems.any((e) => e.assetPath == path);
    if (!exists) return;
    _currentIhai = path;
    notifyListeners();
    _saveToPrefs();
  }

  void clearIhai() {
    _ihaiItems
      ..clear()
      ..add(const IhaiItem(assetPath: 'assets/ihai/ihai01.png'));
    _currentIhai = _ihaiItems.last.assetPath;
    notifyListeners();
    _saveToPrefs();
  }

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
    _saveToPrefs();
  }

  // ===== エフェクト =====
  void setEffectAsset(String? path) {
    _effectAsset = path;
    notifyListeners();
    _saveToPrefs();
  }
}

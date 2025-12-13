// tool/generate_asset_index.dart
import 'dart:io';
import 'dart:convert';

void main() {
  // スキャンするディレクトリ
  const bgDir = 'assets/bg';
  const butsudanDir = 'assets/butsudan';
  const ihaiDir = 'assets/ihai';
  // const effectDir = 'assets/effect'; // エフェクト廃止

  List<String> listFiles(
    String dirPath,
    bool Function(FileSystemEntity) filter,
  ) {
    final dir = Directory(dirPath);
    if (!dir.existsSync()) return [];

    final files = dir
        .listSync(recursive: false, followLinks: false)
        .where((e) => e is File) // ディレクトリ除外を明示（安全）
        .where(filter)
        .map((e) => e.path.replaceAll('\\', '/')) // Windows 対策
        .toList()
      ..sort();
    return files;
  }

  bool isImage(FileSystemEntity e) {
    final path = e.path.toLowerCase();
    return path.endsWith('.png') ||
        path.endsWith('.jpg') ||
        path.endsWith('.jpeg') ||
        path.endsWith('.webp');
  }

  bool isVideo(FileSystemEntity e) {
    final path = e.path.toLowerCase();
    return path.endsWith('.mp4') ||
        path.endsWith('.mov') ||
        path.endsWith('.webm');
  }

  // ★ bg は「画像＋動画」を拾う
  final bg = listFiles(bgDir, (e) => isImage(e) || isVideo(e));

  final butsudan = listFiles(butsudanDir, isImage);
  final ihai = listFiles(ihaiDir, isImage);

  final index = <String, dynamic>{
    'bg': bg,
    'butsudan': butsudan,
    'ihai': ihai,
  };

  // 出力先
  const outputPath = 'assets/asset_index.json';
  final outFile = File(outputPath);

  outFile.parent.createSync(recursive: true);

  outFile.writeAsStringSync(
    const JsonEncoder.withIndent('  ').convert(index),
  );

  print('Generated $outputPath');
  print('  bg:       ${bg.length} items (images + videos)');
  print('  butsudan: ${butsudan.length} items');
  print('  ihai:     ${ihai.length} items');
}

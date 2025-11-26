// tool/generate_asset_index.dart
import 'dart:io';
import 'dart:convert';

void main() async {
  // スキャンするディレクトリ
  const bgDir = 'assets/bg';
  const butsudanDir = 'assets/butsudan';
  const ihaiDir = 'assets/ihai';
  const effectDir = 'assets/effect';

  List<String> listFiles(
      String dirPath, bool Function(FileSystemEntity) filter) {
    final dir = Directory(dirPath);
    if (!dir.existsSync()) return [];

    final files = dir
        .listSync(recursive: false, followLinks: false)
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

  final bg = listFiles(bgDir, isImage);
  final butsudan = listFiles(butsudanDir, isImage);
  final ihai = listFiles(ihaiDir, isImage);
  final effects = listFiles(effectDir, isVideo);

  final index = <String, dynamic>{
    'bg': bg,
    'butsudan': butsudan,
    'ihai': ihai,
    'effect': effects,
  };

  // 出力先
  const outputPath = 'assets/asset_index.json';
  final outFile = File(outputPath);

  // assets フォルダが無ければ作る（通常は既にある）
  outFile.parent.createSync(recursive: true);

  outFile.writeAsStringSync(
    const JsonEncoder.withIndent('  ').convert(index),
  );

  print('Generated $outputPath');
  print('  bg:       ${bg.length} items');
  print('  butsudan: ${butsudan.length} items');
  print('  ihai:     ${ihai.length} items');
  print('  effect:   ${effects.length} items');
}

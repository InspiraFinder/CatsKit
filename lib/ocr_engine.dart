import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/services.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

/// 通用 OCR 引擎：识别图片，返回全图文字项列表。
/// 每项结构：{'text': String, 'x': int, 'y': int, 'w': int, 'h': int}
/// （坐标均为原图像素）
///
/// - Android：Google ML Kit，生成 5 张变体（原图/左右位移/蓝/红通道）合并结果
/// - 桌面/Windows：调用 assets/ocr/catskit_ocr.py（Python RapidOCR）取全图 texts
class OcrEngine {
  /// 识别图片，返回全图文字项列表
  static Future<List<Map<String, dynamic>>> recognize(File image) async {
    if (Platform.isAndroid) {
      return _runAndroidOcr(image);
    }
    return _runPythonOcr(image);
  }

  // ==================== Android: Google ML Kit ====================
  static Future<List<Map<String, dynamic>>> _runAndroidOcr(File image) async {
    if (!await image.exists()) throw Exception('图片文件不存在');

    // ML Kit 对超大图片（超过约 1280px）会内部缩放后再识别，
    // 返回的坐标是相对"缩放后图片"的，直接当作原图坐标会失真
    // （实测 3200×1440 大图 HP 行真实 y≈1278，却被压到 y≈760）。
    // 因此主动把图片等比缩放到安全尺寸（长边 <= 1280），记录缩放比，
    // 识别后把坐标按已知比例映射回原图，保证导出坐标 = 原图像素。
    final bytes = await image.readAsBytes();
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    final ow = frame.image.width;
    final oh = frame.image.height;
    codec.dispose();
    double scale = 1.0;
    File ocrSource = image;
    if (ow > 1280 || oh > 1280) {
      scale = 1280.0 / (ow > oh ? ow : oh);
      ocrSource = await _resizeImage(image, scale);
    }

    try {
      // 预处理：生成多张变体图片
      final variants = await _generateVariants(ocrSource);
      final allResults = <List<Map<String, dynamic>>>[];

      for (final variant in variants) {
        try {
          final inputImage = InputImage.fromFilePath(variant.path);
          final recognizer = TextRecognizer(
            script: TextRecognitionScript.chinese,
          );
          try {
            final RecognizedText recognizedText = await recognizer.processImage(
              inputImage,
            );
            final items = <Map<String, dynamic>>[];
            for (final block in recognizedText.blocks) {
              for (final line in block.lines) {
                items.add({
                  'text': line.text,
                  'x': line.boundingBox.left.toInt(),
                  'y': line.boundingBox.top.toInt(),
                  'w': line.boundingBox.width.toInt(),
                  'h': line.boundingBox.height.toInt(),
                });
              }
            }
            allResults.add(items);
          } finally {
            await recognizer.close();
          }
        } catch (_) {
          // 单张变体识别失败不影响整体
        }
        // 清理变体临时文件（保留原图）
        if (variant.path != image.path) {
          try {
            await variant.delete();
          } catch (_) {}
        }
      }

      // 合并各变体结果：以原图结果为主，用其他变体补充
      final merged = _mergeResults(allResults);
      // 坐标映射回原图（除以缩放比）；未缩放时 scale==1.0 保持不变
      if (scale != 1.0) {
        for (final it in merged) {
          it['x'] = ((it['x'] as num) / scale).round();
          it['y'] = ((it['y'] as num) / scale).round();
          it['w'] = ((it['w'] as num) / scale).round();
          it['h'] = ((it['h'] as num) / scale).round();
        }
      }
      return merged;
    } finally {
      // 清理缩放临时图（保留原图）
      if (ocrSource.path != image.path) {
        try {
          await ocrSource.delete();
        } catch (_) {}
      }
    }
  }

  /// 等比缩放图片到指定比例（Android 识别前缩放到安全尺寸用）
  static Future<File> _resizeImage(File image, double scale) async {
    final bytes = await image.readAsBytes();
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    final original = frame.image;
    final w = original.width;
    final h = original.height;
    final nw = (w * scale).round();
    final nh = (h * scale).round();
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);
    final paint = ui.Paint()..filterQuality = ui.FilterQuality.high;
    canvas.drawImageRect(
      original,
      ui.Rect.fromLTWH(0, 0, w.toDouble(), h.toDouble()),
      ui.Rect.fromLTWH(0, 0, nw.toDouble(), nh.toDouble()),
      paint,
    );
    final picture = recorder.endRecording();
    final scaled = await picture.toImage(nw, nh);
    final pngData = await scaled.toByteData(format: ui.ImageByteFormat.png);
    final f = File(
      '${Directory.systemTemp.path}${Platform.pathSeparator}ocr_resized_${DateTime.now().millisecondsSinceEpoch}.png',
    );
    if (pngData != null) {
      await f.writeAsBytes(pngData.buffer.asUint8List(), flush: true);
    }
    return f;
  }

  /// 预处理图片，生成变体（第 0 张为原图）
  static Future<List<File>> _generateVariants(File source) async {
    final bytes = await source.readAsBytes();
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    final original = frame.image;
    final w = original.width;
    final h = original.height;
    codec.dispose();

    final tempDir = Directory.systemTemp;
    final List<File> files = [source];

    // 获取原始 RGBA 字节
    final byteData = await original.toByteData(
      format: ui.ImageByteFormat.rawRgba,
    );
    if (byteData == null) return files;

    final srcPixels = byteData.buffer.asUint8List();

    Future<File> saveImage(ui.Image img, String suffix) async {
      final pngData = await img.toByteData(format: ui.ImageByteFormat.png);
      final f = File(
        '${tempDir.path}${Platform.pathSeparator}ocr_var_$suffix.png',
      );
      if (pngData != null) {
        await f.writeAsBytes(pngData.buffer.asUint8List(), flush: true);
      }
      return f;
    }

    Future<void> processVariant(
      String name,
      void Function(Uint8List pixels, int w2, int h2) process,
    ) async {
      final pixels = Uint8List.fromList(srcPixels);
      process(pixels, w, h);
      final img = await _pixelsToImage(pixels, w, h);
      files.add(await saveImage(img, name));
    }

    // 左移 2 像素
    await processVariant('shift_l', (p, w2, h2) {
      final s = w2 * 4;
      for (var y = 0; y < h2; y++) {
        final row = y * s;
        final left2 = p.sublist(row, row + 8);
        for (var x = 0; x < w2 - 2; x++) {
          final src = row + (x + 2) * 4;
          p[row + x * 4] = p[src];
          p[row + x * 4 + 1] = p[src + 1];
          p[row + x * 4 + 2] = p[src + 2];
          p[row + x * 4 + 3] = p[src + 3];
        }
        for (var i = 0; i < 8; i++) {
          p[row + (w2 - 2) * 4 + i] = left2[i];
        }
      }
    });

    // 右移 2 像素
    await processVariant('shift_r', (p, w2, h2) {
      final s = w2 * 4;
      for (var y = 0; y < h2; y++) {
        final row = y * s;
        final right2 = p.sublist(row + (w2 - 2) * 4, row + w2 * 4);
        for (var x = w2 - 1; x >= 2; x--) {
          final src = row + (x - 2) * 4;
          p[row + x * 4] = p[src];
          p[row + x * 4 + 1] = p[src + 1];
          p[row + x * 4 + 2] = p[src + 2];
          p[row + x * 4 + 3] = p[src + 3];
        }
        for (var i = 0; i < 8; i++) {
          p[row + i] = right2[i];
        }
      }
    });

    // 蓝色通道（只留 B）
    await processVariant('blue', (p, w2, h2) {
      for (var i = 0; i < p.length; i += 4) {
        p[i] = 0; // R = 0
        p[i + 1] = 0; // G = 0
      }
    });

    // 红色通道（只留 R）
    await processVariant('red', (p, w2, h2) {
      for (var i = 0; i < p.length; i += 4) {
        p[i + 1] = 0; // G = 0
        p[i + 2] = 0; // B = 0
      }
    });

    return files;
  }

  /// 将 RGBA 像素数据转为 ui.Image
  static Future<ui.Image> _pixelsToImage(
    Uint8List pixels,
    int w,
    int h,
  ) async {
    final completer = Completer<ui.Image>();
    ui.decodeImageFromPixels(
      pixels,
      w,
      h,
      ui.PixelFormat.rgba8888,
      (img) => completer.complete(img),
    );
    return completer.future;
  }

  /// 合并多张变体的 OCR 结果
  static List<Map<String, dynamic>> _mergeResults(
    List<List<Map<String, dynamic>>> allResults,
  ) {
    if (allResults.isEmpty) return [];
    // 以原图结果（第一组）为主
    final primary = allResults.first;
    if (primary.isEmpty && allResults.length > 1) return allResults[1];

    // 用其他变体补充原图未识别到的文字
    final seenTexts = primary.map((it) => it['text'] as String).toSet();
    for (var i = 1; i < allResults.length; i++) {
      for (final item in allResults[i]) {
        final t = item['text'] as String;
        if (!seenTexts.contains(t)) {
          primary.add(item);
          seenTexts.add(t);
        }
      }
    }
    return primary;
  }

  // ==================== 桌面: Python RapidOCR ====================
  static Future<List<Map<String, dynamic>>> _runPythonOcr(File image) async {
    final python = await _findPython();
    if (python == null) {
      throw Exception(
        '未找到可用的 Python OCR 环境（需要 rapidocr_onnxruntime / opencv-python / numpy）。'
        '请在终端执行: python -m pip install rapidocr_onnxruntime opencv-python numpy',
      );
    }
    final byteData = await rootBundle.load('assets/ocr/catskit_ocr.py');
    final tempDir = Directory.systemTemp;
    final scriptFile = File(
      '${tempDir.path}${Platform.pathSeparator}catskit_ocr.py',
    );
    await scriptFile.writeAsBytes(byteData.buffer.asUint8List(), flush: true);

    final encodedPath = base64Encode(utf8.encode(image.path));
    final result = await Process.run(python, [scriptFile.path, encodedPath]);

    if (result.exitCode != 0) {
      final stderr = result.stderr.toString().trim();
      throw Exception(
        stderr.isNotEmpty ? stderr : '进程退出码: ${result.exitCode}',
      );
    }

    final json = jsonDecode(result.stdout.toString()) as Map<String, dynamic>;
    if (json['error'] != null) throw Exception(json['error'] as String);

    final texts = json['texts'] as List<dynamic>? ?? [];
    return [
      for (final t in texts)
        {
          'text': (t as Map<String, dynamic>)['text'] as String? ?? '',
          'x': ((t['x'] as num?) ?? 0).toInt(),
          'y': ((t['y'] as num?) ?? 0).toInt(),
          'w': ((t['w'] as num?) ?? 0).toInt(),
          'h': ((t['h'] as num?) ?? 0).toInt(),
        }
    ];
  }

  /// 放大图片 scale 倍（通用工具，供需要提升 OCR 精度的模块在前处理调用）
  static Future<File> upscaleImage(File image, int scale) async {
    final bytes = await image.readAsBytes();
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    final original = frame.image;
    final w = original.width;
    final h = original.height;
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);
    final paint = ui.Paint()..filterQuality = ui.FilterQuality.high;
    canvas.drawImageRect(
      original,
      ui.Rect.fromLTWH(0, 0, w.toDouble(), h.toDouble()),
      ui.Rect.fromLTWH(0, 0, (w * scale).toDouble(), (h * scale).toDouble()),
      paint,
    );
    final picture = recorder.endRecording();
    final scaled = await picture.toImage(w * scale, h * scale);
    final pngData = await scaled.toByteData(format: ui.ImageByteFormat.png);
    final f = File(
      '${Directory.systemTemp.path}${Platform.pathSeparator}ocr_scaled_${DateTime.now().millisecondsSinceEpoch}.png',
    );
    if (pngData != null) {
      await f.writeAsBytes(pngData.buffer.asUint8List(), flush: true);
    }
    return f;
  }

  /// 找一个可用的 Python（能 import rapidocr_onnxruntime 与 cv2）
  static Future<String?> _findPython() async {
    final candidates = <String>['python'];
    for (final py in candidates) {
      try {
        final r = await Process.run(
          py,
          ['-c', 'import rapidocr_onnxruntime, cv2'],
        );
        if (r.exitCode == 0) return py;
      } catch (_) {}
    }
    return null;
  }
}

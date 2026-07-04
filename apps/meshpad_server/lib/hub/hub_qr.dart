import 'package:image/image.dart' as img;
import 'package:qr/qr.dart';

/// Builds a [QrCode] for [data], picking the smallest version that fits.
QrCode buildQrCode(String data) {
  for (var version = 5; version <= 20; version++) {
    try {
      final code = QrCode(version, QrErrorCorrectLevel.M)..addData(data);
      QrImage(code);
      return code;
    } on InputTooLongException {
      continue;
    }
  }
  for (var version = 5; version <= 40; version++) {
    try {
      final code = QrCode(version, QrErrorCorrectLevel.L)..addData(data);
      QrImage(code);
      return code;
    } on InputTooLongException {
      continue;
    }
  }
  throw StateError('QR payload too long');
}

/// PNG bytes for pairing QR (reliable in mobile browsers).
List<int> qrDataToPng(String data, {int size = 240}) {
  final qrImage = QrImage(buildQrCode(data));
  final count = qrImage.moduleCount;
  final image = img.Image(width: size, height: size);
  img.fill(image, color: img.ColorRgb8(255, 255, 255));

  final moduleSize = size ~/ count;
  final offset = (size - moduleSize * count) ~/ 2;

  for (var row = 0; row < count; row++) {
    for (var col = 0; col < count; col++) {
      if (!qrImage.isDark(row, col)) continue;
      final x0 = offset + col * moduleSize;
      final y0 = offset + row * moduleSize;
      for (var dy = 0; dy < moduleSize; dy++) {
        for (var dx = 0; dx < moduleSize; dx++) {
          image.setPixel(x0 + dx, y0 + dy, img.ColorRgb8(0, 0, 0));
        }
      }
    }
  }

  return img.encodePng(image);
}

/// SVG with explicit pixel size (fallback).
String qrDataToSvg(String data, {int size = 240}) {
  final qrImage = QrImage(buildQrCode(data));
  final count = qrImage.moduleCount;
  final moduleSize = size ~/ count;
  final dim = moduleSize * count;

  final sb = StringBuffer()
    ..writeln(
      '<svg xmlns="http://www.w3.org/2000/svg" '
      'width="$size" height="$size" viewBox="0 0 $dim $dim" '
      'shape-rendering="crispEdges">',
    )
    ..writeln('<rect width="$dim" height="$dim" fill="#ffffff"/>');

  for (var row = 0; row < count; row++) {
    for (var col = 0; col < count; col++) {
      if (!qrImage.isDark(row, col)) continue;
      final x = col * moduleSize;
      final y = row * moduleSize;
      sb.writeln(
        '<rect x="$x" y="$y" width="$moduleSize" height="$moduleSize" fill="#000000"/>',
      );
    }
  }

  sb.write('</svg>');
  return sb.toString();
}

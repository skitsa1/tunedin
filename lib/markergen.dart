import 'dart:async';
import 'dart:ui' as ui;
import 'dart:io';
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

Future<BitmapDescriptor> getMarkerIcon(
    String imagePath, Size size, int? speed) async {
  final ui.PictureRecorder pictureRecorder = ui.PictureRecorder();
  final Canvas canvas = Canvas(pictureRecorder);

  final Radius radius = Radius.circular(size.width / 2);

  final Paint tagPaint = Paint()..color = Colors.blue;
  const double tagWidth = 40.0;

  final Paint shadowPaint = Paint()..color = Colors.blue.withAlpha(100);
  const double shadowWidth = 15.0;

  final Paint borderPaint = Paint()..color = Colors.white;
  const double borderWidth = 3.0;

  const double imageOffset = shadowWidth + borderWidth;

  // Add shadow circle
  canvas.drawRRect(
      RRect.fromRectAndCorners(
        Rect.fromLTWH(0.0, 0.0, size.width, size.height),
        topLeft: radius,
        topRight: radius,
        bottomLeft: radius,
        bottomRight: radius,
      ),
      shadowPaint);

  // Add border circle
  canvas.drawRRect(
      RRect.fromRectAndCorners(
        Rect.fromLTWH(shadowWidth, shadowWidth, size.width - (shadowWidth * 2),
            size.height - (shadowWidth * 2)),
        topLeft: radius,
        topRight: radius,
        bottomLeft: radius,
        bottomRight: radius,
      ),
      borderPaint);

  // Add tag circle
  canvas.drawRRect(
      RRect.fromRectAndCorners(
        Rect.fromLTWH(size.width - tagWidth, 0.0, tagWidth, tagWidth),
        topLeft: radius,
        topRight: radius,
        bottomLeft: radius,
        bottomRight: radius,
      ),
      tagPaint);

  // Add tag text
  TextPainter textPainter = TextPainter(textDirection: TextDirection.ltr);
  textPainter.text = TextSpan(
    text: speed.toString(),
    style: const TextStyle(
      fontSize: 25.0,
      color: Colors.white,
      fontWeight: FontWeight.bold,
    ),
  );

  textPainter.layout();
  textPainter.paint(
      canvas,
      Offset(size.width - tagWidth / 2 - textPainter.width / 2,
          tagWidth / 2 - textPainter.height / 2));

  // Oval for the image
  Rect oval = Rect.fromLTWH(imageOffset, imageOffset,
      size.width - (imageOffset * 2), size.height - (imageOffset * 2));

  // Add path for oval image
  canvas.clipPath(Path()..addOval(oval));

  // Add image
  ui.Image image = await loadImageFromAsset(
      imagePath); // Alternatively use your own method to get the image
  paintImage(canvas: canvas, image: image, rect: oval, fit: BoxFit.fitWidth);

  // Convert canvas to image
  final ui.Image markerAsImage = await pictureRecorder
      .endRecording()
      .toImage(size.width.toInt(), size.height.toInt());

  // Convert image to bytes
  final ByteData? byteData =
      await markerAsImage.toByteData(format: ui.ImageByteFormat.png);
  final Uint8List? uint8List = byteData?.buffer.asUint8List();

  return BitmapDescriptor.fromBytes(uint8List!);
}

Future<ui.Image> getImageFromPath(String imagePath) async {
  File imageFile = File(imagePath);

  Uint8List imageBytes = imageFile.readAsBytesSync();

  final Completer<ui.Image> completer = Completer();

  ui.decodeImageFromList(imageBytes, (ui.Image img) {
    return completer.complete(img);
  });

  return completer.future;
}

Future<ui.Image> loadImageFromAsset(String assetName) async {
  if (kIsWeb) {
    WidgetsFlutterBinding.ensureInitialized();
    var image = AssetImage(assetName);
    var key = await image.obtainKey(ImageConfiguration.empty);
    var stream = image.loadBuffer(
        key, PaintingBinding.instance.instantiateImageCodecFromBuffer);
    var completer = Completer<ui.Image>();
    stream.addListener(ImageStreamListener((image, synchronousCall) {
      completer.complete(image.image);
    }));
    return completer.future;
  }
  var buffer = await ImmutableBuffer.fromAsset(assetName);
  var codec = await ui.instantiateImageCodecFromBuffer(buffer);
  var frame = await codec.getNextFrame();
  return frame.image;
}

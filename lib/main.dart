// ignore_for_file: constant_identifier_names
import 'package:flutter/foundation.dart';

import 'package:camera/camera.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_ml_kit/google_ml_kit.dart';

import 'painters/grid_painter.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const Numero());
}

T _ambiguate<T>(T value) => value;

enum Control {
  start_number,
  start_barcode,
  start_qrcode,
  stop_number,
  stop_barcode,
  stop_qrcode,
  toggle_number,
  toggle_barcode,
  toggle_qrcode
}

class Numero extends StatelessWidget {
  const Numero({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'NUM3RO',
        home: SafeArea(
            child: Scaffold(
                appBar: AppBar(
                    foregroundColor: Colors.blue,
                    backgroundColor: Colors.black45,
                    elevation: 0,
                    title: const Text('NUM3RO // AINZCorp')),
                backgroundColor: Colors.blue,
                body: const InitScreen())));
  }
}

class InitScreen extends StatefulWidget {
  const InitScreen({Key? key}) : super(key: key);

  @override
  _InitScreenState createState() => _InitScreenState();
}

class _InitScreenState extends State<InitScreen> with WidgetsBindingObserver {
  CameraDescription? camera;
  CameraController? controller;
  CustomPaint gridPaint =
      CustomPaint(size: Size.infinite, painter: GridPainter());

  String? reading; // = 31.0254;
  String? id; // = 'AA219872EE';
  bool isLoading = false;
  bool isInitialized = false;
  bool isBusy = false;
  BarcodeScanner barcodeScanner = GoogleMlKit.vision.barcodeScanner();
  TextDetector textDetector = GoogleMlKit.vision.textDetector();
  Map<String, String> instructions = {};
  double zoomLevel = 0.0, minZoomLevel = 0.0, maxZoomLevel = 0.0;

  @override
  void initState() {
    super.initState();
    _ambiguate(WidgetsBinding.instance)?.addObserver(this);
    _initializeCamera();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final CameraController? cameraController = controller;
    if (cameraController == null || !cameraController.value.isInitialized) {
      return;
    }
    if (state == AppLifecycleState.inactive) {
      cameraController.dispose();
    } else if (state == AppLifecycleState.resumed) {
      _initializeControllerWithCamera(cameraController.description);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
        child: Center(
            child: (controller == null || !controller!.value.isInitialized)
                ? Column(
                    children: const [
                      CircularProgressIndicator(),
                      Text('loading..'),
                    ],
                  )
                : Column(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: <Widget>[
                      _display(),
                      Padding(
                        padding: const EdgeInsets.all(8),
                        child: AspectRatio(
                          aspectRatio: 1,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Transform.scale(
                              scale: controller!.value.aspectRatio,
                              child: Center(
                                child: AspectRatio(
                                  aspectRatio:
                                      1 / controller!.value.aspectRatio,
                                  child: Stack(
                                    fit: StackFit.expand,
                                    children: [
                                      CameraPreview(controller!),
                                      if (controller != null &&
                                          controller!.value.isInitialized)
                                        Opacity(
                                          opacity: 0.25,
                                          child: gridPaint,
                                        ),
                                      Positioned(
                                        bottom: 100,
                                        left: 50,
                                        right: 50,
                                        child: Slider(
                                          value: zoomLevel,
                                          min: minZoomLevel,
                                          max: maxZoomLevel,
                                          onChanged: (newSliderValue) {
                                            setState(() {
                                              zoomLevel = newSliderValue;
                                              controller!
                                                  .setZoomLevel(zoomLevel);
                                            });
                                          },
                                          divisions:
                                              (maxZoomLevel - 1).toInt() < 1
                                                  ? null
                                                  : (maxZoomLevel - 1).toInt(),
                                        ),
                                      )
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      Buttons(flowControl: flowControl)
                    ],
                  )));
  }

  Widget _display() {
    return Column(
      children: <Widget>[
        Text(
          reading != null ? reading.toString() : 'no reading',
          style: TextStyle(
              fontSize: 60,
              fontWeight: FontWeight.bold,
              color: reading != null ? Colors.black54 : Colors.black26),
        ),
        Text(
          id != null ? id.toString() : 'unidentified',
          style: TextStyle(
              fontSize: 30,
              fontWeight: FontWeight.bold,
              color: id != null ? Colors.black45 : Colors.black12),
        ),
      ],
    );
  }

  Future<void> _detectImage(InputImage inputImage) async {
    if (isBusy) return;
    isBusy = true;
    if (instructions['category'] == 'number') {
      final recognisedText = await textDetector.processImage(inputImage);
      if (recognisedText.text != '') {
        setState(() {
          reading = recognisedText.text;
        });
      }
    }
    if (instructions['category'] == 'qrcode' ||
        instructions['category'] == 'barcode') {
      final barcodes = await barcodeScanner.processImage(inputImage);
      if (barcodes.isNotEmpty) {
        setState(() {
          id = barcodes.first.value.displayValue;
        });
      }
    }

    isBusy = false;
  }

  Future _processImage(CameraImage image) async {
    final WriteBuffer allBytes = WriteBuffer();
    for (Plane plane in image.planes) {
      allBytes.putUint8List(plane.bytes);
    }
    final bytes = allBytes.done().buffer.asUint8List();

    final Size imageSize =
        Size(image.width.toDouble(), image.height.toDouble());

    final inputImageFormat =
        InputImageFormatMethods.fromRawValue(image.format.raw) ??
            InputImageFormat.NV21;

    final planeData = image.planes.map(
      (Plane plane) {
        return InputImagePlaneMetadata(
          bytesPerRow: plane.bytesPerRow,
          height: plane.height,
          width: plane.width,
        );
      },
    ).toList();

    final inputImageData = InputImageData(
      size: imageSize,
      imageRotation: InputImageRotation.Rotation_0deg,
      inputImageFormat: inputImageFormat,
      planeData: planeData,
    );

    final inputImage =
        InputImage.fromBytes(bytes: bytes, inputImageData: inputImageData);

    _detectImage(inputImage);
  }

  void flowControl(Control control) async {
    if (controller == null) return;

    final _instructions = Map<String, String>.fromIterables(
        ['type', 'operation', 'category'],
        control.toString().split(RegExp(r'\.|_')));

    setState(() {
      instructions = _instructions;
    });

    if (instructions['operation'] == 'stop') {
      await controller?.stopImageStream();
      return;
    }

    if (instructions['operation'] == 'start') {
      if (controller != null && controller!.value.isStreamingImages) {
        await controller?.stopImageStream();
      }

      controller?.startImageStream(_processImage);
    }

    // start_number,
    // start_barcode,
    // start_qrcode,
    // stop_number,
    // stop_barcode,
    // stop_qrcode,
    // toggle_number,
    // toggle_barcode,
    // toggle_qrcode,
  }

  Future<void> _initializeCamera() async {
    setState(() {
      isLoading = true;
    });

    List<CameraDescription> allCameras = await availableCameras();
    camera = allCameras.firstWhere(((cameraDescription) =>
        cameraDescription.lensDirection == CameraLensDirection.back));
    if (camera != null) _initializeControllerWithCamera(camera!);

    setState(() {
      isLoading = false;
    });
  }

  void _initializeControllerWithCamera(CameraDescription camera) async {
    if (controller != null) {
      await controller!.dispose();
    }

    final CameraController cameraController = CameraController(
      camera,
      ResolutionPreset.veryHigh,
      enableAudio: false,
    );

    controller = cameraController;

    cameraController.addListener(() {
      if (mounted) {
        setState(() {
          isInitialized = cameraController.value.isInitialized;
        });
      }
    });

    cameraController.initialize().then((_) {
      if (!mounted) {
        return;
      }
      cameraController.getMinZoomLevel().then((value) {
        zoomLevel = value;
        minZoomLevel = value;
      });
      cameraController.getMaxZoomLevel().then((value) {
        maxZoomLevel = value;
      });
      setState(() {});
    });
    await cameraController.lockCaptureOrientation();
  }
}

class Buttons extends StatefulWidget {
  const Buttons({Key? key, required this.flowControl}) : super(key: key);

  final Function(Control) flowControl;

  @override
  State<Buttons> createState() => _ButtonsState();
}

class _ButtonsState extends State<Buttons> {
  bool isloading = false;
  bool isNumber = false;
  bool isBarcode = false;
  bool isQRcode = false;

  void controlHandler(Control control) {
    widget.flowControl(control);
    switch (control) {
      case Control.start_number:
        setState(() {
          isNumber = true;
          isBarcode = false;
          isQRcode = false;
        });
        break;
      case Control.start_barcode:
        setState(() {
          isNumber = false;
          isBarcode = true;
          isQRcode = false;
        });
        break;
      case Control.start_qrcode:
        setState(() {
          isNumber = false;
          isBarcode = false;
          isQRcode = true;
        });
        break;
      case Control.stop_number:
        setState(() {
          isNumber = false;
        });
        break;
      case Control.stop_barcode:
        setState(() {
          isBarcode = false;
        });
        break;
      case Control.stop_qrcode:
        setState(() {
          isQRcode = false;
        });
        break;
      case Control.toggle_number:
        setState(() {
          isQRcode = false;
          isBarcode = false;
          isNumber = !isNumber;
        });
        break;
      case Control.toggle_barcode:
        setState(() {
          isNumber = false;
          isQRcode = false;
          isBarcode = !isBarcode;
        });
        break;
      case Control.toggle_qrcode:
        setState(() {
          isNumber = false;
          isBarcode = false;
          isQRcode = !isQRcode;
        });
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        Ink(
          decoration: ShapeDecoration(
            color: isNumber ? Colors.blue.shade400 : Colors.blue,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          child: GestureDetector(
            onLongPressStart: (_) => controlHandler(Control.start_number),
            onLongPressEnd: (_) => controlHandler(Control.stop_number),
            onDoubleTap: () => controlHandler(Control.toggle_number),
            child: Stack(
              alignment: Alignment.center,
              children: const [
                IconButton(
                  iconSize: 90,
                  icon: Icon(CupertinoIcons.viewfinder),
                  onPressed: null,
                ),
                Text('4.2 g')
              ],
            ),
          ),
        ),
        Ink(
          decoration: ShapeDecoration(
            color: isBarcode ? Colors.blue.shade400 : Colors.blue,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          child: GestureDetector(
            onLongPressStart: (_) => controlHandler(Control.start_barcode),
            onLongPressEnd: (_) => controlHandler(Control.stop_barcode),
            onDoubleTap: () => controlHandler(Control.toggle_barcode),
            child: const IconButton(
              iconSize: 90,
              icon: Icon(CupertinoIcons.barcode_viewfinder),
              onPressed: null,
            ),
          ),
        ),
        Ink(
          decoration: ShapeDecoration(
            color: isQRcode ? Colors.blue.shade400 : Colors.blue,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          child: GestureDetector(
              onLongPressStart: (_) => controlHandler(Control.start_qrcode),
              onLongPressEnd: (_) => controlHandler(Control.stop_qrcode),
              onDoubleTap: () => controlHandler(Control.toggle_qrcode),
              child: const IconButton(
                iconSize: 90,
                icon: Icon(CupertinoIcons.qrcode_viewfinder),
                onPressed: null,
              )),
        ),
      ],
    );
  }
}

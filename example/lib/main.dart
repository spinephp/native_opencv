import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'dart:async';

import 'package:flutter/services.dart';
import 'package:native_opencv/native_opencv.dart';
import 'package:native_opencv/utils/picker_area.dart';
import 'package:native_opencv/utils/adjustment_area.dart';
import 'dart:ui' as ui;

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  String _platformVersion = 'Unknown';
  Uint8List? uint8list;
  // ui.Image? _image;
  // Uint8List? uint8list1;

  @override
  void initState() {
    super.initState();
    initPlatformState();
    WidgetsBinding.instance!.addPostFrameCallback((_) async {
      final bytes = await rootBundle.load('assets/IMG_4739.jpeg');
      uint8list = bytes.buffer.asUint8List();
      // _image = await loadImageByUint8List(uint8list!);
      // Future.delayed(const Duration(milliseconds: 100), () {
      //   setState(() {
      //     opencvImage(uint8list!);
      //   });
      // });
      setState(() {});
    });
  }

  // Platform messages are asynchronous, so we initialize in an async method.
  Future<void> initPlatformState() async {
    String platformVersion;
    // Platform messages may fail, so we use a try/catch PlatformException.
    // We also handle the message potentially returning null.
    try {
      platformVersion = nativeAdd(1, 2).toString();
    } on PlatformException {
      platformVersion = 'Failed to get platform version.';
    }

    // If the widget was removed from the tree while the asynchronous platform
    // message was in flight, we want to discard the reply rather than calling
    // setState to update our non-existent appearance.
    if (!mounted) return;

    setState(() {
      _platformVersion = platformVersion;
    });
  }

//通过[Uint8List]获取图片
  // Future<ui.Image> loadImageByUint8List(Uint8List list) async {
  //   ui.Codec codec = await ui.instantiateImageCodec(list);
  //   ui.FrameInfo frame = await codec.getNextFrame();
  //   return frame.image;
  // }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: const Text('Plugin example app'),
          actions: [
            IconButton(
                onPressed: () {
                  // uint8list = squareImage(uint8list!);
                  setState(() {});
                },
                icon: const Icon(Icons.access_alarms))
          ],
        ),
        body: uint8list == null
            ? const Text("waiting...")
            : Stack(children: [
                // Image.memory(uint8list!),
                // DraggableWidget(
                //   image: _image,
                //   widgetcolor: Colors.tealAccent,
                // ),
                ImageAreaWidget(
                  uint8list: uint8list,
                ),
                // uint8list1 == null
                //     ? const Text("waiting...")
                //     : Expanded(child: Image.memory(uint8list1!))
              ]),
      ),
    );
  }
}

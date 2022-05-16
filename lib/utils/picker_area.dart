import 'dart:ffi';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';
import 'package:flutter/material.dart';
import 'package:native_opencv/utils/adjustment_area.dart';
import 'dart:ui' as ui;

import '../native_opencv.dart';
import 'city_picker.dart';

class ImagePainter extends CustomPainter {
  ui.Image? image;

  ImagePainter(this.image);

  @override
  void paint(Canvas canvas, ui.Size size) {
    Paint paint = Paint();
    if (image != null) {
      //draw the backgroud image
      double dwidth = 0;
      double dheight = 0;
      final width = size.width;
      final height = size.height;
      final double imgWidth = image!.width.toDouble();
      final double imgHeight = image!.height.toDouble();
      if (imgWidth / width > imgHeight / height) {
        dwidth = width;
        dheight = imgHeight * dwidth / imgWidth;
      } else {
        dheight = height;
        dwidth = imgWidth * dheight / imgHeight;
      }
      // canvas.drawImageRect(
      //     image!,
      //     Rect.fromLTWH(0, 0, imgWidth, imgHeight),
      //     Rect.fromLTWH(
      //         (width - dwidth) / 2, (height - dheight) / 2, dwidth, dheight),
      //     paint);
      canvas.drawImageRect(image!, Rect.fromLTWH(0, 0, imgWidth, imgHeight),
          Rect.fromLTWH(0, 0, dwidth, dheight), paint);
    }
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) {
    return false;
  }
}

class ClipAreaPainter extends CustomPainter {
  final List<Offset> offsets;
  final int selected;
  ClipAreaPainter(this.offsets, this.selected);

  @override
  void paint(Canvas canvas, ui.Size size) {
    Paint paint = Paint();
    // double dwidth = 0;
    // double dheight = 0;
    // final width = size.width;
    // final height = size.height;
    // final double imgWidth = image!.width.toDouble();
    // final double imgHeight = image!.height.toDouble();
    // if (imgWidth / width > imgHeight / height) {
    //   dwidth = width;
    //   dheight = imgHeight * dwidth / imgWidth;
    // } else {
    //   dheight = height;
    //   dwidth = imgWidth * dheight / imgHeight;
    // }
    // final sx = dwidth / imgWidth;
    // final sy = dheight / imgHeight;
    // List<Offset> points2 = [];

    // for (int i = 0; i < 4; i++) {
    //   points2.add(Offset(pts[i].x * sx, pts[i].y * sy));
    // }
    // points2.add(points2[0]);
    if (offsets.isNotEmpty) {
      paint.strokeWidth = 2;
      paint.color = Colors.red;

      canvas.drawPoints(
          ui.PointMode.polygon, offsets, paint); //draw the clip box

      //draw the drag point
      double radius = 15;
      for (int i = 0; i < 4; i++) {
        paint.style = i == selected ? PaintingStyle.fill : PaintingStyle.stroke;
        canvas.drawCircle(offsets[i], radius, paint);
      }
    }
  }

  bool equal(ClipAreaPainter oldDelegate) {
    return true;
    // bool result = true;
    //   for (int i = 0; i < offsets.length; i++) {
    //     if (offsets[i] != oldDelegate.offsets[i]) return true;
    //   }
    //   return oldDelegate.selected != selected;
  }

  @override
  bool shouldRepaint(ClipAreaPainter oldDelegate) {
    return equal(oldDelegate);
    //oldDelegate.offsets[0] != offsets[0];
  }
}

typedef FinishCallback = void Function(
    double ratio, int entityUnit, Uint8List imgdata);

class ImageAreaWidget extends StatefulWidget {
  final Uint8List? uint8list;
  final Color dragColor;
  final FinishCallback finishCallback;
  const ImageAreaWidget(
      {Key? key,
      this.uint8list,
      required this.finishCallback,
      this.dragColor = Colors.tealAccent})
      : super(key: key);

  @override
  State<ImageAreaWidget> createState() => _ImageAreaWidgetState();
}

class _ImageAreaWidgetState extends State<ImageAreaWidget>
    implements CityAlertViewDelegate {
  List<Offset> offsets = [];
  List<Offset> _bkOffset = [];

  final FourPoint fp = FourPoint.fp;
  double imgWidth = 400;
  double imgHeight = 400;
  double entityWidth = 0;
  double entityHeight = 0;
  int entityUnit = 0;
  double scale = 1;
  ui.Image? _image;
  Uint8List? _doneImg;
  Pointer<Uint8>? bytes;
  Pointer<Int32>? imgLengthBytes;
  int dragIndex = -1;
  int selectedIndex = -1;
  Offset curOffset = const Offset(0, 0);
  bool isEditing = false;
  static const List<IconData> iconDatas1 = [Icons.cancel, Icons.navigate_next];
  static const List<IconData> iconDatas2 = [Icons.navigate_before, Icons.done];

  /// 通过 Uint8List 获取图片
  Future<ui.Image> loadImageByUint8List(Uint8List list) async {
    ui.Codec codec = await ui.instantiateImageCodec(list);
    ui.FrameInfo frame = await codec.getNextFrame();
    return frame.image;
  }

  void opencvImage(Uint8List list) {
    bytes = malloc.allocate(sizeOf<Uint8>() * list.length);
    for (int i = 0; i < list.length; i++) {
      bytes?.elementAt(i).value = list[i];
    }

    imgLengthBytes = malloc.allocate(sizeOf<Int32>())..value = list.length;

    processImage(
        bytes!, imgLengthBytes!, Pointer.fromFunction(correctOuterEdge));
  }

  Uint8List? imageSquare() {
    Pointer<FPoint> fpts = malloc.allocate(sizeOf<FPoint>() * 4);
    listToFPoint(offsets, fpts, scale, 4);
    final newBytes =
        squareImage(imgLengthBytes!, fpts, entityWidth / entityHeight);
    if (newBytes == nullptr) {
      // print('高斯模糊失败');
      return null;
    }

    var newList = newBytes.asTypedList(imgLengthBytes!.value);

    malloc.free(fpts);
    // malloc.free(imgLengthBytes);
    return newList;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance!.addPostFrameCallback((_) async {
      _image = await loadImageByUint8List(widget.uint8list!);
      imgWidth = _image!.width.toDouble();
      imgHeight = _image!.height.toDouble();
      Future.delayed(const Duration(milliseconds: 100), () {
        setState(() {
          opencvImage(widget.uint8list!);
        });
      });
    });

    // 监听查找到的四边形目标顶点
    fp.addListener(() {
      setState(() {
        scale = context.size!.width / imgWidth;
        for (int i = 0; i < 4; i++) {
          final x = (fp.point4?[i].x ?? 0) * scale;
          final y = (fp.point4?[i].y ?? 0) * scale;
          offsets.add(Offset(x, y));
        }
        offsets.add(offsets[0]);
        isEditing = true;
      });
    });
  }

  void dragUpdate(double dx, double dy) {
    if (selectedIndex != -1) {
      setState(() {
        offsets[selectedIndex] += Offset(dx, dy);
        if (selectedIndex == 0) {
          offsets[4] += Offset(dx, dy);
        }
      });
    }
  }

  List<Widget> buttons() {
    List<Widget> _btns = [];
    _btns.add(IconButton(
      icon: Icon(
        offsets.isNotEmpty ? iconDatas1[0] : iconDatas2[0],
        color: Colors.blueAccent,
        // size: 40,
      ), //Text(btnTitle1),
      onPressed: () async {
        if (offsets.isNotEmpty) {
        } else {
          _image = await loadImageByUint8List(widget.uint8list!);
          offsets = List.from(_bkOffset);
          _bkOffset.clear();
        }
        setState(() {});
      },
    ));
    if (offsets.isNotEmpty) {
      const _iconDatas = [
        Icons.arrow_drop_up,
        Icons.arrow_drop_down,
        Icons.arrow_left,
        Icons.arrow_right
      ];
      const _offsets = [
        [0.0, -1.0],
        [0.0, 1.0],
        [-1.0, 0.0],
        [1.0, 0.0]
      ];
      for (int i = 0; i < _iconDatas.length; i++) {
        _btns.add(IconButton(
            onPressed: selectedIndex != -1
                ? () {
                    dragUpdate(_offsets[i][0], _offsets[i][1]);
                  }
                : null,
            icon: Icon(
              _iconDatas[i],
              color: selectedIndex != -1 ? Colors.blueAccent : Colors.blueGrey,
              // size: 40,
            )));
      }
    }
    _btns.add(IconButton(
        onPressed: () {
          if (offsets.isNotEmpty) {
            //调用弹框
            showModalBottomSheet(
                context: context,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadiusDirectional.circular(10)),
                builder: (BuildContext context) {
                  return CityAlertView(
                    delegate: this,
                  );
                });
          } else {
            widget.finishCallback(
                entityWidth / _image!.width, entityUnit, _doneImg!);
          }
        },
        icon: Icon(
          offsets.isNotEmpty ? iconDatas1[1] : iconDatas2[1],
          color: Colors.blueAccent,
          // size: 40,
        ))); // Text(btnTitle2)));
    return _btns;
  }

  @override
  void dispose() {
    super.dispose();
    fp.dispose();
    if (bytes != null) {
      malloc.free(bytes!);
      bytes = null;
    }
    if (imgLengthBytes != null) {
      malloc.free(imgLengthBytes!);
      imgLengthBytes = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
            child: CustomPaint(
          painter: ImagePainter(_image),
          child: isEditing
              ? GestureDetector(
                  onPanDown: (details) {
                    selectedIndex = -1;
                    for (int i = 0; i < 4; i++) {
                      Path path = Path();
                      path.addOval(
                          Rect.fromCircle(center: offsets[i], radius: 15));
                      if (path.contains(details.localPosition)) {
                        dragIndex = i;
                        curOffset = details.localPosition;
                        break;
                      }
                    }
                  },
                  onPanUpdate: (details) {
                    if (dragIndex >= 0 && dragIndex < 4) {
                      setState(() {
                        offsets[dragIndex] += details.localPosition - curOffset;
                        if (dragIndex == 0) {
                          offsets[4] += details.localPosition - curOffset;
                        }
                        curOffset = details.localPosition;
                      });
                    }
                  },
                  onPanEnd: (details) {
                    selectedIndex = dragIndex;
                    dragIndex = -1;
                  },
                )
              : null,
          foregroundPainter: isEditing
              ? ClipAreaPainter(offsets, dragIndex & selectedIndex)
              : null,
          // size: Size(widget.width, imgHeight * scale),
        )),
        Padding(
          padding: const EdgeInsets.only(top: 28.0),
          child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: buttons()),
        )
      ],
    );
  }

  @override
  void confirmClick(List<num?> models) async {
    entityWidth = models[0]?.toDouble() ?? 0;
    entityHeight = models[1]?.toDouble() ?? 0;
    entityUnit = models[2]?.toInt() ?? 0;
    // debugPrint("width: ${models[0]}");
    _doneImg = imageSquare();
    _image = await loadImageByUint8List(_doneImg!);
    _bkOffset = List.from(offsets);
    offsets.clear();
    setState(() {});
    // debugPrint("选择index为$index,选择的内容为$str");
  }
}

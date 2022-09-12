import 'dart:async';
import 'dart:ffi';
import 'dart:math';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';
import 'package:flutter/material.dart';
import 'dart:ui' as ui;

import 'package:native_opencv/native_opencv.dart';
import 'package:native_opencv/utils/city_picker.dart';
import 'package:native_opencv/utils/adjustment_area.dart';
import 'package:seene_measure/utils/widgets.dart';
import 'package:seene_measure/pages/update_background_page.dart';

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
    // for (int i = 0; i < offsets.length; i++) {
    //   if (offsets[i] != oldDelegate.offsets[i]) return true;
    // }
    // return oldDelegate.selected != selected;
  }

  @override
  bool shouldRepaint(ClipAreaPainter oldDelegate) {
    return equal(oldDelegate);
    //oldDelegate.offsets[0] != offsets[0];
  }
}

class ForeRectPainter extends CustomPainter {
  final List<Offset> offsets;
  final int count;
  ForeRectPainter(this.offsets, this.count);

  @override
  void paint(Canvas canvas, ui.Size size) {
    Paint paint = Paint();
    if (offsets.isNotEmpty) {
      paint.strokeWidth = 2;
      paint.style = PaintingStyle.stroke;
      paint.color = Colors.red;
      if (count == 0) {
        canvas.drawLine(Offset(offsets[0].dx, 0),
            Offset(offsets[0].dx, size.height), paint);
        canvas.drawLine(
            Offset(0, offsets[0].dy), Offset(size.width, offsets[0].dy), paint);
      } else {
        canvas.drawRect(Rect.fromPoints(offsets[0], offsets[1]), paint);
      }
    }
  }

  bool equal(ForeRectPainter oldDelegate) {
    return true;
    // bool result = true;
    // for (int i = 0; i < offsets.length; i++) {
    //   if (offsets[i] != oldDelegate.offsets[i]) return true;
    // }
    // return oldDelegate.selected != selected;
  }

  @override
  bool shouldRepaint(ForeRectPainter oldDelegate) {
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
  // Pointer<Uint8>? bytes;
  // Pointer<Int32>? imgLengthBytes;
  // int? saveImgBytes;
  int dragIndex = -1;
  int selectedIndex = -1;
  Offset curOffset = const Offset(0, 0);
  bool isEditing = false;

  bool isRemoveBackground = false;
  int foreAreaIndex = -1;
  List<Offset> foreAreaOffsets = [];

  static const List<IconData> iconDatas1 = [Icons.cancel, Icons.navigate_next];
  static const List<IconData> iconDatas2 = [Icons.navigate_before, Icons.done];

  void opencvImage(Uint8List list) {
    Pointer<Uint8>? bytes = malloc.allocate(sizeOf<Uint8>() * list.length);
    for (int i = 0; i < list.length; i++) {
      bytes?.elementAt(i).value = list[i];
    }

    Pointer<Int32>? imgLengthBytes = malloc.allocate(sizeOf<Int32>())
      ..value = list.length;

    processImage(
        bytes!, imgLengthBytes!, Pointer.fromFunction(correctOuterEdge));
    malloc.free(bytes);
    bytes = null;
    malloc.free(imgLengthBytes);
    imgLengthBytes = null;
  }

  Uint8List? imageSquare() {
    Pointer<FPoint>? fpts = malloc.allocate(sizeOf<FPoint>() * 4);
    listToFPoint(offsets, fpts, scale, 4);

    Pointer<Int32>? imgLengthBytes = malloc.allocate(sizeOf<Int32>());
    final newBytes =
        squareImage(imgLengthBytes!, fpts, entityWidth / entityHeight);
    if (newBytes == nullptr) return null;

    var newList = newBytes.asTypedList(imgLengthBytes!.value);

    malloc.free(imgLengthBytes);
    imgLengthBytes = null;
    malloc.free(fpts);
    fpts = null;

    return newList;
  }

  void listenerFourPoint() {
    final _w = context.size!.width;
    final _h = context.size!.height;
    final _d = [
      Offset(_w * 0.25, _h * 0.25),
      Offset(_w * 0.75, _h * 0.25),
      Offset(_w * 0.75, _h * 0.75),
      Offset(_w * 0.25, _h * 0.75)
    ];
    setState(() {
      scale = context.size!.width / imgWidth;
      for (int i = 0; i < 4; i++) {
        final x = (fp.point4?[i].x ?? _d[i].dx) * scale;
        final y = (fp.point4?[i].y ?? _d[i].dy) * scale;
        offsets.add(Offset(x, y));
      }
      offsets.add(offsets[0]);
      isEditing = true;
    });
  }

  @override
  void didChangeDependencies() {
    // 监听查找到的四边形目标顶点
    fp.addListener(listenerFourPoint);

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      _image = await loadImageByUint8List(widget.uint8list!);
      imgWidth = _image!.width.toDouble();
      imgHeight = _image!.height.toDouble();
      Future.delayed(const Duration(milliseconds: 100), () {
        setState(() {
          opencvImage(widget.uint8list!);
        });
      });
    });

    super.didChangeDependencies();
  }

  @override
  void initState() {
    super.initState();
  }

  /// 根据当前选择的四边形角点（4个中的一个），调整其位置
  /// 参数 dx - double 类型，指定水平方向位移量
  ///     dy - double 类型，指定垂直方向位移量
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
          // Navigator.of(context).pop();
        } else {
          // if (saveImgBytes != null) imgLengthBytes?.value = saveImgBytes!;
          _image = await loadImageByUint8List(widget.uint8list!);
          offsets = List.from(_bkOffset);
          _bkOffset.clear();
          isEditing = true;
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
    } else {
      // 去除背景
      _btns.add(IconButton(
          icon: const Icon(Icons.photo_size_select_actual_outlined),
          onPressed: () async {
            Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) => UpdateBackgroundPage(
                          imgbytes: _doneImg!,
                        ))).then((value) {
              if (value != null) {
                _doneImg = value;
                loadImageByUint8List(_doneImg!).then((value1) {
                  _image = value1;
                  setState(() {
                    // var _uint8list = Uint8List.fromList(item[4].fileCode(value));
                    // item[4] = ImageFile(data: _uint8list);
                    // saveFile(item[0] + ".smi", _uint8list);
                  });
                });
              }
            });
            // setState(() {
            //   foreAreaOffsets.add(const Offset(0, 0));
            //   foreAreaOffsets.add(const Offset(0, 0));
            //   isRemoveBackground = true;
            //   isEditing = false;
            // });
          }));
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
    fp.removeListener(listenerFourPoint);
    // fp.dispose();
    // if (bytes != null) {
    //   malloc.free(bytes);
    //   bytes = null;
    // }
    // if (imgLengthBytes != null) {
    //   malloc.free(imgLengthBytes!);
    //   imgLengthBytes = null;
    // }
  }

  /// 生成编辑手势动作，用于调整红色四边形的四个角位置与实体四边形重合
  GestureDetector editingPen() {
    return GestureDetector(
      onPanDown: (details) {
        selectedIndex = -1;
        for (int i = 0; i < 4; i++) {
          Path path = Path();
          path.addOval(Rect.fromCircle(center: offsets[i], radius: 15));
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
    );
  }

  /// 生成更换背景手势动作，用于生成包含前景区域的矩形
  GestureDetector removeBackgroundPen() {
    return GestureDetector(
      onScaleStart: (details) {
        if (foreAreaIndex < 1) foreAreaIndex += 1;
        if (details.pointerCount == 1) {
          foreAreaOffsets[foreAreaIndex] = details.localFocalPoint;
        } else if (details.pointerCount == 2) {
          if (foreAreaIndex >= 0 && foreAreaIndex < 2) {
            foreAreaOffsets[foreAreaIndex] = details.localFocalPoint;
          }
        }
      },
      onScaleUpdate: (details) {
        if (foreAreaIndex >= 0 && foreAreaIndex < 2) {
          setState(() {
            foreAreaOffsets[foreAreaIndex] = details.localFocalPoint;
          });
        }
      },
      onScaleEnd: (details) async {
        if (details.pointerCount == 0) {
          foreAreaIndex = -1;
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
        home: Scaffold(
            bottomNavigationBar: BottomAppBar(
                // color: Colors.white,
                child: Row(
                    mainAxisSize: MainAxisSize.max,
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: buttons())),
            body: Column(
              children: [
                Expanded(
                    child: CustomPaint(
                  painter: ImagePainter(_image),
                  child: isEditing
                      ? editingPen()
                      : isRemoveBackground
                          ? removeBackgroundPen()
                          : null,
                  foregroundPainter: isEditing
                      ? ClipAreaPainter(offsets, dragIndex & selectedIndex)
                      : isRemoveBackground
                          ? ForeRectPainter(foreAreaOffsets, foreAreaIndex)
                          : null,
                  // size: Size(widget.width, imgHeight * scale),
                )),
              ],
            )));
  }

  @override
  void confirmClick(List<num?> models) async {
    // 设置实体尺寸及单位(如纸张)
    entityWidth = models[0]?.toDouble() ?? _image!.width.toDouble();
    entityHeight = models[1]?.toDouble() ?? _image!.height.toDouble();
    entityUnit = models[2]?.toInt() ?? 4;

    // if (models[0] != null) {
    _doneImg = models[0] != null ? imageSquare() : widget.uint8list;
    _image = await loadImageByUint8List(_doneImg!);

    // 如实体长短边与图象长短边不对应，则调交换实体两个边使其相对应
    if (_image != null) {
      print(
          "image width: ${_image!.width} image height: ${_image!.height}\n entity width: $entityWidth, entity height: $entityHeight");
      if ((_image!.width > _image!.height && entityWidth < entityHeight) ||
          (_image!.width < _image!.height && entityWidth > entityHeight)) {
        final _tem = entityHeight;
        entityHeight = entityWidth;
        entityWidth = _tem;
      }
    }
    _bkOffset = List.from(offsets);
    offsets.clear();
    // }
    setState(() {});
    // debugPrint("选择index为$index,选择的内容为$str");
  }
}

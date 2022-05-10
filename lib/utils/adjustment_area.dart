import 'dart:ffi';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:native_opencv/native_opencv.dart';

class FourPoint extends ChangeNotifier {
  //这里也可以使用with来进行实现
  List<FPoint>? _pts; //数值计算
  FourPoint._();

  static final FourPoint fp = FourPoint._();

  List<FPoint>? get point4 => _pts;

  update(List<FPoint> p4s) {
    _pts = List.from(p4s);
    notifyListeners();
  }
}

/// FourPoint global4Point = FourPoint();
void correctOuterEdge(Pointer<FPoint> pts, int length) {
  List<FPoint> ps = [];
  for (int i = 0; i < length; i++) {
    ps.add(pts[i]);
    debugPrint("p$i = [${pts[i].x}, ${pts[i].y}]");
  }
  FourPoint.fp.update(ps);
}

List<FPoint> fpointToList(Pointer<FPoint> pts, List<FPoint> ps, int length) {
  for (int i = 0; i < length; i++) {
    ps.add(pts[i]);
  }
  return ps;
}

Pointer<FPoint> listToFPoint(
    List<Offset> offsets, Pointer<FPoint> fpts, double scale, int length) {
  for (int i = 0; i < length; i++) {
    fpts[i].x = (offsets[i].dx / scale).truncateToDouble();
    fpts[i].y = (offsets[i].dy / scale)..truncateToDouble();
  }
  return fpts;
}

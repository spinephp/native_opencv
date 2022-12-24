import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';

//对应C中的Point结构体
class FPoint extends Struct {
  @Double()
  external double x;

  @Double()
  external double y;
}

//对应C中的 RectI 结构体
class RectI extends Struct {
  @Int32()
  external int x;

  @Int32()
  external int y;

  @Int32()
  external int width;

  @Int32()
  external int height;

  factory RectI.allocate(int x, int y, int width, int height) =>
      calloc<RectI>().ref
        ..x = x
        ..y = y
        ..width = width
        ..height = height;
}

final DynamicLibrary nativeAddLib = Platform.isMacOS || Platform.isIOS
    ? DynamicLibrary.process()
    : DynamicLibrary.open('libNativeAdd.${Platform.isWindows ? 'dll' : 'so'}');

// typedef NativeInitRectI = RectI Function(
//     Int32 x, Int32 y, Int32 width, Int32 height);
// typedef FFIInitRectI = RectI Function(int x, int y, int width, int height);
// FFIInitRectI initRectI =
//     nativeAddLib.lookupFunction<NativeInitRectI, FFIInitRectI>("init_recti");

final Pointer<FPoint> Function(int) createPoints = nativeAddLib
    .lookup<NativeFunction<Pointer<FPoint> Function(Int32)>>('create_points')
    .asFunction();

final Pointer<RectI> Function(int) createRects = nativeAddLib
    .lookup<NativeFunction<Pointer<RectI> Function(Int32)>>('create_rects')
    .asFunction();

final int Function(int x, int y) nativeAdd = nativeAddLib
    .lookup<NativeFunction<Int32 Function(Int32, Int32)>>('native_add')
    .asFunction();

// final Pointer<Uint8> Function(
//         Pointer<Uint8> bytes, Pointer<Int32> imgLengthBytes,Native_calc) processImage =
//     nativeAddLib
//         .lookup<
//             NativeFunction<
//                 Pointer<Uint8> Function(Pointer<Uint8> bytes,
//                     Pointer<Int32> imgLengthBytes,Native_calc correctOuterEdge)>>("process_image")
//         .asFunction();

// 查找函数符号 - process_image
typedef Callback = Void Function(Pointer<FPoint>, Int32);
typedef NativeCalc = Void Function(
    Pointer<Uint8>, Pointer<Int32>, Pointer<NativeFunction<Callback>>);
typedef FFICalc = void Function(
    Pointer<Uint8>, Pointer<Int32>, Pointer<NativeFunction<Callback>>);
FFICalc processImage =
    nativeAddLib.lookupFunction<NativeCalc, FFICalc>("process_image");

final Pointer<Uint8> Function(
        Pointer<Uint8>, Pointer<Int32>, Pointer<RectI>, int, int)
    removeBackground = nativeAddLib
        .lookup<
            NativeFunction<
                Pointer<Uint8> Function(Pointer<Uint8>, Pointer<Int32>,
                    Pointer<RectI>, Int32, Int32)>>('remove_background')
        .asFunction();

final Pointer<Uint8> Function(Pointer<Uint8>, Pointer<Int32>)
    removeBackgroundLast = nativeAddLib
        .lookup<
            NativeFunction<
                Pointer<Uint8> Function(
                    Pointer<Uint8>, Pointer<Int32>)>>('remove_background_last')
        .asFunction();

final Pointer<Uint8> Function(Pointer<Uint8>, Pointer<Int32>, Pointer<Uint8>,
        Pointer<Int32>, Pointer<RectI>, int) drawRoles =
    nativeAddLib
        .lookup<
            NativeFunction<
                Pointer<Uint8> Function(
                    Pointer<Uint8>,
                    Pointer<Int32>,
                    Pointer<Uint8>,
                    Pointer<Int32>,
                    Pointer<RectI>,
                    Int32)>>('draw_roles')
        .asFunction();

// final Pointer<Uint8> Function(
//         Pointer<Uint8>, Pointer<Int32>, int x, int y, int width, int height)
//     removeBackground = nativeAddLib
//         .lookup<
//             NativeFunction<
//                 Pointer<Uint8> Function(Pointer<Uint8>, Pointer<Int32>, Int32,
//                     Int32, Int32, Int32)>>('remove_background')
//         .asFunction();

// 查找函数符号 - remove_background
typedef NativeRemoveBackground = Pointer<Uint8> Function(
    Pointer<Uint8>, Pointer<Int32>);
typedef FFIRemoveBackground = Pointer<Uint8> Function(
    Pointer<Uint8>, Pointer<Int32>);
FFIRemoveBackground removeBackground1 =
    nativeAddLib.lookupFunction<NativeRemoveBackground, FFIRemoveBackground>(
        "remove_background1");

// 查找函数符号 - copy_image
final Pointer<Uint8> Function(Pointer<Uint8>, Pointer<Int32>, Pointer<RectI>)
    getRoleImage = nativeAddLib
        .lookup<
            NativeFunction<
                Pointer<Uint8> Function(Pointer<Uint8>, Pointer<Int32>,
                    Pointer<RectI>)>>('get_role_image')
        .asFunction();

// 查找函数符号 - copy_image
final Pointer<Uint8> Function(Pointer<Uint8>, Pointer<Int32>, Pointer<RectI>)
    copyImage = nativeAddLib
        .lookup<
            NativeFunction<
                Pointer<Uint8> Function(Pointer<Uint8>, Pointer<Int32>,
                    Pointer<RectI>)>>('copy_image')
        .asFunction();

// 查找函数符号 - fill_color
final Pointer<Uint8> Function(
        Pointer<Uint8>, Pointer<Int32>, Pointer<RectI>, int) fillColor =
    nativeAddLib
        .lookup<
            NativeFunction<
                Pointer<Uint8> Function(Pointer<Uint8>, Pointer<Int32>,
                    Pointer<RectI>, Int32)>>('fill_color')
        .asFunction();

// 查找函数符号 - fill_image
final Pointer<Uint8> Function(
        Pointer<Uint8>, Pointer<Int32>, Pointer<RectI>, Pointer<Uint8>, int)
    fillImage = nativeAddLib
        .lookup<
            NativeFunction<
                Pointer<Uint8> Function(Pointer<Uint8>, Pointer<Int32>,
                    Pointer<RectI>, Pointer<Uint8>, Int32)>>('fill_image')
        .asFunction();

// 查找函数符号 - rotate_image
final Pointer<Uint8> Function(Pointer<Uint8>, Pointer<Int32>, int) rotateImage =
    nativeAddLib
        .lookup<
            NativeFunction<
                Pointer<Uint8> Function(
                    Pointer<Uint8>, Pointer<Int32>, Int32)>>('rotate_image')
        .asFunction();

// 查找函数符号 - straight_image
final Pointer<Uint8> Function(Pointer<Uint8>, Pointer<Int32>, Pointer<FPoint>)
    straightImage = nativeAddLib
        .lookup<
            NativeFunction<
                Pointer<Uint8> Function(Pointer<Uint8>, Pointer<Int32>,
                    Pointer<FPoint>)>>('straight_image')
        .asFunction();

// 查找函数符号 - square_image
typedef NativeSquareImage = Pointer<Uint8> Function(
    Pointer<Int32>, Pointer<FPoint>, Double);
typedef FFISquareImage = Pointer<Uint8> Function(
    Pointer<Int32>, Pointer<FPoint>, double);
FFISquareImage squareImage = nativeAddLib
    .lookupFunction<NativeSquareImage, FFISquareImage>("square_image");

// 查找函数符号 - arrayFPoint
typedef NativeArrayFPoint = Pointer<FPoint> Function(Int32 length);
typedef FFIArrayFPoint = Pointer<FPoint> Function(int length);
FFIArrayFPoint arrayFPointFunc = nativeAddLib
    .lookupFunction<NativeArrayFPoint, FFIArrayFPoint>("arrayFPoint");

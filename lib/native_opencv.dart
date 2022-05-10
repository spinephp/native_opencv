import 'dart:ffi';
import 'package:ffi/ffi.dart';

import 'dart:io';

import 'dart:typed_data';

import 'package:native_opencv/utils/adjustment_area.dart';

//对应C中的Point结构体
class FPoint extends Struct {
  @Double()
  external double x;

  @Double()
  external double y;
}

typedef NativeArrayFPoint = Pointer<FPoint> Function(Int32 length);
typedef FFIArrayFPoint = Pointer<FPoint> Function(int length);

typedef Callback = Void Function(Pointer<FPoint>, Int32);
typedef NativeCalc = Void Function(
    Pointer<Uint8>, Pointer<Int32>, Pointer<NativeFunction<Callback>>);
typedef FFICalc = void Function(
    Pointer<Uint8>, Pointer<Int32>, Pointer<NativeFunction<Callback>>);

typedef NativeSquareImage = Pointer<Uint8> Function(
    Pointer<Int32>, Pointer<FPoint>, Double);
typedef FFISquareImage = Pointer<Uint8> Function(
    Pointer<Int32>, Pointer<FPoint>, double);

final DynamicLibrary nativeAddLib = Platform.isMacOS || Platform.isIOS
    ? DynamicLibrary.process()
    : DynamicLibrary.open('libNativeAdd.${Platform.isWindows ? 'dll' : 'so'}');

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
FFICalc processImage =
    nativeAddLib.lookupFunction<NativeCalc, FFICalc>("process_image");

// 查找函数符号 - square_image
FFISquareImage squareImage = nativeAddLib
    .lookupFunction<NativeSquareImage, FFISquareImage>("square_image");

// 查找函数符号 - arrayFPoint
FFIArrayFPoint arrayFPointFunc = nativeAddLib
    .lookupFunction<NativeArrayFPoint, FFIArrayFPoint>("arrayFPoint");

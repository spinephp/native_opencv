package com.example.native_opencv

import androidx.annotation.NonNull

import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result

/**
 * The loader for the X native library.
 *
 * This plugin is purely a workaround. On API versions <=23, it is possible to
 * call an Android SDK method that loads a native library that changes the paths searched when
 * `DynamicLibrary.open` is called in Dart.
 *
 * As such, this plugin is configured to load the shared library when it is registered, so that
 * when `DynamicLibrary.open('libX.so')` is called subsequently through Dart, it will be a
 * no-op.
public final class XLoader: FlutterPlugin {
  override fun onAttachedToEngine(@NonNull flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
    loadLibrary()
  }

  override fun onDetachedFromEngine(@NonNull binding: FlutterPlugin.FlutterPluginBinding) {}

  companion object instance {
  var isLibraryLoaded:Boolean  = false

  fun loadLibrary() {
    if (isLibraryLoaded) {
      return
    }

    // Loads `libX.so`.
    System.loadLibrary("native_opencv")
    isLibraryLoaded = true
  }
  }
}
 */

/**
class Plugin: FlutterPlugin, MethodCallHandler {
  companion object {
    const val TAG = <YOUR_TAG>
  }

  private lateinit var channel: MethodChannel
  private lateinit var context: Context

  override fun onAttachedToEngine(@NonNull flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
    context = flutterPluginBinding.applicationContext
    channel = MethodChannel(flutterPluginBinding.binaryMessenger, <CHANNEL_NAME>)

    channel.setMethodCallHandler(this)
  }

  override fun onMethodCall(@NonNull call: MethodCall, @NonNull result: Result) {
    if (call.method == "getNativeLibraryDirectory") {
      val applicationInfo: ApplicationInfo = context.packageManager.getApplicationInfo(context.packageName, PackageManager.GET_META_DATA)

      if (applicationInfo != null) {
        result.success(applicationInfo.nativeLibraryDir)
      } else {
        result.success(null)
      }
    } else {
      result.notImplemented()
    }
  }

  override fun onDetachedFromEngine(@NonNull binding: FlutterPlugin.FlutterPluginBinding) {
    channel.setMethodCallHandler(null)
  }
}
*/

/** NativeOpencvPlugin */
class NativeOpencvPlugin: FlutterPlugin, MethodCallHandler {
  /// The MethodChannel that will the communication between Flutter and native Android
  ///
  /// This local reference serves to register the plugin with the Flutter Engine and unregister it
  /// when the Flutter Engine is detached from the Activity
  private lateinit var channel : MethodChannel

  override fun onAttachedToEngine(@NonNull flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
    channel = MethodChannel(flutterPluginBinding.binaryMessenger, "native_opencv")
    channel.setMethodCallHandler(this)
    loadLibrary()
  }

  override fun onMethodCall(@NonNull call: MethodCall, @NonNull result: Result) {
    if (call.method == "getPlatformVersion") {
      result.success("Android ${android.os.Build.VERSION.RELEASE}")
    } else {
      result.notImplemented()
    }
  }

  override fun onDetachedFromEngine(@NonNull binding: FlutterPlugin.FlutterPluginBinding) {
    channel.setMethodCallHandler(null)
  }


  companion object instance {
    var isLibraryLoaded:Boolean  = false

    fun loadLibrary() {
      if (isLibraryLoaded) {
        return
      }

      // Loads `libX.so`.
      System.loadLibrary("native_opencv")
      isLibraryLoaded = true
    }
  }
}

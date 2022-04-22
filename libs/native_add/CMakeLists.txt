cmake_minimum_required(VERSION 3.4.1)

# 项目名称
if (CMAKE_SYSTEM_NAME MATCHES "Windows") 
    set(PROJECT_NAME "libNativeAdd")
else()
    set(PROJECT_NAME "NativeAdd")
endif()

project(${PROJECT_NAME} LANGUAGES C CXX)


# TODO please change me!
set(OPENCV_BASE_DIR "/Users/liuxingming/Downloads/OpenCV-android-sdk")

set(OPENCV_INCLUDE_DIR "${OPENCV_BASE_DIR}/sdk/native/jni/include/")
set(OPENCV_STATIC_LIB_DIR "${OPENCV_BASE_DIR}/sdk/native/staticlibs/${ANDROID_ABI}")
set(OPENCV_3RDPARTY_STATIC_LIB_DIR "${OPENCV_BASE_DIR}/sdk/native/3rdparty/libs/${ANDROID_ABI}")

include_directories(${OPENCV_INCLUDE_DIR})

# 从系统查找依赖库，这里添加log日志库
# android系统每个类型库存放在一个特定位置，而log库存放在log-lib中
find_library(log-lib log)

# 创建一个静态库 calib3d 直接引用 libopencv_calib3d.a
add_library(calib3d STATIC IMPORTED)
set_target_properties(calib3d PROPERTIES IMPORTED_LOCATION ${OPENCV_STATIC_LIB_DIR}/libopencv_calib3d.a)

add_library(core STATIC IMPORTED)
set_target_properties(core PROPERTIES IMPORTED_LOCATION ${OPENCV_STATIC_LIB_DIR}/libopencv_core.a)

add_library(dnn STATIC IMPORTED)
set_target_properties(dnn PROPERTIES IMPORTED_LOCATION ${OPENCV_STATIC_LIB_DIR}/libopencv_dnn.a)

add_library(flann STATIC IMPORTED)
set_target_properties(flann PROPERTIES IMPORTED_LOCATION ${OPENCV_STATIC_LIB_DIR}/libopencv_flann.a)

add_library(imgproc STATIC IMPORTED)
set_target_properties(imgproc PROPERTIES IMPORTED_LOCATION ${OPENCV_STATIC_LIB_DIR}/libopencv_imgproc.a)

add_library(videoio STATIC IMPORTED)
set_target_properties(videoio PROPERTIES IMPORTED_LOCATION ${OPENCV_STATIC_LIB_DIR}/libopencv_videoio.a)

add_library(imgcodecs STATIC IMPORTED)
set_target_properties(imgcodecs PROPERTIES IMPORTED_LOCATION ${OPENCV_STATIC_LIB_DIR}/libopencv_imgcodecs.a)

add_library(features2d STATIC IMPORTED)
set_target_properties(features2d PROPERTIES IMPORTED_LOCATION ${OPENCV_STATIC_LIB_DIR}/libopencv_features2d.a)

add_library(ml STATIC IMPORTED)
set_target_properties(ml PROPERTIES IMPORTED_LOCATION ${OPENCV_STATIC_LIB_DIR}/libopencv_ml.a)

add_library(photo STATIC IMPORTED)
set_target_properties(photo PROPERTIES IMPORTED_LOCATION ${OPENCV_STATIC_LIB_DIR}/libopencv_photo.a)

#add_library(shape STATIC IMPORTED)
#set_target_properties(shape PROPERTIES IMPORTED_LOCATION ${OPENCV_STATIC_LIB_DIR}/libopencv_shape.a)

add_library(objdetect STATIC IMPORTED)
set_target_properties(objdetect PROPERTIES IMPORTED_LOCATION ${OPENCV_STATIC_LIB_DIR}/libopencv_objdetect.a)

add_library(stitching STATIC IMPORTED)
set_target_properties(stitching PROPERTIES IMPORTED_LOCATION ${OPENCV_STATIC_LIB_DIR}/libopencv_stitching.a)

include(AndroidNdkModules)
android_ndk_import_module_cpufeatures()
#add_library(cpufeatures-lib STATIC IMPORTED)
#set_target_properties(cpufeatures-lib PROPERTIES IMPORTED_LOCATION
#                       ${lib_output_dir}/libcpufeatures.a)

set(CMAKE_THREAD_PREFER_PTHREAD TRUE)
set(THREADS_PREFER_PTHREAD_FLAG TRUE)
find_package(Threads REQUIRED)

add_library(tbb STATIC IMPORTED)
set_target_properties(tbb PROPERTIES IMPORTED_LOCATION ${OPENCV_3RDPARTY_STATIC_LIB_DIR}/libtbb.a)

add_library(tegra_hal STATIC IMPORTED)
set_target_properties(tegra_hal PROPERTIES IMPORTED_LOCATION ${OPENCV_3RDPARTY_STATIC_LIB_DIR}/libtegra_hal.a)

add_library(ittnotify STATIC IMPORTED)
set_target_properties(ittnotify PROPERTIES IMPORTED_LOCATION ${OPENCV_3RDPARTY_STATIC_LIB_DIR}/libittnotify.a)

# 源文件
add_library(
    # 生成的so库名称，此处生成的so文件名称是 libNativeAdd.so
    ${PROJECT_NAME} 

    # Sets the library as a shared library.
    # STATIC：静态库，是目标文件的归档文件，在链接其它目标的时候使用
    # SHARED：动态库，会被动态链接，在运行时被加载
    # MODULE：模块库，是不会被链接到其它目标中的插件，但是可能会在运行时使用dlopen-系列的函数动态链接
    SHARED

    # Provides a relative path to your source file(s).
    # 资源文件，可以多个，
    # 资源路径是相对路径，相对于本CMakeLists.txt所在目录
    "./native_add.cpp"
)

target_link_libraries(${PROJECT_NAME}
        ${log-lib}
        core
        # note: You can import whatever other modules you like (e.g. dnn)
        tbb # note: need to be placed *after* "core"
        cpufeatures
        #cpufeatures-lib
        ittnotify
        tegra_hal # NOTE if still have error, check abiFilters, since tegra does *not* exist in x86.
        Threads::Threads
        -lz
        )

# Windows 需要把dll拷贝到bin目录
IF (WIN32)
    # 动态库的输出目录
    set(CMAKE_LIBRARY_OUTPUT_DIRECTORY "${CMAKE_CURRENT_BINARY_DIR}/$<$<CONFIG:DEBUG>:Debug>$<$<CONFIG:RELEASE>:Release>")
    # 安装动态库的目标目录
    set(INSTALL_BUNDLE_LIB_DIR "${CMAKE_INSTALL_PREFIX}")
    # 安装动态库，到执行目录
    install(FILES "${CMAKE_LIBRARY_OUTPUT_DIRECTORY}/${PROJECT_NAME}.dll" DESTINATION "${INSTALL_BUNDLE_LIB_DIR}" COMPONENT Runtime)
ENDIF()
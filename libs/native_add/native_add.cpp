#include <stdint.h>
#include <opencv2/core.hpp>

#ifdef WIN32
#define DART_API extern "C" __declspec(dllexport)
#else
#define DART_API extern "C" __attribute__((visibility("default"))) __attribute__((used))
#endif

// DART_API int32_t native_add(int32_t x, int32_t y) {
//     return x + y;
// }
DART_API int32_t native_add(int32_t x, int32_t y) {
    cv::Mat m = cv::Mat::zeros(x, y, CV_8UC3);
    return m.rows + m.cols;
}
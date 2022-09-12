#include <stdint.h>
#include <opencv2/core.hpp>
#include <opencv2/imgcodecs.hpp>
#include <opencv2/imgproc.hpp>
#include <opencv2/highgui.hpp>

using namespace cv;
using namespace std;

#ifdef WIN32
#define DART_API extern "C" __declspec(dllexport)
#else
#define DART_API extern "C" __attribute__((visibility("default"))) __attribute__((used))
#endif


//定义结构体Point，表示平面上的一点
typedef struct {
    double_t x;
    double_t y;
} FPoint;

//定义PointArray结构体
typedef struct {
    FPoint *data;
    int32_t length;
} FPointArray;

DART_API FPoint *arrayFPoint(int32_t length){
    auto  *points = (FPoint *)malloc(length * sizeof(FPoint));
    return points;
}

//定义结构体 RectI，表示平面上的矩形
typedef struct {
    int32_t x;
    int32_t y;
    int32_t width;
    int32_t height;
} RectI;

DART_API int32_t native_add(int32_t x, int32_t y) {
    Mat m = Mat::zeros(x, y, CV_8UC3);
    return m.rows + m.cols;
}

Mat *src = nullptr;

void dispose(){
    free(src);
    src = nullptr;
}

Mat *opencv_decodeImage(
        uint8_t *img,
        unsigned *imgLengthBytes) {
 
    std::vector<unsigned char> m;
 
    // __android_log_print(ANDROID_LOG_VERBOSE, "NATIVE",
    //                     "opencv_decodeImage() ---  start imgLengthBytes:%d ",
    //                     *imgLengthBytes);
 
    unsigned len = *imgLengthBytes;
    for (unsigned i = 0; i<len; i++)
         m.push_back(*(img++));
    
    if(src!=nullptr){
        dispose();
    }

    *src = imdecode(m, cv::IMREAD_COLOR);
    if (src->data == nullptr)
        return nullptr;
 
    // if (DEBUG_NATIVE)
    //     __android_log_print(ANDROID_LOG_VERBOSE, "NATIVE",
    //                         "opencv_decodeImage() ---  len before:%d  len after:%d  width:%d  height:%d",
    //                         *imgLengthBytes, src->step[0] * src->rows,
    //                         src->cols, src->rows);
 
    *imgLengthBytes = (unsigned)(src->step[0] * src->rows);
    return src;
}

#pragma mark =========== 寻找最大边框 ===========
int findLargestSquare(const vector<vector<cv::Point> >& squares, vector<cv::Point>& biggest_square)
{
    if (!squares.size()) return -1;

    int max_width = 0;
    int max_height = 0;
    int max_square_idx = 0;
    for (int i = 0; i < squares.size(); i++)
    {
        cv::Rect rectangle = boundingRect(Mat(squares[i]));
        if ((rectangle.width >= max_width) && (rectangle.height >= max_height))
        {
            max_width = rectangle.width;
            max_height = rectangle.height;
            max_square_idx = i;
        }
    }
    biggest_square = squares[max_square_idx];
    return max_square_idx;
}

/**
 根据三个点计算中间那个点的夹角   pt1 pt0 pt2
 */
double getAngle(cv::Point pt1, cv::Point pt2, cv::Point pt0)
{
    double dx1 = pt1.x - pt0.x;
    double dy1 = pt1.y - pt0.y;
    double dx2 = pt2.x - pt0.x;
    double dy2 = pt2.y - pt0.y;
    return (dx1*dx2 + dy1*dy2)/sqrt((dx1*dx1 + dy1*dy1)*(dx2*dx2 + dy2*dy2) + 1e-10);
}

/**
 点到点的距离

 @param p1 点1
 @param p2 点2
 @return 距离
 */
double getSpacePointToPoint(cv::Point p1, cv::Point p2)
{
    int a = p1.x-p2.x;
    int b = p1.y-p2.y;
    return sqrt(a * a + b * b);
}

/**
 两直线的交点

 @param a 线段1
 @param b 线段2
 @return 交点
 */
cv::Point2f computeIntersect(cv::Vec4i a, cv::Vec4i b)  
{  
    float x1 = a[0], y1 = a[1], x2 = a[2], y2 = a[3], x3 = b[0], y3 = b[1], x4 = b[2], y4 = b[3];

    if (float d = ((float)(x1 - x2) * (y3 - y4)) - ((y1 - y2) * (x3 - x4)))  
    {  
        cv::Point2f pt;
        float xy1 = x1 * y2 - y1 * x2;
        float xy2 = x3 * y4 - y3 * x4;
        pt.x = (xy1 * (x3 - x4) - (x1 - x2) * xy2) / d;
        pt.y = (xy1 * (y3 - y4) - (y1 - y2) * xy2) / d;
        return pt;  
    }  
    else  
        return cv::Point2f(-1, -1);  
}  

/**
 对多个点按顺时针排序

 @param corners 点的集合
 */
void sortCorners(std::vector<cv::Point2f>& corners)
{
    if (corners.size() == 0) return;
    //先延 X轴排列
    cv::Point pl = corners[0];
    int index = 0;
    for (int i = 1; i < corners.size(); i++) 
    {
        cv::Point point = corners[i];
        if (pl.x > point.x) 
        {
            pl = point;
            index = i;
        }
    }
    corners[index] = corners[0];
    corners[0] = pl;

    cv::Point lp = corners[0];
    for (int i = 1; i < corners.size(); i++) 
    {
        for (int j = i+1; j<corners.size(); j++) 
        {
            cv::Point point1 = corners[i];
            cv::Point point2 = corners[j];
            if ((point1.y-lp.y*1.0)/(point1.x-lp.x)>(point2.y-lp.y*1.0)/(point2.x-lp.x)) 
            {
                cv::Point temp = point1;
                corners[i] = corners[j];
                corners[j] = temp;
            }
        }
    }
}


void make_adjust_area(vector<cv::Point2f> corns,void (*adjust_area)(FPoint*, int32_t)){
    FPoint *dPts = (FPoint*)malloc(sizeof(FPoint)*corns.size());

    //对顶点顺时针排序
    sortCorners(corns);

     //绘制出四条边
     for (int i = 0; i < corns.size(); i++)
     {
         dPts[i].x = corns[i].x;
         dPts[i].y = corns[i].y;
        //  dPts++;
        //  line(mat, cornors1[i], cornors1[(i+1)%cornors1.size()], Scalar(0,0,255), 5);
     }

     adjust_area(dPts,(int32_t)corns.size() );
     free(dPts);
     dPts=nullptr;

}

void draw_quadrangle(Mat &mat,void (*adjust_area)(FPoint*, int32_t))
{
    Mat src_gray;//, filtered, edges, dilated_edges;
    vector<cv::Point2f> cornors1;

    //获取灰度图像
    cvtColor(mat, src_gray, COLOR_BGR2GRAY);

    // 高斯滤波，降噪
//    GaussianBlur(src_gray, filtered, Size(3,3), 2, 2);
    //滤波，模糊处理，消除某些背景干扰信息
     blur(src_gray, src_gray, cv::Size(3, 3));
     //腐蚀操作，消除某些背景干扰信息
     erode(src_gray, src_gray, Mat(),cv::Point(-1, -1), 3, 1, 1);

     int thresh = 35;
     //边缘检测
     Canny(src_gray, src_gray, thresh, thresh*3, 3);
     //膨胀操作，尽量使边缘闭合
    dilate(src_gray, src_gray, Mat(), cv::Point(-1, -1), 3, 1, 1);

     vector<vector<cv::Point> > contours, squares, hulls;
     //寻找边框
     findContours(src_gray, contours, RETR_LIST, CHAIN_APPROX_SIMPLE);
    // findContours(src_gray, contours, mat, RETR_EXTERNAL, CHAIN_APPROX_SIMPLE);

    vector<cv::Point> hull, approx;
    for (size_t i = 0; i < contours.size(); i++)
    {
        //边框的凸包
        convexHull(contours[i], hull);
        //多边形拟合凸包边框(此时的拟合的精度较低)
        approxPolyDP(Mat(hull), approx, arcLength(Mat(hull), true)*0.02, true);
        //筛选出面积大于某一阈值的，且四边形的各个角度都接近直角的凸四边形
        if (approx.size() == 4 && fabs(contourArea(Mat(approx))) > 40000 &&
                isContourConvex(Mat(approx)))
        {
            double maxCosine = 0;
            for (int j = 2; j < 5; j++)
            {
                double cosine = fabs(getAngle(approx[j%4], approx[j-2], approx[j-1]));
                maxCosine = MAX(maxCosine, cosine);
            }
                //角度大概72度
            if (maxCosine < 0.3)
            {
                squares.push_back(approx);
                hulls.push_back(hull);
             }
         }
    }

    vector<cv::Point> largest_square;
    //找出外接矩形最大的四边形
    int idex = findLargestSquare(squares, largest_square);

    if (largest_square.size() == 0 || idex == -1){
        cornors1.push_back(cv::Point(src_gray.cols/6,src_gray.rows/6));
        cornors1.push_back(cv::Point(src_gray.cols*5/6,src_gray.rows/6));
        cornors1.push_back(cv::Point(src_gray.cols*5/6,src_gray.rows*5/6));
        cornors1.push_back(cv::Point(src_gray.cols/6,src_gray.rows*5/6));
        make_adjust_area(cornors1,adjust_area);
        return;
    } 
    //找到这个最大的四边形对应的凸边框，再次进行多边形拟合，此次精度较高，拟合的结果可能是大于4条边的多边形
    //接下来的操作，主要是为了解决，证件有圆角时检测到的四个顶点的连线会有切边的问题
    hull = hulls[idex];
     approxPolyDP(Mat(hull), approx, 3, true);
    vector<cv::Point> newApprox;
    double maxL = arcLength(Mat(approx), true)*0.02;
    //找到高精度拟合时得到的顶点中 距离小于 低精度拟合得到的四个顶点 maxL的顶点，排除部分顶点的干扰
    for (size_t i = 0; i < approx.size(); i++)
    {
        cv::Point p = approx[i];
        if (!(getSpacePointToPoint(p, largest_square[0]) > maxL &&
            getSpacePointToPoint(p, largest_square[1]) > maxL &&
            getSpacePointToPoint(p, largest_square[2]) > maxL &&
            getSpacePointToPoint(p, largest_square[3]) > maxL))
        {
            newApprox.push_back(p);
        }
    }
    //找到剩余顶点连线中，边长大于 2 * maxL的四条边作为四边形物体的四条边
    vector<Vec4i> lines;
    for (int i = 0; i < newApprox.size(); i++)
    {
        cv::Point p1 = newApprox[i];
        cv::Point p2 = newApprox[(i+1)%newApprox.size()];
        if (getSpacePointToPoint(p1, p2) > 2 * maxL)
        {
            lines.push_back(Vec4i(p1.x, p1.y, p2.x,p2.y));
        }
    }

     //计算出这四条边中 相邻两条边的交点，即物体的四个顶点
     for (int i = 0; i < lines.size(); i++)
     {
         cv::Point cornor = computeIntersect(lines[i],lines[(i+1)%lines.size()]);
         cornors1.push_back(cornor);
     }

    make_adjust_area(cornors1,adjust_area);
    // FPoint *dPts = (FPoint*)malloc(sizeof(FPoint)*cornors1.size());
    // // FPoint *sPts = dPts;
    //  //绘制出四条边
    //  for (int i = 0; i < cornors1.size(); i++)
    //  {
    //      dPts[i].x = cornors1[i].x;
    //      dPts[i].y = cornors1[i].y;
    //     //  dPts++;
    //     //  line(mat, cornors1[i], cornors1[(i+1)%cornors1.size()], Scalar(0,0,255), 5);
    //  }

    //  adjust_area(dPts,(int32_t)cornors1.size() );
    //  free(dPts);
    //  dPts=nullptr;
}

/// 把四边形变换为矩形
/// 参数 mat - Mat 类型，指定要谈换的图象
///     pts - FPoint 类型，指定四边形的顶点
///     aspectRatio - double 类型，指定矩形的长宽比
/// 返回 无（由变换后的 mat 返回）
void square_quadrangle(Mat &mat,FPoint *pts, double aspectRatio=21.0/29.7){
    vector<cv::Point2f> cornors1;
    for(int i=0;i<4;i++){
        cornors1.push_back(Point2f(pts[i].x,pts[i].y));
    }
    //计算目标图像的尺寸
    cv::Point2f p0 = cornors1[0];
    cv::Point2f p1 = cornors1[1];
    cv::Point2f p2 = cornors1[2];
    cv::Point2f p3 = cornors1[3];
    // float space0 = getSpacePointToPoint(p0, p1);
    // float space2 = getSpacePointToPoint(p2, p3);
    // float height = space0 > space2 ? space0 : space2;
    float space0 = getSpacePointToPoint(p0, p1);
    float space1 = getSpacePointToPoint(p1, p2);
    float space2 = getSpacePointToPoint(p2, p3);
    float space3 = getSpacePointToPoint(p3, p0);

    float ew = space1 > space3 ? space1 : space3;
    float eh = space0 > space2 ? space0 : space2;

    // 如果提取出的图片宽高比与实体不一致，则旋转90度
    if((aspectRatio<1 && ew > eh)||(aspectRatio>1 && ew < eh)){
        float temp = ew;
        ew = eh;
        eh = temp;
        Point tempPoint = p3;
        p3 = p2;
        p2 = p1;
        p1 = p0;
        p0 = tempPoint;
    }
    vector<cv::Point2f> cornerMat;
    cornerMat.push_back(p0);
    cornerMat.push_back(p1);
    cornerMat.push_back(p2);
    cornerMat.push_back(p3);

    Mat quad = Mat::zeros(eh, eh*aspectRatio, CV_8UC3);
    std::vector<cv::Point2f> quad_pts;
    quad_pts.push_back(cv::Point2f(0, quad.rows));
    quad_pts.push_back(cv::Point2f(0, 0));
    quad_pts.push_back(cv::Point2f(quad.cols, 0));
    quad_pts.push_back(cv::Point2f(quad.cols, quad.rows));

    //提取图像
    // Mat transmtx = getPerspectiveTransform(cornors1 , quad_pts);
    Mat transmtx = getPerspectiveTransform(cornerMat , quad_pts);
    warpPerspective(mat, mat, transmtx, quad.size());
}

/// 查找可能的最大四边形
/// 参数 imgMat - uint8_t* 类型，指定包含要查找四边形的图象
///     imgLengthBytes - int32_t* 类型，指定图象的字节数
///     adjust_area - void (*)(FPoint*, int32_t) 类型，传回找到的四边形顶点回调
DART_API void process_image(
        uint8_t *imgMat,
        int32_t *imgLengthBytes, 
        void (*adjust_area)(FPoint*, int32_t)) {
    
    Mat *src = opencv_decodeImage(imgMat, (unsigned*)imgLengthBytes);
    if (src == nullptr || src->data == nullptr){
        double datas[8] = {10,10,100,10,100,100,10,100};

        FPoint *dPts = (FPoint*)malloc(sizeof(FPoint)*4);
        for(int i=0;i<4;i++){
            dPts[i].x = datas[i*2];
            dPts[i].y = datas[i*2+1];
        }
        adjust_area(dPts,4);
        free(dPts);
        dPts=nullptr;
    }else
        draw_quadrangle(*src,adjust_area);
}

//
//static void getBinMask( const Mat& comMask, Mat& binMask ){
//	binMask.create( comMask.size(), CV_8UC1 );
//	binMask = comMask & 1;
//}

Mat *img = nullptr;
Mat mask,bgdModel, fgdModel;
Scalar bkColor;
Rect rect;
bool init = false;


/// 去除背景
/// 参数 imgMat - unit8_t 指针类型，指向图象数据(通常与手机屏幕尺寸相匹配)
///     imgLengthByte - int32_t 指针类型，指向包含图象数据字节长度的整数
///     recti - RectI 指针类型，指定要操作的矩形区域
///     color - int32_t 类型，首次调用时指定背景颜色，否则指定掩码类型
DART_API unsigned char *remove_background(uint8_t *imgMat,int32_t *imgLengthBytes,RectI *recti,int32_t color){
    if(imgMat==nullptr&&img!=nullptr){
        img = nullptr;
        mask.release();
        bgdModel.release();
        fgdModel.release();
        init = false;
        return nullptr;
    }
    rect.x = max(0,recti->x);
    rect.y = max(0,recti->y);
    rect.width = recti->width;
    rect.height = recti->height;
    if(img==nullptr){
        img = opencv_decodeImage(imgMat, (unsigned*)imgLengthBytes);
        mask.create(img->size(), CV_8UC1);
        mask.setTo(GC_BGD);
	    mask(rect).setTo(Scalar(GC_PR_FGD));
        bkColor = Scalar(color&0xff, color>>8&0xff, color>>16&0xff);
    } else {
        Scalar scalar;
        switch (color)
        {
        case 0:
            scalar = Scalar(GC_BGD);
            break;
        case 1:
            scalar = Scalar(GC_FGD);
            break;
        case 2:
            scalar = Scalar(GC_PR_BGD);
            break;
        case 3:
            scalar = Scalar(GC_PR_FGD);
            break;
        
        default:
            scalar = Scalar(GC_BGD);
            break;
        }
        mask(rect).setTo(Scalar(scalar));
    }
	// setRectInMask();
	// rectangle(*img, Point(x, y), Point(x + width, y + height ), GREEN, 2);
	// img = opencv_decodeImage(imgMat, (unsigned*)imgLengthBytes);
	// image = imread( filename, 1 );

    if(init)
	    grabCut(*img, mask, rect, bgdModel, fgdModel, 1);
    else{
        grabCut(*img, mask, rect, bgdModel, fgdModel, 1, GC_INIT_WITH_RECT);
        init = true;
    }
//	getBinMask(mask, binMask);
    // compare(mask, GC_PR_FGD, mask, CMP_EQ);
    Mat maskBin = mask&1;

    // 新建与原图相同尺寸，且颜色为 color 指定的8位3通道图像
    Mat res(img->size(), CV_8UC3, bkColor);
	
    // 只考贝 img 中由 maskBin 标识的前景数据到 res
    img->copyTo(res, maskBin);

    static std::vector<uchar> buf(1);
    
    imencode(".png", res, buf);
  
    *imgLengthBytes = (int32_t)buf.size();
    return buf.data();
}


/// 用 remove_background 函数设定好的 mask(掩码信息)，调整其尺寸与给定图象尺寸一致后，去除背景
/// 参数 imgMat - unit8_t 指针类型，指向图象数据
///     imgLengthByte - int32_t 指针类型，指向包含图象数据字节长度的整数
DART_API unsigned char *remove_background_last(uint8_t *imgMat,int32_t *imgLengthBytes){
    img = opencv_decodeImage(imgMat, (unsigned*)imgLengthBytes);
    Mat maskBin;
    resize(mask&1,maskBin,img->size());

    // 新建与原图相同尺寸，且颜色为 color 指定的8位3通道图像
    Mat res(img->size(), CV_8UC3, bkColor);
	
    // 只考贝 img 中由 maskBin 标识的前景数据到 res
    img->copyTo(res, maskBin);

    static std::vector<uchar> buf(1);
    
    imencode(".png", res, buf);
  
    *imgLengthBytes = (int32_t)buf.size();
    return buf.data();
}


// DART_API unsigned char *remove_background(uint8_t *imgMat,int32_t *imgLengthBytes,int32_t x,int32_t y,int32_t width,int32_t height){
// //    const Scalar GREEN = Scalar(0,255,0);
//     Mat bgdModel, fgdModel;
// //	Mat binMask;
//     Mat mask;
//     Rect rect;
//     rect.x = x;
//     rect.y = y;
//     rect.width = width;
//     rect.height = height;
//     Mat *img = opencv_decodeImage(imgMat, (unsigned*)imgLengthBytes);
//     // if (img == nullptr || img->data == nullptr){
// 	mask.create(img->size(), CV_8UC1);
// 	mask.setTo(GC_BGD);
// 	// setRectInMask();
// 	mask(rect).setTo(Scalar(GC_PR_FGD));
// 	// rectangle(*img, Point(x, y), Point(x + width, y + height ), GREEN, 2);
// 	// img = opencv_decodeImage(imgMat, (unsigned*)imgLengthBytes);
// 	// image = imread( filename, 1 );
// 	grabCut(*img, mask, rect, bgdModel, fgdModel, 1, GC_INIT_WITH_RECT);
// //	getBinMask(mask, binMask);
//     // compare(mask, GC_PR_FGD, mask, CMP_EQ);
//      mask = mask&1;
//     Mat res(img->size(), CV_8UC3, Scalar(255, 255, 255));
// 	img->copyTo(res, mask);
// 	// img->copyTo(res, mask);
//     static std::vector<uchar> buf(1);
    
//     imencode(".png", res, buf);
  
//     *imgLengthBytes = (int32_t)buf.size();
//     return buf.data();
// }

DART_API unsigned char *remove_background1(uint8_t *imgMat,int32_t *imgLengthBytes){
//    const Scalar GREEN = Scalar(0,255,0);
    Mat bgdModel, fgdModel;
	Mat binMask, res;
    Mat *img = opencv_decodeImage(imgMat, (unsigned*)imgLengthBytes);
    if (img == nullptr || img->data == nullptr){
        printf( "could not load image...\n");
        return nullptr;
    }

    // 将二维图像数据线性化
    Mat data;
    for( int i = 0; i < img->rows; i++) { //像素点线性排列
        for( int j = 0; j < img->cols; j++)
        {
            Vec3b point = img->at<Vec3b>(i, j);
            Mat tmp = (Mat_< float>( 1, 3) << point[ 0], point[ 1], point[ 2]);
            data.push_back(tmp);
        }
    }

    // 使用K-means聚类
    int numCluster = 4;
    Mat labels;
    TermCriteria criteria = TermCriteria(TermCriteria::EPS + TermCriteria::COUNT, 10, 0.1);
    kmeans(data, numCluster, labels, criteria, 4, KMEANS_PP_CENTERS);

    // 背景与手机二值化
    Mat mask = Mat::zeros(img->size(), CV_8UC1);
    int index = img->rows * 2+ 2; //获取点（2，2）作为背景色
    int cindex = labels.at< int>(index);

    /* 提取背景特征 */
    for( int row = 0; row < img->rows; row++) {
        for( int col = 0; col < img->cols; col++) {
            index = row * img->cols + col;
            int label = labels.at< int>(index);
            if(label == cindex) { // 背景
                mask.at<uchar>(row, col) = 0;
            }
            else{
                mask.at<uchar>(row, col) = 255;
            }
        }
    }
    // imshow( "mask", mask);
    // 腐蚀 + 高斯模糊：图像与背景交汇处高斯模糊化
    Mat k = getStructuringElement(MORPH_RECT, Size( 3, 3), Point( -1, -1));
    erode(mask, mask, k);
    GaussianBlur(mask, mask, Size( 3, 3), 0, 0);

    // 更换背景色以及交汇处融合处理
    RNG rng( 12345) ;
    Vec3b color; //设置的背景色
    color[0] = 255; //rng.uniform(0, 255);
    color[1] = 255; // rng.uniform(0, 255);
    color[2] = 255; // rng.uniform(0, 255);
    Mat result(img->size(), img->type());
    double w = 0.0; //融合权重
    int b = 0, g = 0, r = 0;
    int b1 = 0, g1 = 0, r1 = 0;
    int b2 = 0, g2 = 0, r2 = 0;
    for( int row = 0; row < img->rows; row++) {
        for( int col = 0; col < img->cols; col++) {
            int m = mask.at<uchar>(row, col);
            if(m == 255) {
                result.at<Vec3b>(row, col) = img->at<Vec3b>(row, col); // 前景
            }
            else if(m == 0) {
                result.at<Vec3b>(row, col) = color; // 背景
            }
            else{ /* 融合处理部分 */
                w = m / 255.0;
                b1 = img->at<Vec3b>(row, col)[0];
                g1 = img->at<Vec3b>(row, col)[1];
                r1 = img->at<Vec3b>(row, col)[2];
                b2 = color[0];
                g2 = color[1];
                r2 = color[2];
                b = b1 * w + b2 * (1.0- w);
                g = g1 * w + g2 * (1.0- w);
                r = r1 * w + r2 * (1.0- w);
                result.at<Vec3b>(row, col)[0] = b;
                result.at<Vec3b>(row, col)[1] = g;
                result.at<Vec3b>(row, col)[2] = r;
            }
        }
    }
    static std::vector<uchar> buf(1);   
    imencode(".png", result, buf);
    *imgLengthBytes = (int32_t)buf.size();
    return buf.data();
}

/// 旋转图象
/// 参数 imgMat - uint8_t 指针类型，指定图象
///     imgLengthBytes - int32_t 指针类型，指向图象字节数
/// 返回 unsigned char 指针类型，指定矩形区域图象（矩形区域外的图象被裁剪）
DART_API unsigned char *rotate_image(
        uint8_t *imgMat,
        int32_t *imgLengthBytes){
    
    Mat *dimg = opencv_decodeImage(imgMat, (unsigned*)imgLengthBytes);
    if (dimg == nullptr || dimg->data == nullptr)
        return nullptr;
    Mat dst;
    rotate(*dimg,dst,ROTATE_90_CLOCKWISE);
    static std::vector<uchar> buf(1); 
    
    imencode(".png", dst, buf);
  
    *imgLengthBytes = (int32_t)buf.size();
    free(dimg);
    dimg = nullptr;
    return buf.data();
}

/// 把图象中由四个顶点组成的四边形区域变换成给定长宽比的矩形区域（摆正图象）
/// 参数 imgMat - uint8_t 指针类型，指定图象
///     imgLengthBytes - int32_t 指针类型，指向图象字节数
///     pts - FPoint 指针类型，指定四边形的四个顶点
///     aspectRatio - double_t 类型，指定矩形的长宽比
/// 返回 unsigned char 指针类型，指定矩形区域图象（矩形区域外的图象被裁剪）
DART_API unsigned char *square_image(
        int32_t *imgLengthBytes, 
        FPoint *pts,
        double_t aspectRatio=21.0/29.7) {
    
    if (src == nullptr || src->data == nullptr)
        return nullptr;
    Mat src1 =(*src).clone();
    square_quadrangle(src1,pts,aspectRatio);
    static std::vector<uchar> buf(1); 
    
    imencode(".png", src1, buf);
  
    *imgLengthBytes = (int32_t)buf.size();
    return buf.data();
}

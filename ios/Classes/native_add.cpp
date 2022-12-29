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

DART_API FPoint *create_points(int32_t length){
    auto *points = (FPoint *)malloc(length * sizeof(FPoint));
    return points;
}

//定义结构体Point，表示平面上的一点
typedef struct {
    int32_t x;
    int32_t y;
    int32_t width;
    int32_t height;
} RectI;

DART_API RectI *create_rects(int32_t length){
    auto *rects = (RectI *)malloc(length * sizeof(RectI));
    return rects;
}

inline cv::Scalar colorToScalar(int32_t color){
    return cv::Scalar(color&0xff, color>>8&0xff, color>>16&0xff);
}

DART_API int32_t native_add(int32_t x, int32_t y) {
    Mat m = Mat::zeros(x, y, CV_8UC3);
    return m.rows + m.cols;
}

Mat srcImg ;

Mat *opencv_decodeImage(
        uint8_t *img,
        unsigned *imgLengthBytes,Mat &src) {
 
    std::vector<unsigned char> m;
 
    // __android_log_print(ANDROID_LOG_VERBOSE, "NATIVE",
    //                     "opencv_decodeImage() ---  start imgLengthBytes:%d ",
    //                     *imgLengthBytes);
 
    unsigned len = *imgLengthBytes;
    for (unsigned i = 0; i<len; i++)
         m.push_back(*(img++));
 
    src = imdecode(m, cv::IMREAD_COLOR);
    if (src.data == nullptr)
        return nullptr;
 
    // if (DEBUG_NATIVE)
    //     __android_log_print(ANDROID_LOG_VERBOSE, "NATIVE",
    //                         "opencv_decodeImage() ---  len before:%d  len after:%d  width:%d  height:%d",
    //                         *imgLengthBytes, src->step[0] * src->rows,
    //                         src->cols, src->rows);
 
    *imgLengthBytes = src.step[0] * src.rows;
    return &src;
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

    // 如果没找到最大的四边形，则给定一个矩形以便进行人工选择
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
    Mat transmtx = getPerspectiveTransform(cornerMat, quad_pts);
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
    
    opencv_decodeImage(imgMat, (unsigned*)imgLengthBytes,srcImg);
    // if (src == nullptr || src->data == nullptr){
    //     adjust_area(nullptr,4);
    // }else
        draw_quadrangle(srcImg,adjust_area);
}

Mat imgBack;
Mat mask,bgdModel, fgdModel;
Scalar bkColor;
Rect sourceRect;
Rect rect;
bool init = false;

/// 抠图
/// 参数 imgMat - unit8_t 指针类型，指向图象数据(通常与手机屏幕尺寸相匹配)
///     imgLengthByte - int32_t 指针类型，指向包含图象数据字节长度的整数
///     recti - RectI 指针类型，指定要操作的矩形区域
///     color - int32_t 类型，首次调用时指定背景颜色，否则指定掩码类型
DART_API unsigned char *remove_background(uint8_t *imgMat,int32_t *imgLengthBytes,RectI *recti,int32_t color,int32_t shape){
    if(imgMat==nullptr&&!imgBack.empty()){
        imgBack.release();
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
    if(imgBack.empty()){
        sourceRect = rect;
        opencv_decodeImage(imgMat, (unsigned*)imgLengthBytes,imgBack);
        mask.create(imgBack.size(), CV_8UC1);
        mask.setTo(GC_BGD);
	    mask(rect).setTo(Scalar(GC_PR_FGD));
        bkColor = colorToScalar(color);
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
        if(shape==0)
            mask(rect).setTo(Scalar(scalar));
        else
            circle(mask,rect.tl()+Point(rect.width/2.0,rect.height/2.0),rect.width/2.0,Scalar(scalar),-1);
    }
	// setRectInMask();
	// rectangle(*img, Point(x, y), Point(x + width, y + height ), GREEN, 2);
	// img = opencv_decodeImage(imgMat, (unsigned*)imgLengthBytes);
	// image = imread( filename, 1 );

    if(init)
	    // grabCut(imgBack, mask, rect, bgdModel, fgdModel, 1);
	    grabCut(imgBack(sourceRect), mask(sourceRect), rect-sourceRect.tl(), bgdModel, fgdModel, 1);
    else{
        grabCut(imgBack, mask, rect, bgdModel, fgdModel, 1, GC_INIT_WITH_RECT);
        init = true;
    }
//	getBinMask(mask, binMask);
    // compare(mask, GC_PR_FGD, mask, CMP_EQ);
    Mat maskBin = mask&1;

    // 新建与原图相同尺寸，且颜色为 color 指定的8位3通道图像
    Mat res(imgBack.size(), CV_8UC3, bkColor);
	
    // 只考贝 img 中由 maskBin 标识的前景数据到 res
    imgBack.copyTo(res, maskBin);

    static std::vector<uchar> buf(1);
    
    imencode(".png", res, buf);
  
    *imgLengthBytes = (int32_t)buf.size();
    return buf.data();
}

/// 用 remove_background 函数设定好的 mask(掩码信息)，调整其尺寸与给定图象尺寸一致后，去除背景
/// 参数 imgMat - unit8_t 指针类型，指向图象数据
///     imgLengthByte - int32_t 指针类型，指向包含图象数据字节长度的整数
DART_API unsigned char *remove_background_last(uint8_t *imgMat,int32_t *imgLengthBytes){
    Mat img;
    opencv_decodeImage(imgMat, (unsigned*)imgLengthBytes,img);
    Mat maskBin;
    resize(mask&1,maskBin,img.size());

    // 新建与原图相同尺寸，且颜色为 color 指定的8位3通道图像
    Mat res(img.size(), CV_8UC3, bkColor);
	
    // 只考贝 img 中由 maskBin 标识的前景数据到 res
    img.copyTo(res, maskBin);

    static std::vector<uchar> buf(1);
    
    imencode(".png", res, buf);
  
    *imgLengthBytes = (int32_t)buf.size();
    return buf.data();
}

// void _get_role_image(uint8_t *imgMat,int32_t *imgLengthBytes,RectI *recti,Mat& result){
//     Mat dimg;
//     opencv_decodeImage(imgMat, (unsigned*)imgLengthBytes,dimg);
//     Rect r = Rect(max(0,recti->x),max(0,recti->y),recti->width,recti->height);
//     Mat roleMask = Mat(mask,r).clone();
//     Mat dst = Mat(dimg,r).clone();
//     Mat res(dst.size(), CV_8UC3, bkColor);
//     dst.copyTo(res,roleMask&1);
//     result = res;
// }

DART_API unsigned char *get_role_image(uint8_t *imgMat,int32_t *imgLengthBytes,RectI *recti){
    Mat dimg;
    opencv_decodeImage(imgMat, (unsigned*)imgLengthBytes,dimg);
    if (dimg.data == nullptr)
        return nullptr;
    // Mat res;
    // _get_role_image(imgMat,recti,res);
    // Rect r = Rect(max(0,recti->x),max(0,recti->y),recti->width,recti->height);
    Rect r = boundingRect(mask);
    Mat roleMask = Mat(mask,r).clone();
    Mat dst = Mat(dimg,r).clone();
    cvtColor(dst,dst,COLOR_BGR2BGRA);
    Mat res(dst.size(),CV_8UC4,Scalar(255,255,255,0));
    // Mat res(dst.size(), CV_8UC3, bkColor);
    dst.copyTo(res,roleMask&1);

    static std::vector<uchar> buf(1); 
    
    imencode(".png", res, buf);
  
    *imgLengthBytes = (int32_t)buf.size();
    recti->x = r.x;
    recti->y = r.y;
    recti->width = r.width;
    recti->height = r.height;
    return buf.data();
}

/// 把 roleImg 中的图象，按 rects 矩形数组中各矩形指定的位置和大小，贴进 backImg 相应的区域。
/// 参数 roleImg - unit8_t 指针类型，指向角色图象数据
///     imgLengthByte - int32_t 指针类型，指向包含角色图象数据字节长度的整数
///     backImg - unit8_t 指针类型，指向背景图象数据
///     backImgLengthByte - int32_t 指针类型，指向包含背景图象数据字节长度的整数
///     rects - RectI* 类型，指定矩形数组，第一个指定源角色图象大小，其余的指定要刷入角色图象的位置和大小
///     rectsCount - Int32_t 类型，指定矩形数量。
DART_API unsigned char *draw_roles(uint8_t *roleImg,int32_t *imgLengthBytes,uint8_t *backImg,int32_t *backImgLengthBytes,RectI *rects,int32_t rectsCount){
    Mat img,bgImg;
    opencv_decodeImage(roleImg, (unsigned*)imgLengthBytes,img);
    opencv_decodeImage(backImg, (unsigned*)backImgLengthBytes,bgImg);
    Rect r = Rect(max(0,rects->x),max(0,rects->y),rects->width,rects->height);
    Mat roleMask = Mat(mask,r).clone();
    for(int i=1;i<rectsCount;i++){
        RectI *p = rects+i;
        Rect r = Rect(max(0,p->x),max(0,p->y),p->width,p->height);
        Mat role,maskBin;
        resize(img,role,r.size());
        resize(roleMask&1,maskBin,r.size());
        role.copyTo(bgImg(r), maskBin);
    }

     static std::vector<uchar> buf(1);
    
    imencode(".png", bgImg, buf);
  
    *imgLengthBytes = (int32_t)buf.size();
    return buf.data();
}
 
/// 图像旋转
void Rotate(const cv::Mat &srcImage, cv::Mat &dstImage, double angle, cv::Point2f center, double scale)
{
	cv::Mat M = cv::getRotationMatrix2D(center, angle, scale);//计算旋转的仿射变换矩阵 
	cv::warpAffine(srcImage, dstImage, M, cv::Size(srcImage.cols, srcImage.rows));//仿射变换  
}

/// 旋转图象
/// 参数 imgMat - uint8_t 指针类型，指定图象
///     imgLengthBytes - int32_t 指针类型，指向图象字节数
///     direction - int32_t 类型，指定旋转码 -1 - 逆时针旋转90度，0 - 旋转180度，1 - 顺时针旋转90度
/// 返回 unsigned char 指针类型，指定矩形区域图象（矩形区域外的图象被裁剪）
DART_API unsigned char *rotate_image(
        uint8_t *imgMat,
        int32_t *imgLengthBytes,
        int32_t direction){
    
    Mat dimg;
    opencv_decodeImage(imgMat, (unsigned*)imgLengthBytes,dimg);
    if (dimg.empty() || dimg.data == nullptr)
        return nullptr;
    Mat dst;
    int rotateCode;
    switch (direction)
    {
    case -1:
       rotateCode = ROTATE_90_COUNTERCLOCKWISE;
        break;
    case 0:
        rotateCode = ROTATE_180;
    case 1:
        rotateCode = ROTATE_90_CLOCKWISE;
    default:
        rotateCode = ROTATE_90_CLOCKWISE;
        break;
    }
    rotate(dimg,dst,rotateCode);
    static std::vector<uchar> buf(1); 
    
    imencode(".png", dst, buf);
  
    *imgLengthBytes = (int32_t)buf.size();
    return buf.data();
}

/// 复制区域图象
/// 参数 imgMat - uint8_t 指针类型，指定图象
///     imgLengthBytes - int32_t 指针类型，指向图象字节数
/// 返回 unsigned char 指针类型，指定矩形区域图象（矩形区域外的图象被裁剪）
DART_API unsigned char *copy_image(
        uint8_t *imgMat,
        int32_t *imgLengthBytes,
        RectI *recti){
    
    Mat dimg;
    opencv_decodeImage(imgMat, (unsigned*)imgLengthBytes,dimg);
    if (dimg.data == nullptr)
        return nullptr;
    
    Rect r = Rect(max(0,recti->x),max(0,recti->y),recti->width,recti->height);
    Mat dst = Mat(dimg,r).clone();
    static std::vector<uchar> buf(1); 
    
    imencode(".png", dst, buf);
  
    *imgLengthBytes = (int32_t)buf.size();
    return buf.data();
}

/// 复制区域图象
/// 参数 imgMat - uint8_t 指针类型，指定图象
///     imgLengthBytes - int32_t 指针类型，指向图象字节数
/// 返回 unsigned char 指针类型，指定矩形区域图象（矩形区域外的图象被裁剪）
DART_API unsigned char *fill_color(
        uint8_t *imgMat,
        int32_t *imgLengthBytes,
        RectI *recti,
        int32_t color){
    
    Mat dimg;
    opencv_decodeImage(imgMat, (unsigned*)imgLengthBytes,dimg);
    if (dimg.data == nullptr)
        return nullptr;
    
    Rect r = Rect(max(0,recti->x),max(0,recti->y),recti->width,recti->height);
    vector<Point>  contour;
    contour.push_back(r.tl());
    contour.push_back(Point(r.tl().x + r.width , r.tl().y ) );
    contour.push_back(Point(r.tl().x + r.width , r.tl().y + r.height));
    contour.push_back(Point(r.tl().x , r.tl().y + r.height ));

    cv::fillConvexPoly(dimg, contour, dimg.at<Vec3b>(2, 2));//fillPoly函数的第二个参数是二维数组！！

    static std::vector<uchar> buf(1); 
    
    imencode(".png", dimg, buf);
  
    *imgLengthBytes = (int32_t)buf.size();
    return buf.data();
}

/// 复制区域图象
/// 参数 imgMat - uint8_t 指针类型，指定图象
///     imgLengthBytes - int32_t 指针类型，指向图象字节数
/// 返回 unsigned char 指针类型，指定矩形区域图象（矩形区域外的图象被裁剪）
DART_API unsigned char *fill_image(
        uint8_t *imgMat,
        int32_t *imgLengthBytes,
        RectI *recti,
        uint8_t *fillImg,
        int32_t fillImgLengthBytes){
    
    // 处理待填充图像
    Mat dimg;
    opencv_decodeImage(imgMat, (unsigned*)imgLengthBytes,dimg);
    if (dimg.data == nullptr)
        return nullptr;
    
    // 处理待复制图片
    Mat roi;
    opencv_decodeImage(fillImg, (unsigned*)&fillImgLengthBytes,roi);
    if (roi.data == nullptr)
        return nullptr;
    
    // 设置绘制区域并复制
    Rect r = Rect(max(0,recti->x),max(0,recti->y),roi.cols,roi.rows);
    roi.copyTo(dimg(r));

    // 转换为字节编码并返回
    static std::vector<uchar> buf(1); 
    imencode(".png", dimg, buf);
    *imgLengthBytes = (int32_t)buf.size();
    return buf.data();
}

/// 摆正区域图象
/// 参数 imgMat - uint8_t 指针类型，指定图象
///     imgLengthBytes - int32_t 指针类型，指向图象字节数
///     ptArray = FPointArray 类型，指定要摆正的图象区域
/// 返回 unsigned char 指针类型，包含被摆正后的图象字节数据
DART_API unsigned char *straight_image(
        uint8_t *imgMat,
        int32_t *imgLengthBytes,
        FPoint *ptArray
        ){
    
    // 处理待填充图像
    Mat dimg,mask;
    opencv_decodeImage(imgMat, (unsigned*)imgLengthBytes,dimg);
    if (dimg.data == nullptr)
        return nullptr;

    mask.create(dimg.size(), CV_8UC1);
    mask.setTo(GC_BGD);
    Point pts[1][4];
    for(int i=0;i<4;i++){
        pts[0][i] = Point(ptArray[i].x,ptArray[i].y);
    }
    const Point* ppt[1]={pts[0]};
    int npt[] = {4};
    fillPoly(mask,ppt,npt,1,Scalar(GC_FGD));
    // mask(rect).setTo(Scalar(GC_PR_FGD));
    Mat maskBin = mask&1;

    // 新建与原图相同尺寸，且颜色为 color 指定的8位3通道图像
    Mat res(dimg.size(), CV_8UC3, dimg.at<Vec3b>(2, 2)),dst;
	Mat res1 = res.clone();
    // 只考贝 dimg 中由 maskBin 标识的前景数据到 res
    dimg.copyTo(res, maskBin);
    // 考贝后，考贝的区域填充背景色
    res1.copyTo(dimg,maskBin);

    // 旋转（摆正）图象
    double hx = ptArray[3].x-ptArray[0].x;
    double hy = ptArray[3].y-ptArray[0].y;
    double angle = atan2(hy,hx);
    cv::Point2f center((ptArray[0].x+ptArray[2].x)/2.0,(ptArray[0].y+ptArray[2].y)/2.0);
    Rotate(res,dst,angle*180.0/M_PI-90.0,center,1.0);

    // 计算旋转后摆正区域矩形
    double wx = ptArray[1].x-ptArray[0].x;
    double wy = ptArray[1].y-ptArray[0].y;
    double rw = sqrt(wx*wx+wy*wy);
    double rh = sqrt(hx*hx+hy*hy);
    Rect r = Rect(center.x-rw/2.0,center.y-rh/2.0,rw,rh);

    // 获取摆正矩形区域图象
    dst = Mat(dst,r).clone();
    
    // 复制摆正矩形区域图象到原图
    dst.copyTo(dimg(r));

    // 转换为字节编码并返回
    static std::vector<uchar> buf(1); 
    imencode(".png", dimg, buf);
    *imgLengthBytes = (int32_t)buf.size();
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
    
    if (srcImg.data == nullptr)
        return nullptr;
    Mat src1 =srcImg.clone();
    square_quadrangle(src1,pts,aspectRatio);
    static std::vector<uchar> buf(1);
    
    imencode(".png", src1, buf);
  
    *imgLengthBytes = buf.size();
    return buf.data();
}

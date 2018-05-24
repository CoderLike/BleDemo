
//  HMBLEDataHelper.h

#import <UIKit/UIKit.h>
#import <CoreBluetooth/CoreBluetooth.h>

///*** 日志 ***/
#ifdef DEBUG
#define LZCLog(...) NSLog(__VA_ARGS__)
#else
#define LZCLog(...)
#endif

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, HmSex) {
	HmSexFemale = 0, 	// 女
	HmSexMale = 1, 		// 男
};

typedef NS_ENUM(NSInteger, HmScaleUnit) {
	HmScaleUnitKilogram = 0, 		// 公斤(kg)
	HmScaleUnitHalfKilogram = 1, 	// 斤
};

typedef NS_ENUM(NSInteger, HmStatus) {
	HmStatusScaleMeasuring = 0, 		// 正在测量...
	HmStatusScaleMeasureLocked = 1, 	// 已锁定当前数据,正在测脂...
	HmStatusScaleMeasureUnusual = 2, 	// 测量结束,未检测到脂肪
	HmStatusScaleMeasureEnd = 3, 		// 测量结束,检测到脂肪
	
	HmStatusBleOn = 10, 	// 手机蓝牙已打开
	HmStatusBleOff = 11, 	// 手机蓝牙已关闭
	
	HmStatusBleConnected = 12, 		// 手机蓝牙已连接外设
	HmStatusBleDisConnected = 13, 	// 手机蓝牙已断开与外设连接
	
	HmStatusBleConnectedTimeOut = 14, // 手机蓝牙扫描或连接外设超时
};


@class HMBLEDataHelper;
@protocol HMBLEDataHelperDelegate <NSObject>

@required

/**
 测量结果

 @param bleDataHelper 助手
 @param result 测量结果
 */
- (void)HMBLEDataHelper:(HMBLEDataHelper *)bleDataHelper result:(NSDictionary *)result;

@optional

/**
 状态(包含手机蓝牙和体脂秤的状态)

 @param bleDataHelper 助手
 @param statusInfo 状态码及信息
 */
- (void)HMBLEDataHelper:(HMBLEDataHelper *)bleDataHelper statusInfo:(NSDictionary *)statusInfo;

@end

@interface HMBLEDataHelper : NSObject

/** 代理 */
@property (nonatomic, weak) __nullable id<HMBLEDataHelperDelegate> delegate;
/** 秤的版本信息 */
@property (nonatomic, strong) NSDictionary * scaleInfo;


/**
 初始化蓝牙助手

 @param userid 当前用户id 方便体脂秤进行用户识别
 @param sex 性别
 @param age 年龄 注:若age<18, 儿童少年的身体成分与成人差异较大,所测脂肪不具参考性
 @param height 身高 (0, 250] cm  
 @param unit 体脂秤单位
 @return 蓝牙助手
 */
+ (instancetype )hm_scanAndConnectScaleWithUserid:(NSString *)userid userSex:(HmSex)sex userAge:(NSUInteger)age userHeight:(CGFloat)height currentUnit:(HmScaleUnit)unit;

/** 扫描外设 */
- (void)hm_scanForPeripherals;

/** 停止扫描 */
- (void)hm_stopScanPeripheral;

/** 连接外设 */
- (void)hm_connectPeripheral;

/** 更换单位 */
- (void)hm_sendUnit:(HmScaleUnit)unit;

/** 更改个人数据 */
- (void)hm_changePersonalDataWithUserid:(NSString *)userid userSex:(HmSex)sex userAge:(NSUInteger)age userHeight:(CGFloat)height;

/** 断开连接 */
- (void)hm_disconnect;

NS_ASSUME_NONNULL_END

@end

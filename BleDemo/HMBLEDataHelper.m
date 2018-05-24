
//  HMBLEDataHelper.m


#import "HMBLEDataHelper.h"


#define HLHServiceUUID                 [CBUUID UUIDWithString:@"0783B03E-8535-B5A0-7140-A304D2495CB7"] // 服务的UUID
#define HLHRWCharacteristicUUID        [CBUUID UUIDWithString:@"0783B03E-8535-B5A0-7140-A304D2495CBA"] // 写特征的UUID
#define HLHRWNCharacteristicUUID       [CBUUID UUIDWithString:@"0783B03E-8535-B5A0-7140-A304D2495CB8"] // 通知特征的UUID

@interface HMBLEDataHelper ()<CBCentralManagerDelegate, CBPeripheralDelegate>

/** 通知 特征 */
@property (nonatomic, strong) CBCharacteristic *notifycharacteristic;
/** 写 特征 */
@property (nonatomic, strong) CBCharacteristic *writecharacteristic;

/** 中心管理者 */
@property (nonatomic, strong) CBCentralManager *cMgr;
/** 连接到的外设 */
@property (nonatomic, strong) CBPeripheral *peripheral;


/** 个人信息 */
@property (nonatomic, copy) NSData *userData;
/** 发送的数据 */
@property (nonatomic, copy) NSString *peripheralDataS;
/** 扫描定时器 15秒*/
@property (nonatomic, strong) NSTimer *timerToStopScanAndConnect;

/** 年龄 */
@property (nonatomic, assign) NSInteger userAge;
/** 身高 */
@property (nonatomic, assign) CGFloat userHeight;
/** 性别 */
@property (nonatomic, assign) HmSex userSex;
/** 当前单位 */
@property (nonatomic, assign) HmScaleUnit currentUnit;
/** 当前用户ID */
@property (nonatomic, copy) NSString *currentUserid;

/** 是否手动断开 */
@property (nonatomic, assign, getter=isManualDisconnect) BOOL manualDisconnect;

@end

@implementation HMBLEDataHelper

#pragma mark - 公开方法

#pragma mark - 初始化
+ (instancetype)hm_scanAndConnectScaleWithUserid:(NSString *)userid userSex:(HmSex)sex userAge:(NSUInteger)age userHeight:(CGFloat)height currentUnit:(HmScaleUnit)unit
{
	return [[self alloc] initWithUserid:userid userSex:sex userAge:age userHeight:height currentUnit:unit];
}


- (instancetype)initWithUserid:(NSString *)userid userSex:(HmSex)sex userAge:(NSUInteger)age userHeight:(CGFloat)height currentUnit:(HmScaleUnit)unit
{
	if (self = [super init]) {
		
		// 保存用户当前信息
		self.currentUserid = userid;
		self.userSex = sex;
		self.userAge = age;
		self.userHeight = height;
		self.currentUnit = unit;
		
		// 初始化中心设备管理器
		self.cMgr = [[CBCentralManager alloc] initWithDelegate:self queue:dispatch_get_main_queue() options:nil];
	}
	
	return self;
}


/** 扫描外设 */
- (void)hm_scanForPeripherals
{
	LZCLog(@"搜索外设,15秒超时计算");
	self.timerToStopScanAndConnect = [self hm_creatTimerToStopScanAndConnectScalePeripheral];
	[self.cMgr scanForPeripheralsWithServices:nil options:nil];
}

/** 停止扫描 */
- (void)hm_stopScanPeripheral
{
	[self.cMgr stopScan];
}

/** 连接外设 */
- (void)hm_connectPeripheral
{
	if (self.cMgr.state == CBManagerStatePoweredOff || self.peripheral == nil) return;
	[self.cMgr connectPeripheral:self.peripheral options:nil];
}

/** 更换单位 */
- (void)hm_sendUnit:(HmScaleUnit)unit
{
	// 0xF5 0x02 AA 00 00 00 00 00 00 00 00 00 00 00 00 CRC
	if (self.peripheral == nil) return;
	Byte CRC = (245 + 2 + unit) & 0x7F;
	Byte byte[] = {245,2,unit,0,0,0,0,0,0,0,0,0,0,0,0,CRC};
	NSData *data = [[NSData alloc] initWithBytes:byte length:16];
	[self hm_peripheral:self.peripheral didWriteData:data forCharacteristic:self.writecharacteristic];
}

/** 更改个人数据 */
- (void)hm_changePersonalDataWithUserid:(NSString *)userid userSex:(HmSex)sex userAge:(NSUInteger)age userHeight:(CGFloat)height
{
	if (self.peripheral == nil) return;
	
	// 保存用户当前信息
	self.currentUserid = userid;
	self.userSex = sex;
	self.userAge = age;
	self.userHeight = height;
	
	self.userData = [self hm_getUserdata];
	[self hm_peripheral:self.peripheral didWriteData:self.userData forCharacteristic:self.writecharacteristic];
}


/** 断开连接 */
- (void)hm_disconnect
{
    self.manualDisconnect = YES;
    
	if (self.cMgr.state == CBManagerStatePoweredOff || self.peripheral == nil || self.peripheral.state == CBPeripheralStateDisconnected) return;
	
	[self hm_setNotifiy:NO];
	[self.cMgr cancelPeripheralConnection:self.peripheral];
	LZCLog(@"取消连接外设");
	
	if ([self.delegate respondsToSelector:@selector(HMBLEDataHelper:statusInfo:)]) {
		[self.delegate HMBLEDataHelper:self statusInfo:@{@"HmStatus" : @"13", @"info" : @"手机蓝牙已断开与外设连接"}];
	}
}


#pragma mark - 私有方法
// 写入数据
- (void)hm_peripheral:(CBPeripheral *)peripheral didWriteData:(NSData *)data forCharacteristic:(nonnull CBCharacteristic *)characteristic
{
    if (characteristic.properties & CBCharacteristicPropertyWriteWithoutResponse) {
        [peripheral writeValue:data forCharacteristic:characteristic type:CBCharacteristicWriteWithoutResponse];
    }
}

// 订阅通知
- (void)hm_setNotifiy:(BOOL)isSetNotify{
    
    if (self.peripheral == nil) return;
    if (self.notifycharacteristic.properties & CBCharacteristicPropertyNotify ||  self.notifycharacteristic.properties & CBCharacteristicPropertyIndicate) {
        if (isSetNotify) {
            [self.peripheral setNotifyValue:YES forCharacteristic:self.notifycharacteristic];
            LZCLog(@"订阅了通知");
        }else{
            if(self.notifycharacteristic.isNotifying) { // 正在监听通知状态
                [self.peripheral setNotifyValue:NO forCharacteristic:self.notifycharacteristic];
                LZCLog(@"取消了通知");
            }
        }
    }
    else{
        LZCLog(@"这个characteristic没有nofity的权限");
    }
}

// 接收数据并处理
-(void)hm_receiveDataFromScale:(CBCharacteristic *)characteristics{
    
    if (characteristics.value == nil) return;
    
    // 0xF5 0x81 0x00 00 00 00 00 00 00 00 00 00 00 00 00 00 CRC
    // 0xF5 0x82 0x00 00 00 00 00 00 00 00 00 00 00 00 00 CRC
    // 0xF5 0x03 AA BB CC DD EE FF GG HH 00 00 00 00 00 CRC
    
    // 转换数据
    NSString *halfPeripheralDataS = [self hm_hexadecimalString:characteristics.value];
    
    // 包头:F5 第0位,长度为2
    NSString *bundleS = [halfPeripheralDataS substringWithRange:NSMakeRange(0, 2)];
    UInt64 bundle =  strtoul([bundleS UTF8String], 0, 16);// 16进制转10进制
    
    // 拼接数据 (由于硬件的问题，一条完整的数据采用两次传输，每次传输8位)
    if (bundle == 245 && halfPeripheralDataS.length == 16) {
        self.peripheralDataS = halfPeripheralDataS;
        return;
    }else
    {
        self.peripheralDataS = [self.peripheralDataS stringByAppendingString:halfPeripheralDataS];
        if (self.peripheralDataS.length != 32) return;
    }
    
    NSString *peripheralDataS = self.peripheralDataS;
    
    NSString *personalPrefix = [peripheralDataS substringWithRange:NSMakeRange(2, 2)];
    NSInteger prefix = [personalPrefix integerValue];
    
    NSString *resultS = [peripheralDataS substringWithRange:NSMakeRange(4, 2)];
    NSInteger result = [resultS integerValue];
    
    // 判断响应码
    switch (prefix) {
        case 81:
        {
            // 清除定时器
            if (self.timerToStopScanAndConnect) {
                [self.timerToStopScanAndConnect invalidate];
                self.timerToStopScanAndConnect = nil;
            }
            if (result == 0) {
				
                if ([self.delegate respondsToSelector:@selector(HMBLEDataHelper:statusInfo:)]) {
                    [self.delegate HMBLEDataHelper:self statusInfo: @{@"HmStatus" : @"12",@"info" : @"手机蓝牙已成功连接上外设"}];
                }
            }
			else if (result == 1) {
                [self hm_sendPersonalData];
            }
        }
            break;
        case 82:
        {
            if (result == 0) LZCLog(@"外设收到更改单位信息,校验成功");
            if (result == 1) LZCLog(@"外设收到更改单位信息,但校验不成功");
        }
            break;
        case 3:
        {
            [self hm_analysisPhysicalData:peripheralDataS];
        }
            break;
        case 4:
            LZCLog(@"收到外设用户上秤");
            break;
        case 6:
            LZCLog(@"收到外设用户下秤");
            break;
        default:
            break;
    }
    
}


// 接收的测量数据处理
- (void)hm_analysisPhysicalData:(NSString *)physicalDataS
{
    // 0xF5 0x03 AA BB CC DD EE FF GG HH 00 00 00 00 00 CRC

    // GG:状态 第16位,长度为2
    NSString *scaleStatus = [physicalDataS substringWithRange:NSMakeRange(16, 2)];
    UInt64 status =  strtoul([scaleStatus UTF8String], 0, 16);
    
    switch (status) {
        case 0: // 正在测量
            if ([self.delegate respondsToSelector:@selector(HMBLEDataHelper:statusInfo:)]) {
                [self.delegate HMBLEDataHelper:self statusInfo:@{@"HmStatus" : @"0",@"info" : @"正在测量体重..."}];
            }
            break;
        case 1: // 1.重量锁定,正在测脂
            if ([self.delegate respondsToSelector:@selector(HMBLEDataHelper:statusInfo:)]) {
                [self.delegate HMBLEDataHelper:self statusInfo:@{@"HmStatus" : @"1",@"info" : @"已锁定体重,正在测脂..."}];
            }
            break;
        case 2: // 测量完毕,未检测到脂肪
        case 3: // 测量完毕,检测到脂肪
        {
            // 解析外设测量数据
			
            if ([self.delegate respondsToSelector:@selector(HMBLEDataHelper:result:)]) {
				[self.delegate HMBLEDataHelper:self result:@{@"key" : @"value"}];
            }
        }
            break;
        default:
            break;
    }
    
}


// 发送已保存个人数据
- (void)hm_sendPersonalData
{
    self.userData = [self hm_getUserdata];
    [self hm_peripheral:self.peripheral didWriteData:self.userData forCharacteristic:self.writecharacteristic];
}

// 个人信息处理
- (NSData *)hm_getUserdata
{
    // 0xF5 0x01 AA BB CC DD EE FF 00 00 00 00 00 00 00 CRC
	
    NSString *userid = self.currentUserid;
    UInt64 id1 =  0;
    UInt64 id2 =  0;
    if (userid.length >= 2) {
        
        NSUInteger length = userid.length;
        userid = [userid substringFromIndex:length - 2]; // 截取两位作为用户id
        NSString *s01 = [userid substringToIndex:1];
        NSString *s02 = [userid substringFromIndex:1];
        s01 = [self hm_hexStringFromString:s01];
        s01 = [NSString stringWithFormat:@"0x%@",s01];
        
        s02 = [self hm_hexStringFromString:s02];
        s02 = [NSString stringWithFormat:@"0x%@",s02];
        
        id1 =  strtoul([s01 UTF8String], 0, 16);
        id2 =  strtoul([s02 UTF8String], 0, 16);
    }
    
    NSInteger height = self.userHeight;
    NSInteger sex = self.userSex;
    NSInteger age = self.userAge;
    NSInteger unit = self.currentUnit;
    
    Byte CRC = (245 + 1 + sex + age + height + id1 + id2 + unit) & 0x7F;
    Byte byte[] = {245,1,sex,age,height,id1,id2,unit,0,0,0,0,0,0,0,CRC};
    NSData *userData = [[NSData alloc] initWithBytes:byte length:16];
	
    
    return userData;
}

// 定时器
- (NSTimer *)hm_creatTimerToStopScanAndConnectScalePeripheral
{
    NSTimer *timerToScan = [NSTimer timerWithTimeInterval:15.0 target:self selector:@selector(hm_stopToScanAndConnectScale) userInfo:nil repeats:NO];
    [[NSRunLoop currentRunLoop] addTimer:timerToScan forMode:NSRunLoopCommonModes];
    return timerToScan;
}

- (void)hm_stopToScanAndConnectScale
{
    if (self.timerToStopScanAndConnect) self.timerToStopScanAndConnect = nil;
    
    [self hm_disconnect];
    if ([self.delegate respondsToSelector:@selector(HMBLEDataHelper:statusInfo:)]) {
        [self.delegate HMBLEDataHelper:self statusInfo:@{@"HmStatus" : @"14",@"info" : @"手机蓝牙扫描或连接外设超时"}];
    }
}


// NSData 转 NSString
- (NSString *)hm_hexadecimalString:(NSData *)data{
    NSString* result;
    const unsigned char* dataBuffer = (const unsigned char*)[data bytes];
    if(!dataBuffer) return nil;
    NSUInteger dataLength = [data length];
    NSMutableString* hexString = [NSMutableString stringWithCapacity:(dataLength * 2)];
    for(int i = 0; i < dataLength; i++){
        [hexString appendString:[NSString stringWithFormat:@"%02lx", (unsigned long)dataBuffer[i]]];
    }
    result = [NSString stringWithString:hexString];
    return result;
}

// 普通字符串转换为十六进制字符串
- (NSString *)hm_hexStringFromString:(NSString *)string{
    
    NSData *myD = [string dataUsingEncoding:NSUTF8StringEncoding];
    Byte *bytes = (Byte *)[myD bytes];
    NSString *hexStr=@"";
    for(int i=0;i<[myD length];i++)
    {
        NSString *newHexStr = [NSString stringWithFormat:@"%x",bytes[i]&0xff];
        if([newHexStr length]==1)
            hexStr = [NSString stringWithFormat:@"%@0%@",hexStr,newHexStr];
        else
            hexStr = [NSString stringWithFormat:@"%@%@",hexStr,newHexStr];
    }
    return hexStr;
}




#pragma mark - CBCentralManagerDelegate(中心管理者代理)

#pragma mark - 监听当前蓝牙状态
- (void)centralManagerDidUpdateState:(CBCentralManager *)central
{
    switch (central.state) {
        case CBCentralManagerStateUnknown:
            break;
        case CBCentralManagerStateResetting:
            break;
        case CBCentralManagerStateUnsupported:
            break;
        case CBCentralManagerStateUnauthorized:
            break;
        case CBCentralManagerStatePoweredOff:
        {
			if ([self.delegate respondsToSelector:@selector(HMBLEDataHelper:statusInfo:)]) {
                [self.delegate HMBLEDataHelper:self statusInfo:@{@"HmStatus" : @"11",@"info" : @"手机蓝牙已关闭"}];
			}
        }
            break;
        case CBCentralManagerStatePoweredOn:
        {
			if ([self.delegate respondsToSelector:@selector(HMBLEDataHelper:statusInfo:)]) {
                [self.delegate HMBLEDataHelper:self statusInfo:@{@"HmStatus" : @"10",@"info" : @"手机蓝牙已打开"}];
			}
			// 扫描外设
			[self hm_scanForPeripherals];
        }
            break;
        default:
            break;
    }
}


#pragma mark - 发现外设后调用的方法
- (void)centralManager:(CBCentralManager *)central // 中心管理者
 didDiscoverPeripheral:(CBPeripheral *)peripheral // 外设
     advertisementData:(NSDictionary *)advertisementData // 外设携带的数据
                  RSSI:(NSNumber *)RSSI // 外设发出的蓝牙信号强度
{
    if ([peripheral.name hasPrefix:@"HM"]) {
		
		[self hm_stopScanPeripheral];
		
		self.peripheral = peripheral;
		// 连接
		[self hm_connectPeripheral];
    }
}


#pragma mark - 中心管理者连接外设成功
- (void)centralManager:(CBCentralManager *)central // 中心管理者
  didConnectPeripheral:(CBPeripheral *)peripheral // 外设
{
	
    self.peripheral.delegate = self;
    [self.peripheral discoverServices:@[HLHServiceUUID]];// 传nil代表不过滤
}

#pragma mark - 中心管理者连接外设失败
- (void)centralManager:(CBCentralManager *)central didFailToConnectPeripheral:(CBPeripheral *)peripheral error:(NSError *)error
{
    LZCLog(@"外设%@=连接失败",peripheral.name);
}

#pragma mark - 中心管理者丢失外设连接
- (void)centralManager:(CBCentralManager *)central didDisconnectPeripheral:(CBPeripheral *)peripheral error:(NSError *)error
{
    LZCLog(@"外设%@=断开连接",peripheral.name);
    
    if (self.isManualDisconnect == NO)
    {
        [self hm_connectPeripheral];
    }
    self.manualDisconnect = NO;
}


#pragma mark - CBPeripheralDelegate(外设代理)

#pragma mark - 发现外设的服务后调用的方法
- (void)peripheral:(CBPeripheral *)peripheral didDiscoverServices:(NSError *)error
{
    if (error) {
        LZCLog(@"error = %@",error.localizedDescription);
        return;
    }
    
    for (CBService *service in peripheral.services) {
        if(![service.UUID isEqual:HLHServiceUUID]) continue;
        [peripheral discoverCharacteristics:@[HLHRWCharacteristicUUID,HLHRWNCharacteristicUUID] forService:service];
    }
}
#pragma mark - 发现外设服务里的特征的时候调用的代理方法
- (void)peripheral:(CBPeripheral *)peripheral didDiscoverCharacteristicsForService:(CBService *)service error:(NSError *)error
{
    LZCLog(@"发现指定外设服务里的特征");
    if (error) {
        LZCLog(@"外围设备寻找特征过程中发生错误，错误信息：%@",error.localizedDescription);
        return;
    }
    for (CBCharacteristic *characteristic in service.characteristics) {
        if (![characteristic.UUID isEqual:HLHRWCharacteristicUUID]) continue;
        
        self.writecharacteristic = characteristic;
		// 发送当前用户信息
		[self hm_sendPersonalData];
    }
    
    for (CBCharacteristic *characteristic in service.characteristics) {
        if (![characteristic.UUID isEqual:HLHRWNCharacteristicUUID]) continue;
        self.notifycharacteristic = characteristic;
        LZCLog(@"找到外设通知特征,订阅通知");
        [self hm_setNotifiy:YES];
    }
}


#pragma mark - 更新特征的value的时候会调用
- (void)peripheral:(CBPeripheral *)peripheral didUpdateValueForCharacteristic:(CBCharacteristic *)characteristic error:(NSError *)error
{
    LZCLog(@"更新特征的value");
    if (error) {
        LZCLog(@"更新特征的value的时候发生错误，错误信息：%@",error.localizedDescription);
    }
	if ([characteristic.UUID isEqual:HLHRWNCharacteristicUUID]) {
        if (characteristic.value.length) {
            // 解析
            [self hm_receiveDataFromScale:characteristic];
        }else{
            LZCLog(@"收到特征值更新,但特征值为空");
        }
    }
}


@end

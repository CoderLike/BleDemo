//
//  ViewController.m


#import "ViewController.h"

#import "HMBLEDataHelper.h"

@interface ViewController ()<UITableViewDataSource, UITableViewDelegate,HMBLEDataHelperDelegate>
@property (weak, nonatomic) IBOutlet UITableView *tableView;
/** statusDatas */
@property (nonatomic, strong) NSMutableArray *statusDatas;
/** result */
@property (nonatomic, strong) NSMutableArray *resultDatas;
/** 助手 */
@property (nonatomic, strong) HMBLEDataHelper *helper;

@end

@implementation ViewController

- (NSMutableArray *)statusDatas
{
	if (_statusDatas == nil) {
		_statusDatas = [[NSMutableArray alloc] init];
	}
	return _statusDatas;
}

- (NSMutableArray *)resultDatas
{
	if (_resultDatas == nil) {
		_resultDatas = [[NSMutableArray alloc] init];
	}
	return _resultDatas;
}

- (void)viewDidLoad {
	[super viewDidLoad];
	
}


- (IBAction)goToScaleBtnClick:(UIButton *)sender {
	
	if (self.statusDatas.count) {
		[self.statusDatas removeAllObjects];
	}
	if (self.resultDatas.count) {
		[self.resultDatas removeAllObjects];
	}
	
	// 初始化
	NSString *testuid = @"3040618136c8fdb80cea41fe9810ce93";
	NSInteger testAge = 27;
	CGFloat testHeight = 175.f;
	self.helper = [HMBLEDataHelper hm_scanAndConnectScaleWithUserid:testuid userSex:HmSexFemale userAge:testAge userHeight:testHeight currentUnit:HmScaleUnitHalfKilogram];
    // 代理
	self.helper.delegate = self;
	
}

- (IBAction)disconnectBtnClick:(UIButton *)sender {
	[self.helper hm_disconnect];
}



#pragma mark -HMBLEDataHelperDelegate
- (void)HMBLEDataHelper:(HMBLEDataHelper *_Nonnull)bleDataHelper result:(NSMutableDictionary *_Nonnull)result
{
	[self.resultDatas addObject:result];
	[self.tableView reloadData];
}

- (void)HMBLEDataHelper:(HMBLEDataHelper *)bleDataHelper statusInfo:(NSDictionary *)statusInfo
{
	[self.statusDatas addObject:statusInfo];
	[self.tableView reloadData];
}

#pragma mark - UITableViewDatasourc
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
	return 2;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
	if (section == 0) return self.statusDatas.count;
	NSDictionary *result = self.resultDatas.lastObject;
	return result.allKeys.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
	UITableViewCell *cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:@"cell"];
	
	if (indexPath.section == 0) {
		
		NSDictionary *statusInfo = self.statusDatas[indexPath.row];
		
		cell.textLabel.text = [NSString stringWithFormat:@"HmStatus : %@", statusInfo[@"HmStatus"]];
		cell.detailTextLabel.text = [NSString stringWithFormat:@"info : %@", statusInfo[@"info"]];
		return cell;
	}
	
	NSDictionary *result = self.resultDatas.lastObject;
	NSString *key = result.allKeys[indexPath.row];
	NSString *value = result[key];
	cell.textLabel.text = [NSString stringWithFormat:@"%@ : %@", key, value];
	
	return cell;
}


@end

/**
 * DouyinGhostMode - 抖音隐身模式插件
 *
 * 功能：
 * 1. 直播间隐身进场 - 进入直播间不显示进场通知
 * 2. 无痕浏览 - 访问他人主页不留记录
 *
 * 实现原理：
 * - 直播间隐身：Hook用户模型的secret/isSecret属性，返回YES
 *   抖音直播间会检查这些属性来决定是否显示进场特效
 * - 无痕浏览：Hook埋点SDK的事件上报方法，拦截访问主页相关事件
 *   直接return丢弃数据包，服务器不会收到访问记录
 *
 * Author: 喜爱民谣
 */

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import "Tweak.h"

// ==========================================
// 👻 直播间全局隐身模式
// ==========================================
//
// 实现原理：
// 抖音直播间有3层用户模型，都需要Hook才能完全隐身：
//
// 1. HTSLiveUser - 直播间内部真正使用的用户模型
//    这是直播间核心使用的类，控制进场特效和隐身状态
//    secret属性 = YES 表示用户处于隐身模式
//    displayEntranceEffect = NO 表示不显示进场动画
//
// 2. IESLiveUserModel - 外部通用直播用户模型
//    这是直播模块的通用用户模型，部分功能会读取这个类
//
// 3. AWEUserModel - 抖音基础用户模型
//    这是整个抖音App的基础用户模型，某些场景会检查此属性

%hook HTSLiveUser

- (BOOL)secret {
    if (DYGhostGetBool(kGhostLiveModeKey)) return YES;
    return %orig;
}

- (BOOL)isSecret {
    if (DYGhostGetBool(kGhostLiveModeKey)) return YES;
    return %orig;
}

- (BOOL)displayEntranceEffect {
    if (DYGhostGetBool(kGhostLiveModeKey)) return NO;
    return %orig;
}

%end


%hook IESLiveUserModel

- (BOOL)secret {
    if (DYGhostGetBool(kGhostLiveModeKey)) return YES;
    return %orig;
}

- (BOOL)isSecret {
    if (DYGhostGetBool(kGhostLiveModeKey)) return YES;
    return %orig;
}

- (BOOL)displayEntranceEffect {
    if (DYGhostGetBool(kGhostLiveModeKey)) return NO;
    return %orig;
}

%end


%hook AWEUserModel

- (BOOL)isSecret {
    if (DYGhostGetBool(kGhostLiveModeKey)) return YES;
    return %orig;
}

%end


// ==========================================
// 🥷 全局无痕浏览模式 (拦截字节跳动底层埋点 SDK)
// ==========================================
//
// 实现原理：
// 抖音使用埋点SDK来追踪用户行为，包括：
// - 访问他人主页
// - 增加主页浏览量
// - 视频播放记录
//
// 我们Hook埋点SDK的事件上报方法，拦截特定事件名称
// 直接return丢弃数据包，服务器不会收到这些记录
//
// 注意：只拦截访问相关事件，点赞/评论等正常事件放行
// 防止账号被风控

%hook BDTrackerProtocol

+ (void)eventV3:(NSString *)event params:(NSDictionary *)params {
    if (DYGhostGetBool(kGhostBrowseModeKey)) {
        NSArray *blockedEvents = @[
            @"enter_personal_detail",
            @"profile_pv",
            @"others_homepage",
            @"visit_profile",
            @"shoot_record_play"
        ];

        if ([blockedEvents containsObject:event]) {
            return;
        }
    }
    %orig;
}

%end

%hook Tracker

+ (void)event:(NSString *)event params:(NSDictionary *)params {
    if (DYGhostGetBool(kGhostBrowseModeKey)) {
        NSArray *blockedEvents = @[
            @"enter_personal_detail",
            @"profile_pv",
            @"others_homepage",
            @"visit_profile"
        ];
        if ([blockedEvents containsObject:event]) {
            return;
        }
    }
    %orig;
}

%end


// ==========================================
// ⚙️ 设置界面
// ==========================================

@interface DYGhostSettingsViewController : UIViewController
@end

@implementation DYGhostSettingsViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"隐身模式设置";
    self.view.backgroundColor = [UIColor systemBackgroundColor];

    UIScrollView *scrollView = [[UIScrollView alloc] initWithFrame:self.view.bounds];
    scrollView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [self.view addSubview:scrollView];

    CGFloat padding = 20;
    CGFloat yOffset = 60;
    CGFloat width = self.view.bounds.size.width - padding * 2;

    UILabel *titleLabel = [[UILabel alloc] initWithFrame:CGRectMake(padding, yOffset, width, 30)];
    titleLabel.text = @"👻 隐身模式";
    titleLabel.font = [UIFont boldSystemFontOfSize:22];
    [scrollView addSubview:titleLabel];
    yOffset += 45;

    UILabel *descLabel = [[UILabel alloc] initWithFrame:CGRectMake(padding, yOffset, width, 50)];
    descLabel.text = @"开启后访问他人主页和直播间将不留痕迹";
    descLabel.font = [UIFont systemFontOfSize:14];
    descLabel.textColor = [UIColor secondaryLabelColor];
    descLabel.numberOfLines = 0;
    [scrollView addSubview:descLabel];
    yOffset += 60;

    yOffset = [self addSwitchWithFrame:CGRectMake(padding, yOffset, width, 50)
                                  title:@"直播间隐身进场"
                               subtitle:@"进入直播间不显示进场通知和特效"
                                    key:kGhostLiveModeKey
                                yOffset:yOffset
                              scrollView:scrollView];

    yOffset = [self addSwitchWithFrame:CGRectMake(padding, yOffset + 15, width, 50)
                                  title:@"无痕浏览"
                               subtitle:@"访问他人主页不留记录，不增加浏览量"
                                    key:kGhostBrowseModeKey
                                yOffset:yOffset
                              scrollView:scrollView];

    yOffset += 80;
    UILabel *warnLabel = [[UILabel alloc] initWithFrame:CGRectMake(padding, yOffset, width, 80)];
    warnLabel.text = @"⚠️ 注意：无痕浏览仅拦截客户端埋点上报，\n服务端可能仍有部分记录。隐身模式不会\n影响点赞、评论等正常功能。";
    warnLabel.font = [UIFont systemFontOfSize:12];
    warnLabel.textColor = [UIColor tertiaryLabelColor];
    warnLabel.numberOfLines = 0;
    [scrollView addSubview:warnLabel];

    scrollView.contentSize = CGSizeMake(self.view.bounds.size.width, yOffset + 100);
}

- (CGFloat)addSwitchWithFrame:(CGRect)frame title:(NSString *)title subtitle:(NSString *)subtitle key:(NSString *)key yOffset:(CGFloat)yOffset scrollView:(UIScrollView *)scrollView {
    CGFloat padding = 20;
    CGFloat width = frame.size.width;

    UIView *container = [[UIView alloc] initWithFrame:CGRectMake(padding, yOffset, width, 50)];
    container.backgroundColor = [UIColor secondarySystemGroupedBackgroundColor];
    container.layer.cornerRadius = 12;
    [scrollView addSubview:container];

    UILabel *titleLabel = [[UILabel alloc] initWithFrame:CGRectMake(15, 5, width - 80, 22)];
    titleLabel.text = title;
    titleLabel.font = [UIFont boldSystemFontOfSize:16];
    [container addSubview:titleLabel];

    UILabel *subtitleLabel = [[UILabel alloc] initWithFrame:CGRectMake(15, 27, width - 80, 18)];
    subtitleLabel.text = subtitle;
    subtitleLabel.font = [UIFont systemFontOfSize:12];
    subtitleLabel.textColor = [UIColor secondaryLabelColor];
    [container addSubview:subtitleLabel];

    UISwitch *switchView = [[UISwitch alloc] initWithFrame:CGRectMake(width - 65, 10, 51, 31)];
    switchView.on = DYGhostGetBool(key);
    switchView.transform = CGAffineTransformMakeScale(0.85, 0.85);
    [switchView addTarget:self action:@selector(switchChanged:) forControlEvents:UIControlEventValueChanged];
    switchView.tag = [key hash];
    objc_setAssociatedObject(switchView, "key", key, OBJC_ASSOCIATION_COPY_NONATOMIC);
    [container addSubview:switchView];

    return yOffset + 50;
}

- (void)switchChanged:(UISwitch *)sender {
    NSString *key = objc_getAssociatedObject(sender, "key");
    if (key) {
        [[NSUserDefaults standardUserDefaults] setBool:sender.isOn forKey:key];
        [[NSUserDefaults standardUserDefaults] synchronize];
    }
}

@end


// ==========================================
// 🚪 入口：双指长按打开设置
// ==========================================

%hook UIWindow

- (instancetype)initWithFrame:(CGRect)frame {
    UIWindow *window = %orig;
    if (window) {
        UILongPressGestureRecognizer *gesture = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(dy_ghostLongPress:)];
        gesture.numberOfTouchesRequired = 2;
        gesture.minimumPressDuration = 1.0;
        [window addGestureRecognizer:gesture];
    }
    return window;
}

%new
- (void)dy_ghostLongPress:(UILongPressGestureRecognizer *)gesture {
    if (gesture.state == UIGestureRecognizerStateBegan) {
        UIViewController *rootVC = self.rootViewController;
        if (rootVC) {
            DYGhostSettingsViewController *settingsVC = [[DYGhostSettingsViewController alloc] init];
            if (@available(iOS 15.0, *)) {
                settingsVC.modalPresentationStyle = UIModalPresentationPageSheet;
            } else {
                settingsVC.modalPresentationStyle = UIModalPresentationFullScreen;
            }
            [rootVC presentViewController:settingsVC animated:YES completion:nil];
        }
    }
}

%end


%ctor {
    NSLog(@"[DouyinGhostMode] 插件已加载");
    NSLog(@"[DouyinGhostMode] 直播间隐身: %@", DYGhostGetBool(kGhostLiveModeKey) ? @"开启" : @"关闭");
    NSLog(@"[DouyinGhostMode] 无痕浏览: %@", DYGhostGetBool(kGhostBrowseModeKey) ? @"开启" : @"关闭");
}

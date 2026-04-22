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
// 🚪 入口：摇一摇打开设置
// ==========================================

%hook UIWindow

- (instancetype)initWithFrame:(CGRect)frame {
    UIWindow *window = %orig;
    if (window) {
        UIApplication *app = [UIApplication sharedApplication];
        [app setApplicationSupportsShakeToEdit:YES];
        [window becomeFirstResponder];
    }
    return window;
}

- (BOOL)canBecomeFirstResponder {
    return YES;
}

- (void)motionEnded:(UIEventSubtype)motion withEvent:(UIEvent *)event {
    %orig;
    if (motion == UIEventSubtypeMotionShake) {
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

#ifndef Tweak_h
#define Tweak_h

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

#pragma mark - 直播间用户模型

@interface HTSLiveUser : NSObject
@property (nonatomic) BOOL secret;
@property (nonatomic) BOOL isSecret;
@property (nonatomic) BOOL displayEntranceEffect;
@end

@interface IESLiveUserModel : NSObject
@property (nonatomic) BOOL secret;
@property (nonatomic) BOOL isSecret;
@property (nonatomic) BOOL displayEntranceEffect;
@end

@interface AWEUserModel : NSObject
@property (nonatomic) BOOL isSecret;
@end

#pragma mark - 埋点SDK

@interface BDTrackerProtocol : NSObject
+ (void)eventV3:(NSString *)event params:(NSDictionary *)params;
@end

@interface Tracker : NSObject
+ (void)event:(NSString *)event params:(NSDictionary *)params;
@end

#pragma mark - 设置开关Key

static NSString *const kGhostLiveModeKey = @"DYGhostLiveMode";
static NSString *const kGhostBrowseModeKey = @"DYGhostBrowseMode";

static inline BOOL DYGhostGetBool(NSString *key) {
    return [[NSUserDefaults standardUserDefaults] boolForKey:key];
}

static inline void DYGhostSetBool(NSString *key, BOOL value) {
    [[NSUserDefaults standardUserDefaults] setBool:value forKey:key];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

@interface DYGhostSettingsPresenter : NSObject
+ (void)showSettingsFrom:(UIViewController *)presenter;
@end

#endif

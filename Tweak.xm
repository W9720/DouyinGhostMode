#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <objc/runtime.h>

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

@interface BDTrackerProtocol : NSObject
+ (void)eventV3:(NSString *)event params:(NSDictionary *)params;
@end

@interface Tracker : NSObject
+ (void)event:(NSString *)event params:(NSDictionary *)params;
@end

// ==========================================
// Live Ghost Mode
// ==========================================

%hook HTSLiveUser

- (BOOL)secret {
    if ([[NSUserDefaults standardUserDefaults] boolForKey:@"DYYYLiveGhostMode"]) return YES;
    return %orig;
}

- (BOOL)isSecret {
    if ([[NSUserDefaults standardUserDefaults] boolForKey:@"DYYYLiveGhostMode"]) return YES;
    return %orig;
}

- (BOOL)displayEntranceEffect {
    if ([[NSUserDefaults standardUserDefaults] boolForKey:@"DYYYLiveGhostMode"]) return NO;
    return %orig;
}

%end

%hook IESLiveUserModel

- (BOOL)secret {
    if ([[NSUserDefaults standardUserDefaults] boolForKey:@"DYYYLiveGhostMode"]) return YES;
    return %orig;
}

- (BOOL)isSecret {
    if ([[NSUserDefaults standardUserDefaults] boolForKey:@"DYYYLiveGhostMode"]) return YES;
    return %orig;
}

- (BOOL)displayEntranceEffect {
    if ([[NSUserDefaults standardUserDefaults] boolForKey:@"DYYYLiveGhostMode"]) return NO;
    return %orig;
}

%end

%hook AWEUserModel

- (BOOL)isSecret {
    if ([[NSUserDefaults standardUserDefaults] boolForKey:@"DYYYLiveGhostMode"]) return YES;
    return %orig;
}

%end

// ==========================================
// Browse Ghost Mode
// ==========================================

%hook BDTrackerProtocol

+ (void)eventV3:(NSString *)event params:(NSDictionary *)params {
    if ([[NSUserDefaults standardUserDefaults] boolForKey:@"DYYYGhostMode"]) {
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
    if ([[NSUserDefaults standardUserDefaults] boolForKey:@"DYYYGhostMode"]) {
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
// Shake Gesture Settings
// ==========================================

static BOOL _dyGhostAlertShowing = NO;

@interface DYGhostSettingsPresenter : NSObject
+ (void)showSettingsFrom:(UIViewController *)presenter;
@end

@implementation DYGhostSettingsPresenter

+ (void)showSettingsFrom:(UIViewController *)presenter {
    if (!presenter || _dyGhostAlertShowing) return;
    _dyGhostAlertShowing = YES;

    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Ghost Mode"
                                                                   message:@"Toggle features below"
                                                            preferredStyle:UIAlertControllerStyleAlert];

    NSString *liveTitle = [[NSUserDefaults standardUserDefaults] boolForKey:@"DYYYLiveGhostMode"] ? @"[ON] Live Ghost Mode" : @"[OFF] Live Ghost Mode";
    UIAlertAction *liveAction = [UIAlertAction actionWithTitle:liveTitle
                                                         style:UIAlertActionStyleDefault
                                                       handler:^(UIAlertAction *action) {
        BOOL newVal = ![[NSUserDefaults standardUserDefaults] boolForKey:@"DYYYLiveGhostMode"];
        [[NSUserDefaults standardUserDefaults] setBool:newVal forKey:@"DYYYLiveGhostMode"];
        [[NSUserDefaults standardUserDefaults] synchronize];
        _dyGhostAlertShowing = NO;
    }];

    NSString *browseTitle = [[NSUserDefaults standardUserDefaults] boolForKey:@"DYYYGhostMode"] ? @"[ON] Browse Ghost Mode" : @"[OFF] Browse Ghost Mode";
    UIAlertAction *browseAction = [UIAlertAction actionWithTitle:browseTitle
                                                           style:UIAlertActionStyleDefault
                                                         handler:^(UIAlertAction *action) {
        BOOL newVal = ![[NSUserDefaults standardUserDefaults] boolForKey:@"DYYYGhostMode"];
        [[NSUserDefaults standardUserDefaults] setBool:newVal forKey:@"DYYYGhostMode"];
        [[NSUserDefaults standardUserDefaults] synchronize];
        _dyGhostAlertShowing = NO;
    }];

    UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:@"Cancel"
                                                           style:UIAlertActionStyleCancel
                                                         handler:^(UIAlertAction *action) {
        _dyGhostAlertShowing = NO;
    }];

    [alert addAction:liveAction];
    [alert addAction:browseAction];
    [alert addAction:cancelAction];

    [presenter presentViewController:alert animated:YES completion:nil];
}

@end

%hook UIWindow

- (instancetype)initWithFrame:(CGRect)frame {
    UIWindow *window = %orig;
    if (window) {
        [[UIApplication sharedApplication] setApplicationSupportsShakeToEdit:YES];
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
        while (rootVC.presentedViewController) {
            rootVC = rootVC.presentedViewController;
        }
        [DYGhostSettingsPresenter showSettingsFrom:rootVC];
    }
}

%end

%ctor {
    NSLog(@"[DouyinGhostMode] Plugin loaded");
    if (![[NSUserDefaults standardUserDefaults] objectForKey:@"DYYYLiveGhostMode"]) {
        [[NSUserDefaults standardUserDefaults] setBool:NO forKey:@"DYYYLiveGhostMode"];
    }
    if (![[NSUserDefaults standardUserDefaults] objectForKey:@"DYYYGhostMode"]) {
        [[NSUserDefaults standardUserDefaults] setBool:NO forKey:@"DYYYGhostMode"];
    }
    [[NSUserDefaults standardUserDefaults] synchronize];
}
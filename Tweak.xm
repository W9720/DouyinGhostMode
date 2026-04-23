%config(generator=MobileSubstrate)

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <objc/runtime.h>

static NSString *const kGhostLiveModeKey = @"DYYYLiveGhostMode";
static NSString *const kGhostBrowseModeKey = @"DYYYGhostMode";

static BOOL DYGhostGetBool(NSString *key) {
    return [[NSUserDefaults standardUserDefaults] boolForKey:key];
}

static void DYGhostSetBool(NSString *key, BOOL value) {
    [[NSUserDefaults standardUserDefaults] setBool:value forKey:key];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

#pragma mark - Live Ghost Mode

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

#pragma mark - Browse Ghost Mode

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

#pragma mark - Shake Gesture Settings

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

    NSString *liveTitle = DYGhostGetBool(kGhostLiveModeKey) ? @"[ON] Live Ghost Mode" : @"[OFF] Live Ghost Mode";
    UIAlertAction *liveAction = [UIAlertAction actionWithTitle:liveTitle
                                                         style:UIAlertActionStyleDefault
                                                       handler:^(UIAlertAction *action) {
        BOOL newVal = !DYGhostGetBool(kGhostLiveModeKey);
        DYGhostSetBool(kGhostLiveModeKey, newVal);
        _dyGhostAlertShowing = NO;
    }];

    NSString *browseTitle = DYGhostGetBool(kGhostBrowseModeKey) ? @"[ON] Browse Ghost Mode" : @"[OFF] Browse Ghost Mode";
    UIAlertAction *browseAction = [UIAlertAction actionWithTitle:browseTitle
                                                           style:UIAlertActionStyleDefault
                                                         handler:^(UIAlertAction *action) {
        BOOL newVal = !DYGhostGetBool(kGhostBrowseModeKey);
        DYGhostSetBool(kGhostBrowseModeKey, newVal);
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
    if (![[NSUserDefaults standardUserDefaults] objectForKey:kGhostLiveModeKey]) {
        [[NSUserDefaults standardUserDefaults] setBool:NO forKey:kGhostLiveModeKey];
    }
    if (![[NSUserDefaults standardUserDefaults] objectForKey:kGhostBrowseModeKey]) {
        [[NSUserDefaults standardUserDefaults] setBool:NO forKey:kGhostBrowseModeKey];
    }
    [[NSUserDefaults standardUserDefaults] synchronize];
}
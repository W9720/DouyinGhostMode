#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <objc/runtime.h>

@interface HTSLiveUser : NSObject
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

@interface BDTrackerIMPL : NSObject
+ (void)eventV3:(NSString *)event params:(NSDictionary *)params;
@end

@interface TTTracker : NSObject
+ (void)eventV3:(NSString *)event params:(NSDictionary *)params;
@end

@interface TTTrackerIMPL : NSObject
+ (void)eventV3:(NSString *)event params:(NSDictionary *)params;
@end

@interface BDTGTrackerKit : NSObject
+ (void)eventV3:(NSString *)event params:(NSDictionary *)params;
@end

@interface IESLCTrackerService : NSObject
+ (void)event:(NSString *)event params:(NSDictionary *)params;
@end

@interface BDECIMTracker : NSObject
+ (void)event:(NSString *)event params:(NSDictionary *)params;
@end

@interface BDPlatformSDKTracker : NSObject
+ (void)event:(NSString *)event params:(NSDictionary *)params;
@end

static BOOL DYGhostGetBool(NSString *key) {
    return [[NSUserDefaults standardUserDefaults] boolForKey:key];
}

static BOOL DYGhostShouldBlockEvent(NSString *event) {
    if (!event || !DYGhostGetBool(@"DYYYGhostMode")) return NO;
    NSArray *keywords = @[
        @"enter_personal_detail",
        @"profile_pv",
        @"others_homepage",
        @"visit_profile",
        @"shoot_record_play"
    ];
    for (NSString *k in keywords) {
        if ([event containsString:k]) return YES;
    }
    return NO;
}

// ==========================================
// Live Ghost Mode WITH LOGGING
// ==========================================

%hook HTSLiveUser

- (BOOL)secret {
    BOOL mode = DYGhostGetBool(@"DYYYLiveGhostMode");
    NSLog(@"[DouyinGhostMode] HTSLiveUser.secret CALLED, mode=%d", mode);
    if (mode) return YES;
    return %orig;
}

- (BOOL)isSecret {
    BOOL mode = DYGhostGetBool(@"DYYYLiveGhostMode");
    NSLog(@"[DouyinGhostMode] HTSLiveUser.isSecret CALLED, mode=%d", mode);
    if (mode) return YES;
    return %orig;
}

- (BOOL)displayEntranceEffect {
    BOOL mode = DYGhostGetBool(@"DYYYLiveGhostMode");
    NSLog(@"[DouyinGhostMode] HTSLiveUser.displayEntranceEffect CALLED, mode=%d", mode);
    if (mode) return NO;
    return %orig;
}

%end

%hook AWEUserModel

- (BOOL)isSecret {
    BOOL mode = DYGhostGetBool(@"DYYYLiveGhostMode");
    NSLog(@"[DouyinGhostMode] AWEUserModel.isSecret CALLED, mode=%d", mode);
    if (mode) return YES;
    return %orig;
}

%end

// ==========================================
// Browse Ghost Mode WITH LOGGING
// ==========================================

%hook BDTrackerProtocol
+ (void)eventV3:(NSString *)event params:(NSDictionary *)params {
    NSLog(@"[DouyinGhostMode] BDTrackerProtocol.eventV3 CALLED: %@", event);
    if (DYGhostShouldBlockEvent(event)) {
        NSLog(@"[DouyinGhostMode] BLOCKED event: %@", event);
        return;
    }
    %orig;
}
%end

%hook BDTrackerIMPL
+ (void)eventV3:(NSString *)event params:(NSDictionary *)params {
    NSLog(@"[DouyinGhostMode] BDTrackerIMPL.eventV3 CALLED: %@", event);
    if (DYGhostShouldBlockEvent(event)) {
        NSLog(@"[DouyinGhostMode] BLOCKED event: %@", event);
        return;
    }
    %orig;
}
%end

%hook TTTracker
+ (void)eventV3:(NSString *)event params:(NSDictionary *)params {
    NSLog(@"[DouyinGhostMode] TTTracker.eventV3 CALLED: %@", event);
    if (DYGhostShouldBlockEvent(event)) {
        NSLog(@"[DouyinGhostMode] BLOCKED event: %@", event);
        return;
    }
    %orig;
}
%end

%hook TTTrackerIMPL
+ (void)eventV3:(NSString *)event params:(NSDictionary *)params {
    NSLog(@"[DouyinGhostMode] TTTrackerIMPL.eventV3 CALLED: %@", event);
    if (DYGhostShouldBlockEvent(event)) {
        NSLog(@"[DouyinGhostMode] BLOCKED event: %@", event);
        return;
    }
    %orig;
}
%end

%hook BDTGTrackerKit
+ (void)eventV3:(NSString *)event params:(NSDictionary *)params {
    NSLog(@"[DouyinGhostMode] BDTGTrackerKit.eventV3 CALLED: %@", event);
    if (DYGhostShouldBlockEvent(event)) {
        NSLog(@"[DouyinGhostMode] BLOCKED event: %@", event);
        return;
    }
    %orig;
}
%end

%hook IESLCTrackerService
+ (void)event:(NSString *)event params:(NSDictionary *)params {
    NSLog(@"[DouyinGhostMode] IESLCTrackerService.event CALLED: %@", event);
    if (DYGhostShouldBlockEvent(event)) {
        NSLog(@"[DouyinGhostMode] BLOCKED event: %@", event);
        return;
    }
    %orig;
}
%end

%hook BDECIMTracker
+ (void)event:(NSString *)event params:(NSDictionary *)params {
    NSLog(@"[DouyinGhostMode] BDECIMTracker.event CALLED: %@", event);
    if (DYGhostShouldBlockEvent(event)) {
        NSLog(@"[DouyinGhostMode] BLOCKED event: %@", event);
        return;
    }
    %orig;
}
%end

%hook BDPlatformSDKTracker
+ (void)event:(NSString *)event params:(NSDictionary *)params {
    NSLog(@"[DouyinGhostMode] BDPlatformSDKTracker.event CALLED: %@", event);
    if (DYGhostShouldBlockEvent(event)) {
        NSLog(@"[DouyinGhostMode] BLOCKED event: %@", event);
        return;
    }
    %orig;
}
%end

// ==========================================
// Settings + Log Viewer
// ==========================================

static BOOL _dyGhostAlertShowing = NO;
static NSMutableArray *_dyGhostLogBuffer = nil;

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

    NSString *liveTitle = DYGhostGetBool(@"DYYYLiveGhostMode") ? @"[ON] Live Ghost" : @"[OFF] Live Ghost";
    UIAlertAction *liveAction = [UIAlertAction actionWithTitle:liveTitle
                                                         style:UIAlertActionStyleDefault
                                                       handler:^(UIAlertAction *action) {
        BOOL v = !DYGhostGetBool(@"DYYYLiveGhostMode");
        [[NSUserDefaults standardUserDefaults] setBool:v forKey:@"DYYYLiveGhostMode"];
        [[NSUserDefaults standardUserDefaults] synchronize];
        NSLog(@"[DouyinGhostMode] Live Ghost set to: %@", v ? @"ON" : @"OFF");
        _dyGhostAlertShowing = NO;
    }];

    NSString *browseTitle = DYGhostGetBool(@"DYYYGhostMode") ? @"[ON] Browse Ghost" : @"[OFF] Browse Ghost";
    UIAlertAction *browseAction = [UIAlertAction actionWithTitle:browseTitle
                                                           style:UIAlertActionStyleDefault
                                                         handler:^(UIAlertAction *action) {
        BOOL v = !DYGhostGetBool(@"DYYYGhostMode");
        [[NSUserDefaults standardUserDefaults] setBool:v forKey:@"DYYYGhostMode"];
        [[NSUserDefaults standardUserDefaults] synchronize];
        NSLog(@"[DouyinGhostMode] Browse Ghost set to: %@", v ? @"ON" : @"OFF");
        _dyGhostAlertShowing = NO;
    }];

    UIAlertAction *logAction = [UIAlertAction actionWithTitle:@"View Logs"
                                                        style:UIAlertActionStyleDefault
                                                      handler:^(UIAlertAction *action) {
        _dyGhostAlertShowing = NO;
        NSMutableString *logText = [NSMutableString string];
        if (_dyGhostLogBuffer && _dyGhostLogBuffer.count > 0) {
            for (NSString *line in [_dyGhostLogBuffer reverseObjectEnumerator]) {
                [logText appendFormat:@"%@\n", line];
            }
            if (_dyGhostLogBuffer.count > 50) [logText appendString:@"...(truncated)\n"];
        } else {
            [logText appendString:@"No logs captured yet.\n\nTry:\n1. Open a live room (for live ghost)\n2. Visit someone profile (for browse ghost)\n3. Then check logs again."];
        }
        UIViewController *vc = presenter; while(vc.presentedViewController) vc=vc.presentedViewController;
        UIAlertController *l=[UIAlertController alertControllerWithTitle:@"Hook Logs" message:logText preferredStyle:UIAlertControllerStyleAlert];
        [l addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleCancel handler:nil]];
        [vc presentViewController:l animated:YES completion:nil];
    }];

    UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:@"Cancel"
                                                           style:UIAlertActionStyleCancel
                                                         handler:^(UIAlertAction *action) { _dyGhostAlertShowing = NO; }];

    [alert addAction:liveAction];
    [alert addAction:browseAction];
    [alert addAction:logAction];
    [alert addAction:cancelAction];
    [presenter presentViewController:alert animated:YES completion:nil];
}

@end

%hook UIWindow
- (instancetype)initWithFrame:(CGRect)frame {
    UIWindow *w = %orig;
    if (w) [[UIApplication sharedApplication] setApplicationSupportsShakeToEdit:YES];
    return w;
}
- (BOOL)canBecomeFirstResponder { return YES; }
- (void)motionEnded:(UIEventSubtype)motion withEvent:(UIEvent *)event {
    %orig;
    if (motion == UIEventSubtypeMotionShake) {
        UIViewController *rootVC = self.rootViewController;
        while(rootVC.presentedViewController) rootVC=rootVC.presentedViewController;
        [DYGhostSettingsPresenter showSettingsFrom:rootVC];
    }
}
%end

// ==========================================
// Log Capture
// ==========================================

static void DYGhostLog(NSString *fmt, ...) {
    va_list args; va_start(args, fmt);
    NSString *msg = [[NSString alloc] initWithFormat:fmt arguments:args];
    va_end(args);
    if (!_dyGhostLogBuffer) _dyGhostLogBuffer = [NSMutableArray array];
    [_dyGhostLogBuffer addObject:[NSString stringWithFormat:@"%@", msg]];
    if (_dyGhostLogBuffer.count > 100) [_dyGhostLogBuffer removeObjectsInRange:NSMakeRange(0, 20)];
    NSLog(@"%@", msg);
}

%ctor {
    DYGhostLog(@"[DouyinGhostMode] Plugin loaded!");
    if (![[NSUserDefaults standardUserDefaults] objectForKey:@"DYYYLiveGhostMode"])
        [[NSUserDefaults standardUserDefaults] setBool:NO forKey:@"DYYYLiveGhostMode"];
    if (![[NSUserDefaults standardUserDefaults] objectForKey:@"DYYYGhostMode"])
        [[NSUserDefaults standardUserDefaults] setBool:NO forKey:@"DYYYGhostMode"];
    [[NSUserDefaults standardUserDefaults] synchronize];
}
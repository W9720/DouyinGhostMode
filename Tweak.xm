#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <objc/runtime.h>

@interface HTSLiveUser : NSObject
@property (nonatomic) BOOL secret;
@end

@interface AWEUserModel : NSObject
@property (nonatomic) BOOL isSecret;
@end

@interface BDTrackerProtocol : NSObject
@end

@interface TTTracker : NSObject
@end

@interface BDTGTrackerKit : NSObject
@end

@interface IESLCTrackerService : NSObject
@end

// ==========================================
// Live Ghost Mode - CORRECT METHOD SIGNATURES
// ==========================================

%hook HTSLiveUser

- (BOOL)secret {
    NSLog(@"[DouyinGhostMode] HIT: HTSLiveUser.secret");
    if ([[NSUserDefaults standardUserDefaults] boolForKey:@"DYYYLiveGhostMode"]) return YES;
    return %orig;
}

%end

%hook AWEUserModel

- (BOOL)isSecret {
    NSLog(@"[DouyinGhostMode] HIT: AWEUserModel.isSecret");
    if ([[NSUserDefaults standardUserDefaults] boolForKey:@"DYYYLiveGhostMode"]) return YES;
    return %orig;
}

%end

// ==========================================
// Browse Ghost Mode - CORRECT METHOD SIGNATURES
// ==========================================

%hook BDTrackerProtocol

+ (id)event:(id)arg1 category:(id)arg2 label:(id)arg3 value:(id)arg4 extValue:(id)arg5 eventType:(id)arg6 {
    NSString *labelStr = [arg3 isKindOfClass:[NSString class]] ? arg3 : @"";
    NSString *valueStr = [arg4 isKindOfClass:[NSString class]] ? arg4 : @"";
    NSString *eventName = labelStr.length > 0 ? labelStr : valueStr;

    if ([[NSUserDefaults standardUserDefaults] boolForKey:@"DYYYGhostMode"]) {
        NSArray *keywords = @[@"enter_personal_detail",@"profile_pv",@"others_homepage",@"visit_profile",@"shoot_record_play"];
        for (NSString *k in keywords) {
            if ([eventName containsString:k]) {
                NSLog(@"[DouyinGhostMode] BLOCKED BDTrackerProtocol event: %@", eventName);
                return nil;
            }
        }
    }
    return %orig;
}

+ (void)_event:(id)data eventIndex:(id)index {
    %orig;
}

%end

%hook TTTracker

+ (id)event:(id)arg1 category:(id)arg2 label:(id)arg3 value:(id)arg4 extValue:(id)arg5 eventType:(id)arg6 {
    NSString *labelStr = [arg3 isKindOfClass:[NSString class]] ? arg3 : @"";
    NSString *valueStr = [arg4 isKindOfClass:[NSString class]] ? arg4 : @"";
    NSString *eventName = labelStr.length > 0 ? labelStr : valueStr;

    if ([[NSUserDefaults standardUserDefaults] boolForKey:@"DYYYGhostMode"]) {
        NSArray *keywords = @[@"enter_personal_detail",@"profile_pv",@"others_homepage",@"visit_profile",@"shoot_record_play"];
        for (NSString *k in keywords) {
            if ([eventName containsString:k]) {
                NSLog(@"[DouyinGhostMode] BLOCKED TTTracker event: %@", eventName);
                return nil;
            }
        }
    }
    return %orig;
}

+ (void)_event:(id)data eventIndex:(id)index {
    %orig;
}

%end

%hook BDTGTrackerKit

+ (id)event:(id)arg1 category:(id)arg2 label:(id)arg3 value:(id)arg4 extValue:(id)arg5 eventType:(id)arg6 {
    NSString *labelStr = [arg3 isKindOfClass:[NSString class]] ? arg3 : @"";
    NSString *valueStr = [arg4 isKindOfClass:[NSString class]] ? arg4 : @"";
    NSString *eventName = labelStr.length > 0 ? labelStr : valueStr;

    if ([[NSUserDefaults standardUserDefaults] boolForKey:@"DYYYGhostMode"]) {
        NSArray *keywords = @[@"enter_personal_detail",@"profile_pv",@"others_homepage",@"visit_profile",@"shoot_record_play"];
        for (NSString *k in keywords) {
            if ([eventName containsString:k]) {
                NSLog(@"[DouyinGhostMode] BLOCKED BDTGTrackerKit event: %@", eventName);
                return nil;
            }
        }
    }
    return %orig;
}

%end

%hook IESLCTrackerService

+ (id)event:(id)arg1 category:(id)arg2 label:(id)arg3 value:(id)arg4 extValue:(id)arg5 eventType:(id)arg6 {
    NSString *labelStr = [arg3 isKindOfClass:[NSString class]] ? arg3 : @"";
    NSString *valueStr = [arg4 isKindOfClass:[NSString class]] ? arg4 : @"";
    NSString *eventName = labelStr.length > 0 ? labelStr : valueStr;

    if ([[NSUserDefaults standardUserDefaults] boolForKey:@"DYYYGhostMode"]) {
        NSArray *keywords = @[@"enter_personal_detail",@"profile_pv",@"others_homepage",@"visit_profile",@"shoot_record_play"];
        for (NSString *k in keywords) {
            if ([eventName containsString:k]) {
                NSLog(@"[DouyinGhostMode] BLOCKED IESLCTrackerService event: %@", eventName);
                return nil;
            }
        }
    }
    return %orig;
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
                                                                   message:@"Toggle below"
                                                            preferredStyle:UIAlertControllerStyleAlert];

    NSString *liveTitle = [[NSUserDefaults standardUserDefaults] boolForKey:@"DYYYLiveGhostMode"] ? @"[ON] Live Ghost" : @"[OFF] Live Ghost";
    UIAlertAction *liveAction = [UIAlertAction actionWithTitle:liveTitle style:UIAlertActionStyleDefault handler:^(UIAlertAction *a) {
        BOOL v = ![[NSUserDefaults standardUserDefaults] boolForKey:@"DYYYLiveGhostMode"];
        [[NSUserDefaults standardUserDefaults] setBool:v forKey:@"DYYYLiveGhostMode"];
        [[NSUserDefaults standardUserDefaults] synchronize];
        _dyGhostAlertShowing = NO;
    }];

    NSString *browseTitle = [[NSUserDefaults standardUserDefaults] boolForKey:@"DYYYGhostMode"] ? @"[ON] Browse Ghost" : @"[OFF] Browse Ghost";
    UIAlertAction *browseAction = [UIAlertAction actionWithTitle:browseTitle style:UIAlertActionStyleDefault handler:^(UIAlertAction *a) {
        BOOL v = ![[NSUserDefaults standardUserDefaults] boolForKey:@"DYYYGhostMode"];
        [[NSUserDefaults standardUserDefaults] setBool:v forKey:@"DYYYGhostMode"];
        [[NSUserDefaults standardUserDefaults] synchronize];
        _dyGhostAlertShowing = NO;
    }];

    UIAlertAction *logAction = [UIAlertAction actionWithTitle:@"View Logs" style:UIAlertActionStyleDefault handler:^(UIAlertAction *a) {
        _dyGhostAlertShowing = NO;
        NSMutableString *logText = [NSMutableString string];
        if (_dyGhostLogBuffer && _dyGhostLogBuffer.count > 0) {
            for (NSString *line in [_dyGhostLogBuffer reverseObjectEnumerator]) { [logText appendFormat:@"%@\n", line]; }
        } else {
            [logText appendString:@"No logs yet.\n\n1. Turn ON both modes\n2. Enter live room or visit profile\n3. Check logs again"];
        }
        UIViewController *vc = presenter; while(vc.presentedViewController) vc=vc.presentedViewController;
        UIAlertController *l=[UIAlertController alertControllerWithTitle:@"Hook Logs" message:logText preferredStyle:UIAlertControllerStyleAlert];
        [l addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleCancel handler:nil]];
        [vc presentViewController:l animated:YES completion:nil];
    }];

    [alert addAction:liveAction]; [alert addAction:browseAction]; [alert addAction:logAction];
    [alert addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:^(UIAlertAction *a){_dyGhostAlertShowing=NO;}]];
    [presenter presentViewController:alert animated:YES completion:nil];
}

@end

%hook UIWindow
- (instancetype)initWithFrame:(CGRect)frame {
    UIWindow *w = %orig; if (w) [[UIApplication sharedApplication] setApplicationSupportsShakeToEdit:YES]; return w;
}
- (BOOL)canBecomeFirstResponder { return YES; }
- (void)motionEnded:(UIEventSubtype)motion withEvent:(UIEvent *)event {
    %orig; if (motion == UIEventSubtypeMotionShake) {
        UIViewController *rootVC = self.rootViewController; while(rootVC.presentedViewController) rootVC=rootVC.presentedViewController;
        [DYGhostSettingsPresenter showSettingsFrom:rootVC];
    }
}
%end

static void DYGhostLog(NSString *fmt, ...) {
    va_list args; va_start(args, fmt); NSString *msg = [[NSString alloc] initWithFormat:fmt arguments:args]; va_end(args);
    if (!_dyGhostLogBuffer) _dyGhostLogBuffer = [NSMutableArray array];
    [_dyGhostLogBuffer addObject:msg]; if (_dyGhostLogBuffer.count > 100) [_dyGhostLogBuffer removeObjectsInRange:NSMakeRange(0,20)];
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
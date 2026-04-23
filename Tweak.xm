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
    NSArray *keywords = @[@"enter_personal_detail",@"profile_pv",@"others_homepage",@"visit_profile",@"shoot_record_play"];
    for (NSString *k in keywords) { if ([event containsString:k]) return YES; }
    return NO;
}

// ==========================================
// Live Ghost Mode WITH LOGGING
// ==========================================

%hook HTSLiveUser
- (BOOL)secret {
    NSLog(@"[DouyinGhostMode] HIT: HTSLiveUser.secret");
    if (DYGhostGetBool(@"DYYYLiveGhostMode")) return YES;
    return %orig;
}
- (BOOL)isSecret {
    NSLog(@"[DouyinGhostMode] HIT: HTSLiveUser.isSecret");
    if (DYGhostGetBool(@"DYYYLiveGhostMode")) return YES;
    return %orig;
}
- (BOOL)displayEntranceEffect {
    NSLog(@"[DouyinGhostMode] HIT: HTSLiveUser.displayEntranceEffect");
    if (DYGhostGetBool(@"DYYYLiveGhostMode")) return NO;
    return %orig;
}
%end

%hook AWEUserModel
- (BOOL)isSecret {
    NSLog(@"[DouyinGhostMode] HIT: AWEUserModel.isSecret");
    if (DYGhostGetBool(@"DYYYLiveGhostMode")) return YES;
    return %orig;
}
%end

// ==========================================
// Browse Ghost Mode WITH LOGGING
// ==========================================

%hook BDTrackerProtocol
+ (void)eventV3:(NSString *)event params:(NSDictionary *)params {
    NSLog(@"[DouyinGhostMode] HIT: BDTrackerProtocol.eventV3 = %@", event);
    if (DYGhostShouldBlockEvent(event)) { NSLog(@"[DouyinGhostMode] BLOCKED!"); return; }
    %orig;
}
%end

%hook BDTrackerIMPL
+ (void)eventV3:(NSString *)event params:(NSDictionary *)params {
    NSLog(@"[DouyinGhostMode] HIT: BDTrackerIMPL.eventV3 = %@", event);
    if (DYGhostShouldBlockEvent(event)) { NSLog(@"[DouyinGhostMode] BLOCKED!"); return; }
    %orig;
}
%end

%hook TTTracker
+ (void)eventV3:(NSString *)event params:(NSDictionary *)params {
    NSLog(@"[DouyinGhostMode] HIT: TTTracker.eventV3 = %@", event);
    if (DYGhostShouldBlockEvent(event)) { NSLog(@"[DouyinGhostMode] BLOCKED!"); return; }
    %orig;
}
%end

%hook TTTrackerIMPL
+ (void)eventV3:(NSString *)event params:(NSDictionary *)params {
    NSLog(@"[DouyinGhostMode] HIT: TTTrackerIMPL.eventV3 = %@", event);
    if (DYGhostShouldBlockEvent(event)) { NSLog(@"[DouyinGhostMode] BLOCKED!"); return; }
    %orig;
}
%end

%hook BDTGTrackerKit
+ (void)eventV3:(NSString *)event params:(NSDictionary *)params {
    NSLog(@"[DouyinGhostMode] HIT: BDTGTrackerKit.eventV3 = %@", event);
    if (DYGhostShouldBlockEvent(event)) { NSLog(@"[DouyinGhostMode] BLOCKED!"); return; }
    %orig;
}
%end

%hook IESLCTrackerService
+ (void)event:(NSString *)event params:(NSDictionary *)params {
    NSLog(@"[DouyinGhostMode] HIT: IESLCTrackerService.event = %@", event);
    if (DYGhostShouldBlockEvent(event)) { NSLog(@"[DouyinGhostMode] BLOCKED!"); return; }
    %orig;
}
%end

%hook BDECIMTracker
+ (void)event:(NSString *)event params:(NSDictionary *)params {
    NSLog(@"[DouyinGhostMode] HIT: BDECIMTracker.event = %@", event);
    if (DYGhostShouldBlockEvent(event)) { NSLog(@"[DouyinGhostMode] BLOCKED!"); return; }
    %orig;
}
%end

%hook BDPlatformSDKTracker
+ (void)event:(NSString *)event params:(NSDictionary *)params {
    NSLog(@"[DouyinGhostMode] HIT: BDPlatformSDKTracker.event = %@", event);
    if (DYGhostShouldBlockEvent(event)) { NSLog(@"[DouyinGhostMode] BLOCKED!"); return; }
    %orig;
}
%end

// ==========================================
// Settings + Deep Method Diagnostics
// ==========================================

static BOOL _dyGhostAlertShowing = NO;

static NSString *DYGhostDeepScan(void) {
    NSMutableString *r = [NSMutableString string];

    NSArray *targets = @[
        @{@"cls":@"HTSLiveUser", @"sel":@"secret", @"type":@"instance"},
        @{@"cls":@"HTSLiveUser", @"sel":@"isSecret", @"type":@"instance"},
        @{@"cls":@"HTSLiveUser", @"sel":@"displayEntranceEffect", @"type":@"instance"},
        @{@"cls":@"AWEUserModel", @"sel":@"isSecret", @"type":@"instance"},
        @{@"cls":@"BDTrackerProtocol", @"sel":@"eventV3:", @"type":@"class"},
        @{@"cls":@"BDTrackerIMPL", @"sel":@"eventV3:", @"type":@"class"},
        @{@"cls":@"TTTracker", @"sel":@"eventV3:", @"type":@"class"},
        @{@"cls":@"TTTrackerIMPL", @"sel":@"eventV3:", @"type":@"class"},
        @{@"cls":@"BDTGTrackerKit", @"sel":@"eventV3:", @"type":@"class"},
        @{@"cls":@"IESLCTrackerService", @"sel":@"event:", @"type":@"class"},
        @{@"cls":@"BDECIMTracker", @"sel":@"event:", @"type":@"class"},
        @{@"cls":@"BDPlatformSDKTracker", @"sel":@"event:", @"type":@"class"}
    ];

    [r appendString:@"=== METHOD EXISTENCE CHECK ===\n"];
    for (NSDictionary *t in targets) {
        NSString *clsName = t[@"cls"];
        NSString *selName = t[@"sel"];
        NSString *type = t[@"type"];
        Class cls = NSClassFromString(clsName);
        SEL sel = NSSelectorFromString(selName);

        if (!cls) {
            [r appendFormat:@"CLASS MISSING: %@\n", clsName];
            continue;
        }

        Method m = nil;
        if ([type isEqualToString:@"class"]) {
            m = class_getClassMethod(cls, sel);
            [r appendFormat:@"%@ +[%@ %@]: %@\n",
                clsName, clsName, selName, m ? @"EXISTS" : @"MISSING"];
        } else {
            m = class_getInstanceMethod(cls, sel);
            [r appendFormat:@"%@ -[%@ %@]: %@\n",
                clsName, clsName, selName, m ? @"EXISTS" : @"MISSING"];
        }
    }

    [r appendString:@"\n=== ALL METHODS ON HTSLiveUser ===\n"];
    Class htsCls = NSClassFromString(@"HTSLiveUser");
    if (htsCls) {
        unsigned int mc = 0;
        Method *ms = class_copyMethodList(htsCls, &mc);
        for (unsigned int i = 0; i < mc && i < 30; i++) {
            [r appendFormat:@"  -%@ (%d args)\n",
                NSStringFromSelector(method_getName(ms[i])),
                method_getNumberOfArguments(ms[i]) - 2];
        }
        free(ms);
        if (mc > 30) [r appendFormat:@"  ... +%d total\n", mc - 30];
    }

    [r appendString:@"\n=== ALL METHODS ON BDTrackerProtocol ===\n"];
    Class bdtCls = NSClassFromString(@"BDTrackerProtocol");
    if (bdtCls) {
        unsigned int mc = 0;
        Method *ms = class_copyMethodList(bdtCls, &mc);
        for (unsigned int i = 0; i < mc && i < 20; i++) {
            [r appendFormat:@"  +%@ (%d args)\n",
                NSStringFromSelector(method_getName(ms[i])),
                method_getNumberOfArguments(ms[i]) - 2];
        }
        free(ms);
        if (mc > 20) [r appendFormat:@"  ... +%d total\n", mc - 20];
    }

    [r appendString:@"\n=== ALL METHODS ON TTTracker ===\n"];
    Class ttCls = NSClassFromString(@"TTTracker");
    if (ttCls) {
        unsigned int mc = 0;
        Method *ms = class_copyMethodList(ttCls, &mc);
        for (unsigned int i = 0; i < mc && i < 20; i++) {
            [r appendFormat:@"  +%@ (%d args)\n",
                NSStringFromSelector(method_getName(ms[i])),
                method_getNumberOfArguments(ms[i]) - 2];
        }
        free(ms);
        if (mc > 20) [r appendFormat:@"  ... +%d total\n", mc - 20];
    }

    return r;
}

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

    NSString *liveTitle = DYGhostGetBool(@"DYYYLiveGhostMode") ? @"[ON] Live Ghost" : @"[OFF] Live Ghost";
    UIAlertAction *liveAction = [UIAlertAction actionWithTitle:liveTitle style:UIAlertActionStyleDefault handler:^(UIAlertAction *a) {
        [[NSUserDefaults standardUserDefaults] setBool:!DYGhostGetBool(@"DYYYLiveGhostMode") forKey:@"DYYYLiveGhostMode"];
        [[NSUserDefaults standardUserDefaults] synchronize]; _dyGhostAlertShowing = NO;
    }];

    NSString *browseTitle = DYGhostGetBool(@"DYYYGhostMode") ? @"[ON] Browse Ghost" : @"[OFF] Browse Ghost";
    UIAlertAction *browseAction = [UIAlertAction actionWithTitle:browseTitle style:UIAlertActionStyleDefault handler:^(UIAlertAction *a) {
        [[NSUserDefaults standardUserDefaults] setBool:!DYGhostGetBool(@"DYYYGhostMode") forKey:@"DYYYGhostMode"];
        [[NSUserDefaults standardUserDefaults] synchronize]; _dyGhostAlertShowing = NO;
    }];

    UIAlertAction *deepAction = [UIAlertAction actionWithTitle:@"Deep Scan Methods" style:UIAlertActionStyleDefault handler:^(UIAlertAction *a) {
        _dyGhostAlertShowing = NO;
        NSString *result = DYGhostDeepScan();
        UIViewController *vc = presenter; while(vc.presentedViewController) vc=vc.presentedViewController;
        UIAlertController *d=[UIAlertController alertControllerWithTitle:@"Method Scan" message:result preferredStyle:UIAlertControllerStyleAlert];
        [d addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleCancel handler:nil]];
        [vc presentViewController:d animated:YES completion:nil];
    }];

    [alert addAction:liveAction];
    [alert addAction:browseAction];
    [alert addAction:deepAction];
    [alert addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:^(UIAlertAction *a){_dyGhostAlertShowing=NO;}]];
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

%ctor {
    NSLog(@"[DouyinGhostMode] Plugin loaded!");
    if (![[NSUserDefaults standardUserDefaults] objectForKey:@"DYYYLiveGhostMode"])
        [[NSUserDefaults standardUserDefaults] setBool:NO forKey:@"DYYYLiveGhostMode"];
    if (![[NSUserDefaults standardUserDefaults] objectForKey:@"DYYYGhostMode"])
        [[NSUserDefaults standardUserDefaults] setBool:NO forKey:@"DYYYGhostMode"];
    [[NSUserDefaults standardUserDefaults] synchronize];
}
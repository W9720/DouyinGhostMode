%config(generator=MobileSubstrate)

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <objc/runtime.h>

static NSString *const kGhostLiveModeKey = @"DYYYLiveGhostMode";
static NSString *const kGhostBrowseModeKey = @"DYYYGhostMode";

static BOOL DYGhostGetBool(NSString *key) {
    return [[NSUserDefaults standardUserDefaults] boolForKey:key];
}

static NSMutableArray *_dyGhostLogBuffer = nil;

static void DYGhostLog(NSString *msg) {
    NSLog(@"%@", msg);
    if (!_dyGhostLogBuffer) _dyGhostLogBuffer = [NSMutableArray array];
    [_dyGhostLogBuffer addObject:msg];
    if (_dyGhostLogBuffer.count > 100) [_dyGhostLogBuffer removeObjectsInRange:NSMakeRange(0,20)];
}

// ==========================================
// Live Ghost Mode
// ==========================================

static IMP _orig_hts_secret = NULL;
static BOOL dy_hts_secret(id self, SEL _cmd) {
    if (DYGhostGetBool(kGhostLiveModeKey)) return YES;
    return ((BOOL(*)(id,SEL))_orig_hts_secret)(self,_cmd);
}

// ==========================================
// Browse Ghost Mode - typed hooks for common arg counts
// ==========================================

static NSArray *_blockedKeywords = nil;

static BOOL DYGhostIsBlocked(NSString *s) {
    if (!DYGhostGetBool(kGhostBrowseModeKey) || !s) return NO;
    if (!_blockedKeywords) _blockedKeywords = @[@"enter_personal_detail",@"profile_pv",@"others_homepage",@"visit_profile",@"shoot_record_play"];
    for (NSString *k in _blockedKeywords) { if ([s containsString:k]) return YES; }
    return NO;
}

// 4 real args (total 6 with self+_cmd): event:a:b:c:
static IMP _orig_e4 = NULL;
static id dy_hook_e4(id self, SEL _cmd, id a, id b, id c, id d) {
    NSString *info = ([b isKindOfClass:[NSString class]] ? b : ([c isKindOfClass:[NSString class]] ? c : @""));
    if (DYGhostIsBlocked(info)) { DYGhostLog([NSString stringWithFormat:@"BLOCKED(e4): %@", info]); return nil; }
    return ((id(*)(id,SEL,id,id,id,id))_orig_e4)(self,_cmd,a,b,c,d);
}

// 5 real args (total 7 with self+_cmd): event:a:b:c:d:
static IMP _orig_e5 = NULL;
static id dy_hook_e5(id self, SEL _cmd, id a, id b, id c, id d, id e) {
    NSString *info = ([c isKindOfClass:[NSString class]] ? c : ([d isKindOfClass:[NSString class]] ? d : @""));
    if (DYGhostIsBlocked(info)) { DYGhostLog([NSString stringWithFormat:@"BLOCKED(e5): %@", info]); return nil; }
    return ((id(*)(id,SEL,id,id,id,id,id))_orig_e5)(self,_cmd,a,b,c,d,e);
}

// 6 real args (total 8 with self+_cmd): event:a:b:c:d:e:
static IMP _orig_e6 = NULL;
static id dy_hook_e6(id self, SEL _cmd, id a, id b, id c, id d, id e, id f) {
    NSString *info = ([c isKindOfClass:[NSString class]] ? c : ([d isKindOfClass:[NSString class]] ? d : @""));
    if (DYGhostIsBlocked(info)) { DYGhostLog([NSString stringWithFormat:@"BLOCKED(e6): %@", info]); return nil; }
    return ((id(*)(id,SEL,id,id,id,id,id,id))_orig_e6)(self,_cmd,a,b,c,d,e,f);
}

// 7 real args (total 9 with self+_cmd): event:a:b:c:d:e:f:
static IMP _orig_e7 = NULL;
static id dy_hook_e7(id self, SEL _cmd, id a, id b, id c, id d, id e, id f, id g) {
    NSString *info = ([c isKindOfClass:[NSString class]] ? c : ([d isKindOfClass:[NSString class]] ? d : @""));
    if (DYGhostIsBlocked(info)) { DYGhostLog([NSString stringWithFormat:@"BLOCKED(e7): %@", info]); return nil; }
    return ((id(*)(id,SEL,id,id,id,id,id,id,id))_orig_e7)(self,_cmd,a,b,c,d,e,f,g);
}

// ==========================================
// Install hooks - find REAL method signatures at runtime
// ==========================================

static void DYGhostInstallHooks(void) {
    DYGhostLog(@"Installing hooks...");

    // Live Ghost
    Class htsCls = NSClassFromString(@"HTSLiveUser");
    if (htsCls) {
        Method m = class_getInstanceMethod(htsCls, @selector(secret));
        if (m) { _orig_hts_secret = method_setImplementation(m, (IMP)dy_hts_secret); DYGhostLog(@"HOOKED: HTSLiveUser.secret"); }
    }

    // Browse Ghost - scan each tracker class for event methods
    NSArray *trackerClasses = @[@"BDTrackerProtocol", @"TTTracker", @"BDTGTrackerKit",
        @"IESLCTrackerService", @"BDTrackerIMPL", @"TTTrackerIMPL",
        @"BDECIMTracker", @"BDPlatformSDKTracker"];

    for (NSString *clsName in trackerClasses) {
        Class tc = NSClassFromString(clsName);
        if (!tc) continue;

        unsigned int mc = 0;
        Method *methods = class_copyMethodList(tc, &mc);
        if (!methods) continue;

        for (unsigned int i = 0; i < mc; i++) {
            SEL sel = method_getName(methods[i]);
            NSString *selName = NSStringFromSelector(sel);

            // Only hook methods with "event" in name
            if (![selName containsString:@"event"]) continue;

            char *retType = method_copyReturnType(methods[i]);
            BOOL isVoid = (retType[0] == 'v');
            free(retType);
            if (isVoid) continue; // skip void methods

            NSUInteger argCount = method_getNumberOfArguments(methods[i]);
            NSUInteger realArgs = argCount - 2; // minus self + _cmd

            IMP newImp = NULL;
            IMP *origSlot = NULL;
            const char *tag = "";

            // Select right hook function by arg count
            if (realArgs == 4) { newImp = (IMP)dy_hook_e4; origSlot = &_orig_e4; tag = "e4"; }
            else if (realArgs == 5) { newImp = (IMP)dy_hook_e5; origSlot = &_orig_e5; tag = "e5"; }
            else if (realArgs == 6) { newImp = (IMP)dy_hook_e6; origSlot = &_orig_e6; tag = "e6"; }
            else if (realArgs == 7) { newImp = (IMP)dy_hook_e7; origSlot = &_orig_e7; tag = "e7"; }
            else {
                DYGhostLog([NSString stringWithFormat:@"SKIP: [%@ %@] (%lu args) unsupported", clsName, selName, (unsigned long)realArgs]);
                continue;
            }

            IMP orig = method_setImplementation(methods[i], newImp);
            if (origSlot && !*origSlot) *origSlot = orig; // save first one for each type
            DYGhostLog([NSString stringWithFormat:@"HOOKED(%s): [%@ %@] %luargs", tag, clsName, selName, (unsigned long)realArgs]);
        }
        free(methods);
    }

    DYGhostLog(@"Done!");
}

// ==========================================
// Settings UI
// ==========================================

static BOOL _dyGhostAlertShowing = NO;

@interface DYGhostSettingsPresenter : NSObject
+ (void)showSettingsFrom:(UIViewController *)presenter;
@end

@implementation DYGhostSettingsPresenter

+ (void)showSettingsFrom:(UIViewController *)presenter {
    if (!presenter || _dyGhostAlertShowing) return;
    _dyGhostAlertShowing = YES;

    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Ghost Mode" message:@"Toggle below" preferredStyle:UIAlertControllerStyleAlert];

    NSString *liveTitle = DYGhostGetBool(kGhostLiveModeKey) ? @"[ON] Live Ghost" : @"[OFF] Live Ghost";
    UIAlertAction *liveAction = [UIAlertAction actionWithTitle:liveTitle style:UIAlertActionStyleDefault handler:^(UIAlertAction *a) {
        [[NSUserDefaults standardUserDefaults] setBool:!DYGhostGetBool(kGhostLiveModeKey) forKey:kGhostLiveModeKey];
        [[NSUserDefaults standardUserDefaults] synchronize]; _dyGhostAlertShowing = NO;
    }];

    NSString *browseTitle = DYGhostGetBool(kGhostBrowseModeKey) ? @"[ON] Browse Ghost" : @"[OFF] Browse Ghost";
    UIAlertAction *browseAction = [UIAlertAction actionWithTitle:browseTitle style:UIAlertActionStyleDefault handler:^(UIAlertAction *a) {
        [[NSUserDefaults standardUserDefaults] setBool:!DYGhostGetBool(kGhostBrowseModeKey) forKey:kGhostBrowseModeKey];
        [[NSUserDefaults standardUserDefaults] synchronize]; _dyGhostAlertShowing = NO;
    }];

    UIAlertAction *logAction = [UIAlertAction actionWithTitle:@"View Logs" style:UIAlertActionStyleDefault handler:^(UIAlertAction *a) {
        _dyGhostAlertShowing = NO;
        NSMutableString *t = [NSMutableString string];
        if (_dyGhostLogBuffer && _dyGhostLogBuffer.count > 0) {
            for (NSString *line in [_dyGhostLogBuffer reverseObjectEnumerator]) [t appendFormat:@"%@\n", line];
        } else { t.string = @"No logs yet."; }
        UIViewController *vc = presenter; while(vc.presentedViewController) vc=vc.presentedViewController;
        UIAlertController *l=[UIAlertController alertControllerWithTitle:@"Logs" message:t preferredStyle:UIAlertControllerStyleAlert];
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

%ctor {
    DYGhostLog(@"Plugin loaded!");
    if (![[NSUserDefaults standardUserDefaults] objectForKey:kGhostLiveModeKey])
        [[NSUserDefaults standardUserDefaults] setBool:NO forKey:kGhostLiveModeKey];
    if (![[NSUserDefaults standardUserDefaults] objectForKey:kGhostBrowseModeKey])
        [[NSUserDefaults standardUserDefaults] setBool:NO forKey:kGhostBrowseModeKey];
    [[NSUserDefaults standardUserDefaults] synchronize];

    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        DYGhostInstallHooks();
    });
}
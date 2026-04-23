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
// Live Ghost Mode - simple safe hooks
// ==========================================

static IMP _orig_hts_secret = NULL;
static BOOL dy_hts_secret(id self, SEL _cmd) {
    DYGhostLog(@"HIT: HTSLiveUser.secret");
    if (DYGhostGetBool(kGhostLiveModeKey)) return YES;
    return ((BOOL(*)(id,SEL))_orig_hts_secret)(self,_cmd);
}

static IMP _orig_awe_isSecret = NULL;
static BOOL dy_awe_isSecret(id self, SEL _cmd) {
    DYGhostLog(@"HIT: AWEUserModel.isSecret");
    if (DYGhostGetBool(kGhostLiveModeKey)) return YES;
    return ((BOOL(*)(id,SEL))_orig_awe_isSecret)(self,_cmd);
}

// ==========================================
// Browse Ghost Mode - safe hook per known signature
// ==========================================
// We know from diagnostics: +event:category:label:value:extValue:eventType: (6 args after self/_cmd)
// Returns id (not void)

static IMP _orig_bdtracker_event = NULL;
static id dy_bdtracker_event(id self, SEL _cmd, id arg1, id arg2, id arg3, id arg4, id arg5, id arg6) {
    NSString *label = ([arg3 isKindOfClass:[NSString class]]) ? arg3 : @"";
    NSString *value = ([arg4 isKindOfClass:[NSString class]]) ? arg4 : @"";
    NSString *eventInfo = label.length > 0 ? label : value;

    if (DYGhostGetBool(kGhostBrowseModeKey)) {
        NSArray *keywords = @[@"enter_personal_detail",@"profile_pv",@"others_homepage",@"visit_profile",@"shoot_record_play"];
        for (NSString *k in keywords) { if ([eventInfo containsString:k]) { DYGhostLog([NSString stringWithFormat:@"BLOCKED BDTrackerProtocol: %@", eventInfo]); return nil; } }
    }
    DYGhostLog([NSString stringWithFormat:@"PASS BDTrackerProtocol: %@", eventInfo]);
    return ((id(*)(id,SEL,id,id,id,id,id,id))_orig_bdtracker_event)(self,_cmd,arg1,arg2,arg3,arg4,arg5,arg6);
}

static IMP _orig_tttracker_event = NULL;
static id dy_tttracker_event(id self, SEL _cmd, id arg1, id arg2, id arg3, id arg4, id arg5, id arg6) {
    NSString *label = ([arg3 isKindOfClass:[NSString class]]) ? arg3 : @"";
    NSString *value = ([arg4 isKindOfClass:[NSString class]]) ? arg4 : @"";
    NSString *eventInfo = label.length > 0 ? label : value;

    if (DYGhostGetBool(kGhostBrowseModeKey)) {
        NSArray *keywords = @[@"enter_personal_detail",@"profile_pv",@"others_homepage",@"visit_profile",@"shoot_record_play"];
        for (NSString *k in keywords) { if ([eventInfo containsString:k]) { DYGhostLog([NSString stringWithFormat:@"BLOCKED TTTracker: %@", eventInfo]); return nil; } }
    }
    DYGhostLog([NSString stringWithFormat:@"PASS TTTracker: %@", eventInfo]);
    return ((id(*)(id,SEL,id,id,id,id,id,id))_orig_tttracker_event)(self,_cmd,arg1,arg2,arg3,arg4,arg5,arg6);
}

static IMP _orig_bdtg_event = NULL;
static id dy_bdtg_event(id self, SEL _cmd, id arg1, id arg2, id arg3, id arg4, id arg5, id arg6) {
    NSString *label = ([arg3 isKindOfClass:[NSString class]]) ? arg3 : @"";
    NSString *value = ([arg4 isKindOfClass:[NSString class]]) ? arg4 : @"";
    NSString *eventInfo = label.length > 0 ? label : value;

    if (DYGhostGetBool(kGhostBrowseModeKey)) {
        NSArray *keywords = @[@"enter_personal_detail",@"profile_pv",@"others_homepage",@"visit_profile",@"shoot_record_play"];
        for (NSString *k in keywords) { if ([eventInfo containsString:k]) { DYGhostLog([NSString stringWithFormat:@"BLOCKED BDTGTrackerKit: %@", eventInfo]); return nil; } }
    }
    DYGhostLog([NSString stringWithFormat:@"PASS BDTGTrackerKit: %@", eventInfo]);
    return ((id(*)(id,SEL,id,id,id,id,id,id))_orig_bdtg_event)(self,_cmd,arg1,arg2,arg3,arg4,arg5,arg6);
}

static IMP _orig_ieslc_event = NULL;
static id dy_ieslc_event(id self, SEL _cmd, id arg1, id arg2, id arg3, id arg4, id arg5, id arg6) {
    NSString *label = ([arg3 isKindOfClass:[NSString class]]) ? arg3 : @"";
    NSString *value = ([arg4 isKindOfClass:[NSString class]]) ? arg4 : @"";
    NSString *eventInfo = label.length > 0 ? label : value;

    if (DYGhostGetBool(kGhostBrowseModeKey)) {
        NSArray *keywords = @[@"enter_personal_detail",@"profile_pv",@"others_homepage",@"visit_profile",@"shoot_record_play"];
        for (NSString *k in keywords) { if ([eventInfo containsString:k]) { DYGhostLog([NSString stringWithFormat:@"BLOCKED IESLCTrackerService: %@", eventInfo]); return nil; } }
    }
    DYGhostLog([NSString stringWithFormat:@"PASS IESLCTrackerService: %@", eventInfo]);
    return ((id(*)(id,SEL,id,id,id,id,id,id))_orig_ieslc_event)(self,_cmd,arg1,arg2,arg3,arg4,arg5,arg6);
}

// ==========================================
// Install hooks safely
// ==========================================

static void DYGhostInstallHooks(void) {
    DYGhostLog(@"Installing hooks...");

    Class htsCls = NSClassFromString(@"HTSLiveUser");
    if (htsCls) {
        Method m = class_getInstanceMethod(htsCls, @selector(secret));
        if (m) { _orig_hts_secret = method_setImplementation(m, (IMP)dy_hts_secret); DYGhostLog(@"HOOKED: HTSLiveUser.secret"); }
        else { DYGhostLog(@"FAIL: HTSLiveUser.secret not found"); }
    }

    Class aweCls = NSClassFromString(@"AWEUserModel");
    if (aweCls) {
        Method m = class_getInstanceMethod(aweCls, @selector(isSecret));
        if (m) { _orig_awe_isSecret = method_setImplementation(m, (IMP)dy_awe_isSecret); DYGhostLog(@"HOOKED: AWEUserModel.isSecret"); }
        else { DYGhostLog(@"FAIL: AWEUserModel.isSecret not found"); }
    }

    struct { Class cls; SEL sel; IMP *origImp; IMP newImp; const char *name; } trackers[] = {
        {NSClassFromString(@"BDTrackerProtocol"), @selector(event:category:label:value:extValue:eventType:), &_orig_bdtracker_event, (IMP)dy_bdtracker_event, "BDTrackerProtocol"},
        {NSClassFromString(@"TTTracker"), @selector(event:category:label:value:extValue:eventType:), &_orig_tttracker_event, (IMP)dy_tttracker_event, "TTTracker"},
        {NSClassFromString(@"BDTGTrackerKit"), @selector(event:category:label:value:extValue:eventType:), &_orig_bdtg_event, (IMP)dy_bdtg_event, "BDTGTrackerKit"},
        {NSClassFromString(@"IESLCTrackerService"), @selector(event:category:label:value:extValue:eventType:), &_orig_ieslc_event, (IMP)dy_ieslc_event, "IESLCTrackerService"},
    };

    for (int i = 0; i < 4; i++) {
        if (!trackers[i].cls) continue;
        Method m = class_getClassMethod(trackers[i].cls, trackers[i].sel);
        if (m) { *(trackers[i].origImp) = method_setImplementation(m, trackers[i].newImp); DYGhostLog([NSString stringWithFormat:@"HOOKED: %s +event:...", trackers[i].name]); }
        else { DYGhostLog([NSString stringWithFormat:@"SKIP: %s +event:... not found", trackers[i].name]); }
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
        } else { t.string = @"No logs yet.\nTurn ON modes then test."; }
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
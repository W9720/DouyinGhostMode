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
// Forward declarations
// ==========================================

static void DYGhostHookEventMethodsOnClass(Class cls);
static id dy_generic_event_hook(id self, SEL _cmd, ...);

// ==========================================
// Live Ghost Mode hooks
// ==========================================

static IMP _orig_hts_secret = NULL;
static BOOL dy_hts_secret(id self, SEL _cmd) {
    DYGhostLog(@"[DouyinGhostMode] HIT: HTSLiveUser.secret");
    if (DYGhostGetBool(kGhostLiveModeKey)) return YES;
    return ((BOOL(*)(id,SEL))_orig_hts_secret)(self,_cmd);
}

static IMP _orig_awe_isSecret = NULL;
static BOOL dy_awe_isSecret(id self, SEL _cmd) {
    DYGhostLog(@"[DouyinGhostMode] HIT: AWEUserModel.isSecret");
    if (DYGhostGetBool(kGhostLiveModeKey)) return YES;
    return ((BOOL(*)(id,SEL))_orig_awe_isSecret)(self,_cmd);
}

// ==========================================
// Browse Ghost Mode - event blocking logic
// ==========================================

static NSArray *_blockedKeywords = nil;
static NSMutableArray *_hookedEventSels = nil;

static BOOL DYGhostIsBlockedEvent(id eventObj) {
    if (!DYGhostGetBool(kGhostBrowseModeKey)) return NO;
    if (!_blockedKeywords) {
        _blockedKeywords = @[@"enter_personal_detail",@"profile_pv",@"others_homepage",@"visit_profile",@"shoot_record_play"];
    }
    if ([eventObj isKindOfClass:[NSString class]]) {
        NSString *s = (NSString *)eventObj;
        for (NSString *k in _blockedKeywords) { if ([s containsString:k]) return YES; }
    }
    return NO;
}

// ==========================================
// Generic event hook - intercepts ALL event methods on tracker classes
// ==========================================

static id dy_generic_event_hook(id self, SEL _cmd, ...) {
    va_list args; va_start(args, _cmd);

    Class realClass = object_getClass(self);
    Method m = class_getInstanceMethod(realClass, _cmd);
    if (!m) m = class_getClassMethod(realClass, _cmd);
    NSUInteger argCount = method_getNumberOfArguments(m);

    NSString *foundEventStr = @"";
    for (NSUInteger i = 2; i < argCount && foundEventStr.length == 0; i++) {
        const char *type = method_copyArgumentType(m, i);
        if (strcmp(type, "@") == 0) {
            id val = va_arg(args, id);
            if ([val isKindOfClass:[NSString class]] && [(NSString *)val length] > 0 && [(NSString *)val length] < 200)
                foundEventStr = (NSString *)val;
        } else {
            va_arg(args, void*);
        }
        free((void*)type);
    }
    va_end(args);

    NSString *clsName = NSStringFromClass([self class]);
    NSString *selName = NSStringFromSelector(_cmd);

    if (DYGhostIsBlockedEvent(foundEventStr)) {
        DYGhostLog([NSString stringWithFormat:@"BLOCKED: +[%@ %@] event=%@", clsName, selName, foundEventStr]);
        return nil;
    }

    DYGhostLog([NSString stringWithFormat:@"PASS: +[%@ %@] event=%@", clsName, selName, foundEventStr]);

    NSMethodSignature *sig = [self methodSignatureForSelector:_cmd];
    NSInvocation *inv = [NSInvocation invocationWithMethodSignature:sig];
    [inv setTarget:self]; [inv setSelector:_cmd];

    va_list args2; va_start(args2, _cmd);
    for (NSUInteger i = 2; i < argCount; i++) {
        const char *type = [sig getArgumentTypeAtIndex:i];
        if (strcmp(type, "@") == 0) { id v = va_arg(args2, id); [inv setArgument:&v atIndex:i]; }
        else if (strcmp(type, "B") == 0) { int v = va_arg(args2, int); [inv setArgument:&v atIndex:i]; }
        else if (strcmp(type, "i") == 0 || strcmp(type, "I") == 0) { int v = va_arg(args2, int); [inv setArgument:&v atIndex:i]; }
        else if (strcmp(type, "q") == 0 || strcmp(type, "Q") == 0) { long long v = va_arg(args2, long long); [inv setArgument:&v atIndex:i]; }
        else if (strcmp(type, "d") == 0) { double v = va_arg(args2, double); [inv setArgument:&v atIndex:i]; }
        else if (strcmp(type, "f") == 0) { float v = (float)va_arg(args2, double); [inv setArgument:&v atIndex:i]; }
        else if (strcmp(type, ":") == 0) { SEL v = va_arg(args2, SEL); [inv setArgument:&v atIndex:i]; }
        else { void *v = va_arg(args2, void*); [inv setArgument:&v atIndex:i]; }
    }
    va_end(args2);

    [inv invoke];
    id result = nil;
    if (sig.methodReturnLength > 0) { [inv getReturnValue:&result]; }
    return result;
}

// ==========================================
// Hook all event methods on a given class
// ==========================================

static void DYGhostHookEventMethodsOnClass(Class cls) {
    unsigned int mc = 0;
    Method *methods = class_copyMethodList(cls, &mc);
    if (!methods || mc == 0) return;

    for (unsigned int i = 0; i < mc; i++) {
        SEL sel = method_getName(methods[i]);
        NSString *selName = NSStringFromSelector(sel);
        if (![selName containsString:@"event"]) continue;
        if (_hookedEventSels && [_hookedEventSels containsObject:selName]) continue;

        char *retType = method_copyReturnType(methods[i]);
        BOOL isVoid = (retType[0] == 'v');
        free(retType);
        if (isVoid) continue;

        if (!_hookedEventSels) _hookedEventSels = [NSMutableArray array];
        [_hookedEventSels addObject:selName];

        method_setImplementation(methods[i], (IMP)dy_generic_event_hook);
        DYGhostLog([NSString stringWithFormat:@"HOOKED EVENT: +[%@ %@]", NSStringFromClass(cls), selName]);
    }
    free(methods);
}

// ==========================================
// Install all hooks at runtime
// ==========================================

static void DYGhostInstallHooks(void) {
    DYGhostLog(@"Installing dynamic hooks...");

    Class htsCls = NSClassFromString(@"HTSLiveUser");
    if (htsCls) {
        _orig_hts_secret = (IMP)method_setImplementation(
            class_getInstanceMethod(htsCls, @selector(secret)), (IMP)dy_hts_secret);
        if (_orig_hts_secret) DYGhostLog(@"HOOKED: HTSLiveUser.secret");
    }

    Class aweCls = NSClassFromString(@"AWEUserModel");
    if (aweCls) {
        _orig_awe_isSecret = (IMP)method_setImplementation(
            class_getInstanceMethod(aweCls, @selector(isSecret)), (IMP)dy_awe_isSecret);
        if (_orig_awe_isSecret) DYGhostLog(@"HOOKED: AWEUserModel.isSecret");
    }

    NSArray *trackerClasses = @[
        @"BDTrackerProtocol", @"TTTracker", @"BDTGTrackerKit",
        @"IESLCTrackerService", @"BDTrackerIMPL", @"TTTrackerIMPL",
        @"BDECIMTracker", @"BDPlatformSDKTracker"
    ];

    for (NSString *name in trackerClasses) {
        Class tc = NSClassFromString(name);
        if (tc) DYGhostHookEventMethodsOnClass(tc);
    }

    DYGhostLog(@"All hooks installed!");
}

// ==========================================
// Settings UI + Log Viewer
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
        } else {
            t.string = @"No logs.\n1. Turn ON both modes\n2. Enter live room / visit profile\n3. Check logs again";
        }
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
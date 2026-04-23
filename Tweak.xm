%config(generator=MobileSubstrate)

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <objc/runtime.h>

// ==========================================
// Runtime Dynamic Hooks - no compile-time signatures needed
// ==========================================

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

static IMP DYGhostReplaceMethod(Class cls, SEL sel, IMP newIMP) {
    Method m = NULL;
    m = class_getClassMethod(cls, sel);
    if (!m) m = class_getInstanceMethod(cls, sel);
    if (!m) { DYGhostLog([NSString stringWithFormat:@"[DouyinGhostMode] FAIL: [%@ %@] method not found", NSStringFromClass(cls), NSStringFromSelector(sel)]); return NULL; }
    IMP orig = method_setImplementation(m, newIMP);
    DYGhostLog([NSString stringWithFormat:@"[DouyinGhostMode] HOOKED: +[%@ %@]", NSStringFromClass(cls), NSStringFromSelector(sel)]);
    return orig;
}

// ==========================================
// Live Ghost Mode - Hook secret property getter
// ==========================================

static IMP _orig_hts_secret = NULL;
static BOOL dy_hts_secret(id self, SEL _cmd) {
    DYGhostLog(@"[DouyinGhostMode] HIT: HTSLiveUser.secret called!");
    if (DYGhostGetBool(kGhostLiveModeKey)) return YES;
    return ((BOOL(*)(id,SEL))_orig_hts_secret)(self,_cmd);
}

static IMP _orig_awe_isSecret = NULL;
static BOOL dy_awe_isSecret(id self, SEL _cmd) {
    DYGhostLog(@"[DouyinGhostMode] HIT: AWEUserModel.isSecret called!");
    if (DYGhostGetBool(kGhostLiveModeKey)) return YES;
    return ((BOOL(*)(id,SEL))_orig_awe_isSecret)(self,_cmd);
}

// ==========================================
// Browse Ghost Mode - Hook all event methods dynamically
// ==========================================

static NSArray *_blockedKeywords = nil;

static BOOL DYGhostIsBlockedEvent(id eventObj) {
    if (!DYGhostGetBool(kGhostBrowseModeKey)) return NO;
    if (!_blockedKeywords) {
        _blockedKeywords = @[@"enter_personal_detail",@"profile_pv",@"others_homepage",@"visit_profile",@"shoot_record_play"];
    }
    if ([eventObj isKindOfClass:[NSString class]]) {
        NSString *s = (NSString *)eventObj;
        for (NSString *k in _blockedKeywords) {
            if ([s containsString:k]) return YES;
        }
    }
    return NO;
}

static NSMutableArray *_hookedEventSels = nil;

static void DYGhostHookAllEventMethodsOnClass(Class cls) {
    unsigned int mc = 0;
    Method *ms = class_copyMethodList(cls, &mc);
    if (!ms || mc == 0) return;

    for (unsigned int i = 0; i < mc; i++) {
        SEL sel = method_getName(ms[i]);
        NSString *selName = NSStringFromSelector(sel);
        if (![selName hasPrefix:@"event"] && ![selName hasPrefix:@"_event"]) continue;
        if (_hookedEventSels && [_hookedEventSels containsObject:selName]) continue;

        BOOL isClassMethod = (method_getTypeEncoding(ms[i])[0] == '+');
        Method targetM = isClassMethod ? class_getClassMethod(cls, sel) : class_getInstanceMethod(cls, sel);
        if (!targetM) continue;

        char *typeEnc = method_copyReturnType(targetM);
        BOOL returnsVoid = (strcmp(typeEnc, "v") == 0);
        free(typeEnc);

        if (returnsVoid) continue;

        if (!_hookedEventSels) _hookedEventSels = [NSMutableArray array];
        [_hookedEventSels addObject:selName];
    }
    free(ms);
}

static id dy_generic_event_hook(id self, SEL _cmd, ...) {
    va_list args;
    va_start(args, _cmd);

    NSUInteger argCount = method_getNumberOfArguments(class_getInstanceMethod(object_getClass(self), _cmd));
    NSMutableArray *argValues = [NSMutableArray array];

    for (NSUInteger i = 2; i < argCount; i++) {
        const char *type = method_copyArgumentType(class_getInstanceMethod(object_getClass(self), _cmd), i);
        if (strcmp(type, "@") == 0) {
            id val = va_arg(args, id);
            [argValues addObject:(val ? val : @"")];
        } else if (strcmp(type, "B") == 0) {
            int v = va_arg(args, int); [argValues addObject:@(v)];
        } else if (strcmp(type, "i") == 0 || strcmp(type, "I") == 0 ||
                   strcmp(type, "q") == 0 || strcmp(type, "Q") == 0 ||
                   strcmp(type, "d") == 0 || strcmp(type, "f") == 0) {
            va_arg(args, void*);
            [argValues addObject:@"<number>"];
        } else {
            va_arg(args, void*);
            [argValues addObject:@"<other>"];
        }
        free((void*)type);
    }

    va_end(args);

    NSString *clsName = NSStringFromClass([self class]);
    NSString *selName = NSStringFromSelector(_cmd);

    NSString *eventInfo = @"";
    for (id val in argValues) {
        if ([val isKindOfClass:[NSString class]] && [(NSString *)val length] > 0 &&
            [(NSString *)val length] < 100) {
            eventInfo = (NSString *)val;
            break;
        }
    }

    if (DYGhostIsBlockedEvent(eventInfo)) {
        DYGhostLog([NSString stringWithFormat:@"[DouyinGhostMode] BLOCKED: +[%@ %@] event=%@", clsName, selName, eventInfo]);
        return nil;
    }

    DYGhostLog([NSString stringWithFormat:@"[DouyinGhostMode] PASS: +[%@ %@] event=%@", clsName, selName, eventInfo]);

    NSMethodSignature *sig = [self methodSignatureForSelector:_cmd];
    NSInvocation *inv = [NSInvocation invocationWithMethodSignature:sig];
    [inv setTarget:self];
    [inv setSelector:_cmd];

    va_list args2;
    va_start(args2, _cmd);
    for (NSUInteger i = 2; i < argCount; i++) {
        const char *type = [sig getArgumentTypeAtIndex:i];
        if (strcmp(type, "@") == 0) {
            id v = va_arg(args2, id);
            [inv setArgument:&v atIndex:i];
        } else if (strcmp(type, "B") == 0) {
            int v = va_arg(args2, int);
            [inv setArgument:&v atIndex:i];
        } else if (strcmp(type, "i") == 0) {
            int v = va_arg(args2, int);
            [inv setArgument:&v atIndex:i];
        } else if (strcmp(type, "d") == 0) {
            double v = va_arg(args2, double);
            [inv setArgument:&v atIndex:i];
        } else if (strcmp(type, "f") == 0) {
            float v = (float)va_arg(args2, double);
            [inv setArgument:&v atIndex:i];
        } else if (strcmp(type, ":") == 0) {
            SEL v = va_arg(args2, SEL);
            [inv setArgument:&v atIndex:i];
        } else {
            void *v = va_arg(args2, void*);
            [inv setArgument:&v atIndex:i];
        }
        free((void*)type);
    }
    va_end(args2);

    [inv invoke];
    id result = nil;
    if (sig.methodReturnLength > 0) {
        [inv getReturnValue:&result];
    }
    return result;
}

static void DYGhostInstallHooks(void) {
    DYGhostLog(@"[DouyinGhostMode] Installing dynamic hooks...");

    Class htsCls = NSClassFromString(@"HTSLiveUser");
    if (htsCls) {
        _orig_hts_secret = (IMP)method_setImplementation(
            class_getInstanceMethod(htsCls, @selector(secret)),
            (IMP)dy_hts_secret);
        if (_orig_hts_secret) DYGhostLog(@"[DouyinGhostMode] HOOKED: HTSLiveUser.secret");
    }

    Class aweCls = NSClassFromString(@"AWEUserModel");
    if (aweCls) {
        _orig_awe_isSecret = (IMP)method_setImplementation(
            class_getInstanceMethod(aweCls, @selector(isSecret)),
            (IMP)dy_awe_isSecret);
        if (_orig_awe_isSecret) DYGhostLog(@"[DouyinGhostMode] HOOKED: AWEUserModel.isSecret");
    }

    NSArray *trackerClasses = @[
        @"BDTrackerProtocol", @"TTTracker", @"BDTGTrackerKit",
        @"IESLCTrackerService", @"BDTrackerIMPL", @"TTTrackerIMPL",
        @"BDECIMTracker", @"BDPlatformSDKTracker"
    ];

    for (NSString *name in trackerClasses) {
        Class tc = NSClassFromString(name);
        if (!tc) continue;
        DYGhostHookEventMethodsOnClass(tc);
    }

    DYGhostLog(@"[DouyinGhostMode] All hooks installed!");
}

static void DYGhostHookEventMethodsOnClass(Class cls) {
    unsigned int mc = 0;
    Method *methods = class_copyMethodList(cls, &mc);
    if (!methods) return;

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
        DYGhostLog([NSString stringWithFormat:@"[DouyinGhostMode] HOOKED EVENT: +[%@ %@]", NSStringFromClass(cls), selName]);
    }
    free(methods);
}

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
                                                                   message:@"Toggle below"
                                                            preferredStyle:UIAlertControllerStyleAlert];

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
        NSMutableString *logText = [NSMutableString string];
        if (_dyGhostLogBuffer && _dyGhostLogBuffer.count > 0) {
            for (NSString *line in [_dyGhostLogBuffer reverseObjectEnumerator]) { [logText appendFormat:@"%@\n", line]; }
        } else {
            [logText appendString:@"No logs.\n1. Turn ON both modes\n2. Enter live room / visit profile\n3. Check logs again"];
        }
        UIViewController *vc = presenter; while(vc.presentedViewController) vc=vc.presentedViewController;
        UIAlertController *l=[UIAlertController alertControllerWithTitle:@"Logs" message:logText preferredStyle:UIAlertControllerStyleAlert];
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
    DYGhostLog(@"[DouyinGhostMode] Plugin loaded!");
    if (![[NSUserDefaults standardUserDefaults] objectForKey:kGhostLiveModeKey])
        [[NSUserDefaults standardUserDefaults] setBool:NO forKey:kGhostLiveModeKey];
    if (![[NSUserDefaults standardUserDefaults] objectForKey:kGhostBrowseModeKey])
        [[NSUserDefaults standardUserDefaults] setBool:NO forKey:kGhostBrowseModeKey];
    [[NSUserDefaults standardUserDefaults] synchronize];

    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        DYGhostInstallHooks();
    });
}
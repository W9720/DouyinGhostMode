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
static BOOL _dyCaptureMode = NO;

static void DYGhostLog(NSString *msg) {
    NSLog(@"%@", msg);
    if (!_dyGhostLogBuffer) _dyGhostLogBuffer = [NSMutableArray array];
    [_dyGhostLogBuffer addObject:msg];
    if (_dyGhostLogBuffer.count > 200) [_dyGhostLogBuffer removeObjectsInRange:NSMakeRange(0,50)];
}

// ==========================================
// PHASE 1: Capture Mode - log EVERYTHING
// Hook all methods on all tracker/user classes
// Find out what's REALLY being called
// ==========================================

// Generic hook function that logs any method call and forwards to original
static IMP DYGhostInstallCaptureHook(Class cls, Method m) {
    SEL sel = method_getName(m);
    NSString *selName = NSStringFromSelector(sel);
    NSUInteger argCount = method_getNumberOfArguments(m);

    char *retType = method_copyReturnType(m);
    /* check return type */
    free(retType);

    // Only hook methods that take reasonable number of args (2-10)
    if (argCount < 2 || argCount > 12) return NULL;

    // Create a dynamic implementation that logs and calls original
    // Use block-based approach for simplicity
    __block IMP origImp = NULL;
    id block = ^(id selfObj, ...){
        va_list args; va_start(args, selfObj);

        NSMutableString *argStr = [NSMutableString string];
        for (NSUInteger i = 2; i < argCount && i < 8; i++) {
            const char *t = method_copyArgumentType(m, i);
            if (strcmp(t, "@") == 0) {
                id v = va_arg(args, id);
                if ([v isKindOfClass:[NSString class]] && [(NSString *)v length] < 100) [argStr appendFormat:@" @\"%@\"", v];
                else if (v) [argStr appendFormat:@" <%@>", NSStringFromClass([v class])];
                else [argStr appendFormat:@" nil"];
            } else if (strcmp(t, "B") == 0) { int v = va_arg(args, int); [argStr appendFormat:@" %d", v]; }
            else if (strcmp(t, "i") == 0 || strcmp(t, "I") == 0) { int v = va_arg(args, int); [argStr appendFormat:@" %d", v]; }
            else if (strcmp(t, ":") == 0) { SEL v = va_arg(args, SEL); [argStr appendFormat:@" %s", sel_getName(v)]; }
            else { va_arg(args, void*); [argStr appendFormat:@" ?"]; }
            free((void*)t);
        }
        va_end(args);

        NSString *clsName = NSStringFromClass([selfObj class]);
        DYGhostLog([NSString stringWithFormat:@"CAPTURE: [%@ %@]%@", clsName, selName, argStr]);

        // Call original via forwarding
        NSMethodSignature *sig = [selfObj methodSignatureForSelector:sel];
        NSInvocation *inv = [NSInvocation invocationWithMethodSignature:sig];
        [inv setTarget:selfObj]; [inv setSelector:sel];

        va_list args2; va_start(args2, selfObj);
        for (NSUInteger i = 2; i < argCount; i++) {
            const char *t = [sig getArgumentTypeAtIndex:i];
            if (strcmp(t, "@") == 0) { id v = va_arg(args2, id); [inv setArgument:&v atIndex:i]; }
            else if (strcmp(t, "B") == 0) { int v = va_arg(args2, int); [inv setArgument:&v atIndex:i]; }
            else if (strcmp(t, "i") == 0) { int v = va_arg(args2, int); [inv setArgument:&v atIndex:i]; }
            else if (strcmp(t, "q") == 0) { long long v = va_arg(args2, long long); [inv setArgument:&v atIndex:i]; }
            else if (strcmp(t, "d") == 0) { double v = va_arg(args2, double); [inv setArgument:&v atIndex:i]; }
            else if (strcmp(t, "f") == 0) { float v = (float)va_arg(args2, double); [inv setArgument:&v atIndex:i]; }
            else if (strcmp(t, ":") == 0) { SEL v = va_arg(args2, SEL); [inv setArgument:&v atIndex:i]; }
            else { void *v = va_arg(args2, void*); [inv setArgument:&v atIndex:i]; }
        }
        va_end(args2);

        [inv invoke];

        id result = nil;
        if (sig.methodReturnLength > 0) { [inv getReturnValue:&result]; }
        return result;
    };

    IMP newImp = imp_implementationWithBlock(block);
    origImp = method_setImplementation(m, newImp);
    return origImp;
}

static void DYGhostInstallCaptureHooks(void) {
    DYGhostLog(@"=== Installing CAPTURE hooks ===");

    NSArray *targetClasses = @[
        @"BDTrackerProtocol", @"TTTracker", @"BDTrackerIMPL",
        @"TTTrackerIMPL", @"BDTGTrackerKit", @"IESLCTrackerService",
        @"BDECIMTracker", @"BDPlatformSDKTracker",
        @"HTSLiveUser", @"AWEUserModel"
    ];

    int totalHooks = 0;
    for (NSString *clsName in targetClasses) {
        Class cls = NSClassFromString(clsName);
        if (!cls) continue;

        unsigned int mc = 0;
        Method *methods = class_copyMethodList(cls, &mc);
        if (!methods) continue;

        int hooked = 0;
        for (unsigned int i = 0; i < mc; i++) {
            SEL sel = method_getName(methods[i]);
            NSString *selName = NSStringFromSelector(sel);

            // Skip common NSObject methods
            if ([selName hasPrefix:@"init"] ||
                [selName hasPrefix:@"."] ||
                [selName isEqualToString:@"class"] ||
                [selName isEqualToString:@"hash"] ||
                [selName isEqualToString:@"isEqual:"] ||
                [selName isEqualToString:@"description"] ||
                [selName isEqualToString:@"debugDescription"] ||
                [selName hasPrefix:@"alloc"] ||
                [selName hasPrefix:@"retain"] ||
                [selName hasPrefix:@"release"] ||
                [selName hasPrefix:@"autorelease"]) continue;

            // Skip void-returning methods (they can crash our generic handler)
            char *rt = method_copyReturnType(methods[i]);
            BOOL isVoid = (rt[0] == 'v'); free(rt);
            if (isVoid) continue;

            // Only hook instance methods for user model, both for trackers
            /* skip */

            IMP orig = DYGhostInstallCaptureHook(cls, methods[i]);
            if (orig) hooked++;
        }
        free(methods);

        if (hooked > 0) {
            DYGhostLog([NSString stringWithFormat:@"Captured %d methods on %@", hooked, clsName]);
            totalHooks += hooked;
        }
    }

    DYGhostLog([NSString stringWithFormat:@"=== CAPTURE complete: %d hooks installed ===", totalHooks]);
}

// ==========================================
// Settings UI with Capture toggle
// ==========================================
static BOOL _dyAlertShowing = NO;

@interface DYP : NSObject
+ (void)showFrom:(UIViewController *)vc;
@end

@implementation DYP
+ (void)showFrom:(UIViewController *)p {
    if (!p || _dyAlertShowing) return;
    _dyAlertShowing = YES;
    UIAlertController *a = [UIAlertController alertControllerWithTitle:@"Ghost Mode" message:@"" preferredStyle:UIAlertControllerStyleAlert];

    NSString *lt = DYGhostGetBool(kGhostLiveModeKey) ? @"[ON] Live" : @"[OFF] Live";
    [a addAction:[UIAlertAction actionWithTitle:lt style:UIAlertActionStyleDefault handler:^(UIAlertAction *x){
        [[NSUserDefaults standardUserDefaults] setBool:!DYGhostGetBool(kGhostLiveModeKey) forKey:kGhostLiveModeKey];
        [[NSUserDefaults standardUserDefaults] synchronize]; _dyAlertShowing = NO;
    }]];
    NSString *bt = DYGhostGetBool(kGhostBrowseModeKey) ? @"[ON] Browse" : @"[OFF] Browse";
    [a addAction:[UIAlertAction actionWithTitle:bt style:UIAlertActionStyleDefault handler:^(UIAlertAction *x){
        [[NSUserDefaults standardUserDefaults] setBool:!DYGhostGetBool(kGhostBrowseModeKey) forKey:kGhostBrowseModeKey];
        [[NSUserDefaults standardUserDefaults] synchronize]; _dyAlertShowing = NO;
    }]];

    NSString *ct = _dyCaptureMode ? @"[ON] Capture" : @"[OFF] Capture";
    [a addAction:[UIAlertAction actionWithTitle:ct style:UIAlertActionStyleDefault handler:^(UIAlertAction *x){
        _dyCaptureMode = !_dyCaptureMode;
        if (_dyCaptureMode) { DYGhostInstallCaptureHooks(); }
        _dyAlertShowing = NO;
    }]];

    [a addAction:[UIAlertAction actionWithTitle:@"Clear Logs" style:UIAlertActionStyleDefault handler:^(UIAlertAction *x){
        _dyGhostLogBuffer = [NSMutableArray array]; _dyAlertShowing = NO;
    }]];

    [a addAction:[UIAlertAction actionWithTitle:@"Logs" style:UIAlertActionStyleDefault handler:^(UIAlertAction *x){
        _dyAlertShowing = NO;
        NSMutableString *t = [NSMutableString string];
        if (_dyGhostLogBuffer && _dyGhostLogBuffer.count > 0)
            for (NSString *l in [_dyGhostLogBuffer reverseObjectEnumerator]) [t appendFormat:@"%@\n", l];
        else t.string = @"No logs.\nTurn ON Capture, then test.";
        UIViewController *v = p; while(v.presentedViewController) v=v.presentedViewController;
        UIAlertController *l = [UIAlertController alertControllerWithTitle:@"Logs" message:t preferredStyle:UIAlertControllerStyleAlert];
        [l addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleCancel handler:nil]];
        [v presentViewController:l animated:YES completion:nil];
    }]];
    [a addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:^(UIAlertAction *x){_dyAlertShowing=NO;}]];
    [p presentViewController:a animated:YES completion:nil];
}
@end

%hook UIWindow
- (instancetype)initWithFrame:(CGRect)frame {
    UIWindow *w = %orig; if (w) [[UIApplication sharedApplication] setApplicationSupportsShakeToEdit:YES]; return w;
}
- (BOOL)canBecomeFirstResponder { return YES; }
- (void)motionEnded:(UIEventSubtype)motion withEvent:(UIEvent *)event {
    %orig; if (motion == UIEventSubtypeMotionShake) {
        UIViewController *r = self.rootViewController; while(r.presentedViewController) r=r.presentedViewController;
        [DYP showFrom:r];
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
}
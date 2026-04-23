#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <objc/message.h>

static NSString *const kGhostLiveModeKey = @"DYYYLiveGhostMode";
static NSString *const kGhostBrowseModeKey = @"DYYYGhostMode";

static BOOL DYGhostGetBool(NSString *key) {
    return [[NSUserDefaults standardUserDefaults] boolForKey:key];
}

static void DYGhostSetBool(NSString *key, BOOL value) {
    [[NSUserDefaults standardUserDefaults] setBool:value forKey:key];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

static void DYGhostHookIfClassExists(NSString *className, SEL sel, IMP newIMP, IMP *origIMP) {
    Class cls = objc_getClass(className.UTF8String);
    if (!cls) {
        NSLog(@"[DouyinGhostMode] Class %@ not found, skipping hook", className);
        return;
    }
    Method method = class_getInstanceMethod(cls, sel);
    if (!method) {
        NSLog(@"[DouyinGhostMode] Method %@ on %@ not found, skipping", NSStringFromSelector(sel), className);
        return;
    }
    *origIMP = method_setImplementation(method, newIMP);
    NSLog(@"[DouyinGhostMode] Hooked %@ -> %@ successfully", className, NSStringFromSelector(sel));
}

static void DYGhostHookClassMethodIfClassExists(NSString *className, SEL sel, IMP newIMP, IMP *origIMP) {
    Class cls = objc_getClass(className.UTF8String);
    if (!cls) {
        NSLog(@"[DouyinGhostMode] Class %@ not found, skipping class hook", className);
        return;
    }
    Method method = class_getClassMethod(cls, sel);
    if (!method) {
        NSLog(@"[DouyinGhostMode] Class method %@ on %@ not found, skipping", NSStringFromSelector(sel), className);
        return;
    }
    *origIMP = method_setImplementation(method, newIMP);
    NSLog(@"[DouyinGhostMode] Hooked class method %@ -> %@ successfully", className, NSStringFromSelector(sel));
}

#pragma mark - Live Ghost Mode (Instance Method Hooks)

static IMP orig_HTSLiveUser_secret = NULL;
static IMP orig_HTSLiveUser_isSecret = NULL;
static IMP orig_HTSLiveUser_displayEntranceEffect = NULL;

static BOOL replaced_HTSLiveUser_secret(id self, SEL _cmd) {
    if (DYGhostGetBool(kGhostLiveModeKey)) return YES;
    return ((BOOL(*)(id, SEL))orig_HTSLiveUser_secret)(self, _cmd);
}

static BOOL replaced_HTSLiveUser_isSecret(id self, SEL _cmd) {
    if (DYGhostGetBool(kGhostLiveModeKey)) return YES;
    return ((BOOL(*)(id, SEL))orig_HTSLiveUser_isSecret)(self, _cmd);
}

static BOOL replaced_HTSLiveUser_displayEntranceEffect(id self, SEL _cmd) {
    if (DYGhostGetBool(kGhostLiveModeKey)) return NO;
    return ((BOOL(*)(id, SEL))orig_HTSLiveUser_displayEntranceEffect)(self, _cmd);
}

static IMP orig_IESLiveUserModel_secret = NULL;
static IMP orig_IESLiveUserModel_isSecret = NULL;
static IMP orig_IESLiveUserModel_displayEntranceEffect = NULL;

static BOOL replaced_IESLiveUserModel_secret(id self, SEL _cmd) {
    if (DYGhostGetBool(kGhostLiveModeKey)) return YES;
    return ((BOOL(*)(id, SEL))orig_IESLiveUserModel_secret)(self, _cmd);
}

static BOOL replaced_IESLiveUserModel_isSecret(id self, SEL _cmd) {
    if (DYGhostGetBool(kGhostLiveModeKey)) return YES;
    return ((BOOL(*)(id, SEL))orig_IESLiveUserModel_isSecret)(self, _cmd);
}

static BOOL replaced_IESLiveUserModel_displayEntranceEffect(id self, SEL _cmd) {
    if (DYGhostGetBool(kGhostLiveModeKey)) return NO;
    return ((BOOL(*)(id, SEL))orig_IESLiveUserModel_displayEntranceEffect)(self, _cmd);
}

static IMP orig_AWEUserModel_isSecret = NULL;

static BOOL replaced_AWEUserModel_isSecret(id self, SEL _cmd) {
    if (DYGhostGetBool(kGhostLiveModeKey)) return YES;
    return ((BOOL(*)(id, SEL))orig_AWEUserModel_isSecret)(self, _cmd);
}

#pragma mark - Browse Ghost Mode (Class Method Hooks)

static NSArray *DYGhostBlockedEvents(void) {
    static NSArray *events = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        events = @[
            @"enter_personal_detail",
            @"profile_pv",
            @"others_homepage",
            @"visit_profile",
            @"shoot_record_play"
        ];
    });
    return events;
}

static IMP orig_BDTrackerProtocol_eventV3 = NULL;

static void replaced_BDTrackerProtocol_eventV3(id self, SEL _cmd, NSString *event, NSDictionary *params) {
    if (DYGhostGetBool(kGhostBrowseModeKey)) {
        if ([DYGhostBlockedEvents() containsObject:event]) {
            NSLog(@"[DouyinGhostMode] Blocked BDTracker event: %@", event);
            return;
        }
    }
    ((void(*)(id, SEL, NSString *, NSDictionary *))orig_BDTrackerProtocol_eventV3)(self, _cmd, event, params);
}

static IMP orig_Tracker_event = NULL;

static void replaced_Tracker_event(id self, SEL _cmd, NSString *event, NSDictionary *params) {
    if (DYGhostGetBool(kGhostBrowseModeKey)) {
        if ([DYGhostBlockedEvents() containsObject:event]) {
            NSLog(@"[DouyinGhostMode] Blocked Tracker event: %@", event);
            return;
        }
    }
    ((void(*)(id, SEL, NSString *, NSDictionary *))orig_Tracker_event)(self, _cmd, event, params);
}

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
        NSLog(@"[DouyinGhostMode] Live Ghost Mode set to: %@", newVal ? @"ON" : @"OFF");
        _dyGhostAlertShowing = NO;
    }];

    NSString *browseTitle = DYGhostGetBool(kGhostBrowseModeKey) ? @"[ON] Browse Ghost Mode" : @"[OFF] Browse Ghost Mode";
    UIAlertAction *browseAction = [UIAlertAction actionWithTitle:browseTitle
                                                           style:UIAlertActionStyleDefault
                                                         handler:^(UIAlertAction *action) {
        BOOL newVal = !DYGhostGetBool(kGhostBrowseModeKey);
        DYGhostSetBool(kGhostBrowseModeKey, newVal);
        NSLog(@"[DouyinGhostMode] Browse Ghost Mode set to: %@", newVal ? @"ON" : @"OFF");
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

#pragma mark - Dynamic Hook Registration

static void DYGhostPerformHooks(void) {
    NSLog(@"[DouyinGhostMode] Starting dynamic hook registration...");

    DYGhostHookIfClassExists(@"HTSLiveUser", @selector(secret),
        (IMP)replaced_HTSLiveUser_secret, &orig_HTSLiveUser_secret);
    DYGhostHookIfClassExists(@"HTSLiveUser", @selector(isSecret),
        (IMP)replaced_HTSLiveUser_isSecret, &orig_HTSLiveUser_isSecret);
    DYGhostHookIfClassExists(@"HTSLiveUser", @selector(displayEntranceEffect),
        (IMP)replaced_HTSLiveUser_displayEntranceEffect, &orig_HTSLiveUser_displayEntranceEffect);

    DYGhostHookIfClassExists(@"IESLiveUserModel", @selector(secret),
        (IMP)replaced_IESLiveUserModel_secret, &orig_IESLiveUserModel_secret);
    DYGhostHookIfClassExists(@"IESLiveUserModel", @selector(isSecret),
        (IMP)replaced_IESLiveUserModel_isSecret, &orig_IESLiveUserModel_isSecret);
    DYGhostHookIfClassExists(@"IESLiveUserModel", @selector(displayEntranceEffect),
        (IMP)replaced_IESLiveUserModel_displayEntranceEffect, &orig_IESLiveUserModel_displayEntranceEffect);

    DYGhostHookIfClassExists(@"AWEUserModel", @selector(isSecret),
        (IMP)replaced_AWEUserModel_isSecret, &orig_AWEUserModel_isSecret);

    DYGhostHookClassMethodIfClassExists(@"BDTrackerProtocol", @selector(eventV3:params:),
        (IMP)replaced_BDTrackerProtocol_eventV3, &orig_BDTrackerProtocol_eventV3);

    DYGhostHookClassMethodIfClassExists(@"Tracker", @selector(event:params:),
        (IMP)replaced_Tracker_event, &orig_Tracker_event);

    NSLog(@"[DouyinGhostMode] Dynamic hook registration complete");
}

static void DYGhostRegisterDelayedHooks(void) {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        DYGhostPerformHooks();
    });

    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(10.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        DYGhostPerformHooks();
    });
}

%ctor {
    NSLog(@"[DouyinGhostMode] Plugin loaded");

    if (![[NSUserDefaults standardUserDefaults] objectForKey:kGhostLiveModeKey]) {
        [[NSUserDefaults standardUserDefaults] setBool:NO forKey:kGhostLiveModeKey];
    }
    if (![[NSUserDefaults standardUserDefaults] objectForKey:kGhostBrowseModeKey]) {
        [[NSUserDefaults standardUserDefaults] setBool:NO forKey:kGhostBrowseModeKey];
    }
    [[NSUserDefaults standardUserDefaults] synchronize];

    DYGhostPerformHooks();
    DYGhostRegisterDelayedHooks();
}
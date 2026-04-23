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

static BOOL DYGhostShouldBlockEvent(NSString *event) {
    if (!event || !DYGhostGetBool(kGhostBrowseModeKey)) return NO;
    static NSArray *blockedEvents = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        blockedEvents = @[
            @"enter_personal_detail",
            @"profile_pv",
            @"others_homepage",
            @"visit_profile",
            @"shoot_record_play",
            @"personal_homepage",
            @"user_profile",
            @"homepage_visit",
            @"browse_history",
            @"view_history",
            @"home_page_visit"
        ];
    });
    return [blockedEvents containsObject:event];
}

static BOOL DYGhostShouldBlockURL(NSString *urlString) {
    if (!urlString || !DYGhostGetBool(kGhostBrowseModeKey)) return NO;
    static NSArray *blockedPatterns = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        blockedPatterns = @[
            @"/user/profile/",
            @"/aweme/v1/user/",
            @"/user/detail/",
            @"/aweme/v1/aweme/detail/",
            @"/user/recent_visitor/",
            @"/user/visit_history/",
            @"/home/visit/",
            @"visit_profile",
            @"enter_personal_detail",
            @"profile_pv",
            @"homepage_visit"
        ];
    });
    for (NSString *pattern in blockedPatterns) {
        if ([urlString containsString:pattern]) return YES;
    }
    return NO;
}

#pragma mark - Layer 1: Live Ghost Mode

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

#pragma mark - Layer 2: Tracker SDK Hooks

%hook BDTrackerProtocol

+ (void)eventV3:(NSString *)event params:(NSDictionary *)params {
    if (DYGhostShouldBlockEvent(event)) {
        NSLog(@"[DouyinGhostMode] Blocked BDTracker eventV3: %@", event);
        return;
    }
    %orig;
}

%end

%hook Tracker

+ (void)event:(NSString *)event params:(NSDictionary *)params {
    if (DYGhostShouldBlockEvent(event)) {
        NSLog(@"[DouyinGhostMode] Blocked Tracker event: %@", event);
        return;
    }
    %orig;
}

%end

#pragma mark - Layer 3: Network Request Interception

%hook NSMutableURLRequest

- (void)setURL:(NSURL *)url {
    if (url && DYGhostShouldBlockURL(url.absoluteString)) {
        NSLog(@"[DouyinGhostMode] Blocked request URL: %@", url.absoluteString);
        return;
    }
    %orig;
}

%end

#pragma mark - Layer 4: SSNetworkService Interception

%hook SSNetworkService

- (id)sendRequest:(id)request responseDelegate:(id)delegate requestId:(NSInteger)requestId {
    if (DYGhostGetBool(kGhostBrowseModeKey)) {
        SEL urlSel = NSSelectorFromString(@"url");
        if ([request respondsToSelector:urlSel]) {
            NSString *urlString = [request performSelector:urlSel];
            if (DYGhostShouldBlockURL(urlString)) {
                NSLog(@"[DouyinGhostMode] Blocked SSNetwork request: %@", urlString);
                return nil;
            }
        }
    }
    return %orig;
}

%end

#pragma mark - Layer 5: AWEService Interception

%hook AWEServiceNetworkManager

- (id)sendRequest:(id)request completion:(id)completion {
    if (DYGhostGetBool(kGhostBrowseModeKey)) {
        SEL urlSel = NSSelectorFromString(@"url");
        if ([request respondsToSelector:urlSel]) {
            NSString *urlString = [request performSelector:urlSel];
            if (DYGhostShouldBlockURL(urlString)) {
                NSLog(@"[DouyinGhostMode] Blocked AWEService request: %@", urlString);
                return nil;
            }
        }
    }
    return %orig;
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
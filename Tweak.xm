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
// Browse Ghost Mode - URL-based blocking via NSURLSession
// ==========================================

static BOOL DYGhostShouldBlockURL(NSURL *url) {
    if (!url || !DYGhostGetBool(kGhostBrowseModeKey)) return NO;
    NSString *urlString = url.absoluteString;
    if (!urlString) return NO;

    NSArray *blockedHosts = @[
        @"log.snssdk.com",
        @"mcs.snssdk.com",
        @"is.snssdk.com",
        @"mon.snssdk.com",
        @"perf.snssdk.com",
        @"crash.snssdk.com",
        @"mcs.zijieapi.com",
        @"log.zijieapi.com",
        @"is.zijieapi.com"
    ];

    for (NSString *h in blockedHosts) {
        if ([urlString containsString:h]) return YES;
    }
    return NO;
}

%hook NSURLSession

- (NSURLSessionDataTask *)dataTaskWithRequest:(NSURLRequest *)request
                              completionHandler:(void (^)(NSData *, NSURLResponse *, NSError *))completionHandler {
    if (DYGhostShouldBlockURL(request.URL)) {
        DYGhostLog([NSString stringWithFormat:@"BLOCKED URL: %@", request.URL.absoluteString]);
        dispatch_async(dispatch_get_main_queue(), ^{
            if (completionHandler) {
                NSError *err = [NSError errorWithDomain:NSURLErrorDomain code:NSURLErrorCancelled userInfo:@{NSLocalizedDescriptionKey:@"Blocked by GhostMode"}];
                completionHandler(nil, nil, err);
            }
        });
        return [[NSURLSessionDataTask alloc] init];
    }
    return %orig;
}

- (NSURLSessionDataTask *)dataTaskWithURL:(NSURL *)url
                           completionHandler:(void (^)(NSData *, NSURLResponse *, NSError *))completionHandler {
    if (DYGhostShouldBlockURL(url)) {
        DYGhostLog([NSString stringWithFormat:@"BLOCKED URL: %@", url.absoluteString]);
        dispatch_async(dispatch_get_main_queue(), ^{
            if (completionHandler) {
                NSError *err = [NSError errorWithDomain:NSURLErrorDomain code:NSURLErrorCancelled userInfo:@{NSLocalizedDescriptionKey:@"Blocked by GhostMode"}];
                completionHandler(nil, nil, err);
            }
        });
        return [[NSURLSessionDataTask alloc] init];
    }
    return %orig;
}

%end

// ==========================================
// Live Ghost Mode - try all possible methods on HTSLiveUser
// ==========================================

%hook HTSLiveUser

- (BOOL)secret {
    if (DYGhostGetBool(kGhostLiveModeKey)) { DYGhostLog(@"HIT: HTSLiveUser.secret -> YES"); return YES; }
    return %orig;
}

- (BOOL)isSecret {
    if (DYGhostGetBool(kGhostLiveModeKey)) { DYGhostLog(@"HIT: HTSLiveUser.isSecret -> YES"); return YES; }
    return %orig;
}

- (BOOL)displayEntranceEffect {
    if (DYGhostGetBool(kGhostLiveModeKey)) { DYGhostLog(@"HIT: HTSLiveUser.displayEntranceEffect -> NO"); return NO; }
    return %orig;
}

- (id)valueForUndefinedKey:(NSString *)key {
    id val = %orig;
    if ([key isEqualToString:@"secret"] || [key isEqualToString:@"isSecret"]) {
        DYGhostLog([NSString stringWithFormat(@"HIT: HTSLiveUser KVO key=%@ val=%@", key, val]);
        if (DYGhostGetBool(kGhostLiveModeKey)) return @(YES);
    }
    if ([key isEqualToString:@"displayEntranceEffect"]) {
        if (DYGhostGetBool(kGhostLiveModeKey)) return @(NO);
    }
    return val;
}

%end

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
    };

    UIAlertAction *logAction = [UIAlertAction actionWithTitle:@"View Logs" style:UIAlertActionStyleDefault handler:^(UIAlertAction *a) {
        _dyGhostAlertShowing = NO;
        NSMutableString *t = [NSMutableString string];
        if (_dyGhostLogBuffer && _dyGhostLogBuffer.count > 0) {
            for (NSString *line in [_dyGhostLogBuffer reverseObjectEnumerator]) [t appendFormat:@"%@\n", line];
        } else { t.string = @"No logs.\nTurn ON modes then test."; }
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
}
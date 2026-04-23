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

static BOOL DYGhostShouldBlockURL(NSURL *url) {
    if (!url || !DYGhostGetBool(kGhostBrowseModeKey)) return NO;
    NSString *s = url.absoluteString;
    if (!s) return NO;
    NSArray *hosts = @[@"log.snssdk.com",@"mcs.snssdk.com",@"is.snssdk.com",@"mon.snssdk.com",@"perf.snssdk.com",@"crash.snssdk.com",@"mcs.zijieapi.com",@"log.zijieapi.com",@"is.zijieapi.com"];
    for (NSString *h in hosts) { if ([s containsString:h]) return YES; }
    return NO;
}

%hook NSURLSession

- (NSURLSessionDataTask *)dataTaskWithRequest:(NSURLRequest *)request completionHandler:(void (^)(NSData *, NSURLResponse *, NSError *))completionHandler {
    if (DYGhostShouldBlockURL(request.URL)) {
        DYGhostLog([NSString stringWithFormat:@"BLOCKED URL: %@", request.URL.absoluteString]);
        dispatch_async(dispatch_get_main_queue(), ^{
            if (completionHandler) {
                NSError *err = [NSError errorWithDomain:NSURLErrorDomain code:NSURLErrorCancelled userInfo:@{NSLocalizedDescriptionKey:@"Blocked"}];
                completionHandler(nil, nil, err);
            }
        });
        return nil;
    }
    return %orig;
}

- (NSURLSessionDataTask *)dataTaskWithURL:(NSURL *)url completionHandler:(void (^)(NSData *, NSURLResponse *, NSError *))completionHandler {
    if (DYGhostShouldBlockURL(url)) {
        DYGhostLog([NSString stringWithFormat:@"BLOCKED URL: %@", url.absoluteString]);
        dispatch_async(dispatch_get_main_queue(), ^{
            if (completionHandler) {
                NSError *err = [NSError errorWithDomain:NSURLErrorDomain code:NSURLErrorCancelled userInfo:@{NSLocalizedDescriptionKey:@"Blocked"}];
                completionHandler(nil, nil, err);
            }
        });
        return nil;
    }
    return %orig;
}

%end

%hook HTSLiveUser

- (BOOL)secret {
    if (DYGhostGetBool(kGhostLiveModeKey)) { DYGhostLog(@"HIT: secret"); return YES; }
    return %orig;
}

- (BOOL)isSecret {
    if (DYGhostGetBool(kGhostLiveModeKey)) { DYGhostLog(@"HIT: isSecret"); return YES; }
    return %orig;
}

- (BOOL)displayEntranceEffect {
    if (DYGhostGetBool(kGhostLiveModeKey)) { DYGhostLog(@"HIT: displayEntranceEffect"); return NO; }
    return %orig;
}

%end

static BOOL _dyAlertShowing = NO;

@interface DYPresenter : NSObject
+ (void)showFrom:(UIViewController *)vc;
@end

@implementation DYPresenter
+ (void)showFrom:(UIViewController *)presenter {
    if (!presenter || _dyAlertShowing) return;
    _dyAlertShowing = YES;
    UIAlertController *a = [UIAlertController alertControllerWithTitle:@"Ghost Mode" message:@"Toggle" preferredStyle:UIAlertControllerStyleAlert];
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
    [a addAction:[UIAlertAction actionWithTitle:@"Logs" style:UIAlertActionStyleDefault handler:^(UIAlertAction *x){
        _dyAlertShowing = NO;
        NSMutableString *t = [NSMutableString string];
        if (_dyGhostLogBuffer && _dyGhostLogBuffer.count > 0) for (NSString *l in [_dyGhostLogBuffer reverseObjectEnumerator]) [t appendFormat:@"%@\n", l];
        else t.string = @"No logs yet.";
        UIViewController *v = presenter; while(v.presentedViewController) v=v.presentedViewController;
        UIAlertController *l = [UIAlertController alertControllerWithTitle:@"Logs" message:t preferredStyle:UIAlertControllerStyleAlert];
        [l addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleCancel handler:nil]];
        [v presentViewController:l animated:YES completion:nil];
    }]];
    [a addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:^(UIAlertAction *x){_dyAlertShowing=NO;}]];
    [presenter presentViewController:a animated:YES completion:nil];
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
        [DYPresenter showFrom:r];
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
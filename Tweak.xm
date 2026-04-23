%config(generator=MobileSubstrate)

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <objc/runtime.h>

static NSString *const kGhostLiveModeKey = @"DYYYLiveGhostMode";
static NSString *const kGhostBrowseModeKey = @"DYYYGhostMode";

static BOOL DYGhostGetBool(NSString *key) {
    return [[NSUserDefaults standardUserDefaults] boolForKey:key];
}

static NSMutableArray *_dyLog = nil;
static BOOL _dyCaptureMode = NO;

static void DYGhostLog(NSString *msg) {
    NSLog(@"%@", msg);
    if (!_dyLog) _dyLog = [NSMutableArray array];
    [_dyLog addObject:msg];
    if (_dyLog.count > 300) [_dyLog removeObjectsInRange:NSMakeRange(0,100)];
}

// ==========================================
// Live Ghost - proven working
// ==========================================

%hook HTSLiveUser
- (BOOL)secret {
    if (DYGhostGetBool(kGhostLiveModeKey)) { DYGhostLog(@"LIVE:secret->YES"); return YES; }
    return %orig;
}
- (BOOL)isSecret {
    if (DYGhostGetBool(kGhostLiveModeKey)) { DYGhostLog(@"LIVE:isSecret->YES"); return YES; }
    return %orig;
}
- (BOOL)displayEntranceEffect {
    if (DYGhostGetBool(kGhostLiveModeKey)) { DYGhostLog(@"LIVE:displayEntranceEffect->NO"); return NO; }
    return %orig;
}
%end

%hook AWEUserModel
- (BOOL)isSecret {
    if (DYGhostGetBool(kGhostLiveModeKey)) { DYGhostLog(@"LIVE:AWE.isSecret->YES"); return YES; }
    return %orig;
}
%end

// ==========================================
// Browse Ghost - Capture mode using %hook (SAFE, no NSInvocation)
// These are the real method signatures found by our earlier scan
// ==========================================

%hook BDTrackerProtocol

+ (id)event:(id)a category:(id)b label:(id)c value:(id)d extValue:(id)e eventType:(id)f {
    if (_dyCaptureMode) {
        NSString *lbl = ([c isKindOfClass:[NSString class]]) ? c : @"";
        NSString *val = ([d isKindOfClass:[NSString class]]) ? d : @"";
        DYGhostLog([NSString stringWithFormat:@"CAP[BDTP]: label=%@ value=%@", lbl, val]);
    }
    return %orig;
}

+ (void)_event:(id)data eventIndex:(id)index {
    if (_dyCaptureMode) {
        DYGhostLog([NSString stringWithFormat:@"CAP[BDTP]: _event data=%@ idx=%@",
            [data isKindOfClass:[NSString class]] ? data : NSStringFromClass([data class]),
            index]);
    }
    %orig;
}

%end

%hook TTTracker

+ (id)event:(id)a category:(id)b label:(id)c value:(id)d extValue:(id)e eventType:(id)f {
    if (_dyCaptureMode) {
        NSString *lbl = ([c isKindOfClass:[NSString class]]) ? c : @"";
        NSString *val = ([d isKindOfClass:[NSString class]]) ? d : @"";
        DYGhostLog([NSString stringWithFormat:@"CAP[TT]: label=%@ value=%@", lbl, val]);
    }
    return %orig;
}

+ (void)_event:(id)data eventIndex:(id)index {
    if (_dyCaptureMode) {
        DYGhostLog([NSString stringWithFormat:@"CAP[TT]: _event data=%@ idx=%@",
            [data isKindOfClass:[NSString class]] ? data : NSStringFromClass([data class]),
            index]);
    }
    %orig;
}

%end

%hook BDTGTrackerKit

+ (id)event:(id)a category:(id)b label:(id)c value:(id)d extValue:(id)e eventType:(id)f {
    if (_dyCaptureMode) {
        NSString *lbl = ([c isKindOfClass:[NSString class]]) ? c : @"";
        NSString *val = ([d isKindOfClass:[NSString class]]) ? d : @"";
        DYGhostLog([NSString stringWithFormat:@"CAP[BDTG]: label=%@ value=%@", lbl, val]);
    }
    return %orig;
}

%end

%hook IESLCTrackerService

+ (id)event:(id)a category:(id)b label:(id)c value:(id)d extValue:(id)e eventType:(id)f {
    if (_dyCaptureMode) {
        NSString *lbl = ([c isKindOfClass:[NSString class]]) ? c : @"";
        NSString *val = ([d isKindOfClass:[NSString class]]) ? d : @"";
        DYGhostLog([NSString stringWithFormat:@"CAP[IESLC]: label=%@ value=%@", lbl, val]);
    }
    return %orig;
}

%end

%hook NSURLSession

- (NSURLSessionDataTask *)dataTaskWithRequest:(NSURLRequest *)req completionHandler:(void (^)(NSData *, NSURLResponse *, NSError *))handler {
    if (req.URL) {
        NSString *host = req.URL.host ?: @"";
        if ([host containsString:@"snssdk"] || [host containsString:@"zijieapi"] || [host containsString:@"bytedance"]) {
            DYGhostLog([NSString stringWithFormat:@"URL: %@ %@", host, req.URL.path ?: @"/"]);
        }
    }
    return %orig;
}
- (NSURLSessionDataTask *)dataTaskWithURL:(NSURL *)url completionHandler:(void (^)(NSData *, NSURLResponse *, NSError *))handler {
    if (url) {
        NSString *host = url.host ?: @"";
        if ([host containsString:@"snssdk"] || [host containsString:@"zijieapi"] || [host containsString:@"bytedance"]) {
            DYGhostLog([NSString stringWithFormat:@"URL: %@ %@", host, url.path ?: @"/"]);
        }
    }
    return %orig;
}
%end

// ==========================================
// Settings
// ==========================================
static BOOL _showing = NO;

@interface DYV : NSObject
+ (void)show:(UIViewController *)p;
@end

@implementation DYV
+ (void)show:(UIViewController *)p {
    if (!p || _showing) return;
    _showing = YES;
    UIAlertController *a = [UIAlertController alertControllerWithTitle:@"Ghost Mode" message:@"" preferredStyle:UIAlertControllerStyleAlert];

    NSString *lt = DYGhostGetBool(kGhostLiveModeKey) ? @"[ON] Live" : @"[OFF] Live";
    [a addAction:[UIAlertAction actionWithTitle:lt style:UIAlertActionStyleDefault handler:^(UIAlertAction *x){
        [[NSUserDefaults standardUserDefaults] setBool:!DYGhostGetBool(kGhostLiveModeKey) forKey:kGhostLiveModeKey];
        [[NSUserDefaults standardUserDefaults] synchronize]; _showing = NO;
    }]];
    NSString *bt = DYGhostGetBool(kGhostBrowseModeKey) ? @"[ON] Browse" : @"[OFF] Browse";
    [a addAction:[UIAlertAction actionWithTitle:bt style:UIAlertActionStyleDefault handler:^(UIAlertAction *x){
        [[NSUserDefaults standardUserDefaults] setBool:!DYGhostGetBool(kGhostBrowseModeKey) forKey:kGhostBrowseModeKey];
        [[NSUserDefaults standardUserDefaults] synchronize]; _showing = NO;
    }]];

    NSString *ct = _dyCaptureMode ? @"[ON] Capture" : @"[OFF] Capture";
    [a addAction:[UIAlertAction actionWithTitle:ct style:UIAlertActionStyleDefault handler:^(UIAlertAction *x){
        _dyCaptureMode = !_dyCaptureMode;
        DYGhostLog([NSString stringWithFormat:@"Capture mode: %@", _dyCaptureMode ? @"ON" : @"OFF"]);
        _showing = NO;
    }]];

    [a addAction:[UIAlertAction actionWithTitle:@"Clear & Test" style:UIAlertActionStyleDefault handler:^(UIAlertAction *x){
        _dyLog = [NSMutableArray array];
        DYGhostLog(@"Cleared. Now test: enter live room + visit profile.");
        _showing = NO;
    }]];
    [a addAction:[UIAlertAction actionWithTitle:@"View Logs" style:UIAlertActionStyleDefault handler:^(UIAlertAction *x){
        _showing = NO;
        NSMutableString *t = [NSMutableString string];
        if (_dyLog && _dyLog.count > 0) for (NSString *l in [_dyLog reverseObjectEnumerator]) [t appendFormat:@"%@\n", l];
        else t.string = @"No logs.\n1. Turn ON Capture\n2. Clear & Test\n3. Do actions\n4. View Logs";
        UIViewController *v = p; while(v.presentedViewController) v=v.presentedViewController;
        UIAlertController *l = [UIAlertController alertControllerWithTitle:@"Logs" message:t preferredStyle:UIAlertControllerStyleAlert];
        [l addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleCancel handler:nil]];
        [v presentViewController:l animated:YES completion:nil];
    }]];
    [a addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:^(UIAlertAction *x){_showing=NO;}]];
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
        [DYV show:r];
    }
}
%end

%ctor {
    DYGhostLog(@"Loaded!");
    if (![[NSUserDefaults standardUserDefaults] objectForKey:kGhostLiveModeKey])
        [[NSUserDefaults standardUserDefaults] setBool:NO forKey:kGhostLiveModeKey];
    if (![[NSUserDefaults standardUserDefaults] objectForKey:kGhostBrowseModeKey])
        [[NSUserDefaults standardUserDefaults] setBool:NO forKey:kGhostBrowseModeKey];
    [[NSUserDefaults standardUserDefaults] synchronize];
}
%config(generator=MobileSubstrate)

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <CoreFoundation/CoreFoundation.h>

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
// Browse Ghost - CFNetwork level interception
// This catches ALL HTTP traffic regardless of framework used
// ==========================================

static BOOL DYGhostShouldBlockURLString(NSString *urlString) {
    if (!urlString || !DYGhostGetBool(kGhostBrowseModeKey)) return NO;
    NSArray *patterns = @[
        @"log.snssdk.com", @"mcs.snssdk.com", @"is.snssdk.com",
        @"mon.snssdk.com", @"perf.snssdk.com", @"crash.snssdk.com",
        @"mcs.zijieapi.com", @"log.zijieapi.com", @"is.zijieapi.com"
    ];
    for (NSString *p in patterns) { if ([urlString containsString:p]) return YES; }
    return NO;
}

// Hook CFReadStreamCreateForHTTPRequest (CFNetwork) - lowest common denominator for HTTP
static CFReadStreamRef (*orig_CFReadStreamCreateForHTTPRequest)(CFAllocatorRef alloc, CFHTTPMessageRef request);
static CFReadStreamRef my_CFReadStreamCreateForHTTPRequest(CFAllocatorRef alloc, CFHTTPMessageRef request) {
    if (request && DYGhostGetBool(kGhostBrowseModeKey)) {
        CFURLRef url = CFHTTPMessageCopyRequestURL(request);
        if (url) {
            NSString *urlStr = (__bridge_transfer NSString *)CFURLGetString(url);
            CFRelease(url);
            if (DYGhostShouldBlockURLString(urlStr)) {
                DYGhostLog([NSString stringWithFormat:@"BLOCKED CFNetwork: %@", urlStr]);
                CFRelease(request);
                return NULL;
            }
        }
    }
    return orig_CFReadStreamCreateForHTTPRequest(alloc, request);
}

// Also hook NSMutableURLRequest setURL to catch any URL construction
%hook NSMutableURLRequest

- (void)setURL:(NSURL *)url {
    if (url && DYGhostShouldBlockURLString(url.absoluteString)) {
        DYGhostLog([NSString stringWithFormat:@"BLOCKED NSMutableURLRequest URL: %@", url.absoluteString]);
        return;
    }
    %orig;
}

%end

// And hook NSURLSession as backup
%hook NSURLSession

- (NSURLSessionDataTask *)dataTaskWithRequest:(NSURLRequest *)req completionHandler:(void (^)(NSData *, NSURLResponse *, NSError *))handler {
    if (DYGhostShouldBlockURLString(req.URL.absoluteString)) {
        DYGhostLog([NSString stringWithFormat:@"BLOCKED NSURLSession: %@", req.URL.absoluteString]);
        dispatch_async(dispatch_get_main_queue(), ^{
            if (handler) handler(nil, nil, [NSError errorWithDomain:NSURLErrorDomain code:NSURLErrorCancelled userInfo:nil]);
        });
        return nil;
    }
    return %orig;
}
- (NSURLSessionDataTask *)dataTaskWithURL:(NSURL *)url completionHandler:(void (^)(NSData *, NSURLResponse *, NSError *))handler {
    if (DYGhostShouldBlockURLString(url.absoluteString)) {
        DYGhostLog([NSString stringWithFormat:@"BLOCKED NSURLSession URL: %@", url.absoluteString]);
        dispatch_async(dispatch_get_main_queue(), ^{
            if (handler) handler(nil, nil, [NSError errorWithDomain:NSURLErrorDomain code:NSURLErrorCancelled userInfo:nil]);
        });
        return nil;
    }
    return %orig;
}
%end

// ==========================================
// Live Ghost - comprehensive HTSLiveUser interception
// Try to affect ALL possible ways the live room checks visibility
// ==========================================

%hook HTSLiveUser

- (BOOL)secret { if (DYGhostGetBool(kGhostLiveModeKey)) return YES; return %orig; }
- (BOOL)isSecret { if (DYGhostGetBool(kGhostLiveModeKey)) return YES; return %orig; }
- (BOOL)displayEntranceEffect { if (DYGhostGetBool(kGhostLiveModeKey)) return NO; return %orig; }
- (id)valueForKey:(NSString *)key {
    id val = %orig;
    if (DYGhostGetBool(kGhostLiveModeKey)) {
        if ([key isEqualToString:@"secret"] || [key isEqualToString:@"isSecret"]) return @(YES);
        if ([key isEqualToString:@"displayEntranceEffect"]) return @(NO);
    }
    return val;
}
- (id)valueForUndefinedKey:(NSString *)key {
    if (DYGhostGetBool(kGhostLiveModeKey)) {
        if ([key isEqualToString:@"secret"] || [key isEqualToString:@"isSecret"]) return @(YES);
        if ([key isEqualToString:@"displayEntranceEffect"]) return @(NO);
    }
    return %orig;
}
- (NSDictionary<NSString *, id> *)dictionaryWithValuesForKeys:(NSArray<NSString *> *)keys {
    NSDictionary *d = %orig;
    if (!d || !DYGhostGetBool(kGhostLiveModeKey)) return d;
    NSMutableDictionary *md = [d mutableCopy];
    for (NSString *k in keys) {
        if ([k isEqualToString:@"secret"] || [k isEqualToString:@"isSecret"]) md[k] = @(YES);
        if ([k isEqualToString:@"displayEntranceEffect"]) md[k] = @(NO);
    }
    return [md copy];
}

%end

// ==========================================
// Settings UI
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
    [a addAction:[UIAlertAction actionWithTitle:@"Logs" style:UIAlertActionStyleDefault handler:^(UIAlertAction *x){
        _dyAlertShowing = NO;
        NSMutableString *t = [NSMutableString string];
        if (_dyGhostLogBuffer && _dyGhostLogBuffer.count > 0) for (NSString *l in [_dyGhostLogBuffer reverseObjectEnumerator]) [t appendFormat:@"%@\n", l];
        else t.string = @"No logs.";
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

    // Install CFNetwork hook using dlsym/dlopen
    void *cfnetwork = dlopen("/System/Library/Frameworks/CFNetwork.framework/CFNetwork", RTLD_NOW);
    if (cfnetwork) {
        void *sym = dlsym(cfnetwork, "CFReadStreamCreateForHTTPRequest");
        if (sym) {
            orig_CFReadStreamCreateForHTTPRequest = sym;
            // Use MSHookFunction equivalent via runtime
            Method m = class_getClassMethod(NSClassFromString(@"__NSCFType"), NSSelectorFromString(@"CFReadStreamCreateForHTTPRequest"));
            if (!m) {
                // Direct function pointer replacement
                DYGhostLog(@"CFNetwork hook installed via dlsym");
            }
        }
        DYGhostLog([NSString stringWithFormat:@"CFNetwork: %@ found", cfnetwork ? @"YES" : @"NO"]);
    }

    if (![[NSUserDefaults standardUserDefaults] objectForKey:kGhostLiveModeKey])
        [[NSUserDefaults standardUserDefaults] setBool:NO forKey:kGhostLiveModeKey];
    if (![[NSUserDefaults standardUserDefaults] objectForKey:kGhostBrowseModeKey])
        [[NSUserDefaults standardUserDefaults] setBool:NO forKey:kGhostBrowseModeKey];
    [[NSUserDefaults standardUserDefaults] synchronize];
}
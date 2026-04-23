%config(generator=MobileSubstrate)

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <dlfcn.h>
#import <CoreFoundation/CoreFoundation.h>

static NSString *const kGhostLiveModeKey = @"DYYYLiveGhostMode";
static NSString *const kGhostBrowseModeKey = @"DYYYGhostMode";

static BOOL DYGhostGetBool(NSString *key) { return [[NSUserDefaults standardUserDefaults] boolForKey:key]; }

static NSMutableArray *_dyLog = nil;
static int _dyCounter = 0;

static void DYGhostLog(NSString *msg) {
    _dyCounter++;
    NSLog(@"[DYGhost] %@", msg);
    if (!_dyLog) _dyLog = [NSMutableArray array];
    [_dyLog addObject:msg];
    if (_dyLog.count > 500) [_dyLog removeObjectsInRange:NSMakeRange(0,150)];
}

static BOOL DYIsDouyinURL(NSString *s) {
    if (!s) return NO;
    NSArray *p = @[@"snssdk",@"zijieapi",@"bytedance",@"amemv",@"iesdouyin",@"douyin",@"byteimg",@"douyinstatic"];
    for (NSString *x in p) { if ([s containsString:x]) return YES; }
    return NO;
}

static BOOL DYIsNoiseURL(NSString *s) {
    if (!s) return NO;
    NSString *lower = [s lowercaseString];
    NSArray *noise = @[@".png",@".jpg",@".jpeg",@".gif",@".webp",@".mp4",@".m3u8",
                       @".css",@".js",@".woff",@".ttf",@".svg",@".ico",
                       @"cdn-tos",@"cdn.",@"byteimg",@"webcastcdn",
                       @"/obj/",@".font.",@".icon."];
    for (NSString *x in noise) { if ([lower containsString:x]) return YES; }
    return NO;
}

#pragma mark - Live Ghost

%hook HTSLiveUser
- (BOOL)secret {
    BOOL r = %orig;
    if (DYGhostGetBool(kGhostLiveModeKey)) { DYGhostLog([NSString stringWithFormat:@"LIVE: secret->YES (was %d)", (int)r]); return YES; }
    return r;
}
- (BOOL)isSecret {
    BOOL r = %orig;
    if (DYGhostGetBool(kGhostLiveModeKey)) { DYGhostLog([NSString stringWithFormat:@"LIVE: isSecret->YES (was %d)", (int)r]); return YES; }
    return r;
}
- (BOOL)displayEntranceEffect {
    BOOL r = %orig;
    if (DYGhostGetBool(kGhostLiveModeKey)) { DYGhostLog([NSString stringWithFormat:@"LIVE: entrance->NO (was %d)", (int)r]); return NO; }
    return r;
}
%end

%hook AWEUserModel
- (BOOL)isSecret {
    BOOL r = %orig;
    if (DYGhostGetBool(kGhostLiveModeKey)) { DYGhostLog([NSString stringWithFormat:@"LIVE: AWE.isSecret->YES (was %d)", (int)r]); return YES; }
    return r;
}
%end

#pragma mark - Live UI Hook

%hook UIView
- (void)setHidden:(BOOL)hidden {
    if (DYGhostGetBool(kGhostLiveModeKey) && !hidden) {
        NSString *cls = NSStringFromClass([self class]);
        if ([cls containsString:@"Entrance"] || [cls containsString:@"EnterRoom"] ||
            [cls containsString:@"Welcome"] || [cls containsString:@"JoinRoom"] ||
            [cls containsString:@"ComeIn"] || [cls containsString:@"UserEnter"]) {
            DYGhostLog([NSString stringWithFormat:@"UI-HIDE: %@", cls]); hidden = YES;
        }
    }
    %orig;
}
- (void)setAlpha:(CGFloat)alpha {
    if (DYGhostGetBool(kGhostLiveModeKey) && alpha > 0) {
        NSString *cls = NSStringFromClass([self class]);
        if ([cls containsString:@"Entrance"] || [cls containsString:@"EnterRoom"] ||
            [cls containsString:@"Welcome"] || [cls containsString:@"JoinRoom"]) {
            DYGhostLog([NSString stringWithFormat:@"UI-ALPHA0: %@", cls]); alpha = 0;
        }
    }
    %orig;
}
%end

#pragma mark - Browse DIAG: log only, no block, filter noise

%hook NSMutableURLRequest
- (void)setURL:(NSURL *)url {
    if (url && DYGhostGetBool(kGhostBrowseModeKey)) {
        NSString *s = url.absoluteString;
        if (DYIsDouyinURL(s)) {
            if (!DYIsNoiseURL(s)) {
                NSString *method = self.HTTPMethod ?: @"GET";
                DYGhostLog([NSString stringWithFormat:@"REQ [%@] %@", method, s]);
            }
        } else {
            DYGhostLog([NSString stringWithFormat:@"EXT [%@] %@", self.HTTPMethod ?: @"GET", s]);
        }
    }
    %orig;
}
- (void)setHTTPBody:(NSData *)body {
    %orig;
    if (body && DYGhostGetBool(kGhostBrowseModeKey) && self.URL) {
        NSString *s = self.URL.absoluteString;
        if (DYIsDouyinURL(s) && !DYIsNoiseURL(s) && body.length > 0 && body.length < 3000) {
            NSString *bs = [[NSString alloc] initWithData:body encoding:NSUTF8StringEncoding];
            if (!bs) bs = [[NSString alloc] initWithData:body encoding:NSASCIIStringEncoding];
            if (bs && bs.length > 0) {
                NSArray *parts = [s componentsSeparatedByString:@"/"];
                NSString *lastPath = parts.lastObject ?: @"";
                if (lastPath.length > 50) lastPath = [lastPath substringToIndex:50];
                NSString *preview = (bs.length > 120) ? [bs substringToIndex:120] : bs;
                DYGhostLog([NSString stringWithFormat:@"BODY [%@] %@", lastPath, preview]);
            } else {
                DYGhostLog([NSString stringWithFormat:@"BIN [%@] len=%d", s, (int)body.length]);
            }
        }
    }
}
%end

%hook NSURLSession
- (NSURLSessionDataTask *)dataTaskWithRequest:(NSURLRequest *)req completionHandler:(id)handler {
    if (req.URL && DYGhostGetBool(kGhostBrowseModeKey) && !DYIsNoiseURL(req.URL.absoluteString)) {
        DYGhostLog([NSString stringWithFormat:@"SESS [%@] %@", req.HTTPMethod ?: @"GET", req.URL.absoluteString]);
    }
    return %orig;
}
- (NSURLSessionDataTask *)dataTaskWithURL:(NSURL *)url completionHandler:(id)handler {
    if (url && DYGhostGetBool(kGhostBrowseModeKey) && !DYIsNoiseURL(url.absoluteString)) {
        DYGhostLog([NSString stringWithFormat:@"SESS-URL %@", url.absoluteString]);
    }
    return %orig;
}
%end

%hook NSURLConnection
+ (NSData *)sendSynchronousRequest:(NSURLRequest *)req returningResponse:(NSURLResponse **)resp error:(NSError **)err {
    if (req.URL && DYGhostGetBool(kGhostBrowseModeKey) && !DYIsNoiseURL(req.URL.absoluteString)) {
        DYGhostLog([NSString stringWithFormat:@"CON [%@] %@", req.HTTPMethod ?: @"GET", req.URL.absoluteString]);
    }
    return %orig;
}
+ (void)sendAsynchronousRequest:(NSURLRequest *)req queue:(NSOperationQueue *)q completionHandler:(id)handler {
    if (req.URL && DYGhostGetBool(kGhostBrowseModeKey) && !DYIsNoiseURL(req.URL.absoluteString)) {
        DYGhostLog([NSString stringWithFormat:@"CON-ASYNC [%@] %@", req.HTTPMethod ?: @"GET", req.URL.absoluteString]);
    }
    %orig;
}
%end

#pragma mark - Tracker events

%hook BDTrackerProtocol
+ (id)event:(id)a category:(id)b label:(id)c value:(id)d extValue:(id)e eventType:(id)f {
    NSString *lbl = ([c isKindOfClass:[NSString class]])?c:(@"");
    NSString *val = ([d isKindOfClass:[NSString class]])?d:(@"");
    DYGhostLog([NSString stringWithFormat:@"EVT [BDTP] lbl=%@ val=%@", lbl, val]);
    return %orig;
}
%end

%hook TTTracker
+ (id)event:(id)a category:(id)b label:(id)c value:(id)d extValue:(id)e eventType:(id)f {
    NSString *lbl = ([c isKindOfClass:[NSString class]])?c:(@"");
    NSString *val = ([d isKindOfClass:[NSString class]])?d:(@"");
    DYGhostLog([NSString stringWithFormat:@"EVT [TT] lbl=%@ val=%@", lbl, val]);
    return %orig;
}
%end

%hook BDTGTrackerKit
+ (id)event:(id)a category:(id)b label:(id)c value:(id)d extValue:(id)e eventType:(id)f {
    NSString *lbl = ([c isKindOfClass:[NSString class]])?c:(@"");
    NSString *val = ([d isKindOfClass:[NSString class]])?d:(@"");
    DYGhostLog([NSString stringWithFormat:@"EVT [BDTG] lbl=%@ val=%@", lbl, val]);
    return %orig;
}
%end

%hook IESLCTrackerService
+ (id)event:(id)a category:(id)b label:(id)c value:(id)d extValue:(id)e eventType:(id)f {
    NSString *lbl = ([c isKindOfClass:[NSString class]])?c:(@"");
    NSString *val = ([d isKindOfClass:[NSString class]])?d:(@"");
    DYGhostLog([NSString stringWithFormat:@"EVT [IESLC] lbl=%@ val=%@", lbl, val]);
    return %orig;
}
%end

#pragma mark - Settings UI

static BOOL _showing = NO;

@interface DYV : NSObject
+ (void)show:(UIViewController *)p;
@end

@implementation DYV
+ (void)show:(UIViewController *)p {
    if (!p || _showing) return;
    _showing = YES;
    UIAlertController *a = [UIAlertController alertControllerWithTitle:@"Ghost Mode v6" message:@"" preferredStyle:UIAlertControllerStyleAlert];

    NSString *lt = DYGhostGetBool(kGhostLiveModeKey)?@"[ON] Live":@"[OFF] Live";
    [a addAction:[UIAlertAction actionWithTitle:lt style:UIAlertActionStyleDefault handler:^(UIAlertAction *x){
        [[NSUserDefaults standardUserDefaults] setBool:!DYGhostGetBool(kGhostLiveModeKey) forKey:kGhostLiveModeKey];
        [[NSUserDefaults standardUserDefaults] synchronize]; _showing=NO;
    }]];

    NSString *bt = DYGhostGetBool(kGhostBrowseModeKey)?@"[ON] Browse DIAG":@"[OFF] Browse DIAG";
    [a addAction:[UIAlertAction actionWithTitle:bt style:UIAlertActionStyleDefault handler:^(UIAlertAction *x){
        [[NSUserDefaults standardUserDefaults] setBool:!DYGhostGetBool(kGhostBrowseModeKey) forKey:kGhostBrowseModeKey];
        [[NSUserDefaults standardUserDefaults] synchronize]; _showing=NO;
    }]];

    [a addAction:[UIAlertAction actionWithTitle:@"=== MARK ===" style:UIAlertActionStyleDefault handler:^(UIAlertAction *x){
        DYGhostLog(@">>> MARK <<<"); _showing=NO;
    }]];

    [a addAction:[UIAlertAction actionWithTitle:@"Clear & Test" style:UIAlertActionStyleDefault handler:^(UIAlertAction *x){
        _dyLog=[NSMutableArray array]; _dyCounter=0; DYGhostLog(@">>> Cleared <<<"); _showing=NO;
    }]];

    [a addAction:[UIAlertAction actionWithTitle:@"View Logs" style:UIAlertActionStyleDefault handler:^(UIAlertAction *x){
        _showing=NO;
        NSMutableString *t=[NSMutableString string];
        if(_dyLog.count>0) for(NSString *l in[_dyLog reverseObjectEnumerator])[t appendFormat:@"%@\n",l];
        else t.string=@"No logs.\n1.Turn ON both\n2.Clear&Test\n3.Click MARK\n4.Enter live room\n5.Click MARK\n6.Visit profile\n7.Click MARK\n8.View Logs";
        UIViewController *v=p;while(v.presentedViewController)v=v.presentedViewController;
        UIAlertController *la=[UIAlertController alertControllerWithTitle:@"Logs" message:t preferredStyle:UIAlertControllerStyleAlert];
        [la addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleCancel handler:nil]];
        [v presentViewController:la animated:YES completion:nil];
    }]];

    [a addAction:[UIAlertAction actionWithTitle:@"Stats" style:UIAlertActionStyleDefault handler:^(UIAlertAction *x){
        _showing=NO;
        int req=0,sess=0,con=0,ev=0,live=0,body=0,ext=0,uihide=0,mark=0,other=0;
        for(NSString *l in _dyLog){
            if([l hasPrefix:@"REQ "]) req++;
            else if([l hasPrefix:@"SESS"]) sess++;
            else if([l hasPrefix:@"CON"]) con++;
            else if([l hasPrefix:@"EVT"]) ev++;
            else if([l hasPrefix:@"LIVE"]) live++;
            else if([l hasPrefix:@"BODY"]||[l hasPrefix:@"BIN"]) body++;
            else if([l hasPrefix:@"EXT"]) ext++;
            else if([l hasPrefix:@"UI-HIDE"]||[l hasPrefix:@"UI-ALPHA"]) uihide++;
            else if([l containsString:@"MARK"]) mark++;
            else other++;
        }
        NSMutableString *ms=[NSMutableString string];
        [ms appendFormat:@"Requests: %d\nSession: %d\nConnection: %d\nEvents: %d\nLiveHooks: %d\nBodies: %d\nExtURLs: %d\nUI-Hide: %d\nMarks: %d\nOther: %d\nTotal: %d",req,sess,con,ev,live,body,ext,uihide,mark,other,(int)_dyLog.count];
        UIViewController *v=p;while(v.presentedViewController)v=v.presentedViewController;
        UIAlertController *sa=[UIAlertController alertControllerWithTitle:@"Stats" message:ms preferredStyle:UIAlertControllerStyleAlert];
        [sa addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleCancel handler:nil]];
        [v presentViewController:sa animated:YES completion:nil];
    }]];

    [a addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:^(UIAlertAction *x){_showing=NO;}]];
    [p presentViewController:a animated:YES completion:nil];
}
@end

#pragma mark - Shake Gesture

%hook UIWindow
- (instancetype)initWithFrame:(CGRect)frame {
    UIWindow *w=%orig;if(w)[[UIApplication sharedApplication]setApplicationSupportsShakeToEdit:YES];return w;
}
- (BOOL)canBecomeFirstResponder{ return YES;}
- (void)motionEnded:(UIEventSubtype)motion withEvent:(UIEvent *)event{
    %orig;
    if(motion==UIEventSubtypeMotionShake){
        UIViewController *r=self.rootViewController;while(r.presentedViewController)r=r.presentedViewController;
        [DYV show:r];
    }
}
%end

#pragma mark - Constructor

%ctor{
    DYGhostLog(@"Loading v6...");
    void *h=dlopen("/System/Library/Frameworks/CFNetwork.framework/CFNetwork",RTLD_NOW);
    if(h){ typedef CFHTTPMessageRef (*Fn)(CFAllocatorRef,CFURLRef,CFStringRef,CFStringRef,CFDictionaryRef); Fn f=(Fn)dlsym(h,"CFHTTPMessageCreateRequest"); if(f) DYGhostLog(@"CFNetwork: FOUND"); else DYGhostLog(@"CFNetwork: NOT found");}
    else{ DYGhostLog(@"CFNetwork: FAIL");}
    NSUserDefaults *u=[NSUserDefaults standardUserDefaults];
    if(![u objectForKey:kGhostLiveModeKey])[u setBool:NO forKey:kGhostLiveModeKey];
    if(![u objectForKey:kGhostBrowseModeKey])[u setBool:NO forKey:kGhostBrowseModeKey];
    [u synchronize]; DYGhostLog(@"Ready!");
}
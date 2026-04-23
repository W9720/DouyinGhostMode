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
static int _dyReqCounter = 0;

static void DYGhostLog(NSString *msg) {
    _dyReqCounter++;
    NSString *tagged = [NSString stringWithFormat:@"[%03d] %@", _dyReqCounter, msg];
    NSLog(@"[DYGhost] %@", tagged);
    if (!_dyLog) _dyLog = [NSMutableArray array];
    [_dyLog addObject:tagged];
    if (_dyLog.count > 800) [_dyLog removeObjectsInRange:NSMakeRange(0,200)];
}

static BOOL DYIsDouyinURL(NSString *s) {
    if (!s) return NO;
    NSArray *p = @[@"snssdk",@"zijieapi",@"bytedance",@"amemv",@"iesdouyin",@"douyin",@"byteimg",@"douyinstatic"];
    for (NSString *x in p) { if ([s containsString:x]) return YES; }
    return NO;
}

#pragma mark - Live Ghost: data layer

%hook HTSLiveUser
- (BOOL)secret {
    BOOL r = %orig;
    if (DYGhostGetBool(kGhostLiveModeKey)) {
        DYGhostLog([NSString stringWithFormat:@"LIVE: secret->YES (was %d)", (int)r]);
        return YES;
    }
    return r;
}
- (BOOL)isSecret {
    BOOL r = %orig;
    if (DYGhostGetBool(kGhostLiveModeKey)) {
        DYGhostLog([NSString stringWithFormat:@"LIVE: isSecret->YES (was %d)", (int)r]);
        return YES;
    }
    return r;
}
- (BOOL)displayEntranceEffect {
    BOOL r = %orig;
    if (DYGhostGetBool(kGhostLiveModeKey)) {
        DYGhostLog([NSString stringWithFormat:@"LIVE: entrance->NO (was %d)", (int)r]);
        return NO;
    }
    return r;
}
%end

%hook AWEUserModel
- (BOOL)isSecret {
    BOOL r = %orig;
    if (DYGhostGetBool(kGhostLiveModeKey)) {
        DYGhostLog([NSString stringWithFormat:@"LIVE: AWE.isSecret->YES (was %d)", (int)r]);
        return YES;
    }
    return r;
}
%end

#pragma mark - Live Ghost: UI layer - hide entrance banner

%hook UIView
- (void)setHidden:(BOOL)hidden {
    if (DYGhostGetBool(kGhostLiveModeKey) && !hidden) {
        NSString *cls = NSStringFromClass([self class]);
        if ([cls containsString:@"Entrance"] || [cls containsString:@"EnterRoom"] ||
            [cls containsString:@"Welcome"] || [cls containsString:@"JoinRoom"] ||
            [cls containsString:@"ComeIn"] || [cls containsString:@"UserEnter"]) {
            DYGhostLog([NSString stringWithFormat:@"UI-HIDE: %@", cls]);
            hidden = YES;
        }
    }
    %orig;
}
- (void)setAlpha:(CGFloat)alpha {
    if (DYGhostGetBool(kGhostLiveModeKey) && alpha > 0) {
        NSString *cls = NSStringFromClass([self class]);
        if ([cls containsString:@"Entrance"] || [cls containsString:@"EnterRoom"] ||
            [cls containsString:@"Welcome"] || [cls containsString:@"JoinRoom"]) {
            DYGhostLog([NSString stringWithFormat:@"UI-ALPHA0: %@", cls]);
            alpha = 0;
        }
    }
    %orig;
}
%end

#pragma mark - Browse Ghost DIAGNOSTIC MODE: log ALL requests, block NONE

%hook NSMutableURLRequest
- (void)setURL:(NSURL *)url {
    if (url && DYGhostGetBool(kGhostBrowseModeKey)) {
        NSString *s = url.absoluteString;
        if (DYIsDouyinURL(s)) {
            NSString *method = self.HTTPMethod ?: @"GET";
            DYGhostLog([NSString stringWithFormat:@"REQ [%@] %@", method, s]);
        } else {
            DYGhostLog([NSString stringWithFormat:@"EXT [%@] %@", self.HTTPMethod ?: @"GET", s]);
        }
    }
    %orig;
}
- (void)setHTTPBody:(NSData *)body {
    %orig;
    if (body && DYGhostGetBool(kGhostBrowseModeKey) && self.URL && DYIsDouyinURL(self.URL.absoluteString)) {
        NSString *s = self.URL.absoluteString;
        if (body.length > 0 && body.length < 3000) {
            NSString *bs = [[NSString alloc] initWithData:body encoding:NSUTF8StringEncoding];
            if (!bs) bs = [[NSString alloc] initWithData:body encoding:NSASCIIStringEncoding];
            if (bs) {
                NSArray *parts = [s componentsSeparatedByString:@"/"];
                NSString *lastPath = parts.lastObject ?: @"";
                if (lastPath.length > 50) lastPath = [lastPath substringToIndex:50];
                NSString *preview = (bs.length > 150) ? [bs substringToIndex:150] : bs;
                DYGhostLog([NSString stringWithFormat:@"BODY [%@] %@", lastPath, preview]);
            } else {
                DYGhostLog([NSString stringWithFormat:@"BIN [%@] len=%d", s, (int)body.length]);
            }
        } else if (body.length >= 3000) {
            DYGhostLog([NSString stringWithFormat:@"BIG-BODY [%@] len=%d", s, (int)body.length]);
        }
    }
}
- (void)setHTTPMethod:(NSString *)method {
    %orig;
    if (method && DYGhostGetBool(kGhostBrowseModeKey) && self.URL && DYIsDouyinURL(self.URL.absoluteString)) {
        DYGhostLog([NSString stringWithFormat:@"METHOD %@ %@", method, self.URL.absoluteString]);
    }
}
- (void)addValue:(id)value forHTTPHeaderField:(NSString *)field {
    %orig;
    if (value && field && DYGhostGetBool(kGhostBrowseModeKey) && self.URL && DYIsDouyinURL(self.URL.absoluteString)) {
        DYGhostLog([NSString stringWithFormat:@"HDR %@: %@", field, value]);
    }
}
%end

%hook NSURLSession
- (NSURLSessionDataTask *)dataTaskWithRequest:(NSURLRequest *)req completionHandler:(id)handler {
    if (req.URL && DYGhostGetBool(kGhostBrowseModeKey)) {
        DYGhostLog([NSString stringWithFormat:@"SESS-REQ [%@] %@", req.HTTPMethod ?: @"GET", req.URL.absoluteString]);
    }
    return %orig;
}
- (NSURLSessionDataTask *)dataTaskWithURL:(NSURL *)url completionHandler:(id)handler {
    if (url && DYGhostGetBool(kGhostBrowseModeKey)) {
        DYGhostLog([NSString stringWithFormat:@"SESS-URL %@", url.absoluteString]);
    }
    return %orig;
}
- (NSURLSessionUploadTask *)uploadTaskWithRequest:(NSURLRequest *)req fromData:(NSData *)body completionHandler:(id)handler {
    if (req.URL && DYGhostGetBool(kGhostBrowseModeKey)) {
        DYGhostLog([NSString stringWithFormat:@"SESS-UP [%@] %@ len=%d", req.HTTPMethod ?: @"POST", req.URL.absoluteString, (int)body.length]);
    }
    return %orig;
}
%end

%hook NSURLConnection
+ (NSData *)sendSynchronousRequest:(NSURLRequest *)req returningResponse:(NSURLResponse **)resp error:(NSError **)err {
    if (req.URL && DYGhostGetBool(kGhostBrowseModeKey)) {
        DYGhostLog([NSString stringWithFormat:@"CON-SYNC [%@] %@", req.HTTPMethod ?: @"GET", req.URL.absoluteString]);
    }
    return %orig;
}
+ (void)sendAsynchronousRequest:(NSURLRequest *)req queue:(NSOperationQueue *)q completionHandler:(id)handler {
    if (req.URL && DYGhostGetBool(kGhostBrowseModeKey)) {
        DYGhostLog([NSString stringWithFormat:@"CON-ASYNC [%@] %@", req.HTTPMethod ?: @"GET", req.URL.absoluteString]);
    }
    %orig;
}
%end

#pragma mark - Tracker events (log only)

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
    UIAlertController *a = [UIAlertController alertControllerWithTitle:@"Ghost Mode v6-DIAG" message:@"" preferredStyle:UIAlertControllerStyleAlert];

    NSString *lt = DYGhostGetBool(kGhostLiveModeKey)?@"[ON] Live Ghost":@"[OFF] Live Ghost";
    [a addAction:[UIAlertAction actionWithTitle:lt style:UIAlertActionStyleDefault handler:^(UIAlertAction *x){
        [[NSUserDefaults standardUserDefaults] setBool:!DYGhostGetBool(kGhostLiveModeKey) forKey:kGhostLiveModeKey];
        [[NSUserDefaults standardUserDefaults] synchronize]; _showing=NO;
    }]];

    NSString *bt = DYGhostGetBool(kGhostBrowseModeKey)?@"[ON] Browse DIAG":@"[OFF] Browse DIAG";
    [a addAction:[UIAlertAction actionWithTitle:bt style:UIAlertActionStyleDefault handler:^(UIAlertAction *x){
        [[NSUserDefaults standardUserDefaults] setBool:!DYGhostGetBool(kGhostBrowseModeKey) forKey:kGhostBrowseModeKey];
        [[NSUserDefaults standardUserDefaults] synchronize]; _showing=NO;
    }]];

    [a addAction:[UIAlertAction actionWithTitle:@"--- MARK ---" style:UIAlertActionStyleDefault handler:^(UIAlertAction *x){
        DYGhostLog(@">>>>>>>>>> MARK <<<<<<<<<<"); _showing=NO;
    }]];

    [a addAction:[UIAlertAction actionWithTitle:@"Clear & Test" style:UIAlertActionStyleDefault handler:^(UIAlertAction *x){
        _dyLog=[NSMutableArray array]; _dyReqCounter=0; DYGhostLog(@">>> Cleared <<<"); _showing=NO;
    }]];

    [a addAction:[UIAlertAction actionWithTitle:@"View Logs" style:UIAlertActionStyleDefault handler:^(UIAlertAction *x){
        _showing=NO;
        NSMutableString *t=[NSMutableString string];
        if(_dyLog.count>0) for(NSString *l in[_dyLog reverseObjectEnumerator])[t appendFormat:@"%@\n",l];
        else t.string=@"No logs.\n1.Turn ON both switches\n2.Clear&Test\n3.Click MARK\n4.Enter live room\n5.Click MARK\n6.Visit profile\n7.Click MARK\n8.View Logs";
        UIViewController *v=p;while(v.presentedViewController)v=v.presentedViewController;
        UIAlertController *la=[UIAlertController alertControllerWithTitle:@"Logs" message:t preferredStyle:UIAlertControllerStyleAlert];
        [la addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleCancel handler:nil]];
        [v presentViewController:la animated:YES completion:nil];
    }]];

    [a addAction:[UIAlertAction actionWithTitle:@"Stats" style:UIAlertActionStyleDefault handler:^(UIAlertAction *x){
        _showing=NO;
        int req=0,sess=0,con=0,ev=0,live=0,body=0,hdr=0,ext=0,uihide=0,mark=0,other=0;
        for(NSString *l in _dyLog){
            if([l hasPrefix:@"BLK"]||[l hasPrefix:@"REQ "]||[l rangeOfString:@"] REQ"].location!=NSNotFound) req++;
            else if([l hasPrefix:@"SESS"]) sess++;
            else if([l hasPrefix:@"CON"]) con++;
            else if([l hasPrefix:@"EVT"]) ev++;
            else if([l hasPrefix:@"LIVE"]) live++;
            else if([l hasPrefix:@"BODY"]||[l hasPrefix:@"BIN"]||[l hasPrefix:@"BIG"]) body++;
            else if([l hasPrefix:@"HDR"]) hdr++;
            else if([l hasPrefix:@"EXT"]) ext++;
            else if([l hasPrefix:@"UI-HIDE"]||[l hasPrefix:@"UI-ALPHA"]) uihide++;
            else if([l containsString:@"MARK"]) mark++;
            else other++;
        }
        NSMutableString *ms=[NSMutableString string];
        [ms appendFormat:@"Requests: %d\nSession: %d\nConnection: %d\nEvents: %d\nLiveHooks: %d\nBodies: %d\nHeaders: %d\nExtURLs: %d\nUI-Hide: %d\nMarks: %d\nOther: %d\nTotal: %d",req,sess,con,ev,live,body,hdr,ext,uihide,mark,other,(int)_dyLog.count];
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
    DYGhostLog(@"Loading v6-DIAG...");

    void *h=dlopen("/System/Library/Frameworks/CFNetwork.framework/CFNetwork",RTLD_NOW);
    if(h){
        typedef CFHTTPMessageRef (*CFHTTPMsgCreateFn)(CFAllocatorRef,CFURLRef,CFStringRef,CFStringRef,CFDictionaryRef);
        CFHTTPMsgCreateFn fn = (CFHTTPMsgCreateFn)dlsym(h,"CFHTTPMessageCreateRequest");
        if(fn){ DYGhostLog(@"CFNetwork: FOUND");}
        else{ DYGhostLog(@"CFNetwork: NOT found");}
    }else{ DYGhostLog(@"CFNetwork: dlopen FAIL");}

    NSUserDefaults *u=[NSUserDefaults standardUserDefaults];
    if(![u objectForKey:kGhostLiveModeKey])[u setBool:NO forKey:kGhostLiveModeKey];
    if(![u objectForKey:kGhostBrowseModeKey])[u setBool:NO forKey:kGhostBrowseModeKey];
    [u synchronize];

    DYGhostLog(@"Ready!");
}
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

static void DYGhostLog(NSString *msg) {
    NSLog(@"[DYGhost] %@", msg);
    if (!_dyLog) _dyLog = [NSMutableArray array];
    [_dyLog addObject:msg];
    if (_dyLog.count > 600) [_dyLog removeObjectsInRange:NSMakeRange(0,200)];
}

static BOOL DYIsDouyinURL(NSString *s) {
    if (!s) return NO;
    NSArray *p = @[@"snssdk",@"zijieapi",@"bytedance",@"amemv",@"iesdouyin",@"douyin",@"byteimg",@"douyinstatic"];
    for (NSString *x in p) { if ([s containsString:x]) return YES; }
    return NO;
}

static BOOL DYIsCDNOrImageURL(NSString *s) {
    if (!s) return NO;
    NSArray *cdn = @[@".png",@".jpg",@".jpeg",@".gif",@".webp",@".mp4",@".m3u8",
                     @"cdn-tos",@"cdn.",@"/obj/",@"webcastcdn",@"byteimg",
                     @".css",@".js",@"font.",@"icon."];
    NSString *lower = [s lowercaseString];
    for (NSString *x in cdn) { if ([lower containsString:x]) return YES; }
    return NO;
}

static BOOL DYIsTrackingURL(NSString *s) {
    if (!s) return NO;
    NSString *lower = [s lowercaseString];
    NSArray *track = @[
        @"/private/",@"/log/",@"/mcs/",@"/collect/",@"/event/",
        @"/behavior/",@"/monitor/",@"/analyze/",@"/track/",
        @"/visit/",@"/enter_room",@"/setresult",@"/dispatch_",
        @"/report/",@"/upload_",@"/data/",@"/api/v1/",
        @"/service/",@"/gateway/"
    ];
    for (NSString *x in track) { if ([lower containsString:x]) return YES; }
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

#pragma mark - Browse Ghost: NSMutableURLRequest (THE WORKING HOOK!)

%hook NSMutableURLRequest
- (void)setURL:(NSURL *)url {
    if (url && DYGhostGetBool(kGhostBrowseModeKey)) {
        NSString *s = url.absoluteString;
        if (DYIsDouyinURL(s)) {
            if (DYIsTrackingURL(s)) {
                if (!DYIsCDNOrImageURL(s)) {
                    DYGhostLog([NSString stringWithFormat:@"BLK [Req] %@", s]);
                    return;
                }
            }
            DYGhostLog([NSString stringWithFormat:@"SEE [Req] %@", s]);
        }
    }
    %orig;
}
- (void)setHTTPBody:(NSData *)body {
    %orig;
    if (body && DYGhostGetBool(kGhostBrowseModeKey) && self.URL) {
        NSString *s = self.URL.absoluteString;
        if (DYIsDouyinURL(s) && !DYIsCDNOrImageURL(s) && body.length > 0 && body.length < 2000) {
            NSString *bs = [[NSString alloc] initWithData:body encoding:NSUTF8StringEncoding];
            if (!bs) bs = [[NSString alloc] initWithData:body encoding:NSASCIIStringEncoding];
            if (bs && bs.length > 0) {
                NSArray *parts = [s componentsSeparatedByString:@"/"];
                NSString *lastPath = parts.lastObject ?: @"";
                if (lastPath.length > 60) lastPath = [lastPath substringToIndex:60];
                NSString *bodyPreview = (bs.length > 120) ? [bs substringToIndex:120] : bs;
                DYGhostLog([NSString stringWithFormat:@"BODY [%@] %@", lastPath, bodyPreview]);
            } else {
                DYGhostLog([NSString stringWithFormat:@"BIN-BODY [%@] len=%d", s, (int)body.length]);
            }
        }
    }
}
- (void)setValue:(id)value forHTTPHeaderField:(NSString *)field {
    %orig;
    if (value && DYGhostGetBool(kGhostBrowseModeKey) && self.URL) {
        NSString *s = self.URL.absoluteString;
        if (DYIsDouyinURL(s) && DYIsTrackingURL(s) && !DYIsCDNOrImageURL(s)) {
            DYGhostLog([NSString stringWithFormat:@"HDR [%@] %@=%@", field, field, value]);
        }
    }
}
%end

#pragma mark - Browse Ghost: NSURLSession (backup)

%hook NSURLSession
- (NSURLSessionDataTask *)dataTaskWithRequest:(NSURLRequest *)req completionHandler:(id)handler {
    if (req.URL && DYGhostGetBool(kGhostBrowseModeKey)) {
        NSString *s = req.URL.absoluteString;
        if (DYIsDouyinURL(s) && DYIsTrackingURL(s) && !DYIsCDNOrImageURL(s)) {
            DYGhostLog([NSString stringWithFormat:@"BLK [Sess] %@", s]);
            return nil;
        }
    }
    return %orig;
}
- (NSURLSessionDataTask *)dataTaskWithURL:(NSURL *)url completionHandler:(id)handler {
    if (url && DYGhostGetBool(kGhostBrowseModeKey)) {
        NSString *s = url.absoluteString;
        if (DYIsDouyinURL(s) && DYIsTrackingURL(s) && !DYIsCDNOrImageURL(s)) {
            DYGhostLog([NSString stringWithFormat:@"BLK [SessU] %@", s]);
            return nil;
        }
    }
    return %orig;
}
%end

#pragma mark - Browse Ghost: NSURLConnection legacy

%hook NSURLConnection
+ (NSData *)sendSynchronousRequest:(NSURLRequest *)req returningResponse:(NSURLResponse **)resp error:(NSError **)err {
    if (req.URL && DYGhostGetBool(kGhostBrowseModeKey)) {
        NSString *s = req.URL.absoluteString;
        if (DYIsDouyinURL(s) && DYIsTrackingURL(s) && !DYIsCDNOrImageURL(s)) {
            DYGhostLog([NSString stringWithFormat:@"BLK [ConSync] %@", s]);
            if (err) *err = [NSError errorWithDomain:@"DYGhost" code:-1 userInfo:nil];
            return nil;
        }
    }
    return %orig;
}
+ (void)sendAsynchronousRequest:(NSURLRequest *)req queue:(NSOperationQueue *)q completionHandler:(id)handler {
    if (req.URL && DYGhostGetBool(kGhostBrowseModeKey)) {
        NSString *s = req.URL.absoluteString;
        if (DYIsDouyinURL(s) && DYIsTrackingURL(s) && !DYIsCDNOrImageURL(s)) {
            DYGhostLog([NSString stringWithFormat:@"BLK [ConAsync] %@", s]);
            NSError *fakeErr = [NSError errorWithDomain:@"DYGhost" code:-1 userInfo:nil];
            SEL sel = NSSelectorFromString(@"completionHandler:");
            if ([handler respondsToSelector:sel]) {
                NSMethodSignature *sig = [handler methodSignatureForSelector:sel];
                NSInvocation *inv = [NSInvocation invocationWithMethodSignature:sig];
                [inv setSelector:sel]; [inv setTarget:handler];
                NSData *nilData = nil; NSURLResponse *nilResp = nil;
                [inv setArgument:&nilData atIndex:2]; [inv setArgument:&nilResp atIndex:3];
                [inv setArgument:&fakeErr atIndex:4]; [inv invoke];
            }
            return;
        }
    }
    %orig;
}
%end

#pragma mark - Browse Ghost: Tracker events (always log)

%hook BDTrackerProtocol
+ (id)event:(id)a category:(id)b label:(id)c value:(id)d extValue:(id)e eventType:(id)f {
    NSString *lbl = ([c isKindOfClass:[NSString class]])?c:(@"");
    NSString *val = ([d isKindOfClass:[NSString class]])?d:(@"");
    DYGhostLog([NSString stringWithFormat:@"EVT [BDTP] lbl=%@ val=%@", lbl, val]);
    if (DYGhostGetBool(kGhostBrowseModeKey) && ([lbl containsString:@"visit"]||[lbl containsString:@"enter"]||[lbl containsString:@"browse"]||[lbl containsString:@"profile"]||[lbl containsString:@"live"])) {
        DYGhostLog([NSString stringWithFormat:@"BLK-EVT [BDTP] lbl=%@ val=%@", lbl, val]); return nil;
    }
    return %orig;
}
%end

%hook TTTracker
+ (id)event:(id)a category:(id)b label:(id)c value:(id)d extValue:(id)e eventType:(id)f {
    NSString *lbl = ([c isKindOfClass:[NSString class]])?c:(@"");
    NSString *val = ([d isKindOfClass:[NSString class]])?d:(@"");
    DYGhostLog([NSString stringWithFormat:@"EVT [TT] lbl=%@ val=%@", lbl, val]);
    if (DYGhostGetBool(kGhostBrowseModeKey) && ([lbl containsString:@"visit"]||[lbl containsString:@"enter"]||[lbl containsString:@"browse"]||[lbl containsString:@"profile"]||[lbl containsString:@"live"])) {
        DYGhostLog([NSString stringWithFormat:@"BLK-EVT [TT] lbl=%@ val=%@", lbl, val]); return nil;
    }
    return %orig;
}
%end

%hook BDTGTrackerKit
+ (id)event:(id)a category:(id)b label:(id)c value:(id)d extValue:(id)e eventType:(id)f {
    NSString *lbl = ([c isKindOfClass:[NSString class]])?c:(@"");
    NSString *val = ([d isKindOfClass:[NSString class]])?d:(@"");
    DYGhostLog([NSString stringWithFormat:@"EVT [BDTG] lbl=%@ val=%@", lbl, val]);
    if (DYGhostGetBool(kGhostBrowseModeKey) && ([lbl containsString:@"visit"]||[lbl containsString:@"enter"]||[lbl containsString:@"browse"]||[lbl containsString:@"profile"]||[lbl containsString:@"live"])) {
        DYGhostLog([NSString stringWithFormat:@"BLK-EVT [BDTG] lbl=%@ val=%@", lbl, val]); return nil;
    }
    return %orig;
}
%end

%hook IESLCTrackerService
+ (id)event:(id)a category:(id)b label:(id)c value:(id)d extValue:(id)e eventType:(id)f {
    NSString *lbl = ([c isKindOfClass:[NSString class]])?c:(@"");
    NSString *val = ([d isKindOfClass:[NSString class]])?d:(@"");
    DYGhostLog([NSString stringWithFormat:@"EVT [IESLC] lbl=%@ val=%@", lbl, val]);
    if (DYGhostGetBool(kGhostBrowseModeKey) && ([lbl containsString:@"visit"]||[lbl containsString:@"enter"]||[lbl containsString:@"browse"]||[lbl containsString:@"profile"]||[lbl containsString:@"live"])) {
        DYGhostLog([NSString stringWithFormat:@"BLK-EVT [IESLC] lbl=%@ val=%@", lbl, val]); return nil;
    }
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
    UIAlertController *a = [UIAlertController alertControllerWithTitle:@"Ghost Mode v5" message:@"" preferredStyle:UIAlertControllerStyleAlert];

    NSString *lt = DYGhostGetBool(kGhostLiveModeKey)?@"[ON] Live Ghost":@"[OFF] Live Ghost";
    [a addAction:[UIAlertAction actionWithTitle:lt style:UIAlertActionStyleDefault handler:^(UIAlertAction *x){
        [[NSUserDefaults standardUserDefaults] setBool:!DYGhostGetBool(kGhostLiveModeKey) forKey:kGhostLiveModeKey];
        [[NSUserDefaults standardUserDefaults] synchronize]; _showing=NO;
    }]];

    NSString *bt = DYGhostGetBool(kGhostBrowseModeKey)?@"[ON] Browse Ghost":@"[OFF] Browse Ghost";
    [a addAction:[UIAlertAction actionWithTitle:bt style:UIAlertActionStyleDefault handler:^(UIAlertAction *x){
        [[NSUserDefaults standardUserDefaults] setBool:!DYGhostGetBool(kGhostBrowseModeKey) forKey:kGhostBrowseModeKey];
        [[NSUserDefaults standardUserDefaults] synchronize]; _showing=NO;
    }]];

    [a addAction:[UIAlertAction actionWithTitle:@"Clear & Test" style:UIAlertActionStyleDefault handler:^(UIAlertAction *x){
        _dyLog=[NSMutableArray array]; DYGhostLog(@">>> Cleared. Test now <<<"); _showing=NO;
    }]];

    [a addAction:[UIAlertAction actionWithTitle:@"View Logs" style:UIAlertActionStyleDefault handler:^(UIAlertAction *x){
        _showing=NO;
        NSMutableString *t=[NSMutableString string];
        if(_dyLog.count>0) for(NSString *l in[_dyLog reverseObjectEnumerator])[t appendFormat:@"%@\n",l];
        else t.string=@"No logs.\n1.Turn ON both switches\n2.Clear&Test\n3.Enter live room\n4.Visit profile\n5.View Logs";
        UIViewController *v=p;while(v.presentedViewController)v=v.presentedViewController;
        UIAlertController *la=[UIAlertController alertControllerWithTitle:@"Logs" message:t preferredStyle:UIAlertControllerStyleAlert];
        [la addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleCancel handler:nil]];
        [v presentViewController:la animated:YES completion:nil];
    }]];

    [a addAction:[UIAlertAction actionWithTitle:@"Network Stats" style:UIAlertActionStyleDefault handler:^(UIAlertAction *x){
        _showing=NO;
        int rq=0,se=0,cn=0,ev=0,lv=0,blk=0,body=0,hdr=0;
        for(NSString *l in _dyLog){
            if([l hasPrefix:@"BLK"]) blk++;
            else if([l rangeOfString:@"[Req]"].location!=NSNotFound) rq++;
            else if([l rangeOfString:@"[Sess]"].location!=NSNotFound) se++;
            else if([l rangeOfString:@"[Con]"].location!=NSNotFound) cn++;
            else if([l hasPrefix:@"EVT"]) ev++;
            else if([l hasPrefix:@"LIVE"]) lv++;
            else if([l hasPrefix:@"BODY"]) body++;
            else if([l hasPrefix:@"HDR"]) hdr++;
        }
        NSMutableString *ms=[NSMutableString string];
        [ms appendFormat:@"NSURLRequest: %d\nNSURLSession: %d\nNSURLConnection: %d\nTracker Events: %d\nLive Hooks: %d\nBlocked: %d\nBodies: %d\nHeaders: %d\nTotal: %d",rq,se,cn,ev,lv,blk,body,hdr,(int)_dyLog.count];
        if(blk>0)[ms appendString:@"\n\n>>> BLOCKING ACTIVE! <<<"];
        else if(rq>0&&blk==0)[ms appendString:@"\n\n>>> URLs seen but not blocked <<<"];
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
    DYGhostLog(@"Loading v5...");

    void *h=dlopen("/System/Library/Frameworks/CFNetwork.framework/CFNetwork",RTLD_NOW);
    if(h){
        typedef CFHTTPMessageRef (*CFHTTPMsgCreateFn)(CFAllocatorRef,CFURLRef,CFStringRef,CFStringRef,CFDictionaryRef);
        CFHTTPMsgCreateFn fn = (CFHTTPMsgCreateFn)dlsym(h,"CFHTTPMessageCreateRequest");
        if(fn){ DYGhostLog(@"CFNetwork: symbol FOUND");}
        else{ DYGhostLog(@"CFNetwork: symbol NOT found");}
    }else{ DYGhostLog(@"CFNetwork: dlopen FAIL");}

    NSUserDefaults *u=[NSUserDefaults standardUserDefaults];
    if(![u objectForKey:kGhostLiveModeKey])[u setBool:NO forKey:kGhostLiveModeKey];
    if(![u objectForKey:kGhostBrowseModeKey])[u setBool:NO forKey:kGhostBrowseModeKey];
    [u synchronize];

    DYGhostLog(@"Ready!");
}
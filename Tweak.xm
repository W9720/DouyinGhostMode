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
    NSArray *p = @[@"snssdk",@"zijieapi",@"bytedance",@"amemv",@"iesdouyin",@"douyin",@"byteimg"];
    for (NSString *x in p) { if ([s containsString:x]) return YES; }
    return NO;
}

static BOOL DYIsTrackingURL(NSString *s) {
    if (!s) return NO;
    NSArray *p = @[@"/log/",@"/mcs/",@"/collect/",@"/event/",@"/behavior/",@"/monitor/",@"/analyze/",@"/track/",@"/visit/",@"/enter_room"];
    for (NSString *x in p) { if ([s containsString:x]) return YES; }
    return NO;
}

#pragma mark - Live Ghost

%hook HTSLiveUser
- (BOOL)secret {
    BOOL r = %orig;
    if (DYGhostGetBool(kGhostLiveModeKey)) { DYGhostLog(@"LIVE: secret->YES (was %d)", (int)r); return YES; }
    return r;
}
- (BOOL)isSecret {
    BOOL r = %orig;
    if (DYGhostGetBool(kGhostLiveModeKey)) { DYGhostLog(@"LIVE: isSecret->YES (was %d)", (int)r); return YES; }
    return r;
}
- (BOOL)displayEntranceEffect {
    BOOL r = %orig;
    if (DYGhostGetBool(kGhostLiveModeKey)) { DYGhostLog(@"LIVE: entrance->NO (was %d)", (int)r); return NO; }
    return r;
}
%end

%hook AWEUserModel
- (BOOL)isSecret {
    BOOL r = %orig;
    if (DYGhostGetBool(kGhostLiveModeKey)) { DYGhostLog(@"LIVE: AWE.isSecret->YES (was %d)", (int)r); return YES; }
    return r;
}
%end

#pragma mark - Browse Ghost: Layer 1 - CFNetwork diagnostic

static void (*orig_CFNetFunc)(void) = NULL;

#pragma mark - Browse Ghost: Layer 2 - NSURLRequest

%hook NSMutableURLRequest
- (void)setURL:(NSURL *)url {
    if (url && DYGhostGetBool(kGhostBrowseModeKey)) {
        NSString *s = url.absoluteString;
        if (DYIsDouyinURL(s)) {
            if (DYIsTrackingURL(s)) {
                DYGhostLog([NSString stringWithFormat:@"BLK [Req] %@", s]);
                return;
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
        if (DYIsDouyinURL(s) && body.length > 0 && body.length < 1000) {
            NSString *bs = [[NSString alloc] initWithData:body encoding:NSUTF8StringEncoding];
            if (bs) DYGhostLog([NSString stringWithFormat:@"BODY [%@] %@", [s componentsSeparatedBy:@"/"].lastObject, bs]);
        }
    }
}
%end

#pragma mark - Browse Ghost: Layer 3 - NSURLSession

%hook NSURLSession
- (NSURLSessionDataTask *)dataTaskWithRequest:(NSURLRequest *)req completionHandler:(id)handler {
    if (req.URL && DYGhostGetBool(kGhostBrowseModeKey)) {
        NSString *s = req.URL.absoluteString;
        if (DYIsDouyinURL(s)) {
            if (DYIsTrackingURL(s)) {
                DYGhostLog([NSString stringWithFormat:@"BLK [Sess] %@", s]);
                return nil;
            }
            DYGhostLog([NSString stringWithFormat:@"SEE [Sess] %@", s]);
        }
    }
    return %orig;
}
- (NSURLSessionDataTask *)dataTaskWithURL:(NSURL *)url completionHandler:(id)handler {
    if (url && DYGhostGetBool(kGhostBrowseModeKey)) {
        NSString *s = url.absoluteString;
        if (DYIsDouyinURL(s)) {
            if (DYIsTrackingURL(s)) {
                DYGhostLog([NSString stringWithFormat:@"BLK [SessU] %@", s]);
                return nil;
            }
            DYGhostLog([NSString stringWithFormat:@"SEE [SessU] %@", s]);
        }
    }
    return %orig;
}
- (NSURLSessionUploadTask *)uploadTaskWithRequest:(NSURLRequest *)req fromData:(NSData *)body completionHandler:(id)handler {
    if (req.URL && DYGhostGetBool(kGhostBrowseModeKey)) {
        NSString *s = req.URL.absoluteString;
        if (DYIsDouyinURL(s)) {
            if (DYIsTrackingURL(s)) {
                DYGhostLog([NSString stringWithFormat:@"BLK [Up] %@ len=%d", s, (int)body.length]);
                return nil;
            }
            DYGhostLog([NSString stringWithFormat:@"SEE [Up] %@ len=%d", s, (int)body.length]);
        }
    }
    return %orig;
}
%end

#pragma mark - Browse Ghost: Layer 4 - NSURLConnection legacy

%hook NSURLConnection
+ (NSData *)sendSynchronousRequest:(NSURLRequest *)req returningResponse:(NSURLResponse **)resp error:(NSError **)err {
    if (req.URL && DYGhostGetBool(kGhostBrowseModeKey)) {
        NSString *s = req.URL.absoluteString;
        if (DYIsDouyinURL(s)) {
            if (DYIsTrackingURL(s)) {
                DYGhostLog([NSString stringWithFormat:@"BLK [ConSync] %@", s]);
                if (err) *err = [NSError errorWithDomain:@"DYGhost" code:-1 userInfo:nil];
                return nil;
            }
            DYGhostLog([NSString stringWithFormat:@"SEE [ConSync] %@", s]);
        }
    }
    return %orig;
}
+ (void)sendAsynchronousRequest:(NSURLRequest *)req queue:(NSOperationQueue *)q completionHandler:(id)handler {
    if (req.URL && DYGhostGetBool(kGhostBrowseModeKey)) {
        NSString *s = req.URL.absoluteString;
        if (DYIsDouyinURL(s)) {
            if (DYIsTrackingURL(s)) {
                DYGhostLog([NSString stringWithFormat:@"BLK [ConAsync] %@", s]);
                if (handler)((void(*)(id,id,id,id))handler)(nil,nil,[NSError errorWithDomain:@"DYGhost" code:-1 userInfo:nil]);
                return;
            }
            DYGhostLog([NSString stringWithFormat:@"SEE [ConAsync] %@", s]);
        }
    }
    %orig;
}
%end

#pragma mark - Browse Ghost: Layer 5 - Tracker event methods (all known signatures)

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
    UIAlertController *a = [UIAlertController alertControllerWithTitle:@"Ghost Mode v4" message:@"" preferredStyle:UIAlertControllerStyleAlert];

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
        else t.string=@"No logs.\n1.Turn ON switches\n2.Clear&Test\n3.Enter live room\n4.Visit profile\n5.View Logs";
        UIViewController *v=p;while(v.presentedViewController)v=v.presentedViewController;
        UIAlertController *la=[UIAlertController alertControllerWithTitle:@"Logs" message:t preferredStyle:UIAlertControllerStyleAlert];
        [la addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleCancel handler:nil]];
        [v presentViewController:la animated:YES completion:nil];
    }]];

    [a addAction:[UIAlertAction actionWithTitle:@"Network Stats" style:UIAlertActionStyleDefault handler:^(UIAlertAction *x){
        _showing=NO;
        int cf=0,rq=0,se=0,cn=0,ev=0,lv=0,blk=0;
        for(NSString *l in _dyLog){
            if([l hasPrefix:@"BLK"]) blk++;
            else if([l containsString:@"[CFNet]"]) cf++;
            else if([l containsString:@"[Req]")) rq++;
            else if([l containsString:@"[Sess]")) se++;
            else if([l containsString:@"[Con]")) cn++;
            else if([l hasPrefix:@"EVT"]) ev++;
            else if([l hasPrefix:@"LIVE"]) lv++;
        }
        NSMutableString *ms=[NSMutableString string];
        [ms appendFormat:@"CFNetwork: %d\nNSURLRequest: %d\nNSURLSession: %d\nNSURLConnection: %d\nTracker Events: %d\nLive Hooks: %d\nBlocked: %d\nTotal: %d",cf,rq,se,cn,ev,lv,blk,(int)_dyLog.count];
        if(blk==0&&ev==0&&se==0)[ms appendString:@"\n\n>>> If all zeros, Douyin uses its own network stack (Cronet/TTNet) <<<"];
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
    DYGhostLog(@"Loading v4...");

    void *h=dlopen("/System/Library/Frameworks/CFNetwork.framework/CFNetwork",RTLD_NOW);
    if(h){
        void *s=dlsym(h,"CFHTTPMessageCreateRequest");
        if(s){ orig_CFNetFunc=s; DYGhostLog(@"CFNetwork: symbol FOUND");}
        else{ DYGhostLog(@"CFNetwork: symbol NOT found");}
    }else{ DYGhostLog(@"CFNetwork: dlopen FAIL");}

    NSUserDefaults *u=[NSUserDefaults standardUserDefaults];
    if(![u objectForKey:kGhostLiveModeKey])[u setBool:NO forKey:kGhostLiveModeKey];
    if(![u objectForKey:kGhostBrowseModeKey])[u setBool:NO forKey:kGhostBrowseModeKey];
    [u synchronize];

    DYGhostLog(@"Ready!");
}
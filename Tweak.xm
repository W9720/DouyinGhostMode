%config(generator=MobileSubstrate)

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <dlfcn.h>
#import <CoreFoundation/CoreFoundation.h>
#import <sys/socket.h>
#import <arpa/inet.h>

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

static BOOL DYIsNoiseURL(NSString *s) {
    if (!s) return NO;
    NSString *lower = [s lowercaseString];
    NSArray *noise = @[@".png",@".jpg",@".jpeg",@".gif",@".webp",@".mp4",@".m3u8",
                       @".css",@".js",@".woff",@".ttf",@".svg",@".ico",
                       @"cdn-tos",@"cdn.",@"byteimg",@"webcastcdn",@"/obj/"];
    for (NSString *x in noise) { if ([lower containsString:x]) return YES; }
    return NO;
}

static int _dyViewScanCount = 0;
static NSSet *_dyLiveKeywords = nil;

#pragma mark - Live Ghost: data layer

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

#pragma mark - Live Ghost: VIEW CLASS SCANNER - find real UI class names!

static void DYInitLiveKeywords(void) {
    if (!_dyLiveKeywords) {
        _dyLiveKeywords = [NSSet setWithArray:@[
            @"Audience",@"audience",@"Member",@"member",@"UserList",@"userlist",
            @"Viewer",@"viewer",@"Guest",@"guest",@"Follower",@"follower",
            @"Entrance",@"entrance",@"EnterRoom",@"enterroom",@"Enter",@"enter",
            @"Welcome",@"welcome",@"JoinRoom",@"joinroom",@"Join",@"join",
            @"ComeIn",@"comein",@"UserEnter",@"userenter",@"InRoom",@"inroom",
            @"OnlineUser",@"onlineuser",@"RoomUser",@"roomuser",
            @"Notice",@"notice",@"Banner",@"banner",@"Toast",@"toast",
            @"Tip",@"tip",@"Alert",@"alert",@"Popup",@"popup",
            @"Notify",@"notify",@"Notification",@"notification",
            @"Badge",@"badge",@"Tag",@"tag",@"Label",
            @"AvatarRow",@"avatarrow",@"UserCell",@"usercell",
            @"ListItem",@"listitem",@"RowView",@"rowview",
            @"SpeakBar",@"speakbar",@"ChatRow",@"chatrow",
            @"GiftAnim",@"giftanim",@"Effect",@"effect",
            @"TopFan",@"topfan",@"Rich",@"rich",@"Super",@"super"
        ]];
    }
}

static BOOL DYShouldHideView(NSString *clsName) {
    if (!clsName || !DYGhostGetBool(kGhostLiveModeKey)) return NO;
    DYInitLiveKeywords();
    for (NSString *kw in _dyLiveKeywords) {
        if ([clsName rangeOfString:kw options:NSCaseInsensitiveSearch].location != NSNotFound)
            return YES;
    }
    return NO;
}

%hook UIView
- (instancetype)initWithFrame:(CGRect)frame {
    UIView *v = %orig;
    if (v && DYGhostGetBool(kGhostLiveModeKey)) {
        NSString *cls = NSStringFromClass([self class]);
        _dyViewScanCount++;
        if (_dyViewScanCount <= 300 || DYShouldHideView(cls)) {
            CGRect f = frame;
            DYGhostLog([NSString stringWithFormat:@"VIEW [%@] %.0fx%.0f+%+.0f+%+.0f #%d", cls,
                f.size.width, f.size.height, f.origin.x, f.origin.y, _dyViewScanCount]);
            if (DYShouldHideView(cls)) {
                DYGhostLog([NSString stringWithFormat:@"HIDE %@", cls]);
                dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.01 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                    v.hidden = YES;
                    v.alpha = 0;
                });
            }
        }
    }
    return v;
}
- (void)didMoveToWindow {
    %orig;
    if (self.window && DYGhostGetBool(kGhostLiveModeKey)) {
        NSString *cls = NSStringFromClass([self class]);
        if (DYShouldHideView(cls)) {
            DYGhostLog([NSString stringWithFormat:@"HIDE-MOVE %@", cls]);
            self.hidden = YES;
            self.alpha = 0;
        }
    }
}
%end

%hook UILabel
- (instancetype)initWithFrame:(CGRect)frame {
    UILabel *l = %orig;
    if (l && DYGhostGetBool(kGhostLiveModeKey)) {
        NSString *cls = NSStringFromClass([self class]);
        if (DYShouldHideView(cls)) {
            DYGhostLog([NSString stringWithFormat:@"HIDE-LABEL %@ text=%@", cls, l.text ?: @""]);
            l.hidden = YES; l.alpha = 0;
        }
    }
    return l;
}
- (void)setText:(NSString *)text {
    %orig;
    if (text && DYGhostGetBool(kGhostLiveModeKey)) {
        NSString *cls = NSStringFromClass([self class]);
        if (DYShouldHideView(cls)) {
            DYGhostLog([NSString stringWithFormat:@"HIDE-LABEL-TEXT %@ '%@'", cls, text]);
            self.hidden = YES; self.alpha = 0;
        }
    }
}
%end

#pragma mark - Browse DIAG: log all requests

%hook NSMutableURLRequest
- (void)setURL:(NSURL *)url {
    if (url && DYGhostGetBool(kGhostBrowseModeKey)) {
        NSString *s = url.absoluteString;
        if (DYIsDouyinURL(s)) {
            if (!DYIsNoiseURL(s)) {
                DYGhostLog([NSString stringWithFormat:@"REQ [%@] %@", self.HTTPMethod ?: @"GET", s]);
            }
        } else {
            DYGhostLog([NSString stringWithFormat:@"EXT [%@] %@", self.HTTPMethod ?: @"GET", s]);
        }
    }
    %orig;
}
- (void)setHTTPBody:(NSData *)body {
    %orig;
    if (body && DYGhostGetBool(kGhostBrowseModeKey) && self.URL && DYIsDouyinURL(self.URL.absoluteString) && !DYIsNoiseURL(self.URL.absoluteString) && body.length > 0 && body.length < 3000) {
        NSString *bs = [[NSString alloc] initWithData:body encoding:NSUTF8StringEncoding];
        if (!bs) bs = [[NSString alloc] initWithData:body encoding:NSASCIIStringEncoding];
        if (bs && bs.length > 0) {
            NSArray *parts = [self.URL.absoluteString componentsSeparatedByString:@"/"];
            NSString *lastPath = parts.lastObject ?: @"";
            if (lastPath.length > 50) lastPath = [lastPath substringToIndex:50];
            DYGhostLog([NSString stringWithFormat:@"BODY [%@] %@", lastPath, (bs.length > 120) ? [bs substringToIndex:120] : bs]);
        } else {
            DYGhostLog([NSString stringWithFormat:@"BIN [%@] len=%d", self.URL.absoluteString, (int)body.length]);
        }
    }
}
%end

%hook NSURLSession
- (NSURLSessionDataTask *)dataTaskWithRequest:(NSURLRequest *)req completionHandler:(id)handler {
    if (req.URL && DYGhostGetBool(kGhostBrowseModeKey) && !DYIsNoiseURL(req.URL.absoluteString))
        DYGhostLog([NSString stringWithFormat:@"SESS [%@] %@", req.HTTPMethod ?: @"GET", req.URL.absoluteString]);
    return %orig;
}
- (NSURLSessionDataTask *)dataTaskWithURL:(NSURL *)url completionHandler:(id)handler {
    if (url && DYGhostGetBool(kGhostBrowseModeKey) && !DYIsNoiseURL(url.absoluteString))
        DYGhostLog([NSString stringWithFormat:@"SESS-URL %@", url.absoluteString]);
    return %orig;
}
%end

%hook NSURLConnection
+ (NSData *)sendSynchronousRequest:(NSURLRequest *)req returningResponse:(NSURLResponse **)resp error:(NSError **)err {
    if (req.URL && DYGhostGetBool(kGhostBrowseModeKey) && !DYIsNoiseURL(req.URL.absoluteString))
        DYGhostLog([NSString stringWithFormat:@"CON [%@] %@", req.HTTPMethod ?: @"GET", req.URL.absoluteString]);
    return %orig;
}
+ (void)sendAsynchronousRequest:(NSURLRequest *)req queue:(NSOperationQueue *)q completionHandler:(id)handler {
    if (req.URL && DYGhostGetBool(kGhostBrowseModeKey) && !DYIsNoiseURL(req.URL.absoluteString))
        DYGhostLog([NSString stringWithFormat:@"CON-ASYNC [%@] %@", req.HTTPMethod ?: @"GET", req.URL.absoluteString]);
    %orig;
}
%end

#pragma mark - Socket level diagnostic: log all connections

static int (*orig_connect)(int, const struct sockaddr *, socklen_t) = NULL;

static int my_connect(int sockfd, const struct sockaddr *addr, socklen_t addrlen) {
    if (DYGhostGetBool(kGhostBrowseModeKey) || DYGhostGetBool(kGhostLiveModeKey)) {
        if (addr && addr->sa_family == AF_INET) {
            struct sockaddr_in *addr_in = (struct sockaddr_in *)addr;
            char ip[INET_ADDRSTRLEN];
            inet_ntop(AF_INET, &addr_in->sin_addr, ip, sizeof(ip));
            uint16_t port = ntohs(addr_in->sin_port);
            DYGhostLog([NSString stringWithFormat:@"SOCK connect to %s:%d", ip, (int)port]);
        } else if (addr && addr->sa_family == AF_INET6) {
            DYGhostLog(@"SOCK connect IPv6");
        }
    }
    return orig_connect(sockfd, addr, addrlen);
}

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
    UIAlertController *a = [UIAlertController alertControllerWithTitle:@"Ghost Mode v7" message:@"" preferredStyle:UIAlertControllerStyleAlert];

    NSString *lt = DYGhostGetBool(kGhostLiveModeKey)?@"[ON] Live SCAN":@"[OFF] Live";
    [a addAction:[UIAlertAction actionWithTitle:lt style:UIAlertActionStyleDefault handler:^(UIAlertAction *x){
        [[NSUserDefaults standardUserDefaults] setBool:!DYGhostGetBool(kGhostLiveModeKey) forKey:kGhostLiveModeKey];
        [[NSUserDefaults standardUserDefaults] synchronize]; _showing=NO;
    }]];

    NSString *bt = DYGhostGetBool(kGhostBrowseModeKey)?@"[ON] Browse+SOCK":@"[OFF] Browse";
    [a addAction:[UIAlertAction actionWithTitle:bt style:UIAlertActionStyleDefault handler:^(UIAlertAction *x){
        [[NSUserDefaults standardUserDefaults] setBool:!DYGhostGetBool(kGhostBrowseModeKey) forKey:kGhostBrowseModeKey];
        [[NSUserDefaults standardUserDefaults] synchronize]; _showing=NO;
    }]];

    [a addAction:[UIAlertAction actionWithTitle:@"=== MARK ===" style:UIAlertActionStyleDefault handler:^(UIAlertAction *x){
        DYGhostLog(@">>> MARK <<<"); _showing=NO;
    }]];

    [a addAction:[UIAlertAction actionWithTitle:@"Clear & Test" style:UIAlertActionStyleDefault handler:^(UIAlertAction *x){
        _dyLog=[NSMutableArray array]; _dyViewScanCount=0; DYGhostLog(@">>> Cleared <<<"); _showing=NO;
    }]];

    [a addAction:[UIAlertAction actionWithTitle:@"View Logs" style:UIAlertActionStyleDefault handler:^(UIAlertAction *x){
        _showing=NO;
        NSMutableString *t=[NSMutableString string];
        if(_dyLog.count>0) for(NSString *l in[_dyLog reverseObjectEnumerator])[t appendFormat:@"%@\n",l];
        else t.string=@"No logs.\n1.Turn ON switches\n2.Clear&Test\n3.Click MARK\n4.Enter live room\n5.Click MARK\n6.Visit profile\n7.Click MARK\n8.View Logs";
        UIViewController *v=p;while(v.presentedViewController)v=v.presentedViewController;
        UIAlertController *la=[UIAlertController alertControllerWithTitle:@"Logs" message:t preferredStyle:UIAlertControllerStyleAlert];
        [la addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleCancel handler:nil]];
        [v presentViewController:la animated:YES completion:nil];
    }]];

    [a addAction:[UIAlertAction actionWithTitle:@"Stats" style:UIAlertActionStyleDefault handler:^(UIAlertAction *x){
        _showing=NO;
        int req=0,sess=0,con=0,ev=0,live=0,body=0,ext=0,sock=0,view=0,hide=0,mark=0,other=0;
        for(NSString *l in _dyLog){
            if([l hasPrefix:@"REQ "]) req++;
            else if([l hasPrefix:@"SESS"]) sess++;
            else if([l hasPrefix:@"CON"]) con++;
            else if([l hasPrefix:@"EVT"]) ev++;
            else if([l hasPrefix:@"LIVE"]) live++;
            else if([l hasPrefix:@"BODY"]||[l hasPrefix:@"BIN"]) body++;
            else if([l hasPrefix:@"EXT"]) ext++;
            else if([l hasPrefix:@"SOCK"]) sock++;
            else if([l hasPrefix:@"VIEW "]||[l hasPrefix:@"HIDE-LABEL"]) view++;
            else if([l hasPrefix:@"HIDE "]||[l hasPrefix:@"HIDE-MOVE"]) hide++;
            else if([l containsString:@"MARK"]) mark++;
            else other++;
        }
        NSMutableString *ms=[NSMutableString string];
        [ms appendFormat:@"Requests: %d\nSession: %d\nConnection: %d\nEvents: %d\nLiveHooks: %d\nBodies: %d\nExtURLs: %d\nSockets: %d\nViews: %d\nHidden: %d\nMarks: %d\nOther: %d\nTotal: %d\nViewsScanned: %d",req,sess,con,ev,live,body,ext,sock,view,hide,mark,other,(int)_dyLog.count,_dyViewScanCount];
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
    DYGhostLog(@"Loading v7...");
    DYInitLiveKeywords();

    void *h=dlopen("/usr/lib/libsystem_kernel.dylib",RTLD_NOW);
    if(h){
        orig_connect=(int(*)(int,const struct sockaddr*,socklen_t))dlsym(h,"connect");
        if(orig_connect){
            MSHookFunction((void*)orig_connect,(void*)my_connect,(void**)&orig_connect);
            DYGhostLog(@"Socket: connect() HOOKED");
        }else{ DYGhostLog(@"Socket: connect NOT found");}
    }else{ DYGhostLog(@"Socket: dlopen FAIL");}

    void *cf=dlopen("/System/Library/Frameworks/CFNetwork.framework/CFNetwork",RTLD_NOW);
    if(cf){ typedef CFHTTPMessageRef(*Fn)(CFAllocatorRef,CFURLRef,CFStringRef,CFStringRef,CFDictionaryRef); Fn f=(Fn)dlsym(cf,"CFHTTPMessageCreateRequest"); if(f) DYGhostLog(@"CFNetwork: FOUND"); else DYGhostLog(@"CFNetwork: NOT found");}
    else{ DYGhostLog(@"CFNetwork: FAIL");}

    NSUserDefaults *u=[NSUserDefaults standardUserDefaults];
    if(![u objectForKey:kGhostLiveModeKey])[u setBool:NO forKey:kGhostLiveModeKey];
    if(![u objectForKey:kGhostBrowseModeKey])[u setBool:NO forKey:kGhostBrowseModeKey];
    [u synchronize]; DYGhostLog(@"Ready!");
}
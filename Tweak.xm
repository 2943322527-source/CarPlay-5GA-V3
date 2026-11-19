// CarPlay 5GA V5: read-only view probe (NO UI changes).
// iOS 16.5 / Dopamine RootHide; load only in com.apple.CarPlayApp.
// Purpose: identify the actual 5G-small-cap-A label and its rectangle before
// implementing an independent overlay. Do not hook text or layout methods.

#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <dispatch/dispatch.h>
#import <objc/message.h>

static NSUInteger cp5ga_nodes = 0;
static NSUInteger cp5ga_hits = 0;
static NSMutableString *cp5ga_report = nil;

static BOOL CP5GAInterestingName(NSString *name) {
    if (!name) return NO;
    return ([name rangeOfString:@"Status" options:NSCaseInsensitiveSearch].location != NSNotFound ||
            [name rangeOfString:@"String" options:NSCaseInsensitiveSearch].location != NSNotFound ||
            [name rangeOfString:@"Cellular" options:NSCaseInsensitiveSearch].location != NSNotFound ||
            [name rangeOfString:@"Signal" options:NSCaseInsensitiveSearch].location != NSNotFound);
}

static NSString *CP5GATextForView(UIView *view) {
    if (![view respondsToSelector:@selector(text)]) return nil;
    id value = ((id (*)(id, SEL))objc_msgSend)(view, @selector(text));
    if (![value isKindOfClass:[NSString class]]) return nil;
    return (NSString *)value;
}

static BOOL CP5GAIsNetworkText(NSString *text) {
    if (![text isKindOfClass:[NSString class]]) return NO;
    // Never log arbitrary screen text. Only network indicators are included.
    return ([text rangeOfString:@"5G" options:NSCaseInsensitiveSearch].location != NSNotFound ||
            [text rangeOfString:@"5Ｇ"].location != NSNotFound);
}

static void CP5GAInspect(UIView *view, UIWindow *window, NSUInteger depth) {
    if (!view || depth > 13 || cp5ga_nodes++ >= 900) return;
    NSString *name = NSStringFromClass([view class]);
    NSString *value = CP5GATextForView(view);
    BOOL target = CP5GAIsNetworkText(value);
    BOOL named = CP5GAInterestingName(name);
    if ((target || named) && cp5ga_report.length < 50000) {
        CGRect r = [view convertRect:view.bounds toView:window];
        NSString *parentName = view.superview ? NSStringFromClass([view.superview class]) : @"none";
        NSString *appearance = @"";
        if (target && [view isKindOfClass:[UILabel class]]) {
            UILabel *label = (UILabel *)view;
            UIFont *font = label.font;
            appearance = [NSString stringWithFormat:@" font=%@ size=%.2f textColor=%@",
                font.fontName ?: @"unknown", font.pointSize, label.textColor];
        }
        [cp5ga_report appendFormat:@"%@ depth=%lu view=%@ parent=%@ frame=(%.1f,%.1f,%.1f,%.1f) hidden=%d alpha=%.2f%@%@\n",
         target ? @"NETWORK" : @"view", (unsigned long)depth, name, parentName,
         r.origin.x, r.origin.y, r.size.width, r.size.height, view.hidden, view.alpha,
         target ? [NSString stringWithFormat:@" text=%@", value] : @"", appearance];
        if (target) cp5ga_hits++;
    }
    // Read-only traversal: never change text, font, layout, transform or layer.
    for (UIView *child in view.subviews) {
        CP5GAInspect(child, window, depth + 1);
        if (cp5ga_nodes >= 900) return;
    }
}

static NSArray<UIWindow *> *CP5GAWindows(void) {
    NSMutableArray<UIWindow *> *result = [NSMutableArray array];
    UIApplication *app = [UIApplication sharedApplication];
    // Keep the legacy window fallback for iOS 16 CarPlay scene discovery.
    // The iOS 16 SDK marks UIApplication.windows deprecated; this read-only
    // diagnostic access is intentional and should not fail -Werror builds.
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    for (UIWindow *w in app.windows) {
        if (![result containsObject:w]) [result addObject:w];
    }
#pragma clang diagnostic pop
    if (@available(iOS 13.0, *)) {
        for (UIScene *scene in app.connectedScenes) {
            if (![scene isKindOfClass:[UIWindowScene class]]) continue;
            for (UIWindow *w in ((UIWindowScene *)scene).windows) {
                if (![result containsObject:w]) [result addObject:w];
            }
        }
    }
    return result;
}

static void CP5GAWriteReport(NSString *report) {
    // Multiple candidates because system-app sandbox permissions vary.
    NSArray<NSString *> *paths = @[
        @"/var/mobile/Library/Logs/CarPlay5GAProbe.txt",
        @"/var/mobile/Library/Preferences/CarPlay5GAProbe.txt",
        @"/private/var/tmp/CarPlay5GAProbe.txt",
        [NSTemporaryDirectory() stringByAppendingPathComponent:@"CarPlay5GAProbe.txt"]
    ];
    NSError *err = nil;
    for (NSString *path in paths) {
        err = nil;
        if ([report writeToFile:path atomically:YES encoding:NSUTF8StringEncoding error:&err]) {
            NSLog(@"[CarPlay5GAProbe] report saved at %@", path);
            return;
        }
    }
    NSLog(@"[CarPlay5GAProbe] Could not write report: %@", err);
    NSLog(@"[CarPlay5GAProbe] %@", report);
}

static void CP5GAScan(NSUInteger run) {
    cp5ga_nodes = 0;
    cp5ga_hits = 0;
    cp5ga_report = [NSMutableString stringWithFormat:
      @"CarPlay 5GA READ-ONLY PROBE V5\nrun=%lu date=%@\nbundle=%@\n",
      (unsigned long)run, [NSDate date], [[NSBundle mainBundle] bundleIdentifier]];
    NSArray<UIWindow *> *windows = CP5GAWindows();
    [cp5ga_report appendFormat:@"windows=%lu\n", (unsigned long)windows.count];
    for (UIWindow *w in windows) {
        [cp5ga_report appendFormat:@"WINDOW %@ bounds=(%.1f,%.1f) hidden=%d\n",
          NSStringFromClass([w class]), w.bounds.size.width, w.bounds.size.height, w.hidden];
        CP5GAInspect(w, w, 0);
    }
    [cp5ga_report appendFormat:@"totalVisited=%lu networkHits=%lu\n",
      (unsigned long)cp5ga_nodes, (unsigned long)cp5ga_hits];
    CP5GAWriteReport(cp5ga_report);
}

%ctor {
    // No Logos hooks. Even if the class names differ on this device, UI is untouched.
    dispatch_async(dispatch_get_main_queue(), ^{
        __block NSUInteger scanNumber = 0;
        [NSTimer scheduledTimerWithTimeInterval:5.0 repeats:YES block:^(NSTimer *timer) {
            scanNumber++;
            CP5GAScan(scanNumber);
            if (scanNumber >= 12) [timer invalidate];
        }];
    });
}

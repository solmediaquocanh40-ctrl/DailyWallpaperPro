// Tweak.x — DailyWallpaperPro 1.0.1 (com.anhdang.dailywallpaperpro)
// Chay trong SpringBoard: dong ho kiem tra moi 60 giay + thong bao Darwin
// tu trang Cai dat (doi ngay / test engine). Khong hook class nao o ban nay —
// toan bo viec doi nen nam o DWPEngine (do API luc chay, ghi log tung duong).

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <CoreFoundation/CoreFoundation.h>
#import "DWPShared.h"
#import "DWPEngine.h"

// Khai bao truoc moi ham/bien toan cuc ma khoi duoi dung (thu tu khai bao).
static void DWPCheckAndApply(NSString *reason, BOOL force);
static void DWPApplySlot(NSInteger slot, NSString *reason);
static void DWPHandlePrefsChanged(void);
static void DWPHandleApplyNow(void);
static void DWPHandleTestEngine(void);
static void DWPOnPrefsChanged(CFNotificationCenterRef center, void *observer, CFStringRef name, const void *object, CFDictionaryRef userInfo);
static void DWPOnApplyNow(CFNotificationCenterRef center, void *observer, CFStringRef name, const void *object, CFDictionaryRef userInfo);
static void DWPOnTestEngine(CFNotificationCenterRef center, void *observer, CFStringRef name, const void *object, CFDictionaryRef userInfo);
static UIImage *DWPTestImage(void);

static void DWPApplySlot(NSInteger slot, NSString *reason) {
    NSString *path = DWPSlotPath(slot);
    UIImage *image = [UIImage imageWithContentsOfFile:path];
    if (!image) {
        DWPLog(@"apply (%@): o %ld khong co anh (%@)", reason, (long)slot, path);
        return;
    }
    NSInteger target = DWPPrefInt(DWPKeyTarget, 2);
    BOOL ok = [DWPEngine applyImage:image target:target];
    NSDate *now = [NSDate date];
    DWPSetPref(DWPKeyLastChange, @([now timeIntervalSince1970]));
    DWPSetPref(DWPKeyCurrentSlot, @(slot));
    NSDateFormatter *fmt = [[NSDateFormatter alloc] init];
    fmt.dateFormat = @"yyyy-MM-dd";
    fmt.locale = [NSLocale localeWithLocaleIdentifier:@"en_US_POSIX"];
    DWPSetPref(DWPKeyLastDay, [fmt stringFromDate:now]);
    DWPLog(@"apply (%@): o %ld target %ld -> engine %@", reason, (long)slot, (long)target, ok ? @"NHAN LENH (cho anh doi chieu bang mat)" : @"KHONG NHAN");
}

static void DWPCheckAndApply(NSString *reason, BOOL force) {
    if (!DWPPrefBool(DWPKeyEnabled, YES)) {
        if (force) DWPLog(@"check (%@): tweak dang TAT, bo qua", reason);
        return;
    }
    NSArray<NSNumber *> *filled = DWPFilledSlots();
    if (filled.count == 0) {
        if (force) DWPLog(@"check (%@): chua co anh nao, bo qua", reason);
        return;
    }
    NSInteger mode = DWPPrefInt(DWPKeyRotationMode, 0);
    NSDate *now = [NSDate date];

    if (mode == 2) { // Tat — chi dung 1 anh, chi doi khi bam Doi ngay
        if (force) DWPApplySlot([filled.firstObject integerValue], reason);
        return;
    }

    if (mode == 0) { // Lich thang: ngay may -> o anh ay
        NSCalendar *cal = [NSCalendar currentCalendar];
        NSInteger day = [cal component:NSCalendarUnitDay fromDate:now];
        NSInteger hour = DWPPrefInt(DWPKeyScheduleHour, 0);
        NSInteger minute = DWPPrefInt(DWPKeyScheduleMinute, 0);
        NSDateComponents *dc = [cal components:(NSCalendarUnitYear | NSCalendarUnitMonth | NSCalendarUnitDay) fromDate:now];
        dc.hour = hour; dc.minute = minute; dc.second = 0;
        NSDate *startToday = [cal dateFromComponents:dc];
        if (startToday && [now compare:startToday] == NSOrderedAscending && !force) return; // chua toi gio bat dau
        NSDateFormatter *fmt = [[NSDateFormatter alloc] init];
        fmt.dateFormat = @"yyyy-MM-dd";
        fmt.locale = [NSLocale localeWithLocaleIdentifier:@"en_US_POSIX"];
        NSString *today = [fmt stringFromDate:now];
        NSString *lastDay = DWPPrefString(DWPKeyLastDay, @"");
        if ([lastDay isEqualToString:today] && !force) return; // hom nay da doi roi
        NSInteger slot = day;
        if (![filled containsObject:@(slot)]) {
            // Ngay nay chua co anh: lui ve o co anh gan nhat phia truoc, ghi log ro.
            NSInteger fallback = [filled.firstObject integerValue];
            for (NSNumber *n in filled) if ([n integerValue] <= day) fallback = [n integerValue];
            DWPLog(@"check (%@): ngay %ld chua co anh, tam dung o %ld", reason, (long)day, (long)fallback);
            slot = fallback;
        }
        DWPApplySlot(slot, reason);
        return;
    }

    // mode == 1: Khoang thoi gian tu set (phut/gio/ngay/thang)
    double last = DWPPrefDouble(DWPKeyLastChange, 0);
    if (last > 0 && !force) {
        NSDate *next = DWPNextIntervalDate([NSDate dateWithTimeIntervalSince1970:last],
                                            DWPPrefInt(DWPKeyIntervalValue, 1),
                                            DWPPrefInt(DWPKeyIntervalUnit, 2));
        if ([now compare:next] == NSOrderedAscending) return; // chua toi moc
    }
    NSInteger current = DWPPrefInt(DWPKeyCurrentSlot, 0);
    NSInteger order = DWPPrefInt(DWPKeyOrderMode, 0);
    NSInteger nextSlot;
    if (order == 1 && filled.count > 1) {
        NSInteger pick = current;
        while (pick == current) pick = [filled[arc4random_uniform((uint32_t)filled.count)] integerValue];
        nextSlot = pick;
    } else {
        NSUInteger idx = [filled indexOfObject:@(current)];
        if (idx == NSNotFound) idx = filled.count - 1;
        nextSlot = [filled[(idx + 1) % filled.count] integerValue];
    }
    DWPApplySlot(nextSlot, reason);
}

static void DWPHandlePrefsChanged(void) {
    DWPLog(@"notify: cai dat thay doi — enabled=%d target=%ld mode=%ld interval=%ld unit=%ld",
           DWPPrefBool(DWPKeyEnabled, YES), (long)DWPPrefInt(DWPKeyTarget, 2),
           (long)DWPPrefInt(DWPKeyRotationMode, 0), (long)DWPPrefInt(DWPKeyIntervalValue, 1),
           (long)DWPPrefInt(DWPKeyIntervalUnit, 2));
    DWPCheckAndApply(@"prefsChanged", NO);
}

static void DWPHandleApplyNow(void) {
    DWPLog(@"notify: anh bam DOI NGAY trong Cai dat");
    DWPCheckAndApply(@"applyNow", YES);
}

static void DWPHandleTestEngine(void) {
    DWPLog(@"notify: anh bam TEST ENGINE trong Cai dat");
    [DWPEngine dumpDiagnostics];
    UIImage *img = DWPTestImage();
    NSInteger target = DWPPrefInt(DWPKeyTarget, 2);
    BOOL ok = [DWPEngine applyImage:img target:target];
    DWPLog(@"test engine: target %ld -> %@", (long)target, ok ? @"CO duong nhan lenh" : @"KHONG duong nao nhan lenh");
}

static void DWPOnPrefsChanged(CFNotificationCenterRef center, void *observer, CFStringRef name, const void *object, CFDictionaryRef userInfo) {
    dispatch_async(dispatch_get_main_queue(), ^{ DWPHandlePrefsChanged(); });
}
static void DWPOnApplyNow(CFNotificationCenterRef center, void *observer, CFStringRef name, const void *object, CFDictionaryRef userInfo) {
    dispatch_async(dispatch_get_main_queue(), ^{ DWPHandleApplyNow(); });
}
static void DWPOnTestEngine(CFNotificationCenterRef center, void *observer, CFStringRef name, const void *object, CFDictionaryRef userInfo) {
    dispatch_async(dispatch_get_main_queue(), ^{ DWPHandleTestEngine(); });
}

static UIImage *DWPTestImage(void) {
    CGSize size = CGSizeMake(1170, 2532);
    UIGraphicsImageRenderer *renderer = [[UIGraphicsImageRenderer alloc] initWithSize:size];
    return [renderer imageWithActions:^(UIGraphicsImageRendererContext *ctx) {
        [[UIColor colorWithRed:0.85 green:0.25 blue:0.15 alpha:1.0] setFill];
        UIRectFill(CGRectMake(0, 0, size.width, size.height));
        NSDictionary *attrs = @{ NSFontAttributeName: [UIFont boldSystemFontOfSize:130],
                                 NSForegroundColorAttributeName: [UIColor whiteColor] };
        NSString *text = @"DWP TEST\n1.0.1";
        CGSize ts = [text sizeWithAttributes:attrs];
        [text drawInRect:CGRectMake((size.width - ts.width) / 2.0, (size.height - ts.height) / 2.0, ts.width, ts.height) withAttributes:attrs];
    }];
}

%ctor {
    @autoreleasepool {
        DWPLog(@"=== DailyWallpaperPro %@ nap vao SpringBoard ===", DWP_VERSION);
        CFNotificationCenterRef darwin = CFNotificationCenterGetDarwinNotifyCenter();
        CFNotificationCenterAddObserver(darwin, NULL, DWPOnPrefsChanged, DWP_NOTIFY_PREFS, NULL, CFNotificationSuspensionBehaviorDeliverImmediately);
        CFNotificationCenterAddObserver(darwin, NULL, DWPOnApplyNow, DWP_NOTIFY_APPLY, NULL, CFNotificationSuspensionBehaviorDeliverImmediately);
        CFNotificationCenterAddObserver(darwin, NULL, DWPOnTestEngine, DWP_NOTIFY_TEST, NULL, CFNotificationSuspensionBehaviorDeliverImmediately);
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [DWPEngine dumpDiagnostics];
            DWPCheckAndApply(@"khoi dong", NO);
            [NSTimer scheduledTimerWithTimeInterval:60.0 repeats:YES block:^(NSTimer *timer) {
                DWPCheckAndApply(@"tick", NO);
            }];
            DWPLog(@"dong ho kiem tra 60 giay da chay");
        });
    }
}

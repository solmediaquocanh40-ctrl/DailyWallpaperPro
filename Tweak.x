// Tweak.x — DailyWallpaperPro 1.0.11 (com.anhdang.dailywallpaperpro)
// Chay trong SpringBoard: dong ho kiem tra moi 60 giay + thong bao Darwin
// tu trang Cai dat (doi ngay / test engine / test mau). Khong hook class nao —
// toan bo viec doi nen nam o DWPEngine (do API luc chay, ghi log tung duong).

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <CoreFoundation/CoreFoundation.h>
#import <CoreImage/CoreImage.h>
#import "DWPShared.h"
#import "DWPEngine.h"
#import "DWPLicense.h"

// Khai bao truoc moi ham/bien toan cuc ma khoi duoi dung (thu tu khai bao).
static void DWPCheckAndApply(NSString *reason, BOOL force);
static void DWPApplySlot(NSInteger slot, NSString *reason);
static void DWPApplyColorLike(NSInteger forcedIndex, NSString *reason, BOOL force);
static UIImage *DWPProcessedImage(UIImage *image);
static BOOL DWPBatteryBlocksChange(void);
static void DWPMarkApplied(NSInteger slotOrColor);
static void DWPHandlePrefsChanged(void);
static void DWPHandleApplyNow(void);
static void DWPHandleTestEngine(void);
static void DWPHandleTestColor(void);
static void DWPOnPrefsChanged(CFNotificationCenterRef center, void *observer, CFStringRef name, const void *object, CFDictionaryRef userInfo);
static void DWPOnApplyNow(CFNotificationCenterRef center, void *observer, CFStringRef name, const void *object, CFDictionaryRef userInfo);
static void DWPOnTestEngine(CFNotificationCenterRef center, void *observer, CFStringRef name, const void *object, CFDictionaryRef userInfo);
static void DWPOnTestColor(CFNotificationCenterRef center, void *observer, CFStringRef name, const void *object, CFDictionaryRef userInfo);
static UIImage *DWPTestImage(void);

static BOOL gDWPTestExperimental = NO;

static void DWPMarkApplied(NSInteger slotOrColor) {
    NSDate *now = [NSDate date];
    DWPSetPref(DWPKeyLastChange, @([now timeIntervalSince1970]));
    NSDateFormatter *fmt = [[NSDateFormatter alloc] init];
    fmt.dateFormat = @"yyyy-MM-dd";
    fmt.locale = [NSLocale localeWithLocaleIdentifier:@"en_US_POSIX"];
    DWPSetPref(DWPKeyLastDay, [fmt stringFromDate:now]);
    (void)slotOrColor;
}

static BOOL DWPBatteryBlocksChange(void) {
    if (!DWPPrefBool(DWPKeyLowBatteryGuard, NO)) return NO;
    UIDevice *dev = [UIDevice currentDevice];
    dev.batteryMonitoringEnabled = YES;
    float level = dev.batteryLevel;
    if (level < 0) return NO;
    UIDeviceBatteryState state = dev.batteryState;
    if (level < 0.20f && state != UIDeviceBatteryStateCharging && state != UIDeviceBatteryStateFull) {
        DWPLog(@"pin: %.0f%% va khong sac — tam khong doi nen (chan pin yeu dang BAT)", level * 100);
        return YES;
    }
    return NO;
}

// Lam mo + phu toi anh theo cai dat (chi ap cho che do anh).
static UIImage *DWPProcessedImage(UIImage *image) {
    NSInteger blur = DWPPrefInt(DWPKeyBlurLevel, 0);
    NSInteger darken = DWPPrefInt(DWPKeyDarkenPercent, 0);
    UIImage *img = image;
    if (blur > 0) {
        double radius = (blur == 1) ? 10.0 : (blur == 2) ? 20.0 : 35.0;
        CIImage *inImg = [CIImage imageWithCGImage:img.CGImage];
        CIFilter *clamp = [CIFilter filterWithName:@"CIAffineClamp"];
        [clamp setValue:inImg forKey:kCIInputImageKey];
        CIFilter *gauss = [CIFilter filterWithName:@"CIGaussianBlur"];
        [gauss setValue:clamp.outputImage forKey:kCIInputImageKey];
        [gauss setValue:@(radius) forKey:kCIInputRadiusKey];
        CIImage *outImg = gauss.outputImage;
        if (outImg) {
            CIContext *ctx = [CIContext contextWithOptions:nil];
            CGImageRef cg = [ctx createCGImage:outImg fromRect:inImg.extent];
            if (cg) {
                img = [UIImage imageWithCGImage:cg scale:img.scale orientation:img.imageOrientation];
                CGImageRelease(cg);
            }
        }
    }
    if (darken > 0) {
        CGFloat alpha = (CGFloat)darken / 100.0;
        UIGraphicsImageRenderer *renderer = [[UIGraphicsImageRenderer alloc] initWithSize:img.size];
        img = [renderer imageWithActions:^(UIGraphicsImageRendererContext *rctx) {
            [img drawInRect:CGRectMake(0, 0, img.size.width, img.size.height)];
            [[UIColor colorWithWhite:0 alpha:alpha] setFill];
            UIRectFill(CGRectMake(0, 0, img.size.width, img.size.height));
        }];
    }
    return img;
}

static void DWPApplySlot(NSInteger slot, NSString *reason) {
    NSString *path = DWPSlotPath(slot);
    UIImage *image = [UIImage imageWithContentsOfFile:path];
    if (!image) {
        DWPLog(@"apply (%@): o %ld khong co anh (%@)", reason, (long)slot, path);
        return;
    }
    image = DWPProcessedImage(image);
    NSInteger target = DWPPrefInt(DWPKeyTarget, 2);
    BOOL ok = [DWPEngine applyImage:image target:target];
    DWPSetPref(DWPKeyCurrentSlot, @(slot));
    DWPMarkApplied(slot);
    DWPLog(@"apply (%@): anh o %ld target %ld -> engine %@", reason, (long)slot, (long)target, ok ? @"NHAN LENH (cho anh doi chieu bang mat)" : @"KHONG NHAN");
}

// Ap nen dang mau tron / mau chuyen. forcedIndex >= 0: dung thang vi tri do
// (test). Nguoc lai: theo cai dat — xoay mau thi theo ngay/vong, khong thi
// dung mau dang chon.
static void DWPApplyColorLike(NSInteger forcedIndex, NSString *reason, BOOL force) {
    NSInteger source = DWPPrefInt(DWPKeySourceMode, 0);
    NSInteger target = DWPPrefInt(DWPKeyTarget, 2);
    BOOL rotate = DWPPrefBool(DWPKeyColorRotate, NO);
    NSInteger mode = DWPPrefInt(DWPKeyRotationMode, 0);
    NSInteger count = (source == 1) ? (NSInteger)DWPPaletteHexes().count : (NSInteger)DWPGradientHexPairs().count;
    if (count <= 0) return;
    NSInteger idx;
    if (forcedIndex >= 0) {
        idx = forcedIndex % count;
    } else if (!rotate) {
        idx = (source == 1) ? DWPPrefInt(DWPKeyColorIndex, 8) : DWPPrefInt(DWPKeyGradientIndex, 0);
    } else if (mode == 0) {
        NSInteger day = [[NSCalendar currentCalendar] component:NSCalendarUnitDay fromDate:[NSDate date]];
        idx = (day - 1) % count;
    } else {
        idx = DWPPrefInt(DWPKeyCurrentColor, 0);
    }
    if (idx < 0 || idx >= count) idx = 0;
    UIImage *image = nil;
    BOOL nativeTried = NO;
    BOOL nativeOK = NO;
    if (source == 1) {
        UIColor *color = nil;
        if (!rotate && forcedIndex < 0) color = DWPCurrentSolidColor();
        else color = DWPColorFromHex(DWPPaletteHexes()[idx]);
        if (!color) color = [UIColor blackColor];
        image = DWPSolidColorImage(color);
        nativeOK = [DWPEngine applyColorNative:color target:target];
        nativeTried = YES;
    } else {
        image = DWPGradientImage(idx);
    }
    BOOL ok = gDWPTestExperimental ? [DWPEngine applyImageExperimental:image target:target]
                                       : [DWPEngine applyImage:image target:target];
    DWPSetPref(DWPKeyCurrentColor, @(idx));
    DWPMarkApplied(idx);
    DWPLog(@"apply (%@): %@ vi tri %ld target %ld -> anh %@ / mau native %@",
           reason, source == 1 ? @"MAU TRON" : @"GRADIENT", (long)idx, (long)target,
           ok ? @"NHAN LENH" : @"KHONG NHAN",
           nativeTried ? (nativeOK ? @"NHAN LENH" : @"KHONG NHAN") : @"khong thu");
}

static void DWPCheckAndApply(NSString *reason, BOOL force) {
    if (!DWPPrefBool(DWPKeyEnabled, YES)) {
        if (force) DWPLog(@"check (%@): tweak dang TAT, bo qua", reason);
        return;
    }
    // Cong ban quyen (1.0.11): het dung thu / het han key thi khong doi nen.
    // Log chi khi trang thai thay doi de khoi spam moi 60 giay.
    if (!DWPLicenseActive()) {
        static DWPLicState lastLicState = (DWPLicState)-1;
        DWPLicState st = DWPLicenseCurrentState(NULL, NULL);
        if (st != lastLicState) {
            lastLicState = st;
            DWPLog(@"check (%@): BAN QUYEN khong con han (%@) — khong doi nen", reason, DWPLicenseStatusText());
        }
        return;
    }
    if (!force && DWPBatteryBlocksChange()) return;

    NSInteger source = DWPPrefInt(DWPKeySourceMode, 0);
    NSInteger mode = DWPPrefInt(DWPKeyRotationMode, 0);
    NSDate *now = [NSDate date];

    if (source != 0) {
        // Che do mau: khong can anh. Tat xoay = chi ap khi co lenh force.
        BOOL rotate = DWPPrefBool(DWPKeyColorRotate, NO);
        if (mode == 2 || !rotate) {
            if (force) DWPApplyColorLike(-1, reason, force);
            return;
        }
        if (mode == 0) {
            NSDateFormatter *fmt = [[NSDateFormatter alloc] init];
            fmt.dateFormat = @"yyyy-MM-dd";
            fmt.locale = [NSLocale localeWithLocaleIdentifier:@"en_US_POSIX"];
            NSString *today = [fmt stringFromDate:now];
            if ([DWPPrefString(DWPKeyLastDay, @"") isEqualToString:today] && !force) return;
            DWPApplyColorLike(-1, reason, force);
            return;
        }
        // Khoang thoi gian: toi moc thi qua mau tiep theo
        double last = DWPPrefDouble(DWPKeyLastChange, 0);
        if (last > 0 && !force) {
            NSDate *next = DWPNextIntervalDate([NSDate dateWithTimeIntervalSince1970:last],
                                                DWPPrefInt(DWPKeyIntervalValue, 1),
                                                DWPPrefInt(DWPKeyIntervalUnit, 2));
            if ([now compare:next] == NSOrderedAscending) return;
        }
        NSInteger count = (source == 1) ? (NSInteger)DWPPaletteHexes().count : (NSInteger)DWPGradientHexPairs().count;
        NSInteger cur = DWPPrefInt(DWPKeyCurrentColor, 0);
        NSInteger order = DWPPrefInt(DWPKeyOrderMode, 0);
        NSInteger nextIdx;
        if (order == 1 && count > 1) {
            nextIdx = cur;
            while (nextIdx == cur) nextIdx = (NSInteger)arc4random_uniform((uint32_t)count);
        } else {
            nextIdx = (cur + 1) % count;
        }
        DWPApplyColorLike(nextIdx, reason, force);
        return;
    }

    // Che do anh
    NSArray<NSNumber *> *filled = DWPFilledSlots();
    if (filled.count == 0) {
        if (force) DWPLog(@"check (%@): chua co anh nao, bo qua", reason);
        return;
    }
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
        if (startToday && [now compare:startToday] == NSOrderedAscending && !force) return;
        NSDateFormatter *fmt = [[NSDateFormatter alloc] init];
        fmt.dateFormat = @"yyyy-MM-dd";
        fmt.locale = [NSLocale localeWithLocaleIdentifier:@"en_US_POSIX"];
        NSString *today = [fmt stringFromDate:now];
        if ([DWPPrefString(DWPKeyLastDay, @"") isEqualToString:today] && !force) return;
        NSInteger slot = day;
        if (![filled containsObject:@(slot)]) {
            NSInteger fallback = [filled.firstObject integerValue];
            for (NSNumber *n in filled) if ([n integerValue] <= day) fallback = [n integerValue];
            DWPLog(@"check (%@): ngay %ld chua co anh, tam dung o %ld", reason, (long)day, (long)fallback);
            slot = fallback;
        }
        DWPApplySlot(slot, reason);
        return;
    }
    // Khoang thoi gian tu set (phut/gio/ngay/thang)
    double last = DWPPrefDouble(DWPKeyLastChange, 0);
    if (last > 0 && !force) {
        NSDate *next = DWPNextIntervalDate([NSDate dateWithTimeIntervalSince1970:last],
                                            DWPPrefInt(DWPKeyIntervalValue, 1),
                                            DWPPrefInt(DWPKeyIntervalUnit, 2));
        if ([now compare:next] == NSOrderedAscending) return;
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
    DWPLog(@"notify: cai dat thay doi — enabled=%d target=%ld mode=%ld source=%ld interval=%ld unit=%ld",
           DWPPrefBool(DWPKeyEnabled, YES), (long)DWPPrefInt(DWPKeyTarget, 2),
           (long)DWPPrefInt(DWPKeyRotationMode, 0), (long)DWPPrefInt(DWPKeySourceMode, 0),
           (long)DWPPrefInt(DWPKeyIntervalValue, 1), (long)DWPPrefInt(DWPKeyIntervalUnit, 2));
    DWPCheckAndApply(@"prefsChanged", NO);
}

static void DWPHandleApplyNow(void) {
    DWPLog(@"notify: anh bam DOI NGAY trong Cai dat");
    DWPCheckAndApply(@"applyNow", YES);
}

static void DWPHandleTestEngine(void) {
    DWPLog(@"notify: anh bam TEST ENGINE trong Cai dat");
    if (!DWPLicenseActive()) {
        DWPLog(@"test engine: BAN QUYEN khong con han (%@) — bo qua", DWPLicenseStatusText());
        return;
    }
    [DWPEngine dumpDiagnostics];
    UIImage *img = DWPTestImage();
    NSInteger target = DWPPrefInt(DWPKeyTarget, 2);
    BOOL ok = [DWPEngine applyImageExperimental:img target:target];
    DWPLog(@"test engine: target %ld -> %@", (long)target, ok ? @"CO duong nhan lenh" : @"KHONG duong nao nhan lenh");
}

static void DWPHandleTestColor(void) {
    DWPLog(@"notify: anh bam TEST MAU trong Cai dat");
    if (!DWPLicenseActive()) {
        DWPLog(@"test mau: BAN QUYEN khong con han (%@) — bo qua", DWPLicenseStatusText());
        return;
    }
    gDWPTestExperimental = YES;
    DWPApplyColorLike(-1, @"testColor", YES);
    gDWPTestExperimental = NO;
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
static void DWPOnTestColor(CFNotificationCenterRef center, void *observer, CFStringRef name, const void *object, CFDictionaryRef userInfo) {
    dispatch_async(dispatch_get_main_queue(), ^{ DWPHandleTestColor(); });
}

static UIImage *DWPTestImage(void) {
    CGSize size = CGSizeMake(1170, 2532);
    UIGraphicsImageRenderer *renderer = [[UIGraphicsImageRenderer alloc] initWithSize:size];
    return [renderer imageWithActions:^(UIGraphicsImageRendererContext *ctx) {
        [[UIColor colorWithRed:0.85 green:0.25 blue:0.15 alpha:1.0] setFill];
        UIRectFill(CGRectMake(0, 0, size.width, size.height));
        NSDictionary *attrs = @{ NSFontAttributeName: [UIFont boldSystemFontOfSize:130],
                                 NSForegroundColorAttributeName: [UIColor whiteColor] };
        NSString *text = @"DWP TEST\n1.0.11";
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
        CFNotificationCenterAddObserver(darwin, NULL, DWPOnTestColor, DWP_NOTIFY_TESTCOLOR, NULL, CFNotificationSuspensionBehaviorDeliverImmediately);
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

// DWPShared.m — DailyWallpaperPro 1.0.10

#import "DWPShared.h"
#import <CoreFoundation/CoreFoundation.h>
#import <fcntl.h>
#import <unistd.h>

NSString * const DWPKeyEnabled = @"enabled";
NSString * const DWPKeyTarget = @"target";
NSString * const DWPKeyRotationMode = @"rotationMode";
NSString * const DWPKeyOrderMode = @"orderMode";
NSString * const DWPKeyIntervalValue = @"intervalValue";
NSString * const DWPKeyIntervalUnit = @"intervalUnit";
NSString * const DWPKeyScheduleHour = @"scheduleHour";
NSString * const DWPKeyScheduleMinute = @"scheduleMinute";
NSString * const DWPKeyLanguage = @"language";
NSString * const DWPKeySourceMode = @"sourceMode";
NSString * const DWPKeyColorIndex = @"colorIndex";
NSString * const DWPKeyColorHex = @"colorHex";
NSString * const DWPKeyColorRotate = @"colorRotate";
NSString * const DWPKeyGradientIndex = @"gradientIndex";
NSString * const DWPKeyDarkenPercent = @"darkenPercent";
NSString * const DWPKeyBlurLevel = @"blurLevel";
NSString * const DWPKeyLowBatteryGuard = @"lowBatteryGuard";
NSString * const DWPKeyLastChange = @"lastChange";
NSString * const DWPKeyLastDay = @"lastDay";
NSString * const DWPKeyCurrentSlot = @"currentSlot";
NSString * const DWPKeyCurrentColor = @"currentColor";

void DWPLog(NSString *format, ...) {
    va_list args;
    va_start(args, format);
    NSString *msg = [[NSString alloc] initWithFormat:format arguments:args];
    va_end(args);
    static NSDateFormatter *fmt = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        fmt = [[NSDateFormatter alloc] init];
        fmt.dateFormat = @"yyyy-MM-dd HH:mm:ss";
        fmt.locale = [NSLocale localeWithLocaleIdentifier:@"en_US_POSIX"];
    });
    NSString *line = [NSString stringWithFormat:@"[%@] %@\n", [fmt stringFromDate:[NSDate date]], msg];
    NSLog(@"[DailyWallpaperPro] %@", msg);
    // Ghi bang POSIX O_APPEND + 1 lan write duy nhat: nhieu tien trinh
    // (SpringBoard va Cai dat) ghi cung luc cung khong xen dong nhau.
    NSData *data = [line dataUsingEncoding:NSUTF8StringEncoding];
    if (!data) return;
    int fd = open([DWP_LOG_PATH fileSystemRepresentation], O_WRONLY | O_CREAT | O_APPEND, 0644);
    if (fd >= 0) {
        (void)write(fd, data.bytes, data.length);
        close(fd);
    }
}

static NSUserDefaults *DWPSuite(void) {
    return [[NSUserDefaults alloc] initWithSuiteName:DWP_BUNDLE_ID];
}

id _Nullable DWPPrefObject(NSString *key) {
    return [DWPSuite() objectForKey:key];
}

BOOL DWPPrefBool(NSString *key, BOOL fallback) {
    id v = DWPPrefObject(key);
    return v ? [v boolValue] : fallback;
}

NSInteger DWPPrefInt(NSString *key, NSInteger fallback) {
    id v = DWPPrefObject(key);
    return v ? [v integerValue] : fallback;
}

double DWPPrefDouble(NSString *key, double fallback) {
    id v = DWPPrefObject(key);
    return v ? [v doubleValue] : fallback;
}

NSString *DWPPrefString(NSString *key, NSString *fallback) {
    id v = DWPPrefObject(key);
    return [v isKindOfClass:[NSString class]] ? v : fallback;
}

void DWPSetPref(NSString *key, id value) {
    NSUserDefaults *suite = DWPSuite();
    [suite setObject:value forKey:key];
    [suite synchronize];
}

void DWPRemovePref(NSString *key) {
    NSUserDefaults *suite = DWPSuite();
    [suite removeObjectForKey:key];
    [suite synchronize];
}

void DWPPostDarwin(CFStringRef name) {
    CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(), name, NULL, NULL, true);
}

NSInteger DWPLanguage(void) {
    return DWPPrefInt(DWPKeyLanguage, 0);
}

NSString *DWPT(NSString *vi, NSString *en) {
    return DWPLanguage() == 1 ? en : vi;
}

NSString *DWPSlotPath(NSInteger slot) {
    return [DWP_PHOTOS_DIR stringByAppendingPathComponent:[NSString stringWithFormat:@"slot-%02ld.jpg", (long)slot]];
}

NSArray<NSNumber *> *DWPFilledSlots(void) {
    NSMutableArray<NSNumber *> *out = [NSMutableArray array];
    NSFileManager *fm = [NSFileManager defaultManager];
    for (NSInteger s = 1; s <= 31; s++) {
        if ([fm fileExistsAtPath:DWPSlotPath(s)]) [out addObject:@(s)];
    }
    return [out copy];
}

NSInteger DWPDaysInMonthForDate(NSDate *date) {
    NSCalendar *cal = [NSCalendar currentCalendar];
    NSRange r = [cal rangeOfUnit:NSCalendarUnitDay inUnit:NSCalendarUnitMonth forDate:date];
    return (NSInteger)r.length;
}

NSInteger DWPDaysInCurrentMonth(void) {
    return DWPDaysInMonthForDate([NSDate date]);
}

NSDate *DWPNextIntervalDate(NSDate *from, NSInteger value, NSInteger unit) {
    if (value < 1) value = 1;
    switch (unit) {
        case 0: return [from dateByAddingTimeInterval:(NSTimeInterval)value * 60.0];
        case 1: return [from dateByAddingTimeInterval:(NSTimeInterval)value * 3600.0];
        case 3: {
            NSDate *d = [[NSCalendar currentCalendar] dateByAddingUnit:NSCalendarUnitMonth value:value toDate:from options:0];
            return d ? d : [from dateByAddingTimeInterval:(NSTimeInterval)value * 30.0 * 86400.0];
        }
        case 2:
        default: return [from dateByAddingTimeInterval:(NSTimeInterval)value * 86400.0];
    }
}

#pragma mark - Anh

UIImage * _Nullable DWPWallpaperSizedImage(UIImage *src) {
    if (!src) return nil;
    CGSize target = CGSizeMake(1170, 2532);
    CGFloat scale = MAX(target.width / src.size.width, target.height / src.size.height);
    CGSize scaled = CGSizeMake(src.size.width * scale, src.size.height * scale);
    UIGraphicsImageRenderer *renderer = [[UIGraphicsImageRenderer alloc] initWithSize:target];
    return [renderer imageWithActions:^(UIGraphicsImageRendererContext *ctx) {
        [src drawInRect:CGRectMake((target.width - scaled.width) / 2.0, (target.height - scaled.height) / 2.0, scaled.width, scaled.height)];
    }];
}

NSInteger DWPSaveWallpaperImages(NSArray<UIImage *> *images, NSInteger replaceSlot) {
    NSFileManager *fm = [NSFileManager defaultManager];
    NSError *dirError = nil;
    [fm createDirectoryAtPath:DWP_PHOTOS_DIR withIntermediateDirectories:YES attributes:nil error:&dirError];
    if (dirError) {
        DWPLog(@"luu anh: KHONG tao duoc thu muc %@: %@", DWP_PHOTOS_DIR, dirError);
        return 0;
    }
    NSInteger saved = 0;
    if (replaceSlot > 0) {
        UIImage *sized = DWPWallpaperSizedImage(images.firstObject);
        NSData *data = sized ? UIImageJPEGRepresentation(sized, 0.85) : nil;
        NSError *err = nil;
        if (data && [data writeToFile:DWPSlotPath(replaceSlot) options:NSDataWritingAtomic error:&err]) {
            saved = 1;
            DWPLog(@"luu anh: da thay o %ld (%lu bytes)", (long)replaceSlot, (unsigned long)data.length);
        } else {
            DWPLog(@"luu anh: GHI THAT BAI o %ld: %@", (long)replaceSlot, err ? err : @"khong co du lieu JPEG");
        }
        return saved;
    }
    for (NSInteger s = 1; s <= 31; s++) [fm removeItemAtPath:DWPSlotPath(s) error:nil];
    NSInteger slot = 1;
    for (UIImage *img in images) {
        UIImage *sized = DWPWallpaperSizedImage(img);
        NSData *data = sized ? UIImageJPEGRepresentation(sized, 0.85) : nil;
        NSError *err = nil;
        if (data && [data writeToFile:DWPSlotPath(slot) options:NSDataWritingAtomic error:&err]) {
            saved++;
        } else {
            DWPLog(@"luu anh: GHI THAT BAI o %ld: %@", (long)slot, err ? err : @"khong co du lieu JPEG");
        }
        slot++;
        if (slot > 31) break;
    }
    DWPLog(@"luu anh: da luu %ld/%lu anh vao cac o", (long)saved, (unsigned long)images.count);
    return saved;
}

#pragma mark - Mau nen

NSArray<NSString *> *DWPPaletteHexes(void) {
    return @[@"#000000", @"#FFFFFF", @"#8E8E93", @"#E0392B", @"#F07D1A", @"#F2C41C",
             @"#2FA84F", @"#1E7FD9", @"#14264C", @"#7D3FD1", @"#E56AA1", @"#8A5A2B"];
}

NSArray<NSString *> *DWPGradientHexPairs(void) {
    return @[@"#FF9966/#FF5E62", @"#2193B0/#6DD5ED", @"#134E5E/#71B280", @"#8E2DE2/#4A00E0", @"#0F2027/#2C5364"];
}

UIColor * _Nullable DWPColorFromHex(NSString *hex) {
    if (![hex isKindOfClass:[NSString class]]) return nil;
    NSString *h = [[hex stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]] uppercaseString];
    if ([h hasPrefix:@"#"]) h = [h substringFromIndex:1];
    if (h.length != 6) return nil;
    unsigned int rgb = 0;
    if (![[NSScanner scannerWithString:h] scanHexInt:&rgb]) return nil;
    return [UIColor colorWithRed:((rgb >> 16) & 0xFF) / 255.0
                           green:((rgb >> 8) & 0xFF) / 255.0
                            blue:(rgb & 0xFF) / 255.0
                           alpha:1.0];
}

UIColor *DWPCurrentSolidColor(void) {
    NSString *hex = DWPPrefString(DWPKeyColorHex, @"");
    UIColor *custom = DWPColorFromHex(hex);
    if (custom) return custom;
    NSArray<NSString *> *palette = DWPPaletteHexes();
    NSInteger idx = DWPPrefInt(DWPKeyColorIndex, 8);
    if (idx < 0 || idx >= (NSInteger)palette.count) idx = 8;
    UIColor *c = DWPColorFromHex(palette[idx]);
    return c ? c : [UIColor blackColor];
}

UIImage *DWPSolidColorImage(UIColor *color) {
    CGSize target = CGSizeMake(1170, 2532);
    UIGraphicsImageRenderer *renderer = [[UIGraphicsImageRenderer alloc] initWithSize:target];
    return [renderer imageWithActions:^(UIGraphicsImageRendererContext *ctx) {
        [color setFill];
        UIRectFill(CGRectMake(0, 0, target.width, target.height));
    }];
}

UIImage *DWPGradientImage(NSInteger gradientIndex) {
    NSArray<NSString *> *pairs = DWPGradientHexPairs();
    NSInteger idx = gradientIndex;
    if (idx < 0 || idx >= (NSInteger)pairs.count) idx = 0;
    NSArray<NSString *> *parts = [pairs[idx] componentsSeparatedByString:@"/"];
    UIColor *top = parts.count > 0 ? DWPColorFromHex(parts[0]) : nil;
    UIColor *bottom = parts.count > 1 ? DWPColorFromHex(parts[1]) : nil;
    if (!top) top = [UIColor blackColor];
    if (!bottom) bottom = top;
    CGSize target = CGSizeMake(1170, 2532);
    UIGraphicsImageRenderer *renderer = [[UIGraphicsImageRenderer alloc] initWithSize:target];
    return [renderer imageWithActions:^(UIGraphicsImageRendererContext *ctx) {
        CGContextRef g = ctx.CGContext;
        CGColorSpaceRef space = CGColorSpaceCreateDeviceRGB();
        CGGradientRef gradient = CGGradientCreateWithColors(space,
            (__bridge CFArrayRef)@[ (id)top.CGColor, (id)bottom.CGColor ], NULL);
        CGContextDrawLinearGradient(g, gradient, CGPointMake(0, 0), CGPointMake(target.width, target.height), 0);
        CGGradientRelease(gradient);
        CGColorSpaceRelease(space);
    }];
}

#pragma mark - Xuat / nhap cai dat

NSArray<NSString *> *DWPUserSettingKeys(void) {
    return @[DWPKeyEnabled, DWPKeyTarget, DWPKeyRotationMode, DWPKeyOrderMode,
             DWPKeyIntervalValue, DWPKeyIntervalUnit, DWPKeyScheduleHour, DWPKeyScheduleMinute,
             DWPKeyLanguage, DWPKeySourceMode, DWPKeyColorIndex, DWPKeyColorHex,
             DWPKeyColorRotate, DWPKeyGradientIndex, DWPKeyDarkenPercent, DWPKeyBlurLevel,
             DWPKeyLowBatteryGuard];
}

NSDictionary *DWPExportSettings(void) {
    NSMutableDictionary *out = [NSMutableDictionary dictionary];
    out[@"_app"] = DWP_BUNDLE_ID;
    out[@"_version"] = DWP_VERSION;
    for (NSString *key in DWPUserSettingKeys()) {
        id v = DWPPrefObject(key);
        if (v) out[key] = v;
    }
    return [out copy];
}

NSInteger DWPImportSettings(NSDictionary *dict) {
    if (![dict isKindOfClass:[NSDictionary class]]) return 0;
    NSInteger applied = 0;
    for (NSString *key in DWPUserSettingKeys()) {
        id v = dict[key];
        if (v) {
            DWPSetPref(key, v);
            applied++;
        }
    }
    DWPLog(@"nhap cai dat: da ap %ld khoa", (long)applied);
    return applied;
}

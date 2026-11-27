// DWPShared.m — DailyWallpaperPro 1.0.1

#import "DWPShared.h"
#import <CoreFoundation/CoreFoundation.h>

NSString * const DWPKeyEnabled = @"enabled";
NSString * const DWPKeyTarget = @"target";
NSString * const DWPKeyRotationMode = @"rotationMode";
NSString * const DWPKeyOrderMode = @"orderMode";
NSString * const DWPKeyIntervalValue = @"intervalValue";
NSString * const DWPKeyIntervalUnit = @"intervalUnit";
NSString * const DWPKeyScheduleHour = @"scheduleHour";
NSString * const DWPKeyScheduleMinute = @"scheduleMinute";
NSString * const DWPKeyLastChange = @"lastChange";
NSString * const DWPKeyLastDay = @"lastDay";
NSString * const DWPKeyCurrentSlot = @"currentSlot";

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
    NSFileHandle *fh = [NSFileHandle fileHandleForWritingAtPath:DWP_LOG_PATH];
    if (!fh) {
        [[NSFileManager defaultManager] createFileAtPath:DWP_LOG_PATH contents:nil attributes:nil];
        fh = [NSFileHandle fileHandleForWritingAtPath:DWP_LOG_PATH];
    }
    if (fh) {
        [fh seekToEndOfFile];
        NSData *data = [line dataUsingEncoding:NSUTF8StringEncoding];
        if (data) [fh writeData:data];
        [fh closeFile];
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

void DWPPostDarwin(CFStringRef name) {
    CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(), name, NULL, NULL, true);
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

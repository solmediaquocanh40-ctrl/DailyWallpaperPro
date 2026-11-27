// DWPEngine.m — DailyWallpaperPro 1.0.0

#import "DWPEngine.h"
#import "DWPShared.h"
#import <objc/runtime.h>

// Khai bao cac class he thong khong co header trong SDK Theos.
// Moi loi goi deu qua respondsToSelector truoc — khai bao o day chi de
// trinh bien dich chap nhan, class/method khong ton tai luc chay se bi bo qua.
@interface SBWallpaperController : NSObject
+ (instancetype)sharedInstance;
- (void)setWallpaperForLocations:(NSInteger)locations image:(UIImage *)image;
- (void)setWallpaperWithImage:(UIImage *)image forLocations:(NSInteger)locations save:(BOOL)save;
- (void)setWallpaperWithImage:(UIImage *)image forVariant:(NSInteger)variant;
- (void)setWallpaperVariant:(NSInteger)variant withConfiguration:(id)configuration;
- (id)wallpaperConfigurationManager;
@end

@interface SBFWallpaperConfiguration : NSObject
- (instancetype)initWithVariant:(NSInteger)variant;
@end

@implementation DWPEngine

+ (void)dumpDiagnostics {
    NSArray<NSString *> *classNames = @[@"SBWallpaperController",
                                        @"SBFWallpaperConfiguration",
                                        @"SBFWallpaperConfigurationManager",
                                        @"SBWallpaperConfigurationManager",
                                        @"SBWallpaperView",
                                        @"WFWallpaperConfigurationManager"];
    for (NSString *name in classNames) {
        Class cls = objc_getClass([name UTF8String]);
        DWPLog(@"engine dump: class %@ = %@", name, cls ? @"CO" : @"KHONG CO");
        if (!cls) continue;
        unsigned int count = 0;
        Method *methods = class_copyMethodList(cls, &count);
        NSInteger shown = 0;
        for (unsigned int i = 0; i < count && shown < 60; i++) {
            NSString *sel = NSStringFromSelector(method_getName(methods[i]));
            NSString *low = [sel lowercaseString];
            if ([low containsString:@"wallpaper"] || [low containsString:@"image"] || [low hasPrefix:@"set"]) {
                DWPLog(@"engine dump:   -[%@ %@]", name, sel);
                shown++;
            }
        }
        if (methods) free(methods);
        unsigned int pcount = 0;
        objc_property_t *props = class_copyPropertyList(cls, &pcount);
        for (unsigned int i = 0; i < pcount && i < 40; i++) {
            DWPLog(@"engine dump:   prop %@.%s", name, property_getName(props[i]));
        }
        if (props) free(props);
    }
}

// Thu 1 duong: tra YES neu selector ton tai va goi khong nem ngoai le.
+ (BOOL)tryController:(SBWallpaperController *)controller selector:(SEL)sel logName:(NSString *)logName call:(void (^)(void))call {
    if (![controller respondsToSelector:sel]) {
        DWPLog(@"engine: duong %@ — selector khong ton tai, bo qua", logName);
        return NO;
    }
    @try {
        call();
        DWPLog(@"engine: duong %@ — da goi, khong loi luc chay", logName);
        return YES;
    } @catch (NSException *e) {
        DWPLog(@"engine: duong %@ — NGOAI LE %@: %@", logName, e.name, e.reason);
        return NO;
    }
}

+ (BOOL)applyImage:(UIImage *)image target:(NSInteger)target {
    if (!image) { DWPLog(@"engine: anh nil, dung"); return NO; }
    Class cls = objc_getClass("SBWallpaperController");
    if (!cls) { DWPLog(@"engine: KHONG co class SBWallpaperController"); return NO; }
    SBWallpaperController *controller = nil;
    @try { controller = [cls sharedInstance]; } @catch (NSException *e) { controller = nil; }
    if (!controller) { DWPLog(@"engine: sharedInstance tra nil"); return NO; }

    // Locations bitmask (gia thuyet pho bien): 1=Khoa, 2=Chinh, 3=Both
    NSInteger locations = (target == 0) ? 1 : (target == 1) ? 2 : 3;
    // Variant (gia thuyet pho bien): 1=Khoa, 2=Chinh
    NSArray<NSNumber *> *variants = (target == 0) ? @[@1] : (target == 1) ? @[@2] : @[@1, @2];

    BOOL ok = NO;

    ok = [self tryController:controller selector:@selector(setWallpaperForLocations:image:) logName:@"setWallpaperForLocations:image:" call:^{
        [controller setWallpaperForLocations:locations image:image];
    }] || ok;

    ok = [self tryController:controller selector:@selector(setWallpaperWithImage:forLocations:save:) logName:@"setWallpaperWithImage:forLocations:save:" call:^{
        [controller setWallpaperWithImage:image forLocations:locations save:YES];
    }] || ok;

    if ([controller respondsToSelector:@selector(setWallpaperWithImage:forVariant:)]) {
        for (NSNumber *v in variants) {
            NSInteger variant = [v integerValue];
            ok = [self tryController:controller selector:@selector(setWallpaperWithImage:forVariant:) logName:[NSString stringWithFormat:@"setWallpaperWithImage:forVariant:%ld", (long)variant] call:^{
                [controller setWallpaperWithImage:image forVariant:variant];
            }] || ok;
        }
    } else {
        DWPLog(@"engine: duong setWallpaperWithImage:forVariant: — selector khong ton tai, bo qua");
    }

    if ([controller respondsToSelector:@selector(setWallpaperVariant:withConfiguration:)]) {
        Class cfgCls = objc_getClass("SBFWallpaperConfiguration");
        if (cfgCls) {
            for (NSNumber *v in variants) {
                NSInteger variant = [v integerValue];
                @try {
                    SBFWallpaperConfiguration *cfg = [[cfgCls alloc] initWithVariant:variant];
                    if (cfg) {
                        // Chi gan anh vao property nao class that su co.
                        unsigned int pcount = 0;
                        objc_property_t *props = class_copyPropertyList(cfgCls, &pcount);
                        NSMutableSet<NSString *> *propNames = [NSMutableSet set];
                        for (unsigned int i = 0; i < pcount; i++) [propNames addObject:[NSString stringWithUTF8String:property_getName(props[i])]];
                        if (props) free(props);
                        for (NSString *key in @[@"image", @"wallpaperImage", @"lockScreenImage", @"homeScreenImage"]) {
                            if ([propNames containsObject:key]) {
                                [cfg setValue:image forKey:key];
                                DWPLog(@"engine: config variant %ld — da gan anh vao property %@", (long)variant, key);
                            }
                        }
                        [controller setWallpaperVariant:variant withConfiguration:cfg];
                        DWPLog(@"engine: duong setWallpaperVariant:%ld withConfiguration: — da goi, khong loi luc chay", (long)variant);
                        ok = YES;
                    }
                } @catch (NSException *e) {
                    DWPLog(@"engine: duong config variant %ld — NGOAI LE %@: %@", (long)variant, e.name, e.reason);
                }
            }
        } else {
            DWPLog(@"engine: duong config — KHONG co class SBFWallpaperConfiguration");
        }
    } else {
        DWPLog(@"engine: duong setWallpaperVariant:withConfiguration: — selector khong ton tai, bo qua");
    }

    DWPLog(@"engine: tong ket apply target=%ld -> %@", (long)target, ok ? @"CO duong nhan lenh" : @"KHONG duong nao nhan lenh");
    return ok;
}

@end

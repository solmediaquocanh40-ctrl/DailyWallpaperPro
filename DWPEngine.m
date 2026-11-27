// DWPEngine.m — DailyWallpaperPro 1.0.7

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
- (void)updateWallpaperForLocations:(NSInteger)locations withCompletion:(id)completion;
- (void)wallpaperServer:(id)server setWallpaperColor:(id)color darkColor:(id)darkColor forVariants:(id)variants completionHandler:(id)handler;
@end

@interface SBFWallpaperConfigurationManager : NSObject
- (id)wallpaperConfigurationForVariant:(NSInteger)variant includingValuesForTypes:(NSInteger)types;
@end

@interface SBFWallpaperConfiguration : NSObject
- (instancetype)initWithVariant:(NSInteger)variant;
@end

@implementation DWPEngine

+ (void)dumpDiagnostics {
    NSArray<NSString *> *classNames = @[@"SBWallpaperController",
                                        @"SBFWallpaperConfiguration",
                                        @"SBFWallpaperConfigurationManager",
                                        @"SBFWallpaperOptions",
                                        @"SBWallpaperServer",
                                        @"PBWallpaperServer",
                                        @"WFWallpaperServer"];
    for (NSString *name in classNames) {
        Class cls = objc_getClass([name UTF8String]);
        DWPLog(@"engine dump: class %@ = %@", name, cls ? @"CO" : @"KHONG CO");
        if (!cls) continue;
        unsigned int count = 0;
        Method *methods = class_copyMethodList(cls, &count);
        for (unsigned int i = 0; i < count; i++) {
            DWPLog(@"engine dump:   -[%@ %@]", name, NSStringFromSelector(method_getName(methods[i])));
        }
        if (methods) free(methods);
        unsigned int mcount = 0;
        Method *mmethods = class_copyMethodList(object_getClass(cls), &mcount);
        for (unsigned int i = 0; i < mcount; i++) {
            DWPLog(@"engine dump:   +[%@ %@]", name, NSStringFromSelector(method_getName(mmethods[i])));
        }
        if (mmethods) free(mmethods);
        unsigned int pcount = 0;
        objc_property_t *props = class_copyPropertyList(cls, &pcount);
        for (unsigned int i = 0; i < pcount; i++) {
            DWPLog(@"engine dump:   prop %@.%s", name, property_getName(props[i]));
        }
        if (props) free(props);
        unsigned int icount = 0;
        Ivar *ivars = class_copyIvarList(cls, &icount);
        for (unsigned int i = 0; i < icount; i++) {
            DWPLog(@"engine dump:   ivar %@.%s", name, ivar_getName(ivars[i]));
        }
        if (ivars) free(ivars);
    }
}

+ (SBWallpaperController *)sharedController {
    Class cls = objc_getClass("SBWallpaperController");
    if (!cls) { DWPLog(@"engine: KHONG co class SBWallpaperController"); return nil; }
    SBWallpaperController *controller = nil;
    @try { controller = [cls sharedInstance]; } @catch (NSException *e) { controller = nil; }
    if (!controller) DWPLog(@"engine: sharedInstance tra nil");
    return controller;
}

// Thu 1 duong legacy: tra YES neu selector ton tai va goi khong nem ngoai le.
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

// Duong E1 (moi, theo dump 1.0.1): lay configuration hien tai cua tung variant
// tu wallpaperConfigurationManager, gan anh vao property wallpaperImage bang
// KVC, roi goi updateWallpaperForLocations:withCompletion: de he thong ap lai.
+ (BOOL)applyViaConfiguration:(SBWallpaperController *)controller image:(UIImage *)image target:(NSInteger)target {
    if (![controller respondsToSelector:@selector(wallpaperConfigurationManager)]) {
        DWPLog(@"engine E1: controller khong co wallpaperConfigurationManager, bo qua");
        return NO;
    }
    id rawManager = nil;
    @try { rawManager = [controller wallpaperConfigurationManager]; } @catch (NSException *e) {
        DWPLog(@"engine E1: lay manager NGOAI LE %@: %@", e.name, e.reason);
        return NO;
    }
    if (!rawManager) { DWPLog(@"engine E1: manager = nil"); return NO; }
    DWPLog(@"engine E1: manager class = %@", NSStringFromClass([rawManager class]));
    if (![rawManager respondsToSelector:@selector(wallpaperConfigurationForVariant:includingValuesForTypes:)]) {
        DWPLog(@"engine E1: manager khong co wallpaperConfigurationForVariant:includingValuesForTypes:");
        return NO;
    }
    SBFWallpaperConfigurationManager *manager = (SBFWallpaperConfigurationManager *)rawManager;
    NSArray<NSArray<NSNumber *> *> *variantSets = nil;
    if (target == 0) variantSets = @[@[@0], @[@1]];
    else if (target == 1) variantSets = @[@[@1], @[@2]];
    else variantSets = @[@[@0, @1], @[@1, @2]];

    for (NSArray<NSNumber *> *set in variantSets) {
        BOOL anyConfig = NO;
        BOOL anySet = NO;
        for (NSNumber *v in set) {
            NSInteger variant = [v integerValue];
            id cfg = nil;
            for (NSNumber *t in @[@3, @0, @(-1)]) {
                @try {
                    cfg = [manager wallpaperConfigurationForVariant:variant includingValuesForTypes:[t integerValue]];
                } @catch (NSException *e) {
                    DWPLog(@"engine E1: lay config variant %ld types %ld NGOAI LE %@: %@", (long)variant, (long)[t integerValue], e.name, e.reason);
                    cfg = nil;
                }
                if (cfg) break;
            }
            if (!cfg) {
                DWPLog(@"engine E1: variant %ld khong lay duoc configuration", (long)variant);
                continue;
            }
            anyConfig = YES;
            DWPLog(@"engine E1: variant %ld configuration class = %@", (long)variant, NSStringFromClass([cfg class]));
            @try {
                [cfg setValue:image forKey:@"wallpaperImage"];
                anySet = YES;
                DWPLog(@"engine E1: variant %ld da gan wallpaperImage bang KVC", (long)variant);
            } @catch (NSException *e) {
                DWPLog(@"engine E1: variant %ld gan wallpaperImage THAT BAI %@: %@", (long)variant, e.name, e.reason);
            }
        }
        if (anyConfig) {
            if ([controller respondsToSelector:@selector(updateWallpaperForLocations:withCompletion:)]) {
                NSInteger locations = (target == 0) ? 1 : (target == 1) ? 2 : 3;
                @try {
                    [controller updateWallpaperForLocations:locations withCompletion:^(id result) {
                        DWPLog(@"engine E1: updateWallpaperForLocations completion da goi lai");
                    }];
                    DWPLog(@"engine E1: da goi updateWallpaperForLocations:%ld", (long)locations);
                } @catch (NSException *e) {
                    DWPLog(@"engine E1: updateWallpaper NGOAI LE %@: %@", e.name, e.reason);
                }
            } else {
                DWPLog(@"engine E1: controller khong co updateWallpaperForLocations:withCompletion:");
            }
            return anySet;
        }
    }
    return NO;
}

+ (BOOL)applyImage:(UIImage *)image target:(NSInteger)target {
    if (!image) { DWPLog(@"engine: anh nil, dung"); return NO; }
    SBWallpaperController *controller = [self sharedController];
    if (!controller) return NO;

    BOOL ok = NO;
    ok = [self applyViaConfiguration:controller image:image target:target] || ok;

    // Cac duong legacy (1.0.1 da chung minh khong ton tai tren iOS 16.3.1,
    // giu lai re vi chi la respondsToSelector — ban sau se bo han neu E1 dung).
    NSInteger locations = (target == 0) ? 1 : (target == 1) ? 2 : 3;
    NSArray<NSNumber *> *variants = (target == 0) ? @[@1] : (target == 1) ? @[@2] : @[@1, @2];

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
    }

    if ([controller respondsToSelector:@selector(setWallpaperVariant:withConfiguration:)]) {
        Class cfgCls = objc_getClass("SBFWallpaperConfiguration");
        if (cfgCls) {
            for (NSNumber *v in variants) {
                NSInteger variant = [v integerValue];
                @try {
                    SBFWallpaperConfiguration *cfg = [[cfgCls alloc] initWithVariant:variant];
                    if (cfg) {
                        [cfg setValue:image forKey:@"wallpaperImage"];
                        [controller setWallpaperVariant:variant withConfiguration:cfg];
                        DWPLog(@"engine: duong setWallpaperVariant:%ld withConfiguration: — da goi", (long)variant);
                        ok = YES;
                    }
                } @catch (NSException *e) {
                    DWPLog(@"engine: duong config variant %ld — NGOAI LE %@: %@", (long)variant, e.name, e.reason);
                }
            }
        }
    }

    DWPLog(@"engine: tong ket apply anh target=%ld -> %@", (long)target, ok ? @"CO duong nhan lenh" : @"KHONG duong nao nhan lenh");
    return ok;
}

+ (BOOL)applyColorNative:(UIColor *)color target:(NSInteger)target {
    if (!color) { DWPLog(@"engine mau: mau nil, dung"); return NO; }
    SBWallpaperController *controller = [self sharedController];
    if (!controller) return NO;
    SEL sel = @selector(wallpaperServer:setWallpaperColor:darkColor:forVariants:completionHandler:);
    if (![controller respondsToSelector:sel]) {
        DWPLog(@"engine mau: selector setWallpaperColor khong ton tai, bo qua");
        return NO;
    }
    CGFloat r = 0, g = 0, b = 0, a = 1;
    UIColor *dark = color;
    if ([color getRed:&r green:&g blue:&b alpha:&a]) {
        dark = [UIColor colorWithRed:r * 0.7 green:g * 0.7 blue:b * 0.7 alpha:a];
    }
    NSMutableIndexSet *variants = [NSMutableIndexSet indexSet];
    if (target == 0 || target == 2) [variants addIndex:0];
    if (target == 1 || target == 2) [variants addIndex:1];
    DWPLog(@"engine mau: chuan bi goi setWallpaperColor variants=%@ (0=khoa, 1=chinh)", variants);
    @try {
        [controller wallpaperServer:nil setWallpaperColor:color darkColor:dark forVariants:variants completionHandler:^(id result) {
            DWPLog(@"engine mau: completion da goi lai");
        }];
        DWPLog(@"engine mau: da goi setWallpaperColor, khong loi luc chay");
        return YES;
    } @catch (NSException *e) {
        DWPLog(@"engine mau: NGOAI LE %@: %@", e.name, e.reason);
        return NO;
    }
}

@end

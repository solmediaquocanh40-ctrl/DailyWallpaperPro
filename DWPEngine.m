// DWPEngine.m — DailyWallpaperPro 1.0.8

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
- (void)_updateForLockScreenPosterConfiguration:(id)lockConfiguration homeScreenPosterConfiguration:(id)homeConfiguration;
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
                                        @"WFWallpaperServer",
                                        @"PBUIWallpaperConfigurationManager",
                                        @"PBUIWallpaperConfiguration",
                                        @"PRSPosterConfiguration",
                                        @"PRSPosterDescriptor"];
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

// Lay configuration cua 1 variant, thu lan luot cac muc types 3 -> 0 -> -1.
+ (id)fetchConfiguration:(id)manager variant:(NSInteger)variant {
    SBFWallpaperConfigurationManager *mgr = (SBFWallpaperConfigurationManager *)manager;
    for (NSNumber *t in @[@3, @0, @(-1)]) {
        id cfg = nil;
        @try {
            cfg = [mgr wallpaperConfigurationForVariant:variant includingValuesForTypes:[t integerValue]];
        } @catch (NSException *e) {
            DWPLog(@"engine: lay config variant %ld types %ld NGOAI LE %@: %@", (long)variant, (long)[t integerValue], e.name, e.reason);
            cfg = nil;
        }
        if (cfg) {
            DWPLog(@"engine: lay duoc config variant %ld voi types %ld (class %@)", (long)variant, (long)[t integerValue], NSStringFromClass([cfg class]));
            return cfg;
        }
    }
    DWPLog(@"engine: variant %ld khong lay duoc configuration o moi types", (long)variant);
    return nil;
}

// Doc lai wallpaperImage cua config SAU khi ap (tre 1.5 giay) de phan dinh:
// anh moi con nam trong config khong, hay chi la ban sao tam thoi.
+ (void)readBackConfiguration:(id)manager variant:(NSInteger)variant appliedImage:(UIImage *)image tag:(NSString *)tag {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        id cfg = [self fetchConfiguration:manager variant:variant];
        if (!cfg) { DWPLog(@"engine %@: doc lai variant %ld — khong lay duoc config", tag, (long)variant); return; }
        id current = nil;
        @try { current = [cfg valueForKey:@"wallpaperImage"]; } @catch (NSException *e) { current = nil; }
        if ([current isKindOfClass:[UIImage class]]) {
            UIImage *cur = (UIImage *)current;
            BOOL same = (NSInteger)cur.size.width == (NSInteger)image.size.width &&
                        (NSInteger)cur.size.height == (NSInteger)image.size.height;
            DWPLog(@"engine %@: doc lai variant %ld — config dang giu anh %lux%lu, anh vua ap %lux%lu -> %@",
                   tag, (long)variant, (unsigned long)cur.size.width, (unsigned long)cur.size.height,
                   (unsigned long)image.size.width, (unsigned long)image.size.height,
                   same ? @"TRUNG KICH THUOC (anh moi da vao config)" : @"KHAC (config giu anh khac)");
        } else {
            DWPLog(@"engine %@: doc lai variant %ld — wallpaperImage = %@", tag, (long)variant, current ?: @"nil");
        }
    });
}

// Duong E2 (1.0.8, theo dump 1.0.7): SBWallpaperController co method noi bo
// _updateForLockScreenPosterConfiguration:homeScreenPosterConfiguration: —
// duong he thong tu dung khi poster thay doi. Gan anh vao config cua tung
// phia roi dua ca 2 config cho controller tu ap (phia khong doi thi dua
// config hien tai nguyen ven).
+ (BOOL)applyViaPosterUpdate:(SBWallpaperController *)controller manager:(id)manager image:(UIImage *)image target:(NSInteger)target {
    SEL sel = @selector(_updateForLockScreenPosterConfiguration:homeScreenPosterConfiguration:);
    if (![controller respondsToSelector:sel]) {
        DWPLog(@"engine E2: controller khong co _updateForLockScreenPosterConfiguration, bo qua");
        return NO;
    }
    id lockCfg = [self fetchConfiguration:manager variant:0];
    id homeCfg = [self fetchConfiguration:manager variant:1];
    if (!lockCfg && !homeCfg) { DWPLog(@"engine E2: khong lay duoc config nao, bo qua"); return NO; }
    BOOL setAny = NO;
    if ((target == 0 || target == 2) && lockCfg) {
        @try { [lockCfg setValue:image forKey:@"wallpaperImage"]; setAny = YES; DWPLog(@"engine E2: da gan anh vao config KHOA (variant 0)"); }
        @catch (NSException *e) { DWPLog(@"engine E2: gan anh config khoa THAT BAI %@: %@", e.name, e.reason); }
    }
    if ((target == 1 || target == 2) && homeCfg) {
        @try { [homeCfg setValue:image forKey:@"wallpaperImage"]; setAny = YES; DWPLog(@"engine E2: da gan anh vao config CHINH (variant 1)"); }
        @catch (NSException *e) { DWPLog(@"engine E2: gan anh config chinh THAT BAI %@: %@", e.name, e.reason); }
    }
    if (!setAny) return NO;
    @try {
        [controller _updateForLockScreenPosterConfiguration:lockCfg homeScreenPosterConfiguration:homeCfg];
        DWPLog(@"engine E2: da goi _updateForLockScreenPosterConfiguration (lock=%@, home=%@)",
               lockCfg ? @"co" : @"nil", homeCfg ? @"co" : @"nil");
    } @catch (NSException *e) {
        DWPLog(@"engine E2: goi update poster NGOAI LE %@: %@", e.name, e.reason);
        return NO;
    }
    if (target == 0 || target == 2) [self readBackConfiguration:manager variant:0 appliedImage:image tag:@"E2"];
    if (target == 1 || target == 2) [self readBackConfiguration:manager variant:1 appliedImage:image tag:@"E2"];
    return YES;
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
            if (anySet) {
                for (NSNumber *v in set) {
                    [self readBackConfiguration:rawManager variant:[v integerValue] appliedImage:image tag:@"E1"];
                }
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

    // Duong E2 (1.0.8): dua thang 2 poster configuration cho controller tu ap
    if ([controller respondsToSelector:@selector(wallpaperConfigurationManager)]) {
        id mgr = nil;
        @try { mgr = [controller wallpaperConfigurationManager]; } @catch (NSException *e) { mgr = nil; }
        if (mgr) ok = [self applyViaPosterUpdate:controller manager:mgr image:image target:target] || ok;
    }

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

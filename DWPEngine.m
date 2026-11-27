// DWPEngine.m — DailyWallpaperPro 1.0.11

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
- (void)_kickPosterBoard;
- (void)wallpaperServer:(id)server setWallpaperColor:(id)color darkColor:(id)darkColor forVariants:(id)variants completionHandler:(id)handler;
@end

@interface SBFWallpaperConfigurationManager : NSObject
- (id)wallpaperConfigurationForVariant:(NSInteger)variant includingValuesForTypes:(NSInteger)types;
@end

@interface SBFWallpaperConfiguration : NSObject
- (instancetype)initWithVariant:(NSInteger)variant;
@end

// Manager that tren iOS 16.3.1 (dump 1.0.11): PBUIWallpaperConfigurationManager
// — chua API ghi anh that vao kho nen cua he thong.
@interface PBUIWallpaperConfigurationManager : NSObject
- (id)wallpaperConfigurationForVariant:(NSInteger)variant includingValuesForTypes:(NSInteger)types;
- (void)setWallpaperImage:(UIImage *)image adjustedImage:(UIImage *)adjustedImage thumbnailData:(NSData *)thumbnailData imageHashData:(NSData *)imageHashData wallpaperOptions:(id)wallpaperOptions forVariants:(NSIndexSet *)variants wallpaperMode:(NSInteger)wallpaperMode;
- (void)wallpaperDidChangeForVariants:(NSIndexSet *)variants shouldNotify:(BOOL)shouldNotify;
- (void)beginChangeBatch;
- (void)endChangeBatch;
- (NSInteger)wallpaperMode;
- (BOOL)hasWallpaperImageForVariant:(NSInteger)variant wallpaperMode:(NSInteger)mode;
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
    for (NSNumber *t in @[@(-1), @3, @0]) {
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

// Duong E3 (1.0.9, theo dump 1.0.8): PBUIWallpaperConfigurationManager co
// API ghi anh that vao kho nen cua he thong:
//   setWallpaperImage:adjustedImage:thumbnailData:imageHashData:
//   wallpaperOptions:forVariants:wallpaperMode:
// Day la method cua CHINH manager (cung ho PaperBoardUI voi config no
// quan ly) — khac han E2 da gay Safe Mode (E2 dua config cua manager nay
// cho SBWallpaperController nhan nham kieu poster configuration).
// CHI chay qua applyImageExperimental (nut Test), khong chay tu dong.
+ (BOOL)applyViaManagerSetImage:(SBWallpaperController *)controller image:(UIImage *)image target:(NSInteger)target {
    if (![controller respondsToSelector:@selector(wallpaperConfigurationManager)]) {
        DWPLog(@"engine E3: controller khong co wallpaperConfigurationManager, bo qua");
        return NO;
    }
    id rawManager = nil;
    @try { rawManager = [controller wallpaperConfigurationManager]; } @catch (NSException *e) { rawManager = nil; }
    if (!rawManager) { DWPLog(@"engine E3: manager = nil"); return NO; }
    Class pbuiCls = objc_getClass("PBUIWallpaperConfigurationManager");
    if (!pbuiCls || ![rawManager isKindOfClass:pbuiCls]) {
        DWPLog(@"engine E3: manager class %@ khong phai PBUIWallpaperConfigurationManager, dung cho an toan", NSStringFromClass([rawManager class]));
        return NO;
    }
    PBUIWallpaperConfigurationManager *manager = (PBUIWallpaperConfigurationManager *)rawManager;
    SEL setSel = @selector(setWallpaperImage:adjustedImage:thumbnailData:imageHashData:wallpaperOptions:forVariants:wallpaperMode:);
    if (![manager respondsToSelector:setSel]) {
        DWPLog(@"engine E3: manager khong co setWallpaperImage:..., bo qua");
        return NO;
    }
    NSInteger mode = 0;
    @try { mode = [manager wallpaperMode]; } @catch (NSException *e) { mode = 0; }
    // MOC TRUOC KHI SET (1.0.11): lay config day du gia tri (types -1) lam
    // moc doi chieu + lay wallpaperOptions THAT (ban 1.0.10 fetch types 3
    // nen ca anh lan options deu nil — phep doc lai cu do sai vi thieu
    // bitmask gia tri, khong phai vi kho khong co anh).
    NSInteger firstVariant = (target == 1) ? 1 : 0;
    id cfg = [self fetchConfiguration:manager variant:firstVariant];
    id options = nil;
    @try { options = [cfg valueForKey:@"wallpaperOptions"]; } @catch (NSException *e) { options = nil; }
    @try {
        UIImage *baseImg = [cfg valueForKey:@"wallpaperImage"];
        DWPLog(@"engine E3: MOC truoc set — variant %ld wallpaperImage = %@, options = %@, hasImage(mode %ld) = %d/%d",
               (long)firstVariant,
               baseImg ? [NSString stringWithFormat:@"%.0fx%.0f", baseImg.size.width, baseImg.size.height] : @"nil",
               options ? NSStringFromClass([options class]) : @"nil", (long)mode,
               [manager hasWallpaperImageForVariant:0 wallpaperMode:mode],
               [manager hasWallpaperImageForVariant:1 wallpaperMode:mode]);
    } @catch (NSException *e) {
        DWPLog(@"engine E3: moc truoc set NGOAI LE %@: %@", e.name, e.reason);
    }
    CGSize ts = CGSizeMake(270, 480);
    UIGraphicsImageRenderer *renderer = [[UIGraphicsImageRenderer alloc] initWithSize:ts];
    UIImage *thumb = [renderer imageWithActions:^(UIGraphicsImageRendererContext *ctx) {
        [image drawInRect:CGRectMake(0, 0, ts.width, ts.height)];
    }];
    NSData *thumbData = UIImageJPEGRepresentation(thumb, 0.8);
    NSData *fullData = UIImageJPEGRepresentation(image, 0.85);
    NSMutableIndexSet *variants = [NSMutableIndexSet indexSet];
    if (target == 0 || target == 2) [variants addIndex:0];
    if (target == 1 || target == 2) [variants addIndex:1];
    DWPLog(@"engine E3: chuan bi setWallpaperImage (mode %ld, variants %@, thumb %lu byte, full %lu byte, options %@)",
           (long)mode, variants, (unsigned long)thumbData.length, (unsigned long)fullData.length,
           options ? NSStringFromClass([options class]) : @"nil");
    @try {
        if ([manager respondsToSelector:@selector(beginChangeBatch)]) [manager beginChangeBatch];
        [manager setWallpaperImage:image adjustedImage:image thumbnailData:thumbData
                   imageHashData:fullData wallpaperOptions:options
                     forVariants:variants wallpaperMode:mode];
        if ([manager respondsToSelector:@selector(endChangeBatch)]) [manager endChangeBatch];
        DWPLog(@"engine E3: da goi setWallpaperImage — khong loi luc chay");
    } @catch (NSException *e) {
        DWPLog(@"engine E3: NGOAI LE %@: %@", e.name, e.reason);
        return NO;
    }
    @try {
        if ([manager respondsToSelector:@selector(wallpaperDidChangeForVariants:shouldNotify:)]) {
            [manager wallpaperDidChangeForVariants:variants shouldNotify:YES];
            DWPLog(@"engine E3: da goi wallpaperDidChangeForVariants:shouldNotify:YES");
        }
    } @catch (NSException *e) {
        DWPLog(@"engine E3: wallpaperDidChange NGOAI LE %@: %@", e.name, e.reason);
    }
    // Buoc day sau set (1.0.11): nho controller cap nhat lai cac vi tri va
    // "da" PosterBoard doc lai — lop poster cua iOS 16 co the khong tu doc
    // lai kho PBUI neu khong co su kien nay.
    @try {
        if ([controller respondsToSelector:@selector(updateWallpaperForLocations:withCompletion:)]) {
            [controller updateWallpaperForLocations:3 withCompletion:nil];
            DWPLog(@"engine E3: da goi them updateWallpaperForLocations:3 sau set");
        }
        if ([controller respondsToSelector:@selector(_kickPosterBoard)]) {
            [controller _kickPosterBoard];
            DWPLog(@"engine E3: da goi _kickPosterBoard");
        } else {
            DWPLog(@"engine E3: controller khong co _kickPosterBoard");
        }
    } @catch (NSException *e) {
        DWPLog(@"engine E3: buoc day sau set NGOAI LE %@: %@", e.name, e.reason);
    }
    @try {
        DWPLog(@"engine E3: hasImage SAU set (mode %ld) = %d/%d", (long)mode,
               [manager hasWallpaperImageForVariant:0 wallpaperMode:mode],
               [manager hasWallpaperImageForVariant:1 wallpaperMode:mode]);
    } @catch (NSException *e) { }
    if (target == 0 || target == 2) [self readBackConfiguration:manager variant:0 appliedImage:image tag:@"E3"];
    if (target == 1 || target == 2) [self readBackConfiguration:manager variant:1 appliedImage:image tag:@"E3"];
    return YES;
}

+ (BOOL)applyImageExperimental:(UIImage *)image target:(NSInteger)target {
    if (!image) { DWPLog(@"engine E3: anh nil, dung"); return NO; }
    SBWallpaperController *controller = [self sharedController];
    if (!controller) return NO;
    DWPLog(@"engine: nut Test dang thu duong E3 (target %ld)", (long)target);
    return [self applyViaManagerSetImage:controller image:image target:target];
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
            for (NSNumber *t in @[@(-1), @3, @0]) {
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

    // (E2 da bi XOA o 1.0.9 — gay Safe Mode, xem .ips 2026-11-27 16:18.)

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

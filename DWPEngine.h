// DWPEngine.h — DailyWallpaperPro 1.0.8
// Engine doi hinh nen tren iOS 16. Log may that cua ban 1.0.1 da chung minh:
// SBWallpaperController KHONG con bat ky method setWallpaperWithImage nao —
// 4 duong cu deu "selector khong ton tai". Duong moi cua ban nay dua tren
// chinh dump do: wallpaperConfigurationManager + SBFWallpaperConfiguration
// (property wallpaperImage) + updateWallpaperForLocations:withCompletion:,
// va duong mau native wallpaperServer:setWallpaperColor:... cho che do mau.

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface DWPEngine : NSObject
// Dump TOAN BO method/property/ivar cua cac class wallpaper (khong loc,
// khong cat) de cac ban sau co du bang chung.
+ (void)dumpDiagnostics;
// Thu ap anh lam hinh nen. target: 0=Khoa, 1=Chinh, 2=Both.
// Tra YES neu co it nhat 1 duong he thong nhan lenh (chua chac hien thi —
// phai doi chieu bang mat tren may).
+ (BOOL)applyImage:(UIImage *)image target:(NSInteger)target;
// Thu ap mau nen bang duong native cua he thong (chi che do mau tron).
+ (BOOL)applyColorNative:(UIColor *)color target:(NSInteger)target;
@end

NS_ASSUME_NONNULL_END

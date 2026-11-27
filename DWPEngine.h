// DWPEngine.h — DailyWallpaperPro 1.0.1
// Engine doi hinh nen tren iOS 16: do API he thong luc chay, thu lan luot
// cac duong da biet, ghi log tung buoc. Chua co bang chung tren may that —
// log DailyWallpaperPro.log la nguon de chot duong dung o ban sau.

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface DWPEngine : NSObject
// Dump danh sach class/method lien quan wallpaper ma may that co.
+ (void)dumpDiagnostics;
// Thu ap anh lam hinh nen. target: 0=Khoa, 1=Chinh, 2=Both.
// Tra YES neu co it nhat 1 duong he thong nhan lenh (chua chac hien thi —
// phai doi chieu bang mat tren may).
+ (BOOL)applyImage:(UIImage *)image target:(NSInteger)target;
@end

NS_ASSUME_NONNULL_END

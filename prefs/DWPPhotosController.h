// DWPPhotosController.h — DailyWallpaperPro 1.0.8
// Trang quan ly danh sach anh: luoi o theo ngay, chon nhieu anh cung luc,
// doi tung anh, hoan doi vi tri giua 2 o, xoa tung o.

#import <UIKit/UIKit.h>
#import <Preferences/PSSpecifier.h>

@interface DWPPhotosController : UIViewController
@property (nonatomic, retain) PSSpecifier *specifier;
@end

// DWPShared.h — DailyWallpaperPro 1.0.5
// Hang so + ham dung chung giua tweak (SpringBoard) va trang Cai dat.

#import <Foundation/Foundation.h>
#import <CoreFoundation/CoreFoundation.h>
#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

#define DWP_VERSION @"1.0.5"
#define DWP_BUNDLE_ID @"com.anhdang.dailywallpaperpro"
#define DWP_LOG_PATH @"/var/mobile/Documents/DailyWallpaperPro.log"
#define DWP_SETTINGS_PATH @"/var/mobile/Documents/DailyWallpaperPro-Settings.plist"
#define DWP_PHOTOS_DIR @"/var/mobile/Library/DailyWallpaperPro"

// Ten thong bao Darwin — dung CFSTR truc tiep (khong __bridge tu chuoi C).
#define DWP_NOTIFY_PREFS CFSTR("com.anhdang.dailywallpaperpro/prefsChanged")
#define DWP_NOTIFY_APPLY CFSTR("com.anhdang.dailywallpaperpro/applyNow")
#define DWP_NOTIFY_TEST CFSTR("com.anhdang.dailywallpaperpro/testEngine")
#define DWP_NOTIFY_TESTCOLOR CFSTR("com.anhdang.dailywallpaperpro/testColor")

// Khoa cai dat nguoi dung (17 khoa — xuat/nhap file cai dat chi gom cac khoa nay)
extern NSString * const DWPKeyEnabled;        // BOOL, mac dinh YES
extern NSString * const DWPKeyTarget;         // 0=Khoa, 1=Chinh, 2=Both
extern NSString * const DWPKeyRotationMode;   // 0=Lich thang, 1=Khoang thoi gian, 2=Tat
extern NSString * const DWPKeyOrderMode;      // 0=Lan luot, 1=Ngau nhien
extern NSString * const DWPKeyIntervalValue;  // so (vd 24)
extern NSString * const DWPKeyIntervalUnit;   // 0=Phut, 1=Gio, 2=Ngay, 3=Thang
extern NSString * const DWPKeyScheduleHour;   // 0-23, gio bat dau ngay (che do lich)
extern NSString * const DWPKeyScheduleMinute; // 0/5/10/15/20/30/40/45/50/55
extern NSString * const DWPKeyLanguage;       // 0=Tieng Viet (mac dinh), 1=English
extern NSString * const DWPKeySourceMode;     // 0=Anh, 1=Mau tron, 2=Mau chuyen (gradient)
extern NSString * const DWPKeyColorIndex;     // mau trong bang mau san (0-11)
extern NSString * const DWPKeyColorHex;       // mau tu nhap dang #RRGGBB, rong = dung bang mau
extern NSString * const DWPKeyColorRotate;    // BOOL: tu doi mau theo lich/khoang nhu doi anh
extern NSString * const DWPKeyGradientIndex;  // bo mau chuyen san (0-4)
extern NSString * const DWPKeyDarkenPercent;  // 0/10/20/30/40 — phu toi len anh cho de doc chu/icon
extern NSString * const DWPKeyBlurLevel;      // 0-3 — lam mo anh
extern NSString * const DWPKeyLowBatteryGuard;// BOOL: pin <20% va khong sac thi tam khong doi
// Khoa trang thai noi bo (khong xuat/nhap)
extern NSString * const DWPKeyLastChange;     // double: thoi diem doi gan nhat
extern NSString * const DWPKeyLastDay;        // chuoi yyyy-MM-dd da ap gan nhat (lich)
extern NSString * const DWPKeyCurrentSlot;    // o anh dang hien (1-31)
extern NSString * const DWPKeyCurrentColor;   // vi tri mau/gradient dang hien khi xoay mau

void DWPLog(NSString *format, ...) NS_FORMAT_FUNCTION(1, 2);

id _Nullable DWPPrefObject(NSString *key);
BOOL DWPPrefBool(NSString *key, BOOL fallback);
NSInteger DWPPrefInt(NSString *key, NSInteger fallback);
double DWPPrefDouble(NSString *key, double fallback);
NSString *DWPPrefString(NSString *key, NSString *fallback);
void DWPSetPref(NSString *key, id value);
void DWPRemovePref(NSString *key);
void DWPPostDarwin(CFStringRef name);

// Ngon ngu giao dien: 0 = Tieng Viet, 1 = English
NSInteger DWPLanguage(void);
NSString *DWPT(NSString *vi, NSString *en);

NSString *DWPSlotPath(NSInteger slot);
NSArray<NSNumber *> *DWPFilledSlots(void);
NSInteger DWPDaysInMonthForDate(NSDate *date);
NSInteger DWPDaysInCurrentMonth(void);
NSDate *DWPNextIntervalDate(NSDate *from, NSInteger value, NSInteger unit);

// Anh: thu ve kich thuoc nen + luu vao o. replaceSlot > 0 = chi thay 1 o do;
// replaceSlot == 0 = thay ca bo tu o 1 va xoa cac o thua. Tra so anh da luu.
UIImage * _Nullable DWPWallpaperSizedImage(UIImage *src);
NSInteger DWPSaveWallpaperImages(NSArray<UIImage *> *images, NSInteger replaceSlot);

// Mau nen
NSArray<NSString *> *DWPPaletteHexes(void);
NSArray<NSString *> *DWPGradientHexPairs(void); // moi phan tu dang "#RRGGBB/#RRGGBB"
UIColor * _Nullable DWPColorFromHex(NSString *hex); // tra nil neu hex khong hop le
UIColor *DWPCurrentSolidColor(void);           // mau tron dang chon (hex tu nhap thang bang mau)
UIImage *DWPSolidColorImage(UIColor *color);
UIImage *DWPGradientImage(NSInteger gradientIndex);

// Xuat / nhap file cai dat
NSArray<NSString *> *DWPUserSettingKeys(void);
NSDictionary *DWPExportSettings(void);
NSInteger DWPImportSettings(NSDictionary *dict); // tra so khoa da ap

NS_ASSUME_NONNULL_END

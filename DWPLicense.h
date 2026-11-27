// DWPLicense.h — DailyWallpaperPro 1.0.5
// He ban quyen theo dung mau Fake5G/ZUS da chay that tren may anh:
//  - Dung thu 3 ngay tu dong tu lan chay dau; moc ghi 3 noi (prefs +
//    Keychain + file trong Documents), lay moc som nhat, chong van
//    nguoc dong ho bang maxSeen. Go/cai lai tweak KHONG reset duoc.
//  - Key ECDSA P-256 ky so, dinh dang DWP1-<base32(payload||chu ky DER)>.
//    kind 1 = key chinh, vinh vien, khong buoc may.
//    kind 3 = key phu, 3 ngay tu luc kich hoat, BUOC MA MAY: payload chua
//    dau van ma may cua dung 1 may — may khac dan vao bi tu choi. Moc
//    kich hoat gan voi dau van cua key (SHA-256) va ghi 3 noi: xoa key
//    roi nhap lai cung key thi han van tinh tu lan kich hoat dau tien.
//  - Chu ky luu dang DER (dung hop dong cua SecKeyVerifySignature X962).
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, DWPLicState) {
    DWPLicStateTrial = 0,
    DWPLicStateTrialExpired,
    DWPLicStatePermanent,
    DWPLicStateTimed,
    DWPLicStateTimedExpired
};

// Ma may cua may nay (16 ky tu hex, dang XXXX-XXXX-XXXX-XXXX) — khach doc
// o muc Ban quyen trong Cai dat va gui de duoc cap key phu rieng.
NSString *DWPLicenseMachineCode(void);
// Trang thai hien tai; daysLeft = ngay con lai (lam tron len), -1 = vinh vien.
DWPLicState DWPLicenseCurrentState(NSInteger * _Nullable daysLeftOut,
                                   NSString * _Nullable * _Nullable nameOut);
// YES khi tweak duoc chay tinh nang (con dung thu hoac key con han)
BOOL DWPLicenseActive(void);
// YES chi khi co KEY con han — trang Cai dat mo khoa bang ham nay (dung
// thu chay nen bang cau hinh san co nhung khong vao duoc phan dieu chinh)
BOOL DWPLicenseHasActiveKey(void);
NSString *DWPLicenseStatusText(void);
// Kiem tra + luu key. Thanh cong tra YES va ten chu key qua nameOut.
BOOL DWPLicenseTryActivateKey(NSString *key,
                              NSString * _Nullable * _Nullable nameOut,
                              NSString * _Nullable * _Nullable errorOut);

NS_ASSUME_NONNULL_END

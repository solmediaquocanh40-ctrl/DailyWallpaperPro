// DWPRootListController.m — DailyWallpaperPro 1.0.2
// Trang Cai dat chinh: specifiers dung bang CODE de doi ngon ngu duoc
// (Tieng Viet co dau mac dinh / English). Neu dung code loi thi tu lui ve
// Root.plist (Tieng Viet) — trang khong bao gio trang trang.

#import "DWPRootListController.h"
#import "../DWPShared.h"
#import "DWPPhotosController.h"
#import "DWPLogViewController.h"
#import "DWPPickerHelper.h"
#import <Preferences/PSSpecifier.h>
#import <PhotosUI/PhotosUI.h>
#import <UniformTypeIdentifiers/UniformTypeIdentifiers.h>
#import <objc/message.h>

@interface DWPRootListController () <PHPickerViewControllerDelegate, UIDocumentPickerDelegate>
- (NSMutableArray *)buildSpecifiers;
- (void)showAlertTitle:(NSString *)title message:(NSString *)message;
- (void)importSettingsFromURL:(NSURL *)url;
@end

// ---- Nha may specifier ----
static PSSpecifier *DWPSpecGroup(id target, NSString *name, NSString *footer) {
    PSSpecifier *spec = [PSSpecifier groupSpecifierWithName:name];
    if (footer) [spec setProperty:footer forKey:@"footerText"];
    return spec;
}

static void DWPSetKeyProps(PSSpecifier *spec, NSString *key, id def) {
    [spec setProperty:key forKey:@"key"];
    [spec setProperty:DWP_BUNDLE_ID forKey:@"defaults"];
    if (def) [spec setProperty:def forKey:@"default"];
    [spec setProperty:key forKey:@"id"];
}

static PSSpecifier *DWPSpecSwitch(id target, NSString *name, NSString *key, BOOL def) {
    PSSpecifier *spec = [PSSpecifier preferenceSpecifierNamed:name target:target set:@selector(setPreferenceValue:specifier:) get:@selector(readPreferenceValue:) detail:nil cell:PSSwitchCell edit:nil];
    DWPSetKeyProps(spec, key, @(def));
    return spec;
}

static PSSpecifier *DWPSpecLinkList(id target, NSString *name, NSString *key, id def, NSArray *values, NSArray *titles) {
    PSSpecifier *spec = [PSSpecifier preferenceSpecifierNamed:name target:target set:@selector(setPreferenceValue:specifier:) get:@selector(readPreferenceValue:) detail:[PSListItemsController class] cell:PSLinkListCell edit:nil];
    DWPSetKeyProps(spec, key, def);
    [spec setProperty:values forKey:@"validValues"];
    [spec setProperty:titles forKey:@"validTitles"];
    return spec;
}

static PSSpecifier *DWPSpecLink(id target, NSString *name, Class detailClass, NSString *sid) {
    PSSpecifier *spec = [PSSpecifier preferenceSpecifierNamed:name target:target set:nil get:nil detail:detailClass cell:PSLinkCell edit:nil];
    [spec setProperty:@YES forKey:@"isController"];
    [spec setProperty:sid forKey:@"id"];
    return spec;
}

static PSSpecifier *DWPSpecButton(id target, NSString *name, SEL action, NSString *sid) {
    PSSpecifier *spec = [PSSpecifier preferenceSpecifierNamed:name target:target set:nil get:nil detail:nil cell:PSButtonCell edit:nil];
    [spec setProperty:sid forKey:@"id"];
    if ([spec respondsToSelector:@selector(setButtonAction:)]) {
        ((void (*)(id, SEL, SEL))objc_msgSend)(spec, @selector(setButtonAction:), action);
    } else {
        [spec setProperty:NSStringFromSelector(action) forKey:@"action"];
    }
    return spec;
}

static PSSpecifier *DWPSpecValue(id target, NSString *name, NSString *key) {
    PSSpecifier *spec = [PSSpecifier preferenceSpecifierNamed:name target:target set:nil get:@selector(readPreferenceValue:) detail:nil cell:PSTitleValueCell edit:nil];
    [spec setProperty:key forKey:@"key"];
    [spec setProperty:key forKey:@"id"];
    return spec;
}

static PSSpecifier *DWPSpecEditText(id target, NSString *name, NSString *key, NSString *def) {
    PSSpecifier *spec = [PSSpecifier preferenceSpecifierNamed:name target:target set:@selector(setPreferenceValue:specifier:) get:@selector(readPreferenceValue:) detail:nil cell:PSEditTextCell edit:nil];
    DWPSetKeyProps(spec, key, def);
    return spec;
}

@implementation DWPRootListController

- (NSArray *)specifiers {
    if (!_specifiers) {
        NSMutableArray *built = nil;
        @try { built = [self buildSpecifiers]; } @catch (NSException *e) {
            DWPLog(@"prefs: dung specifiers bang code THAT BAI (%@: %@) — lui ve Root.plist", e.name, e.reason);
            built = nil;
        }
        if (built.count > 0) _specifiers = built;
        else _specifiers = [self loadSpecifiersFromPlistName:@"Root" target:self];
    }
    return _specifiers;
}

- (NSMutableArray *)buildSpecifiers {
    NSMutableArray *items = [NSMutableArray array];
    BOOL en = (DWPLanguage() == 1);

    [items addObject:DWPSpecGroup(self, @"DailyWallpaper Pro",
        DWPT(@"Tự đổi hình nền theo lịch tháng hoặc theo khoảng thời gian anh tự đặt. Quản lý danh sách ảnh ngay trong trang này.",
             @"Auto-change wallpaper by calendar month or by a custom interval. Manage the photo list right here."))];
    [items addObject:DWPSpecSwitch(self, DWPT(@"Bật DailyWallpaper Pro", @"Enable DailyWallpaper Pro"), DWPKeyEnabled, YES)];
    [items addObject:DWPSpecLinkList(self, DWPT(@"Ngôn ngữ", @"Language"), DWPKeyLanguage, @0, @[@0, @1], @[@"Tiếng Việt", @"English"])];

    [items addObject:DWPSpecGroup(self, DWPT(@"Nguồn nền", @"Wallpaper source"),
        DWPT(@"Ảnh: dùng bộ ảnh đã chọn. Màu trơn / Màu chuyển: không cần ảnh, hợp khi anh không muốn để hình nữa.",
             @"Photos: use the picked set. Solid / Gradient: no photos needed."))];
    [items addObject:DWPSpecLinkList(self, DWPT(@"Nguồn nền", @"Source"), DWPKeySourceMode, @0, @[@0, @1, @2],
        en ? @[@"Photos", @"Solid color", @"Gradient"] : @[@"Ảnh đã chọn", @"Màu trơn", @"Màu chuyển (gradient)"])];
    [items addObject:DWPSpecLink(self, DWPT(@"Quản lý danh sách ảnh", @"Manage photo list"), [DWPPhotosController class], @"photos")];
    [items addObject:DWPSpecButton(self, DWPT(@"Chọn bộ ảnh ngay tại đây (đường dự phòng)", @"Pick photo set right here (fallback)"), @selector(pickPhotosFallback:), @"pickFallback")];

    [items addObject:DWPSpecGroup(self, DWPT(@"Nơi đổi hình nền", @"Where to change"),
        DWPT(@"Both nghĩa là đổi cả màn hình khoá và màn hình chính cùng một nền.", @"Both changes lock screen and home screen together."))];
    [items addObject:DWPSpecLinkList(self, DWPT(@"Đổi ở đâu", @"Change on"), DWPKeyTarget, @2, @[@0, @1, @2],
        en ? @[@"Lock screen only", @"Home screen only", @"Both"] : @[@"Chỉ màn hình khoá", @"Chỉ màn hình chính", @"Cả hai (Both)"])];

    [items addObject:DWPSpecGroup(self, DWPT(@"Kiểu tự đổi", @"Auto-change style"),
        DWPT(@"Theo lịch tháng: ngày mấy hiện ảnh ô ấy, tháng có bao nhiêu ngày thì chọn bấy nhiêu ảnh. Theo khoảng thời gian: hết khoảng là đổi tiếp. Tắt: chỉ dùng 1 nền cố định.",
             @"Calendar: day N shows slot N. Interval: advance when the interval elapses. Off: one fixed wallpaper."))];
    [items addObject:DWPSpecLinkList(self, DWPT(@"Kiểu tự đổi", @"Style"), DWPKeyRotationMode, @0, @[@0, @1, @2],
        en ? @[@"By calendar month", @"By custom interval", @"Off — single wallpaper"] : @[@"Theo lịch tháng", @"Theo khoảng thời gian tự đặt", @"Tắt — chỉ dùng 1 nền"])];
    [items addObject:DWPSpecLinkList(self, DWPT(@"Thứ tự (chế độ khoảng thời gian)", @"Order (interval mode)"), DWPKeyOrderMode, @0, @[@0, @1],
        en ? @[@"Sequential 1, 2, 3...", @"Random"] : @[@"Lần lượt 1, 2, 3...", @"Ngẫu nhiên"])];

    NSMutableArray *hourTitles = [NSMutableArray array];
    NSMutableArray *hourValues = [NSMutableArray array];
    for (NSInteger h = 0; h < 24; h++) {
        [hourValues addObject:@(h)];
        [hourTitles addObject:en ? [NSString stringWithFormat:@"%ld:00", (long)h] : [NSString stringWithFormat:@"%ld giờ", (long)h]];
    }
    NSArray *minValues = @[@0, @5, @10, @15, @20, @30, @40, @45, @50, @55];
    NSMutableArray *minTitles = [NSMutableArray array];
    for (NSNumber *m in minValues) [minTitles addObject:[NSString stringWithFormat:@"%02ld %@", (long)[m integerValue], en ? @"min" : @"phút"]];
    [items addObject:DWPSpecGroup(self, DWPT(@"Giờ bắt đầu ngày (chế độ lịch tháng)", @"Day start time (calendar mode)"),
        DWPT(@"Qua giờ này mỗi ngày, nền của ngày hôm đó mới được áp.", @"The day's wallpaper applies after this time."))];
    [items addObject:DWPSpecLinkList(self, DWPT(@"Giờ bắt đầu", @"Start hour"), DWPKeyScheduleHour, @0, hourValues, hourTitles)];
    [items addObject:DWPSpecLinkList(self, DWPT(@"Phút bắt đầu", @"Start minute"), DWPKeyScheduleMinute, @0, minValues, minTitles)];

    [items addObject:DWPSpecGroup(self, DWPT(@"Khoảng thời gian (chế độ khoảng thời gian)", @"Interval (interval mode)"),
        DWPT(@"Ví dụ: 30 Phút, 24 Giờ, 48 Giờ, 2 Ngày, 1 Tháng.", @"Examples: 30 Minutes, 24 Hours, 48 Hours, 2 Days, 1 Month."))];
    [items addObject:DWPSpecLinkList(self, DWPT(@"Mỗi (số)", @"Every (amount)"), DWPKeyIntervalValue, @1, @[@1, @2, @3, @5, @10, @15, @30, @45, @48, @60],
        @[@"1", @"2", @"3", @"5", @"10", @"15", @"30", @"45", @"48", @"60"])];
    [items addObject:DWPSpecLinkList(self, DWPT(@"Đơn vị", @"Unit"), DWPKeyIntervalUnit, @2, @[@0, @1, @2, @3],
        en ? @[@"Minutes", @"Hours", @"Days", @"Months"] : @[@"Phút", @"Giờ", @"Ngày", @"Tháng"])];

    NSArray *colorNamesVI = @[@"Đen", @"Trắng", @"Xám", @"Đỏ", @"Cam", @"Vàng", @"Xanh lá", @"Xanh biển", @"Xanh navy", @"Tím", @"Hồng", @"Nâu"];
    NSArray *colorNamesEN = @[@"Black", @"White", @"Gray", @"Red", @"Orange", @"Yellow", @"Green", @"Blue", @"Navy", @"Purple", @"Pink", @"Brown"];
    NSMutableArray *colorValues = [NSMutableArray array];
    for (NSInteger i = 0; i < 12; i++) [colorValues addObject:@(i)];
    NSArray *gradNamesVI = @[@"Hoàng hôn", @"Biển", @"Rừng", @"Tím mộng", @"Đêm"];
    NSArray *gradNamesEN = @[@"Sunset", @"Ocean", @"Forest", @"Purple dream", @"Night"];
    [items addObject:DWPSpecGroup(self, DWPT(@"Màu nền (nguồn Màu trơn / Màu chuyển)", @"Colors (Solid / Gradient source)"), nil)];
    [items addObject:DWPSpecLinkList(self, DWPT(@"Màu trơn trong bảng màu", @"Solid color (palette)"), DWPKeyColorIndex, @8, colorValues, en ? colorNamesEN : colorNamesVI)];
    [items addObject:DWPSpecEditText(self, DWPT(@"Màu tự nhập (#RRGGBB, trống = bảng màu)", @"Custom color (#RRGGBB, empty = palette)"), DWPKeyColorHex, @"")];
    [items addObject:DWPSpecLinkList(self, DWPT(@"Bộ màu chuyển", @"Gradient set"), DWPKeyGradientIndex, @0, @[@0, @1, @2, @3, @4], en ? gradNamesEN : gradNamesVI)];
    [items addObject:DWPSpecSwitch(self, DWPT(@"Tự đổi màu theo lịch/khoảng như đổi ảnh", @"Rotate colors on schedule like photos"), DWPKeyColorRotate, NO)];
    [items addObject:DWPSpecButton(self, DWPT(@"Áp màu / gradient ngay để thử", @"Apply color / gradient now (test)"), @selector(testColor:), @"testColor")];

    [items addObject:DWPSpecGroup(self, DWPT(@"Hiệu ứng ảnh (chế độ ảnh)", @"Photo effects (photo source)"), nil)];
    [items addObject:DWPSpecLinkList(self, DWPT(@"Phủ tối (dễ đọc chữ/icon)", @"Dark overlay (readability)"), DWPKeyDarkenPercent, @0, @[@0, @10, @20, @30, @40],
        @[@"0%", @"10%", @"20%", @"30%", @"40%"])];
    [items addObject:DWPSpecLinkList(self, DWPT(@"Làm mờ ảnh", @"Blur photo"), DWPKeyBlurLevel, @0, @[@0, @1, @2, @3],
        en ? @[@"None", @"Light", @"Medium", @"Strong"] : @[@"Không", @"Nhẹ", @"Vừa", @"Mạnh"])];
    [items addObject:DWPSpecSwitch(self, DWPT(@"Pin yếu thì tạm không đổi (dưới 20%, không sạc)", @"Skip change on low battery (under 20%, not charging)"), DWPKeyLowBatteryGuard, NO)];

    [items addObject:DWPSpecGroup(self, DWPT(@"Trạng thái", @"Status"), nil)];
    [items addObject:DWPSpecValue(self, DWPT(@"Nguồn + nơi đổi", @"Source + target"), @"infoSource")];
    [items addObject:DWPSpecValue(self, DWPT(@"Ảnh đã lưu", @"Saved photos"), @"infoPhotos")];
    [items addObject:DWPSpecValue(self, DWPT(@"Lần đổi gần nhất", @"Last change"), @"infoLast")];

    [items addObject:DWPSpecGroup(self, DWPT(@"Thao tác", @"Actions"), nil)];
    [items addObject:DWPSpecButton(self, DWPT(@"Đổi nền ngay bây giờ", @"Change wallpaper now"), @selector(applyNow:), @"applyNow")];
    [items addObject:DWPSpecButton(self, DWPT(@"Test engine đổi nền (ảnh đỏ DWP TEST)", @"Test wallpaper engine (red DWP TEST image)"), @selector(testEngine:), @"testEngine")];
    [items addObject:DWPSpecButton(self, DWPT(@"Đặt lại mốc đổi", @"Reset change timer"), @selector(resetState:), @"resetState")];

    [items addObject:DWPSpecGroup(self, DWPT(@"Cài đặt & nhật ký", @"Settings & log"),
        [NSString stringWithFormat:@"DailyWallpaper Pro %@ — com.anhdang.dailywallpaperpro — Log: /var/mobile/Documents/DailyWallpaperPro.log", DWP_VERSION])];
    [items addObject:DWPSpecButton(self, DWPT(@"Xuất file cài đặt", @"Export settings file"), @selector(exportSettings:), @"exportSettings")];
    [items addObject:DWPSpecButton(self, DWPT(@"Nhập file cài đặt", @"Import settings file"), @selector(importSettings:), @"importSettings")];
    [items addObject:DWPSpecLink(self, DWPT(@"Xem nhật ký (log)", @"View log"), [DWPLogViewController class], @"logView")];
    [items addObject:DWPSpecButton(self, DWPT(@"Đặt lại toàn bộ cài đặt", @"Reset all settings"), @selector(resetAll:), @"resetAll")];

    DWPLog(@"prefs: da dung %lu specifiers bang code (ngon ngu %ld)", (unsigned long)items.count, (long)DWPLanguage());
    return items;
}

- (id)readPreferenceValue:(PSSpecifier *)specifier {
    NSString *key = [specifier propertyForKey:@"key"];
    if ([key isEqualToString:@"infoSource"]) {
        NSInteger source = DWPPrefInt(DWPKeySourceMode, 0);
        NSInteger target = DWPPrefInt(DWPKeyTarget, 2);
        NSString *src = source == 0 ? DWPT(@"Ảnh", @"Photos") : (source == 1 ? DWPT(@"Màu trơn", @"Solid") : DWPT(@"Màu chuyển", @"Gradient"));
        NSString *tgt = target == 0 ? DWPT(@"Khoá", @"Lock") : (target == 1 ? DWPT(@"Chính", @"Home") : @"Both");
        return [NSString stringWithFormat:@"%@ → %@", src, tgt];
    }
    if ([key isEqualToString:@"infoPhotos"]) {
        return [NSString stringWithFormat:DWPT(@"%ld ảnh, đang hiện ô %ld", @"%ld photos, current slot %ld"),
                (long)DWPFilledSlots().count, (long)DWPPrefInt(DWPKeyCurrentSlot, 0)];
    }
    if ([key isEqualToString:@"infoLast"]) {
        double last = DWPPrefDouble(DWPKeyLastChange, 0);
        if (last <= 0) return DWPT(@"Chưa đổi lần nào", @"Never changed yet");
        NSDateFormatter *fmt = [[NSDateFormatter alloc] init];
        fmt.dateFormat = @"dd/MM HH:mm";
        return [fmt stringFromDate:[NSDate dateWithTimeIntervalSince1970:last]];
    }
    id value = key ? DWPPrefObject(key) : nil;
    if (!value) value = [specifier propertyForKey:@"default"];
    return value;
}

- (void)setPreferenceValue:(id)value specifier:(PSSpecifier *)specifier {
    NSString *key = [specifier propertyForKey:@"key"];
    if (key && value) {
        DWPSetPref(key, value);
        DWPPostDarwin(DWP_NOTIFY_PREFS);
        DWPLog(@"prefs: dat %@ = %@", key, value);
        if ([key isEqualToString:DWPKeyLanguage]) {
            dispatch_async(dispatch_get_main_queue(), ^{
                _specifiers = nil;
                [self reloadSpecifiers];
            });
        }
    }
}

- (void)showAlertTitle:(NSString *)title message:(NSString *)message {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:title message:message preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)applyNow:(id)sender {
    DWPPostDarwin(DWP_NOTIFY_APPLY);
    [self showAlertTitle:DWPT(@"Đã gửi lệnh đổi ngay", @"Change command sent")
                 message:DWPT(@"Anh thoát ra màn hình khoá / màn hình chính để coi nền đã đổi chưa. Chưa đổi thì gửi em log.", @"Check the lock / home screen. If unchanged, send me the log.")];
}

- (void)testEngine:(id)sender {
    DWPPostDarwin(DWP_NOTIFY_TEST);
    [self showAlertTitle:DWPT(@"Đã gửi lệnh test engine", @"Engine test sent")
                 message:DWPT(@"Tweak sẽ thử đổi nền bằng ảnh đỏ DWP TEST. Anh coi màn hình có đổi không rồi gửi em log.", @"A red DWP TEST image will be applied if a route works. Check the screen and send me the log.")];
}

- (void)testColor:(id)sender {
    DWPPostDarwin(DWP_NOTIFY_TESTCOLOR);
    [self showAlertTitle:DWPT(@"Đã gửi lệnh áp màu", @"Color apply sent")
                 message:DWPT(@"Anh coi nền có đổi sang màu/gradient đang chọn không rồi gửi em log.", @"Check whether the wallpaper turned to the chosen color/gradient, then send me the log.")];
}

- (void)resetState:(id)sender {
    DWPSetPref(DWPKeyLastChange, @(0));
    DWPSetPref(DWPKeyLastDay, @"");
    DWPSetPref(DWPKeyCurrentSlot, @(0));
    DWPSetPref(DWPKeyCurrentColor, @(0));
    DWPPostDarwin(DWP_NOTIFY_PREFS);
    [self showAlertTitle:DWPT(@"Đã đặt lại mốc đổi", @"Timer reset")
                 message:DWPT(@"Lần kiểm tra tiếp theo (tối đa 60 giây) tweak sẽ đổi nền lại từ đầu.", @"Within 60 seconds the tweak will apply again from the start.")];
}

#pragma mark - Chon anh du phong ngay o trang chinh

- (void)pickPhotosFallback:(id)sender {
    DWPLog(@"prefs: anh bam CHON ANH DU PHONG o trang chinh");
    NSInteger limit = (DWPPrefInt(DWPKeyRotationMode, 0) == 0) ? DWPDaysInCurrentMonth() : 31;
    PHPickerConfiguration *config = [[PHPickerConfiguration alloc] init];
    config.selectionLimit = limit;
    config.filter = [PHPickerFilter imagesFilter];
    PHPickerViewController *picker = [[PHPickerViewController alloc] initWithConfiguration:config];
    picker.delegate = self;
    [self presentViewController:picker animated:YES completion:^{
        DWPLog(@"picker: da trinh bo chon anh (du phong, gioi han %ld)", (long)limit);
    }];
}

- (void)picker:(PHPickerViewController *)picker didFinishPicking:(NSArray<PHPickerResult *> *)results {
    [picker dismissViewControllerAnimated:YES completion:nil];
    if (results.count == 0) {
        DWPLog(@"picker: anh huy chon (0 ket qua)");
        return;
    }
    DWPLoadPickerImages(results, ^(NSArray<UIImage *> *images) {
        if (images.count == 0) {
            [self showAlertTitle:DWPT(@"Không tải được ảnh nào", @"No photo could be loaded")
                         message:DWPT(@"Anh thử lại, hoặc gửi em log để em coi dòng picker.", @"Try again, or send me the log so I can read the picker lines.")];
            return;
        }
        NSInteger saved = DWPSaveWallpaperImages(images, 0);
        DWPPostDarwin(DWP_NOTIFY_PREFS);
        [self showAlertTitle:DWPT(@"Đã lưu bộ ảnh", @"Photo set saved")
                     message:[NSString stringWithFormat:DWPT(@"Đã lưu %ld ảnh vào các ô.", @"Saved %ld photos into slots."), (long)saved]];
    });
}

#pragma mark - Xuat / nhap cai dat

- (void)exportSettings:(id)sender {
    NSDictionary *dict = DWPExportSettings();
    BOOL ok = [dict writeToFile:DWP_SETTINGS_PATH atomically:YES];
    DWPLog(@"prefs: xuat cai dat -> %@ (%@)", DWP_SETTINGS_PATH, ok ? @"OK" : @"THAT BAI");
    if (!ok) {
        [self showAlertTitle:DWPT(@"Xuất thất bại", @"Export failed") message:DWP_SETTINGS_PATH];
        return;
    }
    NSURL *url = [NSURL fileURLWithPath:DWP_SETTINGS_PATH];
    UIActivityViewController *avc = [[UIActivityViewController alloc] initWithActivityItems:@[url] applicationActivities:nil];
    [self presentViewController:avc animated:YES completion:nil];
}

- (void)importSettings:(id)sender {
    if ([[NSFileManager defaultManager] fileExistsAtPath:DWP_SETTINGS_PATH]) {
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:DWPT(@"Nhập file cài đặt?", @"Import settings file?")
            message:[NSString stringWithFormat:DWPT(@"Đã thấy file ở %@. Nhập sẽ ghi đè cài đặt hiện tại.", @"Found the file at %@. Importing overwrites current settings."), DWP_SETTINGS_PATH]
            preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:DWPT(@"Huỷ", @"Cancel") style:UIAlertActionStyleCancel handler:nil]];
        [alert addAction:[UIAlertAction actionWithTitle:DWPT(@"Nhập", @"Import") style:UIAlertActionStyleDefault handler:^(UIAlertAction *a) {
            [self importSettingsFromURL:[NSURL fileURLWithPath:DWP_SETTINGS_PATH]];
        }]];
        [self presentViewController:alert animated:YES completion:nil];
        return;
    }
    UTType *plistType = [UTType typeWithIdentifier:@"com.apple.property-list"];
    UIDocumentPickerViewController *doc = [[UIDocumentPickerViewController alloc] initForOpeningContentTypes:@[plistType] asCopy:YES];
    doc.delegate = self;
    [self presentViewController:doc animated:YES completion:nil];
}

- (void)documentPicker:(UIDocumentPickerViewController *)controller didPickDocumentsAtURLs:(NSArray<NSURL *> *)urls {
    NSURL *url = urls.firstObject;
    if (url) [self importSettingsFromURL:url];
}

- (void)importSettingsFromURL:(NSURL *)url {
    BOOL scoped = [url startAccessingSecurityScopedResource];
    NSDictionary *dict = [NSDictionary dictionaryWithContentsOfURL:url];
    if (scoped) [url stopAccessingSecurityScopedResource];
    if (!dict) {
        DWPLog(@"prefs: nhap cai dat THAT BAI, khong doc duoc file %@", url);
        [self showAlertTitle:DWPT(@"Nhập thất bại", @"Import failed")
                     message:DWPT(@"File không đọc được hoặc không đúng định dạng plist.", @"The file is unreadable or not a plist.")];
        return;
    }
    NSInteger applied = DWPImportSettings(dict);
    DWPPostDarwin(DWP_NOTIFY_PREFS);
    _specifiers = nil;
    [self reloadSpecifiers];
    [self showAlertTitle:DWPT(@"Đã nhập cài đặt", @"Settings imported")
                 message:[NSString stringWithFormat:DWPT(@"Đã áp %ld mục cài đặt từ file.", @"Applied %ld settings from the file."), (long)applied]];
}

- (void)resetAll:(id)sender {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:DWPT(@"Đặt lại toàn bộ cài đặt?", @"Reset all settings?")
        message:DWPT(@"Mọi lựa chọn sẽ về mặc định. Ảnh đã lưu KHÔNG bị xoá.", @"All options return to defaults. Saved photos are NOT deleted.")
        preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:DWPT(@"Huỷ", @"Cancel") style:UIAlertActionStyleCancel handler:nil]];
    [alert addAction:[UIAlertAction actionWithTitle:DWPT(@"Đặt lại", @"Reset") style:UIAlertActionStyleDestructive handler:^(UIAlertAction *a) {
        for (NSString *key in DWPUserSettingKeys()) DWPRemovePref(key);
        DWPRemovePref(DWPKeyLastChange);
        DWPRemovePref(DWPKeyLastDay);
        DWPRemovePref(DWPKeyCurrentSlot);
        DWPRemovePref(DWPKeyCurrentColor);
        DWPPostDarwin(DWP_NOTIFY_PREFS);
        DWPLog(@"prefs: anh vua DAT LAI TOAN BO cai dat");
        _specifiers = nil;
        [self reloadSpecifiers];
    }]];
    [self presentViewController:alert animated:YES completion:nil];
}

@end

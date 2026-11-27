// DWPRootListController.m — DailyWallpaperPro 1.0.8
// Ban nay QUAY VE specifiers bang PLIST (duong da chung minh chay tot o
// 1.0.1: doi gia tri, bam nut deu ngon). Ban 1.0.2/1.0.3 dung specifiers
// bang code — log 1.0.3 cho thay trang dung duoc nhung khong co bat ky
// dong "prefs: dat" nao (doi gia tri khong bao gio xong, khop loi anh bao
// "an vo dau cung vang"). Song ngu bang 2 file plist: Root.plist (Tieng
// Viet co dau) va RootEN.plist (English), chon theo khoa language.

#import "DWPRootListController.h"
#import "../DWPShared.h"
#import "../DWPLicense.h"
#import "DWPPhotosController.h"
#import "DWPLogViewController.h"
#import "DWPPickerHelper.h"
#import <Preferences/PSSpecifier.h>
#import <PhotosUI/PhotosUI.h>
#import <Photos/Photos.h>
#import <UniformTypeIdentifiers/UniformTypeIdentifiers.h>

@interface DWPRootListController () <PHPickerViewControllerDelegate, UIDocumentPickerDelegate>
- (void)showAlertTitle:(NSString *)title message:(NSString *)message;
- (void)importSettingsFromURL:(NSURL *)url;
@end

@implementation DWPRootListController

- (NSArray *)specifiers {
    if (!_specifiers) {
        NSString *plistName = (DWPLanguage() == 1) ? @"RootEN" : @"Root";
        _specifiers = [self loadSpecifiersFromPlistName:plistName target:self];
        for (PSSpecifier *spec in _specifiers) {
            if ([[spec propertyForKey:@"id"] isEqualToString:@"licenseGroup"]) {
                [spec setProperty:DWPLicenseStatusText() forKey:@"footerText"];
            }
        }
        DWPLog(@"prefs: da nap specifiers tu %@.plist (%lu muc)", plistName, (unsigned long)_specifiers.count);
    }
    return _specifiers;
}

- (id)readPreferenceValue:(PSSpecifier *)specifier {
    NSString *key = [specifier propertyForKey:@"key"];
    if ([key isEqualToString:@"licStatus"]) return DWPLicenseStatusText();
    if ([key isEqualToString:@"licMachine"]) return DWPLicenseMachineCode();
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

#pragma mark - Ban quyen: phu mo + popup Active (mau Fake5G/ZUS)

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    if (DWPLicenseHasActiveKey()) {
        [self removeExpiredOverlay];
        self.popupShownThisAppear = NO;
    } else {
        [self installExpiredOverlay];
        if (!self.popupShownThisAppear) {
            self.popupShownThisAppear = YES;
            [self showActivatePopup];
        }
    }
}

- (void)installExpiredOverlay {
    if ([self.view viewWithTag:9001]) return;
    UIVisualEffectView *blur = [[UIVisualEffectView alloc]
        initWithEffect:[UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemMaterial]];
    blur.tag = 9001;
    blur.frame = self.view.bounds;
    blur.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    UILabel *label = [[UILabel alloc] initWithFrame:blur.contentView.bounds];
    label.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    label.text = (DWPLicenseCurrentState(NULL, NULL) == DWPLicStateTrial)
        ? DWPT(@"Đang dùng thử — nhập key để mở khoá điều chỉnh\nChạm để nhập key kích hoạt",
               @"Trial running — enter a key to unlock settings\nTap to enter your activation key")
        : DWPT(@"Đã hết hạn dùng thử\nChạm để nhập key kích hoạt",
               @"Trial expired\nTap to enter your activation key");
    label.numberOfLines = 2;
    label.textAlignment = NSTextAlignmentCenter;
    label.font = [UIFont systemFontOfSize:15 weight:UIFontWeightSemibold];
    [blur.contentView addSubview:label];
    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc]
        initWithTarget:self action:@selector(expiredOverlayTapped)];
    [blur addGestureRecognizer:tap];
    [self.view addSubview:blur];
}

- (void)removeExpiredOverlay {
    [[self.view viewWithTag:9001] removeFromSuperview];
}

- (void)expiredOverlayTapped {
    [self showActivatePopup];
}

- (void)activateTapped:(id)sender {
    [self showActivatePopup];
}

- (void)copyMachine:(id)sender {
    [UIPasteboard generalPasteboard].string = DWPLicenseMachineCode();
    DWPLog(@"prefs: anh vua sao chep ma may %@", DWPLicenseMachineCode());
    [self showAlertTitle:DWPT(@"Đã chép mã máy", @"Machine code copied")
                 message:DWPLicenseMachineCode()];
}

- (void)showActivatePopup {
    [self showActivatePopupWithMessage:DWPLicenseStatusText()];
}

- (void)showActivatePopupWithMessage:(NSString *)message {
    if (self.activeAlert) return;
    UIAlertController *alert = [UIAlertController
        alertControllerWithTitle:DWPT(@"Kích hoạt DailyWallpaper Pro", @"Activate DailyWallpaper Pro")
                         message:[message stringByAppendingFormat:@"\n%@",
                                  DWPT(@"Dán key vào ô dưới rồi bấm OK. Popup tự đóng sau 30 giây.",
                                       @"Paste your key below and tap OK. This popup closes itself after 30 seconds.")]
                  preferredStyle:UIAlertControllerStyleAlert];
    [alert addTextFieldWithConfigurationHandler:^(UITextField *textField) {
        textField.placeholder = @"DWP1-....";
        textField.autocapitalizationType = UITextAutocapitalizationTypeAllCharacters;
        textField.autocorrectionType = UITextAutocorrectionTypeNo;
        textField.delegate = self;
    }];
    __weak typeof(self) weakSelf = self;
    [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault
        handler:^(UIAlertAction *action) {
            [weakSelf stopPopupTimer];
            weakSelf.activeAlert = nil;
            NSString *key = alert.textFields.firstObject.text ?: @"";
            NSString *name = nil, *error = nil;
            if (DWPLicenseTryActivateKey(key, &name, &error)) {
                [weakSelf removeExpiredOverlay];
                weakSelf.popupShownThisAppear = NO;
                _specifiers = nil;
                [weakSelf reloadSpecifiers];
                [weakSelf showAlertTitle:DWPT(@"Đã kích hoạt", @"Activated")
                                 message:[NSString stringWithFormat:DWPT(@"Key của %@ đã được chấp nhận.", @"The key for %@ was accepted."), name ?: @""]];
            } else {
                [weakSelf showActivatePopupWithMessage:(error ?: DWPT(@"Key chưa đúng.", @"Invalid key."))];
            }
        }]];
    [alert addAction:[UIAlertAction actionWithTitle:DWPT(@"Huỷ", @"Cancel") style:UIAlertActionStyleCancel
        handler:^(UIAlertAction *action) {
            [weakSelf stopPopupTimer];
            weakSelf.activeAlert = nil;
        }]];
    self.activeAlert = alert;
    self.popupSecondsLeft = 30;
    self.popupEditing = NO;
    [self presentViewController:alert animated:YES completion:nil];
    [self stopPopupTimer];
    self.popupTimer = [NSTimer scheduledTimerWithTimeInterval:1.0
                                                       target:self
                                                     selector:@selector(popupTimerFired)
                                                     userInfo:nil
                                                      repeats:YES];
}

- (void)popupTimerFired {
    if (self.popupEditing) return;
    self.popupSecondsLeft -= 1;
    if (self.popupSecondsLeft <= 0) {
        [self stopPopupTimer];
        [self.activeAlert dismissViewControllerAnimated:YES completion:nil];
        self.activeAlert = nil;
    }
}

- (void)stopPopupTimer {
    [self.popupTimer invalidate];
    self.popupTimer = nil;
}

- (void)textFieldDidBeginEditing:(UITextField *)textField {
    self.popupEditing = YES;
}

- (void)textFieldDidEndEditing:(UITextField *)textField {
    self.popupEditing = NO;
}

#pragma mark - Chon anh du phong ngay o trang chinh

- (void)pickPhotosFallback:(id)sender {
    DWPLog(@"prefs: anh bam CHON ANH DU PHONG o trang chinh");
    NSInteger limit = (DWPPrefInt(DWPKeyRotationMode, 0) == 0) ? DWPDaysInCurrentMonth() : 31;
    PHPickerConfiguration *config = [[PHPickerConfiguration alloc] initWithPhotoLibrary:[PHPhotoLibrary sharedPhotoLibrary]];
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
        message:DWPT(@"Mọi lựa chọn sẽ về mặc định, key đã kích hoạt bị xoá (phải nhập lại; hạn key vẫn tính từ lần kích hoạt đầu tiên, dùng thử không chạy lại). Ảnh đã lưu KHÔNG bị xoá.", @"All options return to defaults and the activated key is removed (re-enter it; its expiry still counts from first activation and the trial does not restart). Saved photos are NOT deleted.")
        preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:DWPT(@"Huỷ", @"Cancel") style:UIAlertActionStyleCancel handler:nil]];
    [alert addAction:[UIAlertAction actionWithTitle:DWPT(@"Đặt lại", @"Reset") style:UIAlertActionStyleDestructive handler:^(UIAlertAction *a) {
        for (NSString *key in DWPUserSettingKeys()) DWPRemovePref(key);
        DWPRemovePref(DWPKeyLastChange);
        DWPRemovePref(DWPKeyLastDay);
        DWPRemovePref(DWPKeyCurrentSlot);
        DWPRemovePref(DWPKeyCurrentColor);
        // Xoa key da kich hoat nhung GIU NGUYEN cac moc thoi gian ban quyen
        // (trialStart/maxSeen/actStart/actKeyHash o 3 noi) — mau Fake5G.
        DWPRemovePref(@"licenseKey");
        DWPPostDarwin(DWP_NOTIFY_PREFS);
        DWPLog(@"prefs: anh vua DAT LAI TOAN BO cai dat (da xoa key, giu moc ban quyen)");
        _specifiers = nil;
        [self reloadSpecifiers];
        if (!DWPLicenseHasActiveKey()) {
            [self installExpiredOverlay];
            self.popupShownThisAppear = YES;
        }
    }]];
    [self presentViewController:alert animated:YES completion:nil];
}

@end

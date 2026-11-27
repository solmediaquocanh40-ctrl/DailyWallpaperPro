// DWPRootListController.m — DailyWallpaperPro 1.0.1

#import "DWPRootListController.h"
#import "../DWPShared.h"
#import <Preferences/PSSpecifier.h>

@implementation DWPRootListController

- (NSArray *)specifiers {
    if (!_specifiers) {
        _specifiers = [self loadSpecifiersFromPlistName:@"Root" target:self];
    }
    return _specifiers;
}

- (id)readPreferenceValue:(PSSpecifier *)specifier {
    NSString *key = [specifier propertyForKey:@"key"];
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
    }
}

- (void)showAlertTitle:(NSString *)title message:(NSString *)message {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:title message:message preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)applyNow:(id)sender {
    DWPPostDarwin(DWP_NOTIFY_APPLY);
    [self showAlertTitle:@"Da gui lenh doi ngay" message:@"Anh thoat ra man hinh khoa / man hinh chinh de coi anh da doi chua, roi gui em file log DailyWallpaperPro.log trong Documents neu chua doi."];
}

- (void)testEngine:(id)sender {
    DWPPostDarwin(DWP_NOTIFY_TEST);
    [self showAlertTitle:@"Da gui lenh test engine" message:@"Tweak se thu doi nen bang anh TEST mau do (khong can chon anh truoc). Anh coi man hinh co doi sang anh do chu DWP TEST khong, roi gui em log."];
}

- (void)resetState:(id)sender {
    DWPSetPref(DWPKeyLastChange, @(0));
    DWPSetPref(DWPKeyLastDay, @"");
    DWPSetPref(DWPKeyCurrentSlot, @(0));
    DWPPostDarwin(DWP_NOTIFY_PREFS);
    [self showAlertTitle:@"Da dat lai moc doi" message:@"Lan kiem tra tiep theo (toi da 60 giay) tweak se doi anh lai tu dau."];
}

@end

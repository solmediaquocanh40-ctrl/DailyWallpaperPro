// DWPRootListController.h — DailyWallpaperPro 1.0.5

#import <Preferences/PSListController.h>
#import <Preferences/PSSpecifier.h>
#import <Preferences/PSListItemsController.h>

@interface DWPRootListController : PSListController <UITextFieldDelegate>
@property (nonatomic, weak) UIAlertController *activeAlert;
@property (nonatomic, strong) NSTimer *popupTimer;
@property (nonatomic, assign) NSInteger popupSecondsLeft;
@property (nonatomic, assign) BOOL popupEditing;
@property (nonatomic, assign) BOOL popupShownThisAppear;
- (void)applyNow:(id)sender;
- (void)testEngine:(id)sender;
- (void)testColor:(id)sender;
- (void)resetState:(id)sender;
- (void)pickPhotosFallback:(id)sender;
- (void)exportSettings:(id)sender;
- (void)importSettings:(id)sender;
- (void)resetAll:(id)sender;
- (void)activateTapped:(id)sender;
- (void)copyMachine:(id)sender;
- (void)showActivatePopup;
- (void)showActivatePopupWithMessage:(NSString *)message;
- (void)popupTimerFired;
- (void)stopPopupTimer;
- (void)installExpiredOverlay;
- (void)removeExpiredOverlay;
- (void)expiredOverlayTapped;
@end

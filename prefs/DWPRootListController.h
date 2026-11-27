// DWPRootListController.h — DailyWallpaperPro 1.0.3

#import <Preferences/PSListController.h>
#import <Preferences/PSSpecifier.h>
#import <Preferences/PSListItemsController.h>

@interface DWPRootListController : PSListController
- (void)applyNow:(id)sender;
- (void)testEngine:(id)sender;
- (void)testColor:(id)sender;
- (void)resetState:(id)sender;
- (void)pickPhotosFallback:(id)sender;
- (void)exportSettings:(id)sender;
- (void)importSettings:(id)sender;
- (void)resetAll:(id)sender;
@end

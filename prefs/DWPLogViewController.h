// DWPLogViewController.h — DailyWallpaperPro 1.0.4

#import <UIKit/UIKit.h>
#import <Preferences/PSSpecifier.h>

@interface DWPLogViewController : UIViewController
@property (nonatomic, retain) PSSpecifier *specifier;
- (void)reloadLog;
- (void)shareLog;
- (void)clearLog;
@end

// DWPLogViewController.m — DailyWallpaperPro 1.0.7

#import "DWPLogViewController.h"
#import "../DWPShared.h"

@implementation DWPLogViewController {
    UITextView *_textView;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = DWPT(@"Nhật ký", @"Log");
    self.view.backgroundColor = [UIColor systemBackgroundColor];
    _textView = [[UITextView alloc] initWithFrame:CGRectZero];
    _textView.editable = NO;
    _textView.font = [UIFont monospacedSystemFontOfSize:11 weight:UIFontWeightRegular];
    [self.view addSubview:_textView];
    UIBarButtonItem *refresh = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemRefresh target:self action:@selector(reloadLog)];
    UIBarButtonItem *share = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemAction target:self action:@selector(shareLog)];
    UIBarButtonItem *trash = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemTrash target:self action:@selector(clearLog)];
    self.navigationItem.rightBarButtonItems = @[trash, share, refresh];
    [self reloadLog];
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    _textView.frame = self.view.bounds;
}

- (void)reloadLog {
    NSString *all = [NSString stringWithContentsOfFile:DWP_LOG_PATH encoding:NSUTF8StringEncoding error:nil];
    if (!all) {
        _textView.text = DWPT(@"Chưa có file log.", @"No log file yet.");
        return;
    }
    NSArray<NSString *> *lines = [all componentsSeparatedByString:@"\n"];
    NSInteger from = MAX(0, (NSInteger)lines.count - 400);
    _textView.text = [[lines subarrayWithRange:NSMakeRange(from, lines.count - from)] componentsJoinedByString:@"\n"];
    if (_textView.text.length > 0) {
        [_textView scrollRangeToVisible:NSMakeRange(_textView.text.length - 1, 1)];
    }
}

- (void)shareLog {
    NSURL *url = [NSURL fileURLWithPath:DWP_LOG_PATH];
    UIActivityViewController *avc = [[UIActivityViewController alloc] initWithActivityItems:@[url] applicationActivities:nil];
    [self presentViewController:avc animated:YES completion:nil];
}

- (void)clearLog {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:DWPT(@"Xoá log?", @"Clear log?") message:nil preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:DWPT(@"Huỷ", @"Cancel") style:UIAlertActionStyleCancel handler:nil]];
    [alert addAction:[UIAlertAction actionWithTitle:DWPT(@"Xoá", @"Clear") style:UIAlertActionStyleDestructive handler:^(UIAlertAction *a) {
        [[NSFileManager defaultManager] createFileAtPath:DWP_LOG_PATH contents:nil attributes:nil];
        DWPLog(@"log: anh vua xoa log tu trang Cai dat");
        [self reloadLog];
    }]];
    [self presentViewController:alert animated:YES completion:nil];
}

@end

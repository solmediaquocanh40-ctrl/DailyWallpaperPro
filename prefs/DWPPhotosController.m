// DWPPhotosController.m — DailyWallpaperPro 1.0.3
// Ban nay sua vu "khong chon duoc hinh" cua 1.0.1: log MOI buoc cua picker,
// khong con nhanh that bai im lang, trinh picker tre 0.4s sau action sheet
// (tranh dung luc sheet dang tat), co nut Chon anh ngay trong trang va
// duong du phong tai du lieu tho khi tai truc tiep that bai (DWPPickerHelper).

#import "DWPPhotosController.h"
#import "../DWPShared.h"
#import "DWPPickerHelper.h"
#import <PhotosUI/PhotosUI.h>

static UIImage *DWPThumbnailForSlot(NSInteger slot);

static UIImage *DWPThumbnailForSlot(NSInteger slot) {
    UIImage *full = [UIImage imageWithContentsOfFile:DWPSlotPath(slot)];
    if (!full) return nil;
    CGSize thumb = CGSizeMake(234, 506);
    CGFloat scale = MAX(thumb.width / full.size.width, thumb.height / full.size.height);
    CGSize scaled = CGSizeMake(full.size.width * scale, full.size.height * scale);
    UIGraphicsImageRenderer *renderer = [[UIGraphicsImageRenderer alloc] initWithSize:thumb];
    return [renderer imageWithActions:^(UIGraphicsImageRendererContext *ctx) {
        [full drawInRect:CGRectMake((thumb.width - scaled.width) / 2.0, (thumb.height - scaled.height) / 2.0, scaled.width, scaled.height)];
    }];
}

@interface DWPPhotosController () <UICollectionViewDataSource, UICollectionViewDelegate, PHPickerViewControllerDelegate>
- (NSInteger)displayCount;
- (void)refreshStatus;
- (void)pickMultiple;
- (void)pickSingleForSlot:(NSInteger)slot;
- (void)presentPickerWithLimit:(NSInteger)limit replaceSlot:(NSInteger)replaceSlot afterDelay:(BOOL)afterDelay;
- (void)handlePickedImages:(NSArray<UIImage *> *)images replaceSlot:(NSInteger)replaceSlot;
- (void)tapSlot:(NSInteger)slot filled:(BOOL)filled sourceView:(UIView *)sourceView;
- (void)swapSlot:(NSInteger)a withSlot:(NSInteger)b;
- (void)clearSlot:(NSInteger)slot;
- (void)deleteAllPhotos;
- (void)showMessage:(NSString *)message;
@end

@implementation DWPPhotosController {
    UICollectionView *_grid;
    UILabel *_status;
    UIButton *_pickButton;
    UIButton *_deleteAllButton;
    NSInteger _replaceSlot;
    NSInteger _swapSource;
    NSCache<NSNumber *, UIImage *> *_thumbs;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    DWPLog(@"photos: trang danh sach anh vua MO (viewDidLoad)");
    self.title = DWPT(@"Danh sách ảnh", @"Photo list");
    _replaceSlot = 0;
    _swapSource = 0;
    _thumbs = [[NSCache alloc] init];
    self.view.backgroundColor = [UIColor systemBackgroundColor];
    _status = [[UILabel alloc] initWithFrame:CGRectZero];
    _status.numberOfLines = 0;
    _status.font = [UIFont systemFontOfSize:14];
    [self.view addSubview:_status];
    _pickButton = [UIButton buttonWithType:UIButtonTypeSystem];
    [_pickButton setTitle:DWPT(@"Chọn ảnh", @"Pick photos") forState:UIControlStateNormal];
    _pickButton.titleLabel.font = [UIFont boldSystemFontOfSize:16];
    [_pickButton addTarget:self action:@selector(pickMultiple) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:_pickButton];
    _deleteAllButton = [UIButton buttonWithType:UIButtonTypeSystem];
    [_deleteAllButton setTitle:DWPT(@"Xoá tất cả", @"Delete all") forState:UIControlStateNormal];
    [_deleteAllButton setTitleColor:[UIColor systemRedColor] forState:UIControlStateNormal];
    [_deleteAllButton addTarget:self action:@selector(deleteAllPhotos) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:_deleteAllButton];
    UICollectionViewFlowLayout *layout = [[UICollectionViewFlowLayout alloc] init];
    layout.minimumInteritemSpacing = 6;
    layout.minimumLineSpacing = 6;
    layout.sectionInset = UIEdgeInsetsMake(8, 8, 8, 8);
    _grid = [[UICollectionView alloc] initWithFrame:CGRectZero collectionViewLayout:layout];
    _grid.dataSource = self;
    _grid.delegate = self;
    _grid.backgroundColor = [UIColor systemBackgroundColor];
    [_grid registerClass:[UICollectionViewCell class] forCellWithReuseIdentifier:@"slot"];
    [self.view addSubview:_grid];
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:DWPT(@"Chọn ảnh", @"Pick") style:UIBarButtonItemStyleDone target:self action:@selector(pickMultiple)];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    DWPLog(@"photos: trang anh xuat hien, dang co %ld anh", (long)DWPFilledSlots().count);
    [_thumbs removeAllObjects];
    [self refreshStatus];
    [_grid reloadData];
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    CGFloat w = self.view.bounds.size.width;
    CGFloat statusH = 76;
    _status.frame = CGRectMake(12, 8, w - 24, statusH);
    CGFloat btnY = statusH + 10;
    _pickButton.frame = CGRectMake(12, btnY, (w - 32) / 2.0, 36);
    _deleteAllButton.frame = CGRectMake(20 + (w - 32) / 2.0, btnY, (w - 32) / 2.0, 36);
    CGFloat gridY = btnY + 44;
    _grid.frame = CGRectMake(0, gridY, w, self.view.bounds.size.height - gridY);
    UICollectionViewFlowLayout *layout = (UICollectionViewFlowLayout *)_grid.collectionViewLayout;
    CGFloat cellW = floor((w - 16 - 12) / 3.0);
    layout.itemSize = CGSizeMake(cellW, cellW * 1.6);
}

- (NSInteger)displayCount {
    NSInteger mode = DWPPrefInt(DWPKeyRotationMode, 0);
    if (mode == 0) return DWPDaysInCurrentMonth();
    return 31;
}

- (void)refreshStatus {
    NSInteger mode = DWPPrefInt(DWPKeyRotationMode, 0);
    NSInteger filled = (NSInteger)DWPFilledSlots().count;
    if (mode == 0) {
        _status.text = [NSString stringWithFormat:DWPT(@"Chế độ lịch tháng: tháng này có %ld ngày — đã có %ld ảnh. Ô số mấy là ảnh của ngày ấy. Bấm 1 ô để đổi ảnh / đổi vị trí / xoá.", @"Calendar mode: this month has %ld days — %ld photos saved. Slot N is day N's photo. Tap a slot to replace / swap / delete."),
                        (long)DWPDaysInCurrentMonth(), (long)filled];
    } else {
        _status.text = [NSString stringWithFormat:DWPT(@"Đã có %ld ảnh (tối đa 31). Bấm 1 ô để đổi ảnh / đổi vị trí / xoá. Bấm 'Chọn ảnh' để chọn lại cả bộ cùng lúc.", @"%ld photos saved (max 31). Tap a slot to replace / swap / delete. Tap 'Pick photos' to re-pick the whole set."),
                        (long)filled];
    }
    if (_swapSource > 0) {
        _status.text = [NSString stringWithFormat:DWPT(@"Đang đổi vị trí: hãy bấm ô đích để hoán đổi với ô %ld.", @"Swapping: tap the target slot to swap with slot %ld."), (long)_swapSource];
    }
}

#pragma mark - Collection

- (NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section {
    return [self displayCount];
}

- (UICollectionViewCell *)collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath {
    NSInteger slot = indexPath.item + 1;
    UICollectionViewCell *cell = [collectionView dequeueReusableCellWithReuseIdentifier:@"slot" forIndexPath:indexPath];
    for (UIView *v in [cell.contentView.subviews copy]) [v removeFromSuperview];
    cell.contentView.backgroundColor = [UIColor secondarySystemBackgroundColor];
    cell.contentView.layer.cornerRadius = 8;
    cell.contentView.clipsToBounds = YES;
    UIImage *thumb = [_thumbs objectForKey:@(slot)];
    if (!thumb) {
        thumb = DWPThumbnailForSlot(slot);
        if (thumb) [_thumbs setObject:thumb forKey:@(slot)];
    }
    if (thumb) {
        UIImageView *iv = [[UIImageView alloc] initWithFrame:cell.contentView.bounds];
        iv.contentMode = UIViewContentModeScaleAspectFill;
        iv.clipsToBounds = YES;
        iv.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        iv.image = thumb;
        [cell.contentView addSubview:iv];
    } else {
        UILabel *plus = [[UILabel alloc] initWithFrame:cell.contentView.bounds];
        plus.text = @"+";
        plus.textAlignment = NSTextAlignmentCenter;
        plus.font = [UIFont systemFontOfSize:30];
        plus.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        [cell.contentView addSubview:plus];
    }
    UILabel *badge = [[UILabel alloc] initWithFrame:CGRectMake(4, 4, 44, 20)];
    badge.text = [NSString stringWithFormat:@"%ld", (long)slot];
    badge.font = [UIFont boldSystemFontOfSize:13];
    badge.textColor = [UIColor whiteColor];
    badge.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.55];
    badge.textAlignment = NSTextAlignmentCenter;
    badge.layer.cornerRadius = 6;
    badge.clipsToBounds = YES;
    [cell.contentView addSubview:badge];
    if (_swapSource == slot) {
        cell.contentView.layer.borderWidth = 3;
        cell.contentView.layer.borderColor = [UIColor systemOrangeColor].CGColor;
    } else {
        cell.contentView.layer.borderWidth = 0;
    }
    return cell;
}

- (void)collectionView:(UICollectionView *)collectionView didSelectItemAtIndexPath:(NSIndexPath *)indexPath {
    NSInteger slot = indexPath.item + 1;
    DWPLog(@"photos: anh bam o %ld", (long)slot);
    UICollectionViewCell *cell = [collectionView cellForItemAtIndexPath:indexPath];
    if (_swapSource > 0) {
        if (_swapSource != slot) [self swapSlot:_swapSource withSlot:slot];
        _swapSource = 0;
        [self refreshStatus];
        [_grid reloadData];
        return;
    }
    BOOL filled = [[NSFileManager defaultManager] fileExistsAtPath:DWPSlotPath(slot)];
    [self tapSlot:slot filled:filled sourceView:cell.contentView];
}

#pragma mark - Actions on a slot

- (void)tapSlot:(NSInteger)slot filled:(BOOL)filled sourceView:(UIView *)sourceView {
    UIAlertController *sheet = [UIAlertController alertControllerWithTitle:[NSString stringWithFormat:DWPT(@"Ảnh ô %ld", @"Slot %ld photo"), (long)slot] message:nil preferredStyle:UIAlertControllerStyleActionSheet];
    if (filled) {
        [sheet addAction:[UIAlertAction actionWithTitle:DWPT(@"Đổi ảnh này", @"Replace this photo") style:UIAlertActionStyleDefault handler:^(UIAlertAction *a) { [self pickSingleForSlot:slot]; }]];
        [sheet addAction:[UIAlertAction actionWithTitle:DWPT(@"Đổi vị trí với ô khác", @"Swap with another slot") style:UIAlertActionStyleDefault handler:^(UIAlertAction *a) {
            self->_swapSource = slot;
            [self refreshStatus];
            [self->_grid reloadData];
        }]];
        [sheet addAction:[UIAlertAction actionWithTitle:DWPT(@"Xoá ảnh này", @"Delete this photo") style:UIAlertActionStyleDestructive handler:^(UIAlertAction *a) { [self clearSlot:slot]; }]];
    } else {
        [sheet addAction:[UIAlertAction actionWithTitle:DWPT(@"Chọn ảnh cho ô này", @"Pick a photo for this slot") style:UIAlertActionStyleDefault handler:^(UIAlertAction *a) { [self pickSingleForSlot:slot]; }]];
    }
    [sheet addAction:[UIAlertAction actionWithTitle:DWPT(@"Huỷ", @"Cancel") style:UIAlertActionStyleCancel handler:nil]];
    if (sheet.popoverPresentationController) {
        sheet.popoverPresentationController.sourceView = sourceView;
        sheet.popoverPresentationController.sourceRect = sourceView.bounds;
    }
    [self presentViewController:sheet animated:YES completion:nil];
}

- (void)swapSlot:(NSInteger)a withSlot:(NSInteger)b {
    NSFileManager *fm = [NSFileManager defaultManager];
    NSString *pa = DWPSlotPath(a), *pb = DWPSlotPath(b);
    NSString *tmp = [DWP_PHOTOS_DIR stringByAppendingPathComponent:@"swap-tmp.jpg"];
    BOOL hasA = [fm fileExistsAtPath:pa], hasB = [fm fileExistsAtPath:pb];
    [fm removeItemAtPath:tmp error:nil];
    if (hasA) [fm moveItemAtPath:pa toPath:tmp error:nil];
    if (hasB) [fm moveItemAtPath:pb toPath:pa error:nil];
    if (hasA) [fm moveItemAtPath:tmp toPath:pb error:nil];
    [_thumbs removeObjectForKey:@(a)];
    [_thumbs removeObjectForKey:@(b)];
    DWPLog(@"photos: hoan doi o %ld <-> o %ld", (long)a, (long)b);
    DWPPostDarwin(DWP_NOTIFY_PREFS);
}

- (void)clearSlot:(NSInteger)slot {
    [[NSFileManager defaultManager] removeItemAtPath:DWPSlotPath(slot) error:nil];
    [_thumbs removeObjectForKey:@(slot)];
    DWPLog(@"photos: xoa anh o %ld", (long)slot);
    DWPPostDarwin(DWP_NOTIFY_PREFS);
    [self refreshStatus];
    [_grid reloadData];
}

- (void)deleteAllPhotos {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:DWPT(@"Xoá tất cả ảnh?", @"Delete all photos?")
        message:DWPT(@"Toàn bộ ảnh trong các ô sẽ bị xoá. Cài đặt giữ nguyên.", @"All slot photos will be deleted. Settings stay.")
        preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:DWPT(@"Huỷ", @"Cancel") style:UIAlertActionStyleCancel handler:nil]];
    [alert addAction:[UIAlertAction actionWithTitle:DWPT(@"Xoá tất cả", @"Delete all") style:UIAlertActionStyleDestructive handler:^(UIAlertAction *a) {
        NSFileManager *fm = [NSFileManager defaultManager];
        for (NSInteger s = 1; s <= 31; s++) [fm removeItemAtPath:DWPSlotPath(s) error:nil];
        [self->_thumbs removeAllObjects];
        DWPLog(@"photos: anh vua XOA TAT CA anh");
        DWPPostDarwin(DWP_NOTIFY_PREFS);
        [self refreshStatus];
        [self->_grid reloadData];
    }]];
    [self presentViewController:alert animated:YES completion:nil];
}

#pragma mark - Picker

- (void)pickMultiple {
    DWPLog(@"photos: anh bam CHON ANH (ca bo)");
    [self presentPickerWithLimit:[self displayCount] replaceSlot:0 afterDelay:NO];
}

- (void)pickSingleForSlot:(NSInteger)slot {
    DWPLog(@"photos: anh chon anh cho o %ld", (long)slot);
    [self presentPickerWithLimit:1 replaceSlot:slot afterDelay:YES];
}

- (void)presentPickerWithLimit:(NSInteger)limit replaceSlot:(NSInteger)replaceSlot afterDelay:(BOOL)afterDelay {
    _replaceSlot = replaceSlot;
    void (^presentBlock)(void) = ^{
        PHPickerConfiguration *config = [[PHPickerConfiguration alloc] init];
        config.selectionLimit = limit;
        config.filter = [PHPickerFilter imagesFilter];
        PHPickerViewController *picker = [[PHPickerViewController alloc] initWithConfiguration:config];
        picker.delegate = self;
        DWPLog(@"picker: chuan bi trinh bo chon anh (gioi han %ld, thay o %ld)", (long)limit, (long)replaceSlot);
        [self presentViewController:picker animated:YES completion:^{
            DWPLog(@"picker: da trinh xong, dang cho anh chon");
        }];
    };
    if (afterDelay) {
        // Cho action sheet tat han roi moi trinh — ban 1.0.1 trinh ngay lap
        // tuc nen co the bi iOS huy trinh trong im lang.
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.45 * NSEC_PER_SEC)), dispatch_get_main_queue(), presentBlock);
    } else {
        presentBlock();
    }
}

- (void)picker:(PHPickerViewController *)picker didFinishPicking:(NSArray<PHPickerResult *> *)results {
    [picker dismissViewControllerAnimated:YES completion:nil];
    NSInteger replaceSlot = _replaceSlot;
    if (results.count == 0) {
        DWPLog(@"picker: anh huy chon (0 ket qua)");
        return;
    }
    DWPLoadPickerImages(results, ^(NSArray<UIImage *> *images) {
        [self handlePickedImages:images replaceSlot:replaceSlot];
    });
}

- (void)handlePickedImages:(NSArray<UIImage *> *)images replaceSlot:(NSInteger)replaceSlot {
    if (images.count == 0) {
        DWPLog(@"picker: TAI ANH THAT BAI toan bo — khong luu duoc anh nao");
        [self showMessage:DWPT(@"Không tải được ảnh nào. Anh thử chọn lại, hoặc gửi em log để em coi các dòng picker.", @"No photo could be loaded. Try again, or send me the log so I can read the picker lines.")];
        return;
    }
    NSInteger saved = DWPSaveWallpaperImages(images, replaceSlot);
    if (saved == 0) {
        [self showMessage:DWPT(@"Lưu ảnh thất bại. Anh gửi em log để em coi dòng lưu ảnh.", @"Saving failed. Send me the log so I can read the save lines.")];
        return;
    }
    [_thumbs removeAllObjects];
    DWPPostDarwin(DWP_NOTIFY_PREFS);
    [self refreshStatus];
    [_grid reloadData];
    [self showMessage:[NSString stringWithFormat:DWPT(@"Đã lưu %ld ảnh.", @"Saved %ld photos."), (long)saved]];
}

- (void)showMessage:(NSString *)message {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"DailyWallpaper Pro" message:message preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}

@end

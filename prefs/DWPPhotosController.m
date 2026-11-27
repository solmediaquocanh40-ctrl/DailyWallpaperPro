// DWPPhotosController.m — DailyWallpaperPro 1.0.0

#import "DWPPhotosController.h"
#import "../DWPShared.h"
#import <PhotosUI/PhotosUI.h>

static UIImage *DWPWallpaperSizedImage(UIImage *src);
static UIImage *DWPThumbnailForSlot(NSInteger slot);

static UIImage *DWPWallpaperSizedImage(UIImage *src) {
    if (!src) return nil;
    CGSize target = CGSizeMake(1170, 2532);
    CGFloat scale = MAX(target.width / src.size.width, target.height / src.size.height);
    CGSize scaled = CGSizeMake(src.size.width * scale, src.size.height * scale);
    UIGraphicsImageRenderer *renderer = [[UIGraphicsImageRenderer alloc] initWithSize:target];
    return [renderer imageWithActions:^(UIGraphicsImageRendererContext *ctx) {
        [src drawInRect:CGRectMake((target.width - scaled.width) / 2.0, (target.height - scaled.height) / 2.0, scaled.width, scaled.height)];
    }];
}

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
- (void)presentPickerWithLimit:(NSInteger)limit replaceSlot:(NSInteger)replaceSlot;
- (void)saveImages:(NSArray<UIImage *> *)images replaceSlot:(NSInteger)replaceSlot;
- (void)tapSlot:(NSInteger)slot filled:(BOOL)filled sourceView:(UIView *)sourceView;
- (void)swapSlot:(NSInteger)a withSlot:(NSInteger)b;
- (void)clearSlot:(NSInteger)slot;
- (void)showMessage:(NSString *)message;
@end

@implementation DWPPhotosController {
    UICollectionView *_grid;
    UILabel *_status;
    NSInteger _replaceSlot;
    NSInteger _swapSource;
    NSCache<NSNumber *, UIImage *> *_thumbs;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"Danh sach anh";
    _replaceSlot = 0;
    _swapSource = 0;
    _thumbs = [[NSCache alloc] init];
    self.view.backgroundColor = [UIColor systemBackgroundColor];
    _status = [[UILabel alloc] initWithFrame:CGRectZero];
    _status.numberOfLines = 0;
    _status.font = [UIFont systemFontOfSize:14];
    [self.view addSubview:_status];
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
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"Chon anh" style:UIBarButtonItemStyleDone target:self action:@selector(pickMultiple)];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [_thumbs removeAllObjects];
    [self refreshStatus];
    [_grid reloadData];
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    CGFloat w = self.view.bounds.size.width;
    CGFloat statusH = 76;
    _status.frame = CGRectMake(12, 8, w - 24, statusH);
    _grid.frame = CGRectMake(0, statusH + 12, w, self.view.bounds.size.height - statusH - 12);
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
        _status.text = [NSString stringWithFormat:@"Che do lich thang: thang nay co %ld ngay — da co %ld anh. O so may la anh cua ngay ay. Bam 1 o de doi anh / doi vi tri / xoa.", (long)DWPDaysInCurrentMonth(), (long)filled];
    } else {
        _status.text = [NSString stringWithFormat:@"Da co %ld anh (toi da 31). Bam 1 o de doi anh / doi vi tri / xoa. Bam 'Chon anh' de chon lai ca bo cung luc.", (long)filled];
    }
    if (_swapSource > 0) {
        _status.text = [NSString stringWithFormat:@"Dang doi vi tri: hay bam o dich de hoan doi voi o %ld.", (long)_swapSource];
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
    UIAlertController *sheet = [UIAlertController alertControllerWithTitle:[NSString stringWithFormat:@"Anh o %ld", (long)slot] message:nil preferredStyle:UIAlertControllerStyleActionSheet];
    if (filled) {
        [sheet addAction:[UIAlertAction actionWithTitle:@"Doi anh nay" style:UIAlertActionStyleDefault handler:^(UIAlertAction *a) { [self pickSingleForSlot:slot]; }]];
        [sheet addAction:[UIAlertAction actionWithTitle:@"Doi vi tri voi o khac" style:UIAlertActionStyleDefault handler:^(UIAlertAction *a) {
            self->_swapSource = slot;
            [self refreshStatus];
            [self->_grid reloadData];
        }]];
        [sheet addAction:[UIAlertAction actionWithTitle:@"Xoa anh nay" style:UIAlertActionStyleDestructive handler:^(UIAlertAction *a) { [self clearSlot:slot]; }]];
    } else {
        [sheet addAction:[UIAlertAction actionWithTitle:@"Chon anh cho o nay" style:UIAlertActionStyleDefault handler:^(UIAlertAction *a) { [self pickSingleForSlot:slot]; }]];
    }
    [sheet addAction:[UIAlertAction actionWithTitle:@"Huy" style:UIAlertActionStyleCancel handler:nil]];
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
    DWPLog(@"prefs: hoan doi o %ld <-> o %ld", (long)a, (long)b);
    DWPPostDarwin(DWP_NOTIFY_PREFS);
}

- (void)clearSlot:(NSInteger)slot {
    [[NSFileManager defaultManager] removeItemAtPath:DWPSlotPath(slot) error:nil];
    [_thumbs removeObjectForKey:@(slot)];
    DWPLog(@"prefs: xoa anh o %ld", (long)slot);
    DWPPostDarwin(DWP_NOTIFY_PREFS);
    [self refreshStatus];
    [_grid reloadData];
}

#pragma mark - Picker

- (void)pickMultiple {
    [self presentPickerWithLimit:[self displayCount] replaceSlot:0];
}

- (void)pickSingleForSlot:(NSInteger)slot {
    [self presentPickerWithLimit:1 replaceSlot:slot];
}

- (void)presentPickerWithLimit:(NSInteger)limit replaceSlot:(NSInteger)replaceSlot {
    _replaceSlot = replaceSlot;
    PHPickerConfiguration *config = [[PHPickerConfiguration alloc] init];
    config.selectionLimit = limit;
    config.filter = [PHPickerFilter imagesFilter];
    PHPickerViewController *picker = [[PHPickerViewController alloc] initWithConfiguration:config];
    picker.delegate = self;
    [self presentViewController:picker animated:YES completion:nil];
}

- (void)picker:(PHPickerViewController *)picker didFinishPicking:(NSArray<PHPickerResult *> *)results {
    [picker dismissViewControllerAnimated:YES completion:nil];
    if (results.count == 0) return;
    NSInteger replaceSlot = _replaceSlot;
    NSMutableArray<UIImage *> *images = [NSMutableArray arrayWithCapacity:results.count];
    for (NSUInteger i = 0; i < results.count; i++) [images addObject:(UIImage *)[NSNull null]];
    dispatch_group_t group = dispatch_group_create();
    [results enumerateObjectsUsingBlock:^(PHPickerResult *result, NSUInteger idx, BOOL *stop) {
        dispatch_group_enter(group);
        [result.itemProvider loadObjectOfClass:[UIImage class] completionHandler:^(id<NSItemProviderReading> object, NSError *error) {
            if ([object isKindOfClass:[UIImage class]]) {
                @synchronized (images) { images[idx] = (UIImage *)object; }
            }
            dispatch_group_leave(group);
        }];
    }];
    dispatch_group_notify(group, dispatch_get_main_queue(), ^{
        NSMutableArray<UIImage *> *real = [NSMutableArray array];
        for (id obj in images) if ([obj isKindOfClass:[UIImage class]]) [real addObject:obj];
        if (real.count > 0) [self saveImages:real replaceSlot:replaceSlot];
    });
}

- (void)saveImages:(NSArray<UIImage *> *)images replaceSlot:(NSInteger)replaceSlot {
    NSFileManager *fm = [NSFileManager defaultManager];
    [fm createDirectoryAtPath:DWP_PHOTOS_DIR withIntermediateDirectories:YES attributes:nil error:nil];
    if (replaceSlot > 0) {
        UIImage *sized = DWPWallpaperSizedImage(images.firstObject);
        NSData *data = sized ? UIImageJPEGRepresentation(sized, 0.85) : nil;
        if (data) [data writeToFile:DWPSlotPath(replaceSlot) atomically:YES];
        [_thumbs removeObjectForKey:@(replaceSlot)];
        DWPLog(@"prefs: doi anh o %ld", (long)replaceSlot);
    } else {
        for (NSInteger s = 1; s <= 31; s++) [fm removeItemAtPath:DWPSlotPath(s) error:nil];
        NSInteger slot = 1;
        for (UIImage *img in images) {
            UIImage *sized = DWPWallpaperSizedImage(img);
            NSData *data = sized ? UIImageJPEGRepresentation(sized, 0.85) : nil;
            if (data) [data writeToFile:DWPSlotPath(slot) atomically:YES];
            slot++;
        }
        [_thumbs removeAllObjects];
        DWPLog(@"prefs: chon lai ca bo %lu anh", (unsigned long)images.count);
    }
    DWPPostDarwin(DWP_NOTIFY_PREFS);
    [self refreshStatus];
    [_grid reloadData];
    [self showMessage:[NSString stringWithFormat:@"Da luu %lu anh.", (unsigned long)images.count]];
}

- (void)showMessage:(NSString *)message {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"DailyWallpaper Pro" message:message preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}

@end

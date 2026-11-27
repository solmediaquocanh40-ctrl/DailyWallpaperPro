// DWPPickerHelper.m — DailyWallpaperPro 1.0.7
// Ban nay doi duong tai chinh: log 1.0.3 chung minh NSItemProvider chet
// 0/7 vi file tam cua extension chon anh KHONG TON TAI trong container
// PluginKitPlugin (loi -1000 "Cannot load representation of type
// public.jpeg" / "No such file or directory") o ca 2 duong truc tiep va
// du lieu tho. Duong moi di thang vao thu vien anh bang assetIdentifier +
// PHImageManager (khong dung file tam cua extension), NSItemProvider chi
// con la du phong. Neu tai 0 anh thi log luon dung luong trong de vong
// sau co bang chung (nghi van may het dung luong lam extension khong
// ghi duoc file tam).

#import "DWPPickerHelper.h"
#import "../DWPShared.h"
#import <Photos/Photos.h>
#import <sys/mount.h>

static long long DWPFreeBytes(void) {
    struct statfs s;
    if (statfs("/var/mobile", &s) != 0) return -1;
    return (long long)s.f_bavail * (long long)s.f_bsize;
}

static void DWPStoreLoaded(NSMutableArray *slots, NSUInteger idx, UIImage *img, NSString *route) {
    @synchronized (slots) { slots[idx] = img; }
    DWPLog(@"picker: muc %lu tai OK qua %@ (%lux%lu)", (unsigned long)idx, route,
           (unsigned long)img.size.width, (unsigned long)img.size.height);
}

void DWPLoadPickerImages(NSArray<PHPickerResult *> *results, void (^completion)(NSArray<UIImage *> *images)) {
    DWPLog(@"picker: delegate nhan %lu ket qua", (unsigned long)results.count);
    PHAuthorizationStatus auth = [PHPhotoLibrary authorizationStatusForAccessLevel:PHAccessLevelReadWrite];
    DWPLog(@"picker: quyen thu vien anh cua Cai dat = %ld (0=chua hoi, 1=bi chan, 2=bi tu choi, 3=duoc phep, 4=gioi han)", (long)auth);
    NSMutableArray *slots = [NSMutableArray arrayWithCapacity:results.count];
    for (NSUInteger i = 0; i < results.count; i++) [slots addObject:[NSNull null]];
    dispatch_group_t group = dispatch_group_create();
    [results enumerateObjectsUsingBlock:^(PHPickerResult *result, NSUInteger idx, BOOL *stop) {
        dispatch_group_enter(group);
        NSString *assetID = result.assetIdentifier;
        PHAsset *asset = nil;
        if (assetID.length > 0) {
            asset = [PHAsset fetchAssetsWithLocalIdentifiers:@[assetID] options:nil].firstObject;
        }
        if (asset) {
            PHImageRequestOptions *opts = [[PHImageRequestOptions alloc] init];
            opts.deliveryMode = PHImageRequestOptionsDeliveryModeHighQualityFormat;
            opts.networkAccessAllowed = YES;
            opts.synchronous = NO;
            [[PHImageManager defaultManager] requestImageForAsset:asset
                                                        targetSize:PHImageManagerMaximumSize
                                                       contentMode:PHImageContentModeAspectFit
                                                           options:opts
                                                     resultHandler:^(UIImage *image, NSDictionary *info) {
                if (image && ![info[PHImageResultIsDegradedKey] boolValue]) {
                    DWPStoreLoaded(slots, idx, image, @"PhotoKit");
                    dispatch_group_leave(group);
                } else if (!image) {
                    DWPLog(@"picker: muc %lu PhotoKit THAT BAI (%@), lui ve NSItemProvider", (unsigned long)idx, info[PHImageErrorKey] ? info[PHImageErrorKey] : @"khong co anh");
                    [result.itemProvider loadObjectOfClass:[UIImage class] completionHandler:^(id<NSItemProviderReading> object, NSError *error) {
                        if ([object isKindOfClass:[UIImage class]]) {
                            DWPStoreLoaded(slots, idx, (UIImage *)object, @"NSItemProvider du phong");
                        } else {
                            DWPLog(@"picker: muc %lu NSItemProvider du phong cung THAT BAI (%@)", (unsigned long)idx, error ? error : @"khong phai UIImage");
                        }
                        dispatch_group_leave(group);
                    }];
                }
                // Ban degraded (anh mo tam): bo qua, cho ban net goi lai.
            }];
        } else {
            DWPLog(@"picker: muc %lu khong co assetIdentifier/asset (%@), dung NSItemProvider", (unsigned long)idx, assetID ? assetID : @"nil");
            [result.itemProvider loadObjectOfClass:[UIImage class] completionHandler:^(id<NSItemProviderReading> object, NSError *error) {
                if ([object isKindOfClass:[UIImage class]]) {
                    DWPStoreLoaded(slots, idx, (UIImage *)object, @"NSItemProvider");
                } else {
                    DWPLog(@"picker: muc %lu NSItemProvider THAT BAI (%@), thu du lieu tho", (unsigned long)idx, error ? error : @"khong phai UIImage");
                    [result.itemProvider loadDataRepresentationForTypeIdentifier:@"public.image" completionHandler:^(NSData *data, NSError *error2) {
                        if (data) {
                            UIImage *img = [UIImage imageWithData:data];
                            if (img) DWPStoreLoaded(slots, idx, img, @"du lieu tho");
                            else DWPLog(@"picker: muc %lu du lieu khong thanh anh duoc", (unsigned long)idx);
                        } else {
                            DWPLog(@"picker: muc %lu du lieu tho THAT BAI (%@)", (unsigned long)idx, error2 ? error2 : @"khong co du lieu");
                        }
                        dispatch_group_leave(group);
                        return;
                    }];
                    return;
                }
                dispatch_group_leave(group);
            }];
        }
    }];
    dispatch_group_notify(group, dispatch_get_main_queue(), ^{
        NSMutableArray<UIImage *> *real = [NSMutableArray array];
        for (id obj in slots) if ([obj isKindOfClass:[UIImage class]]) [real addObject:obj];
        DWPLog(@"picker: tai xong %lu/%lu anh", (unsigned long)real.count, (unsigned long)results.count);
        if (real.count == 0) {
            long long freeB = DWPFreeBytes();
            DWPLog(@"picker: TAI 0 ANH — dung luong con trong o /var/mobile: %.1f MB", freeB >= 0 ? freeB / 1048576.0 : -1.0);
        }
        completion([real copy]);
    });
}

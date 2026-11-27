// DWPPickerHelper.m — DailyWallpaperPro 1.0.3

#import "DWPPickerHelper.h"
#import "../DWPShared.h"
#import <UniformTypeIdentifiers/UniformTypeIdentifiers.h>

void DWPLoadPickerImages(NSArray<PHPickerResult *> *results, void (^completion)(NSArray<UIImage *> *images)) {
    DWPLog(@"picker: delegate nhan %lu ket qua", (unsigned long)results.count);
    NSMutableArray *slots = [NSMutableArray arrayWithCapacity:results.count];
    for (NSUInteger i = 0; i < results.count; i++) [slots addObject:[NSNull null]];
    dispatch_group_t group = dispatch_group_create();
    [results enumerateObjectsUsingBlock:^(PHPickerResult *result, NSUInteger idx, BOOL *stop) {
        dispatch_group_enter(group);
        NSItemProvider *provider = result.itemProvider;
        [provider loadObjectOfClass:[UIImage class] completionHandler:^(id<NSItemProviderReading> object, NSError *error) {
            if ([object isKindOfClass:[UIImage class]]) {
                @synchronized (slots) { slots[idx] = (UIImage *)object; }
                DWPLog(@"picker: muc %lu tai truc tiep OK (%lux%lu)", (unsigned long)idx,
                       (unsigned long)((UIImage *)object).size.width, (unsigned long)((UIImage *)object).size.height);
                dispatch_group_leave(group);
            } else {
                DWPLog(@"picker: muc %lu tai truc tiep THAT BAI (%@), thu duong du lieu tho", (unsigned long)idx, error ? error : @"khong phai UIImage");
                [provider loadDataRepresentationForTypeIdentifier:@"public.image" completionHandler:^(NSData *data, NSError *error2) {
                    if (data) {
                        UIImage *img = [UIImage imageWithData:data];
                        if (img) {
                            @synchronized (slots) { slots[idx] = img; }
                            DWPLog(@"picker: muc %lu tai du phong OK", (unsigned long)idx);
                        } else {
                            DWPLog(@"picker: muc %lu du lieu khong thanh anh duoc", (unsigned long)idx);
                        }
                    } else {
                        DWPLog(@"picker: muc %lu tai du phong THAT BAI (%@)", (unsigned long)idx, error2 ? error2 : @"khong co du lieu");
                    }
                    dispatch_group_leave(group);
                }];
            }
        }];
    }];
    dispatch_group_notify(group, dispatch_get_main_queue(), ^{
        NSMutableArray<UIImage *> *real = [NSMutableArray array];
        for (id obj in slots) if ([obj isKindOfClass:[UIImage class]]) [real addObject:obj];
        DWPLog(@"picker: tai xong %lu/%lu anh", (unsigned long)real.count, (unsigned long)results.count);
        completion([real copy]);
    });
}

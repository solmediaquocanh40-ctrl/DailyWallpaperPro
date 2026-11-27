// DWPPickerHelper.h — DailyWallpaperPro 1.0.7
// Tai anh tu ket qua PHPicker theo dung thu tu da chon, co duong du phong
// loadDataRepresentation khi loadObjectOfClass that bai. Moi buoc deu ghi log —
// ban 1.0.1 that bai trong im lang nen tu ban nay khong co nhanh nao im lang.

#import <Foundation/Foundation.h>
#import <PhotosUI/PhotosUI.h>

// completion chay tren main queue, images chi gom cac anh tai duoc that.
void DWPLoadPickerImages(NSArray<PHPickerResult *> *results, void (^completion)(NSArray<UIImage *> *images));

# DailyWallpaper Pro 1.0.1

Tweak `com.anhdang.dailywallpaperpro` cho iPhone 12 Pro / iOS 16.3.1 / Dopamine rootless
(build du 3 scheme: rootless, rootful, roothide).

## Tinh nang

- **Theo lich thang:** thang co bao nhieu ngay thi chon bay nhieu anh (thang 2 nam nhuan
  29 anh, thang thuong 28/30/31 anh). Ngay may hien anh o ay. Qua thang moi quay lai o 1.
- **Theo khoang thoi gian tu set:** nhap so + don vi Phut / Gio / Ngay / Thang
  (vd 30 phut, 24 gio, 48 gio, 2 ngay, 1 thang). Thu tu Lan luot hoac Ngau nhien.
- **Tat:** chi dung 1 anh co dinh, chi doi khi bam "Doi anh ngay bay gio".
- **Noi doi:** chi man hinh khoa / chi man hinh chinh / ca hai (Both).
- **Gio bat dau ngay** cho che do lich thang.
- **Quan ly anh ngay trong Cai dat:** chon nhieu anh cung luc bang PHPicker, xem luoi
  theo o ngay, doi tung anh, hoan doi vi tri giua 2 o (vd o 5 <-> o 29), xoa tung o.
  Anh duoc copy va thu ve 1170x2532 vao `/var/mobile/Library/DailyWallpaperPro/`,
  khong tro thang vao Thu vien Anh.

## Trang thai ban 1.0.1 — CAN TEST MAY THAT

- Phan logic (lich thang, khoang thoi gian, quan ly o anh) da kiem tinh day du.
- **Engine doi nen tren iOS 16 CHUA co bang chung tren may that.** iOS 16 doi sang he
  PosterBoard nen ban nay do API luc chay: `DWPEngine` dump toan bo class/method
  wallpaper tim thay vao log va thu lan luot cac duong da biet, ghi ro duong nao
  ton tai / duong nao nhan lenh. Nut **Test engine** trong Cai dat doi nen bang anh
  do "DWP TEST" de kiem tra ma khong can chon anh truoc.
- Log: `/var/mobile/Documents/DailyWallpaperPro.log` — co loi thi gui file nay de fix.

## Cach test de gui log co gia tri nhat

1. Cai .deb rootless, respring.
2. Vao Cai dat > DailyWallpaper Pro > bam **Test engine** tung muc o "Doi o dau":
   Khoa / Chinh / Both — moi lan thoat ra coi man hinh co doi sang anh do khong.
3. Chon vai anh trong "Quan ly danh sach anh", bam **Doi anh ngay bay gio**, coi ket qua.
4. Gui `DailyWallpaperPro.log` kem ghi chu muc nao doi duoc / muc nao khong.

# DailyWallpaper Pro 1.0.3

Tweak `com.anhdang.dailywallpaperpro` cho iPhone 12 Pro / iOS 16.3.1 / Dopamine rootless
(build đủ 3 scheme: rootless, rootful, roothide).

## Tính năng

- **Theo lịch tháng:** tháng có bao nhiêu ngày thì chọn bấy nhiêu ảnh (tháng 2 năm nhuận
  29 ảnh, tháng thường 28/30/31 ảnh). Ngày mấy hiện ảnh ô ấy. Qua tháng mới quay lại ô 1.
- **Theo khoảng thời gian tự đặt:** số + đơn vị Phút / Giờ / Ngày / Tháng
  (vd 30 phút, 24 giờ, 48 giờ, 2 ngày, 1 tháng). Thứ tự Lần lượt hoặc Ngẫu nhiên.
- **Tắt:** chỉ dùng 1 nền cố định, chỉ đổi khi bấm "Đổi nền ngay bây giờ".
- **Nơi đổi:** chỉ màn hình khoá / chỉ màn hình chính / cả hai (Both). Giờ bắt đầu ngày
  cho chế độ lịch tháng.
- **Nguồn nền 3 kiểu:** Ảnh đã chọn / **Màu trơn** (bảng 12 màu + màu tự nhập #RRGGBB,
  có tự đổi màu theo lịch/khoảng) / **Màu chuyển gradient** (5 bộ màu) — khi không muốn
  để hình nữa. Nút áp màu thử ngay; chế độ màu trơn còn thử thêm đường màu native của
  chính hệ thống.
- **Hiệu ứng ảnh:** phủ tối 0–40% cho dễ đọc chữ/icon, làm mờ 4 mức, chặn đổi nền khi
  pin yếu dưới 20% và không sạc.
- **Ngôn ngữ:** Tiếng Việt có dấu mặc định, có lựa chọn English trong Cài đặt.
- **Quản lý ảnh ngay trong Cài đặt:** chọn nhiều ảnh cùng lúc, lưới theo ô ngày, đổi
  từng ảnh, hoán đổi vị trí 2 ô (vd ô 5 <-> ô 29), xoá từng ô / xoá tất cả. Có thêm nút
  chọn bộ ảnh dự phòng ngay ở trang chính. Ảnh được copy và thu về 1170x2532 vào
  `/var/mobile/Library/DailyWallpaperPro/`.
- **Xuất / nhập file cài đặt:** xuất ra `Documents/DailyWallpaperPro-Settings.plist`
  (kèm nút chia sẻ), nhập lại từ file đó hoặc qua trình chọn file.
- **Xem nhật ký ngay trong Cài đặt** (mở / chia sẻ / xoá log), mục Trạng thái (nguồn +
  nơi đổi, số ảnh, lần đổi gần nhất), đặt lại mốc đổi, đặt lại toàn bộ cài đặt.

## Trạng thái bản 1.0.3 — CẦN TEST MÁY THẬT

Bằng chứng từ log máy thật của bản 1.0.1 (27/11/2026):

- Cả 4 đường đổi ảnh cũ đều **không tồn tại** trên iOS 16.3.1
  (`SBWallpaperController` không còn method `setWallpaperWithImage` nào).
- Dump thật cho thấy đường của iOS 16: `wallpaperConfigurationManager` +
  `SBFWallpaperConfiguration.wallpaperImage` + `updateWallpaperForLocations:withCompletion:`.
  Bản 1.0.3 đi đường này trước (E1), dump nay in **toàn bộ** method/property/ivar
  không lọc để vòng sau có đủ bằng chứng.
- Vụ "không chọn được hình" ở 1.0.1: log không có bất kỳ dòng lưu ảnh nào và code cũ
  có nhánh thất bại im lặng. Bản 1.0.3 ghi log **mọi bước** của picker (mở trang, trình
  picker, số kết quả, tải từng ảnh, lưu từng ô), báo lỗi bằng hộp thoại, trình picker
  trễ sau action sheet, và có đường tải dữ liệu thô dự phòng.

Log: `/var/mobile/Documents/DailyWallpaperPro.log` — có lỗi thì gửi file này để fix.

## Cách test cho ra log giá trị nhất

1. Cài .deb rootless, respring.
2. Vào Cài đặt > DailyWallpaper Pro: thử **chọn ảnh** trước (trang Quản lý danh sách
   ảnh hoặc nút dự phòng ở trang chính) — coi ảnh có vào ô không.
3. Bấm **Test engine** ở từng mục "Đổi ở đâu": Khoá / Chính / Both — coi có đổi sang
   ảnh đỏ DWP TEST không, để ý các dòng `engine E1:` trong log.
4. Chuyển Nguồn nền sang **Màu trơn**, bấm **Áp màu / gradient ngay** — coi nền có đổi
   màu không (đường này có thêm đường native `setWallpaperColor` của hệ thống).
5. Gửi `DailyWallpaperPro.log` kèm ghi chú bước nào được / bước nào không.

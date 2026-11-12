# PRM393 · Ba bài demo Flutter

| Bài | Dự án | Nội dung |
| --- | --- | --- |
| 01 · Lưu trữ cục bộ | [local_storage](local_storage) | `SharedPreferencesAsync`, file JSON với `dart:io`, SQLite |
| 02 · Xác thực JWT | [jwt_auth](jwt_auth) | Flutter + API Node.js, `flutter_secure_storage`, Bearer JWT, refresh token rotation |
| 03 · Unit testing | [unit_testing](unit_testing) | `LoginValidator`, kiểm thử email và mật khẩu bằng `flutter_test` |

## Chuẩn bị

Các app hướng tới Android. Dùng Flutter 3.47.2 (Dart 3.13.2), Android SDK và một Android Emulator. Bài JWT cần thêm Node.js 22 trở lên.

```bash
git clone https://github.com/Naams2k10fpt/prm393-flutter-demos.git
cd prm393-flutter-demos
flutter devices
```

Chạy từng nhóm lệnh từ thư mục gốc của repo, trừ khi có chỉ dẫn khác.

## 01 · Lưu trữ cục bộ

```bash
cd local_storage
flutter pub get
flutter run
```

1. Nhập tên, chọn **Lưu tên**, bật **Chế độ tối**. `SharedPreferencesAsync` lưu chuỗi, cờ boolean và số lần mở app.
2. Nhập họ tên và tuổi, chọn **Ghi JSON**. Đổi nội dung ô nhập rồi chọn **Đọc JSON** để thấy dữ liệu đã lưu được nạp lại. Dùng **Xóa file** để xóa hồ sơ.
3. Thêm công việc, đánh dấu hoàn thành và thử xóa một việc. SQLite lưu mỗi việc thành một dòng có `id`, `title` và `done`.
4. Đóng hẳn rồi mở lại app để xem tên, giao diện, hồ sơ và công việc được khôi phục. **Đặt lại tùy chọn** xóa các key của phần SharedPreferences.

## 02 · Xác thực JWT

Mở terminal thứ nhất để chạy API.

```bash
cd jwt_auth/backend
npm ci
npm start
```

Mở terminal thứ hai ở thư mục gốc để chạy Flutter trên Android Emulator.

```bash
cd jwt_auth
flutter pub get
flutter run
```

Emulator gọi `http://10.0.2.2:3000`. Với thiết bị Android kết nối USB, chạy `adb reverse tcp:3000 tcp:3000`, rồi chạy `flutter run --dart-define=API_URL=http://127.0.0.1:3000`. Các URL HTTP cục bộ này được cấu hình riêng trong bản debug.

1. Chọn **Tạo tài khoản**, đăng ký bằng họ tên, email và mật khẩu thử nghiệm có ít nhất 8 ký tự.
2. Đăng nhập để app nhận cặp token, lưu vào `flutter_secure_storage` và tải hồ sơ bằng header `Authorization: Bearer <accessToken>`.
3. Đóng hẳn rồi mở lại app để kiểm tra khôi phục phiên. Khi access token hết hạn, chọn **Tải lại hồ sơ**. App nhận `401`, lấy cặp token mới qua `/api/auth/refresh`, rồi gọi lại API hồ sơ một lần.
4. Chọn **Đăng xuất** để thu hồi refresh token hiện tại ở server và xóa phiên trên thiết bị.

Access token mặc định có hiệu lực 900 giây. Để demo nhanh bước làm mới token, đặt `ACCESS_TOKEN_TTL_SECONDS=15` trước khi chạy API, rồi đợi 16 giây sau khi đăng nhập.

```powershell
$env:ACCESS_TOKEN_TTL_SECONDS = '15'
npm start
```

Trên Bash, dùng `ACCESS_TOKEN_TTL_SECONDS=15 npm start`.

| Method | Endpoint | Kết quả khi thành công |
| --- | --- | --- |
| POST | `/api/auth/register` | `201` và tài khoản mới |
| POST | `/api/auth/login` | Access token, refresh token, thời hạn access token |
| GET | `/api/users/me` | Hồ sơ của người dùng đã xác thực |
| POST | `/api/auth/refresh` | Cặp token mới, refresh token cũ hết hiệu lực |
| POST | `/api/auth/logout` | `204` và thu hồi refresh token |

Backend demo chỉ lắng nghe trên loopback. Tài khoản, khóa ký và phiên nằm trong bộ nhớ, nên khởi động lại API sẽ đặt lại dữ liệu. Access token đã cấp tiếp tục có hiệu lực đến `exp` trong vòng đời của tiến trình. Dùng tài khoản thử nghiệm cho bài này.

## 03 · Unit testing

```bash
cd unit_testing
flutter pub get
flutter test
flutter test --plain-name "Password Validation"
flutter test --coverage
```

Xem `test/login_validator_test.dart` để theo dõi Arrange–Act–Assert, `setUp`, `group`, `test` và `expect`. Bộ test bao gồm email hợp lệ, email sai định dạng, mật khẩu rỗng và ranh giới 7/8 ký tự. Coverage được ghi vào `coverage/lcov.info`.

Chạy `flutter run` nếu muốn nhập dữ liệu và xem cùng `LoginValidator` hoạt động trên form.

## Kiểm tra các bài demo

- Trong từng dự án Flutter, chạy `flutter analyze` và `flutter test`.
- Trong `jwt_auth/backend`, chạy `npm test` để kiểm tra đăng ký, đăng nhập, hồ sơ được bảo vệ, hết hạn, refresh và thu hồi refresh token.

## Tài liệu bài học

- Bài 01 dựa trên `PRM393-24-9.docx` và `Local-Storage-and-Persistence-in-Flutter.pptx`.
- Bài 02 dựa trên `PRM393-29-9.docx` và `Flutter-Authentication-with-JWT.pptx`.
- Bài 03 dựa trên `PRM393-1-10.docx` và `Flutter-Unit-Testing.pptx`.

Tham khảo [SharedPreferencesAsync](https://pub.dev/packages/shared_preferences), [Flutter networking](https://docs.flutter.dev/data-and-backend/networking) và [node-jsonwebtoken](https://github.com/auth0/node-jsonwebtoken).

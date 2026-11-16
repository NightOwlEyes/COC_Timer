# Hướng dẫn dùng ADB điều khiển CocTimer

Tài liệu này hướng dẫn cách gửi dữ liệu JSON làng Clash of Clans vào **CocTimer** thông qua **ADB** và nhận lại kết quả JSON chi tiết về thời gian hoàn thành công trình, nghiên cứu phòng thí nghiệm và linh thú.

Tính năng này hoạt động **cả khi ứng dụng đang mở** (tự làm mới giao diện ngay lập tức) **lẫn khi ứng dụng đã đóng** (chạy ngầm qua headless `FlutterEngine`).

---

## 1. Thông số chung

- **Package ID**: `coctimer.nightowleyes.coctimer`
- **BroadcastReceiver**: `coctimer.nightowleyes.coctimer/.AiCommandReceiver`
- **Activity (tùy chọn khi muốn mở app)**: `coctimer.nightowleyes.coctimer/.MainActivity`
- **Logcat Tag**: `COCTIMER_AI`
- **File kết quả mặc định**: `/sdcard/Android/data/coctimer.nightowleyes.coctimer/files/coctimer_result.json`
- **Timeout xử lý**: `8.5 giây` (`8500ms`)

---

## 2. Danh sách Actions & Tham số (Extras)

### Actions hỗ trợ
| Action | Chức năng |
| :--- | :--- |
| `coctimer.ACTION_IMPORT_JSON` | Nạp/cập nhật dữ liệu JSON của làng và trả về danh sách thời gian nâng cấp hoàn thành. |
| `coctimer.ACTION_QUERY_UPGRADES` | Truy vấn lại thời gian hoàn thành từ dữ liệu đã lưu trong máy (không cần gửi lại JSON). |

### Extras hỗ trợ
| Flag ADB | Kiểu | Mô tả |
| :--- | :--- | :--- |
| `--es file` / `--es json_file` | String | Đường dẫn file chứa JSON làng. Nếu truyền đường dẫn tương đối (ví dụ `village.json`), app tự đọc trong `/sdcard/Android/data/coctimer.nightowleyes.coctimer/files/`. |
| `--es base64` | String | Chuỗi JSON đã mã hóa Base64 UTF-8 (tránh lỗi escape ký tự đặc biệt trên shell). |
| `--es json` | String | Chuỗi JSON thô trực tiếp (chỉ phù hợp khi JSON ngắn). |
| `--es name` | String | Tên làng tùy chọn (nếu là làng mới và máy không có mạng, app sẽ dùng tên này thay vì fallback sang Player Tag; với làng đã có, sẽ cập nhật tên mới). |
| `--ez sync_alarms` | Boolean | Mặc định `true` (tự tạo/cập nhật báo thức và thông báo nhắc nhở). Truyền `false` nếu AI agent chỉ muốn tính thời gian nâng cấp mà không đặt báo thức lên máy. |
| `--es tag` | String | Dùng cho `ACTION_QUERY_UPGRADES` để lọc riêng một làng theo tag (ví dụ `#YPVR2CP8C`). |
| `--es output` / `--es output_file` | String | Đường dẫn lưu thêm một bản sao file kết quả JSON (tương đối theo thư mục `files` của app hoặc đường dẫn tuyệt đối mà app có quyền ghi). |

> **Lưu ý ưu tiên đầu vào của `ACTION_IMPORT_JSON`:** `json` -> `base64` -> `file` (`json_file`).

---

## 3. Các lệnh ADB thường dùng

### Cách 1: Gửi qua File (Khuyên dùng cho JSON làng đầy đủ)
Dữ liệu JSON xuất từ Clash of Clans thường dài hàng chục KB, vượt giới hạn độ dài dòng lệnh shell nên đẩy file vào thư mục ngoài của app là ổn định nhất (Android 11+ không cần cấp thêm quyền bộ nhớ cho thư mục `Android/data/<package>/files`).

```bash
# Bước 1: Đẩy file JSON từ máy tính vào thư mục files của app
adb push village.json /sdcard/Android/data/coctimer.nightowleyes.coctimer/files/village.json

# Bước 2: Gửi lệnh import và chờ kết quả trả về ngay trên terminal
adb shell am broadcast -n coctimer.nightowleyes.coctimer/.AiCommandReceiver -a coctimer.ACTION_IMPORT_JSON --es file village.json
```

**Biến thể thực tế:**
```bash
# Đặt tên làng sẵn và KHÔNG tạo báo thức trên điện thoại
adb shell am broadcast -n coctimer.nightowleyes.coctimer/.AiCommandReceiver -a coctimer.ACTION_IMPORT_JSON --es file village.json --es name "MainAcc" --ez sync_alarms false
```

---

### Cách 2: Gửi qua Base64 (Không cần `adb push`)

**Trên Linux / macOS / Git Bash:**
```bash
B64=$(base64 -w 0 village.json)
adb shell am broadcast -n coctimer.nightowleyes.coctimer/.AiCommandReceiver -a coctimer.ACTION_IMPORT_JSON --es base64 "$B64"
```

**Trên Windows PowerShell:**
```powershell
$bytes = [System.IO.File]::ReadAllBytes("village.json")
$b64 = [Convert]::ToBase64String($bytes)
adb shell am broadcast -n coctimer.nightowleyes.coctimer/.AiCommandReceiver -a coctimer.ACTION_IMPORT_JSON --es base64 $b64
```

> Lưu ý: Nếu chuỗi Base64 quá dài vượt giới hạn argument của `adb shell` trên một số thiết bị, hãy chuyển sang **Cách 1 (gửi qua file)**.

---

### Cách 3: Mở giao diện App kèm lệnh (`am start`)
Khi muốn mở app lên màn hình đồng thời nạp JSON:

```bash
adb shell am start -n coctimer.nightowleyes.coctimer/.MainActivity -a coctimer.ACTION_IMPORT_JSON --es file village.json
```

*(Lưu ý: `am start` không in JSON ra STDOUT như `am broadcast`, hãy đọc kết quả qua file `coctimer_result.json` hoặc Logcat `COCTIMER_AI`.)*

---

### Cách 4: Truy vấn lại danh sách nâng cấp (không cần gửi lại JSON)

```bash
# Lấy toàn bộ các làng đang lưu
adb shell am broadcast -n coctimer.nightowleyes.coctimer/.AiCommandReceiver -a coctimer.ACTION_QUERY_UPGRADES

# Chỉ lấy 1 làng theo Player Tag
adb shell am broadcast -n coctimer.nightowleyes.coctimer/.AiCommandReceiver -a coctimer.ACTION_QUERY_UPGRADES --es tag "#YPVR2CP8C"
```

---

## 4. Cách nhận kết quả trả về

Mỗi khi lệnh hoàn tất, CocTimer xuất kết quả ra **3 nơi cùng lúc** để AI agent dễ lấy theo kịch bản phù hợp:

### Kênh 1: Trực tiếp từ STDOUT của `am broadcast`
Output từ `adb shell am broadcast` có dạng:
```text
Broadcasting: Intent { act=coctimer.ACTION_IMPORT_JSON flg=0x400000 cmp=coctimer.nightowleyes.coctimer/.AiCommandReceiver (has extras) }
Broadcast completed: result=-1, data="{\"success\":true,\"action\":\"import_json\",...}"
```
Phần JSON nằm trong `data="..."`.

### Kênh 2: Đọc từ file kết quả trên thiết bị
```bash
adb shell cat /sdcard/Android/data/coctimer.nightowleyes.coctimer/files/coctimer_result.json
```
*(hoặc tải về máy bằng `adb pull /sdcard/Android/data/coctimer.nightowleyes.coctimer/files/coctimer_result.json`)*

### Kênh 3: Đọc từ Android Logcat
```bash
adb logcat -d -s COCTIMER_AI:I
```

---

## 5. Cấu trúc JSON kết quả

### Khi thành công (`import_json`)
Các nâng cấp trong mảng `upgrades` luôn được **sắp xếp tăng dần theo thời gian xong sớm nhất (`finish_timestamp`)**. Công trình xong sớm nhất được đưa lên trường `next_completion`.

```json
{
  "success": true,
  "action": "import_json",
  "is_new_village": false,
  "status_message": "Đã cập nhật: #YPVR2CP8C",
  "queried_at_local": "2026-11-14 01:20:00",
  "queried_at_iso": "2026-11-13T18:20:00.000Z",
  "queried_timestamp": 1794594000,
  "villages_count": 1,
  "tag": "#YPVR2CP8C",
  "name": "hien",
  "data_timestamp": 1794593800,
  "track_home": true,
  "track_builder": true,
  "summary": {
    "home": {
      "builders": "6/6",
      "builders_busy": 6,
      "builders_total": 6,
      "builders_idle": 0,
      "lab": "1/1",
      "lab_busy": 1,
      "lab_total": 1,
      "lab_idle": 0,
      "pets": "1/1",
      "pets_busy": 1,
      "pets_total": 1,
      "pets_idle": 0
    },
    "builder_base": {
      "builders": "2/2",
      "builders_busy": 2,
      "builders_total": 2,
      "builders_idle": 0,
      "lab": "1/1",
      "lab_busy": 1,
      "lab_total": 1,
      "lab_idle": 0
    }
  },
  "boosts_remaining_seconds": {
    "builder_potion": 0,
    "lab_potion": 0,
    "pet_potion": 0,
    "builder_bite": 0,
    "study_soup": 0,
    "clocktower": 0,
    "builder_apprentice": 0,
    "lab_assistant": 0
  },
  "next_completion": {
    "base": "home",
    "category": "builder",
    "data_id": 1000021,
    "name": "X-Bow",
    "name_en": "X-Bow",
    "level": 11,
    "is_extra": false,
    "finish_at_local": "2026-11-14 08:45:12",
    "finish_at_iso": "2026-11-14T01:45:12.000Z",
    "finish_timestamp": 1794620712,
    "remaining_seconds": 26712,
    "remaining_formatted": "7h 25m",
    "alarm_type": "system"
  },
  "upgrades": [
    {
      "base": "home",
      "category": "builder",
      "data_id": 1000021,
      "name": "X-Bow",
      "name_en": "X-Bow",
      "level": 11,
      "is_extra": false,
      "finish_at_local": "2026-11-14 08:45:12",
      "finish_at_iso": "2026-11-14T01:45:12.000Z",
      "finish_timestamp": 1794620712,
      "remaining_seconds": 26712,
      "remaining_formatted": "7h 25m",
      "alarm_type": "system"
    }
  ],
  "result_file": "/storage/emulated/0/Android/data/coctimer.nightowleyes.coctimer/files/coctimer_result.json"
}
```

### Khi dùng `ACTION_QUERY_UPGRADES`
Cấu trúc trả về bọc danh sách các làng trong mảng `villages`:
```json
{
  "success": true,
  "action": "query_upgrades",
  "queried_at_local": "2026-11-14 01:20:00",
  "queried_at_iso": "2026-11-13T18:20:00.000Z",
  "queried_timestamp": 1794594000,
  "villages_count": 1,
  "villages": [
    { "...cấu trúc báo cáo từng làng giống ở trên..." }
  ],
  "result_file": "/storage/emulated/0/Android/data/coctimer.nightowleyes.coctimer/files/coctimer_result.json"
}
```

### Khi có lỗi
```json
{
  "success": false,
  "action": "import_json",
  "error": "Missing input. Provide --es file, --es base64, or --es json.",
  "result_file": "/storage/emulated/0/Android/data/coctimer.nightowleyes.coctimer/files/coctimer_result.json"
}
```

---

## 6. Mẹo & Khắc phục sự cố

1. **Luôn truyền `-n coctimer.nightowleyes.coctimer/.AiCommandReceiver`:** Android 8+ chặn implicit broadcast không chỉ định component đích. Luôn chỉ định rõ `-n coctimer.nightowleyes.coctimer/.AiCommandReceiver`.
2. **File ở `/data/local/tmp/` có thể bị SELinux chặn:** App Android thông thường không đọc được file trong `/data/local/tmp/`. Hãy `adb push` vào `/sdcard/Android/data/coctimer.nightowleyes.coctimer/files/` rồi truyền tên file (`--es file village.json`).
3. **Khai báo `--es name` nếu thiết bị offline hoặc muốn nhanh:** Với làng mới hoàn toàn, app gọi API lấy tên người chơi (timeout tối đa `2.5s`). Nếu truyền sẵn `--es name "TenLang"`, app lưu ngay không phải chờ mạng.
4. **Dấu `#` trong Tag khi dùng Linux/macOS bash:** Khi lọc bằng `--es tag`, hãy bọc trong dấu ngoặc kép `"#YPVR2CP8C"` để shell không hiểu nhầm dấu `#` là comment.

import 'package:shared_preferences/shared_preferences.dart';

class AppStrings {
  static String languageCode = 'vi';

  static Future<void> initLanguage() async {
    final prefs = await SharedPreferences.getInstance();
    languageCode = prefs.getString('app_language') ?? 'vi';
  }

  static Future<void> changeLanguage(String code) async {
    languageCode = code;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('app_language', code);
  }

  /// Hàm hỗ trợ thay thế các biến động trong chuỗi.
  static String format(String text, Map<String, String> values) {
    String result = text;
    values.forEach((key, value) {
      result = result.replaceAll('{$key}', value);
    });
    return result;
  }

  // SỬ DỤNG GETTER ĐỂ TỰ ĐỘNG CHUYỂN NGÔN NGỮ MÀ KHÔNG LÀM LỖI CODE CŨ CỦA BẠN
  static TerminalScreenStrings get terminal => languageCode == 'vi' ? const TerminalScreenStringsVi() : const TerminalScreenStringsEn();
  static ScheduleServiceStrings get schedule => languageCode == 'vi' ? const ScheduleServiceStringsVi() : const ScheduleServiceStringsEn();
  static AlarmPopupStrings get alarm => languageCode == 'vi' ? const AlarmPopupStringsVi() : const AlarmPopupStringsEn();
  static VillageCardStrings get card => languageCode == 'vi' ? const VillageCardStringsVi() : const VillageCardStringsEn();
  static MainStrings get mainApp => languageCode == 'vi' ? const MainStringsVi() : const MainStringsEn();
  static VillageDetailDialogStrings get dialog => languageCode == 'vi' ? const VillageDetailDialogStringsVi() : const VillageDetailDialogStringsEn();
  static GameData get gameData => languageCode == 'vi' ? const GameDataVi() : const GameDataEn();
}

// ==========================================
// CÁC LỚP TRỪU TƯỢNG (INTERFACE CHUNG)
// ==========================================
abstract class TerminalScreenStrings {
  const TerminalScreenStrings();
  String get headerSmallTitle;
  String get labelRealTime;
  String get toggleOn;
  String get toggleOff;
  String get labelServer;
  String get labelTapToSwitchServer;
  String get tabBuilderBase;
  String get tabMainVillage;
  String get logoTitle;
  String get logoSubtitle;
  String get inputSectionLabel;
  String get inputHint;
  String get btnPaste;
  String get btnSubmit;
  String get btnXiaomiPermission;
  String get footerHowtoTitle;
  String get footerHowtoDesc;
  String get statusWaitingJson;
  String get statusLoadedSavedData;
  String get statusVillageDeleted;
  String get statusAlarmSetFullscreen;
  String get statusAlarmOff;
  String get statusNotificationSetSystem;
  String get statusGroupAllOff;
  String get statusGroupModeChanged;
  String get statusUpdated;
  String get statusErrorInvalidJson;
  String get statusXiaomiPromptSuccess;
  String get statusXiaomiPromptError;
  String get defaultVillageNameFallback;
  String get defaultVillageNameUnset;
  String get deleteDialogTitle;
  String get deleteDialogMessage;
  String get btnCancel;
  String get btnDeleteNow;
  String get newVillageDialogTitle;
  String get newVillageDialogTagLabel;
  String get newVillageNameHint;
  String get btnSaveAndAddVillage;
  String get debugLoadAlarmStateError;
  String get debugParseVillageError;
  String get debugLoadNameError;
  String get debugLoadGeneralError;
}

abstract class ScheduleServiceStrings {
  const ScheduleServiceStrings();
  String get notificationTitle;
  String get notificationBody;
  String get alarmNotificationTitle;
  String get alarmNotificationBody;
  String get alarmStopButton;
  String get debugOldChannelDeleted;
  String get debugOldChannelDeleteFailed;
  String get debugFsiPermissionMissing;
  String get debugFsiPermissionCheckError;
  String get debugBatteryOptimizationActive;
  String get debugBatteryPermissionCheckError;
  String get debugAlarmDisabledLog;
  String get debugSystemNotificationScheduledLog;
  String get debugFullscreenAlarmScheduledLog;
  String get debugAlarmDismissError;
  String get debugScreenTimeoutError;
  String get debugEnableAlarmModeError;
  String get debugDisableAlarmModeError;
  String get welcomeNotificationTitle;
  String get welcomeNotificationBody;
}

abstract class AlarmPopupStrings {
  const AlarmPopupStrings();
  String get title;
  String get btnConfirmAndClose;
}

abstract class VillageCardStrings {
  const VillageCardStrings();
  String get unnamedVillage;
  String get btnDelete;
  String get labelVillageNamePrefix;
  String get labelTagPrefix;
  String get statMasterBuilder;
  String get statStarLaboratory;
  String get statBuilder;
  String get statLab;
  String get statPet;
}

abstract class MainStrings {
  const MainStrings();
  String get debugInitBackgroundSystemError;
}

abstract class VillageDetailDialogStrings {
  const VillageDetailDialogStrings();
  String get titlePrefix;
  String get btnClose;
  String get labelVillageName;
  String get hintEnterVillageName;
  String get groupBuilderNight;
  String get groupBuilder;
  String get statusWorkingSuffix;
  String get groupPet;
  String get statusUpgradingSuffix;
  String get groupLabNight;
  String get groupLabMain;
  String get separatorDots;
}

abstract class GameData {
  const GameData();
  String getName(int id);
}

// ==========================================
// BỘ TỪ ĐIỂN TIẾNG VIỆT
// ==========================================
class TerminalScreenStringsVi extends TerminalScreenStrings {
  const TerminalScreenStringsVi();
  @override String get headerSmallTitle => "COC.TIMER";
  @override String get labelRealTime => "NGÀY HOÀN TẤT";
  @override String get toggleOn => "[ BẬT ]";
  @override String get toggleOff => "[ TẮT ]";
  @override String get labelServer => "SERVER: LOCAL";
  @override String get labelTapToSwitchServer => "[ BẤM ĐỂ CHUYỂN ĐỔI LÀNG ]";
  @override String get tabBuilderBase => "■  L À N G   T H Ợ   X Â Y  ■";
  @override String get tabMainVillage => "■  L À N G   C H Í N H  ■";
  @override String get logoTitle => "C O C   T I M E R";
  @override String get logoSubtitle => "ĐẾM NGƯỢC THỜI GIAN NÂNG";
  @override String get inputSectionLabel => "D Ữ   L I Ệ U   L À N G";
  @override String get inputHint => "DÁN JSON VÀO ĐÂY...";
  @override String get btnPaste => "DÁN";
  @override String get btnSubmit => "X Á C   N H Ậ N   ►";
  @override String get btnXiaomiPermission => "[ CẤP QUYỀN TRÊN XIAOMI/POCO ]";
  @override String get footerHowtoTitle => "CHƯA BIẾT CÁCH XUẤT DỮ LIỆU LÀNG?";
  @override String get footerHowtoDesc => "CÀI ĐẶT GAME > THÊM CÀI ĐẶT > XUẤT DỮ LIỆU LÀNG THEO ĐỊNH DẠNG JSON";
  @override String get statusWaitingJson => "> CHỜ DỮ LIỆU JSON";
  @override String get statusLoadedSavedData => "> ĐÃ TẢI DỮ LIỆU LƯU TRỮ";
  @override String get statusVillageDeleted => "> ĐÃ XÓA LÀNG: {tag}";
  @override String get statusAlarmSetFullscreen => "> [BÁO THỨC] {typeString} {dataId}";
  @override String get statusAlarmOff => "> [ĐÃ TẮT] {typeString} {dataId}";
  @override String get statusNotificationSetSystem => "> [THÔNG BÁO] {typeString} {dataId}";
  @override String get statusGroupAllOff => "> ĐÃ TẮT TOÀN BỘ NHÓM: {groupName}";
  @override String get statusGroupModeChanged => "> ĐÃ ĐỔI NHÓM {groupName} SANG CHẾ ĐỘ {alarmType}";
  @override String get statusUpdated => "> ĐÃ CẬP NHẬT: {villageName} ({tag})";
  @override String get statusErrorInvalidJson => "> LỖI! HÃY KIỂM TRA LẠI JSON";
  @override String get statusXiaomiPromptSuccess => "> HÃY TÍCH XANH TẤT CẢ!";
  @override String get statusXiaomiPromptError => "> LỖI: CHỈ THIẾT BỊ XIAOMI/POCO";
  @override String get defaultVillageNameFallback => "<CHƯA ĐẶT TÊN>";
  @override String get defaultVillageNameUnset => "Chưa đặt tên";
  @override String get deleteDialogTitle => "XÁC NHẬN XÓA";
  @override String get deleteDialogMessage => "Bạn có chắc chắn muốn xóa dữ liệu JSON và báo thức của làng {tag} không?\n(Tên làng vẫn sẽ được ghi nhớ)";
  @override String get btnCancel => "HỦY";
  @override String get btnDeleteNow => "XÓA NGAY";
  @override String get newVillageDialogTitle => "PHÁT HIỆN LÀNG MỚI";
  @override String get newVillageDialogTagLabel => "Mã: {tag}";
  @override String get newVillageNameHint => "Nhập tên làng (VD: Acc Chính)...";
  @override String get btnSaveAndAddVillage => "LƯU & THÊM LÀNG";
  @override String get debugLoadAlarmStateError => "Lỗi load trạng thái báo thức: {e}";
  @override String get debugParseVillageError => "Lỗi parse {key}: {e}";
  @override String get debugLoadNameError => "Lỗi load tên làng: {e}";
  @override String get debugLoadGeneralError => "Lỗi load: {e}";
}

class ScheduleServiceStringsVi extends ScheduleServiceStrings {
  const ScheduleServiceStringsVi();
  @override String get notificationTitle => "■ HOÀN TẤT ■";
  @override String get notificationBody => "{itemName} tại {villageName} ({tag}) đã hoàn thành.";
  @override String get alarmNotificationTitle => "■ HOÀN TẤT ■";
  @override String get alarmNotificationBody => "Hạng mục: {itemName}\nLàng: {villageName}\n(Mã: {tag})";
  @override String get alarmStopButton => "ĐÓNG CẢNH BÁO";
  @override String get debugOldChannelDeleted => "Đã xóa dọn dẹp channel cũ: {channelId}";
  @override String get debugOldChannelDeleteFailed => "Không thể xóa channel {channelId}: {e}";
  @override String get debugFsiPermissionMissing => "Chưa có quyền Full Screen Intent, mở màn hình cài đặt...";
  @override String get debugFsiPermissionCheckError => "Lỗi kiểm tra FSI permission: {e}";
  @override String get debugBatteryOptimizationActive => "Đang bị tối ưu hóa pin, yêu cầu cấp quyền Bỏ qua...";
  @override String get debugBatteryPermissionCheckError => "Lỗi kiểm tra Battery permission: {e}";
  @override String get debugAlarmDisabledLog => "Đã tắt báo thức cho ID: {id} (Chuỗi gốc: {instanceId})";
  @override String get debugSystemNotificationScheduledLog => "Hẹn THÔNG BÁO HỆ THỐNG cho ID: {id} vào lúc {realEta}";
  @override String get debugFullscreenAlarmScheduledLog => "Hẹn BÁO THỨC TOÀN MÀN HÌNH cho ID: {id} vào lúc {realEta}";
  @override String get debugAlarmDismissError => "Lỗi handleAlarmDismiss: {e}";
  @override String get debugScreenTimeoutError => "Lỗi allowScreenTimeout: {e}";
  @override String get debugEnableAlarmModeError => "Lỗi enableAlarmMode: {e}";
  @override String get debugDisableAlarmModeError => "Lỗi disableAlarmMode: {e}";
  @override String get welcomeNotificationTitle => "THIẾT LẬP THÀNH CÔNG";
  @override String get welcomeNotificationBody => "Hệ thống thông báo đã sẵn sàng!";
}

class AlarmPopupStringsVi extends AlarmPopupStrings {
  const AlarmPopupStringsVi();
  @override String get title => "■ HOÀN TẤT ■";
  @override String get btnConfirmAndClose => "[ XÁC NHẬN ]";
}

class VillageCardStringsVi extends VillageCardStrings {
  const VillageCardStringsVi();
  @override String get unnamedVillage => "<CHƯA ĐẶT TÊN>";
  @override String get btnDelete => "[ XÓA ]";
  @override String get labelVillageNamePrefix => "Tên làng: ";
  @override String get labelTagPrefix => "Mã làng: ";
  @override String get statMasterBuilder => "THỢ XÂY BẬC THẦY";
  @override String get statStarLaboratory => "THÍ NGHIỆM SAO";
  @override String get statBuilder => "THỢ XÂY";
  @override String get statLab => "THÍ NGHIỆM";
  @override String get statPet => "LINH THÚ";
}

class MainStringsVi extends MainStrings {
  const MainStringsVi();
  @override String get debugInitBackgroundSystemError => "Lỗi khởi tạo hệ thống ngầm: {e}";
}

class VillageDetailDialogStringsVi extends VillageDetailDialogStrings {
  const VillageDetailDialogStringsVi();
  @override String get titlePrefix => "■ CHI TIẾT: ";
  @override String get btnClose => "[ ĐÓNG ]";
  @override String get labelVillageName => "TÊN LÀNG: ";
  @override String get hintEnterVillageName => "[ NHẬP TÊN LÀNG... ]";
  @override String get groupBuilderNight => "> THỢ XÂY";
  @override String get groupBuilder => "> LỀU THỢ XÂY";
  @override String get statusWorkingSuffix => "ĐANG NÂNG";
  @override String get groupPet => "> CHUỒNG LINH THÚ";
  @override String get statusUpgradingSuffix => "ĐANG NÂNG";
  @override String get groupLabNight => "> PHÒNG THÍ NGHIỆM SAO";
  @override String get groupLabMain => "> PHÒNG THÍ NGHIỆM";
  @override String get separatorDots => " ......................................";
}

class GameDataVi extends GameData {
  const GameDataVi();

  final Map<int, String> names = const {
    1000054: "Bom phòng không",
    1000012: "Tháp phòng không",
    1000028: "Tháp thổi khí",
    73000011: "Sứa dữ tơn",
    26000123: "Thần chú giận dữ",
    4000097: "Quản giáo tập sự",
    28000001: "Nữ hoảng cung thủ",
    1000048: "Tháp cung thủ",
    4000001: "Cung thủ",
    1000000: "Doanh trại quân đội",
    1000042: "Doanh trại quân đội",
    4000041: "Tiểu long",
    4000005: "Khinh khí cầu",
    28000000: "Man di vương",
    4000000: "Man di",
    1000006: "Trại lính",
    26000028: "Thần chú dơi",
    4000052: "Khí cầu chiến",
    1000080: "Bệ trực thăng chiến đấu",
    28000005: "Trực thăng chiến đấu",
    4000092: "Máy khoan chiến tranh",
    1000053: "Bệ cỗ máy chiến đấu",
    28000003: "Cỗ máy chiến đấu",
    4000033: "Minion Beta",
    1000070: "Lò rèn",
    1000065: "Trạm điều khiển B.O.B",
    1000064: "Lều B.O.B",
    1000032: "Tháp bom",
    12000000: "Bom",
    4000035: "Bom thủ",
    1000047: "Lều của B.O.T.O",
    4000022: "Thạch thủ",
    4000034: "Võ sĩ khổng nhân",
    1000040: "Trại lính thợ xây",
    1000034: "Hội trường thợ xây",
    93000000: "Thợ xây học việc",
    1000015: "Lều thợ xây",
    103000013: "Máy ném bánh",
    102000039: "Máy ném bánh - HP",
    102000040: "Máy ném bánh - DPH",
    102000041: "Máy ném bánh - ED",
    4000037: "Xe đại bác",
    1000044: "Đại bác",
    1000014: "Hội thành",
    1000039: "Tháp đồng hồ",
    26000016: "Thần chú nhân bản",
    1000097: "Phòng thủ tự chế",
    1000055: "Máy đập",
    1000026: "Trại lính hắc ám",
    1000023: "Dàn khoan hắc tiên dược",
    1000024: "Kho chứa hắc tiên dược",
    1000029: "Nhà máy hắc thần chú",
    73000008: "Tê tê độn thổ",
    1000041: "Đại bác nòng kép",
    28000007: "Công tước rồng",
    4000065: "Kỵ sĩ rồng",
    4000008: "Rồng",
    4000038: "Tàu thả xuống",
    4000123: "Thuật sĩ",
    1000031: "Pháo đại bàng",
    26000010: "Thần chú động đất",
    4000059: "Rồng điện",
    73000002: "Cú điện",
    4000095: "Chiến binh phóng điện",
    4000106: "Pháp sư lửa điện",
    1000035: "Máy hút tiên dược",
    1000036: "Kho chứa tiên dược",
    1000050: "Pháo hoa",
    1000089: "Súng phun lửa",
    4000091: "Xe phóng lửa",
    26000005: "Thần chú đóng băng",
    73000009: "Voi biển băng giá",
    4000150: "Lò lửa",
    1000058: "Mỏ ngọc",
    12000002: "Bom khổng lồ",
    1000057: "Đại bác khổng lồ",
    4000003: "Khổng nhân",
    12000020: "Bom siêu khủng",
    4000002: "Yêu tinh",
    1000037: "Mỏ vàng",
    1000038: "Kho chứa vàng",
    4000013: "Thạch nhân",
    28000002: "Đại quản giáo",
    73000017: "Quạ tham lam",
    1000051: "Vọng gác",
    26000011: "Thần chú tăng tốc",
    4000082: "Thợ săn tướng",
    4000007: "Thầy thuốc",
    1000082: "Lều hồi máu",
    26000001: "Thần chú hồi máu",
    1000093: "Lều người hỗ trợ",
    1000071: "Hội trường tướng",
    103000012: "Tháp săn tướng",
    102000036: "Tháp săn tướng - HP",
    102000037: "Tháp săn tướng - DPS",
    102000038: "Tháp săn tướng - PSL",
    1000043: "Tháp hồ quang điện ẩn",
    4000070: "Trư bay lượn",
    4000011: "Trư kỵ sĩ",
    103000011: "Cây nến rực lửa",
    103000033: "Cây nến rực lửa - HP",
    102000034: "Cây nến rực lửa - DPS",
    102000035: "Cây nến rực lửa - TSA",
    26000109: "Thần chú khiên chắn băng",
    4000058: "Băng thạch nhân",
    1000027: "Tháp hoả ngục",
    26000035: "Thần chú tàng hình",
    26000003: "Thần chú bật nhảy",
    93000001: "Phụ tá phòng thí nghiệm",
    1000007: "Phòng thí nghiệm",
    73000000: "L.A.S.S.I",
    4000017: "Nham khuyển",
    1000063: "Máy phóng dung nham",
    26000000: "Thần chú sấm sét",
    107000008: "Tiều phu",
    4000087: "Máy phóng khúc gỗ",
    107000000: "Xạ thủ tầm xa",
    12000014: "Mìn siêu cấp",
    1000052: "Tháp hồ quang điện siêu cấp",
    4000177: "Thạch nhân thiên thạch",
    73000001: "Bò Tây Tạng dũng mãnh",
    12000013: "Mìn",
    4000024: "Thợ mỏ",
    28000006: "Hoàng tử Minion",
    4000010: "Minion",
    1000077: "Pháo đài đá",
    1000013: "Súng cối",
    1000084: "Tháp nhiều cung thủ",
    1000079: "Tháp đa năng",
    1000045: "Súng cối đa nòng",
    4000042: "Phù thuỷ bóng đêm",
    1000078: "Điền đồn O.T.T.O",
    26000070: "Thần chú siêu tăng trưởng",
    4000009: "P.E.K.K.A",
    1000068: "Chuồng linh thú",
    73000004: "Phượng hoàng lửa",
    73000007: "Thằn lằn phun độc",
    26000009: "Thần chú độc dược",
    4000036: "P.E.K.K.A dũng mãnh",
    93000002: "Người tìm mỏ",
    12000011: "Bẫy đẩy",
    26000002: "Thần chú thịnh nộ",
    4000031: "Man di cuồng nộ",
    26000053: "Thần chú thu quân",
    1000049: "Trại quân tiếp viện",
    1000086: "Tháp phục thù",
    26000098: "Thần chú hồi sinh",
    1000085: "Đại bác bật nẩy",
    1000056: "Lò nung",
    4000110: "Kỵ sĩ rễ cây",
    28000004: "Nữ tướng hoàng gia",
    4000109: "Phù thuỷ tàn tích",
    1000067: "Máy bắn đá",
    12000006: "Mìn bay tầm diệt",
    4000075: "Trại lính bay",
    4000188: "Cỗ xe bay",
    26000017: "Thần chú bộ xương",
    12000008: "Bẫy bộ xương",
    107000001: "Kẻ huỷ diệt",
    4000032: "Cung thủ lén lút",
    73000016: "Dơi hắt xì",
    1000020: "Nh máy thần chú",
    1000072: "Tháp thần chú",
    73000010: "Cáo linh hồn",
    12000010: "Bẫy bật",
    1000046: "Phòng thí nghiệm sao",
    4000062: "Máy bay thả đá",
    1000102: "Tháp siêu pháp sư",
    4000132: "Cao thủ ném lao",
    12000016: "Bẫy lốc xoáy",
    26000120: "Thần chú vật tổ",
    1000001: "Nhà chính",
    4000135: "Máy phóng binh lính",
    73000003: "Ngựa một sừng",
    4000012: "Valkyrie",
    4000004: "Công thành binh",
    4000051: "Xe phá thành",
    1000033: "Tường thành",
    4000015: "Phù thuỷ",
    1000011: "Tháp pháp sư",
    4000006: "Pháp sư",
    1000059: "Xưởng chế tạo",
    1000081: "Tháp cung",
    1000021: "Tháp cung",
    4000053: "Người tuyết Yeti"
  };

  @override
  String getName(int id) => names[id] ?? "t.me/nightowleyes ($id)";
}

// ==========================================
// BỘ TỪ ĐIỂN TIẾNG ANH
// ==========================================
class TerminalScreenStringsEn extends TerminalScreenStrings {
  const TerminalScreenStringsEn();
  @override String get headerSmallTitle => "COC.TIMER";
  @override String get labelRealTime => "DATE OF COMPLETION";
  @override String get toggleOn => "[ ON ]";
  @override String get toggleOff => "[ OFF ]";
  @override String get labelServer => "SERVER: LOCAL";
  @override String get labelTapToSwitchServer => "[CLICK TO SWITCH VILLAGE]";
  @override String get tabBuilderBase => "■ B U I L D E R  V I L L A G E ■";
  @override String get tabMainVillage => "■  H O M E   V I L L A G E  ■";
  @override String get logoTitle => "C O C   T I M E R";
  @override String get logoSubtitle => "COUNTDOWN TO THE UPGRADE";
  @override String get inputSectionLabel => "V I L L A G E    D A T A";
  @override String get inputHint => "PASTE JSON HERE...";
  @override String get btnPaste => "PASTE";
  @override String get btnSubmit => "C O N F I R M   ►";
  @override String get btnXiaomiPermission => "[ GRANT PERMISSION ON XIAOMI/POCO ]";
  @override String get footerHowtoTitle => "DON'T KNOW HOW TO EXPORT VILLAGE DATA YET?";
  @override String get footerHowtoDesc => "GAME SETTINGS > MORE SETTINGS > EXPORT VILLAGE DATA IN JSON FORMAT";
  @override String get statusWaitingJson => "> WAITING FOR JSON DATA";
  @override String get statusLoadedSavedData => "> ARCHIVED DATA";
  @override String get statusVillageDeleted => "> VILLAGE DELETED: {tag}";
  @override String get statusAlarmSetFullscreen => "> [ALARM] {typeString} {dataId}";
  @override String get statusAlarmOff => "> [DISABLED] {typeString} {dataId}";
  @override String get statusNotificationSetSystem => "> [NOTIFICATION] {typeString} {dataId}";
  @override String get statusGroupAllOff => "> ALL GROUPS TURNED OFF: {groupName}";
  @override String get statusGroupModeChanged => "> CHANGED GROUP {groupName} TO MODE {alarmType}";
  @override String get statusUpdated => "> UPDATED: {villageName} ({tag})";
  @override String get statusErrorInvalidJson => "> ERROR! PLEASE CHECK YOUR JSON AGAIN";
  @override String get statusXiaomiPromptSuccess => "> ENABLE EVERYTHING!";
  @override String get statusXiaomiPromptError => "> ERROR: XIAOMI/POCO DEVICES ONLY";
  @override String get defaultVillageNameFallback => "<UNNAMED>";
  @override String get defaultVillageNameUnset => "Unnamed";
  @override String get deleteDialogTitle => "CONFIRM DELETION";
  @override String get deleteDialogMessage => "Are you sure you want to delete the JSON data and alarms for village {tag}?\n(The village name will still be remembered)";
  @override String get btnCancel => "CANCEL";
  @override String get btnDeleteNow => "DELETE";
  @override String get newVillageDialogTitle => "NEW VILLAGE DETECTED";
  @override String get newVillageDialogTagLabel => "Tag: {tag}";
  @override String get newVillageNameHint => "Enter village name (e.g., Main Acc)...";
  @override String get btnSaveAndAddVillage => "SAVE and ADD VILLAGE";
  @override String get debugLoadAlarmStateError => "Error loading alarm state: {e}";
  @override String get debugParseVillageError => "Parse error {key}: {e}";
  @override String get debugLoadNameError => "Error loading village name: {e}";
  @override String get debugLoadGeneralError => "Load error: {e}";
}

class ScheduleServiceStringsEn extends ScheduleServiceStrings {
  const ScheduleServiceStringsEn();
  @override String get notificationTitle => "■ COMPLETED ■";
  @override String get notificationBody => "{itemName} at {villageName} ({tag}) has been completed.";
  @override String get alarmNotificationTitle => "■ COMPLETED ■";
  @override String get alarmNotificationBody => "Category: {itemName}\nVillage: {villageName}\n(Code: {tag})";
  @override String get alarmStopButton => "CLOSE WARNING";
  @override String get debugOldChannelDeleted => "Cleaned up old channel: {channelId}";
  @override String get debugOldChannelDeleteFailed => "Cannot delete channel {channelId}: {e}";
  @override String get debugFsiPermissionMissing => "Full Screen Intent permission not granted; opening settings screen...";
  @override String get debugFsiPermissionCheckError => "FSI permission check error: {e}";
  @override String get debugBatteryOptimizationActive => "Battery optimization is enabled. Please grant the Ignore Battery Optimization permission.";
  @override String get debugBatteryPermissionCheckError => "Battery permission check error: {e}";
  @override String get debugAlarmDisabledLog => "Alarm disabled for ID: {id} (Original string: {instanceId})";
  @override String get debugSystemNotificationScheduledLog => "Schedule SYSTEM NOTIFICATION for ID: {id} at {realEta}";
  @override String get debugFullscreenAlarmScheduledLog => "Full-screen alarm scheduled for ID: {id} at {realEta}";
  @override String get debugAlarmDismissError => "handleAlarmDismiss error: {e}";
  @override String get debugScreenTimeoutError => "Error allowScreenTimeout: {e}";
  @override String get debugEnableAlarmModeError => "enableAlarmMode error: {e}";
  @override String get debugDisableAlarmModeError => "Error disableAlarmMode: {e}";
  @override String get welcomeNotificationTitle => "SETUP COMPLETED";
  @override String get welcomeNotificationBody => "The notification is ready!";
}

class AlarmPopupStringsEn extends AlarmPopupStrings {
  const AlarmPopupStringsEn();
  @override String get title => "■ COMPLETED ■";
  @override String get btnConfirmAndClose => "[ CONFIRM ]";
}

class VillageCardStringsEn extends VillageCardStrings {
  const VillageCardStringsEn();
  @override String get unnamedVillage => "<UNNAMED>";
  @override String get btnDelete => "[ DEL ]";
  @override String get labelVillageNamePrefix => "Village name: ";
  @override String get labelTagPrefix => "Village tag: ";
  @override String get statMasterBuilder => "MASTER BUILDER";
  @override String get statStarLaboratory => "STAR LAB";
  @override String get statBuilder => "BUILDER";
  @override String get statLab => "LAB";
  @override String get statPet => "PET";
}

class MainStringsEn extends MainStrings {
  const MainStringsEn();
  @override String get debugInitBackgroundSystemError => "Failed to initialize background services: {e}";
}

class VillageDetailDialogStringsEn extends VillageDetailDialogStrings {
  const VillageDetailDialogStringsEn();
  @override String get titlePrefix => "■ DETAILS: ";
  @override String get btnClose => "[ CLOSE ]";
  @override String get labelVillageName => "VILLAGE NAME: ";
  @override String get hintEnterVillageName => "[ ENTER VILLAGE NAME... ]";
  @override String get groupBuilderNight => "> BUILDER";
  @override String get groupBuilder => "> BUILDER's HUT";
  @override String get statusWorkingSuffix => "UPGRADING";
  @override String get groupPet => "PET HOUSE";
  @override String get statusUpgradingSuffix => "UPGRADING";
  @override String get groupLabNight => "> STAR LABORATORY";
  @override String get groupLabMain => "> LABORATORY";
  @override String get separatorDots => " ......................................";
}

class GameDataEn extends GameData {
  const GameDataEn();

  final Map<int, String> names = const {
    1000054: "Air Bombs",
    1000012: "Air Defense",
    1000028: "Air Sweeper",
    73000011: "Angry Jelly",
    26000123: "Angry Spell",
    4000097: "Apprentice Warden",
    28000001: "Archer Queen",
    1000048: "Archer Tower",
    4000001: "Archer",
    1000000: "Army Camp",
    1000042: "Army Camp",
    4000041: "Baby Dragon",
    4000005: "Balloon",
    28000000: "Barbarian King",
    4000000: "Barbarian",
    1000006: "Barracks",
    26000028: "Bat Spell",
    4000052: "Battle Blimp",
    1000080: "Battle Copter Altar",
    28000005: "Battle Copter",
    4000092: "Battle Drill",
    1000053: "Battle Machine Altar",
    28000003: "Battle Machine",
    4000033: "Beta Minion",
    1000070: "Blacksmith",
    1000065: "B.O.B Control",
    1000064: "B.O.B's Hut",
    1000032: "Bomb Tower",
    12000000: "Bomb",
    4000035: "Bomber",
    1000047: "B.O.T.O's Shack",
    4000022: "Bowler",
    4000034: "Boxer Giant",
    1000040: "Builder Barracks",
    1000034: "Builder Hall",
    93000000: "Builder's Apprentice",
    1000015: "Builder's Hut",
    103000013: "Cake-A-Pult",
    102000039: "Cake-A-Pult Hitpoints",
    102000040: "Cake-A-Pult DPH",
    102000041: "Cake-A-Pult ED",
    4000037: "Cannon Cart",
    1000044: "Cannon",
    1000014: "Clan Castle",
    1000039: "Clock Tower",
    26000016: "Clone Spell",
    1000097: "Crafting Station",
    1000055: "Crusher",
    1000026: "Dark Barracks",
    1000023: "Dark Elixir Drill",
    1000024: "Dark Elixir Storage",
    1000029: "Dark Spell Factory",
    73000008: "Diggy",
    1000041: "Double Cannon",
    28000007: "Dragon Duke",
    4000065: "Dragon Rider",
    4000008: "Dragon",
    4000038: "Drop Ship",
    4000123: "Druid",
    1000031: "Eagle Artillery",
    26000010: "Earthquake Spell",
    4000059: "Electro Dragon",
    73000002: "Electro Owl",
    4000095: "Electro Titan",
    4000106: "Electrofire Wizard",
    1000035: "Elixir Collector",
    1000036: "Elixir Storage",
    1000050: "Firecrackers",
    1000089: "Firespitter",
    4000091: "Flame Flinger",
    26000005: "Freeze Spell",
    73000009: "Frosty",
    4000150: "Furnace",
    1000058: "Gem Mine",
    12000002: "Giant Bomb",
    1000057: "Giant Cannon",
    4000003: "Giant",
    12000020: "Giga Bomb",
    4000002: "Goblin",
    1000037: "Gold Mine",
    1000038: "Gold Storage",
    4000013: "Golem",
    28000002: "Grand Warden",
    73000017: "Greedy Raven",
    1000051: "Guard Post",
    26000011: "Haste Spell",
    4000082: "Headhunter",
    4000007: "Healer",
    1000082: "Healing Hut",
    26000001: "Healing Spell",
    1000093: "Helper Hut",
    1000071: "Hero Hall",
    103000012: "Hero Hunter",
    102000036: "Hero Hunter Hitpoints",
    102000037: "Hero Hunter DPS",
    102000038: "Hero Hunter PSL",
    1000043: "Hidden Tesla",
    4000070: "Hog Glider",
    4000011: "Hog Rider",
    103000011: "Hot Candle",
    103000033: "Hot Candle - HP",
    102000034: "Hot Candle - DPS",
    102000035: "Hot Candle - TSA",
    26000109: "Ice Block Spell",
    4000058: "Ice Golem",
    1000027: "Inferno Tower",
    26000035: "Invisibility Spell",
    26000003: "Jump Spell",
    93000001: "Lab Assistant",
    1000007: "Laboratory",
    73000000: "L.A.S.S.I",
    4000017: "Lava Hound",
    1000063: "Lava Launcher",
    26000000: "Lightning Spell",
    107000008: "Logger",
    4000087: "Log Launcher",
    107000000: "Longshot",
    12000014: "Mega Mine",
    1000052: "Mega Tesla",
    4000177: "Meteor Golem",
    73000001: "Mighty Yak",
    12000013: "Mine",
    4000024: "Miner",
    28000006: "Minion Prince",
    4000010: "Minion",
    1000077: "Monolith",
    1000013: "Mortar",
    1000084: "Multi-Archer Tower",
    1000079: "Multi-Gear Tower",
    1000045: "Multi Mortar",
    4000042: "Night Witch",
    1000078: "O.T.T.O's Outpost",
    26000070: "Overgrowth Spell",
    4000009: "P.E.K.K.A",
    1000068: "Pet House",
    73000004: "Phoenix",
    73000007: "Poison Lizard",
    26000009: "Poison Spell",
    4000036: "Power P.E.K.K.A",
    93000002: "Prospector",
    12000011: "Push Trap",
    26000002: "Rage Spell",
    4000031: "Raged Barbarian",
    26000053: "Recall Spell",
    1000049: "Reinforcement Camp",
    1000086: "Revenge Tower",
    26000098: "Revive Spell",
    1000085: "Ricochet Cannon",
    1000056: "Roaster",
    4000110: "Root Rider",
    28000004: "Royal Champion",
    4000109: "Ruin Witch",
    1000067: "Scattershot",
    12000006: "Seeking Air Mine",
    4000075: "Siege Barracks",
    4000188: "Sky Wagon",
    26000017: "Skeleton Spell",
    12000008: "Skeleton Trap",
    107000001: "Smasher",
    4000032: "Sneaky Archer",
    73000016: "Sneezy",
    1000020: "Spell Factory",
    1000072: "Spell Tower",
    73000010: "Spirit Fox",
    12000010: "Spring Trap",
    1000046: "Star Laboratory",
    4000062: "Stone Slammer",
    1000102: "Super Wizard Tower",
    4000132: "Thrower",
    12000016: "Tornado Trap",
    26000120: "Totem Spell",
    1000001: "Town Hall",
    4000135: "Troop Launcher",
    73000003: "Unicorn",
    4000012: "Valkyrie",
    4000004: "Wall Breaker",
    4000051: "Wall Wrecker",
    1000033: "Wall",
    4000015: "Witch",
    1000011: "Wizard Tower",
    4000006: "Wizard",
    1000059: "Workshop",
    1000081: "X-Bow",
    1000021: "X-Bow",
    4000053: "Yeti"
  };

  @override
  String getName(int id) => names[id] ?? "t.me/nightowleyes ($id)";
}
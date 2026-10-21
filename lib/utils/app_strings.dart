import 'package:shared_preferences/shared_preferences.dart';
import 'dart:ui' as ui;
import 'game_data.dart';

class AppStrings {
  static String languageCode = 'vi';

  static Future<void> initLanguage() async {
    final prefs = await SharedPreferences.getInstance();

    // KIỂM TRA XEM ĐÃ CÓ NGÔN NGỮ NÀO ĐƯỢC LƯU TRONG BỘ NHỚ CHƯA
    if (prefs.containsKey('app_language')) {
      languageCode = prefs.getString('app_language')!;
    } else {
      // NẾU CHƯA CÓ (ỨNG DỤNG MỚI CÀI ĐẶT): ĐỌC NGÔN NGỮ TỪ HỆ THỐNG
      final String systemLangCode = ui.PlatformDispatcher.instance.locale.languageCode;

      if (systemLangCode == 'vi') {
        languageCode = 'vi';
      } else {
        languageCode = 'en'; // Mọi ngôn ngữ khác (Mỹ, Nhật, Pháp...) đều quy về Tiếng Anh
      }

      // Lưu lại luôn vào bộ nhớ để các lần mở app sau khởi động nhanh hơn
      await prefs.setString('app_language', languageCode);
    }
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

  static TerminalScreenStrings get terminal => languageCode == 'vi' ? const TerminalScreenStringsVi() : const TerminalScreenStringsEn();
  static ScheduleServiceStrings get schedule => languageCode == 'vi' ? const ScheduleServiceStringsVi() : const ScheduleServiceStringsEn();
  static AlarmPopupStrings get alarm => languageCode == 'vi' ? const AlarmPopupStringsVi() : const AlarmPopupStringsEn();
  static VillageCardStrings get card => languageCode == 'vi' ? const VillageCardStringsVi() : const VillageCardStringsEn();
  static MainStrings get mainApp => languageCode == 'vi' ? const MainStringsVi() : const MainStringsEn();
  static VillageDetailDialogStrings get dialog => languageCode == 'vi' ? const VillageDetailDialogStringsVi() : const VillageDetailDialogStringsEn();
  static GameData get gameData => languageCode == 'vi' ? const GameDataVi() : const GameDataEn();
  static SettingsStrings get settings => languageCode == 'vi' ? const SettingsStringsVi() : const SettingsStringsEn();
  static OnlineScreenStrings get onlineScreen => languageCode == 'vi' ? const OnlineScreenStringsVi() : const OnlineScreenStringsEn();
  static WarDetailScreenStrings get warDetail => languageCode == 'vi' ? const WarDetailScreenStringsVi() : const WarDetailScreenStringsEn();
  static WarDashboardWidgetStrings get warDashboard => languageCode == 'vi' ? const WarDashboardWidgetStringsVi() : const WarDashboardWidgetStringsEn();
}

// ==========================================
// CÁC LỚP TRỪU TƯỢNG (INTERFACE CHUNG)
// ==========================================
abstract class TerminalScreenStrings {
  const TerminalScreenStrings();
  String get headerSmallTitle;
  String get headerSupportProject;
  String get textSupportProject;
  String get textSupportProjectQRScanner;
  String get debugQRImageNotFound;
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
  String get btnSettings;
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
  String get trackingOptionsLabel;
  String get trackingHomeVillage;
  String get trackingBuilderBase;
  String get debugLoadAlarmStateError;
  String get debugParseVillageError;
  String get debugLoadNameError;
  String get debugLoadGeneralError;
  String get btnUpdateAvailable;
  String get defaultVillageNameSearching;
  String get statusFetchingVillageName;
  String get statusFoundNameWaitingConfirm;
  String get statusApiTimeoutManualInput;
  String get statusSavedSettings;
  String get statusSavedDefault;
  String get labelLanguage;
  String get labelServerOnline;
  String get quickPasteEmpty;
  String get quickPasteDisabled;
  String get quickPastePinned;
  String get quickPasteUpdated;
  String get quickPasteAdded;
  String get btnQuickPasteOn;
  String get btnPinQuickPaste;
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
  String get channelName;
  String get channelDescription;
  String get warPreAlarmTitle;
  String get warEndAlarmTitle;
  String get debugCancelledWarAlarms;
  String get quickPasteNotificationTitle;
  String get quickPasteNotificationBody;
  String get quickPasteChannelName;
  String get channelQuickPasteDesc;
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
  String get baseAlarmsToggleLabel;
  String get groupBuilderNight;
  String get groupBuilder;
  String get statusWorkingSuffix;
  String get groupPet;
  String get statusUpgradingSuffix;
  String get groupLabNight;
  String get groupLabMain;
  String get separatorDots;
  String get logGroupNameBuilderNight;
  String get logGroupNameBuilder;
  String get logGroupNamePet;
  String get logGroupNameLabNight;
  String get logGroupNameLabMain;
}

abstract class GameData {
  const GameData();
  String getName(int id);
}

abstract class SettingsStrings {
  const SettingsStrings();
  String get settingsTitle;
  String get settingsSchedulePrefix;
  String get settingsAutoSwitchPrefix;
  String get settingsFrom;
  String get settingsTo;
  String get settingsAnd;
  String get settingsBtnAdd;
  String get settingsActionNone;
  String get settingsActionSystem;
  String get settingsActionFullscreen;
  String get labelPickStart;
  String get labelPickEnd;
  String get errorOverlap;
  String get btnDeleteRule;
  String get settingsPreAlarmTitle;
  String get labelPreAlarm;
  String get labelAppInfo;
  String get settingsAutoCheckUpdate;
  String get btnCheckUpdateNow;
  String get statusUpToDate;
  String get statusUpdateAvailable;
  String get statusUpdateError;
  String get labelVersion;
  String get btnPrivacyPolicy;
  String get btnLicenses;
  String get privacyDialogTitle;
  String get privacyDialogContent;
  String get dialogWarningTitle;
  String get dialogWarningContent;
  String get btnCancelDialog;
  String get btnForceDisable;
  String get errorCannotOpenLink;
  String get warAlarmConfigTitle;
  String get warPreAlarmLabel;
  String get warEndAlarmLabel;
  String get warAutoSyncLabel;
  String get btnTypeNotification;
  String get btnTypeAlarm;
  String get errorInvalidTime;
}

abstract class OnlineScreenStrings {
  const OnlineScreenStrings();
  String get statusReadyApi;
  String get statusClanExists;
  String get statusSearchingClan;
  String get statusAddedClan;
  String get statusErrorNotFound;
  String get statusErrorApi;
  String get statusDeletedClan;
  String get statusCancelledFetch;
  String get statusWarDataSuccess;
  String get statusNoWar;
  String get statusWarDataError;
  String get statusMaintenance; // BỔ SUNG TRẠNG THÁI BẢO TRÌ
  String get labelSync;
  String get dialogWarningTitle;
  String get btnCancelDialog;
  String get btnForceDisable;
  String get labelClanName;
  String get btnDeleteClan;
  String get labelClanTag;
  String get labelBadge;
  String get labelLevel;
  String get labelAddClan;
  String get hintPasteTag;
  String get btnConfirmAdd;
  String get overlayFetchingData;
  String get overlayClanPrefix;
  String get overlayLoading;
  String get bannerClanWar;
}

abstract class WarDetailScreenStrings {
  const WarDetailScreenStrings();
  String get statusCalculating;
  String get statusUnknown;
  String get statusEndedCalculating;
  String get statusEndsIn;
  String get statusPrepCalculating;
  String get statusStartsIn;
  String get statusEnded;

  String get dialogTitleMissedAttacks;
  String get dialogMyClanCompleted;
  String get dialogEnemyCompleted;
  String get dialogAttacksCount;
  String get loadingData;
  String get btnBack;
  String get labelVs;
  String get labelMe;
  String get labelEnemy;
  String get btnMissedAttacks;
}

abstract class WarDashboardWidgetStrings {
  const WarDashboardWidgetStrings();
  String get errorEmptyCwlData;
  String get errorNoClanList;
  String get cwlAnalysisTitle;
  String get colClanName;
  String get btnViewMatchDetails;
  String get btnBack;
  String get errorNoWarData;
}
// ==========================================
// BỘ TỪ ĐIỂN TIẾNG VIỆT
// ==========================================
class TerminalScreenStringsVi extends TerminalScreenStrings {
  const TerminalScreenStringsVi();
  @override String get headerSmallTitle => "[ ỦNG HỘ ]";
  @override String get headerSupportProject => "ỦNG HỘ DỰ ÁN";
  @override String get textSupportProject => "Nếu bạn thấy ứng dụng này hữu ích, hãy cân nhắc ủng hộ để duy trì và phát triển dự án!";
  @override String get textSupportProjectQRScanner => "— HOẶC QUÉT MÃ QR —";
  @override String get debugQRImageNotFound => "Chưa tìm thấy ảnh\nassets/donate-qr.png";
  @override String get labelRealTime => "NGÀY HOÀN TẤT";
  @override String get toggleOn => "[ BẬT ]";
  @override String get toggleOff => "[ TẮT ]";
  @override String get labelServer => "SERVER: LOCAL";
  @override String get labelTapToSwitchServer => "[ BẤM ĐỂ CHUYỂN ĐỔI LÀNG ]";
  @override String get tabBuilderBase => "■  C Ă N   C Ứ   T H Ợ   X Â Y  ■";
  @override String get tabMainVillage => "■  L À N G   C H Í N H  ■";
  @override String get logoTitle => "C O C   T I M E R";
  @override String get logoSubtitle => "ĐẾM NGƯỢC THỜI GIAN NÂNG";
  @override String get inputSectionLabel => "D Ữ   L I Ệ U   L À N G";
  @override String get inputHint => "DÁN JSON VÀO ĐÂY...";
  @override String get btnPaste => "DÁN";
  @override String get btnSubmit => "X Á C   N H Ậ N   ►";
  @override String get btnSettings => "[ CÀI ĐẶT ]";
  @override String get btnXiaomiPermission => "CẤP QUYỀN TRÊN XIAOMI/POCO";
  @override String get footerHowtoTitle => "CHƯA BIẾT CÁCH XUẤT DỮ LIỆU LÀNG?";
  @override String get footerHowtoDesc => "CÀI ĐẶT GAME > THÊM CÀI ĐẶT > XUẤT DỮ LIỆU LÀNG THEO ĐỊNH DẠNG JSON";
  @override String get statusWaitingJson => "> CHỜ DỮ LIỆU JSON";
  @override String get statusLoadedSavedData => "> ĐÃ TẢI DỮ LIỆU LƯU TRỮ";
  @override String get statusVillageDeleted => "> ĐÃ XÓA LÀNG: {tag}";
  @override String get statusAlarmSetFullscreen => "> [BÁO THỨC] {typeString} {dataId}";
  @override String get statusAlarmOff => "> [ĐĐ TẮT] {typeString} {dataId}";
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
  @override String get deleteDialogMessage => "Bạn có chắc chắn muốn xóa dữ liệu JSON và báo thức của làng {tag} không?";
  @override String get btnCancel => "HỦY";
  @override String get btnDeleteNow => "XÓA NGAY";
  @override String get newVillageDialogTitle => "PHÁT HIỆN LÀNG MỚI";
  @override String get newVillageDialogTagLabel => "Mã: {tag}";
  @override String get newVillageNameHint => "Nhập tên làng (VD: Acc Chính)...";
  @override String get btnSaveAndAddVillage => "LƯU";
  @override String get trackingOptionsLabel => "TÙY CHỌN THEO DÕI:";
  @override String get trackingHomeVillage => "Làng Chính";
  @override String get trackingBuilderBase => "Căn cứ Thợ Xây";
  @override String get debugLoadAlarmStateError => "Lỗi load trạng thái báo thức: {e}";
  @override String get debugParseVillageError => "Lỗi parse {key}: {e}";
  @override String get debugLoadNameError => "Lỗi load tên làng: {e}";
  @override String get debugLoadGeneralError => "Lỗi load: {e}";
  @override String get btnUpdateAvailable => "[ TẢI BẢN {version} ]";
  @override String get defaultVillageNameSearching => "ĐANG TÌM TÊN LÀNG...";
  @override String get statusFetchingVillageName => "> ĐANG TRUY XUẤT TÊN LÀNG [ {tag} ]...";
  @override String get statusFoundNameWaitingConfirm => "> ĐÃ TÌM THẤY TÊN: {name}. ĐANG CHỜ XÁC NHẬN...";
  @override String get statusApiTimeoutManualInput => "> LỖI API / QUÁ GIỜ: VUI LÒNG NHẬP TÊN THỦ CÔNG";
  @override String get statusSavedSettings => "> ĐÃ LƯU THIẾT LẬP: {name}";
  @override String get statusSavedDefault => "> ĐÃ LƯU MẶC ĐỊNH: {name}";
  @override String get labelLanguage => "NGÔN NGỮ: ";
  @override String get labelServerOnline => "SERVER: ONLINE";
  @override String get quickPasteEmpty => "> BỘ NHỚ TẠM TRỐNG!";
  @override String get quickPasteDisabled => "> ĐÃ TẮT THÔNG BÁO DÁN NHANH";
  @override String get quickPastePinned => "> ĐÃ GHIM DÁN NHANH LÊN THANH THÔNG BÁO";
  @override String get quickPasteUpdated => "✓ Đã lưu: {name} ({tag}) — Chạm để dán tiếp";
  @override String get quickPasteAdded => "✓ Đã thêm: {name} ({tag}) — Chạm để dán tiếp";
  @override String get btnQuickPasteOn => "[ DÁN NHANH: BẬT ]";
  @override String get btnPinQuickPaste => "[ GHIM DÁN NHANH ]";
}

class ScheduleServiceStringsVi extends ScheduleServiceStrings {
  const ScheduleServiceStringsVi();
  @override String get notificationTitle => "■ HOÀN TẤT ■";
  @override String get notificationBody => "{villageName} > {itemName} ({tag}).";
  @override String get alarmNotificationTitle => "■ HOÀN TẤT ■";
  @override String get alarmNotificationBody => "Làng: {villageName}\nHoàn tất: {itemName}\n(Mã: {tag})";
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
  @override String get channelName => "Thông Báo Hệ Thống";
  @override String get channelDescription => "Thông báo cơ bản khi hoàn thành nâng cấp";
  @override String get warPreAlarmTitle => "SẮP KẾT THÚC WAR";
  @override String get warEndAlarmTitle => "WAR ĐÃ KẾT THÚC";
  @override String get debugCancelledWarAlarms => "> ĐÃ HỦY TOÀN BỘ BÁO THỨC WAR CỦA CLAN: {clanTag}";
  @override String get quickPasteNotificationTitle => "■ CHẾ ĐỘ DÁN NHANH ĐANG BẬT";
  @override String get quickPasteNotificationBody => "Chạm vào đây sau khi Copy JSON trong game để lưu ngay";
  @override String get quickPasteChannelName => "Chế Độ Dán Nhanh";
  @override String get channelQuickPasteDesc => "Thanh công cụ dán nhanh JSON khi đang trong game";
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
  @override String get baseAlarmsToggleLabel => "THÔNG BÁO LÀNG NÀY:";
  @override String get groupBuilderNight => "> THỢ XÂY";
  @override String get groupBuilder => "> LỀU THỢ XÂY";
  @override String get statusWorkingSuffix => "ĐANG NÂNG";
  @override String get groupPet => "> CHUỒNG LINH THÚ";
  @override String get statusUpgradingSuffix => "ĐANG NÂNG";
  @override String get groupLabNight => "> PHÒNG THÍ NGHIỆM SAO";
  @override String get groupLabMain => "> PHÒNG THÍ NGHIỆM";
  @override String get separatorDots => " ............................................................................";
  @override String get logGroupNameBuilderNight => "THỢ XÂY ĐÊM";
  @override String get logGroupNameBuilder => "THỢ XÂY";
  @override String get logGroupNamePet => "LINH THÚ";
  @override String get logGroupNameLabNight => "THÍ NGHIỆM ĐÊM";
  @override String get logGroupNameLabMain => "PHÒNG THÍ NGHIỆM";
}

class SettingsStringsVi extends SettingsStrings {
  const SettingsStringsVi();
  @override String get settingsTitle => "■ CÀI ĐẶT";
  @override String get settingsSchedulePrefix => "KHUNG GIỜ ";
  @override String get settingsAutoSwitchPrefix => "Đổi báo thức thành ";
  @override String get settingsFrom => "từ";
  @override String get settingsTo => "đến";
  @override String get settingsAnd => "và";
  @override String get settingsBtnAdd => "[ THÊM KHUNG GIỜ ]";
  @override String get settingsActionNone => "im lặng";
  @override String get settingsActionSystem => "thông báo";
  @override String get settingsActionFullscreen => "báo thức";
  @override String get labelPickStart => "Giờ Bắt Đầu";
  @override String get labelPickEnd => "Giờ Kết Thúc";
  @override String get errorOverlap => "LỖI: Trùng khung giờ với lịch khác!";
  @override String get btnDeleteRule => "[ XOÁ ]";
  @override String get settingsPreAlarmTitle => "NHẮC TRƯỚC KHI NÂNG CẤP XONG";
  @override String get labelPreAlarm => "Báo sớm trước (phút):";
  @override String get labelAppInfo => "THÔNG TIN ỨNG DỤNG";
  @override String get settingsAutoCheckUpdate => "TỰ ĐỘNG KIỂM TRA BẢN CẬP NHẬT";
  @override String get btnCheckUpdateNow => "[ KIỂM TRA CẬP NHẬT ]";
  @override String get statusUpToDate => "> Đang ở phiên bản mới nhất";
  @override String get statusUpdateAvailable => "> CÓ BẢN MỚI: {newVersion}";
  @override String get statusUpdateError => "> Không thể kiểm tra (Lỗi mạng)!";
  @override String get labelVersion => "Phiên bản hiện tại: {version}";
  @override String get btnPrivacyPolicy => "[ BẢO MẬT ]";
  @override String get btnLicenses => "[ GIẤY PHÉP ]";
  @override String get privacyDialogTitle => "■ BẢO MẬT DỮ LIỆU";
  @override String get privacyDialogContent => "- LƯU TRỮ CỤC BỘ: Toàn bộ dữ liệu làng (JSON), mã Clan và cài đặt báo thức chỉ được lưu trực tiếp trên thiết bị của bạn.\n\n- KẾT NỐI API: Chế độ Online chỉ đọc dữ liệu công khai từ máy chủ Supercell để lấy thời gian War.\n\n- KHÔNG THU THẬP: Ứng dụng tuyệt đối KHÔNG theo dõi, KHÔNG lưu trữ đám mây và KHÔNG chia sẻ dữ liệu cá nhân.";
  @override String get dialogWarningTitle => "CẢNH BÁO TẮT ĐỒNG BỘ NGẦM";
  @override String get dialogWarningContent => "Khi tắt tính năng này, ứng dụng sẽ ngừng tự động cập nhật dữ liệu War dưới nền.\n\nBạn sẽ KHÔNG nhận được thông báo hay báo thức cho các trận War mới, trừ khi tự mở ứng dụng để cập nhật thủ công.";
  @override String get btnCancelDialog => "[ GIỮ LẠI ]";
  @override String get btnForceDisable => "[ VẪN TẮT ]";
  @override String get errorCannotOpenLink => "Không thể mở đường dẫn";
  @override String get warAlarmConfigTitle => "BÁO THỨC CLAN WAR";
  @override String get warPreAlarmLabel => "Báo trước khi War kết thúc";
  @override String get warEndAlarmLabel => "Báo ngay khi War kết thúc";
  @override String get warAutoSyncLabel => "Tự động cập nhật lịch War ngầm";
  @override String get btnTypeNotification => "[ THÔNG BÁO ]";
  @override String get btnTypeAlarm => "[ BÁO THỨC ]";
  @override String get errorInvalidTime => "Tối đa chỉ được nhập 06:00!";
}

class OnlineScreenStringsVi extends OnlineScreenStrings {
  const OnlineScreenStringsVi();
  @override String get statusReadyApi => "> SẴN SÀNG KẾT NỐI API...";
  @override String get statusClanExists => "> CLAN NÀY ĐÃ CÓ TRONG DANH SÁCH!";
  @override String get statusSearchingClan => "> ĐANG TÌM KIẾM CLAN [ {tag} ] TRÊN SERVER...";
  @override String get statusAddedClan => "> ĐÃ THÊM CLAN: {name}";
  @override String get statusErrorNotFound => "> LỖI: KHÔNG TÌM THẤY CLAN (SAI MÃ HOẶC MẠNG KÉM)";
  @override String get statusErrorApi => "> LỖI KẾT NỐI API: {error}";
  @override String get statusDeletedClan => "> ĐÃ XÓA CLAN VÀ HỦY BÁO THỨC LIÊN QUAN.";
  @override String get statusCancelledFetch => "> ĐÃ HỦY TRUY XUẤT.";
  @override String get statusWarDataSuccess => "> TẢI DỮ LIỆU WAR THÀNH CÔNG!";
  @override String get statusNoWar => "> CLAN [ {name} ] KHÔNG CÓ TRẬN WAR NÀO.";
  @override String get statusWarDataError => "> LỖI TẢI DỮ LIỆU WAR: {error}";
  @override String get statusMaintenance => "> HỆ THỐNG CLASH OF CLANS ĐANG BẢO TRÌ!"; // ĐÃ THÊM DÒNG NÀY

  @override String get labelSync => "ĐỒNG BỘ: ";
  @override String get dialogWarningTitle => "CẢNH BÁO HỆ THỐNG";
  @override String get btnCancelDialog => "[ HỦY ]";
  @override String get btnForceDisable => "[ VẪN TẮT ]";

  @override String get labelClanName => "Tên clan: ";
  @override String get btnDeleteClan => "[ XÓA ]";
  @override String get labelClanTag => "Mã clan:  ";
  @override String get labelBadge => "HUY HIỆU";
  @override String get labelLevel => "CẤP ĐỘ";

  @override String get labelAddClan => "T H Ê M   C L A N   T H E O   D Õ I";
  @override String get hintPasteTag => "DÁN MÃ HỘI VÀO ĐÂY";
  @override String get btnConfirmAdd => "X Á C   N H Ậ N   ►";

  @override String get overlayFetchingData => "TRUY XUẤT DỮ LIỆU TỪ SERVER";
  @override String get overlayClanPrefix => "> CLAN: ";
  @override String get overlayLoading => "ĐANG TẢI ";
  @override String get bannerClanWar => "■ H Ộ I   C H I Ế N ■";
}

class WarDetailScreenStringsVi extends WarDetailScreenStrings {
  const WarDetailScreenStringsVi();
  @override String get statusCalculating => "Đang tính toán...";
  @override String get statusUnknown => "Unknown";
  @override String get statusEndedCalculating => " KẾT THÚC: [ ĐANG TỔNG KẾT ]";
  @override String get statusEndsIn => " KẾT THÚC: [ {time} ]";
  @override String get statusPrepCalculating => " VÀO TRẬN: [ ĐANG CHUẨN BỊ ]";
  @override String get statusStartsIn => " VÀO TRẬN: [ {time} ]";
  @override String get statusEnded => " TRẠNG THÁI: [ ĐÃ KẾT THÚC ]";

  @override String get dialogTitleMissedAttacks => "TRUY XUẤT: CHƯA ĐÁNH HẾT";
  @override String get dialogMyClanCompleted => "HOÀN THÀNH 100%";
  @override String get dialogEnemyCompleted => "KẺ ĐỊCH ĐÃ ĐÁNH HẾT";
  @override String get dialogAttacksCount => "ĐÁNH: {atkCount}/{maxAttacks}";

  @override String get loadingData => "> ĐANG TRUY XUẤT DỮ LIỆU...";
  @override String get btnBack => "TRỞ VỀ";
  @override String get labelVs => "VS";
  @override String get labelMe => "Ta";
  @override String get labelEnemy => "Địch";
  @override String get btnMissedAttacks => "CHƯA TẤN CÔNG";
}

class WarDashboardWidgetStringsVi extends WarDashboardWidgetStrings {
  const WarDashboardWidgetStringsVi();
  @override String get errorEmptyCwlData => "> DỮ LIỆU CWL TRỐNG";
  @override String get errorNoClanList => "> KHÔNG TÌM THẤY DANH SÁCH CLAN";
  @override String get cwlAnalysisTitle => "CLAN WAR LEAGUE - PHÂN TÍCH ĐỘI HÌNH";
  @override String get colClanName => "TÊN HỘI";
  @override String get btnViewMatchDetails => "TRUY XUẤT CHI TIẾT TRẬN ĐẤU";
  @override String get btnBack => "TRỞ VỀ";
  @override String get errorNoWarData => "> KHÔNG TÌM THẤY DỮ LIỆU WAR";
}
// ==========================================
// BỘ TỪ ĐIỂN TIẾNG ANH
// ==========================================
class TerminalScreenStringsEn extends TerminalScreenStrings {
  const TerminalScreenStringsEn();
  @override String get headerSmallTitle => "[ DONATE ]";
  @override String get headerSupportProject => "DONATE PROJECT";
  @override String get textSupportProject => "If you find this app useful, consider supporting its development!";
  @override String get textSupportProjectQRScanner => "— OR SCAN QR CODE —";
  @override String get debugQRImageNotFound => "Image not found:\nassets/donate-qr.png";
  @override String get labelRealTime => "DATE OF COMPLETION";
  @override String get toggleOn => "[ ON ]";
  @override String get toggleOff => "[ OFF ]";
  @override String get labelServer => "SERVER: LOCAL";
  @override String get labelTapToSwitchServer => "[CLICK TO SWITCH VILLAGE]";
  @override String get tabBuilderBase => "■  B U I L D E R   B A S E  ■";
  @override String get tabMainVillage => "■  H O M E   V I L L A G E  ■";
  @override String get logoTitle => "C O C   T I M E R";
  @override String get logoSubtitle => "COUNTDOWN TO THE UPGRADE";
  @override String get inputSectionLabel => "V I L L A G E    D A T A";
  @override String get inputHint => "PASTE JSON HERE...";
  @override String get btnPaste => "PASTE";
  @override String get btnSubmit => "C O N F I R M   ►";
  @override String get btnSettings => "[ SETTINGS ]";
  @override String get btnXiaomiPermission => "GRANT PERMISSION ON XIAOMI/POCO";
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
  @override String get deleteDialogMessage => "Are you sure you want to delete the JSON data and alarms for village {tag}?";
  @override String get btnCancel => "CANCEL";
  @override String get btnDeleteNow => "DELETE";
  @override String get newVillageDialogTitle => "NEW VILLAGE DETECTED";
  @override String get newVillageDialogTagLabel => "Tag: {tag}";
  @override String get newVillageNameHint => "Enter village name (e.g., Main Acc)...";
  @override String get btnSaveAndAddVillage => "SAVE";
  @override String get trackingOptionsLabel => "TRACKING OPTIONS:";
  @override String get trackingHomeVillage => "Home Village";
  @override String get trackingBuilderBase => "Builder Base";
  @override String get debugLoadAlarmStateError => "Error loading alarm state: {e}";
  @override String get debugParseVillageError => "Parse error {key}: {e}";
  @override String get debugLoadNameError => "Error loading village name: {e}";
  @override String get debugLoadGeneralError => "Load error: {e}";
  @override String get btnUpdateAvailable => "[ GET {version} ]";
  @override String get defaultVillageNameSearching => "SEARCHING VILLAGE NAME...";
  @override String get statusFetchingVillageName => "> FETCHING VILLAGE NAME [ {tag} ]...";
  @override String get statusFoundNameWaitingConfirm => "> NAME FOUND: {name}. WAITING FOR CONFIRMATION...";
  @override String get statusApiTimeoutManualInput => "> API ERROR / TIMEOUT: PLEASE ENTER NAME MANUALLY";
  @override String get statusSavedSettings => "> SAVED SETTINGS: {name}";
  @override String get statusSavedDefault => "> SAVED DEFAULT: {name}";
  @override String get labelLanguage => "LANGUAGE: ";
  @override String get labelServerOnline => "SERVER: ONLINE";
  @override String get quickPasteEmpty => "> CLIPBOARD IS EMPTY!";
  @override String get quickPasteDisabled => "> QUICK-PASTE NOTIFICATION DISABLED";
  @override String get quickPastePinned => "> QUICK-PASTE PINNED TO NOTIFICATION BAR";
  @override String get quickPasteUpdated => "✓ Updated: {name} ({tag}) — Tap to paste next";
  @override String get quickPasteAdded => "✓ Added: {name} ({tag}) — Tap to paste next";
  @override String get btnQuickPasteOn => "[ QUICK PASTE: ON ]";
  @override String get btnPinQuickPaste => "[ PIN QUICK PASTE ]";
}

class ScheduleServiceStringsEn extends ScheduleServiceStrings {
  const ScheduleServiceStringsEn();
  @override String get notificationTitle => "■ COMPLETED ■";
  @override String get notificationBody => "{villageName} > {itemName} ({tag}).";
  @override String get alarmNotificationTitle => "■ COMPLETED ■";
  @override String get alarmNotificationBody => "Village: {villageName}\nDone: {itemName}\n(Tag: {tag})";
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
  @override String get channelName => "System Notifications";
  @override String get channelDescription => "Basic notifications when an upgrade completes";
  @override String get warPreAlarmTitle => "WAR ENDING SOON";
  @override String get warEndAlarmTitle => "WAR HAS ENDED";
  @override String get debugCancelledWarAlarms => "> CANCELLED ALL WAR ALARMS FOR CLAN: {clanTag}";
  @override String get quickPasteNotificationTitle => "■ QUICK-PASTE READY";
  @override String get quickPasteNotificationBody => "Tap here after copying JSON in-game to import instantly";
  @override String get quickPasteChannelName => "Quick Paste";
  @override String get channelQuickPasteDesc => "Quick-paste tool notification while in-game";
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
  @override String get labelVillageNamePrefix => "Village: ";
  @override String get labelTagPrefix => "Tag: ";
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
  @override String get baseAlarmsToggleLabel => "BASE ALARMS:";
  @override String get groupBuilderNight => "> BUILDER";
  @override String get groupBuilder => "> BUILDER's HUT";
  @override String get statusWorkingSuffix => "UPGRADING";
  @override String get groupPet => "> PET HOUSE";
  @override String get statusUpgradingSuffix => "UPGRADING";
  @override String get groupLabNight => "> STAR LABORATORY";
  @override String get groupLabMain => "> LABORATORY";
  @override String get separatorDots => " ............................................................................";
  @override String get logGroupNameBuilderNight => "MASTER BUILDER";
  @override String get logGroupNameBuilder => "BUILDER";
  @override String get logGroupNamePet => "PET";
  @override String get logGroupNameLabNight => "STAR LABORATORY";
  @override String get logGroupNameLabMain => "LABORATORY";
}

class SettingsStringsEn extends SettingsStrings {
  const SettingsStringsEn();
  @override String get settingsTitle => "■ SETTINGS";
  @override String get settingsSchedulePrefix => "SCHEDULE: ";
  @override String get settingsAutoSwitchPrefix => "Change alarm to ";
  @override String get settingsFrom => "from";
  @override String get settingsTo => "to";
  @override String get settingsAnd => "and";
  @override String get settingsBtnAdd => "[ ADD TIME SLOT ]";
  @override String get settingsActionNone => "silent";
  @override String get settingsActionSystem => "notification";
  @override String get settingsActionFullscreen => "full alarm";
  @override String get labelPickStart => "Start Time";
  @override String get labelPickEnd => "End Time";
  @override String get errorOverlap => "ERROR: Time slot overlaps!";
  @override String get btnDeleteRule => "[ DEL ]";
  @override String get settingsPreAlarmTitle => "EARLY UPGRADE REMINDER";
  @override String get labelPreAlarm => "Remind early by (min):";
  @override String get labelAppInfo => "APP INFORMATION";
  @override String get settingsAutoCheckUpdate => "AUTO-CHECK FOR UPDATES";
  @override String get btnCheckUpdateNow => "[ CHECK FOR UPDATES ]";
  @override String get statusUpToDate => "> App is up to date";
  @override String get statusUpdateAvailable => "> NEW UPDATE: {newVersion}";
  @override String get statusUpdateError => "> Update check failed (Network error)!";
  @override String get labelVersion => "Current version: {version}";
  @override String get btnPrivacyPolicy => "[ PRIVACY ]";
  @override String get btnLicenses => "[ LICENSES ]";
  @override String get privacyDialogTitle => "■ DATA PRIVACY";
  @override String get privacyDialogContent => "- LOCAL STORAGE: All village data (JSON), Clan tags, and alarm settings are stored strictly on your device.\n\n- API CONNECTIONS: Online Mode only reads public data from Supercell servers to fetch War schedules.\n\n- NO TRACKING: We DO NOT track, cloud-save, or share any of your personal information.";
  @override String get dialogWarningTitle => "BACKGROUND SYNC WARNING";
  @override String get dialogWarningContent => "If disabled, the app will stop syncing War data in the background.\n\nYou will NOT receive notifications or alarms for upcoming Wars unless you open the app to refresh Clan data manually.";
  @override String get btnCancelDialog => "[ KEEP ON ]";
  @override String get btnForceDisable => "[ DISABLE ANYWAY ]";
  @override String get errorCannotOpenLink => "Cannot open link";
  @override String get warAlarmConfigTitle => "CLAN WAR ALERTS";
  @override String get warPreAlarmLabel => "Alert before War ends";
  @override String get warEndAlarmLabel => "Alert when War ends";
  @override String get warAutoSyncLabel => "Auto-sync War data";
  @override String get btnTypeNotification => "[ NOTIFICATION ]";
  @override String get btnTypeAlarm => "[ ALARM ]";
  @override String get errorInvalidTime => "You can enter a maximum of 06:00!";
}

class OnlineScreenStringsEn extends OnlineScreenStrings {
  const OnlineScreenStringsEn();
  @override String get statusReadyApi => "> READY TO CONNECT API...";
  @override String get statusClanExists => "> CLAN ALREADY IN THE LIST!";
  @override String get statusSearchingClan => "> SEARCHING FOR CLAN [ {tag} ] ON SERVER...";
  @override String get statusAddedClan => "> CLAN ADDED: {name}";
  @override String get statusErrorNotFound => "> ERROR: CLAN NOT FOUND (INVALID TAG OR BAD NETWORK)";
  @override String get statusErrorApi => "> API CONNECTION ERROR: {error}";
  @override String get statusDeletedClan => "> DELETED CLAN AND CANCELLED RELATED ALARMS.";
  @override String get statusCancelledFetch => "> FETCH CANCELLED.";
  @override String get statusWarDataSuccess => "> WAR DATA LOADED SUCCESSFULLY!";
  @override String get statusNoWar => "> CLAN [ {name} ] HAS NO ACTIVE WAR.";
  @override String get statusWarDataError => "> ERROR LOADING WAR DATA: {error}";
  @override String get statusMaintenance => "> CLASH OF CLANS SERVERS ARE UNDER MAINTENANCE!";

  @override String get labelSync => "SYNC: ";
  @override String get dialogWarningTitle => "SYSTEM WARNING";
  @override String get btnCancelDialog => "[ CANCEL ]";
  @override String get btnForceDisable => "[ DISABLE ANYWAY ]";

  @override String get labelClanName => "Clan: ";
  @override String get btnDeleteClan => "[ DEL ]";
  @override String get labelClanTag => "Tag:  ";
  @override String get labelBadge => "BADGE";
  @override String get labelLevel => "LEVEL";

  @override String get labelAddClan => "A D D   C L A N   T O   T R A C K";
  @override String get hintPasteTag => "PASTE CLAN TAG HERE";
  @override String get btnConfirmAdd => "C O N F I R M   ►";

  @override String get overlayFetchingData => "FETCHING DATA FROM SERVER";
  @override String get overlayClanPrefix => "> CLAN: ";
  @override String get overlayLoading => "LOADING ";
  @override String get bannerClanWar => "■ C L A N   W A R ■";
}

class WarDetailScreenStringsEn extends WarDetailScreenStrings {
  const WarDetailScreenStringsEn();
  @override String get statusCalculating => "Calculating...";
  @override String get statusUnknown => "Unknown";
  @override String get statusEndedCalculating => " ENDS: [ CALCULATING ]";
  @override String get statusEndsIn => " ENDS: [ {time} ]";
  @override String get statusPrepCalculating => " STARTS: [ PREPARING ]";
  @override String get statusStartsIn => " STARTS: [ {time} ]";
  @override String get statusEnded => " STATUS: [ ENDED ]";

  @override String get dialogTitleMissedAttacks => "QUERY: MISSED ATTACKS";
  @override String get dialogMyClanCompleted => "100% COMPLETED";
  @override String get dialogEnemyCompleted => "ENEMY COMPLETED ALL";
  @override String get dialogAttacksCount => "ATK: {atkCount}/{maxAttacks}";

  @override String get loadingData => "> FETCHING DATA...";
  @override String get btnBack => "BACK";
  @override String get labelVs => "VS";
  @override String get labelMe => "Me";
  @override String get labelEnemy => "Enemy";
  @override String get btnMissedAttacks => "MISSED ATTACKS";
}

class WarDashboardWidgetStringsEn extends WarDashboardWidgetStrings {
  const WarDashboardWidgetStringsEn();
  @override String get errorEmptyCwlData => "> EMPTY CWL DATA";
  @override String get errorNoClanList => "> CLAN LIST NOT FOUND";
  @override String get cwlAnalysisTitle => "CLAN WAR LEAGUE - ROSTER ANALYSIS";
  @override String get colClanName => "CLAN NAME";
  @override String get btnViewMatchDetails => "FETCH MATCH DETAILS";
  @override String get btnBack => "BACK";
  @override String get errorNoWarData => "> WAR DATA NOT FOUND";
}
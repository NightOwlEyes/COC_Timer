enum AlarmType {
  none,
  system,
  fullscreen
}

class BoostData {
  final int builderBoost;
  final int labBoost;
  final int petBoost;
  final int builderConsumable;
  final int labConsumable;
  final int clocktowerBoost; // MỚI: Tháp đồng hồ Làng Đêm
  final int builderHelperTimer;
  final int labHelperTimer;

  BoostData({
    this.builderBoost = 0,
    this.labBoost = 0,
    this.petBoost = 0,
    this.builderConsumable = 0,
    this.labConsumable = 0,
    this.clocktowerBoost = 0,
    this.builderHelperTimer = 0,
    this.labHelperTimer = 0,
  });

  factory BoostData.fromJson(
    Map<String, dynamic>? json, {
    int builderHelperTimer = 0,
    int labHelperTimer = 0,
  }) {
    if (json == null) {
      return BoostData(
        builderHelperTimer: builderHelperTimer,
        labHelperTimer: labHelperTimer,
      );
    }
    return BoostData(
      builderBoost: json['builder_boost'] ?? 0,
      labBoost: json['lab_boost'] ?? 0,
      petBoost: json['pet_boost'] ?? 0,
      builderConsumable: json['builder_consumable'] ?? 0,
      labConsumable: json['lab_consumable'] ?? 0,
      clocktowerBoost: json['clocktower_boost'] ?? 0,
      builderHelperTimer: builderHelperTimer,
      labHelperTimer: labHelperTimer,
    );
  }
}

class UpgradeItem {
  final String instanceId;
  final int dataId;
  final int level;
  final int originalTimer;
  final DateTime realEta;
  final String typeString;
  final bool isExtra;
  bool isNotified;
  AlarmType alarmType;

  UpgradeItem({
    required this.instanceId,
    required this.dataId,
    required this.level,
    required this.originalTimer,
    required this.realEta,
    required this.typeString,
    this.isExtra = false,
    this.isNotified = false,
    this.alarmType = AlarmType.fullscreen,
  });
}

class VillageData {
  final String tag;
  final int timestamp;
  final int baseBuilders;
  final int totalBuilders2; // MỚI: Tổng số thợ xây đêm
  final BoostData boosts;
  final List<UpgradeItem> buildersItems;
  final List<UpgradeItem> petItems;
  final List<UpgradeItem> labItems;
  final List<UpgradeItem> builders2Items; // MỚI: Danh sách nâng cấp Làng Đêm
  final List<UpgradeItem> lab2Items;      // MỚI: Lính Làng Đêm

  VillageData({
    required this.tag,
    required this.timestamp,
    required this.baseBuilders,
    required this.totalBuilders2,
    required this.boosts,
    required this.buildersItems,
    required this.petItems,
    required this.labItems,
    required this.builders2Items,
    required this.lab2Items,
  });

  // Tính động tổng số thợ xây:
  // - Mặc định là số thợ xây gốc (1-6).
  // - Nếu có thợ xây yêu tinh (isExtra == true) đang hoạt động thì cộng thêm.
  // - Khi thợ xây yêu tinh hoàn tất, tổng số thợ tự động quay về lại số thợ gốc (VD: 6/6).
  // - Nếu thợ xây thường hoàn tất trước mà thợ xây yêu tinh vẫn đang làm thì vẫn giữ tổng là 7 (VD: 6/7).
  int get totalBuilders {
    final active = activeBuilders;
    final int activeExtraCount = active.where((i) => i.isExtra).length;
    final int expectedTotal = baseBuilders + activeExtraCount;
    return active.length > expectedTotal ? active.length : expectedTotal;
  }

  List<UpgradeItem> get activeBuilders {
    var list = buildersItems.where((i) => i.realEta.isAfter(DateTime.now())).toList();
    list.sort((a, b) => a.realEta.compareTo(b.realEta));
    return list;
  }
  List<UpgradeItem> get activePets {
    var list = petItems.where((i) => i.realEta.isAfter(DateTime.now())).toList();
    list.sort((a, b) => a.realEta.compareTo(b.realEta));
    return list;
  }
  List<UpgradeItem> get activeLab {
    var list = labItems.where((i) => i.realEta.isAfter(DateTime.now())).toList();
    list.sort((a, b) => a.realEta.compareTo(b.realEta));
    return list;
  }
  List<UpgradeItem> get activeBuilders2 {
    var list = builders2Items.where((i) => i.realEta.isAfter(DateTime.now())).toList();
    list.sort((a, b) => a.realEta.compareTo(b.realEta));
    return list;
  }
  List<UpgradeItem> get activeLab2 {
    var list = lab2Items.where((i) => i.realEta.isAfter(DateTime.now())).toList();
    list.sort((a, b) => a.realEta.compareTo(b.realEta));
    return list;
  }
}

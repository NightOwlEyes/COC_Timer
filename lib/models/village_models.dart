enum AlarmType {
  none,
  system,
  fullscreen
}

class BoostData {
  final int builderBoost;
  final int labBoost;
  final int petBoost;
  final int builderConsumable; // Bổ sung Món ăn thợ xây (Snack)
  final int labConsumable;     // Bổ sung Món ăn phòng thí nghiệm (Snack)

  BoostData({
    this.builderBoost = 0,
    this.labBoost = 0,
    this.petBoost = 0,
    this.builderConsumable = 0,
    this.labConsumable = 0,
  });

  factory BoostData.fromJson(Map<String, dynamic>? json) {
    if (json == null) return BoostData();
    return BoostData(
      builderBoost: json['builder_boost'] ?? 0,
      labBoost: json['lab_boost'] ?? 0,
      petBoost: json['pet_boost'] ?? 0,
      builderConsumable: json['builder_consumable'] ?? 0, // Đọc từ JSON
      labConsumable: json['lab_consumable'] ?? 0,         // Đọc từ JSON
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
  bool isNotified; // Dành cho UI đếm ngược khi app đang mở
  AlarmType alarmType; // Thay thế cho boolean alarmEnabled cũ

  UpgradeItem({
    required this.instanceId,
    required this.dataId,
    required this.level,
    required this.originalTimer,
    required this.realEta,
    required this.typeString,
    this.isNotified = false,
    this.alarmType = AlarmType.fullscreen, // Đã đổi mặc định sang Báo thức
  });
}

class VillageData {
  final String tag;
  final int timestamp;
  final int totalBuilders;
  final BoostData boosts;
  final List<UpgradeItem> buildersItems;
  final List<UpgradeItem> petItems;
  final List<UpgradeItem> labItems;

  VillageData({
    required this.tag,
    required this.timestamp,
    required this.totalBuilders,
    required this.boosts,
    required this.buildersItems,
    required this.petItems,
    required this.labItems,
  });

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
}
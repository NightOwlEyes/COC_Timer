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

  BoostData({
    this.builderBoost = 0,
    this.labBoost = 0,
    this.petBoost = 0,
    this.builderConsumable = 0,
    this.labConsumable = 0,
    this.clocktowerBoost = 0,
  });

  factory BoostData.fromJson(Map<String, dynamic>? json) {
    if (json == null) return BoostData();
    return BoostData(
      builderBoost: json['builder_boost'] ?? 0,
      labBoost: json['lab_boost'] ?? 0,
      petBoost: json['pet_boost'] ?? 0,
      builderConsumable: json['builder_consumable'] ?? 0,
      labConsumable: json['lab_consumable'] ?? 0,
      clocktowerBoost: json['clocktower_boost'] ?? 0,
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
  bool isNotified;
  AlarmType alarmType;

  UpgradeItem({
    required this.instanceId,
    required this.dataId,
    required this.level,
    required this.originalTimer,
    required this.realEta,
    required this.typeString,
    this.isNotified = false,
    this.alarmType = AlarmType.fullscreen,
  });
}

class VillageData {
  final String tag;
  final int timestamp;
  final int totalBuilders;
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
    required this.totalBuilders,
    required this.totalBuilders2,
    required this.boosts,
    required this.buildersItems,
    required this.petItems,
    required this.labItems,
    required this.builders2Items,
    required this.lab2Items,
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
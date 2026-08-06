import 'dart:convert';
import '../models/village_models.dart';
import 'app_strings.dart';

class VillageParser {
  static VillageData parse(String jsonString) {
    final Map<String, dynamic> data = jsonDecode(jsonString);

    final tag = data['tag'] as String;
    final timestamp = data['timestamp'] as int;
    final boosts = BoostData.fromJson(data['boosts'] as Map<String, dynamic>?);

    List<UpgradeItem> buildersItems = [];
    List<UpgradeItem> petItems = [];
    List<UpgradeItem> labItems = [];
    List<UpgradeItem> builders2Items = [];
    List<UpgradeItem> lab2Items = [];

    int baseBuilders = 0;
    if (data.containsKey('buildings')) {
      for (var item in data['buildings']) {
        if (item['data'] == 1000015 || item['data'] == 1000077) {
          baseBuilders += (item['cnt'] as int? ?? 1);
        }
      }
    }
    if (baseBuilders == 0) baseBuilders = 5;

    int baseBuilders2 = 1;
    if (data.containsKey('buildings2')) {
      for (var item in data['buildings2']) {
        if (item['data'] == 1000078 || item['data'] == 1000047) {
          baseBuilders2 += (item['cnt'] as int? ?? 1);
        }
      }
    }

    int builderHelperLevel = 0;
    int labHelperLevel = 0;
    int builderHelperCooldown = 0;
    int labHelperCooldown = 0;
    if (data['helpers'] != null) {
      for (var h in data['helpers']) {
        if (h['data'] == 93000000) {
          builderHelperLevel = h['lvl'] ?? 0;
          builderHelperCooldown = h['helper_cooldown'] ?? 0;
        }
        if (h['data'] == 93000001) {
          labHelperLevel = h['lvl'] ?? 0;
          labHelperCooldown = h['helper_cooldown'] ?? 0;
        }
      }
    }

    DateTime calculateAdvancedEta({
      required int timer, required int boostDuration, required int boostSpeedAdd,
      required int consumableDuration, required int consumableSpeedAdd,
      required int helperTimer, required int helperLevel, required int helperCooldown,
      required bool helperRecurrent, required int timestamp,
    }) {
      double remainingWork = timer.toDouble();
      double timeElapsed = 0.0;
      double currentBoostRemaining = boostDuration.toDouble();
      double currentConsumableRemaining = consumableDuration.toDouble();
      double currentHelperActiveRemaining = helperTimer.toDouble();
      double currentHelperCooldown = helperCooldown.toDouble();

      while (remainingWork > 0) {
        int currentSpeed = 1;
        if (currentBoostRemaining > 0) currentSpeed += boostSpeedAdd;
        if (currentConsumableRemaining > 0) currentSpeed += consumableSpeedAdd;
        if (currentHelperActiveRemaining > 0) currentSpeed += helperLevel;

        double nextEvent = remainingWork / currentSpeed;

        if (currentBoostRemaining > 0 && currentBoostRemaining < nextEvent) nextEvent = currentBoostRemaining;
        if (currentConsumableRemaining > 0 && currentConsumableRemaining < nextEvent) nextEvent = currentConsumableRemaining;
        if (currentHelperActiveRemaining > 0 && currentHelperActiveRemaining < nextEvent) nextEvent = currentHelperActiveRemaining;

        // Chặn nextEvent lại đúng thời điểm Trợ lý hết Cooldown để thức dậy
        if (helperRecurrent && currentHelperActiveRemaining <= 0 && currentHelperCooldown > 0 && currentHelperCooldown < nextEvent) {
          nextEvent = currentHelperCooldown;
        }

        timeElapsed += nextEvent;
        remainingWork -= nextEvent * currentSpeed;
        currentBoostRemaining -= nextEvent;
        currentConsumableRemaining -= nextEvent;
        currentHelperActiveRemaining -= nextEvent;
        currentHelperCooldown -= nextEvent;

        if (remainingWork < 0.001) remainingWork = 0;
        if (currentBoostRemaining < 0.001) currentBoostRemaining = 0;
        if (currentConsumableRemaining < 0.001) currentConsumableRemaining = 0;
        if (currentHelperActiveRemaining < 0.001) currentHelperActiveRemaining = 0;
        if (currentHelperCooldown < 0.001) currentHelperCooldown = 0;

        // VÁ LỖI LOGIC: Khi cả Active và Cooldown đều <= 0, đánh thức trợ lý!
        if (helperRecurrent && remainingWork > 0 && currentHelperActiveRemaining <= 0 && currentHelperCooldown <= 0) {

          // Trợ lý chính thức tỉnh giấc! Reset lại bộ đếm cho ca làm việc mới
          currentHelperActiveRemaining = 3600.0;
          currentHelperCooldown = 82800.0;

          // Tính toán công việc giải quyết được trong 1 chu kỳ 24h (86400 giây thực tế)
          // Tốc độ gốc giải quyết được 86400 giây việc, Trợ lý làm thêm được 3600 * helperLevel
          double progressPerCycle = 86400.0 + (3600.0 * helperLevel);

          // Nếu lượng việc còn lại lớn hơn cả 1 chu kỳ 24h, Skip (Fast-forward) để chống treo App
          if (remainingWork > progressPerCycle) {
            int cycles = (remainingWork / progressPerCycle).floor();
            timeElapsed += cycles * 86400.0; // Thời gian thực trôi qua
            remainingWork -= cycles * progressPerCycle; // Khối lượng công việc giảm đi
          }
        }
      }
      return DateTime.fromMillisecondsSinceEpoch(timestamp * 1000).add(Duration(seconds: timeElapsed.round()));
    }

    void parseCategory(String key, List<UpgradeItem> targetList, int boostDuration, int boostSpeedAdd, int consumableDuration, int consumableSpeedAdd, int globalHelperLevel, int globalHelperCooldown) {
      if (data.containsKey(key)) {
        int index = 0;
        for (var item in data[key]) {
          int timer = item['timer'] ?? 0;
          if (timer > 0) {
            targetList.add(UpgradeItem(
              instanceId: "${tag}_${key}_${item['data']}_${index++}",
              dataId: item['data'] ?? 0, level: item['lvl'] ?? 0, originalTimer: timer,
              typeString: AppStrings.gameData.getName(item['data'] ?? 0),
              realEta: calculateAdvancedEta(
                timer: timer,
                boostDuration: boostDuration, boostSpeedAdd: boostSpeedAdd,
                consumableDuration: consumableDuration, consumableSpeedAdd: consumableSpeedAdd,
                helperTimer: item['helper_timer'] ?? 0, helperLevel: globalHelperLevel,
                helperCooldown: globalHelperCooldown, helperRecurrent: item['helper_recurrent'] ?? false,
                timestamp: timestamp,
              ),
            ));
          }

          if (item.containsKey('types')) {
            for (var typeObj in item['types']) {
              if (typeObj.containsKey('modules')) {
                for (var modObj in typeObj['modules']) {
                  int modTimer = modObj['timer'] ?? 0;
                  if (modTimer > 0) {
                    targetList.add(UpgradeItem(
                      instanceId: "${tag}_${key}_${item['data']}_${modObj['data']}_${index++}",
                      dataId: modObj['data'] ?? 0,
                      level: modObj['lvl'] ?? 0,
                      originalTimer: modTimer,
                      typeString: AppStrings.gameData.getName(modObj['data'] ?? 0),
                      realEta: calculateAdvancedEta(
                        timer: modTimer,
                        boostDuration: boostDuration, boostSpeedAdd: boostSpeedAdd,
                        consumableDuration: consumableDuration, consumableSpeedAdd: consumableSpeedAdd,
                        helperTimer: modObj['helper_timer'] ?? item['helper_timer'] ?? 0,
                        helperLevel: globalHelperLevel,
                        helperCooldown: globalHelperCooldown,
                        helperRecurrent: modObj['helper_recurrent'] ?? item['helper_recurrent'] ?? false,
                        timestamp: timestamp,
                      ),
                    ));
                  }
                }
              }
            }
          }
        }
      }
    }

    parseCategory('buildings', buildersItems, boosts.builderBoost, 9, boosts.builderConsumable, 1, builderHelperLevel, builderHelperCooldown);
    parseCategory('traps', buildersItems, boosts.builderBoost, 9, boosts.builderConsumable, 1, builderHelperLevel, builderHelperCooldown);
    parseCategory('guardians', buildersItems, boosts.builderBoost, 9, boosts.builderConsumable, 1, builderHelperLevel, builderHelperCooldown);
    parseCategory('heroes', buildersItems, boosts.builderBoost, 9, boosts.builderConsumable, 1, builderHelperLevel, builderHelperCooldown);
    parseCategory('pets', petItems, boosts.petBoost, 23, boosts.labConsumable, 3, 0, 0);
    parseCategory('spells', labItems, boosts.labBoost, 23, boosts.labConsumable, 3, labHelperLevel, labHelperCooldown);
    parseCategory('units', labItems, boosts.labBoost, 23, boosts.labConsumable, 3, labHelperLevel, labHelperCooldown);
    parseCategory('siege_machines', labItems, boosts.labBoost, 23, boosts.labConsumable, 3, labHelperLevel, labHelperCooldown);

    parseCategory('buildings2', builders2Items, boosts.clocktowerBoost, 9, 0, 0, 0, 0);
    parseCategory('traps2', builders2Items, boosts.clocktowerBoost, 9, 0, 0, 0, 0);
    parseCategory('heroes2', builders2Items, boosts.clocktowerBoost, 9, 0, 0, 0, 0);
    parseCategory('units2', lab2Items, boosts.clocktowerBoost, 9, 0, 0, 0, 0);

    int finalTotalBuilders = buildersItems.length > baseBuilders ? buildersItems.length : baseBuilders;
    int finalTotalBuilders2 = builders2Items.length > baseBuilders2 ? builders2Items.length : baseBuilders2;

    return VillageData(
        tag: tag, timestamp: timestamp,
        totalBuilders: finalTotalBuilders, totalBuilders2: finalTotalBuilders2,
        boosts: boosts,
        buildersItems: buildersItems, petItems: petItems, labItems: labItems,
        builders2Items: builders2Items, lab2Items: lab2Items
    );
  }
}
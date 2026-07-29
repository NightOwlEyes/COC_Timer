import 'dart:convert';
import '../models/village_models.dart';

class VillageParser {
  static VillageData parse(String jsonString) {
    final Map<String, dynamic> data = jsonDecode(jsonString);

    final tag = data['tag'] as String;
    final timestamp = data['timestamp'] as int;
    final boosts = BoostData.fromJson(data['boosts'] as Map<String, dynamic>?);

    List<UpgradeItem> buildersItems = [];
    List<UpgradeItem> petItems = [];
    List<UpgradeItem> labItems = [];

    // Tìm lều thợ xây chuẩn
    int baseBuilders = 0;
    if (data.containsKey('buildings')) {
      for (var item in data['buildings']) {
        if (item['data'] == 1000015 || item['data'] == 1000077) {
          baseBuilders += (item['cnt'] as int? ?? 1);
        }
      }
    }
    if (baseBuilders == 0) baseBuilders = 5;

    // Lấy thông số Helper
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
      required int helperTimer, required int helperLevel, required int helperCooldown,
      required bool helperRecurrent, required int timestamp,
    }) {
      double remainingWork = timer.toDouble();
      double timeElapsed = 0.0;
      double currentBoostRemaining = boostDuration.toDouble();
      double currentHelperActiveRemaining = helperTimer.toDouble();
      double currentHelperCooldown = helperCooldown.toDouble();

      while (remainingWork > 0) {
        int currentSpeed = 1;
        if (currentBoostRemaining > 0) currentSpeed += boostSpeedAdd;
        if (currentHelperActiveRemaining > 0) currentSpeed += helperLevel;

        double nextEvent = remainingWork / currentSpeed;

        if (currentBoostRemaining > 0 && currentBoostRemaining < nextEvent) nextEvent = currentBoostRemaining;
        if (currentHelperActiveRemaining > 0 && currentHelperActiveRemaining < nextEvent) nextEvent = currentHelperActiveRemaining;
        if (helperRecurrent && currentHelperActiveRemaining <= 0 && currentHelperCooldown > 0 && currentHelperCooldown < nextEvent) {
          nextEvent = currentHelperCooldown;
        }

        timeElapsed += nextEvent;
        remainingWork -= nextEvent * currentSpeed;
        currentBoostRemaining -= nextEvent;
        currentHelperActiveRemaining -= nextEvent;
        currentHelperCooldown -= nextEvent;

        if (remainingWork < 0.001) remainingWork = 0;
        if (currentBoostRemaining < 0.001) currentBoostRemaining = 0;
        if (currentHelperActiveRemaining < 0.001) currentHelperActiveRemaining = 0;
        if (currentHelperCooldown < 0.001) currentHelperCooldown = 0;

        if (helperRecurrent && remainingWork > 0 && currentHelperActiveRemaining <= 0 && currentHelperCooldown <= 0) {
          currentHelperActiveRemaining = 3600.0;
          currentHelperCooldown = 86400.0;
        }

        if (currentBoostRemaining <= 0 && currentHelperActiveRemaining <= 0 && !helperRecurrent) {
          timeElapsed += remainingWork;
          remainingWork = 0;
          break;
        }

        if (helperRecurrent && currentBoostRemaining <= 0 && currentHelperActiveRemaining <= 0 && remainingWork > 0) {
          if (currentHelperCooldown > 0) {
            double waitWork = currentHelperCooldown * 1;
            if (remainingWork <= waitWork) {
              timeElapsed += remainingWork;
              remainingWork = 0;
              break;
            } else {
              timeElapsed += currentHelperCooldown;
              remainingWork -= waitWork;
              currentHelperCooldown = 0;
              currentHelperActiveRemaining = 3600.0;
              currentHelperCooldown = 86400.0;
              continue;
            }
          }

          double progressPerCycle = 86400.0 + (3600.0 * helperLevel);
          if (remainingWork > progressPerCycle) {
            int cycles = (remainingWork / progressPerCycle).floor();
            timeElapsed += cycles * 86400.0;
            remainingWork -= cycles * progressPerCycle;
          }
        }
      }
      return DateTime.fromMillisecondsSinceEpoch(timestamp * 1000).add(Duration(seconds: timeElapsed.round()));
    }

    void parseCategory(String key, List<UpgradeItem> targetList, int boostDuration, int boostSpeedAdd, int globalHelperLevel, int globalHelperCooldown, String typeName) {
      if (data.containsKey(key)) {
        int index = 0;
        for (var item in data[key]) {
          int timer = item['timer'] ?? 0;
          if (timer > 0) {
            targetList.add(UpgradeItem(
              instanceId: "${tag}_${key}_${item['data']}_${index++}",
              dataId: item['data'] ?? 0, level: item['lvl'] ?? 0, originalTimer: timer, typeString: typeName,
              realEta: calculateAdvancedEta(
                timer: timer, boostDuration: boostDuration, boostSpeedAdd: boostSpeedAdd,
                helperTimer: item['helper_timer'] ?? 0, helperLevel: globalHelperLevel,
                helperCooldown: globalHelperCooldown, helperRecurrent: item['helper_recurrent'] ?? false,
                timestamp: timestamp,
              ),
            ));
          }
        }
      }
    }

    parseCategory('buildings', buildersItems, boosts.builderBoost, 9, builderHelperLevel, builderHelperCooldown, "Công trình");
    parseCategory('traps', buildersItems, boosts.builderBoost, 9, builderHelperLevel, builderHelperCooldown, "Bẫy");
    parseCategory('guardians', buildersItems, boosts.builderBoost, 9, builderHelperLevel, builderHelperCooldown, "Hộ vệ");
    parseCategory('heroes', buildersItems, boosts.builderBoost, 9, builderHelperLevel, builderHelperCooldown, "Tướng");
    parseCategory('pets', petItems, boosts.petBoost, 23, 0, 0, "Linh thú");
    parseCategory('spells', labItems, boosts.labBoost, 23, labHelperLevel, labHelperCooldown, "Thần chú");
    parseCategory('units', labItems, boosts.labBoost, 23, labHelperLevel, labHelperCooldown, "Lính");
    parseCategory('siege_machines', labItems, boosts.labBoost, 23, labHelperLevel, labHelperCooldown, "Công thành");

    int finalTotalBuilders = buildersItems.length > baseBuilders ? buildersItems.length : baseBuilders;

    return VillageData(
      tag: tag, timestamp: timestamp, totalBuilders: finalTotalBuilders,
      boosts: boosts, buildersItems: buildersItems, petItems: petItems, labItems: labItems,
    );
  }
}
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

    // Lấy thông số Helper (Thợ học việc)
    int builderHelperLevel = 0;
    int labHelperLevel = 0;
    int builderHelperCooldown = 0;
    int labHelperCooldown = 0;
    if (data['helpers'] != null) {
      for (var h in data['helpers']) {
        if (h['data'] == 93000000) { // Thợ xây học việc
          builderHelperLevel = h['lvl'] ?? 0;
          builderHelperCooldown = h['helper_cooldown'] ?? 0;
        }
        if (h['data'] == 93000001) { // Học việc phòng thí nghiệm
          labHelperLevel = h['lvl'] ?? 0;
          labHelperCooldown = h['helper_cooldown'] ?? 0;
        }
      }
    }

    // THUẬT TOÁN ĐÃ ĐƯỢC CẬP NHẬT: Tối ưu khối Nhảy cóc chu kỳ ngày (Fast-forward) + Snacks
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
        // Tối ưu hóa nhảy cóc thời gian (Fast-forward) để xử lý chu kỳ Helper lặp lại
        if (helperRecurrent && currentBoostRemaining <= 0 && currentConsumableRemaining <= 0 && remainingWork > 0) {

          // Bước 1: Nếu Helper đang trong thời gian nghỉ (Cooldown), tua nhanh qua thời gian chờ
          if (currentHelperActiveRemaining <= 0 && currentHelperCooldown > 0) {
            double waitWork = currentHelperCooldown * 1; // Vận tốc lúc nghỉ là 1x
            if (remainingWork <= waitWork) {
              timeElapsed += remainingWork;
              remainingWork = 0;
              break;
            } else {
              timeElapsed += currentHelperCooldown;
              remainingWork -= waitWork;

              // Hết thời gian chờ, Helper bắt đầu làm việc
              currentHelperActiveRemaining = 3600.0;
              currentHelperCooldown = 82800.0; // Tổng vòng đời 1 chu kỳ là 23h (82800 giây)
              continue; // Ép vòng lặp chạy lại từ đầu để tính toán tiến độ làm việc
            }
          }

          // Bước 2: Nhảy cóc nhiều chu kỳ 23 tiếng cùng lúc (Nếu công việc còn rất dài)
          if (currentHelperActiveRemaining == 3600.0 && currentHelperCooldown == 82800.0) {
            // Tổng công việc giải quyết được trong 23 giờ: (1h làm việc + 22h nghỉ)
            double workPerCycle = (3600.0 * (1 + helperLevel)) + (79200.0 * 1);
            if (remainingWork > workPerCycle) {
              int cycles = (remainingWork / workPerCycle).floor();
              timeElapsed += cycles * 82800.0; // Cộng dồn thời gian thực 23 tiếng
              remainingWork -= cycles * workPerCycle; // Trừ đi khối lượng công việc
              continue; // Bắt đầu lại vòng lặp để xử lý phần thời gian lẻ còn lại
            }
          }
        }

        // TÍNH TOÁN BÌNH THƯỜNG TỪNG SỰ KIỆN CHO ĐẾN KHI HẾT VIỆC
        int currentSpeed = 1; // Tốc độ cơ bản x1
        if (currentBoostRemaining > 0) currentSpeed += boostSpeedAdd; // Thuốc Potion
        if (currentConsumableRemaining > 0) currentSpeed += consumableSpeedAdd; // Món ăn Snack
        if (currentHelperActiveRemaining > 0) currentSpeed += helperLevel; // Helper buff riêng lẻ

        double nextEvent = remainingWork / currentSpeed;

        if (currentBoostRemaining > 0 && currentBoostRemaining < nextEvent) nextEvent = currentBoostRemaining;
        if (currentConsumableRemaining > 0 && currentConsumableRemaining < nextEvent) nextEvent = currentConsumableRemaining;
        if (currentHelperActiveRemaining > 0 && currentHelperActiveRemaining < nextEvent) nextEvent = currentHelperActiveRemaining;
        if (helperRecurrent && currentHelperActiveRemaining <= 0 && currentHelperCooldown > 0 && currentHelperCooldown < nextEvent) {
          nextEvent = currentHelperCooldown;
        }

        timeElapsed += nextEvent;
        remainingWork -= nextEvent * currentSpeed;
        currentBoostRemaining -= nextEvent;
        currentConsumableRemaining -= nextEvent;
        currentHelperActiveRemaining -= nextEvent;
        currentHelperCooldown -= nextEvent;

        // Chống sai số float
        if (remainingWork < 0.001) remainingWork = 0;
        if (currentBoostRemaining < 0.001) currentBoostRemaining = 0;
        if (currentConsumableRemaining < 0.001) currentConsumableRemaining = 0;
        if (currentHelperActiveRemaining < 0.001) currentHelperActiveRemaining = 0;
        if (currentHelperCooldown < 0.001) currentHelperCooldown = 0;

        // Reset chu kỳ Helper nếu thời gian tua lẻ vừa hoàn thành cooldown
        if (helperRecurrent && remainingWork > 0 && currentHelperActiveRemaining <= 0 && currentHelperCooldown <= 0) {
          currentHelperActiveRemaining = 3600.0;
          currentHelperCooldown = 82800.0;
        }

        // Nếu không còn bất cứ hiệu ứng nào tác động, tua thẳng đến lúc xong việc
        if (currentBoostRemaining <= 0 && currentConsumableRemaining <= 0 && currentHelperActiveRemaining <= 0 && !helperRecurrent) {
          timeElapsed += remainingWork;
          remainingWork = 0;
          break;
        }
      }
      return DateTime.fromMillisecondsSinceEpoch(timestamp * 1000).add(Duration(seconds: timeElapsed.round()));
    }

    void parseCategory(String key, List<UpgradeItem> targetList, int boostDuration, int boostSpeedAdd, int consumableDuration, int consumableSpeedAdd, int globalHelperLevel, int globalHelperCooldown, String typeName) {
      if (data.containsKey(key)) {
        int index = 0;
        for (var item in data[key]) {
          int timer = item['timer'] ?? 0;
          if (timer > 0) {
            targetList.add(UpgradeItem(
              instanceId: "${tag}_${key}_${item['data']}_${index++}",
              dataId: item['data'] ?? 0, level: item['lvl'] ?? 0, originalTimer: timer, typeString: typeName,
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
        }
      }
    }

    // Các Hạng mục do Thợ Xây đảm nhiệm (Thuốc x10 => speed + 9 | Snack x2 => speed + 1)
    parseCategory('buildings', buildersItems, boosts.builderBoost, 9, boosts.builderConsumable, 1, builderHelperLevel, builderHelperCooldown, "Công trình");
    parseCategory('traps', buildersItems, boosts.builderBoost, 9, boosts.builderConsumable, 1, builderHelperLevel, builderHelperCooldown, "Bẫy");
    parseCategory('guardians', buildersItems, boosts.builderBoost, 9, boosts.builderConsumable, 1, builderHelperLevel, builderHelperCooldown, "Hộ vệ");
    parseCategory('heroes', buildersItems, boosts.builderBoost, 9, boosts.builderConsumable, 1, builderHelperLevel, builderHelperCooldown, "Tướng");

    // Các Hạng mục do Lab/Pet House đảm nhiệm (Thuốc x24 => speed + 23 | Snack x4 => speed + 3)
    parseCategory('pets', petItems, boosts.petBoost, 23, boosts.labConsumable, 3, 0, 0, "Linh thú"); // Linh thú KHÔNG ĐƯỢC hưởng Học việc (level 0, cooldown 0)
    parseCategory('spells', labItems, boosts.labBoost, 23, boosts.labConsumable, 3, labHelperLevel, labHelperCooldown, "Thần chú");
    parseCategory('units', labItems, boosts.labBoost, 23, boosts.labConsumable, 3, labHelperLevel, labHelperCooldown, "Lính");
    parseCategory('siege_machines', labItems, boosts.labBoost, 23, boosts.labConsumable, 3, labHelperLevel, labHelperCooldown, "Công thành");

    int finalTotalBuilders = buildersItems.length > baseBuilders ? buildersItems.length : baseBuilders;

    return VillageData(
      tag: tag, timestamp: timestamp, totalBuilders: finalTotalBuilders,
      boosts: boosts, buildersItems: buildersItems, petItems: petItems, labItems: labItems,
    );
  }
}
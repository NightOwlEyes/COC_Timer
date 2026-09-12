import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';

class CocApiService {

  static const String workerUrl = "https://dry-forest-f702.dohuytruc1922tlh.workers.dev";
  static Future<Map<String, dynamic>?> verifyAndGetClanInfo(String clanTag) async {
    String cleanTag = clanTag.replaceAll('#', '').toUpperCase();

    var clanData = await _fetchEndpoint('/v1/clans/%2523$cleanTag');

    if (clanData.isNotEmpty && clanData.containsKey('name')) {
      return {
        'tag': clanData['tag'],
        'name': clanData['name'],
        'badgeUrl': clanData['badgeUrls'] != null ? clanData['badgeUrls']['small'] : '',
        'clanLevel': clanData['clanLevel'] ?? 1,
      };
    }
    return null;
  }

  static Future<String?> fetchPlayerName(String tag) async {
    String cleanTag = tag.replaceAll('#', '').toUpperCase();

    // Gọi API qua worker với double-encoding dấu # (%2523)
    var playerData = await _fetchEndpoint('/v1/players/%2523$cleanTag');

    if (playerData.isNotEmpty && playerData.containsKey('name')) {
      return playerData['name']?.toString();
    }
    return null;
  }

  /// Hàm điều phối chính: Quyết định gọi API nào trước dựa vào ngày trong tháng
  static Future<Map<String, dynamic>> fetchWarData(String clanTag) async {
    // Tiền xử lý Tag: Đảm bảo Tag chỉ chứa chữ cái và số, không chứa dấu #
    String cleanTag = clanTag.replaceAll('#', '').toUpperCase();

    // Lấy ngày hiện tại
    int currentDay = DateTime.now().day;

    if (currentDay >= 1 && currentDay <= 11) {
      // TỪ NGÀY 1 ĐẾN 11: Ưu tiên quét CWL trước
      debugPrint("API ROUTING: Ngày $currentDay -> Ưu tiên quét CWL (7 Ngày)");

      var cwlResult = await _checkCWL(cleanTag);
      if (cwlResult['type'] == 'CWL') return cwlResult; // Nếu đúng đang CWL -> Trả về luôn

      // Nếu rớt đài (Clan không đăng ký CWL), gọi bù War thường
      debugPrint("API ROUTING: Không có CWL -> Chuyển sang quét War Thường");
      return await _checkRegularWar(cleanTag);

    } else {
      // CÁC NGÀY CÒN LẠI: Ưu tiên quét War Thường trước
      debugPrint("API ROUTING: Ngày $currentDay -> Ưu tiên quét War Thường (2 Ngày)");

      var regularResult = await _checkRegularWar(cleanTag);
      if (regularResult['type'] == 'REGULAR') return regularResult; // Nếu đang War thường -> Trả về luôn

      // Nếu không War thường (hoặc đang nghỉ), vẫn gọi thử CWL (Trường hợp hi hữu giải kéo dài)
      debugPrint("API ROUTING: Không có War Thường -> Quét dự phòng CWL");
      return await _checkCWL(cleanTag);
    }
  }

  /// ==========================================
  /// LUỒNG 1: XỬ LÝ WAR THƯỜNG (2 NGÀY)
  /// ==========================================
  static Future<Map<String, dynamic>> _checkRegularWar(String cleanTag) async {
    // SỬA LỖI: Dùng %2523 để mã hóa kép (Double-encode) dấu # qua mặt Cloudflare
    var currentWar = await _fetchEndpoint('/v1/clans/%2523$cleanTag/currentwar');

    if (currentWar.containsKey('state') &&
        (currentWar['state'] == 'inWar' || currentWar['state'] == 'preparation')) {
      return {
        'type': 'REGULAR',
        'data': currentWar
      };
    }
    return {'type': 'NONE'};
  }

  /// ==========================================
  /// LUỒNG 2: XỬ LÝ CLAN WAR LEAGUE (7 NGÀY)
  /// ==========================================
  static Future<Map<String, dynamic>> _checkCWL(String cleanTag) async {
    // SỬA LỖI: Dùng %2523 để mã hóa kép
    var cwlGroup = await _fetchEndpoint('/v1/clans/%2523$cleanTag/currentwar/leaguegroup');

    // Nếu không có dữ liệu CWL hoặc đã hết mùa giải (state = "notInWar")
    if (cwlGroup.isEmpty || !cwlGroup.containsKey('rounds')) {
      return {'type': 'NONE'};
    }

    // TÁI TẠO LOGIC N8N CỦA BẠN: Gom mảng warTag và gắn nhãn Round (Ngày 1-7)
    List<Map<String, dynamic>> warTagsInfo = [];
    int roundIndex = 1;
    for (var round in cwlGroup['rounds']) {
      for (var tag in round['warTags']) {
        if (tag != '#0') {
          warTagsInfo.add({'tag': tag, 'round': roundIndex});
        }
      }
      roundIndex++;
    }

    // Nếu rỗng (hi hữu)
    if (warTagsInfo.isEmpty) return {'type': 'NONE'};

    // GỌI API ĐỒNG LOẠT LẤY CHI TIẾT TẤT CẢ CÁC TRẬN CÙNG LÚC (SPEED BOOST)
    List<Future<Map<String, dynamic>>> futures = [];
    for (var info in warTagsInfo) {
      String cleanWarTag = info['tag'].replaceAll('#', '');
      // SỬA LỖI: Dùng %2523 để mã hóa kép
      futures.add(_fetchEndpoint('/v1/clanwarleagues/wars/%2523$cleanWarTag').then((data) {
        // QUAN TRỌNG: Gắn thông tin Round vào JSON trả về để giao diện biết đây là ngày thứ mấy
        data['cwl_round'] = info['round'];
        return data;
      }));
    }
    var allWars = await Future.wait(futures);

    // LỌC TRẬN ĐẤU CÓ CLAN CỦA MÌNH
    List<Map<String, dynamic>> myWars = [];
    String myFullTag = "#$cleanTag"; // API trả về tag có dấu #

    for (var war in allWars) {
      if (war.isEmpty) continue;

      if (war.containsKey('clan') && war.containsKey('opponent')) {
        if (war['clan']['tag'] == myFullTag || war['opponent']['tag'] == myFullTag) {
          myWars.add(war);
        }
      }
    }

    // Tìm trận Đang Đánh (Hôm nay) và Trận Chuẩn Bị (Tiên tri ngày mai)
    Map<String, dynamic>? prepWar;
    Map<String, dynamic>? inWar;

    for (var war in myWars) {
      if (war['state'] == 'preparation') {
        prepWar = war;
      } else if (war['state'] == 'inWar') {
        inWar = war;
      }
    }

    // Fallback: Ngày cuối cùng của CWL sẽ không có prepWar
    if (prepWar == null && inWar == null && myWars.isNotEmpty) {
      myWars.sort((a, b) => DateTime.parse(b['startTime']).compareTo(DateTime.parse(a['startTime'])));
    }

    return {
      'type': 'CWL',
      'currentWar': inWar,
      'upcomingWar': prepWar,
      'allWars': myWars,
      'allGroupWars': allWars, // THÊM DÒNG NÀY: Truyền toàn bộ 28 trận của Group
      'groupData': cwlGroup
    };
  }

  /// ==========================================
  /// HÀM GỌI CLOUDFLARE WORKER (XỬ LÝ URL ENCODING)
  /// ==========================================
  static Future<Map<String, dynamic>> _fetchEndpoint(String endpointPath) async {
    try {
      // Cách ghép URL thủ công để tránh lỗi Dart tự động Double-Encode dấu %
      final String finalUrl = "$workerUrl?endpoint=$endpointPath";
      final response = await http.get(Uri.parse(finalUrl));

      // KIỂM TRA TRẠNG THÁI BẢO TRÌ CỦA SUPERCELL
      if (response.statusCode == 503 || response.body.contains("inMaintenance")) {
        throw "GAME ĐANG BẢO TRÌ!";
      }

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      } else {
        debugPrint("API Error [${response.statusCode}]: ${response.body}");
        return {}; // Trả về rỗng nếu Clan ẩn lịch sử War hoặc lỗi cấu hình
      }
    } catch (e) {
      // Nếu là lỗi bảo trì đã bắt ở trên thì ném thẳng lên giao diện UI
      if (e.toString().contains("BẢO TRÌ")) {
        rethrow;
      }
      debugPrint("Network Error: $e");
      return {};
    }
  }
}

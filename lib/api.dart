import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:intl/intl.dart';

Map<String, dynamic>? globalSchedulerData;

Future<Map<String, dynamic>> validateCompanyLogin(
    String username, String password) async {
  final url =
      Uri.parse('https://www.alfadock-pack.com/api/users/ValidateCompLogin');
  final response = await http.post(
    url,
    body: {
      'name': username,
      'pwd': password,
    },
  );

  if (response.statusCode == 200) {
    return json.decode(response.body);
  } else {
    throw Exception('Failed to validate company login: ${response.statusCode}');
  }
}

Future<Map<String, dynamic>> validateUserLogin(
    String username, String password, int userId) async {
  final url =
      Uri.parse('https://www.alfadock-pack.com/api/users/ValidateLogin');
  final response = await http.post(
    url,
    body: {
      'username': username,
      'password': password,
      'compId': userId.toString(),
    },
  );

  if (response.statusCode == 200) {
    print('company login response $response');
    return json.decode(response.body);
  } else {
    throw Exception('Failed to validate user login: ${response.statusCode}');
  }
}

Future<String?> getUrlLink(String compId, String appName) async {
  final url = Uri.parse('https://www.alfadock-pack.com/api/AppLink/GetUrlLink');
  final response = await http.post(
    url,
    body: {
      'compid': compId,
      'appname': appName,
    },
  );
  print('GetUrlLink API called: compid=$compId, appname=$appName');
  if (response.statusCode == 200) {
    final List<dynamic> data = json.decode(response.body);
    if (data.isNotEmpty) {
      final Map<String, dynamic> firstItem = data[0];
      final String? appsettings = firstItem['url_appsettings'];
      if (appsettings != null) {
        final Map<String, dynamic> settings = jsonDecode(appsettings);
        print(settings['erpurlbase']);
        return settings['erpurlbase'] as String?;
      } else {
        print('Using AlfaDOCK base: https://www.alfadock-pack.com');
        return 'https://www.alfadock-pack.com';
      }
    }
    return null;
  } else {
    return 'https://www.alfadock-pack.com';
  }
}

Future<List<Map<String, dynamic>>> getProcessFromUserID(String userId) async {
  final url = Uri.parse(
      'https://www.alfadock-pack.com/api/SiSchedulerApiProcess/getProcessFromUserID');
  final response = await http.post(
    url,
    body: {
      'userid': userId,
    },
  );

  if (response.statusCode == 200) {
    return List<Map<String, dynamic>>.from(json.decode(response.body));
  } else {
    throw Exception('Failed to get process list: ${response.statusCode}');
  }
}

Future<Map<String, dynamic>> getAlfaERPProcessListGet(
    String erpUrlBase, String key, String ds, String de, String userId) async {
  print(erpUrlBase);
  final storage = FlutterSecureStorage();

  if (erpUrlBase == "https://www.alfadock-pack.com") {
    final previousDaysTimestamp =
        await storage.read(key: 'previousDaysTimestamp');
    final nextDaysTimestamp = await storage.read(key: 'nextDaysTimestamp');
    // Parse timestamps or fallback to yesterday/tomorrow
    final now = DateTime.now();
    final yesterday = now.subtract(Duration(days: 1));
    final tomorrow = now.add(Duration(days: 1));

    // Format ds and de as yyyyMMdd
    ds = previousDaysTimestamp != null
        ? DateFormat('yyyyMMdd').format(DateTime.parse(previousDaysTimestamp))
        : DateFormat('yyyyMMdd').format(yesterday);
    de = nextDaysTimestamp != null
        ? DateFormat('yyyyMMdd').format(DateTime.parse(nextDaysTimestamp))
        : DateFormat('yyyyMMdd').format(tomorrow);
    // ds = "20250730";
    // de = "20250830";
    print("dock $ds and $de");

    print('Using new API for Alfa ERP process list');

    final url = Uri.parse('https://www.alfadock-pack.com/api/plugin');

    final argsJson =
        "{'userid':'$userId','fromDate':'$ds','toDate':'$de','status':[0,1,2,3,4]}";

    print('Using new API for Alfa ERP process $argsJson list');

    final request = http.MultipartRequest('POST', url);
    request.fields['plugin'] = 'SchedulerApi';
    request.fields['controller'] = 'SchedulerIOSController';
    request.fields['action'] = 'getAllProcessesWithMultiSearch';
    request.fields['args'] = argsJson;

    print('FormData POST: $url');
    print('FormData fields: ${request.fields}');
    print('argsJson: $argsJson');

    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode == 200) {
      print('API Response: ${response.body}');
      return json.decode(response.body);
    } else {
      print('Error Status: ${response.statusCode}');
      print('Error Body: ${response.body}');
      throw Exception('Failed to get process list');
    }
  } else {
    final now = DateTime.now();
    final yesterday = now.subtract(Duration(days: 1));
    final tomorrow = now.add(Duration(days: 1));
    final previousDaysTimestamp =
        await storage.read(key: 'previousDaysTimestamp');
    final nextDaysTimestamp = await storage.read(key: 'nextDaysTimestamp');

    // Format ds and de as yyyyMMdd
    ds = previousDaysTimestamp != null
        ? DateFormat('yyyy-MM-dd').format(DateTime.parse(previousDaysTimestamp))
        : DateFormat('yyyy-MM-dd').format(yesterday);
    de = nextDaysTimestamp != null
        ? DateFormat('yyyy-MM-dd').format(DateTime.parse(nextDaysTimestamp))
        : DateFormat('yyyy-MM-dd').format(tomorrow);
    print("erp $ds and $de");
    // ds = '2025-08-24';
    // de = '2025-09-14';

    print('Fetching Alfa ERP process Api');

    final url = Uri.parse(
        'https://$erpUrlBase.alfa-erp.com/api/get_alfaerp_data/PROCESSLIST?key=$key&ds=$ds&de=$de');

    print('URL: $url');

    final response = await http.get(url);

    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception(
          'Failed to get Alfa ERP process list (GET): ${response.statusCode}');
    }
  }
}

Future<Map<String, dynamic>> getAlfaERPProcessListGetfromSearch(
    String erpUrlBase,
    String key,
    String ds,
    String de,
    String sv,
    String opd) async {
  print('Fetching Alfa ERP process Api');
  final url = Uri.parse(
      'https://$erpUrlBase.alfa-erp.com/api/get_alfaerp_data/PROCESSLIST?key=$key&ds=$ds&de=$de&sv=$sv&opd=$opd');
  print('URL: $url');
  final response = await http.get(url);

  if (response.statusCode == 200) {
    print("response.body: ${response.body}");
    return json.decode(response.body);
  } else {
    throw Exception(
        'Failed to get Alfa ERP process list (GET): ${response.statusCode}');
  }
}

Future<Map<String, dynamic>> submitProcessStatus({
  required int pid,
  required String erpUrlBase,
  required String userId,
}) async {
  if (erpUrlBase == "https://www.alfadock-pack.com") {
    print('Using new API for Alfa ERP process list');
    final url = Uri.parse('https://www.alfadock-pack.com/api/plugin');

    // Prepare args as a raw JSON string
    final argsJson = "{'processid':'$pid'}";

    print('Using new API for Alfa ERP process $argsJson list');

    final request = http.MultipartRequest('POST', url);
    request.fields['plugin'] = 'SchedulerApi';
    request.fields['controller'] = 'SchedulerIOSController';
    request.fields['action'] = 'getProcess';
    request.fields['args'] = argsJson;

    print('FormData POST: $url');
    print('FormData fields: ${request.fields}');

    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);
    final dynamic data = json.decode(response.body);
    print('SISUBMITPROCESS response: $data');

    if (data is List<dynamic> && data.isNotEmpty) {
      return data[0] as Map<String, dynamic>;
    } else if (data is Map<String, dynamic>) {
      return data;
    } else {
      return {'records': [], 'totalRecords': 0};
    }
  } else {
    String key = "sfGa0kl7lO9fXWaE1rENp";
    String sp = "1";
    final url = Uri.parse(
        'https://$erpUrlBase.alfa-erp.com/api/get_alfaerp_data/SISUBMITPROCESS?key=$key&pid=$pid&sp=$sp');
    print('Calling SISUBMITPROCESS API asd: $url');
    final response = await http.get(url);
    print(url);
    if (response.statusCode == 200) {
      final dynamic data = json.decode(response.body);
      print('SISUBMITPROCESS response: $data');
      if (data is List<dynamic> && data.isNotEmpty) {
        return data[0] as Map<String, dynamic>;
      } else if (data is Map<String, dynamic>) {
        return data;
      } else {
        return {'records': [], 'totalRecords': 0};
      }
    } else {
      throw Exception('Failed to submit process: ${response.statusCode}');
    }
  }
}

Future<Map<String, dynamic>> getspdetails({
  required int sid,
  required String erpUrlBase,
  required String userId,
}) async {
  if (erpUrlBase == "https://www.alfadock-pack.com") {
    print('Using new API for Alfa ERP process list');
    final url = Uri.parse('https://www.alfadock-pack.com/api/plugin');

    // Prepare args as a raw JSON string
    final argsJson = "{'spId':'$sid'}";

    print('Using new API for Alfa ERP process $argsJson list');

    final request = http.MultipartRequest('POST', url);
    request.fields['plugin'] = 'SchedulerApi';
    request.fields['controller'] = 'SchedulerSubmitProcessController';
    request.fields['action'] = 'getSPDurationBeforeResume';
    request.fields['args'] = argsJson;

    print('FormData POST: $url');
    print('FormData fields: ${request.fields}');

    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);
    final dynamic data = json.decode(response.body);
    print('SISUBMITPROCESS response: $data');
    if (data is List<dynamic> && data.isNotEmpty) {
      return data[0] as Map<String, dynamic>;
    } else if (data is Map<String, dynamic>) {
      return data;
    } else {
      return {'records': [], 'totalRecords': 0};
    }
  } else {
    String key = "sfGa0kl7lO9fXWaE1rENp";
    String sp = "1";
    final url = Uri.parse(
        'https://$erpUrlBase.alfa-erp.com/api/get_alfaerp_data/SISUBMITPROCESS?key=$key&pid=$sid&sp=$sp');
    print('Calling SISUBMITPROCESS API: $url');
    final response = await http.get(url);
    print(url);
    if (response.statusCode == 200) {
      final dynamic data = json.decode(response.body);
      print('SISUBMITPROCESS response: $data');
      if (data is List<dynamic> && data.isNotEmpty) {
        return data[0] as Map<String, dynamic>;
      } else if (data is Map<String, dynamic>) {
        return data;
      } else {
        return {'records': [], 'totalRecords': 0};
      }
    } else {
      throw Exception('Failed to submit process: ${response.statusCode}');
    }
  }
}

Future<Map<String, dynamic>> cancelprocess({
  required String pid,
  required String erpUrlBase,
  required String userId,
  required String id,
}) async {
  if (erpUrlBase == "https://www.alfadock-pack.com") {
    print('Using new API for Alfa ERP process list');
    final url = Uri.parse('https://www.alfadock-pack.com/api/plugin');

    // Prepare args as a raw JSON string
    final argsJson = "{'id':'$id','processId':'$pid'}";

    print('Using new API for Alfa ERP process $argsJson list');

    final request = http.MultipartRequest('POST', url);
    request.fields['plugin'] = 'SchedulerApi';
    request.fields['controller'] = 'SchedulerIOSController';
    request.fields['action'] = 'undoLastSPOperation';
    request.fields['args'] = argsJson;

    print('FormData POST: $url');
    print('FormData fields: ${request.fields}');

    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);
    final dynamic data = json.decode(response.body);
    print('SISUBMITPROCESS response: $data');
    if (data is List<dynamic> && data.isNotEmpty) {
      return data[0] as Map<String, dynamic>;
    } else if (data is Map<String, dynamic>) {
      return data;
    } else {
      return {'records': [], 'totalRecords': 0};
    }
  } else {
    String key = "7aBNl26gf0yaxEDrFJpE";

    final url = Uri.parse(
        'https://$erpUrlBase.alfa-erp.com/api/set_alfaerp_data/UNDOLASTSPOPERATION?key=$key&processId=$pid');
    print('Calling SISUBMITPROCESS API: $url');
    final response = await http.get(url);
    print(url);
    if (response.statusCode == 200) {
      final dynamic data = json.decode(response.body);
      print('SISUBMITPROCESS response: $data');
      if (data is List<dynamic> && data.isNotEmpty) {
        return data[0] as Map<String, dynamic>;
      } else if (data is Map<String, dynamic>) {
        return data;
      } else {
        return {'records': [], 'totalRecords': 0};
      }
    } else {
      throw Exception('Failed to submit process: ${response.statusCode}');
    }
  }
}

Future<Map<String, dynamic>> updateProcessUsers({
  required int pid,
  required String erpUrlBase,
  required String id,
  required String name,
  required String qty,
  required List<Map<String, dynamic>> users,
  required String userId,
  required Map<int, String> userIdNameMap,
  required List<String> rawusers,
  required Map<int, String> userIdToStaffNameMap,
}) async {
  print(erpUrlBase);
  print('Updating process users for PID: $pid, ID: $id');

  if (erpUrlBase == "https://www.alfadock-pack.com") {
    final url = Uri.parse('https://www.alfadock-pack.com/api/plugin');
    print('name: $rawusers');

    // Match usernames with their IDs
    // List<int> matchedUserIds = userIdNameMap.entries
    //     .where((entry) => rawusers.contains(entry.value))
    //     .map((entry) => entry.key)
    //     .toList();
    // if (matchedUserIds.isEmpty) {
    //   matchedUserIds = userIdToStaffNameMap.entries
    //       .where((entry) => rawusers.contains(entry.value))
    //       .map((entry) => entry.key)
    //       .toList();
    // }
    List<int> matchedUserIds = [];

    for (String name in rawusers) {
      // Try matching from userIdNameMap
      final nameMatch = userIdNameMap.entries.firstWhere(
        (entry) => entry.value == name,
        orElse: () => const MapEntry(-1, ''),
      );

      if (nameMatch.key != -1) {
        matchedUserIds.add(nameMatch.key);
      } else {
        // Fallback to userIdToStaffNameMap
        final staffMatch = userIdToStaffNameMap.entries.firstWhere(
          (entry) => entry.value == name,
          orElse: () => const MapEntry(-1, ''),
        );

        if (staffMatch.key != -1) {
          matchedUserIds.add(staffMatch.key);
        }
      }
    }

    print('Matched user IDs: $matchedUserIds');

    // Track last successful or failed response
    Map<String, dynamic> finalResponse = {};

    for (int uid in matchedUserIds) {
      final argsJson = json.encode({
        'submitProcessId': id,
        'userId': uid.toString(),
      });

      final body = {
        'plugin': 'SchedulerApi',
        'controller': 'SchedulerIOSController',
        'action': 'addUserToSubmitProcess',
        'args': argsJson,
      };

      final headers = {
        'Content-Type': 'application/x-www-form-urlencoded',
      };

      final response = await http.post(url, headers: headers, body: body);

      if (response.statusCode == 200) {
        final dynamic data = json.decode(response.body);
        print('User ID $uid Update response: $data');

        if (data is Map<String, dynamic>) {
          if (data['status'] == 'success') {
            finalResponse = data;
          } else {
            print(
                'Failed to update user ID $uid: ${data['message'] ?? 'Unknown'}');
          }
        } else {
          print('Unexpected format for user ID $uid: $data');
        }
      } else {
        print('HTTP error for user ID $uid: ${response.statusCode}');
      }
    }

    // Return the last successful (or any) response
    return finalResponse.isNotEmpty
        ? finalResponse
        : {'status': 'failure', 'message': 'No users updated successfully'};
  } else {
    // Non-AlfaDock ERP flow
    const key = "7aBNl26gf0yaxEDrFJpE";
    final rawUsers = jsonEncode(users);

    final urlString =
        'https://$erpUrlBase.alfa-erp.com/api/set_alfaerp_data/SISUBMITPROCESS?key=$key&id=$id&parent_id=$pid&name=$name&qty=$qty&users=$rawUsers';

    print('Calling SISUBMITPROCESS Users Update API: $urlString');
    final response = await http.get(Uri.parse(urlString));

    if (response.statusCode == 200) {
      final dynamic data = json.decode(response.body);

      if (data is Map<String, dynamic>) {
        if (data['status'] == 'success') {
          if (data.containsKey('submitProcessList') &&
              data['submitProcessList'] is List &&
              data['submitProcessList'].isNotEmpty) {
            return data['submitProcessList'][0] as Map<String, dynamic>;
          }
          return data;
        } else if (data['status'] == 'failure') {
          throw Exception(
              'API failed to update users: ${data['message'] ?? 'Unknown error'}');
        } else if (data.containsKey('success') && data['success'] == true) {
          return data;
        } else if (data.containsKey('records') &&
            data['records'] is List &&
            data['records'].isNotEmpty) {
          return data['records'][0] as Map<String, dynamic>;
        }
      } else if (data is List<dynamic> &&
          data.isNotEmpty &&
          data[0] is Map<String, dynamic>) {
        return data[0] as Map<String, dynamic>;
      }

      print('Unexpected response format: $data');
      throw Exception('Unexpected API response format');
    } else {
      throw Exception('Failed to update users: ${response.statusCode}');
    }
  }
}

Future<Map<String, dynamic>> removeUserApi({
  required String processName,
  required String user,
  required Map<String, int> userNameToRecordIdMap,
  required Map<int, int> numberInNameToIdMap,
}) async {
  print("Removing user: $user from process: $processName");
  print('numberInNameToIdMap: $numberInNameToIdMap');
  print('userNameToRecordIdMap: $userNameToRecordIdMap');
  int? userId = userNameToRecordIdMap[user];
  print('userid $userId');
  int? processNumber =
      int.tryParse(processName.replaceAll(RegExp(r'[^0-9]'), ''));
  int? submitProcessId = numberInNameToIdMap[processNumber ?? -1];
  print('submitProcessId: $submitProcessId');
  if (userId == null) {
    return {
      'status': 'failure',
      'message': 'User ID not found for $user',
    };
  }

  final url = Uri.parse('https://www.alfadock-pack.com/api/plugin');
  final argsJson = json.encode({
    'submitProcessId': submitProcessId.toString(),
    'recordId': userId.toString(),
  });

  final body = {
    'plugin': 'SchedulerApi',
    'controller': 'SchedulerIOSController',
    'action': 'deleteUserFromSubmitProcess',
    'args': argsJson,
  };

  final headers = {
    'Content-Type': 'application/x-www-form-urlencoded',
  };

  final response = await http.post(url, headers: headers, body: body);

  if (response.statusCode == 200) {
    final data = json.decode(response.body);
    print('Remove User Response: $data');
    return data;
  }
  return {
    'status': 'failure',
    'message': 'HTTP error: ${response.statusCode}',
  };
}

Future<Map<String, dynamic>> startProcess({
  required int pid,
  required String erpUrlBase,
  required String id,
  required String name,
  required String qty,
  required List<Map<String, dynamic>> users,
  required String status,
  required String plannedStartDate,
  required String defectQty,
  required String defectReason,
  required String defectCodeId,
}) async {
  String key = "7aBNl26gf0yaxEDrFJpE";
  String plannedEndDate = "";

  int statusCode;
  if (status == "pending" || status == "ready") {
    statusCode = 0;
  } else if (status == "progress") {
    statusCode = 1;
  } else if (status == "resume") {
    statusCode = 3;
  } else if (status == "done") {
    statusCode = 4;
  } else if (status == "pause") {
    statusCode = 2;
  } else {
    statusCode = 5;
  }
  print('start date $plannedStartDate');
  String formattedDate = '';
  if (plannedStartDate.trim().isNotEmpty) {
    DateFormat inputFormat = DateFormat("MM/dd/yy hh:mm:ss a");
    DateTime parsedDate;
    try {
      parsedDate = inputFormat.parse(plannedStartDate);
      formattedDate = DateFormat("MM/dd/yyyy").format(parsedDate);
    } catch (e) {
      print('Error parsing plannedStartDate Start: $e');
      formattedDate = ''; // send empty if parsing fails
    }
  } else {
    formattedDate = ''; // send empty if null or blank
  }

  print('formatdate $formattedDate');
  final rawUsers = jsonEncode(users);
  // Manually construct URL to avoid automatic encoding
  print('Raw users: $rawUsers');
  final urlString =
      'https://$erpUrlBase.alfa-erp.com/api/set_alfaerp_data/SISUBMITPROCESS?key=$key&id=$id&parent_id=$pid&status=$statusCode&planned_start=$formattedDate&planned_end=$plannedEndDate&name=$name&qty=$qty&defect_qty=$defectQty&defect_reason=$defectReason&defect_code_id=$defectCodeId&users=$rawUsers';
  print('Calling SISUBMITPROCESS API start: $urlString');
  final response = await http.get(Uri.parse(urlString));
  print('Raw SISUBMITPROCESS response: ${response.body}');

  if (response.statusCode == 200) {
    final dynamic data = json.decode(response.body);
    if (data is Map<String, dynamic>) {
      if (data['status'] == 'success') {
        if (data.containsKey('submitProcessList') &&
            data['submitProcessList'] is List &&
            data['submitProcessList'].isNotEmpty) {
          return data['submitProcessList'][0] as Map<String, dynamic>;
        }
        return data;
      } else if (data['status'] == 'failure') {
        throw Exception(
            'API failed to update process status: ${data['message'] ?? 'Unknown error'}');
      } else if (data.containsKey('success') && data['success'] == true) {
        return data;
      } else if (data.containsKey('records') &&
          data['records'] is List &&
          data['records'].isNotEmpty) {
        return data['records'][0] as Map<String, dynamic>;
      }
    } else if (data is List<dynamic> &&
        data.isNotEmpty &&
        data[0] is Map<String, dynamic>) {
      return data[0] as Map<String, dynamic>;
    }
    print('Unexpected response format: $data');
    throw Exception('Unexpected API response format');
  } else {
    throw Exception('Failed to update process status: ${response.statusCode}');
  }
}

Future<Map<String, dynamic>> stopProcess({
  required int pid,
  required String erpUrlBase,
  required String id,
  required String name,
  required String qty,
  required List<Map<String, dynamic>> users,
  required String status,
  required String plannedStartDate,
  required String defectQty,
  required String defectReason,
  required String defectCodeId,
}) async {
  String key = "7aBNl26gf0yaxEDrFJpE";
  String plannedEndDate = "";

  int statusCode;
  if (status == "pending" || status == "ready") {
    statusCode = 0;
  } else if (status == "progress") {
    statusCode = 1;
  } else if (status == "resume") {
    statusCode = 3;
  } else if (status == "done") {
    statusCode = 4;
  } else if (status == "pause") {
    statusCode = 2;
  } else {
    statusCode = 5;
  }

  DateFormat inputFormat = DateFormat("MM/dd/yy hh:mm:ss a");
  DateTime parsedDate;
  try {
    parsedDate = inputFormat.parse(plannedStartDate);
    // print(parsedDate);
  } catch (e) {
    print('Error parsing plannedStartDate Start: $e');
    parsedDate = DateTime.now();
  }
  DateFormat outputFormat = DateFormat("MM/dd/yyyy");
  String formattedDate = outputFormat.format(parsedDate);
  // print('formatdate $formattedDate');

  final rawUsers = jsonEncode(users);
  // Manually construct URL to avoid automatic encoding
  print('Raw users: $rawUsers');
  final urlString =
      'https://$erpUrlBase.alfa-erp.com/api/set_alfaerp_data/SISUBMITPROCESS?key=$key&id=$id&parent_id=$pid&status=$statusCode&planned_start=$formattedDate&planned_end=$plannedEndDate&name=$name&qty=$qty&defect_qty=$defectQty&defect_reason=$defectReason&defect_code_id=$defectCodeId&users=$rawUsers';
  print('Calling SISUBMITPROCESS API start1: $urlString');
  final response = await http.get(Uri.parse(urlString));
  print('Raw SISUBMITPROCESS response: ${response.body}');
  statusCode = 4;
  final urlString1 =
      'https://$erpUrlBase.alfa-erp.com/api/set_alfaerp_data/SISUBMITPROCESS?key=$key&id=$id&parent_id=$pid&status=$statusCode&planned_start=$formattedDate&planned_end=$plannedEndDate&name=$name&qty=$qty&defect_qty=$defectQty&defect_reason=$defectReason&defect_code_id=$defectCodeId&users=$rawUsers';
  print('Calling SISUBMITPROCESS API start2: $urlString');
  final response1 = await http.get(Uri.parse(urlString1));
  print('Raw SISUBMITPROCESS response: ${response.body}');

  if (response.statusCode == 200) {
    final dynamic data = json.decode(response1.body);
    if (data is Map<String, dynamic>) {
      if (data['status'] == 'success') {
        if (data.containsKey('submitProcessList') &&
            data['submitProcessList'] is List &&
            data['submitProcessList'].isNotEmpty) {
          return data['submitProcessList'][0] as Map<String, dynamic>;
        }
        return data;
      } else if (data['status'] == 'failure') {
        throw Exception(
            'API failed to update process status: ${data['message'] ?? 'Unknown error'}');
      } else if (data.containsKey('success') && data['success'] == true) {
        return data;
      } else if (data.containsKey('records') &&
          data['records'] is List &&
          data['records'].isNotEmpty) {
        return data['records'][0] as Map<String, dynamic>;
      }
    } else if (data is List<dynamic> &&
        data.isNotEmpty &&
        data[0] is Map<String, dynamic>) {
      return data[0] as Map<String, dynamic>;
    }
    print('Unexpected response format: $data');
    throw Exception('Unexpected API response format');
  } else {
    throw Exception('Failed to update process status: ${response.statusCode}');
  }
}

Future<Map<String, dynamic>> updateProcessQuantity({
  required int pid,
  required String erpUrlBase,
  required String id,
  required String name,
  required String qty,
  required List<Map<String, dynamic>> users,
  required String defectQty,
  required String defectReason,
  required String defectCodeId,
  required String plannedStartDate,
}) async {
  String key = "7aBNl26gf0yaxEDrFJpE";
  String plannedEndDate = "";
  print('Input plannedStartDate: $plannedStartDate');

  DateTime parsedDate;
  try {
    if (plannedStartDate.isEmpty) {
      throw FormatException('plannedStartDate is null or empty');
    }
    parsedDate =
        DateTime.parse(plannedStartDate); // Handles yyyy-MM-dd HH:mm:ss
    print('Parsed DateTime: $parsedDate');
  } catch (e) {
    print('Error parsing plannedStartDate: $e');
    parsedDate = DateTime.now();
    print('Falling back to current date: $parsedDate');
  }
  String formattedDate =
      DateFormat("MM/dd/yyyy").format(parsedDate); // Format to MM/dd/yyyy

  final rawUsers = jsonEncode(users);
  // Manually construct URL to avoid automatic encoding
  final urlString =
      'https://$erpUrlBase.alfa-erp.com/api/set_alfaerp_data/SISUBMITPROCESS?key=$key&id=$id&parent_id=$pid&name=$name&qty=$qty&defect_qty=$defectQty&defect_reason=$defectReason&defect_code_id=$defectCodeId&users=$rawUsers&planned_start=$formattedDate&planned_end=$plannedEndDate';
  print('Calling SISUBMITPROCESS Quantity Update API: $urlString');
  final response = await http.get(Uri.parse(urlString));
  print('Raw SISUBMITPROCESS Quantity Update response: ${response.body}');

  if (response.statusCode == 200) {
    final dynamic data = json.decode(response.body);
    if (data is Map<String, dynamic>) {
      if (data['status'] == 'success') {
        if (data.containsKey('submitProcessList') &&
            data['submitProcessList'] is List &&
            data['submitProcessList'].isNotEmpty) {
          return data['submitProcessList'][0] as Map<String, dynamic>;
        }
        return data;
      } else if (data['status'] == 'failure') {
        throw Exception(
            'API failed to update quantities: ${data['message'] ?? 'Unknown error'}');
      } else if (data.containsKey('success') && data['success'] == true) {
        return data;
      } else if (data.containsKey('records') &&
          data['records'] is List &&
          data['records'].isNotEmpty) {
        return data['records'][0] as Map<String, dynamic>;
      }
    } else if (data is List<dynamic> &&
        data.isNotEmpty &&
        data[0] is Map<String, dynamic>) {
      return data[0] as Map<String, dynamic>;
    }
    print('Unexpected response format: $data');
    throw Exception('Unexpected API response format');
  } else {
    throw Exception('Failed to update quantities: ${response.statusCode}');
  }
}

Map<String, String> mapping = {};
Future<Map<String, dynamic>> fetchSchedulerSettings(
    String erpUrlBase, String compId) async {
  print('erp $erpUrlBase');
  if (erpUrlBase == "https://www.alfadock-pack.com") {
    print('Fetching user options for AlfaDock: $erpUrlBase');
    final url =
        Uri.parse('https://www.alfadock-pack.com/api/Users/GetUsersForCompany');

    print('Fetching SCHEDULER settings API jana: $url');
    final request = http.MultipartRequest('POST', url);
    request.fields['compid'] = compId;
    print('compid: $compId');
    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);
    print('URL: $url');
    if (response.statusCode == 200) {
      final dynamic data = json.decode(response.body);
      print('User options response: $data');
      if (data is List<dynamic>) {
        final userOptionsList =
            data.map((user) => user['UserName'] as String).toList();
        final staffOptionsList = data.map((user) {
          final staffname = user['staffname']?.toString().trim();
          final username = user['UserName']?.toString().trim();

          return (staffname != null && staffname.isNotEmpty)
              ? staffname
              : username;
        }).toList();
        print('User options list api: $userOptionsList');
        var userStaffNameMap;
        return {
          'operators': [],
          'userOptions': userOptionsList,
          'machines': [],
          'assemblyTypes': [],
          'defect_codes': [],
          'rawResponse': data,
          'staffOptions': staffOptionsList,
          'userStaffNameMap': userStaffNameMap,
        };
      } else {
        print("erreeszzff");
        throw Exception('Unexpected API response format for user options');
      }
    } else {
      print('Failed to fetch user options: ${response.statusCode}');
      throw Exception('Failed to fetch user options: ${response.statusCode}');
    }
  } else {
    final url = Uri.parse(
        'https://$erpUrlBase.alfa-erp.com/api/get_alfaerp_settings/SCHEDULER?key=56ACtlLKKf8LasERZPyf&factory=hq');
    print('Fetching SCHEDULER settings API asa: $url');
    final erp = await http.get(url);
    var erpData = jsonDecode(erp.body);
    globalSchedulerData = erpData;

    print('URL: $url');
    print('Fetching user options for AlfaDock: $erpUrlBase');
    final url1 =
        Uri.parse('https://www.alfadock-pack.com/api/Users/GetUsersForCompany');

    print('Fetching SCHEDULER settings APIsd: $url1');
    final request = http.MultipartRequest('POST', url1);
    request.fields['compid'] = '847';
    print('compid: $compId');
    final streamedResponse = await request.send();
    final dock = await http.Response.fromStream(streamedResponse);
    var dockData = jsonDecode(dock.body);
    print('erp ${erpData}');
    print('dock ${dockData}');
    print('URL: $url');
    if (erpData is Map && erpData['operators'] is List) {
      List<dynamic> processTypes = erpData['operators'];
      print(processTypes);

      if (dockData is List) {
        for (var erpItem in processTypes) {
          String erpName = erpItem['name'] ?? '';
          // print(erpName);

          // Find match in dock data
          var dockMatch = dockData.firstWhere(
            (d) =>
                d['UserName'] == erpName &&
                (d['staffname'] != null &&
                    d['staffname'].toString().trim().isNotEmpty),
            orElse: () => {},
          );

          if (dockMatch.isNotEmpty) {
            // Found matching username with non-empty staffname
            mapping[erpName] = dockMatch['staffname'];
          } else {
            // No match → use ERP name itself
            mapping[erpName] = erpName;
          }
        }
      } else {
        print("⚠ dockData is not a list. Received: $dockData");
      }
    }

    print('mapp $mapping');
    if (erp.statusCode == 200) {
      final dynamic data = json.decode(erp.body);
      print('Scheduler settings response: $data');
      if (data is Map<String, dynamic>) {
        return {
          'mapping': mapping,
          'data': data,
        };
      } else {
        throw Exception('Unexpected API response format');
      }
    } else {
      throw Exception('Failed to fetch scheduler settings: ${erp.statusCode}');
    }
  }
}

Future<Map<String, dynamic>> updateProcessMachine({
  required String erpUrlBase,
  required String id,
  required Map<String, dynamic> machine,
  required String processName,
  required String orderNumber,
  required String productNumber,
}) async {
  String key = "7aBNl26gf0yaxEDrFJpE";
  final rawMachine = '[${jsonEncode(machine)}]';
  print('Raw machine data: $rawMachine');
  final urlString =
      'https://$erpUrlBase.alfa-erp.com/api/set_alfaerp_data/SIPROCESS?key=$key&id=$id&machine_id=$rawMachine&method=name&process_name=$processName&order_number=$orderNumber&product_number=$productNumber';
  print('Calling SIPROCESS Machine Update API: $urlString');
  final response = await http.get(Uri.parse(urlString));

  if (response.statusCode == 200) {
    final dynamic data = json.decode(response.body);
    if (data is Map<String, dynamic>) {
      if (data['status'] == 'success') {
        if (data.containsKey('submitProcessList') &&
            data['submitProcessList'] is List &&
            data['submitProcessList'].isNotEmpty) {
          return data['submitProcessList'][0] as Map<String, dynamic>;
        }
        return data;
      } else if (data['status'] == 'failure') {
        throw Exception(
            'API failed to update machine: ${data['message'] ?? 'Unknown error'}');
      } else if (data.containsKey('success') && data['success'] == true) {
        return data;
      } else if (data.containsKey('records') &&
          data['records'] is List &&
          data['records'].isNotEmpty) {
        return data['records'][0] as Map<String, dynamic>;
      }
    } else if (data is List<dynamic> &&
        data.isNotEmpty &&
        data[0] is Map<String, dynamic>) {
      return data[0] as Map<String, dynamic>;
    }
    print('Unexpected response format: $data');
    throw Exception('Unexpected API response format');
  } else {
    throw Exception('Failed to update machine: ${response.statusCode}');
  }
}

Future<dynamic> getFolderIdByFolderName(String compId, String folderName,
    String erpbase, String pid, String userId) async {
  print(compId);
  print('jana');
  print(folderName);

  if (erpbase == "https://www.alfadock-pack.com") {
    // ds = "20250730";
    // de = "20250830";

    print('Using new API for Alfa ERP process list');

    final url = Uri.parse('https://www.alfadock-pack.com/api/plugin');

    final argsJson = "{'processid':'$pid'}";

    print('Using new API for Alfa ERP process $argsJson list');

    final request = http.MultipartRequest('POST', url);
    request.fields['plugin'] = 'SchedulerApi';
    request.fields['controller'] = 'SchedulerIOSController';
    request.fields['action'] = 'getProcess';
    request.fields['args'] = argsJson;

    print('FormData POST: $url');
    print('FormData fields: ${request.fields}');
    print('argsJson pid: $argsJson');

    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode == 200) {
      print('API Responsedock: ${response.body}');
      final output = json.decode(response.body);
      final drawingFileId = output['value']?['drawingFileId'] ?? "0";
      print('Drawing File ID: $drawingFileId');
      final url =
          Uri.parse('https://www.alfadock-pack.com/api/file/getFolderID');
      final responsefile = await http.post(
        url,
        body: {
          'fileid': drawingFileId,
          'userid': userId,
        },
      );

      print('resposefile ${responsefile.body} $drawingFileId');
      if (responsefile.body == "-1") {
        print('ifff');
        return drawingFileId;
      } else {
        print('elseee');
        return json.decode(responsefile.body);
      }
    } else {
      print('Error Status: ${response.statusCode}');
      print('Error Body: ${response.body}');
      throw Exception('Failed to get process list');
    }
  } else {
    final url = Uri.parse(
        'https://www.alfadock-pack.com/api/file/GetFolderIdByFolderName');
    final response = await http.post(
      url,
      body: {
        'compid': compId,
        'foldername': folderName,
      },
    );

    print(
        'GetFolderIdByFolderName API called: compid=$compId, foldername=$folderName');
    print('API Response: ${response.body}');

    if (response.statusCode == 200) {
      try {
        return json.decode(response.body); // Try to decode as JSON
      } catch (e) {
        // If JSON decoding fails, return the raw response body as a string or int
        return response.body;
      }
    } else {
      throw Exception(
          'Failed to get folder ID: ${response.statusCode} - ${response.body}');
    }
  }
}

Future<List<Map<String, dynamic>>> getAllInOutFiles(
  String compId,
  String userId,
  String folderId,
) async {
  final url =
      Uri.parse('https://www.alfadock-pack.com/api/file/GetAllInOutFiles2');
  final response = await http.post(
    url,
    body: {
      'compid': compId,
      'userid': userId,
      'folderid': folderId,
      'rowoffset': '0',
      'attrFilter': 'true',
      'orderFilter': 'true',
      'linkedFilter': 'true',
      'noattrFilter': 'true',
      'noorderFilter': 'true',
      'nolinkedFilter': 'true',
      'sortValue': 'files.modifieddate',
      'sortOrder': 'desc',
      'pageCount': '200',
      'admin': '1',
      'source': 'user',
    },
  );

  print(
      'GetAllInOutFiles2 API called: compid=$compId, userid=$userId, folderid=$folderId');
  print('API Response: ${response.body}');

  if (response.statusCode == 200) {
    final List<dynamic> decoded = json.decode(response.body);
    return decoded.cast<Map<String, dynamic>>();
  } else {
    throw Exception(
        'Failed to get files: ${response.statusCode} - ${response.body}');
  }
}

Future<List<String>> addSubmitProcess({
  required String erpUrlBase,
  required String processId,
  required String machineId,
  required String curTime,
  required String userId,
  required String suffix,
}) async {
  final url =
      Uri.parse('$erpUrlBase/api/SiSchedulerApiProcess/addSubmitProcess');
  final headers = {
    'Content-Type': 'application/x-www-form-urlencoded',
  };
  final body = {
    'processid': processId,
    'machineid': machineId,
    'curTime': curTime,
    'userid': userId,
    'suffix': suffix,
  };

  print('Calling addSubmitProcess API: $url');
  print('Request body: $body');

  final response = await http
      .post(
        url,
        headers: headers,
        body: body,
      )
      .timeout(
        const Duration(seconds: 10),
        onTimeout: () => throw ('addSubmitProcess request timed out'),
      );

  print('addSubmitProcess response: ${response.body}');

  if (response.statusCode == 200) {
    final dynamic data = json.decode(response.body);

    if (data is List<dynamic>) {
      // Convert to List<String>
      return data.map((e) => e.toString()).toList();
    } else {
      throw Exception('Unexpected response format: expected a JSON array');
    }
  } else {
    throw Exception(
        'Failed to create sub-process: ${response.statusCode} - ${response.body}');
  }
}

Future<Map<String, dynamic>> updateSubmitProcess({
  required String erpUrlBase,
  required String processId,
  required String submitProcessId,
  required String userId,
  required String status,
  required String machineId,
  required String quantity,
  required String defectQuantity,
  required String defectCode,
}) async {
  final url = Uri.parse('$erpUrlBase/api/plugin');
  // Prepare args as a raw JSON string
  final argsJson = jsonEncode({
    'processId': processId,
    'submitProcessId': submitProcessId,
    'userId': userId,
    'status': status,
    'machineId': machineId,
    'quantity': quantity,
    'defectQuantity': defectQuantity,
    'defectCode': defectCode,
  });

  print('machineId: $machineId');
  print('url: $url');

  print('Calling updateSubmitProcess API: $url');
  print('FormData args: $argsJson');

  final request = http.MultipartRequest('POST', url);
  request.fields['plugin'] = 'SchedulerApi';
  request.fields['controller'] = 'SchedulerIOSController';
  request.fields['action'] = 'updateSubmitProcess';
  request.fields['args'] = argsJson;

  print('FormData fields: ${request.fields}');

  final streamedResponse = await request.send().timeout(
        const Duration(seconds: 10),
        onTimeout: () => throw ('updateSubmitProcess request timed out'),
      );
  final response = await http.Response.fromStream(streamedResponse);

  print('updateSubmitProcessdfdfdfdfd response: ${response.body}');

  if (response.statusCode == 200) {
    final dynamic data = json.decode(response.body);
    print('Parsed response data: ${data['value']?['id']}');

    if (data is Map<String, dynamic>) {
      if (data.containsKey('value') && data['value'] != null) {
        // ✅ API returned valid data
        return data;
      } else {
        throw Exception(
            'API failed to update sub-process: ${data['message'] ?? 'Unknown error'}');
      }
    } else {
      throw Exception('Unexpected response format from updateSubmitProcess');
    }
  } else {
    throw Exception(
        'Failed to update sub-process: ${response.statusCode} - ${response.body}');
  }
}

Future<List<dynamic>> getfiltercontent(String compId) async {
  print('Using new API for Alfa ERP process list');
  print('CompId: $compId');
  final url = Uri.parse(
      'https://www.alfadock-pack.com/api/ProcessSetting/GetAllProcessesWithUser');

  final request = http.MultipartRequest('POST', url);
  request.fields['compid'] = compId;

  print('FormData POST: $url');
  print('FormData fields: ${request.fields}');

  final streamedResponse = await request.send();
  final response = await http.Response.fromStream(streamedResponse);

  if (response.statusCode == 200) {
    print('API Response: ${response.body}');
    final decoded = json.decode(response.body);
    if (decoded is List) {
      return decoded;
    } else {
      throw Exception('Expected a list but got: ${decoded.runtimeType}');
    }
  } else {
    print('Error Status: ${response.statusCode}');
    print('Error Body: ${response.body}');
    throw Exception('Failed to get process list');
  }
}

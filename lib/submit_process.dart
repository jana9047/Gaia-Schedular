import 'dart:convert';
import 'dart:io';
import 'package:camerawesome/camerawesome_plugin.dart';
import 'package:camerawesome/pigeon.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import 'api.dart';
import 'app_state.dart';
import 'fileviewer.dart';
import 'package:path_provider/path_provider.dart';
//import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;

import 'main_page.dart';
import 'l10n/app_localizations.dart';

class SubmitProcessPage extends StatefulWidget {
  final Map<String, dynamic> processData;
  final String erpUrlBase;
  final String? compId;
  final String? userId;
  final String? folderId;
  const SubmitProcessPage({
    super.key,
    required this.processData,
    required this.erpUrlBase,
    this.compId,
    this.userId,
    this.folderId,
  });
  @override
  _SubmitProcessPageState createState() => _SubmitProcessPageState();
}

class _SubmitProcessPageState extends State<SubmitProcessPage> {
  List<Map<String, dynamic>> processes = [];
  bool isLoading = false;
  Map<String, String?> selectedAssemblyTypes = {};
  Map<String, List<String>> selectedUsers = {};
  Map<String, List<int>> selectedUsersalfa = {};
  Map<String, String?> selectedDefects = {};
  Map<String, Timer?> timers = {};
  Map<String, int> elapsedSeconds = {};
  List<Map<String, dynamic>> operators = [];
  List<Map<String, dynamic>> machines = [];
  List<Map<String, dynamic>> machinesdock = [];
  Map<String, dynamic>? processListData;
  bool showCancelButton = false;
  int completeInput = 0;
  List<Map<String, dynamic>> fileList = [];
  List<String> currentSelectionNames = [];
  List<String> assemblyTypes = [];
  List<String> userOptions = [];
  List<String> usererp = [];
  List<String> defectTypes = [];
  List<String> staffOptions = [];
  Map<int, String> userIdNameMap = {};
  Map<String, int> userNameToRecordIdMap = {};
  final numberInNameToIdMap = <int, int>{};
  Map<int, String> userIdToStaffNameMap = {};
  int? _userDisplay;
  int? _cancelFunction;
  List<String> optionsuser = [];
  Map<int, String> defectIdToNameMap = {};
  int? flag = 0;
  Map<String, dynamic> response = {};
  List<String> stafferp = [];
  String? _capturedImagePath;
  List<Map<String, String>> folderStack = [];
  String currentFolderName = 'Root';
  int globaldockid = 0;

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _fetchFiles();
    _loadSelectedAssemblyTypes();
    _fetchSchedulerSettings().then((_) {
      _fetchInitialProcessStatus();
      _fetchProcessListData();
    });
    _loadCancelFunctionSetting();
    _loadCompleteInputSetting();
    // print('globaluserType in submit process: $globaluserType');
  }

  @override
  void dispose() {
    for (var timer in timers.values) {
      timer?.cancel();
    }
    super.dispose();
  }

// Add this method to calculate the correct elapsed time from API response
  int _calculateElapsedTimeFromAPI(Map<String, dynamic> record) {
    try {
      // Get duration from API (format: "133:37" meaning 133 minutes 37 seconds)
      final durationStr = record['duration']?.toString() ?? '00:00';
      int apiDurationSeconds = _parseDurationMinutesSeconds(durationStr);
      print(apiDurationSeconds);

      // Get date_start_UTC and treat it as IST/local
      final dateStartStr = record['date_start_UTC']?.toString();
      print('date_start_UTC (from API): $dateStartStr');
      if (dateStartStr != null && dateStartStr.isNotEmpty) {
        try {
          // Manually treat as UTC (since API forgot 'Z')
          final utcDateTime =
              DateTime.parse(dateStartStr).copyWith(isUtc: true);
          final localDateTime = utcDateTime.toLocal();
          print('Parsed UTC: $utcDateTime');
          print('Converted to local IST: $localDateTime');

          // Get current LOCAL time
          final currentLocal = DateTime.now();
          print('Current local time: $currentLocal');

          // Calculate elapsed seconds since start
          final elapsedSinceStart =
              currentLocal.difference(localDateTime).inSeconds;
          print('Elapsed seconds since start: $elapsedSinceStart');

          // Total elapsed = API duration + elapsed since start
          final totalElapsed = apiDurationSeconds + elapsedSinceStart;
          print('API duration: ${apiDurationSeconds}s ($durationStr)');
          print('Elapsed since start: ${elapsedSinceStart}s');
          print('Total elapsed: ${totalElapsed}s');

          return totalElapsed.clamp(0, double.infinity).toInt();
        } catch (e) {
          print('Error parsing date_start_UTC: $e');
          return apiDurationSeconds;
        }
      }

      return apiDurationSeconds;
    } catch (e) {
      print('Error calculating elapsed time: $e');
      return 0;
    }
  }

// Helper method to parse duration in MM:SS format
  int _parseDurationMinutesSeconds(String? duration) {
    if (duration == null || duration.isEmpty) return 0;
    try {
      List<String> parts = duration.split(':');
      if (parts.length == 2) {
        int minutes = int.parse(parts[0]);
        int seconds = int.parse(parts[1]);
        return (minutes * 60 + seconds).clamp(0, double.infinity).toInt();
      }
      return 0;
    } catch (e) {
      print('Error parsing duration: $e');
      return 0;
    }
  }

  Future<void> _loadSettings() async {
    final display = await AppState.getUserDisplay() ?? 0; // Default to ID
    final cancelFunction = await AppState.getCancelFunction() ?? 0;
    setState(() {
      _userDisplay = display;
      _cancelFunction = cancelFunction;
    });
    print('Cancel function setting loaded: $showCancelButton');
    print('User display setting loaded: $_userDisplay');
  }

  void _showPreviewDialog(String imagePath) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Photo Preview'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                constraints:
                    const BoxConstraints(maxHeight: 300, maxWidth: 300),
                child: Image.file(File(imagePath), fit: BoxFit.contain),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  TextButton(
                    onPressed: () {
                      // Navigator.pop(dialogContext); // close preview
                      _openCamera(); // retake
                    },
                    child: const Text('Retake'),
                  ),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: () async {
                      // Navigator.pop(dialogContext); // close preview
                      setState(() => _capturedImagePath = imagePath);
                      print("Captured image path: $_capturedImagePath");

                      // Upload image here
                      //  await _uploadImage(File(imagePath));
                    },
                    child: const Text('Use Photo'),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _loadCancelFunctionSetting() async {
    final cancelFunction = await AppState.getCancelFunction();
    setState(() {
      showCancelButton = (cancelFunction ?? 0) == 0;
    });
  }

  Future<void> _loadCompleteInputSetting() async {
    final completeInputSetting = await AppState.getCompleteInput();
    setState(() {
      completeInput = completeInputSetting ?? 0;
    });
  }

  Future<void> _loadSelectedAssemblyTypes() async {
    final prefs = await SharedPreferences.getInstance();
    final String? savedAssemblyTypes =
        prefs.getString('selectedAssemblyTypes_${widget.processData['id']}');
    if (savedAssemblyTypes != null) {
      setState(() {
        selectedAssemblyTypes =
            Map<String, String?>.from(jsonDecode(savedAssemblyTypes));
      });
      print('Loaded selectedAssemblyTypes: $selectedAssemblyTypes');
    }
  }

  Future<void> _saveSelectedAssemblyTypes() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      'selectedAssemblyTypes_${widget.processData['id']}',
      jsonEncode(selectedAssemblyTypes),
    );
    // print('Saved selectedAssemblyTypes: $selectedAssemblyTypes');
  }

  Future<void> _saveElapsedSeconds(String processName, int seconds) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(
      'elapsedSeconds_${widget.processData['id']}_$processName',
      seconds,
    );
    // print('Saved elapsedSeconds for $processName: $seconds');
  }

  Future<int> _loadElapsedSeconds(String processName) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(
            'elapsedSeconds_${widget.processData['id']}_$processName') ??
        0;
  }

  Future<void> _fetchSchedulerSettings() async {
    setState(() {
      isLoading = true;
    });
    try {
      final response =
          await fetchSchedulerSettings(widget.erpUrlBase, widget.compId ?? '0');
      print('Scheduler settings response: ${jsonEncode(response['data'])}');
      setState(() {
        print('Scheduler settings response: $response');

        // Conditional logic based on erpUrlBase
        if (widget.erpUrlBase == "https://www.alfadock-pack.com") {
          print('data ${response['rawResponse']}');
          final rawResponse = response['rawResponse'] as List<dynamic>;
          userOptions = List<String>.from(response['userOptions'] ?? []);
          staffOptions = List<String>.from(response['staffOptions'] ?? []);
          print('Staff Options: $staffOptions');
          userIdNameMap = {
            for (var user in rawResponse)
              if (user['UserId'] != null && user['UserName'] != null)
                user['UserId'] as int: user['UserName'].toString()
          };
          // print('User ID to Name Map: $userIdNameMap');
          userIdToStaffNameMap = {
            for (var user in rawResponse)
              if (user['UserId'] != null)
                user['UserId'] as int: user['staffname']?.toString() ?? ''
          };
          print('User ID to Name Map: $userIdNameMap');
          print('User Name to Staff Name Map: $userIdToStaffNameMap');
          optionsuser = userIdNameMap.keys
              .map((id) {
                final staffName = userIdToStaffNameMap[id]?.trim() ?? '';
                final userName = userIdNameMap[id]?.trim() ?? '';
                return staffName.isNotEmpty ? staffName : userName;
              })
              .where((name) => name.isNotEmpty)
              .toList();
          print('_userDisplay: $_userDisplay');
          print('Options: $optionsuser ');
          defectTypes = ['empty,empty'];
          print('Defect Types: $defectTypes');
          operators =
              List<Map<String, dynamic>>.from(response['operators'] ?? []);
        } else {
          assemblyTypes = List<String>.from(
              (response['data']['machines'] as List<dynamic>? ?? [])
                  .map((machine) => machine['name'] as String));
          machines = List<Map<String, dynamic>>.from(
              response['data']['machines'] ?? []);
          usererp = List<String>.from(
              (response['data']['operators'] as List<dynamic>? ?? [])
                  .map((operator) => operator['name'] as String));
          operators = List<Map<String, dynamic>>.from(
              response['data']['operators'] ?? []);
        }
        print(response['data']['defect_codes']);
        defectTypes = List<String>.from(
            (response['data']['defect_codes'] as List<dynamic>? ?? [])
                .map((defect) => defect['name'] as String));
        final List<dynamic> defectCodes = response['data']['defect_codes'];
        defectIdToNameMap = {
          for (var code in defectCodes)
            code['alfadock_id'] as int: code['name'] as String
        };
        print('Defect ID to Name Map: $defectIdToNameMap');
        print('Defect Types: $defectTypes');
        print('usererp: $usererp');
        print('mapping $mapping');
        for (var option in usererp) {
          if (mapping.containsKey(option)) {
            stafferp.add(mapping[option]!);
          }
        }
        print('stafferp $stafferp');
        if (_userDisplay == 0) {
          userOptions = usererp;
        } else {
          print(stafferp);
          userOptions = stafferp;
        }
      });
    } catch (e) {
      setState(() {
        assemblyTypes = [];
        userOptions = [];
        operators = [];
        defectTypes = [];
        machines = [];
      });
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> _fetchProcessListData() async {
    final loc = AppLocalizations.of(context);
    try {
      final today = DateTime.now();
      final ds =
          DateFormat('yyyy-MM-dd').format(today.subtract(Duration(days: 366)));
      final de =
          DateFormat('yyyy-MM-dd').format(today.add(Duration(days: 366)));
      final response = await getAlfaERPProcessListGet(
        widget.erpUrlBase,
        'sfGa0kl7lO9fXWaE1rENp',
        ds,
        de,
        widget.userId ?? '0',
      );
      print('userOptionsfetch: $optionsuser');
      setState(() {
        processListData = response;
      });
      print('Process List Data fetched: ${jsonEncode(response)}');
    } catch (e) {
      print('Error fetching process list data: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${loc.failedtoload} $e')),
      );
    }
  }

  int _parseDuration(String? duration) {
    if (duration == null || duration.isEmpty) return 0;
    try {
      List<String> parts = duration.split(':');
      if (parts.length == 2) {
        int minutes = int.parse(parts[0]);
        int secs = int.parse(parts[1]);
        return (minutes * 60 + secs).clamp(0, double.infinity).toInt();
      } else if (parts.length == 3) {
        int hours = int.parse(parts[0]);
        int minutes = int.parse(parts[1]);
        int secs = int.parse(parts[2]);
        return (hours * 3600 + minutes * 60 + secs)
            .clamp(0, double.infinity)
            .toInt();
      }
      return 0;
    } catch (e) {
      print('Error parsing duration: $e');
      return 0;
    }
  }

  void _startTimer(
      String processName, DateTime? startDateTime, int initialElapsedSeconds) {
    timers[processName]?.cancel();

    // Set the initial elapsed seconds
    elapsedSeconds[processName] = initialElapsedSeconds;

    print(
        'Starting timer for $processName with initial elapsed: $initialElapsedSeconds seconds');

    timers[processName] = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          elapsedSeconds[processName] = (elapsedSeconds[processName] ?? 0) + 1;
        });
        _saveElapsedSeconds(processName, elapsedSeconds[processName] ?? 0);
      } else {
        timer.cancel();
        timers[processName] = null;
      }
    });
  }

  void _stopTimer(String processName) {
    timers[processName]?.cancel();
    timers[processName] = null;
    _saveElapsedSeconds(processName, elapsedSeconds[processName] ?? 0);
  }

  String _getNextSpName() {
    if (processes.isEmpty) return 'SP1';
    final spNames = processes.map((p) => p['name'] as String).toList();
    final spNumbers = spNames
        .where((name) => name.toUpperCase().startsWith('SP'))
        .map((name) =>
            int.tryParse(
                name.replaceFirst(RegExp(r'^SP', caseSensitive: false), '')) ??
            0)
        .toList();
    final maxSpNumber =
        spNumbers.isNotEmpty ? spNumbers.reduce((a, b) => a > b ? a : b) : 0;
    return 'SP${maxSpNumber + 1}';
  }

  Future<void> _createNewSubProcess() async {
    setState(() {
      isLoading = true;
    });
    try {
      if (widget.erpUrlBase == "https://www.alfadock-pack.com") {
        final response = await submitProcessStatus(
          pid: int.parse(widget.processData['id'].toString()),
          erpUrlBase: widget.erpUrlBase,
          userId: widget.userId ?? '0',
        );
        int suffix = 1;
        if (response['value'] != null &&
            response['value']['submitProcessList'] != null &&
            (response['value']['submitProcessList'] as List).isNotEmpty) {
          final records = List<Map<String, dynamic>>.from(
              response['value']['submitProcessList']);
          final spNumbers = records
              .map((record) =>
                  int.tryParse(record['numberInName']?.toString() ?? '0') ?? 0)
              .toList();
          final maxSpNumber = spNumbers.isNotEmpty
              ? spNumbers.reduce((a, b) => a > b ? a : b)
              : 0;
          suffix = maxSpNumber + 1;
        }
        final List<dynamic> machineList = response["value"]["machines"] ?? [];
        machinesdock = machineList.map((m) {
          return {
            "id": m["id"],
            "name": m["name"],
          };
        }).toList();

        List<String> assemblyTypes =
            machinesdock.map((m) => m["name"].toString()).toList();

        print('assemblyTypes $assemblyTypes');
        final curTime = DateFormat('yyyyMMdd HH:mm:ss').format(DateTime.now());
        print('Creating new sub-process with suffix: $suffix at $curTime');
        final machineName =
            widget.processData['machineName']?.toString() ?? '0';
        if (machineName != '0' && !assemblyTypes.contains(machineName)) {
          assemblyTypes.add(machineName);
          machines.add({'id': machineName, 'name': machineName});
        }
        final addResponse = await addSubmitProcess(
          erpUrlBase: widget.erpUrlBase,
          processId: widget.processData['id'].toString(),
          machineId: assemblyTypes.contains(machineName) ? machineName : '0',
          curTime: curTime,
          userId: widget.userId ?? '0',
          suffix: suffix.toString(),
        );
        print('addSubmitProcess responsffgfe: ${jsonEncode(addResponse)}');
        print('Created new sub-process SP$suffix: ${jsonEncode(addResponse)}');
        setState(() {
          processes.add({
            'id': addResponse[0],
            'name': 'SP$suffix',
            'qty': widget.processData['quantity'].toString(),
            'defect_qty': 0,
            'status': 'ready',
            'duration': '00:00:00',
            'date_start': null,
            'date_end': null,
            'users2': [],
            'defect_codes': assemblyTypes,
            'machinedock': machinesdock,
          });
          selectedAssemblyTypes['SP$suffix'] =
              assemblyTypes.contains(machineName) ? machineName : null;
        });
        _saveSelectedAssemblyTypes();
        await _fetchUpdatedProcessStatus('SP$suffix');
      } else {
        final newSpName = _getNextSpName();
        // final initialQuantity =
        // int.tryParse(widget.processData['quantity']?.toString() ?? '25') ??
        // 25;
        final machineName = widget.processData['machineName']?.toString();
        if (machineName != null && !assemblyTypes.contains(machineName)) {
          assemblyTypes.add(machineName);
          machines.add({'id': machineName, 'name': machineName});
        }
        print('Creating new sub-process: $newSpName');
        final response = await startProcess(
          pid: int.parse(widget.processData['id'].toString()),
          erpUrlBase: widget.erpUrlBase,
          id: '',
          name: newSpName,
          qty: widget.processData['quantity']?.toString() ?? '25',
          users: [],
          status: 'ready',
          plannedStartDate: '',
          defectQty: '0',
          defectReason: '',
          defectCodeId: '0',
        );
        print('Created new sub-process $newSpName: ${jsonEncode(response)}');
        setState(() {
          processes.add({
            'id': response['id']?.toString() ?? '',
            'name': newSpName,
            'qty': widget.processData['quantity'].toString(),
            'defect_qty': 0,
            'status': 'ready',
            'duration': '00:00:00',
            'date_start': null,
            'date_end': null,
            'users2': [],
          });
          selectedAssemblyTypes[newSpName] =
              assemblyTypes.contains(machineName) ? machineName : null;
        });
        _saveSelectedAssemblyTypes();
        await _fetchUpdatedProcessStatus(newSpName);
      }
    } catch (e) {
      print('Error creating new sub-process: $e');
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  String _mapStatusToCode(String status) {
    print('comingstatus $status');
    switch (status) {
      case 'ready':
        return '0';
      case 'resume':
        return '4';
      case 'progress':
        return '1';
      case 'pause':
        return '3';
      case 'done':
        return '2';
      default:
        return '0';
    }
  }

  String _mapAlfaDockStatus(dynamic status) {
    switch (status?.toString()) {
      case '0':
        return 'ready';
      case '1':
        return 'progress';
      case '3':
        return 'pause';
      case '2':
        return 'done';
      case '4':
        return 'resume';
      default:
        return '';
    }
  }

  Future<void> _updateProcessStatus(String status, String processName) async {
    final loc = AppLocalizations.of(context);
    if (!['pending', 'ready', 'progress', 'resume', 'pause', 'done']
        .contains(status)) {
      print('Invalid status: $status for process $processName');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${loc.anerroroccured} $status')),
      );
      return;
    }
    setState(() {
      isLoading = true;
    });
    try {
      final processIndex =
          processes.indexWhere((p) => p['name'] == processName);
      print('Updating process status for $processIndex');
      if (processIndex == -1) {
        print('Process $processName not found');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('${loc.process} $processName  ${loc.notfound} ')),
        );
        return;
      }
      final process = processes[processIndex];
      print('Current process: ${jsonEncode(process)}');
      final updatedProcess = Map<String, dynamic>.from(process);
      updatedProcess['status'] = status == 'resume' ? 'progress' : status;
      if (status == 'progress' && process['date_start'] == null) {
        print('jana');
        updatedProcess['date_start'] =
            DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now());
      }
      if (status == 'done' || status == 'pause') {
        updatedProcess['date_end'] =
            DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now());
        updatedProcess['duration'] =
            _formatTime(elapsedSeconds[processName] ?? 0);
        print('Duration for $processName: ${updatedProcess['duration']}');
      }
      setState(() {
        processes[processIndex] = updatedProcess;
      });
      if (widget.erpUrlBase == "https://www.alfadock-pack.com") {
        final machineName = selectedAssemblyTypes[processName] ?? '';
        final machine = machines.firstWhere(
          (m) => m['name'] == machineName,
          orElse: () => {'id': '0'},
        );
        final defectName = selectedDefects[processName] ?? '';
        final defectCode = defectTypes.contains(defectName)
            ? defectTypes.indexOf(defectName).toString()
            : '';
        final response = await updateSubmitProcess(
          erpUrlBase: widget.erpUrlBase,
          processId: widget.processData['id'].toString(),
          submitProcessId: process['id']?.toString() ?? '',
          userId: widget.userId ?? '0',
          status: _mapStatusToCode(status),
          machineId: '0',
          quantity: process['qty']?.toString() ?? '0',
          defectQuantity: process['defect_qty']?.toString() ?? '0',
          defectCode: defectCode,
        );
        print(
            'Updated process status for $processName: ${jsonEncode(response)}');
        if (status == 'done' &&
            response['message'] != null &&
            response['message']
                .contains('Cannot change a completed work order')) {
          print(
              'Cannot update $processName to done: parent process (pid=${widget.processData['id']}) is already done');
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(loc.anerroroccured + ' $processName')),
          );
          return;
        }
        print('status: $status');
        if (status == 'progress' || status == 'resume') {
          final startDateTime = updatedProcess['date_start'] != null
              ? DateTime.parse(updatedProcess['date_start'])
              : DateTime.now();
          _startTimer(
            processName,
            startDateTime,
            elapsedSeconds[processName] ?? 0,
          );
        } else {
          _stopTimer(processName);
          if (status == 'done' || status == 'pause') {
            await _saveElapsedSeconds(
                processName, elapsedSeconds[processName] ?? 0);
          }
        }
        await _fetchUpdatedProcessStatus(processName);
      } else {
        final userObjects = (selectedUsers[processName] ?? [])
            .map((userName) => operators.firstWhere(
                  (op) => op['name'] == userName,
                  orElse: () => {
                    'id': 0,
                    'name': userName,
                    'alfadock_id': 0,
                    'staff_name': '',
                  },
                ))
            .toList();
        print('User objects for $processName: ${jsonEncode(userObjects)}');
        final defectName = selectedDefects[processName] ?? '';
        print('Defect name for $processName: $defectName');
        print('defectidmap $defectIdToNameMap');
        final defectCodeId = defectIdToNameMap.entries
            .firstWhere(
              (entry) => entry.value == defectName,
              orElse: () => const MapEntry(0, 'Unknown'),
            )
            .key
            .toString();
        print('Defect code ID for $processName: $defectCodeId');
        print('status bro $status');
        if (completeInput == 0 && status == 'done' && flag == 0) {
          print('eorking');
          response = await stopProcess(
            pid: int.parse(widget.processData['id'].toString()),
            erpUrlBase: widget.erpUrlBase,
            id: process['id']?.toString() ?? '',
            name: processName,
            qty: process['qty']?.toString() ?? '0',
            users: userObjects,
            status: 'progress',
            plannedStartDate: updatedProcess['date_start'] ??
                DateFormat('MM/dd/yy hh:mm:ss a').format(DateTime.now()),
            defectQty: process['defect_qty']?.toString() ?? '0',
            defectReason: defectName,
            defectCodeId: defectCodeId,
          );
        } else {
          response = await startProcess(
            pid: int.parse(widget.processData['id'].toString()),
            erpUrlBase: widget.erpUrlBase,
            id: process['id']?.toString() ?? '',
            name: processName,
            qty: process['qty']?.toString() ?? '0',
            users: userObjects,
            status: status,
            plannedStartDate: updatedProcess['date_start'] ??
                DateFormat('MM/dd/yy hh:mm:ss a').format(DateTime.now()),
            defectQty: process['defect_qty']?.toString() ?? '0',
            defectReason: defectName,
            defectCodeId: defectCodeId,
          );
        }

        print(
            'startProcess response for $processName: ${jsonEncode(response)}');
        if (status == 'done' &&
            response['message'] != null &&
            response['message']
                .contains('Cannot change a completed work order')) {
          print(
              'Cannot update $processName to done: parent process (pid=${widget.processData['id']}) is already done');
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(loc.anerroroccured + ' $processName')),
          );
          return;
        }
        if (status == 'progress') {
          print('progresses');
          _startTimer(
              processName,
              updatedProcess['date_start'] != null
                  ? DateTime.parse(updatedProcess['date_start'])
                  : DateTime.now(),
              elapsedSeconds[processName] ?? 0);
        } else {
          _stopTimer(processName);
          if (status == 'done' || status == 'pause') {
            await _saveElapsedSeconds(
                processName, elapsedSeconds[processName] ?? 0);
          }
        }
        await _fetchUpdatedProcessStatus(processName);
      }
      if (status == 'done') {
        await _adjustDoneProcessesQuantities();
      }
    } catch (e) {
      await _fetchUpdatedProcessStatus(processName);
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> _updateProcessMachine(
      String processName, String machineName) async {
    final loc = AppLocalizations.of(context);
    setState(() {
      isLoading = true;
    });
    try {
      final processIndex =
          processes.indexWhere((p) => p['name'] == processName);
      if (processIndex == -1) {
        print('Process $processName not found');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('${loc.process} $processName ${loc.notfound} ')),
        );
        return;
      }
      final process = processes[processIndex];
      setState(() {
        selectedAssemblyTypes[processName] = machineName;
        print(
            'Selected assembly type for ${selectedAssemblyTypes[processName]}');
      });
      await _saveSelectedAssemblyTypes();
      if (widget.erpUrlBase == "https://www.alfadock-pack.com") {
        final machine = machines.firstWhere(
          (m) => m['name'] == machineName,
          orElse: () => {'id': '0'},
        );
        final defectName = selectedDefects[processName] ?? '';
        final defectCode = defectTypes.contains(defectName)
            ? defectTypes.indexOf(defectName).toString()
            : '';
        print(machineName);
        print(machinesdock);
        final machine1 = machinesdock.firstWhere(
          (m) => m['name'] == machineName,
          orElse: () => {}, // return empty map if not found
        );
        final machineId = machine1.isNotEmpty ? machine1['id'] : null;
        print(machineId);
        final response = await updateSubmitProcess(
          erpUrlBase: widget.erpUrlBase,
          processId: widget.processData['id'].toString(),
          submitProcessId: process['id']?.toString() ?? '',
          userId: widget.userId ?? '0',
          status: process['status'] == 'resume'
              ? '1'
              : _mapStatusToCode(process['status']?.toString() ?? 'ready'),
          machineId: machineId?.toString() ?? '0',
          quantity: process['qty']?.toString() ?? '0',
          defectQuantity: process['defect_qty']?.toString() ?? '0',
          defectCode: defectCode,
        );
        print('Updated machine for $processName: ${jsonEncode(response)}');
        await _fetchUpdatedProcessStatus(processName);
        return;
      } else {
        final machine = machines.firstWhere(
          (m) => m['name'] == machineName,
          orElse: () => {'id': 0, 'name': machineName},
        );
        String orderNumber = widget.processData['poNumber']?.toString() ?? '';
        String productNumber =
            widget.processData['productNumber']?.toString() ?? '';
        if ((orderNumber.isEmpty || productNumber.isEmpty) &&
            processListData != null) {
          final processListRecord = processListData!['records'] != null &&
                  (processListData!['records'] as List).isNotEmpty
              ? (processListData!['records'] as List).firstWhere(
                  (record) => record['id'] == widget.processData['id'],
                  orElse: () => {'order_number': '', 'product_number': ''},
                )
              : {'order_number': '', 'product_number': ''};
          orderNumber =
              processListRecord['order_number']?.toString() ?? orderNumber;
          productNumber =
              processListRecord['product_number']?.toString() ?? productNumber;
        }
        final response = await updateProcessMachine(
          erpUrlBase: widget.erpUrlBase,
          id: process['id']?.toString() ?? '',
          machine: {'id': machine['id'] ?? 0, 'name': machine['name']},
          processName: widget.processData['name'] ?? 'Process Name',
          orderNumber: orderNumber,
          productNumber: productNumber,
        );
        print(
            'Machine update response for $processName: ${jsonEncode(response)}');
        await _fetchUpdatedProcessStatus(processName);
      }
      await _saveSelectedAssemblyTypes();
    } catch (e) {
      print('Error updating machine for $processName: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${loc.failedto} $processName: $e')),
      );
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<bool> _showZeroQuantityConfirmation(BuildContext context) async {
    final loc = AppLocalizations.of(context);
    return await showDialog<bool>(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              title: Text(loc.warning),
              content: Text(loc.pleaseEnterQuantity),
              actions: <Widget>[
                TextButton(
                  child: Text('OK'),
                  onPressed: () {
                    Navigator.of(context).pop(true); // Return true to proceed
                  },
                ),
              ],
            );
          },
        ) ??
        false; // Return false if dialog is dismissed
  }

  Future<void> _updateQuantity(
      String processName, int newQty, bool isDefectQty) async {
    final loc = AppLocalizations.of(context);
    setState(() {
      isLoading = true;
    });
    print('Updating quantity for $processName to $newQty $isDefectQty');
    try {
      print("newQty $newQty");
      // 🔹 Early check: If user entered 0 or empty, show warning and return
      if (newQty == 0 && !isDefectQty) {
        await _showZeroQuantityConfirmation(context);
        setState(() {
          isLoading = false;
        });
        return; // Stop here, don't proceed
      }

      // 🔹 Find the process
      final processIndex =
          processes.indexWhere((p) => p['name'] == processName);

      if (processIndex == -1) {
        print('Process $processName not found');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('${loc.process} $processName ${loc.notfound}')),
        );
        setState(() {
          isLoading = false;
        });
        return;
      }

      final process = Map<String, dynamic>.from(processes[processIndex]);

      // ✅ Calculate updated values
      final updatedQty = isDefectQty
          ? int.tryParse(process['qty']?.toString() ?? '0') ?? 0
          : newQty;
      final updatedDefectQty = isDefectQty
          ? newQty.clamp(0, double.infinity).toInt()
          : int.tryParse(process['defect_qty']?.toString() ?? '0') ?? 0;

      process['qty'] = updatedQty;
      process['defect_qty'] = updatedDefectQty;

      setState(() {
        processes[processIndex] = process;
      });

      // 🔹 Proceed with API calls only if valid
      if (widget.erpUrlBase == "https://www.alfadock-pack.com") {
        final machineName = selectedAssemblyTypes[processName] ?? '';
        final machine = machines.firstWhere(
          (m) => m['name'] == machineName,
          orElse: () => {'id': '0'},
        );
        final defectName = selectedDefects[processName] ?? '';
        final defectCode = defectTypes.contains(defectName)
            ? defectTypes.indexOf(defectName).toString()
            : '';

        final response = await updateSubmitProcess(
          erpUrlBase: widget.erpUrlBase,
          processId: widget.processData['id'].toString(),
          submitProcessId: process['id']?.toString() ?? '',
          userId: widget.userId ?? '0',
          status: process['status'] == 'resume'
              ? '1'
              : _mapStatusToCode(process['status']?.toString() ?? 'ready'),
          machineId: '0',
          quantity: updatedQty.toString(),
          defectQuantity: updatedDefectQty.toString(),
          defectCode: defectCode,
        );

        print(
            'Quantity update response for $processName: ${jsonEncode(response)}');
        if (response['status'] == 'success') {
          await _fetchUpdatedProcessStatus(processName);
        } else {
          throw Exception('API update failed: ${response['message']}');
        }
      } else {
        final userObjects = (selectedUsers[processName] ?? [])
            .map((userName) => operators.firstWhere(
                  (op) => op['name'] == userName,
                  orElse: () => {
                    'id': 0,
                    'name': userName,
                    'alfadock_id': 0,
                    'staff_name': '',
                  },
                ))
            .toList();

        final defectName = selectedDefects[processName] ?? '';
        print('Defect name for $processName: $defectName');
        final defectCodeId = defectTypes.contains(defectName)
            ? defectTypes.indexOf(defectName).toString()
            : '0';
        print('Defect code ID for $processName: $defectCodeId');
        print('updatedQty $updatedQty');
        print('updatedDefectQty $updatedDefectQty');
        final response = await updateProcessQuantity(
          pid: int.parse(widget.processData['id'].toString()),
          erpUrlBase: widget.erpUrlBase,
          id: process['id']?.toString() ?? '',
          name: processName,
          qty: updatedQty.toString(),
          users: userObjects,
          defectQty: updatedDefectQty.toString(),
          defectReason: defectName,
          defectCodeId: defectCodeId,
          plannedStartDate: process['date_start'] ??
              widget.processData['plannedStartDate'] ??
              DateFormat('MM/dd/yy hh:mm:ss a').format(DateTime.now()),
        );

        print(
            'Quantity update response for $processName: ${jsonEncode(response)}');
        if (response['status'] == 'success' || response['status'] != null) {
          await _fetchUpdatedProcessStatus(processName);
        } else {
          throw Exception('API update failed: ${response['message']}');
        }
      }
    } catch (e) {
      print('Error updating quantity for $processName: $e');
      await _fetchUpdatedProcessStatus(processName);
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> _updateProcessUsers(
      String processName, List<String> users) async {
    final loc = AppLocalizations.of(context);
    setState(() {
      isLoading = true;
    });
    print('Updating users for process $processName: $users');
    try {
      print('Updating users for process $processName: $users');
      final processIndex =
          processes.indexWhere((p) => p['name'] == processName);
      if (processIndex == -1) {
        print('Process $processName not found');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('${loc.process} $processName ${loc.notfound} ')),
        );
        return;
      }
      final process = processes[processIndex];
      final userObjects = users
          .map((userName) => operators.firstWhere(
                (op) => op['name'] == userName,
                orElse: () => {
                  'id': 0,
                  'name': userName,
                  'alfadock_id': 0,
                  'staff_name': '',
                },
              ))
          .toList();
      setState(() {
        selectedUsers[processName] = users;
        processes[processIndex]['users2'] = userObjects;
      });
      print('userObjects: ${jsonEncode(userObjects)}');
      final response = await updateProcessUsers(
        pid: int.parse(widget.processData['id'].toString()),
        erpUrlBase: widget.erpUrlBase,
        id: process['id']?.toString() ?? '',
        name: processName,
        qty: process['qty']?.toString() ?? '0',
        users: userObjects,
        userId: widget.userId ?? '0',
        userIdNameMap: userIdNameMap,
        rawusers: users,
        userIdToStaffNameMap: userIdToStaffNameMap,
      );
      print('Update users response for $processName: ${jsonEncode(response)}');
      await _fetchUpdatedProcessStatus(processName);
    } catch (e) {
      print('Error updating users for process $processName: $e');
      // ScaffoldMessenger.of(context).showSnackBar(
      //   SnackBar(content: Text('${loc.failedto} $processName: $e')),
      // );
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  int _getRemainingQuantity() {
    final initialQuantity =
        int.tryParse(widget.processData['quantity']?.toString() ?? '25') ?? 25;
    final doneProcesses =
        processes.where((p) => p['status'] == 'done').toList();
    final usedQuantity = doneProcesses.fold<int>(
        0,
        (sum, process) =>
            sum + (int.tryParse(process['qty']?.toString() ?? '0') ?? 0));
    return (initialQuantity - usedQuantity).clamp(0, initialQuantity);
  }

  Future<void> _adjustDoneProcessesQuantities() async {
    final initialQuantity =
        int.tryParse(widget.processData['quantity']?.toString() ?? '25') ?? 25;
    final doneProcesses =
        processes.where((p) => p['status'] == 'done').toList();
    int totalDoneQuantity = doneProcesses.fold<int>(
        0,
        (sum, process) =>
            sum + (int.tryParse(process['qty']?.toString() ?? '0') ?? 0));
    if (totalDoneQuantity <= initialQuantity) return;
    doneProcesses.sort((a, b) => (a['name'] as String).compareTo(b['name']));
    int remainingQuantity = initialQuantity;
    for (var process in doneProcesses) {
      final processName = process['name'] as String;
      final currentQty = int.tryParse(process['qty']?.toString() ?? '0') ?? 0;
      final newQty = currentQty.clamp(0, remainingQuantity);
      remainingQuantity -= newQty;
      if (newQty != currentQty) {
        print(
            'Adjusting quantity for $processName from $currentQty to $newQty');
        await _updateQuantity(processName, newQty, false);
      }
    }
  }

// Add these separate timer functions for AlfaDock

  void _startProcess(String processName) async {
    flag = 1;
    setState(() {
      elapsedSeconds[processName] = 0;
      _saveElapsedSeconds(processName, 0);
    });
    print('Starting process $processName');

    await _updateProcessStatus('progress', processName);
  }

  void _pauseProcess(String processName) async {
    print('Pausing process $processName');
    await _updateProcessStatus('pause', processName);
  }

  void _resumeProcess(String processName) async {
    flag = 1;
    print('Resuming process $processName');

    await _updateProcessStatus('resume', processName);
  }

  void _stopProcess(String processName) async {
    print('Stopping process $processName');
    await _updateProcessStatus('done', processName);
  }

  String _formatTime(int totalSeconds) {
    totalSeconds = totalSeconds.clamp(0, double.infinity).toInt();
    int hours = totalSeconds ~/ 3600;
    int minutes = (totalSeconds % 3600) ~/ 60;
    int secs = totalSeconds % 60;
    return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  void _showSelectionModal({
    required BuildContext context,
    required String processName,
    required String title,
    required List<String> options,
    required dynamic currentSelection,
    required Function(dynamic) onDone,
    bool isMultiSelect = false,
  }) {
    final loc = AppLocalizations.of(context);
    dynamic tempSelection = isMultiSelect
        ? List<String>.from(currentSelection ?? [])
        : currentSelection;
    print('Showing selection modal for $title with options: $options');
    print('Current selection: $currentSelection');

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(16),
        ),
      ),
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            return Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: Text(loc.cancel),
                      ),
                      Text(
                        title,
                        style: const TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      TextButton(
                        onPressed: () {
                          onDone(tempSelection);
                          if (isMultiSelect) {
                            setState(() {
                              selectedUsers[processName] =
                                  List<String>.from(tempSelection ?? []);
                            });
                            if (widget.erpUrlBase ==
                                "https://www.alfadock-pack.com") {
                              print(
                                  'Updating users for alfa$processName: ${selectedUsers[processName]}');
                              print('Updating users for $userIdNameMap');
                              _updateProcessUsers(processName,
                                  selectedUsers[processName] ?? []);
                            } else {
                              print(
                                  'Updating users for non-alfa $processName: ${selectedUsers[processName]}');
                              _updateProcessUsers(processName,
                                  selectedUsers[processName] ?? []);
                            }
                          } else if (title == 'Select Assembly Type') {
                            setState(() {
                              selectedAssemblyTypes[processName] =
                                  tempSelection;
                              print(
                                  'Selected assembly type for ${selectedAssemblyTypes[processName]}');
                            });
                            _updateProcessMachine(processName, tempSelection);
                            _saveSelectedAssemblyTypes();
                          } else if (title == 'Select Defect Code') {
                            setState(() {
                              selectedDefects[processName] = tempSelection;
                              print(
                                  'Selected defect code for ${selectedDefects[processName]}');
                            });
                            if (widget.erpUrlBase ==
                                "https://www.alfadock-pack.com") {
                              final processIndex = processes
                                  .indexWhere((p) => p['name'] == processName);
                              if (processIndex != -1) {
                                final process = processes[processIndex];
                                print('Updating defect code for $processName');
                                _updateQuantity(
                                    processName, process['qty'] ?? 0, false);
                              } else {
                                print(
                                    'Process $processName not found for defect code update');
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                      content: Text(
                                          '${loc.process} $processName ${loc.notfound} ')),
                                );
                              }
                            } else {
                              final processIndex = processes
                                  .indexWhere((p) => p['name'] == processName);
                              if (processIndex != -1) {
                                final process = processes[processIndex];
                                print('Updating defect code for $processName');
                                _updateQuantity(
                                    processName, process['qty'] ?? 0, false);
                              } else {
                                print(
                                    'Process $processName not found for defect code update');
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                      content: Text(
                                          '${loc.process} $processName ${loc.notfound} ')),
                                );
                              }
                            }
                          }
                          Navigator.pop(context);
                        },
                        child: Text(loc.done),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (isMultiSelect)
                    Expanded(
                      child: ListView(
                        children: options.map((String value) {
                          return CheckboxListTile(
                            title: Text(value),
                            value:
                                (tempSelection as List<String>).contains(value),
                            onChanged: (bool? selected) {
                              setModalState(() {
                                if (selected == true) {
                                  if (!(tempSelection as List<String>)
                                      .contains(value)) {
                                    (tempSelection as List<String>).add(value);
                                  }
                                } else {
                                  (tempSelection as List<String>).remove(value);
                                }
                              });
                            },
                          );
                        }).toList(),
                      ),
                    )
                  else
                    DropdownButtonFormField<String>(
                      decoration: InputDecoration(
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8)),
                        labelText: title,
                      ),
                      value: tempSelection,
                      items: options.map((String value) {
                        return DropdownMenuItem<String>(
                          value: value,
                          child: Text(value),
                        );
                      }).toList(),
                      onChanged: (newValue) {
                        setModalState(() {
                          tempSelection = newValue;
                        });
                      },
                    ),
                  const SizedBox(height: 16),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _removeUser(String processName, String user) async {
    setState(() {
      print('Removing user $user from process $processName');
      selectedUsers[processName] =
          List<String>.from(selectedUsers[processName] ?? [])..remove(user);

      // ✅ Mark this process as manually removed so default won't auto-add again
      _defaultUserManuallyRemoved.add(processName);

      print(
          'Updated selected users for $processName: ${selectedUsers[processName]}');
    });

    if (widget.erpUrlBase == "https://www.alfadock-pack.com") {
      final result = await removeUserApi(
        processName: processName,
        user: user,
        userNameToRecordIdMap: userNameToRecordIdMap,
        numberInNameToIdMap: numberInNameToIdMap,
      );
      if (result['status'] == 'failure') {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result['message'] ?? 'Failed to remove user')),
        );
      } else {
        await _fetchUpdatedProcessStatus(processName);
      }
    } else {
      _updateProcessUsers(processName, selectedUsers[processName] ?? []);
    }
  }

  Future<void> _fetchInitialProcessStatus() async {
    setState(() {
      isLoading = true;
    });
    try {
      await _fetchUpdatedProcessStatus();
      for (var process in processes) {
        final processName = process['name'] as String;
        if (widget.erpUrlBase != "https://www.alfadock-pack.com") {
          final savedSeconds = await _loadElapsedSeconds(processName);
          if (savedSeconds > 0 && process['status'] != 'progress') {
            setState(() {
              elapsedSeconds[processName] = savedSeconds;
              process['duration'] = _formatTime(savedSeconds);

              print('initial elapsed seconds for $processName: $savedSeconds');
            });
          }
        } else {
          print('process: ${process['defect_codes']}');
          assemblyTypes = process['defect_codes'];
        }
        final machineName = widget.processData['machineName']?.toString();
        if (machineName != null && !assemblyTypes.contains(machineName)) {
          assemblyTypes.add(machineName);
          machines.add({'id': machineName, 'name': machineName});
        }
        selectedAssemblyTypes[processName] = assemblyTypes.contains(machineName)
            ? machineName
            : selectedAssemblyTypes[processName];
      }
      await _saveSelectedAssemblyTypes();
    } catch (e) {
      setState(() {
        processes = [
          {
            'id': '',
            'name': 'SP1', // Changed from 'sp1' to 'SP1'
            'qty': int.tryParse(
                    widget.processData['quantity']?.toString() ?? '0') ??
                0,
            'defect_qty': 0,
            'status': 'ready',
            'duration': '00:00:00',
            'date_start': null,
            'date_end': null,
            'users2': [],
          }
        ];
        for (var process in processes) {
          final processName = process['name'];
          _stopTimer(processName);
          elapsedSeconds[processName] = 0;
          selectedUsers[processName] = selectedUsers[processName] ?? [];
          final machineName = widget.processData['machineName']?.toString();
          if (machineName != null && !assemblyTypes.contains(machineName)) {
            assemblyTypes.add(machineName);
            machines.add({'id': machineName, 'name': machineName});
          }
          selectedAssemblyTypes[processName] =
              assemblyTypes.contains(machineName) ? machineName : null;
          selectedDefects[processName] = selectedDefects[processName];
        }
      });
      _saveSelectedAssemblyTypes();
      // Create SP1 via API if no response
      await _createNewSubProcess();
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<DateTime?> convertServerTimeToIST(String serverTime) async {
    try {
      // Parse server time assuming it's in UTC
      final format = DateFormat('M/d/yy h:mm:ss a');
      final parsedUtcTime =
          format.parse(serverTime, true).toUtc(); // parsed as UTC
      // Add IST offset (UTC + 5:30)
      final istTime = parsedUtcTime.add(const Duration(hours: 5, minutes: 30));
      print('Server Time (UTC): $parsedUtcTime');
      // print('Converted IST Time: $istTime');
      return istTime;
    } catch (e) {
      print('Error converting time: $e');
      return null;
    }
  }

  Future<void> _fetchUpdatedProcessStatus([String? targetProcessName]) async {
    final loc = AppLocalizations.of(context);
    setState(() {
      isLoading = true;
    });
    try {
      final response = await submitProcessStatus(
        pid: int.parse(widget.processData['id'].toString()),
        erpUrlBase: widget.erpUrlBase,
        userId: widget.userId ?? '0',
      );
      final submitProcessList = response['value']?['submitProcessList'];
      if (submitProcessList != null && submitProcessList is List) {
        for (var process in submitProcessList) {
          final numberInName = process['numberInName'];
          final id = process['id'];
          if (numberInName != null && id != null) {
            numberInNameToIdMap[numberInName] = id;
          }
          final users = process['users'];
          if (users != null && users is List) {
            for (var user in users) {
              final name = user['name'];
              final recordId = user['recordId'];
              if (name != null && recordId != null) {
                userNameToRecordIdMap[name] = recordId;
              }
            }
          }
        }
      }
      print('numberInNameToIdMap: $numberInNameToIdMap');
      print("User Name to Record ID Map: $userNameToRecordIdMap");
      print(
          'submitProcessStatus responssdsdse for pid=${widget.processData['id']}: ${jsonEncode(response)}');

      if (widget.erpUrlBase == "https://www.alfadock-pack.com") {
        globaldockid = response['value']?['processDefId'];
        print('globaldockid: $globaldockid');
        if (response['value'] == null ||
            response['value']['submitProcessList'] == null ||
            (response['value']['submitProcessList'] as List).isEmpty) {
          if (processes.isEmpty && targetProcessName == null) {
            processes = [
              {
                'id': '',
                'name': 'SP1',
                'qty': int.tryParse(
                        widget.processData['quantity']?.toString() ?? '0') ??
                    0,
                'defect_qty': 0,
                'status': 'ready',
                'duration': '00:00:00',
                'date_start': null,
                'date_end': null,
                'users2': [],
              }
            ];
            for (var process in processes) {
              final processName = process['name'];
              _stopTimer(processName);
              elapsedSeconds[processName] = 0;
              selectedUsers[processName] = selectedUsers[processName] ?? [];
              print(
                  'selecteduserssds[$processName]: ${selectedUsers[processName]}');
              // final machineName = widget.processData['machineName']?.toString();
              // if (machineName != null && !assemblyTypes.contains(machineName)) {
              //   assemblyTypes.add(machineName);
              //   machines.add({'id': machineName, 'name': machineName});
              // }
              // selectedAssemblyTypes[processName] =
              //     assemblyTypes.contains(machineName) ? machineName : null;
              // selectedDefects[processName] = selectedDefects[processName];
              // print(
              //     'Selected assembly type for ${selectedAssemblyTypes[processName]}');
            }
            _saveSelectedAssemblyTypes();
          }
          setState(() {}); // Trigger rebuild if needed
          return;
        }
        final records = List<Map<String, dynamic>>.from(
            response['value']['submitProcessList']);
        print('records: ${jsonEncode(records)}');
        final List<dynamic> machineList = response["value"]["machines"];

        machinesdock = machineList.map((m) {
          return {
            "id": m["id"],
            "name": m["name"],
          };
        }).toList();

        List<String> assemblyTypes =
            machinesdock.map((m) => m["name"].toString()).toList();
        print('fetchupdatedstatus: $machinesdock $machineList $assemblyTypes');
        if (targetProcessName != null) {
          final record = records.firstWhere(
            (r) =>
                r['numberInName']?.toString() ==
                    targetProcessName.replaceFirst('SP', '') ||
                r['id']?.toString() ==
                    processes.firstWhere((p) => p['name'] == targetProcessName,
                        orElse: () => {})['id'],
            orElse: () => {},
          );
          if (record.isNotEmpty) {
            final processIndex =
                processes.indexWhere((p) => p['name'] == targetProcessName);
            final processName = 'SP${record['numberInName'] ?? 1}';
            print('jasasa$processName');
            final status = _mapAlfaDockStatus(record['currentStatus']);
            final startDateTimeStr = record['startTime']?.toString();
            print('record : ${jsonEncode(record)}');
            print('startDateTimeStr: $startDateTimeStr');
            DateTime? startDateTime;
            if (startDateTimeStr != null) {
              try {
                startDateTime = DateFormat("MM/dd/yy h:mm:ss a")
                    .parse(startDateTimeStr); // Parse "10/3/24 4:26:36 AM"
                print('Parsed startDateTimejana: $startDateTime');
              } catch (e) {
                print('Error parsing startDateTime: $e');
                startDateTime = null; // Fallback to null if parsing fails
              }
            }
            print('startDateTime: $startDateTime');
            final accumulatedDuration =
                _parseDuration(record['duration'] ?? '00:00:00');
            print('accumulatedDuration: $accumulatedDuration');
            final savedSeconds = elapsedSeconds[processName] ?? 0;
            final machineName = record['machineName'] as String?;
            final defectCode = record['defectCode'] as String?;
            final sid = record['id'] as int? ?? 0; // Use the process ID as sid
            print('sid: $sid');
            int newDurationSeconds = 0;
            int pausedDurationSeconds = 0;
            if (sid > 0) {
              final spDetails = await getspdetails(
                sid: sid,
                erpUrlBase: widget.erpUrlBase,
                userId: widget.userId ?? '0',
              );
              final lastStartTime = spDetails['value']?['lastStartTime'];
              final Duration =
                  spDetails['value']?['durationBeforeResume'] ?? '00:00:00';
              print('Duration before resume: $Duration');
              print(_formatTime(Duration));
              final startTimeStr =
                  record['startTime']?.toString(); // Changed from finishTime
              print('lastStartTime for sid $sid: $lastStartTime');
              if (lastStartTime != null) {
                // Keep newDurationSeconds as Duration (unchanged as requested)
                newDurationSeconds = Duration;
                print(
                    'New duration (seconds) from lastStartTime to now: $newDurationSeconds');

                // Calculate pausedDurationSeconds for timer resume
                String fixedTime = lastStartTime.endsWith('Z')
                    ? lastStartTime
                    : '${lastStartTime}Z';
                final lastStartUtc = DateTime.parse(fixedTime);
                final lastStartLocal = lastStartUtc.toLocal();
                print('duration UTC: $lastStartUtc');
                print('duration Local (IST): $lastStartLocal');
                print('duration lastStart: $lastStartLocal');
                final currentTime = DateTime.now();
                print('duration currentTime: $currentTime');

                final newdura =
                    currentTime.difference(lastStartLocal).inSeconds;
                print(
                    'duration (seconds) from lastStartTime to now newdura: $newdura');

                // pausedDurationSeconds = Duration + time since last start (for resume)
                pausedDurationSeconds = (((newdura + Duration)).toInt())
                    .clamp(0, double.infinity)
                    .toInt();

                print(
                    'pausedDurationSeconds for timer resume: $pausedDurationSeconds');
              }
              print('machineId: ${record['machineId']}');
              // Compare lastStartTime with startTime if currentStatus == 2
              if (record['currentStatus'] == 2 && startTimeStr != null) {
                DateTime? startTime;
                try {
                  startTime = DateFormat("MM/dd/yy h:mm:ss a")
                      .parse(startTimeStr); // Parse "10/3/24 4:26:36 AM"
                  print('startTime: $startTime');
                } catch (e) {
                  print('Error parsing startTime: $e');
                  // No fallback needed here, just log the error
                }

                // if (startTime != null && lastStartTime != null) {
                //   final lastStart = DateTime.parse(lastStartTime);
                //   final durationFromStartToLastStart =
                //       lastStart.difference(startTime).inSeconds;
                //   print(
                //       'Duration (seconds) from startTime to lastStartTime: $durationFromStartToLastStart');
                //   // Use this duration if it's positive and makes sense for the context
                //   if (durationFromStartToLastStart > 0) {
                //     newDurationSeconds = durationFromStartToLastStart;
                //   }
                // }
              }
            }
            // if (machineName != null && !assemblyTypes.contains(machineName)) {
            //   assemblyTypes.add(machineName);
            //   machines.add({'id': machineName, 'name': machineName});
            // }
            final updatedProcess = {
              'id': record['id']?.toString() ??
                  (processIndex != -1 ? processes[processIndex]['id'] : ''),
              'name': processName,
              'qty': record['quantity'] ??
                  (processIndex != -1 ? processes[processIndex]['qty'] : 25),
              'defect_qty': record['defectQuantity'] ??
                  (processIndex != -1
                      ? processes[processIndex]['defect_qty']
                      : 0),
              'status': status,
              'duration': status == 'ready'
                  ? '00:00:00'
                  : _formatTime(newDurationSeconds > 0
                      ? newDurationSeconds
                      : (savedSeconds > 0
                          ? savedSeconds
                          : accumulatedDuration)),
              'date_start': record['startTime']?.toString(),
              'date_end': status == 'ready'
                  ? null
                  : (record['finishTime'] ??
                      (processIndex != -1
                          ? processes[processIndex]['finishTime']
                          : null)),
              'users2': (record['users'] as List<dynamic>?)?.map((user) {
                    return operators.firstWhere(
                      (op) =>
                          op['id'] == user['id'] && op['name'] == user['name'],
                      orElse: () => {
                        'id': user['id'] ?? 0,
                        'name': user['name'] ?? '',
                        'alfadock_id': user['id'] ?? 0,
                        'staff_name': user['staff_name'] ?? '',
                      },
                    );
                  }).toList() ??
                  (processIndex != -1 ? processes[processIndex]['users2'] : []),
              'defect_codes': assemblyTypes,
              'machinedock': machinesdock,
              'machinedockid': record['machineId'] ?? null,
            };
            print(
                'updatedProcessjana: ${jsonEncode(updatedProcess)}parsedfuration $pausedDurationSeconds newDurationSeconds $newDurationSeconds');
            if (processIndex != -1) {
              processes[processIndex] = updatedProcess;
            } else {
              processes.add(updatedProcess);
            }
            if (status == 'resume' || status == 'progress') {
              // Determine which duration to use based on the scenario
              int timerStartSeconds = pausedDurationSeconds;

              _startTimer(
                processName,
                startDateTime ??
                    (updatedProcess['date_start'] != null
                        ? DateTime.parse(updatedProcess['date_start'])
                        : DateTime.now()),
                timerStartSeconds,
              );
            } else {
              _stopTimer(processName);
              // For non-progress status, use the appropriate duration for display
              elapsedSeconds[processName] = status == 'ready'
                  ? 0
                  : (newDurationSeconds > 0
                      ? newDurationSeconds
                      : (savedSeconds > 0
                          ? savedSeconds
                          : accumulatedDuration));
              _saveElapsedSeconds(
                  processName, elapsedSeconds[processName] ?? 0);
            }
            print(updatedProcess);
            final apiUsers = (record['users'] as List<dynamic>?)
                    ?.map((user) => user['name'] as String)
                    .toList() ??
                [];
            print('selectedusers12[$processName]: $apiUsers');
            selectedUsers[processName] = apiUsers;
            selectedAssemblyTypes[processName] =
                assemblyTypes.contains(machineName)
                    ? machineName
                    : (selectedAssemblyTypes[processName]);
            selectedDefects[processName] = defectTypes.contains(defectCode)
                ? defectCode
                : (selectedDefects[processName]);
            setState(() {}); // Update state after changes
          }
        } else {
          processes = [];
          for (var record in records) {
            final processName = 'SP${record['numberInName'] ?? 1}';
            final status = _mapAlfaDockStatus(record['currentStatus']);
            final startDateTimeStr = record['startTime']?.toString();
            print('${record['startTime']}');
            print('startDateTimeStr: $startDateTimeStr');
            DateTime? startDateTime;
            if (startDateTimeStr != null) {
              try {
                startDateTime = DateFormat("MM/dd/yy h:mm:ss a")
                    .parse(startDateTimeStr); // Parse "10/3/24 4:26:36 AM"
              } catch (e) {
                print('Error parsing startDateTime: $e');
                startDateTime = null; // Fallback to null if parsing fails
              }
            }
            print('startDateTime: $startDateTime');
            final accumulatedDuration =
                _parseDuration(record['duration'] ?? '00:00:00');
            final savedSeconds = elapsedSeconds[processName] ?? 0;
            final machineName = record['machineName'] as String?;
            final defectCode = record['defectCode'] as String?;
            final sid = record['id'] as int? ?? 0; // Use the process ID as sid
            int newDurationSeconds = 0;
            int pausedDurationSeconds = 0;
            if (sid > 0) {
              final spDetails = await getspdetails(
                sid: sid,
                erpUrlBase: widget.erpUrlBase,
                userId: widget.userId ?? '0',
              );
              final lastStartTime = spDetails['value']?['lastStartTime'];
              final startTimeStr =
                  record['startTime']?.toString(); // Changed from finishTime
              print(spDetails);
              final Duration =
                  spDetails['value']?['durationBeforeResume'] ?? '00:00:00';
              print('Duration before resume: $Duration');

              print('lastStartTime for sid $sid: $lastStartTime');
              if (lastStartTime != null) {
                // Keep newDurationSeconds as Duration (unchanged as requested)
                newDurationSeconds = Duration;
                print(
                    'New duration (seconds) from lastStartTime to now: $newDurationSeconds');
                print("lastStartTime $lastStartTime");
                // Calculate pausedDurationSeconds for timer resume
                String fixedTime = lastStartTime.endsWith('Z')
                    ? lastStartTime
                    : '${lastStartTime}Z';
                final lastStartUtc = DateTime.parse(fixedTime);
                final lastStartLocal = lastStartUtc.toLocal();
                print('duration UTC: $lastStartUtc');
                print('duration Local (IST): $lastStartLocal');
                print('duration lastStart: $lastStartLocal');
                final currentTime = DateTime.now();
                print('duration currentTime: $currentTime');

                final newdura =
                    currentTime.difference(lastStartLocal).inSeconds;
                print(
                    'duration (seconds) from lastStartTime to now newdura: $newdura');

                // pausedDurationSeconds = Duration + time since last start (for resume)
                pausedDurationSeconds = (((newdura + Duration)).toInt())
                    .clamp(0, double.infinity)
                    .toInt();
                newDurationSeconds = Duration;
                print(
                    'pausedDurationSeconds for timer resume: $pausedDurationSeconds');
              }
              // Compare lastStartTime with startTime if currentStatus == 2
              if (record['currentStatus'] == 2 && startTimeStr != null) {
                DateTime? startTime;
                try {
                  startTime = DateFormat("MM/dd/yy h:mm:ss a")
                      .parse(startTimeStr); // Parse "10/3/24 4:26:36 AM"
                  print('startTime: $startTime');
                } catch (e) {
                  print('Error parsing startTime: $e');
                  // No fallback needed here, just log the error
                }
                if (startTime != null && lastStartTime != null) {
                  final lastStart = DateTime.parse(lastStartTime);
                  final durationFromStartToLastStart =
                      lastStart.difference(startTime).inSeconds;
                  print(
                      'Duration (seconds) from startTime to lastStartTime: $durationFromStartToLastStart');
                  // Use this duration if it's positive and makes sense for the context
                  if (durationFromStartToLastStart > 0) {
                    newDurationSeconds = durationFromStartToLastStart;
                  }
                }
              }
            }
            // if (machineName != null && !assemblyTypes.contains(machineName)) {
            //   assemblyTypes.add(machineName);
            //   machines.add({'id': machineName, 'name': machineName});
            // }
            print('machineId: ${record['machineId']}');
            print("jana record quantity ${record['quantity']}");
            final updatedProcess = {
              'id': record['id']?.toString() ?? '',
              'name': processName,
              'qty': record['quantity'] ?? 25,
              'defect_qty': record['defectQuantity'] ?? 0,
              'status': status,
              'duration': status == 'ready'
                  ? '00:00:00'
                  : _formatTime(newDurationSeconds > 0
                      ? newDurationSeconds
                      : (savedSeconds > 0
                          ? savedSeconds
                          : accumulatedDuration)),
              'date_start': record['startTime']?.toString(),
              'date_end': status == 'ready' ? null : record['finishTime'],
              'users2': (record['users'] as List<dynamic>?)?.map((user) {
                    return operators.firstWhere(
                      (op) =>
                          op['id'] == user['id'] && op['name'] == user['name'],
                      orElse: () => {
                        'id': user['id'] ?? 0,
                        'name': user['name'] ?? '',
                        'alfadock_id': user['id'] ?? 0,
                        'staff_name': user['staff_name'] ?? '',
                      },
                    );
                  }).toList() ??
                  [],
              'defect_codes': assemblyTypes,
              'machinedock': machinesdock,
              'machinedockid': record['machineId'] ?? null,
            };
            print(
                'updatedProcesskama: ${jsonEncode(updatedProcess)}parsedfuration $pausedDurationSeconds newDurationSeconds $newDurationSeconds');
            processes.add(updatedProcess);
            if (status == 'progress' || status == 'resume') {
              // Determine which duration to use based on the scenario
              int timerStartSeconds = pausedDurationSeconds;
              print(
                  'Using pausedDurationSeconds for resume: $pausedDurationSeconds');

              _startTimer(
                processName,
                startDateTime ??
                    (updatedProcess['date_start'] != null
                        ? DateTime.parse(updatedProcess['date_start'])
                        : DateTime.now()),
                timerStartSeconds,
              );
            } else {
              _stopTimer(processName);
              // For non-progress status, use the appropriate duration for display
              elapsedSeconds[processName] = status == 'ready'
                  ? 0
                  : (newDurationSeconds > 0
                      ? newDurationSeconds
                      : (savedSeconds > 0
                          ? savedSeconds
                          : accumulatedDuration));
              _saveElapsedSeconds(
                  processName, elapsedSeconds[processName] ?? 0);
            }
            print('record[$processName]: ${jsonEncode(record)}');
            final apiUsers = (record['users'] as List<dynamic>?)
                    ?.map((user) => user['name'] as String)
                    .toList() ??
                [];
            print('selectedusers1[$processName]: $apiUsers');
            selectedUsers[processName] = apiUsers;
            if (widget.erpUrlBase == "https://www.alfadock-pack.com") {
              final apiUsers = (record['users'] as List<dynamic>?)
                      ?.map((user) => user['id'] as int)
                      .toList() ??
                  [];
              selectedUsersalfa[processName] = apiUsers;
              print(
                  'selectedusersalfa[$processName]: ${selectedUsersalfa[processName]}');
            }
            print('assemblyTypesfetch up: $assemblyTypes');
            // selectedAssemblyTypes[processName] =
            //     assemblyTypes.contains(machineName)
            //         ? machineName
            //         : (selectedAssemblyTypes[processName]);
            selectedDefects[processName] = defectTypes.contains(defectCode)
                ? defectCode
                : (selectedDefects[processName]);
          }
          setState(() {}); // Update state after loop
        }
      } else {
        if (response['records'] == null ||
            response['records'].isEmpty ||
            response['records'][0]['status'] == null) {
          if (processes.isEmpty && targetProcessName == null) {
            processes = [
              {
                'id': '',
                'name': 'SP1',
                'qty': int.tryParse(
                        widget.processData['quantity']?.toString() ?? '0') ??
                    0,
                'defect_qty': 0,
                'status': 'ready',
                'duration': '00:00:00',
                'date_start': null,
                'date_end': null,
                'users2': [],
              }
            ];
            for (var process in processes) {
              final processName = process['name'];
              _stopTimer(processName);
              elapsedSeconds[processName] = 0;
              selectedUsers[processName] = selectedUsers[processName] ?? [];
              print(
                  'selectedusersqwe[$processName]: ${selectedUsers[processName]}');
              final machineName = widget.processData['machineName']?.toString();
              print('machineNameasa: $machineName');
              if (machineName != null && !assemblyTypes.contains(machineName)) {
                assemblyTypes.add(machineName);
                machines.add({'id': machineName, 'name': machineName});
              }
              selectedAssemblyTypes[processName] =
                  selectedAssemblyTypes[processName];
              selectedDefects[processName] = selectedDefects[processName];
            }
          }
          _saveSelectedAssemblyTypes();
          setState(() {}); // Trigger rebuild if needed
          return;
        }
        final records = List<Map<String, dynamic>>.from(response['records']);
        if (targetProcessName != null) {
          final record = records.firstWhere(
            (r) =>
                r['name']?.toUpperCase() == targetProcessName ||
                r['id']?.toString() ==
                    processes.firstWhere((p) => p['name'] == targetProcessName,
                        orElse: () => {})['id'],
            orElse: () => {},
          );
          if (record.isNotEmpty) {
            print("jana $record");
            final processIndex =
                processes.indexWhere((p) => p['name'] == targetProcessName);
            final status =
                record['status'] == 'resume' ? 'progress' : record['status'];
            final machineName = record['machine_name'] as String?;
            final defectCodeIdStr = record['defect_code_id']?.toString();
            final defectCodeId =
                defectCodeIdStr != null && defectCodeIdStr.isNotEmpty
                    ? int.tryParse(defectCodeIdStr)
                    : null;
            print('defectIdToNameMap: $defectIdToNameMap');
            final defectReason =
                defectCodeId != null ? defectIdToNameMap[defectCodeId] : null;
            print('defectReasonjana: $defectReason');
            final accumulatedDuration = _parseDuration(record['duration']);
            print('accumulatedDuration: $accumulatedDuration');
            final savedSeconds = elapsedSeconds[targetProcessName] ?? 0;
            if (machineName != null && !assemblyTypes.contains(machineName)) {
              assemblyTypes.add(machineName);
              machines.add({'id': machineName, 'name': machineName});
            }
            final updatedProcess = {
              'id': record['id']?.toString() ?? processes[processIndex]['id'],
              'name': targetProcessName,
              'qty': record['qty'] ?? processes[processIndex]['qty'],
              'defect_qty':
                  record['defect_qty'] ?? processes[processIndex]['defect_qty'],
              'status': status,
              'duration': status == 'ready'
                  ? '00:00:00'
                  : _formatTime(
                      savedSeconds > 0 ? savedSeconds : accumulatedDuration),
              'date_start': record['initial_date_start_UTC'] ??
                  processes[processIndex]['date_start'],
              'date_end': status == 'ready'
                  ? null
                  : (record['date_end_UTC'] ??
                      processes[processIndex]['date_end']),
              'users2': (record['users2'] as List<dynamic>?)?.map((user) {
                    return operators.firstWhere(
                      (op) =>
                          op['id'] == user['id'] && op['name'] == user['name'],
                      orElse: () => {
                        'id': user['id'],
                        'name': user['name'],
                        'alfadock_id': user['id'] ?? 0,
                        'staff_name': user['staff_name'] ?? '',
                      },
                    );
                  }).toList() ??
                  processes[processIndex]['users2'] ??
                  [],
              'defect_codes': assemblyTypes,
              'machinedock': machinesdock,
              'machinedockid': record['machineId'] ?? null,
            };
            print('Updated process: ${jsonEncode(updatedProcess)}');
            processes[processIndex] = updatedProcess;
            final currentStatus = status?.toString() ?? 'ready';
            final startDateTime = record['date_start'] != null
                ? DateTime.tryParse(record['date_start'].toString())
                : (updatedProcess['date_start'] != null
                    ? DateTime.parse(updatedProcess['date_start'])
                    : null);
            print("one $startDateTime");
            if (currentStatus == 'progress') {
              _startTimer(
                targetProcessName,
                startDateTime ??
                    (updatedProcess['date_start'] != null
                        ? DateTime.parse(updatedProcess['date_start'])
                        : DateTime.now()),
                savedSeconds > 0 ? savedSeconds : accumulatedDuration,
              );
            } else {
              _stopTimer(targetProcessName);
              elapsedSeconds[targetProcessName] = currentStatus == 'ready'
                  ? 0
                  : (savedSeconds > 0 ? savedSeconds : accumulatedDuration);
              _saveElapsedSeconds(
                  targetProcessName, elapsedSeconds[targetProcessName] ?? 0);
            }
            final apiUsers = (record['users2'] as List<dynamic>?)
                    ?.map((user) => user['name'] as String)
                    .toList() ??
                [];
            selectedUsers[targetProcessName] = apiUsers;
            selectedAssemblyTypes[targetProcessName] =
                machineName ?? selectedAssemblyTypes[targetProcessName];
            selectedDefects[targetProcessName] =
                defectTypes.contains(defectReason)
                    ? defectReason
                    : selectedDefects[targetProcessName];
            setState(() {}); // Update state after changes
          }
        } else {
          processes = [];
          for (var record in records) {
            print('record123: ${jsonEncode(record)}');
            final processName =
                (record['name'] ?? 'SP1').toString().toUpperCase();
            final status =
                record['status'] == 'resume' ? 'progress' : record['status'];
            final machineName = record['machine_name'] as String?;
            print('machineName123: $machineName');
            if (machineName != null && !assemblyTypes.contains(machineName)) {
              assemblyTypes.add(machineName);
              machines.add(
                  {'id': machineName, 'name': machineName}); // Add to machines
            }
            final defectCodeIdStr = record['defect_code_id']?.toString();
            final defectCodeId =
                defectCodeIdStr != null && defectCodeIdStr.isNotEmpty
                    ? int.tryParse(defectCodeIdStr)
                    : null;
            final defectReason =
                defectCodeId != null ? defectIdToNameMap[defectCodeId] : null;
            final accumulatedDuration = _parseDuration(record['duration']);
            print('accumulatedDuration12: $accumulatedDuration');
            final savedSeconds = elapsedSeconds[processName] ?? 0;
            final updatedProcess = {
              'id': record['id']?.toString() ?? '',
              'name': processName,
              'qty': record['qty'] ?? 25,
              'defect_qty': record['defect_qty'] ?? 0,
              'status': status,
              'duration': status == 'ready'
                  ? '00:00:00'
                  : _formatTime(
                      savedSeconds > 0 ? savedSeconds : accumulatedDuration),
              'date_start': record['initial_date_start_UTC'],
              'date_end': status == 'ready' ? null : record['date_end_UTC'],
              'users2': (record['users2'] as List<dynamic>?)?.map((user) {
                    return operators.firstWhere(
                      (op) =>
                          op['id'] == user['id'] && op['name'] == user['name'],
                      orElse: () => {
                        'id': user['id'],
                        'name': user['name'],
                        'alfadock_id': user['id'] ?? 0,
                        'staff_name': user['staff_name'] ?? '',
                      },
                    );
                  }).toList() ??
                  [],
            };
            print('recordsd: ${jsonEncode(record)}');

            processes.add(updatedProcess);
            final currentStatus = status?.toString() ?? 'ready';
            final startDateTime = record['date_start'] != null
                ? DateTime.tryParse(record['date_start'].toString())
                : (updatedProcess['date_start'] != null
                    ? DateTime.parse(updatedProcess['date_start'])
                    : null);
            print('Updated process: ${jsonEncode(updatedProcess)}');
            print("two $startDateTime");
            if (currentStatus == 'progress' || currentStatus == 'resume') {
              // Calculate correct elapsed time from API for running timer
              final calculatedElapsed = _calculateElapsedTimeFromAPI(record);
              print('statuss $status currentstatus $currentStatus');
              _startTimer(
                processName,
                startDateTime ?? DateTime.now(),
                calculatedElapsed,
              );
            } else {
              print('statusifs $status currentstatus $currentStatus');
              _stopTimer(processName);

              // For paused status, store the duration in seconds for internal use
              // but the display will use the original API duration format
              if (status == 'pause') {
                print('statusif $status currentstatus $currentStatus');
                final durationSeconds = _parseDurationMinutesSeconds(
                    record['duration']?.toString());
                elapsedSeconds[processName] = durationSeconds;
              } else {
                // For other statuses, calculate normally
                print('statuselse $status currentstatus $currentStatus');
                final calculatedElapsed = _parseDurationMinutesSeconds(
                    record['duration']?.toString());
                elapsedSeconds[processName] = calculatedElapsed;
              }

              _saveElapsedSeconds(
                  processName, elapsedSeconds[processName] ?? 0);
            }
            final apiUsers = (record['users2'] as List<dynamic>?)
                    ?.map((user) => user['name'] as String)
                    .toList() ??
                [];
            print('apiUsers: $apiUsers');
            selectedUsers[processName] = apiUsers;
            selectedAssemblyTypes[processName] = machineName != 'Unknown'
                ? machineName
                : selectedAssemblyTypes[processName];
            selectedDefects[processName] = defectTypes.contains(defectReason)
                ? defectReason
                : selectedDefects[processName];
            print('processName: $processName');
            print('machineName34: $machineName');
            print('defectReason: $defectReason');
            print('assemblyTypes: $assemblyTypes');
            print('defectTypes: $defectTypes');
            print('selectedAssemblyTypes: $selectedAssemblyTypes');
            print('selectedDefects: $selectedDefects');
            print(
                'selectedDefectssdsds[$processName]: ${selectedDefects[processName]}');
          }
          setState(() {}); // Update state after loop
        }
      }
      processes.sort((a, b) => (a['name'] as String).compareTo(b['name']));
      setState(() {}); // Final state update after sorting
    } catch (e) {
      print('Error fetching updated process status: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${loc.failedto} $e')),
      );
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> _fetchFiles() async {
    print(widget.compId);
    print(widget.userId);
    print(widget.folderId);
    if (widget.compId == null ||
        widget.userId == null ||
        widget.folderId == null) {
      print('Error: Missing compId, userId, or folderId');
      return;
    }
    try {
      final response = await getAllInOutFiles(
        widget.compId!,
        widget.userId!,
        widget.folderId!,
      );
      setState(() {
        fileList = response;
      });
      print(
          'GetAllInOutFiles2 API called: compid=${widget.compId}, userid=${widget.userId}, folderid=${widget.folderId}');
      for (var file in fileList) {
        print('File Details:');
        print('fileName: ${file['fileName'] ?? 'null'}');
        print('thumbnailGuid: ${file['thumbnailGuid'] ?? 'null'}');
        print('------------------------');
      }
    } catch (e) {
      print('Error fetching files: $e');
      setState(() {
        fileList = [];
      });
    }
  }

  void _navigateToFolder(String folderId, String folderName) async {
    // Save current folder to stack

    setState(() {
      isLoading = true;
      folderStack.add({
        'folderId': widget.folderId ?? '',
        'folderName': currentFolderName,
      });
      currentFolderName = folderName;
    });
    // Use inItems for folder contents
    final folder = fileList.firstWhere(
      (file) => file['id'].toString() == folderId,
      orElse: () => {},
    );
    if (folder.isNotEmpty &&
        folder['inItems'] != null &&
        folder['inItems'].isNotEmpty) {
      print(widget.compId);
      print(widget.userId);
      print(widget.folderId);
      if (widget.compId == null ||
          widget.userId == null ||
          widget.folderId == null) {
        print('Error: Missing compId, userId, or folderId');
        return;
      }
      try {
        final response = await getAllInOutFiles(
          widget.compId!,
          widget.userId!,
          folder['id'].toString(),
        );
        setState(() {
          fileList = response;
        });
        print(
            'GetAllInOutFiles2 API called: compid=${widget.compId}, userid=${widget.userId}, folderid=${widget.folderId}');
        for (var file in fileList) {
          print("File $file");
          print('File Details:');

          print('fileName: ${file['fileName'] ?? 'null'}');
          print('thumbnailGuid: ${file['thumbnailGuid'] ?? 'null'}');
          print('------------------------');
        }
      } catch (e) {
        print('Error fetching files: $e');
        setState(() {
          fileList = [];
        });
      } finally {
        setState(() {
          isLoading = false;
        });
      }
    } else {
      setState(() {
        fileList = [];
        isLoading = false;
      });
      print('No inItems found for folder $folderName');
    }
  }

  // Navigate back to parent folder
  void _navigateBack() async {
    if (folderStack.isNotEmpty) {
      print('Navigating back to parent folder');
      final parentFolder = folderStack.removeLast();
      setState(() {
        currentFolderName = parentFolder['folderName']!;
        isLoading = true;
      });
      await _fetchFiles();
      setState(() {
        isLoading = false;
      });
    } else {
      print('Returning to root folder');
      setState(() {
        currentFolderName = 'Root';
        isLoading = true;
      });
      await _fetchFiles();
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> _setProcessForFile(String fileIdResponse, int processId) async {
    try {
      // Parse file ID from response (e.g., "fileid\n12345")
      print('File ID response: $fileIdResponse');
      print('Process ID: $processId');
      final splitArray = fileIdResponse.split('\n');
      print('Split array: $splitArray');
      if (splitArray.length < 2) {
        throw Exception('Invalid file ID response: $fileIdResponse');
      }
      final fileId = splitArray[1]; // Extract file ID
      print('Extracted file ID: $fileId');
      print('Associating file ID $fileId with process ID $processId');
      final uri =
          Uri.parse('https://www.alfadock-pack.com/api/file/setprocessforfile');
      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: {
          'fileid': fileId,
          'processid': processId.toString(),
        },
      );

      if (response.statusCode == 200) {
        print('File associated with process successfully: ${response.body}');
        print('response.body: ${response}');
        // Navigation is now handled in _uploadMedia, not here
      } else {
        throw Exception(
            'Failed to associate file with process: ${response.statusCode}');
      }
    } catch (e) {
      print('Error in setProcessForFile: $e');
    }
  }

  Future<void> _uploadMedia(File file) async {
    final loc = AppLocalizations.of(context);
    setState(() {
      isLoading = true;
    });

    final today = DateTime.now();
    final fileName = '${DateFormat('ddMMyyyyHHmmss').format(today)}.jpg';
    final fileLength = await file.length();

    print('Uploading file: $fileName, Length: $fileLength bytes, Type: Image');

    var request = http.MultipartRequest(
      'POST',
      Uri.parse('https://www.alfadock-pack.com/api/file/UploadFile'),
    );

    request.files.add(await http.MultipartFile.fromPath(
      'file',
      file.path,
      filename: 'camera.jpeg',
    ));

    print('File path: ${file.path}');
    print('File name: $fileName');
    print('userId: ${widget.userId}');
    print('compId: ${widget.compId}');
    print('folderId: ${widget.folderId}');

    // Set form fields
    request.fields['userid'] = widget.userId ?? '0';
    request.fields['filename'] = fileName;
    request.fields['replace'] = 'false';
    request.fields['compid'] = widget.compId ?? '0';
    request.fields['shared'] = 'false';
    request.fields['source'] = 'camera';
    request.fields['fileLength'] = fileLength.toString();
    request.fields['parentid'] = widget.folderId ?? '0';
    request.fields['ownerCompid'] = widget.compId ?? '0';

    try {
      final response = await request.send();
      final responseData = await response.stream.bytesToString();
      print('Upload response: $response');

      if (response.statusCode == 200) {
        print(widget.processData);
        if (responseData.isNotEmpty) {
          print(
              'Setting process for file with ID: ${widget.processData['id']}');
          print(
              'globalSchedulerdataAlfadock_id: $globalSchedulerdataAlfadock_id');

          if (widget.erpUrlBase == "https://www.alfadock-pack.com") {
            print('Using globaldockid: $globaldockid');
            await _setProcessForFile(responseData, globaldockid);
          } else {
            await _setProcessForFile(
                responseData, globalSchedulerdataAlfadock_id!);
          }

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('${loc.photoUploadedSucessfully}: $fileName'),
              ),
            );

            // Navigate to SubmitProcessPage - only navigate once here
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => SubmitProcessPage(
                  processData: widget.processData,
                  erpUrlBase: widget.erpUrlBase,
                  compId: widget.compId,
                  userId: widget.userId,
                  folderId: widget.folderId,
                ),
              ),
            );
          }
        } else {
          throw Exception('Empty response from server');
        }
      } else {
        throw Exception('Upload failed with status: ${response.statusCode}');
      }
    } catch (e) {
      print('Error uploading file: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${loc.failedto} : $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  Future<void> _openCamera() async {
    print("camera");
    final loc = AppLocalizations.of(context);

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) {
          return Scaffold(
            appBar: AppBar(
              title: Text(loc.takePhoto),
              backgroundColor: Colors.amber,
            ),
            body: CameraAwesomeBuilder.awesome(
              onMediaCaptureEvent: (event) async {
                switch ((event.status, event.isPicture, event.isVideo)) {
                  case (MediaCaptureStatus.capturing, true, false):
                    debugPrint('Capturing picture...');
                  case (MediaCaptureStatus.success, true, false):
                    // Photo captured successfully
                    event.captureRequest.when(
                      single: (single) async {
                        if (single.file != null && mounted) {
                          debugPrint('Picture saved: ${single.file!.path}');
                          // Close camera first, then upload
                          Navigator.pop(context);
                          await _uploadMedia(File(single.file!.path));
                        }
                      },
                      multiple: (multiple) async {
                        // Handle multiple captures if needed
                        for (var entry in multiple.fileBySensor.entries) {
                          if (entry.value != null && mounted) {
                            debugPrint(
                                'Multiple image taken: ${entry.key} ${entry.value!.path}');
                            // Close camera first, then upload
                            Navigator.pop(context);
                            await _uploadMedia(File(entry.value!.path));
                            break;
                          }
                        }
                      },
                    );
                  case (MediaCaptureStatus.failure, true, false):
                    debugPrint('Failed to capture picture: ${event.exception}');
                    if (mounted) {
                      _showErrorSnackbar(loc.failedto);
                    }
                  default:
                    debugPrint('Camera event: $event');
                }
              },
              saveConfig: SaveConfig.photo(
                pathBuilder: (sensors) async {
                  final Directory extDir = await getTemporaryDirectory();
                  final testDir = await Directory(
                    '${extDir.path}/camerawesome',
                  ).create(recursive: true);

                  if (sensors.length == 1) {
                    final String filePath =
                        '${testDir.path}/${DateTime.now().millisecondsSinceEpoch}.jpg';
                    return SingleCaptureRequest(filePath, sensors.first);
                  }

                  // Handle multiple sensors
                  return MultipleCaptureRequest(
                    {
                      for (final sensor in sensors)
                        sensor:
                            '${testDir.path}/${sensor.position == SensorPosition.front ? 'front_' : "back_"}${DateTime.now().millisecondsSinceEpoch}.jpg',
                    },
                  );
                },
                exifPreferences: ExifPreferences(saveGPSLocation: false),
              ),
              sensorConfig: SensorConfig.single(
                sensor: Sensor.position(SensorPosition.back),
                flashMode: FlashMode.auto,
                aspectRatio: CameraAspectRatios.ratio_4_3,
                zoom: 0.0,
              ),
              enablePhysicalButton: true,
              previewAlignment: Alignment.center,
              previewFit: CameraPreviewFit.contain,
              theme: AwesomeTheme(
                bottomActionsBackgroundColor: Colors.amber.withOpacity(0.8),
                buttonTheme: AwesomeButtonTheme(
                  backgroundColor: Colors.amber,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  void _showErrorSnackbar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _handleCancel(Map<String, dynamic> process) async {
    final loc = AppLocalizations.of(context);
    try {
      print('Cancelling process with data: ${widget.processData}');
      // final currentId =
      //     widget.processData['id'] ?? 0; // or however you get the process ID
      final currentPid = widget.processData['id'] ?? ''; // adjust as needed

      final result = await cancelprocess(
        pid: widget.processData['id'].toString(),
        erpUrlBase: widget.erpUrlBase,
        id: process['id'].toString(),
        userId: widget.userId.toString(),
      );

      print('Cancel API response: $result');
      //  print('Process cancelled: ${result['value']['status']}');
      if (result['status'] == 'success' ||
          result['value']['status'] == 'success') {
        print('Process cancelled successfully');
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => SubmitProcessPage(
              processData: widget.processData,
              erpUrlBase: widget.erpUrlBase,
              compId: widget.compId,
              userId: widget.userId,
              folderId: widget.folderId,
            ),
          ),
        );
      }
    } catch (e) {
      print('Cancel error: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${loc.cancel ?? 'Failed to cancel process'}: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _initializeDefaultUserIfEmpty(String processName) {
    if (mounted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final existingUsers = selectedUsers[processName] ?? [];

        // Always ensure globaluserType is in the list
        if (!existingUsers.contains(globaluserType)) {
          final updatedUsers = [...existingUsers, globaluserType]
              .where((user) => user != null)
              .map((user) => user!)
              .toList();
          _updateProcessUsers(processName, updatedUsers);
        }
      });
    }
  }

  Set<String> _defaultUserManuallyRemoved = {};

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);

    // print('usertypes $globaluserType');
    if (widget.erpUrlBase == 'https://www.alfadock-pack.com') {
      defectTypes = ['No defect code found'];
    }
    final initialQuantity =
        int.tryParse(widget.processData['quantity']?.toString() ?? '0') ?? 0;

    // Responsive helpers
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final isTablet = screenWidth > 600; // Common breakpoint for tablets
    final isLandscape =
        MediaQuery.of(context).orientation == Orientation.landscape;
    final horizontalPadding = isTablet ? 32.0 : 16.0;
    final verticalPadding = isTablet ? 24.0 : 16.0;
    final cardPadding = isTablet ? 24.0 : 16.0;
    final fontScale = isTablet ? 1.2 : 1.0; // Slightly larger fonts on tablet
    final itemSpacing = isTablet ? 16.0 : 8.0;

    return Scaffold(
      appBar: AppBar(
        title: Center(
          child: Text(
            loc.submitProcess,
            style: TextStyle(
              color: Colors.black,
              fontSize: (isTablet ? 20 : 17) * fontScale,
            ),
          ),
        ),
        backgroundColor: Colors.white,
        leadingWidth: isTablet ? 120 : 100,
        leading: Padding(
          padding: EdgeInsets.only(left: horizontalPadding / 2),
          child: InkWell(
            onTap: () =>
                Navigator.popUntil(context, ModalRoute.withName('/main')),
            child: Row(
              children: [
                Icon(Icons.arrow_back, color: Colors.blue),
                SizedBox(width: 4),
                Text(
                  loc.process,
                  style: TextStyle(
                    color: Colors.blue,
                    fontSize: 14 * fontScale,
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.camera_alt, color: Colors.blue),
            onPressed: _openCamera,
          ),
          IconButton(
            icon: const Icon(Icons.add, color: Colors.blue),
            onPressed: _createNewSubProcess,
          ),
        ],
      ),
      backgroundColor: Colors.white,
      body: LayoutBuilder(
        builder: (context, constraints) {
          // Re-evaluate responsive values based on constraints
          final availableWidth = constraints.maxWidth;
          final isWideTablet = availableWidth > 1000; // For very wide tablets
          final fileListHeight = isTablet ? 120.0 : 100.0;

          return Stack(
            children: [
              SingleChildScrollView(
                padding: EdgeInsets.symmetric(
                  horizontal: horizontalPadding,
                  vertical: verticalPadding,
                ),
                child: Column(
                  children: [
                    // Header Container - Make it responsive
                    Container(
                      width: double.infinity,
                      padding: EdgeInsets.symmetric(
                        vertical: verticalPadding,
                        horizontal: horizontalPadding,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.blue[100],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Center(
                              child: Text(
                                widget.processData['name'],
                                style: TextStyle(
                                  fontSize: (22 * fontScale),
                                  fontWeight: FontWeight.bold,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ),
                          Container(
                            padding: EdgeInsets.symmetric(
                              vertical: 8,
                              horizontal: 16,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.yellow,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              initialQuantity.toString(),
                              style: TextStyle(
                                fontSize: (18 * fontScale),
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: itemSpacing),

                    // File List Section - Responsive height and scroll
                    if (fileList.isNotEmpty || folderStack.isNotEmpty)
                      Container(
                        width: double.infinity,
                        height: fileListHeight,
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (folderStack.isNotEmpty)
                              Padding(
                                padding: EdgeInsets.only(
                                  right: itemSpacing,
                                  top: itemSpacing,
                                ),
                                child: IconButton(
                                  icon: Icon(
                                    Icons.arrow_back,
                                    size: isTablet ? 32 : 28,
                                    color: Colors.blue,
                                  ),
                                  onPressed: _navigateBack,
                                  padding: EdgeInsets.zero,
                                ),
                              ),
                            Expanded(
                              child: ListView.builder(
                                scrollDirection: Axis.horizontal,
                                itemCount: fileList.length,
                                itemBuilder: (context, index) {
                                  final file = fileList[index];
                                  final String? thumbnailGuid =
                                      file['thumbnailGuid'];
                                  final bool isFolder = file['fileType'] == 1;
                                  final String fileName =
                                      file['fileName'] ?? 'Unnamed';
                                  final fileExtension =
                                      fileName.split('.').last.toLowerCase();
                                  final guid = (fileExtension == 'dwg' ||
                                          fileExtension == 'dxf' ||
                                          fileExtension == 'pptx' ||
                                          fileExtension == 'docx' ||
                                          fileExtension == 'xlsx')
                                      ? file['pdf']
                                      : file['guid'];
                                  final String? folderId =
                                      file['id']?.toString();

                                  return Padding(
                                    padding:
                                        EdgeInsets.only(right: itemSpacing),
                                    child: GestureDetector(
                                      onTap: isFolder
                                          ? () {
                                              if (folderId != null) {
                                                _navigateToFolder(
                                                    folderId, fileName);
                                              } else {
                                                print(
                                                    'Error: Folder ID is null for $fileName');
                                              }
                                            }
                                          : () {
                                              final downloadUrl =
                                                  'https://www.alfadock-pack.com/api/file/downloadfilebyguid?guid=$guid&filename=$fileName';
                                              print(
                                                  'Tapped - downloadedurl $downloadUrl');
                                              Navigator.push(
                                                context,
                                                MaterialPageRoute(
                                                  builder: (context) =>
                                                      FileViewerPage(
                                                    downloadUrl: downloadUrl,
                                                    fileName: fileName,
                                                    guid: guid.toString(),
                                                    userId: widget.userId
                                                        .toString(),
                                                    compId: widget.compId
                                                        .toString(),
                                                    fileid:
                                                        file['id'].toString(),
                                                  ),
                                                ),
                                              );
                                            },
                                      child: Container(
                                        width: isTablet
                                            ? 120
                                            : 90, // Wider chips on tablet
                                        child: Chip(
                                          backgroundColor: Colors.grey[200],
                                          padding: EdgeInsets.all(
                                              isTablet ? 12.0 : 10.0),
                                          label: Column(
                                            mainAxisSize: MainAxisSize.min,
                                            crossAxisAlignment:
                                                CrossAxisAlignment.center,
                                            children: [
                                              if (isFolder)
                                                Icon(
                                                  Icons.folder,
                                                  size: isTablet ? 60 : 50,
                                                  color: Colors.blue,
                                                )
                                              else if (thumbnailGuid != null)
                                                Image.network(
                                                  thumbnailGuid,
                                                  width: isTablet ? 60 : 50,
                                                  height: isTablet ? 60 : 40,
                                                  fit: BoxFit.cover,
                                                  errorBuilder: (context, error,
                                                          stackTrace) =>
                                                      Icon(Icons.broken_image,
                                                          size: isTablet
                                                              ? 60
                                                              : 50),
                                                )
                                              else
                                                Icon(
                                                  Icons.image_not_supported,
                                                  size: isTablet ? 60 : 50,
                                                ),
                                              SizedBox(height: 4),
                                              Flexible(
                                                child: Text(
                                                  fileName,
                                                  style: TextStyle(
                                                      fontSize:
                                                          (10 * fontScale)),
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  textAlign: TextAlign.center,
                                                  maxLines: 2,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                      )
                    else
                      Padding(
                        padding: EdgeInsets.all(verticalPadding),
                        child: Text(
                          loc.noFoldersOrFilesavailable,
                          style: TextStyle(
                            fontSize: (16 * fontScale),
                            color: Colors.grey[600],
                          ),
                        ),
                      ),
                    SizedBox(height: itemSpacing * 2),

                    // Processes List - Use ListView with responsive cards
                    processes.isEmpty
                        ? Center(
                            child: Padding(
                              padding: EdgeInsets.all(verticalPadding),
                              child: Text(
                                loc.noprocessfound,
                                style: TextStyle(
                                  fontSize: (18 * fontScale),
                                  color: Colors.grey,
                                ),
                              ),
                            ),
                          )
                        : ListView.separated(
                            shrinkWrap: true,
                            physics: NeverScrollableScrollPhysics(),
                            itemCount: processes.length,
                            separatorBuilder: (context, index) =>
                                SizedBox(height: itemSpacing),
                            itemBuilder: (context, index) {
                              final process = processes[index];
                              final processName = process['name'] ?? 'SP1';
                              //print('Process ${process}');
                              // print('globaluserType in build $globaluserType');
                              // print('processName in build $processName');
                              // _updateProcessUsers(processName,
                              //     ['$globaluserType']);
                              if (process['status'] == 'ready') {
                                process['duration'] = '00:00:00';
                              }
                              final List<String> currentSelectionNames =
                                  (selectedUsersalfa[processName] ?? [])
                                      .map((id) {
                                final staffName =
                                    userIdToStaffNameMap[id]?.trim() ?? '';
                                final userName =
                                    userIdNameMap[id]?.trim() ?? '';
                                return _userDisplay == 1
                                    ? (staffName.isNotEmpty
                                        ? staffName
                                        : userName)
                                    : userName;
                              }).toList();
                              final List<String> currentSelectionNameserp =
                                  (selectedUsers[processName] ?? []).map((key) {
                                final mappedValue = mapping[key]?.trim() ?? '';
                                return _userDisplay == 1
                                    ? (mappedValue.isNotEmpty
                                        ? mappedValue
                                        : key)
                                    : key;
                              }).toList();

                              final rawQty = int.tryParse(
                                      process['qty']?.toString() ?? '0') ??
                                  0;
                              final quantity = rawQty == 0
                                  ? widget.processData['quantity']
                                  : rawQty;
                              final defectQuantity = int.tryParse(
                                      process['defect_qty']?.toString() ??
                                          '0') ??
                                  0;
                              final currentStatus =
                                  process['status']?.toString();

                              final startDateTime =
                                  (process['status']?.toString() == 'ready')
                                      ? null
                                      : (process['date_start'] != null)
                                          ? () {
                                              try {
                                                if (widget.erpUrlBase ==
                                                    "https://www.alfadock-pack.com") {
                                                  final format = DateFormat(
                                                      'MM/dd/yy hh:mm:ss a');
                                                  final parsedTime =
                                                      format.parseUtc(
                                                          process['date_start']
                                                              .toString());
                                                  final localTime =
                                                      parsedTime.toLocal();
                                                  return localTime;
                                                } else {
                                                  final format = DateFormat(
                                                      'yyyy-MM-dd HH:mm:ss');
                                                  final parsedTime =
                                                      format.parseUtc(
                                                          process['date_start']
                                                              .toString());
                                                  final localTime =
                                                      parsedTime.toLocal();
                                                  return localTime;
                                                }
                                              } catch (e) {
                                                return null;
                                              }
                                            }()
                                          : null;

                              final endDateTime = process['date_end'] != null
                                  ? () {
                                      try {
                                        if (widget.erpUrlBase ==
                                            "https://www.alfadock-pack.com") {
                                          final format =
                                              DateFormat('MM/dd/yy hh:mm:ss a');
                                          final parsedTime = format.parseUtc(
                                              process['date_end'].toString());
                                          final localTime =
                                              parsedTime.toLocal();
                                          // print(
                                          //     'Converted IST time (Other) end: $localTime');
                                          return localTime;
                                        } else {
                                          final format =
                                              DateFormat('yyyy-MM-dd HH:mm:ss');
                                          final parsedTime = format.parseUtc(
                                              process['date_end'].toString());
                                          print(parsedTime);
                                          final localTime =
                                              parsedTime.toLocal();
                                          // print(
                                          //     'Converted IST time (Other) end: $localTime');
                                          return localTime;
                                        }
                                      } catch (e) {
                                        return null;
                                      }
                                    }()
                                  : null;

                              final isDone = currentStatus == 'done';
                              final isProgress = currentStatus == 'progress' ||
                                  currentStatus == 'resume';
                              final isStopDisabled = isDone ||
                                  (completeInput == 1 &&
                                      currentStatus == 'ready');

                              return Card(
                                margin:
                                    EdgeInsets.only(bottom: itemSpacing * 2),
                                child: Padding(
                                  padding: EdgeInsets.all(cardPadding),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      // Process Name Container - Responsive height
                                      Container(
                                        width: double.infinity,
                                        height: isTablet ? 50 : 40,
                                        decoration: BoxDecoration(
                                          color: Colors.orange[200],
                                          borderRadius:
                                              BorderRadius.circular(8),
                                        ),
                                        child: Center(
                                          child: Text(
                                            processName,
                                            style: TextStyle(
                                              fontSize: (18 * fontScale),
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ),
                                      SizedBox(height: itemSpacing),

                                      // Assembly/Machine Selection - Responsive tap area
                                      GestureDetector(
                                        onTap: isDone
                                            ? null
                                            : () => _showSelectionModal(
                                                  context: context,
                                                  processName: processName,
                                                  title: loc.selectAssemblyType,
                                                  options: assemblyTypes,
                                                  currentSelection:
                                                      selectedAssemblyTypes[
                                                          processName],
                                                  onDone: (selection) {
                                                    setState(() {
                                                      selectedAssemblyTypes[
                                                              processName] =
                                                          selection;
                                                    });
                                                  },
                                                  isMultiSelect: false,
                                                ),
                                        child: Container(
                                          width: double.infinity,
                                          padding: EdgeInsets.symmetric(
                                              vertical: 12),
                                          child: Center(
                                            child: Builder(
                                              builder: (context) {
                                                final machineDockList = List<
                                                        Map<String,
                                                            dynamic>>.from(
                                                    process['machinedock'] ??
                                                        []);
                                                final machineDockId =
                                                    process['machinedockid'] ??
                                                        0;

                                                final selectedMachine =
                                                    machineDockList.firstWhere(
                                                  (m) =>
                                                      m['id'] == machineDockId,
                                                  orElse: () =>
                                                      <String, dynamic>{},
                                                );

                                                final machineName =
                                                    selectedMachine.isNotEmpty
                                                        ? (selectedMachine[
                                                                'name'] ??
                                                            loc.selectMachineType)
                                                        : loc.selectMachineType;

                                                final displayText = widget
                                                            .erpUrlBase ==
                                                        "https://www.alfadock-pack.com"
                                                    ? machineName
                                                    : (selectedAssemblyTypes[
                                                            processName] ??
                                                        loc.selectMachineType);

                                                return Text(
                                                  displayText,
                                                  style: TextStyle(
                                                    color: isDone
                                                        ? Colors.grey
                                                        : Colors.blue,
                                                    fontSize: (16 * fontScale),
                                                  ),
                                                  textAlign: TextAlign.center,
                                                );
                                              },
                                            ),
                                          ),
                                        ),
                                      ),
                                      SizedBox(height: itemSpacing),

                                      // Users Wrap - LEFT ALIGNED
                                      // In your build/UI code:
                                      if ((selectedUsers[processName] ?? [])
                                              .isEmpty &&
                                          !_defaultUserManuallyRemoved
                                              .contains(processName))
                                        Padding(
                                          padding:
                                              EdgeInsets.symmetric(vertical: 8),
                                          child: Align(
                                            alignment: Alignment.centerLeft,
                                            child: Builder(
                                              builder: (context) {
                                                print(
                                                    'No users selected for $processName, updating with $globaluserType');
                                                WidgetsBinding.instance
                                                    .addPostFrameCallback((_) {
                                                  _initializeDefaultUserIfEmpty(
                                                      processName);
                                                });
                                                return Text(
                                                  loc.noUsersSelected,
                                                  style: TextStyle(
                                                    color: Colors.grey,
                                                    fontSize: (14 * fontScale),
                                                  ),
                                                );
                                              },
                                            ),
                                          ),
                                        )
                                      else
                                        Align(
                                          alignment: Alignment.centerLeft,
                                          child: Builder(
                                            builder: (context) {
                                              // Check if globaluserType is present when users exist
                                              WidgetsBinding.instance
                                                  .addPostFrameCallback((_) {
                                                final existingUsers =
                                                    selectedUsers[
                                                            processName] ??
                                                        [];
                                                if (existingUsers.isNotEmpty &&
                                                    !existingUsers.contains(
                                                        globaluserType) &&
                                                    !_defaultUserManuallyRemoved
                                                        .contains(
                                                            processName)) {
                                                  _initializeDefaultUserIfEmpty(
                                                      processName);
                                                }
                                              });

                                              return Wrap(
                                                spacing: itemSpacing,
                                                runSpacing: itemSpacing,
                                                children: [
                                                  ...(processes[index]['users2']
                                                              as List<
                                                                  dynamic>? ??
                                                          [])
                                                      .map((user) {
                                                    final userId =
                                                        user['alfadock_id'];
                                                    final userName =
                                                        userIdNameMap[userId] ??
                                                            '';
                                                    final staffName =
                                                        userIdToStaffNameMap[
                                                                userId] ??
                                                            '';
                                                    final displayName =
                                                        (_userDisplay == 1
                                                            ? (staffName
                                                                    .isNotEmpty
                                                                ? staffName
                                                                : userName)
                                                            : userName);
                                                    final displayName1 =
                                                        (_userDisplay == 1
                                                            ? mapping[
                                                                user['name']]
                                                            : user['name']);

                                                    return Chip(
                                                      label: Text(
                                                        widget.erpUrlBase ==
                                                                "https://www.alfadock-pack.com"
                                                            ? displayName
                                                            : '$displayName1',
                                                        style: TextStyle(
                                                            fontSize:
                                                                12 * fontScale),
                                                      ),
                                                      deleteIcon: Icon(
                                                          Icons.close,
                                                          size: 18 * fontScale),
                                                      onDeleted: isDone
                                                          ? null
                                                          : () => _removeUser(
                                                                processName,
                                                                (user['name']
                                                                            ?.trim()
                                                                            .isNotEmpty ??
                                                                        false)
                                                                    ? user[
                                                                        'name']
                                                                    : (mapping[user[
                                                                            'name']] ??
                                                                        ''),
                                                              ),
                                                    );
                                                  }).toList(),
                                                ],
                                              );
                                            },
                                          ),
                                        ),
                                      SizedBox(height: itemSpacing),
                                      // Add Users GestureDetector - LEFT ALIGNED
                                      Align(
                                        alignment: Alignment.centerLeft,
                                        child: GestureDetector(
                                          onTap: isDone
                                              ? null
                                              : () => _showSelectionModal(
                                                    context: context,
                                                    processName: processName,
                                                    title: loc.addUsers,
                                                    options: widget
                                                                .erpUrlBase ==
                                                            "https://www.alfadock-pack.com"
                                                        ? optionsuser
                                                        : userOptions,
                                                    currentSelection: widget
                                                                .erpUrlBase ==
                                                            "https://www.alfadock-pack.com"
                                                        ? currentSelectionNames
                                                        : currentSelectionNameserp,
                                                    onDone: (selection) {},
                                                    isMultiSelect: true,
                                                  ),
                                          child: Container(
                                            padding: EdgeInsets.symmetric(
                                                vertical: 12),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(
                                                  Icons.add_circle,
                                                  color: isDone
                                                      ? Colors.grey
                                                      : Colors.green,
                                                  size: 24 * fontScale,
                                                ),
                                                SizedBox(width: itemSpacing),
                                                Text(
                                                  loc.addUsers,
                                                  style: TextStyle(
                                                    color: isDone
                                                        ? Colors.grey
                                                        : Colors.blue,
                                                    fontSize: (16 * fontScale),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                      SizedBox(height: itemSpacing),

                                      // Quantity and Defect Rows - SINGLE COLUMN, RIGHT ALIGNED (Fixed)
                                      Center(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.center,
                                          children: [
                                            ControlRow(
                                              label: loc.quantity,
                                              value: quantity,
                                              isDone: isDone,
                                              onChanged: (val) =>
                                                  _updateQuantity(
                                                      processName, val, false),
                                              maxQuantity: isDone
                                                  ? quantity
                                                  : _getRemainingQuantity(),
                                            ),
                                            SizedBox(height: itemSpacing),
                                            ControlRow(
                                              label: loc.defectQuantity,
                                              value: defectQuantity,
                                              isDone: isDone,
                                              onChanged: (val) =>
                                                  _updateQuantity(
                                                      processName, val, true),
                                              maxQuantity: null,
                                            ),
                                          ],
                                        ),
                                      ),
                                      SizedBox(height: itemSpacing * 2),

                                      // Defect Code Selection - Centered
                                      GestureDetector(
                                        onTap: isDone
                                            ? null
                                            : () => _showSelectionModal(
                                                  context: context,
                                                  processName: processName,
                                                  title: loc.selectDefectCode,
                                                  options: defectTypes,
                                                  currentSelection:
                                                      selectedDefects[
                                                          processName],
                                                  onDone: (selection) {
                                                    setState(() {
                                                      selectedDefects[
                                                              processName] =
                                                          selection;
                                                    });
                                                  },
                                                  isMultiSelect: false,
                                                ),
                                        child: Center(
                                          child: Container(
                                            width: double.infinity,
                                            padding: EdgeInsets.symmetric(
                                                vertical: 12),
                                            child: Text(
                                              selectedDefects[processName] ??
                                                  loc.selectDefectCode,
                                              style: TextStyle(
                                                color: isDone
                                                    ? Colors.grey
                                                    : Colors.blue,
                                                fontSize: (16 * fontScale),
                                              ),
                                              textAlign: TextAlign.center,
                                            ),
                                          ),
                                        ),
                                      ),
                                      SizedBox(height: itemSpacing * 3),

                                      // Buttons Row - Responsive spacing
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceEvenly,
                                        children: [
                                          if (currentStatus == 'ready' &&
                                              !isDone)
                                            ElevatedButton(
                                              onPressed: () =>
                                                  _startProcess(processName),
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor: Colors.green,
                                                shape: RoundedRectangleBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(4),
                                                ),
                                                padding: EdgeInsets.symmetric(
                                                  horizontal:
                                                      isTablet ? 24 : 16,
                                                  vertical: 12,
                                                ),
                                              ),
                                              child: Text(
                                                loc.start,
                                                style: TextStyle(
                                                  color: Colors.white,
                                                  fontSize: (16 * fontScale),
                                                ),
                                              ),
                                            )
                                          else if ((currentStatus ==
                                                      'progress' ||
                                                  currentStatus == 'resume') &&
                                              !isDone)
                                            ElevatedButton(
                                              onPressed: () =>
                                                  _pauseProcess(processName),
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor: Colors.orange,
                                                shape: RoundedRectangleBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(4),
                                                ),
                                                padding: EdgeInsets.symmetric(
                                                  horizontal:
                                                      isTablet ? 24 : 16,
                                                  vertical: 12,
                                                ),
                                              ),
                                              child: Text(
                                                loc.hold,
                                                style: TextStyle(
                                                  color: Colors.white,
                                                  fontSize: (16 * fontScale),
                                                ),
                                              ),
                                            )
                                          else if (currentStatus == 'pause' &&
                                              !isDone)
                                            ElevatedButton(
                                              onPressed: () =>
                                                  _resumeProcess(processName),
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor: Colors.green,
                                                shape: RoundedRectangleBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(4),
                                                ),
                                                padding: EdgeInsets.symmetric(
                                                  horizontal:
                                                      isTablet ? 24 : 16,
                                                  vertical: 12,
                                                ),
                                              ),
                                              child: Text(
                                                loc.resume,
                                                style: TextStyle(
                                                  color: Colors.white,
                                                  fontSize: (16 * fontScale),
                                                ),
                                              ),
                                            )
                                          else
                                            ElevatedButton(
                                              onPressed: null,
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor: Colors.grey,
                                                shape: RoundedRectangleBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(4),
                                                ),
                                                padding: EdgeInsets.symmetric(
                                                  horizontal:
                                                      isTablet ? 24 : 16,
                                                  vertical: 12,
                                                ),
                                              ),
                                              child: Text(
                                                loc.start,
                                                style: TextStyle(
                                                  color: Colors.white,
                                                  fontSize: (16 * fontScale),
                                                ),
                                              ),
                                            ),
                                          SizedBox(width: itemSpacing),
                                          ElevatedButton(
                                            onPressed: isStopDisabled
                                                ? null
                                                : () =>
                                                    _stopProcess(processName),
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: isStopDisabled
                                                  ? Colors.grey
                                                  : Colors.red,
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(4),
                                              ),
                                              padding: EdgeInsets.symmetric(
                                                horizontal: isTablet ? 24 : 16,
                                                vertical: 12,
                                              ),
                                            ),
                                            child: Text(
                                              loc.stop,
                                              style: TextStyle(
                                                color: Colors.white,
                                                fontSize: (16 * fontScale),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      SizedBox(height: itemSpacing * 2),

                                      // Timer Display - Larger on tablet
                                      Center(
                                        child: Text(
                                          (isProgress &&
                                                  currentStatus != 'pause')
                                              ? _formatTime(
                                                  elapsedSeconds[processName] ??
                                                      0)
                                              : (process['duration'] ??
                                                  '00:00:00'),
                                          style: TextStyle(
                                            fontSize: (28 * fontScale),
                                            fontWeight: FontWeight.bold,
                                            color: Colors.black87,
                                          ),
                                        ),
                                      ),
                                      SizedBox(height: itemSpacing * 2),

                                      // Date/Time Rows - Use Row for tablet, Column for mobile
                                      if (isTablet)
                                        Row(
                                          children: [
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    '${loc.startDate}: ${startDateTime != null ? DateFormat('yyyy-MM-dd').format(startDateTime) : ''}',
                                                    style: TextStyle(
                                                        fontSize:
                                                            (14 * fontScale)),
                                                  ),
                                                  Text(
                                                    '${loc.startTime}: ${startDateTime != null ? DateFormat('HH:mm:ss').format(startDateTime) : ''}',
                                                    style: TextStyle(
                                                        fontSize:
                                                            (14 * fontScale)),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            SizedBox(width: itemSpacing * 2),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.end,
                                                children: [
                                                  Text(
                                                    '${loc.endDate}: ${endDateTime != null ? DateFormat('yyyy-MM-dd').format(endDateTime) : ''}',
                                                    style: TextStyle(
                                                        fontSize:
                                                            (14 * fontScale)),
                                                  ),
                                                  Text(
                                                    '${loc.endTime}: ${endDateTime != null ? DateFormat('HH:mm:ss').format(endDateTime) : ''}',
                                                    style: TextStyle(
                                                        fontSize:
                                                            (14 * fontScale)),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        )
                                      else
                                        Column(
                                          children: [
                                            Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment
                                                      .spaceBetween,
                                              children: [
                                                Text(
                                                  '${loc.startDate}: ${startDateTime != null ? DateFormat('yyyy-MM-dd').format(startDateTime) : ''}',
                                                  style: TextStyle(
                                                      fontSize:
                                                          (14 * fontScale)),
                                                ),
                                                Text(
                                                  '${loc.endDate}: ${endDateTime != null ? DateFormat('yyyy-MM-dd').format(endDateTime) : ''}',
                                                  style: TextStyle(
                                                      fontSize:
                                                          (14 * fontScale)),
                                                ),
                                              ],
                                            ),
                                            SizedBox(height: 4),
                                            Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment
                                                      .spaceBetween,
                                              children: [
                                                Text(
                                                  '${loc.startTime}: ${startDateTime != null ? DateFormat('HH:mm:ss').format(startDateTime) : ''}',
                                                  style: TextStyle(
                                                      fontSize:
                                                          (14 * fontScale)),
                                                ),
                                                Text(
                                                  '${loc.endTime}: ${endDateTime != null ? DateFormat('HH:mm:ss').format(endDateTime) : ''}',
                                                  style: TextStyle(
                                                      fontSize:
                                                          (14 * fontScale)),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      SizedBox(height: itemSpacing * 3),

                                      // Cancel Button
                                      if (showCancelButton)
                                        Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.start,
                                          children: [
                                            OutlinedButton(
                                              onPressed: () =>
                                                  _handleCancel(process),
                                              style: OutlinedButton.styleFrom(
                                                shape: RoundedRectangleBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(4),
                                                ),
                                                padding: EdgeInsets.symmetric(
                                                  horizontal:
                                                      isTablet ? 24 : 16,
                                                  vertical: 12,
                                                ),
                                              ),
                                              child: Text(
                                                loc.cancel,
                                                style: TextStyle(
                                                    fontSize: (16 * fontScale)),
                                              ),
                                            ),
                                          ],
                                        ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                  ],
                ),
              ),
              if (isLoading)
                Container(
                  color: Colors.black54,
                  child: const Center(
                    child: CircularProgressIndicator(color: Colors.white),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Timer? _debounce;

  Widget _buildControlRow(String label, int value, bool isDone,
      Function(int) onChanged, int? maxQuantity) {
    final controller = TextEditingController(text: value.toString());

    void _onManualChange(String val) {
      final parsed = int.tryParse(val) ?? value;

      // cancel old timer
      if (_debounce?.isActive ?? false) _debounce!.cancel();

      // start new timer (3 sec delay)
      _debounce = Timer(const Duration(seconds: 3), () {
        onChanged(parsed); // call updateQuantity after 3s
      });
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          SizedBox(width: 120, child: Text(label)),

          // Quantity input box
          Container(
            width: 60,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey),
              borderRadius: BorderRadius.circular(4),
            ),
            child: TextField(
              controller: controller,
              enabled: !isDone,
              textAlign: TextAlign.center,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.zero,
              ),
              onChanged: _onManualChange, // debounce call
            ),
          ),

          const SizedBox(width: 8),

          // Decrement button → call immediately
          _qtyButton(Icons.remove,
              isDone || value <= 0 ? null : () => onChanged(value - 1)),

          const SizedBox(width: 8),

          // Increment button → call immediately
          _qtyButton(Icons.add, isDone ? null : () => onChanged(value + 1)),
        ],
      ),
    );
  }

  Widget _qtyButton(IconData icon, VoidCallback? onPressed) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: onPressed == null ? Colors.grey[300] : Colors.white,
        border: Border.all(color: Colors.grey),
        borderRadius: BorderRadius.circular(4),
      ),
      child: IconButton(
        icon:
            Icon(icon, size: 20, color: onPressed == null ? Colors.grey : null),
        onPressed: onPressed,
        padding: EdgeInsets.zero,
      ),
    );
  }
}

class ControlRow extends StatefulWidget {
  final String label;
  final int value;
  final bool isDone;
  final Function(int) onChanged;
  final int? maxQuantity;

  const ControlRow({
    Key? key,
    required this.label,
    required this.value,
    required this.isDone,
    required this.onChanged,
    this.maxQuantity,
  }) : super(key: key);

  @override
  _ControlRowState createState() => _ControlRowState();
}

class _ControlRowState extends State<ControlRow> {
  late TextEditingController _controller;
  int? _pendingValue; // Store the pending value to be updated

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.value.toString());
  }

  @override
  void didUpdateWidget(ControlRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Update controller value only if the widget value changed from external sources
    if (oldWidget.value != widget.value &&
        _controller.text != widget.value.toString()) {
      _controller.text = widget.value.toString();
      _pendingValue = null; // Clear pending value when external update occurs
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onTextChanged(String val) {
    // Store the pending value but don't trigger update yet
    _pendingValue = int.tryParse(val) ?? widget.value;
  }

  void _onEditingComplete() {
    // Dismiss keyboard first
    FocusScope.of(context).unfocus();

    // Trigger update when user presses done/tick button
    if (_pendingValue != null && _pendingValue != widget.value) {
      widget.onChanged(_pendingValue!);
      _pendingValue = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(width: 120, child: Text(widget.label)),

          // Quantity input box
          Container(
            width: 60,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey),
              borderRadius: BorderRadius.circular(4),
            ),
            child: TextField(
              controller: _controller,
              enabled: !widget.isDone,
              textAlign: TextAlign.center,
              keyboardType: TextInputType.number,
              textInputAction:
                  TextInputAction.done, // Show done button on keyboard
              decoration: const InputDecoration(
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.zero,
              ),
              onChanged: _onTextChanged,
              onEditingComplete:
                  _onEditingComplete, // Called when done button is pressed
              onSubmitted: (value) {
                // Alternative callback for when user submits
                _onEditingComplete();
              },
            ),
          ),

          const SizedBox(width: 8),

          // Decrement button → call immediately
          _qtyButton(
              Icons.remove,
              widget.isDone || widget.value <= 0
                  ? null
                  : () => widget.onChanged(widget.value - 1)),

          const SizedBox(width: 8),

          // Increment button → call immediately
          _qtyButton(Icons.add,
              widget.isDone ? null : () => widget.onChanged(widget.value + 1)),
        ],
      ),
    );
  }

  Widget _qtyButton(IconData icon, VoidCallback? onPressed) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: onPressed == null ? Colors.grey[300] : Colors.white,
        border: Border.all(color: Colors.grey),
        borderRadius: BorderRadius.circular(4),
      ),
      child: IconButton(
        icon:
            Icon(icon, size: 20, color: onPressed == null ? Colors.grey : null),
        onPressed: onPressed,
        padding: EdgeInsets.zero,
      ),
    );
  }
}

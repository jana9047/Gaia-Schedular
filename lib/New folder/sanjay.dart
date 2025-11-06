import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import '../api.dart';
import '../app_state.dart';
import '../fileviewer.dart';

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
  Map<String, dynamic>? processListData;
  bool showCancelButton = false;
  int completeInput = 0;
  List<Map<String, dynamic>> fileList = [];
  List<String> currentSelectionNames = [];
  List<String> assemblyTypes = [];
  List<String> userOptions = [];
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
  @override
  void initState() {
    super.initState();
    _loadSettings();
    _loadSelectedAssemblyTypes();
    _fetchSchedulerSettings().then((_) {
      _fetchInitialProcessStatus();
      _fetchProcessListData();
    });
    _loadCancelFunctionSetting();
    _loadCompleteInputSetting();
    _fetchFiles();
    _loadTimers();
  }

  @override
  void dispose() {
    for (var timer in timers.values) {
      timer?.cancel();
    }
    super.dispose();
  }

  Future<void> _loadTimers() async {
    for (var process in processes) {
      final processName = process['name'] as String;
      final savedSeconds = await TimerManager._loadElapsedSeconds(processName);
      final serverDurationSeconds =
          _parseDuration(process['duration'] ?? '00:00:00');
      setState(() {
        elapsedSeconds[processName] =
            savedSeconds > 0 ? savedSeconds : serverDurationSeconds;
        if (process['status'] == 'progress') {
          _startProcessTimer(processName); // Resume timer if in progress
        }
      });
      await TimerManager._saveElapsedSeconds(
          processName, elapsedSeconds[processName] ?? 0);
    }
  }

  void _startProcessTimer(String processName, {int accumulatedDuration = 0}) {
    final processIndex = processes.indexWhere((p) => p['name'] == processName);
    if (processIndex != -1) {
      setState(() {
        elapsedSeconds[processName] =
            accumulatedDuration; // Sync with provided duration
        processes[processIndex]['duration'] = _formatTime(accumulatedDuration);
      });
      TimerManager.startTimer(processName, accumulatedDuration, () {
        if (mounted) {
          setState(() {
            elapsedSeconds[processName] =
                TimerManager.getElapsedSeconds(processName);
            processes[processIndex]['duration'] =
                _formatTime(elapsedSeconds[processName] ?? 0);
          });
        }
      });
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
    print('complete input $completeInput');
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
    print('Saved selectedAssemblyTypes: $selectedAssemblyTypes');
  }

  Future<void> _saveElapsedSeconds(String processName, int seconds) async {
    print('saved elapse time is calling');
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(
      'elapsedSeconds_${widget.processData['id']}_$processName',
      seconds,
    );
    print('Saved elapsedSeconds for $processName: $seconds');
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
      print('Scheduler settings response: ${jsonEncode(response)}');
      setState(() {
        print('Scheduler settings response: $response');
        assemblyTypes = List<String>.from(
            (response['machines'] as List<dynamic>? ?? [])
                .map((machine) => machine['name'] as String));
        machines = List<Map<String, dynamic>>.from(response['machines'] ?? []);
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
          operators =
              List<Map<String, dynamic>>.from(response['operators'] ?? []);
        } else {
          userOptions = List<String>.from(
              (response['operators'] as List<dynamic>? ?? [])
                  .map((operator) => operator['name'] as String));
          operators =
              List<Map<String, dynamic>>.from(response['operators'] ?? []);
        }
        print(response['defect_codes']);
        defectTypes = List<String>.from(
            (response['defect_codes'] as List<dynamic>? ?? [])
                .map((defect) => defect['name'] as String));
        final List<dynamic> defectCodes = response['defect_codes'];
        defectIdToNameMap = {
          for (var code in defectCodes)
            code['alfadock_id'] as int: code['name'] as String
        };
        print('Defect ID to Name Map: $defectIdToNameMap');
        print('Defect Types: $defectTypes');
        print('userOptions: $userOptions');
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
        SnackBar(content: Text('Failed to load process list data: $e')),
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
      String processName, DateTime? startDateTime, int accumulatedDuration) {
    print("=== _startTimer CALLED for process: $processName ===");
    print("Initial accumulatedDuration: $accumulatedDuration");
    print("Initial startDateTime: $startDateTime");
    print("Previous elapsedSeconds: ${elapsedSeconds[processName]}");
    // Cancel any existing timer for this process
    if (timers[processName] != null) {
      print("Cancelling existing timer for: $processName");
    }
    timers[processName]?.cancel();
    // Reset elapsedSeconds to 0 for a new start, use accumulatedDuration if provided
    elapsedSeconds[processName] = accumulatedDuration > 0
        ? accumulatedDuration
        : (elapsedSeconds[processName] ?? 0);
    print(
        "Calculated new elapsedSeconds for $processName: ${elapsedSeconds[processName]}");
    // Start a periodic timer
    timers[processName] = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          elapsedSeconds[processName] = (elapsedSeconds[processName] ?? 0) + 1;
        });
        print(
            "[TIMER TICK] $processName -> ${elapsedSeconds[processName]} seconds elapsed");
        _saveElapsedSeconds(processName, elapsedSeconds[processName] ?? 0);
      } else {
        print("Widget unmounted. Cancelling timer for: $processName");
        timer.cancel();
        timers[processName] = null;
      }
    });
    print("Timer started for $processName\n");
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
            'qty': 0,
            'defect_qty': 0,
            'status': 'ready',
            'duration': '00:00:00',
            'date_start': null,
            'date_end': null,
            'users2': [],
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
        final response = await startProcess(
          pid: int.parse(widget.processData['id'].toString()),
          erpUrlBase: widget.erpUrlBase,
          id: '',
          name: newSpName,
          qty: "0",
          users: [],
          status: 'ready',
          plannedStartDate:
              DateFormat('MM/dd/yy hh:mm:ss a').format(DateTime.now()),
          defectQty: '0',
          defectReason: '',
          defectCodeId: '0',
        );
        print('Created new sub-process $newSpName: ${jsonEncode(response)}');
        setState(() {
          processes.add({
            'id': response['id']?.toString() ?? '',
            'name': newSpName,
            'qty': 0,
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
    switch (status) {
      case 'ready':
      case 'pending':
        return '0';
      case 'progress':
      case 'resume':
        return '1';
      case 'pause':
        return '2';
      case 'done':
        return '4';
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
    if (!['pending', 'ready', 'progress', 'resume', 'pause', 'done']
        .contains(status)) {
      print('Invalid status: $status for process $processName');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Invalid status: $status')),
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
          SnackBar(content: Text('Process $processName not found')),
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
        elapsedSeconds[processName] = 0; // Reset for new start
        await TimerManager._saveElapsedSeconds(processName, 0);
      }
      if (process['status'] == 'ready') {
        elapsedSeconds[processName] = 0;
        print('processname $processName');
        _saveElapsedSeconds(processName, 0);
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
          machineId: machine['id']?.toString() ?? '0',
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
            SnackBar(
                content: Text(
                    'Cannot update $processName: Parent process is already completed')),
          );
          return;
        }
        print('status: $status');
        if (status == 'progress') {
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
        final defectCodeId = defectTypes.contains(defectName)
            ? defectTypes.indexOf(defectName).toString()
            : '0';
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
        print('response $response');
        print(
            'startProcess response for $processName: ${jsonEncode(response)}');
        if (status == 'done' &&
            response['message'] != null &&
            response['message']
                .contains('Cannot change a completed work order')) {
          print(
              'Cannot update $processName to done: parent process (pid=${widget.processData['id']}) is already done');
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text(
                    'Cannot update $processName: Parent process is already completed')),
          );
          return;
        }
        if (status == 'progress') {
          // Use saved or server duration, ignoring time since last date_start
          final serverDurationSeconds = _parseDuration(
              response['duration'] ?? process['duration'] ?? '00:00:00');
          final savedSeconds =
              await TimerManager._loadElapsedSeconds(processName);
          final accumulatedDuration =
              savedSeconds > 0 ? savedSeconds : serverDurationSeconds;
          elapsedSeconds[processName] =
              accumulatedDuration; // Sync before starting
          await TimerManager._saveElapsedSeconds(
              processName, accumulatedDuration);
          _startTimer(
            processName,
            updatedProcess['date_start'] != null
                ? DateTime.parse(updatedProcess['date_start'])
                : DateTime.now(),
            accumulatedDuration,
          );
        } else {
          TimerManager.stopTimer(processName);
          print('pause');
          _stopTimer(processName);
          if (status == 'done' || status == 'pause') {
            await TimerManager._saveElapsedSeconds(
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
    setState(() {
      isLoading = true;
    });
    try {
      final processIndex =
          processes.indexWhere((p) => p['name'] == processName);
      if (processIndex == -1) {
        print('Process $processName not found');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Process $processName not found')),
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
        final response = await updateSubmitProcess(
          erpUrlBase: widget.erpUrlBase,
          processId: widget.processData['id'].toString(),
          submitProcessId: process['id']?.toString() ?? '',
          userId: widget.userId ?? '0',
          status: process['status'] == 'resume'
              ? '1'
              : _mapStatusToCode(process['status']?.toString() ?? 'ready'),
          machineId: machine['id']?.toString() ?? '0',
          quantity: process['qty']?.toString() ?? '0',
          defectQuantity: process['defect_qty']?.toString() ?? '0',
          defectCode: defectCode,
        );
        print('Updated machine for $processName: ${jsonEncode(response)}');
        await _fetchUpdatedProcessStatus(processName);
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
        SnackBar(
            content: Text('Failed to update machine for $processName: $e')),
      );
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> _updateQuantity(
      String processName, int newQty, bool isDefectQty) async {
    setState(() {
      isLoading = true;
    });
    try {
      final processIndex =
          processes.indexWhere((p) => p['name'] == processName);
      if (processIndex == -1) {
        print('Process $processName not found');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Process $processName not found')),
        );
        return;
      }
      final process =
          Map<String, dynamic>.from(processes[processIndex]); // Create a copy
      final remainingQuantity = _getRemainingQuantity();
      final maxQuantity =
          process['status'] == 'done' ? process['qty'] : remainingQuantity;
      final updatedQty = isDefectQty
          ? (int.tryParse(process['qty']?.toString() ?? '0') ?? 0)
          : newQty; // Remove clamp to allow any value
      final updatedDefectQty = isDefectQty
          ? newQty.clamp(0, double.infinity).toInt()
          : (int.tryParse(process['defect_qty']?.toString() ?? '0') ?? 0);
      process['qty'] = updatedQty;
      process['defect_qty'] = updatedDefectQty;
      setState(() {
        processes[processIndex] =
            process; // Update the list with the new process
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
          status: process['status'] == 'resume'
              ? '1'
              : _mapStatusToCode(process['status']?.toString() ?? 'ready'),
          machineId: machine['id']?.toString() ?? '0',
          quantity: updatedQty.toString(),
          defectQuantity: updatedDefectQty.toString(),
          defectCode: defectCode,
        );
        print(
            'Quantity update response for $processName: ${jsonEncode(response)}');
        if (response['status'] == 'success') {
          await _fetchUpdatedProcessStatus(
              processName); // Only fetch if successful
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
        final defectCodeId = defectTypes.contains(defectName)
            ? defectTypes.indexOf(defectName).toString()
            : '0';
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
        if (response['status'] == 'success') {
          await _fetchUpdatedProcessStatus(
              processName); // Only fetch if successful
        } else {
          throw Exception('API update failed: ${response['message']}');
        }
      }
    } catch (e) {
      print('Error updating quantity for $processName: $e');
      // ScaffoldMessenger.of(context).showSnackBar(
      // SnackBar(content: Text('Failed to update quantity: $e')),
      // );
      // Revert to previous state if update fails
      await _fetchUpdatedProcessStatus(processName);
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> _updateProcessUsers(
      String processName, List<String> users) async {
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
          SnackBar(content: Text('Process $processName not found')),
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update users for $processName: $e')),
      );
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

  void _startProcess(String processName) async {
    flag = 1;
    print('Starting process $processName');
    // Reset elapsedSeconds to 0 when starting a new process
    setState(() {
      elapsedSeconds[processName] = 0;
      print(elapsedSeconds[processName]);
      _saveElapsedSeconds(processName, 0); // Save 0 to SharedPreferences
    });
    await _updateProcessStatus('progress', processName);
    _startProcessTimer(processName);
  }

  void _pauseProcess(String processName) async {
    flag = 1;
    print('Pausing process $processName');
    final processIndex = processes.indexWhere((p) => p['name'] == processName);
    if (processIndex != -1) {
      setState(() {
        processes[processIndex]['date_end'] =
            DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now());
        processes[processIndex]['duration'] =
            _formatTime(elapsedSeconds[processName] ?? 0);
      });
      await _updateProcessStatus('pause', processName);
      TimerManager.stopTimer(processName);
      _stopTimer(processName);
      await TimerManager._saveElapsedSeconds(
          processName, elapsedSeconds[processName] ?? 0);
    }
  }

  void _resumeProcess(String processName) async {
    flag = 1;
    print('Resuming process $processName');
    await _updateProcessStatus('resume', processName);
    final savedSeconds = await TimerManager._loadElapsedSeconds(processName);
    final processIndex = processes.indexWhere((p) => p['name'] == processName);
    if (processIndex != -1) {
      final serverDurationSeconds =
          _parseDuration(processes[processIndex]['duration'] ?? '00:00:00');
      final accumulatedDuration =
          savedSeconds > 0 ? savedSeconds : serverDurationSeconds;
      setState(() {
        elapsedSeconds[processName] =
            accumulatedDuration; // Use accumulated duration
      });
      await TimerManager._saveElapsedSeconds(processName, accumulatedDuration);
      _startProcessTimer(processName, accumulatedDuration: accumulatedDuration);
    }
  }

  void _stopProcess(String processName) async {
    print('Stopping process $processName');
    final processIndex = processes.indexWhere((p) => p['name'] == processName);
    if (processIndex != -1) {
      setState(() {
        processes[processIndex]['date_end'] =
            DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now());
        processes[processIndex]['duration'] =
            _formatTime(elapsedSeconds[processName] ?? 0);
      });
      await _updateProcessStatus('done', processName);
      TimerManager.stopTimer(processName);
      await TimerManager._saveElapsedSeconds(
          processName, elapsedSeconds[processName] ?? 0);
    }
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
                        child: const Text('Cancel'),
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
                                          'Process $processName not found')),
                                );
                              }
                            }
                          }
                          Navigator.pop(context);
                        },
                        child: const Text('Done'),
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
        // Replace current page with a new instance of it
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result['message'] ?? 'Failed to remove user')),
        );
      } else {
        // Optional: show error message
        print('asa');
        await _fetchUpdatedProcessStatus(processName);
      }
    } else {
      print('Updating users for $processName: ${selectedUsers[processName]}');
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
        final savedSeconds = await _loadElapsedSeconds(processName);
        if (savedSeconds > 0 && process['status'] != 'progress') {
          setState(() {
            elapsedSeconds[processName] = savedSeconds;
            process['duration'] = _formatTime(savedSeconds);
            print('initial elapsed seconds for $processName: $savedSeconds');
          });
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
                    widget.processData['quantity']?.toString() ?? '25') ??
                25,
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
      print('Converted IST Time: $istTime');
      return istTime;
    } catch (e) {
      print('Error converting time: $e');
      return null;
    }
  }

  Future<void> _fetchUpdatedProcessStatus([String? targetProcessName]) async {
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
        if (response['value'] == null ||
            response['value']['submitProcessList'] == null ||
            (response['value']['submitProcessList'] as List).isEmpty) {
          if (processes.isEmpty && targetProcessName == null) {
            processes = [
              {
                'id': '',
                'name': 'SP1',
                'qty': int.tryParse(
                        widget.processData['quantity']?.toString() ?? '25') ??
                    25,
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
              final machineName = widget.processData['machineName']?.toString();
              if (machineName != null && !assemblyTypes.contains(machineName)) {
                assemblyTypes.add(machineName);
                machines.add({'id': machineName, 'name': machineName});
              }
              selectedAssemblyTypes[processName] =
                  assemblyTypes.contains(machineName) ? machineName : null;
              selectedDefects[processName] = selectedDefects[processName];
              print(
                  'Selected assembly type for ${selectedAssemblyTypes[processName]}');
            }
            _saveSelectedAssemblyTypes();
          }
          setState(() {}); // Trigger rebuild if needed
          return;
        }
        final records = List<Map<String, dynamic>>.from(
            response['value']['submitProcessList']);
        print('records: ${jsonEncode(records)}');
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
            final startDateTime = record['startTime'];
            print('startDateTime: $startDateTime');
            final accumulatedDuration =
                _parseDuration(record['duration'] ?? '00:00:00');
            print('accumulatedDuration: $accumulatedDuration');
            final savedSeconds = elapsedSeconds[processName] ?? 0;
            elapsedSeconds[targetProcessName] =
                savedSeconds > 0 ? savedSeconds : accumulatedDuration;
            // ... (rest of the update logic)
            if (status == 'progress') {
              _startProcessTimer(targetProcessName,
                  accumulatedDuration: elapsedSeconds[targetProcessName] ?? 0);
            } else {
              TimerManager.stopTimer(targetProcessName);
              _stopTimer(targetProcessName);
              _saveElapsedSeconds(
                  targetProcessName, elapsedSeconds[targetProcessName] ?? 0);
            }
            final machineName = record['machineName'] as String?;
            final defectCode = record['defectCode'] as String?;
            if (machineName != null && !assemblyTypes.contains(machineName)) {
              assemblyTypes.add(machineName);
              machines.add({'id': machineName, 'name': machineName});
            }
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
                  : _formatTime(
                      savedSeconds > 0 ? savedSeconds : accumulatedDuration),
              'date_start': startDateTime ??
                  (processIndex != -1
                      ? processes[processIndex]['startTime']
                      : null),
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
            };
            print('updatedProcessjana: ${jsonEncode(updatedProcess)}');
            if (processIndex != -1) {
              processes[processIndex] = updatedProcess;
            } else {
              processes.add(updatedProcess);
            }
            if (status == 'progress') {
              _startTimer(
                processName,
                startDateTime ??
                    (updatedProcess['date_start'] != null
                        ? DateTime.parse(updatedProcess['date_start'])
                        : DateTime.now()),
                savedSeconds > 0 ? savedSeconds : accumulatedDuration,
              );
            } else {
              _stopTimer(processName);
              elapsedSeconds[processName] = status == 'ready'
                  ? 0
                  : (savedSeconds > 0 ? savedSeconds : accumulatedDuration);
              _saveElapsedSeconds(
                  processName, elapsedSeconds[processName] ?? 0);
            }
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
            final startDateTime = record['startTime'];
            print('${record['startTime']}');
            print('startDateTime: $startDateTime');
            final accumulatedDuration =
                _parseDuration(record['duration'] ?? '00:00:00');
            final savedSeconds = elapsedSeconds[processName] ?? 0;
            final machineName = record['machineName'] as String?;
            final defectCode = record['defectCode'] as String?;
            if (machineName != null && !assemblyTypes.contains(machineName)) {
              assemblyTypes.add(machineName);
              machines.add({'id': machineName, 'name': machineName});
            }
            final updatedProcess = {
              'id': record['id']?.toString() ?? '',
              'name': processName,
              'qty': record['quantity'] ?? 25,
              'defect_qty': record['defectQuantity'] ?? 0,
              'status': status,
              'duration': status == 'ready'
                  ? '00:00:00'
                  : _formatTime(
                      savedSeconds > 0 ? savedSeconds : accumulatedDuration),
              'date_start': startDateTime,
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
            };
            processes.add(updatedProcess);
            if (status == 'progress') {
              _startTimer(
                processName,
                startDateTime ??
                    (updatedProcess['date_start'] != null
                        ? DateTime.parse(updatedProcess['date_start'])
                        : DateTime.now()),
                savedSeconds > 0 ? savedSeconds : accumulatedDuration,
              );
            } else {
              _stopTimer(processName);
              elapsedSeconds[processName] = status == 'ready'
                  ? 0
                  : (savedSeconds > 0 ? savedSeconds : accumulatedDuration);
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
            selectedAssemblyTypes[processName] =
                assemblyTypes.contains(machineName)
                    ? machineName
                    : (selectedAssemblyTypes[processName]);
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
                        widget.processData['quantity']?.toString() ?? '25') ??
                    25,
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
            final defectReason =
                defectCodeId != null ? defectIdToNameMap[defectCodeId] : null;
            print('defectReasonjana: $defectReason');
            final accumulatedDuration = _parseDuration(record['duration']);
            print('accumulatedDuration: $accumulatedDuration');
            final savedSeconds =
                await TimerManager._loadElapsedSeconds(targetProcessName);
            final finalSeconds =
                savedSeconds > 0 ? savedSeconds : accumulatedDuration;
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
            };
            print('Updated process: ${jsonEncode(updatedProcess)}');
            processes[processIndex] = updatedProcess;
            setState(() {
              elapsedSeconds[targetProcessName] = finalSeconds;
            });
            await TimerManager._saveElapsedSeconds(
                targetProcessName, finalSeconds);
            final currentStatus = status?.toString() ?? 'ready';
            final startDateTime = record['date_start'] != null
                ? DateTime.tryParse(record['date_start'].toString())
                : (updatedProcess['date_start'] != null
                    ? DateTime.parse(updatedProcess['date_start'])
                    : null);
            if (currentStatus == 'progress') {
              _startProcessTimer(targetProcessName);
              // _startTimer(
              // targetProcessName,
              // startDateTime ??
              // (updatedProcess['date_start'] != null
              // ? DateTime.parse(updatedProcess['date_start'])
              // : DateTime.now()),
              // savedSeconds > 0 ? savedSeconds : accumulatedDuration,
              // );
            } else {
              TimerManager.stopTimer(targetProcessName);
              _stopTimer(targetProcessName);
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
            print('Updated process: ${jsonEncode(updatedProcess)}');
            processes.add(updatedProcess);
            final currentStatus = status?.toString() ?? 'ready';
            final startDateTime = record['date_start'] != null
                ? DateTime.tryParse(record['date_start'].toString())
                : (updatedProcess['date_start'] != null
                    ? DateTime.parse(updatedProcess['date_start'])
                    : null);
            if (currentStatus == 'progress') {
              _startTimer(
                processName,
                startDateTime ??
                    (updatedProcess['date_start'] != null
                        ? DateTime.parse(updatedProcess['date_start'])
                        : DateTime.now()),
                savedSeconds > 0 ? savedSeconds : accumulatedDuration,
              );
            } else {
              _stopTimer(processName);
              elapsedSeconds[processName] = currentStatus == 'ready'
                  ? 0
                  : (savedSeconds > 0 ? savedSeconds : accumulatedDuration);
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
        SnackBar(content: Text('Failed to fetch process status: $e')),
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

  @override
  Widget build(BuildContext context) {
    final initialQuantity =
        int.tryParse(widget.processData['quantity']?.toString() ?? '25') ?? 25;
    return Scaffold(
      appBar: AppBar(
        title: const Center(
          child: Text('Submit Process', style: TextStyle(color: Colors.black)),
        ),
        backgroundColor: Colors.white,
        leadingWidth: 100,
        leading: Padding(
          padding: const EdgeInsets.only(left: 8),
          child: InkWell(
            onTap: () =>
                Navigator.popUntil(context, ModalRoute.withName('/main')),
            child: const Row(
              children: [
                Icon(Icons.arrow_back, color: Colors.blue),
                SizedBox(width: 4),
                Text('Process',
                    style: TextStyle(color: Colors.blue, fontSize: 14)),
              ],
            ),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.camera_alt, color: Colors.blue),
            onPressed: () {},
          ),
          IconButton(
            icon: const Icon(Icons.add, color: Colors.blue),
            onPressed: _createNewSubProcess,
          ),
        ],
      ),
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          Column(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                decoration: BoxDecoration(
                  color: Colors.blue[100],
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Center(
                        child: Text(
                          widget.processData['name'] ?? 'Process Name',
                          style: const TextStyle(
                              fontSize: 20, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          vertical: 4, horizontal: 12),
                      decoration: BoxDecoration(
                        color: Colors.yellow,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        initialQuantity.toString(),
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(height: 8),
                  if (fileList.isNotEmpty)
                    SizedBox(
                      height: 100,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: fileList.length,
                        itemBuilder: (context, index) {
                          final file = fileList[index];
                          print('file $file');
                          final String? thumbnailGuid = file['thumbnailGuid'];
                          print('thumbnailGuid: $thumbnailGuid');
                          final String fileName = file['fileName'] ?? 'Unnamed';
                          final String? guid = file['guid'];
                          return Padding(
                            padding: const EdgeInsets.only(right: 8.0),
                            child: GestureDetector(
                              onTap: () {
                                final downloadUrl =
                                    'https://www.alfadock-pack.com/api/file/downloadfilebyguid?guid=$guid&filename=$fileName';
                                print('Tapped - downloadedurl $downloadUrl');
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => FileViewerPage(
                                      downloadUrl: downloadUrl,
                                      fileName: fileName,
                                    ),
                                  ),
                                );
                              },
                              child: Chip(
                                backgroundColor: Colors.grey[200],
                                padding: EdgeInsets.all(
                                    8.0), // Add padding for easier tapping
                                label: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    if (thumbnailGuid != null)
                                      Image.network(
                                        thumbnailGuid,
                                        width: 50,
                                        height: 50,
                                        fit: BoxFit.cover,
                                        errorBuilder: (context, error,
                                                stackTrace) =>
                                            Icon(Icons.broken_image, size: 50),
                                      )
                                    else
                                      Icon(Icons.image_not_supported, size: 50),
                                    SizedBox(height: 4),
                                    Text(
                                      fileName,
                                      style: TextStyle(fontSize: 12),
                                      overflow: TextOverflow.ellipsis,
                                      textAlign: TextAlign.center,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    )
                  else
                    Text('No files available'),
                ],
              ),
              Expanded(
                child: processes.isEmpty
                    ? const Center(child: Text('No processes available'))
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: processes.length,
                        itemBuilder: (context, index) {
                          final process = processes[index];
                          final processName = process['name'] ?? 'SP1';
                          //print('Process $process');
                          final List<String> currentSelectionNames =
                              (selectedUsersalfa[processName] ?? []).map((id) {
                            final staffName =
                                userIdToStaffNameMap[id]?.trim() ?? '';
                            final userName = userIdNameMap[id]?.trim() ?? '';
                            return _userDisplay == 1
                                ? (staffName.isNotEmpty ? staffName : userName)
                                : userName;
                          }).toList();
                          final quantity =
                              int.tryParse(process['qty']?.toString() ?? '0') ??
                                  0;
                          final defectQuantity = int.tryParse(
                                  process['defect_qty']?.toString() ?? '0') ??
                              0;
                          final currentStatus = process['status']?.toString();
                          // print('process time ${process['date_start']}');
                          final startDateTime = process['date_start'] != null
                              ? () {
                                  try {
                                    if (widget.erpUrlBase ==
                                        "https://www.alfadock-pack.com") {
                                      final format =
                                          DateFormat('MM/dd/yy hh:mm:ss a');
                                      final parsedTime = format.parse(
                                          process['date_start'].toString());
                                      // Assume server time is in UTC and convert to IST (+5:30)
                                      final istTime = parsedTime.add(
                                          const Duration(
                                              hours: 5, minutes: 30));
                                      // print('Parsed local time: $parsedTime');
                                      // print('Converted IST time: $istTime');
                                      return istTime;
                                    } else {
                                      // print(
                                      // 'Parsing date_start: ${process['date_start']}');
                                      final format =
                                          DateFormat('yyyy-MM-dd HH:mm:ss');
                                      final parsedTime = format.parse(
                                          process['date_start'].toString());
                                      final istTime = parsedTime.add(
                                          const Duration(
                                              hours: 5, minutes: 30));
                                      // print(
                                      // 'Parsed local time (Other): $parsedTime');
                                      // print(
                                      // 'Converted IST time (Other): $istTime');
                                      return istTime;
                                    }
                                  } catch (e) {
                                    // print(
                                    // 'Date parsing error for "${process['date_start']}": $e');
                                    return null; // Fallback to null if parsing fails
                                  }
                                }()
                              : null;
                          // print('startDateTime: $startDateTime');
                          // print('startDateTime: $startDateTime');
                          final endDateTime = process['date_end'] != null
                              ? () {
                                  try {
                                    if (widget.erpUrlBase ==
                                        "https://www.alfadock-pack.com") {
                                      final format =
                                          DateFormat('MM/dd/yy hh:mm:ss a');
                                      final parsedTime = format.parse(
                                          process['date_end'].toString());
                                      // Assume server time is in UTC and convert to IST (+5:30)
                                      final istTime = parsedTime.add(
                                          const Duration(
                                              hours: 5, minutes: 30));
                                      // print(
                                      // 'Parsed local time end: $parsedTime');
                                      // print('Converted IST time end: $istTime');
                                      return istTime;
                                    } else {
                                      // print(
                                      // 'Parsing date_start end: ${process['date_end']}');
                                      final format =
                                          DateFormat('yyyy-MM-dd HH:mm:ss');
                                      final parsedTime = format.parse(
                                          process['date_end'].toString());
                                      final istTime = parsedTime.add(
                                          const Duration(
                                              hours: 5, minutes: 30));
                                      // print(
                                      // 'Parsed local time (Other) end: $parsedTime');
                                      // print(
                                      // 'Converted IST time (Other) end: $istTime');
                                      return istTime;
                                    }
                                  } catch (e) {
                                    // print(
                                    // 'Date parsing error forend "${process['date_start']}": $e');
                                    return null;
                                  }
                                }()
                              : null;
                          final isDone = currentStatus == 'done';
                          final isProgress = currentStatus == 'progress' ||
                              currentStatus == 'resume';
                          final isStopDisabled = isDone ||
                              (completeInput == 1 && currentStatus == 'ready');
                          return Card(
                            margin: const EdgeInsets.only(bottom: 16),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    height: 40,
                                    decoration: BoxDecoration(
                                      color: Colors.orange[200],
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Center(child: Text(processName)),
                                  ),
                                  const SizedBox(height: 16),
                                  GestureDetector(
                                    onTap: isDone
                                        ? null
                                        : () => _showSelectionModal(
                                              context: context,
                                              processName: processName,
                                              title: 'Select Assembly Type',
                                              options: assemblyTypes,
                                              currentSelection:
                                                  selectedAssemblyTypes[
                                                      processName],
                                              onDone: (selection) {
                                                setState(() {
                                                  selectedAssemblyTypes[
                                                      processName] = selection;
                                                  print(
                                                      'janskajskaj ${selectedAssemblyTypes[processName]}');
                                                });
                                              },
                                              isMultiSelect: false,
                                            ),
                                    child: Center(
                                      child: Text(
                                        selectedAssemblyTypes[processName] ??
                                            'Select Machine Type',
                                        style: TextStyle(
                                            color: isDone
                                                ? Colors.grey
                                                : Colors.blue),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    children: (selectedUsers[processName] ?? [])
                                            .isEmpty
                                        ? [
                                            const Text('No users selected',
                                                style: TextStyle(
                                                    color: Colors.grey))
                                          ]
                                        : (processes[index]['users2']
                                                    as List<dynamic>? ??
                                                [])
                                            .map((user) {
                                            final userId = user[
                                                'alfadock_id']; // or 'id', whichever is used
                                            final userName =
                                                userIdNameMap[userId] ?? '';
                                            final staffName =
                                                userIdToStaffNameMap[userId] ??
                                                    '';
                                            // print(
                                            // 'sdsds $currentSelectionNames');
                                            // Use correct map based on _userDisplay
                                            final displayName =
                                                (_userDisplay == 1
                                                    ? (staffName.isNotEmpty
                                                        ? staffName
                                                        : userName)
                                                    : userName);
                                            return Chip(
                                              label: Text(widget.erpUrlBase ==
                                                      "https://www.alfadock-pack.com"
                                                  ? displayName
                                                  : '${user['name'] ?? ''}'),
                                              deleteIcon: const Icon(
                                                  Icons.close,
                                                  size: 18),
                                              onDeleted: isDone
                                                  ? null
                                                  : () => _removeUser(
                                                      processName,
                                                      user['name']),
                                            );
                                          }).toList(),
                                  ),
                                  const SizedBox(height: 16),
                                  GestureDetector(
                                    onTap: isDone
                                        ? null
                                        : () => _showSelectionModal(
                                              context: context,
                                              processName: processName,
                                              title: 'Add Users',
                                              // options: _userDisplay == 1
                                              // ? staffOptions
                                              // : userOptions,
                                              options: widget.erpUrlBase ==
                                                      "https://www.alfadock-pack.com"
                                                  ? optionsuser
                                                  : userOptions,
                                              currentSelection: widget
                                                          .erpUrlBase ==
                                                      "https://www.alfadock-pack.com"
                                                  ? currentSelectionNames
                                                  : selectedUsers[processName],
                                              onDone: (selection) {},
                                              isMultiSelect: true,
                                            ),
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 8),
                                      child: Row(
                                        children: [
                                          Icon(
                                            Icons.add_circle,
                                            color: isDone
                                                ? Colors.grey
                                                : Colors.green,
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            'Add Users',
                                            style: TextStyle(
                                                color: isDone
                                                    ? Colors.grey
                                                    : Colors.blue),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  _buildControlRow(
                                    'Quantity',
                                    quantity,
                                    isDone,
                                    (val) => _updateQuantity(
                                        processName, val, false),
                                    isDone ? quantity : _getRemainingQuantity(),
                                  ),
                                  const SizedBox(height: 12),
                                  _buildControlRow(
                                    'Defect Quantity',
                                    defectQuantity,
                                    isDone,
                                    (val) =>
                                        _updateQuantity(processName, val, true),
                                    null,
                                  ),
                                  const SizedBox(height: 16),
                                  GestureDetector(
                                    onTap: isDone
                                        ? null
                                        : () => _showSelectionModal(
                                              context: context,
                                              processName: processName,
                                              title: 'Select Defect Code',
                                              options: defectTypes,
                                              currentSelection:
                                                  selectedDefects[processName],
                                              onDone: (selection) {
                                                setState(() {
                                                  selectedDefects[processName] =
                                                      selection;
                                                });
                                              },
                                              isMultiSelect: false,
                                            ),
                                    child: Center(
                                      child: Text(
                                        selectedDefects[processName] ??
                                            'Select Defect Code',
                                        style: TextStyle(
                                            color: isDone
                                                ? Colors.grey
                                                : Colors.blue),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 24),
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceAround,
                                    children: [
                                      if (currentStatus == 'ready' && !isDone)
                                        ElevatedButton(
                                          onPressed: () =>
                                              _startProcess(processName),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.green,
                                            shape: const RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.zero),
                                          ),
                                          child: const Text('Start',
                                              style: TextStyle(
                                                  color: Colors.white)),
                                        )
                                      else if ((currentStatus == 'progress' ||
                                              currentStatus == 'resume') &&
                                          !isDone)
                                        ElevatedButton(
                                          onPressed: () =>
                                              _pauseProcess(processName),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.orange,
                                            shape: const RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.zero),
                                          ),
                                          child: const Text('Hold',
                                              style: TextStyle(
                                                  color: Colors.white)),
                                        )
                                      else if (currentStatus == 'pause' &&
                                          !isDone)
                                        ElevatedButton(
                                          onPressed: () =>
                                              _resumeProcess(processName),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.green,
                                            shape: const RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.zero),
                                          ),
                                          child: const Text('Resume',
                                              style: TextStyle(
                                                  color: Colors.white)),
                                        )
                                      else
                                        ElevatedButton(
                                          onPressed: null,
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.grey,
                                            shape: const RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.zero),
                                          ),
                                          child: const Text('Start',
                                              style: TextStyle(
                                                  color: Colors.white)),
                                        ),
                                      ElevatedButton(
                                        onPressed: isStopDisabled
                                            ? null
                                            : () => _stopProcess(processName),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: isStopDisabled
                                              ? Colors.grey
                                              : Colors.red,
                                          shape: const RoundedRectangleBorder(
                                              borderRadius: BorderRadius.zero),
                                        ),
                                        child: const Text('Stop',
                                            style:
                                                TextStyle(color: Colors.white)),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 16),
                                  Center(
                                    child: Text(
                                      processes[index]['status'] == 'progress'
                                          ? _formatTime(
                                              TimerManager.getElapsedSeconds(
                                                  processName))
                                          : (processes[index]['duration'] ??
                                              '00:00:00'),
                                      style: const TextStyle(
                                          fontSize: 24,
                                          fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            'Start date: ${startDateTime != null ? DateFormat('yyyy-MM-dd').format(startDateTime) : ''}',
                                          ),
                                          Text(
                                            'End date: ${endDateTime != null ? DateFormat('yyyy-MM-dd').format(endDateTime) : ''}',
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            'Start time: ${startDateTime != null ? DateFormat('HH:mm:ss').format(startDateTime) : ''}',
                                          ),
                                          Text(
                                            'End time: ${endDateTime != null ? DateFormat('HH:mm:ss').format(endDateTime) : ''}',
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 24),
                                  if (showCancelButton)
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.start,
                                      children: [
                                        OutlinedButton(
                                          onPressed: () =>
                                              Navigator.pop(context),
                                          style: OutlinedButton.styleFrom(
                                            shape: const RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.zero),
                                          ),
                                          child: const Text('Cancel'),
                                        ),
                                      ],
                                    ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
          if (isLoading)
            Container(
              color: Colors.black54,
              child: const Center(
                child: CircularProgressIndicator(color: Colors.white),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildControlRow(String label, int value, bool isDone,
      Function(int) onChanged, int? maxQuantity) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          SizedBox(width: 120, child: Text(label)),
          Container(
            width: 60,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(value.toString()),
          ),
          const SizedBox(width: 8),
          _qtyButton(Icons.remove,
              isDone || value <= 0 ? null : () => onChanged(value - 1)),
          const SizedBox(width: 8),
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

class TimerManager {
  static final Map<String, Timer> _timers = {};
  static final Map<String, int> _elapsedSeconds = {};
  static void startTimer(
      String processName, int initialSeconds, VoidCallback onTick) {
    _timers[processName]?.cancel();
    _elapsedSeconds[processName] = initialSeconds;
    _timers[processName] = Timer.periodic(const Duration(seconds: 1), (timer) {
      _elapsedSeconds[processName] = (_elapsedSeconds[processName] ?? 0) + 1;
      onTick(); // Notify UI to update
      _saveElapsedSeconds(processName, _elapsedSeconds[processName] ?? 0);
    });
  }

  static void stopTimer(String processName) {
    _timers[processName]?.cancel();
    _timers.remove(processName);
  }

  static int getElapsedSeconds(String processName) {
    return _elapsedSeconds[processName] ?? 0;
  }

  static Future<void> _saveElapsedSeconds(
      String processName, int seconds) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('elapsedSeconds_${processName}', seconds);
  }

  static Future<int> _loadElapsedSeconds(String processName) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt('elapsedSeconds_${processName}') ?? 0;
  }
}

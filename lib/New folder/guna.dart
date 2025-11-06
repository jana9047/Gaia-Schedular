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
  Map<String, String?> selectedDefects = {};
  Map<String, Timer?> timers = {};
  Map<String, int> elapsedSeconds = {};
  List<Map<String, dynamic>> operators = [];
  List<Map<String, dynamic>> machines = [];
  Map<String, dynamic>? processListData;
  bool showCancelButton = false;
  int completeInput = 0;
  List<Map<String, dynamic>> fileList = [];
  List<String> assemblyTypes = [];
  List<String> userOptions = [];
  List<String> defectTypes = [];

  @override
  void initState() {
    super.initState();
    _loadSelectedAssemblyTypes();
    _fetchSchedulerSettings();
    _fetchInitialProcessStatus();
    _fetchProcessListData();
    _loadCancelFunctionSetting();
    _loadCompleteInputSetting();
    _fetchFiles();
  }

  @override
  void dispose() {
    for (var timer in timers.values) {
      timer?.cancel();
    }
    super.dispose();
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
    print('Saved selectedAssemblyTypes: $selectedAssemblyTypes');
  }

  Future<void> _saveElapsedSeconds(String processName, int seconds) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(
      'elapsedSeconds_${widget.processData['id']}_$processName',
      seconds,
    );
    final processIndex = processes.indexWhere((p) => p['name'] == processName);
    if (processIndex != -1 && processes[processIndex]['date_start'] != null) {
      await prefs.setString(
        'dateStart_${widget.processData['id']}_$processName',
        processes[processIndex]['date_start'],
      );
    }
    print('Saved elapsedSeconds for $processName: $seconds');
  }

  Future<String?> _loadDateStart(String processName) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs
        .getString('dateStart_${widget.processData['id']}_$processName');
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
        if (widget.erpUrlBase == "https://www.alfadock-pack.com") {
          userOptions = List<String>.from(response['userOptions'] ?? []);
          operators =
              List<Map<String, dynamic>>.from(response['operators'] ?? []);
        } else {
          userOptions = List<String>.from(
              (response['operators'] as List<dynamic>? ?? [])
                  .map((operator) => operator['name'] as String));
          operators =
              List<Map<String, dynamic>>.from(response['operators'] ?? []);
        }
        defectTypes = List<String>.from(
            (response['defect_codes'] as List<dynamic>? ?? [])
                .map((defect) => defect['name'] as String));
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
      ).timeout(
        const Duration(seconds: 10),
        onTimeout: () => throw TimeoutException('Process list fetch timed out'),
      );
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
    timers[processName]?.cancel();
    elapsedSeconds[processName] = accumulatedDuration;
    if (startDateTime != null) {
      final additionalSeconds = DateTime.now()
          .difference(startDateTime)
          .inSeconds
          .clamp(0, double.infinity)
          .toInt();
      elapsedSeconds[processName] = accumulatedDuration + additionalSeconds;
    }
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
        ).timeout(
          const Duration(seconds: 10),
          onTimeout: () =>
              throw TimeoutException('Process status fetch timed out'),
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
        ).timeout(
          const Duration(seconds: 10),
          onTimeout: () => throw TimeoutException('Add sub-process timed out'),
        );
        print('Created new sub-process SP$suffix: ${jsonEncode(addResponse)}');
        setState(() {
          processes.add({
            'id': addResponse['id'].toString() ?? '',
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
        final initialQuantity =
            int.tryParse(widget.processData['quantity']?.toString() ?? '25') ??
                25;
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
        ).timeout(
          const Duration(seconds: 10),
          onTimeout: () =>
              throw TimeoutException('Create sub-process timed out'),
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to create new sub-process: $e')),
      );
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
      case '2':
        return 'pause';
      case '4':
        return 'done';
      default:
        return 'ready';
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
      if (processIndex == -1) {
        print('Process $processName not found');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Process $processName not found')),
        );
        return;
      }
      final process = processes[processIndex];
      final updatedProcess = Map<String, dynamic>.from(process);
      updatedProcess['status'] = status == 'resume' ? 'progress' : status;
      if (status == 'progress' && process['date_start'] == null) {
        updatedProcess['date_start'] =
            DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now());
      }
      if (status == 'done' || status == 'pause') {
        updatedProcess['date_end'] =
            DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now());
        updatedProcess['duration'] =
            _formatTime(elapsedSeconds[processName] ?? 0);
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
        ).timeout(
          const Duration(seconds: 10),
          onTimeout: () =>
              throw TimeoutException('Update process status timed out'),
        );
        print(
            'Updated process status for $processName: ${jsonEncode(response)}');
        if (status == 'done' &&
            response['message']
                    ?.contains('Cannot change a completed work order') ==
                true) {
          print(
              'Cannot update $processName to done: parent process (pid=${widget.processData['id']}) is already done');
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text(
                    'Cannot update $processName: Parent process is already completed')),
          );
          return;
        }
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
        final defectName = selectedDefects[processName] ?? '';
        final defectCodeId = defectTypes.contains(defectName)
            ? defectTypes.indexOf(defectName).toString()
            : '0';
        final response = await startProcess(
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
        ).timeout(
          const Duration(seconds: 10),
          onTimeout: () =>
              throw TimeoutException('Update process status timed out'),
        );
        print(
            'startProcess response for $processName: ${jsonEncode(response)}');
        if (status == 'done' &&
            response['message']
                    ?.contains('Cannot change a completed work order') ==
                true) {
          print(
              'Cannot update $processName to done: parent process (pid=${widget.processData['id']}) is already done');
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text(
                    'Cannot update $processName: Parent process is already completed')),
          );
          return;
        }
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
      });
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
        ).timeout(
          const Duration(seconds: 10),
          onTimeout: () => throw TimeoutException('Update machine timed out'),
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
        ).timeout(
          const Duration(seconds: 10),
          onTimeout: () =>
              throw TimeoutException('Update process machine timed out'),
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
      final initialQuantity =
          int.tryParse(widget.processData['quantity']?.toString() ?? '25') ??
              25;
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
      final remainingQuantity = _getRemainingQuantity();
      final maxQuantity =
          process['status'] == 'done' ? process['qty'] : remainingQuantity;
      final updatedQty = isDefectQty
          ? (int.tryParse(process['qty']?.toString() ?? '0') ?? 0)
          : newQty.clamp(0, maxQuantity);
      final updatedDefectQty = isDefectQty
          ? newQty.clamp(0, double.infinity).toInt()
          : (int.tryParse(process['defect_qty']?.toString() ?? '0') ?? 0);
      final updatedProcess = Map<String, dynamic>.from(process);
      updatedProcess['qty'] = updatedQty;
      updatedProcess['defect_qty'] = updatedDefectQty;
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
          status: process['status'] == 'resume'
              ? '1'
              : _mapStatusToCode(process['status']?.toString() ?? 'ready'),
          machineId: machine['id']?.toString() ?? '0',
          quantity: updatedQty.toString(),
          defectQuantity: updatedDefectQty.toString(),
          defectCode: defectCode,
        ).timeout(
          const Duration(seconds: 10),
          onTimeout: () => throw TimeoutException('Update quantity timed out'),
        );
        print(
            'Quantity update response for $processName: ${jsonEncode(response)}');
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
        ).timeout(
          const Duration(seconds: 10),
          onTimeout: () => throw TimeoutException('Update quantity timed out'),
        );
        print(
            'Quantity update response for $processName: ${jsonEncode(response)}');
        await _fetchUpdatedProcessStatus(processName);
      }
    } catch (e) {
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
          quantity: process['qty']?.toString() ?? '0',
          defectQuantity: process['defect_qty']?.toString() ?? '0',
          defectCode: defectCode,
        ).timeout(
          const Duration(seconds: 10),
          onTimeout: () => throw TimeoutException('Update users timed out'),
        );
        print(
            'Update users response for $processName: ${jsonEncode(response)}');
        await _fetchUpdatedProcessStatus(processName);
      } else {
        final response = await updateProcessUsers(
          pid: int.parse(widget.processData['id'].toString()),
          erpUrlBase: widget.erpUrlBase,
          id: process['id']?.toString() ?? '',
          name: processName,
          qty: process['qty']?.toString() ?? '0',
          users: userObjects,
        ).timeout(
          const Duration(seconds: 10),
          onTimeout: () => throw TimeoutException('Update users timed out'),
        );
        print(
            'Update users response for $processName: ${jsonEncode(response)}');
        await _fetchUpdatedProcessStatus(processName);
      }
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
    print('Starting process $processName');
    await _updateProcessStatus('progress', processName);
  }

  void _pauseProcess(String processName) async {
    print('Pausing process $processName');
    await _updateProcessStatus('pause', processName);
  }

  void _resumeProcess(String processName) async {
    print('Resuming process $processName');
    final processIndex = processes.indexWhere((p) => p['name'] == processName);
    if (processIndex != -1 && processes[processIndex]['date_start'] == null) {
      setState(() {
        processes[processIndex]['date_start'] =
            DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now());
      });
    }
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
    dynamic tempSelection = isMultiSelect
        ? List<String>.from(currentSelection ?? [])
        : currentSelection;
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
                            _updateProcessUsers(
                                processName, selectedUsers[processName] ?? []);
                          } else if (title == 'Select Assembly Type') {
                            setState(() {
                              selectedAssemblyTypes[processName] =
                                  tempSelection;
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

  void _removeUser(String processName, String user) {
    setState(() {
      selectedUsers[processName] =
          List<String>.from(selectedUsers[processName] ?? [])..remove(user);
    });
    _updateProcessUsers(processName, selectedUsers[processName] ?? []);
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
        final savedDateStart = await _loadDateStart(processName);
        if (process['status'] == 'progress' && savedDateStart != null) {
          final startDateTime = DateTime.parse(savedDateStart);
          final currentElapsed = DateTime.now()
              .difference(startDateTime)
              .inSeconds
              .clamp(0, double.infinity)
              .toInt();
          final totalElapsed = savedSeconds + currentElapsed;
          setState(() {
            elapsedSeconds[processName] = totalElapsed;
            process['duration'] = _formatTime(totalElapsed);
            _startTimer(processName, startDateTime, totalElapsed);
          });
          await _saveElapsedSeconds(processName, totalElapsed);
        } else if (savedSeconds > 0 && process['status'] != 'progress') {
          setState(() {
            elapsedSeconds[processName] = savedSeconds;
            process['duration'] = _formatTime(savedSeconds);
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
          final machineName = widget.processData['machineName']?.toString();
          if (machineName != null && !assemblyTypes.contains(machineName)) {
            assemblyTypes.add(machineName);
            machines.add({'id': machineName, 'name': machineName});
          }
          selectedAssemblyTypes[processName] =
              assemblyTypes.contains(machineName) ? machineName : null;
          selectedDefects[processName] = selectedDefects[processName];
        }
        _saveSelectedAssemblyTypes();
      });
      await _createNewSubProcess();
    } finally {
      setState(() {
        isLoading = false;
      });
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
      ).timeout(
        const Duration(seconds: 10),
        onTimeout: () =>
            throw TimeoutException('Process status fetch timed out'),
      );
      print(
          'submitProcessStatus response for pid=${widget.processData['id']}: ${jsonEncode(response)}');
      setState(() {
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
                final machineName =
                    widget.processData['machineName']?.toString();
                if (machineName != null &&
                    !assemblyTypes.contains(machineName)) {
                  assemblyTypes.add(machineName);
                  machines.add({'id': machineName, 'name': machineName});
                }
                selectedAssemblyTypes[processName] =
                    assemblyTypes.contains(machineName) ? machineName : null;
                selectedDefects[processName] = selectedDefects[processName];
              }
              _saveSelectedAssemblyTypes();
            }
            return;
          }
          final records = List<Map<String, dynamic>>.from(
              response['value']['submitProcessList']);
          if (targetProcessName != null) {
            final record = records.firstWhere(
              (r) =>
                  r['numberInName']?.toString() ==
                      targetProcessName.replaceFirst('SP', '') ||
                  r['id']?.toString() ==
                      processes.firstWhere(
                          (p) => p['name'] == targetProcessName,
                          orElse: () => {})['id'],
              orElse: () => {},
            );
            if (record.isNotEmpty) {
              final processIndex =
                  processes.indexWhere((p) => p['name'] == targetProcessName);
              final processName = 'SP${record['numberInName'] ?? 1}';
              final status = _mapAlfaDockStatus(record['currentStatus']);
              final startDateTime =
                  record['startTime'] != null && record['startTime'].isNotEmpty
                      ? DateTime.tryParse(record['startTime'].toString())
                      : (processIndex != -1
                          ? processes[processIndex]['date_start']
                          : null);
              final accumulatedDuration =
                  _parseDuration(record['duration'] ?? '00:00:00');
              final savedSeconds = elapsedSeconds[processName] ?? 0;
              final machineName = record['machineName'] as String? ??
                  widget.processData['machineName']?.toString();
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
                'date_start': startDateTime?.toIso8601String() ??
                    (processIndex != -1
                        ? processes[processIndex]['date_start']
                        : null),
                'date_end': status == 'ready'
                    ? null
                    : (record['finishTime'] ??
                        (processIndex != -1
                            ? processes[processIndex]['date_end']
                            : null)),
                'users2': (record['users'] as List<dynamic>?)?.map((user) {
                      return operators.firstWhere(
                        (op) =>
                            op['id'] == user['id'] &&
                            op['name'] == user['name'],
                        orElse: () => {
                          'id': user['id'] ?? 0,
                          'name': user['name'] ?? '',
                          'alfadock_id': user['id'] ?? 0,
                          'staff_name': user['staff_name'] ?? '',
                        },
                      );
                    }).toList() ??
                    (processIndex != -1
                        ? processes[processIndex]['users2']
                        : []),
              };
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
              selectedUsers[processName] = apiUsers;
              selectedAssemblyTypes[processName] =
                  assemblyTypes.contains(machineName)
                      ? machineName
                      : selectedAssemblyTypes[processName];
              selectedDefects[processName] = defectTypes.contains(defectCode)
                  ? defectCode
                  : (selectedDefects[processName]);
            }
          } else {
            processes = [];
            for (var record in records) {
              final processName = 'SP${record['numberInName'] ?? 1}';
              final status = _mapAlfaDockStatus(record['currentStatus']);
              final startDateTime =
                  record['startTime'] != null && record['startTime'].isNotEmpty
                      ? DateTime.tryParse(record['startTime'].toString())
                      : null;
              final accumulatedDuration =
                  _parseDuration(record['duration'] ?? '00:00:00');
              final savedSeconds = elapsedSeconds[processName] ?? 0;
              final machineName = record['machineName'] as String? ??
                  widget.processData['machineName']?.toString();
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
                'date_start': startDateTime?.toIso8601String(),
                'date_end': status == 'ready' ? null : record['finishTime'],
                'users2': (record['users'] as List<dynamic>?)?.map((user) {
                      return operators.firstWhere(
                        (op) =>
                            op['id'] == user['id'] &&
                            op['name'] == user['name'],
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
              final apiUsers = (record['users'] as List<dynamic>?)
                      ?.map((user) => user['name'] as String)
                      .toList() ??
                  [];
              selectedUsers[processName] = apiUsers;
              selectedAssemblyTypes[processName] =
                  assemblyTypes.contains(machineName)
                      ? machineName
                      : selectedAssemblyTypes[processName];
              selectedDefects[processName] = defectTypes.contains(defectCode)
                  ? defectCode
                  : (selectedDefects[processName]);
            }
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
                final machineName =
                    widget.processData['machineName']?.toString();
                if (machineName != null &&
                    !assemblyTypes.contains(machineName)) {
                  assemblyTypes.add(machineName);
                  machines.add({'id': machineName, 'name': machineName});
                }
                selectedAssemblyTypes[processName] =
                    assemblyTypes.contains(machineName) ? machineName : null;
                selectedDefects[processName] = selectedDefects[processName];
              }
              _saveSelectedAssemblyTypes();
            }
            return;
          }
          final records = List<Map<String, dynamic>>.from(response['records']);
          if (targetProcessName != null) {
            final record = records.firstWhere(
              (r) =>
                  r['name']?.toUpperCase() == targetProcessName ||
                  r['id']?.toString() ==
                      processes.firstWhere(
                          (p) => p['name'] == targetProcessName,
                          orElse: () => {})['id'],
              orElse: () => {},
            );
            if (record.isNotEmpty) {
              final processIndex =
                  processes.indexWhere((p) => p['name'] == targetProcessName);
              final status =
                  record['status'] == 'resume' ? 'progress' : record['status'];
              final machineName = record['machine_name'] as String? ??
                  widget.processData['machineName']?.toString();
              final defectReason = record['defect_reason'] as String?;
              final accumulatedDuration = _parseDuration(record['duration']);
              final savedSeconds = elapsedSeconds[targetProcessName] ?? 0;
              if (machineName != null && !assemblyTypes.contains(machineName)) {
                assemblyTypes.add(machineName);
                machines.add({'id': machineName, 'name': machineName});
              }
              final updatedProcess = {
                'id': record['id']?.toString() ?? processes[processIndex]['id'],
                'name': targetProcessName,
                'qty': record['qty'] ?? processes[processIndex]['qty'],
                'defect_qty': record['defect_qty'] ??
                    processes[processIndex]['defect_qty'],
                'status': status,
                'duration': status == 'ready'
                    ? '00:00:00'
                    : _formatTime(
                        savedSeconds > 0 ? savedSeconds : accumulatedDuration),
                'date_start': record['date_start'] ??
                    processes[processIndex]['date_start'],
                'date_end': status == 'ready'
                    ? null
                    : (record['date_end'] ??
                        processes[processIndex]['date_end']),
                'users2': (record['users2'] as List<dynamic>?)?.map((user) {
                      return operators.firstWhere(
                        (op) =>
                            op['id'] == user['id'] &&
                            op['name'] == user['name'],
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
              processes[processIndex] = updatedProcess;
              final currentStatus = status?.toString() ?? 'ready';
              final startDateTime = record['date_start'] != null
                  ? DateTime.tryParse(record['date_start'].toString())
                  : (updatedProcess['date_start'] != null
                      ? DateTime.parse(updatedProcess['date_start'])
                      : null);
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
                  assemblyTypes.contains(machineName)
                      ? machineName
                      : selectedAssemblyTypes[targetProcessName];
              selectedDefects[targetProcessName] =
                  defectTypes.contains(defectReason)
                      ? defectReason
                      : (selectedDefects[targetProcessName]);
            }
          } else {
            processes = [];
            for (var record in records) {
              final processName =
                  (record['name'] ?? 'SP1').toString().toUpperCase();
              final status =
                  record['status'] == 'resume' ? 'progress' : record['status'];
              final machineName = record['machine_name'] as String? ??
                  widget.processData['machineName']?.toString();
              final defectReason = record['defect_reason'] as String?;
              final accumulatedDuration = _parseDuration(record['duration']);
              final savedSeconds = elapsedSeconds[processName] ?? 0;
              if (machineName != null && !assemblyTypes.contains(machineName)) {
                assemblyTypes.add(machineName);
                machines.add({'id': machineName, 'name': machineName});
              }
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
                'date_start': record['date_start'],
                'date_end': status == 'ready' ? null : record['date_end'],
                'users2': (record['users2'] as List<dynamic>?)?.map((user) {
                      return operators.firstWhere(
                        (op) =>
                            op['id'] == user['id'] &&
                            op['name'] == user['name'],
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
              selectedUsers[processName] = apiUsers;
              selectedAssemblyTypes[processName] =
                  assemblyTypes.contains(machineName)
                      ? machineName
                      : selectedAssemblyTypes[processName];
              selectedDefects[processName] = defectTypes.contains(defectReason)
                  ? defectReason
                  : (selectedDefects[processName]);
            }
          }
          processes.sort((a, b) => (a['name'] as String).compareTo(b['name']));
          _saveSelectedAssemblyTypes();
        }
      });
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
      ).timeout(
        const Duration(seconds: 10),
        onTimeout: () => throw TimeoutException('File fetch timed out'),
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
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
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
                  padding:
                      const EdgeInsets.symmetric(vertical: 4, horizontal: 12),
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
                      final String? thumbnailGuid = file['thumbnailGuid'];
                      final String fileName = file['fileName'] ?? 'Unnamed';
                      final String? guid = file['guid'];
                      return Padding(
                        padding: const EdgeInsets.only(right: 8.0),
                        child: Chip(
                          backgroundColor: Colors.grey[200],
                          label: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              if (thumbnailGuid != null)
                                GestureDetector(
                                  onTap: () {
                                    final downloadUrl =
                                        'https://www.alfadock-pack.com/api/file/downloadfilebyguid?guid=$guid&filename=$fileName';
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
                                  child: Image.network(
                                    thumbnailGuid,
                                    width: 50,
                                    height: 50,
                                    fit: BoxFit.cover,
                                    errorBuilder:
                                        (context, error, stackTrace) =>
                                            Icon(Icons.broken_image, size: 50),
                                  ),
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
                      );
                    },
                  ),
                )
              else
                Text('No files available'),
            ],
          ),
          Expanded(
            child: isLoading
                ? const Center(child: CircularProgressIndicator())
                : processes.isEmpty
                    ? const Center(child: Text('No processes available'))
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: processes.length,
                        itemBuilder: (context, index) {
                          final process = processes[index];
                          final processName = process['name'] ?? 'SP1';
                          final quantity =
                              int.tryParse(process['qty']?.toString() ?? '0') ??
                                  0;
                          final defectQuantity = int.tryParse(
                                  process['defect_qty']?.toString() ?? '0') ??
                              0;
                          final currentStatus = process['status']?.toString();
                          final startDateTime = process['date_start'] != null
                              ? DateTime.tryParse(
                                  process['date_start'].toString())
                              : null;
                          final endDateTime = process['date_end'] != null
                              ? DateTime.tryParse(
                                  process['date_end'].toString())
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
                                                  assemblyTypes.contains(
                                                          selectedAssemblyTypes[
                                                              processName])
                                                      ? selectedAssemblyTypes[
                                                          processName]
                                                      : null,
                                              onDone: (selection) {
                                                setState(() {
                                                  selectedAssemblyTypes[
                                                      processName] = selection;
                                                });
                                                _updateProcessMachine(
                                                    processName, selection);
                                                _saveSelectedAssemblyTypes();
                                              },
                                              isMultiSelect: false,
                                            ),
                                    child: Center(
                                      child: Text(
                                        assemblyTypes.contains(
                                                selectedAssemblyTypes[
                                                    processName])
                                            ? selectedAssemblyTypes[
                                                    processName] ??
                                                'Select Machine Type'
                                            : 'Select Machine Type',
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
                                            return Chip(
                                              label: Text(
                                                  '${user['name']} (${user['alfadock_id']})'),
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
                                              options: userOptions,
                                              currentSelection:
                                                  selectedUsers[processName],
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
                                      isProgress
                                          ? _formatTime(
                                              elapsedSeconds[processName] ?? 0)
                                          : (process['duration'] ?? '00:00:00'),
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
          _qtyButton(
              Icons.add,
              isDone || (maxQuantity != null && value >= maxQuantity)
                  ? null
                  : () => onChanged(value + 1)),
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

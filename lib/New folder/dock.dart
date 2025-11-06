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
              _stopTimerDock(processName); // Use AlfaDock-specific stop timer
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
            int pausedDurationSeconds = 0; // Separate variable for timer resume

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
                final lastStartUtc = DateTime.parse(lastStartTime).toUtc();
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
                pausedDurationSeconds = (newdura + Duration).toInt();
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
              }
            }

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
                  : _formatTime(_calculateElapsedTimeFromAPI(
                      record)), // Updated this line
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

            print('updatedProcessjana: ${jsonEncode(updatedProcess)}');

            if (processIndex != -1) {
              processes[processIndex] = updatedProcess;
            } else {
              processes.add(updatedProcess);
            }

            if (status == 'progress') {
              // Use pausedDurationSeconds for timer resume instead of newDurationSeconds
              _startTimerDock(
                processName,
                startDateTime ??
                    (updatedProcess['date_start'] != null
                        ? DateTime.parse(updatedProcess['date_start'])
                        : DateTime.now()),
                pausedDurationSeconds > 0
                    ? pausedDurationSeconds // Use pausedDurationSeconds for timer
                    : (savedSeconds > 0 ? savedSeconds : accumulatedDuration),
              );
            } else {
              _stopTimerDock(processName); // Use AlfaDock-specific stop timer
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
            print('sid: $sid');

            int newDurationSeconds = 0;
            int pausedDurationSeconds = 0; // Separate variable for timer resume

            if (sid > 0) {
              final spDetails = await getspdetails(
                sid: sid,
                erpUrlBase: widget.erpUrlBase,
                userId: widget.userId ?? '0',
              );
              print('spDetails: ${jsonEncode(spDetails)}');
              final lastStartTime = spDetails['value']?['lastStartTime'];
              print('lastStartTime: $lastStartTime');
              final startTimeStr =
                  record['startTime']?.toString(); // Changed from finishTime
              print('lastStartTime for sid $sid: $lastStartTime');
              final Duration =
                  spDetails['value']?['durationBeforeResume'] ?? '00:00:00';
              print('Duration before resume: $Duration');

              if (lastStartTime != null) {
                final lastStartUtc = DateTime.parse(lastStartTime).toUtc();
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

                // Calculate pausedDurationSeconds for timer resume
                pausedDurationSeconds = (newdura + Duration).toInt();
                print(
                    'pausedDurationSeconds for timer resume: $pausedDurationSeconds');
                print(
                    'New duration (seconds) from lastStartTime to nowkkjk: $newdura');

                // Keep newDurationSeconds as Duration (unchanged as requested)
                newDurationSeconds = Duration;
                print(
                    'New duration (seconds) from lastStartTime to now: $newDurationSeconds');
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

                
              }
            }

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
            };

            print('updatedProcesskama: ${jsonEncode(updatedProcess)}');
            processes.add(updatedProcess);

            if (status == 'progress') {
              // Use pausedDurationSeconds for timer resume instead of newDurationSeconds
              _startTimerDock(
                processName,
                startDateTime ??
                    (updatedProcess['date_start'] != null
                        ? DateTime.parse(updatedProcess['date_start'])
                        : DateTime.now()),
                pausedDurationSeconds > 0
                    ? pausedDurationSeconds // Use pausedDurationSeconds for timer
                    : (savedSeconds > 0 ? savedSeconds : accumulatedDuration),
              );
            } else {
              _stopTimerDock(processName); // Use AlfaDock-specific stop timer
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
      }
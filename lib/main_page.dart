import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:barcode_scan2/barcode_scan2.dart';
import 'package:intl/intl.dart';
import 'api.dart';
import 'setting.dart';
import 'submit_process.dart';
import 'package:http/http.dart' as http;
import 'l10n/app_localizations.dart';
import 'locale_provider.dart'; // Add the correct import path for LocaleProvider
import 'package:provider/provider.dart';

import 'app_state.dart';

String? globaluserType;
// Map<String, dynamic>? globalSchedulerdataAlfadock_id;
int? globalSchedulerdataAlfadock_id;
List<dynamic> filteringdata = [];

class MainPage extends StatefulWidget {
  const MainPage({super.key});

  @override
  _MainPageState createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {
  bool _showPreviousBox = false;
  bool _showTodayBox = false;
  bool _showNextBox = false;
  Map<String, dynamic>? args;
  int? userId;
  int? compId;
  String? userType;
  String? erpUrlBase;
  List<Map<String, dynamic>> processList = [];
  Map<String, dynamic>? alfaERPProcessResponse;
  String searchText = '';
  final TextEditingController _searchController = TextEditingController();
  int completeprocess = 0; // 0: On, 1: Off
  bool _isLoading = false; // Added for loading state

  List<Map<String, dynamic>> previousProcesses = [];
  List<Map<String, dynamic>> todayProcesses = [];
  List<Map<String, dynamic>> nextProcesses = [];
  List<String> selectedProcessNames = [];
  String _selectedLanguage = 'language_ja';

  @override
  void initState() {
    super.initState();
    setState(() {
      searchText = '';
      _searchController.text = '';
    });
    _initializeData();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (args == null) {
      args =
          ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
      userId = args?['userId'];
      compId = args?['compId'];
      userType = args?['userType'];
      globaluserType = args?['username'];
      print('globaluserType in mainpage $globaluserType');
      print('DEBUG: MainPage didChangeDependencies - userId: $userId, '
          'compId: $compId, userType: $userType');
      if (userId != null && compId != null && userType != null) {
        _initializeData();
      }
    }
  }

  Future<void> _initializeData() async {
    final savedCompleteProcess = await AppState.getCompleteProcess();
    setState(() {
      completeprocess = savedCompleteProcess ?? 0;
    });
    await _fetchUrlLink();
    await _fetchProcessList();
    await _fetchAlfaERPProcessListGet();
  }

  Future<void> _fetchUrlLink() async {
    setState(() {
      _isLoading = true; // Show loading screen
    });
    if (compId != null) {
      try {
        var erpBase = await getUrlLink(compId.toString(), 'sischeduler');
        erpBase ??= "https://www.alfadock-pack.com";
        print('ERP URL Base: $erpBase');
        setState(() {
          erpUrlBase = erpBase;
        });
      } catch (e) {
        print('Error fetching URL link: $e');
      } finally {
        setState(() {
          _isLoading = false; // Hide loading screen
        });
      }
    }
  }

  Future<void> _fetchProcessList() async {
    if (userId != null) {
      setState(() {
        _isLoading = true; // Show loading screen
      });
      try {
        final processes = await getProcessFromUserID(userId.toString());
        setState(() {
          processList = processes;
        });
        print('Process List: $processes');
      } catch (e) {
        print('Error fetching process list: $e');
      } finally {
        setState(() {
          _isLoading = false; // Hide loading screen
        });
      }
    }
  }

  Future<void> _fetchAlfaERPProcessListGet() async {
    if (erpUrlBase != null) {
      setState(() {
        _isLoading = true; // Show loading screen
      });
      final DateTime today = DateTime.now();
      final DateTime ds = today.subtract(Duration(days: 1));
      final DateTime de = today.add(Duration(days: 1));
      final String formattedDs = DateFormat('yyyy-MM-dd').format(ds);
      final String formattedDe = DateFormat('yyyy-MM-dd').format(de);

      try {
        final response = await getAlfaERPProcessListGet(
          erpUrlBase!,
          'sfGa0kl7lO9fXWaE1rENp',
          formattedDs,
          formattedDe,
          userId?.toString() ?? '0',
        );
        final response1 =
            await fetchSchedulerSettings(erpUrlBase!, compId.toString());
        filteringdata = response1['data']['processes'];
        print('response1 ${response1['data']['processes']}');
        print('Alfa ERP Process Listsds Response: $response');
        setState(() {
          alfaERPProcessResponse = response;
          _categorizeProcesses(response);
        });
      } catch (e) {
        print('Error fetching Alfa ERP process listsdsd: $e');
      } finally {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _fetchAlfaERPProcessListWithSearch(String searchText) async {
    final loc = AppLocalizations.of(context);
    if (erpUrlBase == null) {
      throw Exception('ERP URL base is not initialized');
    }

    setState(() {
      _isLoading = true; // Show loading screen
    });

    final DateTime today = DateTime.now();
    final String ds =
        DateFormat('yyyy-MM-dd').format(today.subtract(Duration(days: 366)));
    final String de =
        DateFormat('yyyy-MM-dd').format(today.add(Duration(days: 366)));
    final List<String> searchValues =
        searchText.split(',').map((s) => s.trim()).toList();
    final String sv = searchValues.join(',');

    try {
      Map<String, dynamic> data;
      if (erpUrlBase == "https://www.alfadock-pack.com") {
        // AlfaDOCK API
        final url = Uri.parse('https://www.alfadock-pack.com/api/plugin');
        final argsJson = jsonEncode({
          'userid': userId?.toString() ?? '0',
          'fromDate': ds,
          'toDate': de,
          'searchTexts': searchValues,
          'status': [0, 1, 2, 3, 4], // Include relevant statuses
        });

        print('Calling AlfaDOCK search API: $url with args: $argsJson');

        final request = http.MultipartRequest('POST', url);
        request.fields['plugin'] = 'SchedulerApi';
        request.fields['controller'] = 'SchedulerIOSController';
        request.fields['action'] = 'getAllProcessesWithMultiSearch';
        request.fields['args'] = argsJson;

        final streamedResponse = await request.send();
        final response = await http.Response.fromStream(streamedResponse);

        print('AlfaDOCK search response: ${response.body}');

        if (response.statusCode == 200) {
          data = json.decode(response.body);
        } else {
          throw Exception(
              'Failed to fetch AlfaDOCK process list: ${response.statusCode} - ${response.body}');
        }
      } else {
        // AlfaERP API
        final String key = 'sfGa0kl7lO9fXWaE1rENp';
        final String opd = 'and';
        final url = Uri.parse(
            'https://$erpUrlBase.alfa-erp.com/api/get_alfaerp_data/PROCESSLIST?key=$key&ds=$ds&de=$de&sv=$sv&opd=$opd');
        print('Calling AlfaERP search API: $url');

        final response = await http.get(url);
        print('AlfaERP search response: ${response.body}');

        if (response.statusCode == 200) {
          data = jsonDecode(response.body);
        } else {
          throw Exception(
              'Failed to fetch AlfaERP process list: ${response.statusCode} - ${response.body}');
        }
      }

      setState(() {
        alfaERPProcessResponse = data;
        _categorizeProcesses(data);
      });
    } catch (e) {
      print('Error fetching process list with search: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${loc.anerroroccured} $e')),
      );
    } finally {
      setState(() {
        _isLoading = false; // Hide loading screen
      });
    }
  }

  void _categorizeProcesses(Map<String, dynamic>? response) {
    if (response == null || !response.containsKey('value')) {
      return;
    }

    print(erpUrlBase);
    print('Categorizing processes from response: $response');

    final List<dynamic> processes = response['value'];
    final DateTime today =
        DateTime.now().toUtc().toLocal(); // 2025-09-04 10:53:46.299723Z
    print(today);
    final DateTime todayStart = DateTime(today.year, today.month, today.day);
    print('todaystart $todayStart');
    // Use startDate for AlfaDock, otherwise use plannedStartDate
    final String dateKey = (erpUrlBase == "https://www.alfadock-pack.com")
        ? 'startDate'
        : 'plannedStartDate';

    // Filter processes based on completeprocess setting
    var filteredProcesses = completeprocess == 1
        ? processes.where((process) {
            final statusValue = process['status'];
            if (erpUrlBase == "https://www.alfadock-pack.com") {
              return statusValue?.toString() !=
                  '2'; // Exclude "Finished" (status 2)
            } else {
              return (statusValue?.toString() ?? '').toLowerCase() !=
                  'done'; // Exclude "done"
            }
          }).toList()
        : processes; // No filtering when completeprocess is On (0)

    // FOR REGULAR USERS: Filter by process names from processList
    print('usertypecat $userType');

    print('filtered $filteredProcesses');
    print('processlist $processList');
    if (userType == 'User') {
      List<String> allowedProcessNames;

      // If user has made selections in filter page, use those
      if (selectedProcessNames.isNotEmpty) {
        allowedProcessNames = selectedProcessNames
            .map((name) => _normalizeProcessName(name))
            .toList();
        print('Using selectedProcessNames for filtering: $allowedProcessNames');
      } else {
        // Otherwise, use the default processList
        allowedProcessNames = processList
            .map((process) => process['name']?.toString() ?? '')
            .where((name) => name.isNotEmpty)
            .map((name) => _normalizeProcessName(name))
            .toList();
        print('Using processList for filtering: $allowedProcessNames');
      }

      print('Normalized allowed process names: $allowedProcessNames');

      filteredProcesses = filteredProcesses.where((process) {
        final processName = process['name']?.toString() ?? '';
        final normalizedProcessName = _normalizeProcessName(processName);

        // Check if the normalized process name exists in allowed list
        final isAllowed = allowedProcessNames.contains(normalizedProcessName);

        if (!isAllowed) {
          print(
              'Filtering out process: $processName (normalized: $normalizedProcessName)');
        }

        return isAllowed;
      }).toList();

      print('Filtered processes for user: ${filteredProcesses.length}');
    }

    // Filter by selected process names if not empty and not searching
    if (selectedProcessNames.isNotEmpty) {
      filteredProcesses = filteredProcesses.where((process) {
        final name = process['name']?.toString() ?? '';
        return selectedProcessNames.contains(name);
      }).toList();
    }

    setState(() {
      previousProcesses = filteredProcesses
          .where((process) {
            final dateString = process[dateKey]?.toString();
            if (dateString == null || dateString.isEmpty) return false;
            final parsedDate = _parseDate(dateString);
            final parsedDateStart = DateTime(parsedDate.year, parsedDate.month,
                parsedDate.day); // Normalize to start of day
            // print('parsed $parsedDateStart');
            return parsedDateStart.isBefore(todayStart);
          })
          .cast<Map<String, dynamic>>()
          .toList();
      print('Previous Processes: $previousProcesses');

      todayProcesses = filteredProcesses
          .where((process) {
            final dateString = process[dateKey]?.toString();
            if (dateString == null || dateString.isEmpty) return false;
            final parsedDate = _parseDate(dateString);
            final parsedDateStart = DateTime(parsedDate.year, parsedDate.month,
                parsedDate.day); // Normalize to start of day
            return parsedDateStart.isAtSameMomentAs(todayStart);
          })
          .cast<Map<String, dynamic>>()
          .toList();
      print('Today Processes: $todayProcesses');

      nextProcesses = filteredProcesses
          .where((process) {
            final dateString = process[dateKey]?.toString();
            if (dateString == null || dateString.isEmpty) return false;
            final parsedDate = _parseDate(dateString);
            final parsedDateStart = DateTime(parsedDate.year, parsedDate.month,
                parsedDate.day); // Normalize to start of day
            return parsedDateStart.isAfter(todayStart);
          })
          .cast<Map<String, dynamic>>()
          .toList();
      print('Next Processes: $nextProcesses');
    });
  }

  String _normalizeProcessName(String name) {
    // Remove extra spaces, convert to lowercase, and trim
    return name.replaceAll(RegExp(r'\s+'), ' ').trim().toLowerCase();
  }

// Assuming this is your date parsing method (add if not present)
  DateTime _parseDate(String dateString) {
    // print('Parsing date: $dateString');
    // Example parsing for "MM/dd/yy hh:mm:ss a" format
    try {
      return DateFormat("MM/dd/yy hh:mm:ss").parse(dateString, true);
    } catch (e) {
      print('Error parsing date: $dateString, error: $e');
      return DateTime.now(); // Fallback to now if parsing fails
    }
  }

  Future<void> _scanBarcode() async {
    final loc = AppLocalizations.of(context);
    try {
      var result = await BarcodeScanner.scan(
        options: ScanOptions(
          strings: {
            "cancel": loc.cancel, // Change Cancel button text
            "flash_on": loc.flashOn, // Change Flash On text
            // Change Flash Off text
          },
          restrictFormat: [], // Optional: restrict formats if needed
          useCamera: -1, // Optional: choose camera (front/back)
        ),
      );

      if (result.rawContent.isNotEmpty) {
        setState(() {
          searchText = result.rawContent;
          _searchController.text = result.rawContent;
        });
        await _fetchAlfaERPProcessListWithSearch(result.rawContent);
      }
    } catch (e) {
      print('Error scanning barcode: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${loc.anerroroccured} $e')),
      );
    }
  }

  Future<void> _navigateToSubmitProcess(
      BuildContext context, Map<String, dynamic> process) async {
    final loc = AppLocalizations.of(context);
    setState(() {
      _isLoading = true; // Show loading screen
    });
    print('DEBUG: Navigating to SubmitProcess with process: $process');
    if (compId == null || erpUrlBase == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Missing company ID or ERP URL base')),
      );
      return;
    }

    try {
      // Fetch scheduler settings using the new function
      final schedulerSettings =
          await fetchSchedulerSettings(erpUrlBase!, compId.toString());
      final erpData = schedulerSettings['data'];
      final mapping = schedulerSettings['mapping'];
      print('Scheduler Settings: $schedulerSettings');
      if (erpData != null && erpData['processes'] != null) {
        List<dynamic> processesList = erpData['processes'];

        String processName = process['name'];
        var match = processesList.firstWhere(
          (p) => p['name'] == processName,
          orElse: () => null,
        );
        print('Matching process: $match');
        if (match != null) {
          var alfadockId = match['alfadock_id'];
          globalSchedulerdataAlfadock_id = alfadockId; // Store as int or String
          print(
              "✅ Found alfadock_id: $alfadockId for process name: $processName");
        } else {
          print("❌ No matching process name found: $processName");
        }
      } else {
        print("⚠️ Scheduler data not loaded yet or no 'operators' field");
      }

      // Fetch foldername from alfaERPProcessResponse
      String? folderName;
      String? folderId;
      if (alfaERPProcessResponse != null &&
          alfaERPProcessResponse!['value'] != null) {
        final processes = alfaERPProcessResponse!['value'] as List<dynamic>;
        final matchingProcess = processes.firstWhere(
          (p) => p['id'] == process['id'],
          orElse: () => {'productNumber': ''},
        );
        folderName = matchingProcess['productNumber']?.toString() ?? '';
        final response = await getFolderIdByFolderName(
            compId.toString(),
            folderName,
            erpUrlBase!,
            process['id'].toString(),
            userId?.toString() ?? '');
        print('responsemain page $response');
        folderId = response.toString();
      }

      if (folderName == null || folderName.isEmpty) {
        print(
            'Error: Could not retrieve foldername for process ID ${process['id']}');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${loc.anerroroccured}')),
        );
        setState(() {
          _isLoading = false; // Show loading screen
        });
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => SubmitProcessPage(
              processData: process,
              erpUrlBase: erpUrlBase!,
              compId: compId.toString(),
              userId: userId?.toString() ?? '',
              folderId: folderId,
            ),
          ),
        ).then((_) {
          if (searchText == '') {
            _initializeData();
          } else {
            _fetchAlfaERPProcessListWithSearch(searchText);
          }
        });

        return;
      }
      setState(() {
        _isLoading = false; // Show loading screen
      });
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => SubmitProcessPage(
            processData: process,
            erpUrlBase: erpUrlBase!,
            compId: compId.toString(),
            userId: userId?.toString() ?? '',
            folderId: folderId,
          ),
        ),
      ).then((_) {
        if (searchText == '') {
          _initializeData();
        } else {
          _fetchAlfaERPProcessListWithSearch(searchText);
        }
      });
    } catch (e) {
      print("[EXCEPTION] Error in _navigateToSubmitProcess: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${loc.anerroroccured}: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentLocale = Provider.of<LocaleProvider>(context).locale;
    final loc = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        leading: IconButton(
          icon: Icon(Icons.logout, color: Colors.blue),
          onPressed: () async {
            print('DEBUG: Logging out with args: $args');
            await AppState.clearCredentials();
            Navigator.pushNamedAndRemoveUntil(
              context,
              '/user',
              (route) => false,
              arguments: {
                'compName': args?['compName'],
                'compId': args?['compId'],
              },
            );
          },
        ),
        title: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(loc.process),
          ],
        ),
        actions: [
          Row(
            children: [
              IconButton(
                icon: Icon(Icons.settings, color: Colors.blue),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => SettingsPage()),
                  ).then((_) {
                    setState(() {
                      searchText = '';
                      _searchController.text = '';
                    });
                    _initializeData();
                  });
                },
              ),
              SizedBox(width: 20),
              IconButton(
                icon: Icon(Icons.refresh, color: Colors.blue),
                onPressed: () {
                  _initializeData();
                  setState(() {
                    _searchController.clear();
                    searchText = '';
                  });
                },
              ),
              SizedBox(width: 20),
              IconButton(
                onPressed: () {
                  print('DEBUG: Navigating to filter page with response');
                  print(alfaERPProcessResponse);
                  print('DEBUG: UserType: $userType');
                  Navigator.pushNamed(context, '/filter', arguments: {
                    'alfaERPProcessResponse': alfaERPProcessResponse,
                    'userType': userType,
                    'compId': compId,
                    'processList': processList,
                    'selectedProcessNames': selectedProcessNames,
                    'erpUrlBase': erpUrlBase,
                    'compName': args?['compName'],
                  }).then((result) {
                    if (result != null && result is List<String>) {
                      print('DEBUG: Filter result: $result');
                      setState(() {
                        selectedProcessNames = result;
                      });
                      _categorizeProcesses(
                          alfaERPProcessResponse); // Re-categorize with new filter
                    }
                  });
                },
                icon: Icon(Icons.filter_alt, color: Colors.blue),
              ),
              PopupMenuButton<String>(
                icon: Icon(Icons.language, color: Colors.blue),
                onSelected: (String value) {
                  setState(() {
                    _selectedLanguage = value;
                  });
                  print('Selected menu item: $value'); // Debug log
                  if (value == 'language_en') {
                    Provider.of<LocaleProvider>(context, listen: false)
                        .setLocale(Locale('en'));
                    print('Switched to English'); // Debug log
                  } else if (value == 'language_ja') {
                    Provider.of<LocaleProvider>(context, listen: false)
                        .setLocale(Locale('ja'));
                    print('Switched to Japanese'); // Debug log
                  }
                },
                color: Colors.white,
                itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                  PopupMenuItem<String>(
                    value: 'language_en',
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('English'),
                        if (_selectedLanguage == 'language_en')
                          Icon(Icons.check,
                              color: Colors.green), // ✅ green tick
                      ],
                    ),
                  ),
                  PopupMenuItem<String>(
                    value: 'language_ja',
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text("日本語"),
                        if (_selectedLanguage == 'language_ja')
                          Icon(Icons.check,
                              color: Colors.green), // ✅ green tick
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          Column(
            children: [
              Padding(
                padding: EdgeInsets.all(16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        decoration: InputDecoration(
                          hintText: loc.search,
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.search),
                          suffixIcon: _searchController.text.isNotEmpty
                              ? IconButton(
                                  icon: Icon(Icons.cancel, color: Colors.grey),
                                  onPressed: () {
                                    setState(() {
                                      _searchController.clear();
                                      searchText = '';
                                    });
                                    _initializeData();
                                  },
                                )
                              : null,
                        ),
                        onChanged: (value) {
                          setState(() {
                            searchText = value;
                          });
                        },
                        onSubmitted: (value) {
                          if (value.isNotEmpty) {
                            _fetchAlfaERPProcessListWithSearch(value);
                          }
                        },
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.search),
                      onPressed: () {
                        if (searchText.isNotEmpty) {
                          _fetchAlfaERPProcessListWithSearch(searchText);
                        }
                      },
                    ),
                    IconButton(
                      icon: Icon(Icons.qr_code_scanner),
                      onPressed: _scanBarcode,
                    ),
                  ],
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      SizedBox(height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          TextButton(
                            onPressed: () {},
                            child: Text(loc.previous,
                                style: TextStyle(color: Colors.black)),
                          ),
                          Spacer(),
                          IconButton(
                            // Dynamic icon: + if collapsed, - if expanded
                            icon: Icon(
                              _showPreviousBox ? Icons.remove : Icons.add,
                              color: Colors.blue,
                            ),
                            onPressed: () {
                              setState(() {
                                _showPreviousBox = !_showPreviousBox;
                                _showTodayBox = false;
                                _showNextBox = false;
                              });
                            },
                          ),
                        ],
                      ),
                      Visibility(
                        visible: _showPreviousBox,
                        child: SizedBox(
                          height: MediaQuery.of(context).size.width > 600
                              ? 800
                              : 450,
                          child: Padding(
                            padding: EdgeInsets.only(
                                left: 20.0, top: 5.0, right: 20.0, bottom: 5.0),
                            child: ListView.builder(
                              itemCount: previousProcesses.length,
                              itemBuilder: (context, index) {
                                final process = previousProcesses[index];
                                String displayDate =
                                    process['plannedStartDate'] ??
                                        process['startDate'];
                                try {
                                  DateTime parsedDate =
                                      DateFormat('MM/dd/yy hh:mm:ss a')
                                          .parse(displayDate);
                                  displayDate =
                                      DateFormat('MM/dd').format(parsedDate);
                                } catch (e) {
                                  print(
                                      'Error parsing date for display: $displayDate, $e');
                                }
                                String displayStatus = '';
                                Color statusColor = Colors.red;

                                final statusValue = process['status'];

                                if (erpUrlBase ==
                                    "https://www.alfadock-pack.com") {
                                  switch (statusValue?.toString()) {
                                    case '0':
                                      displayStatus = loc.delay;
                                      statusColor = Colors.red;
                                      break;
                                    case '1':
                                      displayStatus = loc.started;
                                      statusColor = Colors.green;
                                      break;
                                    case '2':
                                      displayStatus = loc.finished;
                                      statusColor = Colors.grey;
                                      break;
                                    case '3':
                                      displayStatus = loc.hold;
                                      statusColor = Colors.orange;
                                      break;
                                    default:
                                      displayStatus =
                                          statusValue?.toString() ?? '';
                                  }
                                } else {
                                  switch ((statusValue?.toString() ?? '')
                                      .toLowerCase()) {
                                    case 'pause':
                                      displayStatus = loc.hold;
                                      statusColor = Colors.orange;
                                      break;
                                    case 'pending':
                                      displayStatus = loc.delay;
                                      statusColor = Colors.red;
                                      break;
                                    case 'resume':
                                      displayStatus = loc.started;
                                      statusColor = Colors.green;
                                      break;
                                    case 'ready':
                                      displayStatus = loc.delay;
                                      statusColor = Colors.red;
                                      break;
                                    case 'done':
                                      displayStatus = loc.finished;
                                      statusColor = Colors.grey;
                                      break;
                                    case 'progress':
                                      displayStatus = loc.started;
                                      statusColor = Colors.green;
                                      break;
                                    default:
                                      displayStatus =
                                          statusValue?.toString() ?? '';
                                  }
                                }

                                return InkWell(
                                  onTap: () => _navigateToSubmitProcess(
                                      context, process),
                                  borderRadius: BorderRadius.circular(8.0),
                                  splashColor: Colors.blue.withOpacity(0.3),
                                  highlightColor: Colors.blue.withOpacity(0.1),
                                  child: Container(
                                    margin: EdgeInsets.symmetric(vertical: 2.0),
                                    height: 110,
                                    child: Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        SizedBox(
                                          width: 90,
                                          child: Column(
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            children: [
                                              Container(
                                                height: 80,
                                                color: statusColor,
                                                child: Center(
                                                  child: Text(
                                                    displayStatus,
                                                    style: TextStyle(
                                                      color: Colors.white,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                    ),
                                                    maxLines: 1,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                  ),
                                                ),
                                              ),
                                              Container(
                                                width: 90,
                                                color: Colors.white,
                                                child: Text(
                                                  displayDate,
                                                  textAlign: TextAlign.center,
                                                  style: TextStyle(
                                                    fontSize: 16,
                                                    color: Colors.black,
                                                    fontWeight:
                                                        FontWeight.normal,
                                                  ),
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        Expanded(
                                          child: Container(
                                            height: 110,
                                            color: Colors.white,
                                            padding: EdgeInsets.symmetric(
                                                horizontal: 12.0,
                                                vertical: 9.0),
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              mainAxisAlignment:
                                                  MainAxisAlignment
                                                      .spaceBetween,
                                              children: [
                                                Row(
                                                  mainAxisAlignment:
                                                      MainAxisAlignment
                                                          .spaceBetween,
                                                  children: [
                                                    Text(
                                                      process['name'] ?? '',
                                                      style: TextStyle(
                                                        fontSize: 15,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                      ),
                                                      maxLines: 1,
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                    ),
                                                    Container(
                                                      padding:
                                                          EdgeInsets.symmetric(
                                                              horizontal: 8.0,
                                                              vertical: 2.0),
                                                      decoration: BoxDecoration(
                                                        color:
                                                            Colors.yellow[200],
                                                        borderRadius:
                                                            BorderRadius
                                                                .circular(4.0),
                                                      ),
                                                      child: Text(
                                                        '${process['quantity'] ?? '25'}',
                                                        style: TextStyle(
                                                          fontSize: 14,
                                                          fontWeight:
                                                              FontWeight.bold,
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                                Text(
                                                  '${process['poNumber'] ?? ''}',
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    color: Colors.grey[600],
                                                  ),
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                                Text(
                                                  '${process['productNumber'] ?? ''}',
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    color: Colors.grey[600],
                                                  ),
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                                SizedBox(height: 8),
                                                Text(
                                                  '${process['machineName'] ?? ''}',
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    color: Colors.grey[600],
                                                  ),
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                        Container(
                                          width: 30,
                                          height: 110,
                                          color: Colors.white,
                                          child: Icon(
                                            Icons.arrow_forward_ios,
                                            color: Colors.grey[400],
                                            size: 16,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                      ),
                      SizedBox(height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          TextButton(
                            onPressed: () {},
                            child: Text(loc.today,
                                style: TextStyle(color: Colors.black)),
                          ),
                          Spacer(),
                          IconButton(
                            icon: Icon(
                              _showTodayBox ? Icons.remove : Icons.add,
                              color: Colors.blue,
                            ),
                            onPressed: () {
                              setState(() {
                                _showTodayBox = !_showTodayBox;
                                _showPreviousBox = false;
                                _showNextBox = false;
                              });
                            },
                          ),
                        ],
                      ),
                      Visibility(
                        visible: _showTodayBox,
                        child: SizedBox(
                          height: MediaQuery.of(context).size.width > 600
                              ? 800
                              : 450,
                          child: Padding(
                            padding: EdgeInsets.only(
                                left: 20.0, top: 5.0, right: 20.0, bottom: 5.0),
                            child: ListView.builder(
                              itemCount: todayProcesses.length,
                              itemBuilder: (context, index) {
                                final process = todayProcesses[index];
                                String displayDate =
                                    process['plannedStartDate'] ??
                                        process['startDate'];
                                try {
                                  DateTime parsedDate =
                                      DateFormat('MM/dd/yy hh:mm:ss a')
                                          .parse(displayDate);
                                  displayDate =
                                      DateFormat('MM/dd').format(parsedDate);
                                } catch (e) {
                                  print(
                                      'Error parsing date for display: $displayDate, $e');
                                }
                                String displayStatus = '';
                                Color statusColor = Colors.red;

                                final statusValue = process['status'];

                                if (erpUrlBase ==
                                    "https://www.alfadock-pack.com") {
                                  switch (statusValue?.toString()) {
                                    case '0':
                                      displayStatus = loc.waiting;
                                      statusColor = Colors.blue;
                                      break;
                                    case '1':
                                      displayStatus = loc.started;
                                      statusColor = Colors.green;
                                      break;
                                    case '2':
                                      displayStatus = loc.finished;
                                      statusColor = Colors.grey;
                                      break;
                                    case '3':
                                      displayStatus = loc.hold;
                                      statusColor = Colors.orange;
                                      break;
                                    default:
                                      displayStatus =
                                          statusValue?.toString() ?? '';
                                  }
                                } else {
                                  switch ((statusValue?.toString() ?? '')
                                      .toLowerCase()) {
                                    case 'pending':
                                      displayStatus = loc.waiting;
                                      statusColor = Colors.blue;
                                      break;
                                    case 'ready':
                                      displayStatus = loc.waiting;
                                      statusColor = Colors.blue;
                                      break;
                                    case 'done':
                                      displayStatus = loc.finished;
                                      statusColor = Colors.grey;
                                      break;
                                    case 'pause':
                                      displayStatus = loc.hold;
                                      statusColor = Colors.orange;
                                      break;
                                    case 'progress':
                                      displayStatus = loc.started;
                                      statusColor = Colors.green;
                                      break;
                                    case 'resume':
                                      displayStatus = loc.started;
                                      statusColor = Colors.green;
                                      break;
                                    default:
                                      displayStatus =
                                          statusValue?.toString() ?? '';
                                  }
                                }

                                return InkWell(
                                  onTap: () => _navigateToSubmitProcess(
                                      context, process),
                                  borderRadius: BorderRadius.circular(8.0),
                                  splashColor: Colors.blue.withOpacity(0.3),
                                  highlightColor: Colors.blue.withOpacity(0.1),
                                  child: Container(
                                    margin: EdgeInsets.symmetric(vertical: 2.0),
                                    height: 110,
                                    child: Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        SizedBox(
                                          width: 90,
                                          child: Column(
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            children: [
                                              Container(
                                                height: 80,
                                                color: statusColor,
                                                child: Center(
                                                  child: Text(
                                                    displayStatus,
                                                    style: TextStyle(
                                                      color: Colors.white,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                    ),
                                                    maxLines: 1,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                  ),
                                                ),
                                              ),
                                              Container(
                                                width: 90,
                                                color: Colors.white,
                                                child: Text(
                                                  displayDate,
                                                  textAlign: TextAlign.center,
                                                  style: TextStyle(
                                                    fontSize: 16,
                                                    color: Colors.black,
                                                    fontWeight:
                                                        FontWeight.normal,
                                                  ),
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        Expanded(
                                          child: Container(
                                            height: 110,
                                            color: Colors.white,
                                            padding: EdgeInsets.symmetric(
                                                horizontal: 12.0,
                                                vertical: 4.0),
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              mainAxisAlignment:
                                                  MainAxisAlignment
                                                      .spaceBetween,
                                              children: [
                                                Row(
                                                  mainAxisAlignment:
                                                      MainAxisAlignment
                                                          .spaceBetween,
                                                  children: [
                                                    Text(
                                                      process['name'] ?? '',
                                                      style: TextStyle(
                                                        fontSize: 20,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                      ),
                                                      maxLines: 1,
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                    ),
                                                    Container(
                                                      padding:
                                                          EdgeInsets.symmetric(
                                                              horizontal: 14.0,
                                                              vertical: 2.0),
                                                      decoration: BoxDecoration(
                                                        color:
                                                            Colors.yellow[200],
                                                        borderRadius:
                                                            BorderRadius
                                                                .circular(4.0),
                                                      ),
                                                      child: Text(
                                                        '${process['quantity'] ?? '25'}',
                                                        style: TextStyle(
                                                          fontSize: 14,
                                                          fontWeight:
                                                              FontWeight.bold,
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                                Text(
                                                  '${process['poNumber'] ?? ''}',
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    color: Colors.grey[600],
                                                  ),
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                                Text(
                                                  '${process['productNumber'] ?? ''}',
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    color: Colors.grey[600],
                                                  ),
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                                SizedBox(height: 8),
                                                Text(
                                                  '${process['machineName'] ?? ''}',
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    color: Colors.grey[600],
                                                  ),
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                        Container(
                                          width: 30,
                                          height: 110,
                                          color: Colors.white,
                                          child: Icon(
                                            Icons.arrow_forward_ios,
                                            color: Colors.grey[400],
                                            size: 16,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                      ),
                      SizedBox(height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          TextButton(
                            onPressed: () {},
                            child: Text(loc.next,
                                style: TextStyle(color: Colors.black)),
                          ),
                          Spacer(),
                          IconButton(
                            icon: Icon(
                              _showNextBox ? Icons.remove : Icons.add,
                              color: Colors.blue,
                            ),
                            onPressed: () {
                              setState(() {
                                _showNextBox = !_showNextBox;
                                _showPreviousBox = false;
                                _showTodayBox = false;
                              });
                            },
                          ),
                        ],
                      ),
                      Visibility(
                        visible: _showNextBox,
                        child: SizedBox(
                          height: MediaQuery.of(context).size.width > 600
                              ? 800
                              : 450,
                          child: Padding(
                            padding: EdgeInsets.only(
                                left: 20.0, top: 5.0, right: 20.0, bottom: 5.0),
                            child: ListView.builder(
                              itemCount: nextProcesses.length,
                              itemBuilder: (context, index) {
                                final process = nextProcesses[index];
                                String displayDate =
                                    process['plannedStartDate'] ??
                                        process['startDate'];
                                try {
                                  DateTime parsedDate =
                                      DateFormat('MM/dd/yy hh:mm:ss a')
                                          .parse(displayDate);
                                  displayDate =
                                      DateFormat('MM/dd').format(parsedDate);
                                } catch (e) {
                                  print(
                                      'Error parsing date for display: $displayDate, $e');
                                }
                                String displayStatus = '';
                                Color statusColor = Colors.red;

                                final statusValue = process['status'];

                                if (erpUrlBase ==
                                    "https://www.alfadock-pack.com") {
                                  switch (statusValue?.toString()) {
                                    case '0':
                                      displayStatus = loc.waiting;
                                      statusColor = Colors.blue;
                                      break;
                                    case '1':
                                      displayStatus = loc.started;
                                      statusColor = Colors.green;
                                      break;
                                    case '2':
                                      displayStatus = loc.finished;
                                      statusColor = Colors.grey;
                                      break;
                                    case '3':
                                      displayStatus = loc.hold;
                                      statusColor = Colors.orange;
                                      break;
                                    default:
                                      displayStatus =
                                          statusValue?.toString() ?? '';
                                  }
                                } else {
                                  switch ((statusValue?.toString() ?? '')
                                      .toLowerCase()) {
                                    case 'pending':
                                      displayStatus = loc.waiting;
                                      statusColor = Colors.blue;
                                      break;
                                    case 'ready':
                                      displayStatus = loc.waiting;
                                      statusColor = Colors.blue;
                                      break;
                                    case 'done':
                                      displayStatus = loc.finished;
                                      statusColor = Colors.grey;
                                      break;
                                    case 'pause':
                                      displayStatus = loc.hold;
                                      statusColor = Colors.orange;
                                      break;
                                    case 'progress':
                                      displayStatus = loc.started;
                                      statusColor = Colors.green;
                                      break;
                                    case 'resume':
                                      displayStatus = loc.started;
                                      statusColor = Colors.green;
                                      break;
                                    default:
                                      displayStatus =
                                          statusValue?.toString() ?? '';
                                  }
                                }

                                return InkWell(
                                  onTap: () => _navigateToSubmitProcess(
                                      context, process),
                                  borderRadius: BorderRadius.circular(8.0),
                                  splashColor: Colors.blue.withOpacity(0.3),
                                  highlightColor: Colors.blue.withOpacity(0.1),
                                  child: Container(
                                    margin: EdgeInsets.symmetric(vertical: 2.0),
                                    height: 110,
                                    child: Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        SizedBox(
                                          width: 90,
                                          child: Column(
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            children: [
                                              Container(
                                                height: 80,
                                                color: statusColor,
                                                child: Center(
                                                  child: Text(
                                                    displayStatus,
                                                    style: TextStyle(
                                                      color: Colors.white,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                    ),
                                                    maxLines: 1,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                  ),
                                                ),
                                              ),
                                              Container(
                                                width: 90,
                                                color: Colors.white,
                                                child: Text(
                                                  displayDate,
                                                  textAlign: TextAlign.center,
                                                  style: TextStyle(
                                                    fontSize: 16,
                                                    color: Colors.black,
                                                    fontWeight:
                                                        FontWeight.normal,
                                                  ),
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        Expanded(
                                          child: Container(
                                            height: 110,
                                            color: Colors.white,
                                            padding: EdgeInsets.symmetric(
                                                horizontal: 12.0,
                                                vertical: 4.0),
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              mainAxisAlignment:
                                                  MainAxisAlignment
                                                      .spaceBetween,
                                              children: [
                                                Row(
                                                  mainAxisAlignment:
                                                      MainAxisAlignment
                                                          .spaceBetween,
                                                  children: [
                                                    Text(
                                                      process['name'] ?? '',
                                                      style: TextStyle(
                                                        fontSize: 20,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                      ),
                                                      maxLines: 1,
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                    ),
                                                    Container(
                                                      padding:
                                                          EdgeInsets.symmetric(
                                                              horizontal: 8.0,
                                                              vertical: 2.0),
                                                      decoration: BoxDecoration(
                                                        color:
                                                            Colors.yellow[200],
                                                        borderRadius:
                                                            BorderRadius
                                                                .circular(4.0),
                                                      ),
                                                      child: Text(
                                                        '${process['quantity'] ?? '25'}',
                                                        style: TextStyle(
                                                          fontSize: 14,
                                                          fontWeight:
                                                              FontWeight.bold,
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                                Text(
                                                  '${process['poNumber'] ?? ''}',
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    color: Colors.grey[600],
                                                  ),
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                                Text(
                                                  '${process['productNumber'] ?? ''}',
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    color: Colors.grey[600],
                                                  ),
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                                SizedBox(height: 8),
                                                Text(
                                                  '${process['machineName'] ?? ''}',
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    color: Colors.grey[600],
                                                  ),
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                        Container(
                                          width: 30,
                                          height: 110,
                                          color: Colors.white,
                                          child: Icon(
                                            Icons.arrow_forward_ios,
                                            color: Colors.grey[400],
                                            size: 16,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          if (_isLoading)
            Container(
              color: Colors.black54,
              child: Center(
                child: CircularProgressIndicator(
                  color: Colors.white,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

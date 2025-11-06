import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:barcode_scan2/barcode_scan2.dart';
import 'package:intl/intl.dart';
import '../api.dart';
import '../setting.dart';
import '../submit_process.dart';
import 'package:http/http.dart' as http;

import '../app_state.dart';

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

  @override
  void initState() {
    super.initState();
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
      print('DEBUG: MainPage didChangeDependencies - userId: $userId, '
          'compId: $compId, userType: $userType');
      if (userId != null && compId != null && userType != null) {
        _initializeData();
      }
    }
  }

  Future<void> _initializeData() async {
    final savedCompleteProcess =
        await AppState.getCompleteProcess(); // Load complete process setting
    setState(() {
      completeprocess = savedCompleteProcess ?? 0; // Default to On
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
        print('Alfa ERP Process Listsds Response: $response');
        setState(() {
          alfaERPProcessResponse = response;
          _categorizeProcesses(response);
        });
      } catch (e) {
        print('Error fetching Alfa ERP process listsdsd: $e');
      } finally {
        setState(() {
          _isLoading = false; // Hide loading screen
        });
      }
    }
  }

  Future<void> _fetchAlfaERPProcessListWithSearch(String searchText) async {
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
        SnackBar(content: Text('Error fetching processes: $e')),
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
        DateTime.now().toUtc().add(const Duration(hours: 5, minutes: 30));

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
            return parsedDate
                .isBefore(DateTime(today.year, today.month, today.day));
          })
          .cast<Map<String, dynamic>>()
          .toList();

      todayProcesses = filteredProcesses
          .where((process) {
            final dateString = process[dateKey]?.toString();
            if (dateString == null || dateString.isEmpty) return false;
            final parsedDate = _parseDate(dateString);
            return parsedDate.day == today.day &&
                parsedDate.month == today.month &&
                parsedDate.year == today.year;
          })
          .cast<Map<String, dynamic>>()
          .toList();

      nextProcesses = filteredProcesses
          .where((process) {
            final dateString = process[dateKey]?.toString();
            if (dateString == null || dateString.isEmpty) return false;
            final parsedDate = _parseDate(dateString);
            return parsedDate
                .isAfter(DateTime(today.year, today.month, today.day));
          })
          .cast<Map<String, dynamic>>()
          .toList();
    });
  }

  DateTime _parseDate(String dateStr) {
    try {
      return DateFormat('MM/dd/yy hh:mm:ss a').parse(dateStr);
    } catch (e) {
      print('Error parsing date $dateStr: $e');
      return DateTime.now();
    }
  }

  Future<void> _scanBarcode() async {
    try {
      ScanResult result = await BarcodeScanner.scan();
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
        SnackBar(content: Text('Error scanning barcode: $e')),
      );
    }
  }

  Future<void> _navigateToSubmitProcess(
      BuildContext context, Map<String, dynamic> process) async {
    if (compId == null || erpUrlBase == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Missing company ID or ERP URL base')),
      );
      return;
    }

    // Fetch foldername from alfaERPProcessResponse
    String? folderName;
    if (alfaERPProcessResponse != null &&
        alfaERPProcessResponse!['value'] != null) {
      final processes = alfaERPProcessResponse!['value'] as List<dynamic>;
      final matchingProcess = processes.firstWhere(
        (p) => p['id'] == process['id'],
        orElse: () => {'productNumber': ''},
      );
      folderName = matchingProcess['productNumber']?.toString() ?? '';
    }

    if (folderName == null || folderName.isEmpty) {
      print(
          'Error: Could not retrieve foldername for process ID ${process['id']}');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to retrieve folder name')),
      );
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => SubmitProcessPage(
            processData: process,
            erpUrlBase: erpUrlBase!,
            compId: compId.toString(),
            userId: userId?.toString() ?? '',
          ),
        ),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SubmitProcessPage(
          processData: process,
          erpUrlBase: erpUrlBase!,
          compId: compId.toString(),
          userId: userId?.toString() ?? '',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
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
            Text('Process'),
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
                  ).then((_) =>
                      _initializeData()); // Refresh data after settings change
                },
              ),
              SizedBox(width: 20),
              IconButton(
                icon: Icon(Icons.refresh, color: Colors.blue),
                onPressed: () {
                  _initializeData();
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
              )
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
                          hintText: 'Search',
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
                            child: Text('Previous',
                                style: TextStyle(color: Colors.black)),
                          ),
                          Spacer(),
                          IconButton(
                            icon: Icon(Icons.add, color: Colors.blue),
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
                          height: 400,
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
                                      displayStatus = 'Delay';
                                      statusColor = Colors.red;
                                      break;
                                    case '1':
                                      displayStatus = 'Waiting';
                                      statusColor = Colors.blue;
                                      break;
                                    case '2':
                                      displayStatus = 'Finished';
                                      statusColor = Colors.grey;
                                      break;
                                    default:
                                      displayStatus =
                                          statusValue?.toString() ?? '';
                                  }
                                } else {
                                  switch ((statusValue?.toString() ?? '')
                                      .toLowerCase()) {
                                    case 'pending':
                                      displayStatus = 'Delay';
                                      statusColor = Colors.red;
                                      break;
                                    case 'ready':
                                      displayStatus = 'Waiting';
                                      statusColor = Colors.blue;
                                      break;
                                    case 'done':
                                      displayStatus = 'Finished';
                                      statusColor = Colors.grey;
                                      break;
                                    default:
                                      displayStatus =
                                          statusValue?.toString() ?? '';
                                  }
                                }

                                return GestureDetector(
                                  onTap: () => _navigateToSubmitProcess(
                                      context, process),
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
                            child: Text('Today',
                                style: TextStyle(color: Colors.black)),
                          ),
                          Spacer(),
                          IconButton(
                            icon: Icon(Icons.add, color: Colors.blue),
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
                          height: 400,
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
                                      displayStatus = 'Delay';
                                      statusColor = Colors.red;
                                      break;
                                    case '1':
                                      displayStatus = 'Waiting';
                                      statusColor = Colors.blue;
                                      break;
                                    case '2':
                                      displayStatus = 'Finished';
                                      statusColor = Colors.grey;
                                      break;
                                    default:
                                      displayStatus =
                                          statusValue?.toString() ?? '';
                                  }
                                } else {
                                  switch ((statusValue?.toString() ?? '')
                                      .toLowerCase()) {
                                    case 'pending':
                                      displayStatus = 'Delay';
                                      statusColor = Colors.red;
                                      break;
                                    case 'ready':
                                      displayStatus = 'Waiting';
                                      statusColor = Colors.blue;
                                      break;
                                    case 'done':
                                      displayStatus = 'Finished';
                                      statusColor = Colors.grey;
                                      break;
                                    default:
                                      displayStatus =
                                          statusValue?.toString() ?? '';
                                  }
                                }

                                return GestureDetector(
                                  onTap: () => _navigateToSubmitProcess(
                                      context, process),
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
                            child: Text('Next',
                                style: TextStyle(color: Colors.black)),
                          ),
                          Spacer(),
                          IconButton(
                            icon: Icon(Icons.add, color: Colors.blue),
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
                          height: 400,
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
                                      displayStatus = 'Delay';
                                      statusColor = Colors.red;
                                      break;
                                    case '1':
                                      displayStatus = 'Waiting';
                                      statusColor = Colors.blue;
                                      break;
                                    case '2':
                                      displayStatus = 'Finished';
                                      statusColor = Colors.grey;
                                      break;
                                    default:
                                      displayStatus =
                                          statusValue?.toString() ?? '';
                                  }
                                } else {
                                  switch ((statusValue?.toString() ?? '')
                                      .toLowerCase()) {
                                    case 'pending':
                                      displayStatus = 'Delay';
                                      statusColor = Colors.red;
                                      break;
                                    case 'ready':
                                      displayStatus = 'Waiting';
                                      statusColor = Colors.blue;
                                      break;
                                    case 'done':
                                      displayStatus = 'Finished';
                                      statusColor = Colors.grey;
                                      break;
                                    default:
                                      displayStatus =
                                          statusValue?.toString() ?? '';
                                  }
                                }

                                return GestureDetector(
                                  onTap: () => _navigateToSubmitProcess(
                                      context, process),
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

import 'package:flutter/material.dart';
import 'api.dart';
import 'app_state.dart';
import 'l10n/app_localizations.dart';
import 'main_page.dart';

class FilterPage extends StatefulWidget {
  final Map<String, dynamic>? alfaERPProcessResponse;
  final String? userType;
  final List<Map<String, dynamic>> processList;

  const FilterPage({
    super.key,
    this.alfaERPProcessResponse,
    this.userType,
    required this.processList,
  });

  @override
  _FilterPageState createState() => _FilterPageState();
}

class _FilterPageState extends State<FilterPage> {
  bool _isLoading = true;
  List<dynamic>? _filterData;
  Map<String, dynamic>? args;
  String? compname;
  String? userTypeLocal;
  int? compIdLocal;
  final Map<String, bool> _groupSelection = {};
  final Map<String, Map<String, bool>> _childSelection = {};
  List<Map<String, dynamic>> processList = [];
  List<String> selectedProcessNames = [];
  String? erpUrlBase;
  bool _selectAll = false; // State for Select All checkbox

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    // Extract arguments from ModalRoute
    if (args == null) {
      final routeArgs = ModalRoute.of(context)?.settings.arguments;
      if (routeArgs != null && routeArgs is Map<String, dynamic>) {
        args = routeArgs;
        userTypeLocal = args!['userType'];
        compIdLocal = args!['compId'] as int?;
        processList = args!['processList'] ?? [];
        selectedProcessNames = args!['selectedProcessNames'] ?? [];
        erpUrlBase = args!['erpUrlBase'] ?? '';
        compname = args!['compName'] ?? '';
        print('erpUrlBase: $erpUrlBase');
        print('selectedProcessNames: $selectedProcessNames');
        print('UserType: $userTypeLocal');
        print('DEBUG: FilterPage received arguments: $args');
        print('ProcessList: $processList');
      }
      _fetchFilterContent();
    }
  }

  Future<void> _fetchFilterContent() async {
    print('processList: $processList');
    print('DEBUG: Fetching filter content for compId: $compIdLocal');
    print('selectedProcessNames: $selectedProcessNames');
    // print('DEBUG: isFilterPageFirstLoad: ${AppState.isFilterPageFirstLoad}');
    if (compIdLocal == null) {
      setState(() {
        _isLoading = false;
      });
      return;
    }

    try {
      final response = await getfiltercontent(compIdLocal!.toString());
      setState(() {
        if (erpUrlBase != "https://www.alfadock-pack.com") {
          print('erpUrlBase inside fetch if: $filteringdata');
          _filterData = filteringdata;
        } else {
          _filterData = response as List<dynamic>? ?? [];
        }

        _isLoading = false;
        print('DEBUG: Fetched filter data: $_filterData');
        print('erpUrlBase inside fetch: $filteringdata');
        // Initialize child selections based on erpUrlBase
        _childSelection.clear();
        _groupSelection.clear();
        if (erpUrlBase == "https://www.alfadock-pack.com") {
          _initializeSelectionsForAlfaDock();
        } else {
          _initializeSelectionsForOther();
        }
        _updateSelectAllState(); // Initialize Select All state
        AppState.setFilterPageFirstLoad(false); // Mark first load as complete
      });
      print('DEBUG: Filter data fetched successfully: $_filterData');
      print('DEBUG: _childSelection: $_childSelection');
      print('DEBUG: _groupSelection: $_groupSelection');
      print('DEBUG: _selectAll: $_selectAll');
    } catch (e) {
      print('Error fetching filter content: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _initializeSelectionsForAlfaDock() {
    if (_filterData != null) {
      for (var process in _filterData!) {
        if (process is Map<String, dynamic>) {
          final processtypename = process['processtypename'] as String?;
          final name = process['name'] as String? ?? 'Unnamed';
          if (processtypename != null) {
            _childSelection[processtypename] =
                _childSelection[processtypename] ?? {};
            _groupSelection[processtypename] =
                _groupSelection[processtypename] ?? false;

            bool initialValue = false;
            if (AppState.isFilterPageFirstLoad && userTypeLocal == 'Admin') {
              print(
                  'DEBUG: Admin user, first load for AlfaDock, checking: $name');
              initialValue = true;
            } else if (!AppState.isFilterPageFirstLoad) {
              // print(
              //     'DEBUG: Subsequent load for AlfaDock, using selectedProcessNames for: $name');
              initialValue = selectedProcessNames.contains(name);
            } else {
              print(
                  'DEBUG: Non-Admin, first load for AlfaDock, using processList for: $name');
              initialValue = processList.any((item) => item['name'] == name);
            }
            _childSelection[processtypename]![name] = initialValue;
            // print(
            //     'DEBUG: Initialized $name in $processtypename with value: $initialValue');
          }
        }
      }
      // Update parent checkboxes based on child states
      _groupSelection.forEach((processtypename, _) {
        _updateParentCheckbox(processtypename);
      });
    }
  }

  void _initializeSelectionsForOther() {
    print('erpUrlBase inside init: $_filterData');
    if (_filterData != null) {
      for (var process in _filterData!) {
        if (process is Map<String, dynamic>) {
          final name = process['name'] as String? ?? 'Unnamed';
          final groupKey = 'Default';

          _childSelection[groupKey] = _childSelection[groupKey] ?? {};

          bool initialValue = false;
          if (AppState.isFilterPageFirstLoad && userTypeLocal == 'Admin') {
            print('DEBUG: Admin user, first load for Other, checking: $name');
            initialValue = true;
          } else if (!AppState.isFilterPageFirstLoad) {
            // print(
            //     'DEBUG: Subsequent load for Other, using selectedProcessNames for: $name');
            initialValue = selectedProcessNames.contains(name);
          } else {
            print(
                'DEBUG: Non-Admin, first load for Other, using processList for: $name');
            initialValue = processList.any((item) => item['name'] == name);
          }
          _childSelection[groupKey]![name] = initialValue;
          // print(
          //     'DEBUG: Initialized $name in $groupKey with value: $initialValue');
        }
      }
      // Update Select All state after initialization
      _updateSelectAllState();
    }
  }

  void _updateParentCheckbox(String processtypename) {
    final children = _childSelection[processtypename] ?? {};
    final allChecked =
        children.isNotEmpty && children.values.every((checked) => checked);
    setState(() {
      _groupSelection[processtypename] = allChecked;
      _updateSelectAllState(); // Update Select All when parent changes
    });
  }

  void _updateSelectAllState() {
    // Check if all child checkboxes across all groups are selected
    bool allSelected = _childSelection.isNotEmpty &&
        _childSelection.values.every((children) =>
            children.isNotEmpty && children.values.every((checked) => checked));
    setState(() {
      _selectAll = allSelected;
    });
    print('DEBUG: Updated _selectAll: $_selectAll');
  }

  void _toggleSelectAll(bool? value) {
    setState(() {
      _selectAll = value ?? false;
      _childSelection.forEach((group, children) {
        children.forEach((name, _) {
          children[name] = _selectAll;
        });
      });
      _groupSelection.forEach((group, _) {
        _groupSelection[group] = _selectAll;
      });
    });
    print('DEBUG: Select All toggled to: $_selectAll');
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final groupedData = <String, List<Map<String, dynamic>>>{};
    if (_filterData != null) {
      for (var process in _filterData!) {
        if (process is Map<String, dynamic>) {
          final processtypename =
              process['processtypename'] as String? ?? 'Default';
          groupedData.putIfAbsent(processtypename, () => []).add(process);
        }
      }
    }
    print('DEBUG: FilterPage received arguments: $args');
    print('UserType: $userTypeLocal');
    print('filterData: $_filterData');

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        title: Text('${loc.filter} (${compname})',
            style: const TextStyle(color: Colors.black)),
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: () {
            // Collect only checked child names
            List<String> selectedNames = [];
            _childSelection.forEach((_, children) {
              children.forEach((name, isChecked) {
                if (isChecked) {
                  selectedNames.add(name);
                }
              });
            });
            print('DEBUG: Returning selectedNames: $selectedNames');
            Navigator.pop(context, selectedNames);
          },
        ),
      ),
      body: Stack(
        children: [
          _isLoading || _filterData == null || _filterData!.isEmpty
              ? const SizedBox.shrink() // Hide content when loading or no data
              : Column(
                  children: [
                    // Select All Checkbox
                    CheckboxListTile(
                      title: Text(
                        loc.selectall,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      value: _selectAll,
                      onChanged: _toggleSelectAll,
                      controlAffinity: ListTileControlAffinity.leading,
                      activeColor: Colors.blue,
                      checkColor: Colors.white,
                    ),
                    Expanded(
                      child: erpUrlBase == "https://www.alfadock-pack.com"
                          ? ListView.builder(
                              itemCount: groupedData.length,
                              itemBuilder: (context, index) {
                                final processtypename =
                                    groupedData.keys.elementAt(index);
                                final processes = groupedData[processtypename]!;

                                return ExpansionTile(
                                  title: Row(
                                    children: [
                                      Checkbox(
                                        value:
                                            _groupSelection[processtypename] ??
                                                false,
                                        onChanged: (bool? value) {
                                          setState(() {
                                            _groupSelection[processtypename] =
                                                value ?? false;
                                            for (var process in processes) {
                                              final name =
                                                  process['name'] as String? ??
                                                      'Unnamed';
                                              _childSelection[processtypename]![
                                                  name] = value ?? false;
                                            }
                                            _updateSelectAllState();
                                          });
                                          print(
                                              'Group "$processtypename" checkbox changed to $value');
                                        },
                                      ),
                                      Expanded(
                                        child: Text(
                                          processtypename,
                                          style: TextStyle(
                                              fontWeight: FontWeight.bold),
                                        ),
                                      ),
                                    ],
                                  ),
                                  children: processes.map<Widget>((process) {
                                    final name =
                                        process['name'] as String? ?? 'Unnamed';
                                    return CheckboxListTile(
                                      tileColor: Colors.white,
                                      title: Text(name),
                                      value: _childSelection[processtypename]![
                                              name] ??
                                          false,
                                      onChanged: (bool? value) {
                                        setState(() {
                                          _childSelection[processtypename]![
                                              name] = value ?? false;
                                          _updateParentCheckbox(
                                              processtypename);
                                        });
                                        print(
                                            'Checkbox for $name changed to $value');
                                      },
                                      controlAffinity:
                                          ListTileControlAffinity.leading,
                                      activeColor: Colors.blue,
                                      checkColor: Colors.white,
                                    );
                                  }).toList(),
                                );
                              },
                            )
                          : ListView.builder(
                              itemCount: _filterData!.length,
                              itemBuilder: (context, index) {
                                final process =
                                    _filterData![index] as Map<String, dynamic>;
                                final name =
                                    process['name'] as String? ?? 'Unnamed';
                                final groupKey = 'Default';
                                return CheckboxListTile(
                                  tileColor: Colors.white,
                                  title: Text(name),
                                  value:
                                      _childSelection[groupKey]?[name] ?? false,
                                  onChanged: (bool? value) {
                                    setState(() {
                                      _childSelection[groupKey] ??= {};
                                      _childSelection[groupKey]![name] =
                                          value ?? false;
                                      _updateSelectAllState();
                                    });
                                    print(
                                        'Checkbox for $name changed to $value');
                                  },
                                  controlAffinity:
                                      ListTileControlAffinity.leading,
                                  activeColor: Colors.blue,
                                  checkColor: Colors.white,
                                );
                              },
                            ),
                    ),
                  ],
                ),
          if (_isLoading)
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
}

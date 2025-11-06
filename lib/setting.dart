import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:intl/intl.dart';

import 'l10n/app_localizations.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  _SettingsPageState createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  int cancel = 1; // Initially Off (1)
  int staylogged =
      1; // Initially Off (1) - FIXED: Changed from 1 to 1 (Off by default)
  int userdisplay = 1; // Initially Staff Name (1)
  int completeinput = 0; // Initially On (0)
  int completeprocess = 0; // Initially On (0)
  int previousDays = 1;
  int nextDays = 1;
  String? previousDaysTimestamp;
  String? nextDaysTimestamp;
  final FlutterSecureStorage _storage = FlutterSecureStorage();

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final savedCancel = int.tryParse(
        await _storage.read(key: 'cancelFunction') ??
            '1'); // Default to 1 (Off)
    final savedStayLogged = int.tryParse(
        await _storage.read(key: 'stayLogged') ??
            '1'); // FIXED: Default to 1 (Off)
    final savedUserDisplay = int.tryParse(
        await _storage.read(key: 'userDisplay') ??
            '1'); // Default to 1 (Staff Name)
    final savedCompleteInput = int.tryParse(
        await _storage.read(key: 'completeInput') ?? '0'); // Default to 0 (On)
    final savedCompleteProcess = int.tryParse(
        await _storage.read(key: 'completeProcess') ??
            '0'); // Default to 0 (On)
    final savedPreviousDays =
        int.tryParse(await _storage.read(key: 'previousDays') ?? '1');
    final savedNextDays =
        int.tryParse(await _storage.read(key: 'nextDays') ?? '1');
    final savedPreviousDaysTimestamp =
        await _storage.read(key: 'previousDaysTimestamp');
    final savedNextDaysTimestamp =
        await _storage.read(key: 'nextDaysTimestamp');

    setState(() {
      cancel = savedCancel ?? 1;
      staylogged = savedStayLogged ?? 1; // FIXED: Default to 1 (Off)
      userdisplay = savedUserDisplay ?? 1;
      completeinput = savedCompleteInput ?? 0;
      completeprocess = savedCompleteProcess ?? 0;
      previousDays = savedPreviousDays ?? 1;
      nextDays = savedNextDays ?? 1;
      previousDaysTimestamp = savedPreviousDaysTimestamp;
      nextDaysTimestamp = savedNextDaysTimestamp;
    });
  }

  void _showDaysBottomSheet(String type) {
    final options = [1, 2, 3, 7, 10];
    final loc = AppLocalizations.of(context);

    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return Container(
          padding: EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                "${loc.selectdays}",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 16),
              ...options.map((days) => ListTile(
                    title: Text("$days ${loc.days}"),
                    trailing: (type == "previous" && previousDays == days) ||
                            (type == "next" && nextDays == days)
                        ? Icon(Icons.check, color: Colors.green)
                        : null,
                    onTap: () async {
                      final now = DateTime.now();
                      final timestamp = DateFormat('yyyy-MM-dd HH:mm:ss.SSSSSS')
                          .format(type == "previous"
                              ? now.subtract(Duration(days: days))
                              : now.add(Duration(days: days)));

                      setState(() {
                        if (type == "previous") {
                          previousDays = days;
                          previousDaysTimestamp = timestamp;
                          print('previous time stamp $previousDaysTimestamp');
                        } else {
                          nextDays = days;
                          nextDaysTimestamp = timestamp;
                          print('next time stamp $nextDaysTimestamp');
                        }
                      });

                      await _storage.write(
                        key: type == "previous" ? 'previousDays' : 'nextDays',
                        value: days.toString(),
                      );
                      await _storage.write(
                        key: type == "previous"
                            ? 'previousDaysTimestamp'
                            : 'nextDaysTimestamp',
                        value: timestamp,
                      );

                      Navigator.pop(context);
                    },
                  )),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        title: Text(loc.settings),
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.blue),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
      ),
      backgroundColor: Colors.white,
      body: Padding(
        padding: EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(height: 40),

            /// Cancel Function
            Row(
              children: [
                SizedBox(
                  width: 160,
                  child: Text(
                    loc.cancelFunction,
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
                Radio<int>(
                  value: 0,
                  groupValue: cancel,
                  onChanged: (value) {
                    setState(() {
                      cancel = value!;
                      _storage.write(
                          key: 'cancelFunction', value: value.toString());
                    });
                  },
                ),
                Text(loc.on),
                SizedBox(width: 20),
                Radio<int>(
                  value: 1,
                  groupValue: cancel,
                  onChanged: (value) {
                    setState(() {
                      cancel = value!;
                      _storage.write(
                          key: 'cancelFunction', value: value.toString());
                    });
                  },
                ),
                Text(loc.off),
              ],
            ),
            SizedBox(height: 10),

            /// Stay Logged In
            Row(
              children: [
                SizedBox(
                  width: 160,
                  child: Text(
                    loc.stayLoggedIn,
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
                Radio<int>(
                  value: 0,
                  groupValue: staylogged,
                  onChanged: (value) {
                    setState(() {
                      staylogged = value!;
                      _storage.write(
                          key: 'stayLogged', value: value.toString());
                    });
                  },
                ),
                Text(loc.on),
                SizedBox(width: 20),
                Radio<int>(
                  value: 1,
                  groupValue: staylogged,
                  onChanged: (value) {
                    setState(() {
                      staylogged = value!;
                      _storage.write(
                          key: 'stayLogged', value: value.toString());
                    });
                  },
                ),
                Text(loc.off),
              ],
            ),
            SizedBox(height: 10),

            /// User Display Name
            Row(
              children: [
                SizedBox(
                  width: 160,
                  child: Text(
                    loc.userDisplayName,
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
                Radio<int>(
                  value: 0,
                  groupValue: userdisplay,
                  onChanged: (value) {
                    setState(() {
                      userdisplay = value!;
                      _storage.write(
                          key: 'userDisplay', value: value.toString());
                    });
                  },
                ),
                Text(loc.id),
                SizedBox(width: 20),
                Radio<int>(
                  value: 1,
                  groupValue: userdisplay,
                  onChanged: (value) {
                    setState(() {
                      userdisplay = value!;
                      _storage.write(
                          key: 'userDisplay', value: value.toString());
                    });
                  },
                ),
                Text(loc.staffName),
              ],
            ),
            SizedBox(height: 10),

            /// Complete Input
            Row(
              children: [
                SizedBox(
                  width: 160,
                  child: Text(
                    loc.completeInput,
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
                Radio<int>(
                  value: 0,
                  groupValue: completeinput,
                  onChanged: (value) {
                    setState(() {
                      completeinput = value!;
                      _storage.write(
                          key: 'completeInput', value: value.toString());
                    });
                  },
                ),
                Text(loc.on),
                SizedBox(width: 20),
                Radio<int>(
                  value: 1,
                  groupValue: completeinput,
                  onChanged: (value) {
                    setState(() {
                      completeinput = value!;
                      _storage.write(
                          key: 'completeInput', value: value.toString());
                    });
                  },
                ),
                Text(loc.off),
              ],
            ),
            SizedBox(height: 10),

            /// Complete Process
            Row(
              children: [
                SizedBox(
                  width: 160,
                  child: Text(
                    loc.completeProcess,
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
                Radio<int>(
                  value: 0,
                  groupValue: completeprocess,
                  onChanged: (value) {
                    setState(() {
                      completeprocess = value!;
                      _storage.write(
                          key: 'completeProcess', value: value.toString());
                    });
                  },
                ),
                Text(loc.on),
                SizedBox(width: 20),
                Radio<int>(
                  value: 1,
                  groupValue: completeprocess,
                  onChanged: (value) {
                    setState(() {
                      completeprocess = value!;
                      _storage.write(
                          key: 'completeProcess', value: value.toString());
                    });
                  },
                ),
                Text(loc.off),
              ],
            ),
            SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => _showDaysBottomSheet("previous"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.blue,
                      side: BorderSide(color: Colors.blue),
                    ),
                    child: Text("${loc.prviousprocess}: $previousDays"),
                  ),
                ),
              ],
            ),
            SizedBox(height: 10),

            /// Next Process Days Button
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => _showDaysBottomSheet("next"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.blue,
                      side: BorderSide(color: Colors.blue),
                    ),
                    child: Text("${loc.nextprocess}: $nextDays"),
                  ),
                ),
              ],
            ),
            SizedBox(height: 30),

            /// ✅ OK Button at the bottom
          ],
        ),
      ),
    );
  }
}

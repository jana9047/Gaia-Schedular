import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class AppState {
  static const String _companyUsernameKey = 'companyUsername';
  static const String _companyPasswordKey = 'companyPassword';
  static const String _userUsernameKey = 'userUsername';
  static const String _userPasswordKey = 'userPassword';
  static const String _stayLoggedKey = 'stayLogged';
  static const String _compIdKey = 'compId';
  static const String _cancelFunctionKey = 'cancelFunction';
  static const String _completeInputKey = 'completeInput';
  static const String _completeProcessKey = 'completeProcess';
  static final _storage = FlutterSecureStorage();
  static bool _isFilterPageFirstLoad = true;
  static bool get isFilterPageFirstLoad => _isFilterPageFirstLoad;
  static const String _userDisplayKey = 'userDisplay';

  // Save company credentials
  static void setFilterPageFirstLoad(bool value) {
    _isFilterPageFirstLoad = value;
  }

  static Future<void> saveUserDisplay(int value) async {
    await _storage.write(key: _userDisplayKey, value: value.toString());
  }

  static Future<int?> getUserDisplay() async {
    final value = await _storage.read(key: _userDisplayKey);
    return value != null ? int.tryParse(value) : 1; // Default to 1 (Staff Name)
  }

  static Future<void> saveCredentials(String username, String password) async {
    await _storage.write(key: _companyUsernameKey, value: username);
    await _storage.write(key: _companyPasswordKey, value: password);
    print(
        'DEBUG: Company credentials saved securely - companyUsername: $username, companyPassword: $password');
  }

  // Save user credentials
  static Future<void> saveUserCredentials(
      String username, String password) async {
    await _storage.write(key: _userUsernameKey, value: username);
    await _storage.write(key: _userPasswordKey, value: password);
    print(
        'DEBUG: User credentials saved securely - userUsername: $username, userPassword: $password');
  }

  // Save company ID
  static Future<void> saveCompanyId(int compId) async {
    await _storage.write(key: _compIdKey, value: compId.toString());
    print('DEBUG: Company ID saved securely - compId: $compId');
  }

  // Save stay logged in setting
  static Future<void> saveStayLogged(int value) async {
    await _storage.write(key: _stayLoggedKey, value: value.toString());
    print('DEBUG: Stay Logged In setting saved - value: $value');
  }

  // Save cancel function setting
  static Future<void> saveCancelFunction(int value) async {
    await _storage.write(key: _cancelFunctionKey, value: value.toString());
    print('DEBUG: Cancel Function setting saved - value: $value');
  }

  // Save complete input setting
  static Future<void> saveCompleteInput(int value) async {
    await _storage.write(key: _completeInputKey, value: value.toString());
    print('DEBUG: Complete Input setting saved - value: $value');
  }

  // Save complete process setting
  static Future<void> saveCompleteProcess(int value) async {
    await _storage.write(key: _completeProcessKey, value: value.toString());
    print('DEBUG: Complete Process setting saved - value: $value');
  }

  // Retrieve company username
  static Future<String?> getCompanyUsername() async {
    return await _storage.read(key: _companyUsernameKey);
  }

  // Retrieve company password
  static Future<String?> getCompanyPassword() async {
    return await _storage.read(key: _companyPasswordKey);
  }

  // Retrieve user username
  static Future<String?> getUserUsername() async {
    return await _storage.read(key: _userUsernameKey);
  }

  // Retrieve user password
  static Future<String?> getUserPassword() async {
    return await _storage.read(key: _userPasswordKey);
  }

  // Retrieve company ID
  static Future<int?> getCompanyId() async {
    final value = await _storage.read(key: _compIdKey);
    return value != null ? int.parse(value) : null;
  }

  // Retrieve stay logged in setting - FIXED: Default to 1 (Off)
  static Future<int?> getStayLogged() async {
    final value = await _storage.read(key: _stayLoggedKey);
    return value != null ? int.parse(value) : 1; // FIXED: Default to 1 (Off)
  }

  static Future<void> initializeSettings() async {
    // Initialize all settings with default values if they don't exist
    if (await _storage.read(key: _stayLoggedKey) == null) {
      await _storage.write(key: _stayLoggedKey, value: '1'); // Default to Off
    }
    if (await _storage.read(key: _cancelFunctionKey) == null) {
      await _storage.write(
          key: _cancelFunctionKey, value: '1'); // Default to Off
    }
    if (await _storage.read(key: _userDisplayKey) == null) {
      await _storage.write(
          key: _userDisplayKey, value: '1'); // Default to Staff Name
    }
    if (await _storage.read(key: _completeInputKey) == null) {
      await _storage.write(key: _completeInputKey, value: '0'); // Default to On
    }
    if (await _storage.read(key: _completeProcessKey) == null) {
      await _storage.write(
          key: _completeProcessKey, value: '0'); // Default to On
    }
    print('DEBUG: Settings initialized');
  }

  // Retrieve cancel function setting
  static Future<int?> getCancelFunction() async {
    final value = await _storage.read(key: _cancelFunctionKey);
    return value != null ? int.parse(value) : 1; // Default to 1 (Off)
  }

  // Retrieve complete input setting
  static Future<int?> getCompleteInput() async {
    final value = await _storage.read(key: _completeInputKey);
    return value != null ? int.parse(value) : 0; // Default to 0 (On)
  }

  // Retrieve complete process setting
  static Future<int?> getCompleteProcess() async {
    final value = await _storage.read(key: _completeProcessKey);
    return value != null ? int.parse(value) : 0; // Default to 0 (On)
  }

  // Clear all credentials
  static Future<void> clearCredentials() async {
    await _storage.delete(key: _companyUsernameKey);
    await _storage.delete(key: _companyPasswordKey);
    await _storage.delete(key: _userUsernameKey);
    await _storage.delete(key: _userPasswordKey);
    await _storage.delete(key: _compIdKey);
    await _storage.delete(key: _cancelFunctionKey);
    await _storage.delete(key: _completeInputKey);
    await _storage.delete(key: _completeProcessKey);
    print('DEBUG: All credentials cleared securely');
  }

  // Print current state for debugging
  static Future<void> printCurrentState() async {
    final companyUsername = await getCompanyUsername();
    final companyPassword = await getCompanyPassword();
    final userUsername = await getUserUsername();
    final userPassword = await getUserPassword();
    final compId = await getCompanyId();
    final stayLogged = await getStayLogged();
    final cancelFunction = await getCancelFunction();
    final completeInput = await getCompleteInput();
    final completeProcess = await getCompleteProcess();
    print(
        'DEBUG: Current AppState - companyUsername: $companyUsername, companyPassword: $companyPassword, '
        'userUsername: $userUsername, userPassword: $userPassword, compId: $compId, stayLogged: $stayLogged, '
        'cancelFunction: $cancelFunction, completeInput: $completeInput, completeProcess: $completeProcess');
  }
}

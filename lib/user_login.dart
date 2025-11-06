import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'api.dart';
import 'app_state.dart';
import 'l10n/app_localizations.dart';

class UserLoginPage extends StatefulWidget {
  const UserLoginPage({super.key});

  @override
  _UserLoginPageState createState() => _UserLoginPageState();
}

class _UserLoginPageState extends State<UserLoginPage> {
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isNavigating = false;
  final FlutterSecureStorage _storage = FlutterSecureStorage();

  void _showErrorSnackBar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: TextStyle(
              fontSize: 16.0, color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.red[700],
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: Duration(seconds: 2),
      ),
    );
  }

  bool _validateFields(
      BuildContext context, TextEditingController usernameController) {
    final loc = AppLocalizations.of(context);
    if (usernameController.text.isEmpty) {
      _showErrorSnackBar(context, loc.pleaseenterusername);
      return false;
    }
    if (_passwordController.text.isEmpty) {
      _showErrorSnackBar(context, loc.pleaseenterpassword);
      return false;
    }
    return true;
  }

  Future<void> _handleLogin(
      BuildContext context,
      TextEditingController usernameController,
      TextEditingController passwordController,
      int compId) async {
    final loc = AppLocalizations.of(context);
    if (_isNavigating) return;
    if (!_validateFields(context, usernameController)) return;

    setState(() {
      _isNavigating = true;
    });

    try {
      final response = await validateUserLogin(
        usernameController.text,
        passwordController.text,
        compId,
      );
      final userId = response['userId'];
      print('User Login response: $response');
      print('User ID: $userId');
      final userType = response['userType'];
      final usernames = response['userName'];

      print('User Type: $userType');
      await _storage.write(key: 'userUsername', value: usernameController.text);
      await _storage.write(key: 'userPassword', value: passwordController.text);

      final args =
          ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
      final compName = args?['compName'] as String? ?? 'Unknown Company';
      AppState.setFilterPageFirstLoad(true);
      Navigator.pushReplacementNamed(context, '/main', arguments: {
        'userId': userId,
        'compId': compId,
        'userType': userType,
        'compName': compName,
        'username': usernames,
      });
    } catch (e) {
      _showErrorSnackBar(context, loc.loginFailed);
    } finally {
      setState(() {
        _isNavigating = false;
      });
    }
  }

  Future<void> _autoLoginIfPossible(BuildContext context, int compId) async {
    if (_isNavigating) return;

    final stayLogged = await AppState.getStayLogged();
    print('DEBUG: Stay Logged In setting: $stayLogged (0=On, 1=Off)');

    if (stayLogged == 0) {
      final username = await _storage.read(key: 'userUsername');
      final password = await _storage.read(key: 'userPassword');

      print('DEBUG: Checking for user auto-login credentials');
      print('DEBUG: Username exists: ${username != null}');
      print('DEBUG: Password exists: ${password != null}');

      if (username != null && password != null) {
        print('DEBUG: Attempting auto-login with username: $username');
        setState(() {
          _isNavigating = true;
        });

        try {
          final response = await validateUserLogin(username, password, compId);
          print('DEBUG: Auto-login response: $response');
          final userId = response['userId'];
          final userType = response['userType'];
          final usernames = response['userName'];

          print(
              'DEBUG: Auto-login successful - User ID: $userId, User Type: $userType');

          final args = ModalRoute.of(context)?.settings.arguments
              as Map<String, dynamic>?;
          final compName = args?['compName'] as String? ?? 'Unknown Company';
          AppState.setFilterPageFirstLoad(true);
          Navigator.pushReplacementNamed(context, '/main', arguments: {
            'userId': userId,
            'compId': compId,
            'userType': userType,
            'compName': compName,
            'username': usernames,
          });
        } catch (e) {
          print('DEBUG: Auto-login failed with error: $e');
          await _storage.delete(key: 'userUsername');
          await _storage.delete(key: 'userPassword');
          print('DEBUG: Cleared user credentials after failed auto-login');

          _showErrorSnackBar(
              context, 'Auto-login failed. Please log in manually.');
        } finally {
          if (mounted) {
            setState(() {
              _isNavigating = false;
            });
          }
        }
      }
    } else {
      print('DEBUG: Stay Logged In is OFF, skipping auto-login');
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final args =
        ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    final String compName = args?['compName'] as String? ?? 'Unknown Company';
    final int? compId = args?['compId'] as int?;
    print('DEBUG: UserLoginPage build - compName: $compName, compId: $compId');

    if (compId != null && !_isNavigating) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _autoLoginIfPossible(context, compId);
      });
    }

    return Scaffold(
      body: Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              image: DecorationImage(
                image: AssetImage('assets/wave_background.png'),
                fit: BoxFit.cover,
              ),
            ),
          ),
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Image.asset(
                  'assets/logo.png',
                  height: 100,
                  width: 100,
                ),
                SizedBox(height: 10),
                Container(
                  width: 300,
                  padding: EdgeInsets.all(16.0),
                  decoration: BoxDecoration(
                    image: DecorationImage(
                      image: AssetImage('assets/metal_texture.png'),
                      fit: BoxFit.cover,
                    ),
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey[500] ?? Colors.grey,
                        offset: Offset(4.0, 4.0),
                        blurRadius: 5.0,
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        compName,
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue[900],
                        ),
                      ),
                      SizedBox(height: 16.0),
                      TextField(
                        controller: _usernameController,
                        decoration: InputDecoration(
                          labelText: loc.username,
                          border: OutlineInputBorder(),
                        ),
                        enabled: !_isNavigating,
                      ),
                      SizedBox(height: 16.0),
                      TextField(
                        controller: _passwordController,
                        decoration: InputDecoration(
                          labelText: loc.password,
                          border: OutlineInputBorder(),
                        ),
                        obscureText: true,
                        enabled: !_isNavigating,
                      ),
                      SizedBox(height: 24.0),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          ElevatedButton(
                            onPressed: _isNavigating
                                ? null
                                : () async {
                                    // Clear both user and company credentials on logout
                                    await _storage.delete(key: 'userUsername');
                                    await _storage.delete(key: 'userPassword');
                                    await _storage.delete(
                                        key: 'companyUsername');
                                    await _storage.delete(
                                        key: 'companyPassword');
                                    await _storage.delete(key: 'companyId');
                                    Navigator.pushReplacementNamed(
                                        context, '/company');
                                  },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue[900],
                              minimumSize: Size(100, 50),
                            ),
                            child: Text(
                              loc.logout,
                              style: TextStyle(
                                  fontSize: 16.0, color: Colors.white),
                            ),
                          ),
                          ElevatedButton(
                            onPressed: _isNavigating
                                ? null
                                : () => _handleLogin(
                                      context,
                                      _usernameController,
                                      _passwordController,
                                      compId ?? 0,
                                    ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue[900],
                              minimumSize: Size(100, 50),
                            ),
                            child: Text(
                              loc.login,
                              style: TextStyle(
                                  fontSize: 16.0, color: Colors.white),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (_isNavigating) ...[
            ModalBarrier(
                color: Colors.black.withOpacity(0.3), dismissible: false),
            Center(child: CircularProgressIndicator(color: Colors.white)),
          ],
        ],
      ),
    );
  }
}

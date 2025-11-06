import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'api.dart';
import 'app_state.dart';
import 'l10n/app_localizations.dart';

class CompanyLoginPage extends StatefulWidget {
  const CompanyLoginPage({super.key});

  @override
  _CompanyLoginPageState createState() => _CompanyLoginPageState();
}

class _CompanyLoginPageState extends State<CompanyLoginPage> {
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isLoading = false;
  final FlutterSecureStorage _storage = FlutterSecureStorage();

  bool _validateFields(BuildContext context) {
    final loc = AppLocalizations.of(context);
    if (_usernameController.text.isEmpty) {
      _showErrorSnackBar(context, '${loc.pleaseenterusername}');
      return false;
    }
    if (_passwordController.text.isEmpty) {
      _showErrorSnackBar(context, '${loc.pleaseenterpassword}');
      return false;
    }
    return true;
  }

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

  Future<void> _handleLogin(BuildContext context) async {
    final loc = AppLocalizations.of(context);
    if (!_validateFields(context)) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final response = await validateCompanyLogin(
        _usernameController.text,
        _passwordController.text,
      );
      print('Company Login response: $response');
      final companyName = response['compName'] as String;
      final companyLogo = response['compLogo'] as String;
      final companyId = response['id'];

      // Save company credentials
      await _storage.write(
          key: 'companyUsername', value: _usernameController.text);
      await _storage.write(
          key: 'companyPassword', value: _passwordController.text);
      await _storage.write(key: 'companyId', value: companyId.toString());

      final stayLogged =
          int.tryParse(await _storage.read(key: 'stayLogged') ?? '1');
      print('DEBUG: Stay Logged setting during manual login: $stayLogged');

      if (stayLogged == 0) {
        // If Stay Logged In is On, attempt user auto-login
        final userUsername = await _storage.read(key: 'userUsername');
        final userPassword = await _storage.read(key: 'userPassword');
        if (userUsername != null && userPassword != null) {
          try {
            final userResponse =
                await validateUserLogin(userUsername, userPassword, companyId);
            final userId = userResponse['userId'];
            final userType = userResponse['userType'];
            Navigator.pushReplacementNamed(context, '/main', arguments: {
              'userId': userId,
              'compId': companyId,
              'userType': userType,
              'compName': companyName,
            });
            return; // Exit early
          } catch (e) {
            print('DEBUG: User auto-login failed during company login: $e');
            // Proceed to UserLoginPage for manual login
          }
        }
      }

      // Navigate to UserLoginPage (either Stay Logged In is Off or user auto-login failed)
      Navigator.pushNamed(context, '/user', arguments: {
        'compName': companyName,
        'compLogo': companyLogo,
        'compId': companyId,
      });
    } catch (e) {
      _showErrorSnackBar(context, loc.loginFailed);
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // In CompanyLoginPage's _autoLoginIfPossible method
  Future<void> _autoLoginIfPossible(BuildContext context) async {
    print('DEBUG: Checking for auto-login at ${DateTime.now()}');

    final stayLogged = await AppState.getStayLogged();
    print('DEBUG: Stay Logged setting: $stayLogged (0=On, 1=Off)');

    final username = await _storage.read(key: 'companyUsername');
    final password = await _storage.read(key: 'companyPassword');

    // Always check company credentials, regardless of stayLogged setting
    if (username != null && password != null) {
      print('DEBUG: Company credentials exist, attempting validation');
      setState(() {
        _isLoading = true;
      });

      try {
        final response = await validateCompanyLogin(username, password);
        print('DEBUG: Company validation response: $response');
        final companyName = response['compName'] as String;
        final companyLogo = response['compLogo'] as String;
        final companyId = response['id'];

        await _storage.write(key: 'companyId', value: companyId.toString());

        // Only attempt auto-login if Stay Logged In is ON
        if (stayLogged == 0) {
          final userUsername = await _storage.read(key: 'userUsername');
          final userPassword = await _storage.read(key: 'userPassword');

          if (userUsername != null && userPassword != null) {
            print('DEBUG: Attempting user auto-login');
            final userResponse =
                await validateUserLogin(userUsername, userPassword, companyId);
            final userId = userResponse['userId'];
            final userType = userResponse['userType'];

            Navigator.pushReplacementNamed(context, '/main', arguments: {
              'userId': userId,
              'compId': companyId,
              'userType': userType,
              'compName': companyName,
            });
            return;
          }
        }

        // If Stay Logged In is OFF or no user credentials, go to user login
        Navigator.pushReplacementNamed(context, '/user', arguments: {
          'compName': companyName,
          'compLogo': companyLogo,
          'compId': companyId,
        });
        return;
      } catch (e) {
        print('DEBUG: Company validation failed: $e');
        await _storage.delete(key: 'companyUsername');
        await _storage.delete(key: 'companyPassword');
        await _storage.delete(key: 'companyId');
      } finally {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _autoLoginIfPossible(context);
    });
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
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
                Image.asset(
                  'assets/alfaDOCK_New.png',
                  height: 50,
                  width: 200,
                ),
                SizedBox(height: 20),
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
                        loc.companyLogin,
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue[900],
                        ),
                      ),
                      TextField(
                        controller: _usernameController,
                        decoration: InputDecoration(
                          labelText: loc.username,
                          border: OutlineInputBorder(),
                        ),
                      ),
                      SizedBox(height: 16.0),
                      TextField(
                        controller: _passwordController,
                        decoration: InputDecoration(
                          labelText: loc.password,
                          border: OutlineInputBorder(),
                        ),
                        obscureText: true,
                      ),
                      SizedBox(height: 24.0),
                      ElevatedButton(
                        onPressed: () => _handleLogin(context),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue[900],
                          minimumSize: Size(double.infinity, 50),
                        ),
                        child: Text(
                          loc.login,
                          style: TextStyle(fontSize: 16.0, color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (_isLoading)
            Container(
              color: Colors.black54,
              child: Center(
                child: CircularProgressIndicator(color: Colors.white),
              ),
            ),
        ],
      ),
    );
  }
}

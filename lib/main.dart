import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'company_login.dart';
import 'user_login.dart';
import 'main_page.dart';
import 'submit_process.dart';
import 'filter.dart';
import 'app_state.dart';
import 'l10n/app_localizations.dart';
import 'locale_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppState.initializeSettings();
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => LocaleProvider()),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<LocaleProvider>(
      builder: (context, localeProvider, child) {
        return MaterialApp(
          title: 'Gaia Schedular',
          theme: ThemeData(
            primarySwatch: Colors.blue,
          ),
          initialRoute: '/company',
          routes: {
            '/company': (context) => CompanyLoginPage(),
            '/user': (context) => UserLoginPage(),
            '/main': (context) => MainPage(),
            '/filter': (context) => FilterPage(
                  processList: [],
                ),
          },
          locale: localeProvider.locale, // Use LocaleProvider's locale
          supportedLocales: [
            Locale('en'),
            Locale('ja'),
          ],
          localizationsDelegates: [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          onGenerateRoute: (settings) {
            if (settings.name == '/submit') {
              final args = settings.arguments as Map<String, dynamic>;
              return MaterialPageRoute(
                builder: (context) => SubmitProcessPage(
                  processData: args['processData'],
                  erpUrlBase: args['erpUrlBase'],
                ),
              );
            }
            return null;
          },
        );
      },
    );
  }
}

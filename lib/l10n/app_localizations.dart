import 'package:flutter/material.dart';
import 'dart:convert';
import 'dart:async';
import 'package:flutter/services.dart' show rootBundle;

class AppLocalizations {
  final Locale locale;

  AppLocalizations(this.locale);

  // Helper method to keep the code in the widgets concise
  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  late Map<String, String> _localizedStrings;

  Future<bool> load() async {
    // Load the ARB file from the assets
    String jsonString =
        await rootBundle.loadString('lib/l10n/app_${locale.languageCode}.arb');
    Map<String, dynamic> jsonMap = json.decode(jsonString);

    _localizedStrings = jsonMap.map((key, value) {
      return MapEntry(key, value.toString());
    });

    return true;
  }

  String translate(String key) {
    return _localizedStrings[key] ?? '** $key not found';
  }

  // Add getters for each string
  String get companyLogin => translate('companyLogin');
  String get userLogin => translate('userLogin');
  String get username => translate('username');
  String get password => translate('password');
  String get login => translate('login');
  String get userLoginButton => translate('userLoginButton');
  String get logout => translate('logout');
  String get companyLoginSuccess => translate('companyLoginSuccess');
  String get userLoginSuccess => translate('userLoginSuccess');
  String get loginFailed => translate('loginFailed');
  String get userLoginFailed => translate('userLoginFailed');
  String get search => translate('search');
  String get searchFiles => translate('searchFiles');
  String get enterKeyword => translate('enterKeyword');
  String get noFilesFound => translate('noFilesFound');
  String get confirmLogout => translate('confirmLogout');
  String get areYouSureLogout => translate('areYouSureLogout');
  String get cancel => translate('cancel');

  String get enterText => translate('enterText');
  String get addText => translate('addText');
  String get fileCount => translate('fileCount');
  String get searchResult => translate('searchResult');
  String get marker => translate('marker');
  String get shape => translate('shape');
  String get editFile => translate('editFile');
  String get edittext => translate('edittext');
  String get color => translate('color');
  String get fontsize => translate('fontsize');
  String get confirmchanges => translate('confirmchanges');
  String get selectshape => translate('selectshape');
  String get square => translate('square');
  String get rectangle => translate('rectangle');
  String get triangle => translate('triangle');
  String get circle => translate('circle');
  String get selectcolors => translate('selectcolors');
  String get bordercolor => translate('bordercolor');
  String get enterpassword => translate('enterpassword');
  String get delete => translate('delete');
  String get attribute => translate('attribute');
  String get aitranscript => translate('aitranscript');
  String get areyousure => translate('areyousure');
  String get doyoureallywanttodeletethisfile =>
      translate('doyoureallywanttodeletethisfile');
  String get apply => translate('apply');
  String get select => translate('select');
  String get filename => translate('filename');
  String get content => translate('content');
  String get failedto => translate('failedto');
  String get invalidfile => translate('invalidfile');
  String get failedtoload => translate('failedtoload');
  String get anerroroccured => translate('anerroroccured');
  String get filedeletesuccess => translate('filedeletesuccess');
  String get unsupport => translate('unsupport');
  String get validfont => translate('validfont');
  String get filesavesuccess => translate('filesavesuccess');
  String get failedtosave => translate('failedtosave');
  String get editfile => translate('editfile');
  String get incorrectpass => translate('incorrectpass');
  String get fileopensuccess => translate('fileopensuccess');
  String get failedtoupload => translate('failedtoupload');
  String get fileuploadsuccess => translate('fileuploadsuccess');
  String get failedtovalidatepassword => translate('failedtovalidatepassword');
  String get deleting => translate('deleting');
  String get DrawingNo => translate('DrawingNo');
  String get ProductName => translate('ProductName');
  String get version => translate('version');
  String get Customer => translate('Customer');
  String get CreatedDate => translate('CreatedDate');
  String get Thickness => translate('Thickness');
  String get Material => translate('Material');
  String get ApprovedBy => translate('ApprovedBy');
  String get MaterialSize => translate('MaterialSize');
  String get Date => translate('Date');
  String get MaterialCode => translate('MaterialCode');
  String get NoRecordFound => translate('NoRecordFound');
  String get test => translate('test');
  String get strokewidth => translate('strokewidth');
  String get fillcolor => translate('fillcolor');
  String get textsetting => translate('textsetting');
  String get shapesetting => translate('shapesetting');
  String get fillshape => translate('fillshape');

  String get line => translate('line');
  String get arrow => translate('arrow');
  String get doublearrow => translate('doublearrow');
  String get oval => translate('oval');
  String get freestylesettings => translate('freestylesettings');
  String get pickcolor => translate('pickcolor');
  String get done => translate('done');
  String get fileinfo => translate('fileinfo');
  String get datecreated => translate('datecreated');
  String get datemodified => translate('datemodified');
  String get unsupportfile => translate('unsupportfile');
  String get nomorefiles => translate('nomorefiles');
  String get errorloadingimage => translate('errorloadingimage');
  String get imagedimensionsarenotavailable =>
      translate('imagedimensionsarenotavailable');
  String get failedtoloadimagedimensions =>
      translate('failedtoloadimagedimensions');
  String get pdfdimensionsarenotavailable =>
      translate('pdfdimensionsarenotavailable');
  String get scanqrcode => translate('scanqrcode');
  String get placeinside => translate('placeinside');
  String get Pleaseenterusernameandpassword =>
      translate('Pleaseenterusernameandpassword');
  String get Biometricauthenticationfailed =>
      translate('Biometricauthenticationfailed');
  String get Loginsuccessfulviafingerprint =>
      translate('Loginsuccessfulviafingerprint');
  String get Loginfailedpleaseloginmanually =>
      translate('Loginfailedpleaseloginmanually');
  String get Nofingerprintloginregisteredpleaseloginmanually =>
      translate('Nofingerprintloginregisteredpleaseloginmanually');
  String get Authenticationfailedpleasetryagainorusepassword =>
      translate('Authenticationfailedpleasetryagainorusepassword');
  String get Authenticationerror => translate('Authenticationerror');
  String get Usebiometriclogin => translate('Usebiometriclogin');
  String get Doyouwanttoenablefingerprintfaceidloginforfuture =>
      translate('Doyouwanttoenablefingerprintfaceidloginforfuture');
  String get Yes => translate('Yes');
  String get No => translate('No');
  String get DoyouwanttoremovethefingerprintfaceID =>
      translate('DoyouwanttoremovethefingerprintfaceID');

  String get FingerprintfaceID => translate('FingerprintfaceID');
  String get FingerprintFaceIDremoved => translate('FingerprintFaceIDremoved');
  String get selectscanner => translate('selectscanner');

  String get qrcodescanner => translate('qrcodescanner');

  String get barcodescanner => translate('barcodescanner');
  String get ModifiedDate => translate('ModifiedDate');
  String get DesignedBy => translate('DesignedBy');
  String get settings => translate('settings');
  String get cancelFunction => translate('cancelFunction');
  String get stayLoggedIn => translate('stayLoggedIn');
  String get userDisplayName => translate('userDisplayName');
  String get id => translate('id');
  String get staffName => translate('staffName');
  String get completeInput => translate('completeInput');
  String get completeProcess => translate('completeProcess');
  String get filter => translate('filter');
  String get notfound => translate('notfound');
  String get noprocessfound => translate('noprocessfound');
  String get gaiaScheduler => translate('gaiaScheduler');
  String get flashOn => translate('flashOn');
  String get flashOff => translate('flashOff');

  String get previous => translate('previous');
  String get today => translate('today');
  String get next => translate('next');
  String get process => translate('process');
  String get waiting => translate('waiting');
  String get started => translate('started');
  String get hold => translate('hold');
  String get downloading => translate('downloading');
  String get delay => translate('delay');
  String get pleaseenterquantity => translate('pleaseenterquantity');
  String get videoUploadedSucessfully => translate('videoUploadedSucessfully');

  String get warning => translate('warning');
  String get flashon => translate('flashon');
  String get prviousprocess => translate('prviousprocess');
  String get nextprocess => translate('nextprocess');
  String get selectdays => translate('selectdays');
  String get days => translate('days');
  String get finished => translate('finished');
  String get selectall => translate('selectall');
  String get submitProcess => translate('submitProcess');
  String get selectAssemblyType => translate('selectAssemblyType');
  String get selectMachineType => translate('selectMachineType');
  String get selectDefectCode => translate('selectDefectCode');
  String get page => translate('page');
  String get noUsersSelected => translate('noUsersSelected');
  String get addUsers => translate('addUsers');
  String get quantity => translate('quantity');
  String get defectQuantity => translate('defectQuantity');
  String get on => translate('on');
  String get off => translate('off');
  String get start => translate('start');
  String get resume => translate('resume');
  String get stop => translate('stop');
  String get startDate => translate('startDate');
  String get endDate => translate('endDate');
  String get startTime => translate('startTime');

  String get pleaseenterusername => translate('pleaseenterusername');
  String get pleaseenterpassword => translate('pleaseenterpassword');
  String get endTime => translate('endTime');
  String get takePhoto => translate('takePhoto');
  String get photoUploadedSucessfully => translate('photoUploadedSucessfully');
  String get pleaseEnterQuantity => translate('pleaseEnterQuantity');
  String get noFoldersOrFilesavailable =>
      translate('noFoldersOrFilesavailable');
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  // Define supported locales
  @override
  bool isSupported(Locale locale) {
    return ['en', 'ja'].contains(locale.languageCode);
  }

  // Load the localized resources
  @override
  Future<AppLocalizations> load(Locale locale) async {
    AppLocalizations localizations = AppLocalizations(locale);
    await localizations.load();
    return localizations;
  }

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

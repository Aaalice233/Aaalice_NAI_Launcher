import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_zh.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale) : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate = _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates = <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('zh')
  ];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'NAI Launcher'**
  String get appTitle;

  /// No description provided for @appSubtitle.
  ///
  /// In en, this message translates to:
  /// **'NovelAI Third-party Client'**
  String get appSubtitle;

  /// No description provided for @common_cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get common_cancel;

  /// No description provided for @common_confirm.
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get common_confirm;

  /// No description provided for @common_selectAll.
  ///
  /// In en, this message translates to:
  /// **'Select All'**
  String get common_selectAll;

  /// No description provided for @common_deselectAll.
  ///
  /// In en, this message translates to:
  /// **'Deselect All'**
  String get common_deselectAll;

  /// No description provided for @common_expandAll.
  ///
  /// In en, this message translates to:
  /// **'Expand All'**
  String get common_expandAll;

  /// No description provided for @common_collapseAll.
  ///
  /// In en, this message translates to:
  /// **'Collapse All'**
  String get common_collapseAll;

  /// No description provided for @common_save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get common_save;

  /// No description provided for @common_saved.
  ///
  /// In en, this message translates to:
  /// **'Saved'**
  String get common_saved;

  /// No description provided for @common_delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get common_delete;

  /// No description provided for @common_edit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get common_edit;

  /// No description provided for @common_close.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get common_close;

  /// No description provided for @common_back.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get common_back;

  /// No description provided for @common_clear.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get common_clear;

  /// No description provided for @common_copy.
  ///
  /// In en, this message translates to:
  /// **'Copy'**
  String get common_copy;

  /// No description provided for @common_copied.
  ///
  /// In en, this message translates to:
  /// **'Copied'**
  String get common_copied;

  /// No description provided for @common_export.
  ///
  /// In en, this message translates to:
  /// **'Export'**
  String get common_export;

  /// No description provided for @common_import.
  ///
  /// In en, this message translates to:
  /// **'Import'**
  String get common_import;

  /// No description provided for @common_loading.
  ///
  /// In en, this message translates to:
  /// **'Loading...'**
  String get common_loading;

  /// No description provided for @common_error.
  ///
  /// In en, this message translates to:
  /// **'Error'**
  String get common_error;

  /// No description provided for @common_success.
  ///
  /// In en, this message translates to:
  /// **'Success'**
  String get common_success;

  /// No description provided for @common_retry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get common_retry;

  /// No description provided for @common_more.
  ///
  /// In en, this message translates to:
  /// **'More'**
  String get common_more;

  /// No description provided for @common_select.
  ///
  /// In en, this message translates to:
  /// **'Select'**
  String get common_select;

  /// No description provided for @common_reset.
  ///
  /// In en, this message translates to:
  /// **'Reset'**
  String get common_reset;

  /// No description provided for @common_search.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get common_search;

  /// No description provided for @common_featureInDev.
  ///
  /// In en, this message translates to:
  /// **'Feature in development...'**
  String get common_featureInDev;

  /// No description provided for @common_add.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get common_add;

  /// No description provided for @common_confirmDelete.
  ///
  /// In en, this message translates to:
  /// **'Confirm Delete'**
  String get common_confirmDelete;

  /// No description provided for @common_settings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get common_settings;

  /// No description provided for @common_today.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get common_today;

  /// No description provided for @common_yesterday.
  ///
  /// In en, this message translates to:
  /// **'Yesterday'**
  String get common_yesterday;

  /// No description provided for @common_daysAgo.
  ///
  /// In en, this message translates to:
  /// **'{days} days ago'**
  String common_daysAgo(Object days);

  /// No description provided for @nav_canvas.
  ///
  /// In en, this message translates to:
  /// **'Canvas'**
  String get nav_canvas;

  /// No description provided for @nav_gallery.
  ///
  /// In en, this message translates to:
  /// **'Gallery'**
  String get nav_gallery;

  /// No description provided for @nav_onlineGallery.
  ///
  /// In en, this message translates to:
  /// **'Online Gallery'**
  String get nav_onlineGallery;

  /// No description provided for @nav_randomConfig.
  ///
  /// In en, this message translates to:
  /// **'Random Config'**
  String get nav_randomConfig;

  /// No description provided for @nav_dictionary.
  ///
  /// In en, this message translates to:
  /// **'Dictionary (WIP)'**
  String get nav_dictionary;

  /// No description provided for @nav_settings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get nav_settings;

  /// No description provided for @nav_discordCommunity.
  ///
  /// In en, this message translates to:
  /// **'Discord Community'**
  String get nav_discordCommunity;

  /// No description provided for @nav_githubRepo.
  ///
  /// In en, this message translates to:
  /// **'GitHub Repository'**
  String get nav_githubRepo;

  /// No description provided for @auth_login.
  ///
  /// In en, this message translates to:
  /// **'Login'**
  String get auth_login;

  /// No description provided for @auth_logout.
  ///
  /// In en, this message translates to:
  /// **'Logout'**
  String get auth_logout;

  /// No description provided for @auth_email.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get auth_email;

  /// No description provided for @auth_emailHint.
  ///
  /// In en, this message translates to:
  /// **'Enter your NovelAI account email'**
  String get auth_emailHint;

  /// No description provided for @auth_password.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get auth_password;

  /// No description provided for @auth_passwordHint.
  ///
  /// In en, this message translates to:
  /// **'Enter password'**
  String get auth_passwordHint;

  /// No description provided for @auth_loginButton.
  ///
  /// In en, this message translates to:
  /// **'Sign In'**
  String get auth_loginButton;

  /// No description provided for @auth_loginFailed.
  ///
  /// In en, this message translates to:
  /// **'Login failed'**
  String get auth_loginFailed;

  /// No description provided for @auth_rememberPassword.
  ///
  /// In en, this message translates to:
  /// **'Remember password'**
  String get auth_rememberPassword;

  /// No description provided for @auth_loginTip.
  ///
  /// In en, this message translates to:
  /// **'Sign in with your NovelAI account\nAll data is stored locally only'**
  String get auth_loginTip;

  /// No description provided for @auth_checkingStatus.
  ///
  /// In en, this message translates to:
  /// **'Checking login status'**
  String get auth_checkingStatus;

  /// No description provided for @auth_loggedIn.
  ///
  /// In en, this message translates to:
  /// **'Logged in'**
  String get auth_loggedIn;

  /// No description provided for @auth_tokenConfigured.
  ///
  /// In en, this message translates to:
  /// **'Token configured'**
  String get auth_tokenConfigured;

  /// No description provided for @auth_notLoggedIn.
  ///
  /// In en, this message translates to:
  /// **'Not logged in'**
  String get auth_notLoggedIn;

  /// No description provided for @auth_pleaseLogin.
  ///
  /// In en, this message translates to:
  /// **'Please login to use all features'**
  String get auth_pleaseLogin;

  /// No description provided for @auth_logoutConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Logout'**
  String get auth_logoutConfirmTitle;

  /// No description provided for @auth_logoutConfirmContent.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to logout?'**
  String get auth_logoutConfirmContent;

  /// No description provided for @auth_emailRequired.
  ///
  /// In en, this message translates to:
  /// **'Please enter email'**
  String get auth_emailRequired;

  /// No description provided for @auth_emailInvalid.
  ///
  /// In en, this message translates to:
  /// **'Please enter a valid email address'**
  String get auth_emailInvalid;

  /// No description provided for @auth_passwordRequired.
  ///
  /// In en, this message translates to:
  /// **'Please enter password'**
  String get auth_passwordRequired;

  /// No description provided for @auth_tokenLogin.
  ///
  /// In en, this message translates to:
  /// **'API Token Login'**
  String get auth_tokenLogin;

  /// No description provided for @auth_credentialsLogin.
  ///
  /// In en, this message translates to:
  /// **'Email & Password'**
  String get auth_credentialsLogin;

  /// No description provided for @auth_credentialsLoginTitle.
  ///
  /// In en, this message translates to:
  /// **'Login with Email'**
  String get auth_credentialsLoginTitle;

  /// No description provided for @auth_tokenHint.
  ///
  /// In en, this message translates to:
  /// **'Enter your Persistent API Token'**
  String get auth_tokenHint;

  /// No description provided for @auth_tokenRequired.
  ///
  /// In en, this message translates to:
  /// **'Please enter token'**
  String get auth_tokenRequired;

  /// No description provided for @auth_tokenInvalid.
  ///
  /// In en, this message translates to:
  /// **'Invalid token format, should start with pst-'**
  String get auth_tokenInvalid;

  /// No description provided for @auth_nicknameOptional.
  ///
  /// In en, this message translates to:
  /// **'Nickname (optional)'**
  String get auth_nicknameOptional;

  /// No description provided for @auth_nicknameHint.
  ///
  /// In en, this message translates to:
  /// **'Set a recognizable name for this account'**
  String get auth_nicknameHint;

  /// No description provided for @auth_saveAccount.
  ///
  /// In en, this message translates to:
  /// **'Save this account'**
  String get auth_saveAccount;

  /// No description provided for @auth_validateAndLogin.
  ///
  /// In en, this message translates to:
  /// **'Validate & Login'**
  String get auth_validateAndLogin;

  /// No description provided for @auth_tokenGuide.
  ///
  /// In en, this message translates to:
  /// **'Get Token from NovelAI settings'**
  String get auth_tokenGuide;

  /// No description provided for @auth_savedAccounts.
  ///
  /// In en, this message translates to:
  /// **'Saved Accounts'**
  String get auth_savedAccounts;

  /// No description provided for @auth_addAccount.
  ///
  /// In en, this message translates to:
  /// **'Add Account'**
  String get auth_addAccount;

  /// No description provided for @auth_manageAccounts.
  ///
  /// In en, this message translates to:
  /// **'Manage'**
  String get auth_manageAccounts;

  /// No description provided for @auth_moreAccounts.
  ///
  /// In en, this message translates to:
  /// **'{count} more accounts'**
  String auth_moreAccounts(Object count);

  /// No description provided for @auth_orAddNewAccount.
  ///
  /// In en, this message translates to:
  /// **'or add new account'**
  String get auth_orAddNewAccount;

  /// No description provided for @auth_tokenNotFound.
  ///
  /// In en, this message translates to:
  /// **'Token not found for this account'**
  String get auth_tokenNotFound;

  /// No description provided for @auth_switchAccount.
  ///
  /// In en, this message translates to:
  /// **'Switch Account'**
  String get auth_switchAccount;

  /// No description provided for @auth_currentAccount.
  ///
  /// In en, this message translates to:
  /// **'Current Account'**
  String get auth_currentAccount;

  /// No description provided for @auth_selectAccount.
  ///
  /// In en, this message translates to:
  /// **'Select Account'**
  String get auth_selectAccount;

  /// No description provided for @auth_deleteAccount.
  ///
  /// In en, this message translates to:
  /// **'Delete Account'**
  String get auth_deleteAccount;

  /// No description provided for @auth_deleteAccountConfirm.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete \"{name}\"? This cannot be undone.'**
  String auth_deleteAccountConfirm(Object name);

  /// No description provided for @auth_cannotDeleteCurrent.
  ///
  /// In en, this message translates to:
  /// **'Cannot delete currently logged in account'**
  String get auth_cannotDeleteCurrent;

  /// No description provided for @auth_changeAvatar.
  ///
  /// In en, this message translates to:
  /// **'Change Avatar'**
  String get auth_changeAvatar;

  /// No description provided for @auth_removeAvatar.
  ///
  /// In en, this message translates to:
  /// **'Remove Avatar'**
  String get auth_removeAvatar;

  /// No description provided for @auth_selectFromGallery.
  ///
  /// In en, this message translates to:
  /// **'Select from Gallery'**
  String get auth_selectFromGallery;

  /// No description provided for @auth_takePhoto.
  ///
  /// In en, this message translates to:
  /// **'Take Photo'**
  String get auth_takePhoto;

  /// No description provided for @auth_quickLogin.
  ///
  /// In en, this message translates to:
  /// **'Quick Login'**
  String get auth_quickLogin;

  /// No description provided for @auth_nicknameRequired.
  ///
  /// In en, this message translates to:
  /// **'Please enter nickname'**
  String get auth_nicknameRequired;

  /// No description provided for @auth_createdAt.
  ///
  /// In en, this message translates to:
  /// **'Created at {date}'**
  String auth_createdAt(Object date);

  /// No description provided for @auth_error_loginFailed.
  ///
  /// In en, this message translates to:
  /// **'Login failed: {error}'**
  String auth_error_loginFailed(Object error);

  /// No description provided for @auth_error_networkTimeout.
  ///
  /// In en, this message translates to:
  /// **'Connection timeout'**
  String get auth_error_networkTimeout;

  /// No description provided for @auth_error_networkError.
  ///
  /// In en, this message translates to:
  /// **'Network error'**
  String get auth_error_networkError;

  /// No description provided for @auth_error_authFailed.
  ///
  /// In en, this message translates to:
  /// **'Authentication failed'**
  String get auth_error_authFailed;

  /// No description provided for @auth_error_authFailed_tokenExpired.
  ///
  /// In en, this message translates to:
  /// **'Token expired, please login again'**
  String get auth_error_authFailed_tokenExpired;

  /// No description provided for @auth_error_serverError.
  ///
  /// In en, this message translates to:
  /// **'Server error'**
  String get auth_error_serverError;

  /// No description provided for @auth_error_unknown.
  ///
  /// In en, this message translates to:
  /// **'Unknown error'**
  String get auth_error_unknown;

  /// No description provided for @auth_autoLogin.
  ///
  /// In en, this message translates to:
  /// **'Auto login'**
  String get auth_autoLogin;

  /// No description provided for @auth_forgotPassword.
  ///
  /// In en, this message translates to:
  /// **'Forgot password?'**
  String get auth_forgotPassword;

  /// No description provided for @auth_passwordTooShort.
  ///
  /// In en, this message translates to:
  /// **'Password must be at least 6 characters'**
  String get auth_passwordTooShort;

  /// No description provided for @auth_loggingIn.
  ///
  /// In en, this message translates to:
  /// **'Logging in...'**
  String get auth_loggingIn;

  /// No description provided for @auth_pleaseWait.
  ///
  /// In en, this message translates to:
  /// **'Please wait'**
  String get auth_pleaseWait;

  /// No description provided for @auth_viewTroubleshootingTips.
  ///
  /// In en, this message translates to:
  /// **'View Troubleshooting Tips'**
  String get auth_viewTroubleshootingTips;

  /// No description provided for @auth_troubleshoot_checkConnection_title.
  ///
  /// In en, this message translates to:
  /// **'Check Network Connection'**
  String get auth_troubleshoot_checkConnection_title;

  /// No description provided for @auth_troubleshoot_checkConnection_desc.
  ///
  /// In en, this message translates to:
  /// **'Ensure your device is connected to the internet'**
  String get auth_troubleshoot_checkConnection_desc;

  /// No description provided for @auth_troubleshoot_retry_title.
  ///
  /// In en, this message translates to:
  /// **'Try Again'**
  String get auth_troubleshoot_retry_title;

  /// No description provided for @auth_troubleshoot_retry_desc.
  ///
  /// In en, this message translates to:
  /// **'Network issues may be temporary, please retry'**
  String get auth_troubleshoot_retry_desc;

  /// No description provided for @auth_troubleshoot_proxy_title.
  ///
  /// In en, this message translates to:
  /// **'Check Proxy Settings'**
  String get auth_troubleshoot_proxy_title;

  /// No description provided for @auth_troubleshoot_proxy_desc.
  ///
  /// In en, this message translates to:
  /// **'If using a proxy, verify it\'s configured correctly'**
  String get auth_troubleshoot_proxy_desc;

  /// No description provided for @auth_troubleshoot_firewall_title.
  ///
  /// In en, this message translates to:
  /// **'Check Firewall Settings'**
  String get auth_troubleshoot_firewall_title;

  /// No description provided for @auth_troubleshoot_firewall_desc.
  ///
  /// In en, this message translates to:
  /// **'Ensure your firewall allows connections to NovelAI servers'**
  String get auth_troubleshoot_firewall_desc;

  /// No description provided for @auth_troubleshoot_serverStatus_title.
  ///
  /// In en, this message translates to:
  /// **'Check Server Status'**
  String get auth_troubleshoot_serverStatus_title;

  /// No description provided for @auth_troubleshoot_serverStatus_desc.
  ///
  /// In en, this message translates to:
  /// **'Visit NovelAI status page or community to check for outages'**
  String get auth_troubleshoot_serverStatus_desc;

  /// No description provided for @auth_passwordResetHelp_title.
  ///
  /// In en, this message translates to:
  /// **'Password Reset'**
  String get auth_passwordResetHelp_title;

  /// No description provided for @auth_passwordResetHelp_desc.
  ///
  /// In en, this message translates to:
  /// **'Clicking \'Forgot password?\' will open NovelAI\'s password reset page in your browser where you can reset your password'**
  String get auth_passwordResetHelp_desc;

  /// No description provided for @auth_passwordResetAfterReset_title.
  ///
  /// In en, this message translates to:
  /// **'After Password Reset'**
  String get auth_passwordResetAfterReset_title;

  /// No description provided for @auth_passwordResetAfterReset_desc.
  ///
  /// In en, this message translates to:
  /// **'After resetting your password on NovelAI website, return to this app and login with your new password'**
  String get auth_passwordResetAfterReset_desc;

  /// No description provided for @auth_passwordResetNoEmail_title.
  ///
  /// In en, this message translates to:
  /// **'Didn\'t receive reset email?'**
  String get auth_passwordResetNoEmail_title;

  /// No description provided for @auth_passwordResetNoEmail_desc.
  ///
  /// In en, this message translates to:
  /// **'Check your spam folder or contact NovelAI support if you don\'t receive the password reset email within a few minutes'**
  String get auth_passwordResetNoEmail_desc;

  /// No description provided for @common_paste.
  ///
  /// In en, this message translates to:
  /// **'Paste'**
  String get common_paste;

  /// No description provided for @common_default.
  ///
  /// In en, this message translates to:
  /// **'Default'**
  String get common_default;

  /// No description provided for @settings_title.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings_title;

  /// No description provided for @settings_account.
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get settings_account;

  /// No description provided for @settings_appearance.
  ///
  /// In en, this message translates to:
  /// **'Appearance'**
  String get settings_appearance;

  /// No description provided for @settings_style.
  ///
  /// In en, this message translates to:
  /// **'Style'**
  String get settings_style;

  /// No description provided for @settings_font.
  ///
  /// In en, this message translates to:
  /// **'Font'**
  String get settings_font;

  /// No description provided for @settings_language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get settings_language;

  /// No description provided for @settings_languageChinese.
  ///
  /// In en, this message translates to:
  /// **'中文'**
  String get settings_languageChinese;

  /// No description provided for @settings_languageEnglish.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get settings_languageEnglish;

  /// No description provided for @settings_selectStyle.
  ///
  /// In en, this message translates to:
  /// **'Select Style'**
  String get settings_selectStyle;

  /// No description provided for @settings_defaultPreset.
  ///
  /// In en, this message translates to:
  /// **'Default'**
  String get settings_defaultPreset;

  /// No description provided for @settings_selectFont.
  ///
  /// In en, this message translates to:
  /// **'Select Font'**
  String get settings_selectFont;

  /// No description provided for @settings_selectLanguage.
  ///
  /// In en, this message translates to:
  /// **'Select Language'**
  String get settings_selectLanguage;

  /// No description provided for @settings_loadFailed.
  ///
  /// In en, this message translates to:
  /// **'Load failed: {error}'**
  String settings_loadFailed(Object error);

  /// No description provided for @settings_storage.
  ///
  /// In en, this message translates to:
  /// **'Storage'**
  String get settings_storage;

  /// No description provided for @settings_imageSavePath.
  ///
  /// In en, this message translates to:
  /// **'Image Save Location'**
  String get settings_imageSavePath;

  /// No description provided for @settings_default.
  ///
  /// In en, this message translates to:
  /// **'Default'**
  String get settings_default;

  /// No description provided for @settings_autoSave.
  ///
  /// In en, this message translates to:
  /// **'Auto Save'**
  String get settings_autoSave;

  /// No description provided for @settings_autoSaveSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Automatically save images after generation'**
  String get settings_autoSaveSubtitle;

  /// No description provided for @settings_about.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get settings_about;

  /// No description provided for @settings_version.
  ///
  /// In en, this message translates to:
  /// **'Version {version}'**
  String settings_version(Object version);

  /// No description provided for @settings_openSource.
  ///
  /// In en, this message translates to:
  /// **'Open Source'**
  String get settings_openSource;

  /// No description provided for @settings_openSourceSubtitle.
  ///
  /// In en, this message translates to:
  /// **'View source code and documentation'**
  String get settings_openSourceSubtitle;

  /// No description provided for @settings_pathReset.
  ///
  /// In en, this message translates to:
  /// **'Reset to default location'**
  String get settings_pathReset;

  /// No description provided for @settings_pathSaved.
  ///
  /// In en, this message translates to:
  /// **'Save location updated'**
  String get settings_pathSaved;

  /// No description provided for @settings_selectFolder.
  ///
  /// In en, this message translates to:
  /// **'Select Save Folder'**
  String get settings_selectFolder;

  /// No description provided for @settings_accountProfile.
  ///
  /// In en, this message translates to:
  /// **'Account Profile'**
  String get settings_accountProfile;

  /// No description provided for @settings_accountType.
  ///
  /// In en, this message translates to:
  /// **'Account Type'**
  String get settings_accountType;

  /// No description provided for @settings_notLoggedIn.
  ///
  /// In en, this message translates to:
  /// **'Log in to set avatar and nickname'**
  String get settings_notLoggedIn;

  /// No description provided for @settings_goToLogin.
  ///
  /// In en, this message translates to:
  /// **'Go to Login'**
  String get settings_goToLogin;

  /// No description provided for @settings_tapToChangeAvatar.
  ///
  /// In en, this message translates to:
  /// **'Tap to change avatar'**
  String get settings_tapToChangeAvatar;

  /// No description provided for @settings_changeAvatar.
  ///
  /// In en, this message translates to:
  /// **'Change Avatar'**
  String get settings_changeAvatar;

  /// No description provided for @settings_removeAvatar.
  ///
  /// In en, this message translates to:
  /// **'Remove Avatar'**
  String get settings_removeAvatar;

  /// No description provided for @settings_nickname.
  ///
  /// In en, this message translates to:
  /// **'Nickname'**
  String get settings_nickname;

  /// No description provided for @settings_accountEmail.
  ///
  /// In en, this message translates to:
  /// **'Account Email'**
  String get settings_accountEmail;

  /// No description provided for @settings_emailAccount.
  ///
  /// In en, this message translates to:
  /// **'Email Account'**
  String get settings_emailAccount;

  /// No description provided for @settings_tokenAccount.
  ///
  /// In en, this message translates to:
  /// **'Token Account'**
  String get settings_tokenAccount;

  /// No description provided for @settings_setAsDefault.
  ///
  /// In en, this message translates to:
  /// **'Set as Default'**
  String get settings_setAsDefault;

  /// No description provided for @settings_defaultAccount.
  ///
  /// In en, this message translates to:
  /// **'Default'**
  String get settings_defaultAccount;

  /// No description provided for @settings_editNickname.
  ///
  /// In en, this message translates to:
  /// **'Edit Nickname'**
  String get settings_editNickname;

  /// No description provided for @settings_nicknameHint.
  ///
  /// In en, this message translates to:
  /// **'Enter 2-32 characters'**
  String get settings_nicknameHint;

  /// No description provided for @settings_nicknameEmpty.
  ///
  /// In en, this message translates to:
  /// **'Please enter a nickname'**
  String get settings_nicknameEmpty;

  /// No description provided for @settings_nicknameTooShort.
  ///
  /// In en, this message translates to:
  /// **'Nickname must be at least {minLength} characters'**
  String settings_nicknameTooShort(int minLength);

  /// No description provided for @settings_nicknameTooLong.
  ///
  /// In en, this message translates to:
  /// **'Nickname cannot exceed {maxLength} characters'**
  String settings_nicknameTooLong(int maxLength);

  /// No description provided for @settings_nicknameAllWhitespace.
  ///
  /// In en, this message translates to:
  /// **'Nickname cannot be all whitespace'**
  String get settings_nicknameAllWhitespace;

  /// No description provided for @settings_nicknameUpdated.
  ///
  /// In en, this message translates to:
  /// **'Nickname updated'**
  String get settings_nicknameUpdated;

  /// No description provided for @settings_avatarUpdated.
  ///
  /// In en, this message translates to:
  /// **'Avatar updated'**
  String get settings_avatarUpdated;

  /// No description provided for @settings_avatarRemoved.
  ///
  /// In en, this message translates to:
  /// **'Avatar removed'**
  String get settings_avatarRemoved;

  /// No description provided for @settings_avatarFileMissing.
  ///
  /// In en, this message translates to:
  /// **'Avatar file missing, select again?'**
  String get settings_avatarFileMissing;

  /// No description provided for @settings_setAsDefaultSuccess.
  ///
  /// In en, this message translates to:
  /// **'Set as default account'**
  String get settings_setAsDefaultSuccess;

  /// No description provided for @settings_startupPerformance.
  ///
  /// In en, this message translates to:
  /// **'Startup Performance'**
  String get settings_startupPerformance;

  /// No description provided for @settings_startupPerformanceSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Configure startup performance settings'**
  String get settings_startupPerformanceSubtitle;

  /// No description provided for @generation_title.
  ///
  /// In en, this message translates to:
  /// **'Generate'**
  String get generation_title;

  /// No description provided for @generation_generate.
  ///
  /// In en, this message translates to:
  /// **'Generate'**
  String get generation_generate;

  /// No description provided for @generation_cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get generation_cancel;

  /// No description provided for @generation_generating.
  ///
  /// In en, this message translates to:
  /// **'Generating...'**
  String get generation_generating;

  /// No description provided for @generation_cancelGeneration.
  ///
  /// In en, this message translates to:
  /// **'Cancel Generation'**
  String get generation_cancelGeneration;

  /// No description provided for @generation_generateImage.
  ///
  /// In en, this message translates to:
  /// **'Generate Image'**
  String get generation_generateImage;

  /// No description provided for @generation_pleaseInputPrompt.
  ///
  /// In en, this message translates to:
  /// **'Please enter prompt'**
  String get generation_pleaseInputPrompt;

  /// No description provided for @generation_emptyPromptHint.
  ///
  /// In en, this message translates to:
  /// **'Enter prompt and click generate'**
  String get generation_emptyPromptHint;

  /// No description provided for @generation_imageWillShowHere.
  ///
  /// In en, this message translates to:
  /// **'Image will be displayed here'**
  String get generation_imageWillShowHere;

  /// No description provided for @generation_generationFailed.
  ///
  /// In en, this message translates to:
  /// **'Generation failed'**
  String get generation_generationFailed;

  /// No description provided for @generation_progress.
  ///
  /// In en, this message translates to:
  /// **'Generating... {progress}%'**
  String generation_progress(Object progress);

  /// No description provided for @generation_params.
  ///
  /// In en, this message translates to:
  /// **'Parameters'**
  String get generation_params;

  /// No description provided for @generation_paramsSettings.
  ///
  /// In en, this message translates to:
  /// **'Parameter Settings'**
  String get generation_paramsSettings;

  /// No description provided for @generation_history.
  ///
  /// In en, this message translates to:
  /// **'History'**
  String get generation_history;

  /// No description provided for @generation_historyRecord.
  ///
  /// In en, this message translates to:
  /// **'History Records'**
  String get generation_historyRecord;

  /// No description provided for @generation_noHistory.
  ///
  /// In en, this message translates to:
  /// **'No history records'**
  String get generation_noHistory;

  /// No description provided for @generation_clearHistory.
  ///
  /// In en, this message translates to:
  /// **'Clear History'**
  String get generation_clearHistory;

  /// No description provided for @generation_clearHistoryConfirm.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to clear all history records? This action cannot be undone.'**
  String get generation_clearHistoryConfirm;

  /// No description provided for @generation_model.
  ///
  /// In en, this message translates to:
  /// **'Model'**
  String get generation_model;

  /// No description provided for @generation_imageSize.
  ///
  /// In en, this message translates to:
  /// **'Image Size'**
  String get generation_imageSize;

  /// No description provided for @generation_sampler.
  ///
  /// In en, this message translates to:
  /// **'Sampler'**
  String get generation_sampler;

  /// No description provided for @generation_steps.
  ///
  /// In en, this message translates to:
  /// **'Steps: {steps}'**
  String generation_steps(Object steps);

  /// No description provided for @generation_cfgScale.
  ///
  /// In en, this message translates to:
  /// **'CFG Scale: {scale}'**
  String generation_cfgScale(Object scale);

  /// No description provided for @generation_seed.
  ///
  /// In en, this message translates to:
  /// **'Seed'**
  String get generation_seed;

  /// No description provided for @generation_seedRandom.
  ///
  /// In en, this message translates to:
  /// **'Random'**
  String get generation_seedRandom;

  /// No description provided for @generation_seedLock.
  ///
  /// In en, this message translates to:
  /// **'Lock Seed'**
  String get generation_seedLock;

  /// No description provided for @generation_seedUnlock.
  ///
  /// In en, this message translates to:
  /// **'Unlock Seed'**
  String get generation_seedUnlock;

  /// No description provided for @generation_advancedOptions.
  ///
  /// In en, this message translates to:
  /// **'Advanced Options'**
  String get generation_advancedOptions;

  /// No description provided for @generation_smea.
  ///
  /// In en, this message translates to:
  /// **'SMEA'**
  String get generation_smea;

  /// No description provided for @generation_smeaSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Improve generation quality for large images'**
  String get generation_smeaSubtitle;

  /// No description provided for @generation_smeaDyn.
  ///
  /// In en, this message translates to:
  /// **'SMEA DYN'**
  String get generation_smeaDyn;

  /// No description provided for @generation_smeaDynSubtitle.
  ///
  /// In en, this message translates to:
  /// **'SMEA dynamic variant'**
  String get generation_smeaDynSubtitle;

  /// No description provided for @generation_smeaDescription.
  ///
  /// In en, this message translates to:
  /// **'High resolution samplers will automatically be used above a certain image size'**
  String get generation_smeaDescription;

  /// No description provided for @generation_cfgRescale.
  ///
  /// In en, this message translates to:
  /// **'CFG Rescale: {value}'**
  String generation_cfgRescale(Object value);

  /// No description provided for @generation_noiseSchedule.
  ///
  /// In en, this message translates to:
  /// **'Noise Schedule'**
  String get generation_noiseSchedule;

  /// No description provided for @generation_resetParams.
  ///
  /// In en, this message translates to:
  /// **'Reset Parameters'**
  String get generation_resetParams;

  /// No description provided for @generation_sizePortrait.
  ///
  /// In en, this message translates to:
  /// **'Portrait ({width}×{height})'**
  String generation_sizePortrait(Object width, Object height);

  /// No description provided for @generation_sizeLandscape.
  ///
  /// In en, this message translates to:
  /// **'Landscape ({width}×{height})'**
  String generation_sizeLandscape(Object width, Object height);

  /// No description provided for @generation_sizeSquare.
  ///
  /// In en, this message translates to:
  /// **'Square ({width}×{height})'**
  String generation_sizeSquare(Object width, Object height);

  /// No description provided for @generation_sizeSmallSquare.
  ///
  /// In en, this message translates to:
  /// **'Small Square ({width}×{height})'**
  String generation_sizeSmallSquare(Object width, Object height);

  /// No description provided for @generation_sizeLargeSquare.
  ///
  /// In en, this message translates to:
  /// **'Large Square ({width}×{height})'**
  String generation_sizeLargeSquare(Object width, Object height);

  /// No description provided for @generation_sizeTallPortrait.
  ///
  /// In en, this message translates to:
  /// **'Tall Portrait ({width}×{height})'**
  String generation_sizeTallPortrait(Object width, Object height);

  /// No description provided for @generation_sizeWideLandscape.
  ///
  /// In en, this message translates to:
  /// **'Wide Landscape ({width}×{height})'**
  String generation_sizeWideLandscape(Object width, Object height);

  /// No description provided for @prompt_positive.
  ///
  /// In en, this message translates to:
  /// **'Positive'**
  String get prompt_positive;

  /// No description provided for @prompt_negative.
  ///
  /// In en, this message translates to:
  /// **'Negative'**
  String get prompt_negative;

  /// No description provided for @prompt_positivePrompt.
  ///
  /// In en, this message translates to:
  /// **'Positive Prompt'**
  String get prompt_positivePrompt;

  /// No description provided for @prompt_negativePrompt.
  ///
  /// In en, this message translates to:
  /// **'Negative Prompt'**
  String get prompt_negativePrompt;

  /// No description provided for @prompt_mainPositive.
  ///
  /// In en, this message translates to:
  /// **'Main Prompt (Positive)'**
  String get prompt_mainPositive;

  /// No description provided for @prompt_mainNegative.
  ///
  /// In en, this message translates to:
  /// **'Main Prompt (Negative)'**
  String get prompt_mainNegative;

  /// No description provided for @prompt_characterPrompts.
  ///
  /// In en, this message translates to:
  /// **'Multi-Character Prompts'**
  String get prompt_characterPrompts;

  /// No description provided for @prompt_characterPromptItem.
  ///
  /// In en, this message translates to:
  /// **'{name}: {content}'**
  String prompt_characterPromptItem(Object name, Object content);

  /// No description provided for @prompt_finalPrompt.
  ///
  /// In en, this message translates to:
  /// **'Final Effective Prompt'**
  String get prompt_finalPrompt;

  /// No description provided for @prompt_finalNegative.
  ///
  /// In en, this message translates to:
  /// **'Final Effective Negative'**
  String get prompt_finalNegative;

  /// No description provided for @prompt_tags.
  ///
  /// In en, this message translates to:
  /// **'{count} tags'**
  String prompt_tags(Object count);

  /// No description provided for @prompt_importedCharacters.
  ///
  /// In en, this message translates to:
  /// **'Imported {count} character(s)'**
  String prompt_importedCharacters(int count);

  /// No description provided for @prompt_editPrompt.
  ///
  /// In en, this message translates to:
  /// **'Edit Prompt'**
  String get prompt_editPrompt;

  /// No description provided for @prompt_inputPrompt.
  ///
  /// In en, this message translates to:
  /// **'Enter prompt...'**
  String get prompt_inputPrompt;

  /// No description provided for @prompt_inputNegativePrompt.
  ///
  /// In en, this message translates to:
  /// **'Enter negative prompt...'**
  String get prompt_inputNegativePrompt;

  /// No description provided for @prompt_describeImage.
  ///
  /// In en, this message translates to:
  /// **'Describe the image you want to generate...'**
  String get prompt_describeImage;

  /// No description provided for @prompt_describeImageWithHint.
  ///
  /// In en, this message translates to:
  /// **'Enter prompt to describe image, type < to reference library, supports tag autocomplete'**
  String get prompt_describeImageWithHint;

  /// No description provided for @prompt_unwantedContent.
  ///
  /// In en, this message translates to:
  /// **'Content you don\'t want in the image...'**
  String get prompt_unwantedContent;

  /// No description provided for @prompt_addTagsHint.
  ///
  /// In en, this message translates to:
  /// **'Add tags to describe your desired image'**
  String get prompt_addTagsHint;

  /// No description provided for @prompt_addUnwantedHint.
  ///
  /// In en, this message translates to:
  /// **'Add unwanted elements'**
  String get prompt_addUnwantedHint;

  /// No description provided for @prompt_fullscreenEdit.
  ///
  /// In en, this message translates to:
  /// **'Fullscreen Edit'**
  String get prompt_fullscreenEdit;

  /// No description provided for @prompt_randomPrompt.
  ///
  /// In en, this message translates to:
  /// **'Random Prompt (long press to configure)'**
  String get prompt_randomPrompt;

  /// No description provided for @prompt_clearConfirm.
  ///
  /// In en, this message translates to:
  /// **'Confirm clear {type}'**
  String prompt_clearConfirm(Object type);

  /// No description provided for @prompt_promptSettings.
  ///
  /// In en, this message translates to:
  /// **'Prompt Settings'**
  String get prompt_promptSettings;

  /// No description provided for @prompt_smartAutocomplete.
  ///
  /// In en, this message translates to:
  /// **'Smart Autocomplete'**
  String get prompt_smartAutocomplete;

  /// No description provided for @prompt_smartAutocompleteSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Show tag suggestions while typing'**
  String get prompt_smartAutocompleteSubtitle;

  /// No description provided for @prompt_autoFormat.
  ///
  /// In en, this message translates to:
  /// **'Auto Format'**
  String get prompt_autoFormat;

  /// No description provided for @prompt_autoFormatSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Convert Chinese commas to English, auto-add underscores'**
  String get prompt_autoFormatSubtitle;

  /// No description provided for @prompt_highlightEmphasis.
  ///
  /// In en, this message translates to:
  /// **'Highlight Emphasis'**
  String get prompt_highlightEmphasis;

  /// No description provided for @prompt_highlightEmphasisSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Highlight brackets and weight syntax'**
  String get prompt_highlightEmphasisSubtitle;

  /// No description provided for @prompt_sdSyntaxAutoConvert.
  ///
  /// In en, this message translates to:
  /// **'SD Syntax Auto Convert'**
  String get prompt_sdSyntaxAutoConvert;

  /// No description provided for @prompt_sdSyntaxAutoConvertSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Convert SD weight syntax to NAI format on blur'**
  String get prompt_sdSyntaxAutoConvertSubtitle;

  /// No description provided for @prompt_cooccurrenceRecommendation.
  ///
  /// In en, this message translates to:
  /// **'Co-occurrence Tag Recommendation'**
  String get prompt_cooccurrenceRecommendation;

  /// No description provided for @prompt_cooccurrenceRecommendationSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Automatically recommend related tags after entering a tag'**
  String get prompt_cooccurrenceRecommendationSubtitle;

  /// No description provided for @prompt_formatted.
  ///
  /// In en, this message translates to:
  /// **'Formatted'**
  String get prompt_formatted;

  /// No description provided for @image_save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get image_save;

  /// No description provided for @image_copy.
  ///
  /// In en, this message translates to:
  /// **'Copy'**
  String get image_copy;

  /// No description provided for @image_upscale.
  ///
  /// In en, this message translates to:
  /// **'Upscale'**
  String get image_upscale;

  /// No description provided for @image_saveToLibrary.
  ///
  /// In en, this message translates to:
  /// **'Save to Library'**
  String get image_saveToLibrary;

  /// No description provided for @image_imageSaved.
  ///
  /// In en, this message translates to:
  /// **'Image saved to: {path}'**
  String image_imageSaved(Object path);

  /// No description provided for @image_saveFailed.
  ///
  /// In en, this message translates to:
  /// **'Save failed: {error}'**
  String image_saveFailed(Object error);

  /// No description provided for @image_copiedToClipboard.
  ///
  /// In en, this message translates to:
  /// **'Copied to clipboard'**
  String get image_copiedToClipboard;

  /// No description provided for @image_copyFailed.
  ///
  /// In en, this message translates to:
  /// **'Copy failed: {error}'**
  String image_copyFailed(Object error);

  /// No description provided for @gallery_title.
  ///
  /// In en, this message translates to:
  /// **'Gallery'**
  String get gallery_title;

  /// No description provided for @gallery_selected.
  ///
  /// In en, this message translates to:
  /// **'Selected {count} items'**
  String gallery_selected(Object count);

  /// No description provided for @gallery_clearAll.
  ///
  /// In en, this message translates to:
  /// **'Clear All'**
  String get gallery_clearAll;

  /// No description provided for @gallery_clearGallery.
  ///
  /// In en, this message translates to:
  /// **'Clear Gallery'**
  String get gallery_clearGallery;

  /// No description provided for @gallery_favorite.
  ///
  /// In en, this message translates to:
  /// **'Favorite'**
  String get gallery_favorite;

  /// No description provided for @gallery_sortNewest.
  ///
  /// In en, this message translates to:
  /// **'Newest First'**
  String get gallery_sortNewest;

  /// No description provided for @gallery_sortOldest.
  ///
  /// In en, this message translates to:
  /// **'Oldest First'**
  String get gallery_sortOldest;

  /// No description provided for @gallery_sortFavorite.
  ///
  /// In en, this message translates to:
  /// **'Favorites First'**
  String get gallery_sortFavorite;

  /// No description provided for @gallery_selectedCount.
  ///
  /// In en, this message translates to:
  /// **'Selected {count} images'**
  String gallery_selectedCount(Object count);

  /// No description provided for @config_title.
  ///
  /// In en, this message translates to:
  /// **'Random Prompt Configuration'**
  String get config_title;

  /// No description provided for @config_presets.
  ///
  /// In en, this message translates to:
  /// **'Presets'**
  String get config_presets;

  /// No description provided for @config_configGroups.
  ///
  /// In en, this message translates to:
  /// **'Config Groups'**
  String get config_configGroups;

  /// No description provided for @config_presetName.
  ///
  /// In en, this message translates to:
  /// **'Preset Name'**
  String get config_presetName;

  /// No description provided for @config_noPresets.
  ///
  /// In en, this message translates to:
  /// **'No presets'**
  String get config_noPresets;

  /// No description provided for @config_restoreDefaults.
  ///
  /// In en, this message translates to:
  /// **'Restore Defaults'**
  String get config_restoreDefaults;

  /// No description provided for @config_newPreset.
  ///
  /// In en, this message translates to:
  /// **'New Preset'**
  String get config_newPreset;

  /// No description provided for @config_selectPreset.
  ///
  /// In en, this message translates to:
  /// **'Select a preset'**
  String get config_selectPreset;

  /// No description provided for @config_noConfigGroups.
  ///
  /// In en, this message translates to:
  /// **'No config groups yet'**
  String get config_noConfigGroups;

  /// No description provided for @config_addConfigGroup.
  ///
  /// In en, this message translates to:
  /// **'Add Config Group'**
  String get config_addConfigGroup;

  /// No description provided for @config_saveChanges.
  ///
  /// In en, this message translates to:
  /// **'Save Changes'**
  String get config_saveChanges;

  /// No description provided for @config_configGroupCount.
  ///
  /// In en, this message translates to:
  /// **'{count} config groups'**
  String config_configGroupCount(Object count);

  /// No description provided for @config_setAsCurrent.
  ///
  /// In en, this message translates to:
  /// **'Set as Current'**
  String get config_setAsCurrent;

  /// No description provided for @config_duplicate.
  ///
  /// In en, this message translates to:
  /// **'Duplicate'**
  String get config_duplicate;

  /// No description provided for @config_importConfig.
  ///
  /// In en, this message translates to:
  /// **'Import Config'**
  String get config_importConfig;

  /// No description provided for @config_selectConfigToEdit.
  ///
  /// In en, this message translates to:
  /// **'Select a config group to edit'**
  String get config_selectConfigToEdit;

  /// No description provided for @config_editConfigGroup.
  ///
  /// In en, this message translates to:
  /// **'Edit Config Group'**
  String get config_editConfigGroup;

  /// No description provided for @config_configName.
  ///
  /// In en, this message translates to:
  /// **'Config Name'**
  String get config_configName;

  /// No description provided for @config_selectionMode.
  ///
  /// In en, this message translates to:
  /// **'Selection Mode'**
  String get config_selectionMode;

  /// No description provided for @config_singleRandom.
  ///
  /// In en, this message translates to:
  /// **'Random Single'**
  String get config_singleRandom;

  /// No description provided for @config_singleSequential.
  ///
  /// In en, this message translates to:
  /// **'Sequential Single'**
  String get config_singleSequential;

  /// No description provided for @config_multipleCount.
  ///
  /// In en, this message translates to:
  /// **'Specified Count'**
  String get config_multipleCount;

  /// No description provided for @config_multipleProbability.
  ///
  /// In en, this message translates to:
  /// **'By Probability'**
  String get config_multipleProbability;

  /// No description provided for @config_all.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get config_all;

  /// No description provided for @config_selectCount.
  ///
  /// In en, this message translates to:
  /// **'Select Count'**
  String get config_selectCount;

  /// No description provided for @config_selectProbability.
  ///
  /// In en, this message translates to:
  /// **'Select Probability'**
  String get config_selectProbability;

  /// No description provided for @config_shuffleOrder.
  ///
  /// In en, this message translates to:
  /// **'Shuffle Order'**
  String get config_shuffleOrder;

  /// No description provided for @config_shuffleOrderSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Randomly arrange selected content'**
  String get config_shuffleOrderSubtitle;

  /// No description provided for @config_weightBrackets.
  ///
  /// In en, this message translates to:
  /// **'Weight Brackets'**
  String get config_weightBrackets;

  /// No description provided for @config_weightBracketsHint.
  ///
  /// In en, this message translates to:
  /// **'Each curly bracket pair increases weight by ~5%'**
  String get config_weightBracketsHint;

  /// No description provided for @config_min.
  ///
  /// In en, this message translates to:
  /// **'Min'**
  String get config_min;

  /// No description provided for @config_max.
  ///
  /// In en, this message translates to:
  /// **'Max'**
  String get config_max;

  /// No description provided for @config_preview.
  ///
  /// In en, this message translates to:
  /// **'Preview: {preview}'**
  String config_preview(Object preview);

  /// No description provided for @config_tagContent.
  ///
  /// In en, this message translates to:
  /// **'Tag Content'**
  String get config_tagContent;

  /// No description provided for @config_tagContentHint.
  ///
  /// In en, this message translates to:
  /// **'One tag per line, currently {count} items'**
  String config_tagContentHint(Object count);

  /// No description provided for @config_format.
  ///
  /// In en, this message translates to:
  /// **'Format'**
  String get config_format;

  /// No description provided for @config_sort.
  ///
  /// In en, this message translates to:
  /// **'Sort'**
  String get config_sort;

  /// No description provided for @config_inputTags.
  ///
  /// In en, this message translates to:
  /// **'Enter tags, one per line...\nFor example:\n1girl\nbeautiful eyes\nlong hair'**
  String get config_inputTags;

  /// No description provided for @config_unsavedChanges.
  ///
  /// In en, this message translates to:
  /// **'Unsaved Changes'**
  String get config_unsavedChanges;

  /// No description provided for @config_unsavedChangesContent.
  ///
  /// In en, this message translates to:
  /// **'You have unsaved changes. Are you sure you want to discard them?'**
  String get config_unsavedChangesContent;

  /// No description provided for @config_discard.
  ///
  /// In en, this message translates to:
  /// **'Discard'**
  String get config_discard;

  /// No description provided for @config_deletePreset.
  ///
  /// In en, this message translates to:
  /// **'Delete Preset'**
  String get config_deletePreset;

  /// No description provided for @config_deletePresetConfirm.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete \"{name}\"?'**
  String config_deletePresetConfirm(Object name);

  /// No description provided for @config_pasteJsonConfig.
  ///
  /// In en, this message translates to:
  /// **'Paste JSON config...'**
  String get config_pasteJsonConfig;

  /// No description provided for @config_importSuccess.
  ///
  /// In en, this message translates to:
  /// **'Import successful'**
  String get config_importSuccess;

  /// No description provided for @config_importFailed.
  ///
  /// In en, this message translates to:
  /// **'Import failed: {error}'**
  String config_importFailed(Object error);

  /// No description provided for @config_restoreDefaultsConfirm.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to restore default presets? All custom configurations will be deleted.'**
  String get config_restoreDefaultsConfirm;

  /// No description provided for @config_restored.
  ///
  /// In en, this message translates to:
  /// **'Restored to defaults'**
  String get config_restored;

  /// No description provided for @config_copiedToClipboard.
  ///
  /// In en, this message translates to:
  /// **'Copied to clipboard'**
  String get config_copiedToClipboard;

  /// No description provided for @config_setAsCurrentSuccess.
  ///
  /// In en, this message translates to:
  /// **'Set as current preset'**
  String get config_setAsCurrentSuccess;

  /// No description provided for @config_duplicatedPreset.
  ///
  /// In en, this message translates to:
  /// **'Preset duplicated'**
  String get config_duplicatedPreset;

  /// No description provided for @config_deletedSuccess.
  ///
  /// In en, this message translates to:
  /// **'Deleted'**
  String get config_deletedSuccess;

  /// No description provided for @config_saveSuccess.
  ///
  /// In en, this message translates to:
  /// **'Saved successfully'**
  String get config_saveSuccess;

  /// No description provided for @config_newPresetCreated.
  ///
  /// In en, this message translates to:
  /// **'New preset created'**
  String get config_newPresetCreated;

  /// No description provided for @config_itemCount.
  ///
  /// In en, this message translates to:
  /// **'{count} items'**
  String config_itemCount(Object count);

  /// No description provided for @config_subConfigCount.
  ///
  /// In en, this message translates to:
  /// **'{count} sub-configs'**
  String config_subConfigCount(Object count);

  /// No description provided for @config_random.
  ///
  /// In en, this message translates to:
  /// **'Random'**
  String get config_random;

  /// No description provided for @config_sequential.
  ///
  /// In en, this message translates to:
  /// **'Sequential'**
  String get config_sequential;

  /// No description provided for @config_multiple.
  ///
  /// In en, this message translates to:
  /// **'Multiple'**
  String get config_multiple;

  /// No description provided for @config_probability.
  ///
  /// In en, this message translates to:
  /// **'Probability'**
  String get config_probability;

  /// No description provided for @config_moreActions.
  ///
  /// In en, this message translates to:
  /// **'More actions'**
  String get config_moreActions;

  /// No description provided for @img2img_title.
  ///
  /// In en, this message translates to:
  /// **'Img2Img'**
  String get img2img_title;

  /// No description provided for @img2img_enabled.
  ///
  /// In en, this message translates to:
  /// **'Enabled'**
  String get img2img_enabled;

  /// No description provided for @img2img_sourceImage.
  ///
  /// In en, this message translates to:
  /// **'Source Image'**
  String get img2img_sourceImage;

  /// No description provided for @img2img_selectImage.
  ///
  /// In en, this message translates to:
  /// **'Select Image'**
  String get img2img_selectImage;

  /// No description provided for @img2img_clickToSelectImage.
  ///
  /// In en, this message translates to:
  /// **'Click to select image'**
  String get img2img_clickToSelectImage;

  /// No description provided for @img2img_strength.
  ///
  /// In en, this message translates to:
  /// **'Strength'**
  String get img2img_strength;

  /// No description provided for @img2img_strengthHint.
  ///
  /// In en, this message translates to:
  /// **'Higher values create greater difference from original'**
  String get img2img_strengthHint;

  /// No description provided for @img2img_noise.
  ///
  /// In en, this message translates to:
  /// **'Noise'**
  String get img2img_noise;

  /// No description provided for @img2img_noiseHint.
  ///
  /// In en, this message translates to:
  /// **'Add extra noise for more variation'**
  String get img2img_noiseHint;

  /// No description provided for @img2img_clearSettings.
  ///
  /// In en, this message translates to:
  /// **'Clear Img2Img Settings'**
  String get img2img_clearSettings;

  /// No description provided for @img2img_changeImage.
  ///
  /// In en, this message translates to:
  /// **'Change Image'**
  String get img2img_changeImage;

  /// No description provided for @img2img_removeImage.
  ///
  /// In en, this message translates to:
  /// **'Remove Image'**
  String get img2img_removeImage;

  /// No description provided for @img2img_selectFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to select image: {error}'**
  String img2img_selectFailed(Object error);

  /// No description provided for @img2img_edit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get img2img_edit;

  /// No description provided for @img2img_maskEnabled.
  ///
  /// In en, this message translates to:
  /// **'Inpaint Mask'**
  String get img2img_maskEnabled;

  /// No description provided for @img2img_uploadImage.
  ///
  /// In en, this message translates to:
  /// **'Upload Image'**
  String get img2img_uploadImage;

  /// No description provided for @img2img_drawSketch.
  ///
  /// In en, this message translates to:
  /// **'Draw Sketch'**
  String get img2img_drawSketch;

  /// No description provided for @img2img_maskTooltip.
  ///
  /// In en, this message translates to:
  /// **'White = modify, Black = preserve'**
  String get img2img_maskTooltip;

  /// No description provided for @img2img_maskHelpText.
  ///
  /// In en, this message translates to:
  /// **'In the mask, white areas will be modified during generation, while black areas will be preserved from the source image'**
  String get img2img_maskHelpText;

  /// No description provided for @editor_title.
  ///
  /// In en, this message translates to:
  /// **'Image Editor'**
  String get editor_title;

  /// No description provided for @editor_done.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get editor_done;

  /// No description provided for @editor_saveAndClose.
  ///
  /// In en, this message translates to:
  /// **'Save & Close'**
  String get editor_saveAndClose;

  /// No description provided for @editor_closeWithoutSaving.
  ///
  /// In en, this message translates to:
  /// **'Close without saving'**
  String get editor_closeWithoutSaving;

  /// No description provided for @editor_close.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get editor_close;

  /// No description provided for @editor_save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get editor_save;

  /// No description provided for @editor_modeImage.
  ///
  /// In en, this message translates to:
  /// **'IMAGE'**
  String get editor_modeImage;

  /// No description provided for @editor_modeMask.
  ///
  /// In en, this message translates to:
  /// **'MASK'**
  String get editor_modeMask;

  /// No description provided for @editor_toolSettings.
  ///
  /// In en, this message translates to:
  /// **'Tool Settings'**
  String get editor_toolSettings;

  /// No description provided for @editor_brushPresets.
  ///
  /// In en, this message translates to:
  /// **'Brush Presets'**
  String get editor_brushPresets;

  /// No description provided for @editor_color.
  ///
  /// In en, this message translates to:
  /// **'Color'**
  String get editor_color;

  /// No description provided for @editor_brushSettings.
  ///
  /// In en, this message translates to:
  /// **'Brush Settings'**
  String get editor_brushSettings;

  /// No description provided for @editor_actions.
  ///
  /// In en, this message translates to:
  /// **'Actions'**
  String get editor_actions;

  /// No description provided for @editor_size.
  ///
  /// In en, this message translates to:
  /// **'Size'**
  String get editor_size;

  /// No description provided for @editor_opacity.
  ///
  /// In en, this message translates to:
  /// **'Opacity'**
  String get editor_opacity;

  /// No description provided for @editor_hardness.
  ///
  /// In en, this message translates to:
  /// **'Hardness'**
  String get editor_hardness;

  /// No description provided for @editor_undo.
  ///
  /// In en, this message translates to:
  /// **'Undo'**
  String get editor_undo;

  /// No description provided for @editor_redo.
  ///
  /// In en, this message translates to:
  /// **'Redo'**
  String get editor_redo;

  /// No description provided for @editor_clearLayer.
  ///
  /// In en, this message translates to:
  /// **'Clear Layer'**
  String get editor_clearLayer;

  /// No description provided for @editor_clearImageLayer.
  ///
  /// In en, this message translates to:
  /// **'Clear Paint'**
  String get editor_clearImageLayer;

  /// No description provided for @editor_clearImageLayerMessage.
  ///
  /// In en, this message translates to:
  /// **'This will remove all paint strokes.'**
  String get editor_clearImageLayerMessage;

  /// No description provided for @editor_clearSelection.
  ///
  /// In en, this message translates to:
  /// **'Clear Selection'**
  String get editor_clearSelection;

  /// No description provided for @editor_clearSelectionMessage.
  ///
  /// In en, this message translates to:
  /// **'This will remove the current selection mask.'**
  String get editor_clearSelectionMessage;

  /// No description provided for @editor_resetView.
  ///
  /// In en, this message translates to:
  /// **'Reset View'**
  String get editor_resetView;

  /// No description provided for @editor_currentColor.
  ///
  /// In en, this message translates to:
  /// **'Current Color'**
  String get editor_currentColor;

  /// No description provided for @editor_zoom.
  ///
  /// In en, this message translates to:
  /// **'Zoom'**
  String get editor_zoom;

  /// No description provided for @editor_paintTools.
  ///
  /// In en, this message translates to:
  /// **'Paint'**
  String get editor_paintTools;

  /// No description provided for @editor_selectionTools.
  ///
  /// In en, this message translates to:
  /// **'Selection'**
  String get editor_selectionTools;

  /// No description provided for @editor_toolBrush.
  ///
  /// In en, this message translates to:
  /// **'Brush'**
  String get editor_toolBrush;

  /// No description provided for @editor_toolEraser.
  ///
  /// In en, this message translates to:
  /// **'Eraser'**
  String get editor_toolEraser;

  /// No description provided for @editor_toolFill.
  ///
  /// In en, this message translates to:
  /// **'Fill'**
  String get editor_toolFill;

  /// No description provided for @editor_toolLine.
  ///
  /// In en, this message translates to:
  /// **'Line'**
  String get editor_toolLine;

  /// No description provided for @editor_toolRectSelect.
  ///
  /// In en, this message translates to:
  /// **'Rectangle'**
  String get editor_toolRectSelect;

  /// No description provided for @editor_toolEllipseSelect.
  ///
  /// In en, this message translates to:
  /// **'Ellipse'**
  String get editor_toolEllipseSelect;

  /// No description provided for @editor_toolColorPicker.
  ///
  /// In en, this message translates to:
  /// **'Color Picker'**
  String get editor_toolColorPicker;

  /// No description provided for @editor_presetDefault.
  ///
  /// In en, this message translates to:
  /// **'Default'**
  String get editor_presetDefault;

  /// No description provided for @editor_presetPencil.
  ///
  /// In en, this message translates to:
  /// **'Pencil'**
  String get editor_presetPencil;

  /// No description provided for @editor_presetMarker.
  ///
  /// In en, this message translates to:
  /// **'Marker'**
  String get editor_presetMarker;

  /// No description provided for @editor_presetAirbrush.
  ///
  /// In en, this message translates to:
  /// **'Airbrush'**
  String get editor_presetAirbrush;

  /// No description provided for @editor_presetInkPen.
  ///
  /// In en, this message translates to:
  /// **'Ink Pen'**
  String get editor_presetInkPen;

  /// No description provided for @editor_presetPixel.
  ///
  /// In en, this message translates to:
  /// **'Pixel'**
  String get editor_presetPixel;

  /// No description provided for @editor_unsavedChanges.
  ///
  /// In en, this message translates to:
  /// **'Unsaved Changes'**
  String get editor_unsavedChanges;

  /// No description provided for @editor_unsavedChangesMessage.
  ///
  /// In en, this message translates to:
  /// **'You have unsaved changes. Are you sure you want to close?'**
  String get editor_unsavedChangesMessage;

  /// No description provided for @editor_discard.
  ///
  /// In en, this message translates to:
  /// **'Discard'**
  String get editor_discard;

  /// No description provided for @editor_cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get editor_cancel;

  /// No description provided for @editor_clearConfirm.
  ///
  /// In en, this message translates to:
  /// **'Clear?'**
  String get editor_clearConfirm;

  /// No description provided for @editor_clearConfirmMessage.
  ///
  /// In en, this message translates to:
  /// **'This will remove all content from the current layer.'**
  String get editor_clearConfirmMessage;

  /// No description provided for @editor_clear.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get editor_clear;

  /// No description provided for @editor_shortcutUndo.
  ///
  /// In en, this message translates to:
  /// **'Undo (Ctrl+Z)'**
  String get editor_shortcutUndo;

  /// No description provided for @editor_shortcutRedo.
  ///
  /// In en, this message translates to:
  /// **'Redo (Ctrl+Y)'**
  String get editor_shortcutRedo;

  /// No description provided for @editor_selectionSettings.
  ///
  /// In en, this message translates to:
  /// **'Selection'**
  String get editor_selectionSettings;

  /// No description provided for @editor_shortcuts.
  ///
  /// In en, this message translates to:
  /// **'Shortcuts'**
  String get editor_shortcuts;

  /// No description provided for @editor_addToSelection.
  ///
  /// In en, this message translates to:
  /// **'Add to selection'**
  String get editor_addToSelection;

  /// No description provided for @editor_subtractFromSelection.
  ///
  /// In en, this message translates to:
  /// **'Subtract from selection'**
  String get editor_subtractFromSelection;

  /// No description provided for @editor_selectionHint.
  ///
  /// In en, this message translates to:
  /// **'Draw selection for inpaint mask'**
  String get editor_selectionHint;

  /// No description provided for @layer_duplicate.
  ///
  /// In en, this message translates to:
  /// **'Duplicate'**
  String get layer_duplicate;

  /// No description provided for @layer_delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get layer_delete;

  /// No description provided for @layer_merge.
  ///
  /// In en, this message translates to:
  /// **'Merge Down'**
  String get layer_merge;

  /// No description provided for @layer_visibility.
  ///
  /// In en, this message translates to:
  /// **'Toggle Visibility'**
  String get layer_visibility;

  /// No description provided for @layer_lock.
  ///
  /// In en, this message translates to:
  /// **'Toggle Lock'**
  String get layer_lock;

  /// No description provided for @layer_rename.
  ///
  /// In en, this message translates to:
  /// **'Rename'**
  String get layer_rename;

  /// No description provided for @layer_moveUp.
  ///
  /// In en, this message translates to:
  /// **'Move Up'**
  String get layer_moveUp;

  /// No description provided for @layer_moveDown.
  ///
  /// In en, this message translates to:
  /// **'Move Down'**
  String get layer_moveDown;

  /// No description provided for @vibe_title.
  ///
  /// In en, this message translates to:
  /// **'Vibe Transfer'**
  String get vibe_title;

  /// No description provided for @vibe_hint.
  ///
  /// In en, this message translates to:
  /// **'Add reference images to transfer visual style (max 4)'**
  String get vibe_hint;

  /// No description provided for @vibe_description.
  ///
  /// In en, this message translates to:
  /// **'Change the image, keep the vision.'**
  String get vibe_description;

  /// No description provided for @vibe_addReference.
  ///
  /// In en, this message translates to:
  /// **'Add Reference'**
  String get vibe_addReference;

  /// No description provided for @vibe_clearAll.
  ///
  /// In en, this message translates to:
  /// **'Clear All'**
  String get vibe_clearAll;

  /// No description provided for @vibe_referenceNumber.
  ///
  /// In en, this message translates to:
  /// **'Reference #{index}'**
  String vibe_referenceNumber(Object index);

  /// No description provided for @vibe_referenceStrength.
  ///
  /// In en, this message translates to:
  /// **'Ref Strength'**
  String get vibe_referenceStrength;

  /// No description provided for @vibe_infoExtraction.
  ///
  /// In en, this message translates to:
  /// **'Info Extraction'**
  String get vibe_infoExtraction;

  /// No description provided for @vibe_adjustParams.
  ///
  /// In en, this message translates to:
  /// **'Adjust Parameters'**
  String get vibe_adjustParams;

  /// No description provided for @vibe_remove.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get vibe_remove;

  /// No description provided for @vibe_sliderHint.
  ///
  /// In en, this message translates to:
  /// **'Strength: Higher mimics visual cues\nInfo Extraction: Lower reduces texture, preserves composition'**
  String get vibe_sliderHint;

  /// No description provided for @vibe_strengthInfo.
  ///
  /// In en, this message translates to:
  /// **'Strength: {value} | Info Extraction: {infoValue}'**
  String vibe_strengthInfo(Object value, Object infoValue);

  /// No description provided for @vibe_normalize.
  ///
  /// In en, this message translates to:
  /// **'Normalize Reference Strength Values'**
  String get vibe_normalize;

  /// No description provided for @vibe_encodingCost.
  ///
  /// In en, this message translates to:
  /// **'Encoding required. This will cost {cost} Anlas on the next generation.'**
  String vibe_encodingCost(int cost);

  /// No description provided for @vibe_sourceType_png.
  ///
  /// In en, this message translates to:
  /// **'PNG'**
  String get vibe_sourceType_png;

  /// No description provided for @vibe_sourceType_v4vibe.
  ///
  /// In en, this message translates to:
  /// **'V4 Vibe'**
  String get vibe_sourceType_v4vibe;

  /// No description provided for @vibe_sourceType_bundle.
  ///
  /// In en, this message translates to:
  /// **'Bundle'**
  String get vibe_sourceType_bundle;

  /// No description provided for @vibe_sourceType_image.
  ///
  /// In en, this message translates to:
  /// **'Image'**
  String get vibe_sourceType_image;

  /// No description provided for @characterRef_title.
  ///
  /// In en, this message translates to:
  /// **'Character Reference'**
  String get characterRef_title;

  /// No description provided for @characterRef_hint.
  ///
  /// In en, this message translates to:
  /// **'Upload character reference images to maintain consistency (V4+ only)'**
  String get characterRef_hint;

  /// No description provided for @characterRef_v4Only.
  ///
  /// In en, this message translates to:
  /// **'Character Reference only supports V4+ models, please switch models'**
  String get characterRef_v4Only;

  /// No description provided for @characterRef_addReference.
  ///
  /// In en, this message translates to:
  /// **'Add Reference'**
  String get characterRef_addReference;

  /// No description provided for @characterRef_clearAll.
  ///
  /// In en, this message translates to:
  /// **'Clear All'**
  String get characterRef_clearAll;

  /// No description provided for @characterRef_referenceNumber.
  ///
  /// In en, this message translates to:
  /// **'Reference #{index}'**
  String characterRef_referenceNumber(Object index);

  /// No description provided for @characterRef_description.
  ///
  /// In en, this message translates to:
  /// **'Character Description'**
  String get characterRef_description;

  /// No description provided for @characterRef_descriptionHint.
  ///
  /// In en, this message translates to:
  /// **'Describe this character\'s features (optional but recommended)...'**
  String get characterRef_descriptionHint;

  /// No description provided for @characterRef_remove.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get characterRef_remove;

  /// No description provided for @characterRef_styleAware.
  ///
  /// In en, this message translates to:
  /// **'Style Aware'**
  String get characterRef_styleAware;

  /// No description provided for @characterRef_styleAwareHint.
  ///
  /// In en, this message translates to:
  /// **'Transfer character relevant style information'**
  String get characterRef_styleAwareHint;

  /// No description provided for @characterRef_fidelity.
  ///
  /// In en, this message translates to:
  /// **'Fidelity'**
  String get characterRef_fidelity;

  /// No description provided for @characterRef_fidelityHint.
  ///
  /// In en, this message translates to:
  /// **'0=Old version behavior, 1=New version behavior'**
  String get characterRef_fidelityHint;

  /// No description provided for @unifiedRef_title.
  ///
  /// In en, this message translates to:
  /// **'Image Reference'**
  String get unifiedRef_title;

  /// No description provided for @unifiedRef_switchTitle.
  ///
  /// In en, this message translates to:
  /// **'Switch Mode'**
  String get unifiedRef_switchTitle;

  /// No description provided for @unifiedRef_switchContent.
  ///
  /// In en, this message translates to:
  /// **'Switching modes will clear current references. Continue?'**
  String get unifiedRef_switchContent;

  /// No description provided for @character_buttonLabel.
  ///
  /// In en, this message translates to:
  /// **'Characters'**
  String get character_buttonLabel;

  /// No description provided for @character_title.
  ///
  /// In en, this message translates to:
  /// **'Multi-Character (V4 Only)'**
  String get character_title;

  /// No description provided for @character_hint.
  ///
  /// In en, this message translates to:
  /// **'Define independent prompts and positions for each character (max 6)'**
  String get character_hint;

  /// No description provided for @character_addCharacter.
  ///
  /// In en, this message translates to:
  /// **'Add Character'**
  String get character_addCharacter;

  /// No description provided for @character_clearAll.
  ///
  /// In en, this message translates to:
  /// **'Clear All Characters'**
  String get character_clearAll;

  /// No description provided for @character_number.
  ///
  /// In en, this message translates to:
  /// **'Character {index}'**
  String character_number(Object index);

  /// No description provided for @character_advancedOptions.
  ///
  /// In en, this message translates to:
  /// **'Advanced Options'**
  String get character_advancedOptions;

  /// No description provided for @character_removeCharacter.
  ///
  /// In en, this message translates to:
  /// **'Remove Character'**
  String get character_removeCharacter;

  /// No description provided for @character_description.
  ///
  /// In en, this message translates to:
  /// **'Character Description'**
  String get character_description;

  /// No description provided for @character_descriptionHint.
  ///
  /// In en, this message translates to:
  /// **'Describe this character\'s features...'**
  String get character_descriptionHint;

  /// No description provided for @character_negativeOptional.
  ///
  /// In en, this message translates to:
  /// **'Negative Prompt (Optional)'**
  String get character_negativeOptional;

  /// No description provided for @character_negativeHint.
  ///
  /// In en, this message translates to:
  /// **'Features you don\'t want on this character...'**
  String get character_negativeHint;

  /// No description provided for @character_positionOptional.
  ///
  /// In en, this message translates to:
  /// **'Character Position (Optional)'**
  String get character_positionOptional;

  /// No description provided for @character_positionHint.
  ///
  /// In en, this message translates to:
  /// **'Position (0-1), specifies approximate position in image'**
  String get character_positionHint;

  /// No description provided for @character_auto.
  ///
  /// In en, this message translates to:
  /// **'Auto'**
  String get character_auto;

  /// No description provided for @character_clearPosition.
  ///
  /// In en, this message translates to:
  /// **'Clear Position'**
  String get character_clearPosition;

  /// No description provided for @gallery_empty.
  ///
  /// In en, this message translates to:
  /// **'Gallery is empty'**
  String get gallery_empty;

  /// No description provided for @gallery_emptyHint.
  ///
  /// In en, this message translates to:
  /// **'Generated images will appear here'**
  String get gallery_emptyHint;

  /// No description provided for @gallery_searchHint.
  ///
  /// In en, this message translates to:
  /// **'Search prompts... (supports tags)'**
  String get gallery_searchHint;

  /// No description provided for @gallery_imageCount.
  ///
  /// In en, this message translates to:
  /// **'{count} images'**
  String gallery_imageCount(Object count);

  /// No description provided for @gallery_exportSuccess.
  ///
  /// In en, this message translates to:
  /// **'Exported {count} images to {path}'**
  String gallery_exportSuccess(Object count, Object path);

  /// No description provided for @gallery_savedTo.
  ///
  /// In en, this message translates to:
  /// **'Saved to {path}'**
  String gallery_savedTo(Object path);

  /// No description provided for @gallery_saveFailed.
  ///
  /// In en, this message translates to:
  /// **'Save failed'**
  String get gallery_saveFailed;

  /// No description provided for @gallery_deleteImage.
  ///
  /// In en, this message translates to:
  /// **'Delete Image'**
  String get gallery_deleteImage;

  /// No description provided for @gallery_deleteImageConfirm.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete this image?'**
  String get gallery_deleteImageConfirm;

  /// No description provided for @gallery_generationParams.
  ///
  /// In en, this message translates to:
  /// **'Generation Parameters'**
  String get gallery_generationParams;

  /// No description provided for @gallery_metaModel.
  ///
  /// In en, this message translates to:
  /// **'Model'**
  String get gallery_metaModel;

  /// No description provided for @gallery_metaResolution.
  ///
  /// In en, this message translates to:
  /// **'Resolution'**
  String get gallery_metaResolution;

  /// No description provided for @gallery_metaSteps.
  ///
  /// In en, this message translates to:
  /// **'Steps'**
  String get gallery_metaSteps;

  /// No description provided for @gallery_metaSampler.
  ///
  /// In en, this message translates to:
  /// **'Sampler'**
  String get gallery_metaSampler;

  /// No description provided for @gallery_metaCfgScale.
  ///
  /// In en, this message translates to:
  /// **'CFG Scale'**
  String get gallery_metaCfgScale;

  /// No description provided for @gallery_metaSeed.
  ///
  /// In en, this message translates to:
  /// **'Seed'**
  String get gallery_metaSeed;

  /// No description provided for @gallery_metaSmea.
  ///
  /// In en, this message translates to:
  /// **'SMEA'**
  String get gallery_metaSmea;

  /// No description provided for @gallery_metaSmeaOn.
  ///
  /// In en, this message translates to:
  /// **'On'**
  String get gallery_metaSmeaOn;

  /// No description provided for @gallery_metaSmeaOff.
  ///
  /// In en, this message translates to:
  /// **'Off'**
  String get gallery_metaSmeaOff;

  /// No description provided for @gallery_metaGenerationTime.
  ///
  /// In en, this message translates to:
  /// **'Generation Time'**
  String get gallery_metaGenerationTime;

  /// No description provided for @gallery_metaFileSize.
  ///
  /// In en, this message translates to:
  /// **'File Size'**
  String get gallery_metaFileSize;

  /// No description provided for @gallery_positivePrompt.
  ///
  /// In en, this message translates to:
  /// **'Positive Prompt'**
  String get gallery_positivePrompt;

  /// No description provided for @gallery_negativePrompt.
  ///
  /// In en, this message translates to:
  /// **'Negative Prompt'**
  String get gallery_negativePrompt;

  /// No description provided for @preset_noPresets.
  ///
  /// In en, this message translates to:
  /// **'No presets'**
  String get preset_noPresets;

  /// No description provided for @preset_restoreDefault.
  ///
  /// In en, this message translates to:
  /// **'Restore Default'**
  String get preset_restoreDefault;

  /// No description provided for @preset_configGroupCount.
  ///
  /// In en, this message translates to:
  /// **'{count} config groups'**
  String preset_configGroupCount(Object count);

  /// No description provided for @preset_setAsCurrent.
  ///
  /// In en, this message translates to:
  /// **'Set as Current'**
  String get preset_setAsCurrent;

  /// No description provided for @preset_duplicate.
  ///
  /// In en, this message translates to:
  /// **'Duplicate'**
  String get preset_duplicate;

  /// No description provided for @preset_export.
  ///
  /// In en, this message translates to:
  /// **'Export'**
  String get preset_export;

  /// No description provided for @preset_delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get preset_delete;

  /// No description provided for @preset_noConfigGroups.
  ///
  /// In en, this message translates to:
  /// **'No config groups yet'**
  String get preset_noConfigGroups;

  /// No description provided for @preset_addConfigGroup.
  ///
  /// In en, this message translates to:
  /// **'Add Config Group'**
  String get preset_addConfigGroup;

  /// No description provided for @preset_selectPreset.
  ///
  /// In en, this message translates to:
  /// **'Select a preset'**
  String get preset_selectPreset;

  /// No description provided for @preset_selectConfigToEdit.
  ///
  /// In en, this message translates to:
  /// **'Select a config group to edit'**
  String get preset_selectConfigToEdit;

  /// No description provided for @preset_editConfigGroup.
  ///
  /// In en, this message translates to:
  /// **'Edit Config Group'**
  String get preset_editConfigGroup;

  /// No description provided for @preset_configName.
  ///
  /// In en, this message translates to:
  /// **'Config Name'**
  String get preset_configName;

  /// No description provided for @preset_presetName.
  ///
  /// In en, this message translates to:
  /// **'Preset Name'**
  String get preset_presetName;

  /// No description provided for @preset_selectionMode.
  ///
  /// In en, this message translates to:
  /// **'Selection Mode'**
  String get preset_selectionMode;

  /// No description provided for @preset_randomSingle.
  ///
  /// In en, this message translates to:
  /// **'Random Single'**
  String get preset_randomSingle;

  /// No description provided for @preset_sequentialSingle.
  ///
  /// In en, this message translates to:
  /// **'Sequential Single'**
  String get preset_sequentialSingle;

  /// No description provided for @preset_specifiedCount.
  ///
  /// In en, this message translates to:
  /// **'Specified Count'**
  String get preset_specifiedCount;

  /// No description provided for @preset_byProbability.
  ///
  /// In en, this message translates to:
  /// **'By Probability'**
  String get preset_byProbability;

  /// No description provided for @preset_all.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get preset_all;

  /// No description provided for @preset_selectCount.
  ///
  /// In en, this message translates to:
  /// **'Select Count'**
  String get preset_selectCount;

  /// No description provided for @preset_selectProbability.
  ///
  /// In en, this message translates to:
  /// **'Select Probability'**
  String get preset_selectProbability;

  /// No description provided for @preset_shuffleOrder.
  ///
  /// In en, this message translates to:
  /// **'Shuffle Order'**
  String get preset_shuffleOrder;

  /// No description provided for @preset_shuffleOrderHint.
  ///
  /// In en, this message translates to:
  /// **'Randomly arrange selected content'**
  String get preset_shuffleOrderHint;

  /// No description provided for @preset_weightBrackets.
  ///
  /// In en, this message translates to:
  /// **'Weight Brackets'**
  String get preset_weightBrackets;

  /// No description provided for @preset_weightBracketsHint.
  ///
  /// In en, this message translates to:
  /// **'Each curly bracket increases weight by ~5%'**
  String get preset_weightBracketsHint;

  /// No description provided for @preset_min.
  ///
  /// In en, this message translates to:
  /// **'Min'**
  String get preset_min;

  /// No description provided for @preset_max.
  ///
  /// In en, this message translates to:
  /// **'Max'**
  String get preset_max;

  /// No description provided for @preset_preview.
  ///
  /// In en, this message translates to:
  /// **'Preview: {preview}'**
  String preset_preview(Object preview);

  /// No description provided for @preset_tagContent.
  ///
  /// In en, this message translates to:
  /// **'Tag Content'**
  String get preset_tagContent;

  /// No description provided for @preset_tagContentHint.
  ///
  /// In en, this message translates to:
  /// **'One tag per line, currently {count} items'**
  String preset_tagContentHint(Object count);

  /// No description provided for @preset_format.
  ///
  /// In en, this message translates to:
  /// **'Format'**
  String get preset_format;

  /// No description provided for @preset_sort.
  ///
  /// In en, this message translates to:
  /// **'Sort'**
  String get preset_sort;

  /// No description provided for @preset_inputHint.
  ///
  /// In en, this message translates to:
  /// **'Enter tags, one per line...\nFor example:\n1girl\nbeautiful eyes\nlong hair'**
  String get preset_inputHint;

  /// No description provided for @preset_unsavedChanges.
  ///
  /// In en, this message translates to:
  /// **'Unsaved Changes'**
  String get preset_unsavedChanges;

  /// No description provided for @preset_unsavedChangesConfirm.
  ///
  /// In en, this message translates to:
  /// **'There are unsaved changes. Discard?'**
  String get preset_unsavedChangesConfirm;

  /// No description provided for @preset_discard.
  ///
  /// In en, this message translates to:
  /// **'Discard'**
  String get preset_discard;

  /// No description provided for @preset_deletePreset.
  ///
  /// In en, this message translates to:
  /// **'Delete Preset'**
  String get preset_deletePreset;

  /// No description provided for @preset_deletePresetConfirm.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete \"{name}\"?'**
  String preset_deletePresetConfirm(Object name);

  /// No description provided for @preset_importConfig.
  ///
  /// In en, this message translates to:
  /// **'Import Config'**
  String get preset_importConfig;

  /// No description provided for @preset_pasteJson.
  ///
  /// In en, this message translates to:
  /// **'Paste JSON config...'**
  String get preset_pasteJson;

  /// No description provided for @preset_importSuccess.
  ///
  /// In en, this message translates to:
  /// **'Import successful'**
  String get preset_importSuccess;

  /// No description provided for @preset_importFailed.
  ///
  /// In en, this message translates to:
  /// **'Import failed: {error}'**
  String preset_importFailed(Object error);

  /// No description provided for @preset_restoreDefaultConfirm.
  ///
  /// In en, this message translates to:
  /// **'Restore default presets? All custom configs will be deleted.'**
  String get preset_restoreDefaultConfirm;

  /// No description provided for @preset_restored.
  ///
  /// In en, this message translates to:
  /// **'Restored to defaults'**
  String get preset_restored;

  /// No description provided for @preset_copiedToClipboard.
  ///
  /// In en, this message translates to:
  /// **'Copied to clipboard'**
  String get preset_copiedToClipboard;

  /// No description provided for @preset_setAsCurrentSuccess.
  ///
  /// In en, this message translates to:
  /// **'Set as current preset'**
  String get preset_setAsCurrentSuccess;

  /// No description provided for @preset_duplicated.
  ///
  /// In en, this message translates to:
  /// **'Preset duplicated'**
  String get preset_duplicated;

  /// No description provided for @preset_deleted.
  ///
  /// In en, this message translates to:
  /// **'Deleted'**
  String get preset_deleted;

  /// No description provided for @preset_saveSuccess.
  ///
  /// In en, this message translates to:
  /// **'Saved successfully'**
  String get preset_saveSuccess;

  /// No description provided for @preset_newPresetCreated.
  ///
  /// In en, this message translates to:
  /// **'New preset created'**
  String get preset_newPresetCreated;

  /// No description provided for @preset_itemCount.
  ///
  /// In en, this message translates to:
  /// **'{count} items'**
  String preset_itemCount(Object count);

  /// No description provided for @preset_subConfigCount.
  ///
  /// In en, this message translates to:
  /// **'{count} sub-configs'**
  String preset_subConfigCount(Object count);

  /// No description provided for @preset_random.
  ///
  /// In en, this message translates to:
  /// **'Random'**
  String get preset_random;

  /// No description provided for @preset_sequential.
  ///
  /// In en, this message translates to:
  /// **'Sequential'**
  String get preset_sequential;

  /// No description provided for @preset_multiple.
  ///
  /// In en, this message translates to:
  /// **'Multiple'**
  String get preset_multiple;

  /// No description provided for @preset_probability.
  ///
  /// In en, this message translates to:
  /// **'Probability'**
  String get preset_probability;

  /// No description provided for @preset_moreActions.
  ///
  /// In en, this message translates to:
  /// **'More Actions'**
  String get preset_moreActions;

  /// No description provided for @preset_rename.
  ///
  /// In en, this message translates to:
  /// **'Rename'**
  String get preset_rename;

  /// No description provided for @preset_moveUp.
  ///
  /// In en, this message translates to:
  /// **'Move Up'**
  String get preset_moveUp;

  /// No description provided for @preset_moveDown.
  ///
  /// In en, this message translates to:
  /// **'Move Down'**
  String get preset_moveDown;

  /// No description provided for @onlineGallery_search.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get onlineGallery_search;

  /// No description provided for @onlineGallery_popular.
  ///
  /// In en, this message translates to:
  /// **'Popular'**
  String get onlineGallery_popular;

  /// No description provided for @onlineGallery_favorites.
  ///
  /// In en, this message translates to:
  /// **'Favorites'**
  String get onlineGallery_favorites;

  /// No description provided for @onlineGallery_searchTags.
  ///
  /// In en, this message translates to:
  /// **'Search tags...'**
  String get onlineGallery_searchTags;

  /// No description provided for @onlineGallery_refresh.
  ///
  /// In en, this message translates to:
  /// **'Refresh'**
  String get onlineGallery_refresh;

  /// No description provided for @onlineGallery_login.
  ///
  /// In en, this message translates to:
  /// **'Login'**
  String get onlineGallery_login;

  /// No description provided for @onlineGallery_logout.
  ///
  /// In en, this message translates to:
  /// **'Logout'**
  String get onlineGallery_logout;

  /// No description provided for @onlineGallery_dayRank.
  ///
  /// In en, this message translates to:
  /// **'Day'**
  String get onlineGallery_dayRank;

  /// No description provided for @onlineGallery_weekRank.
  ///
  /// In en, this message translates to:
  /// **'Week'**
  String get onlineGallery_weekRank;

  /// No description provided for @onlineGallery_monthRank.
  ///
  /// In en, this message translates to:
  /// **'Month'**
  String get onlineGallery_monthRank;

  /// No description provided for @onlineGallery_today.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get onlineGallery_today;

  /// No description provided for @onlineGallery_imageCount.
  ///
  /// In en, this message translates to:
  /// **'{count} images'**
  String onlineGallery_imageCount(Object count);

  /// No description provided for @onlineGallery_loadFailed.
  ///
  /// In en, this message translates to:
  /// **'Load failed'**
  String get onlineGallery_loadFailed;

  /// No description provided for @onlineGallery_favoritesEmpty.
  ///
  /// In en, this message translates to:
  /// **'Favorites is empty'**
  String get onlineGallery_favoritesEmpty;

  /// No description provided for @onlineGallery_noResults.
  ///
  /// In en, this message translates to:
  /// **'No images found'**
  String get onlineGallery_noResults;

  /// No description provided for @onlineGallery_pleaseLogin.
  ///
  /// In en, this message translates to:
  /// **'Please login first'**
  String get onlineGallery_pleaseLogin;

  /// No description provided for @onlineGallery_size.
  ///
  /// In en, this message translates to:
  /// **'Size'**
  String get onlineGallery_size;

  /// No description provided for @onlineGallery_score.
  ///
  /// In en, this message translates to:
  /// **'Score'**
  String get onlineGallery_score;

  /// No description provided for @onlineGallery_favCount.
  ///
  /// In en, this message translates to:
  /// **'Favorites'**
  String get onlineGallery_favCount;

  /// No description provided for @onlineGallery_rating.
  ///
  /// In en, this message translates to:
  /// **'Rating'**
  String get onlineGallery_rating;

  /// No description provided for @onlineGallery_type.
  ///
  /// In en, this message translates to:
  /// **'Type'**
  String get onlineGallery_type;

  /// No description provided for @mediaType_video.
  ///
  /// In en, this message translates to:
  /// **'Video'**
  String get mediaType_video;

  /// No description provided for @mediaType_gif.
  ///
  /// In en, this message translates to:
  /// **'GIF'**
  String get mediaType_gif;

  /// No description provided for @onlineGallery_tags.
  ///
  /// In en, this message translates to:
  /// **'Tags'**
  String get onlineGallery_tags;

  /// No description provided for @onlineGallery_artists.
  ///
  /// In en, this message translates to:
  /// **'Artists'**
  String get onlineGallery_artists;

  /// No description provided for @onlineGallery_characters.
  ///
  /// In en, this message translates to:
  /// **'Characters'**
  String get onlineGallery_characters;

  /// No description provided for @onlineGallery_copyrights.
  ///
  /// In en, this message translates to:
  /// **'Copyrights'**
  String get onlineGallery_copyrights;

  /// No description provided for @onlineGallery_general.
  ///
  /// In en, this message translates to:
  /// **'General'**
  String get onlineGallery_general;

  /// No description provided for @onlineGallery_copied.
  ///
  /// In en, this message translates to:
  /// **'Copied'**
  String get onlineGallery_copied;

  /// No description provided for @onlineGallery_copyTags.
  ///
  /// In en, this message translates to:
  /// **'Copy Tags'**
  String get onlineGallery_copyTags;

  /// No description provided for @onlineGallery_open.
  ///
  /// In en, this message translates to:
  /// **'Open'**
  String get onlineGallery_open;

  /// No description provided for @onlineGallery_all.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get onlineGallery_all;

  /// No description provided for @onlineGallery_ratingGeneral.
  ///
  /// In en, this message translates to:
  /// **'General'**
  String get onlineGallery_ratingGeneral;

  /// No description provided for @onlineGallery_ratingSensitive.
  ///
  /// In en, this message translates to:
  /// **'Sensitive'**
  String get onlineGallery_ratingSensitive;

  /// No description provided for @onlineGallery_ratingQuestionable.
  ///
  /// In en, this message translates to:
  /// **'Questionable'**
  String get onlineGallery_ratingQuestionable;

  /// No description provided for @onlineGallery_ratingExplicit.
  ///
  /// In en, this message translates to:
  /// **'Explicit'**
  String get onlineGallery_ratingExplicit;

  /// No description provided for @onlineGallery_clear.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get onlineGallery_clear;

  /// No description provided for @onlineGallery_previousPage.
  ///
  /// In en, this message translates to:
  /// **'Previous Page'**
  String get onlineGallery_previousPage;

  /// No description provided for @onlineGallery_nextPage.
  ///
  /// In en, this message translates to:
  /// **'Next Page'**
  String get onlineGallery_nextPage;

  /// No description provided for @onlineGallery_pageN.
  ///
  /// In en, this message translates to:
  /// **'Page {page}'**
  String onlineGallery_pageN(Object page);

  /// No description provided for @onlineGallery_dateRange.
  ///
  /// In en, this message translates to:
  /// **'Date Range'**
  String get onlineGallery_dateRange;

  /// No description provided for @tooltip_randomPrompt.
  ///
  /// In en, this message translates to:
  /// **'Random Prompt (long press to configure)'**
  String get tooltip_randomPrompt;

  /// No description provided for @tooltip_fullscreenEdit.
  ///
  /// In en, this message translates to:
  /// **'Fullscreen Edit'**
  String get tooltip_fullscreenEdit;

  /// No description provided for @tooltip_maximizePrompt.
  ///
  /// In en, this message translates to:
  /// **'Maximize Prompt Area'**
  String get tooltip_maximizePrompt;

  /// No description provided for @tooltip_restoreLayout.
  ///
  /// In en, this message translates to:
  /// **'Restore Layout'**
  String get tooltip_restoreLayout;

  /// No description provided for @tooltip_clear.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get tooltip_clear;

  /// No description provided for @tooltip_promptSettings.
  ///
  /// In en, this message translates to:
  /// **'Prompt Settings'**
  String get tooltip_promptSettings;

  /// No description provided for @tooltip_decreaseWeight.
  ///
  /// In en, this message translates to:
  /// **'Decrease Weight [-5%]'**
  String get tooltip_decreaseWeight;

  /// No description provided for @tooltip_increaseWeight.
  ///
  /// In en, this message translates to:
  /// **'Increase Weight [+5%]'**
  String get tooltip_increaseWeight;

  /// No description provided for @tooltip_edit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get tooltip_edit;

  /// No description provided for @tooltip_copy.
  ///
  /// In en, this message translates to:
  /// **'Copy'**
  String get tooltip_copy;

  /// No description provided for @tooltip_delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get tooltip_delete;

  /// No description provided for @tooltip_changeImage.
  ///
  /// In en, this message translates to:
  /// **'Change Image'**
  String get tooltip_changeImage;

  /// No description provided for @tooltip_removeImage.
  ///
  /// In en, this message translates to:
  /// **'Remove Image'**
  String get tooltip_removeImage;

  /// No description provided for @tooltip_previewGenerate.
  ///
  /// In en, this message translates to:
  /// **'Preview Generate'**
  String get tooltip_previewGenerate;

  /// No description provided for @tooltip_help.
  ///
  /// In en, this message translates to:
  /// **'Help'**
  String get tooltip_help;

  /// No description provided for @tooltip_addConfigGroup.
  ///
  /// In en, this message translates to:
  /// **'Add Config Group'**
  String get tooltip_addConfigGroup;

  /// No description provided for @tooltip_enable.
  ///
  /// In en, this message translates to:
  /// **'Enable'**
  String get tooltip_enable;

  /// No description provided for @tooltip_disable.
  ///
  /// In en, this message translates to:
  /// **'Disable'**
  String get tooltip_disable;

  /// No description provided for @tooltip_resetWeight.
  ///
  /// In en, this message translates to:
  /// **'Click to reset to 100%'**
  String get tooltip_resetWeight;

  /// No description provided for @upscale_title.
  ///
  /// In en, this message translates to:
  /// **'Image Upscale'**
  String get upscale_title;

  /// No description provided for @upscale_close.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get upscale_close;

  /// No description provided for @upscale_start.
  ///
  /// In en, this message translates to:
  /// **'Start Upscale'**
  String get upscale_start;

  /// No description provided for @upscale_sourceImage.
  ///
  /// In en, this message translates to:
  /// **'Source Image'**
  String get upscale_sourceImage;

  /// No description provided for @upscale_clickToSelect.
  ///
  /// In en, this message translates to:
  /// **'Click to select image to upscale'**
  String get upscale_clickToSelect;

  /// No description provided for @upscale_scale.
  ///
  /// In en, this message translates to:
  /// **'Scale Factor'**
  String get upscale_scale;

  /// No description provided for @upscale_2xHint.
  ///
  /// In en, this message translates to:
  /// **'Upscale to 2x original size (recommended)'**
  String get upscale_2xHint;

  /// No description provided for @upscale_4xHint.
  ///
  /// In en, this message translates to:
  /// **'Upscale to 4x original size (costs more Anlas)'**
  String get upscale_4xHint;

  /// No description provided for @upscale_processing.
  ///
  /// In en, this message translates to:
  /// **'Upscaling image...'**
  String get upscale_processing;

  /// No description provided for @upscale_complete.
  ///
  /// In en, this message translates to:
  /// **'Upscale Complete'**
  String get upscale_complete;

  /// No description provided for @upscale_save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get upscale_save;

  /// No description provided for @upscale_share.
  ///
  /// In en, this message translates to:
  /// **'Share'**
  String get upscale_share;

  /// No description provided for @upscale_failed.
  ///
  /// In en, this message translates to:
  /// **'Upscale failed'**
  String get upscale_failed;

  /// No description provided for @upscale_selectFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to select image: {error}'**
  String upscale_selectFailed(Object error);

  /// No description provided for @upscale_savedTo.
  ///
  /// In en, this message translates to:
  /// **'Saved to: {path}'**
  String upscale_savedTo(Object path);

  /// No description provided for @upscale_saveFailed.
  ///
  /// In en, this message translates to:
  /// **'Save failed: {error}'**
  String upscale_saveFailed(Object error);

  /// No description provided for @upscale_shareFailed.
  ///
  /// In en, this message translates to:
  /// **'Share failed: {error}'**
  String upscale_shareFailed(Object error);

  /// No description provided for @danbooru_loginTitle.
  ///
  /// In en, this message translates to:
  /// **'Login Danbooru'**
  String get danbooru_loginTitle;

  /// No description provided for @danbooru_loginHint.
  ///
  /// In en, this message translates to:
  /// **'Login with username and API Key to use favorites'**
  String get danbooru_loginHint;

  /// No description provided for @danbooru_username.
  ///
  /// In en, this message translates to:
  /// **'Username'**
  String get danbooru_username;

  /// No description provided for @danbooru_usernameHint.
  ///
  /// In en, this message translates to:
  /// **'Enter Danbooru username'**
  String get danbooru_usernameHint;

  /// No description provided for @danbooru_usernameRequired.
  ///
  /// In en, this message translates to:
  /// **'Please enter username'**
  String get danbooru_usernameRequired;

  /// No description provided for @danbooru_apiKeyHint.
  ///
  /// In en, this message translates to:
  /// **'Enter API Key'**
  String get danbooru_apiKeyHint;

  /// No description provided for @danbooru_apiKeyRequired.
  ///
  /// In en, this message translates to:
  /// **'Please enter API Key'**
  String get danbooru_apiKeyRequired;

  /// No description provided for @danbooru_howToGetApiKey.
  ///
  /// In en, this message translates to:
  /// **'How to get API Key?'**
  String get danbooru_howToGetApiKey;

  /// No description provided for @danbooru_loginSuccess.
  ///
  /// In en, this message translates to:
  /// **'Login successful'**
  String get danbooru_loginSuccess;

  /// No description provided for @weight_title.
  ///
  /// In en, this message translates to:
  /// **'Weight'**
  String get weight_title;

  /// No description provided for @weight_reset.
  ///
  /// In en, this message translates to:
  /// **'Reset'**
  String get weight_reset;

  /// No description provided for @weight_done.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get weight_done;

  /// No description provided for @weight_noBrackets.
  ///
  /// In en, this message translates to:
  /// **'No brackets'**
  String get weight_noBrackets;

  /// No description provided for @weight_editTag.
  ///
  /// In en, this message translates to:
  /// **'Edit Tag'**
  String get weight_editTag;

  /// No description provided for @weight_tagName.
  ///
  /// In en, this message translates to:
  /// **'Tag Name'**
  String get weight_tagName;

  /// No description provided for @weight_tagNameHint.
  ///
  /// In en, this message translates to:
  /// **'Enter tag name...'**
  String get weight_tagNameHint;

  /// No description provided for @tag_selected.
  ///
  /// In en, this message translates to:
  /// **'Selected {count}'**
  String tag_selected(Object count);

  /// No description provided for @tag_enable.
  ///
  /// In en, this message translates to:
  /// **'Enable'**
  String get tag_enable;

  /// No description provided for @tag_disable.
  ///
  /// In en, this message translates to:
  /// **'Disable'**
  String get tag_disable;

  /// No description provided for @tag_delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get tag_delete;

  /// No description provided for @tag_addTag.
  ///
  /// In en, this message translates to:
  /// **'Add Tag'**
  String get tag_addTag;

  /// No description provided for @tag_add.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get tag_add;

  /// No description provided for @tag_inputHint.
  ///
  /// In en, this message translates to:
  /// **'Enter tag...'**
  String get tag_inputHint;

  /// No description provided for @tag_copiedToClipboard.
  ///
  /// In en, this message translates to:
  /// **'Copied to clipboard'**
  String get tag_copiedToClipboard;

  /// No description provided for @tag_emptyHint.
  ///
  /// In en, this message translates to:
  /// **'Add tags to describe your desired image'**
  String get tag_emptyHint;

  /// No description provided for @tag_emptyHintSub.
  ///
  /// In en, this message translates to:
  /// **'You can browse, search, or add tags manually'**
  String get tag_emptyHintSub;

  /// No description provided for @tagCategory_artist.
  ///
  /// In en, this message translates to:
  /// **'Artist'**
  String get tagCategory_artist;

  /// No description provided for @tagCategory_copyright.
  ///
  /// In en, this message translates to:
  /// **'Copyright'**
  String get tagCategory_copyright;

  /// No description provided for @tagCategory_character.
  ///
  /// In en, this message translates to:
  /// **'Character'**
  String get tagCategory_character;

  /// No description provided for @tagCategory_meta.
  ///
  /// In en, this message translates to:
  /// **'Meta'**
  String get tagCategory_meta;

  /// No description provided for @tagCategory_general.
  ///
  /// In en, this message translates to:
  /// **'General'**
  String get tagCategory_general;

  /// No description provided for @configEditor_newConfigGroup.
  ///
  /// In en, this message translates to:
  /// **'New Config Group'**
  String get configEditor_newConfigGroup;

  /// No description provided for @configEditor_editConfigGroup.
  ///
  /// In en, this message translates to:
  /// **'Edit Config Group'**
  String get configEditor_editConfigGroup;

  /// No description provided for @configEditor_configName.
  ///
  /// In en, this message translates to:
  /// **'Config Name'**
  String get configEditor_configName;

  /// No description provided for @configEditor_enableConfig.
  ///
  /// In en, this message translates to:
  /// **'Enable this config'**
  String get configEditor_enableConfig;

  /// No description provided for @configEditor_enableConfigHint.
  ///
  /// In en, this message translates to:
  /// **'Disabled configs won\'t participate in generation'**
  String get configEditor_enableConfigHint;

  /// No description provided for @configEditor_contentType.
  ///
  /// In en, this message translates to:
  /// **'Content Type'**
  String get configEditor_contentType;

  /// No description provided for @configEditor_tagList.
  ///
  /// In en, this message translates to:
  /// **'Tag List'**
  String get configEditor_tagList;

  /// No description provided for @configEditor_nestedConfig.
  ///
  /// In en, this message translates to:
  /// **'Nested Config'**
  String get configEditor_nestedConfig;

  /// No description provided for @configEditor_selectionMode.
  ///
  /// In en, this message translates to:
  /// **'Selection Mode'**
  String get configEditor_selectionMode;

  /// No description provided for @configEditor_selectCount.
  ///
  /// In en, this message translates to:
  /// **'Select Count:'**
  String get configEditor_selectCount;

  /// No description provided for @configEditor_selectProbability.
  ///
  /// In en, this message translates to:
  /// **'Select Probability:'**
  String get configEditor_selectProbability;

  /// No description provided for @configEditor_shuffleOrder.
  ///
  /// In en, this message translates to:
  /// **'Shuffle Order'**
  String get configEditor_shuffleOrder;

  /// No description provided for @configEditor_shuffleOrderHint.
  ///
  /// In en, this message translates to:
  /// **'Randomly arrange selected content'**
  String get configEditor_shuffleOrderHint;

  /// No description provided for @configEditor_weightBrackets.
  ///
  /// In en, this message translates to:
  /// **'Weight Brackets'**
  String get configEditor_weightBrackets;

  /// No description provided for @configEditor_weightBracketsHint.
  ///
  /// In en, this message translates to:
  /// **'Brackets increase weight, each curly bracket adds ~5%'**
  String get configEditor_weightBracketsHint;

  /// No description provided for @configEditor_minBrackets.
  ///
  /// In en, this message translates to:
  /// **'Min Brackets: {count}'**
  String configEditor_minBrackets(Object count);

  /// No description provided for @configEditor_maxBrackets.
  ///
  /// In en, this message translates to:
  /// **'Max Brackets: {count}'**
  String configEditor_maxBrackets(Object count);

  /// No description provided for @configEditor_effectPreview.
  ///
  /// In en, this message translates to:
  /// **'Effect Preview:'**
  String get configEditor_effectPreview;

  /// No description provided for @configEditor_content.
  ///
  /// In en, this message translates to:
  /// **'Content'**
  String get configEditor_content;

  /// No description provided for @configEditor_tagCountHint.
  ///
  /// In en, this message translates to:
  /// **'One tag per line, currently {count} items'**
  String configEditor_tagCountHint(Object count);

  /// No description provided for @configEditor_format.
  ///
  /// In en, this message translates to:
  /// **'Format'**
  String get configEditor_format;

  /// No description provided for @configEditor_sort.
  ///
  /// In en, this message translates to:
  /// **'Sort'**
  String get configEditor_sort;

  /// No description provided for @configEditor_dedupe.
  ///
  /// In en, this message translates to:
  /// **'Dedupe'**
  String get configEditor_dedupe;

  /// No description provided for @configEditor_nestedConfigHint.
  ///
  /// In en, this message translates to:
  /// **'Nested configs create complex layered random logic'**
  String get configEditor_nestedConfigHint;

  /// No description provided for @configEditor_noNestedConfig.
  ///
  /// In en, this message translates to:
  /// **'No nested configs yet'**
  String get configEditor_noNestedConfig;

  /// No description provided for @configEditor_itemCount.
  ///
  /// In en, this message translates to:
  /// **'{count} items'**
  String configEditor_itemCount(Object count);

  /// No description provided for @configEditor_subConfigCount.
  ///
  /// In en, this message translates to:
  /// **'{count} sub-configs'**
  String configEditor_subConfigCount(Object count);

  /// No description provided for @configEditor_addNestedConfig.
  ///
  /// In en, this message translates to:
  /// **'Add Nested Config'**
  String get configEditor_addNestedConfig;

  /// No description provided for @configEditor_subConfig.
  ///
  /// In en, this message translates to:
  /// **'Sub-config'**
  String get configEditor_subConfig;

  /// No description provided for @configEditor_singleRandom.
  ///
  /// In en, this message translates to:
  /// **'Single - Random'**
  String get configEditor_singleRandom;

  /// No description provided for @configEditor_singleSequential.
  ///
  /// In en, this message translates to:
  /// **'Single - Sequential'**
  String get configEditor_singleSequential;

  /// No description provided for @configEditor_singleProbability.
  ///
  /// In en, this message translates to:
  /// **'Single - Probability'**
  String get configEditor_singleProbability;

  /// No description provided for @configEditor_multipleCount.
  ///
  /// In en, this message translates to:
  /// **'Multiple - Count'**
  String get configEditor_multipleCount;

  /// No description provided for @configEditor_multipleProbability.
  ///
  /// In en, this message translates to:
  /// **'Multiple - Probability'**
  String get configEditor_multipleProbability;

  /// No description provided for @configEditor_selectAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get configEditor_selectAll;

  /// No description provided for @configEditor_singleRandomHint.
  ///
  /// In en, this message translates to:
  /// **'Randomly select one item each time'**
  String get configEditor_singleRandomHint;

  /// No description provided for @configEditor_singleSequentialHint.
  ///
  /// In en, this message translates to:
  /// **'Cycle through items in order'**
  String get configEditor_singleSequentialHint;

  /// No description provided for @configEditor_singleProbabilityHint.
  ///
  /// In en, this message translates to:
  /// **'X% chance to randomly select one, otherwise skip'**
  String get configEditor_singleProbabilityHint;

  /// No description provided for @configEditor_multipleCountHint.
  ///
  /// In en, this message translates to:
  /// **'Randomly select specified number of items'**
  String get configEditor_multipleCountHint;

  /// No description provided for @configEditor_multipleProbabilityHint.
  ///
  /// In en, this message translates to:
  /// **'Each item selected by probability'**
  String get configEditor_multipleProbabilityHint;

  /// No description provided for @configEditor_selectAllHint.
  ///
  /// In en, this message translates to:
  /// **'Select all items'**
  String get configEditor_selectAllHint;

  /// No description provided for @configEditor_or.
  ///
  /// In en, this message translates to:
  /// **' or '**
  String get configEditor_or;

  /// No description provided for @configEditor_enterConfigName.
  ///
  /// In en, this message translates to:
  /// **'Please enter config name'**
  String get configEditor_enterConfigName;

  /// No description provided for @configEditor_continueEditing.
  ///
  /// In en, this message translates to:
  /// **'Continue Editing'**
  String get configEditor_continueEditing;

  /// No description provided for @configEditor_discardChanges.
  ///
  /// In en, this message translates to:
  /// **'Discard Changes'**
  String get configEditor_discardChanges;

  /// No description provided for @configEditor_randomCount.
  ///
  /// In en, this message translates to:
  /// **'Random {count}'**
  String configEditor_randomCount(Object count);

  /// No description provided for @configEditor_probabilityPercent.
  ///
  /// In en, this message translates to:
  /// **'{percent}% probability'**
  String configEditor_probabilityPercent(Object percent);

  /// No description provided for @presetEdit_newPreset.
  ///
  /// In en, this message translates to:
  /// **'New Preset'**
  String get presetEdit_newPreset;

  /// No description provided for @presetEdit_editPreset.
  ///
  /// In en, this message translates to:
  /// **'Edit Preset'**
  String get presetEdit_editPreset;

  /// No description provided for @presetEdit_presetName.
  ///
  /// In en, this message translates to:
  /// **'Preset Name'**
  String get presetEdit_presetName;

  /// No description provided for @presetEdit_configGroups.
  ///
  /// In en, this message translates to:
  /// **'Config Groups ({count})'**
  String presetEdit_configGroups(Object count);

  /// No description provided for @presetEdit_noConfigGroups.
  ///
  /// In en, this message translates to:
  /// **'No config groups yet'**
  String get presetEdit_noConfigGroups;

  /// No description provided for @presetEdit_addConfigGroupHint.
  ///
  /// In en, this message translates to:
  /// **'Click + in top right to add config group'**
  String get presetEdit_addConfigGroupHint;

  /// No description provided for @presetEdit_addConfigGroup.
  ///
  /// In en, this message translates to:
  /// **'Add Config Group'**
  String get presetEdit_addConfigGroup;

  /// No description provided for @presetEdit_newConfigGroup.
  ///
  /// In en, this message translates to:
  /// **'New Config Group'**
  String get presetEdit_newConfigGroup;

  /// No description provided for @presetEdit_enterPresetName.
  ///
  /// In en, this message translates to:
  /// **'Please enter preset name'**
  String get presetEdit_enterPresetName;

  /// No description provided for @presetEdit_saveSuccess.
  ///
  /// In en, this message translates to:
  /// **'Saved successfully'**
  String get presetEdit_saveSuccess;

  /// No description provided for @presetEdit_saveError.
  ///
  /// In en, this message translates to:
  /// **'Failed to save preset'**
  String get presetEdit_saveError;

  /// No description provided for @presetEdit_deleteConfigConfirm.
  ///
  /// In en, this message translates to:
  /// **'Delete config group \"{name}\"?'**
  String presetEdit_deleteConfigConfirm(Object name);

  /// No description provided for @presetEdit_previewTitle.
  ///
  /// In en, this message translates to:
  /// **'Preview Generation Result'**
  String get presetEdit_previewTitle;

  /// No description provided for @presetEdit_emptyResult.
  ///
  /// In en, this message translates to:
  /// **'(Empty result, please check config)'**
  String get presetEdit_emptyResult;

  /// No description provided for @presetEdit_regenerate.
  ///
  /// In en, this message translates to:
  /// **'Regenerate'**
  String get presetEdit_regenerate;

  /// No description provided for @presetEdit_helpTitle.
  ///
  /// In en, this message translates to:
  /// **'Help'**
  String get presetEdit_helpTitle;

  /// No description provided for @presetEdit_helpConfigGroup.
  ///
  /// In en, this message translates to:
  /// **'Config Group Description'**
  String get presetEdit_helpConfigGroup;

  /// No description provided for @presetEdit_helpConfigGroupContent.
  ///
  /// In en, this message translates to:
  /// **'Each config group generates content in order, final result is joined by commas.'**
  String get presetEdit_helpConfigGroupContent;

  /// No description provided for @presetEdit_helpSelectionMode.
  ///
  /// In en, this message translates to:
  /// **'Selection Mode'**
  String get presetEdit_helpSelectionMode;

  /// No description provided for @presetEdit_helpSingleRandom.
  ///
  /// In en, this message translates to:
  /// **'• Single-Random: Randomly select one item'**
  String get presetEdit_helpSingleRandom;

  /// No description provided for @presetEdit_helpSingleSequential.
  ///
  /// In en, this message translates to:
  /// **'• Single-Sequential: Cycle through in order'**
  String get presetEdit_helpSingleSequential;

  /// No description provided for @presetEdit_helpMultipleCount.
  ///
  /// In en, this message translates to:
  /// **'• Multiple-Count: Randomly select specified count'**
  String get presetEdit_helpMultipleCount;

  /// No description provided for @presetEdit_helpMultipleProbability.
  ///
  /// In en, this message translates to:
  /// **'• Multiple-Probability: Each item selected independently by probability'**
  String get presetEdit_helpMultipleProbability;

  /// No description provided for @presetEdit_helpAll.
  ///
  /// In en, this message translates to:
  /// **'• All: Select all items'**
  String get presetEdit_helpAll;

  /// No description provided for @presetEdit_helpWeightBrackets.
  ///
  /// In en, this message translates to:
  /// **'Weight Brackets'**
  String get presetEdit_helpWeightBrackets;

  /// No description provided for @presetEdit_helpWeightBracketsContent.
  ///
  /// In en, this message translates to:
  /// **'Curly brackets increase weight, more brackets = higher weight.'**
  String get presetEdit_helpWeightBracketsContent;

  /// No description provided for @presetEdit_helpWeightBracketsExample.
  ///
  /// In en, this message translates to:
  /// **'Example: one bracket is 1.05x weight, two brackets is 1.1x.'**
  String get presetEdit_helpWeightBracketsExample;

  /// No description provided for @presetEdit_helpNestedConfig.
  ///
  /// In en, this message translates to:
  /// **'Nested Config'**
  String get presetEdit_helpNestedConfig;

  /// No description provided for @presetEdit_helpNestedConfigContent.
  ///
  /// In en, this message translates to:
  /// **'Configs can be nested for complex layered random logic.'**
  String get presetEdit_helpNestedConfigContent;

  /// No description provided for @presetEdit_gotIt.
  ///
  /// In en, this message translates to:
  /// **'Got it'**
  String get presetEdit_gotIt;

  /// No description provided for @presetEdit_tagCount.
  ///
  /// In en, this message translates to:
  /// **'{count} tags'**
  String presetEdit_tagCount(Object count);

  /// No description provided for @presetEdit_bracketLayers.
  ///
  /// In en, this message translates to:
  /// **'{count} bracket layers'**
  String presetEdit_bracketLayers(Object count);

  /// No description provided for @presetEdit_bracketRange.
  ///
  /// In en, this message translates to:
  /// **'{min}-{max} bracket layers'**
  String presetEdit_bracketRange(Object min, Object max);

  /// No description provided for @qualityTags_label.
  ///
  /// In en, this message translates to:
  /// **'Quality'**
  String get qualityTags_label;

  /// No description provided for @qualityTags_positive.
  ///
  /// In en, this message translates to:
  /// **'Quality (Positive)'**
  String get qualityTags_positive;

  /// No description provided for @qualityTags_negative.
  ///
  /// In en, this message translates to:
  /// **'Quality (Negative)'**
  String get qualityTags_negative;

  /// No description provided for @qualityTags_disabled.
  ///
  /// In en, this message translates to:
  /// **'Quality tags disabled\nClick to enable'**
  String get qualityTags_disabled;

  /// No description provided for @qualityTags_addToEnd.
  ///
  /// In en, this message translates to:
  /// **'Add to prompt end:'**
  String get qualityTags_addToEnd;

  /// No description provided for @qualityTags_naiDefault.
  ///
  /// In en, this message translates to:
  /// **'NAI Default'**
  String get qualityTags_naiDefault;

  /// No description provided for @qualityTags_none.
  ///
  /// In en, this message translates to:
  /// **'None'**
  String get qualityTags_none;

  /// No description provided for @qualityTags_addFromLibrary.
  ///
  /// In en, this message translates to:
  /// **'Add from Library'**
  String get qualityTags_addFromLibrary;

  /// No description provided for @qualityTags_selectFromLibrary.
  ///
  /// In en, this message translates to:
  /// **'Select Quality Tag Entry'**
  String get qualityTags_selectFromLibrary;

  /// No description provided for @ucPreset_label.
  ///
  /// In en, this message translates to:
  /// **'UC Preset'**
  String get ucPreset_label;

  /// No description provided for @ucPreset_heavy.
  ///
  /// In en, this message translates to:
  /// **'Heavy'**
  String get ucPreset_heavy;

  /// No description provided for @ucPreset_light.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get ucPreset_light;

  /// No description provided for @ucPreset_furryFocus.
  ///
  /// In en, this message translates to:
  /// **'Furry'**
  String get ucPreset_furryFocus;

  /// No description provided for @ucPreset_humanFocus.
  ///
  /// In en, this message translates to:
  /// **'Human'**
  String get ucPreset_humanFocus;

  /// No description provided for @ucPreset_none.
  ///
  /// In en, this message translates to:
  /// **'None'**
  String get ucPreset_none;

  /// No description provided for @ucPreset_custom.
  ///
  /// In en, this message translates to:
  /// **'Custom'**
  String get ucPreset_custom;

  /// No description provided for @ucPreset_disabled.
  ///
  /// In en, this message translates to:
  /// **'Undesired content preset disabled'**
  String get ucPreset_disabled;

  /// No description provided for @ucPreset_addToNegative.
  ///
  /// In en, this message translates to:
  /// **'Add to negative prompt:'**
  String get ucPreset_addToNegative;

  /// No description provided for @ucPreset_nsfwHint.
  ///
  /// In en, this message translates to:
  /// **'💡 To generate adult content, add nsfw to your positive prompt. The nsfw tag will be auto-removed from negative prompt'**
  String get ucPreset_nsfwHint;

  /// No description provided for @ucPreset_addFromLibrary.
  ///
  /// In en, this message translates to:
  /// **'Add from Library'**
  String get ucPreset_addFromLibrary;

  /// No description provided for @ucPreset_selectFromLibrary.
  ///
  /// In en, this message translates to:
  /// **'Select UC Entry'**
  String get ucPreset_selectFromLibrary;

  /// No description provided for @randomMode_enabledTip.
  ///
  /// In en, this message translates to:
  /// **'Random mode enabled\nAuto-randomize prompt after each generation'**
  String get randomMode_enabledTip;

  /// No description provided for @randomMode_disabledTip.
  ///
  /// In en, this message translates to:
  /// **'Random mode\nClick to auto-randomize prompts on generation'**
  String get randomMode_disabledTip;

  /// No description provided for @batchSize_title.
  ///
  /// In en, this message translates to:
  /// **'Batch Size'**
  String get batchSize_title;

  /// No description provided for @batchSize_tooltip.
  ///
  /// In en, this message translates to:
  /// **'{count} images per request'**
  String batchSize_tooltip(int count);

  /// No description provided for @batchSize_description.
  ///
  /// In en, this message translates to:
  /// **'Number of images per API request'**
  String get batchSize_description;

  /// No description provided for @batchSize_formula.
  ///
  /// In en, this message translates to:
  /// **'Total images = {batchCount} × {batchSize} = {total}'**
  String batchSize_formula(int batchCount, int batchSize, int total);

  /// No description provided for @batchSize_hint.
  ///
  /// In en, this message translates to:
  /// **'Larger batch = fewer requests, but longer wait per request'**
  String get batchSize_hint;

  /// No description provided for @batchSize_costWarning.
  ///
  /// In en, this message translates to:
  /// **'⚠️ Batch size > 1 costs extra Anlas'**
  String get batchSize_costWarning;

  /// No description provided for @font_systemDefault.
  ///
  /// In en, this message translates to:
  /// **'System Default'**
  String get font_systemDefault;

  /// No description provided for @font_sourceHanSans.
  ///
  /// In en, this message translates to:
  /// **'Source Han Sans'**
  String get font_sourceHanSans;

  /// No description provided for @font_sourceHanSerif.
  ///
  /// In en, this message translates to:
  /// **'Source Han Serif'**
  String get font_sourceHanSerif;

  /// No description provided for @font_sourceHanSansHK.
  ///
  /// In en, this message translates to:
  /// **'Source Han Sans HK'**
  String get font_sourceHanSansHK;

  /// No description provided for @font_sourceHanMono.
  ///
  /// In en, this message translates to:
  /// **'Source Han Mono'**
  String get font_sourceHanMono;

  /// No description provided for @font_zcoolXiaowei.
  ///
  /// In en, this message translates to:
  /// **'ZCOOL Xiaowei'**
  String get font_zcoolXiaowei;

  /// No description provided for @font_zcoolKuaile.
  ///
  /// In en, this message translates to:
  /// **'ZCOOL Kuaile'**
  String get font_zcoolKuaile;

  /// No description provided for @font_mashan.
  ///
  /// In en, this message translates to:
  /// **'Ma Shan Zheng'**
  String get font_mashan;

  /// No description provided for @font_longcang.
  ///
  /// In en, this message translates to:
  /// **'Long Cang'**
  String get font_longcang;

  /// No description provided for @font_liujian.
  ///
  /// In en, this message translates to:
  /// **'Liu Jian Mao Cao'**
  String get font_liujian;

  /// No description provided for @font_zhimang.
  ///
  /// In en, this message translates to:
  /// **'Zhi Mang Xing'**
  String get font_zhimang;

  /// No description provided for @font_codeFont.
  ///
  /// In en, this message translates to:
  /// **'Code Font'**
  String get font_codeFont;

  /// No description provided for @font_modernNarrow.
  ///
  /// In en, this message translates to:
  /// **'Modern Narrow'**
  String get font_modernNarrow;

  /// No description provided for @font_classicSerif.
  ///
  /// In en, this message translates to:
  /// **'Classic Serif'**
  String get font_classicSerif;

  /// No description provided for @font_sciFi.
  ///
  /// In en, this message translates to:
  /// **'Sci-Fi'**
  String get font_sciFi;

  /// No description provided for @font_techStyle.
  ///
  /// In en, this message translates to:
  /// **'Tech Style'**
  String get font_techStyle;

  /// No description provided for @font_systemFonts.
  ///
  /// In en, this message translates to:
  /// **'System Fonts'**
  String get font_systemFonts;

  /// No description provided for @download_tagsData.
  ///
  /// In en, this message translates to:
  /// **'Tags Data'**
  String get download_tagsData;

  /// No description provided for @download_cooccurrenceData.
  ///
  /// In en, this message translates to:
  /// **'Co-occurrence Tags Data'**
  String get download_cooccurrenceData;

  /// No description provided for @download_failed.
  ///
  /// In en, this message translates to:
  /// **'{name} download failed'**
  String download_failed(Object name);

  /// No description provided for @download_downloading.
  ///
  /// In en, this message translates to:
  /// **'Downloading {name}'**
  String download_downloading(Object name);

  /// No description provided for @download_complete.
  ///
  /// In en, this message translates to:
  /// **'{name} download complete'**
  String download_complete(Object name);

  /// No description provided for @download_downloadFailed.
  ///
  /// In en, this message translates to:
  /// **'{name} download failed'**
  String download_downloadFailed(Object name);

  /// No description provided for @warmup_networkCheck.
  ///
  /// In en, this message translates to:
  /// **'Checking network connection...'**
  String get warmup_networkCheck;

  /// No description provided for @warmup_networkCheck_noProxy.
  ///
  /// In en, this message translates to:
  /// **'Cannot connect to NovelAI, please enable VPN or proxy settings'**
  String get warmup_networkCheck_noProxy;

  /// No description provided for @warmup_networkCheck_noSystemProxy.
  ///
  /// In en, this message translates to:
  /// **'Proxy enabled but no system proxy detected, please enable VPN'**
  String get warmup_networkCheck_noSystemProxy;

  /// No description provided for @warmup_networkCheck_manualIncomplete.
  ///
  /// In en, this message translates to:
  /// **'Manual proxy config incomplete, please check settings'**
  String get warmup_networkCheck_manualIncomplete;

  /// No description provided for @warmup_networkCheck_testing.
  ///
  /// In en, this message translates to:
  /// **'Testing network connection...'**
  String get warmup_networkCheck_testing;

  /// No description provided for @warmup_networkCheck_testingProxy.
  ///
  /// In en, this message translates to:
  /// **'Testing network via proxy...'**
  String get warmup_networkCheck_testingProxy;

  /// No description provided for @warmup_networkCheck_failed.
  ///
  /// In en, this message translates to:
  /// **'Network connection failed: {error}, please check VPN'**
  String warmup_networkCheck_failed(Object error);

  /// No description provided for @warmup_networkCheck_success.
  ///
  /// In en, this message translates to:
  /// **'Network connection OK ({latency}ms)'**
  String warmup_networkCheck_success(Object latency);

  /// No description provided for @warmup_preparing.
  ///
  /// In en, this message translates to:
  /// **'Preparing...'**
  String get warmup_preparing;

  /// No description provided for @warmup_complete.
  ///
  /// In en, this message translates to:
  /// **'Complete'**
  String get warmup_complete;

  /// No description provided for @warmup_danbooruAuth.
  ///
  /// In en, this message translates to:
  /// **'Initializing Danbooru authentication...'**
  String get warmup_danbooruAuth;

  /// No description provided for @warmup_loadingTranslation.
  ///
  /// In en, this message translates to:
  /// **'Loading translation data...'**
  String get warmup_loadingTranslation;

  /// No description provided for @warmup_initTagSystem.
  ///
  /// In en, this message translates to:
  /// **'Initializing tag system...'**
  String get warmup_initTagSystem;

  /// No description provided for @warmup_loadingPromptConfig.
  ///
  /// In en, this message translates to:
  /// **'Loading prompt config...'**
  String get warmup_loadingPromptConfig;

  /// No description provided for @warmup_imageEditor.
  ///
  /// In en, this message translates to:
  /// **'Initializing image editor...'**
  String get warmup_imageEditor;

  /// No description provided for @warmup_database.
  ///
  /// In en, this message translates to:
  /// **'Loading recent history...'**
  String get warmup_database;

  /// No description provided for @warmup_network.
  ///
  /// In en, this message translates to:
  /// **'Checking network connection...'**
  String get warmup_network;

  /// No description provided for @warmup_fonts.
  ///
  /// In en, this message translates to:
  /// **'Preloading fonts...'**
  String get warmup_fonts;

  /// No description provided for @warmup_imageCache.
  ///
  /// In en, this message translates to:
  /// **'Warming up image cache...'**
  String get warmup_imageCache;

  /// No description provided for @warmup_statistics.
  ///
  /// In en, this message translates to:
  /// **'Loading statistics...'**
  String get warmup_statistics;

  /// No description provided for @warmup_artistsSync.
  ///
  /// In en, this message translates to:
  /// **'Syncing artists data...'**
  String get warmup_artistsSync;

  /// No description provided for @warmup_subscription.
  ///
  /// In en, this message translates to:
  /// **'Loading subscription info...'**
  String get warmup_subscription;

  /// No description provided for @warmup_dataSourceCache.
  ///
  /// In en, this message translates to:
  /// **'Initializing data source cache...'**
  String get warmup_dataSourceCache;

  /// No description provided for @warmup_galleryFileCount.
  ///
  /// In en, this message translates to:
  /// **'Scanning gallery files...'**
  String get warmup_galleryFileCount;

  /// No description provided for @warmup_cooccurrenceData.
  ///
  /// In en, this message translates to:
  /// **'Loading tag cooccurrence data...'**
  String get warmup_cooccurrenceData;

  /// No description provided for @warmup_retryFailed.
  ///
  /// In en, this message translates to:
  /// **'Retry Failed Tasks'**
  String get warmup_retryFailed;

  /// No description provided for @warmup_errorDetail.
  ///
  /// In en, this message translates to:
  /// **'Error'**
  String get warmup_errorDetail;

  /// No description provided for @warmup_group_basicUI.
  ///
  /// In en, this message translates to:
  /// **'Initializing basic UI services...'**
  String get warmup_group_basicUI;

  /// No description provided for @warmup_group_basicUI_complete.
  ///
  /// In en, this message translates to:
  /// **'Basic UI services ready'**
  String get warmup_group_basicUI_complete;

  /// No description provided for @warmup_group_dataServices.
  ///
  /// In en, this message translates to:
  /// **'Initializing data services...'**
  String get warmup_group_dataServices;

  /// No description provided for @warmup_group_dataServices_complete.
  ///
  /// In en, this message translates to:
  /// **'Data services ready'**
  String get warmup_group_dataServices_complete;

  /// No description provided for @warmup_group_networkServices.
  ///
  /// In en, this message translates to:
  /// **'Initializing network services...'**
  String get warmup_group_networkServices;

  /// No description provided for @warmup_group_networkServices_complete.
  ///
  /// In en, this message translates to:
  /// **'Network services ready'**
  String get warmup_group_networkServices_complete;

  /// No description provided for @warmup_group_cacheServices.
  ///
  /// In en, this message translates to:
  /// **'Initializing cache services...'**
  String get warmup_group_cacheServices;

  /// No description provided for @warmup_group_cacheServices_complete.
  ///
  /// In en, this message translates to:
  /// **'Cache services ready'**
  String get warmup_group_cacheServices_complete;

  /// No description provided for @warmup_cooccurrenceInit.
  ///
  /// In en, this message translates to:
  /// **'Initializing cooccurrence data...'**
  String get warmup_cooccurrenceInit;

  /// No description provided for @warmup_translationInit.
  ///
  /// In en, this message translates to:
  /// **'Initializing translation data...'**
  String get warmup_translationInit;

  /// No description provided for @warmup_danbooruTagsInit.
  ///
  /// In en, this message translates to:
  /// **'Initializing Danbooru tags...'**
  String get warmup_danbooruTagsInit;

  /// No description provided for @warmup_group_dataSourceInitialization.
  ///
  /// In en, this message translates to:
  /// **'Initializing data source services...'**
  String get warmup_group_dataSourceInitialization;

  /// No description provided for @warmup_group_dataSourceInitialization_complete.
  ///
  /// In en, this message translates to:
  /// **'Data source services ready'**
  String get warmup_group_dataSourceInitialization_complete;

  /// No description provided for @performanceReport_title.
  ///
  /// In en, this message translates to:
  /// **'Startup Performance'**
  String get performanceReport_title;

  /// No description provided for @performanceReport_export.
  ///
  /// In en, this message translates to:
  /// **'Export Report'**
  String get performanceReport_export;

  /// No description provided for @performanceReport_taskStats.
  ///
  /// In en, this message translates to:
  /// **'Task Statistics'**
  String get performanceReport_taskStats;

  /// No description provided for @performanceReport_averageDuration.
  ///
  /// In en, this message translates to:
  /// **'Average Duration'**
  String get performanceReport_averageDuration;

  /// No description provided for @performanceReport_successRate.
  ///
  /// In en, this message translates to:
  /// **'Success Rate'**
  String get performanceReport_successRate;

  /// No description provided for @performanceReport_exportSuccess.
  ///
  /// In en, this message translates to:
  /// **'Report exported successfully'**
  String get performanceReport_exportSuccess;

  /// No description provided for @copyName.
  ///
  /// In en, this message translates to:
  /// **' (Copy)'**
  String get copyName;

  /// No description provided for @defaultPreset_name.
  ///
  /// In en, this message translates to:
  /// **'Default Preset'**
  String get defaultPreset_name;

  /// No description provided for @defaultPreset_quality.
  ///
  /// In en, this message translates to:
  /// **'Quality'**
  String get defaultPreset_quality;

  /// No description provided for @defaultPreset_character.
  ///
  /// In en, this message translates to:
  /// **'Character'**
  String get defaultPreset_character;

  /// No description provided for @defaultPreset_expression.
  ///
  /// In en, this message translates to:
  /// **'Expression'**
  String get defaultPreset_expression;

  /// No description provided for @defaultPreset_clothing.
  ///
  /// In en, this message translates to:
  /// **'Clothing'**
  String get defaultPreset_clothing;

  /// No description provided for @defaultPreset_action.
  ///
  /// In en, this message translates to:
  /// **'Action'**
  String get defaultPreset_action;

  /// No description provided for @defaultPreset_background.
  ///
  /// In en, this message translates to:
  /// **'Background'**
  String get defaultPreset_background;

  /// No description provided for @defaultPreset_shot.
  ///
  /// In en, this message translates to:
  /// **'Shot'**
  String get defaultPreset_shot;

  /// No description provided for @defaultPreset_composition.
  ///
  /// In en, this message translates to:
  /// **'Composition'**
  String get defaultPreset_composition;

  /// No description provided for @defaultPreset_specialStyle.
  ///
  /// In en, this message translates to:
  /// **'Special Style'**
  String get defaultPreset_specialStyle;

  /// No description provided for @resolution_groupNormal.
  ///
  /// In en, this message translates to:
  /// **'NORMAL'**
  String get resolution_groupNormal;

  /// No description provided for @resolution_groupLarge.
  ///
  /// In en, this message translates to:
  /// **'LARGE'**
  String get resolution_groupLarge;

  /// No description provided for @resolution_groupWallpaper.
  ///
  /// In en, this message translates to:
  /// **'WALLPAPER'**
  String get resolution_groupWallpaper;

  /// No description provided for @resolution_groupSmall.
  ///
  /// In en, this message translates to:
  /// **'SMALL'**
  String get resolution_groupSmall;

  /// No description provided for @resolution_groupCustom.
  ///
  /// In en, this message translates to:
  /// **'CUSTOM'**
  String get resolution_groupCustom;

  /// No description provided for @resolution_typePortrait.
  ///
  /// In en, this message translates to:
  /// **'Portrait'**
  String get resolution_typePortrait;

  /// No description provided for @resolution_typeLandscape.
  ///
  /// In en, this message translates to:
  /// **'Landscape'**
  String get resolution_typeLandscape;

  /// No description provided for @resolution_typeSquare.
  ///
  /// In en, this message translates to:
  /// **'Square'**
  String get resolution_typeSquare;

  /// No description provided for @resolution_typeCustom.
  ///
  /// In en, this message translates to:
  /// **'Custom'**
  String get resolution_typeCustom;

  /// No description provided for @resolution_width.
  ///
  /// In en, this message translates to:
  /// **'Width'**
  String get resolution_width;

  /// No description provided for @resolution_height.
  ///
  /// In en, this message translates to:
  /// **'Height'**
  String get resolution_height;

  /// No description provided for @api_error_429.
  ///
  /// In en, this message translates to:
  /// **'Concurrency limit reached'**
  String get api_error_429;

  /// No description provided for @api_error_429_hint.
  ///
  /// In en, this message translates to:
  /// **'Too many requests. Please wait and try again (common with shared accounts)'**
  String get api_error_429_hint;

  /// No description provided for @api_error_401.
  ///
  /// In en, this message translates to:
  /// **'Authentication failed'**
  String get api_error_401;

  /// No description provided for @api_error_401_hint.
  ///
  /// In en, this message translates to:
  /// **'Token invalid or expired. Please login again'**
  String get api_error_401_hint;

  /// No description provided for @api_error_402.
  ///
  /// In en, this message translates to:
  /// **'Insufficient balance'**
  String get api_error_402;

  /// No description provided for @api_error_402_hint.
  ///
  /// In en, this message translates to:
  /// **'Insufficient Anlas. Please top up and try again'**
  String get api_error_402_hint;

  /// No description provided for @api_error_500.
  ///
  /// In en, this message translates to:
  /// **'Server error'**
  String get api_error_500;

  /// No description provided for @api_error_500_hint.
  ///
  /// In en, this message translates to:
  /// **'NovelAI server error. Please try again later'**
  String get api_error_500_hint;

  /// No description provided for @api_error_503.
  ///
  /// In en, this message translates to:
  /// **'Service unavailable'**
  String get api_error_503;

  /// No description provided for @api_error_503_hint.
  ///
  /// In en, this message translates to:
  /// **'Server is under maintenance or overloaded. Please try again later'**
  String get api_error_503_hint;

  /// No description provided for @api_error_timeout.
  ///
  /// In en, this message translates to:
  /// **'Request timeout'**
  String get api_error_timeout;

  /// No description provided for @api_error_timeout_hint.
  ///
  /// In en, this message translates to:
  /// **'Network timeout. Please check your connection and try again'**
  String get api_error_timeout_hint;

  /// No description provided for @api_error_network.
  ///
  /// In en, this message translates to:
  /// **'Network error'**
  String get api_error_network;

  /// No description provided for @api_error_network_hint.
  ///
  /// In en, this message translates to:
  /// **'Cannot connect to server. Please check your network'**
  String get api_error_network_hint;

  /// No description provided for @api_error_unknown.
  ///
  /// In en, this message translates to:
  /// **'Unknown error'**
  String get api_error_unknown;

  /// No description provided for @api_error_unknown_hint.
  ///
  /// In en, this message translates to:
  /// **'Unknown error occurred: {error}'**
  String api_error_unknown_hint(Object error);

  /// No description provided for @drop_dialogTitle.
  ///
  /// In en, this message translates to:
  /// **'What do you want to do with this image?'**
  String get drop_dialogTitle;

  /// No description provided for @drop_hint.
  ///
  /// In en, this message translates to:
  /// **'Drop image here'**
  String get drop_hint;

  /// No description provided for @drop_img2img.
  ///
  /// In en, this message translates to:
  /// **'Image2Image'**
  String get drop_img2img;

  /// No description provided for @drop_vibeTransfer.
  ///
  /// In en, this message translates to:
  /// **'Vibe Transfer'**
  String get drop_vibeTransfer;

  /// No description provided for @drop_characterReference.
  ///
  /// In en, this message translates to:
  /// **'Character Reference'**
  String get drop_characterReference;

  /// No description provided for @drop_unsupportedFormat.
  ///
  /// In en, this message translates to:
  /// **'Unsupported file format'**
  String get drop_unsupportedFormat;

  /// No description provided for @drop_addedToImg2Img.
  ///
  /// In en, this message translates to:
  /// **'Added to Image2Image'**
  String get drop_addedToImg2Img;

  /// No description provided for @drop_addedToVibe.
  ///
  /// In en, this message translates to:
  /// **'Added to Vibe Transfer'**
  String get drop_addedToVibe;

  /// No description provided for @drop_addedMultipleToVibe.
  ///
  /// In en, this message translates to:
  /// **'Added {count} vibe references'**
  String drop_addedMultipleToVibe(int count);

  /// No description provided for @drop_addedToCharacterRef.
  ///
  /// In en, this message translates to:
  /// **'Added to Character Reference'**
  String get drop_addedToCharacterRef;

  /// No description provided for @characterEditor_title.
  ///
  /// In en, this message translates to:
  /// **'Multi-Character Prompts'**
  String get characterEditor_title;

  /// No description provided for @characterEditor_close.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get characterEditor_close;

  /// No description provided for @characterEditor_confirm.
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get characterEditor_confirm;

  /// No description provided for @characterEditor_clearAll.
  ///
  /// In en, this message translates to:
  /// **'Clear All'**
  String get characterEditor_clearAll;

  /// No description provided for @characterEditor_clearAllTitle.
  ///
  /// In en, this message translates to:
  /// **'Clear All Characters'**
  String get characterEditor_clearAllTitle;

  /// No description provided for @characterEditor_clearAllConfirm.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete all characters? This action cannot be undone.'**
  String get characterEditor_clearAllConfirm;

  /// No description provided for @characterEditor_tabList.
  ///
  /// In en, this message translates to:
  /// **'Character List'**
  String get characterEditor_tabList;

  /// No description provided for @characterEditor_tabDetail.
  ///
  /// In en, this message translates to:
  /// **'Character Detail'**
  String get characterEditor_tabDetail;

  /// No description provided for @characterEditor_globalAiChoice.
  ///
  /// In en, this message translates to:
  /// **'Global AI Position'**
  String get characterEditor_globalAiChoice;

  /// No description provided for @characterEditor_globalAiChoiceHint.
  ///
  /// In en, this message translates to:
  /// **'When enabled, AI will automatically decide positions for all characters'**
  String get characterEditor_globalAiChoiceHint;

  /// No description provided for @characterEditor_emptyTitle.
  ///
  /// In en, this message translates to:
  /// **'Please select a character'**
  String get characterEditor_emptyTitle;

  /// No description provided for @characterEditor_emptyHint.
  ///
  /// In en, this message translates to:
  /// **'Select from the list or add a new character'**
  String get characterEditor_emptyHint;

  /// No description provided for @characterEditor_noCharacters.
  ///
  /// In en, this message translates to:
  /// **'No characters'**
  String get characterEditor_noCharacters;

  /// No description provided for @characterEditor_addCharacterHint.
  ///
  /// In en, this message translates to:
  /// **'Click buttons above to add characters'**
  String get characterEditor_addCharacterHint;

  /// No description provided for @characterEditor_deleteTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete Character'**
  String get characterEditor_deleteTitle;

  /// No description provided for @characterEditor_deleteConfirm.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete this character? This action cannot be undone.'**
  String get characterEditor_deleteConfirm;

  /// No description provided for @characterEditor_name.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get characterEditor_name;

  /// No description provided for @characterEditor_nameHint.
  ///
  /// In en, this message translates to:
  /// **'Enter character name'**
  String get characterEditor_nameHint;

  /// No description provided for @characterEditor_enabled.
  ///
  /// In en, this message translates to:
  /// **'Enabled'**
  String get characterEditor_enabled;

  /// No description provided for @characterEditor_promptHint.
  ///
  /// In en, this message translates to:
  /// **'Enter positive prompt for this character...'**
  String get characterEditor_promptHint;

  /// No description provided for @characterEditor_negativePromptHint.
  ///
  /// In en, this message translates to:
  /// **'Enter negative prompt for this character...'**
  String get characterEditor_negativePromptHint;

  /// No description provided for @characterEditor_position.
  ///
  /// In en, this message translates to:
  /// **'Position'**
  String get characterEditor_position;

  /// No description provided for @characterEditor_genderFemale.
  ///
  /// In en, this message translates to:
  /// **'Female'**
  String get characterEditor_genderFemale;

  /// No description provided for @characterEditor_genderMale.
  ///
  /// In en, this message translates to:
  /// **'Male'**
  String get characterEditor_genderMale;

  /// No description provided for @characterEditor_genderOther.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get characterEditor_genderOther;

  /// No description provided for @characterEditor_genderFemaleHint.
  ///
  /// In en, this message translates to:
  /// **'Female (selected when adding)'**
  String get characterEditor_genderFemaleHint;

  /// No description provided for @characterEditor_genderMaleHint.
  ///
  /// In en, this message translates to:
  /// **'Male (selected when adding)'**
  String get characterEditor_genderMaleHint;

  /// No description provided for @characterEditor_genderOtherHint.
  ///
  /// In en, this message translates to:
  /// **'Other (selected when adding)'**
  String get characterEditor_genderOtherHint;

  /// No description provided for @characterEditor_addFemale.
  ///
  /// In en, this message translates to:
  /// **'F'**
  String get characterEditor_addFemale;

  /// No description provided for @characterEditor_addMale.
  ///
  /// In en, this message translates to:
  /// **'M'**
  String get characterEditor_addMale;

  /// No description provided for @characterEditor_addOther.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get characterEditor_addOther;

  /// No description provided for @characterEditor_addFromLibrary.
  ///
  /// In en, this message translates to:
  /// **'Library'**
  String get characterEditor_addFromLibrary;

  /// No description provided for @characterEditor_editCharacter.
  ///
  /// In en, this message translates to:
  /// **'Edit Character'**
  String get characterEditor_editCharacter;

  /// No description provided for @characterEditor_moveUp.
  ///
  /// In en, this message translates to:
  /// **'Move Up'**
  String get characterEditor_moveUp;

  /// No description provided for @characterEditor_moveDown.
  ///
  /// In en, this message translates to:
  /// **'Move Down'**
  String get characterEditor_moveDown;

  /// No description provided for @characterEditor_aiChoice.
  ///
  /// In en, this message translates to:
  /// **'AI'**
  String get characterEditor_aiChoice;

  /// No description provided for @characterEditor_positionLabel.
  ///
  /// In en, this message translates to:
  /// **'Position:'**
  String get characterEditor_positionLabel;

  /// No description provided for @characterEditor_positionHint.
  ///
  /// In en, this message translates to:
  /// **'Select character position in the image'**
  String get characterEditor_positionHint;

  /// No description provided for @characterEditor_promptLabel.
  ///
  /// In en, this message translates to:
  /// **'Prompt:'**
  String get characterEditor_promptLabel;

  /// No description provided for @characterEditor_disabled.
  ///
  /// In en, this message translates to:
  /// **'[Disabled]'**
  String get characterEditor_disabled;

  /// No description provided for @characterEditor_characterCount.
  ///
  /// In en, this message translates to:
  /// **'{count} characters'**
  String characterEditor_characterCount(Object count);

  /// No description provided for @characterEditor_characterCountWithEnabled.
  ///
  /// In en, this message translates to:
  /// **'{enabled}/{total} characters'**
  String characterEditor_characterCountWithEnabled(Object enabled, Object total);

  /// No description provided for @characterEditor_tooltipWithCount.
  ///
  /// In en, this message translates to:
  /// **'Multi-Character Prompts ({count} characters)'**
  String characterEditor_tooltipWithCount(Object count);

  /// No description provided for @characterEditor_clickToEdit.
  ///
  /// In en, this message translates to:
  /// **'Click to edit multi-character prompts'**
  String get characterEditor_clickToEdit;

  /// No description provided for @toolbar_randomPrompt.
  ///
  /// In en, this message translates to:
  /// **'Random Prompt'**
  String get toolbar_randomPrompt;

  /// No description provided for @toolbar_fullscreenEdit.
  ///
  /// In en, this message translates to:
  /// **'Fullscreen Edit'**
  String get toolbar_fullscreenEdit;

  /// No description provided for @toolbar_clear.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get toolbar_clear;

  /// No description provided for @toolbar_confirmClear.
  ///
  /// In en, this message translates to:
  /// **'Confirm Clear'**
  String get toolbar_confirmClear;

  /// No description provided for @toolbar_settings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get toolbar_settings;

  /// No description provided for @characterTooltip_noCharacters.
  ///
  /// In en, this message translates to:
  /// **'No characters configured'**
  String get characterTooltip_noCharacters;

  /// No description provided for @characterTooltip_clickToConfig.
  ///
  /// In en, this message translates to:
  /// **'Click to configure multi-character prompts'**
  String get characterTooltip_clickToConfig;

  /// No description provided for @characterTooltip_globalAiLabel.
  ///
  /// In en, this message translates to:
  /// **'Global AI Position:'**
  String get characterTooltip_globalAiLabel;

  /// No description provided for @characterTooltip_enabled.
  ///
  /// In en, this message translates to:
  /// **'Enabled'**
  String get characterTooltip_enabled;

  /// No description provided for @characterTooltip_disabled.
  ///
  /// In en, this message translates to:
  /// **'Disabled'**
  String get characterTooltip_disabled;

  /// No description provided for @characterTooltip_positionAi.
  ///
  /// In en, this message translates to:
  /// **'AI'**
  String get characterTooltip_positionAi;

  /// No description provided for @characterTooltip_disabledLabel.
  ///
  /// In en, this message translates to:
  /// **'Disabled'**
  String get characterTooltip_disabledLabel;

  /// No description provided for @characterTooltip_promptLabel.
  ///
  /// In en, this message translates to:
  /// **'Prompt'**
  String get characterTooltip_promptLabel;

  /// No description provided for @characterTooltip_negativeLabel.
  ///
  /// In en, this message translates to:
  /// **'Negative'**
  String get characterTooltip_negativeLabel;

  /// No description provided for @characterTooltip_notSet.
  ///
  /// In en, this message translates to:
  /// **'Not set'**
  String get characterTooltip_notSet;

  /// No description provided for @characterTooltip_summary.
  ///
  /// In en, this message translates to:
  /// **'{total} characters ({enabled} enabled)'**
  String characterTooltip_summary(Object total, Object enabled);

  /// No description provided for @characterTooltip_viewFullConfig.
  ///
  /// In en, this message translates to:
  /// **'Click for full configuration'**
  String get characterTooltip_viewFullConfig;

  /// No description provided for @tagLibrary_title.
  ///
  /// In en, this message translates to:
  /// **'Tag Library'**
  String get tagLibrary_title;

  /// No description provided for @tagLibrary_tagCount.
  ///
  /// In en, this message translates to:
  /// **'Loaded {count} tags'**
  String tagLibrary_tagCount(Object count);

  /// No description provided for @tagLibrary_usingBuiltin.
  ///
  /// In en, this message translates to:
  /// **'Using built-in library'**
  String get tagLibrary_usingBuiltin;

  /// No description provided for @tagLibrary_lastSync.
  ///
  /// In en, this message translates to:
  /// **'Last sync: {time}'**
  String tagLibrary_lastSync(Object time);

  /// No description provided for @tagLibrary_neverSynced.
  ///
  /// In en, this message translates to:
  /// **'Never synced'**
  String get tagLibrary_neverSynced;

  /// No description provided for @tagLibrary_syncNow.
  ///
  /// In en, this message translates to:
  /// **'Sync from Danbooru'**
  String get tagLibrary_syncNow;

  /// No description provided for @tagLibrary_syncing.
  ///
  /// In en, this message translates to:
  /// **'Syncing...'**
  String get tagLibrary_syncing;

  /// No description provided for @tagLibrary_syncSuccess.
  ///
  /// In en, this message translates to:
  /// **'Library synced successfully'**
  String get tagLibrary_syncSuccess;

  /// No description provided for @tagLibrary_syncFailed.
  ///
  /// In en, this message translates to:
  /// **'Sync failed, please check network connection'**
  String get tagLibrary_syncFailed;

  /// No description provided for @tagLibrary_networkError.
  ///
  /// In en, this message translates to:
  /// **'Cannot connect to Danbooru, please check network or proxy settings'**
  String get tagLibrary_networkError;

  /// No description provided for @tagLibrary_autoSync.
  ///
  /// In en, this message translates to:
  /// **'Auto Sync'**
  String get tagLibrary_autoSync;

  /// No description provided for @tagLibrary_autoSyncHint.
  ///
  /// In en, this message translates to:
  /// **'Periodically update from Danbooru'**
  String get tagLibrary_autoSyncHint;

  /// No description provided for @tagLibrary_syncInterval.
  ///
  /// In en, this message translates to:
  /// **'Sync Interval'**
  String get tagLibrary_syncInterval;

  /// No description provided for @tagLibrary_dataRange.
  ///
  /// In en, this message translates to:
  /// **'Data Range'**
  String get tagLibrary_dataRange;

  /// No description provided for @tagLibrary_dataRangeHint.
  ///
  /// In en, this message translates to:
  /// **'Larger range means longer sync time but more tags'**
  String get tagLibrary_dataRangeHint;

  /// No description provided for @tagLibrary_dataRangePopular.
  ///
  /// In en, this message translates to:
  /// **'Popular (>1000)'**
  String get tagLibrary_dataRangePopular;

  /// No description provided for @tagLibrary_dataRangeMedium.
  ///
  /// In en, this message translates to:
  /// **'Medium (>500)'**
  String get tagLibrary_dataRangeMedium;

  /// No description provided for @tagLibrary_dataRangeFull.
  ///
  /// In en, this message translates to:
  /// **'Full (>100)'**
  String get tagLibrary_dataRangeFull;

  /// No description provided for @tagLibrary_syncIntervalDays.
  ///
  /// In en, this message translates to:
  /// **'{days} days'**
  String tagLibrary_syncIntervalDays(Object days);

  /// No description provided for @tagLibrary_generatedCharacters.
  ///
  /// In en, this message translates to:
  /// **'Generated {count} characters'**
  String tagLibrary_generatedCharacters(Object count);

  /// No description provided for @tagLibrary_generateFailed.
  ///
  /// In en, this message translates to:
  /// **'Generation failed: {error}'**
  String tagLibrary_generateFailed(Object error);

  /// No description provided for @randomMode_title.
  ///
  /// In en, this message translates to:
  /// **'Select Random Mode'**
  String get randomMode_title;

  /// No description provided for @randomMode_naiOfficial.
  ///
  /// In en, this message translates to:
  /// **'Official Mode'**
  String get randomMode_naiOfficial;

  /// No description provided for @randomMode_custom.
  ///
  /// In en, this message translates to:
  /// **'Custom Mode'**
  String get randomMode_custom;

  /// No description provided for @randomMode_hybrid.
  ///
  /// In en, this message translates to:
  /// **'Hybrid Mode'**
  String get randomMode_hybrid;

  /// No description provided for @randomMode_naiOfficialDesc.
  ///
  /// In en, this message translates to:
  /// **'Replicate NovelAI official random algorithm'**
  String get randomMode_naiOfficialDesc;

  /// No description provided for @randomMode_customDesc.
  ///
  /// In en, this message translates to:
  /// **'Generate using custom presets'**
  String get randomMode_customDesc;

  /// No description provided for @randomMode_hybridDesc.
  ///
  /// In en, this message translates to:
  /// **'Combine official algorithm with custom presets'**
  String get randomMode_hybridDesc;

  /// No description provided for @randomMode_naiIndicator.
  ///
  /// In en, this message translates to:
  /// **'NAI'**
  String get randomMode_naiIndicator;

  /// No description provided for @randomMode_customIndicator.
  ///
  /// In en, this message translates to:
  /// **'Custom'**
  String get randomMode_customIndicator;

  /// No description provided for @naiMode_title.
  ///
  /// In en, this message translates to:
  /// **'Default Mode'**
  String get naiMode_title;

  /// No description provided for @naiMode_subtitle.
  ///
  /// In en, this message translates to:
  /// **'Replicate NovelAI official random algorithm'**
  String get naiMode_subtitle;

  /// No description provided for @naiMode_syncLibrary.
  ///
  /// In en, this message translates to:
  /// **'Manage Extended Library'**
  String get naiMode_syncLibrary;

  /// No description provided for @manageLibrary.
  ///
  /// In en, this message translates to:
  /// **'Manage Library'**
  String get manageLibrary;

  /// No description provided for @naiMode_algorithmInfo.
  ///
  /// In en, this message translates to:
  /// **'Algorithm Info'**
  String get naiMode_algorithmInfo;

  /// No description provided for @naiMode_tagCountBadge.
  ///
  /// In en, this message translates to:
  /// **'{count} tags'**
  String naiMode_tagCountBadge(Object count);

  /// No description provided for @naiMode_totalTags.
  ///
  /// In en, this message translates to:
  /// **'Tags: {count}'**
  String naiMode_totalTags(Object count);

  /// No description provided for @naiMode_lastSync.
  ///
  /// In en, this message translates to:
  /// **'Synced: {time}'**
  String naiMode_lastSync(Object time);

  /// No description provided for @naiMode_lastSyncLabel.
  ///
  /// In en, this message translates to:
  /// **'Last Sync'**
  String get naiMode_lastSyncLabel;

  /// No description provided for @timeAgo_justNow.
  ///
  /// In en, this message translates to:
  /// **'just now'**
  String get timeAgo_justNow;

  /// No description provided for @timeAgo_minutes.
  ///
  /// In en, this message translates to:
  /// **'{count} min ago'**
  String timeAgo_minutes(Object count);

  /// No description provided for @timeAgo_hours.
  ///
  /// In en, this message translates to:
  /// **'{count}h ago'**
  String timeAgo_hours(Object count);

  /// No description provided for @timeAgo_days.
  ///
  /// In en, this message translates to:
  /// **'{count}d ago'**
  String timeAgo_days(Object count);

  /// No description provided for @naiMode_dataRange.
  ///
  /// In en, this message translates to:
  /// **'Range: {range}'**
  String naiMode_dataRange(Object range);

  /// No description provided for @naiMode_preview.
  ///
  /// In en, this message translates to:
  /// **'Preview'**
  String get naiMode_preview;

  /// No description provided for @naiMode_createCustom.
  ///
  /// In en, this message translates to:
  /// **'Create Custom Preset'**
  String get naiMode_createCustom;

  /// No description provided for @naiMode_categoryProbability.
  ///
  /// In en, this message translates to:
  /// **'{probability}%'**
  String naiMode_categoryProbability(Object probability);

  /// No description provided for @naiMode_tagCount.
  ///
  /// In en, this message translates to:
  /// **'{count} tags'**
  String naiMode_tagCount(Object count);

  /// No description provided for @naiMode_readOnlyHint.
  ///
  /// In en, this message translates to:
  /// **'Random prompt configuration based on official algorithm'**
  String get naiMode_readOnlyHint;

  /// No description provided for @promptConfig_confirmRemoveGroup.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to remove group \"{name}\"?'**
  String promptConfig_confirmRemoveGroup(Object name);

  /// No description provided for @promptConfig_confirmRemoveCategory.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to remove category \"{name}\"? It will no longer participate in random generation.'**
  String promptConfig_confirmRemoveCategory(Object name);

  /// No description provided for @promptConfig_groupList.
  ///
  /// In en, this message translates to:
  /// **'Group List'**
  String get promptConfig_groupList;

  /// No description provided for @promptConfig_groupCount.
  ///
  /// In en, this message translates to:
  /// **'{count} groups'**
  String promptConfig_groupCount(Object count);

  /// No description provided for @promptConfig_addGroup.
  ///
  /// In en, this message translates to:
  /// **'Add Group'**
  String get promptConfig_addGroup;

  /// No description provided for @promptConfig_noGroups.
  ///
  /// In en, this message translates to:
  /// **'No groups yet, click \"Add Group\" to create'**
  String get promptConfig_noGroups;

  /// No description provided for @promptConfig_builtinLibrary.
  ///
  /// In en, this message translates to:
  /// **'NAI Built-in Library'**
  String get promptConfig_builtinLibrary;

  /// No description provided for @promptConfig_customGroup.
  ///
  /// In en, this message translates to:
  /// **'Custom Group'**
  String get promptConfig_customGroup;

  /// No description provided for @promptConfig_danbooruTagGroup.
  ///
  /// In en, this message translates to:
  /// **'Danbooru TagGroup'**
  String get promptConfig_danbooruTagGroup;

  /// No description provided for @promptConfig_danbooruPool.
  ///
  /// In en, this message translates to:
  /// **'Danbooru Pool'**
  String get promptConfig_danbooruPool;

  /// No description provided for @promptConfig_categorySettings.
  ///
  /// In en, this message translates to:
  /// **'Category Settings'**
  String get promptConfig_categorySettings;

  /// No description provided for @promptConfig_enableCategory.
  ///
  /// In en, this message translates to:
  /// **'Enable Category'**
  String get promptConfig_enableCategory;

  /// No description provided for @promptConfig_disableCategory.
  ///
  /// In en, this message translates to:
  /// **'Disable Category'**
  String get promptConfig_disableCategory;

  /// No description provided for @naiMode_noLibrary.
  ///
  /// In en, this message translates to:
  /// **'Library not loaded'**
  String get naiMode_noLibrary;

  /// No description provided for @naiMode_noCategories.
  ///
  /// In en, this message translates to:
  /// **'No categories. Please reset preset or add new categories.'**
  String get naiMode_noCategories;

  /// No description provided for @naiMode_noTags.
  ///
  /// In en, this message translates to:
  /// **'No tags'**
  String get naiMode_noTags;

  /// No description provided for @naiMode_previewResult.
  ///
  /// In en, this message translates to:
  /// **'Preview Result'**
  String get naiMode_previewResult;

  /// No description provided for @naiMode_characterPrompts.
  ///
  /// In en, this message translates to:
  /// **'Character Prompts'**
  String get naiMode_characterPrompts;

  /// No description provided for @naiMode_character.
  ///
  /// In en, this message translates to:
  /// **'Character'**
  String get naiMode_character;

  /// No description provided for @naiMode_createCustomTitle.
  ///
  /// In en, this message translates to:
  /// **'Create Custom Preset'**
  String get naiMode_createCustomTitle;

  /// No description provided for @naiMode_createCustomDesc.
  ///
  /// In en, this message translates to:
  /// **'This will create a new preset with all NAI categories, which you can customize.'**
  String get naiMode_createCustomDesc;

  /// No description provided for @naiMode_featureComingSoon.
  ///
  /// In en, this message translates to:
  /// **'Feature coming soon...'**
  String get naiMode_featureComingSoon;

  /// No description provided for @naiMode_danbooruToggleTooltip.
  ///
  /// In en, this message translates to:
  /// **'Toggle extended tags for this category'**
  String get naiMode_danbooruToggleTooltip;

  /// No description provided for @naiMode_danbooruSupplementLabel.
  ///
  /// In en, this message translates to:
  /// **'Extended Tags'**
  String get naiMode_danbooruSupplementLabel;

  /// No description provided for @naiMode_danbooruMasterToggleTooltip.
  ///
  /// In en, this message translates to:
  /// **'Toggle extended tags for all categories'**
  String get naiMode_danbooruMasterToggleTooltip;

  /// No description provided for @naiMode_entrySubtitle.
  ///
  /// In en, this message translates to:
  /// **'{count} tags · Replicate official algorithm'**
  String naiMode_entrySubtitle(Object count);

  /// No description provided for @naiAlgorithm_title.
  ///
  /// In en, this message translates to:
  /// **'NAI Random Algorithm'**
  String get naiAlgorithm_title;

  /// No description provided for @naiAlgorithm_characterCount.
  ///
  /// In en, this message translates to:
  /// **'Character Count Distribution'**
  String get naiAlgorithm_characterCount;

  /// No description provided for @naiAlgorithm_categoryProbability.
  ///
  /// In en, this message translates to:
  /// **'Category Selection Probability'**
  String get naiAlgorithm_categoryProbability;

  /// No description provided for @naiAlgorithm_weightedRandom.
  ///
  /// In en, this message translates to:
  /// **'Weighted Random Algorithm'**
  String get naiAlgorithm_weightedRandom;

  /// No description provided for @naiAlgorithm_weightedRandomDesc.
  ///
  /// In en, this message translates to:
  /// **'Each tag\'s weight is based on Danbooru usage count. Higher weight means higher selection probability.'**
  String get naiAlgorithm_weightedRandomDesc;

  /// No description provided for @naiAlgorithm_v4MultiCharacter.
  ///
  /// In en, this message translates to:
  /// **'V4 Multi-Character'**
  String get naiAlgorithm_v4MultiCharacter;

  /// No description provided for @naiAlgorithm_v4Desc.
  ///
  /// In en, this message translates to:
  /// **'V4 models support independent prompts for each character, separating main and character prompts.'**
  String get naiAlgorithm_v4Desc;

  /// No description provided for @naiAlgorithm_mainPrompt.
  ///
  /// In en, this message translates to:
  /// **'Main Prompt'**
  String get naiAlgorithm_mainPrompt;

  /// No description provided for @naiAlgorithm_mainPromptTags.
  ///
  /// In en, this message translates to:
  /// **'Character count, background, style'**
  String get naiAlgorithm_mainPromptTags;

  /// No description provided for @naiAlgorithm_characterPrompt.
  ///
  /// In en, this message translates to:
  /// **'Character Prompt'**
  String get naiAlgorithm_characterPrompt;

  /// No description provided for @naiAlgorithm_characterPromptTags.
  ///
  /// In en, this message translates to:
  /// **'Hair color, eye color, hairstyle, expression, pose'**
  String get naiAlgorithm_characterPromptTags;

  /// No description provided for @naiAlgorithm_noHuman.
  ///
  /// In en, this message translates to:
  /// **'No Human Scene'**
  String get naiAlgorithm_noHuman;

  /// No description provided for @naiAlgorithm_noHumanDesc.
  ///
  /// In en, this message translates to:
  /// **'5% chance to generate scene without humans, containing only background, scene, and style tags.'**
  String get naiAlgorithm_noHumanDesc;

  /// No description provided for @naiAlgorithm_background.
  ///
  /// In en, this message translates to:
  /// **'Background'**
  String get naiAlgorithm_background;

  /// No description provided for @naiAlgorithm_hairColor.
  ///
  /// In en, this message translates to:
  /// **'Hair Color'**
  String get naiAlgorithm_hairColor;

  /// No description provided for @naiAlgorithm_eyeColor.
  ///
  /// In en, this message translates to:
  /// **'Eye Color'**
  String get naiAlgorithm_eyeColor;

  /// No description provided for @naiAlgorithm_expression.
  ///
  /// In en, this message translates to:
  /// **'Expression'**
  String get naiAlgorithm_expression;

  /// No description provided for @naiAlgorithm_hairStyle.
  ///
  /// In en, this message translates to:
  /// **'Hair Style'**
  String get naiAlgorithm_hairStyle;

  /// No description provided for @naiAlgorithm_pose.
  ///
  /// In en, this message translates to:
  /// **'Pose'**
  String get naiAlgorithm_pose;

  /// No description provided for @naiAlgorithm_style.
  ///
  /// In en, this message translates to:
  /// **'Style'**
  String get naiAlgorithm_style;

  /// No description provided for @naiAlgorithm_clothing.
  ///
  /// In en, this message translates to:
  /// **'Clothing'**
  String get naiAlgorithm_clothing;

  /// No description provided for @naiAlgorithm_accessory.
  ///
  /// In en, this message translates to:
  /// **'Accessory'**
  String get naiAlgorithm_accessory;

  /// No description provided for @naiAlgorithm_scene.
  ///
  /// In en, this message translates to:
  /// **'Scene'**
  String get naiAlgorithm_scene;

  /// No description provided for @naiAlgorithm_bodyFeature.
  ///
  /// In en, this message translates to:
  /// **'Body Feature'**
  String get naiAlgorithm_bodyFeature;

  /// No description provided for @importNai_title.
  ///
  /// In en, this message translates to:
  /// **'Import from NAI Library'**
  String get importNai_title;

  /// No description provided for @importNai_selectCategories.
  ///
  /// In en, this message translates to:
  /// **'Select categories to import'**
  String get importNai_selectCategories;

  /// No description provided for @importNai_import.
  ///
  /// In en, this message translates to:
  /// **'Import {count} categories'**
  String importNai_import(Object count);

  /// No description provided for @importNai_tagCount.
  ///
  /// In en, this message translates to:
  /// **'{count} tags'**
  String importNai_tagCount(Object count);

  /// No description provided for @tagLibrary_rangePopular.
  ///
  /// In en, this message translates to:
  /// **'Popular'**
  String get tagLibrary_rangePopular;

  /// No description provided for @tagLibrary_rangeMedium.
  ///
  /// In en, this message translates to:
  /// **'Medium'**
  String get tagLibrary_rangeMedium;

  /// No description provided for @tagLibrary_rangeFull.
  ///
  /// In en, this message translates to:
  /// **'Full'**
  String get tagLibrary_rangeFull;

  /// No description provided for @tagLibrary_daysAgo.
  ///
  /// In en, this message translates to:
  /// **'{days} days ago'**
  String tagLibrary_daysAgo(Object days);

  /// No description provided for @tagLibrary_hoursAgo.
  ///
  /// In en, this message translates to:
  /// **'{hours} hours ago'**
  String tagLibrary_hoursAgo(Object hours);

  /// No description provided for @tagLibrary_justNow.
  ///
  /// In en, this message translates to:
  /// **'Just now'**
  String get tagLibrary_justNow;

  /// No description provided for @tagLibrary_danbooruSupplement.
  ///
  /// In en, this message translates to:
  /// **'Danbooru Supplement'**
  String get tagLibrary_danbooruSupplement;

  /// No description provided for @tagLibrary_danbooruSupplementHint.
  ///
  /// In en, this message translates to:
  /// **'Fetch extra tags from Danbooru to supplement library'**
  String get tagLibrary_danbooruSupplementHint;

  /// No description provided for @tagLibrary_libraryComposition.
  ///
  /// In en, this message translates to:
  /// **'Library Composition'**
  String get tagLibrary_libraryComposition;

  /// No description provided for @tagLibrary_libraryCompositionDesc.
  ///
  /// In en, this message translates to:
  /// **'NAI Official Fixed Library + Extended Tags (Optional)'**
  String get tagLibrary_libraryCompositionDesc;

  /// No description provided for @poolMapping_title.
  ///
  /// In en, this message translates to:
  /// **'Pool Mapping'**
  String get poolMapping_title;

  /// No description provided for @poolMapping_enableSync.
  ///
  /// In en, this message translates to:
  /// **'Enable Pool Sync'**
  String get poolMapping_enableSync;

  /// No description provided for @poolMapping_enableSyncDesc.
  ///
  /// In en, this message translates to:
  /// **'Extract tags from Danbooru Pools to supplement categories'**
  String get poolMapping_enableSyncDesc;

  /// No description provided for @poolMapping_addMapping.
  ///
  /// In en, this message translates to:
  /// **'Add Pool Mapping'**
  String get poolMapping_addMapping;

  /// No description provided for @poolMapping_noMappings.
  ///
  /// In en, this message translates to:
  /// **'No Pool Mappings'**
  String get poolMapping_noMappings;

  /// No description provided for @poolMapping_noMappingsHint.
  ///
  /// In en, this message translates to:
  /// **'Click the button above to add a Danbooru Pool'**
  String get poolMapping_noMappingsHint;

  /// No description provided for @poolMapping_searchPool.
  ///
  /// In en, this message translates to:
  /// **'Search Pool'**
  String get poolMapping_searchPool;

  /// No description provided for @poolMapping_searchHint.
  ///
  /// In en, this message translates to:
  /// **'Enter Pool name keywords'**
  String get poolMapping_searchHint;

  /// No description provided for @poolMapping_targetCategory.
  ///
  /// In en, this message translates to:
  /// **'Target Category'**
  String get poolMapping_targetCategory;

  /// No description provided for @poolMapping_selectPool.
  ///
  /// In en, this message translates to:
  /// **'Select Pool'**
  String get poolMapping_selectPool;

  /// No description provided for @poolMapping_syncPools.
  ///
  /// In en, this message translates to:
  /// **'Sync Pools'**
  String get poolMapping_syncPools;

  /// No description provided for @poolMapping_syncing.
  ///
  /// In en, this message translates to:
  /// **'Syncing...'**
  String get poolMapping_syncing;

  /// No description provided for @poolMapping_neverSynced.
  ///
  /// In en, this message translates to:
  /// **'Never synced'**
  String get poolMapping_neverSynced;

  /// No description provided for @poolMapping_syncSuccess.
  ///
  /// In en, this message translates to:
  /// **'Pool sync successful'**
  String get poolMapping_syncSuccess;

  /// No description provided for @poolMapping_syncFailed.
  ///
  /// In en, this message translates to:
  /// **'Pool sync failed'**
  String get poolMapping_syncFailed;

  /// No description provided for @poolMapping_noResults.
  ///
  /// In en, this message translates to:
  /// **'No matching Pools found'**
  String get poolMapping_noResults;

  /// No description provided for @poolMapping_poolExists.
  ///
  /// In en, this message translates to:
  /// **'This Pool is already added'**
  String get poolMapping_poolExists;

  /// No description provided for @poolMapping_addSuccess.
  ///
  /// In en, this message translates to:
  /// **'Pool mapping added successfully'**
  String get poolMapping_addSuccess;

  /// No description provided for @poolMapping_removeConfirm.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to remove this Pool mapping?'**
  String get poolMapping_removeConfirm;

  /// No description provided for @poolMapping_removeSuccess.
  ///
  /// In en, this message translates to:
  /// **'Pool mapping removed'**
  String get poolMapping_removeSuccess;

  /// No description provided for @poolMapping_tagCount.
  ///
  /// In en, this message translates to:
  /// **'{count} tags'**
  String poolMapping_tagCount(Object count);

  /// No description provided for @poolMapping_postCount.
  ///
  /// In en, this message translates to:
  /// **'{count} posts'**
  String poolMapping_postCount(Object count);

  /// No description provided for @poolMapping_alreadyAdded.
  ///
  /// In en, this message translates to:
  /// **'Added'**
  String get poolMapping_alreadyAdded;

  /// No description provided for @poolMapping_resetToDefault.
  ///
  /// In en, this message translates to:
  /// **'Reset to Default'**
  String get poolMapping_resetToDefault;

  /// No description provided for @poolMapping_resetConfirm.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to reset to default Pool mappings? Current configuration will be overwritten.'**
  String get poolMapping_resetConfirm;

  /// No description provided for @poolMapping_resetSuccess.
  ///
  /// In en, this message translates to:
  /// **'Reset to default configuration'**
  String get poolMapping_resetSuccess;

  /// No description provided for @tagGroup_title.
  ///
  /// In en, this message translates to:
  /// **'Tag Group Sync'**
  String get tagGroup_title;

  /// No description provided for @tagGroup_enableSync.
  ///
  /// In en, this message translates to:
  /// **'Enable Tag Group Sync'**
  String get tagGroup_enableSync;

  /// No description provided for @tagGroup_enableSyncDesc.
  ///
  /// In en, this message translates to:
  /// **'Fetch tag data from Danbooru Tag Groups'**
  String get tagGroup_enableSyncDesc;

  /// No description provided for @tagGroup_mappingTitle.
  ///
  /// In en, this message translates to:
  /// **'Tag Group Mappings'**
  String get tagGroup_mappingTitle;

  /// No description provided for @tagGroup_addMapping.
  ///
  /// In en, this message translates to:
  /// **'Add Mapping'**
  String get tagGroup_addMapping;

  /// No description provided for @tagGroup_noMappings.
  ///
  /// In en, this message translates to:
  /// **'No Tag Group Mappings'**
  String get tagGroup_noMappings;

  /// No description provided for @tagGroup_noMappingsHint.
  ///
  /// In en, this message translates to:
  /// **'Click the button above to browse and add Tag Groups'**
  String get tagGroup_noMappingsHint;

  /// No description provided for @tagGroup_searchHint.
  ///
  /// In en, this message translates to:
  /// **'Search Tag Groups...'**
  String get tagGroup_searchHint;

  /// No description provided for @tagGroup_targetCategory.
  ///
  /// In en, this message translates to:
  /// **'Target Category'**
  String get tagGroup_targetCategory;

  /// No description provided for @tagGroup_selectGroup.
  ///
  /// In en, this message translates to:
  /// **'Select Tag Group'**
  String get tagGroup_selectGroup;

  /// No description provided for @tagGroup_neverSynced.
  ///
  /// In en, this message translates to:
  /// **'Never synced'**
  String get tagGroup_neverSynced;

  /// No description provided for @tagGroup_noResults.
  ///
  /// In en, this message translates to:
  /// **'No matching Tag Groups found'**
  String get tagGroup_noResults;

  /// No description provided for @tagGroup_groupExists.
  ///
  /// In en, this message translates to:
  /// **'This Tag Group is already added'**
  String get tagGroup_groupExists;

  /// No description provided for @tagGroup_addSuccess.
  ///
  /// In en, this message translates to:
  /// **'Tag Group mapping added successfully'**
  String get tagGroup_addSuccess;

  /// No description provided for @tagGroup_removeConfirm.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to remove this Tag Group mapping?'**
  String get tagGroup_removeConfirm;

  /// No description provided for @tagGroup_removeSuccess.
  ///
  /// In en, this message translates to:
  /// **'Tag Group mapping removed'**
  String get tagGroup_removeSuccess;

  /// No description provided for @tagGroup_tagCount.
  ///
  /// In en, this message translates to:
  /// **'{count} tags'**
  String tagGroup_tagCount(Object count);

  /// No description provided for @tagGroup_childCount.
  ///
  /// In en, this message translates to:
  /// **'{count} sub-groups'**
  String tagGroup_childCount(Object count);

  /// No description provided for @tagGroup_alreadyAdded.
  ///
  /// In en, this message translates to:
  /// **'Added'**
  String get tagGroup_alreadyAdded;

  /// No description provided for @tagGroup_resetToDefault.
  ///
  /// In en, this message translates to:
  /// **'Reset to Default'**
  String get tagGroup_resetToDefault;

  /// No description provided for @tagGroup_resetConfirm.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to reset to default Tag Group mappings? Current configuration will be overwritten.'**
  String get tagGroup_resetConfirm;

  /// No description provided for @tagGroup_resetSuccess.
  ///
  /// In en, this message translates to:
  /// **'Reset to default configuration'**
  String get tagGroup_resetSuccess;

  /// No description provided for @tagGroup_minPostCount.
  ///
  /// In en, this message translates to:
  /// **'Minimum Post Count'**
  String get tagGroup_minPostCount;

  /// No description provided for @tagGroup_postCountValue.
  ///
  /// In en, this message translates to:
  /// **'{count} posts'**
  String tagGroup_postCountValue(Object count);

  /// No description provided for @tagGroup_minPostCountHint.
  ///
  /// In en, this message translates to:
  /// **'Only sync tags with post count above this threshold'**
  String get tagGroup_minPostCountHint;

  /// No description provided for @tagGroup_preview.
  ///
  /// In en, this message translates to:
  /// **'Tag Preview'**
  String get tagGroup_preview;

  /// No description provided for @tagGroup_previewCount.
  ///
  /// In en, this message translates to:
  /// **'Preview {count} tags'**
  String tagGroup_previewCount(Object count);

  /// No description provided for @tagGroup_selectToPreview.
  ///
  /// In en, this message translates to:
  /// **'Select a Tag Group to see preview'**
  String get tagGroup_selectToPreview;

  /// No description provided for @tagGroup_noTagsInGroup.
  ///
  /// In en, this message translates to:
  /// **'No tags in this group'**
  String get tagGroup_noTagsInGroup;

  /// No description provided for @tagGroup_andMore.
  ///
  /// In en, this message translates to:
  /// **'and {count} more...'**
  String tagGroup_andMore(Object count);

  /// No description provided for @tagGroup_options.
  ///
  /// In en, this message translates to:
  /// **'Options'**
  String get tagGroup_options;

  /// No description provided for @tagGroup_includeChildren.
  ///
  /// In en, this message translates to:
  /// **'Include sub-group tags'**
  String get tagGroup_includeChildren;

  /// No description provided for @tagGroup_includesChildren.
  ///
  /// In en, this message translates to:
  /// **'Includes sub-groups'**
  String get tagGroup_includesChildren;

  /// No description provided for @tagGroup_syncPreparing.
  ///
  /// In en, this message translates to:
  /// **'Preparing sync...'**
  String get tagGroup_syncPreparing;

  /// No description provided for @tagGroup_syncFetching.
  ///
  /// In en, this message translates to:
  /// **'Fetching {name}... ({current}/{total})'**
  String tagGroup_syncFetching(Object name, Object current, Object total);

  /// No description provided for @tagGroup_syncFiltering.
  ///
  /// In en, this message translates to:
  /// **'Filtering: {total} tags, keeping {filtered} tags'**
  String tagGroup_syncFiltering(Object total, Object filtered);

  /// No description provided for @tagGroup_syncCompleted.
  ///
  /// In en, this message translates to:
  /// **'Sync completed, {count} tags total'**
  String tagGroup_syncCompleted(Object count);

  /// No description provided for @tagGroup_syncFailed.
  ///
  /// In en, this message translates to:
  /// **'Sync failed: {error}'**
  String tagGroup_syncFailed(Object error);

  /// No description provided for @tagGroup_addTo.
  ///
  /// In en, this message translates to:
  /// **'Add to: {category}'**
  String tagGroup_addTo(Object category);

  /// No description provided for @tagGroup_refresh.
  ///
  /// In en, this message translates to:
  /// **'Refresh list'**
  String get tagGroup_refresh;

  /// No description provided for @tagGroup_loadingFromDanbooru.
  ///
  /// In en, this message translates to:
  /// **'Loading Tag Groups from Danbooru...'**
  String get tagGroup_loadingFromDanbooru;

  /// No description provided for @tagGroup_loadFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to load Tag Groups, please check network connection'**
  String get tagGroup_loadFailed;

  /// No description provided for @tagGroup_loadError.
  ///
  /// In en, this message translates to:
  /// **'Load failed: {error}'**
  String tagGroup_loadError(Object error);

  /// No description provided for @tagGroup_reload.
  ///
  /// In en, this message translates to:
  /// **'Reload'**
  String get tagGroup_reload;

  /// No description provided for @tagGroup_searchHintAlt.
  ///
  /// In en, this message translates to:
  /// **'Or use search to find specific groups'**
  String get tagGroup_searchHintAlt;

  /// No description provided for @tagGroup_selected.
  ///
  /// In en, this message translates to:
  /// **'Selected'**
  String get tagGroup_selected;

  /// No description provided for @tagGroup_manageGroups.
  ///
  /// In en, this message translates to:
  /// **'Manage Groups'**
  String get tagGroup_manageGroups;

  /// No description provided for @tagGroup_manageGroupsHint.
  ///
  /// In en, this message translates to:
  /// **'Select Tag Groups to sync'**
  String get tagGroup_manageGroupsHint;

  /// No description provided for @tagGroup_selectedCount.
  ///
  /// In en, this message translates to:
  /// **'Selected {count} groups'**
  String tagGroup_selectedCount(Object count);

  /// No description provided for @naiMode_syncCategory.
  ///
  /// In en, this message translates to:
  /// **'Sync Category'**
  String get naiMode_syncCategory;

  /// No description provided for @naiMode_syncCategoryTooltip.
  ///
  /// In en, this message translates to:
  /// **'Sync extended tags for this category only'**
  String get naiMode_syncCategoryTooltip;

  /// No description provided for @naiMode_viewDetails.
  ///
  /// In en, this message translates to:
  /// **'View Details'**
  String get naiMode_viewDetails;

  /// No description provided for @naiMode_tagListTitle.
  ///
  /// In en, this message translates to:
  /// **'Tag List'**
  String get naiMode_tagListTitle;

  /// No description provided for @naiMode_desc_hairColor.
  ///
  /// In en, this message translates to:
  /// **'Hair color tags for describing character\'s hair color'**
  String get naiMode_desc_hairColor;

  /// No description provided for @naiMode_desc_eyeColor.
  ///
  /// In en, this message translates to:
  /// **'Eye color tags for describing character\'s eye color'**
  String get naiMode_desc_eyeColor;

  /// No description provided for @naiMode_desc_hairStyle.
  ///
  /// In en, this message translates to:
  /// **'Hair style tags for describing character\'s hairstyle'**
  String get naiMode_desc_hairStyle;

  /// No description provided for @naiMode_desc_expression.
  ///
  /// In en, this message translates to:
  /// **'Expression tags for describing facial expressions'**
  String get naiMode_desc_expression;

  /// No description provided for @naiMode_desc_pose.
  ///
  /// In en, this message translates to:
  /// **'Pose tags for describing body postures and actions'**
  String get naiMode_desc_pose;

  /// No description provided for @naiMode_desc_clothing.
  ///
  /// In en, this message translates to:
  /// **'Clothing tags for describing outfits'**
  String get naiMode_desc_clothing;

  /// No description provided for @naiMode_desc_accessory.
  ///
  /// In en, this message translates to:
  /// **'Accessory tags for describing decorations and accessories'**
  String get naiMode_desc_accessory;

  /// No description provided for @naiMode_desc_bodyFeature.
  ///
  /// In en, this message translates to:
  /// **'Body feature tags for describing body characteristics'**
  String get naiMode_desc_bodyFeature;

  /// No description provided for @naiMode_desc_background.
  ///
  /// In en, this message translates to:
  /// **'Background tags for describing background types'**
  String get naiMode_desc_background;

  /// No description provided for @naiMode_desc_scene.
  ///
  /// In en, this message translates to:
  /// **'Scene tags for describing scene elements'**
  String get naiMode_desc_scene;

  /// No description provided for @naiMode_desc_style.
  ///
  /// In en, this message translates to:
  /// **'Style tags for describing art styles'**
  String get naiMode_desc_style;

  /// No description provided for @naiMode_desc_characterCount.
  ///
  /// In en, this message translates to:
  /// **'Character count tags for determining number of characters'**
  String get naiMode_desc_characterCount;

  /// No description provided for @tagGroup_builtin.
  ///
  /// In en, this message translates to:
  /// **'Built-in'**
  String get tagGroup_builtin;

  /// No description provided for @tagGroup_totalTagsTooltip.
  ///
  /// In en, this message translates to:
  /// **'Original: {original} / Filtered: {filtered}'**
  String tagGroup_totalTagsTooltip(Object original, Object filtered);

  /// No description provided for @tagGroup_cacheDetails.
  ///
  /// In en, this message translates to:
  /// **'Cache Details'**
  String get tagGroup_cacheDetails;

  /// No description provided for @tagGroup_cachedCategories.
  ///
  /// In en, this message translates to:
  /// **'Cached Categories'**
  String get tagGroup_cachedCategories;

  /// No description provided for @cache_title.
  ///
  /// In en, this message translates to:
  /// **'Word Groups'**
  String get cache_title;

  /// No description provided for @cache_manage.
  ///
  /// In en, this message translates to:
  /// **'Word Groups'**
  String get cache_manage;

  /// No description provided for @cache_tabTagGroup.
  ///
  /// In en, this message translates to:
  /// **'Tag Group'**
  String get cache_tabTagGroup;

  /// No description provided for @cache_tabPool.
  ///
  /// In en, this message translates to:
  /// **'Pool'**
  String get cache_tabPool;

  /// No description provided for @cache_noTagGroups.
  ///
  /// In en, this message translates to:
  /// **'No Tag Group cache'**
  String get cache_noTagGroups;

  /// No description provided for @cache_noPools.
  ///
  /// In en, this message translates to:
  /// **'No Pool cache'**
  String get cache_noPools;

  /// No description provided for @cache_noBuiltin.
  ///
  /// In en, this message translates to:
  /// **'No built-in dictionaries'**
  String get cache_noBuiltin;

  /// No description provided for @cache_probability.
  ///
  /// In en, this message translates to:
  /// **'Probability'**
  String get cache_probability;

  /// No description provided for @cache_tags.
  ///
  /// In en, this message translates to:
  /// **'tags'**
  String get cache_tags;

  /// No description provided for @cache_posts.
  ///
  /// In en, this message translates to:
  /// **'posts'**
  String get cache_posts;

  /// No description provided for @cache_neverSynced.
  ///
  /// In en, this message translates to:
  /// **'Never synced'**
  String get cache_neverSynced;

  /// No description provided for @cache_refresh.
  ///
  /// In en, this message translates to:
  /// **'Refresh'**
  String get cache_refresh;

  /// No description provided for @cache_refreshFailed.
  ///
  /// In en, this message translates to:
  /// **'Refresh failed: {error}'**
  String cache_refreshFailed(String error);

  /// No description provided for @cache_refreshAll.
  ///
  /// In en, this message translates to:
  /// **'Refresh All'**
  String get cache_refreshAll;

  /// No description provided for @cache_refreshProgress.
  ///
  /// In en, this message translates to:
  /// **'Syncing ({current}/{total}): {name}'**
  String cache_refreshProgress(Object current, Object total, String name);

  /// No description provided for @cache_totalStats.
  ///
  /// In en, this message translates to:
  /// **'{count} groups, {tags} tags total'**
  String cache_totalStats(Object count, Object tags);

  /// No description provided for @addGroup_fetchingCache.
  ///
  /// In en, this message translates to:
  /// **'Fetching data...'**
  String get addGroup_fetchingCache;

  /// No description provided for @addGroup_fetchFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to fetch data, but you can still add the group'**
  String get addGroup_fetchFailed;

  /// No description provided for @addGroup_syncFailed.
  ///
  /// In en, this message translates to:
  /// **'Sync failed, please check network connection and try again'**
  String get addGroup_syncFailed;

  /// No description provided for @addGroup_addFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to add: {error}'**
  String addGroup_addFailed(String error);

  /// No description provided for @addGroup_addCustom.
  ///
  /// In en, this message translates to:
  /// **'Add Custom'**
  String get addGroup_addCustom;

  /// No description provided for @addGroup_filterHint.
  ///
  /// In en, this message translates to:
  /// **'Search cached groups...'**
  String get addGroup_filterHint;

  /// No description provided for @customGroup_title.
  ///
  /// In en, this message translates to:
  /// **'Add Custom Group'**
  String get customGroup_title;

  /// No description provided for @customGroup_searchHint.
  ///
  /// In en, this message translates to:
  /// **'Enter keyword to search Danbooru...'**
  String get customGroup_searchHint;

  /// No description provided for @customGroup_nameLabel.
  ///
  /// In en, this message translates to:
  /// **'Display Name'**
  String get customGroup_nameLabel;

  /// No description provided for @customGroup_add.
  ///
  /// In en, this message translates to:
  /// **'Add & Cache'**
  String get customGroup_add;

  /// No description provided for @customGroup_searchPrompt.
  ///
  /// In en, this message translates to:
  /// **'Enter keyword and search'**
  String get customGroup_searchPrompt;

  /// No description provided for @tagGroup_noCachedData.
  ///
  /// In en, this message translates to:
  /// **'No cached data'**
  String get tagGroup_noCachedData;

  /// No description provided for @tagGroup_syncRequired.
  ///
  /// In en, this message translates to:
  /// **'Sync required'**
  String get tagGroup_syncRequired;

  /// No description provided for @tagGroup_notSynced.
  ///
  /// In en, this message translates to:
  /// **'Not synced'**
  String get tagGroup_notSynced;

  /// No description provided for @tagGroup_lastSyncTime.
  ///
  /// In en, this message translates to:
  /// **'Last sync'**
  String get tagGroup_lastSyncTime;

  /// No description provided for @tagGroup_heatThreshold.
  ///
  /// In en, this message translates to:
  /// **'Heat threshold'**
  String get tagGroup_heatThreshold;

  /// No description provided for @tagGroup_totalStats.
  ///
  /// In en, this message translates to:
  /// **'Total'**
  String get tagGroup_totalStats;

  /// No description provided for @tagGroup_syncedCount.
  ///
  /// In en, this message translates to:
  /// **'{synced}/{total} synced'**
  String tagGroup_syncedCount(Object synced, Object total);

  /// No description provided for @addGroup_dialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Add Dictionary for \"{category}\"'**
  String addGroup_dialogTitle(Object category);

  /// No description provided for @addGroup_builtinTab.
  ///
  /// In en, this message translates to:
  /// **'Built-in'**
  String get addGroup_builtinTab;

  /// No description provided for @addGroup_tagGroupTab.
  ///
  /// In en, this message translates to:
  /// **'Tag Group'**
  String get addGroup_tagGroupTab;

  /// No description provided for @addGroup_cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get addGroup_cancel;

  /// No description provided for @addGroup_submit.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get addGroup_submit;

  /// No description provided for @addGroup_builtinEnabled.
  ///
  /// In en, this message translates to:
  /// **'Built-in Dictionary Enabled'**
  String get addGroup_builtinEnabled;

  /// No description provided for @addGroup_builtinEnabledDesc.
  ///
  /// In en, this message translates to:
  /// **'The built-in dictionary for this category is already in use'**
  String get addGroup_builtinEnabledDesc;

  /// No description provided for @addGroup_enableBuiltin.
  ///
  /// In en, this message translates to:
  /// **'Enable Built-in Dictionary'**
  String get addGroup_enableBuiltin;

  /// No description provided for @addGroup_enableBuiltinDesc.
  ///
  /// In en, this message translates to:
  /// **'Use the app\'s built-in tag dictionary'**
  String get addGroup_enableBuiltinDesc;

  /// No description provided for @addGroup_enable.
  ///
  /// In en, this message translates to:
  /// **'Enable'**
  String get addGroup_enable;

  /// No description provided for @addGroup_backToParent.
  ///
  /// In en, this message translates to:
  /// **'Go back'**
  String get addGroup_backToParent;

  /// No description provided for @addGroup_browseMode.
  ///
  /// In en, this message translates to:
  /// **'Cached List'**
  String get addGroup_browseMode;

  /// No description provided for @addGroup_customMode.
  ///
  /// In en, this message translates to:
  /// **'Add Other'**
  String get addGroup_customMode;

  /// No description provided for @addGroup_allCategories.
  ///
  /// In en, this message translates to:
  /// **'All Categories'**
  String get addGroup_allCategories;

  /// No description provided for @addGroup_noMoreSubcategories.
  ///
  /// In en, this message translates to:
  /// **'No more subcategories'**
  String get addGroup_noMoreSubcategories;

  /// No description provided for @addGroup_tagGroupCount.
  ///
  /// In en, this message translates to:
  /// **'{count} Tag Groups'**
  String addGroup_tagGroupCount(Object count);

  /// No description provided for @addGroup_customInputHint.
  ///
  /// In en, this message translates to:
  /// **'Enter Danbooru tag_group title, e.g.: hair_color'**
  String get addGroup_customInputHint;

  /// No description provided for @addGroup_groupTitleLabel.
  ///
  /// In en, this message translates to:
  /// **'Tag Group Title *'**
  String get addGroup_groupTitleLabel;

  /// No description provided for @addGroup_groupTitleHint.
  ///
  /// In en, this message translates to:
  /// **'e.g.: hair_color or tag_group:hair_color'**
  String get addGroup_groupTitleHint;

  /// No description provided for @addGroup_displayNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Display Name (Optional)'**
  String get addGroup_displayNameLabel;

  /// No description provided for @addGroup_displayNameHint.
  ///
  /// In en, this message translates to:
  /// **'Leave empty to use title'**
  String get addGroup_displayNameHint;

  /// No description provided for @addGroup_targetCategoryLabel.
  ///
  /// In en, this message translates to:
  /// **'Target Category'**
  String get addGroup_targetCategoryLabel;

  /// No description provided for @addGroup_includeChildren.
  ///
  /// In en, this message translates to:
  /// **'Include Sub-groups'**
  String get addGroup_includeChildren;

  /// No description provided for @addGroup_includeChildrenDesc.
  ///
  /// In en, this message translates to:
  /// **'Also fetch tags from all sub-groups of this Tag Group'**
  String get addGroup_includeChildrenDesc;

  /// No description provided for @addGroup_errorEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'Please enter Tag Group title'**
  String get addGroup_errorEmptyTitle;

  /// No description provided for @addGroup_errorGroupExists.
  ///
  /// In en, this message translates to:
  /// **'This Tag Group already exists'**
  String get addGroup_errorGroupExists;

  /// No description provided for @addGroup_sourceTypeLabel.
  ///
  /// In en, this message translates to:
  /// **'Data Source'**
  String get addGroup_sourceTypeLabel;

  /// No description provided for @addGroup_poolTab.
  ///
  /// In en, this message translates to:
  /// **'Danbooru Pool'**
  String get addGroup_poolTab;

  /// No description provided for @addGroup_poolSearchLabel.
  ///
  /// In en, this message translates to:
  /// **'Search Pool'**
  String get addGroup_poolSearchLabel;

  /// No description provided for @addGroup_poolSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Enter pool name to search'**
  String get addGroup_poolSearchHint;

  /// No description provided for @addGroup_poolSearchEmpty.
  ///
  /// In en, this message translates to:
  /// **'Enter keywords to search Danbooru Pools'**
  String get addGroup_poolSearchEmpty;

  /// No description provided for @addGroup_poolSearchError.
  ///
  /// In en, this message translates to:
  /// **'Search failed'**
  String get addGroup_poolSearchError;

  /// No description provided for @addGroup_poolNoResults.
  ///
  /// In en, this message translates to:
  /// **'No matching pools found'**
  String get addGroup_poolNoResults;

  /// No description provided for @addGroup_poolPostCount.
  ///
  /// In en, this message translates to:
  /// **'{count} posts'**
  String addGroup_poolPostCount(Object count);

  /// No description provided for @addGroup_noCachedTagGroups.
  ///
  /// In en, this message translates to:
  /// **'No cached Tag Groups'**
  String get addGroup_noCachedTagGroups;

  /// No description provided for @addGroup_noCachedTagGroupsHint.
  ///
  /// In en, this message translates to:
  /// **'Please sync Tag Group data in Cache Management first'**
  String get addGroup_noCachedTagGroupsHint;

  /// No description provided for @addGroup_noFilterResults.
  ///
  /// In en, this message translates to:
  /// **'No matching results found'**
  String get addGroup_noFilterResults;

  /// No description provided for @addGroup_noCachedPools.
  ///
  /// In en, this message translates to:
  /// **'No cached Pools'**
  String get addGroup_noCachedPools;

  /// No description provided for @addGroup_noCachedPoolsHint.
  ///
  /// In en, this message translates to:
  /// **'Use the search box to search and add Danbooru Pools'**
  String get addGroup_noCachedPoolsHint;

  /// No description provided for @addGroup_sectionTagGroups.
  ///
  /// In en, this message translates to:
  /// **'Tag Groups ☁️'**
  String get addGroup_sectionTagGroups;

  /// No description provided for @addGroup_sectionPools.
  ///
  /// In en, this message translates to:
  /// **'Pools 🖼️'**
  String get addGroup_sectionPools;

  /// No description provided for @globalSettings_title.
  ///
  /// In en, this message translates to:
  /// **'Overview Settings'**
  String get globalSettings_title;

  /// No description provided for @globalSettings_resetToDefault.
  ///
  /// In en, this message translates to:
  /// **'Reset to Default'**
  String get globalSettings_resetToDefault;

  /// No description provided for @globalSettings_characterCountDistribution.
  ///
  /// In en, this message translates to:
  /// **'Character Count Distribution'**
  String get globalSettings_characterCountDistribution;

  /// No description provided for @globalSettings_weightRandomOffset.
  ///
  /// In en, this message translates to:
  /// **'Weight Random Offset'**
  String get globalSettings_weightRandomOffset;

  /// No description provided for @globalSettings_categoryProbabilityOverview.
  ///
  /// In en, this message translates to:
  /// **'Category Probability Overview'**
  String get globalSettings_categoryProbabilityOverview;

  /// No description provided for @globalSettings_cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get globalSettings_cancel;

  /// No description provided for @globalSettings_save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get globalSettings_save;

  /// No description provided for @globalSettings_saveFailed.
  ///
  /// In en, this message translates to:
  /// **'Save failed: {error}'**
  String globalSettings_saveFailed(Object error);

  /// No description provided for @globalSettings_noCharacter.
  ///
  /// In en, this message translates to:
  /// **'None'**
  String get globalSettings_noCharacter;

  /// No description provided for @globalSettings_characterCount.
  ///
  /// In en, this message translates to:
  /// **'{count} character(s)'**
  String globalSettings_characterCount(Object count);

  /// No description provided for @globalSettings_enableWeightRandomOffset.
  ///
  /// In en, this message translates to:
  /// **'Enable Weight Random Offset'**
  String get globalSettings_enableWeightRandomOffset;

  /// No description provided for @globalSettings_enableWeightRandomOffsetDesc.
  ///
  /// In en, this message translates to:
  /// **'Randomly add brackets during generation to simulate human fine-tuning'**
  String get globalSettings_enableWeightRandomOffsetDesc;

  /// No description provided for @globalSettings_bracketType.
  ///
  /// In en, this message translates to:
  /// **'Bracket Type'**
  String get globalSettings_bracketType;

  /// No description provided for @globalSettings_bracketEnhance.
  ///
  /// In en, this message translates to:
  /// **'Curly Braces Enhance'**
  String get globalSettings_bracketEnhance;

  /// No description provided for @globalSettings_bracketWeaken.
  ///
  /// In en, this message translates to:
  /// **'[] Weaken'**
  String get globalSettings_bracketWeaken;

  /// No description provided for @globalSettings_layerRange.
  ///
  /// In en, this message translates to:
  /// **'Layer Range'**
  String get globalSettings_layerRange;

  /// No description provided for @globalSettings_layerRangeValue.
  ///
  /// In en, this message translates to:
  /// **'{min} - {max} layers'**
  String globalSettings_layerRangeValue(Object min, Object max);

  /// No description provided for @globalSettings_category_hairColor.
  ///
  /// In en, this message translates to:
  /// **'Hair Color'**
  String get globalSettings_category_hairColor;

  /// No description provided for @globalSettings_category_eyeColor.
  ///
  /// In en, this message translates to:
  /// **'Eye Color'**
  String get globalSettings_category_eyeColor;

  /// No description provided for @globalSettings_category_hairStyle.
  ///
  /// In en, this message translates to:
  /// **'Hair Style'**
  String get globalSettings_category_hairStyle;

  /// No description provided for @globalSettings_category_expression.
  ///
  /// In en, this message translates to:
  /// **'Expression'**
  String get globalSettings_category_expression;

  /// No description provided for @globalSettings_category_pose.
  ///
  /// In en, this message translates to:
  /// **'Pose'**
  String get globalSettings_category_pose;

  /// No description provided for @globalSettings_category_clothing.
  ///
  /// In en, this message translates to:
  /// **'Clothing'**
  String get globalSettings_category_clothing;

  /// No description provided for @globalSettings_category_accessory.
  ///
  /// In en, this message translates to:
  /// **'Accessory'**
  String get globalSettings_category_accessory;

  /// No description provided for @globalSettings_category_bodyFeature.
  ///
  /// In en, this message translates to:
  /// **'Body Feature'**
  String get globalSettings_category_bodyFeature;

  /// No description provided for @globalSettings_category_background.
  ///
  /// In en, this message translates to:
  /// **'Background'**
  String get globalSettings_category_background;

  /// No description provided for @globalSettings_category_scene.
  ///
  /// In en, this message translates to:
  /// **'Scene'**
  String get globalSettings_category_scene;

  /// No description provided for @globalSettings_category_style.
  ///
  /// In en, this message translates to:
  /// **'Style'**
  String get globalSettings_category_style;

  /// No description provided for @nav_generate.
  ///
  /// In en, this message translates to:
  /// **'Generate'**
  String get nav_generate;

  /// No description provided for @download_completed.
  ///
  /// In en, this message translates to:
  /// **'{name} download completed'**
  String download_completed(Object name);

  /// No description provided for @sync_preparing.
  ///
  /// In en, this message translates to:
  /// **'Preparing to sync...'**
  String get sync_preparing;

  /// No description provided for @sync_fetching.
  ///
  /// In en, this message translates to:
  /// **'Fetching {category}...'**
  String sync_fetching(Object category);

  /// No description provided for @sync_processing.
  ///
  /// In en, this message translates to:
  /// **'Processing data...'**
  String get sync_processing;

  /// No description provided for @sync_saving.
  ///
  /// In en, this message translates to:
  /// **'Saving...'**
  String get sync_saving;

  /// No description provided for @sync_completed.
  ///
  /// In en, this message translates to:
  /// **'Sync completed, {count} tags'**
  String sync_completed(Object count);

  /// No description provided for @sync_failed.
  ///
  /// In en, this message translates to:
  /// **'Sync failed: {error}'**
  String sync_failed(Object error);

  /// No description provided for @sync_extracting.
  ///
  /// In en, this message translates to:
  /// **'Extracting {poolName} tags...'**
  String sync_extracting(Object poolName);

  /// No description provided for @sync_merging.
  ///
  /// In en, this message translates to:
  /// **'Merging tags...'**
  String get sync_merging;

  /// No description provided for @sync_fetching_tags.
  ///
  /// In en, this message translates to:
  /// **'Fetching {groupName} tag popularity...'**
  String sync_fetching_tags(Object groupName);

  /// No description provided for @sync_filtering.
  ///
  /// In en, this message translates to:
  /// **'Filtering tags...'**
  String get sync_filtering;

  /// No description provided for @sync_done.
  ///
  /// In en, this message translates to:
  /// **'Sync completed'**
  String get sync_done;

  /// No description provided for @download_tags_data.
  ///
  /// In en, this message translates to:
  /// **'Downloading tags data...'**
  String get download_tags_data;

  /// No description provided for @download_cooccurrence_data.
  ///
  /// In en, this message translates to:
  /// **'Downloading cooccurrence data...'**
  String get download_cooccurrence_data;

  /// No description provided for @download_parsing_data.
  ///
  /// In en, this message translates to:
  /// **'Parsing data...'**
  String get download_parsing_data;

  /// No description provided for @download_readingFile.
  ///
  /// In en, this message translates to:
  /// **'Reading file...'**
  String get download_readingFile;

  /// No description provided for @download_mergingData.
  ///
  /// In en, this message translates to:
  /// **'Merging data...'**
  String get download_mergingData;

  /// No description provided for @download_loadComplete.
  ///
  /// In en, this message translates to:
  /// **'Loading complete'**
  String get download_loadComplete;

  /// No description provided for @time_just_now.
  ///
  /// In en, this message translates to:
  /// **'Just now'**
  String get time_just_now;

  /// No description provided for @time_minutes_ago.
  ///
  /// In en, this message translates to:
  /// **'{n} minutes ago'**
  String time_minutes_ago(Object n);

  /// No description provided for @time_hours_ago.
  ///
  /// In en, this message translates to:
  /// **'{n} hours ago'**
  String time_hours_ago(Object n);

  /// No description provided for @time_days_ago.
  ///
  /// In en, this message translates to:
  /// **'{n} days ago'**
  String time_days_ago(Object n);

  /// No description provided for @time_never_synced.
  ///
  /// In en, this message translates to:
  /// **'Never synced'**
  String get time_never_synced;

  /// No description provided for @selectionMode_single.
  ///
  /// In en, this message translates to:
  /// **'Single Random'**
  String get selectionMode_single;

  /// No description provided for @selectionMode_multipleNum.
  ///
  /// In en, this message translates to:
  /// **'Multiple Count'**
  String get selectionMode_multipleNum;

  /// No description provided for @selectionMode_multipleProb.
  ///
  /// In en, this message translates to:
  /// **'Multiple Prob'**
  String get selectionMode_multipleProb;

  /// No description provided for @selectionMode_all.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get selectionMode_all;

  /// No description provided for @selectionMode_sequential.
  ///
  /// In en, this message translates to:
  /// **'Sequential'**
  String get selectionMode_sequential;

  /// No description provided for @categorySettings_title.
  ///
  /// In en, this message translates to:
  /// **'Category Settings - {name}'**
  String categorySettings_title(Object name);

  /// No description provided for @categorySettings_probability.
  ///
  /// In en, this message translates to:
  /// **'Category Probability'**
  String get categorySettings_probability;

  /// No description provided for @categorySettings_probabilityDesc.
  ///
  /// In en, this message translates to:
  /// **'Probability of this category participating in random generation'**
  String get categorySettings_probabilityDesc;

  /// No description provided for @categorySettings_groupSelectionMode.
  ///
  /// In en, this message translates to:
  /// **'Group Selection Mode'**
  String get categorySettings_groupSelectionMode;

  /// No description provided for @categorySettings_groupSelectionModeDesc.
  ///
  /// In en, this message translates to:
  /// **'How to select from sub-groups'**
  String get categorySettings_groupSelectionModeDesc;

  /// No description provided for @categorySettings_groupSelectCount.
  ///
  /// In en, this message translates to:
  /// **'Select Count:'**
  String get categorySettings_groupSelectCount;

  /// No description provided for @categorySettings_shuffle.
  ///
  /// In en, this message translates to:
  /// **'Shuffle Order'**
  String get categorySettings_shuffle;

  /// No description provided for @categorySettings_shuffleDesc.
  ///
  /// In en, this message translates to:
  /// **'Randomly arrange selected groups output order'**
  String get categorySettings_shuffleDesc;

  /// No description provided for @categorySettings_unifiedBracket.
  ///
  /// In en, this message translates to:
  /// **'Unified Bracket'**
  String get categorySettings_unifiedBracket;

  /// No description provided for @categorySettings_unifiedBracketDisabled.
  ///
  /// In en, this message translates to:
  /// **'Disabled'**
  String get categorySettings_unifiedBracketDisabled;

  /// No description provided for @categorySettings_enableUnifiedBracket.
  ///
  /// In en, this message translates to:
  /// **'Enable Unified Settings'**
  String get categorySettings_enableUnifiedBracket;

  /// No description provided for @categorySettings_enableUnifiedBracketDesc.
  ///
  /// In en, this message translates to:
  /// **'When enabled, will override each group\'s individual bracket settings'**
  String get categorySettings_enableUnifiedBracketDesc;

  /// No description provided for @categorySettings_bracketRange.
  ///
  /// In en, this message translates to:
  /// **'Bracket Layer Range'**
  String get categorySettings_bracketRange;

  /// No description provided for @categorySettings_bracketMin.
  ///
  /// In en, this message translates to:
  /// **'Min: {count} layers'**
  String categorySettings_bracketMin(Object count);

  /// No description provided for @categorySettings_bracketMax.
  ///
  /// In en, this message translates to:
  /// **'Max: {count} layers'**
  String categorySettings_bracketMax(Object count);

  /// No description provided for @categorySettings_bracketPreview.
  ///
  /// In en, this message translates to:
  /// **'Preview:'**
  String get categorySettings_bracketPreview;

  /// No description provided for @categorySettings_batchSettings.
  ///
  /// In en, this message translates to:
  /// **'Batch Operations'**
  String get categorySettings_batchSettings;

  /// No description provided for @categorySettings_batchSettingsDesc.
  ///
  /// In en, this message translates to:
  /// **'Batch operations for all groups under this category'**
  String get categorySettings_batchSettingsDesc;

  /// No description provided for @categorySettings_enableAllGroups.
  ///
  /// In en, this message translates to:
  /// **'Enable All'**
  String get categorySettings_enableAllGroups;

  /// No description provided for @categorySettings_disableAllGroups.
  ///
  /// In en, this message translates to:
  /// **'Disable All'**
  String get categorySettings_disableAllGroups;

  /// No description provided for @categorySettings_resetGroupSettings.
  ///
  /// In en, this message translates to:
  /// **'Reset Group Settings'**
  String get categorySettings_resetGroupSettings;

  /// No description provided for @categorySettings_batchEnableSuccess.
  ///
  /// In en, this message translates to:
  /// **'All groups enabled'**
  String get categorySettings_batchEnableSuccess;

  /// No description provided for @categorySettings_batchDisableSuccess.
  ///
  /// In en, this message translates to:
  /// **'All groups disabled'**
  String get categorySettings_batchDisableSuccess;

  /// No description provided for @categorySettings_batchResetSuccess.
  ///
  /// In en, this message translates to:
  /// **'All group settings reset'**
  String get categorySettings_batchResetSuccess;

  /// No description provided for @tagGroupSettings_title.
  ///
  /// In en, this message translates to:
  /// **'Group Settings - {name}'**
  String tagGroupSettings_title(Object name);

  /// No description provided for @tagGroupSettings_probability.
  ///
  /// In en, this message translates to:
  /// **'Selection Probability'**
  String get tagGroupSettings_probability;

  /// No description provided for @tagGroupSettings_probabilityDesc.
  ///
  /// In en, this message translates to:
  /// **'Probability of this group being selected'**
  String get tagGroupSettings_probabilityDesc;

  /// No description provided for @tagGroupSettings_selectionMode.
  ///
  /// In en, this message translates to:
  /// **'Selection Mode'**
  String get tagGroupSettings_selectionMode;

  /// No description provided for @tagGroupSettings_selectionModeDesc.
  ///
  /// In en, this message translates to:
  /// **'How to select tags from this group'**
  String get tagGroupSettings_selectionModeDesc;

  /// No description provided for @tagGroupSettings_selectCount.
  ///
  /// In en, this message translates to:
  /// **'Select Count:'**
  String get tagGroupSettings_selectCount;

  /// No description provided for @tagGroupSettings_shuffle.
  ///
  /// In en, this message translates to:
  /// **'Shuffle Order'**
  String get tagGroupSettings_shuffle;

  /// No description provided for @tagGroupSettings_shuffleDesc.
  ///
  /// In en, this message translates to:
  /// **'Randomly arrange selected tags output order'**
  String get tagGroupSettings_shuffleDesc;

  /// No description provided for @tagGroupSettings_bracket.
  ///
  /// In en, this message translates to:
  /// **'Weight Brackets'**
  String get tagGroupSettings_bracket;

  /// No description provided for @tagGroupSettings_bracketDesc.
  ///
  /// In en, this message translates to:
  /// **'Randomly add weight brackets to selected tags, each curly bracket adds ~5% weight'**
  String get tagGroupSettings_bracketDesc;

  /// No description provided for @tagGroupSettings_bracketMin.
  ///
  /// In en, this message translates to:
  /// **'Min: {count} layers'**
  String tagGroupSettings_bracketMin(Object count);

  /// No description provided for @tagGroupSettings_bracketMax.
  ///
  /// In en, this message translates to:
  /// **'Max: {count} layers'**
  String tagGroupSettings_bracketMax(Object count);

  /// No description provided for @tagGroupSettings_bracketPreview.
  ///
  /// In en, this message translates to:
  /// **'Preview:'**
  String get tagGroupSettings_bracketPreview;

  /// No description provided for @categorySettings_settingsButton.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get categorySettings_settingsButton;

  /// No description provided for @tagGroupSettings_settingsButton.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get tagGroupSettings_settingsButton;

  /// No description provided for @promptConfig_tagCountUnit.
  ///
  /// In en, this message translates to:
  /// **'tags'**
  String get promptConfig_tagCountUnit;

  /// No description provided for @promptConfig_removeGroup.
  ///
  /// In en, this message translates to:
  /// **'Remove Group'**
  String get promptConfig_removeGroup;

  /// No description provided for @preset_resetToDefault.
  ///
  /// In en, this message translates to:
  /// **'Reset to Default'**
  String get preset_resetToDefault;

  /// No description provided for @preset_resetConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Reset Preset'**
  String get preset_resetConfirmTitle;

  /// No description provided for @preset_resetConfirmMessage.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to reset all categories and groups in the current preset to default? This action cannot be undone.'**
  String get preset_resetConfirmMessage;

  /// No description provided for @preset_resetSuccess.
  ///
  /// In en, this message translates to:
  /// **'Preset has been reset to default'**
  String get preset_resetSuccess;

  /// No description provided for @newPresetDialog_title.
  ///
  /// In en, this message translates to:
  /// **'Create New Preset'**
  String get newPresetDialog_title;

  /// No description provided for @newPresetDialog_blank.
  ///
  /// In en, this message translates to:
  /// **'Completely Blank'**
  String get newPresetDialog_blank;

  /// No description provided for @newPresetDialog_blankDesc.
  ///
  /// In en, this message translates to:
  /// **'Create preset from scratch with no preset content'**
  String get newPresetDialog_blankDesc;

  /// No description provided for @newPresetDialog_template.
  ///
  /// In en, this message translates to:
  /// **'Based on Default Preset'**
  String get newPresetDialog_template;

  /// No description provided for @newPresetDialog_templateDesc.
  ///
  /// In en, this message translates to:
  /// **'Copy all settings from default preset as starting point'**
  String get newPresetDialog_templateDesc;

  /// No description provided for @category_addNew.
  ///
  /// In en, this message translates to:
  /// **'Add Category'**
  String get category_addNew;

  /// No description provided for @category_dialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Create Category'**
  String get category_dialogTitle;

  /// No description provided for @category_name.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get category_name;

  /// No description provided for @category_nameHint.
  ///
  /// In en, this message translates to:
  /// **'Enter category name'**
  String get category_nameHint;

  /// No description provided for @category_key.
  ///
  /// In en, this message translates to:
  /// **'Key'**
  String get category_key;

  /// No description provided for @category_keyHint.
  ///
  /// In en, this message translates to:
  /// **'Internal identifier'**
  String get category_keyHint;

  /// No description provided for @category_emoji.
  ///
  /// In en, this message translates to:
  /// **'Icon'**
  String get category_emoji;

  /// No description provided for @category_selectEmoji.
  ///
  /// In en, this message translates to:
  /// **'Select Emoji'**
  String get category_selectEmoji;

  /// No description provided for @category_probability.
  ///
  /// In en, this message translates to:
  /// **'Probability'**
  String get category_probability;

  /// No description provided for @category_createSuccess.
  ///
  /// In en, this message translates to:
  /// **'Category created'**
  String get category_createSuccess;

  /// No description provided for @category_nameRequired.
  ///
  /// In en, this message translates to:
  /// **'Name is required'**
  String get category_nameRequired;

  /// No description provided for @category_keyRequired.
  ///
  /// In en, this message translates to:
  /// **'Key is required'**
  String get category_keyRequired;

  /// No description provided for @category_keyExists.
  ///
  /// In en, this message translates to:
  /// **'This key already exists'**
  String get category_keyExists;

  /// No description provided for @group_selectEmoji.
  ///
  /// In en, this message translates to:
  /// **'Select Icon'**
  String get group_selectEmoji;

  /// No description provided for @category_noRecentEmoji.
  ///
  /// In en, this message translates to:
  /// **'No recent emojis'**
  String get category_noRecentEmoji;

  /// No description provided for @category_searchEmoji.
  ///
  /// In en, this message translates to:
  /// **'Search emoji'**
  String get category_searchEmoji;

  /// No description provided for @addGroup_customTab.
  ///
  /// In en, this message translates to:
  /// **'Custom'**
  String get addGroup_customTab;

  /// No description provided for @customGroup_groupName.
  ///
  /// In en, this message translates to:
  /// **'Group Name'**
  String get customGroup_groupName;

  /// No description provided for @customGroup_entryPlaceholder.
  ///
  /// In en, this message translates to:
  /// **'Enter entry and press Enter (supports multiple tags, comma separated)'**
  String get customGroup_entryPlaceholder;

  /// No description provided for @customGroup_noEntries.
  ///
  /// In en, this message translates to:
  /// **'No entries yet, add entries to start'**
  String get customGroup_noEntries;

  /// No description provided for @customGroup_entryCount.
  ///
  /// In en, this message translates to:
  /// **'{count} entries'**
  String customGroup_entryCount(Object count);

  /// No description provided for @customGroup_editEntry.
  ///
  /// In en, this message translates to:
  /// **'Edit Entry'**
  String get customGroup_editEntry;

  /// No description provided for @customGroup_aliasLabel.
  ///
  /// In en, this message translates to:
  /// **'Alias (optional)'**
  String get customGroup_aliasLabel;

  /// No description provided for @customGroup_aliasHint.
  ///
  /// In en, this message translates to:
  /// **'Enter a memorable alias'**
  String get customGroup_aliasHint;

  /// No description provided for @customGroup_contentLabel.
  ///
  /// In en, this message translates to:
  /// **'Prompt Content'**
  String get customGroup_contentLabel;

  /// No description provided for @customGroup_contentHint.
  ///
  /// In en, this message translates to:
  /// **'Enter actual prompt content'**
  String get customGroup_contentHint;

  /// No description provided for @customGroup_save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get customGroup_save;

  /// No description provided for @customGroup_confirm.
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get customGroup_confirm;

  /// No description provided for @customGroup_selectEmoji.
  ///
  /// In en, this message translates to:
  /// **'Select Icon'**
  String get customGroup_selectEmoji;

  /// No description provided for @customGroup_nameRequired.
  ///
  /// In en, this message translates to:
  /// **'Please enter group name'**
  String get customGroup_nameRequired;

  /// No description provided for @customGroup_addEntry.
  ///
  /// In en, this message translates to:
  /// **'Add Entry'**
  String get customGroup_addEntry;

  /// No description provided for @customGroup_noCustomGroups.
  ///
  /// In en, this message translates to:
  /// **'No custom groups yet'**
  String get customGroup_noCustomGroups;

  /// No description provided for @customGroup_createInCacheManager.
  ///
  /// In en, this message translates to:
  /// **'Create custom groups in \"Group Manager\"'**
  String get customGroup_createInCacheManager;

  /// No description provided for @cache_createCustomGroup.
  ///
  /// In en, this message translates to:
  /// **'Create Custom Group'**
  String get cache_createCustomGroup;

  /// No description provided for @cache_confirmDeleteCustomGroup.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete custom group \"{name}\"?'**
  String cache_confirmDeleteCustomGroup(Object name);

  /// No description provided for @cache_customTab.
  ///
  /// In en, this message translates to:
  /// **'Custom'**
  String get cache_customTab;

  /// No description provided for @cache_addFromDanbooru.
  ///
  /// In en, this message translates to:
  /// **'Add from Danbooru'**
  String get cache_addFromDanbooru;

  /// No description provided for @customGroup_emptyStateTitle.
  ///
  /// In en, this message translates to:
  /// **'Start adding entries'**
  String get customGroup_emptyStateTitle;

  /// No description provided for @customGroup_emptyStateHint.
  ///
  /// In en, this message translates to:
  /// **'Type in the input field above and press Enter to add'**
  String get customGroup_emptyStateHint;

  /// No description provided for @common_comingSoon.
  ///
  /// In en, this message translates to:
  /// **'Coming soon...'**
  String get common_comingSoon;

  /// No description provided for @common_openInBrowser.
  ///
  /// In en, this message translates to:
  /// **'Open in browser'**
  String get common_openInBrowser;

  /// No description provided for @customGroup_tagsPlaceholder.
  ///
  /// In en, this message translates to:
  /// **'Enter tags, separated by commas (autocomplete supported)...'**
  String get customGroup_tagsPlaceholder;

  /// No description provided for @characterCountConfig_title.
  ///
  /// In en, this message translates to:
  /// **'Character Count Config'**
  String get characterCountConfig_title;

  /// No description provided for @characterCountConfig_weight.
  ///
  /// In en, this message translates to:
  /// **'Weight'**
  String get characterCountConfig_weight;

  /// No description provided for @characterCountConfig_solo.
  ///
  /// In en, this message translates to:
  /// **'Solo'**
  String get characterCountConfig_solo;

  /// No description provided for @characterCountConfig_duo.
  ///
  /// In en, this message translates to:
  /// **'Duo'**
  String get characterCountConfig_duo;

  /// No description provided for @characterCountConfig_trio.
  ///
  /// In en, this message translates to:
  /// **'Trio'**
  String get characterCountConfig_trio;

  /// No description provided for @characterCountConfig_noHumans.
  ///
  /// In en, this message translates to:
  /// **'No Humans'**
  String get characterCountConfig_noHumans;

  /// No description provided for @characterCountConfig_multiPerson.
  ///
  /// In en, this message translates to:
  /// **'Multi-Person'**
  String get characterCountConfig_multiPerson;

  /// No description provided for @characterCountConfig_customizable.
  ///
  /// In en, this message translates to:
  /// **'Customizable'**
  String get characterCountConfig_customizable;

  /// No description provided for @characterCountConfig_mainPrompt.
  ///
  /// In en, this message translates to:
  /// **'Main Prompt'**
  String get characterCountConfig_mainPrompt;

  /// No description provided for @characterCountConfig_characterPrompt.
  ///
  /// In en, this message translates to:
  /// **'Character Prompt'**
  String get characterCountConfig_characterPrompt;

  /// No description provided for @characterCountConfig_addTagOption.
  ///
  /// In en, this message translates to:
  /// **'Add Character Tag'**
  String get characterCountConfig_addTagOption;

  /// No description provided for @characterCountConfig_addMultiPersonCombo.
  ///
  /// In en, this message translates to:
  /// **'Add Multi-Person Combo'**
  String get characterCountConfig_addMultiPersonCombo;

  /// No description provided for @characterCountConfig_displayName.
  ///
  /// In en, this message translates to:
  /// **'Display Name'**
  String get characterCountConfig_displayName;

  /// No description provided for @characterCountConfig_displayNameHint.
  ///
  /// In en, this message translates to:
  /// **'e.g., Trap'**
  String get characterCountConfig_displayNameHint;

  /// No description provided for @characterCountConfig_mainPromptLabel.
  ///
  /// In en, this message translates to:
  /// **'Main Prompt Tags'**
  String get characterCountConfig_mainPromptLabel;

  /// No description provided for @characterCountConfig_mainPromptHint.
  ///
  /// In en, this message translates to:
  /// **'e.g., solo, 2girls, 1girl 1boy'**
  String get characterCountConfig_mainPromptHint;

  /// No description provided for @characterCountConfig_personCount.
  ///
  /// In en, this message translates to:
  /// **'Person Count:'**
  String get characterCountConfig_personCount;

  /// No description provided for @characterCountConfig_slotConfig.
  ///
  /// In en, this message translates to:
  /// **'Character Slot Config'**
  String get characterCountConfig_slotConfig;

  /// No description provided for @characterCountConfig_slot.
  ///
  /// In en, this message translates to:
  /// **'Slot'**
  String get characterCountConfig_slot;

  /// No description provided for @characterCountConfig_resetToDefault.
  ///
  /// In en, this message translates to:
  /// **'Reset to Default'**
  String get characterCountConfig_resetToDefault;

  /// No description provided for @characterCountConfig_customSlots.
  ///
  /// In en, this message translates to:
  /// **'Custom Slots'**
  String get characterCountConfig_customSlots;

  /// No description provided for @characterCountConfig_customSlotsTitle.
  ///
  /// In en, this message translates to:
  /// **'Character Slot Management'**
  String get characterCountConfig_customSlotsTitle;

  /// No description provided for @characterCountConfig_customSlotsDesc.
  ///
  /// In en, this message translates to:
  /// **'Add or remove available character slot options'**
  String get characterCountConfig_customSlotsDesc;

  /// No description provided for @characterCountConfig_addSlot.
  ///
  /// In en, this message translates to:
  /// **'Add Slot'**
  String get characterCountConfig_addSlot;

  /// No description provided for @characterCountConfig_addSlotHint.
  ///
  /// In en, this message translates to:
  /// **'e.g., 1trap, 1futanari'**
  String get characterCountConfig_addSlotHint;

  /// No description provided for @characterCountConfig_slotExists.
  ///
  /// In en, this message translates to:
  /// **'This slot already exists'**
  String get characterCountConfig_slotExists;

  /// No description provided for @characterCountConfig_cannotDeleteBuiltin.
  ///
  /// In en, this message translates to:
  /// **'Cannot delete built-in slot'**
  String get characterCountConfig_cannotDeleteBuiltin;

  /// No description provided for @genderRestriction_enabled.
  ///
  /// In en, this message translates to:
  /// **'Gender Restriction'**
  String get genderRestriction_enabled;

  /// No description provided for @genderRestriction_enabledDesc.
  ///
  /// In en, this message translates to:
  /// **'Gender filter not enabled'**
  String get genderRestriction_enabledDesc;

  /// No description provided for @genderRestriction_enabledActive.
  ///
  /// In en, this message translates to:
  /// **'Enabled, {count} genders available'**
  String genderRestriction_enabledActive(Object count);

  /// No description provided for @genderRestriction_enable.
  ///
  /// In en, this message translates to:
  /// **'Enable Gender Restriction'**
  String get genderRestriction_enable;

  /// No description provided for @genderRestriction_enableDesc.
  ///
  /// In en, this message translates to:
  /// **'Only apply to characters of specified genders'**
  String get genderRestriction_enableDesc;

  /// No description provided for @genderRestriction_applicableGenders.
  ///
  /// In en, this message translates to:
  /// **'Applicable Genders'**
  String get genderRestriction_applicableGenders;

  /// No description provided for @gender_female.
  ///
  /// In en, this message translates to:
  /// **'Female'**
  String get gender_female;

  /// No description provided for @gender_male.
  ///
  /// In en, this message translates to:
  /// **'Male'**
  String get gender_male;

  /// No description provided for @gender_trap.
  ///
  /// In en, this message translates to:
  /// **'Trap'**
  String get gender_trap;

  /// No description provided for @gender_futanari.
  ///
  /// In en, this message translates to:
  /// **'Futanari'**
  String get gender_futanari;

  /// No description provided for @scope_title.
  ///
  /// In en, this message translates to:
  /// **'Scope'**
  String get scope_title;

  /// No description provided for @scope_titleDesc.
  ///
  /// In en, this message translates to:
  /// **'Set the applicable scope of this category/group'**
  String get scope_titleDesc;

  /// No description provided for @scope_global.
  ///
  /// In en, this message translates to:
  /// **'Main'**
  String get scope_global;

  /// No description provided for @scope_globalTooltip.
  ///
  /// In en, this message translates to:
  /// **'Prompt will appear in main prompt area\nSuitable for: background, scene, style, etc.'**
  String get scope_globalTooltip;

  /// No description provided for @scope_character.
  ///
  /// In en, this message translates to:
  /// **'Char'**
  String get scope_character;

  /// No description provided for @scope_characterTooltip.
  ///
  /// In en, this message translates to:
  /// **'Prompt will only appear in character prompts\nGenerated separately for each character\nSuitable for: hair color, eye color, clothing, expression, etc.'**
  String get scope_characterTooltip;

  /// No description provided for @scope_all.
  ///
  /// In en, this message translates to:
  /// **'Both'**
  String get scope_all;

  /// No description provided for @scope_allTooltip.
  ///
  /// In en, this message translates to:
  /// **'Prompt appears in both main and character prompts\nSuitable for: pose, interaction, and other universal tags'**
  String get scope_allTooltip;

  /// No description provided for @tagGroupSettings_resetToCategory.
  ///
  /// In en, this message translates to:
  /// **'Reset to Category Settings'**
  String get tagGroupSettings_resetToCategory;

  /// No description provided for @bracket_weaken.
  ///
  /// In en, this message translates to:
  /// **'weaken'**
  String get bracket_weaken;

  /// No description provided for @bracket_enhance.
  ///
  /// In en, this message translates to:
  /// **'enhance'**
  String get bracket_enhance;

  /// No description provided for @vibeNoEncodingWarning.
  ///
  /// In en, this message translates to:
  /// **'This image has no pre-encoded data'**
  String get vibeNoEncodingWarning;

  /// No description provided for @vibeWillCostAnlas.
  ///
  /// In en, this message translates to:
  /// **'Encoding will cost {count} Anlas'**
  String vibeWillCostAnlas(int count);

  /// No description provided for @vibeEncodeConfirm.
  ///
  /// In en, this message translates to:
  /// **'Continue and consume Anlas?'**
  String get vibeEncodeConfirm;

  /// No description provided for @vibeCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get vibeCancel;

  /// No description provided for @vibeConfirmEncode.
  ///
  /// In en, this message translates to:
  /// **'Encode'**
  String get vibeConfirmEncode;

  /// No description provided for @vibeParseFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to parse Vibe file'**
  String get vibeParseFailed;

  /// No description provided for @tagGroupBrowser_searchHint.
  ///
  /// In en, this message translates to:
  /// **'Search tags...'**
  String get tagGroupBrowser_searchHint;

  /// No description provided for @tagGroupBrowser_tagCount.
  ///
  /// In en, this message translates to:
  /// **'{count} tags'**
  String tagGroupBrowser_tagCount(Object count);

  /// No description provided for @tagGroupBrowser_filteredTagCount.
  ///
  /// In en, this message translates to:
  /// **'Showing {filtered} of {total} tags'**
  String tagGroupBrowser_filteredTagCount(Object filtered, Object total);

  /// No description provided for @tagGroupBrowser_noTags.
  ///
  /// In en, this message translates to:
  /// **'No tags'**
  String get tagGroupBrowser_noTags;

  /// No description provided for @tagGroupBrowser_noLibrary.
  ///
  /// In en, this message translates to:
  /// **'Tag library not loaded'**
  String get tagGroupBrowser_noLibrary;

  /// No description provided for @tagGroupBrowser_importLibraryHint.
  ///
  /// In en, this message translates to:
  /// **'Please import a tag library first'**
  String get tagGroupBrowser_importLibraryHint;

  /// No description provided for @tagGroupBrowser_noCategories.
  ///
  /// In en, this message translates to:
  /// **'No enabled tag categories'**
  String get tagGroupBrowser_noCategories;

  /// No description provided for @tagGroupBrowser_enableCategoriesHint.
  ///
  /// In en, this message translates to:
  /// **'Please enable tag categories in settings'**
  String get tagGroupBrowser_enableCategoriesHint;

  /// No description provided for @tagGroupBrowser_danbooruSuggestions.
  ///
  /// In en, this message translates to:
  /// **'Danbooru Suggestions'**
  String get tagGroupBrowser_danbooruSuggestions;

  /// No description provided for @tag_favoritesTitle.
  ///
  /// In en, this message translates to:
  /// **'Favorite Tags'**
  String get tag_favoritesTitle;

  /// No description provided for @tag_favoritesEmpty.
  ///
  /// In en, this message translates to:
  /// **'No favorite tags yet'**
  String get tag_favoritesEmpty;

  /// No description provided for @tag_favoritesEmptyHint.
  ///
  /// In en, this message translates to:
  /// **'Long-press on a tag to add it to favorites'**
  String get tag_favoritesEmptyHint;

  /// No description provided for @tag_alreadyAdded.
  ///
  /// In en, this message translates to:
  /// **'Tag already added to current prompt'**
  String get tag_alreadyAdded;

  /// No description provided for @tag_removeFavoriteTitle.
  ///
  /// In en, this message translates to:
  /// **'Remove from Favorites'**
  String get tag_removeFavoriteTitle;

  /// No description provided for @tag_removeFavoriteMessage.
  ///
  /// In en, this message translates to:
  /// **'Remove \"{tag}\" from favorites?'**
  String tag_removeFavoriteMessage(Object tag);

  /// No description provided for @tag_templatesTitle.
  ///
  /// In en, this message translates to:
  /// **'Tag Templates'**
  String get tag_templatesTitle;

  /// No description provided for @tag_templatesEmpty.
  ///
  /// In en, this message translates to:
  /// **'No tag templates yet'**
  String get tag_templatesEmpty;

  /// No description provided for @tag_templatesEmptyHint.
  ///
  /// In en, this message translates to:
  /// **'Select tags and click the + button to create a template'**
  String get tag_templatesEmptyHint;

  /// No description provided for @tag_templateCreate.
  ///
  /// In en, this message translates to:
  /// **'Create Template'**
  String get tag_templateCreate;

  /// No description provided for @tag_templateNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Template Name'**
  String get tag_templateNameLabel;

  /// No description provided for @tag_templateNameHint.
  ///
  /// In en, this message translates to:
  /// **'Enter template name'**
  String get tag_templateNameHint;

  /// No description provided for @tag_templateNameRequired.
  ///
  /// In en, this message translates to:
  /// **'Please enter a template name'**
  String get tag_templateNameRequired;

  /// No description provided for @tag_templateDescLabel.
  ///
  /// In en, this message translates to:
  /// **'Description (Optional)'**
  String get tag_templateDescLabel;

  /// No description provided for @tag_templateDescHint.
  ///
  /// In en, this message translates to:
  /// **'Enter template description'**
  String get tag_templateDescHint;

  /// No description provided for @tag_templatePreview.
  ///
  /// In en, this message translates to:
  /// **'Tag Preview'**
  String get tag_templatePreview;

  /// No description provided for @tag_templateTagCount.
  ///
  /// In en, this message translates to:
  /// **'{count} tags'**
  String tag_templateTagCount(Object count);

  /// No description provided for @tag_templateMoreTags.
  ///
  /// In en, this message translates to:
  /// **'{count} more tags...'**
  String tag_templateMoreTags(Object count);

  /// No description provided for @tag_templateInserted.
  ///
  /// In en, this message translates to:
  /// **'Inserted template \"{name}\"'**
  String tag_templateInserted(Object name);

  /// No description provided for @tag_templateNoTags.
  ///
  /// In en, this message translates to:
  /// **'No tags to save'**
  String get tag_templateNoTags;

  /// No description provided for @tag_templateSaved.
  ///
  /// In en, this message translates to:
  /// **'Template saved'**
  String get tag_templateSaved;

  /// No description provided for @tag_templateNameExists.
  ///
  /// In en, this message translates to:
  /// **'Template name already exists'**
  String get tag_templateNameExists;

  /// No description provided for @tag_templateDeleteTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete Template'**
  String get tag_templateDeleteTitle;

  /// No description provided for @tag_templateDeleteMessage.
  ///
  /// In en, this message translates to:
  /// **'Delete template \"{name}\"?'**
  String tag_templateDeleteMessage(Object name);

  /// No description provided for @tag_tabTags.
  ///
  /// In en, this message translates to:
  /// **'Tags'**
  String get tag_tabTags;

  /// No description provided for @tag_tabGroups.
  ///
  /// In en, this message translates to:
  /// **'Groups'**
  String get tag_tabGroups;

  /// No description provided for @tag_tabFavorites.
  ///
  /// In en, this message translates to:
  /// **'Favorites'**
  String get tag_tabFavorites;

  /// No description provided for @tag_tabTemplates.
  ///
  /// In en, this message translates to:
  /// **'Templates'**
  String get tag_tabTemplates;

  /// No description provided for @tag_categoryGeneral.
  ///
  /// In en, this message translates to:
  /// **'General'**
  String get tag_categoryGeneral;

  /// No description provided for @tag_categoryArtist.
  ///
  /// In en, this message translates to:
  /// **'Artist'**
  String get tag_categoryArtist;

  /// No description provided for @tag_categoryCopyright.
  ///
  /// In en, this message translates to:
  /// **'Copyright'**
  String get tag_categoryCopyright;

  /// No description provided for @tag_categoryCharacter.
  ///
  /// In en, this message translates to:
  /// **'Character'**
  String get tag_categoryCharacter;

  /// No description provided for @tag_categoryMeta.
  ///
  /// In en, this message translates to:
  /// **'Meta'**
  String get tag_categoryMeta;

  /// No description provided for @tag_countBadgeTooltip.
  ///
  /// In en, this message translates to:
  /// **'Total {total} tags'**
  String tag_countBadgeTooltip(Object total);

  /// No description provided for @tag_countBadgeBreakdown.
  ///
  /// In en, this message translates to:
  /// **'Tag Breakdown'**
  String get tag_countBadgeBreakdown;

  /// No description provided for @tag_countEnabled.
  ///
  /// In en, this message translates to:
  /// **'{count} enabled'**
  String tag_countEnabled(Object count);

  /// No description provided for @localGallery_searchIndexing.
  ///
  /// In en, this message translates to:
  /// **'Building search index...'**
  String get localGallery_searchIndexing;

  /// No description provided for @localGallery_searchIndexComplete.
  ///
  /// In en, this message translates to:
  /// **'Search index ready'**
  String get localGallery_searchIndexComplete;

  /// No description provided for @localGallery_searchIndexFailed.
  ///
  /// In en, this message translates to:
  /// **'Search index error'**
  String get localGallery_searchIndexFailed;

  /// No description provided for @localGallery_cacheStatus.
  ///
  /// In en, this message translates to:
  /// **'Cache: {current}/{max} images'**
  String localGallery_cacheStatus(Object current, Object max);

  /// No description provided for @localGallery_cacheHitRate.
  ///
  /// In en, this message translates to:
  /// **'Hit rate: {rate}%'**
  String localGallery_cacheHitRate(Object rate);

  /// No description provided for @localGallery_preloading.
  ///
  /// In en, this message translates to:
  /// **'Preloading images...'**
  String get localGallery_preloading;

  /// No description provided for @localGallery_preloadComplete.
  ///
  /// In en, this message translates to:
  /// **'Preload complete'**
  String get localGallery_preloadComplete;

  /// No description provided for @localGallery_progressiveLoadError.
  ///
  /// In en, this message translates to:
  /// **'Failed to load image'**
  String get localGallery_progressiveLoadError;

  /// No description provided for @localGallery_noImagesFound.
  ///
  /// In en, this message translates to:
  /// **'No images found'**
  String get localGallery_noImagesFound;

  /// No description provided for @localGallery_searchPlaceholder.
  ///
  /// In en, this message translates to:
  /// **'Search prompts, models, samplers...'**
  String get localGallery_searchPlaceholder;

  /// No description provided for @localGallery_filterByDate.
  ///
  /// In en, this message translates to:
  /// **'Filter by date'**
  String get localGallery_filterByDate;

  /// No description provided for @localGallery_clearFilters.
  ///
  /// In en, this message translates to:
  /// **'Clear filters'**
  String get localGallery_clearFilters;

  /// No description provided for @slideshow_title.
  ///
  /// In en, this message translates to:
  /// **'Slideshow'**
  String get slideshow_title;

  /// No description provided for @slideshow_of.
  ///
  /// In en, this message translates to:
  /// **'of'**
  String get slideshow_of;

  /// No description provided for @slideshow_play.
  ///
  /// In en, this message translates to:
  /// **'Play'**
  String get slideshow_play;

  /// No description provided for @slideshow_pause.
  ///
  /// In en, this message translates to:
  /// **'Pause'**
  String get slideshow_pause;

  /// No description provided for @slideshow_previous.
  ///
  /// In en, this message translates to:
  /// **'Previous'**
  String get slideshow_previous;

  /// No description provided for @slideshow_next.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get slideshow_next;

  /// No description provided for @slideshow_exit.
  ///
  /// In en, this message translates to:
  /// **'Exit (Esc)'**
  String get slideshow_exit;

  /// No description provided for @slideshow_noImages.
  ///
  /// In en, this message translates to:
  /// **'No images to display'**
  String get slideshow_noImages;

  /// No description provided for @slideshow_keyboardHint.
  ///
  /// In en, this message translates to:
  /// **'Use ← → to navigate, Space to play/pause, Esc to exit'**
  String get slideshow_keyboardHint;

  /// No description provided for @slideshow_autoPlayInterval.
  ///
  /// In en, this message translates to:
  /// **'Auto-play interval: {seconds}s'**
  String slideshow_autoPlayInterval(Object seconds);

  /// No description provided for @comparison_title.
  ///
  /// In en, this message translates to:
  /// **'Image Comparison'**
  String get comparison_title;

  /// No description provided for @comparison_noImages.
  ///
  /// In en, this message translates to:
  /// **'No images to display'**
  String get comparison_noImages;

  /// No description provided for @comparison_tooManyImages.
  ///
  /// In en, this message translates to:
  /// **'Too many images'**
  String get comparison_tooManyImages;

  /// No description provided for @comparison_maxImages.
  ///
  /// In en, this message translates to:
  /// **'Maximum 4 images allowed for comparison'**
  String get comparison_maxImages;

  /// No description provided for @comparison_close.
  ///
  /// In en, this message translates to:
  /// **'Close comparison'**
  String get comparison_close;

  /// No description provided for @comparison_zoomHint.
  ///
  /// In en, this message translates to:
  /// **'Pinch or scroll to zoom independently'**
  String get comparison_zoomHint;

  /// No description provided for @comparison_loadError.
  ///
  /// In en, this message translates to:
  /// **'Failed to load image'**
  String get comparison_loadError;

  /// No description provided for @statistics_title.
  ///
  /// In en, this message translates to:
  /// **'Statistics'**
  String get statistics_title;

  /// No description provided for @statistics_tabOverview.
  ///
  /// In en, this message translates to:
  /// **'Overview'**
  String get statistics_tabOverview;

  /// No description provided for @statistics_tabTrends.
  ///
  /// In en, this message translates to:
  /// **'Trends'**
  String get statistics_tabTrends;

  /// No description provided for @statistics_tabDetails.
  ///
  /// In en, this message translates to:
  /// **'Details'**
  String get statistics_tabDetails;

  /// No description provided for @statistics_noData.
  ///
  /// In en, this message translates to:
  /// **'No statistics available'**
  String get statistics_noData;

  /// No description provided for @statistics_generatedCount.
  ///
  /// In en, this message translates to:
  /// **'Generated'**
  String get statistics_generatedCount;

  /// No description provided for @statistics_favoriteCount.
  ///
  /// In en, this message translates to:
  /// **'Favorites'**
  String get statistics_favoriteCount;

  /// No description provided for @statistics_tooltipGenerated.
  ///
  /// In en, this message translates to:
  /// **'Generated: {count}'**
  String statistics_tooltipGenerated(Object count);

  /// No description provided for @statistics_tooltipFavorite.
  ///
  /// In en, this message translates to:
  /// **'Favorites: {count}'**
  String statistics_tooltipFavorite(Object count);

  /// No description provided for @statistics_noTagData.
  ///
  /// In en, this message translates to:
  /// **'No tag data'**
  String get statistics_noTagData;

  /// No description provided for @statistics_generateFirst.
  ///
  /// In en, this message translates to:
  /// **'Generate some images first'**
  String get statistics_generateFirst;

  /// No description provided for @statistics_overview.
  ///
  /// In en, this message translates to:
  /// **'Overview'**
  String get statistics_overview;

  /// No description provided for @statistics_totalImages.
  ///
  /// In en, this message translates to:
  /// **'Total Images'**
  String get statistics_totalImages;

  /// No description provided for @statistics_totalSize.
  ///
  /// In en, this message translates to:
  /// **'Total Size'**
  String get statistics_totalSize;

  /// No description provided for @statistics_favorites.
  ///
  /// In en, this message translates to:
  /// **'Favorites'**
  String get statistics_favorites;

  /// No description provided for @statistics_tagged.
  ///
  /// In en, this message translates to:
  /// **'Tagged'**
  String get statistics_tagged;

  /// No description provided for @statistics_modelDistribution.
  ///
  /// In en, this message translates to:
  /// **'Model Distribution'**
  String get statistics_modelDistribution;

  /// No description provided for @statistics_resolutionDistribution.
  ///
  /// In en, this message translates to:
  /// **'Resolution Distribution'**
  String get statistics_resolutionDistribution;

  /// No description provided for @statistics_samplerDistribution.
  ///
  /// In en, this message translates to:
  /// **'Sampler Distribution'**
  String get statistics_samplerDistribution;

  /// No description provided for @statistics_sizeDistribution.
  ///
  /// In en, this message translates to:
  /// **'File Size Distribution'**
  String get statistics_sizeDistribution;

  /// No description provided for @statistics_additionalStats.
  ///
  /// In en, this message translates to:
  /// **'Additional Statistics'**
  String get statistics_additionalStats;

  /// No description provided for @statistics_averageFileSize.
  ///
  /// In en, this message translates to:
  /// **'Average File Size'**
  String get statistics_averageFileSize;

  /// No description provided for @statistics_withMetadata.
  ///
  /// In en, this message translates to:
  /// **'Images with Metadata'**
  String get statistics_withMetadata;

  /// No description provided for @statistics_calculatedAt.
  ///
  /// In en, this message translates to:
  /// **'Calculated At'**
  String get statistics_calculatedAt;

  /// No description provided for @statistics_justNow.
  ///
  /// In en, this message translates to:
  /// **'Just now'**
  String get statistics_justNow;

  /// No description provided for @statistics_minutesAgo.
  ///
  /// In en, this message translates to:
  /// **'{count} minutes ago'**
  String statistics_minutesAgo(Object count);

  /// No description provided for @statistics_hoursAgo.
  ///
  /// In en, this message translates to:
  /// **'{count} hours ago'**
  String statistics_hoursAgo(Object count);

  /// No description provided for @statistics_daysAgo.
  ///
  /// In en, this message translates to:
  /// **'{count} days ago'**
  String statistics_daysAgo(Object count);

  /// No description provided for @statistics_anlasCost.
  ///
  /// In en, this message translates to:
  /// **'Anlas Cost'**
  String get statistics_anlasCost;

  /// No description provided for @statistics_totalAnlasCost.
  ///
  /// In en, this message translates to:
  /// **'Total Cost'**
  String get statistics_totalAnlasCost;

  /// No description provided for @statistics_avgDailyCost.
  ///
  /// In en, this message translates to:
  /// **'Daily Average'**
  String get statistics_avgDailyCost;

  /// No description provided for @statistics_noAnlasData.
  ///
  /// In en, this message translates to:
  /// **'No Anlas consumption data'**
  String get statistics_noAnlasData;

  /// No description provided for @statistics_peakActivity.
  ///
  /// In en, this message translates to:
  /// **'Peak Activity'**
  String get statistics_peakActivity;

  /// No description provided for @statistics_timeMorning.
  ///
  /// In en, this message translates to:
  /// **'Morning'**
  String get statistics_timeMorning;

  /// No description provided for @statistics_timeAfternoon.
  ///
  /// In en, this message translates to:
  /// **'Afternoon'**
  String get statistics_timeAfternoon;

  /// No description provided for @statistics_timeEvening.
  ///
  /// In en, this message translates to:
  /// **'Evening'**
  String get statistics_timeEvening;

  /// No description provided for @statistics_timeNight.
  ///
  /// In en, this message translates to:
  /// **'Night'**
  String get statistics_timeNight;

  /// No description provided for @localGallery_favoritesOnly.
  ///
  /// In en, this message translates to:
  /// **'Favorites Only'**
  String get localGallery_favoritesOnly;

  /// No description provided for @localGallery_noFavorites.
  ///
  /// In en, this message translates to:
  /// **'No favorites yet'**
  String get localGallery_noFavorites;

  /// No description provided for @localGallery_markAsFavorite.
  ///
  /// In en, this message translates to:
  /// **'Mark as Favorite'**
  String get localGallery_markAsFavorite;

  /// No description provided for @localGallery_removeFromFavorites.
  ///
  /// In en, this message translates to:
  /// **'Remove from Favorites'**
  String get localGallery_removeFromFavorites;

  /// No description provided for @localGallery_tags.
  ///
  /// In en, this message translates to:
  /// **'Tags'**
  String get localGallery_tags;

  /// No description provided for @localGallery_addTag.
  ///
  /// In en, this message translates to:
  /// **'Add Tag'**
  String get localGallery_addTag;

  /// No description provided for @localGallery_removeTag.
  ///
  /// In en, this message translates to:
  /// **'Remove Tag'**
  String get localGallery_removeTag;

  /// No description provided for @localGallery_noTags.
  ///
  /// In en, this message translates to:
  /// **'No tags'**
  String get localGallery_noTags;

  /// No description provided for @localGallery_filterByTags.
  ///
  /// In en, this message translates to:
  /// **'Filter by Tags'**
  String get localGallery_filterByTags;

  /// No description provided for @localGallery_selectTags.
  ///
  /// In en, this message translates to:
  /// **'Select Tags'**
  String get localGallery_selectTags;

  /// No description provided for @localGallery_tagFilterMatchAll.
  ///
  /// In en, this message translates to:
  /// **'Match All Tags'**
  String get localGallery_tagFilterMatchAll;

  /// No description provided for @localGallery_tagFilterMatchAny.
  ///
  /// In en, this message translates to:
  /// **'Match Any Tag'**
  String get localGallery_tagFilterMatchAny;

  /// No description provided for @localGallery_clearTagFilter.
  ///
  /// In en, this message translates to:
  /// **'Clear Tag Filter'**
  String get localGallery_clearTagFilter;

  /// No description provided for @localGallery_noTagsFound.
  ///
  /// In en, this message translates to:
  /// **'No tags found'**
  String get localGallery_noTagsFound;

  /// No description provided for @localGallery_advancedFilters.
  ///
  /// In en, this message translates to:
  /// **'Advanced Filters'**
  String get localGallery_advancedFilters;

  /// No description provided for @localGallery_filterByModel.
  ///
  /// In en, this message translates to:
  /// **'Filter by Model'**
  String get localGallery_filterByModel;

  /// No description provided for @localGallery_filterBySampler.
  ///
  /// In en, this message translates to:
  /// **'Filter by Sampler'**
  String get localGallery_filterBySampler;

  /// No description provided for @localGallery_filterBySteps.
  ///
  /// In en, this message translates to:
  /// **'Filter by Steps'**
  String get localGallery_filterBySteps;

  /// No description provided for @localGallery_filterByCfg.
  ///
  /// In en, this message translates to:
  /// **'Filter by CFG Scale'**
  String get localGallery_filterByCfg;

  /// No description provided for @localGallery_filterByResolution.
  ///
  /// In en, this message translates to:
  /// **'Filter by Resolution'**
  String get localGallery_filterByResolution;

  /// No description provided for @localGallery_model.
  ///
  /// In en, this message translates to:
  /// **'Model'**
  String get localGallery_model;

  /// No description provided for @localGallery_sampler.
  ///
  /// In en, this message translates to:
  /// **'Sampler'**
  String get localGallery_sampler;

  /// No description provided for @localGallery_steps.
  ///
  /// In en, this message translates to:
  /// **'Steps'**
  String get localGallery_steps;

  /// No description provided for @localGallery_cfgScale.
  ///
  /// In en, this message translates to:
  /// **'CFG Scale'**
  String get localGallery_cfgScale;

  /// No description provided for @localGallery_resolution.
  ///
  /// In en, this message translates to:
  /// **'Resolution'**
  String get localGallery_resolution;

  /// No description provided for @localGallery_any.
  ///
  /// In en, this message translates to:
  /// **'Any'**
  String get localGallery_any;

  /// No description provided for @localGallery_custom.
  ///
  /// In en, this message translates to:
  /// **'Custom'**
  String get localGallery_custom;

  /// No description provided for @localGallery_to.
  ///
  /// In en, this message translates to:
  /// **'to'**
  String get localGallery_to;

  /// No description provided for @localGallery_applyFilters.
  ///
  /// In en, this message translates to:
  /// **'Apply Filters'**
  String get localGallery_applyFilters;

  /// No description provided for @localGallery_resetAdvancedFilters.
  ///
  /// In en, this message translates to:
  /// **'Reset Advanced Filters'**
  String get localGallery_resetAdvancedFilters;

  /// No description provided for @localGallery_exportMetadata.
  ///
  /// In en, this message translates to:
  /// **'Export Metadata'**
  String get localGallery_exportMetadata;

  /// No description provided for @localGallery_exportSelected.
  ///
  /// In en, this message translates to:
  /// **'Export Selected'**
  String get localGallery_exportSelected;

  /// No description provided for @localGallery_exportFailed.
  ///
  /// In en, this message translates to:
  /// **'Export failed'**
  String get localGallery_exportFailed;

  /// No description provided for @localGallery_exporting.
  ///
  /// In en, this message translates to:
  /// **'Exporting...'**
  String get localGallery_exporting;

  /// No description provided for @localGallery_selectToExport.
  ///
  /// In en, this message translates to:
  /// **'Select images to export'**
  String get localGallery_selectToExport;

  /// No description provided for @localGallery_noImagesSelected.
  ///
  /// In en, this message translates to:
  /// **'No images selected'**
  String get localGallery_noImagesSelected;

  /// No description provided for @localGallery_exportSuccessDetail.
  ///
  /// In en, this message translates to:
  /// **'Exported {count} images with metadata'**
  String localGallery_exportSuccessDetail(Object count);

  /// No description provided for @bulkExport_title.
  ///
  /// In en, this message translates to:
  /// **'Export {count} images'**
  String bulkExport_title(Object count);

  /// No description provided for @bulkExport_format.
  ///
  /// In en, this message translates to:
  /// **'Format'**
  String get bulkExport_format;

  /// No description provided for @bulkExport_jsonFormat.
  ///
  /// In en, this message translates to:
  /// **'JSON'**
  String get bulkExport_jsonFormat;

  /// No description provided for @bulkExport_csvFormat.
  ///
  /// In en, this message translates to:
  /// **'CSV'**
  String get bulkExport_csvFormat;

  /// No description provided for @bulkExport_metadataOptions.
  ///
  /// In en, this message translates to:
  /// **'Metadata Options'**
  String get bulkExport_metadataOptions;

  /// No description provided for @bulkExport_includeMetadata.
  ///
  /// In en, this message translates to:
  /// **'Include metadata'**
  String get bulkExport_includeMetadata;

  /// No description provided for @bulkExport_includeMetadataHint.
  ///
  /// In en, this message translates to:
  /// **'Export generation parameters with images'**
  String get bulkExport_includeMetadataHint;

  /// No description provided for @localGallery_group_today.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get localGallery_group_today;

  /// No description provided for @localGallery_group_yesterday.
  ///
  /// In en, this message translates to:
  /// **'Yesterday'**
  String get localGallery_group_yesterday;

  /// No description provided for @localGallery_group_thisWeek.
  ///
  /// In en, this message translates to:
  /// **'This Week'**
  String get localGallery_group_thisWeek;

  /// No description provided for @localGallery_group_earlier.
  ///
  /// In en, this message translates to:
  /// **'Earlier'**
  String get localGallery_group_earlier;

  /// No description provided for @localGallery_group_dateFormat.
  ///
  /// In en, this message translates to:
  /// **'MMM dd'**
  String get localGallery_group_dateFormat;

  /// No description provided for @localGallery_jumpToDate.
  ///
  /// In en, this message translates to:
  /// **'Jump to Date'**
  String get localGallery_jumpToDate;

  /// No description provided for @localGallery_noImagesOnThisDate.
  ///
  /// In en, this message translates to:
  /// **'No images on this date'**
  String get localGallery_noImagesOnThisDate;

  /// No description provided for @localGallery_selectedImagesNoPrompt.
  ///
  /// In en, this message translates to:
  /// **'Selected images have no prompt information'**
  String get localGallery_selectedImagesNoPrompt;

  /// No description provided for @localGallery_addedTasksToQueue.
  ///
  /// In en, this message translates to:
  /// **'Added {count} tasks to queue'**
  String localGallery_addedTasksToQueue(Object count);

  /// No description provided for @localGallery_cannotOpenFolder.
  ///
  /// In en, this message translates to:
  /// **'Cannot open folder: {error}'**
  String localGallery_cannotOpenFolder(Object error);

  /// No description provided for @localGallery_jumpedToDate.
  ///
  /// In en, this message translates to:
  /// **'Jumped to {date}'**
  String localGallery_jumpedToDate(Object date);

  /// No description provided for @localGallery_permissionRequiredTitle.
  ///
  /// In en, this message translates to:
  /// **'Storage Permission Required'**
  String get localGallery_permissionRequiredTitle;

  /// No description provided for @localGallery_permissionRequiredContent.
  ///
  /// In en, this message translates to:
  /// **'Local gallery needs storage permission to scan your generated images.\n\nPlease grant permission in settings and try again.'**
  String get localGallery_permissionRequiredContent;

  /// No description provided for @localGallery_openSettings.
  ///
  /// In en, this message translates to:
  /// **'Open Settings'**
  String get localGallery_openSettings;

  /// No description provided for @localGallery_firstTimeTipTitle.
  ///
  /// In en, this message translates to:
  /// **'💡 Tips'**
  String get localGallery_firstTimeTipTitle;

  /// No description provided for @localGallery_firstTimeTipContent.
  ///
  /// In en, this message translates to:
  /// **'Right-click (desktop) or long-press (mobile) on images to:\n\n• Copy Prompt\n• Copy Seed\n• View full metadata'**
  String get localGallery_firstTimeTipContent;

  /// No description provided for @localGallery_gotIt.
  ///
  /// In en, this message translates to:
  /// **'Got it'**
  String get localGallery_gotIt;

  /// No description provided for @localGallery_undone.
  ///
  /// In en, this message translates to:
  /// **'Undone'**
  String get localGallery_undone;

  /// No description provided for @localGallery_redone.
  ///
  /// In en, this message translates to:
  /// **'Redone'**
  String get localGallery_redone;

  /// No description provided for @localGallery_confirmBulkDelete.
  ///
  /// In en, this message translates to:
  /// **'Confirm Bulk Delete'**
  String get localGallery_confirmBulkDelete;

  /// No description provided for @localGallery_confirmBulkDeleteContent.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete {count} selected images?\n\nThis will permanently remove them from the file system and cannot be undone.'**
  String localGallery_confirmBulkDeleteContent(Object count);

  /// No description provided for @localGallery_deletedImages.
  ///
  /// In en, this message translates to:
  /// **'Deleted {count} images'**
  String localGallery_deletedImages(Object count);

  /// No description provided for @localGallery_noFoldersAvailable.
  ///
  /// In en, this message translates to:
  /// **'No folders available, please create a folder first'**
  String get localGallery_noFoldersAvailable;

  /// No description provided for @localGallery_moveToFolder.
  ///
  /// In en, this message translates to:
  /// **'Move to Folder'**
  String get localGallery_moveToFolder;

  /// No description provided for @localGallery_imageCount.
  ///
  /// In en, this message translates to:
  /// **'{count} images'**
  String localGallery_imageCount(Object count);

  /// No description provided for @localGallery_movedImages.
  ///
  /// In en, this message translates to:
  /// **'Moved {count} images'**
  String localGallery_movedImages(Object count);

  /// No description provided for @localGallery_moveImagesFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to move images'**
  String get localGallery_moveImagesFailed;

  /// No description provided for @localGallery_addedToCollection.
  ///
  /// In en, this message translates to:
  /// **'Added {count} images to collection \"{name}\"'**
  String localGallery_addedToCollection(Object count, Object name);

  /// No description provided for @localGallery_addToCollectionFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to add images to collection'**
  String get localGallery_addToCollectionFailed;

  /// No description provided for @brushPreset_selectHint.
  ///
  /// In en, this message translates to:
  /// **'Double tap to select this brush preset'**
  String get brushPreset_selectHint;

  /// No description provided for @brushPreset_selected.
  ///
  /// In en, this message translates to:
  /// **'Selected'**
  String get brushPreset_selected;

  /// No description provided for @brushPreset_pencil.
  ///
  /// In en, this message translates to:
  /// **'Pencil'**
  String get brushPreset_pencil;

  /// No description provided for @brushPreset_fine.
  ///
  /// In en, this message translates to:
  /// **'Fine Brush'**
  String get brushPreset_fine;

  /// No description provided for @brushPreset_standard.
  ///
  /// In en, this message translates to:
  /// **'Standard Brush'**
  String get brushPreset_standard;

  /// No description provided for @brushPreset_soft.
  ///
  /// In en, this message translates to:
  /// **'Soft Brush'**
  String get brushPreset_soft;

  /// No description provided for @brushPreset_airbrush.
  ///
  /// In en, this message translates to:
  /// **'Airbrush'**
  String get brushPreset_airbrush;

  /// No description provided for @brushPreset_marker.
  ///
  /// In en, this message translates to:
  /// **'Marker'**
  String get brushPreset_marker;

  /// No description provided for @brushPreset_thick.
  ///
  /// In en, this message translates to:
  /// **'Thick Brush'**
  String get brushPreset_thick;

  /// No description provided for @brushPreset_smudge.
  ///
  /// In en, this message translates to:
  /// **'Smudge Brush'**
  String get brushPreset_smudge;

  /// No description provided for @bulkProgress_progress.
  ///
  /// In en, this message translates to:
  /// **'Processing {current} of {total}'**
  String bulkProgress_progress(Object current, Object total);

  /// No description provided for @bulkProgress_success.
  ///
  /// In en, this message translates to:
  /// **'{count} succeeded'**
  String bulkProgress_success(Object count);

  /// No description provided for @bulkProgress_failed.
  ///
  /// In en, this message translates to:
  /// **'{count} failed'**
  String bulkProgress_failed(Object count);

  /// No description provided for @bulkProgress_errors.
  ///
  /// In en, this message translates to:
  /// **'Errors:'**
  String get bulkProgress_errors;

  /// No description provided for @bulkProgress_moreErrors.
  ///
  /// In en, this message translates to:
  /// **'...and {count} more errors'**
  String bulkProgress_moreErrors(Object count);

  /// No description provided for @bulkProgress_completed.
  ///
  /// In en, this message translates to:
  /// **'{count} items completed'**
  String bulkProgress_completed(Object count);

  /// No description provided for @bulkProgress_completedWithErrors.
  ///
  /// In en, this message translates to:
  /// **'{success} succeeded, {failed} failed'**
  String bulkProgress_completedWithErrors(Object success, Object failed);

  /// No description provided for @bulkProgress_title_delete.
  ///
  /// In en, this message translates to:
  /// **'Deleting Images'**
  String get bulkProgress_title_delete;

  /// No description provided for @bulkProgress_title_export.
  ///
  /// In en, this message translates to:
  /// **'Exporting Metadata'**
  String get bulkProgress_title_export;

  /// No description provided for @bulkProgress_title_metadataEdit.
  ///
  /// In en, this message translates to:
  /// **'Editing Metadata'**
  String get bulkProgress_title_metadataEdit;

  /// No description provided for @bulkProgress_title_addToCollection.
  ///
  /// In en, this message translates to:
  /// **'Adding to Collection'**
  String get bulkProgress_title_addToCollection;

  /// No description provided for @bulkProgress_title_removeFromCollection.
  ///
  /// In en, this message translates to:
  /// **'Removing from Collection'**
  String get bulkProgress_title_removeFromCollection;

  /// No description provided for @bulkProgress_title_toggleFavorite.
  ///
  /// In en, this message translates to:
  /// **'Updating Favorites'**
  String get bulkProgress_title_toggleFavorite;

  /// No description provided for @bulkProgress_title_default.
  ///
  /// In en, this message translates to:
  /// **'Processing'**
  String get bulkProgress_title_default;

  /// No description provided for @collectionSelect_dialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Select Collection'**
  String get collectionSelect_dialogTitle;

  /// No description provided for @collectionSelect_filterHint.
  ///
  /// In en, this message translates to:
  /// **'Search collections...'**
  String get collectionSelect_filterHint;

  /// No description provided for @collectionSelect_noCollections.
  ///
  /// In en, this message translates to:
  /// **'No collections'**
  String get collectionSelect_noCollections;

  /// No description provided for @collectionSelect_createCollectionHint.
  ///
  /// In en, this message translates to:
  /// **'Create a collection first'**
  String get collectionSelect_createCollectionHint;

  /// No description provided for @collectionSelect_noFilterResults.
  ///
  /// In en, this message translates to:
  /// **'No matching collections found'**
  String get collectionSelect_noFilterResults;

  /// No description provided for @collectionSelect_imageCount.
  ///
  /// In en, this message translates to:
  /// **'{count} images'**
  String collectionSelect_imageCount(int count);

  /// No description provided for @statistics_navOverview.
  ///
  /// In en, this message translates to:
  /// **'Overview'**
  String get statistics_navOverview;

  /// No description provided for @statistics_navModels.
  ///
  /// In en, this message translates to:
  /// **'Models'**
  String get statistics_navModels;

  /// No description provided for @statistics_navTags.
  ///
  /// In en, this message translates to:
  /// **'Tags'**
  String get statistics_navTags;

  /// No description provided for @statistics_navParameters.
  ///
  /// In en, this message translates to:
  /// **'Parameters'**
  String get statistics_navParameters;

  /// No description provided for @statistics_navTrends.
  ///
  /// In en, this message translates to:
  /// **'Trends'**
  String get statistics_navTrends;

  /// No description provided for @statistics_navActivity.
  ///
  /// In en, this message translates to:
  /// **'Activity'**
  String get statistics_navActivity;

  /// No description provided for @statistics_sectionTagAnalysis.
  ///
  /// In en, this message translates to:
  /// **'Tag Analysis'**
  String get statistics_sectionTagAnalysis;

  /// No description provided for @statistics_sectionParameterPrefs.
  ///
  /// In en, this message translates to:
  /// **'Parameter Preferences'**
  String get statistics_sectionParameterPrefs;

  /// No description provided for @statistics_sectionActivityAnalysis.
  ///
  /// In en, this message translates to:
  /// **'Activity Analysis'**
  String get statistics_sectionActivityAnalysis;

  /// No description provided for @statistics_chartUsageDistribution.
  ///
  /// In en, this message translates to:
  /// **'Usage Distribution'**
  String get statistics_chartUsageDistribution;

  /// No description provided for @statistics_chartModelRanking.
  ///
  /// In en, this message translates to:
  /// **'Model Ranking'**
  String get statistics_chartModelRanking;

  /// No description provided for @statistics_chartModelUsageOverTime.
  ///
  /// In en, this message translates to:
  /// **'Model Usage Over Time'**
  String get statistics_chartModelUsageOverTime;

  /// No description provided for @statistics_chartTopTags.
  ///
  /// In en, this message translates to:
  /// **'Top Tags'**
  String get statistics_chartTopTags;

  /// No description provided for @statistics_chartTagCloud.
  ///
  /// In en, this message translates to:
  /// **'Tag Cloud'**
  String get statistics_chartTagCloud;

  /// No description provided for @statistics_chartParameterOverview.
  ///
  /// In en, this message translates to:
  /// **'Parameter Overview'**
  String get statistics_chartParameterOverview;

  /// No description provided for @statistics_chartAspectRatio.
  ///
  /// In en, this message translates to:
  /// **'Aspect Ratio Distribution'**
  String get statistics_chartAspectRatio;

  /// No description provided for @statistics_chartActivityHeatmap.
  ///
  /// In en, this message translates to:
  /// **'Activity Heatmap'**
  String get statistics_chartActivityHeatmap;

  /// No description provided for @statistics_chartHourlyDistribution.
  ///
  /// In en, this message translates to:
  /// **'Hourly Distribution'**
  String get statistics_chartHourlyDistribution;

  /// No description provided for @statistics_chartWeekdayDistribution.
  ///
  /// In en, this message translates to:
  /// **'Weekday Distribution'**
  String get statistics_chartWeekdayDistribution;

  /// No description provided for @statistics_filterTitle.
  ///
  /// In en, this message translates to:
  /// **'Filters'**
  String get statistics_filterTitle;

  /// No description provided for @statistics_filterClear.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get statistics_filterClear;

  /// No description provided for @statistics_filterDateRange.
  ///
  /// In en, this message translates to:
  /// **'Date Range'**
  String get statistics_filterDateRange;

  /// No description provided for @statistics_filterModel.
  ///
  /// In en, this message translates to:
  /// **'Model'**
  String get statistics_filterModel;

  /// No description provided for @statistics_filterAllModels.
  ///
  /// In en, this message translates to:
  /// **'All Models'**
  String get statistics_filterAllModels;

  /// No description provided for @statistics_filterResolution.
  ///
  /// In en, this message translates to:
  /// **'Resolution'**
  String get statistics_filterResolution;

  /// No description provided for @statistics_filterAllResolutions.
  ///
  /// In en, this message translates to:
  /// **'All Resolutions'**
  String get statistics_filterAllResolutions;

  /// No description provided for @statistics_granularity.
  ///
  /// In en, this message translates to:
  /// **'Granularity'**
  String get statistics_granularity;

  /// No description provided for @statistics_granularityDay.
  ///
  /// In en, this message translates to:
  /// **'Day'**
  String get statistics_granularityDay;

  /// No description provided for @statistics_granularityWeek.
  ///
  /// In en, this message translates to:
  /// **'Week'**
  String get statistics_granularityWeek;

  /// No description provided for @statistics_granularityMonth.
  ///
  /// In en, this message translates to:
  /// **'Month'**
  String get statistics_granularityMonth;

  /// No description provided for @statistics_labelTotalDays.
  ///
  /// In en, this message translates to:
  /// **'Total Days'**
  String get statistics_labelTotalDays;

  /// No description provided for @statistics_labelPeak.
  ///
  /// In en, this message translates to:
  /// **'Peak'**
  String get statistics_labelPeak;

  /// No description provided for @statistics_labelAverage.
  ///
  /// In en, this message translates to:
  /// **'Average'**
  String get statistics_labelAverage;

  /// No description provided for @statistics_labelSteps.
  ///
  /// In en, this message translates to:
  /// **'Steps'**
  String get statistics_labelSteps;

  /// No description provided for @statistics_labelCfg.
  ///
  /// In en, this message translates to:
  /// **'CFG'**
  String get statistics_labelCfg;

  /// No description provided for @statistics_labelWidth.
  ///
  /// In en, this message translates to:
  /// **'Width'**
  String get statistics_labelWidth;

  /// No description provided for @statistics_labelHeight.
  ///
  /// In en, this message translates to:
  /// **'Height'**
  String get statistics_labelHeight;

  /// No description provided for @statistics_labelFavPercent.
  ///
  /// In en, this message translates to:
  /// **'Fav%'**
  String get statistics_labelFavPercent;

  /// No description provided for @statistics_labelTagPercent.
  ///
  /// In en, this message translates to:
  /// **'Tag%'**
  String get statistics_labelTagPercent;

  /// No description provided for @statistics_aspectSquare.
  ///
  /// In en, this message translates to:
  /// **'Square'**
  String get statistics_aspectSquare;

  /// No description provided for @statistics_aspectLandscape.
  ///
  /// In en, this message translates to:
  /// **'Landscape'**
  String get statistics_aspectLandscape;

  /// No description provided for @statistics_aspectPortrait.
  ///
  /// In en, this message translates to:
  /// **'Portrait'**
  String get statistics_aspectPortrait;

  /// No description provided for @statistics_aspectOther.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get statistics_aspectOther;

  /// No description provided for @statistics_refresh.
  ///
  /// In en, this message translates to:
  /// **'Refresh'**
  String get statistics_refresh;

  /// No description provided for @statistics_retry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get statistics_retry;

  /// No description provided for @statistics_error.
  ///
  /// In en, this message translates to:
  /// **'Error: {error}'**
  String statistics_error(Object error);

  /// No description provided for @statistics_noMetadata.
  ///
  /// In en, this message translates to:
  /// **'No metadata available'**
  String get statistics_noMetadata;

  /// No description provided for @statistics_unknown.
  ///
  /// In en, this message translates to:
  /// **'Unknown'**
  String get statistics_unknown;

  /// No description provided for @statistics_weekLabel.
  ///
  /// In en, this message translates to:
  /// **'W{week}'**
  String statistics_weekLabel(Object week);

  /// No description provided for @statistics_peakHour.
  ///
  /// In en, this message translates to:
  /// **'Peak Hour'**
  String get statistics_peakHour;

  /// No description provided for @statistics_mostActiveDay.
  ///
  /// In en, this message translates to:
  /// **'Most Active Day'**
  String get statistics_mostActiveDay;

  /// No description provided for @statistics_leastActiveDay.
  ///
  /// In en, this message translates to:
  /// **'Least Active Day'**
  String get statistics_leastActiveDay;

  /// No description provided for @statistics_morning.
  ///
  /// In en, this message translates to:
  /// **'Morning'**
  String get statistics_morning;

  /// No description provided for @statistics_afternoon.
  ///
  /// In en, this message translates to:
  /// **'Afternoon'**
  String get statistics_afternoon;

  /// No description provided for @statistics_evening.
  ///
  /// In en, this message translates to:
  /// **'Evening'**
  String get statistics_evening;

  /// No description provided for @statistics_night.
  ///
  /// In en, this message translates to:
  /// **'Night'**
  String get statistics_night;

  /// No description provided for @statistics_sunday.
  ///
  /// In en, this message translates to:
  /// **'Sun'**
  String get statistics_sunday;

  /// No description provided for @statistics_monday.
  ///
  /// In en, this message translates to:
  /// **'Mon'**
  String get statistics_monday;

  /// No description provided for @statistics_tuesday.
  ///
  /// In en, this message translates to:
  /// **'Tue'**
  String get statistics_tuesday;

  /// No description provided for @statistics_wednesday.
  ///
  /// In en, this message translates to:
  /// **'Wed'**
  String get statistics_wednesday;

  /// No description provided for @statistics_thursday.
  ///
  /// In en, this message translates to:
  /// **'Thu'**
  String get statistics_thursday;

  /// No description provided for @statistics_friday.
  ///
  /// In en, this message translates to:
  /// **'Fri'**
  String get statistics_friday;

  /// No description provided for @statistics_saturday.
  ///
  /// In en, this message translates to:
  /// **'Sat'**
  String get statistics_saturday;

  /// No description provided for @fixedTags_label.
  ///
  /// In en, this message translates to:
  /// **'Fixed Tags'**
  String get fixedTags_label;

  /// No description provided for @fixedTags_empty.
  ///
  /// In en, this message translates to:
  /// **'No fixed tags'**
  String get fixedTags_empty;

  /// No description provided for @fixedTags_emptyHint.
  ///
  /// In en, this message translates to:
  /// **'Click the button below to add fixed tags, they will be automatically applied to your prompts'**
  String get fixedTags_emptyHint;

  /// No description provided for @fixedTags_clickToManage.
  ///
  /// In en, this message translates to:
  /// **'Click to manage fixed tags'**
  String get fixedTags_clickToManage;

  /// No description provided for @fixedTags_manage.
  ///
  /// In en, this message translates to:
  /// **'Manage Fixed Tags'**
  String get fixedTags_manage;

  /// No description provided for @fixedTags_add.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get fixedTags_add;

  /// No description provided for @fixedTags_edit.
  ///
  /// In en, this message translates to:
  /// **'Edit Fixed Tag'**
  String get fixedTags_edit;

  /// No description provided for @fixedTags_openLibrary.
  ///
  /// In en, this message translates to:
  /// **'Open Library'**
  String get fixedTags_openLibrary;

  /// No description provided for @fixedTags_prefix.
  ///
  /// In en, this message translates to:
  /// **'Prefix'**
  String get fixedTags_prefix;

  /// No description provided for @fixedTags_suffix.
  ///
  /// In en, this message translates to:
  /// **'Suffix'**
  String get fixedTags_suffix;

  /// No description provided for @fixedTags_prefixDesc.
  ///
  /// In en, this message translates to:
  /// **'Add before prompt'**
  String get fixedTags_prefixDesc;

  /// No description provided for @fixedTags_suffixDesc.
  ///
  /// In en, this message translates to:
  /// **'Add after prompt'**
  String get fixedTags_suffixDesc;

  /// No description provided for @fixedTags_disabled.
  ///
  /// In en, this message translates to:
  /// **'Disabled'**
  String get fixedTags_disabled;

  /// No description provided for @fixedTags_weight.
  ///
  /// In en, this message translates to:
  /// **'Weight'**
  String get fixedTags_weight;

  /// No description provided for @fixedTags_position.
  ///
  /// In en, this message translates to:
  /// **'Position'**
  String get fixedTags_position;

  /// No description provided for @fixedTags_name.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get fixedTags_name;

  /// No description provided for @fixedTags_nameHint.
  ///
  /// In en, this message translates to:
  /// **'Enter a display name (optional)'**
  String get fixedTags_nameHint;

  /// No description provided for @fixedTags_content.
  ///
  /// In en, this message translates to:
  /// **'Content'**
  String get fixedTags_content;

  /// No description provided for @fixedTags_contentHint.
  ///
  /// In en, this message translates to:
  /// **'Enter prompt content, NAI syntax supported'**
  String get fixedTags_contentHint;

  /// No description provided for @fixedTags_syntaxHelp.
  ///
  /// In en, this message translates to:
  /// **'Supports NAI syntax for weight enhancement/reduction and tag alternation'**
  String get fixedTags_syntaxHelp;

  /// No description provided for @fixedTags_resetWeight.
  ///
  /// In en, this message translates to:
  /// **'Reset to 1.0'**
  String get fixedTags_resetWeight;

  /// No description provided for @fixedTags_weightPreview.
  ///
  /// In en, this message translates to:
  /// **'Weight preview:'**
  String get fixedTags_weightPreview;

  /// No description provided for @fixedTags_deleteTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete Fixed Tag'**
  String get fixedTags_deleteTitle;

  /// No description provided for @fixedTags_deleteConfirm.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete \"{name}\"?'**
  String fixedTags_deleteConfirm(Object name);

  /// No description provided for @fixedTags_enabledCount.
  ///
  /// In en, this message translates to:
  /// **'{enabled}/{total} enabled'**
  String fixedTags_enabledCount(Object enabled, Object total);

  /// No description provided for @fixedTags_saveToLibrary.
  ///
  /// In en, this message translates to:
  /// **'Also save to library'**
  String get fixedTags_saveToLibrary;

  /// No description provided for @fixedTags_saveToLibraryHint.
  ///
  /// In en, this message translates to:
  /// **'For reuse in the tag library later'**
  String get fixedTags_saveToLibraryHint;

  /// No description provided for @fixedTags_saveToCategory.
  ///
  /// In en, this message translates to:
  /// **'Save to category'**
  String get fixedTags_saveToCategory;

  /// No description provided for @fixedTags_clearAll.
  ///
  /// In en, this message translates to:
  /// **'Clear All'**
  String get fixedTags_clearAll;

  /// No description provided for @fixedTags_clearAllTitle.
  ///
  /// In en, this message translates to:
  /// **'Clear All Fixed Tags'**
  String get fixedTags_clearAllTitle;

  /// No description provided for @fixedTags_clearAllConfirm.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to clear all {count} fixed tags? This action cannot be undone.'**
  String fixedTags_clearAllConfirm(Object count);

  /// No description provided for @fixedTags_clearedSuccess.
  ///
  /// In en, this message translates to:
  /// **'All fixed tags cleared'**
  String get fixedTags_clearedSuccess;

  /// No description provided for @common_rename.
  ///
  /// In en, this message translates to:
  /// **'Rename'**
  String get common_rename;

  /// No description provided for @common_create.
  ///
  /// In en, this message translates to:
  /// **'Create'**
  String get common_create;

  /// No description provided for @tagLibrary_categories.
  ///
  /// In en, this message translates to:
  /// **'Categories'**
  String get tagLibrary_categories;

  /// No description provided for @tagLibrary_newCategory.
  ///
  /// In en, this message translates to:
  /// **'New Category'**
  String get tagLibrary_newCategory;

  /// No description provided for @tagLibrary_addEntry.
  ///
  /// In en, this message translates to:
  /// **'Add Entry'**
  String get tagLibrary_addEntry;

  /// No description provided for @tagLibrary_editEntry.
  ///
  /// In en, this message translates to:
  /// **'Edit Entry'**
  String get tagLibrary_editEntry;

  /// No description provided for @tagLibrary_searchHint.
  ///
  /// In en, this message translates to:
  /// **'Search entries...'**
  String get tagLibrary_searchHint;

  /// No description provided for @tagLibrary_cardView.
  ///
  /// In en, this message translates to:
  /// **'Card View'**
  String get tagLibrary_cardView;

  /// No description provided for @tagLibrary_listView.
  ///
  /// In en, this message translates to:
  /// **'List View'**
  String get tagLibrary_listView;

  /// No description provided for @tagLibrary_import.
  ///
  /// In en, this message translates to:
  /// **'Import'**
  String get tagLibrary_import;

  /// No description provided for @tagLibrary_export.
  ///
  /// In en, this message translates to:
  /// **'Export'**
  String get tagLibrary_export;

  /// No description provided for @tagLibrary_allEntries.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get tagLibrary_allEntries;

  /// No description provided for @tagLibrary_favorites.
  ///
  /// In en, this message translates to:
  /// **'Favorites'**
  String get tagLibrary_favorites;

  /// No description provided for @tagLibrary_addSubCategory.
  ///
  /// In en, this message translates to:
  /// **'Add Subcategory'**
  String get tagLibrary_addSubCategory;

  /// No description provided for @tagLibrary_moveToRoot.
  ///
  /// In en, this message translates to:
  /// **'Move to Root'**
  String get tagLibrary_moveToRoot;

  /// No description provided for @tagLibrary_categoryNameHint.
  ///
  /// In en, this message translates to:
  /// **'Enter category name'**
  String get tagLibrary_categoryNameHint;

  /// No description provided for @tagLibrary_deleteCategoryTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete Category'**
  String get tagLibrary_deleteCategoryTitle;

  /// No description provided for @tagLibrary_deleteCategoryConfirm.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete category \"{name}\"? {count} entries will be moved to root.'**
  String tagLibrary_deleteCategoryConfirm(Object name, Object count);

  /// No description provided for @tagLibrary_deleteEntryTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete Entry'**
  String get tagLibrary_deleteEntryTitle;

  /// No description provided for @tagLibrary_deleteEntryConfirm.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete entry \"{name}\"?'**
  String tagLibrary_deleteEntryConfirm(Object name);

  /// No description provided for @tagLibrary_noSearchResults.
  ///
  /// In en, this message translates to:
  /// **'No matching entries found'**
  String get tagLibrary_noSearchResults;

  /// No description provided for @tagLibrary_tryDifferentSearch.
  ///
  /// In en, this message translates to:
  /// **'Try different keywords'**
  String get tagLibrary_tryDifferentSearch;

  /// No description provided for @tagLibrary_categoryEmpty.
  ///
  /// In en, this message translates to:
  /// **'This category is empty'**
  String get tagLibrary_categoryEmpty;

  /// No description provided for @tagLibrary_empty.
  ///
  /// In en, this message translates to:
  /// **'Library is empty'**
  String get tagLibrary_empty;

  /// No description provided for @tagLibrary_addFirstEntry.
  ///
  /// In en, this message translates to:
  /// **'Click the button above to add your first entry'**
  String get tagLibrary_addFirstEntry;

  /// No description provided for @tagLibraryPicker_title.
  ///
  /// In en, this message translates to:
  /// **'Select Entry'**
  String get tagLibraryPicker_title;

  /// No description provided for @tagLibraryPicker_searchHint.
  ///
  /// In en, this message translates to:
  /// **'Search entries...'**
  String get tagLibraryPicker_searchHint;

  /// No description provided for @tagLibraryPicker_allCategories.
  ///
  /// In en, this message translates to:
  /// **'All Categories'**
  String get tagLibraryPicker_allCategories;

  /// No description provided for @tagLibrary_addToFixed.
  ///
  /// In en, this message translates to:
  /// **'Add to Fixed Tags'**
  String get tagLibrary_addToFixed;

  /// No description provided for @tagLibrary_addedToFixed.
  ///
  /// In en, this message translates to:
  /// **'Added to Fixed Tags'**
  String get tagLibrary_addedToFixed;

  /// No description provided for @tagLibrary_entryMoved.
  ///
  /// In en, this message translates to:
  /// **'Entry moved to target category'**
  String get tagLibrary_entryMoved;

  /// No description provided for @tagLibrary_useCount.
  ///
  /// In en, this message translates to:
  /// **'Used {count} times'**
  String tagLibrary_useCount(Object count);

  /// No description provided for @tagLibrary_removeFavorite.
  ///
  /// In en, this message translates to:
  /// **'Remove from Favorites'**
  String get tagLibrary_removeFavorite;

  /// No description provided for @tagLibrary_addFavorite.
  ///
  /// In en, this message translates to:
  /// **'Add to Favorites'**
  String get tagLibrary_addFavorite;

  /// No description provided for @tagLibrary_pinned.
  ///
  /// In en, this message translates to:
  /// **'Favorited'**
  String get tagLibrary_pinned;

  /// No description provided for @tagLibrary_thumbnail.
  ///
  /// In en, this message translates to:
  /// **'Thumbnail'**
  String get tagLibrary_thumbnail;

  /// No description provided for @tagLibrary_selectImage.
  ///
  /// In en, this message translates to:
  /// **'Select Image'**
  String get tagLibrary_selectImage;

  /// No description provided for @tagLibrary_thumbnailHint.
  ///
  /// In en, this message translates to:
  /// **'Supports PNG/JPG/WEBP'**
  String get tagLibrary_thumbnailHint;

  /// No description provided for @tagLibrary_name.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get tagLibrary_name;

  /// No description provided for @tagLibrary_nameHint.
  ///
  /// In en, this message translates to:
  /// **'Enter entry name'**
  String get tagLibrary_nameHint;

  /// No description provided for @tagLibrary_category.
  ///
  /// In en, this message translates to:
  /// **'Category'**
  String get tagLibrary_category;

  /// No description provided for @tagLibrary_rootCategory.
  ///
  /// In en, this message translates to:
  /// **'Root'**
  String get tagLibrary_rootCategory;

  /// No description provided for @tagLibrary_tags.
  ///
  /// In en, this message translates to:
  /// **'Tags'**
  String get tagLibrary_tags;

  /// No description provided for @tagLibrary_tagsHint.
  ///
  /// In en, this message translates to:
  /// **'Enter tags, separated by commas'**
  String get tagLibrary_tagsHint;

  /// No description provided for @tagLibrary_tagsHelper.
  ///
  /// In en, this message translates to:
  /// **'Tags are used for filtering and searching'**
  String get tagLibrary_tagsHelper;

  /// No description provided for @tagLibrary_content.
  ///
  /// In en, this message translates to:
  /// **'Prompt Content'**
  String get tagLibrary_content;

  /// No description provided for @tagLibrary_contentHint.
  ///
  /// In en, this message translates to:
  /// **'Enter prompt content, supports autocomplete'**
  String get tagLibrary_contentHint;

  /// No description provided for @settings_network.
  ///
  /// In en, this message translates to:
  /// **'Network'**
  String get settings_network;

  /// No description provided for @settings_enableProxy.
  ///
  /// In en, this message translates to:
  /// **'Enable Proxy'**
  String get settings_enableProxy;

  /// No description provided for @settings_proxyEnabled.
  ///
  /// In en, this message translates to:
  /// **'Enabled'**
  String get settings_proxyEnabled;

  /// No description provided for @settings_proxyDisabled.
  ///
  /// In en, this message translates to:
  /// **'Direct connection'**
  String get settings_proxyDisabled;

  /// No description provided for @settings_proxyMode.
  ///
  /// In en, this message translates to:
  /// **'Proxy Mode'**
  String get settings_proxyMode;

  /// No description provided for @settings_proxyModeAuto.
  ///
  /// In en, this message translates to:
  /// **'Auto-detect system proxy'**
  String get settings_proxyModeAuto;

  /// No description provided for @settings_proxyModeManual.
  ///
  /// In en, this message translates to:
  /// **'Manual configuration'**
  String get settings_proxyModeManual;

  /// No description provided for @settings_auto.
  ///
  /// In en, this message translates to:
  /// **'Auto'**
  String get settings_auto;

  /// No description provided for @settings_manual.
  ///
  /// In en, this message translates to:
  /// **'Manual'**
  String get settings_manual;

  /// No description provided for @settings_proxyHost.
  ///
  /// In en, this message translates to:
  /// **'Proxy Host'**
  String get settings_proxyHost;

  /// No description provided for @settings_proxyPort.
  ///
  /// In en, this message translates to:
  /// **'Port'**
  String get settings_proxyPort;

  /// No description provided for @settings_proxyNotDetected.
  ///
  /// In en, this message translates to:
  /// **'No system proxy detected'**
  String get settings_proxyNotDetected;

  /// No description provided for @settings_testConnection.
  ///
  /// In en, this message translates to:
  /// **'Test Connection'**
  String get settings_testConnection;

  /// No description provided for @settings_testConnectionHint.
  ///
  /// In en, this message translates to:
  /// **'Click to test if proxy is working'**
  String get settings_testConnectionHint;

  /// No description provided for @settings_testSuccess.
  ///
  /// In en, this message translates to:
  /// **'Connection successful ({latency}ms)'**
  String settings_testSuccess(Object latency);

  /// No description provided for @settings_testFailed.
  ///
  /// In en, this message translates to:
  /// **'Connection failed: {error}'**
  String settings_testFailed(Object error);

  /// No description provided for @settings_proxyRestartHint.
  ///
  /// In en, this message translates to:
  /// **'Proxy settings changed, restart recommended'**
  String get settings_proxyRestartHint;

  /// No description provided for @tagLibrary_categoryNameExists.
  ///
  /// In en, this message translates to:
  /// **'Category name already exists'**
  String get tagLibrary_categoryNameExists;

  /// No description provided for @tagLibrary_addToLibrary.
  ///
  /// In en, this message translates to:
  /// **'Add to Library'**
  String get tagLibrary_addToLibrary;

  /// No description provided for @tagLibrary_saveToLibrary.
  ///
  /// In en, this message translates to:
  /// **'Save to Library'**
  String get tagLibrary_saveToLibrary;

  /// No description provided for @tagLibrary_entrySaved.
  ///
  /// In en, this message translates to:
  /// **'Saved to library'**
  String get tagLibrary_entrySaved;

  /// No description provided for @tagLibrary_entryUpdated.
  ///
  /// In en, this message translates to:
  /// **'Entry updated'**
  String get tagLibrary_entryUpdated;

  /// No description provided for @tagLibrary_uncategorized.
  ///
  /// In en, this message translates to:
  /// **'Uncategorized'**
  String get tagLibrary_uncategorized;

  /// No description provided for @tagLibrary_contentPreview.
  ///
  /// In en, this message translates to:
  /// **'Content Preview'**
  String get tagLibrary_contentPreview;

  /// No description provided for @tagLibrary_confirmAdd.
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get tagLibrary_confirmAdd;

  /// No description provided for @tagLibrary_entryName.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get tagLibrary_entryName;

  /// No description provided for @tagLibrary_entryNameHint.
  ///
  /// In en, this message translates to:
  /// **'Enter entry name'**
  String get tagLibrary_entryNameHint;

  /// No description provided for @queue_title.
  ///
  /// In en, this message translates to:
  /// **'Queue'**
  String get queue_title;

  /// No description provided for @queue_management.
  ///
  /// In en, this message translates to:
  /// **'Queue Management'**
  String get queue_management;

  /// No description provided for @queue_empty.
  ///
  /// In en, this message translates to:
  /// **'Queue is empty'**
  String get queue_empty;

  /// No description provided for @queue_emptyHint.
  ///
  /// In en, this message translates to:
  /// **'No tasks in the queue'**
  String get queue_emptyHint;

  /// No description provided for @queue_taskCount.
  ///
  /// In en, this message translates to:
  /// **'{count} tasks'**
  String queue_taskCount(Object count);

  /// No description provided for @queue_pending.
  ///
  /// In en, this message translates to:
  /// **'Pending'**
  String get queue_pending;

  /// No description provided for @queue_running.
  ///
  /// In en, this message translates to:
  /// **'Running'**
  String get queue_running;

  /// No description provided for @queue_completed.
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get queue_completed;

  /// No description provided for @queue_failed.
  ///
  /// In en, this message translates to:
  /// **'Failed'**
  String get queue_failed;

  /// No description provided for @queue_skipped.
  ///
  /// In en, this message translates to:
  /// **'Skipped'**
  String get queue_skipped;

  /// No description provided for @queue_paused.
  ///
  /// In en, this message translates to:
  /// **'Paused'**
  String get queue_paused;

  /// No description provided for @queue_idle.
  ///
  /// In en, this message translates to:
  /// **'Idle'**
  String get queue_idle;

  /// No description provided for @queue_ready.
  ///
  /// In en, this message translates to:
  /// **'Ready'**
  String get queue_ready;

  /// No description provided for @queue_clickToStart.
  ///
  /// In en, this message translates to:
  /// **'Click to start queue execution'**
  String get queue_clickToStart;

  /// No description provided for @queue_clickToPause.
  ///
  /// In en, this message translates to:
  /// **'Click to pause queue'**
  String get queue_clickToPause;

  /// No description provided for @queue_clickToResume.
  ///
  /// In en, this message translates to:
  /// **'Click to resume execution'**
  String get queue_clickToResume;

  /// No description provided for @queue_noTasksToStart.
  ///
  /// In en, this message translates to:
  /// **'Queue is empty, cannot start'**
  String get queue_noTasksToStart;

  /// No description provided for @queue_allTasksCompleted.
  ///
  /// In en, this message translates to:
  /// **'All tasks completed'**
  String get queue_allTasksCompleted;

  /// No description provided for @queue_executionProgress.
  ///
  /// In en, this message translates to:
  /// **'Execution Progress'**
  String get queue_executionProgress;

  /// No description provided for @queue_totalTasks.
  ///
  /// In en, this message translates to:
  /// **'Total'**
  String get queue_totalTasks;

  /// No description provided for @queue_completedTasks.
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get queue_completedTasks;

  /// No description provided for @queue_failedTasks.
  ///
  /// In en, this message translates to:
  /// **'Failed'**
  String get queue_failedTasks;

  /// No description provided for @queue_remainingTasks.
  ///
  /// In en, this message translates to:
  /// **'Remaining'**
  String get queue_remainingTasks;

  /// No description provided for @queue_estimatedTime.
  ///
  /// In en, this message translates to:
  /// **'Estimated: about {time}'**
  String queue_estimatedTime(Object time);

  /// No description provided for @queue_seconds.
  ///
  /// In en, this message translates to:
  /// **'{count} seconds'**
  String queue_seconds(Object count);

  /// No description provided for @queue_minutes.
  ///
  /// In en, this message translates to:
  /// **'{count} minutes'**
  String queue_minutes(Object count);

  /// No description provided for @queue_hours.
  ///
  /// In en, this message translates to:
  /// **'{hours} hours {minutes} minutes'**
  String queue_hours(Object hours, Object minutes);

  /// No description provided for @queue_pause.
  ///
  /// In en, this message translates to:
  /// **'Pause'**
  String get queue_pause;

  /// No description provided for @queue_resume.
  ///
  /// In en, this message translates to:
  /// **'Resume'**
  String get queue_resume;

  /// No description provided for @queue_pauseExecution.
  ///
  /// In en, this message translates to:
  /// **'Pause Execution'**
  String get queue_pauseExecution;

  /// No description provided for @queue_resumeExecution.
  ///
  /// In en, this message translates to:
  /// **'Resume Execution'**
  String get queue_resumeExecution;

  /// No description provided for @queue_autoExecute.
  ///
  /// In en, this message translates to:
  /// **'Auto Execute'**
  String get queue_autoExecute;

  /// No description provided for @queue_autoExecuteOn.
  ///
  /// In en, this message translates to:
  /// **'Auto execute next task when completed'**
  String get queue_autoExecuteOn;

  /// No description provided for @queue_autoExecuteOff.
  ///
  /// In en, this message translates to:
  /// **'Manual click required to generate'**
  String get queue_autoExecuteOff;

  /// No description provided for @queue_taskInterval.
  ///
  /// In en, this message translates to:
  /// **'Task Interval'**
  String get queue_taskInterval;

  /// No description provided for @queue_taskIntervalHint.
  ///
  /// In en, this message translates to:
  /// **'Wait time between tasks (0-10 seconds)'**
  String get queue_taskIntervalHint;

  /// No description provided for @queue_clearQueue.
  ///
  /// In en, this message translates to:
  /// **'Clear Queue'**
  String get queue_clearQueue;

  /// No description provided for @queue_closeFloatingButton.
  ///
  /// In en, this message translates to:
  /// **'Close Floating Button'**
  String get queue_closeFloatingButton;

  /// No description provided for @queue_clearQueueConfirm.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to clear all queue tasks? This action cannot be undone.'**
  String get queue_clearQueueConfirm;

  /// No description provided for @queue_confirmClear.
  ///
  /// In en, this message translates to:
  /// **'Confirm Clear'**
  String get queue_confirmClear;

  /// No description provided for @queue_failureStrategy.
  ///
  /// In en, this message translates to:
  /// **'Failure Strategy'**
  String get queue_failureStrategy;

  /// No description provided for @queue_failureStrategyAutoRetry.
  ///
  /// In en, this message translates to:
  /// **'Auto Retry'**
  String get queue_failureStrategyAutoRetry;

  /// No description provided for @queue_failureStrategyAutoRetryDesc.
  ///
  /// In en, this message translates to:
  /// **'Move task to queue end after max retries'**
  String get queue_failureStrategyAutoRetryDesc;

  /// No description provided for @queue_failureStrategySkip.
  ///
  /// In en, this message translates to:
  /// **'Skip'**
  String get queue_failureStrategySkip;

  /// No description provided for @queue_failureStrategySkipDesc.
  ///
  /// In en, this message translates to:
  /// **'Move failed task to failed pool, continue next'**
  String get queue_failureStrategySkipDesc;

  /// No description provided for @queue_failureStrategyPause.
  ///
  /// In en, this message translates to:
  /// **'Pause and Wait'**
  String get queue_failureStrategyPause;

  /// No description provided for @queue_failureStrategyPauseDesc.
  ///
  /// In en, this message translates to:
  /// **'Pause queue, wait for manual handling'**
  String get queue_failureStrategyPauseDesc;

  /// No description provided for @queue_retryCount.
  ///
  /// In en, this message translates to:
  /// **'Retry {current}/{max}'**
  String queue_retryCount(Object current, Object max);

  /// No description provided for @queue_retry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get queue_retry;

  /// No description provided for @queue_requeue.
  ///
  /// In en, this message translates to:
  /// **'Requeue'**
  String get queue_requeue;

  /// No description provided for @queue_requeueToEnd.
  ///
  /// In en, this message translates to:
  /// **'Move to queue end'**
  String get queue_requeueToEnd;

  /// No description provided for @queue_clearFailedTasks.
  ///
  /// In en, this message translates to:
  /// **'Clear All'**
  String get queue_clearFailedTasks;

  /// No description provided for @queue_noFailedTasks.
  ///
  /// In en, this message translates to:
  /// **'No failed tasks'**
  String get queue_noFailedTasks;

  /// No description provided for @queue_noCompletedTasks.
  ///
  /// In en, this message translates to:
  /// **'No completed records'**
  String get queue_noCompletedTasks;

  /// No description provided for @queue_editTask.
  ///
  /// In en, this message translates to:
  /// **'Edit Task'**
  String get queue_editTask;

  /// No description provided for @queue_duplicateTask.
  ///
  /// In en, this message translates to:
  /// **'Duplicate Task'**
  String get queue_duplicateTask;

  /// No description provided for @queue_taskDuplicated.
  ///
  /// In en, this message translates to:
  /// **'Task duplicated'**
  String get queue_taskDuplicated;

  /// No description provided for @queue_queueFull.
  ///
  /// In en, this message translates to:
  /// **'Queue is full, cannot duplicate'**
  String get queue_queueFull;

  /// No description provided for @queue_positivePrompt.
  ///
  /// In en, this message translates to:
  /// **'Positive Prompt'**
  String get queue_positivePrompt;

  /// No description provided for @queue_enterPositivePrompt.
  ///
  /// In en, this message translates to:
  /// **'Enter positive prompt...'**
  String get queue_enterPositivePrompt;

  /// No description provided for @queue_parametersPreview.
  ///
  /// In en, this message translates to:
  /// **'Parameters Preview'**
  String get queue_parametersPreview;

  /// No description provided for @queue_model.
  ///
  /// In en, this message translates to:
  /// **'Model'**
  String get queue_model;

  /// No description provided for @queue_seed.
  ///
  /// In en, this message translates to:
  /// **'Seed'**
  String get queue_seed;

  /// No description provided for @queue_sampler.
  ///
  /// In en, this message translates to:
  /// **'Sampler'**
  String get queue_sampler;

  /// No description provided for @queue_steps.
  ///
  /// In en, this message translates to:
  /// **'Steps'**
  String get queue_steps;

  /// No description provided for @queue_cfg.
  ///
  /// In en, this message translates to:
  /// **'CFG'**
  String get queue_cfg;

  /// No description provided for @queue_size.
  ///
  /// In en, this message translates to:
  /// **'Size'**
  String get queue_size;

  /// No description provided for @queue_addToQueue.
  ///
  /// In en, this message translates to:
  /// **'Add to Queue'**
  String get queue_addToQueue;

  /// No description provided for @queue_taskAdded.
  ///
  /// In en, this message translates to:
  /// **'Added to queue'**
  String get queue_taskAdded;

  /// No description provided for @queue_negativePromptFromMain.
  ///
  /// In en, this message translates to:
  /// **'Negative prompt will use main page settings'**
  String get queue_negativePromptFromMain;

  /// No description provided for @queue_pinToTop.
  ///
  /// In en, this message translates to:
  /// **'Pin to Top'**
  String get queue_pinToTop;

  /// No description provided for @queue_delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get queue_delete;

  /// No description provided for @queue_edit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get queue_edit;

  /// No description provided for @queue_selectAll.
  ///
  /// In en, this message translates to:
  /// **'Select All'**
  String get queue_selectAll;

  /// No description provided for @queue_invertSelection.
  ///
  /// In en, this message translates to:
  /// **'Invert'**
  String get queue_invertSelection;

  /// No description provided for @queue_cancelSelection.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get queue_cancelSelection;

  /// No description provided for @queue_selectedCount.
  ///
  /// In en, this message translates to:
  /// **'{count} selected'**
  String queue_selectedCount(Object count);

  /// No description provided for @queue_batchDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete Selected'**
  String get queue_batchDelete;

  /// No description provided for @queue_batchPinToTop.
  ///
  /// In en, this message translates to:
  /// **'Pin Selected'**
  String get queue_batchPinToTop;

  /// No description provided for @queue_confirmDeleteSelected.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete {count} selected tasks?'**
  String queue_confirmDeleteSelected(Object count);

  /// No description provided for @queue_export.
  ///
  /// In en, this message translates to:
  /// **'Export'**
  String get queue_export;

  /// No description provided for @queue_import.
  ///
  /// In en, this message translates to:
  /// **'Import'**
  String get queue_import;

  /// No description provided for @queue_exportImport.
  ///
  /// In en, this message translates to:
  /// **'Import/Export Queue'**
  String get queue_exportImport;

  /// No description provided for @queue_exportFormat.
  ///
  /// In en, this message translates to:
  /// **'Export Format'**
  String get queue_exportFormat;

  /// No description provided for @queue_exportFormatJson.
  ///
  /// In en, this message translates to:
  /// **'JSON'**
  String get queue_exportFormatJson;

  /// No description provided for @queue_exportFormatJsonDesc.
  ///
  /// In en, this message translates to:
  /// **'Complete data with all parameters'**
  String get queue_exportFormatJsonDesc;

  /// No description provided for @queue_exportFormatCsv.
  ///
  /// In en, this message translates to:
  /// **'CSV'**
  String get queue_exportFormatCsv;

  /// No description provided for @queue_exportFormatCsvDesc.
  ///
  /// In en, this message translates to:
  /// **'Table format with prompts and basic info'**
  String get queue_exportFormatCsvDesc;

  /// No description provided for @queue_exportFormatText.
  ///
  /// In en, this message translates to:
  /// **'Plain Text'**
  String get queue_exportFormatText;

  /// No description provided for @queue_exportFormatTextDesc.
  ///
  /// In en, this message translates to:
  /// **'Prompts only, one per line'**
  String get queue_exportFormatTextDesc;

  /// No description provided for @queue_importStrategy.
  ///
  /// In en, this message translates to:
  /// **'Import Strategy'**
  String get queue_importStrategy;

  /// No description provided for @queue_importStrategyMerge.
  ///
  /// In en, this message translates to:
  /// **'Merge'**
  String get queue_importStrategyMerge;

  /// No description provided for @queue_importStrategyMergeDesc.
  ///
  /// In en, this message translates to:
  /// **'Add imported tasks to end of existing queue'**
  String get queue_importStrategyMergeDesc;

  /// No description provided for @queue_importStrategyReplace.
  ///
  /// In en, this message translates to:
  /// **'Replace'**
  String get queue_importStrategyReplace;

  /// No description provided for @queue_importStrategyReplaceDesc.
  ///
  /// In en, this message translates to:
  /// **'Clear existing queue and replace with imported'**
  String get queue_importStrategyReplaceDesc;

  /// No description provided for @queue_supportedFormats.
  ///
  /// In en, this message translates to:
  /// **'Supported formats:'**
  String get queue_supportedFormats;

  /// No description provided for @queue_exportSuccess.
  ///
  /// In en, this message translates to:
  /// **'Export successful'**
  String get queue_exportSuccess;

  /// No description provided for @queue_exportFailed.
  ///
  /// In en, this message translates to:
  /// **'Export failed: {error}'**
  String queue_exportFailed(Object error);

  /// No description provided for @queue_importSuccess.
  ///
  /// In en, this message translates to:
  /// **'Successfully imported {count} tasks'**
  String queue_importSuccess(Object count);

  /// No description provided for @queue_importFailed.
  ///
  /// In en, this message translates to:
  /// **'Import failed: {error}'**
  String queue_importFailed(Object error);

  /// No description provided for @queue_selectFile.
  ///
  /// In en, this message translates to:
  /// **'Select file to import'**
  String get queue_selectFile;

  /// No description provided for @queue_noValidTasks.
  ///
  /// In en, this message translates to:
  /// **'No valid tasks in file'**
  String get queue_noValidTasks;

  /// No description provided for @queue_settings.
  ///
  /// In en, this message translates to:
  /// **'Queue Settings'**
  String get queue_settings;

  /// No description provided for @queue_currentQueueInfo.
  ///
  /// In en, this message translates to:
  /// **'Current queue contains {count} tasks'**
  String queue_currentQueueInfo(Object count);

  /// No description provided for @queue_tooltipTasksTotal.
  ///
  /// In en, this message translates to:
  /// **'Tasks: {count}'**
  String queue_tooltipTasksTotal(Object count);

  /// No description provided for @queue_tooltipCompleted.
  ///
  /// In en, this message translates to:
  /// **'Completed: {count}'**
  String queue_tooltipCompleted(Object count);

  /// No description provided for @queue_tooltipFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed: {count}'**
  String queue_tooltipFailed(Object count);

  /// No description provided for @queue_tooltipCurrentTask.
  ///
  /// In en, this message translates to:
  /// **'Current: {task}'**
  String queue_tooltipCurrentTask(Object task);

  /// No description provided for @queue_tooltipNoTasks.
  ///
  /// In en, this message translates to:
  /// **'No tasks in queue'**
  String get queue_tooltipNoTasks;

  /// No description provided for @queue_tooltipDoubleClickToOpen.
  ///
  /// In en, this message translates to:
  /// **'Double-click to start/pause'**
  String get queue_tooltipDoubleClickToOpen;

  /// No description provided for @queue_tooltipClickToToggle.
  ///
  /// In en, this message translates to:
  /// **'Click to open queue'**
  String get queue_tooltipClickToToggle;

  /// No description provided for @queue_tooltipDragToMove.
  ///
  /// In en, this message translates to:
  /// **'Drag to reposition'**
  String get queue_tooltipDragToMove;

  /// No description provided for @queue_statusIdle.
  ///
  /// In en, this message translates to:
  /// **'Status: Idle'**
  String get queue_statusIdle;

  /// No description provided for @queue_statusReady.
  ///
  /// In en, this message translates to:
  /// **'Status: Ready'**
  String get queue_statusReady;

  /// No description provided for @queue_statusRunning.
  ///
  /// In en, this message translates to:
  /// **'Status: Running'**
  String get queue_statusRunning;

  /// No description provided for @queue_statusPaused.
  ///
  /// In en, this message translates to:
  /// **'Status: Paused'**
  String get queue_statusPaused;

  /// No description provided for @queue_statusCompleted.
  ///
  /// In en, this message translates to:
  /// **'Status: Completed'**
  String get queue_statusCompleted;

  /// No description provided for @settings_notification.
  ///
  /// In en, this message translates to:
  /// **'Sound'**
  String get settings_notification;

  /// No description provided for @settings_notificationSound.
  ///
  /// In en, this message translates to:
  /// **'Completion Sound'**
  String get settings_notificationSound;

  /// No description provided for @settings_notificationSoundSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Play sound when generation completes'**
  String get settings_notificationSoundSubtitle;

  /// No description provided for @settings_notificationCustomSound.
  ///
  /// In en, this message translates to:
  /// **'Custom Sound'**
  String get settings_notificationCustomSound;

  /// No description provided for @settings_notificationCustomSoundSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Select custom sound file'**
  String get settings_notificationCustomSoundSubtitle;

  /// No description provided for @settings_notificationSelectSound.
  ///
  /// In en, this message translates to:
  /// **'Select Sound'**
  String get settings_notificationSelectSound;

  /// No description provided for @settings_notificationResetSound.
  ///
  /// In en, this message translates to:
  /// **'Reset to Default'**
  String get settings_notificationResetSound;

  /// No description provided for @categoryConfiguration.
  ///
  /// In en, this message translates to:
  /// **'Category Configuration'**
  String get categoryConfiguration;

  /// No description provided for @resetToDefault.
  ///
  /// In en, this message translates to:
  /// **'Reset to Default'**
  String get resetToDefault;

  /// No description provided for @resetToDefaultTooltip.
  ///
  /// In en, this message translates to:
  /// **'Reset to default configuration'**
  String get resetToDefaultTooltip;

  /// No description provided for @resetToDefaultConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Reset to Default'**
  String get resetToDefaultConfirmTitle;

  /// No description provided for @resetToDefaultConfirmContent.
  ///
  /// In en, this message translates to:
  /// **'This will restore official default configuration. Your custom groups will be kept but disabled.'**
  String get resetToDefaultConfirmContent;

  /// No description provided for @groupEnabled.
  ///
  /// In en, this message translates to:
  /// **'Group enabled'**
  String get groupEnabled;

  /// No description provided for @groupDisabled.
  ///
  /// In en, this message translates to:
  /// **'Group disabled'**
  String get groupDisabled;

  /// No description provided for @toggleGroupEnabled.
  ///
  /// In en, this message translates to:
  /// **'Toggle group enabled state'**
  String get toggleGroupEnabled;

  /// No description provided for @diyNotAvailableForDefault.
  ///
  /// In en, this message translates to:
  /// **'DIY not available for default preset'**
  String get diyNotAvailableForDefault;

  /// No description provided for @diyNotAvailableHint.
  ///
  /// In en, this message translates to:
  /// **'Please copy to a custom preset to edit'**
  String get diyNotAvailableHint;

  /// No description provided for @customGroupDisabledAfterReset.
  ///
  /// In en, this message translates to:
  /// **'Custom group (disabled)'**
  String get customGroupDisabledAfterReset;

  /// No description provided for @confirmReset.
  ///
  /// In en, this message translates to:
  /// **'Confirm Reset'**
  String get confirmReset;

  /// No description provided for @alias_hintText.
  ///
  /// In en, this message translates to:
  /// **'Enter prompts, or use <library name> to reference library content'**
  String get alias_hintText;

  /// No description provided for @alias_libraryCategory.
  ///
  /// In en, this message translates to:
  /// **'Library'**
  String get alias_libraryCategory;

  /// No description provided for @alias_tagCount.
  ///
  /// In en, this message translates to:
  /// **'{count} tags'**
  String alias_tagCount(Object count);

  /// No description provided for @alias_useCount.
  ///
  /// In en, this message translates to:
  /// **'Used {count} times'**
  String alias_useCount(Object count);

  /// No description provided for @alias_favorited.
  ///
  /// In en, this message translates to:
  /// **'Favorited'**
  String get alias_favorited;

  /// No description provided for @statistics_heatmapLess.
  ///
  /// In en, this message translates to:
  /// **'Less'**
  String get statistics_heatmapLess;

  /// No description provided for @statistics_heatmapMore.
  ///
  /// In en, this message translates to:
  /// **'More'**
  String get statistics_heatmapMore;

  /// No description provided for @statistics_heatmapWeekLabel.
  ///
  /// In en, this message translates to:
  /// **'Week'**
  String get statistics_heatmapWeekLabel;

  /// No description provided for @statistics_heatmapActivities.
  ///
  /// In en, this message translates to:
  /// **'{count} activities'**
  String statistics_heatmapActivities(Object count);

  /// No description provided for @statistics_heatmapNoActivity.
  ///
  /// In en, this message translates to:
  /// **'No activity'**
  String get statistics_heatmapNoActivity;

  /// No description provided for @sendToHome_dialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Send to Home'**
  String get sendToHome_dialogTitle;

  /// No description provided for @sendToHome_mainPrompt.
  ///
  /// In en, this message translates to:
  /// **'Send to Main Prompt'**
  String get sendToHome_mainPrompt;

  /// No description provided for @sendToHome_mainPromptSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Fill into the main prompt input field'**
  String get sendToHome_mainPromptSubtitle;

  /// No description provided for @sendToHome_replaceCharacter.
  ///
  /// In en, this message translates to:
  /// **'Replace Character Prompt'**
  String get sendToHome_replaceCharacter;

  /// No description provided for @sendToHome_replaceCharacterSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Clear existing characters and add as new'**
  String get sendToHome_replaceCharacterSubtitle;

  /// No description provided for @sendToHome_appendCharacter.
  ///
  /// In en, this message translates to:
  /// **'Append Character Prompt'**
  String get sendToHome_appendCharacter;

  /// No description provided for @sendToHome_appendCharacterSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Keep existing characters and append new'**
  String get sendToHome_appendCharacterSubtitle;

  /// No description provided for @sendToHome_successMainPrompt.
  ///
  /// In en, this message translates to:
  /// **'Sent to main prompt'**
  String get sendToHome_successMainPrompt;

  /// No description provided for @sendToHome_successReplaceCharacter.
  ///
  /// In en, this message translates to:
  /// **'Character prompt replaced'**
  String get sendToHome_successReplaceCharacter;

  /// No description provided for @sendToHome_successAppendCharacter.
  ///
  /// In en, this message translates to:
  /// **'Character prompt appended'**
  String get sendToHome_successAppendCharacter;

  /// No description provided for @metadataImport_title.
  ///
  /// In en, this message translates to:
  /// **'Select Parameters to Import'**
  String get metadataImport_title;

  /// No description provided for @metadataImport_promptsSection.
  ///
  /// In en, this message translates to:
  /// **'Prompts'**
  String get metadataImport_promptsSection;

  /// No description provided for @metadataImport_generationSection.
  ///
  /// In en, this message translates to:
  /// **'Generation Parameters'**
  String get metadataImport_generationSection;

  /// No description provided for @metadataImport_advancedSection.
  ///
  /// In en, this message translates to:
  /// **'Advanced Options'**
  String get metadataImport_advancedSection;

  /// No description provided for @metadataImport_selectAll.
  ///
  /// In en, this message translates to:
  /// **'Select All'**
  String get metadataImport_selectAll;

  /// No description provided for @metadataImport_deselectAll.
  ///
  /// In en, this message translates to:
  /// **'Deselect All'**
  String get metadataImport_deselectAll;

  /// No description provided for @metadataImport_promptsOnly.
  ///
  /// In en, this message translates to:
  /// **'Prompts Only'**
  String get metadataImport_promptsOnly;

  /// No description provided for @metadataImport_generationOnly.
  ///
  /// In en, this message translates to:
  /// **'Generation Only'**
  String get metadataImport_generationOnly;

  /// No description provided for @metadataImport_prompt.
  ///
  /// In en, this message translates to:
  /// **'Positive Prompt'**
  String get metadataImport_prompt;

  /// No description provided for @metadataImport_negativePrompt.
  ///
  /// In en, this message translates to:
  /// **'Negative Prompt'**
  String get metadataImport_negativePrompt;

  /// No description provided for @metadataImport_characterPrompts.
  ///
  /// In en, this message translates to:
  /// **'Character Prompts'**
  String get metadataImport_characterPrompts;

  /// No description provided for @metadataImport_seed.
  ///
  /// In en, this message translates to:
  /// **'Seed'**
  String get metadataImport_seed;

  /// No description provided for @metadataImport_steps.
  ///
  /// In en, this message translates to:
  /// **'Steps'**
  String get metadataImport_steps;

  /// No description provided for @metadataImport_scale.
  ///
  /// In en, this message translates to:
  /// **'CFG Scale'**
  String get metadataImport_scale;

  /// No description provided for @metadataImport_size.
  ///
  /// In en, this message translates to:
  /// **'Size'**
  String get metadataImport_size;

  /// No description provided for @metadataImport_sampler.
  ///
  /// In en, this message translates to:
  /// **'Sampler'**
  String get metadataImport_sampler;

  /// No description provided for @metadataImport_model.
  ///
  /// In en, this message translates to:
  /// **'Model'**
  String get metadataImport_model;

  /// No description provided for @metadataImport_smea.
  ///
  /// In en, this message translates to:
  /// **'SMEA'**
  String get metadataImport_smea;

  /// No description provided for @metadataImport_smeaDyn.
  ///
  /// In en, this message translates to:
  /// **'SMEA Dyn'**
  String get metadataImport_smeaDyn;

  /// No description provided for @metadataImport_noiseSchedule.
  ///
  /// In en, this message translates to:
  /// **'Noise Schedule'**
  String get metadataImport_noiseSchedule;

  /// No description provided for @metadataImport_cfgRescale.
  ///
  /// In en, this message translates to:
  /// **'CFG Rescale'**
  String get metadataImport_cfgRescale;

  /// No description provided for @metadataImport_qualityToggle.
  ///
  /// In en, this message translates to:
  /// **'Quality Toggle'**
  String get metadataImport_qualityToggle;

  /// No description provided for @metadataImport_ucPreset.
  ///
  /// In en, this message translates to:
  /// **'UC Preset'**
  String get metadataImport_ucPreset;

  /// No description provided for @metadataImport_noData.
  ///
  /// In en, this message translates to:
  /// **'(no data)'**
  String get metadataImport_noData;

  /// No description provided for @metadataImport_selectedCount.
  ///
  /// In en, this message translates to:
  /// **'{count} selected'**
  String metadataImport_selectedCount(int count);

  /// No description provided for @metadataImport_noDataFound.
  ///
  /// In en, this message translates to:
  /// **'No NovelAI metadata found'**
  String get metadataImport_noDataFound;

  /// No description provided for @metadataImport_noParamsSelected.
  ///
  /// In en, this message translates to:
  /// **'No parameters selected'**
  String get metadataImport_noParamsSelected;

  /// No description provided for @metadataImport_appliedCount.
  ///
  /// In en, this message translates to:
  /// **'Applied {count} parameters'**
  String metadataImport_appliedCount(int count);

  /// No description provided for @metadataImport_appliedTitle.
  ///
  /// In en, this message translates to:
  /// **'Metadata Applied'**
  String get metadataImport_appliedTitle;

  /// No description provided for @metadataImport_appliedDescription.
  ///
  /// In en, this message translates to:
  /// **'The following parameters have been applied:'**
  String get metadataImport_appliedDescription;

  /// No description provided for @metadataImport_charactersCount.
  ///
  /// In en, this message translates to:
  /// **'characters'**
  String get metadataImport_charactersCount;

  /// No description provided for @metadataImport_extractFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to extract metadata: {error}'**
  String metadataImport_extractFailed(String error);

  /// No description provided for @metadataImport_appliedToMain.
  ///
  /// In en, this message translates to:
  /// **'Applied {count} parameters to main screen'**
  String metadataImport_appliedToMain(int count);

  /// No description provided for @metadataImport_quickSelectHint.
  ///
  /// In en, this message translates to:
  /// **'Click buttons above to quickly select parameter types'**
  String get metadataImport_quickSelectHint;

  /// No description provided for @shortcut_context_global.
  ///
  /// In en, this message translates to:
  /// **'Global'**
  String get shortcut_context_global;

  /// No description provided for @shortcut_context_generation.
  ///
  /// In en, this message translates to:
  /// **'Generation'**
  String get shortcut_context_generation;

  /// No description provided for @shortcut_context_gallery.
  ///
  /// In en, this message translates to:
  /// **'Gallery List'**
  String get shortcut_context_gallery;

  /// No description provided for @shortcut_context_viewer.
  ///
  /// In en, this message translates to:
  /// **'Image Viewer'**
  String get shortcut_context_viewer;

  /// No description provided for @shortcut_context_tag_library.
  ///
  /// In en, this message translates to:
  /// **'Tag Library'**
  String get shortcut_context_tag_library;

  /// No description provided for @shortcut_context_random_config.
  ///
  /// In en, this message translates to:
  /// **'Random Config'**
  String get shortcut_context_random_config;

  /// No description provided for @shortcut_context_settings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get shortcut_context_settings;

  /// No description provided for @shortcut_context_input.
  ///
  /// In en, this message translates to:
  /// **'Input Field'**
  String get shortcut_context_input;

  /// No description provided for @shortcut_action_navigate_to_generation.
  ///
  /// In en, this message translates to:
  /// **'Generation Page'**
  String get shortcut_action_navigate_to_generation;

  /// No description provided for @shortcut_action_navigate_to_local_gallery.
  ///
  /// In en, this message translates to:
  /// **'Local Gallery'**
  String get shortcut_action_navigate_to_local_gallery;

  /// No description provided for @shortcut_action_navigate_to_online_gallery.
  ///
  /// In en, this message translates to:
  /// **'Online Gallery'**
  String get shortcut_action_navigate_to_online_gallery;

  /// No description provided for @shortcut_action_navigate_to_random_config.
  ///
  /// In en, this message translates to:
  /// **'Random Config'**
  String get shortcut_action_navigate_to_random_config;

  /// No description provided for @shortcut_action_navigate_to_tag_library.
  ///
  /// In en, this message translates to:
  /// **'Tag Library'**
  String get shortcut_action_navigate_to_tag_library;

  /// No description provided for @shortcut_action_navigate_to_statistics.
  ///
  /// In en, this message translates to:
  /// **'Statistics'**
  String get shortcut_action_navigate_to_statistics;

  /// No description provided for @shortcut_action_navigate_to_settings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get shortcut_action_navigate_to_settings;

  /// No description provided for @shortcut_action_generate_image.
  ///
  /// In en, this message translates to:
  /// **'Generate Image'**
  String get shortcut_action_generate_image;

  /// No description provided for @shortcut_action_cancel_generation.
  ///
  /// In en, this message translates to:
  /// **'Cancel Generation'**
  String get shortcut_action_cancel_generation;

  /// No description provided for @shortcut_action_add_to_queue.
  ///
  /// In en, this message translates to:
  /// **'Add to Queue'**
  String get shortcut_action_add_to_queue;

  /// No description provided for @shortcut_action_random_prompt.
  ///
  /// In en, this message translates to:
  /// **'Random Prompt'**
  String get shortcut_action_random_prompt;

  /// No description provided for @shortcut_action_clear_prompt.
  ///
  /// In en, this message translates to:
  /// **'Clear Prompt'**
  String get shortcut_action_clear_prompt;

  /// No description provided for @shortcut_action_toggle_prompt_mode.
  ///
  /// In en, this message translates to:
  /// **'Toggle Prompt Mode'**
  String get shortcut_action_toggle_prompt_mode;

  /// No description provided for @shortcut_action_open_tag_library.
  ///
  /// In en, this message translates to:
  /// **'Open Tag Library'**
  String get shortcut_action_open_tag_library;

  /// No description provided for @shortcut_action_save_image.
  ///
  /// In en, this message translates to:
  /// **'Save Image'**
  String get shortcut_action_save_image;

  /// No description provided for @shortcut_action_upscale_image.
  ///
  /// In en, this message translates to:
  /// **'Upscale Image'**
  String get shortcut_action_upscale_image;

  /// No description provided for @shortcut_action_copy_image.
  ///
  /// In en, this message translates to:
  /// **'Copy Image'**
  String get shortcut_action_copy_image;

  /// No description provided for @shortcut_action_fullscreen_preview.
  ///
  /// In en, this message translates to:
  /// **'Fullscreen Preview'**
  String get shortcut_action_fullscreen_preview;

  /// No description provided for @shortcut_action_open_params_panel.
  ///
  /// In en, this message translates to:
  /// **'Open Params Panel'**
  String get shortcut_action_open_params_panel;

  /// No description provided for @shortcut_action_open_history_panel.
  ///
  /// In en, this message translates to:
  /// **'Open History Panel'**
  String get shortcut_action_open_history_panel;

  /// No description provided for @shortcut_action_reuse_params.
  ///
  /// In en, this message translates to:
  /// **'Reuse Parameters'**
  String get shortcut_action_reuse_params;

  /// No description provided for @shortcut_action_previous_image.
  ///
  /// In en, this message translates to:
  /// **'Previous Image'**
  String get shortcut_action_previous_image;

  /// No description provided for @shortcut_action_next_image.
  ///
  /// In en, this message translates to:
  /// **'Next Image'**
  String get shortcut_action_next_image;

  /// No description provided for @shortcut_action_zoom_in.
  ///
  /// In en, this message translates to:
  /// **'Zoom In'**
  String get shortcut_action_zoom_in;

  /// No description provided for @shortcut_action_zoom_out.
  ///
  /// In en, this message translates to:
  /// **'Zoom Out'**
  String get shortcut_action_zoom_out;

  /// No description provided for @shortcut_action_reset_zoom.
  ///
  /// In en, this message translates to:
  /// **'Reset Zoom'**
  String get shortcut_action_reset_zoom;

  /// No description provided for @shortcut_action_toggle_fullscreen.
  ///
  /// In en, this message translates to:
  /// **'Toggle Fullscreen'**
  String get shortcut_action_toggle_fullscreen;

  /// No description provided for @shortcut_action_close_viewer.
  ///
  /// In en, this message translates to:
  /// **'Close Viewer'**
  String get shortcut_action_close_viewer;

  /// No description provided for @shortcut_action_toggle_favorite.
  ///
  /// In en, this message translates to:
  /// **'Toggle Favorite'**
  String get shortcut_action_toggle_favorite;

  /// No description provided for @shortcut_action_copy_prompt.
  ///
  /// In en, this message translates to:
  /// **'Copy Prompt'**
  String get shortcut_action_copy_prompt;

  /// No description provided for @shortcut_action_reuse_gallery_params.
  ///
  /// In en, this message translates to:
  /// **'Reuse Parameters'**
  String get shortcut_action_reuse_gallery_params;

  /// No description provided for @shortcut_action_delete_image.
  ///
  /// In en, this message translates to:
  /// **'Delete Image'**
  String get shortcut_action_delete_image;

  /// No description provided for @shortcut_action_previous_page.
  ///
  /// In en, this message translates to:
  /// **'Previous Page'**
  String get shortcut_action_previous_page;

  /// No description provided for @shortcut_action_next_page.
  ///
  /// In en, this message translates to:
  /// **'Next Page'**
  String get shortcut_action_next_page;

  /// No description provided for @shortcut_action_refresh_gallery.
  ///
  /// In en, this message translates to:
  /// **'Refresh Gallery'**
  String get shortcut_action_refresh_gallery;

  /// No description provided for @shortcut_action_focus_search.
  ///
  /// In en, this message translates to:
  /// **'Focus Search'**
  String get shortcut_action_focus_search;

  /// No description provided for @shortcut_action_enter_selection_mode.
  ///
  /// In en, this message translates to:
  /// **'Enter Selection Mode'**
  String get shortcut_action_enter_selection_mode;

  /// No description provided for @shortcut_action_open_filter_panel.
  ///
  /// In en, this message translates to:
  /// **'Open Filter Panel'**
  String get shortcut_action_open_filter_panel;

  /// No description provided for @shortcut_action_clear_filter.
  ///
  /// In en, this message translates to:
  /// **'Clear Filter'**
  String get shortcut_action_clear_filter;

  /// No description provided for @shortcut_action_toggle_category_panel.
  ///
  /// In en, this message translates to:
  /// **'Toggle Category Panel'**
  String get shortcut_action_toggle_category_panel;

  /// No description provided for @shortcut_action_jump_to_date.
  ///
  /// In en, this message translates to:
  /// **'Jump to Date'**
  String get shortcut_action_jump_to_date;

  /// No description provided for @shortcut_action_open_folder.
  ///
  /// In en, this message translates to:
  /// **'Open Folder'**
  String get shortcut_action_open_folder;

  /// No description provided for @shortcut_action_select_all_tags.
  ///
  /// In en, this message translates to:
  /// **'Select All Tags'**
  String get shortcut_action_select_all_tags;

  /// No description provided for @shortcut_action_deselect_all_tags.
  ///
  /// In en, this message translates to:
  /// **'Deselect All Tags'**
  String get shortcut_action_deselect_all_tags;

  /// No description provided for @shortcut_action_new_category.
  ///
  /// In en, this message translates to:
  /// **'New Category'**
  String get shortcut_action_new_category;

  /// No description provided for @shortcut_action_new_tag.
  ///
  /// In en, this message translates to:
  /// **'New Tag'**
  String get shortcut_action_new_tag;

  /// No description provided for @shortcut_action_search_tags.
  ///
  /// In en, this message translates to:
  /// **'Search Tags'**
  String get shortcut_action_search_tags;

  /// No description provided for @shortcut_action_batch_delete_tags.
  ///
  /// In en, this message translates to:
  /// **'Batch Delete Tags'**
  String get shortcut_action_batch_delete_tags;

  /// No description provided for @shortcut_action_batch_copy_tags.
  ///
  /// In en, this message translates to:
  /// **'Batch Copy Tags'**
  String get shortcut_action_batch_copy_tags;

  /// No description provided for @shortcut_action_send_to_home.
  ///
  /// In en, this message translates to:
  /// **'Send to Home'**
  String get shortcut_action_send_to_home;

  /// No description provided for @shortcut_action_exit_selection_mode.
  ///
  /// In en, this message translates to:
  /// **'Exit Selection Mode'**
  String get shortcut_action_exit_selection_mode;

  /// No description provided for @shortcut_action_sync_danbooru.
  ///
  /// In en, this message translates to:
  /// **'Sync Danbooru'**
  String get shortcut_action_sync_danbooru;

  /// No description provided for @shortcut_action_generate_preview.
  ///
  /// In en, this message translates to:
  /// **'Generate Preview'**
  String get shortcut_action_generate_preview;

  /// No description provided for @shortcut_action_search_presets.
  ///
  /// In en, this message translates to:
  /// **'Search Presets'**
  String get shortcut_action_search_presets;

  /// No description provided for @shortcut_action_new_preset.
  ///
  /// In en, this message translates to:
  /// **'New Preset'**
  String get shortcut_action_new_preset;

  /// No description provided for @shortcut_action_duplicate_preset.
  ///
  /// In en, this message translates to:
  /// **'Duplicate Preset'**
  String get shortcut_action_duplicate_preset;

  /// No description provided for @shortcut_action_delete_preset.
  ///
  /// In en, this message translates to:
  /// **'Delete Preset'**
  String get shortcut_action_delete_preset;

  /// No description provided for @shortcut_action_close_config.
  ///
  /// In en, this message translates to:
  /// **'Close Config'**
  String get shortcut_action_close_config;

  /// No description provided for @shortcut_action_minimize_to_tray.
  ///
  /// In en, this message translates to:
  /// **'Minimize to Tray'**
  String get shortcut_action_minimize_to_tray;

  /// No description provided for @shortcut_action_quit_app.
  ///
  /// In en, this message translates to:
  /// **'Quit Application'**
  String get shortcut_action_quit_app;

  /// No description provided for @shortcut_action_show_shortcut_help.
  ///
  /// In en, this message translates to:
  /// **'Show Shortcut Help'**
  String get shortcut_action_show_shortcut_help;

  /// No description provided for @shortcut_action_toggle_queue.
  ///
  /// In en, this message translates to:
  /// **'Toggle Queue'**
  String get shortcut_action_toggle_queue;

  /// No description provided for @shortcut_action_toggle_queue_pause.
  ///
  /// In en, this message translates to:
  /// **'Toggle Queue Pause'**
  String get shortcut_action_toggle_queue_pause;

  /// No description provided for @shortcut_action_toggle_theme.
  ///
  /// In en, this message translates to:
  /// **'Toggle Theme'**
  String get shortcut_action_toggle_theme;

  /// No description provided for @shortcut_settings_title.
  ///
  /// In en, this message translates to:
  /// **'Keyboard Shortcuts'**
  String get shortcut_settings_title;

  /// No description provided for @shortcut_settings_description.
  ///
  /// In en, this message translates to:
  /// **'Customize keyboard shortcuts for quick access'**
  String get shortcut_settings_description;

  /// No description provided for @shortcut_settings_enable.
  ///
  /// In en, this message translates to:
  /// **'Enable Shortcuts'**
  String get shortcut_settings_enable;

  /// No description provided for @shortcut_settings_show_badges.
  ///
  /// In en, this message translates to:
  /// **'Show Shortcut Badges'**
  String get shortcut_settings_show_badges;

  /// No description provided for @shortcut_settings_show_in_tooltips.
  ///
  /// In en, this message translates to:
  /// **'Show in Tooltips'**
  String get shortcut_settings_show_in_tooltips;

  /// No description provided for @shortcut_settings_reset_all.
  ///
  /// In en, this message translates to:
  /// **'Reset All to Default'**
  String get shortcut_settings_reset_all;

  /// No description provided for @shortcut_settings_search.
  ///
  /// In en, this message translates to:
  /// **'Search shortcuts...'**
  String get shortcut_settings_search;

  /// No description provided for @shortcut_settings_no_results.
  ///
  /// In en, this message translates to:
  /// **'No shortcuts found'**
  String get shortcut_settings_no_results;

  /// No description provided for @shortcut_settings_press_key.
  ///
  /// In en, this message translates to:
  /// **'Press key combination...'**
  String get shortcut_settings_press_key;

  /// No description provided for @shortcut_settings_conflict.
  ///
  /// In en, this message translates to:
  /// **'Conflict with: {action}'**
  String shortcut_settings_conflict(Object action);

  /// No description provided for @shortcut_help_title.
  ///
  /// In en, this message translates to:
  /// **'Keyboard Shortcuts Help'**
  String get shortcut_help_title;

  /// No description provided for @shortcut_help_search.
  ///
  /// In en, this message translates to:
  /// **'Search shortcuts...'**
  String get shortcut_help_search;

  /// No description provided for @shortcut_help_customize.
  ///
  /// In en, this message translates to:
  /// **'Customize Shortcuts'**
  String get shortcut_help_customize;
}

class _AppLocalizationsDelegate extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) => <String>['en', 'zh'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {


  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en': return AppLocalizationsEn();
    case 'zh': return AppLocalizationsZh();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.'
  );
}

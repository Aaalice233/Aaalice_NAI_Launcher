// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get app_title => 'NAI Launcher';

  @override
  String get app_subtitle => 'NovelAI Third-party Client';

  @override
  String get common_cancel => 'Cancel';

  @override
  String get common_confirm => 'Confirm';

  @override
  String get common_continue => 'Continue';

  @override
  String get common_selectAll => 'Select All';

  @override
  String get common_deselectAll => 'Deselect All';

  @override
  String get common_collapseAll => 'Collapse All';

  @override
  String get common_save => 'Save';

  @override
  String get common_delete => 'Delete';

  @override
  String get common_edit => 'Edit';

  @override
  String get common_close => 'Close';

  @override
  String get common_clear => 'Clear';

  @override
  String get common_copy => 'Copy';

  @override
  String get common_copied => 'Copied';

  @override
  String get common_export => 'Export';

  @override
  String get common_import => 'Import';

  @override
  String get common_loading => 'Loading...';

  @override
  String get common_error => 'Error';

  @override
  String get common_success => 'Success';

  @override
  String get common_retry => 'Retry';

  @override
  String get common_select => 'Select';

  @override
  String get common_reset => 'Reset';

  @override
  String get common_search => 'Search';

  @override
  String get common_add => 'Add';

  @override
  String get common_added => 'Added';

  @override
  String get common_new => 'New';

  @override
  String get common_confirmDelete => 'Confirm Delete';

  @override
  String get common_confirmClear => 'Confirm Clear';

  @override
  String get common_gotIt => 'Got it';

  @override
  String common_deleteItemConfirm(Object itemName) {
    return 'Delete \"$itemName\"? This action cannot be undone.';
  }

  @override
  String common_clearAllItemsConfirm(Object count, Object itemType) {
    return 'Clear all $count $itemType? This action cannot be undone.';
  }

  @override
  String get common_clearInputConfirm => 'Clear the input content?';

  @override
  String get common_today => 'Today';

  @override
  String get common_yesterday => 'Yesterday';

  @override
  String common_daysAgo(Object days) {
    return '$days days ago';
  }

  @override
  String get common_undo => 'Undo';

  @override
  String get common_redo => 'Redo';

  @override
  String get common_refresh => 'Refresh';

  @override
  String get common_download => 'Download';

  @override
  String get common_apply => 'Apply';

  @override
  String get common_move => 'Move';

  @override
  String get common_favorite => 'Favorite';

  @override
  String get common_unfavorite => 'Unfavorite';

  @override
  String get common_ok => 'OK';

  @override
  String get common_replace => 'Replace';

  @override
  String get common_skip => 'Skip';

  @override
  String get common_exit => 'Exit';

  @override
  String get common_folder => 'Folder';

  @override
  String get common_filter => 'Filter';

  @override
  String get common_grid => 'Grid';

  @override
  String get common_date => 'Date';

  @override
  String get common_pack => 'Pack';

  @override
  String get common_multiSelect => 'Multi-select';

  @override
  String get common_category => 'Category';

  @override
  String get common_categories => 'Categories';

  @override
  String get common_items => 'items';

  @override
  String get networkError_connectionTimeout =>
      'Connection timed out. Check your network connection.';

  @override
  String get networkError_sendTimeout => 'Sending timed out. Try again.';

  @override
  String get networkError_receiveTimeout =>
      'Receiving timed out. Image generation may take longer than expected.';

  @override
  String get networkError_requestCancelled => 'The request was cancelled';

  @override
  String get networkError_connection =>
      'Network connection error. Check your network connection.';

  @override
  String get networkError_unknown => 'Unknown error';

  @override
  String get networkError_noResponse => 'The server did not respond';

  @override
  String get networkError_badRequest => 'The request parameters are invalid';

  @override
  String get networkError_authFailed => 'Authentication failed. Sign in again.';

  @override
  String get networkError_insufficientAnlas => 'Insufficient Anlas';

  @override
  String get networkError_forbidden =>
      'You do not have permission to access this resource';

  @override
  String get networkError_notFound => 'The requested resource does not exist';

  @override
  String get networkError_conflict =>
      'The request conflicts with the current state';

  @override
  String get networkError_rateLimited => 'Too many requests. Try again later.';

  @override
  String get networkError_serverInternal => 'Internal server error';

  @override
  String get networkError_badGateway => 'Server gateway error';

  @override
  String get networkError_unavailable =>
      'The service is temporarily unavailable';

  @override
  String networkError_requestFailed(int code) {
    return 'Request failed ($code)';
  }

  @override
  String get nav_canvas => 'Canvas';

  @override
  String get nav_onlineGallery => 'Online Gallery';

  @override
  String get nav_randomConfig => 'Random Config';

  @override
  String get nav_dictionary => 'Dictionary';

  @override
  String get nav_discordCommunity => 'Discord Community';

  @override
  String get nav_githubRepo => 'GitHub Repository';

  @override
  String get nav_expandSidebar => 'Expand sidebar';

  @override
  String get nav_collapseSidebar => 'Collapse sidebar';

  @override
  String get auth_login => 'Login';

  @override
  String get auth_logout => 'Logout';

  @override
  String get auth_email => 'Email';

  @override
  String get auth_password => 'Password';

  @override
  String get auth_loginButton => 'Sign In';

  @override
  String get auth_loginFailed => 'Login failed';

  @override
  String get auth_loginTip =>
      'Sign in with your NovelAI account\nAll data is stored locally only';

  @override
  String get auth_loggedIn => 'Logged in';

  @override
  String get auth_emailRequired => 'Please enter email';

  @override
  String get auth_emailInvalid => 'Please enter a valid email address';

  @override
  String get auth_passwordRequired => 'Please enter password';

  @override
  String get auth_tokenLogin => 'API Token Login';

  @override
  String get auth_tokenLoginRecommended => 'API Token Login (Recommended)';

  @override
  String get auth_credentialsLogin => 'Email & Password';

  @override
  String get auth_credentialsLoginUnavailable =>
      'Email/password login is currently unavailable. Please use Token login.';

  @override
  String get auth_tokenHint => 'Enter your Persistent API Token';

  @override
  String get auth_tokenRequired => 'Please enter token';

  @override
  String get auth_tokenInvalid =>
      'Invalid token format, should start with pst-';

  @override
  String get auth_nicknameOptional => 'Nickname (optional)';

  @override
  String get auth_nicknameHint => 'Set a recognizable name for this account';

  @override
  String get auth_thirdPartyLogin => 'Third-party Site';

  @override
  String get auth_thirdPartyApiSite => 'Third-party API Site';

  @override
  String get auth_imageApiSiteOptional => 'Image API Site (optional)';

  @override
  String get auth_imageApiSiteHint =>
      'Leave empty to use the same third-party API site';

  @override
  String get auth_thirdPartyNicknameHint =>
      'For example: self-hosted site / mirror site';

  @override
  String get auth_thirdPartyTokenHint =>
      'Enter the API token from the third-party site';

  @override
  String get auth_thirdPartyCompatibilityHint =>
      'The third-party site must be compatible with NovelAI subscription and image-generation APIs. The token will be sent as a Bearer token.';

  @override
  String get auth_thirdPartyApiSiteRequired => 'Enter third-party API site URL';

  @override
  String get auth_validateAndLogin => 'Validate & Login';

  @override
  String get auth_tokenGuide => 'Get Token from NovelAI settings';

  @override
  String get auth_savedAccounts => 'Saved Accounts';

  @override
  String get auth_addAccount => 'Add Account';

  @override
  String get auth_manageAccounts => 'Manage';

  @override
  String auth_moreAccounts(Object count) {
    return '$count more accounts';
  }

  @override
  String get auth_tokenNotFound => 'Token not found for this account';

  @override
  String get auth_switchAccount => 'Switch Account';

  @override
  String get auth_currentAccount => 'Current Account';

  @override
  String get auth_selectAccount => 'Select Account';

  @override
  String get auth_deleteAccount => 'Delete Account';

  @override
  String auth_deleteAccountConfirm(Object name) {
    return 'Are you sure you want to delete \"$name\"? This cannot be undone.';
  }

  @override
  String get auth_removeAvatar => 'Remove Avatar';

  @override
  String get auth_selectFromGallery => 'Select from Gallery';

  @override
  String get auth_takePhoto => 'Take Photo';

  @override
  String get auth_quickLogin => 'Quick Login';

  @override
  String get auth_nicknameRequired => 'Please enter nickname';

  @override
  String auth_createdAt(Object date) {
    return 'Created at $date';
  }

  @override
  String get auth_error_networkTimeout => 'Connection timeout';

  @override
  String get auth_error_networkError => 'Network error';

  @override
  String get auth_error_authFailed => 'Authentication failed';

  @override
  String get auth_error_credentialsLoginUnavailable =>
      'Email/password login is currently unavailable';

  @override
  String get auth_error_credentialsLoginUnavailable_hint =>
      'NovelAI now requires a web safety check for email/password login. Please use a Persistent API Token instead.';

  @override
  String get auth_error_serverError => 'Server error';

  @override
  String get auth_error_unknown => 'Unknown error';

  @override
  String get auth_autoLogin => 'Auto login';

  @override
  String get auth_forgotPassword => 'Forgot password?';

  @override
  String get auth_passwordTooShort => 'Password must be at least 6 characters';

  @override
  String get auth_loggingIn => 'Logging in...';

  @override
  String get auth_pleaseWait => 'Please wait';

  @override
  String get auth_viewTroubleshootingTips => 'View Troubleshooting Tips';

  @override
  String get auth_troubleshoot_checkConnection_title =>
      'Check Network Connection';

  @override
  String get auth_troubleshoot_checkConnection_desc =>
      'Ensure your device is connected to the internet';

  @override
  String get auth_troubleshoot_retry_title => 'Try Again';

  @override
  String get auth_troubleshoot_retry_desc =>
      'Network issues may be temporary, please retry';

  @override
  String get auth_troubleshoot_proxy_title => 'Check Proxy Settings';

  @override
  String get auth_troubleshoot_proxy_desc =>
      'If using a proxy, verify it\'s configured correctly';

  @override
  String get auth_troubleshoot_firewall_title => 'Check Firewall Settings';

  @override
  String get auth_troubleshoot_firewall_desc =>
      'Ensure your firewall allows connections to NovelAI servers';

  @override
  String get auth_troubleshoot_serverStatus_title => 'Check Server Status';

  @override
  String get auth_troubleshoot_serverStatus_desc =>
      'Visit NovelAI status page or community to check for outages';

  @override
  String get common_paste => 'Paste';

  @override
  String get common_default => 'Default';

  @override
  String get settings_title => 'Settings';

  @override
  String get settings_account => 'Account';

  @override
  String get settings_appearance => 'Appearance';

  @override
  String get settings_style => 'Style';

  @override
  String get settings_font => 'Font';

  @override
  String get settings_language => 'Language';

  @override
  String get settings_languageChinese => '简体中文';

  @override
  String get settings_languageTraditionalChinese => '繁體中文';

  @override
  String get settings_languageEnglish => 'English';

  @override
  String get settings_languageJapanese => '日本語';

  @override
  String get settings_shortcuts => 'Shortcuts';

  @override
  String get settings_generation => 'Generation';

  @override
  String get settings_dataStorage => 'Data & Storage';

  @override
  String get settings_privacySharing => 'Privacy & Sharing';

  @override
  String get settings_integrations => 'Integrations';

  @override
  String get settings_generationInputSection => 'Input';

  @override
  String get settings_generationOutputSection => 'Image Output';

  @override
  String get settings_generationRetrySection => 'Retry on Failure';

  @override
  String get settings_generationFeedbackSection => 'Completion Alert';

  @override
  String get settings_alphaModeTitle => 'Alpha mode for transparent images';

  @override
  String get settings_alphaModeStraight => 'Straight';

  @override
  String get settings_alphaModePremultiplied => 'Premultiplied';

  @override
  String get settings_alphaModeStraightDescription =>
      'Preserve RGB without multiplying by alpha. Best for further editing and the NovelAI website default.';

  @override
  String get settings_alphaModePremultipliedDescription =>
      'Store RGB multiplied by alpha for compositing and rendering pipelines that expect premultiplied input.';

  @override
  String get settings_promptAssistant => 'Prompt Assistant';

  @override
  String get settings_selectStyle => 'Select Style';

  @override
  String get settings_defaultPreset => 'Default';

  @override
  String get settings_selectFont => 'Select Font';

  @override
  String get settings_selectLanguage => 'Select Language';

  @override
  String settings_loadFailed(Object error) {
    return 'Load failed: $error';
  }

  @override
  String get settings_imageSavePath => 'Image Save Location';

  @override
  String get settings_autoSave => 'Auto Save';

  @override
  String get settings_autoSaveSubtitle =>
      'Automatically save images after generation';

  @override
  String get settings_about => 'About';

  @override
  String settings_version(Object version) {
    return 'Version $version';
  }

  @override
  String get settings_openSource => 'Open Source';

  @override
  String get settings_openSourceSubtitle =>
      'View source code and documentation';

  @override
  String get settings_fileLogging => 'Record application logs';

  @override
  String get settings_fileLoggingSubtitle =>
      'Off by default; enable only for troubleshooting. When enabled, logs are written to Documents/NAI_Launcher/logs. When disabled, log files are no longer created or written.';

  @override
  String get settings_pathReset => 'Reset to default location';

  @override
  String get settings_pathSaved => 'Save location updated';

  @override
  String get settings_selectFolder => 'Select Save Folder';

  @override
  String get settings_vibeLibraryPath => 'Vibe Library Path';

  @override
  String get settings_hiveStoragePath => 'Data Storage Path';

  @override
  String get settings_selectVibeLibraryFolder => 'Select Vibe Library Folder';

  @override
  String get settings_selectHiveFolder => 'Select Data Storage Folder';

  @override
  String get settings_pathSavedRestartRequired =>
      'Path updated, restart to apply changes';

  @override
  String get settings_accountType => 'Account Type';

  @override
  String get settings_thirdPartyApiAccount => 'Third-party Site API';

  @override
  String get settings_apiSite => 'API Site';

  @override
  String get settings_notLoggedIn => 'Log in to set avatar and nickname';

  @override
  String get settings_goToLogin => 'Go to Login';

  @override
  String get settings_tapToChangeAvatar => 'Tap to change avatar';

  @override
  String get settings_changeAvatar => 'Change Avatar';

  @override
  String get settings_removeAvatar => 'Remove Avatar';

  @override
  String get settings_accountEmail => 'Account Email';

  @override
  String get settings_emailAccount => 'Email Account';

  @override
  String get settings_tokenAccount => 'Token Account';

  @override
  String get settings_setAsDefault => 'Set as Default';

  @override
  String get settings_defaultAccount => 'Default';

  @override
  String get settings_editNickname => 'Edit Nickname';

  @override
  String get settings_nickname => 'Nickname';

  @override
  String get settings_nicknameHint => 'Enter 2-32 characters';

  @override
  String get settings_nicknameEmpty => 'Please enter a nickname';

  @override
  String settings_nicknameTooLong(int maxLength) {
    return 'Nickname cannot exceed $maxLength characters';
  }

  @override
  String get settings_nicknameUpdated => 'Nickname updated';

  @override
  String get settings_avatarUpdated => 'Avatar updated';

  @override
  String get settings_avatarRemoved => 'Avatar removed';

  @override
  String get settings_setAsDefaultSuccess => 'Set as default account';

  @override
  String get generation_title => 'Generate';

  @override
  String get generation_generate => 'Generate';

  @override
  String generation_cooldownRemaining(Object seconds) {
    return 'Wait ${seconds}s';
  }

  @override
  String get generation_generating => 'Generating...';

  @override
  String get generation_cancelGeneration => 'Cancel Generation';

  @override
  String get generation_skipCurrentBatch => 'Skip Current Batch';

  @override
  String get generation_pleaseInputPrompt => 'Please enter prompt';

  @override
  String get generation_emptyPromptHint => 'Enter prompt and click generate';

  @override
  String get generation_imageWillShowHere => 'Image will be displayed here';

  @override
  String get generation_generationFailed => 'Generation failed';

  @override
  String generation_progress(Object progress) {
    return 'Generating... $progress%';
  }

  @override
  String get generation_params => 'Parameters';

  @override
  String get generation_paramsSettings => 'Parameter Settings';

  @override
  String get generation_history => 'History';

  @override
  String get generation_historyRecord => 'History Records';

  @override
  String get generation_failedStreamSnapshot => 'Failed snapshot';

  @override
  String get generation_failedStreamSnapshotHint =>
      'Generation did not finish; only the last preview frame is kept. It cannot be saved, favorited, or used for image workflows.';

  @override
  String get generation_noHistory => 'No history records';

  @override
  String get generation_clearHistory => 'Clear History';

  @override
  String get generation_clearHistoryConfirm =>
      'Are you sure you want to clear all history records? This action cannot be undone.';

  @override
  String get generation_model => 'Model';

  @override
  String generation_opusUsageRemaining(Object percent) {
    return '$percent% of Opus Generations remaining';
  }

  @override
  String generation_opusUsageEstimate(Object count) {
    return 'About $count images left';
  }

  @override
  String get generation_opusUsageRefill =>
      'The allowance refills automatically over time';

  @override
  String get generation_opusUsageExhausted =>
      'Your Opus allowance is used up. V5 generations will cost Anlas until it refills.';

  @override
  String get generation_imageSize => 'Image Size';

  @override
  String get generation_transparentBackground => 'Transparent BG';

  @override
  String generation_e2eUpscaleHint(Object size) {
    return 'Server outputs $size';
  }

  @override
  String get generation_sampler => 'Sampler';

  @override
  String generation_steps(Object steps) {
    return 'Steps: $steps';
  }

  @override
  String generation_cfgScale(Object scale) {
    return 'CFG Scale: $scale';
  }

  @override
  String get generation_seed => 'Seed';

  @override
  String get generation_previewApplySeed =>
      'Use the seed of the displayed image';

  @override
  String get generation_transparencyBackgroundTitle =>
      'Transparency Background';

  @override
  String get generation_transparencyChecker => 'Theme Checkerboard';

  @override
  String get generation_transparencyCheckerLight => 'Light Checkerboard';

  @override
  String get generation_transparencyCheckerDark => 'Dark Checkerboard';

  @override
  String get generation_transparencyNone => 'None';

  @override
  String get generation_transparencyBlack => 'Black';

  @override
  String get generation_transparencyWhite => 'White';

  @override
  String get generation_transparencyGray => 'Gray';

  @override
  String get generation_transparencyRed => 'Red';

  @override
  String get generation_transparencyGreen => 'Green';

  @override
  String get generation_transparencyBlue => 'Blue';

  @override
  String get generation_transparencyCustom => 'Custom Color';

  @override
  String get generation_seedRandom => 'Random';

  @override
  String get generation_seedLock => 'Lock Seed';

  @override
  String get generation_seedUnlock => 'Unlock Seed';

  @override
  String get generation_advancedOptions => 'Advanced Options';

  @override
  String get generation_smea => 'SMEA';

  @override
  String get generation_smeaSubtitle =>
      'Improve generation quality for large images';

  @override
  String get generation_smeaDyn => 'SMEA DYN';

  @override
  String get generation_smeaDescription =>
      'High resolution samplers will automatically be used above a certain image size';

  @override
  String generation_cfgRescale(Object value) {
    return 'CFG Rescale: $value';
  }

  @override
  String get generation_noiseSchedule => 'Noise Schedule';

  @override
  String get prompt_positive => 'Prompt';

  @override
  String get prompt_negative => 'Undesired Content';

  @override
  String get prompt_positivePrompt => 'Prompt';

  @override
  String get prompt_negativePrompt => 'Undesired Content';

  @override
  String get prompt_mainPositive => 'Main Prompt';

  @override
  String get prompt_mainNegative => 'Main Prompt (Undesired Content)';

  @override
  String get prompt_characterPrompts => 'Multi-Character Prompts';

  @override
  String get prompt_finalPrompt => 'Final Effective Prompt';

  @override
  String get prompt_finalNegative => 'Final Effective Undesired Content';

  @override
  String prompt_importedCharacters(int count) {
    return 'Imported $count character(s)';
  }

  @override
  String get prompt_characterPromptReplaced => 'Replaced character prompts';

  @override
  String prompt_characterPromptAppended(Object count) {
    return 'Appended character prompts ($count character(s))';
  }

  @override
  String prompt_smartDecomposedWithCharacters(Object count) {
    return 'Decomposed into main prompt + $count character(s)';
  }

  @override
  String get prompt_appliedToMainPrompt => 'Applied to main prompt';

  @override
  String get prompt_inputPrompt => 'Enter prompt...';

  @override
  String get prompt_describeImage =>
      'Describe the image you want to generate...';

  @override
  String get prompt_describeImageWithHint =>
      'Enter prompt to describe image, type < to reference library, supports tag autocomplete';

  @override
  String get prompt_searchHint => 'Search prompt';

  @override
  String prompt_searchMatchCount(Object current, Object total) {
    return '$current / $total';
  }

  @override
  String get prompt_searchPrevious => 'Previous match';

  @override
  String get prompt_searchNext => 'Next match';

  @override
  String get prompt_searchClose => 'Close search';

  @override
  String get prompt_replaceHint => 'Replace with';

  @override
  String get prompt_replaceToggle => 'Toggle replace';

  @override
  String get prompt_replaceCurrent => 'Replace current match (Enter)';

  @override
  String get prompt_replaceAll => 'Replace all (Ctrl+Enter)';

  @override
  String prompt_replaceAllDone(Object count) {
    return 'Replaced $count matches';
  }

  @override
  String get promptAssistant_needPrompt =>
      'Enter a prompt before using the assistant';

  @override
  String promptAssistant_requestFailed(Object error) {
    return 'Assistant request failed: $error';
  }

  @override
  String get promptAssistant_enableAssistant => 'Enable Prompt Assistant';

  @override
  String get promptAssistant_desktopOverlay => 'Desktop bottom-right overlay';

  @override
  String get kritaBridge_busyGenerating =>
      'Krita Bridge is generating. Wait for the current task to finish.';

  @override
  String get prompt_negativeFixedTagPrefix =>
      'Undesired Content Fixed Tag Prefix';

  @override
  String get prompt_negativeFixedTagSuffix =>
      'Undesired Content Fixed Tag Suffix';

  @override
  String get prompt_unwantedContent =>
      'Content you don\'t want in the image...';

  @override
  String get prompt_smartAutocomplete => 'Smart Autocomplete';

  @override
  String get prompt_smartAutocompleteSubtitle =>
      'Show tag suggestions while typing';

  @override
  String get prompt_autoFormat => 'Auto Format';

  @override
  String get prompt_autoFormatSubtitle =>
      'Convert Chinese commas and tag spaces while preserving line breaks';

  @override
  String get prompt_highlightEmphasis => 'Highlight Emphasis';

  @override
  String get prompt_highlightEmphasisSubtitle =>
      'Highlight brackets and weight syntax';

  @override
  String get prompt_sdSyntaxAutoConvert => 'SD Syntax Auto Convert';

  @override
  String get prompt_sdSyntaxAutoConvertSubtitle =>
      'Convert SD weight syntax to NAI format on blur';

  @override
  String get prompt_resolveAliasOnCopy => 'Expand Library On Copy';

  @override
  String get prompt_resolveAliasOnCopySubtitle =>
      'Replace <library name> with its content when copying or cutting';

  @override
  String get prompt_cooccurrenceRecommendation =>
      'Co-occurrence Tag Recommendation';

  @override
  String get prompt_cooccurrenceRecommendationSubtitle =>
      'Suggest after accepting a tag; Ctrl+Shift+Space or Ctrl+click also opens related tags';

  @override
  String get prompt_regexRulesManage => 'Regex Replace Rules...';

  @override
  String prompt_regexRulesCount(int count) {
    return '$count rule(s) configured';
  }

  @override
  String prompt_regexReplaceApplied(int count) {
    return 'Regex replace: $count rule(s)';
  }

  @override
  String prompt_regexInvalidRules(Object names) {
    return 'Skipped invalid regex rule(s): $names';
  }

  @override
  String get regexRules_title => 'Regex Replace Rules';

  @override
  String get regexRules_hint =>
      'Rules run in order on the whole prompt, before SD conversion and auto format. Use \$1, \$2 in the replacement to reference capture groups.';

  @override
  String get regexRules_empty => 'No rules yet. Create one below.';

  @override
  String get regexRules_add => 'New Rule';

  @override
  String get regexRules_unnamed => 'Untitled rule';

  @override
  String get regexRules_invalidBadge => 'Invalid';

  @override
  String get regexRules_deleteConfirmTitle => 'Delete rule';

  @override
  String regexRules_deleteConfirmMessage(Object name) {
    return 'Delete \"$name\"? This cannot be undone.';
  }

  @override
  String get regexRules_newTitle => 'New Rule';

  @override
  String get regexRules_editTitle => 'Edit Rule';

  @override
  String get regexRules_nameLabel => 'Rule name (optional)';

  @override
  String get regexRules_nameHint => 'e.g. Normalize hair color';

  @override
  String get regexRules_patternLabel => 'Match (regular expression)';

  @override
  String get regexRules_patternHint => 'e.g. \\bblue[ _]hair\\b';

  @override
  String get regexRules_replacementLabel => 'Replace with';

  @override
  String get regexRules_replacementHint => 'e.g. aqua hair';

  @override
  String get regexRules_caseSensitive => 'Case sensitive';

  @override
  String get regexRules_patternRequired => 'The match pattern cannot be empty';

  @override
  String regexRules_patternInvalid(Object error) {
    return 'Invalid regular expression: $error';
  }

  @override
  String get regexRules_testTitle => 'Test';

  @override
  String get regexRules_testInputHint => 'Paste a prompt to preview the result';

  @override
  String get regexRules_testNoChange => 'No change';

  @override
  String get regexRules_testNoRules => 'No enabled rules';

  @override
  String get prompt_formatted => 'Formatted';

  @override
  String get image_save => 'Save';

  @override
  String get image_copy => 'Copy';

  @override
  String get image_upscale => 'Upscale';

  @override
  String get image_saveToLibrary => 'Save to Library';

  @override
  String image_imageSaved(Object path) {
    return 'Image saved to: $path';
  }

  @override
  String image_saveFailed(Object error) {
    return 'Save failed: $error';
  }

  @override
  String get image_copiedToClipboard => 'Copied to clipboard';

  @override
  String image_copyFailed(Object error) {
    return 'Copy failed: $error';
  }

  @override
  String get config_newPreset => 'New Preset';

  @override
  String get config_deletePreset => 'Delete Preset';

  @override
  String get img2img_title => 'Image2Image';

  @override
  String get img2img_enabled => 'Enabled';

  @override
  String get img2img_sourceImage => 'Source Image';

  @override
  String get img2img_strength => 'Strength';

  @override
  String get img2img_strengthHint =>
      'Higher values create greater difference from original';

  @override
  String get img2img_noise => 'Noise';

  @override
  String get img2img_noiseHint => 'Add extra noise for more variation';

  @override
  String get img2img_clearSettings => 'Clear Image2Image Settings';

  @override
  String get img2img_changeImage => 'Change Image';

  @override
  String get img2img_removeImage => 'Remove Image';

  @override
  String img2img_selectFailed(Object error) {
    return 'Failed to select image: $error';
  }

  @override
  String get img2img_editImage => 'Edit Image';

  @override
  String get img2img_editApplied =>
      'The edited image is now the new source image';

  @override
  String get img2img_uploadImage => 'Upload Image';

  @override
  String get img2img_drawSketch => 'Draw Sketch';

  @override
  String get img2img_inpaint => 'Inpaint';

  @override
  String get img2img_inpaintStrength => 'Inpaint Strength';

  @override
  String get img2img_inpaintStrengthHint =>
      'Higher values make the masked area diverge more from the current source image';

  @override
  String get img2img_inpaintPendingHint =>
      'Click Inpaint to open the canvas, mark the region you want to repaint with brush, eraser, or selection tools, then return here and use the main generate button.';

  @override
  String get img2img_inpaintReadyHint =>
      'Mask loaded. The next generation will repaint only the masked area.';

  @override
  String get img2img_inpaintMaskReady => 'Inpaint mask is ready';

  @override
  String get img2img_generateVariations => 'Generate Variations';

  @override
  String get img2img_directorTools => 'Director Tools';

  @override
  String get img2img_directorToolsHint =>
      'Send the current source image through a Director Tool. When the result is ready, you can apply it back as the new source image.';

  @override
  String get img2img_directorPrompt => 'Extra Prompt';

  @override
  String get img2img_directorPromptHint =>
      'Add guidance when needed, such as target emotion or color direction';

  @override
  String img2img_directorRun(Object tool) {
    return 'Run $tool';
  }

  @override
  String get img2img_directorRunning => 'Processing...';

  @override
  String get img2img_directorResult => 'Result';

  @override
  String img2img_directorResultReady(Object tool) {
    return '$tool completed';
  }

  @override
  String get img2img_directorApplied =>
      'Applied the Director Tool result as the new source image';

  @override
  String get img2img_directorDefry => 'Defry';

  @override
  String get img2img_directorDefryHint =>
      'Reduce noise or over-saturation in the result (0 = off, 5 = max)';

  @override
  String get img2img_directorEmotionLevel => 'Emotion Level';

  @override
  String get img2img_directorEmotionLevelHint =>
      'How strongly the emotion is applied (0 = subtle, 5 = strong)';

  @override
  String get img2img_directorEmotionPresets => 'Presets';

  @override
  String get img2img_directorApplyAsSource => 'Use as Source';

  @override
  String get img2img_directorSourceImage => 'Source Image';

  @override
  String get img2img_variationsStarted => 'Generating variations...';

  @override
  String get img2img_directorRemoveBackground => 'Remove Background';

  @override
  String get img2img_directorLineArt => 'Line Art';

  @override
  String get img2img_directorSketch => 'Sketch';

  @override
  String get img2img_directorColorize => 'Colorize';

  @override
  String get img2img_directorEmotion => 'Fix Emotion';

  @override
  String get img2img_directorDeclutter => 'Declutter';

  @override
  String get img2img_enhance => 'Enhance';

  @override
  String get img2img_enhanceHint =>
      'Enhance keeps using the current prompt while it upscales and regenerates the source image in latent space.';

  @override
  String get img2img_enhanceMagnitude => 'Magnitude';

  @override
  String get img2img_enhanceShowIndividualSettings =>
      'Show Individual Settings';

  @override
  String get img2img_enhanceUpscaleAmount => 'Upscale Amount';

  @override
  String get img2img_enhanceScaleMax => 'Max';

  @override
  String get img2img_focusedInpaint => 'Focused Inpainting';

  @override
  String get img2img_focusedInpaintEnabledHint =>
      'Enabled. Adjust the focus area and Minimum Context Area from the top-left control in the inpaint editor.';

  @override
  String get img2img_focusedInpaintDisabledHint =>
      'Regular inpaint is the default. To use Focused Inpaint, enable it from the top-left control in the inpaint editor and draw a focus area.';

  @override
  String get img2img_disabled => 'Disabled';

  @override
  String get img2img_novelAiCloudUpscale => 'NovelAI cloud upscale (fixed 4x)';

  @override
  String get img2img_comfyuiEnableHint =>
      'Enable and connect ComfyUI in Settings > ComfyUI first.';

  @override
  String get img2img_upscaleMode => 'Upscale Mode';

  @override
  String get img2img_upscaleRegularModel => 'Regular Model';

  @override
  String get img2img_upscaleModel => 'Upscale Model';

  @override
  String get img2img_noSeedvr2Models =>
      'No usable SeedVR2 model found. Refresh the model list and check ComfyUI\'s native models/diffusion_models and models/vae folders or the SeedVR2 custom-node model folder.';

  @override
  String get img2img_noRegularUpscaleModels =>
      'No regular upscale model found. Refresh the model list or check models/upscale_models.';

  @override
  String get img2img_useNativeSeedvr2Workflow =>
      'Using the native ComfyUI SeedVR2 one-step upscale workflow.';

  @override
  String get img2img_useSeedvr2TiledWorkflow =>
      'Using the SeedVR2TilingUpscaler tiled upscale workflow.';

  @override
  String get img2img_useSeedvr2Workflow =>
      'Using the SeedVR2VideoUpscaler workflow.';

  @override
  String get img2img_useRegularUpscaleWorkflow =>
      'Using UpscaleModelLoader + ImageUpscaleWithModel, then correcting to the target scale with Lanczos.';

  @override
  String get img2img_useRtxUpscaleWorkflow =>
      'Using RTX Video Super Resolution. No model selection is required.';

  @override
  String get img2img_refreshModelList => 'Refresh model list';

  @override
  String get img2img_startUpscale => 'Start Upscale';

  @override
  String get img2img_novelAiUpscaleComplete => 'NovelAI upscale complete';

  @override
  String img2img_upscaleComplete(Object width, Object height) {
    return 'Upscale complete (${width}x$height)';
  }

  @override
  String img2img_regularUpscaleComplete(Object width, Object height) {
    return 'Regular model upscale complete (${width}x$height)';
  }

  @override
  String img2img_rtxUpscaleComplete(Object width, Object height) {
    return 'RTX upscale complete (${width}x$height)';
  }

  @override
  String get img2img_noAvailableSeedvr2Model =>
      'No available SeedVR2 model selected';

  @override
  String get img2img_noAvailableRegularUpscaleModel =>
      'No available regular upscale model selected';

  @override
  String get img2img_decodeSourceFailed => 'Failed to decode source image';

  @override
  String get img2img_metricSpeed => 'Speed';

  @override
  String get img2img_metricVram => 'VRAM';

  @override
  String get img2img_metricQuality => 'Quality';

  @override
  String get img2img_seedvr2Engine => 'SeedVR2 Engine';

  @override
  String get img2img_seedvr2EngineAuto => 'Auto';

  @override
  String get img2img_seedvr2EngineNative => 'Native';

  @override
  String get img2img_seedvr2EngineLegacy => 'Compatibility';

  @override
  String get img2img_seedvr2EngineResolvedNative =>
      'Using native SeedVR2 built into ComfyUI.';

  @override
  String get img2img_seedvr2EngineResolvedLegacy =>
      'Using the installed SeedVR2 custom nodes.';

  @override
  String get img2img_seedvr2EngineUnavailable =>
      'The selected SeedVR2 engine or its required models are unavailable. Refresh the model list or switch engines.';

  @override
  String get img2img_seedvr2VaeTileHint =>
      'Sets the tile size used for SeedVR2 VAE encoding and decoding.';

  @override
  String get img2img_seedvr2UseTiledUpscale => 'Use tiled upscale';

  @override
  String get img2img_seedvr2UseTiledUpscaleHint =>
      'When enabled, uses SeedVR2TilingUpscaler. Recommended for large images or high VRAM pressure.';

  @override
  String get settings_comfyUiSeedvr2EmbedNaiMetadata =>
      'Write NAI generation parameters to SeedVR2 results';

  @override
  String get settings_comfyUiSeedvr2EmbedNaiMetadataHint =>
      'Off by default. When enabled, writes the launcher\'s current prompts and generation parameters. When disabled, preserves the PNG metadata returned by ComfyUI.';

  @override
  String get img2img_seedvr2TileSize => 'Tile Size';

  @override
  String get img2img_seedvr2TileSizeHint =>
      'Also controls SeedVR2TilingUpscaler tile_width / tile_height.';

  @override
  String get img2img_seedvr2BlocksToSwap => 'Blocks Offloaded To RAM';

  @override
  String get img2img_seedvr2BlocksToSwapHint =>
      'How many DiT blocks stay in system RAM and are streamed to VRAM during inference. Higher saves VRAM but uses more RAM and runs slower; lower it (even to 0) when VRAM is plentiful. Raise it if you hit out-of-memory errors.';

  @override
  String get img2img_upscalePanelOpened =>
      'Opened the Image2Image Upscale panel';

  @override
  String get editor_done => 'Done';

  @override
  String get editor_tolerance => 'Tolerance';

  @override
  String get editor_intensity => 'Intensity';

  @override
  String get editor_sourcePoint => 'Alt+Click to set source point';

  @override
  String get editor_brushPresets => 'Brush Presets';

  @override
  String get editor_size => 'Size';

  @override
  String get editor_opacity => 'Opacity';

  @override
  String get editor_hardness => 'Hardness';

  @override
  String get editor_undo => 'Undo';

  @override
  String get editor_redo => 'Redo';

  @override
  String get editor_clearLayer => 'Clear Layer';

  @override
  String get editor_clearSelection => 'Clear Selection';

  @override
  String get editor_resetView => 'Reset View';

  @override
  String get editor_zoom => 'Zoom';

  @override
  String get editor_toolBrush => 'Brush';

  @override
  String get editor_toolEraser => 'Eraser';

  @override
  String get editor_toolFill => 'Fill';

  @override
  String get editor_toolMagicWand => 'Magic Wand';

  @override
  String get editor_magicWandMode => 'Selection method';

  @override
  String get editor_magicWandSmartObject => 'Smart object (EfficientViT)';

  @override
  String get editor_magicWandColorArea => 'Color area (flood fill)';

  @override
  String get editor_magicWandSmartHelp =>
      'Click the object to select. The first use downloads the approximately 133 MiB EfficientViT-SAM L0 model from MIT Han Lab (Apache-2.0), then keeps it locally.';

  @override
  String get editor_magicWandColorHelp =>
      'Click a contiguous region of similar color. This works best on flat, clean boundaries and requires no model download.';

  @override
  String get editor_magicWandInvert => 'Invert result';

  @override
  String get editor_toolLine => 'Line';

  @override
  String get editor_toolRectSelect => 'Rectangle';

  @override
  String get editor_toolEllipseSelect => 'Ellipse';

  @override
  String get editor_toolLassoSelect => 'Lasso';

  @override
  String get editor_toolColorPicker => 'Color Picker';

  @override
  String get editor_toolCloneStamp => 'Clone Stamp';

  @override
  String get editor_toolBlur => 'Blur';

  @override
  String get editor_shortcutUndo => 'Undo (Ctrl+Z)';

  @override
  String get editor_shortcutRedo => 'Redo (Ctrl+Y)';

  @override
  String get editor_back => 'Back';

  @override
  String get editor_layers => 'Layers';

  @override
  String get editor_loadMask => 'Load Mask';

  @override
  String get editor_togglePanels => 'Toggle Panels';

  @override
  String get editor_fillClosedRegion => 'Fill Closed Region';

  @override
  String get editor_resetMask => 'Reset Mask';

  @override
  String get editor_zoomIn => 'Zoom In';

  @override
  String get editor_zoomOut => 'Zoom Out';

  @override
  String get editor_fitToWindow => 'Fit to Window';

  @override
  String get editor_tempColorPickerShortcut =>
      'Alt+Click: temporary color picker';

  @override
  String get editor_shortcutHelpTitle => 'Shortcut Help';

  @override
  String get editor_shortcutPaintTools => 'Paint Tools';

  @override
  String get editor_shortcutSelectionTools => 'Selection Tools';

  @override
  String get editor_shortcutCanvasView => 'Canvas View';

  @override
  String get editor_shortcutBrushAdjust => 'Brush Adjustments';

  @override
  String get editor_shortcutColors => 'Colors';

  @override
  String get editor_shortcutCanvasActions => 'Canvas Actions';

  @override
  String get editor_shortcutHistoryActions => 'History Actions';

  @override
  String get editor_shortcutSelectionActions => 'Selection Actions';

  @override
  String get editor_shortcutTemporaryColorPicker => 'Temporary Color Picker';

  @override
  String get editor_shortcutRectSelection => 'Rectangle Selection';

  @override
  String get editor_shortcutEllipseSelection => 'Ellipse Selection';

  @override
  String get editor_shortcutLassoSelection => 'Lasso Selection';

  @override
  String get editor_shortcut100Zoom => '100% Zoom';

  @override
  String get editor_shortcutFitHeight => 'Fit Height';

  @override
  String get editor_shortcutFitWidth => 'Fit Width';

  @override
  String get editor_shortcutRotateLeft15 => 'Rotate Left 15°';

  @override
  String get editor_shortcutResetRotation => 'Reset Rotation';

  @override
  String get editor_shortcutRotateRight15 => 'Rotate Right 15°';

  @override
  String get editor_shortcutFlipHorizontal => 'Flip Horizontal';

  @override
  String get editor_shortcutWheel => 'Mouse Wheel';

  @override
  String get editor_shortcutBrushSmaller => 'Decrease Brush Size';

  @override
  String get editor_shortcutBrushLarger => 'Increase Brush Size';

  @override
  String get editor_shortcutOpacityLower => 'Decrease Opacity';

  @override
  String get editor_shortcutOpacityHigher => 'Increase Opacity';

  @override
  String get editor_shortcutDragBrushSize => 'Adjust Brush Size';

  @override
  String get editor_shortcutSwapColors => 'Swap Foreground/Background Colors';

  @override
  String get editor_shortcutPanCanvas => 'Pan Canvas';

  @override
  String get editor_shortcutClearSelectionContent => 'Clear Selection Content';

  @override
  String get editor_shortcutCancelCurrentAction => 'Cancel Current Action';

  @override
  String get editor_selectUnlockedLayerWithContent =>
      'Select an unlocked layer with content';

  @override
  String get editor_readCurrentLayerFailed =>
      'Failed to read the current layer';

  @override
  String get editor_localEffects => 'Local Post-processing / Effects';

  @override
  String get editor_basicAdjustments => 'Basic Adjustments';

  @override
  String get editor_styleAndRepair => 'Style & Repair';

  @override
  String get editor_transformCrop => 'Rotate / Flip / Crop';

  @override
  String get editor_transformCropDescription =>
      'Geometry operations are separate. They generate a preview first and write back only after confirmation.';

  @override
  String get editor_effectPreviewHint =>
      'Preview does not modify the original image. Click Apply to write the result to the active layer and undo history.';

  @override
  String get editor_applyToCurrentLayer => 'Apply to Current Layer';

  @override
  String editor_oneShotEffectHint(Object effect) {
    return '$effect is a one-shot operation and has no intensity slider.';
  }

  @override
  String editor_effectIntensity(Object effect) {
    return '$effect Intensity';
  }

  @override
  String get editor_original => 'Original';

  @override
  String get editor_effectPreview => 'Effect Preview';

  @override
  String get editor_effectBrightness => 'Brightness';

  @override
  String get editor_effectContrast => 'Contrast';

  @override
  String get editor_effectSaturation => 'Saturation';

  @override
  String get editor_effectTemperature => 'Temperature';

  @override
  String get editor_effectGamma => 'Gamma';

  @override
  String get editor_effectGrayscale => 'Grayscale';

  @override
  String get editor_effectInvert => 'Invert';

  @override
  String get editor_effectSepia => 'Sepia';

  @override
  String get editor_effectDenoise => 'Denoise';

  @override
  String get editor_effectBlur => 'Gaussian Blur';

  @override
  String get editor_effectSharpen => 'Sharpen';

  @override
  String get editor_effectCropToSelection => 'Crop to Selection';

  @override
  String get editor_effectRotateLeft => 'Rotate Left 90°';

  @override
  String get editor_effectRotateRight => 'Rotate Right 90°';

  @override
  String get editor_effectFlipHorizontal => 'Flip Horizontal';

  @override
  String get editor_effectFlipVertical => 'Flip Vertical';

  @override
  String editor_effectApplied(Object effect) {
    return 'Applied $effect';
  }

  @override
  String editor_applyEffectFailed(Object error) {
    return 'Failed to apply effect: $error';
  }

  @override
  String get editor_changeCanvasSize => 'Change Canvas Size';

  @override
  String editor_canvasTooSmall(Object width, Object height) {
    return 'Canvas size is too small. Minimum size is $width x $height pixels';
  }

  @override
  String editor_canvasTooLarge(Object width, Object height) {
    return 'Canvas size is too large. Maximum size is $width x $height pixels';
  }

  @override
  String editor_canvasResized(Object width, Object height) {
    return 'Canvas resized to $width x $height';
  }

  @override
  String editor_canvasResizeFailed(Object error) {
    return 'Failed to resize canvas: $error';
  }

  @override
  String get editor_confirmExitTitle => 'Confirm Exit';

  @override
  String get editor_confirmExitContent =>
      'There are unsaved changes. Are you sure you want to exit?';

  @override
  String get editor_exit => 'Exit';

  @override
  String get editor_saveAndExit => 'Save and Exit';

  @override
  String editor_exportFailed(Object error) {
    return 'Export failed: $error';
  }

  @override
  String get editor_clickInsideClosedRegion =>
      'Click inside a closed region to fill it.';

  @override
  String get editor_drawClosedMaskOutlineFirst =>
      'Draw a closed mask outline first.';

  @override
  String get editor_noClosedRegionAtPosition =>
      'No fillable closed region at this position.';

  @override
  String get editor_generateMaskOverlayFailed =>
      'Failed to generate mask overlay';

  @override
  String get editor_maskLayerName => 'Mask';

  @override
  String get editor_updateMaskLayerFailed => 'Failed to update mask layer';

  @override
  String get editor_closedRegionFilled => 'Closed region filled as mask.';

  @override
  String editor_fillMaskFailed(Object error) {
    return 'Failed to fill mask: $error';
  }

  @override
  String get editor_magicWandNoSource =>
      'No editable image layer is available for sampling.';

  @override
  String get editor_magicWandNothingChanged =>
      'The selected region is already transparent or masked.';

  @override
  String get editor_magicWandModelPreparing =>
      'Checking the EfficientViT-SAM model…';

  @override
  String editor_magicWandModelDownloading(int percent) {
    return 'Downloading the EfficientViT-SAM model: $percent%';
  }

  @override
  String get editor_magicWandModelLoading =>
      'Loading the EfficientViT-SAM model…';

  @override
  String get editor_magicWandEncoding => 'Analyzing image objects…';

  @override
  String get editor_magicWandSegmenting =>
      'Segmenting the object at the clicked point…';

  @override
  String get editor_magicWandPostprocessing => 'Building the selection…';

  @override
  String editor_magicWandFailed(Object error) {
    return 'Magic Wand failed: $error';
  }

  @override
  String get editor_focusInactiveHint =>
      'Click the button to enter focus mode, then draw a focus area and paint the mask.';

  @override
  String get editor_focusReadyHint =>
      'Focus area selected. You can continue editing the mask with the brush.';

  @override
  String get editor_focusNeedsSelectionHint =>
      'Draw a focus area first, then switch to the brush and paint the mask.';

  @override
  String get editor_focusSelection => 'Selection';

  @override
  String get editor_focusBrush => 'Brush';

  @override
  String get editor_focusContextHint =>
      'The outer rectangle is the area sent to Focused Inpaint. The inner rectangle is the main repaint area. The band between them is the Minimum Context Area.';

  @override
  String get editor_compressionTitle => 'Output resolution';

  @override
  String get editor_compressionTooltip => 'Choose output resolution';

  @override
  String get editor_compressionUncompressed =>
      'Original work resolution; no compression will be applied.';

  @override
  String get editor_compressionApplyOnDone =>
      'Pica Lanczos3 compression runs once when you press Done. The work canvas stays unchanged.';

  @override
  String editor_compressionSizeSummary(
    int workWidth,
    int workHeight,
    int targetWidth,
    int targetHeight,
  ) {
    return 'Work $workWidth×$workHeight → output $targetWidth×$targetHeight';
  }

  @override
  String editor_compressionNormalSummary(
    int normalWidth,
    int normalHeight,
    int minimumWidth,
    int minimumHeight,
  ) {
    return 'Normal (about 1 MP): $normalWidth×$normalHeight. Lowest: $minimumWidth×$minimumHeight.';
  }

  @override
  String get editor_compressionUnavailable =>
      'This work canvas is already below the lowest compression step.';

  @override
  String get editor_compressionFocusLimited =>
      'Higher resolutions are unavailable because the current Focused Inpaint selection would exceed the request area limit.';

  @override
  String editor_focusRequestSummary(
    int outerWidth,
    int outerHeight,
    int requestWidth,
    int requestHeight,
    int cost,
  ) {
    return 'Outer crop $outerWidth×$outerHeight, request $requestWidth×$requestHeight, estimated $cost Anlas.';
  }

  @override
  String editor_unsupportedImageFormat(Object extension) {
    return 'Unsupported file format: .$extension\nPlease choose an image file (PNG, JPG, WEBP, etc.)';
  }

  @override
  String editor_readFileFailed(Object error) {
    return 'Failed to read file: $error';
  }

  @override
  String get editor_noFileData => 'Failed to get file data';

  @override
  String get editor_emptyImageFile =>
      'File is empty. Choose a valid image file';

  @override
  String editor_fileTooLarge(Object sizeMB) {
    return 'File is too large ($sizeMB MB). Choose an image under 50 MB';
  }

  @override
  String get editor_maskLayerAdded => 'Mask layer added';

  @override
  String get editor_parseImageFailed =>
      'Failed to parse image file\nMake sure the file is not corrupted and the format is supported';

  @override
  String editor_loadMaskFailed(Object error) {
    return 'Failed to load mask: $error';
  }

  @override
  String get editor_defaultTitle => 'Canvas';

  @override
  String get editor_baseLayerName => 'Base Image';

  @override
  String get editor_existingMaskLayerName => 'Existing Mask';

  @override
  String get editor_defaultDrawingLayerName => 'Layer 1';

  @override
  String editor_layerName(Object count) {
    return 'Layer $count';
  }

  @override
  String editor_statusZoom(Object value) {
    return 'Zoom: $value%';
  }

  @override
  String editor_statusCanvas(Object width, Object height) {
    return 'Canvas: $width x $height';
  }

  @override
  String editor_statusLayers(Object count) {
    return 'Layers: $count';
  }

  @override
  String get editor_statusHasSelection => 'Selection active';

  @override
  String editor_statusRotation(Object degrees) {
    return 'Rotation: $degrees°';
  }

  @override
  String get editor_statusMirrored => 'Mirrored';

  @override
  String editor_focusMinimumContextArea(Object value) {
    return 'Minimum Context Area: $value';
  }

  @override
  String get editor_canvasSizeTitle => 'Canvas Size';

  @override
  String get editor_presetSize => 'Preset Size';

  @override
  String get editor_customSize => 'Custom';

  @override
  String get editor_contentHandling => 'Content Handling';

  @override
  String get editor_contentCrop => 'Crop';

  @override
  String get editor_contentPad => 'Pad';

  @override
  String get editor_contentStretch => 'Stretch';

  @override
  String get editor_width => 'Width';

  @override
  String get editor_height => 'Height';

  @override
  String get editor_lockAspectRatio => 'Lock aspect ratio';

  @override
  String get editor_unlockAspectRatio => 'Unlock aspect ratio';

  @override
  String get editor_sizePreview => 'Size Preview';

  @override
  String get editor_originalSize => 'Original';

  @override
  String get editor_newSize => 'New Size';

  @override
  String get editor_cropModeDescription =>
      'Crop mode - keep aspect ratio and crop';

  @override
  String get editor_padModeDescription =>
      'Pad mode - keep aspect ratio and pad';

  @override
  String get editor_stretchModeDescription => 'Stretch mode - stretch to fill';

  @override
  String editor_canvasPresetSquare(Object size) {
    return 'Square $size';
  }

  @override
  String editor_canvasPresetLandscape(Object ratio) {
    return 'Landscape $ratio';
  }

  @override
  String editor_canvasPresetPortrait(Object ratio) {
    return 'Portrait $ratio';
  }

  @override
  String get editor_canvasPresetNaiPortrait => 'NAI Portrait';

  @override
  String get editor_canvasPresetNaiLandscape => 'NAI Landscape';

  @override
  String get editor_canvasPresetFullHd => 'Full HD 16:9';

  @override
  String get editor_colorPanelTitle => 'Color';

  @override
  String get editor_colorPickerTitle => 'Choose Color';

  @override
  String get editor_brushSettings => 'Brush Settings';

  @override
  String get editor_eraserSettings => 'Eraser Settings';

  @override
  String get editor_colorPickerHint =>
      'Click anywhere on the canvas to pick a color. Release to switch back to the previous tool.';

  @override
  String get editor_sample => 'Sample';

  @override
  String get editor_samplePoint => 'Point';

  @override
  String get editor_sampleArea => 'Area';

  @override
  String get editor_source => 'Source';

  @override
  String get editor_sourceCurrentLayer => 'Current Layer';

  @override
  String get editor_sourceAllLayers => 'All Layers';

  @override
  String get editor_lassoSelectionHelp =>
      'Hold and drag to draw a freeform selection. Release to close it automatically.';

  @override
  String get layer_empty => 'No layers';

  @override
  String get layer_add => 'Add Layer';

  @override
  String get layer_mergeDown => 'Merge Down';

  @override
  String get layer_duplicate => 'Duplicate';

  @override
  String get layer_delete => 'Delete';

  @override
  String get layer_merge => 'Merge Down';

  @override
  String get layer_visibility => 'Toggle Visibility';

  @override
  String get layer_lock => 'Toggle Lock';

  @override
  String get layer_rename => 'Rename';

  @override
  String get layer_moveUp => 'Move Up';

  @override
  String get layer_moveDown => 'Move Down';

  @override
  String get vibe_title => 'Vibe Transfer';

  @override
  String get vibe_description => 'Change the image, keep the vision.';

  @override
  String get vibe_addFromFileTitle => 'Add from File';

  @override
  String get vibe_addFromFileSubtitle => 'PNG, JPG, Vibe files';

  @override
  String get vibe_addFromLibraryTitle => 'Import from Library';

  @override
  String get vibe_addFromLibrarySubtitle => 'Select from Vibe Library';

  @override
  String get vibe_addReference => 'Add Reference';

  @override
  String get vibe_clearAll => 'Clear All';

  @override
  String vibe_cleared(int count) {
    return 'Cleared $count vibes';
  }

  @override
  String get vibe_referenceStrength => 'Ref Strength';

  @override
  String get vibe_infoExtraction => 'Information Extracted';

  @override
  String get vibe_remove => 'Remove';

  @override
  String get reference_enabled => 'Enabled';

  @override
  String get reference_enable => 'Enable reference';

  @override
  String get reference_disable => 'Disable reference';

  @override
  String get vibe_normalize => 'Normalize Reference Strength Values';

  @override
  String get vibe_sourceType_png => 'PNG';

  @override
  String get vibe_sourceType_v4vibe => 'Vibe file';

  @override
  String get vibe_sourceType_bundle => 'Bundle';

  @override
  String get vibe_sourceType_image => 'Image';

  @override
  String get vibe_sourceType => 'Source';

  @override
  String get vibe_reuseButton => 'Reuse';

  @override
  String get vibe_info => 'Vibe Info';

  @override
  String get vibe_name => 'Name';

  @override
  String get vibe_strength => 'Strength';

  @override
  String get vibe_infoExtracted => 'Information Extracted';

  @override
  String get vibe_shiftReplaceHint => 'Shift+Click to Replace';

  @override
  String get character_buttonLabel => 'Characters';

  @override
  String get character_addCharacter => 'Add Character';

  @override
  String character_limitReached(Object limit) {
    return 'Character limit for this model reached ($limit)';
  }

  @override
  String character_number(Object index) {
    return 'Character $index';
  }

  @override
  String get character_summaryEmpty => 'No characters added';

  @override
  String character_summaryEnabled(int count, String name) {
    return '$count enabled · $name';
  }

  @override
  String character_summaryMore(int count, String name, int additional) {
    return '$count enabled · $name +$additional';
  }

  @override
  String character_summaryAllDisabled(int count) {
    return '0 enabled · $count disabled';
  }

  @override
  String get gallery_generationParams => 'Generation Parameters';

  @override
  String get gallery_metaModel => 'Model';

  @override
  String get gallery_metaResolution => 'Resolution';

  @override
  String get gallery_metaSteps => 'Steps';

  @override
  String get gallery_metaSampler => 'Sampler';

  @override
  String get gallery_metaCfgScale => 'CFG Scale';

  @override
  String get gallery_metaSeed => 'Seed';

  @override
  String get gallery_metaSmea => 'SMEA';

  @override
  String get gallery_promptCopied => 'Prompt copied';

  @override
  String get gallery_seedCopied => 'Seed copied';

  @override
  String get gallery_sendToKritaAction => 'Send to Krita';

  @override
  String get gallery_upscalePanelLoaded =>
      'Loaded the Image2Image Upscale panel';

  @override
  String gallery_readImageFailed(Object error) {
    return 'Failed to read image: $error';
  }

  @override
  String get gallery_fileMissing => 'File does not exist';

  @override
  String get gallery_copiedToClipboard => 'Copied to clipboard';

  @override
  String gallery_copyFailed(Object error) {
    return 'Copy failed: $error';
  }

  @override
  String get gallery_upscale => 'Upscale';

  @override
  String get gallery_sentToImg2Img => 'Image sent to Image2Image';

  @override
  String get gallery_sentToReversePrompt =>
      'Image sent to reverse-prompt module';

  @override
  String gallery_sendFailed(Object error) {
    return 'Send failed: $error';
  }

  @override
  String get preset_presetName => 'Preset Name';

  @override
  String get onlineGallery_search => 'Search';

  @override
  String get onlineGallery_popular => 'Popular';

  @override
  String get onlineGallery_sourceDoesNotSupportPopular =>
      'The current source does not provide popular rankings';

  @override
  String get onlineGallery_favorites => 'Favorites';

  @override
  String get onlineGallery_searchFavorites =>
      'Search favorites by title, author, or tag…';

  @override
  String get onlineGallery_savedLocally => 'Saved locally';

  @override
  String get onlineGallery_savedInCloud => 'Saved in cloud';

  @override
  String get onlineGallery_saveVisibleLocally => 'Save page locally';

  @override
  String get onlineGallery_visibleFavoritesAlreadySaved =>
      'Everything on this page is already saved locally';

  @override
  String get onlineGallery_localFavoritesPartialFailure =>
      'Local favorites failed to load; cloud results are still available';

  @override
  String get onlineGallery_cloudFavoritesPartialFailure =>
      'Cloud favorites failed to load; local results are still available';

  @override
  String onlineGallery_visibleFavoritesSaved(int count) {
    return 'Saved $count items to local favorites';
  }

  @override
  String onlineGallery_saveFavoritesFailed(String error) {
    return 'Failed to save local favorites: $error';
  }

  @override
  String get onlineGallery_searchTags => 'Search tags...';

  @override
  String get onlineGallery_refresh => 'Refresh';

  @override
  String get onlineGallery_random => 'Random';

  @override
  String get onlineGallery_randomRedraw => 'Draw again';

  @override
  String get onlineGallery_randomDrawing => 'Drawing…';

  @override
  String get onlineGallery_randomExhausted =>
      'No more unseen images in this range';

  @override
  String get onlineGallery_randomRestart => 'Start over';

  @override
  String get onlineGallery_login => 'Login';

  @override
  String get onlineGallery_logout => 'Logout';

  @override
  String get onlineGallery_dayRank => 'Day';

  @override
  String get onlineGallery_weekRank => 'Week';

  @override
  String get onlineGallery_monthRank => 'Month';

  @override
  String get onlineGallery_today => 'Today';

  @override
  String onlineGallery_imageCount(Object count) {
    return '$count images';
  }

  @override
  String get onlineGallery_loadFailed => 'Load failed';

  @override
  String get onlineGallery_favoritesEmpty => 'Favorites is empty';

  @override
  String get onlineGallery_noResults => 'No images found';

  @override
  String get onlineGallery_pleaseLogin => 'Please login first';

  @override
  String get onlineGallery_score => 'Score';

  @override
  String get onlineGallery_ratingLabel => 'Rating';

  @override
  String get onlineGallery_favCount => 'Favorites';

  @override
  String get mediaType_video => 'Video';

  @override
  String get mediaType_gif => 'GIF';

  @override
  String get onlineGallery_tags => 'Tags';

  @override
  String get onlineGallery_artists => 'Artists';

  @override
  String get onlineGallery_characters => 'Characters';

  @override
  String get onlineGallery_copyrights => 'Copyrights';

  @override
  String get onlineGallery_general => 'General';

  @override
  String get onlineGallery_copied => 'Copied';

  @override
  String get onlineGallery_copyTags => 'Copy Tags';

  @override
  String get onlineGallery_promptTagCategories => 'Prompt tag categories';

  @override
  String get onlineGallery_promptTagCategoriesTooltip =>
      'Choose which tag categories are included when copying, sending, or adding to the queue';

  @override
  String get onlineGallery_keepOnePromptTagCategory =>
      'Keep at least one prompt tag category selected';

  @override
  String get onlineGallery_addToQueue => 'Add to Queue';

  @override
  String get onlineGallery_sendToTextToImage => 'Send to Text to Image';

  @override
  String get onlineGallery_sentToTextToImage => 'Sent to text-to-image';

  @override
  String get onlineGallery_sendToReversePrompt => 'Send to Reverse Prompt';

  @override
  String get onlineGallery_sentToReversePrompt =>
      'Sent to reverse-prompt module';

  @override
  String onlineGallery_reversePromptSendFailed(Object error) {
    return 'Failed to send to reverse prompt: $error';
  }

  @override
  String get onlineGallery_noTagInfo => 'This image has no tag information';

  @override
  String get onlineGallery_noImageUrl => 'This image has no available URL';

  @override
  String get onlineGallery_pinchToZoom => 'Pinch to zoom';

  @override
  String get onlineGallery_metadata => 'Metadata';

  @override
  String onlineGallery_addedToQueueWithCount(Object count) {
    return 'Added to queue. $count tasks are now pending';
  }

  @override
  String get onlineGallery_queueFullMax => 'Queue is full (maximum 50 items)';

  @override
  String get onlineGallery_chooseDownloadDirectory =>
      'Choose Download Directory';

  @override
  String get onlineGallery_downloadStarted => 'Download started...';

  @override
  String onlineGallery_savedToPath(Object path) {
    return 'Saved to: $path';
  }

  @override
  String onlineGallery_downloadFailed(Object error) {
    return 'Download failed: $error';
  }

  @override
  String get onlineGallery_downloadOriginal => 'Download original image';

  @override
  String get onlineGallery_all => 'All';

  @override
  String get onlineGallery_ratingGeneral => 'General';

  @override
  String get onlineGallery_ratingSensitive => 'Sensitive';

  @override
  String get onlineGallery_ratingQuestionable => 'Questionable';

  @override
  String get onlineGallery_ratingExplicit => 'Explicit';

  @override
  String get onlineGallery_sourceGeneralOnly =>
      'This source only provides general content';

  @override
  String get onlineGallery_sourceUnrated => 'Source unrated';

  @override
  String get onlineGallery_sourceUnratedTooltip =>
      'This source does not provide a reliable content rating, so the app cannot infer one accurately';

  @override
  String get onlineGallery_clear => 'Clear';

  @override
  String get onlineGallery_previousPage => 'Previous Page';

  @override
  String get onlineGallery_nextPage => 'Next Page';

  @override
  String onlineGallery_pageN(Object page) {
    return 'Page $page';
  }

  @override
  String get onlineGallery_dateRange => 'Date Range';

  @override
  String get onlineGallery_fuzzySearch => 'Fuzzy Match';

  @override
  String get onlineGallery_fuzzySearchTooltip =>
      'Use *tag* matching for related tags when enabled; search exact Danbooru tags when disabled';

  @override
  String get onlineGallery_blacklistShort => 'Block';

  @override
  String get onlineGallery_blacklistTags => 'Blacklist Tags';

  @override
  String get onlineGallery_outputFilter => 'Output Filter';

  @override
  String get onlineGallery_outputFilterShort => 'Output';

  @override
  String get onlineGallery_outputFilterTooltip =>
      'Manage tags removed automatically when copying, sending, or adding to the queue';

  @override
  String get onlineGallery_outputFilterTitle => 'Output filter tags';

  @override
  String get onlineGallery_outputFilterSubtitle =>
      'Images remain visible. Exact matching tags are removed only from copied, sent, and queued prompts.';

  @override
  String get onlineGallery_outputFilterAddHint =>
      'Add a tag to remove from output';

  @override
  String get onlineGallery_outputFilterInputHint =>
      'Separate multiple tags with commas or line breaks';

  @override
  String get onlineGallery_outputFilterEmpty =>
      'No output filter tags configured';

  @override
  String get onlineGallery_outputFilterRestoreDefaults => 'Restore defaults';

  @override
  String get onlineGallery_outputFilterClearTitle => 'Clear the output filter?';

  @override
  String get onlineGallery_outputFilterClearConfirm =>
      'Watermark and mosaic tags will appear in copied and sent prompts again.';

  @override
  String get onlineGallery_addTagToOutputFilter => 'Add to output filter';

  @override
  String get onlineGallery_outputFilterAlreadyAdded =>
      'Already in output filter';

  @override
  String get onlineGallery_outputFilterMenuHint =>
      'Keep the image visible and remove only this output tag';

  @override
  String get onlineGallery_addTagToBlacklist => 'Add to blacklist';

  @override
  String get onlineGallery_blacklistAlreadyAdded => 'Already in blacklist';

  @override
  String get onlineGallery_blacklistMenuHint =>
      'Hide gallery images containing this tag';

  @override
  String get onlineGallery_outputFilteredTagTooltip =>
      'Removed when copying, sending, or adding to queue; right-click to manage';

  @override
  String get onlineGallery_tagContextMenuTooltip =>
      'Right-click to add to the blacklist or output filter';

  @override
  String onlineGallery_outputFilterTagAdded(Object tag) {
    return 'Added $tag to the output filter';
  }

  @override
  String onlineGallery_blacklistTagAdded(Object tag) {
    return 'Added $tag to the blacklist';
  }

  @override
  String get onlineGallery_blacklistTitle => 'Online Gallery Blacklist';

  @override
  String get onlineGallery_blacklistSubtitle =>
      'One list is shared by every online gallery and keeps filtering while offline.';

  @override
  String get onlineGallery_blacklistCloudDescription =>
      'Danbooru is connected; local changes sync after a safe merge';

  @override
  String get onlineGallery_blacklistCloudLoginRequired =>
      'The local blacklist still works; sign in to Danbooru to sync';

  @override
  String get onlineGallery_blacklistCloudUnavailable =>
      'The local blacklist is active. Cloud sync will resume after Danbooru can be verified.';

  @override
  String get onlineGallery_addBlacklistTagHint => 'Add blacklist tag';

  @override
  String get onlineGallery_noLocalBlacklistTags => 'No blacklist tags';

  @override
  String get onlineGallery_pullBlacklist => 'Pull cloud';

  @override
  String get onlineGallery_pushBlacklist => 'Push to cloud';

  @override
  String get onlineGallery_pushBlacklistConfirmTitle =>
      'Replace cloud with the unified list?';

  @override
  String get onlineGallery_pushBlacklistConfirmBody =>
      'This completely replaces the Danbooru cloud blacklist. Routine syncing preserves unrecognized advanced rules, but this full push removes them.';

  @override
  String get onlineGallery_blacklistPushSucceeded =>
      'Cloud blacklist replaced with local list';

  @override
  String get onlineGallery_blacklistSyncFailedMessage =>
      'Blacklist sync failed. Check your sign-in and network connection.';

  @override
  String onlineGallery_blacklistSaveFailed(String error) {
    return 'Failed to save blacklist: $error';
  }

  @override
  String get onlineGallery_autoSyncOnStartup => 'Refresh cloud list on startup';

  @override
  String get onlineGallery_autoSyncOnStartupSubtitle =>
      'Safely merges new cloud tags without deleting local tags';

  @override
  String onlineGallery_lastSyncFailed(Object error) {
    return 'Last sync failed: $error';
  }

  @override
  String get onlineGallery_neverSyncedBlacklist =>
      'Danbooru blacklist has not been synced yet';

  @override
  String onlineGallery_lastSync(Object time) {
    return 'Last sync: $time';
  }

  @override
  String get onlineGallery_blacklistSettingsTitle =>
      'Online Gallery Blacklist Settings';

  @override
  String get onlineGallery_blacklistImportTitle => 'Import tags';

  @override
  String get onlineGallery_blacklistImportHint =>
      'Enter one tag per line or separate tags with commas';

  @override
  String onlineGallery_blacklistImported(Object count) {
    return 'Added $count tags';
  }

  @override
  String get onlineGallery_blacklistClearTitle =>
      'Clear the unified blacklist?';

  @override
  String get onlineGallery_blacklistClearBody =>
      'The gallery will immediately stop filtering by these tags. The cloud list will not be cleared automatically, and this action can be undone.';

  @override
  String onlineGallery_blacklistPullSummary(
    Object added,
    Object existing,
    Object skipped,
    Object opaque,
  ) {
    return 'Added $added, already had $existing, skipped $skipped deleted tags; preserved $opaque advanced cloud rules';
  }

  @override
  String onlineGallery_blacklistPushDiff(
    Object added,
    Object removed,
    Object opaque,
  ) {
    return 'Cloud will add $added, remove $removed, and delete $opaque advanced rules.';
  }

  @override
  String get onlineGallery_blacklistCloudEmptyConfirm =>
      'Confirm clearing the cloud blacklist';

  @override
  String get onlineGallery_blacklistMigrationConfirm =>
      'This list includes cloud tags migrated from an unknown account. Confirm syncing them to the current account';

  @override
  String get onlineGallery_bulkFavorite => 'Favorite Selected';

  @override
  String get onlineGallery_bulkDownload => 'Download Selected';

  @override
  String onlineGallery_addedTasksToQueue(Object count) {
    return 'Added $count tasks to queue';
  }

  @override
  String onlineGallery_queueBatchCompleted(
    Object added,
    Object prepareFailed,
    Object queueSkipped,
  ) {
    return 'Added $added; $prepareFailed could not be prepared; $queueSkipped were skipped because the queue is full';
  }

  @override
  String get onlineGallery_unfavorited => 'Unfavorited';

  @override
  String get onlineGallery_favorited => 'Favorited';

  @override
  String onlineGallery_favoritedImages(Object count) {
    return 'Favorited $count images';
  }

  @override
  String onlineGallery_selectDownloadDirectoryFailed(Object error) {
    return 'Failed to choose download directory: $error';
  }

  @override
  String onlineGallery_downloadSelectedStarted(Object count) {
    return 'Downloading $count images...';
  }

  @override
  String onlineGallery_downloadSelectedCompletedWithSkipped(
    Object success,
    Object failed,
    Object skipped,
  ) {
    return 'Download complete: $success succeeded, $failed failed, $skipped text-only items skipped';
  }

  @override
  String get onlineGallery_startDate => 'Start Date';

  @override
  String get onlineGallery_endDate => 'End Date';

  @override
  String get onlineGallery_invalidDateFormat => 'Invalid date format';

  @override
  String get onlineGallery_dateOutOfRange => 'Date out of range';

  @override
  String get onlineGallery_last30Days => 'Last 30 Days';

  @override
  String get onlineGallery_configureGelbooruApi => 'Configure Gelbooru API';

  @override
  String get onlineGallery_gelbooruApiReady => 'Gelbooru API verified';

  @override
  String get onlineGallery_gelbooruApiInvalid => 'Gelbooru credentials expired';

  @override
  String get onlineGallery_gelbooruCredentialsRequired =>
      'Configure your Gelbooru User ID and API Key to view website favorites.';

  @override
  String get onlineGallery_gelbooruCredentialsInvalid =>
      'Your Gelbooru credentials are no longer valid. Configure them again.';

  @override
  String get onlineGallery_gelbooruRateLimited =>
      'Gelbooru is rate limiting requests. Try again later.';

  @override
  String get onlineGallery_gelbooruTimeout =>
      'The Gelbooru request timed out. Check your network connection.';

  @override
  String get onlineGallery_gelbooruServerError =>
      'Gelbooru is temporarily unavailable. Try again later.';

  @override
  String get onlineGallery_gelbooruNetworkError =>
      'Could not connect to Gelbooru. Check your network or proxy settings.';

  @override
  String get onlineGallery_gelbooruMalformedResponse =>
      'Gelbooru returned data that could not be parsed.';

  @override
  String get onlineGallery_gelbooruRequestFailed =>
      'The Gelbooru request failed. Try again later.';

  @override
  String get onlineGallery_aiTagQuery =>
      'Search works, artists, titles, tags, or models';

  @override
  String get onlineGallery_aiTagPromptQuery =>
      'AI Prompt search (search raw Prompt text such as artist:)';

  @override
  String get onlineGallery_sourceQuickTagCloud => 'Codex Gallery';

  @override
  String get onlineGallery_codexSearchHint =>
      'Search titles, prompts, notes, categories, or contributors';

  @override
  String get onlineGallery_codexLabel => 'Codex';

  @override
  String get onlineGallery_codexSelect => 'Select codex';

  @override
  String get onlineGallery_codexAll => 'All codexes';

  @override
  String get onlineGallery_codexBrowse => 'Browse';

  @override
  String get onlineGallery_codexLatest => 'Latest update';

  @override
  String get onlineGallery_codexRecent => 'Recently viewed';

  @override
  String get onlineGallery_codexCategory => 'Category';

  @override
  String get onlineGallery_codexAllCategories => 'All categories';

  @override
  String get onlineGallery_codexUpdateBatch => 'Update batch';

  @override
  String get onlineGallery_codexMediaFilter => 'Images';

  @override
  String get onlineGallery_codexAllEntries => 'All entries';

  @override
  String get onlineGallery_codexWithImages => 'With images';

  @override
  String get onlineGallery_codexWithoutImages => 'Without images';

  @override
  String get onlineGallery_codexOffline => 'Offline cache';

  @override
  String get onlineGallery_codexContributors => 'Contributors and source';

  @override
  String onlineGallery_codexEntryCount(Object entries, Object images) {
    return '$entries entries · $images with images';
  }

  @override
  String get onlineGallery_codexNoImage => 'Entry without images';

  @override
  String get onlineGallery_codexNoImageDescription =>
      'This is a text-only entry. Its prompts and metadata remain fully available.';

  @override
  String get onlineGallery_codexAuthor => 'Author';

  @override
  String get onlineGallery_codexImageFile => 'Image file';

  @override
  String get onlineGallery_codexOriginalFile => 'Original file';

  @override
  String get onlineGallery_codexDeclaredSource => 'Data source';

  @override
  String get onlineGallery_codexPrompt => 'Positive prompt';

  @override
  String get onlineGallery_codexNegativePrompt => 'Negative prompt';

  @override
  String get onlineGallery_negativePromptCopyHeading => 'Negative Prompt';

  @override
  String get onlineGallery_codexCharacterPrompts => 'Character prompts';

  @override
  String get onlineGallery_codexNote => 'Notes';

  @override
  String get onlineGallery_codexCopyPositive => 'Copy positive';

  @override
  String get onlineGallery_codexCopyNegative => 'Copy negative';

  @override
  String get onlineGallery_codexCopyCharacter => 'Copy this character';

  @override
  String get onlineGallery_codexCopyAll => 'Copy all';

  @override
  String get onlineGallery_codexSendToGeneration => 'Send to Generate';

  @override
  String get onlineGallery_codexAddToQueue => 'Add to generation queue';

  @override
  String get onlineGallery_codexDownloadOriginal => 'Download current original';

  @override
  String get onlineGallery_codexOpenSource => 'Open source';

  @override
  String get onlineGallery_codexOpenOrigin => 'Open original page';

  @override
  String get onlineGallery_codexOpenSourceFailed =>
      'Could not open the declared source.';

  @override
  String get onlineGallery_codexBookLocked =>
      'This codex contains adult content. Select Questionable or Explicit in the rating filter to view it.';

  @override
  String get onlineGallery_codexNoData =>
      'No codex entries match these filters';

  @override
  String get onlineGallery_codexExternalFallback =>
      'The external source is unavailable. Showing the codex site\'s cached version.';

  @override
  String get onlineGallery_codexPreviousRelease =>
      'The current version is unavailable. Showing the previous verified release.';

  @override
  String get onlineGallery_codexCachedBadge => 'cached release';

  @override
  String get onlineGallery_codexUntitled => 'Untitled entry';

  @override
  String get onlineGallery_artistHunt => 'Artist chains only';

  @override
  String get onlineGallery_artistHuntTooltip =>
      'Show only images whose positive Prompt contains explicit artist: tags';

  @override
  String get onlineGallery_copyArtistChain => 'Copy artist chain';

  @override
  String get onlineGallery_copyFullPrompt => 'Copy full Prompt';

  @override
  String get onlineGallery_copyRawArtistFragments =>
      'Copy original artist fragments';

  @override
  String get onlineGallery_noArtistChain => 'No artist chain';

  @override
  String onlineGallery_artistCount(Object count) {
    return '$count artists';
  }

  @override
  String get onlineGallery_artistHuntNoExactResults =>
      'No exact artist chains were found in the candidate works';

  @override
  String onlineGallery_artistHuntPartialFailure(Object count) {
    return '$count works could not be parsed. Retry to check them again.';
  }

  @override
  String get onlineGallery_artistHuntDetailFailed =>
      'None of the candidate work details could be parsed. Please retry.';

  @override
  String get onlineGallery_aiTagTimeRange => 'Time range';

  @override
  String get onlineGallery_aiTagAllTime => 'All';

  @override
  String get onlineGallery_aiTagCurrentMonthly => 'Live monthly ranking';

  @override
  String get onlineGallery_aiTagOlderMonthly => 'Older archive';

  @override
  String get onlineGallery_aiTagRankingProcessing =>
      'The ranking is being generated. Please try again shortly.';

  @override
  String get onlineGallery_sourceConfigUnavailable =>
      'Could not load source configuration. Check your connection and retry.';

  @override
  String get onlineGallery_sourceRateLimited =>
      'Too many requests. Please try again later.';

  @override
  String get onlineGallery_sourceTimeout =>
      'The request timed out. Check your connection.';

  @override
  String get onlineGallery_sourceNetworkError =>
      'Could not connect to this gallery source. Check your network or proxy.';

  @override
  String get onlineGallery_sourceRequestFailed =>
      'The request failed. Please try again later.';

  @override
  String onlineGallery_actionFailed(Object error) {
    return 'Action failed: $error';
  }

  @override
  String get onlineGallery_sourceMalformedResponse =>
      'The source response format has changed and cannot be parsed.';

  @override
  String get onlineGallery_detailNotFound =>
      'This work does not exist or has been removed.';

  @override
  String get onlineGallery_imageUnavailable =>
      'This image is currently unavailable.';

  @override
  String get onlineGallery_loadedAll => 'All items loaded';

  @override
  String get onlineGallery_retryAppend => 'Load failed. Click to retry';

  @override
  String onlineGallery_multipleImages(Object count) {
    return '$count images';
  }

  @override
  String get onlineGallery_views => 'Views';

  @override
  String get onlineGallery_downloadAllMedia =>
      'Download all images in this work';

  @override
  String get onlineGallery_copyFullMetadata => 'Copy full metadata';

  @override
  String get onlineGallery_gelbooruReadOnly => 'Read-only favorites';

  @override
  String get onlineGallery_gelbooruFavoritesSortHint =>
      'Sorted by post ID, newest first. This may differ from website favorite-time order.';

  @override
  String get tooltip_fullscreenEdit => 'Fullscreen Edit';

  @override
  String get tooltip_decreaseWeight => 'Decrease Weight [-5%]';

  @override
  String get tooltip_increaseWeight => 'Increase Weight [+5%]';

  @override
  String get tooltip_edit => 'Edit';

  @override
  String get tooltip_copy => 'Copy';

  @override
  String get tooltip_delete => 'Delete';

  @override
  String get tooltip_enable => 'Enable';

  @override
  String get tooltip_disable => 'Disable';

  @override
  String get tooltip_resetWeight => 'Click to reset to 100%';

  @override
  String get upscale_scale => 'Scale Factor';

  @override
  String get danbooru_loginTitle => 'Login Danbooru';

  @override
  String get danbooru_loginHint =>
      'Login with username and API Key to use favorites';

  @override
  String get danbooru_username => 'Username';

  @override
  String get danbooru_usernameHint => 'Enter Danbooru username';

  @override
  String get danbooru_usernameRequired => 'Please enter username';

  @override
  String get danbooru_apiKeyHint => 'Enter API Key';

  @override
  String get danbooru_apiKeyRequired => 'Please enter API Key';

  @override
  String get danbooru_howToGetApiKey => 'How to get API Key?';

  @override
  String get danbooru_loginSuccess => 'Login successful';

  @override
  String get gelbooru_configureTitle => 'Configure Gelbooru API';

  @override
  String get gelbooru_configureHint =>
      'Enter the User ID and API Key shown in your Gelbooru account settings. The app does not collect your password or browser cookies.';

  @override
  String get gelbooru_userId => 'User ID';

  @override
  String get gelbooru_userIdHint => 'Enter a positive numeric User ID';

  @override
  String get gelbooru_userIdRequired =>
      'Enter a valid positive numeric User ID';

  @override
  String get gelbooru_apiKeyHint => 'Enter API Key';

  @override
  String get gelbooru_apiKeyRequired => 'Enter an API Key';

  @override
  String get gelbooru_openAccountSettings => 'Open Gelbooru account settings';

  @override
  String get gelbooru_save => 'Verify and Save';

  @override
  String get gelbooru_saved => 'Gelbooru credentials saved';

  @override
  String get gelbooru_removeCredentials => 'Remove Credentials';

  @override
  String get gelbooru_invalidInput => 'Enter a valid User ID and API Key.';

  @override
  String get gelbooru_invalidCredentials =>
      'Gelbooru rejected these credentials. Check the User ID and API Key.';

  @override
  String get gelbooru_rateLimited => 'Too many requests. Try again later.';

  @override
  String get gelbooru_timeout =>
      'Verification timed out. Check your network connection.';

  @override
  String get gelbooru_serverError => 'Gelbooru is temporarily unavailable.';

  @override
  String get gelbooru_networkError =>
      'Could not connect to Gelbooru. Check your network or proxy settings.';

  @override
  String get gelbooru_malformedResponse =>
      'Gelbooru returned data that could not be parsed.';

  @override
  String get gelbooru_storageError =>
      'Gelbooru credentials could not be stored or read securely.';

  @override
  String get gelbooru_unknownError =>
      'Gelbooru verification failed. Try again later.';

  @override
  String get weight_title => 'Weight';

  @override
  String get weight_reset => 'Reset';

  @override
  String get weight_done => 'Done';

  @override
  String get weight_noBrackets => 'No brackets';

  @override
  String get weight_editTag => 'Edit Tag';

  @override
  String get weight_tagName => 'Tag Name';

  @override
  String get weight_tagNameHint => 'Enter tag name...';

  @override
  String tag_selected(Object count) {
    return 'Selected $count';
  }

  @override
  String get tag_enable => 'Enable';

  @override
  String get tag_disable => 'Disable';

  @override
  String get tag_delete => 'Delete';

  @override
  String get tag_addTag => 'Add Tag';

  @override
  String get tag_add => 'Add';

  @override
  String get tag_inputHint => 'Enter tag...';

  @override
  String get tag_copiedToClipboard => 'Copied to clipboard';

  @override
  String get tag_emptyHint => 'Add tags to describe your desired image';

  @override
  String get tag_emptyHintSub => 'You can browse, search, or add tags manually';

  @override
  String get tagCategory_artist => 'Artist';

  @override
  String get tagCategory_copyright => 'Copyright';

  @override
  String get tagCategory_character => 'Character';

  @override
  String get tagCategory_meta => 'Meta';

  @override
  String get tagCategory_general => 'General';

  @override
  String get qualityTags_label => 'Quality';

  @override
  String get qualityTags_positive => 'Quality (Prompt)';

  @override
  String get qualityTags_negative => 'Quality (Undesired Content)';

  @override
  String get qualityTags_disabled => 'Quality tags disabled\nClick to enable';

  @override
  String get qualityTags_addToEnd => 'Add to prompt end:';

  @override
  String get qualityTags_naiDefault => 'NAI Default';

  @override
  String get qualityTags_naiDefaultStandard => 'NAI Default (Standard)';

  @override
  String get qualityTags_naiDefaultLight => 'NAI Default (Light)';

  @override
  String get qualityTags_none => 'None';

  @override
  String get qualityTags_addFromLibrary => 'Add from Library';

  @override
  String get qualityTags_selectFromLibrary => 'Select Quality Tag Entry';

  @override
  String get ucPreset_label => 'Undesired Content Preset';

  @override
  String get ucPreset_heavy => 'Heavy';

  @override
  String get ucPreset_light => 'Light';

  @override
  String get ucPreset_furryFocus => 'Furry';

  @override
  String get ucPreset_humanFocus => 'Human';

  @override
  String get ucPreset_none => 'None';

  @override
  String get ucPreset_disabled => 'Undesired content preset disabled';

  @override
  String get ucPreset_addToNegative => 'Add to Undesired Content:';

  @override
  String get ucPreset_nsfwHint =>
      '💡 To generate adult content, add nsfw to your prompt. The nsfw tag will be auto-removed from Undesired Content';

  @override
  String get ucPreset_addFromLibrary => 'Add from Library';

  @override
  String get ucPreset_selectFromLibrary => 'Select UC Entry';

  @override
  String get randomMode_enabledTip =>
      'Random mode enabled\nAuto-randomize prompt after each generation';

  @override
  String get randomMode_disabledTip =>
      'Random mode\nClick to auto-randomize prompts on generation';

  @override
  String get batchSize_title => 'Batch Size';

  @override
  String batchSize_tooltip(int count) {
    return '$count images per request';
  }

  @override
  String get batchSize_description => 'Number of images per API request';

  @override
  String batchSize_formula(int batchCount, int batchSize, int total) {
    return 'Total images = $batchCount × $batchSize = $total';
  }

  @override
  String get batchSize_hint =>
      'Larger batch = fewer requests, but longer wait per request';

  @override
  String get batchSize_costWarning => '⚠️ Batch size > 1 costs extra Anlas';

  @override
  String get warmup_networkCheck => 'Checking network connection...';

  @override
  String get warmup_networkCheck_noProxy =>
      'Cannot connect to NovelAI, please enable VPN or proxy settings';

  @override
  String get warmup_networkCheck_noSystemProxy =>
      'Proxy enabled but no system proxy detected, please enable VPN';

  @override
  String get warmup_networkCheck_manualIncomplete =>
      'Manual proxy config incomplete, please check settings';

  @override
  String get warmup_networkCheck_testing => 'Testing network connection...';

  @override
  String get warmup_networkCheck_testingProxy => 'Testing network via proxy...';

  @override
  String warmup_networkCheck_success(Object latency) {
    return 'Network connection OK (${latency}ms)';
  }

  @override
  String get warmup_networkCheck_timeout =>
      'Network check timeout, continuing offline';

  @override
  String warmup_networkCheck_attempt(Object attempt, Object maxAttempts) {
    return 'Checking network... (attempt $attempt/$maxAttempts)';
  }

  @override
  String get warmup_preparing => 'Preparing...';

  @override
  String get warmup_complete => 'Complete';

  @override
  String get warmup_danbooruAuth => 'Initializing Danbooru authentication...';

  @override
  String get warmup_loadingTranslation => 'Loading translation data...';

  @override
  String get warmup_initUnifiedDatabase => 'Initializing tag database...';

  @override
  String get warmup_initTagSystem => 'Initializing tag system...';

  @override
  String get warmup_loadingPromptConfig => 'Loading prompt config...';

  @override
  String get warmup_imageEditor => 'Initializing image editor...';

  @override
  String get warmup_database => 'Loading recent history...';

  @override
  String get warmup_network => 'Checking network connection...';

  @override
  String get warmup_fonts => 'Preloading fonts...';

  @override
  String get warmup_imageCache => 'Warming up image cache...';

  @override
  String get warmup_statistics => 'Loading statistics...';

  @override
  String get warmup_artistsSync => 'Syncing artists data...';

  @override
  String get warmup_subscription => 'Loading subscription info...';

  @override
  String get warmup_dataSourceCache => 'Initializing data source cache...';

  @override
  String get warmup_galleryFileCount => 'Scanning gallery files...';

  @override
  String get warmup_cooccurrenceData => 'Loading tag cooccurrence data...';

  @override
  String get warmup_group_basicUI => 'Initializing basic UI services...';

  @override
  String get warmup_group_basicUI_complete => 'Basic UI services ready';

  @override
  String get warmup_group_dataServices => 'Initializing data services...';

  @override
  String get warmup_group_dataServices_complete => 'Data services ready';

  @override
  String get warmup_group_networkServices => 'Initializing network services...';

  @override
  String get warmup_group_networkServices_complete => 'Network services ready';

  @override
  String get warmup_group_cacheServices => 'Initializing cache services...';

  @override
  String get warmup_group_cacheServices_complete => 'Cache services ready';

  @override
  String get warmup_cooccurrenceInit => 'Initializing cooccurrence data...';

  @override
  String get warmup_translationInit => 'Initializing translation data...';

  @override
  String get warmup_danbooruTagsInit => 'Initializing Danbooru tags...';

  @override
  String get warmup_dataMigration => 'Migrating Hive / Vibe / image data...';

  @override
  String warmup_dataMigrationFailed(Object details) {
    return 'Data migration failed: $details';
  }

  @override
  String get warmup_galleryDataSource => 'Initializing gallery index...';

  @override
  String get warmup_checkAndRecoverData => 'Checking data integrity...';

  @override
  String get warmup_group_dataSourceInitialization =>
      'Initializing data source services...';

  @override
  String get warmup_group_dataSourceInitialization_complete =>
      'Data source services ready';

  @override
  String warmup_fetchingTags(Object message) {
    return 'Syncing tags: $message';
  }

  @override
  String get warmup_fetchingTagDataFromServer =>
      'Fetching tag data from server...';

  @override
  String get warmup_fetchingGeneralTags => 'Fetching general tags...';

  @override
  String get warmup_fetchingCharacterTags => 'Fetching character tags...';

  @override
  String get warmup_fetchingCopyrightTags => 'Fetching copyright tags...';

  @override
  String get warmup_fetchingMetaTags => 'Fetching meta tags...';

  @override
  String get resolution_groupNormal => 'NORMAL';

  @override
  String get resolution_groupLarge => 'LARGE';

  @override
  String get resolution_groupWallpaper => 'WALLPAPER';

  @override
  String get resolution_groupSmall => 'SMALL';

  @override
  String get resolution_groupCustom => 'CUSTOM';

  @override
  String get resolution_typePortrait => 'Portrait';

  @override
  String get resolution_typeLandscape => 'Landscape';

  @override
  String get resolution_typeSquare => 'Square';

  @override
  String get resolution_typeCustom => 'Custom';

  @override
  String get resolution_width => 'Width';

  @override
  String get resolution_height => 'Height';

  @override
  String get generation_invalidResolution => 'Invalid resolution';

  @override
  String generation_invalidResolutionHint(
    int width,
    int height,
    int suggestedWidth,
    int suggestedHeight,
  ) {
    return '$width×$height cannot be used for generation. Both dimensions must be multiples of 64, neither side can exceed 4096, and the total pixel count cannot exceed 3,145,728. The nearest valid size is $suggestedWidth×$suggestedHeight.';
  }

  @override
  String get api_error_429 => 'Concurrency limit reached';

  @override
  String get api_error_429_hint =>
      'Too many requests. Please wait and try again (common with shared accounts)';

  @override
  String get api_error_401 => 'Authentication failed';

  @override
  String get api_error_401_hint =>
      'Token invalid or expired. Please login again';

  @override
  String get api_error_402 => 'Insufficient balance';

  @override
  String get api_error_402_hint =>
      'Insufficient Anlas. Please top up and try again';

  @override
  String get api_error_500 => 'Server error';

  @override
  String get api_error_500_hint =>
      'NovelAI server error. Please try again later';

  @override
  String get api_error_503 => 'Service unavailable';

  @override
  String get api_error_503_hint =>
      'Server is under maintenance or overloaded. Please try again later';

  @override
  String get api_error_timeout => 'Request timeout';

  @override
  String get api_error_timeout_hint =>
      'Network timeout. Please check your connection and try again';

  @override
  String get api_error_network => 'Network error';

  @override
  String get api_error_network_hint =>
      'Cannot connect to server. Please check your network';

  @override
  String get drop_processing => 'Processing image...';

  @override
  String get characterEditor_close => 'Close';

  @override
  String get characterEditor_clearAll => 'Clear All';

  @override
  String get characterEditor_clearAllTitle => 'Clear All Characters';

  @override
  String get characterEditor_clearAllConfirm =>
      'Are you sure you want to delete all characters? This action cannot be undone.';

  @override
  String get characterEditor_nameHint => 'Enter character name';

  @override
  String get characterEditor_enabled => 'Enabled';

  @override
  String get characterEditor_promptHint => 'Enter prompt for this character...';

  @override
  String get characterEditor_negativePromptHint =>
      'Enter Undesired Content for this character...';

  @override
  String get characterCanvas_title => 'Character Positions';

  @override
  String get characterCanvas_aiChoice => 'AI\'s Choice';

  @override
  String get characterCanvas_custom => 'Custom';

  @override
  String get characterCanvas_aiHint =>
      'AI will place all characters automatically';

  @override
  String get characterCanvas_dragHint =>
      'Drag anchors to position characters; release to apply';

  @override
  String get characterEditor_genderFemale => 'Female';

  @override
  String get characterEditor_genderMale => 'Male';

  @override
  String get characterEditor_genderOther => 'Other';

  @override
  String get characterEditor_addFemale => 'F';

  @override
  String get characterEditor_addMale => 'M';

  @override
  String get characterEditor_addOther => 'Other';

  @override
  String get characterEditor_addFromLibrary => 'Library';

  @override
  String get characterEditor_moveUp => 'Move Up';

  @override
  String get characterEditor_moveDown => 'Move Down';

  @override
  String get toolbar_randomPrompt => 'Random Prompt';

  @override
  String get randomPromptToolsHiddenHint =>
      'Random prompt tools are hidden in Settings';

  @override
  String get toolbar_fullscreenEdit => 'Fullscreen Edit';

  @override
  String get toolbar_clear => 'Clear';

  @override
  String get toolbar_confirmClear => 'Confirm Clear';

  @override
  String get toolbar_settings => 'Settings';

  @override
  String get characterTooltip_noCharacters => 'No characters configured';

  @override
  String get characterTooltip_clickToConfig =>
      'Click to configure multi-character prompts';

  @override
  String get characterTooltip_globalAiLabel => 'Global AI Position:';

  @override
  String get characterTooltip_enabled => 'Enabled';

  @override
  String get characterTooltip_disabled => 'Disabled';

  @override
  String get characterTooltip_positionAi => 'AI';

  @override
  String get characterTooltip_disabledLabel => 'Disabled';

  @override
  String get characterTooltip_promptLabel => 'Prompt';

  @override
  String get characterTooltip_negativeLabel => 'Undesired Content';

  @override
  String get characterTooltip_notSet => 'Not set';

  @override
  String characterTooltip_summary(Object total, Object enabled) {
    return '$total characters ($enabled enabled)';
  }

  @override
  String get characterTooltip_viewFullConfig => 'Click for full configuration';

  @override
  String tagLibrary_generatedCharacters(Object count) {
    return 'Generated $count characters';
  }

  @override
  String tagLibrary_generateFailed(Object error) {
    return 'Generation failed: $error';
  }

  @override
  String get randomMode_title => 'Select Random Mode';

  @override
  String get randomMode_naiOfficial => 'Offline Library';

  @override
  String get randomMode_custom => 'Custom Mode';

  @override
  String get randomMode_hybrid => 'Hybrid Mode';

  @override
  String get randomMode_naiOfficialDesc =>
      'Use the verified complete offline tag catalog';

  @override
  String get randomMode_customDesc => 'Generate using custom presets';

  @override
  String get randomMode_hybridDesc =>
      'Combine the offline library with custom presets';

  @override
  String get randomMode_naiIndicator => 'Offline';

  @override
  String get randomMode_customIndicator => 'Custom';

  @override
  String get naiMode_noTags => 'No tags';

  @override
  String get naiAlgorithm_characterCount => 'Character Count Distribution';

  @override
  String get naiAlgorithm_mainPrompt => 'Main Prompt';

  @override
  String tagGroup_tagCount(Object count) {
    return '$count tags';
  }

  @override
  String get addGroup_tagGroupTab => 'Tag Group';

  @override
  String get addGroup_displayNameLabel => 'Display Name (Optional)';

  @override
  String get addGroup_targetCategoryLabel => 'Target Category';

  @override
  String get addGroup_poolTab => 'Danbooru Pool';

  @override
  String globalSettings_saveFailed(Object error) {
    return 'Save failed: $error';
  }

  @override
  String get globalSettings_category_hairColor => 'Hair Color';

  @override
  String get globalSettings_category_eyeColor => 'Eye Color';

  @override
  String get globalSettings_category_hairStyle => 'Hair Style';

  @override
  String get globalSettings_category_expression => 'Expression';

  @override
  String get globalSettings_category_pose => 'Pose';

  @override
  String get globalSettings_category_clothing => 'Clothing';

  @override
  String get globalSettings_category_accessory => 'Accessory';

  @override
  String get globalSettings_category_bodyFeature => 'Body Feature';

  @override
  String get globalSettings_category_background => 'Background';

  @override
  String get globalSettings_category_scene => 'Scene';

  @override
  String get globalSettings_category_style => 'Style';

  @override
  String get nav_generate => 'Generate';

  @override
  String get nav_gallery => 'Gallery';

  @override
  String get nav_settings => 'Settings';

  @override
  String download_completed(Object name) {
    return '$name download completed';
  }

  @override
  String download_failed(Object name) {
    return '$name download failed';
  }

  @override
  String get sync_preparing => 'Preparing to sync...';

  @override
  String sync_fetching(Object category) {
    return 'Fetching $category...';
  }

  @override
  String get sync_processing => 'Processing data...';

  @override
  String get sync_saving => 'Saving...';

  @override
  String sync_completed(Object count) {
    return 'Sync completed, $count tags';
  }

  @override
  String sync_failed(Object error) {
    return 'Sync failed: $error';
  }

  @override
  String sync_extracting(Object poolName) {
    return 'Extracting $poolName tags...';
  }

  @override
  String get sync_merging => 'Merging tags...';

  @override
  String sync_fetching_tags(Object groupName) {
    return 'Fetching $groupName tag popularity...';
  }

  @override
  String get sync_filtering => 'Filtering tags...';

  @override
  String get sync_done => 'Sync completed';

  @override
  String get download_tags_data => 'Downloading tags data...';

  @override
  String get download_cooccurrence_data => 'Downloading cooccurrence data...';

  @override
  String get download_parsing_data => 'Parsing data...';

  @override
  String get download_readingFile => 'Reading file...';

  @override
  String get download_mergingData => 'Merging data...';

  @override
  String get download_loadComplete => 'Loading complete';

  @override
  String get time_just_now => 'Just now';

  @override
  String time_minutes_ago(Object n) {
    return '$n minutes ago';
  }

  @override
  String time_hours_ago(Object n) {
    return '$n hours ago';
  }

  @override
  String time_days_ago(Object n) {
    return '$n days ago';
  }

  @override
  String get time_never_synced => 'Never synced';

  @override
  String get preset_resetToDefault => 'Reset to Default';

  @override
  String get newPresetDialog_title => 'Create New Preset';

  @override
  String get newPresetDialog_blank => 'Completely Blank';

  @override
  String get newPresetDialog_blankDesc =>
      'Create preset from scratch with no preset content';

  @override
  String get newPresetDialog_template => 'Based on Default Preset';

  @override
  String get newPresetDialog_templateDesc =>
      'Copy all settings from default preset as starting point';

  @override
  String get category_dialogTitle => 'Create Category';

  @override
  String get category_nameHint => 'Enter category name';

  @override
  String get category_nameRequired => 'Name is required';

  @override
  String get category_selectEmoji => 'Select Emoji';

  @override
  String get category_noRecentEmoji => 'No recent emojis';

  @override
  String get category_searchEmoji => 'Search emoji';

  @override
  String get characterCountConfig_title => 'Character Count Config';

  @override
  String get characterCountConfig_weight => 'Weight';

  @override
  String get characterCountConfig_solo => 'Solo';

  @override
  String get characterCountConfig_duo => 'Duo';

  @override
  String get characterCountConfig_trio => 'Trio';

  @override
  String get characterCountConfig_noHumans => 'No Humans';

  @override
  String get characterCountConfig_multiPerson => 'Multi-Person';

  @override
  String get characterCountConfig_customizable => 'Customizable';

  @override
  String get characterCountConfig_mainPrompt => 'Main Prompt';

  @override
  String get characterCountConfig_characterPrompt => 'Character Prompt';

  @override
  String get characterCountConfig_addTagOption => 'Add Character Tag';

  @override
  String get characterCountConfig_addMultiPersonCombo =>
      'Add Multi-Person Combo';

  @override
  String get characterCountConfig_displayName => 'Display Name';

  @override
  String get characterCountConfig_displayNameHint => 'e.g., Trap';

  @override
  String get characterCountConfig_mainPromptLabel => 'Main Prompt Tags';

  @override
  String get characterCountConfig_mainPromptHint =>
      'e.g., solo, 2girls, 1girl 1boy';

  @override
  String get characterCountConfig_personCount => 'Person Count:';

  @override
  String get characterCountConfig_slotConfig => 'Character Slot Config';

  @override
  String get characterCountConfig_slot => 'Slot';

  @override
  String get characterCountConfig_customSlots => 'Custom Slots';

  @override
  String get characterCountConfig_customSlotsTitle =>
      'Character Slot Management';

  @override
  String get characterCountConfig_customSlotsDesc =>
      'Add or remove available character slot options';

  @override
  String get characterCountConfig_addSlotHint => 'e.g., 1trap, 1futanari';

  @override
  String get characterCountConfig_slotExists => 'This slot already exists';

  @override
  String get randomManager_algorithmConfig => 'Algorithm Config';

  @override
  String get randomManager_characterCountWeight => 'Character Count Weight';

  @override
  String get randomManager_genderWeight => 'Gender Weight';

  @override
  String get randomManager_globalSettings => 'Global Settings';

  @override
  String get randomManager_enableSeasonalWordlists =>
      'Enable Seasonal Wordlists';

  @override
  String get randomManager_enableSeasonalWordlistsDesc =>
      'Wordlists for Christmas, Halloween, and other special dates';

  @override
  String get randomManager_globalEmphasisProbability =>
      'Global Emphasis Probability';

  @override
  String get randomManager_soloGenderOptions => 'Solo Gender Options';

  @override
  String get randomManager_femaleShort => 'F';

  @override
  String get randomManager_maleShort => 'M';

  @override
  String get randomManager_other => 'Other';

  @override
  String get randomManager_tagGroupList => 'Tag Groups';

  @override
  String get randomManager_deleteTagGroupTitle => 'Delete Tag Group';

  @override
  String randomManager_deleteTagGroupConfirm(Object name) {
    return 'Delete tag group \"$name\"? This action cannot be undone.';
  }

  @override
  String randomManager_tagGroupCount(Object count) {
    return '$count tag groups';
  }

  @override
  String get randomManager_categories => 'Categories';

  @override
  String get randomManager_tagGroups => 'Tag Groups';

  @override
  String get randomManager_tags => 'Tags';

  @override
  String get randomManager_addTagGroup => 'Add Tag Group';

  @override
  String get randomManager_locked => 'Locked';

  @override
  String get randomManager_addCategory => 'Add Category';

  @override
  String get randomManager_noCategories => 'No categories';

  @override
  String get randomManager_noCategoriesHint =>
      'Click \"Add Category\" to start configuring';

  @override
  String get randomManager_globalPeopleSettings => 'Global Character Settings';

  @override
  String get randomManager_closePreview => 'Close preview';

  @override
  String get randomManager_importPreset => 'Import Preset';

  @override
  String get randomManager_importPresetSubtitle =>
      'Import random config preset from JSON text';

  @override
  String get randomManager_exportCurrentPreset => 'Export Current Preset';

  @override
  String get randomManager_noPresetSelected => 'No preset selected';

  @override
  String get randomManager_selectPresetFirst => 'Please select a preset first';

  @override
  String get randomManager_defaultPresetReadonly =>
      'Default presets are read-only. Create or copy a custom preset first.';

  @override
  String randomManager_presetImported(Object name) {
    return 'Imported preset \"$name\"';
  }

  @override
  String get randomManager_defaultPresetV4 => 'Default Mode (V4)';

  @override
  String get randomManager_defaultPresetLegacy => 'Default Mode (Legacy)';

  @override
  String get randomManager_defaultPresetFurry => 'Default Mode (Furry)';

  @override
  String get randomManager_defaultPresetV4Description =>
      'Random algorithm configuration based on the NAI V4 model, with multi-character support';

  @override
  String get randomManager_defaultPresetLegacyDescription =>
      'Random algorithm configuration based on the NAI Legacy model';

  @override
  String get randomManager_defaultPresetFurryDescription =>
      'Random algorithm configuration based on the NAI Furry model';

  @override
  String get randomManager_defaultPresetOfficialDescription =>
      'Random algorithm configuration based on the NAI official setup';

  @override
  String get randomManager_femaleClothing => 'Female Clothing';

  @override
  String get randomManager_maleClothing => 'Male Clothing';

  @override
  String get randomManager_generalClothing => 'General Clothing';

  @override
  String get randomManager_femaleBodyType => 'Female Body Type';

  @override
  String get randomManager_maleBodyType => 'Male Body Type';

  @override
  String get randomManager_generalBodyType => 'General Body Type';

  @override
  String get randomManager_soloFemale => 'Female';

  @override
  String get randomManager_soloMale => 'Male';

  @override
  String get randomManager_duoGirls => 'Two Girls';

  @override
  String get randomManager_duoMixed => 'Girl and Boy';

  @override
  String get randomManager_duoBoys => 'Two Boys';

  @override
  String get randomManager_trioGirls => 'Three Girls';

  @override
  String get randomManager_trioTwoGirlsOneBoy => 'Two Girls and One Boy';

  @override
  String get randomManager_trioOneGirlTwoBoys => 'One Girl and Two Boys';

  @override
  String get randomManager_trioBoys => 'Three Boys';

  @override
  String get randomManager_noHumanScene => 'No-Human Scene';

  @override
  String randomManager_presetCreated(Object name) {
    return 'Created preset \"$name\"';
  }

  @override
  String randomManager_deletePresetConfirm(Object name) {
    return 'Delete \"$name\"? This cannot be undone.';
  }

  @override
  String get randomManager_syncCompleted => 'Danbooru tags synced';

  @override
  String randomManager_syncFailed(Object error) {
    return 'Sync failed: $error';
  }

  @override
  String get randomManager_resetDefaultTitle => 'Reset to Default';

  @override
  String get randomManager_resetDefaultContent =>
      'Restore the official default configuration.\nCustom tag groups will be kept but disabled.';

  @override
  String get randomManager_resetDefaultConfirm => 'Reset';

  @override
  String get randomManager_resetDefaultDone => 'Reset to default configuration';

  @override
  String get randomManager_generatePreview => 'Generate Preview';

  @override
  String get randomManager_importExport => 'Import / Export';

  @override
  String get randomManager_syncing => 'Syncing';

  @override
  String get randomManager_syncDanbooruTags => 'Sync Danbooru Tags';

  @override
  String get randomManager_unknownError => 'Unknown error';

  @override
  String get randomManager_readOnlyMode => 'Read-only Mode';

  @override
  String get randomManager_readOnlyTooltip =>
      'The current preset is a default preset, so all configuration items are locked';

  @override
  String get randomManager_searchCategoryOrTagGroup =>
      'Search categories or tag groups...';

  @override
  String get randomManager_scope => 'Scope';

  @override
  String get randomManager_global => 'Global';

  @override
  String get randomManager_private => 'Private';

  @override
  String get randomManager_status => 'Status';

  @override
  String get randomManager_enabledOnly => 'Enabled only';

  @override
  String get randomManager_diyCapable => 'Has DIY capabilities';

  @override
  String randomManager_addTagGroupSubtitle(Object category) {
    return 'Add to \"$category\"';
  }

  @override
  String get randomManager_tagGroupName => 'Tag Group Name';

  @override
  String get randomManager_tagGroupNameHint => 'Enter tag group name';

  @override
  String get randomManager_tagGroupNameRequired =>
      'Please enter a tag group name';

  @override
  String get randomManager_customTab => 'Custom';

  @override
  String get randomManager_tagList => 'Tag List';

  @override
  String get randomManager_tagListHelp =>
      'One tag per line. Supports tag or tag:weight.';

  @override
  String get randomManager_searchTagGroup => 'Search Tag Group...';

  @override
  String get randomManager_searchPool => 'Search Pool...';

  @override
  String randomManager_itemCount(Object count) {
    return '$count items';
  }

  @override
  String get randomManager_noMatchingTagGroup => 'No matching Tag Groups found';

  @override
  String get randomManager_noMatchingPool => 'No matching Pools found';

  @override
  String get randomManager_cannotLoadPreview => 'Unable to load preview';

  @override
  String get randomManager_openInDanbooru => 'View in Danbooru';

  @override
  String get randomManager_editTagGroup => 'Edit Tag Group';

  @override
  String get randomManager_basicTab => 'Basic';

  @override
  String randomManager_tagsTab(Object count) {
    return 'Tags ($count)';
  }

  @override
  String get randomManager_diyAbilitiesTab => 'DIY Capabilities';

  @override
  String get randomManager_selectionSingle => 'Single';

  @override
  String get randomManager_selectionSingleDesc => 'Weighted random single pick';

  @override
  String get randomManager_selectionAll => 'All';

  @override
  String get randomManager_selectionAllDesc => 'Select all tags';

  @override
  String get randomManager_selectionMultipleCount => 'Multiple Count';

  @override
  String get randomManager_selectionMultipleCountDesc =>
      'Select a specified count';

  @override
  String get randomManager_selectionMultipleProbability =>
      'Multiple Probability';

  @override
  String get randomManager_selectionMultipleProbabilityDesc =>
      'Evaluate each tag independently';

  @override
  String get randomManager_selectionSequential => 'Sequential';

  @override
  String get randomManager_selectionSequentialDesc =>
      'Keep state across batches';

  @override
  String get randomManager_noTags => 'No tags';

  @override
  String get randomManager_conditionalBranch => 'Conditional Branch';

  @override
  String get randomManager_conditionalBranchDesc =>
      'Choose different tag subsets based on variable values';

  @override
  String get randomManager_dependencyConfig => 'Dependency Config';

  @override
  String get randomManager_dependencyConfigDesc =>
      'Make count selection depend on other category values';

  @override
  String get randomManager_visibilityRules => 'Visibility Rules';

  @override
  String get randomManager_visibilityRulesDesc =>
      'Decide whether to generate based on composition';

  @override
  String get randomManager_timeCondition => 'Time Condition';

  @override
  String get randomManager_timeConditionDesc =>
      'Enable within a specific date range';

  @override
  String get randomManager_postProcessRules => 'Post-process Rules';

  @override
  String get randomManager_postProcessRulesDesc =>
      'Remove conflicts based on selected tags';

  @override
  String get randomManager_emphasisProbability => 'Emphasis Probability';

  @override
  String get randomManager_probability => 'Probability';

  @override
  String get randomManager_selectionMode => 'Selection Mode';

  @override
  String randomManager_editHint(Object name) {
    return '$name (click to edit)';
  }

  @override
  String randomManager_emphasisProbabilityValue(Object percent) {
    return 'Emphasis probability: $percent%';
  }

  @override
  String get randomManager_previewGeneration => 'Preview Generation';

  @override
  String get randomManager_generating => 'Generating';

  @override
  String get randomManager_generate => 'Generate';

  @override
  String get randomManager_generationFailed => 'Generation Failed';

  @override
  String get randomManager_copy => 'Copy';

  @override
  String get randomManager_regenerate => 'Regenerate';

  @override
  String get randomManager_copiedToClipboard => 'Copied to clipboard';

  @override
  String get randomManager_selectPresetRequired => 'Please select a preset';

  @override
  String randomManager_characterCountLabel(Object count) {
    return '$count characters';
  }

  @override
  String randomManager_tagCountLabel(Object count) {
    return '$count tags';
  }

  @override
  String get randomManager_previewHint =>
      'Click \"Generate\" to preview random tags';

  @override
  String get randomManager_generateNow => 'Generate Now';

  @override
  String get randomManager_batchOperations => 'Batch Operations';

  @override
  String randomManager_selectedItems(Object count) {
    return '$count selected';
  }

  @override
  String randomManager_totalItems(Object count) {
    return '$count total';
  }

  @override
  String randomManager_enabledItems(Object count) {
    return 'Enabled $count items';
  }

  @override
  String randomManager_disabledItems(Object count) {
    return 'Disabled $count items';
  }

  @override
  String get randomManager_batchDeleteTitle => 'Batch Delete';

  @override
  String randomManager_batchDeleteContent(Object count) {
    return 'Delete $count selected items? This action cannot be undone.';
  }

  @override
  String randomManager_deletedItems(Object count) {
    return 'Deleted $count items';
  }

  @override
  String get randomManager_invertSelection => 'Invert Selection';

  @override
  String get randomManager_moreActions => 'More Actions';

  @override
  String get randomManager_enableSelected => 'Enable Selected';

  @override
  String get randomManager_disableSelected => 'Disable Selected';

  @override
  String get randomManager_deleteSelected => 'Delete Selected';

  @override
  String get randomManager_noHistory => 'No history';

  @override
  String get randomManager_operationHistory => 'Operation History';

  @override
  String get randomManager_keyboardShortcuts => 'Keyboard Shortcuts';

  @override
  String get randomManager_generalShortcuts => 'General';

  @override
  String get randomManager_presetActions => 'Preset Actions';

  @override
  String get randomManager_selectionActions => 'Selection Actions';

  @override
  String get randomManager_closeWindow => 'Close Window';

  @override
  String get randomManager_refreshOrSync => 'Refresh / Sync';

  @override
  String get gender_female => 'Female';

  @override
  String get gender_male => 'Male';

  @override
  String get scope_global => 'Main';

  @override
  String get scope_globalTooltip =>
      'Prompt will appear in main prompt area\nSuitable for: background, scene, style, etc.';

  @override
  String get scope_character => 'Char';

  @override
  String get scope_characterTooltip =>
      'Prompt will only appear in character prompts\nGenerated separately for each character\nSuitable for: hair color, eye color, clothing, expression, etc.';

  @override
  String get scope_all => 'Both';

  @override
  String get scope_allTooltip =>
      'Prompt appears in both main and character prompts\nSuitable for: pose, interaction, and other universal tags';

  @override
  String get vibeParseFailed => 'Failed to parse Vibe file';

  @override
  String get tagGroupBrowser_searchHint => 'Search tags...';

  @override
  String tagGroupBrowser_tagCount(Object count) {
    return '$count tags';
  }

  @override
  String tagGroupBrowser_filteredTagCount(Object filtered, Object total) {
    return 'Showing $filtered of $total tags';
  }

  @override
  String get tagGroupBrowser_noTags => 'No tags';

  @override
  String get tagGroupBrowser_noLibrary => 'Tag library not loaded';

  @override
  String get tagGroupBrowser_importLibraryHint =>
      'Please import a tag library first';

  @override
  String get tagGroupBrowser_noCategories => 'No enabled tag categories';

  @override
  String get tagGroupBrowser_enableCategoriesHint =>
      'Please enable tag categories in settings';

  @override
  String get tagGroupBrowser_danbooruSuggestions => 'Danbooru Suggestions';

  @override
  String get tag_favoritesTitle => 'Favorite Tags';

  @override
  String get tag_favoritesEmpty => 'No favorite tags yet';

  @override
  String get tag_favoritesEmptyHint =>
      'Long-press on a tag to add it to favorites';

  @override
  String get tag_alreadyAdded => 'Tag already added to current prompt';

  @override
  String get tag_removeFavoriteTitle => 'Remove from Favorites';

  @override
  String tag_removeFavoriteMessage(Object tag) {
    return 'Remove \"$tag\" from favorites?';
  }

  @override
  String get tag_templatesTitle => 'Tag Templates';

  @override
  String get tag_templatesEmpty => 'No tag templates yet';

  @override
  String get tag_templatesEmptyHint =>
      'Select tags and click the + button to create a template';

  @override
  String get tag_templateCreate => 'Create Template';

  @override
  String get tag_templateNameLabel => 'Template Name';

  @override
  String get tag_templateNameHint => 'Enter template name';

  @override
  String get tag_templateNameRequired => 'Please enter a template name';

  @override
  String get tag_templateDescLabel => 'Description (Optional)';

  @override
  String get tag_templateDescHint => 'Enter template description';

  @override
  String get tag_templatePreview => 'Tag Preview';

  @override
  String tag_templateTagCount(Object count) {
    return '$count tags';
  }

  @override
  String tag_templateMoreTags(Object count) {
    return '$count more tags...';
  }

  @override
  String tag_templateInserted(Object name) {
    return 'Inserted template \"$name\"';
  }

  @override
  String get tag_templateNoTags => 'No tags to save';

  @override
  String get tag_templateSaved => 'Template saved';

  @override
  String get tag_templateNameExists => 'Template name already exists';

  @override
  String get tag_templateDeleteTitle => 'Delete Template';

  @override
  String tag_templateDeleteMessage(Object name) {
    return 'Delete template \"$name\"?';
  }

  @override
  String get tag_categoryGeneral => 'General';

  @override
  String get tag_categoryArtist => 'Artist';

  @override
  String get tag_categoryCopyright => 'Copyright';

  @override
  String get tag_categoryCharacter => 'Character';

  @override
  String get tag_categoryMeta => 'Meta';

  @override
  String get tag_countBadgeBreakdown => 'Tag Breakdown';

  @override
  String get localGallery_progressiveLoadError => 'Failed to load image';

  @override
  String get localGallery_noImagesFound => 'No images found';

  @override
  String get localGallery_unknownError => 'Unknown error';

  @override
  String localGallery_loadFailed(Object error) {
    return 'Load failed: $error';
  }

  @override
  String get localGallery_indexingLocalImages => 'Indexing local images...';

  @override
  String get localGallery_emptyTitle => 'No local images';

  @override
  String get localGallery_emptySubtitle =>
      'Generated images will be saved here';

  @override
  String get localGallery_noMatchingResults => 'No matching results';

  @override
  String get localGallery_loadingGroupedImages => 'Loading grouped images...';

  @override
  String localGallery_jumpedToMonth(Object year, Object month) {
    return 'Jumped to $year-$month';
  }

  @override
  String get localGallery_title => 'Local Gallery';

  @override
  String get localGallery_allImages => 'All Images';

  @override
  String get localGallery_categoryPanelTitle => 'Categories';

  @override
  String get localGallery_searchFilenamePromptPlaceholder =>
      'Search filename/Prompt; comma-separated terms are matched together...';

  @override
  String get localGallery_selectCurrentPage => 'Select Page';

  @override
  String get localGallery_deselectCurrentPage => 'Deselect Page';

  @override
  String get localGallery_selectAllResults => 'Select All';

  @override
  String get localGallery_deselectAllResults => 'Deselect All';

  @override
  String get localGallery_moveSelected => 'Move';

  @override
  String get localGallery_packSelected => 'Pack';

  @override
  String get localGallery_editMetadata => 'Edit Tags';

  @override
  String get localGallery_addToCollection => 'Collect';

  @override
  String get localGallery_switchToGridView => 'Switch to grid view';

  @override
  String get localGallery_switchToDateGroupedView =>
      'Switch to date grouped view';

  @override
  String get localGallery_openFilterPanel => 'Open filter panel';

  @override
  String get localGallery_hideCategoryPanel => 'Hide category panel';

  @override
  String get localGallery_showCategoryPanel => 'Show category panel';

  @override
  String get localGallery_enterSelectionMode => 'Enter selection mode';

  @override
  String get localGallery_refreshTooltip =>
      'Refresh gallery\n\nAutomatically detects new or changed images and updates the index';

  @override
  String get localGallery_tagIntersection => 'Tag Intersection';

  @override
  String get localGallery_createCategoryTitle => 'New Category';

  @override
  String get localGallery_createCategoryHint => 'Enter category name';

  @override
  String get localGallery_createCategoryConfirm => 'Create';

  @override
  String get localGallery_createSubCategoryTitle => 'New Subcategory';

  @override
  String get localGallery_showInFolder => 'Show in Folder';

  @override
  String get localGallery_promptCopied => 'Prompt copied';

  @override
  String get localGallery_seedCopied => 'Seed copied';

  @override
  String localGallery_confirmDeleteImageContent(Object name) {
    return 'Delete image \"$name\"?\n\nThis cannot be undone.';
  }

  @override
  String get localGallery_imageDeleted => 'Image deleted';

  @override
  String localGallery_deleteFailed(Object error) {
    return 'Delete failed: $error';
  }

  @override
  String get localGallery_categoryDeleteContent =>
      'Delete this category? The folder and its contents will be kept.';

  @override
  String get localGallery_protectedDeleteCategoryTitle =>
      'Protected Mode: Confirm Category Deletion';

  @override
  String get localGallery_protectedDeleteCategoryContent =>
      'This will delete the category record. The folder and its contents will be kept. Confirm again.';

  @override
  String get localGallery_confirmDelete => 'Confirm Delete';

  @override
  String get localGallery_confirmMoveImageTitle =>
      'Protected Mode: Confirm Image Move';

  @override
  String get localGallery_confirmMoveImageContent =>
      'This will move the image to the target category folder. Confirm this was not an accidental drag.';

  @override
  String get localGallery_confirmMove => 'Confirm Move';

  @override
  String get localGallery_imageMovedToCategory => 'Image moved to category';

  @override
  String get localGallery_categoriesSynced => 'Categories synced with folders';

  @override
  String get localGallery_saveDirectoryNotSet => 'Save directory is not set';

  @override
  String get localGallery_folderNotFound => 'Folder not found';

  @override
  String localGallery_openFolderFailed(Object error) {
    return 'Failed to open folder: $error';
  }

  @override
  String get localGallery_protectedDeleteTitle =>
      'Protected Mode: Confirm Delete Again';

  @override
  String localGallery_protectedDeleteImagesContent(Object count) {
    return 'This will permanently delete $count local image files. This cannot be undone.';
  }

  @override
  String get localGallery_protectedBulkMoveTitle =>
      'Protected Mode: Confirm Bulk Move';

  @override
  String localGallery_protectedBulkMoveContent(Object count) {
    return 'This will move $count local image files to the target folder. Confirm this is not a mistake.';
  }

  @override
  String localGallery_importParamsFailed(Object error) {
    return 'Failed to import parameters: $error';
  }

  @override
  String localGallery_protectedDeleteImageContent(Object name) {
    return 'This will permanently delete image \"$name\". This cannot be undone.';
  }

  @override
  String get localGallery_saveZipArchive => 'Save ZIP Archive';

  @override
  String get localGallery_zipMetadataTitle => 'Export ZIP';

  @override
  String get localGallery_zipMetadataDescription =>
      'Choose whether images in the ZIP keep their embedded metadata. Original files will not be changed.';

  @override
  String get localGallery_zipIncludeMetadata => 'Keep metadata';

  @override
  String get localGallery_zipIncludeMetadataDescription =>
      'Pack the original image files without changes.';

  @override
  String get localGallery_zipExcludeMetadata => 'Remove all metadata';

  @override
  String get localGallery_zipExcludeMetadataDescription =>
      'Create sanitized copies for the ZIP, removing PNG text chunks, EXIF, and NovelAI stealth watermark data.';

  @override
  String bulkMetadataEdit_title(Object count) {
    return 'Edit Tags for $count Images';
  }

  @override
  String get bulkMetadataEdit_tagsToAdd => 'Tags to Add';

  @override
  String get bulkMetadataEdit_tagsToAddHint => 'Enter tags to add...';

  @override
  String get bulkMetadataEdit_tagsToRemove => 'Tags to Remove';

  @override
  String get bulkMetadataEdit_tagsToRemoveHint => 'Enter tags to remove...';

  @override
  String get bulkMetadataEdit_noChanges =>
      'Add at least one tag to add or remove';

  @override
  String localGallery_packingImages(Object count) {
    return 'Packing $count images...';
  }

  @override
  String localGallery_packedImages(Object count) {
    return 'Packed $count images';
  }

  @override
  String localGallery_packingProgress(Object current, Object total) {
    return 'Packing $current of $total images...';
  }

  @override
  String get localGallery_packPartialTitle => 'Some images were not exported';

  @override
  String localGallery_packedImagesWithFailures(Object exported, Object failed) {
    return 'ZIP created with $exported images; $failed images could not be included';
  }

  @override
  String get localGallery_packFailed => 'Failed to pack images';

  @override
  String localGallery_packFailedWithDetails(Object error) {
    return 'Failed to create ZIP: $error';
  }

  @override
  String get localGallery_packAlreadyInProgress =>
      'A ZIP export is already in progress';

  @override
  String get localGallery_imageFileMissing => 'Image file does not exist';

  @override
  String get localGallery_sentToImageToImage => 'Image sent to Image2Image';

  @override
  String localGallery_sendFailed(Object error) {
    return 'Send failed: $error';
  }

  @override
  String get localGallery_sentToReversePrompt => 'Image sent to reverse prompt';

  @override
  String localGallery_sendToKritaFailed(Object error) {
    return 'Failed to send to Krita: $error';
  }

  @override
  String get localGallery_sendToImg2Img => 'Send to Image2Image';

  @override
  String get localGallery_sendToReversePrompt => 'Send to Reverse Prompt';

  @override
  String get localGallery_sendToStyleTransfer => 'Send to Vibe Transfer';

  @override
  String get localGallery_sendToPreciseReference => 'Send to Precise Reference';

  @override
  String get localGallery_sendToKrita => 'Send to Krita';

  @override
  String get localGallery_importImageMetadata => 'Import Image Metadata';

  @override
  String get localGallery_copyPrompt => 'Copy Prompt';

  @override
  String get localGallery_copySeed => 'Copy Seed';

  @override
  String get localGallery_dragToShare => 'Drag to share';

  @override
  String get localGallery_moveToRoot => 'Move to Root';

  @override
  String get localGallery_folderName => 'Folder Name';

  @override
  String get localGallery_newFolderName => 'New Name';

  @override
  String get localGallery_folderNameHint => 'Enter folder name';

  @override
  String get localGallery_folderCreated => 'Folder created';

  @override
  String get localGallery_folderCreateFailed => 'Failed to create folder';

  @override
  String get localGallery_renameFolderTitle => 'Rename Folder';

  @override
  String get localGallery_renameSuccess => 'Renamed';

  @override
  String get localGallery_renameFailed => 'Rename failed';

  @override
  String get localGallery_deleteFolderTitle => 'Delete Folder';

  @override
  String localGallery_deleteFolderWithImagesContent(Object name, Object count) {
    return 'Folder \"$name\" contains $count images. Delete it?\n\nNote: this will delete the folder and all images in it. This cannot be undone.';
  }

  @override
  String localGallery_deleteEmptyFolderContent(Object name) {
    return 'Delete empty folder \"$name\"?';
  }

  @override
  String get localGallery_folderDeleted => 'Folder deleted';

  @override
  String get localGallery_folderDeleteFailed => 'Failed to delete folder';

  @override
  String get localGallery_cachingMetadata => 'Caching metadata...';

  @override
  String get localGallery_metadataCacheStats => 'Metadata Cache Stats';

  @override
  String get localGallery_totalImages => 'Total Images';

  @override
  String get localGallery_withMetadata => 'With Metadata';

  @override
  String get localGallery_skipped => 'Skipped';

  @override
  String get localGallery_remaining => 'Remaining';

  @override
  String get localGallery_cacheMonitor => 'Cache Monitor';

  @override
  String get localGallery_threeLayerCacheStats => 'Three-layer Cache Stats';

  @override
  String localGallery_updatedAt(Object time) {
    return 'Updated: $time';
  }

  @override
  String get localGallery_memoryCache => 'Memory Cache';

  @override
  String get localGallery_hiveCache => 'Hive Cache';

  @override
  String get localGallery_sqliteDatabase => 'SQLite Database';

  @override
  String get localGallery_imageUnit => 'images';

  @override
  String get localGallery_metadataUnit => 'metadata';

  @override
  String get localGallery_entriesUnit => 'entries';

  @override
  String get localGallery_hitRate => 'Hit Rate';

  @override
  String get localGallery_performanceStats => 'Performance Stats';

  @override
  String get localGallery_cacheHit => 'Hit';

  @override
  String get localGallery_cacheMiss => 'Miss';

  @override
  String get localGallery_clearL1 => 'Clear L1';

  @override
  String get localGallery_clearL2 => 'Clear L2';

  @override
  String get localGallery_clearAll => 'Clear All';

  @override
  String get localGallery_resetStats => 'Reset Stats';

  @override
  String get localGallery_confirmClearCache => 'Confirm Clear';

  @override
  String get localGallery_confirmClearCacheContent =>
      'Clear all caches? This will rescan all images.';

  @override
  String get localGallery_clearFilters => 'Clear filters';

  @override
  String get slideshow_of => 'of';

  @override
  String get slideshow_play => 'Play';

  @override
  String get slideshow_pause => 'Pause';

  @override
  String get slideshow_previous => 'Previous';

  @override
  String get slideshow_next => 'Next';

  @override
  String get slideshow_exit => 'Exit (Esc)';

  @override
  String get slideshow_noImages => 'No images to display';

  @override
  String get slideshow_keyboardHint =>
      'Use ← → to navigate, Space to play/pause, Esc to exit';

  @override
  String get comparison_noImages => 'No images to display';

  @override
  String get comparison_tooManyImages => 'Too many images';

  @override
  String get comparison_maxImages => 'Maximum 4 images allowed for comparison';

  @override
  String get comparison_close => 'Close comparison';

  @override
  String get comparison_zoomHint => 'Pinch or scroll to zoom independently';

  @override
  String get comparison_loadError => 'Failed to load image';

  @override
  String get statistics_title => 'Statistics';

  @override
  String get statistics_noData => 'No statistics available';

  @override
  String get statistics_generatedCount => 'Generated';

  @override
  String get statistics_favoriteCount => 'Favorites';

  @override
  String statistics_tooltipGenerated(Object count) {
    return 'Generated: $count';
  }

  @override
  String statistics_tooltipFavorite(Object count) {
    return 'Favorites: $count';
  }

  @override
  String get statistics_noTagData => 'No tag data';

  @override
  String get statistics_generateFirst => 'Generate some images first';

  @override
  String get statistics_totalImages => 'Total Images';

  @override
  String get statistics_totalSize => 'Total Size';

  @override
  String get statistics_favorites => 'Favorites';

  @override
  String get statistics_samplerDistribution => 'Sampler Distribution';

  @override
  String get statistics_additionalStats => 'Additional Statistics';

  @override
  String get statistics_averageFileSize => 'Average File Size';

  @override
  String get statistics_withMetadata => 'Images with Metadata';

  @override
  String get statistics_justNow => 'Just now';

  @override
  String statistics_minutesAgo(Object count) {
    return '$count minutes ago';
  }

  @override
  String statistics_hoursAgo(Object count) {
    return '$count hours ago';
  }

  @override
  String statistics_daysAgo(Object count) {
    return '$count days ago';
  }

  @override
  String get statistics_anlasCost => 'Anlas Cost';

  @override
  String get statistics_totalAnlasCost => 'Total Cost';

  @override
  String get statistics_avgDailyCost => 'Daily Average';

  @override
  String get statistics_noAnlasData => 'No Anlas consumption data';

  @override
  String get statistics_peakActivity => 'Peak Activity';

  @override
  String get statistics_timeMorning => 'Morning';

  @override
  String get statistics_timeAfternoon => 'Afternoon';

  @override
  String get statistics_timeEvening => 'Evening';

  @override
  String get statistics_timeNight => 'Night';

  @override
  String get localGallery_advancedFilters => 'Advanced Filters';

  @override
  String get localGallery_filterByModel => 'Filter by Model';

  @override
  String get localGallery_filterBySampler => 'Filter by Sampler';

  @override
  String get localGallery_filterBySteps => 'Filter by Steps';

  @override
  String get localGallery_filterByCfg => 'Filter by CFG Scale';

  @override
  String get localGallery_filterByResolution => 'Filter by Resolution';

  @override
  String get localGallery_filterSubtitle =>
      'Precisely filter your image collection';

  @override
  String get localGallery_modelHint => 'Enter model name...';

  @override
  String get localGallery_samplerHint => 'Enter sampler name...';

  @override
  String get localGallery_resolutionHint => 'Width x height (e.g. 1024x1024)';

  @override
  String get localGallery_activeFiltersSet => 'Filters set';

  @override
  String get localGallery_applyFilters => 'Apply Filters';

  @override
  String get localGallery_resetAdvancedFilters => 'Reset Advanced Filters';

  @override
  String get localGallery_exportFailed => 'Export failed';

  @override
  String get bulkExport_format => 'Format';

  @override
  String get bulkExport_jsonFormat => 'JSON';

  @override
  String get bulkExport_csvFormat => 'CSV';

  @override
  String get bulkExport_includeMetadataHint =>
      'Export generation parameters with images';

  @override
  String get localGallery_group_today => 'Today';

  @override
  String get localGallery_group_yesterday => 'Yesterday';

  @override
  String get localGallery_group_thisWeek => 'This Week';

  @override
  String get localGallery_group_earlier => 'Earlier';

  @override
  String localGallery_cannotOpenFolder(Object error) {
    return 'Cannot open folder: $error';
  }

  @override
  String get localGallery_permissionRequiredTitle =>
      'Storage Permission Required';

  @override
  String get localGallery_permissionRequiredContent =>
      'Local gallery needs storage permission to scan your generated images.\n\nPlease grant permission in settings and try again.';

  @override
  String get localGallery_openSettings => 'Open Settings';

  @override
  String get localGallery_firstTimeTipTitle => '💡 Tips';

  @override
  String get localGallery_firstTimeTipContent =>
      'Right-click (desktop) or long-press (mobile) on images to:\n\n• Copy Prompt\n• Copy Seed\n• View full metadata';

  @override
  String get localGallery_gotIt => 'Got it';

  @override
  String get localGallery_undone => 'Undone';

  @override
  String get localGallery_redone => 'Redone';

  @override
  String get localGallery_confirmBulkDelete => 'Confirm Bulk Delete';

  @override
  String localGallery_confirmBulkDeleteContent(Object count) {
    return 'Are you sure you want to delete $count selected images?\n\nThis will permanently remove them from the file system and cannot be undone.';
  }

  @override
  String localGallery_deletedImages(Object count) {
    return 'Deleted $count images';
  }

  @override
  String get localGallery_noFoldersAvailable =>
      'No folders available, please create a folder first';

  @override
  String get localGallery_moveToFolder => 'Move to Folder';

  @override
  String localGallery_imageCount(Object count) {
    return '$count images';
  }

  @override
  String localGallery_movedImages(Object count) {
    return 'Moved $count images';
  }

  @override
  String get localGallery_moveImagesFailed => 'Failed to move images';

  @override
  String localGallery_addedToCollection(Object count, Object name) {
    return 'Added $count images to collection \"$name\"';
  }

  @override
  String get localGallery_addToCollectionFailed =>
      'Failed to add images to collection';

  @override
  String get brushPreset_selectHint => 'Double tap to select this brush preset';

  @override
  String get brushPreset_pencil => 'Pencil';

  @override
  String get brushPreset_fine => 'Fine Brush';

  @override
  String get brushPreset_standard => 'Standard Brush';

  @override
  String get brushPreset_soft => 'Soft Brush';

  @override
  String get brushPreset_airbrush => 'Airbrush';

  @override
  String get brushPreset_marker => 'Marker';

  @override
  String get brushPreset_thick => 'Thick Brush';

  @override
  String get brushPreset_smudge => 'Smudge Brush';

  @override
  String bulkProgress_progress(Object current, Object total) {
    return 'Processing $current of $total';
  }

  @override
  String bulkProgress_success(Object count) {
    return '$count succeeded';
  }

  @override
  String bulkProgress_failed(Object count) {
    return '$count failed';
  }

  @override
  String get bulkProgress_errors => 'Errors:';

  @override
  String bulkProgress_moreErrors(Object count) {
    return '...and $count more errors';
  }

  @override
  String bulkProgress_completed(Object count) {
    return '$count items completed';
  }

  @override
  String bulkProgress_completedWithErrors(Object success, Object failed) {
    return '$success succeeded, $failed failed';
  }

  @override
  String get bulkProgress_title_delete => 'Deleting Images';

  @override
  String get bulkProgress_title_export => 'Exporting Metadata';

  @override
  String get bulkProgress_title_metadataEdit => 'Editing Metadata';

  @override
  String get bulkProgress_title_addToCollection => 'Adding to Collection';

  @override
  String get bulkProgress_title_removeFromCollection =>
      'Removing from Collection';

  @override
  String get bulkProgress_title_toggleFavorite => 'Updating Favorites';

  @override
  String get bulkProgress_title_default => 'Processing';

  @override
  String get bulkProgress_continueInBackground => 'Continue in background';

  @override
  String get bulkProgress_operationAlreadyInProgress =>
      'Another batch operation is already in progress';

  @override
  String bulkProgress_errorDeleteFailed(String error) {
    return 'Failed to delete images: $error';
  }

  @override
  String get bulkProgress_errorNoImagesToExport => 'No images to export';

  @override
  String get bulkProgress_errorExportFailed => 'Export failed';

  @override
  String bulkProgress_errorExportFailedWithDetails(String error) {
    return 'Export failed: $error';
  }

  @override
  String get bulkProgress_errorNoMetadataChanges =>
      'Enter at least one tag to add or remove';

  @override
  String bulkProgress_errorMetadataEditFailed(String error) {
    return 'Failed to edit image metadata: $error';
  }

  @override
  String bulkProgress_errorFavoriteFailed(String error) {
    return 'Failed to update favorites: $error';
  }

  @override
  String get bulkProgress_errorNoImagesForCollection =>
      'No images to add to the collection';

  @override
  String bulkProgress_errorAddToCollectionFailed(String error) {
    return 'Failed to add images to the collection: $error';
  }

  @override
  String get bulkProgress_errorNothingToUndo => 'There is no operation to undo';

  @override
  String bulkProgress_errorUndoFailed(String error) {
    return 'Undo failed: $error';
  }

  @override
  String get bulkProgress_errorNothingToRedo => 'There is no operation to redo';

  @override
  String bulkProgress_errorRedoFailed(String error) {
    return 'Redo failed: $error';
  }

  @override
  String get collectionSelect_dialogTitle => 'Select Collection';

  @override
  String get collectionSelect_filterHint => 'Search collections...';

  @override
  String get collectionSelect_noCollections => 'No collections';

  @override
  String get collectionSelect_createCollectionHint =>
      'Create a collection first';

  @override
  String get collectionSelect_noFilterResults =>
      'No matching collections found';

  @override
  String collectionSelect_imageCount(int count) {
    return '$count images';
  }

  @override
  String get statistics_chartTopTags => 'Top Tags';

  @override
  String get statistics_chartAspectRatio => 'Aspect Ratio Distribution';

  @override
  String get statistics_chartActivityHeatmap => 'Activity Heatmap';

  @override
  String get statistics_chartHourlyDistribution => 'Hourly Distribution';

  @override
  String get statistics_chartWeekdayDistribution => 'Weekday Distribution';

  @override
  String get statistics_aspectSquare => 'Square';

  @override
  String get statistics_aspectLandscape => 'Landscape';

  @override
  String get statistics_aspectPortrait => 'Portrait';

  @override
  String get statistics_aspectOther => 'Other';

  @override
  String get statistics_refresh => 'Refresh';

  @override
  String get statistics_retry => 'Retry';

  @override
  String statistics_error(Object error) {
    return 'Error: $error';
  }

  @override
  String get statistics_mostActiveDay => 'Most Active Day';

  @override
  String get statistics_leastActiveDay => 'Least Active Day';

  @override
  String get statistics_sunday => 'Sun';

  @override
  String get statistics_monday => 'Mon';

  @override
  String get statistics_tuesday => 'Tue';

  @override
  String get statistics_wednesday => 'Wed';

  @override
  String get statistics_thursday => 'Thu';

  @override
  String get statistics_friday => 'Fri';

  @override
  String get statistics_saturday => 'Sat';

  @override
  String get fixedTags_label => 'Fixed Tags';

  @override
  String get fixedTags_enabled => 'Enabled';

  @override
  String get fixedTags_empty => 'No fixed tags';

  @override
  String get fixedTags_emptyHint =>
      'Click the button below to add fixed tags, they will be automatically applied to your prompts';

  @override
  String get fixedTags_manage => 'Manage Fixed Tags';

  @override
  String get fixedTags_add => 'Add';

  @override
  String get fixedTags_edit => 'Edit Fixed Tag';

  @override
  String get fixedTags_openLibrary => 'Open Library';

  @override
  String get fixedTags_prefix => 'Prefix';

  @override
  String get fixedTags_suffix => 'Suffix';

  @override
  String get fixedTags_disabled => 'Disabled';

  @override
  String get fixedTags_weight => 'Weight';

  @override
  String get fixedTags_position => 'Position';

  @override
  String get fixedTags_name => 'Name';

  @override
  String get fixedTags_nameHint => 'Enter a display name (optional)';

  @override
  String get fixedTags_content => 'Content';

  @override
  String get fixedTags_contentHint =>
      'Enter prompt content, NAI syntax supported';

  @override
  String get fixedTags_syntaxHelp =>
      'Supports NAI syntax for weight enhancement/reduction and tag alternation';

  @override
  String get fixedTags_linkedFromLibrary =>
      'Linked from library (two-way sync)';

  @override
  String get fixedTags_scope => 'Scope';

  @override
  String get fixedTags_positive => 'Prompt';

  @override
  String get fixedTags_negative => 'Undesired Content';

  @override
  String get fixedTags_resetWeight => 'Reset to 1.0';

  @override
  String get fixedTags_weightPreview => 'Weight preview:';

  @override
  String get fixedTags_deleteTitle => 'Delete Fixed Tag';

  @override
  String fixedTags_deleteConfirm(Object name) {
    return 'Are you sure you want to delete \"$name\"?';
  }

  @override
  String fixedTags_enabledCount(Object enabled, Object total) {
    return '$enabled/$total enabled';
  }

  @override
  String get fixedTags_saveToLibrary => 'Also save to library';

  @override
  String get fixedTags_saveToLibraryHint =>
      'For reuse in the tag library later';

  @override
  String get fixedTags_saveToCategory => 'Save to category';

  @override
  String get fixedTags_clearAll => 'Clear All';

  @override
  String get fixedTags_clearAllTitle => 'Clear All Fixed Tags';

  @override
  String fixedTags_clearAllConfirm(Object count) {
    return 'Are you sure you want to clear all $count fixed tags? This action cannot be undone.';
  }

  @override
  String get fixedTags_clearedSuccess => 'All fixed tags cleared';

  @override
  String get fixedTags_sidebarTitle => 'Fixed Tags Sidebar';

  @override
  String get fixedTags_switchGridView => 'Switch to Grid View';

  @override
  String get fixedTags_switchListView => 'Switch to List View';

  @override
  String get fixedTags_addPositive => 'Add Prompt Fixed Tag';

  @override
  String get fixedTags_addNegative => 'Add Undesired Content Fixed Tag';

  @override
  String get fixedTags_addPositiveFromLibrary => 'Add Prompt from Library';

  @override
  String get fixedTags_addNegativeFromLibrary =>
      'Add Undesired Content from Library';

  @override
  String get fixedTags_searchNameOrContent => 'Search name or content';

  @override
  String get fixedTags_clearSearch => 'Clear Search';

  @override
  String get fixedTags_enabledPositive => 'Enabled Prompt';

  @override
  String get fixedTags_emptyEnabledPositive => 'No enabled prompt fixed tags';

  @override
  String get fixedTags_noMatchingEnabled => 'No matching enabled fixed tags';

  @override
  String get fixedTags_negativeTitle => 'Undesired Content Fixed Tags';

  @override
  String get fixedTags_emptyNegative => 'No Undesired Content fixed tags';

  @override
  String get fixedTags_noMatchingNegative =>
      'No matching Undesired Content fixed tags';

  @override
  String get fixedTags_addedToSidebar => 'Added to fixed tags sidebar';

  @override
  String get fixedTags_unknownCategory => 'Unknown Category';

  @override
  String get fixedTags_uncategorized => 'Uncategorized';

  @override
  String get fixedTags_clickManageLongPressSidebar =>
      'Click to manage, long-press to open sidebar';

  @override
  String get fixedTags_clickManageLongPressCompact =>
      'Click to manage, long-press sidebar';

  @override
  String get fixedTags_linked => 'Linked';

  @override
  String fixedTags_linkCount(Object count) {
    return '$count linked';
  }

  @override
  String get fixedTags_expandNegative => 'Expand Undesired Content';

  @override
  String get fixedTags_collapseNegative => 'Collapse Undesired Content';

  @override
  String get fixedTags_undoTooltip => 'Undo fixed tag operation';

  @override
  String get fixedTags_redoTooltip => 'Redo fixed tag operation';

  @override
  String get fixedTags_positiveTitle => 'Prompt Fixed Tags';

  @override
  String fixedTags_columnCount(Object enabled, Object total) {
    return '$enabled/$total';
  }

  @override
  String fixedTags_columnFilteredCount(
    Object enabled,
    Object total,
    Object shown,
  ) {
    return '$enabled/$total · showing $shown';
  }

  @override
  String get fixedTags_new => 'New';

  @override
  String fixedTags_newTarget(Object target) {
    return 'New $target';
  }

  @override
  String get fixedTags_library => 'Library';

  @override
  String fixedTags_addFromLibraryToTarget(Object target) {
    return 'Add from library to $target';
  }

  @override
  String get fixedTags_enableAll => 'Enable All';

  @override
  String get fixedTags_disableAll => 'Disable All';

  @override
  String fixedTags_searchTarget(Object target) {
    return 'Search $target...';
  }

  @override
  String get fixedTags_noMatching => 'No matching fixed tags';

  @override
  String fixedTags_emptyTarget(Object target) {
    return 'No $target';
  }

  @override
  String get fixedTags_dragToLink => 'Drag to create link';

  @override
  String fixedTags_linkedToNames(Object names) {
    return 'Linked: $names';
  }

  @override
  String get fixedTags_linkInstruction =>
      'Drag the link icon from a prompt fixed tag to an Undesired Content fixed tag to create a link';

  @override
  String get fixedTags_manageLinks => 'Manage Links';

  @override
  String fixedTags_removeLink(Object name) {
    return 'Remove link: $name';
  }

  @override
  String get fixedTags_footerExpandedHint =>
      'Create or add from the library at the top of each column';

  @override
  String get fixedTags_newPositive => 'New Prompt';

  @override
  String get fixedTags_addPositiveFromLibraryShort => 'Add Prompt from Library';

  @override
  String get fixedTags_libraryEmpty => 'Library is empty. Add entries first';

  @override
  String get fixedTags_addFromLibrary => 'Add from Library';

  @override
  String get fixedTags_searchLibraryEntries => 'Search library entries...';

  @override
  String get fixedTags_noMatchingResults => 'No matching results';

  @override
  String get reversePrompt_title => 'Reverse Prompt';

  @override
  String get reversePrompt_pending => 'Pending';

  @override
  String reversePrompt_imageCount(Object count) {
    return '$count image(s)';
  }

  @override
  String get reversePrompt_llmReverse => 'LLM Reverse';

  @override
  String get reversePrompt_characterReplace => 'Character Replace';

  @override
  String get reversePrompt_finalResult => 'Final Result';

  @override
  String get reversePrompt_dropToAdd => 'Release to add to reverse prompt';

  @override
  String get reversePrompt_addOrDropImages => 'Add images / drop images';

  @override
  String get reversePrompt_localTaggerModel => 'Local tagger model';

  @override
  String get reversePrompt_localTaggerModelHint =>
      'Configure model folder in Settings';

  @override
  String get reversePrompt_generalThreshold => 'General tag threshold';

  @override
  String get reversePrompt_characterThreshold => 'Character tag threshold';

  @override
  String get reversePrompt_taggerFilterHint =>
      'Only General / Character tags are output. Rating, Artist, Copyright, Meta, and other categories are filtered.';

  @override
  String get reversePrompt_replacementEmptyHint =>
      'No replacement target character selected. Choose a character from the tag library here; it will not be injected into the prompt.';

  @override
  String get reversePrompt_selectReplacementCharacter =>
      'Choose replacement target character from library';

  @override
  String get reversePrompt_selectReplacementTargetTitle =>
      'Choose Replacement Target Character';

  @override
  String get reversePrompt_change => 'Change';

  @override
  String get reversePrompt_start => 'Start Reverse Prompt';

  @override
  String get reversePrompt_sentToPrompt => 'Sent to prompt';

  @override
  String get reversePrompt_sendToPrompt => 'Send to Prompt';

  @override
  String get reversePrompt_externalTarget =>
      'multimodal LLM reverse prompt service';

  @override
  String get reversePrompt_dropUnreadable =>
      'The dropped source did not provide a readable image file or image URL';

  @override
  String get reversePrompt_needImageAndMethod =>
      'Add an image and enable at least ONNX tagger or LLM reverse prompt';

  @override
  String get reversePrompt_stagePreparing => 'Preparing reverse prompt';

  @override
  String get reversePrompt_stageOnnxTagger => 'ONNX tagger reverse prompting';

  @override
  String get reversePrompt_stageLlmReverse => 'LLM image reverse prompting';

  @override
  String get reversePrompt_stageCharacterReplace => 'Replacing character';

  @override
  String get reversePrompt_needReplacementCharacter =>
      'Choose a valid character from the reverse-prompt character library first';

  @override
  String get reversePrompt_needPromptForCharacterReplace =>
      'Character replacement requires a reverse-prompt result first';

  @override
  String get reversePrompt_noOnnxModel =>
      'No ONNX tagger model found. Configure the model folder in Settings first';

  @override
  String get promptAssistant_translateProcessing => 'Translating';

  @override
  String get promptAssistant_optimizeProcessing => 'Optimizing';

  @override
  String get promptAssistant_characterReplaceProcessing =>
      'Replacing character';

  @override
  String get promptAssistant_customProcessing => 'Processing custom request';

  @override
  String get promptAssistant_imageInputDisabled =>
      'The current custom-task provider does not have image input enabled';

  @override
  String get promptAssistant_needCharacter =>
      'Add a valid character in the reverse-prompt character library first';

  @override
  String get promptAssistant_assistantSettings => 'Assistant Settings';

  @override
  String get promptAssistant_serviceSettings => 'Service Settings';

  @override
  String get promptAssistant_ruleSettings => 'Rule Settings';

  @override
  String get promptAssistant_cancelCurrentTask => 'Cancel Current Task';

  @override
  String get promptAssistant_collapseAssistant => 'Collapse Assistant';

  @override
  String get promptAssistant_expandAssistant => 'Expand Assistant';

  @override
  String get promptAssistant_history => 'History';

  @override
  String get promptAssistant_undo => 'Undo';

  @override
  String get promptAssistant_redo => 'Redo';

  @override
  String get promptAssistant_translate => 'Translate';

  @override
  String get promptAssistant_optimize => 'Optimize';

  @override
  String get promptAssistant_custom => 'Custom';

  @override
  String get promptAssistant_characterReplace => 'Character Replace';

  @override
  String get promptAssistant_cancelTask => 'Cancel Task';

  @override
  String get promptAssistant_menu => 'Menu';

  @override
  String get promptAssistant_customDialogTitle => 'Custom Prompt Assistant';

  @override
  String get promptAssistant_currentPrompt => 'Current Prompt';

  @override
  String get promptAssistant_currentPromptEmpty => '(current prompt is empty)';

  @override
  String get promptAssistant_customRequestLabel => 'Your modification request';

  @override
  String get promptAssistant_customRequestHint =>
      'For example: make it more ominous, add a rainy night street background, make the action more dynamic, return only the final prompt';

  @override
  String get promptAssistant_addReferenceImage => 'Add Reference Image';

  @override
  String get promptAssistant_execute => 'Run';

  @override
  String promptAssistant_maxReferenceImages(Object count) {
    return 'Add up to $count reference images';
  }

  @override
  String promptAssistant_unsupportedImageFormat(Object fileName) {
    return 'Unsupported image format: $fileName';
  }

  @override
  String get promptAssistant_needCustomRequestOrImage =>
      'Enter a custom request or add a reference image';

  @override
  String get promptAssistant_taskOptimize => 'Optimize';

  @override
  String get promptAssistant_taskTranslate => 'Translate';

  @override
  String get promptAssistant_taskReverse => 'Reverse Prompt';

  @override
  String get promptAssistant_taskCharacterReplace => 'Character Replace';

  @override
  String get promptAssistant_taskCustom => 'Custom';

  @override
  String get promptAssistant_settingsInputSwitchSubtitle =>
      'Assistant switch in the bottom-right of the prompt input';

  @override
  String get promptAssistant_desktopOverlayTitle =>
      'Desktop Overlay Interaction';

  @override
  String get promptAssistant_desktopOverlaySubtitle =>
      'Enable hover, right-click, and shortcut behavior';

  @override
  String get promptAssistant_taskRouting => 'Task Routing';

  @override
  String get promptAssistant_taskRoutingSubtitle =>
      'Bind optimize, translate, reverse prompt, and character replacement to different providers and models';

  @override
  String promptAssistant_taskRouteTitle(Object title) {
    return '$title Task';
  }

  @override
  String get promptAssistant_provider => 'Provider';

  @override
  String get promptAssistant_model => 'Model';

  @override
  String get promptAssistant_noModelsPullFirst =>
      'No models yet. Pull the model list first';

  @override
  String get promptAssistant_providerManagement => 'Provider Management';

  @override
  String get promptAssistant_providerManagementSubtitle =>
      'Supports OpenAI Chat / Responses, Anthropic, Gemini, DeepSeek, LM Studio, Ollama, Pollinations, and custom compatible endpoints';

  @override
  String get promptAssistant_apiKeyConfigured => 'API Key: configured';

  @override
  String get promptAssistant_apiKeyNotConfigured => 'API Key: not configured';

  @override
  String get promptAssistant_supportsImageInput => 'Supports image input';

  @override
  String get promptAssistant_textOnly => 'Text only';

  @override
  String get promptAssistant_connectionConfig => 'Connection Config';

  @override
  String get promptAssistant_pullModelList => 'Pull model list';

  @override
  String get promptAssistant_editProvider => 'Edit provider';

  @override
  String get promptAssistant_deleteProvider => 'Delete provider';

  @override
  String get promptAssistant_pullingModels => 'Pulling model list...';

  @override
  String get promptAssistant_emptyModelList =>
      'Provider returned an empty model list';

  @override
  String promptAssistant_modelsSynced(Object count) {
    return 'Synced $count models';
  }

  @override
  String promptAssistant_pullModelsFailed(Object error) {
    return 'Failed to pull models: $error';
  }

  @override
  String get promptAssistant_ruleTemplates => 'Rule Templates';

  @override
  String get promptAssistant_ruleTemplatesSubtitle =>
      'System prompts are assembled as rules + user input + task parameters';

  @override
  String get promptAssistant_addRule => 'Add Rule';

  @override
  String get promptAssistant_addProvider => 'Add Provider';

  @override
  String get promptAssistant_editProviderTitle => 'Edit Provider';

  @override
  String get promptAssistant_name => 'Name';

  @override
  String get promptAssistant_protocol => 'Protocol';

  @override
  String get promptAssistant_allowImageInput => 'Allow image input';

  @override
  String get promptAssistant_allowImageInputSubtitle =>
      'Enable only when the model and provider actually support vision input';

  @override
  String get promptAssistant_apiKeyLeaveEmpty =>
      'API Key (leave empty to keep unchanged)';

  @override
  String promptAssistant_connectionTitle(Object name) {
    return '$name Connection Config';
  }

  @override
  String get promptAssistant_baseUrlHint =>
      'Example: https://api.openai.com/v1';

  @override
  String get promptAssistant_clearCurrentApiKey => 'Clear current API Key';

  @override
  String get promptAssistant_protocolSupportsImagePayload =>
      'The current protocol supports image payloads; the model itself must still support vision input';

  @override
  String get promptAssistant_protocolTextOnlyWarning =>
      'The current protocol is text-only by default; enabling this may still be rejected by the server';

  @override
  String get promptAssistant_addRuleTitle => 'Add Rule';

  @override
  String get promptAssistant_editRuleTitle => 'Edit Rule';

  @override
  String get promptAssistant_taskType => 'Task Type';

  @override
  String get promptAssistant_ruleContent => 'Rule Content';

  @override
  String get promptAssistant_newRule => 'New Rule';

  @override
  String autocomplete_resultsCount(Object count) {
    return '$count results';
  }

  @override
  String get autocomplete_keyNavigate => '↑↓/Scroll';

  @override
  String get autocomplete_actionSelect => 'Select';

  @override
  String get autocomplete_actionConfirm => 'Confirm';

  @override
  String get autocomplete_actionClose => 'Close';

  @override
  String get autocomplete_categoryRecommended => 'Recommended';

  @override
  String get autocomplete_categoryCharacter => 'Character';

  @override
  String get autocomplete_categoryCopyright => 'Copyright';

  @override
  String get autocomplete_categoryArtist => 'Artist';

  @override
  String get autocomplete_categoryMeta => 'Meta';

  @override
  String get autocomplete_categoryContributor => 'Contributor';

  @override
  String get autocomplete_categorySpecies => 'Species';

  @override
  String get autocomplete_categoryLore => 'Lore';

  @override
  String get autocomplete_categoryLibrary => 'Library';

  @override
  String get autocomplete_categoryGeneral => 'General';

  @override
  String get promptToken_webCalibration => 'Web calibration';

  @override
  String get promptToken_prompt => 'Prompt';

  @override
  String get promptToken_fixedTags => 'Fixed Tags';

  @override
  String get promptToken_qualityPreset => 'Quality Preset';

  @override
  String get promptToken_character => 'Character';

  @override
  String get promptToken_negativePrompt => 'Undesired Content';

  @override
  String get promptToken_negativeFixedTags => 'Undesired Content Fixed Tags';

  @override
  String get promptToken_negativePreset => 'Undesired Content Preset';

  @override
  String get promptToken_characterNegative => 'Character Undesired Content';

  @override
  String get common_rename => 'Rename';

  @override
  String get common_create => 'Create';

  @override
  String get tagLibrary_categories => 'Categories';

  @override
  String get tagLibrary_newCategory => 'New Category';

  @override
  String get tagLibrary_addEntry => 'Add Entry';

  @override
  String get tagLibrary_editEntry => 'Edit Entry';

  @override
  String get tagLibrary_searchHint => 'Search entries...';

  @override
  String get tagLibrary_import => 'Import';

  @override
  String get tagLibrary_export => 'Export';

  @override
  String get tagLibrary_sortCustom => 'Custom Sort';

  @override
  String get tagLibrary_sortName => 'Name';

  @override
  String get tagLibrary_sortUseCount => 'Usage';

  @override
  String get tagLibrary_sortUpdatedAt => 'Updated';

  @override
  String get tagLibrary_transferCategory => 'Move Category';

  @override
  String get tagLibrary_copyContent => 'Copy Content';

  @override
  String get tagLibrary_moveToCategoryTitle => 'Move to Category';

  @override
  String get tagLibrary_selectTargetCategory => 'Select target category:';

  @override
  String get tagLibrary_includeThumbnails => 'Include thumbnails';

  @override
  String get tagLibrary_includeThumbnailsSubtitle => 'Increases file size';

  @override
  String tagLibrary_selectedExportCount(Object count) {
    return 'Export ($count items)';
  }

  @override
  String tagLibrary_selectedImportCount(Object count) {
    return 'Import ($count items)';
  }

  @override
  String get tagLibrary_entriesLabel => 'Entries';

  @override
  String get tagLibrary_categoriesLabel => 'Categories';

  @override
  String get tagLibrary_selectExportContent => 'Select content to export';

  @override
  String get tagLibrary_selectImportContent => 'Select content to import';

  @override
  String get tagLibrary_selectSaveLocation => 'Select save location';

  @override
  String get tagLibrary_preparingExport => 'Preparing export...';

  @override
  String get tagLibrary_exportSuccess => 'Export successful';

  @override
  String tagLibrary_exportFailedWithError(Object error) {
    return 'Export failed: $error';
  }

  @override
  String get tagLibrary_selectZipFile => 'Click to select ZIP file';

  @override
  String get tagLibrary_zipFileHint =>
      'Supports library files exported from this app';

  @override
  String get tagLibrary_reselect => 'Select Again';

  @override
  String get tagLibrary_fileInfo => 'File Info';

  @override
  String get tagLibrary_entryCountLabel => 'Entries';

  @override
  String get tagLibrary_categoryCountLabel => 'Categories';

  @override
  String get tagLibrary_exportDateLabel => 'Export Date';

  @override
  String tagLibrary_importConflictsHint(Object count) {
    return '$count conflicts found. Click a conflicted item below to choose how to handle it.';
  }

  @override
  String tagLibrary_categoriesSection(Object count) {
    return 'Categories ($count)';
  }

  @override
  String tagLibrary_entriesSection(Object count) {
    return 'Entries ($count)';
  }

  @override
  String get tagLibrary_conflictResolutionTooltip => 'Choose conflict handling';

  @override
  String get tagLibrary_conflictSkip => 'Conflict - will skip';

  @override
  String get tagLibrary_conflictRename =>
      'Conflict - will import with renamed name';

  @override
  String get tagLibrary_conflictOverwrite => 'Conflict - will replace existing';

  @override
  String tagLibrary_parseFileFailed(Object error) {
    return 'Unable to parse file: $error';
  }

  @override
  String get tagLibrary_preparingImport => 'Preparing import...';

  @override
  String get tagLibrary_importCompleted => 'Import complete';

  @override
  String tagLibrary_importSuccessSummary(Object summary) {
    return 'Import successful: $summary';
  }

  @override
  String tagLibrary_importFailedWithError(Object error) {
    return 'Import failed: $error';
  }

  @override
  String tagLibrary_importedEntriesCount(Object count) {
    return '$count entries';
  }

  @override
  String tagLibrary_importedCategoriesCount(Object count) {
    return '$count categories';
  }

  @override
  String tagLibrary_renamedCount(Object count) {
    return '$count renamed';
  }

  @override
  String tagLibrary_overwrittenCount(Object count) {
    return '$count replaced';
  }

  @override
  String tagLibrary_skippedCount(Object count) {
    return '$count skipped';
  }

  @override
  String get tagLibrary_dragToCategoryHint =>
      'Drag to the category panel to file';

  @override
  String get tagLibrary_unknownCategory => 'Unknown Category';

  @override
  String get tagLibrary_selectEntryToUpdate => 'Select Entry to Update';

  @override
  String get tagLibrary_updatePreview => 'Update Preview';

  @override
  String get tagLibrary_replaceThumbnailHint =>
      'Will replace existing thumbnail';

  @override
  String tagLibrary_sentEntriesToMainPrompt(Object count) {
    return 'Sent $count entries to main prompt';
  }

  @override
  String tagLibrary_confirmDeleteSelectedEntries(Object count) {
    return 'Delete $count selected entries? This action cannot be undone.';
  }

  @override
  String tagLibrary_deletedEntries(Object count) {
    return 'Deleted $count entries';
  }

  @override
  String tagLibrary_movedEntries(Object count) {
    return 'Moved $count entries';
  }

  @override
  String tagLibrary_favoritedEntries(Object count) {
    return 'Favorited $count entries';
  }

  @override
  String tagLibrary_unfavoritedEntries(Object count) {
    return 'Unfavorited $count entries';
  }

  @override
  String tagLibrary_copiedEntriesContent(Object count) {
    return 'Copied content from $count entries';
  }

  @override
  String get tagLibrary_droppedImage => 'Dropped Image';

  @override
  String get tagLibrary_createEntryFromImage => 'Create New Entry';

  @override
  String tagLibrary_promptExtracted(Object prompt) {
    return 'Prompt extracted: \"$prompt\"';
  }

  @override
  String get tagLibrary_createEntryFromImageSubtitle =>
      'Create a new entry from this image';

  @override
  String get tagLibrary_updateExistingThumbnail =>
      'Update Existing Entry Thumbnail';

  @override
  String get tagLibrary_updateExistingThumbnailSubtitle =>
      'Select an entry and replace its thumbnail';

  @override
  String get tagLibrary_allEntries => 'All';

  @override
  String get tagLibrary_favorites => 'Favorites';

  @override
  String get tagLibrary_addSubCategory => 'Add Subcategory';

  @override
  String get tagLibrary_moveToRoot => 'Move to Root';

  @override
  String get tagLibrary_categoryNameHint => 'Enter category name';

  @override
  String get tagLibrary_deleteCategoryTitle => 'Delete Category';

  @override
  String tagLibrary_deleteCategoryConfirm(Object name, Object count) {
    return 'Are you sure you want to delete category \"$name\"? $count entries will be moved to root.';
  }

  @override
  String get tagLibrary_deleteEntryTitle => 'Delete Entry';

  @override
  String tagLibrary_deleteEntryConfirm(Object name) {
    return 'Are you sure you want to delete entry \"$name\"?';
  }

  @override
  String get tagLibrary_noSearchResults => 'No matching entries found';

  @override
  String get tagLibrary_tryDifferentSearch => 'Try different keywords';

  @override
  String get tagLibrary_categoryEmpty => 'This category is empty';

  @override
  String get tagLibrary_empty => 'Library is empty';

  @override
  String get tagLibrary_addFirstEntry =>
      'Click the button above to add your first entry';

  @override
  String get tagLibraryPicker_title => 'Select Entry';

  @override
  String get tagLibraryPicker_searchHint => 'Search entries...';

  @override
  String get tagLibraryPicker_allCategories => 'All Categories';

  @override
  String get tagLibrary_addedToFixed => 'Added to Fixed Tags';

  @override
  String get tagLibrary_entryMoved => 'Entry moved to target category';

  @override
  String get tagLibrary_addFavorite => 'Add to Favorites';

  @override
  String get tagLibrary_thumbnail => 'Thumbnail';

  @override
  String get tagLibrary_selectImage => 'Select Image';

  @override
  String get tagLibrary_thumbnailHint =>
      'Supports PNG, JPG, WEBP, GIF, BMP, TIFF, and more';

  @override
  String get tagLibrary_name => 'Name';

  @override
  String get tagLibrary_nameHint => 'Enter entry name';

  @override
  String get tagLibrary_category => 'Category';

  @override
  String get tagLibrary_rootCategory => 'Root';

  @override
  String get tagLibrary_tags => 'Tags';

  @override
  String get tagLibrary_tagsHint => 'Enter tags, separated by commas';

  @override
  String get tagLibrary_tagsHelper =>
      'Tags are used for filtering and searching';

  @override
  String get tagLibrary_content => 'Prompt Content';

  @override
  String get tagLibrary_contentHint =>
      'Enter prompt content, supports autocomplete';

  @override
  String get settings_network => 'Network';

  @override
  String get settings_enableProxy => 'Enable Proxy';

  @override
  String get settings_proxyEnabled => 'Enabled';

  @override
  String get settings_proxyDisabled => 'Direct connection';

  @override
  String get settings_proxyTrafficDisclosure =>
      'When proxy is enabled, NovelAI API traffic, including authentication requests, is sent through the system or manual proxy. Use only proxies you trust.';

  @override
  String get settings_proxyMode => 'Proxy Mode';

  @override
  String get settings_proxyModeAuto => 'Auto-detect system proxy';

  @override
  String get settings_proxyModeManual => 'Manual configuration';

  @override
  String get settings_auto => 'Auto';

  @override
  String get settings_manual => 'Manual';

  @override
  String get settings_proxyHost => 'Proxy Host';

  @override
  String get settings_proxyPort => 'Port';

  @override
  String get settings_proxyNotDetected => 'No system proxy detected';

  @override
  String get settings_testConnection => 'Test Connection';

  @override
  String get settings_testConnectionHint => 'Click to test if proxy is working';

  @override
  String settings_testSuccess(Object latency) {
    return 'Connection successful (${latency}ms)';
  }

  @override
  String settings_testFailed(Object error) {
    return 'Connection failed: $error';
  }

  @override
  String get settings_proxyRestartHint =>
      'Proxy settings changed, restart recommended';

  @override
  String get tagLibrary_categoryNameExists => 'Category name already exists';

  @override
  String get tagLibrary_addToLibrary => 'Add to Library';

  @override
  String get tagLibrary_saveToLibrary => 'Save to Library';

  @override
  String get tagLibrary_entrySaved => 'Saved to library';

  @override
  String get tagLibrary_entryUpdated => 'Entry updated';

  @override
  String get tagLibrary_uncategorized => 'Uncategorized';

  @override
  String get tagLibrary_contentPreview => 'Content Preview';

  @override
  String get tagLibrary_confirmAdd => 'Confirm';

  @override
  String get tagLibrary_entryName => 'Name';

  @override
  String get tagLibrary_entryNameHint => 'Enter entry name';

  @override
  String get tagLibrary_selectNewImage => 'Select New Image';

  @override
  String get tagLibrary_adjustDisplayRange => 'Adjust Display Range';

  @override
  String get tagLibrary_adjustThumbnailTitle =>
      'Adjust Thumbnail Display Range';

  @override
  String get tagLibrary_dragToMove => 'Drag to move, scroll or pinch to zoom';

  @override
  String get queue_management => 'Queue Management';

  @override
  String get queue_empty => 'Queue is empty';

  @override
  String get queue_emptyHint => 'No tasks in the queue';

  @override
  String get queue_pending => 'Pending';

  @override
  String get queue_running => 'Running';

  @override
  String get queue_completed => 'Completed';

  @override
  String get queue_failed => 'Failed';

  @override
  String get queue_paused => 'Paused';

  @override
  String get queue_idle => 'Idle';

  @override
  String get queue_ready => 'Ready';

  @override
  String get queue_noTasksToStart => 'Queue is empty, cannot start';

  @override
  String get queue_executionProgress => 'Execution Progress';

  @override
  String get queue_totalTasks => 'Total';

  @override
  String get queue_completedTasks => 'Completed';

  @override
  String get queue_failedTasks => 'Failed';

  @override
  String get queue_remainingTasks => 'Remaining';

  @override
  String queue_estimatedTime(Object time) {
    return 'Estimated: about $time';
  }

  @override
  String queue_seconds(Object count) {
    return '$count seconds';
  }

  @override
  String queue_minutes(Object count) {
    return '$count minutes';
  }

  @override
  String queue_hours(Object hours, Object minutes) {
    return '$hours hours $minutes minutes';
  }

  @override
  String get queue_pause => 'Pause';

  @override
  String get queue_resume => 'Resume';

  @override
  String get queue_startExecution => 'Start Queue';

  @override
  String get queue_pauseExecution => 'Pause Queue';

  @override
  String get queue_resumeExecution => 'Resume Queue';

  @override
  String get queue_generationBusy =>
      'Another generation task is running. Start the queue after it finishes';

  @override
  String get queue_clearQueue => 'Clear Queue';

  @override
  String get queue_clearQueueConfirm =>
      'Are you sure you want to clear all queue tasks? This action cannot be undone.';

  @override
  String get queue_confirmClear => 'Confirm Clear';

  @override
  String queue_retryCount(Object current, Object max) {
    return 'Retry $current/$max';
  }

  @override
  String get queue_retry => 'Retry';

  @override
  String get queue_requeue => 'Requeue';

  @override
  String get queue_clearFailedTasks => 'Clear All';

  @override
  String get queue_noFailedTasks => 'No failed tasks';

  @override
  String get queue_noCompletedTasks => 'No completed records';

  @override
  String get queue_editTask => 'Edit Task';

  @override
  String get queue_duplicateTask => 'Duplicate Task';

  @override
  String get queue_taskDuplicated => 'Task duplicated';

  @override
  String get queue_queueFull => 'Queue is full, cannot duplicate';

  @override
  String get queue_positivePrompt => 'Prompt';

  @override
  String get queue_enterPositivePrompt => 'Enter prompt...';

  @override
  String get queue_parametersPreview => 'Parameters Preview';

  @override
  String get queue_model => 'Model';

  @override
  String get queue_seed => 'Seed';

  @override
  String get queue_sampler => 'Sampler';

  @override
  String get queue_steps => 'Steps';

  @override
  String get queue_cfg => 'CFG';

  @override
  String get queue_size => 'Size';

  @override
  String get queue_addCurrentTask => 'Add Current Task';

  @override
  String get queue_taskAdded => 'Added to queue';

  @override
  String get queue_negativePromptFromMain =>
      'Undesired Content will use main page settings';

  @override
  String get queue_pinToTop => 'Pin to Top';

  @override
  String get queue_delete => 'Delete';

  @override
  String get queue_edit => 'Edit';

  @override
  String get queue_selectAll => 'Select All';

  @override
  String get queue_invertSelection => 'Invert';

  @override
  String get queue_cancelSelection => 'Cancel';

  @override
  String queue_selectedCount(Object count) {
    return '$count selected';
  }

  @override
  String queue_confirmDeleteSelected(Object count) {
    return 'Are you sure you want to delete $count selected tasks?';
  }

  @override
  String get queue_export => 'Export';

  @override
  String get queue_import => 'Import';

  @override
  String get queue_exportImport => 'Import/Export Queue';

  @override
  String get queue_exportFormat => 'Export Format';

  @override
  String get queue_exportFormatJson => 'JSON';

  @override
  String get queue_exportFormatJsonDesc => 'Complete data with all parameters';

  @override
  String get queue_exportFormatCsv => 'CSV';

  @override
  String get queue_exportFormatCsvDesc =>
      'Table format with prompts and basic info';

  @override
  String get queue_exportFormatText => 'Plain Text';

  @override
  String get queue_exportFormatTextDesc => 'Prompts only, one per line';

  @override
  String get queue_importStrategy => 'Import Strategy';

  @override
  String get queue_importStrategyMerge => 'Merge';

  @override
  String get queue_importStrategyMergeDesc =>
      'Add imported tasks to end of existing queue';

  @override
  String get queue_importStrategyReplace => 'Replace';

  @override
  String get queue_importStrategyReplaceDesc =>
      'Clear existing queue and replace with imported';

  @override
  String get queue_supportedFormats => 'Supported formats:';

  @override
  String get queue_supportedFormatJson => '• JSON file (.json)';

  @override
  String get queue_supportedFormatCsv => '• CSV file (.csv)';

  @override
  String get queue_supportedFormatText =>
      '• Plain text file (.txt) - one prompt per line';

  @override
  String get queue_shareSubject => 'Queue Export';

  @override
  String queue_unsupportedFileFormat(Object extension) {
    return 'Unsupported file format: $extension';
  }

  @override
  String get queue_exportSuccess => 'Export successful';

  @override
  String queue_exportFailed(Object error) {
    return 'Export failed: $error';
  }

  @override
  String queue_importSuccess(Object count) {
    return 'Successfully imported $count tasks';
  }

  @override
  String queue_importFailed(Object error) {
    return 'Import failed: $error';
  }

  @override
  String get queue_selectFile => 'Select file to import';

  @override
  String get queue_noValidTasks => 'No valid tasks in file';

  @override
  String get settings_queueRetryCount => 'Retry Count';

  @override
  String get settings_queueRetryInterval => 'Retry Interval';

  @override
  String get settings_showRandomPromptTools => 'Show random prompt tools';

  @override
  String get settings_showRandomPromptToolsSubtitle =>
      'Show the Random Prompt button and Random Mode toggle on the generation page';

  @override
  String get settings_enablePromptWeightScroll =>
      'Adjust prompt weight with mouse wheel';

  @override
  String get settings_enablePromptWeightScrollSubtitle =>
      'When prompt text is selected, use the wheel only to adjust its weight and suppress other scroll actions.';

  @override
  String settings_queueRetryCountMax(Object count) {
    return 'Max $count times';
  }

  @override
  String settings_queueRetryIntervalValue(Object seconds) {
    return '$seconds seconds';
  }

  @override
  String get unit_times => 'times';

  @override
  String get unit_seconds => 'seconds';

  @override
  String queue_currentQueueInfo(Object count) {
    return 'Current queue contains $count tasks';
  }

  @override
  String get settings_notificationSound => 'Completion Sound';

  @override
  String get settings_notificationSoundSubtitle =>
      'Play sound when generation completes';

  @override
  String get settings_notificationCustomSound => 'Custom Sound';

  @override
  String get settings_notificationSelectSound => 'Select Sound';

  @override
  String get settings_notificationResetSound => 'Reset to Default';

  @override
  String get categoryConfiguration => 'Category Configuration';

  @override
  String get resetToDefault => 'Reset to Default';

  @override
  String get resetToDefaultTooltip => 'Reset to default configuration';

  @override
  String get toggleGroupEnabled => 'Toggle group enabled state';

  @override
  String get diyNotAvailableForDefault =>
      'DIY not available for default preset';

  @override
  String get diyNotAvailableHint => 'Please copy to a custom preset to edit';

  @override
  String get statistics_heatmapLess => 'Less';

  @override
  String get statistics_heatmapMore => 'More';

  @override
  String statistics_heatmapActivities(Object count) {
    return '$count activities';
  }

  @override
  String get statistics_heatmapNoActivity => 'No activity';

  @override
  String get sendToHome_dialogTitle => 'Send to Home';

  @override
  String get sendToHome_send => 'Send';

  @override
  String get sendToHome_mainPrompt => 'Send to Main Prompt';

  @override
  String get sendToHome_mainPromptSubtitle =>
      'Fill into the main prompt input field';

  @override
  String get sendToHome_mainPromptPipeSubtitle =>
      'Send the full content to the main prompt (including pipes)';

  @override
  String get sendToHome_smartDecompose => 'Smart Decompose';

  @override
  String sendToHome_smartDecomposeSubtitle(Object count) {
    return 'Main prompt + $count characters';
  }

  @override
  String get sendToHome_replaceCharacter => 'Replace Character Prompt';

  @override
  String get sendToHome_replaceCharacterSubtitle =>
      'Clear existing characters and add as new';

  @override
  String get sendToHome_appendCharacter => 'Append Character Prompt';

  @override
  String get sendToHome_appendCharacterSubtitle =>
      'Keep existing characters and append new';

  @override
  String get sendToHome_fixedTags => 'Send to Fixed Tags';

  @override
  String get sendToHome_fixedTagsSubtitle => 'Append to the fixed tag list';

  @override
  String get sendToHome_sendAsAlias => 'Send as Alias';

  @override
  String sendToHome_sendAsAliasSubtitle(Object name) {
    return 'Wrap as <$name> when sending to home';
  }

  @override
  String get sendToHome_preview => 'Send Preview';

  @override
  String get sendToHome_characterPrompt => 'Character Prompt';

  @override
  String sendToHome_characterPromptCount(Object count) {
    return 'Character Prompt ($count)';
  }

  @override
  String sendToHome_characterIndex(Object index) {
    return 'Character $index';
  }

  @override
  String get sendToHome_recommended => 'Recommended';

  @override
  String get sendToHome_successMainPrompt => 'Sent to main prompt';

  @override
  String get sendToHome_successReplaceCharacter => 'Character prompt replaced';

  @override
  String get sendToHome_successAppendCharacter => 'Character prompt appended';

  @override
  String get metadataImport_title => 'Select Parameters to Import';

  @override
  String get metadataImport_promptsSection => 'Prompts';

  @override
  String get metadataImport_generationSection => 'Generation Parameters';

  @override
  String get metadataImport_selectAll => 'Select All';

  @override
  String get metadataImport_promptsOnly => 'Prompts Only';

  @override
  String get metadataImport_generationOnly => 'Parameters Only';

  @override
  String get metadataImport_clear => 'Clear';

  @override
  String get metadataImport_mainPrompt => 'Main Prompt';

  @override
  String get metadataImport_fixedTags => 'Fixed Tags';

  @override
  String metadataImport_fixedPrefix(Object text) {
    return 'Prefix: $text';
  }

  @override
  String metadataImport_fixedSuffix(Object text) {
    return 'Suffix: $text';
  }

  @override
  String metadataImport_negativeFixedPrefix(Object text) {
    return 'Undesired Content Prefix: $text';
  }

  @override
  String metadataImport_negativeFixedSuffix(Object text) {
    return 'Undesired Content Suffix: $text';
  }

  @override
  String metadataImport_qualityTagsCount(int count) {
    return 'Quality Tags ($count)';
  }

  @override
  String get metadataImport_negativePrompt => 'Undesired Content';

  @override
  String metadataImport_characterPromptsCount(int count) {
    return 'Character Prompts ($count)';
  }

  @override
  String metadataImport_characterIndex(int index, Object text) {
    return 'Character $index: $text';
  }

  @override
  String get metadataImport_referenceSection => 'References';

  @override
  String metadataImport_countUnit(int count) {
    return '$count';
  }

  @override
  String metadataImport_preciseReferenceCount(int count) {
    return 'Precise Reference ($count)';
  }

  @override
  String metadataImport_vibeDetail(Object name, Object strength, Object info) {
    return '$name (Reference Strength $strength%, Information Extracted $info%)';
  }

  @override
  String metadataImport_preciseReferenceDetail(
    int index,
    Object type,
    Object strength,
    Object fidelity,
  ) {
    return 'Reference $index: $type (strength $strength%, fidelity $fidelity%)';
  }

  @override
  String get metadataImport_noData => '(no data)';

  @override
  String metadataImport_selectedCount(int count) {
    return '$count selected';
  }

  @override
  String get metadataImport_noDataFound => 'No NovelAI metadata found';

  @override
  String get metadataImport_noParamsSelected => 'No parameters selected';

  @override
  String metadataImport_appliedCount(int count) {
    return 'Applied $count parameters';
  }

  @override
  String get shortcut_context_global => 'Global';

  @override
  String get shortcut_context_generation => 'Generation';

  @override
  String get shortcut_context_gallery => 'Gallery List';

  @override
  String get shortcut_context_viewer => 'Image Viewer';

  @override
  String get shortcut_context_tag_library => 'Tag Library';

  @override
  String get shortcut_context_random_config => 'Random Config';

  @override
  String get shortcut_context_settings => 'Settings';

  @override
  String get shortcut_context_input => 'Input Field';

  @override
  String get shortcut_action_navigate_to_generation => 'Generation Page';

  @override
  String get shortcut_action_navigate_to_local_gallery => 'Local Gallery';

  @override
  String get shortcut_action_navigate_to_online_gallery => 'Online Gallery';

  @override
  String get shortcut_action_navigate_to_random_config => 'Random Config';

  @override
  String get shortcut_action_navigate_to_tag_library => 'Tag Library';

  @override
  String get shortcut_action_navigate_to_statistics => 'Statistics';

  @override
  String get shortcut_action_navigate_to_settings => 'Settings';

  @override
  String get shortcut_action_generate_image => 'Generate Image';

  @override
  String get shortcut_action_generation_prev_image =>
      'Previous preview (linked history)';

  @override
  String get shortcut_action_generation_next_image =>
      'Next preview (linked history)';

  @override
  String get shortcut_action_cancel_generation => 'Cancel Generation';

  @override
  String get shortcut_action_add_to_queue => 'Add to Queue';

  @override
  String get shortcut_action_random_prompt => 'Random Prompt';

  @override
  String get shortcut_action_clear_prompt => 'Clear Prompt';

  @override
  String get shortcut_action_toggle_prompt_mode => 'Toggle Prompt Mode';

  @override
  String get shortcut_action_open_tag_library => 'Open Tag Library';

  @override
  String get shortcut_action_save_image => 'Save Image';

  @override
  String get shortcut_action_upscale_image => 'Upscale Image';

  @override
  String get shortcut_action_copy_image => 'Copy Image';

  @override
  String get shortcut_action_fullscreen_preview => 'Fullscreen Preview';

  @override
  String get shortcut_action_open_params_panel => 'Open Params Panel';

  @override
  String get shortcut_action_open_history_panel => 'Open History Panel';

  @override
  String get shortcut_action_reuse_params => 'Reuse Parameters';

  @override
  String get shortcut_action_previous_image => 'Previous Image';

  @override
  String get shortcut_action_next_image => 'Next Image';

  @override
  String get shortcut_action_zoom_in => 'Zoom In';

  @override
  String get shortcut_action_zoom_out => 'Zoom Out';

  @override
  String get shortcut_action_reset_zoom => 'Reset Zoom';

  @override
  String get shortcut_action_toggle_fullscreen => 'Toggle Fullscreen';

  @override
  String get shortcut_action_close_viewer => 'Close Viewer';

  @override
  String get shortcut_action_toggle_favorite => 'Toggle Favorite';

  @override
  String get shortcut_action_copy_prompt => 'Copy Prompt';

  @override
  String get shortcut_action_reuse_gallery_params => 'Reuse Parameters';

  @override
  String get shortcut_action_delete_image => 'Delete Image';

  @override
  String get shortcut_action_previous_page => 'Previous Page';

  @override
  String get shortcut_action_next_page => 'Next Page';

  @override
  String get shortcut_action_refresh_gallery => 'Refresh Gallery';

  @override
  String get shortcut_action_focus_search => 'Focus Search';

  @override
  String get shortcut_action_enter_selection_mode => 'Enter Selection Mode';

  @override
  String get shortcut_action_open_filter_panel => 'Open Filter Panel';

  @override
  String get shortcut_action_clear_filter => 'Clear Filter';

  @override
  String get shortcut_action_toggle_category_panel => 'Toggle Category Panel';

  @override
  String get shortcut_action_jump_to_date => 'Jump to Date';

  @override
  String get shortcut_action_open_folder => 'Open Folder';

  @override
  String get shortcut_action_select_all_tags => 'Select All Tags';

  @override
  String get shortcut_action_deselect_all_tags => 'Deselect All Tags';

  @override
  String get shortcut_action_new_category => 'New Category';

  @override
  String get shortcut_action_new_tag => 'New Tag';

  @override
  String get shortcut_action_search_tags => 'Search Tags';

  @override
  String get shortcut_action_batch_delete_tags => 'Batch Delete Tags';

  @override
  String get shortcut_action_batch_copy_tags => 'Batch Copy Tags';

  @override
  String get shortcut_action_send_to_home => 'Send to Home';

  @override
  String get shortcut_action_exit_selection_mode => 'Exit Selection Mode';

  @override
  String get shortcut_action_sync_danbooru => 'Sync Danbooru';

  @override
  String get shortcut_action_generate_preview => 'Generate Preview';

  @override
  String get shortcut_action_search_presets => 'Search Presets';

  @override
  String get shortcut_action_new_preset => 'New Preset';

  @override
  String get shortcut_action_duplicate_preset => 'Duplicate Preset';

  @override
  String get shortcut_action_delete_preset => 'Delete Preset';

  @override
  String get shortcut_action_close_config => 'Close Config';

  @override
  String get shortcut_action_minimize_to_tray => 'Minimize to Tray';

  @override
  String get shortcut_action_quit_app => 'Quit Application';

  @override
  String get shortcut_action_show_shortcut_help => 'Show Shortcut Help';

  @override
  String get shortcut_action_toggle_queue => 'Toggle Queue';

  @override
  String get shortcut_action_toggle_queue_pause => 'Toggle Queue Pause';

  @override
  String get shortcut_action_toggle_theme => 'Toggle Theme';

  @override
  String get shortcut_settings_title => 'Keyboard Shortcuts';

  @override
  String get shortcut_settings_enable => 'Enable Shortcuts';

  @override
  String get shortcut_settings_show_badges => 'Show Shortcut Badges';

  @override
  String get shortcut_settings_show_in_tooltips => 'Show in Tooltips';

  @override
  String get shortcut_settings_reset_all => 'Reset All to Default';

  @override
  String get shortcut_settings_search => 'Search shortcuts...';

  @override
  String get shortcut_settings_press_key => 'Press key combination...';

  @override
  String get shortcut_help_title => 'Keyboard Shortcuts Help';

  @override
  String get shortcut_help_search => 'Search shortcuts...';

  @override
  String get shortcut_help_all => 'All';

  @override
  String get shortcut_help_tip =>
      'Tip: press F1 or ? anytime to open this help dialog';

  @override
  String get shortcut_help_fabTooltip => 'Keyboard Shortcuts Help (F1)';

  @override
  String get shortcut_editor_recordingInline => 'Press shortcut...';

  @override
  String get shortcut_editor_pressEscToCancel => 'Press Esc to cancel';

  @override
  String get shortcut_editor_clickToRecord => 'Click to start recording';

  @override
  String shortcut_editor_conflictWith(Object action) {
    return 'This shortcut conflicts with \"$action\"';
  }

  @override
  String get drop_dialogTitle => 'How to use this image?';

  @override
  String get drop_hint => 'Drop image here';

  @override
  String get drop_img2img => 'Image2Image';

  @override
  String get drop_reversePrompt => 'Reverse Prompt';

  @override
  String get drop_vibeTransfer => 'Vibe Transfer';

  @override
  String get drop_characterReference => 'Precise Reference';

  @override
  String get drop_unsupportedFormat => 'Unsupported file format';

  @override
  String get drop_addedToImg2Img => 'Added to Image2Image';

  @override
  String get drop_addedToReversePrompt => 'Added to Reverse Prompt';

  @override
  String get drop_addedToVibe => 'Added to Vibe Transfer';

  @override
  String drop_addedMultipleToVibe(int count) {
    return 'Added $count vibe references';
  }

  @override
  String get drop_addedToCharacterRef => 'Added to Precise Reference';

  @override
  String get drop_extractMetadata => 'Extract Metadata';

  @override
  String get drop_extractMetadataSubtitle =>
      'Read Prompt, Seed and other parameters from image';

  @override
  String get drop_addToQueue => 'Add to Queue';

  @override
  String get drop_addToQueueSubtitle =>
      'Extract prompt and add to generation queue';

  @override
  String get drop_vibeDetected => 'Pre-encoded Vibe detected (saves 2 Anlas)';

  @override
  String drop_vibeStrength(Object value) {
    return 'Strength: $value%';
  }

  @override
  String drop_vibeInfoExtracted(Object value) {
    return 'Information Extracted: $value%';
  }

  @override
  String get drop_reuseVibe => 'Reuse Vibe';

  @override
  String get drop_reuseVibeSubtitle => 'Use pre-encoded data directly (free)';

  @override
  String get drop_useAsRawImage => 'Use as Raw Image';

  @override
  String get drop_useAsRawImageSubtitle => 'Re-encode (costs 2 Anlas)';

  @override
  String get drop_dragToImg2ImgOrOther =>
      'Drag to Image2Image or another target';

  @override
  String get drop_metadataDetected => 'NovelAI metadata detected';

  @override
  String get drop_metadataParseFailed => 'Metadata could not be parsed';

  @override
  String get drop_metadataParseFailedHint =>
      'The image contains metadata fields that cannot currently be read. Other image actions remain available.';

  @override
  String get drop_metadataErrorDetails => 'View error details';

  @override
  String get drop_positivePrompt => 'Prompt';

  @override
  String get drop_negativePrompt => 'Undesired Content';

  @override
  String drop_characterPrompts(int count) {
    return 'Character Prompts ($count)';
  }

  @override
  String drop_characterPositivePrompt(int index) {
    return 'Character $index Positive Prompt';
  }

  @override
  String drop_characterNegativePrompt(int index) {
    return 'Character $index Undesired Content';
  }

  @override
  String get drop_promptNotRecorded => 'Not recorded';

  @override
  String get drop_promptCopy => 'Copy';

  @override
  String get drop_promptAddWhole => 'Add full prompt to library';

  @override
  String get drop_promptAddSelection => 'Add to library';

  @override
  String get drop_promptLibraryTitle => 'Add to Library';

  @override
  String get drop_promptLibraryWriteMode => 'Write mode';

  @override
  String get drop_promptLibraryCreate => 'New';

  @override
  String get drop_promptLibraryAppend => 'Append';

  @override
  String get drop_promptLibraryOverwrite => 'Replace';

  @override
  String get drop_promptLibraryAliasHint =>
      'This name is also used by <library name> references';

  @override
  String get drop_promptLibraryTarget => 'Target entry';

  @override
  String get drop_promptLibrarySelectTarget => 'Select an entry to update';

  @override
  String get drop_promptLibrarySeparator => 'Separator';

  @override
  String get drop_promptLibrarySeparatorComma => 'Comma + space';

  @override
  String get drop_promptLibrarySeparatorNewline => 'New line';

  @override
  String get drop_promptLibrarySeparatorNone => 'No separator';

  @override
  String drop_promptLibraryCharacterCount(int count) {
    return '$count characters';
  }

  @override
  String get drop_promptLibraryExactContentHint =>
      'Saves this text without cleaning, reordering, or completing it';

  @override
  String get drop_promptLibraryResultPreview => 'Result preview';

  @override
  String drop_promptLibraryDuplicate(Object name) {
    return 'The same content already exists in “$name”';
  }

  @override
  String get drop_promptLibraryNameConflict =>
      'This name already exists. Rename it, append, or replace';

  @override
  String drop_promptLibraryOverwriteWarning(Object name) {
    return 'This will replace all prompt content in “$name”';
  }

  @override
  String get drop_promptLibraryMore => 'More options';

  @override
  String get drop_promptLibraryConfirmOverwrite => 'Replace';

  @override
  String get drop_promptLibrarySaved => 'Saved to library';

  @override
  String get drop_promptLibrarySaveFailed => 'Failed to save the library entry';

  @override
  String get drop_promptLibraryPositiveName => 'Prompt snippet';

  @override
  String get drop_promptLibraryNegativeName => 'Undesired content snippet';

  @override
  String get preciseRef_title => 'Precise Reference';

  @override
  String get preciseRef_description =>
      'Add reference images and set type and parameters. Multiple references can be used simultaneously.';

  @override
  String get preciseRef_addReference => 'Add Reference';

  @override
  String get preciseRef_clearAll => 'Clear All';

  @override
  String get preciseRef_remove => 'Remove';

  @override
  String get preciseRef_referenceType => 'Reference Type';

  @override
  String get preciseRef_strength => 'Strength';

  @override
  String get preciseRef_fidelity => 'Fidelity';

  @override
  String get preciseRef_v4Only =>
      'This feature is only available on V4.5 models';

  @override
  String get preciseRef_typeCharacter => 'Character';

  @override
  String get preciseRef_typeStyle => 'Style';

  @override
  String get preciseRef_typeCharacterAndStyle => 'Character + Style';

  @override
  String get preciseRef_costHint =>
      'Using Precise Reference consumes extra Anlas';

  @override
  String get preciseRef_costBadge => 'Uses Anlas';

  @override
  String get preciseRef_dropToAdd => 'Release to add precise reference';

  @override
  String get preciseRef_dropNoReadableImage =>
      'The drop source did not provide a readable image file or image link';

  @override
  String preciseRef_addedCount(int count) {
    return 'Added $count precise references';
  }

  @override
  String preciseRef_removedCount(int count) {
    return 'Removed $count precise references';
  }

  @override
  String get vibeLibrary_title => 'Vibe Library';

  @override
  String get vibeLibrary_categories => 'Categories';

  @override
  String get vibeLibrary_createCategoryTitle => 'New Category';

  @override
  String get vibeLibrary_createSubCategoryTitle => 'New Subcategory';

  @override
  String get vibeLibrary_categoryNameHint => 'Enter category name';

  @override
  String get vibeLibrary_createCategoryConfirm => 'Create';

  @override
  String get vibeLibrary_deleteCategoryTitle => 'Confirm Delete';

  @override
  String get vibeLibrary_deleteCategoryContent =>
      'Delete this category? Vibes in it will be moved to Uncategorized.';

  @override
  String get vibeLibrary_sortTooltip => 'Sort by';

  @override
  String get vibeLibrary_hideCategoryPanel => 'Hide category panel';

  @override
  String get vibeLibrary_showCategoryPanel => 'Show category panel';

  @override
  String get vibeLibrary_enterSelectionMode => 'Enter selection mode';

  @override
  String get vibeLibrary_importTooltip =>
      'Import Vibe files or PNG/JPG/JPEG/WEBP images (right-click for more options)';

  @override
  String get vibeLibrary_exportTooltip => 'Export Vibe to file';

  @override
  String get vibeLibrary_openFolderTooltip => 'Open Vibe library folder';

  @override
  String get vibeLibrary_refresh => 'Refresh';

  @override
  String get vibeLibrary_loading => 'Loading...';

  @override
  String vibeLibrary_totalCount(Object count) {
    return '$count Vibes';
  }

  @override
  String get vibeLibrary_noCategoriesAvailable => 'No categories available';

  @override
  String get vibeLibrary_moveToCategory => 'Move to Category';

  @override
  String get vibeLibrary_uncategorized => 'Uncategorized';

  @override
  String vibeLibrary_movedToCategory(Object count) {
    return 'Moved $count Vibes';
  }

  @override
  String get vibeLibrary_favoriteStatusUpdated => 'Favorite status updated';

  @override
  String get vibeLibrary_importFromFile => 'Import from File';

  @override
  String get vibeLibrary_importFromImage => 'Import from Image';

  @override
  String get vibeLibrary_importFromClipboard =>
      'Import Encoded Data from Clipboard';

  @override
  String vibeLibrary_openFolderFailed(Object error) {
    return 'Failed to open folder: $error';
  }

  @override
  String get vibeLibrary_importFileDialogTitle => 'Select Vibe files to import';

  @override
  String get vibeLibrary_preparingImport => 'Preparing import...';

  @override
  String vibeLibrary_importSuccessCount(Object count) {
    return 'Imported $count Vibes';
  }

  @override
  String vibeLibrary_importSummary(Object success, Object failed) {
    return 'Import complete: $success succeeded, $failed failed';
  }

  @override
  String get vibeLibrary_dropImportHint =>
      'Drop .naiv4vibe/.naiv4vibebundle/.png/.jpg/.jpeg/.webp files or folders here to import';

  @override
  String get vibeLibrary_importing => 'Importing...';

  @override
  String vibeLibrary_pageIndicator(Object current, Object total) {
    return '$current / $total pages';
  }

  @override
  String get vibeLibrary_itemsPerPage => 'Per page:';

  @override
  String get vibeLibrary_tooManyTitle => 'Too Many Vibes';

  @override
  String vibeLibrary_tooManySelectedContent(Object count) {
    return 'Selected $count Vibes, but at most 16 can be used at once.\n\nPlease reduce the selection and try again.';
  }

  @override
  String vibeLibrary_tooManyExistingContent(Object current, Object remaining) {
    return 'The generation page already has $current Vibes. You can add $remaining more.\n\nPlease reduce the selection and try again.';
  }

  @override
  String vibeLibrary_sentToGenerationCount(Object count) {
    return 'Sent $count Vibes to generation';
  }

  @override
  String vibeLibrary_deleteSelectedContent(Object count) {
    return 'Delete $count selected Vibes? This action cannot be undone.';
  }

  @override
  String vibeLibrary_deletedCount(Object count) {
    return 'Deleted $count Vibes';
  }

  @override
  String get vibeLibrary_markEncodingModel => 'Mark encoding model';

  @override
  String vibeLibrary_markEncodingModelContent(Object count, Object model) {
    return 'Mark the selected $count Vibes as encoded for \"$model\" and rewrite their library files.\n\nUse this for entries mislabelled with another model, which makes every generation re-encode and spend Anlas. If those encodings really came from a different model, results may not match expectations.';
  }

  @override
  String vibeLibrary_encodingModelMarked(Object count) {
    return 'Updated the encoding model of $count Vibes';
  }

  @override
  String get vibeLibrary_importImageDialogTitle =>
      'Select images containing Vibe data';

  @override
  String get vibeLibrary_clipboardEmpty => 'Clipboard is empty';

  @override
  String get vibeLibrary_encodeTimeout =>
      'Encoding timed out. Please check your network connection.';

  @override
  String get vibeLibrary_unknownError => 'Unknown error';

  @override
  String get vibeLibrary_save => 'Save to Library';

  @override
  String get vibeLibrary_import => 'Import Vibe';

  @override
  String get vibeLibrary_searchHint => 'Search name, tags...';

  @override
  String get vibeLibrary_empty => 'Vibe Library is empty';

  @override
  String get vibeLibrary_emptyHint => 'Add some entries to Vibe Library first';

  @override
  String get vibeLibrary_allVibes => 'All Vibes';

  @override
  String get vibeLibrary_favorites => 'Favorites';

  @override
  String get vibeLibrary_sendToGeneration => 'Send to Generation';

  @override
  String get vibeLibrary_export => 'Export';

  @override
  String get vibeLibrary_edit => 'Edit';

  @override
  String get vibeLibrary_delete => 'Delete';

  @override
  String get vibeLibrary_addToFavorites => 'Add to Favorites';

  @override
  String get vibeLibrary_removeFromFavorites => 'Remove from Favorites';

  @override
  String get vibeLibrary_newSubCategory => 'New Subcategory';

  @override
  String get vibeLibrary_maxVibesReached => 'Maximum limit reached (16 vibes)';

  @override
  String get vibeLibrary_bundleReadFailed =>
      'Failed to read bundle file, using single file mode';

  @override
  String categoryError_loadFailed(String error) {
    return 'Failed to load categories: $error';
  }

  @override
  String categoryError_syncFailed(String error) {
    return 'Failed to sync categories: $error';
  }

  @override
  String get categoryError_nameEmpty => 'Category name cannot be empty';

  @override
  String get categoryError_parentNotFound => 'Parent category does not exist';

  @override
  String categoryError_createFailed(String error) {
    return 'Failed to create category: $error';
  }

  @override
  String get categoryError_notFound => 'Category does not exist';

  @override
  String categoryError_renameFailed(String error) {
    return 'Failed to rename category: $error';
  }

  @override
  String get categoryError_invalidMove =>
      'A category cannot be moved under one of its descendants';

  @override
  String categoryError_moveFailed(String error) {
    return 'Failed to move category: $error';
  }

  @override
  String get categoryError_hasSubcategories =>
      'This category contains subcategories. Delete them first.';

  @override
  String categoryError_deleteFailed(String error) {
    return 'Failed to delete category: $error';
  }

  @override
  String categoryError_moveImageFailed(String error) {
    return 'Failed to move image: $error';
  }

  @override
  String categoryError_moveImagesFailed(String error) {
    return 'Failed to move images: $error';
  }

  @override
  String categoryError_reorderFailed(String error) {
    return 'Failed to reorder categories: $error';
  }

  @override
  String get vibeBulk_titleDelete => 'Delete Vibes';

  @override
  String get vibeBulk_titleMove => 'Move Vibes';

  @override
  String get vibeBulk_titleToggleFavorite => 'Update Favorites';

  @override
  String get vibeBulk_titleAddTags => 'Add Tags';

  @override
  String get vibeBulk_titleRemoveTags => 'Remove Tags';

  @override
  String get vibeBulk_titleExport => 'Export Vibes';

  @override
  String get vibeBulk_titleImport => 'Import Vibes';

  @override
  String vibeBulk_processingProgress(int current, int total) {
    return 'Processing: $current / $total';
  }

  @override
  String get vibeBulk_completed => 'Operation complete';

  @override
  String get vibeBulk_completedWithFailures =>
      'Operation complete with some failures';

  @override
  String get vibeBulk_successful => 'Succeeded';

  @override
  String get vibeBulk_failed => 'Failed';

  @override
  String get vibeBulk_errorDetails => 'Error details:';

  @override
  String vibeBulk_moreErrors(int count) {
    return '...and $count more errors';
  }

  @override
  String get vibeBulk_operationFailed => 'Operation failed';

  @override
  String get vibeBulk_operationFailedHint =>
      'Check the operation settings and try again.';

  @override
  String vibeBulk_errorEntryNotFoundOrDeleteFailed(String item) {
    return '$item was not found or could not be deleted';
  }

  @override
  String vibeBulk_errorDeleteFailed(String item, String error) {
    return 'Failed to delete $item: $error';
  }

  @override
  String vibeBulk_errorEntryNotFound(String item) {
    return 'Entry not found: $item';
  }

  @override
  String vibeBulk_errorMoveFailed(String item, String error) {
    return 'Failed to move $item: $error';
  }

  @override
  String vibeBulk_errorFavoriteFailed(String item) {
    return 'Failed to update favorite status: $item';
  }

  @override
  String vibeBulk_errorFavoriteFailedWithDetails(String item, String error) {
    return 'Failed to update favorite status for $item: $error';
  }

  @override
  String vibeBulk_errorAddTagsFailed(String item) {
    return 'Failed to add tags: $item';
  }

  @override
  String vibeBulk_errorAddTagsFailedWithDetails(String item, String error) {
    return 'Failed to add tags to $item: $error';
  }

  @override
  String vibeBulk_errorRemoveTagsFailed(String item) {
    return 'Failed to remove tags: $item';
  }

  @override
  String vibeBulk_errorRemoveTagsFailedWithDetails(String item, String error) {
    return 'Failed to remove tags from $item: $error';
  }

  @override
  String get vibeBulk_errorExportNoFile =>
      'Export failed because no file was created';

  @override
  String vibeBulk_errorExportFailed(String error) {
    return 'Export failed: $error';
  }

  @override
  String vibeBulk_errorFileNotFound(String item) {
    return 'File not found: $item';
  }

  @override
  String vibeBulk_errorNoVibeData(String item) {
    return 'No valid Vibe data was found in $item';
  }

  @override
  String vibeBulk_errorImportFailed(String item, String error) {
    return 'Failed to import Vibe from $item: $error';
  }

  @override
  String vibeBulk_errorProcessFileFailed(String item, String error) {
    return 'Failed to process $item: $error';
  }

  @override
  String get vibeBulkTag_title => 'Edit Tags in Bulk';

  @override
  String vibeBulkTag_selectedCount(int count) {
    return '$count Vibes selected';
  }

  @override
  String get vibeBulkTag_inputHint => 'Enter a new tag...';

  @override
  String get vibeBulkTag_noTags => 'No tags';

  @override
  String get vibeBulkTag_noTagsHint =>
      'Add tags to make filtering and management easier';

  @override
  String vibeBulkTag_currentTags(int count) {
    return 'Current tags ($count)';
  }

  @override
  String vibeBulkTag_pendingRemoval(int count) {
    return 'Tags to remove ($count)';
  }

  @override
  String get vibeBulkTag_removeTag => 'Remove tag';

  @override
  String get vibeBulkTag_actionPreview => 'Change preview';

  @override
  String vibeBulkTag_addTagsSummary(String tags) {
    return 'Add tags: $tags';
  }

  @override
  String vibeBulkTag_removeTagsSummary(String tags) {
    return 'Remove tags: $tags';
  }

  @override
  String get vibeBulkTag_noChanges => 'There are no changes to apply';

  @override
  String get vibeBulkCategory_title => 'Select Target Category';

  @override
  String vibeBulkCategory_moveCount(int count) {
    return 'Move $count Vibes to:';
  }

  @override
  String get vibeBulkCategory_cannotMoveToCurrent =>
      'Cannot move to the current category';

  @override
  String get vibeDetail_strengthDescription =>
      'Controls how strongly this Vibe influences generated results';

  @override
  String get vibeDetail_infoExtractedDescription =>
      'Controls how much information is extracted from the source image (costs 2 Anlas)';

  @override
  String get vibeDetail_statistics => 'Statistics';

  @override
  String get vibeDetail_usageCount => 'Times used';

  @override
  String vibeDetail_timesUsed(int count) {
    return '$count times';
  }

  @override
  String get vibeDetail_lastUsed => 'Last used';

  @override
  String get vibeDetail_neverUsed => 'Never used';

  @override
  String get vibeDetail_createdAt => 'Created';

  @override
  String get vibeDetail_saveParameters => 'Save Parameters';

  @override
  String get vibe_export_title => 'Export Vibe';

  @override
  String get vibe_export_format => 'Export Format';

  @override
  String get vibe_selector_title => 'Select Vibe';

  @override
  String get vibe_selector_recent => 'Recent';

  @override
  String get vibe_export_include_thumbnails => 'Include Thumbnails';

  @override
  String get vibe_export_include_thumbnails_subtitle =>
      'Include thumbnail preview in export file';

  @override
  String get vibe_export_singleFile => 'Single file (.naiv4vibe)';

  @override
  String get vibe_export_singleFileDescription =>
      'Export each Vibe as a separate file, suitable for sharing one Vibe';

  @override
  String get vibe_export_bundleFile => 'Bundle file (.naiv4vibebundle)';

  @override
  String get vibe_export_bundleFileDescription =>
      'Pack multiple Vibes into one file, suitable for batch backup';

  @override
  String get vibe_export_embedIntoPng => 'Embed into PNG';

  @override
  String get vibe_export_embedIntoPngDescription =>
      'Export a single Vibe by embedding its data into PNG metadata';

  @override
  String get vibe_export_exportable => 'Exportable';

  @override
  String get vibe_export_notExportable => 'Not exportable';

  @override
  String get vibe_export_selectVibesToExport => 'Select Vibes to export';

  @override
  String vibe_export_exportSelected(int count) {
    return 'Export ($count)';
  }

  @override
  String vibe_export_strengthPercent(int percent) {
    return 'Strength: $percent%';
  }

  @override
  String get vibe_export_pngCarrierImage => 'PNG carrier image';

  @override
  String get vibe_export_noUsablePngCarrier =>
      'This Vibe has no directly usable PNG carrier image. You can choose an external PNG image as the carrier.';

  @override
  String get vibe_export_selectExternalPngImage =>
      'Select external PNG image...';

  @override
  String get vibe_export_changeExternalPngImage =>
      'Change external PNG image...';

  @override
  String get vibe_export_useVibeImageInstead => 'Use Vibe image instead';

  @override
  String vibe_export_usingExternalPng(String fileName) {
    return 'Using external PNG: $fileName';
  }

  @override
  String get vibe_export_selectPngImage => 'Select PNG image';

  @override
  String get vibe_export_invalidPngImage =>
      'The selected file is not a valid PNG image';

  @override
  String vibe_export_selectPngImageFailed(String error) {
    return 'Failed to select PNG image: $error';
  }

  @override
  String vibe_export_embeddingPng(String name) {
    return 'Embedding PNG: $name';
  }

  @override
  String vibe_export_exportCompleteCounts(int successCount, int failCount) {
    return 'Export complete: $successCount succeeded, $failCount failed';
  }

  @override
  String vibe_export_exportCompletePath(String path) {
    return 'Export complete: $path';
  }

  @override
  String vibe_export_packingVibes(int count) {
    return 'Packing $count Vibes...';
  }

  @override
  String vibe_export_exportingName(String name) {
    return 'Exporting: $name';
  }

  @override
  String get vibe_export_selectExportFolder => 'Select export folder';

  @override
  String get vibe_export_generatingBundleFile => 'Generating bundle file...';

  @override
  String vibe_export_bundleTitle(String name) {
    return 'Export Bundle: $name';
  }

  @override
  String vibe_export_vibesTitle(int count) {
    return 'Export Vibes ($count selected)';
  }

  @override
  String get vibe_export_method => 'Export Method';

  @override
  String get vibe_export_wholeBundle => 'Whole Bundle';

  @override
  String get vibe_export_internalVibe => 'Internal Vibe';

  @override
  String vibe_export_wholeBundleDescription(int count) {
    return 'Export as a .naiv4vibebundle file containing all $count vibes';
  }

  @override
  String vibe_export_internalVibeDescription(int count) {
    return 'Select internal bundle vibes to export separately as .naiv4vibe files ($count total)';
  }

  @override
  String get vibe_export_exportBundle => 'Export Bundle';

  @override
  String get vibe_export_exportAsFiles => 'Export as Files';

  @override
  String get vibe_export_exportBundleDescription =>
      'Export as a .naiv4vibebundle file';

  @override
  String get vibe_export_exportAsFilesDescription =>
      'Export as .naiv4vibe or .naiv4vibebundle files';

  @override
  String get vibe_export_exportAsZip => 'Export as ZIP';

  @override
  String get vibe_export_exportAsZipDescription =>
      'Pack the selected Vibe library entries into a .zip as separate files';

  @override
  String get vibe_export_compressData => 'Compress data';

  @override
  String get vibe_export_compressDataDescription =>
      'Use compression to reduce file size (recommended for batch export)';

  @override
  String get vibe_export_zipCompressDescription =>
      'Compress files inside the ZIP to reduce size';

  @override
  String get vibe_export_exportAsPng => 'Export as PNG';

  @override
  String get vibe_export_pngInternalBundleUnsupported =>
      'Embedding into an image is not supported when exporting a single internal bundle vibe';

  @override
  String get vibe_export_embedVibeDataIntoPng =>
      'Embed Vibe data into PNG metadata';

  @override
  String get vibe_export_batchPngUsesFirstImage =>
      'Batch export uses each Vibe\'s first available image. Entries without images are skipped automatically.';

  @override
  String get vibe_export_exportCarrierImage => 'Export carrier image';

  @override
  String get vibe_export_usingExternalCarrierImage =>
      'Using an external PNG as the export carrier image';

  @override
  String get vibe_export_exportAsEncodings => 'Export as Encodings';

  @override
  String get vibe_export_exportAsEncodingsDescription =>
      'Export data as encodings (JSON or Base64)';

  @override
  String get vibe_export_jsonDescription =>
      'Export as a formatted JSON file for easier reading and editing';

  @override
  String get vibe_export_base64Description =>
      'Export as plain Base64 for copying and sharing';

  @override
  String get vibe_export_selectAtLeastOneMethod =>
      'Select at least one export method';

  @override
  String get vibe_export_batchPngUnsupported =>
      'Batch Vibe export does not support embedding into PNG. Use the single Vibe export screen.';

  @override
  String get vibe_export_selectPngCarrier =>
      'Select a PNG carrier image for export';

  @override
  String get vibe_export_selectAtLeastOneInternalVibe =>
      'Select at least one internal vibe to export';

  @override
  String get vibe_export_selectVibeExportFolder => 'Select Vibe export folder';

  @override
  String get vibe_export_saveEncodingFile => 'Save encoding file';

  @override
  String get vibe_export_preparingExport => 'Preparing export...';

  @override
  String vibe_export_preparingVibeProgress(int current, int total) {
    return 'Reading Vibe $current/$total...';
  }

  @override
  String get vibe_export_exportingBundle => 'Exporting Bundle...';

  @override
  String get vibe_export_exportingZip => 'Exporting ZIP...';

  @override
  String get vibe_export_embeddingImage => 'Embedding image...';

  @override
  String get vibe_export_exportingEncoding => 'Exporting encoding...';

  @override
  String vibe_export_exportFailedWithError(String error) {
    return 'Export failed: $error';
  }

  @override
  String get vibe_export_noExportableEntries => 'No exportable Vibe entries';

  @override
  String get vibe_export_bundleFilePathEmpty => 'Bundle file path is empty';

  @override
  String vibe_export_invalidImageFormatWithError(String error) {
    return 'Invalid image format: $error';
  }

  @override
  String vibe_export_embedFailedWithError(String error) {
    return 'Embed failed: $error';
  }

  @override
  String vibe_export_embedImageFailedWithError(String error) {
    return 'Failed to embed image: $error';
  }

  @override
  String vibe_export_extractingVibeProgress(int current, int total) {
    return 'Extracting vibe $current/$total...';
  }

  @override
  String vibe_export_selectImageFailed(String error) {
    return 'Failed to select image: $error';
  }

  @override
  String vibe_export_dialogTitle(int count) {
    return 'Export $count Vibes';
  }

  @override
  String get vibe_export_chooseMethod => 'Choose how to export the vibes';

  @override
  String get vibe_export_asBundle => 'As Bundle';

  @override
  String get vibe_export_individually => 'Individually';

  @override
  String get vibe_export_noData => 'No data to export';

  @override
  String get vibe_export_success => 'Export successful';

  @override
  String get vibe_export_failed => 'Export failed';

  @override
  String vibe_export_skipped(int count) {
    return 'Skipped $count vibes without data';
  }

  @override
  String vibe_export_bundleSuccess(int count) {
    return 'Bundle exported: $count vibes';
  }

  @override
  String get vibe_export_selectToEmbed => 'Select vibes to embed';

  @override
  String get vibe_export_pngRequired => 'PNG file required';

  @override
  String get vibe_export_noEmbeddableData => 'No embeddable data';

  @override
  String vibe_export_embedSuccess(int count) {
    return 'Embedded $count vibes into image';
  }

  @override
  String get vibe_export_embedFailed => 'Embed failed';

  @override
  String get vibe_embedToImage => 'Embed to Image';

  @override
  String get vibe_import_skip => 'Skip';

  @override
  String get vibe_import_confirm => 'Confirm';

  @override
  String get vibe_import_encodingCost => 'Encoding will cost 2 Anlas';

  @override
  String get vibe_import_encodingFailed => 'Encoding failed';

  @override
  String get vibe_import_title => 'Import from Library';

  @override
  String vibe_import_result(int count) {
    return 'Imported $count vibes';
  }

  @override
  String get vibe_import_fileParseFailed => 'Failed to parse file';

  @override
  String get vibe_import_fileSelectionFailed => 'File selection failed';

  @override
  String get vibe_import_importFailed => 'Import failed';

  @override
  String vibe_import_failedWithError(String error) {
    return 'Import failed: $error';
  }

  @override
  String get vibe_import_bundleTitle => 'Import Vibe Bundle';

  @override
  String get vibe_import_bundleChooseMethod => 'Choose import method';

  @override
  String get vibe_import_bundleAsWhole => 'Import as whole';

  @override
  String get vibe_import_bundleAsWholeDescription =>
      'Keep the bundle structure and import it as one library entry';

  @override
  String get vibe_import_bundleSplitEntries => 'Split into separate entries';

  @override
  String get vibe_import_bundleSplitEntriesDescription =>
      'Import each vibe as a separate library entry';

  @override
  String get vibe_import_bundleSelectVibes => 'Select vibes to import';

  @override
  String get vibe_import_bundleSelectVibesDescription =>
      'Import only the selected vibes';

  @override
  String get vibe_import_bundleConfigureEachVibe =>
      'Configure each Vibe\'s parameters';

  @override
  String get vibe_import_bundleSelectAndConfigureEachVibe =>
      'Select and configure each Vibe\'s parameters';

  @override
  String vibe_import_bundleSelectedCount(int selected, int total) {
    return '$selected/$total selected';
  }

  @override
  String get vibe_saveToLibrary_title => 'Save to Library';

  @override
  String get vibe_saveToLibrary_strength => 'Strength';

  @override
  String get vibe_saveToLibrary_infoExtracted => 'Information Extracted';

  @override
  String vibe_saveToLibrary_saving(int count) {
    return 'Saving $count vibes';
  }

  @override
  String get vibe_saveToLibrary_saveFailed => 'Failed to save to library';

  @override
  String vibe_saveToLibrary_savingCount(int count) {
    return 'Saving $count vibes';
  }

  @override
  String get vibe_saveToLibrary_nameLabel => 'Name';

  @override
  String get vibe_saveToLibrary_nameHint => 'Enter vibe name';

  @override
  String vibe_saveToLibrary_mixed(int saved, int reused) {
    return 'Saved $saved, reused $reused';
  }

  @override
  String vibe_saveToLibrary_saved(int count) {
    return 'Saved $count to library';
  }

  @override
  String vibe_saveToLibrary_reused(int count) {
    return 'Reused $count from library';
  }

  @override
  String get vibe_saveToLibrary_saveAsBundle => 'Save as bundle';

  @override
  String vibe_saveToLibrary_saveAsBundleDescription(int count) {
    return 'Save $count Vibes as one bundle';
  }

  @override
  String get vibe_saveToLibrary_tagHint => 'Enter a tag, then press Add';

  @override
  String get vibe_maxReached => 'Maximum 16 vibes reached';

  @override
  String get vibe_maxReachedRemoveSome =>
      'Maximum 16 vibes reached. Remove some vibes first.';

  @override
  String vibe_addedNamed(String name) {
    return 'Added Vibe: $name';
  }

  @override
  String vibe_addedCount(int count) {
    return 'Added $count vibes';
  }

  @override
  String get vibe_statusEncoded => 'Encoded';

  @override
  String get vibe_statusEncoding => 'Encoding...';

  @override
  String get vibe_statusPendingEncode => 'Encode (2 Anlas)';

  @override
  String get vibe_statusNeedsReencode => 'Re-encode (2 Anlas)';

  @override
  String get vibe_statusSourceImageRequired => 'Source image required';

  @override
  String get vibe_encodeDialogTitle => 'Confirm Vibe Encoding';

  @override
  String get vibe_encodeDialogMessage => 'Encode this image for generation?';

  @override
  String get vibe_encodeCostWarning => 'This will cost 2 Anlas (credits)';

  @override
  String get vibe_encodeButton => 'Encode';

  @override
  String get vibe_encodeSuccess => 'Vibe encoded successfully!';

  @override
  String get vibe_encodeFailed => 'Vibe encoding failed, please retry';

  @override
  String vibe_encodeError(String error) {
    return 'Encoding failed: $error';
  }

  @override
  String get shortcuts_customize => 'Customize Shortcuts';

  @override
  String get image_editor_select_tool => 'Select Tool';

  @override
  String get selection_clear_selection => 'Clear Selection';

  @override
  String get selection_invert_selection => 'Invert Selection';

  @override
  String get selection_cut_to_layer => 'Cut to Layer';

  @override
  String get search_results => 'Search Results';

  @override
  String get search_noResults => 'No matching results';

  @override
  String get addToCurrent => 'Add to Current';

  @override
  String get replaceExisting => 'Replace Existing';

  @override
  String get confirmSelection => 'Confirm Selection';

  @override
  String get selectAll => 'Select All';

  @override
  String get clearSelection => 'Clear';

  @override
  String get clearFilters => 'Clear Filters';

  @override
  String get shortcut_context_vibe_detail => 'Vibe Detail';

  @override
  String get shortcut_action_vibe_detail_rename => 'Rename';

  @override
  String get vibeSelectorFilterFavorites => 'Favorites';

  @override
  String get vibeSelectorFilterSourceAll => 'All Types';

  @override
  String get vibeSelectorSortCreated => 'Created';

  @override
  String get vibeSelectorSortLastUsed => 'Last Used';

  @override
  String get vibeSelectorSortUsedCount => 'Usage Count';

  @override
  String get vibeSelectorSortName => 'Name';

  @override
  String vibeSelectorItemsCount(int count) {
    return '$count items';
  }

  @override
  String get tray_show => 'Show Window';

  @override
  String get tray_exit => 'Exit';

  @override
  String get settings_shortcutsSubtitle => 'Customize keyboard shortcuts';

  @override
  String get settings_openFolder => 'Open folder';

  @override
  String get settings_openFolderFailed => 'Failed to open folder';

  @override
  String get settings_pleaseLoginFirst => 'Please login first';

  @override
  String get settings_accountNotFound => 'Account information not found';

  @override
  String get settings_goToLoginPage => 'Go to login page';

  @override
  String get settings_vibePathSaved => 'Vibe library path saved';

  @override
  String get settings_selectFolderFailed => 'Failed to select folder';

  @override
  String get settings_hivePathSaved =>
      'Data storage path saved, effective after restart';

  @override
  String get settings_restartRequiredTitle => 'Restart Required';

  @override
  String get settings_changePathConfirm =>
      'After changing the data storage path, the app needs to restart to take effect.\\n\\nThe new path will take effect on the next startup. Continue?';

  @override
  String get settings_resetPathConfirm =>
      'After resetting the data storage path, the app needs to restart to take effect.\\n\\nThe default path will take effect on the next startup. Continue?';

  @override
  String get settings_kritaBridgeTitle => 'Krita Bridge';

  @override
  String get settings_kritaBridgeEnable => 'Enable Krita local bridge';

  @override
  String get settings_kritaBridgeDisabledText =>
      'Off by default; listens only on local 127.0.0.1 when enabled';

  @override
  String get settings_kritaBridgeStartingText =>
      'Starting local bridge service...';

  @override
  String get settings_kritaBridgeListeningText =>
      'Waiting for Krita plugin connection';

  @override
  String get settings_kritaBridgeConnectedText => 'Krita plugin connected';

  @override
  String get settings_kritaBridgeErrorText =>
      'Startup failed, check the error message';

  @override
  String get settings_kritaBridgeDisabled => 'Disabled';

  @override
  String get settings_kritaBridgeStarting => 'Starting';

  @override
  String get settings_kritaBridgeListening => 'Listening';

  @override
  String get settings_kritaBridgeConnected => 'Connected';

  @override
  String get settings_kritaBridgeError => 'Error';

  @override
  String get settings_kritaBridgeRegenerateSession => 'Regenerate Session';

  @override
  String get settings_kritaBridgeDiscoveryFile => 'Discovery File';

  @override
  String get settings_kritaBridgeWaitingEndpoint =>
      'Waiting for local WebSocket listener';

  @override
  String settings_kritaBridgeClient(Object client) {
    return 'Client: $client';
  }

  @override
  String get settings_fontScale => 'Font Size';

  @override
  String get settings_fontScale_description => 'Adjust global font scale';

  @override
  String get settings_fontScale_previewSmall =>
      'The setting sun and lone duck fly together';

  @override
  String get settings_fontScale_previewMedium =>
      'Autumn water merges with the endless sky';

  @override
  String get settings_fontScale_previewLarge => 'Font Size Preview';

  @override
  String get settings_fontScale_reset => 'Reset';

  @override
  String get settings_fontScale_done => 'Done';

  @override
  String get settings_generationLayout => 'Generation page layout';

  @override
  String get settings_generationLayout_classic => 'Classic';

  @override
  String get settings_generationLayout_classicDescription =>
      'Parameters on the left, prompt above the preview';

  @override
  String get settings_generationLayout_webStyle => 'Web style';

  @override
  String get settings_generationLayout_webStyleDescription =>
      'Prompt and settings docked on the far left, like the NovelAI website';

  @override
  String get settings_historyClickBehavior => 'History click behavior';

  @override
  String get settings_historyClickBehavior_classic => 'Classic';

  @override
  String get settings_historyClickBehavior_classicDescription =>
      'Click a history image to open its details';

  @override
  String get settings_historyClickBehavior_linked => 'Linked preview';

  @override
  String get settings_historyClickBehavior_linkedDescription =>
      'Click to switch the central preview, double-click or hold for details, and browse with Left/Right';

  @override
  String get image_viewDetail => 'View details';

  @override
  String get discordShare_action => 'Share to Discord';

  @override
  String get discordShare_title => 'Share to Discord';

  @override
  String get discordShare_subtitle =>
      'Post this image to an Aaalice community channel';

  @override
  String get discordShare_verifyTitle => 'Verify your Discord membership';

  @override
  String get discordShare_verifyDescription =>
      'Sign in to Discord in your browser before sharing. The app only receives your public identity and server membership status.';

  @override
  String get discordShare_verifyButton => 'Verify with Discord';

  @override
  String get discordShare_verifying => 'Waiting for Discord verification…';

  @override
  String get discordShare_verifyingHint =>
      'Complete authorization in your browser, then return to the app.';

  @override
  String get discordShare_joinRequired =>
      'Join the Aaalice Discord server first';

  @override
  String get discordShare_joinDescription =>
      'Only server members can share to community channels. Join, then return here and verify again.';

  @override
  String get discordShare_joinServer => 'Join Discord server';

  @override
  String get discordShare_retryVerification => 'Verify again';

  @override
  String discordShare_account(Object name) {
    return 'Verified as $name';
  }

  @override
  String get discordShare_disconnect => 'Disconnect Discord';

  @override
  String get discordShare_channels => 'Channels';

  @override
  String get discordShare_selectChannel => 'Select at least one channel';

  @override
  String get discordShare_caption => 'Image caption';

  @override
  String get discordShare_captionHint =>
      'Add a short comment, like a post title (optional)';

  @override
  String get discordShare_promptCategories => 'Prompt categories';

  @override
  String get discordShare_promptEditHint =>
      'You can edit the final text before sending. Changing categories rebuilds it from image metadata.';

  @override
  String get discordShare_promptContent => 'Prompt to send';

  @override
  String get discordShare_noPromptMetadata =>
      'No readable prompt metadata was found. You can still share only the image and caption.';

  @override
  String get discordShare_categoryMain => 'Main';

  @override
  String get discordShare_categoryCharacters => 'Characters';

  @override
  String get discordShare_categoryQuality => 'Quality';

  @override
  String get discordShare_categoryFixed => 'Fixed';

  @override
  String get discordShare_keepMetadata => 'Keep image metadata';

  @override
  String get discordShare_keepMetadataHint =>
      'Off by default. When off, PNG text, EXIF, and NovelAI stealth metadata are removed before upload.';

  @override
  String get discordShare_privacyHint =>
      'This content will be uploaded to Discord. Check prompts and the caption for private information.';

  @override
  String get discordShare_send => 'Send to Discord';

  @override
  String get discordShare_sending => 'Sending…';

  @override
  String get discordShare_success => 'Shared to Discord';

  @override
  String get discordShare_partialSuccess =>
      'Some channels succeeded. Review failed channels and retry.';

  @override
  String discordShare_failed(Object error) {
    return 'Could not share to Discord: $error';
  }

  @override
  String get discordShare_errorNetwork =>
      'Could not reach the Discord share service. Check your connection and try again.';

  @override
  String get discordShare_errorBrowser =>
      'Could not open your browser. Check the system default browser setting.';

  @override
  String get discordShare_errorTimeout =>
      'Discord verification timed out. Please verify again.';

  @override
  String get discordShare_errorRateLimited =>
      'You are sharing too quickly. Please try again shortly.';

  @override
  String discordShare_errorRateLimitedRetry(int seconds) {
    return 'You are sharing too quickly. Try again in $seconds seconds.';
  }

  @override
  String get discordShare_errorNoChannels =>
      'No Discord share channels are currently available.';

  @override
  String get discordShare_errorSession =>
      'Your Discord verification expired. Please verify again.';

  @override
  String get discordShare_errorRelay =>
      'The Discord share service is temporarily unavailable. Please try again later.';

  @override
  String get discordShare_errorImageRejected =>
      'Discord rejected this image. Check its size or format.';

  @override
  String get discordShare_errorDelivery =>
      'The image could not be delivered to the Discord channel. Please retry.';

  @override
  String get settings_defaultImagesPath =>
      'Default (Documents/NAI_Launcher/images/)';

  @override
  String settings_defaultVibePath(Object path) {
    return '$path (Default)';
  }

  @override
  String get settings_defaultHivePath =>
      'Default (%APPDATA%/NAI_Launcher/hive/)';

  @override
  String get settings_protectionMode => 'Protection Mode';

  @override
  String get settings_protectionModeSubtitle =>
      'Protect local assets, shared copies, and high-cost or high-frequency generation operations through the options below. Turning this off keeps the option values but disables them.';

  @override
  String get settings_protectionFeatures => 'Protection Features';

  @override
  String get settings_stripMetadataTitle =>
      'Remove all metadata when copying or dragging';

  @override
  String get settings_stripMetadataSubtitle =>
      'Create a sanitized copy, remove PNG text chunks, EXIF, and NAI steganographic watermark data, and avoid exposing the original path while dragging.';

  @override
  String get settings_confirmDangerousActionsTitle =>
      'Double-confirm dangerous asset actions';

  @override
  String get settings_confirmDangerousActionsSubtitle =>
      'Deleting, moving, or batch-moving local assets will show an additional protection confirmation.';

  @override
  String get settings_warnExternalImageSendTitle =>
      'Confirm before sending to external services';

  @override
  String get settings_warnExternalImageSendSubtitle =>
      'Confirm before local images cross the app boundary to LLMs, NovelAI, ComfyUI, or similar services.';

  @override
  String get settings_preventOverwriteTitle =>
      'Avoid overwriting existing files on export';

  @override
  String get settings_preventOverwriteSubtitle =>
      'Automatically number duplicate export or package paths to avoid replacing existing assets by mistake.';

  @override
  String get settings_warnHighAnlasCostTitle => 'High Anlas cost warning';

  @override
  String settings_warnHighAnlasCostSubtitle(Object threshold) {
    return 'Show a confirmation before generation when the estimated single request cost reaches $threshold Anlas.';
  }

  @override
  String get settings_highAnlasCostThresholdTitle => 'Anlas Warning Threshold';

  @override
  String get settings_setHighAnlasCostThresholdTitle =>
      'Set Anlas Warning Threshold';

  @override
  String get settings_threshold => 'Threshold';

  @override
  String get settings_highAnlasCostThresholdHelper =>
      'Show a confirmation when the estimated single generation cost reaches or exceeds this value.';

  @override
  String get settings_limitGenerationIntervalTitle =>
      'Limit generation frequency';

  @override
  String get settings_limitGenerationIntervalSubtitle =>
      'Require the configured minimum time between generation starts. The Generate button is disabled during the cooldown.';

  @override
  String get settings_generationIntervalTitle => 'Generation interval';

  @override
  String settings_generationIntervalValue(Object seconds) {
    return '$seconds seconds';
  }

  @override
  String get settings_setGenerationIntervalTitle => 'Set Generation Interval';

  @override
  String get settings_generationIntervalHelper =>
      'Enter 1–3600 seconds. The cooldown starts when generation begins.';

  @override
  String get settings_selectLocalOnnxTaggerFolder =>
      'Select ONNX tagger model folder';

  @override
  String get settings_localOnnxTaggerFolderSaved =>
      'ONNX tagger model folder saved';

  @override
  String get settings_localOnnxTaggerFolder => 'Local ONNX tagger model folder';

  @override
  String get settings_notConfigured => 'Not configured';

  @override
  String get settings_confirmExternalSendTitle =>
      'Protection Mode: Confirm External Send';

  @override
  String settings_confirmExternalSendContent(Object count, Object target) {
    return 'About to send $count local image(s) to $target. The image data will leave the local app boundary. Confirm this is expected.';
  }

  @override
  String get settings_confirmExternalSend => 'Send';

  @override
  String get settings_highAnlasCostTitle => 'Protection Mode: High Anlas Cost';

  @override
  String settings_highAnlasCostContent(Object cost, Object threshold) {
    return 'This request is estimated to cost $cost Anlas, which reaches or exceeds your $threshold Anlas warning threshold. Continue generation?';
  }

  @override
  String get settings_continueGeneration => 'Continue Generation';

  @override
  String get settings_comfyUiEnable => 'Enable ComfyUI Integration';

  @override
  String get settings_comfyUiDisabledSubtitle =>
      'When disabled, local upscale and other ComfyUI features are hidden';

  @override
  String get settings_comfyUiServerUrl => 'Server URL';

  @override
  String get settings_comfyUiConnectionSuccess => 'Connection successful';

  @override
  String get settings_comfyUiConnectionSuccessFull =>
      'ComfyUI connection successful';

  @override
  String settings_comfyUiConnectionFailed(Object error) {
    return 'Connection failed: $error';
  }

  @override
  String get settings_comfyUiConnected => 'Connected';

  @override
  String get settings_comfyUiDisconnect => 'Disconnect';

  @override
  String get settings_comfyUiWorkflowManagement => 'Workflow Management';

  @override
  String get settings_comfyUiBuiltinWorkflows => 'Built-in Workflows';

  @override
  String get settings_comfyUiCustomWorkflows => 'Custom Workflows';

  @override
  String get settings_comfyUiNoCustomWorkflows =>
      'No custom workflows yet. Click \"Import\" to add a ComfyUI workflow.';

  @override
  String settings_comfyUiSlotCount(Object count) {
    return '$count slots';
  }

  @override
  String get settings_comfyUiBuiltin => 'Built-in';

  @override
  String get settings_comfyUiDeleteWorkflowTitle => 'Delete Workflow';

  @override
  String settings_comfyUiDeleteWorkflowContent(Object name) {
    return 'Delete workflow \"$name\"? This cannot be undone.';
  }

  @override
  String settings_comfyUiDeleted(Object name) {
    return 'Deleted: $name';
  }

  @override
  String get settings_comfyUiNoResponse => 'Server did not respond';

  @override
  String get settings_comfyUiStatusDisconnected => 'Disconnected';

  @override
  String get settings_comfyUiStatusConnecting => 'Connecting...';

  @override
  String get settings_comfyUiStatusConnected => 'Connected';

  @override
  String get settings_comfyUiStatusError => 'Connection error';

  @override
  String get settings_comfyUiCategoryEnhance => 'Enhance/Upscale';

  @override
  String get settings_comfyUiCategoryImg2Img => 'Image2Image';

  @override
  String get settings_comfyUiCategoryInpaint => 'Inpaint';

  @override
  String get settings_comfyUiCategoryTxt2Img => 'Text-to-Image';

  @override
  String get settings_comfyUiCategoryCustom => 'Custom';

  @override
  String get comfyWorkflow_seedvr2UpscaleName => 'SeedVR2 Upscale';

  @override
  String get comfyWorkflow_seedvr2UpscaleDescription =>
      'Upscale with the SeedVR2 AI model. Produces high-quality results.';

  @override
  String get comfyWorkflow_seedvr2LegacyUpscaleName =>
      'SeedVR2 Compatibility Upscale';

  @override
  String get comfyWorkflow_seedvr2LegacyUpscaleDescription =>
      'Upscale with the installed SeedVR2VideoUpscaler custom nodes.';

  @override
  String get comfyWorkflow_seedvr2TiledUpscaleName => 'SeedVR2 Tiled Upscale';

  @override
  String get comfyWorkflow_seedvr2TiledUpscaleDescription =>
      'Use SeedVR2TilingUpscaler for tiled upscale to reduce VRAM pressure on large images.';

  @override
  String get comfyWorkflow_modelUpscaleName => 'ComfyUI Standard Upscale Model';

  @override
  String get comfyWorkflow_modelUpscaleDescription =>
      'Load a standard upscale model with ComfyUI UpscaleModelLoader, then correct the final scale with Lanczos.';

  @override
  String get comfyWorkflow_rtxUpscaleName => 'RTX Upscale';

  @override
  String get comfyWorkflow_rtxUpscaleDescription =>
      'Use the Nvidia RTX Video Super Resolution node for local upscaling.';

  @override
  String get comfyWorkflowSlot_inputImage => 'Input Image';

  @override
  String get comfyWorkflowSlot_targetShortSide => 'Target Short Side';

  @override
  String get comfyWorkflowSlot_targetLongSide => 'Target Long Side';

  @override
  String get comfyWorkflowSlot_upscaleModel => 'Upscale Model';

  @override
  String get comfyWorkflowSlot_randomSeed => 'Random Seed';

  @override
  String get comfyWorkflowSlot_outputImage => 'Output Image';

  @override
  String get comfyWorkflowSlot_tileWidth => 'Tile Width';

  @override
  String get comfyWorkflowSlot_tileHeight => 'Tile Height';

  @override
  String get comfyWorkflowSlot_tileUpscaleResolution =>
      'Tile Upscale Resolution';

  @override
  String get comfyWorkflowSlot_targetWidth => 'Target Width';

  @override
  String get comfyWorkflowSlot_targetHeight => 'Target Height';

  @override
  String get comfyWorkflowSlot_scale => 'Scale';

  @override
  String get comfyWorkflow_parameters => 'Parameters';

  @override
  String get comfyWorkflow_selectImage => 'Click to select image';

  @override
  String comfyWorkflow_pickImageFailed(Object error) {
    return 'Failed to select image: $error';
  }

  @override
  String get comfyWorkflow_useResult => 'Use Result';

  @override
  String get comfyWorkflow_execute => 'Run';

  @override
  String get comfyWorkflow_uploadingImage => 'Uploading image...';

  @override
  String get comfyWorkflow_queued => 'Queued...';

  @override
  String comfyWorkflow_runningSteps(Object current, Object total) {
    return 'Processing $current/$total';
  }

  @override
  String get comfyWorkflow_processing => 'Processing...';

  @override
  String get comfyWorkflow_complete => 'Complete';

  @override
  String comfyWorkflow_imageCount(Object count) {
    return '$count images';
  }

  @override
  String get promptAssistant_defaultOptimizeRuleName => 'Default Optimize Rule';

  @override
  String get promptAssistant_defaultOptimizeRuleContent =>
      'You are a prompt optimization assistant. Preserve the user intent, add actionable visual details, and output a single comma-separated prompt line.';

  @override
  String get promptAssistant_defaultTranslateRuleName =>
      'Default Translate Rule';

  @override
  String get promptAssistant_defaultTranslateRuleContent =>
      'You are a translation assistant. Detect the source language, translate between Chinese and English automatically, and return only the translation without explanation.';

  @override
  String get promptAssistant_defaultReverseRuleName =>
      'Default Reverse Prompt Rule';

  @override
  String get promptAssistant_defaultReverseRuleContent =>
      'You are an image reverse-prompt assistant. Based on the image and optional tagger results, output English comma-separated prompts suitable for NovelAI. Preserve subject, character, style, clothing, action, composition, lighting, and background. Do not explain.';

  @override
  String get promptAssistant_defaultCharacterReplaceRuleName =>
      'Default Character Replace Rule';

  @override
  String get promptAssistant_defaultCharacterReplaceRuleContent =>
      'You are a character replacement assistant. Replace the original character identity, hairstyle, outfit, and appearance in the input prompt with the target character while preserving action, composition, background, style, camera, and quality tags. Output only the replaced single-line prompt.';

  @override
  String get promptAssistant_defaultCustomRuleName => 'Default Custom Rule';

  @override
  String get promptAssistant_defaultCustomRuleContent =>
      'You are a prompt rewriting assistant. Modify the prompt according to the current prompt, the user request, and optional reference images. Output only the final single-line prompt that can be used directly, without explanation.';

  @override
  String get localGallery_dateFilterButton => 'Date Filter';

  @override
  String get cacheStats_title => 'Cache Statistics';

  @override
  String cacheStats_autoRefreshUpdated(Object time) {
    return 'Auto refresh · Last updated: $time';
  }

  @override
  String cacheStats_secondsAgo(Object seconds) {
    return '$seconds seconds ago';
  }

  @override
  String get cacheStats_refreshNow => 'Refresh now';

  @override
  String get cacheStats_refreshed => 'Refreshed';

  @override
  String get cacheStats_resetStats => 'Reset statistics';

  @override
  String get cacheStats_statsReset => 'Statistics reset';

  @override
  String get cacheStats_l1Memory => 'L1 Memory Cache';

  @override
  String get cacheStats_l2Hive => 'L2 Hive Cache';

  @override
  String get cacheStats_l3Sqlite => 'L3 SQLite Database';

  @override
  String cacheStats_recordCount(Object count) {
    return '$count records';
  }

  @override
  String cacheStats_databaseValue(Object imageCount, Object metadataCount) {
    return '$imageCount images · $metadataCount metadata rows';
  }

  @override
  String get galleryCache_rescanTitle => 'Rescan Gallery';

  @override
  String get galleryCache_rescanContent =>
      'This will:\n\n1. Check data consistency and mark missing files\n2. Scan new and changed files\n3. Retry metadata extraction that failed before, including failed records\n\nThis will not clear existing data or delete image files.';

  @override
  String get galleryCache_startScan => 'Start Scan';

  @override
  String get galleryCache_scanAlreadyRunning =>
      'A scan task is already running. Please wait for it to finish.';

  @override
  String get galleryCache_preparing => 'Preparing...';

  @override
  String get galleryCache_noGalleryFolder => 'Gallery folder is not set';

  @override
  String get galleryCache_galleryFolderMissing =>
      'Gallery folder does not exist';

  @override
  String galleryCache_scanningPhase(Object processed, Object total) {
    return 'Scanning $processed/$total...';
  }

  @override
  String get galleryCache_scanComplete => 'Scan complete';

  @override
  String galleryCache_scanFailed(Object error) {
    return 'Scan failed: $error';
  }

  @override
  String get galleryCache_rescan => 'Rescan';

  @override
  String get galleryCache_rescanSubtitle =>
      'Check data consistency, find missing files, and extract metadata';

  @override
  String get galleryCache_scanning => 'Scanning...';

  @override
  String get galleryCache_scanAction => 'Scan';

  @override
  String get workflowImport_title => 'Import ComfyUI Workflow';

  @override
  String workflowImport_step(Object current, Object title) {
    return 'Step $current/4: $title';
  }

  @override
  String get workflowImport_stepFile => 'Select Workflow File';

  @override
  String get workflowImport_stepInfo => 'Workflow Info';

  @override
  String get workflowImport_stepSlots => 'Confirm Slot Config';

  @override
  String get workflowImport_stepDone => 'Complete Import';

  @override
  String get workflowImport_previous => 'Previous';

  @override
  String get workflowImport_next => 'Next';

  @override
  String get workflowImport_finish => 'Finish Import';

  @override
  String get workflowImport_defaultName => 'Custom Workflow';

  @override
  String get workflowImport_fileInstructions =>
      'Select a workflow_api.json file exported from ComfyUI.\n\nIn ComfyUI, open the menu and choose Export (API format) to get this file.';

  @override
  String workflowImport_nodeCount(Object count) {
    return '$count nodes';
  }

  @override
  String get workflowImport_reselect => 'Click to choose another file';

  @override
  String get workflowImport_selectWorkflowApi =>
      'Click to select workflow_api.json';

  @override
  String get workflowImport_invalidTopLevel =>
      'Invalid file format: top level should be a JSON object';

  @override
  String get workflowImport_noComfyNodes =>
      'No ComfyUI nodes detected. Make sure this is an API-format export.';

  @override
  String workflowImport_readFailed(Object error) {
    return 'Failed to read file: $error';
  }

  @override
  String get workflowImport_analysisResult => 'Automatic Analysis Result';

  @override
  String get workflowImport_inputImageNodes => 'Input image nodes';

  @override
  String get workflowImport_adjustableParams => 'Adjustable parameters';

  @override
  String get workflowImport_outputNodes => 'Output nodes';

  @override
  String get workflowImport_totalNodes => 'Total nodes';

  @override
  String workflowImport_countUnit(Object count) {
    return '$count';
  }

  @override
  String get workflowImport_workflowName => 'Workflow Name *';

  @override
  String get workflowImport_description => 'Description';

  @override
  String get workflowImport_category => 'Category';

  @override
  String get workflowImport_slotsHint =>
      'Select the slots to expose in the UI. Input and output slots should usually stay enabled; parameters that users do not need to adjust can be disabled.';

  @override
  String get workflowImport_inputSection => 'Input';

  @override
  String get workflowImport_outputSection => 'Output';

  @override
  String get workflowImport_parameterSection => 'Parameters';

  @override
  String get workflowImport_noSlotsWarning =>
      'No usable slots were detected. This workflow may not integrate correctly.\nMake sure the workflow includes LoadImage and SaveImage/SaveImageWebsocket nodes.';

  @override
  String workflowImport_nodeRef(Object node) {
    return 'Node $node';
  }

  @override
  String get workflowImport_confirmTitle => 'About to import this workflow';

  @override
  String get workflowImport_name => 'Name';

  @override
  String get workflowImport_inputSlots => 'Input Slots';

  @override
  String get workflowImport_parameterSlots => 'Parameter Slots';

  @override
  String get workflowImport_outputSlots => 'Output Slots';

  @override
  String get workflowImport_afterImportHint =>
      'After import, it can be used from the ComfyUI workflow list on the generation screen.';

  @override
  String workflowImport_success(Object name) {
    return 'Workflow \"$name\" imported';
  }

  @override
  String get shortcut_settings_help => 'View shortcut help';

  @override
  String get shortcut_settings_show_in_menus => 'Show in menus';

  @override
  String shortcut_settings_defaultShortcut(Object shortcut) {
    return 'Default: $shortcut';
  }

  @override
  String get shortcut_settings_unassigned => 'Not set';

  @override
  String get shortcut_settings_no_matches => 'No matching shortcuts found';

  @override
  String get shortcut_settings_reset_all_title => 'Reset All Shortcuts';

  @override
  String get shortcut_settings_reset_all_confirm =>
      'Reset all shortcuts to their default settings? This cannot be undone.';

  @override
  String get shortcut_settings_reset_to_default => 'Reset to default';

  @override
  String get toast_previewUpdated => 'Preview image updated';

  @override
  String toast_styleReferenceLimit(Object max) {
    return 'Style References reached the limit ($max images)';
  }

  @override
  String get toast_noValidPromptFound => 'No valid prompt found';

  @override
  String toast_addedToQueue(Object prompt) {
    return 'Added to queue: $prompt';
  }

  @override
  String get toast_noValidMaskIgnored =>
      'No valid mask detected; save result was ignored.';

  @override
  String get toast_kritaBusy =>
      'Krita Bridge is generating. Wait for the current task to finish.';

  @override
  String get toast_kritaNotConnected =>
      'Krita is not connected. Enable the bridge in Settings and connect the plugin first.';

  @override
  String get toast_sentToKrita => 'Image sent to Krita';

  @override
  String get toast_kritaUnsupportedImageFormat =>
      'This image format cannot be sent to Krita. Use a common image format.';

  @override
  String toast_deletedNamed(Object name) {
    return 'Deleted: $name';
  }

  @override
  String get toast_vibeParamSaveReencodeFailed =>
      'Failed to save parameters because Vibe re-encoding failed';

  @override
  String get toast_exportSuccess => 'Export successful';

  @override
  String toast_exportFailed(Object error) {
    return 'Export failed: $error';
  }

  @override
  String get toast_selectVibeToExport => 'Select a Vibe to export first';

  @override
  String get toast_embedPngSingleVibeOnly =>
      'Embedding into PNG only supports exporting one Vibe';

  @override
  String get toast_selectPngCarrier => 'Select a PNG carrier image for export';

  @override
  String get toast_renameSuccess => 'Renamed successfully';

  @override
  String get toast_paramsSaved => 'Parameters saved';

  @override
  String get toast_paramsSaveFailed => 'Failed to save parameters';

  @override
  String get toast_dropNoReadableImageOrVibe =>
      'The drop source did not provide a readable image or Vibe file';

  @override
  String get toast_contentCannotBeEmpty => 'Content cannot be empty';

  @override
  String get toast_addedToLibrary => 'Added to library';

  @override
  String toast_addFailed(Object error) {
    return 'Add failed: $error';
  }

  @override
  String get toast_libraryNotLoaded => 'Library is not loaded';

  @override
  String get toast_noValidTagContent => 'No valid tag content';

  @override
  String get toast_allTagsAlreadyExist =>
      'All tags already exist in the library';

  @override
  String get toast_noAddableTags => 'No tags can be added';

  @override
  String toast_addedTagsSkippedDuplicates(Object added, Object skipped) {
    return 'Added $added tags, skipped $skipped duplicate tags';
  }

  @override
  String get toast_favorited => 'Favorited';

  @override
  String get toast_unfavorited => 'Unfavorited';

  @override
  String toast_favoriteUpdateFailed(Object error) {
    return 'Failed to update favorite state: $error';
  }

  @override
  String toast_packingImages(Object count) {
    return 'Packing $count images...';
  }

  @override
  String toast_packedImages(Object count) {
    return 'Packed $count images';
  }

  @override
  String get toast_packFailed => 'Pack failed';

  @override
  String toast_packFailedWithError(Object error) {
    return 'Pack failed: $error';
  }

  @override
  String get toast_saveDirNotSet => 'Save directory is not set';

  @override
  String toast_savedTo(Object path) {
    return 'Saved to $path';
  }

  @override
  String get toast_tagAlreadyExists => 'Tag already exists';

  @override
  String get toast_nameRequired => 'Enter a name';

  @override
  String get toast_savedToVibeLibrary => 'Saved to Vibe Library';

  @override
  String get toast_saveBundleFailed => 'Failed to save bundle';

  @override
  String get toast_saveEntryFailed => 'Failed to save entry';

  @override
  String get toast_presetNameRequired => 'Enter a preset name';

  @override
  String get toast_selectPresetContent => 'Select at least one item to save';

  @override
  String get toast_presetSaved => 'Preset saved successfully';

  @override
  String get toast_imagePromptCopied => 'Prompt copied';

  @override
  String get toast_imageHasNoPrompt => 'This image has no Prompt';

  @override
  String get toast_useDeleteButton => 'Use the delete button in the UI';

  @override
  String get toast_imageHasNoMetadata => 'This image has no metadata';

  @override
  String get toast_imageDataUnavailable =>
      'Image data is unavailable and cannot be copied';

  @override
  String get toast_vibeDataCopied => 'Vibe data copied';

  @override
  String get toast_tagCopied => 'Tags copied';

  @override
  String get toast_characterPromptCopied => 'Character prompt copied';

  @override
  String toast_copiedTitle(Object title) {
    return '$title copied';
  }

  @override
  String toast_replacedVibesCount(Object count, Object name) {
    return 'Replaced with $count Vibes: $name';
  }

  @override
  String toast_sentVibesCount(Object count, Object name) {
    return 'Sent $count Vibes to generation: $name';
  }

  @override
  String toast_replacedVibe(Object name) {
    return 'Replaced with: $name';
  }

  @override
  String toast_sentVibeToGeneration(Object name) {
    return 'Sent to generation: $name';
  }

  @override
  String get toast_unreadableDroppedImageSource =>
      'The drop source did not provide a readable image file or image URL';

  @override
  String toast_appendedStyleReferences(Object count) {
    return 'Appended $count Style References';
  }

  @override
  String get toast_appendedPreencodedVibe =>
      'Appended 1 Style Reference (reused pre-encoded Vibe)';

  @override
  String get toast_addedPreencodedVibe =>
      'Added Style Reference (reused pre-encoded Vibe, saved 2 Anlas)';

  @override
  String toast_vibesMissingEncoding(Object count) {
    return '$count Vibes are missing encoded data and cannot be saved';
  }

  @override
  String toast_savedBundle(Object count) {
    return 'Saved Bundle ($count Vibes)';
  }

  @override
  String toast_extractMetadataFailed(Object error) {
    return 'Failed to extract metadata: $error';
  }

  @override
  String toast_extractPromptFailed(Object error) {
    return 'Failed to extract prompt: $error';
  }

  @override
  String get toast_smartDecomposeSent => 'Smart decomposed and sent';

  @override
  String get toast_addedToFixedTags => 'Added to fixed tags';

  @override
  String get toast_renameNameRequired => 'Name is required';

  @override
  String get toast_renameNameConflict =>
      'Name already exists. Use another name.';

  @override
  String get toast_renameEntryNotFound =>
      'The entry no longer exists and may have been deleted';

  @override
  String get toast_renameFilePathMissing =>
      'This entry has no file path and cannot be renamed';

  @override
  String get toast_renameFileFailed =>
      'Failed to rename file. Try again later.';

  @override
  String get toast_renameFailed => 'Rename failed. Try again later.';

  @override
  String toast_processImageFailed(Object error) {
    return 'Failed to process image: $error';
  }

  @override
  String get toast_savePreviewFailed => 'Failed to save preview image';

  @override
  String get common_justNow => 'Just now';

  @override
  String common_minutesAgo(Object minutes) {
    return '$minutes minutes ago';
  }

  @override
  String common_hoursAgo(Object hours) {
    return '$hours hours ago';
  }

  @override
  String get common_saving => 'Saving...';

  @override
  String get common_pleaseWait => 'Please wait';

  @override
  String get common_change => 'Change';

  @override
  String get common_expand => 'Expand';

  @override
  String get common_collapse => 'Collapse';

  @override
  String get vibeLibrary_emptySearchTitle => 'No matching Vibes';

  @override
  String get vibeLibrary_emptySearchSubtitle => 'Try a different keyword';

  @override
  String get vibeLibrary_emptyFavoritesTitle => 'No favorite Vibes yet';

  @override
  String get vibeLibrary_emptyFavoritesSubtitle =>
      'Click the heart icon to favorite a Vibe';

  @override
  String get vibeLibrary_emptyCategoryTitle => 'No Vibes in this category';

  @override
  String get vibeLibrary_emptyCategorySubtitle =>
      'Switch to \"All Vibes\" to see all entries';

  @override
  String get vibeLibrary_emptyNoMatchesTitle => 'No matching results';

  @override
  String get vibeLibrary_emptySaveFromGenerationHint =>
      'Save Vibes from the generation page to add them to the library';

  @override
  String get vibe_nameRequired => 'Name is required';

  @override
  String get vibe_import_namingTitle => 'Name Vibe';

  @override
  String get vibe_import_nameConflictOverwrite =>
      'This name already exists and will be overwritten';

  @override
  String get vibe_previewLoadFailed => 'Failed to load preview';

  @override
  String get vibe_import_applyToRemainingFiles =>
      'Apply to all remaining files';

  @override
  String get vibe_import_applyNamingToRemainingFiles =>
      'Use this naming rule for the remaining files';

  @override
  String get vibe_encodeImageTitle => 'Encode Image as Vibe';

  @override
  String get vibe_imagePreview => 'Image preview';

  @override
  String get vibe_encodeStartButton => 'Start Encoding';

  @override
  String get vibe_encodeImageInProgress => 'Encoding image...';

  @override
  String vibe_encodeErrorImage(Object fileName) {
    return 'Image: $fileName';
  }

  @override
  String vibe_encodeErrorMessage(Object error) {
    return 'Error: $error';
  }

  @override
  String get vibe_encodeSkipImage => 'Skip this image';

  @override
  String get detail_sendToImg2Img => 'Send to Image2Image';

  @override
  String get detail_sendToReversePrompt => 'Send to Reverse Prompt';

  @override
  String get detail_loadingImage => 'Loading image...';

  @override
  String get detail_imageLoadFailed => 'Failed to load image';

  @override
  String get detail_noImage => 'No image';

  @override
  String get detail_parsingMetadata => 'Parsing metadata...';

  @override
  String get detail_noMetadata => 'This image has no metadata';

  @override
  String get detail_metadata => 'Metadata';

  @override
  String get detail_imageDetails => 'Image Details';

  @override
  String get detail_basicInfo => 'Basic Info';

  @override
  String get detail_fileName => 'File Name';

  @override
  String get detail_modifiedTime => 'Modified';

  @override
  String get detail_fileSize => 'File Size';

  @override
  String get detail_noContent => '(No content)';

  @override
  String get detail_savePreset => 'Save Preset';

  @override
  String detail_copyLabel(Object label) {
    return 'Copy $label';
  }

  @override
  String get detail_copyPromptTitle => 'Copy Positive Prompt';

  @override
  String get detail_copyPromptDescription =>
      'Select the prompt categories to copy. Fixed tags may contain private strings or personal markers, so review them before sharing.';

  @override
  String get detail_promptCategoryMain => 'Subject prompt';

  @override
  String get detail_promptCategoryMainHint =>
      'Subject, scene, and general descriptions';

  @override
  String get detail_promptCategoryCharacters => 'Character prompts';

  @override
  String get detail_promptCategoryCharactersHint =>
      'Prompts assigned to individual characters';

  @override
  String get detail_promptCategoryQuality => 'Quality tags';

  @override
  String get detail_promptCategoryQualityHint =>
      'Official quality preset and automatic transparent-background tag';

  @override
  String get detail_promptCategoryFixed => 'Fixed tags';

  @override
  String get detail_promptCategoryFixedHint =>
      'Fixed prefixes and suffixes that may contain private content';

  @override
  String get detail_promptCategoryUnavailable =>
      'This category is not stored in the image';

  @override
  String get detail_copyPromptDefaultHint =>
      'Subject and character prompts are selected by default; quality and fixed tags are excluded.';

  @override
  String get detail_copyCharacterPrompt => 'Copy Character Prompt';

  @override
  String get detail_copyAllVibeData => 'Copy all Vibe data';

  @override
  String get detail_saveToVibeLibrary => 'Save to Vibe Library';

  @override
  String get pagination_firstPage => 'First page';

  @override
  String get pagination_previousPage => 'Previous page';

  @override
  String get pagination_nextPage => 'Next page';

  @override
  String get pagination_lastPage => 'Last page';

  @override
  String get pagination_jumpToPage => 'Jump to page';

  @override
  String get pagination_jump => 'Jump';

  @override
  String get pagination_itemsPerPage => 'Per page';

  @override
  String get pagination_itemUnit => 'items';

  @override
  String get diyGuide_title => 'DIY Feature Guide';

  @override
  String get diyGuide_subtitle =>
      'Learn advanced features and create your own library';

  @override
  String get diyGuide_intro =>
      'This guide explains the core concepts and advanced features of the DIY system, helping you build powerful dynamic prompt libraries.';

  @override
  String get diyGuide_exampleLabel => 'Example';

  @override
  String get diyGuide_hierarchyTitle => 'Hierarchy';

  @override
  String get diyGuide_hierarchyDescription =>
      'The DIY system uses a three-level category structure to organize prompts for easier management and lookup.';

  @override
  String get diyGuide_hierarchyExample =>
      'Category: Character features\n  -> Group: Hairstyle\n      -> Tag: long hair, short hair, twintails';

  @override
  String get diyGuide_selectionModeTitle => 'Selection Mode';

  @override
  String get diyGuide_selectionModeDescription =>
      'Controls how many tags are selected from a group.';

  @override
  String get diyGuide_selectionModeExample =>
      '• Random: select one item each time, such as a random hair color\n• All: select every tag in the group, such as a fixed feature set';

  @override
  String get diyGuide_weightTitle => 'Weight Control';

  @override
  String get diyGuide_weightDescription =>
      'Adjusts the influence of specific prompts during generation.';

  @override
  String get diyGuide_weightExample =>
      '• Boost: curly brackets around masterpiece = 1.05x weight\n• Strong boost: triple curly brackets around masterpiece = 1.16x weight\n• Weaken: [bad hands] = 0.95x weight';

  @override
  String get diyGuide_genderTitle => 'Gender Restriction';

  @override
  String get diyGuide_genderDescription =>
      'Limits tags to specific character genders to avoid incompatible generated features.';

  @override
  String get diyGuide_genderExample =>
      '• Female: only female characters, such as skirt\n• Male: only male characters, such as beard\n• Any: universal, such as T-shirt';

  @override
  String get diyGuide_scopeTitle => 'Scope';

  @override
  String get diyGuide_scopeDescription =>
      'Defines whether a tag applies to the character, background, or the whole image.';

  @override
  String get diyGuide_scopeExample =>
      '• Character: character features, such as eyes and hair\n• Background: environment descriptions, such as blue sky and indoors\n• Global: art style and quality tags, such as best quality';

  @override
  String get diyGuide_conditionalTitle => 'Conditional Branch';

  @override
  String get diyGuide_conditionalDescription =>
      'Dynamically chooses later tags based on selected tags or other conditions.';

  @override
  String get diyGuide_conditionalExample =>
      'IF selected \"rain\"\n  THEN add \"umbrella\" and \"wet clothes\"\n  ELSE add \"sunny\"';

  @override
  String get diyGuide_dependenciesTitle => 'Dependencies';

  @override
  String get diyGuide_dependenciesDescription =>
      'Creates links between tags so related tags are automatically introduced when one tag is selected.';

  @override
  String get diyGuide_dependenciesExample =>
      'Selecting \"JK uniform\" -> automatically adds \"school background\" and \"school bag\"';

  @override
  String get diyGuide_visibilityTitle => 'Visibility Rules';

  @override
  String get diyGuide_visibilityDescription =>
      'Controls when tags are shown in the UI or become active during generation.';

  @override
  String get diyGuide_visibilityExample =>
      'Only show the \"magic wand\" option group when the \"magical girl\" category is selected';

  @override
  String get diyGuide_timeTitle => 'Time Condition';

  @override
  String get diyGuide_timeDescription =>
      'Triggers specific tags based on real time or configured simulated time.';

  @override
  String get diyGuide_timeExample =>
      '• 06:00-18:00 -> add \"daylight\"\n• 18:00-06:00 -> add \"night\"';

  @override
  String get diyGuide_postProcessingTitle => 'Post-processing Rules';

  @override
  String get diyGuide_postProcessingDescription =>
      'Runs text replacement or cleanup at the final stage of prompt generation.';

  @override
  String get diyGuide_postProcessingExample =>
      'Replace every \"blue eyes\" with \"azure eyes\" for a more distinctive description';

  @override
  String get diyGuide_emphasisTitle => 'Emphasis Probability';

  @override
  String get diyGuide_emphasisDescription =>
      'Randomly adds weight syntax to tags to increase output variety.';

  @override
  String get diyGuide_emphasisExample =>
      'Set a 30% probability: about 1/3 of outputs use a weighted tag and 2/3 output the plain tag';

  @override
  String get naiRules_title => 'NAI Random Rules';

  @override
  String get naiRules_characterCountProbability =>
      'Character Count Probability';

  @override
  String get naiRules_solo => '1 person (Solo)';

  @override
  String get naiRules_duo => '2 people (Duo)';

  @override
  String get naiRules_trio => '3 people (Trio)';

  @override
  String get naiRules_group => '4 people (Group)';

  @override
  String get naiRules_genderRules => 'Gender Rules';

  @override
  String get naiRules_female => 'Female';

  @override
  String get naiRules_male => 'Male';

  @override
  String get naiRules_mixed => 'Mixed / Other';

  @override
  String get naiRules_categoryProbability => 'Category Probability';

  @override
  String get naiRules_dynamicTagWeightTitle => 'Dynamic Tag Weight Adjustment';

  @override
  String get naiRules_dynamicTagWeightSubtitle =>
      'Randomly combines multiple dimensions such as action, clothing, expression, and background, then adjusts category weights based on the image theme.';

  @override
  String get naiRules_specialMechanisms => 'Special Mechanisms';

  @override
  String get naiRules_tagStrengthening => 'Tag Strengthening';

  @override
  String get naiRules_seasonalLibraryTitle => 'Seasonal Library';

  @override
  String get naiRules_seasonalLibrarySubtitle =>
      'Automatically matches seasonal features, including seasonal clothing, weather, lighting, and atmosphere.';

  @override
  String get naiRules_v4CharacterPositioning =>
      'V4 Multi-character Positioning';

  @override
  String get naiRules_smartPositionTitle => 'Smart Position Assignment';

  @override
  String get naiRules_smartPositionSubtitle =>
      'With V4 models, character positioning syntax is used to precisely control multi-character placement.';

  @override
  String get comfyImport_detectedTitle =>
      'Detected ComfyUI multi-character prompt';

  @override
  String comfyImport_characterList(Object count) {
    return 'Character List ($count)';
  }

  @override
  String get comfyImport_usePositionInfo => 'Use position information';

  @override
  String get comfyImport_usePositionInfoSubtitle =>
      'Map ComfyUI regions to NAI character positions';

  @override
  String comfyImport_convertCharacters(Object count) {
    return 'Convert $count characters';
  }

  @override
  String get comfyImport_syntaxCouple => 'COUPLE syntax';

  @override
  String get comfyImport_syntaxAndMask => 'AND+MASK syntax';

  @override
  String get comfyImport_syntaxPipe => 'Pipe format';

  @override
  String get comfyImport_syntaxUnknown => 'Unknown syntax';

  @override
  String get comfyImport_globalPrompt => 'Global Prompt';

  @override
  String get danbooruPreview_noTagData => 'No tag data';

  @override
  String get danbooruPreview_noPoolData => 'No Pool data';

  @override
  String danbooruPreview_postCount(Object count) {
    return '$count posts';
  }

  @override
  String get checkForUpdate => 'Check for Updates';

  @override
  String get neverChecked => 'Never checked';

  @override
  String lastCheckedAt(Object time) {
    return 'Last checked: $time';
  }

  @override
  String get includePrereleaseUpdates => 'Include Prerelease Versions';

  @override
  String get includePrereleaseUpdatesDescription =>
      'Include beta/alpha versions when checking for updates';

  @override
  String get updateAvailable => 'Update Available';

  @override
  String get updateChecking => 'Checking for updates...';

  @override
  String get updateDownloading => 'Downloading update...';

  @override
  String get updateInstalling => 'Starting installer...';

  @override
  String get updateUpToDate => 'Already up to date';

  @override
  String get updateError => 'Failed to check for updates';

  @override
  String get updateErrorNetwork =>
      'Unable to reach the update server. Check your network or proxy settings and try again.';

  @override
  String get updateErrorServerBusy =>
      'The update server is busy. Please try again later.';

  @override
  String get updateErrorReleaseNotReady =>
      'The latest release files are not ready yet. Please try again later.';

  @override
  String get updateErrorServiceUnavailable =>
      'The update server is temporarily unavailable. Please try again later.';

  @override
  String get updateErrorInvalidMetadata =>
      'Update information could not be verified. Try again later or download from the Release page.';

  @override
  String get updateErrorUnknown =>
      'Unable to check for updates right now. Please try again later.';

  @override
  String get currentVersion => 'Current Version';

  @override
  String get latestVersion => 'Latest Version';

  @override
  String get releaseNotes => 'Release Notes';

  @override
  String get viewReleasePage => 'View Release';

  @override
  String get updatePortableManualHint =>
      'This build cannot update in-app. Please download the new version from the Release page.';

  @override
  String updateDownloadingProgress(Object percent) {
    return 'Downloading update package: $percent%';
  }

  @override
  String updateDownloadSizeSpeed(Object received, Object total, Object speed) {
    return '$received / $total · $speed';
  }

  @override
  String get updateDownloaded => 'Update Package Ready';

  @override
  String updateDownloadedHint(Object version) {
    return 'v$version has been downloaded and verified. Installing will close the app and restart it automatically.';
  }

  @override
  String get updateInstallAndRestart => 'Install and Restart';

  @override
  String get updateInstallNow => 'Install Now';

  @override
  String get updateInstallLater => 'Install Later';

  @override
  String get updateDownload => 'Download Update';

  @override
  String get updateDownloadCancelled =>
      'Download cancelled; you can resume later';

  @override
  String get updateDownloadFailed => 'Failed to download the update';

  @override
  String get updateInstallFailed => 'Failed to install the update';

  @override
  String get updateInstallingHint =>
      'The installer has started. The app will close and finish updating automatically.';

  @override
  String get updateInstallConfirmationTitle => 'Install the update now?';

  @override
  String get updateInstallConfirmationBody =>
      'The app will shut down safely, install the update, and restart automatically. Active generation and download tasks will stop, so save anything important first.';

  @override
  String get updateActiveTasksWarning =>
      'Queue tasks are still active. Installing will stop the current task.';

  @override
  String get remindMeLater => 'Remind Me in 4 Hours';

  @override
  String get skipThisVersion => 'Skip This Version';

  @override
  String updateNoticeAvailable(Object version) {
    return 'Version v$version is available';
  }

  @override
  String get updateNoticeAvailableSubtitle =>
      'Download and finish the update automatically in the app';

  @override
  String get updateNoticeManualSubtitle =>
      'This platform must be updated manually from the Release page';

  @override
  String updateNoticeReady(Object version) {
    return 'Version v$version is ready';
  }

  @override
  String get updateNoticeReadySubtitle =>
      'The package is verified and ready to install on restart';

  @override
  String get updateNoticeFailed => 'The previous update did not finish';

  @override
  String get updateViewDetails => 'View Update';

  @override
  String updateSettingsAvailable(Object version) {
    return 'v$version is available; select to view details';
  }

  @override
  String updateSettingsReady(Object version) {
    return 'v$version is downloaded; select to install';
  }

  @override
  String get goToDownload => 'Go to Download';

  @override
  String get versionSkipped => 'Version skipped';

  @override
  String get cannotOpenUrl => 'Cannot open link';

  @override
  String get model3d_editorTitle => '3D Model Layer';

  @override
  String get model3d_addMannequin => 'Add Built-in Mannequin';

  @override
  String get model3d_importModel => 'Import Model (.glb/.gltf)';

  @override
  String get model3d_emptyHint =>
      'Scene is empty. Add a mannequin or import a model.';

  @override
  String get model3d_apply => 'Apply to Layer';

  @override
  String get model3d_modeTransform => 'Transform';

  @override
  String get model3d_modePose => 'Pose';

  @override
  String get model3d_gizmoTranslate => 'Move';

  @override
  String get model3d_gizmoRotate => 'Rotate';

  @override
  String get model3d_gizmoScale => 'Scale';

  @override
  String get model3d_undo => 'Undo';

  @override
  String get model3d_resetPose => 'Reset Pose';

  @override
  String get model3d_replaceConfirm =>
      'Replace the current model? Unapplied pose will be lost.';

  @override
  String get model3d_discardConfirm => 'Discard unapplied changes?';

  @override
  String get model3d_missingModel =>
      'Model file is missing. You can re-import it.';

  @override
  String get model3d_loadError => 'Failed to load model';

  @override
  String get model3d_light => 'Lighting';

  @override
  String get model3d_lightIntensity => 'Intensity';

  @override
  String get model3d_lightAzimuth => 'Azimuth';

  @override
  String get model3d_lightElevation => 'Elevation';

  @override
  String get model3d_addLayerTooltip => 'Add 3D Model Layer';

  @override
  String get model3d_webview2Missing =>
      'The 3D editor requires the Microsoft Edge WebView2 Runtime. It ships with Windows 10/11; if missing, install the Evergreen runtime from Microsoft and retry.';

  @override
  String get nav_preciseRefLibrary => 'Precise Ref Library';

  @override
  String get preciseRefLib_title => 'Precise Reference Library';

  @override
  String get preciseRefLib_searchHint => 'Search references...';

  @override
  String get preciseRefLib_empty =>
      'Drop or paste images here to build your library';

  @override
  String get preciseRefLib_emptyHint =>
      'You can also right-click images in preview, history, or gallery to save them here';

  @override
  String get preciseRefLib_import => 'Import Images';

  @override
  String preciseRefLib_entryCount(int count) {
    return '$count items';
  }

  @override
  String get preciseRefLib_sendToPreciseRef => 'Send to Precise Reference';

  @override
  String get preciseRefLib_sendToImg2Img => 'Send to Image to Image';

  @override
  String get preciseRefLib_editEntry => 'Edit Parameters';

  @override
  String get preciseRefLib_deleteEntry => 'Delete';

  @override
  String get preciseRefLib_confirmDeleteTitle => 'Delete Entry';

  @override
  String preciseRefLib_confirmDelete(String name) {
    return 'Delete \"$name\"? The image file will also be removed.';
  }

  @override
  String preciseRefLib_saved(String name) {
    return 'Saved \"$name\" to Precise Ref Library';
  }

  @override
  String get preciseRefLib_savedHint =>
      'You can edit parameters in the library';

  @override
  String preciseRefLib_sent(String name) {
    return 'Sent \"$name\" to Precise Reference';
  }

  @override
  String preciseRefLib_sentToImg2Img(String name) {
    return 'Sent \"$name\" to Image to Image';
  }

  @override
  String get preciseRefLib_imageMissing => 'Image file is missing';

  @override
  String get preciseRefLib_invalidImage =>
      'The image format is unsupported or the file is corrupt';

  @override
  String get preciseRefLib_deleteFailed =>
      'Delete failed. The entry and original image were kept; try again later';

  @override
  String get preciseRefLib_favoritesOnly => 'Favorites only';

  @override
  String get preciseRefLib_sortBy => 'Sort by';

  @override
  String get preciseRefLib_sortCreatedAt => 'Created';

  @override
  String get preciseRefLib_sortLastUsed => 'Last used';

  @override
  String get preciseRefLib_sortUsedCount => 'Most used';

  @override
  String get preciseRefLib_sortName => 'Name';

  @override
  String preciseRefLib_importedCount(int count) {
    return 'Imported $count images';
  }

  @override
  String preciseRefLib_loadFailed(String error) {
    return 'Failed to load the Precise Reference Library: $error';
  }

  @override
  String preciseRefLib_importFailed(String error) {
    return 'Failed to save to the Precise Reference Library: $error';
  }

  @override
  String preciseRefLib_importFailedCount(int count) {
    return '$count images could not be imported into the Precise Reference Library';
  }

  @override
  String get preciseRefLib_fromLibrary => 'From Library';

  @override
  String get preciseRefLib_saveCurrentToLibrary => 'Save to Library';

  @override
  String preciseRefLib_saveCurrentCount(int count) {
    return 'Saved $count references to library';
  }

  @override
  String get preciseRefLib_selectorTitle => 'Select from Precise Ref Library';

  @override
  String preciseRefLib_selectorConfirm(int count) {
    return 'Add Selected ($count)';
  }

  @override
  String get preciseRefLib_nameLabel => 'Name';

  @override
  String get preciseRefLib_typeFilterAll => 'All';

  @override
  String get img2img_fromPreciseRefLibrary => 'From Precise Ref Library';

  @override
  String get localGallery_saveToPreciseRefLibrary =>
      'Save to Precise Ref Library';

  @override
  String get drop_saveToPreciseRefLibrary => 'Save to Precise Ref Library';

  @override
  String get common_enabled => 'Enabled';

  @override
  String get common_disabled => 'Disabled';

  @override
  String bulkAction_selectedCount(int count) {
    return '$count selected';
  }

  @override
  String get comfyTask_errorConnectionFailed =>
      'Unable to connect to the ComfyUI server';

  @override
  String get comfyTask_errorConnectionUnavailable =>
      'The ComfyUI connection is unavailable';

  @override
  String get comfyTask_errorExecutionFailedGeneric =>
      'ComfyUI execution failed';

  @override
  String comfyTask_errorExecutionFailed(String error) {
    return 'ComfyUI execution failed: $error';
  }

  @override
  String get comfyTask_errorTimeout =>
      'The ComfyUI task timed out after 10 minutes';

  @override
  String comfyTask_errorWorkflowNotFound(String workflowId) {
    return 'Workflow not found: $workflowId';
  }

  @override
  String get comfyWorkflowSlot_vaeEncodeTileSize => 'VAE encode tile size';

  @override
  String get comfyWorkflowSlot_vaeDecodeTileSize => 'VAE decode tile size';

  @override
  String get comfyWorkflowSlot_blocksToSwap => 'Blocks to swap';

  @override
  String get comfyWorkflowSlot_swapIoComponents => 'Swap I/O components';

  @override
  String localGallery_firstIndexHint(int count) {
    return 'Detected $count images. The initial index may take a few minutes; you can continue using the app.';
  }

  @override
  String get localGallery_errorPermissionDenied =>
      'Unable to access the image folder. Check the folder permissions.';

  @override
  String localGallery_errorScanFailed(String error) {
    return 'Failed to scan images: $error';
  }

  @override
  String localGallery_errorInitializationFailed(String error) {
    return 'Failed to initialize the gallery: $error';
  }

  @override
  String get localGallery_errorServiceInitializing =>
      'The gallery service is still initializing. Try again shortly.';

  @override
  String localGallery_errorDatabaseFailed(String error) {
    return 'Gallery database error: $error';
  }

  @override
  String localGallery_errorRefreshFailed(String error) {
    return 'Failed to refresh the gallery: $error';
  }

  @override
  String localGallery_errorFilterFailed(String error) {
    return 'Failed to apply gallery filters: $error';
  }

  @override
  String localGallery_errorFavoriteFailed(String error) {
    return 'Failed to update the favorite status: $error';
  }

  @override
  String localGallery_errorRebuildFailed(String error) {
    return 'Failed to rebuild the gallery index: $error';
  }

  @override
  String get diy_editDependencyTitle => 'Edit Dependency';

  @override
  String get diy_dependencyTitle => 'Dependency Settings';

  @override
  String get diy_dependencySubtitle =>
      'Configure dependencies between tag selections';

  @override
  String get diy_dependencyType => 'Dependency Type';

  @override
  String get diy_sourceCategory => 'Source Category';

  @override
  String get diy_selectSourceCategory => 'Select a source category';

  @override
  String get diy_sourceCategoryId => 'Source Category ID';

  @override
  String get diy_enterCategoryId => 'Enter a category ID';

  @override
  String get diy_mappingRules => 'Mapping Rules';

  @override
  String get diy_noMappingRules => 'No mapping rules';

  @override
  String get diy_deleteRule => 'Delete rule';

  @override
  String get diy_defaultValue => 'Default Value';

  @override
  String get diy_defaultValueHint => 'Used when no mapping rule matches';

  @override
  String get diy_enableDependency => 'Enable Dependency';

  @override
  String get diy_enableDependencyHint =>
      'This dependency is ignored while disabled';

  @override
  String get diy_addMappingRule => 'Add Mapping Rule';

  @override
  String get diy_sourceValue => 'Source Value';

  @override
  String get diy_sourceValueHint => 'For example: 1, 2, 3';

  @override
  String get diy_resultValue => 'Result Value';

  @override
  String get diy_resultValueHint => 'For example: 0-3, 0-2, 0-1';

  @override
  String get diy_dependencyCount => 'Count';

  @override
  String get diy_dependencyExists => 'Exists';

  @override
  String get diy_dependencyValue => 'Value';

  @override
  String get diy_dependencyExcludes => 'Excludes';

  @override
  String get diy_dependencyCountDescription =>
      'Use the selected count in the source category to determine the result count';

  @override
  String get diy_dependencyExistsDescription =>
      'Apply only when the source category has at least one selected tag';

  @override
  String get diy_dependencyValueDescription =>
      'Depend on a specific selected tag value in the source category';

  @override
  String get diy_dependencyExcludesDescription =>
      'Do not apply when the source category has a selected tag';

  @override
  String get diy_editConditionalTitle => 'Edit Conditional Branches';

  @override
  String get diy_conditionalDefaultName => 'Conditional Branches';

  @override
  String diy_branchDefaultName(int index) {
    return 'Branch $index';
  }

  @override
  String get diy_conditionalTitle => 'Conditional Branches';

  @override
  String get diy_conditionalSubtitle => 'Choose a branch by probability';

  @override
  String diy_branchCount(int count) {
    return '$count branches';
  }

  @override
  String get diy_noConditionalBranches => 'No conditional branches';

  @override
  String get diy_noConditionalBranchesHint =>
      'Add branches to build conditional selection logic';

  @override
  String diy_conditionCount(int count) {
    return '$count conditions';
  }

  @override
  String get diy_deleteBranch => 'Delete branch';

  @override
  String get diy_addBranch => 'Add Branch';

  @override
  String diy_editBranch(String name) {
    return 'Edit: $name';
  }

  @override
  String get diy_branchName => 'Branch Name';

  @override
  String get diy_probability => 'Probability';

  @override
  String get diy_enableBranch => 'Enable This Branch';

  @override
  String diy_ruleDefaultName(int index) {
    return 'Rule $index';
  }

  @override
  String diy_ruleCount(int count) {
    return '$count rules';
  }

  @override
  String get diy_addRule => 'Add Rule';

  @override
  String get diy_editRule => 'Edit Rule';

  @override
  String get diy_ruleName => 'Rule Name';

  @override
  String get diy_enableRule => 'Enable This Rule';

  @override
  String get diy_postProcessTitle => 'Post-processing Rules';

  @override
  String get diy_postProcessSubtitle => 'Automatically resolve tag conflicts';

  @override
  String get diy_sleepingRule => 'Sleeping Rule';

  @override
  String get diy_sleepingRuleDescription =>
      'Remove eye-color descriptions when the character is sleeping';

  @override
  String get diy_mermaidRule => 'Mermaid Rule';

  @override
  String get diy_mermaidRuleDescription =>
      'Remove legwear descriptions for mermaids, centaurs, lamias, and similar characters';

  @override
  String get diy_presetRules => 'Preset Rules';

  @override
  String get diy_noPostProcessRules => 'No post-processing rules';

  @override
  String get diy_noPostProcessRulesHint =>
      'Add rules to resolve tag conflicts automatically';

  @override
  String get diy_actionType => 'Action Type';

  @override
  String get diy_triggerTags => 'Trigger Tags';

  @override
  String get diy_commaSeparatedTagsHint => 'Comma-separated tag list';

  @override
  String get diy_targetCategories => 'Target Categories';

  @override
  String get diy_commaSeparatedCategoryIdsHint =>
      'Comma-separated category ID list';

  @override
  String get diy_targetTags => 'Target Tags';

  @override
  String get diy_actionRemoveTags => 'Remove Tags';

  @override
  String get diy_actionReplaceTags => 'Replace Tags';

  @override
  String get diy_actionAddTags => 'Add Tags';

  @override
  String get diy_actionRemoveCategories => 'Remove Categories';

  @override
  String get diy_noTriggers => 'No triggers';

  @override
  String diy_actionSummary(String triggers, String action) {
    return 'When [$triggers] matches: $action';
  }

  @override
  String get diy_characterPositionTitle => 'Character Position';

  @override
  String get diy_characterPositionSubtitle =>
      'Visually edit character positions';

  @override
  String get diy_addCharacterPosition => 'Add Character Position';

  @override
  String get diy_addCharacterPositionHint =>
      'Use the button below to add a character position';

  @override
  String diy_characterIndex(int index) {
    return 'Character $index';
  }

  @override
  String get diy_aiPositionChoice => 'AI chooses automatically';

  @override
  String diy_positionCoordinates(String row, String column) {
    return 'Row: $row%, Column: $column%';
  }

  @override
  String get diy_customPosition => 'Custom';

  @override
  String diy_emphasisPercent(String percent) {
    return 'Emphasis $percent%';
  }

  @override
  String get diy_characterCountWeight => 'Character Count Weights';

  @override
  String diy_peopleCount(int count) {
    return '$count people';
  }

  @override
  String get diy_genderProbability => 'Gender Probability';

  @override
  String get diy_noWeightsConfigured => 'No weights configured';

  @override
  String get diy_genderOther => 'Other';

  @override
  String get diy_emphasisTitle => 'Global Emphasis';

  @override
  String get diy_emphasisSubtitle => 'Adjust tag emphasis effects';

  @override
  String get diy_emphasisProbability => 'Emphasis Probability';

  @override
  String diy_emphasisProbabilityHint(String percent) {
    return 'Each selected tag has a $percent% chance of receiving emphasis brackets';
  }

  @override
  String get diy_bracketCount => 'Bracket Layers';

  @override
  String diy_bracketLayers(int count) {
    return '$count layers';
  }

  @override
  String get diy_effectPreview => 'Effect Preview';

  @override
  String get diy_exampleTag => 'example tag';

  @override
  String get diy_emphasisExplanation =>
      'Emphasis brackets increase tag weight; more layers apply a higher weight';

  @override
  String diy_presetExportFailed(String error) {
    return 'Failed to export preset: $error';
  }

  @override
  String get diy_presetJsonRootObject => 'The JSON root must be an object';

  @override
  String diy_presetInvalidData(String error) {
    return 'Invalid preset data: $error';
  }

  @override
  String get diy_presetExportTitle => 'Export Preset';

  @override
  String get diy_presetImportTitle => 'Import Preset';

  @override
  String get diy_unknown => 'Unknown';

  @override
  String get diy_presetShareHint =>
      'Copy the content below to share it with others';

  @override
  String get diy_presetPasteJsonHint => 'Paste preset JSON data here...';

  @override
  String get diy_presetPreview => 'Preset Preview';

  @override
  String get diy_name => 'Name';

  @override
  String get diy_description => 'Description';

  @override
  String get diy_categoryCount => 'Categories';

  @override
  String get diy_totalTagCount => 'Total Tags';

  @override
  String get diy_visibilityTitle => 'Visibility Rules';

  @override
  String get diy_visibilitySubtitle =>
      'Control category visibility with conditions';

  @override
  String get diy_noVisibilityRules => 'No visibility rules';

  @override
  String get diy_noVisibilityRulesHint =>
      'Add rules to control category visibility from the current composition';

  @override
  String get diy_notSet => 'Not set';

  @override
  String get diy_targetCategory => 'Target Category';

  @override
  String get diy_conditionType => 'Condition Type';

  @override
  String get diy_conditionValue => 'Condition Value';

  @override
  String get diy_conditionValueHint => 'Tag name or value';

  @override
  String get diy_visibleWhenMatched => 'Visible When Matched';

  @override
  String get diy_conditionTagExists => 'Tag Exists';

  @override
  String get diy_conditionTagNotExists => 'Tag Does Not Exist';

  @override
  String get diy_conditionValueEquals => 'Value Equals';

  @override
  String get diy_conditionValueNotEquals => 'Value Does Not Equal';

  @override
  String get diy_conditionValueInList => 'Value Is in List';

  @override
  String get diy_conditionValueNotInList => 'Value Is Not in List';

  @override
  String get diy_editTimeConditionTitle => 'Edit Time Condition';

  @override
  String get diy_timeDefaultName => 'Time Condition';

  @override
  String get diy_timeTitle => 'Time Condition';

  @override
  String get diy_timeSubtitle => 'Activate within a specific date range';

  @override
  String get diy_enableTimeCondition => 'Enable Time Condition';

  @override
  String get diy_enableTimeConditionHint =>
      'Apply only within the configured date range';

  @override
  String get diy_christmas => 'Christmas';

  @override
  String get diy_christmasDescription =>
      'Christmas tags, active from December 1 through 31';

  @override
  String get diy_halloween => 'Halloween';

  @override
  String get diy_halloweenDescription =>
      'Halloween tags, active from October 1 through 31';

  @override
  String get diy_valentinesDay => 'Valentine\'s Day';

  @override
  String get diy_valentinesDescription =>
      'Valentine\'s Day tags, active from February 1 through 14';

  @override
  String get diy_presetTemplates => 'Preset Templates';

  @override
  String get diy_dateRange => 'Date Range';

  @override
  String get diy_startDate => 'Start Date';

  @override
  String get diy_endDate => 'End Date';

  @override
  String get diy_crossYearUnsupported =>
      'Date ranges that cross into a new year are not supported yet';

  @override
  String get diy_month => 'Month';

  @override
  String get diy_day => 'Day';

  @override
  String get diy_conditionName => 'Condition Name';

  @override
  String get diy_conditionNameHint => 'Enter a condition name';

  @override
  String get diy_repeatYearly => 'Repeat Yearly';

  @override
  String get diy_repeatYearlyHint =>
      'Activate automatically during the same date range every year';

  @override
  String get diy_currentlyActive => 'Currently Active';

  @override
  String get diy_inactive => 'Inactive';

  @override
  String diy_daysRemaining(int count) {
    return '$count days remaining';
  }

  @override
  String diy_timeRangeSummary(
    String name,
    int startMonth,
    int startDay,
    int endMonth,
    int endDay,
  ) {
    return '$name ($startMonth/$startDay - $endMonth/$endDay)';
  }

  @override
  String get diy_activeBadge => 'ACTIVE';

  @override
  String get common_optional => 'Optional';

  @override
  String get common_emptyValue => '(Empty)';

  @override
  String get common_previewLoadFailed => 'Failed to load preview';

  @override
  String get common_clickToRefresh => 'Click to refresh';

  @override
  String get common_clickToRetry => 'Click to retry';

  @override
  String get common_opening => 'Opening...';

  @override
  String get common_swap => 'Swap';

  @override
  String get common_prefix => 'Prefix';

  @override
  String get common_suffix => 'Suffix';

  @override
  String get common_minimum => 'Minimum';

  @override
  String get common_maximum => 'Maximum';

  @override
  String get addToLibrary_displayNameHint =>
      'Enter a name to identify this entry';

  @override
  String get addToLibrary_tagHint => 'Enter a tag and press Enter to add it';

  @override
  String get newPresetDialog_nameRequired => 'Enter a preset name';

  @override
  String get newPresetDialog_nameLabel => 'Preset Name';

  @override
  String get newPresetDialog_nameHint => 'Enter a name for the new preset';

  @override
  String get newPresetDialog_creationMode => 'Creation Method';

  @override
  String get drop_saveVibeBundle => 'Save Vibe Bundle';

  @override
  String drop_saveVibeBundleSubtitle(String name) {
    return 'Save $name and the other Vibes to the library';
  }

  @override
  String get drop_saveEncodedVibeSubtitle =>
      'Save the pre-encoded Vibe data to the library';

  @override
  String get history_dragFilePreparationFailed =>
      'Failed to prepare the drag file. Try again later.';

  @override
  String get history_dragFilePreparing => 'Preparing the drag file...';

  @override
  String get history_dragFileNotReady => 'The drag file is not ready yet';

  @override
  String get vibe_import_overwriteOriginalParams =>
      'Replace Original Vibe Parameters';

  @override
  String vibe_import_overwriteOriginalParamsHint(String name) {
    return 'Only replace the library parameters for $name; disabled by default';
  }

  @override
  String vibe_import_reencodeFailed(String name) {
    return 'Failed to re-encode Vibe: $name';
  }

  @override
  String get randomManager_releaseToDelete => 'Release to delete';

  @override
  String get randomManager_dragHereToDelete => 'Drag here to delete';

  @override
  String get randomManager_keyboardShortcutsHint =>
      'Keyboard Shortcuts (press ? to view)';

  @override
  String get localGallery_createFolder => 'Create Folder';

  @override
  String galleryScan_skipped(int count) {
    return 'Skipped $count';
  }

  @override
  String galleryScan_withMetadata(int count) {
    return 'With metadata $count';
  }

  @override
  String galleryScan_failed(int count) {
    return 'Failed $count';
  }

  @override
  String get galleryScan_processing => 'Processing';

  @override
  String get galleryScan_pending => 'Pending';

  @override
  String get vibeDetail_useAll => 'Use All';

  @override
  String get vibeDetail_longPressSetCover => 'Long-press to set as cover';

  @override
  String get vibeDetail_noPreviewImage => 'No preview image';

  @override
  String get vibeDetail_dropPreviewImage =>
      'Drop an image here to set the preview';

  @override
  String get vibeDetail_releasePreviewImage =>
      'Release to set the preview image';

  @override
  String imagePicker_dropReadFailed(String error) {
    return 'Failed to read the dropped image: $error';
  }

  @override
  String get imagePicker_dropNoReadableImage =>
      'The dropped data does not contain a readable image file or image URL';

  @override
  String get imagePicker_fileDataUnavailable => 'Unable to read file data';

  @override
  String imagePicker_fileSelectionFailed(String error) {
    return 'Failed to select file: $error';
  }

  @override
  String imagePicker_directorySelectionFailed(String error) {
    return 'Failed to select directory: $error';
  }

  @override
  String get editor_effects => 'Effects';

  @override
  String get editor_shiftEdges => 'Shift Edges';

  @override
  String editor_currentSize(int width, int height) {
    return 'Current: $width x $height';
  }

  @override
  String get editor_edgeLeft => 'Left';

  @override
  String get editor_edgeRight => 'Right';

  @override
  String get editor_edgeTop => 'Top';

  @override
  String get editor_edgeBottom => 'Bottom';

  @override
  String get editor_enterNumber => 'Enter a number';

  @override
  String get editor_nonNegativeNumber => 'Must be 0 or more';

  @override
  String editor_requestedSize(int width, int height) {
    return 'Requested: $width x $height';
  }

  @override
  String get editor_requestedSizeInvalid => 'Requested: invalid';

  @override
  String editor_appliedSize(int width, int height) {
    return 'Applied: $width x $height';
  }

  @override
  String get editor_appliedSizeInvalid => 'Applied: invalid';

  @override
  String editor_appliedEdges(int left, int top, int right, int bottom) {
    return 'Applied edges: L $left, T $top, R $right, B $bottom';
  }

  @override
  String get editor_appliedEdgesInvalid => 'Applied edges: invalid';

  @override
  String editor_appliedDimensionLimit(int max) {
    return 'Applied dimensions must not exceed $max.';
  }

  @override
  String get savePreset_title => 'Save as Preset';

  @override
  String get savePreset_nameHint => 'Enter preset name';

  @override
  String get savePreset_metadataDescription => 'Saved from image metadata';

  @override
  String savePreset_vibeData(int count) {
    return 'Vibe Data ($count)';
  }

  @override
  String get onlineGallery_videoLoadFailed => 'Failed to load video';

  @override
  String get vibe_releaseToAddStyleReference =>
      'Release to add style reference';

  @override
  String router_pageNotFound(String error) {
    return 'Page not found: $error';
  }

  @override
  String get autocomplete_translating => 'Translating…';

  @override
  String get autocomplete_missingTranslation => 'Not translated';

  @override
  String autocomplete_translationCoverage(int translated, int total) {
    return 'Translation coverage: $translated/$total';
  }

  @override
  String autocomplete_aliasMatch(String alias) {
    return 'Alias: $alias';
  }

  @override
  String get autocomplete_settingsTitle => 'Autocomplete';

  @override
  String get autocomplete_enable => 'Enable autocomplete';

  @override
  String get autocomplete_resultLimit => 'Result count';

  @override
  String get autocomplete_allResults => 'All';

  @override
  String get autocomplete_showAliases => 'Show matched aliases';

  @override
  String get autocomplete_showTranslations => 'Show Chinese translations';

  @override
  String get autocomplete_autoComma => 'Add a comma after insertion';

  @override
  String get autocomplete_openOnTagClick =>
      'Open autocomplete when clicking tags';

  @override
  String get autocomplete_openOnTagClickSubtitle =>
      'When enabled, clicking an existing tag opens normal autocomplete; Ctrl/Command-click still shows related tags';

  @override
  String get autocomplete_replaceUnderscores =>
      'Replace underscores with spaces on insertion';

  @override
  String get autocomplete_dataSourcesTitle => 'Data Sources & Cache';

  @override
  String get autocomplete_relatedTagsTitle => 'Co-occurrence and related tags';

  @override
  String get autocomplete_relatedTagsSubtitle =>
      'Suggest after accepting a tag; also use Ctrl+Shift+Space or Ctrl+click on a tag';

  @override
  String get autocomplete_danbooruApi => 'Danbooru online supplement';

  @override
  String get autocomplete_danbooruPrivacy =>
      'Only the current English tag is sent; the full prompt is never uploaded';

  @override
  String get autocomplete_llmTranslation =>
      'Use Prompt Assistant for missing translations';

  @override
  String get autocomplete_llmRouteMissing =>
      'Configure a Translate route in Prompt Assistant first';

  @override
  String autocomplete_llmRoute(String route) {
    return 'Current route: $route. Model usage may incur fees.';
  }

  @override
  String get autocomplete_cooccurrence => 'Local related-tag data';

  @override
  String autocomplete_entryCount(int count) {
    return '$count records';
  }

  @override
  String get autocomplete_cooccurrenceAutoDownload =>
      'Automatically download local related-tag data';

  @override
  String get autocomplete_cooccurrenceAutoDownloadSubtitle =>
      'Downloads in the background after the home screen opens when related tags are enabled; base autocomplete is never blocked';

  @override
  String get autocomplete_downloadNow => 'Download now';

  @override
  String autocomplete_cooccurrenceUnavailable(String size) {
    return 'Not installed · $size download. Online related tags remain available.';
  }

  @override
  String get autocomplete_cooccurrenceChecking => 'Checking local data…';

  @override
  String autocomplete_cooccurrenceDownloading(
    String downloaded,
    String total,
    String speed,
  ) {
    return 'Downloading $downloaded / $total · $speed. Online results remain available.';
  }

  @override
  String get autocomplete_cooccurrenceVerifying =>
      'Download complete. Verifying the data pack…';

  @override
  String get autocomplete_cooccurrenceInstalling =>
      'Installing and switching databases safely…';

  @override
  String autocomplete_cooccurrenceReady(
    String version,
    int count,
    String size,
  ) {
    return 'Version $version · $count relations · $size on disk';
  }

  @override
  String autocomplete_cooccurrenceUpdateAvailable(String version) {
    return 'Data version $version is available';
  }

  @override
  String autocomplete_cooccurrenceFailed(String reason) {
    return 'Local data is unavailable: $reason. Base autocomplete and online related tags are unaffected.';
  }

  @override
  String get autocomplete_cooccurrenceErrorNetwork =>
      'Network connection failed. Try again later';

  @override
  String get autocomplete_cooccurrenceErrorDiskFull => 'Not enough disk space';

  @override
  String get autocomplete_cooccurrenceErrorArchive =>
      'The download is incomplete or failed verification';

  @override
  String get autocomplete_cooccurrenceErrorDatabase =>
      'The database is damaged or incompatible';

  @override
  String get autocomplete_cooccurrenceErrorManifest =>
      'The bundled data manifest is invalid';

  @override
  String get autocomplete_cooccurrenceErrorInstall =>
      'The data file could not be written or replaced';

  @override
  String get autocomplete_cooccurrenceRemoveTitle =>
      'Remove local related-tag data?';

  @override
  String get autocomplete_cooccurrenceRemoveConfirm =>
      'This immediately frees the disk space. Online related tags will continue to work.';

  @override
  String get autocomplete_cooccurrenceStopAutoDownload =>
      'Also turn off automatic downloads so it is not reinstalled next time';

  @override
  String get autocomplete_cacheTitle => 'Online & AI Cache';

  @override
  String get autocomplete_clearDanbooruCache => 'Clear Danbooru cache';

  @override
  String get autocomplete_clearAiCache => 'Clear AI translation cache';

  @override
  String autocomplete_cacheCleared(int count) {
    return 'Cleared $count cached entries';
  }

  @override
  String get autocomplete_baseCatalog => 'Base Danbooru catalog';

  @override
  String autocomplete_catalogStatus(String count, String version) {
    return '$count tags · data version $version';
  }

  @override
  String get autocomplete_zhDictionary => 'ffdkj Simplified Chinese dictionary';

  @override
  String autocomplete_zhInstalled(int count, String version) {
    return 'Installed: $count entries · version $version';
  }

  @override
  String get autocomplete_zhNotInstalled =>
      'Not installed; English autocomplete remains available';

  @override
  String get autocomplete_zhInstallPrompt =>
      'Install the ffdkj dictionary for Chinese labels and reverse lookup. It is downloaded directly from upstream.';

  @override
  String get autocomplete_checkUpdate => 'Check for updates';

  @override
  String get autocomplete_update => 'Update';

  @override
  String get autocomplete_repair => 'Repair';

  @override
  String get autocomplete_install => 'Install';

  @override
  String get autocomplete_remove => 'Remove';

  @override
  String get autocomplete_removeConfirm =>
      'Remove the installed Chinese translation dictionary? You can install it again later.';

  @override
  String get autocomplete_sourceBase => 'Bundled base catalog';

  @override
  String get autocomplete_sourceZh => 'ffdkj Chinese dictionary';

  @override
  String get autocomplete_sourceApi => 'Danbooru API';

  @override
  String get autocomplete_sourceRelated => 'Offline related tags';

  @override
  String get autocomplete_sourceAi => 'Prompt Assistant translation';

  @override
  String get autocomplete_headerTitle => 'Tag autocomplete';

  @override
  String get autocomplete_relatedHeaderTitle => 'Related tags';

  @override
  String get autocomplete_loading =>
      'Searching the local catalog and online tags…';

  @override
  String get autocomplete_empty => 'No matching tags found';

  @override
  String get autocomplete_relatedLoading =>
      'Querying offline co-occurrences and online related tags…';

  @override
  String get autocomplete_relatedEmpty => 'No related tags are available';

  @override
  String autocomplete_relatedMetric(int count, String score) {
    return '$count co-occurrences · Jaccard $score';
  }

  @override
  String get autocomplete_relatedPin =>
      'Pin this tag to insert multiple related tags';

  @override
  String get autocomplete_relatedUnpin =>
      'Unpin and resume chained recommendations';

  @override
  String get autocomplete_statusBase => 'Local';

  @override
  String get autocomplete_statusRelated => 'Related';

  @override
  String get autocomplete_statusOnlineOnly => 'Online only';

  @override
  String get autocomplete_statusOnlineOnlyTooltip =>
      'Local related-tag data is not ready; only Danbooru online results are shown';

  @override
  String get autocomplete_statusDictionary => 'Translation';

  @override
  String get autocomplete_statusOnline => 'Online';

  @override
  String get autocomplete_statusAi => 'AI';

  @override
  String get autocomplete_statusReady => 'Ready';

  @override
  String get autocomplete_statusNotInstalled => 'Not installed';

  @override
  String autocomplete_statusDownloading(int progress) {
    return 'Downloading $progress%';
  }

  @override
  String get autocomplete_statusUpdateAvailable => 'Update';

  @override
  String get autocomplete_statusError => 'Error';

  @override
  String get autocomplete_statusDisabled => 'Off';

  @override
  String get autocomplete_statusSearching => 'Searching';

  @override
  String get autocomplete_statusTranslating => 'Translating';

  @override
  String get autocomplete_openSettings =>
      'Open autocomplete and data source settings';

  @override
  String get randomManager_searchCategories =>
      'Search categories, groups, or tags (Ctrl+F)';

  @override
  String get randomManager_verifiedOfflineLibrary =>
      'Verified offline random library';

  @override
  String get randomManager_sourceDetails => 'Data source details';

  @override
  String get randomManager_sourceUrl => 'Source URL';

  @override
  String get randomManager_sourceCommit => 'Source commit';

  @override
  String get randomManager_sourceDate => 'Source date';

  @override
  String get randomManager_sourceLicense => 'License';

  @override
  String randomManager_catalogCounts(Object tags, Object aliases) {
    return 'Complete catalog: $tags tags, $aliases aliases';
  }

  @override
  String randomManager_libraryVersion(String version, String count) {
    return 'Rules v$version · $count tags';
  }

  @override
  String get randomManager_preview => 'Random result preview';

  @override
  String get randomManager_libraryUnavailable => 'Random library unavailable';

  @override
  String get randomManager_noCategoryResults =>
      'No matching categories, groups, or tags';
}

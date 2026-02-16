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
  String get common_selectAll => 'Select All';

  @override
  String get common_deselectAll => 'Deselect All';

  @override
  String get common_expandAll => 'Expand All';

  @override
  String get common_collapseAll => 'Collapse All';

  @override
  String get common_save => 'Save';

  @override
  String get common_saved => 'Saved';

  @override
  String get common_delete => 'Delete';

  @override
  String get common_edit => 'Edit';

  @override
  String get common_close => 'Close';

  @override
  String get common_back => 'Back';

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
  String get common_more => 'More';

  @override
  String get common_select => 'Select';

  @override
  String get common_reset => 'Reset';

  @override
  String get common_search => 'Search';

  @override
  String get common_featureInDev => 'Feature in development...';

  @override
  String get common_add => 'Add';

  @override
  String get common_confirmDelete => 'Confirm Delete';

  @override
  String get common_settings => 'Settings';

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
  String get common_upload => 'Upload';

  @override
  String get common_apply => 'Apply';

  @override
  String get common_preview => 'Preview';

  @override
  String get common_done => 'Done';

  @override
  String get common_view => 'View';

  @override
  String get common_info => 'Info';

  @override
  String get common_warning => 'Warning';

  @override
  String get common_show => 'Show';

  @override
  String get common_hide => 'Hide';

  @override
  String get common_move => 'Move';

  @override
  String get common_duplicate => 'Duplicate';

  @override
  String get common_favorite => 'Favorite';

  @override
  String get common_unfavorite => 'Unfavorite';

  @override
  String get common_share => 'Share';

  @override
  String get common_open => 'Open';

  @override
  String get common_ok => 'OK';

  @override
  String get common_submit => 'Submit';

  @override
  String get common_discard => 'Discard';

  @override
  String get common_keep => 'Keep';

  @override
  String get common_replace => 'Replace';

  @override
  String get common_skip => 'Skip';

  @override
  String get common_yes => 'Yes';

  @override
  String get common_no => 'No';

  @override
  String get nav_canvas => 'Canvas';

  @override
  String get nav_gallery => 'Gallery';

  @override
  String get nav_onlineGallery => 'Online Gallery';

  @override
  String get nav_randomConfig => 'Random Config';

  @override
  String get nav_dictionary => 'Dictionary (WIP)';

  @override
  String get nav_settings => 'Settings';

  @override
  String get nav_discordCommunity => 'Discord Community';

  @override
  String get nav_githubRepo => 'GitHub Repository';

  @override
  String get auth_login => 'Login';

  @override
  String get auth_logout => 'Logout';

  @override
  String get auth_email => 'Email';

  @override
  String get auth_emailHint => 'Enter your NovelAI account email';

  @override
  String get auth_password => 'Password';

  @override
  String get auth_passwordHint => 'Enter password';

  @override
  String get auth_loginButton => 'Sign In';

  @override
  String get auth_loginFailed => 'Login failed';

  @override
  String get auth_rememberPassword => 'Remember password';

  @override
  String get auth_loginTip => 'Sign in with your NovelAI account\nAll data is stored locally only';

  @override
  String get auth_checkingStatus => 'Checking login status';

  @override
  String get auth_loggedIn => 'Logged in';

  @override
  String get auth_tokenConfigured => 'Token configured';

  @override
  String get auth_notLoggedIn => 'Not logged in';

  @override
  String get auth_pleaseLogin => 'Please login to use all features';

  @override
  String get auth_logoutConfirmTitle => 'Logout';

  @override
  String get auth_logoutConfirmContent => 'Are you sure you want to logout?';

  @override
  String get auth_emailRequired => 'Please enter email';

  @override
  String get auth_emailInvalid => 'Please enter a valid email address';

  @override
  String get auth_passwordRequired => 'Please enter password';

  @override
  String get auth_tokenLogin => 'API Token Login';

  @override
  String get auth_credentialsLogin => 'Email & Password';

  @override
  String get auth_credentialsLoginTitle => 'Login with Email';

  @override
  String get auth_tokenHint => 'Enter your Persistent API Token';

  @override
  String get auth_tokenRequired => 'Please enter token';

  @override
  String get auth_tokenInvalid => 'Invalid token format, should start with pst-';

  @override
  String get auth_nicknameOptional => 'Nickname (optional)';

  @override
  String get auth_nicknameHint => 'Set a recognizable name for this account';

  @override
  String get auth_saveAccount => 'Save this account';

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
  String get auth_orAddNewAccount => 'or add new account';

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
  String get auth_cannotDeleteCurrent => 'Cannot delete currently logged in account';

  @override
  String get auth_changeAvatar => 'Change Avatar';

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
  String auth_error_loginFailed(Object error) {
    return 'Login failed: $error';
  }

  @override
  String get auth_error_networkTimeout => 'Connection timeout';

  @override
  String get auth_error_networkError => 'Network error';

  @override
  String get auth_error_authFailed => 'Authentication failed';

  @override
  String get auth_error_authFailed_tokenExpired => 'Token expired, please login again';

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
  String get auth_troubleshoot_checkConnection_title => 'Check Network Connection';

  @override
  String get auth_troubleshoot_checkConnection_desc => 'Ensure your device is connected to the internet';

  @override
  String get auth_troubleshoot_retry_title => 'Try Again';

  @override
  String get auth_troubleshoot_retry_desc => 'Network issues may be temporary, please retry';

  @override
  String get auth_troubleshoot_proxy_title => 'Check Proxy Settings';

  @override
  String get auth_troubleshoot_proxy_desc => 'If using a proxy, verify it\'s configured correctly';

  @override
  String get auth_troubleshoot_firewall_title => 'Check Firewall Settings';

  @override
  String get auth_troubleshoot_firewall_desc => 'Ensure your firewall allows connections to NovelAI servers';

  @override
  String get auth_troubleshoot_serverStatus_title => 'Check Server Status';

  @override
  String get auth_troubleshoot_serverStatus_desc => 'Visit NovelAI status page or community to check for outages';

  @override
  String get auth_passwordResetHelp_title => 'Password Reset';

  @override
  String get auth_passwordResetHelp_desc => 'Clicking \'Forgot password?\' will open NovelAI\'s password reset page in your browser where you can reset your password';

  @override
  String get auth_passwordResetAfterReset_title => 'After Password Reset';

  @override
  String get auth_passwordResetAfterReset_desc => 'After resetting your password on NovelAI website, return to this app and login with your new password';

  @override
  String get auth_passwordResetNoEmail_title => 'Didn\'t receive reset email?';

  @override
  String get auth_passwordResetNoEmail_desc => 'Check your spam folder or contact NovelAI support if you don\'t receive the password reset email within a few minutes';

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
  String get settings_languageChinese => '中文';

  @override
  String get settings_languageEnglish => 'English';

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
  String get settings_storage => 'Storage';

  @override
  String get settings_imageSavePath => 'Image Save Location';

  @override
  String get settings_default => 'Default';

  @override
  String get settings_autoSave => 'Auto Save';

  @override
  String get settings_autoSaveSubtitle => 'Automatically save images after generation';

  @override
  String get settings_about => 'About';

  @override
  String settings_version(Object version) {
    return 'Version $version';
  }

  @override
  String get settings_openSource => 'Open Source';

  @override
  String get settings_openSourceSubtitle => 'View source code and documentation';

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
  String get settings_restartRequired => 'Restart Required';

  @override
  String get settings_restartRequiredContent => 'The app needs to restart to apply the new storage path. Please restart the app manually.';

  @override
  String get settings_pathSavedRestartRequired => 'Path updated, restart to apply changes';

  @override
  String get settings_accountProfile => 'Account Profile';

  @override
  String get settings_accountType => 'Account Type';

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
  String get settings_nickname => 'Nickname';

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
  String get settings_nicknameHint => 'Enter 2-32 characters';

  @override
  String get settings_nicknameEmpty => 'Please enter a nickname';

  @override
  String settings_nicknameTooShort(int minLength) {
    return 'Nickname must be at least $minLength characters';
  }

  @override
  String settings_nicknameTooLong(int maxLength) {
    return 'Nickname cannot exceed $maxLength characters';
  }

  @override
  String get settings_nicknameAllWhitespace => 'Nickname cannot be all whitespace';

  @override
  String get settings_nicknameUpdated => 'Nickname updated';

  @override
  String get settings_avatarUpdated => 'Avatar updated';

  @override
  String get settings_avatarRemoved => 'Avatar removed';

  @override
  String get settings_avatarFileMissing => 'Avatar file missing, select again?';

  @override
  String get settings_setAsDefaultSuccess => 'Set as default account';

  @override
  String get settings_startupPerformance => 'Startup Performance';

  @override
  String get settings_startupPerformanceSubtitle => 'Configure startup performance settings';

  @override
  String get generation_title => 'Generate';

  @override
  String get generation_generate => 'Generate';

  @override
  String get generation_cancel => 'Cancel';

  @override
  String get generation_generating => 'Generating...';

  @override
  String get generation_cancelGeneration => 'Cancel Generation';

  @override
  String get generation_generateImage => 'Generate Image';

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
  String get generation_noHistory => 'No history records';

  @override
  String get generation_emptyHistoryHint => 'Start your first creation, generation history will appear here';

  @override
  String get generation_quickActions => 'Quick Actions';

  @override
  String get generation_startCreating => 'Start Creating';

  @override
  String get generation_noHistoryGuide => 'Enter prompt and click generate button, your creations will appear here';

  @override
  String get generation_randomPrompt => 'Random Prompt';

  @override
  String get generation_randomPromptSubtitle => 'Generate random prompt';

  @override
  String get generation_clearPrompt => 'Clear Prompt';

  @override
  String get generation_clearPromptSubtitle => 'Clear current prompt';

  @override
  String get generation_promptCleared => 'Prompt cleared';

  @override
  String get generation_clearHistory => 'Clear History';

  @override
  String get generation_clearHistoryConfirm => 'Are you sure you want to clear all history records? This action cannot be undone.';

  @override
  String get generation_model => 'Model';

  @override
  String get generation_imageSize => 'Image Size';

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
  String get generation_smeaSubtitle => 'Improve generation quality for large images';

  @override
  String get generation_smeaDyn => 'SMEA DYN';

  @override
  String get generation_smeaDynSubtitle => 'SMEA dynamic variant';

  @override
  String get generation_smeaDescription => 'High resolution samplers will automatically be used above a certain image size';

  @override
  String generation_cfgRescale(Object value) {
    return 'CFG Rescale: $value';
  }

  @override
  String get generation_noiseSchedule => 'Noise Schedule';

  @override
  String get generation_resetParams => 'Reset Parameters';

  @override
  String generation_sizePortrait(Object width, Object height) {
    return 'Portrait ($width×$height)';
  }

  @override
  String generation_sizeLandscape(Object width, Object height) {
    return 'Landscape ($width×$height)';
  }

  @override
  String generation_sizeSquare(Object width, Object height) {
    return 'Square ($width×$height)';
  }

  @override
  String generation_sizeSmallSquare(Object width, Object height) {
    return 'Small Square ($width×$height)';
  }

  @override
  String generation_sizeLargeSquare(Object width, Object height) {
    return 'Large Square ($width×$height)';
  }

  @override
  String generation_sizeTallPortrait(Object width, Object height) {
    return 'Tall Portrait ($width×$height)';
  }

  @override
  String generation_sizeWideLandscape(Object width, Object height) {
    return 'Wide Landscape ($width×$height)';
  }

  @override
  String get prompt_positive => 'Positive';

  @override
  String get prompt_negative => 'Negative';

  @override
  String get prompt_positivePrompt => 'Positive Prompt';

  @override
  String get prompt_negativePrompt => 'Negative Prompt';

  @override
  String get prompt_mainPositive => 'Main Prompt (Positive)';

  @override
  String get prompt_mainNegative => 'Main Prompt (Negative)';

  @override
  String get prompt_characterPrompts => 'Multi-Character Prompts';

  @override
  String prompt_characterPromptItem(Object name, Object content) {
    return '$name: $content';
  }

  @override
  String get prompt_finalPrompt => 'Final Effective Prompt';

  @override
  String get prompt_finalNegative => 'Final Effective Negative';

  @override
  String prompt_tags(Object count) {
    return '$count tags';
  }

  @override
  String prompt_importedCharacters(int count) {
    return 'Imported $count character(s)';
  }

  @override
  String get prompt_editPrompt => 'Edit Prompt';

  @override
  String get prompt_inputPrompt => 'Enter prompt...';

  @override
  String get prompt_inputNegativePrompt => 'Enter negative prompt...';

  @override
  String get prompt_describeImage => 'Describe the image you want to generate...';

  @override
  String get prompt_describeImageWithHint => 'Enter prompt to describe image, type < to reference library, supports tag autocomplete';

  @override
  String get prompt_unwantedContent => 'Content you don\'t want in the image...';

  @override
  String get prompt_addTagsHint => 'Add tags to describe your desired image';

  @override
  String get prompt_addUnwantedHint => 'Add unwanted elements';

  @override
  String get prompt_fullscreenEdit => 'Fullscreen Edit';

  @override
  String get prompt_randomPrompt => 'Random Prompt (long press to configure)';

  @override
  String prompt_clearConfirm(Object type) {
    return 'Confirm clear $type';
  }

  @override
  String get prompt_promptSettings => 'Prompt Settings';

  @override
  String get prompt_smartAutocomplete => 'Smart Autocomplete';

  @override
  String get prompt_smartAutocompleteSubtitle => 'Show tag suggestions while typing';

  @override
  String get prompt_autoFormat => 'Auto Format';

  @override
  String get prompt_autoFormatSubtitle => 'Convert Chinese commas to English, auto-add underscores';

  @override
  String get prompt_highlightEmphasis => 'Highlight Emphasis';

  @override
  String get prompt_highlightEmphasisSubtitle => 'Highlight brackets and weight syntax';

  @override
  String get prompt_sdSyntaxAutoConvert => 'SD Syntax Auto Convert';

  @override
  String get prompt_sdSyntaxAutoConvertSubtitle => 'Convert SD weight syntax to NAI format on blur';

  @override
  String get prompt_cooccurrenceRecommendation => 'Co-occurrence Tag Recommendation';

  @override
  String get prompt_cooccurrenceRecommendationSubtitle => 'Automatically recommend related tags after entering a tag';

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
  String get gallery_title => 'Gallery';

  @override
  String gallery_selected(Object count) {
    return 'Selected $count items';
  }

  @override
  String get gallery_clearAll => 'Clear All';

  @override
  String get gallery_clearGallery => 'Clear Gallery';

  @override
  String get gallery_favorite => 'Favorite';

  @override
  String get gallery_sortNewest => 'Newest First';

  @override
  String get gallery_sortOldest => 'Oldest First';

  @override
  String get gallery_sortFavorite => 'Favorites First';

  @override
  String gallery_selectedCount(Object count) {
    return 'Selected $count images';
  }

  @override
  String get config_title => 'Random Prompt Configuration';

  @override
  String get config_presets => 'Presets';

  @override
  String get config_configGroups => 'Config Groups';

  @override
  String get config_presetName => 'Preset Name';

  @override
  String get config_noPresets => 'No presets';

  @override
  String get config_restoreDefaults => 'Restore Defaults';

  @override
  String get config_newPreset => 'New Preset';

  @override
  String get config_selectPreset => 'Select a preset';

  @override
  String get config_noConfigGroups => 'No config groups yet';

  @override
  String get config_addConfigGroup => 'Add Config Group';

  @override
  String get config_saveChanges => 'Save Changes';

  @override
  String config_configGroupCount(Object count) {
    return '$count config groups';
  }

  @override
  String get config_setAsCurrent => 'Set as Current';

  @override
  String get config_duplicate => 'Duplicate';

  @override
  String get config_importConfig => 'Import Config';

  @override
  String get config_selectConfigToEdit => 'Select a config group to edit';

  @override
  String get config_editConfigGroup => 'Edit Config Group';

  @override
  String get config_configName => 'Config Name';

  @override
  String get config_selectionMode => 'Selection Mode';

  @override
  String get config_singleRandom => 'Random Single';

  @override
  String get config_singleSequential => 'Sequential Single';

  @override
  String get config_multipleCount => 'Specified Count';

  @override
  String get config_multipleProbability => 'By Probability';

  @override
  String get config_all => 'All';

  @override
  String get config_selectCount => 'Select Count';

  @override
  String get config_selectProbability => 'Select Probability';

  @override
  String get config_shuffleOrder => 'Shuffle Order';

  @override
  String get config_shuffleOrderSubtitle => 'Randomly arrange selected content';

  @override
  String get config_weightBrackets => 'Weight Brackets';

  @override
  String get config_weightBracketsHint => 'Each curly bracket pair increases weight by ~5%';

  @override
  String get config_min => 'Min';

  @override
  String get config_max => 'Max';

  @override
  String config_preview(Object preview) {
    return 'Preview: $preview';
  }

  @override
  String get config_tagContent => 'Tag Content';

  @override
  String config_tagContentHint(Object count) {
    return 'One tag per line, currently $count items';
  }

  @override
  String get config_format => 'Format';

  @override
  String get config_sort => 'Sort';

  @override
  String get config_inputTags => 'Enter tags, one per line...\nFor example:\n1girl\nbeautiful eyes\nlong hair';

  @override
  String get config_unsavedChanges => 'Unsaved Changes';

  @override
  String get config_unsavedChangesContent => 'You have unsaved changes. Are you sure you want to discard them?';

  @override
  String get config_discard => 'Discard';

  @override
  String get config_deletePreset => 'Delete Preset';

  @override
  String config_deletePresetConfirm(Object name) {
    return 'Are you sure you want to delete \"$name\"?';
  }

  @override
  String get config_pasteJsonConfig => 'Paste JSON config...';

  @override
  String get config_importSuccess => 'Import successful';

  @override
  String config_importFailed(Object error) {
    return 'Import failed: $error';
  }

  @override
  String get config_restoreDefaultsConfirm => 'Are you sure you want to restore default presets? All custom configurations will be deleted.';

  @override
  String get config_restored => 'Restored to defaults';

  @override
  String get config_copiedToClipboard => 'Copied to clipboard';

  @override
  String get config_setAsCurrentSuccess => 'Set as current preset';

  @override
  String get config_duplicatedPreset => 'Preset duplicated';

  @override
  String get config_deletedSuccess => 'Deleted';

  @override
  String get config_saveSuccess => 'Saved successfully';

  @override
  String get config_newPresetCreated => 'New preset created';

  @override
  String config_itemCount(Object count) {
    return '$count items';
  }

  @override
  String config_subConfigCount(Object count) {
    return '$count sub-configs';
  }

  @override
  String get config_random => 'Random';

  @override
  String get config_sequential => 'Sequential';

  @override
  String get config_multiple => 'Multiple';

  @override
  String get config_probability => 'Probability';

  @override
  String get config_moreActions => 'More actions';

  @override
  String get img2img_title => 'Img2Img';

  @override
  String get img2img_enabled => 'Enabled';

  @override
  String get img2img_sourceImage => 'Source Image';

  @override
  String get img2img_selectImage => 'Select Image';

  @override
  String get img2img_clickToSelectImage => 'Click to select image';

  @override
  String get img2img_strength => 'Strength';

  @override
  String get img2img_strengthHint => 'Higher values create greater difference from original';

  @override
  String get img2img_noise => 'Noise';

  @override
  String get img2img_noiseHint => 'Add extra noise for more variation';

  @override
  String get img2img_clearSettings => 'Clear Img2Img Settings';

  @override
  String get img2img_changeImage => 'Change Image';

  @override
  String get img2img_removeImage => 'Remove Image';

  @override
  String img2img_selectFailed(Object error) {
    return 'Failed to select image: $error';
  }

  @override
  String get img2img_edit => 'Edit';

  @override
  String get img2img_maskEnabled => 'Inpaint Mask';

  @override
  String get img2img_uploadImage => 'Upload Image';

  @override
  String get img2img_drawSketch => 'Draw Sketch';

  @override
  String get img2img_maskTooltip => 'White = modify, Black = preserve';

  @override
  String get img2img_maskHelpText => 'In the mask, white areas will be modified during generation, while black areas will be preserved from the source image';

  @override
  String get editor_title => 'Image Editor';

  @override
  String get editor_done => 'Done';

  @override
  String get editor_saveAndClose => 'Save & Close';

  @override
  String get editor_closeWithoutSaving => 'Close without saving';

  @override
  String get editor_close => 'Close';

  @override
  String get editor_save => 'Save';

  @override
  String get editor_modeImage => 'IMAGE';

  @override
  String get editor_modeMask => 'MASK';

  @override
  String get editor_toolSettings => 'Tool Settings';

  @override
  String get editor_brushPresets => 'Brush Presets';

  @override
  String get editor_color => 'Color';

  @override
  String get editor_brushSettings => 'Brush Settings';

  @override
  String get editor_actions => 'Actions';

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
  String get editor_clearImageLayer => 'Clear Paint';

  @override
  String get editor_clearImageLayerMessage => 'This will remove all paint strokes.';

  @override
  String get editor_clearSelection => 'Clear Selection';

  @override
  String get editor_clearSelectionMessage => 'This will remove the current selection mask.';

  @override
  String get editor_resetView => 'Reset View';

  @override
  String get editor_currentColor => 'Current Color';

  @override
  String get editor_zoom => 'Zoom';

  @override
  String get editor_paintTools => 'Paint';

  @override
  String get editor_selectionTools => 'Selection';

  @override
  String get editor_toolBrush => 'Brush';

  @override
  String get editor_toolEraser => 'Eraser';

  @override
  String get editor_toolFill => 'Fill';

  @override
  String get editor_toolLine => 'Line';

  @override
  String get editor_toolRectSelect => 'Rectangle';

  @override
  String get editor_toolEllipseSelect => 'Ellipse';

  @override
  String get editor_toolColorPicker => 'Color Picker';

  @override
  String get editor_presetDefault => 'Default';

  @override
  String get editor_presetPencil => 'Pencil';

  @override
  String get editor_presetMarker => 'Marker';

  @override
  String get editor_presetAirbrush => 'Airbrush';

  @override
  String get editor_presetInkPen => 'Ink Pen';

  @override
  String get editor_presetPixel => 'Pixel';

  @override
  String get editor_unsavedChanges => 'Unsaved Changes';

  @override
  String get editor_unsavedChangesMessage => 'You have unsaved changes. Are you sure you want to close?';

  @override
  String get editor_discard => 'Discard';

  @override
  String get editor_cancel => 'Cancel';

  @override
  String get editor_clearConfirm => 'Clear?';

  @override
  String get editor_clearConfirmMessage => 'This will remove all content from the current layer.';

  @override
  String get editor_clear => 'Clear';

  @override
  String get editor_shortcutUndo => 'Undo (Ctrl+Z)';

  @override
  String get editor_shortcutRedo => 'Redo (Ctrl+Y)';

  @override
  String get editor_selectionSettings => 'Selection';

  @override
  String get editor_shortcuts => 'Shortcuts';

  @override
  String get editor_addToSelection => 'Add to selection';

  @override
  String get editor_subtractFromSelection => 'Subtract from selection';

  @override
  String get editor_selectionHint => 'Draw selection for inpaint mask';

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
  String get vibe_hint => 'Add reference images to transfer visual style (max 4)';

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
  String vibe_referenceNumber(Object index) {
    return 'Reference #$index';
  }

  @override
  String get vibe_referenceStrength => 'Ref Strength';

  @override
  String get vibe_infoExtraction => 'Info Extraction';

  @override
  String get vibe_adjustParams => 'Adjust Parameters';

  @override
  String get vibe_remove => 'Remove';

  @override
  String get vibe_sliderHint => 'Strength: Higher mimics visual cues\nInfo Extraction: Lower reduces texture, preserves composition';

  @override
  String vibe_strengthInfo(Object value, Object infoValue) {
    return 'Strength: $value | Info Extraction: $infoValue';
  }

  @override
  String get vibe_normalize => 'Normalize Reference Strength Values';

  @override
  String vibe_encodingCost(int cost) {
    return 'Encoding required. This will cost $cost Anlas on the next generation.';
  }

  @override
  String get vibe_sourceType_png => 'PNG';

  @override
  String get vibe_sourceType_v4vibe => 'V4 Vibe';

  @override
  String get vibe_sourceType_bundle => 'Bundle';

  @override
  String get vibe_sourceType_image => 'Image';

  @override
  String get vibe_sourceType => 'Source';

  @override
  String get vibe_reuseButton => 'Reuse';

  @override
  String get vibe_reuseSuccess => 'Vibe added to generation params';

  @override
  String get vibe_info => 'Vibe Info';

  @override
  String get vibe_name => 'Name';

  @override
  String get vibe_strength => 'Strength';

  @override
  String get vibe_infoExtracted => 'Info Extracted';

  @override
  String get characterRef_title => 'Character Reference';

  @override
  String get characterRef_hint => 'Upload character reference images to maintain consistency (V4+ only)';

  @override
  String get characterRef_v4Only => 'Character Reference only supports V4+ models, please switch models';

  @override
  String get characterRef_addReference => 'Add Reference';

  @override
  String get characterRef_clearAll => 'Clear All';

  @override
  String characterRef_referenceNumber(Object index) {
    return 'Reference #$index';
  }

  @override
  String get characterRef_description => 'Character Description';

  @override
  String get characterRef_descriptionHint => 'Describe this character\'s features (optional but recommended)...';

  @override
  String get characterRef_remove => 'Remove';

  @override
  String get characterRef_styleAware => 'Style Aware';

  @override
  String get characterRef_styleAwareHint => 'Transfer character relevant style information';

  @override
  String get characterRef_fidelity => 'Fidelity';

  @override
  String get characterRef_fidelityHint => '0=Old version behavior, 1=New version behavior';

  @override
  String get unifiedRef_title => 'Image Reference';

  @override
  String get unifiedRef_switchTitle => 'Switch Mode';

  @override
  String get unifiedRef_switchContent => 'Switching modes will clear current references. Continue?';

  @override
  String get character_buttonLabel => 'Characters';

  @override
  String get character_title => 'Multi-Character (V4 Only)';

  @override
  String get character_hint => 'Define independent prompts and positions for each character (max 6)';

  @override
  String get character_addCharacter => 'Add Character';

  @override
  String get character_clearAll => 'Clear All Characters';

  @override
  String character_number(Object index) {
    return 'Character $index';
  }

  @override
  String get character_advancedOptions => 'Advanced Options';

  @override
  String get character_removeCharacter => 'Remove Character';

  @override
  String get character_description => 'Character Description';

  @override
  String get character_descriptionHint => 'Describe this character\'s features...';

  @override
  String get character_negativeOptional => 'Negative Prompt (Optional)';

  @override
  String get character_negativeHint => 'Features you don\'t want on this character...';

  @override
  String get character_positionOptional => 'Character Position (Optional)';

  @override
  String get character_positionHint => 'Position (0-1), specifies approximate position in image';

  @override
  String get character_auto => 'Auto';

  @override
  String get character_clearPosition => 'Clear Position';

  @override
  String get gallery_empty => 'Gallery is empty';

  @override
  String get gallery_emptyHint => 'Generated images will appear here';

  @override
  String get gallery_searchHint => 'Search prompts... (supports tags)';

  @override
  String gallery_imageCount(Object count) {
    return '$count images';
  }

  @override
  String gallery_exportSuccess(Object count, Object path) {
    return 'Exported $count images to $path';
  }

  @override
  String gallery_savedTo(Object path) {
    return 'Saved to $path';
  }

  @override
  String get gallery_saveFailed => 'Save failed';

  @override
  String get gallery_deleteImage => 'Delete Image';

  @override
  String get gallery_deleteImageConfirm => 'Are you sure you want to delete this image?';

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
  String get gallery_metaSmeaOn => 'On';

  @override
  String get gallery_metaSmeaOff => 'Off';

  @override
  String get gallery_metaGenerationTime => 'Generation Time';

  @override
  String get gallery_metaFileSize => 'File Size';

  @override
  String get gallery_positivePrompt => 'Positive Prompt';

  @override
  String get gallery_negativePrompt => 'Negative Prompt';

  @override
  String get preset_noPresets => 'No presets';

  @override
  String get preset_restoreDefault => 'Restore Default';

  @override
  String preset_configGroupCount(Object count) {
    return '$count config groups';
  }

  @override
  String get preset_setAsCurrent => 'Set as Current';

  @override
  String get preset_duplicate => 'Duplicate';

  @override
  String get preset_export => 'Export';

  @override
  String get preset_delete => 'Delete';

  @override
  String get preset_noConfigGroups => 'No config groups yet';

  @override
  String get preset_addConfigGroup => 'Add Config Group';

  @override
  String get preset_selectPreset => 'Select a preset';

  @override
  String get preset_selectConfigToEdit => 'Select a config group to edit';

  @override
  String get preset_editConfigGroup => 'Edit Config Group';

  @override
  String get preset_configName => 'Config Name';

  @override
  String get preset_presetName => 'Preset Name';

  @override
  String get preset_selectionMode => 'Selection Mode';

  @override
  String get preset_randomSingle => 'Random Single';

  @override
  String get preset_sequentialSingle => 'Sequential Single';

  @override
  String get preset_specifiedCount => 'Specified Count';

  @override
  String get preset_byProbability => 'By Probability';

  @override
  String get preset_all => 'All';

  @override
  String get preset_selectCount => 'Select Count';

  @override
  String get preset_selectProbability => 'Select Probability';

  @override
  String get preset_shuffleOrder => 'Shuffle Order';

  @override
  String get preset_shuffleOrderHint => 'Randomly arrange selected content';

  @override
  String get preset_weightBrackets => 'Weight Brackets';

  @override
  String get preset_weightBracketsHint => 'Each curly bracket increases weight by ~5%';

  @override
  String get preset_min => 'Min';

  @override
  String get preset_max => 'Max';

  @override
  String preset_preview(Object preview) {
    return 'Preview: $preview';
  }

  @override
  String get preset_tagContent => 'Tag Content';

  @override
  String preset_tagContentHint(Object count) {
    return 'One tag per line, currently $count items';
  }

  @override
  String get preset_format => 'Format';

  @override
  String get preset_sort => 'Sort';

  @override
  String get preset_inputHint => 'Enter tags, one per line...\nFor example:\n1girl\nbeautiful eyes\nlong hair';

  @override
  String get preset_unsavedChanges => 'Unsaved Changes';

  @override
  String get preset_unsavedChangesConfirm => 'There are unsaved changes. Discard?';

  @override
  String get preset_discard => 'Discard';

  @override
  String get preset_deletePreset => 'Delete Preset';

  @override
  String preset_deletePresetConfirm(Object name) {
    return 'Are you sure you want to delete \"$name\"?';
  }

  @override
  String get preset_importConfig => 'Import Config';

  @override
  String get preset_pasteJson => 'Paste JSON config...';

  @override
  String get preset_importSuccess => 'Import successful';

  @override
  String preset_importFailed(Object error) {
    return 'Import failed: $error';
  }

  @override
  String get preset_restoreDefaultConfirm => 'Restore default presets? All custom configs will be deleted.';

  @override
  String get preset_restored => 'Restored to defaults';

  @override
  String get preset_copiedToClipboard => 'Copied to clipboard';

  @override
  String get preset_setAsCurrentSuccess => 'Set as current preset';

  @override
  String get preset_duplicated => 'Preset duplicated';

  @override
  String get preset_deleted => 'Deleted';

  @override
  String get preset_saveSuccess => 'Saved successfully';

  @override
  String get preset_newPresetCreated => 'New preset created';

  @override
  String preset_itemCount(Object count) {
    return '$count items';
  }

  @override
  String preset_subConfigCount(Object count) {
    return '$count sub-configs';
  }

  @override
  String get preset_random => 'Random';

  @override
  String get preset_sequential => 'Sequential';

  @override
  String get preset_multiple => 'Multiple';

  @override
  String get preset_probability => 'Probability';

  @override
  String get preset_moreActions => 'More Actions';

  @override
  String get preset_rename => 'Rename';

  @override
  String get preset_moveUp => 'Move Up';

  @override
  String get preset_moveDown => 'Move Down';

  @override
  String get onlineGallery_search => 'Search';

  @override
  String get onlineGallery_popular => 'Popular';

  @override
  String get onlineGallery_favorites => 'Favorites';

  @override
  String get onlineGallery_searchTags => 'Search tags...';

  @override
  String get onlineGallery_refresh => 'Refresh';

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
  String get onlineGallery_size => 'Size';

  @override
  String get onlineGallery_score => 'Score';

  @override
  String get onlineGallery_favCount => 'Favorites';

  @override
  String get onlineGallery_rating => 'Rating';

  @override
  String get onlineGallery_type => 'Type';

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
  String get onlineGallery_open => 'Open';

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
  String get tooltip_randomPrompt => 'Random Prompt (long press to configure)';

  @override
  String get tooltip_fullscreenEdit => 'Fullscreen Edit';

  @override
  String get tooltip_maximizePrompt => 'Maximize Prompt Area';

  @override
  String get tooltip_restoreLayout => 'Restore Layout';

  @override
  String get tooltip_clear => 'Clear';

  @override
  String get tooltip_promptSettings => 'Prompt Settings';

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
  String get tooltip_changeImage => 'Change Image';

  @override
  String get tooltip_removeImage => 'Remove Image';

  @override
  String get tooltip_previewGenerate => 'Preview Generate';

  @override
  String get tooltip_help => 'Help';

  @override
  String get tooltip_addConfigGroup => 'Add Config Group';

  @override
  String get tooltip_enable => 'Enable';

  @override
  String get tooltip_disable => 'Disable';

  @override
  String get tooltip_resetWeight => 'Click to reset to 100%';

  @override
  String get upscale_title => 'Image Upscale';

  @override
  String get upscale_close => 'Close';

  @override
  String get upscale_start => 'Start Upscale';

  @override
  String get upscale_sourceImage => 'Source Image';

  @override
  String get upscale_clickToSelect => 'Click to select image to upscale';

  @override
  String get upscale_scale => 'Scale Factor';

  @override
  String get upscale_2xHint => 'Upscale to 2x original size (recommended)';

  @override
  String get upscale_4xHint => 'Upscale to 4x original size (costs more Anlas)';

  @override
  String get upscale_processing => 'Upscaling image...';

  @override
  String get upscale_complete => 'Upscale Complete';

  @override
  String get upscale_save => 'Save';

  @override
  String get upscale_share => 'Share';

  @override
  String get upscale_failed => 'Upscale failed';

  @override
  String upscale_selectFailed(Object error) {
    return 'Failed to select image: $error';
  }

  @override
  String upscale_savedTo(Object path) {
    return 'Saved to: $path';
  }

  @override
  String upscale_saveFailed(Object error) {
    return 'Save failed: $error';
  }

  @override
  String upscale_shareFailed(Object error) {
    return 'Share failed: $error';
  }

  @override
  String get danbooru_loginTitle => 'Login Danbooru';

  @override
  String get danbooru_loginHint => 'Login with username and API Key to use favorites';

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
  String get configEditor_newConfigGroup => 'New Config Group';

  @override
  String get configEditor_editConfigGroup => 'Edit Config Group';

  @override
  String get configEditor_configName => 'Config Name';

  @override
  String get configEditor_enableConfig => 'Enable this config';

  @override
  String get configEditor_enableConfigHint => 'Disabled configs won\'t participate in generation';

  @override
  String get configEditor_contentType => 'Content Type';

  @override
  String get configEditor_tagList => 'Tag List';

  @override
  String get configEditor_nestedConfig => 'Nested Config';

  @override
  String get configEditor_selectionMode => 'Selection Mode';

  @override
  String get configEditor_selectCount => 'Select Count:';

  @override
  String get configEditor_selectProbability => 'Select Probability:';

  @override
  String get configEditor_shuffleOrder => 'Shuffle Order';

  @override
  String get configEditor_shuffleOrderHint => 'Randomly arrange selected content';

  @override
  String get configEditor_weightBrackets => 'Weight Brackets';

  @override
  String get configEditor_weightBracketsHint => 'Brackets increase weight, each curly bracket adds ~5%';

  @override
  String configEditor_minBrackets(Object count) {
    return 'Min Brackets: $count';
  }

  @override
  String configEditor_maxBrackets(Object count) {
    return 'Max Brackets: $count';
  }

  @override
  String get configEditor_effectPreview => 'Effect Preview:';

  @override
  String get configEditor_content => 'Content';

  @override
  String configEditor_tagCountHint(Object count) {
    return 'One tag per line, currently $count items';
  }

  @override
  String get configEditor_format => 'Format';

  @override
  String get configEditor_sort => 'Sort';

  @override
  String get configEditor_dedupe => 'Dedupe';

  @override
  String get configEditor_nestedConfigHint => 'Nested configs create complex layered random logic';

  @override
  String get configEditor_noNestedConfig => 'No nested configs yet';

  @override
  String configEditor_itemCount(Object count) {
    return '$count items';
  }

  @override
  String configEditor_subConfigCount(Object count) {
    return '$count sub-configs';
  }

  @override
  String get configEditor_addNestedConfig => 'Add Nested Config';

  @override
  String get configEditor_subConfig => 'Sub-config';

  @override
  String get configEditor_singleRandom => 'Single - Random';

  @override
  String get configEditor_singleSequential => 'Single - Sequential';

  @override
  String get configEditor_singleProbability => 'Single - Probability';

  @override
  String get configEditor_multipleCount => 'Multiple - Count';

  @override
  String get configEditor_multipleProbability => 'Multiple - Probability';

  @override
  String get configEditor_selectAll => 'All';

  @override
  String get configEditor_singleRandomHint => 'Randomly select one item each time';

  @override
  String get configEditor_singleSequentialHint => 'Cycle through items in order';

  @override
  String get configEditor_singleProbabilityHint => 'X% chance to randomly select one, otherwise skip';

  @override
  String get configEditor_multipleCountHint => 'Randomly select specified number of items';

  @override
  String get configEditor_multipleProbabilityHint => 'Each item selected by probability';

  @override
  String get configEditor_selectAllHint => 'Select all items';

  @override
  String get configEditor_or => ' or ';

  @override
  String get configEditor_enterConfigName => 'Please enter config name';

  @override
  String get configEditor_continueEditing => 'Continue Editing';

  @override
  String get configEditor_discardChanges => 'Discard Changes';

  @override
  String configEditor_randomCount(Object count) {
    return 'Random $count';
  }

  @override
  String configEditor_probabilityPercent(Object percent) {
    return '$percent% probability';
  }

  @override
  String get presetEdit_newPreset => 'New Preset';

  @override
  String get presetEdit_editPreset => 'Edit Preset';

  @override
  String get presetEdit_presetName => 'Preset Name';

  @override
  String presetEdit_configGroups(Object count) {
    return 'Config Groups ($count)';
  }

  @override
  String get presetEdit_noConfigGroups => 'No config groups yet';

  @override
  String get presetEdit_addConfigGroupHint => 'Click + in top right to add config group';

  @override
  String get presetEdit_addConfigGroup => 'Add Config Group';

  @override
  String get presetEdit_newConfigGroup => 'New Config Group';

  @override
  String get presetEdit_enterPresetName => 'Please enter preset name';

  @override
  String get presetEdit_saveSuccess => 'Saved successfully';

  @override
  String get presetEdit_saveError => 'Failed to save preset';

  @override
  String presetEdit_deleteConfigConfirm(Object name) {
    return 'Delete config group \"$name\"?';
  }

  @override
  String get presetEdit_previewTitle => 'Preview Generation Result';

  @override
  String get presetEdit_emptyResult => '(Empty result, please check config)';

  @override
  String get presetEdit_regenerate => 'Regenerate';

  @override
  String get presetEdit_helpTitle => 'Help';

  @override
  String get presetEdit_helpConfigGroup => 'Config Group Description';

  @override
  String get presetEdit_helpConfigGroupContent => 'Each config group generates content in order, final result is joined by commas.';

  @override
  String get presetEdit_helpSelectionMode => 'Selection Mode';

  @override
  String get presetEdit_helpSingleRandom => '• Single-Random: Randomly select one item';

  @override
  String get presetEdit_helpSingleSequential => '• Single-Sequential: Cycle through in order';

  @override
  String get presetEdit_helpMultipleCount => '• Multiple-Count: Randomly select specified count';

  @override
  String get presetEdit_helpMultipleProbability => '• Multiple-Probability: Each item selected independently by probability';

  @override
  String get presetEdit_helpAll => '• All: Select all items';

  @override
  String get presetEdit_helpWeightBrackets => 'Weight Brackets';

  @override
  String get presetEdit_helpWeightBracketsContent => 'Curly brackets increase weight, more brackets = higher weight.';

  @override
  String get presetEdit_helpWeightBracketsExample => 'Example: one bracket is 1.05x weight, two brackets is 1.1x.';

  @override
  String get presetEdit_helpNestedConfig => 'Nested Config';

  @override
  String get presetEdit_helpNestedConfigContent => 'Configs can be nested for complex layered random logic.';

  @override
  String get presetEdit_gotIt => 'Got it';

  @override
  String presetEdit_tagCount(Object count) {
    return '$count tags';
  }

  @override
  String presetEdit_bracketLayers(Object count) {
    return '$count bracket layers';
  }

  @override
  String presetEdit_bracketRange(Object min, Object max) {
    return '$min-$max bracket layers';
  }

  @override
  String get qualityTags_label => 'Quality';

  @override
  String get qualityTags_positive => 'Quality (Positive)';

  @override
  String get qualityTags_negative => 'Quality (Negative)';

  @override
  String get qualityTags_disabled => 'Quality tags disabled\nClick to enable';

  @override
  String get qualityTags_addToEnd => 'Add to prompt end:';

  @override
  String get qualityTags_naiDefault => 'NAI Default';

  @override
  String get qualityTags_none => 'None';

  @override
  String get qualityTags_addFromLibrary => 'Add from Library';

  @override
  String get qualityTags_selectFromLibrary => 'Select Quality Tag Entry';

  @override
  String get ucPreset_label => 'UC Preset';

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
  String get ucPreset_custom => 'Custom';

  @override
  String get ucPreset_disabled => 'Undesired content preset disabled';

  @override
  String get ucPreset_addToNegative => 'Add to negative prompt:';

  @override
  String get ucPreset_nsfwHint => '💡 To generate adult content, add nsfw to your positive prompt. The nsfw tag will be auto-removed from negative prompt';

  @override
  String get ucPreset_addFromLibrary => 'Add from Library';

  @override
  String get ucPreset_selectFromLibrary => 'Select UC Entry';

  @override
  String get randomMode_enabledTip => 'Random mode enabled\nAuto-randomize prompt after each generation';

  @override
  String get randomMode_disabledTip => 'Random mode\nClick to auto-randomize prompts on generation';

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
  String get batchSize_hint => 'Larger batch = fewer requests, but longer wait per request';

  @override
  String get batchSize_costWarning => '⚠️ Batch size > 1 costs extra Anlas';

  @override
  String get font_systemDefault => 'System Default';

  @override
  String get font_sourceHanSans => 'Source Han Sans';

  @override
  String get font_sourceHanSerif => 'Source Han Serif';

  @override
  String get font_sourceHanSansHK => 'Source Han Sans HK';

  @override
  String get font_sourceHanMono => 'Source Han Mono';

  @override
  String get font_zcoolXiaowei => 'ZCOOL Xiaowei';

  @override
  String get font_zcoolKuaile => 'ZCOOL Kuaile';

  @override
  String get font_mashan => 'Ma Shan Zheng';

  @override
  String get font_longcang => 'Long Cang';

  @override
  String get font_liujian => 'Liu Jian Mao Cao';

  @override
  String get font_zhimang => 'Zhi Mang Xing';

  @override
  String get font_codeFont => 'Code Font';

  @override
  String get font_modernNarrow => 'Modern Narrow';

  @override
  String get font_classicSerif => 'Classic Serif';

  @override
  String get font_sciFi => 'Sci-Fi';

  @override
  String get font_techStyle => 'Tech Style';

  @override
  String get font_systemFonts => 'System Fonts';

  @override
  String get download_tagsData => 'Tags Data';

  @override
  String get download_cooccurrenceData => 'Co-occurrence Tags Data';

  @override
  String download_failed(Object name) {
    return '$name download failed';
  }

  @override
  String download_downloading(Object name) {
    return 'Downloading $name';
  }

  @override
  String download_complete(Object name) {
    return '$name download complete';
  }

  @override
  String download_downloadFailed(Object name) {
    return '$name download failed';
  }

  @override
  String get warmup_networkCheck => 'Checking network connection...';

  @override
  String get warmup_networkCheck_noProxy => 'Cannot connect to NovelAI, please enable VPN or proxy settings';

  @override
  String get warmup_networkCheck_noSystemProxy => 'Proxy enabled but no system proxy detected, please enable VPN';

  @override
  String get warmup_networkCheck_manualIncomplete => 'Manual proxy config incomplete, please check settings';

  @override
  String get warmup_networkCheck_testing => 'Testing network connection...';

  @override
  String get warmup_networkCheck_testingProxy => 'Testing network via proxy...';

  @override
  String warmup_networkCheck_failed(Object error) {
    return 'Network connection failed: $error, please check VPN';
  }

  @override
  String warmup_networkCheck_success(Object latency) {
    return 'Network connection OK (${latency}ms)';
  }

  @override
  String get warmup_networkCheck_timeout => 'Network check timeout, continuing offline';

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
  String get warmup_retryFailed => 'Retry Failed Tasks';

  @override
  String get warmup_errorDetail => 'Error';

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
  String get warmup_group_dataSourceInitialization => 'Initializing data source services...';

  @override
  String get warmup_group_dataSourceInitialization_complete => 'Data source services ready';

  @override
  String get performanceReport_title => 'Startup Performance';

  @override
  String get performanceReport_export => 'Export Report';

  @override
  String get performanceReport_taskStats => 'Task Statistics';

  @override
  String get performanceReport_averageDuration => 'Average Duration';

  @override
  String get performanceReport_successRate => 'Success Rate';

  @override
  String get performanceReport_exportSuccess => 'Report exported successfully';

  @override
  String get copyName => ' (Copy)';

  @override
  String get defaultPreset_name => 'Default Preset';

  @override
  String get defaultPreset_quality => 'Quality';

  @override
  String get defaultPreset_character => 'Character';

  @override
  String get defaultPreset_expression => 'Expression';

  @override
  String get defaultPreset_clothing => 'Clothing';

  @override
  String get defaultPreset_action => 'Action';

  @override
  String get defaultPreset_background => 'Background';

  @override
  String get defaultPreset_shot => 'Shot';

  @override
  String get defaultPreset_composition => 'Composition';

  @override
  String get defaultPreset_specialStyle => 'Special Style';

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
  String get api_error_429 => 'Concurrency limit reached';

  @override
  String get api_error_429_hint => 'Too many requests. Please wait and try again (common with shared accounts)';

  @override
  String get api_error_401 => 'Authentication failed';

  @override
  String get api_error_401_hint => 'Token invalid or expired. Please login again';

  @override
  String get api_error_402 => 'Insufficient balance';

  @override
  String get api_error_402_hint => 'Insufficient Anlas. Please top up and try again';

  @override
  String get api_error_500 => 'Server error';

  @override
  String get api_error_500_hint => 'NovelAI server error. Please try again later';

  @override
  String get api_error_503 => 'Service unavailable';

  @override
  String get api_error_503_hint => 'Server is under maintenance or overloaded. Please try again later';

  @override
  String get api_error_timeout => 'Request timeout';

  @override
  String get api_error_timeout_hint => 'Network timeout. Please check your connection and try again';

  @override
  String get api_error_network => 'Network error';

  @override
  String get api_error_network_hint => 'Cannot connect to server. Please check your network';

  @override
  String get api_error_unknown => 'Unknown error';

  @override
  String api_error_unknown_hint(Object error) {
    return 'Unknown error occurred: $error';
  }

  @override
  String get drop_dialogTitle => 'How to use this image?';

  @override
  String get drop_hint => 'Drop image here';

  @override
  String get drop_img2img => 'Image to Image';

  @override
  String get drop_vibeTransfer => 'Vibe Transfer';

  @override
  String get drop_characterReference => 'Precise Reference';

  @override
  String get drop_unsupportedFormat => 'Unsupported file format';

  @override
  String get drop_addedToImg2Img => 'Added to Image to Image';

  @override
  String get drop_addedToVibe => 'Added to Vibe Transfer';

  @override
  String drop_addedMultipleToVibe(int count) {
    return 'Added $count vibe references';
  }

  @override
  String get drop_addedToCharacterRef => 'Added to Precise Reference';

  @override
  String get characterEditor_title => 'Multi-Character Prompts';

  @override
  String get characterEditor_close => 'Close';

  @override
  String get characterEditor_confirm => 'Confirm';

  @override
  String get characterEditor_clearAll => 'Clear All';

  @override
  String get characterEditor_clearAllTitle => 'Clear All Characters';

  @override
  String get characterEditor_clearAllConfirm => 'Are you sure you want to delete all characters? This action cannot be undone.';

  @override
  String get characterEditor_tabList => 'Character List';

  @override
  String get characterEditor_tabDetail => 'Character Detail';

  @override
  String get characterEditor_globalAiChoice => 'Global AI Position';

  @override
  String get characterEditor_globalAiChoiceHint => 'When enabled, AI will automatically decide positions for all characters';

  @override
  String get characterEditor_emptyTitle => 'Please select a character';

  @override
  String get characterEditor_emptyHint => 'Select from the list or add a new character';

  @override
  String get characterEditor_noCharacters => 'No characters';

  @override
  String get characterEditor_addCharacterHint => 'Click buttons above to add characters';

  @override
  String get characterEditor_deleteTitle => 'Delete Character';

  @override
  String get characterEditor_deleteConfirm => 'Are you sure you want to delete this character? This action cannot be undone.';

  @override
  String get characterEditor_name => 'Name';

  @override
  String get characterEditor_nameHint => 'Enter character name';

  @override
  String get characterEditor_enabled => 'Enabled';

  @override
  String get characterEditor_promptHint => 'Enter positive prompt for this character...';

  @override
  String get characterEditor_negativePromptHint => 'Enter negative prompt for this character...';

  @override
  String get characterEditor_position => 'Position';

  @override
  String get characterEditor_genderFemale => 'Female';

  @override
  String get characterEditor_genderMale => 'Male';

  @override
  String get characterEditor_genderOther => 'Other';

  @override
  String get characterEditor_genderFemaleHint => 'Female (selected when adding)';

  @override
  String get characterEditor_genderMaleHint => 'Male (selected when adding)';

  @override
  String get characterEditor_genderOtherHint => 'Other (selected when adding)';

  @override
  String get characterEditor_addFemale => 'F';

  @override
  String get characterEditor_addMale => 'M';

  @override
  String get characterEditor_addOther => 'Other';

  @override
  String get characterEditor_addFromLibrary => 'Library';

  @override
  String get characterEditor_editCharacter => 'Edit Character';

  @override
  String get characterEditor_moveUp => 'Move Up';

  @override
  String get characterEditor_moveDown => 'Move Down';

  @override
  String get characterEditor_aiChoice => 'AI';

  @override
  String get characterEditor_positionLabel => 'Position:';

  @override
  String get characterEditor_positionHint => 'Select character position in the image';

  @override
  String get characterEditor_promptLabel => 'Prompt:';

  @override
  String get characterEditor_disabled => '[Disabled]';

  @override
  String characterEditor_characterCount(Object count) {
    return '$count characters';
  }

  @override
  String characterEditor_characterCountWithEnabled(Object enabled, Object total) {
    return '$enabled/$total characters';
  }

  @override
  String characterEditor_tooltipWithCount(Object count) {
    return 'Multi-Character Prompts ($count characters)';
  }

  @override
  String get characterEditor_clickToEdit => 'Click to edit multi-character prompts';

  @override
  String get toolbar_randomPrompt => 'Random Prompt';

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
  String get characterTooltip_clickToConfig => 'Click to configure multi-character prompts';

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
  String get characterTooltip_negativeLabel => 'Negative';

  @override
  String get characterTooltip_notSet => 'Not set';

  @override
  String characterTooltip_summary(Object total, Object enabled) {
    return '$total characters ($enabled enabled)';
  }

  @override
  String get characterTooltip_viewFullConfig => 'Click for full configuration';

  @override
  String get tagLibrary_title => 'Tag Library';

  @override
  String tagLibrary_tagCount(Object count) {
    return 'Loaded $count tags';
  }

  @override
  String get tagLibrary_usingBuiltin => 'Using built-in library';

  @override
  String tagLibrary_lastSync(Object time) {
    return 'Last sync: $time';
  }

  @override
  String get tagLibrary_neverSynced => 'Never synced';

  @override
  String get tagLibrary_syncNow => 'Sync from Danbooru';

  @override
  String get tagLibrary_syncing => 'Syncing...';

  @override
  String get tagLibrary_syncSuccess => 'Library synced successfully';

  @override
  String get tagLibrary_syncFailed => 'Sync failed, please check network connection';

  @override
  String get tagLibrary_networkError => 'Cannot connect to Danbooru, please check network or proxy settings';

  @override
  String get tagLibrary_autoSync => 'Auto Sync';

  @override
  String get tagLibrary_autoSyncHint => 'Periodically update from Danbooru';

  @override
  String get tagLibrary_syncInterval => 'Sync Interval';

  @override
  String get tagLibrary_dataRange => 'Data Range';

  @override
  String get tagLibrary_dataRangeHint => 'Larger range means longer sync time but more tags';

  @override
  String get tagLibrary_dataRangePopular => 'Popular (>1000)';

  @override
  String get tagLibrary_dataRangeMedium => 'Medium (>500)';

  @override
  String get tagLibrary_dataRangeFull => 'Full (>100)';

  @override
  String tagLibrary_syncIntervalDays(Object days) {
    return '$days days';
  }

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
  String get randomMode_naiOfficial => 'Official Mode';

  @override
  String get randomMode_custom => 'Custom Mode';

  @override
  String get randomMode_hybrid => 'Hybrid Mode';

  @override
  String get randomMode_naiOfficialDesc => 'Replicate NovelAI official random algorithm';

  @override
  String get randomMode_customDesc => 'Generate using custom presets';

  @override
  String get randomMode_hybridDesc => 'Combine official algorithm with custom presets';

  @override
  String get randomMode_naiIndicator => 'NAI';

  @override
  String get randomMode_customIndicator => 'Custom';

  @override
  String get naiMode_title => 'Default Mode';

  @override
  String get naiMode_subtitle => 'Replicate NovelAI official random algorithm';

  @override
  String get naiMode_syncLibrary => 'Manage Extended Library';

  @override
  String get manageLibrary => 'Manage Library';

  @override
  String get naiMode_algorithmInfo => 'Algorithm Info';

  @override
  String naiMode_tagCountBadge(Object count) {
    return '$count tags';
  }

  @override
  String naiMode_totalTags(Object count) {
    return 'Tags: $count';
  }

  @override
  String naiMode_lastSync(Object time) {
    return 'Synced: $time';
  }

  @override
  String get naiMode_lastSyncLabel => 'Last Sync';

  @override
  String get timeAgo_justNow => 'just now';

  @override
  String timeAgo_minutes(Object count) {
    return '$count min ago';
  }

  @override
  String timeAgo_hours(Object count) {
    return '${count}h ago';
  }

  @override
  String timeAgo_days(Object count) {
    return '${count}d ago';
  }

  @override
  String naiMode_dataRange(Object range) {
    return 'Range: $range';
  }

  @override
  String get naiMode_preview => 'Preview';

  @override
  String get naiMode_createCustom => 'Create Custom Preset';

  @override
  String naiMode_categoryProbability(Object probability) {
    return '$probability%';
  }

  @override
  String naiMode_tagCount(Object count) {
    return '$count tags';
  }

  @override
  String get naiMode_readOnlyHint => 'Random prompt configuration based on official algorithm';

  @override
  String promptConfig_confirmRemoveGroup(Object name) {
    return 'Are you sure you want to remove group \"$name\"?';
  }

  @override
  String promptConfig_confirmRemoveCategory(Object name) {
    return 'Are you sure you want to remove category \"$name\"? It will no longer participate in random generation.';
  }

  @override
  String get promptConfig_groupList => 'Group List';

  @override
  String promptConfig_groupCount(Object count) {
    return '$count groups';
  }

  @override
  String get promptConfig_addGroup => 'Add Group';

  @override
  String get promptConfig_noGroups => 'No groups yet, click \"Add Group\" to create';

  @override
  String get promptConfig_builtinLibrary => 'NAI Built-in Library';

  @override
  String get promptConfig_customGroup => 'Custom Group';

  @override
  String get promptConfig_danbooruTagGroup => 'Danbooru TagGroup';

  @override
  String get promptConfig_danbooruPool => 'Danbooru Pool';

  @override
  String get promptConfig_categorySettings => 'Category Settings';

  @override
  String get promptConfig_enableCategory => 'Enable Category';

  @override
  String get promptConfig_disableCategory => 'Disable Category';

  @override
  String get naiMode_noLibrary => 'Library not loaded';

  @override
  String get naiMode_noCategories => 'No categories. Please reset preset or add new categories.';

  @override
  String get naiMode_noTags => 'No tags';

  @override
  String get naiMode_previewResult => 'Preview Result';

  @override
  String get naiMode_characterPrompts => 'Character Prompts';

  @override
  String get naiMode_character => 'Character';

  @override
  String get naiMode_createCustomTitle => 'Create Custom Preset';

  @override
  String get naiMode_createCustomDesc => 'This will create a new preset with all NAI categories, which you can customize.';

  @override
  String get naiMode_featureComingSoon => 'Feature coming soon...';

  @override
  String get naiMode_danbooruToggleTooltip => 'Toggle extended tags for this category';

  @override
  String get naiMode_danbooruSupplementLabel => 'Extended Tags';

  @override
  String get naiMode_danbooruMasterToggleTooltip => 'Toggle extended tags for all categories';

  @override
  String naiMode_entrySubtitle(Object count) {
    return '$count tags · Replicate official algorithm';
  }

  @override
  String get naiAlgorithm_title => 'NAI Random Algorithm';

  @override
  String get naiAlgorithm_characterCount => 'Character Count Distribution';

  @override
  String get naiAlgorithm_categoryProbability => 'Category Selection Probability';

  @override
  String get naiAlgorithm_weightedRandom => 'Weighted Random Algorithm';

  @override
  String get naiAlgorithm_weightedRandomDesc => 'Each tag\'s weight is based on Danbooru usage count. Higher weight means higher selection probability.';

  @override
  String get naiAlgorithm_v4MultiCharacter => 'V4 Multi-Character';

  @override
  String get naiAlgorithm_v4Desc => 'V4 models support independent prompts for each character, separating main and character prompts.';

  @override
  String get naiAlgorithm_mainPrompt => 'Main Prompt';

  @override
  String get naiAlgorithm_mainPromptTags => 'Character count, background, style';

  @override
  String get naiAlgorithm_characterPrompt => 'Character Prompt';

  @override
  String get naiAlgorithm_characterPromptTags => 'Hair color, eye color, hairstyle, expression, pose';

  @override
  String get naiAlgorithm_noHuman => 'No Human Scene';

  @override
  String get naiAlgorithm_noHumanDesc => '5% chance to generate scene without humans, containing only background, scene, and style tags.';

  @override
  String get naiAlgorithm_background => 'Background';

  @override
  String get naiAlgorithm_hairColor => 'Hair Color';

  @override
  String get naiAlgorithm_eyeColor => 'Eye Color';

  @override
  String get naiAlgorithm_expression => 'Expression';

  @override
  String get naiAlgorithm_hairStyle => 'Hair Style';

  @override
  String get naiAlgorithm_pose => 'Pose';

  @override
  String get naiAlgorithm_style => 'Style';

  @override
  String get naiAlgorithm_clothing => 'Clothing';

  @override
  String get naiAlgorithm_accessory => 'Accessory';

  @override
  String get naiAlgorithm_scene => 'Scene';

  @override
  String get naiAlgorithm_bodyFeature => 'Body Feature';

  @override
  String get importNai_title => 'Import from NAI Library';

  @override
  String get importNai_selectCategories => 'Select categories to import';

  @override
  String importNai_import(Object count) {
    return 'Import $count categories';
  }

  @override
  String importNai_tagCount(Object count) {
    return '$count tags';
  }

  @override
  String get tagLibrary_rangePopular => 'Popular';

  @override
  String get tagLibrary_rangeMedium => 'Medium';

  @override
  String get tagLibrary_rangeFull => 'Full';

  @override
  String tagLibrary_daysAgo(Object days) {
    return '$days days ago';
  }

  @override
  String tagLibrary_hoursAgo(Object hours) {
    return '$hours hours ago';
  }

  @override
  String get tagLibrary_justNow => 'Just now';

  @override
  String get tagLibrary_danbooruSupplement => 'Danbooru Supplement';

  @override
  String get tagLibrary_danbooruSupplementHint => 'Fetch extra tags from Danbooru to supplement library';

  @override
  String get tagLibrary_libraryComposition => 'Library Composition';

  @override
  String get tagLibrary_libraryCompositionDesc => 'NAI Official Fixed Library + Extended Tags (Optional)';

  @override
  String get poolMapping_title => 'Pool Mapping';

  @override
  String get poolMapping_enableSync => 'Enable Pool Sync';

  @override
  String get poolMapping_enableSyncDesc => 'Extract tags from Danbooru Pools to supplement categories';

  @override
  String get poolMapping_addMapping => 'Add Pool Mapping';

  @override
  String get poolMapping_noMappings => 'No Pool Mappings';

  @override
  String get poolMapping_noMappingsHint => 'Click the button above to add a Danbooru Pool';

  @override
  String get poolMapping_searchPool => 'Search Pool';

  @override
  String get poolMapping_searchHint => 'Enter Pool name keywords';

  @override
  String get poolMapping_targetCategory => 'Target Category';

  @override
  String get poolMapping_selectPool => 'Select Pool';

  @override
  String get poolMapping_syncPools => 'Sync Pools';

  @override
  String get poolMapping_syncing => 'Syncing...';

  @override
  String get poolMapping_neverSynced => 'Never synced';

  @override
  String get poolMapping_syncSuccess => 'Pool sync successful';

  @override
  String get poolMapping_syncFailed => 'Pool sync failed';

  @override
  String get poolMapping_noResults => 'No matching Pools found';

  @override
  String get poolMapping_poolExists => 'This Pool is already added';

  @override
  String get poolMapping_addSuccess => 'Pool mapping added successfully';

  @override
  String get poolMapping_removeConfirm => 'Are you sure you want to remove this Pool mapping?';

  @override
  String get poolMapping_removeSuccess => 'Pool mapping removed';

  @override
  String poolMapping_tagCount(Object count) {
    return '$count tags';
  }

  @override
  String poolMapping_postCount(Object count) {
    return '$count posts';
  }

  @override
  String get poolMapping_alreadyAdded => 'Added';

  @override
  String get poolMapping_resetToDefault => 'Reset to Default';

  @override
  String get poolMapping_resetConfirm => 'Are you sure you want to reset to default Pool mappings? Current configuration will be overwritten.';

  @override
  String get poolMapping_resetSuccess => 'Reset to default configuration';

  @override
  String get tagGroup_title => 'Tag Group Sync';

  @override
  String get tagGroup_enableSync => 'Enable Tag Group Sync';

  @override
  String get tagGroup_enableSyncDesc => 'Fetch tag data from Danbooru Tag Groups';

  @override
  String get tagGroup_mappingTitle => 'Tag Group Mappings';

  @override
  String get tagGroup_addMapping => 'Add Mapping';

  @override
  String get tagGroup_noMappings => 'No Tag Group Mappings';

  @override
  String get tagGroup_noMappingsHint => 'Click the button above to browse and add Tag Groups';

  @override
  String get tagGroup_searchHint => 'Search Tag Groups...';

  @override
  String get tagGroup_targetCategory => 'Target Category';

  @override
  String get tagGroup_selectGroup => 'Select Tag Group';

  @override
  String get tagGroup_neverSynced => 'Never synced';

  @override
  String get tagGroup_noResults => 'No matching Tag Groups found';

  @override
  String get tagGroup_groupExists => 'This Tag Group is already added';

  @override
  String get tagGroup_addSuccess => 'Tag Group mapping added successfully';

  @override
  String get tagGroup_removeConfirm => 'Are you sure you want to remove this Tag Group mapping?';

  @override
  String get tagGroup_removeSuccess => 'Tag Group mapping removed';

  @override
  String tagGroup_tagCount(Object count) {
    return '$count tags';
  }

  @override
  String tagGroup_childCount(Object count) {
    return '$count sub-groups';
  }

  @override
  String get tagGroup_alreadyAdded => 'Added';

  @override
  String get tagGroup_resetToDefault => 'Reset to Default';

  @override
  String get tagGroup_resetConfirm => 'Are you sure you want to reset to default Tag Group mappings? Current configuration will be overwritten.';

  @override
  String get tagGroup_resetSuccess => 'Reset to default configuration';

  @override
  String get tagGroup_minPostCount => 'Minimum Post Count';

  @override
  String tagGroup_postCountValue(Object count) {
    return '$count posts';
  }

  @override
  String get tagGroup_minPostCountHint => 'Only sync tags with post count above this threshold';

  @override
  String get tagGroup_preview => 'Tag Preview';

  @override
  String tagGroup_previewCount(Object count) {
    return 'Preview $count tags';
  }

  @override
  String get tagGroup_selectToPreview => 'Select a Tag Group to see preview';

  @override
  String get tagGroup_noTagsInGroup => 'No tags in this group';

  @override
  String tagGroup_andMore(Object count) {
    return 'and $count more...';
  }

  @override
  String get tagGroup_options => 'Options';

  @override
  String get tagGroup_includeChildren => 'Include sub-group tags';

  @override
  String get tagGroup_includesChildren => 'Includes sub-groups';

  @override
  String get tagGroup_syncPreparing => 'Preparing sync...';

  @override
  String tagGroup_syncFetching(Object name, Object current, Object total) {
    return 'Fetching $name... ($current/$total)';
  }

  @override
  String tagGroup_syncFiltering(Object total, Object filtered) {
    return 'Filtering: $total tags, keeping $filtered tags';
  }

  @override
  String tagGroup_syncCompleted(Object count) {
    return 'Sync completed, $count tags total';
  }

  @override
  String tagGroup_syncFailed(Object error) {
    return 'Sync failed: $error';
  }

  @override
  String tagGroup_addTo(Object category) {
    return 'Add to: $category';
  }

  @override
  String get tagGroup_refresh => 'Refresh list';

  @override
  String get tagGroup_loadingFromDanbooru => 'Loading Tag Groups from Danbooru...';

  @override
  String get tagGroup_loadFailed => 'Failed to load Tag Groups, please check network connection';

  @override
  String tagGroup_loadError(Object error) {
    return 'Load failed: $error';
  }

  @override
  String get tagGroup_reload => 'Reload';

  @override
  String get tagGroup_searchHintAlt => 'Or use search to find specific groups';

  @override
  String get tagGroup_selected => 'Selected';

  @override
  String get tagGroup_manageGroups => 'Manage Groups';

  @override
  String get tagGroup_manageGroupsHint => 'Select Tag Groups to sync';

  @override
  String tagGroup_selectedCount(Object count) {
    return 'Selected $count groups';
  }

  @override
  String get naiMode_syncCategory => 'Sync Category';

  @override
  String get naiMode_syncCategoryTooltip => 'Sync extended tags for this category only';

  @override
  String get naiMode_viewDetails => 'View Details';

  @override
  String get naiMode_tagListTitle => 'Tag List';

  @override
  String get naiMode_desc_hairColor => 'Hair color tags for describing character\'s hair color';

  @override
  String get naiMode_desc_eyeColor => 'Eye color tags for describing character\'s eye color';

  @override
  String get naiMode_desc_hairStyle => 'Hair style tags for describing character\'s hairstyle';

  @override
  String get naiMode_desc_expression => 'Expression tags for describing facial expressions';

  @override
  String get naiMode_desc_pose => 'Pose tags for describing body postures and actions';

  @override
  String get naiMode_desc_clothing => 'Clothing tags for describing outfits';

  @override
  String get naiMode_desc_accessory => 'Accessory tags for describing decorations and accessories';

  @override
  String get naiMode_desc_bodyFeature => 'Body feature tags for describing body characteristics';

  @override
  String get naiMode_desc_background => 'Background tags for describing background types';

  @override
  String get naiMode_desc_scene => 'Scene tags for describing scene elements';

  @override
  String get naiMode_desc_style => 'Style tags for describing art styles';

  @override
  String get naiMode_desc_characterCount => 'Character count tags for determining number of characters';

  @override
  String get tagGroup_builtin => 'Built-in';

  @override
  String tagGroup_totalTagsTooltip(Object original, Object filtered) {
    return 'Original: $original / Filtered: $filtered';
  }

  @override
  String get tagGroup_cacheDetails => 'Cache Details';

  @override
  String get tagGroup_cachedCategories => 'Cached Categories';

  @override
  String get cache_title => 'Word Groups';

  @override
  String get cache_manage => 'Word Groups';

  @override
  String get cache_tabTagGroup => 'Tag Group';

  @override
  String get cache_tabPool => 'Pool';

  @override
  String get cache_noTagGroups => 'No Tag Group cache';

  @override
  String get cache_noPools => 'No Pool cache';

  @override
  String get cache_noBuiltin => 'No built-in dictionaries';

  @override
  String get cache_probability => 'Probability';

  @override
  String get cache_tags => 'tags';

  @override
  String get cache_posts => 'posts';

  @override
  String get cache_neverSynced => 'Never synced';

  @override
  String get cache_refresh => 'Refresh';

  @override
  String cache_refreshFailed(String error) {
    return 'Refresh failed: $error';
  }

  @override
  String get cache_refreshAll => 'Refresh All';

  @override
  String cache_refreshProgress(Object current, Object total, String name) {
    return 'Syncing ($current/$total): $name';
  }

  @override
  String cache_totalStats(Object count, Object tags) {
    return '$count groups, $tags tags total';
  }

  @override
  String get addGroup_fetchingCache => 'Fetching data...';

  @override
  String get addGroup_fetchFailed => 'Failed to fetch data, but you can still add the group';

  @override
  String get addGroup_syncFailed => 'Sync failed, please check network connection and try again';

  @override
  String addGroup_addFailed(String error) {
    return 'Failed to add: $error';
  }

  @override
  String get addGroup_addCustom => 'Add Custom';

  @override
  String get addGroup_filterHint => 'Search cached groups...';

  @override
  String get customGroup_title => 'Add Custom Group';

  @override
  String get customGroup_searchHint => 'Enter keyword to search Danbooru...';

  @override
  String get customGroup_nameLabel => 'Display Name';

  @override
  String get customGroup_add => 'Add & Cache';

  @override
  String get customGroup_searchPrompt => 'Enter keyword and search';

  @override
  String get tagGroup_noCachedData => 'No cached data';

  @override
  String get tagGroup_syncRequired => 'Sync required';

  @override
  String get tagGroup_notSynced => 'Not synced';

  @override
  String get tagGroup_lastSyncTime => 'Last sync';

  @override
  String get tagGroup_heatThreshold => 'Heat threshold';

  @override
  String get tagGroup_totalStats => 'Total';

  @override
  String tagGroup_syncedCount(Object synced, Object total) {
    return '$synced/$total synced';
  }

  @override
  String addGroup_dialogTitle(Object category) {
    return 'Add Dictionary for \"$category\"';
  }

  @override
  String get addGroup_builtinTab => 'Built-in';

  @override
  String get addGroup_tagGroupTab => 'Tag Group';

  @override
  String get addGroup_cancel => 'Cancel';

  @override
  String get addGroup_submit => 'Add';

  @override
  String get addGroup_builtinEnabled => 'Built-in Dictionary Enabled';

  @override
  String get addGroup_builtinEnabledDesc => 'The built-in dictionary for this category is already in use';

  @override
  String get addGroup_enableBuiltin => 'Enable Built-in Dictionary';

  @override
  String get addGroup_enableBuiltinDesc => 'Use the app\'s built-in tag dictionary';

  @override
  String get addGroup_enable => 'Enable';

  @override
  String get addGroup_backToParent => 'Go back';

  @override
  String get addGroup_browseMode => 'Cached List';

  @override
  String get addGroup_customMode => 'Add Other';

  @override
  String get addGroup_allCategories => 'All Categories';

  @override
  String get addGroup_noMoreSubcategories => 'No more subcategories';

  @override
  String addGroup_tagGroupCount(Object count) {
    return '$count Tag Groups';
  }

  @override
  String get addGroup_customInputHint => 'Enter Danbooru tag_group title, e.g.: hair_color';

  @override
  String get addGroup_groupTitleLabel => 'Tag Group Title *';

  @override
  String get addGroup_groupTitleHint => 'e.g.: hair_color or tag_group:hair_color';

  @override
  String get addGroup_displayNameLabel => 'Display Name (Optional)';

  @override
  String get addGroup_displayNameHint => 'Leave empty to use title';

  @override
  String get addGroup_targetCategoryLabel => 'Target Category';

  @override
  String get addGroup_includeChildren => 'Include Sub-groups';

  @override
  String get addGroup_includeChildrenDesc => 'Also fetch tags from all sub-groups of this Tag Group';

  @override
  String get addGroup_errorEmptyTitle => 'Please enter Tag Group title';

  @override
  String get addGroup_errorGroupExists => 'This Tag Group already exists';

  @override
  String get addGroup_sourceTypeLabel => 'Data Source';

  @override
  String get addGroup_poolTab => 'Danbooru Pool';

  @override
  String get addGroup_poolSearchLabel => 'Search Pool';

  @override
  String get addGroup_poolSearchHint => 'Enter pool name to search';

  @override
  String get addGroup_poolSearchEmpty => 'Enter keywords to search Danbooru Pools';

  @override
  String get addGroup_poolSearchError => 'Search failed';

  @override
  String get addGroup_poolNoResults => 'No matching pools found';

  @override
  String addGroup_poolPostCount(Object count) {
    return '$count posts';
  }

  @override
  String get addGroup_noCachedTagGroups => 'No cached Tag Groups';

  @override
  String get addGroup_noCachedTagGroupsHint => 'Please sync Tag Group data in Cache Management first';

  @override
  String get addGroup_noFilterResults => 'No matching results found';

  @override
  String get addGroup_noCachedPools => 'No cached Pools';

  @override
  String get addGroup_noCachedPoolsHint => 'Use the search box to search and add Danbooru Pools';

  @override
  String get addGroup_sectionTagGroups => 'Tag Groups ☁️';

  @override
  String get addGroup_sectionPools => 'Pools 🖼️';

  @override
  String get globalSettings_title => 'Overview Settings';

  @override
  String get globalSettings_resetToDefault => 'Reset to Default';

  @override
  String get globalSettings_characterCountDistribution => 'Character Count Distribution';

  @override
  String get globalSettings_weightRandomOffset => 'Weight Random Offset';

  @override
  String get globalSettings_categoryProbabilityOverview => 'Category Probability Overview';

  @override
  String get globalSettings_cancel => 'Cancel';

  @override
  String get globalSettings_save => 'Save';

  @override
  String globalSettings_saveFailed(Object error) {
    return 'Save failed: $error';
  }

  @override
  String get globalSettings_noCharacter => 'None';

  @override
  String globalSettings_characterCount(Object count) {
    return '$count character(s)';
  }

  @override
  String get globalSettings_enableWeightRandomOffset => 'Enable Weight Random Offset';

  @override
  String get globalSettings_enableWeightRandomOffsetDesc => 'Randomly add brackets during generation to simulate human fine-tuning';

  @override
  String get globalSettings_bracketType => 'Bracket Type';

  @override
  String get globalSettings_bracketEnhance => 'Curly Braces Enhance';

  @override
  String get globalSettings_bracketWeaken => '[] Weaken';

  @override
  String get globalSettings_layerRange => 'Layer Range';

  @override
  String globalSettings_layerRangeValue(Object min, Object max) {
    return '$min - $max layers';
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
  String download_completed(Object name) {
    return '$name download completed';
  }

  @override
  String import_completed(Object name) {
    return '$name import completed';
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
  String get selectionMode_single => 'Single Random';

  @override
  String get selectionMode_multipleNum => 'Multiple Count';

  @override
  String get selectionMode_multipleProb => 'Multiple Prob';

  @override
  String get selectionMode_all => 'All';

  @override
  String get selectionMode_sequential => 'Sequential';

  @override
  String categorySettings_title(Object name) {
    return 'Category Settings - $name';
  }

  @override
  String get categorySettings_probability => 'Category Probability';

  @override
  String get categorySettings_probabilityDesc => 'Probability of this category participating in random generation';

  @override
  String get categorySettings_groupSelectionMode => 'Group Selection Mode';

  @override
  String get categorySettings_groupSelectionModeDesc => 'How to select from sub-groups';

  @override
  String get categorySettings_groupSelectCount => 'Select Count:';

  @override
  String get categorySettings_shuffle => 'Shuffle Order';

  @override
  String get categorySettings_shuffleDesc => 'Randomly arrange selected groups output order';

  @override
  String get categorySettings_unifiedBracket => 'Unified Bracket';

  @override
  String get categorySettings_unifiedBracketDisabled => 'Disabled';

  @override
  String get categorySettings_enableUnifiedBracket => 'Enable Unified Settings';

  @override
  String get categorySettings_enableUnifiedBracketDesc => 'When enabled, will override each group\'s individual bracket settings';

  @override
  String get categorySettings_bracketRange => 'Bracket Layer Range';

  @override
  String categorySettings_bracketMin(Object count) {
    return 'Min: $count layers';
  }

  @override
  String categorySettings_bracketMax(Object count) {
    return 'Max: $count layers';
  }

  @override
  String get categorySettings_bracketPreview => 'Preview:';

  @override
  String get categorySettings_batchSettings => 'Batch Operations';

  @override
  String get categorySettings_batchSettingsDesc => 'Batch operations for all groups under this category';

  @override
  String get categorySettings_enableAllGroups => 'Enable All';

  @override
  String get categorySettings_disableAllGroups => 'Disable All';

  @override
  String get categorySettings_resetGroupSettings => 'Reset Group Settings';

  @override
  String get categorySettings_batchEnableSuccess => 'All groups enabled';

  @override
  String get categorySettings_batchDisableSuccess => 'All groups disabled';

  @override
  String get categorySettings_batchResetSuccess => 'All group settings reset';

  @override
  String tagGroupSettings_title(Object name) {
    return 'Group Settings - $name';
  }

  @override
  String get tagGroupSettings_probability => 'Selection Probability';

  @override
  String get tagGroupSettings_probabilityDesc => 'Probability of this group being selected';

  @override
  String get tagGroupSettings_selectionMode => 'Selection Mode';

  @override
  String get tagGroupSettings_selectionModeDesc => 'How to select tags from this group';

  @override
  String get tagGroupSettings_selectCount => 'Select Count:';

  @override
  String get tagGroupSettings_shuffle => 'Shuffle Order';

  @override
  String get tagGroupSettings_shuffleDesc => 'Randomly arrange selected tags output order';

  @override
  String get tagGroupSettings_bracket => 'Weight Brackets';

  @override
  String get tagGroupSettings_bracketDesc => 'Randomly add weight brackets to selected tags, each curly bracket adds ~5% weight';

  @override
  String tagGroupSettings_bracketMin(Object count) {
    return 'Min: $count layers';
  }

  @override
  String tagGroupSettings_bracketMax(Object count) {
    return 'Max: $count layers';
  }

  @override
  String get tagGroupSettings_bracketPreview => 'Preview:';

  @override
  String get categorySettings_settingsButton => 'Settings';

  @override
  String get tagGroupSettings_settingsButton => 'Settings';

  @override
  String get promptConfig_tagCountUnit => 'tags';

  @override
  String get promptConfig_removeGroup => 'Remove Group';

  @override
  String get preset_resetToDefault => 'Reset to Default';

  @override
  String get preset_resetConfirmTitle => 'Reset Preset';

  @override
  String get preset_resetConfirmMessage => 'Are you sure you want to reset all categories and groups in the current preset to default? This action cannot be undone.';

  @override
  String get preset_resetSuccess => 'Preset has been reset to default';

  @override
  String get newPresetDialog_title => 'Create New Preset';

  @override
  String get newPresetDialog_blank => 'Completely Blank';

  @override
  String get newPresetDialog_blankDesc => 'Create preset from scratch with no preset content';

  @override
  String get newPresetDialog_template => 'Based on Default Preset';

  @override
  String get newPresetDialog_templateDesc => 'Copy all settings from default preset as starting point';

  @override
  String get category_addNew => 'Add Category';

  @override
  String get category_dialogTitle => 'Create Category';

  @override
  String get category_name => 'Name';

  @override
  String get category_nameHint => 'Enter category name';

  @override
  String get category_key => 'Key';

  @override
  String get category_keyHint => 'Internal identifier';

  @override
  String get category_emoji => 'Icon';

  @override
  String get category_selectEmoji => 'Select Emoji';

  @override
  String get category_probability => 'Probability';

  @override
  String get category_createSuccess => 'Category created';

  @override
  String get category_nameRequired => 'Name is required';

  @override
  String get category_keyRequired => 'Key is required';

  @override
  String get category_keyExists => 'This key already exists';

  @override
  String get group_selectEmoji => 'Select Icon';

  @override
  String get category_noRecentEmoji => 'No recent emojis';

  @override
  String get category_searchEmoji => 'Search emoji';

  @override
  String get addGroup_customTab => 'Custom';

  @override
  String get customGroup_groupName => 'Group Name';

  @override
  String get customGroup_entryPlaceholder => 'Enter entry and press Enter (supports multiple tags, comma separated)';

  @override
  String get customGroup_noEntries => 'No entries yet, add entries to start';

  @override
  String customGroup_entryCount(Object count) {
    return '$count entries';
  }

  @override
  String get customGroup_editEntry => 'Edit Entry';

  @override
  String get customGroup_aliasLabel => 'Alias (optional)';

  @override
  String get customGroup_aliasHint => 'Enter a memorable alias';

  @override
  String get customGroup_contentLabel => 'Prompt Content';

  @override
  String get customGroup_contentHint => 'Enter actual prompt content';

  @override
  String get customGroup_save => 'Save';

  @override
  String get customGroup_confirm => 'Confirm';

  @override
  String get customGroup_selectEmoji => 'Select Icon';

  @override
  String get customGroup_nameRequired => 'Please enter group name';

  @override
  String get customGroup_addEntry => 'Add Entry';

  @override
  String get customGroup_noCustomGroups => 'No custom groups yet';

  @override
  String get customGroup_createInCacheManager => 'Create custom groups in \"Group Manager\"';

  @override
  String get cache_createCustomGroup => 'Create Custom Group';

  @override
  String cache_confirmDeleteCustomGroup(Object name) {
    return 'Are you sure you want to delete custom group \"$name\"?';
  }

  @override
  String get cache_customTab => 'Custom';

  @override
  String get cache_addFromDanbooru => 'Add from Danbooru';

  @override
  String get customGroup_emptyStateTitle => 'Start adding entries';

  @override
  String get customGroup_emptyStateHint => 'Type in the input field above and press Enter to add';

  @override
  String get common_comingSoon => 'Coming soon...';

  @override
  String get common_openInBrowser => 'Open in browser';

  @override
  String get customGroup_tagsPlaceholder => 'Enter tags, separated by commas (autocomplete supported)...';

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
  String get characterCountConfig_addMultiPersonCombo => 'Add Multi-Person Combo';

  @override
  String get characterCountConfig_displayName => 'Display Name';

  @override
  String get characterCountConfig_displayNameHint => 'e.g., Trap';

  @override
  String get characterCountConfig_mainPromptLabel => 'Main Prompt Tags';

  @override
  String get characterCountConfig_mainPromptHint => 'e.g., solo, 2girls, 1girl 1boy';

  @override
  String get characterCountConfig_personCount => 'Person Count:';

  @override
  String get characterCountConfig_slotConfig => 'Character Slot Config';

  @override
  String get characterCountConfig_slot => 'Slot';

  @override
  String get characterCountConfig_resetToDefault => 'Reset to Default';

  @override
  String get characterCountConfig_customSlots => 'Custom Slots';

  @override
  String get characterCountConfig_customSlotsTitle => 'Character Slot Management';

  @override
  String get characterCountConfig_customSlotsDesc => 'Add or remove available character slot options';

  @override
  String get characterCountConfig_addSlot => 'Add Slot';

  @override
  String get characterCountConfig_addSlotHint => 'e.g., 1trap, 1futanari';

  @override
  String get characterCountConfig_slotExists => 'This slot already exists';

  @override
  String get characterCountConfig_cannotDeleteBuiltin => 'Cannot delete built-in slot';

  @override
  String get genderRestriction_enabled => 'Gender Restriction';

  @override
  String get genderRestriction_enabledDesc => 'Gender filter not enabled';

  @override
  String genderRestriction_enabledActive(Object count) {
    return 'Enabled, $count genders available';
  }

  @override
  String get genderRestriction_enable => 'Enable Gender Restriction';

  @override
  String get genderRestriction_enableDesc => 'Only apply to characters of specified genders';

  @override
  String get genderRestriction_applicableGenders => 'Applicable Genders';

  @override
  String get gender_female => 'Female';

  @override
  String get gender_male => 'Male';

  @override
  String get gender_trap => 'Trap';

  @override
  String get gender_futanari => 'Futanari';

  @override
  String get scope_title => 'Scope';

  @override
  String get scope_titleDesc => 'Set the applicable scope of this category/group';

  @override
  String get scope_global => 'Main';

  @override
  String get scope_globalTooltip => 'Prompt will appear in main prompt area\nSuitable for: background, scene, style, etc.';

  @override
  String get scope_character => 'Char';

  @override
  String get scope_characterTooltip => 'Prompt will only appear in character prompts\nGenerated separately for each character\nSuitable for: hair color, eye color, clothing, expression, etc.';

  @override
  String get scope_all => 'Both';

  @override
  String get scope_allTooltip => 'Prompt appears in both main and character prompts\nSuitable for: pose, interaction, and other universal tags';

  @override
  String get tagGroupSettings_resetToCategory => 'Reset to Category Settings';

  @override
  String get bracket_weaken => 'weaken';

  @override
  String get bracket_enhance => 'enhance';

  @override
  String get vibeNoEncodingWarning => 'This image has no pre-encoded data';

  @override
  String vibeWillCostAnlas(int count) {
    return 'Encoding will cost $count Anlas';
  }

  @override
  String get vibeEncodeConfirm => 'Continue and consume Anlas?';

  @override
  String get vibeCancel => 'Cancel';

  @override
  String get vibeConfirmEncode => 'Encode';

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
  String get tagGroupBrowser_importLibraryHint => 'Please import a tag library first';

  @override
  String get tagGroupBrowser_noCategories => 'No enabled tag categories';

  @override
  String get tagGroupBrowser_enableCategoriesHint => 'Please enable tag categories in settings';

  @override
  String get tagGroupBrowser_danbooruSuggestions => 'Danbooru Suggestions';

  @override
  String get tag_favoritesTitle => 'Favorite Tags';

  @override
  String get tag_favoritesEmpty => 'No favorite tags yet';

  @override
  String get tag_favoritesEmptyHint => 'Long-press on a tag to add it to favorites';

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
  String get tag_templatesEmptyHint => 'Select tags and click the + button to create a template';

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
  String get tag_tabTags => 'Tags';

  @override
  String get tag_tabGroups => 'Groups';

  @override
  String get tag_tabFavorites => 'Favorites';

  @override
  String get tag_tabTemplates => 'Templates';

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
  String tag_countBadgeTooltip(Object total) {
    return 'Total $total tags';
  }

  @override
  String get tag_countBadgeBreakdown => 'Tag Breakdown';

  @override
  String tag_countEnabled(Object count) {
    return '$count enabled';
  }

  @override
  String get localGallery_searchIndexing => 'Building search index...';

  @override
  String get localGallery_searchIndexComplete => 'Search index ready';

  @override
  String get localGallery_searchIndexFailed => 'Search index error';

  @override
  String localGallery_cacheStatus(Object current, Object max) {
    return 'Cache: $current/$max images';
  }

  @override
  String localGallery_cacheHitRate(Object rate) {
    return 'Hit rate: $rate%';
  }

  @override
  String get localGallery_preloading => 'Preloading images...';

  @override
  String get localGallery_preloadComplete => 'Preload complete';

  @override
  String get localGallery_progressiveLoadError => 'Failed to load image';

  @override
  String get localGallery_noImagesFound => 'No images found';

  @override
  String get localGallery_searchPlaceholder => 'Search prompts, models, samplers...';

  @override
  String get localGallery_filterByDate => 'Filter by date';

  @override
  String get localGallery_clearFilters => 'Clear filters';

  @override
  String get slideshow_title => 'Slideshow';

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
  String get slideshow_keyboardHint => 'Use ← → to navigate, Space to play/pause, Esc to exit';

  @override
  String slideshow_autoPlayInterval(Object seconds) {
    return 'Auto-play interval: ${seconds}s';
  }

  @override
  String get comparison_title => 'Image Comparison';

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
  String get statistics_tabOverview => 'Overview';

  @override
  String get statistics_tabTrends => 'Trends';

  @override
  String get statistics_tabDetails => 'Details';

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
  String get statistics_overview => 'Overview';

  @override
  String get statistics_totalImages => 'Total Images';

  @override
  String get statistics_totalSize => 'Total Size';

  @override
  String get statistics_favorites => 'Favorites';

  @override
  String get statistics_tagged => 'Tagged';

  @override
  String get statistics_modelDistribution => 'Model Distribution';

  @override
  String get statistics_resolutionDistribution => 'Resolution Distribution';

  @override
  String get statistics_samplerDistribution => 'Sampler Distribution';

  @override
  String get statistics_sizeDistribution => 'File Size Distribution';

  @override
  String get statistics_additionalStats => 'Additional Statistics';

  @override
  String get statistics_averageFileSize => 'Average File Size';

  @override
  String get statistics_withMetadata => 'Images with Metadata';

  @override
  String get statistics_calculatedAt => 'Calculated At';

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
  String get localGallery_favoritesOnly => 'Favorites Only';

  @override
  String get localGallery_noFavorites => 'No favorites yet';

  @override
  String get localGallery_markAsFavorite => 'Mark as Favorite';

  @override
  String get localGallery_removeFromFavorites => 'Remove from Favorites';

  @override
  String get localGallery_tags => 'Tags';

  @override
  String get localGallery_addTag => 'Add Tag';

  @override
  String get localGallery_removeTag => 'Remove Tag';

  @override
  String get localGallery_noTags => 'No tags';

  @override
  String get localGallery_filterByTags => 'Filter by Tags';

  @override
  String get localGallery_selectTags => 'Select Tags';

  @override
  String get localGallery_tagFilterMatchAll => 'Match All Tags';

  @override
  String get localGallery_tagFilterMatchAny => 'Match Any Tag';

  @override
  String get localGallery_clearTagFilter => 'Clear Tag Filter';

  @override
  String get localGallery_noTagsFound => 'No tags found';

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
  String get localGallery_model => 'Model';

  @override
  String get localGallery_sampler => 'Sampler';

  @override
  String get localGallery_steps => 'Steps';

  @override
  String get localGallery_cfgScale => 'CFG Scale';

  @override
  String get localGallery_resolution => 'Resolution';

  @override
  String get localGallery_any => 'Any';

  @override
  String get localGallery_custom => 'Custom';

  @override
  String get localGallery_to => 'to';

  @override
  String get localGallery_applyFilters => 'Apply Filters';

  @override
  String get localGallery_resetAdvancedFilters => 'Reset Advanced Filters';

  @override
  String get localGallery_exportMetadata => 'Export Metadata';

  @override
  String get localGallery_exportSelected => 'Export Selected';

  @override
  String get localGallery_exportFailed => 'Export failed';

  @override
  String get localGallery_exporting => 'Exporting...';

  @override
  String get localGallery_selectToExport => 'Select images to export';

  @override
  String get localGallery_noImagesSelected => 'No images selected';

  @override
  String localGallery_exportSuccessDetail(Object count) {
    return 'Exported $count images with metadata';
  }

  @override
  String bulkExport_title(Object count) {
    return 'Export $count images';
  }

  @override
  String get bulkExport_format => 'Format';

  @override
  String get bulkExport_jsonFormat => 'JSON';

  @override
  String get bulkExport_csvFormat => 'CSV';

  @override
  String get bulkExport_metadataOptions => 'Metadata Options';

  @override
  String get bulkExport_includeMetadata => 'Include metadata';

  @override
  String get bulkExport_includeMetadataHint => 'Export generation parameters with images';

  @override
  String get localGallery_group_today => 'Today';

  @override
  String get localGallery_group_yesterday => 'Yesterday';

  @override
  String get localGallery_group_thisWeek => 'This Week';

  @override
  String get localGallery_group_earlier => 'Earlier';

  @override
  String get localGallery_group_dateFormat => 'MMM dd';

  @override
  String get localGallery_jumpToDate => 'Jump to Date';

  @override
  String get localGallery_noImagesOnThisDate => 'No images on this date';

  @override
  String get localGallery_selectedImagesNoPrompt => 'Selected images have no prompt information';

  @override
  String localGallery_addedTasksToQueue(Object count) {
    return 'Added $count tasks to queue';
  }

  @override
  String localGallery_cannotOpenFolder(Object error) {
    return 'Cannot open folder: $error';
  }

  @override
  String localGallery_jumpedToDate(Object date) {
    return 'Jumped to $date';
  }

  @override
  String get localGallery_permissionRequiredTitle => 'Storage Permission Required';

  @override
  String get localGallery_permissionRequiredContent => 'Local gallery needs storage permission to scan your generated images.\n\nPlease grant permission in settings and try again.';

  @override
  String get localGallery_openSettings => 'Open Settings';

  @override
  String get localGallery_firstTimeTipTitle => '💡 Tips';

  @override
  String get localGallery_firstTimeTipContent => 'Right-click (desktop) or long-press (mobile) on images to:\n\n• Copy Prompt\n• Copy Seed\n• View full metadata';

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
  String get localGallery_noFoldersAvailable => 'No folders available, please create a folder first';

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
  String get localGallery_addToCollectionFailed => 'Failed to add images to collection';

  @override
  String get brushPreset_selectHint => 'Double tap to select this brush preset';

  @override
  String get brushPreset_selected => 'Selected';

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
  String get bulkProgress_title_removeFromCollection => 'Removing from Collection';

  @override
  String get bulkProgress_title_toggleFavorite => 'Updating Favorites';

  @override
  String get bulkProgress_title_default => 'Processing';

  @override
  String get collectionSelect_dialogTitle => 'Select Collection';

  @override
  String get collectionSelect_filterHint => 'Search collections...';

  @override
  String get collectionSelect_noCollections => 'No collections';

  @override
  String get collectionSelect_createCollectionHint => 'Create a collection first';

  @override
  String get collectionSelect_noFilterResults => 'No matching collections found';

  @override
  String collectionSelect_imageCount(int count) {
    return '$count images';
  }

  @override
  String get statistics_navOverview => 'Overview';

  @override
  String get statistics_navModels => 'Models';

  @override
  String get statistics_navTags => 'Tags';

  @override
  String get statistics_navParameters => 'Parameters';

  @override
  String get statistics_navTrends => 'Trends';

  @override
  String get statistics_navActivity => 'Activity';

  @override
  String get statistics_sectionTagAnalysis => 'Tag Analysis';

  @override
  String get statistics_sectionParameterPrefs => 'Parameter Preferences';

  @override
  String get statistics_sectionActivityAnalysis => 'Activity Analysis';

  @override
  String get statistics_chartUsageDistribution => 'Usage Distribution';

  @override
  String get statistics_chartModelRanking => 'Model Ranking';

  @override
  String get statistics_chartModelUsageOverTime => 'Model Usage Over Time';

  @override
  String get statistics_chartTopTags => 'Top Tags';

  @override
  String get statistics_chartTagCloud => 'Tag Cloud';

  @override
  String get statistics_chartParameterOverview => 'Parameter Overview';

  @override
  String get statistics_chartAspectRatio => 'Aspect Ratio Distribution';

  @override
  String get statistics_chartActivityHeatmap => 'Activity Heatmap';

  @override
  String get statistics_chartHourlyDistribution => 'Hourly Distribution';

  @override
  String get statistics_chartWeekdayDistribution => 'Weekday Distribution';

  @override
  String get statistics_filterTitle => 'Filters';

  @override
  String get statistics_filterClear => 'Clear';

  @override
  String get statistics_filterDateRange => 'Date Range';

  @override
  String get statistics_filterModel => 'Model';

  @override
  String get statistics_filterAllModels => 'All Models';

  @override
  String get statistics_filterResolution => 'Resolution';

  @override
  String get statistics_filterAllResolutions => 'All Resolutions';

  @override
  String get statistics_granularity => 'Granularity';

  @override
  String get statistics_granularityDay => 'Day';

  @override
  String get statistics_granularityWeek => 'Week';

  @override
  String get statistics_granularityMonth => 'Month';

  @override
  String get statistics_labelTotalDays => 'Total Days';

  @override
  String get statistics_labelPeak => 'Peak';

  @override
  String get statistics_labelAverage => 'Average';

  @override
  String get statistics_labelSteps => 'Steps';

  @override
  String get statistics_labelCfg => 'CFG';

  @override
  String get statistics_labelWidth => 'Width';

  @override
  String get statistics_labelHeight => 'Height';

  @override
  String get statistics_labelFavPercent => 'Fav%';

  @override
  String get statistics_labelTagPercent => 'Tag%';

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
  String get statistics_noMetadata => 'No metadata available';

  @override
  String get statistics_unknown => 'Unknown';

  @override
  String statistics_weekLabel(Object week) {
    return 'W$week';
  }

  @override
  String get statistics_peakHour => 'Peak Hour';

  @override
  String get statistics_mostActiveDay => 'Most Active Day';

  @override
  String get statistics_leastActiveDay => 'Least Active Day';

  @override
  String get statistics_morning => 'Morning';

  @override
  String get statistics_afternoon => 'Afternoon';

  @override
  String get statistics_evening => 'Evening';

  @override
  String get statistics_night => 'Night';

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
  String get fixedTags_empty => 'No fixed tags';

  @override
  String get fixedTags_emptyHint => 'Click the button below to add fixed tags, they will be automatically applied to your prompts';

  @override
  String get fixedTags_clickToManage => 'Click to manage fixed tags';

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
  String get fixedTags_prefixDesc => 'Add before prompt';

  @override
  String get fixedTags_suffixDesc => 'Add after prompt';

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
  String get fixedTags_contentHint => 'Enter prompt content, NAI syntax supported';

  @override
  String get fixedTags_syntaxHelp => 'Supports NAI syntax for weight enhancement/reduction and tag alternation';

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
  String get fixedTags_saveToLibraryHint => 'For reuse in the tag library later';

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
  String get tagLibrary_cardView => 'Card View';

  @override
  String get tagLibrary_listView => 'List View';

  @override
  String get tagLibrary_import => 'Import';

  @override
  String get tagLibrary_export => 'Export';

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
  String get tagLibrary_addFirstEntry => 'Click the button above to add your first entry';

  @override
  String get tagLibraryPicker_title => 'Select Entry';

  @override
  String get tagLibraryPicker_searchHint => 'Search entries...';

  @override
  String get tagLibraryPicker_allCategories => 'All Categories';

  @override
  String get tagLibrary_addToFixed => 'Add to Fixed Tags';

  @override
  String get tagLibrary_addedToFixed => 'Added to Fixed Tags';

  @override
  String get tagLibrary_entryMoved => 'Entry moved to target category';

  @override
  String tagLibrary_useCount(Object count) {
    return 'Used $count times';
  }

  @override
  String get tagLibrary_removeFavorite => 'Remove from Favorites';

  @override
  String get tagLibrary_addFavorite => 'Add to Favorites';

  @override
  String get tagLibrary_pinned => 'Favorited';

  @override
  String get tagLibrary_thumbnail => 'Thumbnail';

  @override
  String get tagLibrary_selectImage => 'Select Image';

  @override
  String get tagLibrary_thumbnailHint => 'Supports PNG/JPG/WEBP';

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
  String get tagLibrary_tagsHelper => 'Tags are used for filtering and searching';

  @override
  String get tagLibrary_content => 'Prompt Content';

  @override
  String get tagLibrary_contentHint => 'Enter prompt content, supports autocomplete';

  @override
  String get settings_network => 'Network';

  @override
  String get settings_enableProxy => 'Enable Proxy';

  @override
  String get settings_proxyEnabled => 'Enabled';

  @override
  String get settings_proxyDisabled => 'Direct connection';

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
  String get settings_proxyRestartHint => 'Proxy settings changed, restart recommended';

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
  String get queue_title => 'Queue';

  @override
  String get queue_management => 'Queue Management';

  @override
  String get queue_empty => 'Queue is empty';

  @override
  String get queue_emptyHint => 'No tasks in the queue';

  @override
  String queue_taskCount(Object count) {
    return '$count tasks';
  }

  @override
  String get queue_pending => 'Pending';

  @override
  String get queue_running => 'Running';

  @override
  String get queue_completed => 'Completed';

  @override
  String get queue_failed => 'Failed';

  @override
  String get queue_skipped => 'Skipped';

  @override
  String get queue_paused => 'Paused';

  @override
  String get queue_idle => 'Idle';

  @override
  String get queue_ready => 'Ready';

  @override
  String get queue_clickToStart => 'Click to start queue execution';

  @override
  String get queue_clickToPause => 'Click to pause queue';

  @override
  String get queue_clickToResume => 'Click to resume execution';

  @override
  String get queue_noTasksToStart => 'Queue is empty, cannot start';

  @override
  String get queue_allTasksCompleted => 'All tasks completed';

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
  String get queue_pauseExecution => 'Pause Execution';

  @override
  String get queue_resumeExecution => 'Resume Execution';

  @override
  String get queue_autoExecute => 'Auto Execute';

  @override
  String get queue_autoExecuteOn => 'Auto execute next task when completed';

  @override
  String get queue_autoExecuteOff => 'Manual click required to generate';

  @override
  String get queue_taskInterval => 'Task Interval';

  @override
  String get queue_taskIntervalHint => 'Wait time between tasks (0-10 seconds)';

  @override
  String get queue_clearQueue => 'Clear Queue';

  @override
  String get queue_closeFloatingButton => 'Close Floating Button';

  @override
  String get queue_clearQueueConfirm => 'Are you sure you want to clear all queue tasks? This action cannot be undone.';

  @override
  String get queue_confirmClear => 'Confirm Clear';

  @override
  String get queue_failureStrategy => 'Failure Strategy';

  @override
  String get queue_failureStrategyAutoRetry => 'Auto Retry';

  @override
  String get queue_failureStrategyAutoRetryDesc => 'Move task to queue end after max retries';

  @override
  String get queue_failureStrategySkip => 'Skip';

  @override
  String get queue_failureStrategySkipDesc => 'Move failed task to failed pool, continue next';

  @override
  String get queue_failureStrategyPause => 'Pause and Wait';

  @override
  String get queue_failureStrategyPauseDesc => 'Pause queue, wait for manual handling';

  @override
  String queue_retryCount(Object current, Object max) {
    return 'Retry $current/$max';
  }

  @override
  String get queue_retry => 'Retry';

  @override
  String get queue_requeue => 'Requeue';

  @override
  String get queue_requeueToEnd => 'Move to queue end';

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
  String get queue_positivePrompt => 'Positive Prompt';

  @override
  String get queue_enterPositivePrompt => 'Enter positive prompt...';

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
  String get queue_addToQueue => 'Add to Queue';

  @override
  String get queue_taskAdded => 'Added to queue';

  @override
  String get queue_negativePromptFromMain => 'Negative prompt will use main page settings';

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
  String get queue_batchDelete => 'Delete Selected';

  @override
  String get queue_batchPinToTop => 'Pin Selected';

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
  String get queue_exportFormatCsvDesc => 'Table format with prompts and basic info';

  @override
  String get queue_exportFormatText => 'Plain Text';

  @override
  String get queue_exportFormatTextDesc => 'Prompts only, one per line';

  @override
  String get queue_importStrategy => 'Import Strategy';

  @override
  String get queue_importStrategyMerge => 'Merge';

  @override
  String get queue_importStrategyMergeDesc => 'Add imported tasks to end of existing queue';

  @override
  String get queue_importStrategyReplace => 'Replace';

  @override
  String get queue_importStrategyReplaceDesc => 'Clear existing queue and replace with imported';

  @override
  String get queue_supportedFormats => 'Supported formats:';

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
  String get queue_settings => 'Queue Settings';

  @override
  String get settings_queueRetryCount => 'Retry Count';

  @override
  String get settings_queueRetryInterval => 'Retry Interval';

  @override
  String get settings_queueRetryCountSubtitle => 'Maximum retry attempts for failed tasks';

  @override
  String get settings_queueRetryIntervalSubtitle => 'Time to wait between retries';

  @override
  String get unit_times => 'times';

  @override
  String get unit_seconds => 'seconds';

  @override
  String get settings_floatingButtonBackground => 'Floating Button Background';

  @override
  String get settings_floatingButtonBackgroundCustom => 'Custom background set';

  @override
  String get settings_floatingButtonBackgroundDefault => 'Default style';

  @override
  String get settings_clearBackground => 'Clear background';

  @override
  String get settings_selectImage => 'Select Image';

  @override
  String queue_currentQueueInfo(Object count) {
    return 'Current queue contains $count tasks';
  }

  @override
  String queue_tooltipTasksTotal(Object count) {
    return 'Tasks: $count';
  }

  @override
  String queue_tooltipCompleted(Object count) {
    return 'Completed: $count';
  }

  @override
  String queue_tooltipFailed(Object count) {
    return 'Failed: $count';
  }

  @override
  String queue_tooltipCurrentTask(Object task) {
    return 'Current: $task';
  }

  @override
  String get queue_tooltipNoTasks => 'No tasks in queue';

  @override
  String get queue_tooltipDoubleClickToOpen => 'Double-click to start/pause';

  @override
  String get queue_tooltipClickToToggle => 'Click to open queue';

  @override
  String get queue_tooltipDragToMove => 'Drag to reposition';

  @override
  String get queue_statusIdle => 'Status: Idle';

  @override
  String get queue_statusReady => 'Status: Ready';

  @override
  String get queue_statusRunning => 'Status: Running';

  @override
  String get queue_statusPaused => 'Status: Paused';

  @override
  String get queue_statusCompleted => 'Status: Completed';

  @override
  String get settings_notification => 'Sound';

  @override
  String get settings_notificationSound => 'Completion Sound';

  @override
  String get settings_notificationSoundSubtitle => 'Play sound when generation completes';

  @override
  String get settings_notificationCustomSound => 'Custom Sound';

  @override
  String get settings_notificationCustomSoundSubtitle => 'Select custom sound file';

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
  String get resetToDefaultConfirmTitle => 'Reset to Default';

  @override
  String get resetToDefaultConfirmContent => 'This will restore official default configuration. Your custom groups will be kept but disabled.';

  @override
  String get groupEnabled => 'Group enabled';

  @override
  String get groupDisabled => 'Group disabled';

  @override
  String get toggleGroupEnabled => 'Toggle group enabled state';

  @override
  String get diyNotAvailableForDefault => 'DIY not available for default preset';

  @override
  String get diyNotAvailableHint => 'Please copy to a custom preset to edit';

  @override
  String get customGroupDisabledAfterReset => 'Custom group (disabled)';

  @override
  String get confirmReset => 'Confirm Reset';

  @override
  String get alias_hintText => 'Enter prompts, or use <library name> to reference library content';

  @override
  String get alias_libraryCategory => 'Library';

  @override
  String alias_tagCount(Object count) {
    return '$count tags';
  }

  @override
  String alias_useCount(Object count) {
    return 'Used $count times';
  }

  @override
  String get alias_favorited => 'Favorited';

  @override
  String get statistics_heatmapLess => 'Less';

  @override
  String get statistics_heatmapMore => 'More';

  @override
  String get statistics_heatmapWeekLabel => 'Week';

  @override
  String statistics_heatmapActivities(Object count) {
    return '$count activities';
  }

  @override
  String get statistics_heatmapNoActivity => 'No activity';

  @override
  String get sendToHome_dialogTitle => 'Send to Home';

  @override
  String get sendToHome_mainPrompt => 'Send to Main Prompt';

  @override
  String get sendToHome_mainPromptSubtitle => 'Fill into the main prompt input field';

  @override
  String get sendToHome_replaceCharacter => 'Replace Character Prompt';

  @override
  String get sendToHome_replaceCharacterSubtitle => 'Clear existing characters and add as new';

  @override
  String get sendToHome_appendCharacter => 'Append Character Prompt';

  @override
  String get sendToHome_appendCharacterSubtitle => 'Keep existing characters and append new';

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
  String get metadataImport_advancedSection => 'Advanced Options';

  @override
  String get metadataImport_selectAll => 'Select All';

  @override
  String get metadataImport_deselectAll => 'Deselect All';

  @override
  String get metadataImport_promptsOnly => 'Prompts Only';

  @override
  String get metadataImport_generationOnly => 'Generation Only';

  @override
  String get metadataImport_prompt => 'Positive Prompt';

  @override
  String get metadataImport_negativePrompt => 'Negative Prompt';

  @override
  String get metadataImport_characterPrompts => 'Character Prompts';

  @override
  String get metadataImport_seed => 'Seed';

  @override
  String get metadataImport_steps => 'Steps';

  @override
  String get metadataImport_scale => 'CFG Scale';

  @override
  String get metadataImport_size => 'Size';

  @override
  String get metadataImport_sampler => 'Sampler';

  @override
  String get metadataImport_model => 'Model';

  @override
  String get metadataImport_smea => 'SMEA';

  @override
  String get metadataImport_smeaDyn => 'SMEA Dyn';

  @override
  String get metadataImport_noiseSchedule => 'Noise Schedule';

  @override
  String get metadataImport_cfgRescale => 'CFG Rescale';

  @override
  String get metadataImport_qualityToggle => 'Quality Toggle';

  @override
  String get metadataImport_ucPreset => 'UC Preset';

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
  String get metadataImport_appliedTitle => 'Metadata Applied';

  @override
  String get metadataImport_appliedDescription => 'The following parameters have been applied:';

  @override
  String get metadataImport_charactersCount => 'characters';

  @override
  String metadataImport_extractFailed(String error) {
    return 'Failed to extract metadata: $error';
  }

  @override
  String metadataImport_appliedToMain(int count) {
    return 'Applied $count parameters to main screen';
  }

  @override
  String get metadataImport_quickSelectHint => 'Click buttons above to quickly select parameter types';

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
  String get shortcut_settings_description => 'Customize keyboard shortcuts for quick access';

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
  String get shortcut_settings_no_results => 'No shortcuts found';

  @override
  String get shortcut_settings_press_key => 'Press key combination...';

  @override
  String shortcut_settings_conflict(Object action) {
    return 'Conflict with: $action';
  }

  @override
  String get shortcut_help_title => 'Keyboard Shortcuts Help';

  @override
  String get shortcut_help_search => 'Search shortcuts...';

  @override
  String get shortcut_help_customize => 'Customize Shortcuts';

  @override
  String get drop_extractMetadata => 'Extract Metadata';

  @override
  String get drop_extractMetadataSubtitle => 'Read Prompt, Seed and other parameters from image';

  @override
  String get drop_addToQueue => 'Add to Queue';

  @override
  String get drop_addToQueueSubtitle => 'Extract positive prompt and add to generation queue';

  @override
  String get drop_vibeDetected => 'Pre-encoded Vibe detected (saves 2 Anlas)';

  @override
  String drop_vibeStrength(Object value) {
    return 'Strength: $value%';
  }

  @override
  String drop_vibeInfoExtracted(Object value) {
    return 'Info Extracted: $value%';
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
  String get preciseRef_title => 'Precise Reference';

  @override
  String get preciseRef_description => 'Add reference images and set type and parameters. Multiple references can be used simultaneously.';

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
  String get preciseRef_v4Only => 'This feature requires V4+ models';

  @override
  String get preciseRef_typeCharacter => 'Character';

  @override
  String get preciseRef_typeStyle => 'Style';

  @override
  String get preciseRef_typeCharacterAndStyle => 'Character + Style';

  @override
  String get vibeLibrary_title => 'Vibe Library';

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
  String get vibe_export_title => 'Export Vibe';

  @override
  String get vibe_export_format => 'Export Format';

  @override
  String get vibe_selector_title => 'Select Vibe';

  @override
  String get vibe_selector_recent => 'Recent';

  @override
  String get vibe_category_add => 'Add Category';

  @override
  String get vibe_category_rename => 'Rename Category';

  @override
  String get drop_vibe_detected => 'Vibe image detected';

  @override
  String get drop_reuse_vibe => 'Reuse Vibe';

  @override
  String drop_save_anlas(int cost) {
    return 'Save $cost Anlas';
  }

  @override
  String get vibe_export_include_thumbnails => 'Include Thumbnails';

  @override
  String get vibe_export_include_thumbnails_subtitle => 'Include thumbnail preview in export file';

  @override
  String get vibe_import_skip => 'Skip';

  @override
  String get vibe_import_confirm => 'Confirm';

  @override
  String get bundle_internalVibes => 'Internal Vibes';

  @override
  String get shortcuts_customize => 'Customize Shortcuts';

  @override
  String get gallery_send_to => 'Send To';

  @override
  String get image_editor_select_tool => 'Select Tool';

  @override
  String get selection_clear_selection => 'Clear Selection';

  @override
  String get selection_invert_selection => 'Invert Selection';

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
  String get shortcut_action_vibe_detail_send_to_generation => 'Send to Generation';

  @override
  String get shortcut_action_vibe_detail_export => 'Export';

  @override
  String get shortcut_action_vibe_detail_rename => 'Rename';

  @override
  String get shortcut_action_vibe_detail_delete => 'Delete';

  @override
  String get shortcut_action_vibe_detail_toggle_favorite => 'Toggle Favorite';

  @override
  String get shortcut_action_vibe_detail_prev_sub_vibe => 'Previous Sub Vibe';

  @override
  String get shortcut_action_vibe_detail_next_sub_vibe => 'Next Sub Vibe';

  @override
  String get shortcut_action_navigate_to_vibe_library => 'Vibe Library';

  @override
  String get shortcut_action_vibe_import => 'Import Vibe';

  @override
  String get shortcut_action_vibe_export => 'Export Vibe';

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
  String get settings_dataSourceCacheTitle => 'Data source cache management';

  @override
  String get settings_pleaseLoginFirst => 'Please login first';

  @override
  String get settings_accountNotFound => 'Account information not found';

  @override
  String get settings_goToLoginPage => 'Go to login page';

  @override
  String settings_retryCountDisplay(int count) {
    return 'Max $count times';
  }

  @override
  String settings_retryIntervalDisplay(String interval) {
    return '$interval seconds';
  }

  @override
  String get settings_vibePathSaved => 'Vibe library path saved';

  @override
  String get settings_selectFolderFailed => 'Failed to select folder';

  @override
  String get settings_hivePathSaved => 'Data storage path saved, effective after restart';

  @override
  String get settings_restartRequiredTitle => 'Restart Required';

  @override
  String get settings_changePathConfirm => 'After changing the data storage path, the app needs to restart to take effect.\\n\\nThe new path will take effect on the next startup. Continue?';

  @override
  String get settings_resetPathConfirm => 'After resetting the data storage path, the app needs to restart to take effect.\\n\\nThe default path will take effect on the next startup. Continue?';
}

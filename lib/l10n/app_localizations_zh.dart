// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class AppLocalizationsZh extends AppLocalizations {
  AppLocalizationsZh([String locale = 'zh']) : super(locale);

  @override
  String get app_title => 'NAI 启动器';

  @override
  String get app_subtitle => 'NovelAI 第三方客户端';

  @override
  String get common_cancel => '取消';

  @override
  String get common_confirm => '确定';

  @override
  String get common_continue => '继续';

  @override
  String get common_selectAll => '全选';

  @override
  String get common_deselectAll => '全不选';

  @override
  String get common_collapseAll => '收起全部';

  @override
  String get common_save => '保存';

  @override
  String get common_delete => '删除';

  @override
  String get common_edit => '编辑';

  @override
  String get common_close => '关闭';

  @override
  String get common_clear => '清除';

  @override
  String get common_copy => '复制';

  @override
  String get common_copied => '已复制';

  @override
  String get common_export => '导出';

  @override
  String get common_import => '导入';

  @override
  String get common_loading => '加载中...';

  @override
  String get common_error => '错误';

  @override
  String get common_success => '成功';

  @override
  String get common_retry => '重试';

  @override
  String get common_more => '更多';

  @override
  String get common_select => '选择';

  @override
  String get common_reset => '重置';

  @override
  String get common_search => '搜索';

  @override
  String get common_featureInDev => '功能开发中...';

  @override
  String get common_add => '添加';

  @override
  String get common_added => '已添加';

  @override
  String get common_new => '新建';

  @override
  String get common_confirmDelete => '确认删除';

  @override
  String get common_confirmClear => '确认清空';

  @override
  String get common_gotIt => '知道了';

  @override
  String common_deleteItemConfirm(Object itemName) {
    return '确定要删除「$itemName」吗？此操作不可撤销。';
  }

  @override
  String common_clearAllItemsConfirm(Object count, Object itemType) {
    return '确定要清空所有 $count 个$itemType吗？此操作不可撤销。';
  }

  @override
  String get common_clearInputConfirm => '确定要清空输入内容吗？';

  @override
  String get common_today => '今天';

  @override
  String get common_yesterday => '昨天';

  @override
  String common_daysAgo(Object days) {
    return '$days天前';
  }

  @override
  String get common_undo => '撤销';

  @override
  String get common_redo => '重做';

  @override
  String get common_refresh => '刷新';

  @override
  String get common_download => '下载';

  @override
  String get common_upload => '上传';

  @override
  String get common_apply => '应用';

  @override
  String get common_preview => '预览';

  @override
  String get common_view => '查看';

  @override
  String get common_info => '信息';

  @override
  String get common_warning => '警告';

  @override
  String get common_show => '显示';

  @override
  String get common_hide => '隐藏';

  @override
  String get common_move => '移动';

  @override
  String get common_duplicate => '复制';

  @override
  String get common_favorite => '收藏';

  @override
  String get common_unfavorite => '取消收藏';

  @override
  String get common_share => '分享';

  @override
  String get common_ok => '确定';

  @override
  String get common_submit => '提交';

  @override
  String get common_discard => '放弃';

  @override
  String get common_keep => '保留';

  @override
  String get common_replace => '替换';

  @override
  String get common_skip => '跳过';

  @override
  String get common_yes => '是';

  @override
  String get common_no => '否';

  @override
  String get common_exit => '退出';

  @override
  String get common_folder => '文件夹';

  @override
  String get common_filter => '筛选';

  @override
  String get common_grid => '网格';

  @override
  String get common_date => '日期';

  @override
  String get common_pack => '打包';

  @override
  String get common_multiSelect => '多选';

  @override
  String get common_category => '分类';

  @override
  String get common_categories => '分类';

  @override
  String get common_items => '项';

  @override
  String get networkError_connectionTimeout => '连接超时，请检查网络连接。';

  @override
  String get networkError_sendTimeout => '发送超时，请重试。';

  @override
  String get networkError_receiveTimeout => '接收超时，图像生成可能需要更长时间。';

  @override
  String get networkError_requestCancelled => '请求已取消';

  @override
  String get networkError_connection => '网络连接错误，请检查网络连接。';

  @override
  String get networkError_unknown => '未知错误';

  @override
  String get networkError_noResponse => '服务器无响应';

  @override
  String get networkError_badRequest => '请求参数错误';

  @override
  String get networkError_authFailed => '认证失败，请重新登录。';

  @override
  String get networkError_insufficientAnlas => 'Anlas 不足';

  @override
  String get networkError_forbidden => '无权限访问该资源';

  @override
  String get networkError_notFound => '请求的资源不存在';

  @override
  String get networkError_conflict => '请求与当前状态冲突';

  @override
  String get networkError_rateLimited => '请求过于频繁，请稍后重试。';

  @override
  String get networkError_serverInternal => '服务器内部错误';

  @override
  String get networkError_badGateway => '服务器网关错误';

  @override
  String get networkError_unavailable => '服务暂时不可用';

  @override
  String networkError_requestFailed(int code) {
    return '请求失败（$code）';
  }

  @override
  String get nav_canvas => '画布';

  @override
  String get nav_onlineGallery => '画廊';

  @override
  String get nav_randomConfig => '随机配置';

  @override
  String get nav_dictionary => '词库 (WIP)';

  @override
  String get nav_discordCommunity => 'Discord 社群';

  @override
  String get nav_githubRepo => 'GitHub 仓库';

  @override
  String get auth_login => '登录';

  @override
  String get auth_logout => '退出登录';

  @override
  String get auth_email => '邮箱';

  @override
  String get auth_emailHint => '请输入 NovelAI 账户邮箱';

  @override
  String get auth_password => '密码';

  @override
  String get auth_passwordHint => '请输入密码';

  @override
  String get auth_loginButton => '登录';

  @override
  String get auth_loginFailed => '登录失败';

  @override
  String get auth_rememberPassword => '记住密码';

  @override
  String get auth_loginTip => '使用你的 NovelAI 账户登录\n所有数据仅存储在本地设备';

  @override
  String get auth_checkingStatus => '正在检查登录状态';

  @override
  String get auth_loggedIn => '已登录';

  @override
  String get auth_tokenConfigured => 'Token 已配置';

  @override
  String get auth_notLoggedIn => '未登录';

  @override
  String get auth_pleaseLogin => '请登录以使用全部功能';

  @override
  String get auth_logoutConfirmContent => '确定要退出登录吗？';

  @override
  String get auth_emailRequired => '请输入邮箱';

  @override
  String get auth_emailInvalid => '请输入有效的邮箱地址';

  @override
  String get auth_passwordRequired => '请输入密码';

  @override
  String get auth_tokenLogin => 'API Token 登录';

  @override
  String get auth_tokenLoginRecommended => 'API Token 登录（推荐）';

  @override
  String get auth_credentialsLogin => '邮箱密码登录';

  @override
  String get auth_credentialsLoginUnavailable => '账号密码登录当前不可用，请使用 Token 登录';

  @override
  String get auth_credentialsLoginTitle => '邮箱登录';

  @override
  String get auth_tokenHint => '请输入您的 Persistent API Token';

  @override
  String get auth_tokenRequired => '请输入 Token';

  @override
  String get auth_tokenInvalid => 'Token 格式无效，应以 pst- 开头';

  @override
  String get auth_nicknameOptional => '昵称（可选）';

  @override
  String get auth_nicknameHint => '为此账号设置一个便于识别的名称';

  @override
  String get auth_thirdPartyLogin => '第三方站点';

  @override
  String get auth_thirdPartyApiSite => '第三方 API 站点';

  @override
  String get auth_imageApiSiteOptional => '图像 API 站点（可选）';

  @override
  String get auth_imageApiSiteHint => '留空则使用同一个第三方 API 站点';

  @override
  String get auth_thirdPartyNicknameHint => '例如：自建站点 / 镜像站点';

  @override
  String get auth_thirdPartyTokenHint => '请输入第三方站点提供的 API Token';

  @override
  String get auth_thirdPartyCompatibilityHint =>
      '第三方站点需兼容 NovelAI 的 /user/subscription 与图像生成相关 API；Token 将按 Bearer 方式发送。';

  @override
  String get auth_thirdPartyApiSiteRequired => '请输入第三方 API 站点地址';

  @override
  String get auth_saveAccount => '保存此账号';

  @override
  String get auth_validateAndLogin => '验证并登录';

  @override
  String get auth_tokenGuide => '从 NovelAI 账户设置获取 Token';

  @override
  String get auth_savedAccounts => '已保存的账号';

  @override
  String get auth_addAccount => '添加账号';

  @override
  String get auth_manageAccounts => '管理';

  @override
  String auth_moreAccounts(Object count) {
    return '还有 $count 个账号';
  }

  @override
  String get auth_orAddNewAccount => '或添加新账号';

  @override
  String get auth_tokenNotFound => '未找到此账号的 Token';

  @override
  String get auth_switchAccount => '切换账号';

  @override
  String get auth_currentAccount => '当前账号';

  @override
  String get auth_selectAccount => '选择账号';

  @override
  String get auth_deleteAccount => '删除账号';

  @override
  String auth_deleteAccountConfirm(Object name) {
    return '确定要删除账号 \"$name\" 吗？此操作不可撤销。';
  }

  @override
  String get auth_cannotDeleteCurrent => '无法删除当前登录的账号';

  @override
  String get auth_removeAvatar => '移除头像';

  @override
  String get auth_selectFromGallery => '从相册选择';

  @override
  String get auth_takePhoto => '拍摄照片';

  @override
  String get auth_quickLogin => '一键登录';

  @override
  String get auth_nicknameRequired => '请输入昵称';

  @override
  String auth_createdAt(Object date) {
    return '创建于 $date';
  }

  @override
  String auth_error_loginFailed(Object error) {
    return '登录失败: $error';
  }

  @override
  String get auth_error_networkTimeout => '连接超时，请检查网络';

  @override
  String get auth_error_networkError => '网络连接错误';

  @override
  String get auth_error_authFailed => '认证失败';

  @override
  String get auth_error_authFailed_tokenExpired => 'Token 已过期，请重新登录';

  @override
  String get auth_error_credentialsLoginUnavailable => '账号密码登录当前不可用';

  @override
  String get auth_error_credentialsLoginUnavailable_hint =>
      'NovelAI 官网账号密码登录需要网页安全验证，客户端无法完成，请改用 Persistent API Token。';

  @override
  String get auth_error_serverError => '服务器错误';

  @override
  String get auth_error_unknown => '未知错误';

  @override
  String get auth_autoLogin => '自动登录';

  @override
  String get auth_forgotPassword => '忘记密码？';

  @override
  String get auth_passwordTooShort => '密码长度至少6位';

  @override
  String get auth_loggingIn => '登录中...';

  @override
  String get auth_pleaseWait => '请稍候';

  @override
  String get auth_viewTroubleshootingTips => '查看故障排除提示';

  @override
  String get auth_troubleshoot_checkConnection_title => '检查网络连接';

  @override
  String get auth_troubleshoot_checkConnection_desc => '确保您的设备已连接到互联网';

  @override
  String get auth_troubleshoot_retry_title => '重试';

  @override
  String get auth_troubleshoot_retry_desc => '网络问题可能是暂时的，请重试';

  @override
  String get auth_troubleshoot_proxy_title => '检查代理设置';

  @override
  String get auth_troubleshoot_proxy_desc => '如果使用代理，请确认配置正确';

  @override
  String get auth_troubleshoot_firewall_title => '检查防火墙设置';

  @override
  String get auth_troubleshoot_firewall_desc => '确保防火墙允许连接到 NovelAI 服务器';

  @override
  String get auth_troubleshoot_serverStatus_title => '检查服务器状态';

  @override
  String get auth_troubleshoot_serverStatus_desc =>
      '访问 NovelAI 状态页面或社区查看服务中断情况';

  @override
  String get auth_passwordResetHelp_title => '密码重置';

  @override
  String get auth_passwordResetHelp_desc =>
      '点击「忘记密码」将在浏览器中打开 NovelAI 密码重置页面，您可以在那里重置密码';

  @override
  String get auth_passwordResetAfterReset_title => '重置密码后';

  @override
  String get auth_passwordResetAfterReset_desc =>
      '在 NovelAI 网站上重置密码后，返回此应用并使用新密码登录';

  @override
  String get auth_passwordResetNoEmail_title => '未收到重置邮件？';

  @override
  String get auth_passwordResetNoEmail_desc =>
      '如果几分钟内未收到密码重置邮件，请检查垃圾邮件文件夹或联系 NovelAI 客服';

  @override
  String get common_paste => '粘贴';

  @override
  String get common_default => '默认';

  @override
  String get settings_title => '设置';

  @override
  String get settings_account => '账户';

  @override
  String get settings_appearance => '外观';

  @override
  String get settings_style => '风格';

  @override
  String get settings_font => '字体';

  @override
  String get settings_language => '语言';

  @override
  String get settings_languageChinese => '中文';

  @override
  String get settings_languageEnglish => 'English';

  @override
  String get settings_languageJapanese => '日本語';

  @override
  String get settings_shortcuts => '快捷键';

  @override
  String get settings_generation => '生成';

  @override
  String get settings_dataStorage => '数据与存储';

  @override
  String get settings_privacySharing => '安全与分享';

  @override
  String get settings_integrations => '集成';

  @override
  String get settings_generationInputSection => '输入';

  @override
  String get settings_generationRetrySection => '失败重试';

  @override
  String get settings_generationFeedbackSection => '完成提醒';

  @override
  String get settings_promptAssistant => '提示词助手';

  @override
  String get settings_selectStyle => '选择风格';

  @override
  String get settings_defaultPreset => '默认';

  @override
  String get settings_selectFont => '选择字体';

  @override
  String get settings_selectLanguage => '选择语言';

  @override
  String settings_loadFailed(Object error) {
    return '加载失败: $error';
  }

  @override
  String get settings_storage => '存储';

  @override
  String get settings_imageSavePath => '图片保存位置';

  @override
  String get settings_autoSave => '自动保存';

  @override
  String get settings_autoSaveSubtitle => '生成后自动保存图片';

  @override
  String get settings_about => '关于';

  @override
  String settings_version(Object version) {
    return '版本 $version';
  }

  @override
  String get settings_openSource => '开源项目';

  @override
  String get settings_openSourceSubtitle => '查看源代码和文档';

  @override
  String get settings_fileLogging => '记录应用日志';

  @override
  String get settings_fileLoggingSubtitle =>
      '默认关闭；仅在排查问题时开启。开启后会写入 Documents/NAI_Launcher/logs，关闭后不再创建或写入日志文件。';

  @override
  String get settings_pathReset => '已重置为默认路径';

  @override
  String get settings_pathSaved => '保存路径已更新';

  @override
  String get settings_selectFolder => '选择保存文件夹';

  @override
  String get settings_vibeLibraryPath => 'Vibe库路径';

  @override
  String get settings_hiveStoragePath => '数据存储路径';

  @override
  String get settings_selectVibeLibraryFolder => '选择Vibe库文件夹';

  @override
  String get settings_selectHiveFolder => '选择数据存储文件夹';

  @override
  String get settings_restartRequired => '需要重启';

  @override
  String get settings_restartRequiredContent => '应用需要重启才能应用新的存储路径。请手动重启应用。';

  @override
  String get settings_pathSavedRestartRequired => '路径已更新，重启后生效';

  @override
  String get settings_accountProfile => '账号资料';

  @override
  String get settings_accountType => '账号类型';

  @override
  String get settings_thirdPartyApiAccount => '第三方站点 API';

  @override
  String get settings_apiSite => 'API 站点';

  @override
  String get settings_notLoggedIn => '登录后可设置头像和昵称';

  @override
  String get settings_goToLogin => '去登录';

  @override
  String get settings_tapToChangeAvatar => '点击更换头像';

  @override
  String get settings_changeAvatar => '更换头像';

  @override
  String get settings_removeAvatar => '移除头像';

  @override
  String get settings_accountEmail => '账号邮箱';

  @override
  String get settings_emailAccount => '邮箱登录';

  @override
  String get settings_tokenAccount => 'Token登录';

  @override
  String get settings_setAsDefault => '设为默认';

  @override
  String get settings_defaultAccount => '默认';

  @override
  String get settings_editNickname => '编辑昵称';

  @override
  String get settings_nickname => '昵称';

  @override
  String get settings_nicknameHint => '输入2-32个字符';

  @override
  String get settings_nicknameEmpty => '请输入昵称';

  @override
  String settings_nicknameTooShort(int minLength) {
    return '昵称至少$minLength个字符';
  }

  @override
  String settings_nicknameTooLong(int maxLength) {
    return '昵称不能超过$maxLength个字符';
  }

  @override
  String get settings_nicknameAllWhitespace => '昵称不能全为空格';

  @override
  String get settings_nicknameUpdated => '昵称已更新';

  @override
  String get settings_avatarUpdated => '头像已更新';

  @override
  String get settings_avatarRemoved => '头像已移除';

  @override
  String get settings_avatarFileMissing => '头像文件已丢失，是否重新选择？';

  @override
  String get settings_setAsDefaultSuccess => '已设为默认账号';

  @override
  String get settings_startupPerformance => '启动性能';

  @override
  String get settings_startupPerformanceSubtitle => '配置启动性能设置';

  @override
  String get generation_title => '生成';

  @override
  String get generation_generate => '生成';

  @override
  String generation_cooldownRemaining(Object seconds) {
    return '等待 $seconds 秒';
  }

  @override
  String get generation_generating => '生成中...';

  @override
  String get generation_cancelGeneration => '取消生成';

  @override
  String get generation_skipCurrentBatch => '跳过当前批次';

  @override
  String get generation_stopAllGeneration => '停止全部';

  @override
  String get generation_pleaseInputPrompt => '请输入提示词';

  @override
  String get generation_emptyPromptHint => '输入提示词并点击生成';

  @override
  String get generation_imageWillShowHere => '图像将在这里显示';

  @override
  String get generation_generationFailed => '生成失败';

  @override
  String generation_progress(Object progress) {
    return '生成中... $progress%';
  }

  @override
  String get generation_params => '参数';

  @override
  String get generation_paramsSettings => '生成参数';

  @override
  String get generation_history => '历史';

  @override
  String get generation_historyRecord => '历史记录';

  @override
  String get generation_failedStreamSnapshot => '失败快照';

  @override
  String get generation_failedStreamSnapshotHint =>
      '生成未完成，仅保留最后一帧预览；不可保存、收藏或用于图生图';

  @override
  String get generation_noHistory => '暂无历史记录';

  @override
  String get generation_clearHistory => '清除历史记录';

  @override
  String get generation_clearHistoryConfirm => '确定要清除所有历史记录吗？此操作不可撤销。';

  @override
  String get generation_model => '模型';

  @override
  String get generation_imageSize => '图像尺寸';

  @override
  String get generation_sampler => '采样器';

  @override
  String generation_steps(Object steps) {
    return '步数: $steps';
  }

  @override
  String generation_cfgScale(Object scale) {
    return 'CFG 强度：$scale';
  }

  @override
  String get generation_seed => '种子';

  @override
  String get generation_seedRandom => '随机';

  @override
  String get generation_seedLock => '固定种子';

  @override
  String get generation_seedUnlock => '解锁种子';

  @override
  String get generation_advancedOptions => '高级选项';

  @override
  String get generation_smea => 'SMEA';

  @override
  String get generation_smeaSubtitle => '改善大图像的生成质量';

  @override
  String get generation_smeaDyn => 'SMEA DYN';

  @override
  String get generation_smeaDynSubtitle => 'SMEA 动态变体';

  @override
  String get generation_smeaDescription => '高分辨率采样器会在超过一定图像尺寸时自动使用';

  @override
  String generation_cfgRescale(Object value) {
    return 'CFG 重缩放：$value';
  }

  @override
  String get generation_noiseSchedule => '噪声调度';

  @override
  String get generation_resetParams => '重置参数';

  @override
  String generation_sizePortrait(Object width, Object height) {
    return '竖屏 ($width×$height)';
  }

  @override
  String generation_sizeLandscape(Object width, Object height) {
    return '横屏 ($width×$height)';
  }

  @override
  String generation_sizeSquare(Object width, Object height) {
    return '方形 ($width×$height)';
  }

  @override
  String generation_sizeSmallSquare(Object width, Object height) {
    return '小方形 ($width×$height)';
  }

  @override
  String generation_sizeLargeSquare(Object width, Object height) {
    return '大方形 ($width×$height)';
  }

  @override
  String generation_sizeTallPortrait(Object width, Object height) {
    return '竖长 ($width×$height)';
  }

  @override
  String generation_sizeWideLandscape(Object width, Object height) {
    return '横长 ($width×$height)';
  }

  @override
  String get prompt_positive => '正面';

  @override
  String get prompt_negative => '负面';

  @override
  String get prompt_positivePrompt => '正向提示词';

  @override
  String get prompt_negativePrompt => '负向提示词';

  @override
  String get prompt_mainPositive => '主提示词（正面）';

  @override
  String get prompt_mainNegative => '主提示词（负面）';

  @override
  String get prompt_characterPrompts => '多角色提示词';

  @override
  String prompt_characterPromptItem(Object name, Object content) {
    return '$name：$content';
  }

  @override
  String get prompt_finalPrompt => '最终生效提示词';

  @override
  String get prompt_finalNegative => '最终生效负面词';

  @override
  String prompt_importedCharacters(int count) {
    return '已导入 $count 个角色';
  }

  @override
  String get prompt_characterPromptReplaced => '已替换角色提示词';

  @override
  String prompt_characterPromptAppended(Object count) {
    return '已追加角色提示词 ($count 个角色)';
  }

  @override
  String prompt_smartDecomposedWithCharacters(Object count) {
    return '已分解：主提示词 + $count 个角色';
  }

  @override
  String get prompt_appliedToMainPrompt => '已应用到主提示词';

  @override
  String get prompt_editPrompt => '编辑提示词';

  @override
  String get prompt_inputPrompt => '输入提示词...';

  @override
  String get prompt_inputNegativePrompt => '输入负向提示词...';

  @override
  String get prompt_describeImage => '描述你想要生成的图像...';

  @override
  String get prompt_describeImageWithHint => '输入提示词描述画面，输入 < 引用词库，支持自动补全标签';

  @override
  String get prompt_searchHint => '搜索提示词';

  @override
  String prompt_searchMatchCount(Object current, Object total) {
    return '$current / $total';
  }

  @override
  String get prompt_searchPrevious => '上一个命中';

  @override
  String get prompt_searchNext => '下一个命中';

  @override
  String get prompt_searchClose => '关闭搜索';

  @override
  String get prompt_replaceHint => '替换为';

  @override
  String get prompt_replaceToggle => '显示/隐藏替换';

  @override
  String get prompt_replaceCurrent => '替换当前命中（Enter）';

  @override
  String get prompt_replaceAll => '全部替换（Ctrl+Enter）';

  @override
  String prompt_replaceAllDone(Object count) {
    return '已替换 $count 处';
  }

  @override
  String get promptAssistant_needPrompt => '请输入提示词后再操作';

  @override
  String promptAssistant_requestFailed(Object error) {
    return '助手请求失败: $error';
  }

  @override
  String get promptAssistant_enableAssistant => '启用提示词助手';

  @override
  String get promptAssistant_desktopOverlay => '桌面右下角浮层';

  @override
  String get kritaBridge_busyGenerating => 'Krita Bridge 正在生成，请等待当前任务结束';

  @override
  String get prompt_negativeFixedTagPrefix => '负向固定词前缀';

  @override
  String get prompt_negativeFixedTagSuffix => '负向固定词后缀';

  @override
  String get prompt_unwantedContent => '不想出现在图像中的内容...';

  @override
  String get prompt_addUnwantedHint => '添加不想出现的元素';

  @override
  String get prompt_randomPrompt => '随机提示词 (长按配置)';

  @override
  String prompt_clearConfirm(Object type) {
    return '确认清空$type';
  }

  @override
  String get prompt_promptSettings => '提示词设置';

  @override
  String get prompt_smartAutocomplete => '智能补全';

  @override
  String get prompt_smartAutocompleteSubtitle => '输入时显示标签建议';

  @override
  String get prompt_autoFormat => '自动格式化';

  @override
  String get prompt_autoFormatSubtitle => '中文逗号转英文、空格自动转下划线';

  @override
  String get prompt_highlightEmphasis => '高亮强调';

  @override
  String get prompt_highlightEmphasisSubtitle => '括号和权重语法高亮显示';

  @override
  String get prompt_sdSyntaxAutoConvert => 'SD语法自动转换';

  @override
  String get prompt_sdSyntaxAutoConvertSubtitle => '失焦时将SD权重语法转换为NAI格式';

  @override
  String get prompt_cooccurrenceRecommendation => '共现标签推荐';

  @override
  String get prompt_cooccurrenceRecommendationSubtitle => '输入标签后自动推荐相关标签';

  @override
  String get prompt_formatted => '已格式化';

  @override
  String get image_save => '保存';

  @override
  String get image_copy => '复制';

  @override
  String get image_upscale => '放大';

  @override
  String get image_saveToLibrary => '保存到词库';

  @override
  String image_imageSaved(Object path) {
    return '图片已保存到: $path';
  }

  @override
  String image_saveFailed(Object error) {
    return '保存失败: $error';
  }

  @override
  String get image_copiedToClipboard => '已复制到剪贴板';

  @override
  String image_copyFailed(Object error) {
    return '复制失败: $error';
  }

  @override
  String gallery_selected(Object count) {
    return '已选择 $count 项';
  }

  @override
  String get gallery_clearAll => '清除所有';

  @override
  String get gallery_clearGallery => '清除画廊';

  @override
  String get gallery_sortNewest => '最新优先';

  @override
  String get gallery_sortOldest => '最旧优先';

  @override
  String get gallery_sortFavorite => '收藏优先';

  @override
  String gallery_selectedCount(Object count) {
    return '已选择 $count 张';
  }

  @override
  String get config_presets => '预设';

  @override
  String get config_noPresets => '暂无预设';

  @override
  String get config_restoreDefaults => '恢复默认';

  @override
  String get config_newPreset => '新建预设';

  @override
  String get config_selectPreset => '选择一个预设';

  @override
  String get config_noConfigGroups => '还没有配置组';

  @override
  String get config_addConfigGroup => '添加配置组';

  @override
  String config_configGroupCount(Object count) {
    return '$count 个配置组';
  }

  @override
  String get config_setAsCurrent => '设为当前';

  @override
  String get config_duplicate => '复制';

  @override
  String get config_importConfig => '导入配置';

  @override
  String get config_selectConfigToEdit => '选择一个配置组进行编辑';

  @override
  String get config_editConfigGroup => '编辑配置组';

  @override
  String get config_configName => '配置名称';

  @override
  String get config_selectionMode => '选取方式';

  @override
  String get config_multipleProbability => '按概率';

  @override
  String get config_shuffleOrder => '打乱顺序';

  @override
  String get config_shuffleOrderSubtitle => '随机排列选中的内容';

  @override
  String get config_weightBrackets => '权重括号';

  @override
  String get config_weightBracketsHint => '每层花括号增加约 5% 权重';

  @override
  String get config_discard => '放弃';

  @override
  String get config_deletePreset => '删除预设';

  @override
  String config_deletePresetConfirm(Object name) {
    return '确定要删除 \"$name\" 吗？';
  }

  @override
  String get config_pasteJsonConfig => '粘贴 JSON 配置...';

  @override
  String get config_importSuccess => '导入成功';

  @override
  String get config_restoreDefaultsConfirm => '确定要恢复默认预设吗？所有自定义配置将被删除。';

  @override
  String get config_restored => '已恢复默认';

  @override
  String get config_setAsCurrentSuccess => '已设为当前预设';

  @override
  String get config_duplicatedPreset => '已复制预设';

  @override
  String get config_deletedSuccess => '已删除';

  @override
  String get config_saveSuccess => '保存成功';

  @override
  String get config_newPresetCreated => '已创建新预设';

  @override
  String config_subConfigCount(Object count) {
    return '$count 子配置';
  }

  @override
  String get config_sequential => '顺序';

  @override
  String get config_multiple => '多选';

  @override
  String get config_moreActions => '更多操作';

  @override
  String get img2img_title => '图生图';

  @override
  String get img2img_enabled => '已启用';

  @override
  String get img2img_sourceImage => '源图像';

  @override
  String get img2img_clickToSelectImage => '点击选择图片';

  @override
  String get img2img_strength => '变化强度';

  @override
  String get img2img_strengthHint => '值越高，生成的图像与原图差异越大';

  @override
  String get img2img_noise => '噪声量';

  @override
  String get img2img_noiseHint => '添加额外噪声以增加变化';

  @override
  String get img2img_clearSettings => '清除图生图设置';

  @override
  String get img2img_changeImage => '更换图片';

  @override
  String get img2img_removeImage => '移除图片';

  @override
  String img2img_selectFailed(Object error) {
    return '选择图片失败: $error';
  }

  @override
  String get img2img_editImage => '编辑图像';

  @override
  String get img2img_editApplied => '已将编辑结果设为新的源图';

  @override
  String get img2img_maskEnabled => '重绘遮罩';

  @override
  String get img2img_uploadImage => '上传图片';

  @override
  String get img2img_drawSketch => '绘制草图';

  @override
  String get img2img_maskTooltip => '重绘遮罩';

  @override
  String get img2img_maskHelpText => '上传遮罩图片来指定需要重绘的区域。白色区域会被重绘，黑色区域保持不变。';

  @override
  String get img2img_inpaint => '局部重绘';

  @override
  String get img2img_inpaintStrength => '重绘强度';

  @override
  String get img2img_inpaintStrengthHint => '值越高，蒙版区域与当前源图差异越大';

  @override
  String get img2img_inpaintPendingHint =>
      '点击“局部重绘”进入画布，用画笔、橡皮或选区工具标出需要重绘的区域。返回这里后，点击主生成按钮即可只重绘蒙版区域。';

  @override
  String get img2img_inpaintReadyHint => '遮罩已载入。当前会按局部重绘方式提交，只有蒙版区域会被重新生成。';

  @override
  String get img2img_inpaintMaskReady => '局部重绘遮罩已准备好';

  @override
  String get img2img_generateVariations => '生成变体';

  @override
  String get img2img_variationsReady => '已根据图片元数据准备好生成变体';

  @override
  String get img2img_variationsPreparedHint =>
      '变体参数已经准备好啦，直接点击主生成按钮就会以当前图片为基础继续生成新的变体。';

  @override
  String get img2img_variationsFallbackHint => '未找到可复用元数据，已保留当前提示词并切换到基础变体设置';

  @override
  String get img2img_directorTools => '导演工具';

  @override
  String get img2img_directorToolsHint =>
      '将当前源图送入导演工具处理。处理完成后，可以把结果回填为新的源图继续生成。';

  @override
  String get img2img_directorPrompt => '附加提示词';

  @override
  String get img2img_directorPromptHint => '需要时补充描述，例如目标情绪或上色方向';

  @override
  String img2img_directorRun(Object tool) {
    return '运行 $tool';
  }

  @override
  String get img2img_directorRunning => '正在处理...';

  @override
  String get img2img_directorResult => '处理结果';

  @override
  String img2img_directorResultReady(Object tool) {
    return '$tool 处理完成';
  }

  @override
  String get img2img_directorApplied => '已将导演工具结果设为新的源图';

  @override
  String get img2img_directorDefry => 'Defry';

  @override
  String get img2img_directorDefryHint => '降低结果中的噪声或过饱和程度（0 = 关闭，5 = 最强）';

  @override
  String get img2img_directorEmotionLevel => '表情强度';

  @override
  String get img2img_directorEmotionLevelHint => 'AI 改变表情的力度（0 = 轻微，5 = 强烈）';

  @override
  String get img2img_directorEmotionPresets => '快速预设';

  @override
  String get img2img_directorApplyAsSource => '设为源图';

  @override
  String get img2img_directorSourceImage => '源图';

  @override
  String get img2img_directorCompare => '对比';

  @override
  String get img2img_variationsStarted => '正在生成变体...';

  @override
  String get img2img_directorRemoveBackground => '背景移除';

  @override
  String get img2img_directorLineArt => '线稿提取';

  @override
  String get img2img_directorSketch => '草图化';

  @override
  String get img2img_directorColorize => '上色';

  @override
  String get img2img_directorEmotion => '表情修复';

  @override
  String get img2img_directorDeclutter => '杂线清理';

  @override
  String get img2img_enhance => '增强';

  @override
  String get img2img_enhanceHint => '增强会继续参考当前提示词，对源图进行潜空间放大与再生成。';

  @override
  String get img2img_enhanceMagnitude => '幅度';

  @override
  String get img2img_enhanceShowIndividualSettings => '显示单独设置';

  @override
  String get img2img_enhanceUpscaleAmount => '放大倍数';

  @override
  String get img2img_focusedInpaint => 'Focused Inpainting（聚焦重绘）';

  @override
  String get img2img_focusedInpaintEnabledHint =>
      '已启用。请在重绘编辑器左上角按钮里调整聚焦区域与 Minimum Context Area。';

  @override
  String get img2img_focusedInpaintDisabledHint =>
      '默认是普通重绘；如需聚焦重绘，请在重绘编辑器左上角按钮中开启并框选区域。';

  @override
  String get img2img_disabled => '未启用';

  @override
  String get img2img_novelAiCloudUpscale => 'NovelAI 云端超分 (固定 4x 放大)';

  @override
  String get img2img_comfyuiEnableHint => '请先在「设置 > ComfyUI」中启用并连接服务器。';

  @override
  String get img2img_upscaleMode => '放大方式';

  @override
  String get img2img_upscaleRegularModel => '普通模型';

  @override
  String get img2img_upscaleModel => '超分模型';

  @override
  String get img2img_noSeedvr2Models =>
      '未发现 SeedVR2 模型，请刷新模型列表或检查 SeedVR2 节点/模型文件。';

  @override
  String get img2img_noRegularUpscaleModels =>
      '未发现普通超分模型，请刷新模型列表或检查 models/upscale_models。';

  @override
  String get img2img_useSeedvr2TiledWorkflow =>
      '将使用 SeedVR2TilingUpscaler 分块超分流程。';

  @override
  String get img2img_useSeedvr2Workflow => '将使用 SeedVR2VideoUpscaler 流程。';

  @override
  String get img2img_useRegularUpscaleWorkflow =>
      '将使用 UpscaleModelLoader + ImageUpscaleWithModel 流程，并用 Lanczos 修正到目标倍率。';

  @override
  String get img2img_useRtxUpscaleWorkflow =>
      '将使用 RTX Video Super Resolution 流程，无需选择模型。';

  @override
  String get img2img_refreshModelList => '刷新模型列表';

  @override
  String get img2img_startUpscale => '开始超分';

  @override
  String get img2img_novelAiUpscaleComplete => 'NovelAI 超分完成';

  @override
  String img2img_upscaleComplete(Object width, Object height) {
    return '超分完成 (${width}x$height)';
  }

  @override
  String img2img_regularUpscaleComplete(Object width, Object height) {
    return '普通模型超分完成 (${width}x$height)';
  }

  @override
  String img2img_rtxUpscaleComplete(Object width, Object height) {
    return 'RTX 超分完成 (${width}x$height)';
  }

  @override
  String get img2img_noAvailableSeedvr2Model => '未选择可用的 SeedVR2 模型';

  @override
  String get img2img_noAvailableRegularUpscaleModel => '未选择可用的普通超分模型';

  @override
  String get img2img_decodeSourceFailed => '无法解码源图像';

  @override
  String get img2img_metricSpeed => '速度';

  @override
  String get img2img_metricVram => '显存';

  @override
  String get img2img_metricQuality => '效果';

  @override
  String get img2img_seedvr2VaeTileHint =>
      '同时写入 SeedVR2 VAE MODEL 的 encode/decode tile size。';

  @override
  String get img2img_seedvr2UseTiledUpscale => '使用分块放大';

  @override
  String get img2img_seedvr2UseTiledUpscaleHint =>
      '启用后改用 SeedVR2TilingUpscaler，适合大图或显存压力较高的场景。';

  @override
  String get img2img_seedvr2TileSize => '分块图块大小';

  @override
  String get img2img_seedvr2TileSizeHint =>
      '同时控制 SeedVR2TilingUpscaler 的 tile_width / tile_height。';

  @override
  String get img2img_seedvr2BlocksToSwap => '内存卸载层数';

  @override
  String get img2img_seedvr2BlocksToSwapHint =>
      '把多少 DiT 层放在内存里、推理时再逐层送入显存。调高更省显存但更吃内存也更慢；显存充裕可调低甚至设为 0。显存不足报错时请调高。';

  @override
  String img2img_regularModelDescription(Object name) {
    return '普通模型 · $name';
  }

  @override
  String get img2img_upscalePanelOpened => '已打开图生图超分面板';

  @override
  String get editor_title => '图像编辑';

  @override
  String get editor_done => '完成';

  @override
  String get editor_tolerance => '容差';

  @override
  String get editor_intensity => '强度';

  @override
  String get editor_sourcePoint => 'Alt+点击设置源点';

  @override
  String get editor_saveAndClose => '保存并关闭';

  @override
  String get editor_closeWithoutSaving => '不保存关闭';

  @override
  String get editor_modeImage => '涂鸦';

  @override
  String get editor_modeMask => '遮罩';

  @override
  String get editor_toolSettings => '工具设置';

  @override
  String get editor_brushPresets => '笔刷预设';

  @override
  String get editor_actions => '操作';

  @override
  String get editor_size => '大小';

  @override
  String get editor_opacity => '不透明度';

  @override
  String get editor_hardness => '硬度';

  @override
  String get editor_undo => '撤销';

  @override
  String get editor_redo => '重做';

  @override
  String get editor_clearLayer => '清除图层';

  @override
  String get editor_clearImageLayer => '清除涂鸦';

  @override
  String get editor_clearImageLayerMessage => '这将移除所有涂鸦笔画。';

  @override
  String get editor_clearSelection => '清除选区';

  @override
  String get editor_clearSelectionMessage => '这将移除当前的选区遮罩。';

  @override
  String get editor_resetView => '重置视图';

  @override
  String get editor_currentColor => '当前颜色';

  @override
  String get editor_zoom => '缩放';

  @override
  String get editor_paintTools => '绘画';

  @override
  String get editor_toolBrush => '画笔';

  @override
  String get editor_toolEraser => '橡皮擦';

  @override
  String get editor_toolFill => '填充';

  @override
  String get editor_toolMagicWand => '魔棒';

  @override
  String get editor_magicWandHelp => '点击颜色相近的连续区域。编辑图像时将其抠除为透明区域；重绘时将其加入蒙版。';

  @override
  String get editor_magicWandMode => '选择方式';

  @override
  String get editor_magicWandSmartObject => '智能对象（EfficientViT）';

  @override
  String get editor_magicWandColorArea => '颜色区域（洪水填充）';

  @override
  String get editor_magicWandSmartHelp =>
      '点击要选择的对象。首次使用会从 MIT Han Lab 下载约 133 MiB 的 EfficientViT-SAM L0 模型（Apache-2.0），之后保存在本地。';

  @override
  String get editor_magicWandColorHelp => '点击颜色相近的连续区域。适合边界清晰的纯色图像，无需下载模型。';

  @override
  String get editor_magicWandInvert => '反选结果';

  @override
  String get editor_toolLine => '直线';

  @override
  String get editor_toolRectSelect => '矩形选框';

  @override
  String get editor_toolEllipseSelect => '椭圆选框';

  @override
  String get editor_toolLassoSelect => '套索选区';

  @override
  String get editor_toolColorPicker => '吸管取色';

  @override
  String get editor_toolCloneStamp => '仿制图章';

  @override
  String get editor_toolBlur => '模糊';

  @override
  String get editor_presetInkPen => '墨水笔';

  @override
  String get editor_presetPixel => '像素';

  @override
  String get editor_unsavedChanges => '未保存的更改';

  @override
  String get editor_unsavedChangesMessage => '您有未保存的更改，确定要关闭吗？';

  @override
  String get editor_discard => '放弃';

  @override
  String get editor_clearConfirm => '清除图层？';

  @override
  String get editor_clearConfirmMessage => '这将删除当前图层的所有内容。';

  @override
  String get editor_shortcutUndo => '撤销 (Ctrl+Z)';

  @override
  String get editor_shortcutRedo => '重做 (Ctrl+Y)';

  @override
  String get editor_addToSelection => '添加到选区';

  @override
  String get editor_subtractFromSelection => '从选区减去';

  @override
  String get editor_selectionHint => '绘制选区作为重绘遮罩';

  @override
  String get editor_back => '返回';

  @override
  String get editor_layers => '图层';

  @override
  String get editor_loadMask => '加载蒙版';

  @override
  String get editor_togglePanels => '切换面板';

  @override
  String get editor_fillClosedRegion => '填充封闭区域';

  @override
  String get editor_resetMask => '重置蒙版';

  @override
  String get editor_zoomIn => '放大';

  @override
  String get editor_zoomOut => '缩小';

  @override
  String get editor_fitToWindow => '适应窗口';

  @override
  String get editor_tempColorPickerShortcut => 'Alt+点击: 临时取色';

  @override
  String get editor_shortcutHelpTitle => '快捷键帮助';

  @override
  String get editor_shortcutPaintTools => '绘画工具';

  @override
  String get editor_shortcutSelectionTools => '选区工具';

  @override
  String get editor_shortcutCanvasView => '画布视图';

  @override
  String get editor_shortcutBrushAdjust => '笔刷调整';

  @override
  String get editor_shortcutColors => '颜色';

  @override
  String get editor_shortcutCanvasActions => '画布操作';

  @override
  String get editor_shortcutHistoryActions => '历史操作';

  @override
  String get editor_shortcutSelectionActions => '选区操作';

  @override
  String get editor_shortcutTemporaryColorPicker => '临时拾色器';

  @override
  String get editor_shortcutRectSelection => '矩形选区';

  @override
  String get editor_shortcutEllipseSelection => '椭圆选区';

  @override
  String get editor_shortcutLassoSelection => '套索选区';

  @override
  String get editor_shortcut100Zoom => '100% 缩放';

  @override
  String get editor_shortcutFitHeight => '适应高度';

  @override
  String get editor_shortcutFitWidth => '适应宽度';

  @override
  String get editor_shortcutRotateLeft15 => '向左旋转 15°';

  @override
  String get editor_shortcutResetRotation => '重置旋转';

  @override
  String get editor_shortcutRotateRight15 => '向右旋转 15°';

  @override
  String get editor_shortcutFlipHorizontal => '水平镜像';

  @override
  String get editor_shortcutWheel => '滚轮';

  @override
  String get editor_shortcutBrushSmaller => '减小笔刷';

  @override
  String get editor_shortcutBrushLarger => '增大笔刷';

  @override
  String get editor_shortcutOpacityLower => '降低透明度';

  @override
  String get editor_shortcutOpacityHigher => '提高透明度';

  @override
  String get editor_shortcutDragBrushSize => '调整笔刷大小';

  @override
  String get editor_shortcutSwapColors => '交换前景/背景色';

  @override
  String get editor_shortcutPanCanvas => '平移画布';

  @override
  String get editor_shortcutClearSelectionContent => '清除选区内容';

  @override
  String get editor_shortcutCancelCurrentAction => '取消当前操作';

  @override
  String get editor_selectUnlockedLayerWithContent => '请选择一个非锁定且有内容的图层';

  @override
  String get editor_readCurrentLayerFailed => '无法读取当前图层';

  @override
  String get editor_localEffects => '本地后处理 / Effects';

  @override
  String get editor_basicAdjustments => '基础调整';

  @override
  String get editor_styleAndRepair => '风格与修复';

  @override
  String get editor_transformCrop => '旋转 / 翻转 / 裁剪';

  @override
  String get editor_transformCropDescription =>
      '几何操作已经独立出来，点击后会先生成预览，确认应用后才写回图层。';

  @override
  String get editor_effectPreviewHint => '预览不会修改原图；点击应用后才会把结果写入当前活动图层和撤销历史。';

  @override
  String get editor_applyToCurrentLayer => '应用到当前图层';

  @override
  String editor_oneShotEffectHint(Object effect) {
    return '$effect 是一次性操作，没有强度滑条。';
  }

  @override
  String editor_effectIntensity(Object effect) {
    return '$effect 强度';
  }

  @override
  String get editor_original => '原图';

  @override
  String get editor_effectPreview => '效果预览';

  @override
  String get editor_effectBrightness => '亮度';

  @override
  String get editor_effectContrast => '对比度';

  @override
  String get editor_effectSaturation => '饱和度';

  @override
  String get editor_effectTemperature => '色温';

  @override
  String get editor_effectGamma => '伽马';

  @override
  String get editor_effectGrayscale => '灰度';

  @override
  String get editor_effectInvert => '反相';

  @override
  String get editor_effectSepia => '复古棕褐';

  @override
  String get editor_effectDenoise => '降噪';

  @override
  String get editor_effectBlur => '高斯模糊';

  @override
  String get editor_effectSharpen => '锐化';

  @override
  String get editor_effectCropToSelection => '裁剪到选区';

  @override
  String get editor_effectRotateLeft => '向左旋转 90°';

  @override
  String get editor_effectRotateRight => '向右旋转 90°';

  @override
  String get editor_effectFlipHorizontal => '水平翻转';

  @override
  String get editor_effectFlipVertical => '垂直翻转';

  @override
  String editor_effectApplied(Object effect) {
    return '已应用 $effect';
  }

  @override
  String editor_applyEffectFailed(Object error) {
    return '应用效果失败: $error';
  }

  @override
  String get editor_changeCanvasSize => '更改画布尺寸';

  @override
  String editor_canvasTooSmall(Object width, Object height) {
    return '画布尺寸太小，最小尺寸为 $width x $height 像素';
  }

  @override
  String editor_canvasTooLarge(Object width, Object height) {
    return '画布尺寸太大，最大尺寸为 $width x $height 像素';
  }

  @override
  String editor_canvasResized(Object width, Object height) {
    return '画布已调整为 $width x $height';
  }

  @override
  String editor_canvasResizeFailed(Object error) {
    return '调整画布尺寸失败: $error';
  }

  @override
  String get editor_confirmExitTitle => '确认退出';

  @override
  String get editor_confirmExitContent => '有未保存的修改，确定要退出吗？';

  @override
  String get editor_exit => '退出';

  @override
  String get editor_saveAndExit => '保存并退出';

  @override
  String editor_exportFailed(Object error) {
    return '导出失败: $error';
  }

  @override
  String get editor_clickInsideClosedRegion => '请点击封闭区域内部进行填充。';

  @override
  String get editor_drawClosedMaskOutlineFirst => '请先绘制封闭的蒙版轮廓。';

  @override
  String get editor_noClosedRegionAtPosition => '该位置没有可填充的封闭区域。';

  @override
  String get editor_generateMaskOverlayFailed => '无法生成蒙版覆盖层';

  @override
  String get editor_maskLayerName => '蒙版';

  @override
  String get editor_updateMaskLayerFailed => '无法更新蒙版图层';

  @override
  String get editor_closedRegionFilled => '封闭区域已填充为蒙版。';

  @override
  String editor_fillMaskFailed(Object error) {
    return '填充蒙版失败: $error';
  }

  @override
  String get editor_magicWandNoSource => '没有可供魔棒取样的图像图层。';

  @override
  String get editor_magicWandNothingChanged => '选中的区域已经透明或已在蒙版中。';

  @override
  String get editor_magicWandModelPreparing => '正在检查 EfficientViT-SAM 模型…';

  @override
  String editor_magicWandModelDownloading(int percent) {
    return '正在下载 EfficientViT-SAM 模型：$percent%';
  }

  @override
  String get editor_magicWandModelLoading => '正在加载 EfficientViT-SAM 模型…';

  @override
  String get editor_magicWandEncoding => '正在分析图像对象…';

  @override
  String get editor_magicWandSegmenting => '正在根据点击位置分割对象…';

  @override
  String get editor_magicWandPostprocessing => '正在生成选区…';

  @override
  String editor_magicWandFailed(Object error) {
    return '魔棒处理失败: $error';
  }

  @override
  String get editor_focusInactiveHint => '点击按钮后进入聚焦模式，再框选区域并绘制蒙版。';

  @override
  String get editor_focusReadyHint => '已选定聚焦区域，可继续用画笔编辑蒙版。';

  @override
  String get editor_focusNeedsSelectionHint => '先框选聚焦区域，再切换画笔绘制蒙版。';

  @override
  String get editor_focusSelection => '选区';

  @override
  String get editor_focusBrush => '画笔';

  @override
  String get editor_focusContextHint =>
      '外框是实际送去 Focused Inpaint 的区域，内框是主要重绘区域；两框之间的带宽就是 Minimum Context Area。';

  @override
  String editor_focusAnlasWarning(int width, int height, int cost) {
    return '实际送出范围 $width×$height，按当前生成设置预计消耗 $cost Anlas。';
  }

  @override
  String get editor_compressionTitle => '输出分辨率';

  @override
  String get editor_compressionTooltip => '选择输出分辨率';

  @override
  String get editor_compressionUncompressed => '保持编辑工作尺寸，不执行压缩。';

  @override
  String get editor_compressionApplyOnDone =>
      '工作画布保持原样；点击“完成”时使用 Pica Lanczos3 执行一次压缩。';

  @override
  String editor_compressionSizeSummary(
    int workWidth,
    int workHeight,
    int targetWidth,
    int targetHeight,
  ) {
    return '工作尺寸 $workWidth×$workHeight → 输出尺寸 $targetWidth×$targetHeight';
  }

  @override
  String editor_compressionNormalSummary(
    int normalWidth,
    int normalHeight,
    int minimumWidth,
    int minimumHeight,
  ) {
    return 'Normal（约 1MP）为 $normalWidth×$normalHeight；最低档为 $minimumWidth×$minimumHeight。';
  }

  @override
  String get editor_compressionUnavailable => '当前工作画布已经低于最低压缩档，不能继续降低分辨率。';

  @override
  String get editor_compressionFocusLimited =>
      '当前 Focused Inpaint 选区在更高分辨率下会超过请求面积上限，因此滑条上限已收紧。';

  @override
  String editor_focusRequestSummary(
    int outerWidth,
    int outerHeight,
    int requestWidth,
    int requestHeight,
    int cost,
  ) {
    return '外层裁剪 $outerWidth×$outerHeight，实际发送 $requestWidth×$requestHeight，预计 $cost Anlas。';
  }

  @override
  String editor_unsupportedImageFormat(Object extension) {
    return '不支持的文件格式: .$extension\n请选择图像文件（PNG、JPG、WEBP 等）';
  }

  @override
  String editor_readFileFailed(Object error) {
    return '无法读取文件: $error';
  }

  @override
  String get editor_noFileData => '无法获取文件数据';

  @override
  String get editor_emptyImageFile => '文件为空，请选择有效的图像文件';

  @override
  String editor_fileTooLarge(Object sizeMB) {
    return '文件过大（$sizeMB MB），请选择小于 50MB 的图像';
  }

  @override
  String get editor_maskLayerAdded => '蒙版图层已添加';

  @override
  String get editor_parseImageFailed => '无法解析图像文件\n请确保文件未损坏且格式受支持';

  @override
  String editor_loadMaskFailed(Object error) {
    return '加载蒙版时发生错误: $error';
  }

  @override
  String get editor_defaultTitle => '画板';

  @override
  String get editor_baseLayerName => '底图';

  @override
  String get editor_existingMaskLayerName => '已有蒙版';

  @override
  String get editor_defaultDrawingLayerName => '图层 1';

  @override
  String editor_layerName(Object count) {
    return '图层 $count';
  }

  @override
  String editor_statusZoom(Object value) {
    return '缩放: $value%';
  }

  @override
  String editor_statusCanvas(Object width, Object height) {
    return '画布: $width x $height';
  }

  @override
  String editor_statusLayers(Object count) {
    return '图层: $count';
  }

  @override
  String get editor_statusHasSelection => '有选区';

  @override
  String editor_statusRotation(Object degrees) {
    return '旋转: $degrees°';
  }

  @override
  String get editor_statusMirrored => '镜像';

  @override
  String editor_focusMinimumContextArea(Object value) {
    return '最小上下文区域：$value';
  }

  @override
  String get editor_canvasSizeTitle => '画布尺寸';

  @override
  String get editor_presetSize => '预设尺寸';

  @override
  String get editor_customSize => '自定义';

  @override
  String get editor_contentHandling => '内容处理';

  @override
  String get editor_contentCrop => '裁剪';

  @override
  String get editor_contentPad => '填充';

  @override
  String get editor_contentStretch => '拉伸';

  @override
  String get editor_width => '宽度';

  @override
  String get editor_height => '高度';

  @override
  String get editor_lockAspectRatio => '锁定比例';

  @override
  String get editor_unlockAspectRatio => '取消锁定比例';

  @override
  String get editor_sizePreview => '尺寸预览';

  @override
  String get editor_originalSize => '原始';

  @override
  String get editor_newSize => '新尺寸';

  @override
  String get editor_cropModeDescription => '裁剪模式 - 保持比例裁剪';

  @override
  String get editor_padModeDescription => '填充模式 - 保持比例填充';

  @override
  String get editor_stretchModeDescription => '拉伸模式 - 拉伸至填满';

  @override
  String editor_canvasPresetSquare(Object size) {
    return '方形 $size';
  }

  @override
  String editor_canvasPresetLandscape(Object ratio) {
    return '横向 $ratio';
  }

  @override
  String editor_canvasPresetPortrait(Object ratio) {
    return '纵向 $ratio';
  }

  @override
  String get editor_canvasPresetNaiPortrait => 'NAI 纵向';

  @override
  String get editor_canvasPresetNaiLandscape => 'NAI 横向';

  @override
  String get editor_canvasPresetFullHd => '全高清 16:9';

  @override
  String get editor_colorPanelTitle => '颜色';

  @override
  String get editor_colorPickerTitle => '选择颜色';

  @override
  String get editor_brushSettings => '画笔设置';

  @override
  String get editor_eraserSettings => '橡皮擦设置';

  @override
  String get editor_colorPickerHint => '点击画布任意位置取色，松开后自动切回上一工具';

  @override
  String get editor_sample => '取样';

  @override
  String get editor_samplePoint => '单点';

  @override
  String get editor_sampleArea => '区域';

  @override
  String get editor_source => '来源';

  @override
  String get editor_sourceCurrentLayer => '当前图层';

  @override
  String get editor_sourceAllLayers => '所有图层';

  @override
  String get editor_lassoSelectionHelp => '按住鼠标拖动绘制自由形状选区，松开自动闭合';

  @override
  String get layer_empty => '无图层';

  @override
  String get layer_add => '添加图层';

  @override
  String get layer_mergeDown => '向下合并';

  @override
  String get layer_duplicate => '复制图层';

  @override
  String get layer_delete => '删除图层';

  @override
  String get layer_merge => '合并图层';

  @override
  String get layer_visibility => '显示/隐藏';

  @override
  String get layer_lock => '锁定';

  @override
  String get layer_rename => '重命名';

  @override
  String get layer_moveUp => '上移';

  @override
  String get layer_moveDown => '下移';

  @override
  String get vibe_title => '风格迁移';

  @override
  String get vibe_description => '改变图像，保留视觉风格';

  @override
  String get vibe_addFromFileTitle => '从文件添加';

  @override
  String get vibe_addFromFileSubtitle => 'PNG、JPG、Vibe 文件';

  @override
  String get vibe_addFromLibraryTitle => '从库导入';

  @override
  String get vibe_addFromLibrarySubtitle => '从 Vibe 库中选择';

  @override
  String get vibe_addReference => '添加参考图';

  @override
  String get vibe_clearAll => '清除全部';

  @override
  String vibe_cleared(int count) {
    return '已清除 $count 个 vibes';
  }

  @override
  String get vibe_referenceStrength => '参考强度';

  @override
  String get vibe_infoExtraction => '信息提取';

  @override
  String get vibe_remove => '移除';

  @override
  String get reference_enabled => '启用';

  @override
  String get reference_enable => '启用参考';

  @override
  String get reference_disable => '禁用参考';

  @override
  String get vibe_normalize => '标准化参考强度值';

  @override
  String get vibe_sourceType_png => 'PNG';

  @override
  String get vibe_sourceType_v4vibe => 'V4 Vibe';

  @override
  String get vibe_sourceType_bundle => '组合包';

  @override
  String get vibe_sourceType_image => '图片';

  @override
  String get vibe_sourceType => '数据源';

  @override
  String get vibe_reuseButton => '一键复用';

  @override
  String get vibe_reuseSuccess => 'Vibe 已添加到生成参数';

  @override
  String get vibe_info => 'Vibe 信息';

  @override
  String get vibe_name => '名称';

  @override
  String get vibe_strength => '强度';

  @override
  String get vibe_infoExtracted => '信息提取';

  @override
  String get vibe_shiftReplaceHint => 'Shift+点击 替换';

  @override
  String characterRef_referenceNumber(Object index) {
    return '参考图 #$index';
  }

  @override
  String get characterRef_description => '角色描述';

  @override
  String get characterRef_descriptionHint => '描述这个角色的特征（可选，但建议填写）...';

  @override
  String get unifiedRef_title => '图像参考';

  @override
  String get unifiedRef_switchTitle => '切换模式';

  @override
  String get unifiedRef_switchContent => '切换模式会清除当前已添加的参考图，确定要继续吗？';

  @override
  String get character_buttonLabel => '角色';

  @override
  String get character_title => '多角色 (V4 专属)';

  @override
  String get character_addCharacter => '添加角色';

  @override
  String get character_clearAll => '清除全部角色';

  @override
  String character_number(Object index) {
    return '角色 $index';
  }

  @override
  String get character_removeCharacter => '移除角色';

  @override
  String get character_description => '角色描述';

  @override
  String get character_descriptionHint => '描述这个角色的特征...';

  @override
  String get character_negativeOptional => '负向提示词 (可选)';

  @override
  String get character_negativeHint => '不想出现在这个角色上的特征...';

  @override
  String get character_positionOptional => '角色位置 (可选)';

  @override
  String get character_positionHint => '位置坐标 (0-1)，用于指定角色在画面中的大致位置';

  @override
  String get character_clearPosition => '清除位置';

  @override
  String get gallery_empty => '画廊为空';

  @override
  String get gallery_emptyHint => '生成的图像将显示在这里';

  @override
  String get gallery_searchHint => '搜索提示词... (支持中英文标签)';

  @override
  String gallery_exportSuccess(Object count, Object path) {
    return '已导出 $count 张图像到 $path';
  }

  @override
  String get gallery_saveFailed => '保存失败';

  @override
  String get gallery_deleteImage => '删除图像';

  @override
  String get gallery_deleteImageConfirm => '确定要删除这张图像吗？';

  @override
  String get gallery_generationParams => '生成参数';

  @override
  String get gallery_metaModel => '模型';

  @override
  String get gallery_metaResolution => '分辨率';

  @override
  String get gallery_metaSteps => '步数';

  @override
  String get gallery_metaSampler => '采样器';

  @override
  String get gallery_metaCfgScale => 'CFG 强度';

  @override
  String get gallery_metaSeed => '种子';

  @override
  String get gallery_metaSmea => 'SMEA';

  @override
  String get gallery_metaSmeaOn => '开启';

  @override
  String get gallery_metaSmeaOff => '关闭';

  @override
  String get gallery_metaGenerationTime => '生成时间';

  @override
  String get gallery_promptCopied => '已复制提示词';

  @override
  String get gallery_seedCopied => '已复制 Seed';

  @override
  String get gallery_useImageForGeneration => '使用此图片进行图像生成';

  @override
  String get gallery_addToReversePromptModule => '添加到画布反推模块';

  @override
  String get gallery_applyVibeFromImage => '提取并应用图片的风格/角色';

  @override
  String get gallery_noVibeData => '此图片不包含 Vibe 数据';

  @override
  String get gallery_sendToKrita => 'Krita';

  @override
  String get gallery_sendToKritaAction => '发送到 Krita';

  @override
  String get gallery_sendToConnectedKrita => '发送到已连接的 Krita 插件';

  @override
  String get gallery_upscalePanelLoaded => '已载入图生图超分面板';

  @override
  String gallery_readImageFailed(Object error) {
    return '读取图像失败: $error';
  }

  @override
  String get gallery_fileMissing => '文件不存在';

  @override
  String get gallery_copiedToClipboard => '已复制到剪贴板';

  @override
  String gallery_copyFailed(Object error) {
    return '复制失败: $error';
  }

  @override
  String get gallery_textToImage => '文生图';

  @override
  String get gallery_applyParams => '套用参数';

  @override
  String get gallery_unavailable => '不可用';

  @override
  String get gallery_loadSourceImage => '载入源图';

  @override
  String get gallery_upscale => '放大';

  @override
  String get gallery_superResolutionUpscale => '超分放大';

  @override
  String get gallery_sentToImg2Img => '图片已发送到图生图';

  @override
  String get gallery_sentToReversePrompt => '图片已发送到反推模块';

  @override
  String gallery_sendFailed(Object error) {
    return '发送失败: $error';
  }

  @override
  String get preset_noPresets => '暂无预设';

  @override
  String get preset_restoreDefault => '恢复默认';

  @override
  String get preset_setAsCurrent => '设为当前';

  @override
  String get preset_duplicate => '复制';

  @override
  String get preset_selectConfigToEdit => '选择一个配置组进行编辑';

  @override
  String get preset_editConfigGroup => '编辑配置组';

  @override
  String get preset_configName => '配置名称';

  @override
  String get preset_presetName => '预设名称';

  @override
  String get preset_selectionMode => '选取方式';

  @override
  String get preset_randomSingle => '随机单选';

  @override
  String get preset_sequentialSingle => '顺序单选';

  @override
  String get preset_specifiedCount => '指定数量';

  @override
  String get preset_byProbability => '按概率';

  @override
  String get preset_selectCount => '选取数量';

  @override
  String get preset_selectProbability => '选取概率';

  @override
  String get preset_shuffleOrder => '打乱顺序';

  @override
  String get preset_shuffleOrderHint => '随机排列选中的内容';

  @override
  String get preset_weightBrackets => '权重括号';

  @override
  String get preset_weightBracketsHint => '每层花括号增加约 5% 权重';

  @override
  String get preset_min => '最少';

  @override
  String get preset_max => '最多';

  @override
  String preset_preview(Object preview) {
    return '预览: $preview';
  }

  @override
  String get preset_tagContent => '标签内容';

  @override
  String preset_tagContentHint(Object count) {
    return '每行一个标签，当前 $count 项';
  }

  @override
  String get preset_format => '格式化';

  @override
  String get preset_sort => '排序';

  @override
  String get preset_inputHint =>
      '输入标签，每行一个...\n例如：\n1girl\nbeautiful eyes\nlong hair';

  @override
  String get preset_unsavedChanges => '未保存的更改';

  @override
  String get preset_unsavedChangesConfirm => '有未保存的更改，确定要放弃吗？';

  @override
  String get preset_discard => '放弃';

  @override
  String preset_deletePresetConfirm(Object name) {
    return '确定要删除 \"$name\" 吗？';
  }

  @override
  String get preset_importConfig => '导入配置';

  @override
  String get preset_pasteJson => '粘贴 JSON 配置...';

  @override
  String get preset_importSuccess => '导入成功';

  @override
  String get preset_restoreDefaultConfirm => '确定要恢复默认预设吗？所有自定义配置将被删除。';

  @override
  String get preset_restored => '已恢复默认';

  @override
  String get preset_setAsCurrentSuccess => '已设为当前预设';

  @override
  String get preset_duplicated => '已复制预设';

  @override
  String get preset_deleted => '已删除';

  @override
  String get preset_saveSuccess => '保存成功';

  @override
  String get preset_newPresetCreated => '已创建新预设';

  @override
  String get onlineGallery_search => '搜索';

  @override
  String get onlineGallery_popular => '热门';

  @override
  String get onlineGallery_favorites => '收藏';

  @override
  String get onlineGallery_searchTags => '搜索标签...';

  @override
  String get onlineGallery_refresh => '刷新';

  @override
  String get onlineGallery_login => '登录';

  @override
  String get onlineGallery_logout => '退出登录';

  @override
  String get onlineGallery_dayRank => '日榜';

  @override
  String get onlineGallery_weekRank => '周榜';

  @override
  String get onlineGallery_monthRank => '月榜';

  @override
  String get onlineGallery_today => '今天';

  @override
  String onlineGallery_imageCount(Object count) {
    return '$count 张';
  }

  @override
  String get onlineGallery_loadFailed => '加载失败';

  @override
  String get onlineGallery_favoritesEmpty => '收藏夹为空';

  @override
  String get onlineGallery_noResults => '没有找到图片';

  @override
  String get onlineGallery_pleaseLogin => '请先登录';

  @override
  String get onlineGallery_size => '尺寸';

  @override
  String get onlineGallery_score => '评分';

  @override
  String get onlineGallery_favCount => '收藏';

  @override
  String get onlineGallery_rating => '评级';

  @override
  String get onlineGallery_type => '类型';

  @override
  String get mediaType_video => '视频';

  @override
  String get mediaType_gif => '动图';

  @override
  String get onlineGallery_tags => '标签';

  @override
  String get onlineGallery_artists => '艺术家';

  @override
  String get onlineGallery_characters => '角色';

  @override
  String get onlineGallery_copyrights => '作品';

  @override
  String get onlineGallery_general => '通用';

  @override
  String get onlineGallery_copied => '已复制';

  @override
  String get onlineGallery_copyTags => '复制标签';

  @override
  String get onlineGallery_open => '打开';

  @override
  String get onlineGallery_send => '发送';

  @override
  String get onlineGallery_addToQueue => '加入队列';

  @override
  String get onlineGallery_sendToTextToImage => '发送到文生图';

  @override
  String get onlineGallery_sentToTextToImage => '已发送到文生图';

  @override
  String get onlineGallery_sendToReversePrompt => '发送到反推';

  @override
  String get onlineGallery_sentToReversePrompt => '已发送到反推模块';

  @override
  String onlineGallery_reversePromptSendFailed(Object error) {
    return '发送反推失败: $error';
  }

  @override
  String get onlineGallery_noTagInfo => '此图片没有标签信息';

  @override
  String get onlineGallery_promptSentToGeneration => '提示词已发送到生成页面';

  @override
  String get onlineGallery_noImageUrl => '此图片没有可用地址';

  @override
  String get onlineGallery_gifLoadFailed => 'GIF加载失败';

  @override
  String get onlineGallery_pinchToZoom => '双指缩放';

  @override
  String get onlineGallery_metadata => '元数据';

  @override
  String get onlineGallery_addedToQueue => '已加入队列';

  @override
  String get onlineGallery_queueFullMax => '队列已满（最多50项）';

  @override
  String get onlineGallery_chooseDownloadDirectory => '选择下载目录';

  @override
  String get onlineGallery_downloadStarted => '开始下载...';

  @override
  String onlineGallery_savedToPath(Object path) {
    return '已保存到: $path';
  }

  @override
  String onlineGallery_downloadFailed(Object error) {
    return '下载失败: $error';
  }

  @override
  String get onlineGallery_downloadOriginal => '下载原图';

  @override
  String get onlineGallery_all => '全部';

  @override
  String get onlineGallery_ratingGeneral => '全年龄';

  @override
  String get onlineGallery_ratingSensitive => '敏感';

  @override
  String get onlineGallery_ratingQuestionable => '可疑';

  @override
  String get onlineGallery_ratingExplicit => '限制级';

  @override
  String get onlineGallery_clear => '清除';

  @override
  String get onlineGallery_previousPage => '上一页';

  @override
  String get onlineGallery_nextPage => '下一页';

  @override
  String onlineGallery_pageN(Object page) {
    return '第 $page 页';
  }

  @override
  String get onlineGallery_dateRange => '日期范围';

  @override
  String get onlineGallery_fuzzySearch => '模糊匹配';

  @override
  String get onlineGallery_fuzzySearchTooltip =>
      '开启后使用 *tag* 匹配相近标签；关闭时按 Danbooru 精确标签搜索';

  @override
  String get onlineGallery_blacklistTags => '黑名单标签';

  @override
  String get onlineGallery_blacklistTitle => '在线画廊黑名单';

  @override
  String get onlineGallery_blacklistSubtitle => '包含黑名单标签的图片会在在线画廊中直接隐藏。';

  @override
  String get onlineGallery_addBlacklistTagHint => '添加黑名单标签';

  @override
  String get onlineGallery_noLocalBlacklistTags => '暂无本地黑名单标签';

  @override
  String get onlineGallery_autoSyncOnStartup => '启动时自动同步';

  @override
  String get onlineGallery_autoSyncOnStartupSubtitle => '默认开启，可随时关闭';

  @override
  String onlineGallery_lastSyncFailed(Object error) {
    return '上次同步失败: $error';
  }

  @override
  String get onlineGallery_neverSyncedBlacklist => '尚未同步过 Danbooru 黑名单';

  @override
  String onlineGallery_lastSync(Object time) {
    return '上次同步: $time';
  }

  @override
  String get onlineGallery_blacklistSettingsTitle => '在线画廊黑名单设置';

  @override
  String get onlineGallery_blacklistLoginHint =>
      '未登录 Danbooru，仍可使用本地黑名单；同步需要先登录。';

  @override
  String get onlineGallery_bulkFavorite => '批量收藏';

  @override
  String get onlineGallery_bulkDownload => '批量下载';

  @override
  String onlineGallery_addedTasksToQueue(Object count) {
    return '已添加 $count 个任务到队列';
  }

  @override
  String get onlineGallery_unfavorited => '已取消收藏';

  @override
  String get onlineGallery_favorited => '已收藏';

  @override
  String onlineGallery_favoritedImages(Object count) {
    return '已收藏 $count 张图片';
  }

  @override
  String onlineGallery_selectDownloadDirectoryFailed(Object error) {
    return '选择下载目录失败: $error';
  }

  @override
  String onlineGallery_downloadSelectedStarted(Object count) {
    return '开始下载 $count 张图片...';
  }

  @override
  String onlineGallery_downloadSelectedCompleted(
    Object success,
    Object failed,
  ) {
    return '下载完成: 成功 $success, 失败 $failed';
  }

  @override
  String get onlineGallery_startDate => '开始日期';

  @override
  String get onlineGallery_endDate => '结束日期';

  @override
  String get onlineGallery_invalidDateFormat => '日期格式无效';

  @override
  String get onlineGallery_dateOutOfRange => '日期超出范围';

  @override
  String get onlineGallery_last30Days => '最近30天';

  @override
  String get onlineGallery_configureGelbooruApi => '配置 Gelbooru API';

  @override
  String get onlineGallery_gelbooruApiReady => 'Gelbooru API 已验证';

  @override
  String get onlineGallery_gelbooruApiInvalid => 'Gelbooru 凭据已失效';

  @override
  String get onlineGallery_gelbooruCredentialsRequired =>
      '请先配置 Gelbooru User ID 和 API Key 以查看网站收藏。';

  @override
  String get onlineGallery_gelbooruCredentialsInvalid =>
      'Gelbooru 凭据已失效，请重新配置。';

  @override
  String get onlineGallery_gelbooruRateLimited => 'Gelbooru 请求过于频繁，请稍后再试。';

  @override
  String get onlineGallery_gelbooruTimeout => 'Gelbooru 请求超时，请检查网络连接。';

  @override
  String get onlineGallery_gelbooruServerError => 'Gelbooru 服务器暂时不可用，请稍后再试。';

  @override
  String get onlineGallery_gelbooruNetworkError =>
      '无法连接 Gelbooru，请检查网络设置或代理配置。';

  @override
  String get onlineGallery_gelbooruMalformedResponse => 'Gelbooru 返回了无法解析的数据。';

  @override
  String get onlineGallery_gelbooruRequestFailed => 'Gelbooru 请求失败，请稍后重试。';

  @override
  String get onlineGallery_gelbooruReadOnly => '只读收藏';

  @override
  String get onlineGallery_gelbooruFavoritesSortHint =>
      '按帖子 ID 从新到旧排列，不保证与网站收藏时间顺序一致。';

  @override
  String get tooltip_randomPrompt => '随机提示词 (长按配置)';

  @override
  String get tooltip_fullscreenEdit => '全屏编辑';

  @override
  String get tooltip_maximizePrompt => '最大化提示词区域';

  @override
  String get tooltip_restoreLayout => '恢复正常布局';

  @override
  String get tooltip_promptSettings => '提示词设置';

  @override
  String get tooltip_decreaseWeight => '减少权重 [-5%]';

  @override
  String get tooltip_increaseWeight => '增加权重 [+5%]';

  @override
  String get tooltip_edit => '编辑';

  @override
  String get tooltip_copy => '复制';

  @override
  String get tooltip_delete => '删除';

  @override
  String get tooltip_enable => '启用';

  @override
  String get tooltip_disable => '禁用';

  @override
  String get tooltip_resetWeight => '点击重置为100%';

  @override
  String get upscale_title => '图片放大';

  @override
  String get upscale_start => '开始放大';

  @override
  String get upscale_clickToSelect => '点击选择要放大的图片';

  @override
  String get upscale_scale => '放大倍数';

  @override
  String get upscale_2xHint => '将图像放大到原来的2倍 (推荐)';

  @override
  String get upscale_4xHint => '将图像放大到原来的4倍 (消耗更多 Anlas)';

  @override
  String get upscale_processing => '正在放大图片...';

  @override
  String get upscale_complete => '放大完成';

  @override
  String get upscale_share => '分享';

  @override
  String get upscale_failed => '放大失败';

  @override
  String upscale_shareFailed(Object error) {
    return '分享失败: $error';
  }

  @override
  String get danbooru_loginTitle => '登录 Danbooru';

  @override
  String get danbooru_loginHint => '使用用户名和 API Key 登录以使用收藏夹功能';

  @override
  String get danbooru_username => '用户名';

  @override
  String get danbooru_usernameHint => '输入 Danbooru 用户名';

  @override
  String get danbooru_usernameRequired => '请输入用户名';

  @override
  String get danbooru_apiKeyHint => '输入 API Key';

  @override
  String get danbooru_apiKeyRequired => '请输入 API Key';

  @override
  String get danbooru_howToGetApiKey => '如何获取 API Key?';

  @override
  String get danbooru_loginSuccess => '登录成功';

  @override
  String get gelbooru_configureTitle => '配置 Gelbooru API';

  @override
  String get gelbooru_configureHint =>
      '输入 Gelbooru 账户设置页提供的 User ID 和 API Key。应用不会收集密码或浏览器 Cookie。';

  @override
  String get gelbooru_userId => 'User ID';

  @override
  String get gelbooru_userIdHint => '输入正整数 User ID';

  @override
  String get gelbooru_userIdRequired => '请输入有效的正整数 User ID';

  @override
  String get gelbooru_apiKeyHint => '输入 API Key';

  @override
  String get gelbooru_apiKeyRequired => '请输入 API Key';

  @override
  String get gelbooru_openAccountSettings => '打开 Gelbooru 账户设置';

  @override
  String get gelbooru_save => '验证并保存';

  @override
  String get gelbooru_saved => 'Gelbooru 凭据已保存';

  @override
  String get gelbooru_removeCredentials => '移除凭据';

  @override
  String get gelbooru_invalidInput => '请输入有效的 User ID 和 API Key。';

  @override
  String get gelbooru_invalidCredentials =>
      'Gelbooru 拒绝了这些凭据，请检查 User ID 和 API Key。';

  @override
  String get gelbooru_rateLimited => '请求过于频繁，请稍后再试。';

  @override
  String get gelbooru_timeout => '验证超时，请检查网络连接。';

  @override
  String get gelbooru_serverError => 'Gelbooru 服务器暂时不可用。';

  @override
  String get gelbooru_networkError => '无法连接 Gelbooru，请检查网络设置或代理配置。';

  @override
  String get gelbooru_malformedResponse => 'Gelbooru 返回了无法解析的数据。';

  @override
  String get gelbooru_storageError => '无法安全保存或读取 Gelbooru 凭据。';

  @override
  String get gelbooru_unknownError => 'Gelbooru 验证失败，请稍后重试。';

  @override
  String get weight_title => '权重';

  @override
  String get weight_reset => '重置';

  @override
  String get weight_done => '完成';

  @override
  String get weight_noBrackets => '无括号';

  @override
  String get weight_editTag => '编辑标签';

  @override
  String get weight_tagName => '标签名称';

  @override
  String get weight_tagNameHint => '输入标签名称...';

  @override
  String tag_selected(Object count) {
    return '已选 $count';
  }

  @override
  String get tag_enable => '启用';

  @override
  String get tag_disable => '禁用';

  @override
  String get tag_delete => '删除';

  @override
  String get tag_addTag => '添加标签';

  @override
  String get tag_add => '添加';

  @override
  String get tag_inputHint => '输入标签...';

  @override
  String get tag_copiedToClipboard => '已复制到剪贴板';

  @override
  String get tag_emptyHint => '添加标签来描述你想要的画面';

  @override
  String get tag_emptyHintSub => '你可以浏览、搜索或手动添加标签';

  @override
  String get tagCategory_artist => '艺术家';

  @override
  String get tagCategory_copyright => '版权';

  @override
  String get tagCategory_character => '角色';

  @override
  String get tagCategory_meta => '元数据';

  @override
  String get tagCategory_general => '通用';

  @override
  String get qualityTags_label => '质量词';

  @override
  String get qualityTags_positive => '质量词（正面）';

  @override
  String get qualityTags_negative => '质量词（负面）';

  @override
  String get qualityTags_disabled => '质量标签已关闭\n点击开启';

  @override
  String get qualityTags_addToEnd => '添加到提示词末尾:';

  @override
  String get qualityTags_naiDefault => 'NAI 默认';

  @override
  String get qualityTags_none => '无';

  @override
  String get qualityTags_addFromLibrary => '从词库添加';

  @override
  String get qualityTags_selectFromLibrary => '选择质量词条目';

  @override
  String get ucPreset_label => '负面预设';

  @override
  String get ucPreset_heavy => '重度';

  @override
  String get ucPreset_light => '轻度';

  @override
  String get ucPreset_furryFocus => '兽人';

  @override
  String get ucPreset_humanFocus => '人物';

  @override
  String get ucPreset_none => '无';

  @override
  String get ucPreset_disabled => '负面提示词预设已关闭';

  @override
  String get ucPreset_addToNegative => '添加到负面提示词开头:';

  @override
  String get ucPreset_nsfwHint =>
      '💡 如需生成成人内容，请在正面提示词中添加 nsfw，负面提示词中的 nsfw 将自动移除';

  @override
  String get ucPreset_addFromLibrary => '从词库添加';

  @override
  String get ucPreset_selectFromLibrary => '选择负面词条目';

  @override
  String get randomMode_enabledTip => '抽卡模式已开启\n每次生成后自动随机新提示词';

  @override
  String get randomMode_disabledTip => '抽卡模式\n点击开启后每次生成自动随机提示词';

  @override
  String get batchSize_title => '批次大小';

  @override
  String batchSize_tooltip(int count) {
    return '每次请求生成 $count 张';
  }

  @override
  String get batchSize_description => '每次 API 请求生成的图片数量';

  @override
  String batchSize_formula(int batchCount, int batchSize, int total) {
    return '总图像数 = $batchCount × $batchSize = $total 张';
  }

  @override
  String get batchSize_hint => '较大的批次可减少请求次数，但单次等待时间更长';

  @override
  String get batchSize_costWarning => '⚠️ 批次大小 > 1 时会额外消耗 Anlas 点数';

  @override
  String get font_systemDefault => '系统默认';

  @override
  String get font_sourceHanSans => '思源黑体';

  @override
  String get font_sourceHanSerif => '思源宋体';

  @override
  String get font_sourceHanSansHK => '思源黑体港';

  @override
  String get font_sourceHanMono => '思源等宽';

  @override
  String get font_zcoolXiaowei => '站酷小薇';

  @override
  String get font_zcoolKuaile => '站酷快乐';

  @override
  String get font_mashan => '马善政楷书';

  @override
  String get font_longcang => '龙藏体';

  @override
  String get font_liujian => '刘建毛草';

  @override
  String get font_zhimang => '志漫行';

  @override
  String get font_codeFont => '代码字体';

  @override
  String get font_modernNarrow => '现代窄体';

  @override
  String get font_classicSerif => '古典衬线';

  @override
  String get font_sciFi => '科幻风';

  @override
  String get font_techStyle => '科技风';

  @override
  String get font_systemFonts => '系统字体';

  @override
  String get download_tagsData => '标签数据';

  @override
  String get download_cooccurrenceData => '共现标签数据';

  @override
  String download_complete(Object name) {
    return '$name下载完成';
  }

  @override
  String get warmup_networkCheck => '检测网络连接...';

  @override
  String get warmup_networkCheck_noProxy => '无法连接到 NovelAI，请开启VPN或启用代理设置';

  @override
  String get warmup_networkCheck_noSystemProxy => '已启用代理但未检测到系统代理，请开启VPN';

  @override
  String get warmup_networkCheck_manualIncomplete => '手动代理配置不完整，请检查设置';

  @override
  String get warmup_networkCheck_testing => '正在检测网络连接...';

  @override
  String get warmup_networkCheck_testingProxy => '正在通过代理检测网络...';

  @override
  String warmup_networkCheck_failed(Object error) {
    return '网络连接失败: $error，请检查VPN';
  }

  @override
  String warmup_networkCheck_success(Object latency) {
    return '网络连接正常 (${latency}ms)';
  }

  @override
  String get warmup_networkCheck_timeout => '网络检测超时，继续离线启动';

  @override
  String warmup_networkCheck_attempt(Object attempt, Object maxAttempts) {
    return '正在检测网络连接... (尝试 $attempt/$maxAttempts)';
  }

  @override
  String get warmup_preparing => '准备中...';

  @override
  String get warmup_complete => '完成';

  @override
  String get warmup_danbooruAuth => '初始化 Danbooru 认证...';

  @override
  String get warmup_loadingTranslation => '加载翻译数据...';

  @override
  String get warmup_initUnifiedDatabase => '初始化标签数据库...';

  @override
  String get warmup_initTagSystem => '初始化标签系统...';

  @override
  String get warmup_loadingPromptConfig => '加载提示词配置...';

  @override
  String get warmup_imageEditor => '初始化图像编辑器...';

  @override
  String get warmup_database => '加载最近历史记录...';

  @override
  String get warmup_network => '检查网络连接...';

  @override
  String get warmup_fonts => '预加载字体...';

  @override
  String get warmup_imageCache => '预热图像缓存...';

  @override
  String get warmup_statistics => '加载统计数据...';

  @override
  String get warmup_artistsSync => '同步画师数据...';

  @override
  String get warmup_subscription => '加载订阅信息...';

  @override
  String get warmup_dataSourceCache => '初始化数据源缓存...';

  @override
  String get warmup_galleryFileCount => '扫描图库文件...';

  @override
  String get warmup_cooccurrenceData => '加载标签共现数据...';

  @override
  String get warmup_retryFailed => '重试失败任务';

  @override
  String get warmup_group_basicUI => '初始化基础 UI 服务...';

  @override
  String get warmup_group_basicUI_complete => '基础 UI 服务就绪';

  @override
  String get warmup_group_dataServices => '初始化数据服务...';

  @override
  String get warmup_group_dataServices_complete => '数据服务就绪';

  @override
  String get warmup_group_networkServices => '初始化网络服务...';

  @override
  String get warmup_group_networkServices_complete => '网络服务就绪';

  @override
  String get warmup_group_cacheServices => '初始化缓存服务...';

  @override
  String get warmup_group_cacheServices_complete => '缓存服务就绪';

  @override
  String get warmup_cooccurrenceInit => '初始化共现数据...';

  @override
  String get warmup_translationInit => '初始化翻译数据...';

  @override
  String get warmup_danbooruTagsInit => '初始化 Danbooru 标签...';

  @override
  String get warmup_dataMigration => '迁移 Hive / Vibe / 图片数据...';

  @override
  String get warmup_galleryDataSource => '初始化画廊索引...';

  @override
  String get warmup_checkAndRecoverData => '检查数据完整性...';

  @override
  String get warmup_group_dataSourceInitialization => '初始化数据源服务...';

  @override
  String get warmup_group_dataSourceInitialization_complete => '数据源服务就绪';

  @override
  String warmup_fetchingTags(Object message) {
    return '正在同步标签：$message';
  }

  @override
  String get warmup_fetchingTagDataFromServer => '正在从服务器拉取标签数据...';

  @override
  String get warmup_fetchingGeneralTags => '正在拉取通用标签...';

  @override
  String get warmup_fetchingCharacterTags => '正在拉取角色标签...';

  @override
  String get warmup_fetchingCopyrightTags => '正在拉取版权标签...';

  @override
  String get warmup_fetchingMetaTags => '正在拉取元标签...';

  @override
  String get performanceReport_averageDuration => '平均耗时';

  @override
  String get performanceReport_noDataTitle => '暂无性能数据';

  @override
  String get performanceReport_noDataSubtitle => '完成预热后此页面将显示统计数据';

  @override
  String get performanceReport_overallStats => '总体统计';

  @override
  String get performanceReport_warmupCount => '预热次数';

  @override
  String get performanceReport_totalTasks => '总任务数';

  @override
  String get performanceReport_averageTotalDuration => '平均总耗时';

  @override
  String get copyName => ' (副本)';

  @override
  String get defaultPreset_name => '默认预设';

  @override
  String get defaultPreset_quality => '质量';

  @override
  String get defaultPreset_action => '动作';

  @override
  String get defaultPreset_shot => '镜头';

  @override
  String get defaultPreset_composition => '构图';

  @override
  String get defaultPreset_specialStyle => '特殊风格';

  @override
  String get resolution_groupNormal => '常规';

  @override
  String get resolution_groupLarge => '大尺寸';

  @override
  String get resolution_groupWallpaper => '壁纸';

  @override
  String get resolution_groupSmall => '小尺寸';

  @override
  String get resolution_groupCustom => '自定义';

  @override
  String get resolution_typePortrait => '竖屏';

  @override
  String get resolution_typeLandscape => '横屏';

  @override
  String get resolution_typeSquare => '方形';

  @override
  String get resolution_typeCustom => '自定义';

  @override
  String get resolution_width => '宽度';

  @override
  String get resolution_height => '高度';

  @override
  String get api_error_429 => '并发限制';

  @override
  String get api_error_429_hint => '请求过于频繁，请稍后重试（常见于合租账号）';

  @override
  String get api_error_401 => '认证失败';

  @override
  String get api_error_401_hint => 'Token 无效或已过期，请重新登录';

  @override
  String get api_error_402 => '余额不足';

  @override
  String get api_error_402_hint => 'Anlas 余额不足，请充值后重试';

  @override
  String get api_error_500 => '服务器错误';

  @override
  String get api_error_500_hint => 'NovelAI 服务器出现问题，请稍后重试';

  @override
  String get api_error_503 => '服务不可用';

  @override
  String get api_error_503_hint => '服务器正在维护或过载，请稍后重试';

  @override
  String get api_error_timeout => '请求超时';

  @override
  String get api_error_timeout_hint => '网络连接超时，请检查网络后重试';

  @override
  String get api_error_network => '网络错误';

  @override
  String get api_error_network_hint => '无法连接到服务器，请检查网络';

  @override
  String api_error_unknown_hint(Object error) {
    return '发生未知错误: $error';
  }

  @override
  String get drop_processing => '正在解析图片...';

  @override
  String get characterEditor_title => '多人角色提示词';

  @override
  String get characterEditor_close => '关闭';

  @override
  String get characterEditor_clearAll => '清空所有';

  @override
  String get characterEditor_clearAllTitle => '清空所有角色';

  @override
  String get characterEditor_clearAllConfirm => '确定要删除所有角色吗？此操作无法撤销。';

  @override
  String get characterEditor_tabList => '角色列表';

  @override
  String get characterEditor_tabDetail => '角色详情';

  @override
  String get characterEditor_globalAiChoice => '全局AI选择位置';

  @override
  String get characterEditor_globalAiChoiceHint => '启用后，所有角色的位置将由AI自动决定';

  @override
  String get characterEditor_emptyTitle => '请选择一个角色';

  @override
  String get characterEditor_emptyHint => '从左侧列表选择或添加新角色';

  @override
  String get characterEditor_noCharacters => '暂无角色';

  @override
  String get characterEditor_addCharacterHint => '点击上方按钮添加角色';

  @override
  String get characterEditor_nameHint => '输入角色名称';

  @override
  String get characterEditor_enabled => '启用';

  @override
  String get characterEditor_promptHint => '输入角色的正向提示词...';

  @override
  String get characterEditor_negativePromptHint => '输入角色的负面提示词...';

  @override
  String get characterCanvas_title => '角色位置';

  @override
  String get characterCanvas_aiChoice => 'AI 选择';

  @override
  String get characterCanvas_custom => '自定义';

  @override
  String get characterCanvas_aiHint => 'AI 将自动安排角色位置';

  @override
  String get characterCanvas_dragHint => '拖动锚点设置角色位置，松开即生效';

  @override
  String get characterEditor_genderFemale => '女性';

  @override
  String get characterEditor_genderMale => '男性';

  @override
  String get characterEditor_genderOther => '其他';

  @override
  String get characterEditor_genderFemaleHint => '女性（添加时选择）';

  @override
  String get characterEditor_genderMaleHint => '男性（添加时选择）';

  @override
  String get characterEditor_genderOtherHint => '其他（添加时选择）';

  @override
  String get characterEditor_addFemale => '女';

  @override
  String get characterEditor_addMale => '男';

  @override
  String get characterEditor_addOther => '其他';

  @override
  String get characterEditor_addFromLibrary => '词库';

  @override
  String get characterEditor_editCharacter => '编辑角色';

  @override
  String get characterEditor_moveUp => '上移';

  @override
  String get characterEditor_moveDown => '下移';

  @override
  String get characterEditor_aiChoice => 'AI选择';

  @override
  String get characterEditor_positionLabel => '位置:';

  @override
  String get characterEditor_positionHint => '在画面中选择角色的位置';

  @override
  String get characterEditor_promptLabel => '提示词:';

  @override
  String get characterEditor_disabled => '[禁用]';

  @override
  String characterEditor_characterCount(Object count) {
    return '$count 角色';
  }

  @override
  String characterEditor_characterCountWithEnabled(
    Object enabled,
    Object total,
  ) {
    return '$enabled/$total 角色';
  }

  @override
  String characterEditor_tooltipWithCount(Object count) {
    return '多人角色提示词 ($count 个角色)';
  }

  @override
  String get characterEditor_clickToEdit => '点击编辑多人角色提示词';

  @override
  String get toolbar_randomPrompt => '随机提示词';

  @override
  String get randomPromptToolsHiddenHint => '随机提示词工具已在设置中隐藏';

  @override
  String get toolbar_fullscreenEdit => '全屏编辑';

  @override
  String get toolbar_clear => '清空';

  @override
  String get toolbar_confirmClear => '确认清空';

  @override
  String get toolbar_settings => '设置';

  @override
  String get characterTooltip_noCharacters => '未配置角色';

  @override
  String get characterTooltip_clickToConfig => '点击按钮开始配置多人角色';

  @override
  String get characterTooltip_globalAiLabel => '全局 AI 位置:';

  @override
  String get characterTooltip_enabled => '启用';

  @override
  String get characterTooltip_disabled => '禁用';

  @override
  String get characterTooltip_positionAi => 'AI';

  @override
  String get characterTooltip_disabledLabel => '已禁用';

  @override
  String get characterTooltip_promptLabel => '正向';

  @override
  String get characterTooltip_negativeLabel => '负面';

  @override
  String get characterTooltip_notSet => '未设置';

  @override
  String characterTooltip_summary(Object total, Object enabled) {
    return '共 $total 个角色 ($enabled 个启用)';
  }

  @override
  String get characterTooltip_viewFullConfig => '点击查看完整配置';

  @override
  String get tagLibrary_title => '词库管理';

  @override
  String tagLibrary_tagCount(Object count) {
    return '已加载 $count 个标签';
  }

  @override
  String get tagLibrary_usingBuiltin => '使用内置词库';

  @override
  String get tagLibrary_neverSynced => '尚未同步';

  @override
  String get tagLibrary_syncNow => '从 Danbooru 同步';

  @override
  String get tagLibrary_networkError => '无法连接 Danbooru，请检查网络或代理设置';

  @override
  String get tagLibrary_autoSync => '自动同步';

  @override
  String get tagLibrary_autoSyncHint => '定期从 Danbooru 更新词库';

  @override
  String get tagLibrary_syncInterval => '同步间隔';

  @override
  String get tagLibrary_dataRange => '数据范围';

  @override
  String get tagLibrary_dataRangeHint => '数据量越大，同步时间越长，但标签更丰富';

  @override
  String get tagLibrary_dataRangePopular => '热门 (热度>1000)';

  @override
  String get tagLibrary_dataRangeMedium => '中等 (热度>500)';

  @override
  String get tagLibrary_dataRangeFull => '完整 (热度>100)';

  @override
  String tagLibrary_syncIntervalDays(Object days) {
    return '$days天';
  }

  @override
  String tagLibrary_generatedCharacters(Object count) {
    return '已生成 $count 个角色';
  }

  @override
  String tagLibrary_generateFailed(Object error) {
    return '生成失败: $error';
  }

  @override
  String get randomMode_title => '选择随机模式';

  @override
  String get randomMode_naiOfficial => '官网模式';

  @override
  String get randomMode_custom => '自定义模式';

  @override
  String get randomMode_hybrid => '混合模式';

  @override
  String get randomMode_naiOfficialDesc => '复刻 NovelAI 官方随机算法';

  @override
  String get randomMode_customDesc => '使用自定义预设生成';

  @override
  String get randomMode_hybridDesc => '结合官方算法和自定义预设';

  @override
  String get randomMode_naiIndicator => 'NAI';

  @override
  String get randomMode_customIndicator => '自定义';

  @override
  String naiMode_lastSync(Object time) {
    return '同步: $time';
  }

  @override
  String get naiMode_lastSyncLabel => '上次同步';

  @override
  String get timeAgo_justNow => '刚刚';

  @override
  String timeAgo_minutes(Object count) {
    return '$count分钟前';
  }

  @override
  String timeAgo_hours(Object count) {
    return '$count小时前';
  }

  @override
  String timeAgo_days(Object count) {
    return '$count天前';
  }

  @override
  String naiMode_dataRange(Object range) {
    return '范围: $range';
  }

  @override
  String promptConfig_confirmRemoveCategory(Object name) {
    return '确定要移除类别「$name」吗？移除后该类别将不再参与随机生成。';
  }

  @override
  String get promptConfig_categorySettings => '类别设置';

  @override
  String get naiMode_noTags => '暂无标签';

  @override
  String get naiMode_danbooruMasterToggleTooltip => '切换所有类别的扩展标签';

  @override
  String naiMode_entrySubtitle(Object count) {
    return '$count个标签 · 复刻官网算法';
  }

  @override
  String get naiAlgorithm_characterCount => '角色数量分布';

  @override
  String get naiAlgorithm_mainPrompt => '主提示词';

  @override
  String get tagLibrary_rangeMedium => '中等';

  @override
  String get tagLibrary_rangeFull => '完整';

  @override
  String get tagLibrary_danbooruSupplement => 'Danbooru 补充';

  @override
  String get tagLibrary_danbooruSupplementHint => '从 Danbooru 获取额外标签补充词库';

  @override
  String get tagLibrary_libraryComposition => '词库组成';

  @override
  String get tagLibrary_libraryCompositionDesc => 'NAI 官方固定词库 + 扩展标签（可选）';

  @override
  String get poolMapping_title => '图集映射';

  @override
  String get poolMapping_enableSync => '启用图集同步';

  @override
  String get poolMapping_enableSyncDesc => '从图集中提取标签补充到分类';

  @override
  String get poolMapping_noMappings => '暂无图集映射';

  @override
  String get poolMapping_noMappingsHint => '点击上方按钮添加图集';

  @override
  String get poolMapping_searchPool => '搜索图集';

  @override
  String get poolMapping_syncPools => '同步图集';

  @override
  String get poolMapping_syncSuccess => '图集同步成功';

  @override
  String get poolMapping_syncFailed => '图集同步失败';

  @override
  String get poolMapping_removeConfirm => '确定删除此图集映射？';

  @override
  String get poolMapping_removeSuccess => '图集映射已删除';

  @override
  String get poolMapping_resetConfirm => '确定要恢复默认图集映射吗？当前配置将被覆盖。';

  @override
  String get poolMapping_resetSuccess => '已恢复默认配置';

  @override
  String get tagGroup_title => '标签词库同步';

  @override
  String get tagGroup_enableSync => '启用标签词库同步';

  @override
  String get tagGroup_enableSyncDesc => '从 Danbooru 获取分类标签数据';

  @override
  String get tagGroup_mappingTitle => '标签词库映射';

  @override
  String get tagGroup_addMapping => '添加映射';

  @override
  String get tagGroup_noMappings => '暂无标签词库映射';

  @override
  String get tagGroup_noMappingsHint => '点击上方按钮浏览并添加标签词库';

  @override
  String get tagGroup_searchHint => '搜索标签词库...';

  @override
  String get tagGroup_selectGroup => '选择标签词库';

  @override
  String get tagGroup_groupExists => '该标签词库已添加';

  @override
  String get tagGroup_addSuccess => '标签词库映射添加成功';

  @override
  String get tagGroup_removeConfirm => '确定删除此标签词库映射？';

  @override
  String get tagGroup_removeSuccess => '标签词库映射已删除';

  @override
  String tagGroup_tagCount(Object count) {
    return '$count 标签';
  }

  @override
  String tagGroup_childCount(Object count) {
    return '$count 子分组';
  }

  @override
  String get tagGroup_resetConfirm => '确定要恢复默认标签词库映射吗？当前配置将被覆盖。';

  @override
  String get tagGroup_resetSuccess => '已恢复默认配置';

  @override
  String get tagGroup_minPostCount => '最小热度阈值';

  @override
  String get tagGroup_minPostCountHint => '只会同步帖子数量高于此阈值的标签';

  @override
  String tagGroup_previewCount(Object count) {
    return '预览 $count 标签';
  }

  @override
  String get tagGroup_selectToPreview => '选择一个标签词库查看预览';

  @override
  String get tagGroup_noTagsInGroup => '该分组暂无标签数据';

  @override
  String tagGroup_andMore(Object count) {
    return '还有 $count 个...';
  }

  @override
  String get tagGroup_options => '选项';

  @override
  String get tagGroup_includeChildren => '包含子分组标签';

  @override
  String get tagGroup_includesChildren => '含子分组';

  @override
  String get tagGroup_syncPreparing => '准备同步...';

  @override
  String tagGroup_syncFiltering(Object total, Object filtered) {
    return '筛选中: $total 标签, 保留 $filtered 标签';
  }

  @override
  String tagGroup_syncCompleted(Object count) {
    return '同步完成, 共 $count 标签';
  }

  @override
  String tagGroup_addTo(Object category) {
    return '添加到: $category';
  }

  @override
  String get tagGroup_refresh => '刷新列表';

  @override
  String get tagGroup_loadingFromDanbooru => '正在从 Danbooru 加载标签词库...';

  @override
  String get tagGroup_loadFailed => '无法加载标签词库，请检查网络连接';

  @override
  String get tagGroup_reload => '重新加载';

  @override
  String get tagGroup_searchHintAlt => '或使用搜索功能查找特定分组';

  @override
  String get tagGroup_selected => '已选择';

  @override
  String get tagGroup_manageGroups => '管理组';

  @override
  String get tagGroup_manageGroupsHint => '选择要同步的标签词库';

  @override
  String get naiMode_syncCategory => '补充此类别';

  @override
  String get naiMode_syncCategoryTooltip => '仅同步此类别的扩展标签';

  @override
  String get naiMode_viewDetails => '查看详情';

  @override
  String tagGroup_totalTagsTooltip(Object original, Object filtered) {
    return '原始: $original / 过滤后: $filtered';
  }

  @override
  String get tagGroup_cacheDetails => '缓存详情';

  @override
  String get tagGroup_cachedCategories => '已缓存分类';

  @override
  String get addGroup_syncFailed => '同步失败，请检查网络连接后重试';

  @override
  String get addGroup_addCustom => '添加自定义';

  @override
  String get tagGroup_noCachedData => '无缓存数据';

  @override
  String get tagGroup_syncRequired => '需要同步';

  @override
  String get tagGroup_notSynced => '未同步';

  @override
  String get tagGroup_lastSyncTime => '上次同步';

  @override
  String get tagGroup_heatThreshold => '热度阈值';

  @override
  String get tagGroup_totalStats => '总计';

  @override
  String tagGroup_syncedCount(Object synced, Object total) {
    return '$synced/$total 已同步';
  }

  @override
  String get addGroup_tagGroupTab => '标签词库';

  @override
  String get addGroup_builtinEnabled => '内置词库已启用';

  @override
  String get addGroup_builtinEnabledDesc => '该分类的内置词库已经在使用中';

  @override
  String get addGroup_enableBuiltin => '启用内置词库';

  @override
  String get addGroup_enableBuiltinDesc => '使用应用内置的标签词库';

  @override
  String get addGroup_backToParent => '返回上级';

  @override
  String get addGroup_browseMode => '已缓存列表';

  @override
  String get addGroup_customMode => '添加其他';

  @override
  String get addGroup_noMoreSubcategories => '没有更多子分类';

  @override
  String addGroup_tagGroupCount(Object count) {
    return '$count 个标签词库';
  }

  @override
  String get addGroup_customInputHint =>
      '输入 Danbooru 的 tag_group 标题，例如：hair_color';

  @override
  String get addGroup_groupTitleLabel => '标签词库标题 *';

  @override
  String get addGroup_groupTitleHint => '例如：hair_color 或 tag_group:hair_color';

  @override
  String get addGroup_displayNameLabel => '显示名称（可选）';

  @override
  String get addGroup_displayNameHint => '留空则使用标题';

  @override
  String get addGroup_targetCategoryLabel => '目标分类';

  @override
  String get addGroup_includeChildren => '包含子分组';

  @override
  String get addGroup_includeChildrenDesc => '同时获取该标签词库下所有子分组的标签';

  @override
  String get addGroup_errorEmptyTitle => '请输入标签词库标题';

  @override
  String get addGroup_errorGroupExists => '该标签词库已存在';

  @override
  String get addGroup_sourceTypeLabel => '数据来源';

  @override
  String get addGroup_poolTab => '图集';

  @override
  String get addGroup_poolSearchLabel => '搜索图集';

  @override
  String get addGroup_poolSearchHint => '输入图集名称进行搜索';

  @override
  String get addGroup_poolSearchEmpty => '输入关键词搜索图集';

  @override
  String get addGroup_poolSearchError => '搜索失败';

  @override
  String get addGroup_poolNoResults => '未找到匹配的图集';

  @override
  String addGroup_poolPostCount(Object count) {
    return '$count 个帖子';
  }

  @override
  String get addGroup_sectionTagGroups => '标签词库 ☁️';

  @override
  String get addGroup_sectionPools => '图集 🖼️';

  @override
  String get globalSettings_title => '总览设置';

  @override
  String get globalSettings_weightRandomOffset => '权重随机偏移';

  @override
  String get globalSettings_categoryProbabilityOverview => '类别概率总览';

  @override
  String globalSettings_saveFailed(Object error) {
    return '保存失败: $error';
  }

  @override
  String get globalSettings_noCharacter => '无人';

  @override
  String globalSettings_characterCount(Object count) {
    return '$count人';
  }

  @override
  String get globalSettings_enableWeightRandomOffset => '启用权重随机偏移';

  @override
  String get globalSettings_enableWeightRandomOffsetDesc => '生成时随机添加括号模拟人类微调';

  @override
  String get globalSettings_bracketType => '括号类型';

  @override
  String get globalSettings_bracketEnhance => '花括号 增强';

  @override
  String get globalSettings_bracketWeaken => '[] 减弱';

  @override
  String get globalSettings_layerRange => '层数范围';

  @override
  String globalSettings_layerRangeValue(Object min, Object max) {
    return '$min - $max 层';
  }

  @override
  String get globalSettings_category_hairColor => '发色';

  @override
  String get globalSettings_category_eyeColor => '瞳色';

  @override
  String get globalSettings_category_hairStyle => '发型';

  @override
  String get globalSettings_category_expression => '表情';

  @override
  String get globalSettings_category_pose => '姿势';

  @override
  String get globalSettings_category_clothing => '服装';

  @override
  String get globalSettings_category_accessory => '配饰';

  @override
  String get globalSettings_category_bodyFeature => '身体特征';

  @override
  String get globalSettings_category_background => '背景';

  @override
  String get globalSettings_category_scene => '场景';

  @override
  String get globalSettings_category_style => '风格';

  @override
  String get nav_generate => '生成';

  @override
  String get nav_gallery => '画廊';

  @override
  String get nav_settings => '设置';

  @override
  String download_downloading(Object name) {
    return '正在下载 $name';
  }

  @override
  String download_completed(Object name) {
    return '$name下载完成';
  }

  @override
  String download_failed(Object name) {
    return '$name下载失败';
  }

  @override
  String import_completed(Object name) {
    return '$name导入完成';
  }

  @override
  String get sync_preparing => '准备同步...';

  @override
  String sync_fetching(Object category) {
    return '正在获取 $category...';
  }

  @override
  String get sync_processing => '正在处理数据...';

  @override
  String get sync_saving => '正在保存...';

  @override
  String sync_completed(Object count) {
    return '同步完成，共 $count 个标签';
  }

  @override
  String sync_failed(Object error) {
    return '同步失败: $error';
  }

  @override
  String sync_extracting(Object poolName) {
    return '正在提取 $poolName 标签...';
  }

  @override
  String get sync_merging => '正在合并标签...';

  @override
  String sync_fetching_tags(Object groupName) {
    return '正在获取 $groupName 标签热度...';
  }

  @override
  String get sync_filtering => '正在筛选标签...';

  @override
  String get sync_done => '同步完成';

  @override
  String get download_tags_data => '正在下载标签数据...';

  @override
  String get download_cooccurrence_data => '正在下载共现标签数据...';

  @override
  String get download_parsing_data => '正在解析数据...';

  @override
  String get download_readingFile => '正在读取文件...';

  @override
  String get download_mergingData => '正在合并数据...';

  @override
  String get download_loadComplete => '加载完成';

  @override
  String get time_just_now => '刚刚';

  @override
  String time_minutes_ago(Object n) {
    return '$n分钟前';
  }

  @override
  String time_hours_ago(Object n) {
    return '$n小时前';
  }

  @override
  String time_days_ago(Object n) {
    return '$n天前';
  }

  @override
  String get time_never_synced => '从未同步';

  @override
  String categorySettings_bracketMin(Object count) {
    return '最少: $count 层';
  }

  @override
  String categorySettings_bracketMax(Object count) {
    return '最多: $count 层';
  }

  @override
  String get categorySettings_batchSettingsDesc => '对该类别下所有词组进行批量操作';

  @override
  String get categorySettings_enableAllGroups => '全部启用';

  @override
  String get categorySettings_disableAllGroups => '全部禁用';

  @override
  String get categorySettings_resetGroupSettings => '重置词组设置';

  @override
  String get categorySettings_batchEnableSuccess => '已启用所有词组';

  @override
  String get categorySettings_batchDisableSuccess => '已禁用所有词组';

  @override
  String get categorySettings_batchResetSuccess => '已重置所有词组设置';

  @override
  String tagGroupSettings_bracketMin(Object count) {
    return '最少: $count 层';
  }

  @override
  String tagGroupSettings_bracketMax(Object count) {
    return '最多: $count 层';
  }

  @override
  String get promptConfig_removeGroup => '移除分组';

  @override
  String get preset_resetToDefault => '重置为默认';

  @override
  String get preset_resetConfirmTitle => '重置预设';

  @override
  String get preset_resetConfirmMessage =>
      '确定要将当前预设的所有类别和词组设置重置为默认配置吗？此操作不可撤销。';

  @override
  String get preset_resetSuccess => '预设已重置为默认配置';

  @override
  String get newPresetDialog_title => '创建新预设';

  @override
  String get newPresetDialog_blank => '完全空白';

  @override
  String get newPresetDialog_blankDesc => '从头开始创建预设，不包含任何预设内容';

  @override
  String get newPresetDialog_template => '基于默认预设';

  @override
  String get newPresetDialog_templateDesc => '复制默认预设的所有设置作为起点';

  @override
  String get category_key => '类别标识';

  @override
  String get category_keyHint => '英文标识，用于内部';

  @override
  String get category_emoji => '图标';

  @override
  String get category_selectEmoji => '选择 Emoji';

  @override
  String get category_createSuccess => '类别创建成功';

  @override
  String get category_keyRequired => '请输入类别标识';

  @override
  String get category_keyExists => '该标识已存在';

  @override
  String get group_selectEmoji => '选择图标';

  @override
  String get category_noRecentEmoji => '暂无最近使用的 Emoji';

  @override
  String get category_searchEmoji => '搜索 Emoji';

  @override
  String get customGroup_entryPlaceholder => '输入词条并回车（支持多标签，逗号分隔）';

  @override
  String get customGroup_noEntries => '暂无词条，添加词条开始创建';

  @override
  String get customGroup_aliasLabel => '备注名称（可选）';

  @override
  String get customGroup_aliasHint => '输入便于记忆的备注名称';

  @override
  String get customGroup_contentHint => '输入实际的提示词内容';

  @override
  String get customGroup_selectEmoji => '选择图标';

  @override
  String get customGroup_addEntry => '添加词条';

  @override
  String get customGroup_emptyStateTitle => '开始添加词条';

  @override
  String get customGroup_emptyStateHint => '在上方输入框中输入词条，按回车快速添加';

  @override
  String get common_comingSoon => '功能开发中...';

  @override
  String get characterCountConfig_title => '人数类别配置';

  @override
  String get characterCountConfig_weight => '权重';

  @override
  String get characterCountConfig_solo => '单人';

  @override
  String get characterCountConfig_duo => '双人';

  @override
  String get characterCountConfig_trio => '三人';

  @override
  String get characterCountConfig_noHumans => '无人';

  @override
  String get characterCountConfig_multiPerson => '多人';

  @override
  String get characterCountConfig_customizable => '可自定义';

  @override
  String get characterCountConfig_mainPrompt => '主提示词';

  @override
  String get characterCountConfig_characterPrompt => '角色提示词';

  @override
  String get characterCountConfig_addTagOption => '添加角色标签';

  @override
  String get characterCountConfig_addMultiPersonCombo => '添加多人组合';

  @override
  String get characterCountConfig_displayName => '显示名称';

  @override
  String get characterCountConfig_displayNameHint => '例如：伪娘';

  @override
  String get characterCountConfig_mainPromptLabel => '主提示词标签';

  @override
  String get characterCountConfig_mainPromptHint =>
      '例如：solo, 2girls, 1girl 1boy';

  @override
  String get characterCountConfig_personCount => '人数：';

  @override
  String get characterCountConfig_slotConfig => '角色槽位配置';

  @override
  String get characterCountConfig_slot => '槽位';

  @override
  String get characterCountConfig_customSlots => '自定义槽位';

  @override
  String get characterCountConfig_customSlotsTitle => '角色槽位管理';

  @override
  String get characterCountConfig_customSlotsDesc => '添加或删除可用的角色槽位选项';

  @override
  String get characterCountConfig_addSlot => '添加槽位';

  @override
  String get characterCountConfig_addSlotHint => '例如：1trap, 1futanari';

  @override
  String get characterCountConfig_slotExists => '该槽位已存在';

  @override
  String get characterCountConfig_cannotDeleteBuiltin => '无法删除内置槽位';

  @override
  String get randomManager_algorithmConfig => '算法配置';

  @override
  String get randomManager_characterCountWeight => '角色数量权重';

  @override
  String get randomManager_genderWeight => '性别权重';

  @override
  String get randomManager_globalSettings => '全局设置';

  @override
  String get randomManager_enableSeasonalWordlists => '启用季节性词库';

  @override
  String get randomManager_enableSeasonalWordlistsDesc => '圣诞节、万圣节等特殊日期词库';

  @override
  String get randomManager_globalEmphasisProbability => '全局强调概率';

  @override
  String get randomManager_soloGenderOptions => '单人性别选项';

  @override
  String get randomManager_femaleShort => '女';

  @override
  String get randomManager_maleShort => '男';

  @override
  String get randomManager_other => '其他';

  @override
  String get randomManager_tagGroupList => '词组列表';

  @override
  String get randomManager_deleteTagGroupTitle => '删除词组';

  @override
  String randomManager_deleteTagGroupConfirm(Object name) {
    return '确定要删除词组「$name」吗？此操作不可撤销。';
  }

  @override
  String randomManager_tagGroupCount(Object count) {
    return '$count 个词组';
  }

  @override
  String get randomManager_categories => '类别';

  @override
  String get randomManager_tagGroups => '词组';

  @override
  String get randomManager_tags => '标签';

  @override
  String get randomManager_addTagGroup => '添加词组';

  @override
  String get randomManager_locked => '已锁定';

  @override
  String get randomManager_addCategory => '新增类别';

  @override
  String get randomManager_noCategories => '暂无类别';

  @override
  String get randomManager_noCategoriesHint => '点击“新增类别”开始配置';

  @override
  String get randomManager_globalPeopleSettings => '全局人数设置';

  @override
  String get randomManager_closePreview => '关闭预览';

  @override
  String get randomManager_importPreset => '导入预设';

  @override
  String get randomManager_importPresetSubtitle => '从 JSON 文本导入随机配置预设';

  @override
  String get randomManager_exportCurrentPreset => '导出当前预设';

  @override
  String get randomManager_noPresetSelected => '未选择预设';

  @override
  String get randomManager_selectPresetFirst => '请先选择预设';

  @override
  String get randomManager_defaultPresetReadonly => '默认预设为只读，请先新建或复制为自定义预设';

  @override
  String randomManager_presetImported(Object name) {
    return '已导入预设 \"$name\"';
  }

  @override
  String get randomManager_defaultPresetV4 => '默认模式 (V4)';

  @override
  String get randomManager_defaultPresetLegacy => '默认模式 (Legacy)';

  @override
  String get randomManager_defaultPresetFurry => '默认模式 (Furry)';

  @override
  String get randomManager_defaultPresetV4Description =>
      '基于 NAI V4 模型的随机算法配置，支持多角色';

  @override
  String get randomManager_defaultPresetLegacyDescription =>
      '基于 NAI Legacy 模型的随机算法配置';

  @override
  String get randomManager_defaultPresetFurryDescription =>
      '基于 NAI Furry 模型的随机算法配置';

  @override
  String get randomManager_defaultPresetOfficialDescription =>
      '基于 NAI 官网的随机算法配置';

  @override
  String get randomManager_femaleClothing => '女性服装';

  @override
  String get randomManager_maleClothing => '男性服装';

  @override
  String get randomManager_generalClothing => '通用服装';

  @override
  String get randomManager_femaleBodyType => '女性体型';

  @override
  String get randomManager_maleBodyType => '男性体型';

  @override
  String get randomManager_generalBodyType => '通用体型';

  @override
  String get randomManager_soloFemale => '女性';

  @override
  String get randomManager_soloMale => '男性';

  @override
  String get randomManager_duoGirls => '双女';

  @override
  String get randomManager_duoMixed => '一女一男';

  @override
  String get randomManager_duoBoys => '双男';

  @override
  String get randomManager_trioGirls => '三女';

  @override
  String get randomManager_trioTwoGirlsOneBoy => '二女一男';

  @override
  String get randomManager_trioOneGirlTwoBoys => '一女二男';

  @override
  String get randomManager_trioBoys => '三男';

  @override
  String get randomManager_noHumanScene => '无人场景';

  @override
  String randomManager_presetCreated(Object name) {
    return '已创建预设 \"$name\"';
  }

  @override
  String randomManager_deletePresetConfirm(Object name) {
    return '确定要删除 \"$name\" 吗？此操作不可撤销。';
  }

  @override
  String get randomManager_syncCompleted => 'Danbooru 标签同步完成';

  @override
  String randomManager_syncFailed(Object error) {
    return '同步失败: $error';
  }

  @override
  String get randomManager_resetDefaultTitle => '重置为默认配置';

  @override
  String get randomManager_resetDefaultContent =>
      '将恢复官方默认配置。\n您添加的自定义词组会被保留但禁用。';

  @override
  String get randomManager_resetDefaultConfirm => '确认重置';

  @override
  String get randomManager_resetDefaultDone => '已重置为默认配置';

  @override
  String get randomManager_generatePreview => '生成预览';

  @override
  String get randomManager_importExport => '导入/导出';

  @override
  String get randomManager_syncing => '同步中';

  @override
  String get randomManager_syncingWithEllipsis => '同步中...';

  @override
  String get randomManager_syncDanbooruTags => '同步 Danbooru 标签';

  @override
  String get randomManager_unknownError => '未知错误';

  @override
  String get randomManager_readOnlyMode => '只读模式';

  @override
  String get randomManager_readOnlyTooltip => '当前预设为默认预设，所有配置项已锁定';

  @override
  String get randomManager_searchCategoryOrTagGroup => '搜索类别或标签组...';

  @override
  String get randomManager_scope => '作用域';

  @override
  String get randomManager_global => '全局';

  @override
  String get randomManager_private => '私有';

  @override
  String get randomManager_status => '状态';

  @override
  String get randomManager_enabledOnly => '仅启用';

  @override
  String get randomManager_diyCapable => '有 DIY 能力';

  @override
  String randomManager_addTagGroupSubtitle(Object category) {
    return '添加到 \"$category\"';
  }

  @override
  String get randomManager_tagGroupName => '词组名称';

  @override
  String get randomManager_tagGroupNameHint => '输入词组名称';

  @override
  String get randomManager_tagGroupNameRequired => '请输入词组名称';

  @override
  String get randomManager_customTab => '自定义';

  @override
  String get randomManager_tagList => '标签列表';

  @override
  String get randomManager_tagListHelp => '每行一个标签，支持格式: tag 或 tag:weight';

  @override
  String get randomManager_searchTagGroup => '搜索 Tag Group...';

  @override
  String get randomManager_searchPool => '搜索 Pool...';

  @override
  String randomManager_itemCount(Object count) {
    return '$count 个';
  }

  @override
  String get randomManager_noMatchingTagGroup => '未找到匹配的 Tag Group';

  @override
  String get randomManager_noMatchingPool => '未找到匹配的 Pool';

  @override
  String get randomManager_cannotLoadPreview => '无法加载预览';

  @override
  String get randomManager_openInDanbooru => '在 Danbooru 中查看';

  @override
  String get randomManager_editTagGroup => '编辑词组';

  @override
  String get randomManager_basicTab => '基础';

  @override
  String randomManager_tagsTab(Object count) {
    return '标签 ($count)';
  }

  @override
  String get randomManager_diyAbilitiesTab => 'DIY 能力';

  @override
  String get randomManager_selectionSingle => '单选';

  @override
  String get randomManager_selectionSingleDesc => '加权随机选择一个';

  @override
  String get randomManager_selectionAll => '全选';

  @override
  String get randomManager_selectionAllDesc => '选择所有标签';

  @override
  String get randomManager_selectionMultipleCount => '多选数量';

  @override
  String get randomManager_selectionMultipleCountDesc => '选择指定数量';

  @override
  String get randomManager_selectionMultipleProbability => '多选概率';

  @override
  String get randomManager_selectionMultipleProbabilityDesc => '每个独立判断';

  @override
  String get randomManager_selectionSequential => '顺序轮替';

  @override
  String get randomManager_selectionSequentialDesc => '跨批次保持状态';

  @override
  String get randomManager_noTags => '暂无标签';

  @override
  String get randomManager_conditionalBranch => '条件分支';

  @override
  String get randomManager_conditionalBranchDesc => '根据变量值选择不同的标签子集';

  @override
  String get randomManager_dependencyConfig => '依赖配置';

  @override
  String get randomManager_dependencyConfigDesc => '选择数量依赖其他类别的值';

  @override
  String get randomManager_visibilityRules => '可见性规则';

  @override
  String get randomManager_visibilityRulesDesc => '根据构图决定是否生成';

  @override
  String get randomManager_timeCondition => '时间条件';

  @override
  String get randomManager_timeConditionDesc => '特定日期范围启用';

  @override
  String get randomManager_postProcessRules => '后处理规则';

  @override
  String get randomManager_postProcessRulesDesc => '根据已选标签移除冲突';

  @override
  String get randomManager_emphasisProbability => '强调概率';

  @override
  String get randomManager_probability => '概率';

  @override
  String get randomManager_selectionMode => '选择模式';

  @override
  String randomManager_editHint(Object name) {
    return '$name (点击编辑)';
  }

  @override
  String randomManager_emphasisProbabilityValue(Object percent) {
    return '强调概率: $percent%';
  }

  @override
  String get randomManager_previewGeneration => '预览生成';

  @override
  String get randomManager_generating => '生成中';

  @override
  String get randomManager_generate => '生成';

  @override
  String get randomManager_generationFailed => '生成失败';

  @override
  String get randomManager_copy => '复制';

  @override
  String get randomManager_regenerate => '重新生成';

  @override
  String get randomManager_copiedToClipboard => '已复制到剪贴板';

  @override
  String get randomManager_selectPresetRequired => '请选择一个预设';

  @override
  String randomManager_characterCountLabel(Object count) {
    return '$count人';
  }

  @override
  String randomManager_tagCountLabel(Object count) {
    return '$count标签';
  }

  @override
  String get randomManager_previewHint => '点击\"生成\"预览随机标签';

  @override
  String get randomManager_generateNow => '立即生成';

  @override
  String get randomManager_batchOperations => '批量操作';

  @override
  String randomManager_selectedItems(Object count) {
    return '已选择 $count 项';
  }

  @override
  String randomManager_totalItems(Object count) {
    return '共 $count 项';
  }

  @override
  String randomManager_enabledItems(Object count) {
    return '已启用 $count 个项目';
  }

  @override
  String randomManager_disabledItems(Object count) {
    return '已禁用 $count 个项目';
  }

  @override
  String get randomManager_batchDeleteTitle => '批量删除';

  @override
  String randomManager_batchDeleteContent(Object count) {
    return '确定要删除选中的 $count 个项目吗？此操作不可撤销。';
  }

  @override
  String randomManager_deletedItems(Object count) {
    return '已删除 $count 个项目';
  }

  @override
  String get randomManager_invertSelection => '反选';

  @override
  String get randomManager_moreActions => '更多操作';

  @override
  String get randomManager_enableSelected => '启用选中';

  @override
  String get randomManager_disableSelected => '禁用选中';

  @override
  String get randomManager_deleteSelected => '删除选中';

  @override
  String get randomManager_noHistory => '无历史记录';

  @override
  String get randomManager_operationHistory => '操作历史';

  @override
  String get randomManager_keyboardShortcuts => '键盘快捷键';

  @override
  String get randomManager_generalShortcuts => '通用';

  @override
  String get randomManager_presetActions => '预设操作';

  @override
  String get randomManager_selectionActions => '选择操作';

  @override
  String get randomManager_closeWindow => '关闭窗口';

  @override
  String get randomManager_refreshOrSync => '刷新/同步';

  @override
  String get gender_female => '女性';

  @override
  String get gender_male => '男性';

  @override
  String get gender_trap => '伪娘';

  @override
  String get gender_futanari => '扶她';

  @override
  String get scope_global => '主提示词';

  @override
  String get scope_globalTooltip => '提示词将出现在主提示词区域\n适合：背景、场景、画面风格等';

  @override
  String get scope_character => '角色';

  @override
  String get scope_characterTooltip =>
      '提示词将只出现在角色提示词内\n每个角色单独生成\n适合：发色、眵色、服装、表情等';

  @override
  String get scope_all => '通用';

  @override
  String get scope_allTooltip => '提示词同时出现在主提示词和角色提示词\n适合：姿势、互动等通用标签';

  @override
  String get vibeNoEncodingWarning => '此图片没有预编码数据';

  @override
  String vibeWillCostAnlas(int count) {
    return '编码将消耗 $count Anlas';
  }

  @override
  String get vibeEncodeConfirm => '是否继续添加并消耗点数？';

  @override
  String get vibeCancel => '取消';

  @override
  String get vibeConfirmEncode => '确认编码';

  @override
  String get vibeParseFailed => '无法解析 Vibe 文件';

  @override
  String get tagGroupBrowser_searchHint => '搜索标签...';

  @override
  String tagGroupBrowser_tagCount(Object count) {
    return '$count个标签';
  }

  @override
  String tagGroupBrowser_filteredTagCount(Object filtered, Object total) {
    return '显示 $filtered 个，共 $total 个标签';
  }

  @override
  String get tagGroupBrowser_noTags => '暂无标签';

  @override
  String get tagGroupBrowser_noLibrary => '词库未加载';

  @override
  String get tagGroupBrowser_importLibraryHint => '请先导入标签词库';

  @override
  String get tagGroupBrowser_noCategories => '没有启用的标签分类';

  @override
  String get tagGroupBrowser_enableCategoriesHint => '请在设置中启用标签分类';

  @override
  String get tagGroupBrowser_danbooruSuggestions => 'Danbooru 建议';

  @override
  String get tag_favoritesTitle => '收藏标签';

  @override
  String get tag_favoritesEmpty => '暂无收藏标签';

  @override
  String get tag_favoritesEmptyHint => '长按标签即可添加到收藏';

  @override
  String get tag_alreadyAdded => '该标签已在当前提示词中';

  @override
  String get tag_removeFavoriteTitle => '移除收藏';

  @override
  String tag_removeFavoriteMessage(Object tag) {
    return '确定要移除收藏的标签「$tag」吗？';
  }

  @override
  String get tag_templatesTitle => '标签模板';

  @override
  String get tag_templatesEmpty => '暂无标签模板';

  @override
  String get tag_templatesEmptyHint => '选择标签后点击右上角的 + 按钮创建模板';

  @override
  String get tag_templateCreate => '创建模板';

  @override
  String get tag_templateNameLabel => '模板名称';

  @override
  String get tag_templateNameHint => '输入模板名称';

  @override
  String get tag_templateNameRequired => '请输入模板名称';

  @override
  String get tag_templateDescLabel => '模板描述（可选）';

  @override
  String get tag_templateDescHint => '输入模板描述';

  @override
  String get tag_templatePreview => '标签预览';

  @override
  String tag_templateTagCount(Object count) {
    return '$count 个标签';
  }

  @override
  String tag_templateMoreTags(Object count) {
    return '还有 $count 个标签...';
  }

  @override
  String tag_templateInserted(Object name) {
    return '已插入模板「$name」';
  }

  @override
  String get tag_templateNoTags => '没有可保存的标签';

  @override
  String get tag_templateSaved => '模板已保存';

  @override
  String get tag_templateNameExists => '模板名称已存在';

  @override
  String get tag_templateDeleteTitle => '删除模板';

  @override
  String tag_templateDeleteMessage(Object name) {
    return '确定要删除模板「$name」吗？';
  }

  @override
  String get tag_tabGroups => '分组';

  @override
  String get tag_tabTemplates => '模板';

  @override
  String get tag_categoryGeneral => '通用';

  @override
  String get tag_categoryArtist => '画师';

  @override
  String get tag_categoryCopyright => '版权';

  @override
  String get tag_categoryCharacter => '角色';

  @override
  String get tag_categoryMeta => '元数据';

  @override
  String tag_countBadgeTooltip(Object total) {
    return '共 $total 个标签';
  }

  @override
  String get tag_countBadgeBreakdown => '标签分类统计';

  @override
  String tag_countEnabled(Object count) {
    return '$count 个已启用';
  }

  @override
  String get localGallery_searchIndexing => '正在构建搜索索引...';

  @override
  String get localGallery_searchIndexComplete => '搜索索引就绪';

  @override
  String get localGallery_searchIndexFailed => '搜索索引错误';

  @override
  String localGallery_cacheStatus(Object current, Object max) {
    return '缓存：$current/$max 张图片';
  }

  @override
  String localGallery_cacheHitRate(Object rate) {
    return '命中率：$rate%';
  }

  @override
  String get localGallery_preloading => '正在预加载图片...';

  @override
  String get localGallery_preloadComplete => '预加载完成';

  @override
  String get localGallery_progressiveLoadError => '图片加载失败';

  @override
  String get localGallery_noImagesFound => '未找到图片';

  @override
  String get localGallery_unknownError => '未知错误';

  @override
  String localGallery_loadFailed(Object error) {
    return '加载失败: $error';
  }

  @override
  String get localGallery_indexingLocalImages => '索引本地图片中...';

  @override
  String get localGallery_emptyTitle => '暂无本地图片';

  @override
  String get localGallery_emptySubtitle => '生成的图片将保存在此处';

  @override
  String get localGallery_noMatchingResults => '无匹配结果';

  @override
  String get localGallery_loadingGroupedImages => '加载分组图片中...';

  @override
  String localGallery_jumpedToMonth(Object year, Object month) {
    return '已跳转到 $year-$month';
  }

  @override
  String get localGallery_searchPlaceholder => '搜索提示词、模型、采样器...';

  @override
  String get localGallery_title => '本地画廊';

  @override
  String get localGallery_allImages => '全部图片';

  @override
  String get localGallery_categoryPanelTitle => '分类';

  @override
  String get localGallery_searchFilenamePromptPlaceholder =>
      '搜索文件名/Prompt，逗号分隔交集搜索...';

  @override
  String get localGallery_selectCurrentPage => '选择本页';

  @override
  String get localGallery_deselectCurrentPage => '取消本页';

  @override
  String get localGallery_selectAllResults => '选择全部';

  @override
  String get localGallery_deselectAllResults => '取消全部';

  @override
  String get localGallery_moveSelected => '移动';

  @override
  String get localGallery_packSelected => '打包';

  @override
  String get localGallery_editMetadata => '编辑';

  @override
  String get localGallery_addToCollection => '收藏';

  @override
  String get localGallery_switchToGridView => '切换到网格视图';

  @override
  String get localGallery_switchToDateGroupedView => '切换到日期分组视图';

  @override
  String get localGallery_openFilterPanel => '打开筛选面板';

  @override
  String get localGallery_hideCategoryPanel => '隐藏分类面板';

  @override
  String get localGallery_showCategoryPanel => '显示分类面板';

  @override
  String get localGallery_enterSelectionMode => '进入选择模式';

  @override
  String get localGallery_refreshTooltip => '刷新画廊\n\n自动检测新增/修改的图片并更新索引';

  @override
  String get localGallery_tagIntersection => '标签交集';

  @override
  String get localGallery_createCategoryTitle => '新建分类';

  @override
  String get localGallery_createCategoryHint => '请输入分类名称';

  @override
  String get localGallery_createCategoryConfirm => '创建';

  @override
  String get localGallery_createSubCategoryTitle => '新建子分类';

  @override
  String get localGallery_showInFolder => '在文件夹中显示';

  @override
  String get localGallery_promptCopied => 'Prompt 已复制';

  @override
  String get localGallery_seedCopied => 'Seed 已复制';

  @override
  String localGallery_confirmDeleteImageContent(Object name) {
    return '确定要删除图片「$name」吗？\n\n此操作无法撤销。';
  }

  @override
  String get localGallery_imageDeleted => '图片已删除';

  @override
  String localGallery_deleteFailed(Object error) {
    return '删除失败: $error';
  }

  @override
  String get localGallery_categoryDeleteContent => '确定要删除此分类吗？文件夹及其内容将被保留。';

  @override
  String get localGallery_protectedDeleteCategoryTitle => '保护模式：确认删除分类';

  @override
  String get localGallery_protectedDeleteCategoryContent =>
      '将删除此分类记录，文件夹及内容会保留。请再次确认。';

  @override
  String get localGallery_confirmDelete => '确认删除';

  @override
  String get localGallery_confirmMoveImageTitle => '保护模式：确认移动图片';

  @override
  String get localGallery_confirmMoveImageContent => '将把图片移动到目标分类文件夹。请确认不是误拖拽。';

  @override
  String get localGallery_confirmMove => '确认移动';

  @override
  String get localGallery_imageMovedToCategory => '图片已移动到分类';

  @override
  String get localGallery_categoriesSynced => '分类已与文件夹同步';

  @override
  String get localGallery_saveDirectoryNotSet => '未设置保存目录';

  @override
  String get localGallery_folderNotFound => '文件夹不存在';

  @override
  String localGallery_openFolderFailed(Object error) {
    return '打开文件夹失败: $error';
  }

  @override
  String get localGallery_protectedDeleteTitle => '保护模式：再次确认删除';

  @override
  String localGallery_protectedDeleteImagesContent(Object count) {
    return '将永久删除 $count 张本地图片文件。此操作无法撤销。';
  }

  @override
  String get localGallery_protectedBulkMoveTitle => '保护模式：确认批量移动';

  @override
  String localGallery_protectedBulkMoveContent(Object count) {
    return '将移动 $count 张本地图片文件到目标文件夹。请确认不是误操作。';
  }

  @override
  String localGallery_importParamsFailed(Object error) {
    return '导入参数失败: $error';
  }

  @override
  String localGallery_protectedDeleteImageContent(Object name) {
    return '将永久删除图片「$name」。此操作无法撤销。';
  }

  @override
  String get localGallery_saveZipArchive => '保存压缩包';

  @override
  String localGallery_packingImages(Object count) {
    return '正在打包 $count 张图片...';
  }

  @override
  String localGallery_packedImages(Object count) {
    return '已打包 $count 张图片';
  }

  @override
  String get localGallery_packFailed => '打包失败';

  @override
  String get localGallery_imageFileMissing => '图片文件不存在';

  @override
  String get localGallery_sentToImageToImage => '图片已发送到图生图';

  @override
  String localGallery_sendFailed(Object error) {
    return '发送失败: $error';
  }

  @override
  String get localGallery_noVibeData => '此图片不包含 Vibe 数据';

  @override
  String localGallery_vibeAddedToParams(Object name) {
    return 'Vibe \"$name\" 已添加到生成参数';
  }

  @override
  String localGallery_addVibeFailed(Object error) {
    return '添加 Vibe 失败: $error';
  }

  @override
  String get localGallery_sentToReversePrompt => '图片已发送到反推模块';

  @override
  String localGallery_sendToKritaFailed(Object error) {
    return '发送到 Krita 失败: $error';
  }

  @override
  String get localGallery_sendTo => '发送到...';

  @override
  String get localGallery_sendToImg2Img => '发送到图生图';

  @override
  String get localGallery_sendToReversePrompt => '发送到反推';

  @override
  String get localGallery_sendToStyleTransfer => '发送到风格迁移';

  @override
  String get localGallery_sendToPreciseReference => '发送到精准参考';

  @override
  String get localGallery_sendToKrita => '发送到 Krita';

  @override
  String get localGallery_importImageMetadata => '导入图片元数据';

  @override
  String get localGallery_copyPrompt => '复制 Prompt';

  @override
  String get localGallery_copySeed => '复制 Seed';

  @override
  String get localGallery_dragToShare => '拖拽以分享';

  @override
  String get localGallery_moveToRoot => '移至根目录';

  @override
  String get localGallery_folderName => '文件夹名称';

  @override
  String get localGallery_newFolderName => '新名称';

  @override
  String get localGallery_folderNameHint => '输入文件夹名称';

  @override
  String get localGallery_folderCreated => '文件夹创建成功';

  @override
  String get localGallery_folderCreateFailed => '文件夹创建失败';

  @override
  String get localGallery_renameFolderTitle => '重命名文件夹';

  @override
  String get localGallery_renameSuccess => '重命名成功';

  @override
  String get localGallery_renameFailed => '重命名失败';

  @override
  String get localGallery_deleteFolderTitle => '删除文件夹';

  @override
  String localGallery_deleteFolderWithImagesContent(Object name, Object count) {
    return '文件夹「$name」包含 $count 张图片，确定要删除吗？\n\n注意：此操作会删除文件夹及其中的所有图片，无法恢复。';
  }

  @override
  String localGallery_deleteEmptyFolderContent(Object name) {
    return '确定要删除空文件夹「$name」吗？';
  }

  @override
  String get localGallery_folderDeleted => '文件夹已删除';

  @override
  String get localGallery_folderDeleteFailed => '删除文件夹失败';

  @override
  String get localGallery_cachingMetadata => '正在缓存元数据...';

  @override
  String get localGallery_metadataCacheStats => '元数据缓存统计';

  @override
  String get localGallery_totalImages => '总图片';

  @override
  String get localGallery_withMetadata => '有元数据';

  @override
  String get localGallery_skipped => '跳过';

  @override
  String get localGallery_remaining => '剩余';

  @override
  String get localGallery_cacheMonitor => '缓存监控';

  @override
  String get localGallery_threeLayerCacheStats => '三层缓存统计';

  @override
  String localGallery_updatedAt(Object time) {
    return '更新: $time';
  }

  @override
  String get localGallery_memoryCache => '内存缓存';

  @override
  String get localGallery_hiveCache => 'Hive 缓存';

  @override
  String get localGallery_sqliteDatabase => 'SQLite 数据库';

  @override
  String get localGallery_imageUnit => '图片';

  @override
  String get localGallery_metadataUnit => '元数据';

  @override
  String get localGallery_entriesUnit => '条目';

  @override
  String get localGallery_hitRate => '命中率';

  @override
  String get localGallery_performanceStats => '性能监控统计';

  @override
  String get localGallery_cacheHit => '命中';

  @override
  String get localGallery_cacheMiss => '未命中';

  @override
  String get localGallery_clearL1 => '清除 L1';

  @override
  String get localGallery_clearL2 => '清除 L2';

  @override
  String get localGallery_clearAll => '清除全部';

  @override
  String get localGallery_resetStats => '重置统计';

  @override
  String get localGallery_confirmClearCache => '确认清除';

  @override
  String get localGallery_confirmClearCacheContent => '确定要清除所有缓存吗？这将重新扫描所有图片。';

  @override
  String get localGallery_filterByDate => '按日期筛选';

  @override
  String get localGallery_clearFilters => '清除筛选';

  @override
  String get slideshow_title => '幻灯片';

  @override
  String get slideshow_of => '/';

  @override
  String get slideshow_play => '播放';

  @override
  String get slideshow_pause => '暂停';

  @override
  String get slideshow_previous => '上一张';

  @override
  String get slideshow_next => '下一张';

  @override
  String get slideshow_exit => '退出 (Esc)';

  @override
  String get slideshow_noImages => '没有可显示的图片';

  @override
  String get slideshow_keyboardHint => '使用 ← → 导航，空格键播放/暂停，Esc 退出';

  @override
  String slideshow_autoPlayInterval(Object seconds) {
    return '自动播放间隔：$seconds秒';
  }

  @override
  String get comparison_title => '图片对比';

  @override
  String get comparison_noImages => '没有可显示的图片';

  @override
  String get comparison_tooManyImages => '图片数量过多';

  @override
  String get comparison_maxImages => '最多支持对比4张图片';

  @override
  String get comparison_close => '关闭对比';

  @override
  String get comparison_zoomHint => '捏合或滚动可独立缩放';

  @override
  String get comparison_loadError => '加载图片失败';

  @override
  String get statistics_title => '统计仪表盘';

  @override
  String get statistics_tabOverview => '总览';

  @override
  String get statistics_tabTrends => '趋势';

  @override
  String get statistics_tabDetails => '详情';

  @override
  String get statistics_noData => '暂无统计数据';

  @override
  String get statistics_generatedCount => '生成数量';

  @override
  String get statistics_favoriteCount => '收藏数';

  @override
  String statistics_tooltipGenerated(Object count) {
    return '生成数量: $count';
  }

  @override
  String statistics_tooltipFavorite(Object count) {
    return '收藏数: $count';
  }

  @override
  String get statistics_noTagData => '暂无标签数据';

  @override
  String get statistics_generateFirst => '先生成一些图片吧';

  @override
  String get statistics_overview => '总览';

  @override
  String get statistics_totalImages => '总图片数';

  @override
  String get statistics_totalSize => '总大小';

  @override
  String get statistics_favorites => '收藏';

  @override
  String get statistics_modelDistribution => '模型分布';

  @override
  String get statistics_resolutionDistribution => '分辨率分布';

  @override
  String get statistics_samplerDistribution => '采样器分布';

  @override
  String get statistics_sizeDistribution => '文件大小分布';

  @override
  String get statistics_additionalStats => '其他统计';

  @override
  String get statistics_averageFileSize => '平均文件大小';

  @override
  String get statistics_withMetadata => '有元数据的图片';

  @override
  String get statistics_calculatedAt => '计算时间';

  @override
  String get statistics_justNow => '刚刚';

  @override
  String statistics_minutesAgo(Object count) {
    return '$count 分钟前';
  }

  @override
  String statistics_hoursAgo(Object count) {
    return '$count 小时前';
  }

  @override
  String statistics_daysAgo(Object count) {
    return '$count 天前';
  }

  @override
  String get statistics_anlasCost => '点数消耗';

  @override
  String get statistics_totalAnlasCost => '总消耗';

  @override
  String get statistics_avgDailyCost => '日均消耗';

  @override
  String get statistics_noAnlasData => '暂无点数消耗数据';

  @override
  String get statistics_peakActivity => '活跃高峰';

  @override
  String get statistics_timeMorning => '上午';

  @override
  String get statistics_timeAfternoon => '下午';

  @override
  String get statistics_timeEvening => '傍晚';

  @override
  String get statistics_timeNight => '深夜';

  @override
  String get localGallery_favoritesOnly => '仅显示收藏';

  @override
  String get localGallery_noFavorites => '暂无收藏';

  @override
  String get localGallery_markAsFavorite => '添加到收藏';

  @override
  String get localGallery_removeTag => '移除标签';

  @override
  String get localGallery_filterByTags => '按标签筛选';

  @override
  String get localGallery_selectTags => '选择标签';

  @override
  String get localGallery_tagFilterMatchAll => '匹配所有标签';

  @override
  String get localGallery_tagFilterMatchAny => '匹配任意标签';

  @override
  String get localGallery_clearTagFilter => '清除标签筛选';

  @override
  String get localGallery_noTagsFound => '未找到标签';

  @override
  String get localGallery_advancedFilters => '高级筛选';

  @override
  String get localGallery_filterByModel => '按模型筛选';

  @override
  String get localGallery_filterBySampler => '按采样器筛选';

  @override
  String get localGallery_filterBySteps => '按步数筛选';

  @override
  String get localGallery_filterByCfg => '按 CFG 筛选';

  @override
  String get localGallery_filterByResolution => '按分辨率筛选';

  @override
  String get localGallery_filterSubtitle => '精确筛选您的图片集合';

  @override
  String get localGallery_modelHint => '输入模型名称...';

  @override
  String get localGallery_samplerHint => '输入采样器名称...';

  @override
  String get localGallery_resolutionHint => '宽度x高度 (如: 1024x1024)';

  @override
  String get localGallery_any => '任意';

  @override
  String get localGallery_to => '至';

  @override
  String get localGallery_activeFiltersSet => '已设置筛选';

  @override
  String get localGallery_applyFilters => '应用筛选';

  @override
  String get localGallery_resetAdvancedFilters => '重置高级筛选';

  @override
  String get localGallery_exportMetadata => '导出元数据';

  @override
  String get localGallery_exportSelected => '导出选中项';

  @override
  String get localGallery_exportFailed => '导出失败';

  @override
  String get localGallery_exporting => '导出中...';

  @override
  String get localGallery_selectToExport => '选择要导出的图片';

  @override
  String get localGallery_noImagesSelected => '未选择图片';

  @override
  String localGallery_exportSuccessDetail(Object count) {
    return '已导出 $count 张图片及元数据';
  }

  @override
  String bulkExport_title(Object count) {
    return '导出 $count 张图片';
  }

  @override
  String get bulkExport_format => '导出格式';

  @override
  String get bulkExport_jsonFormat => 'JSON';

  @override
  String get bulkExport_csvFormat => 'CSV';

  @override
  String get bulkExport_metadataOptions => '元数据选项';

  @override
  String get bulkExport_includeMetadata => '包含元数据';

  @override
  String get bulkExport_includeMetadataHint => '导出生成参数等信息';

  @override
  String get localGallery_group_today => '今天';

  @override
  String get localGallery_group_yesterday => '昨天';

  @override
  String get localGallery_group_thisWeek => '本周';

  @override
  String get localGallery_group_earlier => '更早';

  @override
  String get localGallery_group_dateFormat => 'MM月dd日';

  @override
  String get localGallery_noImagesOnThisDate => '该日期没有图片';

  @override
  String get localGallery_selectedImagesNoPrompt => '选中的图片没有 Prompt 信息';

  @override
  String localGallery_cannotOpenFolder(Object error) {
    return '无法打开文件夹: $error';
  }

  @override
  String localGallery_jumpedToDate(Object date) {
    return '已跳转到 $date';
  }

  @override
  String get localGallery_permissionRequiredTitle => '需要存储权限';

  @override
  String get localGallery_permissionRequiredContent =>
      '本地画廊需要访问存储权限才能扫描您生成的图片。\n\n请在设置中授予权限后重试。';

  @override
  String get localGallery_openSettings => '打开设置';

  @override
  String get localGallery_firstTimeTipTitle => '💡 使用提示';

  @override
  String get localGallery_firstTimeTipContent =>
      '右键点击（桌面端）或长按（移动端）图片可以：\n\n• 复制 Prompt\n• 复制 Seed\n• 查看完整元数据';

  @override
  String get localGallery_gotIt => '知道了';

  @override
  String get localGallery_undone => '已撤销';

  @override
  String get localGallery_redone => '已重做';

  @override
  String get localGallery_confirmBulkDelete => '确认批量删除';

  @override
  String localGallery_confirmBulkDeleteContent(Object count) {
    return '确定要删除选中的 $count 张图片吗？\n\n此操作将从文件系统中永久删除这些图片，无法恢复。';
  }

  @override
  String localGallery_deletedImages(Object count) {
    return '已删除 $count 张图片';
  }

  @override
  String get localGallery_noFoldersAvailable => '暂无可用文件夹，请先创建文件夹';

  @override
  String get localGallery_moveToFolder => '移动到文件夹';

  @override
  String localGallery_imageCount(Object count) {
    return '$count 张图片';
  }

  @override
  String localGallery_movedImages(Object count) {
    return '已移动 $count 张图片';
  }

  @override
  String get localGallery_moveImagesFailed => '移动图片失败';

  @override
  String localGallery_addedToCollection(Object count, Object name) {
    return '已添加 $count 张图片到集合「$name」';
  }

  @override
  String get localGallery_addToCollectionFailed => '添加图片到集合失败';

  @override
  String get brushPreset_selectHint => '双击选择此笔刷预设';

  @override
  String get brushPreset_selected => '已选择';

  @override
  String get brushPreset_pencil => '铅笔';

  @override
  String get brushPreset_fine => '细笔';

  @override
  String get brushPreset_standard => '标准笔刷';

  @override
  String get brushPreset_soft => '软笔刷';

  @override
  String get brushPreset_airbrush => '喷枪';

  @override
  String get brushPreset_marker => '马克笔';

  @override
  String get brushPreset_thick => '粗笔刷';

  @override
  String get brushPreset_smudge => '涂抹笔刷';

  @override
  String bulkProgress_progress(Object current, Object total) {
    return '正在处理 $current/$total';
  }

  @override
  String bulkProgress_success(Object count) {
    return '$count 项成功';
  }

  @override
  String bulkProgress_failed(Object count) {
    return '$count 项失败';
  }

  @override
  String get bulkProgress_errors => '错误：';

  @override
  String bulkProgress_moreErrors(Object count) {
    return '...还有 $count 个错误';
  }

  @override
  String bulkProgress_completed(Object count) {
    return '已完成 $count 项';
  }

  @override
  String bulkProgress_completedWithErrors(Object success, Object failed) {
    return '$success 项成功，$failed 项失败';
  }

  @override
  String get bulkProgress_title_delete => '删除图片中';

  @override
  String get bulkProgress_title_export => '导出元数据中';

  @override
  String get bulkProgress_title_metadataEdit => '编辑元数据中';

  @override
  String get bulkProgress_title_addToCollection => '添加到收集中';

  @override
  String get bulkProgress_title_removeFromCollection => '从集合中移除';

  @override
  String get bulkProgress_title_toggleFavorite => '更新收藏中';

  @override
  String get bulkProgress_title_default => '处理中';

  @override
  String bulkProgress_errorDeleteFailed(String error) {
    return '删除图片失败：$error';
  }

  @override
  String get bulkProgress_errorNoImagesToExport => '没有可导出的图片';

  @override
  String get bulkProgress_errorExportFailed => '导出失败';

  @override
  String bulkProgress_errorExportFailedWithDetails(String error) {
    return '导出失败：$error';
  }

  @override
  String get bulkProgress_errorNoMetadataChanges => '请至少输入一个要添加或移除的标签';

  @override
  String bulkProgress_errorMetadataEditFailed(String error) {
    return '编辑图片元数据失败：$error';
  }

  @override
  String bulkProgress_errorFavoriteFailed(String error) {
    return '更新收藏状态失败：$error';
  }

  @override
  String get bulkProgress_errorNoImagesForCollection => '没有可添加到集合的图片';

  @override
  String bulkProgress_errorAddToCollectionFailed(String error) {
    return '将图片添加到集合失败：$error';
  }

  @override
  String get bulkProgress_errorNothingToUndo => '没有可撤销的操作';

  @override
  String bulkProgress_errorUndoFailed(String error) {
    return '撤销失败：$error';
  }

  @override
  String get bulkProgress_errorNothingToRedo => '没有可重做的操作';

  @override
  String bulkProgress_errorRedoFailed(String error) {
    return '重做失败：$error';
  }

  @override
  String get collectionSelect_dialogTitle => '选择集合';

  @override
  String get collectionSelect_filterHint => '搜索集合...';

  @override
  String get collectionSelect_noCollections => '暂无集合';

  @override
  String get collectionSelect_createCollectionHint => '请先创建一个集合';

  @override
  String get collectionSelect_noFilterResults => '没有找到匹配的集合';

  @override
  String collectionSelect_imageCount(int count) {
    return '$count 张图片';
  }

  @override
  String get statistics_navOverview => '概览';

  @override
  String get statistics_navModels => '模型';

  @override
  String get statistics_navTrends => '趋势';

  @override
  String get statistics_navActivity => '时段';

  @override
  String get statistics_sectionTagAnalysis => '标签分析';

  @override
  String get statistics_sectionParameterPrefs => '参数偏好';

  @override
  String get statistics_sectionActivityAnalysis => '活动分析';

  @override
  String get statistics_chartTopTags => '热门标签';

  @override
  String get statistics_chartAspectRatio => '宽高比分布';

  @override
  String get statistics_chartActivityHeatmap => '活动热力图';

  @override
  String get statistics_chartHourlyDistribution => '小时分布';

  @override
  String get statistics_chartWeekdayDistribution => '星期分布';

  @override
  String get statistics_aspectSquare => '方形';

  @override
  String get statistics_aspectLandscape => '横屏';

  @override
  String get statistics_aspectPortrait => '竖屏';

  @override
  String get statistics_aspectOther => '其他';

  @override
  String get statistics_refresh => '刷新';

  @override
  String get statistics_retry => '重试';

  @override
  String statistics_error(Object error) {
    return '错误: $error';
  }

  @override
  String get statistics_peakHour => '高峰时段';

  @override
  String get statistics_mostActiveDay => '最活跃日';

  @override
  String get statistics_leastActiveDay => '最不活跃日';

  @override
  String get statistics_morning => '早晨';

  @override
  String get statistics_sunday => '周日';

  @override
  String get statistics_monday => '周一';

  @override
  String get statistics_tuesday => '周二';

  @override
  String get statistics_wednesday => '周三';

  @override
  String get statistics_thursday => '周四';

  @override
  String get statistics_friday => '周五';

  @override
  String get statistics_saturday => '周六';

  @override
  String get fixedTags_label => '固定词';

  @override
  String get fixedTags_enabled => '已启用';

  @override
  String get fixedTags_empty => '暂无固定词';

  @override
  String get fixedTags_emptyHint => '点击下方按钮添加固定词，它们会自动应用到你的提示词中';

  @override
  String get fixedTags_clickToManage => '点击管理固定词';

  @override
  String get fixedTags_manage => '管理固定词';

  @override
  String get fixedTags_add => '添加';

  @override
  String get fixedTags_edit => '编辑固定词';

  @override
  String get fixedTags_openLibrary => '打开词库';

  @override
  String get fixedTags_prefix => '前缀';

  @override
  String get fixedTags_suffix => '后缀';

  @override
  String get fixedTags_prefixDesc => '添加到提示词前面';

  @override
  String get fixedTags_suffixDesc => '添加到提示词后面';

  @override
  String get fixedTags_disabled => '已禁用';

  @override
  String get fixedTags_weight => '权重';

  @override
  String get fixedTags_position => '位置';

  @override
  String get fixedTags_name => '名称';

  @override
  String get fixedTags_nameHint => '输入备注名称（可选）';

  @override
  String get fixedTags_content => '内容';

  @override
  String get fixedTags_contentHint => '输入提示词内容，支持 NAI 语法';

  @override
  String get fixedTags_syntaxHelp => '支持 NAI 语法增强/减弱权重、标签交替等';

  @override
  String get fixedTags_linkedFromLibrary => '关联自词库（双向同步）';

  @override
  String get fixedTags_scope => '作用范围';

  @override
  String get fixedTags_positive => '正向';

  @override
  String get fixedTags_negative => '负向';

  @override
  String get fixedTags_resetWeight => '重置为 1.0';

  @override
  String get fixedTags_weightPreview => '权重预览:';

  @override
  String get fixedTags_deleteTitle => '删除固定词';

  @override
  String fixedTags_deleteConfirm(Object name) {
    return '确定要删除固定词 \"$name\" 吗？';
  }

  @override
  String fixedTags_enabledCount(Object enabled, Object total) {
    return '$enabled/$total 已启用';
  }

  @override
  String get fixedTags_saveToLibrary => '同时保存到词库';

  @override
  String get fixedTags_saveToLibraryHint => '方便日后在词库中重复使用';

  @override
  String get fixedTags_saveToCategory => '保存到类别';

  @override
  String get fixedTags_clearAll => '清空';

  @override
  String get fixedTags_clearAllTitle => '清空所有固定词';

  @override
  String fixedTags_clearAllConfirm(Object count) {
    return '确定要清空所有 $count 个固定词吗？此操作不可撤销。';
  }

  @override
  String get fixedTags_clearedSuccess => '已清空所有固定词';

  @override
  String get fixedTags_sidebarTitle => '固定词侧栏';

  @override
  String get fixedTags_switchGridView => '切换网格视图';

  @override
  String get fixedTags_switchListView => '切换列表视图';

  @override
  String get fixedTags_addPositive => '新增正向固定词';

  @override
  String get fixedTags_addNegative => '新增负向固定词';

  @override
  String get fixedTags_addPositiveFromLibrary => '从词库添加正向';

  @override
  String get fixedTags_addNegativeFromLibrary => '从词库添加负向';

  @override
  String get fixedTags_searchNameOrContent => '搜索名称或内容';

  @override
  String get fixedTags_clearSearch => '清空搜索';

  @override
  String get fixedTags_enabledPositive => '已启用正向';

  @override
  String get fixedTags_emptyEnabledPositive => '暂无启用的正向固定词';

  @override
  String get fixedTags_noMatchingEnabled => '没有匹配的启用固定词';

  @override
  String get fixedTags_negativeTitle => '负向固定词';

  @override
  String get fixedTags_emptyNegative => '暂无负向固定词';

  @override
  String get fixedTags_noMatchingNegative => '没有匹配的负向固定词';

  @override
  String get fixedTags_addedToSidebar => '已添加到固定词侧栏';

  @override
  String get fixedTags_unknownCategory => '未知分类';

  @override
  String get fixedTags_uncategorized => '未分类';

  @override
  String get fixedTags_clickManageLongPressSidebar => '点击管理，长按打开侧栏';

  @override
  String get fixedTags_clickManageLongPressCompact => '点击管理，长按侧栏';

  @override
  String get fixedTags_linked => '联动';

  @override
  String fixedTags_linkCount(Object count) {
    return '$count 个联动';
  }

  @override
  String get fixedTags_expandNegative => '展开负向';

  @override
  String get fixedTags_collapseNegative => '收起负向';

  @override
  String get fixedTags_undoTooltip => '撤销固定词操作';

  @override
  String get fixedTags_redoTooltip => '重做固定词操作';

  @override
  String get fixedTags_positiveTitle => '正向固定词';

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
    return '$enabled/$total · 显示 $shown';
  }

  @override
  String get fixedTags_new => '新建';

  @override
  String fixedTags_newTarget(Object target) {
    return '新建$target';
  }

  @override
  String get fixedTags_library => '词库';

  @override
  String fixedTags_addFromLibraryToTarget(Object target) {
    return '从词库添加到$target';
  }

  @override
  String get fixedTags_enableAll => '全开';

  @override
  String get fixedTags_disableAll => '全关';

  @override
  String fixedTags_searchTarget(Object target) {
    return '搜索 $target...';
  }

  @override
  String get fixedTags_noMatching => '无匹配固定词';

  @override
  String fixedTags_emptyTarget(Object target) {
    return '暂无$target';
  }

  @override
  String get fixedTags_dragToLink => '拖拽创建联动';

  @override
  String fixedTags_linkedToNames(Object names) {
    return '已联动：$names';
  }

  @override
  String get fixedTags_linkInstruction => '拖拽正向固定词的关联图标到负向固定词即可创建联动';

  @override
  String get fixedTags_manageLinks => '管理联动';

  @override
  String fixedTags_removeLink(Object name) {
    return '取消联动：$name';
  }

  @override
  String get fixedTags_footerExpandedHint => '在各列顶部新建或从词库添加';

  @override
  String get fixedTags_newPositive => '新建正向';

  @override
  String get fixedTags_addPositiveFromLibraryShort => '词库添加正向';

  @override
  String get fixedTags_libraryEmpty => '词库为空，请先添加条目';

  @override
  String get fixedTags_addFromLibrary => '从词库添加';

  @override
  String get fixedTags_searchLibraryEntries => '搜索词库条目...';

  @override
  String get fixedTags_noMatchingResults => '无匹配结果';

  @override
  String get reversePrompt_title => '反推';

  @override
  String get reversePrompt_pending => '待添加';

  @override
  String reversePrompt_imageCount(Object count) {
    return '$count 张';
  }

  @override
  String get reversePrompt_llmReverse => 'LLM 反推';

  @override
  String get reversePrompt_characterReplace => '角色替换';

  @override
  String get reversePrompt_finalResult => '最终结果';

  @override
  String get reversePrompt_dropToAdd => '松开后添加到反推';

  @override
  String get reversePrompt_addOrDropImages => '增加图片 / 拖入图片';

  @override
  String get reversePrompt_localTaggerModel => '本地 tagger 模型';

  @override
  String get reversePrompt_localTaggerModelHint => '请在设置中配置模型文件夹';

  @override
  String get reversePrompt_generalThreshold => '通用标签阈值';

  @override
  String get reversePrompt_characterThreshold => '角色标签阈值';

  @override
  String get reversePrompt_taggerFilterHint =>
      '只输出 General / Character 分类标签；Rating、Artist、Copyright、Meta 等分类会被过滤。';

  @override
  String get reversePrompt_replacementEmptyHint =>
      '替换目标角色为空。这里从词库选择一个角色作为替换目标，不会注入到正向提示词。';

  @override
  String get reversePrompt_selectReplacementCharacter => '从词库选择替换目标角色';

  @override
  String get reversePrompt_selectReplacementTargetTitle => '选择替换目标角色';

  @override
  String get reversePrompt_change => '更换';

  @override
  String get reversePrompt_start => '开始反推';

  @override
  String get reversePrompt_sentToPrompt => '已发送到提示词';

  @override
  String get reversePrompt_sendToPrompt => '发送到提示词';

  @override
  String get reversePrompt_externalTarget => '多模态 LLM 反推服务';

  @override
  String get reversePrompt_dropUnreadable => '拖入源未提供可读取的图片文件或图片链接';

  @override
  String get reversePrompt_needImageAndMethod =>
      '请先添加图片，并至少启用 ONNX tagger 或 LLM 反推';

  @override
  String get reversePrompt_stagePreparing => '准备反推';

  @override
  String get reversePrompt_stageOnnxTagger => 'ONNX tagger 反推中';

  @override
  String get reversePrompt_stageLlmReverse => 'LLM 读图反推中';

  @override
  String get reversePrompt_stageCharacterReplace => '角色替换中';

  @override
  String get reversePrompt_needReplacementCharacter => '请先在反推角色库中选择一个有效角色';

  @override
  String get reversePrompt_needPromptForCharacterReplace => '角色替换需要先获得反推提示词';

  @override
  String get reversePrompt_noOnnxModel => '未找到 ONNX tagger 模型，请先在设置中配置模型文件夹';

  @override
  String get promptAssistant_translateProcessing => '翻译中';

  @override
  String get promptAssistant_optimizeProcessing => '优化中';

  @override
  String get promptAssistant_characterReplaceProcessing => '角色替换中';

  @override
  String get promptAssistant_customProcessing => '自定义处理中';

  @override
  String get promptAssistant_imageInputDisabled => '当前自定义任务服务商未启用图片输入';

  @override
  String get promptAssistant_needCharacter => '请先在反推角色库中添加有效角色';

  @override
  String get promptAssistant_assistantSettings => '助手设置';

  @override
  String get promptAssistant_serviceSettings => '服务设置';

  @override
  String get promptAssistant_ruleSettings => '规则设置';

  @override
  String get promptAssistant_cancelCurrentTask => '取消当前任务';

  @override
  String get promptAssistant_collapseAssistant => '收起助手';

  @override
  String get promptAssistant_expandAssistant => '展开助手';

  @override
  String get promptAssistant_history => '历史';

  @override
  String get promptAssistant_undo => '撤销';

  @override
  String get promptAssistant_redo => '重做';

  @override
  String get promptAssistant_translate => '翻译';

  @override
  String get promptAssistant_optimize => '优化';

  @override
  String get promptAssistant_custom => '自定义';

  @override
  String get promptAssistant_characterReplace => '角色替换';

  @override
  String get promptAssistant_cancelTask => '取消任务';

  @override
  String get promptAssistant_menu => '菜单';

  @override
  String get promptAssistant_customDialogTitle => '自定义提示词助手';

  @override
  String get promptAssistant_currentPrompt => '当前提示词';

  @override
  String get promptAssistant_currentPromptEmpty => '（当前提示词为空）';

  @override
  String get promptAssistant_customRequestLabel => '你的修改需求';

  @override
  String get promptAssistant_customRequestHint =>
      '例如：更阴森、增加雨夜街道背景、让动作更有张力，只返回最终提示词';

  @override
  String get promptAssistant_addReferenceImage => '添加参考图';

  @override
  String get promptAssistant_execute => '执行';

  @override
  String promptAssistant_maxReferenceImages(Object count) {
    return '最多添加 $count 张参考图片';
  }

  @override
  String promptAssistant_unsupportedImageFormat(Object fileName) {
    return '不支持的图片格式: $fileName';
  }

  @override
  String get promptAssistant_needCustomRequestOrImage => '请输入自定义需求或添加参考图片';

  @override
  String get promptAssistant_taskOptimize => '优化';

  @override
  String get promptAssistant_taskTranslate => '翻译';

  @override
  String get promptAssistant_taskReverse => '反推';

  @override
  String get promptAssistant_taskCharacterReplace => '角色替换';

  @override
  String get promptAssistant_taskCustom => '自定义';

  @override
  String get promptAssistant_settingsInputSwitchSubtitle => '输入框右下角助手开关';

  @override
  String get promptAssistant_desktopOverlayTitle => '桌面浮层交互';

  @override
  String get promptAssistant_desktopOverlaySubtitle => '启用 hover / 右键 / 快捷键行为';

  @override
  String get promptAssistant_taskRouting => '任务路由';

  @override
  String get promptAssistant_taskRoutingSubtitle => '优化、翻译、反推、角色替换可绑定不同服务商和模型';

  @override
  String promptAssistant_taskRouteTitle(Object title) {
    return '$title任务';
  }

  @override
  String get promptAssistant_provider => '服务商';

  @override
  String get promptAssistant_model => '模型';

  @override
  String get promptAssistant_noModelsPullFirst => '暂无模型，请先拉取';

  @override
  String get promptAssistant_providerManagement => '服务商管理';

  @override
  String get promptAssistant_providerManagementSubtitle =>
      '支持 OpenAI Chat / Responses、Anthropic、Gemini、DeepSeek、LM Studio、Ollama、Pollinations 和自定义兼容端点';

  @override
  String get promptAssistant_apiKeyConfigured => 'API Key: 已配置';

  @override
  String get promptAssistant_apiKeyNotConfigured => 'API Key: 未配置';

  @override
  String get promptAssistant_supportsImageInput => '支持图片输入';

  @override
  String get promptAssistant_textOnly => '仅文本';

  @override
  String get promptAssistant_connectionConfig => '连接配置';

  @override
  String get promptAssistant_pullModelList => '拉取模型列表';

  @override
  String get promptAssistant_editProvider => '编辑服务商';

  @override
  String get promptAssistant_deleteProvider => '删除服务商';

  @override
  String get promptAssistant_pullingModels => '正在拉取模型列表...';

  @override
  String get promptAssistant_emptyModelList => '服务返回空模型列表';

  @override
  String promptAssistant_modelsSynced(Object count) {
    return '已同步 $count 个模型';
  }

  @override
  String promptAssistant_pullModelsFailed(Object error) {
    return '拉取模型失败: $error';
  }

  @override
  String get promptAssistant_ruleTemplates => '规则模板';

  @override
  String get promptAssistant_ruleTemplatesSubtitle =>
      '系统提示词按“规则 + 用户输入 + 任务参数”组装';

  @override
  String get promptAssistant_addRule => '新增规则';

  @override
  String get promptAssistant_addProvider => '新增服务商';

  @override
  String get promptAssistant_editProviderTitle => '编辑服务商';

  @override
  String get promptAssistant_name => '名称';

  @override
  String get promptAssistant_protocol => '协议';

  @override
  String get promptAssistant_allowImageInput => '允许发送图片输入';

  @override
  String get promptAssistant_allowImageInputSubtitle => '仅在模型和服务商实际支持视觉输入时启用';

  @override
  String get promptAssistant_apiKeyLeaveEmpty => 'API Key (留空不改)';

  @override
  String promptAssistant_connectionTitle(Object name) {
    return '$name 连接配置';
  }

  @override
  String get promptAssistant_baseUrlHint => '例如: https://api.openai.com/v1';

  @override
  String get promptAssistant_clearCurrentApiKey => '清空当前 API Key';

  @override
  String get promptAssistant_protocolSupportsImagePayload =>
      '当前协议支持图片载荷，仍需模型本身支持视觉输入';

  @override
  String get promptAssistant_protocolTextOnlyWarning =>
      '当前协议默认仅文本，开启后也可能被服务端拒绝';

  @override
  String get promptAssistant_addRuleTitle => '新增规则';

  @override
  String get promptAssistant_editRuleTitle => '编辑规则';

  @override
  String get promptAssistant_taskType => '任务类型';

  @override
  String get promptAssistant_ruleContent => '规则内容';

  @override
  String get promptAssistant_newRule => '新规则';

  @override
  String autocomplete_resultsCount(Object count) {
    return '$count 个结果';
  }

  @override
  String get autocomplete_keyNavigate => '↑↓/滚轮';

  @override
  String get autocomplete_actionSelect => '选择';

  @override
  String get autocomplete_actionConfirm => '确认';

  @override
  String get autocomplete_actionClose => '关闭';

  @override
  String get autocomplete_categoryRecommended => '推荐';

  @override
  String get autocomplete_categoryCharacter => '角色';

  @override
  String get autocomplete_categoryCopyright => '版权';

  @override
  String get autocomplete_categoryArtist => '艺术家';

  @override
  String get autocomplete_categoryMeta => '元数据';

  @override
  String get autocomplete_categoryLibrary => '词库';

  @override
  String get autocomplete_categoryGeneral => '通用';

  @override
  String get promptToken_webCalibration => '网页端校准';

  @override
  String get promptToken_prompt => '提示词';

  @override
  String get promptToken_fixedTags => '固定词';

  @override
  String get promptToken_qualityPreset => '质量预设';

  @override
  String get promptToken_character => '角色';

  @override
  String get promptToken_negativePrompt => '负面提示词';

  @override
  String get promptToken_negativeFixedTags => '负面固定词';

  @override
  String get promptToken_negativePreset => '负面预设';

  @override
  String get promptToken_characterNegative => '角色负面';

  @override
  String get common_rename => '重命名';

  @override
  String get common_create => '创建';

  @override
  String get tagLibrary_categories => '分类';

  @override
  String get tagLibrary_newCategory => '新建分类';

  @override
  String get tagLibrary_addEntry => '添加条目';

  @override
  String get tagLibrary_editEntry => '编辑条目';

  @override
  String get tagLibrary_searchHint => '搜索条目...';

  @override
  String get tagLibrary_cardView => '卡片视图';

  @override
  String get tagLibrary_listView => '列表视图';

  @override
  String get tagLibrary_import => '导入';

  @override
  String get tagLibrary_export => '导出';

  @override
  String get tagLibrary_sortCustom => '自定义排序';

  @override
  String get tagLibrary_sortName => '名称';

  @override
  String get tagLibrary_sortUseCount => '使用频率';

  @override
  String get tagLibrary_sortUpdatedAt => '更新时间';

  @override
  String get tagLibrary_transferCategory => '转移分类';

  @override
  String get tagLibrary_copyContent => '复制内容';

  @override
  String get tagLibrary_moveToCategoryTitle => '移动到分类';

  @override
  String get tagLibrary_selectTargetCategory => '选择目标分类：';

  @override
  String get tagLibrary_includeThumbnails => '包含预览图';

  @override
  String get tagLibrary_includeThumbnailsSubtitle => '将增加文件大小';

  @override
  String tagLibrary_selectedExportCount(Object count) {
    return '导出 ($count 项)';
  }

  @override
  String tagLibrary_selectedImportCount(Object count) {
    return '导入 ($count 项)';
  }

  @override
  String get tagLibrary_entriesLabel => '条目';

  @override
  String get tagLibrary_categoriesLabel => '分类';

  @override
  String get tagLibrary_selectExportContent => '选择要导出的内容';

  @override
  String get tagLibrary_selectImportContent => '选择要导入的内容';

  @override
  String get tagLibrary_selectSaveLocation => '选择保存位置';

  @override
  String get tagLibrary_preparingExport => '准备导出...';

  @override
  String get tagLibrary_exportSuccess => '导出成功';

  @override
  String tagLibrary_exportFailedWithError(Object error) {
    return '导出失败: $error';
  }

  @override
  String get tagLibrary_selectZipFile => '点击选择 ZIP 文件';

  @override
  String get tagLibrary_zipFileHint => '支持从本应用导出的词库文件';

  @override
  String get tagLibrary_reselect => '重新选择';

  @override
  String get tagLibrary_fileInfo => '文件信息';

  @override
  String get tagLibrary_entryCountLabel => '条目数';

  @override
  String get tagLibrary_categoryCountLabel => '分类数';

  @override
  String get tagLibrary_exportDateLabel => '导出时间';

  @override
  String tagLibrary_importConflictsHint(Object count) {
    return '发现 $count 个冲突项，请点击下方冲突项选择处理方式';
  }

  @override
  String tagLibrary_categoriesSection(Object count) {
    return '分类 ($count)';
  }

  @override
  String tagLibrary_entriesSection(Object count) {
    return '条目 ($count)';
  }

  @override
  String get tagLibrary_conflictResolutionTooltip => '选择冲突处理方式';

  @override
  String get tagLibrary_conflictSkip => '冲突 - 将跳过';

  @override
  String get tagLibrary_conflictRename => '冲突 - 将重命名导入';

  @override
  String get tagLibrary_conflictOverwrite => '冲突 - 将替换现有';

  @override
  String tagLibrary_parseFileFailed(Object error) {
    return '无法解析文件: $error';
  }

  @override
  String get tagLibrary_preparingImport => '准备导入...';

  @override
  String get tagLibrary_importCompleted => '导入完成';

  @override
  String tagLibrary_importSuccessSummary(Object summary) {
    return '导入成功: $summary';
  }

  @override
  String tagLibrary_importFailedWithError(Object error) {
    return '导入失败: $error';
  }

  @override
  String tagLibrary_importedEntriesCount(Object count) {
    return '$count 条目';
  }

  @override
  String tagLibrary_importedCategoriesCount(Object count) {
    return '$count 分类';
  }

  @override
  String tagLibrary_renamedCount(Object count) {
    return '$count 重命名';
  }

  @override
  String tagLibrary_overwrittenCount(Object count) {
    return '$count 替换';
  }

  @override
  String tagLibrary_skippedCount(Object count) {
    return '$count 跳过';
  }

  @override
  String get tagLibrary_dragToCategoryHint => '拖到左侧分类归档';

  @override
  String get tagLibrary_unknownCategory => '未知分类';

  @override
  String get tagLibrary_selectEntryToUpdate => '选择要更新的词条';

  @override
  String get tagLibrary_updatePreview => '更新预览图';

  @override
  String get tagLibrary_replaceThumbnailHint => '将替换现有预览图';

  @override
  String tagLibrary_sentEntriesToMainPrompt(Object count) {
    return '已发送 $count 个词条到主提示词';
  }

  @override
  String tagLibrary_confirmDeleteSelectedEntries(Object count) {
    return '确定要删除选中的 $count 个词条吗？此操作不可撤销。';
  }

  @override
  String tagLibrary_deletedEntries(Object count) {
    return '已删除 $count 个词条';
  }

  @override
  String tagLibrary_movedEntries(Object count) {
    return '已移动 $count 个词条';
  }

  @override
  String tagLibrary_favoritedEntries(Object count) {
    return '已收藏 $count 个词条';
  }

  @override
  String tagLibrary_unfavoritedEntries(Object count) {
    return '已取消收藏 $count 个词条';
  }

  @override
  String tagLibrary_copiedEntriesContent(Object count) {
    return '已复制 $count 个词条的内容';
  }

  @override
  String get tagLibrary_droppedImage => '拖入图片';

  @override
  String get tagLibrary_createEntryFromImage => '创建新词条';

  @override
  String tagLibrary_promptExtracted(Object prompt) {
    return '提示词已提取: \"$prompt\"';
  }

  @override
  String get tagLibrary_createEntryFromImageSubtitle => '从图片创建新词条';

  @override
  String get tagLibrary_updateExistingThumbnail => '更新现有词条预览图';

  @override
  String get tagLibrary_updateExistingThumbnailSubtitle => '选择词条并替换其预览图';

  @override
  String get tagLibrary_allEntries => '全部';

  @override
  String get tagLibrary_favorites => '收藏';

  @override
  String get tagLibrary_addSubCategory => '添加子分类';

  @override
  String get tagLibrary_moveToRoot => '移动到根目录';

  @override
  String get tagLibrary_categoryNameHint => '输入分类名称';

  @override
  String get tagLibrary_deleteCategoryTitle => '删除分类';

  @override
  String tagLibrary_deleteCategoryConfirm(Object name, Object count) {
    return '确定要删除分类 \"$name\" 吗？该分类下的 $count 个条目将移至根目录。';
  }

  @override
  String get tagLibrary_deleteEntryTitle => '删除条目';

  @override
  String tagLibrary_deleteEntryConfirm(Object name) {
    return '确定要删除条目 \"$name\" 吗？';
  }

  @override
  String get tagLibrary_noSearchResults => '没有找到匹配的条目';

  @override
  String get tagLibrary_tryDifferentSearch => '尝试使用其他关键词搜索';

  @override
  String get tagLibrary_categoryEmpty => '该分类暂无条目';

  @override
  String get tagLibrary_empty => '词库为空';

  @override
  String get tagLibrary_addFirstEntry => '点击上方按钮添加第一个条目';

  @override
  String get tagLibraryPicker_title => '选择词条';

  @override
  String get tagLibraryPicker_searchHint => '搜索词条...';

  @override
  String get tagLibraryPicker_allCategories => '全部分类';

  @override
  String get tagLibrary_addToFixed => '添加到固定词';

  @override
  String get tagLibrary_addedToFixed => '已添加到固定词';

  @override
  String get tagLibrary_entryMoved => '条目已移动到目标分类';

  @override
  String tagLibrary_useCount(Object count) {
    return '使用 $count 次';
  }

  @override
  String get tagLibrary_addFavorite => '添加收藏';

  @override
  String get tagLibrary_thumbnail => '预览图';

  @override
  String get tagLibrary_selectImage => '选择图片';

  @override
  String get tagLibrary_thumbnailHint => '支持 PNG/JPG/WEBP 格式';

  @override
  String get tagLibrary_name => '名称';

  @override
  String get tagLibrary_nameHint => '输入条目名称';

  @override
  String get tagLibrary_category => '分类';

  @override
  String get tagLibrary_rootCategory => '根目录';

  @override
  String get tagLibrary_tags => '标签';

  @override
  String get tagLibrary_tagsHint => '输入标签，用逗号分隔';

  @override
  String get tagLibrary_tagsHelper => '标签用于筛选和搜索';

  @override
  String get tagLibrary_content => '提示词内容';

  @override
  String get tagLibrary_contentHint => '输入提示词内容，支持智能补全';

  @override
  String get settings_network => '网络';

  @override
  String get settings_enableProxy => '启用代理';

  @override
  String get settings_proxyEnabled => '已启用';

  @override
  String get settings_proxyDisabled => '直接连接网络';

  @override
  String get settings_proxyTrafficDisclosure =>
      '代理启用后，NovelAI API 流量（包括认证请求）会通过系统代理或手动代理发送。只使用你信任的代理。';

  @override
  String get settings_proxyMode => '代理模式';

  @override
  String get settings_proxyModeAuto => '自动检测系统代理';

  @override
  String get settings_proxyModeManual => '手动配置';

  @override
  String get settings_auto => '自动';

  @override
  String get settings_manual => '手动';

  @override
  String get settings_proxyHost => '代理地址';

  @override
  String get settings_proxyPort => '端口';

  @override
  String get settings_proxyNotDetected => '未检测到系统代理';

  @override
  String get settings_testConnection => '测试连接';

  @override
  String get settings_testConnectionHint => '点击测试代理是否可用';

  @override
  String settings_testSuccess(Object latency) {
    return '连接成功 (${latency}ms)';
  }

  @override
  String settings_testFailed(Object error) {
    return '连接失败: $error';
  }

  @override
  String get settings_proxyRestartHint => '代理设置已更改，建议重启应用';

  @override
  String get tagLibrary_categoryNameExists => '该分类名称已存在';

  @override
  String get tagLibrary_addToLibrary => '收藏到词库';

  @override
  String get tagLibrary_saveToLibrary => '保存到词库';

  @override
  String get tagLibrary_entrySaved => '收藏成功';

  @override
  String get tagLibrary_entryUpdated => '条目已更新';

  @override
  String get tagLibrary_uncategorized => '未分类';

  @override
  String get tagLibrary_contentPreview => '内容预览';

  @override
  String get tagLibrary_confirmAdd => '确认收藏';

  @override
  String get tagLibrary_entryName => '名称';

  @override
  String get tagLibrary_entryNameHint => '输入条目名称';

  @override
  String get tagLibrary_selectNewImage => '选择新图片';

  @override
  String get tagLibrary_adjustDisplayRange => '调整显示范围';

  @override
  String get tagLibrary_adjustThumbnailTitle => '调整预览图显示范围';

  @override
  String get tagLibrary_dragToMove => '拖拽移动，滚轮或双指缩放';

  @override
  String get tagLibrary_livePreview => '实时预览';

  @override
  String get tagLibrary_horizontalOffset => '水平偏移';

  @override
  String get tagLibrary_verticalOffset => '垂直偏移';

  @override
  String get tagLibrary_zoomRatio => '缩放比例';

  @override
  String get queue_title => '队列';

  @override
  String get queue_management => '队列管理';

  @override
  String get queue_empty => '队列为空';

  @override
  String get queue_emptyHint => '没有待执行的任务';

  @override
  String queue_taskCount(Object count) {
    return '$count 个任务';
  }

  @override
  String get queue_pending => '等待中';

  @override
  String get queue_running => '执行中';

  @override
  String get queue_completed => '已完成';

  @override
  String get queue_failed => '失败';

  @override
  String get queue_skipped => '已跳过';

  @override
  String get queue_paused => '已暂停';

  @override
  String get queue_idle => '空闲';

  @override
  String get queue_ready => '就绪';

  @override
  String get queue_clickToStart => '点击开始执行队列';

  @override
  String get queue_clickToPause => '点击暂停队列';

  @override
  String get queue_clickToResume => '点击继续执行';

  @override
  String get queue_noTasksToStart => '队列为空，无法开始';

  @override
  String get queue_allTasksCompleted => '所有任务已完成';

  @override
  String get queue_executionProgress => '执行进度';

  @override
  String get queue_totalTasks => '总数';

  @override
  String get queue_completedTasks => '已完成';

  @override
  String get queue_failedTasks => '失败';

  @override
  String get queue_remainingTasks => '剩余';

  @override
  String queue_estimatedTime(Object time) {
    return '预计：约 $time';
  }

  @override
  String queue_seconds(Object count) {
    return '$count 秒';
  }

  @override
  String queue_minutes(Object count) {
    return '$count 分钟';
  }

  @override
  String queue_hours(Object hours, Object minutes) {
    return '$hours 小时 $minutes 分钟';
  }

  @override
  String get queue_pause => '暂停';

  @override
  String get queue_resume => '继续';

  @override
  String get queue_pauseExecution => '暂停执行';

  @override
  String get queue_resumeExecution => '继续执行';

  @override
  String get queue_autoExecute => '自动执行';

  @override
  String get queue_autoExecuteOn => '完成后自动执行下一个任务';

  @override
  String get queue_autoExecuteOff => '需要手动点击生成';

  @override
  String get queue_taskInterval => '任务间隔';

  @override
  String get queue_taskIntervalHint => '任务之间的等待时间（0-10秒）';

  @override
  String get queue_clearQueue => '清空队列';

  @override
  String get queue_closeFloatingButton => '关闭悬浮球';

  @override
  String get queue_clearQueueConfirm => '确定要清空所有队列任务吗？此操作不可撤销。';

  @override
  String get queue_confirmClear => '确认清空';

  @override
  String get queue_failureStrategy => '失败策略';

  @override
  String get queue_failureStrategyAutoRetry => '自动重试';

  @override
  String get queue_failureStrategyAutoRetryDesc => '达到最大重试次数后移至队列末尾';

  @override
  String get queue_failureStrategySkipDesc => '将失败任务移入失败池，继续执行下一个';

  @override
  String get queue_failureStrategyPause => '暂停等待';

  @override
  String get queue_failureStrategyPauseDesc => '暂停队列，等待手动处理';

  @override
  String queue_retryCount(Object current, Object max) {
    return '重试 $current/$max';
  }

  @override
  String get queue_retry => '重试';

  @override
  String get queue_requeue => '重新排队';

  @override
  String get queue_requeueToEnd => '移至队列末尾';

  @override
  String get queue_clearFailedTasks => '清空全部';

  @override
  String get queue_noFailedTasks => '暂无失败任务';

  @override
  String get queue_noCompletedTasks => '暂无完成记录';

  @override
  String get queue_editTask => '编辑任务';

  @override
  String get queue_duplicateTask => '复制任务';

  @override
  String get queue_taskDuplicated => '任务已复制';

  @override
  String get queue_queueFull => '队列已满，无法复制';

  @override
  String get queue_positivePrompt => '正向提示词';

  @override
  String get queue_enterPositivePrompt => '输入正向提示词...';

  @override
  String get queue_parametersPreview => '参数预览';

  @override
  String get queue_model => '模型';

  @override
  String get queue_seed => '种子';

  @override
  String get queue_sampler => '采样器';

  @override
  String get queue_steps => '步数';

  @override
  String get queue_cfg => 'CFG';

  @override
  String get queue_size => '尺寸';

  @override
  String get queue_addToQueue => '加入队列';

  @override
  String get queue_taskAdded => '已加入队列';

  @override
  String get queue_negativePromptFromMain => '负向提示词将使用主界面设置';

  @override
  String get queue_pinToTop => '置顶';

  @override
  String get queue_delete => '删除';

  @override
  String get queue_edit => '编辑';

  @override
  String get queue_selectAll => '全选';

  @override
  String get queue_invertSelection => '反选';

  @override
  String get queue_cancelSelection => '取消';

  @override
  String queue_selectedCount(Object count) {
    return '已选 $count 个';
  }

  @override
  String get queue_batchPinToTop => '置顶选中';

  @override
  String queue_confirmDeleteSelected(Object count) {
    return '确定要删除选中的 $count 个任务吗？';
  }

  @override
  String get queue_export => '导出';

  @override
  String get queue_import => '导入';

  @override
  String get queue_exportImport => '队列导入/导出';

  @override
  String get queue_exportFormat => '导出格式';

  @override
  String get queue_exportFormatJson => 'JSON';

  @override
  String get queue_exportFormatJsonDesc => '完整数据，包含所有参数';

  @override
  String get queue_exportFormatCsv => 'CSV';

  @override
  String get queue_exportFormatCsvDesc => '表格格式，含提示词和基本信息';

  @override
  String get queue_exportFormatText => '纯文本';

  @override
  String get queue_exportFormatTextDesc => '仅提示词，每行一个';

  @override
  String get queue_importStrategy => '导入策略';

  @override
  String get queue_importStrategyMerge => '合并';

  @override
  String get queue_importStrategyMergeDesc => '将导入的任务添加到现有队列末尾';

  @override
  String get queue_importStrategyReplace => '替换';

  @override
  String get queue_importStrategyReplaceDesc => '清空现有队列，使用导入的任务替换';

  @override
  String get queue_supportedFormats => '支持的格式：';

  @override
  String get queue_supportedFormatJson => '• JSON 文件 (.json)';

  @override
  String get queue_supportedFormatCsv => '• CSV 文件 (.csv)';

  @override
  String get queue_supportedFormatText => '• 纯文本文件 (.txt) - 每行一个提示词';

  @override
  String get queue_shareSubject => '队列导出';

  @override
  String queue_unsupportedFileFormat(Object extension) {
    return '不支持的文件格式: $extension';
  }

  @override
  String get queue_exportSuccess => '导出成功';

  @override
  String queue_exportFailed(Object error) {
    return '导出失败：$error';
  }

  @override
  String queue_importSuccess(Object count) {
    return '成功导入 $count 个任务';
  }

  @override
  String queue_importFailed(Object error) {
    return '导入失败：$error';
  }

  @override
  String get queue_selectFile => '选择要导入的文件';

  @override
  String get queue_noValidTasks => '文件中没有有效任务';

  @override
  String get queue_settings => '队列设置';

  @override
  String get settings_queueRetryCount => '重试次数';

  @override
  String get settings_queueRetryInterval => '重试间隔';

  @override
  String get settings_queueRetryCountSubtitle => '失败任务的最大重试次数';

  @override
  String get settings_queueRetryIntervalSubtitle => '重试之间的等待时间';

  @override
  String get settings_showRandomPromptTools => '显示随机提示词工具';

  @override
  String get settings_showRandomPromptToolsSubtitle =>
      '在生成页显示“随机提示词”按钮和“抽卡模式”开关';

  @override
  String get settings_enablePromptWeightScroll => '滚轮调整提示词权重';

  @override
  String get settings_enablePromptWeightScrollSubtitle =>
      '选中提示词时，滚轮仅调整权重，不再触发页面滚动等其他滚轮操作';

  @override
  String settings_queueRetryCountMax(Object count) {
    return '最多 $count 次';
  }

  @override
  String settings_queueRetryIntervalValue(Object seconds) {
    return '$seconds 秒';
  }

  @override
  String get unit_times => '次';

  @override
  String get unit_seconds => '秒';

  @override
  String get settings_floatingButtonBackground => '悬浮球背景';

  @override
  String get settings_floatingButtonBackgroundCustom => '已设置自定义背景';

  @override
  String get settings_floatingButtonBackgroundDefault => '默认样式';

  @override
  String get settings_clearBackground => '清除背景';

  @override
  String get settings_selectImage => '选择图片';

  @override
  String queue_currentQueueInfo(Object count) {
    return '当前队列包含 $count 个任务';
  }

  @override
  String queue_tooltipTasksTotal(Object count) {
    return '任务数：$count';
  }

  @override
  String queue_tooltipCompleted(Object count) {
    return '已完成：$count';
  }

  @override
  String queue_tooltipFailed(Object count) {
    return '失败：$count';
  }

  @override
  String queue_tooltipCurrentTask(Object task) {
    return '当前任务：$task';
  }

  @override
  String get queue_tooltipNoTasks => '队列中没有任务';

  @override
  String get queue_tooltipDoubleClickToOpen => '双击开始/暂停';

  @override
  String get queue_tooltipClickToToggle => '单击打开队列管理';

  @override
  String get queue_tooltipDragToMove => '拖拽调整位置';

  @override
  String get queue_statusIdle => '状态：空闲';

  @override
  String get queue_statusReady => '状态：就绪';

  @override
  String get queue_statusRunning => '状态：运行中';

  @override
  String get queue_statusPaused => '状态：已暂停';

  @override
  String get queue_statusCompleted => '状态：已完成';

  @override
  String get settings_notification => '音效';

  @override
  String get settings_notificationSound => '完成音效';

  @override
  String get settings_notificationSoundSubtitle => '生成完成时播放提示音效';

  @override
  String get settings_notificationCustomSound => '自定义音效';

  @override
  String get settings_notificationCustomSoundSubtitle => '选择自定义音效文件';

  @override
  String get settings_notificationSelectSound => '选择音效';

  @override
  String get settings_notificationResetSound => '恢复默认';

  @override
  String get categoryConfiguration => '类别配置';

  @override
  String get resetToDefault => '重置为默认';

  @override
  String get resetToDefaultTooltip => '重置为默认配置';

  @override
  String get resetToDefaultConfirmContent => '将恢复官方默认配置。您添加的自定义词组会被保留但禁用。';

  @override
  String get groupEnabled => '词组已启用';

  @override
  String get groupDisabled => '词组已禁用';

  @override
  String get toggleGroupEnabled => '切换词组启用状态';

  @override
  String get diyNotAvailableForDefault => '默认预设不支持 DIY 配置';

  @override
  String get diyNotAvailableHint => '请复制为自定义预设后编辑';

  @override
  String get customGroupDisabledAfterReset => '自定义词组（已禁用）';

  @override
  String get confirmReset => '确认重置';

  @override
  String get alias_hintText => '输入提示词，或使用 <词库名称> 引用词库内容';

  @override
  String get statistics_heatmapLess => '少';

  @override
  String get statistics_heatmapMore => '多';

  @override
  String get statistics_heatmapWeekLabel => '周';

  @override
  String statistics_heatmapActivities(Object count) {
    return '$count 次活动';
  }

  @override
  String get statistics_heatmapNoActivity => '无活动';

  @override
  String get sendToHome_dialogTitle => '发送到主页';

  @override
  String get sendToHome_send => '发送';

  @override
  String get sendToHome_mainPrompt => '发送到主提示词';

  @override
  String get sendToHome_mainPromptSubtitle => '填充到主页的正向提示词输入框';

  @override
  String get sendToHome_mainPromptPipeSubtitle => '发送完整内容到主提示词（包含竖线）';

  @override
  String get sendToHome_smartDecompose => '智能分解';

  @override
  String sendToHome_smartDecomposeSubtitle(Object count) {
    return '主提示词 + $count个角色';
  }

  @override
  String get sendToHome_replaceCharacter => '替换角色提示词';

  @override
  String get sendToHome_replaceCharacterSubtitle => '清空现有角色，添加为新角色';

  @override
  String get sendToHome_appendCharacter => '追加角色提示词';

  @override
  String get sendToHome_appendCharacterSubtitle => '保留现有角色，追加新角色';

  @override
  String get sendToHome_fixedTags => '发送到固定词';

  @override
  String get sendToHome_fixedTagsSubtitle => '追加到固定词列表';

  @override
  String get sendToHome_sendAsAlias => '作为别名发送';

  @override
  String sendToHome_sendAsAliasSubtitle(Object name) {
    return '发送到主页时包装为 <$name>';
  }

  @override
  String get sendToHome_preview => '发送预览';

  @override
  String get sendToHome_characterPrompt => '角色提示词';

  @override
  String sendToHome_characterPromptCount(Object count) {
    return '角色提示词 ($count个)';
  }

  @override
  String sendToHome_characterIndex(Object index) {
    return '角色 $index';
  }

  @override
  String get sendToHome_recommended => '推荐';

  @override
  String get sendToHome_successMainPrompt => '已发送到主提示词';

  @override
  String get sendToHome_successReplaceCharacter => '已替换角色提示词';

  @override
  String get sendToHome_successAppendCharacter => '已追加角色提示词';

  @override
  String get metadataImport_title => '选择要套用的参数';

  @override
  String get metadataImport_promptsSection => '提示词';

  @override
  String get metadataImport_generationSection => '生成参数';

  @override
  String get metadataImport_selectAll => '全选';

  @override
  String get metadataImport_promptsOnly => '仅提示词';

  @override
  String get metadataImport_generationOnly => '仅参数';

  @override
  String get metadataImport_clear => '清空';

  @override
  String get metadataImport_prompt => '正向提示词';

  @override
  String get metadataImport_mainPrompt => '主提示词';

  @override
  String get metadataImport_fixedTags => '固定词';

  @override
  String metadataImport_fixedPrefix(Object text) {
    return '前缀: $text';
  }

  @override
  String metadataImport_fixedSuffix(Object text) {
    return '后缀: $text';
  }

  @override
  String metadataImport_negativeFixedPrefix(Object text) {
    return '负向前缀: $text';
  }

  @override
  String metadataImport_negativeFixedSuffix(Object text) {
    return '负向后缀: $text';
  }

  @override
  String metadataImport_qualityTagsCount(int count) {
    return '质量词 ($count个)';
  }

  @override
  String get metadataImport_negativePrompt => '负向提示词';

  @override
  String get metadataImport_characterPrompts => '多角色提示词';

  @override
  String metadataImport_characterPromptsCount(int count) {
    return '角色提示词 ($count个)';
  }

  @override
  String metadataImport_characterIndex(int index, Object text) {
    return '角色$index: $text';
  }

  @override
  String get metadataImport_referenceSection => '参考图';

  @override
  String metadataImport_countUnit(int count) {
    return '$count个';
  }

  @override
  String metadataImport_preciseReferenceCount(int count) {
    return '精准参考 ($count个)';
  }

  @override
  String metadataImport_vibeDetail(Object name, Object strength, Object info) {
    return '$name (强度 $strength%, 信息提取 $info%)';
  }

  @override
  String metadataImport_preciseReferenceDetail(
    int index,
    Object type,
    Object strength,
    Object fidelity,
  ) {
    return '参考$index: $type (强度 $strength%, 保真 $fidelity%)';
  }

  @override
  String get metadataImport_seed => '种子 (Seed)';

  @override
  String get metadataImport_steps => '步数 (Steps)';

  @override
  String get metadataImport_scale => 'CFG 强度';

  @override
  String get metadataImport_size => '尺寸 (Size)';

  @override
  String get metadataImport_sampler => '采样器 (Sampler)';

  @override
  String get metadataImport_model => '模型 (Model)';

  @override
  String get metadataImport_smea => 'SMEA';

  @override
  String get metadataImport_smeaDyn => 'SMEA Dyn';

  @override
  String get metadataImport_noiseSchedule => '噪声计划';

  @override
  String get metadataImport_cfgRescale => 'CFG 重缩放';

  @override
  String get metadataImport_qualityToggle => '质量标签';

  @override
  String get metadataImport_ucPreset => 'UC 预设';

  @override
  String get metadataImport_noData => '（无数据）';

  @override
  String metadataImport_selectedCount(int count) {
    return '已选择 $count 项';
  }

  @override
  String get metadataImport_noDataFound => '未找到 NovelAI 元数据';

  @override
  String get metadataImport_noParamsSelected => '未选择任何要应用的参数';

  @override
  String metadataImport_appliedCount(int count) {
    return '已应用 $count 项参数';
  }

  @override
  String get metadataImport_appliedTitle => '元数据已应用';

  @override
  String get metadataImport_appliedDescription => '以下参数已应用到当前设置：';

  @override
  String get metadataImport_charactersCount => '个角色';

  @override
  String metadataImport_appliedToMain(int count) {
    return '已应用 $count 项参数到主界面';
  }

  @override
  String get metadataImport_quickSelectHint => '点击上方按钮快速选择参数类型';

  @override
  String get shortcut_context_global => '全局';

  @override
  String get shortcut_context_generation => '生成页面';

  @override
  String get shortcut_context_gallery => '画廊列表';

  @override
  String get shortcut_context_viewer => '图片查看器';

  @override
  String get shortcut_context_tag_library => '词库';

  @override
  String get shortcut_context_random_config => '随机配置';

  @override
  String get shortcut_context_settings => '设置';

  @override
  String get shortcut_context_input => '输入框';

  @override
  String get shortcut_action_navigate_to_generation => '生成页面';

  @override
  String get shortcut_action_navigate_to_local_gallery => '本地画廊';

  @override
  String get shortcut_action_navigate_to_online_gallery => '在线画廊';

  @override
  String get shortcut_action_navigate_to_random_config => '随机配置';

  @override
  String get shortcut_action_navigate_to_tag_library => '词库页面';

  @override
  String get shortcut_action_navigate_to_statistics => '统计页面';

  @override
  String get shortcut_action_navigate_to_settings => '设置页面';

  @override
  String get shortcut_action_generate_image => '生成图像';

  @override
  String get shortcut_action_generation_prev_image => '预览上一张（历史联动）';

  @override
  String get shortcut_action_generation_next_image => '预览下一张（历史联动）';

  @override
  String get shortcut_action_cancel_generation => '取消生成';

  @override
  String get shortcut_action_add_to_queue => '加入队列';

  @override
  String get shortcut_action_random_prompt => '随机提示词';

  @override
  String get shortcut_action_clear_prompt => '清空提示词';

  @override
  String get shortcut_action_toggle_prompt_mode => '切换正/负面模式';

  @override
  String get shortcut_action_open_tag_library => '打开词库';

  @override
  String get shortcut_action_save_image => '保存图像';

  @override
  String get shortcut_action_upscale_image => '放大图像';

  @override
  String get shortcut_action_copy_image => '复制图像';

  @override
  String get shortcut_action_fullscreen_preview => '全屏预览';

  @override
  String get shortcut_action_open_params_panel => '打开参数面板';

  @override
  String get shortcut_action_open_history_panel => '打开历史面板';

  @override
  String get shortcut_action_reuse_params => '复用参数';

  @override
  String get shortcut_action_previous_image => '上一张';

  @override
  String get shortcut_action_next_image => '下一张';

  @override
  String get shortcut_action_zoom_in => '放大';

  @override
  String get shortcut_action_zoom_out => '缩小';

  @override
  String get shortcut_action_reset_zoom => '重置缩放';

  @override
  String get shortcut_action_toggle_fullscreen => '全屏切换';

  @override
  String get shortcut_action_close_viewer => '关闭查看器';

  @override
  String get shortcut_action_toggle_favorite => '收藏切换';

  @override
  String get shortcut_action_copy_prompt => '复制Prompt';

  @override
  String get shortcut_action_reuse_gallery_params => '复用参数';

  @override
  String get shortcut_action_delete_image => '删除图片';

  @override
  String get shortcut_action_previous_page => '上一页';

  @override
  String get shortcut_action_next_page => '下一页';

  @override
  String get shortcut_action_refresh_gallery => '刷新';

  @override
  String get shortcut_action_focus_search => '搜索聚焦';

  @override
  String get shortcut_action_enter_selection_mode => '进入选择模式';

  @override
  String get shortcut_action_open_filter_panel => '打开筛选面板';

  @override
  String get shortcut_action_clear_filter => '清除筛选';

  @override
  String get shortcut_action_toggle_category_panel => '切换分类面板';

  @override
  String get shortcut_action_jump_to_date => '跳转到日期';

  @override
  String get shortcut_action_open_folder => '打开文件夹';

  @override
  String get shortcut_action_select_all_tags => '全选标签';

  @override
  String get shortcut_action_deselect_all_tags => '取消全选';

  @override
  String get shortcut_action_new_category => '新建分类';

  @override
  String get shortcut_action_new_tag => '新建标签';

  @override
  String get shortcut_action_search_tags => '搜索标签';

  @override
  String get shortcut_action_batch_delete_tags => '批量删除标签';

  @override
  String get shortcut_action_batch_copy_tags => '批量复制标签';

  @override
  String get shortcut_action_send_to_home => '发送到首页';

  @override
  String get shortcut_action_exit_selection_mode => '退出选择模式';

  @override
  String get shortcut_action_sync_danbooru => '同步Danbooru';

  @override
  String get shortcut_action_generate_preview => '生成预览';

  @override
  String get shortcut_action_search_presets => '搜索预设';

  @override
  String get shortcut_action_new_preset => '新建预设';

  @override
  String get shortcut_action_duplicate_preset => '复制预设';

  @override
  String get shortcut_action_delete_preset => '删除预设';

  @override
  String get shortcut_action_close_config => '关闭配置';

  @override
  String get shortcut_action_minimize_to_tray => '最小化到托盘';

  @override
  String get shortcut_action_quit_app => '退出应用';

  @override
  String get shortcut_action_show_shortcut_help => '显示快捷键帮助';

  @override
  String get shortcut_action_toggle_queue => '切换队列';

  @override
  String get shortcut_action_toggle_queue_pause => '暂停/继续队列';

  @override
  String get shortcut_action_toggle_theme => '切换主题';

  @override
  String get shortcut_settings_title => '键盘快捷键';

  @override
  String get shortcut_settings_description => '自定义键盘快捷键以便快速访问';

  @override
  String get shortcut_settings_enable => '启用快捷键';

  @override
  String get shortcut_settings_show_badges => '显示快捷键标识';

  @override
  String get shortcut_settings_show_in_tooltips => '在提示中显示';

  @override
  String get shortcut_settings_reset_all => '重置全部为默认';

  @override
  String get shortcut_settings_search => '搜索快捷键...';

  @override
  String get shortcut_settings_no_results => '未找到快捷键';

  @override
  String get shortcut_settings_press_key => '按下按键组合...';

  @override
  String shortcut_settings_conflict(Object action) {
    return '与以下功能冲突: $action';
  }

  @override
  String get shortcut_help_title => '快捷键帮助';

  @override
  String get shortcut_help_search => '搜索快捷键...';

  @override
  String get shortcut_help_all => '全部';

  @override
  String get shortcut_help_tip => '提示：按 F1 或 ? 键可随时打开此帮助对话框';

  @override
  String get shortcut_help_fabTooltip => '快捷键帮助 (F1)';

  @override
  String get shortcut_editor_recordingInline => '按快捷键...';

  @override
  String get shortcut_editor_pressEscToCancel => '按 Esc 取消';

  @override
  String get shortcut_editor_clickToRecord => '点击开始录制';

  @override
  String shortcut_editor_conflictWith(Object action) {
    return '此快捷键与 \"$action\" 冲突';
  }

  @override
  String get drop_dialogTitle => '如何使用这张图片？';

  @override
  String get drop_hint => '拖拽图片到这里';

  @override
  String get drop_img2img => '图生图';

  @override
  String get drop_reversePrompt => '反推';

  @override
  String get drop_vibeTransfer => '风格迁移';

  @override
  String get drop_characterReference => '精准参考';

  @override
  String get drop_unsupportedFormat => '不支持的文件格式';

  @override
  String get drop_addedToImg2Img => '已添加到图生图';

  @override
  String get drop_addedToReversePrompt => '已添加到反推';

  @override
  String get drop_addedToVibe => '已添加到风格迁移';

  @override
  String drop_addedMultipleToVibe(int count) {
    return '已添加 $count 个风格参考';
  }

  @override
  String get drop_addedToCharacterRef => '已添加到精准参考';

  @override
  String get drop_extractMetadata => '提取元数据';

  @override
  String get drop_extractMetadataSubtitle => '读取图片中的 Prompt、Seed 等参数';

  @override
  String get drop_addToQueue => '加入队列';

  @override
  String get drop_addToQueueSubtitle => '提取正面提示词并加入生成队列';

  @override
  String get drop_vibeDetected => '检测到预编码 Vibe（可节省 2 Anlas）';

  @override
  String drop_vibeStrength(Object value) {
    return '强度: $value%';
  }

  @override
  String drop_vibeInfoExtracted(Object value) {
    return '信息提取: $value%';
  }

  @override
  String get drop_reuseVibe => '复用 Vibe';

  @override
  String get drop_reuseVibeSubtitle => '直接使用预编码数据（免费）';

  @override
  String get drop_useAsRawImage => '作为原始图片';

  @override
  String get drop_useAsRawImageSubtitle => '重新编码（消耗 2 Anlas）';

  @override
  String get drop_dragToImg2ImgOrOther => '拖拽到图生图或其他区域';

  @override
  String get preciseRef_title => '精准参考';

  @override
  String get preciseRef_description => '添加参考图并设置类型和参数，可同时使用多个参考。';

  @override
  String get preciseRef_addReference => '添加参考图';

  @override
  String get preciseRef_clearAll => '清空全部';

  @override
  String get preciseRef_remove => '移除';

  @override
  String get preciseRef_referenceType => '参考类型';

  @override
  String get preciseRef_strength => '参考强度';

  @override
  String get preciseRef_fidelity => '保真度';

  @override
  String get preciseRef_v4Only => '此功能需要 V4+ 模型';

  @override
  String get preciseRef_typeCharacter => '角色';

  @override
  String get preciseRef_typeStyle => '风格';

  @override
  String get preciseRef_typeCharacterAndStyle => '角色+风格';

  @override
  String get preciseRef_costHint => '使用精准参考会消耗额外点数';

  @override
  String get preciseRef_costBadge => '消耗点数';

  @override
  String get preciseRef_dropToAdd => '松开后添加精准参考';

  @override
  String get preciseRef_dropNoReadableImage => '拖入源未提供可读取的图片文件或图片链接';

  @override
  String preciseRef_addedCount(int count) {
    return '已添加 $count 个精准参考';
  }

  @override
  String preciseRef_removedCount(int count) {
    return '已删除 $count 个精准参考';
  }

  @override
  String get vibeLibrary_title => 'Vibe 库';

  @override
  String get vibeLibrary_categories => '分类';

  @override
  String get vibeLibrary_createCategoryTitle => '新建分类';

  @override
  String get vibeLibrary_createSubCategoryTitle => '新建子分类';

  @override
  String get vibeLibrary_categoryNameHint => '请输入分类名称';

  @override
  String get vibeLibrary_createCategoryConfirm => '创建';

  @override
  String get vibeLibrary_deleteCategoryTitle => '确认删除';

  @override
  String get vibeLibrary_deleteCategoryContent =>
      '确定要删除此分类吗？分类下的 Vibe 将被移动到未分类。';

  @override
  String get vibeLibrary_sortTooltip => '排序方式';

  @override
  String get vibeLibrary_hideCategoryPanel => '隐藏分类面板';

  @override
  String get vibeLibrary_showCategoryPanel => '显示分类面板';

  @override
  String get vibeLibrary_enterSelectionMode => '进入选择模式';

  @override
  String get vibeLibrary_importTooltip =>
      '导入 Vibe 文件或 PNG/JPG/JPEG/WEBP 图片（右键查看更多选项）';

  @override
  String get vibeLibrary_exportTooltip => '导出 Vibe 到文件';

  @override
  String get vibeLibrary_openFolderTooltip => '打开 Vibe 库文件夹';

  @override
  String get vibeLibrary_refresh => '刷新';

  @override
  String get vibeLibrary_loading => '加载中...';

  @override
  String vibeLibrary_totalCount(Object count) {
    return '共 $count 个 Vibe';
  }

  @override
  String get vibeLibrary_noCategoriesAvailable => '没有可用的分类';

  @override
  String get vibeLibrary_moveToCategory => '移动到分类';

  @override
  String get vibeLibrary_uncategorized => '未分类';

  @override
  String vibeLibrary_movedToCategory(Object count) {
    return '已移动 $count 个 Vibe';
  }

  @override
  String get vibeLibrary_favoriteStatusUpdated => '收藏状态已更新';

  @override
  String get vibeLibrary_importFromFile => '从文件导入';

  @override
  String get vibeLibrary_importFromImage => '从图片导入';

  @override
  String get vibeLibrary_importFromClipboard => '从剪贴板导入编码';

  @override
  String vibeLibrary_openFolderFailed(Object error) {
    return '打开文件夹失败: $error';
  }

  @override
  String get vibeLibrary_importFileDialogTitle => '选择要导入的 Vibe 文件';

  @override
  String get vibeLibrary_preparingImport => '准备导入...';

  @override
  String vibeLibrary_importSuccessCount(Object count) {
    return '成功导入 $count 个 Vibe';
  }

  @override
  String vibeLibrary_importSummary(Object success, Object failed) {
    return '导入完成: $success 成功, $failed 失败';
  }

  @override
  String get vibeLibrary_dropImportHint =>
      '拖拽 .naiv4vibe/.naiv4vibebundle/.png/.jpg/.jpeg/.webp 文件或文件夹到此处导入';

  @override
  String get vibeLibrary_importing => '正在导入...';

  @override
  String vibeLibrary_pageIndicator(Object current, Object total) {
    return '$current / $total 页';
  }

  @override
  String get vibeLibrary_itemsPerPage => '每页:';

  @override
  String get vibeLibrary_tooManyTitle => 'Vibe数量过多';

  @override
  String vibeLibrary_tooManySelectedContent(Object count) {
    return '选中了 $count 个Vibe，但最多只能同时使用16个。\n\n请减少选择数量后再试。';
  }

  @override
  String vibeLibrary_tooManyExistingContent(Object current, Object remaining) {
    return '当前生成页面已有 $current 个Vibe，还可以添加 $remaining 个。\n\n请减少选择数量后再试。';
  }

  @override
  String vibeLibrary_sentToGenerationCount(Object count) {
    return '已发送 $count 个Vibe到生成页面';
  }

  @override
  String vibeLibrary_deleteSelectedContent(Object count) {
    return '确定要删除选中的 $count 个Vibe吗？此操作无法撤销。';
  }

  @override
  String vibeLibrary_deletedCount(Object count) {
    return '已删除 $count 个Vibe';
  }

  @override
  String get vibeLibrary_importImageDialogTitle => '选择包含 Vibe 的图片';

  @override
  String get vibeLibrary_clipboardEmpty => '剪贴板为空';

  @override
  String get vibeLibrary_encodeTimeout => '编码超时，请检查网络连接';

  @override
  String get vibeLibrary_unknownError => '未知错误';

  @override
  String get vibeLibrary_save => '保存到库';

  @override
  String get vibeLibrary_import => '导入 Vibe';

  @override
  String get vibeLibrary_searchHint => '搜索名称、标签...';

  @override
  String get vibeLibrary_empty => 'Vibe 库为空';

  @override
  String get vibeLibrary_emptyHint => '先去 Vibe 库添加一些条目吧';

  @override
  String get vibeLibrary_allVibes => '全部 Vibe';

  @override
  String get vibeLibrary_favorites => '收藏';

  @override
  String get vibeLibrary_sendToGeneration => '发送到生成';

  @override
  String get vibeLibrary_export => '导出';

  @override
  String get vibeLibrary_edit => '编辑';

  @override
  String get vibeLibrary_delete => '删除';

  @override
  String get vibeLibrary_addToFavorites => '收藏';

  @override
  String get vibeLibrary_removeFromFavorites => '取消收藏';

  @override
  String get vibeLibrary_newSubCategory => '新建子分类';

  @override
  String get vibeLibrary_maxVibesReached => '已达到最大数量 (16张)';

  @override
  String get vibeLibrary_bundleReadFailed => '读取 Bundle 文件失败，使用单文件模式';

  @override
  String categoryError_loadFailed(String error) {
    return '加载分类失败：$error';
  }

  @override
  String categoryError_syncFailed(String error) {
    return '同步分类失败：$error';
  }

  @override
  String get categoryError_nameEmpty => '分类名称不能为空';

  @override
  String get categoryError_parentNotFound => '父分类不存在';

  @override
  String categoryError_createFailed(String error) {
    return '创建分类失败：$error';
  }

  @override
  String get categoryError_notFound => '分类不存在';

  @override
  String categoryError_renameFailed(String error) {
    return '重命名分类失败：$error';
  }

  @override
  String get categoryError_invalidMove => '不能将分类移动到它的子孙分类下';

  @override
  String categoryError_moveFailed(String error) {
    return '移动分类失败：$error';
  }

  @override
  String get categoryError_hasSubcategories => '该分类包含子分类，请先删除子分类。';

  @override
  String categoryError_deleteFailed(String error) {
    return '删除分类失败：$error';
  }

  @override
  String categoryError_moveImageFailed(String error) {
    return '移动图片失败：$error';
  }

  @override
  String categoryError_moveImagesFailed(String error) {
    return '批量移动图片失败：$error';
  }

  @override
  String categoryError_reorderFailed(String error) {
    return '重新排序分类失败：$error';
  }

  @override
  String get vibeBulk_titleDelete => '批量删除';

  @override
  String get vibeBulk_titleMove => '批量移动';

  @override
  String get vibeBulk_titleToggleFavorite => '批量更新收藏';

  @override
  String get vibeBulk_titleAddTags => '批量添加标签';

  @override
  String get vibeBulk_titleRemoveTags => '批量移除标签';

  @override
  String get vibeBulk_titleExport => '批量导出';

  @override
  String get vibeBulk_titleImport => '批量导入';

  @override
  String vibeBulk_processingProgress(int current, int total) {
    return '正在处理：$current / $total';
  }

  @override
  String get vibeBulk_completed => '操作完成';

  @override
  String get vibeBulk_completedWithFailures => '操作完成（部分失败）';

  @override
  String get vibeBulk_successful => '成功';

  @override
  String get vibeBulk_failed => '失败';

  @override
  String get vibeBulk_errorDetails => '错误详情：';

  @override
  String vibeBulk_moreErrors(int count) {
    return '……另有 $count 个错误';
  }

  @override
  String get vibeBulk_operationFailed => '操作失败';

  @override
  String get vibeBulk_operationFailedHint => '请检查操作设置后重试。';

  @override
  String vibeBulk_errorEntryNotFoundOrDeleteFailed(String item) {
    return '未找到 $item 或删除失败';
  }

  @override
  String vibeBulk_errorDeleteFailed(String item, String error) {
    return '删除 $item 失败：$error';
  }

  @override
  String vibeBulk_errorEntryNotFound(String item) {
    return '未找到条目：$item';
  }

  @override
  String vibeBulk_errorMoveFailed(String item, String error) {
    return '移动 $item 失败：$error';
  }

  @override
  String vibeBulk_errorFavoriteFailed(String item) {
    return '更新收藏状态失败：$item';
  }

  @override
  String vibeBulk_errorFavoriteFailedWithDetails(String item, String error) {
    return '更新 $item 的收藏状态失败：$error';
  }

  @override
  String vibeBulk_errorAddTagsFailed(String item) {
    return '添加标签失败：$item';
  }

  @override
  String vibeBulk_errorAddTagsFailedWithDetails(String item, String error) {
    return '为 $item 添加标签失败：$error';
  }

  @override
  String vibeBulk_errorRemoveTagsFailed(String item) {
    return '移除标签失败：$item';
  }

  @override
  String vibeBulk_errorRemoveTagsFailedWithDetails(String item, String error) {
    return '从 $item 移除标签失败：$error';
  }

  @override
  String get vibeBulk_errorExportNoFile => '导出失败：未创建文件';

  @override
  String vibeBulk_errorExportFailed(String error) {
    return '导出失败：$error';
  }

  @override
  String vibeBulk_errorFileNotFound(String item) {
    return '未找到文件：$item';
  }

  @override
  String vibeBulk_errorNoVibeData(String item) {
    return '$item 中没有有效的 Vibe 数据';
  }

  @override
  String vibeBulk_errorImportFailed(String item, String error) {
    return '从 $item 导入 Vibe 失败：$error';
  }

  @override
  String vibeBulk_errorProcessFileFailed(String item, String error) {
    return '处理 $item 失败：$error';
  }

  @override
  String get vibeBulkTag_title => '批量编辑标签';

  @override
  String vibeBulkTag_selectedCount(int count) {
    return '已选中 $count 个 Vibe';
  }

  @override
  String get vibeBulkTag_inputHint => '输入新标签……';

  @override
  String get vibeBulkTag_noTags => '暂无标签';

  @override
  String get vibeBulkTag_noTagsHint => '添加标签以方便筛选和管理';

  @override
  String vibeBulkTag_currentTags(int count) {
    return '当前标签（$count）';
  }

  @override
  String vibeBulkTag_pendingRemoval(int count) {
    return '待移除标签（$count）';
  }

  @override
  String get vibeBulkTag_removeTag => '移除标签';

  @override
  String get vibeBulkTag_actionPreview => '操作预览';

  @override
  String vibeBulkTag_addTagsSummary(String tags) {
    return '添加标签：$tags';
  }

  @override
  String vibeBulkTag_removeTagsSummary(String tags) {
    return '移除标签：$tags';
  }

  @override
  String get vibeBulkTag_noChanges => '没有要应用的更改';

  @override
  String get vibeBulkCategory_title => '选择目标分类';

  @override
  String vibeBulkCategory_moveCount(int count) {
    return '将 $count 个 Vibe 移动到：';
  }

  @override
  String get vibeBulkCategory_cannotMoveToCurrent => '不能移动到当前所在分类';

  @override
  String get vibeDetail_strengthDescription => '控制 Vibe 对生成结果的影响强度';

  @override
  String get vibeDetail_infoExtractedDescription => '控制从原图提取的信息量（消耗 2 Anlas）';

  @override
  String get vibeDetail_statistics => '统计信息';

  @override
  String get vibeDetail_usageCount => '使用次数';

  @override
  String vibeDetail_timesUsed(int count) {
    return '$count 次';
  }

  @override
  String get vibeDetail_lastUsed => '最后使用';

  @override
  String get vibeDetail_neverUsed => '从未使用';

  @override
  String get vibeDetail_createdAt => '创建时间';

  @override
  String get vibeDetail_saveParameters => '保存参数';

  @override
  String get vibe_export_title => '导出 Vibe';

  @override
  String get vibe_export_format => '导出格式';

  @override
  String get vibe_selector_title => '选择 Vibe';

  @override
  String get vibe_selector_recent => '最近使用';

  @override
  String get vibe_category_add => '添加分类';

  @override
  String get vibe_category_rename => '重命名分类';

  @override
  String get drop_vibe_detected => '检测到 Vibe 图片';

  @override
  String drop_save_anlas(int cost) {
    return '节省 $cost Anlas';
  }

  @override
  String get vibe_export_include_thumbnails => '包含缩略图';

  @override
  String get vibe_export_include_thumbnails_subtitle => '导出文件中包含缩略图预览';

  @override
  String get vibe_export_singleFile => '单文件 (.naiv4vibe)';

  @override
  String get vibe_export_singleFileDescription =>
      '将每个 Vibe 导出为单独文件，适合分享单个 Vibe';

  @override
  String get vibe_export_bundleFile => '打包文件 (.naiv4vibebundle)';

  @override
  String get vibe_export_bundleFileDescription => '将多个 Vibe 打包到一个文件中，适合批量备份';

  @override
  String get vibe_export_embedIntoPng => '嵌入到 PNG';

  @override
  String get vibe_export_embedIntoPngDescription => '通过写入 PNG 元数据导出单个 Vibe';

  @override
  String get vibe_export_exportable => '可导出';

  @override
  String get vibe_export_notExportable => '不可导出';

  @override
  String get vibe_export_selectVibesToExport => '选择要导出的 Vibe';

  @override
  String vibe_export_exportSelected(int count) {
    return '导出 ($count)';
  }

  @override
  String vibe_export_strengthPercent(int percent) {
    return '强度: $percent%';
  }

  @override
  String get vibe_export_pngCarrierImage => 'PNG 载体图片';

  @override
  String get vibe_export_noUsablePngCarrier =>
      '这个 Vibe 没有可直接使用的 PNG 载体图片。你可以选择外部 PNG 图片作为载体。';

  @override
  String get vibe_export_selectExternalPngImage => '选择外部 PNG 图片...';

  @override
  String get vibe_export_changeExternalPngImage => '更换外部 PNG 图片...';

  @override
  String get vibe_export_useVibeImageInstead => '改用 Vibe 图片';

  @override
  String vibe_export_usingExternalPng(String fileName) {
    return '正在使用外部 PNG: $fileName';
  }

  @override
  String get vibe_export_selectPngImage => '选择 PNG 图片';

  @override
  String get vibe_export_invalidPngImage => '所选文件不是有效的 PNG 图片';

  @override
  String vibe_export_selectPngImageFailed(String error) {
    return '选择 PNG 图片失败: $error';
  }

  @override
  String vibe_export_embeddingPng(String name) {
    return '正在嵌入 PNG: $name';
  }

  @override
  String vibe_export_exportCompleteCounts(int successCount, int failCount) {
    return '导出完成: 成功 $successCount 个，失败 $failCount 个';
  }

  @override
  String vibe_export_exportCompletePath(String path) {
    return '导出完成: $path';
  }

  @override
  String vibe_export_packingVibes(int count) {
    return '正在打包 $count 个 Vibe...';
  }

  @override
  String vibe_export_exportingName(String name) {
    return '正在导出: $name';
  }

  @override
  String get vibe_export_selectExportFolder => '选择导出文件夹';

  @override
  String get vibe_export_generatingBundleFile => '正在生成打包文件...';

  @override
  String vibe_export_bundleTitle(String name) {
    return '导出 Bundle: $name';
  }

  @override
  String vibe_export_vibesTitle(int count) {
    return '导出 Vibe ($count 个已选)';
  }

  @override
  String get vibe_export_method => '导出方式';

  @override
  String get vibe_export_wholeBundle => '整个 Bundle';

  @override
  String get vibe_export_internalVibe => '内部 Vibe';

  @override
  String vibe_export_wholeBundleDescription(int count) {
    return '导出包含全部 $count 个 Vibe 的 .naiv4vibebundle 文件';
  }

  @override
  String vibe_export_internalVibeDescription(int count) {
    return '选择 Bundle 内部 Vibe，分别导出为 .naiv4vibe 文件 (共 $count 个)';
  }

  @override
  String get vibe_export_exportBundle => '导出 Bundle';

  @override
  String get vibe_export_exportAsFiles => '导出为文件';

  @override
  String get vibe_export_exportBundleDescription => '导出为 .naiv4vibebundle 文件';

  @override
  String get vibe_export_exportAsFilesDescription =>
      '导出为 .naiv4vibe 或 .naiv4vibebundle 文件';

  @override
  String get vibe_export_exportAsZip => '导出为 ZIP';

  @override
  String get vibe_export_exportAsZipDescription =>
      '将选中的 Vibe 库条目作为独立文件打包为 .zip';

  @override
  String get vibe_export_compressData => '压缩数据';

  @override
  String get vibe_export_compressDataDescription => '使用压缩以减小文件大小 (推荐用于批量导出)';

  @override
  String get vibe_export_zipCompressDescription => '压缩 ZIP 内的文件以减小体积';

  @override
  String get vibe_export_exportAsPng => '导出为 PNG';

  @override
  String get vibe_export_pngInternalBundleUnsupported =>
      '导出单个 Bundle 内部 Vibe 时不支持嵌入图片';

  @override
  String get vibe_export_embedVibeDataIntoPng => '将 Vibe 数据写入 PNG 元数据';

  @override
  String get vibe_export_batchPngUsesFirstImage =>
      '批量导出会使用每个 Vibe 的第一张可用图片，没有图片的条目会自动跳过。';

  @override
  String get vibe_export_exportCarrierImage => '导出载体图片';

  @override
  String get vibe_export_usingExternalCarrierImage => '正在使用外部 PNG 作为导出载体图片';

  @override
  String get vibe_export_exportAsEncodings => '导出为编码';

  @override
  String get vibe_export_exportAsEncodingsDescription =>
      '将数据导出为编码 (JSON 或 Base64)';

  @override
  String get vibe_export_jsonDescription => '导出为格式化 JSON 文件，便于阅读和编辑';

  @override
  String get vibe_export_base64Description => '导出为纯 Base64，便于复制和分享';

  @override
  String get vibe_export_selectAtLeastOneMethod => '请选择至少一种导出方式';

  @override
  String get vibe_export_batchPngUnsupported =>
      '批量 Vibe 导出不支持嵌入 PNG。请使用单个 Vibe 导出界面。';

  @override
  String get vibe_export_selectPngCarrier => '请选择用于导出的 PNG 载体图片';

  @override
  String get vibe_export_selectAtLeastOneInternalVibe => '请选择至少一个内部 Vibe';

  @override
  String get vibe_export_selectVibeExportFolder => '选择 Vibe 导出文件夹';

  @override
  String get vibe_export_saveEncodingFile => '保存编码文件';

  @override
  String get vibe_export_preparingExport => '正在准备导出...';

  @override
  String vibe_export_preparingVibeProgress(int current, int total) {
    return '正在读取 Vibe $current/$total...';
  }

  @override
  String get vibe_export_exportingBundle => '正在导出 Bundle...';

  @override
  String get vibe_export_exportingZip => '正在导出 ZIP...';

  @override
  String get vibe_export_embeddingImage => '正在嵌入图片...';

  @override
  String get vibe_export_exportingEncoding => '正在导出编码...';

  @override
  String vibe_export_exportFailedWithError(String error) {
    return '导出失败: $error';
  }

  @override
  String get vibe_export_noExportableEntries => '没有可导出的 Vibe 条目';

  @override
  String get vibe_export_bundleFilePathEmpty => 'Bundle 文件路径为空';

  @override
  String vibe_export_invalidImageFormatWithError(String error) {
    return '无效的图片格式: $error';
  }

  @override
  String vibe_export_embedFailedWithError(String error) {
    return '嵌入失败: $error';
  }

  @override
  String vibe_export_embedImageFailedWithError(String error) {
    return '嵌入图片失败: $error';
  }

  @override
  String vibe_export_extractingVibeProgress(int current, int total) {
    return '正在提取 Vibe $current/$total...';
  }

  @override
  String vibe_export_selectImageFailed(String error) {
    return '选择图片失败: $error';
  }

  @override
  String vibe_export_dialogTitle(int count) {
    return '导出 $count 个 Vibes';
  }

  @override
  String get vibe_export_chooseMethod => '选择导出方式';

  @override
  String get vibe_export_asBundle => '打包导出';

  @override
  String get vibe_export_individually => '逐个导出';

  @override
  String get vibe_export_noData => '没有可导出的数据';

  @override
  String get vibe_export_success => '导出成功';

  @override
  String get vibe_export_failed => '导出失败';

  @override
  String vibe_export_skipped(int count) {
    return '跳过了 $count 个无数据 vibes';
  }

  @override
  String vibe_export_bundleSuccess(int count) {
    return '已导出 Bundle: $count 个 vibes';
  }

  @override
  String get vibe_export_selectToEmbed => '选择要嵌入的 vibes';

  @override
  String get vibe_export_pngRequired => '需要 PNG 文件';

  @override
  String get vibe_export_noEmbeddableData => '没有可嵌入的数据';

  @override
  String vibe_export_embedSuccess(int count) {
    return '已嵌入 $count 个 vibes 到图片';
  }

  @override
  String get vibe_export_embedFailed => '嵌入失败';

  @override
  String get vibe_embedToImage => '嵌入到图片';

  @override
  String get vibe_import_skip => '跳过';

  @override
  String get vibe_import_confirm => '确认';

  @override
  String get vibe_import_noEncodingData => '无编码数据';

  @override
  String get vibe_import_encodingCost => '编码将消耗 2 Anlas';

  @override
  String get vibe_import_confirmCost => '继续并消耗 Anlas？';

  @override
  String get vibe_import_encodeNow => '立即编码 (2 Anlas)';

  @override
  String get vibe_addImageOnly => '仅添加图片';

  @override
  String get vibe_import_autoSave => '自动保存到库';

  @override
  String get vibe_import_encodingFailed => '编码失败';

  @override
  String get vibe_import_encodingFailedMessage => 'Vibe 编码失败，是否继续添加未编码图片？';

  @override
  String get vibe_import_encodingInProgress => '编码中...';

  @override
  String get vibe_import_encodingComplete => '编码完成';

  @override
  String get vibe_import_partialFailed => '部分编码失败';

  @override
  String get vibe_import_timeout => '编码超时';

  @override
  String get vibe_import_title => '从库导入';

  @override
  String vibe_import_result(int count) {
    return '已导入 $count 个 vibes';
  }

  @override
  String get vibe_import_fileParseFailed => '解析文件失败';

  @override
  String get vibe_import_fileSelectionFailed => '文件选择失败';

  @override
  String get vibe_import_importFailed => '导入失败';

  @override
  String vibe_import_failedWithError(String error) {
    return '导入失败: $error';
  }

  @override
  String get vibe_import_bundleTitle => '导入 Vibe Bundle';

  @override
  String get vibe_import_bundleChooseMethod => '选择导入方式';

  @override
  String get vibe_import_bundleAsWhole => '作为整体导入';

  @override
  String get vibe_import_bundleAsWholeDescription => '保留 Bundle 结构，并作为一个库条目导入';

  @override
  String get vibe_import_bundleSplitEntries => '拆分为独立条目';

  @override
  String get vibe_import_bundleSplitEntriesDescription => '将每个 Vibe 作为独立库条目导入';

  @override
  String get vibe_import_bundleSelectVibes => '选择要导入的 Vibe';

  @override
  String get vibe_import_bundleSelectVibesDescription => '仅导入选中的 Vibe';

  @override
  String get vibe_import_bundleConfigureEachVibe => '配置每个 Vibe 的参数';

  @override
  String get vibe_import_bundleSelectAndConfigureEachVibe => '选择并配置每个 Vibe 的参数';

  @override
  String vibe_import_bundleSelectedCount(int selected, int total) {
    return '已选择 $selected/$total';
  }

  @override
  String get vibe_saveToLibrary_title => '保存到库';

  @override
  String get vibe_saveToLibrary_strength => '参考强度';

  @override
  String get vibe_saveToLibrary_infoExtracted => '信息提取';

  @override
  String vibe_saveToLibrary_saving(int count) {
    return '正在保存 $count 个 vibes';
  }

  @override
  String get vibe_saveToLibrary_saveFailed => '保存到库失败';

  @override
  String vibe_saveToLibrary_savingCount(int count) {
    return '正在保存 $count 个 vibes';
  }

  @override
  String get vibe_saveToLibrary_nameLabel => '名称';

  @override
  String get vibe_saveToLibrary_nameHint => '输入 vibe 名称';

  @override
  String vibe_saveToLibrary_mixed(int saved, int reused) {
    return '已保存 $saved 个，复用 $reused 个';
  }

  @override
  String vibe_saveToLibrary_saved(int count) {
    return '已保存 $count 个到库';
  }

  @override
  String vibe_saveToLibrary_reused(int count) {
    return '从库复用 $count 个';
  }

  @override
  String get vibe_saveToLibrary_saveAsBundle => '保存为 Bundle';

  @override
  String vibe_saveToLibrary_saveAsBundleDescription(int count) {
    return '将 $count 个 Vibe 保存为一个 Bundle';
  }

  @override
  String get vibe_saveToLibrary_tagHint => '输入标签后点击添加';

  @override
  String get vibe_maxReached => '已达到最大数量 (16张)';

  @override
  String get vibe_maxReachedRemoveSome => '已达到最大数量 (16张)，请先移除一些 Vibe';

  @override
  String vibe_addedNamed(String name) {
    return '已添加 Vibe: $name';
  }

  @override
  String vibe_addedCount(int count) {
    return '已添加 $count 个 vibes';
  }

  @override
  String get vibe_statusEncoded => '已编码';

  @override
  String get vibe_statusEncoding => '编码中...';

  @override
  String get vibe_statusPendingEncode => '待编码 (2 Anlas)';

  @override
  String get vibe_encodeDialogTitle => '确认编码 Vibe';

  @override
  String get vibe_encodeDialogMessage => '是否编码此图片以供生成使用？';

  @override
  String get vibe_encodeCostWarning => '此操作将消耗 2 Anlas（点数）';

  @override
  String get vibe_encodeButton => '编码';

  @override
  String get vibe_encodeSuccess => 'Vibe 编码成功！';

  @override
  String get vibe_encodeFailed => 'Vibe 编码失败，请重试';

  @override
  String vibe_encodeError(String error) {
    return '编码失败: $error';
  }

  @override
  String get bundle_internalVibes => '内部 Vibes';

  @override
  String get shortcuts_customize => '自定义快捷键';

  @override
  String get gallery_send_to => '发送到';

  @override
  String get image_editor_select_tool => '选择工具';

  @override
  String get selection_clear_selection => '清除选区';

  @override
  String get selection_invert_selection => '反转选区';

  @override
  String get selection_cut_to_layer => '剪切到新图层';

  @override
  String get search_results => '搜索结果';

  @override
  String get search_noResults => '未找到匹配结果';

  @override
  String get addToCurrent => '添加到当前';

  @override
  String get replaceExisting => '替换现有';

  @override
  String get confirmSelection => '确认选择';

  @override
  String get selectAll => '全选';

  @override
  String get clearSelection => '清空';

  @override
  String get clearFilters => '清除筛选';

  @override
  String get shortcut_context_vibe_detail => 'Vibe 详情';

  @override
  String get shortcut_action_vibe_detail_rename => '重命名';

  @override
  String get shortcut_action_vibe_detail_toggle_favorite => '切换收藏';

  @override
  String get shortcut_action_vibe_detail_prev_sub_vibe => '上一个子 Vibe';

  @override
  String get shortcut_action_vibe_detail_next_sub_vibe => '下一个子 Vibe';

  @override
  String get vibeSelectorFilterFavorites => '收藏';

  @override
  String get vibeSelectorFilterSourceAll => '全部类型';

  @override
  String get vibeSelectorSortCreated => '创建时间';

  @override
  String get vibeSelectorSortLastUsed => '最近使用';

  @override
  String get vibeSelectorSortUsedCount => '使用次数';

  @override
  String get vibeSelectorSortName => '名称';

  @override
  String vibeSelectorItemsCount(int count) {
    return '$count 项';
  }

  @override
  String get tray_show => '显示窗口';

  @override
  String get tray_exit => '退出';

  @override
  String get settings_shortcutsSubtitle => '自定义键盘快捷键';

  @override
  String get settings_openFolder => '打开文件夹';

  @override
  String get settings_openFolderFailed => '打开文件夹失败';

  @override
  String get settings_dataSourceCacheTitle => '数据源缓存管理';

  @override
  String get settings_pleaseLoginFirst => '请先登录';

  @override
  String get settings_accountNotFound => '未找到账号信息';

  @override
  String get settings_goToLoginPage => '请前往登录页面';

  @override
  String settings_retryIntervalDisplay(String interval) {
    return '$interval 秒';
  }

  @override
  String get settings_vibePathSaved => 'Vibe 库路径已保存';

  @override
  String get settings_selectFolderFailed => '选择文件夹失败';

  @override
  String get settings_hivePathSaved => '数据存储路径已保存，重启后生效';

  @override
  String get settings_restartRequiredTitle => '需要重启应用';

  @override
  String get settings_changePathConfirm =>
      '更改数据存储路径后，需要重启应用才能生效。\\n\\n新路径将在下次启动时生效。是否继续？';

  @override
  String get settings_resetPathConfirm =>
      '重置数据存储路径后，需要重启应用才能生效。\\n\\n默认路径将在下次启动时生效。是否继续？';

  @override
  String get settings_kritaBridgeTitle => 'Krita Bridge';

  @override
  String get settings_kritaBridgeEnable => '启用 Krita 本地桥接';

  @override
  String get settings_kritaBridgeDisabledText => '默认关闭；开启后只监听本机 127.0.0.1';

  @override
  String get settings_kritaBridgeStartingText => '正在启动本地桥接服务...';

  @override
  String get settings_kritaBridgeListeningText => '等待 Krita 插件连接';

  @override
  String get settings_kritaBridgeConnectedText => 'Krita 插件已连接';

  @override
  String get settings_kritaBridgeErrorText => '启动失败，请查看错误信息';

  @override
  String get settings_kritaBridgeDisabled => '已关闭';

  @override
  String get settings_kritaBridgeStarting => '启动中';

  @override
  String get settings_kritaBridgeListening => '监听中';

  @override
  String get settings_kritaBridgeConnected => '已连接';

  @override
  String get settings_kritaBridgeError => '错误';

  @override
  String get settings_kritaBridgeRegenerateSession => '重生成会话';

  @override
  String get settings_kritaBridgeDiscoveryFile => '发现文件';

  @override
  String get settings_kritaBridgeWaitingEndpoint => '等待本地 WebSocket 监听';

  @override
  String settings_kritaBridgeClient(Object client) {
    return '客户端：$client';
  }

  @override
  String get settings_fontScale => '字体大小';

  @override
  String get settings_fontScale_description => '调整应用全局字体缩放比例';

  @override
  String get settings_fontScale_previewSmall => '落霞与孤鹜齐飞';

  @override
  String get settings_fontScale_previewMedium => '秋水共长天一色';

  @override
  String get settings_fontScale_previewLarge => '字体大小预览';

  @override
  String get settings_fontScale_reset => '重置';

  @override
  String get settings_fontScale_done => '完成';

  @override
  String get settings_generationLayout => '生成页布局';

  @override
  String get settings_generationLayout_classic => '经典布局';

  @override
  String get settings_generationLayout_classicDescription => '参数在左侧，提示词位于预览区上方';

  @override
  String get settings_generationLayout_webStyle => '官网式布局';

  @override
  String get settings_generationLayout_webStyleDescription =>
      '提示词与设置固定在最左栏，类似 NovelAI 官网';

  @override
  String get settings_historyClickBehavior => '历史记录点击行为';

  @override
  String get settings_historyClickBehavior_classic => '经典';

  @override
  String get settings_historyClickBehavior_classicDescription => '单击历史图片直接打开详情';

  @override
  String get settings_historyClickBehavior_linked => '官网式联动';

  @override
  String get settings_historyClickBehavior_linkedDescription =>
      '单击切换中央预览，双击或长按打开详情，并支持左右方向键浏览';

  @override
  String get image_viewDetail => '查看详情';

  @override
  String get settings_defaultImagesPath =>
      '默认 (Documents/NAI_Launcher/images/)';

  @override
  String settings_defaultVibePath(Object path) {
    return '$path (默认)';
  }

  @override
  String get settings_defaultHivePath => '默认 (%APPDATA%/NAI_Launcher/hive/)';

  @override
  String get settings_protectionMode => '保护模式';

  @override
  String get settings_protectionModeSubtitle =>
      '开启后按下方子项保护本地资产、分享副本、高消耗和高频生图操作；关闭时保留子项配置但不生效。';

  @override
  String get settings_protectionFeatures => '保护功能';

  @override
  String get settings_stripMetadataTitle => '复制/拖拽时移除全部元数据';

  @override
  String get settings_stripMetadataSubtitle =>
      '生成净化副本，清除 PNG 文本块、EXIF 与 NAI 隐写水印，并避免拖拽暴露原始路径。';

  @override
  String get settings_confirmDangerousActionsTitle => '危险资产操作二次确认';

  @override
  String get settings_confirmDangerousActionsSubtitle =>
      '删除、移动、批量移动等本地资产操作会额外弹出保护确认。';

  @override
  String get settings_warnExternalImageSendTitle => '发送到外部服务前提示';

  @override
  String get settings_warnExternalImageSendSubtitle =>
      '把本地图片发送到 LLM、NovelAI、ComfyUI 等外部边界前进行确认。';

  @override
  String get settings_preventOverwriteTitle => '导出时避免覆盖已有文件';

  @override
  String get settings_preventOverwriteSubtitle => '导出/打包路径重名时自动编号，避免误覆盖原有资产。';

  @override
  String get settings_warnHighAnlasCostTitle => 'Anlas 高消耗警告';

  @override
  String settings_warnHighAnlasCostSubtitle(Object threshold) {
    return '单次生成预计消耗达到 $threshold Anlas 时，生成前弹出确认。';
  }

  @override
  String get settings_highAnlasCostThresholdTitle => 'Anlas 警告阈值';

  @override
  String get settings_setHighAnlasCostThresholdTitle => '设置 Anlas 警告阈值';

  @override
  String get settings_threshold => '阈值';

  @override
  String get settings_highAnlasCostThresholdHelper => '当单次生成预计消耗达到或超过该值时弹出确认。';

  @override
  String get settings_limitGenerationIntervalTitle => '限制生图频率';

  @override
  String get settings_limitGenerationIntervalSubtitle =>
      '开启后，两次生图开始时间必须至少间隔设定秒数；冷却期间生图按钮不可点击。';

  @override
  String get settings_generationIntervalTitle => '生图间隔';

  @override
  String settings_generationIntervalValue(Object seconds) {
    return '$seconds 秒';
  }

  @override
  String get settings_setGenerationIntervalTitle => '设置生图间隔';

  @override
  String get settings_generationIntervalHelper => '可设置 1–3600 秒，从开始执行生图时计时。';

  @override
  String get settings_selectLocalOnnxTaggerFolder => '选择 ONNX tagger 模型文件夹';

  @override
  String get settings_localOnnxTaggerFolderSaved => 'ONNX tagger 模型文件夹已保存';

  @override
  String get settings_localOnnxTaggerFolder => '本地 ONNX tagger 模型文件夹';

  @override
  String get settings_notConfigured => '未配置';

  @override
  String get settings_confirmExternalSendTitle => '保护模式：确认外部发送';

  @override
  String settings_confirmExternalSendContent(Object count, Object target) {
    return '即将把 $count 张本地图片发送到 $target。图片会离开本地应用边界，请确认这符合你的预期。';
  }

  @override
  String get settings_confirmExternalSend => '确认发送';

  @override
  String get settings_highAnlasCostTitle => '保护模式：Anlas 消耗较高';

  @override
  String settings_highAnlasCostContent(Object cost, Object threshold) {
    return '本次预计消耗 $cost Anlas，已达到或超过你设置的 $threshold Anlas 警告阈值。请确认是否继续生成。';
  }

  @override
  String get settings_continueGeneration => '继续生成';

  @override
  String get dataSource_clearingData => '正在清除数据...';

  @override
  String get dataSource_clearTitle => '清除标签数据源';

  @override
  String get dataSource_clearContent =>
      '确定要清除 Danbooru 标签补全数据吗？\n\n这将清空以下数据：\n- Danbooru 标签补全数据\n\n以下数据将保留：\n- 中英文标签翻译\n- 标签共现关系\n\n清除后下次启动时将自动重新加载标签数据。';

  @override
  String get dataSource_confirmClear => '确认清除';

  @override
  String dataSource_clearSuccess(Object count) {
    return '已清除 $count 条数据，下次启动时将自动恢复';
  }

  @override
  String get dataSource_clearFailed => '清除失败';

  @override
  String dataSource_clearFailedWithError(Object error) {
    return '清除失败: $error';
  }

  @override
  String get dataSource_clearTagAutocompleteData => '清除标签补全数据';

  @override
  String get dataSource_ready => '数据源已就绪';

  @override
  String get dataSource_notLoaded => '数据源未加载';

  @override
  String dataSource_cachedTagCount(Object count) {
    return '已缓存 $count 个标签';
  }

  @override
  String get dataSource_clickSyncToDownload => '点击“立即同步”下载标签数据';

  @override
  String dataSource_translationCount(Object count) {
    return '$count 翻译';
  }

  @override
  String dataSource_cooccurrenceCount(Object count) {
    return '$count 共现';
  }

  @override
  String dataSource_lastUpdated(Object time) {
    return '上次更新: $time';
  }

  @override
  String get dataSource_heatThresholdTitle => '热度阈值';

  @override
  String get dataSource_heatThresholdSubtitle => '选择不同类别标签的热度阈值';

  @override
  String get dataSource_autoRefreshInterval => '自动刷新间隔';

  @override
  String get dataSource_syncNow => '立即同步';

  @override
  String get dataSource_cancelSync => '取消同步';

  @override
  String get dataSource_syncingTags => '正在同步标签数据...';

  @override
  String dataSource_loadFailed(Object error) {
    return '加载失败: $error';
  }

  @override
  String get dataSource_hotAll => '全部';

  @override
  String get dataSource_hot10k => '热门 >10K';

  @override
  String get dataSource_common1k => '常用 >1K';

  @override
  String get dataSource_common500 => '常用 >500';

  @override
  String get dataSource_normal100 => '一般 >100';

  @override
  String get dataSource_minimal50 => '少量 >50';

  @override
  String get dataSource_custom => '自定义';

  @override
  String get dataSource_refresh7Days => '7天';

  @override
  String get dataSource_refresh15Days => '15天';

  @override
  String get dataSource_refresh30Days => '30天';

  @override
  String get dataSource_refreshNever => '不自动刷新';

  @override
  String get settings_comfyUiEnable => '启用 ComfyUI 集成';

  @override
  String get settings_comfyUiDisabledSubtitle => '关闭后将隐藏本地超分等 ComfyUI 功能';

  @override
  String get settings_comfyUiServerUrl => '服务器地址';

  @override
  String get settings_comfyUiConnectionSuccess => '连接成功';

  @override
  String get settings_comfyUiConnectionSuccessFull => 'ComfyUI 连接成功';

  @override
  String settings_comfyUiConnectionFailed(Object error) {
    return '连接失败: $error';
  }

  @override
  String get settings_comfyUiConnected => '已连接';

  @override
  String get settings_comfyUiDisconnect => '断开';

  @override
  String get settings_comfyUiWorkflowManagement => '工作流管理';

  @override
  String get settings_comfyUiBuiltinWorkflows => '内置工作流';

  @override
  String get settings_comfyUiCustomWorkflows => '自定义工作流';

  @override
  String get settings_comfyUiNoCustomWorkflows =>
      '暂无自定义工作流，点击“导入”添加 ComfyUI 工作流';

  @override
  String settings_comfyUiSlotCount(Object count) {
    return '$count 个槽位';
  }

  @override
  String get settings_comfyUiBuiltin => '内置';

  @override
  String get settings_comfyUiDeleteWorkflowTitle => '删除工作流';

  @override
  String settings_comfyUiDeleteWorkflowContent(Object name) {
    return '确定要删除工作流“$name”吗？此操作不可撤销。';
  }

  @override
  String settings_comfyUiDeleted(Object name) {
    return '已删除: $name';
  }

  @override
  String get settings_comfyUiNoResponse => '服务器无响应';

  @override
  String get settings_comfyUiStatusDisconnected => '未连接';

  @override
  String get settings_comfyUiStatusConnecting => '正在连接...';

  @override
  String get settings_comfyUiStatusConnected => '已连接';

  @override
  String get settings_comfyUiStatusError => '连接异常';

  @override
  String get settings_comfyUiCategoryEnhance => '增强/超分';

  @override
  String get settings_comfyUiCategoryImg2Img => '图生图';

  @override
  String get settings_comfyUiCategoryInpaint => '重绘';

  @override
  String get settings_comfyUiCategoryTxt2Img => '文生图';

  @override
  String get settings_comfyUiCategoryCustom => '自定义';

  @override
  String get comfyWorkflow_seedvr2UpscaleName => 'SeedVR2 超分';

  @override
  String get comfyWorkflow_seedvr2UpscaleDescription =>
      '使用 SeedVR2 AI 模型进行超分辨率放大，效果优秀';

  @override
  String get comfyWorkflow_seedvr2TiledUpscaleName => 'SeedVR2 分块超分';

  @override
  String get comfyWorkflow_seedvr2TiledUpscaleDescription =>
      '使用 SeedVR2TilingUpscaler 分块放大，降低大图显存压力';

  @override
  String get comfyWorkflow_modelUpscaleName => 'ComfyUI 普通超分模型';

  @override
  String get comfyWorkflow_modelUpscaleDescription =>
      '使用 ComfyUI UpscaleModelLoader 加载普通超分模型，并用 Lanczos 修正最终倍率';

  @override
  String get comfyWorkflow_rtxUpscaleName => 'RTX 超分';

  @override
  String get comfyWorkflow_rtxUpscaleDescription =>
      '使用 Nvidia RTX Video Super Resolution 节点进行本地放大';

  @override
  String get comfyWorkflowSlot_inputImage => '输入图像';

  @override
  String get comfyWorkflowSlot_targetShortSide => '目标短边';

  @override
  String get comfyWorkflowSlot_targetLongSide => '目标长边';

  @override
  String get comfyWorkflowSlot_upscaleModel => '超分模型';

  @override
  String get comfyWorkflowSlot_randomSeed => '随机种子';

  @override
  String get comfyWorkflowSlot_outputImage => '输出图像';

  @override
  String get comfyWorkflowSlot_tileWidth => '图块宽度';

  @override
  String get comfyWorkflowSlot_tileHeight => '图块高度';

  @override
  String get comfyWorkflowSlot_tileUpscaleResolution => '图块超分分辨率';

  @override
  String get comfyWorkflowSlot_targetWidth => '目标宽度';

  @override
  String get comfyWorkflowSlot_targetHeight => '目标高度';

  @override
  String get comfyWorkflowSlot_scale => '放大倍数';

  @override
  String get comfyWorkflow_parameters => '参数设置';

  @override
  String get comfyWorkflow_selectImage => '点击选择图像';

  @override
  String comfyWorkflow_pickImageFailed(Object error) {
    return '选择图像失败: $error';
  }

  @override
  String get comfyWorkflow_useResult => '使用结果';

  @override
  String get comfyWorkflow_execute => '执行';

  @override
  String get comfyWorkflow_uploadingImage => '正在上传图像...';

  @override
  String get comfyWorkflow_queued => '排队中...';

  @override
  String comfyWorkflow_runningSteps(Object current, Object total) {
    return '处理中 $current/$total';
  }

  @override
  String get comfyWorkflow_processing => '处理中...';

  @override
  String get comfyWorkflow_complete => '执行完成';

  @override
  String comfyWorkflow_imageCount(Object count) {
    return '$count 张图像';
  }

  @override
  String get promptAssistant_defaultOptimizeRuleName => '默认优化规则';

  @override
  String get promptAssistant_defaultOptimizeRuleContent =>
      '你是提示词优化助手。保留用户意图，补充可执行的视觉细节，并只输出一行可直接使用的逗号分隔提示词。';

  @override
  String get promptAssistant_defaultTranslateRuleName => '默认翻译规则';

  @override
  String get promptAssistant_defaultTranslateRuleContent =>
      '你是翻译助手。自动识别源语言，在中文和英文之间翻译，并只返回译文，不要解释。';

  @override
  String get promptAssistant_defaultReverseRuleName => '默认反推规则';

  @override
  String get promptAssistant_defaultReverseRuleContent =>
      '你是图像反推提示词助手。根据图像和可选 tagger 结果，输出适用于 NovelAI 的英文逗号分隔提示词。保留主体、角色、风格、服装、动作、构图、光照和背景。不要解释。';

  @override
  String get promptAssistant_defaultCharacterReplaceRuleName => '默认角色替换规则';

  @override
  String get promptAssistant_defaultCharacterReplaceRuleContent =>
      '你是角色替换助手。将输入提示词中的原角色身份、发型、服装和外观替换为目标角色，同时保留动作、构图、背景、风格、镜头和质量标签。只输出替换后的一行提示词。';

  @override
  String get promptAssistant_defaultCustomRuleName => '默认自定义规则';

  @override
  String get promptAssistant_defaultCustomRuleContent =>
      '你是提示词改写助手。根据当前提示词、用户需求和可选参考图修改提示词。只输出最终可直接使用的一行提示词，不要解释。';

  @override
  String get localGallery_dateFilterButton => '日期过滤';

  @override
  String get cacheStats_title => '缓存统计';

  @override
  String cacheStats_autoRefreshUpdated(Object time) {
    return '自动刷新 · 上次更新: $time';
  }

  @override
  String cacheStats_secondsAgo(Object seconds) {
    return '$seconds秒前';
  }

  @override
  String get cacheStats_refreshNow => '立即刷新';

  @override
  String get cacheStats_refreshed => '已刷新';

  @override
  String get cacheStats_resetStats => '重置统计';

  @override
  String get cacheStats_statsReset => '统计已重置';

  @override
  String get cacheStats_l1Memory => 'L1 内存缓存';

  @override
  String get cacheStats_l2Hive => 'L2 Hive 缓存';

  @override
  String get cacheStats_l3Sqlite => 'L3 SQLite 数据库';

  @override
  String cacheStats_recordCount(Object count) {
    return '$count 条记录';
  }

  @override
  String cacheStats_databaseValue(Object imageCount, Object metadataCount) {
    return '$imageCount 张图片 · $metadataCount 条元数据';
  }

  @override
  String get galleryCache_rescanTitle => '重新扫描画廊';

  @override
  String get galleryCache_rescanContent =>
      '这将执行以下操作：\n\n1. 检查数据一致性（标记不存在的文件）\n2. 扫描新文件和变更的文件\n3. 重新尝试历史上未提取成功的元数据（含失败记录）\n\n此操作不会清空已有数据，也不会删除图片文件。';

  @override
  String get galleryCache_startScan => '开始扫描';

  @override
  String get galleryCache_scanAlreadyRunning => '已有扫描任务在进行中，请等待完成后再试';

  @override
  String get galleryCache_preparing => '准备中...';

  @override
  String get galleryCache_noGalleryFolder => '未设置画廊目录';

  @override
  String get galleryCache_galleryFolderMissing => '画廊目录不存在';

  @override
  String galleryCache_scanningPhase(Object processed, Object total) {
    return '正在扫描 $processed/$total...';
  }

  @override
  String get galleryCache_scanComplete => '扫描完成';

  @override
  String galleryCache_scanFailed(Object error) {
    return '扫描失败: $error';
  }

  @override
  String get galleryCache_rescan => '重新扫描';

  @override
  String get galleryCache_rescanSubtitle => '检查数据一致性、查漏补缺、提取元数据';

  @override
  String get galleryCache_scanning => '正在扫描...';

  @override
  String get galleryCache_scanAction => '扫描';

  @override
  String get workflowImport_title => '导入 ComfyUI 工作流';

  @override
  String workflowImport_step(Object current, Object title) {
    return '步骤 $current/4: $title';
  }

  @override
  String get workflowImport_stepFile => '选择工作流文件';

  @override
  String get workflowImport_stepInfo => '工作流信息';

  @override
  String get workflowImport_stepSlots => '确认槽位配置';

  @override
  String get workflowImport_stepDone => '完成导入';

  @override
  String get workflowImport_previous => '上一步';

  @override
  String get workflowImport_next => '下一步';

  @override
  String get workflowImport_finish => '完成导入';

  @override
  String get workflowImport_defaultName => '自定义工作流';

  @override
  String get workflowImport_fileInstructions =>
      '请选择 ComfyUI 导出的 workflow_api.json 文件。\n\n在 ComfyUI 中，点击菜单 → 导出 (API格式) 即可获得此文件。';

  @override
  String workflowImport_nodeCount(Object count) {
    return '$count 个节点';
  }

  @override
  String get workflowImport_reselect => '点击重新选择';

  @override
  String get workflowImport_selectWorkflowApi => '点击选择 workflow_api.json';

  @override
  String get workflowImport_invalidTopLevel => '文件格式无效：顶层应为 JSON 对象';

  @override
  String get workflowImport_noComfyNodes => '未检测到 ComfyUI 节点，请确认是 API 格式导出';

  @override
  String workflowImport_readFailed(Object error) {
    return '读取文件失败: $error';
  }

  @override
  String get workflowImport_analysisResult => '自动分析结果';

  @override
  String get workflowImport_inputImageNodes => '输入图像节点';

  @override
  String get workflowImport_adjustableParams => '可调参数';

  @override
  String get workflowImport_outputNodes => '输出节点';

  @override
  String get workflowImport_totalNodes => '总节点数';

  @override
  String workflowImport_countUnit(Object count) {
    return '$count 个';
  }

  @override
  String get workflowImport_workflowName => '工作流名称 *';

  @override
  String get workflowImport_description => '描述';

  @override
  String get workflowImport_category => '分类';

  @override
  String get workflowImport_slotsHint =>
      '勾选需要暴露给 UI 的槽位。输入/输出槽位建议保留；不需要用户调整的参数可以取消勾选。';

  @override
  String get workflowImport_inputSection => '输入';

  @override
  String get workflowImport_outputSection => '输出';

  @override
  String get workflowImport_parameterSection => '参数';

  @override
  String get workflowImport_noSlotsWarning =>
      '未检测到任何可用槽位。该工作流可能无法正常集成。\n请确认工作流中包含 LoadImage 和 SaveImage/SaveImageWebsocket 节点。';

  @override
  String workflowImport_nodeRef(Object node) {
    return '节点 $node';
  }

  @override
  String get workflowImport_confirmTitle => '即将导入以下工作流';

  @override
  String get workflowImport_name => '名称';

  @override
  String get workflowImport_inputSlots => '输入槽位';

  @override
  String get workflowImport_parameterSlots => '参数槽位';

  @override
  String get workflowImport_outputSlots => '输出槽位';

  @override
  String get workflowImport_afterImportHint => '导入后可在生成界面的 ComfyUI 工作流列表中使用。';

  @override
  String workflowImport_success(Object name) {
    return '工作流“$name”导入成功';
  }

  @override
  String get shortcut_settings_help => '查看快捷键帮助';

  @override
  String get shortcut_settings_show_in_menus => '在菜单中显示';

  @override
  String shortcut_settings_defaultShortcut(Object shortcut) {
    return '默认: $shortcut';
  }

  @override
  String get shortcut_settings_unassigned => '未设置';

  @override
  String get shortcut_settings_no_matches => '未找到匹配的快捷键';

  @override
  String get shortcut_settings_reset_all_title => '重置所有快捷键';

  @override
  String get shortcut_settings_reset_all_confirm =>
      '确定要将所有快捷键重置为默认设置吗？此操作不可撤销。';

  @override
  String get shortcut_settings_reset_to_default => '重置为默认';

  @override
  String get performanceReport_noTaskStats => '暂无任务统计数据';

  @override
  String performanceReport_taskStatsLine(
    Object count,
    Object average,
    Object min,
    Object max,
  ) {
    return '次数: $count | 平均: $average | 最小: $min | 最大: $max';
  }

  @override
  String get performanceReport_clearTitle => '清空性能数据';

  @override
  String get performanceReport_clearContent => '确定要清空所有性能统计数据吗？此操作不可撤销。';

  @override
  String get performanceReport_clearSuccess => '性能数据已清空';

  @override
  String get toast_previewUpdated => '预览图已更新';

  @override
  String toast_styleReferenceLimit(Object max) {
    return '风格参考已达上限 ($max 张)';
  }

  @override
  String get toast_noValidPromptFound => '未找到有效的提示词';

  @override
  String toast_addedToQueue(Object prompt) {
    return '已加入队列: $prompt';
  }

  @override
  String get toast_noValidMaskIgnored => '没有检测到有效蒙版，保存结果已忽略。';

  @override
  String get toast_kritaBusy => 'Krita Bridge 正在生成，请等待当前任务结束';

  @override
  String get toast_kritaNotConnected => 'Krita 未连接，请先在设置中启用桥接并连接插件';

  @override
  String get toast_sentToKrita => '图片已发送到 Krita';

  @override
  String get toast_kritaUnsupportedImageFormat => '图片格式无法发送到 Krita，请换用常见图片格式';

  @override
  String toast_deletedNamed(Object name) {
    return '已删除: $name';
  }

  @override
  String get toast_vibeParamSaveReencodeFailed => '保存参数失败，Vibe 重新编码失败';

  @override
  String get toast_exportSuccess => '导出成功';

  @override
  String toast_exportFailed(Object error) {
    return '导出失败: $error';
  }

  @override
  String get toast_selectVibeToExport => '请先选择要导出的 Vibe';

  @override
  String get toast_embedPngSingleVibeOnly => '嵌入 PNG 仅支持单个 Vibe 导出';

  @override
  String get toast_selectPngCarrier => '请选择一个 PNG 载体图用于导出';

  @override
  String get toast_renameSuccess => '重命名成功';

  @override
  String get toast_paramsSaved => '参数已保存';

  @override
  String get toast_paramsSaveFailed => '保存参数失败';

  @override
  String get toast_dropNoReadableImageOrVibe => '拖入源未提供可读取的图片或 Vibe 文件';

  @override
  String toast_importedTasks(Object count) {
    return '成功导入 $count 个任务';
  }

  @override
  String get toast_contentCannotBeEmpty => '内容不能为空';

  @override
  String get toast_addedToLibrary => '已添加到词库';

  @override
  String toast_addFailed(Object error) {
    return '添加失败: $error';
  }

  @override
  String get toast_libraryNotLoaded => '词库未加载';

  @override
  String get toast_noValidTagContent => '没有有效的标签内容';

  @override
  String get toast_allTagsAlreadyExist => '所有标签已存在于词库中';

  @override
  String get toast_noAddableTags => '没有可添加的标签';

  @override
  String toast_addedTagsSkippedDuplicates(Object added, Object skipped) {
    return '已添加 $added 个标签，跳过 $skipped 个重复标签';
  }

  @override
  String get toast_favorited => '已收藏';

  @override
  String get toast_unfavorited => '已取消收藏';

  @override
  String toast_favoriteUpdateFailed(Object error) {
    return '收藏状态更新失败: $error';
  }

  @override
  String toast_packingImages(Object count) {
    return '正在打包 $count 张图片...';
  }

  @override
  String toast_packedImages(Object count) {
    return '已打包 $count 张图片';
  }

  @override
  String get toast_packFailed => '打包失败';

  @override
  String toast_packFailedWithError(Object error) {
    return '打包失败: $error';
  }

  @override
  String get toast_saveDirNotSet => '未设置保存目录';

  @override
  String toast_savedTo(Object path) {
    return '已保存到 $path';
  }

  @override
  String get toast_tagAlreadyExists => '标签已存在';

  @override
  String get toast_nameRequired => '请输入名称';

  @override
  String get toast_savedToVibeLibrary => '已保存到 Vibe 库';

  @override
  String get toast_saveBundleFailed => '保存组合失败';

  @override
  String get toast_saveEntryFailed => '保存条目失败';

  @override
  String get toast_presetNameRequired => '请输入预设名称';

  @override
  String get toast_selectPresetContent => '请至少选择一项要保存的内容';

  @override
  String get toast_presetSaved => '预设保存成功';

  @override
  String get toast_imagePromptCopied => '已复制 Prompt';

  @override
  String get toast_imageHasNoPrompt => '此图片没有 Prompt';

  @override
  String get toast_useDeleteButton => '请使用界面删除按钮';

  @override
  String get toast_imageHasNoMetadata => '此图片没有元数据';

  @override
  String get toast_imageDataUnavailable => '图像数据不可用，无法复制';

  @override
  String get toast_tempFileCreateFailed => '临时文件创建失败';

  @override
  String get toast_vibeDataCopied => 'Vibe 数据已复制';

  @override
  String get toast_tagCopied => '标签已复制';

  @override
  String get toast_characterPromptCopied => '角色提示词已复制';

  @override
  String toast_copiedTitle(Object title) {
    return '$title已复制';
  }

  @override
  String toast_replacedVibesCount(Object count, Object name) {
    return '已替换为 $count 个 Vibe: $name';
  }

  @override
  String toast_sentVibesCount(Object count, Object name) {
    return '已发送 $count 个 Vibe 到生成页面: $name';
  }

  @override
  String toast_replacedVibe(Object name) {
    return '已替换为: $name';
  }

  @override
  String toast_sentVibeToGeneration(Object name) {
    return '已发送到生成页面: $name';
  }

  @override
  String get toast_unreadableDroppedImageSource => '拖入源未提供可读取的图片文件或图片链接';

  @override
  String toast_appendedStyleReferences(Object count) {
    return '已追加 $count 个风格参考';
  }

  @override
  String get toast_appendedPreencodedVibe => '已追加 1 个风格参考（复用预编码 Vibe）';

  @override
  String get toast_addedPreencodedVibe => '已添加风格参考（复用预编码 Vibe，节省 2 Anlas）';

  @override
  String toast_vibesMissingEncoding(Object count) {
    return '$count 个 Vibe 缺少编码数据，无法保存';
  }

  @override
  String toast_savedBundle(Object count) {
    return '已保存 Bundle ($count 个 Vibe)';
  }

  @override
  String get toast_replacedCharacterReference => '已替换角色参考';

  @override
  String toast_extractMetadataFailed(Object error) {
    return '提取元数据失败: $error';
  }

  @override
  String toast_extractPromptFailed(Object error) {
    return '提取提示词失败: $error';
  }

  @override
  String get toast_smartDecomposeSent => '已智能分解并发送';

  @override
  String get toast_addedToFixedTags => '已添加到固定词';

  @override
  String get toast_renameNameRequired => '名称不能为空';

  @override
  String get toast_renameNameConflict => '名称已存在，请使用其他名称';

  @override
  String get toast_renameEntryNotFound => '条目不存在，可能已被删除';

  @override
  String get toast_renameFilePathMissing => '该条目缺少文件路径，无法重命名';

  @override
  String get toast_renameFileFailed => '重命名文件失败，请稍后重试';

  @override
  String get toast_renameFailed => '重命名失败，请稍后重试';

  @override
  String toast_processImageFailed(Object error) {
    return '处理图片失败: $error';
  }

  @override
  String get toast_savePreviewFailed => '保存预览图失败';

  @override
  String get common_justNow => '刚刚';

  @override
  String common_minutesAgo(Object minutes) {
    return '$minutes分钟前';
  }

  @override
  String common_hoursAgo(Object hours) {
    return '$hours小时前';
  }

  @override
  String get common_saving => '保存中...';

  @override
  String get common_pleaseWait => '请稍候';

  @override
  String get common_change => '更换';

  @override
  String get common_expand => '展开';

  @override
  String get common_collapse => '收起';

  @override
  String get vibeLibrary_emptySearchTitle => '未找到匹配的 Vibe';

  @override
  String get vibeLibrary_emptySearchSubtitle => '尝试其他关键词';

  @override
  String get vibeLibrary_emptyFavoritesTitle => '暂无收藏的 Vibe';

  @override
  String get vibeLibrary_emptyFavoritesSubtitle => '点击心形图标收藏 Vibe';

  @override
  String get vibeLibrary_emptyCategoryTitle => '该分类下暂无 Vibe';

  @override
  String get vibeLibrary_emptyCategorySubtitle => '尝试切换到\"全部 Vibe\"查看所有内容';

  @override
  String get vibeLibrary_emptyNoMatchesTitle => '无匹配结果';

  @override
  String get vibeLibrary_emptySaveFromGenerationHint => '从生成页面保存Vibe到库中';

  @override
  String get vibe_nameRequired => '名称不能为空';

  @override
  String get vibe_import_namingTitle => '命名 Vibe';

  @override
  String get vibe_import_nameConflictOverwrite => '该名称已存在，将被覆盖';

  @override
  String get vibe_previewLoadFailed => '预览加载失败';

  @override
  String get vibe_import_applyToRemainingFiles => '应用到后续所有文件';

  @override
  String get vibe_import_applyNamingToRemainingFiles => '使用此命名规则处理剩余文件';

  @override
  String get vibe_encodeImageTitle => '编码图片为 Vibe';

  @override
  String get vibe_imagePreview => '图片预览';

  @override
  String get vibe_encodeStartButton => '开始编码';

  @override
  String get vibe_encodeImageInProgress => '正在编码图片...';

  @override
  String vibe_encodeErrorImage(Object fileName) {
    return '图片: $fileName';
  }

  @override
  String vibe_encodeErrorMessage(Object error) {
    return '错误: $error';
  }

  @override
  String get vibe_encodeSkipImage => '跳过此图';

  @override
  String get detail_sendToImg2Img => '发送到图生图';

  @override
  String get detail_sendToReversePrompt => '发送到反推';

  @override
  String get detail_loadingImage => '加载图片中...';

  @override
  String get detail_imageLoadFailed => '无法加载图片';

  @override
  String get detail_noImage => '无图片';

  @override
  String get detail_parsingMetadata => '正在解析元数据...';

  @override
  String get detail_noMetadata => '此图片无元数据';

  @override
  String get detail_metadata => '元数据';

  @override
  String get detail_imageDetails => '图片详情';

  @override
  String get detail_basicInfo => '基本信息';

  @override
  String get detail_fileName => '文件名';

  @override
  String get detail_modifiedTime => '修改时间';

  @override
  String get detail_fileSize => '文件大小';

  @override
  String get detail_noContent => '(无内容)';

  @override
  String get detail_savePreset => '保存预设';

  @override
  String detail_copyLabel(Object label) {
    return '复制$label';
  }

  @override
  String get detail_copyCharacterPrompt => '复制角色提示词';

  @override
  String get detail_copyAllVibeData => '复制全部 Vibe 数据';

  @override
  String get detail_saveToVibeLibrary => '保存到 Vibe 库';

  @override
  String get pagination_firstPage => '首页';

  @override
  String get pagination_previousPage => '上一页';

  @override
  String get pagination_nextPage => '下一页';

  @override
  String get pagination_lastPage => '末页';

  @override
  String get pagination_jumpToPage => '跳转到页面';

  @override
  String get pagination_jump => '跳转';

  @override
  String get pagination_itemsPerPage => '每页';

  @override
  String get pagination_itemUnit => '项';

  @override
  String get diyGuide_title => 'DIY 功能指南';

  @override
  String get diyGuide_subtitle => '了解高级功能，创建专属词库';

  @override
  String get diyGuide_intro => '本指南介绍了 DIY 系统的核心概念和高级功能，帮助您构建强大的动态提示词库。';

  @override
  String get diyGuide_exampleLabel => '示例';

  @override
  String get diyGuide_hierarchyTitle => '层级结构 (Hierarchy)';

  @override
  String get diyGuide_hierarchyDescription => 'DIY 系统采用三级分类结构来组织提示词，便于管理和检索。';

  @override
  String get diyGuide_hierarchyExample =>
      'Category (分类): 角色特征\n  -> Group (分组): 发型\n      -> Tag (标签): 长发, 短发, 双马尾';

  @override
  String get diyGuide_selectionModeTitle => '选择模式 (Selection Mode)';

  @override
  String get diyGuide_selectionModeDescription => '决定从一个分组(Group)中选取多少个标签。';

  @override
  String get diyGuide_selectionModeExample =>
      '• Random (随机): 每次随机选取一个 (如：随机发色)\n• All (全选): 选取组内所有标签 (如：固定特征组合)';

  @override
  String get diyGuide_weightTitle => '权重控制 (Weight)';

  @override
  String get diyGuide_weightDescription => '调整特定提示词在生成过程中的影响力。';

  @override
  String get diyGuide_weightExample =>
      '• 增强: 用花括号包裹 masterpiece = 1.05 倍权重\n• 强力增强: 三层花括号包裹 masterpiece = 1.16 倍权重\n• 减弱: [bad hands] = 0.95 倍权重';

  @override
  String get diyGuide_genderTitle => '性别限制 (Gender)';

  @override
  String get diyGuide_genderDescription => '限制标签仅对特定性别的角色生效，避免生成错误的特征。';

  @override
  String get diyGuide_genderExample =>
      '• Female: 仅女性角色可用 (如：裙子)\n• Male: 仅男性角色可用 (如：胡须)\n• Any: 通用 (如：T恤)';

  @override
  String get diyGuide_scopeTitle => '作用域 (Scope)';

  @override
  String get diyGuide_scopeDescription => '定义标签是作用于角色本身、背景环境还是全局画面。';

  @override
  String get diyGuide_scopeExample =>
      '• Character: 角色特征 (眼睛, 头发)\n• Background: 环境描述 (蓝天, 室内)\n• Global: 画风, 质量词 (best quality)';

  @override
  String get diyGuide_conditionalTitle => '条件分支 (Conditional)';

  @override
  String get diyGuide_conditionalDescription => '基于已选标签或其他条件来动态决定后续标签。';

  @override
  String get diyGuide_conditionalExample =>
      'IF (已选 \"下雨\")\n  THEN 添加 \"雨伞\", \"湿衣服\"\n  ELSE 添加 \"晴朗\"';

  @override
  String get diyGuide_dependenciesTitle => '依赖引用 (Dependencies)';

  @override
  String get diyGuide_dependenciesDescription =>
      '建立标签间的关联，选中一个标签时自动引入相关联的其他标签。';

  @override
  String get diyGuide_dependenciesExample =>
      '选中 \"JK制服\" -> 自动引入 \"学校背景\", \"书包\"';

  @override
  String get diyGuide_visibilityTitle => '可见性规则 (Visibility)';

  @override
  String get diyGuide_visibilityDescription => '控制标签在界面上的显示条件，或在生成时的生效条件。';

  @override
  String get diyGuide_visibilityExample => '仅当选中 \"魔法少女\" 分类时，显示 \"魔杖\" 选项组';

  @override
  String get diyGuide_timeTitle => '时间条件 (Time)';

  @override
  String get diyGuide_timeDescription => '根据现实时间或设定的模拟时间触发特定标签。';

  @override
  String get diyGuide_timeExample =>
      '• 06:00-18:00 -> 添加 \"daylight\"\n• 18:00-06:00 -> 添加 \"night\"';

  @override
  String get diyGuide_postProcessingTitle => '后处理规则 (Post-processing)';

  @override
  String get diyGuide_postProcessingDescription => '在提示词生成最后阶段进行文本替换或清理。';

  @override
  String get diyGuide_postProcessingExample =>
      '将所有 \"blue eyes\" 替换为 \"azure eyes\" 以获得更独特的描述';

  @override
  String get diyGuide_emphasisTitle => '强调概率 (Emphasis)';

  @override
  String get diyGuide_emphasisDescription => '为标签随机添加权重符号的概率，增加结果的多样性。';

  @override
  String get diyGuide_emphasisExample =>
      '设置 30% 概率: 约有 1/3 的机会输出加权 tag，2/3 的机会输出普通 tag';

  @override
  String get naiRules_title => 'NAI 随机规则说明';

  @override
  String get naiRules_characterCountProbability => '角色数量概率';

  @override
  String get naiRules_solo => '1人 (Solo)';

  @override
  String get naiRules_duo => '2人 (Duo)';

  @override
  String get naiRules_trio => '3人 (Trio)';

  @override
  String get naiRules_group => '4人 (Group)';

  @override
  String get naiRules_genderRules => '性别规则';

  @override
  String get naiRules_female => '女性 (Female)';

  @override
  String get naiRules_male => '男性 (Male)';

  @override
  String get naiRules_mixed => '混合/其他 (Mixed)';

  @override
  String get naiRules_categoryProbability => '类别概率';

  @override
  String get naiRules_dynamicTagWeightTitle => '标签权重动态调整';

  @override
  String get naiRules_dynamicTagWeightSubtitle =>
      '包含动作、服饰、表情、背景等多个维度的随机组合，根据画面主题动态调整各类别的抽取权重';

  @override
  String get naiRules_specialMechanisms => '特殊机制';

  @override
  String get naiRules_tagStrengthening => '强调机制 (Tag Strengthening)';

  @override
  String get naiRules_seasonalLibraryTitle => '季节词库';

  @override
  String get naiRules_seasonalLibrarySubtitle =>
      '自动匹配季节特征，包含季节性服饰、天气、光照效果和环境氛围';

  @override
  String get naiRules_v4CharacterPositioning => 'V4 多角色位置';

  @override
  String get naiRules_smartPositionTitle => '智能位置分配';

  @override
  String get naiRules_smartPositionSubtitle =>
      '在 V4 模型下，使用 character positioning 语法精确控制多角色站位';

  @override
  String get comfyImport_detectedTitle => '检测到 ComfyUI 多角色提示词';

  @override
  String comfyImport_characterList(Object count) {
    return '角色列表 ($count)';
  }

  @override
  String get comfyImport_usePositionInfo => '使用位置信息';

  @override
  String get comfyImport_usePositionInfoSubtitle => '将 ComfyUI 区域映射为 NAI 角色位置';

  @override
  String comfyImport_convertCharacters(Object count) {
    return '转换 $count 个角色';
  }

  @override
  String get comfyImport_syntaxCouple => 'COUPLE 语法';

  @override
  String get comfyImport_syntaxAndMask => 'AND+MASK 语法';

  @override
  String get comfyImport_syntaxPipe => '竖线格式';

  @override
  String get comfyImport_syntaxUnknown => '未知语法';

  @override
  String get comfyImport_globalPrompt => '全局提示词';

  @override
  String get danbooruPreview_noTagData => '暂无标签数据';

  @override
  String get danbooruPreview_noPoolData => '暂无 Pool 数据';

  @override
  String danbooruPreview_postCount(Object count) {
    return '$count 个帖子';
  }

  @override
  String get checkForUpdate => '检查更新';

  @override
  String get neverChecked => '从未检查';

  @override
  String lastCheckedAt(Object time) {
    return '上次检查: $time';
  }

  @override
  String get includePrereleaseUpdates => '包含预发布版本';

  @override
  String get includePrereleaseUpdatesDescription => '检查更新时包含 beta/alpha 版本';

  @override
  String get updateAvailable => '发现新版本';

  @override
  String get updateChecking => '正在检查更新...';

  @override
  String get updateDownloading => '正在下载更新...';

  @override
  String get updateInstalling => '正在启动安装器...';

  @override
  String get updateUpToDate => '已是最新版本';

  @override
  String get updateError => '检查更新失败';

  @override
  String get currentVersion => '当前版本';

  @override
  String get latestVersion => '最新版本';

  @override
  String get releaseNotes => '更新日志';

  @override
  String get updatePortableManualHint => '便携版需要前往 Release 页面手动下载新版。';

  @override
  String updateDownloadingProgress(Object percent) {
    return '正在下载更新包：$percent%';
  }

  @override
  String get updateInstallingHint => '安装器已启动，应用即将关闭。';

  @override
  String get remindMeLater => '稍后提醒';

  @override
  String get skipThisVersion => '忽略此版本';

  @override
  String get updateDownloadAndInstall => '下载并安装';

  @override
  String get goToDownload => '前往下载';

  @override
  String get versionSkipped => '已忽略此版本';

  @override
  String get cannotOpenUrl => '无法打开链接';

  @override
  String get model3d_editorTitle => '3D 模型图层';

  @override
  String get model3d_addMannequin => '添加内置人偶';

  @override
  String get model3d_importModel => '导入模型 (.glb/.gltf)';

  @override
  String get model3d_emptyHint => '场景为空，先添加人偶或导入模型';

  @override
  String get model3d_apply => '应用到图层';

  @override
  String get model3d_modeTransform => '变换';

  @override
  String get model3d_modePose => '姿势';

  @override
  String get model3d_gizmoTranslate => '移动';

  @override
  String get model3d_gizmoRotate => '旋转';

  @override
  String get model3d_gizmoScale => '缩放';

  @override
  String get model3d_undo => '撤销';

  @override
  String get model3d_resetPose => '重置姿势';

  @override
  String get model3d_replaceConfirm => '替换当前模型？未应用的姿势将丢失。';

  @override
  String get model3d_discardConfirm => '放弃未应用的修改？';

  @override
  String get model3d_missingModel => '模型文件已丢失，可重新导入';

  @override
  String get model3d_loadError => '模型加载失败';

  @override
  String get model3d_light => '光照';

  @override
  String get model3d_lightIntensity => '强度';

  @override
  String get model3d_lightAzimuth => '方位角';

  @override
  String get model3d_lightElevation => '仰角';

  @override
  String get model3d_addLayerTooltip => '添加 3D 模型图层';

  @override
  String get model3d_webview2Missing =>
      '3D 编辑器需要 Microsoft Edge WebView2 运行时。Windows 10/11 通常已自带;若缺失请从微软官网安装 Evergreen 版本后重试。';

  @override
  String get nav_preciseRefLibrary => '精准参考库';

  @override
  String get preciseRefLib_title => '精准参考库';

  @override
  String get preciseRefLib_searchHint => '搜索参考图...';

  @override
  String get preciseRefLib_empty => '拖拽或粘贴图片到此处建立库';

  @override
  String get preciseRefLib_emptyHint => '也可以在生成结果、历史记录或本地图库中右键保存';

  @override
  String get preciseRefLib_import => '导入图片';

  @override
  String preciseRefLib_entryCount(int count) {
    return '$count 个条目';
  }

  @override
  String get preciseRefLib_sendToPreciseRef => '发送到精准参考';

  @override
  String get preciseRefLib_sendToImg2Img => '发送到图生图';

  @override
  String get preciseRefLib_editEntry => '编辑参数';

  @override
  String get preciseRefLib_deleteEntry => '删除';

  @override
  String get preciseRefLib_confirmDeleteTitle => '删除条目';

  @override
  String preciseRefLib_confirmDelete(String name) {
    return '确定删除“$name”？图片文件将一并删除。';
  }

  @override
  String preciseRefLib_saved(String name) {
    return '已存入精准参考库：$name';
  }

  @override
  String get preciseRefLib_savedHint => '可在精准参考库中编辑参数';

  @override
  String preciseRefLib_sent(String name) {
    return '已发送到精准参考：$name';
  }

  @override
  String preciseRefLib_sentToImg2Img(String name) {
    return '已发送到图生图：$name';
  }

  @override
  String get preciseRefLib_imageMissing => '原图文件丢失';

  @override
  String get preciseRefLib_invalidImage => '无法识别图片格式，或图片文件已经损坏';

  @override
  String get preciseRefLib_deleteFailed => '删除失败，条目与原图已保留，请稍后重试';

  @override
  String get preciseRefLib_favoritesOnly => '只看收藏';

  @override
  String get preciseRefLib_sortBy => '排序方式';

  @override
  String get preciseRefLib_sortCreatedAt => '创建时间';

  @override
  String get preciseRefLib_sortLastUsed => '最近使用';

  @override
  String get preciseRefLib_sortUsedCount => '使用次数';

  @override
  String get preciseRefLib_sortName => '名称';

  @override
  String preciseRefLib_importedCount(int count) {
    return '已导入 $count 张图片';
  }

  @override
  String preciseRefLib_loadFailed(String error) {
    return '加载精准参考库失败：$error';
  }

  @override
  String preciseRefLib_importFailed(String error) {
    return '保存到精准参考库失败：$error';
  }

  @override
  String preciseRefLib_importFailedCount(int count) {
    return '$count 张图片未能导入精准参考库';
  }

  @override
  String get preciseRefLib_fromLibrary => '从库导入';

  @override
  String get preciseRefLib_saveCurrentToLibrary => '保存到库';

  @override
  String preciseRefLib_saveCurrentCount(int count) {
    return '已保存 $count 张到精准参考库';
  }

  @override
  String get preciseRefLib_selectorTitle => '从精准参考库选择';

  @override
  String preciseRefLib_selectorConfirm(int count) {
    return '添加所选 ($count)';
  }

  @override
  String get preciseRefLib_nameLabel => '名称';

  @override
  String get preciseRefLib_typeFilterAll => '全部';

  @override
  String get img2img_fromPreciseRefLibrary => '从精准参考库导入';

  @override
  String get localGallery_saveToPreciseRefLibrary => '保存到精准参考库';

  @override
  String get drop_saveToPreciseRefLibrary => '存入精准参考库';

  @override
  String get common_enabled => '已启用';

  @override
  String get common_disabled => '已禁用';

  @override
  String bulkAction_selectedCount(int count) {
    return '已选择 $count 项';
  }

  @override
  String get comfyTask_errorConnectionFailed => '无法连接到 ComfyUI 服务器';

  @override
  String get comfyTask_errorConnectionUnavailable => 'ComfyUI 连接不可用';

  @override
  String get comfyTask_errorExecutionFailedGeneric => 'ComfyUI 执行失败';

  @override
  String comfyTask_errorExecutionFailed(String error) {
    return 'ComfyUI 执行失败：$error';
  }

  @override
  String get comfyTask_errorTimeout => 'ComfyUI 任务已在 10 分钟后超时';

  @override
  String comfyTask_errorWorkflowNotFound(String workflowId) {
    return '未找到工作流：$workflowId';
  }

  @override
  String get comfyWorkflowSlot_vaeEncodeTileSize => 'VAE 编码分块大小';

  @override
  String get comfyWorkflowSlot_vaeDecodeTileSize => 'VAE 解码分块大小';

  @override
  String get comfyWorkflowSlot_blocksToSwap => '换出块数量';

  @override
  String get comfyWorkflowSlot_swapIoComponents => '换出输入输出组件';

  @override
  String localGallery_firstIndexHint(int count) {
    return '检测到 $count 张图片。首次建立索引可能需要几分钟，期间仍可正常使用应用。';
  }

  @override
  String get localGallery_errorPermissionDenied => '无法访问图片文件夹，请检查文件夹权限。';

  @override
  String localGallery_errorScanFailed(String error) {
    return '扫描图片失败：$error';
  }

  @override
  String localGallery_errorInitializationFailed(String error) {
    return '初始化图库失败：$error';
  }

  @override
  String get localGallery_errorServiceInitializing => '图库服务正在初始化，请稍后重试。';

  @override
  String localGallery_errorDatabaseFailed(String error) {
    return '图库数据库错误：$error';
  }

  @override
  String localGallery_errorRefreshFailed(String error) {
    return '刷新图库失败：$error';
  }

  @override
  String localGallery_errorFilterFailed(String error) {
    return '应用图库筛选条件失败：$error';
  }

  @override
  String localGallery_errorFavoriteFailed(String error) {
    return '更新收藏状态失败：$error';
  }

  @override
  String localGallery_errorRebuildFailed(String error) {
    return '重建图库索引失败：$error';
  }

  @override
  String get diy_editDependencyTitle => '编辑依赖配置';

  @override
  String get diy_dependencyTitle => '依赖配置';

  @override
  String get diy_dependencySubtitle => '配置标签选择之间的依赖关系';

  @override
  String get diy_dependencyType => '依赖类型';

  @override
  String get diy_sourceCategory => '源类别';

  @override
  String get diy_selectSourceCategory => '选择源类别';

  @override
  String get diy_sourceCategoryId => '源类别 ID';

  @override
  String get diy_enterCategoryId => '输入类别 ID';

  @override
  String get diy_mappingRules => '映射规则';

  @override
  String get diy_noMappingRules => '暂无映射规则';

  @override
  String get diy_deleteRule => '删除规则';

  @override
  String get diy_defaultValue => '默认值';

  @override
  String get diy_defaultValueHint => '没有匹配的映射规则时使用';

  @override
  String get diy_enableDependency => '启用依赖配置';

  @override
  String get diy_enableDependencyHint => '禁用后将忽略此依赖配置';

  @override
  String get diy_addMappingRule => '添加映射规则';

  @override
  String get diy_sourceValue => '源值';

  @override
  String get diy_sourceValueHint => '例如：1, 2, 3';

  @override
  String get diy_resultValue => '结果值';

  @override
  String get diy_resultValueHint => '例如：0-3, 0-2, 0-1';

  @override
  String get diy_dependencyCount => '数量';

  @override
  String get diy_dependencyExists => '存在';

  @override
  String get diy_dependencyValue => '值';

  @override
  String get diy_dependencyExcludes => '排斥';

  @override
  String get diy_dependencyCountDescription => '根据源类别的已选数量决定结果数量';

  @override
  String get diy_dependencyExistsDescription => '仅在源类别中存在已选标签时生效';

  @override
  String get diy_dependencyValueDescription => '依赖源类别中选定的特定标签值';

  @override
  String get diy_dependencyExcludesDescription => '源类别中存在已选标签时不生效';

  @override
  String get diy_editConditionalTitle => '编辑条件分支';

  @override
  String get diy_conditionalDefaultName => '条件分支配置';

  @override
  String diy_branchDefaultName(int index) {
    return '分支 $index';
  }

  @override
  String get diy_conditionalTitle => '条件分支配置';

  @override
  String get diy_conditionalSubtitle => '根据概率选择不同分支';

  @override
  String diy_branchCount(int count) {
    return '$count 个分支';
  }

  @override
  String get diy_noConditionalBranches => '暂无条件分支';

  @override
  String get diy_noConditionalBranchesHint => '添加分支以实现条件选择逻辑';

  @override
  String diy_conditionCount(int count) {
    return '$count 个条件';
  }

  @override
  String get diy_deleteBranch => '删除分支';

  @override
  String get diy_addBranch => '添加分支';

  @override
  String diy_editBranch(String name) {
    return '编辑：$name';
  }

  @override
  String get diy_branchName => '分支名称';

  @override
  String get diy_probability => '概率';

  @override
  String get diy_enableBranch => '启用此分支';

  @override
  String diy_ruleDefaultName(int index) {
    return '规则 $index';
  }

  @override
  String diy_ruleCount(int count) {
    return '$count 条规则';
  }

  @override
  String get diy_addRule => '添加规则';

  @override
  String get diy_editRule => '编辑规则';

  @override
  String get diy_ruleName => '规则名称';

  @override
  String get diy_enableRule => '启用此规则';

  @override
  String get diy_postProcessTitle => '后处理规则';

  @override
  String get diy_postProcessSubtitle => '自动处理标签冲突';

  @override
  String get diy_sleepingRule => '睡眠规则';

  @override
  String get diy_sleepingRuleDescription => '角色睡眠时移除眼睛颜色描述';

  @override
  String get diy_mermaidRule => '美人鱼规则';

  @override
  String get diy_mermaidRuleDescription => '移除美人鱼、半人马、蛇女等角色的腿部服装描述';

  @override
  String get diy_presetRules => '预设规则';

  @override
  String get diy_noPostProcessRules => '暂无后处理规则';

  @override
  String get diy_noPostProcessRulesHint => '添加规则以自动处理标签冲突';

  @override
  String get diy_actionType => '操作类型';

  @override
  String get diy_triggerTags => '触发标签';

  @override
  String get diy_commaSeparatedTagsHint => '用逗号分隔标签';

  @override
  String get diy_targetCategories => '目标类别';

  @override
  String get diy_commaSeparatedCategoryIdsHint => '用逗号分隔类别 ID';

  @override
  String get diy_targetTags => '目标标签';

  @override
  String get diy_actionRemoveTags => '移除标签';

  @override
  String get diy_actionReplaceTags => '替换标签';

  @override
  String get diy_actionAddTags => '添加标签';

  @override
  String get diy_actionRemoveCategories => '移除类别';

  @override
  String get diy_noTriggers => '无触发条件';

  @override
  String diy_actionSummary(String triggers, String action) {
    return '当 [$triggers] 匹配时：$action';
  }

  @override
  String get diy_characterPositionTitle => '角色位置';

  @override
  String get diy_characterPositionSubtitle => '可视化编辑角色位置';

  @override
  String get diy_addCharacterPosition => '添加角色位置';

  @override
  String get diy_addCharacterPositionHint => '点击下方按钮添加角色位置';

  @override
  String diy_characterIndex(int index) {
    return '角色 $index';
  }

  @override
  String get diy_aiPositionChoice => 'AI 自动选择';

  @override
  String diy_positionCoordinates(String row, String column) {
    return '行：$row%，列：$column%';
  }

  @override
  String get diy_customPosition => '自定义';

  @override
  String diy_emphasisPercent(String percent) {
    return '强调 $percent%';
  }

  @override
  String get diy_characterCountWeight => '角色数量权重';

  @override
  String diy_peopleCount(int count) {
    return '$count 人';
  }

  @override
  String get diy_genderProbability => '性别概率';

  @override
  String get diy_noWeightsConfigured => '未设置权重';

  @override
  String get diy_genderOther => '其他';

  @override
  String get diy_emphasisTitle => '全局强调配置';

  @override
  String get diy_emphasisSubtitle => '调整标签强调效果';

  @override
  String get diy_emphasisProbability => '强调概率';

  @override
  String diy_emphasisProbabilityHint(String percent) {
    return '每个选中的标签有 $percent% 的概率被添加强调括号';
  }

  @override
  String get diy_bracketCount => '括号层数';

  @override
  String diy_bracketLayers(int count) {
    return '$count 层';
  }

  @override
  String get diy_effectPreview => '效果预览';

  @override
  String get diy_exampleTag => '示例标签';

  @override
  String get diy_emphasisExplanation => '强调括号会增加标签的权重，层数越多权重越高';

  @override
  String diy_presetExportFailed(String error) {
    return '导出预设失败：$error';
  }

  @override
  String get diy_presetJsonRootObject => 'JSON 根节点必须是对象';

  @override
  String diy_presetInvalidData(String error) {
    return '无效的预设数据：$error';
  }

  @override
  String get diy_presetExportTitle => '导出预设';

  @override
  String get diy_presetImportTitle => '导入预设';

  @override
  String get diy_unknown => '未知';

  @override
  String get diy_presetShareHint => '复制以下内容分享给其他人';

  @override
  String get diy_presetPasteJsonHint => '在此粘贴预设 JSON 数据……';

  @override
  String get diy_presetPreview => '预设预览';

  @override
  String get diy_name => '名称';

  @override
  String get diy_description => '描述';

  @override
  String get diy_categoryCount => '类别数';

  @override
  String get diy_totalTagCount => '总标签数';

  @override
  String get diy_visibilityTitle => '可见性规则';

  @override
  String get diy_visibilitySubtitle => '根据条件控制类别可见性';

  @override
  String get diy_noVisibilityRules => '暂无可见性规则';

  @override
  String get diy_noVisibilityRulesHint => '添加规则以根据当前构图控制类别可见性';

  @override
  String get diy_notSet => '未设置';

  @override
  String get diy_targetCategory => '目标类别';

  @override
  String get diy_conditionType => '条件类型';

  @override
  String get diy_conditionValue => '条件值';

  @override
  String get diy_conditionValueHint => '标签名或值';

  @override
  String get diy_visibleWhenMatched => '条件匹配时可见';

  @override
  String get diy_conditionTagExists => '标签存在';

  @override
  String get diy_conditionTagNotExists => '标签不存在';

  @override
  String get diy_conditionValueEquals => '值等于';

  @override
  String get diy_conditionValueNotEquals => '值不等于';

  @override
  String get diy_conditionValueInList => '值在列表中';

  @override
  String get diy_conditionValueNotInList => '值不在列表中';

  @override
  String get diy_editTimeConditionTitle => '编辑时间条件';

  @override
  String get diy_timeDefaultName => '时间条件';

  @override
  String get diy_timeTitle => '时间条件';

  @override
  String get diy_timeSubtitle => '在指定日期范围内激活';

  @override
  String get diy_enableTimeCondition => '启用时间条件';

  @override
  String get diy_enableTimeConditionHint => '仅在设置的日期范围内生效';

  @override
  String get diy_christmas => '圣诞节';

  @override
  String get diy_christmasDescription => '圣诞节词库，在 12 月 1 日至 31 日启用';

  @override
  String get diy_halloween => '万圣节';

  @override
  String get diy_halloweenDescription => '万圣节词库，在 10 月 1 日至 31 日启用';

  @override
  String get diy_valentinesDay => '情人节';

  @override
  String get diy_valentinesDescription => '情人节词库，在 2 月 1 日至 14 日启用';

  @override
  String get diy_presetTemplates => '预设模板';

  @override
  String get diy_dateRange => '日期范围';

  @override
  String get diy_startDate => '开始日期';

  @override
  String get diy_endDate => '结束日期';

  @override
  String get diy_crossYearUnsupported => '暂不支持跨年的日期范围';

  @override
  String get diy_month => '月';

  @override
  String get diy_day => '日';

  @override
  String get diy_conditionName => '条件名称';

  @override
  String get diy_conditionNameHint => '输入条件名称';

  @override
  String get diy_repeatYearly => '每年重复';

  @override
  String get diy_repeatYearlyHint => '每年在相同日期范围内自动启用';

  @override
  String get diy_currentlyActive => '当前激活';

  @override
  String get diy_inactive => '未激活';

  @override
  String diy_daysRemaining(int count) {
    return '剩余 $count 天';
  }

  @override
  String diy_timeRangeSummary(
    String name,
    int startMonth,
    int startDay,
    int endMonth,
    int endDay,
  ) {
    return '$name（$startMonth 月 $startDay 日至 $endMonth 月 $endDay 日）';
  }

  @override
  String get diy_activeBadge => '生效中';

  @override
  String get common_optional => '可选';

  @override
  String get common_emptyValue => '（空）';

  @override
  String get common_previewLoadFailed => '无法加载预览';

  @override
  String get common_clickToRefresh => '点击刷新';

  @override
  String get common_clickToRetry => '点击重试';

  @override
  String get common_opening => '正在打开...';

  @override
  String get common_swap => '交换';

  @override
  String get common_prefix => '前缀';

  @override
  String get common_suffix => '后缀';

  @override
  String get common_cancelled => '已取消';

  @override
  String get common_minimum => '最小值';

  @override
  String get common_maximum => '最大值';

  @override
  String get addToLibrary_displayNameHint => '输入便于识别此条目的名称';

  @override
  String get addToLibrary_tagHint => '输入标签并按 Enter 添加';

  @override
  String get newPresetDialog_nameRequired => '请输入预设名称';

  @override
  String get newPresetDialog_nameLabel => '预设名称';

  @override
  String get newPresetDialog_nameHint => '输入新预设的名称';

  @override
  String get newPresetDialog_creationMode => '创建方式';

  @override
  String get drop_saveVibeBundle => '保存 Vibe Bundle';

  @override
  String drop_saveVibeBundleSubtitle(String name) {
    return '将 $name 等 Vibe 保存到库中';
  }

  @override
  String get drop_saveEncodedVibeSubtitle => '将预编码 Vibe 数据保存到库中';

  @override
  String get history_dragFilePreparationFailed => '拖拽文件准备失败，请稍后重试';

  @override
  String get history_dragFilePreparing => '正在准备拖拽文件...';

  @override
  String get history_dragFileNotReady => '拖拽文件尚未准备完成';

  @override
  String get vibe_import_overwriteOriginalParams => '直接替换原 Vibe 参数';

  @override
  String vibe_import_overwriteOriginalParamsHint(String name) {
    return '仅覆盖 $name 的库内参数，默认不勾选';
  }

  @override
  String vibe_import_reencodeFailed(String name) {
    return 'Vibe 重新编码失败: $name';
  }

  @override
  String get randomManager_releaseToDelete => '松开删除';

  @override
  String get randomManager_dragHereToDelete => '拖到这里删除';

  @override
  String get randomManager_keyboardShortcutsHint => '键盘快捷键（按 ? 查看）';

  @override
  String get localGallery_createFolder => '创建文件夹';

  @override
  String galleryScan_skipped(int count) {
    return '跳过 $count';
  }

  @override
  String galleryScan_withMetadata(int count) {
    return '有元数据 $count';
  }

  @override
  String galleryScan_failed(int count) {
    return '失败 $count';
  }

  @override
  String get galleryScan_processing => '处理中';

  @override
  String get galleryScan_pending => '待处理';

  @override
  String get vibeDetail_useAll => '使用全部';

  @override
  String get vibeDetail_longPressSetCover => '长按设为封面';

  @override
  String get vibeDetail_noPreviewImage => '无预览图像';

  @override
  String get vibeDetail_dropPreviewImage => '拖拽图片到此处设置预览图';

  @override
  String get vibeDetail_releasePreviewImage => '释放以设置预览图';

  @override
  String imagePicker_dropReadFailed(String error) {
    return '读取拖入图片失败: $error';
  }

  @override
  String get imagePicker_dropNoReadableImage => '拖入源未提供可读取的图片文件或图片链接';

  @override
  String get imagePicker_fileDataUnavailable => '无法读取文件数据';

  @override
  String imagePicker_fileSelectionFailed(String error) {
    return '选择文件失败: $error';
  }

  @override
  String imagePicker_directorySelectionFailed(String error) {
    return '选择目录失败: $error';
  }

  @override
  String get editor_effects => '效果';

  @override
  String get editor_shiftEdges => '扩展边缘';

  @override
  String editor_currentSize(int width, int height) {
    return '当前: $width x $height';
  }

  @override
  String get editor_edgeLeft => '左';

  @override
  String get editor_edgeRight => '右';

  @override
  String get editor_edgeTop => '上';

  @override
  String get editor_edgeBottom => '下';

  @override
  String get editor_enterNumber => '请输入数字';

  @override
  String get editor_nonNegativeNumber => '必须大于或等于 0';

  @override
  String editor_requestedSize(int width, int height) {
    return '请求尺寸: $width x $height';
  }

  @override
  String get editor_requestedSizeInvalid => '请求尺寸: 无效';

  @override
  String editor_appliedSize(int width, int height) {
    return '应用尺寸: $width x $height';
  }

  @override
  String get editor_appliedSizeInvalid => '应用尺寸: 无效';

  @override
  String editor_appliedEdges(int left, int top, int right, int bottom) {
    return '应用边缘: 左 $left、上 $top、右 $right、下 $bottom';
  }

  @override
  String get editor_appliedEdgesInvalid => '应用边缘: 无效';

  @override
  String editor_appliedDimensionLimit(int max) {
    return '应用后的尺寸不能超过 $max。';
  }

  @override
  String get savePreset_title => '另存为预设';

  @override
  String get savePreset_nameHint => '输入预设名称';

  @override
  String get savePreset_metadataDescription => '从图片元数据保存';

  @override
  String savePreset_vibeData(int count) {
    return 'Vibe 数据（$count）';
  }

  @override
  String get onlineGallery_videoLoadFailed => '视频加载失败';

  @override
  String get vibe_releaseToAddStyleReference => '松开后添加风格参考';

  @override
  String router_pageNotFound(String error) {
    return '页面未找到: $error';
  }
}

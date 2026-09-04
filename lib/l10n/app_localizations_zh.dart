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
  String get desktopWindow_minimize => '最小化';

  @override
  String get desktopWindow_maximize => '最大化';

  @override
  String get desktopWindow_restore => '还原';

  @override
  String get desktopWindow_close => '关闭窗口';

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
  String get common_select => '选择';

  @override
  String get common_reset => '重置';

  @override
  String get common_search => '搜索';

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
  String get common_apply => '应用';

  @override
  String get common_move => '移动';

  @override
  String get common_favorite => '收藏';

  @override
  String get common_unfavorite => '取消收藏';

  @override
  String get common_ok => '确定';

  @override
  String get common_replace => '替换';

  @override
  String get common_skip => '跳过';

  @override
  String get common_exit => '退出';

  @override
  String get common_folder => '文件夹';

  @override
  String get common_filter => '筛选';

  @override
  String get common_grid => '网格';

  @override
  String get common_list => '列表';

  @override
  String get common_grouped => '分组';

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
  String get nav_localGallery => '本地图库';

  @override
  String get nav_onlineGallery => '在线画廊';

  @override
  String get nav_statistics => '统计';

  @override
  String get nav_randomConfig => '随机配置';

  @override
  String get nav_dictionary => '词库';

  @override
  String get nav_discordCommunity => 'Discord 社群';

  @override
  String get nav_githubRepo => 'GitHub 仓库';

  @override
  String get nav_joinDiscord => '加入 Discord';

  @override
  String get nav_projectRepository => '项目仓库';

  @override
  String get nav_expandSidebar => '展开侧边栏';

  @override
  String get nav_collapseSidebar => '收起侧边栏';

  @override
  String get auth_login => '登录';

  @override
  String get auth_logout => '退出登录';

  @override
  String get auth_continueWithoutLogin => '跳过登录，进入主界面';

  @override
  String get auth_loginRequiredImageGeneration => '请先登录，再使用 NovelAI 生成图片。';

  @override
  String get auth_loginRequiredQueueExecution => '请先登录，再启动 NovelAI 生成队列。';

  @override
  String get auth_loginRequiredDirectorTools =>
      '请先登录，再使用 NovelAI Director Tools。';

  @override
  String get auth_loginRequiredNovelAiUpscale => '请先登录，再使用 NovelAI 云端超分。';

  @override
  String get auth_loginRequiredKritaBridge => '请先登录，再通过 Krita Bridge 生成图片。';

  @override
  String get auth_loginRequiredVibeEncoding => '请先登录，再使用 NovelAI 编码 Vibe 图片。';

  @override
  String get auth_email => '邮箱';

  @override
  String get auth_password => '密码';

  @override
  String get auth_loginButton => '登录';

  @override
  String get auth_loginFailed => '登录失败';

  @override
  String get auth_loginTip => '使用你的 NovelAI 账户登录\n所有数据仅存储在本地设备';

  @override
  String get auth_emailRequired => '请输入邮箱';

  @override
  String get auth_emailInvalid => '请输入有效的邮箱地址';

  @override
  String get auth_passwordRequired => '请输入密码';

  @override
  String get auth_tokenLoginCompact => 'Token登录';

  @override
  String get auth_tokenLoginRecommended => 'API Token 登录（推荐）';

  @override
  String get auth_credentialsLogin => '邮箱密码登录';

  @override
  String get auth_credentialsLoginUnavailable => '账号密码登录当前不可用，请使用 Token 登录';

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
      '第三方站点需兼容 NovelAI 图像生成 API；Token 将按 Bearer 方式发送。未实现 /user/subscription 的站点将跳过订阅信息。';

  @override
  String get auth_thirdPartyStreamingHint =>
      '如果第三方站点不支持流式生成，请前往「设置 > 生成 > 图像输出」，关闭「流式预览」后再生成。';

  @override
  String get anlas_thirdPartyUnavailable => '当前站点不提供 Anlas 余额信息';

  @override
  String get auth_thirdPartyApiSiteRequired => '请输入第三方 API 站点地址';

  @override
  String get auth_validateAndLogin => '验证并登录';

  @override
  String get auth_tokenGuide => '从 NovelAI 账户设置获取 Token';

  @override
  String get auth_addAccount => '添加账号';

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
  String get auth_removeAvatar => '移除头像';

  @override
  String get auth_selectFromGallery => '从相册选择';

  @override
  String get auth_quickLogin => '一键登录';

  @override
  String get auth_nicknameRequired => '请输入昵称';

  @override
  String auth_createdAt(Object date) {
    return '创建于 $date';
  }

  @override
  String get auth_error_networkTimeout => '连接超时，请检查网络';

  @override
  String get auth_error_networkError => '网络连接错误';

  @override
  String get auth_error_authFailed => '认证失败';

  @override
  String get auth_error_credentialsLoginUnavailable => '账号密码登录当前不可用';

  @override
  String get auth_error_credentialsLoginUnavailable_hint =>
      'NovelAI 官网账号密码登录需要网页安全验证，客户端无法完成，请改用 Persistent API Token。';

  @override
  String get auth_error_endpointIncompatible =>
      '该地址下未发现 NAI 兼容接口，请确认 API 地址是站点提供的服务根地址';

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
  String get settings_languageChinese => '简体中文';

  @override
  String get settings_languageTraditionalChinese => '繁體中文';

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
  String get settings_accountDetailsSection => '账户信息';

  @override
  String get settings_appearanceInterfaceSection => '界面呈现';

  @override
  String get settings_appearanceWorkflowSection => '生成页交互';

  @override
  String get settings_storageImagesSection => '图像';

  @override
  String get settings_storageLibrariesSection => '模型与资源库';

  @override
  String get settings_storageCacheSection => '缓存维护';

  @override
  String get settings_networkProxySection => '代理连接';

  @override
  String get settings_shortcutManagementSection => '快捷键管理';

  @override
  String get settings_aboutApplicationSection => '应用信息';

  @override
  String get settings_aboutUpdatesSection => '更新';

  @override
  String get settings_aboutResourcesSection => '项目资源';

  @override
  String get settings_integrationConnectionSection => '连接与可用性';

  @override
  String get settings_generationInputSection => '输入';

  @override
  String get settings_generationOutputSection => '图像输出';

  @override
  String get settings_generationRetrySection => '失败重试';

  @override
  String get settings_generationFeedbackSection => '完成提醒';

  @override
  String get settings_generationStreamPreview => '流式预览';

  @override
  String get settings_generationStreamPreviewSubtitle =>
      '生成时显示中间图像；关闭后将直接等待最终图像。';

  @override
  String get settings_alphaModeTitle => '透明图像 Alpha 模式';

  @override
  String get settings_alphaModeStraight => '直通（Straight）';

  @override
  String get settings_alphaModePremultiplied => '预乘（Premultiplied）';

  @override
  String get settings_alphaModeStraightDescription =>
      '保留未乘 Alpha 的 RGB，适合继续编辑，也是 NovelAI 官网默认值。';

  @override
  String get settings_alphaModePremultipliedDescription =>
      'RGB 已乘 Alpha，适合要求预乘输入的合成与渲染流程。';

  @override
  String get settings_promptAssistant => '提示词助手';

  @override
  String get settings_comfyUiDesktopOnly => '仅桌面端可用';

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
  String get settings_exportDiagnosticLogs => '导出诊断日志';

  @override
  String get settings_exportDiagnosticLogsSubtitle =>
      '导出最近日志和基础设备信息；会自动隐藏凭据与本地路径。';

  @override
  String get settings_exportDiagnosticLogsInProgress => '正在导出诊断日志';

  @override
  String get settings_exportDiagnosticLogsSuccess => '诊断日志已导出';

  @override
  String get settings_exportDiagnosticLogsEmpty => '暂无可导出的日志，请先开启日志记录并复现问题';

  @override
  String get settings_exportDiagnosticLogsFailed => '诊断日志导出失败，请重试';

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
  String get settings_pathSavedRestartRequired => '路径已更新，重启后生效';

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
  String get settings_tokenAccount => 'Token 账号';

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
  String settings_nicknameTooLong(int maxLength) {
    return '昵称不能超过$maxLength个字符';
  }

  @override
  String get settings_nicknameUpdated => '昵称已更新';

  @override
  String get settings_avatarUpdated => '头像已更新';

  @override
  String get settings_avatarRemoved => '头像已移除';

  @override
  String get settings_setAsDefaultSuccess => '已设为默认账号';

  @override
  String get generation_title => '生成';

  @override
  String get generation_gestureEditPrompt => '下滑编辑提示词';

  @override
  String get generation_gestureOpenAgent => '上滑打开 AI 助手';

  @override
  String generation_promptOverviewCharacters(Object count) {
    return '$count 字';
  }

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
  String get generation_pleaseInputPrompt => '请输入提示词';

  @override
  String get generation_emptyPromptHint => '输入提示词并点击生成';

  @override
  String get generation_imageWillShowHere => '图像将在这里显示';

  @override
  String get generation_generationFailed => '生成失败';

  @override
  String get generation_streamingUnsupported => '站点不支持流式生成';

  @override
  String get generation_streamingUnsupportedHint =>
      '请前往「设置 > 生成 > 图像输出」，关闭「流式预览」后重试。';

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
  String get agentChat_tab => '聊天';

  @override
  String get nav_agent => '智能体';

  @override
  String get agentChat_inputHint => '给 AI 助手发消息…';

  @override
  String get agentChat_inputHintWithSlash => '给 AI 助手发消息，输入 / 引用技能…';

  @override
  String get agentChat_slashMenu => '技能与会话命令';

  @override
  String get agentChat_slashSkills => '技能';

  @override
  String get agentChat_slashSession => '会话';

  @override
  String get agentChat_addAttachment => '添加附件或引用';

  @override
  String get agentChat_photoLibrary => '相册';

  @override
  String get agentChat_currentCanvas => '当前画布';

  @override
  String get agentChat_referenceGallery => '参考图库';

  @override
  String get agentChat_resourceLibrary => '资源库';

  @override
  String get agentChat_generationHistory => '生成历史';

  @override
  String get agentChat_localGallery => '本地图库';

  @override
  String get agentChat_tagLibrary => '标签词库';

  @override
  String get agentChat_vibeLibrary => 'Vibe 库';

  @override
  String get agentChat_preciseRefLibrary => '精准参考库';

  @override
  String get agentChat_generatedImage => '生成图片';

  @override
  String get agentChat_reference => '引用资源';

  @override
  String get agentChat_noResources => '这里暂时没有可用资源。';

  @override
  String agentChat_imageTooLarge(String fileName, int maxSizeMB) {
    return '$fileName 超过 $maxSizeMB MB。';
  }

  @override
  String get agentChat_enableWebAccess => '开启联网';

  @override
  String get agentChat_disableWebAccess => '关闭联网';

  @override
  String get agentChat_webAccessLabel => '联网';

  @override
  String get agentChat_contextUsageLabel => '上下文';

  @override
  String agentChat_unsupportedImageFormat(Object fileName) {
    return '不支持的图片格式：$fileName';
  }

  @override
  String get agentChat_newChat => '新建聊天';

  @override
  String get agentChat_searchSessions => '搜索聊天';

  @override
  String get agentChat_send => '发送';

  @override
  String get agentChat_sendEmptyHint => '输入消息或添加图片后即可发送';

  @override
  String get agentChat_sendUnavailableHint => 'AI 助手尚未准备好发送消息';

  @override
  String get agentChat_stop => '停止';

  @override
  String get agentChat_queued => '已排队';

  @override
  String get agentChat_queueSteering => '插入当前工作';

  @override
  String get agentChat_queueFollowUp => '当前任务后继续';

  @override
  String get agentChat_thinking => '思考中…';

  @override
  String get agentChat_toolRunning => '调用工具中';

  @override
  String get agentChat_reasoning => '思考过程';

  @override
  String get agentChat_reasoningLevel => '推理强度';

  @override
  String get agentChat_reasoningOff => '关闭';

  @override
  String get agentChat_reasoningMinimal => '最少';

  @override
  String get agentChat_reasoningLow => '低';

  @override
  String get agentChat_reasoningMedium => '中';

  @override
  String get agentChat_reasoningHigh => '高';

  @override
  String get agentChat_reasoningXHigh => '极高';

  @override
  String get agentChat_reasoningMax => '最大';

  @override
  String get agentChat_jumpToLatest => '回到最新';

  @override
  String agentChat_toolGroupCount(int count) {
    return '执行了 $count 项操作';
  }

  @override
  String get agentChat_working => '正在工作';

  @override
  String agentChat_workingFor(String duration) {
    return '已工作 $duration';
  }

  @override
  String get agentChat_worked => '工作完成';

  @override
  String agentChat_workedFor(String duration) {
    return '工作耗时 $duration';
  }

  @override
  String agentChat_workItemCount(int count) {
    return '$count 项';
  }

  @override
  String agentChat_ranCommands(int count) {
    return '执行了 $count 条命令';
  }

  @override
  String agentChat_exploredItems(int count) {
    return '探索了 $count 项资源';
  }

  @override
  String agentChat_earlierMessages(int count) {
    return '更早的 $count 条消息';
  }

  @override
  String get agentChat_loadEarlierMessages => '更早消息';

  @override
  String agentChat_turnNavigation(int number, String preview) {
    return '第 $number 轮：$preview';
  }

  @override
  String get agentChat_phasePreparing => '准备中';

  @override
  String get agentChat_phaseResponding => '回复中';

  @override
  String get agentChat_phaseAwaitingApproval => '等待确认';

  @override
  String get agentChat_phaseStopping => '正在停止';

  @override
  String get agentChat_contextUnavailable => '上下文用量不可用';

  @override
  String get agentChat_toolGenerateImage => '生成图片';

  @override
  String get agentChat_toolQueueImageTask => '添加图片任务';

  @override
  String get agentChat_toolInterrogateImage => '反推图片提示词';

  @override
  String get agentChat_toolRecentImages => '查看最近图片';

  @override
  String get agentChat_toolInspectImages => '检查图片';

  @override
  String get agentChat_toolDisplayImages => '展示图片';

  @override
  String get agentChat_toolResult => '结果';

  @override
  String get agentChat_toolGenerationStatus => '查看生成状态';

  @override
  String get agentChat_toolGetGenerationSettings => '查看生成设置';

  @override
  String get agentChat_toolUpdateGenerationSettings => '更新生成设置';

  @override
  String get agentChat_toolGetGenerationSourceImage => '查看图生图源图';

  @override
  String get agentChat_toolSetGenerationSourceImage => '载入图生图源图';

  @override
  String get agentChat_toolClearGenerationSourceImage => '清除图生图源图';

  @override
  String get agentChat_toolUpdateGenerationSourceSettings => '调整图生图强度';

  @override
  String get agentChat_toolPromptState => '查看提示词状态';

  @override
  String get agentChat_toolSetPositivePrompt => '设置正向提示词';

  @override
  String get agentChat_toolSetNegativePrompt => '设置负向提示词';

  @override
  String get agentChat_toolAddCharacter => '添加角色';

  @override
  String get agentChat_toolUpdateCharacter => '更新角色';

  @override
  String get agentChat_toolRemoveCharacter => '删除角色';

  @override
  String get agentChat_toolReadSkill => '读取 Skill';

  @override
  String get agentChat_toolReadSkillResource => '读取 Skill 资源';

  @override
  String get agentChat_toolSkillDiagnostics => '查看 Skill 诊断';

  @override
  String get agentChat_toolReloadSkills => '重新加载 Skills';

  @override
  String get agentChat_toolSearchTags => '搜索标签';

  @override
  String get agentChat_toolReadFile => '读取文件';

  @override
  String get agentChat_toolWebSearch => '联网搜索';

  @override
  String get agentChat_toolWebRead => '读取网页';

  @override
  String get agentChat_toolApplication => '修改应用数据';

  @override
  String get agentChat_toolGallery => '使用画廊';

  @override
  String get agentChat_toolReferenceLibrary => '使用参考图库';

  @override
  String get agentChat_toolPrepareGeneration => '准备生成任务';

  @override
  String get agentChat_toolInspectGeneration => '查看生成草稿';

  @override
  String get agentChat_toolUpdateGeneration => '修改生成草稿';

  @override
  String get agentChat_toolCancelGeneration => '取消生成草稿';

  @override
  String get agentChat_toolSubmitGeneration => '提交生成任务';

  @override
  String get agentChat_toolCreateInpaint => '创建手动局部重绘草稿';

  @override
  String get agentChat_toolListInpaint => '查看局部重绘草稿列表';

  @override
  String get agentChat_toolInspectInpaint => '查看局部重绘草稿';

  @override
  String get agentChat_toolCancelInpaint => '取消局部重绘草稿';

  @override
  String get agentChat_toolReeditInpaint => '重新编辑局部重绘草稿';

  @override
  String get agentChat_toolSubmitInpaint => '提交局部重绘任务';

  @override
  String get agentChat_toolCreateInpaintMask => '创建重绘蒙版';

  @override
  String get agentChat_toolExpandInpaintCanvas => '扩展画布';

  @override
  String get agentChat_toolLoadInpaintPanel => '装载重绘草稿到面板';

  @override
  String get agentChat_manualInpaintTitle => '手动局部重绘';

  @override
  String get agentChat_manualInpaintComplete => '完成并返回智能体';

  @override
  String get agentChat_resourceUnavailable => '资源不可用';

  @override
  String get agentChat_addResource => '发送到智能体';

  @override
  String get agentChat_resourceAdded => '已添加到 Agent 输入区';

  @override
  String agentChat_addResourceFailed(String error) {
    return '添加引用失败：$error';
  }

  @override
  String agentChat_approvalEstimatedAnlas(int cost) {
    return '预计消耗：$cost Anlas';
  }

  @override
  String get agentChat_needSetup => '未配置聊天模型。请先在设置中添加支持工具调用的供应商。';

  @override
  String get agentChat_heroTitle => '今天想做什么？';

  @override
  String get agentChat_heroSubtitle => '准备生成角色提示词、整理灵感或优化设置。';

  @override
  String get agentChat_moreActions => '更多操作';

  @override
  String get agentChat_compact => '压缩上下文';

  @override
  String get agentChat_compacting => '正在压缩上下文…';

  @override
  String agentChat_compactDone(String before, String after) {
    return '已压缩上下文：$before → $after';
  }

  @override
  String get agentChat_compactNotNeeded => '当前上下文无需压缩';

  @override
  String get agentChat_compactBusy => '正在生成回复，请稍后再压缩';

  @override
  String get agentChat_compactUnavailable => '上下文用量不可用，无法压缩';

  @override
  String agentChat_compactFailed(String error) {
    return '压缩上下文失败：$error';
  }

  @override
  String get agentChat_requestFailed => '请求失败，请重试。';

  @override
  String get agentChat_errorDetails => '错误详情';

  @override
  String get agentChat_modelLabel => '模型';

  @override
  String get agentChat_modelPickerTitle => '选择模型';

  @override
  String get agentChat_searchModels => '搜索模型';

  @override
  String get agentChat_searchModelsHint => '模型名称、ID 或提供商';

  @override
  String get agentChat_clearModelSearch => '清除模型搜索';

  @override
  String get agentChat_noModelResults => '没有符合搜索条件的模型。';

  @override
  String get agentChat_noModel => '未配置模型';

  @override
  String get agentChat_untitled => '新会话';

  @override
  String get agentChat_renameHint => '会话名称';

  @override
  String get agentChat_suggestion1 => '检查当前生成设置';

  @override
  String get agentChat_suggestion2 => '从画廊整理提示词';

  @override
  String get agentChat_suggestion3 => '帮我优化角色标签';

  @override
  String get agentChat_permissionMode => 'Agent 权限';

  @override
  String get agentChat_permissionSafe => '安全模式';

  @override
  String get agentChat_permissionSafeDescription => '仅运行无副作用工具';

  @override
  String get agentChat_permissionAsk => '询问模式';

  @override
  String get agentChat_permissionAskDescription => '敏感操作执行前询问';

  @override
  String get agentChat_permissionFull => '完全访问';

  @override
  String get agentChat_permissionFullDescription => '不询问并允许访问工作区外文件';

  @override
  String agentChat_approvalTitle(Object toolName) {
    return '允许执行 $toolName？';
  }

  @override
  String get agentChat_approvalDescription => '此工具会读取本地数据、修改应用状态或产生费用。';

  @override
  String get agentChat_approvalAllow => '允许一次';

  @override
  String get agentChat_approvalDeny => '拒绝';

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
  String generation_opusUsageRemaining(Object percent) {
    return 'Opus 免费生成剩余 $percent%';
  }

  @override
  String generation_opusUsageEstimate(Object count) {
    return '约可再生成 $count 张';
  }

  @override
  String get generation_opusUsageRefill => '额度会随时间自动恢复';

  @override
  String get generation_opusUsageExhausted =>
      'Opus 免费额度已用完，V5 生成将消耗 Anlas，额度会随时间自动恢复';

  @override
  String get generation_imageSize => '图像尺寸';

  @override
  String get generation_transparentBackground => '透明背景';

  @override
  String generation_e2eUpscaleHint(Object size) {
    return '服务端输出 $size';
  }

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
  String get generation_previewApplySeed => '使用当前图片的种子';

  @override
  String get generation_imageComparison => '对比';

  @override
  String get generation_imageComparisonHint => '对比生成图与本次结果的来源图';

  @override
  String get generation_imageComparisonDivider => '图像对比分割线';

  @override
  String get generation_transparencyBackgroundTitle => '透明部分显示';

  @override
  String get generation_transparencyChecker => '跟随主题棋盘格';

  @override
  String get generation_transparencyCheckerLight => '浅色棋盘格';

  @override
  String get generation_transparencyCheckerDark => '深色棋盘格';

  @override
  String get generation_transparencyNone => '无';

  @override
  String get generation_transparencyBlack => '黑色';

  @override
  String get generation_transparencyWhite => '白色';

  @override
  String get generation_transparencyGray => '灰色';

  @override
  String get generation_transparencyRed => '红色';

  @override
  String get generation_transparencyGreen => '绿色';

  @override
  String get generation_transparencyBlue => '蓝色';

  @override
  String get generation_transparencyCustom => '自定义颜色';

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
  String get generation_smeaDescription => '高分辨率采样器会在超过一定图像尺寸时自动使用';

  @override
  String generation_cfgRescale(Object value) {
    return 'CFG 重缩放：$value';
  }

  @override
  String get generation_noiseSchedule => '噪声调度';

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
  String get prompt_finalPrompt => '最终生效提示词';

  @override
  String get prompt_finalNegative => '最终生效负面词';

  @override
  String get prompt_composition => '提示词构成';

  @override
  String get prompt_expandFull => '展开全文';

  @override
  String get prompt_collapseFull => '收起全文';

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
  String get prompt_inputPrompt => '描述你想生成的画面';

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
  String get prompt_smartAutocomplete => '智能补全';

  @override
  String get prompt_smartAutocompleteSubtitle => '输入时显示标签建议';

  @override
  String get prompt_autoFormat => '自动格式化';

  @override
  String get prompt_autoFormatSubtitle => '中文逗号转英文、标签内空格转下划线（保留换行）';

  @override
  String get prompt_highlightEmphasis => '高亮强调';

  @override
  String get prompt_highlightEmphasisSubtitle => '括号和权重语法高亮显示';

  @override
  String get prompt_sdSyntaxAutoConvert => 'SD语法自动转换';

  @override
  String get prompt_sdSyntaxAutoConvertSubtitle => '失焦时将SD权重语法转换为NAI格式';

  @override
  String get prompt_resolveAliasOnCopy => '复制时展开词库';

  @override
  String get prompt_resolveAliasOnCopySubtitle => '复制或剪切时把 <词库名> 替换为词库内容';

  @override
  String get prompt_cooccurrenceRecommendation => '共现标签推荐';

  @override
  String get prompt_cooccurrenceRecommendationSubtitle =>
      '选中标签后自动推荐，也可按 Ctrl+Shift+Space 或 Ctrl+单击';

  @override
  String get prompt_regexRulesManage => '正则替换规则…';

  @override
  String prompt_regexRulesCount(int count) {
    return '已配置 $count 条规则';
  }

  @override
  String prompt_regexReplaceApplied(int count) {
    return '正则替换 $count 条';
  }

  @override
  String prompt_regexInvalidRules(Object names) {
    return '已跳过无效的正则规则：$names';
  }

  @override
  String get regexRules_title => '正则替换规则';

  @override
  String get regexRules_hint =>
      '规则按顺序作用于整段提示词，早于 SD 转换和自动格式化执行。替换内容里可用 \$1、\$2 引用捕获组。';

  @override
  String get regexRules_empty => '还没有规则，点下面的按钮新建一条';

  @override
  String get regexRules_add => '新建规则';

  @override
  String get regexRules_unnamed => '未命名规则';

  @override
  String get regexRules_invalidBadge => '无效';

  @override
  String get regexRules_deleteConfirmTitle => '删除规则';

  @override
  String regexRules_deleteConfirmMessage(Object name) {
    return '确定删除「$name」吗？此操作不可撤销。';
  }

  @override
  String get regexRules_newTitle => '新建规则';

  @override
  String get regexRules_editTitle => '编辑规则';

  @override
  String get regexRules_nameLabel => '规则名称（可选）';

  @override
  String get regexRules_nameHint => '例如：统一发色写法';

  @override
  String get regexRules_patternLabel => '匹配（正则表达式）';

  @override
  String get regexRules_patternHint => '例如：\\bblue[ _]hair\\b';

  @override
  String get regexRules_replacementLabel => '替换为';

  @override
  String get regexRules_replacementHint => '例如：aqua hair';

  @override
  String get regexRules_caseSensitive => '区分大小写';

  @override
  String get regexRules_patternRequired => '匹配内容不能为空';

  @override
  String regexRules_patternInvalid(Object error) {
    return '正则表达式无效：$error';
  }

  @override
  String get regexRules_testTitle => '测试';

  @override
  String get regexRules_testInputHint => '粘贴一段提示词看看替换效果';

  @override
  String get regexRules_testNoChange => '无变化';

  @override
  String get regexRules_testNoRules => '没有启用中的规则';

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
  String get config_newPreset => '新建预设';

  @override
  String get config_deletePreset => '删除预设';

  @override
  String get img2img_title => '图生图';

  @override
  String get img2img_enabled => '已启用';

  @override
  String get img2img_sourceImage => '源图像';

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
  String get img2img_uploadImage => '上传图片';

  @override
  String get img2img_drawSketch => '绘制草图';

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
  String get img2img_directorConfirmTitle => '确认 Anlas 消耗';

  @override
  String img2img_directorConfirmContent(Object tool, int cost) {
    return '运行$tool预计消耗 $cost Anlas，是否继续？';
  }

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
  String get img2img_enhanceScaleMax => '最大';

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
  String get img2img_novelAiCloudUpscale => 'NovelAI 云端超分 (固定 2x 放大)';

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
      '未发现可用的 SeedVR2 模型，请刷新模型列表，并检查 ComfyUI 原生 models/diffusion_models、models/vae 或 SeedVR2 自定义节点模型目录。';

  @override
  String get img2img_noRegularUpscaleModels =>
      '未发现普通超分模型，请刷新模型列表或检查 models/upscale_models。';

  @override
  String get img2img_useNativeSeedvr2Workflow =>
      '将使用 ComfyUI 原生 SeedVR2 一步超分流程。';

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
  String get img2img_seedvr2Engine => 'SeedVR2 引擎';

  @override
  String get img2img_seedvr2EngineAuto => '自动';

  @override
  String get img2img_seedvr2EngineNative => '原生';

  @override
  String get img2img_seedvr2EngineLegacy => '兼容节点';

  @override
  String get img2img_seedvr2EngineResolvedNative => '当前使用 ComfyUI 原生 SeedVR2。';

  @override
  String get img2img_seedvr2EngineResolvedLegacy => '当前使用已安装的 SeedVR2 自定义节点。';

  @override
  String get img2img_seedvr2EngineUnavailable =>
      '当前选择的 SeedVR2 引擎或所需模型不可用，请刷新模型列表或切换引擎。';

  @override
  String get img2img_seedvr2VaeTileHint => '设置 SeedVR2 VAE 编码与解码的分块尺寸。';

  @override
  String get img2img_seedvr2UseTiledUpscale => '使用分块放大';

  @override
  String get img2img_seedvr2UseTiledUpscaleHint =>
      '启用后改用 SeedVR2TilingUpscaler，适合大图或显存压力较高的场景。';

  @override
  String get settings_comfyUiSeedvr2EmbedNaiMetadata =>
      '在 SeedVR2 结果中写入 NAI 生成参数';

  @override
  String get settings_comfyUiSeedvr2EmbedNaiMetadataHint =>
      '默认关闭。开启后会写入启动器当前的提示词和生成参数；关闭时保留 ComfyUI 返回的原始 PNG 元数据。';

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
  String get img2img_upscalePanelOpened => '已打开图生图超分面板';

  @override
  String get editor_done => '完成';

  @override
  String get editor_tolerance => '容差';

  @override
  String get editor_intensity => '强度';

  @override
  String get editor_sourcePoint => 'Alt+点击设置源点';

  @override
  String get editor_brushPresets => '笔刷预设';

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
  String get editor_clearSelection => '清除选区';

  @override
  String get editor_resetView => '重置视图';

  @override
  String get editor_zoom => '缩放';

  @override
  String get editor_toolBrush => '画笔';

  @override
  String get editor_toolEraser => '橡皮擦';

  @override
  String get editor_toolFill => '填充';

  @override
  String get editor_toolMagicWand => '魔棒';

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
  String get editor_shortcutUndo => '撤销 (Ctrl+Z)';

  @override
  String get editor_shortcutRedo => '重做 (Ctrl+Y)';

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
  String get vibe_sourceType_v4vibe => 'Vibe 文件';

  @override
  String get vibe_sourceType_bundle => '组合包';

  @override
  String get vibe_sourceType_image => '图片';

  @override
  String get vibe_sourceType => '数据源';

  @override
  String get vibe_reuseButton => '一键复用';

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
  String get character_buttonLabel => '角色';

  @override
  String get character_addCharacter => '添加角色';

  @override
  String character_limitReached(Object limit) {
    return '已达当前模型的角色上限（$limit 个）';
  }

  @override
  String character_number(Object index) {
    return '角色 $index';
  }

  @override
  String get character_summaryEmpty => '未添加角色';

  @override
  String character_summaryEnabled(int count, String name) {
    return '已启用 $count 个 · $name';
  }

  @override
  String character_summaryMore(int count, String name, int additional) {
    return '已启用 $count 个 · $name +$additional';
  }

  @override
  String character_summaryAllDisabled(int count) {
    return '已启用 0 个 · 已停用 $count 个';
  }

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
  String get gallery_promptCopied => '已复制提示词';

  @override
  String get gallery_seedCopied => '已复制 Seed';

  @override
  String get gallery_sendToKritaAction => '发送到 Krita';

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
  String get gallery_upscale => '放大';

  @override
  String get gallery_sentToImg2Img => '图片已发送到图生图';

  @override
  String get gallery_sentToReversePrompt => '图片已发送到反推模块';

  @override
  String gallery_sendFailed(Object error) {
    return '发送失败: $error';
  }

  @override
  String get preset_presetName => '预设名称';

  @override
  String get onlineGallery_search => '搜索';

  @override
  String get onlineGallery_popular => '热门';

  @override
  String get onlineGallery_sourceDoesNotSupportPopular => '当前站点不支持热门榜单';

  @override
  String get onlineGallery_favorites => '收藏';

  @override
  String get onlineGallery_searchFavorites => '搜索收藏的标题、作者或标签…';

  @override
  String get onlineGallery_savedLocally => '已保存在本地';

  @override
  String get onlineGallery_savedInCloud => '已保存在云端';

  @override
  String get onlineGallery_saveVisibleLocally => '保存本页到本地';

  @override
  String get onlineGallery_visibleFavoritesAlreadySaved => '本页内容已全部保存到本地收藏';

  @override
  String get onlineGallery_localFavoritesPartialFailure => '本地收藏加载失败，已保留云端结果';

  @override
  String get onlineGallery_cloudFavoritesPartialFailure => '云端收藏加载失败，已保留本地结果';

  @override
  String onlineGallery_visibleFavoritesSaved(int count) {
    return '已保存 $count 项到本地收藏';
  }

  @override
  String onlineGallery_saveFavoritesFailed(String error) {
    return '保存本地收藏失败：$error';
  }

  @override
  String get onlineGallery_searchTags => '搜索标签...';

  @override
  String onlineGallery_maxTagsExceeded(int max) {
    return '最多可组合搜索 $max 个标签';
  }

  @override
  String get onlineGallery_tagDetailsIncomplete =>
      '部分作品的完整标签获取失败，未验证的作品已排除；请重试以补全结果。';

  @override
  String get onlineGallery_unsupportedMetatag =>
      '当前来源或模式不支持元标签语法，请改用普通标签或切换到来源搜索。';

  @override
  String onlineGallery_multiTagScanning(int requests, int candidates) {
    return '正在组合检索：已请求 $requests 页，检查 $candidates 个候选作品';
  }

  @override
  String get onlineGallery_scanPaused => '已分批检查多页候选，尚未找到足够结果。可继续扫描后续页面。';

  @override
  String get onlineGallery_continueScanning => '继续扫描';

  @override
  String get onlineGallery_refresh => '刷新';

  @override
  String get onlineGallery_random => '随机';

  @override
  String get onlineGallery_randomRedraw => '再抽一组';

  @override
  String get onlineGallery_randomDrawing => '抽取中…';

  @override
  String get onlineGallery_randomExhausted => '当前范围暂无更多未见图片';

  @override
  String get onlineGallery_randomDrawNoMatch => '本次未抽中符合条件的图片，可以继续抽取。';

  @override
  String get onlineGallery_randomRestart => '重新开始';

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
  String get onlineGallery_score => '评分';

  @override
  String get onlineGallery_ratingLabel => '分级';

  @override
  String get onlineGallery_favCount => '收藏';

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
  String get onlineGallery_promptTagCategories => '提示词类别';

  @override
  String get onlineGallery_promptTagCategoriesTooltip => '选择发送或加入队列时包含的标签类别';

  @override
  String get onlineGallery_keepOnePromptTagCategory => '至少保留一个提示词类别';

  @override
  String get onlineGallery_addToQueue => '加入队列';

  @override
  String get onlineGallery_sendToTextToImage => '发送到文生图';

  @override
  String get onlineGallery_sentToTextToImage => '已发送到文生图';

  @override
  String get onlineGallery_replaceConfig => '替换配置';

  @override
  String get onlineGallery_replaceConfigDescription =>
      '选择要同时替换的生成配置；未选择的项目会保留当前值';

  @override
  String get onlineGallery_replaceConfigNaiOnly => '仅包含可识别 NovelAI 配置的图片支持此选项';

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
  String get onlineGallery_noImageUrl => '此图片没有可用地址';

  @override
  String get onlineGallery_pinchToZoom => '双指缩放';

  @override
  String get onlineGallery_metadata => '元数据';

  @override
  String onlineGallery_addedToQueueWithCount(Object count) {
    return '已加入队列，当前共 $count 个待执行任务';
  }

  @override
  String get onlineGallery_queueFullMax => '队列已满（最多50项）';

  @override
  String get onlineGallery_chooseDownloadDirectory => '选择下载目录';

  @override
  String get onlineGallery_downloadStarted => '开始下载...';

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
  String get onlineGallery_sourceGeneralOnly => '该站点仅提供全年龄内容';

  @override
  String get onlineGallery_sourceUnrated => '源未分级';

  @override
  String get onlineGallery_sourceUnratedTooltip => '该站点没有提供可靠的内容分级，无法在本地准确推断';

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
  String get onlineGallery_blacklistShort => '屏蔽';

  @override
  String get onlineGallery_blacklistTags => '黑名单标签';

  @override
  String get onlineGallery_outputFilter => '输出过滤';

  @override
  String get onlineGallery_outputFilterShort => '输出';

  @override
  String get onlineGallery_outputFilterTooltip => '管理复制、发送和加入队列时自动剔除的标签';

  @override
  String get onlineGallery_outputFilterTitle => '输出过滤标签';

  @override
  String get onlineGallery_outputFilterSubtitle =>
      '图片仍会正常显示；这些标签只会从复制、发送和队列提示词中精确剔除。';

  @override
  String get onlineGallery_outputFilterAddHint => '添加需要从输出中剔除的标签';

  @override
  String get onlineGallery_outputFilterInputHint => '支持逗号、中文逗号、顿号或换行分隔';

  @override
  String get onlineGallery_outputFilterEmpty => '暂未设置输出过滤标签';

  @override
  String get onlineGallery_outputFilterRestoreDefaults => '恢复默认过滤词';

  @override
  String get onlineGallery_outputFilterClearTitle => '清空输出过滤？';

  @override
  String get onlineGallery_outputFilterClearConfirm =>
      '清空后，水印和马赛克等标签也会重新出现在复制与发送的提示词中。';

  @override
  String get onlineGallery_addTagToOutputFilter => '加入输出过滤';

  @override
  String get onlineGallery_outputFilterAlreadyAdded => '已在输出过滤中';

  @override
  String get onlineGallery_outputFilterMenuHint => '保留图片，只从输出提示词中剔除此标签';

  @override
  String get onlineGallery_addTagToBlacklist => '加入黑名单';

  @override
  String get onlineGallery_blacklistAlreadyAdded => '已在黑名单中';

  @override
  String get onlineGallery_blacklistMenuHint => '隐藏包含此标签的画廊图片';

  @override
  String get onlineGallery_outputFilteredTagTooltip =>
      '此标签会在复制、发送和加入队列时被剔除；右键可管理';

  @override
  String get onlineGallery_tagContextMenuTooltip => '右键可加入黑名单或输出过滤';

  @override
  String onlineGallery_outputFilterTagAdded(Object tag) {
    return '已将 $tag 加入输出过滤';
  }

  @override
  String onlineGallery_blacklistTagAdded(Object tag) {
    return '已将 $tag 加入黑名单';
  }

  @override
  String get onlineGallery_blacklistTitle => '在线画廊黑名单';

  @override
  String get onlineGallery_blacklistSubtitle => '所有在线画廊共用这份列表；离线时仍会正常屏蔽。';

  @override
  String get onlineGallery_blacklistCloudDescription =>
      '已连接 Danbooru；本地修改会在安全合并后同步';

  @override
  String get onlineGallery_blacklistCloudLoginRequired =>
      '本地黑名单仍然有效；登录 Danbooru 后可以同步';

  @override
  String get onlineGallery_blacklistCloudUnavailable =>
      '本地黑名单仍然有效；验证 Danbooru 连接后会恢复云端同步';

  @override
  String get onlineGallery_addBlacklistTagHint => '添加黑名单标签';

  @override
  String get onlineGallery_noLocalBlacklistTags => '暂无黑名单标签';

  @override
  String get onlineGallery_pullBlacklist => '拉取云端';

  @override
  String get onlineGallery_pushBlacklist => '推送到云端';

  @override
  String get onlineGallery_pushBlacklistConfirmTitle => '用统一列表覆盖云端？';

  @override
  String get onlineGallery_pushBlacklistConfirmBody =>
      '这会完整替换 Danbooru 云端黑名单。普通自动同步不会删除无法识别的高级规则，但本次全量推送会删除它们。';

  @override
  String get onlineGallery_blacklistPushSucceeded => '已用本地黑名单覆盖云端';

  @override
  String get onlineGallery_blacklistSyncFailedMessage => '黑名单同步失败，请检查登录状态与网络连接';

  @override
  String onlineGallery_blacklistSaveFailed(String error) {
    return '保存黑名单失败：$error';
  }

  @override
  String get onlineGallery_autoSyncOnStartup => '启动时刷新云端列表';

  @override
  String get onlineGallery_autoSyncOnStartupSubtitle => '安全合并云端新增标签，不删除本地标签';

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
  String get onlineGallery_blacklistImportTitle => '批量导入标签';

  @override
  String get onlineGallery_blacklistImportHint => '每行或使用逗号分隔一个标签';

  @override
  String onlineGallery_blacklistImported(Object count) {
    return '已新增 $count 个标签';
  }

  @override
  String get onlineGallery_blacklistClearTitle => '清空统一黑名单？';

  @override
  String get onlineGallery_blacklistClearBody =>
      '画廊将立即停止使用这些标签过滤。云端不会自动清空，可以撤销本次操作。';

  @override
  String onlineGallery_blacklistPullSummary(
    Object added,
    Object existing,
    Object skipped,
    Object opaque,
  ) {
    return '已新增 $added 项，已有 $existing 项，跳过已删除 $skipped 项；保留 $opaque 条云端高级规则';
  }

  @override
  String onlineGallery_blacklistPushDiff(
    Object added,
    Object removed,
    Object opaque,
  ) {
    return '云端将新增 $added 项、删除 $removed 项，并删除 $opaque 条高级规则。';
  }

  @override
  String get onlineGallery_blacklistCloudEmptyConfirm => '确认清空云端黑名单';

  @override
  String get onlineGallery_blacklistMigrationConfirm =>
      '此列表包含旧版本中无法确认账号归属的云端标签；确认将它们同步到当前账号';

  @override
  String get onlineGallery_bulkFavorite => '批量收藏';

  @override
  String get onlineGallery_bulkDownload => '批量下载';

  @override
  String onlineGallery_addedTasksToQueue(Object count) {
    return '已添加 $count 个任务到队列';
  }

  @override
  String onlineGallery_queueBatchCompleted(
    Object added,
    Object prepareFailed,
    Object queueSkipped,
  ) {
    return '已加入 $added 个任务；$prepareFailed 个未能准备；$queueSkipped 个因队列已满未加入';
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
  String onlineGallery_downloadSelectedCompletedWithSkipped(
    Object success,
    Object failed,
    Object skipped,
  ) {
    return '下载完成：成功 $success，失败 $failed，跳过 $skipped 个纯文本词条';
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
  String get onlineGallery_aiTagQuery => '搜索作品、作者、标题、标签或模型';

  @override
  String get onlineGallery_aiTagPromptQuery =>
      'AI Prompt 搜索（可搜索 artist: 等 Prompt 原文）';

  @override
  String get onlineGallery_sourceQuickTagCloud => '法典图鉴';

  @override
  String get onlineGallery_codexSearchHint => '搜索标题、提示词、备注、分类或贡献者';

  @override
  String get onlineGallery_codexLabel => '法典';

  @override
  String get onlineGallery_codexSelect => '选择法典';

  @override
  String get onlineGallery_codexAll => '全部法典';

  @override
  String get onlineGallery_codexBrowse => '浏览';

  @override
  String get onlineGallery_codexLatest => '本次更新';

  @override
  String get onlineGallery_codexRecent => '最近浏览';

  @override
  String get onlineGallery_codexCategory => '分类';

  @override
  String get onlineGallery_codexAllCategories => '全部分类';

  @override
  String get onlineGallery_codexUpdateBatch => '更新批次';

  @override
  String get onlineGallery_codexMediaFilter => '配图';

  @override
  String get onlineGallery_codexAllEntries => '全部词条';

  @override
  String get onlineGallery_codexWithImages => '只看有图';

  @override
  String get onlineGallery_codexWithoutImages => '只看无图';

  @override
  String get onlineGallery_codexOffline => '离线缓存';

  @override
  String get onlineGallery_codexContributors => '贡献者与来源';

  @override
  String onlineGallery_codexEntryCount(Object entries, Object images) {
    return '$entries 个词条 · $images 个有图';
  }

  @override
  String get onlineGallery_codexNoImage => '无配图词条';

  @override
  String get onlineGallery_codexNoImageDescription => '这是纯文本词条，提示词与元数据仍可完整使用。';

  @override
  String get onlineGallery_codexAuthor => '作者';

  @override
  String get onlineGallery_codexImageFile => '图片文件';

  @override
  String get onlineGallery_codexOriginalFile => '原图文件';

  @override
  String get onlineGallery_codexDeclaredSource => '数据来源';

  @override
  String get onlineGallery_codexPrompt => '正向提示词';

  @override
  String get onlineGallery_codexNegativePrompt => '负向提示词';

  @override
  String get onlineGallery_codexCharacterPrompts => '角色提示词';

  @override
  String get onlineGallery_codexNote => '备注';

  @override
  String get onlineGallery_codexSendToGeneration => '带入生成页';

  @override
  String get onlineGallery_codexAddToQueue => '加入生成队列';

  @override
  String get onlineGallery_codexDownloadOriginal => '下载当前原图';

  @override
  String get onlineGallery_codexOpenSource => '打开上游';

  @override
  String get onlineGallery_codexOpenOrigin => '打开原址';

  @override
  String get onlineGallery_codexOpenSourceFailed => '无法打开声明的数据来源。';

  @override
  String get onlineGallery_codexBookLocked => '此法典包含成人内容，请在分级选单中选择“可疑”或“限制级”。';

  @override
  String get onlineGallery_codexNoData => '暂无符合条件的法典词条';

  @override
  String get onlineGallery_codexExternalFallback => '外部来源暂不可用，正在显示法典站缓存版本。';

  @override
  String get onlineGallery_codexPreviousRelease => '当前版本暂不可用，正在显示上一个已校验版本。';

  @override
  String get onlineGallery_codexCachedBadge => '旧版缓存';

  @override
  String get onlineGallery_codexUntitled => '未命名词条';

  @override
  String get onlineGallery_artistHunt => '仅画师串';

  @override
  String get onlineGallery_artistHuntTooltip =>
      '只显示正向 Prompt 中明确包含 artist: 标签的图片';

  @override
  String get onlineGallery_copyArtistChain => '复制画师串';

  @override
  String get onlineGallery_copyPrompt => '复制提示词';

  @override
  String get onlineGallery_promptCopyDescription =>
      '选择要复制的原始提示词类别。正向与负向内容会以纯文本块分隔。';

  @override
  String get onlineGallery_promptCopyCategoryHint => '按来源提供的标签类别复制';

  @override
  String get onlineGallery_promptCopyStructuredHint => '复制该提示词字段的原始内容';

  @override
  String onlineGallery_artistCount(Object count) {
    return '$count 位画师';
  }

  @override
  String get onlineGallery_artistHuntNoExactResults => '候选作品中没有精确画师串';

  @override
  String onlineGallery_artistHuntPartialFailure(Object count) {
    return '有 $count 个作品解析失败，可重试再次检查。';
  }

  @override
  String get onlineGallery_artistHuntDetailFailed => '候选作品详情全部解析失败，请重试。';

  @override
  String get onlineGallery_aiTagTimeRange => '时间范围';

  @override
  String get onlineGallery_aiTagAllTime => '全部';

  @override
  String get onlineGallery_aiTagCurrentMonthly => '实时月榜';

  @override
  String get onlineGallery_aiTagOlderMonthly => '更早归档';

  @override
  String get onlineGallery_aiTagRankingProcessing => '排行榜生成中，请稍后重试。';

  @override
  String get onlineGallery_sourceConfigUnavailable => '无法获取来源配置，请检查网络后重试。';

  @override
  String get onlineGallery_sourceRateLimited => '请求过于频繁，请稍后重试。';

  @override
  String get onlineGallery_sourceTimeout => '请求超时，请检查网络连接。';

  @override
  String get onlineGallery_sourceNetworkError => '无法连接当前画廊来源，请检查网络或代理。';

  @override
  String get onlineGallery_sourceRequestFailed => '请求失败，请稍后重试。';

  @override
  String onlineGallery_actionFailed(Object error) {
    return '操作失败：$error';
  }

  @override
  String get onlineGallery_sourceMalformedResponse => '来源返回的数据结构已变化，暂时无法解析。';

  @override
  String get onlineGallery_detailNotFound => '作品不存在或已被删除。';

  @override
  String get onlineGallery_imageUnavailable => '图片当前不可用。';

  @override
  String get onlineGallery_loadedAll => '已加载全部';

  @override
  String get onlineGallery_retryAppend => '加载失败，点击重试';

  @override
  String onlineGallery_multipleImages(Object count) {
    return '$count 张图片';
  }

  @override
  String get onlineGallery_views => '浏览';

  @override
  String get onlineGallery_downloadAllMedia => '下载作品全部图片';

  @override
  String get onlineGallery_copyAllTags => '复制全部 TAG';

  @override
  String get onlineGallery_customCopyTags => '自定义复制';

  @override
  String get promptCopy_exportTitle => '自定义复制 TAG';

  @override
  String get promptCopy_allPositive => '全部正面提示词';

  @override
  String get promptCopy_allNegative => '全部负面提示词';

  @override
  String get promptCopy_mainPositive => '主 / 全局正面提示词';

  @override
  String get promptCopy_mainNegative => '主 / 全局负面提示词';

  @override
  String get promptCopy_fixedPositive => '固定正面提示词';

  @override
  String get promptCopy_fixedNegative => '固定负面提示词';

  @override
  String promptCopy_characterPositive(int index) {
    return '角色 $index 正面提示词';
  }

  @override
  String promptCopy_characterNegative(int index) {
    return '角色 $index 负面提示词';
  }

  @override
  String get onlineGallery_gelbooruReadOnly => '只读收藏';

  @override
  String get onlineGallery_gelbooruFavoritesSortHint =>
      '按帖子 ID 从新到旧排列，不保证与网站收藏时间顺序一致。';

  @override
  String get tooltip_fullscreenEdit => '全屏编辑';

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
  String get upscale_scale => '放大倍数';

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
  String get qualityTags_naiDefaultStandard => 'NAI 默认（标准）';

  @override
  String get qualityTags_naiDefaultLight => 'NAI 默认（轻量）';

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
  String warmup_dataMigrationFailed(Object details) {
    return '数据迁移失败：$details';
  }

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
  String get generation_invalidResolution => '分辨率无效';

  @override
  String generation_invalidResolutionHint(
    int width,
    int height,
    int suggestedWidth,
    int suggestedHeight,
  ) {
    return '$width×$height 无法用于生成。宽度和高度必须是 64 的倍数、单边不能超过 4096，且总像素不能超过 3,145,728。最接近的可用尺寸是 $suggestedWidth×$suggestedHeight。';
  }

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
  String get drop_processing => '正在解析图片...';

  @override
  String get characterEditor_close => '关闭';

  @override
  String get characterEditor_clearAll => '清空所有';

  @override
  String get characterEditor_clearAllTitle => '清空所有角色';

  @override
  String get characterEditor_clearAllConfirm => '确定要删除所有角色吗？此操作无法撤销。';

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
  String get characterCanvas_guide => '构图参考线';

  @override
  String get characterCanvas_guideNone => '无';

  @override
  String get characterCanvas_guideThirds => '三分法';

  @override
  String get characterCanvas_guidePhi => '黄金比';

  @override
  String get characterCanvas_guideGrid => '网格';

  @override
  String get characterCanvas_guideColumns => '列';

  @override
  String get characterCanvas_guideRows => '行';

  @override
  String get characterEditor_genderFemale => '女性';

  @override
  String get characterEditor_genderMale => '男性';

  @override
  String get characterEditor_genderOther => '其他';

  @override
  String get characterEditor_addFemale => '女';

  @override
  String get characterEditor_addMale => '男';

  @override
  String get characterEditor_addOther => '其他';

  @override
  String get characterEditor_addFromLibrary => '词库';

  @override
  String get characterEditor_moveUp => '上移';

  @override
  String get characterEditor_moveDown => '下移';

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
  String get characterTooltip_disabledLabel => '已禁用';

  @override
  String get characterTooltip_notSet => '未设置';

  @override
  String get characterTooltip_previewTitle => '角色预览';

  @override
  String characterTooltip_enabledSummary(int enabled, int total) {
    return '$enabled / $total 启用';
  }

  @override
  String characterTooltip_more(int count) {
    return '还有 $count 个角色';
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
  String get randomPrompt_unsupportedModel => '当前模型不支持官网随机词库';

  @override
  String get randomPrompt_unsupportedModelHint =>
      '当前模型没有对应的 NovelAI 官网随机方案。请选择受支持的 NovelAI 模型，或使用自己的自定义预设。';

  @override
  String get naiMode_noTags => '暂无标签';

  @override
  String get naiAlgorithm_mainPrompt => '主提示词';

  @override
  String tagGroup_tagCount(Object count) {
    return '$count 标签';
  }

  @override
  String get addGroup_tagGroupTab => '标签词库';

  @override
  String get addGroup_displayNameLabel => '显示名称（可选）';

  @override
  String get addGroup_targetCategoryLabel => '目标分类';

  @override
  String get addGroup_poolTab => '图集';

  @override
  String globalSettings_saveFailed(Object error) {
    return '保存失败: $error';
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
  String get nav_gallery => '图库';

  @override
  String get nav_settings => '设置';

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
  String get preset_resetToDefault => '重置为默认';

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
  String get category_dialogTitle => '创建新类别';

  @override
  String get category_nameHint => '输入类别名称';

  @override
  String get category_nameRequired => '请输入类别名称';

  @override
  String get category_selectEmoji => '选择 Emoji';

  @override
  String get category_noRecentEmoji => '暂无最近使用的 Emoji';

  @override
  String get category_searchEmoji => '搜索 Emoji';

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
  String get characterCountConfig_addSlotHint => '例如：1trap, 1futanari';

  @override
  String get characterCountConfig_slotExists => '该槽位已存在';

  @override
  String get randomManager_algorithmConfig => '算法配置';

  @override
  String get randomManager_characterCountWeight => '角色数量权重';

  @override
  String get randomManager_genderWeight => '性别权重';

  @override
  String get randomManager_enableSeasonalWordlists => '启用季节性词库';

  @override
  String get randomManager_enableSeasonalWordlistsDesc => '圣诞节、万圣节等特殊日期词库';

  @override
  String get randomManager_globalEmphasisProbability => '全局强调概率';

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
  String get randomManager_defaultPreset => 'NovelAI 官网预设';

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
  String get randomManager_syncDanbooruTags => '同步 Danbooru 标签';

  @override
  String get randomManager_unknownError => '未知错误';

  @override
  String get randomManager_readOnlyMode => '只读模式';

  @override
  String get randomManager_readOnlyTooltip => '当前预设为默认预设，所有配置项已锁定';

  @override
  String get randomManager_global => '全局';

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
  String get randomManager_previewGeneration => '输出预览';

  @override
  String get randomManager_generating => '生成中';

  @override
  String get randomManager_generate => '生成样例';

  @override
  String get randomManager_generationFailed => '生成失败';

  @override
  String get randomManager_copy => '复制全部';

  @override
  String get randomManager_regenerate => '换一个样例';

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
  String get randomManager_previewHint => '尚未生成样例';

  @override
  String get randomManager_generateNow => '立即生成';

  @override
  String get randomManager_moreActions => '更多操作';

  @override
  String get randomManager_deleteSelected => '删除选中';

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
  String get vibeParseFailed => '无法解析 Vibe 文件';

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
  String get tag_countBadgeBreakdown => '标签分类统计';

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
  String get localGallery_editMetadata => '编辑标签';

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
    return '将移动 $count 张本地图片文件到目标分类。请确认不是误操作。';
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
  String get localGallery_zipMetadataTitle => '导出 ZIP 压缩包';

  @override
  String get localGallery_zipMetadataDescription =>
      '选择压缩包内的图片是否保留内嵌元数据。原始图片文件不会被修改。';

  @override
  String get localGallery_zipIncludeMetadata => '保留元数据';

  @override
  String get localGallery_zipIncludeMetadataDescription => '直接打包原始图片，不改变图片内容。';

  @override
  String get localGallery_zipExcludeMetadata => '移除全部元数据';

  @override
  String get localGallery_zipExcludeMetadataDescription =>
      '仅为压缩包生成净化副本，清除 PNG 文本块、EXIF 和 NovelAI 隐写水印数据。';

  @override
  String bulkMetadataEdit_title(Object count) {
    return '批量编辑 $count 张图片的标签';
  }

  @override
  String get bulkMetadataEdit_tagsToAdd => '要添加的标签';

  @override
  String get bulkMetadataEdit_tagsToAddHint => '输入要添加的标签...';

  @override
  String get bulkMetadataEdit_tagsToRemove => '要移除的标签';

  @override
  String get bulkMetadataEdit_tagsToRemoveHint => '输入要移除的标签...';

  @override
  String get bulkMetadataEdit_noChanges => '请至少添加一个要添加或移除的标签';

  @override
  String localGallery_packingImages(Object count) {
    return '正在打包 $count 张图片...';
  }

  @override
  String localGallery_packedImages(Object count) {
    return '已打包 $count 张图片';
  }

  @override
  String localGallery_packingProgress(Object current, Object total) {
    return '正在打包第 $current/$total 张图片...';
  }

  @override
  String get localGallery_packPartialTitle => '部分图片未导出';

  @override
  String localGallery_packedImagesWithFailures(Object exported, Object failed) {
    return '压缩包已生成：成功加入 $exported 张，$failed 张未能加入';
  }

  @override
  String get localGallery_packFailed => '打包失败';

  @override
  String localGallery_packFailedWithDetails(Object error) {
    return '创建压缩包失败：$error';
  }

  @override
  String get localGallery_packAlreadyInProgress => '已有图片压缩包正在导出';

  @override
  String get localGallery_imageFileMissing => '图片文件不存在';

  @override
  String get localGallery_sentToImageToImage => '图片已发送到图生图';

  @override
  String localGallery_sendFailed(Object error) {
    return '发送失败: $error';
  }

  @override
  String get localGallery_sentToReversePrompt => '图片已发送到反推模块';

  @override
  String localGallery_sendToKritaFailed(Object error) {
    return '发送到 Krita 失败: $error';
  }

  @override
  String get localGallery_sendToImg2Img => '发送到图生图';

  @override
  String get localGallery_moreImageActions => '更多图片操作';

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
  String get localGallery_clearFilters => '清除筛选';

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
  String get statistics_noData => '暂无统计数据';

  @override
  String get statistics_noTagData => '暂无标签数据';

  @override
  String get statistics_generateFirst => '先生成一些图片吧';

  @override
  String get statistics_totalImages => '总图片数';

  @override
  String get statistics_totalSize => '总大小';

  @override
  String get statistics_favorites => '收藏';

  @override
  String get statistics_samplerDistribution => '采样器分布';

  @override
  String get statistics_additionalStats => '其他统计';

  @override
  String get statistics_averageFileSize => '平均文件大小';

  @override
  String get statistics_withMetadata => '有元数据的图片';

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
  String get statistics_noAnlasInPeriod => '该周期暂无点数消耗';

  @override
  String get statistics_periodSelectorTooltip => '选择统计周期';

  @override
  String get statistics_periodWeek => '近一周';

  @override
  String get statistics_periodMonth => '近一个月';

  @override
  String get statistics_periodThreeMonths => '近三个月';

  @override
  String get statistics_periodYear => '近一年';

  @override
  String get statistics_periodAll => '全部';

  @override
  String get statistics_periodCustom => '自定义天数';

  @override
  String statistics_periodDays(int count) {
    return '最近 $count 天';
  }

  @override
  String statistics_periodSummary(String start, String end, int count) {
    return '$start 至 $end · $count 天';
  }

  @override
  String statistics_partialCoverage(String date, int count) {
    return '现有记录始于 $date，日均按现有 $count 天计算';
  }

  @override
  String get statistics_customPeriodTitle => '自定义统计周期';

  @override
  String get statistics_customDaysHint => '统计天数';

  @override
  String statistics_customDaysError(int max) {
    return '请输入 1 至 $max 之间的整数';
  }

  @override
  String get statistics_daysUnit => '天';

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
  String get localGallery_activeFiltersSet => '已设置筛选';

  @override
  String get localGallery_applyFilters => '应用筛选';

  @override
  String get localGallery_resetAdvancedFilters => '重置高级筛选';

  @override
  String get bulkExport_format => '导出格式';

  @override
  String get bulkExport_jsonFormat => 'JSON';

  @override
  String get bulkExport_csvFormat => 'CSV';

  @override
  String get localGallery_group_today => '今天';

  @override
  String get localGallery_group_yesterday => '昨天';

  @override
  String get localGallery_group_thisWeek => '本周';

  @override
  String get localGallery_group_earlier => '更早';

  @override
  String localGallery_cannotOpenFolder(Object error) {
    return '无法打开文件夹: $error';
  }

  @override
  String get localGallery_permissionRequiredTitle => '需要存储权限';

  @override
  String get localGallery_permissionRequiredContent =>
      '本地画廊需要访问存储权限才能扫描您生成的图片。\n\n请在设置中授予权限后重试。';

  @override
  String get localGallery_openSettings => '打开设置';

  @override
  String get localGallery_firstTimeTipTitle => '使用提示';

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
  String get localGallery_noCategoriesAvailable => '暂无可用分类，请先创建分类';

  @override
  String get localGallery_moveToCategory => '移动到分类';

  @override
  String get localGallery_albumSectionTitle => '相簿';

  @override
  String get localGallery_folderSectionTitle => '文件夹';

  @override
  String get localGallery_albumEmptyHint => '还没有相簿，点击右侧按钮创建';

  @override
  String get localGallery_createAlbum => '新建相簿';

  @override
  String get localGallery_createSubAlbum => '新建子相簿';

  @override
  String get localGallery_moveAlbumToRoot => '移到根级';

  @override
  String get localGallery_moveAlbumUp => '移到上一级';

  @override
  String get localGallery_moveCategoryUp => '移到上一级';

  @override
  String get localGallery_createAlbumTitle => '新建相簿';

  @override
  String get localGallery_createSubAlbumTitle => '新建子相簿';

  @override
  String get localGallery_createAlbumHint => '输入相簿名称';

  @override
  String get localGallery_deleteAlbumTitle => '删除相簿';

  @override
  String get localGallery_deleteAlbumContent => '将删除该相簿（图片文件不受影响），子相簿会提升到根级。';

  @override
  String get localGallery_addedToAlbum => '已加入相簿';

  @override
  String get localGallery_albumAddFailed => '加入相簿失败';

  @override
  String get localGallery_albumSelectTitle => '加入相簿';

  @override
  String get localGallery_addToAlbum => '加入相簿';

  @override
  String get localGallery_removeFromAlbum => '移出相簿';

  @override
  String localGallery_removedFromAlbum(Object count) {
    return '已移出 $count 张图片';
  }

  @override
  String get localGallery_albumNoMembers => '所选图片不在此相簿中';

  @override
  String localGallery_addedToAlbumWithName(Object count, Object name) {
    return '已将 $count 张图片加入「$name」';
  }

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
  String get brushPreset_selectHint => '双击选择此笔刷预设';

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
  String get bulkProgress_continueInBackground => '转到后台继续';

  @override
  String get bulkProgress_operationAlreadyInProgress => '已有批量操作正在进行';

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
  String get statistics_mostActiveDay => '最活跃日';

  @override
  String get statistics_leastActiveDay => '最不活跃日';

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
  String get promptAssistant_assistant => '助手';

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
  String get promptAssistant_webAccessTitle => 'Agent 联网';

  @override
  String get promptAssistant_webAccessSubtitle => '通过 SearXNG 或 Exa 搜索实时信息';

  @override
  String get promptAssistant_webAccessEnable => '允许 Agent 联网';

  @override
  String get promptAssistant_webAccessEnableSubtitle => '启用后，搜索和读取公网网页不再逐次确认';

  @override
  String get promptAssistant_webAccessBackend => '搜索后端';

  @override
  String get promptAssistant_webAccessBackendAuto => '自动';

  @override
  String get promptAssistant_webAccessBackendSearxng => 'SearXNG';

  @override
  String get promptAssistant_webAccessBackendExaMcp => 'Exa 免费 MCP';

  @override
  String get promptAssistant_webAccessBackendExaApi => 'Exa API';

  @override
  String get promptAssistant_webAccessBackendAutoDescription =>
      '优先使用已配置的 SearXNG，失败后回退到 Exa 匿名 MCP 额度';

  @override
  String get promptAssistant_webAccessBackendSearxngDescription =>
      '仅使用配置的私有 SearXNG 实例';

  @override
  String get promptAssistant_webAccessBackendExaMcpDescription =>
      '无需 API Key，使用 Exa 托管的免费额度并受其限流约束';

  @override
  String get promptAssistant_webAccessBackendExaApiDescription =>
      '使用你的 Exa 账号与 API 额度，此模式可能产生费用';

  @override
  String get promptAssistant_webAccessResultCount => '默认结果数';

  @override
  String get promptAssistant_webAccessSearxngUrl => 'SearXNG 地址';

  @override
  String get promptAssistant_webAccessExaApiKey => 'Exa API Key';

  @override
  String get promptAssistant_webAccessApiKeyConfigured => '已安全保存';

  @override
  String get promptAssistant_webAccessApiKeyMissing => '未配置';

  @override
  String get promptAssistant_webAccessConfigureKey => '配置';

  @override
  String get promptAssistant_webAccessClearKey => '清除 Key';

  @override
  String get promptAssistant_webAccessTestConnection => '测试连接';

  @override
  String get promptAssistant_webAccessTesting => '正在测试...';

  @override
  String promptAssistant_webAccessTestSucceeded(Object provider) {
    return '已通过 $provider 连接';
  }

  @override
  String promptAssistant_webAccessTestFailed(Object error) {
    return '连接失败：$error';
  }

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
  String get autocomplete_actionSelect => '选择';

  @override
  String get autocomplete_actionConfirm => '确认';

  @override
  String get autocomplete_actionClose => '关闭';

  @override
  String get autocomplete_categoryCharacter => '角色';

  @override
  String get autocomplete_categoryCopyright => '版权';

  @override
  String get autocomplete_categoryArtist => '艺术家';

  @override
  String get autocomplete_categoryMeta => '元数据';

  @override
  String get autocomplete_categoryContributor => '贡献者';

  @override
  String get autocomplete_categorySpecies => '物种';

  @override
  String get autocomplete_categoryLore => '设定';

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
  String get tagLibrary_addedToFixed => '已添加到固定词';

  @override
  String get tagLibrary_entryMoved => '条目已移动到目标分类';

  @override
  String get tagLibrary_addFavorite => '添加收藏';

  @override
  String get tagLibrary_thumbnail => '预览图';

  @override
  String get tagLibrary_selectImage => '选择图片';

  @override
  String get tagLibrary_thumbnailHint => '支持 PNG、JPG、WEBP、GIF、BMP、TIFF 等格式';

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
  String get tagLibrary_characterNegativeSyntaxHelp =>
      '角色词库可用 negative(...) 保存独立负面提示词，例如：girl, blue eyes, negative(red hair, glasses)';

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
  String get queue_management => '队列管理';

  @override
  String get queue_empty => '队列为空';

  @override
  String get queue_emptyHint => '没有待执行的任务';

  @override
  String get queue_pending => '等待中';

  @override
  String get queue_running => '执行中';

  @override
  String get queue_completed => '已完成';

  @override
  String get queue_failed => '失败';

  @override
  String get queue_paused => '已暂停';

  @override
  String get queue_idle => '空闲';

  @override
  String get queue_ready => '就绪';

  @override
  String get queue_noTasksToStart => '队列为空，无法开始';

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
  String get queue_startExecution => '开始队列';

  @override
  String get queue_pauseExecution => '暂停队列';

  @override
  String get queue_resumeExecution => '继续队列';

  @override
  String get queue_generationBusy => '当前有其他生成任务正在执行，请稍后再开始队列';

  @override
  String get queue_clearQueue => '清空队列';

  @override
  String get queue_clearQueueConfirm => '确定要清空所有队列任务吗？此操作不可撤销。';

  @override
  String get queue_confirmClear => '确认清空';

  @override
  String queue_retryCount(Object current, Object max) {
    return '重试 $current/$max';
  }

  @override
  String get queue_retry => '重试';

  @override
  String get queue_requeue => '重新排队';

  @override
  String get queue_clearFailedTasks => '清空全部';

  @override
  String get queue_noFailedTasks => '暂无失败任务';

  @override
  String get queue_noCompletedTasks => '暂无完成记录';

  @override
  String get queue_editTask => '编辑任务';

  @override
  String get queue_taskDetails => '任务详情';

  @override
  String get queue_clearCompletedTasks => '清空已完成';

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
  String get queue_addCurrentTask => '加入当前任务';

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
  String queue_confirmDeleteSelected(Object count) {
    return '确定要删除选中的 $count 个任务吗？';
  }

  @override
  String get settings_queueRetryCount => '重试次数';

  @override
  String get settings_queueRetryInterval => '重试间隔';

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
  String get settings_notificationSound => '完成音效';

  @override
  String get settings_notificationSoundSubtitle => '生成完成时播放提示音效';

  @override
  String get settings_notificationCustomSound => '自定义音效';

  @override
  String get settings_notificationSelectSound => '选择音效';

  @override
  String get settings_notificationResetSound => '恢复默认';

  @override
  String get resetToDefault => '重置为默认';

  @override
  String get toggleGroupEnabled => '切换词组启用状态';

  @override
  String get diyNotAvailableForDefault => '默认预设不支持 DIY 配置';

  @override
  String get diyNotAvailableHint => '请复制为自定义预设后编辑';

  @override
  String get statistics_heatmapLess => '少';

  @override
  String get statistics_heatmapMore => '多';

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
  String get metadataImport_mainPrompt => '主提示词';

  @override
  String get metadataImport_fixedTags => '固定词';

  @override
  String get metadataImport_fixedSourceStructured => '来源：图片明确记录';

  @override
  String get metadataImport_fixedSourceLegacy => '来源：旧版图片字段';

  @override
  String get metadataImport_fixedSourceLibrary => '来源：根据当前固定词库严格匹配';

  @override
  String get metadataImport_fixedSourceUnknown => '来源：图片未记录，无法确认';

  @override
  String get metadataImport_unknownFixedTagsHint =>
      '图片没有记录固定词。请选择如何处理当前已启用的固定词。';

  @override
  String get metadataImport_disableCurrentFixedTags => '关闭当前固定词（推荐）';

  @override
  String get metadataImport_keepCurrentFixedTags => '保留并与图片提示词叠加';

  @override
  String metadataImport_imageVersionName(Object name) {
    return '$name（图像版本）';
  }

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
  String get metadataImport_noData => '（无数据）';

  @override
  String metadataImport_selectedCount(int count) {
    return '已选择 $count 项';
  }

  @override
  String get metadataImport_readImageMetadata => '读取图片元数据';

  @override
  String get metadataImport_readFailed => '无法读取所选图片';

  @override
  String get metadataImport_processFailed => '无法处理所选图片';

  @override
  String get metadataImport_noDataFound => '未找到 NovelAI 元数据';

  @override
  String get metadataImport_noParamsSelected => '未选择任何要应用的参数';

  @override
  String metadataImport_appliedCount(int count) {
    return '已应用 $count 项参数';
  }

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
  String get shortcut_settings_press_key => '按下按键组合...';

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
  String get drop_actions => '操作';

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
  String get drop_extractMetadata => '发送到文生图';

  @override
  String get drop_extractMetadataSubtitle => '选择要套用的提示词、固定词和生成参数';

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
  String get drop_metadataDetected => '检测到 NovelAI 元数据';

  @override
  String get drop_metadataParseFailed => '元数据解析失败';

  @override
  String get drop_metadataParseFailedHint => '图片包含元数据字段，但当前无法读取。其他图片用途仍可正常使用。';

  @override
  String get drop_metadataErrorDetails => '查看错误详情';

  @override
  String get drop_positivePrompt => '正向 Prompt';

  @override
  String get drop_negativePrompt => '负向 Prompt';

  @override
  String drop_characterPrompts(int count) {
    return '角色 Prompt（$count）';
  }

  @override
  String drop_characterPositivePrompt(int index) {
    return '角色 $index 正向 Prompt';
  }

  @override
  String drop_characterNegativePrompt(int index) {
    return '角色 $index 负向 Prompt';
  }

  @override
  String get drop_promptNotRecorded => '未记录';

  @override
  String get drop_promptCopy => '复制';

  @override
  String get drop_promptAddWhole => '整段加入词库';

  @override
  String get drop_promptAddSelection => '加入词库';

  @override
  String get drop_promptLibraryTitle => '加入词库';

  @override
  String get drop_promptLibraryWriteMode => '写入方式';

  @override
  String get drop_promptLibraryCreate => '新建';

  @override
  String get drop_promptLibraryAppend => '追加';

  @override
  String get drop_promptLibraryOverwrite => '覆盖';

  @override
  String get drop_promptLibraryAliasHint => '该名称同时用于 <词库名称> 引用';

  @override
  String get drop_promptLibraryTarget => '目标条目';

  @override
  String get drop_promptLibrarySelectTarget => '选择要更新的条目';

  @override
  String get drop_promptLibrarySeparator => '连接方式';

  @override
  String get drop_promptLibrarySeparatorComma => '逗号 + 空格';

  @override
  String get drop_promptLibrarySeparatorNewline => '换行';

  @override
  String get drop_promptLibrarySeparatorNone => '不插入分隔符';

  @override
  String drop_promptLibraryCharacterCount(int count) {
    return '$count 字符';
  }

  @override
  String get drop_promptLibraryExactContentHint => '保存当前文本，不自动清洗、重排或补全';

  @override
  String get drop_promptLibraryResultPreview => '结果预览';

  @override
  String drop_promptLibraryDuplicate(Object name) {
    return '相同内容已存在于“$name”';
  }

  @override
  String get drop_promptLibraryNameConflict => '该名称已存在，请改名或选择追加/覆盖';

  @override
  String drop_promptLibraryOverwriteWarning(Object name) {
    return '将完整替换“$name”的提示词内容';
  }

  @override
  String get drop_promptLibraryMore => '更多选项';

  @override
  String get drop_promptLibraryConfirmOverwrite => '确认覆盖';

  @override
  String get drop_promptLibrarySaved => '已保存到词库';

  @override
  String get drop_promptLibrarySaveFailed => '词库保存失败';

  @override
  String get drop_promptLibraryPositiveName => '正向提示词摘取';

  @override
  String get drop_promptLibraryNegativeName => '负向提示词摘取';

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
  String get preciseRef_v4Only => '此功能仅 V4.5 模型支持';

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
  String get vibeLibrary_markEncodingModel => '标记编码模型';

  @override
  String vibeLibrary_markEncodingModelContent(Object count, Object model) {
    return '把选中的 $count 个 Vibe 标记为「$model」的编码，并重写库文件。\n\n适用于被错误标记成其它模型、导致每次生成都重新编码扣 Anlas 的条目。如果这些编码确实来自别的模型，标记后画面效果可能与预期不符。';
  }

  @override
  String vibeLibrary_encodingModelMarked(Object count) {
    return '已标记 $count 个Vibe的编码模型';
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
  String get vibeBulkTag_actionPreview => '操作预览';

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
  String get vibe_import_encodingCost => '编码将消耗 2 Anlas';

  @override
  String get vibe_import_encodingFailed => '编码失败';

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
  String get vibe_statusNeedsReencode => '需重新编码 (2 Anlas)';

  @override
  String get vibe_statusSourceImageRequired => '缺少原图';

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
  String get shortcuts_customize => '自定义快捷键';

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
  String get settings_pleaseLoginFirst => '请先登录';

  @override
  String get settings_accountNotFound => '未找到账号信息';

  @override
  String get settings_goToLoginPage => '请前往登录页面';

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
  String get discordShare_action => '分享到 Discord';

  @override
  String get discordShare_title => '分享到 Discord';

  @override
  String get discordShare_subtitle => '将图片发布到 Aaalice 社区频道';

  @override
  String get discordShare_verifyTitle => '验证 Discord 成员身份';

  @override
  String get discordShare_verifyDescription =>
      '分享前需要在浏览器中登录 Discord。应用只会获得你的公开身份和服务器成员状态。';

  @override
  String get discordShare_verifyButton => '前往 Discord 验证';

  @override
  String get discordShare_verifying => '正在等待 Discord 验证…';

  @override
  String get discordShare_verifyingHint => '请在浏览器中完成授权，然后返回应用。';

  @override
  String get discordShare_joinRequired => '请先加入 Aaalice Discord 服务器';

  @override
  String get discordShare_joinDescription =>
      '只有服务器成员可以向社区频道分享图片。加入后返回这里重新验证即可。';

  @override
  String get discordShare_joinServer => '加入 Discord 服务器';

  @override
  String get discordShare_retryVerification => '重新验证';

  @override
  String discordShare_account(Object name) {
    return '已验证为 $name';
  }

  @override
  String get discordShare_disconnect => '解除 Discord 连接';

  @override
  String get discordShare_channels => '发送频道';

  @override
  String get discordShare_selectChannel => '至少选择一个频道';

  @override
  String get discordShare_caption => '图像附言';

  @override
  String get discordShare_captionHint => '说点什么，像帖子标题一样（可选）';

  @override
  String get discordShare_promptCategories => '提示词类别';

  @override
  String get discordShare_promptEditHint => '可在发送前继续编辑最终内容。切换类别会按图片元数据重新生成。';

  @override
  String get discordShare_promptContent => '发送的提示词';

  @override
  String get discordShare_noPromptMetadata => '这张图片没有可读取的提示词元数据，仍可只分享图片和附言。';

  @override
  String get discordShare_categoryMain => '主体';

  @override
  String get discordShare_categoryCharacters => '角色';

  @override
  String get discordShare_categoryQuality => '质量词';

  @override
  String get discordShare_categoryFixed => '固定词';

  @override
  String get discordShare_keepMetadata => '保留图像元数据';

  @override
  String get discordShare_keepMetadataHint =>
      '默认关闭。关闭时会清除 PNG 文本、EXIF 和 NAI 隐写元数据后再上传。';

  @override
  String get discordShare_privacyHint => '发送内容会上传到 Discord；请检查提示词和附言中是否包含隐私信息。';

  @override
  String get discordShare_send => '发送到 Discord';

  @override
  String get discordShare_sending => '正在发送…';

  @override
  String get discordShare_success => '已分享到 Discord';

  @override
  String get discordShare_partialSuccess => '部分频道发送成功，请检查失败频道后重试';

  @override
  String discordShare_failed(Object error) {
    return '分享到 Discord 失败：$error';
  }

  @override
  String get discordShare_errorNetwork => '无法连接 Discord 分享服务，请检查网络后重试';

  @override
  String get discordShare_errorBrowser => '无法打开浏览器，请检查系统的默认浏览器设置';

  @override
  String get discordShare_errorTimeout => 'Discord 验证已超时，请重新验证';

  @override
  String get discordShare_errorRateLimited => '分享过于频繁，请稍后再试';

  @override
  String discordShare_errorRateLimitedRetry(int seconds) {
    return '分享过于频繁，请在 $seconds 秒后重试';
  }

  @override
  String get discordShare_errorNoChannels => '当前没有可用的 Discord 分享频道';

  @override
  String get discordShare_errorSession => 'Discord 验证已失效，请重新验证';

  @override
  String get discordShare_errorRelay => 'Discord 分享服务暂时不可用，请稍后再试';

  @override
  String get discordShare_errorImageRejected => 'Discord 拒绝了这张图片，请检查图片大小或格式';

  @override
  String get discordShare_errorDelivery => 'Discord 频道发送失败，请稍后重试';

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
  String get settings_localOnnxTaggerFolder => '本地 ONNX tagger 模型';

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
  String get comfyWorkflow_seedvr2LegacyUpscaleName => 'SeedVR2 兼容节点超分';

  @override
  String get comfyWorkflow_seedvr2LegacyUpscaleDescription =>
      '使用已安装的 SeedVR2VideoUpscaler 自定义节点进行超分';

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
  String get vibeLibrary_emptySaveFromGenerationHint => '可从文件导入，或从生成页面保存 Vibe';

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
  String get detail_copyPromptTitle => '复制正面提示词';

  @override
  String get detail_copyPromptDescription =>
      '勾选需要复制的提示词类别。固定词可能包含私密串或个人标记，请确认后再分享。';

  @override
  String get detail_promptCategoryMain => '主体提示词';

  @override
  String get detail_promptCategoryMainHint => '画面主体、场景和常规描述';

  @override
  String get detail_promptCategoryCharacters => '角色提示词';

  @override
  String get detail_promptCategoryCharactersHint => '多角色专用提示词';

  @override
  String get detail_promptCategoryQuality => '质量提示词';

  @override
  String get detail_promptCategoryQualityHint => '官方质量预设与透明背景自动词';

  @override
  String get detail_promptCategoryFixed => '固定词';

  @override
  String get detail_promptCategoryFixedHint => '固定前缀和后缀，可能包含私密内容';

  @override
  String get detail_promptCategoryUnavailable => '此图片未记录该类别';

  @override
  String get detail_copyPromptDefaultHint => '默认复制主体和角色提示词，不包含质量词与固定词。';

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
  String get updateErrorNetwork => '无法连接更新服务器，请检查网络或代理设置后重试。';

  @override
  String get updateErrorServerBusy => '更新服务器请求繁忙，请稍后重试。';

  @override
  String get updateErrorReleaseNotReady => '最新版本的发布文件尚未就绪，请稍后重试。';

  @override
  String get updateErrorServiceUnavailable => '更新服务器暂时不可用，请稍后重试。';

  @override
  String get updateErrorInvalidMetadata => '更新信息校验失败，请稍后重试或前往 Release 页面下载。';

  @override
  String get updateErrorUnknown => '暂时无法检查更新，请稍后重试。';

  @override
  String get currentVersion => '当前版本';

  @override
  String get latestVersion => '最新版本';

  @override
  String get releaseNotes => '更新日志';

  @override
  String get viewReleasePage => '查看 Release';

  @override
  String get updatePortableManualHint => '当前构建不支持应用内更新，请前往 Release 页面手动下载新版。';

  @override
  String updateDownloadingProgress(Object percent) {
    return '正在下载更新包：$percent%';
  }

  @override
  String updateDownloadSizeSpeed(Object received, Object total, Object speed) {
    return '$received / $total · $speed';
  }

  @override
  String get updateDownloaded => '更新包已就绪';

  @override
  String updateDownloadedHint(Object version) {
    return '新版本 v$version 已下载并通过校验。安装将关闭应用，完成后会自动重启。';
  }

  @override
  String get updateInstallAndRestart => '安装并重启';

  @override
  String get updateInstallNow => '立即安装';

  @override
  String get updateInstallLater => '稍后安装';

  @override
  String get updateDownload => '下载更新';

  @override
  String get updateDownloadCancelled => '已取消下载，稍后可继续';

  @override
  String get updateDownloadFailed => '下载更新失败';

  @override
  String get updateInstallFailed => '安装更新失败';

  @override
  String get updateInstallingHint => '安装程序已启动，应用即将关闭并自动完成更新。';

  @override
  String get updateInstallConfirmationTitle => '现在安装更新？';

  @override
  String get updateInstallConfirmationBody =>
      '应用将安全关闭并安装更新，完成后自动重新启动。进行中的生成和下载任务会停止，请先保存必要内容。';

  @override
  String get updateActiveTasksWarning => '检测到队列任务仍在运行，安装会停止当前任务。';

  @override
  String get remindMeLater => '4 小时后提醒';

  @override
  String get skipThisVersion => '忽略此版本';

  @override
  String updateNoticeAvailable(Object version) {
    return '新版本 v$version 可用';
  }

  @override
  String get updateNoticeAvailableSubtitle => '可在应用内下载、校验并安全安装更新';

  @override
  String get updateNoticeManualSubtitle => '当前平台需要前往 Release 页面手动更新';

  @override
  String updateNoticeReady(Object version) {
    return '新版本 v$version 已准备好';
  }

  @override
  String get updateNoticeReadySubtitle => '更新包已校验，可以立即安装';

  @override
  String get updateNoticeFailed => '上次更新没有完成';

  @override
  String get updateViewDetails => '查看更新';

  @override
  String updateSettingsAvailable(Object version) {
    return '发现 v$version，点击查看更新内容';
  }

  @override
  String updateSettingsReady(Object version) {
    return 'v$version 已下载，点击安装';
  }

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
  String get preciseRefLib_emptyTouch => '导入图片建立参考库';

  @override
  String get preciseRefLib_emptyHintTouch => '也可以从生成结果、历史记录或本地画廊保存';

  @override
  String get preciseRefLib_import => '导入图片';

  @override
  String get preciseRefLib_exportTitle => '导出精准参考配置包';

  @override
  String get preciseRefLib_exportSelectionHint =>
      '选择要包含的精准参考；所选内容会打包为一个 .naipreciseref 文件。';

  @override
  String preciseRefLib_exportConfirm(int count) {
    return '导出所选 ($count)';
  }

  @override
  String preciseRefLib_exportedCount(Object count) {
    return '已导出 $count 个精准参考';
  }

  @override
  String preciseRefLib_exportFailed(Object error) {
    return '导出精准参考失败：$error';
  }

  @override
  String preciseRefLib_openFolderFailed(Object error) {
    return '打开精准参考目录失败：$error';
  }

  @override
  String get preciseRefLib_enterSelectionMode => '进入多选模式';

  @override
  String get preciseRefLib_changeType => '修改类型';

  @override
  String preciseRefLib_sentSelectedSummary(Object failed, Object success) {
    return '已发送 $success 个精准参考，$failed 个失败';
  }

  @override
  String preciseRefLib_failedItems(Object items) {
    return '失败项：$items';
  }

  @override
  String preciseRefLib_confirmDeleteSelected(Object count) {
    return '确定删除所选的 $count 个精准参考吗？对应原图也会删除。';
  }

  @override
  String preciseRefLib_deletedCount(Object count) {
    return '已删除 $count 个精准参考';
  }

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
  String get randomManager_keyboardShortcutsHint => '键盘快捷键（按 ? 查看）';

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
  String get router_backAgainToExit => '再滑一次或按返回键退出应用';

  @override
  String router_pageNotFound(String error) {
    return '页面未找到: $error';
  }

  @override
  String get autocomplete_translating => '翻译中…';

  @override
  String get autocomplete_missingTranslation => '未汉化';

  @override
  String autocomplete_translationCoverage(int translated, int total) {
    return '汉化覆盖：$translated/$total';
  }

  @override
  String autocomplete_aliasMatch(String alias) {
    return '别名：$alias';
  }

  @override
  String get autocomplete_settingsTitle => '自动补全';

  @override
  String get autocomplete_enable => '启用自动补全';

  @override
  String get autocomplete_resultLimit => '结果数量';

  @override
  String get autocomplete_allResults => '全部';

  @override
  String get autocomplete_showAliases => '显示命中的别名';

  @override
  String get autocomplete_showTranslations => '显示中文汉化';

  @override
  String get quickTranslate_show => '快速翻译';

  @override
  String get quickTranslate_restore => '还原原提示词（预览中的修改将被丢弃）';

  @override
  String get quickTranslate_previewSemantics => '本地汉化预览。此处修改不会影响原提示词。';

  @override
  String get quickTranslate_noMatches => '当前内容中没有找到可汉化的标签';

  @override
  String get quickTranslate_failed => '快速翻译失败，请检查汉化词库后重试';

  @override
  String get quickTranslate_missingTitle => '需要汉化词库';

  @override
  String get quickTranslate_missingMessage =>
      '快速翻译需要 ffdkj 简体中文汉化库。是否前往数据与缓存设置并立即下载？';

  @override
  String get quickTranslate_download => '前往并下载';

  @override
  String get autocomplete_autoComma => '插入后自动添加逗号';

  @override
  String get autocomplete_openOnTagClick => '点击标签时显示补全';

  @override
  String get autocomplete_openOnTagClickSubtitle =>
      '开启后，点击已有标签会打开普通补全菜单；Ctrl/Command + 点击仍显示相关标签';

  @override
  String get autocomplete_replaceUnderscores => '插入时将下划线替换为空格';

  @override
  String get autocomplete_dataSourcesTitle => '数据源与缓存';

  @override
  String get autocomplete_relatedTagsTitle => '共现与相关标签推荐';

  @override
  String get autocomplete_relatedTagsSubtitle =>
      '选中补全后自动推荐；也可在标签上按 Ctrl+Shift+Space 或 Ctrl+单击';

  @override
  String get autocomplete_danbooruApi => 'Danbooru 在线补充';

  @override
  String get autocomplete_danbooruPrivacy => '仅发送当前英文标签，不会上传完整提示词';

  @override
  String get autocomplete_llmTranslation => '使用 Prompt Assistant 补译缺失汉化';

  @override
  String get autocomplete_llmRouteMissing =>
      '请先在 Prompt Assistant 中配置 Translate 路由';

  @override
  String autocomplete_llmRoute(String route) {
    return '当前路由：$route。调用模型可能产生费用。';
  }

  @override
  String get autocomplete_cooccurrence => '本地相关标签数据';

  @override
  String autocomplete_entryCount(int count) {
    return '$count 条记录';
  }

  @override
  String get autocomplete_cooccurrenceAutoDownload => '自动下载本地相关标签数据';

  @override
  String get autocomplete_cooccurrenceAutoDownloadSubtitle =>
      '相关标签功能开启时，在进入主页后后台下载安装；不影响基础补全';

  @override
  String get autocomplete_downloadNow => '立即下载';

  @override
  String autocomplete_cooccurrenceUnavailable(String size) {
    return '尚未安装 · 下载大小 $size。当前仅显示在线相关标签。';
  }

  @override
  String get autocomplete_cooccurrenceChecking => '正在检查本地数据…';

  @override
  String autocomplete_cooccurrenceDownloading(
    String downloaded,
    String total,
    String speed,
  ) {
    return '正在下载 $downloaded / $total · $speed。当前仍可使用在线结果。';
  }

  @override
  String get autocomplete_cooccurrenceVerifying => '下载完成，正在校验数据包…';

  @override
  String get autocomplete_cooccurrenceInstalling => '正在安全安装并切换数据库…';

  @override
  String autocomplete_cooccurrenceReady(
    String version,
    int count,
    String size,
  ) {
    return '版本 $version · $count 组关系 · 占用 $size';
  }

  @override
  String autocomplete_cooccurrenceUpdateAvailable(String version) {
    return '发现数据版本 $version，可立即更新';
  }

  @override
  String autocomplete_cooccurrenceFailed(String reason) {
    return '本地数据不可用：$reason。基础补全与在线相关标签不受影响。';
  }

  @override
  String get autocomplete_cooccurrenceErrorNetwork => '网络连接失败，请稍后重试';

  @override
  String get autocomplete_cooccurrenceErrorDiskFull => '磁盘空间不足';

  @override
  String get autocomplete_cooccurrenceErrorArchive => '下载文件不完整或校验失败';

  @override
  String get autocomplete_cooccurrenceErrorDatabase => '数据库损坏或版本不匹配';

  @override
  String get autocomplete_cooccurrenceErrorManifest => '内置数据清单无效';

  @override
  String get autocomplete_cooccurrenceErrorInstall => '无法写入或替换数据文件';

  @override
  String get autocomplete_cooccurrenceRemoveTitle => '删除本地相关标签数据？';

  @override
  String get autocomplete_cooccurrenceRemoveConfirm =>
      '删除后将立即释放磁盘空间，并继续使用在线相关标签。';

  @override
  String get autocomplete_cooccurrenceStopAutoDownload => '同时关闭自动下载，避免下次启动重新安装';

  @override
  String get autocomplete_cacheTitle => '在线与 AI 缓存';

  @override
  String get autocomplete_clearDanbooruCache => '清除 Danbooru 缓存';

  @override
  String get autocomplete_clearAiCache => '清除 AI 汉化缓存';

  @override
  String autocomplete_cacheCleared(int count) {
    return '已清除 $count 条缓存';
  }

  @override
  String get autocomplete_baseCatalog => '基础 Danbooru 词库';

  @override
  String autocomplete_catalogStatus(String count, String version) {
    return '$count 个标签 · 数据版本 $version';
  }

  @override
  String get autocomplete_zhDictionary => 'ffdkj 简体中文汉化库';

  @override
  String autocomplete_zhInstalled(int count, String version) {
    return '已安装 $count 条 · 版本 $version';
  }

  @override
  String get autocomplete_zhNotInstalled => '未安装；英文补全仍可正常使用';

  @override
  String get autocomplete_zhInstallPrompt =>
      '可安装 ffdkj 汉化库以显示中文并支持中文反查；词库将直接从上游下载。';

  @override
  String get autocomplete_zhErrorMetadataRateLimited =>
      'GitHub 请求过于频繁，暂时无法检查词库更新；请稍后重试。';

  @override
  String get autocomplete_zhErrorMetadataAccessDenied =>
      'GitHub 拒绝了词库信息请求；请稍后重试或切换网络。';

  @override
  String get autocomplete_zhErrorDownloadAccessDenied =>
      'GitHub 拒绝下载 ffdkj 词库；请稍后重试或切换网络。';

  @override
  String get autocomplete_zhErrorNetwork => '无法连接 ffdkj GitHub 上游；请检查网络后重试。';

  @override
  String get autocomplete_zhErrorIntegrity => '词库完整性校验失败，未安装任何文件。';

  @override
  String get autocomplete_zhErrorUnknown => 'ffdkj 词库操作失败；请稍后重试。';

  @override
  String get autocomplete_checkUpdate => '检查更新';

  @override
  String get autocomplete_update => '更新';

  @override
  String get autocomplete_repair => '修复';

  @override
  String get autocomplete_install => '安装';

  @override
  String get autocomplete_remove => '移除';

  @override
  String get autocomplete_removeConfirm => '移除已安装的中文汉化词库？之后仍可重新安装。';

  @override
  String get autocomplete_sourceRelated => '离线相关标签';

  @override
  String get autocomplete_headerTitle => '标签补全';

  @override
  String get autocomplete_relatedHeaderTitle => '相关标签';

  @override
  String get autocomplete_loading => '正在查询本地词库与在线标签…';

  @override
  String get autocomplete_empty => '没有找到匹配的标签';

  @override
  String get autocomplete_relatedLoading => '正在查询本地共现库与在线相关标签…';

  @override
  String get autocomplete_relatedEmpty => '没有找到可用的相关标签';

  @override
  String autocomplete_relatedMetric(int count, String score) {
    return '共现 $count 次 · Jaccard $score';
  }

  @override
  String get autocomplete_relatedPin => '固定当前标签，可连续插入相关标签';

  @override
  String get autocomplete_relatedUnpin => '取消固定并继续链式推荐';

  @override
  String get autocomplete_statusBase => '本地';

  @override
  String get autocomplete_statusRelated => '共现';

  @override
  String get autocomplete_statusOnlineOnly => '仅在线';

  @override
  String get autocomplete_statusOnlineOnlyTooltip =>
      '本地相关标签数据尚未就绪，当前只显示 Danbooru 在线结果';

  @override
  String get autocomplete_statusDictionary => '汉化';

  @override
  String get autocomplete_statusOnline => '在线';

  @override
  String get autocomplete_statusAi => 'AI';

  @override
  String get autocomplete_statusReady => '就绪';

  @override
  String get autocomplete_statusNotInstalled => '未安装';

  @override
  String autocomplete_statusDownloading(int progress) {
    return '下载 $progress%';
  }

  @override
  String get autocomplete_statusUpdateAvailable => '可更新';

  @override
  String get autocomplete_statusError => '异常';

  @override
  String get autocomplete_statusDisabled => '已关闭';

  @override
  String get autocomplete_statusSearching => '查询中';

  @override
  String get autocomplete_statusTranslating => '翻译中';

  @override
  String autocomplete_aiCacheEntries(int count) {
    return 'AI 翻译缓存：$count 条';
  }

  @override
  String get autocomplete_openSettings => '打开补全与数据源设置';

  @override
  String get randomManager_searchCategories => '搜索类别、词组或标签（Ctrl+F）';

  @override
  String get randomManager_searchCategoriesCompact => '搜索类别、词组或标签';

  @override
  String get randomManager_workspaceTitle => '随机词库';

  @override
  String get randomManager_workspaceSubtitle => '用完整离线 catalog 组合可复用的随机生成配方';

  @override
  String get randomManager_recipeTitle => '生成配方';

  @override
  String get randomManager_recipeSubtitle => '每个阶段独立控制一类语义标签的触发概率与抽取范围';

  @override
  String get randomManager_inspectorTitle => '生成设置';

  @override
  String get randomManager_inspectorSubtitle => '调整当前预设的角色分布与全局输出行为';

  @override
  String get randomManager_previewEmptyDescription => '生成一组提示词样例，检查当前配方的实际输出。';

  @override
  String get randomManager_category_composition => '构图';

  @override
  String get randomManager_category_camera => '视角';

  @override
  String get randomManager_category_framing => '景别';

  @override
  String get randomManager_category_focus => '焦点';

  @override
  String get randomManager_category_eyeFeature => '眼睛特征';

  @override
  String get randomManager_category_hairLength => '发长';

  @override
  String get randomManager_category_hairTexture => '发质';

  @override
  String get randomManager_category_bangs => '刘海';

  @override
  String get randomManager_category_skinTone => '肤色';

  @override
  String get randomManager_category_species => '物种';

  @override
  String get randomManager_category_headwear => '帽子';

  @override
  String get randomManager_category_hairAccessory => '发饰';

  @override
  String get randomManager_category_prop => '道具';

  @override
  String get randomManager_category_effect => '特效';

  @override
  String get randomManager_category_year => '年代';

  @override
  String get randomManager_category_detail => '创意细节';

  @override
  String get randomManager_libraryUnavailable => '随机词库无法使用';

  @override
  String get randomManager_noCategoryResults => '没有匹配的类别、词组或标签';

  @override
  String get common_share => '分享';

  @override
  String get common_moreActions => '更多操作';

  @override
  String get nav_more => '更多';

  @override
  String get nav_explore => '画廊';

  @override
  String get image_savedToSystemGallery => '已保存到系统相册';

  @override
  String get localGallery_saveToSystemGallery => '保存到系统相册';

  @override
  String localGallery_saveToSystemGalleryFailed(Object error) {
    return '无法保存到系统相册：$error';
  }

  @override
  String image_savedAppOnly(Object error) {
    return '已保存到应用图库，但无法导出到系统相册：$error';
  }

  @override
  String image_shareFailed(Object error) {
    return '分享失败: $error';
  }

  @override
  String onlineGallery_savedFiles(int count) {
    return '已保存 $count 个文件';
  }

  @override
  String get statistics_exportJsonHint => '将全部统计结果和分布数据导出为结构化 JSON。';

  @override
  String get statistics_exportCsvHint => '将分区统计数据导出为可用表格应用打开的 CSV。';

  @override
  String get queue_reorderTask => '调整任务顺序';

  @override
  String get queue_moreTaskActions => '更多任务操作';

  @override
  String get queue_selectTask => '选择任务';

  @override
  String get settings_notificationSoundImportFailed => '无法导入音效，请重新选择文件。';

  @override
  String get settings_androidManagedStorage => '由系统安全管理；导出时可选择保存位置';

  @override
  String get settings_importLocalOnnxTaggerFiles => '导入 ONNX 模型、标签文件或 ZIP 压缩包';

  @override
  String settings_localOnnxFilesImported(int count) {
    return '已导入 $count 个模型文件';
  }

  @override
  String settings_localOnnxManagedFiles(int count) {
    return '应用存储中有 $count 个模型文件';
  }

  @override
  String get settings_clearLocalOnnxModelsTitle => '清除本地 ONNX 模型？';

  @override
  String get settings_clearLocalOnnxModelsContent => '将删除导入到此设备的 ONNX 模型及标签文件。';

  @override
  String updateAndroidDownloadedHint(Object version) {
    return '新版本 v$version 已下载并通过校验。可以打开 Android 系统安装界面继续更新。';
  }

  @override
  String get updateAndroidInstallingHint => '正在打开 Android 系统安装界面，请按系统提示确认更新。';

  @override
  String get updateAndroidInstallConfirmationBody =>
      '将打开 Android 系统安装界面。确认安装后，系统会替换应用且不会清除本地数据；进行中的生成和下载任务可能停止，请先保存必要内容。';

  @override
  String get preciseRefLib_moreActions => '更多操作';

  @override
  String get vibeDetail_setAsCover => '将所选图片设为封面';

  @override
  String vibeDetail_bundleChildParameters(int index) {
    return '正在显示第 $index 个子 Vibe 的导入参数。';
  }

  @override
  String get vibeDetail_bundleDefaultParameters => '正在显示合集默认参数。选择下方子项可查看其参数。';

  @override
  String get vibeDetail_choosePreviewImage => '点击图片按钮选择预览图';

  @override
  String get cloudSync_title => '备份与恢复';

  @override
  String get cloudSync_description =>
      '将设置、提示词等内容推送到你自己的 WebDAV 或 GitHub，或从云端备份拉取到当前设备。';

  @override
  String get cloudSync_disconnected => '尚未连接';

  @override
  String get cloudSync_oneClickDescription =>
      '选择存储服务并填写账号信息。保存只会验证并记住连接，不会推送或拉取数据。';

  @override
  String get cloudSync_saveConnection => '保存连接';

  @override
  String get cloudSync_operationInProgress => '另一项云同步操作正在进行，请稍后重试。';

  @override
  String get cloudSync_fillRequiredFields => '请填写当前服务商的必填连接信息。';

  @override
  String get cloudSync_advancedSettings => '高级设置';

  @override
  String get cloudSync_connectionManagement => '存储连接';

  @override
  String get cloudSync_chooseBackend => '备份到哪里';

  @override
  String get cloudSync_chooseBackendDescription =>
      '先选择同步目的地，再连接账号并选择要同步的内容。凭据只保存在设备安全存储中。';

  @override
  String cloudSync_oauthDescription(String provider) {
    return '连接 $provider 账号';
  }

  @override
  String get cloudSync_oauthSystemBrowser => '将使用系统浏览器安全登录；无需在应用中输入密码。';

  @override
  String cloudSync_oauthUnavailable(String details) {
    return '此版本缺少 OAuth 发布配置，暂时无法连接。请向发布者提供以下诊断：\n$details';
  }

  @override
  String cloudSync_accountConnected(String provider) {
    return '已连接 $provider';
  }

  @override
  String get cloudSync_connectAccount => '连接账号';

  @override
  String get cloudSync_changeAccount => '更换账号';

  @override
  String get cloudSync_connectedAccount => '已连接账号';

  @override
  String get cloudSync_webDavUrl => 'WebDAV 地址';

  @override
  String get cloudSync_allowInsecureHttp => '允许不安全的 HTTP';

  @override
  String get cloudSync_allowInsecureHttpWarning =>
      'HTTP 会以明文传输 WebDAV 凭据和备份数据。仅在可信内网且明确了解风险时启用。';

  @override
  String get cloudSync_username => '用户名';

  @override
  String get cloudSync_password => '密码';

  @override
  String get cloudSync_remotePath => '备份文件夹';

  @override
  String get cloudSync_githubToken => 'GitHub 访问令牌';

  @override
  String get cloudSync_owner => 'GitHub 用户或组织';

  @override
  String get cloudSync_repository => '仓库';

  @override
  String get cloudSync_branch => '分支（通常为 main）';

  @override
  String get cloudSync_testFailed => '连接测试失败';

  @override
  String get cloudSync_operationFailed => '云同步操作失败';

  @override
  String get cloudSync_manualBackupOnly => '只支持手动推送与拉取';

  @override
  String get cloudSync_manualBackupOnlyDescription =>
      '此服务无法可靠处理多台设备同时修改。这里不会自动合并或覆盖，只按你的选择推送或拉取。';

  @override
  String get cloudSync_chooseBackupContents => '选择备份内容';

  @override
  String get cloudSync_backupContentDescription => '仅备份恢复所需的数据；图片资源会在上传前压缩。';

  @override
  String get cloudSync_lightweightData => '轻量数据（默认）';

  @override
  String get cloudSync_settingsDescription => '主题、生成参数和应用偏好';

  @override
  String get cloudSync_promptsAndTags => '提示词与词库';

  @override
  String get cloudSync_promptsAndTagsDescription => '条目、分类、固定词和预设';

  @override
  String get cloudSync_tagThumbnails => '词库预览图';

  @override
  String get cloudSync_tagThumbnailsDescription => '上传前压缩，不保存原图';

  @override
  String get cloudSync_onlineGallerySettings => '在线画廊设置';

  @override
  String get cloudSync_onlineGallerySettingsDescription => '黑名单、筛选和用户分类';

  @override
  String get cloudSync_onlineGalleryFavorites => '在线画廊收藏';

  @override
  String get cloudSync_onlineGalleryFavoritesDescription =>
      '仅保存来源 ID 与恢复所需信息，不保存原图';

  @override
  String get cloudSync_galleryAlbums => '本地画廊相册';

  @override
  String get cloudSync_galleryAlbumsDescription => '只保存相册结构与图片引用，不上传原图';

  @override
  String get cloudSync_optionalResources => '可选资源（默认关闭）';

  @override
  String get cloudSync_vibes => 'Vibe';

  @override
  String get cloudSync_preciseReferences => '精准参考';

  @override
  String get cloudSync_largeResourceDescription => '包含恢复所需资源，可能显著增加体积';

  @override
  String get cloudSync_neverBackedUp => '云端凭据、缓存、日志、浏览历史和远程图库原图始终不会备份。';

  @override
  String get cloudSync_restoreDefaults => '恢复默认';

  @override
  String get cloudSync_saveSelection => '保存选择';

  @override
  String cloudSync_selectedContentSummary(int count) {
    return '已选择 $count 项内容';
  }

  @override
  String get cloudSync_rebuildCompactBackup => '清理旧备份并重新建立';

  @override
  String get cloudSync_rebuildCompactBackupDescription =>
      '删除当前云端备份空间并按现有选择上传新的精简备份。服务商保留的历史版本不会被重写。';

  @override
  String get cloudSync_rebuildCompactBackupConfirm =>
      '删除当前云端备份并立即上传新的精简备份吗？此操作不能撤销。';

  @override
  String get cloudSync_kindSettings => '设置';

  @override
  String get cloudSync_kindPrompts => '提示词与预设';

  @override
  String get cloudSync_kindGalleries => '在线画廊收藏、分类与过滤';

  @override
  String get cloudSync_kindLargeFiles => '图片与其他大文件';

  @override
  String get cloudSync_agentContentTitle => '智能体设置';

  @override
  String get cloudSync_agentSystemPrompt => '自定义系统提示词';

  @override
  String get cloudSync_agentSystemPromptDescription =>
      '保存你修改的提示词和使用方式；模型与账号信息仍只保留在此设备。';

  @override
  String get cloudSync_skillsBackup => '备份已选 Skill';

  @override
  String get cloudSync_skillsBackupDescription => '备份开关默认开启；只备份你在下方选择的 Skill。';

  @override
  String get cloudSync_chooseSkills => '选择 Skill';

  @override
  String cloudSync_skillsSelectedCount(Object count) {
    return '已选择 $count 个 Skill';
  }

  @override
  String cloudSync_missingSelectedSkills(Object count) {
    return '其中 $count 个当前不可用';
  }

  @override
  String get cloudSync_removeMissingSkills => '移除不可用项';

  @override
  String get cloudSync_searchSkills => '搜索 Skill';

  @override
  String get cloudSync_noSkills => '没有匹配的 Skill';

  @override
  String cloudSync_actionFailed(Object error) {
    return '操作失败：$error';
  }

  @override
  String get cloudSync_errorAuthentication => '登录状态已过期，请重新连接账号。';

  @override
  String get cloudSync_errorAuthorization => '当前账号无权访问备份位置。';

  @override
  String get cloudSync_errorNotFound => '未找到云端备份目录或文件。';

  @override
  String get cloudSync_errorConflict => '云端数据已被其他设备更新，请先拉取最新数据再重试。';

  @override
  String get cloudSync_errorQuota => '云存储空间不足。';

  @override
  String get cloudSync_errorRateLimited => '云存储请求过于频繁，请稍后重试。';

  @override
  String get cloudSync_errorRedirect => '服务商将请求重定向到不受信任的地址，操作已停止。';

  @override
  String get cloudSync_errorInvalidResponse => '服务商返回了无法验证的数据。';

  @override
  String get cloudSync_errorNetwork => '无法连接云存储，请检查网络后重试。';

  @override
  String get cloudSync_errorPreviewStale => '预览后数据发生了变化，请重新查看变化后再继续。';

  @override
  String get cloudSync_errorFormat => '备份格式或完整性校验失败。';

  @override
  String get cloudSync_errorConfiguration => '保存的同步配置无法读取。';

  @override
  String get cloudSync_errorState => '同步状态已变化，请重试当前操作。';

  @override
  String get cloudSync_errorUnknown => '同步失败，请检查连接后重试。';

  @override
  String get cloudSync_connectionDetails => '存储信息';

  @override
  String get cloudSync_backend => '存储服务';

  @override
  String get cloudSync_deviceName => '本机名称';

  @override
  String get cloudSync_lastSync => '上次完成';

  @override
  String get cloudSync_connectedDescription => '连接正常，可以推送本机备份或拉取云端数据。';

  @override
  String get cloudSync_providerWarning => '存储服务提示';

  @override
  String get cloudSync_warningGoogleDriveWeakCas =>
      'Google Drive 无法保证文件内容的原子条件更新，因此此连接仅支持显式手动推送与拉取。';

  @override
  String get cloudSync_warningGithubPublicRepository =>
      '当前 GitHub 仓库是公开仓库，备份内容也会公开。私密数据请改用私有仓库。';

  @override
  String get cloudSync_warningWebDavWeakCas =>
      '此服务器无法保证安全的条件更新。当前仅支持手动备份，后续写入可能替换同一个 HEAD。';

  @override
  String get cloudSync_warningWebDavUnverifiedCas =>
      'WebDAV 连接已通过只读验证，但尚未验证安全的条件写入。当前仅支持手动推送与拉取。';

  @override
  String get cloudSync_githubHistoryRetention => 'GitHub 空间说明';

  @override
  String get cloudSync_githubHistoryRetentionDescription =>
      '删除云端备份后，GitHub 的旧提交仍会占用仓库空间。需要彻底清理时，请在 GitHub 中新建仓库。';

  @override
  String get cloudSync_upToDate => '已连接';

  @override
  String get cloudSync_syncing => '正在传输';

  @override
  String get cloudSync_paused => '已暂停';

  @override
  String get cloudSync_syncControls => '推送与拉取';

  @override
  String get cloudSync_pushLocal => '推送到云端';

  @override
  String get cloudSync_pullRemote => '从云端拉取';

  @override
  String get cloudSync_pushConfirmTitle => '推送本机数据？';

  @override
  String get cloudSync_pushConfirmDescription =>
      '将以当前本机数据创建新的云端备份，并把云端当前版本切换到该备份。';

  @override
  String get cloudSync_pullConfirmTitle => '拉取云端数据？';

  @override
  String get cloudSync_pullConfirmDescription =>
      '将使用云端最新备份更新本机已选择的数据。尚未推送的本机更改可能被替换。';

  @override
  String get cloudSync_pause => '暂停';

  @override
  String get cloudSync_resume => '继续';

  @override
  String get cloudSync_cancel => '取消';

  @override
  String get cloudSync_progress => '传输进度';

  @override
  String get cloudSync_metricsDetails => '技术详情';

  @override
  String get cloudSync_metricsElapsed => '总耗时';

  @override
  String get cloudSync_metricsRequests => '服务请求';

  @override
  String get cloudSync_metricsRead => '已接收';

  @override
  String get cloudSync_metricsWritten => '已发送';

  @override
  String get cloudSync_metricsHashPasses => '完整性校验';

  @override
  String get cloudSync_metricsPayloadReads => '数据读取次数';

  @override
  String get cloudSync_metricsLocalRead => '本地读取';

  @override
  String get cloudSync_metricsLocalWritten => '本地写入';

  @override
  String get cloudSync_metricsFlushes => '磁盘刷新';

  @override
  String get cloudSync_stage => '当前进度';

  @override
  String get cloudSync_objects => '已处理';

  @override
  String get cloudSync_reusedObjects => '已复用未变化项';

  @override
  String get cloudSync_bytes => '已传输';

  @override
  String get cloudSync_stagePreparing => '正在准备';

  @override
  String get cloudSync_stageScanning => '正在扫描所选数据';

  @override
  String get cloudSync_stageHashing => '正在校验本地内容';

  @override
  String get cloudSync_stageDownloading => '正在下载';

  @override
  String get cloudSync_stageVerifying => '正在校验下载内容';

  @override
  String get cloudSync_stageMerging => '正在整理两端内容';

  @override
  String get cloudSync_stageReusing => '正在复用未变化内容';

  @override
  String get cloudSync_stageUploading => '正在上传';

  @override
  String get cloudSync_stageCommitting => '正在发布备份';

  @override
  String get cloudSync_stageApplying => '正在保存更改';

  @override
  String get cloudSync_stageSaving => '正在保存恢复状态';

  @override
  String get cloudSync_stageRetryWaiting => '等待重试';

  @override
  String get cloudSync_stageRollingBack => '正在恢复原状';

  @override
  String get cloudSync_stageCompleted => '已完成';

  @override
  String get cloudSync_stageWorking => '正在处理';

  @override
  String get cloudSync_snapshotHistory => '以前的备份';

  @override
  String get cloudSync_snapshotHistoryDescription =>
      '可以先查看某次备份会带来哪些变化，再决定是否恢复。当前数据不会直接被覆盖。';

  @override
  String get cloudSync_noSnapshots => '还没有可恢复的备份。';

  @override
  String cloudSync_backupItemCount(int count) {
    return '包含 $count 项内容';
  }

  @override
  String get cloudSync_previewRestore => '查看并恢复';

  @override
  String get cloudSync_restorePreviewTitle => '恢复前确认';

  @override
  String get cloudSync_restorePreviewDescription =>
      '检查恢复后会新增、更新或删除哪些内容。确认前不会修改当前数据。';

  @override
  String get cloudSync_mergePreviewTitle => '合并内容确认';

  @override
  String get cloudSync_mergePreviewDescription =>
      '本机和云端的数据不同。请检查变化并选择要保留的内容。确认前不会修改数据。';

  @override
  String get cloudSync_previewAwaitingConfirmation => '请先确认下方变化。';

  @override
  String get cloudSync_previewDeletesTitle => '将删除当前设备上的内容';

  @override
  String cloudSync_previewDeletesDescription(Object count) {
    return '恢复后会从当前设备删除 $count 项内容，请确认这些变化符合预期。';
  }

  @override
  String cloudSync_previewCounts(
    Object added,
    Object modified,
    Object deleted,
  ) {
    return '新增 $added · 修改 $modified · 删除 $deleted';
  }

  @override
  String get cloudSync_previewNoChanges => '没有需要应用的变化。';

  @override
  String get cloudSync_confirmMerge => '确认应用';

  @override
  String get cloudSync_confirmRestore => '确认恢复';

  @override
  String get cloudSync_ffdkjIntentTitle => '检测到词库设置';

  @override
  String get cloudSync_ffdkjIntentDescription =>
      '另一台设备安装了 ffdkj 中文词库。词库文件不会通过云端传输。';

  @override
  String get cloudSync_ffdkjInstallWarning => '是否从 ffdkj 官方来源下载并安装中文词库？';

  @override
  String get cloudSync_clearInstallIntent => '暂不安装并清除提示';

  @override
  String get cloudSync_deleteRemoteNamespace => '删除云端备份';

  @override
  String get cloudSync_deleteRemoteNamespaceDescription =>
      '删除 Aaalice 在此服务中保存的全部备份，不会删除当前设备的数据。';

  @override
  String get cloudSync_deleteRemoteConfirm => '确定删除全部云端备份吗？当前设备的数据会保留。';

  @override
  String get cloudSync_disconnect => '断开连接';

  @override
  String get cloudSync_disconnectDescription => '移除此设备保存的存储连接，云端已有备份会保留。';

  @override
  String get cloudSync_disconnectConfirm => '确定断开此设备吗？云端已有备份会保留。';

  @override
  String get cloudSync_confirm => '确认';

  @override
  String get cloudSync_conflictCenter => '内容有冲突';

  @override
  String get cloudSync_conflictDescription => '同一内容在此设备和云端都被修改。请选择要保留的版本。';

  @override
  String get cloudSync_needsConflictResolution => '请选择要保留的内容';

  @override
  String get cloudSync_deferredConflictWarning => '还有内容没有选择，完成后才能继续。';

  @override
  String get cloudSync_applyAll => '全部选择：';

  @override
  String get cloudSync_base => '上次保存';

  @override
  String get cloudSync_local => '此设备';

  @override
  String get cloudSync_remote => '云端';

  @override
  String get cloudSync_chooseLocal => '保留此设备版本';

  @override
  String get cloudSync_chooseRemote => '保留云端版本';

  @override
  String get cloudSync_keepBoth => '两者都保留';

  @override
  String get cloudSync_largeBinaryKeepBothDefault => '大文件会默认保留两个版本，避免丢失。';

  @override
  String get settings_agent => '智能体';

  @override
  String get agentSettings_subtitle => '管理聊天模型、工具权限、联网、系统提示词与 Skills。';

  @override
  String get agentSettings_readingAppearance => '阅读与密度';

  @override
  String get agentSettings_readingTextSize => '阅读字号';

  @override
  String get agentSettings_readingTextSizeDescription => '仅调整智能体面板，并叠加全局字体缩放。';

  @override
  String get agentSettings_density => '界面密度';

  @override
  String get agentSettings_densityDescription => '舒适模式优先保证触控与留白；紧凑模式适合桌面高信息密度。';

  @override
  String get agentSettings_densityComfortable => '舒适';

  @override
  String get agentSettings_densityCompact => '紧凑';

  @override
  String get agentSettings_chatModel => '聊天模型';

  @override
  String get agentSettings_providerModel => '供应商 / 模型';

  @override
  String get agentSettings_modelManagedInIntegrations =>
      '供应商、API Key 与模型发现仍在“集成”中统一管理。';

  @override
  String get agentSettings_manageProviders => '管理服务商';

  @override
  String get agentSettings_noModel => '没有可用聊天模型。请先在“集成”中添加供应商并发现模型。';

  @override
  String get agentSettings_pendingMatch => '待匹配';

  @override
  String get agentSettings_contextWindow => '上下文窗口（token）';

  @override
  String agentSettings_contextWindowKnown(String value) {
    return '留空使用内置值 $value。第三方中转站或自定义部署的实际窗口不同时，在此填写覆盖。';
  }

  @override
  String get agentSettings_contextWindowUnknown =>
      '内置目录未收录该模型，无法自动判断窗口。不填写则无法显示上下文用量，也无法压缩上下文。';

  @override
  String get agentSettings_contextWindowUnknownHint => '例如 128000';

  @override
  String get agentSettings_contextWindowReset => '恢复为内置值';

  @override
  String get agentSettings_contextWindowInvalid => '请填写 1 到 20000000 之间的整数';

  @override
  String get agentSettings_toolPermission => '工具权限';

  @override
  String get agentSettings_permissionSafe => '安全';

  @override
  String get agentSettings_permissionSafeDescription =>
      '仅运行只读和低风险操作，不弹出敏感操作授权。';

  @override
  String get agentSettings_permissionAsk => '敏感操作前询问';

  @override
  String get agentSettings_permissionAskDescription =>
      '默认模式。写文件、执行生成等敏感操作前先请求确认。';

  @override
  String get agentSettings_permissionFull => '完全访问';

  @override
  String get agentSettings_permissionFullDescription =>
      '允许访问工作区外文件并直接执行工具。仅在信任当前任务时使用。';

  @override
  String get agentSettings_webPreference => '联网偏好';

  @override
  String get agentSettings_webEnabled => '允许智能体使用 Web 工具';

  @override
  String get agentSettings_webDescription =>
      '开启后模型可搜索并读取公开网页；关闭后相关工具会从运行时工具表移除。';

  @override
  String get agentSettings_systemPrompt => '系统提示词';

  @override
  String get agentSettings_edit => '编辑';

  @override
  String get agentSettings_previewFinalPrompt => '预览最终提示词';

  @override
  String get agentSettings_systemPromptDescription => '选择下方内容如何应用到智能体的系统提示词。';

  @override
  String get agentSettings_promptModeAppend => '追加';

  @override
  String get agentSettings_promptModeAppendDescription =>
      '保留内置说明与 Skills 列表，并在末尾追加下方内容。';

  @override
  String get agentSettings_promptModeOverride => '覆盖';

  @override
  String get agentSettings_promptModeOverrideDescription =>
      '仅将下方内容作为系统提示词；内置说明与 Skills 列表不会加入，但 Provider 必需的结构化工具定义仍会发送。';

  @override
  String get agentSettings_systemPromptHint => '例如：优先给出简洁结论；修改提示词前先说明影响。';

  @override
  String get agentSettings_restoreDefault => '恢复默认';

  @override
  String get agentSettings_promptSaved => '系统提示词已保存';

  @override
  String get agentSettings_discardPromptTitle => '放弃未保存的系统提示词？';

  @override
  String get agentSettings_discardPromptBody => '离开此页面会丢失尚未保存的修改。';

  @override
  String get agentSettings_keepEditing => '继续编辑';

  @override
  String get agentSettings_discardChanges => '放弃修改';

  @override
  String get agentSettings_importProfile => '导入配置';

  @override
  String get agentSettings_exportProfile => '导出配置';

  @override
  String get agentSettings_profilePrivacy => '此文件不包含 API Key、Token、聊天记录或本机路径。';

  @override
  String get agentSettings_profilePending =>
      '未安装的模型或 Skill 不会伪装为可用；偏好会保留，待以后安装后生效。';

  @override
  String get agentSettings_reloadSkills => '重新扫描';

  @override
  String get agentSettings_importSkills => '从 ZIP 导入';

  @override
  String get agentSettings_exportSkills => '导出所选 Skills';

  @override
  String get agentSettings_searchSkills => '搜索名称或描述';

  @override
  String get agentSettings_filterAll => '全部';

  @override
  String get agentSettings_filterEnabled => '已启用';

  @override
  String get agentSettings_filterDisabled => '已禁用';

  @override
  String agentSettings_skillEnabledCount(int enabled, int total) {
    return '已启用 $enabled/$total';
  }

  @override
  String get agentSettings_diagnostics => '诊断';

  @override
  String get agentSettings_noMatchingSkill => '没有匹配的 Skill';

  @override
  String get agentSettings_noDiagnostics => '未发现诊断问题';

  @override
  String get agentSettings_skillExplicitOnly =>
      '该 Skill 只能由用户显式调用，不会出现在模型可见列表中';

  @override
  String get agentSettings_exportPrivacy =>
      '只会导出明确勾选的 Skill；.env、密钥、Token、Git 与依赖目录不会打包。';

  @override
  String get agentSettings_continueExport => '继续导出';

  @override
  String get agentSettings_install => '安装';

  @override
  String get agentSettings_apply => '应用';

  @override
  String agentSettings_operationFailed(String error) {
    return '操作失败：$error';
  }

  @override
  String get agentSettings_skillsTitle => 'Skills';

  @override
  String get agentSettings_skillsSourceHint =>
      '当前图片项目中的 Skill 会自动启用；Pi 用户与用户全局 Skill 仅在手动开启后使用。';

  @override
  String get agentSettings_skillTransfer => '导入或导出';

  @override
  String get agentSettings_skillsRescanned => 'Skills 已重新扫描';

  @override
  String agentSettings_skillScanFailed(String error) {
    return '扫描失败：$error';
  }

  @override
  String get agentSettings_exportSkillsTitle => '导出 Skills';

  @override
  String get agentSettings_skillsExported => 'Skills 已导出';

  @override
  String get agentSettings_skillZipReadFailed => '无法读取 ZIP 文件';

  @override
  String get agentSettings_confirmSkillsImport => '确认导入 Skills';

  @override
  String agentSettings_skillArchiveStats(int files, int bytes) {
    return '$files 个文件 · $bytes 字节';
  }

  @override
  String get agentSettings_skillConflictReplace => '存在同名 Skill，勾选以替换';

  @override
  String get agentSettings_skillConflictUnsafe => '目标是文件、链接或特殊实体，不能替换';

  @override
  String get agentSettings_skillsInstalled => 'Skills 已安装';

  @override
  String agentSettings_skillShadowed(String name) {
    return '$name 被更高优先级来源覆盖';
  }

  @override
  String agentSettings_preferredSource(String source) {
    return '优先来源：$source';
  }

  @override
  String get agentSettings_sourceWorkspace => '当前图片项目';

  @override
  String get agentSettings_sourcePiUser => 'Pi 用户';

  @override
  String get agentSettings_sourceCommonUser => '用户全局';

  @override
  String get agentSettings_exportProfileTitle => '导出智能体配置';

  @override
  String get agentSettings_profileExported => '智能体配置已导出';

  @override
  String get agentSettings_profileReadFailed => '无法读取配置文件';

  @override
  String get agentSettings_confirmProfileImport => '确认导入智能体配置';

  @override
  String get agentSettings_profileNoChanges => '当前配置不会发生变化';

  @override
  String agentSettings_profileChanges(String changes) {
    return '将变更：$changes';
  }

  @override
  String get agentSettings_listSeparator => '、';

  @override
  String get agentSettings_pendingPreferences => '待匹配偏好';

  @override
  String agentSettings_missingModel(String model) {
    return '当前未提供模型：$model';
  }

  @override
  String agentSettings_missingSkill(String skill) {
    return '当前未安装 Skill：$skill';
  }

  @override
  String get agentSettings_profileImported => '智能体配置已导入';

  @override
  String get settings_watermarkTitle => '水印';

  @override
  String get settings_watermarkSubtitle => '完全在本地创建水印副本，不改动原图';

  @override
  String get settings_watermarkEnable => '启用水印工具';

  @override
  String get settings_watermarkPreserveMetadata => '水印副本保留元数据';

  @override
  String get settings_watermarkPreserveMetadataHint =>
      '关闭时清除 PNG 文本、EXIF、NovelAI 隐写数据、提示词和种子；开启时把原图中受支持的元数据安全写入新 PNG。';

  @override
  String get settings_watermarkEditDefault => '编辑默认水印';

  @override
  String get settings_watermarkCreateFromImage => '选择图片并创建水印副本…';

  @override
  String get settings_watermarkLayoutByOrientation => '按图片方向分别记忆布局';

  @override
  String get settings_watermarkLayoutByOrientationHint =>
      '文字和样式共用，竖图、方图与横图分别保存位置。';

  @override
  String get settings_watermarkConfigMigrated => '旧版水印配置已迁移供检查，请保存以确认当前默认方案。';

  @override
  String get settings_watermarkConfigCorrupted =>
      '水印配置无法读取，当前显示安全默认值；保存后才会替换损坏数据。';

  @override
  String get watermark_actionCreate => '创建水印副本…';

  @override
  String get watermark_actionRegenerate => '重新生成水印副本…';

  @override
  String get watermark_actionDownloadCreate => '下载并添加水印…';

  @override
  String get watermark_editorTitle => '水印编辑器';

  @override
  String get watermark_textLayer => '文字';

  @override
  String get watermark_logoLayer => 'Logo';

  @override
  String get watermark_enableLayer => '显示图层';

  @override
  String get watermark_text => '水印文字';

  @override
  String get watermark_alignment => '文字对齐';

  @override
  String get editor_colorHex => '十六进制颜色值';

  @override
  String get editor_colorSaturationBrightness => '颜色饱和度与明度';

  @override
  String get editor_colorHue => '颜色色相';

  @override
  String get watermark_alignLeft => '左对齐';

  @override
  String get watermark_alignCenter => '居中对齐';

  @override
  String get watermark_alignRight => '右对齐';

  @override
  String get watermark_font => '字体';

  @override
  String get watermark_chooseLogo => '选择 Logo';

  @override
  String get watermark_replaceLogo => '更换 Logo';

  @override
  String get watermark_logoMissing => '已保存的 Logo 缺失，请重新选择后再保存。';

  @override
  String get watermark_logoImportFailed =>
      '无法导入 Logo。请选择尺寸受支持且有效的静态 PNG、JPEG 或 WebP 图片。';

  @override
  String get watermark_opacity => '透明度';

  @override
  String get watermark_size => '大小';

  @override
  String get watermark_letterSpacing => '字间距';

  @override
  String get watermark_stroke => '描边';

  @override
  String get watermark_shadow => '柔和阴影';

  @override
  String get watermark_margin => '边距';

  @override
  String get watermark_anchor => '位置锚点';

  @override
  String get watermark_anchorTopLeft => '左上';

  @override
  String get watermark_anchorTopCenter => '顶部居中';

  @override
  String get watermark_anchorTopRight => '右上';

  @override
  String get watermark_anchorCenterLeft => '左侧居中';

  @override
  String get watermark_anchorCenter => '画布中心';

  @override
  String get watermark_anchorCenterRight => '右侧居中';

  @override
  String get watermark_anchorBottomLeft => '左下';

  @override
  String get watermark_anchorBottomCenter => '底部居中';

  @override
  String get watermark_anchorBottomRight => '右下';

  @override
  String get watermark_layerArrangement => '图层排列';

  @override
  String get watermark_arrangementIndependent => '独立';

  @override
  String get watermark_arrangementHorizontal => '横向组合';

  @override
  String get watermark_arrangementVertical => '纵向组合';

  @override
  String get watermark_zOrder => '将所选图层置于上层';

  @override
  String get watermark_ratioOriginal => '原图';

  @override
  String get watermark_ratioPortrait => '竖图';

  @override
  String get watermark_ratioSquare => '方图';

  @override
  String get watermark_ratioLandscape => '横图';

  @override
  String get watermark_layoutUniversal => '通用布局';

  @override
  String get watermark_layoutPortrait => '竖图布局';

  @override
  String get watermark_layoutSquare => '方图布局';

  @override
  String get watermark_layoutLandscape => '横图布局';

  @override
  String get watermark_metadataRemoved => '将按“安全与分享”设置清除副本元数据。';

  @override
  String get watermark_metadataPreserved => '会把原图中受支持的元数据写入新副本。';

  @override
  String get watermark_setDefault => '设为默认';

  @override
  String get watermark_defaultSaved => '默认水印已更新';

  @override
  String get watermark_saveCopy => '保存副本';

  @override
  String get watermark_saving => '正在渲染原始分辨率图片…';

  @override
  String get watermark_saved => '水印副本已保存';

  @override
  String get watermark_share => '分享';

  @override
  String get watermark_open => '打开';

  @override
  String get watermark_undo => '撤销';

  @override
  String get watermark_reset => '重置';

  @override
  String get watermark_noLayer => '保存前请启用文字或 Logo。';

  @override
  String get watermark_cancelled => '已取消水印渲染';

  @override
  String watermark_failed(Object error) {
    return '无法创建水印副本：$error';
  }

  @override
  String get watermark_failedGeneric => '无法创建水印副本，请检查图片后重试。';

  @override
  String get watermark_systemGalleryExportFailed =>
      '副本已保存在 Aaalice 中，但未能添加到系统图库。';

  @override
  String get watermark_galleryRefreshFailed => '副本已保存，但图库未能刷新；重新打开图库即可重试。';

  @override
  String get watermark_sourceMissing => '找不到原图，请重新选择原图后再生成水印。';

  @override
  String get watermark_chooseOriginal => '选择原图';

  @override
  String get watermark_dragHint => '拖动所选图层；方向键可精细移动，按住 Shift 可加大步长。';

  @override
  String get watermark_moveLeft => '向左移动图层';

  @override
  String get watermark_moveRight => '向右移动图层';

  @override
  String get watermark_moveUp => '向上移动图层';

  @override
  String get watermark_moveDown => '向下移动图层';

  @override
  String get watermark_sourceLoadFailed =>
      '无法打开此图片。请确认文件是有效的静态 PNG、JPEG、WebP 或 BMP 图片后重试。';
}

/// The translations for Chinese, using the Han script (`zh_Hant`).
class AppLocalizationsZhHant extends AppLocalizationsZh {
  AppLocalizationsZhHant() : super('zh_Hant');

  @override
  String get app_title => 'NAI 啟動器';

  @override
  String get app_subtitle => 'NovelAI 第三方客戶端';

  @override
  String get desktopWindow_minimize => '最小化';

  @override
  String get desktopWindow_maximize => '最大化';

  @override
  String get desktopWindow_restore => '還原';

  @override
  String get desktopWindow_close => '關閉視窗';

  @override
  String get common_cancel => '取消';

  @override
  String get common_confirm => '確定';

  @override
  String get common_continue => '繼續';

  @override
  String get common_selectAll => '全選';

  @override
  String get common_deselectAll => '全不選';

  @override
  String get common_save => '儲存';

  @override
  String get common_delete => '刪除';

  @override
  String get common_edit => '編輯';

  @override
  String get common_close => '關閉';

  @override
  String get common_clear => '清除';

  @override
  String get common_copy => '複製';

  @override
  String get common_copied => '已複製';

  @override
  String get common_export => '匯出';

  @override
  String get common_import => '匯入';

  @override
  String get common_loading => '載入中...';

  @override
  String get common_error => '錯誤';

  @override
  String get common_success => '成功';

  @override
  String get common_retry => '重試';

  @override
  String get common_select => '選擇';

  @override
  String get common_reset => '重置';

  @override
  String get common_search => '搜尋';

  @override
  String get common_add => '新增';

  @override
  String get common_added => '已新增';

  @override
  String get common_new => '新建';

  @override
  String get common_confirmDelete => '確認刪除';

  @override
  String get common_confirmClear => '確認清空';

  @override
  String get common_gotIt => '知道了';

  @override
  String common_deleteItemConfirm(Object itemName) {
    return '確定要刪除「$itemName」嗎？此操作不可撤銷。';
  }

  @override
  String common_clearAllItemsConfirm(Object count, Object itemType) {
    return '確定要清空所有 $count 個$itemType嗎？此操作不可撤銷。';
  }

  @override
  String get common_clearInputConfirm => '確定要清空輸入內容嗎？';

  @override
  String get common_today => '今天';

  @override
  String get common_yesterday => '昨天';

  @override
  String common_daysAgo(Object days) {
    return '$days天前';
  }

  @override
  String get common_undo => '撤銷';

  @override
  String get common_redo => '重做';

  @override
  String get common_refresh => '重新整理';

  @override
  String get common_download => '下載';

  @override
  String get common_apply => '應用';

  @override
  String get common_move => '移動';

  @override
  String get common_favorite => '收藏';

  @override
  String get common_unfavorite => '取消收藏';

  @override
  String get common_ok => '確定';

  @override
  String get common_replace => '替換';

  @override
  String get common_skip => '跳過';

  @override
  String get common_exit => '退出';

  @override
  String get common_folder => '資料夾';

  @override
  String get common_filter => '篩選';

  @override
  String get common_grid => '網格';

  @override
  String get common_list => '列表';

  @override
  String get common_grouped => '分組';

  @override
  String get common_date => '日期';

  @override
  String get common_pack => '打包';

  @override
  String get common_multiSelect => '多選';

  @override
  String get common_category => '分類';

  @override
  String get common_categories => '分類';

  @override
  String get networkError_connectionTimeout => '連線超時，請檢查網路連線。';

  @override
  String get networkError_sendTimeout => '傳送超時，請重試。';

  @override
  String get networkError_receiveTimeout => '接收超時，影象生成可能需要更長時間。';

  @override
  String get networkError_requestCancelled => '請求已取消';

  @override
  String get networkError_connection => '網路連線錯誤，請檢查網路連線。';

  @override
  String get networkError_unknown => '未知錯誤';

  @override
  String get networkError_noResponse => '伺服器無響應';

  @override
  String get networkError_badRequest => '請求引數錯誤';

  @override
  String get networkError_authFailed => '認證失敗，請重新登入。';

  @override
  String get networkError_insufficientAnlas => 'Anlas 不足';

  @override
  String get networkError_forbidden => '無許可權訪問該資源';

  @override
  String get networkError_notFound => '請求的資源不存在';

  @override
  String get networkError_conflict => '請求與當前狀態衝突';

  @override
  String get networkError_rateLimited => '請求過於頻繁，請稍後重試。';

  @override
  String get networkError_serverInternal => '伺服器內部錯誤';

  @override
  String get networkError_badGateway => '伺服器閘道器錯誤';

  @override
  String get networkError_unavailable => '服務暫時不可用';

  @override
  String networkError_requestFailed(int code) {
    return '請求失敗（$code）';
  }

  @override
  String get nav_canvas => '畫布';

  @override
  String get nav_localGallery => '本地圖庫';

  @override
  String get nav_onlineGallery => '線上畫廊';

  @override
  String get nav_statistics => '統計';

  @override
  String get nav_randomConfig => '隨機配置';

  @override
  String get nav_dictionary => '詞庫';

  @override
  String get nav_discordCommunity => 'Discord 社群';

  @override
  String get nav_githubRepo => 'GitHub 倉庫';

  @override
  String get nav_joinDiscord => '加入 Discord';

  @override
  String get nav_projectRepository => '專案倉庫';

  @override
  String get nav_expandSidebar => '展開側邊欄';

  @override
  String get nav_collapseSidebar => '收起側邊欄';

  @override
  String get auth_login => '登入';

  @override
  String get auth_logout => '退出登入';

  @override
  String get auth_continueWithoutLogin => '跳過登入，進入主畫面';

  @override
  String get auth_loginRequiredImageGeneration => '請先登入，再使用 NovelAI 生成圖片。';

  @override
  String get auth_loginRequiredQueueExecution => '請先登入，再啟動 NovelAI 生成佇列。';

  @override
  String get auth_loginRequiredDirectorTools =>
      '請先登入，再使用 NovelAI Director Tools。';

  @override
  String get auth_loginRequiredNovelAiUpscale => '請先登入，再使用 NovelAI 雲端超分。';

  @override
  String get auth_loginRequiredKritaBridge => '請先登入，再透過 Krita Bridge 生成圖片。';

  @override
  String get auth_loginRequiredVibeEncoding => '請先登入，再使用 NovelAI 編碼 Vibe 圖片。';

  @override
  String get auth_email => '郵箱';

  @override
  String get auth_password => '密碼';

  @override
  String get auth_loginButton => '登入';

  @override
  String get auth_loginFailed => '登入失敗';

  @override
  String get auth_loginTip => '使用你的 NovelAI 賬戶登入\n所有資料僅儲存在本地裝置';

  @override
  String get auth_emailRequired => '請輸入郵箱';

  @override
  String get auth_emailInvalid => '請輸入有效的郵箱地址';

  @override
  String get auth_passwordRequired => '請輸入密碼';

  @override
  String get auth_tokenLoginCompact => 'Token登入';

  @override
  String get auth_tokenLoginRecommended => 'API Token 登入（推薦）';

  @override
  String get auth_credentialsLogin => '郵箱密碼登入';

  @override
  String get auth_credentialsLoginUnavailable => '賬號密碼登入當前不可用，請使用 Token 登入';

  @override
  String get auth_tokenHint => '請輸入您的 Persistent API Token';

  @override
  String get auth_tokenRequired => '請輸入 Token';

  @override
  String get auth_tokenInvalid => 'Token 格式無效，應以 pst- 開頭';

  @override
  String get auth_nicknameOptional => '暱稱（可選）';

  @override
  String get auth_nicknameHint => '為此賬號設定一個便於識別的名稱';

  @override
  String get auth_thirdPartyLogin => '第三方站點';

  @override
  String get auth_thirdPartyApiSite => '第三方 API 站點';

  @override
  String get auth_imageApiSiteOptional => '影象 API 站點（可選）';

  @override
  String get auth_imageApiSiteHint => '留空則使用同一個第三方 API 站點';

  @override
  String get auth_thirdPartyNicknameHint => '例如：自建站點 / 映象站點';

  @override
  String get auth_thirdPartyTokenHint => '請輸入第三方站點提供的 API Token';

  @override
  String get auth_thirdPartyCompatibilityHint =>
      '第三方站點需相容 NovelAI 影像生成 API；Token 將按 Bearer 方式傳送。未實作 /user/subscription 的站點將略過訂閱資訊。';

  @override
  String get auth_thirdPartyStreamingHint =>
      '若第三方站點不支援串流生成，請前往「設定 > 生成 > 影象輸出」，關閉「串流預覽」後再生成。';

  @override
  String get anlas_thirdPartyUnavailable => '目前站點不提供 Anlas 餘額資訊';

  @override
  String get auth_thirdPartyApiSiteRequired => '請輸入第三方 API 站點地址';

  @override
  String get auth_validateAndLogin => '驗證並登入';

  @override
  String get auth_tokenGuide => '從 NovelAI 賬戶設定獲取 Token';

  @override
  String get auth_addAccount => '新增賬號';

  @override
  String get auth_tokenNotFound => '未找到此賬號的 Token';

  @override
  String get auth_switchAccount => '切換賬號';

  @override
  String get auth_currentAccount => '當前賬號';

  @override
  String get auth_selectAccount => '選擇賬號';

  @override
  String get auth_deleteAccount => '刪除賬號';

  @override
  String auth_deleteAccountConfirm(Object name) {
    return '確定要刪除賬號 \"$name\" 嗎？此操作不可撤銷。';
  }

  @override
  String get auth_removeAvatar => '移除頭像';

  @override
  String get auth_selectFromGallery => '從相簿選擇';

  @override
  String get auth_quickLogin => '一鍵登入';

  @override
  String get auth_nicknameRequired => '請輸入暱稱';

  @override
  String auth_createdAt(Object date) {
    return '建立於 $date';
  }

  @override
  String get auth_error_networkTimeout => '連線超時，請檢查網路';

  @override
  String get auth_error_networkError => '網路連線錯誤';

  @override
  String get auth_error_authFailed => '認證失敗';

  @override
  String get auth_error_credentialsLoginUnavailable => '賬號密碼登入當前不可用';

  @override
  String get auth_error_credentialsLoginUnavailable_hint =>
      'NovelAI 官網賬號密碼登入需要網頁安全驗證，客戶端無法完成，請改用 Persistent API Token。';

  @override
  String get auth_error_endpointIncompatible =>
      '該地址下未發現 NAI 相容介面，請確認 API 地址是站點提供的服務根地址';

  @override
  String get auth_error_serverError => '伺服器錯誤';

  @override
  String get auth_error_unknown => '未知錯誤';

  @override
  String get auth_autoLogin => '自動登入';

  @override
  String get auth_forgotPassword => '忘記密碼？';

  @override
  String get auth_passwordTooShort => '密碼長度至少6位';

  @override
  String get auth_loggingIn => '登入中...';

  @override
  String get auth_pleaseWait => '請稍候';

  @override
  String get auth_viewTroubleshootingTips => '檢視故障排除提示';

  @override
  String get auth_troubleshoot_checkConnection_title => '檢查網路連線';

  @override
  String get auth_troubleshoot_checkConnection_desc => '確保您的裝置已連線到網際網路';

  @override
  String get auth_troubleshoot_retry_title => '重試';

  @override
  String get auth_troubleshoot_retry_desc => '網路問題可能是暫時的，請重試';

  @override
  String get auth_troubleshoot_proxy_title => '檢查代理設定';

  @override
  String get auth_troubleshoot_proxy_desc => '如果使用代理，請確認配置正確';

  @override
  String get auth_troubleshoot_firewall_title => '檢查防火牆設定';

  @override
  String get auth_troubleshoot_firewall_desc => '確保防火牆允許連線到 NovelAI 伺服器';

  @override
  String get auth_troubleshoot_serverStatus_title => '檢查伺服器狀態';

  @override
  String get auth_troubleshoot_serverStatus_desc =>
      '訪問 NovelAI 狀態頁面或社群檢視服務中斷情況';

  @override
  String get common_paste => '貼上';

  @override
  String get common_default => '預設';

  @override
  String get settings_title => '設定';

  @override
  String get settings_account => '賬戶';

  @override
  String get settings_appearance => '外觀';

  @override
  String get settings_style => '風格';

  @override
  String get settings_font => '字型';

  @override
  String get settings_language => '語言';

  @override
  String get settings_languageChinese => '簡體中文';

  @override
  String get settings_languageTraditionalChinese => '繁體中文';

  @override
  String get settings_languageEnglish => 'English';

  @override
  String get settings_languageJapanese => '日本語';

  @override
  String get settings_shortcuts => '快捷鍵';

  @override
  String get settings_generation => '生成';

  @override
  String get settings_dataStorage => '資料與儲存';

  @override
  String get settings_privacySharing => '安全與分享';

  @override
  String get settings_integrations => '整合';

  @override
  String get settings_accountDetailsSection => '賬戶資訊';

  @override
  String get settings_appearanceInterfaceSection => '介面呈現';

  @override
  String get settings_appearanceWorkflowSection => '生成頁互動';

  @override
  String get settings_storageImagesSection => '圖片';

  @override
  String get settings_storageLibrariesSection => '模型與資源庫';

  @override
  String get settings_storageCacheSection => '快取維護';

  @override
  String get settings_networkProxySection => '代理連線';

  @override
  String get settings_shortcutManagementSection => '快捷鍵管理';

  @override
  String get settings_aboutApplicationSection => '應用資訊';

  @override
  String get settings_aboutUpdatesSection => '更新';

  @override
  String get settings_aboutResourcesSection => '專案資源';

  @override
  String get settings_integrationConnectionSection => '連線與可用性';

  @override
  String get settings_generationInputSection => '輸入';

  @override
  String get settings_generationOutputSection => '影象輸出';

  @override
  String get settings_generationRetrySection => '失敗重試';

  @override
  String get settings_generationFeedbackSection => '完成提醒';

  @override
  String get settings_generationStreamPreview => '串流預覽';

  @override
  String get settings_generationStreamPreviewSubtitle =>
      '生成時顯示中間圖像；關閉後將直接等待最終圖像。';

  @override
  String get settings_alphaModeTitle => '透明影象 Alpha 模式';

  @override
  String get settings_alphaModeStraight => '直通（Straight）';

  @override
  String get settings_alphaModePremultiplied => '預乘（Premultiplied）';

  @override
  String get settings_alphaModeStraightDescription =>
      '保留未乘 Alpha 的 RGB，適合繼續編輯，也是 NovelAI 官網預設值。';

  @override
  String get settings_alphaModePremultipliedDescription =>
      'RGB 已乘 Alpha，適合要求預乘輸入的合成與渲染流程。';

  @override
  String get settings_promptAssistant => '提示詞助手';

  @override
  String get settings_comfyUiDesktopOnly => '僅桌面版可用';

  @override
  String get settings_selectStyle => '選擇風格';

  @override
  String get settings_defaultPreset => '預設';

  @override
  String get settings_selectFont => '選擇字型';

  @override
  String get settings_selectLanguage => '選擇語言';

  @override
  String settings_loadFailed(Object error) {
    return '載入失敗: $error';
  }

  @override
  String get settings_imageSavePath => '圖片儲存位置';

  @override
  String get settings_autoSave => '自動儲存';

  @override
  String get settings_autoSaveSubtitle => '生成後自動儲存圖片';

  @override
  String get settings_about => '關於';

  @override
  String settings_version(Object version) {
    return '版本 $version';
  }

  @override
  String get settings_openSource => '開源專案';

  @override
  String get settings_openSourceSubtitle => '檢視原始碼和文件';

  @override
  String get settings_fileLogging => '記錄應用日誌';

  @override
  String get settings_fileLoggingSubtitle =>
      '預設關閉；僅在排查問題時開啟。開啟後會寫入 Documents/NAI_Launcher/logs，關閉後不再建立或寫入日誌檔案。';

  @override
  String get settings_exportDiagnosticLogs => '匯出診斷日誌';

  @override
  String get settings_exportDiagnosticLogsSubtitle =>
      '匯出最近日誌和基本裝置資訊；會自動隱藏憑證與本機路徑。';

  @override
  String get settings_exportDiagnosticLogsInProgress => '正在匯出診斷日誌';

  @override
  String get settings_exportDiagnosticLogsSuccess => '診斷日誌已匯出';

  @override
  String get settings_exportDiagnosticLogsEmpty => '暫無可匯出的日誌，請先開啟日誌記錄並重現問題';

  @override
  String get settings_exportDiagnosticLogsFailed => '診斷日誌匯出失敗，請重試';

  @override
  String get settings_pathReset => '已重置為預設路徑';

  @override
  String get settings_pathSaved => '儲存路徑已更新';

  @override
  String get settings_selectFolder => '選擇儲存資料夾';

  @override
  String get settings_vibeLibraryPath => 'Vibe庫路徑';

  @override
  String get settings_hiveStoragePath => '資料儲存路徑';

  @override
  String get settings_selectVibeLibraryFolder => '選擇Vibe庫資料夾';

  @override
  String get settings_selectHiveFolder => '選擇資料儲存資料夾';

  @override
  String get settings_pathSavedRestartRequired => '路徑已更新，重啟後生效';

  @override
  String get settings_accountType => '賬號型別';

  @override
  String get settings_thirdPartyApiAccount => '第三方站點 API';

  @override
  String get settings_apiSite => 'API 站點';

  @override
  String get settings_notLoggedIn => '登入後可設定頭像和暱稱';

  @override
  String get settings_goToLogin => '去登入';

  @override
  String get settings_tapToChangeAvatar => '點選更換頭像';

  @override
  String get settings_changeAvatar => '更換頭像';

  @override
  String get settings_removeAvatar => '移除頭像';

  @override
  String get settings_accountEmail => '賬號郵箱';

  @override
  String get settings_emailAccount => '郵箱登入';

  @override
  String get settings_tokenAccount => 'Token 帳號';

  @override
  String get settings_setAsDefault => '設為預設';

  @override
  String get settings_defaultAccount => '預設';

  @override
  String get settings_editNickname => '編輯暱稱';

  @override
  String get settings_nickname => '暱稱';

  @override
  String get settings_nicknameHint => '輸入2-32個字元';

  @override
  String get settings_nicknameEmpty => '請輸入暱稱';

  @override
  String settings_nicknameTooLong(int maxLength) {
    return '暱稱不能超過$maxLength個字元';
  }

  @override
  String get settings_nicknameUpdated => '暱稱已更新';

  @override
  String get settings_avatarUpdated => '頭像已更新';

  @override
  String get settings_avatarRemoved => '頭像已移除';

  @override
  String get settings_setAsDefaultSuccess => '已設為預設賬號';

  @override
  String get generation_title => '生成';

  @override
  String get generation_gestureEditPrompt => '下滑編輯提示詞';

  @override
  String get generation_gestureOpenAgent => '上滑開啟 AI 助手';

  @override
  String generation_promptOverviewCharacters(Object count) {
    return '$count 字';
  }

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
  String get generation_skipCurrentBatch => '跳過當前批次';

  @override
  String get generation_pleaseInputPrompt => '請輸入提示詞';

  @override
  String get generation_emptyPromptHint => '輸入提示詞並點選生成';

  @override
  String get generation_imageWillShowHere => '影象將在這裡顯示';

  @override
  String get generation_generationFailed => '生成失敗';

  @override
  String get generation_streamingUnsupported => '站點不支援串流生成';

  @override
  String get generation_streamingUnsupportedHint =>
      '請前往「設定 > 生成 > 影象輸出」，關閉「串流預覽」後重試。';

  @override
  String generation_progress(Object progress) {
    return '生成中... $progress%';
  }

  @override
  String get generation_params => '引數';

  @override
  String get generation_paramsSettings => '生成引數';

  @override
  String get generation_history => '歷史';

  @override
  String get generation_historyRecord => '歷史記錄';

  @override
  String get agentChat_tab => '聊天';

  @override
  String get nav_agent => '智慧體';

  @override
  String get agentChat_inputHint => '給 AI 助手傳送訊息…';

  @override
  String get agentChat_inputHintWithSlash => '給 AI 助手傳送訊息，輸入 / 引用技能…';

  @override
  String get agentChat_slashMenu => '技能與工作階段指令';

  @override
  String get agentChat_slashSkills => '技能';

  @override
  String get agentChat_slashSession => '工作階段';

  @override
  String get agentChat_addAttachment => '新增附件或引用';

  @override
  String get agentChat_photoLibrary => '相簿';

  @override
  String get agentChat_currentCanvas => '目前畫布';

  @override
  String get agentChat_referenceGallery => '參考圖庫';

  @override
  String get agentChat_resourceLibrary => '資源庫';

  @override
  String get agentChat_generationHistory => '生成歷史';

  @override
  String get agentChat_localGallery => '本機圖庫';

  @override
  String get agentChat_tagLibrary => '標籤詞庫';

  @override
  String get agentChat_vibeLibrary => 'Vibe 庫';

  @override
  String get agentChat_preciseRefLibrary => '精準參考庫';

  @override
  String get agentChat_generatedImage => '生成圖片';

  @override
  String get agentChat_reference => '引用資源';

  @override
  String get agentChat_noResources => '這裡暫時沒有可用資源。';

  @override
  String agentChat_imageTooLarge(String fileName, int maxSizeMB) {
    return '$fileName 超過 $maxSizeMB MB。';
  }

  @override
  String get agentChat_enableWebAccess => '開啟聯網';

  @override
  String get agentChat_disableWebAccess => '關閉聯網';

  @override
  String get agentChat_webAccessLabel => '聯網';

  @override
  String get agentChat_contextUsageLabel => '上下文';

  @override
  String agentChat_unsupportedImageFormat(Object fileName) {
    return '不支援的圖片格式：$fileName';
  }

  @override
  String get agentChat_newChat => '新對話';

  @override
  String get agentChat_searchSessions => '搜尋對話';

  @override
  String get agentChat_send => '傳送';

  @override
  String get agentChat_sendEmptyHint => '輸入訊息或加入圖片後即可傳送';

  @override
  String get agentChat_sendUnavailableHint => 'AI 助手尚未準備好傳送訊息';

  @override
  String get agentChat_stop => '停止';

  @override
  String get agentChat_queued => '已排隊';

  @override
  String get agentChat_queueSteering => '插入目前工作';

  @override
  String get agentChat_queueFollowUp => '目前任務後繼續';

  @override
  String get agentChat_thinking => '思考中…';

  @override
  String get agentChat_toolRunning => '呼叫工具中';

  @override
  String get agentChat_reasoning => '思考過程';

  @override
  String get agentChat_reasoningLevel => '推理強度';

  @override
  String get agentChat_reasoningOff => '關閉';

  @override
  String get agentChat_reasoningMinimal => '最少';

  @override
  String get agentChat_reasoningLow => '低';

  @override
  String get agentChat_reasoningMedium => '中';

  @override
  String get agentChat_reasoningHigh => '高';

  @override
  String get agentChat_reasoningXHigh => '極高';

  @override
  String get agentChat_reasoningMax => '最大';

  @override
  String get agentChat_jumpToLatest => '回到最新';

  @override
  String agentChat_toolGroupCount(int count) {
    return '執行了 $count 項操作';
  }

  @override
  String get agentChat_working => '正在工作';

  @override
  String agentChat_workingFor(String duration) {
    return '已工作 $duration';
  }

  @override
  String get agentChat_worked => '工作完成';

  @override
  String agentChat_workedFor(String duration) {
    return '工作耗時 $duration';
  }

  @override
  String agentChat_workItemCount(int count) {
    return '$count 項';
  }

  @override
  String agentChat_ranCommands(int count) {
    return '執行了 $count 條命令';
  }

  @override
  String agentChat_exploredItems(int count) {
    return '探索了 $count 項資源';
  }

  @override
  String agentChat_earlierMessages(int count) {
    return '更早的 $count 則訊息';
  }

  @override
  String get agentChat_loadEarlierMessages => '更早訊息';

  @override
  String agentChat_turnNavigation(int number, String preview) {
    return '第 $number 輪：$preview';
  }

  @override
  String get agentChat_phasePreparing => '準備中';

  @override
  String get agentChat_phaseResponding => '回覆中';

  @override
  String get agentChat_phaseAwaitingApproval => '等待確認';

  @override
  String get agentChat_phaseStopping => '正在停止';

  @override
  String get agentChat_contextUnavailable => '上下文用量不可用';

  @override
  String get agentChat_toolGenerateImage => '生成圖片';

  @override
  String get agentChat_toolQueueImageTask => '新增圖片任務';

  @override
  String get agentChat_toolInterrogateImage => '反推圖片提示詞';

  @override
  String get agentChat_toolRecentImages => '檢視最近圖片';

  @override
  String get agentChat_toolInspectImages => '檢查圖片';

  @override
  String get agentChat_toolDisplayImages => '展示圖片';

  @override
  String get agentChat_toolResult => '結果';

  @override
  String get agentChat_toolGenerationStatus => '檢視生成狀態';

  @override
  String get agentChat_toolGetGenerationSettings => '檢視生成設定';

  @override
  String get agentChat_toolUpdateGenerationSettings => '更新生成設定';

  @override
  String get agentChat_toolGetGenerationSourceImage => '檢視圖生圖來源圖';

  @override
  String get agentChat_toolSetGenerationSourceImage => '載入圖生圖來源圖';

  @override
  String get agentChat_toolClearGenerationSourceImage => '清除圖生圖來源圖';

  @override
  String get agentChat_toolUpdateGenerationSourceSettings => '調整圖生圖強度';

  @override
  String get agentChat_toolPromptState => '檢視提示詞狀態';

  @override
  String get agentChat_toolSetPositivePrompt => '設定正向提示詞';

  @override
  String get agentChat_toolSetNegativePrompt => '設定負向提示詞';

  @override
  String get agentChat_toolAddCharacter => '新增角色';

  @override
  String get agentChat_toolUpdateCharacter => '更新角色';

  @override
  String get agentChat_toolRemoveCharacter => '刪除角色';

  @override
  String get agentChat_toolReadSkill => '讀取 Skill';

  @override
  String get agentChat_toolReadSkillResource => '讀取 Skill 資源';

  @override
  String get agentChat_toolSkillDiagnostics => '檢視 Skill 診斷';

  @override
  String get agentChat_toolReloadSkills => '重新載入 Skills';

  @override
  String get agentChat_toolSearchTags => '搜尋標籤';

  @override
  String get agentChat_toolReadFile => '讀取檔案';

  @override
  String get agentChat_toolWebSearch => '聯網搜尋';

  @override
  String get agentChat_toolWebRead => '讀取網頁';

  @override
  String get agentChat_toolApplication => '修改應用程式資料';

  @override
  String get agentChat_toolGallery => '使用畫廊';

  @override
  String get agentChat_toolReferenceLibrary => '使用參考圖庫';

  @override
  String get agentChat_toolPrepareGeneration => '準備生成任務';

  @override
  String get agentChat_toolInspectGeneration => '查看生成草稿';

  @override
  String get agentChat_toolUpdateGeneration => '修改生成草稿';

  @override
  String get agentChat_toolCancelGeneration => '取消生成草稿';

  @override
  String get agentChat_toolSubmitGeneration => '提交生成任務';

  @override
  String get agentChat_toolCreateInpaint => '建立手動局部重繪草稿';

  @override
  String get agentChat_toolListInpaint => '查看局部重繪草稿列表';

  @override
  String get agentChat_toolInspectInpaint => '查看局部重繪草稿';

  @override
  String get agentChat_toolCancelInpaint => '取消局部重繪草稿';

  @override
  String get agentChat_toolReeditInpaint => '重新編輯局部重繪草稿';

  @override
  String get agentChat_toolSubmitInpaint => '提交局部重繪任務';

  @override
  String get agentChat_toolCreateInpaintMask => '建立重繪遮罩';

  @override
  String get agentChat_toolExpandInpaintCanvas => '擴展畫布';

  @override
  String get agentChat_toolLoadInpaintPanel => '載入重繪草稿到面板';

  @override
  String get agentChat_manualInpaintTitle => '手動局部重繪';

  @override
  String get agentChat_manualInpaintComplete => '完成並返回智慧體';

  @override
  String get agentChat_resourceUnavailable => '資源不可用';

  @override
  String get agentChat_addResource => '傳送至智慧體';

  @override
  String get agentChat_resourceAdded => '已新增至 Agent 輸入區';

  @override
  String agentChat_addResourceFailed(String error) {
    return '新增引用失敗：$error';
  }

  @override
  String agentChat_approvalEstimatedAnlas(int cost) {
    return '預計消耗：$cost Anlas';
  }

  @override
  String get agentChat_needSetup => '未設定聊天模型。請先在設定中新增支援工具呼叫的供應商。';

  @override
  String get agentChat_heroTitle => '今天想做什麼？';

  @override
  String get agentChat_heroSubtitle => '準備生成角色提示詞、整理靈感或最佳化設定。';

  @override
  String get agentChat_moreActions => '更多操作';

  @override
  String get agentChat_compact => '壓縮上下文';

  @override
  String get agentChat_compacting => '正在壓縮上下文…';

  @override
  String agentChat_compactDone(String before, String after) {
    return '已壓縮上下文：$before → $after';
  }

  @override
  String get agentChat_compactNotNeeded => '目前上下文無需壓縮';

  @override
  String get agentChat_compactBusy => '正在產生回覆，請稍後再壓縮';

  @override
  String get agentChat_compactUnavailable => '上下文用量不可用，無法壓縮';

  @override
  String agentChat_compactFailed(String error) {
    return '壓縮上下文失敗：$error';
  }

  @override
  String get agentChat_requestFailed => '請求失敗，請重試。';

  @override
  String get agentChat_errorDetails => '錯誤詳情';

  @override
  String get agentChat_modelLabel => '模型';

  @override
  String get agentChat_modelPickerTitle => '選擇模型';

  @override
  String get agentChat_searchModels => '搜尋模型';

  @override
  String get agentChat_searchModelsHint => '模型名稱、ID 或提供者';

  @override
  String get agentChat_clearModelSearch => '清除模型搜尋';

  @override
  String get agentChat_noModelResults => '沒有符合搜尋條件的模型。';

  @override
  String get agentChat_noModel => '未配置模型';

  @override
  String get agentChat_untitled => '新會話';

  @override
  String get agentChat_renameHint => '會話名稱';

  @override
  String get agentChat_suggestion1 => '檢查目前生成設定';

  @override
  String get agentChat_suggestion2 => '從畫廊整理提示詞';

  @override
  String get agentChat_suggestion3 => '幫我最佳化角色標籤';

  @override
  String get agentChat_permissionMode => 'Agent 權限';

  @override
  String get agentChat_permissionSafe => '安全模式';

  @override
  String get agentChat_permissionSafeDescription => '僅執行無副作用工具';

  @override
  String get agentChat_permissionAsk => '詢問模式';

  @override
  String get agentChat_permissionAskDescription => '敏感操作執行前詢問';

  @override
  String get agentChat_permissionFull => '完全存取';

  @override
  String get agentChat_permissionFullDescription => '不詢問並允許存取工作區外檔案';

  @override
  String agentChat_approvalTitle(Object toolName) {
    return '允許執行 $toolName？';
  }

  @override
  String get agentChat_approvalDescription => '此工具會讀取本機資料、修改應用程式狀態或產生費用。';

  @override
  String get agentChat_approvalAllow => '允許一次';

  @override
  String get agentChat_approvalDeny => '拒絕';

  @override
  String get generation_failedStreamSnapshot => '失敗快照';

  @override
  String get generation_failedStreamSnapshotHint =>
      '生成未完成，僅保留最後一幀預覽；不可儲存、收藏或用於圖生圖';

  @override
  String get generation_noHistory => '暫無歷史記錄';

  @override
  String get generation_clearHistory => '清除歷史記錄';

  @override
  String get generation_clearHistoryConfirm => '確定要清除所有歷史記錄嗎？此操作不可撤銷。';

  @override
  String get generation_model => '模型';

  @override
  String generation_opusUsageRemaining(Object percent) {
    return 'Opus 免費生成剩餘 $percent%';
  }

  @override
  String generation_opusUsageEstimate(Object count) {
    return '約可再生成 $count 張';
  }

  @override
  String get generation_opusUsageRefill => '額度會隨時間自動恢復';

  @override
  String get generation_opusUsageExhausted =>
      'Opus 免費額度已用完，V5 生成將消耗 Anlas，額度會隨時間自動恢復';

  @override
  String get generation_imageSize => '影象尺寸';

  @override
  String get generation_transparentBackground => '透明背景';

  @override
  String generation_e2eUpscaleHint(Object size) {
    return '服務端輸出 $size';
  }

  @override
  String get generation_sampler => '取樣器';

  @override
  String generation_steps(Object steps) {
    return '步數: $steps';
  }

  @override
  String generation_cfgScale(Object scale) {
    return 'CFG 強度：$scale';
  }

  @override
  String get generation_seed => '種子';

  @override
  String get generation_previewApplySeed => '使用當前圖片的種子';

  @override
  String get generation_imageComparison => '對比';

  @override
  String get generation_imageComparisonHint => '對比生成圖與本次結果的來源圖';

  @override
  String get generation_imageComparisonDivider => '圖像對比分隔線';

  @override
  String get generation_transparencyBackgroundTitle => '透明部分顯示';

  @override
  String get generation_transparencyChecker => '跟隨主題棋盤格';

  @override
  String get generation_transparencyCheckerLight => '淺色棋盤格';

  @override
  String get generation_transparencyCheckerDark => '深色棋盤格';

  @override
  String get generation_transparencyNone => '無';

  @override
  String get generation_transparencyBlack => '黑色';

  @override
  String get generation_transparencyWhite => '白色';

  @override
  String get generation_transparencyGray => '灰色';

  @override
  String get generation_transparencyRed => '紅色';

  @override
  String get generation_transparencyGreen => '綠色';

  @override
  String get generation_transparencyBlue => '藍色';

  @override
  String get generation_transparencyCustom => '自定義顏色';

  @override
  String get generation_seedRandom => '隨機';

  @override
  String get generation_seedLock => '固定種子';

  @override
  String get generation_seedUnlock => '解鎖種子';

  @override
  String get generation_advancedOptions => '高階選項';

  @override
  String get generation_smea => 'SMEA';

  @override
  String get generation_smeaSubtitle => '改善大影象的生成質量';

  @override
  String get generation_smeaDyn => 'SMEA DYN';

  @override
  String get generation_smeaDescription => '高解析度取樣器會在超過一定影象尺寸時自動使用';

  @override
  String generation_cfgRescale(Object value) {
    return 'CFG 重縮放：$value';
  }

  @override
  String get generation_noiseSchedule => '噪聲排程';

  @override
  String get prompt_positive => '正面';

  @override
  String get prompt_negative => '負面';

  @override
  String get prompt_positivePrompt => '正向提示詞';

  @override
  String get prompt_negativePrompt => '負向提示詞';

  @override
  String get prompt_mainPositive => '主提示詞（正面）';

  @override
  String get prompt_mainNegative => '主提示詞（負面）';

  @override
  String get prompt_characterPrompts => '多角色提示詞';

  @override
  String get prompt_finalPrompt => '最終生效提示詞';

  @override
  String get prompt_finalNegative => '最終生效負面詞';

  @override
  String get prompt_composition => '提示詞構成';

  @override
  String get prompt_expandFull => '展開全文';

  @override
  String get prompt_collapseFull => '收起全文';

  @override
  String prompt_importedCharacters(int count) {
    return '已匯入 $count 個角色';
  }

  @override
  String get prompt_characterPromptReplaced => '已替換角色提示詞';

  @override
  String prompt_characterPromptAppended(Object count) {
    return '已追加角色提示詞 ($count 個角色)';
  }

  @override
  String prompt_smartDecomposedWithCharacters(Object count) {
    return '已分解：主提示詞 + $count 個角色';
  }

  @override
  String get prompt_appliedToMainPrompt => '已應用到主提示詞';

  @override
  String get prompt_inputPrompt => '描述你想生成的畫面';

  @override
  String get prompt_describeImage => '描述你想要生成的影象...';

  @override
  String get prompt_describeImageWithHint => '輸入提示詞描述畫面，輸入 < 引用詞庫，支援自動補全標籤';

  @override
  String get prompt_searchHint => '搜尋提示詞';

  @override
  String prompt_searchMatchCount(Object current, Object total) {
    return '$current / $total';
  }

  @override
  String get prompt_searchPrevious => '上一個命中';

  @override
  String get prompt_searchNext => '下一個命中';

  @override
  String get prompt_searchClose => '關閉搜尋';

  @override
  String get prompt_replaceHint => '替換為';

  @override
  String get prompt_replaceToggle => '顯示/隱藏替換';

  @override
  String get prompt_replaceCurrent => '替換當前命中（Enter）';

  @override
  String get prompt_replaceAll => '全部替換（Ctrl+Enter）';

  @override
  String prompt_replaceAllDone(Object count) {
    return '已替換 $count 處';
  }

  @override
  String get promptAssistant_needPrompt => '請輸入提示詞後再操作';

  @override
  String promptAssistant_requestFailed(Object error) {
    return '助手請求失敗: $error';
  }

  @override
  String get promptAssistant_enableAssistant => '啟用提示詞助手';

  @override
  String get promptAssistant_desktopOverlay => '桌面右下角浮層';

  @override
  String get kritaBridge_busyGenerating => 'Krita Bridge 正在生成，請等待當前任務結束';

  @override
  String get prompt_negativeFixedTagPrefix => '負向固定詞字首';

  @override
  String get prompt_negativeFixedTagSuffix => '負向固定詞字尾';

  @override
  String get prompt_unwantedContent => '不想出現在影象中的內容...';

  @override
  String get prompt_smartAutocomplete => '智慧補全';

  @override
  String get prompt_smartAutocompleteSubtitle => '輸入時顯示標籤建議';

  @override
  String get prompt_autoFormat => '自動格式化';

  @override
  String get prompt_autoFormatSubtitle => '中文逗號轉英文、標籤內空格轉下劃線（保留換行）';

  @override
  String get prompt_highlightEmphasis => '高亮強調';

  @override
  String get prompt_highlightEmphasisSubtitle => '括號和權重語法高亮顯示';

  @override
  String get prompt_sdSyntaxAutoConvert => 'SD語法自動轉換';

  @override
  String get prompt_sdSyntaxAutoConvertSubtitle => '失焦時將SD權重語法轉換為NAI格式';

  @override
  String get prompt_resolveAliasOnCopy => '複製時展開詞庫';

  @override
  String get prompt_resolveAliasOnCopySubtitle => '複製或剪下時把 <詞庫名> 替換為詞庫內容';

  @override
  String get prompt_cooccurrenceRecommendation => '共現標籤推薦';

  @override
  String get prompt_cooccurrenceRecommendationSubtitle =>
      '選中標籤後自動推薦，也可按 Ctrl+Shift+Space 或 Ctrl+單擊';

  @override
  String get prompt_regexRulesManage => '正則替換規則…';

  @override
  String prompt_regexRulesCount(int count) {
    return '已配置 $count 條規則';
  }

  @override
  String prompt_regexReplaceApplied(int count) {
    return '正則替換 $count 條';
  }

  @override
  String prompt_regexInvalidRules(Object names) {
    return '已跳過無效的正則規則：$names';
  }

  @override
  String get regexRules_title => '正則替換規則';

  @override
  String get regexRules_hint =>
      '規則按順序作用於整段提示詞，早於 SD 轉換和自動格式化執行。替換內容裡可用 \$1、\$2 引用捕獲組。';

  @override
  String get regexRules_empty => '還沒有規則，點下面的按鈕新建一條';

  @override
  String get regexRules_add => '新建規則';

  @override
  String get regexRules_unnamed => '未命名規則';

  @override
  String get regexRules_invalidBadge => '無效';

  @override
  String get regexRules_deleteConfirmTitle => '刪除規則';

  @override
  String regexRules_deleteConfirmMessage(Object name) {
    return '確定刪除「$name」嗎？此操作不可撤銷。';
  }

  @override
  String get regexRules_newTitle => '新建規則';

  @override
  String get regexRules_editTitle => '編輯規則';

  @override
  String get regexRules_nameLabel => '規則名稱（可選）';

  @override
  String get regexRules_nameHint => '例如：統一發色寫法';

  @override
  String get regexRules_patternLabel => '匹配（正規表示式）';

  @override
  String get regexRules_patternHint => '例如：\\bblue[ _]hair\\b';

  @override
  String get regexRules_replacementLabel => '替換為';

  @override
  String get regexRules_replacementHint => '例如：aqua hair';

  @override
  String get regexRules_caseSensitive => '區分大小寫';

  @override
  String get regexRules_patternRequired => '匹配內容不能為空';

  @override
  String regexRules_patternInvalid(Object error) {
    return '正規表示式無效：$error';
  }

  @override
  String get regexRules_testTitle => '測試';

  @override
  String get regexRules_testInputHint => '貼上一段提示詞看看替換效果';

  @override
  String get regexRules_testNoChange => '無變化';

  @override
  String get regexRules_testNoRules => '沒有啟用中的規則';

  @override
  String get prompt_formatted => '已格式化';

  @override
  String get image_save => '儲存';

  @override
  String get image_copy => '複製';

  @override
  String get image_upscale => '放大';

  @override
  String get image_saveToLibrary => '儲存到詞庫';

  @override
  String image_imageSaved(Object path) {
    return '圖片已儲存到: $path';
  }

  @override
  String image_saveFailed(Object error) {
    return '儲存失敗: $error';
  }

  @override
  String get image_copiedToClipboard => '已複製到剪貼簿';

  @override
  String image_copyFailed(Object error) {
    return '複製失敗: $error';
  }

  @override
  String get config_newPreset => '新建預設';

  @override
  String get config_deletePreset => '刪除預設';

  @override
  String get img2img_title => '圖生圖';

  @override
  String get img2img_enabled => '已啟用';

  @override
  String get img2img_sourceImage => '源影象';

  @override
  String get img2img_strength => '變化強度';

  @override
  String get img2img_strengthHint => '值越高，生成的影象與原圖差異越大';

  @override
  String get img2img_noise => '噪聲量';

  @override
  String get img2img_noiseHint => '新增額外噪聲以增加變化';

  @override
  String get img2img_clearSettings => '清除圖生圖設定';

  @override
  String get img2img_changeImage => '更換圖片';

  @override
  String get img2img_removeImage => '移除圖片';

  @override
  String img2img_selectFailed(Object error) {
    return '選擇圖片失敗: $error';
  }

  @override
  String get img2img_editImage => '編輯影象';

  @override
  String get img2img_editApplied => '已將編輯結果設為新的源圖';

  @override
  String get img2img_uploadImage => '上傳圖片';

  @override
  String get img2img_drawSketch => '繪製草圖';

  @override
  String get img2img_inpaint => '區域性重繪';

  @override
  String get img2img_inpaintStrength => '重繪強度';

  @override
  String get img2img_inpaintStrengthHint => '值越高，蒙版區域與當前源圖差異越大';

  @override
  String get img2img_inpaintPendingHint =>
      '點選“區域性重繪”進入畫布，用畫筆、橡皮或選區工具標出需要重繪的區域。返回這裡後，點選主生成按鈕即可只重繪蒙版區域。';

  @override
  String get img2img_inpaintReadyHint => '遮罩已載入。當前會按區域性重繪方式提交，只有蒙版區域會被重新生成。';

  @override
  String get img2img_inpaintMaskReady => '區域性重繪遮罩已準備好';

  @override
  String get img2img_generateVariations => '生成變體';

  @override
  String get img2img_directorTools => '導演工具';

  @override
  String get img2img_directorToolsHint =>
      '將當前源圖送入導演工具處理。處理完成後，可以把結果回填為新的源圖繼續生成。';

  @override
  String get img2img_directorPrompt => '附加提示詞';

  @override
  String get img2img_directorPromptHint => '需要時補充描述，例如目標情緒或上色方向';

  @override
  String img2img_directorRun(Object tool) {
    return '執行 $tool';
  }

  @override
  String get img2img_directorRunning => '正在處理...';

  @override
  String get img2img_directorConfirmTitle => '確認 Anlas 消耗';

  @override
  String img2img_directorConfirmContent(Object tool, int cost) {
    return '執行$tool預計消耗 $cost Anlas，是否繼續？';
  }

  @override
  String get img2img_directorResult => '處理結果';

  @override
  String img2img_directorResultReady(Object tool) {
    return '$tool 處理完成';
  }

  @override
  String get img2img_directorApplied => '已將導演工具結果設為新的源圖';

  @override
  String get img2img_directorDefry => 'Defry';

  @override
  String get img2img_directorDefryHint => '降低結果中的噪聲或過飽和程度（0 = 關閉，5 = 最強）';

  @override
  String get img2img_directorEmotionLevel => '表情強度';

  @override
  String get img2img_directorEmotionLevelHint => 'AI 改變表情的力度（0 = 輕微，5 = 強烈）';

  @override
  String get img2img_directorEmotionPresets => '快速預設';

  @override
  String get img2img_directorApplyAsSource => '設為源圖';

  @override
  String get img2img_directorSourceImage => '源圖';

  @override
  String get img2img_variationsStarted => '正在生成變體...';

  @override
  String get img2img_directorRemoveBackground => '背景移除';

  @override
  String get img2img_directorLineArt => '線稿提取';

  @override
  String get img2img_directorSketch => '草圖化';

  @override
  String get img2img_directorColorize => '上色';

  @override
  String get img2img_directorEmotion => '表情修復';

  @override
  String get img2img_directorDeclutter => '雜線清理';

  @override
  String get img2img_enhance => '增強';

  @override
  String get img2img_enhanceHint => '增強會繼續參考當前提示詞，對源圖進行潛空間放大與再生成。';

  @override
  String get img2img_enhanceMagnitude => '幅度';

  @override
  String get img2img_enhanceShowIndividualSettings => '顯示單獨設定';

  @override
  String get img2img_enhanceUpscaleAmount => '放大倍數';

  @override
  String get img2img_enhanceScaleMax => '最大';

  @override
  String get img2img_focusedInpaint => 'Focused Inpainting（聚焦重繪）';

  @override
  String get img2img_focusedInpaintEnabledHint =>
      '已啟用。請在重繪編輯器左上角按鈕裡調整聚焦區域與 Minimum Context Area。';

  @override
  String get img2img_focusedInpaintDisabledHint =>
      '預設是普通重繪；如需聚焦重繪，請在重繪編輯器左上角按鈕中開啟並框選區域。';

  @override
  String get img2img_disabled => '未啟用';

  @override
  String get img2img_novelAiCloudUpscale => 'NovelAI 雲端超分 (固定 2x 放大)';

  @override
  String get img2img_comfyuiEnableHint => '請先在「設定 > ComfyUI」中啟用並連線伺服器。';

  @override
  String get img2img_upscaleMode => '放大方式';

  @override
  String get img2img_upscaleRegularModel => '普通模型';

  @override
  String get img2img_upscaleModel => '超分模型';

  @override
  String get img2img_noSeedvr2Models =>
      '未發現可用的 SeedVR2 模型，請重新整理模型列表，並檢查 ComfyUI 原生 models/diffusion_models、models/vae 或 SeedVR2 自定義節點模型目錄。';

  @override
  String get img2img_noRegularUpscaleModels =>
      '未發現普通超分模型，請重新整理模型列表或檢查 models/upscale_models。';

  @override
  String get img2img_useNativeSeedvr2Workflow =>
      '將使用 ComfyUI 原生 SeedVR2 一步超分流程。';

  @override
  String get img2img_useSeedvr2TiledWorkflow =>
      '將使用 SeedVR2TilingUpscaler 分塊超分流程。';

  @override
  String get img2img_useSeedvr2Workflow => '將使用 SeedVR2VideoUpscaler 流程。';

  @override
  String get img2img_useRegularUpscaleWorkflow =>
      '將使用 UpscaleModelLoader + ImageUpscaleWithModel 流程，並用 Lanczos 修正到目標倍率。';

  @override
  String get img2img_useRtxUpscaleWorkflow =>
      '將使用 RTX Video Super Resolution 流程，無需選擇模型。';

  @override
  String get img2img_refreshModelList => '重新整理模型列表';

  @override
  String get img2img_startUpscale => '開始超分';

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
  String get img2img_noAvailableSeedvr2Model => '未選擇可用的 SeedVR2 模型';

  @override
  String get img2img_noAvailableRegularUpscaleModel => '未選擇可用的普通超分模型';

  @override
  String get img2img_decodeSourceFailed => '無法解碼源影象';

  @override
  String get img2img_metricSpeed => '速度';

  @override
  String get img2img_metricVram => '視訊記憶體';

  @override
  String get img2img_metricQuality => '效果';

  @override
  String get img2img_seedvr2Engine => 'SeedVR2 引擎';

  @override
  String get img2img_seedvr2EngineAuto => '自動';

  @override
  String get img2img_seedvr2EngineNative => '原生';

  @override
  String get img2img_seedvr2EngineLegacy => '相容節點';

  @override
  String get img2img_seedvr2EngineResolvedNative => '當前使用 ComfyUI 原生 SeedVR2。';

  @override
  String get img2img_seedvr2EngineResolvedLegacy => '當前使用已安裝的 SeedVR2 自定義節點。';

  @override
  String get img2img_seedvr2EngineUnavailable =>
      '當前選擇的 SeedVR2 引擎或所需模型不可用，請重新整理模型列表或切換引擎。';

  @override
  String get img2img_seedvr2VaeTileHint => '設定 SeedVR2 VAE 編碼與解碼的分塊尺寸。';

  @override
  String get img2img_seedvr2UseTiledUpscale => '使用分塊放大';

  @override
  String get img2img_seedvr2UseTiledUpscaleHint =>
      '啟用後改用 SeedVR2TilingUpscaler，適合大圖或視訊記憶體壓力較高的場景。';

  @override
  String get settings_comfyUiSeedvr2EmbedNaiMetadata =>
      '在 SeedVR2 結果中寫入 NAI 生成引數';

  @override
  String get settings_comfyUiSeedvr2EmbedNaiMetadataHint =>
      '預設關閉。開啟後會寫入啟動器當前的提示詞和生成引數；關閉時保留 ComfyUI 返回的原始 PNG 後設資料。';

  @override
  String get img2img_seedvr2TileSize => '分塊圖塊大小';

  @override
  String get img2img_seedvr2TileSizeHint =>
      '同時控制 SeedVR2TilingUpscaler 的 tile_width / tile_height。';

  @override
  String get img2img_seedvr2BlocksToSwap => '記憶體解除安裝層數';

  @override
  String get img2img_seedvr2BlocksToSwapHint =>
      '把多少 DiT 層放在記憶體裡、推理時再逐層送入視訊記憶體。調高更省視訊記憶體但更吃記憶體也更慢；視訊記憶體充裕可調低甚至設為 0。視訊記憶體不足報錯時請調高。';

  @override
  String get img2img_upscalePanelOpened => '已開啟圖生圖超分面板';

  @override
  String get editor_done => '完成';

  @override
  String get editor_tolerance => '容差';

  @override
  String get editor_intensity => '強度';

  @override
  String get editor_sourcePoint => 'Alt+點選設定源點';

  @override
  String get editor_brushPresets => '筆刷預設';

  @override
  String get editor_size => '大小';

  @override
  String get editor_opacity => '不透明度';

  @override
  String get editor_hardness => '硬度';

  @override
  String get editor_undo => '撤銷';

  @override
  String get editor_redo => '重做';

  @override
  String get editor_clearLayer => '清除圖層';

  @override
  String get editor_clearSelection => '清除選區';

  @override
  String get editor_resetView => '重置檢視';

  @override
  String get editor_zoom => '縮放';

  @override
  String get editor_toolBrush => '畫筆';

  @override
  String get editor_toolEraser => '橡皮擦';

  @override
  String get editor_toolFill => '填充';

  @override
  String get editor_toolMagicWand => '魔棒';

  @override
  String get editor_magicWandMode => '選擇方式';

  @override
  String get editor_magicWandSmartObject => '智慧物件（EfficientViT）';

  @override
  String get editor_magicWandColorArea => '顏色區域（洪水填充）';

  @override
  String get editor_magicWandSmartHelp =>
      '點選要選擇的物件。首次使用會從 MIT Han Lab 下載約 133 MiB 的 EfficientViT-SAM L0 模型（Apache-2.0），之後儲存在本地。';

  @override
  String get editor_magicWandColorHelp => '點選顏色相近的連續區域。適合邊界清晰的純色影象，無需下載模型。';

  @override
  String get editor_magicWandInvert => '反選結果';

  @override
  String get editor_toolLine => '直線';

  @override
  String get editor_toolRectSelect => '矩形選框';

  @override
  String get editor_toolEllipseSelect => '橢圓選框';

  @override
  String get editor_toolLassoSelect => '套索選區';

  @override
  String get editor_toolColorPicker => '吸管取色';

  @override
  String get editor_toolCloneStamp => '仿製圖章';

  @override
  String get editor_toolBlur => '模糊';

  @override
  String get editor_shortcutUndo => '撤銷 (Ctrl+Z)';

  @override
  String get editor_shortcutRedo => '重做 (Ctrl+Y)';

  @override
  String get editor_back => '返回';

  @override
  String get editor_layers => '圖層';

  @override
  String get editor_loadMask => '載入蒙版';

  @override
  String get editor_togglePanels => '切換面板';

  @override
  String get editor_fillClosedRegion => '填充封閉區域';

  @override
  String get editor_resetMask => '重置蒙版';

  @override
  String get editor_zoomIn => '放大';

  @override
  String get editor_zoomOut => '縮小';

  @override
  String get editor_fitToWindow => '適應視窗';

  @override
  String get editor_tempColorPickerShortcut => 'Alt+點選: 臨時取色';

  @override
  String get editor_shortcutHelpTitle => '快捷鍵幫助';

  @override
  String get editor_shortcutPaintTools => '繪畫工具';

  @override
  String get editor_shortcutSelectionTools => '選區工具';

  @override
  String get editor_shortcutCanvasView => '畫布檢視';

  @override
  String get editor_shortcutBrushAdjust => '筆刷調整';

  @override
  String get editor_shortcutColors => '顏色';

  @override
  String get editor_shortcutCanvasActions => '畫布操作';

  @override
  String get editor_shortcutHistoryActions => '歷史操作';

  @override
  String get editor_shortcutSelectionActions => '選區操作';

  @override
  String get editor_shortcutTemporaryColorPicker => '臨時拾色器';

  @override
  String get editor_shortcutRectSelection => '矩形選區';

  @override
  String get editor_shortcutEllipseSelection => '橢圓選區';

  @override
  String get editor_shortcutLassoSelection => '套索選區';

  @override
  String get editor_shortcut100Zoom => '100% 縮放';

  @override
  String get editor_shortcutFitHeight => '適應高度';

  @override
  String get editor_shortcutFitWidth => '適應寬度';

  @override
  String get editor_shortcutRotateLeft15 => '向左旋轉 15°';

  @override
  String get editor_shortcutResetRotation => '重置旋轉';

  @override
  String get editor_shortcutRotateRight15 => '向右旋轉 15°';

  @override
  String get editor_shortcutFlipHorizontal => '水平映象';

  @override
  String get editor_shortcutWheel => '滾輪';

  @override
  String get editor_shortcutBrushSmaller => '減小筆刷';

  @override
  String get editor_shortcutBrushLarger => '增大筆刷';

  @override
  String get editor_shortcutOpacityLower => '降低透明度';

  @override
  String get editor_shortcutOpacityHigher => '提高透明度';

  @override
  String get editor_shortcutDragBrushSize => '調整筆刷大小';

  @override
  String get editor_shortcutSwapColors => '交換前景/背景色';

  @override
  String get editor_shortcutPanCanvas => '平移畫布';

  @override
  String get editor_shortcutClearSelectionContent => '清除選區內容';

  @override
  String get editor_shortcutCancelCurrentAction => '取消當前操作';

  @override
  String get editor_selectUnlockedLayerWithContent => '請選擇一個非鎖定且有內容的圖層';

  @override
  String get editor_readCurrentLayerFailed => '無法讀取當前圖層';

  @override
  String get editor_localEffects => '本地後處理 / Effects';

  @override
  String get editor_basicAdjustments => '基礎調整';

  @override
  String get editor_styleAndRepair => '風格與修復';

  @override
  String get editor_transformCrop => '旋轉 / 翻轉 / 裁剪';

  @override
  String get editor_transformCropDescription =>
      '幾何操作已經獨立出來，點選後會先生成預覽，確認應用後才寫回圖層。';

  @override
  String get editor_effectPreviewHint => '預覽不會修改原圖；點選應用後才會把結果寫入當前活動圖層和撤銷歷史。';

  @override
  String get editor_applyToCurrentLayer => '應用到當前圖層';

  @override
  String editor_oneShotEffectHint(Object effect) {
    return '$effect 是一次性操作，沒有強度滑條。';
  }

  @override
  String editor_effectIntensity(Object effect) {
    return '$effect 強度';
  }

  @override
  String get editor_original => '原圖';

  @override
  String get editor_effectPreview => '效果預覽';

  @override
  String get editor_effectBrightness => '亮度';

  @override
  String get editor_effectContrast => '對比度';

  @override
  String get editor_effectSaturation => '飽和度';

  @override
  String get editor_effectTemperature => '色溫';

  @override
  String get editor_effectGamma => '伽馬';

  @override
  String get editor_effectGrayscale => '灰度';

  @override
  String get editor_effectInvert => '反相';

  @override
  String get editor_effectSepia => '復古棕褐';

  @override
  String get editor_effectDenoise => '降噪';

  @override
  String get editor_effectBlur => '高斯模糊';

  @override
  String get editor_effectSharpen => '銳化';

  @override
  String get editor_effectCropToSelection => '裁剪到選區';

  @override
  String get editor_effectRotateLeft => '向左旋轉 90°';

  @override
  String get editor_effectRotateRight => '向右旋轉 90°';

  @override
  String get editor_effectFlipHorizontal => '水平翻轉';

  @override
  String get editor_effectFlipVertical => '垂直翻轉';

  @override
  String editor_effectApplied(Object effect) {
    return '已應用 $effect';
  }

  @override
  String editor_applyEffectFailed(Object error) {
    return '應用效果失敗: $error';
  }

  @override
  String get editor_changeCanvasSize => '更改畫布尺寸';

  @override
  String editor_canvasTooSmall(Object width, Object height) {
    return '畫布尺寸太小，最小尺寸為 $width x $height 畫素';
  }

  @override
  String editor_canvasTooLarge(Object width, Object height) {
    return '畫布尺寸太大，最大尺寸為 $width x $height 畫素';
  }

  @override
  String editor_canvasResized(Object width, Object height) {
    return '畫布已調整為 $width x $height';
  }

  @override
  String editor_canvasResizeFailed(Object error) {
    return '調整畫布尺寸失敗: $error';
  }

  @override
  String get editor_confirmExitTitle => '確認退出';

  @override
  String get editor_confirmExitContent => '有未儲存的修改，確定要退出嗎？';

  @override
  String get editor_exit => '退出';

  @override
  String get editor_saveAndExit => '儲存並退出';

  @override
  String editor_exportFailed(Object error) {
    return '匯出失敗: $error';
  }

  @override
  String get editor_clickInsideClosedRegion => '請點選封閉區域內部進行填充。';

  @override
  String get editor_drawClosedMaskOutlineFirst => '請先繪製封閉的蒙版輪廓。';

  @override
  String get editor_noClosedRegionAtPosition => '該位置沒有可填充的封閉區域。';

  @override
  String get editor_generateMaskOverlayFailed => '無法生成蒙版覆蓋層';

  @override
  String get editor_maskLayerName => '蒙版';

  @override
  String get editor_updateMaskLayerFailed => '無法更新蒙版圖層';

  @override
  String get editor_closedRegionFilled => '封閉區域已填充為蒙版。';

  @override
  String editor_fillMaskFailed(Object error) {
    return '填充蒙版失敗: $error';
  }

  @override
  String get editor_magicWandNoSource => '沒有可供魔棒取樣的影象圖層。';

  @override
  String get editor_magicWandNothingChanged => '選中的區域已經透明或已在蒙版中。';

  @override
  String get editor_magicWandModelPreparing => '正在檢查 EfficientViT-SAM 模型…';

  @override
  String editor_magicWandModelDownloading(int percent) {
    return '正在下載 EfficientViT-SAM 模型：$percent%';
  }

  @override
  String get editor_magicWandModelLoading => '正在載入 EfficientViT-SAM 模型…';

  @override
  String get editor_magicWandEncoding => '正在分析影象物件…';

  @override
  String get editor_magicWandSegmenting => '正在根據點選位置分割物件…';

  @override
  String get editor_magicWandPostprocessing => '正在生成選區…';

  @override
  String editor_magicWandFailed(Object error) {
    return '魔棒處理失敗: $error';
  }

  @override
  String get editor_focusInactiveHint => '點選按鈕後進入聚焦模式，再框選區域並繪製蒙版。';

  @override
  String get editor_focusReadyHint => '已選定聚焦區域，可繼續用畫筆編輯蒙版。';

  @override
  String get editor_focusNeedsSelectionHint => '先框選聚焦區域，再切換畫筆繪製蒙版。';

  @override
  String get editor_focusSelection => '選區';

  @override
  String get editor_focusBrush => '畫筆';

  @override
  String get editor_focusContextHint =>
      '外框是實際送去 Focused Inpaint 的區域，內框是主要重繪區域；兩框之間的頻寬就是 Minimum Context Area。';

  @override
  String get editor_compressionTitle => '輸出解析度';

  @override
  String get editor_compressionTooltip => '選擇輸出解析度';

  @override
  String get editor_compressionUncompressed => '保持編輯工作尺寸，不執行壓縮。';

  @override
  String get editor_compressionApplyOnDone =>
      '工作畫布保持原樣；點選“完成”時使用 Pica Lanczos3 執行一次壓縮。';

  @override
  String editor_compressionSizeSummary(
    int workWidth,
    int workHeight,
    int targetWidth,
    int targetHeight,
  ) {
    return '工作尺寸 $workWidth×$workHeight → 輸出尺寸 $targetWidth×$targetHeight';
  }

  @override
  String editor_compressionNormalSummary(
    int normalWidth,
    int normalHeight,
    int minimumWidth,
    int minimumHeight,
  ) {
    return 'Normal（約 1MP）為 $normalWidth×$normalHeight；最低檔為 $minimumWidth×$minimumHeight。';
  }

  @override
  String get editor_compressionUnavailable => '當前工作畫布已經低於最低壓縮檔，不能繼續降低解析度。';

  @override
  String get editor_compressionFocusLimited =>
      '當前 Focused Inpaint 選區在更高解析度下會超過請求面積上限，因此滑條上限已收緊。';

  @override
  String editor_focusRequestSummary(
    int outerWidth,
    int outerHeight,
    int requestWidth,
    int requestHeight,
    int cost,
  ) {
    return '外層裁剪 $outerWidth×$outerHeight，實際傳送 $requestWidth×$requestHeight，預計 $cost Anlas。';
  }

  @override
  String editor_unsupportedImageFormat(Object extension) {
    return '不支援的檔案格式: .$extension\n請選擇影象檔案（PNG、JPG、WEBP 等）';
  }

  @override
  String editor_readFileFailed(Object error) {
    return '無法讀取檔案: $error';
  }

  @override
  String get editor_noFileData => '無法獲取檔案資料';

  @override
  String get editor_emptyImageFile => '檔案為空，請選擇有效的影象檔案';

  @override
  String editor_fileTooLarge(Object sizeMB) {
    return '檔案過大（$sizeMB MB），請選擇小於 50MB 的影象';
  }

  @override
  String get editor_maskLayerAdded => '蒙版圖層已新增';

  @override
  String get editor_parseImageFailed => '無法解析影象檔案\n請確保檔案未損壞且格式受支援';

  @override
  String editor_loadMaskFailed(Object error) {
    return '載入蒙版時發生錯誤: $error';
  }

  @override
  String get editor_defaultTitle => '畫板';

  @override
  String get editor_baseLayerName => '底圖';

  @override
  String get editor_existingMaskLayerName => '已有蒙版';

  @override
  String get editor_defaultDrawingLayerName => '圖層 1';

  @override
  String editor_layerName(Object count) {
    return '圖層 $count';
  }

  @override
  String editor_statusZoom(Object value) {
    return '縮放: $value%';
  }

  @override
  String editor_statusCanvas(Object width, Object height) {
    return '畫布: $width x $height';
  }

  @override
  String editor_statusLayers(Object count) {
    return '圖層: $count';
  }

  @override
  String get editor_statusHasSelection => '有選區';

  @override
  String editor_statusRotation(Object degrees) {
    return '旋轉: $degrees°';
  }

  @override
  String get editor_statusMirrored => '映象';

  @override
  String editor_focusMinimumContextArea(Object value) {
    return '最小上下文區域：$value';
  }

  @override
  String get editor_canvasSizeTitle => '畫布尺寸';

  @override
  String get editor_presetSize => '預設尺寸';

  @override
  String get editor_customSize => '自定義';

  @override
  String get editor_contentHandling => '內容處理';

  @override
  String get editor_contentCrop => '裁剪';

  @override
  String get editor_contentPad => '填充';

  @override
  String get editor_contentStretch => '拉伸';

  @override
  String get editor_width => '寬度';

  @override
  String get editor_height => '高度';

  @override
  String get editor_lockAspectRatio => '鎖定比例';

  @override
  String get editor_unlockAspectRatio => '取消鎖定比例';

  @override
  String get editor_sizePreview => '尺寸預覽';

  @override
  String get editor_originalSize => '原始';

  @override
  String get editor_newSize => '新尺寸';

  @override
  String get editor_cropModeDescription => '裁剪模式 - 保持比例裁剪';

  @override
  String get editor_padModeDescription => '填充模式 - 保持比例填充';

  @override
  String get editor_stretchModeDescription => '拉伸模式 - 拉伸至填滿';

  @override
  String editor_canvasPresetSquare(Object size) {
    return '方形 $size';
  }

  @override
  String editor_canvasPresetLandscape(Object ratio) {
    return '橫向 $ratio';
  }

  @override
  String editor_canvasPresetPortrait(Object ratio) {
    return '縱向 $ratio';
  }

  @override
  String get editor_canvasPresetNaiPortrait => 'NAI 縱向';

  @override
  String get editor_canvasPresetNaiLandscape => 'NAI 橫向';

  @override
  String get editor_canvasPresetFullHd => '全高畫質 16:9';

  @override
  String get editor_colorPanelTitle => '顏色';

  @override
  String get editor_colorPickerTitle => '選擇顏色';

  @override
  String get editor_brushSettings => '畫筆設定';

  @override
  String get editor_eraserSettings => '橡皮擦設定';

  @override
  String get editor_colorPickerHint => '點選畫布任意位置取色，鬆開後自動切回上一工具';

  @override
  String get editor_sample => '取樣';

  @override
  String get editor_samplePoint => '單點';

  @override
  String get editor_sampleArea => '區域';

  @override
  String get editor_source => '來源';

  @override
  String get editor_sourceCurrentLayer => '當前圖層';

  @override
  String get editor_sourceAllLayers => '所有圖層';

  @override
  String get editor_lassoSelectionHelp => '按住滑鼠拖動繪製自由形狀選區，鬆開自動閉合';

  @override
  String get layer_empty => '無圖層';

  @override
  String get layer_add => '新增圖層';

  @override
  String get layer_mergeDown => '向下合併';

  @override
  String get layer_duplicate => '複製圖層';

  @override
  String get layer_delete => '刪除圖層';

  @override
  String get layer_merge => '合併圖層';

  @override
  String get layer_visibility => '顯示/隱藏';

  @override
  String get layer_lock => '鎖定';

  @override
  String get layer_rename => '重新命名';

  @override
  String get layer_moveUp => '上移';

  @override
  String get layer_moveDown => '下移';

  @override
  String get vibe_title => '風格遷移';

  @override
  String get vibe_description => '改變影象，保留視覺風格';

  @override
  String get vibe_addFromFileTitle => '從檔案新增';

  @override
  String get vibe_addFromFileSubtitle => 'PNG、JPG、Vibe 檔案';

  @override
  String get vibe_addFromLibraryTitle => '從庫匯入';

  @override
  String get vibe_addFromLibrarySubtitle => '從 Vibe 庫中選擇';

  @override
  String get vibe_addReference => '新增參考圖';

  @override
  String get vibe_clearAll => '清除全部';

  @override
  String vibe_cleared(int count) {
    return '已清除 $count 個 vibes';
  }

  @override
  String get vibe_referenceStrength => '參考強度';

  @override
  String get vibe_infoExtraction => '資訊提取';

  @override
  String get vibe_remove => '移除';

  @override
  String get reference_enabled => '啟用';

  @override
  String get reference_enable => '啟用參考';

  @override
  String get reference_disable => '禁用參考';

  @override
  String get vibe_normalize => '標準化參考強度值';

  @override
  String get vibe_sourceType_png => 'PNG';

  @override
  String get vibe_sourceType_v4vibe => 'Vibe 檔案';

  @override
  String get vibe_sourceType_bundle => '組合包';

  @override
  String get vibe_sourceType_image => '圖片';

  @override
  String get vibe_sourceType => '資料來源';

  @override
  String get vibe_reuseButton => '一鍵複用';

  @override
  String get vibe_info => 'Vibe 資訊';

  @override
  String get vibe_name => '名稱';

  @override
  String get vibe_strength => '強度';

  @override
  String get vibe_infoExtracted => '資訊提取';

  @override
  String get vibe_shiftReplaceHint => 'Shift+點選 替換';

  @override
  String get character_buttonLabel => '角色';

  @override
  String get character_addCharacter => '新增角色';

  @override
  String character_limitReached(Object limit) {
    return '已達當前模型的角色上限（$limit 個）';
  }

  @override
  String character_number(Object index) {
    return '角色 $index';
  }

  @override
  String get character_summaryEmpty => '未新增角色';

  @override
  String character_summaryEnabled(int count, String name) {
    return '已啟用 $count 個 · $name';
  }

  @override
  String character_summaryMore(int count, String name, int additional) {
    return '已啟用 $count 個 · $name +$additional';
  }

  @override
  String character_summaryAllDisabled(int count) {
    return '已啟用 0 個 · 已停用 $count 個';
  }

  @override
  String get gallery_generationParams => '生成引數';

  @override
  String get gallery_metaModel => '模型';

  @override
  String get gallery_metaResolution => '解析度';

  @override
  String get gallery_metaSteps => '步數';

  @override
  String get gallery_metaSampler => '取樣器';

  @override
  String get gallery_metaCfgScale => 'CFG 強度';

  @override
  String get gallery_metaSeed => '種子';

  @override
  String get gallery_metaSmea => 'SMEA';

  @override
  String get gallery_promptCopied => '已複製提示詞';

  @override
  String get gallery_seedCopied => '已複製 Seed';

  @override
  String get gallery_sendToKritaAction => '傳送到 Krita';

  @override
  String get gallery_upscalePanelLoaded => '已載入圖生圖超分面板';

  @override
  String gallery_readImageFailed(Object error) {
    return '讀取影象失敗: $error';
  }

  @override
  String get gallery_fileMissing => '檔案不存在';

  @override
  String get gallery_copiedToClipboard => '已複製到剪貼簿';

  @override
  String gallery_copyFailed(Object error) {
    return '複製失敗: $error';
  }

  @override
  String get gallery_upscale => '放大';

  @override
  String get gallery_sentToImg2Img => '圖片已傳送到圖生圖';

  @override
  String get gallery_sentToReversePrompt => '圖片已傳送到反推模組';

  @override
  String gallery_sendFailed(Object error) {
    return '傳送失敗: $error';
  }

  @override
  String get preset_presetName => '預設名稱';

  @override
  String get onlineGallery_search => '搜尋';

  @override
  String get onlineGallery_popular => '熱門';

  @override
  String get onlineGallery_sourceDoesNotSupportPopular => '目前站點不支援熱門榜單';

  @override
  String get onlineGallery_favorites => '收藏';

  @override
  String get onlineGallery_searchFavorites => '搜尋收藏的標題、作者或標籤…';

  @override
  String get onlineGallery_savedLocally => '已儲存在本機';

  @override
  String get onlineGallery_savedInCloud => '已儲存在雲端';

  @override
  String get onlineGallery_saveVisibleLocally => '將本頁儲存至本機';

  @override
  String get onlineGallery_visibleFavoritesAlreadySaved => '本頁內容已全部儲存至本機收藏';

  @override
  String get onlineGallery_localFavoritesPartialFailure => '本機收藏載入失敗，已保留雲端結果';

  @override
  String get onlineGallery_cloudFavoritesPartialFailure => '雲端收藏載入失敗，已保留本機結果';

  @override
  String onlineGallery_visibleFavoritesSaved(int count) {
    return '已將 $count 個項目儲存至本機收藏';
  }

  @override
  String onlineGallery_saveFavoritesFailed(String error) {
    return '儲存本機收藏失敗：$error';
  }

  @override
  String get onlineGallery_searchTags => '搜尋標籤...';

  @override
  String onlineGallery_maxTagsExceeded(int max) {
    return '最多可組合搜尋 $max 個標籤';
  }

  @override
  String get onlineGallery_tagDetailsIncomplete =>
      '部分作品的完整標籤取得失敗，未驗證的作品已排除；請重試以補齊結果。';

  @override
  String get onlineGallery_unsupportedMetatag =>
      '目前來源或模式不支援元標籤語法，請改用一般標籤或切換至來源搜尋。';

  @override
  String onlineGallery_multiTagScanning(int requests, int candidates) {
    return '正在組合搜尋：已請求 $requests 頁，檢查 $candidates 個候選作品';
  }

  @override
  String get onlineGallery_scanPaused => '已分批檢查多頁候選，尚未找到足夠結果。可繼續掃描後續頁面。';

  @override
  String get onlineGallery_continueScanning => '繼續掃描';

  @override
  String get onlineGallery_refresh => '重新整理';

  @override
  String get onlineGallery_random => '隨機';

  @override
  String get onlineGallery_randomRedraw => '再抽一組';

  @override
  String get onlineGallery_randomDrawing => '抽取中…';

  @override
  String get onlineGallery_randomExhausted => '當前範圍暫無更多未見圖片';

  @override
  String get onlineGallery_randomDrawNoMatch => '本次未抽中符合條件的圖片，可以繼續抽取。';

  @override
  String get onlineGallery_randomRestart => '重新開始';

  @override
  String get onlineGallery_login => '登入';

  @override
  String get onlineGallery_logout => '退出登入';

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
    return '$count 張';
  }

  @override
  String get onlineGallery_loadFailed => '載入失敗';

  @override
  String get onlineGallery_favoritesEmpty => '收藏夾為空';

  @override
  String get onlineGallery_noResults => '沒有找到圖片';

  @override
  String get onlineGallery_pleaseLogin => '請先登入';

  @override
  String get onlineGallery_score => '評分';

  @override
  String get onlineGallery_ratingLabel => '分級';

  @override
  String get onlineGallery_favCount => '收藏';

  @override
  String get mediaType_video => '影片';

  @override
  String get mediaType_gif => '動圖';

  @override
  String get onlineGallery_tags => '標籤';

  @override
  String get onlineGallery_artists => '藝術家';

  @override
  String get onlineGallery_characters => '角色';

  @override
  String get onlineGallery_copyrights => '作品';

  @override
  String get onlineGallery_general => '通用';

  @override
  String get onlineGallery_copied => '已複製';

  @override
  String get onlineGallery_copyTags => '複製標籤';

  @override
  String get onlineGallery_promptTagCategories => '提示詞類別';

  @override
  String get onlineGallery_promptTagCategoriesTooltip => '選擇傳送或加入佇列時包含的標籤類別';

  @override
  String get onlineGallery_keepOnePromptTagCategory => '至少保留一個提示詞類別';

  @override
  String get onlineGallery_addToQueue => '加入佇列';

  @override
  String get onlineGallery_sendToTextToImage => '傳送到文生圖';

  @override
  String get onlineGallery_sentToTextToImage => '已傳送到文生圖';

  @override
  String get onlineGallery_replaceConfig => '取代設定';

  @override
  String get onlineGallery_replaceConfigDescription =>
      '選擇要同時取代的生成設定；未選擇的項目會保留目前值';

  @override
  String get onlineGallery_replaceConfigNaiOnly => '僅包含可識別 NovelAI 設定的圖片支援此選項';

  @override
  String get onlineGallery_sendToReversePrompt => '傳送到反推';

  @override
  String get onlineGallery_sentToReversePrompt => '已傳送到反推模組';

  @override
  String onlineGallery_reversePromptSendFailed(Object error) {
    return '傳送反推失敗: $error';
  }

  @override
  String get onlineGallery_noTagInfo => '此圖片沒有標籤資訊';

  @override
  String get onlineGallery_noImageUrl => '此圖片沒有可用地址';

  @override
  String get onlineGallery_pinchToZoom => '雙指縮放';

  @override
  String get onlineGallery_metadata => '後設資料';

  @override
  String onlineGallery_addedToQueueWithCount(Object count) {
    return '已加入佇列，目前共有 $count 個待執行任務';
  }

  @override
  String get onlineGallery_queueFullMax => '佇列已滿（最多50項）';

  @override
  String get onlineGallery_chooseDownloadDirectory => '選擇下載目錄';

  @override
  String get onlineGallery_downloadStarted => '開始下載...';

  @override
  String onlineGallery_downloadFailed(Object error) {
    return '下載失敗: $error';
  }

  @override
  String get onlineGallery_downloadOriginal => '下載原圖';

  @override
  String get onlineGallery_all => '全部';

  @override
  String get onlineGallery_ratingGeneral => '全年齡';

  @override
  String get onlineGallery_ratingSensitive => '敏感';

  @override
  String get onlineGallery_ratingQuestionable => '可疑';

  @override
  String get onlineGallery_ratingExplicit => '限制級';

  @override
  String get onlineGallery_sourceGeneralOnly => '此來源僅提供全年齡內容';

  @override
  String get onlineGallery_sourceUnrated => '來源未分級';

  @override
  String get onlineGallery_sourceUnratedTooltip => '此來源未提供可靠的內容分級，應用程式無法準確推斷';

  @override
  String get onlineGallery_clear => '清除';

  @override
  String get onlineGallery_previousPage => '上一頁';

  @override
  String get onlineGallery_nextPage => '下一頁';

  @override
  String onlineGallery_pageN(Object page) {
    return '第 $page 頁';
  }

  @override
  String get onlineGallery_dateRange => '日期範圍';

  @override
  String get onlineGallery_fuzzySearch => '模糊匹配';

  @override
  String get onlineGallery_fuzzySearchTooltip =>
      '開啟後使用 *tag* 匹配相近標籤；關閉時按 Danbooru 精確標籤搜尋';

  @override
  String get onlineGallery_blacklistShort => '屏蔽';

  @override
  String get onlineGallery_blacklistTags => '黑名單標籤';

  @override
  String get onlineGallery_outputFilter => '輸出過濾';

  @override
  String get onlineGallery_outputFilterShort => '輸出';

  @override
  String get onlineGallery_outputFilterTooltip => '管理複製、傳送和加入佇列時自動剔除的標籤';

  @override
  String get onlineGallery_outputFilterTitle => '輸出過濾標籤';

  @override
  String get onlineGallery_outputFilterSubtitle =>
      '圖片仍會正常顯示；這些標籤只會從複製、傳送和佇列提示詞中精確剔除。';

  @override
  String get onlineGallery_outputFilterAddHint => '新增需要從輸出中剔除的標籤';

  @override
  String get onlineGallery_outputFilterInputHint => '支援逗號、中文逗號、頓號或換行分隔';

  @override
  String get onlineGallery_outputFilterEmpty => '暫未設定輸出過濾標籤';

  @override
  String get onlineGallery_outputFilterRestoreDefaults => '恢復預設過濾詞';

  @override
  String get onlineGallery_outputFilterClearTitle => '清空輸出過濾？';

  @override
  String get onlineGallery_outputFilterClearConfirm =>
      '清空後，水印和馬賽克等標籤也會重新出現在複製與傳送的提示詞中。';

  @override
  String get onlineGallery_addTagToOutputFilter => '加入輸出過濾';

  @override
  String get onlineGallery_outputFilterAlreadyAdded => '已在輸出過濾中';

  @override
  String get onlineGallery_outputFilterMenuHint => '保留圖片，只從輸出提示詞中剔除此標籤';

  @override
  String get onlineGallery_addTagToBlacklist => '加入黑名單';

  @override
  String get onlineGallery_blacklistAlreadyAdded => '已在黑名單中';

  @override
  String get onlineGallery_blacklistMenuHint => '隱藏包含此標籤的畫廊圖片';

  @override
  String get onlineGallery_outputFilteredTagTooltip =>
      '此標籤會在複製、傳送和加入佇列時被剔除；右鍵可管理';

  @override
  String get onlineGallery_tagContextMenuTooltip => '右鍵可加入黑名單或輸出過濾';

  @override
  String onlineGallery_outputFilterTagAdded(Object tag) {
    return '已將 $tag 加入輸出過濾';
  }

  @override
  String onlineGallery_blacklistTagAdded(Object tag) {
    return '已將 $tag 加入黑名單';
  }

  @override
  String get onlineGallery_blacklistTitle => '線上畫廊黑名單';

  @override
  String get onlineGallery_blacklistSubtitle => '所有線上畫廊共用這份清單；離線時仍會正常屏蔽。';

  @override
  String get onlineGallery_blacklistCloudDescription =>
      '已連接 Danbooru；本機修改會在安全合併後同步';

  @override
  String get onlineGallery_blacklistCloudLoginRequired =>
      '本機黑名單仍然有效；登入 Danbooru 後可以同步';

  @override
  String get onlineGallery_blacklistCloudUnavailable =>
      '本機黑名單仍然有效；驗證 Danbooru 連線後會恢復雲端同步';

  @override
  String get onlineGallery_addBlacklistTagHint => '新增黑名單標籤';

  @override
  String get onlineGallery_noLocalBlacklistTags => '暫無黑名單標籤';

  @override
  String get onlineGallery_pullBlacklist => '從雲端拉取';

  @override
  String get onlineGallery_pushBlacklist => '推送至雲端';

  @override
  String get onlineGallery_pushBlacklistConfirmTitle => '使用統一清單覆寫雲端？';

  @override
  String get onlineGallery_pushBlacklistConfirmBody =>
      '這會完整取代 Danbooru 雲端黑名單。一般自動同步會保留無法識別的進階規則，但本次完整推送會刪除它們。';

  @override
  String get onlineGallery_blacklistPushSucceeded => '已使用本機黑名單覆寫雲端清單';

  @override
  String get onlineGallery_blacklistSyncFailedMessage => '黑名單同步失敗，請檢查登入狀態與網路連線';

  @override
  String onlineGallery_blacklistSaveFailed(String error) {
    return '儲存黑名單失敗：$error';
  }

  @override
  String get onlineGallery_autoSyncOnStartup => '啟動時重新整理雲端清單';

  @override
  String get onlineGallery_autoSyncOnStartupSubtitle => '安全合併雲端新增標籤，不刪除本機標籤';

  @override
  String onlineGallery_lastSyncFailed(Object error) {
    return '上次同步失敗: $error';
  }

  @override
  String get onlineGallery_neverSyncedBlacklist => '尚未同步過 Danbooru 黑名單';

  @override
  String onlineGallery_lastSync(Object time) {
    return '上次同步: $time';
  }

  @override
  String get onlineGallery_blacklistSettingsTitle => '線上畫廊黑名單設定';

  @override
  String get onlineGallery_blacklistImportTitle => '批次匯入標籤';

  @override
  String get onlineGallery_blacklistImportHint => '每行或使用逗號分隔一個標籤';

  @override
  String onlineGallery_blacklistImported(Object count) {
    return '已新增 $count 個標籤';
  }

  @override
  String get onlineGallery_blacklistClearTitle => '清空統一黑名單？';

  @override
  String get onlineGallery_blacklistClearBody =>
      '畫廊將立即停止使用這些標籤過濾。雲端不會自動清空，可以復原本次操作。';

  @override
  String onlineGallery_blacklistPullSummary(
    Object added,
    Object existing,
    Object skipped,
    Object opaque,
  ) {
    return '已新增 $added 項，已有 $existing 項，略過已刪除 $skipped 項；保留 $opaque 條雲端進階規則';
  }

  @override
  String onlineGallery_blacklistPushDiff(
    Object added,
    Object removed,
    Object opaque,
  ) {
    return '雲端將新增 $added 項、刪除 $removed 項，並刪除 $opaque 條進階規則。';
  }

  @override
  String get onlineGallery_blacklistCloudEmptyConfirm => '確認清空雲端黑名單';

  @override
  String get onlineGallery_blacklistMigrationConfirm =>
      '此清單包含舊版本中無法確認帳號歸屬的雲端標籤；確認將它們同步到目前帳號';

  @override
  String get onlineGallery_bulkFavorite => '批次收藏';

  @override
  String get onlineGallery_bulkDownload => '批次下載';

  @override
  String onlineGallery_addedTasksToQueue(Object count) {
    return '已新增 $count 個任務到佇列';
  }

  @override
  String onlineGallery_queueBatchCompleted(
    Object added,
    Object prepareFailed,
    Object queueSkipped,
  ) {
    return '已加入 $added 個任務；$prepareFailed 個未能準備；$queueSkipped 個因佇列已滿而未加入';
  }

  @override
  String get onlineGallery_unfavorited => '已取消收藏';

  @override
  String get onlineGallery_favorited => '已收藏';

  @override
  String onlineGallery_favoritedImages(Object count) {
    return '已收藏 $count 張圖片';
  }

  @override
  String onlineGallery_selectDownloadDirectoryFailed(Object error) {
    return '選擇下載目錄失敗: $error';
  }

  @override
  String onlineGallery_downloadSelectedStarted(Object count) {
    return '開始下載 $count 張圖片...';
  }

  @override
  String onlineGallery_downloadSelectedCompletedWithSkipped(
    Object success,
    Object failed,
    Object skipped,
  ) {
    return '下載完成：成功 $success，失敗 $failed，略過 $skipped 個純文字詞條';
  }

  @override
  String get onlineGallery_startDate => '開始日期';

  @override
  String get onlineGallery_endDate => '結束日期';

  @override
  String get onlineGallery_invalidDateFormat => '日期格式無效';

  @override
  String get onlineGallery_dateOutOfRange => '日期超出範圍';

  @override
  String get onlineGallery_last30Days => '最近30天';

  @override
  String get onlineGallery_configureGelbooruApi => '配置 Gelbooru API';

  @override
  String get onlineGallery_gelbooruApiReady => 'Gelbooru API 已驗證';

  @override
  String get onlineGallery_gelbooruApiInvalid => 'Gelbooru 憑據已失效';

  @override
  String get onlineGallery_gelbooruCredentialsRequired =>
      '請先配置 Gelbooru User ID 和 API Key 以檢視網站收藏。';

  @override
  String get onlineGallery_gelbooruCredentialsInvalid =>
      'Gelbooru 憑據已失效，請重新配置。';

  @override
  String get onlineGallery_gelbooruRateLimited => 'Gelbooru 請求過於頻繁，請稍後再試。';

  @override
  String get onlineGallery_gelbooruTimeout => 'Gelbooru 請求超時，請檢查網路連線。';

  @override
  String get onlineGallery_gelbooruServerError => 'Gelbooru 伺服器暫時不可用，請稍後再試。';

  @override
  String get onlineGallery_gelbooruNetworkError =>
      '無法連線 Gelbooru，請檢查網路設定或代理配置。';

  @override
  String get onlineGallery_gelbooruMalformedResponse => 'Gelbooru 返回了無法解析的資料。';

  @override
  String get onlineGallery_gelbooruRequestFailed => 'Gelbooru 請求失敗，請稍後重試。';

  @override
  String get onlineGallery_aiTagQuery => '搜尋作品、作者、標題、標籤或模型';

  @override
  String get onlineGallery_aiTagPromptQuery =>
      'AI Prompt 搜尋（可搜尋 artist: 等 Prompt 原文）';

  @override
  String get onlineGallery_sourceQuickTagCloud => '法典圖鑑';

  @override
  String get onlineGallery_codexSearchHint => '搜尋標題、提示詞、備註、分類或貢獻者';

  @override
  String get onlineGallery_codexLabel => '法典';

  @override
  String get onlineGallery_codexSelect => '選擇法典';

  @override
  String get onlineGallery_codexAll => '全部法典';

  @override
  String get onlineGallery_codexBrowse => '瀏覽';

  @override
  String get onlineGallery_codexLatest => '本次更新';

  @override
  String get onlineGallery_codexRecent => '最近瀏覽';

  @override
  String get onlineGallery_codexCategory => '分類';

  @override
  String get onlineGallery_codexAllCategories => '全部分類';

  @override
  String get onlineGallery_codexUpdateBatch => '更新批次';

  @override
  String get onlineGallery_codexMediaFilter => '配圖';

  @override
  String get onlineGallery_codexAllEntries => '全部詞條';

  @override
  String get onlineGallery_codexWithImages => '只看有圖';

  @override
  String get onlineGallery_codexWithoutImages => '只看無圖';

  @override
  String get onlineGallery_codexOffline => '離線快取';

  @override
  String get onlineGallery_codexContributors => '貢獻者與來源';

  @override
  String onlineGallery_codexEntryCount(Object entries, Object images) {
    return '$entries 個詞條 · $images 個有圖';
  }

  @override
  String get onlineGallery_codexNoImage => '無配圖詞條';

  @override
  String get onlineGallery_codexNoImageDescription => '這是純文字詞條，提示詞與中繼資料仍可完整使用。';

  @override
  String get onlineGallery_codexAuthor => '作者';

  @override
  String get onlineGallery_codexImageFile => '圖片檔案';

  @override
  String get onlineGallery_codexOriginalFile => '原圖檔案';

  @override
  String get onlineGallery_codexDeclaredSource => '資料來源';

  @override
  String get onlineGallery_codexPrompt => '正向提示詞';

  @override
  String get onlineGallery_codexNegativePrompt => '負向提示詞';

  @override
  String get onlineGallery_codexCharacterPrompts => '角色提示詞';

  @override
  String get onlineGallery_codexNote => '備註';

  @override
  String get onlineGallery_codexSendToGeneration => '帶入生成頁';

  @override
  String get onlineGallery_codexAddToQueue => '加入生成佇列';

  @override
  String get onlineGallery_codexDownloadOriginal => '下載目前原圖';

  @override
  String get onlineGallery_codexOpenSource => '開啟上游';

  @override
  String get onlineGallery_codexOpenOrigin => '開啟原址';

  @override
  String get onlineGallery_codexOpenSourceFailed => '無法開啟聲明的資料來源。';

  @override
  String get onlineGallery_codexBookLocked => '此法典包含成人內容，請在分級選單中選擇「可疑」或「限制級」。';

  @override
  String get onlineGallery_codexNoData => '暫無符合條件的法典詞條';

  @override
  String get onlineGallery_codexExternalFallback => '外部來源暫時無法使用，正在顯示法典站快取版本。';

  @override
  String get onlineGallery_codexPreviousRelease => '目前版本暫時無法使用，正在顯示上一個已驗證版本。';

  @override
  String get onlineGallery_codexCachedBadge => '舊版快取';

  @override
  String get onlineGallery_codexUntitled => '未命名詞條';

  @override
  String get onlineGallery_artistHunt => '僅畫師串';

  @override
  String get onlineGallery_artistHuntTooltip =>
      '只顯示正向 Prompt 中明確包含 artist: 標籤的圖片';

  @override
  String get onlineGallery_copyArtistChain => '複製畫師串';

  @override
  String get onlineGallery_copyPrompt => '複製提示詞';

  @override
  String get onlineGallery_promptCopyDescription =>
      '選擇要複製的原始提示詞類別。正向與負向內容會以純文字區塊分隔。';

  @override
  String get onlineGallery_promptCopyCategoryHint => '按來源提供的標籤類別複製';

  @override
  String get onlineGallery_promptCopyStructuredHint => '複製該提示詞欄位的原始內容';

  @override
  String onlineGallery_artistCount(Object count) {
    return '$count 位畫師';
  }

  @override
  String get onlineGallery_artistHuntNoExactResults => '候選作品中沒有精確畫師串';

  @override
  String onlineGallery_artistHuntPartialFailure(Object count) {
    return '有 $count 個作品解析失敗，可重試再次檢查。';
  }

  @override
  String get onlineGallery_artistHuntDetailFailed => '候選作品詳情全部解析失敗，請重試。';

  @override
  String get onlineGallery_aiTagTimeRange => '時間範圍';

  @override
  String get onlineGallery_aiTagAllTime => '全部';

  @override
  String get onlineGallery_aiTagCurrentMonthly => '實時月榜';

  @override
  String get onlineGallery_aiTagOlderMonthly => '更早歸檔';

  @override
  String get onlineGallery_aiTagRankingProcessing => '排行榜生成中，請稍後重試。';

  @override
  String get onlineGallery_sourceConfigUnavailable => '無法獲取來源配置，請檢查網路後重試。';

  @override
  String get onlineGallery_sourceRateLimited => '請求過於頻繁，請稍後重試。';

  @override
  String get onlineGallery_sourceTimeout => '請求超時，請檢查網路連線。';

  @override
  String get onlineGallery_sourceNetworkError => '無法連線當前畫廊來源，請檢查網路或代理。';

  @override
  String get onlineGallery_sourceRequestFailed => '請求失敗，請稍後重試。';

  @override
  String onlineGallery_actionFailed(Object error) {
    return '操作失敗：$error';
  }

  @override
  String get onlineGallery_sourceMalformedResponse => '來源返回的資料結構已變化，暫時無法解析。';

  @override
  String get onlineGallery_detailNotFound => '作品不存在或已被刪除。';

  @override
  String get onlineGallery_imageUnavailable => '圖片當前不可用。';

  @override
  String get onlineGallery_loadedAll => '已載入全部';

  @override
  String get onlineGallery_retryAppend => '載入失敗，點選重試';

  @override
  String onlineGallery_multipleImages(Object count) {
    return '$count 張圖片';
  }

  @override
  String get onlineGallery_views => '瀏覽';

  @override
  String get onlineGallery_downloadAllMedia => '下載作品全部圖片';

  @override
  String get onlineGallery_copyAllTags => '複製全部 TAG';

  @override
  String get onlineGallery_customCopyTags => '自訂複製';

  @override
  String get promptCopy_exportTitle => '自訂複製 TAG';

  @override
  String get promptCopy_allPositive => '全部正面提示詞';

  @override
  String get promptCopy_allNegative => '全部負面提示詞';

  @override
  String get promptCopy_mainPositive => '主 / 全域正面提示詞';

  @override
  String get promptCopy_mainNegative => '主 / 全域負面提示詞';

  @override
  String get promptCopy_fixedPositive => '固定正面提示詞';

  @override
  String get promptCopy_fixedNegative => '固定負面提示詞';

  @override
  String promptCopy_characterPositive(int index) {
    return '角色 $index 正面提示詞';
  }

  @override
  String promptCopy_characterNegative(int index) {
    return '角色 $index 負面提示詞';
  }

  @override
  String get onlineGallery_gelbooruReadOnly => '只讀收藏';

  @override
  String get onlineGallery_gelbooruFavoritesSortHint =>
      '按帖子 ID 從新到舊排列，不保證與網站收藏時間順序一致。';

  @override
  String get tooltip_fullscreenEdit => '全屏編輯';

  @override
  String get tooltip_decreaseWeight => '減少權重 [-5%]';

  @override
  String get tooltip_increaseWeight => '增加權重 [+5%]';

  @override
  String get tooltip_edit => '編輯';

  @override
  String get tooltip_copy => '複製';

  @override
  String get tooltip_delete => '刪除';

  @override
  String get tooltip_enable => '啟用';

  @override
  String get tooltip_disable => '禁用';

  @override
  String get tooltip_resetWeight => '點選重置為100%';

  @override
  String get upscale_scale => '放大倍數';

  @override
  String get danbooru_loginTitle => '登入 Danbooru';

  @override
  String get danbooru_loginHint => '使用使用者名稱和 API Key 登入以使用收藏夾功能';

  @override
  String get danbooru_username => '使用者名稱';

  @override
  String get danbooru_usernameHint => '輸入 Danbooru 使用者名稱';

  @override
  String get danbooru_usernameRequired => '請輸入使用者名稱';

  @override
  String get danbooru_apiKeyHint => '輸入 API Key';

  @override
  String get danbooru_apiKeyRequired => '請輸入 API Key';

  @override
  String get danbooru_howToGetApiKey => '如何獲取 API Key?';

  @override
  String get danbooru_loginSuccess => '登入成功';

  @override
  String get gelbooru_configureTitle => '配置 Gelbooru API';

  @override
  String get gelbooru_configureHint =>
      '輸入 Gelbooru 賬戶設定頁提供的 User ID 和 API Key。應用不會收集密碼或瀏覽器 Cookie。';

  @override
  String get gelbooru_userId => 'User ID';

  @override
  String get gelbooru_userIdHint => '輸入正整數 User ID';

  @override
  String get gelbooru_userIdRequired => '請輸入有效的正整數 User ID';

  @override
  String get gelbooru_apiKeyHint => '輸入 API Key';

  @override
  String get gelbooru_apiKeyRequired => '請輸入 API Key';

  @override
  String get gelbooru_openAccountSettings => '開啟 Gelbooru 賬戶設定';

  @override
  String get gelbooru_save => '驗證並儲存';

  @override
  String get gelbooru_saved => 'Gelbooru 憑據已儲存';

  @override
  String get gelbooru_removeCredentials => '移除憑據';

  @override
  String get gelbooru_invalidInput => '請輸入有效的 User ID 和 API Key。';

  @override
  String get gelbooru_invalidCredentials =>
      'Gelbooru 拒絕了這些憑據，請檢查 User ID 和 API Key。';

  @override
  String get gelbooru_rateLimited => '請求過於頻繁，請稍後再試。';

  @override
  String get gelbooru_timeout => '驗證超時，請檢查網路連線。';

  @override
  String get gelbooru_serverError => 'Gelbooru 伺服器暫時不可用。';

  @override
  String get gelbooru_networkError => '無法連線 Gelbooru，請檢查網路設定或代理配置。';

  @override
  String get gelbooru_malformedResponse => 'Gelbooru 返回了無法解析的資料。';

  @override
  String get gelbooru_storageError => '無法安全儲存或讀取 Gelbooru 憑據。';

  @override
  String get gelbooru_unknownError => 'Gelbooru 驗證失敗，請稍後重試。';

  @override
  String get weight_title => '權重';

  @override
  String get weight_reset => '重置';

  @override
  String get weight_done => '完成';

  @override
  String get weight_noBrackets => '無括號';

  @override
  String get weight_editTag => '編輯標籤';

  @override
  String get weight_tagName => '標籤名稱';

  @override
  String get weight_tagNameHint => '輸入標籤名稱...';

  @override
  String tag_selected(Object count) {
    return '已選 $count';
  }

  @override
  String get tag_enable => '啟用';

  @override
  String get tag_disable => '禁用';

  @override
  String get tag_delete => '刪除';

  @override
  String get tag_addTag => '新增標籤';

  @override
  String get tag_add => '新增';

  @override
  String get tag_inputHint => '輸入標籤...';

  @override
  String get tag_copiedToClipboard => '已複製到剪貼簿';

  @override
  String get tag_emptyHint => '新增標籤來描述你想要的畫面';

  @override
  String get tag_emptyHintSub => '你可以瀏覽、搜尋或手動新增標籤';

  @override
  String get tagCategory_artist => '藝術家';

  @override
  String get tagCategory_copyright => '版權';

  @override
  String get tagCategory_character => '角色';

  @override
  String get tagCategory_meta => '後設資料';

  @override
  String get tagCategory_general => '通用';

  @override
  String get qualityTags_label => '質量詞';

  @override
  String get qualityTags_positive => '質量詞（正面）';

  @override
  String get qualityTags_negative => '質量詞（負面）';

  @override
  String get qualityTags_disabled => '質量標籤已關閉\n點選開啟';

  @override
  String get qualityTags_addToEnd => '新增到提示詞末尾:';

  @override
  String get qualityTags_naiDefault => 'NAI 預設';

  @override
  String get qualityTags_naiDefaultStandard => 'NAI 預設（標準）';

  @override
  String get qualityTags_naiDefaultLight => 'NAI 預設（輕量）';

  @override
  String get qualityTags_none => '無';

  @override
  String get qualityTags_addFromLibrary => '從詞庫新增';

  @override
  String get qualityTags_selectFromLibrary => '選擇質量詞條目';

  @override
  String get ucPreset_label => '負面預設';

  @override
  String get ucPreset_heavy => '重度';

  @override
  String get ucPreset_light => '輕度';

  @override
  String get ucPreset_furryFocus => '獸人';

  @override
  String get ucPreset_humanFocus => '人物';

  @override
  String get ucPreset_none => '無';

  @override
  String get ucPreset_disabled => '負面提示詞預設已關閉';

  @override
  String get ucPreset_addToNegative => '新增到負面提示詞開頭:';

  @override
  String get ucPreset_nsfwHint =>
      '💡 如需生成成人內容，請在正面提示詞中新增 nsfw，負面提示詞中的 nsfw 將自動移除';

  @override
  String get ucPreset_addFromLibrary => '從詞庫新增';

  @override
  String get ucPreset_selectFromLibrary => '選擇負面詞條目';

  @override
  String get randomMode_enabledTip => '抽卡模式已開啟\n每次生成後自動隨機新提示詞';

  @override
  String get randomMode_disabledTip => '抽卡模式\n點選開啟後每次生成自動隨機提示詞';

  @override
  String get batchSize_title => '批次大小';

  @override
  String batchSize_tooltip(int count) {
    return '每次請求生成 $count 張';
  }

  @override
  String get batchSize_description => '每次 API 請求生成的圖片數量';

  @override
  String batchSize_formula(int batchCount, int batchSize, int total) {
    return '總影象數 = $batchCount × $batchSize = $total 張';
  }

  @override
  String get batchSize_hint => '較大的批次可減少請求次數，但單次等待時間更長';

  @override
  String get batchSize_costWarning => '⚠️ 批次大小 > 1 時會額外消耗 Anlas 點數';

  @override
  String get warmup_networkCheck => '檢測網路連線...';

  @override
  String get warmup_networkCheck_noProxy => '無法連線到 NovelAI，請開啟VPN或啟用代理設定';

  @override
  String get warmup_networkCheck_noSystemProxy => '已啟用代理但未檢測到系統代理，請開啟VPN';

  @override
  String get warmup_networkCheck_manualIncomplete => '手動代理配置不完整，請檢查設定';

  @override
  String get warmup_networkCheck_testing => '正在檢測網路連線...';

  @override
  String get warmup_networkCheck_testingProxy => '正在透過代理檢測網路...';

  @override
  String warmup_networkCheck_success(Object latency) {
    return '網路連線正常 (${latency}ms)';
  }

  @override
  String get warmup_networkCheck_timeout => '網路檢測超時，繼續離線啟動';

  @override
  String warmup_networkCheck_attempt(Object attempt, Object maxAttempts) {
    return '正在檢測網路連線... (嘗試 $attempt/$maxAttempts)';
  }

  @override
  String get warmup_preparing => '準備中...';

  @override
  String get warmup_complete => '完成';

  @override
  String get warmup_danbooruAuth => '初始化 Danbooru 認證...';

  @override
  String get warmup_loadingTranslation => '載入翻譯資料...';

  @override
  String get warmup_initUnifiedDatabase => '初始化標籤資料庫...';

  @override
  String get warmup_initTagSystem => '初始化標籤系統...';

  @override
  String get warmup_loadingPromptConfig => '載入提示詞配置...';

  @override
  String get warmup_imageEditor => '初始化影象編輯器...';

  @override
  String get warmup_database => '載入最近歷史記錄...';

  @override
  String get warmup_network => '檢查網路連線...';

  @override
  String get warmup_fonts => '預載入字型...';

  @override
  String get warmup_imageCache => '預熱影象快取...';

  @override
  String get warmup_statistics => '載入統計資料...';

  @override
  String get warmup_artistsSync => '同步畫師資料...';

  @override
  String get warmup_subscription => '載入訂閱資訊...';

  @override
  String get warmup_dataSourceCache => '初始化資料來源快取...';

  @override
  String get warmup_galleryFileCount => '掃描相簿檔案...';

  @override
  String get warmup_cooccurrenceData => '載入標籤共現資料...';

  @override
  String get warmup_group_basicUI => '初始化基礎 UI 服務...';

  @override
  String get warmup_group_basicUI_complete => '基礎 UI 服務就緒';

  @override
  String get warmup_group_dataServices => '初始化資料服務...';

  @override
  String get warmup_group_dataServices_complete => '資料服務就緒';

  @override
  String get warmup_group_networkServices => '初始化網路服務...';

  @override
  String get warmup_group_networkServices_complete => '網路服務就緒';

  @override
  String get warmup_group_cacheServices => '初始化快取服務...';

  @override
  String get warmup_group_cacheServices_complete => '快取服務就緒';

  @override
  String get warmup_cooccurrenceInit => '初始化共現資料...';

  @override
  String get warmup_translationInit => '初始化翻譯資料...';

  @override
  String get warmup_danbooruTagsInit => '初始化 Danbooru 標籤...';

  @override
  String get warmup_dataMigration => '遷移 Hive / Vibe / 圖片資料...';

  @override
  String warmup_dataMigrationFailed(Object details) {
    return '資料遷移失敗：$details';
  }

  @override
  String get warmup_galleryDataSource => '初始化畫廊索引...';

  @override
  String get warmup_checkAndRecoverData => '檢查資料完整性...';

  @override
  String get warmup_group_dataSourceInitialization => '初始化資料來源服務...';

  @override
  String get warmup_group_dataSourceInitialization_complete => '資料來源服務就緒';

  @override
  String warmup_fetchingTags(Object message) {
    return '正在同步標籤：$message';
  }

  @override
  String get warmup_fetchingTagDataFromServer => '正在從伺服器拉取標籤資料...';

  @override
  String get warmup_fetchingGeneralTags => '正在拉取通用標籤...';

  @override
  String get warmup_fetchingCharacterTags => '正在拉取角色標籤...';

  @override
  String get warmup_fetchingCopyrightTags => '正在拉取版權標籤...';

  @override
  String get warmup_fetchingMetaTags => '正在拉取元標籤...';

  @override
  String get resolution_groupNormal => '常規';

  @override
  String get resolution_groupLarge => '大尺寸';

  @override
  String get resolution_groupWallpaper => '桌布';

  @override
  String get resolution_groupSmall => '小尺寸';

  @override
  String get resolution_groupCustom => '自定義';

  @override
  String get resolution_typePortrait => '豎屏';

  @override
  String get resolution_typeLandscape => '橫屏';

  @override
  String get resolution_typeSquare => '方形';

  @override
  String get resolution_typeCustom => '自定義';

  @override
  String get resolution_width => '寬度';

  @override
  String get resolution_height => '高度';

  @override
  String get generation_invalidResolution => '解析度無效';

  @override
  String generation_invalidResolutionHint(
    int width,
    int height,
    int suggestedWidth,
    int suggestedHeight,
  ) {
    return '$width×$height 無法用於生成。寬度和高度必須是 64 的倍數、單邊不能超過 4096，且總畫素不能超過 3,145,728。最接近的可用尺寸是 $suggestedWidth×$suggestedHeight。';
  }

  @override
  String get api_error_429 => '併發限制';

  @override
  String get api_error_429_hint => '請求過於頻繁，請稍後重試（常見於合租賬號）';

  @override
  String get api_error_401 => '認證失敗';

  @override
  String get api_error_401_hint => 'Token 無效或已過期，請重新登入';

  @override
  String get api_error_402 => '餘額不足';

  @override
  String get api_error_402_hint => 'Anlas 餘額不足，請充值後重試';

  @override
  String get api_error_500 => '伺服器錯誤';

  @override
  String get api_error_500_hint => 'NovelAI 伺服器出現問題，請稍後重試';

  @override
  String get api_error_503 => '服務不可用';

  @override
  String get api_error_503_hint => '伺服器正在維護或過載，請稍後重試';

  @override
  String get api_error_timeout => '請求超時';

  @override
  String get api_error_timeout_hint => '網路連線超時，請檢查網路後重試';

  @override
  String get api_error_network => '網路錯誤';

  @override
  String get api_error_network_hint => '無法連線到伺服器，請檢查網路';

  @override
  String get drop_processing => '正在解析圖片...';

  @override
  String get characterEditor_close => '關閉';

  @override
  String get characterEditor_clearAll => '清空所有';

  @override
  String get characterEditor_clearAllTitle => '清空所有角色';

  @override
  String get characterEditor_clearAllConfirm => '確定要刪除所有角色嗎？此操作無法撤銷。';

  @override
  String get characterEditor_nameHint => '輸入角色名稱';

  @override
  String get characterEditor_enabled => '啟用';

  @override
  String get characterEditor_promptHint => '輸入角色的正向提示詞...';

  @override
  String get characterEditor_negativePromptHint => '輸入角色的負面提示詞...';

  @override
  String get characterCanvas_title => '角色位置';

  @override
  String get characterCanvas_aiChoice => 'AI 選擇';

  @override
  String get characterCanvas_custom => '自定義';

  @override
  String get characterCanvas_aiHint => 'AI 將自動安排角色位置';

  @override
  String get characterCanvas_dragHint => '拖動錨點設定角色位置，鬆開即生效';

  @override
  String get characterCanvas_guide => '構圖參考線';

  @override
  String get characterCanvas_guideNone => '無';

  @override
  String get characterCanvas_guideThirds => '三分法';

  @override
  String get characterCanvas_guidePhi => '黃金比';

  @override
  String get characterCanvas_guideGrid => '格線';

  @override
  String get characterCanvas_guideColumns => '欄';

  @override
  String get characterCanvas_guideRows => '列';

  @override
  String get characterEditor_genderFemale => '女性';

  @override
  String get characterEditor_genderMale => '男性';

  @override
  String get characterEditor_genderOther => '其他';

  @override
  String get characterEditor_addFemale => '女';

  @override
  String get characterEditor_addMale => '男';

  @override
  String get characterEditor_addOther => '其他';

  @override
  String get characterEditor_addFromLibrary => '詞庫';

  @override
  String get characterEditor_moveUp => '上移';

  @override
  String get characterEditor_moveDown => '下移';

  @override
  String get toolbar_randomPrompt => '隨機提示詞';

  @override
  String get randomPromptToolsHiddenHint => '隨機提示詞工具已在設定中隱藏';

  @override
  String get toolbar_fullscreenEdit => '全屏編輯';

  @override
  String get toolbar_clear => '清空';

  @override
  String get toolbar_confirmClear => '確認清空';

  @override
  String get toolbar_settings => '設定';

  @override
  String get characterTooltip_disabledLabel => '已禁用';

  @override
  String get characterTooltip_notSet => '未設定';

  @override
  String get characterTooltip_previewTitle => '角色預覽';

  @override
  String characterTooltip_enabledSummary(int enabled, int total) {
    return '$enabled / $total 啟用';
  }

  @override
  String characterTooltip_more(int count) {
    return '還有 $count 個角色';
  }

  @override
  String tagLibrary_generatedCharacters(Object count) {
    return '已生成 $count 個角色';
  }

  @override
  String tagLibrary_generateFailed(Object error) {
    return '生成失敗: $error';
  }

  @override
  String get randomPrompt_unsupportedModel => '目前模型不支援官網隨機詞庫';

  @override
  String get randomPrompt_unsupportedModelHint =>
      '目前模型沒有對應的 NovelAI 官網隨機方案。請選擇支援的 NovelAI 模型，或使用自己的自訂預設。';

  @override
  String get naiMode_noTags => '暫無標籤';

  @override
  String get naiAlgorithm_mainPrompt => '主提示詞';

  @override
  String tagGroup_tagCount(Object count) {
    return '$count 標籤';
  }

  @override
  String get addGroup_tagGroupTab => '標籤詞庫';

  @override
  String get addGroup_displayNameLabel => '顯示名稱（可選）';

  @override
  String get addGroup_targetCategoryLabel => '目標分類';

  @override
  String get addGroup_poolTab => '圖集';

  @override
  String globalSettings_saveFailed(Object error) {
    return '儲存失敗: $error';
  }

  @override
  String get globalSettings_category_hairColor => '髮色';

  @override
  String get globalSettings_category_eyeColor => '瞳色';

  @override
  String get globalSettings_category_hairStyle => '髮型';

  @override
  String get globalSettings_category_expression => '表情';

  @override
  String get globalSettings_category_pose => '姿勢';

  @override
  String get globalSettings_category_clothing => '服裝';

  @override
  String get globalSettings_category_accessory => '配飾';

  @override
  String get globalSettings_category_bodyFeature => '身體特徵';

  @override
  String get globalSettings_category_background => '背景';

  @override
  String get globalSettings_category_scene => '場景';

  @override
  String get globalSettings_category_style => '風格';

  @override
  String get nav_generate => '生成';

  @override
  String get nav_gallery => '圖庫';

  @override
  String get nav_settings => '設定';

  @override
  String get sync_preparing => '準備同步...';

  @override
  String sync_fetching(Object category) {
    return '正在獲取 $category...';
  }

  @override
  String get sync_processing => '正在處理資料...';

  @override
  String get sync_saving => '正在儲存...';

  @override
  String sync_completed(Object count) {
    return '同步完成，共 $count 個標籤';
  }

  @override
  String sync_failed(Object error) {
    return '同步失敗: $error';
  }

  @override
  String sync_extracting(Object poolName) {
    return '正在提取 $poolName 標籤...';
  }

  @override
  String get sync_merging => '正在合併標籤...';

  @override
  String sync_fetching_tags(Object groupName) {
    return '正在獲取 $groupName 標籤熱度...';
  }

  @override
  String get sync_filtering => '正在篩選標籤...';

  @override
  String get sync_done => '同步完成';

  @override
  String get download_tags_data => '正在下載標籤資料...';

  @override
  String get download_cooccurrence_data => '正在下載共現標籤資料...';

  @override
  String get download_parsing_data => '正在解析資料...';

  @override
  String get download_readingFile => '正在讀取檔案...';

  @override
  String get download_mergingData => '正在合併資料...';

  @override
  String get download_loadComplete => '載入完成';

  @override
  String get time_just_now => '剛剛';

  @override
  String time_minutes_ago(Object n) {
    return '$n分鐘前';
  }

  @override
  String time_hours_ago(Object n) {
    return '$n小時前';
  }

  @override
  String time_days_ago(Object n) {
    return '$n天前';
  }

  @override
  String get time_never_synced => '從未同步';

  @override
  String get preset_resetToDefault => '重置為預設';

  @override
  String get newPresetDialog_title => '建立新預設';

  @override
  String get newPresetDialog_blank => '完全空白';

  @override
  String get newPresetDialog_blankDesc => '從頭開始建立預設，不包含任何預設內容';

  @override
  String get newPresetDialog_template => '基於預設預設';

  @override
  String get newPresetDialog_templateDesc => '複製預設預設的所有設定作為起點';

  @override
  String get category_dialogTitle => '建立新類別';

  @override
  String get category_nameHint => '輸入類別名稱';

  @override
  String get category_nameRequired => '請輸入類別名稱';

  @override
  String get category_selectEmoji => '選擇 Emoji';

  @override
  String get category_noRecentEmoji => '暫無最近使用的 Emoji';

  @override
  String get category_searchEmoji => '搜尋 Emoji';

  @override
  String get characterCountConfig_title => '人數類別配置';

  @override
  String get characterCountConfig_weight => '權重';

  @override
  String get characterCountConfig_solo => '單人';

  @override
  String get characterCountConfig_duo => '雙人';

  @override
  String get characterCountConfig_trio => '三人';

  @override
  String get characterCountConfig_noHumans => '無人';

  @override
  String get characterCountConfig_multiPerson => '多人';

  @override
  String get characterCountConfig_customizable => '可自定義';

  @override
  String get characterCountConfig_mainPrompt => '主提示詞';

  @override
  String get characterCountConfig_characterPrompt => '角色提示詞';

  @override
  String get characterCountConfig_addTagOption => '新增角色標籤';

  @override
  String get characterCountConfig_addMultiPersonCombo => '新增多人組合';

  @override
  String get characterCountConfig_displayName => '顯示名稱';

  @override
  String get characterCountConfig_displayNameHint => '例如：偽娘';

  @override
  String get characterCountConfig_mainPromptLabel => '主提示詞標籤';

  @override
  String get characterCountConfig_mainPromptHint =>
      '例如：solo, 2girls, 1girl 1boy';

  @override
  String get characterCountConfig_personCount => '人數：';

  @override
  String get characterCountConfig_slotConfig => '角色槽位配置';

  @override
  String get characterCountConfig_slot => '槽位';

  @override
  String get characterCountConfig_customSlots => '自定義槽位';

  @override
  String get characterCountConfig_customSlotsTitle => '角色槽位管理';

  @override
  String get characterCountConfig_customSlotsDesc => '新增或刪除可用的角色槽位選項';

  @override
  String get characterCountConfig_addSlotHint => '例如：1trap, 1futanari';

  @override
  String get characterCountConfig_slotExists => '該槽位已存在';

  @override
  String get randomManager_algorithmConfig => '演算法配置';

  @override
  String get randomManager_characterCountWeight => '角色數量權重';

  @override
  String get randomManager_genderWeight => '性別權重';

  @override
  String get randomManager_enableSeasonalWordlists => '啟用季節性詞庫';

  @override
  String get randomManager_enableSeasonalWordlistsDesc => '聖誕節、萬聖節等特殊日期詞庫';

  @override
  String get randomManager_globalEmphasisProbability => '全域性強調機率';

  @override
  String get randomManager_tagGroupList => '片語列表';

  @override
  String get randomManager_deleteTagGroupTitle => '刪除片語';

  @override
  String randomManager_deleteTagGroupConfirm(Object name) {
    return '確定要刪除片語「$name」嗎？此操作不可撤銷。';
  }

  @override
  String randomManager_tagGroupCount(Object count) {
    return '$count 個片語';
  }

  @override
  String get randomManager_categories => '類別';

  @override
  String get randomManager_tagGroups => '片語';

  @override
  String get randomManager_tags => '標籤';

  @override
  String get randomManager_addTagGroup => '新增片語';

  @override
  String get randomManager_locked => '已鎖定';

  @override
  String get randomManager_addCategory => '新增類別';

  @override
  String get randomManager_noCategories => '暫無類別';

  @override
  String get randomManager_noCategoriesHint => '點選“新增類別”開始配置';

  @override
  String get randomManager_globalPeopleSettings => '全域性人數設定';

  @override
  String get randomManager_importPreset => '匯入預設';

  @override
  String get randomManager_importPresetSubtitle => '從 JSON 文字匯入隨機配置預設';

  @override
  String get randomManager_exportCurrentPreset => '匯出當前預設';

  @override
  String get randomManager_noPresetSelected => '未選擇預設';

  @override
  String get randomManager_selectPresetFirst => '請先選擇預設';

  @override
  String get randomManager_defaultPresetReadonly => '預設預設為只讀，請先新建或複製為自定義預設';

  @override
  String randomManager_presetImported(Object name) {
    return '已匯入預設 \"$name\"';
  }

  @override
  String get randomManager_defaultPreset => 'NovelAI 官網預設';

  @override
  String get randomManager_femaleClothing => '女性服裝';

  @override
  String get randomManager_maleClothing => '男性服裝';

  @override
  String get randomManager_generalClothing => '通用服裝';

  @override
  String get randomManager_femaleBodyType => '女性體型';

  @override
  String get randomManager_maleBodyType => '男性體型';

  @override
  String get randomManager_generalBodyType => '通用體型';

  @override
  String get randomManager_soloFemale => '女性';

  @override
  String get randomManager_soloMale => '男性';

  @override
  String get randomManager_duoGirls => '雙女';

  @override
  String get randomManager_duoMixed => '一女一男';

  @override
  String get randomManager_duoBoys => '雙男';

  @override
  String get randomManager_trioGirls => '三女';

  @override
  String get randomManager_trioTwoGirlsOneBoy => '二女一男';

  @override
  String get randomManager_trioOneGirlTwoBoys => '一女二男';

  @override
  String get randomManager_trioBoys => '三男';

  @override
  String get randomManager_noHumanScene => '無人場景';

  @override
  String randomManager_presetCreated(Object name) {
    return '已建立預設 \"$name\"';
  }

  @override
  String randomManager_deletePresetConfirm(Object name) {
    return '確定要刪除 \"$name\" 嗎？此操作不可撤銷。';
  }

  @override
  String get randomManager_syncCompleted => 'Danbooru 標籤同步完成';

  @override
  String randomManager_syncFailed(Object error) {
    return '同步失敗: $error';
  }

  @override
  String get randomManager_resetDefaultTitle => '重置為預設配置';

  @override
  String get randomManager_resetDefaultContent =>
      '將恢復官方預設配置。\n您新增的自定義片語會被保留但禁用。';

  @override
  String get randomManager_resetDefaultConfirm => '確認重置';

  @override
  String get randomManager_resetDefaultDone => '已重置為預設配置';

  @override
  String get randomManager_generatePreview => '生成預覽';

  @override
  String get randomManager_importExport => '匯入/匯出';

  @override
  String get randomManager_syncDanbooruTags => '同步 Danbooru 標籤';

  @override
  String get randomManager_unknownError => '未知錯誤';

  @override
  String get randomManager_readOnlyMode => '只讀模式';

  @override
  String get randomManager_readOnlyTooltip => '當前預設為預設預設，所有配置項已鎖定';

  @override
  String get randomManager_global => '全域性';

  @override
  String randomManager_addTagGroupSubtitle(Object category) {
    return '新增到 \"$category\"';
  }

  @override
  String get randomManager_tagGroupName => '片語名稱';

  @override
  String get randomManager_tagGroupNameHint => '輸入片語名稱';

  @override
  String get randomManager_tagGroupNameRequired => '請輸入片語名稱';

  @override
  String get randomManager_customTab => '自定義';

  @override
  String get randomManager_tagList => '標籤列表';

  @override
  String get randomManager_tagListHelp => '每行一個標籤，支援格式: tag 或 tag:weight';

  @override
  String get randomManager_searchTagGroup => '搜尋 Tag Group...';

  @override
  String get randomManager_searchPool => '搜尋 Pool...';

  @override
  String randomManager_itemCount(Object count) {
    return '$count 個';
  }

  @override
  String get randomManager_noMatchingTagGroup => '未找到匹配的 Tag Group';

  @override
  String get randomManager_noMatchingPool => '未找到匹配的 Pool';

  @override
  String get randomManager_cannotLoadPreview => '無法載入預覽';

  @override
  String get randomManager_openInDanbooru => '在 Danbooru 中檢視';

  @override
  String get randomManager_editTagGroup => '編輯片語';

  @override
  String get randomManager_basicTab => '基礎';

  @override
  String randomManager_tagsTab(Object count) {
    return '標籤 ($count)';
  }

  @override
  String get randomManager_diyAbilitiesTab => 'DIY 能力';

  @override
  String get randomManager_selectionSingle => '單選';

  @override
  String get randomManager_selectionSingleDesc => '加權隨機選擇一個';

  @override
  String get randomManager_selectionAll => '全選';

  @override
  String get randomManager_selectionAllDesc => '選擇所有標籤';

  @override
  String get randomManager_selectionMultipleCount => '多選數量';

  @override
  String get randomManager_selectionMultipleCountDesc => '選擇指定數量';

  @override
  String get randomManager_selectionMultipleProbability => '多選機率';

  @override
  String get randomManager_selectionMultipleProbabilityDesc => '每個獨立判斷';

  @override
  String get randomManager_selectionSequential => '順序輪替';

  @override
  String get randomManager_selectionSequentialDesc => '跨批次保持狀態';

  @override
  String get randomManager_noTags => '暫無標籤';

  @override
  String get randomManager_conditionalBranch => '條件分支';

  @override
  String get randomManager_conditionalBranchDesc => '根據變數值選擇不同的標籤子集';

  @override
  String get randomManager_dependencyConfig => '依賴配置';

  @override
  String get randomManager_dependencyConfigDesc => '選擇數量依賴其他類別的值';

  @override
  String get randomManager_visibilityRules => '可見性規則';

  @override
  String get randomManager_visibilityRulesDesc => '根據構圖決定是否生成';

  @override
  String get randomManager_timeCondition => '時間條件';

  @override
  String get randomManager_timeConditionDesc => '特定日期範圍啟用';

  @override
  String get randomManager_postProcessRules => '後處理規則';

  @override
  String get randomManager_postProcessRulesDesc => '根據已選標籤移除衝突';

  @override
  String get randomManager_emphasisProbability => '強調機率';

  @override
  String get randomManager_probability => '機率';

  @override
  String get randomManager_selectionMode => '選擇模式';

  @override
  String get randomManager_previewGeneration => '輸出預覽';

  @override
  String get randomManager_generating => '生成中';

  @override
  String get randomManager_generate => '生成範例';

  @override
  String get randomManager_generationFailed => '生成失敗';

  @override
  String get randomManager_copy => '複製全部';

  @override
  String get randomManager_regenerate => '換一個範例';

  @override
  String get randomManager_copiedToClipboard => '已複製到剪貼簿';

  @override
  String get randomManager_selectPresetRequired => '請選擇一個預設';

  @override
  String randomManager_characterCountLabel(Object count) {
    return '$count人';
  }

  @override
  String randomManager_tagCountLabel(Object count) {
    return '$count標籤';
  }

  @override
  String get randomManager_previewHint => '尚未生成範例';

  @override
  String get randomManager_generateNow => '立即生成';

  @override
  String get randomManager_moreActions => '更多操作';

  @override
  String get randomManager_deleteSelected => '刪除選中';

  @override
  String get randomManager_keyboardShortcuts => '鍵盤快捷鍵';

  @override
  String get randomManager_generalShortcuts => '通用';

  @override
  String get randomManager_presetActions => '預設操作';

  @override
  String get randomManager_selectionActions => '選擇操作';

  @override
  String get randomManager_closeWindow => '關閉視窗';

  @override
  String get randomManager_refreshOrSync => '重新整理/同步';

  @override
  String get scope_global => '主提示詞';

  @override
  String get scope_globalTooltip => '提示詞將出現在主提示詞區域\n適合：背景、場景、畫面風格等';

  @override
  String get scope_character => '角色';

  @override
  String get scope_characterTooltip =>
      '提示詞將只出現在角色提示詞內\n每個角色單獨生成\n適合：髮色、眵色、服裝、表情等';

  @override
  String get scope_all => '通用';

  @override
  String get scope_allTooltip => '提示詞同時出現在主提示詞和角色提示詞\n適合：姿勢、互動等通用標籤';

  @override
  String get vibeParseFailed => '無法解析 Vibe 檔案';

  @override
  String get tag_categoryGeneral => '通用';

  @override
  String get tag_categoryArtist => '畫師';

  @override
  String get tag_categoryCopyright => '版權';

  @override
  String get tag_categoryCharacter => '角色';

  @override
  String get tag_categoryMeta => '後設資料';

  @override
  String get tag_countBadgeBreakdown => '標籤分類統計';

  @override
  String get localGallery_progressiveLoadError => '圖片載入失敗';

  @override
  String get localGallery_noImagesFound => '未找到圖片';

  @override
  String get localGallery_unknownError => '未知錯誤';

  @override
  String localGallery_loadFailed(Object error) {
    return '載入失敗: $error';
  }

  @override
  String get localGallery_indexingLocalImages => '索引本地圖片中...';

  @override
  String get localGallery_emptyTitle => '暫無本地圖片';

  @override
  String get localGallery_emptySubtitle => '生成的圖片將儲存在此處';

  @override
  String get localGallery_noMatchingResults => '無匹配結果';

  @override
  String get localGallery_loadingGroupedImages => '載入分組圖片中...';

  @override
  String localGallery_jumpedToMonth(Object year, Object month) {
    return '已跳轉到 $year-$month';
  }

  @override
  String get localGallery_title => '本地畫廊';

  @override
  String get localGallery_allImages => '全部圖片';

  @override
  String get localGallery_categoryPanelTitle => '分類';

  @override
  String get localGallery_searchFilenamePromptPlaceholder =>
      '搜尋檔名/Prompt，逗號分隔交集搜尋...';

  @override
  String get localGallery_selectCurrentPage => '選擇本頁';

  @override
  String get localGallery_deselectCurrentPage => '取消本頁';

  @override
  String get localGallery_selectAllResults => '選擇全部';

  @override
  String get localGallery_deselectAllResults => '取消全部';

  @override
  String get localGallery_moveSelected => '移動';

  @override
  String get localGallery_packSelected => '打包';

  @override
  String get localGallery_editMetadata => '編輯標籤';

  @override
  String get localGallery_switchToGridView => '切換到網格檢視';

  @override
  String get localGallery_switchToDateGroupedView => '切換到日期分組檢視';

  @override
  String get localGallery_openFilterPanel => '開啟篩選面板';

  @override
  String get localGallery_hideCategoryPanel => '隱藏分類面板';

  @override
  String get localGallery_showCategoryPanel => '顯示分類面板';

  @override
  String get localGallery_enterSelectionMode => '進入選擇模式';

  @override
  String get localGallery_refreshTooltip => '重新整理畫廊\n\n自動檢測新增/修改的圖片並更新索引';

  @override
  String get localGallery_tagIntersection => '標籤交集';

  @override
  String get localGallery_createCategoryTitle => '新建分類';

  @override
  String get localGallery_createCategoryHint => '請輸入分類名稱';

  @override
  String get localGallery_createCategoryConfirm => '建立';

  @override
  String get localGallery_createSubCategoryTitle => '新建子分類';

  @override
  String get localGallery_showInFolder => '在資料夾中顯示';

  @override
  String get localGallery_promptCopied => 'Prompt 已複製';

  @override
  String get localGallery_seedCopied => 'Seed 已複製';

  @override
  String localGallery_confirmDeleteImageContent(Object name) {
    return '確定要刪除圖片「$name」嗎？\n\n此操作無法撤銷。';
  }

  @override
  String get localGallery_imageDeleted => '圖片已刪除';

  @override
  String localGallery_deleteFailed(Object error) {
    return '刪除失敗: $error';
  }

  @override
  String get localGallery_categoryDeleteContent => '確定要刪除此分類嗎？資料夾及其內容將被保留。';

  @override
  String get localGallery_protectedDeleteCategoryTitle => '保護模式：確認刪除分類';

  @override
  String get localGallery_protectedDeleteCategoryContent =>
      '將刪除此分類記錄，資料夾及內容會保留。請再次確認。';

  @override
  String get localGallery_confirmDelete => '確認刪除';

  @override
  String get localGallery_confirmMoveImageTitle => '保護模式：確認移動圖片';

  @override
  String get localGallery_confirmMoveImageContent => '將把圖片移動到目標分類資料夾。請確認不是誤拖拽。';

  @override
  String get localGallery_confirmMove => '確認移動';

  @override
  String get localGallery_imageMovedToCategory => '圖片已移動到分類';

  @override
  String get localGallery_categoriesSynced => '分類已與資料夾同步';

  @override
  String get localGallery_saveDirectoryNotSet => '未設定儲存目錄';

  @override
  String get localGallery_folderNotFound => '資料夾不存在';

  @override
  String localGallery_openFolderFailed(Object error) {
    return '開啟資料夾失敗: $error';
  }

  @override
  String get localGallery_protectedDeleteTitle => '保護模式：再次確認刪除';

  @override
  String localGallery_protectedDeleteImagesContent(Object count) {
    return '將永久刪除 $count 張本地圖片檔案。此操作無法撤銷。';
  }

  @override
  String get localGallery_protectedBulkMoveTitle => '保護模式：確認批次移動';

  @override
  String localGallery_protectedBulkMoveContent(Object count) {
    return '將移動 $count 張本地圖片檔案到目標分類。請確認不是誤操作。';
  }

  @override
  String localGallery_importParamsFailed(Object error) {
    return '匯入引數失敗: $error';
  }

  @override
  String localGallery_protectedDeleteImageContent(Object name) {
    return '將永久刪除圖片「$name」。此操作無法撤銷。';
  }

  @override
  String get localGallery_saveZipArchive => '儲存壓縮包';

  @override
  String get localGallery_zipMetadataTitle => '匯出 ZIP 壓縮包';

  @override
  String get localGallery_zipMetadataDescription =>
      '選擇壓縮包內的圖片是否保留內嵌後設資料。原始圖片檔案不會被修改。';

  @override
  String get localGallery_zipIncludeMetadata => '保留後設資料';

  @override
  String get localGallery_zipIncludeMetadataDescription => '直接打包原始圖片，不變更圖片內容。';

  @override
  String get localGallery_zipExcludeMetadata => '移除全部後設資料';

  @override
  String get localGallery_zipExcludeMetadataDescription =>
      '僅為壓縮包產生淨化副本，清除 PNG 文字區塊、EXIF 和 NovelAI 隱寫浮水印資料。';

  @override
  String bulkMetadataEdit_title(Object count) {
    return '批次編輯 $count 張圖片的標籤';
  }

  @override
  String get bulkMetadataEdit_tagsToAdd => '要新增的標籤';

  @override
  String get bulkMetadataEdit_tagsToAddHint => '輸入要新增的標籤...';

  @override
  String get bulkMetadataEdit_tagsToRemove => '要移除的標籤';

  @override
  String get bulkMetadataEdit_tagsToRemoveHint => '輸入要移除的標籤...';

  @override
  String get bulkMetadataEdit_noChanges => '請至少新增一個要新增或移除的標籤';

  @override
  String localGallery_packingImages(Object count) {
    return '正在打包 $count 張圖片...';
  }

  @override
  String localGallery_packedImages(Object count) {
    return '已打包 $count 張圖片';
  }

  @override
  String localGallery_packingProgress(Object current, Object total) {
    return '正在打包第 $current/$total 張圖片...';
  }

  @override
  String get localGallery_packPartialTitle => '部分圖片未匯出';

  @override
  String localGallery_packedImagesWithFailures(Object exported, Object failed) {
    return '壓縮包已產生：成功加入 $exported 張，$failed 張未能加入';
  }

  @override
  String get localGallery_packFailed => '打包失敗';

  @override
  String localGallery_packFailedWithDetails(Object error) {
    return '建立壓縮包失敗：$error';
  }

  @override
  String get localGallery_packAlreadyInProgress => '已有圖片壓縮包正在匯出';

  @override
  String get localGallery_imageFileMissing => '圖片檔案不存在';

  @override
  String get localGallery_sentToImageToImage => '圖片已傳送到圖生圖';

  @override
  String localGallery_sendFailed(Object error) {
    return '傳送失敗: $error';
  }

  @override
  String get localGallery_sentToReversePrompt => '圖片已傳送到反推模組';

  @override
  String localGallery_sendToKritaFailed(Object error) {
    return '傳送到 Krita 失敗: $error';
  }

  @override
  String get localGallery_sendToImg2Img => '傳送到圖生圖';

  @override
  String get localGallery_moreImageActions => '更多圖片操作';

  @override
  String get localGallery_sendToReversePrompt => '傳送到反推';

  @override
  String get localGallery_sendToStyleTransfer => '傳送到風格遷移';

  @override
  String get localGallery_sendToPreciseReference => '傳送到精準參考';

  @override
  String get localGallery_sendToKrita => '傳送到 Krita';

  @override
  String get localGallery_importImageMetadata => '匯入圖片後設資料';

  @override
  String get localGallery_copyPrompt => '複製 Prompt';

  @override
  String get localGallery_copySeed => '複製 Seed';

  @override
  String get localGallery_dragToShare => '拖拽以分享';

  @override
  String get localGallery_moveToRoot => '移至根目錄';

  @override
  String get localGallery_cachingMetadata => '正在快取後設資料...';

  @override
  String get localGallery_metadataCacheStats => '後設資料快取統計';

  @override
  String get localGallery_totalImages => '總圖片';

  @override
  String get localGallery_withMetadata => '有後設資料';

  @override
  String get localGallery_skipped => '跳過';

  @override
  String get localGallery_remaining => '剩餘';

  @override
  String get localGallery_clearFilters => '清除篩選';

  @override
  String get slideshow_of => '/';

  @override
  String get slideshow_play => '播放';

  @override
  String get slideshow_pause => '暫停';

  @override
  String get slideshow_previous => '上一張';

  @override
  String get slideshow_next => '下一張';

  @override
  String get slideshow_exit => '退出 (Esc)';

  @override
  String get slideshow_noImages => '沒有可顯示的圖片';

  @override
  String get slideshow_keyboardHint => '使用 ← → 導航，空格鍵播放/暫停，Esc 退出';

  @override
  String get comparison_noImages => '沒有可顯示的圖片';

  @override
  String get comparison_tooManyImages => '圖片數量過多';

  @override
  String get comparison_maxImages => '最多支援對比4張圖片';

  @override
  String get comparison_close => '關閉對比';

  @override
  String get comparison_zoomHint => '捏合或滾動可獨立縮放';

  @override
  String get comparison_loadError => '載入圖片失敗';

  @override
  String get statistics_title => '統計儀表盤';

  @override
  String get statistics_noData => '暫無統計資料';

  @override
  String get statistics_noTagData => '暫無標籤資料';

  @override
  String get statistics_generateFirst => '先生成一些圖片吧';

  @override
  String get statistics_totalImages => '總圖片數';

  @override
  String get statistics_totalSize => '總大小';

  @override
  String get statistics_favorites => '收藏';

  @override
  String get statistics_samplerDistribution => '取樣器分佈';

  @override
  String get statistics_additionalStats => '其他統計';

  @override
  String get statistics_averageFileSize => '平均檔案大小';

  @override
  String get statistics_withMetadata => '有後設資料的圖片';

  @override
  String get statistics_justNow => '剛剛';

  @override
  String statistics_minutesAgo(Object count) {
    return '$count 分鐘前';
  }

  @override
  String statistics_hoursAgo(Object count) {
    return '$count 小時前';
  }

  @override
  String statistics_daysAgo(Object count) {
    return '$count 天前';
  }

  @override
  String get statistics_anlasCost => '點數消耗';

  @override
  String get statistics_totalAnlasCost => '總消耗';

  @override
  String get statistics_avgDailyCost => '日均消耗';

  @override
  String get statistics_noAnlasData => '暫無點數消耗資料';

  @override
  String get statistics_noAnlasInPeriod => '該週期暫無點數消耗';

  @override
  String get statistics_periodSelectorTooltip => '選擇統計週期';

  @override
  String get statistics_periodWeek => '近一週';

  @override
  String get statistics_periodMonth => '近一個月';

  @override
  String get statistics_periodThreeMonths => '近三個月';

  @override
  String get statistics_periodYear => '近一年';

  @override
  String get statistics_periodAll => '全部';

  @override
  String get statistics_periodCustom => '自訂天數';

  @override
  String statistics_periodDays(int count) {
    return '最近 $count 天';
  }

  @override
  String statistics_periodSummary(String start, String end, int count) {
    return '$start 至 $end · $count 天';
  }

  @override
  String statistics_partialCoverage(String date, int count) {
    return '現有記錄始於 $date，日均按現有 $count 天計算';
  }

  @override
  String get statistics_customPeriodTitle => '自訂統計週期';

  @override
  String get statistics_customDaysHint => '統計天數';

  @override
  String statistics_customDaysError(int max) {
    return '請輸入 1 至 $max 之間的整數';
  }

  @override
  String get statistics_daysUnit => '天';

  @override
  String get statistics_peakActivity => '活躍高峰';

  @override
  String get statistics_timeMorning => '上午';

  @override
  String get statistics_timeAfternoon => '下午';

  @override
  String get statistics_timeEvening => '傍晚';

  @override
  String get statistics_timeNight => '深夜';

  @override
  String get localGallery_advancedFilters => '高階篩選';

  @override
  String get localGallery_filterByModel => '按模型篩選';

  @override
  String get localGallery_filterBySampler => '按取樣器篩選';

  @override
  String get localGallery_filterBySteps => '按步數篩選';

  @override
  String get localGallery_filterByCfg => '按 CFG 篩選';

  @override
  String get localGallery_filterByResolution => '按解析度篩選';

  @override
  String get localGallery_filterSubtitle => '精確篩選您的圖片集合';

  @override
  String get localGallery_modelHint => '輸入模型名稱...';

  @override
  String get localGallery_samplerHint => '輸入取樣器名稱...';

  @override
  String get localGallery_resolutionHint => '寬度x高度 (如: 1024x1024)';

  @override
  String get localGallery_activeFiltersSet => '已設定篩選';

  @override
  String get localGallery_applyFilters => '應用篩選';

  @override
  String get localGallery_resetAdvancedFilters => '重置高階篩選';

  @override
  String get bulkExport_format => '匯出格式';

  @override
  String get bulkExport_jsonFormat => 'JSON';

  @override
  String get bulkExport_csvFormat => 'CSV';

  @override
  String get localGallery_group_today => '今天';

  @override
  String get localGallery_group_yesterday => '昨天';

  @override
  String get localGallery_group_thisWeek => '本週';

  @override
  String get localGallery_group_earlier => '更早';

  @override
  String localGallery_cannotOpenFolder(Object error) {
    return '無法開啟資料夾: $error';
  }

  @override
  String get localGallery_permissionRequiredTitle => '需要儲存許可權';

  @override
  String get localGallery_permissionRequiredContent =>
      '本地畫廊需要訪問儲存許可權才能掃描您生成的圖片。\n\n請在設定中授予許可權後重試。';

  @override
  String get localGallery_openSettings => '開啟設定';

  @override
  String get localGallery_firstTimeTipTitle => '使用提示';

  @override
  String get localGallery_firstTimeTipContent =>
      '右鍵點選（桌面端）或長按（移動端）圖片可以：\n\n• 複製 Prompt\n• 複製 Seed\n• 檢視完整後設資料';

  @override
  String get localGallery_gotIt => '知道了';

  @override
  String get localGallery_undone => '已撤銷';

  @override
  String get localGallery_redone => '已重做';

  @override
  String get localGallery_confirmBulkDelete => '確認批次刪除';

  @override
  String localGallery_confirmBulkDeleteContent(Object count) {
    return '確定要刪除選中的 $count 張圖片嗎？\n\n此操作將從檔案系統中永久刪除這些圖片，無法恢復。';
  }

  @override
  String localGallery_deletedImages(Object count) {
    return '已刪除 $count 張圖片';
  }

  @override
  String get localGallery_noCategoriesAvailable => '暫無可用分類，請先建立分類';

  @override
  String get localGallery_moveToCategory => '移動到分類';

  @override
  String get localGallery_albumSectionTitle => '相簿';

  @override
  String get localGallery_folderSectionTitle => '資料夾';

  @override
  String get localGallery_albumEmptyHint => '還沒有相簿，點擊右側按鈕建立';

  @override
  String get localGallery_createAlbum => '新建相簿';

  @override
  String get localGallery_createSubAlbum => '新建子相簿';

  @override
  String get localGallery_moveAlbumToRoot => '移到根級';

  @override
  String get localGallery_moveAlbumUp => '移到上一級';

  @override
  String get localGallery_moveCategoryUp => '移到上一級';

  @override
  String get localGallery_createAlbumTitle => '新建相簿';

  @override
  String get localGallery_createSubAlbumTitle => '新建子相簿';

  @override
  String get localGallery_createAlbumHint => '輸入相簿名稱';

  @override
  String get localGallery_deleteAlbumTitle => '刪除相簿';

  @override
  String get localGallery_deleteAlbumContent => '將刪除該相簿（圖片檔案不受影響），子相簿會提升到根級。';

  @override
  String get localGallery_addedToAlbum => '已加入相簿';

  @override
  String get localGallery_albumAddFailed => '加入相簿失敗';

  @override
  String get localGallery_albumSelectTitle => '加入相簿';

  @override
  String get localGallery_addToAlbum => '加入相簿';

  @override
  String get localGallery_removeFromAlbum => '移出相簿';

  @override
  String localGallery_removedFromAlbum(Object count) {
    return '已移出 $count 張圖片';
  }

  @override
  String get localGallery_albumNoMembers => '所選圖片不在此相簿中';

  @override
  String localGallery_addedToAlbumWithName(Object count, Object name) {
    return '已將 $count 張圖片加入「$name」';
  }

  @override
  String localGallery_imageCount(Object count) {
    return '$count 張圖片';
  }

  @override
  String localGallery_movedImages(Object count) {
    return '已移動 $count 張圖片';
  }

  @override
  String get localGallery_moveImagesFailed => '移動圖片失敗';

  @override
  String get brushPreset_selectHint => '雙擊選擇此筆刷預設';

  @override
  String get brushPreset_pencil => '鉛筆';

  @override
  String get brushPreset_fine => '細筆';

  @override
  String get brushPreset_standard => '標準筆刷';

  @override
  String get brushPreset_soft => '軟筆刷';

  @override
  String get brushPreset_airbrush => '噴槍';

  @override
  String get brushPreset_marker => '馬克筆';

  @override
  String get brushPreset_thick => '粗筆刷';

  @override
  String get brushPreset_smudge => '塗抹筆刷';

  @override
  String bulkProgress_progress(Object current, Object total) {
    return '正在處理 $current/$total';
  }

  @override
  String bulkProgress_success(Object count) {
    return '$count 項成功';
  }

  @override
  String bulkProgress_failed(Object count) {
    return '$count 項失敗';
  }

  @override
  String get bulkProgress_errors => '錯誤：';

  @override
  String bulkProgress_moreErrors(Object count) {
    return '...還有 $count 個錯誤';
  }

  @override
  String bulkProgress_completed(Object count) {
    return '已完成 $count 項';
  }

  @override
  String bulkProgress_completedWithErrors(Object success, Object failed) {
    return '$success 項成功，$failed 項失敗';
  }

  @override
  String get bulkProgress_title_delete => '刪除圖片中';

  @override
  String get bulkProgress_title_export => '匯出後設資料中';

  @override
  String get bulkProgress_title_metadataEdit => '編輯後設資料中';

  @override
  String get bulkProgress_title_addToCollection => '新增到收集中';

  @override
  String get bulkProgress_title_removeFromCollection => '從集合中移除';

  @override
  String get bulkProgress_title_toggleFavorite => '更新收藏中';

  @override
  String get bulkProgress_title_default => '處理中';

  @override
  String get bulkProgress_continueInBackground => '轉到背景繼續';

  @override
  String get bulkProgress_operationAlreadyInProgress => '已有批次操作正在進行';

  @override
  String bulkProgress_errorDeleteFailed(String error) {
    return '刪除圖片失敗：$error';
  }

  @override
  String get bulkProgress_errorNoImagesToExport => '沒有可匯出的圖片';

  @override
  String get bulkProgress_errorExportFailed => '匯出失敗';

  @override
  String bulkProgress_errorExportFailedWithDetails(String error) {
    return '匯出失敗：$error';
  }

  @override
  String get bulkProgress_errorNoMetadataChanges => '請至少輸入一個要新增或移除的標籤';

  @override
  String bulkProgress_errorMetadataEditFailed(String error) {
    return '編輯圖片後設資料失敗：$error';
  }

  @override
  String bulkProgress_errorFavoriteFailed(String error) {
    return '更新收藏狀態失敗：$error';
  }

  @override
  String get bulkProgress_errorNoImagesForCollection => '沒有可新增到集合的圖片';

  @override
  String bulkProgress_errorAddToCollectionFailed(String error) {
    return '將圖片新增到集合失敗：$error';
  }

  @override
  String get bulkProgress_errorNothingToUndo => '沒有可撤銷的操作';

  @override
  String bulkProgress_errorUndoFailed(String error) {
    return '撤銷失敗：$error';
  }

  @override
  String get bulkProgress_errorNothingToRedo => '沒有可重做的操作';

  @override
  String bulkProgress_errorRedoFailed(String error) {
    return '重做失敗：$error';
  }

  @override
  String get collectionSelect_dialogTitle => '選擇集合';

  @override
  String get collectionSelect_filterHint => '搜尋集合...';

  @override
  String get collectionSelect_noCollections => '暫無集合';

  @override
  String get collectionSelect_createCollectionHint => '請先建立一個集合';

  @override
  String get collectionSelect_noFilterResults => '沒有找到匹配的集合';

  @override
  String collectionSelect_imageCount(int count) {
    return '$count 張圖片';
  }

  @override
  String get statistics_chartTopTags => '熱門標籤';

  @override
  String get statistics_chartAspectRatio => '寬高比分佈';

  @override
  String get statistics_chartActivityHeatmap => '活動熱力圖';

  @override
  String get statistics_chartHourlyDistribution => '小時分佈';

  @override
  String get statistics_chartWeekdayDistribution => '星期分佈';

  @override
  String get statistics_aspectSquare => '方形';

  @override
  String get statistics_aspectLandscape => '橫屏';

  @override
  String get statistics_aspectPortrait => '豎屏';

  @override
  String get statistics_aspectOther => '其他';

  @override
  String get statistics_refresh => '重新整理';

  @override
  String get statistics_retry => '重試';

  @override
  String statistics_error(Object error) {
    return '錯誤: $error';
  }

  @override
  String get statistics_mostActiveDay => '最活躍日';

  @override
  String get statistics_leastActiveDay => '最不活躍日';

  @override
  String get statistics_sunday => '週日';

  @override
  String get statistics_monday => '週一';

  @override
  String get statistics_tuesday => '週二';

  @override
  String get statistics_wednesday => '週三';

  @override
  String get statistics_thursday => '週四';

  @override
  String get statistics_friday => '週五';

  @override
  String get statistics_saturday => '週六';

  @override
  String get fixedTags_label => '固定詞';

  @override
  String get fixedTags_enabled => '已啟用';

  @override
  String get fixedTags_empty => '暫無固定詞';

  @override
  String get fixedTags_emptyHint => '點選下方按鈕新增固定詞，它們會自動應用到你的提示詞中';

  @override
  String get fixedTags_manage => '管理固定詞';

  @override
  String get fixedTags_add => '新增';

  @override
  String get fixedTags_edit => '編輯固定詞';

  @override
  String get fixedTags_openLibrary => '開啟詞庫';

  @override
  String get fixedTags_prefix => '字首';

  @override
  String get fixedTags_suffix => '字尾';

  @override
  String get fixedTags_disabled => '已禁用';

  @override
  String get fixedTags_weight => '權重';

  @override
  String get fixedTags_position => '位置';

  @override
  String get fixedTags_name => '名稱';

  @override
  String get fixedTags_nameHint => '輸入備註名稱（可選）';

  @override
  String get fixedTags_content => '內容';

  @override
  String get fixedTags_contentHint => '輸入提示詞內容，支援 NAI 語法';

  @override
  String get fixedTags_syntaxHelp => '支援 NAI 語法增強/減弱權重、標籤交替等';

  @override
  String get fixedTags_linkedFromLibrary => '關聯自詞庫（雙向同步）';

  @override
  String get fixedTags_scope => '作用範圍';

  @override
  String get fixedTags_positive => '正向';

  @override
  String get fixedTags_negative => '負向';

  @override
  String get fixedTags_resetWeight => '重置為 1.0';

  @override
  String get fixedTags_weightPreview => '權重預覽:';

  @override
  String get fixedTags_deleteTitle => '刪除固定詞';

  @override
  String fixedTags_deleteConfirm(Object name) {
    return '確定要刪除固定詞 \"$name\" 嗎？';
  }

  @override
  String fixedTags_enabledCount(Object enabled, Object total) {
    return '$enabled/$total 已啟用';
  }

  @override
  String get fixedTags_saveToLibrary => '同時儲存到詞庫';

  @override
  String get fixedTags_saveToLibraryHint => '方便日後在詞庫中重複使用';

  @override
  String get fixedTags_saveToCategory => '儲存到類別';

  @override
  String get fixedTags_clearAll => '清空';

  @override
  String get fixedTags_clearAllTitle => '清空所有固定詞';

  @override
  String fixedTags_clearAllConfirm(Object count) {
    return '確定要清空所有 $count 個固定詞嗎？此操作不可撤銷。';
  }

  @override
  String get fixedTags_clearedSuccess => '已清空所有固定詞';

  @override
  String get fixedTags_sidebarTitle => '固定詞側欄';

  @override
  String get fixedTags_switchGridView => '切換網格檢視';

  @override
  String get fixedTags_switchListView => '切換列表檢視';

  @override
  String get fixedTags_addPositive => '新增正向固定詞';

  @override
  String get fixedTags_addNegative => '新增負向固定詞';

  @override
  String get fixedTags_addPositiveFromLibrary => '從詞庫新增正向';

  @override
  String get fixedTags_addNegativeFromLibrary => '從詞庫新增負向';

  @override
  String get fixedTags_searchNameOrContent => '搜尋名稱或內容';

  @override
  String get fixedTags_clearSearch => '清空搜尋';

  @override
  String get fixedTags_enabledPositive => '已啟用正向';

  @override
  String get fixedTags_emptyEnabledPositive => '暫無啟用的正向固定詞';

  @override
  String get fixedTags_noMatchingEnabled => '沒有匹配的啟用固定詞';

  @override
  String get fixedTags_negativeTitle => '負向固定詞';

  @override
  String get fixedTags_emptyNegative => '暫無負向固定詞';

  @override
  String get fixedTags_noMatchingNegative => '沒有匹配的負向固定詞';

  @override
  String get fixedTags_addedToSidebar => '已新增到固定詞側欄';

  @override
  String get fixedTags_unknownCategory => '未知分類';

  @override
  String get fixedTags_uncategorized => '未分類';

  @override
  String get fixedTags_clickManageLongPressSidebar => '點選管理，長按開啟側欄';

  @override
  String get fixedTags_clickManageLongPressCompact => '點選管理，長按側欄';

  @override
  String get fixedTags_linked => '聯動';

  @override
  String fixedTags_linkCount(Object count) {
    return '$count 個聯動';
  }

  @override
  String get fixedTags_expandNegative => '展開負向';

  @override
  String get fixedTags_collapseNegative => '收起負向';

  @override
  String get fixedTags_undoTooltip => '撤銷固定詞操作';

  @override
  String get fixedTags_redoTooltip => '重做固定詞操作';

  @override
  String get fixedTags_positiveTitle => '正向固定詞';

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
    return '$enabled/$total · 顯示 $shown';
  }

  @override
  String get fixedTags_new => '新建';

  @override
  String fixedTags_newTarget(Object target) {
    return '新建$target';
  }

  @override
  String get fixedTags_library => '詞庫';

  @override
  String fixedTags_addFromLibraryToTarget(Object target) {
    return '從詞庫新增到$target';
  }

  @override
  String get fixedTags_enableAll => '全開';

  @override
  String get fixedTags_disableAll => '全關';

  @override
  String fixedTags_searchTarget(Object target) {
    return '搜尋 $target...';
  }

  @override
  String get fixedTags_noMatching => '無匹配固定詞';

  @override
  String fixedTags_emptyTarget(Object target) {
    return '暫無$target';
  }

  @override
  String get fixedTags_dragToLink => '拖拽建立聯動';

  @override
  String fixedTags_linkedToNames(Object names) {
    return '已聯動：$names';
  }

  @override
  String get fixedTags_linkInstruction => '拖拽正向固定詞的關聯圖示到負向固定詞即可建立聯動';

  @override
  String get fixedTags_manageLinks => '管理聯動';

  @override
  String fixedTags_removeLink(Object name) {
    return '取消聯動：$name';
  }

  @override
  String get fixedTags_footerExpandedHint => '在各列頂部新建或從詞庫新增';

  @override
  String get fixedTags_newPositive => '新建正向';

  @override
  String get fixedTags_addPositiveFromLibraryShort => '詞庫新增正向';

  @override
  String get fixedTags_libraryEmpty => '詞庫為空，請先新增條目';

  @override
  String get fixedTags_addFromLibrary => '從詞庫新增';

  @override
  String get fixedTags_searchLibraryEntries => '搜尋詞庫條目...';

  @override
  String get fixedTags_noMatchingResults => '無匹配結果';

  @override
  String get reversePrompt_title => '反推';

  @override
  String reversePrompt_imageCount(Object count) {
    return '$count 張';
  }

  @override
  String get reversePrompt_llmReverse => 'LLM 反推';

  @override
  String get reversePrompt_characterReplace => '角色替換';

  @override
  String get reversePrompt_finalResult => '最終結果';

  @override
  String get reversePrompt_dropToAdd => '鬆開後新增到反推';

  @override
  String get reversePrompt_addOrDropImages => '增加圖片 / 拖入圖片';

  @override
  String get reversePrompt_localTaggerModel => '本地 tagger 模型';

  @override
  String get reversePrompt_localTaggerModelHint => '請在設定中配置模型資料夾';

  @override
  String get reversePrompt_generalThreshold => '通用標籤閾值';

  @override
  String get reversePrompt_characterThreshold => '角色標籤閾值';

  @override
  String get reversePrompt_taggerFilterHint =>
      '只輸出 General / Character 分類標籤；Rating、Artist、Copyright、Meta 等分類會被過濾。';

  @override
  String get reversePrompt_replacementEmptyHint =>
      '替換目標角色為空。這裡從詞庫選擇一個角色作為替換目標，不會注入到正向提示詞。';

  @override
  String get reversePrompt_selectReplacementCharacter => '從詞庫選擇替換目標角色';

  @override
  String get reversePrompt_selectReplacementTargetTitle => '選擇替換目標角色';

  @override
  String get reversePrompt_change => '更換';

  @override
  String get reversePrompt_start => '開始反推';

  @override
  String get reversePrompt_sentToPrompt => '已傳送到提示詞';

  @override
  String get reversePrompt_sendToPrompt => '傳送到提示詞';

  @override
  String get reversePrompt_externalTarget => '多模態 LLM 反推服務';

  @override
  String get reversePrompt_dropUnreadable => '拖入源未提供可讀取的圖片檔案或圖片連結';

  @override
  String get reversePrompt_needImageAndMethod =>
      '請先新增圖片，並至少啟用 ONNX tagger 或 LLM 反推';

  @override
  String get reversePrompt_stagePreparing => '準備反推';

  @override
  String get reversePrompt_stageOnnxTagger => 'ONNX tagger 反推中';

  @override
  String get reversePrompt_stageLlmReverse => 'LLM 讀圖反推中';

  @override
  String get reversePrompt_stageCharacterReplace => '角色替換中';

  @override
  String get reversePrompt_needReplacementCharacter => '請先在反推角色庫中選擇一個有效角色';

  @override
  String get reversePrompt_needPromptForCharacterReplace => '角色替換需要先獲得反推提示詞';

  @override
  String get reversePrompt_noOnnxModel => '未找到 ONNX tagger 模型，請先在設定中配置模型資料夾';

  @override
  String get promptAssistant_translateProcessing => '翻譯中';

  @override
  String get promptAssistant_optimizeProcessing => '最佳化中';

  @override
  String get promptAssistant_characterReplaceProcessing => '角色替換中';

  @override
  String get promptAssistant_customProcessing => '自定義處理中';

  @override
  String get promptAssistant_imageInputDisabled => '當前自定義任務服務商未啟用圖片輸入';

  @override
  String get promptAssistant_needCharacter => '請先在反推角色庫中新增有效角色';

  @override
  String get promptAssistant_assistantSettings => '助手設定';

  @override
  String get promptAssistant_serviceSettings => '服務設定';

  @override
  String get promptAssistant_ruleSettings => '規則設定';

  @override
  String get promptAssistant_cancelCurrentTask => '取消當前任務';

  @override
  String get promptAssistant_collapseAssistant => '收起助手';

  @override
  String get promptAssistant_expandAssistant => '展開助手';

  @override
  String get promptAssistant_assistant => '助手';

  @override
  String get promptAssistant_history => '歷史';

  @override
  String get promptAssistant_undo => '撤銷';

  @override
  String get promptAssistant_redo => '重做';

  @override
  String get promptAssistant_translate => '翻譯';

  @override
  String get promptAssistant_optimize => '最佳化';

  @override
  String get promptAssistant_custom => '自定義';

  @override
  String get promptAssistant_characterReplace => '角色替換';

  @override
  String get promptAssistant_cancelTask => '取消任務';

  @override
  String get promptAssistant_menu => '選單';

  @override
  String get promptAssistant_customDialogTitle => '自定義提示詞助手';

  @override
  String get promptAssistant_currentPrompt => '當前提示詞';

  @override
  String get promptAssistant_currentPromptEmpty => '（當前提示詞為空）';

  @override
  String get promptAssistant_customRequestLabel => '你的修改需求';

  @override
  String get promptAssistant_customRequestHint =>
      '例如：更陰森、增加雨夜街道背景、讓動作更有張力，只返回最終提示詞';

  @override
  String get promptAssistant_addReferenceImage => '新增參考圖';

  @override
  String get promptAssistant_execute => '執行';

  @override
  String promptAssistant_maxReferenceImages(Object count) {
    return '最多新增 $count 張參考圖片';
  }

  @override
  String promptAssistant_unsupportedImageFormat(Object fileName) {
    return '不支援的圖片格式: $fileName';
  }

  @override
  String get promptAssistant_needCustomRequestOrImage => '請輸入自定義需求或新增參考圖片';

  @override
  String get promptAssistant_taskOptimize => '最佳化';

  @override
  String get promptAssistant_taskTranslate => '翻譯';

  @override
  String get promptAssistant_taskReverse => '反推';

  @override
  String get promptAssistant_taskCharacterReplace => '角色替換';

  @override
  String get promptAssistant_taskCustom => '自定義';

  @override
  String get promptAssistant_settingsInputSwitchSubtitle => '輸入框右下角助手開關';

  @override
  String get promptAssistant_desktopOverlayTitle => '桌面浮層互動';

  @override
  String get promptAssistant_desktopOverlaySubtitle => '啟用 hover / 右鍵 / 快捷鍵行為';

  @override
  String get promptAssistant_webAccessTitle => 'Agent 聯網';

  @override
  String get promptAssistant_webAccessSubtitle => '透過 SearXNG 或 Exa 搜尋即時資訊';

  @override
  String get promptAssistant_webAccessEnable => '允許 Agent 聯網';

  @override
  String get promptAssistant_webAccessEnableSubtitle => '啟用後，搜尋和讀取公網網頁不再逐次確認';

  @override
  String get promptAssistant_webAccessBackend => '搜尋後端';

  @override
  String get promptAssistant_webAccessBackendAuto => '自動';

  @override
  String get promptAssistant_webAccessBackendSearxng => 'SearXNG';

  @override
  String get promptAssistant_webAccessBackendExaMcp => 'Exa 免費 MCP';

  @override
  String get promptAssistant_webAccessBackendExaApi => 'Exa API';

  @override
  String get promptAssistant_webAccessBackendAutoDescription =>
      '優先使用已設定的 SearXNG，失敗後回退到 Exa 匿名 MCP 額度';

  @override
  String get promptAssistant_webAccessBackendSearxngDescription =>
      '僅使用設定的私有 SearXNG 實例';

  @override
  String get promptAssistant_webAccessBackendExaMcpDescription =>
      '無需 API Key，使用 Exa 託管的免費額度並受其限流約束';

  @override
  String get promptAssistant_webAccessBackendExaApiDescription =>
      '使用你的 Exa 帳號與 API 額度，此模式可能產生費用';

  @override
  String get promptAssistant_webAccessResultCount => '預設結果數';

  @override
  String get promptAssistant_webAccessSearxngUrl => 'SearXNG 位址';

  @override
  String get promptAssistant_webAccessExaApiKey => 'Exa API Key';

  @override
  String get promptAssistant_webAccessApiKeyConfigured => '已安全儲存';

  @override
  String get promptAssistant_webAccessApiKeyMissing => '未設定';

  @override
  String get promptAssistant_webAccessConfigureKey => '設定';

  @override
  String get promptAssistant_webAccessClearKey => '清除 Key';

  @override
  String get promptAssistant_webAccessTestConnection => '測試連線';

  @override
  String get promptAssistant_webAccessTesting => '正在測試...';

  @override
  String promptAssistant_webAccessTestSucceeded(Object provider) {
    return '已透過 $provider 連線';
  }

  @override
  String promptAssistant_webAccessTestFailed(Object error) {
    return '連線失敗：$error';
  }

  @override
  String get promptAssistant_taskRouting => '任務路由';

  @override
  String get promptAssistant_taskRoutingSubtitle => '最佳化、翻譯、反推、角色替換可繫結不同服務商和模型';

  @override
  String promptAssistant_taskRouteTitle(Object title) {
    return '$title任務';
  }

  @override
  String get promptAssistant_provider => '服務商';

  @override
  String get promptAssistant_model => '模型';

  @override
  String get promptAssistant_noModelsPullFirst => '暫無模型，請先拉取';

  @override
  String get promptAssistant_providerManagement => '服務商管理';

  @override
  String get promptAssistant_providerManagementSubtitle =>
      '支援 OpenAI Chat / Responses、Anthropic、Gemini、DeepSeek、LM Studio、Ollama、Pollinations 和自定義相容端點';

  @override
  String get promptAssistant_apiKeyConfigured => 'API Key: 已配置';

  @override
  String get promptAssistant_apiKeyNotConfigured => 'API Key: 未配置';

  @override
  String get promptAssistant_supportsImageInput => '支援圖片輸入';

  @override
  String get promptAssistant_textOnly => '僅文字';

  @override
  String get promptAssistant_connectionConfig => '連線配置';

  @override
  String get promptAssistant_pullModelList => '拉取模型列表';

  @override
  String get promptAssistant_editProvider => '編輯服務商';

  @override
  String get promptAssistant_deleteProvider => '刪除服務商';

  @override
  String get promptAssistant_pullingModels => '正在拉取模型列表...';

  @override
  String get promptAssistant_emptyModelList => '服務返回空模型列表';

  @override
  String promptAssistant_modelsSynced(Object count) {
    return '已同步 $count 個模型';
  }

  @override
  String promptAssistant_pullModelsFailed(Object error) {
    return '拉取模型失敗: $error';
  }

  @override
  String get promptAssistant_ruleTemplates => '規則模板';

  @override
  String get promptAssistant_ruleTemplatesSubtitle =>
      '系統提示詞按“規則 + 使用者輸入 + 任務引數”組裝';

  @override
  String get promptAssistant_addRule => '新增規則';

  @override
  String get promptAssistant_addProvider => '新增服務商';

  @override
  String get promptAssistant_editProviderTitle => '編輯服務商';

  @override
  String get promptAssistant_name => '名稱';

  @override
  String get promptAssistant_protocol => '協議';

  @override
  String get promptAssistant_allowImageInput => '允許傳送圖片輸入';

  @override
  String get promptAssistant_allowImageInputSubtitle => '僅在模型和服務商實際支援視覺輸入時啟用';

  @override
  String get promptAssistant_apiKeyLeaveEmpty => 'API Key (留空不改)';

  @override
  String promptAssistant_connectionTitle(Object name) {
    return '$name 連線配置';
  }

  @override
  String get promptAssistant_baseUrlHint => '例如: https://api.openai.com/v1';

  @override
  String get promptAssistant_clearCurrentApiKey => '清空當前 API Key';

  @override
  String get promptAssistant_protocolSupportsImagePayload =>
      '當前協議支援圖片載荷，仍需模型本身支援視覺輸入';

  @override
  String get promptAssistant_protocolTextOnlyWarning =>
      '當前協議預設僅文字，開啟後也可能被服務端拒絕';

  @override
  String get promptAssistant_addRuleTitle => '新增規則';

  @override
  String get promptAssistant_editRuleTitle => '編輯規則';

  @override
  String get promptAssistant_taskType => '任務型別';

  @override
  String get promptAssistant_ruleContent => '規則內容';

  @override
  String get promptAssistant_newRule => '新規則';

  @override
  String autocomplete_resultsCount(Object count) {
    return '$count 個結果';
  }

  @override
  String get autocomplete_actionSelect => '選擇';

  @override
  String get autocomplete_actionConfirm => '確認';

  @override
  String get autocomplete_actionClose => '關閉';

  @override
  String get autocomplete_categoryCharacter => '角色';

  @override
  String get autocomplete_categoryCopyright => '版權';

  @override
  String get autocomplete_categoryArtist => '藝術家';

  @override
  String get autocomplete_categoryMeta => '後設資料';

  @override
  String get autocomplete_categoryContributor => '貢獻者';

  @override
  String get autocomplete_categorySpecies => '物種';

  @override
  String get autocomplete_categoryLore => '設定';

  @override
  String get autocomplete_categoryLibrary => '詞庫';

  @override
  String get autocomplete_categoryGeneral => '通用';

  @override
  String get promptToken_webCalibration => '網頁端校準';

  @override
  String get promptToken_prompt => '提示詞';

  @override
  String get promptToken_fixedTags => '固定詞';

  @override
  String get promptToken_qualityPreset => '質量預設';

  @override
  String get promptToken_character => '角色';

  @override
  String get promptToken_negativePrompt => '負面提示詞';

  @override
  String get promptToken_negativeFixedTags => '負面固定詞';

  @override
  String get promptToken_negativePreset => '負面預設';

  @override
  String get promptToken_characterNegative => '角色負面';

  @override
  String get common_rename => '重新命名';

  @override
  String get common_create => '建立';

  @override
  String get tagLibrary_categories => '分類';

  @override
  String get tagLibrary_newCategory => '新建分類';

  @override
  String get tagLibrary_addEntry => '新增條目';

  @override
  String get tagLibrary_editEntry => '編輯條目';

  @override
  String get tagLibrary_searchHint => '搜尋條目...';

  @override
  String get tagLibrary_import => '匯入';

  @override
  String get tagLibrary_export => '匯出';

  @override
  String get tagLibrary_sortCustom => '自定義排序';

  @override
  String get tagLibrary_sortName => '名稱';

  @override
  String get tagLibrary_sortUseCount => '使用頻率';

  @override
  String get tagLibrary_sortUpdatedAt => '更新時間';

  @override
  String get tagLibrary_transferCategory => '轉移分類';

  @override
  String get tagLibrary_copyContent => '複製內容';

  @override
  String get tagLibrary_moveToCategoryTitle => '移動到分類';

  @override
  String get tagLibrary_selectTargetCategory => '選擇目標分類：';

  @override
  String get tagLibrary_includeThumbnails => '包含預覽圖';

  @override
  String get tagLibrary_includeThumbnailsSubtitle => '將增加檔案大小';

  @override
  String tagLibrary_selectedExportCount(Object count) {
    return '匯出 ($count 項)';
  }

  @override
  String tagLibrary_selectedImportCount(Object count) {
    return '匯入 ($count 項)';
  }

  @override
  String get tagLibrary_entriesLabel => '條目';

  @override
  String get tagLibrary_categoriesLabel => '分類';

  @override
  String get tagLibrary_selectExportContent => '選擇要匯出的內容';

  @override
  String get tagLibrary_selectImportContent => '選擇要匯入的內容';

  @override
  String get tagLibrary_selectSaveLocation => '選擇儲存位置';

  @override
  String get tagLibrary_preparingExport => '準備匯出...';

  @override
  String get tagLibrary_exportSuccess => '匯出成功';

  @override
  String tagLibrary_exportFailedWithError(Object error) {
    return '匯出失敗: $error';
  }

  @override
  String get tagLibrary_selectZipFile => '點選選擇 ZIP 檔案';

  @override
  String get tagLibrary_zipFileHint => '支援從本應用匯出的詞庫檔案';

  @override
  String get tagLibrary_reselect => '重新選擇';

  @override
  String get tagLibrary_fileInfo => '檔案資訊';

  @override
  String get tagLibrary_entryCountLabel => '條目數';

  @override
  String get tagLibrary_categoryCountLabel => '分類數';

  @override
  String get tagLibrary_exportDateLabel => '匯出時間';

  @override
  String tagLibrary_importConflictsHint(Object count) {
    return '發現 $count 個衝突項，請點選下方衝突項選擇處理方式';
  }

  @override
  String tagLibrary_categoriesSection(Object count) {
    return '分類 ($count)';
  }

  @override
  String tagLibrary_entriesSection(Object count) {
    return '條目 ($count)';
  }

  @override
  String get tagLibrary_conflictResolutionTooltip => '選擇衝突處理方式';

  @override
  String get tagLibrary_conflictSkip => '衝突 - 將跳過';

  @override
  String get tagLibrary_conflictRename => '衝突 - 將重新命名匯入';

  @override
  String get tagLibrary_conflictOverwrite => '衝突 - 將替換現有';

  @override
  String tagLibrary_parseFileFailed(Object error) {
    return '無法解析檔案: $error';
  }

  @override
  String get tagLibrary_preparingImport => '準備匯入...';

  @override
  String get tagLibrary_importCompleted => '匯入完成';

  @override
  String tagLibrary_importSuccessSummary(Object summary) {
    return '匯入成功: $summary';
  }

  @override
  String tagLibrary_importFailedWithError(Object error) {
    return '匯入失敗: $error';
  }

  @override
  String tagLibrary_importedEntriesCount(Object count) {
    return '$count 條目';
  }

  @override
  String tagLibrary_importedCategoriesCount(Object count) {
    return '$count 分類';
  }

  @override
  String tagLibrary_renamedCount(Object count) {
    return '$count 重新命名';
  }

  @override
  String tagLibrary_overwrittenCount(Object count) {
    return '$count 替換';
  }

  @override
  String tagLibrary_skippedCount(Object count) {
    return '$count 跳過';
  }

  @override
  String get tagLibrary_dragToCategoryHint => '拖到左側分類歸檔';

  @override
  String get tagLibrary_unknownCategory => '未知分類';

  @override
  String get tagLibrary_selectEntryToUpdate => '選擇要更新的詞條';

  @override
  String get tagLibrary_updatePreview => '更新預覽圖';

  @override
  String get tagLibrary_replaceThumbnailHint => '將替換現有預覽圖';

  @override
  String tagLibrary_sentEntriesToMainPrompt(Object count) {
    return '已傳送 $count 個詞條到主提示詞';
  }

  @override
  String tagLibrary_confirmDeleteSelectedEntries(Object count) {
    return '確定要刪除選中的 $count 個詞條嗎？此操作不可撤銷。';
  }

  @override
  String tagLibrary_deletedEntries(Object count) {
    return '已刪除 $count 個詞條';
  }

  @override
  String tagLibrary_movedEntries(Object count) {
    return '已移動 $count 個詞條';
  }

  @override
  String tagLibrary_favoritedEntries(Object count) {
    return '已收藏 $count 個詞條';
  }

  @override
  String tagLibrary_unfavoritedEntries(Object count) {
    return '已取消收藏 $count 個詞條';
  }

  @override
  String tagLibrary_copiedEntriesContent(Object count) {
    return '已複製 $count 個詞條的內容';
  }

  @override
  String get tagLibrary_droppedImage => '拖入圖片';

  @override
  String get tagLibrary_createEntryFromImage => '建立新詞條';

  @override
  String tagLibrary_promptExtracted(Object prompt) {
    return '提示詞已提取: \"$prompt\"';
  }

  @override
  String get tagLibrary_createEntryFromImageSubtitle => '從圖片建立新詞條';

  @override
  String get tagLibrary_updateExistingThumbnail => '更新現有詞條預覽圖';

  @override
  String get tagLibrary_updateExistingThumbnailSubtitle => '選擇詞條並替換其預覽圖';

  @override
  String get tagLibrary_allEntries => '全部';

  @override
  String get tagLibrary_favorites => '收藏';

  @override
  String get tagLibrary_addSubCategory => '新增子分類';

  @override
  String get tagLibrary_moveToRoot => '移動到根目錄';

  @override
  String get tagLibrary_categoryNameHint => '輸入分類名稱';

  @override
  String get tagLibrary_deleteCategoryTitle => '刪除分類';

  @override
  String tagLibrary_deleteCategoryConfirm(Object name, Object count) {
    return '確定要刪除分類 \"$name\" 嗎？該分類下的 $count 個條目將移至根目錄。';
  }

  @override
  String get tagLibrary_deleteEntryTitle => '刪除條目';

  @override
  String tagLibrary_deleteEntryConfirm(Object name) {
    return '確定要刪除條目 \"$name\" 嗎？';
  }

  @override
  String get tagLibrary_noSearchResults => '沒有找到匹配的條目';

  @override
  String get tagLibrary_tryDifferentSearch => '嘗試使用其他關鍵詞搜尋';

  @override
  String get tagLibrary_categoryEmpty => '該分類暫無條目';

  @override
  String get tagLibrary_empty => '詞庫為空';

  @override
  String get tagLibrary_addFirstEntry => '點選上方按鈕新增第一個條目';

  @override
  String get tagLibraryPicker_title => '選擇詞條';

  @override
  String get tagLibraryPicker_searchHint => '搜尋詞條...';

  @override
  String get tagLibraryPicker_allCategories => '全部分類';

  @override
  String get tagLibrary_addedToFixed => '已新增到固定詞';

  @override
  String get tagLibrary_entryMoved => '條目已移動到目標分類';

  @override
  String get tagLibrary_addFavorite => '新增收藏';

  @override
  String get tagLibrary_thumbnail => '預覽圖';

  @override
  String get tagLibrary_selectImage => '選擇圖片';

  @override
  String get tagLibrary_thumbnailHint => '支援 PNG、JPG、WEBP、GIF、BMP、TIFF 等格式';

  @override
  String get tagLibrary_name => '名稱';

  @override
  String get tagLibrary_nameHint => '輸入條目名稱';

  @override
  String get tagLibrary_category => '分類';

  @override
  String get tagLibrary_rootCategory => '根目錄';

  @override
  String get tagLibrary_tags => '標籤';

  @override
  String get tagLibrary_tagsHint => '輸入標籤，用逗號分隔';

  @override
  String get tagLibrary_tagsHelper => '標籤用於篩選和搜尋';

  @override
  String get tagLibrary_content => '提示詞內容';

  @override
  String get tagLibrary_contentHint => '輸入提示詞內容，支援智慧補全';

  @override
  String get tagLibrary_characterNegativeSyntaxHelp =>
      '角色詞庫可用 negative(...) 儲存獨立負面提示詞，例如：girl, blue eyes, negative(red hair, glasses)';

  @override
  String get settings_network => '網路';

  @override
  String get settings_enableProxy => '啟用代理';

  @override
  String get settings_proxyEnabled => '已啟用';

  @override
  String get settings_proxyDisabled => '直接連線網路';

  @override
  String get settings_proxyTrafficDisclosure =>
      '代理啟用後，NovelAI API 流量（包括認證請求）會透過系統代理或手動代理傳送。只使用你信任的代理。';

  @override
  String get settings_proxyMode => '代理模式';

  @override
  String get settings_proxyModeAuto => '自動檢測系統代理';

  @override
  String get settings_proxyModeManual => '手動配置';

  @override
  String get settings_auto => '自動';

  @override
  String get settings_manual => '手動';

  @override
  String get settings_proxyHost => '代理地址';

  @override
  String get settings_proxyPort => '埠';

  @override
  String get settings_proxyNotDetected => '未檢測到系統代理';

  @override
  String get settings_testConnection => '測試連線';

  @override
  String get settings_testConnectionHint => '點選測試代理是否可用';

  @override
  String settings_testSuccess(Object latency) {
    return '連線成功 (${latency}ms)';
  }

  @override
  String settings_testFailed(Object error) {
    return '連線失敗: $error';
  }

  @override
  String get settings_proxyRestartHint => '代理設定已更改，建議重啟應用';

  @override
  String get tagLibrary_categoryNameExists => '該分類名稱已存在';

  @override
  String get tagLibrary_addToLibrary => '收藏到詞庫';

  @override
  String get tagLibrary_saveToLibrary => '儲存到詞庫';

  @override
  String get tagLibrary_entrySaved => '收藏成功';

  @override
  String get tagLibrary_entryUpdated => '條目已更新';

  @override
  String get tagLibrary_uncategorized => '未分類';

  @override
  String get tagLibrary_contentPreview => '內容預覽';

  @override
  String get tagLibrary_confirmAdd => '確認收藏';

  @override
  String get tagLibrary_entryName => '名稱';

  @override
  String get tagLibrary_entryNameHint => '輸入條目名稱';

  @override
  String get tagLibrary_selectNewImage => '選擇新圖片';

  @override
  String get tagLibrary_adjustDisplayRange => '調整顯示範圍';

  @override
  String get tagLibrary_adjustThumbnailTitle => '調整預覽圖顯示範圍';

  @override
  String get tagLibrary_dragToMove => '拖拽移動，滾輪或雙指縮放';

  @override
  String get queue_management => '佇列管理';

  @override
  String get queue_empty => '佇列為空';

  @override
  String get queue_emptyHint => '沒有待執行的任務';

  @override
  String get queue_pending => '等待中';

  @override
  String get queue_running => '執行中';

  @override
  String get queue_completed => '已完成';

  @override
  String get queue_failed => '失敗';

  @override
  String get queue_paused => '已暫停';

  @override
  String get queue_idle => '空閒';

  @override
  String get queue_ready => '就緒';

  @override
  String get queue_noTasksToStart => '佇列為空，無法開始';

  @override
  String get queue_executionProgress => '執行進度';

  @override
  String get queue_totalTasks => '總數';

  @override
  String get queue_completedTasks => '已完成';

  @override
  String get queue_failedTasks => '失敗';

  @override
  String get queue_remainingTasks => '剩餘';

  @override
  String queue_estimatedTime(Object time) {
    return '預計：約 $time';
  }

  @override
  String queue_seconds(Object count) {
    return '$count 秒';
  }

  @override
  String queue_minutes(Object count) {
    return '$count 分鐘';
  }

  @override
  String queue_hours(Object hours, Object minutes) {
    return '$hours 小時 $minutes 分鐘';
  }

  @override
  String get queue_pause => '暫停';

  @override
  String get queue_resume => '繼續';

  @override
  String get queue_startExecution => '開始佇列';

  @override
  String get queue_pauseExecution => '暫停佇列';

  @override
  String get queue_resumeExecution => '繼續佇列';

  @override
  String get queue_generationBusy => '目前有其他生成任務正在執行，請稍後再開始佇列';

  @override
  String get queue_clearQueue => '清空佇列';

  @override
  String get queue_clearQueueConfirm => '確定要清空所有佇列任務嗎？此操作不可撤銷。';

  @override
  String get queue_confirmClear => '確認清空';

  @override
  String queue_retryCount(Object current, Object max) {
    return '重試 $current/$max';
  }

  @override
  String get queue_retry => '重試';

  @override
  String get queue_requeue => '重新排隊';

  @override
  String get queue_clearFailedTasks => '清空全部';

  @override
  String get queue_noFailedTasks => '暫無失敗任務';

  @override
  String get queue_noCompletedTasks => '暫無完成記錄';

  @override
  String get queue_editTask => '編輯任務';

  @override
  String get queue_taskDetails => '任務詳情';

  @override
  String get queue_clearCompletedTasks => '清除已完成';

  @override
  String get queue_duplicateTask => '複製任務';

  @override
  String get queue_taskDuplicated => '任務已複製';

  @override
  String get queue_queueFull => '佇列已滿，無法複製';

  @override
  String get queue_positivePrompt => '正向提示詞';

  @override
  String get queue_enterPositivePrompt => '輸入正向提示詞...';

  @override
  String get queue_parametersPreview => '引數預覽';

  @override
  String get queue_model => '模型';

  @override
  String get queue_seed => '種子';

  @override
  String get queue_sampler => '取樣器';

  @override
  String get queue_steps => '步數';

  @override
  String get queue_cfg => 'CFG';

  @override
  String get queue_size => '尺寸';

  @override
  String get queue_addCurrentTask => '加入目前任務';

  @override
  String get queue_taskAdded => '已加入佇列';

  @override
  String get queue_negativePromptFromMain => '負向提示詞將使用主介面設定';

  @override
  String get queue_pinToTop => '置頂';

  @override
  String get queue_delete => '刪除';

  @override
  String get queue_edit => '編輯';

  @override
  String get queue_selectAll => '全選';

  @override
  String get queue_invertSelection => '反選';

  @override
  String get queue_cancelSelection => '取消';

  @override
  String queue_selectedCount(Object count) {
    return '已選 $count 個';
  }

  @override
  String queue_confirmDeleteSelected(Object count) {
    return '確定要刪除選中的 $count 個任務嗎？';
  }

  @override
  String get settings_queueRetryCount => '重試次數';

  @override
  String get settings_queueRetryInterval => '重試間隔';

  @override
  String get settings_showRandomPromptTools => '顯示隨機提示詞工具';

  @override
  String get settings_showRandomPromptToolsSubtitle =>
      '在生成頁顯示“隨機提示詞”按鈕和“抽卡模式”開關';

  @override
  String get settings_enablePromptWeightScroll => '滾輪調整提示詞權重';

  @override
  String get settings_enablePromptWeightScrollSubtitle =>
      '選中提示詞時，滾輪僅調整權重，不再觸發頁面滾動等其他滾輪操作';

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
  String get settings_notificationSound => '完成音效';

  @override
  String get settings_notificationSoundSubtitle => '生成完成時播放提示音效';

  @override
  String get settings_notificationCustomSound => '自定義音效';

  @override
  String get settings_notificationSelectSound => '選擇音效';

  @override
  String get settings_notificationResetSound => '恢復預設';

  @override
  String get resetToDefault => '重置為預設';

  @override
  String get toggleGroupEnabled => '切換片語啟用狀態';

  @override
  String get diyNotAvailableForDefault => '預設預設不支援 DIY 配置';

  @override
  String get diyNotAvailableHint => '請複製為自定義預設後編輯';

  @override
  String get statistics_heatmapLess => '少';

  @override
  String get statistics_heatmapMore => '多';

  @override
  String statistics_heatmapActivities(Object count) {
    return '$count 次活動';
  }

  @override
  String get statistics_heatmapNoActivity => '無活動';

  @override
  String get sendToHome_dialogTitle => '傳送到主頁';

  @override
  String get sendToHome_send => '傳送';

  @override
  String get sendToHome_mainPrompt => '傳送到主提示詞';

  @override
  String get sendToHome_mainPromptSubtitle => '填充到主頁的正向提示詞輸入框';

  @override
  String get sendToHome_mainPromptPipeSubtitle => '傳送完整內容到主提示詞（包含豎線）';

  @override
  String get sendToHome_smartDecompose => '智慧分解';

  @override
  String sendToHome_smartDecomposeSubtitle(Object count) {
    return '主提示詞 + $count個角色';
  }

  @override
  String get sendToHome_replaceCharacter => '替換角色提示詞';

  @override
  String get sendToHome_replaceCharacterSubtitle => '清空現有角色，新增為新角色';

  @override
  String get sendToHome_appendCharacter => '追加角色提示詞';

  @override
  String get sendToHome_appendCharacterSubtitle => '保留現有角色，追加新角色';

  @override
  String get sendToHome_fixedTags => '傳送到固定詞';

  @override
  String get sendToHome_fixedTagsSubtitle => '追加到固定詞列表';

  @override
  String get sendToHome_sendAsAlias => '作為別名傳送';

  @override
  String sendToHome_sendAsAliasSubtitle(Object name) {
    return '傳送到主頁時包裝為 <$name>';
  }

  @override
  String get sendToHome_preview => '傳送預覽';

  @override
  String get sendToHome_characterPrompt => '角色提示詞';

  @override
  String sendToHome_characterPromptCount(Object count) {
    return '角色提示詞 ($count個)';
  }

  @override
  String sendToHome_characterIndex(Object index) {
    return '角色 $index';
  }

  @override
  String get sendToHome_recommended => '推薦';

  @override
  String get sendToHome_successMainPrompt => '已傳送到主提示詞';

  @override
  String get sendToHome_successReplaceCharacter => '已替換角色提示詞';

  @override
  String get sendToHome_successAppendCharacter => '已追加角色提示詞';

  @override
  String get metadataImport_title => '選擇要套用的引數';

  @override
  String get metadataImport_promptsSection => '提示詞';

  @override
  String get metadataImport_generationSection => '生成引數';

  @override
  String get metadataImport_selectAll => '全選';

  @override
  String get metadataImport_promptsOnly => '僅提示詞';

  @override
  String get metadataImport_generationOnly => '僅引數';

  @override
  String get metadataImport_clear => '清空';

  @override
  String get metadataImport_mainPrompt => '主提示詞';

  @override
  String get metadataImport_fixedTags => '固定詞';

  @override
  String get metadataImport_fixedSourceStructured => '來源：圖片明確記錄';

  @override
  String get metadataImport_fixedSourceLegacy => '來源：舊版圖片欄位';

  @override
  String get metadataImport_fixedSourceLibrary => '來源：根據目前固定詞庫嚴格匹配';

  @override
  String get metadataImport_fixedSourceUnknown => '來源：圖片未記錄，無法確認';

  @override
  String get metadataImport_unknownFixedTagsHint =>
      '圖片沒有記錄固定詞。請選擇如何處理目前已啟用的固定詞。';

  @override
  String get metadataImport_disableCurrentFixedTags => '關閉目前固定詞（推薦）';

  @override
  String get metadataImport_keepCurrentFixedTags => '保留並與圖片提示詞疊加';

  @override
  String metadataImport_imageVersionName(Object name) {
    return '$name（圖片版本）';
  }

  @override
  String metadataImport_fixedPrefix(Object text) {
    return '字首: $text';
  }

  @override
  String metadataImport_fixedSuffix(Object text) {
    return '字尾: $text';
  }

  @override
  String metadataImport_negativeFixedPrefix(Object text) {
    return '負向字首: $text';
  }

  @override
  String metadataImport_negativeFixedSuffix(Object text) {
    return '負向字尾: $text';
  }

  @override
  String metadataImport_qualityTagsCount(int count) {
    return '質量詞 ($count個)';
  }

  @override
  String get metadataImport_negativePrompt => '負向提示詞';

  @override
  String metadataImport_characterPromptsCount(int count) {
    return '角色提示詞 ($count個)';
  }

  @override
  String metadataImport_characterIndex(int index, Object text) {
    return '角色$index: $text';
  }

  @override
  String get metadataImport_referenceSection => '參考圖';

  @override
  String metadataImport_countUnit(int count) {
    return '$count個';
  }

  @override
  String metadataImport_preciseReferenceCount(int count) {
    return '精準參考 ($count個)';
  }

  @override
  String metadataImport_vibeDetail(Object name, Object strength, Object info) {
    return '$name (強度 $strength%, 資訊提取 $info%)';
  }

  @override
  String metadataImport_preciseReferenceDetail(
    int index,
    Object type,
    Object strength,
    Object fidelity,
  ) {
    return '參考$index: $type (強度 $strength%, 保真 $fidelity%)';
  }

  @override
  String get metadataImport_noData => '（無資料）';

  @override
  String metadataImport_selectedCount(int count) {
    return '已選擇 $count 項';
  }

  @override
  String get metadataImport_readImageMetadata => '讀取圖片後設資料';

  @override
  String get metadataImport_readFailed => '無法讀取所選圖片';

  @override
  String get metadataImport_processFailed => '無法處理所選圖片';

  @override
  String get metadataImport_noDataFound => '未找到 NovelAI 後設資料';

  @override
  String get metadataImport_noParamsSelected => '未選擇任何要應用的引數';

  @override
  String metadataImport_appliedCount(int count) {
    return '已應用 $count 項引數';
  }

  @override
  String get shortcut_context_global => '全域性';

  @override
  String get shortcut_context_generation => '生成頁面';

  @override
  String get shortcut_context_gallery => '畫廊列表';

  @override
  String get shortcut_context_viewer => '圖片檢視器';

  @override
  String get shortcut_context_tag_library => '詞庫';

  @override
  String get shortcut_context_random_config => '隨機配置';

  @override
  String get shortcut_context_settings => '設定';

  @override
  String get shortcut_context_input => '輸入框';

  @override
  String get shortcut_action_navigate_to_generation => '生成頁面';

  @override
  String get shortcut_action_navigate_to_local_gallery => '本地畫廊';

  @override
  String get shortcut_action_navigate_to_online_gallery => '線上畫廊';

  @override
  String get shortcut_action_navigate_to_random_config => '隨機配置';

  @override
  String get shortcut_action_navigate_to_tag_library => '詞庫頁面';

  @override
  String get shortcut_action_navigate_to_statistics => '統計頁面';

  @override
  String get shortcut_action_navigate_to_settings => '設定頁面';

  @override
  String get shortcut_action_generate_image => '生成影象';

  @override
  String get shortcut_action_generation_prev_image => '預覽上一張（歷史聯動）';

  @override
  String get shortcut_action_generation_next_image => '預覽下一張（歷史聯動）';

  @override
  String get shortcut_action_cancel_generation => '取消生成';

  @override
  String get shortcut_action_add_to_queue => '加入佇列';

  @override
  String get shortcut_action_random_prompt => '隨機提示詞';

  @override
  String get shortcut_action_clear_prompt => '清空提示詞';

  @override
  String get shortcut_action_toggle_prompt_mode => '切換正/負面模式';

  @override
  String get shortcut_action_open_tag_library => '開啟詞庫';

  @override
  String get shortcut_action_save_image => '儲存影象';

  @override
  String get shortcut_action_upscale_image => '放大影象';

  @override
  String get shortcut_action_copy_image => '複製影象';

  @override
  String get shortcut_action_fullscreen_preview => '全屏預覽';

  @override
  String get shortcut_action_open_params_panel => '開啟引數面板';

  @override
  String get shortcut_action_open_history_panel => '開啟歷史面板';

  @override
  String get shortcut_action_reuse_params => '複用引數';

  @override
  String get shortcut_action_previous_image => '上一張';

  @override
  String get shortcut_action_next_image => '下一張';

  @override
  String get shortcut_action_zoom_in => '放大';

  @override
  String get shortcut_action_zoom_out => '縮小';

  @override
  String get shortcut_action_reset_zoom => '重置縮放';

  @override
  String get shortcut_action_toggle_fullscreen => '全屏切換';

  @override
  String get shortcut_action_close_viewer => '關閉檢視器';

  @override
  String get shortcut_action_toggle_favorite => '收藏切換';

  @override
  String get shortcut_action_copy_prompt => '複製Prompt';

  @override
  String get shortcut_action_reuse_gallery_params => '複用引數';

  @override
  String get shortcut_action_delete_image => '刪除圖片';

  @override
  String get shortcut_action_previous_page => '上一頁';

  @override
  String get shortcut_action_next_page => '下一頁';

  @override
  String get shortcut_action_refresh_gallery => '重新整理';

  @override
  String get shortcut_action_focus_search => '搜尋聚焦';

  @override
  String get shortcut_action_enter_selection_mode => '進入選擇模式';

  @override
  String get shortcut_action_open_filter_panel => '開啟篩選面板';

  @override
  String get shortcut_action_clear_filter => '清除篩選';

  @override
  String get shortcut_action_toggle_category_panel => '切換分類面板';

  @override
  String get shortcut_action_jump_to_date => '跳轉到日期';

  @override
  String get shortcut_action_open_folder => '開啟資料夾';

  @override
  String get shortcut_action_select_all_tags => '全選標籤';

  @override
  String get shortcut_action_deselect_all_tags => '取消全選';

  @override
  String get shortcut_action_new_category => '新建分類';

  @override
  String get shortcut_action_new_tag => '新建標籤';

  @override
  String get shortcut_action_search_tags => '搜尋標籤';

  @override
  String get shortcut_action_batch_delete_tags => '批次刪除標籤';

  @override
  String get shortcut_action_batch_copy_tags => '批次複製標籤';

  @override
  String get shortcut_action_send_to_home => '傳送到首頁';

  @override
  String get shortcut_action_exit_selection_mode => '退出選擇模式';

  @override
  String get shortcut_action_sync_danbooru => '同步Danbooru';

  @override
  String get shortcut_action_generate_preview => '生成預覽';

  @override
  String get shortcut_action_search_presets => '搜尋預設';

  @override
  String get shortcut_action_new_preset => '新建預設';

  @override
  String get shortcut_action_duplicate_preset => '複製預設';

  @override
  String get shortcut_action_delete_preset => '刪除預設';

  @override
  String get shortcut_action_close_config => '關閉配置';

  @override
  String get shortcut_action_minimize_to_tray => '最小化到托盤';

  @override
  String get shortcut_action_quit_app => '退出應用';

  @override
  String get shortcut_action_show_shortcut_help => '顯示快捷鍵幫助';

  @override
  String get shortcut_action_toggle_queue => '切換佇列';

  @override
  String get shortcut_action_toggle_queue_pause => '暫停/繼續佇列';

  @override
  String get shortcut_action_toggle_theme => '切換主題';

  @override
  String get shortcut_settings_title => '鍵盤快捷鍵';

  @override
  String get shortcut_settings_enable => '啟用快捷鍵';

  @override
  String get shortcut_settings_show_badges => '顯示快捷鍵標識';

  @override
  String get shortcut_settings_show_in_tooltips => '在提示中顯示';

  @override
  String get shortcut_settings_reset_all => '重置全部為預設';

  @override
  String get shortcut_settings_search => '搜尋快捷鍵...';

  @override
  String get shortcut_settings_press_key => '按下按鍵組合...';

  @override
  String get shortcut_help_title => '快捷鍵幫助';

  @override
  String get shortcut_help_search => '搜尋快捷鍵...';

  @override
  String get shortcut_help_all => '全部';

  @override
  String get shortcut_help_tip => '提示：按 F1 或 ? 鍵可隨時開啟此幫助對話方塊';

  @override
  String get shortcut_help_fabTooltip => '快捷鍵幫助 (F1)';

  @override
  String get shortcut_editor_recordingInline => '按快捷鍵...';

  @override
  String get shortcut_editor_pressEscToCancel => '按 Esc 取消';

  @override
  String get shortcut_editor_clickToRecord => '點選開始錄製';

  @override
  String shortcut_editor_conflictWith(Object action) {
    return '此快捷鍵與 \"$action\" 衝突';
  }

  @override
  String get drop_dialogTitle => '如何使用這張圖片？';

  @override
  String get drop_actions => '操作';

  @override
  String get drop_hint => '拖拽圖片到這裡';

  @override
  String get drop_img2img => '圖生圖';

  @override
  String get drop_reversePrompt => '反推';

  @override
  String get drop_vibeTransfer => '風格遷移';

  @override
  String get drop_characterReference => '精準參考';

  @override
  String get drop_unsupportedFormat => '不支援的檔案格式';

  @override
  String get drop_addedToImg2Img => '已新增到圖生圖';

  @override
  String get drop_addedToReversePrompt => '已新增到反推';

  @override
  String get drop_addedToVibe => '已新增到風格遷移';

  @override
  String drop_addedMultipleToVibe(int count) {
    return '已新增 $count 個風格參考';
  }

  @override
  String get drop_addedToCharacterRef => '已新增到精準參考';

  @override
  String get drop_extractMetadata => '傳送到文生圖';

  @override
  String get drop_extractMetadataSubtitle => '選擇要套用的提示詞、固定詞和生成引數';

  @override
  String get drop_addToQueue => '加入佇列';

  @override
  String get drop_addToQueueSubtitle => '提取正面提示詞並加入生成佇列';

  @override
  String get drop_vibeDetected => '檢測到預編碼 Vibe（可節省 2 Anlas）';

  @override
  String drop_vibeStrength(Object value) {
    return '強度: $value%';
  }

  @override
  String drop_vibeInfoExtracted(Object value) {
    return '資訊提取: $value%';
  }

  @override
  String get drop_reuseVibe => '複用 Vibe';

  @override
  String get drop_reuseVibeSubtitle => '直接使用預編碼資料（免費）';

  @override
  String get drop_useAsRawImage => '作為原始圖片';

  @override
  String get drop_useAsRawImageSubtitle => '重新編碼（消耗 2 Anlas）';

  @override
  String get drop_dragToImg2ImgOrOther => '拖拽到圖生圖或其他區域';

  @override
  String get drop_metadataDetected => '檢測到 NovelAI 後設資料';

  @override
  String get drop_metadataParseFailed => '後設資料解析失敗';

  @override
  String get drop_metadataParseFailedHint => '圖片包含後設資料欄位，但目前無法讀取。其他圖片用途仍可正常使用。';

  @override
  String get drop_metadataErrorDetails => '檢視錯誤詳情';

  @override
  String get drop_positivePrompt => '正向 Prompt';

  @override
  String get drop_negativePrompt => '負向 Prompt';

  @override
  String drop_characterPrompts(int count) {
    return '角色 Prompt（$count）';
  }

  @override
  String drop_characterPositivePrompt(int index) {
    return '角色 $index 正向 Prompt';
  }

  @override
  String drop_characterNegativePrompt(int index) {
    return '角色 $index 負向 Prompt';
  }

  @override
  String get drop_promptNotRecorded => '未記錄';

  @override
  String get drop_promptCopy => '複製';

  @override
  String get drop_promptAddWhole => '整段加入詞庫';

  @override
  String get drop_promptAddSelection => '加入詞庫';

  @override
  String get drop_promptLibraryTitle => '加入詞庫';

  @override
  String get drop_promptLibraryWriteMode => '寫入方式';

  @override
  String get drop_promptLibraryCreate => '新建';

  @override
  String get drop_promptLibraryAppend => '追加';

  @override
  String get drop_promptLibraryOverwrite => '覆蓋';

  @override
  String get drop_promptLibraryAliasHint => '該名稱同時用於 <詞庫名稱> 引用';

  @override
  String get drop_promptLibraryTarget => '目標條目';

  @override
  String get drop_promptLibrarySelectTarget => '選擇要更新的條目';

  @override
  String get drop_promptLibrarySeparator => '連線方式';

  @override
  String get drop_promptLibrarySeparatorComma => '逗號 + 空格';

  @override
  String get drop_promptLibrarySeparatorNewline => '換行';

  @override
  String get drop_promptLibrarySeparatorNone => '不插入分隔符';

  @override
  String drop_promptLibraryCharacterCount(int count) {
    return '$count 字元';
  }

  @override
  String get drop_promptLibraryExactContentHint => '儲存當前文字，不自動清洗、重排或補全';

  @override
  String get drop_promptLibraryResultPreview => '結果預覽';

  @override
  String drop_promptLibraryDuplicate(Object name) {
    return '相同內容已存在於「$name」';
  }

  @override
  String get drop_promptLibraryNameConflict => '該名稱已存在，請改名或選擇追加/覆蓋';

  @override
  String drop_promptLibraryOverwriteWarning(Object name) {
    return '將完整替換「$name」的提示詞內容';
  }

  @override
  String get drop_promptLibraryMore => '更多選項';

  @override
  String get drop_promptLibraryConfirmOverwrite => '確認覆蓋';

  @override
  String get drop_promptLibrarySaved => '已儲存到詞庫';

  @override
  String get drop_promptLibrarySaveFailed => '詞庫儲存失敗';

  @override
  String get drop_promptLibraryPositiveName => '正向提示詞摘取';

  @override
  String get drop_promptLibraryNegativeName => '負向提示詞摘取';

  @override
  String get preciseRef_title => '精準參考';

  @override
  String get preciseRef_description => '新增參考圖並設定型別和引數，可同時使用多個參考。';

  @override
  String get preciseRef_addReference => '新增參考圖';

  @override
  String get preciseRef_clearAll => '清空全部';

  @override
  String get preciseRef_remove => '移除';

  @override
  String get preciseRef_referenceType => '參考型別';

  @override
  String get preciseRef_strength => '參考強度';

  @override
  String get preciseRef_fidelity => '保真度';

  @override
  String get preciseRef_v4Only => '此功能僅 V4.5 模型支援';

  @override
  String get preciseRef_typeCharacter => '角色';

  @override
  String get preciseRef_typeStyle => '風格';

  @override
  String get preciseRef_typeCharacterAndStyle => '角色+風格';

  @override
  String get preciseRef_costHint => '使用精準參考會消耗額外點數';

  @override
  String get preciseRef_costBadge => '消耗點數';

  @override
  String get preciseRef_dropToAdd => '鬆開後新增精準參考';

  @override
  String get preciseRef_dropNoReadableImage => '拖入源未提供可讀取的圖片檔案或圖片連結';

  @override
  String preciseRef_addedCount(int count) {
    return '已新增 $count 個精準參考';
  }

  @override
  String preciseRef_removedCount(int count) {
    return '已刪除 $count 個精準參考';
  }

  @override
  String get vibeLibrary_title => 'Vibe 庫';

  @override
  String get vibeLibrary_categories => '分類';

  @override
  String get vibeLibrary_createCategoryTitle => '新建分類';

  @override
  String get vibeLibrary_createSubCategoryTitle => '新建子分類';

  @override
  String get vibeLibrary_categoryNameHint => '請輸入分類名稱';

  @override
  String get vibeLibrary_createCategoryConfirm => '建立';

  @override
  String get vibeLibrary_deleteCategoryTitle => '確認刪除';

  @override
  String get vibeLibrary_deleteCategoryContent =>
      '確定要刪除此分類嗎？分類下的 Vibe 將被移動到未分類。';

  @override
  String get vibeLibrary_sortTooltip => '排序方式';

  @override
  String get vibeLibrary_hideCategoryPanel => '隱藏分類面板';

  @override
  String get vibeLibrary_showCategoryPanel => '顯示分類面板';

  @override
  String get vibeLibrary_enterSelectionMode => '進入選擇模式';

  @override
  String get vibeLibrary_importTooltip =>
      '匯入 Vibe 檔案或 PNG/JPG/JPEG/WEBP 圖片（右鍵檢視更多選項）';

  @override
  String get vibeLibrary_exportTooltip => '匯出 Vibe 到檔案';

  @override
  String get vibeLibrary_openFolderTooltip => '開啟 Vibe 庫資料夾';

  @override
  String get vibeLibrary_refresh => '重新整理';

  @override
  String get vibeLibrary_loading => '載入中...';

  @override
  String vibeLibrary_totalCount(Object count) {
    return '共 $count 個 Vibe';
  }

  @override
  String get vibeLibrary_noCategoriesAvailable => '沒有可用的分類';

  @override
  String get vibeLibrary_moveToCategory => '移動到分類';

  @override
  String get vibeLibrary_uncategorized => '未分類';

  @override
  String vibeLibrary_movedToCategory(Object count) {
    return '已移動 $count 個 Vibe';
  }

  @override
  String get vibeLibrary_favoriteStatusUpdated => '收藏狀態已更新';

  @override
  String get vibeLibrary_importFromFile => '從檔案匯入';

  @override
  String get vibeLibrary_importFromImage => '從圖片匯入';

  @override
  String get vibeLibrary_importFromClipboard => '從剪貼簿匯入編碼';

  @override
  String vibeLibrary_openFolderFailed(Object error) {
    return '開啟資料夾失敗: $error';
  }

  @override
  String get vibeLibrary_importFileDialogTitle => '選擇要匯入的 Vibe 檔案';

  @override
  String get vibeLibrary_preparingImport => '準備匯入...';

  @override
  String vibeLibrary_importSuccessCount(Object count) {
    return '成功匯入 $count 個 Vibe';
  }

  @override
  String vibeLibrary_importSummary(Object success, Object failed) {
    return '匯入完成: $success 成功, $failed 失敗';
  }

  @override
  String get vibeLibrary_dropImportHint =>
      '拖拽 .naiv4vibe/.naiv4vibebundle/.png/.jpg/.jpeg/.webp 檔案或資料夾到此處匯入';

  @override
  String get vibeLibrary_importing => '正在匯入...';

  @override
  String vibeLibrary_pageIndicator(Object current, Object total) {
    return '$current / $total 頁';
  }

  @override
  String get vibeLibrary_itemsPerPage => '每頁:';

  @override
  String get vibeLibrary_tooManyTitle => 'Vibe數量過多';

  @override
  String vibeLibrary_tooManySelectedContent(Object count) {
    return '選中了 $count 個Vibe，但最多隻能同時使用16個。\n\n請減少選擇數量後再試。';
  }

  @override
  String vibeLibrary_tooManyExistingContent(Object current, Object remaining) {
    return '當前生成頁面已有 $current 個Vibe，還可以新增 $remaining 個。\n\n請減少選擇數量後再試。';
  }

  @override
  String vibeLibrary_sentToGenerationCount(Object count) {
    return '已傳送 $count 個Vibe到生成頁面';
  }

  @override
  String vibeLibrary_deleteSelectedContent(Object count) {
    return '確定要刪除選中的 $count 個Vibe嗎？此操作無法撤銷。';
  }

  @override
  String vibeLibrary_deletedCount(Object count) {
    return '已刪除 $count 個Vibe';
  }

  @override
  String get vibeLibrary_markEncodingModel => '標記編碼模型';

  @override
  String vibeLibrary_markEncodingModelContent(Object count, Object model) {
    return '把選中的 $count 個 Vibe 標記為「$model」的編碼，並重寫庫檔案。\n\n適用於被錯誤標記成其它模型、導致每次生成都重新編碼扣 Anlas 的條目。如果這些編碼確實來自別的模型，標記後畫面效果可能與預期不符。';
  }

  @override
  String vibeLibrary_encodingModelMarked(Object count) {
    return '已標記 $count 個Vibe的編碼模型';
  }

  @override
  String get vibeLibrary_importImageDialogTitle => '選擇包含 Vibe 的圖片';

  @override
  String get vibeLibrary_clipboardEmpty => '剪貼簿為空';

  @override
  String get vibeLibrary_encodeTimeout => '編碼超時，請檢查網路連線';

  @override
  String get vibeLibrary_unknownError => '未知錯誤';

  @override
  String get vibeLibrary_save => '儲存到庫';

  @override
  String get vibeLibrary_import => '匯入 Vibe';

  @override
  String get vibeLibrary_searchHint => '搜尋名稱、標籤...';

  @override
  String get vibeLibrary_empty => 'Vibe 庫為空';

  @override
  String get vibeLibrary_emptyHint => '先去 Vibe 庫新增一些條目吧';

  @override
  String get vibeLibrary_allVibes => '全部 Vibe';

  @override
  String get vibeLibrary_favorites => '收藏';

  @override
  String get vibeLibrary_sendToGeneration => '傳送到生成';

  @override
  String get vibeLibrary_export => '匯出';

  @override
  String get vibeLibrary_edit => '編輯';

  @override
  String get vibeLibrary_delete => '刪除';

  @override
  String get vibeLibrary_addToFavorites => '收藏';

  @override
  String get vibeLibrary_removeFromFavorites => '取消收藏';

  @override
  String get vibeLibrary_newSubCategory => '新建子分類';

  @override
  String get vibeLibrary_maxVibesReached => '已達到最大數量 (16張)';

  @override
  String get vibeLibrary_bundleReadFailed => '讀取 Bundle 檔案失敗，使用單檔案模式';

  @override
  String categoryError_loadFailed(String error) {
    return '載入分類失敗：$error';
  }

  @override
  String categoryError_syncFailed(String error) {
    return '同步分類失敗：$error';
  }

  @override
  String get categoryError_nameEmpty => '分類名稱不能為空';

  @override
  String get categoryError_parentNotFound => '父分類不存在';

  @override
  String categoryError_createFailed(String error) {
    return '建立分類失敗：$error';
  }

  @override
  String get categoryError_notFound => '分類不存在';

  @override
  String categoryError_renameFailed(String error) {
    return '重新命名分類失敗：$error';
  }

  @override
  String get categoryError_invalidMove => '不能將分類移動到它的子孫分類下';

  @override
  String categoryError_moveFailed(String error) {
    return '移動分類失敗：$error';
  }

  @override
  String get categoryError_hasSubcategories => '該分類包含子分類，請先刪除子分類。';

  @override
  String categoryError_deleteFailed(String error) {
    return '刪除分類失敗：$error';
  }

  @override
  String categoryError_moveImageFailed(String error) {
    return '移動圖片失敗：$error';
  }

  @override
  String categoryError_moveImagesFailed(String error) {
    return '批次移動圖片失敗：$error';
  }

  @override
  String categoryError_reorderFailed(String error) {
    return '重新排序分類失敗：$error';
  }

  @override
  String vibeBulk_errorEntryNotFoundOrDeleteFailed(String item) {
    return '未找到 $item 或刪除失敗';
  }

  @override
  String vibeBulk_errorDeleteFailed(String item, String error) {
    return '刪除 $item 失敗：$error';
  }

  @override
  String vibeBulk_errorEntryNotFound(String item) {
    return '未找到條目：$item';
  }

  @override
  String vibeBulk_errorMoveFailed(String item, String error) {
    return '移動 $item 失敗：$error';
  }

  @override
  String vibeBulk_errorFavoriteFailed(String item) {
    return '更新收藏狀態失敗：$item';
  }

  @override
  String vibeBulk_errorFavoriteFailedWithDetails(String item, String error) {
    return '更新 $item 的收藏狀態失敗：$error';
  }

  @override
  String vibeBulk_errorAddTagsFailed(String item) {
    return '新增標籤失敗：$item';
  }

  @override
  String vibeBulk_errorAddTagsFailedWithDetails(String item, String error) {
    return '為 $item 新增標籤失敗：$error';
  }

  @override
  String vibeBulk_errorRemoveTagsFailed(String item) {
    return '移除標籤失敗：$item';
  }

  @override
  String vibeBulk_errorRemoveTagsFailedWithDetails(String item, String error) {
    return '從 $item 移除標籤失敗：$error';
  }

  @override
  String get vibeBulk_errorExportNoFile => '匯出失敗：未建立檔案';

  @override
  String vibeBulk_errorExportFailed(String error) {
    return '匯出失敗：$error';
  }

  @override
  String vibeBulk_errorFileNotFound(String item) {
    return '未找到檔案：$item';
  }

  @override
  String vibeBulk_errorNoVibeData(String item) {
    return '$item 中沒有有效的 Vibe 資料';
  }

  @override
  String vibeBulk_errorImportFailed(String item, String error) {
    return '從 $item 匯入 Vibe 失敗：$error';
  }

  @override
  String vibeBulk_errorProcessFileFailed(String item, String error) {
    return '處理 $item 失敗：$error';
  }

  @override
  String get vibeBulkTag_actionPreview => '操作預覽';

  @override
  String get vibeDetail_strengthDescription => '控制 Vibe 對生成結果的影響強度';

  @override
  String get vibeDetail_infoExtractedDescription => '控制從原圖提取的資訊量（消耗 2 Anlas）';

  @override
  String get vibeDetail_statistics => '統計資訊';

  @override
  String get vibeDetail_usageCount => '使用次數';

  @override
  String vibeDetail_timesUsed(int count) {
    return '$count 次';
  }

  @override
  String get vibeDetail_lastUsed => '最後使用';

  @override
  String get vibeDetail_neverUsed => '從未使用';

  @override
  String get vibeDetail_createdAt => '建立時間';

  @override
  String get vibeDetail_saveParameters => '儲存引數';

  @override
  String get vibe_export_title => '匯出 Vibe';

  @override
  String get vibe_export_format => '匯出格式';

  @override
  String get vibe_selector_title => '選擇 Vibe';

  @override
  String get vibe_selector_recent => '最近使用';

  @override
  String get vibe_export_include_thumbnails => '包含縮圖';

  @override
  String get vibe_export_include_thumbnails_subtitle => '匯出檔案中包含縮圖預覽';

  @override
  String get vibe_export_singleFile => '單檔案 (.naiv4vibe)';

  @override
  String get vibe_export_singleFileDescription =>
      '將每個 Vibe 匯出為單獨檔案，適合分享單個 Vibe';

  @override
  String get vibe_export_bundleFile => '打包檔案 (.naiv4vibebundle)';

  @override
  String get vibe_export_bundleFileDescription => '將多個 Vibe 打包到一個檔案中，適合批次備份';

  @override
  String get vibe_export_embedIntoPng => '嵌入到 PNG';

  @override
  String get vibe_export_embedIntoPngDescription => '透過寫入 PNG 後設資料匯出單個 Vibe';

  @override
  String get vibe_export_exportable => '可匯出';

  @override
  String get vibe_export_notExportable => '不可匯出';

  @override
  String get vibe_export_selectVibesToExport => '選擇要匯出的 Vibe';

  @override
  String vibe_export_exportSelected(int count) {
    return '匯出 ($count)';
  }

  @override
  String vibe_export_strengthPercent(int percent) {
    return '強度: $percent%';
  }

  @override
  String get vibe_export_pngCarrierImage => 'PNG 載體圖片';

  @override
  String get vibe_export_noUsablePngCarrier =>
      '這個 Vibe 沒有可直接使用的 PNG 載體圖片。你可以選擇外部 PNG 圖片作為載體。';

  @override
  String get vibe_export_selectExternalPngImage => '選擇外部 PNG 圖片...';

  @override
  String get vibe_export_changeExternalPngImage => '更換外部 PNG 圖片...';

  @override
  String get vibe_export_useVibeImageInstead => '改用 Vibe 圖片';

  @override
  String vibe_export_usingExternalPng(String fileName) {
    return '正在使用外部 PNG: $fileName';
  }

  @override
  String get vibe_export_selectPngImage => '選擇 PNG 圖片';

  @override
  String get vibe_export_invalidPngImage => '所選檔案不是有效的 PNG 圖片';

  @override
  String vibe_export_selectPngImageFailed(String error) {
    return '選擇 PNG 圖片失敗: $error';
  }

  @override
  String vibe_export_embeddingPng(String name) {
    return '正在嵌入 PNG: $name';
  }

  @override
  String vibe_export_exportCompleteCounts(int successCount, int failCount) {
    return '匯出完成: 成功 $successCount 個，失敗 $failCount 個';
  }

  @override
  String vibe_export_exportCompletePath(String path) {
    return '匯出完成: $path';
  }

  @override
  String vibe_export_packingVibes(int count) {
    return '正在打包 $count 個 Vibe...';
  }

  @override
  String vibe_export_exportingName(String name) {
    return '正在匯出: $name';
  }

  @override
  String get vibe_export_selectExportFolder => '選擇匯出資料夾';

  @override
  String get vibe_export_generatingBundleFile => '正在生成打包檔案...';

  @override
  String vibe_export_bundleTitle(String name) {
    return '匯出 Bundle: $name';
  }

  @override
  String vibe_export_vibesTitle(int count) {
    return '匯出 Vibe ($count 個已選)';
  }

  @override
  String get vibe_export_method => '匯出方式';

  @override
  String get vibe_export_wholeBundle => '整個 Bundle';

  @override
  String get vibe_export_internalVibe => '內部 Vibe';

  @override
  String vibe_export_wholeBundleDescription(int count) {
    return '匯出包含全部 $count 個 Vibe 的 .naiv4vibebundle 檔案';
  }

  @override
  String vibe_export_internalVibeDescription(int count) {
    return '選擇 Bundle 內部 Vibe，分別匯出為 .naiv4vibe 檔案 (共 $count 個)';
  }

  @override
  String get vibe_export_exportBundle => '匯出 Bundle';

  @override
  String get vibe_export_exportAsFiles => '匯出為檔案';

  @override
  String get vibe_export_exportBundleDescription => '匯出為 .naiv4vibebundle 檔案';

  @override
  String get vibe_export_exportAsFilesDescription =>
      '匯出為 .naiv4vibe 或 .naiv4vibebundle 檔案';

  @override
  String get vibe_export_exportAsZip => '匯出為 ZIP';

  @override
  String get vibe_export_exportAsZipDescription =>
      '將選中的 Vibe 庫條目作為獨立檔案打包為 .zip';

  @override
  String get vibe_export_compressData => '壓縮資料';

  @override
  String get vibe_export_compressDataDescription => '使用壓縮以減小檔案大小 (推薦用於批次匯出)';

  @override
  String get vibe_export_zipCompressDescription => '壓縮 ZIP 內的檔案以減小體積';

  @override
  String get vibe_export_exportAsPng => '匯出為 PNG';

  @override
  String get vibe_export_pngInternalBundleUnsupported =>
      '匯出單個 Bundle 內部 Vibe 時不支援嵌入圖片';

  @override
  String get vibe_export_embedVibeDataIntoPng => '將 Vibe 資料寫入 PNG 後設資料';

  @override
  String get vibe_export_batchPngUsesFirstImage =>
      '批次匯出會使用每個 Vibe 的第一張可用圖片，沒有圖片的條目會自動跳過。';

  @override
  String get vibe_export_exportCarrierImage => '匯出載體圖片';

  @override
  String get vibe_export_usingExternalCarrierImage => '正在使用外部 PNG 作為匯出載體圖片';

  @override
  String get vibe_export_exportAsEncodings => '匯出為編碼';

  @override
  String get vibe_export_exportAsEncodingsDescription =>
      '將資料匯出為編碼 (JSON 或 Base64)';

  @override
  String get vibe_export_jsonDescription => '匯出為格式化 JSON 檔案，便於閱讀和編輯';

  @override
  String get vibe_export_base64Description => '匯出為純 Base64，便於複製和分享';

  @override
  String get vibe_export_selectAtLeastOneMethod => '請選擇至少一種匯出方式';

  @override
  String get vibe_export_batchPngUnsupported =>
      '批次 Vibe 匯出不支援嵌入 PNG。請使用單個 Vibe 匯出介面。';

  @override
  String get vibe_export_selectPngCarrier => '請選擇用於匯出的 PNG 載體圖片';

  @override
  String get vibe_export_selectAtLeastOneInternalVibe => '請選擇至少一個內部 Vibe';

  @override
  String get vibe_export_selectVibeExportFolder => '選擇 Vibe 匯出資料夾';

  @override
  String get vibe_export_saveEncodingFile => '儲存編碼檔案';

  @override
  String get vibe_export_preparingExport => '正在準備匯出...';

  @override
  String vibe_export_preparingVibeProgress(int current, int total) {
    return '正在讀取 Vibe $current/$total...';
  }

  @override
  String get vibe_export_exportingBundle => '正在匯出 Bundle...';

  @override
  String get vibe_export_exportingZip => '正在匯出 ZIP...';

  @override
  String get vibe_export_embeddingImage => '正在嵌入圖片...';

  @override
  String get vibe_export_exportingEncoding => '正在匯出編碼...';

  @override
  String vibe_export_exportFailedWithError(String error) {
    return '匯出失敗: $error';
  }

  @override
  String get vibe_export_noExportableEntries => '沒有可匯出的 Vibe 條目';

  @override
  String get vibe_export_bundleFilePathEmpty => 'Bundle 檔案路徑為空';

  @override
  String vibe_export_invalidImageFormatWithError(String error) {
    return '無效的圖片格式: $error';
  }

  @override
  String vibe_export_embedFailedWithError(String error) {
    return '嵌入失敗: $error';
  }

  @override
  String vibe_export_embedImageFailedWithError(String error) {
    return '嵌入圖片失敗: $error';
  }

  @override
  String vibe_export_extractingVibeProgress(int current, int total) {
    return '正在提取 Vibe $current/$total...';
  }

  @override
  String vibe_export_selectImageFailed(String error) {
    return '選擇圖片失敗: $error';
  }

  @override
  String vibe_export_dialogTitle(int count) {
    return '匯出 $count 個 Vibes';
  }

  @override
  String get vibe_export_chooseMethod => '選擇匯出方式';

  @override
  String get vibe_export_asBundle => '打包匯出';

  @override
  String get vibe_export_individually => '逐個匯出';

  @override
  String get vibe_export_noData => '沒有可匯出的資料';

  @override
  String get vibe_export_success => '匯出成功';

  @override
  String get vibe_export_failed => '匯出失敗';

  @override
  String vibe_export_skipped(int count) {
    return '跳過了 $count 個無資料 vibes';
  }

  @override
  String vibe_export_bundleSuccess(int count) {
    return '已匯出 Bundle: $count 個 vibes';
  }

  @override
  String get vibe_export_selectToEmbed => '選擇要嵌入的 vibes';

  @override
  String get vibe_export_pngRequired => '需要 PNG 檔案';

  @override
  String get vibe_export_noEmbeddableData => '沒有可嵌入的資料';

  @override
  String vibe_export_embedSuccess(int count) {
    return '已嵌入 $count 個 vibes 到圖片';
  }

  @override
  String get vibe_export_embedFailed => '嵌入失敗';

  @override
  String get vibe_embedToImage => '嵌入到圖片';

  @override
  String get vibe_import_skip => '跳過';

  @override
  String get vibe_import_confirm => '確認';

  @override
  String get vibe_import_encodingCost => '編碼將消耗 2 Anlas';

  @override
  String get vibe_import_encodingFailed => '編碼失敗';

  @override
  String get vibe_import_title => '從庫匯入';

  @override
  String vibe_import_result(int count) {
    return '已匯入 $count 個 vibes';
  }

  @override
  String get vibe_import_fileParseFailed => '解析檔案失敗';

  @override
  String get vibe_import_fileSelectionFailed => '檔案選擇失敗';

  @override
  String get vibe_import_importFailed => '匯入失敗';

  @override
  String get vibe_import_bundleTitle => '匯入 Vibe Bundle';

  @override
  String get vibe_import_bundleChooseMethod => '選擇匯入方式';

  @override
  String get vibe_import_bundleAsWhole => '作為整體匯入';

  @override
  String get vibe_import_bundleAsWholeDescription => '保留 Bundle 結構，並作為一個庫條目匯入';

  @override
  String get vibe_import_bundleSplitEntries => '拆分為獨立條目';

  @override
  String get vibe_import_bundleSplitEntriesDescription => '將每個 Vibe 作為獨立庫條目匯入';

  @override
  String get vibe_import_bundleSelectVibes => '選擇要匯入的 Vibe';

  @override
  String get vibe_import_bundleSelectVibesDescription => '僅匯入選中的 Vibe';

  @override
  String get vibe_import_bundleConfigureEachVibe => '配置每個 Vibe 的引數';

  @override
  String get vibe_import_bundleSelectAndConfigureEachVibe => '選擇並配置每個 Vibe 的引數';

  @override
  String vibe_import_bundleSelectedCount(int selected, int total) {
    return '已選擇 $selected/$total';
  }

  @override
  String get vibe_saveToLibrary_title => '儲存到庫';

  @override
  String get vibe_saveToLibrary_strength => '參考強度';

  @override
  String get vibe_saveToLibrary_infoExtracted => '資訊提取';

  @override
  String vibe_saveToLibrary_saving(int count) {
    return '正在儲存 $count 個 vibes';
  }

  @override
  String get vibe_saveToLibrary_saveFailed => '儲存到庫失敗';

  @override
  String vibe_saveToLibrary_savingCount(int count) {
    return '正在儲存 $count 個 vibes';
  }

  @override
  String get vibe_saveToLibrary_nameLabel => '名稱';

  @override
  String get vibe_saveToLibrary_nameHint => '輸入 vibe 名稱';

  @override
  String vibe_saveToLibrary_mixed(int saved, int reused) {
    return '已儲存 $saved 個，複用 $reused 個';
  }

  @override
  String vibe_saveToLibrary_saved(int count) {
    return '已儲存 $count 個到庫';
  }

  @override
  String vibe_saveToLibrary_reused(int count) {
    return '從庫複用 $count 個';
  }

  @override
  String get vibe_saveToLibrary_saveAsBundle => '儲存為 Bundle';

  @override
  String vibe_saveToLibrary_saveAsBundleDescription(int count) {
    return '將 $count 個 Vibe 儲存為一個 Bundle';
  }

  @override
  String get vibe_saveToLibrary_tagHint => '輸入標籤後點選新增';

  @override
  String get vibe_maxReached => '已達到最大數量 (16張)';

  @override
  String vibe_addedNamed(String name) {
    return '已新增 Vibe: $name';
  }

  @override
  String vibe_addedCount(int count) {
    return '已新增 $count 個 vibes';
  }

  @override
  String get vibe_statusEncoded => '已編碼';

  @override
  String get vibe_statusEncoding => '編碼中...';

  @override
  String get vibe_statusPendingEncode => '待編碼 (2 Anlas)';

  @override
  String get vibe_statusNeedsReencode => '需重新編碼 (2 Anlas)';

  @override
  String get vibe_statusSourceImageRequired => '缺少原圖';

  @override
  String get vibe_encodeDialogTitle => '確認編碼 Vibe';

  @override
  String get vibe_encodeDialogMessage => '是否編碼此圖片以供生成使用？';

  @override
  String get vibe_encodeCostWarning => '此操作將消耗 2 Anlas（點數）';

  @override
  String get vibe_encodeButton => '編碼';

  @override
  String get vibe_encodeSuccess => 'Vibe 編碼成功！';

  @override
  String get vibe_encodeFailed => 'Vibe 編碼失敗，請重試';

  @override
  String vibe_encodeError(String error) {
    return '編碼失敗: $error';
  }

  @override
  String get shortcuts_customize => '自定義快捷鍵';

  @override
  String get image_editor_select_tool => '選擇工具';

  @override
  String get selection_clear_selection => '清除選區';

  @override
  String get selection_invert_selection => '反轉選區';

  @override
  String get selection_cut_to_layer => '剪下到新圖層';

  @override
  String get search_results => '搜尋結果';

  @override
  String get search_noResults => '未找到匹配結果';

  @override
  String get addToCurrent => '新增到當前';

  @override
  String get replaceExisting => '替換現有';

  @override
  String get confirmSelection => '確認選擇';

  @override
  String get selectAll => '全選';

  @override
  String get clearSelection => '清空';

  @override
  String get clearFilters => '清除篩選';

  @override
  String get shortcut_context_vibe_detail => 'Vibe 詳情';

  @override
  String get shortcut_action_vibe_detail_rename => '重新命名';

  @override
  String get vibeSelectorFilterFavorites => '收藏';

  @override
  String get vibeSelectorFilterSourceAll => '全部型別';

  @override
  String get vibeSelectorSortCreated => '建立時間';

  @override
  String get vibeSelectorSortLastUsed => '最近使用';

  @override
  String get vibeSelectorSortUsedCount => '使用次數';

  @override
  String get vibeSelectorSortName => '名稱';

  @override
  String vibeSelectorItemsCount(int count) {
    return '$count 項';
  }

  @override
  String get tray_show => '顯示視窗';

  @override
  String get tray_exit => '退出';

  @override
  String get settings_shortcutsSubtitle => '自定義鍵盤快捷鍵';

  @override
  String get settings_openFolder => '開啟資料夾';

  @override
  String get settings_openFolderFailed => '開啟資料夾失敗';

  @override
  String get settings_pleaseLoginFirst => '請先登入';

  @override
  String get settings_accountNotFound => '未找到賬號資訊';

  @override
  String get settings_goToLoginPage => '請前往登入頁面';

  @override
  String get settings_vibePathSaved => 'Vibe 庫路徑已儲存';

  @override
  String get settings_selectFolderFailed => '選擇資料夾失敗';

  @override
  String get settings_hivePathSaved => '資料儲存路徑已儲存，重啟後生效';

  @override
  String get settings_restartRequiredTitle => '需要重啟應用';

  @override
  String get settings_changePathConfirm =>
      '更改資料儲存路徑後，需要重啟應用才能生效。\\n\\n新路徑將在下次啟動時生效。是否繼續？';

  @override
  String get settings_resetPathConfirm =>
      '重置資料儲存路徑後，需要重啟應用才能生效。\\n\\n預設路徑將在下次啟動時生效。是否繼續？';

  @override
  String get settings_kritaBridgeEnable => '啟用 Krita 本地橋接';

  @override
  String get settings_kritaBridgeDisabledText => '預設關閉；開啟後只監聽本機 127.0.0.1';

  @override
  String get settings_kritaBridgeStartingText => '正在啟動本地橋接服務...';

  @override
  String get settings_kritaBridgeListeningText => '等待 Krita 外掛連線';

  @override
  String get settings_kritaBridgeConnectedText => 'Krita 外掛已連線';

  @override
  String get settings_kritaBridgeErrorText => '啟動失敗，請檢視錯誤資訊';

  @override
  String get settings_kritaBridgeDisabled => '已關閉';

  @override
  String get settings_kritaBridgeStarting => '啟動中';

  @override
  String get settings_kritaBridgeListening => '監聽中';

  @override
  String get settings_kritaBridgeConnected => '已連線';

  @override
  String get settings_kritaBridgeError => '錯誤';

  @override
  String get settings_kritaBridgeRegenerateSession => '重生成會話';

  @override
  String get settings_kritaBridgeDiscoveryFile => '發現檔案';

  @override
  String get settings_kritaBridgeWaitingEndpoint => '等待本地 WebSocket 監聽';

  @override
  String settings_kritaBridgeClient(Object client) {
    return '客戶端：$client';
  }

  @override
  String get settings_fontScale => '字型大小';

  @override
  String get settings_fontScale_description => '調整應用全域性字型縮放比例';

  @override
  String get settings_fontScale_previewSmall => '落霞與孤鶩齊飛';

  @override
  String get settings_fontScale_previewMedium => '秋水共長天一色';

  @override
  String get settings_fontScale_previewLarge => '字型大小預覽';

  @override
  String get settings_fontScale_reset => '重置';

  @override
  String get settings_fontScale_done => '完成';

  @override
  String get settings_generationLayout => '生成頁佈局';

  @override
  String get settings_generationLayout_classic => '經典佈局';

  @override
  String get settings_generationLayout_classicDescription => '引數在左側，提示詞位於預覽區上方';

  @override
  String get settings_generationLayout_webStyle => '官網式佈局';

  @override
  String get settings_generationLayout_webStyleDescription =>
      '提示詞與設定固定在最左欄，類似 NovelAI 官網';

  @override
  String get settings_historyClickBehavior => '歷史記錄點選行為';

  @override
  String get settings_historyClickBehavior_classic => '經典';

  @override
  String get settings_historyClickBehavior_classicDescription => '單擊歷史圖片直接開啟詳情';

  @override
  String get settings_historyClickBehavior_linked => '官網式聯動';

  @override
  String get settings_historyClickBehavior_linkedDescription =>
      '單擊切換中央預覽，雙擊或長按開啟詳情，並支援左右方向鍵瀏覽';

  @override
  String get image_viewDetail => '檢視詳情';

  @override
  String get discordShare_action => '分享到 Discord';

  @override
  String get discordShare_title => '分享到 Discord';

  @override
  String get discordShare_subtitle => '將圖片釋出到 Aaalice 社群頻道';

  @override
  String get discordShare_verifyTitle => '驗證 Discord 成員身份';

  @override
  String get discordShare_verifyDescription =>
      '分享前需要在瀏覽器中登入 Discord。應用只會取得你的公開身份和伺服器成員狀態。';

  @override
  String get discordShare_verifyButton => '前往 Discord 驗證';

  @override
  String get discordShare_verifying => '正在等待 Discord 驗證…';

  @override
  String get discordShare_verifyingHint => '請在瀏覽器中完成授權，然後返回應用。';

  @override
  String get discordShare_joinRequired => '請先加入 Aaalice Discord 伺服器';

  @override
  String get discordShare_joinDescription =>
      '只有伺服器成員可以向社群頻道分享圖片。加入後返回這裡重新驗證即可。';

  @override
  String get discordShare_joinServer => '加入 Discord 伺服器';

  @override
  String get discordShare_retryVerification => '重新驗證';

  @override
  String discordShare_account(Object name) {
    return '已驗證為 $name';
  }

  @override
  String get discordShare_disconnect => '解除 Discord 連線';

  @override
  String get discordShare_channels => '傳送頻道';

  @override
  String get discordShare_selectChannel => '至少選擇一個頻道';

  @override
  String get discordShare_caption => '圖像附言';

  @override
  String get discordShare_captionHint => '說點什麼，像貼文標題一樣（可選）';

  @override
  String get discordShare_promptCategories => '提示詞類別';

  @override
  String get discordShare_promptEditHint => '可在傳送前繼續編輯最終內容。切換類別會按圖片後設資料重新產生。';

  @override
  String get discordShare_promptContent => '傳送的提示詞';

  @override
  String get discordShare_noPromptMetadata => '這張圖片沒有可讀取的提示詞後設資料，仍可只分享圖片和附言。';

  @override
  String get discordShare_categoryMain => '主體';

  @override
  String get discordShare_categoryCharacters => '角色';

  @override
  String get discordShare_categoryQuality => '品質詞';

  @override
  String get discordShare_categoryFixed => '固定詞';

  @override
  String get discordShare_keepMetadata => '保留圖像後設資料';

  @override
  String get discordShare_keepMetadataHint =>
      '預設關閉。關閉時會清除 PNG 文字、EXIF 和 NAI 隱寫後設資料後再上傳。';

  @override
  String get discordShare_privacyHint => '傳送內容會上傳到 Discord；請檢查提示詞和附言中是否包含隱私資訊。';

  @override
  String get discordShare_send => '傳送到 Discord';

  @override
  String get discordShare_sending => '正在傳送…';

  @override
  String get discordShare_success => '已分享到 Discord';

  @override
  String get discordShare_partialSuccess => '部分頻道傳送成功，請檢查失敗頻道後重試';

  @override
  String discordShare_failed(Object error) {
    return '分享到 Discord 失敗：$error';
  }

  @override
  String get discordShare_errorNetwork => '無法連線 Discord 分享服務，請檢查網路後重試';

  @override
  String get discordShare_errorBrowser => '無法開啟瀏覽器，請檢查系統的預設瀏覽器設定';

  @override
  String get discordShare_errorTimeout => 'Discord 驗證已逾時，請重新驗證';

  @override
  String get discordShare_errorRateLimited => '分享過於頻繁，請稍後再試';

  @override
  String discordShare_errorRateLimitedRetry(int seconds) {
    return '分享過於頻繁，請在 $seconds 秒後重試';
  }

  @override
  String get discordShare_errorNoChannels => '目前沒有可用的 Discord 分享頻道';

  @override
  String get discordShare_errorSession => 'Discord 驗證已失效，請重新驗證';

  @override
  String get discordShare_errorRelay => 'Discord 分享服務暫時無法使用，請稍後再試';

  @override
  String get discordShare_errorImageRejected => 'Discord 拒絕了這張圖片，請檢查圖片大小或格式';

  @override
  String get discordShare_errorDelivery => 'Discord 頻道傳送失敗，請稍後重試';

  @override
  String get settings_defaultImagesPath =>
      '預設 (Documents/NAI_Launcher/images/)';

  @override
  String settings_defaultVibePath(Object path) {
    return '$path (預設)';
  }

  @override
  String get settings_defaultHivePath => '預設 (%APPDATA%/NAI_Launcher/hive/)';

  @override
  String get settings_protectionMode => '保護模式';

  @override
  String get settings_protectionModeSubtitle =>
      '開啟後按下方子項保護本地資產、分享副本、高消耗和高頻生圖操作；關閉時保留子項配置但不生效。';

  @override
  String get settings_protectionFeatures => '保護功能';

  @override
  String get settings_stripMetadataTitle => '複製/拖拽時移除全部後設資料';

  @override
  String get settings_stripMetadataSubtitle =>
      '生成淨化副本，清除 PNG 文字塊、EXIF 與 NAI 隱寫水印，並避免拖拽暴露原始路徑。';

  @override
  String get settings_confirmDangerousActionsTitle => '危險資產操作二次確認';

  @override
  String get settings_confirmDangerousActionsSubtitle =>
      '刪除、移動、批次移動等本地資產操作會額外彈出保護確認。';

  @override
  String get settings_warnExternalImageSendTitle => '傳送到外部服務前提示';

  @override
  String get settings_warnExternalImageSendSubtitle =>
      '把本地圖片傳送到 LLM、NovelAI、ComfyUI 等外部邊界前進行確認。';

  @override
  String get settings_preventOverwriteTitle => '匯出時避免覆蓋已有檔案';

  @override
  String get settings_preventOverwriteSubtitle => '匯出/打包路徑重名時自動編號，避免誤覆蓋原有資產。';

  @override
  String get settings_warnHighAnlasCostTitle => 'Anlas 高消耗警告';

  @override
  String settings_warnHighAnlasCostSubtitle(Object threshold) {
    return '單次生成預計消耗達到 $threshold Anlas 時，生成前彈出確認。';
  }

  @override
  String get settings_highAnlasCostThresholdTitle => 'Anlas 警告閾值';

  @override
  String get settings_setHighAnlasCostThresholdTitle => '設定 Anlas 警告閾值';

  @override
  String get settings_threshold => '閾值';

  @override
  String get settings_highAnlasCostThresholdHelper => '當單次生成預計消耗達到或超過該值時彈出確認。';

  @override
  String get settings_limitGenerationIntervalTitle => '限制生圖頻率';

  @override
  String get settings_limitGenerationIntervalSubtitle =>
      '開啟後，兩次生圖開始時間必須至少間隔設定秒數；冷卻期間生圖按鈕不可點選。';

  @override
  String get settings_generationIntervalTitle => '生圖間隔';

  @override
  String settings_generationIntervalValue(Object seconds) {
    return '$seconds 秒';
  }

  @override
  String get settings_setGenerationIntervalTitle => '設定生圖間隔';

  @override
  String get settings_generationIntervalHelper => '可設定 1–3600 秒，從開始執行生圖時計時。';

  @override
  String get settings_selectLocalOnnxTaggerFolder => '選擇 ONNX tagger 模型資料夾';

  @override
  String get settings_localOnnxTaggerFolderSaved => 'ONNX tagger 模型資料夾已儲存';

  @override
  String get settings_localOnnxTaggerFolder => '本地 ONNX tagger 模型';

  @override
  String get settings_notConfigured => '未配置';

  @override
  String get settings_confirmExternalSendTitle => '保護模式：確認外部傳送';

  @override
  String settings_confirmExternalSendContent(Object count, Object target) {
    return '即將把 $count 張本地圖片傳送到 $target。圖片會離開本地應用邊界，請確認這符合你的預期。';
  }

  @override
  String get settings_confirmExternalSend => '確認傳送';

  @override
  String get settings_highAnlasCostTitle => '保護模式：Anlas 消耗較高';

  @override
  String settings_highAnlasCostContent(Object cost, Object threshold) {
    return '本次預計消耗 $cost Anlas，已達到或超過你設定的 $threshold Anlas 警告閾值。請確認是否繼續生成。';
  }

  @override
  String get settings_continueGeneration => '繼續生成';

  @override
  String get settings_comfyUiEnable => '啟用 ComfyUI 整合';

  @override
  String get settings_comfyUiDisabledSubtitle => '關閉後將隱藏本地超分等 ComfyUI 功能';

  @override
  String get settings_comfyUiServerUrl => '伺服器地址';

  @override
  String get settings_comfyUiConnectionSuccess => '連線成功';

  @override
  String get settings_comfyUiConnectionSuccessFull => 'ComfyUI 連線成功';

  @override
  String settings_comfyUiConnectionFailed(Object error) {
    return '連線失敗: $error';
  }

  @override
  String get settings_comfyUiConnected => '已連線';

  @override
  String get settings_comfyUiDisconnect => '斷開';

  @override
  String get settings_comfyUiWorkflowManagement => '工作流管理';

  @override
  String get settings_comfyUiBuiltinWorkflows => '內建工作流';

  @override
  String get settings_comfyUiCustomWorkflows => '自定義工作流';

  @override
  String get settings_comfyUiNoCustomWorkflows =>
      '暫無自定義工作流，點選“匯入”新增 ComfyUI 工作流';

  @override
  String settings_comfyUiSlotCount(Object count) {
    return '$count 個槽位';
  }

  @override
  String get settings_comfyUiBuiltin => '內建';

  @override
  String get settings_comfyUiDeleteWorkflowTitle => '刪除工作流';

  @override
  String settings_comfyUiDeleteWorkflowContent(Object name) {
    return '確定要刪除工作流“$name”嗎？此操作不可撤銷。';
  }

  @override
  String settings_comfyUiDeleted(Object name) {
    return '已刪除: $name';
  }

  @override
  String get settings_comfyUiNoResponse => '伺服器無響應';

  @override
  String get settings_comfyUiStatusDisconnected => '未連線';

  @override
  String get settings_comfyUiStatusConnecting => '正在連線...';

  @override
  String get settings_comfyUiStatusConnected => '已連線';

  @override
  String get settings_comfyUiStatusError => '連線異常';

  @override
  String get settings_comfyUiCategoryEnhance => '增強/超分';

  @override
  String get settings_comfyUiCategoryImg2Img => '圖生圖';

  @override
  String get settings_comfyUiCategoryInpaint => '重繪';

  @override
  String get settings_comfyUiCategoryTxt2Img => '文生圖';

  @override
  String get settings_comfyUiCategoryCustom => '自定義';

  @override
  String get comfyWorkflow_seedvr2UpscaleName => 'SeedVR2 超分';

  @override
  String get comfyWorkflow_seedvr2UpscaleDescription =>
      '使用 SeedVR2 AI 模型進行超解析度放大，效果優秀';

  @override
  String get comfyWorkflow_seedvr2LegacyUpscaleName => 'SeedVR2 相容節點超分';

  @override
  String get comfyWorkflow_seedvr2LegacyUpscaleDescription =>
      '使用已安裝的 SeedVR2VideoUpscaler 自定義節點進行超分';

  @override
  String get comfyWorkflow_seedvr2TiledUpscaleName => 'SeedVR2 分塊超分';

  @override
  String get comfyWorkflow_seedvr2TiledUpscaleDescription =>
      '使用 SeedVR2TilingUpscaler 分塊放大，降低大圖視訊記憶體壓力';

  @override
  String get comfyWorkflow_modelUpscaleName => 'ComfyUI 普通超分模型';

  @override
  String get comfyWorkflow_modelUpscaleDescription =>
      '使用 ComfyUI UpscaleModelLoader 載入普通超分模型，並用 Lanczos 修正最終倍率';

  @override
  String get comfyWorkflow_rtxUpscaleName => 'RTX 超分';

  @override
  String get comfyWorkflow_rtxUpscaleDescription =>
      '使用 Nvidia RTX Video Super Resolution 節點進行本地放大';

  @override
  String get comfyWorkflowSlot_inputImage => '輸入影象';

  @override
  String get comfyWorkflowSlot_targetShortSide => '目標短邊';

  @override
  String get comfyWorkflowSlot_targetLongSide => '目標長邊';

  @override
  String get comfyWorkflowSlot_upscaleModel => '超分模型';

  @override
  String get comfyWorkflowSlot_randomSeed => '隨機種子';

  @override
  String get comfyWorkflowSlot_outputImage => '輸出影象';

  @override
  String get comfyWorkflowSlot_tileWidth => '圖塊寬度';

  @override
  String get comfyWorkflowSlot_tileHeight => '圖塊高度';

  @override
  String get comfyWorkflowSlot_tileUpscaleResolution => '圖塊超分解析度';

  @override
  String get comfyWorkflowSlot_targetWidth => '目標寬度';

  @override
  String get comfyWorkflowSlot_targetHeight => '目標高度';

  @override
  String get comfyWorkflowSlot_scale => '放大倍數';

  @override
  String get comfyWorkflow_parameters => '引數設定';

  @override
  String get comfyWorkflow_selectImage => '點選選擇影象';

  @override
  String comfyWorkflow_pickImageFailed(Object error) {
    return '選擇影象失敗: $error';
  }

  @override
  String get comfyWorkflow_useResult => '使用結果';

  @override
  String get comfyWorkflow_execute => '執行';

  @override
  String get comfyWorkflow_uploadingImage => '正在上傳影象...';

  @override
  String get comfyWorkflow_queued => '排隊中...';

  @override
  String comfyWorkflow_runningSteps(Object current, Object total) {
    return '處理中 $current/$total';
  }

  @override
  String get comfyWorkflow_processing => '處理中...';

  @override
  String get comfyWorkflow_complete => '執行完成';

  @override
  String comfyWorkflow_imageCount(Object count) {
    return '$count 張影象';
  }

  @override
  String get promptAssistant_defaultOptimizeRuleName => '預設最佳化規則';

  @override
  String get promptAssistant_defaultOptimizeRuleContent =>
      '你是提示詞最佳化助手。保留使用者意圖，補充可執行的視覺細節，並只輸出一行可直接使用的逗號分隔提示詞。';

  @override
  String get promptAssistant_defaultTranslateRuleName => '預設翻譯規則';

  @override
  String get promptAssistant_defaultTranslateRuleContent =>
      '你是翻譯助手。自動識別源語言，在中文和英文之間翻譯，並只返回譯文，不要解釋。';

  @override
  String get promptAssistant_defaultReverseRuleName => '預設反推規則';

  @override
  String get promptAssistant_defaultReverseRuleContent =>
      '你是影象反推提示詞助手。根據影象和可選 tagger 結果，輸出適用於 NovelAI 的英文逗號分隔提示詞。保留主體、角色、風格、服裝、動作、構圖、光照和背景。不要解釋。';

  @override
  String get promptAssistant_defaultCharacterReplaceRuleName => '預設角色替換規則';

  @override
  String get promptAssistant_defaultCharacterReplaceRuleContent =>
      '你是角色替換助手。將輸入提示詞中的原角色身份、髮型、服裝和外觀替換為目標角色，同時保留動作、構圖、背景、風格、鏡頭和質量標籤。只輸出替換後的一行提示詞。';

  @override
  String get promptAssistant_defaultCustomRuleName => '預設自定義規則';

  @override
  String get promptAssistant_defaultCustomRuleContent =>
      '你是提示詞改寫助手。根據當前提示詞、使用者需求和可選參考圖修改提示詞。只輸出最終可直接使用的一行提示詞，不要解釋。';

  @override
  String get localGallery_dateFilterButton => '日期過濾';

  @override
  String get cacheStats_title => '快取統計';

  @override
  String cacheStats_autoRefreshUpdated(Object time) {
    return '自動重新整理 · 上次更新: $time';
  }

  @override
  String cacheStats_secondsAgo(Object seconds) {
    return '$seconds秒前';
  }

  @override
  String get cacheStats_refreshNow => '立即重新整理';

  @override
  String get cacheStats_refreshed => '已重新整理';

  @override
  String get cacheStats_resetStats => '重置統計';

  @override
  String get cacheStats_statsReset => '統計已重置';

  @override
  String get cacheStats_l1Memory => 'L1 記憶體快取';

  @override
  String get cacheStats_l2Hive => 'L2 Hive 快取';

  @override
  String get cacheStats_l3Sqlite => 'L3 SQLite 資料庫';

  @override
  String cacheStats_recordCount(Object count) {
    return '$count 條記錄';
  }

  @override
  String cacheStats_databaseValue(Object imageCount, Object metadataCount) {
    return '$imageCount 張圖片 · $metadataCount 條後設資料';
  }

  @override
  String get galleryCache_rescanTitle => '重新掃描畫廊';

  @override
  String get galleryCache_rescanContent =>
      '這將執行以下操作：\n\n1. 檢查資料一致性（標記不存在的檔案）\n2. 掃描新檔案和變更的檔案\n3. 重新嘗試歷史上未提取成功的後設資料（含失敗記錄）\n\n此操作不會清空已有資料，也不會刪除圖片檔案。';

  @override
  String get galleryCache_startScan => '開始掃描';

  @override
  String get galleryCache_scanAlreadyRunning => '已有掃描任務在進行中，請等待完成後再試';

  @override
  String get galleryCache_preparing => '準備中...';

  @override
  String get galleryCache_noGalleryFolder => '未設定畫廊目錄';

  @override
  String get galleryCache_galleryFolderMissing => '畫廊目錄不存在';

  @override
  String galleryCache_scanningPhase(Object processed, Object total) {
    return '正在掃描 $processed/$total...';
  }

  @override
  String get galleryCache_scanComplete => '掃描完成';

  @override
  String galleryCache_scanFailed(Object error) {
    return '掃描失敗: $error';
  }

  @override
  String get galleryCache_rescan => '重新掃描';

  @override
  String get galleryCache_rescanSubtitle => '檢查資料一致性、查漏補缺、提取後設資料';

  @override
  String get galleryCache_scanning => '正在掃描...';

  @override
  String get galleryCache_scanAction => '掃描';

  @override
  String get workflowImport_title => '匯入 ComfyUI 工作流';

  @override
  String workflowImport_step(Object current, Object title) {
    return '步驟 $current/4: $title';
  }

  @override
  String get workflowImport_stepFile => '選擇工作流檔案';

  @override
  String get workflowImport_stepInfo => '工作流資訊';

  @override
  String get workflowImport_stepSlots => '確認槽位配置';

  @override
  String get workflowImport_stepDone => '完成匯入';

  @override
  String get workflowImport_previous => '上一步';

  @override
  String get workflowImport_next => '下一步';

  @override
  String get workflowImport_finish => '完成匯入';

  @override
  String get workflowImport_defaultName => '自定義工作流';

  @override
  String get workflowImport_fileInstructions =>
      '請選擇 ComfyUI 匯出的 workflow_api.json 檔案。\n\n在 ComfyUI 中，點選選單 → 匯出 (API格式) 即可獲得此檔案。';

  @override
  String workflowImport_nodeCount(Object count) {
    return '$count 個節點';
  }

  @override
  String get workflowImport_reselect => '點選重新選擇';

  @override
  String get workflowImport_selectWorkflowApi => '點選選擇 workflow_api.json';

  @override
  String get workflowImport_invalidTopLevel => '檔案格式無效：頂層應為 JSON 物件';

  @override
  String get workflowImport_noComfyNodes => '未檢測到 ComfyUI 節點，請確認是 API 格式匯出';

  @override
  String workflowImport_readFailed(Object error) {
    return '讀取檔案失敗: $error';
  }

  @override
  String get workflowImport_analysisResult => '自動分析結果';

  @override
  String get workflowImport_inputImageNodes => '輸入影象節點';

  @override
  String get workflowImport_adjustableParams => '可調引數';

  @override
  String get workflowImport_outputNodes => '輸出節點';

  @override
  String get workflowImport_totalNodes => '總節點數';

  @override
  String workflowImport_countUnit(Object count) {
    return '$count 個';
  }

  @override
  String get workflowImport_workflowName => '工作流名稱 *';

  @override
  String get workflowImport_description => '描述';

  @override
  String get workflowImport_category => '分類';

  @override
  String get workflowImport_slotsHint =>
      '勾選需要暴露給 UI 的槽位。輸入/輸出槽位建議保留；不需要使用者調整的引數可以取消勾選。';

  @override
  String get workflowImport_inputSection => '輸入';

  @override
  String get workflowImport_outputSection => '輸出';

  @override
  String get workflowImport_parameterSection => '引數';

  @override
  String get workflowImport_noSlotsWarning =>
      '未檢測到任何可用槽位。該工作流可能無法正常整合。\n請確認工作流中包含 LoadImage 和 SaveImage/SaveImageWebsocket 節點。';

  @override
  String workflowImport_nodeRef(Object node) {
    return '節點 $node';
  }

  @override
  String get workflowImport_confirmTitle => '即將匯入以下工作流';

  @override
  String get workflowImport_name => '名稱';

  @override
  String get workflowImport_inputSlots => '輸入槽位';

  @override
  String get workflowImport_parameterSlots => '引數槽位';

  @override
  String get workflowImport_outputSlots => '輸出槽位';

  @override
  String get workflowImport_afterImportHint => '匯入後可在生成介面的 ComfyUI 工作流列表中使用。';

  @override
  String workflowImport_success(Object name) {
    return '工作流“$name”匯入成功';
  }

  @override
  String get shortcut_settings_help => '檢視快捷鍵幫助';

  @override
  String get shortcut_settings_show_in_menus => '在選單中顯示';

  @override
  String shortcut_settings_defaultShortcut(Object shortcut) {
    return '預設: $shortcut';
  }

  @override
  String get shortcut_settings_unassigned => '未設定';

  @override
  String get shortcut_settings_no_matches => '未找到匹配的快捷鍵';

  @override
  String get shortcut_settings_reset_all_title => '重置所有快捷鍵';

  @override
  String get shortcut_settings_reset_all_confirm =>
      '確定要將所有快捷鍵重置為預設設定嗎？此操作不可撤銷。';

  @override
  String get shortcut_settings_reset_to_default => '重置為預設';

  @override
  String get toast_previewUpdated => '預覽圖已更新';

  @override
  String toast_styleReferenceLimit(Object max) {
    return '風格參考已達上限 ($max 張)';
  }

  @override
  String get toast_noValidPromptFound => '未找到有效的提示詞';

  @override
  String toast_addedToQueue(Object prompt) {
    return '已加入佇列: $prompt';
  }

  @override
  String get toast_noValidMaskIgnored => '沒有檢測到有效蒙版，儲存結果已忽略。';

  @override
  String get toast_kritaBusy => 'Krita Bridge 正在生成，請等待當前任務結束';

  @override
  String get toast_kritaNotConnected => 'Krita 未連線，請先在設定中啟用橋接並連線外掛';

  @override
  String get toast_sentToKrita => '圖片已傳送到 Krita';

  @override
  String get toast_kritaUnsupportedImageFormat => '圖片格式無法傳送到 Krita，請換用常見圖片格式';

  @override
  String toast_deletedNamed(Object name) {
    return '已刪除: $name';
  }

  @override
  String get toast_vibeParamSaveReencodeFailed => '儲存引數失敗，Vibe 重新編碼失敗';

  @override
  String get toast_exportSuccess => '匯出成功';

  @override
  String toast_exportFailed(Object error) {
    return '匯出失敗: $error';
  }

  @override
  String get toast_selectVibeToExport => '請先選擇要匯出的 Vibe';

  @override
  String get toast_embedPngSingleVibeOnly => '嵌入 PNG 僅支援單個 Vibe 匯出';

  @override
  String get toast_selectPngCarrier => '請選擇一個 PNG 載體圖用於匯出';

  @override
  String get toast_renameSuccess => '重新命名成功';

  @override
  String get toast_paramsSaved => '引數已儲存';

  @override
  String get toast_paramsSaveFailed => '儲存引數失敗';

  @override
  String get toast_dropNoReadableImageOrVibe => '拖入源未提供可讀取的圖片或 Vibe 檔案';

  @override
  String get toast_contentCannotBeEmpty => '內容不能為空';

  @override
  String get toast_addedToLibrary => '已新增到詞庫';

  @override
  String toast_addFailed(Object error) {
    return '新增失敗: $error';
  }

  @override
  String get toast_libraryNotLoaded => '詞庫未載入';

  @override
  String get toast_noValidTagContent => '沒有有效的標籤內容';

  @override
  String get toast_allTagsAlreadyExist => '所有標籤已存在於詞庫中';

  @override
  String get toast_noAddableTags => '沒有可新增的標籤';

  @override
  String toast_addedTagsSkippedDuplicates(Object added, Object skipped) {
    return '已新增 $added 個標籤，跳過 $skipped 個重複標籤';
  }

  @override
  String get toast_favorited => '已收藏';

  @override
  String get toast_unfavorited => '已取消收藏';

  @override
  String toast_favoriteUpdateFailed(Object error) {
    return '收藏狀態更新失敗: $error';
  }

  @override
  String toast_packingImages(Object count) {
    return '正在打包 $count 張圖片...';
  }

  @override
  String toast_packedImages(Object count) {
    return '已打包 $count 張圖片';
  }

  @override
  String get toast_packFailed => '打包失敗';

  @override
  String toast_packFailedWithError(Object error) {
    return '打包失敗: $error';
  }

  @override
  String get toast_saveDirNotSet => '未設定儲存目錄';

  @override
  String toast_savedTo(Object path) {
    return '已儲存到 $path';
  }

  @override
  String get toast_tagAlreadyExists => '標籤已存在';

  @override
  String get toast_nameRequired => '請輸入名稱';

  @override
  String get toast_savedToVibeLibrary => '已儲存到 Vibe 庫';

  @override
  String get toast_saveBundleFailed => '儲存組合失敗';

  @override
  String get toast_saveEntryFailed => '儲存條目失敗';

  @override
  String get toast_presetNameRequired => '請輸入預設名稱';

  @override
  String get toast_selectPresetContent => '請至少選擇一項要儲存的內容';

  @override
  String get toast_presetSaved => '預設儲存成功';

  @override
  String get toast_imagePromptCopied => '已複製 Prompt';

  @override
  String get toast_imageHasNoPrompt => '此圖片沒有 Prompt';

  @override
  String get toast_useDeleteButton => '請使用介面刪除按鈕';

  @override
  String get toast_imageHasNoMetadata => '此圖片沒有後設資料';

  @override
  String get toast_imageDataUnavailable => '影象資料不可用，無法複製';

  @override
  String get toast_vibeDataCopied => 'Vibe 資料已複製';

  @override
  String get toast_tagCopied => '標籤已複製';

  @override
  String get toast_characterPromptCopied => '角色提示詞已複製';

  @override
  String toast_copiedTitle(Object title) {
    return '$title已複製';
  }

  @override
  String toast_replacedVibesCount(Object count, Object name) {
    return '已替換為 $count 個 Vibe: $name';
  }

  @override
  String toast_sentVibesCount(Object count, Object name) {
    return '已傳送 $count 個 Vibe 到生成頁面: $name';
  }

  @override
  String toast_replacedVibe(Object name) {
    return '已替換為: $name';
  }

  @override
  String toast_sentVibeToGeneration(Object name) {
    return '已傳送到生成頁面: $name';
  }

  @override
  String get toast_unreadableDroppedImageSource => '拖入源未提供可讀取的圖片檔案或圖片連結';

  @override
  String toast_appendedStyleReferences(Object count) {
    return '已追加 $count 個風格參考';
  }

  @override
  String get toast_appendedPreencodedVibe => '已追加 1 個風格參考（複用預編碼 Vibe）';

  @override
  String get toast_addedPreencodedVibe => '已新增風格參考（複用預編碼 Vibe，節省 2 Anlas）';

  @override
  String toast_vibesMissingEncoding(Object count) {
    return '$count 個 Vibe 缺少編碼資料，無法儲存';
  }

  @override
  String toast_savedBundle(Object count) {
    return '已儲存 Bundle ($count 個 Vibe)';
  }

  @override
  String toast_extractMetadataFailed(Object error) {
    return '提取後設資料失敗: $error';
  }

  @override
  String toast_extractPromptFailed(Object error) {
    return '提取提示詞失敗: $error';
  }

  @override
  String get toast_smartDecomposeSent => '已智慧分解併傳送';

  @override
  String get toast_addedToFixedTags => '已新增到固定詞';

  @override
  String get toast_renameNameRequired => '名稱不能為空';

  @override
  String get toast_renameNameConflict => '名稱已存在，請使用其他名稱';

  @override
  String get toast_renameEntryNotFound => '條目不存在，可能已被刪除';

  @override
  String get toast_renameFilePathMissing => '該條目缺少檔案路徑，無法重新命名';

  @override
  String get toast_renameFileFailed => '重新命名檔案失敗，請稍後重試';

  @override
  String get toast_renameFailed => '重新命名失敗，請稍後重試';

  @override
  String toast_processImageFailed(Object error) {
    return '處理圖片失敗: $error';
  }

  @override
  String get toast_savePreviewFailed => '儲存預覽圖失敗';

  @override
  String get common_justNow => '剛剛';

  @override
  String common_minutesAgo(Object minutes) {
    return '$minutes分鐘前';
  }

  @override
  String common_hoursAgo(Object hours) {
    return '$hours小時前';
  }

  @override
  String get common_saving => '儲存中...';

  @override
  String get common_pleaseWait => '請稍候';

  @override
  String get common_change => '更換';

  @override
  String get common_expand => '展開';

  @override
  String get common_collapse => '收起';

  @override
  String get vibeLibrary_emptySearchTitle => '未找到匹配的 Vibe';

  @override
  String get vibeLibrary_emptySearchSubtitle => '嘗試其他關鍵詞';

  @override
  String get vibeLibrary_emptyFavoritesTitle => '暫無收藏的 Vibe';

  @override
  String get vibeLibrary_emptyFavoritesSubtitle => '點選心形圖示收藏 Vibe';

  @override
  String get vibeLibrary_emptyCategoryTitle => '該分類下暫無 Vibe';

  @override
  String get vibeLibrary_emptyCategorySubtitle => '嘗試切換到\"全部 Vibe\"檢視所有內容';

  @override
  String get vibeLibrary_emptyNoMatchesTitle => '無匹配結果';

  @override
  String get vibeLibrary_emptySaveFromGenerationHint => '可從檔案匯入，或從生成頁面儲存 Vibe';

  @override
  String get vibe_nameRequired => '名稱不能為空';

  @override
  String get vibe_import_namingTitle => '命名 Vibe';

  @override
  String get vibe_import_nameConflictOverwrite => '該名稱已存在，將被覆蓋';

  @override
  String get vibe_previewLoadFailed => '預覽載入失敗';

  @override
  String get vibe_import_applyToRemainingFiles => '應用到後續所有檔案';

  @override
  String get vibe_import_applyNamingToRemainingFiles => '使用此命名規則處理剩餘檔案';

  @override
  String get vibe_encodeImageTitle => '編碼圖片為 Vibe';

  @override
  String get vibe_imagePreview => '圖片預覽';

  @override
  String get vibe_encodeStartButton => '開始編碼';

  @override
  String get vibe_encodeImageInProgress => '正在編碼圖片...';

  @override
  String vibe_encodeErrorImage(Object fileName) {
    return '圖片: $fileName';
  }

  @override
  String vibe_encodeErrorMessage(Object error) {
    return '錯誤: $error';
  }

  @override
  String get vibe_encodeSkipImage => '跳過此圖';

  @override
  String get detail_sendToImg2Img => '傳送到圖生圖';

  @override
  String get detail_sendToReversePrompt => '傳送到反推';

  @override
  String get detail_loadingImage => '載入圖片中...';

  @override
  String get detail_imageLoadFailed => '無法載入圖片';

  @override
  String get detail_noImage => '無圖片';

  @override
  String get detail_parsingMetadata => '正在解析後設資料...';

  @override
  String get detail_noMetadata => '此圖片無後設資料';

  @override
  String get detail_metadata => '後設資料';

  @override
  String get detail_imageDetails => '圖片詳情';

  @override
  String get detail_basicInfo => '基本資訊';

  @override
  String get detail_fileName => '檔名';

  @override
  String get detail_modifiedTime => '修改時間';

  @override
  String get detail_fileSize => '檔案大小';

  @override
  String get detail_noContent => '(無內容)';

  @override
  String get detail_savePreset => '儲存預設';

  @override
  String detail_copyLabel(Object label) {
    return '複製$label';
  }

  @override
  String get detail_copyPromptTitle => '複製正面提示詞';

  @override
  String get detail_copyPromptDescription =>
      '勾選需要複製的提示詞類別。固定詞可能包含私密字串或個人標記，請確認後再分享。';

  @override
  String get detail_promptCategoryMain => '主體提示詞';

  @override
  String get detail_promptCategoryMainHint => '畫面主體、場景和一般描述';

  @override
  String get detail_promptCategoryCharacters => '角色提示詞';

  @override
  String get detail_promptCategoryCharactersHint => '多角色專用提示詞';

  @override
  String get detail_promptCategoryQuality => '品質提示詞';

  @override
  String get detail_promptCategoryQualityHint => '官方品質預設與透明背景自動詞';

  @override
  String get detail_promptCategoryFixed => '固定詞';

  @override
  String get detail_promptCategoryFixedHint => '固定前綴和後綴，可能包含私密內容';

  @override
  String get detail_promptCategoryUnavailable => '此圖片未記錄該類別';

  @override
  String get detail_copyPromptDefaultHint => '預設複製主體和角色提示詞，不包含品質詞與固定詞。';

  @override
  String get detail_copyCharacterPrompt => '複製角色提示詞';

  @override
  String get detail_copyAllVibeData => '複製全部 Vibe 資料';

  @override
  String get detail_saveToVibeLibrary => '儲存到 Vibe 庫';

  @override
  String get pagination_firstPage => '首頁';

  @override
  String get pagination_previousPage => '上一頁';

  @override
  String get pagination_nextPage => '下一頁';

  @override
  String get pagination_lastPage => '末頁';

  @override
  String get pagination_jumpToPage => '跳轉到頁面';

  @override
  String get pagination_jump => '跳轉';

  @override
  String get pagination_itemsPerPage => '每頁';

  @override
  String get pagination_itemUnit => '項';

  @override
  String get diyGuide_title => 'DIY 功能指南';

  @override
  String get diyGuide_subtitle => '瞭解高階功能，建立專屬詞庫';

  @override
  String get diyGuide_intro => '本指南介紹了 DIY 系統的核心概念和高階功能，幫助您構建強大的動態提示詞庫。';

  @override
  String get diyGuide_exampleLabel => '示例';

  @override
  String get diyGuide_hierarchyTitle => '層級結構 (Hierarchy)';

  @override
  String get diyGuide_hierarchyDescription => 'DIY 系統採用三級分類結構來組織提示詞，便於管理和檢索。';

  @override
  String get diyGuide_hierarchyExample =>
      'Category (分類): 角色特徵\n  -> Group (分組): 髮型\n      -> Tag (標籤): 長髮, 短髮, 雙馬尾';

  @override
  String get diyGuide_selectionModeTitle => '選擇模式 (Selection Mode)';

  @override
  String get diyGuide_selectionModeDescription => '決定從一個分組(Group)中選取多少個標籤。';

  @override
  String get diyGuide_selectionModeExample =>
      '• Random (隨機): 每次隨機選取一個 (如：隨機發色)\n• All (全選): 選取組內所有標籤 (如：固定特徵組合)';

  @override
  String get diyGuide_weightTitle => '權重控制 (Weight)';

  @override
  String get diyGuide_weightDescription => '調整特定提示詞在生成過程中的影響力。';

  @override
  String get diyGuide_weightExample =>
      '• 增強: 用花括號包裹 masterpiece = 1.05 倍權重\n• 強力增強: 三層花括號包裹 masterpiece = 1.16 倍權重\n• 減弱: [bad hands] = 0.95 倍權重';

  @override
  String get diyGuide_genderTitle => '性別限制 (Gender)';

  @override
  String get diyGuide_genderDescription => '限制標籤僅對特定性別的角色生效，避免生成錯誤的特徵。';

  @override
  String get diyGuide_genderExample =>
      '• Female: 僅女性角色可用 (如：裙子)\n• Male: 僅男性角色可用 (如：鬍鬚)\n• Any: 通用 (如：T恤)';

  @override
  String get diyGuide_scopeTitle => '作用域 (Scope)';

  @override
  String get diyGuide_scopeDescription => '定義標籤是作用於角色本身、背景環境還是全域性畫面。';

  @override
  String get diyGuide_scopeExample =>
      '• Character: 角色特徵 (眼睛, 頭髮)\n• Background: 環境描述 (藍天, 室內)\n• Global: 畫風, 質量詞 (best quality)';

  @override
  String get diyGuide_conditionalTitle => '條件分支 (Conditional)';

  @override
  String get diyGuide_conditionalDescription => '基於已選標籤或其他條件來動態決定後續標籤。';

  @override
  String get diyGuide_conditionalExample =>
      'IF (已選 \"下雨\")\n  THEN 新增 \"雨傘\", \"溼衣服\"\n  ELSE 新增 \"晴朗\"';

  @override
  String get diyGuide_dependenciesTitle => '依賴引用 (Dependencies)';

  @override
  String get diyGuide_dependenciesDescription =>
      '建立標籤間的關聯，選中一個標籤時自動引入相關聯的其他標籤。';

  @override
  String get diyGuide_dependenciesExample =>
      '選中 \"JK制服\" -> 自動引入 \"學校背景\", \"書包\"';

  @override
  String get diyGuide_visibilityTitle => '可見性規則 (Visibility)';

  @override
  String get diyGuide_visibilityDescription => '控制標籤在介面上的顯示條件，或在生成時的生效條件。';

  @override
  String get diyGuide_visibilityExample => '僅當選中 \"魔法少女\" 分類時，顯示 \"魔杖\" 選項組';

  @override
  String get diyGuide_timeTitle => '時間條件 (Time)';

  @override
  String get diyGuide_timeDescription => '根據現實時間或設定的模擬時間觸發特定標籤。';

  @override
  String get diyGuide_timeExample =>
      '• 06:00-18:00 -> 新增 \"daylight\"\n• 18:00-06:00 -> 新增 \"night\"';

  @override
  String get diyGuide_postProcessingTitle => '後處理規則 (Post-processing)';

  @override
  String get diyGuide_postProcessingDescription => '在提示詞生成最後階段進行文字替換或清理。';

  @override
  String get diyGuide_postProcessingExample =>
      '將所有 \"blue eyes\" 替換為 \"azure eyes\" 以獲得更獨特的描述';

  @override
  String get diyGuide_emphasisTitle => '強調機率 (Emphasis)';

  @override
  String get diyGuide_emphasisDescription => '為標籤隨機新增權重符號的機率，增加結果的多樣性。';

  @override
  String get diyGuide_emphasisExample =>
      '設定 30% 機率: 約有 1/3 的機會輸出加權 tag，2/3 的機會輸出普通 tag';

  @override
  String get naiRules_title => 'NAI 隨機規則說明';

  @override
  String get naiRules_characterCountProbability => '角色數量機率';

  @override
  String get naiRules_solo => '1人 (Solo)';

  @override
  String get naiRules_duo => '2人 (Duo)';

  @override
  String get naiRules_trio => '3人 (Trio)';

  @override
  String get naiRules_group => '4人 (Group)';

  @override
  String get naiRules_genderRules => '性別規則';

  @override
  String get naiRules_female => '女性 (Female)';

  @override
  String get naiRules_male => '男性 (Male)';

  @override
  String get naiRules_mixed => '混合/其他 (Mixed)';

  @override
  String get naiRules_categoryProbability => '類別機率';

  @override
  String get naiRules_dynamicTagWeightTitle => '標籤權重動態調整';

  @override
  String get naiRules_dynamicTagWeightSubtitle =>
      '包含動作、服飾、表情、背景等多個維度的隨機組合，根據畫面主題動態調整各類別的抽取權重';

  @override
  String get naiRules_specialMechanisms => '特殊機制';

  @override
  String get naiRules_tagStrengthening => '強調機制 (Tag Strengthening)';

  @override
  String get naiRules_seasonalLibraryTitle => '季節詞庫';

  @override
  String get naiRules_seasonalLibrarySubtitle =>
      '自動匹配季節特徵，包含季節性服飾、天氣、光照效果和環境氛圍';

  @override
  String get naiRules_v4CharacterPositioning => 'V4 多角色位置';

  @override
  String get naiRules_smartPositionTitle => '智慧位置分配';

  @override
  String get naiRules_smartPositionSubtitle =>
      '在 V4 模型下，使用 character positioning 語法精確控制多角色站位';

  @override
  String get comfyImport_detectedTitle => '檢測到 ComfyUI 多角色提示詞';

  @override
  String comfyImport_characterList(Object count) {
    return '角色列表 ($count)';
  }

  @override
  String get comfyImport_usePositionInfo => '使用位置資訊';

  @override
  String get comfyImport_usePositionInfoSubtitle => '將 ComfyUI 區域對映為 NAI 角色位置';

  @override
  String comfyImport_convertCharacters(Object count) {
    return '轉換 $count 個角色';
  }

  @override
  String get comfyImport_syntaxCouple => 'COUPLE 語法';

  @override
  String get comfyImport_syntaxAndMask => 'AND+MASK 語法';

  @override
  String get comfyImport_syntaxPipe => '豎線格式';

  @override
  String get comfyImport_syntaxUnknown => '未知語法';

  @override
  String get comfyImport_globalPrompt => '全域性提示詞';

  @override
  String get danbooruPreview_noTagData => '暫無標籤資料';

  @override
  String get danbooruPreview_noPoolData => '暫無 Pool 資料';

  @override
  String danbooruPreview_postCount(Object count) {
    return '$count 個帖子';
  }

  @override
  String get checkForUpdate => '檢查更新';

  @override
  String get neverChecked => '從未檢查';

  @override
  String lastCheckedAt(Object time) {
    return '上次檢查: $time';
  }

  @override
  String get includePrereleaseUpdates => '包含預釋出版本';

  @override
  String get includePrereleaseUpdatesDescription => '檢查更新時包含 beta/alpha 版本';

  @override
  String get updateAvailable => '發現新版本';

  @override
  String get updateChecking => '正在檢查更新...';

  @override
  String get updateDownloading => '正在下載更新...';

  @override
  String get updateInstalling => '正在啟動安裝器...';

  @override
  String get updateUpToDate => '已是最新版本';

  @override
  String get updateError => '檢查更新失敗';

  @override
  String get updateErrorNetwork => '無法連線更新伺服器，請檢查網路或代理設定後重試。';

  @override
  String get updateErrorServerBusy => '更新伺服器請求繁忙，請稍後重試。';

  @override
  String get updateErrorReleaseNotReady => '最新版本的釋出檔案尚未就緒，請稍後重試。';

  @override
  String get updateErrorServiceUnavailable => '更新伺服器暫時不可用，請稍後重試。';

  @override
  String get updateErrorInvalidMetadata => '更新資訊校驗失敗，請稍後重試或前往 Release 頁面下載。';

  @override
  String get updateErrorUnknown => '暫時無法檢查更新，請稍後重試。';

  @override
  String get currentVersion => '當前版本';

  @override
  String get latestVersion => '最新版本';

  @override
  String get releaseNotes => '更新日誌';

  @override
  String get viewReleasePage => '查看 Release';

  @override
  String get updatePortableManualHint => '當前構建不支援應用內更新，請前往 Release 頁面手動下載新版。';

  @override
  String updateDownloadingProgress(Object percent) {
    return '正在下載更新包：$percent%';
  }

  @override
  String updateDownloadSizeSpeed(Object received, Object total, Object speed) {
    return '$received / $total · $speed';
  }

  @override
  String get updateDownloaded => '更新包已就緒';

  @override
  String updateDownloadedHint(Object version) {
    return '新版本 v$version 已下載並透過校驗。安裝將關閉應用，完成後會自動重啟。';
  }

  @override
  String get updateInstallAndRestart => '安裝並重啟';

  @override
  String get updateInstallNow => '立即安裝';

  @override
  String get updateInstallLater => '稍後安裝';

  @override
  String get updateDownload => '下載更新';

  @override
  String get updateDownloadCancelled => '已取消下載，稍後可繼續';

  @override
  String get updateDownloadFailed => '下載更新失敗';

  @override
  String get updateInstallFailed => '安裝更新失敗';

  @override
  String get updateInstallingHint => '安裝程式已啟動，應用即將關閉並自動完成更新。';

  @override
  String get updateInstallConfirmationTitle => '現在安裝更新？';

  @override
  String get updateInstallConfirmationBody =>
      '應用將安全關閉並安裝更新，完成後自動重新啟動。進行中的生成和下載任務會停止，請先儲存必要內容。';

  @override
  String get updateActiveTasksWarning => '檢測到佇列任務仍在執行，安裝會停止當前任務。';

  @override
  String get remindMeLater => '4 小時後提醒';

  @override
  String get skipThisVersion => '忽略此版本';

  @override
  String updateNoticeAvailable(Object version) {
    return '新版本 v$version 可用';
  }

  @override
  String get updateNoticeAvailableSubtitle => '可在應用內下載、校驗並安全安裝更新';

  @override
  String get updateNoticeManualSubtitle => '當前平臺需要前往 Release 頁面手動更新';

  @override
  String updateNoticeReady(Object version) {
    return '新版本 v$version 已準備好';
  }

  @override
  String get updateNoticeReadySubtitle => '更新包已校驗，可以立即安裝';

  @override
  String get updateNoticeFailed => '上次更新沒有完成';

  @override
  String get updateViewDetails => '檢視更新';

  @override
  String updateSettingsAvailable(Object version) {
    return '發現 v$version，點選檢視更新內容';
  }

  @override
  String updateSettingsReady(Object version) {
    return 'v$version 已下載，點選安裝';
  }

  @override
  String get goToDownload => '前往下載';

  @override
  String get versionSkipped => '已忽略此版本';

  @override
  String get cannotOpenUrl => '無法開啟連結';

  @override
  String get model3d_editorTitle => '3D 模型圖層';

  @override
  String get model3d_addMannequin => '新增內建人偶';

  @override
  String get model3d_importModel => '匯入模型 (.glb/.gltf)';

  @override
  String get model3d_emptyHint => '場景為空，先新增人偶或匯入模型';

  @override
  String get model3d_apply => '應用到圖層';

  @override
  String get model3d_modeTransform => '變換';

  @override
  String get model3d_modePose => '姿勢';

  @override
  String get model3d_gizmoTranslate => '移動';

  @override
  String get model3d_gizmoRotate => '旋轉';

  @override
  String get model3d_gizmoScale => '縮放';

  @override
  String get model3d_undo => '撤銷';

  @override
  String get model3d_resetPose => '重置姿勢';

  @override
  String get model3d_replaceConfirm => '替換當前模型？未應用的姿勢將丟失。';

  @override
  String get model3d_discardConfirm => '放棄未應用的修改？';

  @override
  String get model3d_missingModel => '模型檔案已丟失，可重新匯入';

  @override
  String get model3d_loadError => '模型載入失敗';

  @override
  String get model3d_light => '光照';

  @override
  String get model3d_lightIntensity => '強度';

  @override
  String get model3d_lightAzimuth => '方位角';

  @override
  String get model3d_lightElevation => '仰角';

  @override
  String get model3d_addLayerTooltip => '新增 3D 模型圖層';

  @override
  String get model3d_webview2Missing =>
      '3D 編輯器需要 Microsoft Edge WebView2 執行時。Windows 10/11 通常已自帶;若缺失請從微軟官網安裝 Evergreen 版本後重試。';

  @override
  String get nav_preciseRefLibrary => '精準參考庫';

  @override
  String get preciseRefLib_title => '精準參考庫';

  @override
  String get preciseRefLib_searchHint => '搜尋參考圖...';

  @override
  String get preciseRefLib_empty => '拖拽或貼上圖片到此處建立庫';

  @override
  String get preciseRefLib_emptyHint => '也可以在生成結果、歷史記錄或本地相簿中右鍵儲存';

  @override
  String get preciseRefLib_emptyTouch => '匯入圖片建立參考庫';

  @override
  String get preciseRefLib_emptyHintTouch => '也可以從生成結果、歷史記錄或本地相簿儲存';

  @override
  String get preciseRefLib_import => '匯入圖片';

  @override
  String get preciseRefLib_exportTitle => '匯出精準參考設定包';

  @override
  String get preciseRefLib_exportSelectionHint =>
      '選擇要包含的精準參考；所選內容會封裝成一個 .naipreciseref 檔案。';

  @override
  String preciseRefLib_exportConfirm(int count) {
    return '匯出所選 ($count)';
  }

  @override
  String preciseRefLib_exportedCount(Object count) {
    return '已匯出 $count 個精準參考';
  }

  @override
  String preciseRefLib_exportFailed(Object error) {
    return '匯出精準參考失敗：$error';
  }

  @override
  String preciseRefLib_openFolderFailed(Object error) {
    return '開啟精準參考目錄失敗：$error';
  }

  @override
  String get preciseRefLib_enterSelectionMode => '進入多選模式';

  @override
  String get preciseRefLib_changeType => '修改類型';

  @override
  String preciseRefLib_sentSelectedSummary(Object failed, Object success) {
    return '已傳送 $success 個精準參考，$failed 個失敗';
  }

  @override
  String preciseRefLib_failedItems(Object items) {
    return '失敗項：$items';
  }

  @override
  String preciseRefLib_confirmDeleteSelected(Object count) {
    return '確定刪除所選的 $count 個精準參考嗎？對應原圖也會刪除。';
  }

  @override
  String preciseRefLib_deletedCount(Object count) {
    return '已刪除 $count 個精準參考';
  }

  @override
  String preciseRefLib_entryCount(int count) {
    return '$count 個條目';
  }

  @override
  String get preciseRefLib_sendToPreciseRef => '傳送到精準參考';

  @override
  String get preciseRefLib_sendToImg2Img => '傳送到圖生圖';

  @override
  String get preciseRefLib_editEntry => '編輯引數';

  @override
  String get preciseRefLib_deleteEntry => '刪除';

  @override
  String get preciseRefLib_confirmDeleteTitle => '刪除條目';

  @override
  String preciseRefLib_confirmDelete(String name) {
    return '確定刪除“$name”？圖片檔案將一併刪除。';
  }

  @override
  String preciseRefLib_saved(String name) {
    return '已存入精準參考庫：$name';
  }

  @override
  String get preciseRefLib_savedHint => '可在精準參考庫中編輯引數';

  @override
  String preciseRefLib_sent(String name) {
    return '已傳送到精準參考：$name';
  }

  @override
  String preciseRefLib_sentToImg2Img(String name) {
    return '已傳送到圖生圖：$name';
  }

  @override
  String get preciseRefLib_imageMissing => '原圖檔案丟失';

  @override
  String get preciseRefLib_invalidImage => '無法識別圖片格式，或圖片檔案已經損壞';

  @override
  String get preciseRefLib_deleteFailed => '刪除失敗，條目與原圖已保留，請稍後重試';

  @override
  String get preciseRefLib_favoritesOnly => '只看收藏';

  @override
  String get preciseRefLib_sortBy => '排序方式';

  @override
  String get preciseRefLib_sortCreatedAt => '建立時間';

  @override
  String get preciseRefLib_sortLastUsed => '最近使用';

  @override
  String get preciseRefLib_sortUsedCount => '使用次數';

  @override
  String get preciseRefLib_sortName => '名稱';

  @override
  String preciseRefLib_importedCount(int count) {
    return '已匯入 $count 張圖片';
  }

  @override
  String preciseRefLib_loadFailed(String error) {
    return '載入精準參考庫失敗：$error';
  }

  @override
  String preciseRefLib_importFailed(String error) {
    return '儲存到精準參考庫失敗：$error';
  }

  @override
  String preciseRefLib_importFailedCount(int count) {
    return '$count 張圖片未能匯入精準參考庫';
  }

  @override
  String get preciseRefLib_fromLibrary => '從庫匯入';

  @override
  String get preciseRefLib_saveCurrentToLibrary => '儲存到庫';

  @override
  String preciseRefLib_saveCurrentCount(int count) {
    return '已儲存 $count 張到精準參考庫';
  }

  @override
  String get preciseRefLib_selectorTitle => '從精準參考庫選擇';

  @override
  String preciseRefLib_selectorConfirm(int count) {
    return '新增所選 ($count)';
  }

  @override
  String get preciseRefLib_nameLabel => '名稱';

  @override
  String get preciseRefLib_typeFilterAll => '全部';

  @override
  String get img2img_fromPreciseRefLibrary => '從精準參考庫匯入';

  @override
  String get localGallery_saveToPreciseRefLibrary => '儲存到精準參考庫';

  @override
  String get drop_saveToPreciseRefLibrary => '存入精準參考庫';

  @override
  String get common_enabled => '已啟用';

  @override
  String get common_disabled => '已禁用';

  @override
  String bulkAction_selectedCount(int count) {
    return '已選擇 $count 項';
  }

  @override
  String get comfyTask_errorConnectionFailed => '無法連線到 ComfyUI 伺服器';

  @override
  String get comfyTask_errorConnectionUnavailable => 'ComfyUI 連線不可用';

  @override
  String get comfyTask_errorExecutionFailedGeneric => 'ComfyUI 執行失敗';

  @override
  String comfyTask_errorExecutionFailed(String error) {
    return 'ComfyUI 執行失敗：$error';
  }

  @override
  String get comfyTask_errorTimeout => 'ComfyUI 任務已在 10 分鐘後超時';

  @override
  String comfyTask_errorWorkflowNotFound(String workflowId) {
    return '未找到工作流：$workflowId';
  }

  @override
  String get comfyWorkflowSlot_vaeEncodeTileSize => 'VAE 編碼分塊大小';

  @override
  String get comfyWorkflowSlot_vaeDecodeTileSize => 'VAE 解碼分塊大小';

  @override
  String get comfyWorkflowSlot_blocksToSwap => '換出塊數量';

  @override
  String get comfyWorkflowSlot_swapIoComponents => '換出輸入輸出元件';

  @override
  String localGallery_firstIndexHint(int count) {
    return '檢測到 $count 張圖片。首次建立索引可能需要幾分鐘，期間仍可正常使用應用。';
  }

  @override
  String get localGallery_errorPermissionDenied => '無法訪問圖片資料夾，請檢查資料夾許可權。';

  @override
  String localGallery_errorScanFailed(String error) {
    return '掃描圖片失敗：$error';
  }

  @override
  String localGallery_errorInitializationFailed(String error) {
    return '初始化相簿失敗：$error';
  }

  @override
  String get localGallery_errorServiceInitializing => '相簿服務正在初始化，請稍後重試。';

  @override
  String localGallery_errorDatabaseFailed(String error) {
    return '相簿資料庫錯誤：$error';
  }

  @override
  String localGallery_errorRefreshFailed(String error) {
    return '重新整理相簿失敗：$error';
  }

  @override
  String localGallery_errorFilterFailed(String error) {
    return '應用相簿篩選條件失敗：$error';
  }

  @override
  String localGallery_errorFavoriteFailed(String error) {
    return '更新收藏狀態失敗：$error';
  }

  @override
  String localGallery_errorRebuildFailed(String error) {
    return '重建相簿索引失敗：$error';
  }

  @override
  String get diy_editDependencyTitle => '編輯依賴配置';

  @override
  String get diy_dependencyTitle => '依賴配置';

  @override
  String get diy_dependencySubtitle => '配置標籤選擇之間的依賴關係';

  @override
  String get diy_dependencyType => '依賴型別';

  @override
  String get diy_sourceCategory => '源類別';

  @override
  String get diy_selectSourceCategory => '選擇源類別';

  @override
  String get diy_sourceCategoryId => '源類別 ID';

  @override
  String get diy_enterCategoryId => '輸入類別 ID';

  @override
  String get diy_mappingRules => '對映規則';

  @override
  String get diy_noMappingRules => '暫無對映規則';

  @override
  String get diy_deleteRule => '刪除規則';

  @override
  String get diy_defaultValue => '預設值';

  @override
  String get diy_defaultValueHint => '沒有匹配的對映規則時使用';

  @override
  String get diy_enableDependency => '啟用依賴配置';

  @override
  String get diy_enableDependencyHint => '禁用後將忽略此依賴配置';

  @override
  String get diy_addMappingRule => '新增對映規則';

  @override
  String get diy_sourceValue => '源值';

  @override
  String get diy_sourceValueHint => '例如：1, 2, 3';

  @override
  String get diy_resultValue => '結果值';

  @override
  String get diy_resultValueHint => '例如：0-3, 0-2, 0-1';

  @override
  String get diy_dependencyCount => '數量';

  @override
  String get diy_dependencyExists => '存在';

  @override
  String get diy_dependencyValue => '值';

  @override
  String get diy_dependencyExcludes => '排斥';

  @override
  String get diy_dependencyCountDescription => '根據源類別的已選數量決定結果數量';

  @override
  String get diy_dependencyExistsDescription => '僅在源類別中存在已選標籤時生效';

  @override
  String get diy_dependencyValueDescription => '依賴源類別中選定的特定標籤值';

  @override
  String get diy_dependencyExcludesDescription => '源類別中存在已選標籤時不生效';

  @override
  String get diy_editConditionalTitle => '編輯條件分支';

  @override
  String get diy_conditionalDefaultName => '條件分支配置';

  @override
  String diy_branchDefaultName(int index) {
    return '分支 $index';
  }

  @override
  String get diy_conditionalTitle => '條件分支配置';

  @override
  String get diy_conditionalSubtitle => '根據機率選擇不同分支';

  @override
  String diy_branchCount(int count) {
    return '$count 個分支';
  }

  @override
  String get diy_noConditionalBranches => '暫無條件分支';

  @override
  String get diy_noConditionalBranchesHint => '新增分支以實現條件選擇邏輯';

  @override
  String diy_conditionCount(int count) {
    return '$count 個條件';
  }

  @override
  String get diy_deleteBranch => '刪除分支';

  @override
  String get diy_addBranch => '新增分支';

  @override
  String diy_editBranch(String name) {
    return '編輯：$name';
  }

  @override
  String get diy_branchName => '分支名稱';

  @override
  String get diy_probability => '機率';

  @override
  String get diy_enableBranch => '啟用此分支';

  @override
  String diy_ruleDefaultName(int index) {
    return '規則 $index';
  }

  @override
  String diy_ruleCount(int count) {
    return '$count 條規則';
  }

  @override
  String get diy_addRule => '新增規則';

  @override
  String get diy_editRule => '編輯規則';

  @override
  String get diy_ruleName => '規則名稱';

  @override
  String get diy_enableRule => '啟用此規則';

  @override
  String get diy_postProcessTitle => '後處理規則';

  @override
  String get diy_postProcessSubtitle => '自動處理標籤衝突';

  @override
  String get diy_sleepingRule => '睡眠規則';

  @override
  String get diy_sleepingRuleDescription => '角色睡眠時移除眼睛顏色描述';

  @override
  String get diy_mermaidRule => '美人魚規則';

  @override
  String get diy_mermaidRuleDescription => '移除美人魚、半人馬、蛇女等角色的腿部服裝描述';

  @override
  String get diy_presetRules => '預設規則';

  @override
  String get diy_noPostProcessRules => '暫無後處理規則';

  @override
  String get diy_noPostProcessRulesHint => '新增規則以自動處理標籤衝突';

  @override
  String get diy_actionType => '操作型別';

  @override
  String get diy_triggerTags => '觸發標籤';

  @override
  String get diy_commaSeparatedTagsHint => '用逗號分隔標籤';

  @override
  String get diy_targetCategories => '目標類別';

  @override
  String get diy_commaSeparatedCategoryIdsHint => '用逗號分隔類別 ID';

  @override
  String get diy_targetTags => '目標標籤';

  @override
  String get diy_actionRemoveTags => '移除標籤';

  @override
  String get diy_actionReplaceTags => '替換標籤';

  @override
  String get diy_actionAddTags => '新增標籤';

  @override
  String get diy_actionRemoveCategories => '移除類別';

  @override
  String get diy_noTriggers => '無觸發條件';

  @override
  String diy_actionSummary(String triggers, String action) {
    return '當 [$triggers] 匹配時：$action';
  }

  @override
  String get diy_emphasisTitle => '全域性強調配置';

  @override
  String get diy_emphasisSubtitle => '調整標籤強調效果';

  @override
  String get diy_emphasisProbability => '強調機率';

  @override
  String diy_emphasisProbabilityHint(String percent) {
    return '每個選中的標籤有 $percent% 的機率被新增強調括號';
  }

  @override
  String get diy_bracketCount => '括號層數';

  @override
  String diy_bracketLayers(int count) {
    return '$count 層';
  }

  @override
  String get diy_effectPreview => '效果預覽';

  @override
  String get diy_exampleTag => '示例標籤';

  @override
  String get diy_emphasisExplanation => '強調括號會增加標籤的權重，層數越多權重越高';

  @override
  String diy_presetExportFailed(String error) {
    return '匯出預設失敗：$error';
  }

  @override
  String get diy_presetJsonRootObject => 'JSON 根節點必須是物件';

  @override
  String diy_presetInvalidData(String error) {
    return '無效的預設資料：$error';
  }

  @override
  String get diy_presetExportTitle => '匯出預設';

  @override
  String get diy_presetImportTitle => '匯入預設';

  @override
  String get diy_unknown => '未知';

  @override
  String get diy_presetShareHint => '複製以下內容分享給其他人';

  @override
  String get diy_presetPasteJsonHint => '在此貼上預設 JSON 資料……';

  @override
  String get diy_presetPreview => '預設預覽';

  @override
  String get diy_name => '名稱';

  @override
  String get diy_description => '描述';

  @override
  String get diy_categoryCount => '類別數';

  @override
  String get diy_totalTagCount => '總標籤數';

  @override
  String get diy_visibilityTitle => '可見性規則';

  @override
  String get diy_visibilitySubtitle => '根據條件控制類別可見性';

  @override
  String get diy_noVisibilityRules => '暫無可見性規則';

  @override
  String get diy_noVisibilityRulesHint => '新增規則以根據當前構圖控制類別可見性';

  @override
  String get diy_notSet => '未設定';

  @override
  String get diy_targetCategory => '目標類別';

  @override
  String get diy_conditionType => '條件型別';

  @override
  String get diy_conditionValue => '條件值';

  @override
  String get diy_conditionValueHint => '標籤名或值';

  @override
  String get diy_visibleWhenMatched => '條件匹配時可見';

  @override
  String get diy_conditionTagExists => '標籤存在';

  @override
  String get diy_conditionTagNotExists => '標籤不存在';

  @override
  String get diy_conditionValueEquals => '值等於';

  @override
  String get diy_conditionValueNotEquals => '值不等於';

  @override
  String get diy_conditionValueInList => '值在列表中';

  @override
  String get diy_conditionValueNotInList => '值不在列表中';

  @override
  String get diy_editTimeConditionTitle => '編輯時間條件';

  @override
  String get diy_timeDefaultName => '時間條件';

  @override
  String get diy_timeTitle => '時間條件';

  @override
  String get diy_timeSubtitle => '在指定日期範圍內啟用';

  @override
  String get diy_enableTimeCondition => '啟用時間條件';

  @override
  String get diy_enableTimeConditionHint => '僅在設定的日期範圍內生效';

  @override
  String get diy_christmas => '聖誕節';

  @override
  String get diy_christmasDescription => '聖誕節詞庫，在 12 月 1 日至 31 日啟用';

  @override
  String get diy_halloween => '萬聖節';

  @override
  String get diy_halloweenDescription => '萬聖節詞庫，在 10 月 1 日至 31 日啟用';

  @override
  String get diy_valentinesDay => '情人節';

  @override
  String get diy_valentinesDescription => '情人節詞庫，在 2 月 1 日至 14 日啟用';

  @override
  String get diy_presetTemplates => '預設模板';

  @override
  String get diy_dateRange => '日期範圍';

  @override
  String get diy_startDate => '開始日期';

  @override
  String get diy_endDate => '結束日期';

  @override
  String get diy_crossYearUnsupported => '暫不支援跨年的日期範圍';

  @override
  String get diy_month => '月';

  @override
  String get diy_day => '日';

  @override
  String get diy_conditionName => '條件名稱';

  @override
  String get diy_conditionNameHint => '輸入條件名稱';

  @override
  String get diy_repeatYearly => '每年重複';

  @override
  String get diy_repeatYearlyHint => '每年在相同日期範圍內自動啟用';

  @override
  String get diy_currentlyActive => '當前啟用';

  @override
  String get diy_inactive => '未啟用';

  @override
  String diy_daysRemaining(int count) {
    return '剩餘 $count 天';
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
  String get common_optional => '可選';

  @override
  String get common_emptyValue => '（空）';

  @override
  String get common_previewLoadFailed => '無法載入預覽';

  @override
  String get common_clickToRetry => '點選重試';

  @override
  String get common_opening => '正在開啟...';

  @override
  String get common_swap => '交換';

  @override
  String get common_prefix => '字首';

  @override
  String get common_suffix => '字尾';

  @override
  String get common_minimum => '最小值';

  @override
  String get common_maximum => '最大值';

  @override
  String get addToLibrary_displayNameHint => '輸入便於識別此條目的名稱';

  @override
  String get addToLibrary_tagHint => '輸入標籤並按 Enter 新增';

  @override
  String get newPresetDialog_nameRequired => '請輸入預設名稱';

  @override
  String get newPresetDialog_nameLabel => '預設名稱';

  @override
  String get newPresetDialog_nameHint => '輸入新預設的名稱';

  @override
  String get newPresetDialog_creationMode => '建立方式';

  @override
  String get drop_saveVibeBundle => '儲存 Vibe Bundle';

  @override
  String drop_saveVibeBundleSubtitle(String name) {
    return '將 $name 等 Vibe 儲存到庫中';
  }

  @override
  String get drop_saveEncodedVibeSubtitle => '將預編碼 Vibe 資料儲存到庫中';

  @override
  String get history_dragFilePreparationFailed => '拖拽檔案準備失敗，請稍後重試';

  @override
  String get history_dragFilePreparing => '正在準備拖拽檔案...';

  @override
  String get history_dragFileNotReady => '拖拽檔案尚未準備完成';

  @override
  String get vibe_import_overwriteOriginalParams => '直接替換原 Vibe 引數';

  @override
  String vibe_import_overwriteOriginalParamsHint(String name) {
    return '僅覆蓋 $name 的庫內引數，預設不勾選';
  }

  @override
  String vibe_import_reencodeFailed(String name) {
    return 'Vibe 重新編碼失敗: $name';
  }

  @override
  String get randomManager_keyboardShortcutsHint => '鍵盤快捷鍵（按 ? 檢視）';

  @override
  String galleryScan_skipped(int count) {
    return '跳過 $count';
  }

  @override
  String galleryScan_withMetadata(int count) {
    return '有後設資料 $count';
  }

  @override
  String galleryScan_failed(int count) {
    return '失敗 $count';
  }

  @override
  String get galleryScan_processing => '處理中';

  @override
  String get galleryScan_pending => '待處理';

  @override
  String get vibeDetail_useAll => '使用全部';

  @override
  String get vibeDetail_longPressSetCover => '長按設為封面';

  @override
  String get vibeDetail_noPreviewImage => '無預覽影象';

  @override
  String get vibeDetail_dropPreviewImage => '拖拽圖片到此處設定預覽圖';

  @override
  String get vibeDetail_releasePreviewImage => '釋放以設定預覽圖';

  @override
  String imagePicker_dropReadFailed(String error) {
    return '讀取拖入圖片失敗: $error';
  }

  @override
  String get imagePicker_dropNoReadableImage => '拖入源未提供可讀取的圖片檔案或圖片連結';

  @override
  String get imagePicker_fileDataUnavailable => '無法讀取檔案資料';

  @override
  String imagePicker_fileSelectionFailed(String error) {
    return '選擇檔案失敗: $error';
  }

  @override
  String imagePicker_directorySelectionFailed(String error) {
    return '選擇目錄失敗: $error';
  }

  @override
  String get editor_effects => '效果';

  @override
  String get editor_shiftEdges => '擴充套件邊緣';

  @override
  String editor_currentSize(int width, int height) {
    return '當前: $width x $height';
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
  String get editor_enterNumber => '請輸入數字';

  @override
  String get editor_nonNegativeNumber => '必須大於或等於 0';

  @override
  String editor_requestedSize(int width, int height) {
    return '請求尺寸: $width x $height';
  }

  @override
  String get editor_requestedSizeInvalid => '請求尺寸: 無效';

  @override
  String editor_appliedSize(int width, int height) {
    return '應用尺寸: $width x $height';
  }

  @override
  String get editor_appliedSizeInvalid => '應用尺寸: 無效';

  @override
  String editor_appliedEdges(int left, int top, int right, int bottom) {
    return '應用邊緣: 左 $left、上 $top、右 $right、下 $bottom';
  }

  @override
  String get editor_appliedEdgesInvalid => '應用邊緣: 無效';

  @override
  String editor_appliedDimensionLimit(int max) {
    return '應用後的尺寸不能超過 $max。';
  }

  @override
  String get savePreset_title => '另存為預設';

  @override
  String get savePreset_nameHint => '輸入預設名稱';

  @override
  String get savePreset_metadataDescription => '從圖片後設資料儲存';

  @override
  String savePreset_vibeData(int count) {
    return 'Vibe 資料（$count）';
  }

  @override
  String get onlineGallery_videoLoadFailed => '影片載入失敗';

  @override
  String get vibe_releaseToAddStyleReference => '鬆開後新增風格參考';

  @override
  String get router_backAgainToExit => '再滑一次或按返回鍵退出應用';

  @override
  String router_pageNotFound(String error) {
    return '頁面未找到: $error';
  }

  @override
  String get autocomplete_translating => '翻譯中…';

  @override
  String get autocomplete_missingTranslation => '未漢化';

  @override
  String autocomplete_translationCoverage(int translated, int total) {
    return '漢化覆蓋：$translated/$total';
  }

  @override
  String autocomplete_aliasMatch(String alias) {
    return '別名：$alias';
  }

  @override
  String get autocomplete_settingsTitle => '自動補全';

  @override
  String get autocomplete_enable => '啟用自動補全';

  @override
  String get autocomplete_resultLimit => '結果數量';

  @override
  String get autocomplete_allResults => '全部';

  @override
  String get autocomplete_showAliases => '顯示命中的別名';

  @override
  String get autocomplete_showTranslations => '顯示中文漢化';

  @override
  String get quickTranslate_show => '快速翻譯';

  @override
  String get quickTranslate_restore => '還原原提示詞（預覽中的修改將被捨棄）';

  @override
  String get quickTranslate_previewSemantics => '本機漢化預覽。在此修改不會影響原提示詞。';

  @override
  String get quickTranslate_noMatches => '目前內容中沒有找到可漢化的標籤';

  @override
  String get quickTranslate_failed => '快速翻譯失敗，請檢查漢化詞庫後重試';

  @override
  String get quickTranslate_missingTitle => '需要漢化詞庫';

  @override
  String get quickTranslate_missingMessage =>
      '快速翻譯需要 ffdkj 簡體中文漢化庫。是否前往資料與快取設定並立即下載？';

  @override
  String get quickTranslate_download => '前往並下載';

  @override
  String get autocomplete_autoComma => '插入後自動新增逗號';

  @override
  String get autocomplete_openOnTagClick => '點選標籤時顯示補全';

  @override
  String get autocomplete_openOnTagClickSubtitle =>
      '開啟後，點選已有標籤會開啟普通補全選單；Ctrl/Command + 點選仍顯示相關標籤';

  @override
  String get autocomplete_replaceUnderscores => '插入時將下劃線替換為空格';

  @override
  String get autocomplete_dataSourcesTitle => '資料來源與快取';

  @override
  String get autocomplete_relatedTagsTitle => '共現與相關標籤推薦';

  @override
  String get autocomplete_relatedTagsSubtitle =>
      '選中補全後自動推薦；也可在標籤上按 Ctrl+Shift+Space 或 Ctrl+單擊';

  @override
  String get autocomplete_danbooruApi => 'Danbooru 線上補充';

  @override
  String get autocomplete_danbooruPrivacy => '僅傳送當前英文標籤，不會上傳完整提示詞';

  @override
  String get autocomplete_llmTranslation => '使用 Prompt Assistant 補譯缺失漢化';

  @override
  String get autocomplete_llmRouteMissing =>
      '請先在 Prompt Assistant 中配置 Translate 路由';

  @override
  String autocomplete_llmRoute(String route) {
    return '當前路由：$route。呼叫模型可能產生費用。';
  }

  @override
  String get autocomplete_cooccurrence => '本地相關標籤資料';

  @override
  String autocomplete_entryCount(int count) {
    return '$count 條記錄';
  }

  @override
  String get autocomplete_cooccurrenceAutoDownload => '自動下載本地相關標籤資料';

  @override
  String get autocomplete_cooccurrenceAutoDownloadSubtitle =>
      '相關標籤功能開啟時，在進入主頁後後臺下載安裝；不影響基礎補全';

  @override
  String get autocomplete_downloadNow => '立即下載';

  @override
  String autocomplete_cooccurrenceUnavailable(String size) {
    return '尚未安裝 · 下載大小 $size。當前僅顯示線上相關標籤。';
  }

  @override
  String get autocomplete_cooccurrenceChecking => '正在檢查本地資料…';

  @override
  String autocomplete_cooccurrenceDownloading(
    String downloaded,
    String total,
    String speed,
  ) {
    return '正在下載 $downloaded / $total · $speed。當前仍可使用線上結果。';
  }

  @override
  String get autocomplete_cooccurrenceVerifying => '下載完成，正在校驗資料包…';

  @override
  String get autocomplete_cooccurrenceInstalling => '正在安全安裝並切換資料庫…';

  @override
  String autocomplete_cooccurrenceReady(
    String version,
    int count,
    String size,
  ) {
    return '版本 $version · $count 組關係 · 佔用 $size';
  }

  @override
  String autocomplete_cooccurrenceUpdateAvailable(String version) {
    return '發現資料版本 $version，可立即更新';
  }

  @override
  String autocomplete_cooccurrenceFailed(String reason) {
    return '本地資料不可用：$reason。基礎補全與線上相關標籤不受影響。';
  }

  @override
  String get autocomplete_cooccurrenceErrorNetwork => '網路連線失敗，請稍後重試';

  @override
  String get autocomplete_cooccurrenceErrorDiskFull => '磁碟空間不足';

  @override
  String get autocomplete_cooccurrenceErrorArchive => '下載檔案不完整或校驗失敗';

  @override
  String get autocomplete_cooccurrenceErrorDatabase => '資料庫損壞或版本不匹配';

  @override
  String get autocomplete_cooccurrenceErrorManifest => '內建資料清單無效';

  @override
  String get autocomplete_cooccurrenceErrorInstall => '無法寫入或替換資料檔案';

  @override
  String get autocomplete_cooccurrenceRemoveTitle => '刪除本地相關標籤資料？';

  @override
  String get autocomplete_cooccurrenceRemoveConfirm =>
      '刪除後將立即釋放磁碟空間，並繼續使用線上相關標籤。';

  @override
  String get autocomplete_cooccurrenceStopAutoDownload => '同時關閉自動下載，避免下次啟動重新安裝';

  @override
  String get autocomplete_cacheTitle => '線上與 AI 快取';

  @override
  String get autocomplete_clearDanbooruCache => '清除 Danbooru 快取';

  @override
  String get autocomplete_clearAiCache => '清除 AI 漢化快取';

  @override
  String autocomplete_cacheCleared(int count) {
    return '已清除 $count 條快取';
  }

  @override
  String get autocomplete_baseCatalog => '基礎 Danbooru 詞庫';

  @override
  String autocomplete_catalogStatus(String count, String version) {
    return '$count 個標籤 · 資料版本 $version';
  }

  @override
  String get autocomplete_zhDictionary => 'ffdkj 簡體中文漢化庫';

  @override
  String autocomplete_zhInstalled(int count, String version) {
    return '已安裝 $count 條 · 版本 $version';
  }

  @override
  String get autocomplete_zhNotInstalled => '未安裝；英文補全仍可正常使用';

  @override
  String get autocomplete_zhInstallPrompt =>
      '可安裝 ffdkj 漢化庫以顯示中文並支援中文反查；詞庫將直接從上游下載。';

  @override
  String get autocomplete_zhErrorMetadataRateLimited =>
      'GitHub 請求過於頻繁，暫時無法檢查詞庫更新；請稍後重試。';

  @override
  String get autocomplete_zhErrorMetadataAccessDenied =>
      'GitHub 拒絕了詞庫資訊請求；請稍後重試或切換網路。';

  @override
  String get autocomplete_zhErrorDownloadAccessDenied =>
      'GitHub 拒絕下載 ffdkj 詞庫；請稍後重試或切換網路。';

  @override
  String get autocomplete_zhErrorNetwork => '無法連線 ffdkj GitHub 上游；請檢查網路後重試。';

  @override
  String get autocomplete_zhErrorIntegrity => '詞庫完整性驗證失敗，未安裝任何檔案。';

  @override
  String get autocomplete_zhErrorUnknown => 'ffdkj 詞庫操作失敗；請稍後重試。';

  @override
  String get autocomplete_checkUpdate => '檢查更新';

  @override
  String get autocomplete_update => '更新';

  @override
  String get autocomplete_repair => '修復';

  @override
  String get autocomplete_install => '安裝';

  @override
  String get autocomplete_remove => '移除';

  @override
  String get autocomplete_removeConfirm => '移除已安裝的中文漢化詞庫？之後仍可重新安裝。';

  @override
  String get autocomplete_sourceRelated => '離線相關標籤';

  @override
  String get autocomplete_headerTitle => '標籤補全';

  @override
  String get autocomplete_relatedHeaderTitle => '相關標籤';

  @override
  String get autocomplete_loading => '正在查詢本地詞庫與線上標籤…';

  @override
  String get autocomplete_empty => '沒有找到匹配的標籤';

  @override
  String get autocomplete_relatedLoading => '正在查詢本地共現庫與線上相關標籤…';

  @override
  String get autocomplete_relatedEmpty => '沒有找到可用的相關標籤';

  @override
  String autocomplete_relatedMetric(int count, String score) {
    return '共現 $count 次 · Jaccard $score';
  }

  @override
  String get autocomplete_relatedPin => '固定當前標籤，可連續插入相關標籤';

  @override
  String get autocomplete_relatedUnpin => '取消固定並繼續鏈式推薦';

  @override
  String get autocomplete_statusBase => '本地';

  @override
  String get autocomplete_statusRelated => '共現';

  @override
  String get autocomplete_statusOnlineOnly => '僅線上';

  @override
  String get autocomplete_statusOnlineOnlyTooltip =>
      '本地相關標籤資料尚未就緒，當前只顯示 Danbooru 線上結果';

  @override
  String get autocomplete_statusDictionary => '漢化';

  @override
  String get autocomplete_statusOnline => '線上';

  @override
  String get autocomplete_statusAi => 'AI';

  @override
  String get autocomplete_statusReady => '就緒';

  @override
  String get autocomplete_statusNotInstalled => '未安裝';

  @override
  String autocomplete_statusDownloading(int progress) {
    return '下載 $progress%';
  }

  @override
  String get autocomplete_statusUpdateAvailable => '可更新';

  @override
  String get autocomplete_statusError => '異常';

  @override
  String get autocomplete_statusDisabled => '已關閉';

  @override
  String get autocomplete_statusSearching => '查詢中';

  @override
  String get autocomplete_statusTranslating => '翻譯中';

  @override
  String autocomplete_aiCacheEntries(int count) {
    return 'AI 翻譯快取：$count 筆';
  }

  @override
  String get autocomplete_openSettings => '開啟補全與資料來源設定';

  @override
  String get randomManager_searchCategories => '搜尋類別、詞組或標籤（Ctrl+F）';

  @override
  String get randomManager_searchCategoriesCompact => '搜尋類別、詞組或標籤';

  @override
  String get randomManager_workspaceTitle => '隨機詞庫';

  @override
  String get randomManager_workspaceSubtitle => '用完整離線 catalog 組合可重用的隨機生成配方';

  @override
  String get randomManager_recipeTitle => '生成配方';

  @override
  String get randomManager_recipeSubtitle => '每個階段獨立控制一類語義標籤的觸發機率與抽取範圍';

  @override
  String get randomManager_inspectorTitle => '生成設定';

  @override
  String get randomManager_inspectorSubtitle => '調整目前預設的角色分佈與全域輸出行為';

  @override
  String get randomManager_previewEmptyDescription => '生成一組提示詞範例，檢查目前配方的實際輸出。';

  @override
  String get randomManager_category_composition => '構圖';

  @override
  String get randomManager_category_camera => '視角';

  @override
  String get randomManager_category_framing => '景別';

  @override
  String get randomManager_category_focus => '焦點';

  @override
  String get randomManager_category_eyeFeature => '眼睛特徵';

  @override
  String get randomManager_category_hairLength => '髮長';

  @override
  String get randomManager_category_hairTexture => '髮質';

  @override
  String get randomManager_category_bangs => '瀏海';

  @override
  String get randomManager_category_skinTone => '膚色';

  @override
  String get randomManager_category_species => '物種';

  @override
  String get randomManager_category_headwear => '帽子';

  @override
  String get randomManager_category_hairAccessory => '髮飾';

  @override
  String get randomManager_category_prop => '道具';

  @override
  String get randomManager_category_effect => '特效';

  @override
  String get randomManager_category_year => '年代';

  @override
  String get randomManager_category_detail => '創意細節';

  @override
  String get randomManager_libraryUnavailable => '隨機詞庫無法使用';

  @override
  String get randomManager_noCategoryResults => '沒有符合的類別、詞組或標籤';

  @override
  String get common_share => '分享';

  @override
  String get common_moreActions => '更多操作';

  @override
  String get nav_more => '更多';

  @override
  String get nav_explore => '畫廊';

  @override
  String get image_savedToSystemGallery => '已儲存到系統相簿';

  @override
  String get localGallery_saveToSystemGallery => '儲存到系統相簿';

  @override
  String localGallery_saveToSystemGalleryFailed(Object error) {
    return '無法儲存到系統相簿：$error';
  }

  @override
  String image_savedAppOnly(Object error) {
    return '已儲存到應用程式圖庫，但無法匯出到系統相簿：$error';
  }

  @override
  String image_shareFailed(Object error) {
    return '分享失敗: $error';
  }

  @override
  String onlineGallery_savedFiles(int count) {
    return '已儲存 $count 個檔案';
  }

  @override
  String get statistics_exportJsonHint => '將全部統計結果和分佈資料匯出為結構化 JSON。';

  @override
  String get statistics_exportCsvHint => '將分區統計資料匯出為可用試算表應用程式開啟的 CSV。';

  @override
  String get queue_reorderTask => '調整任務順序';

  @override
  String get queue_moreTaskActions => '更多任務操作';

  @override
  String get queue_selectTask => '選擇任務';

  @override
  String get settings_notificationSoundImportFailed => '無法匯入音效，請重新選擇檔案。';

  @override
  String get settings_androidManagedStorage => '由系統安全管理；匯出時可選擇儲存位置';

  @override
  String get settings_importLocalOnnxTaggerFiles => '匯入 ONNX 模型、標籤檔案或 ZIP 壓縮檔';

  @override
  String settings_localOnnxFilesImported(int count) {
    return '已匯入 $count 個模型檔案';
  }

  @override
  String settings_localOnnxManagedFiles(int count) {
    return '應用程式儲存空間中有 $count 個模型檔案';
  }

  @override
  String get settings_clearLocalOnnxModelsTitle => '清除本地 ONNX 模型？';

  @override
  String get settings_clearLocalOnnxModelsContent =>
      '將刪除此裝置上已匯入的 ONNX 模型及標籤檔案。';

  @override
  String updateAndroidDownloadedHint(Object version) {
    return '新版本 v$version 已下載並透過校驗。可以開啟 Android 系統安裝介面繼續更新。';
  }

  @override
  String get updateAndroidInstallingHint => '正在開啟 Android 系統安裝介面，請依系統提示確認更新。';

  @override
  String get updateAndroidInstallConfirmationBody =>
      '將開啟 Android 系統安裝介面。確認安裝後，系統會替換應用且不會清除本機資料；進行中的生成和下載任務可能停止，請先儲存必要內容。';

  @override
  String get preciseRefLib_moreActions => '更多操作';

  @override
  String get vibeDetail_setAsCover => '將所選圖片設為封面';

  @override
  String vibeDetail_bundleChildParameters(int index) {
    return '正在顯示第 $index 個子 Vibe 的匯入參數。';
  }

  @override
  String get vibeDetail_bundleDefaultParameters => '正在顯示合集預設參數。選擇下方子項可查看其參數。';

  @override
  String get vibeDetail_choosePreviewImage => '點選圖片按鈕選擇預覽圖';

  @override
  String get cloudSync_title => '備份與還原';

  @override
  String get cloudSync_description =>
      '將設定、提示詞等內容推送到你自己的 WebDAV 或 GitHub，或從雲端備份拉取到目前裝置。';

  @override
  String get cloudSync_disconnected => '尚未連線';

  @override
  String get cloudSync_oneClickDescription =>
      '選擇儲存服務並填寫帳號資訊。儲存只會驗證並記住連線，不會推送或拉取資料。';

  @override
  String get cloudSync_saveConnection => '儲存連線';

  @override
  String get cloudSync_operationInProgress => '另一項雲端同步操作正在進行，請稍後再試。';

  @override
  String get cloudSync_fillRequiredFields => '請填寫目前服務商的必填連線資訊。';

  @override
  String get cloudSync_advancedSettings => '進階設定';

  @override
  String get cloudSync_connectionManagement => '儲存連線';

  @override
  String get cloudSync_chooseBackend => '備份到哪裡';

  @override
  String get cloudSync_chooseBackendDescription =>
      '先選擇同步目的地，再連線帳號並選擇要同步的內容。憑證只會儲存在裝置的安全儲存區。';

  @override
  String cloudSync_oauthDescription(String provider) {
    return '連線 $provider 帳號';
  }

  @override
  String get cloudSync_oauthSystemBrowser => '將使用系統瀏覽器安全登入；無需在應用程式中輸入密碼。';

  @override
  String cloudSync_oauthUnavailable(String details) {
    return '此版本缺少 OAuth 發佈設定，暫時無法連線。請向發佈者提供以下診斷：\n$details';
  }

  @override
  String cloudSync_accountConnected(String provider) {
    return '已連線 $provider';
  }

  @override
  String get cloudSync_connectAccount => '連線帳號';

  @override
  String get cloudSync_changeAccount => '更換帳號';

  @override
  String get cloudSync_connectedAccount => '已連線帳號';

  @override
  String get cloudSync_webDavUrl => 'WebDAV 位址';

  @override
  String get cloudSync_allowInsecureHttp => '允許不安全的 HTTP';

  @override
  String get cloudSync_allowInsecureHttpWarning =>
      'HTTP 會以明文傳輸 WebDAV 憑證和備份資料。僅在可信內網且明確了解風險時啟用。';

  @override
  String get cloudSync_username => '使用者名稱';

  @override
  String get cloudSync_password => '密碼';

  @override
  String get cloudSync_remotePath => '備份資料夾';

  @override
  String get cloudSync_githubToken => 'GitHub 存取權杖';

  @override
  String get cloudSync_owner => 'GitHub 使用者或組織';

  @override
  String get cloudSync_repository => '儲存庫';

  @override
  String get cloudSync_branch => '分支（通常為 main）';

  @override
  String get cloudSync_testFailed => '連線測試失敗';

  @override
  String get cloudSync_operationFailed => '雲端同步操作失敗';

  @override
  String get cloudSync_manualBackupOnly => '只支援手動推送與拉取';

  @override
  String get cloudSync_manualBackupOnlyDescription =>
      '此服務無法可靠處理多台裝置同時修改。這裡不會自動合併或覆蓋，只按你的選擇推送或拉取。';

  @override
  String get cloudSync_chooseBackupContents => '選擇備份內容';

  @override
  String get cloudSync_backupContentDescription => '僅備份恢復所需的資料；圖片資源會在上傳前壓縮。';

  @override
  String get cloudSync_lightweightData => '輕量資料（預設）';

  @override
  String get cloudSync_settingsDescription => '主題、生成參數和應用偏好';

  @override
  String get cloudSync_promptsAndTags => '提示詞與詞庫';

  @override
  String get cloudSync_promptsAndTagsDescription => '條目、分類、固定詞和預設';

  @override
  String get cloudSync_tagThumbnails => '詞庫預覽圖';

  @override
  String get cloudSync_tagThumbnailsDescription => '上傳前壓縮，不儲存原圖';

  @override
  String get cloudSync_onlineGallerySettings => '線上畫廊設定';

  @override
  String get cloudSync_onlineGallerySettingsDescription => '黑名單、篩選和使用者分類';

  @override
  String get cloudSync_onlineGalleryFavorites => '線上畫廊收藏';

  @override
  String get cloudSync_onlineGalleryFavoritesDescription =>
      '僅儲存來源 ID 與恢復所需資訊，不儲存原圖';

  @override
  String get cloudSync_galleryAlbums => '本機畫廊相簿';

  @override
  String get cloudSync_galleryAlbumsDescription => '只儲存相簿結構與圖片引用，不上傳原圖';

  @override
  String get cloudSync_optionalResources => '可選資源（預設關閉）';

  @override
  String get cloudSync_vibes => 'Vibe';

  @override
  String get cloudSync_preciseReferences => '精準參考';

  @override
  String get cloudSync_largeResourceDescription => '包含恢復所需資源，可能顯著增加體積';

  @override
  String get cloudSync_neverBackedUp => '雲端憑據、快取、日誌、瀏覽歷史和遠端圖庫原圖始終不會備份。';

  @override
  String get cloudSync_restoreDefaults => '恢復預設';

  @override
  String get cloudSync_saveSelection => '儲存選擇';

  @override
  String cloudSync_selectedContentSummary(int count) {
    return '已選擇 $count 項內容';
  }

  @override
  String get cloudSync_rebuildCompactBackup => '清理舊備份並重新建立';

  @override
  String get cloudSync_rebuildCompactBackupDescription =>
      '刪除目前雲端備份空間並按現有選擇上傳新的精簡備份。服務商保留的歷史版本不會被重寫。';

  @override
  String get cloudSync_rebuildCompactBackupConfirm =>
      '刪除目前雲端備份並立即上傳新的精簡備份嗎？此操作無法復原。';

  @override
  String get cloudSync_kindSettings => '設定';

  @override
  String get cloudSync_kindPrompts => '提示詞與預設';

  @override
  String get cloudSync_kindGalleries => '線上畫廊收藏、分類與篩選';

  @override
  String get cloudSync_kindLargeFiles => '圖片與其他大型檔案';

  @override
  String get cloudSync_agentContentTitle => '智慧代理設定';

  @override
  String get cloudSync_agentSystemPrompt => '自訂系統提示詞';

  @override
  String get cloudSync_agentSystemPromptDescription =>
      '儲存你修改的提示詞和使用方式；模型與帳號資訊仍只保留在此裝置。';

  @override
  String get cloudSync_skillsBackup => '備份已選 Skill';

  @override
  String get cloudSync_skillsBackupDescription => '備份開關預設開啟；只備份你在下方選擇的 Skill。';

  @override
  String get cloudSync_chooseSkills => '選擇 Skill';

  @override
  String cloudSync_skillsSelectedCount(Object count) {
    return '已選擇 $count 個 Skill';
  }

  @override
  String cloudSync_missingSelectedSkills(Object count) {
    return '其中 $count 個目前無法使用';
  }

  @override
  String get cloudSync_removeMissingSkills => '移除無法使用的項目';

  @override
  String get cloudSync_searchSkills => '搜尋 Skill';

  @override
  String get cloudSync_noSkills => '沒有符合的 Skill';

  @override
  String cloudSync_actionFailed(Object error) {
    return '操作失敗：$error';
  }

  @override
  String get cloudSync_errorAuthentication => '登入狀態已過期，請重新連接帳號。';

  @override
  String get cloudSync_errorAuthorization => '目前帳號無權存取備份位置。';

  @override
  String get cloudSync_errorNotFound => '找不到雲端備份目錄或檔案。';

  @override
  String get cloudSync_errorConflict => '雲端資料已被其他裝置更新，請先拉取最新資料再重試。';

  @override
  String get cloudSync_errorQuota => '雲端儲存空間不足。';

  @override
  String get cloudSync_errorRateLimited => '雲端儲存要求過於頻繁，請稍後重試。';

  @override
  String get cloudSync_errorRedirect => '服務商將要求重新導向至不受信任的位址，操作已停止。';

  @override
  String get cloudSync_errorInvalidResponse => '服務商傳回了無法驗證的資料。';

  @override
  String get cloudSync_errorNetwork => '無法連接雲端儲存，請檢查網路後重試。';

  @override
  String get cloudSync_errorPreviewStale => '預覽後資料已變更，請重新查看變更後再繼續。';

  @override
  String get cloudSync_errorFormat => '備份格式或完整性驗證失敗。';

  @override
  String get cloudSync_errorConfiguration => '無法讀取已儲存的同步設定。';

  @override
  String get cloudSync_errorState => '同步狀態已變更，請重試目前操作。';

  @override
  String get cloudSync_errorUnknown => '同步失敗，請檢查連線後重試。';

  @override
  String get cloudSync_connectionDetails => '儲存資訊';

  @override
  String get cloudSync_backend => '儲存服務';

  @override
  String get cloudSync_deviceName => '本機名稱';

  @override
  String get cloudSync_lastSync => '上次完成';

  @override
  String get cloudSync_connectedDescription => '連線正常，可以推送本機備份或拉取雲端資料。';

  @override
  String get cloudSync_providerWarning => '儲存服務提示';

  @override
  String get cloudSync_warningGoogleDriveWeakCas =>
      'Google Drive 無法保證檔案內容的原子條件更新，因此此連線僅支援明確的手動推送與拉取。';

  @override
  String get cloudSync_warningGithubPublicRepository =>
      '目前的 GitHub 儲存庫是公開儲存庫，備份內容也會公開。私密資料請改用私人儲存庫。';

  @override
  String get cloudSync_warningWebDavWeakCas =>
      '此伺服器無法保證安全的條件更新。目前僅支援手動備份，後續寫入可能取代同一個 HEAD。';

  @override
  String get cloudSync_warningWebDavUnverifiedCas =>
      'WebDAV 連線已通過唯讀驗證，但尚未驗證安全的條件寫入。目前僅支援手動推送與拉取。';

  @override
  String get cloudSync_githubHistoryRetention => 'GitHub 空間說明';

  @override
  String get cloudSync_githubHistoryRetentionDescription =>
      '刪除雲端備份後，GitHub 的舊提交仍會佔用儲存庫空間。需要徹底清理時，請在 GitHub 中建立新儲存庫。';

  @override
  String get cloudSync_upToDate => '已連線';

  @override
  String get cloudSync_syncing => '正在傳輸';

  @override
  String get cloudSync_paused => '已暫停';

  @override
  String get cloudSync_syncControls => '推送與拉取';

  @override
  String get cloudSync_pushLocal => '推送到雲端';

  @override
  String get cloudSync_pullRemote => '從雲端拉取';

  @override
  String get cloudSync_pushConfirmTitle => '推送本機資料？';

  @override
  String get cloudSync_pushConfirmDescription =>
      '將以目前本機資料建立新的雲端備份，並把雲端目前版本切換到該備份。';

  @override
  String get cloudSync_pullConfirmTitle => '拉取雲端資料？';

  @override
  String get cloudSync_pullConfirmDescription =>
      '將使用雲端最新備份更新本機已選取的資料。尚未推送的本機變更可能被取代。';

  @override
  String get cloudSync_pause => '暫停';

  @override
  String get cloudSync_resume => '繼續';

  @override
  String get cloudSync_cancel => '取消';

  @override
  String get cloudSync_progress => '傳輸進度';

  @override
  String get cloudSync_metricsDetails => '技術詳情';

  @override
  String get cloudSync_metricsElapsed => '總耗時';

  @override
  String get cloudSync_metricsRequests => '服務要求';

  @override
  String get cloudSync_metricsRead => '已接收';

  @override
  String get cloudSync_metricsWritten => '已傳送';

  @override
  String get cloudSync_metricsHashPasses => '完整性驗證';

  @override
  String get cloudSync_metricsPayloadReads => '資料讀取次數';

  @override
  String get cloudSync_metricsLocalRead => '本機讀取';

  @override
  String get cloudSync_metricsLocalWritten => '本機寫入';

  @override
  String get cloudSync_metricsFlushes => '磁碟刷新';

  @override
  String get cloudSync_stage => '目前進度';

  @override
  String get cloudSync_objects => '已處理';

  @override
  String get cloudSync_reusedObjects => '已重用未變更項目';

  @override
  String get cloudSync_bytes => '已傳輸';

  @override
  String get cloudSync_stagePreparing => '正在準備';

  @override
  String get cloudSync_stageScanning => '正在掃描所選資料';

  @override
  String get cloudSync_stageHashing => '正在驗證本機內容';

  @override
  String get cloudSync_stageDownloading => '正在下載';

  @override
  String get cloudSync_stageVerifying => '正在驗證下載內容';

  @override
  String get cloudSync_stageMerging => '正在整理兩端內容';

  @override
  String get cloudSync_stageReusing => '正在重用未變更內容';

  @override
  String get cloudSync_stageUploading => '正在上傳';

  @override
  String get cloudSync_stageCommitting => '正在發佈備份';

  @override
  String get cloudSync_stageApplying => '正在儲存變更';

  @override
  String get cloudSync_stageSaving => '正在儲存復原狀態';

  @override
  String get cloudSync_stageRetryWaiting => '等待重試';

  @override
  String get cloudSync_stageRollingBack => '正在恢復原狀';

  @override
  String get cloudSync_stageCompleted => '已完成';

  @override
  String get cloudSync_stageWorking => '正在處理';

  @override
  String get cloudSync_snapshotHistory => '以前的備份';

  @override
  String get cloudSync_snapshotHistoryDescription =>
      '可以先查看某次備份會帶來哪些變化，再決定是否恢復。目前資料不會直接被覆蓋。';

  @override
  String get cloudSync_noSnapshots => '還沒有可恢復的備份。';

  @override
  String cloudSync_backupItemCount(int count) {
    return '包含 $count 項內容';
  }

  @override
  String get cloudSync_previewRestore => '查看並恢復';

  @override
  String get cloudSync_restorePreviewTitle => '恢復前確認';

  @override
  String get cloudSync_restorePreviewDescription =>
      '檢查恢復後會新增、更新或刪除哪些內容。確認前不會修改目前資料。';

  @override
  String get cloudSync_mergePreviewTitle => '合併內容確認';

  @override
  String get cloudSync_mergePreviewDescription =>
      '本機和雲端的資料不同。請檢查變化並選擇要保留的內容。確認前不會修改資料。';

  @override
  String get cloudSync_previewAwaitingConfirmation => '請先確認下方變化。';

  @override
  String get cloudSync_previewDeletesTitle => '將刪除目前裝置上的內容';

  @override
  String cloudSync_previewDeletesDescription(Object count) {
    return '恢復後會從目前裝置刪除 $count 項內容，請確認這些變化符合預期。';
  }

  @override
  String cloudSync_previewCounts(
    Object added,
    Object modified,
    Object deleted,
  ) {
    return '新增 $added · 修改 $modified · 刪除 $deleted';
  }

  @override
  String get cloudSync_previewNoChanges => '沒有需要套用的變更。';

  @override
  String get cloudSync_confirmMerge => '確認套用';

  @override
  String get cloudSync_confirmRestore => '確認恢復';

  @override
  String get cloudSync_ffdkjIntentTitle => '偵測到詞庫設定';

  @override
  String get cloudSync_ffdkjIntentDescription =>
      '另一台裝置安裝了 ffdkj 中文詞庫。詞庫檔案不會透過雲端傳輸。';

  @override
  String get cloudSync_ffdkjInstallWarning => '是否從 ffdkj 官方來源下載並安裝中文詞庫？';

  @override
  String get cloudSync_clearInstallIntent => '暫不安裝並清除提示';

  @override
  String get cloudSync_deleteRemoteNamespace => '刪除雲端備份';

  @override
  String get cloudSync_deleteRemoteNamespaceDescription =>
      '刪除 Aaalice 在此服務中儲存的全部備份，不會刪除目前裝置的資料。';

  @override
  String get cloudSync_deleteRemoteConfirm => '確定刪除全部雲端備份嗎？目前裝置的資料會保留。';

  @override
  String get cloudSync_disconnect => '中斷連線';

  @override
  String get cloudSync_disconnectDescription => '移除此裝置儲存的儲存連線，雲端已有備份會保留。';

  @override
  String get cloudSync_disconnectConfirm => '確定中斷此裝置嗎？雲端已有備份會保留。';

  @override
  String get cloudSync_confirm => '確認';

  @override
  String get cloudSync_conflictCenter => '內容有衝突';

  @override
  String get cloudSync_conflictDescription => '同一內容在此裝置和雲端都被修改。請選擇要保留的版本。';

  @override
  String get cloudSync_needsConflictResolution => '請選擇要保留的內容';

  @override
  String get cloudSync_deferredConflictWarning => '還有內容沒有選擇，完成後才能繼續。';

  @override
  String get cloudSync_applyAll => '全部選擇：';

  @override
  String get cloudSync_base => '上次儲存';

  @override
  String get cloudSync_local => '此裝置';

  @override
  String get cloudSync_remote => '雲端';

  @override
  String get cloudSync_chooseLocal => '保留此裝置版本';

  @override
  String get cloudSync_chooseRemote => '保留雲端版本';

  @override
  String get cloudSync_keepBoth => '兩者都保留';

  @override
  String get cloudSync_largeBinaryKeepBothDefault => '大型檔案會預設保留兩個版本，避免遺失。';

  @override
  String get settings_agent => '智慧體';

  @override
  String get agentSettings_subtitle => '管理聊天模型、工具權限、連網、系統提示詞與 Skills。';

  @override
  String get agentSettings_readingAppearance => '閱讀與密度';

  @override
  String get agentSettings_readingTextSize => '閱讀字級';

  @override
  String get agentSettings_readingTextSizeDescription => '僅調整智慧體面板，並疊加全域字體縮放。';

  @override
  String get agentSettings_density => '介面密度';

  @override
  String get agentSettings_densityDescription => '舒適模式優先保證觸控與留白；緊湊模式適合桌面高資訊密度。';

  @override
  String get agentSettings_densityComfortable => '舒適';

  @override
  String get agentSettings_densityCompact => '緊湊';

  @override
  String get agentSettings_chatModel => '聊天模型';

  @override
  String get agentSettings_providerModel => '供應商 / 模型';

  @override
  String get agentSettings_modelManagedInIntegrations =>
      '供應商、API Key 與模型探索仍在「整合」中統一管理。';

  @override
  String get agentSettings_manageProviders => '管理供應商';

  @override
  String get agentSettings_noModel => '沒有可用聊天模型。請先在「整合」中新增供應商並探索模型。';

  @override
  String get agentSettings_pendingMatch => '待配對';

  @override
  String get agentSettings_contextWindow => '上下文視窗（token）';

  @override
  String agentSettings_contextWindowKnown(String value) {
    return '留空則使用內建值 $value。第三方中轉站或自訂部署的實際視窗不同時，可在此填寫覆寫。';
  }

  @override
  String get agentSettings_contextWindowUnknown =>
      '內建目錄未收錄此模型，無法自動判斷視窗。未填寫則無法顯示上下文用量，也無法壓縮上下文。';

  @override
  String get agentSettings_contextWindowUnknownHint => '例如 128000';

  @override
  String get agentSettings_contextWindowReset => '還原為內建值';

  @override
  String get agentSettings_contextWindowInvalid => '請填寫 1 到 20000000 之間的整數';

  @override
  String get agentSettings_toolPermission => '工具權限';

  @override
  String get agentSettings_permissionSafe => '安全';

  @override
  String get agentSettings_permissionSafeDescription =>
      '僅執行唯讀和低風險操作，不彈出敏感操作授權。';

  @override
  String get agentSettings_permissionAsk => '敏感操作前詢問';

  @override
  String get agentSettings_permissionAskDescription =>
      '預設模式。寫入檔案、執行生成等敏感操作前先要求確認。';

  @override
  String get agentSettings_permissionFull => '完全存取';

  @override
  String get agentSettings_permissionFullDescription =>
      '允許存取工作區外檔案並直接執行工具。僅在信任目前任務時使用。';

  @override
  String get agentSettings_webPreference => '連網偏好';

  @override
  String get agentSettings_webEnabled => '允許智慧體使用 Web 工具';

  @override
  String get agentSettings_webDescription =>
      '開啟後模型可搜尋並讀取公開網頁；關閉後相關工具會從執行階段工具表移除。';

  @override
  String get agentSettings_systemPrompt => '系統提示詞';

  @override
  String get agentSettings_edit => '編輯';

  @override
  String get agentSettings_previewFinalPrompt => '預覽最終提示詞';

  @override
  String get agentSettings_systemPromptDescription => '選擇下方內容如何套用到智慧體的系統提示詞。';

  @override
  String get agentSettings_promptModeAppend => '附加';

  @override
  String get agentSettings_promptModeAppendDescription =>
      '保留內建說明與 Skills 清單，並在末尾附加下方內容。';

  @override
  String get agentSettings_promptModeOverride => '覆蓋';

  @override
  String get agentSettings_promptModeOverrideDescription =>
      '僅將下方內容作為系統提示詞；內建說明與 Skills 清單不會加入，但 Provider 必需的結構化工具定義仍會傳送。';

  @override
  String get agentSettings_systemPromptHint => '例如：優先給出簡潔結論；修改提示詞前先說明影響。';

  @override
  String get agentSettings_restoreDefault => '還原預設值';

  @override
  String get agentSettings_promptSaved => '系統提示詞已儲存';

  @override
  String get agentSettings_discardPromptTitle => '放棄未儲存的系統提示詞？';

  @override
  String get agentSettings_discardPromptBody => '離開此頁面會遺失尚未儲存的修改。';

  @override
  String get agentSettings_keepEditing => '繼續編輯';

  @override
  String get agentSettings_discardChanges => '放棄修改';

  @override
  String get agentSettings_importProfile => '匯入設定';

  @override
  String get agentSettings_exportProfile => '匯出設定';

  @override
  String get agentSettings_profilePrivacy => '此檔案不包含 API Key、Token、聊天記錄或本機路徑。';

  @override
  String get agentSettings_profilePending =>
      '未安裝的模型或 Skill 不會偽裝為可用；偏好會保留，待日後安裝後生效。';

  @override
  String get agentSettings_reloadSkills => '重新掃描';

  @override
  String get agentSettings_importSkills => '從 ZIP 匯入';

  @override
  String get agentSettings_exportSkills => '匯出所選 Skills';

  @override
  String get agentSettings_searchSkills => '搜尋名稱或描述';

  @override
  String get agentSettings_filterAll => '全部';

  @override
  String get agentSettings_filterEnabled => '已啟用';

  @override
  String get agentSettings_filterDisabled => '已停用';

  @override
  String agentSettings_skillEnabledCount(int enabled, int total) {
    return '已啟用 $enabled/$total';
  }

  @override
  String get agentSettings_diagnostics => '診斷';

  @override
  String get agentSettings_noMatchingSkill => '沒有相符的 Skill';

  @override
  String get agentSettings_noDiagnostics => '未發現診斷問題';

  @override
  String get agentSettings_skillExplicitOnly =>
      '此 Skill 只能由使用者明確呼叫，不會出現在模型可見清單中';

  @override
  String get agentSettings_exportPrivacy =>
      '只會匯出明確勾選的 Skill；.env、金鑰、Token、Git 與依賴目錄不會打包。';

  @override
  String get agentSettings_continueExport => '繼續匯出';

  @override
  String get agentSettings_install => '安裝';

  @override
  String get agentSettings_apply => '套用';

  @override
  String agentSettings_operationFailed(String error) {
    return '操作失敗：$error';
  }

  @override
  String get agentSettings_skillsTitle => 'Skills';

  @override
  String get agentSettings_skillsSourceHint =>
      '目前圖片專案中的 Skill 會自動啟用；Pi 使用者與使用者全域 Skill 僅在手動啟用後使用。';

  @override
  String get agentSettings_skillTransfer => '匯入或匯出';

  @override
  String get agentSettings_skillsRescanned => 'Skills 已重新掃描';

  @override
  String agentSettings_skillScanFailed(String error) {
    return '掃描失敗：$error';
  }

  @override
  String get agentSettings_exportSkillsTitle => '匯出 Skills';

  @override
  String get agentSettings_skillsExported => 'Skills 已匯出';

  @override
  String get agentSettings_skillZipReadFailed => '無法讀取 ZIP 檔案';

  @override
  String get agentSettings_confirmSkillsImport => '確認匯入 Skills';

  @override
  String agentSettings_skillArchiveStats(int files, int bytes) {
    return '$files 個檔案 · $bytes 位元組';
  }

  @override
  String get agentSettings_skillConflictReplace => '存在同名 Skill，勾選以取代';

  @override
  String get agentSettings_skillConflictUnsafe => '目標是檔案、連結或特殊實體，無法取代';

  @override
  String get agentSettings_skillsInstalled => 'Skills 已安裝';

  @override
  String agentSettings_skillShadowed(String name) {
    return '$name 被更高優先順序來源覆蓋';
  }

  @override
  String agentSettings_preferredSource(String source) {
    return '優先來源：$source';
  }

  @override
  String get agentSettings_sourceWorkspace => '目前圖片專案';

  @override
  String get agentSettings_sourcePiUser => 'Pi 使用者';

  @override
  String get agentSettings_sourceCommonUser => '使用者全域';

  @override
  String get agentSettings_exportProfileTitle => '匯出智慧體設定';

  @override
  String get agentSettings_profileExported => '智慧體設定已匯出';

  @override
  String get agentSettings_profileReadFailed => '無法讀取設定檔';

  @override
  String get agentSettings_confirmProfileImport => '確認匯入智慧體設定';

  @override
  String get agentSettings_profileNoChanges => '目前設定不會變更';

  @override
  String agentSettings_profileChanges(String changes) {
    return '將變更：$changes';
  }

  @override
  String get agentSettings_listSeparator => '、';

  @override
  String get agentSettings_pendingPreferences => '待配對偏好';

  @override
  String agentSettings_missingModel(String model) {
    return '目前未提供模型：$model';
  }

  @override
  String agentSettings_missingSkill(String skill) {
    return '目前未安裝 Skill：$skill';
  }

  @override
  String get agentSettings_profileImported => '智慧體設定已匯入';

  @override
  String get settings_watermarkTitle => '浮水印';

  @override
  String get settings_watermarkSubtitle => '完全在本機建立浮水印副本，不修改原圖';

  @override
  String get settings_watermarkEnable => '啟用浮水印工具';

  @override
  String get settings_watermarkPreserveMetadata => '浮水印副本保留中繼資料';

  @override
  String get settings_watermarkPreserveMetadataHint =>
      '關閉時清除 PNG 文字、EXIF、NovelAI 隱寫資料、提示詞和種子；開啟時把原圖中支援的中繼資料安全寫入新 PNG。';

  @override
  String get settings_watermarkEditDefault => '編輯預設浮水印';

  @override
  String get settings_watermarkCreateFromImage => '選擇圖片並建立浮水印副本…';

  @override
  String get settings_watermarkLayoutByOrientation => '依圖片方向分別記憶版面';

  @override
  String get settings_watermarkLayoutByOrientationHint =>
      '文字和樣式共用，直向、方形與橫向圖片分別儲存位置。';

  @override
  String get settings_watermarkConfigMigrated => '舊版浮水印設定已遷移供檢查，請儲存以確認目前預設方案。';

  @override
  String get settings_watermarkConfigCorrupted =>
      '浮水印設定無法讀取，目前顯示安全預設值；儲存後才會取代損壞資料。';

  @override
  String get watermark_actionCreate => '建立浮水印副本…';

  @override
  String get watermark_actionRegenerate => '重新產生浮水印副本…';

  @override
  String get watermark_actionDownloadCreate => '下載並加入浮水印…';

  @override
  String get watermark_editorTitle => '浮水印編輯器';

  @override
  String get watermark_textLayer => '文字';

  @override
  String get watermark_logoLayer => 'Logo';

  @override
  String get watermark_enableLayer => '顯示圖層';

  @override
  String get watermark_text => '浮水印文字';

  @override
  String get watermark_alignment => '文字對齊';

  @override
  String get editor_colorHex => '十六進位顏色值';

  @override
  String get editor_colorSaturationBrightness => '顏色飽和度與明度';

  @override
  String get editor_colorHue => '顏色色相';

  @override
  String get watermark_alignLeft => '靠左對齊';

  @override
  String get watermark_alignCenter => '置中對齊';

  @override
  String get watermark_alignRight => '靠右對齊';

  @override
  String get watermark_font => '字型';

  @override
  String get watermark_chooseLogo => '選擇 Logo';

  @override
  String get watermark_replaceLogo => '更換 Logo';

  @override
  String get watermark_logoMissing => '已儲存的 Logo 遺失，請重新選擇後再儲存。';

  @override
  String get watermark_logoImportFailed =>
      '無法匯入 Logo。請選擇尺寸受支援且有效的靜態 PNG、JPEG 或 WebP 圖片。';

  @override
  String get watermark_opacity => '透明度';

  @override
  String get watermark_size => '大小';

  @override
  String get watermark_letterSpacing => '字距';

  @override
  String get watermark_stroke => '描邊';

  @override
  String get watermark_shadow => '柔和陰影';

  @override
  String get watermark_margin => '邊距';

  @override
  String get watermark_anchor => '位置錨點';

  @override
  String get watermark_anchorTopLeft => '左上';

  @override
  String get watermark_anchorTopCenter => '頂部置中';

  @override
  String get watermark_anchorTopRight => '右上';

  @override
  String get watermark_anchorCenterLeft => '左側置中';

  @override
  String get watermark_anchorCenter => '畫布中央';

  @override
  String get watermark_anchorCenterRight => '右側置中';

  @override
  String get watermark_anchorBottomLeft => '左下';

  @override
  String get watermark_anchorBottomCenter => '底部置中';

  @override
  String get watermark_anchorBottomRight => '右下';

  @override
  String get watermark_layerArrangement => '圖層排列';

  @override
  String get watermark_arrangementIndependent => '獨立';

  @override
  String get watermark_arrangementHorizontal => '橫向組合';

  @override
  String get watermark_arrangementVertical => '縱向組合';

  @override
  String get watermark_zOrder => '將所選圖層移到上層';

  @override
  String get watermark_ratioOriginal => '原圖';

  @override
  String get watermark_ratioPortrait => '直向';

  @override
  String get watermark_ratioSquare => '方形';

  @override
  String get watermark_ratioLandscape => '橫向';

  @override
  String get watermark_layoutUniversal => '通用版面';

  @override
  String get watermark_layoutPortrait => '直向版面';

  @override
  String get watermark_layoutSquare => '方形版面';

  @override
  String get watermark_layoutLandscape => '橫向版面';

  @override
  String get watermark_metadataRemoved => '將依「安全性與分享」設定清除副本中繼資料。';

  @override
  String get watermark_metadataPreserved => '會把原圖中支援的中繼資料寫入新副本。';

  @override
  String get watermark_setDefault => '設為預設';

  @override
  String get watermark_defaultSaved => '預設浮水印已更新';

  @override
  String get watermark_saveCopy => '儲存副本';

  @override
  String get watermark_saving => '正在渲染原始解析度圖片…';

  @override
  String get watermark_saved => '浮水印副本已儲存';

  @override
  String get watermark_share => '分享';

  @override
  String get watermark_open => '開啟';

  @override
  String get watermark_undo => '復原';

  @override
  String get watermark_reset => '重設';

  @override
  String get watermark_noLayer => '儲存前請啟用文字或 Logo。';

  @override
  String get watermark_cancelled => '已取消浮水印渲染';

  @override
  String watermark_failed(Object error) {
    return '無法建立浮水印副本：$error';
  }

  @override
  String get watermark_failedGeneric => '無法建立浮水印副本，請檢查圖片後再試一次。';

  @override
  String get watermark_systemGalleryExportFailed =>
      '副本已儲存在 Aaalice 中，但無法加入系統圖庫。';

  @override
  String get watermark_galleryRefreshFailed => '副本已儲存，但圖庫無法重新整理；重新開啟圖庫即可重試。';

  @override
  String get watermark_sourceMissing => '找不到原圖，請重新選擇原圖後再產生浮水印。';

  @override
  String get watermark_chooseOriginal => '選擇原圖';

  @override
  String get watermark_dragHint => '拖曳所選圖層；方向鍵可精細移動，按住 Shift 可加大步長。';

  @override
  String get watermark_moveLeft => '向左移動圖層';

  @override
  String get watermark_moveRight => '向右移動圖層';

  @override
  String get watermark_moveUp => '向上移動圖層';

  @override
  String get watermark_moveDown => '向下移動圖層';

  @override
  String get watermark_sourceLoadFailed =>
      '無法開啟此圖片。請確認檔案是有效的靜態 PNG、JPEG、WebP 或 BMP 圖片後再試一次。';
}

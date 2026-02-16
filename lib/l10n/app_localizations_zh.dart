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
  String get common_selectAll => '全选';

  @override
  String get common_deselectAll => '全不选';

  @override
  String get common_expandAll => '展开全部';

  @override
  String get common_collapseAll => '收起全部';

  @override
  String get common_save => '保存';

  @override
  String get common_saved => '已保存';

  @override
  String get common_delete => '删除';

  @override
  String get common_edit => '编辑';

  @override
  String get common_close => '关闭';

  @override
  String get common_back => '返回';

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
  String get common_confirmDelete => '确认删除';

  @override
  String get common_settings => '设置';

  @override
  String get common_today => '今天';

  @override
  String get common_yesterday => '昨天';

  @override
  String common_daysAgo(Object days) {
    return '$days天前';
  }

  @override
  String get nav_canvas => '画布';

  @override
  String get nav_gallery => '画廊';

  @override
  String get nav_onlineGallery => '画廊';

  @override
  String get nav_randomConfig => '随机配置';

  @override
  String get nav_dictionary => '词库 (WIP)';

  @override
  String get nav_settings => '设置';

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
  String get auth_logoutConfirmTitle => '退出登录';

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
  String get auth_credentialsLogin => '邮箱密码登录';

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
  String get auth_changeAvatar => '更换头像';

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
  String get auth_troubleshoot_serverStatus_desc => '访问 NovelAI 状态页面或社区查看服务中断情况';

  @override
  String get auth_passwordResetHelp_title => '密码重置';

  @override
  String get auth_passwordResetHelp_desc => '点击「忘记密码」将在浏览器中打开 NovelAI 密码重置页面，您可以在那里重置密码';

  @override
  String get auth_passwordResetAfterReset_title => '重置密码后';

  @override
  String get auth_passwordResetAfterReset_desc => '在 NovelAI 网站上重置密码后，返回此应用并使用新密码登录';

  @override
  String get auth_passwordResetNoEmail_title => '未收到重置邮件？';

  @override
  String get auth_passwordResetNoEmail_desc => '如果几分钟内未收到密码重置邮件，请检查垃圾邮件文件夹或联系 NovelAI 客服';

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
  String get settings_default => '默认';

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
  String get settings_pathReset => '已重置为默认路径';

  @override
  String get settings_pathSaved => '保存路径已更新';

  @override
  String get settings_selectFolder => '选择保存文件夹';

  @override
  String get settings_accountProfile => '账号资料';

  @override
  String get settings_accountType => '账号类型';

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
  String get settings_nickname => '昵称';

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
  String get generation_cancel => '取消';

  @override
  String get generation_generating => '生成中...';

  @override
  String get generation_cancelGeneration => '取消生成';

  @override
  String get generation_generateImage => '生成图像';

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
    return 'CFG Scale: $scale';
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
    return 'CFG Rescale: $value';
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
  String prompt_tags(Object count) {
    return '$count 个标签';
  }

  @override
  String prompt_importedCharacters(int count) {
    return '已导入 $count 个角色';
  }

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
  String get prompt_unwantedContent => '不想出现在图像中的内容...';

  @override
  String get prompt_addTagsHint => '添加标签来描述你想要的画面';

  @override
  String get prompt_addUnwantedHint => '添加不想出现的元素';

  @override
  String get prompt_fullscreenEdit => '全屏编辑';

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
  String get gallery_title => '画廊';

  @override
  String gallery_selected(Object count) {
    return '已选择 $count 项';
  }

  @override
  String get gallery_clearAll => '清除所有';

  @override
  String get gallery_clearGallery => '清除画廊';

  @override
  String get gallery_favorite => '收藏';

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
  String get config_title => '随机提示词配置';

  @override
  String get config_presets => '预设';

  @override
  String get config_configGroups => '配置组';

  @override
  String get config_presetName => '预设名称';

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
  String get config_saveChanges => '保存更改';

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
  String get config_singleRandom => '随机单选';

  @override
  String get config_singleSequential => '顺序单选';

  @override
  String get config_multipleCount => '指定数量';

  @override
  String get config_multipleProbability => '按概率';

  @override
  String get config_all => '全部';

  @override
  String get config_selectCount => '选取数量';

  @override
  String get config_selectProbability => '选取概率';

  @override
  String get config_shuffleOrder => '打乱顺序';

  @override
  String get config_shuffleOrderSubtitle => '随机排列选中的内容';

  @override
  String get config_weightBrackets => '权重括号';

  @override
  String get config_weightBracketsHint => '每层花括号增加约 5% 权重';

  @override
  String get config_min => '最少';

  @override
  String get config_max => '最多';

  @override
  String config_preview(Object preview) {
    return '预览: $preview';
  }

  @override
  String get config_tagContent => '标签内容';

  @override
  String config_tagContentHint(Object count) {
    return '每行一个标签，当前 $count 项';
  }

  @override
  String get config_format => '格式化';

  @override
  String get config_sort => '排序';

  @override
  String get config_inputTags => '输入标签，每行一个...\n例如：\n1girl\nbeautiful eyes\nlong hair';

  @override
  String get config_unsavedChanges => '未保存的更改';

  @override
  String get config_unsavedChangesContent => '有未保存的更改，确定要放弃吗？';

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
  String config_importFailed(Object error) {
    return '导入失败: $error';
  }

  @override
  String get config_restoreDefaultsConfirm => '确定要恢复默认预设吗？所有自定义配置将被删除。';

  @override
  String get config_restored => '已恢复默认';

  @override
  String get config_copiedToClipboard => '已复制到剪贴板';

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
  String config_itemCount(Object count) {
    return '$count 项';
  }

  @override
  String config_subConfigCount(Object count) {
    return '$count 子配置';
  }

  @override
  String get config_random => '随机';

  @override
  String get config_sequential => '顺序';

  @override
  String get config_multiple => '多选';

  @override
  String get config_probability => '概率';

  @override
  String get config_moreActions => '更多操作';

  @override
  String get img2img_title => '图生图';

  @override
  String get img2img_enabled => '已启用';

  @override
  String get img2img_sourceImage => '源图像';

  @override
  String get img2img_selectImage => '选择图片';

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
  String get img2img_edit => '编辑';

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
  String get editor_title => '图像编辑';

  @override
  String get editor_done => '完成';

  @override
  String get editor_saveAndClose => '保存并关闭';

  @override
  String get editor_closeWithoutSaving => '不保存关闭';

  @override
  String get editor_close => '关闭';

  @override
  String get editor_save => '保存';

  @override
  String get editor_modeImage => '涂鸦';

  @override
  String get editor_modeMask => '遮罩';

  @override
  String get editor_toolSettings => '工具设置';

  @override
  String get editor_brushPresets => '笔刷预设';

  @override
  String get editor_color => '颜色';

  @override
  String get editor_brushSettings => '笔刷参数';

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
  String get editor_selectionTools => '选区';

  @override
  String get editor_toolBrush => '画笔';

  @override
  String get editor_toolEraser => '橡皮擦';

  @override
  String get editor_toolFill => '填充';

  @override
  String get editor_toolLine => '直线';

  @override
  String get editor_toolRectSelect => '矩形选框';

  @override
  String get editor_toolEllipseSelect => '椭圆选框';

  @override
  String get editor_toolColorPicker => '吸管取色';

  @override
  String get editor_presetDefault => '默认';

  @override
  String get editor_presetPencil => '铅笔';

  @override
  String get editor_presetMarker => '马克笔';

  @override
  String get editor_presetAirbrush => '喷枪';

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
  String get editor_cancel => '取消';

  @override
  String get editor_clearConfirm => '清除图层？';

  @override
  String get editor_clearConfirmMessage => '这将删除当前图层的所有内容。';

  @override
  String get editor_clear => '清除';

  @override
  String get editor_shortcutUndo => '撤销 (Ctrl+Z)';

  @override
  String get editor_shortcutRedo => '重做 (Ctrl+Y)';

  @override
  String get editor_selectionSettings => '选区';

  @override
  String get editor_shortcuts => '快捷键';

  @override
  String get editor_addToSelection => '添加到选区';

  @override
  String get editor_subtractFromSelection => '从选区减去';

  @override
  String get editor_selectionHint => '绘制选区作为重绘遮罩';

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
  String get vibe_hint => '添加参考图片来迁移其视觉风格和氛围（最多4张）';

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
  String vibe_referenceNumber(Object index) {
    return '参考图 #$index';
  }

  @override
  String get vibe_referenceStrength => '参考强度';

  @override
  String get vibe_infoExtraction => '信息提取';

  @override
  String get vibe_adjustParams => '调整参数';

  @override
  String get vibe_remove => '移除';

  @override
  String get vibe_sliderHint => '强度: 越高越模仿视觉线索\n信息提取: 降低会减少纹理、保留构图';

  @override
  String vibe_strengthInfo(Object value, Object infoValue) {
    return '强度: $value | 信息提取: $infoValue';
  }

  @override
  String get vibe_normalize => '标准化参考强度值';

  @override
  String vibe_encodingCost(int cost) {
    return '需要编码。下次生成将消耗 $cost Anlas。';
  }

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
  String get characterRef_title => '角色参考';

  @override
  String get characterRef_hint => '上传角色参考图来保持角色一致性（仅 V4+ 模型支持）';

  @override
  String get characterRef_v4Only => '角色参考仅支持 V4+ 模型，请切换模型后使用';

  @override
  String get characterRef_addReference => '添加参考图';

  @override
  String get characterRef_clearAll => '清除全部';

  @override
  String characterRef_referenceNumber(Object index) {
    return '参考图 #$index';
  }

  @override
  String get characterRef_description => '角色描述';

  @override
  String get characterRef_descriptionHint => '描述这个角色的特征（可选，但建议填写）...';

  @override
  String get characterRef_remove => '移除';

  @override
  String get characterRef_styleAware => '风格感知';

  @override
  String get characterRef_styleAwareHint => '传输角色相关的风格信息';

  @override
  String get characterRef_fidelity => '保真度';

  @override
  String get characterRef_fidelityHint => '0=旧版行为, 1=新版行为';

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
  String get character_hint => '为每个角色定义独立的提示词和位置（最多6个角色）';

  @override
  String get character_addCharacter => '添加角色';

  @override
  String get character_clearAll => '清除全部角色';

  @override
  String character_number(Object index) {
    return '角色 $index';
  }

  @override
  String get character_advancedOptions => '高级选项';

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
  String get character_auto => '自动';

  @override
  String get character_clearPosition => '清除位置';

  @override
  String get gallery_empty => '画廊为空';

  @override
  String get gallery_emptyHint => '生成的图像将显示在这里';

  @override
  String get gallery_searchHint => '搜索提示词... (支持中英文标签)';

  @override
  String gallery_imageCount(Object count) {
    return '$count 张';
  }

  @override
  String gallery_exportSuccess(Object count, Object path) {
    return '已导出 $count 张图像到 $path';
  }

  @override
  String gallery_savedTo(Object path) {
    return '已保存到 $path';
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
  String get gallery_metaCfgScale => 'CFG Scale';

  @override
  String get gallery_metaSeed => 'Seed';

  @override
  String get gallery_metaSmea => 'SMEA';

  @override
  String get gallery_metaSmeaOn => '开启';

  @override
  String get gallery_metaSmeaOff => '关闭';

  @override
  String get gallery_metaGenerationTime => '生成时间';

  @override
  String get gallery_metaFileSize => '文件大小';

  @override
  String get gallery_positivePrompt => '正向提示词';

  @override
  String get gallery_negativePrompt => '负向提示词';

  @override
  String get preset_noPresets => '暂无预设';

  @override
  String get preset_restoreDefault => '恢复默认';

  @override
  String preset_configGroupCount(Object count) {
    return '$count 个配置组';
  }

  @override
  String get preset_setAsCurrent => '设为当前';

  @override
  String get preset_duplicate => '复制';

  @override
  String get preset_export => '导出';

  @override
  String get preset_delete => '删除';

  @override
  String get preset_noConfigGroups => '还没有配置组';

  @override
  String get preset_addConfigGroup => '添加配置组';

  @override
  String get preset_selectPreset => '选择一个预设';

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
  String get preset_all => '全部';

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
  String get preset_inputHint => '输入标签，每行一个...\n例如：\n1girl\nbeautiful eyes\nlong hair';

  @override
  String get preset_unsavedChanges => '未保存的更改';

  @override
  String get preset_unsavedChangesConfirm => '有未保存的更改，确定要放弃吗？';

  @override
  String get preset_discard => '放弃';

  @override
  String get preset_deletePreset => '删除预设';

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
  String preset_importFailed(Object error) {
    return '导入失败: $error';
  }

  @override
  String get preset_restoreDefaultConfirm => '确定要恢复默认预设吗？所有自定义配置将被删除。';

  @override
  String get preset_restored => '已恢复默认';

  @override
  String get preset_copiedToClipboard => '已复制到剪贴板';

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
  String preset_itemCount(Object count) {
    return '$count 项';
  }

  @override
  String preset_subConfigCount(Object count) {
    return '$count 子配置';
  }

  @override
  String get preset_random => '随机';

  @override
  String get preset_sequential => '顺序';

  @override
  String get preset_multiple => '多选';

  @override
  String get preset_probability => '概率';

  @override
  String get preset_moreActions => '更多操作';

  @override
  String get preset_rename => '重命名';

  @override
  String get preset_moveUp => '上移';

  @override
  String get preset_moveDown => '下移';

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
  String get tooltip_randomPrompt => '随机提示词 (长按配置)';

  @override
  String get tooltip_fullscreenEdit => '全屏编辑';

  @override
  String get tooltip_maximizePrompt => '最大化提示词区域';

  @override
  String get tooltip_restoreLayout => '恢复正常布局';

  @override
  String get tooltip_clear => '清空';

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
  String get tooltip_changeImage => '更换图片';

  @override
  String get tooltip_removeImage => '移除图片';

  @override
  String get tooltip_previewGenerate => '预览生成';

  @override
  String get tooltip_help => '帮助';

  @override
  String get tooltip_addConfigGroup => '添加配置组';

  @override
  String get tooltip_enable => '启用';

  @override
  String get tooltip_disable => '禁用';

  @override
  String get tooltip_resetWeight => '点击重置为100%';

  @override
  String get upscale_title => '图片放大';

  @override
  String get upscale_close => '关闭';

  @override
  String get upscale_start => '开始放大';

  @override
  String get upscale_sourceImage => '源图像';

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
  String get upscale_save => '保存';

  @override
  String get upscale_share => '分享';

  @override
  String get upscale_failed => '放大失败';

  @override
  String upscale_selectFailed(Object error) {
    return '选择图片失败: $error';
  }

  @override
  String upscale_savedTo(Object path) {
    return '已保存到: $path';
  }

  @override
  String upscale_saveFailed(Object error) {
    return '保存失败: $error';
  }

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
  String get configEditor_newConfigGroup => '新建配置组';

  @override
  String get configEditor_editConfigGroup => '编辑配置组';

  @override
  String get configEditor_configName => '配置名称';

  @override
  String get configEditor_enableConfig => '启用此配置';

  @override
  String get configEditor_enableConfigHint => '禁用后不会参与生成';

  @override
  String get configEditor_contentType => '内容类型';

  @override
  String get configEditor_tagList => '标签列表';

  @override
  String get configEditor_nestedConfig => '嵌套配置';

  @override
  String get configEditor_selectionMode => '选取方式';

  @override
  String get configEditor_selectCount => '选取数量：';

  @override
  String get configEditor_selectProbability => '选取概率：';

  @override
  String get configEditor_shuffleOrder => '打乱顺序';

  @override
  String get configEditor_shuffleOrderHint => '随机排列选中的内容';

  @override
  String get configEditor_weightBrackets => '权重括号';

  @override
  String get configEditor_weightBracketsHint => '括号用于增加权重，每层花括号增加约 5% 权重';

  @override
  String configEditor_minBrackets(Object count) {
    return '最少括号: $count';
  }

  @override
  String configEditor_maxBrackets(Object count) {
    return '最多括号: $count';
  }

  @override
  String get configEditor_effectPreview => '效果预览：';

  @override
  String get configEditor_content => '内容';

  @override
  String configEditor_tagCountHint(Object count) {
    return '每行一个标签，当前 $count 项';
  }

  @override
  String get configEditor_format => '格式化';

  @override
  String get configEditor_sort => '排序';

  @override
  String get configEditor_dedupe => '去重';

  @override
  String get configEditor_nestedConfigHint => '嵌套配置可以创建复杂的分层随机逻辑';

  @override
  String get configEditor_noNestedConfig => '还没有嵌套配置';

  @override
  String configEditor_itemCount(Object count) {
    return '$count 项';
  }

  @override
  String configEditor_subConfigCount(Object count) {
    return '$count 个子配置';
  }

  @override
  String get configEditor_addNestedConfig => '添加嵌套配置';

  @override
  String get configEditor_subConfig => '子配置';

  @override
  String get configEditor_singleRandom => '单个 - 随机';

  @override
  String get configEditor_singleSequential => '单个 - 顺序';

  @override
  String get configEditor_singleProbability => '单个 - 概率出现';

  @override
  String get configEditor_multipleCount => '多个 - 指定数量';

  @override
  String get configEditor_multipleProbability => '多个 - 指定概率';

  @override
  String get configEditor_selectAll => '全部';

  @override
  String get configEditor_singleRandomHint => '每次随机选择一项';

  @override
  String get configEditor_singleSequentialHint => '按顺序循环选择一项';

  @override
  String get configEditor_singleProbabilityHint => '有X%的几率随机选一项，否则不出';

  @override
  String get configEditor_multipleCountHint => '随机选择指定数量的项';

  @override
  String get configEditor_multipleProbabilityHint => '每项按概率独立选择';

  @override
  String get configEditor_selectAllHint => '选择所有项';

  @override
  String get configEditor_or => ' 或 ';

  @override
  String get configEditor_enterConfigName => '请输入配置名称';

  @override
  String get configEditor_continueEditing => '继续编辑';

  @override
  String get configEditor_discardChanges => '放弃更改';

  @override
  String configEditor_randomCount(Object count) {
    return '随机 $count 个';
  }

  @override
  String configEditor_probabilityPercent(Object percent) {
    return '$percent% 概率';
  }

  @override
  String get presetEdit_newPreset => '新建预设';

  @override
  String get presetEdit_editPreset => '编辑预设';

  @override
  String get presetEdit_presetName => '预设名称';

  @override
  String presetEdit_configGroups(Object count) {
    return '配置组 ($count)';
  }

  @override
  String get presetEdit_noConfigGroups => '还没有配置组';

  @override
  String get presetEdit_addConfigGroupHint => '点击右上角 + 添加配置组';

  @override
  String get presetEdit_addConfigGroup => '添加配置组';

  @override
  String get presetEdit_newConfigGroup => '新配置组';

  @override
  String get presetEdit_enterPresetName => '请输入预设名称';

  @override
  String get presetEdit_saveSuccess => '保存成功';

  @override
  String get presetEdit_saveError => '保存预设失败';

  @override
  String presetEdit_deleteConfigConfirm(Object name) {
    return '删除配置组 \"$name\"？';
  }

  @override
  String get presetEdit_previewTitle => '预览生成结果';

  @override
  String get presetEdit_emptyResult => '(空结果，请检查配置)';

  @override
  String get presetEdit_regenerate => '重新生成';

  @override
  String get presetEdit_helpTitle => '帮助';

  @override
  String get presetEdit_helpConfigGroup => '配置组说明';

  @override
  String get presetEdit_helpConfigGroupContent => '每个配置组会按顺序生成内容，最终结果由逗号连接。';

  @override
  String get presetEdit_helpSelectionMode => '选取方式';

  @override
  String get presetEdit_helpSingleRandom => '• 单个-随机：随机选择一项';

  @override
  String get presetEdit_helpSingleSequential => '• 单个-顺序：按顺序循环选择';

  @override
  String get presetEdit_helpMultipleCount => '• 多个-数量：随机选择指定数量';

  @override
  String get presetEdit_helpMultipleProbability => '• 多个-概率：每项按概率独立选择';

  @override
  String get presetEdit_helpAll => '• 全部：选择所有项';

  @override
  String get presetEdit_helpWeightBrackets => '权重括号';

  @override
  String get presetEdit_helpWeightBracketsContent => '花括号用于增加权重，括号越多权重越高。';

  @override
  String get presetEdit_helpWeightBracketsExample => '例如：一层括号是 1.05 倍权重，两层括号是 1.1 倍。';

  @override
  String get presetEdit_helpNestedConfig => '嵌套配置';

  @override
  String get presetEdit_helpNestedConfigContent => '配置可以嵌套，用于创建复杂的分层随机逻辑。';

  @override
  String get presetEdit_gotIt => '知道了';

  @override
  String presetEdit_tagCount(Object count) {
    return '$count 项标签';
  }

  @override
  String presetEdit_bracketLayers(Object count) {
    return '$count 层括号';
  }

  @override
  String presetEdit_bracketRange(Object min, Object max) {
    return '$min-$max 层括号';
  }

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
  String get ucPreset_furryFocus => 'Furry';

  @override
  String get ucPreset_humanFocus => '人物';

  @override
  String get ucPreset_none => '无';

  @override
  String get ucPreset_custom => '自定义';

  @override
  String get ucPreset_disabled => '负面提示词预设已关闭';

  @override
  String get ucPreset_addToNegative => '添加到负面提示词开头:';

  @override
  String get ucPreset_nsfwHint => '💡 如需生成成人内容，请在正面提示词中添加 nsfw，负面提示词中的 nsfw 将自动移除';

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
  String download_failed(Object name) {
    return '$name下载失败';
  }

  @override
  String download_downloading(Object name) {
    return '正在下载 $name';
  }

  @override
  String download_complete(Object name) {
    return '$name下载完成';
  }

  @override
  String download_downloadFailed(Object name) {
    return '$name下载失败';
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
  String get warmup_errorDetail => '错误';

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
  String get warmup_group_dataSourceInitialization => '初始化数据源服务...';

  @override
  String get warmup_group_dataSourceInitialization_complete => '数据源服务就绪';

  @override
  String get performanceReport_title => '启动性能';

  @override
  String get performanceReport_export => '导出报告';

  @override
  String get performanceReport_taskStats => '任务统计';

  @override
  String get performanceReport_averageDuration => '平均耗时';

  @override
  String get performanceReport_successRate => '成功率';

  @override
  String get performanceReport_exportSuccess => '报告导出成功';

  @override
  String get copyName => ' (副本)';

  @override
  String get defaultPreset_name => '默认预设';

  @override
  String get defaultPreset_quality => '质量';

  @override
  String get defaultPreset_character => '角色';

  @override
  String get defaultPreset_expression => '表情';

  @override
  String get defaultPreset_clothing => '服装';

  @override
  String get defaultPreset_action => '动作';

  @override
  String get defaultPreset_background => '背景';

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
  String get api_error_unknown => '未知错误';

  @override
  String api_error_unknown_hint(Object error) {
    return '发生未知错误: $error';
  }

  @override
  String get drop_dialogTitle => '如何使用这张图片？';

  @override
  String get drop_hint => '拖拽图片到这里';

  @override
  String get drop_img2img => '图生图';

  @override
  String get drop_vibeTransfer => '风格迁移';

  @override
  String get drop_characterReference => '精准参考';

  @override
  String get drop_unsupportedFormat => '不支持的文件格式';

  @override
  String get drop_addedToImg2Img => '已添加到图生图';

  @override
  String get drop_addedToVibe => '已添加到风格迁移';

  @override
  String drop_addedMultipleToVibe(int count) {
    return '已添加 $count 个风格参考';
  }

  @override
  String get drop_addedToCharacterRef => '已添加到精准参考';

  @override
  String get characterEditor_title => '多人角色提示词';

  @override
  String get characterEditor_close => '关闭';

  @override
  String get characterEditor_confirm => '确定';

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
  String get characterEditor_deleteTitle => '删除角色';

  @override
  String get characterEditor_deleteConfirm => '确定要删除这个角色吗？此操作无法撤销。';

  @override
  String get characterEditor_name => '名称';

  @override
  String get characterEditor_nameHint => '输入角色名称';

  @override
  String get characterEditor_enabled => '启用';

  @override
  String get characterEditor_promptHint => '输入角色的正向提示词...';

  @override
  String get characterEditor_negativePromptHint => '输入角色的负面提示词...';

  @override
  String get characterEditor_position => '位置';

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
  String characterEditor_characterCountWithEnabled(Object enabled, Object total) {
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
  String tagLibrary_lastSync(Object time) {
    return '上次同步: $time';
  }

  @override
  String get tagLibrary_neverSynced => '尚未同步';

  @override
  String get tagLibrary_syncNow => '从 Danbooru 同步';

  @override
  String get tagLibrary_syncing => '同步中...';

  @override
  String get tagLibrary_syncSuccess => '词库同步成功';

  @override
  String get tagLibrary_syncFailed => '同步失败，请检查网络连接';

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
  String get naiMode_title => '默认模式';

  @override
  String get naiMode_subtitle => '复刻 NovelAI 官方随机算法';

  @override
  String get naiMode_syncLibrary => '管理扩展词库';

  @override
  String get manageLibrary => '管理词库';

  @override
  String get naiMode_algorithmInfo => '算法说明';

  @override
  String naiMode_tagCountBadge(Object count) {
    return '$count 个标签';
  }

  @override
  String naiMode_totalTags(Object count) {
    return '标签数: $count';
  }

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
  String get naiMode_preview => '预览生成';

  @override
  String get naiMode_createCustom => '基于此创建自定义预设';

  @override
  String naiMode_categoryProbability(Object probability) {
    return '$probability%';
  }

  @override
  String naiMode_tagCount(Object count) {
    return '$count个标签';
  }

  @override
  String get naiMode_readOnlyHint => '基于官方算法的随机提示词配置';

  @override
  String promptConfig_confirmRemoveGroup(Object name) {
    return '确定要移除分组「$name」吗？';
  }

  @override
  String promptConfig_confirmRemoveCategory(Object name) {
    return '确定要移除类别「$name」吗？移除后该类别将不再参与随机生成。';
  }

  @override
  String get promptConfig_groupList => '词组列表';

  @override
  String promptConfig_groupCount(Object count) {
    return '$count 个词组';
  }

  @override
  String get promptConfig_addGroup => '添加词组';

  @override
  String get promptConfig_noGroups => '暂无词组，点击「添加词组」创建';

  @override
  String get promptConfig_builtinLibrary => 'NAI 内置词库';

  @override
  String get promptConfig_customGroup => '自定义分组';

  @override
  String get promptConfig_danbooruTagGroup => '标签词库';

  @override
  String get promptConfig_danbooruPool => '图集';

  @override
  String get promptConfig_categorySettings => '类别设置';

  @override
  String get promptConfig_enableCategory => '启用类别';

  @override
  String get promptConfig_disableCategory => '禁用类别';

  @override
  String get naiMode_noLibrary => '词库未加载';

  @override
  String get naiMode_noCategories => '暂无类别，请重置预设或添加新类别';

  @override
  String get naiMode_noTags => '暂无标签';

  @override
  String get naiMode_previewResult => '生成预览';

  @override
  String get naiMode_characterPrompts => '角色提示词';

  @override
  String get naiMode_character => '角色';

  @override
  String get naiMode_createCustomTitle => '创建自定义预设';

  @override
  String get naiMode_createCustomDesc => '将创建一个包含所有NAI类别的新预设，您可以在此基础上进行自定义修改。';

  @override
  String get naiMode_featureComingSoon => '功能开发中...';

  @override
  String get naiMode_danbooruToggleTooltip => '切换此类别的扩展标签';

  @override
  String get naiMode_danbooruSupplementLabel => '扩展标签';

  @override
  String get naiMode_danbooruMasterToggleTooltip => '切换所有类别的扩展标签';

  @override
  String naiMode_entrySubtitle(Object count) {
    return '$count个标签 · 复刻官网算法';
  }

  @override
  String get naiAlgorithm_title => 'NAI随机算法说明';

  @override
  String get naiAlgorithm_characterCount => '角色数量分布';

  @override
  String get naiAlgorithm_categoryProbability => '类别选择概率';

  @override
  String get naiAlgorithm_weightedRandom => '加权随机算法';

  @override
  String get naiAlgorithm_weightedRandomDesc => '每个标签的权重基于 Danbooru 使用次数计算，权重越高被选中概率越大。';

  @override
  String get naiAlgorithm_v4MultiCharacter => 'V4多角色联动';

  @override
  String get naiAlgorithm_v4Desc => 'V4模型支持多角色独立提示词，主提示词和角色提示词分离。';

  @override
  String get naiAlgorithm_mainPrompt => '主提示词';

  @override
  String get naiAlgorithm_mainPromptTags => '人数、背景、风格';

  @override
  String get naiAlgorithm_characterPrompt => '角色提示词';

  @override
  String get naiAlgorithm_characterPromptTags => '发色、瞳色、发型、表情、姿势';

  @override
  String get naiAlgorithm_noHuman => '无人物场景';

  @override
  String get naiAlgorithm_noHumanDesc => '5%概率生成无人物场景，仅包含背景、场景、风格标签。';

  @override
  String get naiAlgorithm_background => '背景';

  @override
  String get naiAlgorithm_hairColor => '发色';

  @override
  String get naiAlgorithm_eyeColor => '瞳色';

  @override
  String get naiAlgorithm_expression => '表情';

  @override
  String get naiAlgorithm_hairStyle => '发型';

  @override
  String get naiAlgorithm_pose => '姿势';

  @override
  String get naiAlgorithm_style => '风格';

  @override
  String get naiAlgorithm_clothing => '服装';

  @override
  String get naiAlgorithm_accessory => '配饰';

  @override
  String get naiAlgorithm_scene => '场景';

  @override
  String get naiAlgorithm_bodyFeature => '身体特征';

  @override
  String get importNai_title => '从NAI词库导入';

  @override
  String get importNai_selectCategories => '选择要导入的类别';

  @override
  String importNai_import(Object count) {
    return '导入 $count 个类别';
  }

  @override
  String importNai_tagCount(Object count) {
    return '$count个标签';
  }

  @override
  String get tagLibrary_rangePopular => '热门';

  @override
  String get tagLibrary_rangeMedium => '中等';

  @override
  String get tagLibrary_rangeFull => '完整';

  @override
  String tagLibrary_daysAgo(Object days) {
    return '$days天前';
  }

  @override
  String tagLibrary_hoursAgo(Object hours) {
    return '$hours小时前';
  }

  @override
  String get tagLibrary_justNow => '刚刚';

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
  String get poolMapping_addMapping => '添加图集映射';

  @override
  String get poolMapping_noMappings => '暂无图集映射';

  @override
  String get poolMapping_noMappingsHint => '点击上方按钮添加图集';

  @override
  String get poolMapping_searchPool => '搜索图集';

  @override
  String get poolMapping_searchHint => '输入图集名称关键词';

  @override
  String get poolMapping_targetCategory => '目标分类';

  @override
  String get poolMapping_selectPool => '选择图集';

  @override
  String get poolMapping_syncPools => '同步图集';

  @override
  String get poolMapping_syncing => '同步中...';

  @override
  String get poolMapping_neverSynced => '从未同步';

  @override
  String get poolMapping_syncSuccess => '图集同步成功';

  @override
  String get poolMapping_syncFailed => '图集同步失败';

  @override
  String get poolMapping_noResults => '未找到匹配的图集';

  @override
  String get poolMapping_poolExists => '该图集已添加';

  @override
  String get poolMapping_addSuccess => '图集映射添加成功';

  @override
  String get poolMapping_removeConfirm => '确定删除此图集映射？';

  @override
  String get poolMapping_removeSuccess => '图集映射已删除';

  @override
  String poolMapping_tagCount(Object count) {
    return '$count 标签';
  }

  @override
  String poolMapping_postCount(Object count) {
    return '$count 帖子';
  }

  @override
  String get poolMapping_alreadyAdded => '已添加';

  @override
  String get poolMapping_resetToDefault => '恢复默认';

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
  String get tagGroup_targetCategory => '目标分类';

  @override
  String get tagGroup_selectGroup => '选择标签词库';

  @override
  String get tagGroup_neverSynced => '从未同步';

  @override
  String get tagGroup_noResults => '未找到匹配的标签词库';

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
  String get tagGroup_alreadyAdded => '已添加';

  @override
  String get tagGroup_resetToDefault => '恢复默认';

  @override
  String get tagGroup_resetConfirm => '确定要恢复默认标签词库映射吗？当前配置将被覆盖。';

  @override
  String get tagGroup_resetSuccess => '已恢复默认配置';

  @override
  String get tagGroup_minPostCount => '最小热度阈值';

  @override
  String tagGroup_postCountValue(Object count) {
    return '$count posts';
  }

  @override
  String get tagGroup_minPostCountHint => '只会同步帖子数量高于此阈值的标签';

  @override
  String get tagGroup_preview => '标签预览';

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
  String tagGroup_syncFetching(Object name, Object current, Object total) {
    return '正在获取 $name... ($current/$total)';
  }

  @override
  String tagGroup_syncFiltering(Object total, Object filtered) {
    return '筛选中: $total 标签, 保留 $filtered 标签';
  }

  @override
  String tagGroup_syncCompleted(Object count) {
    return '同步完成, 共 $count 标签';
  }

  @override
  String tagGroup_syncFailed(Object error) {
    return '同步失败: $error';
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
  String tagGroup_loadError(Object error) {
    return '加载失败: $error';
  }

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
  String tagGroup_selectedCount(Object count) {
    return '已选 $count 组';
  }

  @override
  String get naiMode_syncCategory => '补充此类别';

  @override
  String get naiMode_syncCategoryTooltip => '仅同步此类别的扩展标签';

  @override
  String get naiMode_viewDetails => '查看详情';

  @override
  String get naiMode_tagListTitle => '标签列表';

  @override
  String get naiMode_desc_hairColor => '角色头发颜色相关标签，用于描述发色';

  @override
  String get naiMode_desc_eyeColor => '角色眼睛颜色相关标签，用于描述瞳色';

  @override
  String get naiMode_desc_hairStyle => '角色发型相关标签，用于描述发型样式';

  @override
  String get naiMode_desc_expression => '角色表情相关标签，用于描述面部表情';

  @override
  String get naiMode_desc_pose => '角色姿势相关标签，用于描述身体动作和姿态';

  @override
  String get naiMode_desc_clothing => '角色服装相关标签，用于描述衣着';

  @override
  String get naiMode_desc_accessory => '配饰相关标签，用于描述装饰品和配件';

  @override
  String get naiMode_desc_bodyFeature => '身体特征相关标签，用于描述体型特点';

  @override
  String get naiMode_desc_background => '背景相关标签，用于描述画面背景类型';

  @override
  String get naiMode_desc_scene => '场景相关标签，用于描述具体场景元素';

  @override
  String get naiMode_desc_style => '画风相关标签，用于描述艺术风格';

  @override
  String get naiMode_desc_characterCount => '角色数量相关标签，决定画面中的人物数量';

  @override
  String get tagGroup_builtin => '内置';

  @override
  String tagGroup_totalTagsTooltip(Object original, Object filtered) {
    return '原始: $original / 过滤后: $filtered';
  }

  @override
  String get tagGroup_cacheDetails => '缓存详情';

  @override
  String get tagGroup_cachedCategories => '已缓存分类';

  @override
  String get cache_title => '词组管理';

  @override
  String get cache_manage => '词组管理';

  @override
  String get cache_tabTagGroup => '标签词库';

  @override
  String get cache_tabPool => '图集';

  @override
  String get cache_noTagGroups => '暂无标签词库缓存';

  @override
  String get cache_noPools => '暂无图集缓存';

  @override
  String get cache_noBuiltin => '暂无内置词库';

  @override
  String get cache_probability => '概率';

  @override
  String get cache_tags => '标签';

  @override
  String get cache_posts => '张图片';

  @override
  String get cache_neverSynced => '从未同步';

  @override
  String get cache_refresh => '刷新';

  @override
  String cache_refreshFailed(String error) {
    return '刷新失败: $error';
  }

  @override
  String get cache_refreshAll => '刷新全部';

  @override
  String cache_refreshProgress(Object current, Object total, String name) {
    return '正在同步 ($current/$total): $name';
  }

  @override
  String cache_totalStats(Object count, Object tags) {
    return '共 $count 个词组，$tags 个标签';
  }

  @override
  String get addGroup_fetchingCache => '正在获取数据...';

  @override
  String get addGroup_fetchFailed => '获取数据失败，但仍可添加词组';

  @override
  String get addGroup_syncFailed => '同步失败，请检查网络连接后重试';

  @override
  String addGroup_addFailed(String error) {
    return '添加失败: $error';
  }

  @override
  String get addGroup_addCustom => '添加自定义';

  @override
  String get addGroup_filterHint => '搜索已缓存的词组...';

  @override
  String get customGroup_title => '添加自定义词组';

  @override
  String get customGroup_searchHint => '输入关键词搜索 Danbooru...';

  @override
  String get customGroup_nameLabel => '显示名称';

  @override
  String get customGroup_add => '添加并缓存';

  @override
  String get customGroup_searchPrompt => '输入关键词并搜索';

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
  String addGroup_dialogTitle(Object category) {
    return '为「$category」添加词库';
  }

  @override
  String get addGroup_builtinTab => '内置词库';

  @override
  String get addGroup_tagGroupTab => '标签词库';

  @override
  String get addGroup_cancel => '取消';

  @override
  String get addGroup_submit => '添加';

  @override
  String get addGroup_builtinEnabled => '内置词库已启用';

  @override
  String get addGroup_builtinEnabledDesc => '该分类的内置词库已经在使用中';

  @override
  String get addGroup_enableBuiltin => '启用内置词库';

  @override
  String get addGroup_enableBuiltinDesc => '使用应用内置的标签词库';

  @override
  String get addGroup_enable => '启用';

  @override
  String get addGroup_backToParent => '返回上级';

  @override
  String get addGroup_browseMode => '已缓存列表';

  @override
  String get addGroup_customMode => '添加其他';

  @override
  String get addGroup_allCategories => '全部分类';

  @override
  String get addGroup_noMoreSubcategories => '没有更多子分类';

  @override
  String addGroup_tagGroupCount(Object count) {
    return '$count 个标签词库';
  }

  @override
  String get addGroup_customInputHint => '输入 Danbooru 的 tag_group 标题，例如：hair_color';

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
  String get addGroup_noCachedTagGroups => '暂无缓存的标签词库';

  @override
  String get addGroup_noCachedTagGroupsHint => '请先在「词组管理」中同步标签词库数据';

  @override
  String get addGroup_noFilterResults => '没有找到匹配的结果';

  @override
  String get addGroup_noCachedPools => '暂无缓存的图集';

  @override
  String get addGroup_noCachedPoolsHint => '使用搜索框搜索并添加图集';

  @override
  String get addGroup_sectionTagGroups => '标签词库 ☁️';

  @override
  String get addGroup_sectionPools => '图集 🖼️';

  @override
  String get globalSettings_title => '总览设置';

  @override
  String get globalSettings_resetToDefault => '重置为默认';

  @override
  String get globalSettings_characterCountDistribution => '角色数量分布';

  @override
  String get globalSettings_weightRandomOffset => '权重随机偏移';

  @override
  String get globalSettings_categoryProbabilityOverview => '类别概率总览';

  @override
  String get globalSettings_cancel => '取消';

  @override
  String get globalSettings_save => '保存';

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
  String download_completed(Object name) {
    return '$name下载完成';
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
  String get selectionMode_single => '单选随机';

  @override
  String get selectionMode_multipleNum => '多选数量';

  @override
  String get selectionMode_multipleProb => '多选概率';

  @override
  String get selectionMode_all => '全选';

  @override
  String get selectionMode_sequential => '顺序轮替';

  @override
  String categorySettings_title(Object name) {
    return '类别设置 - $name';
  }

  @override
  String get categorySettings_probability => '类别选取概率';

  @override
  String get categorySettings_probabilityDesc => '该类别参与随机生成的概率';

  @override
  String get categorySettings_groupSelectionMode => '词组选取模式';

  @override
  String get categorySettings_groupSelectionModeDesc => '从下属词组中选取的方式';

  @override
  String get categorySettings_groupSelectCount => '选取数量：';

  @override
  String get categorySettings_shuffle => '打乱顺序';

  @override
  String get categorySettings_shuffleDesc => '随机排列选中的词组输出顺序';

  @override
  String get categorySettings_unifiedBracket => '统一权重括号';

  @override
  String get categorySettings_unifiedBracketDisabled => '未启用';

  @override
  String get categorySettings_enableUnifiedBracket => '启用统一设置';

  @override
  String get categorySettings_enableUnifiedBracketDesc => '启用后将覆盖各词组的独立括号设置';

  @override
  String get categorySettings_bracketRange => '括号层数范围';

  @override
  String categorySettings_bracketMin(Object count) {
    return '最少: $count 层';
  }

  @override
  String categorySettings_bracketMax(Object count) {
    return '最多: $count 层';
  }

  @override
  String get categorySettings_bracketPreview => '效果预览：';

  @override
  String get categorySettings_batchSettings => '批量操作';

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
  String tagGroupSettings_title(Object name) {
    return '词组设置 - $name';
  }

  @override
  String get tagGroupSettings_probability => '选取概率';

  @override
  String get tagGroupSettings_probabilityDesc => '该词组被选中的概率';

  @override
  String get tagGroupSettings_selectionMode => '选取模式';

  @override
  String get tagGroupSettings_selectionModeDesc => '从词组内标签中选取的方式';

  @override
  String get tagGroupSettings_selectCount => '选取数量：';

  @override
  String get tagGroupSettings_shuffle => '打乱顺序';

  @override
  String get tagGroupSettings_shuffleDesc => '随机排列选中的标签输出顺序';

  @override
  String get tagGroupSettings_bracket => '权重括号';

  @override
  String get tagGroupSettings_bracketDesc => '为选中的标签随机添加权重括号，每层花括号增加约5%权重';

  @override
  String tagGroupSettings_bracketMin(Object count) {
    return '最少: $count 层';
  }

  @override
  String tagGroupSettings_bracketMax(Object count) {
    return '最多: $count 层';
  }

  @override
  String get tagGroupSettings_bracketPreview => '效果预览：';

  @override
  String get categorySettings_settingsButton => '设置';

  @override
  String get tagGroupSettings_settingsButton => '设置';

  @override
  String get promptConfig_tagCountUnit => '个标签';

  @override
  String get promptConfig_removeGroup => '移除分组';

  @override
  String get preset_resetToDefault => '重置为默认';

  @override
  String get preset_resetConfirmTitle => '重置预设';

  @override
  String get preset_resetConfirmMessage => '确定要将当前预设的所有类别和词组设置重置为默认配置吗？此操作不可撤销。';

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
  String get category_addNew => '新增类别';

  @override
  String get category_dialogTitle => '创建新类别';

  @override
  String get category_name => '类别名称';

  @override
  String get category_nameHint => '输入类别名称';

  @override
  String get category_key => '类别标识';

  @override
  String get category_keyHint => '英文标识，用于内部';

  @override
  String get category_emoji => '图标';

  @override
  String get category_selectEmoji => '选择 Emoji';

  @override
  String get category_probability => '选中概率';

  @override
  String get category_createSuccess => '类别创建成功';

  @override
  String get category_nameRequired => '请输入类别名称';

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
  String get addGroup_customTab => '自定义';

  @override
  String get customGroup_groupName => '词组名称';

  @override
  String get customGroup_entryPlaceholder => '输入词条并回车（支持多标签，逗号分隔）';

  @override
  String get customGroup_noEntries => '暂无词条，添加词条开始创建';

  @override
  String customGroup_entryCount(Object count) {
    return '共 $count 个词条';
  }

  @override
  String get customGroup_editEntry => '编辑词条';

  @override
  String get customGroup_aliasLabel => '备注名称（可选）';

  @override
  String get customGroup_aliasHint => '输入便于记忆的备注名称';

  @override
  String get customGroup_contentLabel => '提示词内容';

  @override
  String get customGroup_contentHint => '输入实际的提示词内容';

  @override
  String get customGroup_save => '保存';

  @override
  String get customGroup_confirm => '确定';

  @override
  String get customGroup_selectEmoji => '选择图标';

  @override
  String get customGroup_nameRequired => '请输入词组名称';

  @override
  String get customGroup_addEntry => '添加词条';

  @override
  String get customGroup_noCustomGroups => '暂无自定义词组';

  @override
  String get customGroup_createInCacheManager => '请在「词组管理」中创建自定义词组';

  @override
  String get cache_createCustomGroup => '创建自定义词组';

  @override
  String cache_confirmDeleteCustomGroup(Object name) {
    return '确定要删除自定义词组「$name」吗？';
  }

  @override
  String get cache_customTab => '自定义';

  @override
  String get cache_addFromDanbooru => '从 Danbooru 添加';

  @override
  String get customGroup_emptyStateTitle => '开始添加词条';

  @override
  String get customGroup_emptyStateHint => '在上方输入框中输入词条，按回车快速添加';

  @override
  String get common_comingSoon => '功能开发中...';

  @override
  String get common_openInBrowser => '在浏览器中打开';

  @override
  String get customGroup_tagsPlaceholder => '输入标签，用逗号分隔（支持补全）...';

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
  String get characterCountConfig_mainPromptHint => '例如：solo, 2girls, 1girl 1boy';

  @override
  String get characterCountConfig_personCount => '人数：';

  @override
  String get characterCountConfig_slotConfig => '角色槽位配置';

  @override
  String get characterCountConfig_slot => '槽位';

  @override
  String get characterCountConfig_resetToDefault => '重置为默认';

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
  String get genderRestriction_enabled => '性别限定';

  @override
  String get genderRestriction_enabledDesc => '未启用性别过滤';

  @override
  String genderRestriction_enabledActive(Object count) {
    return '已启用，$count 种性别可用';
  }

  @override
  String get genderRestriction_enable => '启用性别限定';

  @override
  String get genderRestriction_enableDesc => '仅对指定性别的角色生效';

  @override
  String get genderRestriction_applicableGenders => '适用性别';

  @override
  String get gender_female => '女性';

  @override
  String get gender_male => '男性';

  @override
  String get gender_trap => '伪娘';

  @override
  String get gender_futanari => '扶她';

  @override
  String get scope_title => '作用域';

  @override
  String get scope_titleDesc => '设置此类别/词组的适用范围';

  @override
  String get scope_global => '主提示词';

  @override
  String get scope_globalTooltip => '提示词将出现在主提示词区域\n适合：背景、场景、画面风格等';

  @override
  String get scope_character => '角色';

  @override
  String get scope_characterTooltip => '提示词将只出现在角色提示词内\n每个角色单独生成\n适合：发色、眵色、服装、表情等';

  @override
  String get scope_all => '通用';

  @override
  String get scope_allTooltip => '提示词同时出现在主提示词和角色提示词\n适合：姿势、互动等通用标签';

  @override
  String get tagGroupSettings_resetToCategory => '重置为类别设置';

  @override
  String get bracket_weaken => '降权';

  @override
  String get bracket_enhance => '增强';

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
  String get tag_tabTags => '标签';

  @override
  String get tag_tabGroups => '分组';

  @override
  String get tag_tabFavorites => '收藏';

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
  String get localGallery_searchPlaceholder => '搜索提示词、模型、采样器...';

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
  String get statistics_tagged => '已标记';

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
  String get localGallery_removeFromFavorites => '取消收藏';

  @override
  String get localGallery_tags => '标签';

  @override
  String get localGallery_addTag => '添加标签';

  @override
  String get localGallery_removeTag => '移除标签';

  @override
  String get localGallery_noTags => '暂无标签';

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
  String get localGallery_model => '模型';

  @override
  String get localGallery_sampler => '采样器';

  @override
  String get localGallery_steps => '步数';

  @override
  String get localGallery_cfgScale => 'CFG 强度';

  @override
  String get localGallery_resolution => '分辨率';

  @override
  String get localGallery_any => '任意';

  @override
  String get localGallery_custom => '自定义';

  @override
  String get localGallery_to => '至';

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
  String get localGallery_jumpToDate => '跳转到日期';

  @override
  String get localGallery_noImagesOnThisDate => '该日期没有图片';

  @override
  String get localGallery_selectedImagesNoPrompt => '选中的图片没有 Prompt 信息';

  @override
  String localGallery_addedTasksToQueue(Object count) {
    return '已添加 $count 个任务到队列';
  }

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
  String get localGallery_permissionRequiredContent => '本地画廊需要访问存储权限才能扫描您生成的图片。\n\n请在设置中授予权限后重试。';

  @override
  String get localGallery_openSettings => '打开设置';

  @override
  String get localGallery_firstTimeTipTitle => '💡 使用提示';

  @override
  String get localGallery_firstTimeTipContent => '右键点击（桌面端）或长按（移动端）图片可以：\n\n• 复制 Prompt\n• 复制 Seed\n• 查看完整元数据';

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
  String get statistics_navTags => '标签';

  @override
  String get statistics_navParameters => '参数';

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
  String get statistics_chartUsageDistribution => '使用分布';

  @override
  String get statistics_chartModelRanking => '模型排行';

  @override
  String get statistics_chartModelUsageOverTime => '模型使用趋势';

  @override
  String get statistics_chartTopTags => '热门标签';

  @override
  String get statistics_chartTagCloud => '标签云';

  @override
  String get statistics_chartParameterOverview => '参数概览';

  @override
  String get statistics_chartAspectRatio => '宽高比分布';

  @override
  String get statistics_chartActivityHeatmap => '活动热力图';

  @override
  String get statistics_chartHourlyDistribution => '小时分布';

  @override
  String get statistics_chartWeekdayDistribution => '星期分布';

  @override
  String get statistics_filterTitle => '筛选';

  @override
  String get statistics_filterClear => '清除';

  @override
  String get statistics_filterDateRange => '日期范围';

  @override
  String get statistics_filterModel => '模型';

  @override
  String get statistics_filterAllModels => '全部模型';

  @override
  String get statistics_filterResolution => '分辨率';

  @override
  String get statistics_filterAllResolutions => '全部分辨率';

  @override
  String get statistics_granularity => '粒度';

  @override
  String get statistics_granularityDay => '日';

  @override
  String get statistics_granularityWeek => '周';

  @override
  String get statistics_granularityMonth => '月';

  @override
  String get statistics_labelTotalDays => '总天数';

  @override
  String get statistics_labelPeak => '峰值';

  @override
  String get statistics_labelAverage => '平均';

  @override
  String get statistics_labelSteps => '步数';

  @override
  String get statistics_labelCfg => 'CFG';

  @override
  String get statistics_labelWidth => '宽度';

  @override
  String get statistics_labelHeight => '高度';

  @override
  String get statistics_labelFavPercent => '收藏率';

  @override
  String get statistics_labelTagPercent => '标签率';

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
  String get statistics_noMetadata => '无元数据';

  @override
  String get statistics_unknown => '未知';

  @override
  String statistics_weekLabel(Object week) {
    return '第$week周';
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
  String get statistics_afternoon => '下午';

  @override
  String get statistics_evening => '傍晚';

  @override
  String get statistics_night => '深夜';

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
  String get tagLibrary_removeFavorite => '取消收藏';

  @override
  String get tagLibrary_addFavorite => '添加收藏';

  @override
  String get tagLibrary_pinned => '已收藏';

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
  String get queue_failureStrategySkip => '跳过';

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
  String get queue_batchDelete => '删除选中';

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
  String get resetToDefaultConfirmTitle => '重置为默认配置';

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
  String get alias_libraryCategory => '词库';

  @override
  String alias_tagCount(Object count) {
    return '$count 个标签';
  }

  @override
  String alias_useCount(Object count) {
    return '使用 $count 次';
  }

  @override
  String get alias_favorited => '已收藏';

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
  String get sendToHome_mainPrompt => '发送到主提示词';

  @override
  String get sendToHome_mainPromptSubtitle => '填充到主页的正向提示词输入框';

  @override
  String get sendToHome_replaceCharacter => '替换角色提示词';

  @override
  String get sendToHome_replaceCharacterSubtitle => '清空现有角色，添加为新角色';

  @override
  String get sendToHome_appendCharacter => '追加角色提示词';

  @override
  String get sendToHome_appendCharacterSubtitle => '保留现有角色，追加新角色';

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
  String get metadataImport_advancedSection => '高级选项';

  @override
  String get metadataImport_selectAll => '全选';

  @override
  String get metadataImport_deselectAll => '全不选';

  @override
  String get metadataImport_promptsOnly => '仅提示词';

  @override
  String get metadataImport_generationOnly => '仅生成参数';

  @override
  String get metadataImport_prompt => '正向提示词';

  @override
  String get metadataImport_negativePrompt => '负向提示词';

  @override
  String get metadataImport_characterPrompts => '多角色提示词';

  @override
  String get metadataImport_seed => '种子 (Seed)';

  @override
  String get metadataImport_steps => '步数 (Steps)';

  @override
  String get metadataImport_scale => 'CFG Scale';

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
  String get metadataImport_cfgRescale => 'CFG Rescale';

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
  String metadataImport_extractFailed(String error) {
    return '提取元数据失败: $error';
  }

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
  String get shortcut_help_customize => '自定义快捷键';

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
  String get vibeLibrary_title => 'Vibe 库';

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
  String get drop_reuse_vibe => '复用 Vibe';

  @override
  String drop_save_anlas(int cost) {
    return '节省 $cost Anlas';
  }

  @override
  String get vibe_export_include_thumbnails => '包含缩略图';

  @override
  String get vibe_export_include_thumbnails_subtitle => '导出文件中包含缩略图预览';

  @override
  String get vibe_import_skip => '跳过';

  @override
  String get vibe_import_confirm => '确认';

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
  String get shortcut_action_vibe_detail_send_to_generation => '发送到生成';

  @override
  String get shortcut_action_vibe_detail_export => '导出';

  @override
  String get shortcut_action_vibe_detail_rename => '重命名';

  @override
  String get shortcut_action_vibe_detail_delete => '删除';

  @override
  String get shortcut_action_vibe_detail_toggle_favorite => '切换收藏';

  @override
  String get shortcut_action_vibe_detail_prev_sub_vibe => '上一个子 Vibe';

  @override
  String get shortcut_action_vibe_detail_next_sub_vibe => '下一个子 Vibe';

  @override
  String get shortcut_action_navigate_to_vibe_library => 'Vibe 库';

  @override
  String get shortcut_action_vibe_import => '导入 Vibe';

  @override
  String get shortcut_action_vibe_export => '导出 Vibe';

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
  String settings_retryCountDisplay(int count) {
    return '最多 $count 次';
  }

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
  String get settings_changePathConfirm => '更改数据存储路径后，需要重启应用才能生效。\n\n新路径将在下次启动时生效。是否继续？';

  @override
  String get settings_resetPathConfirm => '重置数据存储路径后，需要重启应用才能生效。\n\n默认路径将在下次启动时生效。是否继续？';
}

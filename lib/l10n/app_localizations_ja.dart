// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Japanese (`ja`).
class AppLocalizationsJa extends AppLocalizations {
  AppLocalizationsJa([String locale = 'ja']) : super(locale);

  @override
  String get app_title => 'NAI Launcher';

  @override
  String get app_subtitle => 'NovelAI サードパーティ クライアント';

  @override
  String get common_cancel => 'キャンセル';

  @override
  String get common_confirm => '確認';

  @override
  String get common_continue => '続行';

  @override
  String get common_selectAll => 'すべて選択';

  @override
  String get common_deselectAll => 'すべての選択を解除';

  @override
  String get common_expandAll => 'すべて展開';

  @override
  String get common_collapseAll => 'すべて折りたたむ';

  @override
  String get common_save => '保存';

  @override
  String get common_saved => '保存しました';

  @override
  String get common_delete => '削除';

  @override
  String get common_edit => '編集';

  @override
  String get common_close => '閉じる';

  @override
  String get common_back => '戻る';

  @override
  String get common_clear => 'クリア';

  @override
  String get common_copy => 'コピー';

  @override
  String get common_copied => 'コピーしました';

  @override
  String get common_export => 'エクスポート';

  @override
  String get common_import => 'インポート';

  @override
  String get common_loading => '読み込み中...';

  @override
  String get common_error => 'エラー';

  @override
  String get common_success => '成功';

  @override
  String get common_retry => '再試行';

  @override
  String get common_more => 'その他';

  @override
  String get common_select => '選択してください';

  @override
  String get common_reset => 'リセット';

  @override
  String get common_search => '検索';

  @override
  String get common_featureInDev => '開発中の機能...';

  @override
  String get common_add => '追加';

  @override
  String get common_added => '追加しました';

  @override
  String get common_new => '新規';

  @override
  String get common_confirmDelete => '削除の確認';

  @override
  String get common_confirmClear => 'クリアの確認';

  @override
  String get common_gotIt => 'わかりました';

  @override
  String common_deleteItemConfirm(Object itemName) {
    return '「$itemName」を削除しますか?この操作は元に戻すことができません。';
  }

  @override
  String common_clearAllItemsConfirm(Object count, Object itemType) {
    return '$count $itemType をすべてクリアしますか?この操作は元に戻すことができません。';
  }

  @override
  String get common_clearInputConfirm => '入力内容をクリアしますか?';

  @override
  String get common_settings => '設定';

  @override
  String get common_today => '今日';

  @override
  String get common_yesterday => '昨日';

  @override
  String common_daysAgo(Object days) {
    return '$days 日前';
  }

  @override
  String get common_undo => '元に戻す';

  @override
  String get common_redo => 'やり直し';

  @override
  String get common_refresh => '更新';

  @override
  String get common_download => 'ダウンロード';

  @override
  String get common_upload => 'アップロード';

  @override
  String get common_apply => '適用する';

  @override
  String get common_preview => 'プレビュー';

  @override
  String get common_done => '完了';

  @override
  String get common_view => '表示';

  @override
  String get common_info => '情報';

  @override
  String get common_warning => '警告';

  @override
  String get common_show => '表示';

  @override
  String get common_hide => '非表示';

  @override
  String get common_move => '移動';

  @override
  String get common_duplicate => '複製';

  @override
  String get common_favorite => 'お気に入り';

  @override
  String get common_unfavorite => 'お気に入りから削除';

  @override
  String get common_share => 'シェア';

  @override
  String get common_open => '開く';

  @override
  String get common_ok => 'OK';

  @override
  String get common_submit => '送信';

  @override
  String get common_discard => '破棄';

  @override
  String get common_keep => '保持する';

  @override
  String get common_replace => '置換';

  @override
  String get common_skip => 'スキップ';

  @override
  String get common_yes => 'はい';

  @override
  String get common_no => 'いいえ';

  @override
  String get common_exit => '終了';

  @override
  String get common_folder => 'フォルダー';

  @override
  String get common_filter => 'フィルター';

  @override
  String get common_grid => 'グリッド';

  @override
  String get common_date => '日付';

  @override
  String get common_pack => 'パック';

  @override
  String get common_multiSelect => '複数選択';

  @override
  String get common_category => 'カテゴリ';

  @override
  String get common_categories => 'カテゴリ';

  @override
  String get common_items => 'アイテム';

  @override
  String get nav_canvas => 'キャンバス';

  @override
  String get nav_gallery => 'ギャラリー';

  @override
  String get nav_onlineGallery => 'オンライン ギャラリー';

  @override
  String get nav_randomConfig => 'ランダム構成';

  @override
  String get nav_dictionary => '辞書 (WIP)';

  @override
  String get nav_settings => '設定';

  @override
  String get nav_discordCommunity => 'Discord コミュニティ';

  @override
  String get nav_githubRepo => 'GitHub リポジトリ';

  @override
  String get auth_login => 'ログイン';

  @override
  String get auth_logout => 'ログアウト';

  @override
  String get auth_email => '電子メール';

  @override
  String get auth_emailHint => 'NovelAI アカウントのメールアドレスを入力してください';

  @override
  String get auth_password => 'パスワード';

  @override
  String get auth_passwordHint => 'パスワードを入力してください';

  @override
  String get auth_loginButton => 'サインイン';

  @override
  String get auth_loginFailed => 'ログインに失敗しました';

  @override
  String get auth_rememberPassword => 'パスワードを記憶';

  @override
  String get auth_loginTip =>
      'NovelAI アカウントでサインインしてください\nすべてのデータはローカルにのみ保存されます';

  @override
  String get auth_checkingStatus => 'ログインステータスを確認しています';

  @override
  String get auth_loggedIn => 'ログインしました';

  @override
  String get auth_tokenConfigured => 'トークンが構成されました';

  @override
  String get auth_notLoggedIn => 'ログインしていません';

  @override
  String get auth_pleaseLogin => 'すべての機能を使用するにはログインしてください';

  @override
  String get auth_logoutConfirmTitle => 'ログアウト';

  @override
  String get auth_logoutConfirmContent => 'ログアウトしてもよろしいですか?';

  @override
  String get auth_emailRequired => 'メールアドレスを入力してください';

  @override
  String get auth_emailInvalid => '有効な電子メール アドレスを入力してください';

  @override
  String get auth_passwordRequired => 'パスワードを入力してください';

  @override
  String get auth_tokenLogin => 'API トークンのログイン';

  @override
  String get auth_tokenLoginRecommended => 'API トークンのログイン（推奨）';

  @override
  String get auth_credentialsLogin => '電子メールとパスワード';

  @override
  String get auth_credentialsLoginUnavailable =>
      'メールアドレス/パスワードでのログインは現在利用できません。Token ログインを使用してください。';

  @override
  String get auth_credentialsLoginTitle => '電子メールでログイン';

  @override
  String get auth_tokenHint => '永続 API トークンを入力してください';

  @override
  String get auth_tokenRequired => 'トークンを入力してください';

  @override
  String get auth_tokenInvalid => '無効なトークン形式です。pst- で始まる必要があります。';

  @override
  String get auth_nicknameOptional => 'ニックネーム (オプション)';

  @override
  String get auth_nicknameHint => 'このアカウントに認識可能な名前を設定します';

  @override
  String get auth_thirdPartyLogin => 'サードパーティサイト';

  @override
  String get auth_thirdPartyApiSite => 'サードパーティ API サイト';

  @override
  String get auth_imageApiSiteOptional => '画像 API サイト (オプション)';

  @override
  String get auth_imageApiSiteHint => '同じサードパーティ API サイトを使用する場合は空のままにしてください';

  @override
  String get auth_thirdPartyNicknameHint => '例: 自己ホスト型サイト / ミラー サイト';

  @override
  String get auth_thirdPartyTokenHint => 'サードパーティ サイトから API トークンを入力してください';

  @override
  String get auth_thirdPartyCompatibilityHint =>
      'サードパーティ サイトは、NovelAI サブスクリプション API およびイメージ生成 API と互換性がある必要があります。トークンはベアラー トークンとして送信されます。';

  @override
  String get auth_thirdPartyApiSiteRequired => 'サードパーティ API サイトの URL を入力してください';

  @override
  String get auth_saveAccount => 'このアカウントを保存します';

  @override
  String get auth_validateAndLogin => '検証してログイン';

  @override
  String get auth_tokenGuide => 'NovelAI 設定からトークンを取得します';

  @override
  String get auth_savedAccounts => '保存されたアカウント';

  @override
  String get auth_addAccount => 'アカウントを追加';

  @override
  String get auth_manageAccounts => '管理';

  @override
  String auth_moreAccounts(Object count) {
    return 'ほか $count 件のアカウント';
  }

  @override
  String get auth_orAddNewAccount => 'または新しいアカウントを追加してください';

  @override
  String get auth_tokenNotFound => 'このアカウントのトークンが見つかりません';

  @override
  String get auth_switchAccount => 'アカウントを切り替える';

  @override
  String get auth_currentAccount => '現在のアカウント';

  @override
  String get auth_selectAccount => 'アカウントを選択してください';

  @override
  String get auth_deleteAccount => 'アカウントを削除';

  @override
  String auth_deleteAccountConfirm(Object name) {
    return '「$name」を削除してもよろしいですか?これを元に戻すことはできません。';
  }

  @override
  String get auth_cannotDeleteCurrent => '現在ログインしているアカウントは削除できません';

  @override
  String get auth_changeAvatar => 'アバターの変更';

  @override
  String get auth_removeAvatar => 'アバターを削除';

  @override
  String get auth_selectFromGallery => 'ギャラリーから選択';

  @override
  String get auth_takePhoto => '写真を撮る';

  @override
  String get auth_quickLogin => 'クイックログイン';

  @override
  String get auth_nicknameRequired => 'ニックネームを入力してください';

  @override
  String auth_createdAt(Object date) {
    return '作成日時: $date';
  }

  @override
  String auth_error_loginFailed(Object error) {
    return 'ログインに失敗しました: $error';
  }

  @override
  String get auth_error_networkTimeout => '接続タイムアウト';

  @override
  String get auth_error_networkError => 'ネットワークエラー';

  @override
  String get auth_error_authFailed => '認証に失敗しました';

  @override
  String get auth_error_authFailed_tokenExpired =>
      'トークンの有効期限が切れました。もう一度ログインしてください。';

  @override
  String get auth_error_credentialsLoginUnavailable =>
      'メールアドレス/パスワードでのログインは現在利用できません';

  @override
  String get auth_error_credentialsLoginUnavailable_hint =>
      'NovelAI ではメールアドレス/パスワードログインに Web の安全確認が必要になりました。代わりに Persistent API Token を使用してください。';

  @override
  String get auth_error_serverError => 'サーバーエラー';

  @override
  String get auth_error_unknown => '不明なエラー';

  @override
  String get auth_autoLogin => '自動ログイン';

  @override
  String get auth_forgotPassword => 'パスワードをお忘れですか?';

  @override
  String get auth_passwordTooShort => 'パスワードは 6 文字以上である必要があります';

  @override
  String get auth_loggingIn => 'ログイン中...';

  @override
  String get auth_pleaseWait => 'お待ちください';

  @override
  String get auth_viewTroubleshootingTips => 'トラブルシューティングのヒントを表示';

  @override
  String get auth_troubleshoot_checkConnection_title => 'ネットワーク接続を確認してください';

  @override
  String get auth_troubleshoot_checkConnection_desc =>
      'デバイスがインターネットに接続されていることを確認してください';

  @override
  String get auth_troubleshoot_retry_title => 'もう一度試してください';

  @override
  String get auth_troubleshoot_retry_desc =>
      'ネットワークの問題は一時的なものである可能性があります。再試行してください。';

  @override
  String get auth_troubleshoot_proxy_title => 'プロキシ設定を確認してください';

  @override
  String get auth_troubleshoot_proxy_desc =>
      'プロキシを使用している場合は、正しく構成されていることを確認してください';

  @override
  String get auth_troubleshoot_firewall_title => 'ファイアウォール設定を確認してください';

  @override
  String get auth_troubleshoot_firewall_desc =>
      'ファイアウォールで NovelAI サーバーへの接続が許可されていることを確認してください';

  @override
  String get auth_troubleshoot_serverStatus_title => 'サーバーのステータスを確認してください';

  @override
  String get auth_troubleshoot_serverStatus_desc =>
      'NovelAI ステータス ページまたはコミュニティにアクセスして、停止を確認してください';

  @override
  String get auth_passwordResetHelp_title => 'パスワードのリセット';

  @override
  String get auth_passwordResetHelp_desc =>
      '[パスワードをお忘れですか?] をクリックします。ブラウザで NovelAI のパスワード リセット ページが開き、パスワードをリセットできます。';

  @override
  String get auth_passwordResetAfterReset_title => 'パスワードのリセット後';

  @override
  String get auth_passwordResetAfterReset_desc =>
      'NovelAI ウェブサイトでパスワードをリセットした後、このアプリに戻り、新しいパスワードでログインしてください';

  @override
  String get auth_passwordResetNoEmail_title => 'リセットメールを受信しませんでしたか?';

  @override
  String get auth_passwordResetNoEmail_desc =>
      'スパム フォルダを確認するか、数分以内にパスワード リセット メールが届かない場合は NovelAI サポートにお問い合わせください。';

  @override
  String get common_paste => '貼り付け';

  @override
  String get common_default => 'デフォルト';

  @override
  String get settings_title => '設定';

  @override
  String get settings_account => 'アカウント';

  @override
  String get settings_appearance => '外観';

  @override
  String get settings_style => 'スタイル';

  @override
  String get settings_font => 'フォント';

  @override
  String get settings_language => '言語';

  @override
  String get settings_languageChinese => '中文';

  @override
  String get settings_languageEnglish => 'English';

  @override
  String get settings_languageJapanese => '日本語';

  @override
  String get settings_shortcuts => 'ショートカット';

  @override
  String get settings_generation => '生成';

  @override
  String get settings_dataStorage => 'データとストレージ';

  @override
  String get settings_privacySharing => '保護と共有';

  @override
  String get settings_integrations => '連携';

  @override
  String get settings_generationInputSection => '入力';

  @override
  String get settings_generationRetrySection => '失敗時リトライ';

  @override
  String get settings_generationFeedbackSection => '完了通知';

  @override
  String get settings_promptAssistant => 'プロンプトアシスタント';

  @override
  String get settings_selectStyle => 'スタイルの選択';

  @override
  String get settings_defaultPreset => 'デフォルト';

  @override
  String get settings_selectFont => 'フォントの選択';

  @override
  String get settings_selectLanguage => '言語の選択';

  @override
  String settings_loadFailed(Object error) {
    return 'ロードに失敗しました: $error';
  }

  @override
  String get settings_storage => 'ストレージ';

  @override
  String get settings_imageSavePath => '画像の保存場所';

  @override
  String get settings_default => 'デフォルト';

  @override
  String get settings_autoSave => '自動保存';

  @override
  String get settings_autoSaveSubtitle => '生成後に画像を自動的に保存します';

  @override
  String get settings_about => '概要';

  @override
  String settings_version(Object version) {
    return 'バージョン $version';
  }

  @override
  String get settings_openSource => 'オープンソース';

  @override
  String get settings_openSourceSubtitle => 'ソース コードとドキュメントを表示する';

  @override
  String get settings_fileLogging => 'アプリケーション ログを記録する';

  @override
  String get settings_fileLoggingSubtitle =>
      'デフォルトではオフ。トラブルシューティングの場合にのみ有効にします。有効にすると、ログはDocuments/NAI_Launcher/logsに書き込まれます。無効にすると、ログ ファイルは作成または書き込まれなくなります。';

  @override
  String get settings_pathReset => 'デフォルトの場所にリセット';

  @override
  String get settings_pathSaved => '保存場所が更新されました';

  @override
  String get settings_selectFolder => '保存フォルダーを選択してください';

  @override
  String get settings_vibeLibraryPath => 'バイブライブラリパス';

  @override
  String get settings_hiveStoragePath => 'データ ストレージ パス';

  @override
  String get settings_selectVibeLibraryFolder => 'バイブライブラリフォルダーを選択してください';

  @override
  String get settings_selectHiveFolder => 'データ保存フォルダーの選択';

  @override
  String get settings_restartRequired => '再起動が必要です';

  @override
  String get settings_restartRequiredContent =>
      '新しいストレージ パスを適用するには、アプリを再起動する必要があります。アプリを手動で再起動してください。';

  @override
  String get settings_pathSavedRestartRequired =>
      'パスが更新されました。変更を適用するには再起動してください';

  @override
  String get settings_accountProfile => 'アカウント プロファイル';

  @override
  String get settings_accountType => 'アカウントの種類';

  @override
  String get settings_thirdPartyApiAccount => 'サードパーティのサイト API';

  @override
  String get settings_apiSite => 'API サイト';

  @override
  String get settings_notLoggedIn => 'ログインしてアバターとニックネームを設定してください';

  @override
  String get settings_goToLogin => 'ログインに移動';

  @override
  String get settings_tapToChangeAvatar => 'タップしてアバターを変更します';

  @override
  String get settings_changeAvatar => 'アバターの変更';

  @override
  String get settings_removeAvatar => 'アバターを削除';

  @override
  String get settings_nickname => 'ニックネーム';

  @override
  String get settings_accountEmail => 'アカウントのメールアドレス';

  @override
  String get settings_emailAccount => '電子メール アカウント';

  @override
  String get settings_tokenAccount => 'トークンアカウント';

  @override
  String get settings_setAsDefault => 'デフォルトとして設定';

  @override
  String get settings_defaultAccount => 'デフォルト';

  @override
  String get settings_editNickname => 'ニックネームの編集';

  @override
  String get settings_nicknameHint => '2 ～ 32 文字を入力してください';

  @override
  String get settings_nicknameEmpty => 'ニックネームを入力してください';

  @override
  String settings_nicknameTooShort(int minLength) {
    return 'ニックネームは少なくとも $minLength 文字である必要があります';
  }

  @override
  String settings_nicknameTooLong(int maxLength) {
    return 'ニックネームは $maxLength 文字を超えることはできません';
  }

  @override
  String get settings_nicknameAllWhitespace => 'ニックネームをすべて空白にすることはできません';

  @override
  String get settings_nicknameUpdated => 'ニックネームが更新されました';

  @override
  String get settings_avatarUpdated => 'アバターが更新されました';

  @override
  String get settings_avatarRemoved => 'アバターが削除されました';

  @override
  String get settings_avatarFileMissing => 'アバター ファイルが見つかりません。もう一度選択しますか?';

  @override
  String get settings_setAsDefaultSuccess => 'デフォルトのアカウントとして設定';

  @override
  String get settings_startupPerformance => '起動パフォーマンス';

  @override
  String get settings_startupPerformanceSubtitle => '起動時のパフォーマンス設定を構成する';

  @override
  String get generation_title => '生成';

  @override
  String get generation_generate => '生成';

  @override
  String get generation_cancel => 'キャンセル';

  @override
  String get generation_generating => '生成中...';

  @override
  String get generation_cancelGeneration => '生成のキャンセル';

  @override
  String get generation_skipCurrentBatch => '現在のバッチをスキップ';

  @override
  String get generation_stopAllGeneration => 'すべて停止';

  @override
  String get generation_generateImage => '画像の生成';

  @override
  String get generation_pleaseInputPrompt => 'プロンプトを入力してください';

  @override
  String get generation_emptyPromptHint => 'プロンプトを入力し、「生成」をクリックします';

  @override
  String get generation_imageWillShowHere => 'ここに画像が表示されます';

  @override
  String get generation_generationFailed => '生成に失敗しました';

  @override
  String generation_progress(Object progress) {
    return '生成中...$progress%';
  }

  @override
  String get generation_params => 'パラメータ';

  @override
  String get generation_paramsSettings => 'パラメータ設定';

  @override
  String get generation_history => '履歴';

  @override
  String get generation_historyRecord => '履歴レコード';

  @override
  String get generation_failedStreamSnapshot => 'スナップショットが失敗しました';

  @override
  String get generation_failedStreamSnapshotHint =>
      '生成が完了しませんでした。最後のプレビュー フレームのみが保持されます。保存したり、お気に入りに登録したり、画像ワークフローに使用したりすることはできません。';

  @override
  String get generation_noHistory => '履歴レコードがありません';

  @override
  String get generation_clearHistory => '履歴をクリア';

  @override
  String get generation_clearHistoryConfirm =>
      'すべての履歴レコードをクリアしてもよろしいですか?この操作は元に戻すことができません。';

  @override
  String get generation_model => 'モデル';

  @override
  String get generation_imageSize => '画像サイズ';

  @override
  String get generation_sampler => 'サンプラー';

  @override
  String generation_steps(Object steps) {
    return 'ステップ: $steps';
  }

  @override
  String generation_cfgScale(Object scale) {
    return 'CFG スケール: $scale';
  }

  @override
  String get generation_seed => 'シード';

  @override
  String get generation_seedRandom => 'ランダム';

  @override
  String get generation_seedLock => 'ロックシード';

  @override
  String get generation_seedUnlock => 'シードのロックを解除する';

  @override
  String get generation_advancedOptions => '詳細オプション';

  @override
  String get generation_smea => 'SMEA';

  @override
  String get generation_smeaSubtitle => '大きな画像の生成品質を向上させます';

  @override
  String get generation_smeaDyn => 'SMEA DYN';

  @override
  String get generation_smeaDynSubtitle => 'SMEA 動的バリアント';

  @override
  String get generation_smeaDescription =>
      '特定の画像サイズを超えると、高解像度サンプラーが自動的に使用されます。';

  @override
  String generation_cfgRescale(Object value) {
    return 'CFG リスケール: $value';
  }

  @override
  String get generation_noiseSchedule => 'ノイズスケジュール';

  @override
  String get generation_resetParams => 'パラメータのリセット';

  @override
  String generation_sizePortrait(Object width, Object height) {
    return 'ポートレート ($width×$height)';
  }

  @override
  String generation_sizeLandscape(Object width, Object height) {
    return '横長 ($width×$height)';
  }

  @override
  String generation_sizeSquare(Object width, Object height) {
    return '正方形 ($width×$height)';
  }

  @override
  String generation_sizeSmallSquare(Object width, Object height) {
    return '小さな正方形 ($width×$height)';
  }

  @override
  String generation_sizeLargeSquare(Object width, Object height) {
    return '大きな正方形 ($width×$height)';
  }

  @override
  String generation_sizeTallPortrait(Object width, Object height) {
    return '縦長ポートレート ($width×$height)';
  }

  @override
  String generation_sizeWideLandscape(Object width, Object height) {
    return 'ワイド横長 ($width×$height)';
  }

  @override
  String get prompt_positive => 'プロンプト';

  @override
  String get prompt_negative => '除外したい要素';

  @override
  String get prompt_positivePrompt => 'プロンプト';

  @override
  String get prompt_negativePrompt => '除外したい要素';

  @override
  String get prompt_mainPositive => 'メイン プロンプト (正)';

  @override
  String get prompt_mainNegative => 'メインプロンプト (除外したい要素)';

  @override
  String get prompt_characterPrompts => '複数キャラクターのプロンプト';

  @override
  String prompt_characterPromptItem(Object name, Object content) {
    return '$name: $content';
  }

  @override
  String get prompt_finalPrompt => '最終的な有効なプロンプト';

  @override
  String get prompt_finalNegative => '最終有効な除外したい要素';

  @override
  String prompt_tags(Object count) {
    return '$count タグ';
  }

  @override
  String prompt_importedCharacters(int count) {
    return '$count キャラクターをインポートしました';
  }

  @override
  String get prompt_characterPromptReplaced => 'キャラクタープロンプトを置き換えました';

  @override
  String prompt_characterPromptAppended(Object count) {
    return 'キャラクタープロンプトを追加しました ($count キャラクター)';
  }

  @override
  String prompt_smartDecomposedWithCharacters(Object count) {
    return 'メインプロンプト + $count キャラクターに分解';
  }

  @override
  String get prompt_appliedToMainPrompt => 'メイン プロンプトに適用されます';

  @override
  String get prompt_editPrompt => 'プロンプトの編集';

  @override
  String get prompt_inputPrompt => 'プロンプトを入力してください...';

  @override
  String get prompt_inputNegativePrompt => '除外したい要素を入力してください...';

  @override
  String get prompt_describeImage => '生成したい画像を説明してください...';

  @override
  String get prompt_describeImageWithHint =>
      '画像を説明するプロンプトを入力し、< と入力してライブラリを参照し、タグのオートコンプリートをサポートします';

  @override
  String get prompt_searchHint => '検索プロンプト';

  @override
  String prompt_searchMatchCount(Object current, Object total) {
    return '$current / $total';
  }

  @override
  String get prompt_searchPrevious => '前の一致';

  @override
  String get prompt_searchNext => '次の一致';

  @override
  String get prompt_searchClose => '検索を閉じる';

  @override
  String get promptAssistant_needPrompt => 'アシスタントを使用する前にプロンプトを入力してください';

  @override
  String promptAssistant_requestFailed(Object error) {
    return 'アシスタントのリクエストが失敗しました: $error';
  }

  @override
  String get promptAssistant_enableAssistant => 'Prompt Assistant を有効にする';

  @override
  String get promptAssistant_desktopOverlay => 'デスクトップ右下のオーバーレイ';

  @override
  String get kritaBridge_busyGenerating =>
      'Krita Bridge で生成中です。現在のタスクが完了するまで待ってください。';

  @override
  String get prompt_negativeFixedTagPrefix => '除外したい要素固定タグプレフィックス';

  @override
  String get prompt_negativeFixedTagSuffix => '除外したい要素固定タグサフィックス';

  @override
  String get prompt_unwantedContent => '画像に含めたくないコンテンツ...';

  @override
  String get prompt_addTagsHint => '希望の画像を説明するタグを追加します';

  @override
  String get prompt_addUnwantedHint => '除外したい要素を追加します';

  @override
  String get prompt_fullscreenEdit => 'フルスクリーン編集';

  @override
  String get prompt_randomPrompt => 'ランダムプロンプト (長押しして設定)';

  @override
  String prompt_clearConfirm(Object type) {
    return '$type のクリアを確認します';
  }

  @override
  String get prompt_promptSettings => 'プロンプト設定';

  @override
  String get prompt_smartAutocomplete => 'スマート オートコンプリート';

  @override
  String get prompt_smartAutocompleteSubtitle => '入力中にタグの候補を表示します';

  @override
  String get prompt_autoFormat => '自動フォーマット';

  @override
  String get prompt_autoFormatSubtitle => '中国語カンマを英語カンマに変換し、アンダースコアを自動追加します';

  @override
  String get prompt_highlightEmphasis => 'ハイライトの強調';

  @override
  String get prompt_highlightEmphasisSubtitle => '括弧と重みの構文を強調表示します';

  @override
  String get prompt_sdSyntaxAutoConvert => 'SD 構文自動変換';

  @override
  String get prompt_sdSyntaxAutoConvertSubtitle =>
      'フォーカスが外れたときに SD ウェイト構文を NAI 形式に変換します';

  @override
  String get prompt_cooccurrenceRecommendation => '共起タグの推奨事項';

  @override
  String get prompt_cooccurrenceRecommendationSubtitle =>
      'タグを入力すると、関連するタグが自動的に推奨されます';

  @override
  String get prompt_formatted => 'フォーマット済み';

  @override
  String get image_save => '保存';

  @override
  String get image_copy => 'コピー';

  @override
  String get image_upscale => '拡大';

  @override
  String get image_saveToLibrary => 'ライブラリに保存';

  @override
  String image_imageSaved(Object path) {
    return '画像は次の場所に保存されました: $path';
  }

  @override
  String image_saveFailed(Object error) {
    return '保存に失敗しました: $error';
  }

  @override
  String get image_copiedToClipboard => 'クリップボードにコピーされました';

  @override
  String image_copyFailed(Object error) {
    return 'コピーに失敗しました: $error';
  }

  @override
  String get gallery_title => 'ギャラリー';

  @override
  String gallery_selected(Object count) {
    return '選択された $count アイテム';
  }

  @override
  String get gallery_clearAll => 'すべてクリア';

  @override
  String get gallery_clearGallery => 'ギャラリーをクリア';

  @override
  String get gallery_favorite => 'お気に入り';

  @override
  String get gallery_sortNewest => '新しい順';

  @override
  String get gallery_sortOldest => '古い順';

  @override
  String get gallery_sortFavorite => '最初にお気に入り';

  @override
  String gallery_selectedCount(Object count) {
    return '選択した $count 画像';
  }

  @override
  String get config_title => 'ランダムプロンプト構成';

  @override
  String get config_presets => 'プリセット';

  @override
  String get config_configGroups => '構成グループ';

  @override
  String get config_presetName => 'プリセット名';

  @override
  String get config_noPresets => 'プリセットはありません';

  @override
  String get config_restoreDefaults => 'デフォルトに戻す';

  @override
  String get config_newPreset => '新しいプリセット';

  @override
  String get config_selectPreset => 'プリセットを選択してください';

  @override
  String get config_noConfigGroups => '構成グループがまだありません';

  @override
  String get config_addConfigGroup => '構成グループの追加';

  @override
  String get config_saveChanges => '変更を保存';

  @override
  String config_configGroupCount(Object count) {
    return '$count 構成グループ';
  }

  @override
  String get config_setAsCurrent => '現在として設定';

  @override
  String get config_duplicate => '重複';

  @override
  String get config_importConfig => '構成のインポート';

  @override
  String get config_selectConfigToEdit => '編集する構成グループを選択してください';

  @override
  String get config_editConfigGroup => '構成グループの編集';

  @override
  String get config_configName => '構成名';

  @override
  String get config_selectionMode => '選択モード';

  @override
  String get config_singleRandom => 'ランダムシングル';

  @override
  String get config_singleSequential => 'シーケンシャルシングル';

  @override
  String get config_multipleCount => '指定された数';

  @override
  String get config_multipleProbability => '確率による';

  @override
  String get config_all => 'すべて';

  @override
  String get config_selectCount => '数の選択';

  @override
  String get config_selectProbability => '確率の選択';

  @override
  String get config_shuffleOrder => 'シャッフル順序';

  @override
  String get config_shuffleOrderSubtitle => '選択したコンテンツをランダムに配置します';

  @override
  String get config_weightBrackets => 'ウェイト ブラケット';

  @override
  String get config_weightBracketsHint => '中括弧のペアごとに重みが最大 5% 増加します';

  @override
  String get config_min => '分';

  @override
  String get config_max => '最大';

  @override
  String config_preview(Object preview) {
    return 'プレビュー: $preview';
  }

  @override
  String get config_tagContent => 'タグの内容';

  @override
  String config_tagContentHint(Object count) {
    return '1 行に 1 つのタグ、現在 $count 個のアイテム';
  }

  @override
  String get config_format => '形式';

  @override
  String get config_sort => '並べ替え';

  @override
  String get config_inputTags =>
      'タグを 1 行に 1 つずつ入力してください...\nたとえば:\n1女の子\n美しい目\n長い髪';

  @override
  String get config_unsavedChanges => '未保存の変更';

  @override
  String get config_unsavedChangesContent => '未保存の変更があります。本当に破棄してもよろしいですか?';

  @override
  String get config_discard => '破棄';

  @override
  String get config_deletePreset => 'プリセットを削除';

  @override
  String config_deletePresetConfirm(Object name) {
    return '「$name」を削除してもよろしいですか?';
  }

  @override
  String get config_pasteJsonConfig => 'JSON 構成を貼り付けます...';

  @override
  String get config_importSuccess => 'インポートが成功しました';

  @override
  String config_importFailed(Object error) {
    return 'インポートに失敗しました: $error';
  }

  @override
  String get config_restoreDefaultsConfirm =>
      'デフォルトのプリセットを復元してもよろしいですか?すべてのカスタム構成が削除されます。';

  @override
  String get config_restored => 'デフォルトに復元されました';

  @override
  String get config_copiedToClipboard => 'クリップボードにコピーされました';

  @override
  String get config_setAsCurrentSuccess => '現在のプリセットとして設定';

  @override
  String get config_duplicatedPreset => 'プリセットが複製されました';

  @override
  String get config_deletedSuccess => '削除されました';

  @override
  String get config_saveSuccess => '正常に保存されました';

  @override
  String get config_newPresetCreated => '新しいプリセットが作成されました';

  @override
  String config_itemCount(Object count) {
    return '$count アイテム';
  }

  @override
  String config_subConfigCount(Object count) {
    return '$count サブ構成';
  }

  @override
  String get config_random => 'ランダム';

  @override
  String get config_sequential => 'シーケンシャル';

  @override
  String get config_multiple => '複数';

  @override
  String get config_probability => '確率';

  @override
  String get config_moreActions => 'その他のアクション';

  @override
  String get img2img_title => 'Image2Image';

  @override
  String get img2img_enabled => '有効';

  @override
  String get img2img_sourceImage => 'ソース画像';

  @override
  String get img2img_selectImage => '画像を選択してください';

  @override
  String get img2img_clickToSelectImage => 'クリックして画像を選択してください';

  @override
  String get img2img_strength => '強度';

  @override
  String get img2img_strengthHint => '値が高いほど、元画像との差が大きくなります';

  @override
  String get img2img_noise => 'ノイズ';

  @override
  String get img2img_noiseHint => 'ノイズを追加してバリエーションを増やします';

  @override
  String get img2img_clearSettings => 'Image2Image 設定をクリア';

  @override
  String get img2img_changeImage => '画像の変更';

  @override
  String get img2img_removeImage => '画像を削除';

  @override
  String img2img_selectFailed(Object error) {
    return '画像の選択に失敗しました: $error';
  }

  @override
  String get img2img_edit => '編集';

  @override
  String get img2img_editImage => '画像を編集';

  @override
  String get img2img_editApplied => '編集された画像が新しいソース画像になりました';

  @override
  String get img2img_maskEnabled => 'インペイントマスク';

  @override
  String get img2img_uploadImage => '画像をアップロード';

  @override
  String get img2img_drawSketch => 'スケッチを描く';

  @override
  String get img2img_maskTooltip => '白 = 変更、黒 = 保持';

  @override
  String get img2img_maskHelpText =>
      'マスクでは、白い領域は生成中に変更されますが、黒い領域はソース イメージから保持されます。';

  @override
  String get img2img_inpaint => 'インペイント';

  @override
  String get img2img_inpaintStrength => 'インペイント強度';

  @override
  String get img2img_inpaintStrengthHint =>
      '値を高くすると、マスクされた領域が現在のソース イメージからさらに離れます。';

  @override
  String get img2img_inpaintPendingHint =>
      '「インペイント」をクリックしてキャンバスを開き、ブラシ、消しゴム、選択ツールで再描画したい領域を指定します。その後ここに戻り、メインの生成ボタンを使用します。';

  @override
  String get img2img_inpaintReadyHint =>
      'マスクを読み込みました。次回の生成では、マスクされた領域のみを再描画します。';

  @override
  String get img2img_inpaintMaskReady => 'インペイントマスクの準備ができました';

  @override
  String get img2img_generateVariations => 'バリエーションの生成';

  @override
  String get img2img_variationsReady => '画像メタデータから作成したバリエーション設定';

  @override
  String get img2img_variationsPreparedHint =>
      'バリエーションの設定が完了しました。メインの生成ボタンを使用して、現在の画像から新しい結果を作成します。';

  @override
  String get img2img_variationsFallbackHint =>
      '再利用可能なメタデータが見つかりません。現在のプロンプトを維持し、基本バリエーションの設定に切り替えました';

  @override
  String get img2img_directorTools => 'ディレクターツール';

  @override
  String get img2img_directorToolsHint =>
      'ディレクターツールを通じて現在のソース イメージを送信します。結果の準備ができたら、それを新しいソース イメージとして再度適用できます。';

  @override
  String get img2img_directorPrompt => '追加のプロンプト';

  @override
  String get img2img_directorPromptHint => 'ターゲットの感情や色の方向など、必要に応じてガイダンスを追加します';

  @override
  String img2img_directorRun(Object tool) {
    return '$tool を実行します';
  }

  @override
  String get img2img_directorRunning => '処理中...';

  @override
  String get img2img_directorResult => '結果';

  @override
  String img2img_directorResultReady(Object tool) {
    return '$tool が完了しました';
  }

  @override
  String get img2img_directorApplied => 'ディレクターツールの結果を新しいソース イメージとして適用しました';

  @override
  String get img2img_directorDefry => 'デフライ';

  @override
  String get img2img_directorDefryHint => '結果のノイズまたは過飽和を低減します (0 = オフ、5 = 最大)';

  @override
  String get img2img_directorEmotionLevel => '感情レベル';

  @override
  String get img2img_directorEmotionLevelHint => '感情が適用される強さ (0 = 微妙、5 = 強い)';

  @override
  String get img2img_directorEmotionPresets => 'プリセット';

  @override
  String get img2img_directorApplyAsSource => 'ソースとして使用';

  @override
  String get img2img_directorSave => '保存';

  @override
  String get img2img_directorSourceImage => 'ソース画像';

  @override
  String get img2img_directorCompare => '比較';

  @override
  String get img2img_variationsStarted => 'バリエーションを生成しています...';

  @override
  String get img2img_directorRemoveBackground => '背景の除去';

  @override
  String get img2img_directorLineArt => '線画';

  @override
  String get img2img_directorSketch => 'スケッチ';

  @override
  String get img2img_directorColorize => 'カラー化';

  @override
  String get img2img_directorEmotion => '感情';

  @override
  String get img2img_directorDeclutter => 'デクラッター';

  @override
  String get img2img_enhance => '品質向上';

  @override
  String get img2img_enhanceHint =>
      '品質向上は、潜在スペースでソース画像を拡大して再生成する間、現在のプロンプトを使用し続けます。';

  @override
  String get img2img_enhanceMagnitude => '大きさ';

  @override
  String get img2img_enhanceShowIndividualSettings => '個別設定を表示';

  @override
  String get img2img_enhanceUpscaleAmount => '画像の拡大率';

  @override
  String get img2img_focusedInpaint => 'Focused インペイント';

  @override
  String get img2img_focusedInpaintEnabledHint =>
      '有効になりました。インペイント エディターの左上のコントロールからフォーカス エリアと最小コンテキスト エリアを調整します。';

  @override
  String get img2img_focusedInpaintDisabledHint =>
      '通常のインペイントがデフォルトです。Focused インペイントを使うには、インペイントエディター左上のコントロールから有効にし、フォーカスエリアを描画します。';

  @override
  String get img2img_disabled => '無効';

  @override
  String get img2img_novelAiCloudUpscale => 'NovelAI クラウド拡大 (4x 固定)';

  @override
  String get img2img_comfyuiEnableHint =>
      'まず、[設定] > [ComfyUI] で ComfyUI を有効にして接続します。';

  @override
  String get img2img_upscaleMode => '拡大モード';

  @override
  String get img2img_upscaleRegularModel => 'レギュラーモデル';

  @override
  String get img2img_upscaleModel => '拡大モデル';

  @override
  String get img2img_noSeedvr2Models =>
      'SeedVR2 モデルが見つかりません。モデル リストを更新するか、SeedVR2 ノード/モデル ファイルを確認してください。';

  @override
  String get img2img_noRegularUpscaleModels =>
      '通常の拡大モデルが見つかりません。モデルリストを更新するか、models/upscale_models を確認してください。';

  @override
  String get img2img_useSeedvr2TiledWorkflow =>
      'SeedVR2TilingUpscaler のタイル状の拡大ワークフローを使用します。';

  @override
  String get img2img_useSeedvr2Workflow => 'SeedVR2VideoUpscaler ワークフローの使用。';

  @override
  String get img2img_useRegularUpscaleWorkflow =>
      'UpscaleModelLoader + ImageUpscaleWithModel を使用し、Lanczos でターゲット スケールに修正します。';

  @override
  String get img2img_useRtxUpscaleWorkflow =>
      'RTX ビデオ超解像度を使用します。モデルの選択は必要ありません。';

  @override
  String get img2img_refreshModelList => 'モデルリストを更新';

  @override
  String get img2img_startUpscale => '拡大を開始';

  @override
  String get img2img_novelAiUpscaleComplete => 'NovelAI 拡大が完了しました';

  @override
  String img2img_upscaleComplete(Object width, Object height) {
    return '拡大が完了しました (${width}x$height)';
  }

  @override
  String img2img_regularUpscaleComplete(Object width, Object height) {
    return '通常モデルの拡大が完了しました (${width}x$height)';
  }

  @override
  String img2img_rtxUpscaleComplete(Object width, Object height) {
    return 'RTX 拡大が完了しました (${width}x$height)';
  }

  @override
  String get img2img_noAvailableSeedvr2Model => '利用可能な SeedVR2 モデルが選択されていません';

  @override
  String get img2img_noAvailableRegularUpscaleModel =>
      '利用可能な通常の拡大モデルが選択されていません';

  @override
  String get img2img_decodeSourceFailed => 'ソース画像のデコードに失敗しました';

  @override
  String get img2img_metricSpeed => '速度';

  @override
  String get img2img_metricVram => 'VRAM';

  @override
  String get img2img_metricQuality => '品質';

  @override
  String get img2img_seedvr2VaeTileHint =>
      'SeedVR2 VAE MODEL のエンコード/デコード タイル サイズも書き込みます。';

  @override
  String get img2img_seedvr2UseTiledUpscale => 'タイル状の拡大を使用する';

  @override
  String get img2img_seedvr2UseTiledUpscaleHint =>
      '有効にすると、SeedVR2TilingUpscaler が使用されます。大きな画像や VRAM 負荷が高い場合に推奨します。';

  @override
  String get img2img_seedvr2TileSize => 'タイルのサイズ';

  @override
  String get img2img_seedvr2TileSizeHint =>
      'SeedVR2TilingUpscaler tile_width / tile_height も制御します。';

  @override
  String img2img_regularModelDescription(Object name) {
    return '通常モデル · $name';
  }

  @override
  String get img2img_upscalePanelOpened => 'Image2Image の拡大パネルを開きました';

  @override
  String get editor_title => '画像エディター';

  @override
  String get editor_done => '完了';

  @override
  String get editor_tolerance => '許容差';

  @override
  String get editor_intensity => '強度';

  @override
  String get editor_sourcePoint => 'Alt+クリックしてソースポイントを設定します';

  @override
  String get editor_saveAndClose => '保存して閉じる';

  @override
  String get editor_closeWithoutSaving => '保存せずに閉じます';

  @override
  String get editor_close => '閉じる';

  @override
  String get editor_save => '保存';

  @override
  String get editor_modeImage => '画像';

  @override
  String get editor_modeMask => 'マスク';

  @override
  String get editor_toolSettings => 'ツール設定';

  @override
  String get editor_brushPresets => 'ブラシ プリセット';

  @override
  String get editor_color => 'カラー';

  @override
  String get editor_brushSettings => 'ブラシ設定';

  @override
  String get editor_actions => 'アクション';

  @override
  String get editor_size => 'サイズ';

  @override
  String get editor_opacity => '不透明度';

  @override
  String get editor_hardness => '硬度';

  @override
  String get editor_undo => '元に戻す';

  @override
  String get editor_redo => 'やり直し';

  @override
  String get editor_clearLayer => 'クリアレイヤー';

  @override
  String get editor_clearImageLayer => 'クリアペイント';

  @override
  String get editor_clearImageLayerMessage => 'これにより、すべてのペイント ストロークが削除されます。';

  @override
  String get editor_clearSelection => '選択をクリア';

  @override
  String get editor_clearSelectionMessage => 'これにより、現在の選択マスクが削除されます。';

  @override
  String get editor_resetView => 'ビューをリセット';

  @override
  String get editor_currentColor => '現在の色';

  @override
  String get editor_zoom => 'ズーム';

  @override
  String get editor_paintTools => 'ペイント';

  @override
  String get editor_selectionTools => '選択';

  @override
  String get editor_toolBrush => 'ブラシ';

  @override
  String get editor_toolEraser => '消しゴム';

  @override
  String get editor_toolFill => '塗りつぶし';

  @override
  String get editor_toolLine => '直線';

  @override
  String get editor_toolRectSelect => '長方形';

  @override
  String get editor_toolEllipseSelect => '楕円';

  @override
  String get editor_toolLassoSelect => 'なげなわ';

  @override
  String get editor_toolColorPicker => 'カラーピッカー';

  @override
  String get editor_toolCloneStamp => 'クローンスタンプ';

  @override
  String get editor_toolBlur => 'ぼかし';

  @override
  String get editor_presetDefault => 'デフォルト';

  @override
  String get editor_presetPencil => '鉛筆';

  @override
  String get editor_presetMarker => 'マーカー';

  @override
  String get editor_presetAirbrush => 'エアブラシ';

  @override
  String get editor_presetInkPen => 'インクペン';

  @override
  String get editor_presetPixel => 'ピクセル';

  @override
  String get editor_unsavedChanges => '未保存の変更';

  @override
  String get editor_unsavedChangesMessage => '未保存の変更があります。閉じてもよろしいですか?';

  @override
  String get editor_discard => '破棄';

  @override
  String get editor_cancel => 'キャンセル';

  @override
  String get editor_clearConfirm => 'クリアしますか？';

  @override
  String get editor_clearConfirmMessage => 'これにより、現在のレイヤーからすべてのコンテンツが削除されます。';

  @override
  String get editor_clear => 'クリア';

  @override
  String get editor_shortcutUndo => '元に戻す (Ctrl+Z)';

  @override
  String get editor_shortcutRedo => 'やり直し (Ctrl+Y)';

  @override
  String get editor_selectionSettings => '選択';

  @override
  String get editor_shortcuts => 'ショートカット';

  @override
  String get editor_addToSelection => '選択に追加';

  @override
  String get editor_subtractFromSelection => '選択範囲から減算';

  @override
  String get editor_selectionHint => 'インペイントマスク用の選択範囲を描画します';

  @override
  String get editor_back => '戻る';

  @override
  String get editor_layers => 'レイヤー';

  @override
  String get editor_loadMask => 'ロードマスク';

  @override
  String get editor_togglePanels => 'パネルの切り替え';

  @override
  String get editor_fillClosedRegion => '閉じた領域を埋める';

  @override
  String get editor_resetMask => 'マスクをリセット';

  @override
  String get editor_zoomIn => 'ズームイン';

  @override
  String get editor_zoomOut => 'ズームアウト';

  @override
  String get editor_fitToWindow => '窓に合わせる';

  @override
  String get editor_tempColorPickerShortcut => 'Alt+クリック: 一時的なカラーピッカー';

  @override
  String get editor_shortcutHelpTitle => 'ショートカット ヘルプ';

  @override
  String get editor_shortcutPaintTools => 'ペイント ツール';

  @override
  String get editor_shortcutSelectionTools => '選択ツール';

  @override
  String get editor_shortcutCanvasView => 'キャンバス ビュー';

  @override
  String get editor_shortcutBrushAdjust => 'ブラシの調整';

  @override
  String get editor_shortcutColors => 'カラー';

  @override
  String get editor_shortcutCanvasActions => 'キャンバスアクション';

  @override
  String get editor_shortcutHistoryActions => '履歴アクション';

  @override
  String get editor_shortcutSelectionActions => '選択アクション';

  @override
  String get editor_shortcutTemporaryColorPicker => '一時的なカラーピッカー';

  @override
  String get editor_shortcutRectSelection => '長方形の選択';

  @override
  String get editor_shortcutEllipseSelection => '楕円の選択';

  @override
  String get editor_shortcutLassoSelection => 'なげなわ選択';

  @override
  String get editor_shortcut100Zoom => '100% ズーム';

  @override
  String get editor_shortcutFitHeight => '高さに合わせる';

  @override
  String get editor_shortcutFitWidth => '幅に合わせる';

  @override
  String get editor_shortcutRotateLeft15 => '左に 15 度回転';

  @override
  String get editor_shortcutResetRotation => '回転をリセット';

  @override
  String get editor_shortcutRotateRight15 => '右に 15 度回転';

  @override
  String get editor_shortcutFlipHorizontal => '水平方向に反転';

  @override
  String get editor_shortcutWheel => 'マウス ホイール';

  @override
  String get editor_shortcutBrushSmaller => 'ブラシ サイズを小さくします';

  @override
  String get editor_shortcutBrushLarger => 'ブラシ サイズを大きくする';

  @override
  String get editor_shortcutOpacityLower => '不透明度を下げる';

  @override
  String get editor_shortcutOpacityHigher => '不透明度を増やす';

  @override
  String get editor_shortcutDragBrushSize => 'ブラシ サイズを調整する';

  @override
  String get editor_shortcutSwapColors => '前景色と背景色の交換';

  @override
  String get editor_shortcutPanCanvas => 'パン キャンバス';

  @override
  String get editor_shortcutClearSelectionContent => '選択内容をクリア';

  @override
  String get editor_shortcutCancelCurrentAction => '現在のアクションをキャンセルします';

  @override
  String get editor_selectUnlockedLayerWithContent =>
      'コンテンツを含むロック解除されたレイヤーを選択してください';

  @override
  String get editor_readCurrentLayerFailed => '現在のレイヤーの読み取りに失敗しました';

  @override
  String get editor_localEffects => 'ローカル後処理 / エフェクト';

  @override
  String get editor_basicAdjustments => '基本的な調整';

  @override
  String get editor_styleAndRepair => 'スタイルと修復';

  @override
  String get editor_transformCrop => '回転/反転/切り抜き';

  @override
  String get editor_transformCropDescription =>
      'ジオメトリ操作は別のものです。最初にプレビューを生成し、確認後にのみ書き戻します。';

  @override
  String get editor_effectPreviewHint =>
      'プレビューは元の画像を変更しません。「適用」をクリックすると、結果をアクティブなレイヤーに書き込み、アンドゥ履歴に追加します。';

  @override
  String get editor_applyToCurrentLayer => '現在のレイヤーに適用';

  @override
  String editor_oneShotEffectHint(Object effect) {
    return '$effect はワンショット操作であり、強度スライダーはありません。';
  }

  @override
  String editor_effectIntensity(Object effect) {
    return '$effect 強度';
  }

  @override
  String get editor_original => 'オリジナル';

  @override
  String get editor_effectPreview => 'エフェクトのプレビュー';

  @override
  String get editor_effectBrightness => '明るさ';

  @override
  String get editor_effectContrast => 'コントラスト';

  @override
  String get editor_effectSaturation => '彩度';

  @override
  String get editor_effectTemperature => '温度';

  @override
  String get editor_effectGamma => 'ガンマ';

  @override
  String get editor_effectGrayscale => 'グレースケール';

  @override
  String get editor_effectInvert => '反転';

  @override
  String get editor_effectSepia => 'セピア';

  @override
  String get editor_effectDenoise => 'ノイズ除去';

  @override
  String get editor_effectBlur => 'ガウスぼかし';

  @override
  String get editor_effectSharpen => 'シャープにする';

  @override
  String get editor_effectCropToSelection => '選択範囲まで切り抜き';

  @override
  String get editor_effectRotateLeft => '左に 90 度回転';

  @override
  String get editor_effectRotateRight => '右に 90 度回転';

  @override
  String get editor_effectFlipHorizontal => '水平方向に反転';

  @override
  String get editor_effectFlipVertical => '垂直方向に反転';

  @override
  String editor_effectApplied(Object effect) {
    return '適用済み $effect';
  }

  @override
  String editor_applyEffectFailed(Object error) {
    return '効果の適用に失敗しました: $error';
  }

  @override
  String get editor_changeCanvasSize => 'キャンバス サイズの変更';

  @override
  String editor_canvasTooSmall(Object width, Object height) {
    return 'キャンバスのサイズが小さすぎます。最小サイズは $width × $height ピクセルです';
  }

  @override
  String editor_canvasTooLarge(Object width, Object height) {
    return 'キャンバスのサイズが大きすぎます。最大サイズは $width × $height ピクセルです';
  }

  @override
  String editor_canvasResized(Object width, Object height) {
    return 'キャンバスのサイズを $width × $height に変更しました';
  }

  @override
  String editor_canvasResizeFailed(Object error) {
    return 'キャンバスのサイズ変更に失敗しました: $error';
  }

  @override
  String get editor_confirmExitTitle => '終了の確認';

  @override
  String get editor_confirmExitContent => '未保存の変更があります。終了してもよろしいですか?';

  @override
  String get editor_exit => '終了';

  @override
  String get editor_saveAndExit => '保存して終了';

  @override
  String editor_exportFailed(Object error) {
    return 'エクスポートに失敗しました: $error';
  }

  @override
  String get editor_clickInsideClosedRegion => '閉じた領域内をクリックして塗りつぶします。';

  @override
  String get editor_drawClosedMaskOutlineFirst => '最初に閉じたマスクの輪郭を描画します。';

  @override
  String get editor_noClosedRegionAtPosition => 'この位置には充填可能な閉じた領域がありません。';

  @override
  String get editor_generateMaskOverlayFailed => 'マスク オーバーレイの生成に失敗しました';

  @override
  String get editor_maskLayerName => 'マスク';

  @override
  String get editor_updateMaskLayerFailed => 'マスクレイヤーの更新に失敗しました';

  @override
  String get editor_closedRegionFilled => '閉じた領域がマスクとして埋められました。';

  @override
  String editor_fillMaskFailed(Object error) {
    return 'マスクの塗りつぶしに失敗しました: $error';
  }

  @override
  String get editor_focusInactiveHint =>
      'ボタンをクリックしてフォーカス モードに入り、フォーカス エリアを描画してマスクをペイントします。';

  @override
  String get editor_focusReadyHint =>
      'フォーカス エリアが選択されました。ブラシを使用してマスクの編集を続けることができます。';

  @override
  String get editor_focusNeedsSelectionHint =>
      '最初にフォーカス エリアを描画し、次にブラシに切り替えてマスクをペイントします。';

  @override
  String get editor_focusSelection => '選択';

  @override
  String get editor_focusBrush => 'ブラシ';

  @override
  String get editor_focusContextHint =>
      '外側の長方形は Focused インペイントに送信される領域です。内側の長方形が主な再描画領域です。その間の帯が最小コンテキスト領域です。';

  @override
  String editor_focusAnlasWarning(int width, int height, int cost) {
    return '実際に送信する範囲は $width×$height です。現在の生成設定では $cost Anlas を消費します。';
  }

  @override
  String get editor_compressionTitle => '出力解像度';

  @override
  String get editor_compressionTooltip => '出力解像度を選択';

  @override
  String get editor_compressionUncompressed => '編集作業サイズを維持し、圧縮は行いません。';

  @override
  String get editor_compressionApplyOnDone =>
      '作業キャンバスは変更されません。「完了」を押したときに Pica Lanczos3 で 1 回だけ圧縮します。';

  @override
  String editor_compressionSizeSummary(
    int workWidth,
    int workHeight,
    int targetWidth,
    int targetHeight,
  ) {
    return '作業サイズ $workWidth×$workHeight → 出力サイズ $targetWidth×$targetHeight';
  }

  @override
  String editor_compressionNormalSummary(
    int normalWidth,
    int normalHeight,
    int minimumWidth,
    int minimumHeight,
  ) {
    return 'Normal（約 1 MP）: $normalWidth×$normalHeight。最低: $minimumWidth×$minimumHeight。';
  }

  @override
  String get editor_compressionUnavailable =>
      '作業キャンバスはすでに最低圧縮段階より小さいため、解像度を下げられません。';

  @override
  String get editor_compressionFocusLimited =>
      '現在の Focused Inpaint 選択範囲では、これ以上の解像度がリクエスト面積上限を超えるため、スライダー上限を制限しています。';

  @override
  String editor_focusRequestSummary(
    int outerWidth,
    int outerHeight,
    int requestWidth,
    int requestHeight,
    int cost,
  ) {
    return '外側の切り抜き $outerWidth×$outerHeight、送信サイズ $requestWidth×$requestHeight、推定 $cost Anlas。';
  }

  @override
  String editor_unsupportedImageFormat(Object extension) {
    return 'サポートされていないファイル形式: .$extension\n画像ファイル(PNG、JPG、WEBPなど)を選択してください。';
  }

  @override
  String editor_readFileFailed(Object error) {
    return 'ファイルの読み取りに失敗しました: $error';
  }

  @override
  String get editor_noFileData => 'ファイルデータの取得に失敗しました';

  @override
  String get editor_emptyImageFile => 'ファイルが空です。有効な画像ファイルを選択してください';

  @override
  String editor_fileTooLarge(Object sizeMB) {
    return 'ファイルが大きすぎます ($sizeMB MB)。 50 MB 未満の画像を選択してください';
  }

  @override
  String get editor_maskLayerAdded => 'マスクレイヤーを追加しました';

  @override
  String get editor_parseImageFailed =>
      '画像ファイルの解析に失敗しました\nファイルが破損しておらず、その形式がサポートされていることを確認してください';

  @override
  String editor_loadMaskFailed(Object error) {
    return 'マスクのロードに失敗しました: $error';
  }

  @override
  String get editor_defaultTitle => 'キャンバス';

  @override
  String get editor_baseLayerName => '基本イメージ';

  @override
  String get editor_existingMaskLayerName => '既存のマスク';

  @override
  String get editor_defaultDrawingLayerName => 'レイヤ 1';

  @override
  String editor_layerName(Object count) {
    return 'レイヤー $count';
  }

  @override
  String editor_statusZoom(Object value) {
    return 'ズーム: $value%';
  }

  @override
  String editor_statusCanvas(Object width, Object height) {
    return 'キャンバス: $width × $height';
  }

  @override
  String editor_statusLayers(Object count) {
    return 'レイヤー: $count';
  }

  @override
  String get editor_statusHasSelection => '選択が有効です';

  @override
  String editor_statusRotation(Object degrees) {
    return '回転: $degrees°';
  }

  @override
  String get editor_statusMirrored => 'ミラーリングされました';

  @override
  String editor_focusMinimumContextArea(Object value) {
    return '最小コンテキスト領域: $value';
  }

  @override
  String get editor_canvasSizeTitle => 'キャンバスのサイズ';

  @override
  String get editor_presetSize => 'プリセット サイズ';

  @override
  String get editor_customSize => 'カスタム';

  @override
  String get editor_contentHandling => 'コンテンツの処理';

  @override
  String get editor_contentCrop => '切り抜き';

  @override
  String get editor_contentPad => 'パッド';

  @override
  String get editor_contentStretch => 'ストレッチ';

  @override
  String get editor_width => '幅';

  @override
  String get editor_height => '高さ';

  @override
  String get editor_lockAspectRatio => 'アスペクト比をロックする';

  @override
  String get editor_unlockAspectRatio => 'アスペクト比のロックを解除します';

  @override
  String get editor_sizePreview => 'サイズのプレビュー';

  @override
  String get editor_originalSize => 'オリジナル';

  @override
  String get editor_newSize => '新しいサイズ';

  @override
  String get editor_cropModeDescription => 'トリミング モード - アスペクト比を維持してトリミングします';

  @override
  String get editor_padModeDescription => 'パッドモード - アスペクト比を維持して余白を追加します';

  @override
  String get editor_stretchModeDescription => 'ストレッチ モード - いっぱいまでストレッチします';

  @override
  String editor_canvasPresetSquare(Object size) {
    return '正方形 $size';
  }

  @override
  String editor_canvasPresetLandscape(Object ratio) {
    return '横長 $ratio';
  }

  @override
  String editor_canvasPresetPortrait(Object ratio) {
    return 'ポートレート $ratio';
  }

  @override
  String get editor_canvasPresetNaiPortrait => 'NAI 縦長';

  @override
  String get editor_canvasPresetNaiLandscape => 'NAI 横長';

  @override
  String get editor_canvasPresetFullHd => 'フル HD 16:9';

  @override
  String get editor_colorPanelTitle => 'カラー';

  @override
  String get editor_colorPickerTitle => '色を選択してください';

  @override
  String get editor_eraserSettings => '消しゴムの設定';

  @override
  String get editor_colorPickerHint =>
      'キャンバス上の任意の場所をクリックして色を選択します。放すと前のツールに戻ります。';

  @override
  String get editor_sample => 'サンプル';

  @override
  String get editor_samplePoint => 'ポイント';

  @override
  String get editor_sampleArea => 'エリア';

  @override
  String get editor_source => 'ソース';

  @override
  String get editor_sourceCurrentLayer => '現在のレイヤー';

  @override
  String get editor_sourceAllLayers => 'すべてのレイヤー';

  @override
  String get editor_lassoSelectionHelp =>
      '押したままドラッグして、自由形式の選択範囲を描画します。放すと自動的に閉まります。';

  @override
  String get layer_empty => 'レイヤーがありません';

  @override
  String get layer_add => 'レイヤーを追加';

  @override
  String get layer_mergeDown => '下へマージ';

  @override
  String get layer_duplicate => '重複';

  @override
  String get layer_delete => '削除';

  @override
  String get layer_merge => '下へマージ';

  @override
  String get layer_visibility => '表示/非表示の切り替え';

  @override
  String get layer_lock => 'ロックの切り替え';

  @override
  String get layer_rename => '名前の変更';

  @override
  String get layer_moveUp => '上に移動';

  @override
  String get layer_moveDown => '下に移動';

  @override
  String get vibe_title => 'バイブストランスファー';

  @override
  String get vibe_hint => 'ビジュアル スタイルを転送するための参照画像を追加します (最大 4 つ)';

  @override
  String get vibe_description => 'イメージを変えて、ビジョンを維持します。';

  @override
  String get vibe_addFromFileTitle => 'ファイルから追加';

  @override
  String get vibe_addFromFileSubtitle => 'PNG、JPG、Vibe ファイル';

  @override
  String get vibe_addFromLibraryTitle => 'ライブラリからインポート';

  @override
  String get vibe_addFromLibrarySubtitle => 'バイブライブラリから選択';

  @override
  String get vibe_addReference => '参照の追加';

  @override
  String get vibe_clearAll => 'すべてクリア';

  @override
  String vibe_cleared(int count) {
    return '$count 件の Vibe をクリアしました';
  }

  @override
  String vibe_referenceNumber(Object index) {
    return '参照番号$index';
  }

  @override
  String get vibe_referenceStrength => '参照強度';

  @override
  String get vibe_infoExtraction => '抽出情報';

  @override
  String get vibe_adjustParams => 'パラメータを調整する';

  @override
  String get vibe_remove => '削除';

  @override
  String get reference_enabled => '有効';

  @override
  String get reference_enable => '参照を有効化';

  @override
  String get reference_disable => '参照を無効化';

  @override
  String get vibe_sliderHint =>
      '参照強度: 高いほど視覚的な特徴をまねします\n抽出情報: 低くするとテクスチャが減少し、構成が維持されます。';

  @override
  String vibe_strengthInfo(Object value, Object infoValue) {
    return '参照強度: $value | 抽出情報: $infoValue';
  }

  @override
  String get vibe_normalize => '基準強度値の正規化';

  @override
  String vibe_encodingCost(int cost) {
    return 'エンコードが必要です。次回の生成時に $cost Anlas を消費します。';
  }

  @override
  String get vibe_sourceType_png => 'PNG';

  @override
  String get vibe_sourceType_v4vibe => 'V4 Vibe';

  @override
  String get vibe_sourceType_bundle => 'バンドル';

  @override
  String get vibe_sourceType_image => '画像';

  @override
  String get vibe_sourceType => 'ソース';

  @override
  String get vibe_reuseButton => '再利用';

  @override
  String get vibe_reuseSuccess => 'Vibe が生成パラメータに追加されました';

  @override
  String get vibe_info => 'Vibe 情報';

  @override
  String get vibe_name => '名前';

  @override
  String get vibe_strength => '強度';

  @override
  String get vibe_infoExtracted => '抽出情報';

  @override
  String get vibe_shiftReplaceHint => 'Shift+クリックして置換';

  @override
  String get characterRef_title => 'キャラ参照';

  @override
  String get characterRef_hint => '一貫性を維持するためにキャラ参照画像をアップロードします (V4+ のみ)';

  @override
  String get characterRef_v4Only => 'キャラ参照は V4+ モデルのみをサポートしています。モデルを切り替えてください。';

  @override
  String get characterRef_addReference => '参照の追加';

  @override
  String get characterRef_clearAll => 'すべてクリア';

  @override
  String characterRef_referenceNumber(Object index) {
    return '参照番号$index';
  }

  @override
  String get characterRef_description => 'キャラクターの説明';

  @override
  String get characterRef_descriptionHint =>
      'このキャラクターの特徴を説明してください (オプションですが推奨)...';

  @override
  String get characterRef_remove => '削除';

  @override
  String get characterRef_styleAware => 'スタイルを意識';

  @override
  String get characterRef_styleAwareHint => 'キャラクター関連のスタイル情報を転送します';

  @override
  String get characterRef_fidelity => '忠実度';

  @override
  String get characterRef_fidelityHint => '0=古いバージョンの動作、1=新しいバージョンの動作';

  @override
  String get unifiedRef_title => '画像参照';

  @override
  String get unifiedRef_switchTitle => 'モードの切り替え';

  @override
  String get unifiedRef_switchContent => 'モードを切り替えると、現在の参照がクリアされます。続行しますか？';

  @override
  String get character_buttonLabel => 'キャラクター';

  @override
  String get character_title => 'マルチキャラクター (V4 のみ)';

  @override
  String get character_hint => 'キャラクターごとに独立したプロンプトと位置を定義します (最大 6 つ)';

  @override
  String get character_addCharacter => 'キャラクターを追加';

  @override
  String get character_clearAll => 'すべてのキャラクターをクリア';

  @override
  String character_number(Object index) {
    return 'キャラクター $index';
  }

  @override
  String get character_advancedOptions => '詳細オプション';

  @override
  String get character_removeCharacter => 'キャラクターを削除';

  @override
  String get character_description => 'キャラクターの説明';

  @override
  String get character_descriptionHint => 'このキャラクターの特徴を説明してください...';

  @override
  String get character_negativeOptional => '除外したい要素 (オプション)';

  @override
  String get character_negativeHint => 'このキャラクターには望ましくない機能があります...';

  @override
  String get character_positionOptional => 'キャラクター位置 (オプション)';

  @override
  String get character_positionHint => '位置 (0-1)、画像内のおおよその位置を指定します';

  @override
  String get character_auto => '自動';

  @override
  String get character_clearPosition => 'ポジションをクリア';

  @override
  String get gallery_empty => 'ギャラリーは空です';

  @override
  String get gallery_emptyHint => '生成された画像がここに表示されます';

  @override
  String get gallery_searchHint => '検索プロンプト... (タグをサポート)';

  @override
  String gallery_imageCount(Object count) {
    return '$count 画像';
  }

  @override
  String gallery_exportSuccess(Object count, Object path) {
    return '$count の画像を $path にエクスポートしました';
  }

  @override
  String gallery_savedTo(Object path) {
    return '$path に保存されました';
  }

  @override
  String get gallery_saveFailed => '保存に失敗しました';

  @override
  String get gallery_deleteImage => '画像を削除';

  @override
  String get gallery_deleteImageConfirm => 'この画像を削除してもよろしいですか?';

  @override
  String get gallery_generationParams => '生成パラメータ';

  @override
  String get gallery_metaModel => 'モデル';

  @override
  String get gallery_metaResolution => '解像度';

  @override
  String get gallery_metaSteps => 'ステップ';

  @override
  String get gallery_metaSampler => 'サンプラー';

  @override
  String get gallery_metaCfgScale => 'CFG スケール';

  @override
  String get gallery_metaSeed => 'シード';

  @override
  String get gallery_metaSmea => 'SMEA';

  @override
  String get gallery_metaSmeaOn => 'オン';

  @override
  String get gallery_metaSmeaOff => 'オフ';

  @override
  String get gallery_metaGenerationTime => '生成時間';

  @override
  String get gallery_metaFileSize => 'ファイルサイズ';

  @override
  String get gallery_positivePrompt => 'プロンプト';

  @override
  String get gallery_negativePrompt => '除外したい要素';

  @override
  String get gallery_promptCopied => 'プロンプトがコピーされました';

  @override
  String get gallery_seedCopied => 'シードがコピーされました';

  @override
  String get gallery_sendToImg2Img => 'Image2Image';

  @override
  String get gallery_useImageForGeneration => 'この画像を画像生成に使用します';

  @override
  String get gallery_sendToReversePromptTitle => '逆プロンプト';

  @override
  String get gallery_addToReversePromptModule => 'キャンバスのリバースプロンプトモジュールに追加します';

  @override
  String get gallery_applyVibeFromImage => '画像のスタイル/キャラクターを抽出して適用します';

  @override
  String get gallery_noVibeData => 'この画像には Vibe データが含まれていません';

  @override
  String get gallery_sendToKrita => 'クリタ';

  @override
  String get gallery_sendToKritaAction => 'Krita に送信';

  @override
  String get gallery_sendToConnectedKrita => '接続されている Krita プラグインに送信します';

  @override
  String get gallery_upscalePanelLoaded => 'Image2Image の拡大パネルを読み込みました';

  @override
  String gallery_readImageFailed(Object error) {
    return '画像の読み取りに失敗しました: $error';
  }

  @override
  String get gallery_fileMissing => 'ファイルが存在しません';

  @override
  String get gallery_copiedToClipboard => 'クリップボードにコピーされました';

  @override
  String gallery_copyFailed(Object error) {
    return 'コピーに失敗しました: $error';
  }

  @override
  String get gallery_textToImage => 'テキストから画像へ';

  @override
  String get gallery_applyParams => 'パラメータを適用';

  @override
  String get gallery_unavailable => '利用できません';

  @override
  String get gallery_loadSourceImage => 'ソース画像をロードします';

  @override
  String get gallery_upscale => '拡大';

  @override
  String get gallery_superResolutionUpscale => '超解像度拡大';

  @override
  String get gallery_sentToImg2Img => '画像を Image2Image に送信しました';

  @override
  String get gallery_sentToReversePrompt => '画像がリバースプロンプトモジュールに送信されました';

  @override
  String gallery_sendFailed(Object error) {
    return '送信失敗: $error';
  }

  @override
  String get preset_noPresets => 'プリセットはありません';

  @override
  String get preset_restoreDefault => 'デフォルトに戻す';

  @override
  String preset_configGroupCount(Object count) {
    return '$count 構成グループ';
  }

  @override
  String get preset_setAsCurrent => '現在として設定';

  @override
  String get preset_duplicate => '重複';

  @override
  String get preset_export => 'エクスポート';

  @override
  String get preset_delete => '削除';

  @override
  String get preset_noConfigGroups => '構成グループはまだありません';

  @override
  String get preset_addConfigGroup => '構成グループの追加';

  @override
  String get preset_selectPreset => 'プリセットを選択してください';

  @override
  String get preset_selectConfigToEdit => '編集する構成グループを選択してください';

  @override
  String get preset_editConfigGroup => '構成グループの編集';

  @override
  String get preset_configName => '構成名';

  @override
  String get preset_presetName => 'プリセット名';

  @override
  String get preset_selectionMode => '選択モード';

  @override
  String get preset_randomSingle => 'ランダムシングル';

  @override
  String get preset_sequentialSingle => 'シーケンシャルシングル';

  @override
  String get preset_specifiedCount => '指定された数';

  @override
  String get preset_byProbability => '確率による';

  @override
  String get preset_all => 'すべて';

  @override
  String get preset_selectCount => 'カウントの選択';

  @override
  String get preset_selectProbability => '確率の選択';

  @override
  String get preset_shuffleOrder => 'シャッフル順序';

  @override
  String get preset_shuffleOrderHint => '選択したコンテンツをランダムに配置します';

  @override
  String get preset_weightBrackets => 'ウェイト ブラケット';

  @override
  String get preset_weightBracketsHint => '各中括弧でウェイトが約 5% 増加します';

  @override
  String get preset_min => '分';

  @override
  String get preset_max => '最大';

  @override
  String preset_preview(Object preview) {
    return 'プレビュー: $preview';
  }

  @override
  String get preset_tagContent => 'タグの内容';

  @override
  String preset_tagContentHint(Object count) {
    return '1 行に 1 つのタグ、現在 $count 項目';
  }

  @override
  String get preset_format => '形式';

  @override
  String get preset_sort => '並べ替え';

  @override
  String get preset_inputHint =>
      'タグを 1 行に 1 つずつ入力してください...\nたとえば:\n1女の子\n美しい目\n長い髪';

  @override
  String get preset_unsavedChanges => '未保存の変更';

  @override
  String get preset_unsavedChangesConfirm => '未保存の変更があります。破棄？';

  @override
  String get preset_discard => '破棄';

  @override
  String get preset_deletePreset => 'プリセットを削除';

  @override
  String preset_deletePresetConfirm(Object name) {
    return '「$name」を削除してもよろしいですか?';
  }

  @override
  String get preset_importConfig => '構成のインポート';

  @override
  String get preset_pasteJson => 'JSON 構成を貼り付けます...';

  @override
  String get preset_importSuccess => 'インポートが成功しました';

  @override
  String preset_importFailed(Object error) {
    return 'インポートに失敗しました: $error';
  }

  @override
  String get preset_restoreDefaultConfirm =>
      'デフォルトのプリセットを復元しますか?すべてのカスタム構成が削除されます。';

  @override
  String get preset_restored => 'デフォルトに復元されました';

  @override
  String get preset_copiedToClipboard => 'クリップボードにコピーされました';

  @override
  String get preset_setAsCurrentSuccess => '現在のプリセットとして設定';

  @override
  String get preset_duplicated => 'プリセットが複製されました';

  @override
  String get preset_deleted => '削除されました';

  @override
  String get preset_saveSuccess => '正常に保存されました';

  @override
  String get preset_newPresetCreated => '新しいプリセットが作成されました';

  @override
  String preset_itemCount(Object count) {
    return '$count アイテム';
  }

  @override
  String preset_subConfigCount(Object count) {
    return '$count サブ構成';
  }

  @override
  String get preset_random => 'ランダム';

  @override
  String get preset_sequential => 'シーケンシャル';

  @override
  String get preset_multiple => '複数';

  @override
  String get preset_probability => '確率';

  @override
  String get preset_moreActions => 'その他のアクション';

  @override
  String get preset_rename => '名前の変更';

  @override
  String get preset_moveUp => '上に移動';

  @override
  String get preset_moveDown => '下に移動';

  @override
  String get onlineGallery_search => '検索';

  @override
  String get onlineGallery_popular => '人気';

  @override
  String get onlineGallery_favorites => 'お気に入り';

  @override
  String get onlineGallery_searchTags => 'タグを検索...';

  @override
  String get onlineGallery_refresh => '更新';

  @override
  String get onlineGallery_login => 'ログイン';

  @override
  String get onlineGallery_logout => 'ログアウト';

  @override
  String get onlineGallery_dayRank => '日';

  @override
  String get onlineGallery_weekRank => '週';

  @override
  String get onlineGallery_monthRank => '月';

  @override
  String get onlineGallery_today => '今日';

  @override
  String onlineGallery_imageCount(Object count) {
    return '$count 画像';
  }

  @override
  String get onlineGallery_loadFailed => 'ロードに失敗しました';

  @override
  String get onlineGallery_favoritesEmpty => 'お気に入りが空です';

  @override
  String get onlineGallery_noResults => '画像が見つかりませんでした';

  @override
  String get onlineGallery_pleaseLogin => 'まずログインしてください';

  @override
  String get onlineGallery_size => 'サイズ';

  @override
  String get onlineGallery_score => 'スコア';

  @override
  String get onlineGallery_favCount => 'お気に入り';

  @override
  String get onlineGallery_rating => '評価';

  @override
  String get onlineGallery_type => 'タイプ';

  @override
  String get mediaType_video => 'ビデオ';

  @override
  String get mediaType_gif => 'GIF';

  @override
  String get onlineGallery_tags => 'タグ';

  @override
  String get onlineGallery_artists => 'アーティスト';

  @override
  String get onlineGallery_characters => 'キャラクター';

  @override
  String get onlineGallery_copyrights => '著作権';

  @override
  String get onlineGallery_general => '一般';

  @override
  String get onlineGallery_copied => 'コピーされました';

  @override
  String get onlineGallery_copyTags => 'タグをコピー';

  @override
  String get onlineGallery_open => '開く';

  @override
  String get onlineGallery_send => '送信';

  @override
  String get onlineGallery_addToQueue => 'キューに追加';

  @override
  String get onlineGallery_sendToTextToImage => 'テキストから画像へ送信';

  @override
  String get onlineGallery_sentToTextToImage => 'text-to-image に送信されました';

  @override
  String get onlineGallery_sendToReversePrompt => '逆プロンプトに送信';

  @override
  String get onlineGallery_sentToReversePrompt => 'リバースプロンプトモジュールに送信されました';

  @override
  String onlineGallery_reversePromptSendFailed(Object error) {
    return '逆プロンプトへの送信に失敗しました: $error';
  }

  @override
  String get onlineGallery_noTagInfo => 'この画像にはタグ情報がありません';

  @override
  String get onlineGallery_promptSentToGeneration => 'プロンプトが生成ページに送信されました';

  @override
  String get onlineGallery_noImageUrl => 'この画像には利用可能な URL がありません';

  @override
  String get onlineGallery_gifLoadFailed => 'GIFのロードに失敗しました';

  @override
  String get onlineGallery_pinchToZoom => 'ピンチしてズーム';

  @override
  String get onlineGallery_metadata => 'メタデータ';

  @override
  String get onlineGallery_addedToQueue => 'キューに追加されました';

  @override
  String get onlineGallery_queueFullMax => 'キューがいっぱいです (最大 50 項目)';

  @override
  String get onlineGallery_chooseDownloadDirectory => 'ダウンロード ディレクトリを選択してください';

  @override
  String get onlineGallery_downloadStarted => 'ダウンロードが開始されました...';

  @override
  String onlineGallery_savedToPath(Object path) {
    return '保存先: $path';
  }

  @override
  String onlineGallery_downloadFailed(Object error) {
    return 'ダウンロードに失敗しました: $error';
  }

  @override
  String get onlineGallery_downloadOriginal => '元の画像をダウンロード';

  @override
  String get onlineGallery_all => 'すべて';

  @override
  String get onlineGallery_ratingGeneral => '一般';

  @override
  String get onlineGallery_ratingSensitive => 'センシティブ';

  @override
  String get onlineGallery_ratingQuestionable => '疑問あり';

  @override
  String get onlineGallery_ratingExplicit => '露骨';

  @override
  String get onlineGallery_clear => 'クリア';

  @override
  String get onlineGallery_previousPage => '前のページ';

  @override
  String get onlineGallery_nextPage => '次のページ';

  @override
  String onlineGallery_pageN(Object page) {
    return 'ページ $page';
  }

  @override
  String get onlineGallery_dateRange => '日付範囲';

  @override
  String get onlineGallery_fuzzySearch => 'ファジーマッチ';

  @override
  String get onlineGallery_fuzzySearchTooltip =>
      '有効な場合は、関連タグに *tag* マッチングを使用します。無効になっている場合は、正確な Danbooru タグを検索します';

  @override
  String get onlineGallery_blacklistTags => 'ブラックリスト タグ';

  @override
  String get onlineGallery_blacklistTitle => 'オンライン ギャラリー ブラックリスト';

  @override
  String get onlineGallery_blacklistSubtitle =>
      'ブラックリストに登録されたタグを含む画像は、オンライン ギャラリーで直接非表示になります。';

  @override
  String get onlineGallery_addBlacklistTagHint => 'ブラックリスト タグを追加';

  @override
  String get onlineGallery_noLocalBlacklistTags => 'ローカル ブラックリスト タグがありません';

  @override
  String get onlineGallery_autoSyncOnStartup => '起動時に自動同期';

  @override
  String get onlineGallery_autoSyncOnStartupSubtitle =>
      'デフォルトで有効になります。いつでもオフにできます';

  @override
  String onlineGallery_lastSyncFailed(Object error) {
    return '最後の同期に失敗しました: $error';
  }

  @override
  String get onlineGallery_neverSyncedBlacklist =>
      'Danbooru ブラックリストはまだ同期されていません';

  @override
  String onlineGallery_lastSync(Object time) {
    return '最終同期: $time';
  }

  @override
  String get onlineGallery_blacklistSettingsTitle => 'オンライン ギャラリーのブラックリスト設定';

  @override
  String get onlineGallery_blacklistLoginHint =>
      'Danbooru にログインしていません。ローカルのブラックリストは引き続き機能しますが、同期にはログインが必要です。';

  @override
  String get onlineGallery_bulkFavorite => '選択項目をお気に入りに追加';

  @override
  String get onlineGallery_bulkDownload => '選択項目をダウンロード';

  @override
  String onlineGallery_addedTasksToQueue(Object count) {
    return '$count タスクをキューに追加しました';
  }

  @override
  String get onlineGallery_unfavorited => 'お気に入りから削除しました';

  @override
  String get onlineGallery_favorited => 'お気に入りに登録しました';

  @override
  String onlineGallery_favoritedImages(Object count) {
    return '$count 件の画像をお気に入りに追加しました';
  }

  @override
  String onlineGallery_selectDownloadDirectoryFailed(Object error) {
    return 'ダウンロード ディレクトリの選択に失敗しました: $error';
  }

  @override
  String onlineGallery_downloadSelectedStarted(Object count) {
    return '$count 画像をダウンロードしています...';
  }

  @override
  String onlineGallery_downloadSelectedCompleted(
    Object success,
    Object failed,
  ) {
    return 'ダウンロード完了: $success 成功、$failed 失敗';
  }

  @override
  String get onlineGallery_startDate => '開始日';

  @override
  String get onlineGallery_endDate => '終了日';

  @override
  String get onlineGallery_invalidDateFormat => '無効な日付形式です';

  @override
  String get onlineGallery_dateOutOfRange => '日付が範囲外です';

  @override
  String get onlineGallery_last30Days => '過去 30 日間';

  @override
  String get tooltip_randomPrompt => 'ランダムプロンプト (長押しして設定)';

  @override
  String get tooltip_fullscreenEdit => 'フルスクリーン編集';

  @override
  String get tooltip_maximizePrompt => 'プロンプト領域を最大化';

  @override
  String get tooltip_restoreLayout => 'レイアウトを復元';

  @override
  String get tooltip_clear => 'クリア';

  @override
  String get tooltip_promptSettings => 'プロンプト設定';

  @override
  String get tooltip_decreaseWeight => 'ウェイトを下げる [-5%]';

  @override
  String get tooltip_increaseWeight => 'ウェイトを上げる [+5%]';

  @override
  String get tooltip_edit => '編集';

  @override
  String get tooltip_copy => 'コピー';

  @override
  String get tooltip_delete => '削除';

  @override
  String get tooltip_changeImage => '画像の変更';

  @override
  String get tooltip_removeImage => '画像を削除';

  @override
  String get tooltip_previewGenerate => 'プレビュー生成';

  @override
  String get tooltip_help => 'ヘルプ';

  @override
  String get tooltip_addConfigGroup => '構成グループの追加';

  @override
  String get tooltip_enable => '有効にする';

  @override
  String get tooltip_disable => '無効にする';

  @override
  String get tooltip_resetWeight => 'クリックして 100% にリセットします';

  @override
  String get upscale_title => '画像の拡大';

  @override
  String get upscale_close => '閉じる';

  @override
  String get upscale_start => '拡大を開始';

  @override
  String get upscale_sourceImage => 'ソース画像';

  @override
  String get upscale_clickToSelect => 'クリックして拡大する画像を選択してください';

  @override
  String get upscale_scale => 'スケール係数';

  @override
  String get upscale_2xHint => '元のサイズの 2 倍に拡大 (推奨)';

  @override
  String get upscale_4xHint => '元のサイズの 4 倍に拡大 (Anlas のコストが高くなります)';

  @override
  String get upscale_processing => '画像を拡大しています...';

  @override
  String get upscale_complete => '拡大完了';

  @override
  String get upscale_save => '保存';

  @override
  String get upscale_share => 'シェア';

  @override
  String get upscale_failed => '拡大に失敗しました';

  @override
  String upscale_selectFailed(Object error) {
    return '画像の選択に失敗しました: $error';
  }

  @override
  String upscale_savedTo(Object path) {
    return '保存先: $path';
  }

  @override
  String upscale_saveFailed(Object error) {
    return '保存に失敗しました: $error';
  }

  @override
  String upscale_shareFailed(Object error) {
    return '共有に失敗しました: $error';
  }

  @override
  String get danbooru_loginTitle => 'ログイン Danbooru';

  @override
  String get danbooru_loginHint => 'お気に入りを使用するには、ユーザー名と API キーを使用してログインしてください';

  @override
  String get danbooru_username => 'ユーザー名';

  @override
  String get danbooru_usernameHint => 'Danbooru ユーザー名を入力してください';

  @override
  String get danbooru_usernameRequired => 'ユーザー名を入力してください';

  @override
  String get danbooru_apiKeyHint => 'API キーを入力してください';

  @override
  String get danbooru_apiKeyRequired => 'API キーを入力してください';

  @override
  String get danbooru_howToGetApiKey => 'API キーを取得するにはどうすればよいですか?';

  @override
  String get danbooru_loginSuccess => 'ログインに成功しました';

  @override
  String get weight_title => 'ウェイト';

  @override
  String get weight_reset => 'リセット';

  @override
  String get weight_done => '完了';

  @override
  String get weight_noBrackets => '括弧なし';

  @override
  String get weight_editTag => 'タグを編集';

  @override
  String get weight_tagName => 'タグ名';

  @override
  String get weight_tagNameHint => 'タグ名を入力してください...';

  @override
  String tag_selected(Object count) {
    return '$count が選択されました';
  }

  @override
  String get tag_enable => '有効にする';

  @override
  String get tag_disable => '無効にする';

  @override
  String get tag_delete => '削除';

  @override
  String get tag_addTag => 'タグを追加';

  @override
  String get tag_add => '追加';

  @override
  String get tag_inputHint => 'タグを入力してください...';

  @override
  String get tag_copiedToClipboard => 'クリップボードにコピーされました';

  @override
  String get tag_emptyHint => '希望の画像を説明するタグを追加します';

  @override
  String get tag_emptyHintSub => 'タグを手動で参照、検索、追加できます';

  @override
  String get tagCategory_artist => 'アーティスト';

  @override
  String get tagCategory_copyright => '著作権';

  @override
  String get tagCategory_character => 'キャラクター';

  @override
  String get tagCategory_meta => 'メタ';

  @override
  String get tagCategory_general => '一般';

  @override
  String get configEditor_newConfigGroup => '新しい構成グループ';

  @override
  String get configEditor_editConfigGroup => '構成グループの編集';

  @override
  String get configEditor_configName => '構成名';

  @override
  String get configEditor_enableConfig => 'この構成を有効にする';

  @override
  String get configEditor_enableConfigHint => '無効な構成は生成に参加しません';

  @override
  String get configEditor_contentType => 'コンテンツ タイプ';

  @override
  String get configEditor_tagList => 'タグリスト';

  @override
  String get configEditor_nestedConfig => 'ネストされた構成';

  @override
  String get configEditor_selectionMode => '選択モード';

  @override
  String get configEditor_selectCount => '数を選択:';

  @override
  String get configEditor_selectProbability => '確率を選択:';

  @override
  String get configEditor_shuffleOrder => 'シャッフル順序';

  @override
  String get configEditor_shuffleOrderHint => '選択したコンテンツをランダムに配置します';

  @override
  String get configEditor_weightBrackets => 'ウェイト ブラケット';

  @override
  String get configEditor_weightBracketsHint =>
      '括弧により重みが増加し、中括弧ごとに最大 5% 追加されます';

  @override
  String configEditor_minBrackets(Object count) {
    return '最小ブラケット: $count';
  }

  @override
  String configEditor_maxBrackets(Object count) {
    return '最大括弧数: $count';
  }

  @override
  String get configEditor_effectPreview => '効果のプレビュー:';

  @override
  String get configEditor_content => 'コンテンツ';

  @override
  String configEditor_tagCountHint(Object count) {
    return '1 行に 1 つのタグ、現在 $count 個のアイテム';
  }

  @override
  String get configEditor_format => '形式';

  @override
  String get configEditor_sort => '並べ替え';

  @override
  String get configEditor_dedupe => '重複排除';

  @override
  String get configEditor_nestedConfigHint =>
      'ネストされた構成により、複雑な階層化されたランダム ロジックが作成されます';

  @override
  String get configEditor_noNestedConfig => 'ネストされた構成はまだありません';

  @override
  String configEditor_itemCount(Object count) {
    return '$count アイテム';
  }

  @override
  String configEditor_subConfigCount(Object count) {
    return '$count サブ構成';
  }

  @override
  String get configEditor_addNestedConfig => 'ネストされた構成の追加';

  @override
  String get configEditor_subConfig => 'サブ構成';

  @override
  String get configEditor_singleRandom => 'シングル - ランダム';

  @override
  String get configEditor_singleSequential => 'シングル - シーケンシャル';

  @override
  String get configEditor_singleProbability => 'シングル - 確率';

  @override
  String get configEditor_multipleCount => '複数 - カウント';

  @override
  String get configEditor_multipleProbability => '複数 - 確率';

  @override
  String get configEditor_selectAll => 'すべて';

  @override
  String get configEditor_singleRandomHint => '毎回ランダムに 1 つのアイテムを選択します';

  @override
  String get configEditor_singleSequentialHint => '項目を順番に循環します';

  @override
  String get configEditor_singleProbabilityHint =>
      'X% の確率でランダムに 1 つが選択され、それ以外の場合はスキップされます。';

  @override
  String get configEditor_multipleCountHint => '指定された数のアイテムをランダムに選択します';

  @override
  String get configEditor_multipleProbabilityHint => '確率で選択される各アイテム';

  @override
  String get configEditor_selectAllHint => 'すべてのアイテムを選択';

  @override
  String get configEditor_or => ' または ';

  @override
  String get configEditor_enterConfigName => '構成名を入力してください';

  @override
  String get configEditor_continueEditing => '編集を続ける';

  @override
  String get configEditor_discardChanges => '変更を破棄';

  @override
  String configEditor_randomCount(Object count) {
    return 'ランダム $count';
  }

  @override
  String configEditor_probabilityPercent(Object percent) {
    return '$percent% の確率';
  }

  @override
  String get presetEdit_newPreset => '新しいプリセット';

  @override
  String get presetEdit_editPreset => 'プリセットの編集';

  @override
  String get presetEdit_presetName => 'プリセット名';

  @override
  String presetEdit_configGroups(Object count) {
    return '構成グループ ($count)';
  }

  @override
  String get presetEdit_noConfigGroups => '構成グループがまだありません';

  @override
  String get presetEdit_addConfigGroupHint => '右上の + をクリックして構成グループを追加します';

  @override
  String get presetEdit_addConfigGroup => '構成グループの追加';

  @override
  String get presetEdit_newConfigGroup => '新しい構成グループ';

  @override
  String get presetEdit_enterPresetName => 'プリセット名を入力してください';

  @override
  String get presetEdit_saveSuccess => '正常に保存されました';

  @override
  String get presetEdit_saveError => 'プリセットの保存に失敗しました';

  @override
  String presetEdit_deleteConfigConfirm(Object name) {
    return '構成グループ「$name」を削除しますか?';
  }

  @override
  String get presetEdit_previewTitle => 'プレビュー生成結果';

  @override
  String get presetEdit_emptyResult => '(結果は空です。設定を確認してください)';

  @override
  String get presetEdit_regenerate => '再生成';

  @override
  String get presetEdit_helpTitle => 'ヘルプ';

  @override
  String get presetEdit_helpConfigGroup => '構成グループの説明';

  @override
  String get presetEdit_helpConfigGroupContent =>
      '各構成グループはコンテンツを順番に生成し、最終結果はカンマで結合されます。';

  @override
  String get presetEdit_helpSelectionMode => '選択モード';

  @override
  String get presetEdit_helpSingleRandom =>
      '• Single-Random: 1 つのアイテムをランダムに選択します';

  @override
  String get presetEdit_helpSingleSequential => '• シングルシーケンシャル: 順番に循環します。';

  @override
  String get presetEdit_helpMultipleCount =>
      '• Multiple-Count: 指定されたカウントをランダムに選択します';

  @override
  String get presetEdit_helpMultipleProbability =>
      '• 複数の確率: 各アイテムは確率によって独立して選択されます。';

  @override
  String get presetEdit_helpAll => '• すべて: すべての項目を選択します。';

  @override
  String get presetEdit_helpWeightBrackets => 'ウェイト ブラケット';

  @override
  String get presetEdit_helpWeightBracketsContent =>
      '中括弧は重みを増加させます。括弧が多いほど重みが高くなります。';

  @override
  String get presetEdit_helpWeightBracketsExample =>
      '例: ブラケット 1 個でウェイト 1.05 倍、ブラケット 2 個でウェイト 1.1 倍です。';

  @override
  String get presetEdit_helpNestedConfig => 'ネストされた構成';

  @override
  String get presetEdit_helpNestedConfigContent =>
      '構成は、複雑な階層化されたランダム ロジック用にネストできます。';

  @override
  String get presetEdit_gotIt => 'わかりました';

  @override
  String presetEdit_tagCount(Object count) {
    return '$count タグ';
  }

  @override
  String presetEdit_bracketLayers(Object count) {
    return '$count ブラケット レイヤ';
  }

  @override
  String presetEdit_bracketRange(Object min, Object max) {
    return '$min-$max ブラケット レイヤ';
  }

  @override
  String get qualityTags_label => '品質';

  @override
  String get qualityTags_positive => '品質 (プロンプト)';

  @override
  String get qualityTags_negative => '品質 (除外したい要素)';

  @override
  String get qualityTags_disabled => '品質タグが無効です\nクリックして有効にします';

  @override
  String get qualityTags_addToEnd => 'プロンプトの最後に追加:';

  @override
  String get qualityTags_naiDefault => 'NAI のデフォルト';

  @override
  String get qualityTags_none => 'なし';

  @override
  String get qualityTags_addFromLibrary => 'ライブラリから追加';

  @override
  String get qualityTags_selectFromLibrary => '品質タグエントリの選択';

  @override
  String get ucPreset_label => '除外したい要素プリセット';

  @override
  String get ucPreset_heavy => '重い';

  @override
  String get ucPreset_light => 'ライト';

  @override
  String get ucPreset_furryFocus => '毛皮で覆われた';

  @override
  String get ucPreset_humanFocus => '人間';

  @override
  String get ucPreset_none => 'なし';

  @override
  String get ucPreset_custom => 'カスタム';

  @override
  String get ucPreset_disabled => '除外したい要素プリセットが無効です';

  @override
  String get ucPreset_addToNegative => '除外したい要素に追加:';

  @override
  String get ucPreset_nsfwHint =>
      '💡 アダルト コンテンツを生成するには、プロンプトに nsfw を追加します。nsfw タグは除外したい要素から自動的に削除されます';

  @override
  String get ucPreset_addFromLibrary => 'ライブラリから追加';

  @override
  String get ucPreset_selectFromLibrary => '除外したい要素エントリを選択';

  @override
  String get randomMode_enabledTip =>
      'ランダムモードが有効になりました\n各生成後にプロンプトを自動的にランダム化する';

  @override
  String get randomMode_disabledTip =>
      'ランダムモード\nクリックすると、生成時にプロンプトが自動的にランダム化されます';

  @override
  String get batchSize_title => 'バッチサイズ';

  @override
  String batchSize_tooltip(int count) {
    return 'リクエストごとに $count 個の画像';
  }

  @override
  String get batchSize_description => 'API リクエストごとの画像の数';

  @override
  String batchSize_formula(int batchCount, int batchSize, int total) {
    return '画像総数 = $batchCount × $batchSize = $total';
  }

  @override
  String get batchSize_hint => 'バッチが大きい = リクエストは少なくなりますが、リクエストあたりの待ち時間が長くなります';

  @override
  String get batchSize_costWarning => '⚠️ バッチサイズ > 1 には追加の Anlas 費用がかかります';

  @override
  String get font_systemDefault => 'システムのデフォルト';

  @override
  String get font_sourceHanSans => 'ソース・ハン・サンズ';

  @override
  String get font_sourceHanSerif => 'ソース ハン セリフ';

  @override
  String get font_sourceHanSansHK => 'ソース Han Sans HK';

  @override
  String get font_sourceHanMono => 'ソースハンモノ';

  @override
  String get font_zcoolXiaowei => 'ZCOOL シャオウェイ';

  @override
  String get font_zcoolKuaile => 'ZCOOL クアイレ';

  @override
  String get font_mashan => '馬山鄭';

  @override
  String get font_longcang => 'ロン・カン';

  @override
  String get font_liujian => '劉建毛操';

  @override
  String get font_zhimang => '志曼興';

  @override
  String get font_codeFont => 'コードフォント';

  @override
  String get font_modernNarrow => 'モダンナロー';

  @override
  String get font_classicSerif => 'クラシックセリフ';

  @override
  String get font_sciFi => 'SF';

  @override
  String get font_techStyle => 'テックスタイル';

  @override
  String get font_systemFonts => 'システム フォント';

  @override
  String get download_tagsData => 'タグ データ';

  @override
  String get download_cooccurrenceData => '共起タグデータ';

  @override
  String download_failed(Object name) {
    return '$name ダウンロードに失敗しました';
  }

  @override
  String download_downloading(Object name) {
    return '$name をダウンロードしています';
  }

  @override
  String download_complete(Object name) {
    return '$name ダウンロードが完了しました';
  }

  @override
  String download_downloadFailed(Object name) {
    return '$name ダウンロードに失敗しました';
  }

  @override
  String get warmup_networkCheck => 'ネットワーク接続を確認しています...';

  @override
  String get warmup_networkCheck_noProxy =>
      'NovelAI に接続できません。VPN またはプロキシ設定を有効にしてください';

  @override
  String get warmup_networkCheck_noSystemProxy =>
      'プロキシは有効ですが、システム プロキシが検出されませんでした。VPN を有効にしてください。';

  @override
  String get warmup_networkCheck_manualIncomplete =>
      '手動プロキシ構成が不完全です。設定を確認してください。';

  @override
  String get warmup_networkCheck_testing => 'ネットワーク接続をテストしています...';

  @override
  String get warmup_networkCheck_testingProxy => 'プロキシ経由でネットワークをテストしています...';

  @override
  String warmup_networkCheck_failed(Object error) {
    return 'ネットワーク接続に失敗しました: $error、VPN を確認してください';
  }

  @override
  String warmup_networkCheck_success(Object latency) {
    return 'ネットワーク接続は OK (${latency}ms)';
  }

  @override
  String get warmup_networkCheck_timeout =>
      'ネットワーク チェックがタイムアウトしました。オフラインを継続します';

  @override
  String warmup_networkCheck_attempt(Object attempt, Object maxAttempts) {
    return 'ネットワークをチェックしています... ($attempt/$maxAttempts を試行)';
  }

  @override
  String get warmup_preparing => '準備中...';

  @override
  String get warmup_complete => '完了';

  @override
  String get warmup_danbooruAuth => 'Danbooru 認証を初期化しています...';

  @override
  String get warmup_loadingTranslation => '翻訳データをロードしています...';

  @override
  String get warmup_initUnifiedDatabase => 'タグ データベースを初期化しています...';

  @override
  String get warmup_initTagSystem => 'タグ システムを初期化しています...';

  @override
  String get warmup_loadingPromptConfig => 'プロンプト構成を読み込んでいます...';

  @override
  String get warmup_imageEditor => '画像エディタを初期化しています...';

  @override
  String get warmup_database => '最近の履歴を読み込んでいます...';

  @override
  String get warmup_network => 'ネットワーク接続を確認しています...';

  @override
  String get warmup_fonts => 'フォントをプリロードしています...';

  @override
  String get warmup_imageCache => '画像キャッシュをウォームアップしています...';

  @override
  String get warmup_statistics => '統計を読み込んでいます...';

  @override
  String get warmup_artistsSync => 'アーティスト データを同期しています...';

  @override
  String get warmup_subscription => 'サブスクリプション情報を読み込み中...';

  @override
  String get warmup_dataSourceCache => 'データ ソース キャッシュを初期化しています...';

  @override
  String get warmup_galleryFileCount => 'ギャラリー ファイルをスキャンしています...';

  @override
  String get warmup_cooccurrenceData => 'タグ共起データをロードしています...';

  @override
  String get warmup_retryFailed => '失敗したタスクを再試行します';

  @override
  String get warmup_errorDetail => 'エラー';

  @override
  String get warmup_group_basicUI => '基本的な UI サービスを初期化しています...';

  @override
  String get warmup_group_basicUI_complete => '基本的な UI サービスの準備が完了しました';

  @override
  String get warmup_group_dataServices => 'データ サービスを初期化しています...';

  @override
  String get warmup_group_dataServices_complete => 'データ サービスの準備が完了しました';

  @override
  String get warmup_group_networkServices => 'ネットワーク サービスを初期化しています...';

  @override
  String get warmup_group_networkServices_complete => 'ネットワーク サービスの準備が完了しました';

  @override
  String get warmup_group_cacheServices => 'キャッシュ サービスを初期化しています...';

  @override
  String get warmup_group_cacheServices_complete => 'キャッシュ サービスの準備が完了しました';

  @override
  String get warmup_cooccurrenceInit => '共起データを初期化しています...';

  @override
  String get warmup_translationInit => '翻訳データを初期化しています...';

  @override
  String get warmup_danbooruTagsInit => 'Danbooru タグを初期化しています...';

  @override
  String get warmup_dataMigration => 'Hive / Vibe / 画像データを移行しています...';

  @override
  String get warmup_galleryDataSource => 'ギャラリー インデックスを初期化しています...';

  @override
  String get warmup_checkAndRecoverData => 'データの整合性をチェックしています...';

  @override
  String get warmup_group_dataSourceInitialization =>
      'データ ソース サービスを初期化しています...';

  @override
  String get warmup_group_dataSourceInitialization_complete =>
      'データ ソース サービスの準備が完了しました';

  @override
  String warmup_fetchingTags(Object message) {
    return 'タグを同期しています: $message';
  }

  @override
  String get warmup_fetchingTagDataFromServer => 'サーバーからタグデータを取得しています...';

  @override
  String get warmup_fetchingGeneralTags => '一般タグを取得しています...';

  @override
  String get warmup_fetchingCharacterTags => 'キャラクタータグを取得しています...';

  @override
  String get warmup_fetchingCopyrightTags => '作品タグを取得しています...';

  @override
  String get warmup_fetchingMetaTags => 'メタタグを取得しています...';

  @override
  String get performanceReport_title => '起動パフォーマンス';

  @override
  String get performanceReport_export => 'レポートのエクスポート';

  @override
  String get performanceReport_taskStats => 'タスク統計';

  @override
  String get performanceReport_averageDuration => '平均継続時間';

  @override
  String get performanceReport_successRate => '成功率';

  @override
  String get performanceReport_exportSuccess => 'レポートは正常にエクスポートされました';

  @override
  String get performanceReport_noDataTitle => 'パフォーマンス データがありません';

  @override
  String get performanceReport_noDataSubtitle => 'ウォームアップが完了すると、統計がここに表示されます';

  @override
  String get performanceReport_overallStats => '全体的な統計';

  @override
  String get performanceReport_warmupCount => 'ウォームアップの実行';

  @override
  String get performanceReport_totalTasks => '合計タスク数';

  @override
  String get performanceReport_averageTotalDuration => '平均合計所要時間';

  @override
  String get copyName => ' (コピー)';

  @override
  String get defaultPreset_name => 'デフォルトのプリセット';

  @override
  String get defaultPreset_quality => '品質';

  @override
  String get defaultPreset_character => 'キャラクター';

  @override
  String get defaultPreset_expression => '式';

  @override
  String get defaultPreset_clothing => '衣類';

  @override
  String get defaultPreset_action => 'アクション';

  @override
  String get defaultPreset_background => '背景';

  @override
  String get defaultPreset_shot => 'ショット';

  @override
  String get defaultPreset_composition => '構成';

  @override
  String get defaultPreset_specialStyle => '特別なスタイル';

  @override
  String get resolution_groupNormal => '正常';

  @override
  String get resolution_groupLarge => 'ラージ';

  @override
  String get resolution_groupWallpaper => '壁紙';

  @override
  String get resolution_groupSmall => '小';

  @override
  String get resolution_groupCustom => 'カスタム';

  @override
  String get resolution_typePortrait => '縦長';

  @override
  String get resolution_typeLandscape => '横長';

  @override
  String get resolution_typeSquare => 'スクエア';

  @override
  String get resolution_typeCustom => 'カスタム';

  @override
  String get resolution_width => '幅';

  @override
  String get resolution_height => '高さ';

  @override
  String get api_error_429 => '同時実行制限に達しました';

  @override
  String get api_error_429_hint =>
      'リクエストが多すぎます。しばらく待ってからもう一度お試しください (共有アカウントの場合に共通)';

  @override
  String get api_error_401 => '認証に失敗しました';

  @override
  String get api_error_401_hint => 'トークンが無効か、期限切れです。再度ログインしてください';

  @override
  String get api_error_402 => '残高が不足しています';

  @override
  String get api_error_402_hint => 'Anlas が不足しています。補充してもう一度お試しください';

  @override
  String get api_error_500 => 'サーバーエラー';

  @override
  String get api_error_500_hint => 'NovelAI サーバー エラー。後でもう一度試してください';

  @override
  String get api_error_503 => 'サービスが利用できません';

  @override
  String get api_error_503_hint => 'サーバーはメンテナンス中か過負荷状態です。後でもう一度試してください';

  @override
  String get api_error_timeout => 'リクエストのタイムアウト';

  @override
  String get api_error_timeout_hint => 'ネットワークタイムアウト。接続を確認してもう一度お試しください';

  @override
  String get api_error_network => 'ネットワークエラー';

  @override
  String get api_error_network_hint => 'サーバーに接続できません。ネットワークを確認してください';

  @override
  String get api_error_unknown => '不明なエラー';

  @override
  String api_error_unknown_hint(Object error) {
    return '不明なエラーが発生しました: $error';
  }

  @override
  String get drop_dialogTitle => 'この画像はどのように使用しますか?';

  @override
  String get drop_hint => 'ここに画像をドロップしてください';

  @override
  String get drop_processing => '画像を処理しています...';

  @override
  String get drop_processingSubtitle => 'お待ちください';

  @override
  String get drop_img2img => 'Image2Image';

  @override
  String get drop_reversePrompt => '逆プロンプト';

  @override
  String get drop_vibeTransfer => 'バイブストランスファー';

  @override
  String get drop_characterReference => '精密参照';

  @override
  String get drop_unsupportedFormat => 'サポートされていないファイル形式です';

  @override
  String get drop_addedToImg2Img => 'Image2Image に追加しました';

  @override
  String get drop_addedToReversePrompt => 'リバースプロンプトに追加されました';

  @override
  String get drop_addedToVibe => 'バイブストランスファーに追加しました';

  @override
  String drop_addedMultipleToVibe(int count) {
    return '$count 件のバイブストランスファー参照を追加しました';
  }

  @override
  String get drop_addedToCharacterRef => '精密参照に追加しました';

  @override
  String get characterEditor_title => '複数キャラクタープロンプト';

  @override
  String get characterEditor_close => '閉じる';

  @override
  String get characterEditor_dock => 'ドック';

  @override
  String get characterEditor_undock => 'ドッキング解除';

  @override
  String get characterEditor_dockedHint => 'キャラクターパネルが画像領域にドッキングされています';

  @override
  String get characterEditor_confirm => '確認';

  @override
  String get characterEditor_clearAll => 'すべてクリア';

  @override
  String get characterEditor_clearAllTitle => 'すべてのキャラクターをクリア';

  @override
  String get characterEditor_clearAllConfirm =>
      'すべてのキャラクターを削除しますか？この操作は元に戻せません。';

  @override
  String get characterEditor_tabList => 'キャラクターリスト';

  @override
  String get characterEditor_tabDetail => 'キャラクター詳細';

  @override
  String get characterEditor_globalAiChoice => 'AI のグローバルな地位';

  @override
  String get characterEditor_globalAiChoiceHint =>
      '有効にすると、AI がすべてのキャラクターの位置を自動的に決定します';

  @override
  String get characterEditor_emptyTitle => 'キャラクターを選択してください';

  @override
  String get characterEditor_emptyHint => 'リストから選択するか、新しいキャラクターを追加してください';

  @override
  String get characterEditor_noCharacters => 'キャラクターなし';

  @override
  String get characterEditor_addCharacterHint =>
      'キャラクターを追加するには上のボタンをクリックしてください';

  @override
  String get characterEditor_deleteTitle => 'キャラクターの削除';

  @override
  String get characterEditor_deleteConfirm => 'このキャラクターを削除しますか？この操作は元に戻せません。';

  @override
  String get characterEditor_name => '名前';

  @override
  String get characterEditor_nameHint => 'キャラクター名を入力してください';

  @override
  String get characterEditor_enabled => '有効';

  @override
  String get characterEditor_promptHint => 'このキャラクターのプロンプトを入力してください...';

  @override
  String get characterEditor_negativePromptHint =>
      'このキャラクターの除外したい要素を入力してください...';

  @override
  String get characterEditor_position => '位置';

  @override
  String get characterEditor_genderFemale => '女性';

  @override
  String get characterEditor_genderMale => '男性';

  @override
  String get characterEditor_genderOther => 'その他';

  @override
  String get characterEditor_genderFemaleHint => '女性 (追加時に選択)';

  @override
  String get characterEditor_genderMaleHint => '男性(追加時に選択)';

  @override
  String get characterEditor_genderOtherHint => 'その他（追加時に選択）';

  @override
  String get characterEditor_addFemale => 'F';

  @override
  String get characterEditor_addMale => 'M';

  @override
  String get characterEditor_addOther => 'その他';

  @override
  String get characterEditor_addFromLibrary => 'ライブラリ';

  @override
  String get characterEditor_editCharacter => 'キャラクターの編集';

  @override
  String get characterEditor_moveUp => '上に移動';

  @override
  String get characterEditor_moveDown => '下に移動';

  @override
  String get characterEditor_aiChoice => 'AI';

  @override
  String get characterEditor_positionLabel => '位置:';

  @override
  String get characterEditor_positionHint => '画像内のキャラクター位置を選択してください';

  @override
  String get characterEditor_promptLabel => 'プロンプト:';

  @override
  String get characterEditor_disabled => '[無効]';

  @override
  String characterEditor_characterCount(Object count) {
    return '$count キャラクター';
  }

  @override
  String characterEditor_characterCountWithEnabled(
    Object enabled,
    Object total,
  ) {
    return '$enabled/$total キャラクター';
  }

  @override
  String characterEditor_tooltipWithCount(Object count) {
    return '複数キャラクタープロンプト ($count キャラクター)';
  }

  @override
  String get characterEditor_clickToEdit => 'クリックして複数キャラクタープロンプトを編集します';

  @override
  String get toolbar_randomPrompt => 'ランダムなプロンプト';

  @override
  String get randomPromptToolsHiddenHint => 'ランダムプロンプトツールは設定で非表示になっています';

  @override
  String get toolbar_fullscreenEdit => 'フルスクリーン編集';

  @override
  String get toolbar_clear => 'クリア';

  @override
  String get toolbar_confirmClear => 'クリアの確認';

  @override
  String get toolbar_settings => '設定';

  @override
  String get characterTooltip_noCharacters => 'キャラクターが設定されていません';

  @override
  String get characterTooltip_clickToConfig => 'クリックして複数キャラクタープロンプトを設定します';

  @override
  String get characterTooltip_globalAiLabel => 'グローバル AI のポジション:';

  @override
  String get characterTooltip_enabled => '有効';

  @override
  String get characterTooltip_disabled => '無効';

  @override
  String get characterTooltip_positionAi => 'AI';

  @override
  String get characterTooltip_disabledLabel => '無効';

  @override
  String get characterTooltip_promptLabel => 'プロンプト';

  @override
  String get characterTooltip_negativeLabel => '除外したい要素';

  @override
  String get characterTooltip_notSet => '未設定';

  @override
  String characterTooltip_summary(Object total, Object enabled) {
    return '$total キャラクター ($enabled 有効)';
  }

  @override
  String get characterTooltip_viewFullConfig => 'クリックすると完全な構成が表示されます';

  @override
  String get tagLibrary_title => 'タグ ライブラリ';

  @override
  String tagLibrary_tagCount(Object count) {
    return '$count タグが読み込まれました';
  }

  @override
  String get tagLibrary_usingBuiltin => '組み込みライブラリの使用';

  @override
  String tagLibrary_lastSync(Object time) {
    return '最終同期: $time';
  }

  @override
  String get tagLibrary_neverSynced => '同期されていません';

  @override
  String get tagLibrary_syncNow => 'Danbooru から同期';

  @override
  String get tagLibrary_syncing => '同期中...';

  @override
  String get tagLibrary_syncSuccess => 'ライブラリは正常に同期されました';

  @override
  String get tagLibrary_syncFailed => '同期に失敗しました。ネットワーク接続を確認してください';

  @override
  String get tagLibrary_networkError =>
      'Danbooru に接続できません。ネットワークまたはプロキシ設定を確認してください。';

  @override
  String get tagLibrary_autoSync => '自動同期';

  @override
  String get tagLibrary_autoSyncHint => 'Danbooru から定期的に更新します';

  @override
  String get tagLibrary_syncInterval => '同期間隔';

  @override
  String get tagLibrary_dataRange => 'データ範囲';

  @override
  String get tagLibrary_dataRangeHint => '範囲が広いほど同期時間は長くなりますが、タグの数も多くなります';

  @override
  String get tagLibrary_dataRangePopular => '人気 (>1000)';

  @override
  String get tagLibrary_dataRangeMedium => '中 (>500)';

  @override
  String get tagLibrary_dataRangeFull => 'フル (>100)';

  @override
  String tagLibrary_syncIntervalDays(Object days) {
    return '$days 日';
  }

  @override
  String tagLibrary_generatedCharacters(Object count) {
    return '$count キャラクターを生成しました';
  }

  @override
  String tagLibrary_generateFailed(Object error) {
    return '生成に失敗しました: $error';
  }

  @override
  String get randomMode_title => 'ランダム モードを選択';

  @override
  String get randomMode_naiOfficial => '公式モード';

  @override
  String get randomMode_custom => 'カスタムモード';

  @override
  String get randomMode_hybrid => 'ハイブリッド モード';

  @override
  String get randomMode_naiOfficialDesc => 'NovelAI 公式ランダム アルゴリズムを複製する';

  @override
  String get randomMode_customDesc => 'カスタム プリセットを使用して生成';

  @override
  String get randomMode_hybridDesc => '公式アルゴリズムとカスタム プリセットを組み合わせる';

  @override
  String get randomMode_naiIndicator => 'NAI';

  @override
  String get randomMode_customIndicator => 'カスタム';

  @override
  String get naiMode_title => 'デフォルトモード';

  @override
  String get naiMode_subtitle => 'NovelAI の公式ランダム アルゴリズムを複製する';

  @override
  String get naiMode_syncLibrary => '拡張ライブラリの管理';

  @override
  String get manageLibrary => 'ライブラリの管理';

  @override
  String get naiMode_algorithmInfo => 'アルゴリズム情報';

  @override
  String naiMode_tagCountBadge(Object count) {
    return '$count タグ';
  }

  @override
  String naiMode_totalTags(Object count) {
    return 'タグ: $count';
  }

  @override
  String naiMode_lastSync(Object time) {
    return '同期しました: $time';
  }

  @override
  String get naiMode_lastSyncLabel => '最終同期';

  @override
  String get timeAgo_justNow => 'たった今';

  @override
  String timeAgo_minutes(Object count) {
    return '$count 分前';
  }

  @override
  String timeAgo_hours(Object count) {
    return '$count時間前';
  }

  @override
  String timeAgo_days(Object count) {
    return '$count日前';
  }

  @override
  String naiMode_dataRange(Object range) {
    return '範囲: $range';
  }

  @override
  String get naiMode_preview => 'プレビュー';

  @override
  String get naiMode_createCustom => 'カスタム プリセットの作成';

  @override
  String naiMode_categoryProbability(Object probability) {
    return '$probability%';
  }

  @override
  String naiMode_tagCount(Object count) {
    return '$count タグ';
  }

  @override
  String get naiMode_readOnlyHint => '公式アルゴリズムに基づくランダムなプロンプト構成';

  @override
  String promptConfig_confirmRemoveGroup(Object name) {
    return 'グループ「$name」を削除してもよろしいですか?';
  }

  @override
  String promptConfig_confirmRemoveCategory(Object name) {
    return 'カテゴリ「$name」を削除してもよろしいですか?ランダム生成には参加しなくなります。';
  }

  @override
  String get promptConfig_groupList => 'グループリスト';

  @override
  String promptConfig_groupCount(Object count) {
    return '$count グループ';
  }

  @override
  String get promptConfig_addGroup => 'グループを追加';

  @override
  String get promptConfig_noGroups => 'まだグループがありません。[グループを追加] をクリックして作成します';

  @override
  String get promptConfig_builtinLibrary => 'NAI 組み込みライブラリ';

  @override
  String get promptConfig_customGroup => 'カスタム グループ';

  @override
  String get promptConfig_danbooruTagGroup => 'Danbooru タググループ';

  @override
  String get promptConfig_danbooruPool => 'Danbooru プール';

  @override
  String get promptConfig_categorySettings => 'カテゴリ設定';

  @override
  String get promptConfig_enableCategory => 'カテゴリを有効にする';

  @override
  String get promptConfig_disableCategory => 'カテゴリを無効にする';

  @override
  String get naiMode_noLibrary => 'ライブラリがロードされていません';

  @override
  String get naiMode_noCategories =>
      'カテゴリがありません。プリセットをリセットするか、新しいカテゴリを追加してください。';

  @override
  String get naiMode_noTags => 'タグがありません';

  @override
  String get naiMode_previewResult => 'プレビュー結果';

  @override
  String get naiMode_characterPrompts => 'キャラクタープロンプト';

  @override
  String get naiMode_character => 'キャラクター';

  @override
  String get naiMode_createCustomTitle => 'カスタム プリセットの作成';

  @override
  String get naiMode_createCustomDesc =>
      'これにより、すべての NAI カテゴリを含む新しいプリセットが作成され、カスタマイズできます。';

  @override
  String get naiMode_featureComingSoon => '機能は近日公開予定です...';

  @override
  String get naiMode_danbooruToggleTooltip => 'このカテゴリの拡張タグを切り替えます';

  @override
  String get naiMode_danbooruSupplementLabel => '拡張タグ';

  @override
  String get naiMode_danbooruMasterToggleTooltip => 'すべてのカテゴリの拡張タグを切り替えます';

  @override
  String naiMode_entrySubtitle(Object count) {
    return '$count タグ · 公式アルゴリズムを複製';
  }

  @override
  String get naiAlgorithm_title => 'NAI ランダム アルゴリズム';

  @override
  String get naiAlgorithm_characterCount => 'キャラクター数の分布';

  @override
  String get naiAlgorithm_categoryProbability => 'カテゴリ選択確率';

  @override
  String get naiAlgorithm_weightedRandom => '加重ランダム アルゴリズム';

  @override
  String get naiAlgorithm_weightedRandomDesc =>
      '各タグの重みは、Danbooru の使用数に基づいています。重みが大きいほど、選択確率が高くなります。';

  @override
  String get naiAlgorithm_v4MultiCharacter => 'V4 マルチキャラクター';

  @override
  String get naiAlgorithm_v4Desc =>
      'V4 モデルは、メイン プロンプトとキャラクター プロンプトを分離し、各キャラクターの独立したプロンプトをサポートします。';

  @override
  String get naiAlgorithm_mainPrompt => 'メイン プロンプト';

  @override
  String get naiAlgorithm_mainPromptTags => 'キャラクター数、背景、スタイル';

  @override
  String get naiAlgorithm_characterPrompt => 'キャラクタープロンプト';

  @override
  String get naiAlgorithm_characterPromptTags => '髪の色、目の色、髪型、表情、ポーズ';

  @override
  String get naiAlgorithm_noHuman => '人間のシーンはありません';

  @override
  String get naiAlgorithm_noHumanDesc =>
      '5% の確率で人間のいない、背景、シーン、スタイル タグのみを含むシーンが生成されます。';

  @override
  String get naiAlgorithm_background => '背景';

  @override
  String get naiAlgorithm_hairColor => '髪の色';

  @override
  String get naiAlgorithm_eyeColor => '目の色';

  @override
  String get naiAlgorithm_expression => '式';

  @override
  String get naiAlgorithm_hairStyle => 'ヘアスタイル';

  @override
  String get naiAlgorithm_pose => 'ポーズ';

  @override
  String get naiAlgorithm_style => 'スタイル';

  @override
  String get naiAlgorithm_clothing => '衣類';

  @override
  String get naiAlgorithm_accessory => 'アクセサリ';

  @override
  String get naiAlgorithm_scene => 'シーン';

  @override
  String get naiAlgorithm_bodyFeature => 'ボディの特徴';

  @override
  String get importNai_title => 'NAI ライブラリからインポート';

  @override
  String get importNai_selectCategories => 'インポートするカテゴリを選択してください';

  @override
  String importNai_import(Object count) {
    return '$count カテゴリをインポートします';
  }

  @override
  String importNai_tagCount(Object count) {
    return '$count タグ';
  }

  @override
  String get tagLibrary_rangePopular => '人気';

  @override
  String get tagLibrary_rangeMedium => '中';

  @override
  String get tagLibrary_rangeFull => 'フル';

  @override
  String tagLibrary_daysAgo(Object days) {
    return '$days 日前';
  }

  @override
  String tagLibrary_hoursAgo(Object hours) {
    return '$hours 時間前';
  }

  @override
  String get tagLibrary_justNow => 'たった今';

  @override
  String get tagLibrary_danbooruSupplement => 'Danbooru 補足';

  @override
  String get tagLibrary_danbooruSupplementHint =>
      'Danbooru から追加のタグを取得してライブラリを補足します';

  @override
  String get tagLibrary_libraryComposition => 'ライブラリ構成';

  @override
  String get tagLibrary_libraryCompositionDesc =>
      'NAI 公式固定ライブラリ + 拡張タグ (オプション)';

  @override
  String get poolMapping_title => 'プールのマッピング';

  @override
  String get poolMapping_enableSync => 'プールの同期を有効にする';

  @override
  String get poolMapping_enableSyncDesc => 'Danbooru プールからタグを抽出してカテゴリを補完します';

  @override
  String get poolMapping_addMapping => 'プール マッピングの追加';

  @override
  String get poolMapping_noMappings => 'プール マッピングがありません';

  @override
  String get poolMapping_noMappingsHint => '上のボタンをクリックして Danbooru プールを追加します';

  @override
  String get poolMapping_searchPool => '検索プール';

  @override
  String get poolMapping_searchHint => 'プール名のキーワードを入力してください';

  @override
  String get poolMapping_targetCategory => '対象カテゴリ';

  @override
  String get poolMapping_selectPool => 'プールの選択';

  @override
  String get poolMapping_syncPools => '同期プール';

  @override
  String get poolMapping_syncing => '同期中...';

  @override
  String get poolMapping_neverSynced => '同期されていません';

  @override
  String get poolMapping_syncSuccess => 'プールの同期が成功しました';

  @override
  String get poolMapping_syncFailed => 'プールの同期に失敗しました';

  @override
  String get poolMapping_noResults => '一致するプールが見つかりませんでした';

  @override
  String get poolMapping_poolExists => 'このプールはすでに追加されています';

  @override
  String get poolMapping_addSuccess => 'プール マッピングが正常に追加されました';

  @override
  String get poolMapping_removeConfirm => 'このプール マッピングを削除してもよろしいですか?';

  @override
  String get poolMapping_removeSuccess => 'プール マッピングが削除されました';

  @override
  String poolMapping_tagCount(Object count) {
    return '$count タグ';
  }

  @override
  String poolMapping_postCount(Object count) {
    return '$count 投稿';
  }

  @override
  String get poolMapping_alreadyAdded => '追加';

  @override
  String get poolMapping_resetToDefault => 'デフォルトにリセット';

  @override
  String get poolMapping_resetConfirm =>
      'デフォルトのプール マッピングにリセットしてもよろしいですか?現在の設定は上書きされます。';

  @override
  String get poolMapping_resetSuccess => 'デフォルト構成にリセット';

  @override
  String get tagGroup_title => 'タググループの同期';

  @override
  String get tagGroup_enableSync => 'タググループの同期を有効にする';

  @override
  String get tagGroup_enableSyncDesc => 'Danbooru タグ グループからタグ データを取得します';

  @override
  String get tagGroup_mappingTitle => 'タググループのマッピング';

  @override
  String get tagGroup_addMapping => 'マッピングを追加';

  @override
  String get tagGroup_noMappings => 'タググループマッピングがありません';

  @override
  String get tagGroup_noMappingsHint => '上のボタンをクリックしてタグ グループを参照して追加します';

  @override
  String get tagGroup_searchHint => 'タグ グループを検索...';

  @override
  String get tagGroup_targetCategory => '対象カテゴリ';

  @override
  String get tagGroup_selectGroup => 'タググループの選択';

  @override
  String get tagGroup_neverSynced => '同期されていません';

  @override
  String get tagGroup_noResults => '一致するタグ グループが見つかりませんでした';

  @override
  String get tagGroup_groupExists => 'このタググループはすでに追加されています';

  @override
  String get tagGroup_addSuccess => 'タグ グループ マッピングが正常に追加されました';

  @override
  String get tagGroup_removeConfirm => 'このタグ グループ マッピングを削除してもよろしいですか?';

  @override
  String get tagGroup_removeSuccess => 'タググループマッピングが削除されました';

  @override
  String tagGroup_tagCount(Object count) {
    return '$count タグ';
  }

  @override
  String tagGroup_childCount(Object count) {
    return '$count サブグループ';
  }

  @override
  String get tagGroup_alreadyAdded => '追加';

  @override
  String get tagGroup_resetToDefault => 'デフォルトにリセット';

  @override
  String get tagGroup_resetConfirm =>
      'デフォルトのタググループマッピングにリセットしてもよろしいですか?現在の設定は上書きされます。';

  @override
  String get tagGroup_resetSuccess => 'デフォルト構成にリセット';

  @override
  String get tagGroup_minPostCount => '最小投稿数';

  @override
  String tagGroup_postCountValue(Object count) {
    return '$count 件の投稿';
  }

  @override
  String get tagGroup_minPostCountHint => 'このしきい値を超える投稿数を持つタグのみを同期します';

  @override
  String get tagGroup_preview => 'タグのプレビュー';

  @override
  String tagGroup_previewCount(Object count) {
    return '$count タグをプレビューする';
  }

  @override
  String get tagGroup_selectToPreview => 'プレビューを表示するにはタグ グループを選択してください';

  @override
  String get tagGroup_noTagsInGroup => 'このグループにはタグがありません';

  @override
  String tagGroup_andMore(Object count) {
    return 'および $count その他...';
  }

  @override
  String get tagGroup_options => 'オプション';

  @override
  String get tagGroup_includeChildren => 'サブグループタグを含める';

  @override
  String get tagGroup_includesChildren => 'サブグループを含む';

  @override
  String get tagGroup_syncPreparing => '同期を準備しています...';

  @override
  String tagGroup_syncFetching(Object name, Object current, Object total) {
    return '$name を取得中... ($current/$total)';
  }

  @override
  String tagGroup_syncFiltering(Object total, Object filtered) {
    return 'フィルタリング: $total タグ、$filtered タグを保持';
  }

  @override
  String tagGroup_syncCompleted(Object count) {
    return '同期が完了しました。タグの合計は $count 個です';
  }

  @override
  String tagGroup_syncFailed(Object error) {
    return '同期に失敗しました: $error';
  }

  @override
  String tagGroup_addTo(Object category) {
    return '追加先: $category';
  }

  @override
  String get tagGroup_refresh => 'リストを更新';

  @override
  String get tagGroup_loadingFromDanbooru => 'Danbooru からタグ グループをロードしています...';

  @override
  String get tagGroup_loadFailed => 'タグ グループのロードに失敗しました。ネットワーク接続を確認してください。';

  @override
  String tagGroup_loadError(Object error) {
    return 'ロードに失敗しました: $error';
  }

  @override
  String get tagGroup_reload => 'リロード';

  @override
  String get tagGroup_searchHintAlt => 'または、検索を使用して特定のグループを見つけます';

  @override
  String get tagGroup_selected => '選択済み';

  @override
  String get tagGroup_manageGroups => 'グループの管理';

  @override
  String get tagGroup_manageGroupsHint => '同期するタグ グループを選択してください';

  @override
  String tagGroup_selectedCount(Object count) {
    return '選択された $count グループ';
  }

  @override
  String get naiMode_syncCategory => '同期カテゴリ';

  @override
  String get naiMode_syncCategoryTooltip => 'このカテゴリのみの拡張タグを同期します';

  @override
  String get naiMode_viewDetails => '詳細を見る';

  @override
  String get naiMode_tagListTitle => 'タグリスト';

  @override
  String get naiMode_desc_hairColor => 'キャラクターの髪の色を記述するための髪色タグ';

  @override
  String get naiMode_desc_eyeColor => 'キャラクターの目の色を記述するための目の色タグ';

  @override
  String get naiMode_desc_hairStyle => 'キャラクターの髪型を記述するための髪型タグ';

  @override
  String get naiMode_desc_expression => '表情を記述するための式タグ';

  @override
  String get naiMode_desc_pose => '体の姿勢と動作を説明するためのポーズタグ';

  @override
  String get naiMode_desc_clothing => '服装を説明するための衣類タグ';

  @override
  String get naiMode_desc_accessory => '装飾やアクセサリーを説明するためのアクセサリータグ';

  @override
  String get naiMode_desc_bodyFeature => '身体の特徴を記述するための身体特徴タグ';

  @override
  String get naiMode_desc_background => '背景の種類を記述するための背景タグ';

  @override
  String get naiMode_desc_scene => 'シーン要素を記述するためのシーンタグ';

  @override
  String get naiMode_desc_style => 'アート スタイルを記述するためのスタイル タグ';

  @override
  String get naiMode_desc_characterCount => 'キャラクター数を決定するためのキャラクター数タグ';

  @override
  String get tagGroup_builtin => '内蔵';

  @override
  String tagGroup_totalTagsTooltip(Object original, Object filtered) {
    return '元: $original / フィルタ済み: $filtered';
  }

  @override
  String get tagGroup_cacheDetails => 'キャッシュの詳細';

  @override
  String get tagGroup_cachedCategories => 'キャッシュされたカテゴリ';

  @override
  String get cache_title => '単語グループ';

  @override
  String get cache_manage => '単語グループ';

  @override
  String get cache_tabTagGroup => 'タググループ';

  @override
  String get cache_tabPool => 'プール';

  @override
  String get cache_noTagGroups => 'タグ グループ キャッシュがありません';

  @override
  String get cache_noPools => 'プール キャッシュがありません';

  @override
  String get cache_noBuiltin => '内蔵辞書はありません';

  @override
  String get cache_probability => '確率';

  @override
  String get cache_tags => 'タグ';

  @override
  String get cache_posts => '投稿';

  @override
  String get cache_neverSynced => '同期されていません';

  @override
  String get cache_refresh => '更新';

  @override
  String cache_refreshFailed(String error) {
    return '更新に失敗しました: $error';
  }

  @override
  String get cache_refreshAll => 'すべて更新';

  @override
  String cache_refreshProgress(Object current, Object total, String name) {
    return '同期中 ($current/$total): $name';
  }

  @override
  String cache_totalStats(Object count, Object tags) {
    return '$count グループ、合計 $tags タグ';
  }

  @override
  String get addGroup_fetchingCache => 'データを取得しています...';

  @override
  String get addGroup_fetchFailed => 'データの取得に失敗しましたが、グループを追加することはできます';

  @override
  String get addGroup_syncFailed => '同期に失敗しました。ネットワーク接続を確認して再試行してください。';

  @override
  String addGroup_addFailed(String error) {
    return '追加に失敗しました: $error';
  }

  @override
  String get addGroup_addCustom => 'カスタムを追加';

  @override
  String get addGroup_filterHint => 'キャッシュされたグループを検索します...';

  @override
  String get customGroup_title => 'カスタム グループの追加';

  @override
  String get customGroup_searchHint => '検索するキーワードを入力してください Danbooru...';

  @override
  String get customGroup_nameLabel => '表示名';

  @override
  String get customGroup_add => '追加とキャッシュ';

  @override
  String get customGroup_searchPrompt => 'キーワードを入力して検索してください';

  @override
  String get tagGroup_noCachedData => 'キャッシュされたデータがありません';

  @override
  String get tagGroup_syncRequired => '同期が必要です';

  @override
  String get tagGroup_notSynced => '同期されていません';

  @override
  String get tagGroup_lastSyncTime => '最終同期';

  @override
  String get tagGroup_heatThreshold => '熱閾値';

  @override
  String get tagGroup_totalStats => '合計';

  @override
  String tagGroup_syncedCount(Object synced, Object total) {
    return '$synced/$total 同期しました';
  }

  @override
  String addGroup_dialogTitle(Object category) {
    return '「$category」の辞書を追加';
  }

  @override
  String get addGroup_builtinTab => '内蔵';

  @override
  String get addGroup_tagGroupTab => 'タググループ';

  @override
  String get addGroup_cancel => 'キャンセル';

  @override
  String get addGroup_submit => '追加';

  @override
  String get addGroup_builtinEnabled => '内蔵辞書が有効になりました';

  @override
  String get addGroup_builtinEnabledDesc => 'このカテゴリの組み込み辞書はすでに使用されています';

  @override
  String get addGroup_enableBuiltin => '内蔵辞書を有効にする';

  @override
  String get addGroup_enableBuiltinDesc => 'アプリの組み込みタグ辞書を使用する';

  @override
  String get addGroup_enable => '有効にする';

  @override
  String get addGroup_backToParent => '戻る';

  @override
  String get addGroup_browseMode => 'キャッシュされたリスト';

  @override
  String get addGroup_customMode => 'その他を追加';

  @override
  String get addGroup_allCategories => 'すべてのカテゴリ';

  @override
  String get addGroup_noMoreSubcategories => 'サブカテゴリはもうありません';

  @override
  String addGroup_tagGroupCount(Object count) {
    return '$count タグ グループ';
  }

  @override
  String get addGroup_customInputHint =>
      'Danbooru タググループのタイトルを入力します。例: Hair_color';

  @override
  String get addGroup_groupTitleLabel => 'タググループのタイトル *';

  @override
  String get addGroup_groupTitleHint => '例:hair_color または tag_group:hair_color';

  @override
  String get addGroup_displayNameLabel => '表示名 (オプション)';

  @override
  String get addGroup_displayNameHint => 'タイトルを使用するには空のままにしてください';

  @override
  String get addGroup_targetCategoryLabel => '対象カテゴリ';

  @override
  String get addGroup_includeChildren => 'サブグループを含める';

  @override
  String get addGroup_includeChildrenDesc => 'このタグ グループのすべてのサブグループからもタグを取得します';

  @override
  String get addGroup_errorEmptyTitle => 'タググループのタイトルを入力してください';

  @override
  String get addGroup_errorGroupExists => 'このタグ グループはすでに存在します';

  @override
  String get addGroup_sourceTypeLabel => 'データ ソース';

  @override
  String get addGroup_poolTab => 'Danbooru プール';

  @override
  String get addGroup_poolSearchLabel => '検索プール';

  @override
  String get addGroup_poolSearchHint => '検索するプール名を入力してください';

  @override
  String get addGroup_poolSearchEmpty => 'キーワードを入力して Danbooru プールを検索してください';

  @override
  String get addGroup_poolSearchError => '検索に失敗しました';

  @override
  String get addGroup_poolNoResults => '一致するプールが見つかりませんでした';

  @override
  String addGroup_poolPostCount(Object count) {
    return '$count 投稿';
  }

  @override
  String get addGroup_noCachedTagGroups => 'キャッシュされたタグ グループがありません';

  @override
  String get addGroup_noCachedTagGroupsHint => 'まずキャッシュ管理でタグ グループ データを同期してください';

  @override
  String get addGroup_noFilterResults => '一致する結果が見つかりませんでした';

  @override
  String get addGroup_noCachedPools => 'キャッシュされたプールがありません';

  @override
  String get addGroup_noCachedPoolsHint => '検索ボックスを使用して Danbooru プールを検索して追加します';

  @override
  String get addGroup_sectionTagGroups => 'タググループ ☁️';

  @override
  String get addGroup_sectionPools => 'プール 🖼️';

  @override
  String get globalSettings_title => '概要設定';

  @override
  String get globalSettings_resetToDefault => 'デフォルトにリセット';

  @override
  String get globalSettings_characterCountDistribution => 'キャラクター数の分布';

  @override
  String get globalSettings_weightRandomOffset => 'ウェイトのランダムオフセット';

  @override
  String get globalSettings_categoryProbabilityOverview => 'カテゴリ確率の概要';

  @override
  String get globalSettings_cancel => 'キャンセル';

  @override
  String get globalSettings_save => '保存';

  @override
  String globalSettings_saveFailed(Object error) {
    return '保存に失敗しました: $error';
  }

  @override
  String get globalSettings_noCharacter => 'なし';

  @override
  String globalSettings_characterCount(Object count) {
    return '$count キャラクター';
  }

  @override
  String get globalSettings_enableWeightRandomOffset => 'ウェイトのランダムオフセットを有効にする';

  @override
  String get globalSettings_enableWeightRandomOffsetDesc =>
      '人間による微調整をシミュレートするために、生成中にブラケットをランダムに追加します';

  @override
  String get globalSettings_bracketType => 'ブラケットのタイプ';

  @override
  String get globalSettings_bracketEnhance => '中括弧の強化';

  @override
  String get globalSettings_bracketWeaken => '[] 弱体化';

  @override
  String get globalSettings_layerRange => 'レイヤー範囲';

  @override
  String globalSettings_layerRangeValue(Object min, Object max) {
    return '$min - $max レイヤー';
  }

  @override
  String get globalSettings_category_hairColor => '髪の色';

  @override
  String get globalSettings_category_eyeColor => '目の色';

  @override
  String get globalSettings_category_hairStyle => 'ヘアスタイル';

  @override
  String get globalSettings_category_expression => '式';

  @override
  String get globalSettings_category_pose => 'ポーズ';

  @override
  String get globalSettings_category_clothing => '衣類';

  @override
  String get globalSettings_category_accessory => 'アクセサリ';

  @override
  String get globalSettings_category_bodyFeature => 'ボディの特徴';

  @override
  String get globalSettings_category_background => '背景';

  @override
  String get globalSettings_category_scene => 'シーン';

  @override
  String get globalSettings_category_style => 'スタイル';

  @override
  String get nav_generate => '生成';

  @override
  String download_completed(Object name) {
    return '$name ダウンロードが完了しました';
  }

  @override
  String import_completed(Object name) {
    return '$name インポートが完了しました';
  }

  @override
  String get sync_preparing => '同期の準備中...';

  @override
  String sync_fetching(Object category) {
    return '$category を取得しています...';
  }

  @override
  String get sync_processing => 'データを処理しています...';

  @override
  String get sync_saving => '保存中...';

  @override
  String sync_completed(Object count) {
    return '同期が完了しました。$count タグ';
  }

  @override
  String sync_failed(Object error) {
    return '同期に失敗しました: $error';
  }

  @override
  String sync_extracting(Object poolName) {
    return '$poolName タグを抽出しています...';
  }

  @override
  String get sync_merging => 'タグを結合しています...';

  @override
  String sync_fetching_tags(Object groupName) {
    return '$groupName タグの人気度を取得しています...';
  }

  @override
  String get sync_filtering => 'タグをフィルタリングしています...';

  @override
  String get sync_done => '同期が完了しました';

  @override
  String get download_tags_data => 'タグ データをダウンロードしています...';

  @override
  String get download_cooccurrence_data => '共起データをダウンロードしています...';

  @override
  String get download_parsing_data => 'データを解析しています...';

  @override
  String get download_readingFile => 'ファイルを読み取り中...';

  @override
  String get download_mergingData => 'データを結合しています...';

  @override
  String get download_loadComplete => '読み込みが完了しました';

  @override
  String get time_just_now => 'ただいま';

  @override
  String time_minutes_ago(Object n) {
    return '$n 分前';
  }

  @override
  String time_hours_ago(Object n) {
    return '$n 時間前';
  }

  @override
  String time_days_ago(Object n) {
    return '$n 日前';
  }

  @override
  String get time_never_synced => '同期されていません';

  @override
  String get selectionMode_single => '単一のランダム';

  @override
  String get selectionMode_multipleNum => '複数のカウント';

  @override
  String get selectionMode_multipleProb => '複数の問題';

  @override
  String get selectionMode_all => 'すべて';

  @override
  String get selectionMode_sequential => 'シーケンシャル';

  @override
  String categorySettings_title(Object name) {
    return 'カテゴリ設定 - $name';
  }

  @override
  String get categorySettings_probability => 'カテゴリの確率';

  @override
  String get categorySettings_probabilityDesc => 'このカテゴリがランダム生成に参加する確率';

  @override
  String get categorySettings_groupSelectionMode => 'グループ選択モード';

  @override
  String get categorySettings_groupSelectionModeDesc => 'サブグループから選択する方法';

  @override
  String get categorySettings_groupSelectCount => '数を選択:';

  @override
  String get categorySettings_shuffle => 'シャッフル順序';

  @override
  String get categorySettings_shuffleDesc => '選択したグループの出力順序をランダムに配置します';

  @override
  String get categorySettings_unifiedBracket => '統合ブラケット';

  @override
  String get categorySettings_unifiedBracketDisabled => '無効';

  @override
  String get categorySettings_enableUnifiedBracket => '統合設定を有効にする';

  @override
  String get categorySettings_enableUnifiedBracketDesc =>
      '有効にすると、各グループの個別のブラケット設定が上書きされます。';

  @override
  String get categorySettings_bracketRange => 'ブラケット層の範囲';

  @override
  String categorySettings_bracketMin(Object count) {
    return '最小: $count レイヤー';
  }

  @override
  String categorySettings_bracketMax(Object count) {
    return '最大: $count レイヤー';
  }

  @override
  String get categorySettings_bracketPreview => 'プレビュー:';

  @override
  String get categorySettings_batchSettings => 'バッチ操作';

  @override
  String get categorySettings_batchSettingsDesc => 'このカテゴリのすべてのグループに対するバッチ操作';

  @override
  String get categorySettings_enableAllGroups => 'すべて有効にする';

  @override
  String get categorySettings_disableAllGroups => 'すべて無効にする';

  @override
  String get categorySettings_resetGroupSettings => 'グループ設定をリセット';

  @override
  String get categorySettings_batchEnableSuccess => 'すべてのグループが有効になりました';

  @override
  String get categorySettings_batchDisableSuccess => 'すべてのグループが無効になりました';

  @override
  String get categorySettings_batchResetSuccess => 'すべてのグループ設定がリセットされました';

  @override
  String tagGroupSettings_title(Object name) {
    return 'グループ設定 - $name';
  }

  @override
  String get tagGroupSettings_probability => '選択確率';

  @override
  String get tagGroupSettings_probabilityDesc => 'このグループが選択される確率';

  @override
  String get tagGroupSettings_selectionMode => '選択モード';

  @override
  String get tagGroupSettings_selectionModeDesc => 'このグループからタグを選択する方法';

  @override
  String get tagGroupSettings_selectCount => '数を選択:';

  @override
  String get tagGroupSettings_shuffle => 'シャッフル順序';

  @override
  String get tagGroupSettings_shuffleDesc => '選択したタグの出力順序をランダムに並べます';

  @override
  String get tagGroupSettings_bracket => 'ウェイト ブラケット';

  @override
  String get tagGroupSettings_bracketDesc =>
      '選択したタグにウェイトブラケットをランダムに追加します。各中括弧でウェイトが約 5% 増加します';

  @override
  String tagGroupSettings_bracketMin(Object count) {
    return '最小: $count レイヤー';
  }

  @override
  String tagGroupSettings_bracketMax(Object count) {
    return '最大: $count レイヤー';
  }

  @override
  String get tagGroupSettings_bracketPreview => 'プレビュー:';

  @override
  String get categorySettings_settingsButton => '設定';

  @override
  String get tagGroupSettings_settingsButton => '設定';

  @override
  String get promptConfig_tagCountUnit => 'タグ';

  @override
  String get promptConfig_removeGroup => 'グループを削除';

  @override
  String get preset_resetToDefault => 'デフォルトにリセット';

  @override
  String get preset_resetConfirmTitle => 'プリセットをリセット';

  @override
  String get preset_resetConfirmMessage =>
      '現在のプリセット内のすべてのカテゴリとグループをデフォルトにリセットしてもよろしいですか?この操作は元に戻すことができません。';

  @override
  String get preset_resetSuccess => 'プリセットがデフォルトにリセットされました';

  @override
  String get newPresetDialog_title => '新しいプリセットを作成';

  @override
  String get newPresetDialog_blank => '完全に空白';

  @override
  String get newPresetDialog_blankDesc => 'プリセット コンテンツを持たずにプリセットを最初から作成します';

  @override
  String get newPresetDialog_template => 'デフォルトのプリセットに基づく';

  @override
  String get newPresetDialog_templateDesc => 'デフォルトのプリセットからすべての設定を開始点としてコピーします';

  @override
  String get category_addNew => 'カテゴリを追加';

  @override
  String get category_dialogTitle => 'カテゴリの作成';

  @override
  String get category_name => '名前';

  @override
  String get category_nameHint => 'カテゴリ名を入力してください';

  @override
  String get category_key => 'キー';

  @override
  String get category_keyHint => '内部識別子';

  @override
  String get category_emoji => 'アイコン';

  @override
  String get category_selectEmoji => '絵文字を選択してください';

  @override
  String get category_probability => '確率';

  @override
  String get category_createSuccess => 'カテゴリが作成されました';

  @override
  String get category_nameRequired => '名前は必須です';

  @override
  String get category_keyRequired => 'キーが必要です';

  @override
  String get category_keyExists => 'このキーはすでに存在します';

  @override
  String get group_selectEmoji => 'アイコンを選択';

  @override
  String get category_noRecentEmoji => '最近の絵文字はありません';

  @override
  String get category_searchEmoji => '絵文字を検索';

  @override
  String get addGroup_customTab => 'カスタム';

  @override
  String get customGroup_groupName => 'グループ名';

  @override
  String get customGroup_entryPlaceholder =>
      'エントリを入力して Enter キーを押します (複数のタグをサポート、カンマ区切り)';

  @override
  String get customGroup_noEntries => 'エントリがまだありません。開始するにはエントリを追加してください';

  @override
  String customGroup_entryCount(Object count) {
    return '$count エントリ';
  }

  @override
  String get customGroup_editEntry => 'エントリーの編集';

  @override
  String get customGroup_aliasLabel => 'エイリアス (オプション)';

  @override
  String get customGroup_aliasHint => '覚えやすいエイリアスを入力してください';

  @override
  String get customGroup_contentLabel => 'プロンプトの内容';

  @override
  String get customGroup_contentHint => '実際のプロンプトの内容を入力してください';

  @override
  String get customGroup_save => '保存';

  @override
  String get customGroup_confirm => '確認';

  @override
  String get customGroup_selectEmoji => 'アイコンを選択';

  @override
  String get customGroup_nameRequired => 'グループ名を入力してください';

  @override
  String get customGroup_addEntry => 'エントリの追加';

  @override
  String get customGroup_noCustomGroups => 'カスタム グループはまだありません';

  @override
  String get customGroup_createInCacheManager => '「グループ マネージャー」でカスタム グループを作成する';

  @override
  String get cache_createCustomGroup => 'カスタム グループの作成';

  @override
  String cache_confirmDeleteCustomGroup(Object name) {
    return 'カスタム グループ「$name」を削除してもよろしいですか?';
  }

  @override
  String get cache_customTab => 'カスタム';

  @override
  String get cache_addFromDanbooru => 'Danbooru から追加';

  @override
  String get customGroup_emptyStateTitle => 'エントリの追加を開始します';

  @override
  String get customGroup_emptyStateHint => '上の入力フィールドに入力し、Enter キーを押して追加します';

  @override
  String get common_comingSoon => '近日公開予定...';

  @override
  String get common_openInBrowser => 'ブラウザで開く';

  @override
  String get customGroup_tagsPlaceholder =>
      'カンマで区切ってタグを入力してください (オートコンプリートがサポートされています)...';

  @override
  String get characterCountConfig_title => 'キャラクター数設定';

  @override
  String get characterCountConfig_weight => 'ウェイト';

  @override
  String get characterCountConfig_solo => 'ソロ';

  @override
  String get characterCountConfig_duo => 'デュオ';

  @override
  String get characterCountConfig_trio => 'トリオ';

  @override
  String get characterCountConfig_noHumans => '人間は存在しません';

  @override
  String get characterCountConfig_multiPerson => '複数人';

  @override
  String get characterCountConfig_customizable => 'カスタマイズ可能';

  @override
  String get characterCountConfig_mainPrompt => 'メイン プロンプト';

  @override
  String get characterCountConfig_characterPrompt => 'キャラクタープロンプト';

  @override
  String get characterCountConfig_addTagOption => 'キャラクタータグを追加';

  @override
  String get characterCountConfig_addMultiPersonCombo => '複数人コンボを追加';

  @override
  String get characterCountConfig_displayName => '表示名';

  @override
  String get characterCountConfig_displayNameHint => '例: トラップ';

  @override
  String get characterCountConfig_mainPromptLabel => 'メイン プロンプト タグ';

  @override
  String get characterCountConfig_mainPromptHint =>
      '例: ソロ、女の子 2 人、女の子 1 人、男の子 1 人';

  @override
  String get characterCountConfig_personCount => '人数:';

  @override
  String get characterCountConfig_slotConfig => 'キャラクタースロット構成';

  @override
  String get characterCountConfig_slot => 'スロット';

  @override
  String get characterCountConfig_resetToDefault => 'デフォルトにリセット';

  @override
  String get characterCountConfig_customSlots => 'カスタム スロット';

  @override
  String get characterCountConfig_customSlotsTitle => 'キャラクタースロット管理';

  @override
  String get characterCountConfig_customSlotsDesc =>
      '利用可能なキャラクター スロット オプションを追加または削除します';

  @override
  String get characterCountConfig_addSlot => 'スロットを追加';

  @override
  String get characterCountConfig_addSlotHint => '例: トラップ 1 つ、フタナリ 1 つ';

  @override
  String get characterCountConfig_slotExists => 'このスロットはすでに存在します';

  @override
  String get characterCountConfig_cannotDeleteBuiltin => '内蔵スロットは削除できません';

  @override
  String get randomManager_algorithmConfig => 'アルゴリズム構成';

  @override
  String get randomManager_characterCountWeight => 'キャラクター数の重み';

  @override
  String get randomManager_genderWeight => '性別の重み';

  @override
  String get randomManager_globalSettings => 'グローバル設定';

  @override
  String get randomManager_enableSeasonalWordlists => '季節の単語リストを有効にする';

  @override
  String get randomManager_enableSeasonalWordlistsDesc =>
      'クリスマス、ハロウィーン、その他の特別な日の単語リスト';

  @override
  String get randomManager_globalEmphasisProbability => 'グローバル強調確率';

  @override
  String get randomManager_soloGenderOptions => 'ソロジェンダーのオプション';

  @override
  String get randomManager_femaleShort => 'F';

  @override
  String get randomManager_maleShort => 'M';

  @override
  String get randomManager_other => 'その他';

  @override
  String get randomManager_tagGroupList => 'タググループ';

  @override
  String get randomManager_deleteTagGroupTitle => 'タググループの削除';

  @override
  String randomManager_deleteTagGroupConfirm(Object name) {
    return 'タグ グループ「$name」を削除しますか?この操作は元に戻すことができません。';
  }

  @override
  String randomManager_tagGroupCount(Object count) {
    return '$count タグ グループ';
  }

  @override
  String get randomManager_categories => 'カテゴリ';

  @override
  String get randomManager_tagGroups => 'タググループ';

  @override
  String get randomManager_tags => 'タグ';

  @override
  String get randomManager_addTagGroup => 'タググループの追加';

  @override
  String get randomManager_locked => 'ロックされました';

  @override
  String get randomManager_addCategory => 'カテゴリを追加';

  @override
  String get randomManager_noCategories => 'カテゴリがありません';

  @override
  String get randomManager_noCategoriesHint => '[カテゴリを追加] をクリックして設定を開始してください';

  @override
  String get randomManager_globalPeopleSettings => 'グローバルキャラクター設定';

  @override
  String get randomManager_closePreview => 'プレビューを閉じる';

  @override
  String get randomManager_importPreset => 'プリセットのインポート';

  @override
  String get randomManager_importPresetSubtitle =>
      'JSON テキストからランダムな構成プリセットをインポートします';

  @override
  String get randomManager_exportCurrentPreset => '現在のプリセットをエクスポート';

  @override
  String get randomManager_noPresetSelected => 'プリセットが選択されていません';

  @override
  String get randomManager_selectPresetFirst => '最初にプリセットを選択してください';

  @override
  String get randomManager_defaultPresetReadonly =>
      'デフォルトのプリセットは読み取り専用です。まずカスタム プリセットを作成またはコピーします。';

  @override
  String randomManager_presetImported(Object name) {
    return 'インポートされたプリセット「$name」';
  }

  @override
  String get randomManager_defaultPresetV4 => 'デフォルト モード (V4)';

  @override
  String get randomManager_defaultPresetLegacy => 'デフォルト モード (レガシー)';

  @override
  String get randomManager_defaultPresetFurry => 'デフォルト モード (毛皮)';

  @override
  String get randomManager_defaultPresetV4Description =>
      'NAI V4 モデルに基づくランダムアルゴリズム設定 (複数キャラクター対応)';

  @override
  String get randomManager_defaultPresetLegacyDescription =>
      'NAI レガシー モデルに基づくランダム アルゴリズム構成';

  @override
  String get randomManager_defaultPresetFurryDescription =>
      'NAI Furry モデルに基づくランダム アルゴリズム構成';

  @override
  String get randomManager_defaultPresetOfficialDescription =>
      'NAI 公式設定に基づくランダム アルゴリズム設定';

  @override
  String get randomManager_femaleClothing => '女性服';

  @override
  String get randomManager_maleClothing => '男性服';

  @override
  String get randomManager_generalClothing => '一般衣料品';

  @override
  String get randomManager_femaleBodyType => '女性の体型';

  @override
  String get randomManager_maleBodyType => '男性の体型';

  @override
  String get randomManager_generalBodyType => '一般的な体型';

  @override
  String get randomManager_soloFemale => '女性';

  @override
  String get randomManager_soloMale => '男性';

  @override
  String get randomManager_duoGirls => '二人の女の子';

  @override
  String get randomManager_duoMixed => '女の子と男の子';

  @override
  String get randomManager_duoBoys => '二人の少年';

  @override
  String get randomManager_trioGirls => '3 人の女の子';

  @override
  String get randomManager_trioTwoGirlsOneBoy => '女の子 2 人と男の子 1 人';

  @override
  String get randomManager_trioOneGirlTwoBoys => '女の子 1 人と男の子 2 人';

  @override
  String get randomManager_trioBoys => '3 人の男の子';

  @override
  String get randomManager_noHumanScene => '人間のいないシーン';

  @override
  String randomManager_presetCreated(Object name) {
    return 'プリセット「$name」を作成しました';
  }

  @override
  String randomManager_deletePresetConfirm(Object name) {
    return '「$name」を削除しますか?これを元に戻すことはできません。';
  }

  @override
  String get randomManager_syncCompleted => 'Danbooru タグが同期されました';

  @override
  String randomManager_syncFailed(Object error) {
    return '同期に失敗しました: $error';
  }

  @override
  String get randomManager_resetDefaultTitle => 'デフォルトにリセット';

  @override
  String get randomManager_resetDefaultContent =>
      '公式のデフォルト構成を復元します。\nカスタム タグ グループは保持されますが、無効になります。';

  @override
  String get randomManager_resetDefaultConfirm => 'リセット';

  @override
  String get randomManager_resetDefaultDone => 'デフォルト構成にリセット';

  @override
  String get randomManager_generatePreview => 'プレビューの生成';

  @override
  String get randomManager_importExport => 'インポート / エクスポート';

  @override
  String get randomManager_syncing => '同期中';

  @override
  String get randomManager_syncingWithEllipsis => '同期中...';

  @override
  String get randomManager_syncDanbooruTags => 'Danbooru タグを同期';

  @override
  String get randomManager_unknownError => '不明なエラー';

  @override
  String get randomManager_readOnlyMode => '読み取り専用モード';

  @override
  String get randomManager_readOnlyTooltip =>
      '現在のプリセットはデフォルトのプリセットであるため、すべての構成項目がロックされています';

  @override
  String get randomManager_searchCategoryOrTagGroup =>
      'カテゴリまたはタグ グループを検索します...';

  @override
  String get randomManager_scope => '範囲';

  @override
  String get randomManager_global => 'グローバル';

  @override
  String get randomManager_private => '非公開';

  @override
  String get randomManager_status => 'ステータス';

  @override
  String get randomManager_enabledOnly => '有効のみ';

  @override
  String get randomManager_diyCapable => 'DIY 機能あり';

  @override
  String randomManager_addTagGroupSubtitle(Object category) {
    return '「$category」に追加';
  }

  @override
  String get randomManager_tagGroupName => 'タググループ名';

  @override
  String get randomManager_tagGroupNameHint => 'タググループ名を入力してください';

  @override
  String get randomManager_tagGroupNameRequired => 'タググループ名を入力してください';

  @override
  String get randomManager_customTab => 'カスタム';

  @override
  String get randomManager_tagList => 'タグリスト';

  @override
  String get randomManager_tagListHelp => '1 行に 1 つのタグ。タグまたはタグ:ウェイトをサポートします。';

  @override
  String get randomManager_searchTagGroup => 'タグ グループを検索...';

  @override
  String get randomManager_searchPool => '検索プール...';

  @override
  String randomManager_itemCount(Object count) {
    return '$count アイテム';
  }

  @override
  String get randomManager_noMatchingTagGroup => '一致するタグ グループが見つかりませんでした';

  @override
  String get randomManager_noMatchingPool => '一致するプールが見つかりませんでした';

  @override
  String get randomManager_cannotLoadPreview => 'プレビューを読み込めません';

  @override
  String get randomManager_openInDanbooru => 'Danbooru で表示';

  @override
  String get randomManager_editTagGroup => 'タググループの編集';

  @override
  String get randomManager_basicTab => '基本';

  @override
  String randomManager_tagsTab(Object count) {
    return 'タグ ($count)';
  }

  @override
  String get randomManager_diyAbilitiesTab => 'DIY 機能';

  @override
  String get randomManager_selectionSingle => 'シングル';

  @override
  String get randomManager_selectionSingleDesc => '重み付けされたランダムな 1 つの選択';

  @override
  String get randomManager_selectionAll => 'すべて';

  @override
  String get randomManager_selectionAllDesc => 'すべてのタグを選択';

  @override
  String get randomManager_selectionMultipleCount => '複数のカウント';

  @override
  String get randomManager_selectionMultipleCountDesc => '指定されたカウントを選択してください';

  @override
  String get randomManager_selectionMultipleProbability => '多重確率';

  @override
  String get randomManager_selectionMultipleProbabilityDesc => '各タグを個別に評価します';

  @override
  String get randomManager_selectionSequential => 'シーケンシャル';

  @override
  String get randomManager_selectionSequentialDesc => 'バッチ間で状態を維持する';

  @override
  String get randomManager_noTags => 'タグがありません';

  @override
  String get randomManager_conditionalBranch => '条件分岐';

  @override
  String get randomManager_conditionalBranchDesc => '変数値に基づいて異なるタグのサブセットを選択します';

  @override
  String get randomManager_dependencyConfig => '依存関係構成';

  @override
  String get randomManager_dependencyConfigDesc => 'カウントの選択を他のカテゴリ値に依存させる';

  @override
  String get randomManager_visibilityRules => '可視性ルール';

  @override
  String get randomManager_visibilityRulesDesc => '構成に基づいて生成するかどうかを決定';

  @override
  String get randomManager_timeCondition => '時間条件';

  @override
  String get randomManager_timeConditionDesc => '特定の日付範囲内で有効にする';

  @override
  String get randomManager_postProcessRules => '後処理ルール';

  @override
  String get randomManager_postProcessRulesDesc => '選択したタグに基づいて競合を削除します';

  @override
  String get randomManager_emphasisProbability => '強調確率';

  @override
  String get randomManager_probability => '確率';

  @override
  String get randomManager_selectionMode => '選択モード';

  @override
  String randomManager_editHint(Object name) {
    return '$name (クリックして編集)';
  }

  @override
  String randomManager_emphasisProbabilityValue(Object percent) {
    return '強調確率: $percent%';
  }

  @override
  String get randomManager_previewGeneration => 'プレビューの生成';

  @override
  String get randomManager_generating => '生成中';

  @override
  String get randomManager_generate => '生成';

  @override
  String get randomManager_generationFailed => '生成に失敗しました';

  @override
  String get randomManager_copy => 'コピー';

  @override
  String get randomManager_regenerate => '再生成';

  @override
  String get randomManager_copiedToClipboard => 'クリップボードにコピーされました';

  @override
  String get randomManager_selectPresetRequired => 'プリセットを選択してください';

  @override
  String randomManager_characterCountLabel(Object count) {
    return '$count キャラクター';
  }

  @override
  String randomManager_tagCountLabel(Object count) {
    return '$count タグ';
  }

  @override
  String get randomManager_previewHint => '[生成] をクリックしてランダムなタグをプレビューします';

  @override
  String get randomManager_generateNow => '今すぐ生成';

  @override
  String get randomManager_batchOperations => 'バッチ操作';

  @override
  String randomManager_selectedItems(Object count) {
    return '$count が選択されました';
  }

  @override
  String randomManager_totalItems(Object count) {
    return '$count 合計';
  }

  @override
  String randomManager_enabledItems(Object count) {
    return '$count 項目が有効になりました';
  }

  @override
  String randomManager_disabledItems(Object count) {
    return '$count 項目が無効になりました';
  }

  @override
  String get randomManager_batchDeleteTitle => '一括削除';

  @override
  String randomManager_batchDeleteContent(Object count) {
    return '選択した $count 個のアイテムを削除しますか?この操作は元に戻すことができません。';
  }

  @override
  String randomManager_deletedItems(Object count) {
    return '$count 個のアイテムが削除されました';
  }

  @override
  String get randomManager_invertSelection => '選択範囲を反転';

  @override
  String get randomManager_moreActions => 'その他のアクション';

  @override
  String get randomManager_enableSelected => '選択したものを有効にする';

  @override
  String get randomManager_disableSelected => '選択したものを無効にする';

  @override
  String get randomManager_deleteSelected => '選択したものを削除';

  @override
  String get randomManager_noHistory => '履歴はありません';

  @override
  String get randomManager_operationHistory => '操作履歴';

  @override
  String get randomManager_keyboardShortcuts => 'キーボード ショートカット';

  @override
  String get randomManager_generalShortcuts => '一般';

  @override
  String get randomManager_presetActions => 'プリセットアクション';

  @override
  String get randomManager_selectionActions => '選択アクション';

  @override
  String get randomManager_closeWindow => 'ウィンドウを閉じる';

  @override
  String get randomManager_refreshOrSync => '更新/同期';

  @override
  String get genderRestriction_enabled => '性別制限';

  @override
  String get genderRestriction_enabledDesc => '性別フィルターが有効になっていません';

  @override
  String genderRestriction_enabledActive(Object count) {
    return '有効、$count 性別が利用可能';
  }

  @override
  String get genderRestriction_enable => '性別制限を有効にする';

  @override
  String get genderRestriction_enableDesc => '指定された性別のキャラクターにのみ適用されます';

  @override
  String get genderRestriction_applicableGenders => '該当する性別';

  @override
  String get gender_female => '女性';

  @override
  String get gender_male => '男性';

  @override
  String get gender_trap => 'トラップ';

  @override
  String get gender_futanari => 'ふたなり';

  @override
  String get scope_title => '範囲';

  @override
  String get scope_titleDesc => 'このカテゴリ/グループの適用範囲を設定します';

  @override
  String get scope_global => 'メイン';

  @override
  String get scope_globalTooltip =>
      'プロンプトはメイン プロンプト領域に表示されます\n適した用途: 背景、シーン、スタイルなど。';

  @override
  String get scope_character => 'キャラクター';

  @override
  String get scope_characterTooltip =>
      'プロンプトはキャラクタープロンプトにのみ表示されます\nキャラクターごとに個別に生成されます\n適用対象: 髪の色、目の色、服装、表情など。';

  @override
  String get scope_all => '両方';

  @override
  String get scope_allTooltip =>
      'プロンプトはメイン プロンプトとキャラクター プロンプトの両方に表示されます\n用途: ポーズ、インタラクション、その他の汎用タグ';

  @override
  String get tagGroupSettings_resetToCategory => 'カテゴリ設定にリセット';

  @override
  String get bracket_weaken => '弱体化';

  @override
  String get bracket_enhance => '強化';

  @override
  String get vibeNoEncodingWarning => 'この画像には事前にエンコードされたデータがありません';

  @override
  String vibeWillCostAnlas(int count) {
    return 'エンコードには $count Anlas を消費します';
  }

  @override
  String get vibeEncodeConfirm => '続けて Anlas を消費しますか?';

  @override
  String get vibeCancel => 'キャンセル';

  @override
  String get vibeConfirmEncode => 'エンコード';

  @override
  String get vibeParseFailed => 'Vibe ファイルの解析に失敗しました';

  @override
  String get tagGroupBrowser_searchHint => 'タグを検索...';

  @override
  String tagGroupBrowser_tagCount(Object count) {
    return '$count タグ';
  }

  @override
  String tagGroupBrowser_filteredTagCount(Object filtered, Object total) {
    return '$total タグ中 $filtered を表示しています';
  }

  @override
  String get tagGroupBrowser_noTags => 'タグがありません';

  @override
  String get tagGroupBrowser_noLibrary => 'タグ ライブラリがロードされていません';

  @override
  String get tagGroupBrowser_importLibraryHint => 'まずタグ ライブラリをインポートしてください';

  @override
  String get tagGroupBrowser_noCategories => '有効なタグ カテゴリがありません';

  @override
  String get tagGroupBrowser_enableCategoriesHint => '設定でタグ カテゴリを有効にしてください';

  @override
  String get tagGroupBrowser_danbooruSuggestions => 'Danbooru 提案';

  @override
  String get tag_favoritesTitle => 'お気に入りのタグ';

  @override
  String get tag_favoritesEmpty => 'お気に入りのタグはまだありません';

  @override
  String get tag_favoritesEmptyHint => 'タグを長押ししてお気に入りに追加します';

  @override
  String get tag_alreadyAdded => 'タグはすでに現在のプロンプトに追加されています';

  @override
  String get tag_removeFavoriteTitle => 'お気に入りから削除';

  @override
  String tag_removeFavoriteMessage(Object tag) {
    return '「$tag」をお気に入りから削除しますか?';
  }

  @override
  String get tag_templatesTitle => 'タグテンプレート';

  @override
  String get tag_templatesEmpty => 'タグ テンプレートはまだありません';

  @override
  String get tag_templatesEmptyHint => 'タグを選択し、+ ボタンをクリックしてテンプレートを作成します';

  @override
  String get tag_templateCreate => 'テンプレートの作成';

  @override
  String get tag_templateNameLabel => 'テンプレート名';

  @override
  String get tag_templateNameHint => 'テンプレート名を入力してください';

  @override
  String get tag_templateNameRequired => 'テンプレート名を入力してください';

  @override
  String get tag_templateDescLabel => '説明 (オプション)';

  @override
  String get tag_templateDescHint => 'テンプレートの説明を入力してください';

  @override
  String get tag_templatePreview => 'タグのプレビュー';

  @override
  String tag_templateTagCount(Object count) {
    return '$count タグ';
  }

  @override
  String tag_templateMoreTags(Object count) {
    return '$count 個以上のタグ...';
  }

  @override
  String tag_templateInserted(Object name) {
    return 'テンプレート「$name」を挿入しました';
  }

  @override
  String get tag_templateNoTags => '保存するタグがありません';

  @override
  String get tag_templateSaved => 'テンプレートが保存されました';

  @override
  String get tag_templateNameExists => 'テンプレート名はすでに存在します';

  @override
  String get tag_templateDeleteTitle => 'テンプレートを削除';

  @override
  String tag_templateDeleteMessage(Object name) {
    return 'テンプレート「$name」を削除しますか?';
  }

  @override
  String get tag_tabTags => 'タグ';

  @override
  String get tag_tabGroups => 'グループ';

  @override
  String get tag_tabFavorites => 'お気に入り';

  @override
  String get tag_tabTemplates => 'テンプレート';

  @override
  String get tag_categoryGeneral => '一般';

  @override
  String get tag_categoryArtist => 'アーティスト';

  @override
  String get tag_categoryCopyright => '著作権';

  @override
  String get tag_categoryCharacter => 'キャラクター';

  @override
  String get tag_categoryMeta => 'メタ';

  @override
  String tag_countBadgeTooltip(Object total) {
    return '合計 $total タグ';
  }

  @override
  String get tag_countBadgeBreakdown => 'タグの内訳';

  @override
  String tag_countEnabled(Object count) {
    return '$count が有効になりました';
  }

  @override
  String get localGallery_searchIndexing => '検索インデックスを構築しています...';

  @override
  String get localGallery_searchIndexComplete => '検索インデックスの準備ができました';

  @override
  String get localGallery_searchIndexFailed => '検索インデックス エラー';

  @override
  String localGallery_cacheStatus(Object current, Object max) {
    return 'キャッシュ: $current/$max 画像';
  }

  @override
  String localGallery_cacheHitRate(Object rate) {
    return 'ヒット率: $rate%';
  }

  @override
  String get localGallery_preloading => '画像をプリロードしています...';

  @override
  String get localGallery_preloadComplete => 'プリロードが完了しました';

  @override
  String get localGallery_progressiveLoadError => '画像のロードに失敗しました';

  @override
  String get localGallery_noImagesFound => '画像が見つかりませんでした';

  @override
  String get localGallery_unknownError => '不明なエラー';

  @override
  String localGallery_loadFailed(Object error) {
    return 'ロードに失敗しました: $error';
  }

  @override
  String get localGallery_indexingLocalImages => 'ローカル画像のインデックスを作成しています...';

  @override
  String get localGallery_emptyTitle => 'ローカル イメージがありません';

  @override
  String get localGallery_emptySubtitle => '生成された画像はここに保存されます';

  @override
  String get localGallery_noMatchingResults => '一致する結果はありません';

  @override
  String get localGallery_loadingGroupedImages => 'グループ化された画像を読み込み中...';

  @override
  String localGallery_jumpedToMonth(Object year, Object month) {
    return '$year-$month にジャンプしました';
  }

  @override
  String get localGallery_searchPlaceholder => 'プロンプト、モデル、サンプラーを検索...';

  @override
  String get localGallery_title => 'ローカル ギャラリー';

  @override
  String get localGallery_allImages => 'すべての画像';

  @override
  String get localGallery_categoryPanelTitle => 'カテゴリ';

  @override
  String get localGallery_searchFilenamePromptPlaceholder =>
      'ファイル名/プロンプトを検索します。カンマで区切られた用語は一緒に照合されます...';

  @override
  String get localGallery_selectCurrentPage => 'ページを選択';

  @override
  String get localGallery_deselectCurrentPage => 'ページの選択を解除';

  @override
  String get localGallery_selectAllResults => 'すべて選択';

  @override
  String get localGallery_deselectAllResults => 'すべての選択を解除';

  @override
  String get localGallery_moveSelected => '移動';

  @override
  String get localGallery_packSelected => 'パック';

  @override
  String get localGallery_editMetadata => '編集';

  @override
  String get localGallery_addToCollection => 'コレクションに追加';

  @override
  String get localGallery_switchToGridView => 'グリッド ビューに切り替える';

  @override
  String get localGallery_switchToDateGroupedView => '日付グループ化ビューに切り替える';

  @override
  String get localGallery_openFilterPanel => 'フィルター パネルを開く';

  @override
  String get localGallery_hideCategoryPanel => 'カテゴリ パネルを非表示にする';

  @override
  String get localGallery_showCategoryPanel => 'カテゴリ パネルを表示';

  @override
  String get localGallery_enterSelectionMode => '選択モードに入ります';

  @override
  String get localGallery_refreshTooltip =>
      'ギャラリーを更新\n\n新しい画像または変更された画像を自動的に検出し、インデックスを更新します';

  @override
  String get localGallery_tagIntersection => 'タグの交差';

  @override
  String get localGallery_createCategoryTitle => '新しいカテゴリ';

  @override
  String get localGallery_createCategoryHint => 'カテゴリ名を入力してください';

  @override
  String get localGallery_createCategoryConfirm => '作成';

  @override
  String get localGallery_createSubCategoryTitle => '新しいサブカテゴリ';

  @override
  String get localGallery_showInFolder => 'フォルダー内に表示';

  @override
  String get localGallery_promptCopied => 'プロンプトがコピーされました';

  @override
  String get localGallery_seedCopied => 'シードがコピーされました';

  @override
  String localGallery_confirmDeleteImageContent(Object name) {
    return '画像「$name」を削除しますか?\n\nこれを元に戻すことはできません。';
  }

  @override
  String get localGallery_imageDeleted => '画像が削除されました';

  @override
  String localGallery_deleteFailed(Object error) {
    return '削除に失敗しました: $error';
  }

  @override
  String get localGallery_categoryDeleteContent =>
      'このカテゴリを削除しますか?フォルダーとその内容は保持されます。';

  @override
  String get localGallery_protectedDeleteCategoryTitle => '保護モード: カテゴリの削除の確認';

  @override
  String get localGallery_protectedDeleteCategoryContent =>
      'これにより、カテゴリ レコードが削除されます。フォルダーとその内容は保持されます。もう一度確認してください。';

  @override
  String get localGallery_confirmDelete => '削除の確認';

  @override
  String get localGallery_confirmMoveImageTitle => '保護モード: 画像の移動を確認';

  @override
  String get localGallery_confirmMoveImageContent =>
      'これにより、画像がターゲット カテゴリ フォルダーに移動されます。これが誤ってドラッグされたものではないことを確認します。';

  @override
  String get localGallery_confirmMove => '移動の確認';

  @override
  String get localGallery_imageMovedToCategory => '画像がカテゴリに移動されました';

  @override
  String get localGallery_categoriesSynced => 'カテゴリとフォルダーが同期されました';

  @override
  String get localGallery_saveDirectoryNotSet => '保存ディレクトリが設定されていません';

  @override
  String get localGallery_folderNotFound => 'フォルダーが見つかりません';

  @override
  String localGallery_openFolderFailed(Object error) {
    return 'フォルダーを開けませんでした: $error';
  }

  @override
  String get localGallery_protectedDeleteTitle => '保護モード: 削除を再度確認してください';

  @override
  String localGallery_protectedDeleteImagesContent(Object count) {
    return 'これにより、$count 個のローカル イメージ ファイルが完全に削除されます。これを元に戻すことはできません。';
  }

  @override
  String get localGallery_protectedBulkMoveTitle => '保護モード: 一括移動の確認';

  @override
  String localGallery_protectedBulkMoveContent(Object count) {
    return 'これにより、$count ローカル画像ファイルがターゲット フォルダに移動されます。これが間違いではないことを確認してください。';
  }

  @override
  String localGallery_importParamsFailed(Object error) {
    return 'パラメータのインポートに失敗しました: $error';
  }

  @override
  String localGallery_protectedDeleteImageContent(Object name) {
    return 'これにより、イメージ「$name」が完全に削除されます。これを元に戻すことはできません。';
  }

  @override
  String get localGallery_saveZipArchive => 'ZIP アーカイブを保存';

  @override
  String localGallery_packingImages(Object count) {
    return '$count 個の画像をパッキングしています...';
  }

  @override
  String localGallery_packedImages(Object count) {
    return '$count 個の画像をパックしました';
  }

  @override
  String get localGallery_packFailed => '画像のパックに失敗しました';

  @override
  String get localGallery_noMetadata => 'この画像にはメタデータがありません';

  @override
  String get localGallery_imageFileMissing => '画像ファイルが存在しません';

  @override
  String get localGallery_sentToImageToImage => '画像を Image2Image に送信しました';

  @override
  String localGallery_sendFailed(Object error) {
    return '送信失敗: $error';
  }

  @override
  String get localGallery_noVibeData => 'この画像には Vibe データが含まれていません';

  @override
  String localGallery_vibeAddedToParams(Object name) {
    return 'Vibe「$name」が生成パラメータに追加されました';
  }

  @override
  String localGallery_addVibeFailed(Object error) {
    return 'Vibe の追加に失敗しました: $error';
  }

  @override
  String get localGallery_sentToReversePrompt => '画像がリバース プロンプトに送信されました';

  @override
  String localGallery_sendToKritaFailed(Object error) {
    return 'Krita への送信に失敗しました: $error';
  }

  @override
  String get localGallery_sendTo => '送信先...';

  @override
  String get localGallery_sendToImg2Img => 'Image2Image に送信';

  @override
  String get localGallery_sendToReversePrompt => '逆プロンプトに送信';

  @override
  String get localGallery_sendToStyleTransfer => 'バイブストランスファーに送信';

  @override
  String get localGallery_sendToPreciseReference => '精密参照に送信';

  @override
  String get localGallery_sendToKrita => 'Krita に送信';

  @override
  String get localGallery_importImageMetadata => '画像メタデータをインポート';

  @override
  String get localGallery_copyPrompt => 'プロンプトのコピー';

  @override
  String get localGallery_copySeed => 'シードをコピー';

  @override
  String get localGallery_dragToShare => 'ドラッグして共有';

  @override
  String get localGallery_moveToRoot => 'ルートに移動';

  @override
  String get localGallery_folderName => 'フォルダー名';

  @override
  String get localGallery_newFolderName => '新しい名前';

  @override
  String get localGallery_folderNameHint => 'フォルダー名を入力してください';

  @override
  String get localGallery_folderCreated => 'フォルダーが作成されました';

  @override
  String get localGallery_folderCreateFailed => 'フォルダーの作成に失敗しました';

  @override
  String get localGallery_renameFolderTitle => 'フォルダーの名前を変更';

  @override
  String get localGallery_renameSuccess => '名前が変更されました';

  @override
  String get localGallery_renameFailed => '名前の変更に失敗しました';

  @override
  String get localGallery_deleteFolderTitle => 'フォルダーの削除';

  @override
  String localGallery_deleteFolderWithImagesContent(Object name, Object count) {
    return 'フォルダー「$name」には $count の画像が含まれています。削除しますか?\n\n注: これにより、フォルダーとその中のすべての画像が削除されます。これを元に戻すことはできません。';
  }

  @override
  String localGallery_deleteEmptyFolderContent(Object name) {
    return '空のフォルダー「$name」を削除しますか?';
  }

  @override
  String get localGallery_folderDeleted => 'フォルダーが削除されました';

  @override
  String get localGallery_folderDeleteFailed => 'フォルダーの削除に失敗しました';

  @override
  String get localGallery_cachingMetadata => 'メタデータをキャッシュしています...';

  @override
  String get localGallery_metadataCacheStats => 'メタデータ キャッシュ統計';

  @override
  String get localGallery_totalImages => '合計画像数';

  @override
  String get localGallery_withMetadata => 'メタデータあり';

  @override
  String get localGallery_skipped => 'スキップされました';

  @override
  String get localGallery_remaining => '残り';

  @override
  String get localGallery_cacheMonitor => 'キャッシュ モニター';

  @override
  String get localGallery_threeLayerCacheStats => '3 層キャッシュの統計';

  @override
  String localGallery_updatedAt(Object time) {
    return '更新: $time';
  }

  @override
  String get localGallery_memoryCache => 'メモリ キャッシュ';

  @override
  String get localGallery_hiveCache => 'Hive キャッシュ';

  @override
  String get localGallery_sqliteDatabase => 'SQLite データベース';

  @override
  String get localGallery_imageUnit => '画像';

  @override
  String get localGallery_metadataUnit => 'メタデータ';

  @override
  String get localGallery_entriesUnit => 'エントリ';

  @override
  String get localGallery_hitRate => 'ヒット率';

  @override
  String get localGallery_performanceStats => 'パフォーマンス統計';

  @override
  String get localGallery_cacheHit => 'ヒット';

  @override
  String get localGallery_cacheMiss => 'ミス';

  @override
  String get localGallery_clearL1 => 'L1 をクリア';

  @override
  String get localGallery_clearL2 => 'L2 をクリア';

  @override
  String get localGallery_clearAll => 'すべてクリア';

  @override
  String get localGallery_resetStats => '統計をリセット';

  @override
  String get localGallery_confirmClearCache => 'クリアの確認';

  @override
  String get localGallery_confirmClearCacheContent =>
      'すべてのキャッシュをクリアしますか?これにより、すべての画像が再スキャンされます。';

  @override
  String get localGallery_filterByDate => '日付でフィルターする';

  @override
  String get localGallery_clearFilters => 'フィルターをクリア';

  @override
  String get slideshow_title => 'スライドショー';

  @override
  String get slideshow_of => '件中';

  @override
  String get slideshow_play => 'プレイ';

  @override
  String get slideshow_pause => '一時停止';

  @override
  String get slideshow_previous => '前へ';

  @override
  String get slideshow_next => '次へ';

  @override
  String get slideshow_exit => '終了 (Esc)';

  @override
  String get slideshow_noImages => '表示する画像がありません';

  @override
  String get slideshow_keyboardHint =>
      '← → を使用して移動し、Space を使用して再生/一時停止し、Esc を使用して終了します';

  @override
  String slideshow_autoPlayInterval(Object seconds) {
    return '自動再生間隔: ${seconds}s';
  }

  @override
  String get comparison_title => '画像の比較';

  @override
  String get comparison_noImages => '表示する画像がありません';

  @override
  String get comparison_tooManyImages => '画像が多すぎます';

  @override
  String get comparison_maxImages => '比較できる画像は最大 4 つです';

  @override
  String get comparison_close => '詳細比較';

  @override
  String get comparison_zoomHint => 'ピンチまたはスクロールして個別にズームします';

  @override
  String get comparison_loadError => '画像のロードに失敗しました';

  @override
  String get statistics_title => '統計';

  @override
  String get statistics_tabOverview => '概要';

  @override
  String get statistics_tabTrends => 'トレンド';

  @override
  String get statistics_tabDetails => '詳細';

  @override
  String get statistics_noData => '利用可能な統計はありません';

  @override
  String get statistics_generatedCount => '生成数';

  @override
  String get statistics_favoriteCount => 'お気に入り';

  @override
  String statistics_tooltipGenerated(Object count) {
    return '生成数: $count';
  }

  @override
  String statistics_tooltipFavorite(Object count) {
    return 'お気に入り: $count';
  }

  @override
  String get statistics_noTagData => 'タグデータがありません';

  @override
  String get statistics_generateFirst => '最初にいくつかの画像を生成します';

  @override
  String get statistics_overview => '概要';

  @override
  String get statistics_totalImages => '合計画像数';

  @override
  String get statistics_totalSize => '合計サイズ';

  @override
  String get statistics_favorites => 'お気に入り';

  @override
  String get statistics_tagged => 'タグ付き';

  @override
  String get statistics_modelDistribution => 'モデル分布';

  @override
  String get statistics_resolutionDistribution => '解像度の分布';

  @override
  String get statistics_samplerDistribution => 'サンプラー分布';

  @override
  String get statistics_sizeDistribution => 'ファイル サイズの分布';

  @override
  String get statistics_additionalStats => '追加の統計';

  @override
  String get statistics_averageFileSize => '平均ファイルサイズ';

  @override
  String get statistics_withMetadata => 'メタデータ付きの画像';

  @override
  String get statistics_calculatedAt => '計算日時';

  @override
  String get statistics_justNow => 'たった今';

  @override
  String statistics_minutesAgo(Object count) {
    return '$count 分前';
  }

  @override
  String statistics_hoursAgo(Object count) {
    return '$count 時間前';
  }

  @override
  String statistics_daysAgo(Object count) {
    return '$count 日前';
  }

  @override
  String get statistics_anlasCost => 'Anlas コスト';

  @override
  String get statistics_totalAnlasCost => '総コスト';

  @override
  String get statistics_avgDailyCost => '1 日の平均';

  @override
  String get statistics_noAnlasData => 'Anlas 消費データがありません';

  @override
  String get statistics_peakActivity => 'ピークアクティビティ';

  @override
  String get statistics_timeMorning => '朝';

  @override
  String get statistics_timeAfternoon => '午後';

  @override
  String get statistics_timeEvening => '夕方';

  @override
  String get statistics_timeNight => '夜';

  @override
  String get localGallery_favoritesOnly => 'お気に入りのみ';

  @override
  String get localGallery_noFavorites => 'お気に入りはまだありません';

  @override
  String get localGallery_markAsFavorite => 'お気に入りとしてマーク';

  @override
  String get localGallery_removeFromFavorites => 'お気に入りから削除';

  @override
  String get localGallery_tags => 'タグ';

  @override
  String get localGallery_addTag => 'タグを追加';

  @override
  String get localGallery_removeTag => 'タグを削除';

  @override
  String get localGallery_noTags => 'タグがありません';

  @override
  String get localGallery_filterByTags => 'タグによるフィルター';

  @override
  String get localGallery_selectTags => 'タグの選択';

  @override
  String get localGallery_tagFilterMatchAll => 'すべてのタグに一致';

  @override
  String get localGallery_tagFilterMatchAny => '任意のタグに一致';

  @override
  String get localGallery_clearTagFilter => 'タグフィルターをクリア';

  @override
  String get localGallery_noTagsFound => 'タグが見つかりませんでした';

  @override
  String get localGallery_advancedFilters => '高度なフィルター';

  @override
  String get localGallery_filterByModel => 'モデルによるフィルター';

  @override
  String get localGallery_filterBySampler => 'サンプラーによるフィルター';

  @override
  String get localGallery_filterBySteps => 'ステップごとにフィルターする';

  @override
  String get localGallery_filterByCfg => 'CFG スケールによるフィルター';

  @override
  String get localGallery_filterByResolution => '解像度によるフィルター';

  @override
  String get localGallery_filterSubtitle => '画像コレクションを正確にフィルタリングします';

  @override
  String get localGallery_model => 'モデル';

  @override
  String get localGallery_modelHint => 'モデル名を入力してください...';

  @override
  String get localGallery_sampler => 'サンプラー';

  @override
  String get localGallery_samplerHint => 'サンプラー名を入力してください...';

  @override
  String get localGallery_steps => 'ステップ';

  @override
  String get localGallery_cfgScale => 'CFG スケール';

  @override
  String get localGallery_resolution => '解像度';

  @override
  String get localGallery_resolutionHint => '幅 x 高さ (例: 1024x1024)';

  @override
  String get localGallery_any => '任意';

  @override
  String get localGallery_custom => 'カスタム';

  @override
  String get localGallery_to => 'へ';

  @override
  String get localGallery_activeFiltersSet => 'フィルターセット';

  @override
  String get localGallery_applyFilters => 'フィルターを適用する';

  @override
  String get localGallery_resetAdvancedFilters => '詳細フィルターをリセット';

  @override
  String get localGallery_exportMetadata => 'メタデータのエクスポート';

  @override
  String get localGallery_exportSelected => '選択項目をエクスポート';

  @override
  String get localGallery_exportFailed => 'エクスポートに失敗しました';

  @override
  String get localGallery_exporting => 'エクスポートしています...';

  @override
  String get localGallery_selectToExport => 'エクスポートする画像を選択してください';

  @override
  String get localGallery_noImagesSelected => '画像が選択されていません';

  @override
  String localGallery_exportSuccessDetail(Object count) {
    return 'メタデータ付きの $count 画像をエクスポートしました';
  }

  @override
  String bulkExport_title(Object count) {
    return '$count 画像をエクスポート';
  }

  @override
  String get bulkExport_format => '形式';

  @override
  String get bulkExport_jsonFormat => 'JSON';

  @override
  String get bulkExport_csvFormat => 'CSV';

  @override
  String get bulkExport_metadataOptions => 'メタデータ オプション';

  @override
  String get bulkExport_includeMetadata => 'メタデータを含める';

  @override
  String get bulkExport_includeMetadataHint => '生成パラメータを画像付きでエクスポート';

  @override
  String get localGallery_group_today => '今日';

  @override
  String get localGallery_group_yesterday => '昨日';

  @override
  String get localGallery_group_thisWeek => '今週';

  @override
  String get localGallery_group_earlier => '以前';

  @override
  String get localGallery_group_dateFormat => 'MMM dd';

  @override
  String get localGallery_jumpToDate => '日付に移動';

  @override
  String get localGallery_noImagesOnThisDate => 'この日付には画像がありません';

  @override
  String get localGallery_selectedImagesNoPrompt => '選択した画像にはプロンプト情報がありません';

  @override
  String localGallery_addedTasksToQueue(Object count) {
    return '$count タスクをキューに追加しました';
  }

  @override
  String localGallery_cannotOpenFolder(Object error) {
    return 'フォルダーを開けません: $error';
  }

  @override
  String localGallery_jumpedToDate(Object date) {
    return '$date にジャンプしました';
  }

  @override
  String get localGallery_permissionRequiredTitle => 'ストレージ権限が必要です';

  @override
  String get localGallery_permissionRequiredContent =>
      'ローカル ギャラリーには、生成された画像をスキャンするためのストレージ権限が必要です。\n\n設定で許可を与えて、もう一度お試しください。';

  @override
  String get localGallery_openSettings => '設定を開く';

  @override
  String get localGallery_firstTimeTipTitle => '💡 ヒント';

  @override
  String get localGallery_firstTimeTipContent =>
      '画像を右クリック (デスクトップ) または長押し (モバイル) すると、次のことができます。\n\n• プロンプトのコピー\n• コピーシード\n• 完全なメタデータの表示';

  @override
  String get localGallery_gotIt => 'わかりました';

  @override
  String get localGallery_undone => '元に戻しました';

  @override
  String get localGallery_redone => 'やり直し';

  @override
  String get localGallery_confirmBulkDelete => '一括削除の確認';

  @override
  String localGallery_confirmBulkDeleteContent(Object count) {
    return '$count 個の選択した画像を削除してもよろしいですか?\n\nこれにより、それらはファイル システムから永久に削除され、元に戻すことはできません。';
  }

  @override
  String localGallery_deletedImages(Object count) {
    return '$count 個の画像が削除されました';
  }

  @override
  String get localGallery_noFoldersAvailable =>
      '使用可能なフォルダーがありません。最初にフォルダーを作成してください。';

  @override
  String get localGallery_moveToFolder => 'フォルダーに移動';

  @override
  String localGallery_imageCount(Object count) {
    return '$count 画像';
  }

  @override
  String localGallery_movedImages(Object count) {
    return '$count 個の画像を移動しました';
  }

  @override
  String get localGallery_moveImagesFailed => '画像の移動に失敗しました';

  @override
  String localGallery_addedToCollection(Object count, Object name) {
    return '$count 画像をコレクション「$name」に追加しました';
  }

  @override
  String get localGallery_addToCollectionFailed => '画像をコレクションに追加できませんでした';

  @override
  String get brushPreset_selectHint => 'ダブルタップしてこのブラシ プリセットを選択します';

  @override
  String get brushPreset_selected => '選択済み';

  @override
  String get brushPreset_pencil => '鉛筆';

  @override
  String get brushPreset_fine => '細筆';

  @override
  String get brushPreset_standard => '標準ブラシ';

  @override
  String get brushPreset_soft => 'ソフトブラシ';

  @override
  String get brushPreset_airbrush => 'エアブラシ';

  @override
  String get brushPreset_marker => 'マーカー';

  @override
  String get brushPreset_thick => '太いブラシ';

  @override
  String get brushPreset_smudge => 'スマッジ ブラシ';

  @override
  String bulkProgress_progress(Object current, Object total) {
    return '$total の $current を処理しています';
  }

  @override
  String bulkProgress_success(Object count) {
    return '$count は成功しました';
  }

  @override
  String bulkProgress_failed(Object count) {
    return '$count が失敗しました';
  }

  @override
  String get bulkProgress_errors => 'エラー:';

  @override
  String bulkProgress_moreErrors(Object count) {
    return '...さらに $count 個のエラー';
  }

  @override
  String bulkProgress_completed(Object count) {
    return '$count 個のアイテムが完了しました';
  }

  @override
  String bulkProgress_completedWithErrors(Object success, Object failed) {
    return '$success は成功しました、$failed は失敗しました';
  }

  @override
  String get bulkProgress_title_delete => '画像の削除';

  @override
  String get bulkProgress_title_export => 'メタデータのエクスポート';

  @override
  String get bulkProgress_title_metadataEdit => 'メタデータの編集';

  @override
  String get bulkProgress_title_addToCollection => 'コレクションに追加';

  @override
  String get bulkProgress_title_removeFromCollection => 'コレクションから削除しています';

  @override
  String get bulkProgress_title_toggleFavorite => 'お気に入りを更新しています';

  @override
  String get bulkProgress_title_default => '処理中';

  @override
  String get collectionSelect_dialogTitle => 'コレクションを選択してください';

  @override
  String get collectionSelect_filterHint => 'コレクションを検索...';

  @override
  String get collectionSelect_noCollections => 'コレクションはありません';

  @override
  String get collectionSelect_createCollectionHint => '最初にコレクションを作成してください';

  @override
  String get collectionSelect_noFilterResults => '一致するコレクションが見つかりませんでした';

  @override
  String collectionSelect_imageCount(int count) {
    return '$count 画像';
  }

  @override
  String get statistics_navOverview => '概要';

  @override
  String get statistics_navModels => 'モデル';

  @override
  String get statistics_navTags => 'タグ';

  @override
  String get statistics_navParameters => 'パラメータ';

  @override
  String get statistics_navTrends => 'トレンド';

  @override
  String get statistics_navActivity => 'アクティビティ';

  @override
  String get statistics_sectionTagAnalysis => 'タグ分析';

  @override
  String get statistics_sectionParameterPrefs => 'パラメータの設定';

  @override
  String get statistics_sectionActivityAnalysis => 'アクティビティ分析';

  @override
  String get statistics_chartUsageDistribution => '使用状況の分布';

  @override
  String get statistics_chartModelRanking => 'モデルランキング';

  @override
  String get statistics_chartModelUsageOverTime => 'モデルの経時的な使用状況';

  @override
  String get statistics_chartTopTags => 'トップのタグ';

  @override
  String get statistics_chartTagCloud => 'タグクラウド';

  @override
  String get statistics_chartParameterOverview => 'パラメータの概要';

  @override
  String get statistics_chartAspectRatio => 'アスペクト比の分布';

  @override
  String get statistics_chartActivityHeatmap => 'アクティビティ ヒートマップ';

  @override
  String get statistics_chartHourlyDistribution => '時間別分布';

  @override
  String get statistics_chartWeekdayDistribution => '曜日別分布';

  @override
  String get statistics_filterTitle => 'フィルター';

  @override
  String get statistics_filterClear => 'クリア';

  @override
  String get statistics_filterDateRange => '日付範囲';

  @override
  String get statistics_filterModel => 'モデル';

  @override
  String get statistics_filterAllModels => 'すべてのモデル';

  @override
  String get statistics_filterResolution => '解像度';

  @override
  String get statistics_filterAllResolutions => 'すべての解像度';

  @override
  String get statistics_granularity => '粒度';

  @override
  String get statistics_granularityDay => '日';

  @override
  String get statistics_granularityWeek => '週';

  @override
  String get statistics_granularityMonth => '月';

  @override
  String get statistics_labelTotalDays => '合計日数';

  @override
  String get statistics_labelPeak => 'ピーク';

  @override
  String get statistics_labelAverage => '平均';

  @override
  String get statistics_labelSteps => 'ステップ';

  @override
  String get statistics_labelCfg => 'CFG';

  @override
  String get statistics_labelWidth => '幅';

  @override
  String get statistics_labelHeight => '高さ';

  @override
  String get statistics_labelFavPercent => 'お気に入り%';

  @override
  String get statistics_labelTagPercent => 'タグ%';

  @override
  String get statistics_aspectSquare => 'スクエア';

  @override
  String get statistics_aspectLandscape => '横長';

  @override
  String get statistics_aspectPortrait => '縦長';

  @override
  String get statistics_aspectOther => 'その他';

  @override
  String get statistics_refresh => '更新';

  @override
  String get statistics_retry => '再試行';

  @override
  String statistics_error(Object error) {
    return 'エラー: $error';
  }

  @override
  String get statistics_noMetadata => '利用可能なメタデータがありません';

  @override
  String get statistics_unknown => '不明';

  @override
  String statistics_weekLabel(Object week) {
    return 'W$week';
  }

  @override
  String get statistics_peakHour => 'ピーク時間';

  @override
  String get statistics_mostActiveDay => '最もアクティブな日';

  @override
  String get statistics_leastActiveDay => '最も活動的でない日';

  @override
  String get statistics_morning => '朝';

  @override
  String get statistics_afternoon => '午後';

  @override
  String get statistics_evening => '夕方';

  @override
  String get statistics_night => '夜';

  @override
  String get statistics_sunday => '日';

  @override
  String get statistics_monday => '月';

  @override
  String get statistics_tuesday => '火';

  @override
  String get statistics_wednesday => '水';

  @override
  String get statistics_thursday => '木';

  @override
  String get statistics_friday => '金';

  @override
  String get statistics_saturday => '土';

  @override
  String get fixedTags_label => '固定タグ';

  @override
  String get fixedTags_enabled => '有効';

  @override
  String get fixedTags_empty => '固定タグなし';

  @override
  String get fixedTags_emptyHint => '下のボタンをクリックして固定タグを追加すると、プロンプトに自動的に適用されます';

  @override
  String get fixedTags_clickToManage => 'クリックして固定タグを管理します';

  @override
  String get fixedTags_manage => '固定タグの管理';

  @override
  String get fixedTags_add => '追加';

  @override
  String get fixedTags_edit => '固定タグの編集';

  @override
  String get fixedTags_openLibrary => 'ライブラリを開く';

  @override
  String get fixedTags_prefix => 'プレフィックス';

  @override
  String get fixedTags_suffix => 'サフィックス';

  @override
  String get fixedTags_prefixDesc => 'プロンプトの前に追加';

  @override
  String get fixedTags_suffixDesc => 'プロンプトの後に追加';

  @override
  String get fixedTags_disabled => '無効';

  @override
  String get fixedTags_weight => 'ウェイト';

  @override
  String get fixedTags_position => '位置';

  @override
  String get fixedTags_name => '名前';

  @override
  String get fixedTags_nameHint => '表示名を入力してください (オプション)';

  @override
  String get fixedTags_content => 'コンテンツ';

  @override
  String get fixedTags_contentHint => 'プロンプトの内容を入力してください。NAI 構文がサポートされています';

  @override
  String get fixedTags_syntaxHelp => '重みの強化/削減およびタグの代替のための NAI 構文をサポートします';

  @override
  String get fixedTags_linkedFromLibrary => 'ライブラリからリンクされました (双方向同期)';

  @override
  String get fixedTags_scope => '範囲';

  @override
  String get fixedTags_positive => 'プロンプト';

  @override
  String get fixedTags_negative => '除外したい要素';

  @override
  String get fixedTags_resetWeight => '1.0 にリセット';

  @override
  String get fixedTags_weightPreview => 'ウェイトプレビュー:';

  @override
  String get fixedTags_deleteTitle => '固定タグを削除';

  @override
  String fixedTags_deleteConfirm(Object name) {
    return '「$name」を削除してもよろしいですか?';
  }

  @override
  String fixedTags_enabledCount(Object enabled, Object total) {
    return '$enabled/$total が有効になりました';
  }

  @override
  String get fixedTags_saveToLibrary => 'ライブラリにも保存します';

  @override
  String get fixedTags_saveToLibraryHint => '後でタグ ライブラリで再利用するため';

  @override
  String get fixedTags_saveToCategory => 'カテゴリに保存';

  @override
  String get fixedTags_clearAll => 'すべてクリア';

  @override
  String get fixedTags_clearAllTitle => 'すべての固定タグをクリア';

  @override
  String fixedTags_clearAllConfirm(Object count) {
    return 'すべての $count 固定タグをクリアしてもよろしいですか?この操作は元に戻すことができません。';
  }

  @override
  String get fixedTags_clearedSuccess => 'すべての固定タグがクリアされました';

  @override
  String get fixedTags_sidebarTitle => '固定タグサイドバー';

  @override
  String get fixedTags_switchGridView => 'グリッド ビューに切り替える';

  @override
  String get fixedTags_switchListView => 'リストビューに切り替える';

  @override
  String get fixedTags_addPositive => 'プロンプト固定タグを追加';

  @override
  String get fixedTags_addNegative => '除外したい要素固定タグを追加';

  @override
  String get fixedTags_addPositiveFromLibrary => 'ライブラリからプロンプト固定タグを追加';

  @override
  String get fixedTags_addNegativeFromLibrary => 'ライブラリから除外したい要素固定タグを追加';

  @override
  String get fixedTags_searchNameOrContent => '名前または内容を検索します';

  @override
  String get fixedTags_clearSearch => '検索をクリア';

  @override
  String get fixedTags_enabledPositive => '有効なプロンプト';

  @override
  String get fixedTags_emptyEnabledPositive => '有効なプロンプト固定タグがありません';

  @override
  String get fixedTags_noMatchingEnabled => '一致する有効な固定タグがありません';

  @override
  String get fixedTags_negativeTitle => '除外したい要素固定タグ';

  @override
  String get fixedTags_emptyNegative => '除外したい要素固定タグはありません';

  @override
  String get fixedTags_noMatchingNegative => '一致する除外したい要素固定タグがありません';

  @override
  String get fixedTags_addedToSidebar => '固定タグのサイドバーに追加されました';

  @override
  String get fixedTags_unknownCategory => '不明なカテゴリ';

  @override
  String get fixedTags_uncategorized => '未分類';

  @override
  String get fixedTags_clickManageLongPressSidebar =>
      'クリックして管理し、長押ししてサイドバーを開きます';

  @override
  String get fixedTags_clickManageLongPressCompact => 'クリックしてサイドバーを長押しして管理します';

  @override
  String get fixedTags_linked => 'リンクされました';

  @override
  String fixedTags_linkCount(Object count) {
    return '$count リンクされました';
  }

  @override
  String get fixedTags_expandNegative => '除外したい要素を展開';

  @override
  String get fixedTags_collapseNegative => '除外したい要素を折りたたむ';

  @override
  String get fixedTags_undoTooltip => '固定タグ操作を元に戻す';

  @override
  String get fixedTags_redoTooltip => '固定タグ操作をやり直す';

  @override
  String get fixedTags_positiveTitle => 'プロンプト固定タグ';

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
    return '$enabled/$total · $shown を表示中';
  }

  @override
  String get fixedTags_new => '新規';

  @override
  String fixedTags_newTarget(Object target) {
    return '新しい $target';
  }

  @override
  String get fixedTags_library => 'ライブラリ';

  @override
  String fixedTags_addFromLibraryToTarget(Object target) {
    return 'ライブラリから $target に追加します';
  }

  @override
  String get fixedTags_enableAll => 'すべて有効にする';

  @override
  String get fixedTags_disableAll => 'すべて無効にする';

  @override
  String fixedTags_searchTarget(Object target) {
    return '$target を検索...';
  }

  @override
  String get fixedTags_noMatching => '一致する固定タグがありません';

  @override
  String fixedTags_emptyTarget(Object target) {
    return '$target はありません';
  }

  @override
  String get fixedTags_dragToLink => 'ドラッグしてリンクを作成します';

  @override
  String fixedTags_linkedToNames(Object names) {
    return 'リンク済み: $names';
  }

  @override
  String get fixedTags_linkInstruction =>
      'リンク アイコンをプロンプト固定タグから除外したい要素固定タグにドラッグしてリンクを作成します';

  @override
  String get fixedTags_manageLinks => 'リンクの管理';

  @override
  String fixedTags_removeLink(Object name) {
    return 'リンクを削除: $name';
  }

  @override
  String get fixedTags_footerExpandedHint => '各列の先頭にあるライブラリから作成または追加します';

  @override
  String get fixedTags_newPositive => '新規プロンプト';

  @override
  String get fixedTags_addPositiveFromLibraryShort => 'ライブラリからプロンプト固定タグを追加';

  @override
  String get fixedTags_libraryEmpty => 'ライブラリが空です。最初にエントリを追加します';

  @override
  String get fixedTags_addFromLibrary => 'ライブラリから追加';

  @override
  String get fixedTags_searchLibraryEntries => 'ライブラリ エントリを検索します...';

  @override
  String get fixedTags_noMatchingResults => '一致する結果はありません';

  @override
  String get reversePrompt_title => '逆プロンプト';

  @override
  String get reversePrompt_pending => '保留中';

  @override
  String reversePrompt_imageCount(Object count) {
    return '$count 画像';
  }

  @override
  String get reversePrompt_llmReverse => 'LLM リバース';

  @override
  String get reversePrompt_characterReplace => 'キャラクター置換';

  @override
  String get reversePrompt_finalResult => '最終結果';

  @override
  String get reversePrompt_dropToAdd => '逆プロンプトに追加するには放します';

  @override
  String get reversePrompt_addOrDropImages => '画像を追加/画像をドロップ';

  @override
  String get reversePrompt_localTaggerModel => 'ローカルタガーモデル';

  @override
  String get reversePrompt_localTaggerModelHint => '設定でモデルフォルダーを構成します';

  @override
  String get reversePrompt_generalThreshold => '一般タグしきい値';

  @override
  String get reversePrompt_characterThreshold => 'キャラクタータグのしきい値';

  @override
  String get reversePrompt_taggerFilterHint =>
      '一般/キャラクタータグのみが出力されます。評価、アーティスト、著作権、メタ、その他のカテゴリはフィルターされます。';

  @override
  String get reversePrompt_replacementEmptyHint =>
      '置換対象キャラクターが選択されていません。ここでタグライブラリからキャラクターを選択します。プロンプトには挿入されません。';

  @override
  String get reversePrompt_selectReplacementCharacter =>
      '置換対象のキャラクターをライブラリから選択してください';

  @override
  String get reversePrompt_selectReplacementTargetTitle =>
      '置換対象キャラクターを選択してください';

  @override
  String get reversePrompt_change => '変更';

  @override
  String get reversePrompt_start => 'リバースプロンプトの開始';

  @override
  String get reversePrompt_sentToPrompt => 'プロンプトに送信されました';

  @override
  String get reversePrompt_sendToPrompt => 'プロンプトに送信';

  @override
  String get reversePrompt_externalTarget => 'マルチモーダル LLM リバース プロンプト サービス';

  @override
  String get reversePrompt_dropUnreadable =>
      'ドロップされたソースは、読み取り可能な画像ファイルまたは画像 URL を提供しませんでした';

  @override
  String get reversePrompt_needImageAndMethod =>
      '画像を追加し、少なくとも ONNX タガーまたは LLM リバース プロンプトを有効にしてください';

  @override
  String get reversePrompt_stagePreparing => '逆プロンプトを準備しています';

  @override
  String get reversePrompt_stageOnnxTagger => 'ONNX タガーのリバース プロンプト';

  @override
  String get reversePrompt_stageLlmReverse => 'LLM イメージの逆プロンプト';

  @override
  String get reversePrompt_stageCharacterReplace => 'キャラクターを置換します';

  @override
  String get reversePrompt_needReplacementCharacter =>
      '最初にリバースプロンプトのキャラクターライブラリから有効なキャラクターを選択してください';

  @override
  String get reversePrompt_needPromptForCharacterReplace =>
      'キャラクター置換には、最初にリバースプロンプトの結果が必要です';

  @override
  String get reversePrompt_noOnnxModel =>
      'ONNX タガー モデルが見つかりません。最初に設定でモデルフォルダーを構成します';

  @override
  String get promptAssistant_translateProcessing => '翻訳中';

  @override
  String get promptAssistant_optimizeProcessing => '最適化中';

  @override
  String get promptAssistant_characterReplaceProcessing => 'キャラクターを置換しています';

  @override
  String get promptAssistant_customProcessing => 'カスタムリクエストを処理しています';

  @override
  String get promptAssistant_imageInputDisabled =>
      '現在のカスタム タスク プロバイダーでは画像入力が有効になっていません';

  @override
  String get promptAssistant_needCharacter =>
      '先にリバースプロンプトのキャラクターライブラリに有効なキャラクターを追加してください';

  @override
  String get promptAssistant_assistantSettings => 'アシスタントの設定';

  @override
  String get promptAssistant_serviceSettings => 'サービス設定';

  @override
  String get promptAssistant_ruleSettings => 'ルール設定';

  @override
  String get promptAssistant_cancelCurrentTask => '現在のタスクをキャンセル';

  @override
  String get promptAssistant_collapseAssistant => 'アシスタントを折りたたむ';

  @override
  String get promptAssistant_expandAssistant => 'アシスタントを展開';

  @override
  String get promptAssistant_history => '履歴';

  @override
  String get promptAssistant_undo => '元に戻す';

  @override
  String get promptAssistant_redo => 'やり直し';

  @override
  String get promptAssistant_translate => '翻訳';

  @override
  String get promptAssistant_optimize => '最適化';

  @override
  String get promptAssistant_custom => 'カスタム';

  @override
  String get promptAssistant_characterReplace => 'キャラクター置換';

  @override
  String get promptAssistant_cancelTask => 'タスクのキャンセル';

  @override
  String get promptAssistant_menu => 'メニュー';

  @override
  String get promptAssistant_customDialogTitle => 'カスタム Prompt Assistant';

  @override
  String get promptAssistant_currentPrompt => '現在のプロンプト';

  @override
  String get promptAssistant_currentPromptEmpty => '(現在のプロンプトは空です)';

  @override
  String get promptAssistant_customRequestLabel => '変更リクエスト';

  @override
  String get promptAssistant_customRequestHint =>
      '例: より不気味にする、雨の夜の街の背景を追加する、アクションをよりダイナミックにする、最後のプロンプトのみを返す';

  @override
  String get promptAssistant_addReferenceImage => '参照画像を追加';

  @override
  String get promptAssistant_execute => '実行';

  @override
  String promptAssistant_maxReferenceImages(Object count) {
    return '最大 $count 個の参照画像を追加します';
  }

  @override
  String promptAssistant_unsupportedImageFormat(Object fileName) {
    return 'サポートされていない画像形式: $fileName';
  }

  @override
  String get promptAssistant_needCustomRequestOrImage =>
      'カスタムリクエストを入力するか、参照画像を追加してください';

  @override
  String get promptAssistant_taskOptimize => '最適化';

  @override
  String get promptAssistant_taskTranslate => '翻訳';

  @override
  String get promptAssistant_taskReverse => 'リバースプロンプト';

  @override
  String get promptAssistant_taskCharacterReplace => 'キャラクター置換';

  @override
  String get promptAssistant_taskCustom => 'カスタム';

  @override
  String get promptAssistant_settingsInputSwitchSubtitle =>
      'プロンプト入力の右下にあるアシスタント スイッチ';

  @override
  String get promptAssistant_desktopOverlayTitle => 'デスクトップ オーバーレイ インタラクション';

  @override
  String get promptAssistant_desktopOverlaySubtitle =>
      'ホバー、右クリック、およびショートカットの動作を有効にする';

  @override
  String get promptAssistant_taskRouting => 'タスク ルーティング';

  @override
  String get promptAssistant_taskRoutingSubtitle =>
      '最適化、翻訳、リバースプロンプト、キャラクター置換をさまざまなプロバイダーとモデルに割り当てます';

  @override
  String promptAssistant_taskRouteTitle(Object title) {
    return '$title タスク';
  }

  @override
  String get promptAssistant_provider => 'プロバイダー';

  @override
  String get promptAssistant_model => 'モデル';

  @override
  String get promptAssistant_noModelsPullFirst => 'モデルはまだありません。まずモデルリストを取得します';

  @override
  String get promptAssistant_providerManagement => 'プロバイダー管理';

  @override
  String get promptAssistant_providerManagementSubtitle =>
      'OpenAI Chat / Responses、Anthropic、Gemini、DeepSeek、LM Studio、Ollama、Pollinations、カスタム互換エンドポイントをサポート';

  @override
  String get promptAssistant_apiKeyConfigured => 'API キー: 設定済み';

  @override
  String get promptAssistant_apiKeyNotConfigured => 'API キー: 設定されていません';

  @override
  String get promptAssistant_supportsImageInput => '画像入力をサポート';

  @override
  String get promptAssistant_textOnly => 'テキストのみ';

  @override
  String get promptAssistant_connectionConfig => '接続構成';

  @override
  String get promptAssistant_pullModelList => 'モデルリストをプルします';

  @override
  String get promptAssistant_editProvider => 'プロバイダーの編集';

  @override
  String get promptAssistant_deleteProvider => 'プロバイダーを削除します';

  @override
  String get promptAssistant_pullingModels => 'モデル リストを取得しています...';

  @override
  String get promptAssistant_emptyModelList => 'プロバイダーが空のモデル リストを返しました';

  @override
  String promptAssistant_modelsSynced(Object count) {
    return '同期された $count モデル';
  }

  @override
  String promptAssistant_pullModelsFailed(Object error) {
    return 'モデルのプルに失敗しました: $error';
  }

  @override
  String get promptAssistant_ruleTemplates => 'ルール テンプレート';

  @override
  String get promptAssistant_ruleTemplatesSubtitle =>
      'システム プロンプトはルール + ユーザー入力 + タスク パラメーターとして組み立てられます';

  @override
  String get promptAssistant_addRule => 'ルールの追加';

  @override
  String get promptAssistant_addProvider => 'プロバイダーの追加';

  @override
  String get promptAssistant_editProviderTitle => 'プロバイダーの編集';

  @override
  String get promptAssistant_name => '名前';

  @override
  String get promptAssistant_protocol => 'プロトコル';

  @override
  String get promptAssistant_allowImageInput => '画像入力を許可します';

  @override
  String get promptAssistant_allowImageInputSubtitle =>
      'モデルとプロバイダーが実際にビジョン入力をサポートしている場合にのみ有効になります';

  @override
  String get promptAssistant_apiKeyLeaveEmpty => 'API キー (変更しない場合は空のままにします)';

  @override
  String promptAssistant_connectionTitle(Object name) {
    return '$name 接続構成';
  }

  @override
  String get promptAssistant_baseUrlHint => '例: https://api.openai.com/v1';

  @override
  String get promptAssistant_clearCurrentApiKey => '現在の API キーをクリアします';

  @override
  String get promptAssistant_protocolSupportsImagePayload =>
      '現在のプロトコルは画像ペイロードをサポートしています。モデル自体は引き続きビジョン入力をサポートする必要があります';

  @override
  String get promptAssistant_protocolTextOnlyWarning =>
      '現在のプロトコルはデフォルトではテキストのみです。これを有効にしてもサーバーによって拒否される可能性があります';

  @override
  String get promptAssistant_addRuleTitle => 'ルールの追加';

  @override
  String get promptAssistant_editRuleTitle => 'ルールの編集';

  @override
  String get promptAssistant_taskType => 'タスクの種類';

  @override
  String get promptAssistant_ruleContent => 'ルールの内容';

  @override
  String get promptAssistant_newRule => '新しいルール';

  @override
  String autocomplete_resultsCount(Object count) {
    return '$count 結果';
  }

  @override
  String get autocomplete_keyNavigate => '↑↓/スクロール';

  @override
  String get autocomplete_actionSelect => '選択してください';

  @override
  String get autocomplete_actionConfirm => '確認';

  @override
  String get autocomplete_actionClose => '閉じる';

  @override
  String get autocomplete_categoryRecommended => '推奨';

  @override
  String get autocomplete_categoryCharacter => 'キャラクター';

  @override
  String get autocomplete_categoryCopyright => '著作権';

  @override
  String get autocomplete_categoryArtist => 'アーティスト';

  @override
  String get autocomplete_categoryMeta => 'メタ';

  @override
  String get autocomplete_categoryLibrary => 'ライブラリ';

  @override
  String get autocomplete_categoryGeneral => '一般';

  @override
  String get promptToken_webCalibration => 'Web キャリブレーション';

  @override
  String get promptToken_prompt => 'プロンプト';

  @override
  String get promptToken_fixedTags => '固定タグ';

  @override
  String get promptToken_qualityPreset => '品質プリセット';

  @override
  String get promptToken_character => 'キャラクター';

  @override
  String get promptToken_negativePrompt => '除外したい要素';

  @override
  String get promptToken_negativeFixedTags => '除外したい要素固定タグ';

  @override
  String get promptToken_negativePreset => '除外したい要素プリセット';

  @override
  String get promptToken_characterNegative => 'キャラクター除外要素';

  @override
  String get common_rename => '名前の変更';

  @override
  String get common_create => '作成';

  @override
  String get tagLibrary_categories => 'カテゴリ';

  @override
  String get tagLibrary_newCategory => '新しいカテゴリ';

  @override
  String get tagLibrary_addEntry => 'エントリの追加';

  @override
  String get tagLibrary_editEntry => 'エントリーの編集';

  @override
  String get tagLibrary_searchHint => 'エントリを検索...';

  @override
  String get tagLibrary_cardView => 'カードビュー';

  @override
  String get tagLibrary_listView => 'リストビュー';

  @override
  String get tagLibrary_import => 'インポート';

  @override
  String get tagLibrary_export => 'エクスポート';

  @override
  String get tagLibrary_sortCustom => 'カスタム並べ替え';

  @override
  String get tagLibrary_sortName => '名前';

  @override
  String get tagLibrary_sortUseCount => '使用回数';

  @override
  String get tagLibrary_sortUpdatedAt => '更新日時';

  @override
  String get tagLibrary_transferCategory => 'カテゴリを移動';

  @override
  String get tagLibrary_copyContent => 'コンテンツをコピー';

  @override
  String get tagLibrary_moveToCategoryTitle => 'カテゴリに移動';

  @override
  String get tagLibrary_selectTargetCategory => 'ターゲット カテゴリを選択してください:';

  @override
  String get tagLibrary_includeThumbnails => 'サムネイルを含める';

  @override
  String get tagLibrary_includeThumbnailsSubtitle => 'ファイルサイズが増加します';

  @override
  String tagLibrary_selectedExportCount(Object count) {
    return 'エクスポート ($count アイテム)';
  }

  @override
  String tagLibrary_selectedImportCount(Object count) {
    return 'インポート ($count アイテム)';
  }

  @override
  String get tagLibrary_entriesLabel => 'エントリ';

  @override
  String get tagLibrary_categoriesLabel => 'カテゴリ';

  @override
  String get tagLibrary_selectExportContent => 'エクスポートするコンテンツを選択してください';

  @override
  String get tagLibrary_selectImportContent => 'インポートするコンテンツを選択してください';

  @override
  String get tagLibrary_selectSaveLocation => '保存場所を選択してください';

  @override
  String get tagLibrary_preparingExport => 'エクスポートを準備しています...';

  @override
  String get tagLibrary_exportSuccess => 'エクスポートが成功しました';

  @override
  String tagLibrary_exportFailedWithError(Object error) {
    return 'エクスポートに失敗しました: $error';
  }

  @override
  String get tagLibrary_selectZipFile => 'クリックして ZIP ファイルを選択してください';

  @override
  String get tagLibrary_zipFileHint => 'このアプリからエクスポートされたライブラリ ファイルをサポートします';

  @override
  String get tagLibrary_reselect => 'もう一度選択してください';

  @override
  String get tagLibrary_fileInfo => 'ファイル情報';

  @override
  String get tagLibrary_entryCountLabel => 'エントリ';

  @override
  String get tagLibrary_categoryCountLabel => 'カテゴリ';

  @override
  String get tagLibrary_exportDateLabel => 'エクスポート日';

  @override
  String tagLibrary_importConflictsHint(Object count) {
    return '$count の競合が見つかりました。以下の競合する項目をクリックして、その処理方法を選択します。';
  }

  @override
  String tagLibrary_categoriesSection(Object count) {
    return 'カテゴリ ($count)';
  }

  @override
  String tagLibrary_entriesSection(Object count) {
    return 'エントリ ($count)';
  }

  @override
  String get tagLibrary_conflictResolutionTooltip => '競合処理を選択してください';

  @override
  String get tagLibrary_conflictSkip => '競合 - スキップします';

  @override
  String get tagLibrary_conflictRename => '競合 - 名前を変更してインポートします';

  @override
  String get tagLibrary_conflictOverwrite => '競合 - 既存のものを置き換えます';

  @override
  String tagLibrary_parseFileFailed(Object error) {
    return 'ファイルを解析できません: $error';
  }

  @override
  String get tagLibrary_preparingImport => 'インポートを準備しています...';

  @override
  String get tagLibrary_importCompleted => 'インポートが完了しました';

  @override
  String tagLibrary_importSuccessSummary(Object summary) {
    return 'インポートが成功しました: $summary';
  }

  @override
  String tagLibrary_importFailedWithError(Object error) {
    return 'インポートに失敗しました: $error';
  }

  @override
  String tagLibrary_importedEntriesCount(Object count) {
    return '$count エントリ';
  }

  @override
  String tagLibrary_importedCategoriesCount(Object count) {
    return '$count カテゴリ';
  }

  @override
  String tagLibrary_renamedCount(Object count) {
    return '$count の名前が変更されました';
  }

  @override
  String tagLibrary_overwrittenCount(Object count) {
    return '$count が置き換えられました';
  }

  @override
  String tagLibrary_skippedCount(Object count) {
    return '$count はスキップされました';
  }

  @override
  String get tagLibrary_dragToCategoryHint => 'カテゴリ パネルにドラッグしてファイルします';

  @override
  String get tagLibrary_unknownCategory => '不明なカテゴリ';

  @override
  String get tagLibrary_selectEntryToUpdate => '更新するエントリを選択してください';

  @override
  String get tagLibrary_updatePreview => 'プレビューを更新';

  @override
  String get tagLibrary_replaceThumbnailHint => '既存のサムネイルを置き換えます';

  @override
  String tagLibrary_sentEntriesToMainPrompt(Object count) {
    return '$count エントリをメイン プロンプトに送信しました';
  }

  @override
  String tagLibrary_confirmDeleteSelectedEntries(Object count) {
    return '$count 選択したエントリを削除しますか?この操作は元に戻すことができません。';
  }

  @override
  String tagLibrary_deletedEntries(Object count) {
    return '$count エントリを削除しました';
  }

  @override
  String tagLibrary_movedEntries(Object count) {
    return '$count エントリを移動しました';
  }

  @override
  String tagLibrary_favoritedEntries(Object count) {
    return '$count 件のエントリをお気に入りに追加しました';
  }

  @override
  String tagLibrary_unfavoritedEntries(Object count) {
    return '$count 件のエントリをお気に入りから削除しました';
  }

  @override
  String tagLibrary_copiedEntriesContent(Object count) {
    return '$count エントリからコンテンツをコピーしました';
  }

  @override
  String get tagLibrary_droppedImage => 'ドロップされた画像';

  @override
  String get tagLibrary_createEntryFromImage => '新しいエントリの作成';

  @override
  String tagLibrary_promptExtracted(Object prompt) {
    return '抽出されたプロンプト: \"$prompt\"';
  }

  @override
  String get tagLibrary_createEntryFromImageSubtitle => 'この画像から新しいエントリを作成します';

  @override
  String get tagLibrary_updateExistingThumbnail => '既存のエントリのサムネイルを更新';

  @override
  String get tagLibrary_updateExistingThumbnailSubtitle =>
      'エントリを選択し、そのサムネイルを置き換えます';

  @override
  String get tagLibrary_allEntries => 'すべて';

  @override
  String get tagLibrary_favorites => 'お気に入り';

  @override
  String get tagLibrary_addSubCategory => 'サブカテゴリを追加';

  @override
  String get tagLibrary_moveToRoot => 'ルートに移動';

  @override
  String get tagLibrary_categoryNameHint => 'カテゴリ名を入力してください';

  @override
  String get tagLibrary_deleteCategoryTitle => 'カテゴリを削除';

  @override
  String tagLibrary_deleteCategoryConfirm(Object name, Object count) {
    return 'カテゴリ「$name」を削除してもよろしいですか? $count エントリはルートに移動されます。';
  }

  @override
  String get tagLibrary_deleteEntryTitle => 'エントリの削除';

  @override
  String tagLibrary_deleteEntryConfirm(Object name) {
    return 'エントリ「$name」を削除してもよろしいですか?';
  }

  @override
  String get tagLibrary_noSearchResults => '一致するエントリが見つかりませんでした';

  @override
  String get tagLibrary_tryDifferentSearch => '別のキーワードを試してください';

  @override
  String get tagLibrary_categoryEmpty => 'このカテゴリは空です';

  @override
  String get tagLibrary_empty => 'ライブラリが空です';

  @override
  String get tagLibrary_addFirstEntry => '上のボタンをクリックして最初のエントリを追加してください';

  @override
  String get tagLibraryPicker_title => 'エントリの選択';

  @override
  String get tagLibraryPicker_searchHint => 'エントリを検索...';

  @override
  String get tagLibraryPicker_allCategories => 'すべてのカテゴリ';

  @override
  String get tagLibrary_addToFixed => '固定タグに追加';

  @override
  String get tagLibrary_addedToFixed => '固定タグに追加';

  @override
  String get tagLibrary_entryMoved => 'エントリがターゲット カテゴリに移動されました';

  @override
  String tagLibrary_useCount(Object count) {
    return '$count 回使用されました';
  }

  @override
  String get tagLibrary_removeFavorite => 'お気に入りから削除';

  @override
  String get tagLibrary_addFavorite => 'お気に入りに追加';

  @override
  String get tagLibrary_pinned => 'お気に入りに登録しました';

  @override
  String get tagLibrary_thumbnail => 'サムネイル';

  @override
  String get tagLibrary_selectImage => '画像を選択してください';

  @override
  String get tagLibrary_thumbnailHint => 'PNG/JPG/WEBP をサポート';

  @override
  String get tagLibrary_name => '名前';

  @override
  String get tagLibrary_nameHint => 'エントリ名を入力してください';

  @override
  String get tagLibrary_category => 'カテゴリ';

  @override
  String get tagLibrary_rootCategory => 'ルート';

  @override
  String get tagLibrary_tags => 'タグ';

  @override
  String get tagLibrary_tagsHint => 'タグをカンマで区切って入力します';

  @override
  String get tagLibrary_tagsHelper => 'タグはフィルタリングと検索に使用されます';

  @override
  String get tagLibrary_content => 'プロンプトの内容';

  @override
  String get tagLibrary_contentHint => 'プロンプトの内容を入力し、オートコンプリートをサポートします';

  @override
  String get settings_network => 'ネットワーク';

  @override
  String get settings_enableProxy => 'プロキシを有効にする';

  @override
  String get settings_proxyEnabled => '有効';

  @override
  String get settings_proxyDisabled => '直接接続';

  @override
  String get settings_proxyTrafficDisclosure =>
      'プロキシを有効にすると、認証リクエストを含む NovelAI API トラフィックはシステムまたは手動プロキシ経由で送信されます。信頼できるプロキシのみを使用してください。';

  @override
  String get settings_proxyMode => 'プロキシ モード';

  @override
  String get settings_proxyModeAuto => 'システム プロキシの自動検出';

  @override
  String get settings_proxyModeManual => '手動構成';

  @override
  String get settings_auto => '自動';

  @override
  String get settings_manual => '手動';

  @override
  String get settings_proxyHost => 'プロキシ ホスト';

  @override
  String get settings_proxyPort => 'ポート';

  @override
  String get settings_proxyNotDetected => 'システム プロキシが検出されませんでした';

  @override
  String get settings_testConnection => 'テスト接続';

  @override
  String get settings_testConnectionHint => 'クリックしてプロキシが機能しているかどうかをテストします';

  @override
  String settings_testSuccess(Object latency) {
    return '接続成功 ($latencyミリ秒)';
  }

  @override
  String settings_testFailed(Object error) {
    return '接続に失敗しました: $error';
  }

  @override
  String get settings_proxyRestartHint => 'プロキシ設定が変更されました。再起動をお勧めします';

  @override
  String get tagLibrary_categoryNameExists => 'カテゴリ名はすでに存在します';

  @override
  String get tagLibrary_addToLibrary => 'ライブラリに追加';

  @override
  String get tagLibrary_saveToLibrary => 'ライブラリに保存';

  @override
  String get tagLibrary_entrySaved => 'ライブラリに保存されました';

  @override
  String get tagLibrary_entryUpdated => 'エントリが更新されました';

  @override
  String get tagLibrary_uncategorized => '未分類';

  @override
  String get tagLibrary_contentPreview => 'コンテンツのプレビュー';

  @override
  String get tagLibrary_confirmAdd => '確認';

  @override
  String get tagLibrary_entryName => '名前';

  @override
  String get tagLibrary_entryNameHint => 'エントリ名を入力してください';

  @override
  String get tagLibrary_selectNewImage => '新しい画像を選択してください';

  @override
  String get tagLibrary_adjustDisplayRange => '表示範囲の調整';

  @override
  String get tagLibrary_adjustThumbnailTitle => 'サムネイル表示範囲の調整';

  @override
  String get tagLibrary_dragToMove => 'ドラッグして移動、スクロールまたはピンチしてズームします';

  @override
  String get tagLibrary_livePreview => 'ライブ プレビュー';

  @override
  String get tagLibrary_horizontalOffset => '水平オフセット';

  @override
  String get tagLibrary_verticalOffset => '垂直オフセット';

  @override
  String get tagLibrary_zoom => 'ズーム';

  @override
  String get tagLibrary_zoomRatio => 'ズーム率';

  @override
  String get queue_title => 'キュー';

  @override
  String get queue_management => 'キュー管理';

  @override
  String get queue_empty => 'キューが空です';

  @override
  String get queue_emptyHint => 'キューにタスクがありません';

  @override
  String queue_taskCount(Object count) {
    return '$count タスク';
  }

  @override
  String get queue_pending => '保留中';

  @override
  String get queue_running => '実行中';

  @override
  String get queue_completed => '完了しました';

  @override
  String get queue_failed => '失敗しました';

  @override
  String get queue_skipped => 'スキップされました';

  @override
  String get queue_paused => '一時停止しました';

  @override
  String get queue_idle => 'アイドル状態';

  @override
  String get queue_ready => '準備完了';

  @override
  String get queue_clickToStart => 'クリックしてキューの実行を開始します';

  @override
  String get queue_clickToPause => 'クリックしてキューを一時停止します';

  @override
  String get queue_clickToResume => 'クリックして実行を再開します';

  @override
  String get queue_noTasksToStart => 'キューが空のため開始できません';

  @override
  String get queue_allTasksCompleted => 'すべてのタスクが完了しました';

  @override
  String get queue_executionProgress => '実行の進行状況';

  @override
  String get queue_totalTasks => '合計';

  @override
  String get queue_completedTasks => '完了しました';

  @override
  String get queue_failedTasks => '失敗しました';

  @override
  String get queue_remainingTasks => '残り';

  @override
  String queue_estimatedTime(Object time) {
    return '推定: 約 $time';
  }

  @override
  String queue_seconds(Object count) {
    return '$count 秒';
  }

  @override
  String queue_minutes(Object count) {
    return '$count 分';
  }

  @override
  String queue_hours(Object hours, Object minutes) {
    return '$hours 時間 $minutes 分';
  }

  @override
  String get queue_pause => '一時停止';

  @override
  String get queue_resume => '再開';

  @override
  String get queue_pauseExecution => '実行を一時停止します';

  @override
  String get queue_resumeExecution => '実行を再開';

  @override
  String get queue_autoExecute => '自動実行';

  @override
  String get queue_autoExecuteOn => '完了時に次のタスクを自動的に実行';

  @override
  String get queue_autoExecuteOff => '生成するには手動でクリックする必要があります';

  @override
  String get queue_taskInterval => 'タスク間隔';

  @override
  String get queue_taskIntervalHint => 'タスク間の待機時間 (0 ～ 10 秒)';

  @override
  String get queue_clearQueue => 'キューをクリアします';

  @override
  String get queue_closeFloatingButton => 'フローティング ボタンを閉じる';

  @override
  String get queue_clearQueueConfirm =>
      'すべてのキュー タスクをクリアしてもよろしいですか?この操作は元に戻すことができません。';

  @override
  String get queue_confirmClear => 'クリアの確認';

  @override
  String get queue_failureStrategy => '失敗戦略';

  @override
  String get queue_failureStrategyAutoRetry => '自動再試行';

  @override
  String get queue_failureStrategyAutoRetryDesc => '最大再試行後にタスクをキューの最後に移動します';

  @override
  String get queue_failureStrategySkip => 'スキップ';

  @override
  String get queue_failureStrategySkipDesc => '失敗したタスクを失敗したプールに移動し、次へ続行します';

  @override
  String get queue_failureStrategyPause => '一時停止して待ちます';

  @override
  String get queue_failureStrategyPauseDesc => 'キューを一時停止し、手動処理を待ちます';

  @override
  String queue_retryCount(Object current, Object max) {
    return '再試行 $current/$max';
  }

  @override
  String get queue_retry => '再試行';

  @override
  String get queue_requeue => '再キューイング';

  @override
  String get queue_requeueToEnd => 'キューの最後に移動';

  @override
  String get queue_clearFailedTasks => 'すべてクリア';

  @override
  String get queue_noFailedTasks => '失敗したタスクはありません';

  @override
  String get queue_noCompletedTasks => '完了したレコードはありません';

  @override
  String get queue_editTask => 'タスクの編集';

  @override
  String get queue_duplicateTask => 'タスクを複製';

  @override
  String get queue_taskDuplicated => 'タスクが重複しました';

  @override
  String get queue_queueFull => 'キューがいっぱいなので複製できません';

  @override
  String get queue_positivePrompt => 'プロンプト';

  @override
  String get queue_enterPositivePrompt => 'プロンプトを入力してください...';

  @override
  String get queue_parametersPreview => 'パラメータのプレビュー';

  @override
  String get queue_model => 'モデル';

  @override
  String get queue_seed => 'シード';

  @override
  String get queue_sampler => 'サンプラー';

  @override
  String get queue_steps => 'ステップ';

  @override
  String get queue_cfg => 'CFG';

  @override
  String get queue_size => 'サイズ';

  @override
  String get queue_addToQueue => 'キューに追加';

  @override
  String get queue_taskAdded => 'キューに追加されました';

  @override
  String get queue_negativePromptFromMain => '除外したい要素にはメインページの設定が使用されます';

  @override
  String get queue_pinToTop => 'トップに固定する';

  @override
  String get queue_delete => '削除';

  @override
  String get queue_edit => '編集';

  @override
  String get queue_selectAll => 'すべて選択';

  @override
  String get queue_invertSelection => '反転';

  @override
  String get queue_cancelSelection => 'キャンセル';

  @override
  String queue_selectedCount(Object count) {
    return '$count が選択されました';
  }

  @override
  String get queue_batchDelete => '選択したものを削除';

  @override
  String get queue_batchPinToTop => '選択項目を先頭に固定';

  @override
  String queue_confirmDeleteSelected(Object count) {
    return '$count 個の選択したタスクを削除してもよろしいですか?';
  }

  @override
  String get queue_export => 'エクスポート';

  @override
  String get queue_import => 'インポート';

  @override
  String get queue_exportImport => 'キューのインポート/エクスポート';

  @override
  String get queue_exportFormat => 'エクスポート形式';

  @override
  String get queue_exportFormatJson => 'JSON';

  @override
  String get queue_exportFormatJsonDesc => 'すべてのパラメータを含む完全なデータ';

  @override
  String get queue_exportFormatCsv => 'CSV';

  @override
  String get queue_exportFormatCsvDesc => 'プロンプトと基本情報を含むテーブル形式';

  @override
  String get queue_exportFormatText => 'プレーンテキスト';

  @override
  String get queue_exportFormatTextDesc => 'プロンプトのみ、1 行に 1 つ';

  @override
  String get queue_importStrategy => 'インポート戦略';

  @override
  String get queue_importStrategyMerge => 'マージ';

  @override
  String get queue_importStrategyMergeDesc => 'インポートされたタスクを既存のキューの最後に追加します';

  @override
  String get queue_importStrategyReplace => '置換';

  @override
  String get queue_importStrategyReplaceDesc =>
      '既存のキューをクリアし、インポートされたキューと置き換えます';

  @override
  String get queue_supportedFormats => 'サポートされている形式:';

  @override
  String get queue_supportedFormatJson => '• JSON ファイル (.json)';

  @override
  String get queue_supportedFormatCsv => '• CSV ファイル (.csv)';

  @override
  String get queue_supportedFormatText =>
      '• プレーン テキスト ファイル (.txt) - 1 行に 1 つのプロンプト';

  @override
  String get queue_shareSubject => 'キューのエクスポート';

  @override
  String queue_unsupportedFileFormat(Object extension) {
    return 'サポートされていないファイル形式: $extension';
  }

  @override
  String get queue_exportSuccess => 'エクスポートが成功しました';

  @override
  String queue_exportFailed(Object error) {
    return 'エクスポートに失敗しました: $error';
  }

  @override
  String queue_importSuccess(Object count) {
    return '$count タスクが正常にインポートされました';
  }

  @override
  String queue_importFailed(Object error) {
    return 'インポートに失敗しました: $error';
  }

  @override
  String get queue_selectFile => 'インポートするファイルを選択してください';

  @override
  String get queue_noValidTasks => 'ファイル内に有効なタスクがありません';

  @override
  String get queue_settings => 'キュー設定';

  @override
  String get settings_queueRetryCount => '再試行回数';

  @override
  String get settings_queueRetryInterval => '再試行間隔';

  @override
  String get settings_queueRetryCountSubtitle => '失敗したタスクの最大再試行回数';

  @override
  String get settings_queueRetryIntervalSubtitle => '再試行間の待機時間';

  @override
  String get settings_showRandomPromptTools => 'ランダムプロンプトツールを表示';

  @override
  String get settings_showRandomPromptToolsSubtitle =>
      '生成ページにランダムプロンプトボタンと Random Mode の切り替えを表示します';

  @override
  String get settings_enablePromptWeightScroll => 'マウスホイールでプロンプトの重みを調整';

  @override
  String get settings_enablePromptWeightScrollSubtitle =>
      'プロンプトを選択している間は、ホイールで重みだけを調整し、ページスクロールなどの操作は行いません。';

  @override
  String settings_queueRetryCountMax(Object count) {
    return '最大 $count 回';
  }

  @override
  String settings_queueRetryIntervalValue(Object seconds) {
    return '$seconds 秒';
  }

  @override
  String get unit_times => '回';

  @override
  String get unit_seconds => '秒';

  @override
  String get settings_floatingButtonBackground => 'フローティング ボタンの背景';

  @override
  String get settings_floatingButtonBackgroundCustom => 'カスタム背景を設定済み';

  @override
  String get settings_floatingButtonBackgroundDefault => 'デフォルトのスタイル';

  @override
  String get settings_clearBackground => '背景をクリア';

  @override
  String get settings_selectImage => '画像を選択してください';

  @override
  String queue_currentQueueInfo(Object count) {
    return '現在のキューには $count タスクが含まれています';
  }

  @override
  String queue_tooltipTasksTotal(Object count) {
    return 'タスク: $count';
  }

  @override
  String queue_tooltipCompleted(Object count) {
    return '完了: $count';
  }

  @override
  String queue_tooltipFailed(Object count) {
    return '失敗しました: $count';
  }

  @override
  String queue_tooltipCurrentTask(Object task) {
    return '現在: $task';
  }

  @override
  String get queue_tooltipNoTasks => 'キューにタスクがありません';

  @override
  String get queue_tooltipDoubleClickToOpen => 'ダブルクリックして開始/一時停止します';

  @override
  String get queue_tooltipClickToToggle => 'クリックしてキューを開きます';

  @override
  String get queue_tooltipDragToMove => 'ドラッグして位置を変更します';

  @override
  String get queue_statusIdle => 'ステータス: アイドル';

  @override
  String get queue_statusReady => 'ステータス: 準備完了';

  @override
  String get queue_statusRunning => 'ステータス: 実行中';

  @override
  String get queue_statusPaused => 'ステータス: 一時停止中';

  @override
  String get queue_statusCompleted => 'ステータス: 完了';

  @override
  String get settings_notification => 'サウンド';

  @override
  String get settings_notificationSound => '完了音';

  @override
  String get settings_notificationSoundSubtitle => '生成完了時にサウンドを再生する';

  @override
  String get settings_notificationCustomSound => 'カスタムサウンド';

  @override
  String get settings_notificationCustomSoundSubtitle =>
      'カスタムサウンドファイルを選択してください';

  @override
  String get settings_notificationSelectSound => 'サウンドの選択';

  @override
  String get settings_notificationResetSound => 'デフォルトにリセット';

  @override
  String get categoryConfiguration => 'カテゴリ構成';

  @override
  String get resetToDefault => 'デフォルトにリセット';

  @override
  String get resetToDefaultTooltip => 'デフォルト構成にリセット';

  @override
  String get resetToDefaultConfirmTitle => 'デフォルトにリセット';

  @override
  String get resetToDefaultConfirmContent =>
      'これにより、公式のデフォルト構成が復元されます。カスタム グループは保持されますが、無効になります。';

  @override
  String get groupEnabled => 'グループが有効になりました';

  @override
  String get groupDisabled => 'グループが無効になりました';

  @override
  String get toggleGroupEnabled => 'グループ有効状態の切り替え';

  @override
  String get diyNotAvailableForDefault => 'DIY はデフォルトのプリセットでは使用できません';

  @override
  String get diyNotAvailableHint => '編集するにはカスタム プリセットにコピーしてください';

  @override
  String get customGroupDisabledAfterReset => 'カスタム グループ (無効)';

  @override
  String get confirmReset => 'リセットの確認';

  @override
  String get alias_hintText => 'プロンプトを入力するか、<ライブラリ名> を使用してライブラリのコンテンツを参照してください';

  @override
  String get alias_libraryCategory => 'ライブラリ';

  @override
  String alias_tagCount(Object count) {
    return '$count タグ';
  }

  @override
  String alias_useCount(Object count) {
    return '$count 回使用されました';
  }

  @override
  String get alias_favorited => 'お気に入りに登録しました';

  @override
  String get statistics_heatmapLess => '少ない';

  @override
  String get statistics_heatmapMore => '多い';

  @override
  String get statistics_heatmapWeekLabel => '週';

  @override
  String statistics_heatmapActivities(Object count) {
    return '$count アクティビティ';
  }

  @override
  String get statistics_heatmapNoActivity => 'アクティビティはありません';

  @override
  String get sendToHome_dialogTitle => 'ホームに送信';

  @override
  String get sendToHome_send => '送信';

  @override
  String get sendToHome_mainPrompt => 'メイン プロンプトに送信';

  @override
  String get sendToHome_mainPromptSubtitle => 'メイン プロンプト入力フィールドに入力します';

  @override
  String get sendToHome_mainPromptPipeSubtitle =>
      '完全なコンテンツをメイン プロンプトに送信します (パイプを含む)';

  @override
  String get sendToHome_smartDecompose => 'スマート分解';

  @override
  String sendToHome_smartDecomposeSubtitle(Object count) {
    return 'メインプロンプト + $count キャラクター';
  }

  @override
  String get sendToHome_replaceCharacter => 'キャラクタープロンプトを置換';

  @override
  String get sendToHome_replaceCharacterSubtitle => '既存のキャラクターをクリアして新規として追加';

  @override
  String get sendToHome_appendCharacter => 'キャラクタープロンプトを追加';

  @override
  String get sendToHome_appendCharacterSubtitle =>
      '既存のキャラクターを保持し、新しいキャラクターを追加します';

  @override
  String get sendToHome_fixedTags => '固定タグに送信';

  @override
  String get sendToHome_fixedTagsSubtitle => '固定タグリストに追加';

  @override
  String get sendToHome_sendAsAlias => 'エイリアスとして送信';

  @override
  String sendToHome_sendAsAliasSubtitle(Object name) {
    return '自宅に送信する場合は <$name> としてラップします';
  }

  @override
  String get sendToHome_preview => 'プレビューを送信';

  @override
  String get sendToHome_characterPrompt => 'キャラクタープロンプト';

  @override
  String sendToHome_characterPromptCount(Object count) {
    return 'キャラクタープロンプト ($count)';
  }

  @override
  String sendToHome_characterIndex(Object index) {
    return 'キャラクター $index';
  }

  @override
  String get sendToHome_recommended => '推奨';

  @override
  String get sendToHome_successMainPrompt => 'メイン プロンプトに送信されます';

  @override
  String get sendToHome_successReplaceCharacter => 'キャラクタープロンプトを置換しました';

  @override
  String get sendToHome_successAppendCharacter => 'キャラクタープロンプトを追加しました';

  @override
  String get metadataImport_title => 'インポートするパラメータを選択してください';

  @override
  String get metadataImport_promptsSection => 'プロンプト';

  @override
  String get metadataImport_generationSection => '生成パラメータ';

  @override
  String get metadataImport_advancedSection => '詳細オプション';

  @override
  String get metadataImport_selectAll => 'すべて選択';

  @override
  String get metadataImport_deselectAll => 'すべての選択を解除';

  @override
  String get metadataImport_promptsOnly => 'プロンプトのみ';

  @override
  String get metadataImport_generationOnly => 'パラメータのみ';

  @override
  String get metadataImport_clear => 'クリア';

  @override
  String get metadataImport_prompt => 'プロンプト';

  @override
  String get metadataImport_mainPrompt => 'メイン プロンプト';

  @override
  String get metadataImport_fixedTags => '固定タグ';

  @override
  String metadataImport_fixedPrefix(Object text) {
    return 'プレフィックス: $text';
  }

  @override
  String metadataImport_fixedSuffix(Object text) {
    return 'サフィックス: $text';
  }

  @override
  String metadataImport_negativeFixedPrefix(Object text) {
    return '除外したい要素プレフィックス: $text';
  }

  @override
  String metadataImport_negativeFixedSuffix(Object text) {
    return '除外したい要素サフィックス: $text';
  }

  @override
  String metadataImport_qualityTagsCount(int count) {
    return '品質タグ ($count)';
  }

  @override
  String get metadataImport_negativePrompt => '除外したい要素';

  @override
  String get metadataImport_characterPrompts => 'キャラクタープロンプト';

  @override
  String metadataImport_characterPromptsCount(int count) {
    return 'キャラクタープロンプト ($count)';
  }

  @override
  String metadataImport_characterIndex(int index, Object text) {
    return 'キャラクター $index: $text';
  }

  @override
  String get metadataImport_referenceSection => '参照';

  @override
  String metadataImport_countUnit(int count) {
    return '$count';
  }

  @override
  String metadataImport_preciseReferenceCount(int count) {
    return '精密参照 ($count)';
  }

  @override
  String metadataImport_vibeDetail(Object name, Object strength, Object info) {
    return '$name (参照強度 $strength%、抽出情報 $info%)';
  }

  @override
  String metadataImport_preciseReferenceDetail(
    int index,
    Object type,
    Object strength,
    Object fidelity,
  ) {
    return '参照 $index: $type (強度 $strength%、忠実度 $fidelity%)';
  }

  @override
  String get metadataImport_seed => 'シード';

  @override
  String get metadataImport_steps => 'ステップ数';

  @override
  String get metadataImport_scale => 'CFG スケール';

  @override
  String get metadataImport_size => 'サイズ';

  @override
  String get metadataImport_sampler => 'サンプラー';

  @override
  String get metadataImport_model => 'モデル';

  @override
  String get metadataImport_smea => 'SMEA';

  @override
  String get metadataImport_smeaDyn => 'SMEA Dyn';

  @override
  String get metadataImport_noiseSchedule => 'ノイズスケジュール';

  @override
  String get metadataImport_cfgRescale => 'CFG リスケール';

  @override
  String get metadataImport_qualityToggle => '品質切り替え';

  @override
  String get metadataImport_ucPreset => '除外したい要素プリセット';

  @override
  String get metadataImport_noData => '(データなし)';

  @override
  String metadataImport_selectedCount(int count) {
    return '$count が選択されました';
  }

  @override
  String get metadataImport_noDataFound => 'NovelAI メタデータが見つかりませんでした';

  @override
  String get metadataImport_noParamsSelected => 'パラメータが選択されていません';

  @override
  String metadataImport_appliedCount(int count) {
    return '適用された $count パラメータ';
  }

  @override
  String get metadataImport_appliedTitle => 'メタデータが適用されました';

  @override
  String get metadataImport_appliedDescription => '次のパラメータが適用されました:';

  @override
  String get metadataImport_charactersCount => 'キャラクター';

  @override
  String metadataImport_extractFailed(String error) {
    return 'メタデータの抽出に失敗しました: $error';
  }

  @override
  String metadataImport_appliedToMain(int count) {
    return '$count パラメータをメイン画面に適用しました';
  }

  @override
  String get metadataImport_quickSelectHint =>
      '上のボタンをクリックしてパラメータ タイプをすばやく選択してください';

  @override
  String get shortcut_context_global => 'グローバル';

  @override
  String get shortcut_context_generation => '生成';

  @override
  String get shortcut_context_gallery => 'ギャラリーリスト';

  @override
  String get shortcut_context_viewer => '画像ビューア';

  @override
  String get shortcut_context_tag_library => 'タグ ライブラリ';

  @override
  String get shortcut_context_random_config => 'ランダム構成';

  @override
  String get shortcut_context_settings => '設定';

  @override
  String get shortcut_context_input => '入力フィールド';

  @override
  String get shortcut_action_navigate_to_generation => '生成ページ';

  @override
  String get shortcut_action_navigate_to_local_gallery => 'ローカル ギャラリー';

  @override
  String get shortcut_action_navigate_to_online_gallery => 'オンライン ギャラリー';

  @override
  String get shortcut_action_navigate_to_random_config => 'ランダム構成';

  @override
  String get shortcut_action_navigate_to_tag_library => 'タグ ライブラリ';

  @override
  String get shortcut_action_navigate_to_statistics => '統計';

  @override
  String get shortcut_action_navigate_to_settings => '設定';

  @override
  String get shortcut_action_generate_image => '画像の生成';

  @override
  String get shortcut_action_cancel_generation => '生成のキャンセル';

  @override
  String get shortcut_action_add_to_queue => 'キューに追加';

  @override
  String get shortcut_action_random_prompt => 'ランダムなプロンプト';

  @override
  String get shortcut_action_clear_prompt => 'プロンプトをクリア';

  @override
  String get shortcut_action_toggle_prompt_mode => 'プロンプトモードの切り替え';

  @override
  String get shortcut_action_open_tag_library => 'タグ ライブラリを開く';

  @override
  String get shortcut_action_save_image => '画像を保存';

  @override
  String get shortcut_action_upscale_image => '画像を拡大';

  @override
  String get shortcut_action_copy_image => '画像をコピー';

  @override
  String get shortcut_action_fullscreen_preview => '全画面プレビュー';

  @override
  String get shortcut_action_open_params_panel => 'パラメータパネルを開く';

  @override
  String get shortcut_action_open_history_panel => '履歴パネルを開く';

  @override
  String get shortcut_action_reuse_params => 'パラメータの再利用';

  @override
  String get shortcut_action_previous_image => '前の画像';

  @override
  String get shortcut_action_next_image => '次の画像';

  @override
  String get shortcut_action_zoom_in => 'ズームイン';

  @override
  String get shortcut_action_zoom_out => 'ズームアウト';

  @override
  String get shortcut_action_reset_zoom => 'ズームをリセット';

  @override
  String get shortcut_action_toggle_fullscreen => '全画面表示の切り替え';

  @override
  String get shortcut_action_close_viewer => 'ビューアを閉じる';

  @override
  String get shortcut_action_toggle_favorite => 'お気に入りの切り替え';

  @override
  String get shortcut_action_copy_prompt => 'プロンプトのコピー';

  @override
  String get shortcut_action_reuse_gallery_params => 'パラメータの再利用';

  @override
  String get shortcut_action_delete_image => '画像を削除';

  @override
  String get shortcut_action_previous_page => '前のページ';

  @override
  String get shortcut_action_next_page => '次のページ';

  @override
  String get shortcut_action_refresh_gallery => 'ギャラリーを更新';

  @override
  String get shortcut_action_focus_search => '検索にフォーカス';

  @override
  String get shortcut_action_enter_selection_mode => '選択モードに入る';

  @override
  String get shortcut_action_open_filter_panel => 'フィルター パネルを開く';

  @override
  String get shortcut_action_clear_filter => 'フィルターをクリア';

  @override
  String get shortcut_action_toggle_category_panel => 'カテゴリ パネルの切り替え';

  @override
  String get shortcut_action_jump_to_date => '日付に移動';

  @override
  String get shortcut_action_open_folder => 'フォルダーを開く';

  @override
  String get shortcut_action_select_all_tags => 'すべてのタグを選択';

  @override
  String get shortcut_action_deselect_all_tags => 'すべてのタグの選択を解除';

  @override
  String get shortcut_action_new_category => '新しいカテゴリ';

  @override
  String get shortcut_action_new_tag => '新しいタグ';

  @override
  String get shortcut_action_search_tags => 'タグを検索';

  @override
  String get shortcut_action_batch_delete_tags => 'タグの一括削除';

  @override
  String get shortcut_action_batch_copy_tags => 'タグのバッチコピー';

  @override
  String get shortcut_action_send_to_home => 'ホームに送信';

  @override
  String get shortcut_action_exit_selection_mode => '選択モードを終了します';

  @override
  String get shortcut_action_sync_danbooru => 'Danbooru を同期';

  @override
  String get shortcut_action_generate_preview => 'プレビューの生成';

  @override
  String get shortcut_action_search_presets => 'プリセットの検索';

  @override
  String get shortcut_action_new_preset => '新しいプリセット';

  @override
  String get shortcut_action_duplicate_preset => 'プリセットを複製';

  @override
  String get shortcut_action_delete_preset => 'プリセットを削除';

  @override
  String get shortcut_action_close_config => '構成を閉じる';

  @override
  String get shortcut_action_minimize_to_tray => 'トレイに最小化';

  @override
  String get shortcut_action_quit_app => 'アプリケーションを終了します';

  @override
  String get shortcut_action_show_shortcut_help => 'ショートカット ヘルプを表示';

  @override
  String get shortcut_action_toggle_queue => 'キューの切り替え';

  @override
  String get shortcut_action_toggle_queue_pause => 'キューの一時停止の切り替え';

  @override
  String get shortcut_action_toggle_theme => 'テーマの切り替え';

  @override
  String get shortcut_settings_title => 'キーボード ショートカット';

  @override
  String get shortcut_settings_description =>
      'キーボード ショートカットをカスタマイズしてすばやくアクセスできるようにする';

  @override
  String get shortcut_settings_enable => 'ショートカットを有効にする';

  @override
  String get shortcut_settings_show_badges => 'ショートカット バッジを表示';

  @override
  String get shortcut_settings_show_in_tooltips => 'ツールチップに表示';

  @override
  String get shortcut_settings_reset_all => 'すべてをデフォルトにリセット';

  @override
  String get shortcut_settings_search => 'ショートカットを検索...';

  @override
  String get shortcut_settings_no_results => 'ショートカットが見つかりませんでした';

  @override
  String get shortcut_settings_press_key => 'キーの組み合わせを押してください...';

  @override
  String shortcut_settings_conflict(Object action) {
    return '次と競合します: $action';
  }

  @override
  String get shortcut_help_title => 'キーボード ショートカットのヘルプ';

  @override
  String get shortcut_help_search => 'ショートカットを検索...';

  @override
  String get shortcut_help_customize => 'ショートカットをカスタマイズする';

  @override
  String get shortcut_help_all => 'すべて';

  @override
  String get shortcut_help_tip =>
      'ヒント: F1 または ? を押します。いつでもこのヘルプ ダイアログを開くことができます';

  @override
  String get shortcut_help_fabTooltip => 'キーボード ショートカット ヘルプ (F1)';

  @override
  String get shortcut_editor_recordingInline => 'ショートカットを押してください...';

  @override
  String get shortcut_editor_pressEscToCancel => 'キャンセルするには Esc キーを押してください';

  @override
  String get shortcut_editor_clickToRecord => 'クリックして記録を開始します';

  @override
  String shortcut_editor_conflictWith(Object action) {
    return 'このショートカットは「$action」と競合します';
  }

  @override
  String get drop_extractMetadata => 'メタデータの抽出';

  @override
  String get drop_extractMetadataSubtitle => '画像からプロンプト、シード、その他のパラメーターを読み取ります';

  @override
  String get drop_addToQueue => 'キューに追加';

  @override
  String get drop_addToQueueSubtitle => 'プロンプトを抽出して生成キューに追加します';

  @override
  String get drop_vibeDetected => '事前にエンコードされた Vibe を検出しました (2 Anlas を節約)';

  @override
  String drop_vibeStrength(Object value) {
    return '強度: $value%';
  }

  @override
  String drop_vibeInfoExtracted(Object value) {
    return '抽出情報: $value%';
  }

  @override
  String get drop_reuseVibe => 'バイブを再利用';

  @override
  String get drop_reuseVibeSubtitle => '事前にエンコードされたデータを直接使用する (無料)';

  @override
  String get drop_useAsRawImage => 'Raw 画像として使用';

  @override
  String get drop_useAsRawImageSubtitle => '再エンコード (2 Anlas を消費します)';

  @override
  String get drop_dragToImg2ImgOrOther => 'Image2Image または別のターゲットにドラッグします';

  @override
  String get preciseRef_title => '精密参照';

  @override
  String get preciseRef_description =>
      '参照画像を追加し、タイプとパラメータを設定します。複数の参照を同時に使用できます。';

  @override
  String get preciseRef_addReference => '参照の追加';

  @override
  String get preciseRef_clearAll => 'すべてクリア';

  @override
  String get preciseRef_remove => '削除';

  @override
  String get preciseRef_referenceType => '参照タイプ';

  @override
  String get preciseRef_strength => '強度';

  @override
  String get preciseRef_fidelity => '忠実度';

  @override
  String get preciseRef_v4Only => 'この機能には V4 以降のモデルが必要です';

  @override
  String get preciseRef_typeCharacter => 'キャラ参照';

  @override
  String get preciseRef_typeStyle => '絵柄参照';

  @override
  String get preciseRef_typeCharacterAndStyle => 'キャラ＆絵柄参照';

  @override
  String get preciseRef_costHint => '精密参照を使用すると追加の Anlas を消費します';

  @override
  String get preciseRef_costBadge => 'Anlas を使用します';

  @override
  String get preciseRef_dropToAdd => '精密参照を追加するにはリリースしてください';

  @override
  String get preciseRef_dropNoReadableImage =>
      'ドロップ ソースは読み取り可能な画像ファイルまたは画像リンクを提供しませんでした';

  @override
  String preciseRef_addedCount(int count) {
    return '$count 件の精密参照を追加しました';
  }

  @override
  String preciseRef_removedCount(int count) {
    return '$count 件の精密参照を削除しました';
  }

  @override
  String get vibeLibrary_title => 'バイブライブラリ';

  @override
  String get vibeLibrary_categories => 'カテゴリ';

  @override
  String get vibeLibrary_newCategoryShort => '新規';

  @override
  String get vibeLibrary_createCategoryTitle => '新しいカテゴリ';

  @override
  String get vibeLibrary_createSubCategoryTitle => '新しいサブカテゴリ';

  @override
  String get vibeLibrary_categoryNameHint => 'カテゴリ名を入力してください';

  @override
  String get vibeLibrary_createCategoryConfirm => '作成';

  @override
  String get vibeLibrary_deleteCategoryTitle => '削除の確認';

  @override
  String get vibeLibrary_deleteCategoryContent =>
      'このカテゴリを削除しますか？中の Vibe は未分類に移動されます。';

  @override
  String get vibeLibrary_sortTooltip => '並べ替え基準';

  @override
  String get vibeLibrary_hideCategoryPanel => 'カテゴリ パネルを非表示にする';

  @override
  String get vibeLibrary_showCategoryPanel => 'カテゴリ パネルを表示';

  @override
  String get vibeLibrary_enterSelectionMode => '選択モードに入ります';

  @override
  String get vibeLibrary_importTooltip =>
      'Vibe ファイルまたは PNG/JPG/JPEG/WEBP 画像をインポートします (右クリックしてその他のオプションを表示します)';

  @override
  String get vibeLibrary_exportTooltip => 'Vibe をファイルにエクスポート';

  @override
  String get vibeLibrary_openFolderTooltip => 'バイブライブラリフォルダーを開く';

  @override
  String get vibeLibrary_refresh => '更新';

  @override
  String get vibeLibrary_loading => '読み込み中...';

  @override
  String vibeLibrary_totalCount(Object count) {
    return '$count 件の Vibe';
  }

  @override
  String get vibeLibrary_noCategoriesAvailable => '使用可能なカテゴリがありません';

  @override
  String get vibeLibrary_moveToCategory => 'カテゴリに移動';

  @override
  String get vibeLibrary_uncategorized => '未分類';

  @override
  String vibeLibrary_movedToCategory(Object count) {
    return '$count 件の Vibe を移動しました';
  }

  @override
  String get vibeLibrary_favoriteStatusUpdated => 'お気に入りのステータスが更新されました';

  @override
  String get vibeLibrary_importFromFile => 'ファイルからインポート';

  @override
  String get vibeLibrary_importFromImage => '画像からインポート';

  @override
  String get vibeLibrary_importFromClipboard => 'クリップボードからエンコードされたデータをインポート';

  @override
  String vibeLibrary_openFolderFailed(Object error) {
    return 'フォルダーを開けませんでした: $error';
  }

  @override
  String get vibeLibrary_importFileDialogTitle => 'インポートする Vibe ファイルを選択してください';

  @override
  String get vibeLibrary_preparingImport => 'インポートを準備しています...';

  @override
  String vibeLibrary_importSuccessCount(Object count) {
    return '$count 件の Vibe をインポートしました';
  }

  @override
  String vibeLibrary_importSummary(Object success, Object failed) {
    return 'インポート完了: $success 成功、$failed 失敗';
  }

  @override
  String get vibeLibrary_dropImportHint =>
      '.naiv4vibe/.naiv4vibebundle/.png/.jpg/.jpeg/.webp ファイルまたはフォルダーをここにドロップしてインポートします';

  @override
  String get vibeLibrary_importing => 'インポート中...';

  @override
  String vibeLibrary_pageIndicator(Object current, Object total) {
    return '$current / $total ページ';
  }

  @override
  String get vibeLibrary_itemsPerPage => 'ページごと:';

  @override
  String get vibeLibrary_tooManyTitle => 'Vibe が多すぎます';

  @override
  String vibeLibrary_tooManySelectedContent(Object count) {
    return '$count 件の Vibe が選択されています。一度に使用できるのは最大 16 件です。\n\n選択数を減らして再試行してください。';
  }

  @override
  String vibeLibrary_tooManyExistingContent(Object current, Object remaining) {
    return '生成ページにはすでに $current 件の Vibe があります。さらに $remaining 件まで追加できます。\n\n選択数を減らして再試行してください。';
  }

  @override
  String vibeLibrary_sentToGenerationCount(Object count) {
    return '$count 件の Vibe を生成に送信しました';
  }

  @override
  String vibeLibrary_deleteSelectedContent(Object count) {
    return '選択した $count 件の Vibe を削除しますか？この操作は元に戻せません。';
  }

  @override
  String vibeLibrary_deletedCount(Object count) {
    return '$count 件の Vibe を削除しました';
  }

  @override
  String get vibeLibrary_importImageDialogTitle => 'Vibe データを含む画像を選択してください';

  @override
  String get vibeLibrary_clipboardEmpty => 'クリップボードが空です';

  @override
  String get vibeLibrary_encodeTimeout => 'エンコードがタイムアウトしました。ネットワーク接続を確認してください。';

  @override
  String get vibeLibrary_unknownError => '不明なエラー';

  @override
  String get vibeLibrary_save => 'ライブラリに保存';

  @override
  String get vibeLibrary_import => 'Vibe をインポート';

  @override
  String get vibeLibrary_searchHint => '名前、タグを検索...';

  @override
  String get vibeLibrary_empty => 'バイブライブラリは空です';

  @override
  String get vibeLibrary_emptyHint => 'まずバイブライブラリにエントリを追加してください';

  @override
  String get vibeLibrary_allVibes => 'すべての Vibe';

  @override
  String get vibeLibrary_favorites => 'お気に入り';

  @override
  String get vibeLibrary_sendToGeneration => '生成に送信';

  @override
  String get vibeLibrary_export => 'エクスポート';

  @override
  String get vibeLibrary_edit => '編集';

  @override
  String get vibeLibrary_delete => '削除';

  @override
  String get vibeLibrary_addToFavorites => 'お気に入りに追加';

  @override
  String get vibeLibrary_removeFromFavorites => 'お気に入りから削除';

  @override
  String get vibeLibrary_newSubCategory => '新しいサブカテゴリ';

  @override
  String get vibeLibrary_maxVibesReached => '最大制限に達しました (16 件の Vibe)';

  @override
  String get vibeLibrary_bundleReadFailed =>
      'バンドルファイルの読み取りに失敗したため、単一ファイルモードを使用します';

  @override
  String get vibe_export_title => 'Vibe をエクスポート';

  @override
  String get vibe_export_format => 'エクスポート形式';

  @override
  String get vibe_selector_title => 'Vibe を選択してください';

  @override
  String get vibe_selector_recent => '最近の';

  @override
  String get vibe_category_add => 'カテゴリを追加';

  @override
  String get vibe_category_rename => 'カテゴリの名前を変更';

  @override
  String get drop_vibe_detected => 'Vibe 画像を検出しました';

  @override
  String get drop_reuse_vibe => 'バイブを再利用';

  @override
  String drop_save_anlas(int cost) {
    return '$cost Anlas を節約';
  }

  @override
  String get vibe_export_include_thumbnails => 'サムネイルを含める';

  @override
  String get vibe_export_include_thumbnails_subtitle =>
      'エクスポート ファイルにサムネイル プレビューを含めます';

  @override
  String get vibe_export_singleFile => '単一ファイル (.naiv4vibe)';

  @override
  String get vibe_export_singleFileDescription =>
      '各 Vibe を個別のファイルとしてエクスポートし、1 つの Vibe を共有するのに適しています';

  @override
  String get vibe_export_bundleFile => 'バンドル ファイル (.naiv4vibebundle)';

  @override
  String get vibe_export_bundleFileDescription =>
      '複数の Vibe を 1 つのファイルにまとめ、バッチバックアップに適しています';

  @override
  String get vibe_export_embedIntoPng => 'PNG に埋め込む';

  @override
  String get vibe_export_embedIntoPngDescription =>
      'データを PNG メタデータに埋め込んで単一の Vibe をエクスポートします';

  @override
  String get vibe_export_exportable => 'エクスポート可能';

  @override
  String get vibe_export_notExportable => 'エクスポートできません';

  @override
  String get vibe_export_selectVibesToExport => 'エクスポートする Vibe を選択してください';

  @override
  String vibe_export_exportSelected(int count) {
    return 'エクスポート ($count)';
  }

  @override
  String vibe_export_strengthPercent(int percent) {
    return '強度: $percent%';
  }

  @override
  String get vibe_export_pngCarrierImage => 'PNG キャリア画像';

  @override
  String get vibe_export_noUsablePngCarrier =>
      'この Vibe には、直接使用できる PNG キャリア画像がありません。外部 PNG 画像をキャリアとして選択できます。';

  @override
  String get vibe_export_selectExternalPngImage => '外部 PNG 画像を選択してください...';

  @override
  String get vibe_export_changeExternalPngImage => '外部 PNG 画像を変更します...';

  @override
  String get vibe_export_useVibeImageInstead => '代わりに Vibe 画像を使用してください';

  @override
  String vibe_export_usingExternalPng(String fileName) {
    return '外部 PNG の使用: $fileName';
  }

  @override
  String get vibe_export_selectPngImage => 'PNG 画像を選択してください';

  @override
  String get vibe_export_invalidPngImage => '選択したファイルは有効な PNG 画像ではありません';

  @override
  String vibe_export_selectPngImageFailed(String error) {
    return 'PNG 画像の選択に失敗しました: $error';
  }

  @override
  String vibe_export_embeddingPng(String name) {
    return 'PNG の埋め込み: $name';
  }

  @override
  String vibe_export_exportCompleteCounts(int successCount, int failCount) {
    return 'エクスポート完了: $successCount 成功、$failCount 失敗';
  }

  @override
  String vibe_export_exportCompletePath(String path) {
    return 'エクスポートが完了しました: $path';
  }

  @override
  String vibe_export_packingVibes(int count) {
    return '$count 件の Vibe をパックしています...';
  }

  @override
  String vibe_export_exportingName(String name) {
    return 'エクスポート中: $name';
  }

  @override
  String get vibe_export_selectExportFolder => 'エクスポートフォルダーを選択してください';

  @override
  String get vibe_export_generatingBundleFile => 'バンドル ファイルを生成しています...';

  @override
  String vibe_export_bundleTitle(String name) {
    return 'バンドルのエクスポート: $name';
  }

  @override
  String vibe_export_vibesTitle(int count) {
    return 'Vibe をエクスポート ($count 件選択中)';
  }

  @override
  String get vibe_export_method => 'エクスポート方法';

  @override
  String get vibe_export_wholeBundle => 'バンドル全体';

  @override
  String get vibe_export_internalVibe => '内部 Vibe';

  @override
  String vibe_export_wholeBundleDescription(int count) {
    return '全 $count 件の Vibe を含む .naiv4vibebundle ファイルとしてエクスポートします';
  }

  @override
  String vibe_export_internalVibeDescription(int count) {
    return '.naiv4vibe ファイルとして個別にエクスポートする内部バンドル Vibe を選択してください (合計 $count)';
  }

  @override
  String get vibe_export_exportBundle => 'エクスポート バンドル';

  @override
  String get vibe_export_exportAsFiles => 'ファイルとしてエクスポート';

  @override
  String get vibe_export_exportBundleDescription =>
      '.naiv4vibebundle ファイルとしてエクスポート';

  @override
  String get vibe_export_exportAsFilesDescription =>
      '.naiv4vibe または .naiv4vibebundle ファイルとしてエクスポート';

  @override
  String get vibe_export_exportAsZip => 'ZIP としてエクスポート';

  @override
  String get vibe_export_exportAsZipDescription =>
      '選択したバイブライブラリエントリを個別のファイルとして .zip にパックします';

  @override
  String get vibe_export_compressData => 'データを圧縮します';

  @override
  String get vibe_export_compressDataDescription =>
      '圧縮を使用してファイル サイズを削減します (バッチ エクスポートに推奨)';

  @override
  String get vibe_export_zipCompressDescription => 'ZIP 内のファイルを圧縮してサイズを削減します';

  @override
  String get vibe_export_exportAsPng => 'PNG としてエクスポート';

  @override
  String get vibe_export_pngInternalBundleUnsupported =>
      '単一の内部バンドル Vibe をエクスポートする場合、画像への埋め込みはサポートされていません';

  @override
  String get vibe_export_embedVibeDataIntoPng => 'Vibe データを PNG メタデータに埋め込む';

  @override
  String get vibe_export_batchPngUsesFirstImage =>
      'バッチ エクスポートでは、各 Vibe の最初に使用可能な画像が使用されます。画像のないエントリは自動的にスキップされます。';

  @override
  String get vibe_export_exportCarrierImage => 'キャリアイメージのエクスポート';

  @override
  String get vibe_export_usingExternalCarrierImage =>
      'エクスポートキャリア画像として外部 PNG を使用する';

  @override
  String get vibe_export_exportAsEncodings => 'エンコーディングとしてエクスポート';

  @override
  String get vibe_export_exportAsEncodingsDescription =>
      'データをエンコーディング (JSON または Base64) としてエクスポートします。';

  @override
  String get vibe_export_jsonDescription =>
      '読み取りと編集を容易にするために、フォーマットされた JSON ファイルとしてエクスポートします。';

  @override
  String get vibe_export_base64Description =>
      'コピーと共有のためにプレーン Base64 としてエクスポートします';

  @override
  String get vibe_export_selectAtLeastOneMethod =>
      '少なくとも 1 つのエクスポート方法を選択してください';

  @override
  String get vibe_export_batchPngUnsupported =>
      'バッチ Vibe エクスポートは、PNG への埋め込みをサポートしていません。単一の Vibe エクスポート画面を使用します。';

  @override
  String get vibe_export_selectPngCarrier => 'エクスポートする PNG キャリア画像を選択してください';

  @override
  String get vibe_export_selectAtLeastOneInternalVibe =>
      'エクスポートする内部 Vibe を少なくとも 1 つ選択してください';

  @override
  String get vibe_export_selectVibeExportFolder => 'Vibe エクスポート フォルダーを選択してください';

  @override
  String get vibe_export_saveEncodingFile => 'エンコードファイルを保存';

  @override
  String get vibe_export_preparingExport => 'エクスポートを準備しています...';

  @override
  String vibe_export_preparingVibeProgress(int current, int total) {
    return 'Vibe $current/$total を読み取り中...';
  }

  @override
  String get vibe_export_exportingBundle => 'バンドルをエクスポートしています...';

  @override
  String get vibe_export_exportingZip => 'ZIP をエクスポートしています...';

  @override
  String get vibe_export_embeddingImage => '画像を埋め込んでいます...';

  @override
  String get vibe_export_exportingEncoding => 'エンコーディングをエクスポートしています...';

  @override
  String vibe_export_exportFailedWithError(String error) {
    return 'エクスポートに失敗しました: $error';
  }

  @override
  String get vibe_export_noExportableEntries => 'エクスポート可能な Vibe エントリがありません';

  @override
  String get vibe_export_bundleFilePathEmpty => 'バンドル ファイルのパスが空です';

  @override
  String vibe_export_invalidImageFormatWithError(String error) {
    return '無効な画像形式: $error';
  }

  @override
  String vibe_export_embedFailedWithError(String error) {
    return '埋め込みに失敗しました: $error';
  }

  @override
  String vibe_export_embedImageFailedWithError(String error) {
    return '画像の埋め込みに失敗しました: $error';
  }

  @override
  String vibe_export_extractingVibeProgress(int current, int total) {
    return 'Vibe $current/$total を抽出しています...';
  }

  @override
  String vibe_export_selectImageFailed(String error) {
    return '画像の選択に失敗しました: $error';
  }

  @override
  String vibe_export_dialogTitle(int count) {
    return '$count 件の Vibe をエクスポート';
  }

  @override
  String get vibe_export_chooseMethod => 'Vibe のエクスポート方法を選択してください';

  @override
  String get vibe_export_asBundle => 'バンドルとして';

  @override
  String get vibe_export_individually => '個別';

  @override
  String get vibe_export_noData => 'エクスポートするデータがありません';

  @override
  String get vibe_export_success => 'エクスポートが成功しました';

  @override
  String get vibe_export_failed => 'エクスポートに失敗しました';

  @override
  String vibe_export_skipped(int count) {
    return 'データのない $count 件の Vibe をスキップしました';
  }

  @override
  String vibe_export_bundleSuccess(int count) {
    return 'バンドルをエクスポートしました: $count 件の Vibe';
  }

  @override
  String get vibe_export_selectToEmbed => '埋め込む Vibe を選択してください';

  @override
  String get vibe_export_pngRequired => 'PNG ファイルが必要です';

  @override
  String get vibe_export_noEmbeddableData => '埋め込み可能なデータがありません';

  @override
  String vibe_export_embedSuccess(int count) {
    return '$count 件の Vibe を画像に埋め込みました';
  }

  @override
  String get vibe_export_embedFailed => '埋め込みに失敗しました';

  @override
  String get vibe_embedToImage => '画像に埋め込む';

  @override
  String get vibe_import_skip => 'スキップ';

  @override
  String get vibe_import_confirm => '確認';

  @override
  String get vibe_import_noEncodingData => 'エンコード データがありません';

  @override
  String get vibe_import_encodingCost => 'エンコードには 2 Anlas を消費します';

  @override
  String get vibe_import_confirmCost => '続けて Anlas を消費しますか?';

  @override
  String get vibe_import_encodeNow => 'すぐにエンコードします (2 Anlas)';

  @override
  String get vibe_addImageOnly => '画像のみを追加';

  @override
  String get vibe_import_autoSave => 'ライブラリに自動保存';

  @override
  String get vibe_import_encodingFailed => 'エンコードに失敗しました';

  @override
  String get vibe_import_encodingFailedMessage =>
      'Vibe のエンコードに失敗しました。未エンコードの画像を追加し続けますか？';

  @override
  String get vibe_import_encodingInProgress => 'エンコード中...';

  @override
  String get vibe_import_encodingComplete => 'エンコードが完了しました';

  @override
  String get vibe_import_partialFailed => '部分的なエンコードに失敗しました';

  @override
  String get vibe_import_timeout => 'エンコードのタイムアウト';

  @override
  String get vibe_import_title => 'ライブラリからインポート';

  @override
  String vibe_import_result(int count) {
    return '$count 件の Vibe をインポートしました';
  }

  @override
  String get vibe_import_fileParseFailed => 'ファイルの解析に失敗しました';

  @override
  String get vibe_import_fileSelectionFailed => 'ファイルの選択に失敗しました';

  @override
  String get vibe_import_importFailed => 'インポートに失敗しました';

  @override
  String vibe_import_failedWithError(String error) {
    return 'インポートに失敗しました: $error';
  }

  @override
  String get vibe_import_bundleTitle => 'Vibe バンドルをインポート';

  @override
  String get vibe_import_bundleChooseMethod => 'インポート方法を選択してください';

  @override
  String get vibe_import_bundleAsWhole => '全体としてインポート';

  @override
  String get vibe_import_bundleAsWholeDescription =>
      'バンドル構造を保持し、1 つのライブラリ エントリとしてインポートします';

  @override
  String get vibe_import_bundleSplitEntries => '個別のエントリに分割';

  @override
  String get vibe_import_bundleSplitEntriesDescription =>
      '各 Vibe を個別のライブラリエントリとしてインポートします';

  @override
  String get vibe_import_bundleSelectVibes => 'インポートする Vibe を選択してください';

  @override
  String get vibe_import_bundleSelectVibesDescription =>
      '選択した Vibe のみをインポートします';

  @override
  String get vibe_import_bundleConfigureEachVibe => '各 Vibe のパラメータを設定します';

  @override
  String get vibe_import_bundleSelectAndConfigureEachVibe =>
      '各 Vibe のパラメータを選択して設定します';

  @override
  String vibe_import_bundleSelectedCount(int selected, int total) {
    return '$selected/$total が選択されました';
  }

  @override
  String get vibe_saveToLibrary_title => 'ライブラリに保存';

  @override
  String get vibe_saveToLibrary_strength => '強度';

  @override
  String get vibe_saveToLibrary_infoExtracted => '抽出情報';

  @override
  String vibe_saveToLibrary_saving(int count) {
    return '$count 件の Vibe を保存しています';
  }

  @override
  String get vibe_saveToLibrary_saveFailed => 'ライブラリへの保存に失敗しました';

  @override
  String vibe_saveToLibrary_savingCount(int count) {
    return '$count 件の Vibe を保存しています';
  }

  @override
  String get vibe_saveToLibrary_nameLabel => '名前';

  @override
  String get vibe_saveToLibrary_nameHint => 'Vibe 名を入力してください';

  @override
  String vibe_saveToLibrary_mixed(int saved, int reused) {
    return '保存 $saved、再利用 $reused';
  }

  @override
  String vibe_saveToLibrary_saved(int count) {
    return '$count をライブラリに保存しました';
  }

  @override
  String vibe_saveToLibrary_reused(int count) {
    return 'ライブラリから $count を再利用しました';
  }

  @override
  String get vibe_saveToLibrary_saveAsBundle => 'バンドルとして保存';

  @override
  String vibe_saveToLibrary_saveAsBundleDescription(int count) {
    return '$count 件の Vibe を 1 つのバンドルとして保存';
  }

  @override
  String get vibe_saveToLibrary_tagHint => 'タグを入力して、[追加] を押します';

  @override
  String get vibe_maxReached => '最大 16 件の Vibe に達しました';

  @override
  String get vibe_maxReachedRemoveSome =>
      '最大 16 件の Vibe に達しました。まずいくつかの Vibe を削除してください。';

  @override
  String vibe_addedNamed(String name) {
    return 'Vibe を追加しました: $name';
  }

  @override
  String vibe_addedCount(int count) {
    return '$count 件の Vibe を追加しました';
  }

  @override
  String get vibe_statusEncoded => 'エンコード済み';

  @override
  String get vibe_statusEncoding => 'エンコード中...';

  @override
  String get vibe_statusPendingEncode => 'エンコード (2 Anlas)';

  @override
  String get vibe_encodeDialogTitle => 'Vibe エンコーディングを確認する';

  @override
  String get vibe_encodeDialogMessage => 'この画像を生成のためにエンコードしますか?';

  @override
  String get vibe_encodeCostWarning => 'これには 2 Anlas (クレジット) かかります';

  @override
  String get vibe_encodeButton => 'エンコード';

  @override
  String get vibe_encodeSuccess => 'Vibe は正常にエンコードされました。';

  @override
  String get vibe_encodeFailed => 'Vibe エンコードに失敗しました。再試行してください。';

  @override
  String vibe_encodeError(String error) {
    return 'エンコードに失敗しました: $error';
  }

  @override
  String get bundle_internalVibes => '内部 Vibe';

  @override
  String get shortcuts_customize => 'ショートカットをカスタマイズする';

  @override
  String get gallery_send_to => '送信先';

  @override
  String get image_editor_select_tool => 'ツールの選択';

  @override
  String get selection_clear_selection => '選択をクリア';

  @override
  String get selection_invert_selection => '選択範囲を反転';

  @override
  String get selection_cut_to_layer => 'レイヤーにカット';

  @override
  String get search_results => '検索結果';

  @override
  String get search_noResults => '一致する結果はありません';

  @override
  String get addToCurrent => '現在に追加';

  @override
  String get replaceExisting => '既存のものを置き換えます';

  @override
  String get confirmSelection => '選択を確認';

  @override
  String get selectAll => 'すべて選択';

  @override
  String get clearSelection => 'クリア';

  @override
  String get clearFilters => 'フィルターをクリア';

  @override
  String get shortcut_context_vibe_detail => 'Vibe 詳細';

  @override
  String get shortcut_action_vibe_detail_send_to_generation => '生成に送信';

  @override
  String get shortcut_action_vibe_detail_export => 'エクスポート';

  @override
  String get shortcut_action_vibe_detail_rename => '名前の変更';

  @override
  String get shortcut_action_vibe_detail_delete => '削除';

  @override
  String get shortcut_action_vibe_detail_toggle_favorite => 'お気に入りの切り替え';

  @override
  String get shortcut_action_vibe_detail_prev_sub_vibe => '前の Sub Vibe';

  @override
  String get shortcut_action_vibe_detail_next_sub_vibe => '次の Sub Vibe';

  @override
  String get shortcut_action_navigate_to_vibe_library => 'バイブライブラリ';

  @override
  String get shortcut_action_vibe_import => 'Vibe をインポート';

  @override
  String get shortcut_action_vibe_export => 'Vibe をエクスポート';

  @override
  String get vibeSelectorFilterFavorites => 'お気に入り';

  @override
  String get vibeSelectorFilterSourceAll => 'すべてのタイプ';

  @override
  String get vibeSelectorSortCreated => '作成されました';

  @override
  String get vibeSelectorSortLastUsed => '最後に使用したもの';

  @override
  String get vibeSelectorSortUsedCount => '使用回数';

  @override
  String get vibeSelectorSortName => '名前';

  @override
  String vibeSelectorItemsCount(int count) {
    return '$count アイテム';
  }

  @override
  String get tray_show => 'ウィンドウを表示';

  @override
  String get tray_exit => '終了';

  @override
  String get settings_shortcutsSubtitle => 'キーボード ショートカットをカスタマイズする';

  @override
  String get settings_openFolder => 'フォルダーを開く';

  @override
  String get settings_openFolderFailed => 'フォルダーを開けませんでした';

  @override
  String get settings_dataSourceCacheTitle => 'データ ソース キャッシュ管理';

  @override
  String get settings_pleaseLoginFirst => 'まずログインしてください';

  @override
  String get settings_accountNotFound => 'アカウント情報が見つかりません';

  @override
  String get settings_goToLoginPage => 'ログインページに移動';

  @override
  String settings_retryCountDisplay(int count) {
    return '最大 $count 回';
  }

  @override
  String settings_retryIntervalDisplay(String interval) {
    return '$interval 秒';
  }

  @override
  String get settings_vibePathSaved => 'バイブライブラリのパスを保存しました';

  @override
  String get settings_selectFolderFailed => 'フォルダーの選択に失敗しました';

  @override
  String get settings_hivePathSaved => 'データ ストレージ パスが保存され、再起動後に有効になります';

  @override
  String get settings_restartRequiredTitle => '再起動が必要です';

  @override
  String get settings_changePathConfirm =>
      'データ ストレージ パスを変更した後、反映するにはアプリの再起動が必要です。\\n\\n新しいパスは次回起動時に有効になります。続行しますか？';

  @override
  String get settings_resetPathConfirm =>
      'データ ストレージ パスをリセットした後、反映するにはアプリの再起動が必要です。\\n\\nデフォルトのパスは次回起動時に有効になります。続行しますか？';

  @override
  String get settings_kritaBridgeTitle => 'Krita Bridge';

  @override
  String get settings_kritaBridgeEnable => 'Krita ローカル ブリッジを有効にする';

  @override
  String get settings_kritaBridgeDisabledText =>
      'デフォルトではオフ。有効にするとローカル 127.0.0.1 でのみリッスンします';

  @override
  String get settings_kritaBridgeStartingText => 'ローカル ブリッジ サービスを開始しています...';

  @override
  String get settings_kritaBridgeListeningText => 'Krita プラグインの接続を待機しています';

  @override
  String get settings_kritaBridgeConnectedText => 'Krita プラグインが接続されました';

  @override
  String get settings_kritaBridgeErrorText => '起動に失敗しました。エラー メッセージを確認してください。';

  @override
  String get settings_kritaBridgeDisabled => '無効';

  @override
  String get settings_kritaBridgeStarting => '開始中';

  @override
  String get settings_kritaBridgeListening => 'リスニング';

  @override
  String get settings_kritaBridgeConnected => '接続されました';

  @override
  String get settings_kritaBridgeError => 'エラー';

  @override
  String get settings_kritaBridgeRegenerateSession => 'セッションを再生成';

  @override
  String get settings_kritaBridgeDiscoveryFile => '検出ファイル';

  @override
  String get settings_kritaBridgeWaitingEndpoint =>
      'ローカル WebSocket リスナーを待機しています';

  @override
  String settings_kritaBridgeClient(Object client) {
    return 'クライアント: $client';
  }

  @override
  String get settings_fontScale => 'フォント サイズ';

  @override
  String get settings_fontScale_description => 'グローバルフォントスケールを調整します';

  @override
  String get settings_fontScale_previewSmall => '夕日と一匹のアヒルが一緒に飛ぶ';

  @override
  String get settings_fontScale_previewMedium => '秋の水が果てしない空と溶け合う';

  @override
  String get settings_fontScale_previewLarge => 'フォント サイズのプレビュー';

  @override
  String get settings_fontScale_reset => 'リセット';

  @override
  String get settings_fontScale_done => '完了';

  @override
  String get settings_generationLayout => '生成ページのレイアウト';

  @override
  String get settings_generationLayout_classic => 'クラシック';

  @override
  String get settings_generationLayout_classicDescription =>
      'パラメータは左側、プロンプトはプレビューの上';

  @override
  String get settings_generationLayout_webStyle => '公式サイト風';

  @override
  String get settings_generationLayout_webStyleDescription =>
      'プロンプトと設定を左端に固定、NovelAI 公式サイト風';

  @override
  String get settings_defaultImagesPath =>
      'デフォルト (Documents/NAI_Launcher/images/)';

  @override
  String settings_defaultVibePath(Object path) {
    return '$path (デフォルト)';
  }

  @override
  String get settings_defaultHivePath => 'デフォルト (%APPDATA%/NAI_Launcher/hive/)';

  @override
  String get settings_protectionMode => '保護モード';

  @override
  String get settings_protectionModeSubtitle =>
      '以下のオプションを通じて、ローカル資産、共有コピー、および高コストの操作を保護します。これをオフにすると、オプションの値は保持されますが、無効になります。';

  @override
  String get settings_protectionFeatures => '保護機能';

  @override
  String get settings_stripMetadataTitle => 'コピーまたはドラッグするときにすべてのメタデータを削除します';

  @override
  String get settings_stripMetadataSubtitle =>
      'サニタイズされたコピーを作成し、PNG テキスト チャンク、EXIF、および NAI ステガノグラフィック透かしデータを削除し、ドラッグ中に元のパスが露出しないようにします。';

  @override
  String get settings_confirmDangerousActionsTitle => '危険な資産のアクションを再確認する';

  @override
  String get settings_confirmDangerousActionsSubtitle =>
      'ローカル アセットを削除、移動、またはバッチ移動すると、追加の保護の確認が表示されます。';

  @override
  String get settings_warnExternalImageSendTitle => '外部サービスに送信する前に確認してください';

  @override
  String get settings_warnExternalImageSendSubtitle =>
      'ローカル画像がアプリの境界を越えて LLM、NovelAI、ComfyUI、または同様のサービスに到達する前に確認してください。';

  @override
  String get settings_preventOverwriteTitle => 'エクスポート時に既存のファイルを上書きしないようにします';

  @override
  String get settings_preventOverwriteSubtitle =>
      '既存のアセットを誤って置き換えることを避けるために、重複するエクスポートまたはパッケージのパスに自動的に番号を付けます。';

  @override
  String get settings_warnHighAnlasCostTitle => 'Anlas コストが高いという警告';

  @override
  String settings_warnHighAnlasCostSubtitle(Object threshold) {
    return '単一リクエストの推定コストが $threshold Anlas に達したときに、生成前に確認を表示します。';
  }

  @override
  String get settings_highAnlasCostThresholdTitle => 'Anlas 警告しきい値';

  @override
  String get settings_setHighAnlasCostThresholdTitle => 'Anlas 警告しきい値を設定';

  @override
  String get settings_threshold => 'しきい値';

  @override
  String get settings_highAnlasCostThresholdHelper =>
      '1 回の生成にかかる推定コストがこの値以上になった場合に確認を表示します。';

  @override
  String get settings_selectLocalOnnxTaggerFolder =>
      'ONNX タガー モデル フォルダーを選択してください';

  @override
  String get settings_localOnnxTaggerFolderSaved =>
      'ONNX タガー モデル フォルダーが保存されました';

  @override
  String get settings_localOnnxTaggerFolder => 'ローカル ONNX タガー モデル フォルダー';

  @override
  String get settings_notConfigured => '未構成';

  @override
  String get settings_confirmExternalSendTitle => '保護モード: 外部送信の確認';

  @override
  String settings_confirmExternalSendContent(Object count, Object target) {
    return '$count 枚のローカル画像を $target に送信しようとしています。画像データはローカル アプリの外部に送信されます。これが想定どおりであることを確認してください。';
  }

  @override
  String get settings_confirmExternalSend => '送信';

  @override
  String get settings_highAnlasCostTitle => '保護モード: 高 Anlas コスト';

  @override
  String settings_highAnlasCostContent(Object cost, Object threshold) {
    return 'このリクエストには $cost Anlas の費用がかかると推定されており、$threshold Anlas の警告しきい値に達するか超えています。生成を継続しますか?';
  }

  @override
  String get settings_continueGeneration => '生成を続行';

  @override
  String get dataSource_clearingData => 'データを消去しています...';

  @override
  String get dataSource_clearTitle => 'タグ データ ソースのクリア';

  @override
  String get dataSource_clearContent =>
      'Danbooru タグのオートコンプリート データをクリアしますか?\n\nこれでクリアされます:\n- Danbooru タグのオートコンプリート データ\n\nこれは保存されます:\n- 中国語/英語タグ翻訳\n- タグ共起データ\n\nタグデータは次回起動時に自動的に再読み込みされます。';

  @override
  String get dataSource_confirmClear => 'クリア';

  @override
  String dataSource_clearSuccess(Object count) {
    return '$count 行をクリアしました。次回起動時にデータが自動的に復元されます。';
  }

  @override
  String get dataSource_clearFailed => 'クリアに失敗しました';

  @override
  String dataSource_clearFailedWithError(Object error) {
    return 'クリアに失敗しました: $error';
  }

  @override
  String get dataSource_clearTagAutocompleteData => 'タグのオートコンプリート データをクリアします';

  @override
  String get dataSource_ready => 'データ ソースの準備ができました';

  @override
  String get dataSource_notLoaded => 'データ ソースがロードされていません';

  @override
  String dataSource_cachedTagCount(Object count) {
    return 'キャッシュされた $count タグ';
  }

  @override
  String get dataSource_clickSyncToDownload =>
      '[今すぐ同期] をクリックしてタグ データをダウンロードします';

  @override
  String dataSource_translationCount(Object count) {
    return '$count 翻訳';
  }

  @override
  String dataSource_cooccurrenceCount(Object count) {
    return '$count 共起';
  }

  @override
  String dataSource_lastUpdated(Object time) {
    return '最終更新日: $time';
  }

  @override
  String get dataSource_heatThresholdTitle => '人気度しきい値';

  @override
  String get dataSource_heatThresholdSubtitle => '各タグカテゴリの人気度しきい値を選択します';

  @override
  String get dataSource_autoRefreshInterval => '自動リフレッシュ間隔';

  @override
  String get dataSource_syncNow => '今すぐ同期';

  @override
  String get dataSource_cancelSync => '同期のキャンセル';

  @override
  String get dataSource_syncingTags => 'タグ データを同期しています...';

  @override
  String dataSource_loadFailed(Object error) {
    return 'ロードに失敗しました: $error';
  }

  @override
  String get dataSource_hotAll => 'すべて';

  @override
  String get dataSource_hot10k => 'ホット >10K';

  @override
  String get dataSource_common1k => '共通 >1K';

  @override
  String get dataSource_common500 => 'コモン >500';

  @override
  String get dataSource_normal100 => '通常 >100';

  @override
  String get dataSource_minimal50 => '最小 >50';

  @override
  String get dataSource_custom => 'カスタム';

  @override
  String get dataSource_refresh7Days => '7 日間';

  @override
  String get dataSource_refresh15Days => '15 日';

  @override
  String get dataSource_refresh30Days => '30 日';

  @override
  String get dataSource_refreshNever => '更新しない';

  @override
  String get settings_comfyUiEnable => 'ComfyUI 統合を有効にする';

  @override
  String get settings_comfyUiDisabledSubtitle =>
      '無効にすると、ローカル拡大およびその他の ComfyUI 機能が非表示になります';

  @override
  String get settings_comfyUiServerUrl => 'サーバー URL';

  @override
  String get settings_comfyUiConnectionSuccess => '接続に成功しました';

  @override
  String settings_comfyUiConnectionFailed(Object error) {
    return '接続に失敗しました: $error';
  }

  @override
  String get settings_comfyUiConnected => '接続されました';

  @override
  String get settings_comfyUiDisconnect => '切断';

  @override
  String get settings_comfyUiWorkflowManagement => 'ワークフロー管理';

  @override
  String get settings_comfyUiBuiltinWorkflows => '組み込みワークフロー';

  @override
  String get settings_comfyUiCustomWorkflows => 'カスタム ワークフロー';

  @override
  String get settings_comfyUiNoCustomWorkflows =>
      'カスタム ワークフローはまだありません。 「インポート」をクリックして ComfyUI ワークフローを追加します。';

  @override
  String settings_comfyUiSlotCount(Object count) {
    return '$count スロット';
  }

  @override
  String get settings_comfyUiBuiltin => '内蔵';

  @override
  String get settings_comfyUiDeleteWorkflowTitle => 'ワークフローの削除';

  @override
  String settings_comfyUiDeleteWorkflowContent(Object name) {
    return 'ワークフロー「$name」を削除しますか?これを元に戻すことはできません。';
  }

  @override
  String settings_comfyUiDeleted(Object name) {
    return '削除されました: $name';
  }

  @override
  String get settings_comfyUiNoResponse => 'サーバーが応答しませんでした';

  @override
  String get settings_comfyUiStatusDisconnected => '切断されました';

  @override
  String get settings_comfyUiStatusConnecting => '接続中...';

  @override
  String get settings_comfyUiStatusConnected => '接続されました';

  @override
  String get settings_comfyUiStatusError => '接続エラー';

  @override
  String get settings_comfyUiCategoryEnhance => '品質向上/拡大';

  @override
  String get settings_comfyUiCategoryImg2Img => 'Image2Image';

  @override
  String get settings_comfyUiCategoryInpaint => 'インペイント';

  @override
  String get settings_comfyUiCategoryTxt2Img => 'テキストから画像へ';

  @override
  String get settings_comfyUiCategoryCustom => 'カスタム';

  @override
  String get comfyWorkflow_seedvr2UpscaleName => 'SeedVR2 拡大';

  @override
  String get comfyWorkflow_seedvr2UpscaleDescription =>
      'SeedVR2 AI モデルで拡大します。高品質な結果を生成します。';

  @override
  String get comfyWorkflow_seedvr2TiledUpscaleName => 'SeedVR2 タイル拡大';

  @override
  String get comfyWorkflow_seedvr2TiledUpscaleDescription =>
      '大きな画像の VRAM 負荷を軽減するため、タイル状の拡大に SeedVR2TilingUpscaler を使用します。';

  @override
  String get comfyWorkflow_modelUpscaleName => 'ComfyUI 標準拡大モデル';

  @override
  String get comfyWorkflow_modelUpscaleDescription =>
      'ComfyUI UpscaleModelLoader で標準の拡大モデルをロードし、Lanczos で最終スケールを修正します。';

  @override
  String get comfyWorkflow_rtxUpscaleName => 'RTX 拡大';

  @override
  String get comfyWorkflow_rtxUpscaleDescription =>
      'ローカル拡大には Nvidia RTX ビデオ超解像度ノードを使用します。';

  @override
  String get comfyWorkflowSlot_inputImage => '入力画像';

  @override
  String get comfyWorkflowSlot_targetShortSide => 'ターゲット短辺';

  @override
  String get comfyWorkflowSlot_targetLongSide => 'ターゲット長辺';

  @override
  String get comfyWorkflowSlot_upscaleModel => '拡大モデル';

  @override
  String get comfyWorkflowSlot_randomSeed => 'ランダムシード';

  @override
  String get comfyWorkflowSlot_outputImage => '出力画像';

  @override
  String get comfyWorkflowSlot_tileWidth => 'タイルの幅';

  @override
  String get comfyWorkflowSlot_tileHeight => 'タイルの高さ';

  @override
  String get comfyWorkflowSlot_tileUpscaleResolution => 'タイル拡大解像度';

  @override
  String get comfyWorkflowSlot_targetWidth => 'ターゲット幅';

  @override
  String get comfyWorkflowSlot_targetHeight => '目標高さ';

  @override
  String get comfyWorkflowSlot_scale => 'スケール';

  @override
  String get comfyWorkflow_parameters => 'パラメータ';

  @override
  String get comfyWorkflow_selectImage => 'クリックして画像を選択してください';

  @override
  String comfyWorkflow_pickImageFailed(Object error) {
    return '画像の選択に失敗しました: $error';
  }

  @override
  String get comfyWorkflow_useResult => '結果を使用';

  @override
  String get comfyWorkflow_execute => '実行';

  @override
  String get comfyWorkflow_uploadingImage => '画像をアップロードしています...';

  @override
  String get comfyWorkflow_queued => 'キューに入れられました...';

  @override
  String comfyWorkflow_runningSteps(Object current, Object total) {
    return '$current/$total を処理しています';
  }

  @override
  String get comfyWorkflow_processing => '処理中...';

  @override
  String get comfyWorkflow_complete => '完了';

  @override
  String comfyWorkflow_imageCount(Object count) {
    return '$count 画像';
  }

  @override
  String get promptAssistant_defaultOptimizeRuleName => 'デフォルトの最適化ルール';

  @override
  String get promptAssistant_defaultOptimizeRuleContent =>
      'あなたはプロンプト最適化アシスタントです。ユーザーの意図を保持し、実用的な視覚的な詳細を追加し、カンマで区切られた単一のプロンプト行を出力します。';

  @override
  String get promptAssistant_defaultTranslateRuleName => 'デフォルトの翻訳ルール';

  @override
  String get promptAssistant_defaultTranslateRuleContent =>
      'あなたは翻訳アシスタントです。ソース言語を検出し、中国語と英語を自動的に翻訳し、説明なしで翻訳のみを返します。';

  @override
  String get promptAssistant_defaultReverseRuleName => 'デフォルトのリバースプロンプトルール';

  @override
  String get promptAssistant_defaultReverseRuleContent =>
      'あなたは画像のリバースプロンプトアシスタントです。画像と任意のタガー結果に基づいて、NovelAI に適した英語のカンマ区切りプロンプトを出力します。主題、キャラクター、スタイル、服装、アクション、構図、照明、背景を保持します。説明は不要です。';

  @override
  String get promptAssistant_defaultCharacterReplaceRuleName =>
      'デフォルトのキャラクター置換ルール';

  @override
  String get promptAssistant_defaultCharacterReplaceRuleContent =>
      'あなたはキャラクター置換アシスタントです。アクション、構成、背景、スタイル、カメラ、および品質タグを保持しながら、入力プロンプト内の元のキャラクターのアイデンティティ、髪型、衣装、外観をターゲット キャラクターに置き換えます。置換された単一行プロンプトのみを出力します。';

  @override
  String get promptAssistant_defaultCustomRuleName => 'デフォルトのカスタム ルール';

  @override
  String get promptAssistant_defaultCustomRuleContent =>
      'あなたはプロンプト書き換えアシスタントです。現在のプロンプト、ユーザー要求、およびオプションの参照イメージに従ってプロンプトを変更します。直接使用できる最後の 1 行プロンプトのみを説明なしで出力します。';

  @override
  String get localGallery_dateFilterButton => '日付フィルター';

  @override
  String get cacheStats_title => 'キャッシュ統計';

  @override
  String cacheStats_autoRefreshUpdated(Object time) {
    return '自動更新 · 最終更新日: $time';
  }

  @override
  String cacheStats_secondsAgo(Object seconds) {
    return '$seconds 秒前';
  }

  @override
  String get cacheStats_refreshNow => '今すぐ更新';

  @override
  String get cacheStats_refreshed => '更新されました';

  @override
  String get cacheStats_resetStats => '統計をリセット';

  @override
  String get cacheStats_statsReset => '統計をリセットしました';

  @override
  String get cacheStats_l1Memory => 'L1 メモリ キャッシュ';

  @override
  String get cacheStats_l2Hive => 'L2 Hive キャッシュ';

  @override
  String get cacheStats_l3Sqlite => 'L3 SQLite データベース';

  @override
  String cacheStats_recordCount(Object count) {
    return '$count レコード';
  }

  @override
  String cacheStats_databaseValue(Object imageCount, Object metadataCount) {
    return '$imageCount 画像 · $metadataCount メタデータ行';
  }

  @override
  String get galleryCache_rescanTitle => 'ギャラリーを再スキャン';

  @override
  String get galleryCache_rescanContent =>
      'これにより、次のことが行われます。\n\n1. データの整合性をチェックし、不足しているファイルにマークを付ける\n2. 新しいファイルと変更されたファイルをスキャンします\n3. 失敗したレコードを含め、以前に失敗したメタデータ抽出を再試行します。\n\nこれにより、既存のデータが消去されたり、画像ファイルが削除されたりすることはありません。';

  @override
  String get galleryCache_startScan => 'スキャンの開始';

  @override
  String get galleryCache_scanAlreadyRunning =>
      'スキャン タスクはすでに実行中です。完了するまでお待ちください。';

  @override
  String get galleryCache_preparing => '準備中...';

  @override
  String get galleryCache_noGalleryFolder => 'ギャラリーフォルダーが設定されていません';

  @override
  String get galleryCache_galleryFolderMissing => 'ギャラリー フォルダーが存在しません';

  @override
  String galleryCache_scanningPhase(Object processed, Object total) {
    return '$processed/$total をスキャンしています...';
  }

  @override
  String get galleryCache_scanComplete => 'スキャンが完了しました';

  @override
  String galleryCache_scanFailed(Object error) {
    return 'スキャンに失敗しました: $error';
  }

  @override
  String get galleryCache_rescan => '再スキャン';

  @override
  String get galleryCache_rescanSubtitle =>
      'データの整合性をチェックし、欠落しているファイルを見つけて、メタデータを抽出します';

  @override
  String get galleryCache_scanning => 'スキャン中...';

  @override
  String get galleryCache_scanAction => 'スキャン';

  @override
  String get workflowImport_title => 'ComfyUI ワークフローのインポート';

  @override
  String workflowImport_step(Object current, Object title) {
    return 'ステップ $current/4: $title';
  }

  @override
  String get workflowImport_stepFile => 'ワークフロー ファイルの選択';

  @override
  String get workflowImport_stepInfo => 'ワークフロー情報';

  @override
  String get workflowImport_stepSlots => 'スロット構成の確認';

  @override
  String get workflowImport_stepDone => 'インポート完了';

  @override
  String get workflowImport_previous => '前へ';

  @override
  String get workflowImport_next => '次へ';

  @override
  String get workflowImport_finish => 'インポートを完了する';

  @override
  String get workflowImport_defaultName => 'カスタム ワークフロー';

  @override
  String get workflowImport_fileInstructions =>
      'ComfyUI からエクスポートされた workflow_api.json ファイルを選択します。\n\nComfyUI でメニューを開き、[エクスポート (API 形式)] を選択してこのファイルを取得します。';

  @override
  String workflowImport_nodeCount(Object count) {
    return '$count ノード';
  }

  @override
  String get workflowImport_reselect => 'クリックして別のファイルを選択してください';

  @override
  String get workflowImport_selectWorkflowApi =>
      'クリックして workflow_api.json を選択します';

  @override
  String get workflowImport_invalidTopLevel =>
      '無効なファイル形式: 最上位は JSON オブジェクトである必要があります';

  @override
  String get workflowImport_noComfyNodes =>
      'ComfyUI ノードが検出されませんでした。これが API 形式のエクスポートであることを確認してください。';

  @override
  String workflowImport_readFailed(Object error) {
    return 'ファイルの読み取りに失敗しました: $error';
  }

  @override
  String get workflowImport_analysisResult => '自動解析結果';

  @override
  String get workflowImport_inputImageNodes => '入力画像ノード';

  @override
  String get workflowImport_adjustableParams => '調整可能なパラメータ';

  @override
  String get workflowImport_outputNodes => '出力ノード';

  @override
  String get workflowImport_totalNodes => '合計ノード数';

  @override
  String workflowImport_countUnit(Object count) {
    return '$count';
  }

  @override
  String get workflowImport_workflowName => 'ワークフロー名 *';

  @override
  String get workflowImport_description => '説明';

  @override
  String get workflowImport_category => 'カテゴリ';

  @override
  String get workflowImport_slotsHint =>
      'UI で公開するスロットを選択します。通常、入力スロットと出力スロットは有効のままにしておく必要があります。ユーザーが調整する必要のないパラメータは無効にすることができます。';

  @override
  String get workflowImport_inputSection => '入力';

  @override
  String get workflowImport_outputSection => '出力';

  @override
  String get workflowImport_parameterSection => 'パラメータ';

  @override
  String get workflowImport_noSlotsWarning =>
      '使用可能なスロットが検出されませんでした。このワークフローは正しく統合されない可能性があります。\nワークフローに LoadImage ノードと SaveImage/SaveImageWebsocket ノードが含まれていることを確認してください。';

  @override
  String workflowImport_nodeRef(Object node) {
    return 'ノード $node';
  }

  @override
  String get workflowImport_confirmTitle => 'このワークフローをインポートしようとしています';

  @override
  String get workflowImport_name => '名前';

  @override
  String get workflowImport_inputSlots => '入力スロット';

  @override
  String get workflowImport_parameterSlots => 'パラメータスロット';

  @override
  String get workflowImport_outputSlots => '出力スロット';

  @override
  String get workflowImport_afterImportHint =>
      'インポート後、生成画面のComfyUIワークフロー一覧から利用可能になります。';

  @override
  String workflowImport_success(Object name) {
    return 'ワークフロー「$name」がインポートされました';
  }

  @override
  String get shortcut_settings_help => 'ショートカットのヘルプを表示';

  @override
  String get shortcut_settings_show_in_menus => 'メニューに表示';

  @override
  String shortcut_settings_defaultShortcut(Object shortcut) {
    return 'デフォルト: $shortcut';
  }

  @override
  String get shortcut_settings_unassigned => '未設定';

  @override
  String get shortcut_settings_no_matches => '一致するショートカットが見つかりません';

  @override
  String get shortcut_settings_reset_all_title => 'すべてのショートカットをリセット';

  @override
  String get shortcut_settings_reset_all_confirm =>
      'すべてのショートカットをデフォルト設定にリセットしますか?これを元に戻すことはできません。';

  @override
  String get shortcut_settings_reset_to_default => 'デフォルトにリセット';

  @override
  String get performanceReport_noTaskStats => 'タスク統計がまだありません';

  @override
  String performanceReport_taskStatsLine(
    Object count,
    Object average,
    Object min,
    Object max,
  ) {
    return 'カウント: $count |平均: $average |最小: $min |最大: $max';
  }

  @override
  String get performanceReport_clearTitle => 'パフォーマンス データのクリア';

  @override
  String get performanceReport_clearContent =>
      'すべてのパフォーマンス統計をクリアしますか?これを元に戻すことはできません。';

  @override
  String get performanceReport_clearSuccess => 'パフォーマンス データがクリアされました';

  @override
  String get performanceReport_clearAction => 'クリア';

  @override
  String get toast_previewUpdated => 'プレビュー画像が更新されました';

  @override
  String toast_styleReferenceLimit(Object max) {
    return '絵柄参照が上限に達しました ($max 画像)';
  }

  @override
  String get toast_noValidPromptFound => '有効なプロンプトが見つかりません';

  @override
  String toast_addedToQueue(Object prompt) {
    return 'キューに追加されました: $prompt';
  }

  @override
  String get toast_noValidMaskIgnored => '有効なマスクが検出されませんでした。保存結果は無視されました。';

  @override
  String get toast_kritaBusy => 'Krita Bridge が生成されています。現在のタスクが完了するまで待ちます。';

  @override
  String get toast_kritaNotConnected =>
      'Krita が接続されていません。設定でブリッジを有効にし、最初にプラグインを接続します。';

  @override
  String get toast_sentToKrita => '画像が Krita に送信されました';

  @override
  String get toast_kritaUnsupportedImageFormat =>
      'この画像形式は Krita に送信できません。一般的な画像形式を使用します。';

  @override
  String toast_deletedNamed(Object name) {
    return '削除されました: $name';
  }

  @override
  String get toast_vibeParamSaveReencodeFailed =>
      'Vibe の再エンコードに失敗したため、パラメーターを保存できませんでした';

  @override
  String get toast_exportSuccess => 'エクスポートが成功しました';

  @override
  String toast_exportFailed(Object error) {
    return 'エクスポートに失敗しました: $error';
  }

  @override
  String get toast_selectVibeToExport => '先にエクスポートする Vibe を選択してください';

  @override
  String get toast_embedPngSingleVibeOnly =>
      'PNG への埋め込みでは、1 つの Vibe のエクスポートのみがサポートされます';

  @override
  String get toast_selectPngCarrier => 'エクスポートする PNG キャリア画像を選択してください';

  @override
  String get toast_renameSuccess => '名前が正常に変更されました';

  @override
  String get toast_paramsSaved => 'パラメータが保存されました';

  @override
  String get toast_paramsSaveFailed => 'パラメータの保存に失敗しました';

  @override
  String get toast_dropNoReadableImageOrVibe =>
      'ドロップ ソースは読み取り可能な画像または Vibe ファイルを提供しませんでした';

  @override
  String toast_importedTasks(Object count) {
    return '$count 件のタスクをインポートしました';
  }

  @override
  String get toast_contentCannotBeEmpty => 'コンテンツを空にすることはできません';

  @override
  String get toast_addedToLibrary => 'ライブラリに追加されました';

  @override
  String toast_addFailed(Object error) {
    return '追加に失敗しました: $error';
  }

  @override
  String get toast_libraryNotLoaded => 'ライブラリがロードされていません';

  @override
  String get toast_noValidTagContent => '有効なタグの内容がありません';

  @override
  String get toast_allTagsAlreadyExist => 'すべてのタグはすでにライブラリに存在します';

  @override
  String get toast_noAddableTags => 'タグは追加できません';

  @override
  String toast_addedTagsSkippedDuplicates(Object added, Object skipped) {
    return '$added タグを追加し、$skipped 重複タグをスキップしました';
  }

  @override
  String get toast_favorited => 'お気に入りに登録しました';

  @override
  String get toast_unfavorited => 'お気に入りから削除しました';

  @override
  String toast_favoriteUpdateFailed(Object error) {
    return 'お気に入りの状態を更新できませんでした: $error';
  }

  @override
  String toast_packingImages(Object count) {
    return '$count 個の画像をパッキングしています...';
  }

  @override
  String toast_packedImages(Object count) {
    return '$count 個の画像をパックしました';
  }

  @override
  String get toast_packFailed => 'パックに失敗しました';

  @override
  String toast_packFailedWithError(Object error) {
    return 'パックに失敗しました: $error';
  }

  @override
  String get toast_saveDirNotSet => '保存ディレクトリが設定されていません';

  @override
  String toast_savedTo(Object path) {
    return '$path に保存されました';
  }

  @override
  String get toast_tagAlreadyExists => 'タグはすでに存在します';

  @override
  String get toast_nameRequired => '名前を入力してください';

  @override
  String get toast_savedToVibeLibrary => 'バイブライブラリに保存しました';

  @override
  String get toast_saveBundleFailed => 'バンドルの保存に失敗しました';

  @override
  String get toast_saveEntryFailed => 'エントリの保存に失敗しました';

  @override
  String get toast_presetNameRequired => 'プリセット名を入力してください';

  @override
  String get toast_selectPresetContent => '保存する項目を少なくとも 1 つ選択してください';

  @override
  String get toast_presetSaved => 'プリセットは正常に保存されました';

  @override
  String get toast_imagePromptCopied => 'プロンプトがコピーされました';

  @override
  String get toast_imageHasNoPrompt => 'この画像にはプロンプトがありません';

  @override
  String get toast_useDeleteButton => 'UI の削除ボタンを使用します。';

  @override
  String get toast_imageHasNoMetadata => 'この画像にはメタデータがありません';

  @override
  String get toast_imageDataUnavailable => '画像データが利用できないため、コピーできません';

  @override
  String get toast_tempFileCreateFailed => '一時ファイルの作成に失敗しました';

  @override
  String get toast_vibeDataCopied => 'Vibe データをコピーしました';

  @override
  String get toast_tagCopied => 'タグがコピーされました';

  @override
  String get toast_characterPromptCopied => 'キャラクタープロンプトをコピーしました';

  @override
  String toast_copiedTitle(Object title) {
    return '$title がコピーされました';
  }

  @override
  String toast_replacedVibesCount(Object count, Object name) {
    return '$count 件の Vibe を置換しました: $name';
  }

  @override
  String toast_sentVibesCount(Object count, Object name) {
    return '$count 件の Vibe を生成に送信しました: $name';
  }

  @override
  String toast_replacedVibe(Object name) {
    return '$name に置き換えました';
  }

  @override
  String toast_sentVibeToGeneration(Object name) {
    return '生成に送信しました: $name';
  }

  @override
  String get toast_unreadableDroppedImageSource =>
      'ドロップ ソースは読み取り可能な画像ファイルまたは画像 URL を提供しませんでした';

  @override
  String toast_appendedStyleReferences(Object count) {
    return '$count 件の絵柄参照を追加しました';
  }

  @override
  String get toast_appendedPreencodedVibe => '1 つの絵柄参照を追加 (事前にエンコード済みのバイブを再利用)';

  @override
  String get toast_addedPreencodedVibe =>
      '絵柄参照を追加しました (事前にエンコード済みのバイブを再利用し、2 Anlas を節約)';

  @override
  String toast_vibesMissingEncoding(Object count) {
    return '$count 件の Vibe にはエンコード済みデータがないため保存できません';
  }

  @override
  String toast_savedBundle(Object count) {
    return 'バンドルを保存しました ($count 件の Vibe)';
  }

  @override
  String get toast_replacedCharacterReference => 'キャラクター参照を置換しました';

  @override
  String toast_extractMetadataFailed(Object error) {
    return 'メタデータの抽出に失敗しました: $error';
  }

  @override
  String toast_extractPromptFailed(Object error) {
    return 'プロンプトを抽出できませんでした: $error';
  }

  @override
  String get toast_smartDecomposeSent => 'スマートに分解して送信';

  @override
  String get toast_addedToFixedTags => '固定タグに追加しました';

  @override
  String get toast_renameNameRequired => '名前は必須です';

  @override
  String get toast_renameNameConflict => '名前はすでに存在します。別の名前を使用してください。';

  @override
  String get toast_renameEntryNotFound => 'エントリはもう存在しないため、削除された可能性があります';

  @override
  String get toast_renameFilePathMissing => 'このエントリにはファイル パスがないため、名前を変更できません';

  @override
  String get toast_renameFileFailed => 'ファイル名の変更に失敗しました。後でもう一度試してください。';

  @override
  String get toast_renameFailed => '名前の変更に失敗しました。後でもう一度試してください。';

  @override
  String toast_processImageFailed(Object error) {
    return '画像の処理に失敗しました: $error';
  }

  @override
  String get toast_savePreviewFailed => 'プレビュー画像の保存に失敗しました';

  @override
  String get common_justNow => 'たった今';

  @override
  String common_minutesAgo(Object minutes) {
    return '$minutes 分前';
  }

  @override
  String common_hoursAgo(Object hours) {
    return '$hours 時間前';
  }

  @override
  String get common_saving => '保存中...';

  @override
  String get common_pleaseWait => 'お待ちください';

  @override
  String get common_change => '変更';

  @override
  String get common_expand => '展開する';

  @override
  String get common_collapse => '折りたたむ';

  @override
  String get vibeLibrary_emptySearchTitle => '一致する Vibe がありません';

  @override
  String get vibeLibrary_emptySearchSubtitle => '別のキーワードを試してください';

  @override
  String get vibeLibrary_emptyFavoritesTitle => 'お気に入りの Vibe はまだありません';

  @override
  String get vibeLibrary_emptyFavoritesSubtitle =>
      'ハートのアイコンをクリックして Vibe をお気に入りに追加します';

  @override
  String get vibeLibrary_emptyCategoryTitle => 'このカテゴリには Vibe がありません';

  @override
  String get vibeLibrary_emptyCategorySubtitle =>
      'すべてのエントリを表示するには「すべての Vibe」に切り替えてください';

  @override
  String get vibeLibrary_emptyNoMatchesTitle => '一致する結果はありません';

  @override
  String get vibeLibrary_emptySaveFromGenerationHint =>
      '生成ページから Vibe を保存してライブラリに追加します';

  @override
  String get vibe_nameRequired => '名前は必須です';

  @override
  String get vibe_import_namingTitle => 'Vibe に名前を付ける';

  @override
  String get vibe_import_nameConflictOverwrite => 'この名前はすでに存在するため上書きされます';

  @override
  String get vibe_previewLoadFailed => 'プレビューのロードに失敗しました';

  @override
  String get vibe_import_applyToRemainingFiles => '残りのすべてのファイルに適用します';

  @override
  String get vibe_import_applyNamingToRemainingFiles => '残りのファイルにはこの命名規則を使用します';

  @override
  String get vibe_encodeImageTitle => '画像を Vibe としてエンコード';

  @override
  String get vibe_imagePreview => '画像プレビュー';

  @override
  String get vibe_encodeStartButton => 'エンコードの開始';

  @override
  String get vibe_encodeImageInProgress => '画像をエンコード中...';

  @override
  String vibe_encodeErrorImage(Object fileName) {
    return '画像: $fileName';
  }

  @override
  String vibe_encodeErrorMessage(Object error) {
    return 'エラー: $error';
  }

  @override
  String get vibe_encodeSkipImage => 'この画像をスキップ';

  @override
  String get detail_sendToImg2Img => 'Image2Image に送信';

  @override
  String get detail_sendToReversePrompt => '逆プロンプトに送信';

  @override
  String get detail_loadingImage => '画像を読み込み中...';

  @override
  String get detail_imageLoadFailed => '画像のロードに失敗しました';

  @override
  String get detail_noImage => '画像がありません';

  @override
  String get detail_parsingMetadata => 'メタデータを解析しています...';

  @override
  String get detail_noMetadata => 'この画像にはメタデータがありません';

  @override
  String get detail_metadata => 'メタデータ';

  @override
  String get detail_imageDetails => '画像の詳細';

  @override
  String get detail_basicInfo => '基本情報';

  @override
  String get detail_fileName => 'ファイル名';

  @override
  String get detail_modifiedTime => '更新日時';

  @override
  String get detail_fileSize => 'ファイルサイズ';

  @override
  String get detail_noContent => '(コンテンツなし)';

  @override
  String get detail_savePreset => 'プリセットの保存';

  @override
  String detail_copyLabel(Object label) {
    return '$label をコピーします';
  }

  @override
  String get detail_copyCharacterPrompt => 'キャラクタープロンプトをコピー';

  @override
  String get detail_copyAllVibeData => 'すべての Vibe データをコピーします';

  @override
  String get detail_saveToVibeLibrary => 'バイブライブラリに保存';

  @override
  String get pagination_firstPage => '最初のページ';

  @override
  String get pagination_previousPage => '前のページ';

  @override
  String get pagination_nextPage => '次のページ';

  @override
  String get pagination_lastPage => '最後のページ';

  @override
  String get pagination_jumpToPage => 'ページへジャンプ';

  @override
  String get pagination_jump => 'ジャンプ';

  @override
  String get pagination_itemsPerPage => 'ページごと';

  @override
  String get pagination_itemUnit => 'アイテム';

  @override
  String get diyGuide_title => 'DIY 機能ガイド';

  @override
  String get diyGuide_subtitle => '高度な機能を学び、独自のライブラリを作成します';

  @override
  String get diyGuide_intro =>
      'このガイドでは、DIY システムの中核となる概念と高度な機能について説明し、強力な動的プロンプト ライブラリの構築に役立ちます。';

  @override
  String get diyGuide_exampleLabel => '例';

  @override
  String get diyGuide_hierarchyTitle => '階層';

  @override
  String get diyGuide_hierarchyDescription =>
      'DIY システムは、3 レベルのカテゴリ構造を使用してプロンプトを整理し、管理と検索を容易にします。';

  @override
  String get diyGuide_hierarchyExample =>
      'カテゴリ: キャラクターの特徴\n  -> グループ: ヘアスタイル\n      -> タグ: ロングヘア、ショートヘア、ツインテール';

  @override
  String get diyGuide_selectionModeTitle => '選択モード';

  @override
  String get diyGuide_selectionModeDescription => 'グループから選択されるタグの数を制御します。';

  @override
  String get diyGuide_selectionModeExample =>
      '• ランダム: ランダムな髪の色など、毎回 1 つのアイテムを選択します\n• すべて: 固定機能セットなど、グループ内のすべてのタグを選択します。';

  @override
  String get diyGuide_weightTitle => 'ウェイト制御';

  @override
  String get diyGuide_weightDescription => '生成中の特定のプロンプトの影響を調整します。';

  @override
  String get diyGuide_weightExample =>
      '• ブースト: masterpiece を中括弧で囲む = 1.05x ウェイト\n• 強力なブースト: masterpiece を三重中括弧で囲む = 1.16x ウェイト\n• 弱体化: [bad hands] = 0.95x ウェイト';

  @override
  String get diyGuide_genderTitle => '性別制限';

  @override
  String get diyGuide_genderDescription =>
      '互換性のない生成された機能を避けるために、タグを特定のキャラクターの性別に制限します。';

  @override
  String get diyGuide_genderExample =>
      '• 女性: スカートなどの女性キャラクターのみ\n• 男性: ひげなどの男性キャラクターのみ\n• 任意: T シャツなどの普遍的なもの';

  @override
  String get diyGuide_scopeTitle => '範囲';

  @override
  String get diyGuide_scopeDescription =>
      'タグをキャラクター、背景、または画像全体のどれに適用するかを定義します。';

  @override
  String get diyGuide_scopeExample =>
      '• キャラクター: 目や髪などのキャラクターの特徴\n• 背景: 青空や屋内などの環境の説明\n• グローバル: アート スタイルと品質タグ (最高品質など)';

  @override
  String get diyGuide_conditionalTitle => '条件分岐';

  @override
  String get diyGuide_conditionalDescription =>
      '選択したタグまたはその他の条件に基づいて、後のタグを動的に選択します。';

  @override
  String get diyGuide_conditionalExample =>
      '「雨」を選択した場合\n  次に、「傘」と「濡れた服」を追加します\n  ELSE「晴れ」を追加';

  @override
  String get diyGuide_dependenciesTitle => '依存関係';

  @override
  String get diyGuide_dependenciesDescription =>
      'タグ間のリンクを作成し、1 つのタグが選択されたときに関連タグが自動的に導入されるようにします。';

  @override
  String get diyGuide_dependenciesExample =>
      '「JK制服」を選択 -> 「学校背景」と「スクールバッグ」を自動追加';

  @override
  String get diyGuide_visibilityTitle => '可視性ルール';

  @override
  String get diyGuide_visibilityDescription =>
      'タグが UI にいつ表示されるか、または生成中にアクティブになるかを制御します。';

  @override
  String get diyGuide_visibilityExample =>
      '「魔法少女」カテゴリが選択されている場合に「魔法の杖」オプション グループのみを表示します';

  @override
  String get diyGuide_timeTitle => '時間条件';

  @override
  String get diyGuide_timeDescription =>
      'リアルタイムまたは設定されたシミュレート時間に基づいて特定のタグをトリガーします。';

  @override
  String get diyGuide_timeExample =>
      '• 06:00-18:00 -> \"daylight\" を追加\n• 18:00-06:00 -> \"night\" を追加';

  @override
  String get diyGuide_postProcessingTitle => '後処理ルール';

  @override
  String get diyGuide_postProcessingDescription =>
      'プロンプト生成の最終段階でテキストの置換またはクリーンアップを実行します。';

  @override
  String get diyGuide_postProcessingExample =>
      'より特徴的な説明のために、すべての「青い目」を「紺碧の目」に置き換えます。';

  @override
  String get diyGuide_emphasisTitle => '強調確率';

  @override
  String get diyGuide_emphasisDescription => '出力の多様性を高めるためにタグに重み構文をランダムに追加します。';

  @override
  String get diyGuide_emphasisExample =>
      '確率を 30% に設定します。出力の約 1/3 は重み付きタグを使用し、2/3 はプレーン タグを出力します。';

  @override
  String get naiRules_title => 'NAI ランダム ルール';

  @override
  String get naiRules_characterCountProbability => 'キャラクター数の確率';

  @override
  String get naiRules_solo => '1人（ソロ）';

  @override
  String get naiRules_duo => '2名（デュオ）';

  @override
  String get naiRules_trio => '3人（トリオ）';

  @override
  String get naiRules_group => '4名（グループ）';

  @override
  String get naiRules_genderRules => '性別ルール';

  @override
  String get naiRules_female => '女性';

  @override
  String get naiRules_male => '男性';

  @override
  String get naiRules_mixed => '混合 / その他';

  @override
  String get naiRules_categoryProbability => 'カテゴリの確率';

  @override
  String get naiRules_dynamicTagWeightTitle => '動的タグ重み調整';

  @override
  String get naiRules_dynamicTagWeightSubtitle =>
      'アクション、服装、表情、背景などの複数の要素をランダムに組み合わせて、画像のテーマに基づいてカテゴリの重みを調整します。';

  @override
  String get naiRules_specialMechanisms => '特別なメカニズム';

  @override
  String get naiRules_tagStrengthening => 'タグ強化';

  @override
  String get naiRules_seasonalLibraryTitle => '季節ライブラリ';

  @override
  String get naiRules_seasonalLibrarySubtitle =>
      '季節の服装、天候、照明、雰囲気などの季節の特徴を自動的に照合します。';

  @override
  String get naiRules_v4CharacterPositioning => 'V4 複数キャラクター配置';

  @override
  String get naiRules_smartPositionTitle => 'スマートな位置の割り当て';

  @override
  String get naiRules_smartPositionSubtitle =>
      'V4 モデルでは、キャラクター配置構文を使用して複数キャラクターの配置を正確に制御します。';

  @override
  String get comfyImport_detectedTitle => 'ComfyUI の複数キャラクタープロンプトを検出しました';

  @override
  String comfyImport_characterList(Object count) {
    return 'キャラクター一覧 ($count)';
  }

  @override
  String get comfyImport_usePositionInfo => '位置情報を利用する';

  @override
  String get comfyImport_usePositionInfoSubtitle =>
      'ComfyUI の領域を NAI のキャラクター位置にマップします';

  @override
  String comfyImport_convertCharacters(Object count) {
    return '$count 件のキャラクターを変換';
  }

  @override
  String get comfyImport_syntaxCouple => 'COUPLE 構文';

  @override
  String get comfyImport_syntaxAndMask => 'AND+MASK 構文';

  @override
  String get comfyImport_syntaxPipe => 'パイプ形式';

  @override
  String get comfyImport_syntaxUnknown => '不明な構文です';

  @override
  String get comfyImport_globalPrompt => 'グローバル プロンプト';

  @override
  String get danbooruPreview_noTagData => 'タグ データがありません';

  @override
  String get danbooruPreview_noPoolData => 'プール データがありません';

  @override
  String danbooruPreview_postCount(Object count) {
    return '$count 件の投稿';
  }

  @override
  String get checkForUpdate => 'アップデートを確認してください';

  @override
  String get neverChecked => 'チェックされていません';

  @override
  String lastCheckedAt(Object time) {
    return '最終チェック日: $time';
  }

  @override
  String get includePrereleaseUpdates => 'プレリリース バージョンを含む';

  @override
  String get includePrereleaseUpdatesDescription =>
      '更新をチェックするときにベータ/アルファ バージョンを含めます';

  @override
  String get updateAvailable => 'アップデートが利用可能です';

  @override
  String get updateChecking => 'アップデートをチェックしています...';

  @override
  String get updateDownloading => 'アップデートをダウンロードしています...';

  @override
  String get updateInstalling => 'インストーラーを起動しています...';

  @override
  String get updateUpToDate => 'すでに最新です';

  @override
  String get updateError => '更新の確認に失敗しました';

  @override
  String get currentVersion => '現在のバージョン';

  @override
  String get latestVersion => '最新バージョン';

  @override
  String get releaseNotes => 'リリースノート';

  @override
  String get updatePortableManualHint =>
      'ポータブル版では Release ページを開いて手動でダウンロードします。';

  @override
  String updateDownloadingProgress(Object percent) {
    return '更新パッケージをダウンロードしています: $percent%';
  }

  @override
  String get updateInstallingHint => 'インストーラーが起動しました。アプリはまもなく終了します。';

  @override
  String get remindMeLater => '後で通知する';

  @override
  String get skipThisVersion => 'このバージョンをスキップ';

  @override
  String get updateDownloadAndInstall => 'ダウンロードしてインストール';

  @override
  String get goToDownload => 'ダウンロードに移動';

  @override
  String get versionSkipped => 'バージョンがスキップされました';

  @override
  String get cannotOpenUrl => 'リンクを開けません';

  @override
  String get model3d_editorTitle => '3Dモデルレイヤー';

  @override
  String get model3d_addMannequin => '内蔵マネキンを追加';

  @override
  String get model3d_importModel => 'モデルをインポート (.glb/.gltf)';

  @override
  String get model3d_emptyHint => 'シーンは空です。マネキンを追加するかモデルをインポートしてください';

  @override
  String get model3d_apply => 'レイヤーに適用';

  @override
  String get model3d_modeTransform => '変換';

  @override
  String get model3d_modePose => 'ポーズ';

  @override
  String get model3d_gizmoTranslate => '移動';

  @override
  String get model3d_gizmoRotate => '回転';

  @override
  String get model3d_gizmoScale => '拡縮';

  @override
  String get model3d_undo => '元に戻す';

  @override
  String get model3d_resetPose => 'ポーズをリセット';

  @override
  String get model3d_replaceConfirm => '現在のモデルを置き換えますか？未適用のポーズは失われます。';

  @override
  String get model3d_discardConfirm => '未適用の変更を破棄しますか？';

  @override
  String get model3d_missingModel => 'モデルファイルが見つかりません。再インポートできます';

  @override
  String get model3d_loadError => 'モデルの読み込みに失敗しました';

  @override
  String get model3d_light => 'ライティング';

  @override
  String get model3d_lightIntensity => '強度';

  @override
  String get model3d_lightAzimuth => '方位角';

  @override
  String get model3d_lightElevation => '仰角';

  @override
  String get model3d_addLayerTooltip => '3Dモデルレイヤーを追加';

  @override
  String get model3d_webview2Missing =>
      '3DエディタにはMicrosoft Edge WebView2ランタイムが必要です。Windows 10/11には通常同梱されています。無い場合はMicrosoftからEvergreen版をインストールして再試行してください。';
}

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
  String get common_collapseAll => 'すべて折りたたむ';

  @override
  String get common_save => '保存';

  @override
  String get common_delete => '削除';

  @override
  String get common_edit => '編集';

  @override
  String get common_close => '閉じる';

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
  String get common_select => '選択してください';

  @override
  String get common_reset => 'リセット';

  @override
  String get common_search => '検索';

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
  String get common_apply => '適用する';

  @override
  String get common_move => '移動';

  @override
  String get common_favorite => 'お気に入り';

  @override
  String get common_unfavorite => 'お気に入りから削除';

  @override
  String get common_ok => 'OK';

  @override
  String get common_replace => '置換';

  @override
  String get common_skip => 'スキップ';

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
  String get networkError_connectionTimeout =>
      '接続がタイムアウトしました。ネットワーク接続を確認してください。';

  @override
  String get networkError_sendTimeout => '送信がタイムアウトしました。もう一度お試しください。';

  @override
  String get networkError_receiveTimeout =>
      '受信がタイムアウトしました。画像生成には時間がかかる場合があります。';

  @override
  String get networkError_requestCancelled => 'リクエストはキャンセルされました';

  @override
  String get networkError_connection => 'ネットワーク接続エラーです。接続を確認してください。';

  @override
  String get networkError_unknown => '不明なエラー';

  @override
  String get networkError_noResponse => 'サーバーから応答がありません';

  @override
  String get networkError_badRequest => 'リクエストパラメーターが無効です';

  @override
  String get networkError_authFailed => '認証に失敗しました。再度ログインしてください。';

  @override
  String get networkError_insufficientAnlas => 'Anlas が不足しています';

  @override
  String get networkError_forbidden => 'このリソースにアクセスする権限がありません';

  @override
  String get networkError_notFound => 'リクエストされたリソースが存在しません';

  @override
  String get networkError_conflict => 'リクエストが現在の状態と競合しています';

  @override
  String get networkError_rateLimited => 'リクエストが多すぎます。しばらくしてからもう一度お試しください。';

  @override
  String get networkError_serverInternal => 'サーバー内部エラー';

  @override
  String get networkError_badGateway => 'サーバーゲートウェイエラー';

  @override
  String get networkError_unavailable => 'サービスは一時的に利用できません';

  @override
  String networkError_requestFailed(int code) {
    return 'リクエストに失敗しました ($code)';
  }

  @override
  String get nav_canvas => 'キャンバス';

  @override
  String get nav_onlineGallery => 'オンライン ギャラリー';

  @override
  String get nav_randomConfig => 'ランダム構成';

  @override
  String get nav_dictionary => '辞書';

  @override
  String get nav_discordCommunity => 'Discord コミュニティ';

  @override
  String get nav_githubRepo => 'GitHub リポジトリ';

  @override
  String get nav_joinDiscord => 'Discord に参加';

  @override
  String get nav_projectRepository => 'プロジェクトリポジトリ';

  @override
  String get nav_expandSidebar => 'サイドバーを展開';

  @override
  String get nav_collapseSidebar => 'サイドバーを折りたたむ';

  @override
  String get auth_login => 'ログイン';

  @override
  String get auth_logout => 'ログアウト';

  @override
  String get auth_continueWithoutLogin => 'ログインせずにメイン画面へ';

  @override
  String get auth_loginRequiredImageGeneration =>
      'NovelAI で画像を生成するにはログインしてください。';

  @override
  String get auth_loginRequiredQueueExecution =>
      'NovelAI の生成キューを開始するにはログインしてください。';

  @override
  String get auth_loginRequiredDirectorTools =>
      'NovelAI Director Tools を使用するにはログインしてください。';

  @override
  String get auth_loginRequiredNovelAiUpscale =>
      'NovelAI クラウドアップスケールを使用するにはログインしてください。';

  @override
  String get auth_loginRequiredKritaBridge =>
      'Krita Bridge から画像を生成するにはログインしてください。';

  @override
  String get auth_loginRequiredVibeEncoding =>
      'NovelAI で Vibe 画像をエンコードするにはログインしてください。';

  @override
  String get auth_email => '電子メール';

  @override
  String get auth_password => 'パスワード';

  @override
  String get auth_loginButton => 'サインイン';

  @override
  String get auth_loginFailed => 'ログインに失敗しました';

  @override
  String get auth_loginTip =>
      'NovelAI アカウントでサインインしてください\nすべてのデータはローカルにのみ保存されます';

  @override
  String get auth_loggedIn => 'ログインしました';

  @override
  String get auth_emailRequired => 'メールアドレスを入力してください';

  @override
  String get auth_emailInvalid => '有効な電子メール アドレスを入力してください';

  @override
  String get auth_passwordRequired => 'パスワードを入力してください';

  @override
  String get auth_tokenLogin => 'API トークンのログイン';

  @override
  String get auth_tokenLoginCompact => 'トークンログイン';

  @override
  String get auth_tokenLoginRecommended => 'API トークンのログイン（推奨）';

  @override
  String get auth_credentialsLogin => '電子メールとパスワード';

  @override
  String get auth_credentialsLoginUnavailable =>
      'メールアドレス/パスワードでのログインは現在利用できません。Token ログインを使用してください。';

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
  String get auth_removeAvatar => 'アバターを削除';

  @override
  String get auth_selectFromGallery => 'ギャラリーから選択';

  @override
  String get auth_quickLogin => 'クイックログイン';

  @override
  String get auth_nicknameRequired => 'ニックネームを入力してください';

  @override
  String auth_createdAt(Object date) {
    return '作成日時: $date';
  }

  @override
  String get auth_error_networkTimeout => '接続タイムアウト';

  @override
  String get auth_error_networkError => 'ネットワークエラー';

  @override
  String get auth_error_authFailed => '認証に失敗しました';

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
  String get settings_languageChinese => '简体中文';

  @override
  String get settings_languageTraditionalChinese => '繁體中文';

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
  String get settings_generationOutputSection => '画像出力';

  @override
  String get settings_generationRetrySection => '失敗時リトライ';

  @override
  String get settings_generationFeedbackSection => '完了通知';

  @override
  String get settings_alphaModeTitle => '透過画像のアルファモード';

  @override
  String get settings_alphaModeStraight => 'ストレート';

  @override
  String get settings_alphaModePremultiplied => '乗算済み';

  @override
  String get settings_alphaModeStraightDescription =>
      'アルファを乗算せずに RGB を保持します。追加編集向けで、NovelAI 公式サイトのデフォルトです。';

  @override
  String get settings_alphaModePremultipliedDescription =>
      'RGB にアルファを乗算し、乗算済み入力を必要とする合成・レンダリング処理に適した形式にします。';

  @override
  String get settings_promptAssistant => 'プロンプトアシスタント';

  @override
  String get settings_comfyUiDesktopOnly => 'デスクトップ版でのみ利用できます';

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
  String get settings_imageSavePath => '画像の保存場所';

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
  String get settings_pathSavedRestartRequired =>
      'パスが更新されました。変更を適用するには再起動してください';

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
  String get settings_nickname => 'ニックネーム';

  @override
  String get settings_nicknameHint => '2 ～ 32 文字を入力してください';

  @override
  String get settings_nicknameEmpty => 'ニックネームを入力してください';

  @override
  String settings_nicknameTooLong(int maxLength) {
    return 'ニックネームは $maxLength 文字を超えることはできません';
  }

  @override
  String get settings_nicknameUpdated => 'ニックネームが更新されました';

  @override
  String get settings_avatarUpdated => 'アバターが更新されました';

  @override
  String get settings_avatarRemoved => 'アバターが削除されました';

  @override
  String get settings_setAsDefaultSuccess => 'デフォルトのアカウントとして設定';

  @override
  String get generation_title => '生成';

  @override
  String generation_promptOverviewCharacters(Object count) {
    return '$count 文字';
  }

  @override
  String get generation_generate => '生成';

  @override
  String generation_cooldownRemaining(Object seconds) {
    return 'あと$seconds秒';
  }

  @override
  String get generation_generating => '生成中...';

  @override
  String get generation_cancelGeneration => '生成のキャンセル';

  @override
  String get generation_skipCurrentBatch => '現在のバッチをスキップ';

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
  String get agentChat_tab => 'チャット';

  @override
  String get agentChat_inputHint => 'AI アシスタントにメッセージを送る…';

  @override
  String get agentChat_attachImage => '画像を追加';

  @override
  String agentChat_unsupportedImageFormat(Object fileName) {
    return 'サポートされていない画像形式です: $fileName';
  }

  @override
  String get agentChat_newChat => '新しいチャット';

  @override
  String get agentChat_send => '送信';

  @override
  String get agentChat_stop => '停止';

  @override
  String get agentChat_queued => '待機中';

  @override
  String get agentChat_thinking => '思考中…';

  @override
  String get agentChat_toolRunning => 'ツール実行中';

  @override
  String get agentChat_needSetup =>
      'チャットモデルが未設定です。先に設定でツール呼び出しに対応したプロバイダーを追加してください。';

  @override
  String get agentChat_heroTitle => 'AI アシスタント';

  @override
  String get agentChat_heroSubtitle => '会話でプロンプトとキャラクターを編集';

  @override
  String get agentChat_moreActions => '操作メニュー';

  @override
  String get agentChat_compact => 'コンテキスト圧縮';

  @override
  String get agentChat_compacting => 'コンテキストを圧縮中…';

  @override
  String get agentChat_model => 'モデルを選択';

  @override
  String get agentChat_noModel => 'モデル未設定';

  @override
  String get agentChat_untitled => '新しいチャット';

  @override
  String get agentChat_renameHint => 'チャット名';

  @override
  String get agentChat_suggestion1 => '現在のポジティブプロンプトを改善して';

  @override
  String get agentChat_suggestion2 => '2人のキャラを追加してポーズを設定して';

  @override
  String get agentChat_suggestion3 => 'ネガティブプロンプトをリアル系に書き換えて';

  @override
  String get agentChat_permissionMode => 'Agent 権限';

  @override
  String get agentChat_permissionSafe => 'セーフ';

  @override
  String get agentChat_permissionSafeDescription => '副作用のないツールのみ実行';

  @override
  String get agentChat_permissionAsk => '確認';

  @override
  String get agentChat_permissionAskDescription => '機密性の高い操作の前に確認';

  @override
  String get agentChat_permissionFull => 'フルアクセス';

  @override
  String get agentChat_permissionFullDescription => '確認なしで実行し、ワークスペース外のファイルも許可';

  @override
  String agentChat_approvalTitle(Object toolName) {
    return '$toolName の実行を許可しますか？';
  }

  @override
  String get agentChat_approvalDescription =>
      'このツールはローカルデータの読み取り、アプリ状態の変更、または料金の発生を伴う可能性があります。';

  @override
  String get agentChat_approvalAllow => '今回のみ許可';

  @override
  String get agentChat_approvalDeny => '拒否';

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
  String generation_opusUsageRemaining(Object percent) {
    return 'Opus 無料生成の残り $percent%';
  }

  @override
  String generation_opusUsageEstimate(Object count) {
    return 'あと約 $count 枚生成可能';
  }

  @override
  String get generation_opusUsageRefill => '上限は時間経過で自動回復します';

  @override
  String get generation_opusUsageExhausted =>
      'Opus の無料枠を使い切りました。回復するまで V5 の生成には Anlas を消費します。';

  @override
  String get generation_imageSize => '画像サイズ';

  @override
  String get generation_transparentBackground => '透過背景';

  @override
  String generation_e2eUpscaleHint(Object size) {
    return 'サーバー出力 $size';
  }

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
  String get generation_previewApplySeed => '表示中の画像のシードを使う';

  @override
  String get generation_transparencyBackgroundTitle => '透過部分の表示';

  @override
  String get generation_transparencyChecker => 'テーマに合わせたチェック模様';

  @override
  String get generation_transparencyCheckerLight => '明るいチェック模様';

  @override
  String get generation_transparencyCheckerDark => '暗いチェック模様';

  @override
  String get generation_transparencyNone => 'なし';

  @override
  String get generation_transparencyBlack => '黒';

  @override
  String get generation_transparencyWhite => '白';

  @override
  String get generation_transparencyGray => 'グレー';

  @override
  String get generation_transparencyRed => '赤';

  @override
  String get generation_transparencyGreen => '緑';

  @override
  String get generation_transparencyBlue => '青';

  @override
  String get generation_transparencyCustom => 'カスタムカラー';

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
  String get generation_smeaDescription =>
      '特定の画像サイズを超えると、高解像度サンプラーが自動的に使用されます。';

  @override
  String generation_cfgRescale(Object value) {
    return 'CFG リスケール: $value';
  }

  @override
  String get generation_noiseSchedule => 'ノイズスケジュール';

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
  String get prompt_finalPrompt => '最終的な有効なプロンプト';

  @override
  String get prompt_finalNegative => '最終有効な除外したい要素';

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
  String get prompt_inputPrompt => '生成したい画像を説明';

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
  String get prompt_replaceHint => '置換後の文字列';

  @override
  String get prompt_replaceToggle => '置換欄の表示切り替え';

  @override
  String get prompt_replaceCurrent => '現在の一致を置換（Enter）';

  @override
  String get prompt_replaceAll => 'すべて置換（Ctrl+Enter）';

  @override
  String prompt_replaceAllDone(Object count) {
    return '$count 件を置換しました';
  }

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
  String get prompt_smartAutocomplete => 'スマート オートコンプリート';

  @override
  String get prompt_smartAutocompleteSubtitle => '入力中にタグの候補を表示します';

  @override
  String get prompt_autoFormat => '自動フォーマット';

  @override
  String get prompt_autoFormatSubtitle => '改行を保持しながら、中国語のカンマとタグ内の空白を変換します';

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
  String get prompt_resolveAliasOnCopy => 'コピー時に単語ライブラリを展開';

  @override
  String get prompt_resolveAliasOnCopySubtitle =>
      'コピーまたは切り取り時に <ライブラリ名> をその内容に置き換えます';

  @override
  String get prompt_cooccurrenceRecommendation => '共起タグの推奨事項';

  @override
  String get prompt_cooccurrenceRecommendationSubtitle =>
      'タグ確定後に自動表示。Ctrl+Shift+Space または Ctrl+クリックでも表示できます';

  @override
  String get prompt_regexRulesManage => '正規表現置換ルール…';

  @override
  String prompt_regexRulesCount(int count) {
    return '$count 件のルールを設定済み';
  }

  @override
  String prompt_regexReplaceApplied(int count) {
    return '正規表現置換 $count 件';
  }

  @override
  String prompt_regexInvalidRules(Object names) {
    return '無効な正規表現ルールをスキップしました: $names';
  }

  @override
  String get regexRules_title => '正規表現置換ルール';

  @override
  String get regexRules_hint =>
      'ルールはプロンプト全体に順番に適用され、SD 変換と自動フォーマットより先に実行されます。置換文字列では \$1、\$2 でキャプチャグループを参照できます。';

  @override
  String get regexRules_empty => 'ルールがありません。下のボタンから作成してください';

  @override
  String get regexRules_add => 'ルールを新規作成';

  @override
  String get regexRules_unnamed => '名称未設定のルール';

  @override
  String get regexRules_invalidBadge => '無効';

  @override
  String get regexRules_deleteConfirmTitle => 'ルールを削除';

  @override
  String regexRules_deleteConfirmMessage(Object name) {
    return '「$name」を削除しますか？この操作は取り消せません。';
  }

  @override
  String get regexRules_newTitle => 'ルールを新規作成';

  @override
  String get regexRules_editTitle => 'ルールを編集';

  @override
  String get regexRules_nameLabel => 'ルール名（任意）';

  @override
  String get regexRules_nameHint => '例: 髪色の表記を統一';

  @override
  String get regexRules_patternLabel => 'マッチ（正規表現）';

  @override
  String get regexRules_patternHint => '例: \\bblue[ _]hair\\b';

  @override
  String get regexRules_replacementLabel => '置換後';

  @override
  String get regexRules_replacementHint => '例: aqua hair';

  @override
  String get regexRules_caseSensitive => '大文字と小文字を区別する';

  @override
  String get regexRules_patternRequired => 'マッチ内容を空にはできません';

  @override
  String regexRules_patternInvalid(Object error) {
    return '正規表現が無効です: $error';
  }

  @override
  String get regexRules_testTitle => 'テスト';

  @override
  String get regexRules_testInputHint => 'プロンプトを貼り付けて結果を確認';

  @override
  String get regexRules_testNoChange => '変化なし';

  @override
  String get regexRules_testNoRules => '有効なルールがありません';

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
  String get config_newPreset => '新しいプリセット';

  @override
  String get config_deletePreset => 'プリセットを削除';

  @override
  String get img2img_title => 'Image2Image';

  @override
  String get img2img_enabled => '有効';

  @override
  String get img2img_sourceImage => 'ソース画像';

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
  String get img2img_editImage => '画像を編集';

  @override
  String get img2img_editApplied => '編集された画像が新しいソース画像になりました';

  @override
  String get img2img_uploadImage => '画像をアップロード';

  @override
  String get img2img_drawSketch => 'スケッチを描く';

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
  String get img2img_directorSourceImage => 'ソース画像';

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
  String get img2img_enhanceScaleMax => '最大';

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
  String get img2img_novelAiCloudUpscale => 'NovelAI クラウド拡大 (2x 固定)';

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
      '利用可能な SeedVR2 モデルが見つかりません。モデル一覧を更新し、ComfyUI ネイティブの models/diffusion_models と models/vae、または SeedVR2 カスタムノードのモデルフォルダーを確認してください。';

  @override
  String get img2img_noRegularUpscaleModels =>
      '通常の拡大モデルが見つかりません。モデルリストを更新するか、models/upscale_models を確認してください。';

  @override
  String get img2img_useNativeSeedvr2Workflow =>
      'ComfyUI ネイティブ SeedVR2 の 1 ステップ拡大ワークフローを使用します。';

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
  String get img2img_seedvr2Engine => 'SeedVR2 エンジン';

  @override
  String get img2img_seedvr2EngineAuto => '自動';

  @override
  String get img2img_seedvr2EngineNative => 'ネイティブ';

  @override
  String get img2img_seedvr2EngineLegacy => '互換ノード';

  @override
  String get img2img_seedvr2EngineResolvedNative =>
      'ComfyUI ネイティブの SeedVR2 を使用しています。';

  @override
  String get img2img_seedvr2EngineResolvedLegacy =>
      'インストール済みの SeedVR2 カスタムノードを使用しています。';

  @override
  String get img2img_seedvr2EngineUnavailable =>
      '選択した SeedVR2 エンジンまたは必要なモデルを利用できません。モデル一覧を更新するか、エンジンを切り替えてください。';

  @override
  String get img2img_seedvr2VaeTileHint =>
      'SeedVR2 VAE のエンコードとデコードに使用するタイルサイズを設定します。';

  @override
  String get img2img_seedvr2UseTiledUpscale => 'タイル状の拡大を使用する';

  @override
  String get img2img_seedvr2UseTiledUpscaleHint =>
      '有効にすると、SeedVR2TilingUpscaler が使用されます。大きな画像や VRAM 負荷が高い場合に推奨します。';

  @override
  String get settings_comfyUiSeedvr2EmbedNaiMetadata =>
      'SeedVR2 の結果に NAI 生成パラメータを書き込む';

  @override
  String get settings_comfyUiSeedvr2EmbedNaiMetadataHint =>
      '既定では無効です。有効にすると、ランチャーの現在のプロンプトと生成パラメータを書き込みます。無効の場合は、ComfyUI から返された PNG メタデータをそのまま保持します。';

  @override
  String get img2img_seedvr2TileSize => 'タイルのサイズ';

  @override
  String get img2img_seedvr2TileSizeHint =>
      'SeedVR2TilingUpscaler tile_width / tile_height も制御します。';

  @override
  String get img2img_seedvr2BlocksToSwap => 'メモリへ退避するブロック数';

  @override
  String get img2img_seedvr2BlocksToSwapHint =>
      'DiT ブロックのうち何個をシステムメモリに置き、推論時に VRAM へ順次転送するかを指定します。大きいほど VRAM を節約できますがメモリを消費し遅くなります。VRAM に余裕がある場合は 0 まで下げられます。メモリ不足エラーが出る場合は上げてください。';

  @override
  String get img2img_upscalePanelOpened => 'Image2Image の拡大パネルを開きました';

  @override
  String get editor_done => '完了';

  @override
  String get editor_tolerance => '許容差';

  @override
  String get editor_intensity => '強度';

  @override
  String get editor_sourcePoint => 'Alt+クリックしてソースポイントを設定します';

  @override
  String get editor_brushPresets => 'ブラシ プリセット';

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
  String get editor_clearSelection => '選択をクリア';

  @override
  String get editor_resetView => 'ビューをリセット';

  @override
  String get editor_zoom => 'ズーム';

  @override
  String get editor_toolBrush => 'ブラシ';

  @override
  String get editor_toolEraser => '消しゴム';

  @override
  String get editor_toolFill => '塗りつぶし';

  @override
  String get editor_toolMagicWand => 'マジックワンド';

  @override
  String get editor_magicWandMode => '選択方法';

  @override
  String get editor_magicWandSmartObject => 'スマートオブジェクト（EfficientViT）';

  @override
  String get editor_magicWandColorArea => '色領域（塗りつぶし）';

  @override
  String get editor_magicWandSmartHelp =>
      '選択するオブジェクトをクリックします。初回使用時に MIT Han Lab から約 133 MiB の EfficientViT-SAM L0 モデル（Apache-2.0）をダウンロードし、以後はローカルに保存します。';

  @override
  String get editor_magicWandColorHelp =>
      '近い色の連続領域をクリックします。境界が明瞭なフラット画像に適し、モデルのダウンロードは不要です。';

  @override
  String get editor_magicWandInvert => '結果を反転';

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
  String get editor_shortcutUndo => '元に戻す (Ctrl+Z)';

  @override
  String get editor_shortcutRedo => 'やり直し (Ctrl+Y)';

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
  String get editor_magicWandNoSource => 'サンプリング可能な画像レイヤーがありません。';

  @override
  String get editor_magicWandNothingChanged => '選択した領域はすでに透明、またはマスク済みです。';

  @override
  String get editor_magicWandModelPreparing => 'EfficientViT-SAM モデルを確認しています…';

  @override
  String editor_magicWandModelDownloading(int percent) {
    return 'EfficientViT-SAM モデルをダウンロード中：$percent%';
  }

  @override
  String get editor_magicWandModelLoading => 'EfficientViT-SAM モデルを読み込んでいます…';

  @override
  String get editor_magicWandEncoding => '画像内のオブジェクトを解析しています…';

  @override
  String get editor_magicWandSegmenting => 'クリック位置のオブジェクトを分割しています…';

  @override
  String get editor_magicWandPostprocessing => '選択範囲を生成しています…';

  @override
  String editor_magicWandFailed(Object error) {
    return 'マジックワンドに失敗しました: $error';
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
  String get editor_brushSettings => 'ブラシ設定';

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
  String get vibe_referenceStrength => '参照強度';

  @override
  String get vibe_infoExtraction => '抽出情報';

  @override
  String get vibe_remove => '削除';

  @override
  String get reference_enabled => '有効';

  @override
  String get reference_enable => '参照を有効化';

  @override
  String get reference_disable => '参照を無効化';

  @override
  String get vibe_normalize => '基準強度値の正規化';

  @override
  String get vibe_sourceType_png => 'PNG';

  @override
  String get vibe_sourceType_v4vibe => 'Vibe ファイル';

  @override
  String get vibe_sourceType_bundle => 'バンドル';

  @override
  String get vibe_sourceType_image => '画像';

  @override
  String get vibe_sourceType => 'ソース';

  @override
  String get vibe_reuseButton => '再利用';

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
  String get character_buttonLabel => 'キャラクター';

  @override
  String get character_addCharacter => 'キャラクターを追加';

  @override
  String character_limitReached(Object limit) {
    return 'このモデルのキャラクター上限（$limit）に達しました';
  }

  @override
  String character_number(Object index) {
    return 'キャラクター $index';
  }

  @override
  String get character_summaryEmpty => 'キャラクター未追加';

  @override
  String character_summaryEnabled(int count, String name) {
    return '$count人有効 · $name';
  }

  @override
  String character_summaryMore(int count, String name, int additional) {
    return '$count人有効 · $name +$additional';
  }

  @override
  String character_summaryAllDisabled(int count) {
    return '0人有効 · $count人無効';
  }

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
  String get gallery_promptCopied => 'プロンプトがコピーされました';

  @override
  String get gallery_seedCopied => 'シードがコピーされました';

  @override
  String get gallery_sendToKritaAction => 'Krita に送信';

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
  String get gallery_upscale => '拡大';

  @override
  String get gallery_sentToImg2Img => '画像を Image2Image に送信しました';

  @override
  String get gallery_sentToReversePrompt => '画像がリバースプロンプトモジュールに送信されました';

  @override
  String gallery_sendFailed(Object error) {
    return '送信失敗: $error';
  }

  @override
  String get preset_presetName => 'プリセット名';

  @override
  String get onlineGallery_search => '検索';

  @override
  String get onlineGallery_popular => '人気';

  @override
  String get onlineGallery_sourceDoesNotSupportPopular =>
      '現在のサイトは人気ランキングに対応していません';

  @override
  String get onlineGallery_favorites => 'お気に入り';

  @override
  String get onlineGallery_searchFavorites => 'お気に入りのタイトル・作者・タグを検索…';

  @override
  String get onlineGallery_savedLocally => 'ローカルに保存済み';

  @override
  String get onlineGallery_savedInCloud => 'クラウドに保存済み';

  @override
  String get onlineGallery_saveVisibleLocally => 'このページをローカル保存';

  @override
  String get onlineGallery_visibleFavoritesAlreadySaved =>
      'このページはすべてローカル保存済みです';

  @override
  String get onlineGallery_localFavoritesPartialFailure =>
      'ローカルお気に入りの読み込みに失敗しました。クラウドの結果は保持されています';

  @override
  String get onlineGallery_cloudFavoritesPartialFailure =>
      'クラウドお気に入りの読み込みに失敗しました。ローカルの結果は保持されています';

  @override
  String onlineGallery_visibleFavoritesSaved(int count) {
    return '$count 件をローカルお気に入りに保存しました';
  }

  @override
  String onlineGallery_saveFavoritesFailed(String error) {
    return 'ローカルお気に入りの保存に失敗しました：$error';
  }

  @override
  String get onlineGallery_searchTags => 'タグを検索...';

  @override
  String onlineGallery_maxTagsExceeded(int max) {
    return '一度に組み合わせて検索できるタグは最大 $max 個です';
  }

  @override
  String get onlineGallery_tagDetailsIncomplete =>
      '一部の作品で完全なタグ一覧を取得できませんでした。未確認の作品は除外されています。再試行してください。';

  @override
  String get onlineGallery_unsupportedMetatag =>
      'このソースまたはモードではメタタグ構文を使用できません。通常のタグを使うか、ソース検索に切り替えてください。';

  @override
  String onlineGallery_multiTagScanning(int requests, int candidates) {
    return 'タグを組み合わせて検索中：$requests ページを取得し、$candidates 件の候補を確認しました';
  }

  @override
  String get onlineGallery_scanPaused =>
      '複数ページの候補を確認しましたが、十分な結果が見つかりませんでした。後続ページの検索を続けられます。';

  @override
  String get onlineGallery_continueScanning => '検索を続ける';

  @override
  String get onlineGallery_refresh => '更新';

  @override
  String get onlineGallery_random => 'ランダム';

  @override
  String get onlineGallery_randomRedraw => 'もう一度抽選';

  @override
  String get onlineGallery_randomDrawing => '抽選中…';

  @override
  String get onlineGallery_randomExhausted => 'この範囲に未表示の画像はありません';

  @override
  String get onlineGallery_randomDrawNoMatch =>
      '今回は条件に合う画像を取得できませんでした。続けて抽選できます。';

  @override
  String get onlineGallery_randomRestart => '最初から';

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
  String get onlineGallery_score => 'スコア';

  @override
  String get onlineGallery_ratingLabel => 'レーティング';

  @override
  String get onlineGallery_favCount => 'お気に入り';

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
  String get onlineGallery_promptTagCategories => 'プロンプトタグのカテゴリ';

  @override
  String get onlineGallery_promptTagCategoriesTooltip =>
      'コピー、送信、キューへの追加時に含めるタグカテゴリを選択します';

  @override
  String get onlineGallery_keepOnePromptTagCategory =>
      'プロンプトタグのカテゴリを1つ以上選択してください';

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
  String get onlineGallery_noImageUrl => 'この画像には利用可能な URL がありません';

  @override
  String get onlineGallery_pinchToZoom => 'ピンチしてズーム';

  @override
  String get onlineGallery_metadata => 'メタデータ';

  @override
  String onlineGallery_addedToQueueWithCount(Object count) {
    return 'キューに追加しました。現在 $count 件が実行待ちです';
  }

  @override
  String get onlineGallery_queueFullMax => 'キューがいっぱいです (最大 50 項目)';

  @override
  String get onlineGallery_chooseDownloadDirectory => 'ダウンロード ディレクトリを選択してください';

  @override
  String get onlineGallery_downloadStarted => 'ダウンロードが開始されました...';

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
  String get onlineGallery_sourceGeneralOnly => 'このソースは全年齢向けコンテンツのみ提供します';

  @override
  String get onlineGallery_sourceUnrated => 'ソース未分類';

  @override
  String get onlineGallery_sourceUnratedTooltip =>
      'このソースには信頼できるコンテンツ分類がないため、アプリで正確に推定できません';

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
  String get onlineGallery_blacklistShort => '除外';

  @override
  String get onlineGallery_blacklistTags => 'ブラックリスト タグ';

  @override
  String get onlineGallery_outputFilter => '出力フィルター';

  @override
  String get onlineGallery_outputFilterShort => '出力';

  @override
  String get onlineGallery_outputFilterTooltip =>
      'コピー、送信、キュー追加時に自動で除外するタグを管理します';

  @override
  String get onlineGallery_outputFilterTitle => '出力フィルタータグ';

  @override
  String get onlineGallery_outputFilterSubtitle =>
      '画像は表示されたまま、完全一致するタグだけをコピー・送信・キューのプロンプトから除外します。';

  @override
  String get onlineGallery_outputFilterAddHint => '出力から除外するタグを追加';

  @override
  String get onlineGallery_outputFilterInputHint => '複数のタグはカンマまたは改行で区切ります';

  @override
  String get onlineGallery_outputFilterEmpty => '出力フィルタータグは設定されていません';

  @override
  String get onlineGallery_outputFilterRestoreDefaults => 'デフォルトに戻す';

  @override
  String get onlineGallery_outputFilterClearTitle => '出力フィルターをクリアしますか？';

  @override
  String get onlineGallery_outputFilterClearConfirm =>
      '透かしやモザイクのタグがコピー・送信するプロンプトに再び含まれます。';

  @override
  String get onlineGallery_addTagToOutputFilter => '出力フィルターに追加';

  @override
  String get onlineGallery_outputFilterAlreadyAdded => '出力フィルターに追加済み';

  @override
  String get onlineGallery_outputFilterMenuHint => '画像は表示したまま、このタグだけを出力から除外します';

  @override
  String get onlineGallery_addTagToBlacklist => 'ブラックリストに追加';

  @override
  String get onlineGallery_blacklistAlreadyAdded => 'ブラックリストに追加済み';

  @override
  String get onlineGallery_blacklistMenuHint => 'このタグを含むギャラリー画像を非表示にします';

  @override
  String get onlineGallery_outputFilteredTagTooltip =>
      'コピー、送信、キュー追加時に除外されます。右クリックで管理できます';

  @override
  String get onlineGallery_tagContextMenuTooltip =>
      '右クリックでブラックリストまたは出力フィルターに追加';

  @override
  String onlineGallery_outputFilterTagAdded(Object tag) {
    return '$tag を出力フィルターに追加しました';
  }

  @override
  String onlineGallery_blacklistTagAdded(Object tag) {
    return '$tag をブラックリストに追加しました';
  }

  @override
  String get onlineGallery_blacklistTitle => 'オンライン ギャラリー ブラックリスト';

  @override
  String get onlineGallery_blacklistSubtitle =>
      'すべてのオンラインギャラリーで共有され、オフラインでもフィルタリングします。';

  @override
  String get onlineGallery_blacklistCloudDescription =>
      'Danbooru に接続済みです。ローカルの変更は安全にマージして同期します';

  @override
  String get onlineGallery_blacklistCloudLoginRequired =>
      'ローカルのブラックリストは有効です。Danbooru にログインすると同期できます';

  @override
  String get onlineGallery_blacklistCloudUnavailable =>
      'ローカルのブラックリストは有効です。Danbooru の接続確認後にクラウド同期を再開します';

  @override
  String get onlineGallery_addBlacklistTagHint => 'ブラックリスト タグを追加';

  @override
  String get onlineGallery_noLocalBlacklistTags => 'ブラックリスト タグがありません';

  @override
  String get onlineGallery_pullBlacklist => 'クラウドを取得';

  @override
  String get onlineGallery_pushBlacklist => 'クラウドへ送信';

  @override
  String get onlineGallery_pushBlacklistConfirmTitle => '統一リストでクラウドを置き換えますか？';

  @override
  String get onlineGallery_pushBlacklistConfirmBody =>
      'Danbooru クラウドのブラックリストを完全に置き換えます。通常の同期では不明な高度なルールを保持しますが、今回の完全送信では削除されます。';

  @override
  String get onlineGallery_blacklistPushSucceeded =>
      'クラウドをローカルのブラックリストで置き換えました';

  @override
  String get onlineGallery_blacklistSyncFailedMessage =>
      '同期に失敗しました。ログイン状態とネットワーク接続を確認してください。';

  @override
  String onlineGallery_blacklistSaveFailed(String error) {
    return 'ブラックリストの保存に失敗しました：$error';
  }

  @override
  String get onlineGallery_autoSyncOnStartup => '起動時にクラウドリストを更新';

  @override
  String get onlineGallery_autoSyncOnStartupSubtitle =>
      'ローカルタグを削除せず、クラウドの新しいタグを安全にマージします';

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
  String get onlineGallery_blacklistImportTitle => 'タグを一括インポート';

  @override
  String get onlineGallery_blacklistImportHint => '1 行に 1 タグ、またはカンマで区切って入力します';

  @override
  String onlineGallery_blacklistImported(Object count) {
    return '$count 個のタグを追加しました';
  }

  @override
  String get onlineGallery_blacklistClearTitle => '統一ブラックリストをクリアしますか？';

  @override
  String get onlineGallery_blacklistClearBody =>
      'ギャラリーはこれらのタグによるフィルタリングを直ちに停止します。クラウドは自動的にクリアされず、この操作は元に戻せます。';

  @override
  String onlineGallery_blacklistPullSummary(
    Object added,
    Object existing,
    Object skipped,
    Object opaque,
  ) {
    return '$added 件追加、$existing 件は登録済み、削除済み $skipped 件をスキップし、高度なクラウドルール $opaque 件を保持しました';
  }

  @override
  String onlineGallery_blacklistPushDiff(
    Object added,
    Object removed,
    Object opaque,
  ) {
    return 'クラウドに $added 件追加、$removed 件削除し、高度なルール $opaque 件を削除します。';
  }

  @override
  String get onlineGallery_blacklistCloudEmptyConfirm =>
      'クラウドのブラックリストをクリアすることを確認';

  @override
  String get onlineGallery_blacklistMigrationConfirm =>
      'このリストにはアカウントを特定できない旧バージョンのクラウドタグが含まれます。現在のアカウントへの同期を確認してください';

  @override
  String get onlineGallery_bulkFavorite => '選択項目をお気に入りに追加';

  @override
  String get onlineGallery_bulkDownload => '選択項目をダウンロード';

  @override
  String onlineGallery_addedTasksToQueue(Object count) {
    return '$count タスクをキューに追加しました';
  }

  @override
  String onlineGallery_queueBatchCompleted(
    Object added,
    Object prepareFailed,
    Object queueSkipped,
  ) {
    return '$added 件を追加しました。$prepareFailed 件は準備できず、$queueSkipped 件はキューがいっぱいのため追加されませんでした';
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
  String onlineGallery_downloadSelectedCompletedWithSkipped(
    Object success,
    Object failed,
    Object skipped,
  ) {
    return 'ダウンロード完了：$success 件成功、$failed 件失敗、テキストのみの項目 $skipped 件をスキップ';
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
  String get onlineGallery_configureGelbooruApi => 'Gelbooru API を設定';

  @override
  String get onlineGallery_gelbooruApiReady => 'Gelbooru API は検証済みです';

  @override
  String get onlineGallery_gelbooruApiInvalid => 'Gelbooru 認証情報が無効です';

  @override
  String get onlineGallery_gelbooruCredentialsRequired =>
      'ウェブサイトのお気に入りを表示するには、Gelbooru の User ID と API Key を設定してください。';

  @override
  String get onlineGallery_gelbooruCredentialsInvalid =>
      'Gelbooru 認証情報が無効になりました。再設定してください。';

  @override
  String get onlineGallery_gelbooruRateLimited =>
      'Gelbooru のリクエスト回数が多すぎます。しばらくしてから再試行してください。';

  @override
  String get onlineGallery_gelbooruTimeout =>
      'Gelbooru リクエストがタイムアウトしました。ネットワーク接続を確認してください。';

  @override
  String get onlineGallery_gelbooruServerError => 'Gelbooru サーバーは一時的に利用できません。';

  @override
  String get onlineGallery_gelbooruNetworkError =>
      'Gelbooru に接続できません。ネットワークまたはプロキシ設定を確認してください。';

  @override
  String get onlineGallery_gelbooruMalformedResponse =>
      'Gelbooru から解析できないデータが返されました。';

  @override
  String get onlineGallery_gelbooruRequestFailed =>
      'Gelbooru リクエストに失敗しました。しばらくしてから再試行してください。';

  @override
  String get onlineGallery_aiTagQuery => '作品、作者、タイトル、タグ、モデルを検索';

  @override
  String get onlineGallery_aiTagPromptQuery =>
      'AI Prompt 検索（artist: などの Prompt 原文を検索）';

  @override
  String get onlineGallery_sourceQuickTagCloud => '法典図鑑';

  @override
  String get onlineGallery_codexSearchHint => 'タイトル、プロンプト、メモ、カテゴリ、投稿者を検索';

  @override
  String get onlineGallery_codexLabel => '法典';

  @override
  String get onlineGallery_codexSelect => '法典を選択';

  @override
  String get onlineGallery_codexAll => 'すべての法典';

  @override
  String get onlineGallery_codexBrowse => '閲覧';

  @override
  String get onlineGallery_codexLatest => '今回の更新';

  @override
  String get onlineGallery_codexRecent => '最近見た項目';

  @override
  String get onlineGallery_codexCategory => 'カテゴリ';

  @override
  String get onlineGallery_codexAllCategories => 'すべてのカテゴリ';

  @override
  String get onlineGallery_codexUpdateBatch => '更新バッチ';

  @override
  String get onlineGallery_codexMediaFilter => '画像';

  @override
  String get onlineGallery_codexAllEntries => 'すべての項目';

  @override
  String get onlineGallery_codexWithImages => '画像ありのみ';

  @override
  String get onlineGallery_codexWithoutImages => '画像なしのみ';

  @override
  String get onlineGallery_codexOffline => 'オフラインキャッシュ';

  @override
  String get onlineGallery_codexContributors => '協力者と出典';

  @override
  String onlineGallery_codexEntryCount(Object entries, Object images) {
    return '$entries 項目 · 画像あり $images 件';
  }

  @override
  String get onlineGallery_codexNoImage => '画像なし項目';

  @override
  String get onlineGallery_codexNoImageDescription =>
      'テキストのみの項目です。プロンプトとメタデータはすべて利用できます。';

  @override
  String get onlineGallery_codexAuthor => '作者';

  @override
  String get onlineGallery_codexImageFile => '画像ファイル';

  @override
  String get onlineGallery_codexOriginalFile => '原画像ファイル';

  @override
  String get onlineGallery_codexDeclaredSource => 'データ提供元';

  @override
  String get onlineGallery_codexPrompt => 'ポジティブプロンプト';

  @override
  String get onlineGallery_codexNegativePrompt => 'ネガティブプロンプト';

  @override
  String get onlineGallery_negativePromptCopyHeading => 'ネガティブプロンプト';

  @override
  String get onlineGallery_codexCharacterPrompts => 'キャラクタープロンプト';

  @override
  String get onlineGallery_codexNote => 'メモ';

  @override
  String get onlineGallery_codexCopyPositive => 'ポジティブをコピー';

  @override
  String get onlineGallery_codexCopyNegative => 'ネガティブをコピー';

  @override
  String get onlineGallery_codexCopyCharacter => 'このキャラクターをコピー';

  @override
  String get onlineGallery_codexCopyAll => 'すべてコピー';

  @override
  String get onlineGallery_codexSendToGeneration => '生成画面へ送る';

  @override
  String get onlineGallery_codexAddToQueue => '生成キューに追加';

  @override
  String get onlineGallery_codexDownloadOriginal => '現在の原画像を保存';

  @override
  String get onlineGallery_codexOpenSource => '出典を開く';

  @override
  String get onlineGallery_codexOpenOrigin => '元のページを開く';

  @override
  String get onlineGallery_codexOpenSourceFailed => '指定された出典を開けません。';

  @override
  String get onlineGallery_codexBookLocked =>
      'この法典には成人向けコンテンツが含まれます。レーティングで「疑問あり」または「露骨」を選択してください。';

  @override
  String get onlineGallery_codexNoData => '条件に一致する法典項目がありません';

  @override
  String get onlineGallery_codexExternalFallback =>
      '外部ソースを利用できないため、法典サイトのキャッシュ版を表示しています。';

  @override
  String get onlineGallery_codexPreviousRelease =>
      '現在のバージョンを利用できないため、検証済みの前バージョンを表示しています。';

  @override
  String get onlineGallery_codexCachedBadge => '旧版キャッシュ';

  @override
  String get onlineGallery_codexUntitled => '無題の項目';

  @override
  String get onlineGallery_artistHunt => '絵師タグのみ';

  @override
  String get onlineGallery_artistHuntTooltip =>
      'ポジティブ Prompt に明示的な artist: タグがある画像のみ表示';

  @override
  String get onlineGallery_copyArtistChain => '絵師タグ列をコピー';

  @override
  String get onlineGallery_copyFullPrompt => '完全な Prompt をコピー';

  @override
  String get onlineGallery_copyRawArtistFragments => '元の絵師タグ断片をコピー';

  @override
  String get onlineGallery_noArtistChain => 'コピー可能な絵師タグなし';

  @override
  String onlineGallery_artistCount(Object count) {
    return '絵師 $count 人';
  }

  @override
  String get onlineGallery_artistHuntNoExactResults => '候補作品に正確な絵師タグ列がありません';

  @override
  String onlineGallery_artistHuntPartialFailure(Object count) {
    return '$count 件の作品を解析できませんでした。再試行できます。';
  }

  @override
  String get onlineGallery_artistHuntDetailFailed =>
      '候補作品の詳細をすべて解析できませんでした。再試行してください。';

  @override
  String get onlineGallery_aiTagTimeRange => '期間';

  @override
  String get onlineGallery_aiTagAllTime => 'すべて';

  @override
  String get onlineGallery_aiTagCurrentMonthly => 'リアルタイム月間ランキング';

  @override
  String get onlineGallery_aiTagOlderMonthly => '過去のアーカイブ';

  @override
  String get onlineGallery_aiTagRankingProcessing =>
      'ランキングを生成中です。しばらくしてから再試行してください。';

  @override
  String get onlineGallery_sourceConfigUnavailable =>
      'ソース設定を取得できません。接続を確認して再試行してください。';

  @override
  String get onlineGallery_sourceRateLimited =>
      'リクエストが多すぎます。しばらくしてから再試行してください。';

  @override
  String get onlineGallery_sourceTimeout => 'リクエストがタイムアウトしました。接続を確認してください。';

  @override
  String get onlineGallery_sourceNetworkError =>
      'ギャラリーソースに接続できません。ネットワークまたはプロキシを確認してください。';

  @override
  String get onlineGallery_sourceRequestFailed =>
      'リクエストに失敗しました。しばらくしてから再試行してください。';

  @override
  String onlineGallery_actionFailed(Object error) {
    return '操作に失敗しました: $error';
  }

  @override
  String get onlineGallery_sourceMalformedResponse =>
      'ソースのレスポンス形式が変更され、解析できません。';

  @override
  String get onlineGallery_detailNotFound => '作品が存在しないか、削除されています。';

  @override
  String get onlineGallery_imageUnavailable => '画像は現在利用できません。';

  @override
  String get onlineGallery_loadedAll => 'すべて読み込み済み';

  @override
  String get onlineGallery_retryAppend => '読み込みに失敗しました。クリックして再試行';

  @override
  String onlineGallery_multipleImages(Object count) {
    return '$count 枚の画像';
  }

  @override
  String get onlineGallery_views => '閲覧数';

  @override
  String get onlineGallery_downloadAllMedia => '作品の全画像をダウンロード';

  @override
  String get onlineGallery_copyFullMetadata => '完全なメタデータをコピー';

  @override
  String get onlineGallery_gelbooruReadOnly => '読み取り専用のお気に入り';

  @override
  String get onlineGallery_gelbooruFavoritesSortHint =>
      '投稿 ID の新しい順です。ウェブサイトのお気に入り登録時刻順とは異なる場合があります。';

  @override
  String get tooltip_fullscreenEdit => 'フルスクリーン編集';

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
  String get tooltip_enable => '有効にする';

  @override
  String get tooltip_disable => '無効にする';

  @override
  String get tooltip_resetWeight => 'クリックして 100% にリセットします';

  @override
  String get upscale_scale => 'スケール係数';

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
  String get gelbooru_configureTitle => 'Gelbooru API を設定';

  @override
  String get gelbooru_configureHint =>
      'Gelbooru のアカウント設定に表示される User ID と API Key を入力してください。パスワードやブラウザー Cookie は収集しません。';

  @override
  String get gelbooru_userId => 'ユーザー ID';

  @override
  String get gelbooru_userIdHint => '正の整数の User ID を入力';

  @override
  String get gelbooru_userIdRequired => '有効な正の整数の User ID を入力してください';

  @override
  String get gelbooru_apiKeyHint => 'API Key を入力';

  @override
  String get gelbooru_apiKeyRequired => 'API Key を入力してください';

  @override
  String get gelbooru_openAccountSettings => 'Gelbooru のアカウント設定を開く';

  @override
  String get gelbooru_save => '検証して保存';

  @override
  String get gelbooru_saved => 'Gelbooru 認証情報を保存しました';

  @override
  String get gelbooru_removeCredentials => '認証情報を削除';

  @override
  String get gelbooru_invalidInput => '有効な User ID と API Key を入力してください。';

  @override
  String get gelbooru_invalidCredentials =>
      'Gelbooru に認証情報を拒否されました。User ID と API Key を確認してください。';

  @override
  String get gelbooru_rateLimited => 'リクエスト回数が多すぎます。しばらくしてから再試行してください。';

  @override
  String get gelbooru_timeout => '検証がタイムアウトしました。ネットワーク接続を確認してください。';

  @override
  String get gelbooru_serverError => 'Gelbooru サーバーは一時的に利用できません。';

  @override
  String get gelbooru_networkError =>
      'Gelbooru に接続できません。ネットワークまたはプロキシ設定を確認してください。';

  @override
  String get gelbooru_malformedResponse => 'Gelbooru から解析できないデータが返されました。';

  @override
  String get gelbooru_storageError => 'Gelbooru 認証情報を安全に保存または読み取れませんでした。';

  @override
  String get gelbooru_unknownError => 'Gelbooru の検証に失敗しました。しばらくしてから再試行してください。';

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
  String get qualityTags_naiDefaultStandard => 'NAI のデフォルト（標準）';

  @override
  String get qualityTags_naiDefaultLight => 'NAI のデフォルト（ライト）';

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
  String warmup_dataMigrationFailed(Object details) {
    return 'データ移行に失敗しました: $details';
  }

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
  String get generation_invalidResolution => '無効な解像度';

  @override
  String generation_invalidResolutionHint(
    int width,
    int height,
    int suggestedWidth,
    int suggestedHeight,
  ) {
    return '$width×$height は生成に使用できません。幅と高さは 64 の倍数で、各辺は 4096 以下、総ピクセル数は 3,145,728 以下である必要があります。最も近い有効なサイズは $suggestedWidth×$suggestedHeight です。';
  }

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
  String get drop_processing => '画像を処理しています...';

  @override
  String get characterEditor_close => '閉じる';

  @override
  String get characterEditor_clearAll => 'すべてクリア';

  @override
  String get characterEditor_clearAllTitle => 'すべてのキャラクターをクリア';

  @override
  String get characterEditor_clearAllConfirm =>
      'すべてのキャラクターを削除しますか？この操作は元に戻せません。';

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
  String get characterCanvas_title => 'キャラクター位置';

  @override
  String get characterCanvas_aiChoice => 'AIにおまかせ';

  @override
  String get characterCanvas_custom => 'カスタム';

  @override
  String get characterCanvas_aiHint => 'AIがすべてのキャラクターの位置を自動で決めます';

  @override
  String get characterCanvas_dragHint => 'アンカーをドラッグして位置を設定し、離すと反映されます';

  @override
  String get characterCanvas_guide => '構図ガイド';

  @override
  String get characterCanvas_guideNone => 'なし';

  @override
  String get characterCanvas_guideThirds => '三分割';

  @override
  String get characterCanvas_guidePhi => '黄金比';

  @override
  String get characterCanvas_guideGrid => 'グリッド';

  @override
  String get characterCanvas_guideColumns => '列';

  @override
  String get characterCanvas_guideRows => '行';

  @override
  String get characterEditor_genderFemale => '女性';

  @override
  String get characterEditor_genderMale => '男性';

  @override
  String get characterEditor_genderOther => 'その他';

  @override
  String get characterEditor_addFemale => 'F';

  @override
  String get characterEditor_addMale => 'M';

  @override
  String get characterEditor_addOther => 'その他';

  @override
  String get characterEditor_addFromLibrary => 'ライブラリ';

  @override
  String get characterEditor_moveUp => '上に移動';

  @override
  String get characterEditor_moveDown => '下に移動';

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
  String get characterTooltip_disabledLabel => '無効';

  @override
  String get characterTooltip_notSet => '未設定';

  @override
  String get characterTooltip_previewTitle => 'キャラクタープレビュー';

  @override
  String characterTooltip_enabledSummary(int enabled, int total) {
    return '$enabled / $total 有効';
  }

  @override
  String characterTooltip_more(int count) {
    return '他 $count 人のキャラクター';
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
  String get randomMode_naiOfficialDesc =>
      '現在のモデルに対応する NovelAI 公式ランダムワードリストを使用';

  @override
  String get randomMode_customDesc => '完全なオフラインタグカタログとカスタムプリセットから生成';

  @override
  String get randomMode_hybridDesc => '公式ワードリストとカタログ拡張を組み合わせる';

  @override
  String get randomMode_naiIndicator => '公式';

  @override
  String get randomMode_customIndicator => 'カスタム';

  @override
  String get naiMode_noTags => 'タグがありません';

  @override
  String get naiAlgorithm_mainPrompt => 'メイン プロンプト';

  @override
  String tagGroup_tagCount(Object count) {
    return '$count タグ';
  }

  @override
  String get addGroup_tagGroupTab => 'タググループ';

  @override
  String get addGroup_displayNameLabel => '表示名 (オプション)';

  @override
  String get addGroup_targetCategoryLabel => '対象カテゴリ';

  @override
  String get addGroup_poolTab => 'Danbooru プール';

  @override
  String globalSettings_saveFailed(Object error) {
    return '保存に失敗しました: $error';
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
  String get nav_gallery => 'ギャラリー';

  @override
  String get nav_settings => '設定';

  @override
  String download_completed(Object name) {
    return '$name ダウンロードが完了しました';
  }

  @override
  String download_failed(Object name) {
    return '$name ダウンロードに失敗しました';
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
  String get preset_resetToDefault => 'デフォルトにリセット';

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
  String get category_dialogTitle => 'カテゴリの作成';

  @override
  String get category_nameHint => 'カテゴリ名を入力してください';

  @override
  String get category_nameRequired => '名前は必須です';

  @override
  String get category_selectEmoji => '絵文字を選択してください';

  @override
  String get category_noRecentEmoji => '最近の絵文字はありません';

  @override
  String get category_searchEmoji => '絵文字を検索';

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
  String get characterCountConfig_customSlots => 'カスタム スロット';

  @override
  String get characterCountConfig_customSlotsTitle => 'キャラクタースロット管理';

  @override
  String get characterCountConfig_customSlotsDesc =>
      '利用可能なキャラクター スロット オプションを追加または削除します';

  @override
  String get characterCountConfig_addSlotHint => '例: トラップ 1 つ、フタナリ 1 つ';

  @override
  String get characterCountConfig_slotExists => 'このスロットはすでに存在します';

  @override
  String get randomManager_algorithmConfig => 'アルゴリズム構成';

  @override
  String get randomManager_characterCountWeight => 'キャラクター数の重み';

  @override
  String get randomManager_genderWeight => '性別の重み';

  @override
  String get randomManager_enableSeasonalWordlists => '季節の単語リストを有効にする';

  @override
  String get randomManager_enableSeasonalWordlistsDesc =>
      'クリスマス、ハロウィーン、その他の特別な日の単語リスト';

  @override
  String get randomManager_globalEmphasisProbability => 'グローバル強調確率';

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
  String get gender_female => '女性';

  @override
  String get gender_male => '男性';

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
  String get tag_countBadgeBreakdown => 'タグの内訳';

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
  String get localGallery_editMetadata => 'タグを編集';

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
  String get localGallery_zipMetadataTitle => 'ZIP をエクスポート';

  @override
  String get localGallery_zipMetadataDescription =>
      'ZIP 内の画像に埋め込みメタデータを残すか選択します。元の画像ファイルは変更されません。';

  @override
  String get localGallery_zipIncludeMetadata => 'メタデータを保持';

  @override
  String get localGallery_zipIncludeMetadataDescription =>
      '元の画像ファイルを変更せずにパックします。';

  @override
  String get localGallery_zipExcludeMetadata => 'すべてのメタデータを削除';

  @override
  String get localGallery_zipExcludeMetadataDescription =>
      'ZIP 専用のサニタイズ済みコピーを作成し、PNG テキストチャンク、EXIF、NovelAI ステルス透かしデータを削除します。';

  @override
  String bulkMetadataEdit_title(Object count) {
    return '$count 枚の画像のタグを一括編集';
  }

  @override
  String get bulkMetadataEdit_tagsToAdd => '追加するタグ';

  @override
  String get bulkMetadataEdit_tagsToAddHint => '追加するタグを入力...';

  @override
  String get bulkMetadataEdit_tagsToRemove => '削除するタグ';

  @override
  String get bulkMetadataEdit_tagsToRemoveHint => '削除するタグを入力...';

  @override
  String get bulkMetadataEdit_noChanges => '追加または削除するタグを1つ以上指定してください';

  @override
  String localGallery_packingImages(Object count) {
    return '$count 個の画像をパッキングしています...';
  }

  @override
  String localGallery_packedImages(Object count) {
    return '$count 個の画像をパックしました';
  }

  @override
  String localGallery_packingProgress(Object current, Object total) {
    return '$total 枚中 $current 枚目をパックしています...';
  }

  @override
  String get localGallery_packPartialTitle => '一部の画像をエクスポートできませんでした';

  @override
  String localGallery_packedImagesWithFailures(Object exported, Object failed) {
    return 'ZIP を作成しました：$exported 枚を追加、$failed 枚は追加できませんでした';
  }

  @override
  String get localGallery_packFailed => '画像のパックに失敗しました';

  @override
  String localGallery_packFailedWithDetails(Object error) {
    return 'ZIP の作成に失敗しました：$error';
  }

  @override
  String get localGallery_packAlreadyInProgress => '画像の ZIP エクスポートはすでに進行中です';

  @override
  String get localGallery_imageFileMissing => '画像ファイルが存在しません';

  @override
  String get localGallery_sentToImageToImage => '画像を Image2Image に送信しました';

  @override
  String localGallery_sendFailed(Object error) {
    return '送信失敗: $error';
  }

  @override
  String get localGallery_sentToReversePrompt => '画像がリバース プロンプトに送信されました';

  @override
  String localGallery_sendToKritaFailed(Object error) {
    return 'Krita への送信に失敗しました: $error';
  }

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
  String get localGallery_clearFilters => 'フィルターをクリア';

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
  String get statistics_totalImages => '合計画像数';

  @override
  String get statistics_totalSize => '合計サイズ';

  @override
  String get statistics_favorites => 'お気に入り';

  @override
  String get statistics_samplerDistribution => 'サンプラー分布';

  @override
  String get statistics_additionalStats => '追加の統計';

  @override
  String get statistics_averageFileSize => '平均ファイルサイズ';

  @override
  String get statistics_withMetadata => 'メタデータ付きの画像';

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
  String get statistics_noAnlasInPeriod => '選択した期間に Anlas 消費はありません';

  @override
  String get statistics_periodSelectorTooltip => '集計期間を選択';

  @override
  String get statistics_periodWeek => '直近 1 週間';

  @override
  String get statistics_periodMonth => '直近 1 か月';

  @override
  String get statistics_periodThreeMonths => '直近 3 か月';

  @override
  String get statistics_periodYear => '直近 1 年';

  @override
  String get statistics_periodAll => '全期間';

  @override
  String get statistics_periodCustom => '日数を指定';

  @override
  String statistics_periodDays(int count) {
    return '直近 $count 日';
  }

  @override
  String statistics_periodSummary(String start, String end, int count) {
    return '$start～$end・$count 日間';
  }

  @override
  String statistics_partialCoverage(String date, int count) {
    return '利用可能な記録は $date からです。1 日の平均は既存の $count 日間で計算されます';
  }

  @override
  String get statistics_customPeriodTitle => '集計日数を指定';

  @override
  String get statistics_customDaysHint => '日数';

  @override
  String statistics_customDaysError(int max) {
    return '1 から $max までの整数を入力してください';
  }

  @override
  String get statistics_daysUnit => '日';

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
  String get localGallery_modelHint => 'モデル名を入力してください...';

  @override
  String get localGallery_samplerHint => 'サンプラー名を入力してください...';

  @override
  String get localGallery_resolutionHint => '幅 x 高さ (例: 1024x1024)';

  @override
  String get localGallery_activeFiltersSet => 'フィルターセット';

  @override
  String get localGallery_applyFilters => 'フィルターを適用する';

  @override
  String get localGallery_resetAdvancedFilters => '詳細フィルターをリセット';

  @override
  String get bulkExport_format => '形式';

  @override
  String get bulkExport_jsonFormat => 'JSON';

  @override
  String get bulkExport_csvFormat => 'CSV';

  @override
  String get localGallery_group_today => '今日';

  @override
  String get localGallery_group_yesterday => '昨日';

  @override
  String get localGallery_group_thisWeek => '今週';

  @override
  String get localGallery_group_earlier => '以前';

  @override
  String localGallery_cannotOpenFolder(Object error) {
    return 'フォルダーを開けません: $error';
  }

  @override
  String get localGallery_permissionRequiredTitle => 'ストレージ権限が必要です';

  @override
  String get localGallery_permissionRequiredContent =>
      'ローカル ギャラリーには、生成された画像をスキャンするためのストレージ権限が必要です。\n\n設定で許可を与えて、もう一度お試しください。';

  @override
  String get localGallery_openSettings => '設定を開く';

  @override
  String get localGallery_firstTimeTipTitle => 'ヒント';

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
  String get bulkProgress_continueInBackground => 'バックグラウンドで続行';

  @override
  String get bulkProgress_operationAlreadyInProgress => '別の一括操作がすでに進行中です';

  @override
  String bulkProgress_errorDeleteFailed(String error) {
    return '画像の削除に失敗しました: $error';
  }

  @override
  String get bulkProgress_errorNoImagesToExport => 'エクスポートする画像がありません';

  @override
  String get bulkProgress_errorExportFailed => 'エクスポートに失敗しました';

  @override
  String bulkProgress_errorExportFailedWithDetails(String error) {
    return 'エクスポートに失敗しました: $error';
  }

  @override
  String get bulkProgress_errorNoMetadataChanges => '追加または削除するタグを入力してください';

  @override
  String bulkProgress_errorMetadataEditFailed(String error) {
    return '画像メタデータの編集に失敗しました: $error';
  }

  @override
  String bulkProgress_errorFavoriteFailed(String error) {
    return 'お気に入りの更新に失敗しました: $error';
  }

  @override
  String get bulkProgress_errorNoImagesForCollection => 'コレクションに追加する画像がありません';

  @override
  String bulkProgress_errorAddToCollectionFailed(String error) {
    return 'コレクションへの画像追加に失敗しました: $error';
  }

  @override
  String get bulkProgress_errorNothingToUndo => '元に戻す操作がありません';

  @override
  String bulkProgress_errorUndoFailed(String error) {
    return '元に戻せませんでした: $error';
  }

  @override
  String get bulkProgress_errorNothingToRedo => 'やり直す操作がありません';

  @override
  String bulkProgress_errorRedoFailed(String error) {
    return 'やり直せませんでした: $error';
  }

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
  String get statistics_chartTopTags => 'トップのタグ';

  @override
  String get statistics_chartAspectRatio => 'アスペクト比の分布';

  @override
  String get statistics_chartActivityHeatmap => 'アクティビティ ヒートマップ';

  @override
  String get statistics_chartHourlyDistribution => '時間別分布';

  @override
  String get statistics_chartWeekdayDistribution => '曜日別分布';

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
  String get statistics_mostActiveDay => '最もアクティブな日';

  @override
  String get statistics_leastActiveDay => '最も活動的でない日';

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
  String get autocomplete_categoryContributor => '投稿者';

  @override
  String get autocomplete_categorySpecies => '種族';

  @override
  String get autocomplete_categoryLore => '設定';

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
  String get tagLibrary_addedToFixed => '固定タグに追加';

  @override
  String get tagLibrary_entryMoved => 'エントリがターゲット カテゴリに移動されました';

  @override
  String get tagLibrary_addFavorite => 'お気に入りに追加';

  @override
  String get tagLibrary_thumbnail => 'サムネイル';

  @override
  String get tagLibrary_selectImage => '画像を選択してください';

  @override
  String get tagLibrary_thumbnailHint => 'PNG、JPG、WEBP、GIF、BMP、TIFF などをサポート';

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
  String get queue_management => 'キュー管理';

  @override
  String get queue_empty => 'キューが空です';

  @override
  String get queue_emptyHint => 'キューにタスクがありません';

  @override
  String get queue_pending => '保留中';

  @override
  String get queue_running => '実行中';

  @override
  String get queue_completed => '完了しました';

  @override
  String get queue_failed => '失敗しました';

  @override
  String get queue_paused => '一時停止しました';

  @override
  String get queue_idle => 'アイドル状態';

  @override
  String get queue_ready => '準備完了';

  @override
  String get queue_noTasksToStart => 'キューが空のため開始できません';

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
  String get queue_startExecution => 'キューを開始';

  @override
  String get queue_pauseExecution => 'キューを一時停止';

  @override
  String get queue_resumeExecution => 'キューを再開';

  @override
  String get queue_generationBusy => '別の生成タスクが実行中です。完了後にキューを開始してください';

  @override
  String get queue_clearQueue => 'キューをクリアします';

  @override
  String get queue_clearQueueConfirm =>
      'すべてのキュー タスクをクリアしてもよろしいですか?この操作は元に戻すことができません。';

  @override
  String get queue_confirmClear => 'クリアの確認';

  @override
  String queue_retryCount(Object current, Object max) {
    return '再試行 $current/$max';
  }

  @override
  String get queue_retry => '再試行';

  @override
  String get queue_requeue => '再キューイング';

  @override
  String get queue_clearFailedTasks => 'すべてクリア';

  @override
  String get queue_noFailedTasks => '失敗したタスクはありません';

  @override
  String get queue_noCompletedTasks => '完了したレコードはありません';

  @override
  String get queue_editTask => 'タスクの編集';

  @override
  String get queue_taskDetails => 'タスク詳細';

  @override
  String get queue_clearCompletedTasks => '完了履歴をクリア';

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
  String get queue_addCurrentTask => '現在のタスクを追加';

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
  String get settings_queueRetryCount => '再試行回数';

  @override
  String get settings_queueRetryInterval => '再試行間隔';

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
  String queue_currentQueueInfo(Object count) {
    return '現在のキューには $count タスクが含まれています';
  }

  @override
  String get settings_notificationSound => '完了音';

  @override
  String get settings_notificationSoundSubtitle => '生成完了時にサウンドを再生する';

  @override
  String get settings_notificationCustomSound => 'カスタムサウンド';

  @override
  String get settings_notificationSelectSound => 'サウンドの選択';

  @override
  String get settings_notificationResetSound => 'デフォルトにリセット';

  @override
  String get resetToDefault => 'デフォルトにリセット';

  @override
  String get toggleGroupEnabled => 'グループ有効状態の切り替え';

  @override
  String get diyNotAvailableForDefault => 'DIY はデフォルトのプリセットでは使用できません';

  @override
  String get diyNotAvailableHint => '編集するにはカスタム プリセットにコピーしてください';

  @override
  String get statistics_heatmapLess => '少ない';

  @override
  String get statistics_heatmapMore => '多い';

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
  String get metadataImport_selectAll => 'すべて選択';

  @override
  String get metadataImport_promptsOnly => 'プロンプトのみ';

  @override
  String get metadataImport_generationOnly => 'パラメータのみ';

  @override
  String get metadataImport_clear => 'クリア';

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
  String get shortcut_action_generation_prev_image => '前のプレビュー（履歴連動）';

  @override
  String get shortcut_action_generation_next_image => '次のプレビュー（履歴連動）';

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
  String get shortcut_settings_press_key => 'キーの組み合わせを押してください...';

  @override
  String get shortcut_help_title => 'キーボード ショートカットのヘルプ';

  @override
  String get shortcut_help_search => 'ショートカットを検索...';

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
  String get drop_dialogTitle => 'この画像はどのように使用しますか?';

  @override
  String get drop_actions => '操作';

  @override
  String get drop_hint => 'ここに画像をドロップしてください';

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
  String get drop_metadataDetected => 'NovelAI メタデータを検出しました';

  @override
  String get drop_metadataParseFailed => 'メタデータを解析できませんでした';

  @override
  String get drop_metadataParseFailedHint =>
      '画像にメタデータ項目がありますが、現在は読み取れません。他の画像操作は引き続き使用できます。';

  @override
  String get drop_metadataErrorDetails => 'エラー詳細を表示';

  @override
  String get drop_positivePrompt => 'プロンプト';

  @override
  String get drop_negativePrompt => '除外したい要素';

  @override
  String drop_characterPrompts(int count) {
    return 'キャラクタープロンプト（$count）';
  }

  @override
  String drop_characterPositivePrompt(int index) {
    return 'キャラクター $index プロンプト';
  }

  @override
  String drop_characterNegativePrompt(int index) {
    return 'キャラクター $index の除外したい要素';
  }

  @override
  String get drop_promptNotRecorded => '記録なし';

  @override
  String get drop_promptCopy => 'コピー';

  @override
  String get drop_promptAddWhole => '全文をライブラリに追加';

  @override
  String get drop_promptAddSelection => 'ライブラリに追加';

  @override
  String get drop_promptLibraryTitle => 'ライブラリに追加';

  @override
  String get drop_promptLibraryWriteMode => '書き込み方法';

  @override
  String get drop_promptLibraryCreate => '新規';

  @override
  String get drop_promptLibraryAppend => '追記';

  @override
  String get drop_promptLibraryOverwrite => '置換';

  @override
  String get drop_promptLibraryAliasHint => 'この名前は <ライブラリ名> の参照にも使用されます';

  @override
  String get drop_promptLibraryTarget => '対象エントリ';

  @override
  String get drop_promptLibrarySelectTarget => '更新するエントリを選択';

  @override
  String get drop_promptLibrarySeparator => '区切り';

  @override
  String get drop_promptLibrarySeparatorComma => 'カンマ + スペース';

  @override
  String get drop_promptLibrarySeparatorNewline => '改行';

  @override
  String get drop_promptLibrarySeparatorNone => '区切りなし';

  @override
  String drop_promptLibraryCharacterCount(int count) {
    return '$count 文字';
  }

  @override
  String get drop_promptLibraryExactContentHint => 'テキストを整形、並べ替え、補完せずに保存します';

  @override
  String get drop_promptLibraryResultPreview => '結果プレビュー';

  @override
  String drop_promptLibraryDuplicate(Object name) {
    return '同じ内容が「$name」に既にあります';
  }

  @override
  String get drop_promptLibraryNameConflict =>
      '同じ名前があります。名前の変更、追記、または置換を選択してください';

  @override
  String drop_promptLibraryOverwriteWarning(Object name) {
    return '「$name」のプロンプト内容をすべて置き換えます';
  }

  @override
  String get drop_promptLibraryMore => 'その他のオプション';

  @override
  String get drop_promptLibraryConfirmOverwrite => '置換を確認';

  @override
  String get drop_promptLibrarySaved => 'ライブラリに保存しました';

  @override
  String get drop_promptLibrarySaveFailed => 'ライブラリへの保存に失敗しました';

  @override
  String get drop_promptLibraryPositiveName => 'プロンプト抜粋';

  @override
  String get drop_promptLibraryNegativeName => '除外したい要素の抜粋';

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
  String get preciseRef_v4Only => 'この機能は V4.5 モデルのみ対応しています';

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
  String get vibeLibrary_markEncodingModel => 'エンコードモデルを設定';

  @override
  String vibeLibrary_markEncodingModelContent(Object count, Object model) {
    return '選択した $count 件の Vibe を「$model」のエンコードとして設定し、ライブラリファイルを書き換えます。\n\n別モデルとして誤って記録され、生成のたびに再エンコードされて Anlas を消費する項目の修復用です。エンコードが実際に別モデルのものだった場合、結果が想定と異なる可能性があります。';
  }

  @override
  String vibeLibrary_encodingModelMarked(Object count) {
    return '$count 件の Vibe のエンコードモデルを更新しました';
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
  String categoryError_loadFailed(String error) {
    return 'カテゴリの読み込みに失敗しました: $error';
  }

  @override
  String categoryError_syncFailed(String error) {
    return 'カテゴリの同期に失敗しました: $error';
  }

  @override
  String get categoryError_nameEmpty => 'カテゴリ名を入力してください';

  @override
  String get categoryError_parentNotFound => '親カテゴリが存在しません';

  @override
  String categoryError_createFailed(String error) {
    return 'カテゴリの作成に失敗しました: $error';
  }

  @override
  String get categoryError_notFound => 'カテゴリが存在しません';

  @override
  String categoryError_renameFailed(String error) {
    return 'カテゴリ名の変更に失敗しました: $error';
  }

  @override
  String get categoryError_invalidMove => '子孫カテゴリの下には移動できません';

  @override
  String categoryError_moveFailed(String error) {
    return 'カテゴリの移動に失敗しました: $error';
  }

  @override
  String get categoryError_hasSubcategories =>
      'このカテゴリにはサブカテゴリがあります。先に削除してください。';

  @override
  String categoryError_deleteFailed(String error) {
    return 'カテゴリの削除に失敗しました: $error';
  }

  @override
  String categoryError_moveImageFailed(String error) {
    return '画像の移動に失敗しました: $error';
  }

  @override
  String categoryError_moveImagesFailed(String error) {
    return '画像の一括移動に失敗しました: $error';
  }

  @override
  String categoryError_reorderFailed(String error) {
    return 'カテゴリの並べ替えに失敗しました: $error';
  }

  @override
  String get vibeBulk_titleDelete => 'Vibe を削除';

  @override
  String get vibeBulk_titleMove => 'Vibe を移動';

  @override
  String get vibeBulk_titleToggleFavorite => 'お気に入りを更新';

  @override
  String get vibeBulk_titleAddTags => 'タグを追加';

  @override
  String get vibeBulk_titleRemoveTags => 'タグを削除';

  @override
  String get vibeBulk_titleExport => 'Vibe をエクスポート';

  @override
  String get vibeBulk_titleImport => 'Vibe をインポート';

  @override
  String vibeBulk_processingProgress(int current, int total) {
    return '処理中: $current / $total';
  }

  @override
  String get vibeBulk_completed => '操作が完了しました';

  @override
  String get vibeBulk_completedWithFailures => '一部失敗して操作が完了しました';

  @override
  String get vibeBulk_successful => '成功';

  @override
  String get vibeBulk_failed => '失敗';

  @override
  String get vibeBulk_errorDetails => 'エラー詳細:';

  @override
  String vibeBulk_moreErrors(int count) {
    return '...他 $count 件のエラー';
  }

  @override
  String get vibeBulk_operationFailed => '操作に失敗しました';

  @override
  String get vibeBulk_operationFailedHint => '操作設定を確認して、もう一度お試しください。';

  @override
  String vibeBulk_errorEntryNotFoundOrDeleteFailed(String item) {
    return '$item が見つからないか、削除できませんでした';
  }

  @override
  String vibeBulk_errorDeleteFailed(String item, String error) {
    return '$item の削除に失敗しました: $error';
  }

  @override
  String vibeBulk_errorEntryNotFound(String item) {
    return 'エントリが見つかりません: $item';
  }

  @override
  String vibeBulk_errorMoveFailed(String item, String error) {
    return '$item の移動に失敗しました: $error';
  }

  @override
  String vibeBulk_errorFavoriteFailed(String item) {
    return 'お気に入り状態の更新に失敗しました: $item';
  }

  @override
  String vibeBulk_errorFavoriteFailedWithDetails(String item, String error) {
    return '$item のお気に入り状態の更新に失敗しました: $error';
  }

  @override
  String vibeBulk_errorAddTagsFailed(String item) {
    return 'タグの追加に失敗しました: $item';
  }

  @override
  String vibeBulk_errorAddTagsFailedWithDetails(String item, String error) {
    return '$item へのタグ追加に失敗しました: $error';
  }

  @override
  String vibeBulk_errorRemoveTagsFailed(String item) {
    return 'タグの削除に失敗しました: $item';
  }

  @override
  String vibeBulk_errorRemoveTagsFailedWithDetails(String item, String error) {
    return '$item からのタグ削除に失敗しました: $error';
  }

  @override
  String get vibeBulk_errorExportNoFile => 'ファイルが作成されなかったため、エクスポートに失敗しました';

  @override
  String vibeBulk_errorExportFailed(String error) {
    return 'エクスポートに失敗しました: $error';
  }

  @override
  String vibeBulk_errorFileNotFound(String item) {
    return 'ファイルが見つかりません: $item';
  }

  @override
  String vibeBulk_errorNoVibeData(String item) {
    return '$item に有効な Vibe データが見つかりません';
  }

  @override
  String vibeBulk_errorImportFailed(String item, String error) {
    return '$item からの Vibe インポートに失敗しました: $error';
  }

  @override
  String vibeBulk_errorProcessFileFailed(String item, String error) {
    return '$item の処理に失敗しました: $error';
  }

  @override
  String get vibeBulkTag_title => 'タグを一括編集';

  @override
  String vibeBulkTag_selectedCount(int count) {
    return '$count 件の Vibe を選択中';
  }

  @override
  String get vibeBulkTag_inputHint => '新しいタグを入力...';

  @override
  String get vibeBulkTag_noTags => 'タグがありません';

  @override
  String get vibeBulkTag_noTagsHint => 'タグを追加すると、絞り込みや管理が簡単になります';

  @override
  String vibeBulkTag_currentTags(int count) {
    return '現在のタグ ($count)';
  }

  @override
  String vibeBulkTag_pendingRemoval(int count) {
    return '削除予定のタグ ($count)';
  }

  @override
  String get vibeBulkTag_removeTag => 'タグを削除';

  @override
  String get vibeBulkTag_actionPreview => '変更内容';

  @override
  String vibeBulkTag_addTagsSummary(String tags) {
    return '追加するタグ: $tags';
  }

  @override
  String vibeBulkTag_removeTagsSummary(String tags) {
    return '削除するタグ: $tags';
  }

  @override
  String get vibeBulkTag_noChanges => '適用する変更はありません';

  @override
  String get vibeBulkCategory_title => '移動先カテゴリを選択';

  @override
  String vibeBulkCategory_moveCount(int count) {
    return '$count 件の Vibe の移動先:';
  }

  @override
  String get vibeBulkCategory_cannotMoveToCurrent => '現在のカテゴリには移動できません';

  @override
  String get vibeDetail_strengthDescription => 'この Vibe が生成結果に与える影響の強さを調整します';

  @override
  String get vibeDetail_infoExtractedDescription =>
      '元画像から抽出する情報量を調整します（2 Anlas を消費）';

  @override
  String get vibeDetail_statistics => '統計情報';

  @override
  String get vibeDetail_usageCount => '使用回数';

  @override
  String vibeDetail_timesUsed(int count) {
    return '$count 回';
  }

  @override
  String get vibeDetail_lastUsed => '最終使用';

  @override
  String get vibeDetail_neverUsed => '未使用';

  @override
  String get vibeDetail_createdAt => '作成日時';

  @override
  String get vibeDetail_saveParameters => 'パラメーターを保存';

  @override
  String get vibe_export_title => 'Vibe をエクスポート';

  @override
  String get vibe_export_format => 'エクスポート形式';

  @override
  String get vibe_selector_title => 'Vibe を選択してください';

  @override
  String get vibe_selector_recent => '最近の';

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
  String get vibe_import_encodingCost => 'エンコードには 2 Anlas を消費します';

  @override
  String get vibe_import_encodingFailed => 'エンコードに失敗しました';

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
  String get vibe_statusNeedsReencode => '再エンコード (2 Anlas)';

  @override
  String get vibe_statusSourceImageRequired => '元画像が必要';

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
  String get shortcuts_customize => 'ショートカットをカスタマイズする';

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
  String get shortcut_action_vibe_detail_rename => '名前の変更';

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
  String get settings_pleaseLoginFirst => 'まずログインしてください';

  @override
  String get settings_accountNotFound => 'アカウント情報が見つかりません';

  @override
  String get settings_goToLoginPage => 'ログインページに移動';

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
  String get settings_historyClickBehavior => '履歴クリックの動作';

  @override
  String get settings_historyClickBehavior_classic => 'クラシック';

  @override
  String get settings_historyClickBehavior_classicDescription =>
      '履歴画像をクリックして詳細を開きます';

  @override
  String get settings_historyClickBehavior_linked => 'プレビュー連動';

  @override
  String get settings_historyClickBehavior_linkedDescription =>
      'クリックで中央プレビューを切り替え、ダブルクリックまたは長押しで詳細を開き、左右キーで移動します';

  @override
  String get image_viewDetail => '詳細を表示';

  @override
  String get discordShare_action => 'Discord に共有';

  @override
  String get discordShare_title => 'Discord に共有';

  @override
  String get discordShare_subtitle => '画像を Aaalice コミュニティチャンネルに投稿します';

  @override
  String get discordShare_verifyTitle => 'Discord メンバーシップを確認';

  @override
  String get discordShare_verifyDescription =>
      '共有する前にブラウザで Discord にログインしてください。アプリが取得するのは公開プロフィールとサーバーのメンバー状態のみです。';

  @override
  String get discordShare_verifyButton => 'Discord で確認';

  @override
  String get discordShare_verifying => 'Discord の確認を待っています…';

  @override
  String get discordShare_verifyingHint => 'ブラウザで認証を完了してからアプリに戻ってください。';

  @override
  String get discordShare_joinRequired => '先に Aaalice Discord サーバーへ参加してください';

  @override
  String get discordShare_joinDescription =>
      'コミュニティチャンネルへ共有できるのはサーバーメンバーだけです。参加後、ここに戻って再確認してください。';

  @override
  String get discordShare_joinServer => 'Discord サーバーに参加';

  @override
  String get discordShare_retryVerification => '再確認';

  @override
  String discordShare_account(Object name) {
    return '$name として確認済み';
  }

  @override
  String get discordShare_disconnect => 'Discord の接続を解除';

  @override
  String get discordShare_channels => '送信先チャンネル';

  @override
  String get discordShare_selectChannel => 'チャンネルを1つ以上選択してください';

  @override
  String get discordShare_caption => '画像のコメント';

  @override
  String get discordShare_captionHint => '投稿タイトルのような短いコメント（任意）';

  @override
  String get discordShare_promptCategories => 'プロンプトの種類';

  @override
  String get discordShare_promptEditHint =>
      '送信前に最終テキストを編集できます。種類を切り替えると画像メタデータから再生成されます。';

  @override
  String get discordShare_promptContent => '送信するプロンプト';

  @override
  String get discordShare_noPromptMetadata =>
      '読み取れるプロンプトメタデータがありません。画像とコメントだけでも共有できます。';

  @override
  String get discordShare_categoryMain => 'メイン';

  @override
  String get discordShare_categoryCharacters => 'キャラクター';

  @override
  String get discordShare_categoryQuality => '品質タグ';

  @override
  String get discordShare_categoryFixed => '固定タグ';

  @override
  String get discordShare_keepMetadata => '画像メタデータを保持';

  @override
  String get discordShare_keepMetadataHint =>
      '既定ではオフです。オフの場合、PNG テキスト、EXIF、NovelAI のステルスメタデータを削除してからアップロードします。';

  @override
  String get discordShare_privacyHint =>
      'この内容は Discord にアップロードされます。プロンプトとコメントに個人情報がないか確認してください。';

  @override
  String get discordShare_send => 'Discord に送信';

  @override
  String get discordShare_sending => '送信中…';

  @override
  String get discordShare_success => 'Discord に共有しました';

  @override
  String get discordShare_partialSuccess =>
      '一部のチャンネルだけ送信できました。失敗したチャンネルを確認して再試行してください。';

  @override
  String discordShare_failed(Object error) {
    return 'Discord への共有に失敗しました：$error';
  }

  @override
  String get discordShare_errorNetwork =>
      'Discord 共有サービスに接続できません。ネットワークを確認して再試行してください。';

  @override
  String get discordShare_errorBrowser =>
      'ブラウザーを開けません。システムの既定のブラウザー設定を確認してください。';

  @override
  String get discordShare_errorTimeout =>
      'Discord の確認がタイムアウトしました。もう一度確認してください。';

  @override
  String get discordShare_errorRateLimited => '共有回数が多すぎます。しばらくしてから再試行してください。';

  @override
  String discordShare_errorRateLimitedRetry(int seconds) {
    return '共有回数が多すぎます。$seconds 秒後に再試行してください。';
  }

  @override
  String get discordShare_errorNoChannels => '現在利用できる Discord 共有チャンネルがありません。';

  @override
  String get discordShare_errorSession => 'Discord の確認が期限切れです。もう一度確認してください。';

  @override
  String get discordShare_errorRelay =>
      'Discord 共有サービスは一時的に利用できません。後でもう一度お試しください。';

  @override
  String get discordShare_errorImageRejected =>
      'Discord がこの画像を拒否しました。サイズまたは形式を確認してください。';

  @override
  String get discordShare_errorDelivery =>
      'Discord チャンネルへの送信に失敗しました。再試行してください。';

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
      '以下のオプションを通じて、ローカル資産、共有コピー、高コストおよび高頻度の画像生成操作を保護します。オフにしても各設定値は保持されますが、機能は無効になります。';

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
  String get settings_limitGenerationIntervalTitle => '画像生成の頻度を制限';

  @override
  String get settings_limitGenerationIntervalSubtitle =>
      '画像生成の開始間隔を設定値以上に制限します。クールダウン中は生成ボタンを使用できません。';

  @override
  String get settings_generationIntervalTitle => '画像生成の間隔';

  @override
  String settings_generationIntervalValue(Object seconds) {
    return '$seconds 秒';
  }

  @override
  String get settings_setGenerationIntervalTitle => '画像生成の間隔を設定';

  @override
  String get settings_generationIntervalHelper =>
      '1～3600 秒で設定できます。画像生成の開始時から計測します。';

  @override
  String get settings_selectLocalOnnxTaggerFolder =>
      'ONNX タガー モデル フォルダーを選択してください';

  @override
  String get settings_localOnnxTaggerFolderSaved =>
      'ONNX タガー モデル フォルダーが保存されました';

  @override
  String get settings_localOnnxTaggerFolder => 'ローカル ONNX タガー モデル';

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
  String get settings_comfyUiEnable => 'ComfyUI 統合を有効にする';

  @override
  String get settings_comfyUiDisabledSubtitle =>
      '無効にすると、ローカル拡大およびその他の ComfyUI 機能が非表示になります';

  @override
  String get settings_comfyUiServerUrl => 'サーバー URL';

  @override
  String get settings_comfyUiConnectionSuccess => '接続に成功しました';

  @override
  String get settings_comfyUiConnectionSuccessFull => 'ComfyUI への接続に成功しました';

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
  String get comfyWorkflow_seedvr2LegacyUpscaleName => 'SeedVR2 互換ノード拡大';

  @override
  String get comfyWorkflow_seedvr2LegacyUpscaleDescription =>
      'インストール済みの SeedVR2VideoUpscaler カスタムノードで拡大します。';

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
      'ファイルからインポートするか、生成ページから Vibe を保存できます';

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
  String get detail_copyPromptTitle => 'ポジティブプロンプトをコピー';

  @override
  String get detail_copyPromptDescription =>
      'コピーするプロンプトのカテゴリを選択してください。固定タグには非公開文字列や個人用マーカーが含まれる場合があります。共有前に確認してください。';

  @override
  String get detail_promptCategoryMain => '主体プロンプト';

  @override
  String get detail_promptCategoryMainHint => '主体、シーン、一般的な説明';

  @override
  String get detail_promptCategoryCharacters => 'キャラクタープロンプト';

  @override
  String get detail_promptCategoryCharactersHint => '各キャラクターに割り当てられたプロンプト';

  @override
  String get detail_promptCategoryQuality => '品質タグ';

  @override
  String get detail_promptCategoryQualityHint => '公式品質プリセットと透明背景の自動タグ';

  @override
  String get detail_promptCategoryFixed => '固定タグ';

  @override
  String get detail_promptCategoryFixedHint => '非公開内容を含む可能性がある固定の接頭・接尾タグ';

  @override
  String get detail_promptCategoryUnavailable => 'このカテゴリは画像に記録されていません';

  @override
  String get detail_copyPromptDefaultHint =>
      '主体とキャラクターは既定で選択され、品質タグと固定タグは除外されます。';

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
  String get updateErrorNetwork =>
      '更新サーバーに接続できません。ネットワークまたはプロキシ設定を確認して、もう一度お試しください。';

  @override
  String get updateErrorServerBusy => '更新サーバーが混み合っています。しばらくしてからもう一度お試しください。';

  @override
  String get updateErrorReleaseNotReady =>
      '最新バージョンのリリースファイルはまだ準備中です。しばらくしてからもう一度お試しください。';

  @override
  String get updateErrorServiceUnavailable =>
      '更新サーバーは一時的に利用できません。しばらくしてからもう一度お試しください。';

  @override
  String get updateErrorInvalidMetadata =>
      '更新情報を検証できませんでした。後でもう一度試すか、Release ページからダウンロードしてください。';

  @override
  String get updateErrorUnknown => '現在アップデートを確認できません。しばらくしてからもう一度お試しください。';

  @override
  String get currentVersion => '現在のバージョン';

  @override
  String get latestVersion => '最新バージョン';

  @override
  String get releaseNotes => 'リリースノート';

  @override
  String get viewReleasePage => 'Release を表示';

  @override
  String get updatePortableManualHint =>
      'このビルドはアプリ内更新に対応していません。Release ページから新しいバージョンを手動でダウンロードしてください。';

  @override
  String updateDownloadingProgress(Object percent) {
    return '更新パッケージをダウンロードしています: $percent%';
  }

  @override
  String updateDownloadSizeSpeed(Object received, Object total, Object speed) {
    return '$received / $total · $speed';
  }

  @override
  String get updateDownloaded => '更新パッケージの準備ができました';

  @override
  String updateDownloadedHint(Object version) {
    return 'v$version をダウンロードし、検証が完了しました。インストールするとアプリが終了し、自動的に再起動します。';
  }

  @override
  String get updateInstallAndRestart => 'インストールして再起動';

  @override
  String get updateInstallNow => '今すぐインストール';

  @override
  String get updateInstallLater => '後でインストール';

  @override
  String get updateDownload => '更新をダウンロード';

  @override
  String get updateDownloadCancelled => 'ダウンロードをキャンセルしました。後で再開できます';

  @override
  String get updateDownloadFailed => '更新のダウンロードに失敗しました';

  @override
  String get updateInstallFailed => '更新のインストールに失敗しました';

  @override
  String get updateInstallingHint => 'インストーラーが起動しました。アプリは終了し、自動的に更新が完了します。';

  @override
  String get updateInstallConfirmationTitle => '今すぐ更新をインストールしますか？';

  @override
  String get updateInstallConfirmationBody =>
      'アプリを安全に終了して更新をインストールし、自動的に再起動します。実行中の生成・ダウンロードタスクは停止するため、必要な内容を先に保存してください。';

  @override
  String get updateActiveTasksWarning => 'キュータスクが実行中です。インストールすると現在のタスクは停止します。';

  @override
  String get remindMeLater => '4時間後に通知';

  @override
  String get skipThisVersion => 'このバージョンをスキップ';

  @override
  String updateNoticeAvailable(Object version) {
    return '新しいバージョン v$version があります';
  }

  @override
  String get updateNoticeAvailableSubtitle =>
      'アプリ内で更新をダウンロード、検証し、安全にインストールできます';

  @override
  String get updateNoticeManualSubtitle =>
      'このプラットフォームでは Release ページから手動で更新してください';

  @override
  String updateNoticeReady(Object version) {
    return 'バージョン v$version の準備ができました';
  }

  @override
  String get updateNoticeReadySubtitle => 'パッケージは検証済みで、インストールできます';

  @override
  String get updateNoticeFailed => '前回の更新は完了しませんでした';

  @override
  String get updateViewDetails => '更新を表示';

  @override
  String updateSettingsAvailable(Object version) {
    return 'v$version が利用可能です。選択して詳細を表示';
  }

  @override
  String updateSettingsReady(Object version) {
    return 'v$version はダウンロード済みです。選択してインストール';
  }

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

  @override
  String get nav_preciseRefLibrary => '精密参照ライブラリ';

  @override
  String get preciseRefLib_title => '精密参照ライブラリ';

  @override
  String get preciseRefLib_searchHint => '参照画像を検索...';

  @override
  String get preciseRefLib_empty => 'ここに画像をドロップまたは貼り付けてライブラリを作成';

  @override
  String get preciseRefLib_emptyHint => 'プレビュー・履歴・ギャラリーで右クリックして保存もできます';

  @override
  String get preciseRefLib_emptyTouch => '画像を読み込んで参照ライブラリを作成';

  @override
  String get preciseRefLib_emptyHintTouch => '生成結果、履歴、ローカルギャラリーから保存することもできます';

  @override
  String get preciseRefLib_import => '画像をインポート';

  @override
  String preciseRefLib_entryCount(int count) {
    return '$count 件';
  }

  @override
  String get preciseRefLib_sendToPreciseRef => '精密参照へ送る';

  @override
  String get preciseRefLib_sendToImg2Img => '画像から画像へ送る';

  @override
  String get preciseRefLib_editEntry => 'パラメータを編集';

  @override
  String get preciseRefLib_deleteEntry => '削除';

  @override
  String get preciseRefLib_confirmDeleteTitle => 'エントリを削除';

  @override
  String preciseRefLib_confirmDelete(String name) {
    return '「$name」を削除しますか？画像ファイルも削除されます。';
  }

  @override
  String preciseRefLib_saved(String name) {
    return '精密参照ライブラリに保存しました：$name';
  }

  @override
  String get preciseRefLib_savedHint => 'ライブラリでパラメータを編集できます';

  @override
  String preciseRefLib_sent(String name) {
    return '精密参照へ送信しました：$name';
  }

  @override
  String preciseRefLib_sentToImg2Img(String name) {
    return '画像から画像へ送信しました：$name';
  }

  @override
  String get preciseRefLib_imageMissing => '元画像ファイルが見つかりません';

  @override
  String get preciseRefLib_invalidImage => '画像形式を認識できないか、ファイルが破損しています';

  @override
  String get preciseRefLib_deleteFailed =>
      '削除に失敗しました。項目と元画像は保持されています。後でもう一度お試しください';

  @override
  String get preciseRefLib_favoritesOnly => 'お気に入りのみ';

  @override
  String get preciseRefLib_sortBy => '並び替え';

  @override
  String get preciseRefLib_sortCreatedAt => '作成日時';

  @override
  String get preciseRefLib_sortLastUsed => '最終使用';

  @override
  String get preciseRefLib_sortUsedCount => '使用回数';

  @override
  String get preciseRefLib_sortName => '名前';

  @override
  String preciseRefLib_importedCount(int count) {
    return '$count 枚の画像をインポートしました';
  }

  @override
  String preciseRefLib_loadFailed(String error) {
    return '精密参照ライブラリを読み込めませんでした：$error';
  }

  @override
  String preciseRefLib_importFailed(String error) {
    return '精密参照ライブラリへの保存に失敗しました：$error';
  }

  @override
  String preciseRefLib_importFailedCount(int count) {
    return '$count 枚の画像を精密参照ライブラリにインポートできませんでした';
  }

  @override
  String get preciseRefLib_fromLibrary => 'ライブラリから';

  @override
  String get preciseRefLib_saveCurrentToLibrary => 'ライブラリへ保存';

  @override
  String preciseRefLib_saveCurrentCount(int count) {
    return '$count 件をライブラリへ保存しました';
  }

  @override
  String get preciseRefLib_selectorTitle => '精密参照ライブラリから選択';

  @override
  String preciseRefLib_selectorConfirm(int count) {
    return '選択を追加 ($count)';
  }

  @override
  String get preciseRefLib_nameLabel => '名前';

  @override
  String get preciseRefLib_typeFilterAll => 'すべて';

  @override
  String get img2img_fromPreciseRefLibrary => '精密参照ライブラリから';

  @override
  String get localGallery_saveToPreciseRefLibrary => '精密参照ライブラリへ保存';

  @override
  String get drop_saveToPreciseRefLibrary => '精密参照ライブラリへ保存';

  @override
  String get common_enabled => '有効';

  @override
  String get common_disabled => '無効';

  @override
  String bulkAction_selectedCount(int count) {
    return '$count 件を選択中';
  }

  @override
  String get comfyTask_errorConnectionFailed => 'ComfyUI サーバーに接続できません';

  @override
  String get comfyTask_errorConnectionUnavailable => 'ComfyUI 接続を利用できません';

  @override
  String get comfyTask_errorExecutionFailedGeneric => 'ComfyUI の実行に失敗しました';

  @override
  String comfyTask_errorExecutionFailed(String error) {
    return 'ComfyUI の実行に失敗しました: $error';
  }

  @override
  String get comfyTask_errorTimeout => 'ComfyUI タスクが 10 分でタイムアウトしました';

  @override
  String comfyTask_errorWorkflowNotFound(String workflowId) {
    return 'ワークフローが見つかりません: $workflowId';
  }

  @override
  String get comfyWorkflowSlot_vaeEncodeTileSize => 'VAE エンコードのタイルサイズ';

  @override
  String get comfyWorkflowSlot_vaeDecodeTileSize => 'VAE デコードのタイルサイズ';

  @override
  String get comfyWorkflowSlot_blocksToSwap => 'スワップするブロック数';

  @override
  String get comfyWorkflowSlot_swapIoComponents => 'I/O コンポーネントをスワップ';

  @override
  String localGallery_firstIndexHint(int count) {
    return '$count 枚の画像を検出しました。初回のインデックス作成には数分かかる場合がありますが、アプリはそのまま使用できます。';
  }

  @override
  String get localGallery_errorPermissionDenied =>
      '画像フォルダーにアクセスできません。フォルダーの権限を確認してください。';

  @override
  String localGallery_errorScanFailed(String error) {
    return '画像のスキャンに失敗しました: $error';
  }

  @override
  String localGallery_errorInitializationFailed(String error) {
    return 'ギャラリーの初期化に失敗しました: $error';
  }

  @override
  String get localGallery_errorServiceInitializing =>
      'ギャラリーサービスを初期化しています。しばらくしてから再試行してください。';

  @override
  String localGallery_errorDatabaseFailed(String error) {
    return 'ギャラリーデータベースエラー: $error';
  }

  @override
  String localGallery_errorRefreshFailed(String error) {
    return 'ギャラリーの更新に失敗しました: $error';
  }

  @override
  String localGallery_errorFilterFailed(String error) {
    return 'ギャラリーフィルターの適用に失敗しました: $error';
  }

  @override
  String localGallery_errorFavoriteFailed(String error) {
    return 'お気に入り状態の更新に失敗しました: $error';
  }

  @override
  String localGallery_errorRebuildFailed(String error) {
    return 'ギャラリーインデックスの再構築に失敗しました: $error';
  }

  @override
  String get diy_editDependencyTitle => '依存関係を編集';

  @override
  String get diy_dependencyTitle => '依存関係設定';

  @override
  String get diy_dependencySubtitle => 'タグ選択間の依存関係を設定します';

  @override
  String get diy_dependencyType => '依存タイプ';

  @override
  String get diy_sourceCategory => 'ソースカテゴリ';

  @override
  String get diy_selectSourceCategory => 'ソースカテゴリを選択';

  @override
  String get diy_sourceCategoryId => 'ソースカテゴリ ID';

  @override
  String get diy_enterCategoryId => 'カテゴリ ID を入力';

  @override
  String get diy_mappingRules => 'マッピングルール';

  @override
  String get diy_noMappingRules => 'マッピングルールはありません';

  @override
  String get diy_deleteRule => 'ルールを削除';

  @override
  String get diy_defaultValue => 'デフォルト値';

  @override
  String get diy_defaultValueHint => '一致するマッピングルールがない場合に使用します';

  @override
  String get diy_enableDependency => '依存関係を有効化';

  @override
  String get diy_enableDependencyHint => '無効にすると、この依存関係は適用されません';

  @override
  String get diy_addMappingRule => 'マッピングルールを追加';

  @override
  String get diy_sourceValue => 'ソース値';

  @override
  String get diy_sourceValueHint => '例: 1, 2, 3';

  @override
  String get diy_resultValue => '結果値';

  @override
  String get diy_resultValueHint => '例: 0-3, 0-2, 0-1';

  @override
  String get diy_dependencyCount => '数量';

  @override
  String get diy_dependencyExists => '存在';

  @override
  String get diy_dependencyValue => '値';

  @override
  String get diy_dependencyExcludes => '除外';

  @override
  String get diy_dependencyCountDescription => 'ソースカテゴリの選択数から結果数を決定します';

  @override
  String get diy_dependencyExistsDescription => 'ソースカテゴリでタグが選択されている場合のみ適用します';

  @override
  String get diy_dependencyValueDescription => 'ソースカテゴリで選択された特定のタグ値に依存します';

  @override
  String get diy_dependencyExcludesDescription => 'ソースカテゴリでタグが選択されている場合は適用しません';

  @override
  String get diy_editConditionalTitle => '条件分岐を編集';

  @override
  String get diy_conditionalDefaultName => '条件分岐';

  @override
  String diy_branchDefaultName(int index) {
    return '分岐 $index';
  }

  @override
  String get diy_conditionalTitle => '条件分岐';

  @override
  String get diy_conditionalSubtitle => '確率に基づいて分岐を選択します';

  @override
  String diy_branchCount(int count) {
    return '$count 件の分岐';
  }

  @override
  String get diy_noConditionalBranches => '条件分岐はありません';

  @override
  String get diy_noConditionalBranchesHint => '分岐を追加して条件選択ロジックを作成します';

  @override
  String diy_conditionCount(int count) {
    return '$count 件の条件';
  }

  @override
  String get diy_deleteBranch => '分岐を削除';

  @override
  String get diy_addBranch => '分岐を追加';

  @override
  String diy_editBranch(String name) {
    return '編集: $name';
  }

  @override
  String get diy_branchName => '分岐名';

  @override
  String get diy_probability => '確率';

  @override
  String get diy_enableBranch => 'この分岐を有効化';

  @override
  String diy_ruleDefaultName(int index) {
    return 'ルール $index';
  }

  @override
  String diy_ruleCount(int count) {
    return '$count 件のルール';
  }

  @override
  String get diy_addRule => 'ルールを追加';

  @override
  String get diy_editRule => 'ルールを編集';

  @override
  String get diy_ruleName => 'ルール名';

  @override
  String get diy_enableRule => 'このルールを有効化';

  @override
  String get diy_postProcessTitle => '後処理ルール';

  @override
  String get diy_postProcessSubtitle => 'タグの競合を自動的に解決します';

  @override
  String get diy_sleepingRule => '睡眠ルール';

  @override
  String get diy_sleepingRuleDescription => 'キャラクターが眠っているときに目の色の記述を削除します';

  @override
  String get diy_mermaidRule => '人魚ルール';

  @override
  String get diy_mermaidRuleDescription => '人魚、ケンタウロス、ラミアなどから脚部衣装の記述を削除します';

  @override
  String get diy_presetRules => 'プリセットルール';

  @override
  String get diy_noPostProcessRules => '後処理ルールはありません';

  @override
  String get diy_noPostProcessRulesHint => 'ルールを追加してタグの競合を自動的に解決します';

  @override
  String get diy_actionType => 'アクションタイプ';

  @override
  String get diy_triggerTags => 'トリガータグ';

  @override
  String get diy_commaSeparatedTagsHint => 'カンマ区切りのタグリスト';

  @override
  String get diy_targetCategories => '対象カテゴリ';

  @override
  String get diy_commaSeparatedCategoryIdsHint => 'カンマ区切りのカテゴリ ID リスト';

  @override
  String get diy_targetTags => '対象タグ';

  @override
  String get diy_actionRemoveTags => 'タグを削除';

  @override
  String get diy_actionReplaceTags => 'タグを置換';

  @override
  String get diy_actionAddTags => 'タグを追加';

  @override
  String get diy_actionRemoveCategories => 'カテゴリを削除';

  @override
  String get diy_noTriggers => 'トリガーなし';

  @override
  String diy_actionSummary(String triggers, String action) {
    return '[$triggers] に一致した場合: $action';
  }

  @override
  String get diy_characterPositionTitle => 'キャラクター位置';

  @override
  String get diy_characterPositionSubtitle => 'キャラクター位置を視覚的に編集';

  @override
  String get diy_addCharacterPosition => 'キャラクター位置を追加';

  @override
  String get diy_addCharacterPositionHint => '下のボタンでキャラクター位置を追加します';

  @override
  String diy_characterIndex(int index) {
    return 'キャラクター $index';
  }

  @override
  String get diy_aiPositionChoice => 'AI が自動選択';

  @override
  String diy_positionCoordinates(String row, String column) {
    return '行: $row%、列: $column%';
  }

  @override
  String get diy_customPosition => 'カスタム';

  @override
  String diy_emphasisPercent(String percent) {
    return '強調 $percent%';
  }

  @override
  String get diy_characterCountWeight => 'キャラクター数の重み';

  @override
  String diy_peopleCount(int count) {
    return '$count 人';
  }

  @override
  String get diy_genderProbability => '性別の確率';

  @override
  String get diy_noWeightsConfigured => '重みが設定されていません';

  @override
  String get diy_genderOther => 'その他';

  @override
  String get diy_emphasisTitle => 'グローバル強調';

  @override
  String get diy_emphasisSubtitle => 'タグの強調効果を調整';

  @override
  String get diy_emphasisProbability => '強調確率';

  @override
  String diy_emphasisProbabilityHint(String percent) {
    return '選択された各タグに $percent% の確率で強調括弧が追加されます';
  }

  @override
  String get diy_bracketCount => '括弧の階層数';

  @override
  String diy_bracketLayers(int count) {
    return '$count 層';
  }

  @override
  String get diy_effectPreview => '効果プレビュー';

  @override
  String get diy_exampleTag => 'タグの例';

  @override
  String get diy_emphasisExplanation => '強調括弧はタグの重みを増やし、階層が多いほど重みが高くなります';

  @override
  String diy_presetExportFailed(String error) {
    return 'プリセットのエクスポートに失敗しました: $error';
  }

  @override
  String get diy_presetJsonRootObject => 'JSON のルートはオブジェクトである必要があります';

  @override
  String diy_presetInvalidData(String error) {
    return '無効なプリセットデータ: $error';
  }

  @override
  String get diy_presetExportTitle => 'プリセットをエクスポート';

  @override
  String get diy_presetImportTitle => 'プリセットをインポート';

  @override
  String get diy_unknown => '不明';

  @override
  String get diy_presetShareHint => '以下の内容をコピーして共有できます';

  @override
  String get diy_presetPasteJsonHint => 'プリセットの JSON データをここに貼り付け...';

  @override
  String get diy_presetPreview => 'プリセットのプレビュー';

  @override
  String get diy_name => '名前';

  @override
  String get diy_description => '説明';

  @override
  String get diy_categoryCount => 'カテゴリ数';

  @override
  String get diy_totalTagCount => 'タグ総数';

  @override
  String get diy_visibilityTitle => '表示ルール';

  @override
  String get diy_visibilitySubtitle => '条件に基づいてカテゴリの表示を制御します';

  @override
  String get diy_noVisibilityRules => '表示ルールはありません';

  @override
  String get diy_noVisibilityRulesHint => 'ルールを追加して現在の構成からカテゴリの表示を制御します';

  @override
  String get diy_notSet => '未設定';

  @override
  String get diy_targetCategory => '対象カテゴリ';

  @override
  String get diy_conditionType => '条件タイプ';

  @override
  String get diy_conditionValue => '条件値';

  @override
  String get diy_conditionValueHint => 'タグ名または値';

  @override
  String get diy_visibleWhenMatched => '一致した場合に表示';

  @override
  String get diy_conditionTagExists => 'タグが存在する';

  @override
  String get diy_conditionTagNotExists => 'タグが存在しない';

  @override
  String get diy_conditionValueEquals => '値が等しい';

  @override
  String get diy_conditionValueNotEquals => '値が等しくない';

  @override
  String get diy_conditionValueInList => '値がリストに含まれる';

  @override
  String get diy_conditionValueNotInList => '値がリストに含まれない';

  @override
  String get diy_editTimeConditionTitle => '時間条件を編集';

  @override
  String get diy_timeDefaultName => '時間条件';

  @override
  String get diy_timeTitle => '時間条件';

  @override
  String get diy_timeSubtitle => '指定した日付範囲内で有効化します';

  @override
  String get diy_enableTimeCondition => '時間条件を有効化';

  @override
  String get diy_enableTimeConditionHint => '設定した日付範囲内でのみ適用します';

  @override
  String get diy_christmas => 'クリスマス';

  @override
  String get diy_christmasDescription => '12月1日から31日まで有効になるクリスマスタグ';

  @override
  String get diy_halloween => 'ハロウィン';

  @override
  String get diy_halloweenDescription => '10月1日から31日まで有効になるハロウィンタグ';

  @override
  String get diy_valentinesDay => 'バレンタインデー';

  @override
  String get diy_valentinesDescription => '2月1日から14日まで有効になるバレンタインタグ';

  @override
  String get diy_presetTemplates => 'プリセットテンプレート';

  @override
  String get diy_dateRange => '日付範囲';

  @override
  String get diy_startDate => '開始日';

  @override
  String get diy_endDate => '終了日';

  @override
  String get diy_crossYearUnsupported => '年をまたぐ日付範囲はまだサポートされていません';

  @override
  String get diy_month => '月';

  @override
  String get diy_day => '日';

  @override
  String get diy_conditionName => '条件名';

  @override
  String get diy_conditionNameHint => '条件名を入力';

  @override
  String get diy_repeatYearly => '毎年繰り返す';

  @override
  String get diy_repeatYearlyHint => '毎年同じ日付範囲で自動的に有効化します';

  @override
  String get diy_currentlyActive => '現在有効';

  @override
  String get diy_inactive => '無効';

  @override
  String diy_daysRemaining(int count) {
    return '残り $count 日';
  }

  @override
  String diy_timeRangeSummary(
    String name,
    int startMonth,
    int startDay,
    int endMonth,
    int endDay,
  ) {
    return '$name（$startMonth月$startDay日～$endMonth月$endDay日）';
  }

  @override
  String get diy_activeBadge => '有効';

  @override
  String get common_optional => '任意';

  @override
  String get common_emptyValue => '（空）';

  @override
  String get common_previewLoadFailed => 'プレビューを読み込めませんでした';

  @override
  String get common_clickToRefresh => 'クリックして更新';

  @override
  String get common_clickToRetry => 'クリックして再試行';

  @override
  String get common_opening => '開いています...';

  @override
  String get common_swap => '入れ替え';

  @override
  String get common_prefix => 'プレフィックス';

  @override
  String get common_suffix => 'サフィックス';

  @override
  String get common_minimum => '最小';

  @override
  String get common_maximum => '最大';

  @override
  String get addToLibrary_displayNameHint => 'この項目を識別する名前を入力';

  @override
  String get addToLibrary_tagHint => 'タグを入力して Enter キーで追加';

  @override
  String get newPresetDialog_nameRequired => 'プリセット名を入力してください';

  @override
  String get newPresetDialog_nameLabel => 'プリセット名';

  @override
  String get newPresetDialog_nameHint => '新しいプリセットの名前を入力';

  @override
  String get newPresetDialog_creationMode => '作成方法';

  @override
  String get drop_saveVibeBundle => 'Vibe Bundleを保存';

  @override
  String drop_saveVibeBundleSubtitle(String name) {
    return '$name などのVibeをライブラリに保存';
  }

  @override
  String get drop_saveEncodedVibeSubtitle => 'エンコード済みVibeデータをライブラリに保存';

  @override
  String get history_dragFilePreparationFailed =>
      'ドラッグ用ファイルの準備に失敗しました。後でもう一度お試しください。';

  @override
  String get history_dragFilePreparing => 'ドラッグ用ファイルを準備しています...';

  @override
  String get history_dragFileNotReady => 'ドラッグ用ファイルはまだ準備できていません';

  @override
  String get vibe_import_overwriteOriginalParams => '元のVibeパラメータを置換';

  @override
  String vibe_import_overwriteOriginalParamsHint(String name) {
    return '$name のライブラリ内パラメータのみ置換します。初期状態では無効です';
  }

  @override
  String vibe_import_reencodeFailed(String name) {
    return 'Vibeの再エンコードに失敗しました: $name';
  }

  @override
  String get randomManager_keyboardShortcutsHint => 'キーボードショートカット（? キーで表示）';

  @override
  String get localGallery_createFolder => 'フォルダーを作成';

  @override
  String galleryScan_skipped(int count) {
    return 'スキップ $count';
  }

  @override
  String galleryScan_withMetadata(int count) {
    return 'メタデータあり $count';
  }

  @override
  String galleryScan_failed(int count) {
    return '失敗 $count';
  }

  @override
  String get galleryScan_processing => '処理中';

  @override
  String get galleryScan_pending => '処理待ち';

  @override
  String get vibeDetail_useAll => 'すべて使用';

  @override
  String get vibeDetail_longPressSetCover => '長押ししてカバーに設定';

  @override
  String get vibeDetail_noPreviewImage => 'プレビュー画像がありません';

  @override
  String get vibeDetail_dropPreviewImage => 'ここに画像をドロップしてプレビューを設定';

  @override
  String get vibeDetail_releasePreviewImage => '離すとプレビュー画像を設定';

  @override
  String imagePicker_dropReadFailed(String error) {
    return 'ドロップした画像を読み込めませんでした: $error';
  }

  @override
  String get imagePicker_dropNoReadableImage =>
      'ドロップされたデータに読み取り可能な画像ファイルまたは画像URLがありません';

  @override
  String get imagePicker_fileDataUnavailable => 'ファイルデータを読み込めません';

  @override
  String imagePicker_fileSelectionFailed(String error) {
    return 'ファイルの選択に失敗しました: $error';
  }

  @override
  String imagePicker_directorySelectionFailed(String error) {
    return 'フォルダーの選択に失敗しました: $error';
  }

  @override
  String get editor_effects => 'エフェクト';

  @override
  String get editor_shiftEdges => 'エッジをシフト';

  @override
  String editor_currentSize(int width, int height) {
    return '現在: $width x $height';
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
  String get editor_enterNumber => '数値を入力してください';

  @override
  String get editor_nonNegativeNumber => '0以上の値を入力してください';

  @override
  String editor_requestedSize(int width, int height) {
    return '指定: $width x $height';
  }

  @override
  String get editor_requestedSizeInvalid => '指定: 無効';

  @override
  String editor_appliedSize(int width, int height) {
    return '適用: $width x $height';
  }

  @override
  String get editor_appliedSizeInvalid => '適用: 無効';

  @override
  String editor_appliedEdges(int left, int top, int right, int bottom) {
    return '適用エッジ: 左 $left、上 $top、右 $right、下 $bottom';
  }

  @override
  String get editor_appliedEdgesInvalid => '適用エッジ: 無効';

  @override
  String editor_appliedDimensionLimit(int max) {
    return '適用後の寸法は $max 以下である必要があります。';
  }

  @override
  String get savePreset_title => 'プリセットとして保存';

  @override
  String get savePreset_nameHint => 'プリセット名を入力';

  @override
  String get savePreset_metadataDescription => '画像メタデータから保存';

  @override
  String savePreset_vibeData(int count) {
    return 'Vibeデータ（$count）';
  }

  @override
  String get onlineGallery_videoLoadFailed => '動画を読み込めませんでした';

  @override
  String get vibe_releaseToAddStyleReference => '離すとスタイル参照を追加';

  @override
  String router_pageNotFound(String error) {
    return 'ページが見つかりません: $error';
  }

  @override
  String get autocomplete_translating => '翻訳中…';

  @override
  String get autocomplete_missingTranslation => '未翻訳';

  @override
  String autocomplete_translationCoverage(int translated, int total) {
    return '翻訳カバー率：$translated/$total';
  }

  @override
  String autocomplete_aliasMatch(String alias) {
    return '別名：$alias';
  }

  @override
  String get autocomplete_settingsTitle => 'オートコンプリート';

  @override
  String get autocomplete_enable => 'オートコンプリートを有効にする';

  @override
  String get autocomplete_resultLimit => '結果数';

  @override
  String get autocomplete_allResults => 'すべて';

  @override
  String get autocomplete_showAliases => '一致した別名を表示';

  @override
  String get autocomplete_showTranslations => '中国語訳を表示';

  @override
  String get autocomplete_autoComma => '挿入後にカンマを追加';

  @override
  String get autocomplete_openOnTagClick => 'タグのクリックで補完を表示';

  @override
  String get autocomplete_openOnTagClickSubtitle =>
      'オンにすると既存タグのクリックで通常の補完を開きます。Ctrl/Command＋クリックでは引き続き関連タグを表示します';

  @override
  String get autocomplete_replaceUnderscores => '挿入時にアンダースコアを空白に置換';

  @override
  String get autocomplete_dataSourcesTitle => 'データソースとキャッシュ';

  @override
  String get autocomplete_relatedTagsTitle => '共起・関連タグ候補';

  @override
  String get autocomplete_relatedTagsSubtitle =>
      'タグ確定後に自動表示。タグ上で Ctrl+Shift+Space または Ctrl+クリックでも表示できます';

  @override
  String get autocomplete_danbooruApi => 'Danbooru オンライン補完';

  @override
  String get autocomplete_danbooruPrivacy => '現在の英語タグのみ送信し、プロンプト全体は送信しません';

  @override
  String get autocomplete_llmTranslation => '不足する翻訳に Prompt Assistant を使用';

  @override
  String get autocomplete_llmRouteMissing =>
      '先に Prompt Assistant で Translate ルートを設定してください';

  @override
  String autocomplete_llmRoute(String route) {
    return '現在のルート：$route。モデル利用料が発生する場合があります。';
  }

  @override
  String get autocomplete_cooccurrence => 'ローカル関連タグデータ';

  @override
  String autocomplete_entryCount(int count) {
    return '$count 件';
  }

  @override
  String get autocomplete_cooccurrenceAutoDownload => 'ローカル関連タグデータを自動ダウンロード';

  @override
  String get autocomplete_cooccurrenceAutoDownloadSubtitle =>
      '関連タグが有効な場合、ホーム画面表示後にバックグラウンドで取得します。基本補完はブロックされません';

  @override
  String get autocomplete_downloadNow => '今すぐダウンロード';

  @override
  String autocomplete_cooccurrenceUnavailable(String size) {
    return '未インストール · ダウンロード $size。オンライン関連タグは利用できます。';
  }

  @override
  String get autocomplete_cooccurrenceChecking => 'ローカルデータを確認中…';

  @override
  String autocomplete_cooccurrenceDownloading(
    String downloaded,
    String total,
    String speed,
  ) {
    return 'ダウンロード中 $downloaded / $total · $speed。オンライン結果は利用できます。';
  }

  @override
  String get autocomplete_cooccurrenceVerifying => 'ダウンロード完了。データパックを検証中…';

  @override
  String get autocomplete_cooccurrenceInstalling => 'データベースを安全にインストール・切り替え中…';

  @override
  String autocomplete_cooccurrenceReady(
    String version,
    int count,
    String size,
  ) {
    return 'バージョン $version · $count 組 · ディスク使用量 $size';
  }

  @override
  String autocomplete_cooccurrenceUpdateAvailable(String version) {
    return 'データバージョン $version を利用できます';
  }

  @override
  String autocomplete_cooccurrenceFailed(String reason) {
    return 'ローカルデータを利用できません：$reason。基本補完とオンライン関連タグには影響しません。';
  }

  @override
  String get autocomplete_cooccurrenceErrorNetwork =>
      'ネットワーク接続に失敗しました。後でもう一度お試しください';

  @override
  String get autocomplete_cooccurrenceErrorDiskFull => 'ディスクの空き容量が不足しています';

  @override
  String get autocomplete_cooccurrenceErrorArchive => 'ダウンロードが不完全、または検証に失敗しました';

  @override
  String get autocomplete_cooccurrenceErrorDatabase =>
      'データベースが破損しているか互換性がありません';

  @override
  String get autocomplete_cooccurrenceErrorManifest => '内蔵データマニフェストが無効です';

  @override
  String get autocomplete_cooccurrenceErrorInstall => 'データファイルを書き込み、または置換できません';

  @override
  String get autocomplete_cooccurrenceRemoveTitle => 'ローカル関連タグデータを削除しますか？';

  @override
  String get autocomplete_cooccurrenceRemoveConfirm =>
      '削除するとディスク容量が解放されます。オンライン関連タグは引き続き利用できます。';

  @override
  String get autocomplete_cooccurrenceStopAutoDownload =>
      '次回再インストールされないよう、自動ダウンロードもオフにする';

  @override
  String get autocomplete_cacheTitle => 'オンライン・AI キャッシュ';

  @override
  String get autocomplete_clearDanbooruCache => 'Danbooru キャッシュを消去';

  @override
  String get autocomplete_clearAiCache => 'AI 翻訳キャッシュを消去';

  @override
  String autocomplete_cacheCleared(int count) {
    return 'キャッシュを $count 件消去しました';
  }

  @override
  String get autocomplete_baseCatalog => '基本 Danbooru カタログ';

  @override
  String autocomplete_catalogStatus(String count, String version) {
    return '$count タグ · データ版 $version';
  }

  @override
  String get autocomplete_zhDictionary => 'ffdkj 簡体字中国語辞書';

  @override
  String autocomplete_zhInstalled(int count, String version) {
    return '$count 件インストール済み · バージョン $version';
  }

  @override
  String get autocomplete_zhNotInstalled => '未インストール（英語補完は利用できます）';

  @override
  String get autocomplete_zhInstallPrompt =>
      '中国語表示と逆引き用の ffdkj 辞書を上流から直接インストールできます。';

  @override
  String get autocomplete_checkUpdate => '更新を確認';

  @override
  String get autocomplete_update => '更新';

  @override
  String get autocomplete_repair => '修復';

  @override
  String get autocomplete_install => 'インストール';

  @override
  String get autocomplete_remove => '削除';

  @override
  String get autocomplete_removeConfirm =>
      'インストール済みの中国語翻訳辞書を削除しますか？後で再インストールできます。';

  @override
  String get autocomplete_sourceBase => '同梱の基本カタログ';

  @override
  String get autocomplete_sourceZh => 'ffdkj 中国語辞書';

  @override
  String get autocomplete_sourceApi => 'Danbooru API';

  @override
  String get autocomplete_sourceRelated => 'オフライン関連タグ';

  @override
  String get autocomplete_sourceAi => 'Prompt Assistant 翻訳';

  @override
  String get autocomplete_headerTitle => 'タグ補完';

  @override
  String get autocomplete_relatedHeaderTitle => '関連タグ';

  @override
  String get autocomplete_loading => 'ローカルカタログとオンラインタグを検索中…';

  @override
  String get autocomplete_empty => '一致するタグが見つかりません';

  @override
  String get autocomplete_relatedLoading => 'ローカル共起データとオンライン関連タグを検索中…';

  @override
  String get autocomplete_relatedEmpty => '利用可能な関連タグがありません';

  @override
  String autocomplete_relatedMetric(int count, String score) {
    return '共起 $count 回 · Jaccard $score';
  }

  @override
  String get autocomplete_relatedPin => 'このタグを固定して関連タグを連続挿入';

  @override
  String get autocomplete_relatedUnpin => '固定を解除して連鎖候補に戻す';

  @override
  String get autocomplete_statusBase => 'ローカル';

  @override
  String get autocomplete_statusRelated => '共起';

  @override
  String get autocomplete_statusOnlineOnly => 'オンラインのみ';

  @override
  String get autocomplete_statusOnlineOnlyTooltip =>
      'ローカル関連タグデータが未準備のため、Danbooru のオンライン結果のみ表示しています';

  @override
  String get autocomplete_statusDictionary => '翻訳';

  @override
  String get autocomplete_statusOnline => 'オンライン';

  @override
  String get autocomplete_statusAi => 'AI';

  @override
  String get autocomplete_statusReady => '準備完了';

  @override
  String get autocomplete_statusNotInstalled => '未導入';

  @override
  String autocomplete_statusDownloading(int progress) {
    return 'DL $progress%';
  }

  @override
  String get autocomplete_statusUpdateAvailable => '更新あり';

  @override
  String get autocomplete_statusError => 'エラー';

  @override
  String get autocomplete_statusDisabled => 'オフ';

  @override
  String get autocomplete_statusSearching => '検索中';

  @override
  String get autocomplete_statusTranslating => '翻訳中';

  @override
  String get autocomplete_openSettings => '補完とデータソース設定を開く';

  @override
  String get randomManager_searchCategories => 'カテゴリ、グループ、タグを検索（Ctrl+F）';

  @override
  String get randomManager_searchCategoriesCompact => 'カテゴリ、グループ、タグを検索';

  @override
  String get randomManager_workspaceTitle => 'ランダムライブラリ';

  @override
  String get randomManager_workspaceSubtitle =>
      '完全なオフラインカタログから再利用可能な生成レシピを構成します';

  @override
  String get randomManager_recipeTitle => '生成レシピ';

  @override
  String get randomManager_recipeSubtitle => '各ステージで意味カテゴリごとの発動確率と抽出範囲を設定します';

  @override
  String get randomManager_inspectorTitle => '生成設定';

  @override
  String get randomManager_inspectorSubtitle => '現在のプリセットのキャラクター分布と出力動作を調整します';

  @override
  String get randomManager_previewEmptyDescription =>
      'サンプルを生成して、現在のレシピの出力を確認します。';

  @override
  String get randomManager_category_composition => '構図';

  @override
  String get randomManager_category_camera => 'カメラアングル';

  @override
  String get randomManager_category_framing => 'フレーミング';

  @override
  String get randomManager_category_focus => 'フォーカス';

  @override
  String get randomManager_category_eyeFeature => '目の特徴';

  @override
  String get randomManager_category_hairLength => '髪の長さ';

  @override
  String get randomManager_category_hairTexture => '髪質';

  @override
  String get randomManager_category_bangs => '前髪';

  @override
  String get randomManager_category_skinTone => '肌の色';

  @override
  String get randomManager_category_species => '種族';

  @override
  String get randomManager_category_headwear => '帽子';

  @override
  String get randomManager_category_hairAccessory => '髪飾り';

  @override
  String get randomManager_category_prop => '小道具';

  @override
  String get randomManager_category_effect => 'エフェクト';

  @override
  String get randomManager_category_year => '年代';

  @override
  String get randomManager_category_detail => 'クリエイティブ詳細';

  @override
  String randomManager_sourceOfficial(String wordlist) {
    return '公式 · $wordlist';
  }

  @override
  String get randomManager_sourceCatalog => 'カスタム · Catalog 拡張';

  @override
  String randomManager_sourceHybrid(String wordlist) {
    return 'ハイブリッド · $wordlist + Catalog';
  }

  @override
  String get randomManager_currentMode => '現在のモード';

  @override
  String get randomManager_officialWordlist => '現在のモデルの公式ワードリスト';

  @override
  String randomManager_officialWordlistCount(String wordlist, int count) {
    return '$wordlist：元データ $count 件';
  }

  @override
  String get randomManager_officialAsset => '公式アセット全体';

  @override
  String randomManager_officialAssetCount(int entries, int groups) {
    return '$entries 件、元配列 $groups 個';
  }

  @override
  String get randomManager_sourceFile => 'ソースファイル';

  @override
  String get randomManager_sourceSha256 => 'ソース SHA-256';

  @override
  String get randomManager_catalogExtension => 'Catalog 拡張';

  @override
  String get randomManager_wordlistLegacyAnime => 'Legacy Anime';

  @override
  String get randomManager_wordlistFurryV3 => 'Furry V3';

  @override
  String get randomManager_wordlistCharacterPrompts => 'Character Prompts';

  @override
  String get randomManager_sourceDetails => 'データソースの詳細';

  @override
  String get randomManager_sourceUrl => 'ソース URL';

  @override
  String get randomManager_sourceCommit => 'ソースコミット';

  @override
  String get randomManager_sourceDate => 'ソース日付';

  @override
  String get randomManager_sourceLicense => 'ライセンス';

  @override
  String randomManager_catalogCounts(Object tags, Object aliases) {
    return '完全なカタログ：$tags タグ、$aliases エイリアス';
  }

  @override
  String get randomManager_libraryUnavailable => 'ランダムライブラリを利用できません';

  @override
  String get randomManager_noCategoryResults => '一致するカテゴリ、グループ、タグがありません';

  @override
  String get common_share => '共有';

  @override
  String get common_moreActions => 'その他の操作';

  @override
  String get nav_more => 'その他';

  @override
  String get nav_explore => '探索';

  @override
  String get image_savedToSystemGallery => 'システムギャラリーに保存しました';

  @override
  String image_savedAppOnly(Object error) {
    return 'アプリ内ギャラリーには保存しましたが、システムギャラリーに書き出せませんでした: $error';
  }

  @override
  String image_shareFailed(Object error) {
    return '共有に失敗しました: $error';
  }

  @override
  String onlineGallery_savedFiles(int count) {
    return '$count 個のファイルを保存しました';
  }

  @override
  String get statistics_exportJsonHint => 'すべての統計結果と分布データを構造化 JSON として書き出します。';

  @override
  String get statistics_exportCsvHint => 'セクション別の統計を表計算アプリで開ける CSV として書き出します。';

  @override
  String get queue_reorderTask => 'タスクの順序を変更';

  @override
  String get queue_moreTaskActions => 'その他のタスク操作';

  @override
  String get queue_selectTask => 'タスクを選択';

  @override
  String get settings_notificationSoundImportFailed =>
      'サウンドを読み込めませんでした。ファイルを選び直してください。';

  @override
  String get settings_androidManagedStorage =>
      'システムが安全に管理します。エクスポート時に保存先を選択できます';

  @override
  String get settings_importLocalOnnxTaggerFiles => 'ONNX モデルとラベルファイルをインポート';

  @override
  String settings_localOnnxFilesImported(int count) {
    return 'モデルファイルを $count 件インポートしました';
  }

  @override
  String settings_localOnnxManagedFiles(int count) {
    return 'アプリストレージ内のモデルファイル: $count 件';
  }

  @override
  String get settings_clearLocalOnnxModelsTitle => 'ローカル ONNX モデルを消去しますか？';

  @override
  String get settings_clearLocalOnnxModelsContent =>
      'この端末にインポートした ONNX モデルとラベルファイルを削除します。';

  @override
  String updateAndroidDownloadedHint(Object version) {
    return 'v$version をダウンロードし、検証が完了しました。Android のシステムインストーラーを開いて更新を続行できます。';
  }

  @override
  String get updateAndroidInstallingHint =>
      'Android のシステムインストーラーを開いています。システムの案内に従って更新を確認してください。';

  @override
  String get updateAndroidInstallConfirmationBody =>
      'Android のシステムインストーラーを開きます。確認後、ローカルデータを消去せずにアプリが更新されます。実行中の生成・ダウンロードタスクが停止する場合があるため、必要な内容を先に保存してください。';

  @override
  String get preciseRefLib_moreActions => 'その他の操作';

  @override
  String get vibeDetail_setAsCover => '選択した画像をカバーに設定';

  @override
  String vibeDetail_bundleChildParameters(int index) {
    return '子 Vibe $index のインポートパラメーターを表示しています。';
  }

  @override
  String get vibeDetail_bundleDefaultParameters =>
      'Bundle の既定パラメーターを表示しています。下の子項目を選択すると、そのパラメーターを確認できます。';

  @override
  String get vibeDetail_choosePreviewImage => '画像ボタンからプレビューを選択してください';
}

// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class AppLocalizationsZh extends AppLocalizations {
  AppLocalizationsZh([String locale = 'zh']) : super(locale);

  @override
  String get appTitle => 'Alanya';

  @override
  String get navChats => '聊天';

  @override
  String get navCalls => '通话';

  @override
  String get navStatuses => '动态';

  @override
  String get navMeetings => '会议';

  @override
  String get navProfile => '我的';

  @override
  String get offlineBanner => '无网络连接 — 消息将在重新连接后发送';

  @override
  String get loginWelcome => '欢迎';

  @override
  String get loginSubtitle => '登录以继续使用 Alanya';

  @override
  String get loginPasswordHint => '密码';

  @override
  String get loginForgotPassword => '忘记密码？';

  @override
  String get loginSubmit => '登录';

  @override
  String get loginNoAccount => '还没有账号？';

  @override
  String get loginSignUp => '注册';

  @override
  String get signupTitle => '创建账号';

  @override
  String get signupSubtitle => '加入 Alanya 社区';

  @override
  String get signupNameHint => '全名';

  @override
  String get signupPseudoHint => '用户名';

  @override
  String get signupEmailHint => '电子邮箱';

  @override
  String get signupPasswordHint => '密码';

  @override
  String get signupSubmit => '注册';

  @override
  String get signupHasAccount => '已有账号？';

  @override
  String get signupLogin => '登录';

  @override
  String get validatorRequired => '必填项';

  @override
  String get validatorEmail => '邮箱地址无效';

  @override
  String validatorMinLength(int n) {
    return '至少 $n 个字符';
  }

  @override
  String get validatorOtp6 => '6 位验证码';

  @override
  String get validatorPasswordMatch => '两次输入的密码不一致';

  @override
  String get unknownSender => '未知';

  @override
  String get statusPending => '待发送';

  @override
  String get statusSent => '已发送';

  @override
  String get statusDelivered => '已送达';

  @override
  String get statusRead => '已读';

  @override
  String get statusFailedRetry => '发送失败 — 点击重试';

  @override
  String get retry => '重试';

  @override
  String get forgotPasswordTitle => '找回密码';

  @override
  String get forgotEmailTitle => '输入您的邮箱';

  @override
  String get forgotEmailSubtitle => '验证码将发送至您的邮箱';

  @override
  String get forgotEmailHint => '邮箱';

  @override
  String get forgotOtpTitle => '验证码校验';

  @override
  String forgotOtpSubtitle(String email) {
    return '请输入发送至 $email 的 6 位验证码';
  }

  @override
  String get forgotResendCode => '重新发送验证码';

  @override
  String get forgotNewPasswordTitle => '新密码';

  @override
  String get forgotNewPasswordSubtitle => '请输入新密码';

  @override
  String get forgotNewPasswordHint => '新密码';

  @override
  String get forgotConfirmPasswordHint => '确认密码';

  @override
  String get settingsTitle => '设置';

  @override
  String get settingsAppearance => '外观';

  @override
  String get settingsThemeLight => '浅色';

  @override
  String get settingsThemeDark => '深色';

  @override
  String get settingsThemeSystem => '跟随系统';

  @override
  String get settingsLanguage => '语言';

  @override
  String get settingsLangSystem => '跟随系统';

  @override
  String get settingsSectionLanguages => '语言';

  @override
  String get settingsAppLanguage => '应用语言';

  @override
  String get settingsMessageTranslation => '消息翻译';

  @override
  String settingsLangSystemResolved(String language) {
    return '跟随手机设置——当前为 $language';
  }

  @override
  String get languageScreenHint => '此设置仅更改应用界面的语言，不会更改您收到的消息的语言。';

  @override
  String get languageSectionMessages => '消息';

  @override
  String get settingsMedia => '媒体';

  @override
  String get settingsAutoDownload => '自动下载';

  @override
  String get settingsAutoDownloadSubtitle => '在应用内下载收到的媒体文件';

  @override
  String get settingsMediaVisibility => '保存到相册';

  @override
  String get settingsMediaVisibilitySubtitle => '收到的照片和视频会显示在设备相册中';

  @override
  String get mediaSaveToGallery => '保存到相册';

  @override
  String get mediaSaveToDownloads => '保存到下载';

  @override
  String get mediaSavedToGallery => '已保存到相册';

  @override
  String get mediaSavedToDownloads => '已保存到下载';

  @override
  String get mediaAlreadyInGallery => '已在相册中';

  @override
  String get mediaAlreadyInDownloads => '已在下载中';

  @override
  String get mediaSaveAgain => '再次保存';

  @override
  String get mediaSaveFailed => '无法保存该媒体文件';

  @override
  String get mediaExpired => '媒体已过期';

  @override
  String mediaExpiredAskSender(String name) {
    return '请让 $name 重新发送';
  }

  @override
  String get mediaExpiredResendYourself => '如果还在相册中，请重新发送';

  @override
  String get settingsRingtone => '来电铃声';

  @override
  String get ringtoneScreenTitle => '来电铃声';

  @override
  String get ringtoneSectionSystem => '默认铃声';

  @override
  String get ringtoneSectionApp => '内置铃声';

  @override
  String get ringtoneSectionCustom => '导入的铃声';

  @override
  String get ringtoneSystemDefaultLabel => '设备默认铃声';

  @override
  String get ringtoneAddCustomAction => '添加铃声';

  @override
  String get ringtoneAddCustomHint => '音频文件（MP3、WAV、M4A…），最大 5 MB';

  @override
  String get ringtoneLimitReached => '铃声数量已达上限（10 个）';

  @override
  String get ringtoneCustomEmpty => '尚未导入任何铃声';

  @override
  String get ringtoneDeleteConfirmTitle => '删除该铃声？';

  @override
  String get ringtoneDeleteConfirmMessage => '此操作无法撤销。';

  @override
  String get ringtoneImportSuccess => '铃声已添加并选用';

  @override
  String get ringtoneImportError => '无法导入该文件';

  @override
  String get ringtonePreviewError => '无法播放该铃声';

  @override
  String get ringtoneSyncInfoTitle => '跨设备同步';

  @override
  String get ringtoneSyncInfoBody =>
      '此铃声仅保存在本设备上：音频文件绝不会上传到我们的服务器。\n\n要在其他设备上也能听到，请在那些设备上导入同一音频文件。Alanya 按文件内容识别，而不是按文件名：同名但内容不同的文件不会被识别。\n\n在此之前，您的其他设备会播放原来的声音——您的选择会被保留，一旦在该设备上导入文件，铃声就会恢复。';

  @override
  String get ringtoneSyncInfoTooltip => '在我的其他设备上使用此声音';

  @override
  String get listRingtoneSoundMissing => '本设备上文件缺失';

  @override
  String get listRingtoneSyncedNote =>
      '此选择跟随您的账号，并应用到您的所有设备。导入的铃声必须存在于设备上才能在该设备播放。';

  @override
  String get settingsPrivacy => '隐私';

  @override
  String get settingsPrivacySubtitle => '已屏蔽的联系人';

  @override
  String get commonCancel => '取消';

  @override
  String get commonConfirm => '确认';

  @override
  String get commonDelete => '删除';

  @override
  String get commonSave => '保存';

  @override
  String get commonSend => '发送';

  @override
  String get commonClose => '关闭';

  @override
  String get commonRetry => '重试';

  @override
  String get commonSearch => '搜索';

  @override
  String get commonLoading => '加载中…';

  @override
  String get commonError => '错误';

  @override
  String get commonYes => '是';

  @override
  String get commonNo => '否';

  @override
  String get commonOk => '确定';

  @override
  String get commonAccept => '接受';

  @override
  String get commonDecline => '拒绝';

  @override
  String get commonCallBack => '回拨';

  @override
  String get callMissed => '未接来电';

  @override
  String get callIncoming => '来电';

  @override
  String membersCount(int count) {
    return '成员（$count）';
  }

  @override
  String groupMembersCount(int count) {
    return '群组 • $count 位成员';
  }

  @override
  String pinnedMessagesCount(int count) {
    return '置顶消息（$count）';
  }

  @override
  String selectCount(int count) {
    return '已选择（$count）';
  }

  @override
  String forwardAlbumCount(int count) {
    return '转发相册（$count）';
  }

  @override
  String downloadAlbumCount(int count) {
    return '下载相册（$count）';
  }

  @override
  String get downloadAlbumHint => '将全部媒体保存到设备';

  @override
  String downloadAlbumProgress(int current, int total) {
    return '第 $current / $total 个';
  }

  @override
  String get albumMediaAlreadyDownloaded => '相册中的媒体已全部下载';

  @override
  String maxMessages(int count) {
    return '最多 $count 条消息';
  }

  @override
  String maxVideos(int count) {
    return '最多 $count 个视频。';
  }

  @override
  String albumFirstOnly(int count) {
    return '仅发送前 $count 个。';
  }

  @override
  String videoTooLarge(String mb, int limit) {
    return '视频即使压缩后仍过大（约 $mb MB）。上限：$limit MB。';
  }

  @override
  String fileTooLarge(String mb, int limit) {
    return '文件过大（$mb MB）。上限：$limit MB。';
  }

  @override
  String minutesShort(int minutes) {
    return '$minutes 分钟';
  }

  @override
  String durationLabel(String duration) {
    return '时长：$duration';
  }

  @override
  String todayAt(String time) {
    return '今天 · $time';
  }

  @override
  String tomorrowAt(String time) {
    return '明天 · $time';
  }

  @override
  String todayAtTime(String time) {
    return '今天 $time';
  }

  @override
  String seenAt(String time) {
    return '$time 查看';
  }

  @override
  String seenYesterdayAt(String time) {
    return '昨天 $time 查看';
  }

  @override
  String seenOnDate(int day, int month) {
    return '$month 月 $day 日查看';
  }

  @override
  String seenAtLower(String time) {
    return '$time 查看';
  }

  @override
  String seenYesterdayAtLower(String time) {
    return '昨天 $time 查看';
  }

  @override
  String timeAgoDays(int count) {
    return '$count 天前';
  }

  @override
  String timeAgoHours(int count) {
    return '$count 小时前';
  }

  @override
  String timeAgoMinutes(int count) {
    return '$count 分钟前';
  }

  @override
  String pageOf(int page, int total) {
    return '第 $page / $total 页';
  }

  @override
  String usedByOwner(String owner) {
    return '已使用 · $owner';
  }

  @override
  String maxParticipants(int count) {
    return '最多 $count 位参与者';
  }

  @override
  String selectUpToVideo(int count) {
    return '最多可选择 $count 位成员进行视频通话';
  }

  @override
  String selectUpToVoice(int count) {
    return '最多可选择 $count 位成员进行语音通话';
  }

  @override
  String noResultsFor(String query) {
    return '没有找到与“$query”相关的结果';
  }

  @override
  String editedAt(String time) {
    return '$time 已编辑';
  }

  @override
  String labelForwarded(String label) {
    return '已转发$label';
  }

  @override
  String labelForwardedTo(String label, int count) {
    return '$label已转发至 $count 个聊天';
  }

  @override
  String forwardedToRatio(int ok, int total) {
    return '已转发至 $ok/$total 个聊天';
  }

  @override
  String callFrom(String name) {
    return '$name 的来电';
  }

  @override
  String organizedBy(String name) {
    return '由 $name 组织';
  }

  @override
  String numberAssigned(String number) {
    return '已分配号码：$number';
  }

  @override
  String userIdLabel(String id) {
    return '用户 $id';
  }

  @override
  String canContactAgain(String name) {
    return '$name 将可以重新联系您。';
  }

  @override
  String removePreferredContact(String name) {
    return '将 $name 从常用联系人中移除';
  }

  @override
  String videoMaxSelectable(int count) {
    return '视频：最多 $count 个。';
  }

  @override
  String callBackName(String name) {
    return '回拨 $name';
  }

  @override
  String mediaTitleNamed(String name) {
    return '$name — 媒体';
  }

  @override
  String photosCount(int count) {
    return '📷 $count 张照片';
  }

  @override
  String videosCount(int count) {
    return '🎥 $count 个视频';
  }

  @override
  String locationLabel(String label) {
    return '📍 $label';
  }

  @override
  String contactLabel(String label) {
    return '👤 $label';
  }

  @override
  String tapToOpenLabel(String label) {
    return '$label · 点击打开';
  }

  @override
  String get mediaAccessErrorMakeSureHttps =>
      '媒体访问出错。请确认已启用 HTTPS，或正在使用 localhost。';

  @override
  String get cannotAccessMicrophoneCameraCheckThat =>
      '无法访问麦克风/摄像头。请检查应用是否已获得权限。';

  @override
  String get thisActionCannotBeUndoneThe => '此操作无法撤销。该会议将对所有参与者删除。';

  @override
  String get ifYouReceivedAMeetingLink => '如果您收到了会议链接，也可以直接点击链接加入。';

  @override
  String get microphoneErrorPleaseCheckYourPermissions => '麦克风出错。请检查权限和音频设备。';

  @override
  String get permissionDeniedOpenSettingsOrPick => '权限被拒绝。请前往设置，或在地图上选点。';

  @override
  String get statusesFromContactsWhoFavoritedYou => '将您设为常用联系人的好友，其动态会显示在这里。';

  @override
  String get enableLocationToUseYourPosition => '开启定位以使用当前位置，或移动地图选点。';

  @override
  String get permissionDeniedYouCanStillPick => '权限被拒绝。您仍可在地图上选点。';

  @override
  String get addContactsToFindThemQuickly => '添加联系人，会议中可快速找到他们';

  @override
  String get editingIsOnlyPossibleWithin30 => '仅可在发送后 30 分钟内编辑';

  @override
  String get cameraErrorPleaseCheckYourPermissions => '摄像头出错。请检查权限和摄像头设备。';

  @override
  String get saveTheseDetailsYouWillNeed => '请保存这些信息 — 登录时需要用到：';

  @override
  String get doYouWantToEndThe => '要为所有参与者结束这场会议吗？';

  @override
  String get freeEntryReservedPatternsOrStandard => '自由输入：保留号段或标准 8 位号码';

  @override
  String get viewOnceMediaVisibleOnlyOnce => '阅后即焚 — 接收方仅可查看一次';

  @override
  String get youWillNoLongerSeeThis => '该群组将不再显示在您的聊天列表中。';

  @override
  String get cannotAccessDevicesCheckPermissions => '无法访问设备。请检查权限。';

  @override
  String get permissionDeniedPleaseAllowMicrophoneCamera =>
      '权限被拒绝。请允许使用麦克风/摄像头。';

  @override
  String get theyWillNoLongerBeAble => '对方将无法再向您发送消息或呼叫您。';

  @override
  String get n8DigitsAutoGeneratedExcludingReserved => '8 位数字（自动生成，不含保留号码）';

  @override
  String get noMicrophoneCameraDeviceFoundOn => '系统中未找到麦克风/摄像头设备。';

  @override
  String get gpsUnavailableMoveTheMapTo => 'GPS 不可用。请移动地图选点。';

  @override
  String get localMessagesInThisChatWill => '该聊天中本地保存的消息将被删除。';

  @override
  String get oneOrMoreMessagesCannotBe => '有一条或多条消息无法转发';

  @override
  String get mediaAccessErrorCheckHttpsOr => '媒体访问出错。请检查 HTTPS 或 localhost。';

  @override
  String get noResultsEnterAFullPattern => '无结果 — 请输入完整的号段号码 ';

  @override
  String get conversationDeletedLocallyServerUnreachable => '会话已在本地删除（服务器不可达）';

  @override
  String get thisMessageCannotBeForwardedRight => '该消息暂时无法转发';

  @override
  String get thisAlbumCannotBeForwardedRight => '该相册暂时无法转发';

  @override
  String get selectedChatsAreNotArchived => '所选聊天未被归档';

  @override
  String get enterTheMeetingCodeProvidedBy => '请输入组织者提供的会议码';

  @override
  String get startANewChatWithThe => '点击 + 按钮开始新的聊天。';

  @override
  String get thisMediaCannotBeForwardedRight => '该媒体暂时无法转发';

  @override
  String get reservationLimitedTo3Or4 => '仅可保留 3 位或 4 位号码，';

  @override
  String get selectedChatsAreAlreadyArchived => '所选聊天已归档';

  @override
  String get selectedChatsAreAlreadyPinned => '所选聊天已置顶';

  @override
  String get unableToAddParticipantsTryAgain => '无法添加参与者，请重试';

  @override
  String get peopleYouBlockWillAppearHere => '您屏蔽的人会显示在这里。';

  @override
  String get unableToInviteParticipantsTryAgain => '无法邀请参与者，请重试';

  @override
  String pausedTapToReturn(String type) {
    return '已暂停 · $type · 点击返回';
  }

  @override
  String get sayHelloToStartTheConversation => '打个招呼，开始聊天吧！';

  @override
  String get noFreeNumberFoundInThe => '管理列表中没有可用号码';

  @override
  String get unableToDeleteTheMeetingTry => '无法删除该会议，请重试';

  @override
  String get yourPastAndReceivedCallsWill => '您的通话记录会显示在这里。';

  @override
  String get microphoneCameraPermissionDenied => '麦克风/摄像头权限被拒绝';

  @override
  String get unableToRemoveThisContactTry => '无法移除该联系人，请重试';

  @override
  String get newChatUnavailableOffline => '离线状态下无法新建聊天';

  @override
  String get messageNotFoundInThisConversation => '在该会话中未找到此消息';

  @override
  String get numberMustContainOnlyDigits => '号码只能包含数字';

  @override
  String get invalidNumber34Or8 => '号码无效：需为 3 位、4 位或 8 位';

  @override
  String get errorCreatingTheConversation => '创建会话时出错';

  @override
  String get unableToLeaveTheGroupTry => '无法退出该群组，请重试';

  @override
  String get unableToPostTheStatusTry => '无法发布该动态，请重试';

  @override
  String get unableToAddThisContactTry => '无法添加该联系人，请重试';

  @override
  String get canBeOpenedOnlyOnceThen => '仅可打开一次，之后将无法访问';

  @override
  String get unableToLoadBlockedContacts => '无法加载已屏蔽的联系人';

  @override
  String get enterANumberOrChooseA => '输入号码或选择一位联系人';

  @override
  String get unableToCreateTheMeetingTry => '无法创建该会议，请重试';

  @override
  String get unableToCreateTheGroupTry => '无法创建该群组，请重试';

  @override
  String get searchByNameUsernameOrPhone => '按姓名、用户名或 Alanya ID 搜索…';

  @override
  String get assignAReservedNumberOptional => '分配保留号码（可选）';

  @override
  String get ajoutezDesContactsPourLesRetrouver => '添加联系人以便查找';

  @override
  String get unableToStartTheCallTry => '无法发起通话，请重试';

  @override
  String get cannotInviteABlockedContact => '无法邀请已屏蔽的联系人';

  @override
  String get manageUsersAndMonitoring => '用户管理与监控';

  @override
  String get fromGalleryOrCamera => '从相册或相机选择';

  @override
  String get passwordResetSuccessfully => '密码重置成功';

  @override
  String get reservedPatternDirectAssignment => '保留号段（直接分配）';

  @override
  String get unableToForwardTheMessages => '无法转发这些消息';

  @override
  String get longPressToExitSelection => '长按以退出选择模式';

  @override
  String get unableToDownloadTheFile => '无法下载该文件';

  @override
  String get yourProfilePhotoWillBeRemoved => '您的头像将被移除。';

  @override
  String get unableToForwardTheMessage => '无法转发该消息';

  @override
  String get thisNumberCannotBeAssigned => '该号码无法分配';

  @override
  String get unableToUpdateTheCountry => '无法更新国家/地区';

  @override
  String get errorStartingTheCall => '发起通话时出错';

  @override
  String get unableToDownloadTheMedia => '无法下载该媒体';

  @override
  String get mediaNoLongerAvailable => '该媒体已不可用';

  @override
  String get unableToUnblockThisContact => '无法解除屏蔽该联系人';

  @override
  String get unableToLoadNumbers => '无法加载号码列表';

  @override
  String get searchByNameUsernameOr => '按姓名、用户名或…搜索';

  @override
  String get unableToCreateTheConversation => '无法创建会话';

  @override
  String get noAudioVideoDeviceFound => '未找到音频/视频设备';

  @override
  String get unableToOpenTheConversation => '无法打开该会话';

  @override
  String get connectingTapToReturn => '连接中… · 点击返回';

  @override
  String get unableToVerifyTheContact => '无法验证该联系人';

  @override
  String get meetingInvitationsAndReminders => '会议邀请与提醒';

  @override
  String get errorGroupIdNotFound => '错误：未找到群组 ID';

  @override
  String get profileUnavailableTryAgain => '资料不可用，请重试';

  @override
  String get cannotCallThisContact => '无法呼叫该联系人';

  @override
  String get unableToForwardTheAlbum => '无法转发该相册';

  @override
  String get thisGroupIsNoLongerAccessible => '该群组已无法访问。';

  @override
  String get youHaveBlockedThisUser => '您已屏蔽该用户';

  @override
  String get unableToDisplayTheMessage => '无法显示该消息';

  @override
  String get meetingInLessThan10Minutes => '会议将在 10 分钟内开始';

  @override
  String get addACaptionOptional => '添加说明（可选）';

  @override
  String get rapidementLorsDeVosReunions => '以便在会议中快速找到';

  @override
  String get alreadyInYourPreferredContacts => '已在您的常用联系人中';

  @override
  String get dateMustBeInTheFuture => '日期必须晚于当前时间';

  @override
  String get longPressFailedTryAgain => '长按操作失败，请重试';

  @override
  String get eG112233441234OrLabel => '例如 11223344、1234 或标签…';

  @override
  String get theOtherPartyIsBusy => '对方正忙。';

  @override
  String get viewAndUnblockContacts => '查看并解除屏蔽联系人';

  @override
  String get thisActionCannotBeUndone => '此操作无法撤销。';

  @override
  String get mediaIsNotReadyYet => '媒体尚未就绪';

  @override
  String get thisMediaIsNoLongerAvailable => '该媒体已不可用';

  @override
  String get yourSignInCredentials => '您的登录凭据';

  @override
  String get resetPassword => '重置密码';

  @override
  String get microphonePermissionDenied => '麦克风权限被拒绝';

  @override
  String get noConversationToDelete => '没有可删除的会话';

  @override
  String get phoneAlanyaPhone => 'Alanya ID';

  @override
  String get noOtherMembersToCall => '没有其他可呼叫的成员';

  @override
  String get actionFailedPleaseTryAgain => '操作失败，请重试';

  @override
  String get failedToAddParticipants => '添加参与者失败';

  @override
  String get noArchivedConversations => '没有已归档的会话';

  @override
  String get noConnectionsRecorded => '没有登录记录';

  @override
  String get countryListUnavailable => '国家/地区列表不可用';

  @override
  String get profilePhotoUpdated => '头像已更新';

  @override
  String get searchByNameUsername => '按姓名、用户名搜索…';

  @override
  String get noConversationToClear => '没有可清空的会话';

  @override
  String get historyWillBeDeleted => '聊天记录将被删除。';

  @override
  String get addAtLeastOneMember => '请至少添加一位成员';

  @override
  String get searchChats => '搜索聊天…';

  @override
  String get thisMediaHasAlreadyBeenOpened => '该媒体已被打开过';

  @override
  String get addAPreferredContact => '添加常用联系人';

  @override
  String get enterANumberToAdd => '输入要添加的号码';

  @override
  String get noMeetingsToday => '今天没有会议';

  @override
  String get aCallIsAlreadyInProgress => '已有通话正在进行';

  @override
  String get failedToCreateGroup => '创建群组失败';

  @override
  String get turnOffSpeaker => '关闭扬声器';

  @override
  String get noParticipantsConnected => '没有参与者接入';

  @override
  String get chooseFromGallery => '从相册选择';

  @override
  String get deleteConversation => '删除该会话？';

  @override
  String get manualNumberEntry => '手动输入号码';

  @override
  String get thisMessageWasDeleted => '该消息已被删除';

  @override
  String get deleteUser => '删除该用户？';

  @override
  String get mediaAccessError => '媒体访问出错';

  @override
  String get addADescription => '添加简介…';

  @override
  String get microphonePermissionDenied2 => '麦克风权限被拒绝';

  @override
  String get failedToLeaveGroup => '退出群组失败';

  @override
  String get unableToOpenMaps => '无法打开地图';

  @override
  String get conversationNotFound => '未找到该会话';

  @override
  String get addParticipants => '添加参与者';

  @override
  String get tapToDownload => '点击下载';

  @override
  String pdfPageCount(int count) {
    return '$count 页';
  }

  @override
  String get noUsersFound => '未找到用户';

  @override
  String get enterTheGroupName => '输入群组名称';

  @override
  String get requiredExceptTier3 => '除三级外均为必填';

  @override
  String get deleteConversation2 => '删除会话';

  @override
  String get userNotFound => '未找到该用户';

  @override
  String get downloadFailed => '下载失败';

  @override
  String get invalidUploadResponse => '上传响应无效';

  @override
  String get enableLocation => '开启定位';

  @override
  String get noUpcomingMeetings => '没有即将开始的会议';

  @override
  String get exampleAbcDefgHij => '示例：abc-defg-hij';

  @override
  String get unblockThisContact => '解除屏蔽该联系人？';

  @override
  String get clearMessages => '清空消息？';

  @override
  String get sendThisLocation => '发送该位置';

  @override
  String get startVideoCall => '发起视频通话';

  @override
  String get forwardUnavailable => '无法转发';

  @override
  String get startVoiceCall => '发起语音通话';

  @override
  String get noPastMeetings => '没有历史会议';

  @override
  String get scheduleAMeeting => '安排会议';

  @override
  String get n34DigitsOrXxyyzztt => '3 位 / 4 位数字，或 XXYYZZTT';

  @override
  String get groupCallInProgress => '群组通话进行中';

  @override
  String get deleteThisStatus => '删除该动态？';

  @override
  String get mediaLinksAndDocs => '媒体、链接和文件';

  @override
  String get searchForACountry => '搜索国家/地区…';

  @override
  String get voiceMessageEnded => '语音消息播放结束';

  @override
  String get musicEnded => '音乐播放结束';

  @override
  String get noPreferredContacts => '没有常用联系人';

  @override
  String get donTHaveAnAccount => '还没有账号？';

  @override
  String get joinAMeeting => '加入会议';

  @override
  String get meetingDetails => '会议详情';

  @override
  String get noBlockedContacts => '没有已屏蔽的联系人';

  @override
  String get blockThisContact => '屏蔽该联系人？';

  @override
  String get sendALocation => '发送位置';

  @override
  String get createUser => '创建用户';

  @override
  String get addACaption => '添加说明…';

  @override
  String get alanyaNumberRequired => '需要 Alanya ID';

  @override
  String get selectACountry => '选择国家/地区';

  @override
  String get noReservedNumbers => '没有保留号码';

  @override
  String get clearMessages2 => '清空消息';

  @override
  String get removeFromContacts => '从联系人中移除';

  @override
  String get messageToForward => '要转发的消息';

  @override
  String get deletePhoto => '删除照片？';

  @override
  String get unblockContact => '解除屏蔽';

  @override
  String get loadingCountries => '正在加载国家/地区…';

  @override
  String get newChat => '新建聊天';

  @override
  String get typeYourStatus => '输入您的动态…';

  @override
  String get editMessage => '编辑消息';

  @override
  String get noRecentStatus => '没有最新动态';

  @override
  String get closeSearch => '关闭搜索';

  @override
  String get sendLocation => '发送位置';

  @override
  String get openSettings => '打开设置';

  @override
  String get statusReply => '动态回复';

  @override
  String get statusNoLongerAvailable => '该动态已不可用';

  @override
  String get socketNotConnected => '连接未建立';

  @override
  String get deleteForEveryone => '为所有人删除';

  @override
  String get meetingTitle => '会议主题';

  @override
  String get connecting => '连接中…';

  @override
  String get callReconnecting => '重新连接中…';

  @override
  String get freeUnassigned => '空闲 · 未分配';

  @override
  String get numberUnavailable => '号码不可用';

  @override
  String get meetingNotFound => '未找到该会议';

  @override
  String get recentConnections => '最近登录';

  @override
  String get replyToStatus => '回复该动态…';

  @override
  String get noSharedMedia => '没有共享的媒体';

  @override
  String get leaveGroup => '退出群组？';

  @override
  String get typing => '正在输入…';

  @override
  String get cancelMeeting => '取消会议';

  @override
  String get editProfile => '编辑资料';

  @override
  String get blockContact => '屏蔽联系人';

  @override
  String get groupNotFound => '未找到该群组';

  @override
  String get deleteForMe => '仅为我删除';

  @override
  String get groupVideoCall => '群组视频通话';

  @override
  String get noRecentCalls => '没有最近的通话';

  @override
  String get audioUnavailable => '音频不可用';

  @override
  String get typing2 => '正在输入…';

  @override
  String get numberOrLabel => '号码或标签…';

  @override
  String get albumToForward => '要转发的相册';

  @override
  String get mediaUnavailable => '媒体不可用';

  @override
  String get messageDetails => '消息详情';

  @override
  String get endForEveryone => '为所有人结束';

  @override
  String get writeAMessage => '写点什么…';

  @override
  String get changeNumber => '更换号码';

  @override
  String get countryUnavailable => '国家/地区不可用';

  @override
  String get numberAvailable => '号码可用';

  @override
  String get addAVideo => '添加视频';

  @override
  String get noCountryFound => '未找到国家/地区';

  @override
  String get addAPhoto => '添加照片';

  @override
  String get cameraDisabled => '摄像头已关闭';

  @override
  String get searchInConversationHint => '在聊天中搜索';

  @override
  String get searchNoResult => '未找到消息';

  @override
  String searchResultCounter(int index, int total) {
    return '$index/$total';
  }

  @override
  String get searchPrevious => '上一个结果';

  @override
  String get searchNext => '下一个结果';

  @override
  String get searchExit => '关闭搜索';

  @override
  String get takeAPhoto => '拍照';

  @override
  String get enableCamera => '开启摄像头';

  @override
  String get switchCamera => '切换摄像头';

  @override
  String get noChats => '没有聊天';

  @override
  String get callFailed => '通话失败。';

  @override
  String get retrySending => '重新发送';

  @override
  String get leaveGroup2 => '退出群组';

  @override
  String get preferredContacts => '常用联系人';

  @override
  String get turnOffCamera => '关闭摄像头';

  @override
  String get messagesCleared => '消息已清空';

  @override
  String get reservedNumbers => '保留号码';

  @override
  String get meetingEnded => '会议已结束';

  @override
  String get meetingBlockedByCall => '通话进行中：无法加入会议。';

  @override
  String get meetingJoinExpired => '此会议已过期。';

  @override
  String get meetingJoinNotInvited => '找不到会议。';

  @override
  String get meetingParticipantJoined => '已加入';

  @override
  String get meetingParticipantPending => '待加入';

  @override
  String get meetingExpired => '已过期';

  @override
  String get newMeeting => '新建会议';

  @override
  String get alanyaPhone => 'Alanya ID';

  @override
  String get deletedMessage => '已删除的消息';

  @override
  String get verifyCode => '验证码校验';

  @override
  String get notDeliveredYet => '尚未送达';

  @override
  String get someoneIsTyping => '有人正在输入…';

  @override
  String nameIsTyping(String name) {
    return '$name 正在输入…';
  }

  @override
  String get lastWeek => '上周';

  @override
  String get otherResults => '其他结果';

  @override
  String get changeMedia => '更换媒体';

  @override
  String get contactUnblocked => '已解除屏蔽';

  @override
  String get downloading => '下载中…';

  @override
  String get minimizeCall => '最小化通话';

  @override
  String get createAGroup => '创建群组';

  @override
  String get dashboard => '概览';

  @override
  String get replySent => '回复已发送';

  @override
  String get sessionExpired => '登录已过期';

  @override
  String get callInProgress => '通话中…';

  @override
  String get createGroup => '创建群组';

  @override
  String get newMessage => '新消息';

  @override
  String get groupInfo => '群组信息';

  @override
  String get placeACall => '发起通话';

  @override
  String get newContact => '新建联系人';

  @override
  String get noAnswer => '无人接听。';

  @override
  String get backgroundColor => '背景颜色';

  @override
  String get photoDeleted => '照片已删除';

  @override
  String get serverError => '服务器错误';

  @override
  String get noDocuments => '没有文件';

  @override
  String get reservedNumber => '保留号码';

  @override
  String get password => '密码 *';

  @override
  String get notNow => '暂不';

  @override
  String get missedCalls => '未接来电';

  @override
  String get newStatus => '新动态';

  @override
  String get newGroup => '新建群组';

  @override
  String get noResults => '没有结果';

  @override
  String get labelRequired => '标签为必填项';

  @override
  String get unlike => '取消赞';

  @override
  String get messages7d => '消息（7 天）';

  @override
  String get noContacts => '没有联系人';

  @override
  String get callEnded => '通话已结束';

  @override
  String get joinedOn => '加入于';

  @override
  String get uploadFailed => '上传失败';

  @override
  String get cameraOn => '摄像头已开启';

  @override
  String get cameraOff => '摄像头已关闭';

  @override
  String get verifying => '验证中…';

  @override
  String get reRecord => '重新录制';

  @override
  String get videoComingSoon => '视频功能即将推出';

  @override
  String get dateAndTime => '日期与时间';

  @override
  String get noMessages => '没有消息';

  @override
  String get lastCall => '最近通话';

  @override
  String get videoMeeting => '视频会议';

  @override
  String get groupName => '群组名称';

  @override
  String get callComingSoon => '通话功能即将推出';

  @override
  String get noAnswer2 => '无人接听';

  @override
  String get organizer => '组织者';

  @override
  String get noImages => '没有图片';

  @override
  String get emptyMessage => '消息为空';

  @override
  String get rewind10S => '后退 10 秒';

  @override
  String get pdfDocument => 'PDF 文件';

  @override
  String get speaker => '扬声器';

  @override
  String get audioOutputEarpiece => '听筒';

  @override
  String get audioOutputWired => '有线耳机';

  @override
  String get audioOutputBluetooth => '蓝牙';

  @override
  String get changeAudioOutput => '切换音频输出';

  @override
  String get newCall => '新通话';

  @override
  String get lastView => '最近查看';

  @override
  String get receivedCalls => '来电';

  @override
  String get participants => '参与者';

  @override
  String get alreadyUsed => '已被使用';

  @override
  String get select => '选择';

  @override
  String get makeAdmin => '设为管理员';

  @override
  String get statuses7d => '动态（7 天）';

  @override
  String get forward10S => '快进 10 秒';

  @override
  String get openWith => '打开方式…';

  @override
  String get groupCall => '群组通话';

  @override
  String get noVideos => '没有视频';

  @override
  String get chats => '聊天';

  @override
  String get creating => '创建中…';

  @override
  String get videoCall => '视频通话';

  @override
  String get unpin => '取消置顶';

  @override
  String get micMuted => '麦克风已静音';

  @override
  String get outgoingCalls => '去电';

  @override
  String get micOn => '麦克风已开启';

  @override
  String get demote => '取消管理员';

  @override
  String get audioCall => '语音通话';

  @override
  String get description => '简介';

  @override
  String get unarchive => '取消归档';

  @override
  String get voiceCall => '语音通话';

  @override
  String get search => '搜索…';

  @override
  String get signOut => '退出登录';

  @override
  String get calls7d => '通话（7 天）';

  @override
  String get justNow => '刚刚';

  @override
  String get notSet => '未设置';

  @override
  String get myStatus => '我的动态';

  @override
  String get noViews => '暂无查看';

  @override
  String get connecting2 => '连接中…';

  @override
  String get forward => '转发';

  @override
  String get noLinks => '没有链接';

  @override
  String get emptyAlbum => '相册为空';

  @override
  String get message => '消息…';

  @override
  String get offline => '离线';

  @override
  String get viewOnce => '阅后即焚';

  @override
  String get refresh => '刷新';

  @override
  String get location => '📍 位置';

  @override
  String get later => '稍后';

  @override
  String get warning => '警告';

  @override
  String get seeAll => '查看全部';

  @override
  String get forwarded => '已转发';

  @override
  String get edited => '· 已编辑';

  @override
  String get unblock => '解除屏蔽';

  @override
  String get file => '📎 文件';

  @override
  String get results => '结果';

  @override
  String get join => '加入';

  @override
  String get allow => '允许';

  @override
  String get recently => '最近';

  @override
  String get documents => '文件';

  @override
  String get phone => '电话';

  @override
  String get scheduled => '已安排';

  @override
  String get contact => '👤 联系人';

  @override
  String get gotIt => '知道了';

  @override
  String get banReason => '封禁原因';

  @override
  String get used => '已使用';

  @override
  String get sentAt => '发送于';

  @override
  String get pin => '置顶';

  @override
  String get unpin2 => '取消置顶';

  @override
  String get username => '用户名 *';

  @override
  String get reply => '回复';

  @override
  String get message2 => '消息…';

  @override
  String get unban => '解除封禁';

  @override
  String get online => '在线';

  @override
  String get edit => '编辑';

  @override
  String get inProgress => '进行中';

  @override
  String get ended => '已结束';

  @override
  String get location2 => '位置';

  @override
  String get alreadyViewed => '已查看';

  @override
  String get archived => '已归档';

  @override
  String get files => '文件';

  @override
  String get share => '分享';

  @override
  String get shareToConversation => '通过 Alanya 发送';

  @override
  String get sharedContentSent => '内容已发送';

  @override
  String sharedContentSentTo(int count) {
    return '内容已发送至 $count 个聊天';
  }

  @override
  String get unableToShareTheContent => '无法发送该内容';

  @override
  String get unableToShareTheMessage => '无法分享该消息';

  @override
  String get thisMessageCannotBeSharedRight => '该消息暂时无法分享';

  @override
  String get document => '文件';

  @override
  String get activity => '动态';

  @override
  String get album => '📷 相册';

  @override
  String get answered => '已接听';

  @override
  String get upcoming => '即将开始';

  @override
  String get generate => '生成';

  @override
  String get audio => '🎵 音频';

  @override
  String get photo => '📷 照片';

  @override
  String get reply2 => '回复';

  @override
  String get deliveredAt => '送达于';

  @override
  String get gallery => '相册';

  @override
  String get meeting => '会议';

  @override
  String get next => '下一步';

  @override
  String get dismiss => '忽略';

  @override
  String get file2 => '文件';

  @override
  String get comingSoon => '即将推出';

  @override
  String get recent => '最近';

  @override
  String get label => '标签';

  @override
  String get invite => '邀请';

  @override
  String get ended2 => '已结束';

  @override
  String get video => '🎥 视频';

  @override
  String get contact2 => '联系人';

  @override
  String get leave => '退出';

  @override
  String get favorites => '收藏';

  @override
  String get gotIt2 => '知道了';

  @override
  String get edited2 => '已编辑';

  @override
  String get inactive => '未激活';

  @override
  String get add => '添加';

  @override
  String get member => '成员';

  @override
  String get success => '成功';

  @override
  String get ban => '封禁';

  @override
  String get past => '已结束';

  @override
  String get videos => '视频';

  @override
  String get copy => '复制';

  @override
  String get camera => '相机';

  @override
  String get photos => '照片';

  @override
  String get sending => '发送中…';

  @override
  String get blocked => '已屏蔽';

  @override
  String get added => '已添加';

  @override
  String get images => '图片';

  @override
  String get number => '号码';

  @override
  String get back => '返回';

  @override
  String get missed => '未接';

  @override
  String voicemailPeerUnavailable(String name) {
    return '$name 暂时无法接听';
  }

  @override
  String get voicemailLeaveMessage => '留下语音留言，对方会在你们的对话中收到。';

  @override
  String get voicemailRecord => '录音';

  @override
  String get voicemailSend => '发送';

  @override
  String get voicemailDiscard => '取消';

  @override
  String get voicemailNotNow => '暂不留言';

  @override
  String get voicemailSent => '留言已发送';

  @override
  String get voicemailBannerActive => '语音信箱已开启';

  @override
  String voicemailBannerUntil(String time) {
    return '语音信箱已开启，至 $time';
  }

  @override
  String get voicemailBannerDisable => '关闭';

  @override
  String get voicemailDisabled => '语音信箱已关闭';

  @override
  String get voicemailScheduleTitle => '语音信箱';

  @override
  String get voicemailEnabled => '定时语音信箱';

  @override
  String get voicemailEnabledSubtitle => '在这些时段内手机不会响铃，来电者可以留言';

  @override
  String voicemailTimezoneHint(String timezone) {
    return '按 $timezone 时区计算';
  }

  @override
  String get voicemailBypassTitle => '仍可联系到我';

  @override
  String get voicemailBypassTile => '允许的名单';

  @override
  String get voicemailBypassNobody => '无人';

  @override
  String get voicemailBypassHint => '该名单中的成员即使在语音信箱开启时也能让手机响铃。';

  @override
  String voicemailPeerNoAnswer(String name) {
    return '$name 没有接听';
  }

  @override
  String get voicemailGreetingPause => '停止播放';

  @override
  String get voicemailGreetingReplay => '再听一次';

  @override
  String get voicemailGreetingSection => '我的问候语';

  @override
  String get voicemailGreetingTitle => '录制你的问候语';

  @override
  String voicemailGreetingHint(int max) {
    return '转到语音信箱的来电者会听到它。最多 $max 秒。';
  }

  @override
  String get voicemailGreetingStop => '完成';

  @override
  String get voicemailGreetingSaved => '问候语已保存';

  @override
  String get voicemailGreetingNone => '没有问候语——将显示一段文字';

  @override
  String voicemailGreetingSet(int seconds) {
    return '已录制 $seconds 秒';
  }

  @override
  String get voicemailGreetingListen => '播放问候语';

  @override
  String get voicemailGreetingDelete => '删除问候语';

  @override
  String get voicemailGreetingDeleted => '问候语已删除';

  @override
  String get voicemailWhenNoAnswer => '当我没有接听时';

  @override
  String get voicemailAfterDelay => '30 秒后转语音信箱';

  @override
  String get voicemailAfterDelaySubtitle => '手机会响铃。如果你没有接听、拒接，或线路正忙，来电者可以留言。';

  @override
  String get voicemailWhenUnavailable => '当我无法接听时';

  @override
  String get voicemailSlotsEnabled => '定时时段';

  @override
  String get voicemailSlotsEnabledSubtitle => '在这些时段内手机完全不会响铃';

  @override
  String get voicemailSlotNone => '没有时段';

  @override
  String get voicemailSlotAllDay => '全天';

  @override
  String voicemailSlotOvernight(String range) {
    return '$range（延续至次日）';
  }

  @override
  String voicemailSlotsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 个定时时段',
    );
    return '$_temp0';
  }

  @override
  String get voicemailQuickHint => '请选择结束时间。每个选项都有结束时间——忘记关闭的语音信箱比不开更糟。';

  @override
  String get voicemailQuickSchedule => '设置定时时段';

  @override
  String get voicemailForOneHour => '1 小时';

  @override
  String get voicemailForFourHours => '4 小时';

  @override
  String get voicemailUntilMorning => '到明天早上';

  @override
  String get voicemailUntilCustom => '到指定日期';

  @override
  String get voicemailDeadlinePast => '该时间已过';

  @override
  String get voicemailCallStatus => '语音信箱';

  @override
  String get rejected => '已拒接';

  @override
  String get links => '链接';

  @override
  String get linkNoun => '链接';

  @override
  String get timeZoneLabel => '时区';

  @override
  String get email => '邮箱';

  @override
  String get create => '创建';

  @override
  String get name => '姓名 *';

  @override
  String get title => '标题';

  @override
  String get admin => '管理员';

  @override
  String get audio2 => '音频';

  @override
  String get playbackSpeed => '播放速度';

  @override
  String get playbackSpeedVoiceLabel => '语音消息';

  @override
  String get playbackSpeedVideoLabel => '视频';

  @override
  String get playbackSpeedMusicLabel => '音乐';

  @override
  String get music => '音乐';

  @override
  String musicPreview(String name) {
    return '🎵 $name';
  }

  @override
  String get active => '活跃';

  @override
  String get duration => '时长';

  @override
  String get failure => '失败';

  @override
  String get photo2 => '照片';

  @override
  String get copied => '已复制';

  @override
  String get video2 => '视频';

  @override
  String get theme => '主题';

  @override
  String get all => '全部';

  @override
  String get role => '角色';

  @override
  String get mute => '静音';

  @override
  String get readAt => '已读于';

  @override
  String get more => '更多';

  @override
  String get country => '国家/地区';

  @override
  String get name2 => '姓名';

  @override
  String get continueLabel => '继续';

  @override
  String get showLabel => '显示';

  @override
  String get hideLabel => '隐藏';

  @override
  String selectedCount(int count) {
    return '已选择 $count 项';
  }

  @override
  String participantsAdded(int count) {
    return '已添加 $count 位参与者';
  }

  @override
  String participantsInvited(int count) {
    return '已邀请 $count 位参与者';
  }

  @override
  String get accepted => '已接受';

  @override
  String get startAction => '开始';

  @override
  String get likeAction => '赞';

  @override
  String get incomingCallsChannel => '来电';

  @override
  String get ongoingCallsChannel => '通话中';

  @override
  String get viewsTitle => '查看';

  @override
  String get keypadTitle => '拨号键盘';

  @override
  String get clearAction => '清空';

  @override
  String get scheduleAction => '安排';

  @override
  String get archiveAction => '归档';

  @override
  String get markAsRead => '标为已读';

  @override
  String get infoAction => '详情';

  @override
  String get reportAction => '举报';

  @override
  String get reportMessageTitle => '举报此消息';

  @override
  String get reportUserTitle => '举报此账号';

  @override
  String get reportSubtitle => '您的举报将发送给 ALANYA 团队。对方不会收到通知。';

  @override
  String get reportReasonHarassment => '骚扰或欺凌';

  @override
  String get reportReasonHate => '仇恨言论';

  @override
  String get reportReasonViolence => '暴力或威胁';

  @override
  String get reportReasonSexual => '色情内容';

  @override
  String get reportReasonScam => '诈骗';

  @override
  String get reportReasonSpam => '垃圾信息';

  @override
  String get reportReasonImpersonation => '冒充他人';

  @override
  String get reportReasonOther => '其他';

  @override
  String get reportNoteHint => '补充说明（选填）';

  @override
  String get reportSubmit => '发送举报';

  @override
  String get reportSent => '举报已发送，谢谢。';

  @override
  String get reportFailed => '发送失败，请重试。';

  @override
  String get cannotPlaceCallCheckInternet => '无法发起通话，请检查网络连接后重试。';

  @override
  String get cannotPlaceCallServerFailed => '无法发起通话。连接服务器失败，请重试。';

  @override
  String get connectionRequired => '需要网络连接';

  @override
  String get callImpossible => '无法通话。';

  @override
  String get errorAcceptingCall => '接听通话时出错';

  @override
  String get userNotConnected => '用户未在线';

  @override
  String get mediaUnavailableForTransfer => '该媒体无法转发';

  @override
  String get invalidPositionForTransfer => '位置无效，无法转发';

  @override
  String get invalidContactForTransfer => '联系人无效，无法转发';

  @override
  String get photoViewOnce => '📷 照片 · 阅后即焚';

  @override
  String get videoViewOnce => '🎥 视频 · 阅后即焚';

  @override
  String get videoCallPreview => '📹 视频通话';

  @override
  String get voiceCallPreview => '📞 语音通话';

  @override
  String get deletePhotoAction => '删除照片';

  @override
  String get unavailableOffline => '离线状态下不可用';

  @override
  String get noParticipantsYet => '暂无参与者';

  @override
  String get noMessagesYet => '暂无消息';

  @override
  String get removeParticipantToAddAnother => '请先移除一位参与者，再添加新的。';

  @override
  String get noContactsYet => '暂无联系人';

  @override
  String get voiceMessage => '语音消息';

  @override
  String get paused => '已暂停';

  @override
  String get recordOrImportAudio => '录制语音或导入音频文件';

  @override
  String get tapToAddYourStatus => '点击发布您的动态';

  @override
  String get shareAContact => '分享联系人';

  @override
  String get searchAContact => '搜索联系人';

  @override
  String get unmuteMic => '取消静音';

  @override
  String get muteMic => '静音';

  @override
  String get turnOnSpeaker => '开启扬声器';

  @override
  String get notAuthenticated => '未登录';

  @override
  String get networkTimeout => '网络超时';

  @override
  String get networkError => '连接失败。请检查您的网络后重试。';

  @override
  String get noRefreshToken => '缺少刷新令牌';

  @override
  String get refreshFailed => '刷新失败';

  @override
  String addedToPreferredContacts(String name) {
    return '已将 $name 添加到常用联系人';
  }

  @override
  String get approximateGpsSlow => '位置为近似值（GPS 信号较弱）。';

  @override
  String get notYetRead => '尚未读取';

  @override
  String get sentOnTapSend => '已点击发送';

  @override
  String maxPhotos(int count) {
    return '最多 $count 张照片。';
  }

  @override
  String maxFiles(int count) {
    return '最多 $count 个文件。';
  }

  @override
  String get videoUnreadableOnDevice => '此手机无法播放该视频。';

  @override
  String compressingVideo(int percent) {
    return '正在压缩… $percent%';
  }

  @override
  String filesSkippedTooLarge(int count, int limit) {
    return '已跳过 $count 个文件：超出 $limit MB 上限。';
  }

  @override
  String maxMedias(int count) {
    return '最多 $count 个媒体文件。';
  }

  @override
  String get addMore => '添加';

  @override
  String get removeMedia => '移除';

  @override
  String get voiceViewOnce => '语音 · 阅后即焚';

  @override
  String get heCanContactYouAgain => '对方将可以重新联系您。';

  @override
  String unableToLoadNamed(String name) {
    return '无法加载 $name';
  }

  @override
  String get contactNotFound => '未找到该联系人';

  @override
  String get yesterday => '昨天';

  @override
  String get today => '今天';

  @override
  String get tomorrow => '明天';

  @override
  String get nowLabel => '现在';

  @override
  String get positionUnavailable => '位置不可用';

  @override
  String get contactUnavailable => '联系人不可用';

  @override
  String tapToViewKind(String kind) {
    return '$kind · 点击查看';
  }

  @override
  String kindViewOnce(String kind) {
    return '$kind · 阅后即焚';
  }

  @override
  String get viewOnceOpened => '已打开';

  @override
  String viewOnceDownloadKind(String kind) {
    return '$kind · 下载';
  }

  @override
  String get viewOnceDownloading => '下载中…';

  @override
  String get viewOnceRetry => '失败 — 重试';

  @override
  String get recordingEllipsis => '录制中…';

  @override
  String get unread => '未读';

  @override
  String get addAContact => '添加联系人';

  @override
  String meetingNamed(String when) {
    return '$when 的会议';
  }

  @override
  String get dataUnavailable => '数据不可用';

  @override
  String get sendCode => '发送验证码';

  @override
  String get unableToLoadCountryList => '无法加载国家/地区列表';

  @override
  String maxAudioParticipantsHint(int count) {
    return '最多 $count 位参与者（语音通话）。';
  }

  @override
  String membersOnlyCount(int count) {
    return '$count 位成员';
  }

  @override
  String sendWithCount(int count) {
    return '发送（$count）';
  }

  @override
  String messagesCountLabel(int count) {
    return '$count 条消息';
  }

  @override
  String messagesCountLabelOne(int count) {
    return '$count 条消息';
  }

  @override
  String deliveredAtTime(String time) {
    return '$time 送达';
  }

  @override
  String readAtTime(String time) {
    return '$time 已读';
  }

  @override
  String durationTapToReturn(String duration) {
    return '$duration · 点击返回';
  }

  @override
  String sessionBannerTapToReturn(String duration, String type) {
    return '$duration · $type · 点击返回';
  }

  @override
  String get usedLabel => '已使用';

  @override
  String limitReachedParticipants(int total, String media) {
    return '$media最多 $total 位参与者（含您本人）';
  }

  @override
  String get mediaLabelVideo => '视频通话';

  @override
  String get mediaLabelAudio => '语音通话';

  @override
  String activeStatusesTapToView(int count) {
    return '$count 条进行中的动态 — 点击查看';
  }

  @override
  String viewsCountLabel(int count) {
    return '$count 次查看';
  }

  @override
  String dateAtTime(String date, String time) {
    return '$date $time';
  }

  @override
  String selectedFeminineCount(int count) {
    return '已选择 $count 项';
  }

  @override
  String selectionRatio(int count, int max) {
    return '已选择 $count/$max';
  }

  @override
  String get groupFallback => '群组';

  @override
  String get reservedPhoneSearchHelp =>
      '在管理列表中搜索，或输入完整号段（3 位、4 位，或 8 位 XXYYZZTT 格式）。号段可直接分配，无需先加入列表。';

  @override
  String get reservedPhoneOnlyHint =>
      '仅限 3 位或 4 位数字，或 8 位 XXYYZZTT 格式（例如 11 22 33 44）。这些形式不参与自动注册。';

  @override
  String messagesSummaryMulti(int totalMessages, int convCount) {
    return '$totalMessages 条消息 · $convCount 个聊天';
  }

  @override
  String messagesSummaryOne(int count) {
    return '$count 条新消息';
  }

  @override
  String messagesSummaryMany(int count) {
    return '$count 条新消息';
  }

  @override
  String dateAtTimeFull(int day, int month, int year, String time) {
    return '$year 年 $month 月 $day 日 $time';
  }

  @override
  String todayTimeShort(String time) {
    return '今天 $time';
  }

  @override
  String get albumCannotBeForwarded => '该相册无法转发';

  @override
  String userHashId(Object id) {
    return '用户 #$id';
  }

  @override
  String listWithCount(int count) {
    return '列表（$count）';
  }

  @override
  String get listLabel => '列表';

  @override
  String get filterLabel => '筛选';

  @override
  String get freePlural => '可用';

  @override
  String get assignAction => '分配';

  @override
  String get messagesChannelName => '消息';

  @override
  String get searchEllipsis => '搜索…';

  @override
  String get callNoun => '通话';

  @override
  String get allFilter => '全部';

  @override
  String get audioViewOnce => '🎵 音频 · 阅后即焚';

  @override
  String get mediaFallback => '媒体';

  @override
  String fileWithName(String name) {
    return '📎 $name';
  }

  @override
  String get groupsFilter => '群组';

  @override
  String participantsSelected(int count) {
    return '已选择 $count 位参与者';
  }

  @override
  String get waitingForParticipants => '等待参与者加入…';

  @override
  String participantsCount(int count) {
    return '$count 位参与者';
  }

  @override
  String durationParticipants(String duration, int count) {
    return '$duration · $count 位参与者';
  }

  @override
  String participantsRatio(int current, int max) {
    return '参与者（$current/$max）';
  }

  @override
  String confirmWithParticipants(String label, int count) {
    return '$label · $count 位参与者';
  }

  @override
  String dotParticipantsCount(int count) {
    return '· $count 位参与者';
  }

  @override
  String get text2 => '文字';

  @override
  String get publishAction => '发布';

  @override
  String get importAction => '导入';

  @override
  String get finishAction => '完成';

  @override
  String get recordAction => '录制';

  @override
  String get meLabel => '我';

  @override
  String selfChatTitle(String name) {
    return '$name（我）';
  }

  @override
  String get messageYourself => '给自己发消息';

  @override
  String get selfChatSubtitle => '笔记、提醒、文件';

  @override
  String get selfChatDeleteWarning => '您的所有笔记将被永久删除，且无法恢复。';

  @override
  String get cannotCallYourself => '无法呼叫自己';

  @override
  String get statusNoun => '动态';

  @override
  String get youLabel => '您';

  @override
  String get hostLabel => '主持人';

  @override
  String get guestLabel => '访客';

  @override
  String get chatLabel => '聊天';

  @override
  String get summaryLabel => '概要';

  @override
  String get typeLabel => '类型';

  @override
  String get accountLabel => '账号';

  @override
  String get adminDashboard => '管理后台';

  @override
  String get superAdmin => '超级管理员';

  @override
  String inMinutes(int mins) {
    return '$mins 分钟后';
  }

  @override
  String get participantFallback => '参与者';

  @override
  String get userFallback => '用户';

  @override
  String nameYouParen(String name) {
    return '$name（您）';
  }

  @override
  String get contactsLabel => '联系人';

  @override
  String get searchUserByNameOrUsername => '按姓名或用户名搜索用户';

  @override
  String get endMeetingAction => '结束';

  @override
  String hoursShort(int hours) {
    return '$hours 小时';
  }

  @override
  String hoursAndMinutesShort(int hours, int minutes) {
    return '$hours 小时 $minutes';
  }

  @override
  String get formatBold => '加粗';

  @override
  String get formatItalic => '斜体';

  @override
  String get formatUnderline => '下划线';

  @override
  String get formatStrikethrough => '删除线';

  @override
  String get formatHandwriting => '手写体';

  @override
  String get genderMale => '男';

  @override
  String get genderFemale => '女';

  @override
  String get avatarLabel => '头像';

  @override
  String get nameUsernamePasswordRequired => '姓名、用户名和密码为必填项';

  @override
  String get usersLabel => '用户';

  @override
  String get bannedUsers => '已封禁';

  @override
  String get bannedLabel => '已封禁';

  @override
  String get adminsLabel => '管理员';

  @override
  String get actionsLabel => '操作';

  @override
  String get conversationsLabel => '会话';

  @override
  String get totalLabel => '总计';

  @override
  String get commonBlock => '屏蔽';

  @override
  String get messageNoun => '消息';

  @override
  String get albumNoun => '相册';

  @override
  String get favoriteSingular => '收藏';

  @override
  String get hangUp => '挂断';

  @override
  String get viewAction => '查看';

  @override
  String invitationFrom(String name) {
    return '来自 $name 的邀请';
  }

  @override
  String get fileArchive => '压缩包';

  @override
  String get reservationLimitedTo3Or4OrXxyyzztt =>
      '仅可保留 3 位或 4 位号码，或 8 位 XXYYZZTT 格式（例如 11 22 33 44）';

  @override
  String get discussionFallback => '聊天';

  @override
  String get overviewSection => '概览';

  @override
  String rangeOfTotal(int from, int to, int total) {
    return '$from–$to，共 $total';
  }

  @override
  String get tryAnotherName => '请换一个名称试试。';

  @override
  String get tryAnotherSearchTerm => '请换一个关键词试试。';

  @override
  String andNOthers(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '…以及另外 $count 位',
    );
    return '$_temp0';
  }

  @override
  String get voiceCallOutgoing => '去电（语音）';

  @override
  String get voiceCallIncoming => '来电（语音）';

  @override
  String get videoCallOutgoing => '去电（视频）';

  @override
  String get videoCallIncoming => '来电（视频）';

  @override
  String reactionChipLabel(String emoji, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 个回应',
    );
    return '$emoji，$_temp0';
  }

  @override
  String get reactToMessage => '回应';

  @override
  String get moreReactions => '更多回应';

  @override
  String get settingsNotifications => '通知';

  @override
  String get settingsNotificationsSubtitle => '消息、通话、隐私';

  @override
  String get notifPrefsSectionAlerts => '提醒';

  @override
  String get notifPrefsSectionBehavior => '行为';

  @override
  String get notifPrefMessages => '私聊消息';

  @override
  String get notifPrefGroupMessages => '群组消息';

  @override
  String get notifPrefCalls => '通话';

  @override
  String get notifPrefMeetings => '会议';

  @override
  String get notifPrefStatusView => '动态查看';

  @override
  String get notifPrefBroadcasts => 'Alanya 公告';

  @override
  String get notifPrefSound => '声音';

  @override
  String get notifPrefVibration => '振动';

  @override
  String get notifPrefPreviewTitle => '锁屏预览';

  @override
  String get notifPrefPreviewFull => '姓名 + 内容';

  @override
  String get notifPrefPreviewNameOnly => '仅姓名';

  @override
  String get notifPrefPreviewGeneric => '通用提示';

  @override
  String get notifPrefsSaveFailed => '无法保存通知偏好';

  @override
  String get convMuteAction => '通知';

  @override
  String get convMuteSubtitle => '关闭该会话的提醒';

  @override
  String convMuteTitle(String name) {
    return '通知 — $name';
  }

  @override
  String get convMute8h => '静音 8 小时';

  @override
  String get convMute1w => '静音 1 周';

  @override
  String get convMuteForever => '一直静音';

  @override
  String get convUnmute => '取消静音';

  @override
  String convMuteDone(String name) {
    return '已关闭 $name 的通知';
  }

  @override
  String convUnmuteDone(String name) {
    return '已开启 $name 的通知';
  }

  @override
  String get convMuteFailed => '无法更新静音设置';

  @override
  String sysGroupCreated(String actor, String value) {
    return '$actor 创建了群组“$value”';
  }

  @override
  String sysGroupCreatedByMe(String value) {
    return '您创建了群组“$value”';
  }

  @override
  String sysMemberAdded(String actor, String targets) {
    return '$actor 添加了 $targets';
  }

  @override
  String sysMemberAddedByMe(String targets) {
    return '您添加了 $targets';
  }

  @override
  String sysMemberRemoved(String actor, String targets) {
    return '$actor 移除了 $targets';
  }

  @override
  String sysMemberRemovedByMe(String targets) {
    return '您移除了 $targets';
  }

  @override
  String sysMemberLeft(String actor) {
    return '$actor 退出了群组';
  }

  @override
  String get sysMemberLeftByMe => '您退出了群组';

  @override
  String sysGroupRenamed(String actor, String value) {
    return '$actor 将群组名称改为“$value”';
  }

  @override
  String sysGroupRenamedByMe(String value) {
    return '您将群组名称改为“$value”';
  }

  @override
  String sysGroupPhotoChanged(String actor) {
    return '$actor 更换了群头像';
  }

  @override
  String get sysGroupPhotoChangedByMe => '您更换了群头像';

  @override
  String sysGroupDescriptionChanged(String actor) {
    return '$actor 修改了群简介';
  }

  @override
  String get sysGroupDescriptionChangedByMe => '您修改了群简介';

  @override
  String sysRolePromoted(String actor, String targets) {
    return '$actor 将 $targets 设为管理员';
  }

  @override
  String sysRolePromotedByMe(String targets) {
    return '您将 $targets 设为管理员';
  }

  @override
  String sysRoleDemoted(String actor, String targets) {
    return '$actor 取消了 $targets 的管理员身份';
  }

  @override
  String sysRoleDemotedByMe(String targets) {
    return '您取消了 $targets 的管理员身份';
  }

  @override
  String sysOnlyAdminsSendOn(String actor) {
    return '$actor 将发言权限限制为仅管理员';
  }

  @override
  String get sysOnlyAdminsSendOnByMe => '您将发言权限限制为仅管理员';

  @override
  String sysOnlyAdminsSendOff(String actor) {
    return '$actor 允许所有人发送消息';
  }

  @override
  String get sysOnlyAdminsSendOffByMe => '您允许所有人发送消息';

  @override
  String sysOnlyAdminsEditOn(String actor) {
    return '$actor 将群资料编辑权限限制为仅管理员';
  }

  @override
  String get sysOnlyAdminsEditOnByMe => '您将群资料编辑权限限制为仅管理员';

  @override
  String sysOnlyAdminsEditOff(String actor) {
    return '$actor 允许所有人编辑群资料';
  }

  @override
  String get sysOnlyAdminsEditOffByMe => '您允许所有人编辑群资料';

  @override
  String get sysGroupEventFallback => '群组信息已更新';

  @override
  String sysPreviewGroupCreated(String actor, String value) {
    return '$actor 创建了“$value”';
  }

  @override
  String sysPreviewGroupCreatedShort(String actor) {
    return '$actor 创建了群组';
  }

  @override
  String sysPreviewMemberAdded(String actor) {
    return '$actor 添加了成员';
  }

  @override
  String sysPreviewMemberRemoved(String actor) {
    return '$actor 移除了成员';
  }

  @override
  String sysPreviewMemberLeft(String actor) {
    return '$actor 退出了群组';
  }

  @override
  String sysPreviewGroupRenamed(String actor) {
    return '$actor 修改了群组名称';
  }

  @override
  String sysPreviewGroupPhotoChanged(String actor) {
    return '$actor 更换了群头像';
  }

  @override
  String sysPreviewGroupDescriptionChanged(String actor) {
    return '$actor 修改了群简介';
  }

  @override
  String sysPreviewRolePromoted(String actor) {
    return '$actor 设置了新的管理员';
  }

  @override
  String sysPreviewRoleDemoted(String actor) {
    return '$actor 取消了管理员权限';
  }

  @override
  String sysPreviewSettingsChanged(String actor) {
    return '$actor 修改了群设置';
  }

  @override
  String get groupOwner => '群主';

  @override
  String get groupAdmin => '管理员';

  @override
  String get removeFromGroup => '移出群组';

  @override
  String removeMemberConfirm(String name) {
    return '将 $name 移出群组？';
  }

  @override
  String removeMemberDone(String name) {
    return '$name 已被移出群组';
  }

  @override
  String get dismissAdmin => '取消管理员';

  @override
  String get viewProfile => '查看资料';

  @override
  String get groupDescription => '群简介';

  @override
  String get groupDescriptionHint => '添加群简介…';

  @override
  String get noGroupDescription => '暂无简介';

  @override
  String get renameGroup => '修改群名称';

  @override
  String get changeGroupPhoto => '更换群头像';

  @override
  String get groupSettings => '群设置';

  @override
  String get onlyAdminsCanSendLabel => '仅管理员可发送消息';

  @override
  String get onlyAdminsCanSendSubtitle => '将群组变为公告频道';

  @override
  String get onlyAdminsCanEditInfoLabel => '仅管理员可编辑群资料';

  @override
  String get onlyAdminsCanEditInfoSubtitle => '名称、头像和简介';

  @override
  String get hideHistoryForNewMembersLabel => '对新成员隐藏历史消息';

  @override
  String get hideHistoryForNewMembersSubtitle => '新成员看不到加入前发送的消息';

  @override
  String get onlyAdminsCanAddMembersLabel => '仅管理员可添加成员';

  @override
  String get onlyAdminsCanAddMembersSubtitle => '邀请新成员加入群组';

  @override
  String groupJoinBannerBody(String actor, String group) {
    return '$actor 将您加入了群组“$group”';
  }

  @override
  String get stay => '留在群里';

  @override
  String sysHideHistoryOn(String actor) {
    return '$actor 对新成员隐藏了历史消息';
  }

  @override
  String get sysHideHistoryOnByMe => '您对新成员隐藏了历史消息';

  @override
  String sysHideHistoryOff(String actor) {
    return '$actor 对新成员开放了历史消息';
  }

  @override
  String get sysHideHistoryOffByMe => '您对新成员开放了历史消息';

  @override
  String sysOnlyAdminsAddOn(String actor) {
    return '$actor 将添加成员权限限制为仅管理员';
  }

  @override
  String get sysOnlyAdminsAddOnByMe => '您将添加成员权限限制为仅管理员';

  @override
  String sysOnlyAdminsAddOff(String actor) {
    return '$actor 允许所有人添加成员';
  }

  @override
  String get sysOnlyAdminsAddOffByMe => '您允许所有人添加成员';

  @override
  String get mentionsOnlyLabel => '仅提醒 @我';

  @override
  String get mentionsOnlySubtitle => '只有被提及时才收到提醒';

  @override
  String get youWereRemovedFromGroup => '您已不在该群组中';

  @override
  String get notAllowedGroupAction => '没有权限执行此操作';

  @override
  String get ownerMustTransferOnLeave => '您是群主：群组将移交给加入时间最长的成员。';

  @override
  String get groupInfoUpdated => '群资料已更新';

  @override
  String get groupUpdateFailed => '无法更新该群组';

  @override
  String get announcementOnlyAdmins => '仅管理员可发送消息';

  @override
  String get officialAccountReadonlyBanner => '此账号用于发布公告，无法回复。';

  @override
  String get accountBadgeVerified => 'Alanya Plus 订阅用户';

  @override
  String get accountBadgeBusinessDeclared => '已申报企业';

  @override
  String get accountBadgeBusinessVerified => '已认证企业';

  @override
  String get accountBadgeOfficial => 'Alanya 官方账号';

  @override
  String get mentionAll => '@全体';

  @override
  String mentionAllSubtitle(int count) {
    return '提醒全部 $count 位成员';
  }

  @override
  String get mentionYou => '您';

  @override
  String get jumpToMention => '跳到下一条提及';

  @override
  String get unreadMessagesSeparator => '未读消息';

  @override
  String get signupEmailOptionalHint => '电子邮箱（可选）';

  @override
  String get signupEmailOptionalSubtitle => '仅用于找回密码';

  @override
  String get signupNoEmailWarningTitle => '未填写邮箱';

  @override
  String get signupNoEmailWarningBody => '没有邮箱，一旦忘记 Alanya ID 或密码，将无法找回账号。';

  @override
  String get signupAddEmail => '添加邮箱';

  @override
  String get signupContinueWithoutEmail => '继续';

  @override
  String get signupCredentialsNoEmailReminder =>
      '没有邮箱将无法找回账号。您可以随时在「我的 → 账号 → 编辑资料」中添加（需验证码验证）。';

  @override
  String get signupCredentialsEmailOk => '忘记密码时，可通过该邮箱重置。';

  @override
  String get emailLabel => '邮箱';

  @override
  String get emailNotSet => '未设置';

  @override
  String get emailNeededForRecovery => '找回密码所必需';

  @override
  String get emailMissingRecoveryBanner => '未填写邮箱：一旦忘记登录凭据，将无法找回账号。';

  @override
  String get accountSecurityTitle => '账号与安全';

  @override
  String get accountSecuritySubtitle => '邮箱和密码';

  @override
  String get changeEmailTitle => '电子邮箱';

  @override
  String get changeEmailSubtitleAdd => '添加邮箱地址，以便日后找回密码。';

  @override
  String get changeEmailSubtitleReplace => '验证码将发送至新的邮箱地址。';

  @override
  String get changeEmailCurrentLabel => '当前邮箱';

  @override
  String get changeEmailNewLabel => '新邮箱地址';

  @override
  String get changeEmailAddLabel => '您的邮箱地址';

  @override
  String get changeEmailStep1 => '1. 邮箱';

  @override
  String get changeEmailStep2 => '2. 验证';

  @override
  String get changeEmailWhyOtp => '为确认该邮箱属于您，我们将向其发送 6 位验证码。';

  @override
  String get changeEmailCheckInbox => '请打开邮箱并输入收到的验证码，也请查看垃圾邮件。';

  @override
  String get changeEmailEditAddress => '修改邮箱';

  @override
  String get changeEmailSendCode => '发送验证码';

  @override
  String get changeEmailOtpTitle => '验证码';

  @override
  String changeEmailOtpSubtitle(String email) {
    return '请输入发送至 $email 的验证码';
  }

  @override
  String get changeEmailResendCode => '重新发送验证码';

  @override
  String get changeEmailConfirm => '验证并保存';

  @override
  String get changeEmailSuccess => '邮箱地址已更新';

  @override
  String get changePasswordTitle => '修改密码';

  @override
  String get changePasswordSubtitle => '需要输入当前密码';

  @override
  String get changePasswordCurrent => '当前密码';

  @override
  String get changePasswordNew => '新密码';

  @override
  String get changePasswordConfirm => '确认新密码';

  @override
  String get changePasswordSubmit => '保存';

  @override
  String get changePasswordSuccess => '密码已更新';

  @override
  String get changePasswordSameAsCurrent => '新密码不能与当前密码相同';

  @override
  String get profileNoEmailChip => '添加邮箱以保护您的账号';

  @override
  String get addToCall => '加入通话';

  @override
  String get transferCall => '转接通话';

  @override
  String get transferCallSheetTitle => '转接通话';

  @override
  String get transferCallConfirmationTitle => '转接这通电话？';

  @override
  String get transferCallConfirmationBody => '对方将先加入通话，接通约 10 秒后您会自动退出。';

  @override
  String get addToCallConfirmBody => '邀请该联系人加入当前通话？';

  @override
  String get transferWaitingForParticipant => '等待接听…';

  @override
  String get transferWaitingForConnection => '连接中…';

  @override
  String get transferCountdown => '正在转接… 您即将退出通话。';

  @override
  String transferCountdownSeconds(int seconds) {
    return '转接中 · $seconds 秒';
  }

  @override
  String get transferCompleted => '通话已转接';

  @override
  String get mediaConnectionFailed => '媒体连接建立失败';

  @override
  String get conferenceTransferInviteBody => '希望将这通电话转接给您';

  @override
  String get confCallOfThree => '三方通话';

  @override
  String get confRinging => '呼叫中…';

  @override
  String confAddingInvitee(String name) {
    return '正在添加 $name';
  }

  @override
  String confSomeoneAdds(String who, String name) {
    return '$who 正在添加 $name';
  }

  @override
  String confJoinedCall(String name) {
    return '$name 已加入通话';
  }

  @override
  String confLeftCall(String name) {
    return '$name 已离开通话';
  }

  @override
  String confDeclined(String name) {
    return '$name 拒绝加入';
  }

  @override
  String confBusy(String name) {
    return '$name 正在通话中';
  }

  @override
  String confNoAnswer(String name) {
    return '$name 未接听';
  }

  @override
  String confNotJoined(String name) {
    return '$name 未加入通话';
  }

  @override
  String get confAddAlreadyUsed => '本次通话已添加过其他人';

  @override
  String confCannotAdd(String name) {
    return '无法添加 $name';
  }

  @override
  String get confAddFailed => '无法添加该联系人';

  @override
  String confInviteSubtitle(String name) {
    return '正在邀请您加入与 $name 的通话';
  }

  @override
  String get confAddSheetTitle => '加入通话';

  @override
  String get noContactsToAdd => '没有可添加的联系人';

  @override
  String get confAlreadyInCall => '已在通话中';

  @override
  String get confContactBusy => '通话中';

  @override
  String get confCancelInvite => '取消';

  @override
  String get qrMyCodeTitle => '我的二维码';

  @override
  String get qrMyCodeTabCode => '我的码';

  @override
  String get qrMyCodeTabScan => '扫码';

  @override
  String get qrMyCodeSubtitle => '让对方扫描此码，即可将您加为常用联系人。';

  @override
  String get qrMyCodeShare => '分享';

  @override
  String qrMyCodeExpiresIn(String time) {
    return '$time 后失效';
  }

  @override
  String get qrMyCodeValidityNote => '有效期 10 分钟，且仅限一人使用。新码会自动生成。';

  @override
  String get qrMyCodeNewCode => '生成新码';

  @override
  String get qrMyCodeShareValidity => '此码有效期 10 分钟，且仅限一人使用。';

  @override
  String get qrScanReturnTitle => '新联系人';

  @override
  String qrScanReturnBody(String name) {
    return '$name 通过您的二维码将您加为常用联系人。要回加对方吗？';
  }

  @override
  String get qrScanReturnAccept => '添加';

  @override
  String get qrScanReturnDecline => '暂不';

  @override
  String get qrScanReturnFailed => '无法添加该联系人';

  @override
  String qrScannedMutualInfo(String name) {
    return '$name 通过您的二维码添加了您';
  }

  @override
  String get qrNoteFieldHint => '添加备注（地点、场合…）';

  @override
  String get qrNoteSaved => '备注已保存';

  @override
  String get qrNoteFailed => '无法保存备注';

  @override
  String get qrContactsFilterAll => '全部';

  @override
  String get qrContactsFilterQr => '扫码添加';

  @override
  String get qrContactAddedViaQr => '通过二维码添加';

  @override
  String qrContactAddedViaQrOn(String date) {
    return '通过二维码添加 · $date';
  }

  @override
  String get qrMyCodeShareSheetTitle => '分享我的码';

  @override
  String get qrMyCodeShareLink => '分享链接';

  @override
  String get qrMyCodeShareLinkHint => '可点击的链接和 Alanya ID';

  @override
  String get qrMyCodeShareImage => '分享图片';

  @override
  String get qrMyCodeShareImageHint => '可扫描的名片';

  @override
  String qrMyCodeShareId(String id) {
    return '我的 Alanya ID：$id';
  }

  @override
  String get qrMyCodeRegenerate => '重新生成';

  @override
  String get qrMyCodeRegenerateConfirmTitle => '重新生成您的二维码？';

  @override
  String get qrMyCodeRegenerateConfirmBody => '旧码将立即失效。已保存旧码的人将无法再通过它添加您。';

  @override
  String get qrMyCodeRegenerateDone => '新码已生成';

  @override
  String qrMyCodeShareText(String name) {
    return '在 Alanya 上加我：我是 $name。';
  }

  @override
  String get qrScanTitle => '扫描二维码';

  @override
  String get qrScanEntryButton => '扫描二维码';

  @override
  String get qrScanInstruction => '对准对方的二维码';

  @override
  String get qrScanErrorUnreadable => '无法识别该码。请靠近一些后重试。';

  @override
  String get qrScanErrorUnknown => '该码已失效或无法识别。';

  @override
  String get qrScanOwnCode => '这是您自己的码。';

  @override
  String qrScanAddSuccess(String name) {
    return '已将 $name 加入常用联系人';
  }

  @override
  String qrScanAlreadyContact(String name) {
    return '$name 已在您的常用联系人中';
  }

  @override
  String get qrScanResultAdded => '已加入您的联系人';

  @override
  String get qrScanResultAlready => '已在您的联系人中';

  @override
  String get qrScanActionMessage => '发消息';

  @override
  String get qrScanActionDetails => '查看详情';

  @override
  String get qrScanUndo => '撤销';

  @override
  String qrScanUndone(String name) {
    return '已将 $name 从常用联系人中移除';
  }

  @override
  String get qrScanUndoFailed => '无法撤销此次添加';

  @override
  String get qrScanCameraDenied => 'Alanya 需要相机权限才能扫码。';

  @override
  String get qrScanOpenSettings => '打开设置';

  @override
  String get qrScanTorchOn => '打开手电筒';

  @override
  String get qrScanTorchOff => '关闭手电筒';

  @override
  String get qrScanImportImage => '导入图片';

  @override
  String get qrScanImportNoCode => '该图片中没有二维码。';

  @override
  String get qrScanImportNotAlanya => '该二维码不是 Alanya 的码。';

  @override
  String get qrScanImportFailed => '无法读取该图片。';

  @override
  String get qrLoginTitle => '扫码登录';

  @override
  String get qrLoginEntryButton => '使用二维码登录';

  @override
  String get qrLoginUsePassword => '使用密码登录';

  @override
  String get qrLoginExplanation => '在已登录的手机上打开 Alanya，进入「账号与安全」，然后扫描此码。';

  @override
  String get qrLoginDeviceNotTrustedNotice =>
      '此账户尚未识别这部手机。请用已登录的设备扫描此码。如果无法再使用该设备，请在登录页重置密码。';

  @override
  String qrLoginExpiresIn(String time) {
    return '$time 后失效';
  }

  @override
  String get qrLoginStatusWaiting => '等待扫码…';

  @override
  String get qrLoginStatusScanned => '已扫码。请在另一台设备上确认。';

  @override
  String get qrLoginStatusRejected => '另一台设备已拒绝本次登录。';

  @override
  String get qrLoginStatusExpired => '该码已失效。';

  @override
  String get qrLoginRegenerate => '生成新的二维码';

  @override
  String get qrLoginNetworkError => '无法连接。请检查网络后重试。';

  @override
  String get qrApproveTitle => '新的登录请求';

  @override
  String get qrApproveIntro => '以下设备刚刚扫描了该码：';

  @override
  String get qrApproveDeviceLabel => '设备（自报名称）';

  @override
  String get qrApprovePlatformLabel => '平台';

  @override
  String get qrApproveRequestedLabel => '请求时间';

  @override
  String get qrApproveIpLabel => 'IP 地址';

  @override
  String get qrApproveLocationLabel => '大致位置';

  @override
  String get qrApproveDeclaredNotice =>
      '名称和平台由请求设备自行声明，可能被伪造。只有 IP 地址由 Alanya 实际观测。';

  @override
  String get qrApproveSecurityWarning => '如果这不是您本人的操作，请拒绝并立即修改密码。';

  @override
  String get qrApproveReject => '拒绝';

  @override
  String get qrApproveConfirm => '确认';

  @override
  String get qrApproveDone => '设备已连接';

  @override
  String get qrApproveRejectDone => '已拒绝本次登录';

  @override
  String get qrApproveSessionExpired => '该请求已过期。请在另一台设备上显示新的二维码。';

  @override
  String get qrDevicesTitle => '已登录设备';

  @override
  String get qrDevicesEntryTitle => '已登录设备';

  @override
  String get qrDevicesEntrySubtitle => '查看您的账号在哪些设备上登录';

  @override
  String get qrLinkDeviceTitle => '关联新设备';

  @override
  String get qrLinkDeviceSubtitle => '扫描另一台设备上显示的二维码';

  @override
  String get qrDevicesThisDevice => '当前设备';

  @override
  String get qrDevicesUnknownDevice => '未知设备';

  @override
  String get qrDevicesMethodPassword => '通过密码登录';

  @override
  String get qrDevicesMethodSignup => '注册设备';

  @override
  String get qrDevicesMethodQr => '通过二维码登录';

  @override
  String qrDevicesLastActive(String date) {
    return '$date 活跃';
  }

  @override
  String get qrDevicesRevoke => '退出登录';

  @override
  String get qrDevicesRevokeConfirmTitle => '让该设备退出登录？';

  @override
  String qrDevicesRevokeConfirmBody(String name) {
    return '$name 将立即退出登录。要在该设备上重新登录，需要输入密码。';
  }

  @override
  String get qrDevicesRevokeDone => '设备已退出登录';

  @override
  String get qrDevicesEmpty => '没有其他已登录设备';

  @override
  String get qrDevicesLoadError => '无法加载您的设备列表';

  @override
  String get qrDevicesIosNote =>
      '在 iPhone 上，重新安装 Alanya 后，同一台设备可能会作为新设备再次出现在此列表中。';

  @override
  String qrBannerNewDevice(String name) {
    return '新设备已连接：$name';
  }

  @override
  String get qrBannerSignedOutRemotely => '该设备已被另一台设备强制退出登录。';

  @override
  String get myAccountLabel => '我的账号';

  @override
  String get accountHubTitle => '我的账号';

  @override
  String get accountHubSecurityScore => '安全评分';

  @override
  String accountHubSecurityScoreValue(int score, int max) {
    return '$score / $max';
  }

  @override
  String get securityScoreAddEmail => '添加邮箱以提升评分。';

  @override
  String get securityScoreAddBiometric => '开启生物识别以提升评分。';

  @override
  String get accountHubSectionIdentity => '身份';

  @override
  String get accountHubSectionProtection => '保护';

  @override
  String get accountHubSectionData => '数据';

  @override
  String get accountHubEditProfile => '编辑资料';

  @override
  String get accountHubEditProfileSubtitle => '姓名、用户名、简介、头像';

  @override
  String get accountHubMyMedia => '我的媒体';

  @override
  String get accountHubPrivacy => '隐私';

  @override
  String get accountHubPrivacySubtitle => '可见性、屏蔽、已读回执';

  @override
  String get accountHubSecurity => '账号安全';

  @override
  String get accountHubSecuritySubtitle => '密码、设备、生物识别';

  @override
  String get accountHubDataAccount => '数据与账号';

  @override
  String get accountHubDataAccountSubtitle => 'GDPR 数据导出、账号注销';

  @override
  String get accountHubProfilePreview => '资料预览';

  @override
  String get accountHubProfilePreviewSubtitle => '查看联系人眼中的您';

  @override
  String get profileBioLabel => '个人简介';

  @override
  String get profileBioHint => '介绍一下自己（最多 500 字）';

  @override
  String get profilePreviewLink => '资料预览';

  @override
  String get myMediaTitle => '我的媒体';

  @override
  String get myMediaPlaceholder => '您分享过的照片和视频会显示在这里。';

  @override
  String get storageTitle => '存储与缓存';

  @override
  String get storageUsed => '已用空间';

  @override
  String get storageBreakdownTitle => '明细';

  @override
  String get storageMediaCache => '媒体缓存';

  @override
  String get storageDatabase => '数据库';

  @override
  String get storageTempFiles => '临时文件';

  @override
  String get storageOther => '其他数据';

  @override
  String get storageClearMediaCache => '清除媒体缓存';

  @override
  String get storageClearTemp => '清除临时文件';

  @override
  String get storageClearCacheConfirm =>
      '缓存文件将被删除。服务器上仍存在的媒体可以重新下载；较早的媒体将永久丢失。';

  @override
  String get storageClearCacheDone => '媒体缓存已清除';

  @override
  String get storageClearTempDone => '临时文件已清除';

  @override
  String get networkDataTitle => '网络与流量';

  @override
  String get networkDataSectionNetwork => '网络';

  @override
  String get networkWifiOnly => '仅在 Wi-Fi 下';

  @override
  String get networkWifiOnlySubtitle => '仅在 Wi-Fi 下下载媒体';

  @override
  String get networkDataSaver => '省流量模式';

  @override
  String get networkDataSaverSubtitle => '降低画质并减少自动下载';

  @override
  String get settingsSectionCommunication => '通讯';

  @override
  String get settingsSectionApplication => '应用';

  @override
  String get settingsSectionInformation => '信息';

  @override
  String get settingsStorage => '存储与缓存';

  @override
  String get settingsStorageSubtitle => '用量与清理';

  @override
  String get settingsNetwork => '网络与流量';

  @override
  String get settingsNetworkSubtitle => 'Wi-Fi 与省流量';

  @override
  String get settingsAccessibility => '无障碍';

  @override
  String get settingsAccessibilitySubtitle => '文字与动效';

  @override
  String get settingsAbout => '关于与法律条款';

  @override
  String get settingsMutedConversations => '已静音的会话';

  @override
  String get accessibilityTitle => '无障碍';

  @override
  String get accessibilitySectionDisplay => '显示';

  @override
  String get accessibilityFontScale => '文字大小';

  @override
  String get accessibilityFontScaleSmall => '小';

  @override
  String get accessibilityFontScaleDefault => '标准';

  @override
  String get accessibilityFontScaleMedium => '大';

  @override
  String get accessibilityFontScaleLarge => '特大';

  @override
  String get accessibilityReduceMotion => '减弱动效';

  @override
  String get accessibilityReduceMotionSubtitle => '减少过渡与视觉效果';

  @override
  String get accessibilitySaveFailed => '无法保存偏好设置';

  @override
  String get mutedConversationsTitle => '已静音的会话';

  @override
  String get mutedConversationsEmpty => '没有已静音的会话';

  @override
  String mutedConversationsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 个会话',
    );
    return '$_temp0';
  }

  @override
  String get mutedForeverLabel => '永久静音';

  @override
  String mutedUntilLabel(String date) {
    return '至 $date';
  }

  @override
  String get dndScheduleTitle => '勿扰模式';

  @override
  String get dndEnabled => '定时';

  @override
  String get dndEnabledSubtitle => '按时间段静音通知';

  @override
  String get dndScheduleHours => '时间';

  @override
  String get dndStartTime => '开始';

  @override
  String get dndEndTime => '结束';

  @override
  String get dndDays => '生效日';

  @override
  String get dndDayMon => '周一';

  @override
  String get dndDayTue => '周二';

  @override
  String get dndDayWed => '周三';

  @override
  String get dndDayThu => '周四';

  @override
  String get dndDayFri => '周五';

  @override
  String get dndDaySat => '周六';

  @override
  String get dndDaySun => '周日';

  @override
  String get dndSaveFailed => '无法保存定时设置';

  @override
  String get aboutTitle => '关于';

  @override
  String get aboutSectionLegal => '法律条款';

  @override
  String aboutVersion(String version, String build) {
    return '版本 $version（构建 $build）';
  }

  @override
  String get aboutTerms => '服务条款';

  @override
  String get aboutPrivacy => '隐私政策';

  @override
  String get aboutLicenses => '开源许可';

  @override
  String get aboutSupport => '联系客服';

  @override
  String get aboutCopyright => '© 2026 Alanya · 在雅温得用心打造';

  @override
  String get exportDataTitle => '数据与账号';

  @override
  String get exportSectionYourData => '您的数据';

  @override
  String get exportSectionDanger => '敏感操作';

  @override
  String get exportPhase1Title => '快速导出（GDPR）';

  @override
  String get exportPhase1Subtitle => '资料、联系人、元数据 — 立即可得';

  @override
  String get exportPhase2Title => '完整导出';

  @override
  String get exportPhase2Subtitle => '包含消息和媒体 — 约 24 小时后可得';

  @override
  String get exportRequestPhase1 => '立即导出';

  @override
  String get exportRequestPhase2 => '申请完整导出';

  @override
  String get exportPhase1ReadyTitle => '导出已就绪';

  @override
  String get exportPhase2Started => '已申请完整导出 — 完成后会通知您';

  @override
  String get exportInProgress => '导出进行中';

  @override
  String get exportInProgressHint => '约 24 小时后就绪 · 完成时通知';

  @override
  String get exportReady => '您的导出文件已就绪';

  @override
  String get exportDownload => '下载';

  @override
  String get deleteAccountTitle => '注销账号';

  @override
  String get deleteAccountEntrySubtitle => '此操作不可逆';

  @override
  String get deleteAccountStep1Title => '此操作不可逆';

  @override
  String get deleteAccountStep1Bullet1 => '消息和媒体将被删除';

  @override
  String get deleteAccountStep1Bullet2 => '将退出所有群组';

  @override
  String get deleteAccountStep1Bullet3 => '宽限期结束后释放您的号码';

  @override
  String get deleteAccountContinue => '继续';

  @override
  String get deleteAccountPassword => '密码';

  @override
  String get deleteAccountConfirmLabel => '请输入 DELETE';

  @override
  String get deleteAccountConfirmWord => 'DELETE';

  @override
  String get deleteAccountConfirmMismatch => '请输入 DELETE 以确认';

  @override
  String get deleteAccountSubmit => '注销我的账号';

  @override
  String get deleteAccountGraceTitle => '注销已安排';

  @override
  String deleteAccountGraceBody(String date) {
    return '您的账号将于 $date 被永久删除。在此之前可随时取消。';
  }

  @override
  String get biometricLock => '生物识别锁';

  @override
  String get biometricLockTitle => 'Alanya 已锁定';

  @override
  String get biometricLockUnlock => '解锁';

  @override
  String get biometricLockSubtitle => '打开应用时使用指纹或面容解锁';

  @override
  String get biometricLockEnableConfirm => '请验证指纹以启用锁定';

  @override
  String get biometricLockUnavailable => '该设备不支持生物识别';

  @override
  String get accountSecuritySectionProtection => '保护';

  @override
  String get logoutAllDevices => '退出所有设备';

  @override
  String get logoutAllDevicesSubtitle => '结束除本机外的所有会话';

  @override
  String get logoutAllDevicesConfirm => '其他所有设备将立即退出登录。';

  @override
  String get logoutAllDevicesAction => '退出登录';

  @override
  String get logoutAllDevicesDone => '其他设备已退出登录';

  @override
  String get logoutAllDevicesFailed => '无法让所有设备退出登录';

  @override
  String get privacySectionWhoCanSee => '谁可以看到我';

  @override
  String get privacySectionMessages => '消息';

  @override
  String get privacySectionLists => '名单与群组';

  @override
  String get privacyLastSeen => '最后在线时间';

  @override
  String get privacyOnlineStatus => '在线状态';

  @override
  String get privacyProfilePhoto => '头像';

  @override
  String get privacyReadReceipts => '已读回执';

  @override
  String get privacyReadReceiptsSubtitle => '发送并接收已读确认';

  @override
  String get privacyNotificationPreview => '通知预览';

  @override
  String get privacyBlockedContacts => '已屏蔽的联系人';

  @override
  String get privacyBlockedContactsEmpty => '没有已屏蔽的联系人';

  @override
  String privacyBlockedContactsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 位联系人',
    );
    return '$_temp0';
  }

  @override
  String get privacyAddToGroups => '被加入群组';

  @override
  String get privacyVisibilityEveryone => '所有人';

  @override
  String get privacyVisibilityContacts => '我的联系人';

  @override
  String get privacyVisibilityNobody => '任何人都不可';

  @override
  String get privacySaveFailed => '无法保存隐私设置';

  @override
  String get onboardingCredentialsTitle => '您的登录凭据';

  @override
  String get onboardingCredentialsSubtitle => '请妥善保管这些信息。';

  @override
  String get onboardingCredentialsBanner => '请记下您的 Alanya 号码和密码 — 它们不会再次显示。';

  @override
  String get onboardingProfileTitle => '您的资料';

  @override
  String get onboardingProfileSubtitle =>
      '头像、性别、年龄、国家/地区、简介：现在填写，或随时在「我的账号」中补充。';

  @override
  String get profileBioDefault => '你好，我在用 Alanya';

  @override
  String get onboardingPersonalizeTitle => '个性化 Alanya';

  @override
  String get onboardingPersonalizeSubtitle => '主题、语言和锁定。可随时在「设置」中修改。';

  @override
  String onboardingStepOf(int current, int total) {
    return '第 $current 步，共 $total 步';
  }

  @override
  String get onboardingCountryTitle => '您的国家/地区';

  @override
  String get onboardingCountrySubtitle => '便于联系人认出您。';

  @override
  String get onboardingPhotoTitle => '头像';

  @override
  String get onboardingPhotoSubtitle => '添加一张照片，或跳过此步骤。';

  @override
  String get onboardingPhotoChooseGallery => '从相册选择';

  @override
  String get onboardingPhotoCamera => '拍照';

  @override
  String get onboardingPhotoFailed => '无法添加照片';

  @override
  String get onboardingBioTitle => '简单介绍一下您';

  @override
  String get onboardingBioSubtitle => '用一句话介绍自己（可选）。';

  @override
  String get onboardingBioHint => '你好，我在用 Alanya';

  @override
  String get onboardingPreferencesTitle => '偏好设置';

  @override
  String get onboardingPreferencesSubtitle => '应用主题与语言。';

  @override
  String get onboardingThemeLabel => '主题';

  @override
  String get onboardingLanguageLabel => '语言';

  @override
  String get onboardingBiometricTitle => '保护访问';

  @override
  String get onboardingBiometricSubtitle => '每次回到应用时，一个动作即可解锁。';

  @override
  String get onboardingBiometricFriendlyTitle => '指纹或面容解锁';

  @override
  String get onboardingBiometricFriendlyBody => '开启快速解锁。可随时在「设置」中修改。';

  @override
  String get onboardingBiometricUnavailable => '该设备不支持生物识别 — 您可以稍后在设置中启用。';

  @override
  String get onboardingCompleteTitle => '一切就绪！';

  @override
  String get onboardingCompleteSubtitle => '您的账号已准备好。';

  @override
  String get onboardingCompleteMessage => '探索 Alanya，与在乎的人保持联系。';

  @override
  String get onboardingCompleteCta => '开始使用 Alanya';

  @override
  String get onboardingContinue => '继续';

  @override
  String get onboardingSkip => '跳过';

  @override
  String get onboardingSkipAll => '稍后设置';

  @override
  String get onboardingSkipAllTitle => '跳过设置？';

  @override
  String get onboardingSkipAllBody => '您可以随时在「我的账号」中完善资料。';

  @override
  String get onboardingSkipAllCredentialsBody =>
      '密码不会在此再次显示。您可以随时在「我的账号」中完善资料。';

  @override
  String get onboardingSkipAllRecoveryBody =>
      '密码不会在此再次显示，恢复码也只能在「我的账号 → 安全」中再次查看。请先记下它们。';

  @override
  String get onboardingSaveFailed => '保存失败 — 请重试或跳过此步骤。';

  @override
  String get onboardingCredentialsBannerNoEmail =>
      '请记下您的 Alanya 号码、密码和恢复码 — 它们不会在此再次显示。';

  @override
  String get onboardingPhotoAdd => '点击添加照片';

  @override
  String get onboardingIdentityTitle => '关于您';

  @override
  String get onboardingIdentitySubtitle => '性别和年龄一经保存便无法修改。';

  @override
  String get profileGenderLabel => '性别';

  @override
  String get profileIdentitySection => '身份';

  @override
  String get profileGenderSegmentPreferNotSay => '不愿透露';

  @override
  String get profileGenderMale => '男';

  @override
  String get profileGenderFemale => '女';

  @override
  String get profileGenderOther => '其他';

  @override
  String get profileGenderUnspecified => '不愿透露';

  @override
  String get profileAgeLabel => '年龄';

  @override
  String get profileAgeSuffix => '岁';

  @override
  String profileAgeBirthYear(int year) {
    return '出生年份 ≈ $year';
  }

  @override
  String profileAgeInvalid(int min, int max) {
    return '年龄无效（须在 $min 至 $max 之间）';
  }

  @override
  String get recoveryCodeTitle => '恢复码';

  @override
  String get recoveryCodeKeepSafe => '请妥善保管';

  @override
  String get recoveryCodeOnboardingHint =>
      '没有邮箱时，这串代码是您找回账号的唯一途径。请记在这台手机以外的地方。';

  @override
  String get recoveryCodeCopied => '恢复码已复制';

  @override
  String get recoveryCodeEntrySubtitle => '无需邮箱即可重置密码';

  @override
  String get recoveryCodeIntro => '该代码可在不使用邮箱的情况下重置密码。它永不改变，即使修改密码后也是如此。';

  @override
  String get recoveryCodeSecurityWarning =>
      '任何知道该代码和您 Alanya ID 的人都能修改您的密码。切勿分享。';

  @override
  String get recoveryCodeReveal => '显示代码';

  @override
  String get recoveryCodeHide => '隐藏';

  @override
  String get recoveryCodePasswordPrompt => '请输入密码以显示该代码。';

  @override
  String get recoveryCodeRevealFailed => '无法显示该代码';

  @override
  String get forgotMethodTitle => '找回您的账号';

  @override
  String get forgotMethodSubtitle => '您希望以何种方式继续？';

  @override
  String get forgotMethodEmail => '我有邮箱地址';

  @override
  String get forgotMethodEmailSubtitle => '通过邮件接收 6 位验证码。';

  @override
  String get forgotMethodCode => '我有恢复码';

  @override
  String get forgotMethodCodeSubtitle => '创建账号时显示的那串代码。';

  @override
  String get forgotCodeTitle => '您的恢复码';

  @override
  String get forgotCodeSubtitle => '请输入您的 Alanya ID 和注册时保存的恢复码。';

  @override
  String get forgotCodeHint => 'XXXX-XXXX-XXXX';

  @override
  String get forgotCodeSubmit => '验证代码';

  @override
  String get validatorRecoveryCode => '12 位恢复码';

  @override
  String deleteAccountGraceDays(int days) {
    return '宽限期 · $days 天';
  }

  @override
  String get deleteAccountCancelDeletion => '取消注销';

  @override
  String get deleteAccountCancelSuccess => '注销已取消';

  @override
  String get deleteAccountCancelFailed => '无法取消注销';

  @override
  String get deleteAccountLogoutNow => '退出登录';

  @override
  String get myMediaEmpty => '暂无分享过的媒体';

  @override
  String get myMediaLoadFailed => '无法加载您的媒体';

  @override
  String get bytesUnitB => '字节';

  @override
  String get bytesUnitKB => 'KB';

  @override
  String get bytesUnitMB => 'MB';

  @override
  String get bytesUnitGB => 'GB';

  @override
  String get myMediaSortRecent => '最近';

  @override
  String get myMediaSortLargest => '最大';

  @override
  String myMediaOnThisDevice(String size) {
    return '本机占用 $size';
  }

  @override
  String get myMediaFreeSpace => '释放空间';

  @override
  String get myMediaFreeSpaceConfirm => '将删除所选媒体在本机的副本。它们仍保留在聊天中，打开时会重新下载。';

  @override
  String get myMediaFreeSpaceConfirmMaybeGone =>
      '将删除所选媒体在本机的副本。它们仍保留在聊天中，但部分文件较旧：如果服务器上已不再保留，将无法重新获取。';

  @override
  String myMediaFreedSpace(String size) {
    return '已在本机释放 $size';
  }

  @override
  String get myMediaNothingCached => '这些媒体均未占用本机空间';

  @override
  String get myMediaForwardUnavailable => '这些媒体已不在本机的聊天记录中';

  @override
  String get myMediaSelectAll => '全选';

  @override
  String get myMediaFilterReceived => '已接收';

  @override
  String get myMediaFilterSent => '已发送';

  @override
  String get myMediaFilterAll => '全部';

  @override
  String myMediaFrom(String name) {
    return '来自 $name';
  }

  @override
  String get settingsBackup => '备份';

  @override
  String get settingsBackupSubtitle => '您的消息与设置，已加密';

  @override
  String get backupTitle => '备份';

  @override
  String get backupSubtitle => '您的消息与设置，已加密';

  @override
  String get backupFrequencyLabel => '频率';

  @override
  String get backupFrequencyDaily => '每天';

  @override
  String get backupFrequencyWeekly => '每周';

  @override
  String get backupFrequencyMonthly => '每月';

  @override
  String get backupFrequencyNever => '从不';

  @override
  String get backupLastNever => '尚无备份';

  @override
  String backupLastAt(String when, String size) {
    return '上次备份：$when · $size';
  }

  @override
  String backupCounts(int messages, int conversations) {
    return '$messages 条消息 · $conversations 个聊天';
  }

  @override
  String get backupRunNow => '立即备份';

  @override
  String get backupRunning => '正在备份…';

  @override
  String get backupSucceeded => '备份完成';

  @override
  String get backupAlreadyRunning => '备份正在进行中。';

  @override
  String get backupFailed => '备份失败';

  @override
  String get backupStaleWarning => '已数天没有成功备份。请检查网络和可用空间。';

  @override
  String get backupDestinationLabel => '备份位置';

  @override
  String backupDestinationDrive(String account) {
    return 'Google Drive $account';
  }

  @override
  String get backupDestinationDriveUnlinked => 'Google Drive — 本机未连接账号';

  @override
  String get backupDestinationDevice => '本机';

  @override
  String get backupChangeAccount => '更换 Google 账号';

  @override
  String get backupConnectDrive => '连接 Google Drive';

  @override
  String get backupUseDevice => '备份到本机';

  @override
  String get backupDriveConnected => '已连接 Google Drive。后续备份将保存在那里。';

  @override
  String get backupDriveRefused => '已取消 Google 登录，未做任何更改。';

  @override
  String get backupFellBack => '无法连接 Drive：备份已保存在本机。';

  @override
  String backupFellBackAt(String when) {
    return '无法连接 Drive。已于 $when 在本机创建备份。';
  }

  @override
  String get backupLocalRisksTitle => '本机备份';

  @override
  String get backupLocalRisksBody =>
      '您的备份保存在本机的“下载 › Alanya › Sauvegardes”中。\n\n✓ 重新安装 Alanya 后依然存在。\n✗ 手机丢失、被盗或损坏后将无法找回。\n✗ 设备被完全清除后将无法找回。\n\n如需将数据保存在手机之外，请连接 Google Drive。';

  @override
  String get backupWhatIsSaved => '备份内容：消息、聊天、联系人和设置。照片、视频和文件不包含在内。';

  @override
  String get backupNotEndToEnd => '备份已加密。Alanya 在技术上可以为您解密以便恢复；其他人则不能。';

  @override
  String get backupRestoreEntry => '恢复备份';

  @override
  String get backupRestoreEntryHint => '从 Google 云端硬盘或手机上的文件';

  @override
  String get restoreTitle => '恢复您的数据';

  @override
  String restoreFound(String when, String size) {
    return '找到 $when 的备份（$size）。';
  }

  @override
  String get restoreExplain => '您的消息和设置将被恢复。超过 30 天的照片和视频不会回来。';

  @override
  String get restoreAction => '恢复';

  @override
  String get restoreConnectGoogle => '连接到 Google 云端硬盘';

  @override
  String get restoreGoogleRefused => '已取消 Google 登录';

  @override
  String get restoreGoogleEmpty => '此 Google 账号中没有备份';

  @override
  String get restoreFromDrive => '从 Google 云端硬盘恢复';

  @override
  String restoreDriveAccount(String account) {
    return '请使用账号 $account 登录。';
  }

  @override
  String get restoreNothingOnDevice => '此手机上没有备份。请连接 Google 云端硬盘，或选择备份文件。';

  @override
  String get restorePickFile => '选择备份文件';

  @override
  String get restorePickHint =>
      '如果没有显示您的备份（例如重装之后），请在“下载 › Alanya › Sauvegardes”中指定 .enc 文件。';

  @override
  String get restorePickCancelled => '未选择文件';

  @override
  String get restorePickWrongFile => '此文件不是 Alanya 备份';

  @override
  String get restoreSkip => '跳过并继续';

  @override
  String get restoreRunning => '正在恢复…';

  @override
  String get restoreCloseApp => '关闭 Alanya';

  @override
  String get restoreDoneRestart => '恢复已就绪。请关闭 Alanya 后重新打开：您的数据将在启动时就位。';

  @override
  String get restoreFailedMessage => '恢复失败。您可以在设置中重试。';

  @override
  String get restoreKeyUnknown => '此备份使用了我们不再识别的密钥。';

  @override
  String get restoreTooRecent => '此备份来自更新版本的 Alanya。请升级应用。';

  @override
  String get restoreInterrupted => '上次恢复被中断，将从头开始。';

  @override
  String get exportPeriodAction => '导出此时间段';

  @override
  String get exportSheetTitle => '导出此时间段';

  @override
  String exportSheetSummary(int count, String size) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 个项目 · $size',
      zero: '没有项目',
    );
    return '$_temp0';
  }

  @override
  String get exportSheetNothing => '没有符合筛选条件的媒体可导出';

  @override
  String exportMissingRecoverable(int count, String size) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 个缺失项目可恢复（$size）',
    );
    return '$_temp0';
  }

  @override
  String exportMissingRecoverableEstimate(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '最多可恢复 $count 个缺失项目',
    );
    return '$_temp0';
  }

  @override
  String get exportMissingEstimateHint => '无法联系服务器：其中部分项目可能已不存在。';

  @override
  String exportDoneWithMissing(String size, int missing) {
    return '存档已就绪：$size · $missing 个项目不可用';
  }

  @override
  String get exportMissingRecoverableHint => '勾选后，这些项目会在打包前下载。不勾选则不消耗移动数据。';

  @override
  String exportMissingLost(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 个项目在服务器上已不可用',
    );
    return '$_temp0';
  }

  @override
  String get exportMissingLostHint => '它们会在存档中标注，但内容已永久丢失。';

  @override
  String get exportDestinationShare => '分享';

  @override
  String get exportDestinationDownloads => '保存到下载';

  @override
  String get exportPhaseScanning => '正在清点…';

  @override
  String exportPhaseRecovering(int done, int total) {
    return '正在恢复 $done / $total';
  }

  @override
  String exportPhaseAssembling(int done, int total) {
    return '正在打包 $done / $total';
  }

  @override
  String exportDone(String size) {
    return '存档已就绪：$size';
  }

  @override
  String get exportFailedGeneric => '导出失败';

  @override
  String get exportNoSpace => '设备空间不足，无法创建此存档';

  @override
  String get exportSaveUnsupported => '此设备不支持该目标位置';

  @override
  String get exportSavedToDownloads => '存档已保存到 Downloads/Alanya';

  @override
  String get exportCancelled => '导出已取消';

  @override
  String get myMediaFilters => '筛选';

  @override
  String get myMediaFilterDiscussion => '聊天';

  @override
  String get myMediaAllDiscussions => '全部聊天';

  @override
  String get myMediaSearchDiscussion => '搜索聊天';

  @override
  String get myMediaFilterOrigin => '来源';

  @override
  String get myMediaFilterPeriod => '时间段';

  @override
  String get myMediaPeriodAny => '全部时间';

  @override
  String get myMediaPeriodStart => '开始';

  @override
  String get myMediaPeriodEnd => '结束';

  @override
  String get myMediaPeriodLast7 => '7 天';

  @override
  String get myMediaPeriodLast30 => '30 天';

  @override
  String get myMediaPeriodThisYear => '今年';

  @override
  String get myMediaPeriodClear => '清除时间段';

  @override
  String get myMediaKindAll => '全部';

  @override
  String get myMediaKindPhotos => '照片';

  @override
  String get myMediaKindVideos => '视频';

  @override
  String get myMediaKindAudio => '语音';

  @override
  String get myMediaKindFiles => '文件';

  @override
  String myMediaSummary(int count, String size) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 个项目 · $size',
      one: '1 个项目 · $size',
      zero: '没有项目',
    );
    return '$_temp0';
  }

  @override
  String get myMediaEmptyFiltered => '没有符合筛选条件的媒体';

  @override
  String get myMediaResetFilters => '重置筛选';

  @override
  String dndSummaryActive(String start, String end, String days) {
    return '$start – $end · $days';
  }

  @override
  String get dndSummaryInactive => '已关闭';

  @override
  String get exportPhase1ShareSubject => 'Alanya 数据导出（资料与元数据）';

  @override
  String get officialContactSupport => '联系客服';

  @override
  String get officialComingSoon => '即将推出';

  @override
  String get officialHelpAndFaq => '帮助与常见问题';

  @override
  String get officialHelpUnavailable => '无法打开帮助页面';

  @override
  String get listKindFamily => '家人';

  @override
  String get listKindFriends => '朋友';

  @override
  String get listKindWork => '工作';

  @override
  String get listKindTrust => '信任';

  @override
  String get contactLists => '联系人分组';

  @override
  String get contactListsManage => '管理';

  @override
  String get createList => '新建分组';

  @override
  String get listName => '分组名称';

  @override
  String get listNameHint => '家人、朋友、工作…';

  @override
  String get renameList => '重命名分组';

  @override
  String get deleteList => '删除分组';

  @override
  String deleteListConfirm(String name) {
    return '删除“$name”？您的联系人仍保留在常用联系人中。';
  }

  @override
  String get listColor => '标签颜色';

  @override
  String get listNameAlreadyExists => '已存在同名分组';

  @override
  String get listSaveFailed => '无法保存该分组，请重试。';

  @override
  String get listMembersUpdateFailed => '无法更新成员，请重试。';

  @override
  String listMembersCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 位成员',
    );
    return '$_temp0';
  }

  @override
  String listMembersCountLimited(int current, int limit) {
    return '$current/$limit 位成员';
  }

  @override
  String listMemberLimitReached(int limit) {
    return '该分组最多 $limit 位成员';
  }

  @override
  String get addToList => '添加成员';

  @override
  String get removeFromList => '移出分组';

  @override
  String get createGroupFromList => '创建群组';

  @override
  String get noLists => '暂无联系人分组';

  @override
  String get noListsHint => '把常用联系人分到家人、朋友、工作…';

  @override
  String get noListMembers => '该分组暂无成员';

  @override
  String get noContactToAddToList => '您的常用联系人都已在该分组中';

  @override
  String addMembersSelected(int count) {
    return '已选择 $count 位';
  }

  @override
  String get newList => '新建分组';

  @override
  String get contactListsHint => '分组只能包含已在常用联系人中的人。同一位联系人可以属于多个分组。';

  @override
  String get notInThisList => '常用联系人 — 不在该分组中';

  @override
  String createGroupNamed(String name) {
    return '创建群组“$name”';
  }

  @override
  String get manageLists => '管理分组';

  @override
  String get contactListsSheetSubtitle => '打开分组，或将其转为群组。';

  @override
  String get markAllAsRead => '全部标为已读';

  @override
  String markAllAsReadDone(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '已将 $count 个聊天标为已读',
    );
    return '$_temp0';
  }

  @override
  String get optionsAction => '选项';

  @override
  String get trips => '安心行程';

  @override
  String get tripsCircleEmptyTitle => '您的信任圈还是空的';

  @override
  String get tripsCircleEmptyBody => '最多选择五个人。只有他们能看到您的行程，且仅限您分享的那些。';

  @override
  String get tripsComposeCircle => '设置我的信任圈';

  @override
  String get tripsMyCircle => '我的信任圈';

  @override
  String get tripsNone => '当前没有进行中的行程。';

  @override
  String get tripsNew => '新建行程';

  @override
  String get tripsKindTaxi => '乘车';

  @override
  String get tripsKindTaxiHint => '一段车程，带预计到达时间';

  @override
  String get tripsKindWalk => '步行';

  @override
  String get tripsKindWalkHint => '一段步行，带预计到达时间';

  @override
  String get tripsKindMeeting => '步行';

  @override
  String get tripsKindMeetingHint => '一段步行，带预计到达时间';

  @override
  String get tripsArrivalIn => '预计到达';

  @override
  String tripsMinutes(int count) {
    return '$count 分钟';
  }

  @override
  String get tripsNoteLabel => '给信任圈的备注';

  @override
  String get tripsNoteHint => '黄色出租车，车牌 LT 4471';

  @override
  String get tripsStart => '开始分享';

  @override
  String tripsContract(int count, String eta, String alert) {
    return '您的 $count 位联系人将看到您的实时位置，直至 $eta。若到 $alert 仍未确认，他们会收到提醒并看到您最后已知的位置。';
  }

  @override
  String get tripsCircleFrozen =>
      '信任圈在「我的 › 联系人分组」中编辑，绝不在开始行程时更改。被加入或移出的人不会收到任何提示。';

  @override
  String get tripsInProgress => '行程进行中';

  @override
  String get tripsLive => '实时';

  @override
  String get tripsStale => '位置不可用';

  @override
  String get tripsAwaitingConfirm => '待确认到达';

  @override
  String get tripsAlerted => '提醒已发出';

  @override
  String tripsWatcherCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 人正在关注',
    );
    return '$_temp0';
  }

  @override
  String tripsWatcherFollowedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 人关注过',
    );
    return '$_temp0';
  }

  @override
  String tripsEtaAt(String time) {
    return '预计 $time 到达';
  }

  @override
  String get tripsAlreadyActive => '已有行程正在进行。';

  @override
  String get tripsStartFailed => '无法开始该行程。';

  @override
  String get tripsSosUnavailable => 'SOS 功能尚未开放。';

  @override
  String get tripsStop => '停止分享';

  @override
  String get tripsForegroundOnly => '离开 Alanya 后分享会暂停。到了预定时间，您的信任圈仍会收到提醒。';

  @override
  String tripsCardStarted(String name) {
    return '$name 开始了一段行程';
  }

  @override
  String get tripsCardStartedByMe => '您开始了一段行程';

  @override
  String tripsCardAwaiting(String name) {
    return '$name 本应已经到达';
  }

  @override
  String get tripsCardAwaitingByMe => '您本应已经到达';

  @override
  String tripsCardAlert(String name) {
    return '$name 未确认到达';
  }

  @override
  String get tripsCardAlertByMe => '您未确认到达';

  @override
  String tripsCardSos(String name) {
    return '$name 触发了 SOS';
  }

  @override
  String get tripsCardSosByMe => '您触发了 SOS';

  @override
  String tripsCardArrived(String name) {
    return '$name 已平安到达';
  }

  @override
  String get tripsCardArrivedByMe => '您已平安到达';

  @override
  String tripsCardStopped(String name) {
    return '$name 停止了分享';
  }

  @override
  String get tripsCardStoppedByMe => '您停止了分享';

  @override
  String get tripsCardFollow => '实时关注';

  @override
  String get tripsCardView => '查看';

  @override
  String get tripsCardSeePosition => '查看位置';

  @override
  String get tripsCardSeeLast => '查看最后已知位置';

  @override
  String get tripsCardFallback => '安心行程 — 请更新应用';

  @override
  String get tripsConfirmArrival => '我已平安到达';

  @override
  String tripsExtendBy(int count) {
    return '+$count 分钟';
  }

  @override
  String tripsExtended(int count) {
    return '已延长 $count 分钟。您的信任圈已收到通知。';
  }

  @override
  String get tripsAlreadyClosed => '该行程已结束。';

  @override
  String get tripsActionFailed => '操作暂时失败。';

  @override
  String get tripsHistory => '历史记录';

  @override
  String get tripsHistoryEmpty => '暂无行程';

  @override
  String get tripsHistoryEmptyBody => '分享行程后，它会出现在这里 — 也只在这里。';

  @override
  String get tripsHistoryUnavailable => '历史记录不可用';

  @override
  String get tripsHistoryOnline => '历史行程从网络获取：不会保存在本机上。';

  @override
  String get tripsRetentionNote => '行程保留十二个月。详细轨迹保留二十四小时 — 触发提醒后保留三十天。';

  @override
  String get tripsOutcomeConfirmed => '已确认到达';

  @override
  String get tripsOutcomeStopped => '行程已停止';

  @override
  String get tripsOutcomeAlert => '已触发提醒';

  @override
  String get tripsDeleteLocked => '该行程在触发提醒后保留三十天。此规则用于保护当事人。';

  @override
  String get loadMore => '加载更多';

  @override
  String get tripsFgsTitle => '安心行程进行中';

  @override
  String get tripsFgsBodyPlain => '正在与您的信任圈分享位置';

  @override
  String tripsFgsBody(String names) {
    return '正在分享给 $names';
  }

  @override
  String get tripsSosTitle => 'SOS';

  @override
  String get tripsSosHold => '点击触发 SOS';

  @override
  String get tripsSosHoldBody => '倒计时立即开始，发送前可以取消。';

  @override
  String get tripsSosNotEmergency => 'SOS 不会呼叫急救部门，它提醒的是您的信任圈。';

  @override
  String tripsSosSending(int count) {
    return '$count 秒后发送';
  }

  @override
  String get tripsSosSendingNow => '发送中…';

  @override
  String get tripsSosSendingNowBody => '您的信任圈稍后会收到提醒。';

  @override
  String get tripsSosSent => '您的信任圈已收到提醒';

  @override
  String get tripsSosDiscreet => '无声音，无振动。位置仍在持续分享。';

  @override
  String get tripsSosActive => '分享进行中';

  @override
  String get tripsSosActiveBody => '正在分享您的位置。无声音，无振动。';

  @override
  String get tripsSosTooMany => '过去 24 小时内 SOS 次数过多。';

  @override
  String get tripsSosFalseAlarm => '误触，我没事';

  @override
  String get tripsSosButton => '触发 SOS';

  @override
  String get tripsKeepsRunning => '即使锁屏，分享也会继续。会有一条通知提醒您，并可随时停止。';

  @override
  String get tripsDestination => '目的地';

  @override
  String get tripsDestinationOptional => '选择目的地（可选）';

  @override
  String get tripsDestinationRadius => '进入 100 米范围内即视为到达';

  @override
  String get tripsShort => '安心';

  @override
  String get tripsRailStart => '开始';

  @override
  String get tripsRailFollow => '关注';

  @override
  String get tripsRailConfirm => '确认';

  @override
  String get tripsRailClose => '关闭';

  @override
  String get tripsConfirmed => '到达已确认。您的信任圈已收到通知。';

  @override
  String get tripsDeleteTitle => '删除该行程？';

  @override
  String get tripsDeleteBody => '行程及其轨迹将被清除，且无法恢复。';

  @override
  String get tripsRecenter => '回到当前位置';

  @override
  String get tripsMapExpand => '全屏';

  @override
  String get tripsMapReduce => '退出全屏';

  @override
  String get tripsMapFitBounds => '同时显示位置与目的地';

  @override
  String get tripsDestinationSafetyNet => '设置目的地后，我们会在您抵达时请您确认 — 而不只是在预定时间。';

  @override
  String tripsDistanceM(int meters) {
    return '约 $meters 米';
  }

  @override
  String tripsDistanceKm(double km) {
    final intl.NumberFormat kmNumberFormat = intl.NumberFormat.compact(
      locale: localeName,
    );
    final String kmString = kmNumberFormat.format(km);

    return '约 $kmString 公里';
  }

  @override
  String tripsUpdatedAgo(String age) {
    return '$age前更新';
  }

  @override
  String get tripsPositionFrozen => '位置已冻结';

  @override
  String get tripsDeleteLockedHint => '触发提醒后保留 30 天';

  @override
  String tripsEventWatcherSeenGroup(int count) {
    return '$count 位联系人已查看';
  }

  @override
  String get tripsArrivalReachedTitle => '您到了吗？';

  @override
  String get tripsArrivalReachedBody => '您已在目的地停留一分钟。';

  @override
  String get tripsArrivalDueTitle => '确认您的到达';

  @override
  String tripsArrivalDueBody(String time) {
    return '若无回应，您的信任圈将于 $time 收到提醒，并看到您最后已知的位置。';
  }

  @override
  String get tripsArrivalDueBodyPlain => '若无回应，您的信任圈将收到提醒，并看到您最后已知的位置。';

  @override
  String get tripsArrivalLater => '还没到 — 倒计时继续';

  @override
  String get tripsDegradedPermission => '定位已关闭';

  @override
  String get tripsDegradedPermissionBody =>
      '您的信任圈已无法看到您的位置。截止时间依然有效：若您不确认，他们仍会收到提醒。';

  @override
  String get tripsDegradedStale => '位置不可用';

  @override
  String get tripsDegradedStaleBody => '可能在隧道、地下停车场或信号较弱处。这不是警报 — 倒计时继续。';

  @override
  String get tripsDegradedBattery => '电量不足';

  @override
  String get tripsDegradedBatteryBody => '定位频率已降低。若手机关机，将发送您最后的位置。';

  @override
  String get tripsDegradedFix => '去处理';

  @override
  String get locationSearchHint => '搜索地点或地址…';

  @override
  String get locationSearchEmpty => '没有结果。您仍可在地图上选点。';

  @override
  String get locationSearchUnavailable => '搜索不可用。请检查网络后重试。';

  @override
  String get locationPickerChooseDestination => '选择目的地';

  @override
  String get locationPickerUseDestination => '使用该目的地';

  @override
  String get locationUseMyPosition => '使用我的位置';

  @override
  String get locationPickerInstruction => '搜索、移动地图，或使用当前位置';

  @override
  String get mapCompassNorth => '恢复正北朝上';

  @override
  String tripsCardFalseAlarm(String name) {
    return '$name 说明是误触';
  }

  @override
  String get tripsCardFalseAlarmByMe => '您说明是误触';

  @override
  String get tripsSosFalseAlarmSent => '您的信任圈已知道您没事。';

  @override
  String get tripsCall => '拨打电话';

  @override
  String get tripsPermissionTitle => '允许访问位置';

  @override
  String get tripsPermissionBody => '若不允许，您的信任圈将看不到您在哪里。到达时间仍会照常监控。';

  @override
  String get tripsPermissionNever => 'Alanya 仅在您发起的行程期间使用位置。行程之前和之后都不会。';

  @override
  String get tripsPermissionAllow => '允许';

  @override
  String get tripsPermissionLater => '稍后';

  @override
  String sysTripAlert(String actor) {
    return '$actor 未确认到达 — 信任圈已收到提醒';
  }

  @override
  String get sysTripAlertByMe => '您未确认到达 — 您的信任圈已收到提醒';

  @override
  String sysTripSos(String actor) {
    return '$actor 触发了 SOS';
  }

  @override
  String get sysTripSosByMe => '您触发了 SOS';

  @override
  String get tripsPreviewActive => '🧭 行程进行中';

  @override
  String get tripsPreviewAwaiting => '🧭 待确认到达';

  @override
  String get tripsPreviewAlert => '🆘 行程提醒';

  @override
  String get tripsPreviewSos => '🆘 SOS';

  @override
  String get tripsPreviewConfirmed => '✅ 已平安到达';

  @override
  String get tripsPreviewStopped => '🧭 行程已停止';

  @override
  String get tripsPreviewFalseAlarm => '✅ 误触';

  @override
  String get tripsAlertChannelName => '行程提醒';

  @override
  String get tripsAlertChannelBody => '有联系人未确认到达，或触发了 SOS。此类提醒会突破静音模式。';

  @override
  String get tripsChannelName => '安心行程';

  @override
  String get tripsChannelBody => '您自己行程的到达确认提醒。';

  @override
  String tripsRevokeTitle(String name) {
    return '移除 $name？';
  }

  @override
  String get tripsRevokeBody => '对方将无法再看到您的位置和该行程状态。对方不会收到任何提示。';

  @override
  String get tripsRevokeAction => '移除';

  @override
  String get tripsWatchersNoneSeen => '还没有人打开';

  @override
  String tripsWatchersSeenCount(int seen, int total) {
    return '$total 人中已有 $seen 人查看';
  }

  @override
  String get tripsWatcherSeen => '已查看';

  @override
  String get tripsOtherDeviceTitle => '行程正在您的另一台设备上运行';

  @override
  String get tripsOtherDeviceBody => '只有一台设备发送位置，否则轨迹会在不同地点之间跳动。';

  @override
  String get tripsOtherDeviceTake => '改用本设备记录';

  @override
  String get tripsOtherDeviceKeep => '保持只读';

  @override
  String get tripsNoLongerShared => '该行程已不再与您分享';

  @override
  String get tripsNoLongerSharedBody => '它可能已结束，也可能您已被移除。不会提供更多信息。';

  @override
  String get tripsLiveEndedArrived => '已平安到达';

  @override
  String get tripsLiveEndedStopped => '分享已结束';

  @override
  String get tripsLiveEndedBody => '位置分享已结束。';

  @override
  String get tripsDetailTitle => '行程详情';

  @override
  String get tripsDetailTimeline => '时间线';

  @override
  String get tripsDetailNoEvents => '没有记录到任何事件。';

  @override
  String get tripsTraceExpired => '轨迹已过期';

  @override
  String get tripsTraceExpiredBody => '该行程的位置点已被清除。概要和时间线仍然可用。';

  @override
  String get tripsTraceUnavailable => '轨迹无法加载';

  @override
  String get tripsTraceUnavailableBody => '无法加载该行程的位置点。它们并未被删除，请重试。';

  @override
  String get tripsTraceEmpty => '没有位置记录';

  @override
  String get tripsTraceEmptyBody => '该行程期间没有记录任何位置。概要和时间线仍然可用。';

  @override
  String get tripsEventStarted => '已开始';

  @override
  String get tripsEventExtended => '已延长';

  @override
  String get tripsEventArrivalDetected => '检测到到达';

  @override
  String get tripsEventEtaDue => '已到预定时间';

  @override
  String get tripsEventAlerted => '提醒已发出';

  @override
  String get tripsEventClosed => '已结束';

  @override
  String get tripsEventSignalBack => '信号已恢复';

  @override
  String get tripsEventLowBattery => '电量不足';

  @override
  String get tripsEventWatcherSeen => '已被联系人查看';

  @override
  String get tripsEventWatcherRevoked => '关注者已移除';

  @override
  String get tripsEventDeviceTakeover => '已在另一台设备上接管';

  @override
  String get tripsUnreachable => '行程不可用';

  @override
  String get tripsUnreachableBody => '无法连接服务器，您的网络可能已断开。';

  @override
  String get tripsLeave => '停止关注';

  @override
  String get tripsLeaveTitle => '停止关注该行程？';

  @override
  String get tripsLeaveBody => '您将不再看到对方的位置，对方未确认到达时您也不会收到提醒。';

  @override
  String get translationSection => '翻译';

  @override
  String get autoTranslate => '自动翻译';

  @override
  String get autoTranslateDescription => '将收到的、非您阅读语言的消息翻译过来。';

  @override
  String get onDeviceTranslationNotice => '翻译在您的设备上完成。不会有任何消息发送给第三方服务，且离线也能使用。';

  @override
  String get translateTo => '翻译成';

  @override
  String translatedFrom(String language) {
    return '译自$language';
  }

  @override
  String get showOriginal => '查看原文';

  @override
  String get showTranslation => '查看译文';

  @override
  String get translate => '翻译';

  @override
  String get translating => '翻译中…';

  @override
  String get translationFailed => '无法翻译';

  @override
  String get translationUnavailable => '该消息暂无可用翻译。';

  @override
  String get languageModels => '语言模型';

  @override
  String languageModelsDescription(int size) {
    return '每种语言约占用设备 $size MB 空间。';
  }

  @override
  String downloadLanguageModel(String language, int size) {
    return '下载$language（$size MB）以进行翻译';
  }

  @override
  String get downloadModel => '下载';

  @override
  String get deleteModel => '删除';

  @override
  String get modelBundled => '已内置于应用中';

  @override
  String downloadingModel(String language) {
    return '正在下载$language…';
  }

  @override
  String get modelDownloadFailed => '下载失败。请检查 Wi-Fi 连接。';

  @override
  String get modelDownloadWifiNotice => '下载走 Wi-Fi，以节省您的移动流量。';

  @override
  String get translateThisConversation => '翻译该会话';

  @override
  String get translateModeAuto => '自动';

  @override
  String get translateModeAlways => '始终翻译';

  @override
  String get translateModeNever => '从不翻译';

  @override
  String get translateModeAutoSubtitle => '跟随总体设置';

  @override
  String get errDelaiDepasse => '服务器响应超时。请重试。';

  @override
  String get errReseauSuspect => '无法建立安全连接。请检查您的网络。';

  @override
  String get errSessionExpiree => '您的会话已过期。请重新登录。';

  @override
  String get errIntrouvable => '未找到。此内容可能已被删除。';

  @override
  String get errConflit => '当前状态下无法执行此操作。';

  @override
  String get errTropDeRequetes => '尝试次数过多。请稍候。';

  @override
  String get errServeur => '服务暂时不可用。请重试。';

  @override
  String get errPermission => '权限被拒绝。请检查您的设备设置。';

  @override
  String get errPeripherique => '设备不可用或已被其他应用占用。';

  @override
  String get errStockage => '无法访问文件。请检查可用存储空间。';

  @override
  String get errGenerique => '发生错误。请重试。';

  @override
  String get errDomaineAuth => '登录失败。请重试。';

  @override
  String get errDomaineChat => '消息未发送。请重试。';

  @override
  String get errDomaineAppel => '通话未能接通。请重试。';

  @override
  String get errDomaineReunion => '无法打开会议。请重试。';

  @override
  String get errDomaineQr => '无法使用此二维码。请重试。';

  @override
  String get errDomaineMedia => '无法处理该文件。请重试。';

  @override
  String get errDomaineTrajet => '无法更新行程。请重试。';

  @override
  String get errDomaineStatut => '无法发布动态。请重试。';

  @override
  String get errDomaineProfil => '无法保存更改。请重试。';

  @override
  String get errDomaineAdmin => '操作失败。请重试。';

  @override
  String get errAppelHorsLigne => '无网络连接，无法拨打电话。';

  @override
  String get errChatHorsLigne => '消息已排队：网络恢复后将自动发送。';

  @override
  String get errMediaStockage => '无法保存。请检查设备的可用空间。';

  @override
  String get errCodeRefreshExpired => '您的会话已过期。请重新登录。';

  @override
  String get errCodeDeviceRevoked => '此设备已被登出。请重新登录。';

  @override
  String get errCodeAccountDeletionPending => '此账户正在删除中。';

  @override
  String get errCodeRegisterRateLimited => '注册尝试次数过多。请稍后再试。';

  @override
  String get errCodeInvalidCredentials => '账号或密码不正确。';

  @override
  String get errCodePasswordIncorrect => '密码不正确。';

  @override
  String get errCodeQrSessionExpired => '此二维码已过期。请重新生成。';

  @override
  String get errCodeDeviceNotOwner => '此设备无权执行该操作。';

  @override
  String get errCodeDeviceNotTrusted => '此账户尚未识别这部手机。请在已登录的设备上使用二维码登录。';

  @override
  String get errCodeAddAlreadyUsed => '此代码已被使用。';

  @override
  String get errCodeAddMePolicyDenied => '此用户不接受通过代码添加。';

  @override
  String get errCodeMeetingExpired => '此会议已过期。';

  @override
  String get errCodeMeetingEnded => '此会议已结束。';

  @override
  String get errCodeMeetingOrganiserRequired => '只有组织者才能执行此操作。';

  @override
  String get errCodeAccountAlreadyInMeeting => '该账户已在其他设备上参加此会议。';

  @override
  String get errCodeSessionBusy => '通话进行中。请先结束通话。';

  @override
  String get errCodeMaxDurationReached => '已达到最长时限。';

  @override
  String get errCodeBlockedBySender => '您无法联系此用户。';

  @override
  String get errCodeNotAMember => '您已不是该群组成员。';

  @override
  String get errCodeGroupAdminsOnly => '仅限群组管理员。';

  @override
  String get errCodeGroupOwnerRequired => '只有群主才能执行此操作。';

  @override
  String get errCodeConversationNotFound => '此会话已不存在。';

  @override
  String get errCodeOfficialReadonly => '此官方账户不接受回复。';

  @override
  String get errCodeListMemberLimit => '此列表已达到成员上限。';

  @override
  String get errCodeSystemListReadonly => '系统列表无法修改。';

  @override
  String get errCodeInviteBlocked => '无法邀请此用户。';

  @override
  String get errCodeBusinessOnly => '仅限企业账户。';

  @override
  String get errCodeTrustListEmpty => '您的信任名单为空。请先添加联系人。';

  @override
  String get errCodeTripAlreadyActive => '已有行程正在进行中。';

  @override
  String get errCodeTripTerminal => '此行程已结束。';

  @override
  String get errCodeTripStillOpen => '请先结束当前行程。';

  @override
  String get errCodeSosRateLimited => '警报已发送。请稍后再发送。';

  @override
  String get errCodeInvalidEta => '到达时间无效。';

  @override
  String get errCodeInvalidDestination => '目的地无效。';

  @override
  String get errCodeMediaExpired => '此媒体已过期，不再可用。';

  @override
  String get errCodeInvalidExtension => '不支持此文件类型。';

  @override
  String get errCodeInsufficientRole => '您没有执行此操作的权限。';

  @override
  String get errCodeFieldImmutable => '此字段无法再修改。';

  @override
  String get errAucuneAppPourFichier => '没有应用可以打开此文件。';

  @override
  String get plusBrand => 'Alanya Plus';

  @override
  String get plusFeatureTranslation => '翻译';

  @override
  String get plusFeatureBackup => '备份';

  @override
  String get plusFeatureTrips => '行程';

  @override
  String get plusFeatureRingtones => '铃声';

  @override
  String get plusFeatureStyle => '样式';

  @override
  String get plusFeatureBadge => '认证标记';

  @override
  String plusAmount(String amount) {
    return '$amount FCFA';
  }

  @override
  String get plusPerMonth => '/ 月';

  @override
  String get plusPerYear => '/ 年';

  @override
  String plusPerNMonths(int count) {
    return '/ $count 个月';
  }

  @override
  String get plusPlanMonthly => '月度';

  @override
  String get plusPlanYearly => '年度';

  @override
  String get plusRenew => '续订';

  @override
  String get plusResubscribe => '重新订阅';

  @override
  String get paywallFromLabel => '低至';

  @override
  String get paywallSeeOffer => '查看方案';

  @override
  String get paywallTranslationTitle => '翻译您的消息';

  @override
  String get paywallTranslationBody =>
      '翻译是 Alanya Plus 的一部分。它在您的手机上运行，即使离线也能使用，您的消息永远不会离开设备。';

  @override
  String get paywallBackupTitle => '备份您的聊天';

  @override
  String get paywallBackupBody =>
      '备份是 Alanya Plus 的一部分：加密保存在您的手机或 Drive 上。您现有的备份始终可以恢复。';

  @override
  String get paywallTripsTitle => '开始可信行程';

  @override
  String get paywallTripsBody =>
      '可信行程和 SOS 是 Alanya Plus 的一部分：您的亲友会跟随您的行程，如果您未能到达，他们会收到提醒。已开始的行程在结束前仍可使用 SOS。';

  @override
  String get paywallRingtonesTitle => '每个列表一种铃声';

  @override
  String get paywallRingtonesBody =>
      '列表铃声是 Alanya Plus 的一部分：无需看屏幕就能分辨家人、同事或朋友。';

  @override
  String get paywallGenericTitle => 'Alanya Plus 功能';

  @override
  String get paywallGenericBody => '此功能属于 Alanya Plus。';

  @override
  String get errCodeSubscriptionRequired => '此功能属于 Alanya Plus。';

  @override
  String get errCodeBillingNotActive => 'Alanya Plus 目前免费：无需付款。';

  @override
  String get errCodePaymentPending => '已有一笔付款正在等待您确认。';

  @override
  String get errCodeInvalidMsisdn => '此移动支付号码无效。';

  @override
  String get errCodeInvalidChannel => '不支持此付款方式。';

  @override
  String get errCodePlanNotFound => '此方案已不再提供。请重新加载。';

  @override
  String get errCodePaymentProviderError => '支付服务没有响应。请稍后重试。';

  @override
  String get errDomaineAbonnement => '您的订阅操作未能完成。';

  @override
  String plusCardGraceTitle(String date) {
    return '自 $date 起收费';
  }

  @override
  String plusCardGraceBody(String date) {
    return '在此之前，翻译、备份、行程和列表铃声仍然免费。现在订阅：您的第一个周期将于 $date 开始。';
  }

  @override
  String plusCardGraceDaysLeft(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '还剩 $count 天免费',
      zero: '最后一个免费日',
    );
    return '$_temp0';
  }

  @override
  String get plusCardUpgradeTitle => '升级到 Alanya Plus';

  @override
  String get plusCardDiscover => '了解方案';

  @override
  String plusCardActiveUntil(String date) {
    return '有效期至 $date';
  }

  @override
  String plusCardEndsOn(String date) {
    return '将于 $date 到期';
  }

  @override
  String plusCardEndsSoonBody(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '还剩 $count 天。续订以保留您的功能。',
      zero: '最后一天。续订以保留您的功能。',
    );
    return '$_temp0';
  }

  @override
  String get plusCardAutoRenewOn => '已开启自动续订。';

  @override
  String get plusCardAutoRenewOff => '请记得在到期前续订。';

  @override
  String get plusCardBadgeActive => 'Alanya Plus 订阅用户';

  @override
  String plusCardStartsOn(String date) {
    return '您的订阅将于 $date 开始';
  }

  @override
  String get plusCardScheduledBody => '在此之前，一切对您仍然免费。';

  @override
  String plusCardLapsedKicker(String date) {
    return '已于 $date 结束';
  }

  @override
  String get plusCardLapsedTitle => '您的 Plus 功能已暂停';

  @override
  String get plusCardLapsedBody => '您的设置已保留。重新订阅即可恢复全部功能，包括认证标记。';

  @override
  String get plusOfferUnlocks => 'Plus 解锁的功能';

  @override
  String get plusOfferUnavailable => '暂时无法付款。请稍后再试。';

  @override
  String get plusOfferDuration => '时长';

  @override
  String plusOfferContinue(String amount) {
    return '继续 — $amount';
  }

  @override
  String get plusOfferNoCommitment => '无需长期承诺';

  @override
  String plusOfferEquivalent(String amount) {
    return '相当于每月 $amount';
  }

  @override
  String plusOfferMonthsFree(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '赠送 $count 个月',
    );
    return '$_temp0';
  }

  @override
  String plusOfferFirstPeriod(String start, String end) {
    return '第一个周期：$start 至 $end。';
  }

  @override
  String plusOfferNextPeriod(String start, String end) {
    return '下一个周期：$start 至 $end，紧接当前周期。';
  }

  @override
  String get plusOfferNoRefund => '每个周期需预先支付，且不予退款。';

  @override
  String get checkoutTitle => '付款';

  @override
  String get checkoutPayWith => '付款方式';

  @override
  String get checkoutNumber => '扣款号码';

  @override
  String get checkoutNumberHint => '6XX XX XX XX';

  @override
  String get checkoutNumberInvalid => '请输入喀麦隆手机号码：以 6 开头的 9 位数字。';

  @override
  String get checkoutAutoRenew => '自动续订';

  @override
  String checkoutAutoRenewHint(String operator) {
    return '$operator 将在到期前一天请您确认。';
  }

  @override
  String get checkoutSimulated =>
      '模拟付款：不会扣除任何费用。号码以 01 结尾：余额不足 · 02：拒绝 · 03：无响应。';

  @override
  String checkoutPay(String amount) {
    return '支付 $amount';
  }

  @override
  String get checkoutWaitingTitle => '请在手机上确认';

  @override
  String checkoutWaitingBody(String operator, String amount) {
    return '输入您的 $operator 密码以确认支付 $amount。此页面会自动更新。';
  }

  @override
  String checkoutExpiresIn(String time) {
    return '请求将在 $time 后过期';
  }

  @override
  String get checkoutStepSent => '请求已发送';

  @override
  String checkoutStepSentTo(String number) {
    return '发送至 $number';
  }

  @override
  String get checkoutStepConfirm => '用密码确认';

  @override
  String get checkoutStepPending => '等待中';

  @override
  String get checkoutStepActivated => '订阅已激活';

  @override
  String checkoutStepActivatedHint(String operator) {
    return '$operator 回复后立即激活';
  }

  @override
  String get checkoutLeave => '离开此页面';

  @override
  String get checkoutLeaveHint => '即使您离开此页面，确认后订阅也会立即激活。';

  @override
  String get checkoutSuccessTitle => 'Alanya Plus 已激活';

  @override
  String checkoutSuccessBody(String plan, String start, String end) {
    return '$plan，$start 至 $end。';
  }

  @override
  String get checkoutSuccessScheduled => '在此之前，一切对您仍然免费。';

  @override
  String get checkoutSuccessFeatures => '翻译、备份、行程和列表铃声已开启。';

  @override
  String get checkoutSuccessFeaturesScheduled => '翻译、备份、行程和列表铃声将持续开启，不会中断。';

  @override
  String get checkoutDone => '完成';

  @override
  String get checkoutFailedTitle => '付款未成功';

  @override
  String get checkoutFailedInsufficient => '此移动支付账户余额不足。';

  @override
  String get checkoutFailedDeclined => '付款在手机上被拒绝。';

  @override
  String get checkoutFailedTimeout => '未能及时收到确认。您可以重试。';

  @override
  String get checkoutFailedGeneric => '付款失败。您可以重试。';

  @override
  String get subscriptionTitle => '我的订阅';

  @override
  String get subscriptionAutoRenew => '自动续订';

  @override
  String get subscriptionAutoRenewHint => '到期前一天，您的运营商会请您确认付款。';

  @override
  String get subscriptionNextDuration => '下次续订时长';

  @override
  String get subscriptionPayments => '付款记录';

  @override
  String get subscriptionPeriods => '订阅周期';

  @override
  String subscriptionRenewAmount(String amount) {
    return '续订 — $amount';
  }

  @override
  String get subscriptionNoPayments => '暂无付款记录。';

  @override
  String get subscriptionSourcePaid => '已付款';

  @override
  String get subscriptionSourceTrial => '试用';

  @override
  String get subscriptionSourceGift => '赠送';

  @override
  String get subscriptionSourceCompensation => '补偿';

  @override
  String subscriptionEndsIn(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 天后',
      zero: '今天',
    );
    return '$_temp0';
  }

  @override
  String get subscriptionNoneTitle => '暂无有效订阅';

  @override
  String get subscriptionNoneBody => 'Alanya Plus 可解锁翻译、备份、可信行程和列表铃声。';

  @override
  String get subscriptionExemptTitle => '您的账户已包含 Alanya Plus';

  @override
  String get paymentStatusSucceeded => '成功';

  @override
  String get paymentStatusFailed => '失败';

  @override
  String get paymentStatusExpired => '已过期';

  @override
  String get paymentStatusRefunded => '已退款';

  @override
  String get paymentStatusPending => '处理中';

  @override
  String get plusLockedTranslation => '未订阅时，翻译仅适用于与 Alanya Plus 联系人的对话。';

  @override
  String get plusLockedBackup => '新的备份为 Alanya Plus 专享功能。您现有的备份仍可恢复。';

  @override
  String get plusLockedRingtones => '列表铃声为 Alanya Plus 专享功能。您的设置已保留，订阅后即可恢复。';

  @override
  String get plusLockedTrips =>
      '新行程和行程外的 SOS 为 Alanya Plus 专享功能。已开始的行程在结束前仍可使用 SOS。';

  @override
  String plusCardLapsedBodyUntil(String date) {
    return '您的设置和历史记录将保留至 $date。在此之前重新订阅即可恢复全部功能，包括认证标记。';
  }

  @override
  String get plusCardPurgedBody => '您的 Plus 设置和历史记录已被删除。重新订阅即可恢复您的功能。';

  @override
  String get plusCardTrialKicker => '免费试用';

  @override
  String plusCardTrialTitle(String date) {
    return '免费至 $date';
  }

  @override
  String get plusCardTrialBody => '所有功能均已开放。之后您仍可接收消息和来电，但发送消息和拨打电话需要订阅。';

  @override
  String plusCardTrialDaysLeft(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '试用还剩 $count 天',
      zero: '试用最后一天',
    );
    return '$_temp0';
  }

  @override
  String get plusCardSubscribe => '订阅';

  @override
  String get plusCardRestrictedKicker => '试用已结束';

  @override
  String get plusCardRestrictedTitle => '您无法再发送消息或拨打电话';

  @override
  String get plusCardRestrictedBody => '您仍可接收消息和来电。订阅后即可再次发送消息和拨打电话。';

  @override
  String get plusCardLapsedTrialBody => '您仍可接收消息和来电。输入新的代码即可恢复。';

  @override
  String get plusCardRenewByCode => '续订需要一个新的代码。';

  @override
  String get plusCardScheduledTrialBody => '免费试用持续到那时，之后由订阅接替。';

  @override
  String get subscriptionSourceCode => '激活码';

  @override
  String get redeemTitle => '我有激活码';

  @override
  String get redeemIntro => '在网站付款后，您会收到一个代码。在此输入即可解锁全部功能一年。';

  @override
  String get redeemFieldLabel => '激活码';

  @override
  String get redeemFieldHint => 'XXXXX-XXXXX-XXXXX';

  @override
  String get redeemSubmit => '激活';

  @override
  String get redeemChecksumError => '这个代码似乎不正确，请检查每个字符。';

  @override
  String get redeemSuccessTitle => '订阅已激活';

  @override
  String redeemSuccessActive(String date) {
    return '您的订阅有效期至 $date。';
  }

  @override
  String redeemSuccessScheduled(String start, String end) {
    return '您的免费试用继续。订阅将于 $start 开始，持续至 $end。';
  }

  @override
  String get redeemDone => '完成';

  @override
  String get redeemPaste => '粘贴代码';

  @override
  String get composerSubscriptionRequired => '您的试用已结束：您仍可接收消息，但发送消息需要订阅。';

  @override
  String redeemLocked(int minutes) {
    return '尝试次数过多。请在 $minutes 分钟后重试。';
  }

  @override
  String get paywallOutgoingTitle => '订阅后继续使用';

  @override
  String get paywallOutgoingBody => '您的免费试用已结束。您仍可接收消息和来电，但发送消息和拨打电话需要订阅。';

  @override
  String get paywallTrialTitle => '订阅 Alanya';

  @override
  String get paywallTrialBody =>
      '一年的订阅将解锁全部功能：发送消息、拨打电话、翻译、备份和可信行程。在免费试用期内即可订阅：订阅将从试用结束时开始。';

  @override
  String get paywallPayOnline => '在线付款';

  @override
  String get paywallHaveCode => '我有激活码';

  @override
  String get paywallPayHint => '您将在我们的网站付款，然后收到一个代码，在此输入。';

  @override
  String get paywallPayUnavailable => '在线付款暂未开通。如果您有激活码，请输入。';

  @override
  String get paywallPayOpenFailed => '无法打开付款网站。';

  @override
  String get errCodeInvalidCode => '此代码不存在，请检查。';

  @override
  String get errCodeInvalidCodeFormat => '此代码输入有误，应为 15 个字符。';

  @override
  String get errCodeCodeAlreadyUsed => '此代码已被使用。';

  @override
  String get errCodeCodeExpired => '此代码已过期。';

  @override
  String get errCodeCodeRevoked => '此代码已被取消。';

  @override
  String get errCodeCodeLocked => '尝试次数过多，请几分钟后重试。';

  @override
  String get verificationTitle => '获取认证标记';

  @override
  String get verificationStatusTitle => '我的认证';

  @override
  String get verificationIntro => '认证标记告诉您的联系人，您确实是此账户名称所指的人。';

  @override
  String get verificationNameLabel => '待认证姓名';

  @override
  String get verificationNameHint => '这是您的个人资料姓名，必须与您的证件一致。';

  @override
  String get verificationToProvide => '需提供';

  @override
  String get verificationIdFront => '身份证件 — 正面';

  @override
  String get verificationIdFrontHint => '身份证、护照或驾照';

  @override
  String get verificationIdBack => '身份证件 — 背面';

  @override
  String get verificationIdBackHint => '如果证件有背面';

  @override
  String get verificationSelfie => '手持证件自拍';

  @override
  String get verificationSelfieHint => '面部和证件清晰可见';

  @override
  String get verificationTakePhoto => '拍照';

  @override
  String get verificationChooseGallery => '从相册选择';

  @override
  String get verificationRemove => '移除';

  @override
  String get verificationPrivacy => '您的证件已加密，仅管理团队可见，并在决定后 90 天删除。每次查看都会被记录。';

  @override
  String get verificationSubmit => '提交申请';

  @override
  String get verificationSendPieces => '发送证件';

  @override
  String get verificationPendingTitle => '认证审核中';

  @override
  String verificationPendingBody(String date) {
    return '$date 提交 · 5 个工作日内答复';
  }

  @override
  String get verificationStepSent => '申请已发送';

  @override
  String get verificationStepPieces => '证件已收到';

  @override
  String verificationPiecesCount(int count) {
    return '$count 份';
  }

  @override
  String get verificationStepReview => 'Alanya 审核';

  @override
  String get verificationStepInProgress => '进行中';

  @override
  String get verificationStepDecision => '决定';

  @override
  String get verificationStepDecisionHint => '我们会通知您';

  @override
  String get verificationPlusNotWaiting => '您的订阅已生效：Plus 功能无需等待审核结果。';

  @override
  String get verificationCancel => '取消申请';

  @override
  String get verificationCancelConfirm => '取消申请？您的证件将被删除。';

  @override
  String get verificationDocRequestedTitle => '您的申请缺少证件';

  @override
  String get verificationRefusedTitle => '申请被拒绝';

  @override
  String get verificationRevokedTitle => '认证标记已撤销';

  @override
  String verificationReason(String reason) {
    return '原因：$reason';
  }

  @override
  String get verificationResubmitHint => '您可以重新提交申请。';

  @override
  String get verificationRenamedTitle => '您的姓名已更改';

  @override
  String get verificationRenamedBody => '认证标记等待重新审核：请提交与显示姓名一致的证件，或恢复已认证的姓名。';

  @override
  String get verificationApprovedTitle => '身份已认证，标记已生效';

  @override
  String verificationApprovedUntil(String date) {
    return '它随您的订阅有效：至 $date。';
  }

  @override
  String get verificationApprovedFree => '认证标记显示在您的名字旁。';

  @override
  String get verificationPausedTitle => '身份已认证，标记已暂停';

  @override
  String get verificationPausedBody => '订阅恢复后标记即会恢复。';

  @override
  String get verificationUnavailableBody => '身份认证即将开放。请几天后再来。';

  @override
  String get plusCardBadgeMissing => '订阅后即可显示认证标记。';

  @override
  String get errCodeVerificationUnavailable => '身份认证尚未开放。';

  @override
  String get errCodeDocumentsRequired => '请添加您的身份证件和手持证件的自拍。';

  @override
  String get errCodeNameRequired => '请先在个人资料中填写姓名再申请认证。';

  @override
  String get errCodeVerificationAlreadyOpen => '已有申请正在审核中。';

  @override
  String get errCodeVerificationAlreadyApproved => '您的身份已以此姓名认证。';

  @override
  String get errCodeRequestNotPending => '此申请已发生变化。请刷新页面。';

  @override
  String get phoneChangeTitle => '选择我的号码';

  @override
  String get phoneChangeProduct => 'Alanya 号码';

  @override
  String get phoneChangeCurrent => '您当前的号码';

  @override
  String phoneChangeIntro(String amount) {
    return '选择一个更好记的 8 位号码，价格 $amount。它将替换您当前的号码，包括用于登录。';
  }

  @override
  String get phoneChangeFieldLabel => '想要的号码';

  @override
  String get phoneChangeCheck => '查询';

  @override
  String get phoneChangeMustBe8 => '请输入 8 位数字的号码。';

  @override
  String get phoneChangeAvailable => '可用';

  @override
  String get phoneChangeReasonSame => '这已经是您的号码。';

  @override
  String get phoneChangeReasonTaken => '该号码已被使用，请换一个。';

  @override
  String get phoneChangeReasonSetAside => '该号码由 Alanya 保留，请换一个。';

  @override
  String get phoneChangeReasonHeld => '有人正在选择该号码。请几分钟后再试，或换一个。';

  @override
  String get phoneChangeReasonQuarantine => '该号码刚被其持有人释放，暂不可用，请换一个。';

  @override
  String phoneChangeReserveAndPay(String amount) {
    return '预留并支付 $amount';
  }

  @override
  String get phoneChangeUseCredit => '确认此号码';

  @override
  String get phoneChangeCreditBanner => '您的更换已付款，但所选号码在此期间被占用。请另选一个，无需再次付款。';

  @override
  String phoneChangeHeldUntil(String phone, String time) {
    return '$phone 已为您预留至 $time。';
  }

  @override
  String get phoneChangeReleaseHold => '释放此号码';

  @override
  String phoneChangePending(String phone) {
    return '$phone 的付款正在进行中。';
  }

  @override
  String get phoneChangeSeeWaiting => '查看付款进度';

  @override
  String get phoneChangeLoginNote =>
      '更换后，请使用新号码登录。您的聊天、联系人和群组都会保留。您的旧号码不会立即分配给他人。';

  @override
  String get phoneChangeUnavailable => '暂时无法选择号码。';

  @override
  String phoneChangeSummaryHeld(String time) {
    return '为您预留至 $time';
  }

  @override
  String get phoneChangeStepApplied => '号码已更换';

  @override
  String get phoneChangeLeaveHint => '付款确认后您的号码即会更换，即使您离开此页面。';

  @override
  String get phoneChangeSuccessTitle => '这是您的新号码';

  @override
  String get phoneChangeSuccessBody => '今后请用它登录。您的聊天、联系人和群组都会保留。';

  @override
  String get phoneChangeCreditTitle => '付款已确认';

  @override
  String get phoneChangeCreditBody => '所选号码在此期间被占用。请另选一个，无需再次付款。';

  @override
  String get phoneChangeChooseAnother => '选择号码';

  @override
  String get errCodePhonePurchaseUnavailable => '暂不提供选择号码。';

  @override
  String get errCodeOfficialPhoneFixed => '此账户的号码无法更改。';

  @override
  String get errCodePhoneNotPurchasable => '只能选择 8 位数字的号码。';

  @override
  String get errCodePhoneUnavailable => '该号码已不可用，请换一个。';

  @override
  String get errCodePhoneHoldExpired => '该号码的预留已过期，请重新查询。';

  @override
  String get errCodePhoneOrderNotFound => '该预留已不存在，请重新开始。';

  @override
  String get errCodePhoneOrderPending => '已有一笔号码付款正在等待您确认。';

  @override
  String accountSecurityPhoneSubtitle(String amount) {
    return '更换为更好记的号码 · $amount';
  }

  @override
  String accountSecurityPhonePending(String phone) {
    return '正在更换为 $phone';
  }

  @override
  String get accountSecurityPhoneCredit => '更换已付款：请选择您的号码';

  @override
  String get receiptsTitle => '消息详情';

  @override
  String receiptsReadBy(int count) {
    return '$count 人已读';
  }

  @override
  String receiptsOutOf(int total) {
    return '/ 共 $total 人';
  }

  @override
  String receiptsDeliveredBy(int count) {
    return '$count 人已送达';
  }

  @override
  String receiptsPendingCount(int count) {
    return '$count 人未送达';
  }

  @override
  String get receiptsReadSection => '已读';

  @override
  String receiptsShowAllReaders(int count) {
    return '查看全部 $count 位读者';
  }

  @override
  String get receiptsDeliveredNotRead => '已送达，未读';

  @override
  String get receiptsNotDelivered => '尚未送达';

  @override
  String receiptsMemberCount(int count) {
    return '$count 位成员';
  }

  @override
  String get receiptsNoReaders => '还没有人读过';

  @override
  String get receiptsLoadError => '无法加载已读回执。';

  @override
  String receiptsBarLabel(int read, int delivered, int pending) {
    return '$read 人已读，$delivered 人已送达未读，$pending 人未送达';
  }

  @override
  String get stickerWord => '贴纸';

  @override
  String stickerPreview(String emoji) {
    return '$emoji 贴纸';
  }

  @override
  String get stickerRemoved => '贴纸已移除';

  @override
  String get stickerUnsupported => '不支持的贴纸，请更新应用';

  @override
  String get stickerTabEmojis => '表情';

  @override
  String get stickerTabStickers => '贴纸';

  @override
  String get stickerRecents => '最近';

  @override
  String get stickerFavorites => '收藏';

  @override
  String get stickerEmptyRecents => '最近使用的贴纸会显示在这里。';

  @override
  String get stickerEmptyFavorites => '在贴纸详情中点按 ★ 即可收藏。';

  @override
  String get stickerLoadError => '无法加载贴纸。';

  @override
  String get stickerRetry => '重试';

  @override
  String get stickerLockedBanner => '此贴纸包仅限 Alanya Plus。';

  @override
  String get stickerUnlockCta => '了解 Alanya Plus';

  @override
  String stickerLockedLabel(String name) {
    return '$name 贴纸包，已锁定';
  }

  @override
  String get stickerBadgeOfficial => '官方';

  @override
  String get stickerBadgePlus => 'Plus';

  @override
  String get stickerFavoriteAdd => '添加到收藏';

  @override
  String get stickerFavoriteRemove => '从收藏中移除';

  @override
  String get stickerViewPack => '查看贴纸包';

  @override
  String get stickerForward => '转发';

  @override
  String stickerSheetPack(String name) {
    return '贴纸包：$name';
  }

  @override
  String stickerSheetSender(String name) {
    return '发送者：$name';
  }

  @override
  String stickerSheetSize(int w, int h) {
    return '$w × $h 像素';
  }

  @override
  String stickerSheetWeight(String size) {
    return '大小：$size';
  }

  @override
  String get stickerAddPack => '添加';

  @override
  String get stickerRemovePack => '移除';

  @override
  String get stickerAdded => '已添加贴纸包。';

  @override
  String get stickerPackRemoved => '已移除贴纸包。';

  @override
  String get stickerMyPacks => '我的贴纸包';

  @override
  String get stickerCatalog => '目录';

  @override
  String get stickerManage => '管理贴纸';

  @override
  String stickerPackCount(int count) {
    return '$count 个贴纸';
  }

  @override
  String get stickerPackInstalled => '已安装';

  @override
  String get stickerSendLockedPlus => '此贴纸需要 Alanya Plus。';

  @override
  String get stickerDomainError => '贴纸暂时不可用。';

  @override
  String get errCodeStickerNotFound => '此贴纸已不存在。';

  @override
  String get errCodeStickerPackUnavailable => '此贴纸包已不可用。';

  @override
  String get errCodeStickerInvalidPayload => '无法发送此贴纸。';

  @override
  String get errCodeStickerAssetInvalid => '此图片无法用作贴纸。';

  @override
  String get errCodeStickerAssetBlocked => '此图片已被屏蔽，无法使用。';

  @override
  String get errCodeStickerQuotaExceeded => '您已达到 200 张贴纸的上限。';

  @override
  String get errCodeStickerPackLimit => '您已达到贴纸包数量或每包贴纸数量的上限。';

  @override
  String get plusFeatureStickers => 'Royal 贴纸';

  @override
  String get paywallStickersTitle => 'Royal 贴纸';

  @override
  String get paywallStickersBody => 'Royal 贴纸包属于 Alanya Plus：为您的聊天增添皇冠、奖杯和闪光。';

  @override
  String get stickerTrayLabel => '贴纸';

  @override
  String get stickerNoPacks => '尚未安装贴纸包。打开目录添加。';

  @override
  String get stickerPreviewTitle => '贴纸预览';

  @override
  String get stickerReplyQuote => '贴纸';

  @override
  String stickerSemantics(String emoji) {
    return '贴纸 $emoji';
  }

  @override
  String get stickerPackLockedSemantics => '已锁定，需要 Alanya Plus';

  @override
  String get stickerSendFailed => '无法发送贴纸。';

  @override
  String get stickerPackReorderHint => '长按并拖动以重新排序';

  @override
  String get stickerPackActions => '贴纸包操作';

  @override
  String get stickerMoveUp => '上移';

  @override
  String get stickerMoveDown => '下移';

  @override
  String get stickerNoFavorites => '暂无收藏';

  @override
  String get stickerOfficialPackName => '官方贴纸包';

  @override
  String get stickerTabInstalled => '已安装';

  @override
  String get stickerMyCreations => '我的创作';

  @override
  String get stickerCreatedEmpty => '您还没有创建贴纸包。点按 ＋ 开始。';

  @override
  String get stickerNewPack => '新建贴纸包';

  @override
  String get stickerPackNameLabel => '贴纸包名称';

  @override
  String get stickerDefaultPackName => '我的贴纸';

  @override
  String get stickerPrivacyTitle => '创建之前';

  @override
  String get stickerPrivacyBody => '发送的贴纸，收件人可以看到。';

  @override
  String get stickerPrivacyDetail => '您的贴纸包保持私密，但收到某张图片的任何人都可以查看它。';

  @override
  String get stickerPrivacyConfirm => '我知道了';

  @override
  String get stickerRename => '重命名';

  @override
  String get stickerDeletePack => '删除贴纸包';

  @override
  String get stickerDeletePackBody => '贴纸包将被删除，其分享链接将被撤销。已发送的贴纸可能显示为“贴纸已移除”。';

  @override
  String get stickerPackDeleted => '贴纸包已删除。';

  @override
  String get stickerAddFromGallery => '从相册添加';

  @override
  String get stickerAddedSticker => '贴纸已添加到贴纸包。';

  @override
  String get stickerAlreadyOwned => '这张图片已在您的贴纸中。';

  @override
  String get stickerRemoveFromPack => '从贴纸包中移除';

  @override
  String get stickerPackEmpty => '此贴纸包为空。请从相册添加图片。';

  @override
  String get stickerImageFormat => '无法读取该图片。请选择 JPEG、PNG 或 WebP 照片。';

  @override
  String get stickerImageTooBig => '图片超过 1 MB。';

  @override
  String get stickerImageSize => '图片必须正好是 512 × 512 像素。';

  @override
  String get stickerImageNoAlpha => '图片需要透明背景（带透明度的 PNG 或 WebP）。';

  @override
  String get stickerImageAnimated => '暂不支持动态图片（GIF、动态 WebP）。';

  @override
  String get stickerImageInputTooBig => '图片太大（最大 20 MB 或 5000 万像素）。';

  @override
  String get stickerPreviewHint => '图片会适配到 512 × 512 像素的方形中。棋盘格表示透明区域。';

  @override
  String get stickerPreviewAdd => '添加';

  @override
  String get stickerAddToPack => '添加到贴纸包';

  @override
  String get stickerChoosePack => '选择贴纸包';

  @override
  String get stickerCopiedToPack => '贴纸已添加到您的贴纸包。';

  @override
  String get stickerReport => '举报';

  @override
  String get stickerReportTitle => '为什么举报此贴纸？';

  @override
  String get stickerReportInappropriate => '不当内容';

  @override
  String get stickerReportSpam => '垃圾信息';

  @override
  String get stickerReportRights => '侵犯权利';

  @override
  String get stickerReportOther => '其他';

  @override
  String get stickerReported => '谢谢，您的举报已提交。';

  @override
  String get stickerReportedAlready => '您已举报过此贴纸。';

  @override
  String get stickerShareByLink => '通过链接分享';

  @override
  String get stickerShareRevoke => '撤销链接';

  @override
  String get stickerShareRevoked => '链接已撤销。';

  @override
  String get stickerShareRevokeBody => '链接将失效。已添加此贴纸包的人会保留各自的副本。';

  @override
  String get stickerShareEmpty => '分享前请至少添加一张贴纸。';

  @override
  String get stickerShared => '已分享';

  @override
  String stickerShareMessage(String name, String link, String code) {
    return '我在 Alanya 上的贴纸包“$name”：$link\n代码：$code';
  }

  @override
  String get stickerOpenLink => '打开贴纸包链接';

  @override
  String get stickerOpenLinkHint => '粘贴链接或代码';

  @override
  String get stickerOpenLinkInvalid => '此链接或代码不是贴纸包。';

  @override
  String get stickerSharedPackTitle => '分享的贴纸包';

  @override
  String get stickerShareInstall => '添加到我的贴纸包';

  @override
  String get stickerShareCopyInfo => '您将获得自己的副本：即使链接被撤销，它仍属于您。';

  @override
  String get stickerShareAlreadyAdded => '已添加';

  @override
  String get stickerShareMine => '这是您自己的贴纸包。';

  @override
  String get stickerShareDone => '贴纸包已添加到您的创作。';

  @override
  String stickerShareIgnored(int count) {
    return '已跳过 $count 张图片（被屏蔽或已移除）。';
  }

  @override
  String stickerCreatedCount(int count, int max) {
    return '$count/$max';
  }

  @override
  String get errCodeRateLimited => '请求过多。请一分钟后重试。';

  @override
  String get stickerSetCover => '设为封面';

  @override
  String get stickerPaste => '粘贴';

  @override
  String get stickerPreviewEdit => '编辑';

  @override
  String get mediaEditorTitleSticker => '编辑贴纸';

  @override
  String get mediaEditorTitlePhoto => '编辑图片';

  @override
  String get mediaEditorDone => '完成';

  @override
  String get mediaEditorUndo => '撤销';

  @override
  String get mediaEditorRedo => '重做';

  @override
  String get mediaEditorTools => '编辑工具';

  @override
  String get mediaEditorToolCrop => '裁剪';

  @override
  String get mediaEditorToolDraw => '画笔';

  @override
  String get mediaEditorToolText => '文字';

  @override
  String get mediaEditorToolEmoji => '表情';

  @override
  String get mediaEditorPen => '画笔';

  @override
  String get mediaEditorEraser => '橡皮擦';

  @override
  String get mediaEditorColor => '颜色';

  @override
  String get mediaEditorColorBlack => '黑色';

  @override
  String get mediaEditorColorWhite => '白色';

  @override
  String get mediaEditorColorRed => '红色';

  @override
  String get mediaEditorColorOrange => '橙色';

  @override
  String get mediaEditorColorGreen => '绿色';

  @override
  String get mediaEditorColorBlue => '蓝色';

  @override
  String get mediaEditorColorIndigo => '靛蓝';

  @override
  String get mediaEditorThickness => '笔画粗细';

  @override
  String get mediaEditorCropHintSticker => '双指缩放，拖动以在方框内移动图片。';

  @override
  String get mediaEditorCropHintPhoto => '双指缩放，拖动以在画框内移动图片。';

  @override
  String get mediaEditorFitContain => '适应';

  @override
  String get mediaEditorFitCover => '填满';

  @override
  String get mediaEditorAspectOriginal => '原始';

  @override
  String get mediaEditorAddText => '添加文字';

  @override
  String get mediaEditorEditText => '编辑文字';

  @override
  String get mediaEditorTextHint => '输入文字';

  @override
  String get mediaEditorFontStandard => '标准';

  @override
  String get mediaEditorFontBold => '粗体';

  @override
  String get mediaEditorFontHandwriting => '手写';

  @override
  String get mediaEditorAddEmoji => '添加表情';

  @override
  String get mediaEditorSize => '大小';

  @override
  String get mediaEditorRotation => '旋转';

  @override
  String get mediaEditorDeleteItem => '删除元素';

  @override
  String get mediaEditorCanvas => '图片编辑区域';

  @override
  String get mediaEditorDiscardTitle => '放弃修改？';

  @override
  String get mediaEditorDiscardBody => '您的修改将丢失。';

  @override
  String get mediaEditorKeepEditing => '继续编辑';

  @override
  String get mediaEditorDiscard => '放弃';

  @override
  String get mediaEditorExporting => '正在处理图片…';

  @override
  String get mediaEditorToolCutout => '抠图';

  @override
  String get mediaEditorCutoutHint => '自动抠图：仅限人物。其他内容请使用画笔。';

  @override
  String get mediaEditorCutoutAuto => '抠出人物';

  @override
  String get mediaEditorCutoutBusy => '正在抠图…';

  @override
  String get mediaEditorCutoutKeep => '保留';

  @override
  String get mediaEditorCutoutErase => '擦除';

  @override
  String get mediaEditorCutoutSize => '画笔大小';

  @override
  String get mediaEditorCutoutSoft => '柔和边缘';

  @override
  String get mediaEditorCutoutReset => '重置蒙版';

  @override
  String get mediaEditorCutoutNoPerson => '此图片中未检测到人物。请使用画笔抠图。';

  @override
  String get mediaEditorCutoutFailed => '自动抠图失败。请使用画笔抠图。';

  @override
  String stickerAnimatedSemantics(String emoji) {
    return '动态贴纸 $emoji';
  }

  @override
  String get stickerReplay => '重新播放动画';

  @override
  String get stickerOpenDetails => '查看贴纸详情';

  @override
  String get stickerBadgeAnimated => '动态';

  @override
  String get stickerAddAnimated => '添加动态贴纸';

  @override
  String get stickerAnimatedTitle => '动态贴纸';

  @override
  String get stickerAnimatedShape => '形状';

  @override
  String get stickerShapeCircle => '圆形';

  @override
  String get stickerShapeRounded => '圆角方形';

  @override
  String get stickerShapeSquare => '方形';

  @override
  String get stickerAnimatedHint =>
      '图片将被裁剪为正方形，时长限制在约 3 秒。在聊天中动画只播放一次，点按贴纸可重新播放。';

  @override
  String get stickerAnimatedPreviewLabel => '动态贴纸预览';

  @override
  String get stickerAnimatedConverting => '正在转换…';

  @override
  String get stickerAnimatedConvertingHint => '这可能需要十几秒。';

  @override
  String get stickerAnimatedAdded => '已添加动态贴纸。';

  @override
  String get stickerAnimatedNotAnimated => '该文件不是动态图。请选择 GIF 或动态 WebP。';

  @override
  String get stickerAnimatedFormat => '仅支持 GIF 和动态 WebP 文件。';

  @override
  String get stickerAnimatedTooBig => '该文件超过 3 MB。';

  @override
  String get stickerAnimatedInvalid => '该文件过大或不受支持。请尝试更短或更小的 GIF。';

  @override
  String get stickerAnimatedRateLimited => '您创建的动态贴纸过多。请稍后再试（每小时最多 10 个）。';

  @override
  String get stickerAnimatedBusy => '服务繁忙，请稍后再试。';

  @override
  String get stickerAnimatedClosed => '动态贴纸暂时不可用。';

  @override
  String get mediaEditorCropHintRound => '拖动并捏合来调整照片：它将显示在圆形框内。';

  @override
  String get mediaEditorEditFailed => '无法处理编辑后的照片，请重试。';

  @override
  String get stickerCreateTile => '创建';

  @override
  String get stickerCreateHint => '用相册中的照片制作贴纸。';

  @override
  String stickerCreatedInMyStickers(String name) {
    return '已添加到“$name”';
  }

  @override
  String get stickerView => '查看';

  @override
  String get chatPanelExpand => '展开面板';

  @override
  String get chatPanelCollapse => '收起面板';

  @override
  String get stickerVideoTitle => '视频贴纸';

  @override
  String get stickerVideoPreviewLabel => '裁剪后的视频预览';

  @override
  String get stickerVideoStart => '开始';

  @override
  String get stickerVideoDuration => '时长';

  @override
  String stickerVideoStartValue(String time) {
    return '开始：$time';
  }

  @override
  String stickerVideoDurationValue(String seconds) {
    return '时长：$seconds 秒';
  }

  @override
  String get stickerVideoPlay => '播放';

  @override
  String get stickerVideoPause => '暂停';

  @override
  String get stickerVideoHint =>
      '选择要保留的片段（最长 3 秒，最短 500 毫秒）。视频在我们的服务器上裁剪，不含声音。';

  @override
  String get stickerVideoTooBig => '此视频超过 20 MB，请选择更短的视频。';

  @override
  String get stickerVideoFormat => '不支持此格式，请选择 MP4、MOV 或 WebM 视频。';

  @override
  String get stickerVideoUnsupported => '暂不支持视频。';

  @override
  String get stickerVideoTooShort => '此视频太短（至少 500 毫秒）。';

  @override
  String get stickerVideoLoadFailed => '无法播放此视频。';

  @override
  String get stickerVideoConverting => '正在上传并转换视频…';

  @override
  String get stickerVideoConvertingHint => '使用移动数据时可能需要最多一分钟。';

  @override
  String get stickerVideoInvalid => '不支持此视频，或内容过于复杂。请尝试更短或更简单的视频。';

  @override
  String get mediaEditorToolFilters => '滤镜';

  @override
  String get mediaEditorBrushPen => '钢笔';

  @override
  String get mediaEditorBrushHighlighter => '荧光笔';

  @override
  String get mediaEditorBrushNeon => '霓虹';

  @override
  String get mediaEditorBrushBlur => '模糊';

  @override
  String get mediaEditorBlurHint => '用手指划过人脸或车牌即可模糊处理。';

  @override
  String get mediaEditorColorYellow => '黄色';

  @override
  String get mediaEditorColorPink => '粉色';

  @override
  String get mediaEditorRotate90 => '旋转';

  @override
  String get mediaEditorFlip => '镜像';

  @override
  String get mediaEditorReset => '重置';

  @override
  String get mediaEditorStraighten => '拉直';

  @override
  String get mediaEditorTabFilters => '滤镜';

  @override
  String get mediaEditorTabAdjust => '调整';

  @override
  String get mediaEditorIntensity => '强度';

  @override
  String get mediaEditorBrightness => '亮度';

  @override
  String get mediaEditorContrast => '对比度';

  @override
  String get mediaEditorSaturation => '饱和度';

  @override
  String get mediaEditorWarmth => '色温';

  @override
  String get mediaEditorFilterNone => '原图';

  @override
  String get mediaEditorFilterVivid => '鲜艳';

  @override
  String get mediaEditorFilterWarm => '暖色';

  @override
  String get mediaEditorFilterSoft => '柔和';

  @override
  String get mediaEditorFilterMono => '黑白';

  @override
  String get mediaEditorFilterNight => '夜晚';

  @override
  String get mediaEditorCompare => '按住查看原图';

  @override
  String get mediaEditorAlign => '文字对齐';

  @override
  String get mediaEditorTextBackground => '文字背景';

  @override
  String get mediaEditorItemHint => '拖动以移动，双指缩放或旋转。';

  @override
  String get mediaSendRemoveItem => '从发送中移除';

  @override
  String get mediaSendAddMore => '添加媒体';

  @override
  String get mediaSendUndoEdit => '撤销上次编辑';

  @override
  String get mediaSendViewOnceOn => '一次性查看已开启';

  @override
  String get mediaSendViewOnceOff => '一次性查看已关闭';

  @override
  String get mediaSendMute => '静音';

  @override
  String get mediaSendUnmute => '取消静音';

  @override
  String mediaSendEdits(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 处编辑',
    );
    return '$_temp0';
  }

  @override
  String mediaSendItemLabel(String kind, int index, int total) {
    return '第 $index 个$kind，共 $total 个';
  }

  @override
  String get cameraShutterHint => '轻点拍照，长按录像';

  @override
  String get cameraTakePhoto => '拍照';

  @override
  String get cameraStartRecording => '开始录像';

  @override
  String get cameraStopRecording => '停止录像';

  @override
  String get cameraFlash => '闪光灯';

  @override
  String get cameraOpenGallery => '打开相册';

  @override
  String get videoTrimStart => '视频开始';

  @override
  String get videoTrimEnd => '视频结束';

  @override
  String get videoRendering => '正在处理视频…';

  @override
  String get videoRenderFailed => '无法处理视频，请重试。';

  @override
  String get videoFrameFailed => '无法读取此视频进行编辑。';

  @override
  String videoTrimSummary(String range, String length, String total) {
    return '$range · $length（共 $total）';
  }

  @override
  String get errCodeDeleteWindowExpired => '仅可在发送后 72 小时内为所有人删除。';

  @override
  String get clearChatTitle => '清空聊天记录';

  @override
  String get clearChatAllMessages => '所有消息';

  @override
  String get clearChatMediaOnly => '仅媒体文件';

  @override
  String get clearChatAllHint => '聊天仍保留在您的列表中，其他参与者不会看到任何变化。';

  @override
  String get clearChatMediaHint => '消息保留，但会删除此设备上已下载的文件。';

  @override
  String clearChatButton(String size) {
    return '清空聊天记录（$size）';
  }

  @override
  String get clearChatButtonNoSize => '清空聊天记录';

  @override
  String get clearChatDone => '聊天记录已清空';

  @override
  String get clearChatMediaDone => '媒体文件已删除';

  @override
  String sysScreenshot(String actor) {
    return '$actor 对此聊天进行了截屏';
  }

  @override
  String get sysScreenshotByMe => '您对此聊天进行了截屏';

  @override
  String sysScreenRecording(String actor) {
    return '$actor 对此聊天进行了录屏';
  }

  @override
  String get sysScreenRecordingByMe => '您对此聊天进行了录屏';

  @override
  String get renameContactTitle => '联系人名称';

  @override
  String get renameContactHelper => '仅您可见。留空则恢复为个人资料名称。';

  @override
  String get contactProfileSection => '个人资料';

  @override
  String get contactProfileName => '姓名';

  @override
  String get contactProfilePseudo => '用户名';

  @override
  String get contactProfileNumber => 'Alanya 号码';

  @override
  String get contactYourNameSection => '您为此联系人设置的名称';

  @override
  String get contactYourNameNone => '无';

  @override
  String get contactYourNameAdd => '添加名称';

  @override
  String get contactYourNameEdit => '修改';

  @override
  String get contactYourNameClear => '清除名称';

  @override
  String get contactYourNameHelpSet => '仅您可见。它会在您的聊天、通话和通知中替换个人资料名称。';

  @override
  String get contactYourNameHelpEmpty => '用您选择的名称保存此联系人。对方永远看不到。';

  @override
  String get safeboxTitle => '保险箱';

  @override
  String get safeboxSubtitle => '您的重要文件，已加密并无限期保存';

  @override
  String get safeboxRootAlbums => '相册';

  @override
  String get safeboxRootPhotos => '照片';

  @override
  String get safeboxRootShare => '分享';

  @override
  String get safeboxAddToAlbum => '添加到相册';

  @override
  String get safeboxAddToAlbumHere => '添加到这里';

  @override
  String get safeboxAddedToAlbum => '已添加到相册';

  @override
  String safeboxAlsoIn(String place) {
    return '也在“$place”中';
  }

  @override
  String get safeboxDeleteWhich => '此文件也在保险箱的其他位置';

  @override
  String safeboxDeleteHereOnly(String place) {
    return '仅从“$place”移除';
  }

  @override
  String safeboxDeleteHereOnlyHint(String other) {
    return '它仍保留在“$other”中，不会释放空间。';
  }

  @override
  String get safeboxDeleteEverywhere => '从所有位置删除';

  @override
  String get safeboxDeleteEverywhereHint => '移至回收站；清空回收站后释放空间。';

  @override
  String get safeboxMoveToRoot => '移动到…';

  @override
  String get safeboxQualityTitle => '上传质量';

  @override
  String get safeboxQualityOriginal => '原始';

  @override
  String get safeboxQualityHd => '高清';

  @override
  String get safeboxQualityCompressed => '压缩';

  @override
  String get safeboxQualityOriginalHint => '保持原样，画质无损。';

  @override
  String safeboxQualityVideoPart(String res) {
    return '视频 $res';
  }

  @override
  String safeboxQualityPhotoPart(String px) {
    return '照片 $px 像素';
  }

  @override
  String safeboxQualityMusicPart(String kbps) {
    return '音乐 $kbps kbps';
  }

  @override
  String safeboxQualityTooLarge(String name, String size, String max) {
    return '“$name”将为 $size：超过每个文件 $max 的上限。';
  }

  @override
  String get safeboxQualityNote => '文档始终按原样发送。已经比所选格式更小的文件不会被修改。';

  @override
  String safeboxQualityFreeAfter(String size) {
    return '添加后：剩余 $size';
  }

  @override
  String safeboxQualityNoneFits(String max) {
    return '即使压缩后仍过大：每个文件上限为 $max。';
  }

  @override
  String safeboxQualityDowngraded(String quality) {
    return '按常用格式太大：将以$quality发送。';
  }

  @override
  String safeboxQualityTo(String destination) {
    return '到$destination';
  }

  @override
  String safeboxQualityAddCount(int count, String size) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '添加 $count 个文件 · ≈ $size',
    );
    return '$_temp0';
  }

  @override
  String safeboxQualitySendCount(int count, String size) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '发送 $count 个文件 · ≈ $size',
    );
    return '$_temp0';
  }

  @override
  String safeboxCountVideos(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 个视频',
    );
    return '$_temp0';
  }

  @override
  String safeboxCountPhotos(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 张照片',
    );
    return '$_temp0';
  }

  @override
  String safeboxCountAudios(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 个音频',
    );
    return '$_temp0';
  }

  @override
  String safeboxCountDocuments(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 个文档',
    );
    return '$_temp0';
  }

  @override
  String get safeboxHevcWarningTitle => 'H.265 视频';

  @override
  String get safeboxHevcWarningBody =>
      '部分成员可能无法播放此视频：它采用 H.265 格式，他们的手机无法读取。仍要发送吗？';

  @override
  String get safeboxHevcWarningSend => '仍然发送';

  @override
  String get safeboxTabTransfers => '传输';

  @override
  String get safeboxSpaceTitle => '已用空间';

  @override
  String safeboxPlanFree(String size) {
    return '免费 · $size';
  }

  @override
  String safeboxPlanPlus(String size) {
    return 'Alanya Plus · $size';
  }

  @override
  String safeboxQuotaOutOf(String total) {
    return '共 $total';
  }

  @override
  String get safeboxStatusSafe => '您的所有文件都很安全';

  @override
  String get safeboxStatusSafeHint => '没有等待上传的文件';

  @override
  String safeboxStatusWaiting(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 个文件等待网络',
    );
    return '$_temp0';
  }

  @override
  String safeboxStatusPaused(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 个上传已暂停',
    );
    return '$_temp0';
  }

  @override
  String safeboxStatusFailed(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 个上传失败',
    );
    return '$_temp0';
  }

  @override
  String get safeboxStatusOpen => '查看传输';

  @override
  String get safeboxMyFolders => '我的文件夹';

  @override
  String get safeboxRecentAlbums => '最近的相册';

  @override
  String get safeboxSeeAll => '查看全部';

  @override
  String safeboxAlbumItems(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 项',
    );
    return '$_temp0';
  }

  @override
  String get safeboxNewAlbum => '新建相册';

  @override
  String get safeboxAddTo => '添加到…';

  @override
  String get safeboxUploadsTab => '上传';

  @override
  String get safeboxDownloadsTab => '下载';

  @override
  String get safeboxPauseAll => '全部暂停';

  @override
  String get safeboxResumeAll => '全部继续';

  @override
  String get safeboxUploadPaused => '已暂停';

  @override
  String get safeboxPause => '暂停';

  @override
  String get safeboxResume => '继续';

  @override
  String get safeboxInProgress => '进行中';

  @override
  String get safeboxFinished => '已完成';

  @override
  String safeboxBytesOf(String done, String total) {
    return '$done / $total';
  }

  @override
  String get safeboxNoDownloads => '没有下载';

  @override
  String safeboxExportProgress(int done, int total) {
    return '$done/$total 个文件';
  }

  @override
  String get safeboxExportDoneGallery => '已存入相册“Alanya”';

  @override
  String get safeboxExportDoneZip => '已存入 下载/Alanya';

  @override
  String get safeboxExportFailed => '下载失败';

  @override
  String get safeboxExportCancelled => '已取消';

  @override
  String safeboxExportSkipped(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 个文件无法复制',
    );
    return '$_temp0';
  }

  @override
  String safeboxSelectedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '已选 $count 项',
    );
    return '$_temp0';
  }

  @override
  String get safeboxSelectAll => '全选';

  @override
  String get safeboxFilterAll => '全部';

  @override
  String get safeboxFilterWithNote => '有评论';

  @override
  String get safeboxDownload => '下载';

  @override
  String get safeboxDownloadWhat => '下载什么？';

  @override
  String get safeboxDownloadWhere => '保存到哪里？';

  @override
  String safeboxDownloadSelection(int count, String size) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '所选的 $count 个文件 · $size',
    );
    return '$_temp0';
  }

  @override
  String safeboxDownloadFolder(String name) {
    return '整个文件夹“$name”';
  }

  @override
  String get safeboxDownloadGallery => '手机相册';

  @override
  String get safeboxDownloadZip => 'ZIP 文件';

  @override
  String get safeboxDownloadGalleryHint =>
      '照片和视频存入相册“Alanya”；其他文件存入 下载/Alanya。';

  @override
  String get safeboxDownloadZipHint => '在 下载/Alanya 中生成一个文件。';

  @override
  String get safeboxDownloadDecryptHint => '文件在您的手机上解密。';

  @override
  String safeboxDownloadAction(String size) {
    return '下载 · $size';
  }

  @override
  String get safeboxDownloadStarted => '下载已开始：可在“传输”中查看。';

  @override
  String get safeboxDownloadFolderAction => '保存到手机';

  @override
  String get safeboxToday => '今天';

  @override
  String get safeboxYesterday => '昨天';

  @override
  String get safeboxSendAlbum => '发送相册';

  @override
  String get safeboxSendFolder => '发送文件夹';

  @override
  String safeboxFilesCount(int count) {
    return '$count 个文件';
  }

  @override
  String safeboxFoldersCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 个文件夹',
    );
    return '$_temp0';
  }

  @override
  String get safeboxUploadWaitingWifi => '等待 Wi-Fi';

  @override
  String get safeboxBackupTitle => '自动备份';

  @override
  String get safeboxBackupPitch => '照片、视频和文档自动复制到保险箱。手机上的文件不会被删除。';

  @override
  String get safeboxBackupActivate => '开启';

  @override
  String get safeboxBackupUpToDate => '已是最新';

  @override
  String safeboxBackupRemaining(int count) {
    return '$count 个文件待备份';
  }

  @override
  String safeboxBackupWaitingWifi(int count) {
    return '$count 个文件等待 Wi-Fi';
  }

  @override
  String get safeboxBackupUseMobile => '使用移动数据发送';

  @override
  String safeboxBackupWaitingCharge(int count) {
    return '$count 个文件等待充电时压缩';
  }

  @override
  String safeboxBackupSpaceFull(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '空间已满：$count 个文件等待空间',
      zero: '空间已满',
    );
    return '$_temp0';
  }

  @override
  String get safeboxBackupNoAccess => '照片访问被拒绝';

  @override
  String get safeboxBackupAllow => '允许';

  @override
  String get safeboxBackupLimited => '仅可访问部分照片';

  @override
  String get safeboxBackupWiden => '扩大访问权限';

  @override
  String get safeboxBackupPermissionTitle => '允许访问您的照片、视频和音乐';

  @override
  String get safeboxBackupPermissionBody =>
      '保险箱以加密方式单向复制您的文件：手机上的文件不会被删除，您从保险箱删除的内容也不会再次备份。';

  @override
  String get safeboxBackupPermissionDenied =>
      '没有此权限，只能备份您选择的文档文件夹。您可以在 Android 设置中允许。';

  @override
  String get safeboxBackupOpenSettings => '打开设置';

  @override
  String get safeboxBackupStep1 => '第 1 步，共 2 步 · 备份什么？';

  @override
  String get safeboxBackupStep2 => '第 2 步，共 2 步 · 质量';

  @override
  String get safeboxBackupGranted => '已允许访问照片、视频和音乐。文件以加密方式复制，手机上的文件不会被删除。';

  @override
  String get safeboxBackupWhat => '备份什么？';

  @override
  String safeboxBackupPhotosDesc(int count, String size) {
    return '$count 张照片 · 原始质量 $size';
  }

  @override
  String safeboxBackupVideosDesc(int count, String size) {
    return '$count 个视频 · 原始质量 $size';
  }

  @override
  String safeboxBackupAudiosDesc(int count) {
    return '音乐和录音 · $count 个文件';
  }

  @override
  String safeboxBackupDocsDesc(String size) {
    return '下方选择的文件夹 · $size';
  }

  @override
  String get safeboxBackupGalleryFolders => '照片和视频文件夹';

  @override
  String get safeboxBackupDocFolders => '文档文件夹';

  @override
  String get safeboxBackupAddFolder => '添加文件夹';

  @override
  String get safeboxBackupRemoveFolder => '移除文件夹';

  @override
  String get safeboxBackupDownloadsWarning =>
      'Android 不允许自动备份“下载”文件夹。请手动添加这些文件。';

  @override
  String get safeboxBackupSince => '从何时开始？';

  @override
  String get safeboxBackupAllHistory => '全部历史';

  @override
  String get safeboxBackupFromToday => '从今天开始';

  @override
  String get safeboxBackupContinue => '继续';

  @override
  String get safeboxBackupSelection => '您的选择';

  @override
  String safeboxBackupFree(String size) {
    return '剩余 $size';
  }

  @override
  String safeboxBackupFits(String size) {
    return '全部可放入您的空间，将剩余 $size。';
  }

  @override
  String safeboxBackupOverflows(String size) {
    return '超出 $size：最新的文件先备份，最旧的文件将等待空间。';
  }

  @override
  String safeboxBackupHdPreselected(String size) {
    return '已预选 HD：原始质量下，您的选择（$size）超出剩余空间。';
  }

  @override
  String safeboxBackupDocsAlways(String size) {
    return '文档：始终保持原样 · $size';
  }

  @override
  String get safeboxBackupWifiOnly => '仅限 Wi-Fi';

  @override
  String get safeboxBackupChargingOnly => '仅在充电时压缩';

  @override
  String get safeboxBackupRulesNote => '原始质量超过 1 GB 的视频将以 HD 上传。之后更改质量只影响后续文件。';

  @override
  String get safeboxBackupEnable => '开启备份';

  @override
  String get safeboxBackupSave => '保存';

  @override
  String get safeboxBackupDisable => '关闭备份';

  @override
  String get safeboxBackupDisableConfirm => '备份将停止。已在保险箱中的内容会保留。';

  @override
  String get safeboxBackupEnabledToast => '自动备份已开启';

  @override
  String get safeboxBackupSettings => '备份设置';

  @override
  String get safeboxBackupScanning => '正在查找手机上的文件…';

  @override
  String get safeboxFreePhoneTitle => '释放手机空间';

  @override
  String safeboxFreePhoneBody(int photos, int videos, String size) {
    return '$photos 张照片和 $videos 个视频已以原始质量存入保险箱。从手机移除可释放 $size。';
  }

  @override
  String get safeboxFreePhoneAction => '从手机移除';

  @override
  String safeboxFreePhoneDone(int count) {
    return '已从手机移除 $count 个文件';
  }

  @override
  String get safeboxFolderCamera => '相机';

  @override
  String get safeboxFolderScreenshots => '截图';

  @override
  String get safeboxFolderDownloads => '下载的图片';

  @override
  String get safeboxShareBadge => '保险箱';

  @override
  String get safeboxShareSeeAlbum => '查看相册';

  @override
  String safeboxShareItems(int count) {
    return '$count 项';
  }

  @override
  String safeboxShareFamilyPhotos(int count) {
    return '$count 张照片';
  }

  @override
  String safeboxShareFamilyVideos(int count) {
    return '$count 个视频';
  }

  @override
  String safeboxShareFamilyAudios(int count) {
    return '$count 个音频';
  }

  @override
  String safeboxShareFamilyDocuments(int count) {
    return '$count 个文档';
  }

  @override
  String safeboxShareDownloadedBy(int count, int total) {
    return '$total 人中 $count 人已下载';
  }

  @override
  String get safeboxShareSeeTracking => '查看下载情况';

  @override
  String safeboxShareUploading(int percent) {
    return '正在上传到保险箱 · $percent%';
  }

  @override
  String get safeboxShareUploadingHint => '上传完成后成员才会看到。';

  @override
  String safeboxShareBatchTitle(int count) {
    return '$count 个文件';
  }

  @override
  String get safeboxSharedFileTitle => '共享文件';

  @override
  String safeboxSharedBy(String name) {
    return '由 $name 发送';
  }

  @override
  String safeboxSharedFrom(String name) {
    return '来自 $name';
  }

  @override
  String get safeboxSharedSender => '发送者';

  @override
  String safeboxSharedAvailableWhile(String name) {
    return '已加密。只要 $name 将其保留在保险箱中即可使用。';
  }

  @override
  String get safeboxSharedDownloadPlay => '下载并打开';

  @override
  String safeboxSharedWifiAdvised(String size) {
    return '建议使用 Wi-Fi（$size）。';
  }

  @override
  String get safeboxSharedDownloadAll => '全部下载';

  @override
  String safeboxSharedKeepAlbumHint(String size) {
    return '“保留”会将其添加到您的相册（占用 $size 空间）。';
  }

  @override
  String safeboxSharedAlbumKept(String name) {
    return '相册“$name”已添加到您的相册';
  }

  @override
  String get safeboxSharedAllKept => '全部已在您的保险箱中';

  @override
  String get safeboxSharedUnavailable => '已不可用：发送者已将其删除';

  @override
  String safeboxTrackingOutOf(int count, int total) {
    return '$count / $total';
  }

  @override
  String get safeboxTrackingReceivedLabel => '位成员已下载或保留';

  @override
  String safeboxTrackingSaved(int count) {
    return '$count 人已保存到保险箱';
  }

  @override
  String safeboxTrackingSentAt(String date) {
    return '发送于 $date';
  }

  @override
  String get safeboxTrackingMembers => '成员';

  @override
  String safeboxTrackingDownloadedAt(String date) {
    return '已下载 · $date';
  }

  @override
  String get safeboxTrackingSavedState => '已保存到其保险箱';

  @override
  String get safeboxTrackingPending => '尚未';

  @override
  String get safeboxTrackingNote => '文件保留在您的“分享”文件夹中。如果删除，聊天中将无法再获取。';

  @override
  String get safeboxTrackingSendElsewhere => '发送到其他聊天';

  @override
  String get safeboxTrackingRevoke => '取消共享';

  @override
  String get safeboxTrackingRevokeConfirm => '成员将无法再下载。文件仍保留在您的保险箱中。';

  @override
  String get safeboxTrackingRevoked => '已取消共享';

  @override
  String get safeboxShareTabSent => '我的发送';

  @override
  String get safeboxShareTabReceived => '已收到';

  @override
  String get safeboxShareSentInfo => '这些文件会一直保留，直到您将其删除。它们计入您的空间。';

  @override
  String get safeboxShareReceivedInfo => '通过保险箱发送给您的文件（来自所有聊天）。只要发送者保留，即可使用。';

  @override
  String safeboxShareAllReceived(int count) {
    return '$count 个文件所有人已下载';
  }

  @override
  String safeboxShareToFree(String size) {
    return '可释放 $size';
  }

  @override
  String safeboxShareDeleteAllReceived(int count) {
    return '从“分享”中删除这 $count 个文件？所有人都已拥有。';
  }

  @override
  String get safeboxShareNotSent => '尚未发送';

  @override
  String safeboxShareStatusAll(String name) {
    return '已发送到 $name · 所有人都已下载';
  }

  @override
  String safeboxShareStatusNone(String name) {
    return '已发送到 $name · 还没有人下载';
  }

  @override
  String safeboxShareStatusSome(String name, int count, int total) {
    return '已发送到 $name · $count/$total 人已下载';
  }

  @override
  String safeboxShareStatusPersonNone(String name) {
    return '$name 尚未下载';
  }

  @override
  String safeboxShareStatusPersonDone(String name) {
    return '$name 已下载';
  }

  @override
  String get safeboxShareConvFallback => '一个聊天';

  @override
  String get safeboxReceivedEmpty => '尚未通过保险箱收到任何文件';

  @override
  String get safeboxReceivedInDownloads => '在 下载/Alanya 中';

  @override
  String get safeboxReceivedKept => '已保存到您的保险箱';

  @override
  String get safeboxRootVideos => '视频';

  @override
  String get safeboxRootAudios => '音频';

  @override
  String get safeboxRootDocuments => '文档';

  @override
  String safeboxQuotaUsed(String used, String total) {
    return '已使用 $used，共 $total';
  }

  @override
  String safeboxQuotaTrash(String size) {
    return '其中回收站占用 $size';
  }

  @override
  String safeboxRootSummary(int count, String size) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 个文件 · $size',
      zero: '没有文件',
    );
    return '$_temp0';
  }

  @override
  String get safeboxTrash => '回收站';

  @override
  String get safeboxTrashEmpty => '回收站是空的';

  @override
  String safeboxTrashExplain(int days) {
    return '已删除的项目会在这里保留 $days 天，之后将被永久删除。它们会占用您的空间。';
  }

  @override
  String safeboxTrashPurgeOn(String date) {
    return '将于 $date 永久删除';
  }

  @override
  String get safeboxEmptyTrash => '清空回收站';

  @override
  String get safeboxEmptyTrashConfirm => '回收站中的所有内容将被永久删除，且无法恢复。';

  @override
  String get safeboxRestore => '恢复';

  @override
  String get safeboxRestored => '已恢复';

  @override
  String get safeboxDeleteForever => '永久删除';

  @override
  String safeboxDeleteForeverConfirm(String name) {
    return '“$name”将被永久删除。';
  }

  @override
  String get safeboxFolderEmpty => '此文件夹为空';

  @override
  String get safeboxFolderEmptyHint => '点击 + 按钮添加文件或创建子文件夹。';

  @override
  String get safeboxAddFiles => '添加文件';

  @override
  String get safeboxNewFolder => '新建文件夹';

  @override
  String get safeboxFolderName => '文件夹名称';

  @override
  String get safeboxFileName => '文件名';

  @override
  String get safeboxCreate => '创建';

  @override
  String get safeboxRename => '重命名';

  @override
  String get safeboxMove => '移动';

  @override
  String get safeboxMoveHere => '移到此处';

  @override
  String get safeboxDelete => '删除';

  @override
  String get safeboxMovedToTrash => '已移至回收站';

  @override
  String get safeboxOpen => '打开';

  @override
  String get safeboxExport => '保存或分享';

  @override
  String safeboxDownloading(int percent) {
    return '正在下载… $percent%';
  }

  @override
  String get safeboxCompressTitle => '如何上传这些文件？';

  @override
  String safeboxCompressOriginal(String size) {
    return '原始质量 · $size';
  }

  @override
  String get safeboxCompressOriginalHint => '文件将按原样上传。';

  @override
  String safeboxCompressReduced(String size) {
    return '压缩 · 约 $size';
  }

  @override
  String safeboxCompressReducedHint(String saved) {
    return '约节省 $saved。照片、视频或音频的质量依然良好。';
  }

  @override
  String get safeboxCompressRemember => '记住我的选择';

  @override
  String get safeboxSend => '上传';

  @override
  String get safeboxPreparing => '正在准备…';

  @override
  String get safeboxTransfers => '上传任务';

  @override
  String safeboxTransfersCount(int count) {
    return '$count 个上传任务进行中';
  }

  @override
  String get safeboxUploadQueued => '排队中';

  @override
  String safeboxUploadRunning(int percent) {
    return '已上传 $percent%';
  }

  @override
  String get safeboxUploadWaitingNetwork => '等待网络';

  @override
  String get safeboxUploadFailed => '上传失败';

  @override
  String get safeboxUploadDone => '已添加到保险箱';

  @override
  String get safeboxRetry => '重试';

  @override
  String get safeboxCancelUpload => '取消上传';

  @override
  String get safeboxClearFinished => '清除列表';

  @override
  String get safeboxNoTransfers => '没有正在进行的上传';

  @override
  String safeboxWrongFamily(String folder) {
    return '此文件应放入“$folder”。';
  }

  @override
  String safeboxFileTooLarge(String max) {
    return '文件过大（最多 $max）。';
  }

  @override
  String get safeboxEmptyFile => '空文件：没有可上传的内容。';

  @override
  String get safeboxQuotaExceeded => '您的保险箱已满。请释放空间或升级到 Alanya Plus。';

  @override
  String get safeboxSourceChanged => '文件在上传过程中被修改或删除。请重新添加。';

  @override
  String get safeboxUnavailable => '保险箱暂时不可用，请稍后再试。';

  @override
  String get safeboxNameTaken => '此文件夹中已有同名项目。';

  @override
  String get safeboxTooDeep => '子文件夹层级过多。';

  @override
  String get safeboxFolderLimit => '您已达到文件夹数量上限。';

  @override
  String get safeboxInvalidName => '名称无效。';

  @override
  String get safeboxRootLocked => '四个主文件夹无法重命名、移动或删除。';

  @override
  String get safeboxInvalidMove => '文件夹不能移动到其自身内部。';

  @override
  String get safeboxOpenFailed => '无法在此手机上打开此文件。';

  @override
  String get safeboxGoPlus => '查看 Alanya Plus';

  @override
  String safeboxFreeSpace(String size) {
    return '剩余 $size';
  }

  @override
  String get safeboxNotifChannel => '上传到保险箱';

  @override
  String get safeboxAlertChannel => '保险箱空间';

  @override
  String get safeboxAlert80Title => '您的保险箱已使用 80%';

  @override
  String get safeboxAlert95Title => '您的保险箱即将用满（95%）';

  @override
  String get safeboxAlert100Title => '您的保险箱已满';

  @override
  String get safeboxAlertBody => '请释放空间或升级到 Alanya Plus 以继续添加文件。';

  @override
  String get safeboxFreeUpTitle => '释放空间';

  @override
  String get safeboxFreeUpLargest => '最大的文件';

  @override
  String safeboxFreeUpTrash(String size) {
    return '清空回收站 · $size';
  }

  @override
  String safeboxFreeUpSelected(int count, String size) {
    return '已选择 $count 个文件 · $size';
  }

  @override
  String get safeboxFreeUpDelete => '移至回收站';

  @override
  String get safeboxFreeUpHint => '在清空回收站之前，回收站中的文件仍会占用您的空间。';

  @override
  String get safeboxFreeUpNothing => '您的保险箱中没有文件。';

  @override
  String safeboxInFolder(String folder) {
    return '位于 $folder';
  }

  @override
  String get safeboxShareAttach => '保险箱';

  @override
  String get safeboxSharePickTitle => '从保险箱发送';

  @override
  String safeboxSharePickHint(String max) {
    return '最多 $max。文件会保留在您的保险箱中并占用您的空间，直到您将其删除。';
  }

  @override
  String get safeboxSharePickFromPhone => '从手机中选择';

  @override
  String get safeboxShareQueued => '文件进入您的保险箱后将立即发送到聊天中。';

  @override
  String get safeboxShareFromVault => '来自您的保险箱';

  @override
  String safeboxShareDownload(String size) {
    return '下载 · $size';
  }

  @override
  String get safeboxShareSave => '保留在我的保险箱';

  @override
  String get safeboxShareSaved => '已在您的保险箱中';

  @override
  String get safeboxShareSavedToast => '已保留在您的保险箱';

  @override
  String get safeboxShareRevoked => '发送者已移除该文件';

  @override
  String safeboxShareDownloadLimit(int limit) {
    return '您今天已下载此文件 $limit 次。请明天再试，或将其保存到您的保险箱。';
  }

  @override
  String safeboxShareDownloadsLeft(int count) {
    return '今天还可下载 $count 次';
  }

  @override
  String get safeboxShareFallback => '保险箱文件';

  @override
  String safeboxSharePreview(String name) {
    return '📦 $name';
  }

  @override
  String get safeboxShareUnavailableHere => '此文件无法在此处打开。';

  @override
  String get safeboxPlusBadge => 'Alanya Plus';

  @override
  String get safeboxOverQuotaTitle => '您的保险箱超出了空间';

  @override
  String get safeboxOverQuotaBody => '您仍可以查看、下载和删除文件，但无法再添加新文件。';

  @override
  String safeboxOverQuotaPurge(String date) {
    return '超出部分将于 $date 被删除，从最新的文件开始。请在此之前续订 Alanya Plus 或释放空间。';
  }

  @override
  String get safeboxOfferTitle => '文件太大，无法在聊天中发送';

  @override
  String safeboxOfferBody(String size, int limit, String vaultMax) {
    return '此文件大小为 $size，超过了聊天中允许的 $limit MB。保险箱最多可发送 $vaultMax：文件将存放在您的保险箱中，并占用您的空间。';
  }

  @override
  String safeboxOfferBodyMany(int count, int limit, String vaultMax) {
    return '有 $count 个文件超过了聊天中允许的 $limit MB。保险箱可发送每个最多 $vaultMax 的文件：它们将存放在您的保险箱中，并占用您的空间。';
  }

  @override
  String get safeboxOfferAction => '通过保险箱发送';

  @override
  String get safeboxSendToChat => '发送到聊天';

  @override
  String get safeboxSendPickTitle => '发送给…';

  @override
  String safeboxSendDone(int count) {
    return '已发送到 $count 个聊天';
  }

  @override
  String safeboxSentReceived(int received, int recipients) {
    return '$recipients 人中有 $received 人已接收';
  }

  @override
  String get safeboxSentAll => '所有人均已接收';

  @override
  String get safeboxFreeUpSent => '已发送';

  @override
  String get safeboxSavedToDownloads => '已保存到“下载/Alanya”';

  @override
  String get safeboxSaveToDownloadsFailed => '无法保存到“下载”：文件仍保留在应用中。';

  @override
  String safeboxMetaPages(int count) {
    return '$count 页';
  }

  @override
  String get safeboxStoreInTitle => '存放到您的保险箱';

  @override
  String safeboxStoreInHint(int count) {
    return '$count 个文件发送后会保留在您保险箱的此文件夹中。';
  }

  @override
  String get safeboxStoreChange => '更改';

  @override
  String get safeboxStoreContinue => '继续';

  @override
  String get safeboxStoreHere => '存放在这里';

  @override
  String get safeboxFileLost => '文件已损坏';

  @override
  String get safeboxFileLostBody => '此文件已损坏：其内容已在我们的存储服务商处丢失，无法恢复。请将其删除以释放空间。';

  @override
  String get safeboxShareLost => '文件已损坏，无法恢复';

  @override
  String get safeboxShareRemovedByModeration => '该文件已被 Alanya 审核移除';

  @override
  String get safeboxNoteTitle => '评论';

  @override
  String get safeboxNoteAdd => '添加评论';

  @override
  String get safeboxNoteEdit => '编辑评论';

  @override
  String get safeboxNoteHint => '写评论（可选）';

  @override
  String get safeboxNotePrivate => '仅在您的保险箱中可见：分享照片时不会一起发送。';

  @override
  String get safeboxNoteRecord => '录制音频（最长 5 分钟）';

  @override
  String get safeboxNoteStop => '停止';

  @override
  String get safeboxNoteRedo => '重新录制';

  @override
  String get safeboxNoteDeleteAudio => '删除音频';

  @override
  String safeboxNoteAudio(String duration) {
    return '音频评论 · $duration';
  }

  @override
  String safeboxNoteRecording(String elapsed) {
    return '录音中 · $elapsed / 5:00';
  }

  @override
  String get safeboxNoteSaved => '评论已保存';

  @override
  String get safeboxNoteTooLong => '评论过长：文字最多 200 个字符，音频最长 5 分钟。';

  @override
  String get safeboxNoteUnavailable => '仅照片可以添加评论。';

  @override
  String get safeboxNoteAudioFailed => '无法播放音频。';

  @override
  String get safeboxOpenWith => '用其他应用打开…';

  @override
  String get safeboxCompressNothingToGain => '文件已经很小：压缩几乎没有效果。';
}

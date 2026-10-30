/// Centralized UI copy for the whole app.
///
/// Keeping every user-facing string here makes future localization
/// (e.g. switching to `flutter_localizations` / ARB files) a mechanical task.
abstract final class AppStrings {
  // App
  static const String appName = 'Meeto';

  // Tabs
  static const String tabMessages = 'Messages';
  static const String tabMe = 'Me';

  // Feed (community activity wall)
  static const String emptyFeed = 'No activity posts found';
  static const String verifiedLabel = 'Verified';
  // Escrow payment page
  static const String paymentTitle = 'Confirm payment';
  static const String paymentMatchLine = 'Your plan, once the fee is secured';
  static const String paymentFeeLabel = 'Service fee';
  static const String paymentHeldByLabel = 'Held by';
  static const String paymentHeldBy = 'Meeto escrow';
  static const String paymentReleaseLabel = 'Released';
  static const String paymentRelease = 'After you both confirm the meet';
  static const String paymentMethodDemo = 'Demo payment (GCash coming soon)';
  static const String paymentEscrowNote =
      'Your money never goes to the other person directly. Meeto holds it '
      'until the meet-up happens, and refunds it in full if the plan is '
      'cancelled. Chat and phone numbers unlock after payment.';
  static String paymentPayCta(String fee) => 'Pay $fee into escrow';
  static const String paymentPaying = 'Processing...';
  static const String paymentDoneSnack = 'Fee secured in escrow';
  static const String paymentFailedSnack = 'Payment failed, try again';
  static const String chatLockedNote = 'Chat unlocks once the fee is in escrow';
  static const String deletePostCta = 'Delete post';
  static const String deletePostConfirmTitle = 'Delete this post?';
  static const String deletePostConfirmBody =
      'Candidates who signed up will be released. This cannot be undone.';
  static const String deletePostYes = 'Delete';
  static const String deletePostNo = 'Keep';
  static const String deletePostDone = 'Post deleted';
  static String appliedCount(int count) =>
      count == 1 ? '1 applied' : '$count applied';
  static const String tipLabel = 'Fee';
  static String distanceAway(String distance) => '$distance km away';

  // Community guidelines banner + page
  static const String bannerEyebrow = 'Community';
  static const String bannerTitle = 'Meet safe, be real';
  static const String bannerSub =
      'The rules every Meeto member agrees to follow';
  static const String bannerCta = 'Read rules';
  static const String guidelinesTitle = 'Community Guidelines';
  static const String guidelinesIntro =
      'Meeto is where you book real company for real activities. These '
      'rules keep every meet-up safe, honest, and worth showing up for.';
  static const List<(String, String)> guidelinesRules = <(String, String)>[
    (
      'Be real',
      'Your profile photo must be you. Every account passes real-person '
          'verification, and pretending to be someone else gets you banned.',
    ),
    (
      'Respect first',
      'No harassment, insults, or pressure of any kind, on the app or at '
          'the meet-up. One report can be enough for a ban.',
    ),
    (
      'Meet in public',
      'Pick cafes, restaurants, malls, and other public venues. Never move '
          'a first meet-up to a private place.',
    ),
    (
      'Companionship only',
      'Meeto is for real company at real activities. Any sexual services, '
          'offers, or hints are strictly forbidden and are reported to '
          'authorities.',
    ),
    (
      'Keep money on Meeto',
      'The service fee stays in Meeto escrow until the meet-up happens. '
          'Never pay or collect outside the platform; off-app deals are not '
          'protected.',
    ),
    (
      'Show up on time',
      'Both sides commit when a plan is matched. No-shows and last-minute '
          'bailing hurt your account standing.',
    ),
    (
      'Report, we act',
      'Something felt wrong? Use Report a problem on the order. Payouts '
          'freeze while we review, and rule-breakers lose their accounts.',
    ),
  ];
  static const String guidelinesFooter =
      'Breaking these rules can lead to frozen payouts or a permanent ban.';

  // Post detail
  static const String labelTime = 'Time';
  static const String labelPlace = 'Place';
  static const String labelDistance = 'Distance';
  static const String safetyNotice =
      'Meeto protects you: both sides are identity-verified, and the whole '
      'activity \u2014 from match to meet-up \u2014 runs under platform '
      'supervision.';
  static const String tipPayLabel = 'Service fee you\'ll pay';
  static const String tipReceiveLabel = 'Service fee you\'ll receive';
  static const String signUpCta = 'Sign up';
  static const String signedUpCta = 'Signed up \u00b7 awaiting selection';
  static const String candidateSignedUpSnack =
      'You are in as a candidate \u2014 the poster picks one person to match';

  // Candidate flow (poster side)
  static const String candidatesTitle = 'Candidates';
  static const String candidatesEmpty =
      'No candidates yet \u2014 sign-ups usually arrive within minutes';
  static const String approveCta = 'Approve';
  static const String tipPayNote =
      'Held in escrow by Meeto \u00b7 full refund on cancellation';

  // Escrow / settlement
  static const String escrowSub =
      'Meeto holds the payment until the activity completes \u00b7 full '
      'refund if cancelled';

  // Publish
  static const String publishTitle = 'Post an activity';
  static const String publishScene = 'Scene';
  static const String publishFieldTitle = 'Title';
  static const String publishFieldDesc = 'Description';
  static const String publishFieldDescHint =
      'share what you want to do and expect';
  static const String publishPhTitle = 'e.g. Coffee at a new cafe';
  static const String publishPhDesc =
      'e.g. New cafe in town, looking for relaxed company and good chat...';
  static const String publishTipPayNote =
      'Service fee you\'ll pay when you pick a host \u00b7 held in escrow '
      'by Meeto';
  static const String publishSubmit = 'Publish';
  static const String publishSuccess = 'Published! Awaiting sign-ups';
  static const String publishDefaultDesc =
      'Looking for company, relaxed and no pressure';
  static const String publishDefaultTime = 'Time is flexible';
  static const String publishDefaultPlace = 'Place open to ideas';

  // User profile
  static const String profileTitle = 'Profile';
  static const String profileReviews = 'Reviews';
  static const String profileActivityPosts = 'Activities posted';
  static const String profileDatesCompleted = 'Activities completed';
  static const String profileJobLabel = 'Work';
  static const String profileEducationLabel = 'Education';
  static const String profileHeightLabel = 'Height';
  static const String profileWeightLabel = 'Weight';
  static const String profileLivesInLabel = 'Lives in';

  // Chats
  static const String statusCompleted = 'Completed';
  static const String messageInputHint = 'Type a message...';

  // Order flow (chat detail)
  static const List<String> orderStages = <String>[
    'Deal',
    'En route',
    'Met',
    'Done',
  ];
  static const List<String> personStages = <String>[
    'Ready',
    'En route',
    'Arrived',
  ];

  // Live orders (API mode: both sides act from their own devices)
  static const String ordersEmpty =
      'No plans yet \u2014 sign up for a post or publish your own';
  static const String statusAwaitingPayment = 'Awaiting payment';
  static const String payToUnlockCta = 'Pay to unlock';
  static const String statusPendingDate = 'Plan details to be set';
  static const String statusActive = 'In progress';
  static const String statusCancelled = 'Cancelled';
  static String payCta(String amount) => 'Pay $amount into escrow';
  static const String waitingForPayment =
      'Waiting for the service fee to be paid';
  static String settledEarnerNote(String net) =>
      'Activity completed \u00b7 $net settled to your wallet';
  static String settledPayerNote(String fee) =>
      'Activity completed \u00b7 $fee released from escrow';
  static const String cancelledNote =
      'This plan was cancelled \u00b7 full refund issued';
  static String escrowHeldNote(String amount) =>
      '$amount held in escrow by Meeto';
  static const String selectionDoneSnack =
      'Host approved \u2014 the plan forms once you pay the service fee';

  // Profile setup wizard (registration onboarding)
  static const String setupStepRoleTitle = 'How will you use Meeto?';
  static const String setupStepRoleSub =
      'Pick the side that fits you. This cannot be changed later.';
  static const String roleUserLabel = 'Book activities';
  static const String roleUserSub =
      'Post what you want to do or invite a host, '
      'and pay the service fee';
  static const String roleHostLabel = 'Host and earn';
  static const String roleHostSub =
      'Pitch plans, host great activities, '
      'and earn the service fee';
  static const String roleRequiredHint = 'Pick how you\'ll use Meeto first';
  static const String setupStepGenderTitle = 'I am a...';
  static const String setupStepGenderSub =
      'Shown on your profile and used for search preferences. '
      'It cannot be changed later.';
  static const String genderFemaleLabel = 'Woman';
  static const String genderMaleLabel = 'Man';
  static const String genderRequiredHint = 'Pick one to continue';
  static const String setupStepNameTitle = 'My name is...';
  static const String setupStepNameSub =
      'This is how you will appear on Meeto';
  static const String setupNameHint = 'Your name';
  static const String nameRequiredHint = 'Enter your name to continue';
  static const String setupStepBirthTitle = 'When were you born?';
  static const String setupStepBirthSub =
      'You must be 18 or older. Others only see your age.';
  static const String setupBirthYearLabel = 'Year';
  static const String setupBirthMonthLabel = 'Month';
  static const String setupStepBodyTitle = 'Height & weight';
  static const String setupStepBodySub =
      'A quick physical picture for your profile';
  static const String setupStepLocationTitle = 'Where are you based?';
  static const String setupStepLocationSub =
      'So we can show activities near you';
  static const String setupStepWorkTitle = 'What do you do?';
  static const String setupStepWorkSub =
      'A little background goes a long way';
  static const String setupStepTagsTitle = 'Your interests';
  static const String setupStepTagsSub = 'Pick a few things you love';
  static const String setupStepBioTitle = 'A bit about you';
  static const String setupStepBioSub =
      'A short intro makes matches much more likely';
  static const String setupStepPhotosTitle = 'Add your photos';
  static const String setupStepPhotosSub =
      'A main photo plus up to 3 more. The main photo is also the '
      'reference we use to verify you are a real person.';
  static const String setupMainPhotoBadge = 'Main';
  static const String setupStepHostScenesTitle =
      'Which activities can you host?';
  static const String setupStepHostScenesSub =
      'Pick at least one. Guests invite you from this list, and you earn '
      'the shown amount per hosted activity.';
  static const String setupHostScenesLabel = 'Hosted activities';
  static const String hostScenesRequiredHint =
      'Pick at least one activity you can host';
  static const String setupNext = 'Next';
  static const String setupFinish = 'Finish';
  static const String setupStepSkip = 'Skip';
  static const String setupCountryLabel = 'Country';
  static const String setupCityLabel = 'City';

  /// Launch markets and their selectable cities. Keep country names as the
  /// stored values; the server treats them as plain strings.
  static const List<(String, List<String>)> countryCities =
      <(String, List<String>)>[
    (
      'Philippines',
      <String>[
        'Manila',
        'Quezon City',
        'Makati',
        'Taguig',
        'Pasig',
        'Pasay',
        'Paranaque',
        'Caloocan',
        'Cebu City',
        'Davao City',
        'Baguio',
        'Iloilo City',
        'Bacolod',
        'Cagayan de Oro',
      ]
    ),
    (
      'Indonesia',
      <String>[
        'Jakarta',
        'Surabaya',
        'Bandung',
        'Medan',
        'Semarang',
        'Makassar',
        'Palembang',
        'Tangerang',
        'Bekasi',
        'Depok',
        'Denpasar',
        'Yogyakarta',
      ]
    ),
    (
      'Vietnam',
      <String>[
        'Ho Chi Minh City',
        'Hanoi',
        'Da Nang',
        'Hai Phong',
        'Can Tho',
        'Bien Hoa',
        'Hue',
        'Nha Trang',
        'Vung Tau',
        'Da Lat',
      ]
    ),
  ];
  static const String setupJobLabel = 'Work';
  static const String setupEducationLabel = 'Education';
  static const String setupHeightLabel = 'Height';
  static const String setupWeightLabel = 'Weight';

  /// Fixed education levels; stored as-is.
  static const List<String> educationOptions = <String>[
    'High school',
    'Vocational',
    'Bachelor\u2019s',
    'Master\u2019s',
    'Doctorate',
  ];

  /// Fixed occupation categories; stored as-is.
  static const List<String> jobOptions = <String>[
    'Student',
    'IT & Engineering',
    'Design & Creative',
    'Teacher',
    'Medical & Health',
    'Sales & Marketing',
    'Finance',
    'Service industry',
    'Entrepreneur',
    'Freelancer',
    'Content creator',
    'Other',
  ];
  static const String setupTagsLabel = 'Interests';

  /// Predefined interest tags shown as multi-select chips on profile setup.
  static const List<String> setupTagOptions = <String>[
    'Coffee',
    'Food trips',
    'Movies',
    'Music',
    'Karaoke',
    'Art',
    'Travel',
    'Fitness',
    'Hiking',
    'Gaming',
    'Photography',
    'Books',
    'Nightlife',
    'Shopping',
  ];
  static const String setupBioLabel = 'About you';
  static const String setupBioHint =
      'A short intro: what you like, what a fun time out looks like for '
      'you...';
  static const String setupSave = 'Save';
  static const String menuEditProfile = 'Edit profile';
  static const String editPhotosLabel = 'Photos';
  static const String editLocationLabel = 'Location';
  static const String editNotSet = 'Not set';
  static const String sheetDone = 'Done';

  // Real-person verification
  static const String verifyTitle = 'Real-person verification';
  static const String verifySub =
      'We capture a quick selfie and match it against your profile photo to confirm it is really you. It keeps meet-ups safe and unlocks posting, signing up and payments.';
  static const String verifyYourPhoto = 'Your profile photo';
  static const String verifyStart = 'Start verification';
  static const String verifySuccess = 'You are verified';
  static const String verifyNoAvatar =
      'Set a profile photo first; your selfie is matched against it';
  static const String verifyGoSetAvatar = 'Set profile photo';
  static const String verifyDialogTitle = 'Verification required';
  static const String verifyDialogBody =
      'This action needs real-person verification. It only takes a minute.';
  static const String verifyNow = 'Verify now';
  static const String verifyLater = 'Later';
  static const String verifiedStatus = 'Verified';
  static const String notVerifiedStatus = 'Not verified';
  static const String setupUploadFailed = 'Upload failed, try again';
  static const String setupAvatarRequired = 'Add a profile photo first';
  static String joinedLine(String time) => 'Joined $time';

  // Publish: structured time and place pickers
  static const String publishPickTime = 'Pick a date & time';

  // Meet flow (API mode order room)
  static const String peerPhoneLabel = 'Phone';
  static const String phoneCopied = 'Phone number copied';
  static String distanceApart(String km) => 'You are $km km apart';
  static const String distanceWaiting =
      'Distance appears when both share location';
  static const String confirmMeetCta = "We met \u2014 confirm";
  static const String meetWaitingPeer =
      'Confirmed. Waiting for the other side to confirm the meet';
  static const String notTogetherHint =
      'You two do not seem to be at the same place yet. Try again when you are together.';
  static const String metHeadline = 'Meet confirmed';
  static String metSettleEarnerSub(String time, String amount) =>
      '$amount releases to you at $time. Enjoy!';
  static String metSettlePayerSub(String time) =>
      'The fee releases to your host at $time';
  static const String disputeCta = 'Report a problem';
  static const String disputeConfirmTitle = 'Report a problem?';
  static const String disputeConfirmBody =
      'This freezes the payout until our team reviews the meet-up. Use it only if something went wrong.';
  static const String disputeConfirmYes = 'Report';
  static const String disputeConfirmNo = 'Back';
  static const String disputedHeadline = 'Under review';
  static const String disputedSub =
      'A problem was reported. The payout is frozen while our team reviews it.';
  static const String locationNeededHint =
      'Location access is needed to confirm you met in person';

  // Gig hall (host-side work surface)
  static const String tabGigs = 'Requests';
  static const String gigsTitle = 'Open requests';
  static const String gigsSubtitle =
      'Pitch a plan and earn the service fee';
  static const String gigsEmpty =
      'No open requests right now \u2014 check back soon';
  static const String gigsInvitesHeader = 'Invitations for you';
  static const String gigsRequestsHeader = 'Open requests';
  static String gigEarnLine(String amount) => 'Earn $amount';
  static const String gigAppliedBadge = 'Applied';
  static const String gigPitchCta = 'Pitch your plan';

  // Host directory + direct invitations
  static const String tabHosts = 'Hosts';
  static const String tabCommunity = 'Community';
  static const String hostsTitle = 'Find a host';
  static const String hostsSubtitle =
      'Pick someone to plan and host your next activity';
  static const String hostsEmpty = 'No hosts available yet';
  static const String hostsPostRequestCta = 'Post a request';
  static String hostCompletedLabel(int count) =>
      count == 1 ? '1 activity hosted' : '$count activities hosted';
  static const String hostNewLabel = 'New host';
  static const String hostRecentPlanLabel = 'Recent plans';
  static const String hostSeeActivities = 'See activities they can host';
  static const String hostActivitiesTitle = 'Activities they can host';
  static const String inviteRowCta = 'Invite';
  static String inviteSheetTitle(String name) => 'Invite $name to host';
  static const String inviteNoteHint =
      'Tell them what you have in mind (optional)';
  static String inviteFeeNote(String fee) =>
      'If they accept, you\'ll pay the $fee service fee to start the plan';
  static const String inviteSendCta = 'Send invitation';
  static const String inviteSentSnack =
      'Invitation sent \u2014 you\'ll be notified when they respond';
  static const String inviteAlreadyPendingSnack =
      'You already have a pending invitation to this host';
  static String inviteFromLine(String name, String scene) =>
      '$name invited you to host: $scene';
  static const String inviteAcceptCta = 'Accept';
  static const String inviteDeclineCta = 'Decline';
  static const String inviteAcceptedSnack =
      'Invitation accepted \u2014 the plan starts once they pay';
  static const String inviteDeclinedSnack = 'Invitation declined';
  static String notifyInviteReceived(String name) =>
      '$name invited you to host an activity';
  static String notifyInviteAccepted(String name) =>
      '$name accepted your invitation \u2014 pay the service fee to start';
  static String notifyInviteDeclined(String name) =>
      '$name declined your invitation this time';

  // Community moments (activity recaps)
  static const String momentBadge = 'Moment';
  static const String momentComposerTitle = 'Share a moment';
  static const String momentTextHint =
      'How did your activity go? Give your host a shout-out';
  static const String momentTextRequiredHint = 'Write something first';
  static const String momentPostCta = 'Post';
  static const String momentPhotoFailed = 'Photo upload failed, try again';

  // Sign-up proposal (the candidate's plan pitch)
  static const String proposalSheetTitle = 'Pitch your plan';
  static const String proposalSheetSub =
      'Say where you\'d take them and when. The poster picks a host '
      'based on the plans.';
  static const String proposalHint =
      'e.g. Single Origin in Makati, Saturday 3pm';
  static const String proposalRequiredHint =
      'Write a short plan to sign up';

  // Plan (host proposes, poster confirms)
  static const String planCardTitle = 'The plan';
  static const String planHostPrompt =
      'You are the host \u2014 propose where and when you\'ll meet';
  static const String planProposeCta = 'Propose the plan';
  static const String planEditCta = 'Change';
  static const String planWaitingHost =
      'Waiting for the host to propose the plan';
  static const String planAwaitingConfirm =
      'Waiting for confirmation from the poster';
  static const String planConfirmCta = 'Confirm plan';
  static const String planConfirmedBadge = 'Confirmed';
  static const String planSheetTitle = 'Propose the plan';
  static const String planPlaceHint =
      'Where exactly? e.g. Single Origin, Greenbelt 3';
  static const String planRequiredHint = 'Add the place and time first';
  static const String planProposedSnack = 'Plan sent for confirmation';
  static const String planConfirmedSnack = 'Plan confirmed';
  static String notifyPlanProposed(String name) =>
      '$name proposed the plan \u2014 review and confirm';
  static String notifyPlanConfirmed(String name) =>
      '$name confirmed the plan. See you there!';

  // Notifications
  static const String notificationsTitle = 'Notifications';
  static const String notificationsInboxSub =
      'Applicants, matches and order updates';
  static const String notificationsEmpty = 'Nothing here yet';
  static String notifyNewApplicant(String name) =>
      '$name signed up for your post';
  static String notifySelected(String name) =>
      '$name picked you to host the activity';
  static String notifyOrderPaid(String name) =>
      '$name paid the service fee. The plan is on!';
  static String notifyOrderCancelled(String name) =>
      '$name cancelled the plan';
  static String notifyOrderMet(String name) =>
      '$name confirmed you met. Payout timer started';
  static const String notifyOrderSettled =
      'Your earnings have been released to your wallet';
  static String notifyOrderDisputed(String name) =>
      '$name reported a problem with the meet-up';
  static const String timeJustNow = 'Just now';
  static String timeMinutesAgo(int m) => '${m}m ago';
  static String timeHoursAgo(int h) => '${h}h ago';
  static String timeDaysAgo(int d) => '${d}d ago';

  // Me page
  static const String walletLabel = 'Earnings this month';
  static String walletWithdrawable(String amount) =>
      'Withdrawable $amount \u00b7 T+1 payout';
  static const String withdraw = 'Withdraw';
  static const String withdrawSubmitted = 'Withdrawal request submitted';
  static const String menuMyPosts = 'My Posts';
  static const String menuVerification = 'Verification Center';
  static const String menuSettings = 'Settings';
  static const String menuLogout = 'Log out';
  static const String myPostsEmpty = 'No posts yet';
  static const String postStatusOpen = 'Open';
  static const String postStatusMatched = 'Matched';
  static const String walletTitle = 'Wallet';
  static const String withdrawSheetTitle = 'Withdraw to GCash';
  static String withdrawSheetSub(String amount) =>
      'Up to $amount \u00b7 arrives T+1 \u00b7 payout account setup comes '
      'with the GCash integration';
  static const String withdrawHistoryTitle = 'Withdrawal history';
  static const String withdrawHistoryEmpty = 'No withdrawals yet';
  static const String withdrawFailed = 'Withdrawal failed, try again';
  static const String withdrawalPending = 'Pending';
  static const String withdrawalPaid = 'Paid';

  // Relative time
  static const String justNow = 'just now';
  static String minutesAgo(int minutes) => '${minutes}m ago';
  static String hoursAgo(int hours) => '${hours}h ago';
  static String daysAgo(int days) => '${days}d ago';
}

import '../../../core/constants/app_strings.dart';
import '../../../core/network/api_client.dart';
import '../models/current_user.dart';
import '../models/profile_parts.dart';
import '../models/user_detail.dart';
import 'profile_repository.dart';

/// [ProfileRepository] backed entirely by the Meeto API. Profile content is
/// real user data; aggregates (dates completed) come from the orders table.
/// Ratings/reviews render an honest empty state until the review system
/// ships — no fabricated numbers.
class ApiProfileRepository implements ProfileRepository {
  ApiProfileRepository(this._client);

  final ApiClient _client;

  @override
  Future<CurrentUser> fetchCurrentUser() async {
    final Map<String, dynamic> json =
        await _client.get('/users/me') as Map<String, dynamic>;
    final String city = json['city'] as String? ?? '';
    final String shortId =
        (json['id'] as String).substring(0, 6).toUpperCase();
    return CurrentUser(
      id: json['id'] as String,
      name: json['name'] as String,
      gender: json['gender'] as String,
      avatarUrl: resolveMediaUrl(json['avatarUrl'] as String? ?? ''),
      meta: json['meta'] as String,
      isVerified: json['isVerified'] as bool,
      idLine: city.isEmpty ? 'Meeto ID $shortId' : 'Meeto ID $shortId \u00b7 $city',
      stats: _stats(json),
    );
  }

  @override
  Future<WalletSummary> fetchWallet() async {
    final Map<String, dynamic> json =
        await _client.get('/wallet') as Map<String, dynamic>;
    return WalletSummary(
      monthTipIncome: minorToPesos(json['monthIncomeMinor'] as int),
      withdrawable: minorToPesos(json['withdrawableMinor'] as int),
    );
  }

  @override
  Future<List<WithdrawalRecord>> fetchWithdrawals() async {
    final List<dynamic> json =
        await _client.get('/wallet/withdrawals') as List<dynamic>;
    return json
        .cast<Map<String, dynamic>>()
        .map(_toWithdrawal)
        .toList(growable: false);
  }

  @override
  Future<WithdrawalRecord> requestWithdrawal(int amountPesos) async {
    final Map<String, dynamic> json = await _client.post(
      '/wallet/withdrawals',
      body: <String, dynamic>{'amountMinor': amountPesos * 100},
    ) as Map<String, dynamic>;
    return _toWithdrawal(json);
  }

  WithdrawalRecord _toWithdrawal(Map<String, dynamic> json) {
    return WithdrawalRecord(
      id: json['id'] as String,
      amountPesos: minorToPesos(json['amountMinor'] as int),
      status: json['status'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }

  @override
  Future<UserDetail?> fetchUserDetail(String userId) async {
    final Map<String, dynamic> json;
    try {
      json = await _client.get('/users/$userId') as Map<String, dynamic>;
    } on ApiException catch (e) {
      if (e.statusCode == 404) {
        return null;
      }
      rethrow;
    }
    final String city = json['city'] as String? ?? '';
    final String country = json['country'] as String? ?? '';
    final String job = json['job'] as String? ?? '';
    final String education = json['education'] as String? ?? '';
    final int? heightCm = json['heightCm'] as int?;
    final int? weightKg = json['weightKg'] as int?;
    final String livesIn = <String>[city, country]
        .where((String part) => part.isNotEmpty)
        .join(' \u00b7 ');
    return UserDetail(
      id: json['id'] as String,
      name: json['name'] as String,
      avatarUrl: resolveMediaUrl(json['avatarUrl'] as String? ?? ''),
      meta: json['meta'] as String,
      isVerified: json['isVerified'] as bool,
      city: city,
      joinedText: AppStrings.joinedLine(
        _monthYear(DateTime.parse(json['joinedAt'] as String)),
      ),
      bio: json['bio'] as String? ?? '',
      tags: (json['tags'] as List<dynamic>? ?? <dynamic>[]).cast<String>(),
      photos: (json['photos'] as List<dynamic>? ?? <dynamic>[])
          .cast<String>()
          .map(resolveMediaUrl)
          .toList(growable: false),
      info: <ProfileInfoItem>[
        if (job.isNotEmpty)
          ProfileInfoItem(label: AppStrings.profileJobLabel, value: job),
        if (education.isNotEmpty)
          ProfileInfoItem(
            label: AppStrings.profileEducationLabel,
            value: education,
          ),
        if (heightCm != null)
          ProfileInfoItem(
            label: AppStrings.profileHeightLabel,
            value: '$heightCm cm',
          ),
        if (weightKg != null)
          ProfileInfoItem(
            label: AppStrings.profileWeightLabel,
            value: '$weightKg kg',
          ),
        if (livesIn.isNotEmpty)
          ProfileInfoItem(
            label: AppStrings.profileLivesInLabel,
            value: livesIn,
          ),
      ],
      stats: _stats(json),
      reviews: const <UserReview>[],
    );
  }

  /// Honest stats: both counts come from real posts and orders. No rating
  /// shown until the review system provides real scores.
  List<ProfileStat> _stats(Map<String, dynamic> json) {
    final int datePosts = json['datePosts'] as int? ?? 0;
    final int datesCompleted = json['datesCompleted'] as int? ?? 0;
    return <ProfileStat>[
      ProfileStat(value: '$datePosts', label: AppStrings.profileDatePosts),
      ProfileStat(
        value: '$datesCompleted',
        label: AppStrings.profileDatesCompleted,
      ),
    ];
  }

  static const List<String> _months = <String>[
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  String _monthYear(DateTime date) =>
      '${_months[date.month - 1]} ${date.year}';
}

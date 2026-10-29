import '../models/current_user.dart';
import '../models/profile_parts.dart';
import '../models/user_detail.dart';

/// Data source contract for user profiles and the wallet summary.
abstract interface class ProfileRepository {
  Future<CurrentUser> fetchCurrentUser();

  Future<WalletSummary> fetchWallet();

  /// Withdrawal history, newest first.
  Future<List<WithdrawalRecord>> fetchWithdrawals();

  /// Requests a withdrawal of [amountPesos]; the balance is debited
  /// immediately and the request stays PENDING until paid out.
  Future<WithdrawalRecord> requestWithdrawal(int amountPesos);

  /// Full public profile for any user, or null when not found.
  Future<UserDetail?> fetchUserDetail(String userId);
}

/// In-memory mock used for the demo build.
class MockProfileRepository implements ProfileRepository {
  static const CurrentUser _me = CurrentUser(
    id: 'user-100',
    name: 'Andrea',
    gender: 'FEMALE',
    avatarUrl: 'https://i.pravatar.cc/160?img=47',
    meta: 'Female \u00b7 24',
    isVerified: true,
    idLine: 'Meeto ID 20481 \u00b7 Manila',
    stats: <ProfileStat>[
      ProfileStat(value: '36', label: 'Dates completed'),
      ProfileStat(value: '98%', label: 'Rating'),
      ProfileStat(value: '12', label: 'Regulars'),
    ],
  );

  static final Map<String, UserDetail> _users = <String, UserDetail>{
    'user-101': UserDetail(
      id: 'user-101',
      name: 'Miguel',
      avatarUrl: 'https://i.pravatar.cc/300?img=11',
      meta: 'Male \u00b7 27',
      isVerified: true,
      city: 'Manila \u00b7 Makati',
      joinedText: 'Joined September 2025',
      bio: 'Product manager, coffee-powered. Cafe hopping and galleries on '
          'weekends, looking for people who vibe.',
      tags: const <String>['Coffee', 'Art exhibits', 'Podcasts', 'Whiskey'],
      photos: const <String>[
        'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?auto=format&fit=crop&w=600&h=800&q=80',
        'https://images.unsplash.com/photo-1472099645785-5658abf4ff4e?auto=format&fit=crop&w=600&h=800&q=80',
      ],
      info: const <ProfileInfoItem>[
        ProfileInfoItem(label: 'Job', value: 'Product manager'),
        ProfileInfoItem(label: 'Education', value: 'Masters \u00b7 Ateneo'),
        ProfileInfoItem(label: 'Height', value: '178cm'),
        ProfileInfoItem(label: 'Lives in', value: 'Manila \u00b7 Makati'),
      ],
      stats: const <ProfileStat>[
        ProfileStat(value: '8', label: 'Dates posted'),
        ProfileStat(value: '7', label: 'Completed'),
        ProfileStat(value: '100%', label: 'Rating'),
      ],
      reviews: const <UserReview>[
        UserReview(
          fromName: 'Bea',
          avatarUrl: 'https://i.pravatar.cc/60?img=44',
          text: 'So many topics, super easy to talk to, and the cafe he '
              'picked was lovely.',
        ),
        UserReview(
          fromName: 'Luna',
          avatarUrl: 'https://i.pravatar.cc/60?img=45',
          text: 'On time and polite \u2014 even reimbursed my ride right '
              'after the date.',
        ),
      ],
    ),
    'user-102': UserDetail(
      id: 'user-102',
      name: 'Paolo',
      avatarUrl: 'https://i.pravatar.cc/300?img=59',
      meta: 'Male \u00b7 29',
      isVerified: true,
      city: 'Taguig \u00b7 BGC',
      joinedText: 'Joined August 2025',
      bio: 'In the F&B supply business \u2014 loves food and knows food. '
          'Looking for company to explore great restaurants.',
      tags: const <String>['Food trips', 'Japanese food', 'City walks'],
      photos: const <String>[
        'https://images.unsplash.com/photo-1500648767791-00dcc994a43e?auto=format&fit=crop&w=600&h=800&q=80',
        'https://images.unsplash.com/photo-1506794778202-cad84cf45f1d?auto=format&fit=crop&w=600&h=800&q=80',
      ],
      info: const <ProfileInfoItem>[
        ProfileInfoItem(label: 'Job', value: 'F&B entrepreneur'),
        ProfileInfoItem(label: 'Education', value: 'College \u00b7 UP Diliman'),
        ProfileInfoItem(label: 'Height', value: '182cm'),
        ProfileInfoItem(label: 'Lives in', value: 'Taguig \u00b7 BGC'),
      ],
      stats: const <ProfileStat>[
        ProfileStat(value: '12', label: 'Dates posted'),
        ProfileStat(value: '11', label: 'Completed'),
        ProfileStat(value: '98%', label: 'Rating'),
      ],
      reviews: const <UserReview>[
        UserReview(
          fromName: 'Andrea',
          avatarUrl: 'https://i.pravatar.cc/60?img=47',
          text: 'Took me to an amazing Japanese place, respectful and easy '
              'to talk to.',
        ),
        UserReview(
          fromName: 'Cha',
          avatarUrl: 'https://i.pravatar.cc/60?img=48',
          text: 'Relaxed dinner, zero pressure. Recommended!',
        ),
      ],
    ),
    'user-103': UserDetail(
      id: 'user-103',
      name: 'Marco',
      avatarUrl: 'https://i.pravatar.cc/300?img=12',
      meta: 'Male \u00b7 28',
      isVerified: true,
      city: 'Makati \u00b7 Poblacion',
      joinedText: 'Joined October 2025',
      bio: 'Copywriter at an ad agency. Quiet bars after work, no pushing '
          'drinks \u2014 just conversation.',
      tags: const <String>['Whiskey', 'Jazz', 'Movies', 'Cats'],
      photos: const <String>[
        'https://images.unsplash.com/photo-1492562080023-ab3db95bfbce?auto=format&fit=crop&w=600&h=800&q=80',
        'https://images.unsplash.com/photo-1519085360753-af0119f7cbe7?auto=format&fit=crop&w=600&h=800&q=80',
      ],
      info: const <ProfileInfoItem>[
        ProfileInfoItem(label: 'Job', value: 'Senior copywriter'),
        ProfileInfoItem(label: 'Education', value: 'College \u00b7 DLSU'),
        ProfileInfoItem(label: 'Height', value: '176cm'),
        ProfileInfoItem(label: 'Lives in', value: 'Makati \u00b7 Poblacion'),
      ],
      stats: const <ProfileStat>[
        ProfileStat(value: '6', label: 'Dates posted'),
        ProfileStat(value: '6', label: 'Completed'),
        ProfileStat(value: '100%', label: 'Rating'),
      ],
      reviews: const <UserReview>[
        UserReview(
          fromName: 'Kat',
          avatarUrl: 'https://i.pravatar.cc/60?img=49',
          text: 'A gentleman all evening \u2014 truly just drinks and good '
              'talk. Felt completely at ease.',
        ),
        UserReview(
          fromName: 'Momo',
          avatarUrl: 'https://i.pravatar.cc/60?img=32',
          text: 'The bar he picked was so quiet and the conversation flowed '
              '\u2014 time flew by.',
        ),
      ],
    ),
    'user-104': UserDetail(
      id: 'user-104',
      name: 'Rafael',
      avatarUrl: 'https://i.pravatar.cc/300?img=33',
      meta: 'Male \u00b7 26',
      isVerified: true,
      city: 'Pasig \u00b7 Ortigas',
      joinedText: 'Joined September 2025',
      bio: 'Software engineer and movie addict \u2014 around 100 films a '
          'year. Looking for someone to watch and discuss with.',
      tags: const <String>['Movies', 'Sci-fi', 'Photography'],
      photos: const <String>[
        'https://images.unsplash.com/photo-1463453091185-61582044d556?auto=format&fit=crop&w=600&h=800&q=80',
        'https://images.unsplash.com/photo-1480429370139-e0132c086e2a?auto=format&fit=crop&w=600&h=800&q=80',
      ],
      info: const <ProfileInfoItem>[
        ProfileInfoItem(label: 'Job', value: 'Software engineer'),
        ProfileInfoItem(label: 'Education', value: 'Masters \u00b7 UP'),
        ProfileInfoItem(label: 'Height', value: '175cm'),
        ProfileInfoItem(label: 'Lives in', value: 'Pasig \u00b7 Ortigas'),
      ],
      stats: const <ProfileStat>[
        ProfileStat(value: '5', label: 'Dates posted'),
        ProfileStat(value: '4', label: 'Completed'),
        ProfileStat(value: '97%', label: 'Rating'),
      ],
      reviews: const <UserReview>[
        UserReview(
          fromName: 'Trish',
          avatarUrl: 'https://i.pravatar.cc/60?img=16',
          text: 'We talked for an hour after the movie \u2014 his takes are '
              'great.',
        ),
      ],
    ),
    'user-105': UserDetail(
      id: 'user-105',
      name: 'Daniel',
      avatarUrl: 'https://i.pravatar.cc/300?img=7',
      meta: 'Male \u00b7 31',
      isVerified: true,
      city: 'QC \u00b7 Katipunan',
      joinedText: 'Joined August 2025',
      bio: 'Marketing at a multinational, fast-paced weeks. Weekends are for '
          'slowing down over afternoon tea.',
      tags: const <String>['Desserts', 'Afternoon tea', 'Tennis'],
      photos: const <String>[
        'https://images.unsplash.com/photo-1504257432389-52343af06ae3?auto=format&fit=crop&w=600&h=800&q=80',
        'https://images.unsplash.com/photo-1519345182560-3f2917c472ef?auto=format&fit=crop&w=600&h=800&q=80',
      ],
      info: const <ProfileInfoItem>[
        ProfileInfoItem(label: 'Job', value: 'Marketing director'),
        ProfileInfoItem(label: 'Education', value: 'Masters \u00b7 abroad'),
        ProfileInfoItem(label: 'Height', value: '180cm'),
        ProfileInfoItem(label: 'Lives in', value: 'QC \u00b7 Katipunan'),
      ],
      stats: const <ProfileStat>[
        ProfileStat(value: '9', label: 'Dates posted'),
        ProfileStat(value: '9', label: 'Completed'),
        ProfileStat(value: '100%', label: 'Rating'),
      ],
      reviews: const <UserReview>[
        UserReview(
          fromName: 'Dess',
          avatarUrl: 'https://i.pravatar.cc/60?img=20',
          text: 'Warm and attentive the whole date, and the dessert place '
              'was gorgeous.',
        ),
        UserReview(
          fromName: 'Cici',
          avatarUrl: 'https://i.pravatar.cc/60?img=23',
          text: 'Light, pressure-free conversation and it ended right on '
              'time.',
        ),
      ],
    ),
    'user-100': UserDetail(
      id: 'user-100',
      name: 'Andrea',
      avatarUrl: 'https://i.pravatar.cc/300?img=47',
      meta: 'Female \u00b7 24',
      isVerified: true,
      city: 'Manila \u00b7 Makati',
      joinedText: 'Joined October 2025',
      bio: 'Office girl by day, loves good talk in the evening. Into '
          'desserts, movies and everything cute.',
      tags: const <String>['Desserts', 'Movies', 'City walks'],
      photos: const <String>[
        'https://images.unsplash.com/photo-1494790108377-be9c29b29330?auto=format&fit=crop&w=600&h=800&q=80',
        'https://images.unsplash.com/photo-1529626455594-4ff0802cfb7e?auto=format&fit=crop&w=600&h=800&q=80',
      ],
      info: const <ProfileInfoItem>[
        ProfileInfoItem(label: 'Job', value: 'Social media specialist'),
        ProfileInfoItem(label: 'Education', value: 'College \u00b7 UST'),
        ProfileInfoItem(label: 'Height', value: '160cm'),
        ProfileInfoItem(label: 'Lives in', value: 'Manila \u00b7 Makati'),
      ],
      stats: const <ProfileStat>[
        ProfileStat(value: '36', label: 'Dates completed'),
        ProfileStat(value: '98%', label: 'Rating'),
        ProfileStat(value: '12', label: 'Regulars'),
      ],
      reviews: const <UserReview>[
        UserReview(
          fromName: 'Marco',
          avatarUrl: 'https://i.pravatar.cc/60?img=12',
          text: 'Great company, the whole evening was easy. A solid date '
              'buddy.',
        ),
      ],
    ),
  };

  @override
  Future<CurrentUser> fetchCurrentUser() async {
    await Future<void>.delayed(const Duration(milliseconds: 200));
    return _me;
  }

  int _mockWithdrawable = 29800;
  final List<WithdrawalRecord> _withdrawals = <WithdrawalRecord>[];

  @override
  Future<WalletSummary> fetchWallet() async {
    await Future<void>.delayed(const Duration(milliseconds: 200));
    return WalletSummary(
      monthTipIncome: 38250,
      withdrawable: _mockWithdrawable,
    );
  }

  @override
  Future<List<WithdrawalRecord>> fetchWithdrawals() async {
    await Future<void>.delayed(const Duration(milliseconds: 200));
    return List<WithdrawalRecord>.unmodifiable(_withdrawals);
  }

  @override
  Future<WithdrawalRecord> requestWithdrawal(int amountPesos) async {
    await Future<void>.delayed(const Duration(milliseconds: 300));
    final WithdrawalRecord record = WithdrawalRecord(
      id: 'wd-${DateTime.now().millisecondsSinceEpoch}',
      amountPesos: amountPesos,
      status: 'PENDING',
      createdAt: DateTime.now(),
    );
    _mockWithdrawable -= amountPesos;
    _withdrawals.insert(0, record);
    return record;
  }

  @override
  Future<UserDetail?> fetchUserDetail(String userId) async {
    await Future<void>.delayed(const Duration(milliseconds: 250));
    return _users[userId];
  }
}

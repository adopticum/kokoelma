import 'dart:async';
import 'dart:convert';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:math';
import '../models/profile.dart';
import '../utils/logger.dart';

class ProfileService {
  final SupabaseClient supabase; //dep. = Supabase.instance.client;
  final String userId;

  final StreamController<void> _changesController =
      StreamController<void>.broadcast();
  late final StreamSubscription<AuthState> _authStateSubscription;
  RealtimeChannel? _profileRealtimeChannel;
  RealtimeChannel? _membershipsRealtimeChannel;
  RealtimeChannel? _groupsRealtimeChannel;
  String? _boundUserId;
  bool _bindingRealtime = false;
  bool _rebindRequested = false;

  ProfileService(this.supabase, this.userId) {
    _authStateSubscription = supabase.auth.onAuthStateChange.listen((data) {
      if (data.event == AuthChangeEvent.initialSession ||
          data.event == AuthChangeEvent.tokenRefreshed) {
        _bindRealtimeForCurrentUser();
      }
    });
    _bindRealtimeForCurrentUser();
  }

  static const String _table = 'userprofiles';
  static const String _membershipsTable = 'memberships';
  static const String _groupsTable = 'groups';
  final _random = Random();

  Stream<void> get changes => _changesController.stream;

  Future<void> _bindRealtimeForCurrentUser() async {
    if (_bindingRealtime) {
      _rebindRequested = true;
      return;
    }

    _bindingRealtime = true;
    try {
      do {
        _rebindRequested = false;
        await _bindRealtimeForCurrentUserInternal();
      } while (_rebindRequested);
    } finally {
      _bindingRealtime = false;
    }
  }

  Future<void> _bindRealtimeForCurrentUserInternal() async {
    final currentSession = supabase.auth.currentSession;
    final accessToken = await _getFreshAccessToken();

    logger.d(
      'Binding realtime for profile sync: authUserId=$userId, currentSessionPresent=${currentSession != null}, accessTokenPresent=${currentSession?.accessToken != null}',
    );

    // Keep realtime socket auth in sync with the latest session token.
    try {
      await supabase.realtime.setAuth(accessToken);
      logger.d(
        'Realtime auth synced before binding: tokenPresent=${accessToken != null}',
      );
    } catch (e) {
      logger.w('Failed to sync realtime auth token: $e');
    }

    if (userId == _boundUserId &&
        _profileRealtimeChannel != null &&
        _membershipsRealtimeChannel != null &&
        _groupsRealtimeChannel != null) {
      return;
    }

    await _unbindRealtime();

    if (userId.isEmpty) {
      _boundUserId = null;
      return;
    }

    _boundUserId = userId;

    final profileChannelName = 'profile-sync-$userId-profile';
    final membershipsChannelName = 'profile-sync-$userId-memberships';
    final groupsChannelName = 'profile-sync-$userId-groups';

    final profileChannel = supabase
        .channel(profileChannelName)
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: _table,
          callback: (payload) => _onProfileRowChanged(userId, payload),
        );

    final membershipsChannel = supabase
        .channel(membershipsChannelName)
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: _membershipsTable,
          callback: (payload) => _onMembershipRowChanged(userId, payload),
        );

    final groupsChannel = supabase
        .channel(groupsChannelName)
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: _groupsTable,
          callback: (payload) => _onGroupRowChanged(userId, payload),
        );

    profileChannel.subscribe((status, error) {
      logger.d(
        'Realtime subscription [$profileChannelName] status: $status${error != null ? ', error: $error' : ''}',
      );
      _handleRealtimeSubscribeStatus(status, error);
    });

    membershipsChannel.subscribe((status, error) {
      logger.d(
        'Realtime subscription [$membershipsChannelName] status: $status${error != null ? ', error: $error' : ''}',
      );
      _handleRealtimeSubscribeStatus(status, error);
    });

    groupsChannel.subscribe((status, error) {
      logger.d(
        'Realtime subscription [$groupsChannelName] status: $status${error != null ? ', error: $error' : ''}',
      );
      _handleRealtimeSubscribeStatus(status, error);
    });

    _profileRealtimeChannel = profileChannel;
    _membershipsRealtimeChannel = membershipsChannel;
    _groupsRealtimeChannel = groupsChannel;
  }

  Future<String?> _getFreshAccessToken() async {
    var session = supabase.auth.currentSession;
    var token = session?.accessToken;

    if (token != null && _isJwtExpiredOrNearExpiry(token)) {
      logger.i(
        'Realtime bind: token expired/near expiry, refreshing session before subscribe.',
      );
      try {
        final refreshed = await supabase.auth.refreshSession();
        session = refreshed.session ?? supabase.auth.currentSession;
        token = session?.accessToken;
      } catch (e) {
        logger.w('Realtime bind: failed to refresh session token: $e');
      }
    }

    return token;
  }

  bool _isJwtExpiredOrNearExpiry(String jwt, {int skewSeconds = 30}) {
    try {
      final parts = jwt.split('.');
      if (parts.length < 2) {
        return true;
      }

      var payload = parts[1];
      final normalized = payload.length % 4;
      if (normalized > 0) {
        payload = payload.padRight(payload.length + (4 - normalized), '=');
      }

      final decoded = utf8.decode(base64Url.decode(payload));
      final map = jsonDecode(decoded);
      final exp = map is Map<String, dynamic> ? map['exp'] : null;
      if (exp is! num) {
        return true;
      }

      final nowSeconds = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      return exp.toInt() <= (nowSeconds + skewSeconds);
    } catch (_) {
      return true;
    }
  }

  void _handleRealtimeSubscribeStatus(
    RealtimeSubscribeStatus status,
    Object? error,
  ) {
    if (status != RealtimeSubscribeStatus.channelError) {
      return;
    }

    final message = error?.toString() ?? '';
    if (message.contains('InvalidJWTToken') ||
        message.toLowerCase().contains('token has expired')) {
      logger.w(
        'Realtime channel rejected JWT; scheduling rebind after auth refresh.',
      );
      _bindRealtimeForCurrentUser();
    }
  }

  Future<void> _unbindRealtime() async {
    final profileChannel = _profileRealtimeChannel;
    final membershipsChannel = _membershipsRealtimeChannel;
    final groupsChannel = _groupsRealtimeChannel;

    _profileRealtimeChannel = null;
    _membershipsRealtimeChannel = null;
    _groupsRealtimeChannel = null;

    if (profileChannel != null) {
      await supabase.removeChannel(profileChannel);
    }
    if (membershipsChannel != null) {
      await supabase.removeChannel(membershipsChannel);
    }
    if (groupsChannel != null) {
      await supabase.removeChannel(groupsChannel);
    }
  }

  void _emitChangeSignal() {
    if (!_changesController.isClosed) {
      _changesController.add(null);
    }
  }

  void _logRealtimePayload(String label, PostgresChangePayload payload) {
    logger.d(
      'Realtime [$label] payload: schema=${payload.schema}, table=${payload.table}, eventType=${payload.eventType}, commitTimestamp=${payload.commitTimestamp}, new=${payload.newRecord}, old=${payload.oldRecord}, errors=${payload.errors}',
    );
  }

  void _onProfileRowChanged(String uid, PostgresChangePayload payload) {
    _logRealtimePayload('profile', payload);
    logger.d('Realtime: profile row change detected.');
    if (_boundUserId != uid) {
      logger.d('Realtime: User id check mismatch for profile row change.');
      return;
    }
    _emitChangeSignal();
  }

  void _onMembershipRowChanged(String uid, PostgresChangePayload payload) {
    _logRealtimePayload('membership', payload);
    logger.d('Realtime: membership row change detected.');
    if (_boundUserId != uid) {
        logger.d('Realtime: User id check mismatch for membership row change.');
        return;
    }

    // RLS already limits membership rows to the authenticated user.
    // DELETE payloads may omit userid, so client-side userid filtering
    // can incorrectly drop relevant events.
    _emitChangeSignal();
  }

  void _onGroupRowChanged(String uid, PostgresChangePayload payload) {
    _logRealtimePayload('group', payload);
    logger.d('Realtime: group row change detected.');
    if (_boundUserId != uid) {
      logger.d('Realtime: User id check mismatch for group row change.');
      return;
    }
    _emitChangeSignal();
  }

  Future<UserProfile?> getProfile() async {
    UserProfile? userprofile;
    logger.i("Fetching profile for userId: $userId");
    
    try {
      final response = await supabase
        .from(_table)
        .select('''
          id,
          nickname,
          firstname,
          lastname,
          created_at,
          privileges(is_group_admin)
        ''')
        .eq('id', userId)
        .single();
      userprofile = UserProfile.fromJson(response);
    } on PostgrestException catch (e) {
      if (e.details?.toString().contains('0 rows') ?? false) {
        logger.i('Profile not found for user: $userId');
      } else {
        logger.e('Database error while fetching profile', error: e);
      }
    } on AuthException catch (e) {
      logger.e('Authentication error while fetching profile', error: e);
    } catch (e) {
      logger.e('Unexpected error while fetching profile', error: e);
    }
    return userprofile;
  }

  Future<UserProfile?> generateProfile() async {
    try {
      final response =
          await supabase
              .from(_table)
              .insert({'id': userId, 'nickname': _generateRandomNickname()})
              .select()
              .single();
      return UserProfile.fromJson(response);
    } on PostgrestException catch (e) {
      logger.e('Error creating profile', error: e);
    } on AuthException catch (e) {
      logger.e('Authentication error while creating profile', error: e);
    } catch (e) {
      logger.e('Unexpected error while creating profile', error: e);
    }
    return null;
  }

  Future<UserProfile?> getOrGenerateProfile() async {
    UserProfile? up = await getProfile();
    up ??= await generateProfile();
    if (up == null) {
      throw Exception("Failed to load or create the user profile.");
    }
    return up;
  }

  Future<void> updateProfile(UserProfile userprofile) async {
    try {
      await supabase.from(_table).upsert(userprofile.toJson());
      logger.i('Profile updated successfully for user: ${userprofile.id}');
    } on PostgrestException catch (e) {
      logger.e('Database error while updating profile', error: e);
      rethrow;
    } on AuthException catch (e) {
      logger.e('Authentication error while updating profile', error: e);
      rethrow;
    } catch (e) {
      logger.e('Unexpected error while updating profile', error: e);
      rethrow;
    }
  }

  String _generateRandomNickname() {
    const adjectives = [
      "Swift",
      "Silent",
      "Brave",
      "Clever",
      "Mighty",
      "Noble",
      "Loyal",
      "Wise",
      "Gentle",
      "Colorful",
      "Happy",
      "Friendly",
      "Curious",
      "Bright",
      "Cheerful",
      "Kind",
      "Joyful",
      "Radiant",
      "Hopeful",
      "Gracious",
      "Calm",
      "Playful",
      "Sunny",
      "Patient",
      "Bold",
    ];
    const animals = [
      "Lion",
      "Eagle",
      "Shark",
      "Wolf",
      "Panther",
      "Falcon",
      "Tiger",
      "Bear",
      "Dolphin",
      "Fox",
      "Hawk",
      "Panda",
      "Otter",
      "Hedgehog",
      "Koala",
      "Salmon",
      "Lynx",
      "Swan",
      "Seal",
      "Badger",
      "Moose",
      "Jaguar",
      "Leopard",
      "Parrot",
      "Penguin",
    ];
    final randomNum = _random.nextInt(100);
    final adjective = adjectives[_random.nextInt(adjectives.length)];
    final animal = animals[_random.nextInt(animals.length)];
    return '$adjective$animal$randomNum';
  }

  void dispose() {
    _authStateSubscription.cancel();
    _unbindRealtime();
    _changesController.close();
  }
}

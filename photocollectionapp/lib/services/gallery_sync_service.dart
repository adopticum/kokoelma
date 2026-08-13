/*
GallerySyncService should:

- subscribe to realtime for memberships and photometadata
- normalize raw realtime payloads into typed gallery events
- expose one ordered event stream for GalleryViewModel
  provide lifecycle methods (start, stop, rebind)
- optionally provide a bounded catch-up hook after reconnect

It should not:
- own widget state
- mutate GalleryViewModel directly
- do full list polling on every event
*/

import 'dart:async';
import 'package:logger/logger.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/gallery_sync_events.dart';
import '../models/photo_metadata.dart';
import '../models/membership.dart';
import 'group_service.dart';

// Service API contract (implementation agnostic).
abstract class GallerySyncService {
  /// Stream consumed by GalleryViewModel.
  Stream<GallerySyncEvent> get events;

  /// Current scoped user for this session subtree.
  String get userId;

  /// Start realtime subscriptions.
  Future<void> start();

  /// Stop and dispose realtime subscriptions/channels.
  Future<void> stop();

  /// Force rebind channels (token refresh/recover).
  Future<void> rebind();

  /// Optional: update current group filter context if you choose
  /// dynamic per-group channels later.
  Future<void> updateTrackedGroups(Set<String> groupIds);

  /// Optional catch-up query after reconnect.
  Future<void> catchUpSince(DateTime sinceUtc);

  void dispose();
}


class SupabaseGallerySyncService implements GallerySyncService {
  final SupabaseClient _supabase;
  final String _userId;
  final GroupService _groupService;
  final Logger _logger;
  final StreamController<GallerySyncEvent> _eventsController =
      StreamController<GallerySyncEvent>.broadcast();

  StreamSubscription<AuthState>? _authStateSubscription;
  RealtimeChannel? _membershipsChannel;
  RealtimeChannel? _photoMetadataChannel;
  final Set<String> _trackedGroupIds = <String>{};
  bool _started = false;
  bool _binding = false;
  bool _rebindRequested = false;

  static const String photometadataTable = 'photometadata';
  static const String membershipsTable = 'memberships';

  SupabaseGallerySyncService({
    required String userId,
    required SupabaseClient supabase,
    required GroupService groupService,
    required Logger logger,
  }) : _supabase = supabase,
    _userId = userId,
    _groupService = groupService,
    _logger = logger;

  @override
  Stream<GallerySyncEvent> get events => _eventsController.stream;

  @override
  String get userId => _userId;

  @override
  Future<void> start() async {
    if (_started) return;
    _started = true;

    final groups = await _groupService.getGroupsForUser(_userId);
    _trackedGroupIds
      ..clear()
      ..addAll(groups.map((group) => group.id));

    _authStateSubscription = _supabase.auth.onAuthStateChange.listen((data) {
      if (data.event == AuthChangeEvent.initialSession ||
          data.event == AuthChangeEvent.tokenRefreshed) {
        rebind();
      }
    });

    await _bindRealtime();
  }

  @override
  Future<void> stop() async {
    _started = false;
    await _authStateSubscription?.cancel();
    _authStateSubscription = null;
    await _unbindRealtime();
  }

  @override
  Future<void> rebind() async {
    if (!_started) return;
    await _bindRealtime();
  }

  @override
  Future<void> updateTrackedGroups(Set<String> groupIds) async {
    _trackedGroupIds
      ..clear()
      ..addAll(groupIds);
  }

  @override
  Future<void> catchUpSince(DateTime sinceUtc) async {
    _emit(
      GallerySyncInvalidate(
        reason: 'catch_up_not_implemented',
        receivedAt: DateTime.now(),
      ),
    );
  }

  Future<void> _bindRealtime() async {
    if (_binding) {
      _rebindRequested = true;
      return;
    }

    _binding = true;
    try {
      do {
        _rebindRequested = false;
        await _bindRealtimeInternal();
      } while (_rebindRequested);
    } finally {
      _binding = false;
    }
  }

  Future<void> _bindRealtimeInternal() async {
    await _syncRealtimeAuth();
    await _unbindRealtime();

    final membershipsChannelName = 'gallery-sync-$_userId-$membershipsTable';
    final photoMetadataChannelName = 'gallery-sync-$_userId-$photometadataTable';

    final membershipsChannel = _supabase
        .channel(membershipsChannelName)
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: membershipsTable,
          callback: _handleMembershipPayload,
        );

    final photoMetadataChannel = _supabase
        .channel(photoMetadataChannelName)
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: photometadataTable,
          callback: _handlePhotoMetadataPayload,
        );

    membershipsChannel.subscribe((status, error) {
      _logStatus(membershipsChannelName, status, error);
      _handleSubscribeStatus(status, error);
    });

    photoMetadataChannel.subscribe((status, error) {
      _logStatus(photoMetadataChannelName, status, error);
      _handleSubscribeStatus(status, error);
    });

    _membershipsChannel = membershipsChannel;
    _photoMetadataChannel = photoMetadataChannel;
  }

  Future<void> _syncRealtimeAuth() async {
    final token = _supabase.auth.currentSession?.accessToken;

    try {
      await _supabase.realtime.setAuth(token);
    } catch (e) {
      _logger.w('Gallery sync: failed to sync realtime auth token: $e');
    }
  }

  Future<void> _unbindRealtime() async {
    final membershipsChannel = _membershipsChannel;
    final photoMetadataChannel = _photoMetadataChannel;
    _membershipsChannel = null;
    _photoMetadataChannel = null;

    if (membershipsChannel != null) {
      await _supabase.removeChannel(membershipsChannel);
    }
    if (photoMetadataChannel != null) {
      await _supabase.removeChannel(photoMetadataChannel);
    }
  }

  void _handleMembershipPayload(PostgresChangePayload payload) {
    final receivedAt = _receivedAt(payload);
    _logger.d(
      'Gallery realtime membership payload: event=${payload.eventType}, new=${payload.newRecord}, old=${payload.oldRecord}',
    );

    final record = _recordPicker(payload);
    final membership = Membership.tryParseMembership(record);

    if (membership == null) {
      _logger.w(
        'Gallery realtime membership payload could not be parsed; falling back to invalidate',
      );
      _emit(
        GallerySyncInvalidate(
          reason: 'membership_payload_unparseable',
          receivedAt: receivedAt,
        ),
      );
      return;
    }

    _logger.d(
      'Gallery realtime membership parsed: user=${membership.userid}, group=${membership.groupid}',
    );

    switch (payload.eventType) {
      case PostgresChangeEvent.insert:
        _trackedGroupIds.add(membership.groupid);
        _emit(
          MembershipAdded(receivedAt: receivedAt, membership: membership)
        );
        return;
      case PostgresChangeEvent.delete:
        _trackedGroupIds.remove(membership.groupid);
        _emit(
          MembershipRemoved(receivedAt: receivedAt, membership: membership),
        );
        return;
      default:
        _emit(
          GallerySyncInvalidate(
            reason: 'membership_update_not_supported',
            receivedAt: receivedAt,
          ),
        );
    }
}

  void _handlePhotoMetadataPayload(PostgresChangePayload payload) {
    final receivedAt = _receivedAt(payload);
    final record = _recordPicker(payload);
    final pmd = PhotoMetadata.fromJson(record);

    _logger.d(
      'Gallery realtime photo payload: event=${payload.eventType}, photo=${pmd.photoId}, group=${pmd.groupid}',
    );

    if (!_trackedGroupIds.contains(pmd.groupid)) {
      _logger.d(
        'Gallery realtime photo payload ignored: group ${pmd.groupid} is not tracked',
      );
      return;
    }

    switch (payload.eventType) {
      case PostgresChangeEvent.insert:
        _emit(PhotoAdded(receivedAt: receivedAt, photoMetadata: pmd));
        return;
      case PostgresChangeEvent.delete:
        _emit(PhotoRemoved(receivedAt: receivedAt, photoMetadata: pmd));
        return;
      default:
        _emit(
          GallerySyncInvalidate(
            reason: 'photo_metadata_update_not_supported',
            receivedAt: receivedAt,
          ),
        );
    }
  }

  Map<String, dynamic> _recordPicker(PostgresChangePayload payload) {
    // Depending on the event type, the relevant data is in either newRecord or oldRecord.
    // Remember to set "replica identity full" on the table to get oldRecord values.
    if (payload.eventType == PostgresChangeEvent.delete) {
      return payload.oldRecord;
    }
    return payload.newRecord;
  }

  DateTime _receivedAt(PostgresChangePayload payload) {
    final timestamp = payload.commitTimestamp;
    return DateTime.tryParse(timestamp.toString()) ?? DateTime.now();
  }

  void _handleSubscribeStatus(RealtimeSubscribeStatus status, Object? error) {
    if (status != RealtimeSubscribeStatus.channelError) {
      return;
    }

    final message = error?.toString() ?? '';
    if (message.contains('InvalidJWTToken') ||
        message.toLowerCase().contains('token has expired')) {
      rebind();
      return;
    }

    _emit(
      GallerySyncInvalidate(
        reason: 'channel_error',
        receivedAt: DateTime.now(),
      ),
    );
  }

  void _logStatus(
    String channelName,
    RealtimeSubscribeStatus status,
    Object? error,
  ) {
    _logger.d(
      'Gallery realtime subscription [$channelName] status: $status${error != null ? ', error: $error' : ''}',
    );
  }

  void _emit(GallerySyncEvent event) {
    if (!_eventsController.isClosed) {
      _logger.d('Gallery realtime emit: ${event.runtimeType}');
      _eventsController.add(event);
    }
  }

  @override
  void dispose() {
    stop();
    _eventsController.close();
  }
}
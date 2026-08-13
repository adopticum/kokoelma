import 'photo_metadata.dart';
import 'membership.dart';

abstract class GallerySyncEvent {
  final DateTime receivedAt;
  const GallerySyncEvent(this.receivedAt);
}

// Membership change events, e.g. user added/removed from group.
class MembershipAdded extends GallerySyncEvent {
  final Membership membership;
  
  const MembershipAdded({
    required DateTime receivedAt,
    required this.membership,
  }) : super(receivedAt);
}

class MembershipRemoved extends GallerySyncEvent {
  final Membership membership;
  
  const MembershipRemoved({
    required DateTime receivedAt,
    required this.membership,
  }) : super(receivedAt);
}

// Photo metadata events (incremental CRUD). We skip update event because photos are immutable.
class PhotoAdded extends GallerySyncEvent {
  final PhotoMetadata photoMetadata;
  const PhotoAdded({
    required DateTime receivedAt,
    required this.photoMetadata,
  }) : super(receivedAt);
}

class PhotoRemoved extends GallerySyncEvent {
  final PhotoMetadata photoMetadata;
  const PhotoRemoved({
    required DateTime receivedAt,
    required this.photoMetadata,
  }) : super(receivedAt);
}

class GallerySyncInvalidate extends GallerySyncEvent {
  final String reason; // reconnect_gap, decode_error, auth_rebind, etc.
  const GallerySyncInvalidate({
    required this.reason,
    required DateTime receivedAt,
  }) : super(receivedAt);
}


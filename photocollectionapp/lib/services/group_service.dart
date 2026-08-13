import 'package:photocollectionapp/models/membership.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/group.dart';
import '../utils/logger.dart';

class GroupService {
  final SupabaseClient _supabase;

  GroupService(this._supabase);

  Future<Group?> getGroup(String groupId) async {
    try {
      final response =
          await _supabase.from('groups').select().eq('id', groupId).single();
      return Group.fromJson(response);
    } on PostgrestException catch (e) {
      if (e.details?.toString().contains('0 rows') ?? false) {
        logger.i('Group not found: $groupId');
      } else {
        logger.e('Database error while fetching group', error: e);
      }
    } on AuthException catch (e) {
      logger.e('Authentication error while fetching group', error: e);
    } catch (e) {
      logger.e('Unexpected error while fetching group', error: e);
    }
    return null;
  }

  /* Query all group memberships for a user.
  Returns a list of memberships sorted in chronological order. */
  Future<List<Membership>> getAllMemberships(String userId) async {
    try {
      final response = await _supabase
          .from('memberships')
          .select()
          .eq('userid', userId)
          .order(
            'joined_at',
            ascending: false,
          ); // Most recent memberships first.

      final items = List<Map<String, dynamic>>.from(response as List<dynamic>);
      return items.map((json) => Membership.fromJson(json)).toList();
    } on PostgrestException catch (e) {
      if (e.details?.toString().contains('0 rows') ?? false) {
        logger.i('No memberships found for user: $userId');
        return [];
      } else {
        logger.e('Database error while fetching memberships', error: e);
      }
    } on AuthException catch (e) {
      logger.e('Authentication error while fetching memberships', error: e);
    } catch (e) {
      logger.e('Unexpected error while fetching memberships', error: e);
    }
    return [];
  }

  Future<List<Group>> getGroupsForUser(String? userId) async {
    if (userId == null) {
      logger.i('No group memberships for null user.');
      return [];
    }
    final memberships = await getAllMemberships(userId);
    if (memberships.isEmpty) {
      logger.i('No group memberships found for user: $userId');
      return [];
    }

    final groups = await Future.wait(
      memberships.map((membership) => getGroup(membership.groupid)),
    );

    return groups.whereType<Group>().toList();
  }

  /* Get the current active group membership for a user.
  TODO: Implement support for multiple group memberships and selection of active group.  
  */
  Future<Group?> getDefaultGroup(String userId) async {
    // Get all memberships for the user, and return the group details for the most recent membership.
    final memberships = await getAllMemberships(userId);
    if (memberships.isEmpty) {
      logger.i('No group memberships found for user: $userId');
      return null;
    }
    logger.i("Found ${memberships.length} memberships.");
    final group = await getGroup(
      memberships.first.groupid,
    ); //Pick most recent membership as default.
    logger.i("Active group is ${group?.name}.");
    return group;
  }

  /* TODO:
  We will do a code review specifically to analyze the case when the user is not member of any group. 
  Is that case properly handled everywhere throughout the app?
  We will not fix any other issues that we find at the same time, only take note of other issues.
  */
}

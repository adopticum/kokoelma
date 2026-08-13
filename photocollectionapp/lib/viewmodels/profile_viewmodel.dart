import 'dart:async';

import 'package:flutter/material.dart';
import '../services/profile_service.dart';
import '../services/group_service.dart';
import '../models/profile.dart';
import '../models/group.dart';
import '../utils/logger.dart';

class ProfileViewModel extends ChangeNotifier {
  final ProfileService profileService;
  final GroupService groupService;

  StreamSubscription<void>? _profileChangesSubscription;
  bool _isRealtimeRefreshing = false;
  bool _pendingRealtimeRefresh = false;

  ProfileViewModel(this.profileService, this.groupService) {
    _profileChangesSubscription = profileService.changes.listen((_) {
      logger.d('ProfileViewModel: received realtime profile change signal.');
      _refreshFromRealtime();
    });
  }

  UserProfile? _profile;

  bool isLoading = false;  // During inital load from backend.
  bool isSaving = false;  // During saving of changes.

  // Public getters (the view uses only these).

  bool get hasProfile => _profile != null;

  String get userId => _profile?.id ?? '';

  String get nickname => _profile?.nickname ?? '';

  String get firstName => _profile?.firstName ?? '';

  String get lastName => _profile?.lastName ?? '';

  bool get isGroupAdmin => _profile?.isAdmin ?? false;

  List<Group> groups = [];

  Group? get group => groups.isNotEmpty ? groups.first : null;

  Future<void> _refreshFromRealtime() async {
    if (_isRealtimeRefreshing || isLoading || isSaving) {
      _pendingRealtimeRefresh = true;
      return;
    }

    _isRealtimeRefreshing = true;

    try {
      final freshProfile = await profileService.getOrGenerateProfile();
      final freshGroups = await groupService.getGroupsForUser(freshProfile?.id);

      final profileChanged = freshProfile != _profile;
      final groupsChanged = !Group.areEqualLists(groups, freshGroups);
      if (profileChanged || groupsChanged) {
        _profile = freshProfile;
        groups = freshGroups;
        notifyListeners();
      }
    } catch (e) {
      logger.e('Realtime profile refresh failed', error: e);
    } finally {
      _isRealtimeRefreshing = false;

      if (_pendingRealtimeRefresh) {
        _pendingRealtimeRefresh = false;
        _refreshFromRealtime();
      }
    }
  }


  Future<void> load() async {
    isLoading = true;
    notifyListeners();

    try {
      _profile = await profileService.getOrGenerateProfile();
      groups = await groupService.getGroupsForUser(_profile?.id);
    } catch (e) {
      logger.e("Loading profile failed", error: e);
      _profile = null;
      groups = [];
    }

    isLoading = false;
    notifyListeners();

    if (_pendingRealtimeRefresh) {
      _pendingRealtimeRefresh = false;
      _refreshFromRealtime();
    }
  }

  Future<void> _updateProfile({
    required String nickname,
    required String firstName,
    required String lastName,
  }) async {
    if (_profile == null) return;

    isSaving = true;
    notifyListeners();

    final updated = UserProfile(
      id: _profile!.id,
      nickname: nickname,
      firstName: firstName,
      lastName: lastName,
      createdAt: _profile!.createdAt,
      isAdmin: _profile!.isAdmin,
    );

    await profileService.updateProfile(updated);

    _profile = updated;
    isSaving = false;
    notifyListeners();
  }

  Future<void> saveNickname(String newNickname) async {
    await _updateProfile(
      nickname: newNickname,
      firstName: firstName,
      lastName: lastName,
    );
  }

  Future<void> saveFirstName(String newFirstName) async {
    await _updateProfile(
      nickname: nickname,
      firstName: newFirstName,
      lastName: lastName,
    );
  }

  Future<void> saveLastName(String newLastName) async {
    await _updateProfile(
      nickname: nickname,
      firstName: firstName,
      lastName: newLastName,
    );
  }

  @override
  void dispose() {
    _profileChangesSubscription?.cancel();
    super.dispose();
  }
}

import 'package:flutter/material.dart';
import 'package:photocollectionapp/services/auth_service.dart';
import 'package:photocollectionapp/services/local_photo_service.dart';

class HomeViewModel extends ChangeNotifier {
  final AuthService auth;
  final LocalPhotoService localPhotoService;

  HomeViewModel(this.auth, this.localPhotoService);

  // If we are running wasm (web assembly) set default page to profile, otherwise set to camera.
  //int _pageIndex = bool.fromEnvironment('dart.tool.dart2wasm')? 1 : 0 ;
  
  int _pageIndex = 1;
  int get pageIndex => _pageIndex;

  bool _isImporting = false;
  bool get isImporting => _isImporting;

  void setPageIndex(int index) {
    if (_pageIndex != index) {
      _pageIndex = index;
      notifyListeners();
    }
  }

  Future<void> signOut() async {
    await auth.signOut();
  }

  Future<ImportResult> importImage() async {
    _isImporting = true;

    notifyListeners();

    final result = await localPhotoService.importImage();

    _isImporting = false;

    notifyListeners();

    if (result == ImportResult.success) {
      setPageIndex(2); // go to Camera Roll
    }

    return result;
  }
}

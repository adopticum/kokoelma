import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:photocollectionapp/services/auth_service.dart';
import 'package:photocollectionapp/services/exif_service.dart';
import 'package:photocollectionapp/services/gallery_sync_service.dart';
import 'package:photocollectionapp/services/group_service.dart';
import 'package:photocollectionapp/services/image_service.dart';
import 'package:photocollectionapp/services/local_photo_service.dart';
import 'package:photocollectionapp/services/location_service.dart';
import 'package:photocollectionapp/services/path_service.dart';
import 'package:photocollectionapp/services/profile_service.dart';
import 'package:photocollectionapp/services/storage_service.dart';
import 'package:photocollectionapp/viewmodels/camera_roll_viewmodel.dart';
import 'package:photocollectionapp/viewmodels/camera_viewmodel.dart';
import 'package:photocollectionapp/viewmodels/gallery_viewmodel.dart';
import 'package:photocollectionapp/viewmodels/home_viewmodel.dart';
import 'package:photocollectionapp/viewmodels/profile_viewmodel.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../utils/logger.dart';
import 'home_view.dart';
import 'login_view.dart';

class SessionWrapper extends StatelessWidget {
  const SessionWrapper({super.key});

  /*
  @Deprecated('This bypasses our AuthService')
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AuthState>(
      stream: Supabase.instance.client.auth.onAuthStateChange,
      builder: (context, snapshot) {
        final session = Supabase.instance.client.auth.currentSession;

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        return session == null ? const LoginView() : const HomeView();
      },
    );
  }
  */

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthService>(
      builder: (context, auth, _) {
        // Read the userId from the auth service, iff session is valid then 
        // create the user session scoped subtree where userId is immutable.
        final uid = auth.user?.id;

        if (uid == null) {
          return const LoginView();
        }

        return MultiProvider(
          key: ValueKey('session-$uid'),
          providers: [
            Provider(
              create:
                  (context) => LocalPhotoService(
                    context.read<PathService>(),
                    uid,
                  ),
              dispose: (_, service) {
                service.dispose();
              },
            ),
            Provider(
              create:
                  (context) => StorageService(
                    Supabase.instance.client,
                    context.read<ExifService>(),
                    context.read<GroupService>(),
                    context.read<ImageService>(),
                    context.read<LocalPhotoService>(),
                  ),
            ),
            Provider(
              create:
                  (context) => ProfileService(
                    Supabase.instance.client,
                    uid,
                  ),
              dispose: (_, service) {
                service.dispose();
              },
            ),
            Provider<GallerySyncService>(
              create:
                  (context) => SupabaseGallerySyncService(
                    userId: uid,
                    supabase: Supabase.instance.client,
                    groupService: context.read<GroupService>(),
                    logger: logger,
                  ),
              dispose: (_, service) {
                service.dispose();
              },
            ),
            ChangeNotifierProvider(
              create:
                  (context) => HomeViewModel(
                    context.read<AuthService>(),
                    context.read<LocalPhotoService>(),
                  ),
            ),
            ChangeNotifierProvider(
              create:
                  (context) => ProfileViewModel(
                    context.read<ProfileService>(),
                    context.read<GroupService>(),
                  ),
            ),
            ChangeNotifierProvider(
              create:
                  (context) => CameraRollViewModel(
                    uid,
                    context.read<LocalPhotoService>(),
                    context.read<StorageService>(),
                  ),
            ),
            ChangeNotifierProvider(
              create:
                  (context) => GalleryViewModel(
                    uid,
                    context.read<LocalPhotoService>(),
                    context.read<StorageService>(),
                    context.read<GallerySyncService>(),
                  ),
            ),
            ChangeNotifierProvider(
              create:
                  (context) => CameraViewModel(
                    context.read<LocalPhotoService>(),
                    context.read<PhotoLocationService>(),
                  ),
            ),
          ],
          child: const HomeView(),
        );
      },
    );
  }
}

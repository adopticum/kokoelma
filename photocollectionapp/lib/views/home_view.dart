import 'package:flutter/material.dart';
import 'package:photocollectionapp/services/local_photo_service.dart';
import 'package:photocollectionapp/views/gallery_view.dart';
import 'package:provider/provider.dart';
import '../viewmodels/home_viewmodel.dart';
import 'camera_view.dart';
import 'profile_view.dart';
import 'camera_roll_view.dart';

class HomeView extends StatefulWidget {
  const HomeView({super.key});

  @override
  State<HomeView> createState() => _HomeViewState();
}

class _HomeViewState extends State<HomeView> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  void _openDrawer() => _scaffoldKey.currentState?.openDrawer();

  List<Widget> get _pages => <Widget>[
    const Icon(Icons.camera, size: 150), // dummy
    const ProfilePage(),
    const CameraRollView(),
    const GalleryView(), //placeholder: Icon(Icons.photo_library, size: 150),
  ];

  Future<void> _importImage(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final vm = context.read<HomeViewModel>();

    final result = await vm.importImage();

    if (!mounted) return;

    final statusText = (result == ImportResult.success)
      ? "Imported successful" : "Import failed";

    messenger.showSnackBar(SnackBar(content: Text(statusText)));
  }

  // Dont add a floating button in the camera ui, but do it everywhere else
  List<Widget> _mainScreen(BuildContext context, HomeViewModel viewModel) {
    List<Widget> widgetList;
    if (viewModel.pageIndex == 0) {
      widgetList = [CameraView(onMenuPressed: _openDrawer)];
    } else {
      widgetList = [
        _pages[viewModel.pageIndex],
        Positioned(
          bottom: 16,
          left: 16,
          child: FloatingActionButton(
            mini: true,
            onPressed: () => _scaffoldKey.currentState?.openDrawer(),
            child: const Icon(Icons.menu),
          ),
        ),
      ];
    }
    return widgetList;
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<HomeViewModel>(
      builder: (context, vm, _) {
        return Scaffold(
          key: _scaffoldKey,
          drawer: Drawer(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                const DrawerHeader(
                  decoration: BoxDecoration(color: Colors.blue),
                  child: Text('Photo Collection App'),
                ),
                ListTile(
                  leading: const Icon(Icons.camera),
                  title: const Text('Camera'),
                  onTap: () {
                    vm.setPageIndex(0);
                    _scaffoldKey.currentState?.closeDrawer();
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.file_upload),
                  title: const Text('Import'),
                  onTap: vm.isImporting ? null : () => _importImage(context),
                ),
                ListTile(
                  leading: const Icon(Icons.camera_roll),
                  title: const Text('My photos'),
                  onTap: () {
                    vm.setPageIndex(2);
                    _scaffoldKey.currentState?.closeDrawer();
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.photo_library),
                  title: const Text('Group gallery'),
                  onTap: () {
                    vm.setPageIndex(3);
                    _scaffoldKey.currentState?.closeDrawer();
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.person),
                  title: const Text('User profile'),
                  onTap: () {
                    vm.setPageIndex(1);
                    _scaffoldKey.currentState?.closeDrawer();
                  },
                ),
                Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.logout),
                    label: const Text('Logout'),
                    onPressed: () async {
                      await vm.signOut();
                    },
                  ),
                ),
              ],
            ),
          ),
          body: SafeArea(
            child: Stack(children: _mainScreen(context, vm)),
          ),
        );
      },
    );
  }
}

import 'package:flutter_test/flutter_test.dart';
import 'package:photocollectionapp/models/photo_local.dart';
import 'package:photocollectionapp/viewmodels/photos_viewmodel.dart';
import 'package:photocollectionapp/viewmodels/camera_roll_viewmodel.dart';

void main() {
  test('groups photos into Today, Yesterday, Past 7 days, and month buckets', () {
    final now = DateTime.now();

    final photos = [
      LocalPhoto(
        userid: 'user',
        capturedAt: DateTime(now.year, now.month, now.day, 10),
        fullPath: '/tmp/a.jpg',
        miniPath: '/tmp/a.jpg',
      ),
      LocalPhoto(
        userid: 'user',
        capturedAt: DateTime(now.year, now.month, now.day - 1, 9),
        fullPath: '/tmp/b.jpg',
        miniPath: '/tmp/b.jpg',
      ),
      LocalPhoto(
        userid: 'user',
        capturedAt: DateTime(now.year, now.month, now.day - 4, 8),
        fullPath: '/tmp/c.jpg',
        miniPath: '/tmp/c.jpg',
      ),
      LocalPhoto(
        userid: 'user',
        capturedAt: DateTime(now.year, now.month - 1, 15, 7),
        fullPath: '/tmp/d.jpg',
        miniPath: '/tmp/d.jpg',
      ),
    ];

    final items =
        photos
            .map(
              (photo) => PhotoItem(
                photo: photo,
                isUploaded: false,
                isLocal: true,
                isMine: true,
              ),
            )
            .toList();

    final sections = CameraRollViewModel.groupPhotosByDate(items);

    expect(sections.map((section) => section.title).toList(), [
      'Today',
      'Yesterday',
      'Past 7 days',
      'Previous month',
    ]);
  });
}

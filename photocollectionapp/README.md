# Adopticum Photo Collection App

A Flutter application for capturing, processing with AI, and securely storing photos using Supabase and ONNX runtime.

## Key Features

- **AI Image Analysis**: Uses an ONNX model to detect objects in captured photos directly on the device (mobile or web).
- **Secure Storage**: Photos are uploaded to a private Supabase storage bucket, organized by user ID.
- **Automatic Metadata Extraction**: Extracts GPS coordinates from EXIF data and timestamps from filenames before upload.
- **Optimized Uploads**: Automatically resizes and compresses images to fit within size limits (default 900KB) while preserving quality as much as possible.
- **Gallery View**: Browse previously captured photos with thumbnails, sorted by capture time.
- **Theme Support**: Light and dark mode support via `ThemeViewModel`.

## Architecture Overview (MVVM + Provider)

The app follows the MVVM pattern using Flutter's `Provider` for state management:

### 1. Model Layer
Represents data structures used throughout the application:
- `CapturedPhoto`: Represents a photo with its path, URL, thumbnail URL, and timestamp.
- `PhotoMetadata`: Contains filename, timestamp, latitude, and longitude.
- `Profile`: User profile information from Supabase.

### 2. ViewModel Layer (State Management)
Mantains UI state and coordinates between views and services:
- `AuthViewModel`: Manages user authentication state via `AuthService`.
- `HomeViewModel`: Handles home screen navigation and state.
- `ImagePreviewViewModel`: Orchestrates ONNX inference on selected images, managing loading states and detection results.
- `CameraRollViewModel`: Fetches and manages the list of uploaded photos from `StorageService`.
- `ThemeViewModel`: Manages light/dark theme switching.

### 3. Service Layer (Business Logic & External APIs)
Encapsulates all external interactions:
- `AuthService`: Wraps Supabase authentication operations.
- `ExifService`: Reads and writes GPS coordinates to photo EXIF data using the `native_exif` package.
- `OnnxRunner`: Abstract interface for running ONNX models, with platform-specific implementations (`OnnxRunnerMobile`, `OnnxRunnerWeb`).
- `PermissionService`: Handles requesting camera and location permissions with user guidance.
- `ProfileService`: Mantains user profile data in Supabase.
- `StorageService`: Coordinates photo uploads to Supabase Storage (including thumbnail generation) and metadata insertion into the database.

### 4. View Layer (UI Components)
Flutter widgets that observe ViewModels:
- `SplashView`: Handles app initialization and authentication state check.
- `LoginView`: User authentication interface.
- `HomeView`: Main navigation hub.
- `CameraView`: Uses `camerawesome` for photo capture with EXIF metadata embedding.
- `ImagePreviewView`: Displays selected photos, shows detection results from ONNX inference, and displays image metadata.
- `CameraRollView`: Gallery of previously uploaded photos.
- `ProfileView`: User profile management.

## Project Structure

```text
lib/
├── models/             # Data structures (CapturedPhoto, PhotoMetadata, Profile)
├── services/           # External service wrappers (Auth, Exif, OnnxRunner, Permission, Profile, Storage)
├── theme/              # Custom app themes
├── utils/              # Helpers and constants (Logger, Secrets, BoundingBoxPainter)
├── viewmodels/         # State management classes (Auth, CameraRoll, Home, ImagePreview, Theme)
├── views/              # UI screens (Camera, CameraRoll, Gallery, Home, ImagePreview, Login, Profile, SessionWrapper, Splash)
└── main.dart           # App entry point and dependency injection setup

assets/
├── images/             # Static assets like logos
└── onnx_models/        # ONNX model files for inference (Do not save to git repo.)
```

## Installation & Setup

### Prerequisites
- Flutter SDK installed
- Supabase project 'kokoelma' with authentication enabled. Adjust URL:s and keys for your project.

### Configuration
1. Create a `.env` file or update `lib/utils/secrets.dart` with your Supabase URL and publishable key:
   ```dart
   // lib/utils/secrets.dart
   class Secrets {
     static const String projectUrl = 'YOUR_SUPABASE_PROJECT_URL';  //kokoelma
     static const String publishableKey = 'YOUR_SUPABASE_PUBLISHABLE_KEY';
   }

   ```

### Running the App
```bash
flutter pub get
flutter run
```

To run on a tethered device (e.g. an iPhone).

```bash
flutter run -d MyPhone
```

## Key Implementation Details

### ONNX Inference Pipeline
1. `ImagePreviewViewModel` receives image bytes from the UI.
2. It calls `OnnxRunner.detect(bytes)`.
3. On mobile, this runs in a separate **Isolate** to avoid blocking the main thread during heavy computation.
4. The model (e.g., `log_ends.onnx`) performs object detection and returns bounding boxes, scores, and class IDs.
5. Results are rendered on top of the image using `BoundingBoxPainter`.

### Storage & Upload Workflow
1. Photo captured via `CameraView` with EXIF GPS data embedded.
2. `StorageService.uploadAndRecord(file)` is called:
   - Parses filename for timestamp and reads EXIF for location.
   - Compresses image to fit within the size limit of the backend, using binary search on JPEG quality/scale. Default 900KB.
   - Generates a thumbnail (300px width).
   - Uploads both original and thumbnail to Supabase Storage.
   - Inserts metadata record into a database table for photo metadata in the public schema.

### Security & Permissions
- **Supabase RLS**: All storage access and database operations rely on Row Level Security policies based on the authenticated user's ID.
- **Permissions**: The app explicitly requests camera and location permissions, guiding users to settings if denied permanently via `PermissionService`.

## Realtime updates
The Supabase backend and the app support realtime push events. 
Changes made on the backend trigger push events to a subscribed app.
This is set per table and in controlled by RLS policies (specifically SELECT privileges).

## Development Commands

| Command | Description |
|---------|-------------|
| `flutter pub get` | Install dependencies |
| `dart run rename_app:main all="Adopticum Photo Collector"` | Rename the app name |
| `flutter pub run change_app_package_name:main com.adopticum.photocollectionapp` | Change package name |
| `dart run flutter_launcher_icons` | Generate app icons from assets |

---
*Developed by Adopticum.*
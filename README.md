# SecureTrack

A secure employee attendance management system built with Flutter, featuring multi-layered validation and real-time monitoring capabilities.

## About

SecureTrack is a Flutter-based Android attendance app that provides a complete solution for workplace attendance management. It uses Riverpod for state management, GoRouter for navigation, and Firebase as the backend.

## Features

### Authentication & Security
- **Unified login system** that automatically detects user roles (Admin/Employee)
- **Admin registration** protected with unique admin codes
- **Device binding** — each employee account is linked to a single device ID to prevent unauthorized access

### Attendance Tracking
- **WiFi IP validation** to verify employees are on the company network
- **GPS location verification** to confirm physical presence at the workplace
- **QR code backup** method for emergency check-in situations

### Admin Dashboard
- Live attendance monitoring
- Employee management (add/edit/delete)
- Real-time data visualization from Firebase

### Employee Dashboard
- Check-in and check-out
- Leave requests
- Attendance history

### Additional Features
- **Profile management** with photo upload, displaying real user data from Firestore
- **Dark mode & light mode** with a navy blue and white color scheme and persistent theme preferences

## Tech Stack

| Layer              | Technology                        |
| ------------------ | --------------------------------- |
| Framework          | Flutter                           |
| Language           | Dart                              |
| State Management   | Riverpod                          |
| Navigation         | GoRouter                          |
| Backend            | Firebase (Auth, Firestore, Storage) |
| Architecture       | MVVM                              |

## Project Structure

```
lib/
├── main.dart
├── app.dart
├── firebase_options.dart
├── core/
│   ├── constants/
│   ├── firebase/
│   ├── router/
│   ├── theme/
│   └── widgets/
└── features/
    ├── auth/          # Login, registration, role detection
    ├── attendance/    # Check-in/out with WiFi + GPS validation
    ├── dashboard/     # Admin & employee dashboards
    ├── leave/         # Leave request system
    ├── profile/       # User profile management
    └── splash/        # Splash screen
```

## Getting Started

1. **Clone the repository**
   ```bash
   git clone <repository-url>
   ```

2. **Install dependencies**
   ```bash
   flutter pub get
   ```

3. **Configure Firebase**
   - Set up a Firebase project and add your `google-services.json` (Android) or `GoogleService-Info.plist` (iOS)

4. **Run the app**
   ```bash
   flutter run
   ```

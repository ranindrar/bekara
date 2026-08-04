# Panduan Belajar dan Persiapan Development

## Bekara — Flutter, Drift/SQLite, dan Supabase

| Informasi | Nilai |
|---|---|
| Target pembaca | Product owner/tester dengan latar belakang Java |
| Platform development awal | Windows |
| Platform aplikasi awal | Android |
| IDE utama | Android Studio |
| Mobile | Flutter dan Dart |
| Database lokal | Drift/SQLite |
| Backend | Supabase Free/PostgreSQL |

## 1. Tujuan panduan

Panduan ini menjelaskan perangkat yang harus disiapkan, konsep yang perlu dipahami, cara menjalankan aplikasi, dan pengetahuan minimum untuk melakukan review. Product owner tidak diwajibkan menulis atau mengubah kode.

## 2. Pembagian peran

### Product owner/tester

- Menjelaskan kebutuhan menggunakan bahasa sehari-hari dan contoh nyata.
- Memilih keputusan produk ketika terdapat beberapa alternatif.
- Menjalankan build aplikasi pada perangkat.
- Menguji skenario dan melaporkan hasil aktual.
- Menyetujui atau menolak acceptance criteria.
- Menyediakan akun/akses eksternal yang memang memerlukan kepemilikan pribadi.

### Codex/developer

- Mengubah kebutuhan menjadi specification dan acceptance criteria.
- Membuat serta mengubah source code.
- Menulis migration, RLS policy, RPC, dan seed data.
- Menulis unit, widget, integration, dan database test.
- Menjalankan pemeriksaan otomatis yang tersedia.
- Menyiapkan APK atau instruksi build.
- Menjelaskan perubahan dan risiko tanpa meminta product owner menyentuh kode.
- Memperbaiki bug berdasarkan hasil pengujian.

## 3. Perangkat yang dibutuhkan

### Wajib untuk Android

1. Windows 10/11 64-bit.
2. Git for Windows.
3. Flutter SDK stable.
4. Android Studio.
5. Plugin Flutter dan Dart di Android Studio.
6. Android SDK, Platform Tools, dan Command-line Tools.
7. Android Emulator atau ponsel Android dengan USB debugging.
8. Akun Supabase gratis.
9. Browser modern.

Flutter SDK sebaiknya diletakkan pada path tanpa spasi dan tanpa kebutuhan administrator, misalnya:

```text
C:\Development\flutter
```

Hindari `C:\Program Files\flutter`.

### Opsional

- Docker Desktop untuk menjalankan Supabase secara lokal.
- Supabase CLI untuk migration dan local stack.
- DBeaver atau PostgreSQL client untuk inspeksi database; Supabase Studio sudah cukup untuk awal.
- Perangkat Android kedua untuk menguji sinkronisasi suami–istri.

Docker tidak wajib untuk tahap awal. Aplikasi dapat memakai project Supabase Free yang di-host.

## 4. Pemeriksaan instalasi

Perintah utama:

```powershell
flutter doctor -v
flutter devices
flutter --version
dart --version
```

Kondisi siap Android:

- Flutter ditemukan pada PATH.
- Android toolchain berstatus berhasil.
- Android license sudah diterima.
- Android Studio terdeteksi.
- Minimal satu emulator atau perangkat terdeteksi.

## 5. IDE

Android Studio menjadi pilihan utama karena familiar bagi developer Java dan menyediakan Android SDK Manager, emulator, debugger, Flutter Inspector, serta DevTools. IntelliJ IDEA atau VS Code boleh digunakan, tetapi Android Studio tetap diperlukan untuk pengelolaan toolchain Android.

Plugin yang dibutuhkan:

- Flutter.
- Dart, biasanya ikut terpasang bersama Flutter plugin.

## 6. Peta konsep Java ke Dart/Flutter

| Java/Spring | Dart/Flutter/Supabase |
|---|---|
| Maven/Gradle dependency | `pubspec.yaml` |
| POJO/record | Dart class/immutable model |
| `CompletableFuture<T>` | `Future<T>` |
| Reactive stream | `Stream<T>` |
| JUnit | `package:test` / `flutter_test` |
| JPA/DAO | Drift DAO/repository |
| Flyway | Drift dan Supabase SQL migrations |
| Spring Security | Supabase Auth + PostgreSQL RLS |
| Service transaction | PostgreSQL RPC/function |
| JavaFX/Swing component | Flutter Widget |
| Controller mengubah view | State berubah lalu widget rebuild |

## 7. Materi yang perlu dipahami

Product owner cukup memahami gambaran umum. Pendalaman diperlukan hanya jika ingin ikut melakukan code review.

### Dart

- Variable, class, constructor, dan generic.
- `final` versus `const`.
- Sound null safety: `String` versus `String?`.
- Named dan optional parameter.
- `Future`, `async`, dan `await`.
- `Stream`.
- Exception handling.
- Sealed class, record, dan pattern matching.

Hindari penggunaan berlebihan `dynamic` dan operator `!`.

### Flutter

- Widget sebagai deskripsi UI.
- Widget tree dan immutable widget.
- `StatelessWidget` dan consumer widget.
- Layout: `Row`, `Column`, `Stack`, `ListView`.
- Form dan validation.
- Routing melalui GoRouter.
- State management melalui Riverpod.
- Theme, responsive layout, dan accessibility.
- Hot reload, debugger, Flutter Inspector, dan DevTools.

### Drift/SQLite

- Table dan column.
- Generated row dan companion.
- DAO dan repository.
- Reactive query dengan `watch()`.
- Transaction dan batch.
- Schema version serta migration.
- Index dan query plan dasar.
- In-memory database test.
- Background isolate untuk operasi database.

Drift menggunakan code generation:

```powershell
dart run build_runner build
dart run build_runner watch
```

### Supabase/PostgreSQL

- Project dan environment.
- Supabase Auth.
- Table, constraint, foreign key, dan index.
- SQL migration.
- Row Level Security dan policy.
- Publishable key versus service-role key.
- PostgreSQL function/RPC dan transaction.
- Realtime sebagai sinyal perubahan.
- Backup dan restore.

Aturan keamanan utama:

```text
Publishable/anon key -> boleh digunakan aplikasi
Service-role key     -> tidak boleh ditanam di aplikasi
```

## 8. Struktur aplikasi yang direncanakan

```text
bekara/
├── android/
├── ios/
├── lib/
│   ├── app/
│   ├── core/
│   │   ├── database/
│   │   ├── sync/
│   │   ├── errors/
│   │   └── utils/
│   ├── features/
│   │   ├── auth/
│   │   ├── household/
│   │   ├── wallet/
│   │   ├── transaction/
│   │   ├── period/
│   │   └── dashboard/
│   └── main.dart
├── test/
├── integration_test/
├── supabase/
│   ├── migrations/
│   ├── tests/
│   ├── seed.sql
│   └── config.toml
├── docs/
├── pubspec.yaml
└── analysis_options.yaml
```

UI tidak boleh mengakses Drift atau Supabase secara langsung. Akses melewati controller/use case/repository agar offline dan remote dapat diuji terpisah.

## 9. Menjalankan aplikasi

```powershell
flutter pub get
dart run build_runner build
flutter doctor -v
flutter devices
flutter run
```

Menjalankan test:

```powershell
flutter test
```

Membuat APK:

```powershell
flutter build apk --debug
flutter build apk --release
```

Konfigurasi Supabase diberikan melalui environment/build define dan tidak ditulis permanen dalam source:

```powershell
flutter run --dart-define=SUPABASE_URL=<url> --dart-define=SUPABASE_PUBLISHABLE_KEY=<key>
```

## 10. Supabase local development

Jika local stack digunakan, install Supabase CLI dan Docker-compatible runtime:

```powershell
supabase init
supabase start
supabase db reset
```

Migration dan seed wajib masuk version control. Project local hanya untuk development dan tidak diekspos ke internet.

## 11. Batasan platform

- Android dapat dibangun dan diuji dari Windows.
- Web dan Windows desktop dapat dijalankan bila diperlukan, tetapi bukan target awal.
- iOS hanya dapat dibangun menggunakan macOS dan Xcode.
- Release awal disarankan Android agar pengembangan lebih cepat.

## 12. Urutan belajar yang disarankan

| Tahap | Fokus | Hasil minimum |
|---|---|---|
| 1 | Dart | Memahami model, null safety, Future, Stream |
| 2 | Flutter | Memahami widget, form, navigation, Riverpod |
| 3 | Drift | Memahami local table, DAO, migration, reactive query |
| 4 | Supabase | Memahami Auth, PostgreSQL, RLS, RPC |
| 5 | Integrasi | Memahami repository, offline queue, idempotensi, conflict |

Jangan mempelajari seluruh stack sekaligus melalui fitur produksi. Mulai dari transaksi lokal dengan Drift, kemudian Auth/Supabase, lalu sinkronisasi dua perangkat.

## 13. Referensi resmi

- [Install Flutter](https://docs.flutter.dev/install)
- [Flutter Android on Windows](https://docs.flutter.dev/get-started/install/windows/mobile)
- [Dart language](https://dart.dev/language)
- [Dart null safety](https://dart.dev/null-safety)
- [Drift setup](https://drift.simonbinder.eu/setup/)
- [Drift supported platforms](https://drift.simonbinder.eu/platforms/)
- [Supabase Flutter quickstart](https://supabase.com/docs/guides/getting-started/quickstarts/flutter)
- [Supabase local development](https://supabase.com/docs/guides/local-development/overview)
- [Flutter iOS setup](https://docs.flutter.dev/platform-integration/ios/setup)

# Flutter web client

Requires the [Flutter SDK](https://docs.flutter.dev/get-started/install).
FlowDo ships a web client only — the `web/` project directory is committed, so
no `flutter create` step is needed.

```bash
flutter pub get
flutter run -d chrome
```

Release build (CanvasKit is bundled instead of loaded from the Google CDN):

```bash
flutter build web --release --no-web-resources-cdn
```

The client always calls API paths on the current origin. In production,
`web/nginx.conf` proxies those paths to the API container. The login page only
asks for the instance password. A fresh database has no password until the first
visit, which asks you to choose one and confirm it.

Reminders, crontab recurrence and lunar dates are implemented in the web client
(`lib/widgets/reminder_time_picker.dart`, `lib/utils/cron.dart`, `lib/utils/lunar.dart`).

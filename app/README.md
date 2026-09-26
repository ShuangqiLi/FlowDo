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
asks for a username and password; accounts are created from the deployment host.

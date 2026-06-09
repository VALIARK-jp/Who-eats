# who_eats_app

Who eats UI prototype built with Flutter (clean architecture + mock-first).

## 開発セットアップ

- **秘密・`.env` の運用（Valiark 共通）:** [docs/valiark_client_secrets_playbook.md](docs/valiark_client_secrets_playbook.md)
- **push 通知の prod 接続:** [docs/push_notification_prod_setup.md](docs/push_notification_prod_setup.md)
- **valiark-prod / prod 接続と build:** [docs/16_valiark_prod_who_eats_setup.md](docs/16_valiark_prod_who_eats_setup.md)
- **環境値の優先順位:** `--dart-define=KEY=value` を付けた場合は、ルートの `.env` より優先（`lib/src/core/config/app_config.dart` の `AppConfig`）。
- **初回:** `cp .env.example .env` で `.env` を作る（`pubspec.yaml` の asset に含まれるため必須）。または [scripts/flutter_run_dev.sh](scripts/flutter_run_dev.sh) が無ければ自動コピーしてから `flutter run`。
- **prod:** `cp .env.prod.example .env.prod` のうえ、[scripts/flutter_run_prod.sh](scripts/flutter_run_prod.sh) / [scripts/flutter_build_prod.sh](scripts/flutter_build_prod.sh) を使う。

## Map API integration (pins + place detail)

The map screen fetches map pins and place detail from external APIs and
automatically falls back to mock data when the API is unavailable.

### Run with map APIs (via `.env` or `--dart-define`)

```bash
cp .env.example .env
# Edit .env values

flutter run
```

CI や一時試行では `.env` を触らずに上書きできる例:

```bash
flutter run \
  --dart-define=WHOEATS_SUPABASE_URL=https://xxx.supabase.co \
  --dart-define=WHOEATS_SUPABASE_ANON_KEY=eyJ...
```

`WHOEATS_GOOGLE_MAPS_WEB_API_KEY` is used for direct Google API trials:
- Maps SDK (map rendering in app)
- Places Nearby Search (map pins)
- Place Details (address/rating/phone/opening)
- Places Autocomplete (post editor place suggestions)
- Directions API (walking minutes in place sheet)
- Places Photos (detail hero image)

Native Maps SDK keys are also read from `.env`:
- `WHOEATS_IOS_MAPS_API_KEY` (iOS `GMSServices.provideAPIKey`)
- `WHOEATS_ANDROID_MAPS_API_KEY` (Android manifest placeholder)

### Pins API format (`GET /map/pins`)

Either of the following is accepted:

```json
[
  {
    "id": "m1",
    "placeName": "and people udagawa",
    "rating": 4.6,
    "friendComment": "Great vibe",
    "imageUrl": "https://...",
    "isFriendVisited": true,
    "friendAvatars": ["H", "R", "M"],
    "latitude": 35.6595,
    "longitude": 139.7005
  }
]
```

or:

```json
{
  "data": [
    {
      "id": "m1",
      "place_name": "and people udagawa",
      "rating": 4.6,
      "friend_comment": "Great vibe",
      "image_url": "https://...",
      "is_friend_visited": true,
      "friend_avatars": ["H", "R", "M"],
      "lat": 35.6595,
      "lng": 139.7005
    }
  ]
}
```

If the API returns an error or unexpected format, map pins are served from mock
data so the screen remains usable.

### Place detail API format (`GET /places/{placeId}`)

Accepted response:

```json
{
  "placeId": "m1",
  "placeName": "and people udagawa",
  "rating": 4.6,
  "friendComment": "Great vibe",
  "imageUrl": "https://...",
  "posts": [
    {
      "id": "pp1",
      "userName": "haruka",
      "comment": "ライト暗めで写真映えした！"
    }
  ]
}
```

or:

```json
{
  "data": {
    "place_id": "m1",
    "place_name": "and people udagawa",
    "rating": 4.6,
    "friend_comment": "Great vibe",
    "image_url": "https://...",
    "posts": [
      {
        "id": "pp1",
        "user_name": "haruka",
        "comment": "ライト暗めで写真映えした！"
      }
    ]
  }
}
```

# zsoltscores

Modern élő sporteredmény követő Flutter alkalmazás (StatPal V2).

## Fejlesztések (2026-11-22)

- Kedvenc meccsek tartós mentése (SharedPreferences)
- Jobb offline / cache élmény (hiba esetén utolsó ismert adatok megőrzése)
- Helyi értesítések (flutter_local_notifications) gólokra, piros lapokra, meccsvégekre
- Jobb üres állapotok a Meccsek és Kedvencek fülön

## Futtatás

```bash
flutter pub get
flutter run
```

Android/iOS értesítésekhez további platform konfiguráció szükséges (AndroidManifest, Info.plist).

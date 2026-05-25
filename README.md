# Kinopoisk

A production-ready Flutter movie app inspired by Kinopoisk: dark cinematic UI, Firebase Authentication, Firestore real-time sync, Storage avatars, favorites, watchlists, reviews, search, tickets, trailers, people pages, news, profile editing, and polished Material 3 UX.

## Run

```bash
flutter pub get
flutter run
```

Verified locally:

```bash
flutter analyze
flutter build apk --debug
```

## Firebase Setup

The app is already wired with `lib/firebase_options.dart` and `android/app/google-services.json` for the included demo Firebase project. In Firebase Console enable:

- Authentication: Email/Password and Google
- Cloud Firestore
- Firebase Storage

Deploy Firestore rules:

```bash
firebase deploy --only firestore:rules
```

For a different Firebase project, run:

```bash
dart pub global activate flutterfire_cli
flutterfire configure
```

Then replace `android/app/google-services.json` and `lib/firebase_options.dart`.

The splash screen safely falls back to bundled movie data if Firestore is empty or unavailable. After signing in, movie data can be seeded into the `movies` collection.

## Features

- Splash and onboarding
- Login, registration, Google Sign-In, logout, persistent sessions
- Home hero carousel plus Kinopoisk-style hub: Tasks, Films, Genres, Online cinema, Premieres, Top 250, Series, Tickets, Cinemas, Calendar, Awards, Ratings, Reviews, People, News
- Movie details with backdrop, poster, genres, rating, cast, trailer, tickets, similar movies
- Favorites, watchlists, watchlist details, reviews with delete, profile editing, avatar upload
- Personal movie ratings saved to Firestore, global reviews feed, genre pages, cinema schedule, release calendar, awards page
- Marking-scheme task screen: Google/Email auth entry, add/complete/delete tasks, real-time Firestore task sync, filters, live stats bar, personal identity block, starter tasks
- History, notifications, subscription, achievements, support, privacy, about, settings
- Real-time Firestore streams through Riverpod
- Debounced search with suggestions and local search history
- Material 3, Google Fonts, cached images, blur panels, transitions
- Android package configured with Kotlin, Google Services, internet/network permissions, multidex, and a cinematic native splash theme

## Screens / Routes

The app contains 20+ real app screens based on common Kinopoisk sections:

Splash, onboarding, login, registration, home, tasks, films catalog, genres, genre details, online cinema, premieres, Top 250, series, tickets, cinemas, release calendar, awards, my ratings, reviews feed, people, person profile, news, article, movie details, trailer, ticket checkout, reviews, search, favorites, watchlists, watchlist details, profile, edit profile, history, notifications, subscription, achievements, support, privacy, about, settings.

## Marking Scheme Coverage

- Google Sign-In works correctly: implemented through Firebase Auth and Google Sign-In.
- Email/password registration and login: implemented through Firebase Auth.
- Add / complete / delete tasks: implemented in `/tasks`.
- Firestore real-time sync: task, movie, favorite, watchlist, review, history, profile, and identity streams use Firestore.
- Filters and live stats bar: implemented in `/tasks` with All / Active / Done filters and live All / Active / Done / progress stats.
- Personal identity block: implemented in `/tasks` with name, IIN, color, and starter tasks.
- UI quality: dark Kinopoisk-style Material 3 UI with cached posters, cards, loading/error/empty states, and smooth navigation.

## Firestore Collections

- `movies`
- `users`
- `favorites`
- `watchlists`
- `reviews`
- `users/{uid}/history`

## Project Notes

All Flutter platform folders are present: `android`, `ios`, `web`, `linux`, `macos`, `windows`, plus `lib` and `test`.

The main app code currently lives in `lib/main.dart` for easy teacher review, with clear layers inside the file: providers, routing, models, repository, screens, and shared UI components.

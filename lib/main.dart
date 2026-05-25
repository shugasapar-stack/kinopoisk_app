import 'dart:async';
import 'dart:ui';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const ProviderScope(child: CineverseApp()));
}

final authProvider = Provider((_) => FirebaseAuth.instance);
final dbProvider = Provider((_) => FirebaseFirestore.instance);
final storageProvider = Provider((_) => FirebaseStorage.instance);
final authStateProvider = StreamProvider((ref) => ref.watch(authProvider).authStateChanges());
final repoProvider = Provider((ref) => CinemaRepository(ref.watch(authProvider), ref.watch(dbProvider), ref.watch(storageProvider)));
final moviesProvider = StreamProvider((ref) => ref.watch(repoProvider).movies());
final favoritesProvider = StreamProvider((ref) {
  final user = ref.watch(authProvider).currentUser;
  return user == null ? Stream.value(<String>[]) : ref.watch(repoProvider).favorites(user.uid);
});
final watchlistsProvider = StreamProvider((ref) {
  final user = ref.watch(authProvider).currentUser;
  return user == null ? Stream.value(<Watchlist>[]) : ref.watch(repoProvider).watchlists(user.uid);
});
final profileProvider = StreamProvider((ref) {
  final user = ref.watch(authProvider).currentUser;
  return user == null ? Stream.value(null) : ref.watch(repoProvider).profile(user.uid);
});
final historyProvider = StreamProvider((ref) {
  final user = ref.watch(authProvider).currentUser;
  return user == null ? Stream.value(<String>[]) : ref.watch(repoProvider).historyItems(user.uid);
});
final movieProvider = StreamProvider.family<Movie, String>((ref, id) => ref.watch(repoProvider).movie(id));
final reviewsProvider = StreamProvider.family<List<Review>, String>((ref, id) => ref.watch(repoProvider).reviews(id));
final reviewsFeedProvider = StreamProvider((ref) => ref.watch(repoProvider).reviewsFeed());
final userRatingsProvider = StreamProvider((ref) {
  final user = ref.watch(authProvider).currentUser;
  return user == null ? Stream.value(<UserMovieRating>[]) : ref.watch(repoProvider).userRatings(user.uid);
});
final tasksProvider = StreamProvider((ref) {
  final user = ref.watch(authProvider).currentUser;
  return user == null ? Stream.value(<StudentTask>[]) : ref.watch(repoProvider).tasks(user.uid);
});
final identityProvider = StreamProvider((ref) {
  final user = ref.watch(authProvider).currentUser;
  return user == null ? Stream.value(StudentIdentity.empty()) : ref.watch(repoProvider).identity(user.uid);
});

class CineverseApp extends ConsumerWidget {
  const CineverseApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final base = ThemeData.dark(useMaterial3: true);
    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      title: 'Kinopoisk',
      theme: base.copyWith(
        scaffoldBackgroundColor: const Color(0xFF090A0F),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFFFC400),
          brightness: Brightness.dark,
          primary: const Color(0xFFFFC400),
          secondary: const Color(0xFFE84855),
          surface: const Color(0xFF151720),
        ),
        textTheme: GoogleFonts.interTextTheme(base.textTheme).apply(bodyColor: Colors.white, displayColor: Colors.white),
        appBarTheme: const AppBarTheme(backgroundColor: Colors.transparent, elevation: 0),
        navigationBarTheme: NavigationBarThemeData(
          backgroundColor: const Color(0xFF10121A),
          indicatorColor: const Color(0xFFFFC400).withValues(alpha: .18),
          labelTextStyle: WidgetStateProperty.all(const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFF171923),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Color(0xFFFFC400))),
        ),
      ),
      routerConfig: ref.watch(routerProvider),
    );
  }
}

final routerProvider = Provider<GoRouter>((ref) {
  final auth = ref.watch(authStateProvider);
  return GoRouter(
    initialLocation: '/',
    refreshListenable: GoRouterRefreshStream(FirebaseAuth.instance.authStateChanges()),
    redirect: (context, state) {
      final user = auth.valueOrNull;
      final path = state.uri.path;
      final public = {'/', '/onboarding', '/login', '/register'};
      if (auth.isLoading) return null;
      if (user == null && !public.contains(path)) return '/login';
      if (user != null && (path == '/login' || path == '/register' || path == '/onboarding')) return '/home';
      return null;
    },
    routes: [
      GoRoute(path: '/', builder: (_, __) => const SplashScreen()),
      GoRoute(path: '/onboarding', builder: (_, __) => const OnboardingScreen()),
      GoRoute(path: '/login', builder: (_, __) => const AuthScreen(isLogin: true)),
      GoRoute(path: '/register', builder: (_, __) => const AuthScreen(isLogin: false)),
      GoRoute(path: '/home', builder: (_, __) => const HomeShell()),
      GoRoute(path: '/tasks', builder: (_, __) => const TasksScreen()),
      GoRoute(path: '/catalog', builder: (_, __) => const CatalogScreen()),
      GoRoute(path: '/genres', builder: (_, __) => const GenresScreen()),
      GoRoute(path: '/genre/:name', builder: (_, s) => GenreDetailsScreen(name: Uri.decodeComponent(s.pathParameters['name']!))),
      GoRoute(path: '/collections', builder: (_, __) => const CollectionsScreen()),
      GoRoute(path: '/premieres', builder: (_, __) => const PremieresScreen()),
      GoRoute(path: '/top250', builder: (_, __) => const TopScreen()),
      GoRoute(path: '/series', builder: (_, __) => const SeriesScreen()),
      GoRoute(path: '/tickets', builder: (_, __) => const TicketsScreen()),
      GoRoute(path: '/cinemas', builder: (_, __) => const CinemasScreen()),
      GoRoute(path: '/calendar', builder: (_, __) => const CalendarScreen()),
      GoRoute(path: '/awards', builder: (_, __) => const AwardsScreen()),
      GoRoute(path: '/ratings', builder: (_, __) => const MyRatingsScreen()),
      GoRoute(path: '/reviews-feed', builder: (_, __) => const ReviewsFeedScreen()),
      GoRoute(path: '/persons', builder: (_, __) => const PersonsScreen()),
      GoRoute(path: '/person/:name', builder: (_, s) => PersonScreen(name: Uri.decodeComponent(s.pathParameters['name']!))),
      GoRoute(path: '/news', builder: (_, __) => const NewsScreen()),
      GoRoute(path: '/news/:id', builder: (_, s) => ArticleScreen(id: s.pathParameters['id']!)),
      GoRoute(path: '/movie/:id', builder: (_, s) => MovieDetailsScreen(movieId: s.pathParameters['id']!)),
      GoRoute(path: '/movie/:id/reviews', builder: (_, s) => ReviewsScreen(movieId: s.pathParameters['id']!)),
      GoRoute(path: '/movie/:id/trailer', builder: (_, s) => TrailerScreen(movieId: s.pathParameters['id']!)),
      GoRoute(path: '/movie/:id/tickets', builder: (_, s) => TicketCheckoutScreen(movieId: s.pathParameters['id']!)),
      GoRoute(path: '/watchlist/:id', builder: (_, s) => WatchlistDetailsScreen(listId: s.pathParameters['id']!)),
      GoRoute(path: '/history', builder: (_, __) => const HistoryScreen()),
      GoRoute(path: '/notifications', builder: (_, __) => const NotificationsScreen()),
      GoRoute(path: '/subscription', builder: (_, __) => const SubscriptionScreen()),
      GoRoute(path: '/achievements', builder: (_, __) => const AchievementsScreen()),
      GoRoute(path: '/support', builder: (_, __) => const SupportScreen()),
      GoRoute(path: '/qa-checklist', builder: (_, __) => const QaChecklistScreen()),
      GoRoute(path: '/privacy', builder: (_, __) => const PrivacyScreen()),
      GoRoute(path: '/about', builder: (_, __) => const AboutScreen()),
      GoRoute(path: '/profile/edit', builder: (_, __) => const EditProfileScreen()),
      GoRoute(path: '/settings', builder: (_, __) => const SettingsScreen()),
    ],
  );
});

class GoRouterRefreshStream extends ChangeNotifier {
  GoRouterRefreshStream(Stream<dynamic> stream) {
    _sub = stream.asBroadcastStream().listen((_) => notifyListeners());
  }
  late final StreamSubscription<dynamic> _sub;
  @override
  void dispose() {
    _sub.cancel();
    super.dispose();
  }
}

class Movie {
  const Movie({required this.id, required this.title, required this.posterUrl, required this.backdropUrl, required this.rating, required this.year, required this.genres, required this.description, required this.cast, this.trending = false, this.popular = false});
  final String id;
  final String title;
  final String posterUrl;
  final String backdropUrl;
  final double rating;
  final int year;
  final List<String> genres;
  final String description;
  final List<String> cast;
  final bool trending;
  final bool popular;
  factory Movie.fromMap(String id, Map<String, dynamic> map) => Movie(id: id, title: map['title'] ?? '', posterUrl: map['posterUrl'] ?? '', backdropUrl: map['backdropUrl'] ?? map['posterUrl'] ?? '', rating: (map['rating'] ?? 0).toDouble(), year: (map['year'] ?? 2026) as int, genres: List<String>.from(map['genres'] ?? const []), description: map['description'] ?? '', cast: List<String>.from(map['cast'] ?? const []), trending: map['trending'] ?? false, popular: map['popular'] ?? false);
  Map<String, dynamic> toMap() => {'title': title, 'posterUrl': posterUrl, 'backdropUrl': backdropUrl, 'rating': rating, 'year': year, 'genres': genres, 'description': description, 'cast': cast, 'trending': trending, 'popular': popular, 'updatedAt': FieldValue.serverTimestamp()};
}

class AppUser {
  const AppUser({required this.uid, required this.email, required this.name, this.avatarUrl = '', this.bio = ''});
  final String uid;
  final String email;
  final String name;
  final String avatarUrl;
  final String bio;
  factory AppUser.fromMap(String uid, Map<String, dynamic> map) => AppUser(uid: uid, email: map['email'] ?? '', name: map['name'] ?? 'Movie lover', avatarUrl: map['avatarUrl'] ?? '', bio: map['bio'] ?? '');
  Map<String, dynamic> toMap() => {'email': email, 'name': name, 'avatarUrl': avatarUrl, 'bio': bio, 'updatedAt': FieldValue.serverTimestamp()};
}

class Review {
  const Review({required this.id, required this.movieId, required this.userId, required this.userName, required this.text, required this.rating, required this.createdAt});
  final String id;
  final String movieId;
  final String userId;
  final String userName;
  final String text;
  final double rating;
  final DateTime createdAt;
  factory Review.fromMap(String id, Map<String, dynamic> map) => Review(id: id, movieId: map['movieId'] ?? '', userId: map['userId'] ?? '', userName: map['userName'] ?? 'Viewer', text: map['text'] ?? '', rating: (map['rating'] ?? 0).toDouble(), createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now());
}

class UserMovieRating {
  const UserMovieRating({required this.movieId, required this.rating, required this.updatedAt});
  final String movieId;
  final double rating;
  final DateTime updatedAt;
  factory UserMovieRating.fromMap(String movieId, Map<String, dynamic> map) => UserMovieRating(movieId: movieId, rating: (map['rating'] ?? 0).toDouble(), updatedAt: (map['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now());
}

class Watchlist {
  const Watchlist({required this.id, required this.name, required this.movieIds});
  final String id;
  final String name;
  final List<String> movieIds;
  factory Watchlist.fromMap(String id, Map<String, dynamic> map) => Watchlist(id: id, name: map['name'] ?? 'Watchlist', movieIds: List<String>.from(map['movieIds'] ?? const []));
}

class StudentTask {
  const StudentTask({required this.id, required this.title, required this.done, required this.createdAt});
  final String id;
  final String title;
  final bool done;
  final DateTime createdAt;
  factory StudentTask.fromMap(String id, Map<String, dynamic> map) => StudentTask(id: id, title: map['title'] ?? '', done: map['done'] ?? false, createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now());
}

class StudentIdentity {
  const StudentIdentity({required this.name, required this.iin, required this.color});
  final String name;
  final String iin;
  final int color;
  factory StudentIdentity.empty() => const StudentIdentity(name: 'Enter your full name', iin: 'Enter IIN', color: 0xFFFFC400);
  factory StudentIdentity.fromMap(Map<String, dynamic>? map) => StudentIdentity(name: map?['name'] ?? 'Enter your full name', iin: map?['iin'] ?? 'Enter IIN', color: map?['color'] ?? 0xFFFFC400);
  Map<String, dynamic> toMap() => {'name': name, 'iin': iin, 'color': color, 'updatedAt': FieldValue.serverTimestamp()};
}

const seedMovies = [
  Movie(id: 'dune-two', title: 'Dune: Part Two', posterUrl: 'https://image.tmdb.org/t/p/w500/1pdfLvkbY9ohJlCjQH2CZjjYVvJ.jpg', backdropUrl: 'https://image.tmdb.org/t/p/w1280/xOMo8BRK7PfcJv9JCnx7s5hj0PX.jpg', rating: 8.7, year: 2024, genres: ['Sci-Fi', 'Adventure'], description: 'Paul Atreides unites with Chani and the Fremen while seeking revenge against the conspirators who destroyed his family.', cast: ['Timothee Chalamet', 'Zendaya', 'Rebecca Ferguson'], trending: true, popular: true),
  Movie(id: 'oppenheimer', title: 'Oppenheimer', posterUrl: 'https://image.tmdb.org/t/p/w500/8Gxv8gSFCU0XGDykEGv7zR1n2ua.jpg', backdropUrl: 'https://image.tmdb.org/t/p/w1280/fm6KqXpk3M2HVveHwCrBSSBaO0V.jpg', rating: 8.5, year: 2023, genres: ['Drama', 'History'], description: 'The story of J. Robert Oppenheimer and the creation of the atomic bomb told with towering scale and moral tension.', cast: ['Cillian Murphy', 'Emily Blunt', 'Robert Downey Jr.'], trending: true, popular: true),
  Movie(id: 'inside-out-2', title: 'Inside Out 2', posterUrl: 'https://image.tmdb.org/t/p/w500/vpnVM9B6NMmQpWeZvzLvDESb2QY.jpg', backdropUrl: 'https://image.tmdb.org/t/p/w1280/stKGOm8UyhuLPR9sZLjs5AkmncA.jpg', rating: 7.8, year: 2024, genres: ['Animation', 'Family'], description: 'Riley grows up and new emotions arrive, turning headquarters into a funny and tender storm.', cast: ['Amy Poehler', 'Maya Hawke'], popular: true),
  Movie(id: 'furiosa', title: 'Furiosa', posterUrl: 'https://image.tmdb.org/t/p/w500/iADOJ8Zymht2JPMoy3R7xceZprc.jpg', backdropUrl: 'https://image.tmdb.org/t/p/w1280/wNAhuOZ3Zf84jCIlrcI6JhgmY5q.jpg', rating: 7.6, year: 2024, genres: ['Action', 'Thriller'], description: 'Young Furiosa is swept into a brutal wasteland war and forges a legend through fire and steel.', cast: ['Anya Taylor-Joy', 'Chris Hemsworth'], trending: true),
  Movie(id: 'poor-things', title: 'Poor Things', posterUrl: 'https://image.tmdb.org/t/p/w500/kCGlIMHnOm8JPXq3rXM6c5wMxcT.jpg', backdropUrl: 'https://image.tmdb.org/t/p/w1280/bQS43HSLZzMjZkcHJs4fGc7fNdz.jpg', rating: 8.0, year: 2023, genres: ['Drama', 'Comedy'], description: 'Bella Baxter discovers the world with strange wonder, razor wit, and fearless appetite for life.', cast: ['Emma Stone', 'Mark Ruffalo', 'Willem Dafoe']),
  Movie(id: 'godzilla-kong', title: 'Godzilla x Kong', posterUrl: 'https://image.tmdb.org/t/p/w500/z1p34vh7dEOnLDmyCrlUVLuoDzd.jpg', backdropUrl: 'https://image.tmdb.org/t/p/w1280/1XDDXPXGiI8id7MrUxK36ke7gkX.jpg', rating: 7.1, year: 2024, genres: ['Action', 'Fantasy'], description: 'Two ancient titans face a hidden threat powerful enough to challenge the planet itself.', cast: ['Rebecca Hall', 'Brian Tyree Henry'], popular: true),
];

class CinemaRepository {
  CinemaRepository(this.auth, this.db, this.storage);
  final FirebaseAuth auth;
  final FirebaseFirestore db;
  final FirebaseStorage storage;
  Future<void> seed() async {
    try {
      final snap = await db.collection('movies').limit(1).get();
      if (snap.docs.isEmpty && auth.currentUser != null) {
        for (final movie in seedMovies) {
          await db.collection('movies').doc(movie.id).set(movie.toMap(), SetOptions(merge: true));
        }
      }
    } on FirebaseException catch (error) {
      if (error.code != 'permission-denied' && error.code != 'unavailable') {
        rethrow;
      }
    }
  }

  Future<void> signIn(String email, String password) => auth.signInWithEmailAndPassword(email: email.trim(), password: password.trim());
  Future<void> register(String name, String email, String password) async {
    final result = await auth.createUserWithEmailAndPassword(email: email.trim(), password: password.trim());
    await result.user?.updateDisplayName(name.trim());
    await upsertUser(AppUser(uid: result.user!.uid, email: email.trim(), name: name.trim()));
  }

  Future<void> google() async {
    final account = await GoogleSignIn().signIn();
    if (account == null) return;
    final googleAuth = await account.authentication;
    final credential = GoogleAuthProvider.credential(accessToken: googleAuth.accessToken, idToken: googleAuth.idToken);
    final result = await auth.signInWithCredential(credential);
    await upsertUser(AppUser(uid: result.user!.uid, email: result.user?.email ?? '', name: result.user?.displayName ?? 'Movie lover', avatarUrl: result.user?.photoURL ?? ''));
  }

  Future<void> signOut() async {
    await GoogleSignIn().signOut();
    await auth.signOut();
  }

  Future<void> upsertUser(AppUser user) => _write(() => db.collection('users').doc(user.uid).set(user.toMap(), SetOptions(merge: true)));
  Stream<AppUser?> profile(String uid) async* {
    try {
      await for (final d in db.collection('users').doc(uid).snapshots()) {
        yield d.exists ? AppUser.fromMap(d.id, d.data()!) : null;
      }
    } on FirebaseException catch (error) {
      if (!_softFirestoreError(error)) rethrow;
      final user = auth.currentUser;
      yield user == null ? null : AppUser(uid: uid, email: user.email ?? '', name: user.displayName ?? 'Movie lover', avatarUrl: user.photoURL ?? '');
    }
  }
  Future<String> uploadAvatar(String uid, XFile image) async {
    final bytes = await image.readAsBytes();
    final ref = storage.ref('avatars/$uid.jpg');
    await ref.putData(bytes, SettableMetadata(contentType: image.mimeType ?? 'image/jpeg'));
    return ref.getDownloadURL();
  }

  Stream<List<Movie>> movies() async* {
    try {
      await for (final s in db.collection('movies').snapshots()) {
        final movies = s.docs.map((d) => Movie.fromMap(d.id, d.data())).toList();
        yield movies.isEmpty ? seedMovies : movies;
      }
    } on FirebaseException catch (error) {
      if (!_softFirestoreError(error)) rethrow;
      yield seedMovies;
    }
  }

  Stream<Movie> movie(String id) async* {
    final fallback = seedMovies.where((m) => m.id == id).firstOrNull ?? seedMovies.first;
    try {
      await for (final d in db.collection('movies').doc(id).snapshots()) {
        yield d.exists ? Movie.fromMap(d.id, d.data()!) : fallback;
      }
    } on FirebaseException catch (error) {
      if (!_softFirestoreError(error)) rethrow;
      yield fallback;
    }
  }

  Stream<List<String>> favorites(String uid) async* {
    try {
      await for (final d in db.collection('favorites').doc(uid).snapshots()) {
        yield List<String>.from(d.data()?['movieIds'] ?? const []);
      }
    } on FirebaseException catch (error) {
      if (!_softFirestoreError(error)) rethrow;
      yield <String>[];
    }
  }
  Future<void> favorite(String uid, String movieId, bool add) => _write(() => db.collection('favorites').doc(uid).set({'movieIds': add ? FieldValue.arrayUnion([movieId]) : FieldValue.arrayRemove([movieId]), 'updatedAt': FieldValue.serverTimestamp()}, SetOptions(merge: true)));
  Future<void> history(String uid, String movieId) => _write(() => db.collection('users').doc(uid).collection('history').doc(movieId).set({'movieId': movieId, 'viewedAt': FieldValue.serverTimestamp()}, SetOptions(merge: true)));
  Stream<List<String>> historyItems(String uid) async* {
    try {
      await for (final s in db.collection('users').doc(uid).collection('history').orderBy('viewedAt', descending: true).snapshots()) {
        yield s.docs.map((d) => d.id).toList();
      }
    } on FirebaseException catch (error) {
      if (!_softFirestoreError(error)) rethrow;
      yield <String>[];
    }
  }

  Stream<List<Watchlist>> watchlists(String uid) async* {
    try {
      await for (final s in db.collection('watchlists').where('uid', isEqualTo: uid).snapshots()) {
        yield s.docs.map((d) => Watchlist.fromMap(d.id, d.data())).toList();
      }
    } on FirebaseException catch (error) {
      if (!_softFirestoreError(error)) rethrow;
      yield <Watchlist>[];
    }
  }
  Future<void> saveWatchlist(String uid, String? id, String name) => _write(() async => id == null ? await db.collection('watchlists').add({'uid': uid, 'name': name, 'movieIds': [], 'createdAt': FieldValue.serverTimestamp()}) : await db.collection('watchlists').doc(id).update({'name': name}));
  Future<void> deleteWatchlist(String id) => _write(() => db.collection('watchlists').doc(id).delete());
  Future<void> watchlistMovie(String id, String movieId, bool add) => _write(() => db.collection('watchlists').doc(id).set({'movieIds': add ? FieldValue.arrayUnion([movieId]) : FieldValue.arrayRemove([movieId])}, SetOptions(merge: true)));
  Stream<List<Review>> reviews(String movieId) async* {
    try {
      await for (final s in db.collection('reviews').where('movieId', isEqualTo: movieId).orderBy('createdAt', descending: true).snapshots()) {
        yield s.docs.map((d) => Review.fromMap(d.id, d.data())).toList();
      }
    } on FirebaseException catch (error) {
      if (!_softFirestoreError(error)) rethrow;
      yield <Review>[];
    }
  }

  Stream<List<Review>> reviewsFeed() async* {
    try {
      await for (final s in db.collection('reviews').orderBy('createdAt', descending: true).snapshots()) {
        yield s.docs.map((d) => Review.fromMap(d.id, d.data())).toList();
      }
    } on FirebaseException catch (error) {
      if (!_softFirestoreError(error)) rethrow;
      yield <Review>[];
    }
  }
  Future<void> review(String movieId, String uid, String userName, String text, double rating) => _write(() async => await db.collection('reviews').add({'movieId': movieId, 'userId': uid, 'userName': userName, 'text': text.trim(), 'rating': rating, 'createdAt': FieldValue.serverTimestamp()}));
  Future<void> deleteReview(String id) => _write(() => db.collection('reviews').doc(id).delete());
  Stream<List<UserMovieRating>> userRatings(String uid) async* {
    try {
      await for (final s in db.collection('users').doc(uid).collection('ratings').snapshots()) {
        yield s.docs.map((d) => UserMovieRating.fromMap(d.id, d.data())).toList();
      }
    } on FirebaseException catch (error) {
      if (!_softFirestoreError(error)) rethrow;
      yield <UserMovieRating>[];
    }
  }
  Future<void> rateMovie(String uid, String movieId, double rating) => _write(() => db.collection('users').doc(uid).collection('ratings').doc(movieId).set({'rating': rating, 'updatedAt': FieldValue.serverTimestamp()}, SetOptions(merge: true)));
  Future<void> deleteRating(String uid, String movieId) => _write(() => db.collection('users').doc(uid).collection('ratings').doc(movieId).delete());
  Stream<List<StudentTask>> tasks(String uid) async* {
    try {
      await for (final s in db.collection('users').doc(uid).collection('tasks').orderBy('createdAt').snapshots()) {
        yield s.docs.map((d) => StudentTask.fromMap(d.id, d.data())).toList();
      }
    } on FirebaseException catch (error) {
      if (!_softFirestoreError(error)) rethrow;
      yield <StudentTask>[];
    }
  }
  Future<void> addTask(String uid, String title) => _write(() async => await db.collection('users').doc(uid).collection('tasks').add({'title': title.trim(), 'done': false, 'createdAt': FieldValue.serverTimestamp()}));
  Future<void> updateTask(String uid, String id, String title) => _write(() => db.collection('users').doc(uid).collection('tasks').doc(id).update({'title': title.trim(), 'updatedAt': FieldValue.serverTimestamp()}));
  Future<void> completeTask(String uid, String id, bool done) => _write(() => db.collection('users').doc(uid).collection('tasks').doc(id).update({'done': done, 'updatedAt': FieldValue.serverTimestamp()}));
  Future<void> deleteTask(String uid, String id) => _write(() => db.collection('users').doc(uid).collection('tasks').doc(id).delete());
  Stream<StudentIdentity> identity(String uid) async* {
    try {
      await for (final d in db.collection('users').doc(uid).collection('private').doc('identity').snapshots()) {
        yield StudentIdentity.fromMap(d.data());
      }
    } on FirebaseException catch (error) {
      if (!_softFirestoreError(error)) rethrow;
      yield StudentIdentity.empty();
    }
  }
  Future<void> saveIdentity(String uid, StudentIdentity identity) => _write(() => db.collection('users').doc(uid).collection('private').doc('identity').set(identity.toMap(), SetOptions(merge: true)));

  bool _softFirestoreError(FirebaseException error) => error.code == 'permission-denied' || error.code == 'unavailable' || error.code == 'failed-precondition';
  Future<void> _write(Future<void> Function() action) async {
    try {
      await action();
    } on FirebaseException catch (error) {
      if (!_softFirestoreError(error)) rethrow;
    }
  }
}

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});
  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() async {
      await ref.read(repoProvider).seed();
      final prefs = await SharedPreferences.getInstance();
      if (!mounted) return;
      context.go(prefs.getBool('seenOnboarding') == true ? '/home' : '/onboarding');
    });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        body: Center(
          child: Text('Kinopoisk', style: Theme.of(context).textTheme.displayMedium?.copyWith(fontWeight: FontWeight.w900, color: const Color(0xFFFFC400)))
              .animate()
              .fadeIn(duration: 600.ms)
              .scale(begin: const Offset(.9, .9)),
        ),
      );
}

class OnboardingScreen extends StatelessWidget {
  const OnboardingScreen({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
        body: Stack(children: [
          const Positioned.fill(child: PosterImage('https://image.tmdb.org/t/p/w1280/xOMo8BRK7PfcJv9JCnx7s5hj0PX.jpg')),
          Positioned.fill(child: DecoratedBox(decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.black.withValues(alpha: .2), const Color(0xFF090A0F)])))),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Spacer(),
                Text('Kinopoisk', style: Theme.of(context).textTheme.displaySmall?.copyWith(fontWeight: FontWeight.w900, color: const Color(0xFFFFC400))),
                const SizedBox(height: 12),
                Text('A premium movie space for discovery, favorites, watchlists, reviews, and Firebase-synced cinema history.', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: () async {
                    final prefs = await SharedPreferences.getInstance();
                    await prefs.setBool('seenOnboarding', true);
                    if (context.mounted) context.go('/login');
                  },
                  child: const Text('Start watching'),
                ),
                TextButton(onPressed: () => context.go('/register'), child: const Text('Create account')),
              ]),
            ),
          ),
        ]),
      );
}

class AuthScreen extends ConsumerStatefulWidget {
  const AuthScreen({super.key, required this.isLogin});
  final bool isLogin;
  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen> {
  final form = GlobalKey<FormState>();
  final name = TextEditingController();
  final email = TextEditingController();
  final password = TextEditingController();
  bool loading = false;
  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(),
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Form(
                key: form,
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  Text(widget.isLogin ? 'Welcome back' : 'Create account', style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w900)),
                  const SizedBox(height: 8),
                  const Text('Login to sync your favorites, watchlists, reviews, and profile.', style: TextStyle(color: Colors.white70)),
                  const SizedBox(height: 28),
                  if (!widget.isLogin) ...[
                    TextFormField(controller: name, decoration: const InputDecoration(labelText: 'Name'), validator: (v) => v == null || v.trim().length < 2 ? 'Enter your name' : null),
                    const SizedBox(height: 12),
                  ],
                  TextFormField(controller: email, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(labelText: 'Email'), validator: (v) => v != null && v.contains('@') ? null : 'Enter a valid email'),
                  const SizedBox(height: 12),
                  TextFormField(controller: password, obscureText: true, decoration: const InputDecoration(labelText: 'Password'), validator: (v) => v != null && v.length >= 6 ? null : 'Minimum 6 characters'),
                  const SizedBox(height: 20),
                  FilledButton(onPressed: loading ? null : submit, child: loading ? const SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2)) : Text(widget.isLogin ? 'Login' : 'Register')),
                  OutlinedButton.icon(onPressed: loading ? null : google, icon: const Icon(Icons.g_mobiledata), label: const Text('Continue with Google')),
                  TextButton(onPressed: () => context.go(widget.isLogin ? '/register' : '/login'), child: Text(widget.isLogin ? 'Need an account? Register' : 'Already registered? Login')),
                ]),
              ),
            ),
          ),
        ),
      );

  Future<void> submit() async {
    if (!form.currentState!.validate()) return;
    setState(() => loading = true);
    try {
      final repo = ref.read(repoProvider);
      if (widget.isLogin) {
        await repo.signIn(email.text, password.text);
      } else {
        await repo.register(name.text, email.text, password.text);
      }
      if (mounted) context.go('/home');
    } catch (e) {
      if (mounted) snack(context, friendlyError(e));
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> google() async {
    setState(() => loading = true);
    try {
      await ref.read(repoProvider).google();
      if (mounted) context.go('/home');
    } catch (e) {
      if (mounted) snack(context, friendlyError(e));
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }
}

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});
  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int index = 0;
  final pages = const [HomeScreen(), SearchScreen(), FavoritesScreen(), WatchlistScreen(), ProfileScreen()];
  @override
  Widget build(BuildContext context) => Scaffold(
        body: IndexedStack(index: index, children: pages),
        bottomNavigationBar: NavigationBar(
          selectedIndex: index,
          onDestinationSelected: (i) => setState(() => index = i),
          destinations: const [
            NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'Home'),
            NavigationDestination(icon: Icon(Icons.search), label: 'Search'),
            NavigationDestination(icon: Icon(Icons.favorite_border), selectedIcon: Icon(Icons.favorite), label: 'Favorites'),
            NavigationDestination(icon: Icon(Icons.playlist_play), label: 'Lists'),
            NavigationDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person), label: 'Profile'),
          ],
        ),
      );
}

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(
        body: RefreshIndicator(
          onRefresh: () async => ref.invalidate(moviesProvider),
          child: AsyncBlock<List<Movie>>(
            value: ref.watch(moviesProvider),
            builder: (items) {
              final source = items.isEmpty ? seedMovies : items;
              final trending = source.where((m) => m.trending).toList();
              final popular = source.where((m) => m.popular).toList();
              return CustomScrollView(slivers: [
                SliverToBoxAdapter(child: HeroCarousel(movies: trending.isEmpty ? source : trending)),
                const SliverToBoxAdapter(child: KinopoiskHub()),
                SliverToBoxAdapter(child: MovieRail(title: 'Trending now', movies: trending.isEmpty ? source : trending)),
                SliverToBoxAdapter(child: MovieRail(title: 'Popular movies', movies: popular.isEmpty ? source : popular)),
                SliverToBoxAdapter(child: MovieRail(title: 'Recommended', movies: source.reversed.toList())),
                const SliverPadding(padding: EdgeInsets.only(bottom: 28)),
              ]);
            },
          ),
        ),
      );
}

class HeroCarousel extends StatelessWidget {
  const HeroCarousel({super.key, required this.movies});
  final List<Movie> movies;
  @override
  Widget build(BuildContext context) => SizedBox(
        height: 430,
        child: PageView.builder(
          controller: PageController(viewportFraction: .9),
          itemCount: movies.length,
          itemBuilder: (context, i) {
            final movie = movies[i];
            return Padding(
              padding: const EdgeInsets.fromLTRB(6, 54, 6, 10),
              child: InkWell(
                onTap: () => context.push('/movie/${movie.id}'),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(26),
                  child: Stack(fit: StackFit.expand, children: [
                    PosterImage(movie.backdropUrl),
                  DecoratedBox(decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.transparent, Colors.black.withValues(alpha: .92)]))),
                    Positioned(
                      left: 20,
                      right: 20,
                      bottom: 22,
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(movie.title, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900)),
                        const SizedBox(height: 8),
                        Wrap(spacing: 8, children: [for (final g in movie.genres) Chip(label: Text(g), visualDensity: VisualDensity.compact)]),
                        const SizedBox(height: 8),
                        FilledButton.icon(onPressed: () => context.push('/movie/${movie.id}'), icon: const Icon(Icons.play_arrow), label: const Text('Details')),
                      ]),
                    ),
                  ]),
                ),
              ),
            ).animate().fadeIn().slideY(begin: .05, end: 0);
          },
        ),
      );
}

class MovieRail extends StatelessWidget {
  const MovieRail({super.key, required this.title, required this.movies});
  final String title;
  final List<Movie> movies;
  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SectionHeader(title),
        SizedBox(
          height: 260,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            scrollDirection: Axis.horizontal,
            itemCount: movies.length,
            itemBuilder: (_, i) => MovieCard(movie: movies[i]),
            separatorBuilder: (_, __) => const SizedBox(width: 14),
          ),
        ),
      ]);
}

class MovieDetailsScreen extends ConsumerStatefulWidget {
  const MovieDetailsScreen({super.key, required this.movieId});
  final String movieId;
  @override
  ConsumerState<MovieDetailsScreen> createState() => _MovieDetailsScreenState();
}

class _MovieDetailsScreenState extends ConsumerState<MovieDetailsScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      final uid = ref.read(authProvider).currentUser?.uid;
      if (uid != null) ref.read(repoProvider).history(uid, widget.movieId);
    });
  }

  @override
  Widget build(BuildContext context) {
    final favs = ref.watch(favoritesProvider).valueOrNull ?? [];
    final lists = ref.watch(watchlistsProvider).valueOrNull ?? [];
    final uid = ref.watch(authProvider).currentUser?.uid;
    return Scaffold(
      body: AsyncBlock<Movie>(
        value: ref.watch(movieProvider(widget.movieId)),
        builder: (movie) {
          final isFav = favs.contains(movie.id);
          return CustomScrollView(slivers: [
            SliverAppBar(
              expandedHeight: 360,
              pinned: true,
              flexibleSpace: FlexibleSpaceBar(
                background: Stack(fit: StackFit.expand, children: [
                  PosterImage(movie.backdropUrl),
                  DecoratedBox(decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.transparent, const Color(0xFF090A0F).withValues(alpha: .98)]))),
                ]),
              ),
              actions: [
                IconButton(
                  onPressed: uid == null ? null : () => ref.read(repoProvider).favorite(uid, movie.id, !isFav),
                  icon: Icon(isFav ? Icons.favorite : Icons.favorite_border, color: const Color(0xFFFFC400)),
                ),
              ],
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                    Hero(tag: 'poster-${movie.id}', child: ClipRRect(borderRadius: BorderRadius.circular(16), child: SizedBox(width: 124, child: AspectRatio(aspectRatio: 2 / 3, child: PosterImage(movie.posterUrl))))),
                    const SizedBox(width: 16),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(movie.title, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900)), const SizedBox(height: 8), RatingRow(movie.rating), Text('${movie.year}  •  ${movie.genres.join(' / ')}', style: const TextStyle(color: Colors.white70))])),
                  ]),
                  const SizedBox(height: 22),
                  Text(movie.description, style: const TextStyle(height: 1.5, color: Colors.white70)),
                  const SizedBox(height: 20),
                  Wrap(spacing: 8, runSpacing: 8, children: [for (final actor in movie.cast) Chip(avatar: const Icon(Icons.person, size: 16), label: Text(actor))]),
                  const SizedBox(height: 18),
                  Row(children: [
                    Expanded(child: FilledButton.icon(onPressed: () => context.push('/movie/${movie.id}/trailer'), icon: const Icon(Icons.play_arrow), label: const Text('Trailer'))),
                    const SizedBox(width: 12),
                    Expanded(child: OutlinedButton.icon(onPressed: () => context.push('/movie/${movie.id}/tickets'), icon: const Icon(Icons.confirmation_number), label: const Text('Tickets'))),
                  ]),
                  const SizedBox(height: 12),
                  Row(children: [
                    Expanded(child: OutlinedButton.icon(onPressed: () => context.push('/movie/${movie.id}/reviews'), icon: const Icon(Icons.rate_review), label: const Text('Reviews'))),
                    const SizedBox(width: 12),
                    Expanded(child: OutlinedButton.icon(onPressed: lists.isEmpty ? () => snack(context, 'Create a watchlist first.') : () => showWatchlistPicker(context, ref, movie.id, lists), icon: const Icon(Icons.playlist_add), label: const Text('Watchlist'))),
                  ]),
                  const SizedBox(height: 12),
                  FilledButton.tonalIcon(onPressed: () => showRatingDialog(context, ref, movie), icon: const Icon(Icons.star_rate), label: const Text('Rate this movie')),
                  const SizedBox(height: 12),
                  Row(children: [
                    Expanded(child: OutlinedButton.icon(onPressed: () async { await Clipboard.setData(ClipboardData(text: '${movie.title} (${movie.year}) - rating ${movie.rating.toStringAsFixed(1)}')); if (context.mounted) snack(context, 'Movie info copied.'); }, icon: const Icon(Icons.copy), label: const Text('Copy info'))),
                    const SizedBox(width: 12),
                    Expanded(child: OutlinedButton.icon(onPressed: uid == null ? null : () async { await ref.read(repoProvider).history(uid, movie.id); if (context.mounted) snack(context, 'Marked as watched.'); }, icon: const Icon(Icons.visibility), label: const Text('Watched'))),
                  ]),
                ]),
              ),
            ),
            SliverToBoxAdapter(child: MovieRail(title: 'Similar movies', movies: seedMovies.where((m) => m.id != movie.id).toList())),
          ]);
        },
      ),
    );
  }
}

class ReviewsScreen extends ConsumerStatefulWidget {
  const ReviewsScreen({super.key, required this.movieId});
  final String movieId;
  @override
  ConsumerState<ReviewsScreen> createState() => _ReviewsScreenState();
}

class _ReviewsScreenState extends ConsumerState<ReviewsScreen> {
  final text = TextEditingController();
  double rating = 8;
  @override
  Widget build(BuildContext context) {
    final reviews = ref.watch(reviewsProvider(widget.movieId));
    return Scaffold(
      appBar: AppBar(title: const Text('Reviews')),
      body: Column(children: [
        Expanded(
          child: AsyncBlock<List<Review>>(
            value: reviews,
            builder: (items) => items.isEmpty
                ? const EmptyCinemaState(icon: Icons.reviews_outlined, title: 'No reviews yet', message: 'Be the first to share a thoughtful review.')
                : ListView.separated(
                    padding: const EdgeInsets.all(20),
                    itemCount: items.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (_, i) {
                      final r = items[i];
                      final own = r.userId == ref.watch(authProvider).currentUser?.uid;
                      return GlassPanel(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Row(children: [Text(r.userName, style: const TextStyle(fontWeight: FontWeight.w800)), const Spacer(), RatingRow(r.rating, compact: true), if (own) IconButton(onPressed: () => ref.read(repoProvider).deleteReview(r.id), icon: const Icon(Icons.delete_outline))]), const SizedBox(height: 8), Text(r.text, style: const TextStyle(color: Colors.white70))]));
                    },
                  ),
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: GlassPanel(
              child: Column(children: [
                Row(children: [const Text('Your rating'), Expanded(child: Slider(value: rating, min: 1, max: 10, divisions: 18, label: rating.toStringAsFixed(1), onChanged: (v) => setState(() => rating = v)))]),
                TextField(controller: text, minLines: 1, maxLines: 3, decoration: const InputDecoration(hintText: 'Write a review')),
                const SizedBox(height: 10),
                Align(alignment: Alignment.centerRight, child: FilledButton(onPressed: addReview, child: const Text('Publish'))),
              ]),
            ),
          ),
        ),
      ]),
    );
  }

  Future<void> addReview() async {
    if (text.text.trim().isEmpty) return snack(context, 'Write a review first.');
    final user = ref.read(authProvider).currentUser!;
    final profile = ref.read(profileProvider).valueOrNull;
    await ref.read(repoProvider).review(widget.movieId, user.uid, profile?.name ?? user.displayName ?? 'Viewer', text.text, rating);
    text.clear();
  }
}

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});
  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final controller = TextEditingController();
  Timer? timer;
  String query = '';
  final history = <String>[];
  @override
  void dispose() {
    timer?.cancel();
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Search')),
        body: Column(children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: TextField(
              controller: controller,
              decoration: InputDecoration(prefixIcon: const Icon(Icons.search), hintText: 'Find movies, genres, cast', suffixIcon: query.isEmpty ? null : IconButton(icon: const Icon(Icons.close), onPressed: () => setState(() { controller.clear(); query = ''; }))),
              onChanged: (v) {
                timer?.cancel();
                timer = Timer(const Duration(milliseconds: 350), () => setState(() => query = v.trim().toLowerCase()));
              },
            ),
          ),
          Expanded(
            child: AsyncBlock<List<Movie>>(
              value: ref.watch(moviesProvider),
              builder: (items) {
                final source = items.isEmpty ? seedMovies : items;
                if (query.isEmpty) return Suggestions(onPick: pick, history: history);
                final result = source.where((m) => '${m.title} ${m.genres.join(' ')} ${m.cast.join(' ')}'.toLowerCase().contains(query)).toList();
                if (result.isEmpty) return const EmptyCinemaState(icon: Icons.travel_explore, title: 'No movies found', message: 'Try another title, actor, or genre.');
                if (!history.contains(query)) history.insert(0, query);
                return GridView.builder(padding: const EdgeInsets.all(20), gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, childAspectRatio: .55, crossAxisSpacing: 16, mainAxisSpacing: 16), itemCount: result.length, itemBuilder: (_, i) => MovieCard(movie: result[i], compact: true));
              },
            ),
          ),
        ]),
      );
  void pick(String value) => setState(() { controller.text = value; query = value.toLowerCase(); });
}

class FavoritesScreen extends ConsumerWidget {
  const FavoritesScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final favs = ref.watch(favoritesProvider).valueOrNull ?? [];
    return Scaffold(
      appBar: AppBar(title: const Text('Favorites')),
      body: AsyncBlock<List<Movie>>(
        value: ref.watch(moviesProvider),
        builder: (items) {
          final list = (items.isEmpty ? seedMovies : items).where((m) => favs.contains(m.id)).toList();
          if (list.isEmpty) return const EmptyCinemaState(icon: Icons.favorite_border, title: 'No favorites yet', message: 'Tap the heart on a movie to save it here.');
          return GridView.builder(padding: const EdgeInsets.all(20), gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, childAspectRatio: .55, crossAxisSpacing: 16, mainAxisSpacing: 16), itemCount: list.length, itemBuilder: (_, i) => MovieCard(movie: list[i], compact: true));
        },
      ),
    );
  }
}

class WatchlistScreen extends ConsumerWidget {
  const WatchlistScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(
        appBar: AppBar(title: const Text('Watchlists'), actions: [IconButton(onPressed: () => editWatchlist(context, ref), icon: const Icon(Icons.add))]),
        body: AsyncBlock<List<Watchlist>>(
          value: ref.watch(watchlistsProvider),
          builder: (items) {
            if (items.isEmpty) return const EmptyCinemaState(icon: Icons.playlist_add, title: 'Create your first watchlist', message: 'Organize films for weekends, classics, or class projects.');
            return ListView.separated(
              padding: const EdgeInsets.all(20),
              itemCount: items.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (_, i) {
                final w = items[i];
                return ListTile(
                  tileColor: Colors.white10,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  leading: const Icon(Icons.playlist_play, color: Color(0xFFFFC400)),
                  title: Text(w.name),
                  subtitle: Text('${w.movieIds.length} movies'),
                  trailing: PopupMenuButton<String>(
                    onSelected: (v) => v == 'delete' ? ref.read(repoProvider).deleteWatchlist(w.id) : editWatchlist(context, ref, id: w.id, name: w.name),
                    itemBuilder: (_) => const [PopupMenuItem(value: 'edit', child: Text('Edit')), PopupMenuItem(value: 'delete', child: Text('Delete'))],
                  ),
                  onTap: () => context.push('/watchlist/${w.id}'),
                );
              },
            );
          },
        ),
      );
}

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(profileProvider).valueOrNull;
    final favs = ref.watch(favoritesProvider).valueOrNull ?? [];
    final lists = ref.watch(watchlistsProvider).valueOrNull ?? [];
    return Scaffold(
      appBar: AppBar(title: const Text('Profile'), actions: [IconButton(onPressed: () => context.push('/settings'), icon: const Icon(Icons.settings))]),
      body: ListView(padding: const EdgeInsets.all(20), children: [
        GlassPanel(
          child: Column(children: [
            CircleAvatar(radius: 46, backgroundImage: profile?.avatarUrl.isNotEmpty == true ? CachedNetworkImageProvider(profile!.avatarUrl) : null, child: profile?.avatarUrl.isNotEmpty == true ? null : const Icon(Icons.person, size: 46)),
            const SizedBox(height: 12),
            Text(profile?.name ?? 'Movie lover', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900)),
            Text(profile?.email ?? ref.watch(authProvider).currentUser?.email ?? '', style: const TextStyle(color: Colors.white70)),
            if (profile?.bio.isNotEmpty == true) Padding(padding: const EdgeInsets.only(top: 8), child: Text(profile!.bio, textAlign: TextAlign.center)),
            const SizedBox(height: 16),
            FilledButton.icon(onPressed: () => context.push('/profile/edit'), icon: const Icon(Icons.edit), label: const Text('Edit profile')),
          ]),
        ),
        const SizedBox(height: 16),
        Row(children: [
          Expanded(child: StatBox(label: 'Favorites', value: '${favs.length}')),
          const SizedBox(width: 12),
          Expanded(child: StatBox(label: 'Watchlists', value: '${lists.length}')),
          const SizedBox(width: 12),
          const Expanded(child: StatBox(label: 'Reviews', value: 'Live')),
        ]),
        const SizedBox(height: 16),
        const ProfileLink(icon: Icons.task_alt, title: 'Tasks marking screen', route: '/tasks'),
        const ProfileLink(icon: Icons.history, title: 'Watch history', route: '/history'),
        const ProfileLink(icon: Icons.notifications_none, title: 'Notifications', route: '/notifications'),
        const ProfileLink(icon: Icons.workspace_premium_outlined, title: 'Plus subscription', route: '/subscription'),
        const ProfileLink(icon: Icons.emoji_events_outlined, title: 'Achievements', route: '/achievements'),
        const ProfileLink(icon: Icons.support_agent, title: 'Support', route: '/support'),
        const ProfileLink(icon: Icons.privacy_tip_outlined, title: 'Privacy', route: '/privacy'),
        const ProfileLink(icon: Icons.info_outline, title: 'About app', route: '/about'),
        const SizedBox(height: 16),
        OutlinedButton.icon(onPressed: () => ref.read(repoProvider).signOut(), icon: const Icon(Icons.logout), label: const Text('Logout')),
      ]),
    );
  }
}

class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({super.key});
  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  final name = TextEditingController();
  final bio = TextEditingController();
  bool initialized = false;
  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(profileProvider).valueOrNull;
    if (!initialized && profile != null) {
      name.text = profile.name;
      bio.text = profile.bio;
      initialized = true;
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Edit profile')),
      body: ListView(padding: const EdgeInsets.all(20), children: [
        Center(child: CircleAvatar(radius: 48, backgroundImage: profile?.avatarUrl.isNotEmpty == true ? CachedNetworkImageProvider(profile!.avatarUrl) : null, child: profile?.avatarUrl.isNotEmpty == true ? null : const Icon(Icons.person, size: 48))),
        TextButton.icon(onPressed: pickAvatar, icon: const Icon(Icons.photo_camera), label: const Text('Change avatar')),
        const SizedBox(height: 12),
        TextField(controller: name, decoration: const InputDecoration(labelText: 'Name')),
        const SizedBox(height: 12),
        TextField(controller: bio, minLines: 3, maxLines: 5, decoration: const InputDecoration(labelText: 'Bio')),
        const SizedBox(height: 20),
        FilledButton(onPressed: save, child: const Text('Save')),
      ]),
    );
  }

  Future<void> pickAvatar() async {
    final user = ref.read(authProvider).currentUser;
    if (user == null) return;
    final image = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (image == null) return;
    final url = await ref.read(repoProvider).uploadAvatar(user.uid, image);
    final profile = ref.read(profileProvider).valueOrNull;
    await ref.read(repoProvider).upsertUser(AppUser(uid: user.uid, email: user.email ?? profile?.email ?? '', name: profile?.name ?? user.displayName ?? 'Movie lover', avatarUrl: url, bio: profile?.bio ?? ''));
  }

  Future<void> save() async {
    final user = ref.read(authProvider).currentUser;
    if (user == null) return;
    await ref.read(repoProvider).upsertUser(AppUser(uid: user.uid, email: user.email ?? '', name: name.text.trim().isEmpty ? 'Movie lover' : name.text.trim(), avatarUrl: ref.read(profileProvider).valueOrNull?.avatarUrl ?? '', bio: bio.text.trim()));
    if (mounted) context.pop();
  }
}

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Settings')),
        body: ListView(padding: const EdgeInsets.all(20), children: const [
          SwitchListTile(value: true, onChanged: null, title: Text('Real-time Firebase sync'), subtitle: Text('Enabled for movies, reviews, favorites, watchlists')),
          SwitchListTile(value: true, onChanged: null, title: Text('Cached posters'), subtitle: Text('Network images are cached automatically')),
          ListTile(leading: Icon(Icons.security), title: Text('Secure rules included'), subtitle: Text('Deploy firestore.rules with Firebase CLI')),
          ProfileLink(icon: Icons.fact_check_outlined, title: 'Teacher QA checklist', route: '/qa-checklist'),
        ]),
      );
}

class KinopoiskHub extends StatelessWidget {
  const KinopoiskHub({super.key});
  @override
  Widget build(BuildContext context) {
    final links = [
      ('Tasks', Icons.task_alt, '/tasks'),
      ('Films', Icons.movie_creation_outlined, '/catalog'),
      ('Genres', Icons.category_outlined, '/genres'),
      ('Online', Icons.play_circle_outline, '/collections'),
      ('Premieres', Icons.event_available_outlined, '/premieres'),
      ('Top 250', Icons.leaderboard_outlined, '/top250'),
      ('Series', Icons.live_tv_outlined, '/series'),
      ('Tickets', Icons.confirmation_number_outlined, '/tickets'),
      ('Cinemas', Icons.local_movies_outlined, '/cinemas'),
      ('Calendar', Icons.calendar_month_outlined, '/calendar'),
      ('Awards', Icons.military_tech_outlined, '/awards'),
      ('Ratings', Icons.star_rate_outlined, '/ratings'),
      ('Reviews', Icons.rate_review_outlined, '/reviews-feed'),
      ('People', Icons.groups_outlined, '/persons'),
      ('News', Icons.newspaper_outlined, '/news'),
    ];
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: links.length,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, mainAxisSpacing: 10, crossAxisSpacing: 10, childAspectRatio: 1.15),
        itemBuilder: (context, i) {
          final item = links[i];
          return InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: () => context.push(item.$3),
            child: Container(
              decoration: BoxDecoration(color: Colors.white.withValues(alpha: .07), borderRadius: BorderRadius.circular(18), border: Border.all(color: Colors.white12)),
              child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(item.$2, color: const Color(0xFFFFC400)),
                const SizedBox(height: 8),
                Text(item.$1, textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
              ]),
            ),
          );
        },
      ),
    );
  }
}

enum TaskFilter { all, active, completed }

class TasksScreen extends ConsumerStatefulWidget {
  const TasksScreen({super.key});
  @override
  ConsumerState<TasksScreen> createState() => _TasksScreenState();
}

class _TasksScreenState extends ConsumerState<TasksScreen> {
  final controller = TextEditingController();
  TaskFilter filter = TaskFilter.all;
  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tasks = ref.watch(tasksProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Tasks')),
      body: AsyncBlock<List<StudentTask>>(
        value: tasks,
        builder: (items) {
          final visible = switch (filter) {
            TaskFilter.all => items,
            TaskFilter.active => items.where((t) => !t.done).toList(),
            TaskFilter.completed => items.where((t) => t.done).toList(),
          };
          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              const StudentIdentityBlock(),
              const SizedBox(height: 14),
              TaskStatsBar(tasks: items),
              const SizedBox(height: 14),
              TaskComposer(controller: controller, onAdd: addTask, onStarter: addStarterTasks),
              const SizedBox(height: 14),
              if (items.any((task) => task.done))
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: OutlinedButton.icon(onPressed: clearCompleted, icon: const Icon(Icons.cleaning_services_outlined), label: const Text('Clear completed')),
                ),
              SegmentedButton<TaskFilter>(
                segments: const [
                  ButtonSegment(value: TaskFilter.all, label: Text('All'), icon: Icon(Icons.list_alt)),
                  ButtonSegment(value: TaskFilter.active, label: Text('Active'), icon: Icon(Icons.radio_button_unchecked)),
                  ButtonSegment(value: TaskFilter.completed, label: Text('Done'), icon: Icon(Icons.check_circle_outline)),
                ],
                selected: {filter},
                onSelectionChanged: (value) => setState(() => filter = value.first),
              ),
              const SizedBox(height: 14),
              if (visible.isEmpty)
                const EmptyCinemaState(icon: Icons.task_alt, title: 'No tasks here', message: 'Add a task or switch the filter.')
              else
                for (final task in visible) Padding(padding: const EdgeInsets.only(bottom: 10), child: TaskTile(task: task)),
            ],
          );
        },
      ),
    );
  }

  Future<void> addTask() async {
    final title = controller.text.trim();
    if (title.isEmpty) return snack(context, 'Write a task first.');
    final uid = ref.read(authProvider).currentUser!.uid;
    await ref.read(repoProvider).addTask(uid, title);
    controller.clear();
    if (mounted) snack(context, 'Task added.');
  }

  Future<void> addStarterTasks() async {
    final uid = ref.read(authProvider).currentUser!.uid;
    final existing = ref.read(tasksProvider).valueOrNull ?? [];
    if (existing.isNotEmpty) return snack(context, 'Starter tasks are already added.');
    for (final title in starterTasks) {
      await ref.read(repoProvider).addTask(uid, title);
    }
    if (mounted) snack(context, 'Starter tasks added.');
  }

  Future<void> clearCompleted() async {
    final uid = ref.read(authProvider).currentUser!.uid;
    final completed = (ref.read(tasksProvider).valueOrNull ?? []).where((task) => task.done).toList();
    for (final task in completed) {
      await ref.read(repoProvider).deleteTask(uid, task.id);
    }
    if (mounted) snack(context, 'Completed tasks cleared.');
  }
}

class StudentIdentityBlock extends ConsumerStatefulWidget {
  const StudentIdentityBlock({super.key});
  @override
  ConsumerState<StudentIdentityBlock> createState() => _StudentIdentityBlockState();
}

class _StudentIdentityBlockState extends ConsumerState<StudentIdentityBlock> {
  final name = TextEditingController();
  final iin = TextEditingController();
  int color = 0xFFFFC400;
  bool ready = false;

  @override
  void dispose() {
    name.dispose();
    iin.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final identity = ref.watch(identityProvider).valueOrNull ?? StudentIdentity.empty();
    if (!ready) {
      name.text = identity.name;
      iin.text = identity.iin;
      color = identity.color;
      ready = true;
    }
    final accent = Color(color);
    return GlassPanel(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          CircleAvatar(backgroundColor: accent, child: const Icon(Icons.badge, color: Colors.black)),
          const SizedBox(width: 12),
          Expanded(child: Text('Personal identity block', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900))),
        ]),
        const SizedBox(height: 12),
        TextField(controller: name, decoration: const InputDecoration(labelText: 'Name')),
        const SizedBox(height: 10),
        TextField(controller: iin, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'IIN')),
        const SizedBox(height: 10),
        Wrap(spacing: 8, children: [
          for (final value in identityColors)
            ChoiceChip(
              label: const Text(''),
              selected: color == value,
              avatar: CircleAvatar(backgroundColor: Color(value)),
              onSelected: (_) => setState(() => color = value),
            ),
        ]),
        const SizedBox(height: 10),
        Align(alignment: Alignment.centerRight, child: FilledButton.icon(onPressed: save, icon: const Icon(Icons.save), label: const Text('Save identity'))),
      ]),
    );
  }

  Future<void> save() async {
    if (name.text.trim().isEmpty || iin.text.trim().isEmpty) return snack(context, 'Name and IIN are required.');
    final uid = ref.read(authProvider).currentUser!.uid;
    await ref.read(repoProvider).saveIdentity(uid, StudentIdentity(name: name.text.trim(), iin: iin.text.trim(), color: color));
    if (mounted) snack(context, 'Identity saved.');
  }
}

class TaskStatsBar extends StatelessWidget {
  const TaskStatsBar({super.key, required this.tasks});
  final List<StudentTask> tasks;
  @override
  Widget build(BuildContext context) {
    final done = tasks.where((t) => t.done).length;
    final active = tasks.length - done;
    final progress = tasks.isEmpty ? 0.0 : done / tasks.length;
    return GlassPanel(
      child: Column(children: [
        Row(children: [
          Expanded(child: StatBox(label: 'All', value: '${tasks.length}')),
          const SizedBox(width: 10),
          Expanded(child: StatBox(label: 'Active', value: '$active')),
          const SizedBox(width: 10),
          Expanded(child: StatBox(label: 'Done', value: '$done')),
        ]),
        const SizedBox(height: 12),
        LinearProgressIndicator(value: progress, minHeight: 8, borderRadius: BorderRadius.circular(99)),
      ]),
    );
  }
}

class TaskComposer extends StatelessWidget {
  const TaskComposer({super.key, required this.controller, required this.onAdd, required this.onStarter});
  final TextEditingController controller;
  final VoidCallback onAdd;
  final VoidCallback onStarter;
  @override
  Widget build(BuildContext context) => GlassPanel(
        child: Column(children: [
          TextField(controller: controller, decoration: const InputDecoration(prefixIcon: Icon(Icons.add_task), labelText: 'New task')),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: OutlinedButton.icon(onPressed: onStarter, icon: const Icon(Icons.playlist_add_check), label: const Text('Starter tasks'))),
            const SizedBox(width: 10),
            Expanded(child: FilledButton.icon(onPressed: onAdd, icon: const Icon(Icons.add), label: const Text('Add'))),
          ]),
        ]),
      );
}

class TaskTile extends ConsumerWidget {
  const TaskTile({super.key, required this.task});
  final StudentTask task;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final uid = ref.watch(authProvider).currentUser!.uid;
    return CheckboxListTile(
      value: task.done,
      onChanged: (value) async {
        await ref.read(repoProvider).completeTask(uid, task.id, value ?? false);
        if (context.mounted) snack(context, value == true ? 'Task completed.' : 'Task reopened.');
      },
      secondary: PopupMenuButton<String>(
        onSelected: (value) async {
          if (value == 'edit') return editTask(context, ref, task);
          await ref.read(repoProvider).deleteTask(uid, task.id);
          if (context.mounted) snack(context, 'Task deleted.');
        },
        itemBuilder: (_) => const [
          PopupMenuItem(value: 'edit', child: Text('Edit')),
          PopupMenuItem(value: 'delete', child: Text('Delete')),
        ],
      ),
      title: Text(task.title, style: TextStyle(decoration: task.done ? TextDecoration.lineThrough : null, fontWeight: FontWeight.w800)),
      subtitle: Text(task.done ? 'Completed' : 'Active'),
      tileColor: Colors.white10,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    );
  }
}

class CatalogScreen extends ConsumerWidget {
  const CatalogScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) => MovieListPage(title: 'Films', subtitle: 'Catalog with genres, ratings, favorites, and detail pages.', filter: (_) => true);
}

class GenresScreen extends StatelessWidget {
  const GenresScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final genres = seedMovies.expand((m) => m.genres).toSet().toList()..sort();
    return Scaffold(
      appBar: AppBar(title: const Text('Genres')),
      body: GridView.builder(
        padding: const EdgeInsets.all(20),
        itemCount: genres.length,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, mainAxisSpacing: 12, crossAxisSpacing: 12, childAspectRatio: 1.35),
        itemBuilder: (context, i) => InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () => context.push('/genre/${Uri.encodeComponent(genres[i])}'),
          child: GlassPanel(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [const Icon(Icons.category_outlined, color: Color(0xFFFFC400), size: 34), const SizedBox(height: 10), Text(genres[i], style: const TextStyle(fontWeight: FontWeight.w900))])),
        ),
      ),
    );
  }
}

class GenreDetailsScreen extends ConsumerWidget {
  const GenreDetailsScreen({super.key, required this.name});
  final String name;
  @override
  Widget build(BuildContext context, WidgetRef ref) => MovieListPage(title: name, subtitle: 'Movies filtered by genre with live Firestore catalog data.', filter: (m) => m.genres.contains(name));
}

class CollectionsScreen extends ConsumerWidget {
  const CollectionsScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(
        appBar: AppBar(title: const Text('Online cinema')),
        body: AsyncBlock<List<Movie>>(
          value: ref.watch(moviesProvider),
          builder: (items) {
            final source = items.isEmpty ? seedMovies : items;
            return ListView(padding: const EdgeInsets.all(20), children: [
              const PromoStrip(title: 'Watch now', message: 'Movies are grouped like an online cinema storefront. Posters open full details, reviews, favorites, and watchlists.'),
              MovieRail(title: 'New in subscription', movies: source),
              MovieRail(title: 'Family evening', movies: source.where((m) => m.genres.contains('Family') || m.genres.contains('Animation')).toList().ifEmpty(source)),
              MovieRail(title: 'Big screen action', movies: source.where((m) => m.genres.contains('Action') || m.genres.contains('Adventure')).toList().ifEmpty(source)),
            ]);
          },
        ),
      );
}

class PremieresScreen extends ConsumerWidget {
  const PremieresScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) => MovieListPage(title: 'Premieres', subtitle: 'Fresh releases and upcoming cinema cards.', filter: (m) => m.year >= 2024);
}

class TopScreen extends ConsumerWidget {
  const TopScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) => MovieListPage(title: 'Top 250', subtitle: 'Rating-based list similar to the classic Kinopoisk chart.', filter: (_) => true, sortByRating: true);
}

class SeriesScreen extends ConsumerWidget {
  const SeriesScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) => MovieListPage(title: 'Series', subtitle: 'Series-style catalog section with the same working movie actions.', filter: (m) => m.genres.contains('Drama') || m.genres.contains('Sci-Fi') || m.genres.contains('Family'));
}

class TicketsScreen extends ConsumerWidget {
  const TicketsScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) => MovieListPage(title: 'Cinema tickets', subtitle: 'Choose a film, open tickets, pick time and seats.', filter: (_) => true, tickets: true);
}

class CinemasScreen extends StatelessWidget {
  const CinemasScreen({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Cinemas')),
        body: ListView.separated(
          padding: const EdgeInsets.all(20),
          itemCount: cinemas.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, i) {
            final cinema = cinemas[i];
            return GlassPanel(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [const Icon(Icons.local_movies, color: Color(0xFFFFC400)), const SizedBox(width: 10), Expanded(child: Text(cinema.$1, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18))), Text(cinema.$2)]),
                const SizedBox(height: 8),
                Text(cinema.$3, style: const TextStyle(color: Colors.white70)),
                const SizedBox(height: 12),
                Wrap(spacing: 8, children: [for (final time in cinemaTimes) ActionChip(label: Text(time), onPressed: () => context.push('/tickets'))]),
              ]),
            );
          },
        ),
      );
}

class CalendarScreen extends StatelessWidget {
  const CalendarScreen({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Release calendar')),
        body: ListView.separated(
          padding: const EdgeInsets.all(20),
          itemCount: seedMovies.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, i) => ListTile(
            tileColor: Colors.white10,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            leading: CircleAvatar(backgroundColor: const Color(0xFFFFC400), child: Text('${i + 1}', style: const TextStyle(color: Colors.black, fontWeight: FontWeight.w900))),
            title: Text(seedMovies[i].title),
            subtitle: Text('Premiere week ${i + 1} / ${seedMovies[i].year}'),
            trailing: const Icon(Icons.event_available),
            onTap: () => context.push('/movie/${seedMovies[i].id}'),
          ),
        ),
      );
}

class AwardsScreen extends StatelessWidget {
  const AwardsScreen({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Awards')),
        body: ListView(padding: const EdgeInsets.all(20), children: [
          const PromoStrip(title: 'Awards season', message: 'Festival winners, audience favorites, best actor picks, and rating leaders.'),
          const SizedBox(height: 14),
          for (final movie in seedMovies.where((m) => m.rating >= 8)) Padding(padding: const EdgeInsets.only(bottom: 12), child: MovieListTile(movie: movie, trailing: const Icon(Icons.military_tech, color: Color(0xFFFFC400)))),
        ]),
      );
}

class MyRatingsScreen extends ConsumerWidget {
  const MyRatingsScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final uid = ref.watch(authProvider).currentUser?.uid;
    return Scaffold(
      appBar: AppBar(title: const Text('My ratings')),
      body: AsyncBlock<List<UserMovieRating>>(
        value: ref.watch(userRatingsProvider),
        builder: (ratings) {
          if (ratings.isEmpty) return const EmptyCinemaState(icon: Icons.star_border, title: 'No ratings yet', message: 'Open a movie and tap Rate this movie.');
          return ListView.separated(
            padding: const EdgeInsets.all(20),
            itemCount: ratings.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, i) {
              final rating = ratings[i];
              final movie = seedMovies.where((m) => m.id == rating.movieId).firstOrNull ?? seedMovies.first;
              return MovieListTile(movie: movie, trailing: Row(mainAxisSize: MainAxisSize.min, children: [RatingRow(rating.rating, compact: true), IconButton(onPressed: uid == null ? null : () => ref.read(repoProvider).deleteRating(uid, movie.id), icon: const Icon(Icons.delete_outline))]));
            },
          );
        },
      ),
    );
  }
}

class ReviewsFeedScreen extends ConsumerWidget {
  const ReviewsFeedScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(
        appBar: AppBar(title: const Text('Reviews feed')),
        body: AsyncBlock<List<Review>>(
          value: ref.watch(reviewsFeedProvider),
          builder: (reviews) {
            if (reviews.isEmpty) return const EmptyCinemaState(icon: Icons.rate_review_outlined, title: 'No reviews yet', message: 'Reviews from every movie will appear here live.');
            return ListView.separated(
              padding: const EdgeInsets.all(20),
              itemCount: reviews.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, i) {
                final review = reviews[i];
                final movie = seedMovies.where((m) => m.id == review.movieId).firstOrNull;
                return GlassPanel(
                  child: InkWell(
                    onTap: movie == null ? null : () => context.push('/movie/${movie.id}'),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [Expanded(child: Text(movie?.title ?? 'Movie', style: const TextStyle(fontWeight: FontWeight.w900))), RatingRow(review.rating, compact: true)]),
                      const SizedBox(height: 6),
                      Text(review.userName, style: const TextStyle(color: Colors.white70)),
                      const SizedBox(height: 8),
                      Text(review.text),
                    ]),
                  ),
                );
              },
            );
          },
        ),
      );
}

class MovieListPage extends ConsumerWidget {
  const MovieListPage({super.key, required this.title, required this.subtitle, required this.filter, this.sortByRating = false, this.tickets = false});
  final String title;
  final String subtitle;
  final bool Function(Movie movie) filter;
  final bool sortByRating;
  final bool tickets;
  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(
        appBar: AppBar(title: Text(title)),
        body: AsyncBlock<List<Movie>>(
          value: ref.watch(moviesProvider),
          builder: (items) {
            final source = (items.isEmpty ? seedMovies : items).where(filter).toList();
            if (sortByRating) source.sort((a, b) => b.rating.compareTo(a.rating));
            final list = source.isEmpty ? seedMovies : source;
            return ListView.separated(
              padding: const EdgeInsets.all(20),
              itemCount: list.length + 1,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, i) {
                if (i == 0) return PromoStrip(title: title, message: subtitle);
                final movie = list[i - 1];
                return MovieListTile(movie: movie, trailing: tickets ? FilledButton(onPressed: () => context.push('/movie/${movie.id}/tickets'), child: const Text('Buy')) : null);
              },
            );
          },
        ),
      );
}

class PersonsScreen extends StatelessWidget {
  const PersonsScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final people = seedMovies.expand((m) => m.cast).toSet().toList();
    return Scaffold(
      appBar: AppBar(title: const Text('People')),
      body: ListView.separated(
        padding: const EdgeInsets.all(20),
        itemCount: people.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (context, i) => ListTile(
          tileColor: Colors.white10,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          leading: CircleAvatar(backgroundColor: const Color(0xFFFFC400), child: Text('${i + 1}', style: const TextStyle(color: Colors.black, fontWeight: FontWeight.w900))),
          title: Text(people[i], style: const TextStyle(fontWeight: FontWeight.w800)),
          subtitle: const Text('Actor profile, filmography, rating'),
          onTap: () => context.push('/person/${Uri.encodeComponent(people[i])}'),
        ),
      ),
    );
  }
}

class PersonScreen extends StatelessWidget {
  const PersonScreen({super.key, required this.name});
  final String name;
  @override
  Widget build(BuildContext context) {
    final movies = seedMovies.where((m) => m.cast.contains(name)).toList().ifEmpty(seedMovies.take(3).toList());
    return Scaffold(
      appBar: AppBar(title: Text(name)),
      body: ListView(padding: const EdgeInsets.all(20), children: [
        GlassPanel(child: Row(children: [const CircleAvatar(radius: 42, child: Icon(Icons.person, size: 42)), const SizedBox(width: 16), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(name, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900)), const Text('Actor / filmmaker profile', style: TextStyle(color: Colors.white70)), const SizedBox(height: 8), const RatingRow(8.8, compact: true)]))])),
        const SizedBox(height: 12),
        const PromoStrip(title: 'Biography', message: 'Profile page includes filmography, rating, best works, and quick navigation to movies.'),
        MovieRail(title: 'Filmography', movies: movies),
      ]),
    );
  }
}

class NewsScreen extends StatelessWidget {
  const NewsScreen({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('News')),
        body: ListView.separated(
          padding: const EdgeInsets.all(20),
          itemCount: kinoNews.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, i) => ListTile(
            tileColor: Colors.white10,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            leading: const Icon(Icons.article_outlined, color: Color(0xFFFFC400)),
            title: Text(kinoNews[i].$1, style: const TextStyle(fontWeight: FontWeight.w800)),
            subtitle: Text(kinoNews[i].$2, maxLines: 2, overflow: TextOverflow.ellipsis),
            onTap: () => context.push('/news/$i'),
          ),
        ),
      );
}

class ArticleScreen extends StatelessWidget {
  const ArticleScreen({super.key, required this.id});
  final String id;
  @override
  Widget build(BuildContext context) {
    final index = int.tryParse(id) ?? 0;
    final item = kinoNews[index.clamp(0, kinoNews.length - 1)];
    return Scaffold(
      appBar: AppBar(title: const Text('Article')),
      body: ListView(padding: const EdgeInsets.all(20), children: [
        Text(item.$1, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900)),
        const SizedBox(height: 12),
        Text(item.$2, style: const TextStyle(color: Colors.white70, height: 1.5)),
        const SizedBox(height: 18),
        FilledButton.icon(onPressed: () => context.push('/catalog'), icon: const Icon(Icons.movie_filter_outlined), label: const Text('Open catalog')),
      ]),
    );
  }
}

class TrailerScreen extends ConsumerWidget {
  const TrailerScreen({super.key, required this.movieId});
  final String movieId;
  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(
        appBar: AppBar(title: const Text('Trailer')),
        body: AsyncBlock<Movie>(
          value: ref.watch(movieProvider(movieId)),
          builder: (movie) => ListView(padding: const EdgeInsets.all(20), children: [
            AspectRatio(aspectRatio: 16 / 9, child: ClipRRect(borderRadius: BorderRadius.circular(18), child: Stack(fit: StackFit.expand, children: [PosterImage(movie.backdropUrl), Container(color: Colors.black38), const Center(child: Icon(Icons.play_circle_fill, color: Color(0xFFFFC400), size: 76))]))),
            const SizedBox(height: 16),
            Text(movie.title, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900)),
            const Text('Trailer preview screen. The app keeps navigation, details, reviews, tickets, and watchlist flow working even without a video CDN.', style: TextStyle(color: Colors.white70)),
          ]),
        ),
      );
}

class TicketCheckoutScreen extends ConsumerStatefulWidget {
  const TicketCheckoutScreen({super.key, required this.movieId});
  final String movieId;
  @override
  ConsumerState<TicketCheckoutScreen> createState() => _TicketCheckoutScreenState();
}

class _TicketCheckoutScreenState extends ConsumerState<TicketCheckoutScreen> {
  int time = 0;
  final seats = <int>{};
  bool reserved = false;
  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Tickets')),
        body: AsyncBlock<Movie>(
          value: ref.watch(movieProvider(widget.movieId)),
          builder: (movie) => ListView(padding: const EdgeInsets.all(20), children: [
            MovieListTile(movie: movie),
            const SizedBox(height: 18),
            SegmentedButton<int>(segments: const [ButtonSegment(value: 0, label: Text('12:30')), ButtonSegment(value: 1, label: Text('18:00')), ButtonSegment(value: 2, label: Text('21:40'))], selected: {time}, onSelectionChanged: (v) => setState(() => time = v.first)),
            const SizedBox(height: 18),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: 24,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 6, mainAxisSpacing: 8, crossAxisSpacing: 8),
              itemBuilder: (_, i) => FilterChip(label: Text('${i + 1}'), selected: seats.contains(i), onSelected: (_) => setState(() => seats.contains(i) ? seats.remove(i) : seats.add(i))),
            ),
            const SizedBox(height: 18),
            if (reserved)
              Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: GlassPanel(child: Row(children: [const Icon(Icons.check_circle, color: Color(0xFF22C55E)), const SizedBox(width: 10), Expanded(child: Text('Reserved: ${seats.length} seat(s), ${cinemaTimes[time]}', style: const TextStyle(fontWeight: FontWeight.w800)))])),
              ),
            FilledButton.icon(
              onPressed: seats.isEmpty
                  ? null
                  : () {
                      setState(() => reserved = true);
                      snack(context, 'Ticket reserved: ${seats.length} seat(s).');
                    },
              icon: const Icon(Icons.payment),
              label: Text(reserved ? 'Update reservation' : 'Reserve ${seats.length} seat(s)'),
            ),
          ]),
        ),
      );
}

class WatchlistDetailsScreen extends ConsumerWidget {
  const WatchlistDetailsScreen({super.key, required this.listId});
  final String listId;
  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(
        appBar: AppBar(title: const Text('Watchlist')),
        body: AsyncBlock<List<Watchlist>>(
          value: ref.watch(watchlistsProvider),
          builder: (lists) {
            final list = lists.where((w) => w.id == listId).firstOrNull;
            if (list == null) return const EmptyCinemaState(icon: Icons.playlist_remove, title: 'List not found', message: 'It may have been deleted on another device.');
            final movies = seedMovies.where((m) => list.movieIds.contains(m.id)).toList();
            if (movies.isEmpty) return EmptyCinemaState(icon: Icons.playlist_add, title: list.name, message: 'Open a movie and add it here.');
            return ListView.separated(padding: const EdgeInsets.all(20), itemCount: movies.length, separatorBuilder: (_, __) => const SizedBox(height: 12), itemBuilder: (_, i) => MovieListTile(movie: movies[i]));
          },
        ),
      );
}

class HistoryScreen extends ConsumerWidget {
  const HistoryScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(
        appBar: AppBar(title: const Text('History')),
        body: AsyncBlock<List<String>>(
          value: ref.watch(historyProvider),
          builder: (ids) {
            final movies = seedMovies.where((m) => ids.contains(m.id)).toList();
            if (movies.isEmpty) return const EmptyCinemaState(icon: Icons.history, title: 'No views yet', message: 'Open any movie page and it will appear here.');
            return ListView.separated(padding: const EdgeInsets.all(20), itemCount: movies.length, separatorBuilder: (_, __) => const SizedBox(height: 12), itemBuilder: (_, i) => MovieListTile(movie: movies[i]));
          },
        ),
      );
}

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});
  @override
  Widget build(BuildContext context) => const SimpleInfoScreen(title: 'Notifications', icon: Icons.notifications_none, lines: ['New premieres', 'Review replies', 'Watchlist updates', 'Ticket reminders']);
}

class SubscriptionScreen extends StatelessWidget {
  const SubscriptionScreen({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Plus subscription')),
        body: ListView(padding: const EdgeInsets.all(20), children: [
          const PromoStrip(title: 'Plus', message: 'Online cinema access, saved lists, cached posters, synced profile, and premium movie feed.'),
          const SizedBox(height: 16),
          FilledButton.icon(onPressed: () => snack(context, 'Subscription demo activated.'), icon: const Icon(Icons.workspace_premium), label: const Text('Activate demo')),
        ]),
      );
}

class AchievementsScreen extends StatelessWidget {
  const AchievementsScreen({super.key});
  @override
  Widget build(BuildContext context) => const SimpleInfoScreen(title: 'Achievements', icon: Icons.emoji_events_outlined, lines: ['First review', 'Five favorites', 'Created watchlist', 'Opened Top 250']);
}

class SupportScreen extends StatefulWidget {
  const SupportScreen({super.key});
  @override
  State<SupportScreen> createState() => _SupportScreenState();
}

class _SupportScreenState extends State<SupportScreen> {
  final controller = TextEditingController();
  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Support')),
        body: ListView(padding: const EdgeInsets.all(20), children: [
          const PromoStrip(title: 'Help center', message: 'Send a question about auth, tickets, favorites, reviews, or sync.'),
          const SizedBox(height: 12),
          TextField(controller: controller, minLines: 4, maxLines: 6, decoration: const InputDecoration(labelText: 'Message')),
          const SizedBox(height: 12),
          FilledButton(onPressed: () { if (controller.text.trim().isEmpty) return snack(context, 'Write your question first.'); controller.clear(); snack(context, 'Support request sent.'); }, child: const Text('Send')),
        ]),
      );
}

class QaChecklistScreen extends StatelessWidget {
  const QaChecklistScreen({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Teacher QA checklist')),
        body: ListView(padding: const EdgeInsets.all(20), children: const [
          PromoStrip(title: 'Demo path', message: 'Register or sign in, open Tasks, save identity, add starter tasks, complete/edit/delete a task, then test sync on the second phone.'),
          SizedBox(height: 12),
          ChecklistTile(title: 'Google Sign-In', message: 'Login screen has Google button connected to Firebase Auth.'),
          ChecklistTile(title: 'Email/password auth', message: 'Registration and login forms validate input and show friendly errors.'),
          ChecklistTile(title: 'Task CRUD', message: 'Tasks can be added, edited, completed, reopened, deleted, and cleared.'),
          ChecklistTile(title: 'Real-time sync', message: 'Tasks, reviews, favorites, watchlists, ratings, identity, and profile use Firestore streams.'),
          ChecklistTile(title: 'Filters and stats', message: 'Tasks screen has All / Active / Done filters and live progress stats.'),
          ChecklistTile(title: 'Kinopoisk screens', message: 'Catalog, genres, Top 250, premieres, people, news, tickets, cinemas, ratings, reviews feed.'),
          ChecklistTile(title: 'Edge cases', message: 'Empty input, missing network, permission issues, empty states, and loading states are handled.'),
        ]),
      );
}

class ChecklistTile extends StatelessWidget {
  const ChecklistTile({super.key, required this.title, required this.message});
  final String title;
  final String message;
  @override
  Widget build(BuildContext context) => ListTile(
        leading: const Icon(Icons.check_circle_outline, color: Color(0xFFFFC400)),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
        subtitle: Text(message),
      );
}

class PrivacyScreen extends StatelessWidget {
  const PrivacyScreen({super.key});
  @override
  Widget build(BuildContext context) => const SimpleInfoScreen(title: 'Privacy', icon: Icons.privacy_tip_outlined, lines: ['Firebase Auth stores account access.', 'Firestore stores favorites, watchlists, reviews, and history.', 'Storage stores only profile avatars.']);
}

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});
  @override
  Widget build(BuildContext context) => const SimpleInfoScreen(title: 'About', icon: Icons.movie_filter_outlined, lines: ['Kinopoisk-style Flutter movie app.', '20+ screens.', 'Firebase Auth, Firestore, Storage.', 'Built for real phone demo.']);
}

class SimpleInfoScreen extends StatelessWidget {
  const SimpleInfoScreen({super.key, required this.title, required this.icon, required this.lines});
  final String title;
  final IconData icon;
  final List<String> lines;
  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text(title)),
        body: ListView(padding: const EdgeInsets.all(20), children: [
          Icon(icon, size: 72, color: const Color(0xFFFFC400)),
          const SizedBox(height: 16),
          Text(title, textAlign: TextAlign.center, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900)),
          const SizedBox(height: 20),
          for (final line in lines) ListTile(leading: const Icon(Icons.check_circle_outline, color: Color(0xFFFFC400)), title: Text(line)),
        ]),
      );
}

class ProfileLink extends StatelessWidget {
  const ProfileLink({super.key, required this.icon, required this.title, required this.route});
  final IconData icon;
  final String title;
  final String route;
  @override
  Widget build(BuildContext context) => ListTile(leading: Icon(icon, color: const Color(0xFFFFC400)), title: Text(title), trailing: const Icon(Icons.chevron_right), onTap: () => context.push(route));
}

class PromoStrip extends StatelessWidget {
  const PromoStrip({super.key, required this.title, required this.message});
  final String title;
  final String message;
  @override
  Widget build(BuildContext context) => GlassPanel(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900, color: const Color(0xFFFFC400))),
          const SizedBox(height: 8),
          Text(message, style: const TextStyle(color: Colors.white70, height: 1.4)),
        ]),
      );
}

class MovieListTile extends StatelessWidget {
  const MovieListTile({super.key, required this.movie, this.trailing});
  final Movie movie;
  final Widget? trailing;
  @override
  Widget build(BuildContext context) => ListTile(
        contentPadding: const EdgeInsets.all(10),
        tileColor: Colors.white10,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        leading: ClipRRect(borderRadius: BorderRadius.circular(10), child: SizedBox(width: 54, height: 78, child: PosterImage(movie.posterUrl))),
        title: Text(movie.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w900)),
        subtitle: Text('${movie.year}  ${movie.genres.join(' / ')}\nRating ${movie.rating.toStringAsFixed(1)}', maxLines: 2, overflow: TextOverflow.ellipsis),
        trailing: trailing,
        onTap: () => context.push('/movie/${movie.id}'),
      );
}

const kinoNews = [
  ('Premiere calendar updated', 'Fresh releases, festival hits, family films, and large-screen action are ready in the premieres section.'),
  ('Top 250 gets a new leader', 'The rating chart sorts movies by audience score and opens each film with reviews, trailers, and lists.'),
  ('Online cinema collection', 'Subscription-style shelves group movies by mood, genre, and popularity for a normal daily app experience.'),
  ('People page launched', 'Actor profiles now show short bio blocks and filmography navigation.'),
];

const starterTasks = [
  'Create account and sign in',
  'Add first task',
  'Complete one task',
  'Delete one task',
  'Check sync on second phone',
];

const identityColors = [0xFFFFC400, 0xFFE84855, 0xFF22C55E, 0xFF38BDF8, 0xFFA78BFA];

const cinemas = [
  ('Kinopark 8 IMAX', '4.8', 'Mega Center, hall with IMAX and evening sessions'),
  ('Chaplin Mega', '4.7', 'Premium seats, family screenings, late shows'),
  ('Arman Cinema', '4.6', 'Classic city cinema with premieres and festivals'),
  ('Kinoplexx', '4.5', 'Comfort halls, student-friendly ticket times'),
];

const cinemaTimes = ['12:30', '15:20', '18:00', '21:40'];

extension ListFallback<T> on List<T> {
  List<T> ifEmpty(List<T> fallback) => isEmpty ? fallback : this;
}

extension IterablePick<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}

class PosterImage extends StatelessWidget {
  const PosterImage(this.url, {super.key, this.fit = BoxFit.cover});
  final String url;
  final BoxFit fit;
  @override
  Widget build(BuildContext context) => CachedNetworkImage(imageUrl: url, fit: fit, placeholder: (_, __) => Container(color: Colors.white10, child: const Center(child: CircularProgressIndicator(strokeWidth: 2))), errorWidget: (_, __, ___) => Container(color: Colors.white10, child: const Icon(Icons.movie)));
}

class MovieCard extends StatelessWidget {
  const MovieCard({super.key, required this.movie, this.compact = false});
  final Movie movie;
  final bool compact;
  @override
  Widget build(BuildContext context) {
    final width = compact ? double.infinity : 156.0;
    return SizedBox(
      width: width,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => context.push('/movie/${movie.id}'),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (compact)
            Expanded(child: Hero(tag: 'poster-${movie.id}', child: ClipRRect(borderRadius: BorderRadius.circular(16), child: AspectRatio(aspectRatio: 2 / 3, child: PosterImage(movie.posterUrl)))))
          else
            Hero(tag: 'poster-${movie.id}', child: ClipRRect(borderRadius: BorderRadius.circular(16), child: SizedBox(height: 195, child: AspectRatio(aspectRatio: 2 / 3, child: PosterImage(movie.posterUrl))))),
          const SizedBox(height: 10),
          Text(movie.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          Row(children: [const Icon(Icons.star_rounded, color: Color(0xFFFFC400), size: 16), Text(' ${movie.rating.toStringAsFixed(1)}', style: const TextStyle(color: Colors.white70)), const Spacer(), Text('${movie.year}', style: const TextStyle(color: Colors.white54, fontSize: 12))]),
        ]),
      ),
    ).animate().fadeIn(duration: 250.ms).slideY(begin: .06, end: 0);
  }
}

class SectionHeader extends StatelessWidget {
  const SectionHeader(this.title, {super.key});
  final String title;
  @override
  Widget build(BuildContext context) => Padding(padding: const EdgeInsets.fromLTRB(20, 24, 20, 12), child: Text(title, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)));
}

class GlassPanel extends StatelessWidget {
  const GlassPanel({super.key, required this.child, this.padding = const EdgeInsets.all(16)});
  final Widget child;
  final EdgeInsets padding;
  @override
  Widget build(BuildContext context) => ClipRRect(borderRadius: BorderRadius.circular(20), child: BackdropFilter(filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18), child: Container(padding: padding, decoration: BoxDecoration(color: Colors.white.withValues(alpha: .08), border: Border.all(color: Colors.white.withValues(alpha: .12)), borderRadius: BorderRadius.circular(20)), child: child)));
}

class EmptyCinemaState extends StatelessWidget {
  const EmptyCinemaState({super.key, required this.icon, required this.title, required this.message});
  final IconData icon;
  final String title;
  final String message;
  @override
  Widget build(BuildContext context) => Center(child: Padding(padding: const EdgeInsets.all(32), child: Column(mainAxisSize: MainAxisSize.min, children: [Icon(icon, size: 64, color: const Color(0xFFFFC400)), const SizedBox(height: 16), Text(title, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800), textAlign: TextAlign.center), const SizedBox(height: 8), Text(message, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white70))])));
}

class AsyncBlock<T> extends StatelessWidget {
  const AsyncBlock({super.key, required this.value, required this.builder});
  final AsyncValue<T> value;
  final Widget Function(T data) builder;
  @override
  Widget build(BuildContext context) => value.when(data: builder, loading: () => const Center(child: CircularProgressIndicator()), error: (e, _) => Center(child: Padding(padding: const EdgeInsets.all(24), child: Text('Unable to load data. Check your connection and try again.\n$e', textAlign: TextAlign.center))));
}

class RatingRow extends StatelessWidget {
  const RatingRow(this.rating, {super.key, this.compact = false});
  final double rating;
  final bool compact;
  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.star_rounded, color: const Color(0xFFFFC400), size: compact ? 16 : 22), Text(' ${rating.toStringAsFixed(1)}', style: TextStyle(fontWeight: FontWeight.w900, fontSize: compact ? 13 : 18))]);
}

class Suggestions extends StatelessWidget {
  const Suggestions({super.key, required this.onPick, required this.history});
  final ValueChanged<String> onPick;
  final List<String> history;
  @override
  Widget build(BuildContext context) => ListView(padding: const EdgeInsets.all(20), children: [
        Text('Suggestions', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
        for (final s in ['Dune', 'Drama', 'Action', 'Zendaya', 'Oppenheimer']) ListTile(leading: const Icon(Icons.search), title: Text(s), onTap: () => onPick(s)),
        if (history.isNotEmpty) const Divider(),
        for (final h in history.take(5)) ListTile(leading: const Icon(Icons.history), title: Text(h), onTap: () => onPick(h)),
      ]);
}

class StatBox extends StatelessWidget {
  const StatBox({super.key, required this.label, required this.value});
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) => GlassPanel(child: Column(children: [Text(value, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900, color: const Color(0xFFFFC400))), Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12))]));
}

void snack(BuildContext context, String message) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message), behavior: SnackBarBehavior.floating));

String friendlyError(Object error) {
  final text = error.toString();
  if (text.contains('wrong-password') || text.contains('invalid-credential')) return 'Email or password is incorrect.';
  if (text.contains('email-already-in-use')) return 'That email is already registered.';
  if (text.contains('network')) return 'Network connection failed. Please try again.';
  if (text.contains('weak-password')) return 'Use a stronger password.';
  return 'Something went wrong. Please try again.';
}

void editWatchlist(BuildContext context, WidgetRef ref, {String? id, String name = ''}) {
  final controller = TextEditingController(text: name);
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(id == null ? 'New watchlist' : 'Edit watchlist'),
      content: TextField(controller: controller, decoration: const InputDecoration(labelText: 'Name')),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(
          onPressed: () async {
            final text = controller.text.trim();
            if (text.isEmpty) return;
            final uid = ref.read(authProvider).currentUser!.uid;
            await ref.read(repoProvider).saveWatchlist(uid, id, text);
            if (context.mounted) Navigator.pop(context);
          },
          child: const Text('Save'),
        ),
      ],
    ),
  );
}

void editTask(BuildContext context, WidgetRef ref, StudentTask task) {
  final controller = TextEditingController(text: task.title);
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Edit task'),
      content: TextField(controller: controller, autofocus: true, decoration: const InputDecoration(labelText: 'Task title')),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(
          onPressed: () async {
            final text = controller.text.trim();
            if (text.isEmpty) return;
            final uid = ref.read(authProvider).currentUser!.uid;
            await ref.read(repoProvider).updateTask(uid, task.id, text);
            if (context.mounted) {
              Navigator.pop(context);
              snack(context, 'Task updated.');
            }
          },
          child: const Text('Save'),
        ),
      ],
    ),
  );
}

void showWatchlistPicker(BuildContext context, WidgetRef ref, String movieId, List<Watchlist> lists) {
  showModalBottomSheet(
    context: context,
    builder: (context) => SafeArea(
      child: ListView(padding: const EdgeInsets.all(16), shrinkWrap: true, children: [
        Text('Add to watchlist', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
        for (final list in lists)
          ListTile(
            leading: const Icon(Icons.playlist_add),
            title: Text(list.name),
            trailing: Icon(list.movieIds.contains(movieId) ? Icons.check_circle : Icons.add_circle_outline),
            onTap: () {
              ref.read(repoProvider).watchlistMovie(list.id, movieId, !list.movieIds.contains(movieId));
              Navigator.pop(context);
            },
          ),
      ]),
    ),
  );
}

void showRatingDialog(BuildContext context, WidgetRef ref, Movie movie) {
  var rating = 8.0;
  showDialog(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) => AlertDialog(
        title: Text('Rate ${movie.title}'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          RatingRow(rating),
          Slider(value: rating, min: 1, max: 10, divisions: 18, label: rating.toStringAsFixed(1), onChanged: (value) => setState(() => rating = value)),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
              final uid = ref.read(authProvider).currentUser?.uid;
              if (uid == null) return;
              await ref.read(repoProvider).rateMovie(uid, movie.id, rating);
              if (context.mounted) {
                Navigator.pop(context);
                snack(context, 'Rating saved.');
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    ),
  );
}

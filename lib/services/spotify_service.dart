import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

import '../models/mood_result.dart';

class SpotifyService {
  static const String _authUrl = 'https://accounts.spotify.com/api/token';
  static const String _searchUrl = 'https://api.spotify.com/v1/search';
  static const int _recentHistoryLimit = 8;

  static final List<String> _recentSongKeys = <String>[];
  static final Map<String, int> _moodCursor = <String, int>{};

  String get _clientId => dotenv.env['SPOTIFY_CLIENT_ID'] ?? '';
  String get _clientSecret => dotenv.env['SPOTIFY_CLIENT_SECRET'] ?? '';

  String? _accessToken;
  DateTime? _tokenExpiry;

  static const Map<String, _MoodProfile> _moodProfiles = {
    'peaceful': _MoodProfile(
      searchQueries: [
        'calm indie folk peaceful',
        'serene ambient acoustic',
      ],
      fallbackSongs: [
        _SongSeed('Holocene', 'Bon Iver', 'Bon Iver, Bon Iver'),
        _SongSeed('Anchor', 'Novo Amor', 'Birthplace'),
        _SongSeed('Bloom', 'The Paper Kites', 'States'),
        _SongSeed('Coastline', 'Hollow Coves', 'Wanderlust EP'),
        _SongSeed('Mystery of Love', 'Sufjan Stevens', 'Call Me by Your Name'),
        _SongSeed('Cherry Wine (Live)', 'Hozier', 'Hozier'),
        _SongSeed('Flightless Bird, American Mouth', 'Iron & Wine', 'The Shepherd\'s Dog'),
        _SongSeed('Riverside', 'Agnes Obel', 'Philharmonics'),
        _SongSeed('To Build a Home', 'The Cinematic Orchestra', 'Ma Fleur'),
        _SongSeed('Heartbeats', 'Jose Gonzalez', 'Veneer'),
      ],
    ),
    'nostalgic': _MoodProfile(
      searchQueries: [
        'nostalgic classic indie',
        'golden hour throwback reflective',
      ],
      fallbackSongs: [
        _SongSeed('Vienna', 'Billy Joel', 'The Stranger'),
        _SongSeed('Landslide', 'Fleetwood Mac', 'Fleetwood Mac'),
        _SongSeed('The Night We Met', 'Lord Huron', 'Strange Trails'),
        _SongSeed('Fast Car', 'Tracy Chapman', 'Tracy Chapman'),
        _SongSeed('1979', 'The Smashing Pumpkins', 'Mellon Collie and the Infinite Sadness'),
        _SongSeed('Dreams', 'Fleetwood Mac', 'Rumours'),
        _SongSeed('Sweet Disposition', 'The Temper Trap', 'Conditions'),
        _SongSeed('Yellow', 'Coldplay', 'Parachutes'),
        _SongSeed('Scott Street', 'Phoebe Bridgers', 'Stranger in the Alps'),
        _SongSeed('Cigarette Daydreams', 'Cage the Elephant', 'Melophobia'),
      ],
    ),
    'dreamy': _MoodProfile(
      searchQueries: [
        'dream pop hazy ethereal',
        'dreamy indie night',
      ],
      fallbackSongs: [
        _SongSeed('Space Song', 'Beach House', 'Depression Cherry'),
        _SongSeed('Apocalypse', 'Cigarettes After Sex', 'Cigarettes After Sex'),
        _SongSeed('Moon Song', 'Phoebe Bridgers', 'Punisher'),
        _SongSeed('Sunsetz', 'Cigarettes After Sex', 'Cigarettes After Sex'),
        _SongSeed('Myth', 'Beach House', 'Bloom'),
        _SongSeed('Midnight City', 'M83', 'Hurry Up, We\'re Dreaming'),
        _SongSeed('Show Me How', 'Men I Trust', 'Oncle Jazz'),
        _SongSeed('Fade Into You', 'Mazzy Star', 'So Tonight That I Might See'),
        _SongSeed('Nothing\'s Gonna Hurt You Baby', 'Cigarettes After Sex', 'I.'),
        _SongSeed('Lover Is a Day', 'Cuco', 'Chiquito'),
      ],
    ),
    'urban': _MoodProfile(
      searchQueries: [
        'alt rnb urban night',
        'moody city pop hip hop',
      ],
      fallbackSongs: [
        _SongSeed('Nights', 'Frank Ocean', 'Blonde'),
        _SongSeed('SLOW DANCING IN THE DARK', 'Joji', 'BALLADS 1'),
        _SongSeed('After Hours', 'The Weeknd', 'After Hours'),
        _SongSeed('Passionfruit', 'Drake', 'More Life'),
        _SongSeed('Crew Love', 'Drake', 'Take Care'),
        _SongSeed('Location', 'Khalid', 'American Teen'),
        _SongSeed('Pink + White', 'Frank Ocean', 'Blonde'),
        _SongSeed('Self Control', 'Frank Ocean', 'Blonde'),
        _SongSeed('The Hills', 'The Weeknd', 'Beauty Behind the Madness'),
        _SongSeed('Thinkin Bout You', 'Frank Ocean', 'Channel Orange'),
      ],
    ),
    'focused': _MoodProfile(
      searchQueries: [
        'instrumental focus cinematic electronic',
        'deep focus ambient modern classical',
      ],
      fallbackSongs: [
        _SongSeed('Time', 'Hans Zimmer', 'Inception'),
        _SongSeed('Experience', 'Ludovico Einaudi', 'In a Time Lapse'),
        _SongSeed('A Moment Apart', 'ODESZA', 'A Moment Apart'),
        _SongSeed('Cornfield Chase', 'Hans Zimmer', 'Interstellar'),
        _SongSeed('Nuvole Bianche', 'Ludovico Einaudi', 'Una Mattina'),
        _SongSeed('Awake', 'Tycho', 'Awake'),
        _SongSeed('Sunset Lover', 'Petit Biscuit', 'Presence'),
        _SongSeed('Your Hand in Mine', 'Explosions in the Sky', 'The Earth Is Not a Cold Dead Place'),
        _SongSeed('Outro', 'M83', 'Hurry Up, We\'re Dreaming'),
        _SongSeed('Hoppipolla', 'Sigur Ros', 'Takk...'),
      ],
    ),
    'lonely': _MoodProfile(
      searchQueries: [
        'lonely indie late night',
        'sad intimate bedroom pop',
      ],
      fallbackSongs: [
        _SongSeed('Liability', 'Lorde', 'Melodrama'),
        _SongSeed('All I Want', 'Kodaline', 'In a Perfect World'),
        _SongSeed('I Found', 'Amber Run', '5AM'),
        _SongSeed('Someone You Loved', 'Lewis Capaldi', 'Divinely Uninspired to a Hellish Extent'),
        _SongSeed('Youth', 'Daughter', 'If You Leave'),
        _SongSeed('Waiting Game', 'BANKS', 'Goddess'),
        _SongSeed('Heather', 'Conan Gray', 'Kid Krow'),
        _SongSeed('Dancing On My Own', 'Robyn', 'Body Talk'),
        _SongSeed('Fallingforyou', 'The 1975', 'The 1975'),
        _SongSeed('Liability (Reprise)', 'Lorde', 'Melodrama'),
      ],
    ),
    'romantic': _MoodProfile(
      searchQueries: [
        'romantic soul love ballad',
        'intimate rnb date night',
      ],
      fallbackSongs: [
        _SongSeed('All of Me', 'John Legend', 'Love in the Future'),
        _SongSeed('Best Part', 'Daniel Caesar', 'Freudian'),
        _SongSeed('Adore You', 'Harry Styles', 'Fine Line'),
        _SongSeed('Love on the Brain', 'Rihanna', 'ANTI'),
        _SongSeed('Beyond', 'Leon Bridges', 'Good Thing'),
        _SongSeed('Kiss Me', 'Sixpence None the Richer', 'Sixpence None the Richer'),
        _SongSeed('At Last', 'Etta James', 'At Last!'),
        _SongSeed('Earned It', 'The Weeknd', 'Beauty Behind the Madness'),
        _SongSeed('Come Away With Me', 'Norah Jones', 'Come Away With Me'),
        _SongSeed('Can\'t Help Falling in Love', 'Kina Grannis', 'Crazy Rich Asians'),
      ],
    ),
    'playful': _MoodProfile(
      searchQueries: [
        'playful indie pop fun',
        'bright dance feel good',
      ],
      fallbackSongs: [
        _SongSeed('Electric Feel', 'MGMT', 'Oracular Spectacular'),
        _SongSeed('Feel It Still', 'Portugal. The Man', 'Woodstock'),
        _SongSeed('Tongue Tied', 'Grouplove', 'Never Trust a Happy Song'),
        _SongSeed('Levitating', 'Dua Lipa', 'Future Nostalgia'),
        _SongSeed('Shut Up and Dance', 'WALK THE MOON', 'Talking Is Hard'),
        _SongSeed('Young Folks', 'Peter Bjorn and John', 'Writer\'s Block'),
        _SongSeed('Put Your Records On', 'Corinne Bailey Rae', 'Corinne Bailey Rae'),
        _SongSeed('Walking on Sunshine', 'Katrina and the Waves', 'Walking on Sunshine'),
        _SongSeed('Classic', 'MKTO', 'MKTO'),
        _SongSeed('Sunday Best', 'Surfaces', 'Where the Light Is'),
      ],
    ),
    'cinematic': _MoodProfile(
      searchQueries: [
        'cinematic epic soundtrack',
        'orchestral emotional atmospheric',
      ],
      fallbackSongs: [
        _SongSeed('Outro', 'M83', 'Hurry Up, We\'re Dreaming'),
        _SongSeed('Run Boy Run', 'Woodkid', 'The Golden Age'),
        _SongSeed('Time', 'Hans Zimmer', 'Inception'),
        _SongSeed('Cornfield Chase', 'Hans Zimmer', 'Interstellar'),
        _SongSeed('Arrival of the Birds', 'The Cinematic Orchestra', 'The Crimson Wing'),
        _SongSeed('Saturn', 'Sleeping At Last', 'Atlas: Space'),
        _SongSeed('Exit Music (For a Film)', 'Radiohead', 'OK Computer'),
        _SongSeed('Wait', 'M83', 'Hurry Up, We\'re Dreaming'),
        _SongSeed('Mountains', 'Hans Zimmer', 'Interstellar'),
        _SongSeed('Experience', 'Ludovico Einaudi', 'In a Time Lapse'),
      ],
    ),
    'intense': _MoodProfile(
      searchQueries: [
        'intense high energy alternative',
        'dark hype cinematic rap',
      ],
      fallbackSongs: [
        _SongSeed('DNA.', 'Kendrick Lamar', 'DAMN.'),
        _SongSeed('HUMBLE.', 'Kendrick Lamar', 'DAMN.'),
        _SongSeed('Uprising', 'Muse', 'The Resistance'),
        _SongSeed('No Church in the Wild', 'JAY-Z & Kanye West', 'Watch the Throne'),
        _SongSeed('BLACK SKINHEAD', 'Kanye West', 'Yeezus'),
        _SongSeed('Believer', 'Imagine Dragons', 'Evolve'),
        _SongSeed('Seven Nation Army', 'The White Stripes', 'Elephant'),
        _SongSeed('Take Me Out', 'Franz Ferdinand', 'Franz Ferdinand'),
        _SongSeed('Smells Like Teen Spirit', 'Nirvana', 'Nevermind'),
        _SongSeed('Natural', 'Imagine Dragons', 'Origins'),
      ],
    ),
    'melancholic': _MoodProfile(
      searchQueries: [
        'melancholic sad indie',
        'heartbreak soft alternative',
      ],
      fallbackSongs: [
        _SongSeed('Skinny Love', 'Bon Iver', 'For Emma, Forever Ago'),
        _SongSeed('Roslyn', 'Bon Iver & St. Vincent', 'The Twilight Saga: New Moon'),
        _SongSeed('Someone Like You', 'Adele', '21'),
        _SongSeed('Funeral', 'Phoebe Bridgers', 'Punisher'),
        _SongSeed('Between the Bars', 'Elliott Smith', 'Either/Or'),
        _SongSeed('Breathe Me', 'Sia', 'Colour the Small One'),
        _SongSeed('Nothing Arrived', 'Villagers', '{Awayland}'),
        _SongSeed('Motion Picture Soundtrack', 'Radiohead', 'Kid A'),
        _SongSeed('Youth', 'Daughter', 'If You Leave'),
        _SongSeed('The Night We Met', 'Lord Huron', 'Strange Trails'),
      ],
    ),
    'warm': _MoodProfile(
      searchQueries: [
        'warm acoustic golden folk',
        'cozy feel good singer songwriter',
      ],
      fallbackSongs: [
        _SongSeed('Golden Hour', 'Kacey Musgraves', 'Golden Hour'),
        _SongSeed('Better Together', 'Jack Johnson', 'In Between Dreams'),
        _SongSeed('Home', 'Edward Sharpe & The Magnetic Zeros', 'Up from Below'),
        _SongSeed('Banana Pancakes', 'Jack Johnson', 'In Between Dreams'),
        _SongSeed('Sunflower', 'Rex Orange County', 'Apricot Princess'),
        _SongSeed('Come Away With Me', 'Norah Jones', 'Come Away With Me'),
        _SongSeed('Sweet Creature', 'Harry Styles', 'Harry Styles'),
        _SongSeed('Here Comes the Sun', 'The Beatles', 'Abbey Road'),
        _SongSeed('Bloom', 'The Paper Kites', 'States'),
        _SongSeed('Put Your Records On', 'Corinne Bailey Rae', 'Corinne Bailey Rae'),
      ],
    ),
    'mysterious': _MoodProfile(
      searchQueries: [
        'mysterious noir alternative',
        'dark moody trip hop',
      ],
      fallbackSongs: [
        _SongSeed('Redbone', 'Childish Gambino', 'Awaken, My Love!'),
        _SongSeed('Do I Wanna Know?', 'Arctic Monkeys', 'AM'),
        _SongSeed('Retrograde', 'James Blake', 'Overgrown'),
        _SongSeed('Teardrop', 'Massive Attack', 'Mezzanine'),
        _SongSeed('Pyramid Song', 'Radiohead', 'Amnesiac'),
        _SongSeed('Glory Box', 'Portishead', 'Dummy'),
        _SongSeed('After Dark', 'Mr.Kitty', 'Time'),
        _SongSeed('Angel', 'Massive Attack', 'Mezzanine'),
        _SongSeed('The Hills', 'The Weeknd', 'Beauty Behind the Madness'),
        _SongSeed('Nightcall', 'Kavinsky', 'OutRun'),
      ],
    ),
    'adventurous': _MoodProfile(
      searchQueries: [
        'adventure indie anthem roadtrip',
        'open road uplifting folk',
      ],
      fallbackSongs: [
        _SongSeed('Mountain Sound', 'Of Monsters and Men', 'My Head Is an Animal'),
        _SongSeed('Send Me On My Way', 'Rusted Root', 'When I Woke'),
        _SongSeed('Ends of the Earth', 'Lord Huron', 'Lonesome Dreams'),
        _SongSeed('Budapest', 'George Ezra', 'Wanted on Voyage'),
        _SongSeed('Dog Days Are Over', 'Florence + The Machine', 'Lungs'),
        _SongSeed('Rivers and Roads', 'The Head and the Heart', 'The Head and the Heart'),
        _SongSeed('On Top of the World', 'Imagine Dragons', 'Night Visions'),
        _SongSeed('Geronimo', 'Sheppard', 'Bombs Away'),
        _SongSeed('Adventure of a Lifetime', 'Coldplay', 'A Head Full of Dreams'),
        _SongSeed('Home', 'Edward Sharpe & The Magnetic Zeros', 'Up from Below'),
      ],
    ),
    'reflective': _MoodProfile(
      searchQueries: [
        'reflective introspective indie',
        'thoughtful ambient singer songwriter',
      ],
      fallbackSongs: [
        _SongSeed('Saturn', 'Sleeping At Last', 'Atlas: Space'),
        _SongSeed('Re: Stacks', 'Bon Iver', 'For Emma, Forever Ago'),
        _SongSeed('Riverside', 'Agnes Obel', 'Philharmonics'),
        _SongSeed('Holocene', 'Bon Iver', 'Bon Iver, Bon Iver'),
        _SongSeed('Wait', 'M83', 'Hurry Up, We\'re Dreaming'),
        _SongSeed('Everything in Its Right Place', 'Radiohead', 'Kid A'),
        _SongSeed('Anchor', 'Novo Amor', 'Birthplace'),
        _SongSeed('Hoppipolla', 'Sigur Ros', 'Takk...'),
        _SongSeed('Bloom', 'The Paper Kites', 'States'),
        _SongSeed('Vienna', 'Billy Joel', 'The Stranger'),
      ],
    ),
  };

  Future<SongResult> getSongForMood(String mood) async {
    final normalizedMood = _normalizeMood(mood);
    final profile =
        _moodProfiles[normalizedMood] ?? _moodProfiles['reflective']!;

    debugPrint('Spotify lookup start: mood=$normalizedMood');

    if (!_hasConfiguredCredentials) {
      debugPrint(
        'Spotify lookup fallback: missing credentials for mood=$normalizedMood',
      );
      return _selectFallbackSong(normalizedMood, profile, 'missing_credentials');
    }

    try {
      await _ensureValidToken();

      if (_accessToken == null) {
        debugPrint('Spotify lookup fallback: no access token mood=$normalizedMood');
        return _selectFallbackSong(normalizedMood, profile, 'token_unavailable');
      }

      final spotifyCandidates = <SongResult>[];
      final seenKeys = <String>{};

      for (final query in profile.searchQueries) {
        final results = await _searchTracks(query);
        for (final song in results) {
          final key = _songKey(song.title, song.artist);
          if (seenKeys.add(key)) {
            spotifyCandidates.add(song);
          }
        }
      }

      if (spotifyCandidates.isNotEmpty) {
        final selected = _selectSong(
          mood: normalizedMood,
          songs: spotifyCandidates,
          source: 'spotify',
        );
        debugPrint(
          'Spotify lookup success: mood=$normalizedMood source=spotify song=${selected.title} artist=${selected.artist} candidates=${spotifyCandidates.length}',
        );
        return selected;
      }

      debugPrint('Spotify lookup fallback: empty search results mood=$normalizedMood');
      return _selectFallbackSong(normalizedMood, profile, 'empty_results');
    } catch (e, st) {
      debugPrint('Spotify lookup fallback: mood=$normalizedMood error=$e');
      debugPrintStack(stackTrace: st);
      return _selectFallbackSong(normalizedMood, profile, 'exception');
    }
  }

  bool get _hasConfiguredCredentials =>
      _clientId.isNotEmpty &&
      _clientSecret.isNotEmpty &&
      _clientId != 'your_spotify_client_id_here' &&
      _clientSecret != 'your_spotify_client_secret_here';

  String _normalizeMood(String mood) {
    final normalized = mood.trim().toLowerCase();
    if (_moodProfiles.containsKey(normalized)) {
      return normalized;
    }
    return 'reflective';
  }

  Future<List<SongResult>> _searchTracks(String query) async {
    final songs = <SongResult>[];
    var response = await _performSearchRequest(query);

    if (response.statusCode == 401) {
      debugPrint('Spotify search token expired, refreshing for query=$query');
      _accessToken = null;
      _tokenExpiry = null;
      await _ensureValidToken(forceRefresh: true);
      response = await _performSearchRequest(query);
    }

    if (response.statusCode != 200) {
      debugPrint(
        'Spotify search failed: query=$query status=${response.statusCode} body=${response.body}',
      );
      return songs;
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final tracks = (data['tracks']?['items'] as List?) ?? const [];

    for (final item in tracks) {
      if (item is! Map<String, dynamic>) {
        continue;
      }

      final song = _songFromSpotifyTrack(item);
      if (song != null) {
        songs.add(song);
      }
    }

    debugPrint('Spotify search success: query=$query results=${songs.length}');
    return songs;
  }

  Future<http.Response> _performSearchRequest(String query) {
    return http
        .get(
          Uri.parse(
            '$_searchUrl?q=${Uri.encodeComponent(query)}&type=track&limit=8',
          ),
          headers: {'Authorization': 'Bearer $_accessToken'},
        )
        .timeout(const Duration(seconds: 8));
  }

  SongResult? _songFromSpotifyTrack(Map<String, dynamic> track) {
    final title = track['name'] as String?;
    final artistList = track['artists'] as List?;
    final album = track['album'] as Map<String, dynamic>?;
    final artist = artistList != null && artistList.isNotEmpty
        ? artistList.first['name'] as String?
        : null;

    if (title == null || artist == null) {
      return null;
    }

    final images = album?['images'] as List?;

    return SongResult(
      title: title,
      artist: artist,
      album: album?['name'] as String? ?? '',
      albumArtUrl:
          images != null && images.isNotEmpty ? images.first['url'] as String? : null,
      previewUrl: track['preview_url'] as String?,
      spotifyUrl: track['external_urls']?['spotify'] as String?,
    );
  }

  SongResult _selectFallbackSong(
    String mood,
    _MoodProfile profile,
    String reason,
  ) {
    final songs = profile.fallbackSongs
        .map(
          (song) => SongResult(
            title: song.title,
            artist: song.artist,
            album: song.album,
            albumArtUrl: song.albumArtUrl,
          ),
        )
        .toList();

    final selected = _selectSong(
      mood: mood,
      songs: songs,
      source: 'local_pool',
    );

    debugPrint(
      'Spotify lookup fallback selected: mood=$mood source=local_pool reason=$reason song=${selected.title} artist=${selected.artist}',
    );

    return selected;
  }

  SongResult _selectSong({
    required String mood,
    required List<SongResult> songs,
    required String source,
  }) {
    final recentFiltered = songs
        .where((song) => !_recentSongKeys.contains(_songKey(song.title, song.artist)))
        .toList();
    final availableSongs = recentFiltered.isNotEmpty ? recentFiltered : songs;
    final cursor = _moodCursor[mood] ?? 0;
    final selected = availableSongs[cursor % availableSongs.length];

    _moodCursor[mood] = cursor + 1;
    _rememberSong(selected);

    debugPrint(
      'Song selected: mood=$mood source=$source title=${selected.title} artist=${selected.artist}',
    );

    return selected;
  }

  void _rememberSong(SongResult song) {
    final key = _songKey(song.title, song.artist);
    _recentSongKeys.remove(key);
    _recentSongKeys.add(key);

    if (_recentSongKeys.length > _recentHistoryLimit) {
      _recentSongKeys.removeAt(0);
    }
  }

  String _songKey(String title, String artist) =>
      '${title.trim().toLowerCase()}::${artist.trim().toLowerCase()}';

  Future<void> _ensureValidToken({bool forceRefresh = false}) async {
    if (!forceRefresh &&
        _accessToken != null &&
        _tokenExpiry != null &&
        DateTime.now().isBefore(_tokenExpiry!)) {
      return;
    }

    final credentials = base64Encode(utf8.encode('$_clientId:$_clientSecret'));

    try {
      final response = await http
          .post(
            Uri.parse(_authUrl),
            headers: {
              'Authorization': 'Basic $credentials',
              'Content-Type': 'application/x-www-form-urlencoded',
            },
            body: 'grant_type=client_credentials',
          )
          .timeout(const Duration(seconds: 8));

      if (response.statusCode != 200) {
        debugPrint(
          'Spotify auth failed: status=${response.statusCode} body=${response.body}',
        );
        _accessToken = null;
        _tokenExpiry = null;
        return;
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      _accessToken = data['access_token'] as String?;

      final expiresIn = data['expires_in'] as int? ?? 3600;
      _tokenExpiry = DateTime.now().add(Duration(seconds: expiresIn - 60));

      debugPrint('Spotify auth success: token refreshed');
    } catch (e) {
      debugPrint('Spotify auth error: $e');
      _accessToken = null;
      _tokenExpiry = null;
    }
  }
}

class _MoodProfile {
  final List<String> searchQueries;
  final List<_SongSeed> fallbackSongs;

  const _MoodProfile({
    required this.searchQueries,
    required this.fallbackSongs,
  });
}

class _SongSeed {
  final String title;
  final String artist;
  final String album;
  final String? albumArtUrl;

  const _SongSeed(
    this.title,
    this.artist,
    this.album, {
    this.albumArtUrl,
  });
}

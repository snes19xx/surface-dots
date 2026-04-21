import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:dbus/dbus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:palette_generator_master/palette_generator_master.dart';
import 'package:window_manager/window_manager.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await windowManager.ensureInitialized();
  const Size windowSize = Size(252, 420);

  WindowOptions windowOptions = const WindowOptions(
    size: windowSize,
    center: true,
    backgroundColor: Colors.transparent,
    skipTaskbar: false,
    titleBarStyle: TitleBarStyle.hidden,
  );

  await windowManager.waitUntilReadyToShow(windowOptions, () async {
    await windowManager.setResizable(false);
    await windowManager.setSize(windowSize);
    await windowManager.show();
    await windowManager.focus();
  });

  runApp(const NowPlayingApp());
}

class NowPlayingApp extends StatefulWidget {
  const NowPlayingApp({super.key});

  @override
  State<NowPlayingApp> createState() => _NowPlayingAppState();
}

class _NowPlayingAppState extends State<NowPlayingApp> {
  ColorScheme _scheme = ColorScheme.fromSeed(
    seedColor: const Color(0xFFB061FF),
    brightness: Brightness.dark,
    surface: const Color(0xFF121212),
    dynamicSchemeVariant: DynamicSchemeVariant.fidelity,
  );

  void _applyScheme(ColorScheme scheme) {
    if (!mounted) return;
    setState(() => _scheme = scheme);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorScheme: _scheme,
        scaffoldBackgroundColor: Colors.transparent,
      ),
      home: NowPlayingWidget(onSchemeChanged: _applyScheme),
    );
  }
}

class FontCombo {
  final String titleFont;
  final String artistFont;
  final FontStyle titleStyle;
  final FontStyle artistStyle;
  final FontWeight titleWeight;
  final FontWeight artistWeight;

  const FontCombo({
    required this.titleFont,
    required this.artistFont,
    this.titleStyle = FontStyle.normal,
    this.artistStyle = FontStyle.normal,
    this.titleWeight = FontWeight.w700,
    this.artistWeight = FontWeight.w500,
  });
}

class NowPlayingWidget extends StatefulWidget {
  const NowPlayingWidget({super.key, required this.onSchemeChanged});
  final ValueChanged<ColorScheme> onSchemeChanged;

  @override
  State<NowPlayingWidget> createState() => _NowPlayingWidgetState();
}

class _NowPlayingWidgetState extends State<NowPlayingWidget>
    with TickerProviderStateMixin {
  static const double _maxCardWidth = 256;
  static const double _albumSize = 210;
  final GlobalKey _cardKey = GlobalKey();

  final Map<String, _PlayerData> _knownPlayers = {};
  String? _activePlayerName;

  String _title = 'Nothing playing';
  String _artist = '';
  String _albumArt = '';
  bool _isPlaying = false;
  double _durationSec = 180;
  double _positionSec = 0;

  bool _isDraggingBar = false;
  double _dragPercent = 0.0;
  bool _isAlbumPressed = false;

  Color _primaryPop = const Color(0xFFB061FF);
  Color _primarySoft = const Color(0xFF9040DF);
  String _lastArtKey = '';

  bool _isBarHovered = false;

  Process? _playerCtlProcess;
  StreamSubscription? _playerCtlSub;

  late Ticker _positionTicker;
  late AnimationController _breathingController;

  DateTime? _lastSyncTime;
  double _syncedPosition = 0;
  Timer? _driftSyncTimer;
  Timer? _cleanupTimer;
  Timer? _artRetryTimer;

  Timer? _resizeDebounce;
  double _lastMeasuredHeight = 0;

  final Duration _uiTickInterval = const Duration(milliseconds: 150);
  DateTime _lastUiTick = DateTime.fromMillisecondsSinceEpoch(0);

  final List<String> _musicApps = [
    'spotify', 'rhythmbox', 'mpd', 'cider', 'music', 'audacious', 'vlc', 'pear'
  ];
  final List<String> _browsers = [
    'firefox', 'chromium', 'chrome', 'brave', 'edge', 'opera'
  ];

  final List<FontCombo> _fontCombos = [
    const FontCombo(titleFont: 'Inter', artistFont: 'Inter', titleWeight: FontWeight.w700),
    const FontCombo(titleFont: 'Manrope', artistFont: 'Manrope', titleWeight: FontWeight.w700),
    const FontCombo(titleFont: 'Arial', artistFont: 'Arial', titleWeight: FontWeight.bold),
    const FontCombo(titleFont: 'Roboto', artistFont: 'Roboto', titleWeight: FontWeight.w600),
    const FontCombo(titleFont: 'sans-serif', artistFont: 'sans-serif', titleWeight: FontWeight.bold),
    const FontCombo(titleFont: 'EB Garamond', artistFont: 'Inter', titleWeight: FontWeight.w600),
    const FontCombo(titleFont: 'Lora', artistFont: 'Lora', titleWeight: FontWeight.w600),
    const FontCombo(titleFont: 'Georgia', artistFont: 'Arial', titleWeight: FontWeight.bold),
    const FontCombo(titleFont: 'monospace', artistFont: 'monospace', titleWeight: FontWeight.bold),
  ];
  int _fontIndex = 0;

  File get _fontPrefFile {
    final home = Platform.environment['HOME'] ?? '';
    return File('$home/.cache/now_playing_font_pref.txt');
  }

  @override
  void initState() {
    super.initState();
    debugPrint('[DEBUG] Widget InitState started.');
    _loadFontPref();

    _breathingController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    );

    _positionTicker = createTicker((elapsed) {
      if (_lastSyncTime == null || !_isPlaying || _isDraggingBar) return;
      final now = DateTime.now();
      if (now.difference(_lastUiTick) < _uiTickInterval) return;
      _lastUiTick = now;
      final diff = now.difference(_lastSyncTime!).inMilliseconds / 1000.0;
      final newPos = (_syncedPosition + diff).clamp(0.0, _durationSec);
      if ((newPos - _positionSec).abs() > 0.02) {
        if (!mounted) return;
        setState(() => _positionSec = newPos);
      }
    });

    _initStream();
    _driftSyncTimer =
        Timer.periodic(const Duration(seconds: 7), (_) => _syncPositionOnly());
    _cleanupTimer =
        Timer.periodic(const Duration(seconds: 3), (_) => _checkAlivePlayers());
    WidgetsBinding.instance.addPostFrameCallback((_) => _scheduleResize());
  }

  @override
  void dispose() {
    _playerCtlSub?.cancel();
    _playerCtlProcess?.kill();
    _driftSyncTimer?.cancel();
    _cleanupTimer?.cancel();
    _artRetryTimer?.cancel();
    _resizeDebounce?.cancel();
    _positionTicker.dispose();
    _breathingController.dispose();
    super.dispose();
  }

  void _loadFontPref() {
    try {
      if (_fontPrefFile.existsSync()) {
        final idx = int.parse(_fontPrefFile.readAsStringSync().trim());
        if (idx >= 0 && idx < _fontCombos.length) _fontIndex = idx;
      }
    } catch (_) {}
  }

  void _cycleFont() {
    setState(() {
      _fontIndex = (_fontIndex + 1) % _fontCombos.length;
    });
    try {
      _fontPrefFile.writeAsStringSync(_fontIndex.toString());
    } catch (_) {}
  }

  // ---------------------------------------------------------------------------
  // DBUS QUERY FOR STARTUP FALLBACK
  // ---------------------------------------------------------------------------
  Future<String> _fetchArtViaDBus(String playerName) async {
    DBusClient? client;
    try {
      client = DBusClient.session();
      final busNames = await client.listNames();
      
      final targetBus = busNames.firstWhere(
        (name) => name.toLowerCase().startsWith('org.mpris.mediaplayer2.${playerName.toLowerCase()}'),
        orElse: () => '',
      );

      if (targetBus.isEmpty) return '';

      final object = DBusRemoteObject(
        client,
        name: targetBus,
        path: DBusObjectPath('/org/mpris/MediaPlayer2'),
      );

      final metaVariant = await object.getProperty('org.mpris.MediaPlayer2.Player', 'Metadata');
      final metaMap = metaVariant.toNative();
      
      if (metaMap is Map) {
        final artUrl = metaMap['mpris:artUrl'];
        if (artUrl != null && artUrl.toString().trim().isNotEmpty) {
          return artUrl.toString().trim();
        }
      }
      return '';
    } catch (e) {
      debugPrint('[DEBUG DBUS] Error querying D-Bus: $e');
      return '';
    } finally {
      client?.close();
    }
  }

  // ---------------------------------------------------------------------------
  // FIREFOX MANUAL CACHE FALLBACK
  // ---------------------------------------------------------------------------
  String _getFirefoxFallbackArt() {
    try {
      debugPrint('[DEBUG FIREFOX] Attempting manual directory scan.');
      final home = Platform.environment['HOME'] ?? '';
      final dir = Directory('$home/.mozilla/firefox/firefox-mpris');
      
      if (!dir.existsSync()) {
        debugPrint('[DEBUG FIREFOX] Directory does not exist.');
        return '';
      }

      final files = dir.listSync().whereType<File>().where((f) {
        final path = f.path.toLowerCase();
        return path.endsWith('.png') || path.endsWith('.jpg') || path.endsWith('.jpeg');
      }).toList();

      if (files.isEmpty) return '';

      // Sort by modified time descending to get the most recent cover
      files.sort((a, b) => b.lastModifiedSync().compareTo(a.lastModifiedSync()));
      final latest = files.first.path;
      debugPrint('[DEBUG FIREFOX] Found latest cached art: $latest');
      
      return 'file://$latest';
    } catch (e) {
      debugPrint('[DEBUG FIREFOX] Manual fallback failed: $e');
      return '';
    }
  }

  Future<void> _initStream() async {
    await Future.delayed(const Duration(milliseconds: 1000));
    await _seedPlayersOnce();
    _recalculateActivePlayer(); 
    await _startPlayerctlFollow();
  }

  Future<void> _seedPlayersOnce() async {
    try {
      final listRes = await Process.run('playerctl', ['-l']);
      final players = listRes.stdout.toString().trim().split('\n').where((s) => s.isNotEmpty).toList();
      
      for (final p in players) {
        final res = await Process.run('playerctl', [
          '-p', p, 'metadata', '--format',
          '{{status}};;{{mpris:length}};;{{mpris:artUrl}};;{{title}};;{{artist}}',
        ]);
        
        final out = res.stdout.toString().trim();
        if (out.isEmpty) continue;
        
        final parts = out.split(';;');
        if (parts.length < 5) continue;
        
        final name = p.trim().toLowerCase();
        final status = parts[0].trim();
        final lenStr = parts[1].trim();
        String rawArtUrl = parts[2].trim();
        final title = parts[3].trim();
        final artist = parts[4].trim();

        if ((rawArtUrl.isEmpty || _isPlaceholder(rawArtUrl, 'mpris:artUrl')) && _isBrowser(name)) {
          rawArtUrl = await _fetchArtViaDBus(name);
          
          if (rawArtUrl.isEmpty && name.contains('firefox')) {
            rawArtUrl = _getFirefoxFallbackArt();
          }
        }

        final currentArt = _isPlaceholder(rawArtUrl, 'mpris:artUrl') ? '' : rawArtUrl;

        _knownPlayers[name] = _PlayerData(
          name: name,
          status: status,
          lengthStr: lenStr,
          artUrl: currentArt,
          lastGoodArtUrl: currentArt,
          title: title,
          artist: artist,
          lastUpdated: DateTime.now(),
        );

        if (currentArt.isNotEmpty) {
          final normUrl = _normalizeArtUrl(currentArt);
          unawaited(_updateTheme(normUrl));
        }
      }
    } catch (e) {
      debugPrint('[DEBUG SEED] Seed failed completely: $e');
    }
  }

  Future<void> _startPlayerctlFollow() async {
    try {
      _playerCtlProcess = await Process.start('playerctl', [
        '-a', 'metadata', '--format',
        '{{playerName}};;{{status}};;{{mpris:length}};;{{mpris:artUrl}};;{{title}};;{{artist}}',
        '--follow',
      ]);
      _playerCtlSub = _playerCtlProcess!.stdout
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen(
        (line) {
          if (line.trim().isEmpty) return;
          _processUpdate(line);
        },
        onDone: () {
          if (!mounted) return;
          Future.delayed(const Duration(seconds: 1), () {
            if (!mounted) return;
            _startPlayerctlFollow();
          });
        },
      );
    } catch (_) {}
  }

  Future<void> _checkAlivePlayers() async {
    try {
      final res = await Process.run('playerctl', ['-a', '-l']);
      final aliveList = res.stdout
          .toString()
          .trim()
          .split('\n')
          .where((s) => s.trim().isNotEmpty)
          .map((s) => s.trim().toLowerCase())
          .toList();
      final currentKeys = _knownPlayers.keys.toList();
      bool changed = false;
      for (final key in currentKeys) {
        final isAlive = aliveList.any((a) => a == key || a.startsWith('$key.'));
        if (!isAlive) {
          _knownPlayers.remove(key);
          changed = true;
        }
      }
      if (changed) _recalculateActivePlayer();
    } catch (_) {}
  }

  bool _isPlaceholder(String v, String placeholder) {
    final s = v.trim();
    if (s.isEmpty) return true;
    if (s.toLowerCase() == placeholder.toLowerCase()) return true;
    return false;
  }

  void _processUpdate(String line) {
    if (!mounted) return;
    final parts = line.split(';;');
    if (parts.length < 6) return;
    final name = parts[0].trim().toLowerCase();
    final status = parts[1].trim();
    final lenStr = parts[2].trim();
    final rawArtUrl = parts[3].trim();
    final title = parts[4].trim();
    final artist = parts[5].trim();
    
    final prev = _knownPlayers[name];
    
    final mergedName = name;
    final mergedStatus = _isPlaceholder(status, 'status') ? (prev?.status ?? '') : status;
    final mergedLen = _isPlaceholder(lenStr, 'mpris:length') ? (prev?.lengthStr ?? '') : lenStr;
    final mergedTitle = (!_isPlaceholder(title, 'title') && title.isNotEmpty) ? title : (prev?.title ?? '');
    final mergedArtist = (!_isPlaceholder(artist, 'artist') && artist.isNotEmpty) ? artist : (prev?.artist ?? '');

    String newGoodArt = prev?.lastGoodArtUrl ?? '';
    String currentArt = _isPlaceholder(rawArtUrl, 'mpris:artUrl') ? '' : rawArtUrl;
    
    if (currentArt.isNotEmpty) {
      newGoodArt = currentArt;
    } else if (prev != null && mergedTitle == prev.title) {
      currentArt = newGoodArt; 
    } else {
      newGoodArt = '';
      currentArt = '';
    }

    _knownPlayers[name] = _PlayerData(
      name: mergedName,
      status: mergedStatus,
      lengthStr: mergedLen,
      artUrl: currentArt,
      lastGoodArtUrl: newGoodArt,
      title: mergedTitle,
      artist: mergedArtist,
      lastUpdated: DateTime.now(),
    );
    _recalculateActivePlayer();
  }

  void _recalculateActivePlayer() {
    if (_knownPlayers.isEmpty) {
      _resetUi();
      return;
    }
    int statusRank(String s) {
      if (s == 'Playing') return 0;
      if (s == 'Paused') return 1;
      return 2;
    }
    final sorted = _knownPlayers.values.toList();
    sorted.sort((a, b) {
      final ar = statusRank(a.status);
      final br = statusRank(b.status);
      if (ar != br) return ar.compareTo(br);
      final aIsMusic = _isMusicApp(a.name);
      final bIsMusic = _isMusicApp(b.name);
      if (aIsMusic && !bIsMusic) return -1;
      if (!aIsMusic && bIsMusic) return 1;
      final aIsBrowser = _isBrowser(a.name);
      final bIsBrowser = _isBrowser(b.name);
      if (!aIsBrowser && bIsBrowser) return -1;
      if (aIsBrowser && !bIsBrowser) return 1;
      return b.lastUpdated.compareTo(a.lastUpdated);
    });
    
    final winner = sorted.first;
    final sourceChanged = _activePlayerName != winner.name;
    _activePlayerName = winner.name;

    if (winner.artUrl.isEmpty) {
      _startArtRetry(winner.name);
    } else {
      _artRetryTimer?.cancel();
    }

    _updateUiFromPlayer(winner, forceUpdate: sourceChanged);
  }

  void _startArtRetry(String playerName) {
    _artRetryTimer?.cancel();
    _artRetryTimer = Timer.periodic(const Duration(milliseconds: 1000), (timer) async {
      if (_activePlayerName != playerName) {
        timer.cancel();
        return;
      }
      try {
        String out = '';
        if (_isBrowser(playerName)) {
          out = await _fetchArtViaDBus(playerName);
          if (out.isEmpty && playerName.contains('firefox')) {
            out = _getFirefoxFallbackArt();
          }
        }
        
        if (out.isEmpty) {
          final res = await Process.run('playerctl', ['-p', playerName, 'metadata', 'mpris:artUrl']);
          out = res.stdout.toString().trim();
        }

        if (out.isNotEmpty && !_isPlaceholder(out, 'mpris:artUrl')) {
          timer.cancel();
          if (!mounted) return;
          final current = _knownPlayers[playerName];
          if (current != null) {
            _knownPlayers[playerName] = _PlayerData(
              name: current.name,
              status: current.status,
              lengthStr: current.lengthStr,
              artUrl: out,
              lastGoodArtUrl: out,
              title: current.title,
              artist: current.artist,
              lastUpdated: current.lastUpdated,
            );
            if (_activePlayerName == playerName) {
              _updateUiFromPlayer(_knownPlayers[playerName]!);
            }
          }
        }
      } catch (_) {}
    });
  }

  void _resetUi() {
    if (_title == 'Nothing playing' && !_isPlaying) return;
    final shouldResize = _title != 'Nothing playing' ||
        _artist.isNotEmpty ||
        _albumArt.isNotEmpty ||
        _isBarHovered;
    setState(() {
      _activePlayerName = null;
      _title = 'Nothing playing';
      _artist = '';
      _albumArt = '';
      _isPlaying = false;
      _positionSec = 0;
      _syncedPosition = 0;
      _lastSyncTime = null;
    });
    if (_positionTicker.isActive) _positionTicker.stop();
    if (_breathingController.isAnimating) _breathingController.stop();
    if (shouldResize) _scheduleResize();
  }

  bool _isMusicApp(String name) => _musicApps.any((app) => name.contains(app));
  bool _isBrowser(String name) => _browsers.any((app) => name.contains(app));

  void _updateUiFromPlayer(_PlayerData p, {bool forceUpdate = false}) {
    final isPlayingNow = (p.status == 'Playing');
    final normalizedArt = _normalizeArtUrl(p.artUrl);
    final finalTitle = p.title.isEmpty ? (isPlayingNow ? 'Loading...' : 'Nothing playing') : p.title;
    final finalArtist = p.artist;

    double newDur = _durationSec;
    if (!_isPlaceholder(p.lengthStr, 'mpris:length')) {
      try {
        newDur = math.max(1.0, int.parse(p.lengthStr) / 1000000.0);
      } catch (_) {}
    }

    final titleChanged = finalTitle != _title;
    final artistChanged = finalArtist != _artist;
    final artChanged = normalizedArt != _albumArt;

    setState(() {
      _title = finalTitle;
      _artist = finalArtist;
      _albumArt = normalizedArt;
      _durationSec = newDur;
      _isPlaying = isPlayingNow;
    });

    if (isPlayingNow) {
      if (!_positionTicker.isActive) {
        _lastUiTick = DateTime.fromMillisecondsSinceEpoch(0);
        _positionTicker.start();
        _lastSyncTime = DateTime.now();
        _syncPositionOnly();
      }
      if (!_breathingController.isAnimating) {
        _breathingController.repeat(reverse: true);
      }
    } else {
      if (_positionTicker.isActive) _positionTicker.stop();
      if (_breathingController.isAnimating) _breathingController.stop();
    }

    if (normalizedArt.isNotEmpty && normalizedArt != _lastArtKey) {
      _lastArtKey = normalizedArt;
      unawaited(_updateTheme(normalizedArt));
    }

    if (titleChanged || artistChanged || artChanged) {
      _scheduleResize();
    }
    if (forceUpdate) _syncPositionOnly();
  }

  Future<ProcessResult> _runPlayerctl(List<String> args) {
    final full = <String>[];
    if (_activePlayerName != null) {
      full.addAll(['-p', _activePlayerName!]);
    }
    full.addAll(args);
    return Process.run('playerctl', full);
  }

  Future<void> _syncPositionOnly() async {
    if (_activePlayerName == null || _isDraggingBar) return;
    try {
      final res = await _runPlayerctl(['position']);
      final txt = res.stdout.toString().trim();
      if (txt.isEmpty) return;
      final pos = double.tryParse(txt);
      if (pos == null || !mounted) return;
      _syncedPosition = pos;
      _lastSyncTime = DateTime.now();
      if (!_isPlaying && !_isDraggingBar) setState(() => _positionSec = pos);
    } catch (_) {}
  }

  String _normalizeArtUrl(String url) {
    if (url.isEmpty || url == 'mpris:artUrl') return '';
    String finalUrl = url;

    try {
      if (finalUrl.startsWith('file://')) {
        finalUrl = Uri.parse(finalUrl).toFilePath();
      } else if (finalUrl.startsWith('file:')) {
        finalUrl = finalUrl.replaceFirst('file:', '');
        finalUrl = Uri.decodeFull(finalUrl);
      }
    } catch (e) {
      debugPrint('[DEBUG NORMALIZE ERROR] Failed to parse URI: $e');
    }

    if (!finalUrl.startsWith('http') && !finalUrl.startsWith('/')) {
      if (finalUrl.startsWith('www.')) {
        finalUrl = 'https://$finalUrl';
      } else {
        return '';
      }
    }

    if (finalUrl.contains('lh3.googleusercontent.com') || finalUrl.contains('ggpht.com')) {
      finalUrl = finalUrl.replaceAll(RegExp(r'=w\d+-h\d+.*'), '=w600-h600-c');
    }

    return finalUrl;
  }

  void _scheduleResize() {
    _resizeDebounce?.cancel();
    _resizeDebounce = Timer(const Duration(milliseconds: 90), () {
      if (!mounted) return;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        unawaited(_performResize());
      });
    });
  }

  Future<void> _performResize() async {
    try {
      final RenderBox? box =
          _cardKey.currentContext?.findRenderObject() as RenderBox?;
      if (box == null) return;
      final double cardHeight = box.size.height.ceilToDouble();
      if ((cardHeight - _lastMeasuredHeight).abs() <= 1.0) return;
      _lastMeasuredHeight = cardHeight;
      final Size currentSize = await windowManager.getSize();
      if ((currentSize.height - cardHeight).abs() <= 1.0 &&
          (currentSize.width - _maxCardWidth).abs() <= 1.0) {
        return;
      }
      await windowManager.setSize(Size(_maxCardWidth, cardHeight));
    } catch (_) {}
  }

  Future<void> _updateTheme(String art) async {
    try {
      ImageProvider provider;
      if (art.startsWith('http')) {
        provider = NetworkImage(art, headers: const {'User-Agent': 'Mozilla/5.0'});
      } else {
        final file = File(art);
        if (!file.existsSync()) {
          return;
        }
        provider = FileImage(file);
      }

      final resizedProvider = ResizeImage(provider, width: 200, height: 200);
      final palette = await PaletteGeneratorMaster.fromImageProvider(
        resizedProvider,
        maximumColorCount: 32,
      );

      Color bgBase;
      if (palette.darkMutedColor != null) {
        bgBase = _darkenToBackground(palette.darkMutedColor!.color);
      } else if (palette.darkVibrantColor != null) {
        bgBase = _darkenToBackground(palette.darkVibrantColor!.color);
      } else {
        bgBase = _darkenToBackground(
            palette.dominantColor?.color ?? const Color(0xFF121212));
      }

      Color accentColor;
      if (palette.vibrantColor != null) {
        accentColor = palette.vibrantColor!.color;
      } else if (palette.lightVibrantColor != null) {
        accentColor = palette.lightVibrantColor!.color;
      } else {
        accentColor = palette.dominantColor?.color ?? const Color(0xFFB061FF);
      }

      final popAccent = _boostColor(accentColor);
      final softAccent = _softenColor(accentColor);

      if (!mounted) return;
      setState(() {
        _primaryPop = popAccent;
        _primarySoft = softAccent;
      });

      final scheme = ColorScheme.fromSeed(
        seedColor: popAccent,
        brightness: Brightness.dark,
        surface: bgBase,
        primary: popAccent,
        secondary: softAccent,
        dynamicSchemeVariant: DynamicSchemeVariant.fidelity,
      );
      widget.onSchemeChanged(scheme);
    } catch (e) {
      debugPrint('[DEBUG THEME ERROR] Generator failed: $e');
    }
  }

  Color _darkenToBackground(Color c) {
    final hsl = HSLColor.fromColor(c);
    return hsl.withLightness(hsl.lightness.clamp(0.05, 0.11)).toColor();
  }

  Color _boostColor(Color c) {
    final hsl = HSLColor.fromColor(c);
    return hsl
        .withSaturation((hsl.saturation + 0.35).clamp(0.0, 1.0))
        .withLightness((hsl.lightness + 0.15).clamp(0.48, 0.88))
        .toColor();
  }

  Color _softenColor(Color c) {
    final hsl = HSLColor.fromColor(c);
    return hsl
        .withSaturation((hsl.saturation * 0.7).clamp(0.0, 1.0))
        .withLightness(hsl.lightness.clamp(0.25, 0.60))
        .toColor();
  }

  Future<void> _playPause() async {
    setState(() => _isPlaying = !_isPlaying);
    await _runPlayerctl(['play-pause']);
  }

  Future<void> _next() async {
    setState(() {
      _positionSec = 0;
      _syncedPosition = 0;
      _lastSyncTime = DateTime.now();
    });
    await _runPlayerctl(['next']);
  }

  Future<void> _previous() async {
    setState(() {
      _positionSec = 0;
      _syncedPosition = 0;
      _lastSyncTime = DateTime.now();
    });
    await _runPlayerctl(['previous']);
  }

  Future<void> _seek(double percent) async {
    final targetSec = _durationSec * percent;
    setState(() {
      _positionSec = targetSec;
      _syncedPosition = targetSec;
      _lastSyncTime = DateTime.now();
      _lastUiTick = DateTime.fromMillisecondsSinceEpoch(0);
    });
    await _runPlayerctl(['position', targetSec.toString()]);
  }

  String _fmt(double sec) {
    final d = Duration(seconds: sec.isFinite ? sec.floor() : 0);
    final m = d.inMinutes;
    final s = d.inSeconds % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  double get _progress => (_positionSec / _durationSec).clamp(0.0, 1.0);

  double _adaptiveTitleSize(String title) {
    final len = title.length;
    if (len <= 15) return 15.0; 
    if (len <= 25) return 13.0;
    if (len <= 35) return 11.0;
    return 10.0;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final activeSec = _isDraggingBar ? (_dragPercent * _durationSec) : _positionSec;
    final currentFont = _fontCombos[_fontIndex];

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.escape): () => exit(0),
      },
      child: Focus(
        autofocus: true,
        child: Scaffold(
          backgroundColor: cs.surface,
          body: Stack(
            children: [
              Positioned.fill(
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 800),
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      center: Alignment.topCenter,
                      radius: 1.5,
                      colors: [
                        _primaryPop.withOpacity(0.12),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
              Center(
                child: SingleChildScrollView(
                  physics: const NeverScrollableScrollPhysics(),
                  child: Container(
                    key: _cardKey,
                    width: _maxCardWidth,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        GestureDetector(
                          onTapDown: (_) => setState(() => _isAlbumPressed = true),
                          onTapUp: (_) {
                            setState(() => _isAlbumPressed = false);
                            _cycleFont();
                          },
                          onTapCancel: () => setState(() => _isAlbumPressed = false),
                          child: AnimatedScale(
                            scale: _isAlbumPressed ? 0.92 : 1.0,
                            duration: const Duration(milliseconds: 150),
                            curve: Curves.easeOutBack,
                            child: SizedBox(
                              width: _albumSize,
                              height: _albumSize,
                              child: Stack(
                                alignment: Alignment.center,
                                children: [
                                  Container(
                                    width: _albumSize,
                                    height: _albumSize,
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(8),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withOpacity(0.4),
                                          blurRadius: 20,
                                          spreadRadius: 2,
                                          offset: const Offset(0, 8),
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (_albumArt.isEmpty)
                                    Container(
                                      width: _albumSize,
                                      height: _albumSize,
                                      decoration: BoxDecoration(
                                        color: cs.surfaceContainerHighest,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Icon(Icons.music_note_rounded,
                                          size: 48,
                                          color: cs.onSurfaceVariant.withOpacity(0.5)),
                                    ),
                                  if (_albumArt.isNotEmpty)
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: Image(
                                        image: _albumArt.startsWith('http')
                                            ? NetworkImage(_albumArt)
                                            : FileImage(File(_albumArt)) as ImageProvider,
                                        width: _albumSize,
                                        height: _albumSize,
                                        fit: BoxFit.cover,
                                        errorBuilder: (context, error, stackTrace) {
                                          debugPrint('[DEBUG IMAGE ERROR] Failed to display widget image: $error');
                                          return Container(
                                            color: cs.surfaceContainerHighest,
                                            child: Icon(Icons.broken_image_rounded, size: 48, color: cs.error),
                                          );
                                        },
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: Column(
                            children: [
                              AnimatedDefaultTextStyle(
                                duration: const Duration(milliseconds: 350),
                                curve: Curves.easeOutCubic,
                                style: TextStyle(
                                  fontFamily: currentFont.titleFont,
                                  fontWeight: currentFont.titleWeight,
                                  fontStyle: currentFont.titleStyle,
                                  letterSpacing: -0.2,
                                  height: 1.1,
                                  fontSize: _adaptiveTitleSize(_title),
                                  color: cs.onSurface,
                                ),
                                child: Text(
                                  _title,
                                  textAlign: TextAlign.center,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(height: 4),
                              AnimatedDefaultTextStyle(
                                duration: const Duration(milliseconds: 350),
                                style: TextStyle(
                                  fontFamily: currentFont.artistFont,
                                  fontWeight: currentFont.artistWeight,
                                  fontStyle: currentFont.artistStyle,
                                  letterSpacing: 1.0,
                                  height: 1.2,
                                  color: cs.onSurface.withOpacity(0.60),
                                  fontSize: 9,
                                ),
                                child: Text(
                                  _artist.toUpperCase(),
                                  textAlign: TextAlign.center,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 0),
                        RepaintBoundary(
                          child: MouseRegion(
                            onEnter: (_) {
                              setState(() => _isBarHovered = true);
                              _scheduleResize();
                            },
                            onExit: (_) {
                              setState(() => _isBarHovered = false);
                              _scheduleResize();
                            },
                            child: LayoutBuilder(
                              builder: (context, constraints) {
                                return GestureDetector(
                                  onPanStart: (details) {
                                    setState(() {
                                      _isDraggingBar = true;
                                      _dragPercent = (details.localPosition.dx / constraints.maxWidth).clamp(0.0, 1.0);
                                    });
                                  },
                                  onPanUpdate: (details) {
                                    setState(() {
                                      _dragPercent = (details.localPosition.dx / constraints.maxWidth).clamp(0.0, 1.0);
                                    });
                                  },
                                  onPanEnd: (details) {
                                    _seek(_dragPercent);
                                    setState(() => _isDraggingBar = false);
                                  },
                                  onTapDown: (details) {
                                    final p = (details.localPosition.dx / constraints.maxWidth).clamp(0.0, 1.0);
                                    _seek(p);
                                  },
                                  child: Container(
                                    color: Colors.transparent,
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                    child: AnimatedBuilder(
                                      animation: _breathingController,
                                      builder: (context, child) {
                                        final activeProgress = _isDraggingBar ? _dragPercent : _progress;
                                        return AnimatedContainer(
                                          duration: const Duration(milliseconds: 200),
                                          height: _isBarHovered || _isDraggingBar ? 8 : 4,
                                          child: CustomPaint(
                                            painter: _GapProgressPainter(
                                              progress: activeProgress,
                                              activeColor: _primaryPop.withOpacity(
                                                0.85 + _breathingController.value * 0.15,
                                              ),
                                              inactiveColor: cs.onSurface.withOpacity(0.15),
                                            ),
                                            size: Size(constraints.maxWidth, _isBarHovered || _isDraggingBar ? 8 : 4),
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.only(top: 0, bottom: 8),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(_fmt(activeSec),
                                  style: TextStyle(
                                      fontFamily: 'Roboto Mono',
                                      fontSize: 9,
                                      fontWeight: FontWeight.w600,
                                      color: cs.onSurfaceVariant)),
                              Text(_fmt(_durationSec),
                                  style: TextStyle(
                                      fontFamily: 'Roboto Mono',
                                      fontSize: 9,
                                      fontWeight: FontWeight.w600,
                                      color: cs.onSurfaceVariant)),
                            ],
                          ),
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            MediaControl(
                              icon: Icons.skip_previous_rounded,
                              size: 32,
                              iconSize: 18,
                              onTap: _previous,
                              backgroundColor: cs.onSurface.withOpacity(0.08),
                              iconColor: cs.onSurface,
                            ),
                            const SizedBox(width: 14),
                            MediaControl(
                              icon: _isPlaying
                                  ? Icons.pause_rounded
                                  : Icons.play_arrow_rounded,
                              size: 48,
                              iconSize: 28,
                              backgroundColor: _primarySoft,
                              iconColor: cs.surface,
                              onTap: _playPause,
                              isPlayButton: true,
                            ),
                            const SizedBox(width: 14),
                            MediaControl(
                              icon: Icons.skip_next_rounded,
                              size: 32,
                              iconSize: 18,
                              onTap: _next,
                              backgroundColor: cs.onSurface.withOpacity(0.08),
                              iconColor: cs.onSurface,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PlayerData {
  final String name;
  final String status;
  final String lengthStr;
  final String artUrl;
  final String lastGoodArtUrl;
  final String title;
  final String artist;
  final DateTime lastUpdated;

  _PlayerData({
    required this.name,
    required this.status,
    required this.lengthStr,
    required this.artUrl,
    required this.lastGoodArtUrl,
    required this.title,
    required this.artist,
    required this.lastUpdated,
  });
}

class _GapProgressPainter extends CustomPainter {
  final double progress;
  final Color activeColor;
  final Color inactiveColor;

  _GapProgressPainter({
    required this.progress,
    required this.activeColor,
    required this.inactiveColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final cy = h / 2;
    const gap = 10.0;

    final paint = Paint()
      ..strokeCap = StrokeCap.round
      ..strokeWidth = h;

    final splitX = w * progress;

    if (splitX > 0) {
      paint.color = activeColor;
      final endActive = (splitX - gap / 2).clamp(0.0, w);
      canvas.drawLine(Offset(0, cy), Offset(endActive, cy), paint);
    }

    if (splitX < w) {
      paint.color = inactiveColor;
      final startInactive = (splitX + gap / 2).clamp(0.0, w);
      canvas.drawLine(Offset(startInactive, cy), Offset(w, cy), paint);

      final dotPaint = Paint()
        ..color = activeColor
        ..style = PaintingStyle.fill;
      canvas.drawCircle(Offset(w, cy), h * 0.35, dotPaint);
    }
  }

  @override
  bool shouldRepaint(_GapProgressPainter old) =>
      old.progress != progress ||
      old.activeColor != activeColor ||
      old.inactiveColor != inactiveColor;
}

class MediaControl extends StatefulWidget {
  final IconData icon;
  final double size;
  final double iconSize;
  final VoidCallback onTap;
  final Color backgroundColor;
  final Color iconColor;
  final bool isPlayButton;

  const MediaControl({
    super.key,
    required this.icon,
    required this.size,
    required this.iconSize,
    required this.onTap,
    required this.backgroundColor,
    required this.iconColor,
    this.isPlayButton = false,
  });

  @override
  State<MediaControl> createState() => _MediaControlState();
}

class _MediaControlState extends State<MediaControl> {
  bool _isHovered = false;
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final targetScale = _isPressed ? 0.85 : (_isHovered ? 1.08 : 1.0);
    final targetRadius = widget.isPlayButton ? widget.size * 0.35 : widget.size * 0.28;
    
    final dynamicBgColor = _isPressed
        ? Color.lerp(widget.backgroundColor, Colors.black, 0.1)!
        : _isHovered
            ? Color.lerp(widget.backgroundColor, Colors.white, 0.18)!
            : widget.backgroundColor;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() {
        _isHovered = false;
        _isPressed = false;
      }),
      child: GestureDetector(
        onTapDown: (_) => setState(() => _isPressed = true),
        onTapUp: (_) {
          setState(() => _isPressed = false);
          widget.onTap();
        },
        onTapCancel: () => setState(() => _isPressed = false),
        child: AnimatedScale(
          scale: targetScale,
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeOutCubic,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOutCubic,
            width: widget.size,
            height: widget.size,
            decoration: BoxDecoration(
              color: dynamicBgColor,
              borderRadius: BorderRadius.circular(targetRadius),
            ),
            child: Center(
              child: Icon(
                widget.icon,
                color: widget.iconColor,
                size: widget.iconSize,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

void unawaited(Future<void> f) {}
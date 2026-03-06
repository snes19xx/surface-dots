import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart'; 
import 'package:palette_generator/palette_generator.dart';
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

// -----------------------------------------------------------------------------
// APP ROOT
// -----------------------------------------------------------------------------
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
        fontFamily: 'Manrope',
        textTheme: const TextTheme(
          titleLarge: TextStyle(
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5,
            height: 1.1,
          ),
          bodyMedium: TextStyle(
            fontWeight: FontWeight.w500,
            letterSpacing: -0.2,
            height: 1.1,
          ),
        ),
      ),
      home: NowPlayingWidget(onSchemeChanged: _applyScheme),
    );
  }
}

// -----------------------------------------------------------------------------
// MAIN WIDGET
// -----------------------------------------------------------------------------
class NowPlayingWidget extends StatefulWidget {
  const NowPlayingWidget({super.key, required this.onSchemeChanged});
  final ValueChanged<ColorScheme> onSchemeChanged;

  @override
  State<NowPlayingWidget> createState() => _NowPlayingWidgetState();
}

class _NowPlayingWidgetState extends State<NowPlayingWidget>
    with TickerProviderStateMixin {
  static const double _maxCardWidth = 252;
  static const double _albumSize = 196;
  final GlobalKey _cardKey = GlobalKey();

  // --- PLAYER STATE ---
  final Map<String, _PlayerData> _knownPlayers = {};
  String? _activePlayerName;

  String _title = 'Nothing playing';
  String _artist = '';
  String _albumArt = '';
  bool _isPlaying = false;
  double _durationSec = 180;
  double _positionSec = 0;

  // --- THEME STATE ---
  Color _primaryPop = const Color(0xFFB061FF);
  Color _primarySoft = const Color(0xFFB061FF).withOpacity(0.6);
  String _lastArtKey = '';

  // --- UI INTERACTION ---
  bool _isBarHovered = false;

  // --- TIMERS & PROCESSES ---
  Process? _playerCtlProcess;
  StreamSubscription? _playerCtlSub;

  late Ticker _positionTicker;
  late AnimationController _breathingController;

  DateTime? _lastSyncTime;
  double _syncedPosition = 0;
  Timer? _driftSyncTimer;
  Timer? _cleanupTimer;

  // Resize debounce
  Timer? _resizeDebounce;
  double _lastMeasuredHeight = 0;

  // Throttle position UI updates (approx 6 Hz)
  final Duration _uiTickInterval = const Duration(milliseconds: 150);
  DateTime _lastUiTick = DateTime.fromMillisecondsSinceEpoch(0);

  final List<String> _musicApps = [
    'spotify',
    'rhythmbox',
    'mpd',
    'cider',
    'music',
    'audacious',
    'vlc',
    'pear'
  ];
  final List<String> _browsers = [
    'firefox',
    'chromium',
    'chrome',
    'brave',
    'edge',
    'opera'
  ];

  @override
  void initState() {
    super.initState();

    _breathingController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );

    _positionTicker = createTicker((elapsed) {
      if (_lastSyncTime == null || !_isPlaying) return;

      final now = DateTime.now();
      
      // Throttle UI updates
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

    // Sync position every 7 seconds
    _driftSyncTimer =
        Timer.periodic(const Duration(seconds: 7), (_) => _syncPositionOnly());

    // Check for dead players every 3s
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
    _resizeDebounce?.cancel();

    _positionTicker.dispose();
    _breathingController.dispose();

    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // PLAYER STREAMING
  // ---------------------------------------------------------------------------

  Future<void> _initStream() async {
    await _seedPlayersOnce();
    await _startPlayerctlFollow();
  }

  Future<void> _seedPlayersOnce() async {
    try {
      final res = await Process.run('playerctl', [
        '-a',
        'metadata',
        '--format',
        '{{playerName}};;{{status}};;{{mpris:length}};;{{mpris:artUrl}};;{{title}};;{{artist}}',
      ]);
      final out = res.stdout.toString();
      final lines = const LineSplitter().convert(out);
      for (final line in lines) {
        if (line.trim().isEmpty) continue;
        _processUpdate(line);
      }
    } catch (_) {}
  }

  Future<void> _startPlayerctlFollow() async {
    try {
      _playerCtlProcess = await Process.start('playerctl', [
        '-a',
        'metadata',
        '--format',
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
        // 'firefox' matches 'firefox.instance234'
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
    final artUrl = parts[3].trim();
    final title = parts[4].trim();
    final artist = parts[5].trim();

    final prev = _knownPlayers[name];
    final prevArt = prev?.artUrl ?? '';
    final artChanged = (artUrl != prevArt);

    final mergedName = name;
    final mergedStatus = _isPlaceholder(status, 'status') ? (prev?.status ?? '') : status;
    final mergedLen = _isPlaceholder(lenStr, 'mpris:length') ? (prev?.lengthStr ?? '') : lenStr;
    final mergedArt = _isPlaceholder(artUrl, 'mpris:artUrl') ? (prev?.artUrl ?? '') : artUrl;
    
    // If art changed, use new title (even if empty) to clear annoying youtube ads -_-
    final mergedTitle = (artChanged || !_isPlaceholder(title, 'title')) 
        ? title 
        : (prev?.title ?? '');
        
    final mergedArtist = (artChanged || !_isPlaceholder(artist, 'artist')) 
        ? artist 
        : (prev?.artist ?? '');

    _knownPlayers[name] = _PlayerData(
      name: mergedName,
      status: mergedStatus,
      lengthStr: mergedLen,
      artUrl: mergedArt,
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

    _updateUiFromPlayer(winner, forceUpdate: sourceChanged);
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
    final finalTitle = _isPlaceholder(p.title, 'title') 
        ? (isPlayingNow ? 'Loading...' : 'Nothing playing') 
        : p.title;
        
    final finalArtist = _isPlaceholder(p.artist, 'artist') ? '' : p.artist;

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

    if (normalizedArt.isNotEmpty &&
        normalizedArt != _lastArtKey &&
        !normalizedArt.contains('mpris:artUrl')) {
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
    if (_activePlayerName == null) return;
    try {
      final res = await _runPlayerctl(['position']);
      final txt = res.stdout.toString().trim();
      if (txt.isEmpty) return;

      final pos = double.tryParse(txt);
      if (pos == null || !mounted) return;

      _syncedPosition = pos;
      _lastSyncTime = DateTime.now();

      if (!_isPlaying) {
        setState(() => _positionSec = pos);
      }
    } catch (_) {}
  }

  String _normalizeArtUrl(String url) {
    if (url.isEmpty) return '';
    if (url.startsWith('file://')) return url.substring(7);
    if (url == 'mpris:artUrl') return '';
    if (url.startsWith('www.')) return 'https://$url';
    return url;
  }

  // ---------------------------------------------------------------------------
  // WINDOW RESIZE (DEBOUNCED)
  // ---------------------------------------------------------------------------

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

  // ---------------------------------------------------------------------------
  // COLOR LOGIC
  // ---------------------------------------------------------------------------

  Future<void> _updateTheme(String art) async {
    try {
      ImageProvider provider;
      if (art.startsWith('http')) {
        provider = NetworkImage(art, headers: {'User-Agent': 'Mozilla/5.0'});
      } else {
        provider = FileImage(File(art));
      }

      final resizedProvider = ResizeImage(provider, width: 100, height: 100);

      final palette = await PaletteGenerator.fromImageProvider(
        resizedProvider,
        maximumColorCount: 16,
      );

      Color dominant =
          palette.dominantColor?.color ?? const Color(0xFF121212);
      Color bgBase = _darkenToBackground(dominant);

      final bgHSL = HSLColor.fromColor(bgBase);

      List<PaletteColor> candidates = palette.paletteColors.toList();
      Color? bestAccent;
      double bestScore = -1.0;

      for (final pc in candidates) {
        final hsl = HSLColor.fromColor(pc.color);

        if (hsl.lightness < 0.35) continue;
        if (hsl.saturation < 0.2) continue;

        double hueDiff = (hsl.hue - bgHSL.hue).abs();
        if (hueDiff > 180) hueDiff = 360 - hueDiff;
        double distScore = hueDiff / 180.0;

        double score = (hsl.saturation * 1.5) + (distScore * 1.0);

        if (score > bestScore) {
          bestScore = score;
          bestAccent = pc.color;
        }
      }

      bestAccent ??= palette.lightVibrantColor?.color ?? Colors.white;

      final popAccent = _boostColor(bestAccent);
      final softAccent = _softenColor(bestAccent);

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
    } catch (_) {}
  }

  Color _darkenToBackground(Color c) {
    final hsl = HSLColor.fromColor(c);
    if (hsl.lightness < 0.1) return c;
    return hsl.withLightness(0.12).toColor();
  }

  Color _boostColor(Color c) {
    final hsl = HSLColor.fromColor(c);
    if (hsl.saturation < 0.1) return c;
    return hsl
        .withSaturation((hsl.saturation + 0.3).clamp(0.0, 1.0))
        .withLightness((hsl.lightness + 0.1).clamp(0.4, 0.8))
        .toColor();
  }

  Color _softenColor(Color c) {
    final hsl = HSLColor.fromColor(c);
    if (hsl.saturation < 0.1) return c;
    return hsl
        .withSaturation((hsl.saturation * 0.8).clamp(0.0, 1.0))
        .withLightness((hsl.lightness).clamp(0.3, 0.7))
        .toColor();
  }

  // ---------------------------------------------------------------------------
  // CONTROLS
  // ---------------------------------------------------------------------------

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

  // ---------------------------------------------------------------------------
  // BUILD
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

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
                child: Container(
                  color: const Color(0xFFA7C080).withOpacity(0.05),
                ),
              ),
              Center(
                child: SingleChildScrollView(
                  physics: const NeverScrollableScrollPhysics(),
                  child: Container(
                    key: _cardKey,
                    width: _maxCardWidth,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 17, vertical: 17),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // ARTWORK
                        Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.4),
                                blurRadius: 11,
                                offset: const Offset(0, 5),
                              ),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: SizedBox(
                              width: _albumSize,
                              height: _albumSize,
                              child: _albumArt.isEmpty
                                  ? Container(
                                      color: cs.surfaceContainerHighest,
                                      child: Icon(Icons.music_note,
                                          size: 45, color: cs.onSurfaceVariant),
                                    )
                                  : Image(
                                      image: _albumArt.startsWith('http')
                                          ? NetworkImage(_albumArt)
                                          : FileImage(File(_albumArt))
                                              as ImageProvider,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) => Container(
                                        color: cs.surfaceContainerHighest,
                                        child: const Icon(Icons.broken_image,
                                            size: 28),
                                      ),
                                    ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),

                        // TITLE & ARTIST
                        Text(
                          _title,
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                fontSize: 14,
                                color: cs.onSurface,
                              ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          _artist,
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: cs.onSurface.withOpacity(0.7),
                                fontSize: 10.5,
                              ),
                        ),
                        const SizedBox(height: 17),

                        // PROGRESS BAR
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
                            child: LayoutBuilder(builder: (context, constraints) {
                              return InkWell(
                                onTapUp: (details) {
                                  final p = (details.localPosition.dx /
                                          constraints.maxWidth)
                                      .clamp(0.0, 1.0);
                                  _seek(p);
                                },
                                borderRadius: BorderRadius.circular(8),
                                child: Padding(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 5),
                                  child: AnimatedBuilder(
                                    animation: _breathingController,
                                    builder: (context, child) {
                                      return AnimatedContainer(
                                        duration:
                                            const Duration(milliseconds: 200),
                                        height: _isBarHovered ? 8 : 4,
                                        child: CustomPaint(
                                          painter: _GapProgressPainter(
                                            progress: _progress,
                                            activeColor: _primaryPop.withOpacity(
                                              0.9 +
                                                  (_breathingController.value *
                                                      0.1),
                                            ),
                                            inactiveColor: cs.onSurface
                                                .withOpacity(0.15),
                                          ),
                                          size: Size(constraints.maxWidth,
                                              _isBarHovered ? 8 : 4),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              );
                            }),
                          ),
                        ),

                        Padding(
                          padding:
                              const EdgeInsets.only(top: 3, bottom: 8),
                          child: Row(
                            mainAxisAlignment:
                                MainAxisAlignment.spaceBetween,
                            children: [
                              Text(_fmt(_positionSec),
                                  style: TextStyle(
                                      fontSize: 8.5,
                                      color: cs.onSurfaceVariant)),
                              Text(_fmt(_durationSec),
                                  style: TextStyle(
                                      fontSize: 8.5,
                                      color: cs.onSurfaceVariant)),
                            ],
                          ),
                        ),

                        // CONTROLS
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            MediaControl(
                              icon: Icons.skip_previous_rounded,
                              size: 34,
                              iconSize: 15,
                              onTap: _previous,
                              backgroundColor:
                                  cs.onSurface.withOpacity(0.1),
                              iconColor: cs.onSurface,
                            ),
                            const SizedBox(width: 11),
                            MediaControl(
                              icon: _isPlaying
                                  ? Icons.pause_rounded
                                  : Icons.play_arrow_rounded,
                              size: 45,
                              iconSize: 22,
                              backgroundColor: _primarySoft,
                              iconColor: cs.surface,
                              onTap: _playPause,
                              isPlayButton: true,
                            ),
                            const SizedBox(width: 11),
                            MediaControl(
                              icon: Icons.skip_next_rounded,
                              size: 34,
                              iconSize: 15,
                              onTap: _next,
                              backgroundColor:
                                  cs.onSurface.withOpacity(0.1),
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

// -----------------------------------------------------------------------------
// HELPERS
// -----------------------------------------------------------------------------

class _PlayerData {
  final String name;
  final String status;
  final String lengthStr;
  final String artUrl;
  final String title;
  final String artist;
  final DateTime lastUpdated;

  _PlayerData({
    required this.name,
    required this.status,
    required this.lengthStr,
    required this.artUrl,
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
    const gap = 8.0;

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
      canvas.drawCircle(Offset(w, cy), h * 0.3, dotPaint);
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

class _MediaControlState extends State<MediaControl>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  bool _isHovered = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
      lowerBound: 0.90,
      upperBound: 1.00,
      value: 1.0,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTapDown: (_) => _controller.animateTo(0.9),
        onTapUp: (_) {
          _controller.animateTo(1.0);
          widget.onTap();
        },
        onTapCancel: () => _controller.animateTo(1.0),
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            return Transform.scale(
              scale: _controller.value,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: widget.size,
                height: widget.size,
                decoration: BoxDecoration(
                  color: _isHovered
                      ? Color.lerp(widget.backgroundColor, Colors.white, 0.15)
                      : widget.backgroundColor,
                  borderRadius: BorderRadius.circular(widget.size * 0.35),
                ),
                child: Center(
                  child: Icon(
                    widget.icon,
                    color: widget.iconColor,
                    size: widget.iconSize,
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

void unawaited(Future<void> f) {}
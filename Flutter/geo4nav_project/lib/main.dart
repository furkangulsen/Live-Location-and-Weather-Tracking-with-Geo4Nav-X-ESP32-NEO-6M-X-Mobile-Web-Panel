import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:ui';
import 'pages/veri_listele_page.dart';
import 'pages/gps_verileri_page.dart';
import 'pages/reverse_geocoding_page.dart';
import 'pages/maps_page.dart';
import 'pages/weather_page.dart';
import 'pages/about_page.dart';

void main() {
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ),
  );
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Geo4Nav Web Panel',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF2563EB),
          brightness: Brightness.light,
        ),
        useMaterial3: true,
      ),
      home: const SplashScreen(),
    );
  }
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _masterController;
  late AnimationController _logoController;
  late AnimationController _particleController;
  late AnimationController _waveController;
  late AnimationController _breathController;
  late AnimationController _textController;
  late AnimationController _progressController;

  late Animation<double> _logoScale;
  late Animation<double> _logoRotation;
  late Animation<double> _logoOpacity;
  late Animation<double> _particleAnimation;
  late Animation<double> _waveAnimation;
  late Animation<double> _breathAnimation;
  late Animation<double> _textSlide;
  late Animation<double> _textOpacity;
  late Animation<double> _progressAnimation;
  late Animation<Color?> _backgroundGradient1;
  late Animation<Color?> _backgroundGradient2;
  late Animation<Color?> _backgroundGradient3;

  @override
  void initState() {
    super.initState();

    // Ana controller - tüm animasyonları yönetir
    _masterController = AnimationController(
      duration: const Duration(milliseconds: 4000),
      vsync: this,
    );

    // Logo animasyonları
    _logoController = AnimationController(
      duration: const Duration(milliseconds: 2500),
      vsync: this,
    );

    // Parçacık efektleri
    _particleController = AnimationController(
      duration: const Duration(milliseconds: 6000),
      vsync: this,
    );

    // Dalga efektleri
    _waveController = AnimationController(
      duration: const Duration(milliseconds: 3000),
      vsync: this,
    );

    // Nefes alma efekti
    _breathController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );

    // Metin animasyonları
    _textController = AnimationController(
      duration: const Duration(milliseconds: 1800),
      vsync: this,
    );

    // Progress bar animasyonu
    _progressController = AnimationController(
      duration: const Duration(milliseconds: 3500),
      vsync: this,
    );

    _initializeAnimations();
    _startAnimationSequence();
  }

  void _initializeAnimations() {
    // Logo animasyonları - çok daha sofistike
    _logoScale = Tween<double>(begin: 0.3, end: 1.0).animate(
      CurvedAnimation(
        parent: _logoController,
        curve: const Interval(0.0, 0.6, curve: Curves.elasticOut),
      ),
    );

    _logoRotation = Tween<double>(begin: -0.5, end: 0.0).animate(
      CurvedAnimation(
        parent: _logoController,
        curve: const Interval(0.2, 0.8, curve: Curves.easeOutBack),
      ),
    );

    _logoOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _logoController,
        curve: const Interval(0.0, 0.4, curve: Curves.easeInOut),
      ),
    );

    // Parçacık animasyonu
    _particleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _particleController,
        curve: Curves.easeInOut,
      ),
    );

    // Dalga animasyonu
    _waveAnimation = Tween<double>(begin: 0.0, end: 2.0).animate(
      CurvedAnimation(
        parent: _waveController,
        curve: Curves.easeInOut,
      ),
    );

    // Nefes alma animasyonu
    _breathAnimation = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(
        parent: _breathController,
        curve: Curves.easeInOut,
      ),
    );

    // Metin animasyonları
    _textSlide = Tween<double>(begin: 50.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _textController,
        curve: const Interval(0.0, 0.7, curve: Curves.easeOutCubic),
      ),
    );

    _textOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _textController,
        curve: const Interval(0.3, 1.0, curve: Curves.easeIn),
      ),
    );

    // Progress animasyonu
    _progressAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _progressController,
        curve: Curves.easeInOut,
      ),
    );

    // Dinamik arka plan gradient'leri
    _backgroundGradient1 = ColorTween(
      begin: const Color(0xFF1E3A8A),
      end: const Color(0xFF3B82F6),
    ).animate(CurvedAnimation(
      parent: _masterController,
      curve: Curves.easeInOut,
    ));

    _backgroundGradient2 = ColorTween(
      begin: const Color(0xFF3B82F6),
      end: const Color(0xFF06B6D4),
    ).animate(CurvedAnimation(
      parent: _masterController,
      curve: Curves.easeInOut,
    ));

    _backgroundGradient3 = ColorTween(
      begin: const Color(0xFF8B5CF6),
      end: const Color(0xFFEC4899),
    ).animate(CurvedAnimation(
      parent: _masterController,
      curve: Curves.easeInOut,
    ));
  }

  void _startAnimationSequence() {
    // Animasyon sıralaması - çok daha sofistike timing
    Future.delayed(const Duration(milliseconds: 200), () {
      _masterController.forward();
      _particleController.repeat();
    });

    Future.delayed(const Duration(milliseconds: 400), () {
      _logoController.forward();
    });

    Future.delayed(const Duration(milliseconds: 800), () {
      _waveController.repeat(reverse: true);
    });

    Future.delayed(const Duration(milliseconds: 1200), () {
      _breathController.repeat(reverse: true);
    });

    Future.delayed(const Duration(milliseconds: 1600), () {
      _textController.forward();
    });

    Future.delayed(const Duration(milliseconds: 2000), () {
      _progressController.forward();
    });

    // Ana sayfaya geçiş - daha smooth
    Future.delayed(const Duration(milliseconds: 5000), () {
      Navigator.pushReplacement(
        context,
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) =>
              const HomePage(),
          transitionDuration: const Duration(milliseconds: 1500),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0.0, 0.2),
                end: Offset.zero,
              ).animate(CurvedAnimation(
                parent: animation,
                curve: Curves.easeOutQuart,
              )),
              child: FadeTransition(
                opacity: animation,
                child: ScaleTransition(
                  scale: Tween<double>(begin: 0.95, end: 1.0).animate(
                    CurvedAnimation(
                      parent: animation,
                      curve: Curves.easeOutCubic,
                    ),
                  ),
                  child: child,
                ),
              ),
            );
          },
        ),
      );
    });
  }

  @override
  void dispose() {
    _masterController.dispose();
    _logoController.dispose();
    _particleController.dispose();
    _waveController.dispose();
    _breathController.dispose();
    _textController.dispose();
    _progressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AnimatedBuilder(
        animation: Listenable.merge([
          _masterController,
          _logoController,
          _particleController,
          _waveController,
          _breathController,
          _textController,
          _progressController,
        ]),
        builder: (context, child) {
          return Container(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: Alignment.center,
                radius: 1.2,
                colors: [
                  _backgroundGradient1.value ?? const Color(0xFF1E3A8A),
                  _backgroundGradient2.value ?? const Color(0xFF3B82F6),
                  _backgroundGradient3.value ?? const Color(0xFF8B5CF6),
                ],
                stops: const [0.0, 0.6, 1.0],
              ),
            ),
            child: Stack(
              children: [
                // Arka plan parçacık efektleri
                ..._buildParticleEffects(),

                // Dalga efektleri
                _buildWaveEffect(),

                // Ana içerik
                Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Logo container - gelişmiş tasarım
                      Transform.scale(
                        scale: _logoScale.value * _breathAnimation.value,
                        child: Transform.rotate(
                          angle: _logoRotation.value,
                          child: Container(
                            width: 140,
                            height: 140,
                            decoration: BoxDecoration(
                              gradient: RadialGradient(
                                colors: [
                                  Colors.white.withOpacity(0.9),
                                  Colors.white.withOpacity(0.6),
                                  Colors.white.withOpacity(0.3),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(35),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.white.withOpacity(0.3),
                                  blurRadius: 30,
                                  spreadRadius: 5,
                                ),
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.1),
                                  blurRadius: 20,
                                  offset: const Offset(0, 10),
                                ),
                              ],
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(35),
                              child: BackdropFilter(
                                filter:
                                    ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(35),
                                    border: Border.all(
                                      color: Colors.white.withOpacity(0.4),
                                      width: 2,
                                    ),
                                  ),
                                  child: Center(
                                    child: ShaderMask(
                                      shaderCallback: (bounds) =>
                                          const LinearGradient(
                                        colors: [
                                          Color(0xFF60A5FA),
                                          Color(0xFF3B82F6),
                                          Color(0xFF1D4ED8),
                                        ],
                                      ).createShader(bounds),
                                      child: Icon(
                                        Icons.location_on_rounded,
                                        size: 65,
                                        color: Colors.white
                                            .withOpacity(_logoOpacity.value),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 40),

                      // Ana başlık - çok daha etkileyici
                      Transform.translate(
                        offset: Offset(0, _textSlide.value),
                        child: Opacity(
                          opacity: _textOpacity.value,
                          child: ShaderMask(
                            shaderCallback: (bounds) => const LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                Colors.white,
                                Color(0xFFE0F2FE),
                                Colors.white,
                                Color(0xFFBAE6FD),
                              ],
                            ).createShader(bounds),
                            child: const Text(
                              'Geo4Nav',
                              style: TextStyle(
                                fontSize: 48,
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                                letterSpacing: 4,
                                height: 1.0,
                              ),
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 15),

                      // Alt başlık
                      Transform.translate(
                        offset: Offset(0, _textSlide.value * 0.7),
                        child: Opacity(
                          opacity: _textOpacity.value * 0.9,
                          child: Text(
                            'Control GPS. Visualize. Act.',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                              color: Colors.white.withOpacity(0.9),
                              letterSpacing: 3,
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 60),

                      // Gelişmiş progress indicator
                      Container(
                        width: 280,
                        height: 6,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: LinearProgressIndicator(
                            value: _progressAnimation.value,
                            backgroundColor: Colors.transparent,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.white.withOpacity(0.8),
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 20),

                      // Loading text
                      Opacity(
                        opacity: _textOpacity.value * 0.8,
                        child: Text(
                          'Initializing...',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w400,
                            color: Colors.white.withOpacity(0.7),
                            letterSpacing: 1,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  List<Widget> _buildParticleEffects() {
    List<Widget> particles = [];
    for (int i = 0; i < 15; i++) {
      particles.add(
        Positioned(
          left: (i * 30.0) % MediaQuery.of(context).size.width,
          top: (i * 50.0) % MediaQuery.of(context).size.height,
          child: Transform.translate(
            offset: Offset(
              50 * _particleAnimation.value * (i % 2 == 0 ? 1 : -1),
              30 * _particleAnimation.value,
            ),
            child: Container(
              width: 4 + (i % 3) * 2,
              height: 4 + (i % 3) * 2,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.6 * _particleAnimation.value),
                borderRadius: BorderRadius.circular(10),
                boxShadow: [
                  BoxShadow(
                    color: Colors.white.withOpacity(0.3),
                    blurRadius: 10,
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }
    return particles;
  }

  Widget _buildWaveEffect() {
    return Positioned.fill(
      child: CustomPaint(
        painter: WavePainter(_waveAnimation.value),
      ),
    );
  }
}

class WavePainter extends CustomPainter {
  final double animationValue;

  WavePainter(this.animationValue);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.1)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    final center = Offset(size.width / 2, size.height / 2);

    for (int i = 0; i < 3; i++) {
      final radius = (50 + i * 30) * (1 + animationValue);
      canvas.drawCircle(
        center,
        radius,
        paint..color = Colors.white.withOpacity(0.1 - i * 0.03),
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final String channelId = "2983534";
  final String readApiKey = "2894ERH4G3W220YU";

  List<Map<String, dynamic>> feedData = [];
  bool isLoading = true;
  String? error;

  @override
  void initState() {
    super.initState();
    fetchData();
  }

  Future<void> fetchData() async {
    setState(() {
      isLoading = true;
      error = null;
    });

    try {
      final response = await http.get(
        Uri.parse(
          'https://api.thingspeak.com/channels/$channelId/feeds.json?api_key=$readApiKey&results=25',
        ),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          feedData = List<Map<String, dynamic>>.from(data['feeds'].reversed);
          isLoading = false;
        });
      } else {
        setState(() {
          error = 'Veri çekme hatası: ${response.statusCode}';
          isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        error = 'Bir hata oluştu: $e';
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFFE8F4FD),
              Color(0xFFF0F8FF),
              Colors.white,
              Color(0xFFE3F2FD),
            ],
          ),
        ),
        child: SafeArea(
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 40, 24, 0),
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.blue.withOpacity(0.1),
                              blurRadius: 20,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.location_on_rounded,
                              size: 32,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                            const SizedBox(width: 12),
                            Text(
                              'Geo4Nav',
                              style: Theme.of(context)
                                  .textTheme
                                  .headlineMedium
                                  ?.copyWith(
                                    color:
                                        Theme.of(context).colorScheme.primary,
                                    fontWeight: FontWeight.bold,
                                  ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                sliver: SliverGrid(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 16,
                    crossAxisSpacing: 16,
                    childAspectRatio: 1.15,
                  ),
                  delegate: SliverChildListDelegate([
                    _buildMenuCard(
                      context,
                      'Verileri\nListele',
                      Icons.list_alt_rounded,
                      Colors.blue,
                      () {
                        HapticFeedback.mediumImpact();
                        Navigator.push(
                          context,
                          _createSmoothPageRoute(
                              const VeriListele(), 'Verileri\nListele'),
                        );
                      },
                    ),
                    _buildMenuCard(
                      context,
                      'GPS\nVerileri',
                      Icons.gps_fixed_rounded,
                      Colors.green,
                      () {
                        HapticFeedback.mediumImpact();
                        Navigator.push(
                          context,
                          _createSmoothPageRoute(
                              const GpsVerileriPage(), 'GPS\nVerileri'),
                        );
                      },
                    ),
                    _buildMenuCard(
                      context,
                      'Reverse\nGeocoding',
                      Icons.location_searching_rounded,
                      Colors.orange,
                      () {
                        HapticFeedback.mediumImpact();
                        Navigator.push(
                          context,
                          _createSmoothPageRoute(const ReverseGeocodingPage(),
                              'Reverse\nGeocoding'),
                        );
                      },
                    ),
                    _buildMenuCard(
                      context,
                      'Konum\nHarita',
                      Icons.map_rounded,
                      Colors.purple,
                      () {
                        HapticFeedback.mediumImpact();
                        Navigator.push(
                          context,
                          _createSmoothPageRoute(
                              const MapsPage(), 'Konum\nHarita'),
                        );
                      },
                    ),
                    _buildMenuCard(
                      context,
                      'Hava\nDurumu',
                      Icons.cloud_rounded,
                      Colors.teal,
                      () {
                        HapticFeedback.mediumImpact();
                        Navigator.push(
                          context,
                          _createSmoothPageRoute(
                              const WeatherPage(), 'Hava\nDurumu'),
                        );
                      },
                    ),
                    _buildMenuCard(
                      context,
                      'Hakkında',
                      Icons.info_outline_rounded,
                      Colors.indigo,
                      () {
                        HapticFeedback.mediumImpact();
                        Navigator.push(
                          context,
                          _createSmoothPageRoute(const AboutPage(), 'Hakkında'),
                        );
                      },
                    ),
                  ]),
                ),
              ),
              const SliverToBoxAdapter(
                child: SizedBox(height: 100), // Alt boşluk için
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: Container(
        height: 60,
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: Center(
          child: Text(
            '© 2025 Geo4Nav',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.grey[600],
                  letterSpacing: 1,
                  fontWeight: FontWeight.w500,
                ),
          ),
        ),
      ),
    );
  }

  Widget _buildMenuCard(
    BuildContext context,
    String title,
    IconData icon,
    MaterialColor color,
    VoidCallback onTap,
  ) {
    return Hero(
      tag: title,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.white,
                  color.shade50,
                  Colors.white.withOpacity(0.9),
                ],
                stops: const [0.0, 0.6, 1.0],
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: color.withOpacity(0.2),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: color.withOpacity(0.15),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
                const BoxShadow(
                  color: Colors.white,
                  blurRadius: 8,
                  offset: Offset(-2, -2),
                  spreadRadius: -4,
                ),
              ],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        color.shade100,
                        color.shade200,
                      ],
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: color.withOpacity(0.3),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Icon(
                    icon,
                    size: 28,
                    color: color.shade700,
                  ),
                ),
                const SizedBox(height: 12),
                Flexible(
                  child: Text(
                    title,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: color.shade700,
                          fontWeight: FontWeight.w600,
                          height: 1.2,
                          fontSize: 13,
                        ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  PageRoute _createSmoothPageRoute(Widget page, String title) {
    return PageRouteBuilder(
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionDuration: const Duration(milliseconds: 500),
      reverseTransitionDuration: const Duration(milliseconds: 300),
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        const begin = Offset(0.0, 0.1);
        const end = Offset.zero;
        const curve = Curves.easeOutCubic;

        var tween = Tween(begin: begin, end: end).chain(
          CurveTween(curve: curve),
        );

        return SlideTransition(
          position: animation.drive(tween),
          child: FadeTransition(
            opacity: animation,
            child: child,
          ),
        );
      },
    );
  }
}

class VeriListele extends StatefulWidget {
  const VeriListele({super.key});

  @override
  State<VeriListele> createState() => _VeriListeleState();
}

class _VeriListeleState extends State<VeriListele> {
  final String channelId = "2983534";
  final String readApiKey = "2894ERH4G3W220YU";

  Map<String, dynamic>? channelInfo;
  List<Map<String, dynamic>> feedData = [];
  bool isLoading = true;
  String? error;

  @override
  void initState() {
    super.initState();
    fetchData();
  }

  Future<void> fetchData() async {
    setState(() {
      isLoading = true;
      error = null;
    });

    try {
      final response = await http.get(
        Uri.parse(
          'https://api.thingspeak.com/channels/$channelId/feeds.json?api_key=$readApiKey&results=25',
        ),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          channelInfo = data['channel'];
          feedData = List<Map<String, dynamic>>.from(data['feeds'].reversed);
          isLoading = false;
        });
      } else {
        setState(() {
          error = 'Veri çekme hatası: ${response.statusCode}';
          isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        error = 'Bir hata oluştu: $e';
        isLoading = false;
      });
    }
  }

  String formatDate(String? date) {
    if (date == null) return 'N/A';
    final DateTime parsedDate = DateTime.parse(date);
    return '${parsedDate.day}-${parsedDate.month}-${parsedDate.year} ${parsedDate.hour}:${parsedDate.minute}';
  }

  String formatCoordinate(String? coordinate) {
    if (coordinate == null) return 'N/A';
    try {
      final double parsedCoordinate = double.parse(coordinate);
      return parsedCoordinate.toStringAsFixed(6);
    } catch (e) {
      return 'N/A';
    }
  }

  TableRow _buildTableRow(String key, String value) {
    return TableRow(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Text(
            key,
            style: const TextStyle(
              color: Color(0xFF2F72BC),
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Text(
            value,
            style: const TextStyle(
              color: Color(0xFF2F72BC),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.white,
              Colors.blue.shade50,
            ],
          ),
        ),
        child: SafeArea(
          child: isLoading
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 16),
                      Text('Veriler yükleniyor...'),
                    ],
                  ),
                )
              : error != null
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.error_outline,
                              color: Colors.red, size: 48),
                          const SizedBox(height: 16),
                          Text(
                            error!,
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: Colors.red),
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton(
                            onPressed: fetchData,
                            child: const Text('Tekrar Dene'),
                          ),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: fetchData,
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(24.0),
                        physics: const AlwaysScrollableScrollPhysics(),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Geri Butonu ve Başlık
                            Row(
                              children: [
                                InkWell(
                                  onTap: () => Navigator.pop(context),
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.arrow_back_ios,
                                        size: 18,
                                        color: Colors.blue.shade700,
                                      ),
                                      Text(
                                        'Verileri Listele',
                                        style: TextStyle(
                                          color: Colors.blue.shade700,
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 32),
                            // Kanal Bilgileri Tablosu
                            if (channelInfo != null)
                              Container(
                                width: double.infinity,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.05),
                                      blurRadius: 10,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Padding(
                                      padding: const EdgeInsets.all(16),
                                      child: Text(
                                        'Kanal Bilgileri',
                                        style: TextStyle(
                                          color: Colors.blue.shade900,
                                          fontSize: 18,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                    Table(
                                      border: TableBorder(
                                        horizontalInside: BorderSide(
                                          color: Colors.blue.shade50,
                                          width: 1,
                                        ),
                                      ),
                                      children: [
                                        _buildTableRow(
                                            'id',
                                            channelInfo!['id']?.toString() ??
                                                'N/A'),
                                        _buildTableRow(
                                            'name',
                                            channelInfo!['name']?.toString() ??
                                                'N/A'),
                                        _buildTableRow(
                                            'description',
                                            channelInfo!['description']
                                                    ?.toString() ??
                                                'N/A'),
                                        _buildTableRow(
                                            'latitude',
                                            channelInfo!['latitude']
                                                    ?.toString() ??
                                                'N/A'),
                                        _buildTableRow(
                                            'longitude',
                                            channelInfo!['longitude']
                                                    ?.toString() ??
                                                'N/A'),
                                        _buildTableRow(
                                            'field1',
                                            channelInfo!['field1']
                                                    ?.toString() ??
                                                'N/A'),
                                        _buildTableRow(
                                            'field2',
                                            channelInfo!['field2']
                                                    ?.toString() ??
                                                'N/A'),
                                        _buildTableRow(
                                            'created_at',
                                            formatDate(
                                                channelInfo!['created_at']
                                                    ?.toString())),
                                        _buildTableRow(
                                            'updated_at',
                                            formatDate(
                                                channelInfo!['updated_at']
                                                    ?.toString())),
                                        _buildTableRow(
                                            'last_entry_id',
                                            channelInfo!['last_entry_id']
                                                    ?.toString() ??
                                                'N/A'),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            const SizedBox(height: 32),
                            // Son Veriler Tablosu
                            Container(
                              width: double.infinity,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.05),
                                    blurRadius: 10,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.all(16),
                                    child: Text(
                                      'Son 25 Veri (En Yeni En Üstte)',
                                      style: TextStyle(
                                        color: Colors.blue.shade900,
                                        fontSize: 18,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                  SingleChildScrollView(
                                    scrollDirection: Axis.horizontal,
                                    child: DataTable(
                                      headingRowColor: WidgetStateProperty.all(
                                        const Color(0xFF2F72BC),
                                      ),
                                      headingTextStyle: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 14,
                                      ),
                                      columns: const [
                                        DataColumn(label: Text('#')),
                                        DataColumn(label: Text('Tarih/Saat')),
                                        DataColumn(label: Text('Entry ID')),
                                        DataColumn(label: Text('Enlem')),
                                        DataColumn(label: Text('Boylam')),
                                      ],
                                      rows:
                                          feedData.asMap().entries.map((entry) {
                                        final index = entry.key;
                                        final feed = entry.value;
                                        return DataRow(
                                          cells: [
                                            DataCell(Text('${index + 1}')),
                                            DataCell(Text(formatDate(
                                                feed['created_at']))),
                                            DataCell(Text(
                                                feed['entry_id']?.toString() ??
                                                    'N/A')),
                                            DataCell(Text(formatCoordinate(
                                                feed['field1']?.toString()))),
                                            DataCell(Text(formatCoordinate(
                                                feed['field2']?.toString()))),
                                          ],
                                        );
                                      }).toList(),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
        ),
      ),
    );
  }
}

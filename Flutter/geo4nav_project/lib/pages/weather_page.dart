import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';

class WeatherPage extends StatefulWidget {
  const WeatherPage({super.key});

  @override
  State<WeatherPage> createState() => _WeatherPageState();
}

class _WeatherPageState extends State<WeatherPage> {
  Timer? _timer;
  StreamController<Map<String, dynamic>>? _streamController;

  // GPS verileri
  double? _latitude;
  double? _longitude;

  @override
  void initState() {
    super.initState();
    _streamController = StreamController<Map<String, dynamic>>();

    // Widget tamamen yüklendikten sonra veri çekmeye başla
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _fetchWeatherData();
        // Her 30 saniyede bir veri güncelleme (hava durumu için yeterli)
        _timer = Timer.periodic(const Duration(seconds: 30), (_) {
          if (mounted) {
            _fetchWeatherData();
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _streamController?.close();
    _streamController = null;
    super.dispose();
  }

  Future<void> _fetchWeatherData() async {
    if (!mounted || _streamController == null || _streamController!.isClosed)
      return;

    try {
      // Önce GPS verilerini al
      final gpsResponse = await http.get(
        Uri.parse('http://192.168.1.200/get_gps_data'),
      );

      if (!mounted || _streamController == null || _streamController!.isClosed)
        return;

      if (gpsResponse.statusCode == 200) {
        final gpsData = json.decode(gpsResponse.body);
        _parseCoordinates(gpsData['location']);

        if (_latitude != null && _longitude != null) {
          // Hava durumu verilerini al
          await _fetchWeatherFromAPI();
        } else {
          if (mounted &&
              _streamController != null &&
              !_streamController!.isClosed) {
            _streamController!.addError('GPS konumu alınamadı');
          }
        }
      } else {
        // Arduino'ya bağlanamıyorsa test verisi kullan
        _useTestData();
      }
    } catch (e) {
      print('GPS bağlantı hatası: $e');
      if (mounted) {
        _useTestData();
      }
    }
  }

  void _useTestData() {
    if (!mounted) return;

    setState(() {
      _latitude = 39.925533; // Ankara Kızılay
      _longitude = 32.866287;
    });
    _fetchWeatherFromAPI();
  }

  Future<void> _fetchWeatherFromAPI() async {
    if (!mounted || _streamController == null || _streamController!.isClosed)
      return;
    if (_latitude == null || _longitude == null) return;

    try {
      final url =
          'https://api.open-meteo.com/v1/forecast?latitude=${_latitude!.toStringAsFixed(6)}&longitude=${_longitude!.toStringAsFixed(6)}&current_weather=true';

      final response = await http.get(Uri.parse(url));

      if (!mounted || _streamController == null || _streamController!.isClosed)
        return;

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['current_weather'] != null) {
          final weatherData = _parseWeatherData(data['current_weather']);
          if (mounted &&
              _streamController != null &&
              !_streamController!.isClosed) {
            _streamController!.add(weatherData);
          }
        } else {
          if (mounted &&
              _streamController != null &&
              !_streamController!.isClosed) {
            _streamController!.addError('Hava durumu verisi bulunamadı');
          }
        }
      } else {
        if (mounted &&
            _streamController != null &&
            !_streamController!.isClosed) {
          _streamController!.addError(
              'Hava durumu servisine bağlanılamadı. HTTP Kodu: ${response.statusCode}');
        }
      }
    } catch (e) {
      if (mounted &&
          _streamController != null &&
          !_streamController!.isClosed) {
        _streamController!.addError('Hava durumu hatası: $e');
      }
    }
  }

  void _parseCoordinates(String? location) {
    if (location == null || !mounted) return;

    try {
      // "Enlem: 39.123456, Boylam: 32.654321" formatını ayrıştır
      final regex =
          RegExp(r'Enlem:\s*([-+]?\d*\.?\d+),\s*Boylam:\s*([-+]?\d*\.?\d+)');
      final match = regex.firstMatch(location);

      if (match != null && mounted) {
        final lat = double.tryParse(match.group(1) ?? '');
        final lng = double.tryParse(match.group(2) ?? '');

        if (lat != null && lng != null) {
          setState(() {
            _latitude = lat;
            _longitude = lng;
          });
        }
      }
    } catch (e) {
      print('Koordinat ayrıştırma hatası: $e');
    }
  }

  Map<String, dynamic> _parseWeatherData(Map<String, dynamic> currentWeather) {
    // Tarih ve saat formatı
    String time = currentWeather['time'] ?? 'N/A';
    if (time != 'N/A') {
      try {
        final datePart = time.substring(0, 10); // YYYY-MM-DD
        final timePart = time.substring(11, 16); // HH:MM

        final year = datePart.substring(0, 4);
        final monthNum = datePart.substring(5, 7);
        final day = datePart.substring(8, 10);

        final monthNames = {
          '01': 'Ocak',
          '02': 'Şubat',
          '03': 'Mart',
          '04': 'Nisan',
          '05': 'Mayıs',
          '06': 'Haziran',
          '07': 'Temmuz',
          '08': 'Ağustos',
          '09': 'Eylül',
          '10': 'Ekim',
          '11': 'Kasım',
          '12': 'Aralık'
        };

        final monthName = monthNames[monthNum] ?? monthNum;
        time = '$day $monthName $year, $timePart UTC';
      } catch (e) {
        print('Tarih formatı hatası: $e');
      }
    }

    // Hava durumu kodu açıklaması
    final weatherCode = currentWeather['weathercode'] ?? 0;
    String weatherDescription = _getWeatherDescription(weatherCode);

    // Gündüz/Gece durumu
    final isDay = currentWeather['is_day'] == 1;
    final dayNightStatus = isDay ? 'Gündüz' : 'Gece';

    return {
      'time': time,
      'temperature': currentWeather['temperature']?.toString() ?? 'N/A',
      'windspeed': currentWeather['windspeed']?.toString() ?? 'N/A',
      'winddirection': currentWeather['winddirection']?.toString() ?? 'N/A',
      'weatherDescription': weatherDescription,
      'dayNightStatus': dayNightStatus,
      'isDay': isDay,
      'latitude': _latitude,
      'longitude': _longitude,
    };
  }

  String _getWeatherDescription(int weatherCode) {
    switch (weatherCode) {
      case 0:
        return 'Açık';
      case 1:
      case 2:
      case 3:
        return 'Çoğunlukla Açık / Parçalı Bulutlu';
      case 45:
      case 48:
        return 'Sisli';
      case 51:
      case 53:
      case 55:
        return 'Çisenti';
      case 56:
      case 57:
        return 'Dondurucu Çisenti';
      case 61:
      case 63:
      case 65:
        return 'Yağmurlu';
      case 66:
      case 67:
        return 'Dondurucu Yağmur';
      case 71:
      case 73:
      case 75:
        return 'Kar Yağışı';
      case 77:
        return 'Kar Tanesi';
      case 80:
      case 81:
      case 82:
        return 'Sağanak Yağış';
      case 85:
      case 86:
        return 'Kar Sağanağı';
      case 95:
        return 'Fırtına';
      case 96:
      case 99:
        return 'Dolu ile Fırtına';
      default:
        return 'Bilinmiyor';
    }
  }

  String _getWeatherIcon(String description, bool isDay) {
    if (description.contains('Açık')) {
      return isDay ? '☀️' : '🌙';
    } else if (description.contains('Bulutlu')) {
      return isDay ? '⛅' : '☁️';
    } else if (description.contains('Yağmur') ||
        description.contains('Sağanak')) {
      return '🌧️';
    } else if (description.contains('Kar')) {
      return '❄️';
    } else if (description.contains('Fırtına')) {
      return '⛈️';
    } else if (description.contains('Sisli')) {
      return '🌫️';
    } else {
      return '🌤️';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFE0E7EF),
      appBar: AppBar(
        title: const Text(
          'Hava Durumu',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: const Color(0xFF2F72BC),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              if (mounted &&
                  _streamController != null &&
                  !_streamController!.isClosed) {
                _fetchWeatherData();
              }
            },
            tooltip: 'Yenile',
          ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFE0E7EF), Color(0xFFF8FAFC)],
          ),
        ),
        child: StreamBuilder<Map<String, dynamic>>(
          stream: _streamController?.stream,
          builder: (context, snapshot) {
            // StreamController null ise loading göster
            if (_streamController == null) {
              return const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(
                      color: Color(0xFF2F72BC),
                    ),
                    SizedBox(height: 16),
                    Text(
                      'Hava durumu başlatılıyor...',
                      style: TextStyle(
                        color: Color(0xFF2F72BC),
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              );
            }
            if (snapshot.hasError) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline,
                          color: Colors.red, size: 48),
                      const SizedBox(height: 16),
                      Text(
                        snapshot.error.toString(),
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.red),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () {
                          if (mounted &&
                              _streamController != null &&
                              !_streamController!.isClosed) {
                            _fetchWeatherData();
                          }
                        },
                        child: const Text('Tekrar Dene'),
                      ),
                    ],
                  ),
                ),
              );
            }

            if (!snapshot.hasData) {
              return const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(
                      color: Color(0xFF2F72BC),
                    ),
                    SizedBox(height: 16),
                    Text(
                      'Hava durumu yükleniyor...',
                      style: TextStyle(
                        color: Color(0xFF2F72BC),
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              );
            }

            final data = snapshot.data!;
            final weatherIcon =
                _getWeatherIcon(data['weatherDescription'], data['isDay']);

            return SingleChildScrollView(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                children: [
                  // Ana Hava Durumu Kartı
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(30),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: data['isDay']
                            ? [const Color(0xFF4FA3E3), const Color(0xFF2F72BC)]
                            : [
                                const Color(0xFF2F72BC),
                                const Color(0xFF1D4F8C)
                              ],
                      ),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 15,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        Text(
                          'Geo4Nav',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.7),
                            fontSize: 14,
                            fontWeight: FontWeight.w400,
                            letterSpacing: 1.2,
                          ),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          weatherIcon,
                          style: const TextStyle(fontSize: 80),
                        ),
                        const SizedBox(height: 15),
                        Text(
                          '${data['temperature']}°C',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 48,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          data['weatherDescription'],
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          data['dayNightStatus'],
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.9),
                            fontSize: 16,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 25),

                  // Detay Bilgileri Kartı
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(25),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(15),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 10,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(
                              Icons.info_outline,
                              color: Color(0xFF2F72BC),
                              size: 24,
                            ),
                            SizedBox(width: 10),
                            Text(
                              'Detaylı Bilgiler',
                              style: TextStyle(
                                color: Color(0xFF2F72BC),
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        _buildDetailRow('📅 Tarih/Saat', data['time']),
                        const SizedBox(height: 15),
                        _buildDetailRow(
                            '🌡️ Sıcaklık', '${data['temperature']}°C'),
                        const SizedBox(height: 15),
                        _buildDetailRow(
                            '🌬️ Rüzgar Hızı', '${data['windspeed']} km/h'),
                        const SizedBox(height: 15),
                        _buildDetailRow(
                            '🧭 Rüzgar Yönü', '${data['winddirection']}°'),
                        const SizedBox(height: 15),
                        _buildDetailRow('🌍 Konum',
                            'Enlem: ${data['latitude']?.toStringAsFixed(6) ?? 'N/A'}, Boylam: ${data['longitude']?.toStringAsFixed(6) ?? 'N/A'}'),
                      ],
                    ),
                  ),

                  const SizedBox(height: 25),

                  // Alt bilgi
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(15),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF3F8FD),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: const Color(0xFF2F72BC).withOpacity(0.2),
                      ),
                    ),
                    child: const Text(
                      '© 2025 Geo4Nav - Hava durumu verileri Open-Meteo',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12,
                        color: Color(0xFF777777),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 2,
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Color(0xFF666666),
            ),
          ),
        ),
        Expanded(
          flex: 3,
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Color(0xFF333333),
            ),
          ),
        ),
      ],
    );
  }
}

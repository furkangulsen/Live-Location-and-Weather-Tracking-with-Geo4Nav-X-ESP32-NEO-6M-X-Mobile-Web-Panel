import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'package:flutter_map_cancellable_tile_provider/flutter_map_cancellable_tile_provider.dart';

class MapsPage extends StatefulWidget {
  const MapsPage({super.key});

  @override
  State<MapsPage> createState() => _MapsPageState();
}

class _MapsPageState extends State<MapsPage> {
  final MapController _mapController = MapController();
  Timer? _timer;
  final _streamController = StreamController<Map<String, dynamic>>();

  // GPS verileri
  double? _latitude;
  double? _longitude;

  // Harita ayarları
  static const double _defaultLat = 39.9334; // Ankara
  static const double _defaultLng = 32.8597;
  static const double _defaultZoom = 6.0;
  static const double _activeZoom = 15.0;

  @override
  void initState() {
    super.initState();
    // Her 2 saniyede bir veri güncelleme (GPS Verileri sayfasıyla aynı)
    _timer = Timer.periodic(const Duration(seconds: 2), (_) => _fetchGpsData());
    // İlk veriyi hemen çek
    _fetchGpsData();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _streamController.close();
    super.dispose();
  }

  Future<void> _fetchGpsData() async {
    try {
      final response = await http.get(
        Uri.parse('http://192.168.1.200/get_gps_data'),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        _streamController.add(data);

        // Koordinatları ayrıştır ve haritayı güncelle
        _parseCoordinates(data['location']);
      } else {
        _streamController.addError('Veri çekme hatası: ${response.statusCode}');
      }
    } catch (e) {
      // Arduino'ya bağlanamıyorsa test verisi kullan
      print('Arduino bağlantı hatası: $e');
      _useTestData();
    }
  }

  void _useTestData() {
    final testData = {
      'status': 'Aktif (Test Modu - Uydu: 8)',
      'location': 'Enlem: 39.925533, Boylam: 32.866287', // Ankara Kızılay
      'full_data': 'Test modu - Arduino bağlantısı yok',
      'raw_gprmc': 'Test GPRMC verisi'
    };

    _streamController.add(testData);
    _parseCoordinates(testData['location']);
  }

  void _parseCoordinates(String? location) {
    if (location == null) return;

    try {
      // "Enlem: 39.123456, Boylam: 32.654321" formatını ayrıştır
      final regex =
          RegExp(r'Enlem:\s*([-+]?\d*\.?\d+),\s*Boylam:\s*([-+]?\d*\.?\d+)');
      final match = regex.firstMatch(location);

      if (match != null) {
        final lat = double.tryParse(match.group(1) ?? '');
        final lng = double.tryParse(match.group(2) ?? '');

        if (lat != null && lng != null) {
          setState(() {
            _latitude = lat;
            _longitude = lng;
          });

          // Haritayı yeni konuma taşı (sadece widget mount edilmişse)
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              try {
                _mapController.move(LatLng(lat, lng), _activeZoom);
              } catch (e) {
                print('Harita hareket hatası: $e');
              }
            }
          });
        }
      }
    } catch (e) {
      print('Koordinat ayrıştırma hatası: $e');
    }
  }

  void _centerOnLocation() {
    if (_latitude != null && _longitude != null) {
      _mapController.move(LatLng(_latitude!, _longitude!), _activeZoom);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFE0E7EF),
      appBar: AppBar(
        title: const Text(
          'Haritada Konum',
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
            onPressed: _fetchGpsData,
            tooltip: 'Yenile',
          ),
          if (_latitude != null && _longitude != null)
            IconButton(
              icon: const Icon(Icons.my_location),
              onPressed: _centerOnLocation,
              tooltip: 'Konuma Git',
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
          stream: _streamController.stream,
          builder: (context, snapshot) {
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
                        onPressed: _fetchGpsData,
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
                      'GPS verileri yükleniyor...',
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
            final isGpsActive =
                !data['status'].toString().contains('aktif değil');

            return Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                children: [
                  // GPS Durum Kartı
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
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
                        Row(
                          children: [
                            Icon(
                              isGpsActive
                                  ? Icons.gps_fixed
                                  : Icons.gps_not_fixed,
                              color: isGpsActive ? Colors.green : Colors.red,
                              size: 24,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'GPS Durumu: ${data['status']}',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color:
                                      isGpsActive ? Colors.green : Colors.red,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'Konum: ${data['location']}',
                          style: const TextStyle(
                            fontSize: 14,
                            color: Color(0xFF0B3E75),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (data['full_data'] != null) ...[
                          const SizedBox(height: 10),
                          Text(
                            'Detay: ${data['full_data']}',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF666666),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Harita Kartı
                  Expanded(
                    child: Container(
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
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(15),
                        child: FlutterMap(
                          mapController: _mapController,
                          options: MapOptions(
                            initialCenter:
                                _latitude != null && _longitude != null
                                    ? LatLng(_latitude!, _longitude!)
                                    : const LatLng(_defaultLat, _defaultLng),
                            initialZoom: _latitude != null && _longitude != null
                                ? _activeZoom
                                : _defaultZoom,
                            minZoom: 3.0,
                            maxZoom: 18.0,
                          ),
                          children: [
                            // Harita katmanı
                            TileLayer(
                              urlTemplate:
                                  'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                              userAgentPackageName: 'com.example.gomulu_proje',
                              maxZoom: 18,
                              tileProvider: CancellableNetworkTileProvider(),
                            ),

                            // Marker katmanı
                            if (_latitude != null && _longitude != null)
                              MarkerLayer(
                                markers: [
                                  Marker(
                                    point: LatLng(_latitude!, _longitude!),
                                    width: 60,
                                    height: 60,
                                    child: Container(
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        shape: BoxShape.circle,
                                        boxShadow: [
                                          BoxShadow(
                                            color:
                                                Colors.black.withOpacity(0.3),
                                            blurRadius: 6,
                                            offset: const Offset(0, 3),
                                          ),
                                        ],
                                      ),
                                      child: Icon(
                                        Icons.location_on,
                                        color: isGpsActive
                                            ? const Color(0xFF2F72BC)
                                            : Colors.red,
                                        size: 40,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

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
                      '© 2025 Geo4Nav - Harita verileri OpenStreetMap',
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
}

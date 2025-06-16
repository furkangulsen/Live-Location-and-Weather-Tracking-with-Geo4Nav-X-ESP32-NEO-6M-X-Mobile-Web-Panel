import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class ReverseGeocodingPage extends StatefulWidget {
  const ReverseGeocodingPage({super.key});

  @override
  State<ReverseGeocodingPage> createState() => _ReverseGeocodingPageState();
}

class _ReverseGeocodingPageState extends State<ReverseGeocodingPage> {
  final String locationIQApiKey = "pk.683bddad82460b401e5b84f85d430929";
  final String gpsDataUrl = "http://192.168.1.200/get_gps_data";

  Map<String, dynamic>? gpsData;
  Map<String, dynamic>? locationData;
  bool isLoadingGps = true;
  bool isLoadingLocation = false;
  String? error;
  double? currentLat;
  double? currentLon;

  @override
  void initState() {
    super.initState();
    _fetchGpsData();
  }

  Future<void> _fetchGpsData() async {
    setState(() {
      isLoadingGps = true;
      error = null;
    });

    try {
      final response = await http.get(Uri.parse(gpsDataUrl));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          gpsData = data;
          isLoadingGps = false;
        });

        // Location string'inden koordinatları çıkar
        final locationStr = data['location']?.toString() ?? '';
        final coordinates = _extractCoordinatesFromLocation(locationStr);

        if (coordinates != null) {
          currentLat = coordinates['lat'];
          currentLon = coordinates['lon'];
          _performReverseGeocoding(currentLat!, currentLon!);
        }
      } else {
        setState(() {
          error = 'GPS verisi alınamadı: ${response.statusCode}';
          isLoadingGps = false;
        });
      }
    } catch (e) {
      setState(() {
        error = 'GPS bağlantı hatası: $e';
        isLoadingGps = false;
      });
    }
  }

  Map<String, double>? _extractCoordinatesFromLocation(String locationStr) {
    try {
      // "Enlem: 40.146620, Boylam: 29.976990" formatından koordinatları çıkar
      final enlemIndex = locationStr.indexOf('Enlem: ');
      final boylamIndex = locationStr.indexOf('Boylam: ');

      if (enlemIndex != -1 && boylamIndex != -1) {
        // Enlem değerini çıkar
        final enlemStart = enlemIndex + 'Enlem: '.length;
        final enlemEnd = locationStr.indexOf(',', enlemStart);
        final enlemStr = locationStr.substring(enlemStart, enlemEnd).trim();

        // Boylam değerini çıkar
        final boylamStart = boylamIndex + 'Boylam: '.length;
        final boylamStr = locationStr.substring(boylamStart).trim();

        final lat = double.parse(enlemStr);
        final lon = double.parse(boylamStr);

        return {'lat': lat, 'lon': lon};
      }
    } catch (e) {
      print('Koordinat çıkarma hatası: $e');
    }
    return null;
  }

  Future<void> _performReverseGeocoding(double lat, double lon) async {
    setState(() {
      isLoadingLocation = true;
      error = null;
    });

    try {
      final url =
          'https://us1.locationiq.com/v1/reverse?key=$locationIQApiKey&lat=${lat.toStringAsFixed(6)}&lon=${lon.toStringAsFixed(6)}&format=json';

      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          locationData = data;
          isLoadingLocation = false;
        });
      } else {
        setState(() {
          error =
              'Konum servisine bağlanılamadı. HTTP Kodu: ${response.statusCode}';
          isLoadingLocation = false;
        });
      }
    } catch (e) {
      setState(() {
        error = 'Konum servisi hatası: $e';
        isLoadingLocation = false;
      });
    }
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
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
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
                            'Tam Konum (Reverse Geocoding)',
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

                // GPS Durum Kartı
                if (isLoadingGps)
                  const Center(
                    child: Column(
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 16),
                        Text('GPS verileri yükleniyor...'),
                      ],
                    ),
                  )
                else if (error != null)
                  Center(
                    child: Column(
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
                          onPressed: _fetchGpsData,
                          child: const Text('Tekrar Dene'),
                        ),
                      ],
                    ),
                  )
                else ...[
                  // GPS Koordinatları Kartı
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
                          child: Row(
                            children: [
                              const Icon(Icons.gps_fixed, color: Colors.green),
                              const SizedBox(width: 8),
                              Text(
                                'GPS Koordinatları',
                                style: TextStyle(
                                  color: Colors.blue.shade900,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Divider(),
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildInfoRow('Durum',
                                  gpsData!['status']?.toString() ?? 'N/A'),
                              const SizedBox(height: 12),
                              if (currentLat != null && currentLon != null) ...[
                                _buildInfoRow(
                                    'Enlem', currentLat!.toStringAsFixed(6)),
                                const SizedBox(height: 12),
                                _buildInfoRow(
                                    'Boylam', currentLon!.toStringAsFixed(6)),
                              ] else ...[
                                _buildInfoRow('Enlem', 'N/A'),
                                const SizedBox(height: 12),
                                _buildInfoRow('Boylam', 'N/A'),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Konum Bilgileri Kartı
                  if (isLoadingLocation)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(32),
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
                      child: const Center(
                        child: Column(
                          children: [
                            CircularProgressIndicator(),
                            SizedBox(height: 16),
                            Text('Konum bilgileri alınıyor...'),
                          ],
                        ),
                      ),
                    )
                  else if (locationData != null) ...[
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
                            child: Row(
                              children: [
                                const Icon(Icons.location_on,
                                    color: Colors.orange),
                                const SizedBox(width: 8),
                                Text(
                                  'Konum Bilgileri',
                                  style: TextStyle(
                                    color: Colors.blue.shade900,
                                    fontSize: 18,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Divider(),
                          Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (locationData!['display_name'] != null)
                                  _buildInfoRow('Tam Adres',
                                      locationData!['display_name']),
                                const SizedBox(height: 16),

                                // Adres Detayları
                                if (locationData!['address'] != null) ...[
                                  Text(
                                    'Adres Detayları',
                                    style: TextStyle(
                                      color: Colors.blue.shade900,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  ...locationData!['address']
                                      .entries
                                      .map<Widget>((entry) {
                                    String label = _getAddressLabel(entry.key);
                                    return Padding(
                                      padding: const EdgeInsets.only(bottom: 8),
                                      child: _buildInfoRow(
                                          label, entry.value.toString()),
                                    );
                                  }).toList(),
                                ],

                                // Sınır Kutusu
                                if (locationData!['boundingbox'] != null) ...[
                                  const SizedBox(height: 16),
                                  Text(
                                    'Sınır Kutusu',
                                    style: TextStyle(
                                      color: Colors.blue.shade900,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  _buildBoundingBox(
                                      locationData!['boundingbox']),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ] else if (currentLat == null || currentLon == null)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(32),
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
                      child: const Center(
                        child: Text(
                          'GPS konumu henüz aktif değil veya geçersiz. Lütfen GPS verilerini bekleyin.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.orange,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Color(0xFF2F72BC),
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            color: Colors.black87,
            fontSize: 15,
            height: 1.5,
          ),
        ),
      ],
    );
  }

  Widget _buildBoundingBox(List<dynamic> boundingbox) {
    if (boundingbox.length >= 4) {
      return Column(
        children: [
          _buildInfoRow('Güney sınır (min enlem)', boundingbox[0].toString()),
          const SizedBox(height: 8),
          _buildInfoRow('Kuzey sınır (max enlem)', boundingbox[1].toString()),
          const SizedBox(height: 8),
          _buildInfoRow('Batı sınır (min boylam)', boundingbox[2].toString()),
          const SizedBox(height: 8),
          _buildInfoRow('Doğu sınır (max boylam)', boundingbox[3].toString()),
        ],
      );
    }
    return const Text('Sınır kutusu bilgisi mevcut değil');
  }

  String _getAddressLabel(String key) {
    const Map<String, String> labelMap = {
      'road': 'Cadde/Sokak',
      'house_number': 'Bina No',
      'suburb': 'Semt',
      'city_district': 'İlçe',
      'city': 'Şehir',
      'province': 'İl',
      'state': 'Eyalet',
      'postcode': 'Posta Kodu',
      'country': 'Ülke',
      'country_code': 'Ülke Kodu',
    };
    return labelMap[key] ?? key;
  }
}

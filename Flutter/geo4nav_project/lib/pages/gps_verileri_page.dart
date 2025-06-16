import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class GpsVerileriPage extends StatefulWidget {
  const GpsVerileriPage({super.key});

  @override
  State<GpsVerileriPage> createState() => _GpsVerileriPageState();
}

class _GpsVerileriPageState extends State<GpsVerileriPage> {
  Timer? _timer;
  final _streamController = StreamController<Map<String, dynamic>>();

  @override
  void initState() {
    super.initState();
    // Her 2 saniyede bir veri güncelleme
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
      } else {
        _streamController.addError('Veri çekme hatası: ${response.statusCode}');
      }
    } catch (e) {
      _streamController.addError('Bağlantı hatası: $e');
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
          child: StreamBuilder<Map<String, dynamic>>(
            stream: _streamController.stream,
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Center(
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
                );
              }

              if (!snapshot.hasData) {
                return const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 16),
                      Text('GPS verileri yükleniyor...'),
                    ],
                  ),
                );
              }

              final data = snapshot.data!;
              final isGpsActive =
                  !data['status'].toString().contains('aktif değil');

              return SingleChildScrollView(
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
                                'GPS Verileri',
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
                                Icon(
                                  isGpsActive ? Icons.gps_fixed : Icons.gps_off,
                                  color:
                                      isGpsActive ? Colors.green : Colors.red,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'GPS Durumu',
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
                                _buildInfoRow(
                                  'Durum',
                                  data['status'],
                                  color:
                                      isGpsActive ? Colors.green : Colors.red,
                                ),
                                const SizedBox(height: 16),
                                _buildInfoRow('Konum', data['location']),
                                const SizedBox(height: 16),
                                _buildInfoRow(
                                    'Son Tam Veri', data['full_data']),
                                const SizedBox(height: 16),
                                _buildInfoRow('Ham GPRMC', data['raw_gprmc']),
                              ],
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
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, {Color? color}) {
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
          style: TextStyle(
            color: color ?? Colors.black87,
            fontSize: 15,
            height: 1.5,
          ),
        ),
      ],
    );
  }
}

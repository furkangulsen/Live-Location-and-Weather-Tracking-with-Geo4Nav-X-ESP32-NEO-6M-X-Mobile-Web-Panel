import 'package:flutter/material.dart';

class AboutPage extends StatelessWidget {
  const AboutPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFE0E7EF),
      appBar: AppBar(
        title: const Text(
          'Hakkında',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: const Color(0xFF2F72BC),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFE0E7EF), Color(0xFFF8FAFC)],
          ),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            children: [
              // Modern Hero Section
              Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(vertical: 60, horizontal: 40),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color(0xFF667eea),
                      Color(0xFF764ba2),
                      Color(0xFF2F72BC),
                    ],
                    stops: [0.0, 0.5, 1.0],
                  ),
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF2F72BC).withOpacity(0.3),
                      blurRadius: 25,
                      offset: const Offset(0, 15),
                      spreadRadius: 5,
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    // Modern Icon Container
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.2),
                          width: 1,
                        ),
                      ),
                      child: const Icon(
                        Icons.navigation_rounded,
                        size: 64,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 28),
                    // Modern Typography
                    const Text(
                      'Geo4Nav',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 44,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.8,
                        height: 1.1,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 30),

              // Bilgi Kartı
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(30),
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
                          Icons.code_rounded,
                          color: Color(0xFF2F72BC),
                          size: 24,
                        ),
                        SizedBox(width: 10),
                        Text(
                          'Yazılım Bilgileri',
                          style: TextStyle(
                            color: Color(0xFF2F72BC),
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    _buildInfoRow('🚀 Platform', 'Flutter Web Application'),
                    const SizedBox(height: 15),
                    _buildInfoRow('⚡ Teknoloji', 'Dart • Material Design 3'),
                    const SizedBox(height: 15),
                    _buildInfoRow('🌐 API Entegrasyonu',
                        'ThingSpeak • Open-Meteo • LocationIQ'),
                    const SizedBox(height: 15),
                    _buildInfoRow(
                        '📱 Özellikler', 'GPS Takip • Hava Durumu • Harita'),
                  ],
                ),
              ),

              const SizedBox(height: 25),

              // Donanım Bilgileri Kartı - YENİ EKLEME
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(30),
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
                          Icons.memory_rounded,
                          color: Color(0xFF2F72BC),
                          size: 24,
                        ),
                        SizedBox(width: 10),
                        Text(
                          'Donanım Bilgileri',
                          style: TextStyle(
                            color: Color(0xFF2F72BC),
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    _buildInfoRow(
                        '🔧 Geliştirme Kartı', 'ESP32 Development Board'),
                    const SizedBox(height: 15),
                    _buildInfoRow('🛰️ GPS Modülü', 'NEO-6M GPS Receiver'),
                    const SizedBox(height: 15),
                    _buildInfoRow(
                        '📊 Veri İletişimi', 'WiFi • Serial Communication'),
                    const SizedBox(height: 15),
                    _buildInfoRow(
                        '⚡ Güç Kaynağı', 'Arduino UNO (5V Supply) • USB'),
                  ],
                ),
              ),

              const SizedBox(height: 25),

              // Versiyon ve Telif Hakkı
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFFF3F8FD),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: const Color(0xFF2F72BC).withOpacity(0.2),
                  ),
                ),
                child: const Column(
                  children: [
                    Text(
                      'Version 1.0.0',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF2F72BC),
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      '© 2025 Geo4Nav - Tüm hakları saklıdır',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12,
                        color: Color(0xFF777777),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Alt Bilgi
              Container(
                padding: const EdgeInsets.all(15),
                child: const Text(
                  'Modern teknolojiler ile geliştirilmiş\nprofesyonel GPS takip ve hava durumu sistemi',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: Color(0xFF666666),
                    fontStyle: FontStyle.italic,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
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

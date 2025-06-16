import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

class VeriListelePage extends StatefulWidget {
  const VeriListelePage({super.key});

  @override
  State<VeriListelePage> createState() => _VeriListelePageState();
}

class _VeriListelePageState extends State<VeriListelePage> {
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

  // API'den veri çekme fonksiyonu
  Future<void> fetchData() async {
    setState(() {
      isLoading = true;
      error = null;
    });

    try {
      final response = await http.get(
        Uri.parse(
          'https://api.thingspeak.com/channels/$channelId/feeds.json?api_key=$readApiKey&results=100',
        ),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          channelInfo = data['channel'];
          // Verileri ters çeviriyoruz (en yeni en üstte)
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

  // Tarih formatını düzenleme fonksiyonu
  String formatDate(String? dateStr) {
    if (dateStr == null) return '';
    try {
      final date = DateTime.parse(dateStr);
      return DateFormat('dd.MM.yyyy HH:mm:ss').format(date.toLocal());
    } catch (e) {
      return dateStr;
    }
  }

  // Koordinat formatını düzenleme fonksiyonu
  String formatCoordinate(String? coord) {
    if (coord == null || coord.isEmpty) return 'N/A';
    try {
      return double.parse(coord).toStringAsFixed(6);
    } catch (e) {
      return coord;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Verileri Listele'),
        centerTitle: true,
        actions: [
          // Yenileme butonu
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: fetchData,
          ),
        ],
      ),
      body: isLoading
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
                      const Icon(
                        Icons.error_outline,
                        color: Colors.red,
                        size: 48,
                      ),
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
                    physics: const AlwaysScrollableScrollPhysics(),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (channelInfo != null) ...[
                            Card(
                              elevation: 4,
                              child: Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        const Icon(Icons.info_outline),
                                        const SizedBox(width: 8),
                                        const Text(
                                          'Kanal Bilgileri',
                                          style: TextStyle(
                                            fontSize: 20,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const Divider(),
                                    const SizedBox(height: 8),
                                    // Önemli kanal bilgilerini göster
                                    _buildInfoRow('Kanal ID', channelInfo!['id']?.toString() ?? 'N/A'),
                                    _buildInfoRow('İsim', channelInfo!['name']?.toString() ?? 'N/A'),
                                    _buildInfoRow('Açıklama', channelInfo!['description']?.toString() ?? 'N/A'),
                                    _buildInfoRow('Konum', '${channelInfo!['latitude']}, ${channelInfo!['longitude']}'),
                                    _buildInfoRow('Oluşturulma', formatDate(channelInfo!['created_at']?.toString())),
                                    _buildInfoRow('Son Güncelleme', formatDate(channelInfo!['updated_at']?.toString())),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 24),
                          ],
                          Card(
                            elevation: 4,
                            child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      const Icon(Icons.list_alt),
                                      const SizedBox(width: 8),
                                      Text(
                                        'Son ${feedData.length} Veri',
                                        style: const TextStyle(
                                          fontSize: 20,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const Divider(),
                                  const SizedBox(height: 8),
                                  SingleChildScrollView(
                                    scrollDirection: Axis.horizontal,
                                    child: DataTable(
                                      columns: const [
                                        DataColumn(
                                          label: Text(
                                            '#',
                                            style: TextStyle(fontWeight: FontWeight.bold),
                                          ),
                                        ),
                                        DataColumn(
                                          label: Text(
                                            'Tarih/Saat',
                                            style: TextStyle(fontWeight: FontWeight.bold),
                                          ),
                                        ),
                                        DataColumn(
                                          label: Text(
                                            'Entry ID',
                                            style: TextStyle(fontWeight: FontWeight.bold),
                                          ),
                                        ),
                                        DataColumn(
                                          label: Text(
                                            'Enlem',
                                            style: TextStyle(fontWeight: FontWeight.bold),
                                          ),
                                        ),
                                        DataColumn(
                                          label: Text(
                                            'Boylam',
                                            style: TextStyle(fontWeight: FontWeight.bold),
                                          ),
                                        ),
                                      ],
                                      rows: feedData.asMap().entries.map((entry) {
                                        final index = entry.key;
                                        final feed = entry.value;
                                        return DataRow(
                                          cells: [
                                            DataCell(Text('${index + 1}')),
                                            DataCell(Text(formatDate(feed['created_at']))),
                                            DataCell(Text(feed['entry_id']?.toString() ?? 'N/A')),
                                            DataCell(Text(formatCoordinate(feed['field1']?.toString()))),
                                            DataCell(Text(formatCoordinate(feed['field2']?.toString()))),
                                          ],
                                        );
                                      }).toList(),
                                    ),
                                  ),
                                ],
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

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Text(
              '$label:',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              value,
              style: const TextStyle(color: Colors.black87),
            ),
          ),
        ],
      ),
    );
  }
} 
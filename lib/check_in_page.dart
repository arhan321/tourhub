import 'dart:async';
import 'dart:convert';
import 'dart:developer' as dev;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;

import 'recommend_page.dart';

class CheckInPage extends StatefulWidget {
  final String name;
  final String budget;
  final int days;

  const CheckInPage({
    super.key,
    required this.name,
    required this.budget,
    required this.days,
  });

  @override
  State<CheckInPage> createState() => _CheckInPageState();
}

class _CheckInPageState extends State<CheckInPage> {
  bool isLoading = false;
  List<Map<String, dynamic>> allRecommendations = [];

  // simpan list destinasi per hari
  final Map<int, List<Map<String, dynamic>>> visitedPlaces = {};

  void _log(String message, {int level = 0, Object? error, StackTrace? st}) {
    // level: 0=info, 900=warn, 1000=error
    dev.log(message,
        name: 'CHECKIN', level: level, error: error, stackTrace: st);
  }

  String _safeBody(String body) {
    const max = 1200;
    if (body.length <= max) return body;
    return '${body.substring(0, max)}... (truncated)';
  }

  // =========================
  // Location permission helper
  // =========================
  Future<void> _ensureLocationReady() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw Exception('Location service OFF. Tolong nyalakan GPS/Location.');
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied) {
      throw Exception('Permission lokasi ditolak.');
    }

    if (permission == LocationPermission.deniedForever) {
      throw Exception(
        'Permission lokasi ditolak permanen. Buka Settings dan aktifkan lokasi untuk aplikasi.',
      );
    }
  }

  // =========================
  // Ambil data rekomendasi dari API (SUPER DETAIL LOG)
  // =========================
  Future<List<Map<String, dynamic>>> _getRecommendations() async {
    if (allRecommendations.isNotEmpty) return allRecommendations;

    final sw = Stopwatch()..start();

    try {
      // 1) pastikan lokasi aman
      _log('[RECO] Checking location permission...');
      await _ensureLocationReady();

      // 2) ambil posisi
      _log('[RECO] Getting current position...');
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      final lat = position.latitude;
      final lon = position.longitude;

      // 3) buat URL
      final url =
          Uri.parse("https://malay.djncloud.my.id/recommend?lat=$lat&lon=$lon");

      // 4) headers
      final headers = <String, String>{
        "Accept": "application/json",
        // Kalau API Key sudah dimatikan di FastAPI, hapus baris ini:
        "X-API-Key": "secret123",
      };

      _log('[RECO] REQUEST => GET $url');
      _log('[RECO] HEADERS => $headers');
      _log('[RECO] isWeb=$kIsWeb');

      // 5) request dengan timeout
      final response = await http
          .get(url, headers: headers)
          .timeout(const Duration(seconds: 20));

      sw.stop();

      // 6) response logging
      _log(
          '[RECO] RESPONSE <= status=${response.statusCode} (${sw.elapsedMilliseconds}ms)');
      _log('[RECO] RESPONSE HEADERS <= ${response.headers}');
      _log('[RECO] RESPONSE BODY <= ${_safeBody(response.body)}');

      // 7) handle status
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        if (data is! Map || data['topk'] == null) {
          throw FormatException(
            'JSON tidak sesuai: field "topk" tidak ditemukan. body=${_safeBody(response.body)}',
          );
        }

        allRecommendations = List<Map<String, dynamic>>.from(data['topk']);
        return allRecommendations;
      } else {
        throw Exception(
            "HTTP ${response.statusCode}: ${_safeBody(response.body)}");
      }
    } on TimeoutException catch (e, st) {
      sw.stop();
      _log('[RECO] TIMEOUT after ${sw.elapsedMilliseconds}ms',
          level: 1000, error: e, st: st);
      rethrow;
    } on http.ClientException catch (e, st) {
      sw.stop();
      _log(
          '[RECO] ClientException: Failed to fetch (web biasanya CORS/SSL/network)',
          level: 1000,
          error: e,
          st: st);

      if (kIsWeb) {
        _log(
          '[RECO] Web hint: buka DevTools (F12) -> Console/Network. '
          'Jika ada tulisan "CORS" / "blocked by CORS policy", berarti FastAPI belum allow origin.',
          level: 900,
        );
      }
      rethrow;
    } on FormatException catch (e, st) {
      sw.stop();
      _log('[RECO] FormatException (JSON parse/shape)',
          level: 1000, error: e, st: st);
      rethrow;
    } catch (e, st) {
      sw.stop();
      _log('[RECO] UNKNOWN ERROR', level: 1000, error: e, st: st);
      rethrow;
    }
  }

  // =========================
  // Handle klik Check-In Hari X
  // =========================
  Future<void> _showRecommendations(int day) async {
    setState(() => isLoading = true);

    try {
      final rekom = await _getRecommendations();

      // ambil 3 item per hari (misal: day 1 = index 0-2, day 2 = 3-5)
      final start = (day - 1) * 3;
      final end = (start + 3) <= rekom.length ? start + 3 : rekom.length;

      if (start >= rekom.length) {
        throw Exception(
          'Data rekomendasi tidak cukup untuk Day $day. total=${rekom.length}, start=$start',
        );
      }

      final top3 = rekom.sublist(start, end);

      final chosenPlaces = await Navigator.push<List<Map<String, dynamic>>>(
        context,
        MaterialPageRoute(
          builder: (_) => RecommendPage(
            day: day,
            rekomendasi: top3,
            visitedPlaces: visitedPlaces[day] ?? [],
          ),
        ),
      );

      if (chosenPlaces != null && chosenPlaces.isNotEmpty) {
        setState(() {
          visitedPlaces[day] = chosenPlaces;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
                Text("Hari $day: ${chosenPlaces.length} tempat dikunjungi ✅"),
          ),
        );
      }
    } catch (e) {
      _log('[UI] Error saat load rekomendasi: $e', level: 1000);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e")),
      );
    } finally {
      setState(() => isLoading = false);
    }
  }

  // =========================
  // Widget Card Hari
  // =========================
  Widget _buildDayCard(int day) {
    final places = visitedPlaces[day] ?? [];
    final alreadyVisited = places.isNotEmpty;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      elevation: 4,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ListTile(
            leading: Icon(
              alreadyVisited ? Icons.check_circle : Icons.location_on,
              color: alreadyVisited ? Colors.green : Colors.blue,
            ),
            title: Text("Day $day"),
            subtitle: alreadyVisited
                ? Text("${places.length} tempat dikunjungi")
                : const Text("Klik untuk lihat rekomendasi"),
            trailing: ElevatedButton(
              onPressed: isLoading ? null : () => _showRecommendations(day),
              child: Text(alreadyVisited ? "Done" : "Check-In"),
            ),
          ),
          if (alreadyVisited)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: places.map((place) {
                  final name = (place['name'] ?? '').toString();
                  final dist = place['distance_km'];

                  String distText = '-';
                  if (dist is num) {
                    distText = dist.toStringAsFixed(2);
                  } else {
                    // fallback kalau dist berbentuk string
                    final parsed = num.tryParse(dist?.toString() ?? '');
                    if (parsed != null) distText = parsed.toStringAsFixed(2);
                  }

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(
                      children: [
                        const Icon(Icons.check, color: Colors.green, size: 16),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            "$name — $distText km",
                            style: const TextStyle(fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
        ],
      ),
    );
  }

  // =========================
  // Build UI utama
  // =========================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Check-In Wisata (${widget.name})")),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Card(
              elevation: 3,
              child: ListTile(
                title: Text(
                  widget.name,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Text(
                    "Budget: ${widget.budget} | Stay: ${widget.days} hari"),
                leading: const Icon(Icons.person),
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: ListView.builder(
                itemCount: widget.days,
                itemBuilder: (context, index) {
                  final day = index + 1;
                  return _buildDayCard(day);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

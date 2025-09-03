import 'dart:convert';
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

  // Ambil data rekomendasi dari API
  Future<List<Map<String, dynamic>>> _getRecommendations() async {
    if (allRecommendations.isNotEmpty) return allRecommendations;

    Position position = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );
    final lat = position.latitude;
    final lon = position.longitude;

    final url = Uri.parse(
      "https://malaysia.djncloud.my.id/recommend?lat=$lat&lon=$lon",
    );

    final response = await http.get(
      url,
      headers: {"Accept": "application/json", "X-API-Key": "secret123"},
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      allRecommendations = List<Map<String, dynamic>>.from(data['topk']);
      return allRecommendations;
    } else {
      throw Exception("Gagal ambil rekomendasi: ${response.body}");
    }
  }

  // Handle klik Check-In Hari X
  Future<void> _showRecommendations(int day) async {
    setState(() => isLoading = true);

    try {
      final rekom = await _getRecommendations();

      // ambil 3 item per hari (misal: day 1 = index 0-2, day 2 = 3-5)
      final start = (day - 1) * 3;
      final end = (start + 3) <= rekom.length ? start + 3 : rekom.length;
      final top3 = rekom.sublist(start, end);

      // tunggu hasil dari RecommendPage (list destinasi terpilih)
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
            content: Text(
              "Hari $day: ${chosenPlaces.length} tempat dikunjungi ✅",
            ),
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e")),
      );
    } finally {
      setState(() => isLoading = false);
    }
  }

  // Widget Card Hari
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
                  return Row(
                    children: [
                      const Icon(Icons.check, color: Colors.green, size: 16),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          "${place['name']} — ${(place['distance_km'] as num).toStringAsFixed(2)} km",
                          style: const TextStyle(fontSize: 13),
                        ),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
        ],
      ),
    );
  }

  // Build UI utama
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
                title: Text(widget.name,
                    style: const TextStyle(fontWeight: FontWeight.bold)),
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

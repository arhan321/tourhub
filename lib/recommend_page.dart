import 'package:flutter/material.dart';

class RecommendPage extends StatefulWidget {
  final int day;
  final List<Map<String, dynamic>> rekomendasi;
  final List<Map<String, dynamic>> visitedPlaces; // bawaan dari CheckInPage

  const RecommendPage({
    super.key,
    required this.day,
    required this.rekomendasi,
    this.visitedPlaces = const [],
  });

  @override
  State<RecommendPage> createState() => _RecommendPageState();
}

class _RecommendPageState extends State<RecommendPage> {
  late Set<int> selectedIndexes;

  @override
  void initState() {
    super.initState();
    // tandai index yang sudah dikunjungi sebelumnya
    selectedIndexes = widget.visitedPlaces
        .map((place) =>
            widget.rekomendasi.indexWhere((e) => e['name'] == place['name']))
        .where((i) => i != -1)
        .toSet();
  }

  void _togglePlace(int index) {
    setState(() {
      if (selectedIndexes.contains(index)) {
        selectedIndexes.remove(index);
      } else {
        selectedIndexes.add(index);
      }
    });
  }

  void _saveAndExit() {
    final chosenPlaces =
        selectedIndexes.map((i) => widget.rekomendasi[i]).toList();
    Navigator.pop(context, chosenPlaces);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
            "Rekomendasi Hari ${widget.day} (${selectedIndexes.length} dipilih)"),
        actions: [
          IconButton(
            icon: const Icon(Icons.check),
            onPressed: _saveAndExit,
          )
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView.builder(
          itemCount: widget.rekomendasi.length,
          itemBuilder: (context, index) {
            final place = widget.rekomendasi[index];
            final isSelected = selectedIndexes.contains(index);

            return Card(
              margin: const EdgeInsets.only(bottom: 16),
              elevation: 4,
              child: ListTile(
                leading: Icon(
                  isSelected ? Icons.check_circle : Icons.place,
                  color: isSelected ? Colors.green : Colors.blue,
                ),
                title: Text(place['name'] ?? 'Unknown'),
                subtitle: Text(
                  "${(place['distance_km'] as num).toStringAsFixed(2)} km",
                ),
                onTap: () => _togglePlace(index),
              ),
            );
          },
        ),
      ),
    );
  }
}

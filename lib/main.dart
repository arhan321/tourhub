import 'package:flutter/material.dart';
import 'check_in_page.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: "Predict Wisata",
      theme: ThemeData(primarySwatch: Colors.blue),
      home: const FormPage(), // Halaman awal
    );
  }
}

// ================== FORM PAGE ==================
class FormPage extends StatefulWidget {
  const FormPage({super.key});

  @override
  State<FormPage> createState() => _FormPageState();
}

class _FormPageState extends State<FormPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController nameController = TextEditingController();
  final TextEditingController budgetController = TextEditingController();
  final TextEditingController daysController = TextEditingController();

  void _submit() {
    if (_formKey.currentState!.validate()) {
      final name = nameController.text.trim();
      final budget = budgetController.text.trim();
      final days = int.tryParse(daysController.text.trim()) ?? 1;

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => CheckInPage(
            name: name,
            budget: budget,
            days: days,
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Formulir Wisata")),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                controller: nameController,
                decoration: const InputDecoration(labelText: "Nama"),
                validator: (v) => v == null || v.isEmpty ? "Wajib diisi" : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: budgetController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: "Budget (Rp)"),
                validator: (v) => v == null || v.isEmpty ? "Wajib diisi" : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: daysController,
                keyboardType: TextInputType.number,
                decoration:
                    const InputDecoration(labelText: "Lama Stay (hari)"),
                validator: (v) => v == null || v.isEmpty ? "Wajib diisi" : null,
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _submit,
                child: const Text("Lanjut ke Check-In"),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

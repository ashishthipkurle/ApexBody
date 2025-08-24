import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/data_provider.dart';
import '../models/user_model.dart';
import '../widgets/loading_animation.dart';

class BodyAnalysisForm extends StatefulWidget {
  const BodyAnalysisForm({Key? key}) : super(key: key);

  @override
  State<BodyAnalysisForm> createState() => _BodyAnalysisFormState();
}

class _BodyAnalysisFormState extends State<BodyAnalysisForm> {
  final _formKey = GlobalKey<FormState>();

  AppUser? selectedClient;
  List<AppUser> clients = [];
  bool loadingClients = true;
  bool saving = false;

  // Controllers for each field
  final TextEditingController heightController = TextEditingController();
  final TextEditingController heartRateController = TextEditingController();
  final TextEditingController healthScoreController = TextEditingController();
  final TextEditingController bodyAgeController = TextEditingController();
  final TextEditingController weightController = TextEditingController();
  final TextEditingController weightControlController = TextEditingController();
  final TextEditingController bmiController = TextEditingController();
  final TextEditingController bodyFatController = TextEditingController();
  final TextEditingController bodyTypeController = TextEditingController();
  final TextEditingController muscleMassController = TextEditingController();
  final TextEditingController boneMassController = TextEditingController();
  final TextEditingController visceralFatController = TextEditingController();
  final TextEditingController calorieIntakeController = TextEditingController();
  final TextEditingController bodyWaterController = TextEditingController();
  final TextEditingController metabolicAgeController = TextEditingController();
  final TextEditingController bmrController = TextEditingController();
  final TextEditingController waistHipRatioController = TextEditingController();
  final TextEditingController adiposityController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadClients();
  }

  Future<void> _loadClients() async {
    final provider = Provider.of<DataProvider>(context, listen: false);
    final c = await provider.fetchClients();
    setState(() {
      clients = c;
      loadingClients = false;
    });
  }

  Future<void> _saveAnalysis() async {
    if (selectedClient == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Select a client')));
      return;
    }
    setState(() => saving = true);
    final clientId = selectedClient!.id;
    final data = {
      'user_id': clientId,
      'height': double.tryParse(heightController.text),
      'heart_rate': int.tryParse(heartRateController.text),
      'health_score': double.tryParse(healthScoreController.text),
      'body_age': int.tryParse(bodyAgeController.text),
      'weight': double.tryParse(weightController.text),
      'weight_control': double.tryParse(weightControlController.text),
      'bmi': double.tryParse(bmiController.text),
      'body_fat': double.tryParse(bodyFatController.text),
      'body_type': bodyTypeController.text,
      'muscle_mass': double.tryParse(muscleMassController.text),
      'bone_mass': double.tryParse(boneMassController.text),
      'visceral_fat': double.tryParse(visceralFatController.text),
      'calorie_intake': double.tryParse(calorieIntakeController.text),
      'body_water': double.tryParse(bodyWaterController.text),
      'metabolic_age': int.tryParse(metabolicAgeController.text),
      'bmr': double.tryParse(bmrController.text),
      'waist_hip_ratio': double.tryParse(waistHipRatioController.text),
      'adiposity_level': double.tryParse(adiposityController.text),
    };
    try {
      await Provider.of<DataProvider>(context, listen: false)
          .saveBodyAnalysisReport(data);

      // Update client's weight and height in users table
      await Provider.of<DataProvider>(context, listen: false)
          .updateClientWeightHeight(
        clientId: clientId,
        weight: double.tryParse(weightController.text),
        height: double.tryParse(heightController.text),
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Analysis saved!')));
      _formKey.currentState?.reset();
      heightController.clear();
      heartRateController.clear();
      healthScoreController.clear();
      bodyAgeController.clear();
      weightController.clear();
      weightControlController.clear();
      bmiController.clear();
      bodyFatController.clear();
      bodyTypeController.clear();
      muscleMassController.clear();
      boneMassController.clear();
      visceralFatController.clear();
      calorieIntakeController.clear();
      bodyWaterController.clear();
      metabolicAgeController.clear();
      bmrController.clear();
      waistHipRatioController.clear();
      adiposityController.clear();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Container(
          decoration: const BoxDecoration(
            image: DecorationImage(
              image: AssetImage('assets/Dashboard6.png'),
              fit: BoxFit.cover,
            ),
          ),
        ),
        Scaffold(
          backgroundColor: Colors.transparent,
          body: loadingClients
              ? const Center(
                  child:
                      LoadingAnimation(size: 120, text: "Loading clients..."))
              : Form(
                  key: _formKey,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        DropdownButtonFormField<AppUser>(
                          value: selectedClient,
                          items: clients
                              .map((c) => DropdownMenuItem(
                                    value: c,
                                    child: Text(c.name ?? ''),
                                  ))
                              .toList(),
                          onChanged: (c) => setState(() => selectedClient = c),
                          decoration: InputDecoration(
                            labelText: 'Select Client',
                            fillColor: Colors.white,
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8)),
                            filled: true,
                            // fillColor: Colors.white.withOpacity(0.6),
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 14),
                          ),
                          validator: (c) =>
                              c == null ? 'Select a client' : null,
                        ),
                        const SizedBox(height: 16),
                        buildTextField("Height (cm / ft.)", heightController),
                        buildTextField("Heart Rate", heartRateController),
                        buildTextField("Health Score", healthScoreController),
                        buildTextField("Body Age", bodyAgeController),
                        buildTextField("Weight (kg)", weightController),
                        buildTextField(
                            "Weight Control", weightControlController),
                        buildTextField("BMI (kg/m²)", bmiController),
                        buildTextField("Body Fat Ratio", bodyFatController),
                        buildTextField("Body Type", bodyTypeController),
                        buildTextField(
                            "Muscle Mass (kg)", muscleMassController),
                        buildTextField("Bone Mass (kg)", boneMassController),
                        buildTextField(
                            "Visceral Fat Level", visceralFatController),
                        buildTextField("Recommended Calorie Intake",
                            calorieIntakeController),
                        buildTextField("Body Water %", bodyWaterController),
                        buildTextField("Metabolic Age", metabolicAgeController),
                        buildTextField(
                            "BMR (Basal Metabolic Rate)", bmrController),
                        buildTextField(
                            "Waist Hip Ratio", waistHipRatioController),
                        buildTextField("Adiposity Level", adiposityController),
                        const SizedBox(height: 20),
                        ElevatedButton(
                          onPressed: saving
                              ? null
                              : () {
                                  if (_formKey.currentState!.validate()) {
                                    _saveAnalysis();
                                  }
                                },
                          child: saving
                              ? const SizedBox(
                                  height: 24,
                                  width: 24,
                                  child: LoadingAnimation(size: 24))
                              : const Text("Submit"),
                        ),
                      ],
                    ),
                  ),
                ),
        ),
      ],
    );
  }

  Widget buildTextField(String label, TextEditingController controller) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: TextFormField(
        controller: controller,
        decoration: InputDecoration(
          labelText: label,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          filled: true,
          fillColor: Colors.white.withOpacity(0.6),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        ),
        validator: (value) =>
            value == null || value.isEmpty ? "Enter $label" : null,
      ),
    );
  }
}

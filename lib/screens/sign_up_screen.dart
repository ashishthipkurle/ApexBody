import 'dart:math';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({Key? key}) : super(key: key);

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final _formKey = GlobalKey<FormState>();

  // Controllers
  final TextEditingController _nameCtrl = TextEditingController();
  final TextEditingController _dobCtrl = TextEditingController();
  final TextEditingController _ageCtrl = TextEditingController();
  final TextEditingController _phoneCtrl = TextEditingController();
  final TextEditingController _emailCtrl = TextEditingController();
  final TextEditingController _professionCtrl = TextEditingController();
  final TextEditingController _emergencyNameCtrl = TextEditingController();
  final TextEditingController _emergencyPhoneCtrl = TextEditingController();
  final TextEditingController _heightCtrl = TextEditingController();
  final TextEditingController _weightCtrl = TextEditingController();
  final TextEditingController _bmiCtrl = TextEditingController();
  final TextEditingController _startDateCtrl = TextEditingController();
  final TextEditingController _passwordCtrl = TextEditingController();
  final TextEditingController _confirmPasswordCtrl = TextEditingController();

  // State
  String? _gender;
  String? _emergencyRelation;
  String _selectedFitnessGoal = 'Lose weight';
  String _selectedMembershipType = 'Monthly';
  bool _trainerRequired = false;
  bool _physioRequired = false;
  bool _hasMedicalCondition = false;
  bool _takingMedication = false;
  bool _hadSurgeries = false;

  bool _loading = false;
  bool _obscurePassword = true;
  bool _obscureConfirm = true;

  final List<String> _relations = [
    'Mother',
    'Father',
    'Spouse',
    'Sibling',
    'Friend',
    'Other'
  ];

  @override
  void initState() {
    super.initState();
    _heightCtrl.addListener(_recalculateBmi);
    _weightCtrl.addListener(_recalculateBmi);
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _dobCtrl.dispose();
    _ageCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    _professionCtrl.dispose();
    _emergencyNameCtrl.dispose();
    _emergencyPhoneCtrl.dispose();
    _heightCtrl.dispose();
    _weightCtrl.dispose();
    _bmiCtrl.dispose();
    _startDateCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmPasswordCtrl.dispose();
    super.dispose();
  }

  void _recalculateBmi() {
    final h = double.tryParse(_heightCtrl.text);
    final w = double.tryParse(_weightCtrl.text);
    if (h != null && w != null && h > 0) {
      final bmi = w / pow(h / 100, 2);
      _bmiCtrl.text = bmi.toStringAsFixed(1);
    } else {
      _bmiCtrl.text = '';
    }
  }

  Future<void> _pickDOB() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime(now.year - 20),
      firstDate: DateTime(now.year - 100),
      lastDate: now,
    );
    if (picked != null) {
      _dobCtrl.text =
          '${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
      final age = _calculateAge(picked);
      _ageCtrl.text = age.toString();
      _recalculateBmi();
    }
  }

  int _calculateAge(DateTime dob) {
    final today = DateTime.now();
    var age = today.year - dob.year;
    if (today.month < dob.month ||
        (today.month == dob.month && today.day < dob.day)) {
      age--;
    }
    return age;
  }

  String? _validateName(String? v) {
    if (v == null || v.trim().isEmpty) return 'Please enter full name';
    final onlyLetters = RegExp(r'^[A-Za-z ]+$');
    if (!onlyLetters.hasMatch(v))
      return 'Name must contain letters and spaces only';
    return null;
  }

  String? _validateProfession(String? v) {
    if (v == null || v.trim().isEmpty) return 'Please enter profession';
    final onlyLetters = RegExp(r'^[A-Za-z ]+$');
    if (!onlyLetters.hasMatch(v))
      return 'Profession must contain letters and spaces only';
    return null;
  }

  String? _validatePhone(String? v) {
    if (v == null || v.trim().isEmpty) return 'Please enter phone number';
    final digits = v.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.length != 10) return 'Phone number must be 10 digits';
    return null;
  }

  String? _validateEmail(String? v) {
    if (v == null || v.trim().isEmpty) return 'Please enter email';
    final emailRegex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
    if (!emailRegex.hasMatch(v)) return 'Enter a valid email';
    return null;
  }

  String? _validateHeight(String? v) {
    if (v == null || v.trim().isEmpty) return 'Please enter height in cm';
    final val = double.tryParse(v);
    if (val == null) return 'Height must be a number';
    if (val > 200) return 'Height cannot be more than 200 cm';
    return null;
  }

  String? _validateWeight(String? v) {
    if (v == null || v.trim().isEmpty) return 'Please enter weight in kg';
    final val = double.tryParse(v);
    if (val == null) return 'Weight must be a number';
    return null;
  }

  String? _validatePassword(String? v) {
    if (v == null || v.isEmpty) return 'Please enter password';
    if (v.length < 6) return 'Password must be at least 6 characters';
    return null;
  }

  String? _validateConfirm(String? v) {
    if (v == null || v.isEmpty) return 'Please confirm password';
    if (v != _passwordCtrl.text) return 'Passwords do not match';
    return null;
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_gender == null) {
      _showError('Please select gender');
      return;
    }
    if (_emergencyRelation == null) {
      _showError('Please select emergency relation');
      return;
    }

    setState(() => _loading = true);
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final email = _emailCtrl.text.trim();
    final res = await auth.signUp(
      email: email,
      password: _passwordCtrl.text.trim(),
      name: _nameCtrl.text.trim(),
      phone: _phoneCtrl.text.trim(),
      weight: double.tryParse(_weightCtrl.text.trim()),
      height: double.tryParse(_heightCtrl.text.trim()),
      age: int.tryParse(_ageCtrl.text.trim()),
      // normalize gender to lowercase to match DB enum/check constraint (e.g. 'male','female')
      gender: (_gender ?? '').toLowerCase(),
      extra: {
        'dob': _dobCtrl.text.trim(),
        'profession': _professionCtrl.text.trim(),
        'emergency_name': _emergencyNameCtrl.text.trim(),
        'emergency_relation': _emergencyRelation ?? '',
        'emergency_phone': _emergencyPhoneCtrl.text.trim(),
        'bmi': double.tryParse(_bmiCtrl.text) ?? _bmiCtrl.text.trim(),
        'fitness_goal': _selectedFitnessGoal,
        // send booleans as real booleans so Postgres boolean columns receive true/false
        'medical_condition': _hasMedicalCondition,
        'medication': _takingMedication,
        'surgeries': _hadSurgeries,
        'membership_type': _selectedMembershipType,
        'start_date': _startDateCtrl.text.trim(),
        'trainer_required': _trainerRequired,
        'physio_required': _physioRequired,
      },
    );

    setState(() => _loading = false);
    if (res != null) {
      _showError(res);
      return;
    }

    if (!mounted) return;
    final msg =
        'Sign up successful. A confirmation email has been sent to $email. Please confirm it.';
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      duration: const Duration(seconds: 6),
    ));
    Navigator.of(context).pop();
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  InputDecoration _decoration(String label) => InputDecoration(
        hintText: label,
        hintStyle: const TextStyle(color: Colors.red),
        filled: true,
        fillColor: Colors.grey.shade200,
        contentPadding:
            const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide.none,
        ),
      );
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Align(
                    alignment: Alignment.topLeft,
                    child: Image.asset('assets/ApexBody_logo.png', height: 60)),
                const SizedBox(height: 10),
                const Center(
                    child: Text('Sign Up',
                        style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: Colors.red))),
                const SizedBox(height: 20),

                // Personal fields
                TextFormField(
                    controller: _nameCtrl,
                    decoration: _decoration('Full Name'),
                    validator: _validateName),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(
                      child: TextFormField(
                          controller: _dobCtrl,
                          readOnly: true,
                          decoration: _decoration('Date of Birth'),
                          onTap: _pickDOB,
                          validator: (v) => (v == null || v.isEmpty)
                              ? 'Please pick date of birth'
                              : null)),
                  const SizedBox(width: 12),
                  SizedBox(
                      width: 100,
                      child: TextFormField(
                          controller: _ageCtrl,
                          readOnly: true,
                          decoration: _decoration('Age'),
                          validator: (v) {
                            if (v == null || v.isEmpty) return 'Age required';
                            if (int.tryParse(v) == null) return 'Invalid age';
                            return null;
                          })),
                ]),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                    value: _gender,
                    items: const [
                      DropdownMenuItem(value: 'Male', child: Text('Male')),
                      DropdownMenuItem(value: 'Female', child: Text('Female')),
                      DropdownMenuItem(value: 'Other', child: Text('Other'))
                    ],
                    onChanged: (v) => setState(() => _gender = v),
                    decoration: _decoration('Gender'),
                    validator: (v) =>
                        v == null ? 'Please select gender' : null),
                const SizedBox(height: 12),
                TextFormField(
                    controller: _phoneCtrl,
                    keyboardType: TextInputType.phone,
                    decoration: _decoration('Phone Number'),
                    validator: _validatePhone),
                const SizedBox(height: 12),
                TextFormField(
                    controller: _emailCtrl,
                    keyboardType: TextInputType.emailAddress,
                    decoration: _decoration('Email'),
                    validator: _validateEmail),
                const SizedBox(height: 12),
                TextFormField(
                    controller: _professionCtrl,
                    decoration: _decoration('Profession'),
                    validator: _validateProfession),

                const SizedBox(height: 16),
                const Text('Emergency Contact',
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.red)),
                const SizedBox(height: 8),
                TextFormField(
                    controller: _emergencyNameCtrl,
                    decoration: _decoration('Name')),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                    value: _emergencyRelation,
                    items: _relations
                        .map((r) => DropdownMenuItem(value: r, child: Text(r)))
                        .toList(),
                    onChanged: (v) => setState(() => _emergencyRelation = v),
                    decoration: _decoration('Relationship'),
                    validator: (v) =>
                        v == null ? 'Please select relation' : null),
                const SizedBox(height: 12),
                TextFormField(
                    controller: _emergencyPhoneCtrl,
                    keyboardType: TextInputType.phone,
                    decoration: _decoration('Phone Number')),

                const SizedBox(height: 16),
                const Text('Health & Fitness Details',
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.red)),
                const SizedBox(height: 8),
                Row(children: [
                  Expanded(
                      child: TextFormField(
                          controller: _heightCtrl,
                          keyboardType: TextInputType.number,
                          decoration: _decoration('Height (cm)'),
                          validator: _validateHeight)),
                  const SizedBox(width: 12),
                  Expanded(
                      child: TextFormField(
                          controller: _weightCtrl,
                          keyboardType: TextInputType.number,
                          decoration: _decoration('Weight (kg)'),
                          validator: _validateWeight))
                ]),
                const SizedBox(height: 12),
                TextFormField(
                    controller: _bmiCtrl,
                    readOnly: true,
                    decoration: _decoration('BMI')),
                const SizedBox(height: 12),
                CheckboxListTile(
                    title: const Text('Existing Medical Condition',
                        style: TextStyle(color: Colors.red)),
                    value: _hasMedicalCondition,
                    onChanged: (v) =>
                        setState(() => _hasMedicalCondition = v ?? false),
                    controlAffinity: ListTileControlAffinity.leading),
                CheckboxListTile(
                    title: const Text('Taking Medication',
                        style: TextStyle(color: Colors.red)),
                    value: _takingMedication,
                    onChanged: (v) =>
                        setState(() => _takingMedication = v ?? false),
                    controlAffinity: ListTileControlAffinity.leading),
                CheckboxListTile(
                    title: const Text('Surgeries / Injuries in past 6 months',
                        style: TextStyle(color: Colors.red)),
                    value: _hadSurgeries,
                    onChanged: (v) =>
                        setState(() => _hadSurgeries = v ?? false),
                    controlAffinity: ListTileControlAffinity.leading),

                const SizedBox(height: 16),
                const Text('Membership Details',
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.red)),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                    value: _selectedMembershipType,
                    items: const [
                      DropdownMenuItem(
                          value: 'Monthly', child: Text('Monthly')),
                      DropdownMenuItem(
                          value: 'Quarterly', child: Text('Quarterly')),
                      DropdownMenuItem(
                          value: 'Half Yearly', child: Text('Half Yearly')),
                      DropdownMenuItem(value: 'Yearly', child: Text('Yearly'))
                    ],
                    onChanged: (v) => setState(() =>
                        _selectedMembershipType = v ?? _selectedMembershipType),
                    decoration: _decoration('Type')),
                const SizedBox(height: 12),
                TextFormField(
                    controller: _startDateCtrl,
                    readOnly: true,
                    decoration: _decoration('Start Date'),
                    onTap: () async {
                      final now = DateTime.now();
                      final picked = await showDatePicker(
                          context: context,
                          initialDate: now,
                          firstDate: DateTime(now.year - 1),
                          lastDate: DateTime(now.year + 5));
                      if (picked != null)
                        _startDateCtrl.text =
                            '${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
                    }),
                const SizedBox(height: 12),
                CheckboxListTile(
                    title: const Text('Trainer Required',
                        style: TextStyle(color: Colors.red)),
                    value: _trainerRequired,
                    onChanged: (v) =>
                        setState(() => _trainerRequired = v ?? false),
                    controlAffinity: ListTileControlAffinity.leading),
                CheckboxListTile(
                    title: const Text('Physiotherapy Required',
                        style: TextStyle(color: Colors.red)),
                    value: _physioRequired,
                    onChanged: (v) =>
                        setState(() => _physioRequired = v ?? false),
                    controlAffinity: ListTileControlAffinity.leading),

                const SizedBox(height: 16),
                TextFormField(
                  controller: _passwordCtrl,
                  obscureText: _obscurePassword,
                  decoration: _decoration('Password').copyWith(
                    suffixIcon: IconButton(
                      icon: Icon(_obscurePassword
                          ? Icons.visibility
                          : Icons.visibility_off),
                      onPressed: () =>
                          setState(() => _obscurePassword = !_obscurePassword),
                    ),
                  ),
                  validator: _validatePassword,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _confirmPasswordCtrl,
                  obscureText: _obscureConfirm,
                  decoration: _decoration('Confirm Password').copyWith(
                    suffixIcon: IconButton(
                      icon: Icon(_obscureConfirm
                          ? Icons.visibility
                          : Icons.visibility_off),
                      onPressed: () =>
                          setState(() => _obscureConfirm = !_obscureConfirm),
                    ),
                  ),
                  validator: _validateConfirm,
                ),
                const SizedBox(height: 30),
                _loading
                    ? const CircularProgressIndicator()
                    : ElevatedButton(
                        onPressed: _loading ? null : _submit,
                        style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 60, vertical: 14),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(30))),
                        child: const Text('Sign Up',
                            style:
                                TextStyle(fontSize: 18, color: Colors.white))),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

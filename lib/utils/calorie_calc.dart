// Utilities to compute BMR and calories burned
double bmrMifflinStJeor({required double weightKg, required double heightCm, required int age, required String gender}) {
  // gender: 'male' or 'female'
  final base = 10 * weightKg + 6.25 * heightCm - 5 * age;
  if (gender.toLowerCase() == 'male') return base + 5;
  return base - 161;
}

double caloriesFromMet({required double met, required double weightKg, required double durationMinutes}) {
  // Calories burned = (MET * weightKg * durationMinutes) / 60
  return (met * weightKg * durationMinutes) / 60.0;
}


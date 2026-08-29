extension StringExtensions on String {
  bool get isValidPhone => RegExp(r'^\+?[1-9]\d{1,14}$').hasMatch(this);
  bool get isValidEmail => RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(this);
  String get capitalize => isEmpty ? this : '${this[0].toUpperCase()}${substring(1)}';
  String get capitalizeWords => split(' ').map((w) => w.capitalize).join(' ');
  bool get isBlank => trim().isEmpty;
  bool get isNotBlank => trim().isNotEmpty;
}

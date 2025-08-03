String formatCardName(String? name) {
  if (name == null || name.isEmpty) return 'No Name';
  String formatted = name.replaceAll('-ex', ' EX');
  return formatted[0].toUpperCase() + formatted.substring(1);
}

import 'dart:convert';

class BeautyFilter {
  BeautyFilter({
    this.contrast = 1.0,
    this.brightness = 1.0,
    this.saturation = 1.0,
    this.blurRadius = 0.0,
    this.noiseReduction = 0.0,
  });
  factory BeautyFilter.fromJson(String source) =>
      BeautyFilter.fromMap(json.decode(source) as Map<String, dynamic>);

  factory BeautyFilter.fromMap(Map<String, dynamic> map) {
    return BeautyFilter(
      contrast: map['contrast'] as double? ?? 1.0,
      brightness: map['brightness'] as double? ?? 1.0,
      saturation: map['saturation'] as double? ?? 1.0,
      blurRadius: map['blurRadius'] as double? ?? 0.0,
      noiseReduction: map['noiseReduction'] as double? ?? 0.0,
    );
  }

  double contrast;
  double brightness;
  double saturation;
  double blurRadius;
  double noiseReduction;

  BeautyFilter copyWith({
    String? name,
    double? contrast,
    double? brightness,
    double? saturation,
    double? blurRadius,
    double? noiseReduction,
  }) {
    return BeautyFilter(
      contrast: contrast ?? this.contrast,
      brightness: brightness ?? this.brightness,
      saturation: saturation ?? this.saturation,
      blurRadius: blurRadius ?? this.blurRadius,
      noiseReduction: noiseReduction ?? this.noiseReduction,
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'contrast': contrast,
      'brightness': brightness,
      'saturation': saturation,
      'blurRadius': blurRadius,
      'noiseReduction': noiseReduction,
    };
  }

  String toJson() => json.encode(toMap());

  @override
  String toString() {
    return 'BeautyFilter( contrast: $contrast, brightness: $brightness, saturation: $saturation, blurRadius: $blurRadius, noiseReduction: $noiseReduction)';
  }

  @override
  bool operator ==(covariant BeautyFilter other) {
    if (identical(this, other)) return true;

    return other.contrast == contrast &&
        other.brightness == brightness &&
        other.saturation == saturation &&
        other.blurRadius == blurRadius &&
        other.noiseReduction == noiseReduction;
  }

  @override
  int get hashCode {
    return contrast.hashCode ^
        brightness.hashCode ^
        saturation.hashCode ^
        blurRadius.hashCode ^
        noiseReduction.hashCode;
  }
}

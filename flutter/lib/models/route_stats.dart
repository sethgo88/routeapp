class RouteStats {
  final double distanceKm;
  final double gainM;
  final double lossM;

  const RouteStats({
    required this.distanceKm,
    required this.gainM,
    required this.lossM,
  });

  Map<String, dynamic> toJson() => {
        'distanceKm': distanceKm,
        'gainM': gainM,
        'lossM': lossM,
      };

  factory RouteStats.fromJson(Map<String, dynamic> json) => RouteStats(
        distanceKm: (json['distanceKm'] as num).toDouble(),
        gainM: (json['gainM'] as num).toDouble(),
        lossM: (json['lossM'] as num).toDouble(),
      );
}

/// Represents a mock plant item on the indoor navigation map.
class MockPlantInfo {
  final String plantId;
  final String plantName;
  final double coordinateX;
  final double coordinateY;

  const MockPlantInfo({
    required this.plantId,
    required this.plantName,
    required this.coordinateX,
    required this.coordinateY,
  });
}

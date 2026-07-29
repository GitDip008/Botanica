import 'package:botanica_ar/models/mock_plant.dart';

/// Service to handle plant metadata and discovery queries.
class PlantService {
  /// Simulates a network call to fetch nearby plant locations within the greenhouse.
  Future<List<MockPlantInfo>> fetchNearbyPlants() async {
    // Simulate a 1.2-second network latency delay.
    await Future.delayed(const Duration(milliseconds: 1200));

    return const [
      MockPlantInfo(
        plantId: '101',
        plantName: 'Monstera Deliciosa',
        coordinateX: -135.2031,
        coordinateY: 8.9552,
      ),
      MockPlantInfo(
        plantId: '102',
        plantName: 'Fiddle Leaf Fig',
        coordinateX: -131.8921,
        coordinateY: 15.0008,
      ),
      MockPlantInfo(
        plantId: '103',
        plantName: 'Snake Plant',
        coordinateX: -138.7172,
        coordinateY: 9.9832,
      ),
      MockPlantInfo(
        plantId: '104',
        plantName: 'Golden Pothos',
        coordinateX: -128.8454,
        coordinateY: 9.6185,
      ),
      MockPlantInfo(
        plantId: '105',
        plantName: 'ZZ Plant',
        coordinateX: -125.0599,
        coordinateY: 8.1888,
      ),
    ];
  }

  /// Simulates a network call to update a plant's location in the database.
  Future<bool> editPlantInformationById(
    String plantId,
    double newX,
    double newY,
  ) async {
    // Simulate a network delay of 800 milliseconds.
    await Future.delayed(const Duration(milliseconds: 800));
    print('Mock API Call: Plant $plantId location updated to ($newX, $newY)');
    return true;
  }
}

import '../../models/consumer_model.dart';
import '../../models/meter_model.dart';
import '../../models/route_model.dart';
import '../../models/user_model.dart';

/// Comprehensive fake seed dataset reflecting Pakistani DISCO topography (FR-46, FR-49).
class SeedData {
  SeedData._();

  static List<UserModel> get defaultUsers => [
    const UserModel(
      id: 'USR-READER-01',
      name: 'Muhammad Tariq',
      mobile: '03004567891',
      role: UserRole.reader,
      discoCode: 'LESCO',
      assignedRouteIds: ['RT-LESCO-04', 'RT-IESCO-02'],
    ),
    const UserModel(
      id: 'USR-SUPERVISOR-01',
      name: 'Engr. Nadir Ahmad (SDO)',
      mobile: '03219876543',
      role: UserRole.supervisor,
      discoCode: 'LESCO',
      assignedRouteIds: ['RT-LESCO-04', 'RT-IESCO-02', 'RT-FESCO-08'],
    ),
    const UserModel(
      id: 'USR-ADMIN-01',
      name: 'Muhammad Ans (AI Lead)',
      mobile: '03331122334',
      role: UserRole.admin,
      discoCode: 'LESCO',
      assignedRouteIds: ['RT-LESCO-04', 'RT-IESCO-02', 'RT-FESCO-08'],
    ),
  ];

  static List<RouteModel> get defaultRoutes => [
    const RouteModel(
      id: 'RT-LESCO-04',
      name: 'Gulberg III & Mini Market Commercial',
      batchNo: '04',
      subdivision: 'SD-11234 (Gulberg Sub-Division)',
      discoCode: 'LESCO (Lahore)',
      readerId: 'USR-READER-01',
    ),
    const RouteModel(
      id: 'RT-IESCO-02',
      name: 'Sector F-7 / Blue Area Executive',
      batchNo: '02',
      subdivision: 'SD-22109 (Islamabad West)',
      discoCode: 'IESCO (Islamabad)',
      readerId: 'USR-READER-01',
    ),
    const RouteModel(
      id: 'RT-FESCO-08',
      name: 'Peoples Colony & D-Ground Industrial',
      batchNo: '08',
      subdivision: 'SD-33401 (Faisalabad Central)',
      discoCode: 'FESCO (Faisalabad)',
      readerId: 'USR-READER-01',
    ),
  ];

  /// Generates a rich dataset of 60+ realistic consumers with varied meters and consumption patterns.
  static List<ConsumerModel> generateSeedConsumers() {
    final consumers = <ConsumerModel>[];

    final firstNames = [
      'Abdul', 'Muhammad', 'Sheikh', 'Malik', 'Chaudhry', 'Syed', 'Mian', 'Rana', 'Haji', 'Dr.'
    ];
    final lastNames = [
      'Rehman', 'Tariq', 'Farooq', 'Rashid', 'Akram', 'Nawaz', 'Bashir', 'Iqbal', 'Sultan', 'Javed',
      'Bilal', 'Zubair', 'Hamza', 'Munir', 'Shahid', 'Afzal', 'Kamran', 'Saleem', 'Arshad', 'Waqas'
    ];

    final streetTemplates = [
      'House #, Street 4, Block K, Gulberg III, Lahore',
      'Flat #, Al-Hafeez Heights, Ghalib Market, Lahore',
      'Plot #, Main Boulevard, Gulberg, Lahore',
      'Bungalow #, Street 18, Sector F-7/2, Islamabad',
      'Office #, Fazal-e-Haq Road, Blue Area, Islamabad',
      'Kothi #, Street 9, Peoples Colony No. 1, Faisalabad',
      'Shop #, D-Ground Commercial Market, Faisalabad',
      'Haveli #, Millat Town, Sargodha Road, Faisalabad',
    ];

    final tariffTiers = ['Domestic', 'Commercial', 'Industrial', 'Agriculture'];

    int consumerCounter = 1;
    for (int routeIdx = 0; routeIdx < defaultRoutes.length; routeIdx++) {
      final route = defaultRoutes[routeIdx];
      final countForRoute = 25; // 25 consumers per route = 75 consumers total

      for (int i = 0; i < countForRoute; i++) {
        final fName = firstNames[(consumerCounter * 3) % firstNames.length];
        final lName = lastNames[(consumerCounter * 7) % lastNames.length];
        final fullName = '$fName $lName';
        
        final refNum = '${route.batchNo}-${route.subdivision.substring(3, 8)}-${consumerCounter.toString().padLeft(7, '0')} U';
        final address = streetTemplates[(consumerCounter) % streetTemplates.length].replaceAll('#', '${(consumerCounter * 7) % 190 + 1}');
        final tariff = tariffTiers[i % 4 == 0 ? 1 : 0]; // 75% domestic, 25% commercial
        
        // Realistic previous readings
        final baseReading = 12000.0 + (consumerCounter * 450.0);
        
        // Historical 6-month monthly readings
        final avgMonthly = (tariff == 'Commercial') ? 480.0 : 160.0 + (i % 5) * 35.0;
        final history = [
          avgMonthly - 15.0,
          avgMonthly + 20.0,
          avgMonthly - 10.0,
          avgMonthly + 35.0,
          avgMonthly - 5.0,
          avgMonthly + 10.0,
        ];

        consumers.add(ConsumerModel(
          id: 'CON-${consumerCounter.toString().padLeft(4, '0')}',
          referenceNo: refNum,
          name: fullName,
          address: address,
          tariffCategory: tariff,
          connectedLoadKw: (tariff == 'Commercial') ? 15.0 : 3.0,
          lat: 31.5204 + (consumerCounter * 0.0012),
          lng: 74.3587 + (consumerCounter * 0.0015),
          routeId: route.id,
          meterId: 'MTR-${consumerCounter.toString().padLeft(4, '0')}',
          previousReading: baseReading,
          previousDate: '2026-09-14',
          past6MonthsConsumption: history,
        ));

        consumerCounter++;
      }
    }

    return consumers;
  }

  /// Generates corresponding meter hardware models.
  static List<MeterModel> generateSeedMeters(List<ConsumerModel> consumers) {
    return consumers.map((c) {
      final idx = int.tryParse(c.id.replaceAll('CON-', '')) ?? 1;
      final mType = (idx % 8 == 0)
          ? MeterType.analogDrum
          : (idx % 12 == 0)
              ? MeterType.threePhase
              : MeterType.digitalLcd;

      final mPrefix = (idx % 3 == 0) ? 'PK-MTI' : (idx % 3 == 1) ? 'PK-PEL' : 'PK-ACC';

      return MeterModel(
        id: c.meterId,
        consumerId: c.id,
        meterNo: '$mPrefix-${(740000 + idx * 137).toString()}',
        meterType: mType,
        phase: (mType == MeterType.threePhase) ? 'three' : 'single',
        digits: (mType == MeterType.analogDrum) ? 5 : 6,
        decimals: 1,
        multiplier: (mType == MeterType.threePhase) ? 10.0 : 1.0,
        touEnabled: mType == MeterType.threePhase,
        installedOn: '2021-06-10',
        status: 'normal',
      );
    }).toList();
  }
}

import 'package:flutter_test/flutter_test.dart';
import 'package:disco_meter_reader/models/ai_inference_result.dart';
import 'package:disco_meter_reader/models/consumer_model.dart';
import 'package:disco_meter_reader/models/meter_model.dart';
import 'package:disco_meter_reader/models/validation_result.dart';
import 'package:disco_meter_reader/services/validation/rule_engine_service.dart';

void main() {
  group('Phase-1 Rule Engine Tests (Section P1.3)', () {
    late RuleEngineService engine;
    late MeterModel standardMeter;
    late ConsumerModel standardConsumer;

    setUp(() {
      engine = RuleEngineService();
      standardMeter = const MeterModel(
        id: 'MTR-001',
        consumerId: 'CON-001',
        meterNo: 'PK-MTI-100234',
        meterType: MeterType.digitalLcd,
        digits: 5,
        decimals: 1,
        multiplier: 1.0,
        installedOn: '2022-01-01',
      );

      standardConsumer = const ConsumerModel(
        id: 'CON-001',
        referenceNo: '04-11234-0001010 U',
        name: 'Bashir Ahmed',
        address: 'House 14, Gulberg III, Lahore',
        tariffCategory: 'Domestic',
        connectedLoadKw: 3.0,
        lat: 31.52,
        lng: 74.35,
        routeId: 'RT-LESCO-04',
        meterId: 'MTR-001',
        previousReading: 12000.0,
        previousDate: '2026-09-14',
        past6MonthsConsumption: [180, 200, 190, 210, 195, 205], // Avg ~ 196.6 kWh
      );
    });

    test('Rule A & B: Normal clean reading produces GREEN traffic light', () {
      const aiResult = AiInferenceResult(
        status: 'ok',
        readingText: '12185.4',
        readingValue: 12185.4,
        digitConfidences: [0.98, 0.97, 0.99, 0.96, 0.95, 0.94],
        overallConfidence: 0.96,
        displayBox: DisplayBox(x: 100, y: 100, w: 200, h: 80),
        meterTypeGuess: 'digital_lcd',
        registerGuess: 'kWh',
        qualityFlags: [],
        modelVersion: 'detector-v0.3',
        inferenceMs: 1200,
      );

      final res = engine.evaluate(
        aiResult: aiResult,
        meter: standardMeter,
        consumer: standardConsumer,
        currentReading: 12185.4,
      );

      expect(res.trafficLight, equals(TrafficLight.green));
      expect(res.isGreen, isTrue);
    });

    test('Rule B: Weak digit confidence produces AMBER traffic light', () {
      const aiResult = AiInferenceResult(
        status: 'ok',
        readingText: '12185.4',
        readingValue: 12185.4,
        digitConfidences: [0.98, 0.97, 0.99, 0.68, 0.95, 0.94], // 0.68 is weak (< 0.70)
        overallConfidence: 0.75,
        displayBox: DisplayBox(x: 100, y: 100, w: 200, h: 80),
        meterTypeGuess: 'digital_lcd',
        registerGuess: 'kWh',
        qualityFlags: ['glare'],
        modelVersion: 'detector-v0.3',
        inferenceMs: 1200,
      );

      final res = engine.evaluate(
        aiResult: aiResult,
        meter: standardMeter,
        consumer: standardConsumer,
        currentReading: 12185.4,
      );

      expect(res.trafficLight, anyOf(equals(TrafficLight.amber), equals(TrafficLight.red)));
    });

    test('Rule C: Lower reading without rollover flag produces AMBER', () {
      const aiResult = AiInferenceResult(
        status: 'ok',
        readingText: '11500.0', // Lower than 12000.0
        readingValue: 11500.0,
        digitConfidences: [0.98, 0.97, 0.99, 0.96, 0.95, 0.94],
        overallConfidence: 0.95,
        displayBox: DisplayBox(x: 100, y: 100, w: 200, h: 80),
        meterTypeGuess: 'digital_lcd',
        registerGuess: 'kWh',
        qualityFlags: [],
        modelVersion: 'detector-v0.3',
        inferenceMs: 1200,
      );

      final res = engine.evaluate(
        aiResult: aiResult,
        meter: standardMeter,
        consumer: standardConsumer,
        currentReading: 11500.0,
      );

      expect(res.trafficLight, equals(TrafficLight.amber));
    });

    test('Rule D: Consumption spike > 3x average produces AMBER', () {
      // Avg is ~196.6 -> 3x is ~590 -> current reading with 850 units consumed
      const aiResult = AiInferenceResult(
        status: 'ok',
        readingText: '12850.0',
        readingValue: 12850.0,
        digitConfidences: [0.99, 0.98, 0.97, 0.96, 0.98, 0.95],
        overallConfidence: 0.97,
        displayBox: DisplayBox(x: 100, y: 100, w: 200, h: 80),
        meterTypeGuess: 'digital_lcd',
        registerGuess: 'kWh',
        qualityFlags: [],
        modelVersion: 'detector-v0.3',
        inferenceMs: 1200,
      );

      final res = engine.evaluate(
        aiResult: aiResult,
        meter: standardMeter,
        consumer: standardConsumer,
        currentReading: 12850.0,
      );

      expect(res.trafficLight, equals(TrafficLight.amber));
      expect(res.isConsumptionSpike, isTrue);
    });

    test('Rule E: Suspicious zero units on high active consumer produces AMBER', () {
      const aiResult = AiInferenceResult(
        status: 'ok',
        readingText: '12000.0', // Exactly equal to previous reading
        readingValue: 12000.0,
        digitConfidences: [0.99, 0.98, 0.97, 0.96, 0.98, 0.95],
        overallConfidence: 0.97,
        displayBox: DisplayBox(x: 100, y: 100, w: 200, h: 80),
        meterTypeGuess: 'digital_lcd',
        registerGuess: 'kWh',
        qualityFlags: [],
        modelVersion: 'detector-v0.3',
        inferenceMs: 1200,
      );

      final res = engine.evaluate(
        aiResult: aiResult,
        meter: standardMeter,
        consumer: standardConsumer,
        currentReading: 12000.0,
      );

      expect(res.trafficLight, equals(TrafficLight.amber));
      expect(res.isSuspiciousZero, isTrue);
    });

    test('Rule F: Missing digit / order of magnitude jump produces RED', () {
      const aiResult = AiInferenceResult(
        status: 'ok',
        readingText: '1200.0', // 1200 instead of 12000 (10x ratio jump)
        readingValue: 1200.0,
        digitConfidences: [0.95, 0.94, 0.93, 0.91],
        overallConfidence: 0.93,
        displayBox: DisplayBox(x: 100, y: 100, w: 200, h: 80),
        meterTypeGuess: 'digital_lcd',
        registerGuess: 'kWh',
        qualityFlags: ['cropped'],
        modelVersion: 'detector-v0.3',
        inferenceMs: 1200,
      );

      final res = engine.evaluate(
        aiResult: aiResult,
        meter: standardMeter,
        consumer: standardConsumer,
        currentReading: 1200.0,
      );

      expect(res.trafficLight, equals(TrafficLight.red));
    });
  });
}

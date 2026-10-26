import 'dart:convert';

import 'package:flutter_driver/flutter_driver.dart';
import 'package:test/test.dart' hide TypeMatcher, isInstanceOf;

void main() {
  group('xue_hua_navite_share example (flutter_driver)', () {
    late FlutterDriver driver;

    setUpAll(() async {
      driver = await FlutterDriver.connect();
    });

    tearDownAll(() async {
      await driver.close();
    });

    Future<void> scrollActionsIntoView() async {
      // Share action buttons live below the fold in the ListView.
      await driver.scrollUntilVisible(
        find.byType('ListView'),
        find.byValueKey('btn_share_text'),
        dyScroll: -120,
        timeout: const Duration(seconds: 15),
      );
    }

    test('workbench renders and capabilities load', () async {
      await driver.waitFor(find.byValueKey('app_bar_title'));
      expect(
        await driver.getText(find.byValueKey('app_bar_title')),
        'XueHua Native Share Workbench',
      );

      final capsRaw = await driver.requestData('capabilities');
      final caps = jsonDecode(capsRaw) as Map<String, dynamic>;
      expect(caps['platform']?.toString().toLowerCase(), contains('linux'));
      expect(caps['supportsSystemShareSheet'], isTrue);
      expect(caps['supportsFileSharing'], isTrue);
      expect(caps['supportsMemoryBytesSharing'], isTrue);
      expect(caps['supportsTargetedServices'], isTrue);
      final services = (caps['availableServices'] as List)
          .map((e) => e.toString())
          .toList();
      expect(services, contains('systemClipboard'));
      expect(services, contains('fileExplorer'));
      expect(services, contains('mail'));

      await driver.waitFor(
        find.byValueKey('chip_platform'),
        timeout: const Duration(seconds: 10),
      );
    });

    test('canShare text via DataHandler', () async {
      expect(await driver.requestData('can_share_text'), 'true');
    });

    test('clipboard text + memory + cleanup via DataHandler', () async {
      final clip = jsonDecode(await driver.requestData('clipboard_text'))
          as Map<String, dynamic>;
      expect(clip['status'], anyOf('success', 'fallbackExecuted'));

      final mem = jsonDecode(await driver.requestData('clipboard_memory'))
          as Map<String, dynamic>;
      expect(mem['status'], anyOf('success', 'fallbackExecuted'));

      final cleaned = int.parse(await driver.requestData('cleanup'));
      expect(cleaned, greaterThanOrEqualTo(0));
    });

    test('UI: cleanup button updates diagnostics', () async {
      await driver.scrollUntilVisible(
        find.byType('ListView'),
        find.byValueKey('btn_cleanup_temp_body'),
        dyScroll: -120,
        timeout: const Duration(seconds: 15),
      );
      await driver.tap(find.byValueKey('btn_cleanup_temp_body'));
      await driver.waitFor(
        find.byValueKey('result_cleaned_count'),
        timeout: const Duration(seconds: 15),
      );
      final text =
          await driver.getText(find.byValueKey('result_cleaned_count'));
      expect(text, contains('cleanupTempFiles() removed:'));
    });

    test('UI: empty local paths shows error without native dialog', () async {
      await scrollActionsIntoView();
      await driver.tap(find.byValueKey('btn_share_files'));
      await driver.waitFor(
        find.byValueKey('result_status'),
        timeout: const Duration(seconds: 15),
      );
      final status = await driver.getText(find.byValueKey('result_status'));
      expect(status, contains('error'));
      final message = await driver.getText(find.byValueKey('result_message'));
      expect(message.toLowerCase(), contains('file path'));
    });

    test('UI: Share Text uses clipboard fallback (no mailto handler)', () async {
      // Intentionally skips Share Memory / Share URI with files — those open
      // the blocking GTK AppChooserDialog on Linux.
      await scrollActionsIntoView();
      await driver.tap(find.byValueKey('btn_share_text'));
      await driver.waitFor(
        find.byValueKey('result_status'),
        timeout: const Duration(seconds: 20),
      );
      final status = await driver.getText(find.byValueKey('result_status'));
      expect(
        status.contains('success') || status.contains('fallbackExecuted'),
        isTrue,
        reason: 'unexpected status text: $status',
      );
    });

    test('fileExplorer DataHandler is non-modal and tolerant', () async {
      // Kept last: may briefly open a file manager window via GIO fallback.
      final result = jsonDecode(await driver.requestData('file_explorer'))
          as Map<String, dynamic>;
      expect(
        result['status'],
        anyOf('success', 'unavailable', 'fallbackExecuted'),
      );
      expect(
        int.parse(await driver.requestData('cleanup')),
        greaterThanOrEqualTo(0),
      );
    });
  });
}

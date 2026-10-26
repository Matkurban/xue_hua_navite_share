import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;

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
      await driver.scrollUntilVisible(
        find.byType('ListView'),
        find.byValueKey('btn_share_text'),
        dyScroll: -200,
        timeout: const Duration(seconds: 20),
      );
    }

    Future<String> waitForResultStatusMatching(
      bool Function(String status) predicate, {
      Duration timeout = const Duration(seconds: 25),
    }) async {
      final deadline = DateTime.now().add(timeout);
      Object? lastError;
      String? lastStatus;
      while (DateTime.now().isBefore(deadline)) {
        try {
          final current =
              await driver.getText(find.byValueKey('result_status'));
          lastStatus = current;
          if (predicate(current)) {
            return current;
          }
        } catch (e) {
          lastError = e;
        }
        await Future<void>.delayed(const Duration(milliseconds: 300));
      }
      throw TimeoutException(
        'result_status did not match within $timeout '
        '(lastStatus=$lastStatus lastError=$lastError)',
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
      expect(
        caps['platform']?.toString().toLowerCase(),
        contains(Platform.operatingSystem),
      );
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

    test('systemSheet text via DataHandler (clipboard fallback)', () async {
      final sheet = jsonDecode(await driver.requestData('system_sheet_text'))
          as Map<String, dynamic>;
      expect(sheet['status'], anyOf('success', 'fallbackExecuted'));
    });

    test('UI: cleanup button updates diagnostics', () async {
      await driver.scrollUntilVisible(
        find.byType('ListView'),
        find.byValueKey('btn_cleanup_temp_body'),
        dyScroll: -200,
        timeout: const Duration(seconds: 20),
      );
      await driver.tap(find.byValueKey('btn_cleanup_temp_body'));
      await driver.waitFor(
        find.byValueKey('result_cleaned_count'),
        timeout: const Duration(seconds: 15),
      );
      final text =
          await driver.getText(find.byValueKey('result_cleaned_count'));
      expect(text, contains('cleanupTempFiles() removed:'));
    }, timeout: const Timeout(Duration(seconds: 60)));

    test('UI: Share Text uses clipboard/fallback (non-blocking)', () async {
      // On macOS/iOS, Share Text opens a modal system picker and blocks until
      // the user dismisses it. Cover the same capability via DataHandler.
      if (Platform.isMacOS || Platform.isIOS) {
        final clip = jsonDecode(await driver.requestData('clipboard_text'))
            as Map<String, dynamic>;
        expect(clip['status'], anyOf('success', 'fallbackExecuted'));
        return;
      }
      await scrollActionsIntoView();
      await driver.tap(find.byValueKey('btn_share_text'));
      final status = await waitForResultStatusMatching(
        (s) =>
            s.contains('success') ||
            s.contains('fallbackExecuted') ||
            s.contains('unavailable'),
      );
      expect(
        status.contains('success') ||
            status.contains('fallbackExecuted') ||
            status.contains('unavailable'),
        isTrue,
        reason: 'unexpected status text: $status',
      );
    }, timeout: const Timeout(Duration(seconds: 90)));

    test('UI: empty local paths shows error without native dialog', () async {
      await scrollActionsIntoView();
      await driver.tap(find.byValueKey('btn_share_files'));
      final status = await waitForResultStatusMatching(
        (s) => s.contains('error'),
      );
      expect(status, contains('error'));
      final message = await driver.getText(find.byValueKey('result_message'));
      expect(message.toLowerCase(), contains('file path'));
    }, timeout: const Timeout(Duration(seconds: 90)));

    test('fileExplorer DataHandler is non-modal and tolerant', () async {
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
    }, timeout: const Timeout(Duration(seconds: 60)));
  }, timeout: const Timeout(Duration(minutes: 3)));
}
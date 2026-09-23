import 'package:cashier_app/core/offline/app_mode_cubit.dart';
import 'package:cashier_app/features/shell/presentation/pages/shell_page.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const online = AppModeState();
  const offline = AppModeState(mode: AppMode.offline);

  test('switching between online and offline reloads the shift', () {
    expect(shiftNeedsRefresh(online, offline), isTrue);
    expect(shiftNeedsRefresh(offline, online), isTrue);
  });

  test('a new offline sale reloads the shift so the header takings update', () {
    expect(
      shiftNeedsRefresh(offline, offline.copyWith(pendingCount: 1)),
      isTrue,
    );
  });

  test('pending changes online, or unrelated changes, do not reload', () {
    expect(
      shiftNeedsRefresh(online, online.copyWith(pendingCount: 1)),
      isFalse,
    );
    expect(
      shiftNeedsRefresh(offline, offline.copyWith(failedCount: 1)),
      isFalse,
    );
    expect(
      shiftNeedsRefresh(offline, offline.copyWith(prompt: ModePrompt.goOnline)),
      isFalse,
    );
  });
}

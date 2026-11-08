import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focuslearn_design_system/focuslearn_design_system.dart';

Widget _host(Widget child, {ThemeData? theme}) =>
    MaterialApp(theme: theme ?? AppTheme.light(), home: Scaffold(body: child));

void main() {
  group('AppTheme', () {
    test('light theme uses the token palette', () {
      final t = AppTheme.light();
      expect(t.colorScheme.primary, const Color(0xFF2563EB));
      expect(t.scaffoldBackgroundColor, const Color(0xFFFFFFFF));
      expect(t.colorScheme.brightness, Brightness.light);
    });

    test('dark theme uses the dark palette', () {
      final t = AppTheme.dark();
      expect(t.colorScheme.primary, const Color(0xFF60A5FA));
      expect(t.colorScheme.brightness, Brightness.dark);
    });

    test('body text is at least 16 logical pixels', () {
      expect(AppTheme.light().textTheme.bodyMedium?.fontSize, greaterThanOrEqualTo(16));
    });
  });

  group('AppButton', () {
    testWidgets('calls onPressed when tapped', (tester) async {
      var taps = 0;
      await tester.pumpWidget(_host(AppButton(label: 'Go', onPressed: () => taps++)));
      await tester.tap(find.text('Go'));
      expect(taps, 1);
    });

    testWidgets('ignores taps while loading and shows a progress indicator', (tester) async {
      var taps = 0;
      await tester.pumpWidget(_host(AppButton(label: 'Go', onPressed: () => taps++, loading: true)));
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      await tester.tap(find.byType(FilledButton), warnIfMissed: false);
      expect(taps, 0);
    });

    testWidgets('is disabled without a handler', (tester) async {
      await tester.pumpWidget(_host(const AppButton(label: 'Go', onPressed: null)));
      expect(tester.widget<FilledButton>(find.byType(FilledButton)).onPressed, isNull);
    });

    testWidgets('meets the minimum touch target height', (tester) async {
      await tester.pumpWidget(_host(AppButton(label: 'Go', onPressed: () {})));
      expect(tester.getSize(find.byType(FilledButton)).height, greaterThanOrEqualTo(Sizes.minTouchTarget));
    });

    testWidgets('exposes its label to screen readers even while loading', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(_host(AppButton(label: 'Sign in', onPressed: () {}, loading: true)));
      expect(find.bySemanticsLabel('Sign in'), findsOneWidget);
      handle.dispose();
    });
  });

  group('StatusBanner', () {
    for (final entry in <BannerKind, IconData>{
      BannerKind.info: Icons.info_outline,
      BannerKind.success: Icons.check_circle_outline,
      BannerKind.warning: Icons.warning_amber_outlined,
      BannerKind.error: Icons.error_outline,
    }.entries) {
      testWidgets('${entry.key.name} shows text and its own icon (not colour alone)', (tester) async {
        await tester.pumpWidget(_host(StatusBanner(kind: entry.key, message: 'Hello')));
        expect(find.text('Hello'), findsOneWidget);
        expect(find.byIcon(entry.value), findsOneWidget);
      });
    }

    testWidgets('renders in the dark theme too', (tester) async {
      await tester.pumpWidget(_host(const StatusBanner(kind: BannerKind.error, message: 'Oops'), theme: AppTheme.dark()));
      expect(find.text('Oops'), findsOneWidget);
    });
  });

  group('state views', () {
    testWidgets('ErrorView calls onRetry', (tester) async {
      var retries = 0;
      await tester.pumpWidget(_host(ErrorView(message: 'Failed', retryLabel: 'Try again', onRetry: () => retries++)));
      await tester.tap(find.text('Try again'));
      expect(retries, 1);
    });

    testWidgets('EmptyView shows its title and message', (tester) async {
      await tester.pumpWidget(_host(const EmptyView(title: 'Nothing here', message: 'Add something')));
      expect(find.text('Nothing here'), findsOneWidget);
      expect(find.text('Add something'), findsOneWidget);
    });

    testWidgets('LoadingView announces its label', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(_host(const LoadingView(label: 'Loading your profile')));
      expect(find.bySemanticsLabel('Loading your profile'), findsOneWidget);
      handle.dispose();
    });
  });

  group('AppTextField', () {
    testWidgets('shows a persistent label and an error text', (tester) async {
      final controller = TextEditingController();
      await tester.pumpWidget(_host(AppTextField(controller: controller, label: 'Email', errorText: 'Enter an email')));
      expect(find.text('Email'), findsOneWidget);
      expect(find.text('Enter an email'), findsOneWidget);
    });
  });

  testWidgets('ContentWidth caps the width of its child', (tester) async {
    tester.view.physicalSize = const Size(2000, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(_host(const ContentWidth(child: SizedBox(key: Key('box'), width: double.infinity, height: 10))));
    expect(tester.getSize(find.byKey(const Key('box'))).width, lessThanOrEqualTo(Sizes.maxContentWidth));
  });
}

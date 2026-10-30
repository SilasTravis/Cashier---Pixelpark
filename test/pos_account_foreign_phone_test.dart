import 'package:flutter_test/flutter_test.dart';

import 'package:cashier_app/core/utils/phone_number.dart';
import 'package:cashier_app/features/pos_account/data/pos_account_remote_data_source.dart';
import 'package:cashier_app/features/pos_account/data/pos_account_repository_impl.dart';
import 'package:cashier_app/features/pos_account/domain/customer.dart';
import 'package:cashier_app/features/pos_account/presentation/bloc/pos_account_bloc.dart';

/// In-memory remote: records the phone sent on create; the rest throws.
class _FakeRemote implements PosAccountRemoteDataSource {
  String? createdPhone;

  @override
  Future<Customer> createCustomer({
    required String phoneNumber,
    required String fullName,
  }) async {
    createdPhone = phoneNumber;
    return Customer(
      id: 1,
      phoneNumber: phoneNumber,
      firstName: fullName,
      lastName: null,
      balance: 0,
      children: const [],
    );
  }

  @override
  Future<List<Customer>> searchCustomers(String query, {int page = 1}) async =>
      const [];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Future<void> _type(PosAccountBloc bloc, String digits) async {
  for (final d in digits.split('')) {
    bloc.add(PosAccountDigitPressed(d));
  }
  await Future<void>.delayed(Duration.zero);
}

void main() {
  group('foreign phone at the cashier', () {
    test('Uzbek mode is unchanged: 9 digits, sent as +998…', () async {
      final remote = _FakeRemote();
      final bloc = PosAccountBloc(PosAccountRepository(remote));
      await _type(bloc, '9012345678'); // 10th digit ignored
      expect(bloc.state.phoneDigits, '901234567');
      expect(bloc.state.canCreateWithPhone, isTrue);

      bloc.add(const PosAccountNewCustomerRequested('Ali Valiyev'));
      await Future<void>.delayed(Duration.zero);
      expect(remote.createdPhone, '+998901234567');
      await bloc.close();
    });

    test(
      'foreign mode sends +<country code><number>, up to 15 digits',
      () async {
        final remote = _FakeRemote();
        final bloc = PosAccountBloc(PosAccountRepository(remote));
        await _type(bloc, '90');
        bloc.add(const PosAccountForeignPhoneToggled());
        await Future<void>.delayed(Duration.zero);
        expect(bloc.state.foreignPhone, isTrue);
        expect(bloc.state.phoneDigits, isEmpty, reason: 'toggle clears input');

        await _type(bloc, '79161234567');
        expect(bloc.state.fullPhone, '+79161234567');
        expect(bloc.state.canCreateWithPhone, isTrue);

        bloc.add(const PosAccountNewCustomerRequested('John Smith'));
        await Future<void>.delayed(Duration.zero);
        expect(remote.createdPhone, '+79161234567');
        await bloc.close();
      },
    );

    test('foreign mode refuses a 998… number and too-short numbers', () async {
      final bloc = PosAccountBloc(PosAccountRepository(_FakeRemote()));
      bloc.add(const PosAccountForeignPhoneToggled());
      await _type(bloc, '998901234567');
      expect(bloc.state.canCreateWithPhone, isFalse);
      await bloc.close();

      final short = PosAccountBloc(PosAccountRepository(_FakeRemote()));
      short.add(const PosAccountForeignPhoneToggled());
      await _type(short, '1234567');
      expect(short.state.canCreateWithPhone, isFalse);
      await short.close();
    });
  });

  group('formatPhoneNumber', () {
    test('keeps Uzbek grouping', () {
      expect(formatPhoneNumber('+998901234567'), '+998 90 123 45 67');
      expect(formatPhoneNumber('901234567'), '+998 90 123 45 67');
    });

    test('shows foreign numbers as stored', () {
      expect(formatPhoneNumber('+79161234567'), '+79161234567');
      expect(formatPhoneNumber('+123456789'), '+123456789');
    });
  });
}

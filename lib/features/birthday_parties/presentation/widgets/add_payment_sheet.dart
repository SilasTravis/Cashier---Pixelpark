import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/error/exceptions.dart';
import '../../../../core/theme/pos_palette.dart';
import '../../../../core/utils/currency.dart';
import '../../../../core/widgets/payment_method_selector.dart';
import '../../../../generated/l10n.dart';
import '../../../../injector_container.dart';
import '../../../pos_account/data/pos_account_repository_impl.dart';
import '../../data/birthday_parties_repository.dart';
import '../../domain/birthday_party.dart';
import '../../domain/birthday_payment.dart';
import '../birthday_error_text.dart';
import 'birthday_payment_block.dart';

/// "+ To'lov qo'shish": takes (part of) the remaining debt. Resolves with the
/// updated party, null when closed. The amount starts at the whole debt and
/// can never exceed it.
Future<BirthdayParty?> showAddPaymentSheet(
  BuildContext context,
  BirthdayParty party,
) {
  final theme = Theme.of(context);
  return showDialog<BirthdayParty>(
    context: context,
    barrierDismissible: false,
    builder: (_) => Theme(
      data: theme,
      child: AddPaymentSheet(party: party),
    ),
  );
}

class AddPaymentSheet extends StatefulWidget {
  const AddPaymentSheet({super.key, required this.party});

  final BirthdayParty party;

  @override
  State<AddPaymentSheet> createState() => _AddPaymentSheetState();
}

class _AddPaymentSheetState extends State<AddPaymentSheet> {
  /// Fixed for the life of the sheet: a retry after a timeout is the same
  /// payment on the server and never charges twice.
  final _requestId = const Uuid().v4();
  late final _amount = TextEditingController(
    text: groupDigits(widget.party.debtUzs),
  );
  final _cash = TextEditingController();
  final _card = TextEditingController();
  int _balance = 0;
  bool _payFromBalance = false;
  PaymentMethod _method = PaymentMethod.cash;
  bool _busy = false;
  String? _errorCode;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadBalance();
  }

  @override
  void dispose() {
    _amount.dispose();
    _cash.dispose();
    _card.dispose();
    super.dispose();
  }

  Future<void> _loadBalance() async {
    try {
      final result = await sl<PosAccountRepository>().searchCustomers(
        widget.party.customerPhone,
      );
      final balance = result.fold<int?>(
        (_) => null,
        (list) => list
            .where((c) => c.id == widget.party.customerId)
            .firstOrNull
            ?.balance,
      );
      if (balance != null && mounted) setState(() => _balance = balance);
    } catch (_) {
      // No balance known: the cashier can still take cash / card.
    }
  }

  int get _amountUzs => parseUzs(_amount.text) ?? 0;

  BirthdayPayment get _payment => BirthdayPayment.compute(
    dueUzs: widget.party.debtUzs,
    balanceUzs: _balance,
    deposit: true,
    depositUzs: _amountUzs,
    payFromBalance: _payFromBalance,
    method: _method,
    cashInput: _cash.text,
    cardInput: _card.text,
  );

  bool get _overDebt => _amountUzs > widget.party.debtUzs;

  bool get _canSubmit =>
      !_busy && _amountUzs > 0 && !_overDebt && _payment.isValid;

  Future<void> _submit() async {
    if (!_canSubmit) return;
    final money = _payment.money;
    setState(() {
      _busy = true;
      _errorCode = null;
      _errorMessage = null;
    });
    try {
      final party = await sl<BirthdayPartiesRepository>().pay(
        widget.party.id,
        money,
        _requestId,
      );
      if (mounted) Navigator.of(context).pop(party);
    } on ServerException catch (e) {
      if (mounted) {
        setState(() {
          _busy = false;
          _errorCode = e.code ?? 'UNKNOWN';
          _errorMessage = e.message;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _busy = false;
          _errorCode = 'UNKNOWN';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalization.of(context);
    final p = PosPalette.of(context);
    final party = widget.party;
    return Dialog(
      insetPadding: const EdgeInsets.all(24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 20),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(l10n.bdPayTitle, style: p.title.copyWith(fontSize: 19)),
                const SizedBox(height: 2),
                Text(party.customerName, style: p.bodyMuted),
                const SizedBox(height: 14),
                _remaining(p, l10n, party.debtUzs),
                const SizedBox(height: 14),
                TextField(
                  key: const ValueKey('bd-pay-amount'),
                  controller: _amount,
                  keyboardType: TextInputType.number,
                  inputFormatters: const [ThousandsInputFormatter()],
                  decoration: InputDecoration(
                    labelText: l10n.bdPayAmount,
                    errorText: _overDebt ? l10n.bdPayOverDebt : null,
                  ),
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 12),
                BirthdayPaymentBlock(
                  payment: _payment,
                  balanceUzs: _balance,
                  payFromBalance: _payFromBalance,
                  onPayFromBalance: (v) => setState(() => _payFromBalance = v),
                  method: _method,
                  onMethod: (m) => setState(() => _method = m),
                  cashController: _cash,
                  cardController: _card,
                  onChanged: () => setState(() {}),
                ),
                if (_errorCode != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    key: const ValueKey('bd-pay-error'),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 9,
                    ),
                    decoration: BoxDecoration(
                      color: p.dangerSoft,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      birthdayErrorText(l10n, _errorCode, _errorMessage),
                      style: TextStyle(color: p.danger, fontSize: 13),
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: SizedBox(
                        height: 52,
                        child: OutlinedButton(
                          onPressed: _busy
                              ? null
                              : () => Navigator.of(context).pop(),
                          child: Text(l10n.cancel),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 4,
                      child: SizedBox(
                        height: 52,
                        child: FilledButton(
                          key: const ValueKey('bd-pay-submit'),
                          onPressed: _canSubmit ? _submit : null,
                          child: _busy
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Text(l10n.bdPaySubmit),
                                ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _remaining(PosPalette p, AppLocalization l10n, int debt) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    decoration: BoxDecoration(
      color: p.warningSoft,
      borderRadius: BorderRadius.circular(14),
    ),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(l10n.bdLeft, style: p.heading.copyWith(color: p.warning)),
        Text(
          formatUzs(debt),
          style: p.title.copyWith(fontSize: 22, color: p.warning),
        ),
      ],
    ),
  );
}

import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/error/exceptions.dart';
import '../../../../core/theme/pos_palette.dart';
import '../../../../core/utils/currency.dart';
import '../../../../core/widgets/payment_method_selector.dart';
import '../../../../generated/l10n.dart';
import '../../../../injector_container.dart';
import '../../data/birthday_parties_repository.dart';
import '../../domain/birthday_party.dart';
import '../../domain/birthday_payment.dart';
import '../birthday_error_text.dart';
import '../birthday_recovery.dart';
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
  bool _balanceFailed = false;

  /// The last submit ended without a clear answer: the payment may exist. The
  /// amounts stay locked to [_pendingMoney] and only the same requestId is
  /// retried.
  bool _unclear = false;
  BirthdayMoney? _pendingMoney;
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
    final balance = await lookupCustomerBalance(
      widget.party.customerId,
      widget.party.customerPhone,
    );
    if (!mounted) return;
    setState(() {
      if (balance == null) {
        _balanceFailed = true;
        _payFromBalance = false;
      } else {
        _balance = balance;
      }
    });
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
    // After an unclear failure the very same money is retried.
    final money = _pendingMoney ?? _payment.money;
    setState(() {
      _busy = true;
      _errorCode = null;
      _errorMessage = null;
    });
    final repo = sl<BirthdayPartiesRepository>();
    try {
      final party = await repo.pay(widget.party.id, money, _requestId);
      if (mounted) Navigator.of(context).pop(party);
    } catch (error) {
      if (!mounted) return;
      final code = error is ServerException ? error.code : null;
      final message = error is ServerException ? error.message : null;
      if (isUnclearFailure(error)) {
        // The response may have been lost after the server took the money.
        final fresh = await refetchParty(repo, widget.party.id);
        if (!mounted) return;
        if (fresh != null && paymentReflected(widget.party, fresh, money)) {
          Navigator.of(context).pop(fresh);
          return;
        }
        setState(() {
          _busy = false;
          _unclear = true;
          _pendingMoney = money;
          _errorCode = code ?? 'UNKNOWN';
          _errorMessage = message;
        });
        return;
      }
      setState(() {
        _busy = false;
        _errorCode = code ?? 'UNKNOWN';
        _errorMessage = message;
      });
    }
  }

  /// Closing after an unclear failure first re-reads the party: the payment
  /// may have landed after all (then it counts and its receipt prints).
  Future<void> _close() async {
    final navigator = Navigator.of(context);
    if (!_unclear) {
      navigator.pop();
      return;
    }
    setState(() => _busy = true);
    final fresh = await refetchParty(
      sl<BirthdayPartiesRepository>(),
      widget.party.id,
    );
    final money = _pendingMoney;
    final landed =
        fresh != null &&
        money != null &&
        paymentReflected(widget.party, fresh, money);
    if (mounted) navigator.pop(landed ? fresh : null);
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
                  enabled: !_unclear,
                  keyboardType: TextInputType.number,
                  inputFormatters: const [ThousandsInputFormatter()],
                  decoration: InputDecoration(
                    labelText: l10n.bdPayAmount,
                    errorText: _overDebt ? l10n.bdPayOverDebt : null,
                  ),
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 12),
                IgnorePointer(
                  ignoring: _unclear,
                  child: Opacity(
                    opacity: _unclear ? 0.55 : 1,
                    child: BirthdayPaymentBlock(
                      payment: _payment,
                      balanceUnknown: _balanceFailed,
                      balanceUzs: _balance,
                      payFromBalance: _payFromBalance,
                      onPayFromBalance: (v) =>
                          setState(() => _payFromBalance = v),
                      method: _method,
                      onMethod: (m) => setState(() => _method = m),
                      cashController: _cash,
                      cardController: _card,
                      onChanged: () => setState(() {}),
                    ),
                  ),
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
                  if (_unclear) ...[
                    const SizedBox(height: 6),
                    Text(
                      l10n.bdUnclearHint,
                      key: const ValueKey('bd-pay-unclear-hint'),
                      style: p.bodyMuted.copyWith(fontSize: 12.5),
                    ),
                  ],
                ],
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: SizedBox(
                        height: 52,
                        child: OutlinedButton(
                          key: const ValueKey('bd-pay-close'),
                          onPressed: _busy ? null : _close,
                          child: Text(_unclear ? l10n.bdClose : l10n.cancel),
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
                                  child: Text(
                                    _unclear
                                        ? l10n.eventsRetry
                                        : l10n.bdPaySubmit,
                                  ),
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

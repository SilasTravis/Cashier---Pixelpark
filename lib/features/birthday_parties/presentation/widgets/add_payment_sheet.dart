import 'package:flutter/material.dart';
import 'package:phosphor_icons/phosphor_icons.dart';
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
import '../../domain/birthday_plan.dart';
import '../../domain/birthday_wallet.dart';
import '../birthday_error_text.dart';
import '../birthday_recovery.dart';
import 'birthday_payment_block.dart';
import 'birthday_ui.dart';

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

  /// What of the balance may pay (real money only); null while loading or
  /// when the lookup failed.
  BirthdayWallet? _wallet;
  bool _walletLoading = true;
  bool _payFromBalance = false;
  PaymentMethod _method = PaymentMethod.cash;
  bool _busy = false;

  /// The close re-check could not reach the server: the sheet stays locked.
  bool _offline = false;

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
    _loadWallet();
  }

  @override
  void dispose() {
    _amount.dispose();
    _cash.dispose();
    _card.dispose();
    super.dispose();
  }

  /// Reads the birthday wallet. A failed first read leaves the switch off
  /// and disabled; a failed re-read (after a balance refusal) keeps the last
  /// known wallet.
  Future<void> _loadWallet({bool refresh = false}) async {
    BirthdayWallet? wallet;
    try {
      wallet = await sl<BirthdayPartiesRepository>().wallet(
        widget.party.customerId,
      );
    } catch (_) {
      wallet = null;
    }
    if (!mounted) return;
    setState(() {
      _walletLoading = false;
      if (wallet != null) {
        _wallet = wallet;
      } else if (!refresh) {
        _wallet = null;
      }
      if ((_wallet?.usableUzs ?? 0) <= 0) _payFromBalance = false;
    });
  }

  int get _amountUzs => parseUzs(_amount.text) ?? 0;

  BirthdayPayment get _payment => BirthdayPayment.compute(
    dueUzs: widget.party.debtUzs,
    balanceUzs: _wallet?.usableUzs ?? 0,
    deposit: true,
    depositUzs: _amountUzs,
    payFromBalance: _payFromBalance,
    method: _method,
    cashInput: _cash.text,
    cardInput: _card.text,
  );

  bool get _overDebt => _amountUzs > widget.party.debtUzs;

  bool get _canSubmit =>
      !_busy &&
      !_walletLoading &&
      _amountUzs > 0 &&
      !_overDebt &&
      _payment.isValid;

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
        if (fresh != null &&
            paymentReflected(
              widget.party,
              fresh,
              money,
              requestId: _requestId,
            )) {
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
      // A clean refusal — also of a retry: a payment already taken under this
      // requestId would have replayed as a success — so nothing was charged
      // and the amounts are editable again.
      setState(() {
        _busy = false;
        _unclear = false;
        _pendingMoney = null;
        _offline = false;
        _errorCode = code ?? 'UNKNOWN';
        _errorMessage = message;
      });
      // The balance shown was stale: show the real one.
      if (code == 'BIRTHDAY_BALANCE_INSUFFICIENT') {
        await _loadWallet(refresh: true);
      }
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
    setState(() {
      _busy = true;
      _offline = false;
    });
    final lookup = await lookupPartySettled(
      sl<BirthdayPartiesRepository>(),
      widget.party.id,
    );
    if (!mounted) return;
    if (lookup is PartyUnreachable) {
      // Cannot tell whether the payment landed: keep the sheet locked.
      setState(() {
        _busy = false;
        _offline = true;
      });
      return;
    }
    final money = _pendingMoney;
    final landed =
        lookup is PartyFound &&
        money != null &&
        paymentReflected(
          widget.party,
          lookup.party,
          money,
          requestId: _requestId,
        );
    navigator.pop(landed ? (lookup).party : null);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalization.of(context);
    final p = PosPalette.of(context);
    final party = widget.party;
    final tier = colorOf(party.planColor, p.accent);
    return Dialog(
      insetPadding: const EdgeInsets.all(24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 540),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(26, 22, 26, 22),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: p.accentSoft,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(
                        PhosphorIconsRegular.handCoins,
                        size: 22,
                        color: p.accent,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l10n.bdPayTitle,
                            style: p.title.copyWith(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          Text(
                            party.customerLabel,
                            overflow: TextOverflow.ellipsis,
                            style: tabular(p.bodyMuted.copyWith(fontSize: 13)),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: tierTint(context, tier, strength: 1.4),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        '${party.planName} · ${partyDateLabel(party.partyDate)}',
                        style: tabular(
                          p.body.copyWith(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            color: tierInk(context, tier),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                _remaining(p, l10n, party.debtUzs),
                const SizedBox(height: 16),
                TextField(
                  key: const ValueKey('bd-pay-amount'),
                  controller: _amount,
                  enabled: !_unclear,
                  keyboardType: TextInputType.number,
                  inputFormatters: const [ThousandsInputFormatter()],
                  style: tabular(
                    p.heading.copyWith(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  decoration: InputDecoration(
                    labelText: l10n.bdPayAmount,
                    suffixText: "so'm",
                    errorText: _overDebt ? l10n.bdPayOverDebt : null,
                  ),
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 14),
                // Locked after an unclear failure: no clicks and no keyboard
                // (a split field may still have had focus).
                ExcludeFocus(
                  excluding: _unclear,
                  child: IgnorePointer(
                    ignoring: _unclear,
                    child: Opacity(
                      opacity: _unclear ? 0.55 : 1,
                      child: BirthdayPaymentBlock(
                        payment: _payment,
                        wallet: _wallet,
                        walletLoading: _walletLoading,
                        payFromBalance: _payFromBalance,
                        onPayFromBalance: (v) => setState(
                          () => _payFromBalance =
                              v && (_wallet?.usableUzs ?? 0) > 0,
                        ),
                        method: _method,
                        onMethod: (m) => setState(() => _method = m),
                        cashController: _cash,
                        cardController: _card,
                        onChanged: () => setState(() {}),
                      ),
                    ),
                  ),
                ),
                if (_errorCode != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    key: const ValueKey('bd-pay-error'),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 11,
                    ),
                    decoration: BoxDecoration(
                      color: p.dangerSoft,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Text(
                      birthdayErrorText(l10n, _errorCode, _errorMessage),
                      style: TextStyle(color: p.danger, fontSize: 13.5),
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
                if (_offline) ...[
                  const SizedBox(height: 6),
                  Text(
                    l10n.bdOfflineHint,
                    key: const ValueKey('bd-pay-offline-hint'),
                    style: TextStyle(color: p.danger, fontSize: 12.5),
                  ),
                ],
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: SizedBox(
                        height: 54,
                        child: OutlinedButton(
                          key: const ValueKey('bd-pay-close'),
                          onPressed: _busy ? null : _close,
                          style: OutlinedButton.styleFrom(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child: Text(_unclear ? l10n.bdClose : l10n.cancel),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 4,
                      child: SizedBox(
                        height: 54,
                        child: FilledButton(
                          key: const ValueKey('bd-pay-submit'),
                          onPressed: _canSubmit ? _submit : null,
                          style: FilledButton.styleFrom(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child: _busy
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
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
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    decoration: BoxDecoration(
      color: p.warningSoft,
      borderRadius: BorderRadius.circular(16),
    ),
    child: Row(
      children: [
        Icon(PhosphorIconsRegular.hourglassMedium, size: 20, color: p.warning),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            l10n.bdLeft,
            style: p.heading.copyWith(fontSize: 15, color: p.warning),
          ),
        ),
        Text(
          formatUzs(debt),
          style: tabular(
            p.title.copyWith(
              fontSize: 26,
              fontWeight: FontWeight.w800,
              color: p.warning,
            ),
          ),
        ),
      ],
    ),
  );
}

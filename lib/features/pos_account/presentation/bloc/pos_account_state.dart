part of 'pos_account_bloc.dart';

/// The server's quote for switching the panel's selected children onto the
/// selected plan — what lets an upgrade be paid and printed in ONE press
/// (only the surcharge, like any sale). [conflicts] is null when the quote
/// failed (older backend): the panel then falls back to the switch modal.
class PlanSwitchQuote extends Equatable {
  const PlanSwitchQuote({required this.key, required this.conflicts});

  final String key;
  final List<PosEntryConflict>? conflicts;

  @override
  List<Object?> get props => [key, conflicts];
}

class PosAccountState extends Equatable {
  const PosAccountState({
    this.phoneDigits = '',
    this.foreignPhone = false,
    this.searchQuery = '',
    this.isSearching = false,
    this.results = const [],
    this.recentCustomers = const [],
    this.customerHistory = const [],
    this.customerPage = 1,
    this.hasMoreCustomers = true,
    this.isLoadingMoreCustomers = false,
    this.selectedCustomer,
    this.isBusy = false,
    this.errorMessage,
    this.plans = const [],
    this.isLoadingPlans = false,
    this.products = const [],
    this.playing = const [],
    this.transactions = const [],
    this.transactionsTotal = 0,
    this.transactionsPage = 0,
    this.isLoadingTransactions = false,
    this.transactionsFailed = false,
    this.activePasses = const [],
    this.switchQuote,
    this.lastEntryResult,
    this.lastParentPass,
    this.companionPriceUzs = defaultCompanionPriceUzs,
    this.discounts = const [],
    this.entryDiscounts = const [],
    this.checkDiscounts = const [],
    this.errorCode,
    this.promo,
    this.isCheckingPromo = false,
    this.customerPromoCodes,
    this.isLoadingPromoCodes = false,
    this.promoCodesFailed = false,
    this.promoErrorCode,
    this.promoErrorMessage,
    this.subscriptions = const [],
    this.sellableSubscriptions = const [],
    this.isLoadingSellableSubscriptions = false,
    this.lastSubscriptionSale,
  });

  /// Fallback HAMROH price used until (or if) `GET /v1/pos/config` answers —
  /// matches the backend constant at the time this build shipped.
  static const defaultCompanionPriceUzs = 10000;

  final String phoneDigits;

  /// Cashier-only: the number is foreign, so `phoneDigits` already starts
  /// with its country code and is sent as `+<digits>` (never `+998`).
  final bool foreignPhone;

  /// Full number to send / show for what is typed: `+998…` or `+<code>…`.
  String get fullPhone => foreignPhone ? '+$phoneDigits' : '+998$phoneDigits';

  /// Enough digits to register a new customer with this number. A foreign
  /// number may not start with 998 — that is an Uzbek one.
  bool get canCreateWithPhone => foreignPhone
      ? RegExp(r'^[1-9]\d{7,14}$').hasMatch(phoneDigits) &&
            !phoneDigits.startsWith('998')
      : RegExp(r'^\d{9}$').hasMatch(phoneDigits);
  final String searchQuery;
  final bool isSearching;
  final List<Customer> results;

  /// Latest customers, shown as a browsable default before the cashier
  /// types anything — capped to 10 in the bloc.
  final List<Customer> recentCustomers;

  /// Customers opened by this cashier during the current app session.
  final List<Customer> customerHistory;
  final int customerPage;
  final bool hasMoreCustomers;
  final bool isLoadingMoreCustomers;
  final Customer? selectedCustomer;
  final bool isBusy;
  final String? errorMessage;

  /// Standard/VIP tariffs — fetched once at page load, not per customer.
  final List<KidsPlan> plans;
  final bool isLoadingPlans;

  /// Ticket-type products sellable at the plan-entry checkout — fetched
  /// once at page load, same lifecycle as [plans].
  final List<Product> products;

  /// The selected customer's currently-inside children with live due-so-far
  /// — refreshed on selection and after each checkout.
  final List<PlayingChild> playing;

  /// The open page of the customer's balance ledger — empty until the
  /// "Amallar" accordion is first opened ([transactionsPage] 0 = never
  /// loaded), then refreshed whenever the balance moves.
  final List<CustomerTransaction> transactions;
  final int transactionsTotal;
  final int transactionsPage;
  final bool isLoadingTransactions;
  final bool transactionsFailed;

  /// Each child's still-valid day pass — the "already on this plan today"
  /// badge; same refresh lifecycle as [playing].
  final List<ActivePass> activePasses;

  /// The latest plan-switch quote — see [PlanSwitchQuote].
  final PlanSwitchQuote? switchQuote;

  /// Set right after a plan-entry request so the UI can pop the
  /// entrance-QR slip dialog and surface any per-child failures; cleared
  /// once acknowledged.
  final PosEntryResult? lastEntryResult;

  /// Set right after a parent-QR request so the UI can print the sticker;
  /// cleared once acknowledged — same lifecycle as [lastEntryResult].
  final ParentPass? lastParentPass;

  /// Price of one paid HAMROH companion sticker — server-owned, fetched at
  /// page load; the compiled-in default covers older backends.
  final int companionPriceUzs;

  /// Active discount catalog (`GET /v1/pos/discounts`) — fetched once at
  /// page load, best-effort like [plans]/[products]: empty just hides the
  /// picker in the goods-cart checkout section.
  final List<Discount> discounts;

  /// Active ENTRY-scoped discount catalog — the per-child 3-dots menu picks
  /// from this list instead of the old hardcoded `FreeReason` enum. Same
  /// best-effort/empty-hides-the-menu contract as [discounts].
  final List<Discount> entryDiscounts;

  /// Active CHECK-scoped catalog — the "Chek chegirmasi" sheet above the pay
  /// button; empty hides the button.
  final List<Discount> checkDiscounts;

  /// Machine-readable code paired with [errorMessage] — same reset-on-every-
  /// copyWith lifecycle (not `?? this.errorCode`), so it never lingers past
  /// the action that set it. Lets the widget react to a specific failure
  /// (`DISCOUNT_NOT_AVAILABLE`) without parsing the localized message text.
  final String? errorCode;

  /// The verified promo code for [selectedCustomer] — applied to one child
  /// at checkout; cleared on checkout, on a promo error, or when another
  /// customer is opened. A partner code is its owner's; a blogger code may
  /// also sit here with no customer open (accepted on the search screen,
  /// waiting for the cashier to pick one).
  final PromoCodeCheck? promo;
  final bool isCheckingPromo;

  /// The open customer's redeemable codes ("Faol promokodlar"); null until
  /// the list is first requested for this customer.
  final List<CustomerPromoCode>? customerPromoCodes;
  final bool isLoadingPromoCodes;

  /// The last list request failed (offline, server) — the picker offers a retry.
  final bool promoCodesFailed;

  /// The last promo-code failure — sticky until the next promo action (it
  /// is shown under the field, not as a one-off snackbar). A local
  /// `PROMO_CODE_INVALID_FORMAT` never reaches the server.
  final String? promoErrorCode;
  final String? promoErrorMessage;

  /// The selected customer's children's LIVE subscriptions — best-effort:
  /// empty (fetch failed, older backend) simply means a normal sale.
  final List<CustomerSubscription> subscriptions;

  /// Subscription types sellable at this branch — loaded when the sell
  /// modal opens.
  final List<SellableSubscriptionPlan> sellableSubscriptions;
  final bool isLoadingSellableSubscriptions;

  /// Set right after a successful subscription sale so the UI prints the
  /// receipt (+ today's sticker); cleared once acknowledged.
  final SubscriptionSaleResult? lastSubscriptionSale;

  PosAccountState copyWith({
    String? phoneDigits,
    bool? foreignPhone,
    String? searchQuery,
    bool? isSearching,
    List<Customer>? results,
    List<Customer>? recentCustomers,
    List<Customer>? customerHistory,
    int? customerPage,
    bool? hasMoreCustomers,
    bool? isLoadingMoreCustomers,
    Customer? selectedCustomer,
    bool clearSelected = false,
    bool? isBusy,
    String? errorMessage,
    List<KidsPlan>? plans,
    bool? isLoadingPlans,
    List<Product>? products,
    List<PlayingChild>? playing,
    List<CustomerTransaction>? transactions,
    int? transactionsTotal,
    int? transactionsPage,
    bool? isLoadingTransactions,
    bool? transactionsFailed,
    List<ActivePass>? activePasses,
    PlanSwitchQuote? switchQuote,
    PosEntryResult? lastEntryResult,
    bool clearLastEntryResult = false,
    ParentPass? lastParentPass,
    bool clearLastParentPass = false,
    int? companionPriceUzs,
    List<Discount>? discounts,
    List<Discount>? entryDiscounts,
    List<Discount>? checkDiscounts,
    String? errorCode,
    PromoCodeCheck? promo,
    bool clearPromo = false,
    bool? isCheckingPromo,
    List<CustomerPromoCode>? customerPromoCodes,
    bool clearCustomerPromoCodes = false,
    bool? isLoadingPromoCodes,
    bool? promoCodesFailed,
    String? promoErrorCode,
    String? promoErrorMessage,
    bool clearPromoError = false,
    List<CustomerSubscription>? subscriptions,
    List<SellableSubscriptionPlan>? sellableSubscriptions,
    bool? isLoadingSellableSubscriptions,
    SubscriptionSaleResult? lastSubscriptionSale,
    bool clearLastSubscriptionSale = false,
  }) {
    return PosAccountState(
      phoneDigits: phoneDigits ?? this.phoneDigits,
      foreignPhone: foreignPhone ?? this.foreignPhone,
      searchQuery: searchQuery ?? this.searchQuery,
      isSearching: isSearching ?? this.isSearching,
      results: results ?? this.results,
      recentCustomers: recentCustomers ?? this.recentCustomers,
      customerHistory: customerHistory ?? this.customerHistory,
      customerPage: customerPage ?? this.customerPage,
      hasMoreCustomers: hasMoreCustomers ?? this.hasMoreCustomers,
      isLoadingMoreCustomers:
          isLoadingMoreCustomers ?? this.isLoadingMoreCustomers,
      selectedCustomer: clearSelected
          ? null
          : (selectedCustomer ?? this.selectedCustomer),
      isBusy: isBusy ?? this.isBusy,
      errorMessage: errorMessage,
      plans: plans ?? this.plans,
      isLoadingPlans: isLoadingPlans ?? this.isLoadingPlans,
      products: products ?? this.products,
      playing: playing ?? this.playing,
      transactions: transactions ?? this.transactions,
      transactionsTotal: transactionsTotal ?? this.transactionsTotal,
      transactionsPage: transactionsPage ?? this.transactionsPage,
      isLoadingTransactions:
          isLoadingTransactions ?? this.isLoadingTransactions,
      transactionsFailed: transactionsFailed ?? this.transactionsFailed,
      activePasses: activePasses ?? this.activePasses,
      switchQuote: switchQuote ?? this.switchQuote,
      lastEntryResult: clearLastEntryResult
          ? null
          : (lastEntryResult ?? this.lastEntryResult),
      lastParentPass: clearLastParentPass
          ? null
          : (lastParentPass ?? this.lastParentPass),
      companionPriceUzs: companionPriceUzs ?? this.companionPriceUzs,
      discounts: discounts ?? this.discounts,
      entryDiscounts: entryDiscounts ?? this.entryDiscounts,
      checkDiscounts: checkDiscounts ?? this.checkDiscounts,
      errorCode: errorCode,
      promo: clearPromo ? null : (promo ?? this.promo),
      isCheckingPromo: isCheckingPromo ?? this.isCheckingPromo,
      customerPromoCodes: clearCustomerPromoCodes
          ? null
          : (customerPromoCodes ?? this.customerPromoCodes),
      isLoadingPromoCodes: isLoadingPromoCodes ?? this.isLoadingPromoCodes,
      promoCodesFailed: promoCodesFailed ?? this.promoCodesFailed,
      // `clearPromoError` drops the OLD error; a new one passed alongside
      // still lands.
      promoErrorCode:
          promoErrorCode ?? (clearPromoError ? null : this.promoErrorCode),
      promoErrorMessage:
          promoErrorMessage ??
          (clearPromoError ? null : this.promoErrorMessage),
      subscriptions: subscriptions ?? this.subscriptions,
      sellableSubscriptions:
          sellableSubscriptions ?? this.sellableSubscriptions,
      isLoadingSellableSubscriptions:
          isLoadingSellableSubscriptions ?? this.isLoadingSellableSubscriptions,
      lastSubscriptionSale: clearLastSubscriptionSale
          ? null
          : (lastSubscriptionSale ?? this.lastSubscriptionSale),
    );
  }

  @override
  List<Object?> get props => [
    phoneDigits,
    foreignPhone,
    searchQuery,
    isSearching,
    results,
    recentCustomers,
    customerHistory,
    customerPage,
    hasMoreCustomers,
    isLoadingMoreCustomers,
    selectedCustomer,
    isBusy,
    errorMessage,
    plans,
    isLoadingPlans,
    products,
    playing,
    transactions,
    transactionsTotal,
    transactionsPage,
    isLoadingTransactions,
    transactionsFailed,
    activePasses,
    switchQuote,
    lastEntryResult,
    lastParentPass,
    companionPriceUzs,
    discounts,
    entryDiscounts,
    checkDiscounts,
    errorCode,
    promo,
    isCheckingPromo,
    customerPromoCodes,
    isLoadingPromoCodes,
    promoCodesFailed,
    promoErrorCode,
    promoErrorMessage,
    subscriptions,
    sellableSubscriptions,
    isLoadingSellableSubscriptions,
    lastSubscriptionSale,
  ];
}

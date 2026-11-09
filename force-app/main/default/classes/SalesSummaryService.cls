public with sharing class SalesSummaryService {
    public class SummaryException extends Exception {
    }

    private static final String OWN_SUMMARY_ONLY = 'You can only view your own sales summary.';
    private static final String SELECT_ACTIVE_USER = 'Select an active user.';
    private static final String SELECT_CURRENCY = 'Select NIS or USD.';
    private static final Integer RATE_SCALE = 10;
    private static final List<String> MONTH_NAMES = new List<String>{
        'January',
        'February',
        'March',
        'April',
        'May',
        'June',
        'July',
        'August',
        'September',
        'October',
        'November',
        'December'
    };

    public class Summary {
        @AuraEnabled
        public Boolean hasSales;
        @AuraEnabled
        public String currencyCode;
        @AuraEnabled
        public Decimal total;
        @AuraEnabled
        public List<MonthTotal> months;
    }

    public class MonthTotal {
        @AuraEnabled
        public String name;
        @AuraEnabled
        public Integer year;
        @AuraEnabled
        public Decimal amount;
        @AuraEnabled
        public Boolean hasSales;
        @AuraEnabled
        public Boolean highlight;
    }

    public static Summary load(Id userId) {
        return load(userId, 'ILS');
    }

    public static Summary load(Id userId, String currencyCode) {
        if (
            userId != null &&
            userId != UserInfo.getUserId() &&
            !FeatureManagement.checkPermission('Select_Any_Salesperson')
        ) {
            throw new SummaryException(OWN_SUMMARY_ONLY);
        }
        if (userId == null || !isActiveUser(userId)) {
            throw new SummaryException(SELECT_ACTIVE_USER);
        }
        try {
            return build(userId, organizationToday(), currencyCode);
        } catch (SalesSummarySelector.AccessException ex) {
            throw new SummaryException(ex.getMessage());
        }
    }

    @TestVisible
    private static Summary build(Id userId, Date asOf) {
        return build(userId, asOf, 'ILS');
    }

    @TestVisible
    private static Summary build(Id userId, Date asOf, String currencyCode) {
        String target = normalizedCurrency(currencyCode);
        SalesSummarySelector selector = new SalesSummarySelector();
        return fromGroups(
            selector.groupedSales(userId, windowStart(asOf), windowEnd(asOf)),
            selector.conversionRates(),
            asOf,
            target
        );
    }

    @TestVisible
    private static Summary fromGroups(
        List<SalesSummarySelector.MonthCurrencyTotal> groups,
        Map<String, Decimal> rates,
        Date asOf
    ) {
        return fromGroups(groups, rates, asOf, 'ILS');
    }

    @TestVisible
    private static Summary fromGroups(
        List<SalesSummarySelector.MonthCurrencyTotal> groups,
        Map<String, Decimal> rates,
        Date asOf,
        String currencyCode
    ) {
        String target = normalizedCurrency(currencyCode);
        Decimal ilsRate = null;
        Decimal targetRate = null;
        if (!groups.isEmpty()) {
            ilsRate = rateFor(rates, 'ILS');
            targetRate = rateFor(rates, target);
        }
        Decimal threshold = Decimal.valueOf(System.Label.Sales_Summary_Low_Amount);
        Map<String, Decimal> ilsByMonth = new Map<String, Decimal>();
        Map<String, Decimal> displayByMonth = new Map<String, Decimal>();

        for (SalesSummarySelector.MonthCurrencyTotal bucket : groups) {
            String key = monthKey(bucket.year, bucket.month);
            Decimal ilsCurrent = ilsByMonth.containsKey(key) ? ilsByMonth.get(key) : 0;
            Decimal displayCurrent = displayByMonth.containsKey(key) ? displayByMonth.get(key) : 0;
            Decimal amount = bucket.total == null ? 0 : bucket.total;
            ilsByMonth.put(key, ilsCurrent + convert(amount, ilsRate, rates.get(bucket.currencyCode)));
            displayByMonth.put(key, displayCurrent + convert(amount, targetRate, rates.get(bucket.currencyCode)));
        }

        Summary summary = new Summary();
        summary.currencyCode = target;
        summary.hasSales = !ilsByMonth.isEmpty();
        summary.months = new List<MonthTotal>();
        summary.total = 0;
        if (!summary.hasSales) {
            return summary;
        }

        Date cursor = windowStart(asOf);
        for (Integer i = 0; i < 12; i++) {
            String key = monthKey(cursor.year(), cursor.month());
            Boolean monthHasSales = ilsByMonth.containsKey(key);
            Decimal ilsAmount = monthHasSales ? ilsByMonth.get(key).setScale(2, RoundingMode.HALF_UP) : 0;
            Decimal amount = monthHasSales ? displayByMonth.get(key).setScale(2, RoundingMode.HALF_UP) : 0;
            MonthTotal month = new MonthTotal();
            month.name = MONTH_NAMES[cursor.month() - 1];
            month.year = cursor.year();
            month.amount = amount;
            month.hasSales = monthHasSales;
            month.highlight = monthHasSales && ilsAmount < threshold;
            summary.months.add(month);
            summary.total += amount;
            cursor = cursor.addMonths(1);
        }
        return summary;
    }

    private static String normalizedCurrency(String currencyCode) {
        if (
            String.isBlank(currencyCode) ||
            currencyCode.equalsIgnoreCase('ILS') ||
            currencyCode.equalsIgnoreCase('NIS')
        ) {
            return 'ILS';
        }
        if (currencyCode.equalsIgnoreCase('USD')) {
            return 'USD';
        }
        throw new SummaryException(SELECT_CURRENCY);
    }

    private static Boolean isActiveUser(Id userId) {
        List<User> users = [SELECT IsActive FROM User WHERE Id = :userId];
        return !users.isEmpty() && users[0].IsActive;
    }

    private static Decimal rateFor(Map<String, Decimal> rates, String currencyCode) {
        Decimal rate = rates == null ? null : rates.get(currencyCode);
        if (rate == null || rate == 0) {
            throw new SummaryException(SELECT_CURRENCY);
        }
        return rate;
    }

    private static Decimal convert(Decimal amount, Decimal targetRate, Decimal sourceRate) {
        if (sourceRate == null || sourceRate == 0) {
            throw new SummaryException(SELECT_CURRENCY);
        }
        return amount * targetRate.divide(sourceRate, RATE_SCALE, RoundingMode.HALF_UP);
    }

    @TestVisible
    private static Date organizationToday() {
        String timeZoneSid = [SELECT TimeZoneSidKey FROM Organization].TimeZoneSidKey;
        return Date.valueOf(System.now().format('yyyy-MM-dd', timeZoneSid));
    }

    @TestVisible
    private static Date windowStart(Date asOf) {
        return Date.newInstance(asOf.year(), asOf.month(), 1).addMonths(-11);
    }

    @TestVisible
    private static Date windowEnd(Date asOf) {
        return Date.newInstance(asOf.year(), asOf.month(), 1).addMonths(1).addDays(-1);
    }

    private static String monthKey(Integer year, Integer month) {
        return String.valueOf(year) + '-' + String.valueOf(month);
    }
}

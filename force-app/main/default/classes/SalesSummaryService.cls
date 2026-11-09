public with sharing class SalesSummaryService {
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
        return build(userId, organizationToday(), currencyCode);
    }

    public static Summary build(Id userId, Date asOf) {
        return build(userId, asOf, 'ILS');
    }

    public static Summary build(Id userId, Date asOf, String currencyCode) {
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
        Decimal ilsRate = rates.get('ILS');
        Decimal targetRate = rates.get(target);
        Decimal threshold = Decimal.valueOf(System.Label.Sales_Summary_Low_Amount);
        Map<String, Decimal> ilsByMonth = new Map<String, Decimal>();
        Map<String, Decimal> displayByMonth = new Map<String, Decimal>();

        for (SalesSummarySelector.MonthCurrencyTotal bucket : groups) {
            Decimal sourceRate = rates.get(bucket.currencyCode);
            String key = monthKey(bucket.year, bucket.month);
            Decimal ilsCurrent = ilsByMonth.containsKey(key) ? ilsByMonth.get(key) : 0;
            Decimal displayCurrent = displayByMonth.containsKey(key) ? displayByMonth.get(key) : 0;
            ilsByMonth.put(key, ilsCurrent + (bucket.total * (ilsRate / sourceRate)));
            displayByMonth.put(key, displayCurrent + (bucket.total * (targetRate / sourceRate)));
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
        AuraHandledException ex = new AuraHandledException('Select NIS or USD.');
        ex.setMessage('Select NIS or USD.');
        throw ex;
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

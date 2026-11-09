// Sale sharing is private. The credited person is the current Account owner.
// Field access is checked first, then the query runs in system mode so a sale
// owned by someone else is still included.
public without sharing class SalesSummarySelector {
    public class AccessException extends Exception {
    }

    public class MonthCurrencyTotal {
        public Integer year;
        public Integer month;
        public String currencyCode;
        public Decimal total;
    }

    public List<MonthCurrencyTotal> groupedSales(Id ownerId, Date startDate, Date endDate) {
        assertFieldsReadable();
        List<MonthCurrencyTotal> groups = new List<MonthCurrencyTotal>();
        for (
            AggregateResult row : (List<AggregateResult>) Database.queryWithBinds(
                'SELECT CALENDAR_YEAR(SaleDate__c) saleYear, CALENDAR_MONTH(SaleDate__c) saleMonth, ' +
                    'CurrencyIsoCode currencyCode, SUM(AmountNumber__c) total ' +
                    'FROM Sale__c ' +
                    'WHERE Account__r.OwnerId = :ownerId ' +
                    'AND SaleDate__c >= :startDate AND SaleDate__c <= :endDate ' +
                    'GROUP BY CALENDAR_YEAR(SaleDate__c), CALENDAR_MONTH(SaleDate__c), CurrencyIsoCode',
                new Map<String, Object>{
                    'ownerId' => ownerId,
                    'startDate' => startDate,
                    'endDate' => endDate
                },
                AccessLevel.SYSTEM_MODE
            )
        ) {
            MonthCurrencyTotal bucket = new MonthCurrencyTotal();
            bucket.year = Integer.valueOf(String.valueOf(row.get('saleYear')));
            bucket.month = Integer.valueOf(String.valueOf(row.get('saleMonth')));
            bucket.currencyCode = (String) row.get('currencyCode');
            bucket.total = (Decimal) row.get('total');
            groups.add(bucket);
        }
        return groups;
    }

    public Map<String, Decimal> conversionRates() {
        Map<String, Decimal> rates = new Map<String, Decimal>();
        for (CurrencyType rate : [SELECT IsoCode, ConversionRate FROM CurrencyType WHERE IsActive = TRUE]) {
            rates.put(rate.IsoCode, rate.ConversionRate);
        }
        return rates;
    }

    private void assertFieldsReadable() {
        if (
            !Schema.SObjectType.Sale__c.fields.Amount__c.isAccessible() ||
            !Schema.SObjectType.Sale__c.fields.AmountNumber__c.isAccessible() ||
            !Schema.SObjectType.Sale__c.fields.SaleDate__c.isAccessible() ||
            !Schema.SObjectType.Sale__c.fields.Account__c.isAccessible()
        ) {
            throw new AccessException('You do not have access to sales.');
        }
    }
}

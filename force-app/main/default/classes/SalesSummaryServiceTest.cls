@IsTest
private class SalesSummaryServiceTest {
    private static final Date AS_OF = Date.newInstance(2026, 11, 9);

    @IsTest
    static void buildsTwelveMonthsOldestFirst() {
        User owner = insertUser('twelve');
        insertSale(owner.Id, Date.newInstance(2026, 11, 9), 10, 'ILS');

        SalesSummaryService.Summary summary = SalesSummaryService.build(owner.Id, AS_OF);

        Assert.areEqual(12, summary.months.size(), 'Twelve months are returned when any sale exists.');
        Assert.areEqual('December', summary.months[0].name);
        Assert.areEqual(2025, summary.months[0].year);
        Assert.areEqual('November', summary.months[11].name);
        Assert.areEqual(2026, summary.months[11].year);
        Assert.areEqual('ILS', summary.currencyCode);
    }

    @IsTest
    static void usesEnglishMonthNames() {
        User owner = insertUser('english');
        insertSale(owner.Id, AS_OF, 10, 'ILS');

        SalesSummaryService.Summary summary = SalesSummaryService.build(owner.Id, AS_OF);

        Assert.areEqual(
            new List<String>{
                'December',
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
                'November'
            },
            namesOf(summary)
        );
    }

    @IsTest
    static void zeroMonthIsNotHighlighted() {
        User owner = insertUser('zeromonth');
        insertSale(owner.Id, AS_OF, 10, 'ILS');

        SalesSummaryService.MonthTotal emptyMonth = SalesSummaryService.build(owner.Id, AS_OF).months[0];

        Assert.areEqual(0, emptyMonth.amount);
        Assert.isFalse(emptyMonth.hasSales);
        Assert.isFalse(emptyMonth.highlight);
    }

    @IsTest
    static void noSalesReturnsNoRows() {
        User owner = insertUser('nosales');

        SalesSummaryService.Summary summary = SalesSummaryService.build(owner.Id, AS_OF);

        Assert.isFalse(summary.hasSales);
        Assert.areEqual(0, summary.months.size());
        Assert.areEqual(0, summary.total);
    }

    @IsTest
    static void convertsIlsAndUsdAndTotalsRoundedMonths() {
        User owner = insertUser('convert');
        insertSale(owner.Id, AS_OF, 100, 'ILS');
        insertSale(owner.Id, AS_OF, 10, 'USD');
        Map<String, Decimal> rates = new SalesSummarySelector().conversionRates();
        Decimal expectedMonth = (100 + (10 * rates.get('ILS') / rates.get('USD'))).setScale(2, RoundingMode.HALF_UP);

        SalesSummaryService.Summary summary = SalesSummaryService.build(owner.Id, AS_OF);

        Assert.areEqual(expectedMonth, summary.months[11].amount);
        Assert.areEqual(expectedMonth, summary.total);
    }

    @IsTest
    static void highlightsBelowTheLabelAndNotWhenEqual() {
        User owner = insertUser('label');
        insertSale(owner.Id, Date.newInstance(2026, 11, 2), 999.99, 'ILS');
        insertSale(owner.Id, Date.newInstance(2026, 10, 2), 1000, 'ILS');

        List<SalesSummaryService.MonthTotal> months = SalesSummaryService.build(owner.Id, AS_OF).months;

        Assert.isFalse(months[10].highlight, 'October equals the label.');
        Assert.areEqual(1000, months[10].amount);
        Assert.isTrue(months[11].highlight, 'November is below the label.');
        Assert.areEqual(999.99, months[11].amount);
    }

    @IsTest
    static void followsTheCurrentAccountOwner() {
        User previousOwner = insertUser('oldown');
        User currentOwner = insertUser('newown');
        Account customer = insertAccount(previousOwner.Id, 'Moved Customer');
        System.runAs(new User(Id = UserInfo.getUserId())) {
            insert new Sale__c(
                Account__c = customer.Id,
                SaleDate__c = AS_OF,
                Amount__c = 40,
                CurrencyIsoCode = 'ILS'
            );
            customer.OwnerId = currentOwner.Id;
            update customer;
        }

        Assert.isTrue(SalesSummaryService.build(currentOwner.Id, AS_OF).hasSales);
        Assert.isFalse(SalesSummaryService.build(previousOwner.Id, AS_OF).hasSales);
    }

    @IsTest
    static void excludesSaleBeforeTheWindow() {
        User owner = insertUser('before');
        insertSale(owner.Id, SalesSummaryService.windowStart(AS_OF).addDays(-1), 500, 'ILS');
        insertSale(owner.Id, AS_OF, 20, 'ILS');

        SalesSummaryService.Summary summary = SalesSummaryService.build(owner.Id, AS_OF);

        Assert.areEqual(20, summary.total);
    }

    @IsTest
    static void includesWindowEdges() {
        User owner = insertUser('edges');
        insertSale(owner.Id, SalesSummaryService.windowStart(AS_OF), 5, 'ILS');
        insertSale(owner.Id, SalesSummaryService.windowEnd(AS_OF), 7, 'ILS');
        insertSale(owner.Id, SalesSummaryService.windowEnd(AS_OF).addDays(1), 100, 'ILS');

        SalesSummaryService.Summary summary = SalesSummaryService.build(owner.Id, AS_OF);

        Assert.isTrue(summary.months[0].hasSales);
        Assert.areEqual(5, summary.months[0].amount);
        Assert.isTrue(summary.months[11].hasSales);
        Assert.areEqual(7, summary.months[11].amount);
        Assert.areEqual(12, summary.total);
    }

    @IsTest
    static void addsAmountsBeforeRounding() {
        List<SalesSummarySelector.MonthCurrencyTotal> groups = new List<SalesSummarySelector.MonthCurrencyTotal>{
            currencyGroup(2026, 11, 'ILS', 0.004),
            currencyGroup(2026, 11, 'ILS', 0.004)
        };

        SalesSummaryService.MonthTotal november = SalesSummaryService.fromGroups(
                groups,
                new Map<String, Decimal>{ 'ILS' => 1 },
                AS_OF
            )
            .months[11];

        Assert.areEqual(0.01, november.amount);
    }

    @IsTest
    static void doesNotHighlightAmountThatRoundsUpToTheLabel() {
        SalesSummaryService.MonthTotal november = SalesSummaryService.fromGroups(
                new List<SalesSummarySelector.MonthCurrencyTotal>{ currencyGroup(2026, 11, 'ILS', 999.995) },
                new Map<String, Decimal>{ 'ILS' => 1 },
                AS_OF
            )
            .months[11];

        Assert.areEqual(1000, november.amount);
        Assert.isFalse(november.highlight);
    }

    @IsTest
    static void displaysUsdAndHighlightsFromTheIlsTotal() {
        SalesSummaryService.Summary summary = SalesSummaryService.fromGroups(
            new List<SalesSummarySelector.MonthCurrencyTotal>{
                currencyGroup(2026, 10, 'ILS', 400),
                currencyGroup(2026, 11, 'USD', 500)
            },
            new Map<String, Decimal>{ 'ILS' => 3.18, 'USD' => 1 },
            AS_OF,
            'USD'
        );

        Assert.areEqual('USD', summary.currencyCode);
        Assert.areEqual(125.79, summary.months[10].amount);
        Assert.isTrue(summary.months[10].highlight);
        Assert.areEqual(500, summary.months[11].amount);
        Assert.isFalse(summary.months[11].highlight);
        Assert.areEqual(625.79, summary.total);
    }

    @IsTest
    static void acceptsNisAsIls() {
        SalesSummaryService.Summary summary = SalesSummaryService.fromGroups(
            new List<SalesSummarySelector.MonthCurrencyTotal>(),
            new Map<String, Decimal>{ 'ILS' => 3.18, 'USD' => 1 },
            AS_OF,
            'NIS'
        );

        Assert.areEqual('ILS', summary.currencyCode);
        Assert.isFalse(summary.hasSales);
    }

    @IsTest
    static void rejectsACurrencyOtherThanNisOrUsd() {
        try {
            SalesSummaryService.fromGroups(
                new List<SalesSummarySelector.MonthCurrencyTotal>(),
                new Map<String, Decimal>{ 'ILS' => 1, 'USD' => 1 },
                AS_OF,
                'EUR'
            );
            Assert.fail('EUR is rejected.');
        } catch (AuraHandledException ex) {
            Assert.areEqual('Select NIS or USD.', ex.getMessage());
        }
    }

    @IsTest
    static void includesNegativeAmountAndHighlightsIt() {
        User owner = insertUser('negative');
        insertSale(owner.Id, AS_OF, -25, 'ILS');

        SalesSummaryService.MonthTotal november = SalesSummaryService.build(owner.Id, AS_OF).months[11];

        Assert.areEqual(-25, november.amount);
        Assert.isTrue(november.hasSales);
        Assert.isTrue(november.highlight);
    }

    private static List<String> namesOf(SalesSummaryService.Summary summary) {
        List<String> names = new List<String>();
        for (SalesSummaryService.MonthTotal month : summary.months) {
            names.add(month.name);
        }
        return names;
    }

    private static SalesSummarySelector.MonthCurrencyTotal currencyGroup(
        Integer year,
        Integer month,
        String currencyCode,
        Decimal total
    ) {
        SalesSummarySelector.MonthCurrencyTotal row = new SalesSummarySelector.MonthCurrencyTotal();
        row.year = year;
        row.month = month;
        row.currencyCode = currencyCode;
        row.total = total;
        return row;
    }

    private static User insertUser(String alias) {
        String unique = alias + String.valueOf(Math.abs(Crypto.getRandomInteger()));
        User person = new User(
            Alias = alias.left(8),
            Email = unique + '@example.com',
            EmailEncodingKey = 'UTF-8',
            LastName = alias,
            LanguageLocaleKey = 'en_US',
            LocaleSidKey = 'en_US',
            CommunityNickname = unique.left(40),
            ProfileId = [SELECT Id FROM Profile WHERE Name = 'System Administrator' LIMIT 1]
            .Id,
            TimeZoneSidKey = 'America/Los_Angeles',
            Username = unique + '@example.com'
        );
        insert person;
        return person;
    }

    private static Account insertAccount(Id ownerId, String name) {
        Account customer = new Account(Name = name, OwnerId = ownerId);
        System.runAs(new User(Id = UserInfo.getUserId())) {
            insert customer;
        }
        return customer;
    }

    private static void insertSale(Id ownerId, Date saleDate, Decimal amount, String currencyCode) {
        Account customer = insertAccount(ownerId, 'Customer ' + ownerId);
        System.runAs(new User(Id = UserInfo.getUserId())) {
            insert new Sale__c(
                Account__c = customer.Id,
                SaleDate__c = saleDate,
                Amount__c = amount,
                CurrencyIsoCode = currencyCode
            );
        }
    }
}

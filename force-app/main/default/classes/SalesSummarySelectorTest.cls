@IsTest
private class SalesSummarySelectorTest {
    private static final Date AS_OF = Date.newInstance(2026, 11, 9);

    @IsTest
    static void returnsGroupedTotalsForTheOwner() {
        User owner = insertUser('group');
        Id customerId = insertAccount(owner.Id, 'Grouped Customer');
        insertSale(customerId, owner.Id, Date.newInstance(2026, 11, 4), 30, 'ILS');
        insertSale(customerId, owner.Id, Date.newInstance(2026, 11, 18), 20, 'USD');

        List<SalesSummarySelector.MonthCurrencyTotal> groups = new SalesSummarySelector()
            .groupedSales(owner.Id, SalesSummaryService.windowStart(AS_OF), SalesSummaryService.windowEnd(AS_OF));

        Map<String, Decimal> totals = new Map<String, Decimal>();
        for (SalesSummarySelector.MonthCurrencyTotal bucket : groups) {
            Assert.areEqual(2026, bucket.year);
            Assert.areEqual(11, bucket.month);
            totals.put(bucket.currencyCode, bucket.total);
        }
        Assert.areEqual(30, totals.get('ILS'));
        Assert.areEqual(20, totals.get('USD'));
    }

    @IsTest
    static void excludesAnotherAccountOwner() {
        User owner = insertUser('keep');
        User otherOwner = insertUser('drop');
        insertSale(insertAccount(owner.Id, 'Kept'), owner.Id, AS_OF, 15, 'ILS');
        insertSale(insertAccount(otherOwner.Id, 'Dropped'), otherOwner.Id, AS_OF, 80, 'ILS');

        List<SalesSummarySelector.MonthCurrencyTotal> groups = new SalesSummarySelector()
            .groupedSales(owner.Id, SalesSummaryService.windowStart(AS_OF), SalesSummaryService.windowEnd(AS_OF));

        Assert.areEqual(1, groups.size());
        Assert.areEqual(15, groups[0].total);
    }

    @IsTest
    static void includesSaleWhoseRecordOwnerIsSomeoneElse() {
        User accountOwner = insertUser('acct');
        User recordOwner = insertUser('rec');
        Id customerId = insertAccount(accountOwner.Id, 'Account Owner Customer');
        insertSale(customerId, recordOwner.Id, AS_OF, 12, 'ILS');

        List<SalesSummarySelector.MonthCurrencyTotal> groups = new SalesSummarySelector()
            .groupedSales(
                accountOwner.Id,
                SalesSummaryService.windowStart(AS_OF),
                SalesSummaryService.windowEnd(AS_OF)
            );

        Assert.areEqual(1, groups.size());
        Assert.areEqual(12, groups[0].total);
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

    private static Id insertAccount(Id ownerId, String name) {
        Account customer = new Account(Name = name, OwnerId = ownerId);
        System.runAs(new User(Id = UserInfo.getUserId())) {
            insert customer;
        }
        return customer.Id;
    }

    private static void insertSale(
        Id accountId,
        Id recordOwnerId,
        Date saleDate,
        Decimal amount,
        String currencyCode
    ) {
        System.runAs(new User(Id = UserInfo.getUserId())) {
            insert new Sale__c(
                Account__c = accountId,
                OwnerId = recordOwnerId,
                SaleDate__c = saleDate,
                Amount__c = amount,
                CurrencyIsoCode = currencyCode
            );
        }
    }
}

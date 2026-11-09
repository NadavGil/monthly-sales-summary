// Sample customers and sales for the running user.
// Current month: Seed Harbor, 500 USD. At 3.18 that is 1,590.00 ILS, above the label, not red.
// Previous month: Seed Inland, 400 ILS. Below the label, red.
// Running this again does not add a second pair.

String timeZoneSid = [SELECT TimeZoneSidKey FROM Organization].TimeZoneSidKey;
Date orgToday = Date.valueOf(System.now().format('yyyy-MM-dd', timeZoneSid));
Date currentMonth = Date.newInstance(orgToday.year(), orgToday.month(), 15);
Date previousMonth = currentMonth.addMonths(-1);
Id ownerId = UserInfo.getUserId();

List<Account> existing = [
    SELECT Id
    FROM Account
    WHERE OwnerId = :ownerId AND Name IN ('Seed Harbor', 'Seed Inland')
];

if (existing.isEmpty()) {
    Account harbor = new Account(Name = 'Seed Harbor', OwnerId = ownerId);
    Account inland = new Account(Name = 'Seed Inland', OwnerId = ownerId);
    insert new List<Account>{ harbor, inland };

    insert new List<Sale__c>{
        new Sale__c(
            Account__c = harbor.Id,
            SaleDate__c = currentMonth,
            Amount__c = 500,
            CurrencyIsoCode = 'USD'
        ),
        new Sale__c(
            Account__c = inland.Id,
            SaleDate__c = previousMonth,
            Amount__c = 400,
            CurrencyIsoCode = 'ILS'
        )
    };
    System.debug(
        'Seed created Seed Harbor (500 USD on ' +
            currentMonth +
            ') and Seed Inland (400 ILS on ' +
            previousMonth +
            ').'
    );
} else {
    System.debug('Seed accounts already exist for this user. No new records were created.');
}

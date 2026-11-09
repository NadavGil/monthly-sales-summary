// Run once to create Sample Salesperson. Run the same command again to add that user's customers and sales.
// A user and an account cannot be created in the same execution. A third run does nothing.

String username = 'sample.salesperson.' + UserInfo.getOrganizationId() + '@agentforce.com';
List<User> existing = [SELECT Id FROM User WHERE Username = :username];

if (existing.isEmpty()) {
    Profile standardUser = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1];
    String nickname = ('sample' + UserInfo.getOrganizationId()).left(40);
    User salesman = new User(
        Alias = 'salesp',
        Email = UserInfo.getUserEmail(),
        EmailEncodingKey = 'UTF-8',
        FirstName = 'Sample',
        LastName = 'Salesperson',
        LanguageLocaleKey = 'en_US',
        LocaleSidKey = 'en_US',
        CommunityNickname = nickname,
        CompanyName = 'Monthly Sales Summary',
        ProfileId = standardUser.Id,
        TimeZoneSidKey = 'Asia/Jerusalem',
        Username = username
    );
    insert salesman;
    insert new PermissionSetAssignment(
        AssigneeId = salesman.Id,
        PermissionSetId = [
            SELECT Id
            FROM PermissionSet
            WHERE Name = 'Sales_Summary_User' AND IsOwnedByProfile = FALSE
            LIMIT 1
        ]
        .Id
    );
    System.setPassword(salesman.Id, 'Sales2026');
    System.debug('Sample salesperson created: ' + username + '. Run this script again to add customers and sales.');
} else {
    Id salesmanId = existing[0].Id;
    List<String> names = new List<String>{ 'Galilee Produce', 'Eilat Dive Center', 'Jerusalem Stone' };
    List<Account> already = [
        SELECT Id
        FROM Account
        WHERE OwnerId = :salesmanId AND Name IN :names
    ];
    if (!already.isEmpty()) {
        System.debug('Sample salesperson and customers already exist. No new records were created.');
    } else {
        String timeZoneSid = [SELECT TimeZoneSidKey FROM Organization].TimeZoneSidKey;
        Date orgToday = Date.valueOf(System.now().format('yyyy-MM-dd', timeZoneSid));
        List<Account> accounts = new List<Account>();
        for (String name : names) {
            accounts.add(new Account(Name = name, OwnerId = salesmanId));
        }
        insert accounts;

        Map<String, Id> accountIds = new Map<String, Id>();
        for (Account account : accounts) {
            accountIds.put(account.Name, account.Id);
        }

        List<String> rows = new List<String>{
            'Galilee Produce|2025-12-10|2200|ILS',
            'Eilat Dive Center|2026-01-15|400|USD',
            'Galilee Produce|2026-02-18|900|USD',
            'Jerusalem Stone|2026-03-09|3000|ILS',
            'Eilat Dive Center|2026-04-12|110|ILS',
            'Eilat Dive Center|2026-04-26|800|USD',
            'Jerusalem Stone|2026-05-08|2000|ILS',
            'Jerusalem Stone|2026-05-21|180|USD',
            'Galilee Produce|2026-06-14|1600|ILS',
            'Eilat Dive Center|2026-07-19|700|USD',
            'Jerusalem Stone|2026-08-06|95|ILS',
            'Jerusalem Stone|2026-08-19|500|USD',
            'Galilee Produce|2026-09-04|350|ILS',
            'Jerusalem Stone|2026-09-18|150|ILS',
            'Jerusalem Stone|2026-10-02|180|ILS',
            'Jerusalem Stone|2026-10-13|40|USD',
            'Eilat Dive Center|2026-11-02|250|ILS',
            'Eilat Dive Center|2026-11-06|450|USD'
        };
        List<Sale__c> sales = new List<Sale__c>();
        for (String row : rows) {
            List<String> parts = row.split('\\|');
            Date saleDate = Date.valueOf(parts[1]);
            if (saleDate > orgToday) {
                continue;
            }
            sales.add(
                new Sale__c(
                    Account__c = accountIds.get(parts[0]),
                    OwnerId = salesmanId,
                    SaleDate__c = saleDate,
                    Amount__c = Decimal.valueOf(parts[2]),
                    CurrencyIsoCode = parts[3]
                )
            );
        }
        insert sales;
        System.debug('Added ' + accounts.size() + ' accounts and ' + sales.size() + ' sales for ' + username + '.');
    }
}

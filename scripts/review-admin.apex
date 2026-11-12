// First run creates Review Administrator. Run the same command again to add that user's customers and sales.
// A user and an account cannot be created in the same execution. A later run does not reset the password or add a second book.

String username = 'review.admin.' + UserInfo.getOrganizationId() + '@agentforce.com';
List<User> existing = [SELECT Id, IsActive FROM User WHERE Username = :username];

if (!existing.isEmpty() && !existing[0].IsActive) {
    System.debug('Review Administrator exists and is inactive. No records were created.');
} else if (existing.isEmpty()) {
    Profile adminProfile = [SELECT Id FROM Profile WHERE Name = 'System Administrator' LIMIT 1];
    String nickname = ('review' + UserInfo.getOrganizationId()).left(40);
    User reviewAdmin = new User(
        Alias = 'revadmin',
        Email = UserInfo.getUserEmail(),
        EmailEncodingKey = 'UTF-8',
        FirstName = 'Review',
        LastName = 'Administrator',
        LanguageLocaleKey = 'en_US',
        LocaleSidKey = 'en_US',
        CommunityNickname = nickname,
        CompanyName = 'Monthly Sales Summary',
        ProfileId = adminProfile.Id,
        TimeZoneSidKey = 'Asia/Jerusalem',
        Username = username
    );
    insert reviewAdmin;
    insert new List<PermissionSetAssignment>{
        new PermissionSetAssignment(
            AssigneeId = reviewAdmin.Id,
            PermissionSetId = [
                SELECT Id
                FROM PermissionSet
                WHERE Name = 'Sales_Summary_User' AND IsOwnedByProfile = FALSE
                LIMIT 1
            ]
            .Id
        ),
        new PermissionSetAssignment(
            AssigneeId = reviewAdmin.Id,
            PermissionSetId = [
                SELECT Id
                FROM PermissionSet
                WHERE Name = 'Sales_Manager' AND IsOwnedByProfile = FALSE
                LIMIT 1
            ]
            .Id
        )
    };
    System.setPassword(reviewAdmin.Id, 'Review2026');
    System.debug('Review Administrator created: ' + username + '. Run this script again to add customers and sales.');
} else {
    Id reviewAdminId = existing[0].Id;
    List<String> names = new List<String>{
        'Ashdod Port Services',
        'Sharon Textiles',
        'Dead Sea Minerals',
        'Acre Fisheries'
    };
    List<Account> already = [
        SELECT Id
        FROM Account
        WHERE OwnerId = :reviewAdminId AND Name IN :names
    ];
    if (!already.isEmpty()) {
        System.debug('Review Administrator and customers already exist. No new records were created.');
    } else {
        String timeZoneSid = [SELECT TimeZoneSidKey FROM Organization].TimeZoneSidKey;
        Date orgToday = Date.valueOf(System.now().format('yyyy-MM-dd', timeZoneSid));
        List<Account> accounts = new List<Account>();
        for (String name : names) {
            accounts.add(new Account(Name = name, OwnerId = reviewAdminId));
        }
        insert accounts;

        Map<String, Id> accountIds = new Map<String, Id>();
        for (Account account : accounts) {
            accountIds.put(account.Name, account.Id);
        }

        List<String> rows = new List<String>{
            'Ashdod Port Services|2025-12-08|800|ILS',
            'Sharon Textiles|2026-01-14|2000|ILS',
            'Dead Sea Minerals|2026-01-22|500|USD',
            'Acre Fisheries|2026-02-11|250|USD',
            'Sharon Textiles|2026-03-05|1800|ILS',
            'Ashdod Port Services|2026-03-19|400|USD',
            'Dead Sea Minerals|2026-04-16|600|ILS',
            'Acre Fisheries|2026-05-07|2200|ILS',
            'Sharon Textiles|2026-05-20|100|USD',
            'Ashdod Port Services|2026-06-09|900|ILS',
            'Ashdod Port Services|2026-06-23|-200|ILS',
            'Dead Sea Minerals|2026-07-15|1500|USD',
            'Acre Fisheries|2026-08-18|90|USD',
            'Sharon Textiles|2026-09-03|2400|ILS',
            'Dead Sea Minerals|2026-09-17|300|USD',
            'Acre Fisheries|2026-10-06|450|ILS',
            'Ashdod Port Services|2026-11-04|1100|ILS',
            'Sharon Textiles|2026-11-08|200|USD'
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
                    OwnerId = reviewAdminId,
                    SaleDate__c = saleDate,
                    Amount__c = Decimal.valueOf(parts[2]),
                    CurrencyIsoCode = parts[3]
                )
            );
        }
        insert sales;
        System.debug(
            'Added ' + accounts.size() + ' accounts and ' + sales.size() + ' sales for ' + username + '.'
        );
    }
}

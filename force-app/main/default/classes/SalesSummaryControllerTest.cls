@IsTest
private class SalesSummaryControllerTest {
    @IsTest
    static void salespersonLoadsOwnSummary() {
        User salesperson = insertUser('self');
        assignSummaryUser(salesperson.Id);
        Account customer = insertAccount(salesperson.Id, 'Own Customer');
        insertSale(customer.Id, Date.today(), 10, 'ILS');

        System.runAs(salesperson) {
            SalesSummaryService.Summary summary = SalesSummaryController.getSummary(salesperson.Id, null);
            Assert.isTrue(summary.hasSales);
            Assert.areEqual('ILS', summary.currencyCode);
        }
    }

    @IsTest
    static void salespersonCannotLoadAnotherUser() {
        User salesperson = insertUser('rep');
        User other = insertUser('other');

        System.runAs(salesperson) {
            try {
                SalesSummaryController.getSummary(other.Id, null);
                Assert.fail('A salesperson must not open another summary.');
            } catch (AuraHandledException ex) {
                Assert.areEqual('You can only view your own sales summary.', ex.getMessage());
            }
        }
    }

    @IsTest
    static void salespersonNullIdIsRejected() {
        User salesperson = insertUser('nullid');

        System.runAs(salesperson) {
            try {
                SalesSummaryController.getSummary(null, null);
                Assert.fail('A null id is rejected.');
            } catch (AuraHandledException ex) {
                Assert.areEqual('Select an active user.', ex.getMessage());
            }
        }
    }

    @IsTest
    static void managerLoadsAnActiveUser() {
        User manager = insertUser('mgr');
        User salesperson = insertUser('rep2');
        assignManager(manager.Id);
        insertSale(insertAccount(salesperson.Id, 'Managed Customer').Id, Date.today(), 25, 'ILS');

        System.runAs(manager) {
            SalesSummaryService.Summary summary = SalesSummaryController.getSummary(salesperson.Id, null);
            Assert.isTrue(summary.hasSales);
        }
    }

    @IsTest
    static void managerRejectsInactiveNullAndUnknown() {
        User manager = insertUser('mgr2');
        User inactive = insertUser('inact');
        assignManager(manager.Id);
        inactive.IsActive = false;
        update inactive;
        Id unknownId = (Id) (User.SObjectType.getDescribe().getKeyPrefix() + '000000000000');

        System.runAs(manager) {
            assertRejected(null);
            assertRejected(unknownId);
            assertRejected(inactive.Id);
        }
    }

    private static void assertRejected(Id userId) {
        try {
            SalesSummaryController.getSummary(userId, null);
            Assert.fail('The id should be rejected.');
        } catch (AuraHandledException ex) {
            Assert.areEqual('Select an active user.', ex.getMessage());
        }
    }

    private static void assignSummaryUser(Id userId) {
        assignPermissionSet(userId, 'Sales_Summary_User');
    }

    private static void assignManager(Id userId) {
        assignPermissionSet(userId, 'Sales_Manager');
    }

    private static void assignPermissionSet(Id userId, String permissionSetName) {
        insert new PermissionSetAssignment(
            AssigneeId = userId,
            PermissionSetId = [SELECT Id FROM PermissionSet WHERE Name = :permissionSetName LIMIT 1]
            .Id
        );
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

    private static void insertSale(Id accountId, Date saleDate, Decimal amount, String currencyCode) {
        System.runAs(new User(Id = UserInfo.getUserId())) {
            insert new Sale__c(
                Account__c = accountId,
                SaleDate__c = saleDate,
                Amount__c = amount,
                CurrencyIsoCode = currencyCode
            );
        }
    }
}

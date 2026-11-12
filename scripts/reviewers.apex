// The org has four Salesforce licenses, all in use. The first run deactivates
// Review Administrator and Sample Salesperson. The second run creates one
// System Administrator for each reviewer, with that reviewer's email. The
// third run moves the customer books onto those users. A user and an account
// cannot be changed in the same execution. A later run does not reset passwords.

String orgId = UserInfo.getOrganizationId();
String oranUsername = 'orans.' + orgId + '@agentforce.com';
String saharUsername = 'saharel.' + orgId + '@agentforce.com';

List<User> reviewers = [
    SELECT Id, Username
    FROM User
    WHERE Username IN :new List<String>{ oranUsername, saharUsername }
];

if (reviewers.isEmpty()) {
    List<User> holdingLicenses = [
        SELECT Id, Username
        FROM User
        WHERE
            IsActive = TRUE
            AND (Username LIKE 'review.admin.%@agentforce.com'
            OR Username LIKE 'sample.salesperson.%@agentforce.com')
    ];
    if (!holdingLicenses.isEmpty()) {
        for (User oldUser : holdingLicenses) {
            oldUser.IsActive = false;
        }
        update holdingLicenses;
        System.debug(
            'Deactivated ' +
                holdingLicenses.size() +
                ' users to free Salesforce licenses. Run this script again.'
        );
        return;
    }

    Profile adminProfile = [SELECT Id FROM Profile WHERE Name = 'System Administrator' LIMIT 1];
    List<User> toInsert = new List<User>{
        new User(
            Alias = 'orans',
            Email = 'orans@5555.co.il',
            EmailEncodingKey = 'UTF-8',
            FirstName = 'Review',
            LastName = 'orans',
            LanguageLocaleKey = 'en_US',
            LocaleSidKey = 'en_US',
            CommunityNickname = ('orans' + orgId).left(40),
            CompanyName = 'Monthly Sales Summary',
            ProfileId = adminProfile.Id,
            TimeZoneSidKey = 'Asia/Jerusalem',
            Username = oranUsername
        ),
        new User(
            Alias = 'saharel',
            Email = 'saharel@5555.co.il',
            EmailEncodingKey = 'UTF-8',
            FirstName = 'Review',
            LastName = 'saharel',
            LanguageLocaleKey = 'en_US',
            LocaleSidKey = 'en_US',
            CommunityNickname = ('saharel' + orgId).left(40),
            CompanyName = 'Monthly Sales Summary',
            ProfileId = adminProfile.Id,
            TimeZoneSidKey = 'Asia/Jerusalem',
            Username = saharUsername
        )
    };
    insert toInsert;

    Map<String, Id> permissionSetIds = new Map<String, Id>();
    for (PermissionSet permissionSet : [
        SELECT Id, Name
        FROM PermissionSet
        WHERE Name IN ('Sales_Summary_User', 'Sales_Manager') AND IsOwnedByProfile = FALSE
    ]) {
        permissionSetIds.put(permissionSet.Name, permissionSet.Id);
    }
    List<PermissionSetAssignment> assignments = new List<PermissionSetAssignment>();
    for (User reviewer : toInsert) {
        assignments.add(
            new PermissionSetAssignment(
                AssigneeId = reviewer.Id,
                PermissionSetId = permissionSetIds.get('Sales_Summary_User')
            )
        );
        assignments.add(
            new PermissionSetAssignment(
                AssigneeId = reviewer.Id,
                PermissionSetId = permissionSetIds.get('Sales_Manager')
            )
        );
        System.setPassword(reviewer.Id, 'Review2026');
    }
    insert assignments;
    System.debug('Created ' + oranUsername + ' and ' + saharUsername + '. Run this script again to move the customer books.');
    return;
}

Map<String, Id> reviewerIds = new Map<String, Id>();
for (User reviewer : reviewers) {
    reviewerIds.put(reviewer.Username.toLowerCase(), reviewer.Id);
}
Id oranId = reviewerIds.get(oranUsername.toLowerCase());
Id saharId = reviewerIds.get(saharUsername.toLowerCase());

List<User> previous = [
    SELECT Id, Username
    FROM User
    WHERE
        Username LIKE 'review.admin.%@agentforce.com'
        OR Username LIKE 'sample.salesperson.%@agentforce.com'
];
Id previousReviewId;
Id previousSampleId;
for (User previousUser : previous) {
    String username = previousUser.Username.toLowerCase();
    if (username.startsWith('review.admin.')) {
        previousReviewId = previousUser.Id;
    } else if (username.startsWith('sample.salesperson.')) {
        previousSampleId = previousUser.Id;
    }
}

List<Id> previousIds = new List<Id>();
if (previousReviewId != null) {
    previousIds.add(previousReviewId);
}
if (previousSampleId != null) {
    previousIds.add(previousSampleId);
}

List<Account> accounts = [SELECT Id, OwnerId FROM Account WHERE OwnerId IN :previousIds];
Integer movedAccounts = 0;
for (Account account : accounts) {
    Id nextOwner = account.OwnerId == previousReviewId ? oranId : saharId;
    if (nextOwner != null && account.OwnerId != nextOwner) {
        account.OwnerId = nextOwner;
        movedAccounts++;
    }
}
if (movedAccounts > 0) {
    update accounts;
}

List<Sale__c> sales = [SELECT Id, OwnerId FROM Sale__c WHERE OwnerId IN :previousIds];
Integer movedSales = 0;
for (Sale__c sale : sales) {
    Id nextOwner = sale.OwnerId == previousReviewId ? oranId : saharId;
    if (nextOwner != null && sale.OwnerId != nextOwner) {
        sale.OwnerId = nextOwner;
        movedSales++;
    }
}
if (movedSales > 0) {
    update sales;
}
System.debug('Moved ' + movedAccounts + ' accounts and ' + movedSales + ' sales onto the reviewer users.');

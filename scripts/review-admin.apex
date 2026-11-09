// Creates Review Administrator, a System Administrator for the reviewing team.
// The email is the running user's email. Running this again does not reset the password.

String username = 'review.admin.' + UserInfo.getOrganizationId() + '@agentforce.com';
List<User> existing = [SELECT Id FROM User WHERE Username = :username];
Id reviewAdminId;

if (existing.isEmpty()) {
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
    System.setPassword(reviewAdmin.Id, 'Review2026');
    reviewAdminId = reviewAdmin.Id;
    System.debug('Review Administrator created: ' + username);
} else {
    reviewAdminId = existing[0].Id;
    System.debug('Review Administrator already exists: ' + username);
}

List<PermissionSet> permissionSets = [
    SELECT Id, Name
    FROM PermissionSet
    WHERE Name IN ('Sales_Summary_User', 'Sales_Manager') AND IsOwnedByProfile = FALSE
];
Set<Id> alreadyAssigned = new Set<Id>();
for (PermissionSetAssignment assignment : [
    SELECT PermissionSetId
    FROM PermissionSetAssignment
    WHERE AssigneeId = :reviewAdminId AND PermissionSetId IN :permissionSets
]) {
    alreadyAssigned.add(assignment.PermissionSetId);
}
List<PermissionSetAssignment> missing = new List<PermissionSetAssignment>();
for (PermissionSet permissionSet : permissionSets) {
    if (!alreadyAssigned.contains(permissionSet.Id)) {
        missing.add(
            new PermissionSetAssignment(AssigneeId = reviewAdminId, PermissionSetId = permissionSet.Id)
        );
    }
}
if (!missing.isEmpty()) {
    insert missing;
}
System.debug('Review Administrator has Sales_Summary_User and Sales_Manager. Username: ' + username);

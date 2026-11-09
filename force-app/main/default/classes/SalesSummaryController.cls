public with sharing class SalesSummaryController {
    private static final String OWN_SUMMARY_ONLY = 'You can only view your own sales summary.';
    private static final String SELECT_ACTIVE_USER = 'Select an active user.';

    @AuraEnabled
    public static SalesSummaryService.Summary getSummary(Id userId, String currencyCode) {
        if (userId == null || !isActiveUser(userId)) {
            throw handled(SELECT_ACTIVE_USER);
        }
        if (userId != UserInfo.getUserId() && !FeatureManagement.checkPermission('Select_Any_Salesperson')) {
            throw handled(OWN_SUMMARY_ONLY);
        }
        return SalesSummaryService.load(userId, currencyCode);
    }

    private static Boolean isActiveUser(Id userId) {
        List<User> users = [SELECT IsActive FROM User WHERE Id = :userId];
        return !users.isEmpty() && users[0].IsActive;
    }

    private static AuraHandledException handled(String message) {
        AuraHandledException ex = new AuraHandledException(message);
        ex.setMessage(message);
        return ex;
    }
}

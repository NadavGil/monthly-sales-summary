public with sharing class SalesSummaryController {
    @AuraEnabled
    public static SalesSummaryService.Summary getSummary(Id userId, String currencyCode) {
        try {
            return SalesSummaryService.load(userId, currencyCode);
        } catch (SalesSummaryService.SummaryException ex) {
            throw handled(ex.getMessage());
        }
    }

    private static AuraHandledException handled(String message) {
        AuraHandledException ex = new AuraHandledException(message);
        ex.setMessage(message);
        return ex;
    }
}

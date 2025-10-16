// File: BV_CBVRBuilder.cls
public with sharing class BV_CBVRBuilder {

    private static final String DEFAULT_SERVICE_TYPE = 'Dental';

    /**
     * It creates the CareBenefitVerifyRequest__c records for the given Accounts.
     * And returns the Ids of the CBVRs that were inserted (successful rows only).
     */
    public static List<Id> buildFromAccountIds(
        List<Id> accountIds,
        Date serviceDate,
        String serviceType,
        String icd10,
        String cpt
    ){
        List<Id> created = new List<Id>();
        if (accountIds == null || accountIds.isEmpty()) return created;

        // Normalize/validate serviceType against active picklist values
        String safeServiceType = coerceToActiveServiceType(serviceType);

        Map<Id, Account> acctMap = new Map<Id, Account>(
            [SELECT Id, Name FROM Account WHERE Id IN :accountIds]
        );

        List<CareBenefitVerifyRequest__c> toInsert = new List<CareBenefitVerifyRequest__c>();

        for (Id aid : accountIds) {
            Account a = acctMap.get(aid);
            if (a == null) continue;

            CareBenefitVerifyRequest__c cbvr = new CareBenefitVerifyRequest__c(
                Name            = 'CBVR for ' + a.Name,
                ServiceType__c  = safeServiceType,   // validated picklist value
                Service_Date__c = serviceDate,
                ICD10__c        = icd10,
                CPT__c          = cpt
            );
            toInsert.add(cbvr);
        }

        if (toInsert.isEmpty()) return created;

        
        Database.SaveResult[] results = Database.insert(toInsert, /*allOrNone*/ false);
        for (Integer i = 0; i < results.size(); i++) {
            if (results[i].isSuccess()) {
                created.add(results[i].getId());
            } else {
                // Helpful logging for any failures
                for (Database.Error e : results[i].getErrors()) {
                    System.debug(LoggingLevel.ERROR,
                        'CBVR insert failed for row ' + i + ': ' + e.getStatusCode() + ' - ' + e.getMessage());
                }
            }
        }
        return created;
    }

    /**
     Give it an Accounts filter. It finds those Accounts, grabs their IDs, and then builds the results from those IDs.
     */
    public static List<Id> buildFromAccountsWhere(
        String whereClause,
        Date serviceDate,
        String serviceType,
        String icd10,
        String cpt
    ){
        String soql = 'SELECT Id FROM Account';
        if (!String.isBlank(whereClause)) soql += ' WHERE ' + whereClause;

        List<Account> accts = Database.query(soql);

        List<Id> acctIds = new List<Id>();
        for (Account a : accts) acctIds.add(a.Id);

        return buildFromAccountIds(acctIds, serviceDate, serviceType, icd10, cpt);
    }

    // ---------- helpers ----------

    // Looks up an active picklist value for ServiceType__c. If nothing qualifies, it returns the default value.
    private static String coerceToActiveServiceType(String incoming) {
        Set<String> active = getActiveServiceTypes();
        String val = String.isBlank(incoming) ? null : incoming.trim();
        if (val != null && active.contains(val)) return val;
        // fall back to default if provided default is active, otherwise first active value
        if (active.contains(DEFAULT_SERVICE_TYPE)) return DEFAULT_SERVICE_TYPE;
        return (active.isEmpty() ? null : active.iterator().next());
    }

    // Uses the field describe to fetch the active picklist values for that field.
    @TestVisible private static Set<String> getActiveServiceTypes() {
        Set<String> vals = new Set<String>();
        Schema.DescribeFieldResult dfr = CareBenefitVerifyRequest__c.ServiceType__c.getDescribe();
        for (Schema.PicklistEntry pe : dfr.getPicklistValues()) {
            if (pe.isActive()) vals.add(pe.getValue());
        }
        return vals;
    }
}
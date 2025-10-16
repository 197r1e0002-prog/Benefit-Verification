public with sharing class BV_CBVRQuickCreate {

    /** Make the smallest possible CBVR record that fills in all the mandatory fields. */
    public static Id make(String statusLabel) {
        // Patient & Provider Accounts
        Account patient  = new Account(Name = 'Test Patient '  + Datetime.now().getTime());
        Account provider = new Account(Name = 'Test Provider ' + Datetime.now().getTime());
        insert new List<Account>{ patient, provider };

        // Make sure the Insurance_Information__c lookup has a Member Plan record connected.
        Id memberPlanId = ensureMemberPlan();

        // Create the CBVR
        CareBenefitVerifyRequest__c r = new CareBenefitVerifyRequest__c(
            Status__c                = String.isBlank(statusLabel) ? 'New' : statusLabel,
            ServiceType__c           = 'Medical',
            Patient_Details__c       = patient.Id,
            Provider_Information__c  = provider.Id,
            Insurance_Information__c = memberPlanId,
            Service_Date__c          = Date.today()
        );
        insert r;

        // If automation (a trigger) didn’t fill this in, handle it yourself as a backup.
        if (String.isBlank(r.External_Request_Id__c)) {
            r.External_Request_Id__c = 'CBVR-' + r.Id;
            update r;
        }
        return r.Id;
    }

    @TestVisible
    private static Id ensureMemberPlan() {
        // onfirm which object the Insurance_Information__c field is a lookup to (e.g., Member Plan).
        Schema.DescribeFieldResult dfr =
            CareBenefitVerifyRequest__c.Insurance_Information__c.getDescribe();
        Schema.SObjectType refType = dfr.getReferenceTo()[0];
        String apiName = refType.getDescribe().getName();

        // If there’s already a suitable Member Plan, use that one instead of creating a new one.
        List<SObject> existing = Database.query('SELECT Id FROM ' + apiName + ' LIMIT 1');
        if (!existing.isEmpty()) return (Id) existing[0].get('Id');


        Account member = new Account(Name = 'Test Member ' + Datetime.now().getTime());
        insert member;

        // If none exists, create a new Member Plan with just the required fields filled.
        SObject mp = refType.newSObject(null, true);
        Map<String, Schema.SObjectField> f = refType.getDescribe().fields.getMap();
        if (f.containsKey('Name'))     mp.put('Name', 'Test Member Plan ' + Datetime.now().getTime());
        if (f.containsKey('MemberId')) mp.put('MemberId', member.Id); // REQUIRED in your org
        insert mp;

        return (Id) mp.get('Id');
    }
}
@IsTest(SeeAllData=true) // uses the real queues Dental/Emergency/Medical/Care_Representatives
private class BV_CBVRRoutingTriggerTest {

    // A small helper that makes Account records for tests.
    private static Account makeAccount(String name){
        Account a = new Account(Name = name);
        insert a;
        return a;
    }

    // Only fill the fields that must have values and that we’re allowed to write, using harmless defaults.
    private static void fillRequiredFields(SObject sobj, Id fallbackAccountId){
        Schema.DescribeSObjectResult sdesc = sobj.getSObjectType().getDescribe();
        Map<String, Schema.SObjectField> fmap = sdesc.fields.getMap();

        for (String api : fmap.keySet()) {
            Schema.DescribeFieldResult f = fmap.get(api).getDescribe();

            if (!f.isCreateable() || f.isCalculated() || f.isDefaultedOnCreate()) continue;
            if (f.isNillable()) continue;                            // only required fields
            if (api == 'Id' || api == 'OwnerId' || api == 'RecordTypeId' || api.endsWith('__pc')) continue;
            if (sobj.get(api) != null) continue;                     // already set

            switch on f.getType() {
                when STRING, EMAIL, URL, PHONE, TEXTAREA, ENCRYPTEDSTRING {
                    sobj.put(api, 'x');
                }
                when PICKLIST {
                    List<Schema.PicklistEntry> opts = f.getPicklistValues();
                    if (!opts.isEmpty()) sobj.put(api, opts[0].getValue());
                }
                when MULTIPICKLIST {
                    List<Schema.PicklistEntry> opts = f.getPicklistValues();
                    if (!opts.isEmpty()) sobj.put(api, new List<String>{ opts[0].getValue() });
                }
                when BOOLEAN {
                    sobj.put(api, true);
                }
                when INTEGER, DOUBLE, CURRENCY, PERCENT {
                    sobj.put(api, 1);
                }
                when DATE {
                    sobj.put(api, Date.today());
                }
                when DATETIME {
                    sobj.put(api, System.now());
                }
                when TIME {
                    sobj.put(api, Time.newInstance(0,0,0,0));
                }
                when REFERENCE {
                    // If a lookup can point to multiple objects, use Account or User first when allowed.
                    List<Schema.SObjectType> targets = f.getReferenceTo();
                    Set<String> names = new Set<String>();
                    for (Schema.SObjectType t : targets) names.add(t.getDescribe().getName());
                    if (names.contains('Account') && fallbackAccountId != null) {
                        sobj.put(api, fallbackAccountId);
                    } else if (names.contains('User')) {
                        sobj.put(api, UserInfo.getUserId());
                    }
                }
                when else { /* ignore */ }
            }
        }
    }

    // Make a record of the object referenced by CBVR.Insurance_Information__c.
    private static Id makeInsuranceRecord(Id fallbackAccountId){
        Schema.DescribeFieldResult dfr   = CareBenefitVerifyRequest__c.Insurance_Information__c.getDescribe();
        Schema.SObjectType         typ   = dfr.getReferenceTo()[0];               // e.g., Member_Plan__c
        SObject                    plan  = typ.newSObject(null, true);

        // If that object has a writable Name field, set it.
        Map<String, Schema.SObjectField> fmap = typ.getDescribe().fields.getMap();
        if (fmap.containsKey('Name') && fmap.get('Name').getDescribe().isCreateable()){
            plan.put('Name','Plan');
        }

        fillRequiredFields(plan, fallbackAccountId);
        insert plan;
        return (Id) plan.get('Id');
    }

    // Create a CBVR record and populate all three required lookup fields.
    private static CareBenefitVerifyRequest__c makeCBVR(
        String serviceType, Id patientId, Id providerId, Id insuranceId
    ){
        CareBenefitVerifyRequest__c r = new CareBenefitVerifyRequest__c();
        // Also fill in any fields the routing logic depends on.
        r.ServiceType__c  = serviceType;
        r.Service_Date__c = Date.today();
        r.ICD10__c        = 'E11.9';
        r.CPT__c          = '99213';

        // Make sure the must-have lookup fields (as per your mapping) are set.
        r.Patient_Details__c       = patientId;     // Patient
        r.Provider_Information__c  = providerId;    // Provider
        r.Insurance_Information__c = insuranceId;   // Insurance (Member Plan)

        // For any other required fields, set simple generic values.
        fillRequiredFields(r, patientId);
        return r;
    }

    // Look up Queue IDs using their DeveloperName (assumes those queues actually exist).
    private static Id queueId(String devName){
        Group g = [
            SELECT Id FROM Group
            WHERE Type = 'Queue' AND DeveloperName = :devName
            LIMIT 1
        ];
        System.assertNotEquals(null, g, 'Expected queue ' + devName + ' to exist');
        return g.Id;
    }

    /* ---------------- the test ---------------- */

    @IsTest
    static void routes_Dental_Emergency_Medical_and_Default(){
        // List the queues that should be present.
        Id dentalQ  = queueId('Dental');
        Id emergQ   = queueId('Emergency');
        Id medicalQ = queueId('Medical');
        Id defaultQ = queueId('Care_Representatives');

        // Include queues/owners for both the user/teams doing the work and the insurance side.
        Account patient  = makeAccount('Patient A');
        Account provider = makeAccount('Provider A');
        Id planId        = makeInsuranceRecord(patient.Id);

        // Create four sample records that hit each routing scenario.
        CareBenefitVerifyRequest__c d = makeCBVR('Dental',     patient.Id, provider.Id, planId);
        CareBenefitVerifyRequest__c e = makeCBVR('Emergency',  patient.Id, provider.Id, planId);
        CareBenefitVerifyRequest__c m = makeCBVR('Medical',    patient.Id, provider.Id, planId);
        CareBenefitVerifyRequest__c z = makeCBVR('consultation', patient.Id, provider.Id, planId); // default

        insert new List<CareBenefitVerifyRequest__c>{ d, e, m, z };

        // After triggers run, query the records again to see the final owner set by automation.
        d = [SELECT OwnerId FROM CareBenefitVerifyRequest__c WHERE Id = :d.Id];
        e = [SELECT OwnerId FROM CareBenefitVerifyRequest__c WHERE Id = :e.Id];
        m = [SELECT OwnerId FROM CareBenefitVerifyRequest__c WHERE Id = :m.Id];
        z = [SELECT OwnerId FROM CareBenefitVerifyRequest__c WHERE Id = :z.Id];

        System.assertEquals(dentalQ,  d.OwnerId, 'Dental ➜ Dental queue');
        System.assertEquals(emergQ,   e.OwnerId, 'Emergency ➜ Emergency queue');
        System.assertEquals(medicalQ, m.OwnerId, 'Medical ➜ Medical queue');
        System.assertEquals(defaultQ, z.OwnerId, 'Unmapped ➜ Care_Representatives queue');
    }
}
@IsTest(seeAllData=false)
private class CBV_ResultsApiV1AuthTest {

    /* ---------- small helpers ---------- */

    private static Account makeAccount(String name){
        Account a = new Account(Name = name);
        insert a;
        return a;
    }

    // Only set the fields that are required and writeable, using basic, harmless values.
    private static void fillRequiredFields(SObject sobj, Id fallbackAccountId){
        Schema.DescribeSObjectResult sdesc = sobj.getSObjectType().getDescribe();
        Map<String, Schema.SObjectField> fmap = sdesc.fields.getMap();

        for (String api : fmap.keySet()) {
            Schema.DescribeFieldResult f = fmap.get(api).getDescribe();
            if (!f.isCreateable() || f.isCalculated() || f.isDefaultedOnCreate()) continue;
            if (f.isNillable()) continue;
            if (api == 'Id' || api == 'OwnerId' || api == 'RecordTypeId' || api.endsWith('__pc')) continue;
            if (sobj.get(api) != null) continue;

            switch on f.getType() {
                when STRING, EMAIL, URL, PHONE, TEXTAREA, ENCRYPTEDSTRING { sobj.put(api, 'x'); }
                when PICKLIST       { List<Schema.PicklistEntry> opts = f.getPicklistValues(); if (!opts.isEmpty()) sobj.put(api, opts[0].getValue()); }
                when MULTIPICKLIST  { List<Schema.PicklistEntry> opts = f.getPicklistValues(); if (!opts.isEmpty()) sobj.put(api, new List<String>{ opts[0].getValue() }); }
                when BOOLEAN        { sobj.put(api, true); }
                when INTEGER, DOUBLE, CURRENCY, PERCENT { sobj.put(api, 1); }
                when DATE           { sobj.put(api, Date.today()); }
                when DATETIME       { sobj.put(api, System.now()); }
                when TIME           { sobj.put(api, Time.newInstance(0,0,0,0)); }
                when REFERENCE {
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

    // Make a record of the object that the CBVR.Insurance_Information__c lookup points to.
    private static Id makeInsuranceRecord(Id fallbackAccountId){
        Schema.DescribeFieldResult dfr = CareBenefitVerifyRequest__c.Insurance_Information__c.getDescribe();
        Schema.SObjectType refType = dfr.getReferenceTo()[0];
        SObject plan = refType.newSObject(null, true);

        Map<String, Schema.SObjectField> fmap = refType.getDescribe().fields.getMap();
        if (fmap.containsKey('Name') && fmap.get('Name').getDescribe().isCreateable()) {
            plan.put('Name','Plan');
        }
        fillRequiredFields(plan, fallbackAccountId);
        insert plan;
        return (Id) plan.get('Id');
    }

    private static CareBenefitVerifyRequest__c makeCbvr(){
        Account patient  = makeAccount('Patient A');
        Account provider = makeAccount('Provider A');
        Id planId = makeInsuranceRecord(patient.Id);

        CareBenefitVerifyRequest__c cbvr = new CareBenefitVerifyRequest__c();
        fillRequiredFields(cbvr, patient.Id);
        cbvr.Name                     = 'BVR-TEST';
        cbvr.Patient_Details__c       = patient.Id;
        cbvr.Provider_Information__c  = provider.Id;
        cbvr.Insurance_Information__c = planId;
        insert cbvr;
        return cbvr;
    }

    private static String requestJson(Id cbvrId, String status){
        return JSON.serialize(new Map<String,Object>{
            'cbvrId'            => cbvrId,
            'externalRequestId' => String.valueOf(cbvrId),
            'status'            => status,
            'statusReason'      => 'ok',
            'coverage' => new List<Object>{
                new Map<String,Object>{
                    'externalId'   => 'EV-TEST-401',
                    'name'         => 'Aetna PPO | Test',
                    'status'       => 'active',
                    'statusReason' => 'created'
                }
            }
        });
    }

    /* ---------- tests ---------- */

    @IsTest
    static void missing_header_returns_401_and_writes_nothing(){
        CareBenefitVerifyRequest__c cbvr = makeCbvr();
        // Enable authentication for this test so the calls behave like real, secured requests.
        CBV_ResultsApiV1.TEST_WEBHOOK_SECRET = 'top-secret';

        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        RestContext.request = req; RestContext.response = res;
        req.httpMethod = 'POST';
        req.requestURI = '/services/apexrest/cbv/results/v1';
        req.addHeader('Content-Type','application/json');
        req.requestBody = Blob.valueOf(requestJson(cbvr.Id, 'ready'));

        try {
            CBV_ResultsApiV1.receive();
            System.assertEquals(401, RestContext.response.statusCode, 'Should be unauthorized');
            // Double-check that the test didn’t accidentally create any records.
            System.assertEquals(0, [SELECT count() FROM CoverageBenefit__c WHERE External_Request_Id__c = 'EV-TEST-401']);
        } finally {
            CBV_ResultsApiV1.TEST_WEBHOOK_SECRET = null;
        }
    }

    @IsTest
    static void wrong_header_returns_401(){
        CareBenefitVerifyRequest__c cbvr = makeCbvr();
        CBV_ResultsApiV1.TEST_WEBHOOK_SECRET = 'top-secret';

        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        RestContext.request = req; RestContext.response = res;
        req.httpMethod = 'POST';
        req.requestURI = '/services/apexrest/cbv/results/v1';
        req.addHeader('Content-Type','application/json');
        req.addHeader('x-bv-webhook-secret','wrong');
        req.requestBody = Blob.valueOf(requestJson(cbvr.Id, 'ready'));

        try {
            CBV_ResultsApiV1.receive();
            System.assertEquals(401, RestContext.response.statusCode, 'Should be unauthorized');
            System.assertEquals(0, [SELECT count() FROM CoverageBenefit__c WHERE External_Request_Id__c = 'EV-TEST-401']);
        } finally {
            CBV_ResultsApiV1.TEST_WEBHOOK_SECRET = null;
        }
    }

    @IsTest
    static void correct_header_returns_200_and_upserts(){
        CareBenefitVerifyRequest__c cbvr = makeCbvr();
        CBV_ResultsApiV1.TEST_WEBHOOK_SECRET = 'top-secret';

        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        RestContext.request = req; RestContext.response = res;
        req.httpMethod = 'POST';
        req.requestURI = '/services/apexrest/cbv/results/v1';
        req.addHeader('Content-Type','application/json');
        req.addHeader('x-bv-webhook-secret','top-secret'); // correct
        req.requestBody = Blob.valueOf(requestJson(cbvr.Id, 'ready'));

        try {
            CBV_ResultsApiV1.receive();
            System.assertEquals(200, RestContext.response.statusCode, 'Should be OK');

            CoverageBenefit__c row = [
                SELECT Id, Status__c, Status_Reason__c, CareBenefitVerifyRequest__c
                FROM CoverageBenefit__c
                WHERE External_Request_Id__c = 'EV-TEST-401'
                LIMIT 1
            ];
            System.assertEquals('Active', row.Status__c);
            System.assertEquals('created', row.Status_Reason__c);
            System.assertEquals(cbvr.Id, row.CareBenefitVerifyRequest__c);
        } finally {
            CBV_ResultsApiV1.TEST_WEBHOOK_SECRET = null;
        }
    }
}
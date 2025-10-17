@IsTest(seeAllData=false)
private class BV_VerifyServiceTest {

    /* Settings you might change if your org is different */
    private static final String PLAN_ACCOUNT_FIELD   = 'MemberId';
    private static final String FALLBACK_SERVICETYPE = 'Surgery';
    private static final String FALLBACK_GENDER      = 'Male';

    // Stores the last HTTP request body captured by the mock
    private static String lastBody;

    /* Fake callouts used by tests */
    private class CaptureMock implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req){
            lastBody = req.getBody();
            HTTPResponse r = new HTTPResponse();
            r.setStatusCode(200);
            // You can include more keys here if you want to assert them later
            r.setBody('{"status":"Acknowledged","statusReason":"ok"}');
            return r;
        }
    }
    private class Http500Mock implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req){
            lastBody = req.getBody();
            HTTPResponse r = new HTTPResponse();
            r.setStatusCode(500);
            r.setBody('{"status":"Error","statusReason":"Internal Server Error"}');
            return r;
        }
    }
    private class ThrowMock implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req){
            lastBody = req.getBody();
            throw new CalloutException('socket timeout');
        }
    }

    /* Small helpers to build test data */

    private static Account makeAccount(String name){
        Account a = new Account(Name = name);
        insert a;
        return a;
    }

    private static void fillRequiredFields(SObject sobj, Id fallbackAccountId){
        Schema.DescribeSObjectResult sdesc = sobj.getSObjectType().getDescribe();
        Map<String, Schema.SObjectField> fmap = sdesc.fields.getMap();

        for (String api : fmap.keySet()) {
            Schema.DescribeFieldResult d = fmap.get(api).getDescribe();
            if (!d.isCreateable() || d.isCalculated() || d.isDefaultedOnCreate()) continue;
            if (d.isNillable()) continue;
            if (api == 'Id' || api == 'OwnerId' || api == 'RecordTypeId' || api.endsWith('__pc')) continue;
            if (sobj.get(api) != null) continue;

            switch on d.getType() {
                when STRING, EMAIL, URL, PHONE, TEXTAREA, ENCRYPTEDSTRING { sobj.put(api, 'x'); }
                when PICKLIST       {
                    List<Schema.PicklistEntry> opts = d.getPicklistValues();
                    if (!opts.isEmpty()) sobj.put(api, opts[0].getValue());
                }
                when MULTIPICKLIST  {
                    List<Schema.PicklistEntry> opts = d.getPicklistValues();
                    if (!opts.isEmpty()) sobj.put(api, new List<String>{ opts[0].getValue() });
                }
                when BOOLEAN        { sobj.put(api, true); }
                when INTEGER, DOUBLE, CURRENCY, PERCENT { sobj.put(api, 1); }
                when DATE           { sobj.put(api, Date.today()); }
                when DATETIME       { sobj.put(api, System.now()); }
                when TIME           { sobj.put(api, Time.newInstance(0,0,0,0)); }
                when REFERENCE {
                    List<Schema.SObjectType> targets = d.getReferenceTo();
                    Set<String> names = new Set<String>();
                    for (Schema.SObjectType t : targets) names.add(t.getDescribe().getName());
                    if (names.contains('Account') && fallbackAccountId != null) {
                        sobj.put(api, fallbackAccountId);
                    } else if (names.contains('User')) {
                        sobj.put(api, UserInfo.getUserId());
                    }
                }
                when else { /* do nothing */ }
            }
        }
    }

    private static String firstPickVal(Schema.DescribeFieldResult d, String fallback){
        for (Schema.PicklistEntry p : d.getPicklistValues()){
            String v = p.getValue();
            if (!String.isBlank(v)) return v;
        }
        return fallback;
    }

    private static Id makeMemberPlan(Id memberAccountId){
        Schema.SObjectField f = CareBenefitVerifyRequest__c.SObjectType
            .getDescribe().fields.getMap().get('Insurance_Information__c');
        Schema.SObjectType planType = f.getDescribe().getReferenceTo()[0];

        SObject plan = planType.newSObject(null, true);

        Map<String, Schema.SObjectField> pf = planType.getDescribe().fields.getMap();
        if (pf.containsKey(PLAN_ACCOUNT_FIELD)) plan.put(PLAN_ACCOUNT_FIELD, memberAccountId);
        if (pf.containsKey('Name'))         plan.put('Name', 'Plan UT');
        if (pf.containsKey('MemberNumber')) plan.put('MemberNumber', 'M-123');
        if (pf.containsKey('GroupNumber'))  plan.put('GroupNumber',  'G-123');
        if (pf.containsKey('PolicyNumber')) plan.put('PolicyNumber', 'P-123');

        fillRequiredFields(plan, memberAccountId);
        insert plan;
        return (Id) plan.get('Id');
    }

    private static CareBenefitVerifyRequest__c mkCbvr(){
        Account patient = makeAccount('John Doe');
        Id planId = makeMemberPlan(patient.Id);

        CareBenefitVerifyRequest__c cbvr = new CareBenefitVerifyRequest__c();

        cbvr.ServiceType__c = firstPickVal(
            CareBenefitVerifyRequest__c.ServiceType__c.getDescribe(), FALLBACK_SERVICETYPE
        );
        cbvr.Service_Date__c = Date.today();

        cbvr.Patient_First_Name__c = 'John';
        cbvr.Patient_Last_Name__c  = 'Doe';
        cbvr.Date_of_Birth__c      = Date.today().addYears(-30);
        cbvr.Gender__c = firstPickVal(
            CareBenefitVerifyRequest__c.Gender__c.getDescribe(), FALLBACK_GENDER
        );

        cbvr.Insurance_Provider_Name__c = 'Aetna';
        cbvr.Policy_Number__c           = 'P-123';
        cbvr.Group_Number__c            = 'G-123';

        cbvr.Provider_NPI__c        = '1234567890';
        cbvr.Provider_First_Name__c = 'Alice';
        cbvr.Provider_Last_Name__c  = 'Smith';

        cbvr.Insurance_Information__c = planId;

        fillRequiredFields(cbvr, patient.Id);
        insert cbvr;
        return cbvr;
    }

    private static void seedValidForVerification(Id cbvrId){
        update new CareBenefitVerifyRequest__c(
            Id                        = cbvrId,
            ServiceType__c            = firstPickVal(CareBenefitVerifyRequest__c.ServiceType__c.getDescribe(), FALLBACK_SERVICETYPE),
            Service_Date__c           = Date.today(),
            Patient_First_Name__c     = 'John',
            Patient_Last_Name__c      = 'Doe',
            Date_of_Birth__c          = Date.today().addYears(-30),
            Gender__c                 = firstPickVal(CareBenefitVerifyRequest__c.Gender__c.getDescribe(), FALLBACK_GENDER),
            Insurance_Provider_Name__c= 'Aetna',
            Policy_Number__c          = 'P-123',
            Group_Number__c           = 'G-123',
            Provider_NPI__c           = '1234567890',
            Provider_First_Name__c    = 'Alice',
            Provider_Last_Name__c     = 'Smith'
        );
    }

    /* Test cases */

    @IsTest
    static void success_updates_status_and_clears_error(){
        CareBenefitVerifyRequest__c cbvr = mkCbvr();

        update new CareBenefitVerifyRequest__c(
            Id = cbvr.Id, Last_Error__c = 'prev error'
        );

        seedValidForVerification(cbvr.Id);

        lastBody = null;
        Test.setMock(HttpCalloutMock.class, new CaptureMock());
        Test.startTest();
        BV_VerifyService.verify(cbvr.Id);
        Test.stopTest();

        CareBenefitVerifyRequest__c got = [
            SELECT Status__c, Status_Reason__c, Last_Error__c
            FROM CareBenefitVerifyRequest__c WHERE Id = :cbvr.Id
        ];
        System.assertEquals('Acknowledged', got.Status__c);
        System.assertEquals('ok',            got.Status_Reason__c);
        System.assertEquals(null,            got.Last_Error__c);

        System.assertNotEquals(null, lastBody, 'No callout body captured');
        Map<String,Object> root =
            (Map<String,Object>) JSON.deserializeUntyped(lastBody);
        System.assert(root.containsKey('patient'));
        System.assert(root.containsKey('insurance'));
        System.assert(root.containsKey('provider'));
    }

    @IsTest
    static void payload_includes_patient_insurance_provider(){
        CareBenefitVerifyRequest__c cbvr = mkCbvr();
        seedValidForVerification(cbvr.Id);

        lastBody = null;
        Test.setMock(HttpCalloutMock.class, new CaptureMock());
        Test.startTest();
        BV_VerifyService.verify(cbvr.Id);
        Test.stopTest();

        System.assertNotEquals(null, lastBody, 'No callout body captured');

        Map<String, Object> root =
            (Map<String, Object>) JSON.deserializeUntyped(lastBody);

        System.assert(root.containsKey('patient'),   'patient block missing');
        System.assert(root.containsKey('insurance'), 'insurance block missing');
        System.assert(root.containsKey('provider'),  'provider block missing');

        Map<String,Object> patient   = (Map<String,Object>) root.get('patient');
        Map<String,Object> insurance = (Map<String,Object>) root.get('insurance');
        Map<String,Object> provider  = (Map<String,Object>) root.get('provider');

        System.assert(patient.containsKey('firstName'));
        System.assert(patient.containsKey('lastName'));
        System.assert(patient.containsKey('dateOfBirth'));
        System.assert(patient.containsKey('gender'));

        System.assert(insurance.containsKey('providerName'));
        System.assert(insurance.containsKey('policyNumber'));
        System.assert(insurance.containsKey('groupNumber'));
        System.assert(insurance.containsKey('subscriberId'));

        System.assert(provider.containsKey('npi'));
        System.assert(provider.containsKey('firstName'));
        System.assert(provider.containsKey('lastName'));
    }

    @IsTest
    static void http_500_sets_callout_failed_and_logs_body(){
        CareBenefitVerifyRequest__c cbvr = mkCbvr();
        seedValidForVerification(cbvr.Id);

        lastBody = null;
        Test.setMock(HttpCalloutMock.class, new Http500Mock());
        Test.startTest();
        BV_VerifyService.verify(cbvr.Id);
        Test.stopTest();

        CareBenefitVerifyRequest__c got = [
            SELECT Status__c, Status_Reason__c, Last_Error__c
            FROM CareBenefitVerifyRequest__c WHERE Id = :cbvr.Id
        ];
        System.assertEquals('Error',          got.Status__c);
        System.assertEquals('Callout failed', got.Status_Reason__c);
        System.assert(!String.isBlank(got.Last_Error__c) &&
                      got.Last_Error__c.contains('Internal Server Error'),
                      'Last_Error__c should contain server message');
    }

    @IsTest
    static void exception_sets_callout_failed_reason(){
        CareBenefitVerifyRequest__c cbvr = mkCbvr();
        seedValidForVerification(cbvr.Id);

        lastBody = null;
        Test.setMock(HttpCalloutMock.class, new ThrowMock());
        Test.startTest();
        BV_VerifyService.verify(cbvr.Id);
        Test.stopTest();

        CareBenefitVerifyRequest__c got = [
            SELECT Status__c, Status_Reason__c
            FROM CareBenefitVerifyRequest__c WHERE Id = :cbvr.Id
        ];
        System.assertEquals('Error',          got.Status__c);
        System.assertEquals('Callout failed', got.Status_Reason__c);
    }

    @IsTest
    static void validation_blocks_callout_and_sets_error(){
        CareBenefitVerifyRequest__c cbvr = mkCbvr();

        // Intentionally make the NPI invalid (non-digits) to trigger the guard
        update new CareBenefitVerifyRequest__c(
            Id = cbvr.Id,
            Provider_NPI__c = 'ABC'
        );

        lastBody = null;
        Test.setMock(HttpCalloutMock.class, new CaptureMock());
        Test.startTest();
        BV_VerifyService.verify(cbvr.Id);
        Test.stopTest();

        System.assertEquals(null, lastBody, 'Callout should be blocked by validation');

        CareBenefitVerifyRequest__c got = [
            SELECT Status__c, Status_Reason__c, Last_Error__c
            FROM CareBenefitVerifyRequest__c
            WHERE Id = :cbvr.Id
        ];
        System.assertEquals('Error',             got.Status__c);
        System.assertEquals('Validation failed', got.Status_Reason__c);
        System.assert(!String.isBlank(got.Last_Error__c) &&
                      got.Last_Error__c.contains('Provider NPI'),
                      'Last_Error__c should list invalid field(s)');
    }
}

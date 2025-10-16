@IsTest
private class BV_CBVRSubmitterTest {

    @IsTest
    static void upsert_is_idempotent_and_persists_fields(){
        // Make a valid CBVR; the helper also fills External_Request_Id__c
        Id cbvrId = BV_CBVRQuickCreate.make('New');

        CareBenefitVerifyRequest__c cbvr = [
            SELECT Id, External_Request_Id__c
            FROM CareBenefitVerifyRequest__c
            WHERE Id = :cbvrId
        ];
        System.assertNotEquals(null, cbvr.External_Request_Id__c,
            'External_Request_Id__c should be set before submitting');

        Test.startTest();
        BV_CBVRSubmitter.SubmitResult r1 = BV_CBVRSubmitter.sendByCbvrId(
            cbvr.Id, 'Ready', 'Aetna PPO | Adam Turnel', 'Active', 'In network', 'EV-12345');
        BV_CBVRSubmitter.SubmitResult r2 = BV_CBVRSubmitter.sendByCbvrId(
            cbvr.Id, 'Ready', 'Aetna PPO | Adam Turnel', 'Active', 'In network', 'EV-12345');
        Test.stopTest();

        System.assertEquals(200, r1.statusCode, 'First submit should return 200');
        System.assertEquals(200, r2.statusCode, 'Second submit should return 200');
        System.assertNotEquals(null, r1.coverageBenefitId, 'coverageBenefitId should be returned');
        System.assertEquals(r1.coverageBenefitId, r2.coverageBenefitId,
            'Same externalId should upsert the same CoverageBenefit');

        CoverageBenefit__c cov = [
            SELECT Id, Name, Status__c, Status_Reason__c, External_Request_Id__c, CareBenefitVerifyRequest__c
            FROM CoverageBenefit__c
            WHERE Id = :r1.coverageBenefitId
            LIMIT 1
        ];
        System.assertEquals('Aetna PPO | Adam Turnel', cov.Name);
        System.assertEquals('Active',    cov.Status__c);
        System.assertEquals('In network',cov.Status_Reason__c);
        System.assertEquals('EV-12345',  cov.External_Request_Id__c);
        System.assertEquals(cbvr.Id,     cov.CareBenefitVerifyRequest__c);
    }
}
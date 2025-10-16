trigger CBVR_SetExternalId on CareBenefitVerifyRequest__c (after insert) {
    List<CareBenefitVerifyRequest__c> ups = new List<CareBenefitVerifyRequest__c>();
    for (CareBenefitVerifyRequest__c r : Trigger.new) {
        if (String.isBlank(r.External_Request_Id__c)) {
            ups.add(new CareBenefitVerifyRequest__c(
                Id = r.Id,
                External_Request_Id__c = 'CBVR-' + r.Id
            ));
        }
    }
    if (!ups.isEmpty()) update ups;
}
public with sharing class BV_VerifyService {

    /* Data types Flow can send in and get back */
    public class RequestItem {
        @InvocableVariable(required=true) public Id recordId;
        public RequestItem() {}
        public RequestItem(Id idVal) { recordId = idVal; }
    }
    public class ResultItem {
        @InvocableVariable public Id      recordId;
        @InvocableVariable public Integer statusCode;
        @InvocableVariable public String  responseBody;
        @InvocableVariable public String  error;
    }

    // Validation helpers
    private class ValidationException extends Exception {}

    // Stop and throw an error if required fields are missing or invalid
    private static void validateOrThrow(CareBenefitVerifyRequest__c rec){
        List<String> errs = new List<String>();

        // Service details
        if (String.isBlank(rec.ServiceType__c)) errs.add('Service Type');
        if (rec.Service_Date__c == null)        errs.add('Service Date');

        // Patient
        if (String.isBlank(rec.Patient_First_Name__c)) errs.add('Patient First Name');
        if (String.isBlank(rec.Patient_Last_Name__c))  errs.add('Patient Last Name');
        if (rec.Date_of_Birth__c == null)              errs.add('Patient Date of Birth');
        if (String.isBlank(rec.Gender__c))             errs.add('Patient Gender');

        // Insurance (as per assignment)
        if (String.isBlank(rec.Insurance_Provider_Name__c)) errs.add('Insurance Provider Name');
        if (String.isBlank(rec.Policy_Number__c))           errs.add('Policy Number');
        if (String.isBlank(rec.Group_Number__c))            errs.add('Group Number');

        // Provider
        if (String.isBlank(rec.Provider_NPI__c)) {
            errs.add('Provider NPI');
        } else {
            String digits = rec.Provider_NPI__c.replaceAll('[^0-9]','');
            if (digits.length() != 10) errs.add('Provider NPI must be 10 digits');
        }
        if (String.isBlank(rec.Provider_First_Name__c)) errs.add('Provider First Name');
        if (String.isBlank(rec.Provider_Last_Name__c))  errs.add('Provider Last Name');

        if (!errs.isEmpty()) {
            throw new ValidationException('Missing/invalid: ' + String.join(errs, ', '));
        }
    }

    @InvocableMethod(
        label='Verify Benefits'
        description='Sends selected CareBenefitVerifyRequest__c records to the vendor and returns status & body.'
    )
    public static List<ResultItem> run(List<RequestItem> items) {
        // Gather valid record Ids (skip nulls)
        Set<Id> ids = new Set<Id>();
        for (RequestItem r : items) if (r != null && r.recordId != null) ids.add(r.recordId);

        List<ResultItem> results = new List<ResultItem>();
        if (ids.isEmpty()) return results;

        // Fetch just the fields needed
        Map<Id, CareBenefitVerifyRequest__c> reqs = new Map<Id, CareBenefitVerifyRequest__c>(
            [SELECT Id, Name, ServiceType__c, Service_Date__c, ICD10__c, CPT__c, External_Request_Id__c,
                    Patient_First_Name__c, Patient_Last_Name__c, Date_of_Birth__c, Gender__c,
                    Insurance_Provider_Name__c, Policy_Number__c, Group_Number__c,
                    Provider_NPI__c, Provider_First_Name__c, Provider_Last_Name__c,
                    Insurance_Information__c
               FROM CareBenefitVerifyRequest__c
              WHERE Id IN :ids]
        );

        for (RequestItem i : items) {
            ResultItem r = new ResultItem();
            r.recordId = i.recordId;

            CareBenefitVerifyRequest__c rec = reqs.get(i.recordId);
            if (rec == null) {
                r.error = 'Record not found';
                results.add(r);
                continue;
            }

            try {
                // Try to set External_Request_Id__c; if it fails, ignore and continue
                try {
                    if (String.isBlank(rec.External_Request_Id__c)) {
                        update new CareBenefitVerifyRequest__c(
                            Id = rec.Id,
                            External_Request_Id__c = rec.Id
                        );
                        rec.External_Request_Id__c = rec.Id; // local copy
                    }
                } catch (Exception ignore) {}

                // Validate before building and sending
                validateOrThrow(rec);

                // Build the JSON body the vendor expects
                Map<String, Object> payload = new Map<String, Object>{
                    'requestId'         => String.valueOf(rec.Id),
                    'externalRequestId' => rec.External_Request_Id__c,
                    'name'              => rec.Name,
                    'serviceType'       => rec.ServiceType__c,
                    'serviceDate'       => (rec.Service_Date__c != null ? rec.Service_Date__c.format() : null),
                    'icd10'             => rec.ICD10__c,
                    'cpt'               => rec.CPT__c
                };

                // Add patient, insurance, and provider sections
                Map<String,Object> patient = new Map<String,Object>{
                    'firstName'   => rec.Patient_First_Name__c,
                    'lastName'    => rec.Patient_Last_Name__c,
                    'dateOfBirth' => (rec.Date_of_Birth__c != null ? rec.Date_of_Birth__c.format() : null),
                    'gender'      => rec.Gender__c
                };
                Map<String,Object> insurance = new Map<String,Object>{
                    'providerName' => rec.Insurance_Provider_Name__c,
                    'policyNumber' => rec.Policy_Number__c,
                    'groupNumber'  => rec.Group_Number__c,
                    // subscriberId could be sourced from plan if present; not mandatory for send
                    'subscriberId' => null
                };
                Map<String,Object> provider = new Map<String,Object>{
                    'npi'       => rec.Provider_NPI__c,
                    'firstName' => rec.Provider_First_Name__c,
                    'lastName'  => rec.Provider_Last_Name__c
                };
                payload.put('patient',   patient);
                payload.put('insurance', insurance);
                payload.put('provider',  provider);

                String body = JSON.serialize(payload);

                // Send the request to the vendor API
                HttpResponse resp = BV_Client.verify(body);
                r.statusCode   = resp.getStatusCode();
                r.responseBody = resp.getBody();

                // Save status/reason from the response and clear Last_Error__c
                try {
                    Map<String,Object> parsed =
                        (Map<String,Object>) JSON.deserializeUntyped(r.responseBody);
                    String status = (String) parsed.get('status');
                    String reason = (String) parsed.get('statusReason');

                    update new CareBenefitVerifyRequest__c(
                        Id                     = rec.Id,
                        External_Request_Id__c = rec.External_Request_Id__c,
                        Status__c              = status,
                        Status_Reason__c       = reason,
                        Last_Error__c          = null
                    );
                } catch (Exception ignore) {
                    // If response isn’t JSON, still clear any previous error text
                    update new CareBenefitVerifyRequest__c(
                        Id            = rec.Id,
                        Last_Error__c = null
                    );
                }

            } catch (ValidationException vex) {
                // If validation fails, set a clear error and do not make the callout
                r.error = vex.getMessage();
                update new CareBenefitVerifyRequest__c(
                    Id               = rec.Id,
                    Status__c        = 'Error',
                    Status_Reason__c = 'Validation failed',
                    Last_Error__c    = vex.getMessage()
                );

            } catch (Exception ex) {
                // Handle callout/network/server errors
                r.error = ex.getMessage();
                update new CareBenefitVerifyRequest__c(
                    Id               = rec.Id,
                    Status__c        = 'Error',
                    Status_Reason__c = 'Callout failed',
                    Last_Error__c    = ex.getMessage()
                );
            }

            results.add(r);
        }
        return results;
    }

    // Helper methods to make calling this easier from Apex
    public static List<ResultItem> verify(Id cbvrId) {
        return run(new List<RequestItem>{ new RequestItem(cbvrId) });
    }
    public static List<ResultItem> verify(List<Id> cbvrIds) {
        List<RequestItem> items = new List<RequestItem>();
        for (Id idVal : cbvrIds) items.add(new RequestItem(idVal));
        return run(items);
    }
}
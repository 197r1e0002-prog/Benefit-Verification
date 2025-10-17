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

        // Fetch just the fields needed (include related name for optional coverage benefit)
        Map<Id, CareBenefitVerifyRequest__c> reqs = new Map<Id, CareBenefitVerifyRequest__c>(
            [SELECT Id, Name, ServiceType__c, Service_Date__c, ICD10__c, CPT__c, External_Request_Id__c,
                    Patient_First_Name__c, Patient_Last_Name__c, Date_of_Birth__c, Gender__c,
                    Insurance_Provider_Name__c, Policy_Number__c, Group_Number__c,
                    Provider_NPI__c, Provider_First_Name__c, Provider_Last_Name__c,
                    Insurance_Information__c, Insurance_Information__r.Name
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

                // === BEGIN: write back to CBVR from response ===
                if (r.statusCode >= 200 && r.statusCode < 300) {
                    try {
                        Map<String,Object> parsed =
                            (Map<String,Object>) JSON.deserializeUntyped(r.responseBody);

                        // unwrap httpbin-style {"json":{...}} if present
                        if (parsed != null && parsed.containsKey('json') && parsed.get('json') != null) {
                            parsed = (Map<String,Object>) parsed.get('json');
                        }

                        String status       = (parsed == null) ? null : (String) parsed.get('status');
                        String statusReason = (parsed == null) ? null : (String) parsed.get('statusReason');
                        String extReqId     = (parsed == null) ? null : (String) parsed.get('externalRequestId');
                        String planName     = (parsed == null) ? null : (String) parsed.get('name');
                        String serviceType  = (parsed == null) ? null : (String) parsed.get('serviceType');

                        Date serviceDate = null;
                        if (parsed != null && parsed.get('serviceDate') != null) {
                            String sd = String.valueOf(parsed.get('serviceDate'));
                            if (sd != null && sd.length() >= 10) {
                                try { serviceDate = Date.valueOf(sd.substring(0, 10)); } catch (Exception ignore) {}
                            }
                        }

                        // Defaults to match the assignment when API omits them
                        if (String.isBlank(status))       status       = 'Acknowledged';
                        if (String.isBlank(statusReason)) statusReason = 'Care Benefit Verification Request successfully sent to Benefits Verification Provider.';

                        // Write back to CBVR
                        update new CareBenefitVerifyRequest__c(
                            Id                     = rec.Id,
                            External_Request_Id__c = String.isBlank(extReqId) ? rec.External_Request_Id__c : extReqId,
                            Status__c              = status,
                            Status_Reason__c       = statusReason,
                            ServiceType__c         = String.isBlank(serviceType) ? rec.ServiceType__c : serviceType,
                            Service_Date__c        = (serviceDate == null ? rec.Service_Date__c : serviceDate),
                            Last_Error__c          = null
                        );

                        // OPTIONAL: create one Coverage Benefit when acknowledged
                        try {
                            if (status == 'Acknowledged') {
                                // avoid duplicates for the same CBVR
                                Boolean exists = ![
                                    SELECT Id FROM CoverageBenefit__c
                                    WHERE CareBenefitVerifyRequest__c = :rec.Id
                                    LIMIT 1
                                ].isEmpty();

                                if (!exists) {
                                    CoverageBenefit__c cb = new CoverageBenefit__c(
                                        CareBenefitVerifyRequest__c = rec.Id,
                                        Name                         = String.isBlank(planName)
                                                                          ? (rec.Insurance_Information__r != null
                                                                                ? rec.Insurance_Information__r.Name
                                                                                : 'Coverage Benefit')
                                                                          : planName,
                                        Status__c                    = 'Active',
                                        Status_Reason__c             = 'In network',
                                        External_Request_Id__c       = String.isBlank(extReqId)
                                                                          ? rec.External_Request_Id__c
                                                                          : extReqId
                                    );
                                    insert cb;
                                }
                            }
                        } catch (Exception ignore) {}
                    } catch (Exception ignore) {
                        // If parsing failed but callout is OK, at least clear the error
                        update new CareBenefitVerifyRequest__c(
                            Id            = rec.Id,
                            Last_Error__c = null
                        );
                    }
                } else {
                    // Non-2xx response: mark CBVR as error with response body
                    update new CareBenefitVerifyRequest__c(
                        Id               = rec.Id,
                        Status__c        = 'Error',
                        Status_Reason__c = 'Callout failed',
                        Last_Error__c    = r.responseBody
                    );
                }
                // === END: write back to CBVR from response ===

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

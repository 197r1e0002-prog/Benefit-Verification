public with sharing class BV_ResponseParser_Invocable {

    /* What the flow sends in and what it gets back */

    public class Inp {
        @InvocableVariable /* (required=false) */
        public String responseBody;     // now optional
        @InvocableVariable
        public Id cbvrId;
    }

    public class Out {
        @InvocableVariable public String externalRequestId;
        @InvocableVariable public String requestId;
        @InvocableVariable public Date   serviceDate;
        @InvocableVariable public String serviceType;
        @InvocableVariable public String name; // Plan name
    }

    /* Main invocable method */

    @InvocableMethod(label='Parse Verify JSON'
                     description='Extracts verify response fields; falls back to CBVR fields if missing.')
    public static List<Out> run(List<Inp> reqs){
        List<Out> outs = new List<Out>();

        for (Inp r : reqs) {
            Out o = new Out();

            // 1) Try to read fields directly from the JSON (works with httpbin {"json":{...}} or a flat root)
            if (!String.isBlank(r.responseBody)) {
                try {
                    Map<String,Object> root = (Map<String,Object>) JSON.deserializeUntyped(r.responseBody);
                    Map<String,Object> json = (root != null && root.containsKey('json') && root.get('json') != null)
                        ? (Map<String,Object>) root.get('json')
                        : root;

                    if (json != null) {
                        o.externalRequestId = toStr(json.get('externalRequestId'));
                        o.requestId         = toStr(json.get('requestId'));
                        o.serviceType       = toStr(json.get('serviceType'));
                        o.name              = toStr(json.get('name'));

                        String sd = toStr(json.get('serviceDate')); // Could be a date or a datetime string
                        if (!String.isBlank(sd) && sd.length() >= 10) {
                            try { o.serviceDate = Date.valueOf(sd.substring(0, 10)); } catch (Exception ignore) {}
                        }
                    }
                } catch (Exception ignore) {
                    // If JSON parsing fails, we’ll try to fill values from CBVR instead
                }
            }

            // 2) For anything still missing, pull values from the CBVR record
            if (r.cbvrId != null) {
                try {
                    CareBenefitVerifyRequest__c cbvr = [
                        SELECT Id, ServiceType__c, Service_Date__c, External_Request_Id__c,
                               Insurance_Information__r.Name
                        FROM CareBenefitVerifyRequest__c
                        WHERE Id = :r.cbvrId
                        LIMIT 1
                    ];

                    if (isBlank(o.name) && cbvr.Insurance_Information__r != null)
                        o.name = cbvr.Insurance_Information__r.Name;

                    if (isBlank(o.serviceType))
                        o.serviceType = cbvr.ServiceType__c;

                    if (o.serviceDate == null)
                        o.serviceDate = cbvr.Service_Date__c;

                    if (isBlank(o.externalRequestId))
                        o.externalRequestId = cbvr.External_Request_Id__c;

                    if (isBlank(o.requestId))
                        o.requestId = String.valueOf(cbvr.Id);

                } catch (Exception ignore) {
                    // Don’t break the flow if we can’t read the CBVR
                }
            }

            outs.add(o);
        }
        return outs;
    }

    /* Small helper methods */

    private static String toStr(Object o) { return (o == null) ? null : String.valueOf(o); }

    // Null/empty/whitespace check that’s safe for strings
    private static Boolean isBlank(String s) {
        return String.isBlank(s); // true when null, empty, or only spaces
        // Alternative without String.isBlank: return (s == null || s.trim().length() == 0);
    }
}
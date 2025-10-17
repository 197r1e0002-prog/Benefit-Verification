public with sharing class BV_ResponseParser_Invocable {

    /* ===== Inputs / Outputs ===== */

    public class Inp {
        @InvocableVariable(required=false)
        public String responseBody;     // raw response; can be blank
        @InvocableVariable(required=false)
        public Id cbvrId;               // optional; for fallbacks
    }

    public class Out {
        // NEW: always provide these so the Flow can show/update status
        @InvocableVariable public String status;
        @InvocableVariable public String statusReason;

        @InvocableVariable public String externalRequestId;
        @InvocableVariable public String requestId;
        @InvocableVariable public Date   serviceDate;
        @InvocableVariable public String serviceType;
        @InvocableVariable public String name; // plan name
    }

    /* ===== Invocable ===== */

    @InvocableMethod(label='Parse Verify JSON'
                     description='Extracts verify response fields; defaults status to Acknowledged; falls back to CBVR when missing.')
    public static List<Out> run(List<Inp> reqs){
        List<Out> outs = new List<Out>();

        for (Inp r : reqs) {
            Out o = new Out();

            // Defaults you asked for (used when the vendor doesn’t send status fields)
            o.status       = 'Acknowledged';
            o.statusReason = 'Care Benefit Verification Request successfully sent to Benefits Verification Provider.';

            // 1) Parse from response JSON (supports httpbin {"json":{...}} or direct root)
            if (!String.isBlank(r.responseBody)) {
                try {
                    Map<String,Object> root = (Map<String,Object>) JSON.deserializeUntyped(r.responseBody);
                    Map<String,Object> json = (root != null && root.containsKey('json') && root.get('json') != null)
                        ? (Map<String,Object>) root.get('json')
                        : root;

                    if (json != null) {
                        // If the vendor supplied status/ reason, use them (overwrite defaults)
                        String st = toStr(json.get('status'));
                        String sr = toStr(json.get('statusReason'));
                        if (!String.isBlank(st)) o.status = st;
                        if (!String.isBlank(sr)) o.statusReason = sr;

                        o.externalRequestId = toStr(json.get('externalRequestId'));
                        o.requestId         = toStr(json.get('requestId'));
                        o.serviceType       = toStr(json.get('serviceType'));
                        o.name              = toStr(json.get('name'));

                        String sd = toStr(json.get('serviceDate')); // date or datetime
                        if (!String.isBlank(sd) && sd.length() >= 10) {
                            try { o.serviceDate = Date.valueOf(sd.substring(0, 10)); } catch (Exception ignore) {}
                        }
                    }
                } catch (Exception ignore) {
                    // ignore bad JSON; we’ll fill from CBVR if possible
                }
            }

            // 2) Fallbacks from CBVR for any fields still blank (we keep status defaults)
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

                    // Note: we intentionally do NOT overwrite o.status / o.statusReason here.
                    // They already default to "Acknowledged" + message, or vendor-provided values if present.

                } catch (Exception ignore) {
                    // do nothing; keep whatever we already set
                }
            }

            outs.add(o);
        }
        return outs;
    }

    /* ===== Helpers ===== */

    private static String toStr(Object o) { return (o == null) ? null : String.valueOf(o); }
    private static Boolean isBlank(String s) { return String.isBlank(s); }
}

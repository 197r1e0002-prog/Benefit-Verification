public with sharing class BV_CBVRSubmitter {

    public class SubmitResult {
        public Integer statusCode;
        public Id cbvrId;
        public Id coverageBenefitId;
    }

    /* Grab the security key from the BV_Settings custom metadata, and don’t break if different orgs name things a bit differently. */
    private static String getWebhookSecret() {
        try {
            return [
                SELECT Webhook_Secret__c
                FROM BV_Settings__mdt
                WHERE DeveloperName = 'Default'
                LIMIT 1
            ].Webhook_Secret__c;
        } catch (Exception e) {
            // If the exact DeveloperName isn’t found (because sandboxes/prod differ), just use any available settings record.
            List<BV_Settings__mdt> rows = [
                SELECT Webhook_Secret__c
                FROM BV_Settings__mdt
                LIMIT 1
            ];
            return rows.isEmpty() ? null : rows[0].Webhook_Secret__c;
        }
    }

    /**
     Send a small, valid JSON to that REST URL (the vendor will call the same one), then read the response and give back the IDs and status.
     */
    public static SubmitResult sendByCbvrId(
        Id cbvrId,
        String cbvrStatus,
        String covName,
        String covStatus,
        String covReason,
        String covExternalId
    ){
        // The API expects the request body in a specific shape—especially make sure coverage is an array/list.
        Map<String,Object> coverageRow = new Map<String,Object>{
            'name'         => covName,
            'status'       => covStatus,
            'statusReason' => covReason,
            'externalId'   => covExternalId
        };
        Map<String,Object> body = new Map<String,Object>{
            'cbvrId'            => (String) cbvrId,
            'externalRequestId' => (String) cbvrId,   // keeps CBVR.External_Request_Id__c in sync
            'status'            => cbvrStatus,
            'coverage'          => new List<Object>{ coverageRow }
        };

        RestRequest  req = new RestRequest();
        RestResponse res = new RestResponse();
        req.httpMethod  = 'POST';
        req.requestURI  = '/services/apexrest/cbv/results/v1';
        req.addHeader('Content-Type', 'application/json');

        // Add the special security header with the guard secret, or the endpoint will reject the call.
        String secret = getWebhookSecret();
        if (!String.isBlank(secret)) {
            req.addHeader('x-bv-webhook-secret', secret);
        }

        req.requestBody       = Blob.valueOf(JSON.serialize(body));
        RestContext.request   = req;
        RestContext.response  = res;

        // Call the REST endpoint yourself (no extra wrappers) to test the full flow end-to-end.
        BV_ResultsApiV1.receive();

        SubmitResult out = new SubmitResult();
        out.statusCode = res.statusCode;

        if (res.responseBody != null) {
            Map<String,Object> resp =
                (Map<String,Object>) JSON.deserializeUntyped(res.responseBody.toString());

            if (resp.containsKey('cbvrId') && resp.get('cbvrId') != null) {
                out.cbvrId = (Id) (String) resp.get('cbvrId');
            }
            if (resp.containsKey('coverageBenefitIds')) {
                List<Object> ids = (List<Object>) resp.get('coverageBenefitIds');
                if (!ids.isEmpty() && ids[0] != null) {
                    out.coverageBenefitId = (Id) (String) ids[0];
                }
            }
        }
        return out;
    }
}
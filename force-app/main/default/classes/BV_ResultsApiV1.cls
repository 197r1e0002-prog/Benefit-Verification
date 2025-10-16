@RestResource(urlMapping='/bv/results/v1')
global with sharing class BV_ResultsApiV1 {

    // TEST HOOK: allow tests to set the secret without creating CMDT records
    @TestVisible
    static String TEST_WEBHOOK_SECRET = null;

    /* Helpers: normalize input text */
    private static String norm(String s){
        if (s == null) return null;
        String t = s.trim().toLowerCase();
        t = t.replace('_',' ').replace('-', ' ');
        t = t.replaceAll('\\s+',' ');
        return t;
    }

    // Allowed values and synonyms for CBVR.Status__c
    private static final Map<String,String> CBVR_ALLOWED = new Map<String,String>{
        'new'=>'New','ready'=>'Ready','submitted'=>'Submitted','acknowledged'=>'Acknowledged',
        'queued'=>'Queued','in progress'=>'In Progress','needs info'=>'Needs Info',
        'error'=>'Error','cancelled'=>'Cancelled'
    };
    private static final Map<String,String> CBVR_SYNONYMS = new Map<String,String>{
        'complete'=>'Ready','completed'=>'Ready','done'=>'Ready','ack'=>'Acknowledged',
        'processing'=>'In Progress','in_progress'=>'In Progress','failed'=>'Error',
        'canceled'=>'Cancelled','need info'=>'Needs Info','missing info'=>'Needs Info'
    };

    // Allowed values and synonyms for CoverageBenefit__c.Status__c
    private static final Map<String,String> COV_ALLOWED = new Map<String,String>{
        'active'=>'Active','inactive'=>'Inactive','terminated'=>'Terminated','pending'=>'Pending',
        'not found'=>'Not Found','not covered'=>'Not Covered','limited'=>'Limited','unknown'=>'Unknown'
    };
    private static final Map<String,String> COV_SYNONYMS = new Map<String,String>{
        'not_found'=>'Not Found','not_covered'=>'Not Covered'
    };

    private static String translateOrFail(String raw, Map<String,String> syn, Map<String,String> allowed, String label){
        if (raw == null) return null;
        String key = norm(raw);
        if (syn.containsKey(key)) return syn.get(key);
        if (allowed.containsKey(key)) return allowed.get(key);
        throw new ClientException(label + ' not recognized: ' + raw);
    }

    /* Data shapes for requests and responses */
    global class CoverageIn { public String externalId, name, status, statusReason; }
    global class RequestIn  {
        public Id cbvrId;
        public String externalRequestId;
        public String status, statusReason;
        public List<CoverageIn> coverage;
    }
    global class ResponseOut {
        public Boolean ok;
        public String  message;
        public Id      cbvrId;
        public List<Id> coverageBenefitIds = new List<Id>();
        public List<Boolean> createdFlags  = new List<Boolean>();
    }

    /* REST endpoint entry point */
    @HttpPost
    global static ResponseOut receive(){
        RestRequest req = RestContext.request;
        RestResponse res = RestContext.response;
        res.addHeader('Content-Type','application/json');

        try {
            // Incoming auth check (skip if no secret is set)
            // Use the test override if present; otherwise read from config (CMDT)
            String configuredSecret = (TEST_WEBHOOK_SECRET != null)
                ? TEST_WEBHOOK_SECRET
                : BV_Config.get().webhookSecret;  // reads from your existing config utility

            if (!String.isBlank(configuredSecret)) {
                String header = req.headers.get('x-bv-webhook-secret');
                if (String.isBlank(header) || header != configuredSecret) {
                    return writeErr(res, 401, 'Unauthorized');
                }
            }

            if (req.requestBody == null) throw new ClientException('Empty body');
            RequestIn body = (RequestIn) JSON.deserialize(req.requestBody.toString(), RequestIn.class);

            // Find the CBVR by Id or by External_Request_Id__c
            CareBenefitVerifyRequest__c cbvr;
            if (body.cbvrId != null) {
                cbvr = [SELECT Id, External_Request_Id__c FROM CareBenefitVerifyRequest__c WHERE Id = :body.cbvrId LIMIT 1];
            } else if (!String.isBlank(body.externalRequestId)) {
                cbvr = [SELECT Id, External_Request_Id__c FROM CareBenefitVerifyRequest__c WHERE External_Request_Id__c = :body.externalRequestId LIMIT 1];
            } else {
                throw new ClientException('Provide either cbvrId or externalRequestId');
            }
            Id cbvrId = cbvr.Id;

            // If externalRequestId is provided, save it on the CBVR (safe to repeat)
            if (!String.isBlank(body.externalRequestId) && String.isBlank(cbvr.External_Request_Id__c)) {
                update new CareBenefitVerifyRequest__c(
                    Id = cbvrId,
                    External_Request_Id__c = body.externalRequestId
                );
            }

            // Convert CBVR status text to a valid value if sent
            String cbvrStatus = translateOrFail(body.status, CBVR_SYNONYMS, CBVR_ALLOWED, 'CBVR status');
            String cbvrReason = body.statusReason;

            // Build CoverageBenefit records and upsert using External_Request_Id__c
            if (body.coverage == null || body.coverage.isEmpty())
                throw new ClientException('coverage[] is required (at least one item)');

            List<CoverageBenefit__c> rows = new List<CoverageBenefit__c>();
            for (CoverageIn c : body.coverage) {
                if (c == null) continue;
                if (String.isBlank(c.externalId)) throw new ClientException('coverage.externalId is required');

                CoverageBenefit__c row = new CoverageBenefit__c();
                row.External_Request_Id__c      = c.externalId;                               // upsert key
                row.CareBenefitVerifyRequest__c = cbvrId;
                if (!String.isBlank(c.name))         row.Name             = c.name;
                if (c.status != null)                row.Status__c        = translateOrFail(c.status, COV_SYNONYMS, COV_ALLOWED, 'CoverageBenefit status');
                if (!String.isBlank(c.statusReason)) row.Status_Reason__c = c.statusReason;

                rows.add(row);
            }

            Database.UpsertResult[] results =
                Database.upsert(rows, CoverageBenefit__c.External_Request_Id__c, false);

            // Update CBVR if status or reason is provided
            Boolean touched = false;
            CareBenefitVerifyRequest__c cbvrUpd = new CareBenefitVerifyRequest__c(Id = cbvrId);
            if (cbvrStatus != null)         { cbvrUpd.Status__c        = cbvrStatus;  touched = true; }
            if (!String.isBlank(cbvrReason)) { cbvrUpd.Status_Reason__c = cbvrReason; touched = true; }
            if (touched) update cbvrUpd;

            // Build and return the response payload
            ResponseOut out = new ResponseOut();
            out.ok = true; out.cbvrId = cbvrId;
            for (Database.UpsertResult r : results) {
                out.coverageBenefitIds.add(r.getId());
                out.createdFlags.add(r.isCreated());
            }
            res.statusCode = 200;
            res.responseBody = Blob.valueOf(JSON.serialize(out));
            return out;

        } catch (QueryException qe) {
            return writeErr(res, 404, 'CBVR not found: ' + qe.getMessage());
        } catch (ClientException ce) {
            return writeErr(res, 400, ce.getMessage());
        } catch (DmlException de) {
            return writeErr(res, 400, 'DML error: ' + de.getDmlMessage(0));
        } catch (Exception e) {
            return writeErr(res, 500, 'Unexpected error: ' + e.getMessage());
        }
    }

    /* Error helpers */
    private class ClientException extends Exception {}
    private static ResponseOut writeErr(RestResponse res, Integer code, String msg){
        res.statusCode = code;
        ResponseOut out = new ResponseOut();
        out.ok = false; out.message = msg;
        res.responseBody = Blob.valueOf(JSON.serialize(out));
        return out;
    }
}
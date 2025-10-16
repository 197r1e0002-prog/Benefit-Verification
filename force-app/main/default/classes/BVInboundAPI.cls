@RestResource(urlMapping='/care-benefit-verification-results')
global with sharing class BVInboundAPI {

    // Simple data class to read the JSON request
    global class ResultDTO {
        public String status;
        public String statusReason;
        public String externalCorrelationId; // ID of the CBVR record
    }

    @HttpPost
    global static void createCoverageBenefit() {
        try {
            // Read and parse the request body
            ResultDTO body = (ResultDTO) JSON.deserialize(
                RestContext.request.requestBody.toString(),
                ResultDTO.class
            );

            if (String.isBlank(body.externalCorrelationId)) {
                RestContext.response.statusCode = 400;
                RestContext.response.responseBody =
                    Blob.valueOf('{"error":"Missing externalCorrelationId"}');
                return;
            }

            // Find the CBVR; if it isn’t there, return 404 instead of throwing an error
            List<CareBenefitVerifyRequest__c> rows = [
                SELECT Id
                FROM CareBenefitVerifyRequest__c
                WHERE Id = :body.externalCorrelationId
                LIMIT 1
            ];
            if (rows.isEmpty()) {
                RestContext.response.statusCode = 404;
                RestContext.response.responseBody =
                    Blob.valueOf('{"error":"CareBenefitVerifyRequest not found for Id ' +
                                 JSON.serialize(body.externalCorrelationId) + '"}');
                return;
            }

            // Create the CoverageBenefit record (use your org’s field API names)
            CoverageBenefit__c cb = new CoverageBenefit__c(
                CareBenefitVerifyRequest__c = rows[0].Id,
                Status__c        = body.status,
                Status_Reason__c = body.statusReason
            );
            insert cb;

            RestContext.response.statusCode = 201; // Created
        } catch (Exception e) {
            RestContext.response.statusCode = 500;
            RestContext.response.responseBody =
                Blob.valueOf('{"error":' + JSON.serialize(e.getMessage()) + '}');
        }
    }
}
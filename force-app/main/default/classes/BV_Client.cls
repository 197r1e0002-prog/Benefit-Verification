public with sharing class BV_Client {

    /** Simple GET to /health */
    public static HttpResponse healthCheck() {
        BV_Config.Cfg cfg = BV_Config.get();
        return get(cfg.healthPath);
    }

    /** Send the verify request as JSON */
    public static HttpResponse verify(String jsonBody) {
        BV_Config.Cfg cfg = BV_Config.get();
        return postJson(cfg.verifyPath, jsonBody);
    }

    /* =========================
       Core helpers
       ========================= */

    private static HttpResponse get(String path) {
        HttpRequest req = build('GET', path, null);
        return send(req);
    }

    private static HttpResponse postJson(String path, String body) {
        HttpRequest req = build('POST', path, body);
        req.setHeader('Content-Type', 'application/json');
        return send(req);
    }

    /** Create an HttpRequest using the Named Credential and a relative path */
    private static HttpRequest build(String method, String path, String body) {
        BV_Config.Cfg cfg = BV_Config.get();

        // Clean up the path so it has exactly one leading slash
        if (String.isBlank(path)) {
            path = '';
        } else if (!path.startsWith('/')) {
            path = '/' + path;
        }

        HttpRequest req = new HttpRequest();
        req.setMethod(method);
        req.setTimeout(cfg.timeoutMs);

        // Example: callout:BV_BenefitVerification/health
        String endpoint = cfg.calloutPrefix() + path;
        req.setEndpoint(endpoint);

        // Add the webhook secret header if configured
        if (!String.isBlank(cfg.webhookSecret)) {
            req.setHeader('x-bv-webhook-secret', cfg.webhookSecret);
        }
        if (body != null) req.setBody(body);

        return req;
    }

    /**
     * Send the request with simple retry logic for HTTP 5xx responses,
     * retrying up to Retry_Limit__c times. Always returns the last response.
     */
    private static HttpResponse send(HttpRequest req) {
        BV_Config.Cfg cfg = BV_Config.get();
        Http http = new Http();
        HttpResponse res;
        Integer attempts = 0;
        Integer maxAttempts = Math.max(0, cfg.retryLimit) + 1; // first try + retries

        while (true) {
            attempts++;
            res = http.send(req);
            Integer code = res.getStatusCode();

            // Retry only on 5xx if we still have attempts left
            if (code >= 500 && code < 600 && attempts < maxAttempts) {
                System.debug(LoggingLevel.WARN, 'BV_Client retry #' + attempts + ' after ' + code);
                continue;
            }
            break;
        }
        return res;
    }
}
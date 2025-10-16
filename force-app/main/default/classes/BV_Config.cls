public with sharing class BV_Config {

    // Keep a single in-memory copy
    private static BV_Config.Cfg cachedCfg;

    /** Simple settings holder other classes can use */
    public class Cfg {
        public String  devName;                 // e.g., 'Default'
        public Boolean useExternalCredential;   // from CMDT (for info)
        public String  namedCredentialName;     // e.g., BV_BenefitVerification
        public String  externalCredentialName;  // e.g., BV_Basic_Auth
        public String  healthPath;              // e.g., /health
        public String  verifyPath;              // e.g., /benefit-verification-request
        public String  callbackPath;            // optional
        public Integer retryLimit;              // 0 or higher
        public Integer timeoutMs;               // milliseconds
        public String  webhookSecret;           // optional

        /** Always return the Named Credential callout prefix */
        public String calloutPrefix() {
            if (String.isBlank(namedCredentialName)) {
                // If setup is missing, throw a clear error
                throw new AuraHandledException('BV_Config: Named Credential Name is blank in BV_Settings__mdt.');
            }
            return 'callout:' + namedCredentialName.trim();
        }
    }

    /** Get the config (loads the “Default” CMDT row) */
    public static Cfg get() {
        if (cachedCfg != null) return cachedCfg;

        BV_Settings__mdt row = [
            SELECT DeveloperName,
                   Use_External_Credential__c,
                   Named_Credential_Name__c,
                   External_Credential_Name__c,
                   Health_Check_Path__c,
                   Verify_API_Path__c,
                   Callback_Path__c,
                   Retry_Limit__c,
                   TimeoutMS__c,
                   Webhook_Secret__c
            FROM BV_Settings__mdt
            WHERE DeveloperName = 'Default'
            LIMIT 1
        ];

        Cfg c = new Cfg();
        c.devName                = row.DeveloperName;
        c.useExternalCredential  = row.Use_External_Credential__c;
        c.namedCredentialName    = row.Named_Credential_Name__c;
        c.externalCredentialName = row.External_Credential_Name__c;
        c.healthPath             = row.Health_Check_Path__c;
        c.verifyPath             = row.Verify_API_Path__c;
        c.callbackPath           = row.Callback_Path__c;
        c.retryLimit             = (row.Retry_Limit__c == null ? 0 : row.Retry_Limit__c.intValue());
        c.timeoutMs              = (row.TimeoutMS__c   == null ? 10000 : row.TimeoutMS__c.intValue());
        c.webhookSecret          = row.Webhook_Secret__c;

        cachedCfg = c;
        return cachedCfg;
    }

    /** Reset the cache after changing CMDT */
    @TestVisible public static void flush() { cachedCfg = null; }
}
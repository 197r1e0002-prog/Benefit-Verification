public class getRecordIdForAura{
    @AuraEnabled
    public static List<Account> getAccount() {
        
        return [SELECT ID from Account WHERE Name ='Charles Green' AND IsPersonAccount = true  LIMIT 1];  
    }
  
    @AuraEnabled
    public static List<HealthCloudGA__CarePlanTemplate__c> getCarePlanTemplate() {
        
        return [SELECT ID from HealthCloudGA__CarePlanTemplate__c WHERE Name='Healthy Lifestyle' LIMIT 1];  
    } 
    @AuraEnabled
    public static List<CareProgram> getCarePrograms() {
        
        return [SELECT ID from CareProgram  WHERE Name like '%Kanaka Patient Assistance Program%' LIMIT 1];  
    }
    @AuraEnabled
    public static List<Account> getBenAccount() {
        
        return [SELECT ID from Account WHERE Name ='Ben Green' AND IsPersonAccount = true  LIMIT 1];  
    }
    @AuraEnabled
    public static List<Account> getMakanaAccount() {
        
        return [SELECT ID from Account WHERE Name ='Makana Clinic'  LIMIT 1];  
    }
    @AuraEnabled
    public static List<Contact> getContacts() {
        
        return [SELECT ID from Contact WHERE Name like '%Gayathri Satish%'  LIMIT 1];  
    }
    @AuraEnabled
    public static List<ListView> getLeadRefferalManagement() {
        
        return [SELECT ID  from ListView WHERE DeveloperName = 'Incoming_Referrals'   LIMIT 1];  
    }
    @AuraEnabled
    public static List<ListView> getWorkingRefferal(){
        return [SELECT ID  from ListView WHERE DeveloperName = 'Working_Referrals'   LIMIT 1];
    }
    @AuraEnabled
    public static List<ReceivedDocument> getReceivedDocument() {
        
        return [SELECT ID  from ReceivedDocument WHERE Name like '%Brenda McClure_IDA%' AND source ='Salesforce Manual'  LIMIT 1];  
    }
    @AuraEnabled
    public static List<Account> getFortisAccount() {
        
        return [SELECT ID from Account WHERE Name like '%Fortis Hospital%' and IsPersonAccount = false  LIMIT 1];  
    }
    @AuraEnabled
    public static List<SalesAgreement> getSalesAgreement() {
        
        return [SELECT ID from SalesAgreement  WHERE Name like '%Makana Stent sales agreement%' LIMIT 1];  
    }
    @AuraEnabled
    public static List<Account> getForecastDeviceSales() {
        
        return [SELECT ID from Account  WHERE Name like '%Makana Clinic%' and IsPersonAccount = false  LIMIT 1];  
    }
    @AuraEnabled
    public static List<Lead> getLead() {
        
        return [SELECT ID from Lead  WHERE Name like '%Janice Chan%'  LIMIT 1];  
    }
    @AuraEnabled
    public static List<Account> getCredentialAccount() {
        
        return [SELECT ID from Account WHERE Name like '%Bill Stellar%'  AND IsPersonAccount = true  LIMIT 1];  
    }
    @AuraEnabled
    public static List<Contract> getContract() {
        
        return [SELECT ID from Contract WHERE ContractNumber ='00000101'   LIMIT 1];  
    }
    
    /*ADV Account Forecast*/
    @AuraEnabled
    public static List<AdvAcctForecastSetPartner> getAdvAccountForecast() {
        return [SELECT ID from AdvAcctForecastSetPartner  WHERE Name like 'Makana Clinic Monthly Product Forecast' LIMIT 1];  
    }
    
    /* ATM */
    @AuraEnabled
    public static List<CareProgramEnrollee> getCareProgramEnrollee() {
        return [SELECT ID from CareProgramEnrollee WHERE Name = 'Charles Green - Makana Commercial Delivery' LIMIT 1];  
    }
    
    @AuraEnabled
    public static List<CareProgramEnrollee> getShawnaCareProgramEnrollee() {
        return [SELECT ID from CareProgramEnrollee WHERE Name = 'Shawna Green - Makana Commercial Delivery' LIMIT 1];  
    }
}
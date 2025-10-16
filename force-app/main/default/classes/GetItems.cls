public without sharing class GetItems {
    

    @AuraEnabled(cacheable = true)
    public static List<Navigation_Item__c>  getPageItems(String pageName){
        Map<String, Id> lstNavRecords = getRecords();

        List<Navigation_Item__c> items = new List<Navigation_Item__c>();
        for(Navigation_Item__c item : [SELECT Id,Icon_Name__c, Section_Detail__c,Section_Heading__c,Target_App__c,RelatedEntityAPIName__c,Target_Tab_Name__c,NavigationType__c,Filter_Criteria__c,Target_RecordId__c, ObjectName__c
        FROM Navigation_Item__c WHERE isActive__c = true and PageName__c =:pageName order by Sequence_Number__c ]){
            System.debug('Navigation_Item__c items >>> ' + item);
            if(item.Filter_Criteria__c != null){
                String recordId = getRecordIdBasedOnFilter(item.ObjectName__c,item.Filter_Criteria__c);
                if(recordId != null){
                    item.Target_RecordId__c = recordId;
                }
            }

            if(String.isNotBlank(item.Section_Detail__c)) {
                String richTextData = replaceNavigationLinks(pageName, item.Section_Detail__c, lstNavRecords);
                item.Section_Detail__c = richTextData;
            } 

            items.add(item);
        }
        return items;
    }

     private static String getRecordIdBasedOnFilter(String objectName, String filter){
        String soqlQuery = 'select Id,Name from ' + objectName + ' where ' + filter;
        try{
            List<Sobject> results = database.query(soqlQuery);
            return results[0].Id;
        }    
        catch(Exception e){
            return null;
        }
            
    }

    private static Map<String, Id> getRecords() {

        Map<String, Id> mapRecords = new Map<String, Id>();

        //Account Records
        List<Account> lstAccount = [SELECT Id,Name FROM Account WHERE Name IN ('Makana Clinic', 'Fortis Hospital', 'Charles Green', 'Ben Green', 'Bill Stellar', 'Scott Carter', 'Sam Billings')];
        if(!lstAccount.isEmpty()){
            for(Account acc : lstAccount) {
                mapRecords.put(acc.Name.toUpperCase().replace(' ', '_') + '_REC', acc.Id);
            }
        }

        //Contact Records
        List<Contact> lstContacts = [SELECT Id, Name FROM Contact WHERE Name = 'Gayathri Satish'];
        if (!lstContacts.isEmpty()) {
            for(Contact con : lstContacts) {
                mapRecords.put(con.Name.toUpperCase().replace(' ', '_') + '_REC', con.Id);
            }
        }

        List<Contract> contracts = [SELECT Id FROM Contract WHERE ContractNumber ='00000101' LIMIT 1];
        if (!contracts.isEmpty()) {
            mapRecords.put('PNM_CONTRACT_101', contracts[0].Id);
        }

        List<AdvAcctForecastSetPartner> advAcctFSPs = [SELECT Id FROM AdvAcctForecastSetPartner WHERE Name = 'Makana Clinic Monthly Product Forecast' LIMIT 1];
        if (!advAcctFSPs.isEmpty()) {
            mapRecords.put('MAKANA_ADV_FORECAST_REC', advAcctFSPs[0].Id);
        }

        List<OmniProcess> omniProcesses = [SELECT Id, UniqueName FROM OmniProcess WHERE OmniProcessType = 'OmniScript' AND UniqueName IN ('CrisisCenter_ImmediateRisk_English_1', 'CrisisCenter_Intake_English_1', 'CrisisCenter_SafetyPlan_English_1', 'BehavioralHealth_PHQ9_English_1', 'BehavioralHealth_GAD7_English_1', 'BehavioralHealth_AUDITC_English_1')];
        for (OmniProcess os : omniProcesses) {
            mapRecords.put('OS_' + os.UniqueName.toUpperCase().replace(' ', '_'), os.Id);
        }

        List<Case> cases = [SELECT Id FROM Case WHERE Subject = 'Diabetes Care Plan' LIMIT 1];
        if (!cases.isEmpty()) {
            mapRecords.put('CASE_DIABETESCAREPLAN', cases[0].Id);
        }

        List<SerializedProduct> serializedProducts = [SELECT Id FROM SerializedProduct WHERE SerialNumber = 'TY-234' LIMIT 1];
        if (!serializedProducts.isEmpty()) {
            mapRecords.put('SERIALIZED_INV_REC', serializedProducts[0].Id);
        }

        List<Visit> visits = [SELECT Id FROM Visit ORDER BY PlannedVisitStartTime DESC LIMIT 1];
        if (!visits.isEmpty()) {
            mapRecords.put('VISIT_REC', visits[0].Id);
        }

        List<SalesAgreement> salesAgreements = [SELECT Id FROM SalesAgreement WHERE Name = 'Makana Stent sales agreement' LIMIT 1];
        if (!salesAgreements.isEmpty()) {
            mapRecords.put('MAKANA_SALES_AGREEMENT_REC', salesAgreements[0].Id);
        }

        List<CareProgram> carePrograms = [SELECT Id FROM CareProgram WHERE Name = 'Makana Commercial Delivery' LIMIT 1];
        if (!carePrograms.isEmpty()) {
            mapRecords.put('MAKANA_CP_REC', carePrograms[0].Id);
        }

        List<CareObservation> careObservations = [SELECT Id FROM CareObservation WHERE Name = 'Sam Billings High Systolic Blood Pressure' LIMIT 1];
        if (!careObservations.isEmpty()) {
            mapRecords.put('SAMBILLING_CO_REC', careObservations[0].Id);
        }

        return mapRecords;
    }

    private static String replaceNavigationLinks(String pageName, String richTextData, Map<String, Id> mapRecords) {

        String recValue = '';
        String appName = 'c__Care_CoordinationApp';

        if('MedTech Landing Page'.equalsIgnoreCase(pageName)) {
            appName = 'standard__MedicalDevices';
        }

        if('Pharma Landing Page'.equalsIgnoreCase(pageName)) {
            appName = 'c__Patient_Services';
        }

        richTextData = richTextData.replace('CSCM_APP', '<a href="/lightning/app/standard__CrisisCenter/" target="_blank" style="color: rgb(0, 0, 238);"><u>here</u></a>');

        recValue = mapRecords.get('MAKANA_CLINIC_REC');
        richTextData = richTextData.replace('MAKANA_CLINIC_REC', '<a href="/lightning/app/'+ appName + '/r/Account/' + recValue + '/view" target="_blank" style="color: rgb(0, 0, 238);"><u>here</u></a>');

        recValue = mapRecords.get('CHARLES_GREEN_REC');
        richTextData = richTextData.replace('CHARLES_GREEN_REC', '<a href="/lightning/app/c__Care_CoordinationApp/r/Account/' + recValue + '/view" target="_blank" style="color: rgb(0, 0, 238);"><u>here</u></a>');

        recValue = mapRecords.get('SAM_BILLINGS_REC');
        richTextData = richTextData.replace('SAM_BILLINGS_REC', '<a href="/lightning/app/standard__ICMConsole/r/Account/' + recValue + '/view" target="_blank" style="color: rgb(0, 0, 238);"><u>here</u></a>');

        recValue = mapRecords.get('SAMBILLING_CO_REC');
        richTextData = richTextData.replace('SAMBILLING_CO_REC', '<a href="/lightning/app/standard__ICMConsole/r/CareObservation/' + recValue + '/view" target="_blank" style="color: rgb(0, 0, 238);"><u>here</u></a>');

        recValue = mapRecords.get('SCOTT_CARTER_REC');
        richTextData = richTextData.replace('SCOTT_CARTER_REC', '<a href="/lightning/app/standard__HomeHealth/r/Account/' + recValue + '/view" target="_blank" style="color: rgb(0, 0, 238);"><u>here</u></a>');

        recValue = mapRecords.get('BEN_GREEN_REC');
        richTextData = richTextData.replace('BEN_GREEN_REC', '<a href="/lightning/app/'+ appName + '/r/Account/' + recValue + '/view" target="_blank" style="color: rgb(0, 0, 238);"><u>here</u></a>');

        recValue = mapRecords.get('GAYATHRI_SATISH_REC');
        richTextData = richTextData.replace('GAYATHRI_SATISH_REC', '<a href="/lightning/app/c__Care_CoordinationApp/r/Contact/' + recValue + '/view" target="_blank" style="color: rgb(0, 0, 238);"><u>here</u></a>');
        
        recValue = mapRecords.get('OPPTY_WORKING_REFERRAL_LV');
        richTextData = richTextData.replace('OPPTY_WORKING_REFERRAL_LV', '<a href="/lightning/app/' + appName + '/o/Opportunity/list?filterName=Working_Referrals" target="_blank" style="color: rgb(0, 0, 238);"><u>here</u></a>');
        
        recValue = mapRecords.get('BILL_STELLAR_REC');
        richTextData = richTextData.replace('BILL_STELLAR_REC', '<a href="/lightning/app/standard__ProviderNetworkManagement/r/Account/' + recValue + '/view" target="_blank" style="color: rgb(0, 0, 238);"><u>here</u></a>');

        recValue = mapRecords.get('FORTIS_HOSPITAL_REC');
        richTextData = richTextData.replace('FORTIS_REC', '<a href="/lightning/app/standard__ProviderNetworkManagement/r/Account/' + recValue + '/view" target="_blank" style="color: rgb(0, 0, 238);"><u>here</u></a>');

        recValue = mapRecords.get('PNM_CONTRACT_101');
        richTextData = richTextData.replace('PNM_CONTRACT_101', '<a href="/lightning/app/standard__ProviderNetworkManagement/r/Contract/' + recValue + '/view" target="_blank" style="color: rgb(0, 0, 238);"><u>here</u></a>');

        recValue = mapRecords.get('MAKANA_ADV_FORECAST_REC');
        richTextData = richTextData.replace('MAKANA_ADV_FORECAST_REC', '<a href="/lightning/app/standard__MedicalDevices/r/AdvAcctForecastSetPartner/' + recValue + '/view" target="_blank" style="color: rgb(0, 0, 238);"><u>here</u></a>');

        recValue = mapRecords.get('SERIALIZED_INV_REC');
        richTextData = richTextData.replace('SERIALIZED_INV_REC', '<a href="/lightning/app/standard__MedicalDevices/r/SerializedProduct/' + recValue + '/view" target="_blank" style="color: rgb(0, 0, 238);"><u>here</u></a>');

        recValue = mapRecords.get('VISIT_REC');
        richTextData = richTextData.replace('VISIT_REC', '<a href="/lightning/app/standard__MedicalDevices/r/Visit/' + recValue + '/view" target="_blank" style="color: rgb(0, 0, 238);"><u>here</u></a>');

        recValue = mapRecords.get('OS_CRISISCENTER_INTAKE_ENGLISH_1');
        richTextData = richTextData.replace('OS_CRISISCENTER_INTAKE_ENGLISH_1', '<a href="/lightning/app/omnistudio__Vlocity_Digital_Studio/cmp/omnistudio__OmniDesignerAuraWrapper?c__recordId=' + recValue + '" target="_blank" style="color: rgb(0, 0, 238);"><u>Intake</u></a>');
        
        recValue = mapRecords.get('OS_CRISISCENTER_IMMEDIATERISK_ENGLISH_1');
        richTextData = richTextData.replace('OS_CRISISCENTER_IMMEDIATERISK_ENGLISH_1', '<a href="/lightning/app/omnistudio__Vlocity_Digital_Studio/cmp/omnistudio__OmniDesignerAuraWrapper?c__recordId=' + recValue + '" target="_blank" style="color: rgb(0, 0, 238);"><u>Immediate Risk Assessment</u></a>');
        
        recValue = mapRecords.get('OS_CRISISCENTER_SAFETYPLAN_ENGLISH_1');
        richTextData = richTextData.replace('OS_CRISISCENTER_SAFETYPLAN_ENGLISH_1', '<a href="/lightning/app/omnistudio__Vlocity_Digital_Studio/cmp/omnistudio__OmniDesignerAuraWrapper?c__recordId=' + recValue + '" target="_blank" style="color: rgb(0, 0, 238);"><u>Safety Plan</u></a>');
        
        recValue = mapRecords.get('CASE_DIABETESCAREPLAN');
        richTextData = richTextData.replace('CASE_DIABETESCAREPLAN', '<a href="/lightning/app/standard__CrisisCenter/r/Case/' + recValue + '/view" target="_blank" style="color: rgb(0, 0, 238);"><u>here</u></a>');
    
        recValue = mapRecords.get('OS_BEHAVIORALHEALTH_PHQ9_ENGLISH_1');
        richTextData = richTextData.replace('OS_BEHAVIORALHEALTH_PHQ9_ENGLISH_1', '<a href="/lightning/app/omnistudio__Vlocity_Digital_Studio/cmp/omnistudio__OmniDesignerAuraWrapper?c__recordId=' + recValue + '" target="_blank" style="color: rgb(0, 0, 238);"><u>PHQ-9</u></a>');
        
        recValue = mapRecords.get('OS_BEHAVIORALHEALTH_GAD7_ENGLISH_1');
        richTextData = richTextData.replace('OS_BEHAVIORALHEALTH_GAD7_ENGLISH_1', '<a href="/lightning/app/omnistudio__Vlocity_Digital_Studio/cmp/omnistudio__OmniDesignerAuraWrapper?c__recordId=' + recValue + '" target="_blank" style="color: rgb(0, 0, 238);"><u>GAD-7</u></a>');
        
        recValue = mapRecords.get('OS_BEHAVIORALHEALTH_AUDITC_ENGLISH_1');
        richTextData = richTextData.replace('OS_BEHAVIORALHEALTH_AUDITC_ENGLISH_1', '<a href="/lightning/app/omnistudio__Vlocity_Digital_Studio/cmp/omnistudio__OmniDesignerAuraWrapper?c__recordId=' + recValue + '" target="_blank" style="color: rgb(0, 0, 238);"><u>AUDIT-C</u></a>');
        
        recValue = mapRecords.get('MAKANA_SALES_AGREEMENT_REC');
        richTextData = richTextData.replace('MAKANA_SALES_AGREEMENT_REC', '<a href="/lightning/app/standard__MedicalDevices/r/SalesAgreement/' + recValue + '/view" target="_blank" style="color: rgb(0, 0, 238);"><u>here</u></a>');

        recValue = mapRecords.get('MAKANA_CP_REC');
        richTextData = richTextData.replace('MAKANA_CP_REC', '<a href="/lightning/app/standard__AdvancedTherapyManagement/r/CareProgram/' + recValue + '/view" target="_blank" style="color: rgb(0, 0, 238);"><u>here</u></a>');

        richTextData = richTextData.replace('PROVIDER_SEARCH_CBSF', '<a href="/lightning/app/c__Care_CoordinationApp/n/Provider_Search_CBSF" target="_blank" style="color: rgb(0, 0, 238);"><u>here</u></a>');

        List<Network> communities = [SELECT Id, Name FROM Network WHERE Name = 'Provider Portal'];
        richTextData = richTextData.replace('PROVIDER_PORTAL_JOINNETWORK', '<a href="' + Network.getLoginUrl(communities[0].Id).removeEnd('/login') + '/joinournetwork" target="_blank" style="color: rgb(0, 0, 238);"><u>Provider Portal</u></a>');


        return richTextData;
    }

}
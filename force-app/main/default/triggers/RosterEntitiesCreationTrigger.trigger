trigger RosterEntitiesCreationTrigger on ContentDocumentLink (after insert) {
    List<ContentDocumentLink> contentDocumentLinkRecords = new List<ContentDocumentLink>();
    List<CaseRelatedFile> caseRelatedFileList = new List<CaseRelatedFile>();
    
    //To be changed by the System Administrator
    final String rosterCaseRecordTypeName = 'Roster File';   
    
    // Collect all Content Document Link records related to Case having rosterCaseRecordTypeName record type
    for (ContentDocumentLink contentDocumentLink : Trigger.new) {
        if (contentDocumentLink.LinkedEntityId.getSObjectType() == EmailMessage.sObjectType) {
            List<EmailMessage> linkedEmailMessage = [SELECT ParentId FROM EmailMessage WHERE Id = :contentDocumentLink.LinkedEntityId LIMIT 1];
            List<Case> cases = [SELECT Id, RecordTypeId FROM Case WHERE Id = :linkedEmailMessage.get(0).ParentId LIMIT 1];
            if (cases.get(0).RecordTypeId != null) {
                // Query the RecordType object to get the Record Type Name
                RecordType rt = [SELECT Name FROM RecordType WHERE Id = :cases.get(0).RecordTypeId LIMIT 1];
                if (rt != null && rt.Name.equals(rosterCaseRecordTypeName)) {
                    CaseRelatedFile caseRelatedFile = new CaseRelatedFile();    
                    caseRelatedFile.CaseId = cases.get(0).Id;
                    caseRelatedFile.ContentDocumentId  = contentDocumentLink.ContentDocumentId;
                    
                    ContentDocument document = [SELECT FileType FROM ContentDocument WHERE Id = :caseRelatedFile.ContentDocumentId LIMIT 1];
                    if (document != null && document.FileType == 'CSV') {
                        caseRelatedFileList.add(caseRelatedFile);
                    }
                }
            }
        }
        else if (contentDocumentLink.LinkedEntityId.getSObjectType() == Case.sObjectType) {
            String linkedEntityId = contentDocumentLink.LinkedEntityId;
            List<Case> cases = [SELECT Id, RecordTypeId FROM Case WHERE Id = :linkedEntityId LIMIT 1];
            if (cases.get(0).RecordTypeId != null) {
                // Query the RecordType object to get the Record Type Name
                RecordType rt = [SELECT Name FROM RecordType WHERE Id = :cases.get(0).RecordTypeId LIMIT 1];
                if (rt != null && rt.Name.equals(rosterCaseRecordTypeName)) {
                    ContentDocument document = [SELECT FileType FROM ContentDocument WHERE Id = :contentDocumentLink.ContentDocumentId LIMIT 1];
                    if (document != null && document.FileType == 'CSV') {
                        contentDocumentLinkRecords.add(contentDocumentLink);
                    }
                }
            }
        }
    }
    
    if(!caseRelatedFileList.isEmpty()) {
        try {
            insert caseRelatedFileList;
        } 
        catch (Exception e) {
            System.debug('Error occurred in RosterFileRelatedObjectsCreationService: ' + e.getMessage());
        }
    }
    
    if (!contentDocumentLinkRecords.isEmpty()) {
        try {
            // Instantiate the service class
            healthcloudext.RosterFileRelatedObjectsCreationService rosterFileRelatedObjectsCreationService = new healthcloudext.RosterFileRelatedObjectsCreationService();
            // Call the method to create case related file for the content document link record
            rosterFileRelatedObjectsCreationService.createCaseRelatedFiles(contentDocumentLinkRecords);
        }
        catch(Exception e) {
            // Log the exception message
            System.debug('Error occurred in RosterFileRelatedObjectsCreationService: ' + e.getMessage());
        } 
    }
}
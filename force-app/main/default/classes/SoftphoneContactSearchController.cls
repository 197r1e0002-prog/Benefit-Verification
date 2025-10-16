/*
Copyright 2016 salesforce.com, inc. All rights reserved.

Use of this software is subject to the salesforce.com Developerforce Terms of Use and other applicable terms that salesforce.com may make available, as may be amended from time to time. You may not decompile, reverse engineer, disassemble, attempt to derive the source code of, decrypt, modify, or create derivative works of this software, updates thereto, or any part thereof. You may not use the software to engage in any development activity that infringes the rights of a third party, including that which interferes with, damages, or accesses in an unauthorized manner the servers, networks, or other properties or services of salesforce.com or any third party.

WITHOUT LIMITING THE GENERALITY OF THE FOREGOING, THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED. IN NO EVENT SHALL SALESFORCE.COM HAVE ANY LIABILITY FOR ANY DAMAGES, INCLUDING BUT NOT LIMITED TO, DIRECT, INDIRECT, SPECIAL, INCIDENTAL, PUNITIVE, OR CONSEQUENTIAL DAMAGES, OR DAMAGES BASED ON LOST PROFITS, DATA OR USE, IN CONNECTION WITH THE SOFTWARE, HOWEVER CAUSED AND, WHETHER IN CONTRACT, TORT OR UNDER ANY OTHER THEORY OF LIABILITY, WHETHER OR NOT YOU HAVE BEEN ADVISED OF THE POSSIBILITY OF SUCH DAMAGES.
*/

global class SoftphoneContactSearchController {
    webService static String getContacts(String name) {
        List<Contact> contactList = new List<Contact>();
        for (Contact contact: [SELECT Id, Phone, Name, Title, Account.Name FROM Contact WHERE (id = :name OR Name LIKE :('%' + name + '%') OR firstname LIKE :('%' + name + '%') OR lastname LIKE :('%' + name + '%') OR phone LIKE :('%' + name + '%')) LIMIT 10]){
            contactList.add(contact);
        }
        System.debug('SELECT Id, Phone, Name, Title, Account.Name FROM Contact WHERE (id = :'+name +'OR Name LIKE :(%' + name + '%) OR firstname LIKE :(%' + name + '%) OR lastname LIKE :(%' + name + '%) OR phone LIKE :(%' + name + '%)) LIMIT 10');
        return JSON.serialize(contactList);
    }
    
    // Create Engagement Interaction using connect API
     webService static String createEngagementInteraction(String recordId) {
        system.debug('In create Engagement Interaction');
        ConnectApi.EngagementInteractionCreateInput interactionInput = new ConnectApi.EngagementInteractionCreateInput();
        interactionInput.communicationChannel = 'Voice Call';
        interactionInput.attendeeVerified = false;
        interactionInput.startDateTime = datetime.now().formatGMT('yyyy-MM-dd\'T\'HH:mm:ss.SSS\'Z\'');
        interactionInput.status = 'New';
        
        if(recordId !='UNKNOWN'  ){
            interactionInput.initiatingAttendeeId = recordId;
            interactionInput.attendeeAuthenticated = true;
        }
        ConnectApi.EngagementsCreateInput containerInput = new ConnectApi.EngagementsCreateInput();
        containerInput.engagementInteraction = interactionInput;
        ConnectApi.EngagementsCreateOutput output = ConnectApi.EngagementContainerConnect.createEngagementInteraction(containerInput);
        return output.engagementInteraction.id;
    }
    
    webService static String updateEngagementInteraction(Id recordId) {
        
        EngagementInteraction  ei = [SELECT Id FROM EngagementInteraction  WHERE Id=:recordId];
        
        ei.EndDateTime =DateTime.now();
        ei.Status = 'Completed';
        update ei;
        
        List<EngagementAttendee> eaList = [SELECT Id, EndDateTime FROM EngagementAttendee WHERE EngagementId=:recordId];
        
        for(EngagementAttendee ea : eaList) {
            ea.EndDateTime = DateTime.now();
        }
        
        if(eaList.size() > 0 )
            update eaList;

        return recordId;
    }

}
// File: BV_CBVRCreateorBatch.cls   (name can be anything)
public with sharing class BV_CBVRCreateorBatch
    implements Database.Batchable<SObject>, Database.Stateful {

    private Date   serviceDate;
    private String serviceType;
    private String icd10;
    private String cpt;

    public BV_CBVRCreateorBatch(String serviceType, Date serviceDate, String icd10, String cpt){
        this.serviceType  = serviceType;
        this.serviceDate  = serviceDate;
        this.icd10        = icd10;
        this.cpt          = cpt;
    }

    // Adjust the query to your targeting/routing needs
    public Database.QueryLocator start(Database.BatchableContext bc){
        return Database.getQueryLocator('SELECT Id FROM Account WHERE IsPersonAccount = true');
    }

    public void execute(Database.BatchableContext bc, List<SObject> scope){
        List<Id> ids = new List<Id>();
        for (SObject s : scope) ids.add((Id)s.get('Id'));
        // Re-use the builder
        BV_CBVRBuilder.buildFromAccountIds(ids, serviceDate, serviceType, icd10, cpt);
    }

    public void finish(Database.BatchableContext bc) {}
}
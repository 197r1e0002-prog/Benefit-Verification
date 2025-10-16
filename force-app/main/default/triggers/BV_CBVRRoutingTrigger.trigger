trigger BV_CBVRRoutingTrigger on CareBenefitVerifyRequest__c (before insert, before update) {

    // Map ServiceType -> Queue DeveloperName (must match *DeveloperName* on the queue)
    Map<String,String> route = new Map<String,String>{
        'Dental'   => 'Dental',
        'Emergency'=> 'Emergency',
        'Medical'  => 'Medical',
        'DEFAULT'  => 'Care_Representatives'
    };

    // Load queues by DeveloperName
    Map<String,Id> qIds = new Map<String,Id>();
    for (Group g : [
        SELECT Id, DeveloperName
        FROM Group
        WHERE Type = 'Queue' AND DeveloperName IN :route.values()
    ]) {
        qIds.put(g.DeveloperName, g.Id);
    }

    // Set OwnerId inline (legal in BEFORE triggers)
    for (CareBenefitVerifyRequest__c r : Trigger.new) {
        String key   = (r.ServiceType__c ?? '').trim();
        String qName = route.containsKey(key) ? route.get(key) : route.get('DEFAULT');
        Id qId       = qIds.get(qName);
        if (qId != null && r.OwnerId != qId) {
            r.OwnerId = qId;   // OK in BEFORE
        }
    }
}
public with sharing class BV_CBVRSubmitter_Invocable {
    public class Inp {
        @InvocableVariable(required=true) public Id recordId;
        @InvocableVariable public String coverageName;    // optional override
        @InvocableVariable public String coverageStatus;  // optional override
        @InvocableVariable public String statusReason;    // optional override
        @InvocableVariable public String externalId;      // optional override
    }
    public class Out {
        @InvocableVariable public Integer statusCode;
        @InvocableVariable public Id cbvrId;
        @InvocableVariable public Id coverageBenefitId;
        @InvocableVariable public String error;
    }

    @InvocableMethod(label='Mock Callback for CBVR'
                     description='Creates/updates CoverageBenefit__c for this CBVR (demo).')
    public static List<Out> run(List<Inp> reqs){
        List<Out> outs = new List<Out>();
        for (Inp r : reqs){
            // fallbacks so it "just works"
            String name   = String.isBlank(r.coverageName)   ? 'Aetna PPO | Adam Turnel' : r.coverageName;
            String cstat  = String.isBlank(r.coverageStatus) ? 'Active'                  : r.coverageStatus;
            String reason = String.isBlank(r.statusReason)   ? 'In network'              : r.statusReason;
            String ext    = String.isBlank(r.externalId)     ? 'EV-TEST-' + String.valueOf(Crypto.getRandomInteger()) : r.externalId;

            BV_CBVRSubmitter.SubmitResult res =
                BV_CBVRSubmitter.sendByCbvrId(r.recordId, 'Ready', name, cstat, reason, ext);

            Out o = new Out();
            o.statusCode        = res.statusCode;
            o.cbvrId            = res.cbvrId;
            o.coverageBenefitId = res.coverageBenefitId;
            outs.add(o);
        }
        return outs;
    }
}
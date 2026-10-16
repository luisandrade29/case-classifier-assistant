// Classifies one case per job and chains itself for the rest, keeping each job well inside callout limits.
public with sharing class CaseClassifierQueueable implements Queueable, Database.AllowsCallouts {
    final List<Id> caseIds;
    final AiProvider provider;

    public CaseClassifierQueueable(List<Id> caseIds) {
        this(caseIds, new ClaudeProvider());
    }

    public CaseClassifierQueueable(List<Id> caseIds, AiProvider provider) {
        this.caseIds = caseIds;
        this.provider = provider;
    }

    public void execute(QueueableContext ctx) {
        List<Id> rest = caseIds.clone();
        Id current = rest.remove(0);

        List<Case> cases = [SELECT Id, Subject, Description FROM Case WHERE Id = :current];
        if (!cases.isEmpty()) {
            Case c = cases[0];
            try {
                AiResult r = provider.classify(c.Subject, c.Description);
                c.AI_Category__c = r.category?.abbreviate(50);
                c.AI_Priority__c = r.priority?.abbreviate(20);
                c.AI_Summary__c = r.summary?.abbreviate(255);
                c.AI_Suggested_Reply__c = r.suggestedReply?.abbreviate(10000);
                c.AI_Status__c = 'Done';
            } catch (Exception e) {
                // The case must stay usable if the AI call fails.
                System.debug(LoggingLevel.ERROR, 'Case classification failed: ' + e.getMessage());
                c.AI_Status__c = 'Error';
            }
            update c;
        }

        if (!rest.isEmpty()) {
            System.enqueueJob(new CaseClassifierQueueable(rest, provider));
        }
    }
}

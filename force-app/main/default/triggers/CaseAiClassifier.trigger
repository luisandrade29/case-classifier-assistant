trigger CaseAiClassifier on Case (after insert) {
    // IT incidents (separate project) are triaged by SLA flows, not by the AI classifier.
    Schema.RecordTypeInfo incidentRt = Schema.SObjectType.Case.getRecordTypeInfosByDeveloperName().get('Incident_IT');
    Id incidentRtId = incidentRt?.getRecordTypeId();

    List<Id> ids = new List<Id>();
    for (Case c : Trigger.new) {
        // Dynamic get: RecordTypeId only exists in orgs with Case record types, so this must not be a compile-time reference.
        if (incidentRtId != null && (Id) c.get('RecordTypeId') == incidentRtId) {
            continue;
        }
        if (String.isNotBlank(c.Subject) || String.isNotBlank(c.Description)) {
            ids.add(c.Id);
        }
    }
    if (!ids.isEmpty()) {
        System.enqueueJob(new CaseClassifierQueueable(ids));
    }
}

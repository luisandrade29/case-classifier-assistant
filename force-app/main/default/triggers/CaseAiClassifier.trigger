trigger CaseAiClassifier on Case (after insert) {
    List<Id> ids = new List<Id>();
    for (Case c : Trigger.new) {
        if (String.isNotBlank(c.Subject) || String.isNotBlank(c.Description)) {
            ids.add(c.Id);
        }
    }
    if (!ids.isEmpty()) {
        System.enqueueJob(new CaseClassifierQueueable(ids));
    }
}

@IsTest
private class CaseClassifierTest {
    class ClaudeMock implements HttpCalloutMock {
        Integer status;
        String modelText;
        Boolean withThinking = false;
        ClaudeMock(Integer status, String modelText) {
            this.status = status;
            this.modelText = modelText;
        }
        public HttpResponse respond(HttpRequest req) {
            System.assertEquals('POST', req.getMethod());
            // The prompt must ask the model to answer in the customer's language.
            System.assert(req.getBody().contains('Detect the language'), 'language instruction missing');
            HttpResponse res = new HttpResponse();
            res.setStatusCode(status);
            List<Object> blocks = new List<Object>();
            if (withThinking) {
                blocks.add(new Map<String, Object>{ 'type' => 'thinking', 'thinking' => '', 'signature' => 'x' });
            }
            blocks.add(new Map<String, Object>{ 'type' => 'text', 'text' => modelText });
            res.setBody(JSON.serialize(new Map<String, Object>{ 'content' => blocks }));
            return res;
        }
    }

    static final String GOOD =
        'Here you go:\n```json\n{"category":"Billing","priority":"High",' +
        '"summary":"Customer was charged twice.","suggestedReply":"Sorry about that, we are refunding you."}\n```';

    @IsTest
    static void providerParsesJsonWrappedInProse() {
        Test.setMock(HttpCalloutMock.class, new ClaudeMock(200, GOOD));
        Test.startTest();
        AiResult r = new ClaudeProvider().classify('Double charge', 'I was charged twice');
        Test.stopTest();
        System.assertEquals('Billing', r.category);
        System.assertEquals('High', r.priority);
    }

    @IsTest
    static void providerSkipsThinkingBlockBeforeText() {
        ClaudeMock mock = new ClaudeMock(200, GOOD);
        mock.withThinking = true;
        Test.setMock(HttpCalloutMock.class, mock);
        System.assertEquals('Billing', new ClaudeProvider().classify('s', 'b').category);
    }

    @IsTest
    static void providerThrowsOnHttpError() {
        Test.setMock(HttpCalloutMock.class, new ClaudeMock(500, ''));
        try {
            new ClaudeProvider().classify('s', 'b');
            System.assert(false, 'expected exception');
        } catch (AiResult.AiException e) {
            System.assert(e.getMessage().contains('500'));
        }
    }

    @IsTest
    static void providerThrowsWhenNoJson() {
        Test.setMock(HttpCalloutMock.class, new ClaudeMock(200, 'no json here'));
        try {
            new ClaudeProvider().classify('s', 'b');
            System.assert(false, 'expected exception');
        } catch (AiResult.AiException e) {
            System.assert(e.getMessage().contains('No JSON'));
        }
    }

    @IsTest
    static void newCaseIsClassifiedViaTrigger() {
        Test.setMock(HttpCalloutMock.class, new ClaudeMock(200, GOOD));
        Test.startTest();
        Case c = new Case(Subject = 'Double charge', Description = 'I was charged twice');
        insert c;
        Test.stopTest(); // runs the queueable
        c = [SELECT AI_Category__c, AI_Priority__c, AI_Summary__c, AI_Suggested_Reply__c, AI_Status__c
             FROM Case WHERE Id = :c.Id];
        System.assertEquals('Done', c.AI_Status__c);
        System.assertEquals('Billing', c.AI_Category__c);
        System.assertEquals('High', c.AI_Priority__c);
        System.assert(c.AI_Suggested_Reply__c.contains('refunding'));
    }

    @IsTest
    static void apiFailureMarksCaseAsErrorWithoutBlockingInsert() {
        Test.setMock(HttpCalloutMock.class, new ClaudeMock(500, ''));
        Test.startTest();
        Case c = new Case(Subject = 'Help', Description = 'Something broke');
        insert c;
        Test.stopTest();
        c = [SELECT AI_Status__c, AI_Category__c FROM Case WHERE Id = :c.Id];
        System.assertEquals('Error', c.AI_Status__c);
        System.assertEquals(null, c.AI_Category__c);
    }

    @IsTest
    static void caseWithoutTextIsSkipped() {
        Test.startTest();
        Case c = new Case(Origin = 'Web');
        insert c;
        Test.stopTest();
        System.assertEquals(null, [SELECT AI_Status__c FROM Case WHERE Id = :c.Id].AI_Status__c);
    }
}

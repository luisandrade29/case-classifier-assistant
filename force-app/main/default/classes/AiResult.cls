// Property names match the JSON keys the model is asked to return.
public class AiResult {
    public String category;
    public String priority;
    public String summary;
    public String suggestedReply;

    public class AiException extends Exception {}
}

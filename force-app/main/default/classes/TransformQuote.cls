public class TransformQuote {
public class Request {
        @InvocableVariable(required = true)
        public List<Custom_Quote__c > quotes;

        @InvocableVariable(required = false)
        public List<List<String>> stringLists; // List of string lists to store in a field
    }

    public class Response {
        @InvocableVariable
        public List<healthcloudext.HomeVisitPatientQuoteDetails> transformedQuotes; // Updated type to Custom_Quote__c
    }

    @InvocableMethod(label = 'Transform Quotes' description = 'Transform Quotes')
    public static List<Response> transformQuotes(List<Request> requests) {
        List<Response> responses = new List<Response>();
        
        for (Request req : requests) {
            Response resp = new Response();
            resp.transformedQuotes = new List<healthcloudext.HomeVisitPatientQuoteDetails>();
            if (req == null || req.quotes == null || req.quotes.size() == 0){
                  return responses;
            }
            for (Integer i = 0; i < req.quotes.size(); i++) {
                Custom_Quote__c quote = req.quotes[i];
                
                healthcloudext.HomeVisitPatientQuoteDetails detail = new healthcloudext.HomeVisitPatientQuoteDetails();
                detail.quoteId = quote.Id;
                detail.quotePrice = quote.Cost__c;
                detail.quoteName = quote.Name__c;
                DateTime value = quote.CreatedDate;
                Date dateValue = value.date();
                detail.createdDate  = dateValue;
                
                if(String.isNotBlank(quote.Products__c)){
                     List<String> p = quote.Products__c.split(',');
               
                    for(Integer j =0;j<p.size();j++){
                    p[j] = p[j].trim();
                }
                detail.productNames = p;
                    
                }else{
                    detail.productNames = new List<String>();
                }
                  
                resp.transformedQuotes.add(detail);
            }
            responses.add(resp);
        }

        return responses;
    }
}
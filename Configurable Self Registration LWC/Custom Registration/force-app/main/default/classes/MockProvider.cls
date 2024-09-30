@isTest
public class MockProvider implements System.StubProvider {
    
    public Object handleMethodCall(Object stubbedObject, String stubbedMethodName, Type returnType, List<Type> listOfParamTypes, List<String> listOfParamNames, List<Object> listOfArgs) {
    
        // This is a very simple mock provider that returns a hard-coded value based on the stubbed method name so we can test the results.
        if (stubbedMethodName == 'verifyUser') {
            return '{"registerResult":[{"pageUrl": "https://www.google.com", "verificationSuccess" : true}]}';
        }

        if(stubbedMethodName == 'loginUser') {
            return 'Failed Login';
        }

        else {
            return null;
        }      
    }
}
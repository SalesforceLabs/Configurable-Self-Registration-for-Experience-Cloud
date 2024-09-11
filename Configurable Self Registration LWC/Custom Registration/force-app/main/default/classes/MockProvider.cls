@isTest
public class MockProvider implements System.StubProvider {
    
    public Object handleMethodCall(Object stubbedObject, String stubbedMethodName, 
        Type returnType, List<Type> listOfParamTypes, List<String> listOfParamNames, 
        List<Object> listOfArgs) {
        
        // The following debug statements show an example of logging 
        // the invocation of a mocked method.
       
        // You can use the method name and return type to determine which method was called.
        System.debug('Name of stubbed method: ' + stubbedMethodName);
        System.debug('Return type of stubbed method: ' + returnType.getName());
        
        // You can also use the parameter names and types to determine which method 
        // was called.
        for (integer i =0; i < listOfParamNames.size(); i++) {
            System.debug('parameter name: ' + listOfParamNames.get(i));
            System.debug('  parameter type: ' + listOfParamTypes.get(i).getName());
        }
        
        // This shows the actual parameter values passed into the stubbed method at runtime.
        System.debug('number of parameters passed into the mocked call: ' + 
            listOfArgs.size());
        System.debug('parameter(s) sent into the mocked call: ' + listOfArgs);
        
        // This is a very simple mock provider that returns a hard-coded value 
        // based on the return type of the invoked.
        if (returnType.getName() == 'String') {
            return '{"registerResult":[{"pageUrl": "https://www.google.com", "verificationSuccess" : true}]}';
        }
        else {
            return null;
        }      
    }
}
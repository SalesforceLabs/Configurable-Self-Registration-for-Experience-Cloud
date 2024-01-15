/**
 * @description - test classes for retrieving picklist values from record types for LWC configuration panel.
 * @author Jamie Lowe - jamielowe1990/jlowesfdc
**/

@isTest
private class RetrieveRecordsForQueryTest {

    //Create a test Person Account record
    private static void createPersonAccountTestData() {
        
        Id recordTypeId = Schema.SObjectType.Account.getRecordTypeInfosByName().get('Person Account').getRecordTypeId();

        Schema.SObjectType targetType = Schema.getGlobalDescribe().get('Account');
        SObject newObject = targetType.newSObject(); 
        Account acc = (Account)newObject;
        acc.put('RecordTypeId', recordTypeId);
        acc.put('FirstName', 'Test');
        acc.put('LastName', 'PA');
        acc.put('PersonEmail', 'user@test.com');
        insert acc;
    }

    //Mock a form submit in System mode for the custom query
    @isTest
    private static void retrieveRecordsCustomQuerySystemTest() {       
        
        createPersonAccountTestData();

        //Fake some inputs for the form and settings
        String formInputs = '{"FirstName":"Test", "LastName":"Contact", "Username":"user@test.com", "Email":"user@test.com","password":"Testing123!", "confirmPassword":"Testing123!"}';
        String configurationOptions = '{"loggingEnabled":"true", "objectToQuery": "Account", "customQuery":"SELECT Id,PersonEmail FROM Account WHERE PersonEmail = :Email LIMIT 1", "accessLevelMode":"System"}';
        
        Map<String, Object> configurationOptionsObject = (Map<String, Object>) JSON.deserializeUntyped(configurationOptions);
        Map<String, Object> formInputsObject = (Map<String, Object>) JSON.deserializeUntyped(formInputs);

        //Query the record using the custom query to find the test data
        List<sObject> recordList = RetrieveRecordsForQuery.getRecords(formInputsObject, configurationOptionsObject);
        System.assertEquals(1, recordList.size(), 'Person Account record found using custom query in SYSTEM mode');
    }

    //Mock a form submit in User mode for the custom query
    @isTest
    private static void retrieveRecordsCustomQueryUserTest() {       
        
        createPersonAccountTestData();

        //Fake some inputs for the form and settings
        String formInputs = '{"FirstName":"Test", "LastName":"Contact", "Username":"user@test.com", "Email":"user@test.com","password":"Testing123!", "confirmPassword":"Testing123!"}';
        String configurationOptions = '{"loggingEnabled":"true", "objectToQuery": "Account", "customQuery":"SELECT Id,PersonEmail FROM Account WHERE PersonEmail = :Email LIMIT 1", "accessLevelMode":"User"}';
        
        Map<String, Object> configurationOptionsObject = (Map<String, Object>) JSON.deserializeUntyped(configurationOptions);
        Map<String, Object> formInputsObject = (Map<String, Object>) JSON.deserializeUntyped(formInputs);

        //Query the record using the custom query to find the test data
        List<sObject> recordList = RetrieveRecordsForQuery.getRecords(formInputsObject, configurationOptionsObject);
        System.assertEquals(1, recordList.size(), 'Person Account record found using custom query in USER mode');
    }
}
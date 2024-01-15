/**
 * @description A simple class to run the custom query using without sharing. This class is called from the SiteRegistrationController where with sharing has been enforced.
 * This class runs without sharing to return records for the specified query that would otherwise have to be shared via some other means.
 * @author: Jamie Lowe
 */
public without sharing class RetrieveRecordsForQuery {
    
    /**
    * @description Query records using the specified custom query
    * @param formInputs Map of the submitted form values 
    * @param configurationOptions - JSON String of the LWC property values from the Experience Builder configration panel
    * @return Specified records as a generic sObject list
    */
    public static List<sObject> getRecords(Map<String, Object> formInputs, Map<String, Object> configurationOptions) {
        List<sObject> recordList = new List<sObject>();
        
        if(configurationOptions.get('accessLevelMode') == 'System') { 
            recordList = Database.queryWithBinds(SiteRegistrationController.convertToString(configurationOptions.get('customQuery')), formInputs, AccessLevel.SYSTEM_MODE);
        }
        else {  
            recordList = Database.queryWithBinds(SiteRegistrationController.convertToString(configurationOptions.get('customQuery')), formInputs, AccessLevel.USER_MODE);
        }

        return recordList;
    }
}
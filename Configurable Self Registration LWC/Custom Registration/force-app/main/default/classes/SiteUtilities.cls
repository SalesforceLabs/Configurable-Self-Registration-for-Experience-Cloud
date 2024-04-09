/***************************************************************************************************************
 * AUTHOR         : Jamie Lowe (Salesforce)
 * CREATE DATE    : 13/04/2024
 * @description Apex controller to provide common functions between SiteRegistration, SiteLogin and others in the future
 ***************************************************************************************************************/
public with sharing class SiteUtilities {
    
    /**
    * @description Simple method to wrap Object's Key > String conversion for easy re-use.
    * @param valueToConvert - pass in an object and convert to a String value
    * @return String of passed object value
    */
    @AuraEnabled
    public static String convertToString(Object valueToConvert) {
        if(valueToConvert != null) {
            return String.valueOf(valueToConvert);
        }
        return '';
    }

    /**
    * @description Simple method to wrap Object > Boolean conversion for easy re-use.
    * @param valueToConvert - pass in an object and convert to a Boolean value
    * @return Boolean of passed object value
    */
    @AuraEnabled
    public static Boolean convertToBoolean(Object valueToConvert) {
        if(valueToConvert != null) {
            return Boolean.valueOf(valueToConvert);
        }
        return false;
    }    

    /** 
     * @description Create a Platform Event (Error Log) which a Flow subscribes. The platform event contains a list of messages to log in a custom object. Off by default, turn on in the Custom Metadata Types.
     * @param loggingEnabled - Passes in the LWC property panel setting to turn logging on or off in a custom object called 'Self Registration Log'
     * @param message - a list of messages to store on the Platform Event
     * @param logType - the type of error to log, either 'Information' or 'Log'
     * @param componentName - the name of the component that is calling this function
     */
    @AuraEnabled
    public static void createLogEntry(Boolean loggingEnabled, String message, String logType, String componentName){
       try {
            if(loggingEnabled) {
                Experience_Cloud_Event__e newLog = new Experience_Cloud_Event__e();
                newLog.Message__c = message;
                newLog.Log_Type__c = logType;
                newLog.Component_Name__c = componentName;
                Eventbus.publish(newLog);
            } 
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    /**
    * @description Checks to see if the Logging setting is activated.
    * @param settingName - pass in the settingName which is related to the component
    * @return true/false depending on setting value.
    */
    @AuraEnabled(cacheable=true)
    public static Boolean isLoggingEnabled(String settingName) {
        
        if(Test.isRunningTest()) { //Always return false if running Tests to prevent failure as the logging can be switched on/off by the user after installation.
            return false;  
        } 
        
        List<Custom_Experience_Cloud_Setting__mdt> logSetting = new List<Custom_Experience_Cloud_Setting__mdt>();
        try {
            logSetting = [SELECT Id, Enable__c, DeveloperName
                        FROM Custom_Experience_Cloud_Setting__mdt 
                        WHERE (DeveloperName = :settingName AND Enable__c = true)
                        WITH SECURITY_ENFORCED
                        LIMIT 1];
        }
        catch(Exception ex) {
            return false;
        }
        
        if(!logSetting.isEmpty() && logSetting.size() == 1) {
            return true;
        }
        return false;
    }
}
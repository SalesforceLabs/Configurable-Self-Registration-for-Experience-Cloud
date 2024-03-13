/***************************************************************************************************************
 * AUTHOR         : Jamie Lowe (Salesforce)
 * CREATE DATE    : 05/02/2024
 * @description Apex controller to support custom built UI Custom Login for Experience Cloud
 ***************************************************************************************************************/
public with sharing class SiteLoginController {
    public class CustomLoginException extends Exception{}
    public static List<String> messages = new List<String>();
    static final String COMPONENT_NAME = 'Login';
 
    /**
     * @description Attempts to login the newly registered user. Redirects to the home page on success.
     * @param username - Passes in the submitted username field from the self registration form.
     * @param password - Passes in the submitted password field from the self registration form. 
     * @param configurationOptions - refers to all parameters configured within the LWC Property Panel within Experience Cloud builder.
     * @return String PageURL to redirect to upon successful login.
     */
    @AuraEnabled(cacheable=true)
    public static String loginUser(String username, String password, Map<String, Object> configurationOptions) {
        String pageUrl = null;

        try {
            ApexPages.PageReference homePageRef = new PageReference(Site.getBaseSecureUrl() + SiteUtilities.convertToString(configurationOptions.get('portalLoginRedirect')));
            String startUrl = homePageRef.getUrl();
            ApexPages.PageReference startPageRef = Site.login(username, password, startUrl);

            //If we are running in a Test, check the test user and throw a custom exception to mimic failed logins.
            if(Test.isRunningTest()) {
                switch on username {
                    when 'testusergenericfail@mail.com' {
                       throw new CustomLoginException('Unknown error.'); 
                    }
                    when 'testusersuccessful@mail.com' {
                        //Don't throw an exception
                    }
                    when else {
                        throw new CustomLoginException('Your login attempt has failed. Make sure the username and password are correct.');
                    }
                }
            }

            if(startPageRef != null) {
                pageUrl = startPageRef.getUrl();
            } else {
                ApexPages.PageReference pageRef = new PageReference(Site.getBaseSecureUrl());
                pageUrl = pageRef.getUrl();
            }

        } catch (Exception e) {

            //Login failed throws back a generic error. Go to the login history to get the full story to present back to the user.
            if(e.getMessage() == 'Your login attempt has failed. Make sure the username and password are correct.') {
               
               //Run in elevated permissions without sharing in a separate class to protect from the guest user as much as possible.
               String status = RetrieveLoginHistory.getUserIdWithUsername(username);

               //If we are running in a Test, check the test user and return a hardcoded status to mimic login history as Site.login() doesn't actually login.
               if(Test.isRunningTest()) {
                    switch on username {
                        when 'testuserblocked@mail.com' {
                            status = 'User is Frozen';
                        }
                        when 'testuserinvalidpassword@mail.com' {
                            status = 'Invalid Password';
                        }
                        when 'testusernotexist@mail.com' {
                            status = 'Username Not Found';
                        }   
                        when 'testuserlocked@mail.com' {
                            status = 'Password Lockout';
                        }
                        when else { //testuserother@mail.com
                            status = '';
                        }
                    }
                }

               //TODO: Handle more types of Login History Status if needed... https://stackoverflow.com/questions/11581806/is-it-possible-to-check-if-a-user-is-locked-out
               switch on status { 
                    when 'User is Frozen' {
                        String error = SiteUtilities.convertToString(configurationOptions.get('blockUserErrorMessage'));
                        messages.add('There was a problem logging ' + username + ' into the portal.' + ' Error: ' + error);
                        SiteUtilities.createLogEntry(SiteUtilities.convertToBoolean(configurationOptions.get('loggingEnabled')), String.join(messages,'\n'), 'Error', COMPONENT_NAME); 
                        throw new AuraHandledException(error);
                    }
                    when 'Invalid Password', 'Username Not Found' {
                        String error = SiteUtilities.convertToString(configurationOptions.get('incorrectUserCredentialsErrorMessage'));
                        messages.add('There was a problem logging ' + username + ' into the portal.' + ' Error: ' + error);
                        SiteUtilities.createLogEntry(SiteUtilities.convertToBoolean(configurationOptions.get('loggingEnabled')), String.join(messages,'\n'), 'Error', COMPONENT_NAME);
                        throw new AuraHandledException(error); 
                    }
                    when 'Password Lockout' {
                        String error = SiteUtilities.convertToString(configurationOptions.get('userLockedOutErrorMessage'));
                        messages.add('There was a problem logging ' + username + ' into the portal.' + ' Error: ' + error);
                        SiteUtilities.createLogEntry(SiteUtilities.convertToBoolean(configurationOptions.get('loggingEnabled')), String.join(messages,'\n'), 'Error', COMPONENT_NAME);
                        throw new AuraHandledException(error);  
                    }
                    when else {
                        messages.add('There was a problem logging ' + username + ' into the portal.' + ' Error: ' + e.getMessage());
                        SiteUtilities.createLogEntry(SiteUtilities.convertToBoolean(configurationOptions.get('loggingEnabled')), String.join(messages,'\n'), 'Error', COMPONENT_NAME); 
                        throw new AuraHandledException('An unknown error has occurred, please contact us for further assistance.');
                    }
               }               
            }
            messages.add('There was a problem logging ' + username + ' into the portal.' + ' Error: ' + e.getMessage());
            SiteUtilities.createLogEntry(SiteUtilities.convertToBoolean(configurationOptions.get('loggingEnabled')), String.join(messages,'\n'), 'Error', COMPONENT_NAME);        
            throw new AuraHandledException('An unknown error has occurred, please contact us for further assistance.');
        }
        messages.add(username + ' successfully logged into the portal.');
        SiteUtilities.createLogEntry(SiteUtilities.convertToBoolean(configurationOptions.get('loggingEnabled')), String.join(messages,'\n'), 'Information', COMPONENT_NAME);     
        return pageUrl;
    }
}
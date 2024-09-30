/***************************************************************************************************************
 * AUTHOR         : Jamie Lowe (Salesforce)
 * CREATE DATE    : 05/02/2024
 * @description Apex controller to support custom built UI Custom Login for Experience Cloud
 ***************************************************************************************************************/
public with sharing class SiteLoginController {
   
    /**
     * @description Custom Exception method. Thrown to force an error when user is not found, and get the Login History. Also called in a test class.
     */
    public class CustomLoginException extends Exception{}
    
    /**
     * @description Attempts to login the newly registered user. Redirects to the home page on success.
     * @param username - Passes in the submitted username field from the self registration form.
     * @param password - Passes in the submitted password field from the self registration form. 
     * @param configurationOptions - refers to all parameters configured within the LWC Property Panel within Experience Cloud builder.
     * @return String PageURL to redirect to upon successful login.
     */
    @AuraEnabled(cacheable=true)
    public static String loginUser(String formInputs, Map<String, Object> configurationOptions) {
        String pageUrl = null;

        Map<String, Object> formJson = (Map<String, Object>) JSON.deserializeUntyped(formInputs);
        String username = String.isNotBlank(SiteUtilities.convertToString(formJson.get('Username'))) ? SiteUtilities.convertToString(formJson.get('Username')) : SiteUtilities.convertToString(formJson.get('Email'));
        String password = String.isNotBlank(SiteUtilities.convertToString(formJson.get('password'))) ? SiteUtilities.convertToString(formJson.get('password')) : '';
        String mobilePhone = String.isNotBlank(SiteUtilities.convertToString(formJson.get('MobilePhone'))) && String.isNotBlank(SiteUtilities.convertToString(formJson.get('countryCode'))) ? UserManagement.formatPhoneNumber(SiteUtilities.convertToString(formJson.get('countryCode')), SiteUtilities.convertToString(formJson.get('MobilePhone'))) : ''; //Format the phone number with the user management class otherwise user isn't found!!;
        String identifier;
        Boolean showVerificationCode = false;
        String result = '';
        String jsonPart = '{"loginResult":[';

        try {

            if(SiteUtilities.convertToBoolean(configurationOptions.get('enablePasswordlessLogin')) ) {
                Auth.VerificationMethod method = SiteUtilities.methods.get(SiteUtilities.convertToString(configurationOptions.get('passwordlessMethod')));
                SiteUtilities.messages.add('Looking for existing user: ' + formJson);
                List<User> user = SiteUtilities.getUserIdWithUsername(username, mobilePhone);
                
                //Only send a code if the user is NOT found!
                if(user.size() == 0) {
                    SiteUtilities.messages.add('Error sending verification code via ' + SiteUtilities.convertToString(configurationOptions.get('passwordlessMethod'))  + ' to User: '+ formJson +' . User not found.');
                    throw new CustomLoginException('Your login attempt has failed. Make sure the username and password are correct.');
                }
                else {
                    SiteUtilities.messages.add('Sending verification code via ' + SiteUtilities.convertToString(configurationOptions.get('passwordlessMethod'))  + ' to User: ' + formJson);
                    identifier = SiteUtilities.sendVerificationCode(method, user[0], SiteUtilities.LOGIN_COMPONENT_NAME);                
                    showVerificationCode = true;
                }
            }
            else {
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
                            //Don't throw an exception.
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
            }

            jsonPart += '{';
            jsonPart += '"pageUrl":"' + pageUrl + '",';
            jsonPart += '"showVerificationCode":' + showVerificationCode + ',';
            jsonPart += '"verificationId":"' + identifier + '"}]}';
            result += jsonPart;
        } catch (Exception e) {

            String status = 'Username Not Found';

            //Login failed throws back a generic error. Go to the login history to get the full story to present back to the user.
            if(e.getMessage() == 'Your login attempt has failed. Make sure the username and password are correct.') {
               
               //Run in elevated permissions without sharing in a separate class to protect from the guest user as much as possible.
               List<User> u = SiteUtilities.getUserIdWithUsername(username, mobilePhone);

               if(u.size() == 1) {
                    status = SiteUtilities.getLoginHistory(u[0].Id);
               }

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
                        SiteUtilities.messages.add('There was a problem logging ' + username + ' into the portal.' + ' Error: ' + error);
                        SiteUtilities.createLogEntry(SiteUtilities.convertToBoolean(configurationOptions.get('loggingEnabled')), String.join(SiteUtilities.messages,'\n'), 'Error', SiteUtilities.LOGIN_COMPONENT_NAME); 
                        throw new AuraHandledException(error);
                    }
                    when 'Invalid Password', 'Username Not Found' {
                        String error = SiteUtilities.convertToString(configurationOptions.get('incorrectUserCredentialsErrorMessage'));
                        SiteUtilities.messages.add('There was a problem logging ' + username + ' into the portal.' + ' Error: ' + error);
                        SiteUtilities.createLogEntry(SiteUtilities.convertToBoolean(configurationOptions.get('loggingEnabled')), String.join(SiteUtilities.messages,'\n'), 'Error', SiteUtilities.LOGIN_COMPONENT_NAME);
                        throw new AuraHandledException(error); 
                    }
                    when 'Password Lockout' {
                        String error = SiteUtilities.convertToString(configurationOptions.get('userLockedOutErrorMessage'));
                        SiteUtilities.messages.add('There was a problem logging ' + username + ' into the portal.' + ' Error: ' + error);
                        SiteUtilities.createLogEntry(SiteUtilities.convertToBoolean(configurationOptions.get('loggingEnabled')), String.join(SiteUtilities.messages,'\n'), 'Error', SiteUtilities.LOGIN_COMPONENT_NAME);
                        throw new AuraHandledException(error);  
                    }
                    when else {
                        SiteUtilities.messages.add('There was a problem logging ' + username + ' into the portal.' + ' Error: ' + e.getMessage());
                        SiteUtilities.createLogEntry(SiteUtilities.convertToBoolean(configurationOptions.get('loggingEnabled')), String.join(SiteUtilities.messages,'\n'), 'Error', SiteUtilities.LOGIN_COMPONENT_NAME); 
                        throw new AuraHandledException('An unknown error has occurred, please contact us for further assistance.');
                    }
               }               
            }
            SiteUtilities.messages.add('There was a problem logging ' + username + ' into the portal.' + ' Error: ' + e.getMessage());
            SiteUtilities.createLogEntry(SiteUtilities.convertToBoolean(configurationOptions.get('loggingEnabled')), String.join(SiteUtilities.messages,'\n'), 'Error', SiteUtilities.LOGIN_COMPONENT_NAME);        
            throw new AuraHandledException('An unknown error has occurred, please contact us for further assistance.');
        }
        SiteUtilities.messages.add(username + ' successfully logged into the portal.');
        SiteUtilities.createLogEntry(SiteUtilities.convertToBoolean(configurationOptions.get('loggingEnabled')), String.join(SiteUtilities.messages,'\n'), 'Information', SiteUtilities.LOGIN_COMPONENT_NAME);     
        return result;
    }
}
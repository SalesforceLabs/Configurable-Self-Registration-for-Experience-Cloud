public with sharing class UserManagementWrapper {
    
    public String verifyUserMock(String formInputs, String configurationOptions) {
        return SiteRegistrationController.verifyUser(formInputs, configurationOptions);
    }

}
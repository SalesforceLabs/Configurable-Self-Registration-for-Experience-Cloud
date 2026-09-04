public with sharing class UserManagementWrapper {
    
    public String verifyUser(String formInputs, String componentName) {
        return SiteUtilities.verifyUser(formInputs, componentName, null);
    }

    public String verifyUser(String formInputs, String componentName, String startUrl) {
        return SiteUtilities.verifyUser(formInputs, componentName, startUrl);
    }

    public String loginUser(String username, String password, Map<String,Object> configurationOptions) {
        return SiteRegistrationController.loginUser(username, password, configurationOptions, null);
    }

    public String loginUser(String username, String password, Map<String,Object> configurationOptions, String startUrl) {
        return SiteRegistrationController.loginUser(username, password, configurationOptions, startUrl);
    }

}

public with sharing class UserManagementWrapper {
  public String verifyUser(
    String configurationOptions,
    String formInputs,
    String componentName
  ) {
    return SiteUtilities.verifyUser(
      formInputs,
      configurationOptions,
      componentName
    );
  }

  public String loginUser(
    String username,
    String password,
    Map<String, Object> configurationOptions
  ) {
    return SiteRegistrationController.loginUser(
      username,
      password,
      configurationOptions
    );
  }
}

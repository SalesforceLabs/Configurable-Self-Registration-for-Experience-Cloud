# Salesforce Labs - Configurable Self Registration for Experience Cloud - Previous Release Notes (v1.93 and earlier)

v2.0 (Winter 27) release notes are in the repository [README.md](../README.md). The admin setup & user guide is [INSTALLATION_GUIDE.md](INSTALLATION_GUIDE.md).

---

### **Version 1.92/1.93**

Patch release. Fixes an issue with package installation in Spring 26 orgs which involves a migration from experiencePropertyTypeBundles to lightningTypes.

---

### **Version 1.91**

Patch release. A number of fixes/small changes added in this release:

* For the unmanaged Git repo, fixes were applied to the Apex Tests so that it can be deployed to Person Account configured orgs AND Business Account/Contact configured orgs with high enough coverage to deploy between environments.
* Fix to the Password/Confirm Password functionality to fire the ‘Passwords do not match’ message onBlur rather than onChange. The message only now fires if there is values in both the Password AND Confirm Password fields resulting in a smoother user experience.
* New fields added to the Experience Cloud logging object. The fields below are added to the ‘All’ List View and the default page layout:
  * **Updated field:** Log Type renamed to Type: No fundamental change other than the label.
  * **New field:** Log Type (Formula) which displays an icon next to Information/Error to draw attention to more important records.
  * **New field:** UserId (Lookup) this is the user who logged in, or who registered successfully.
  * **New field:** Contact Id (Lookup) this is the contact Id for the user interacting with the component. If registration, then it is the contact matched, or the new contact created. This is the Person Contact Id in Person Account orgs.
  * **New field:** Account Id (Lookup) this is the Account Id for the user’s Contact interacting with the component. If registration, then it is the contact matched Account Icd, or the new contact created which uses the Account Id parameter in the component. In Person Account orgs, this is set to the Account Id.
* Fix the Country Code picklist to support a list of all countries. Previously adding all values broke the component as the value was truncated. The field now supports a full list if needed. New installs will default to the full list. Upgrades can add values as needed.

---

### **Version 1.89/1.90**

This release is bug fixes only as follows:

* If a guest user does not have access to a field that is mapped from the form to a Person Account or Contact, it is removed automatically to prevent registration failures. However, up until now this security measure wasn’t logged so it was not visible to admin that this was occurring. Now, in the Experience Cloud logging object you can clearly see fields that will not be mapped due to access:

![image.png](/docs/images/image_rn1.png)

* It was not previously possible to override the Nickname field set on the user object created during registration. It was always being set to “Site User {Current Date Time}”. The value can now be overridden by creating a Custom Metadata record for the CommunityNickname API field which is visible on the form. The submitted value will become the user’s nickname visible in the Experience Cloud site on their profile.
* v1.86 onwards introduced a bug with the mapping of packaged Email/MobilePhone to the Person Account fields PersonEmail and PersonMobilePhone whereby the values weren’t being mapped. This functionality is now fixed so that values from the form map correctly to Person Accounts.

---

### **Version 1.88**

The previous version (1.87) still did not fix the issue with a character limit on the Custom Query property. In v1.88, this has been changed to a multi-line text field to allow up to 2000 characters and does fix the underlying validation issue.

This release also fixes a regression problem in that the component was not installable on orgs where Person Accounts were not enabled due to a reference to a Person Account field that doesn’t exist if the feature is not enabled. This has been rectified.

Again, due to Salesforce limitations, this release has updated the component released in v1.87 also as deprecated and added a new component. It is best to completely uninstall the old package rather than upgrading.

---

### **Version 1.87**

The previous version (1.86) released a Custom Property Editor to make configuration more user friendly in Experience Builder by grouping common settings. This change unintentionally introduced a 255 character limit on the Custom Query parameter. This update contains a fix for this problem.

Due to Salesforce limitations, this release has updated the component released in v1.86 as deprecated and added a new component. It is best to completely uninstall the old package rather than upgrading.

---

### **Version 1.86**

> **NOTE:** If you upgrade to this version, some existing components are deprecated. You will need to manually reconfigure the custom Login/Self Registration components within your site. Please remove and delete the following components from your site/org (take note of any existing settings before doing so!):
> * `customLogin`
> * `customSelfRegistration`

![image.png](/docs/images/file_2_image.png)

They are now deprecated as of v1.86 and replaced with the following new components. Note that these are the API names, the labels as shown in Experience Builder are the same as before.

* `customLoginCPE`
* `customSelfRegistrationCPE`

This release includes the following new features:

* **Support has been added for password-less self registration & login using Email/SMS verification methods**
  * Email is provided by Salesforce free of charge. If you wish to use SMS as a verification method, then an add-on licence must be purchased. See [here](https://help.salesforce.com/s/articleView?language=en_US&id=sf.security_mfa_sms_for_external_users.htm&type=5) for more information.
  * Additional records have been added to the Custom Registration Configuration metadata type to enable easier setup of password-less login and registration. The records are Country Code, Mobile, Verification Code and Identifier. See the [full user guide](https://salesforce.quip.com/M0o9AYupf991) for how to utilise these fields and setup password-less registration/login.
* **Custom Login is now configurable via Custom Metadata**
  * Previously, the login component was restricted to Username/Email and Password. Certain elements of these could be configured such as the Label, Help Text etc but new form fields could not be added. In this release the component has been updated to remove the property panel configuration elements and they are not setup in a Custom Metadata Type called Custom Login Configuration where the same configuration attributes as the Self Registration component are available to use. Because of this change, if you configured the login component previously and changed any of the defaults, then you will need to reconfigure this in the Custom Metadata Type after upgrading.
  * Custom Login Configuration has some default records for Email, Password, Country Code, Mobile, Verification Code and Identifier to support the setup of password-less registration/login. See the [full user guide](https://salesforce.quip.com/M0o9AYupf991) for how to utilise these fields and setup password-less registration/login.
  * The form will now support pre-populating the fields with a value from the URL in the same way that the Custom Self Registration component does.
* **Support for the ‘combobox’ a.k.a a picklist data type in Custom Metadata for Custom Login and Custom Self Registration**
  * You can now configure a picklist to show on your form to capture details from a user during registration and login. For this release, the picklist values are configured using JSON and do not reference picklist metadata setup previously configured. See the [full user guide](https://salesforce.quip.com/M0o9AYupf991) for how to configure this data type.
* **Support for submitting hidden fields with pre-populated values**
  * A field can now be created and hidden on the form by setting the ‘Field Class’ attribute to ‘slds-hide’. The field can be pre-populated using URL parameters to submit hidden values to the server and store them on the User, Contact or Person Account records upon creation. Previously hidden fields were validated during submission which could cause the form to fail validation as the user cannot control the value and therefore the form would not submit.
* **Support for removing First/Last Name from the Self Registration form amongst other small tweaks to streamline the setup.** Required fields are given the following values if not present:
  * Username is automatically set to Email Address
  * First Name set to ‘Site’
  * Last Name set to ‘User’
  * Map Email > Person Email and vice versa if creating a Person Account to allow the form to be configured with either field, whilst still supporting the values to be populated on the user record.
  * Map Mobile > Person Mobile and vice versa if creating a Person Account to allow the form to be configured with either field, whilst still supporting the values to be populated on the user record.
* **Support for configurable icons with the password show/hide functionality via custom metadata types for both Custom Login and Custom Self Registration**
  * *NOTE:* Toggle of Field Type and Field Icon can also be used for other field types but some oddities are expected with input types such as date that include a native icon.
* **Support to switch auto-complete on/off with supported input types (text, email, tel, url)**
  * See [Lightning Input Documentation](https://developer.salesforce.com/docs/component-library/bundle/lightning-input/documentation) for more information.
* **The property panel has been updated to use a Custom Property Editor for Custom Self Registration to group settings into the following logical sections, making it easier to navigate:**
  * **Base Settings:** Contains settings for custom query, button label configuration, configuring email confirmation.
  * **Create Record:** Contains settings for enable the creation of a new record if not found in the query and settings to control which type of record is created.
  * **Error Messages:** Contains all the configurable error messages from before in one section.
  * **Passwordless Login:** Contains all the new settings to support password-less registration & login.

**Fixes:**
* Apply data type conversion to submitted fields for dates, date/times and times, as well as booleans when mapping to a user record. Previously in v1.8, a fix was applied to convert the data type of fields used in the Custom Query and creation of new records but didn’t work if the same custom field name also existed on the user.
* **Ignore hidden fields from form validation when submitting by ignoring fields with ‘slds-hide’ class applied:** Previously, if a field was hidden it was still validated before submitting the form which could potentially stop the form from being submitted. These fields are now ignored and not validated.
* **General tidy up of Apex Classes to merge separate without sharing classes with single methods into Site Utilities:**
  * Previously, there were many separate classes for methods that required the ‘without sharing’ access for guest users. These have been merged in the Site Utilities class which still runs in ‘without sharing’ so that methods can be re-used where appropriate and allows for easier maintenance in future releases.
  * Tidy up of HTML template in both Custom Login and Custom Self Registration to remove some unnecessary logic.
* Changed the “Person Account Record Type” option in Experience Builder to store the Record Type Name, not the Id to prevent deployment issues when deploying Experience Cloud across Sandboxes and Production where the Ids were different. The component now looks up the Id using the Name at run time when creating a Person Account.
* General tidy of Apex Tests to give code coverage of new features for passwordless registration and login, plus others mentioned above.

---

### **Version 1.8 - Fix (06/09/2024)**

A single fix was applied to this version:
* **Apply data type conversion to submitted fields for dates, date/times and times, as well as booleans when creating a record to prevent a record creation failure:** Previously, a fix was applied to convert the data type of fields used in the Custom Query. This fix has now been applied when creating new Contacts and Person Account records to prevent a similar data type error.

---

### **Version 1.5, 1.6, 1.7 - Fixes**

These release fixes a bug with fields that are submitted as blank, and used in the Custom Query causing the error “Key ‘x’ does not exist in the bindMap” where ‘x’ is the name of the field being queried on. The field was not submitted to the server if the field never had a value in it causing this issue. In the latest release, support was also added for checkboxes - NOTE: This does not work in v1.5 but does in v1.7.

*NOTE:* You may still correctly see this error if you have included fields that do not exist on the form in your query which is expected behaviour.

---

### **Version 1.4 - Fixes**

This release includes the following fixes:

* **User already exists error handling improvements:**
  * When the component is set to “Create new Record” if a match isn’t found, a Contact/Person Account record is created. If the submitted Email address matches an existing user in the Salesforce instance then the component previously failed with the generic error “There was a problem during registration. Please contact us for further assistance.”. More details were included in the Experience Cloud Logging and showed in the Dashboard, however, the user wasn’t aware how to fix or what the problem was. The component now correctly displays the configured value from the “Already Registered Error Message” parameter in Experience Builder which by default shows “User is already registered. Please login to continue.” in this scenario.
* **Trim whitespace in submitted values:**
  * When whitespace was included in the fields, the query did not always return results as this was included in the query e.g. `SELECT Id,Email FROM Contact WHERE Email = :Email`, and the submitted value of ` name@salesforce.com ` would be used directly in the query returning no results, even if there was a Contact with an email address of `name@salesforce.com` in the instance. A `trim()` function has now been applied to the submitted values to prevent this behaviour so a submitted value of ` name@salesforce.com ` will now be submitted as `name@salesforce.com` and this value is used in the query.
* **Metadata loop performance fix:**
  * The component made several calls in a loop to the `getGlobalDescribe()` API method to validate that fields included in the Self Registration form existed in the records that they were being mapped to (Contact/Person Account/User). The metadata calls were also used to detect the correct data type of the field to ensure that the submitted value could be stored in Salesforce successfully. This performance issue has now been rectified to ensure that `getGlobalDescribe()` is called outside of the loop.

---

### **Version 1 - Move to Managed Package**

This release moves the package over to a Managed Package for easier upgrades at a later date. It is recommended that you remove the old unmanaged package version before installing this version. There are breaking changes in this release when compared to the Unmanaged Package version.

This version adds several new features to the Custom Metadata Type called Custom Registration Configuration. Each record now contains the following fields offering further configuration possibilities within the component:

* **Field Parent Class:** Style the field’s parent container with a CSS class to help with icon positioning (see user guide for full details).
* **Field Show Icon:** Show/hide the icon.
* **Field Icon Class:** Add the icon below to the left or right of the field.
* **Field Icon Name:** Add an icon within the field using SLDS Icons.
* **Field Label Variant:** Show the field label above the field, to the left or not at all.
* **Field Date Style:** Allows a date field to be configured with different date formats - supported as short (dd/mm/yyyy), medium (Jan 7, 2020), long (January 7, 2020).
* **Field Show Password Visibility:** Add a Show/hide feature on password fields to reveal/mask the value typed.

**Other Changes & Fixes:**
* Fix to Nickname generation on the External User record created during registration. In some scenarios where the email address was 40 characters or more, and this was used by an existing user the component would error. Previously, Nicknames were the Email Address followed by the current date/time in milliseconds to create a unique Nickname and truncated to 40 characters (as per Salesforce requirements). This version places the time in milliseconds before the email to ensure better uniqueness across all users.
* To support the new Login component, a new object has been introduced for the Custom Logging feature called `Experience_Cloud_Log__c`. This replaces the original `Self_Registration_Log__c` object. The object is mostly the same as before, but is now used to log Errors/Information for both components. It adds one new field called Component Name which is now populated with either “Self Registration” or “Login” depending on the component being logged. This change was made to make the object more generic for both use cases, removing references solely to Self Registration. The old object can be safely removed if moving to this version and existing logging is no longer required.
* Alongside this, a new Platform Event and Flow have been added to reference the new objects for consistency rather than leaving old API names in place.
* In addition to the above features, v3 also has the addition of a Custom App called Experience Cloud Logging, with a Home Page Dashboard and some useful reports to highlight recent errors for both components within the last 7 and 30 days.
* A new class has been added called SiteUtilities, which enables sharing of common methods across the Self Registration and Login components to reduce repeated code and offer easier maintainability.
* The Self Registration component now uses the ‘iterator’ instead of ‘lwc:for each’ method to generate the dynamic HTML template to enable detection of the first/last element on the screen. This change allows a dynamic listener on the last field element to allow submitting the form on hitting enter for accessibility.
* The Self Registration’s password match feature is now on change rather than on submit for better user experience. The user no longer needs to submit the form to be told the passwords do not match, the message is shown as the user types a password.

The package now contains a new 2nd component - Custom Login. This component can be used as a replacement to the out of the box Login component. The first version included in this package supports additional features to close the functionality gap in the out of the box version. It is possible to configure error messages for the below scenarios, these use the Login History object to determine the detail behind a login request.

* **Blocked User:** If an admin uses the “Freeze” button on a user and they try to login, this message is displayed.
* **Locked User:** If the user tries to login with incorrect credentials more than the profile’s specified password policy then they are temporarily locked out. When this is the case, this error message is displayed.
* **Account not found / Username or Password not recognised:** If the user tries to login with incorrect credentials, or the account details they are used are not recognised then this error message is displayed.

In addition to the above, each of the field elements for Username and Password are configurable as follows:

* **Username Field Label:** The default is Username. But this can be overridden.
* **Username Label Variant:** The default is “standard” which shows the label above the field. Can be hidden or shown “inline” (to the left of the field) if required.
* **Username Help Text:** Shows in an “I” bubble beside the Field Label if populated. Only supported currently when the field label is set to “standard”
* **Username Placeholder:** Shows a temporary value within the field itself and is hidden when a user types in the field
* **Username Field Icon:** Shows an icon within the field, either to the left or right depending on the CSS Class applied in Parent Container CSS / Icon CSS Class parameters. Currently set to “utility:email”. Other icons available [here](https://www.lightningdesignsystem.com/icons/).
* **Username Field Icon CSS Class:** Currently set to “input-icon-label-shown-right”
* Other classes that can be used are “input-icon-label-hidden-X” or “input-icon-label-inline-X” where X is left or right to place the icon based on the field label variant configuration.
* **Username Parent Container CSS Class:** Currently set to “slds-input-has-icon_right”
* Other classes that can be used are “slds-input-has-icon_left” to place the icon on the left. When using the Field Label Variant of “label-hidden”, you can also specify “top” as an additional class to add spacing between the fields e.g. “slds-input-has-icon_left top”
* **Username Field Validation Message:** The field is required to login. This is the message that is shown to the user if the field is left blank.
* **Username Field REGEX Pattern Match:** A REGEX pattern is used to enforce an email address format for the username field. This is defaulted to the REGEX pattern: `^[a-zA-Z0-9._+\-]+@[a-zA-Z0-9.\-]+\.[a-zA-Z]{2,4}$` which enforces the format of a common email address e.g. `first.last+test@mail.com`
* **Username Field REGEX Pattern Match Message:** This message is shown to the user when the entered username does not meet the requirements. By default, this is configured to *Please enter an email address in the correct format e.g. "example@mail.com"*

Most of the above are also available for the Password field too. Also available for configuration are:

* **Password Field: Show Icon Name:** The default is “utility:preview”. Uses SLDS Icons, see [here](https://www.lightningdesignsystem.com/icons/#utility) for other supported icons. The icon that is displayed when the password value is hidden. Clicking the icon shows the password.
* **Password Field: Hide Icon Name:** The default is “utility:hide”. Uses SLDS Icons, see [here](https://www.lightningdesignsystem.com/icons/#utility) for other supported icons. The icon that is displayed when the password value is shown. Clicking the icon hides the password.
* **Enable Show Password function:** This shows or hides the preview icon in the field.
* **Login Button Label:** Set to Login by default, but can be changed.
* **Login Waiting Button Label:** Set to “Logging in…Please Wait” by default. Can be overridden as required.
* **Redirect URL after Login:** The URL that the user is redirected to after a successful login. The default is the home page.

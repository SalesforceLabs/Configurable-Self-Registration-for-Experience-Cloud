# Configurable Self Registration & Login LWC for Experience Cloud - Admin Installation & Setup Guide - Updated April 2026 (Managed Package v1.93)

**<u>Summary</u>**

This package includes 2 components - Custom Self Registration and Custom Login. It is designed for use in Experience Cloud sites where the out of the box components do not meet your business needs and configurability is required. The components can be used together to complement each other, or individually.

The components have been designed to accommodate the average Salesforce Administrator who wishes to simply install and configure with no code involved. You are only required to know a little bit about SOQL queries for the Custom Self Registration component, everything else is deliberately admin friendly! The components offer many configuration options which are described throughout this document and they may or may not fit your use cases exactly, but aims to fill the gaps and extend existing functionality to provide a more flexible solution.

Leave comments on your thoughts for improvements, or if you find bugs then raise an Issue via the [GitHub repository](https://github.com/SalesforceLabs/Configurable-Self-Registration-for-Experience-Cloud) so I can investigate and fix. I will aim to maintain the solution as much as possible as time allows. Please note that unfortunately LWC development is not my full time job and this was created in my spare time.

**<u>Prerequisites</u>**

The package install requires that your Salesforce Org has the following features enabled before installing the AppExchange package:

NetworksEnabledOnce: This refers to Experience Cloud and enabling the Digital Experiences feature from Setup > Digital Experiences > Settings. Enable the setting, and save then try the installation again.

![image9.png](/docs/images/image9.png)

The Custom Self Registration component requires that Self Registration is enabled on your site. Within your site > Workspaces > Administration > Login & Registration ensure that you enable the “Allow customers and partners to self-register” setting:

![2024-09-06_11-51-53.png](/docs/images/2024-09-06_11-51-53.png)

**<u>Installation</u>**

From the AppExchange, click Get it Now on the listing. Install in your organisation for Admin Users. Once the package has been installed on your org, two new Lightning Web Components will become available to you within the Experience Cloud Builder under **Custom Components**

![image6.png](/docs/images/image6.png)

Navigate to the Login or Register page, then simply drag and drop the relevant component onto the canvas to begin configuring it for use.

**<u>Permission Sets</u>**

There are four Permission Sets provided as part of the package:

* Custom Login - Guest Access
* Custom Login - Internal Access
* Custom Self Registration - Guest Access
* Custom Self Registration - Internal Access

These Permission Sets should be assigned appropriately to allow access to the necessary Objects & Fields, Custom Metadata Types and Apex Classes which control the component’s various features.

| Permission Set Name | Object & Field | Custom Metadata Type | Apex Class |
| :--- | :--- | :--- | :--- |
| Custom Login - Guest Access | Experience Cloud Event<br>User (Custom Field only) | Custom Experience Cloud Setting<br>Custom Login Configuration | SiteLoginController<br>SiteUtilties<br>LoginHistory |
| Custom Login - Internal Access | Experience Cloud Log<br>Experience Cloud Event<br>User (Custom Field only) | Custom Experience Cloud Setting<br>Custom Login Configuration | SiteLoginController<br>SiteUtilties<br>LoginHistory |
| Custom Self Registration - Guest Access | Experience Cloud Event<br>User (Custom Field only) | Custom Experience Cloud Setting<br>Custom Registration Configuration | SiteRegistrationController<br>SiteUtilties<br>RetrieveRecordsForQuery<br>RetrieveNetworkMembers |
| Custom Self Registration - Internal Access | Experience Cloud Log<br>Experience Cloud Event<br>User (Custom Field only) | Custom Experience Cloud Setting<br>Custom Registration Configuration | SiteLoginController<br>SiteRegistrationController<br>SiteUtilties<br>LoginHistory<br>RetrieveRecordsForQuery<br>RetrieveNetworkMembers |

To assign a Permission Set to a User, open the relevant Permission Set, click Manage Assignments and then follow the wizard. Search for ‘guest’ in the All Users list will return a Guest User for each Experience Cloud portal on your org, so ensure you choose the correct user if more than one is available:

![image7.png](/docs/images/image7.png)

**<u>Guest User Sharing Rules</u>**

The Custom Self Registration component runs as the Guest User when accessing it via an Experience Cloud site. The component has been secured so that it runs in a ‘with sharing’ context, but executes queries, and other system methods as needed in a ‘without sharing’ context. Use the Access Level parameter with care - System Mode ignores Field Level/Object Level to the Guest User to run the specified query. User mode will enforce Field Level/Object Level Access as per your org settings. Criteria Based Sharing Rules can be used to share any relevant Accounts, Contacts or Cases with the Guest User to open up further access if needed.

**<u>Component Parameters</u>**

The following parameters are available for configuration once you have added the Custom Self Registration component to the Register page. The parameters have been organised into tabs for easier setup:

![image.png](/docs/images/image.png)

* **Base Settings**
  * **Custom Query:** Write a custom SOQL query to find a matching Contact, Account (if using Person Accounts) or Case to relate a newly registered Portal User to (External User). See below for more information.
  * **Access Level for SOQL Query:** Controls the access level for the query above. Change to ‘User’ if the query should run as the Guest User or ‘System’ to run the query with elevated access and see all data.
  * **Send Email Confirmation:** When the user successfully registers, an email notification is sent to the user from Salesforce. You may wish to turn this off if using another tool such as Marketing Cloud to send out registration emails. You could use the “Is Customer Portal” checkbox to trigger a journey into Marketing Cloud. If enabled, change the content of the email easily by navigating to the template set in Welcome New Member setting within Experience Cloud.
  * **Sign Up Button Label:** This is the text shown in the “Sign Up” button when the page loads and before the button is clicked.
  * **Sign Up Button Waiting Message:** This is the text shown briefly on the Sign Up button once the form is submitted and before the page redirects to the portal home page (if the registration was successful).
  * **Redirect URL After Registration:** After registration, the user is redirected to this Portal page. The default is “/” which takes the user to the configured Home Page. However, this could be another page such as the default Case List View using “case/Case/Default”.
* **Create New Record**
  * **Create Record on Registration (if not found):** If a record is not found using the above custom query, then a new record can be created and related to the External User instead.
  * **Object Type to Create:** If the above setting is set to TRUE, set whether the component should create a Contact or Person Account. Note that Person Accounts must be switched on and configured before you can use this functionality otherwise you will experience all kinds of weird behaviour!
  * **Account Id:** If the “**Object Type to Create**” setting is set to Contacts, then set the Account Id of an existing Account to link a Contact to. This ensures that visibility can be enforced for any Contacts that have self registered.
  * **Person Account Record Type:** If the “**Object Type to Create**” setting is set to Person Accounts, then set the Record Type of the Person Account Record Type in your Org. Person Accounts must already be enabled in the org for this option to be configured successfully.
* **Error Handling**
  * **Password Match Error Message:** When registering, if the Password and Confirm Password fields do not match then this message is displayed.
  * **Username Taken Error Message:** If the username chosen when registering is already taken, then display this message.
  * **Record Not Found Error Message:** If a record is not found based on the submitted details and the configured custom query then this message is displayed.
  * **Multiple Records Found Error Message:** If a record is not found based on the submitted details and the configured custom query then this message is displayed.
  * **Login After Registration Error Message:** If there is a problem logging into the portal after registration, then this message is displayed.
  * **User Creation Error Message:** If there is a problem creating an external user, then this message is displayed.
  * **Already Registered Error Message:** If the matched record from the Custom Query is already registered for the portal, then this message is displayed.
* **Passwordless Login**
  * **Enable Passwordless Login:** Set to TRUE to enable the passwordless login feature. Additional setup is required, please see the Setting Up Passwordless Registration & Login section for more details.
  * **Verification Method:** Select either ‘Email’ or ‘SMS’. NOTE: If you wish to use SMS as a verification method, then an add-on licence must be purchased. See [here](https://help.salesforce.com/s/articleView?language=en_US&id=sf.security_mfa_sms_for_external_users.htm&type=5) for more information.
  * **Profile Id:** Select the profile that will be assigned when a new user registers using a passwordless verification method. The profiles selectable here are site ‘Members’.
  * **Submit Verification Button Label:** The default value is set to “Submit Verification Code”, however it can be overridden as required. This button label is shown to the user when they try to register, and the form is awaiting the user to enter a code they have received via Email or SMS.
  * **Verification Code Send Error:** If the form fails to send a verification code via the selected Verification Method, this message overrides the unhelpful system message shown to the user. To understand the full message and debug, the system admin can look at the Experience Cloud Logs custom object to fix the issue..
  * **Verification Code Validation Error:** If the form fails to validate the verification code entered by the user, this message overrides the unhelpful system message shown to the user. To understand the full message and debug, the system admin can look at the Experience Cloud Logs custom object to fix the issue.

**<u>Basic Setup - Self Registration</u>**

When the component is first added to the canvas, the Custom Query parameter is blank and must be configured as a minimum to use the component. You can write your own SOQL query to identify an existing Contact, Person Account or Case during registration to link the registration to, if a record is not found then you could later decide to create a record. Updates are not supported to an existing record.

The query can be dynamic and supports values submitted on the registration form. For example, you can use the submitted email address of the user registering to find a Contact, Person Account or Case in Salesforce. To do this, include one of the following bind variables in your query:

* :FirstName
* :LastName
* :Username
* :Email

The query must return exactly 1 record to ensure a unique match. If the query finds more than 1 result, then the component will error during registration with the parameter value set in “Multiple Records Found Error Message” and the site visitor will be unable to register to your Experience Cloud portal. Due to this, use LIMIT 1 within your chosen query as per the examples. If more than one record is found, only the first one found is used, ignoring any others. 

> **Important**  
> *Do not use spaces between field names for the SELECT part of the SOQL statement otherwise the component will not validate the query correctly.*  
> *AccountId is a required field when querying the Contact object. If you omit the field from the Custom Query parameter, the Custom Self Registration component will error.*

***Example 1 (Contacts):***  
`SELECT Id,AccountId,Email FROM Contact WHERE Email = :Email LIMIT 1`

This query attempts to find a Contact where the email address submitted matches a Contact in the Salesforce instance. It returns 1 result.

***Example 2 (Person Accounts):***  
`SELECT Id,PersonEmail FROM Account WHERE PersonEmail = :Email AND IsPersonAccount = true LIMIT 1`

This query attempts to find a Person Account where the email address submitted matches an Account and the record is a Person Account type.

If your Org’s data quality isn’t great, you may also wish to enable logging so you can log each registration and monitor for problems. This will ensure that errors are caught and you have visibility of the failures in the Experience Cloud Logs custom object. See “Enabling Custom Logging” section for more information.

If you have configured Custom Fields to show on your form using the Custom Self Registration Configuration metadata type (see below), then these fields can also be passed to your SOQL query using the API Name of the field. For example, if you create a Custom Field called “Reference Number”, the API Name is set to “Reference_Number__c” by default by Salesforce on field creation (NOTE: This could have been manually overridden). Simply use “:Reference_Number__c” as part of your query as shown:

***Example 3 (Contacts with Custom Field):***  
`SELECT Id,Email,Reference_Number_c FROM Contact WHERE Reference_Number_c = :Reference_Number_c LIMIT 1`

The default behaviour of the component at this point is to display a message to the user as configured in the **Record Not Found Error Message** parameter if your query returns no results, or if there is more than 1 result, then the **Multiple Records Found Error Message** parameter is shown instead.

The Custom Query can be run in User, or System Mode which affects the results that are found. Change the Access Level for SOQL Query setting accordingly. The registration form runs as a Guest User, and thus so does your Custom Query so you ***MUST*** carefully consider which option you wish to use based on the security measures enforced by your org.

<u>**Create Record on Registration (if not found)**</u>

This option does exactly what it says on the tin! If your Custom Query does not find a record and this mode is enabled, then a new record is created. This setting works in tandem with the Object Type to Create setting where you can choose to create a Contact linked to a pre-existing Account, or a Person Account (if your org is configured to support Person Accounts).

Turn this setting on by ticking the checkbox, then choose the appropriate object type to create.

If creating a Contact, ensure you have an Account to attach any new registrations to which will enforce any security settings configured in your org. Without setting an Account Id, the Contact remains private and may not be visible to your users - see [here](https://help.salesforce.com/s/articleView?id=sf.contacts_private.htm&type=5). Navigate to an Account, copy the Id from the browser URL bar (starting 001) into the component configuration panel.

![image4.png](/docs/images/image4.png)

If creating a Person Account, select the appropriate Person Account record type from the Picklist. You do not need to set the Account Id parameter for this object type.

**Send Email Confirmation**

By default, the component sends an email from Salesforce upon successful registration using the Welcome Email template configured in Workspaces.

Switch this feature off if you plan to use some other tool for successful registration. For example, you may wish to use Marketing Cloud and add new registered users to a specific journey rather than relying on standard templates.

**Configuring Form Fields on the Self Registration Form**

By default, there are number of fields available in Custom Metadata that can be configured. Different fields are required dependent on the configuration of the form. The form will show the following standard fields once installed:

* First Name
* Last Name
* Email
* Password
* Confirm Password

The following fields are available, but not shown by default:

* Country Code
* Mobile
* Verification Code
* Identifier

Each of these fields are controlled from Setup > Custom Metadata Types > Custom Registration Configuration. From here, you amend each record to change the field behaviour, for example show/hide field, make a field required or not, change length etc.

It is possible to capture Custom Fields during registration and store them on the Contact/Account record created as part of the registration. Fields can also be used in the Custom Query as described earlier.

> **Password mode:** Minimum of Email, Password and Confirm Password are required. If the First/Last Name fields are not provided then these are set to “Site” and “User” automatically. If a username is not provided, then the Email address is used. You can use a Login Flow or provide a menu option and allow a user to update these later if needed.  
>  
> **Passwordless mode:** Depending on the Verification Method chosen, either Email or Mobile Number is required. When using SMS verification, a Country Code is also required to be captured.

> **OTHER NOTES**  
> *The nickname field is populated with “SiteUser” + current timestamp.*  
> *Data captured during registration is stored on the Contact/Person Account when creating a new Contact/Account only, not if an existing record is matched.*

> **IMPORTANT NOTES**  
> *Whilst the component will let you can hide all fields, some are required for a successful registration. This varies depending on the configuration settings on the component.*

Start by creating a new Custom Field on the Contact or Account object from Setup > Object Manager.  Next, navigate to Setup > Custom Metadata Types > Manage Record beside the Custom Registration Configuration option. Click New to begin configuring a new field. Fill out the following options:

* **Label & Custom Registration Configuration Name:** These fields are not used by Experience Cloud. Set them to something suitable based on any customisation standards defined by your org.
* **Active:** Ensure you set the new configuration to Active to display it on the registration form.
* **Portal API Name:** The easiest way to discover the API Name of your Experience Cloud portal is to use a simple SOQL query which can be run from the Developer Console of your Salesforce org or using an external tool such as Workbench. Run the following query: *SELECT Id,Name,UrlPathPrefix FROM Site* -
* *NOTE: The query may return 2 results, use the value with “1” appended to the end.*
* *NOTE: You can also use the value “ALL” if you have one site configured on your Org, or you wish to share this configuration deliberately across multiple sites using this component.*
* **Field Label:** Set this to the label that will be displayed to the user on the registration form.
* **Field API Name:** Set this to the API Name of the field that you created on the User object.
* **Field Type:** The default is ‘text’, however other data types are supported. Pick the most appropriate from the list for the field you wish to display to prevent submission errors.
* **Display Order:** Set this to a number. The component sorts fields by this value. The default fields are set with values 1-6. For custom fields enter a number >6 to display the field after the standard ones, or amend all records to create a custom sort order.
* **Field Help Text:** This value is used to guide the user during registration. It shows in a small help bubble beside the Field Label on the form.
* **Field Placeholder:** This value displays on the form field before a value is entered to provide guidance to the user on what to enter.
* **Field Class:** Populate this with a custom CSS class.
  * This option is used within the Password/Confirm Password fields to identify them for Custom Validation that is applied. The password fields apply the “passwordCmp” and “confirmPasswordCmp” classes. Do not remove them otherwise the comparison functionality will not work.
  * Apply the “slds-hide” class to hide the field from the form, but still submit a value to Salesforce. Hidden fields can be pre-populated via URL parameters - see the section Pre-populating form values for more information.
* **Field Parent Class:** Style the field’s parent container with a CSS class to help with icon positioning (See the section “Configuring CSS for Icons” for more information) or other custom use cases
* **Field Show Icon:** Show/hide the defined icon within the field.
* **Field Icon Class:** Add the icon below to the left or right of the field using CSS classes. See the section “Configuring CSS for Icons” for more information.
* **Field Icon Name:** Add an icon within the field using SLDS icons. See [here](https://www.lightningdesignsystem.com/icons/) for more information.
* **Field Label Variant:** Show the field label above the field (standard & default), to the left (inline) or not at all (hidden).
* **Field Date Style:** Allows a date field to be configured with different date formats - supported as short (dd/mm/yyyy), medium (Jan 7, 2020), long (January 7, 2020).
* **Field Picklist Options:** When using the ‘picklist’ datatype, specify the options here in JSON format. You can specify API names which is the value submitted and labels that are displayed to the user. This feature does not currently lookup picklist metadata. If a value is specified here and you try to map to a picklist that does not hold the value entered, then the registration will fail.
  * Example: `[{"label": "(+1) United States", "value": "1"},{"label": "(+44) United Kingdom", "value": "44"}]`
  * This displays (+1) United States to the user, but submits the value of “1” if chosen.
* **Field Toggle Type:** This option is mainly used to control the password show/hide functionality. When the icon is clicked on the field, the field type is changed dynamically to the type set here.
* **Field Toggle Icon Name:** This option is mainly used to control the password show/hide functionality. When the icon specified in Field Icon Name setting is clicked on the field, the icon is changed dynamically to the new icon set here. Add an icon within the field using SLDS icons. See [here](https://www.lightningdesignsystem.com/icons/) for more information.

**Customisable Error Messages:**

* **Field Validation Regex:** Choose the required format of data entered into the field during registration.
* **Field REGEX Message:** This is the error message displayed if the Field Validation Regex is not met or the field is set to required and has not been populated.
* **Field Required:** Choose whether the field must be populated to submit the registration form.
* **Field Required Message:** This message is displayed when the field is required, and the user navigates away from the field when it is empty.
* **Field Min Characters:** Specify the minimum length of a field on the registration form
* **Field Message Too Short:** Display a message when the field length is below the minimum characters specified above.
* **Field Max Characters:** Set the max length of the field on the registration form. It must not exceed the field length of the Custom Field otherwise failures during registration will occur.
* **Field Message Too Long:** Display a message when the field length is above the maximum characters specified above. NOTE: In some browsers, the maximum characters behaviour blocks a user from entering more than the specified characters so this message may not fire. Use Field Validation REGEX & Field REGEX Message instead to e.g. “.{0,3}” to fire a message when more than 3 characters are entered.
* **Minimum Value:** The lowest value or earliest date/time/datetime that this field will accept. This can be set to a number, date, datetime or time value and is not supported with other Field Types.
* **Field Under Minimum Range Message:** Set the message that will be displayed if the field is below the Minimum Value.
* **Maximum Value:** The highest value or latest date/time/datetime that this field will accept. This can be set to a number, date, datetime or time value and is not supported with other Field Types.
* **Field Over Max Range Message:** Set the message that will be displayed if the field is above the Maximum Value.

![2024-10-08_12-17-16.png](/docs/images/2024-10-08_12-17-16.png)

Once you are happy with the configuration, save the Custom Metadata, then go back to Experience Cloud and refresh the page to show the custom fields. You do not need to re-publish the site for these changes to take effect. Add as many Custom Fields as required, but do consider the user experience before capturing too many fields!

<u>**Show/Hide Password Functionality**</u>

On the password fields for both the Custom Login and Custom Self Registration components, the following metadata options are configured:

* **Field Show Icon:** Set to TRUE to show an icon within a field. Also consider setting the CSS override options to place the icon in the correct position. See the “Configuring CSS for Icons” section for more details. 
* **Field Icon Name:** Default value is “utility:preview”. Add an icon within the field using SLDS icons. See [here](https://www.lightningdesignsystem.com/icons/) for more information.
* **Field Toggle Type:** Set to ‘text’.
* **Field Toggle Icon Name:** Default value is “utility:hide”. Add an icon within the field using SLDS icons. See [here](https://www.lightningdesignsystem.com/icons/) for more information.

The password fields start as the ‘password’ input type, and therefore the value entered by the user is masked from view. When the specified icon is clicked, the icon changes to the “Field Toggle Icon Name” setting value. The field type changes to the “Field Toggle Type” setting value i.e. ‘text’ and therefore the entered value is visible in plain text within the browser.

On load...

![2024-10-08_12-26-48.png](/docs/images/2024-10-08_12-26-48.png)

On click of the icon...

![2024-10-08_12-27-06.png](/docs/images/2024-10-08_12-27-06.png)

**<u>Pre-populate Form Fields</u>**

Both components support the ability to pre-populate defined fields on the form from values in the URL Parameters. When a user navigates to your Login or Self Registration page, add the API Name of a given field and its value at the end of the page URL in the format:

*?Reference_Number__c=1234567*

If the API Name provided exists on the form when the page loads, the value for that parameter is pre-populated on the form. Multiple fields can be populated by separating the parameters with the “&” symbol e.g:

*?Reference_Number__c=1234567&FirstName=Test*

> **IMPORTANT NOTE**  
> *There is no validation of the data set at the point of the page loading. The form is only validated when a user navigates away from a field, or the form is submitted - at which point, the component will fire any configured validation messages.*

![2024-10-08_12-28-29.png](/docs/images/2024-10-08_12-28-29.png)

A field can be hidden from view and still pre-populated. This value will be populated when a new record is created as it does for other fields on the form.

**<u>Basic Setup - Login</u>**

The Custom Login component configuration is set up in a similar way to the Custom Self Registration component. In the Experience Cloud Builder tool, there are a number of parameters that can be configured to change the behaviour:

* **Login Button Label:** Set to Login by default, but can be changed.
* **Login Waiting Button Label:** Set to “Logging in…Please Wait” by default. Can be overridden as required.
* **Redirect URL after Login:** The URL that the user is redirected to after a successful login. The default is the home page.

Error messages are configurable with the following parameters:

* **Blocked User Error Message:** If an admin uses the “Freeze” button on a user and they try to login, this message is displayed.
* **Locked User Error Message:** If the user tries to login with incorrect credentials more than the profile’s specified password policy then they are temporarily locked out. When this is the case, this error message is displayed.
* **Incorrect Username/Password Error:** If the user tries to login with incorrect credentials, or the account details they are used are not recognised then this error message is displayed.

Passwordless Login features are configurable with the following parameters:

* **Enable Passwordless Login:** Set to TRUE to enable the passwordless login feature. Additional setup is required, please see the Setting Up Passwordless Registration & Login section for more details.
* **Verification Method:** Select either ‘Email’ or ‘SMS’. NOTE: If you wish to use SMS as a verification method, then an add-on licence must be purchased. See [here](https://help.salesforce.com/s/articleView?language=en_US&id=sf.security_mfa_sms_for_external_users.htm&type=5) for more information.
* **Submit Verification Button Label:** The default value is set to “Submit Verification Code”, however it can be overridden as required. This button label is shown to the user when they try to register, and the form is awaiting the user to enter a code they have received via Email or SMS.
* **Verification Code Send Error:** If the form fails to send a verification code via the selected Verification Method, this message overrides the unhelpful system message shown to the user. To understand the full message and debug, the system admin can look at the Experience Cloud Logs custom object to fix the issue..
* **Verification Code Validation Error:** If the form fails to validate the verification code entered by the user, this message overrides the unhelpful system message shown to the user. To understand the full message and debug, the system admin can look at the Experience Cloud Logs custom object to fix the issue.

From here, fields that are shown are controlled by the Custom Metadata Type called Custom Login Configuration. The same attributes are available for the login form fields as they are for the self registration component.

<u>**Setting Up Passwordless Self Registration & Login**</u>

The journey to enable Passwordless features for these components begins with a portal user self registering for the portal. After they have registered with either an Email or Password, then they can login using that method going forwards. The user will receive a verification code to the email or as an SMS to the mobile phone number they provide.

> NOTE: The components can be configured to support ***either*** email OR mobile verification for the initial Self Registration. The user cannot self register again for a 2nd device. They need to do this once authenticated.

**<u>Custom Self Registration - Custom Metadata</u>**

The component should be configured in the following way to turn the feature on:

In Custom Metadata Types > Custom Registration Configuration, turn on the following fields:

* Country Code (only when verification method = SMS)
* Mobile Phone (only when verification method = SMS)
* Email (only when verification method = Email)
* Verification Code
* Identifier

It is not a necessarily a requirement, but it is best to turn off all other fields. The recommendation is for the form to show only show the country code & mobile OR email fields. The verification code is shown only once the user fills out their contact details and clicks sign up. The identifier field is always hidden from view and is a system field required to make the passwordless functionality work. 

The premise of passwordless is to streamline the approach as much as possible and therefore capture minimal data at sign up. Whilst it can be done here, this data can always be captured later via a profile page, or login flow depending on the requirements.

**<u>Custom Self Registration - Experience Builder Parameters</u>**

In Experience Builder, navigate to the Passwordless Login tab in the property panel. Set/Review the following parameters:

* **Enable Passwordless Login:** Set to TRUE to enable the passwordless login feature. 
* **Verification Method:** Select either ‘Email’ or ‘SMS’. NOTE: If you wish to use SMS as a verification method, then an add-on licence must be purchased. If you do not have the appropriate licence, then you will not see the SMS licence. See [here](https://help.salesforce.com/s/articleView?language=en_US&id=sf.security_mfa_sms_for_external_users.htm&type=5) for more information.
* **Profile Id:** Select the profile that will be assigned when a new user registers using a passwordless verification method. The profiles selectable here are site ‘Members’.
* **Submit Verification Button Label:** The default value is set to “Submit Verification Code”, however it can be overridden as required. This button label is shown to the user when they try to register, and the form is awaiting the user to enter a code they have received via Email or SMS.
* **Verification Code Send Error:** If the form fails to send a verification code via the selected Verification Method, this message overrides the unhelpful system message shown to the user.  Use the default, or change as required.
* **Verification Code Validation Error:** If the form fails to validate the verification code entered by the user, this message overrides the unhelpful system message shown to the user. Use the default, or change as required.

> **NOTE:** *Remember to re-publish your site after making the above changes so that they take effect.*

**<u>Custom Login - Custom Metadata</u>**

Once a user has registered using the Self Registration component, they can then login with that device going forwards as long as the Custom Login component is configured appropriately. The configuration is much the same as the Custom Self Registration setup. In Custom Metadata Type > Custom Login,  ensure that the following fields are enabled:

* Country Code (only when verification method = SMS)
* Mobile Phone (only when verification method = SMS)
* Email (only when verification method = Email)
* Verification Code
* Identifier

**<u>Custom Login - Experience Builder Parameters</u>**

Similar parameters are available for Custom Login in the Experience Builder property panel. Review the following settings:

* **Enable Passwordless Login:** Set to TRUE to enable the passwordless login feature. 
* **Verification Method:** Select either ‘Email’ or ‘SMS’. NOTE: If you wish to use SMS as a verification method, then an add-on licence must be purchased. If you do not have the appropriate licence, then you will not see the SMS licence. See [here](https://help.salesforce.com/s/articleView?language=en_US&id=sf.security_mfa_sms_for_external_users.htm&type=5) for more information.
* **Profile Id:** Select the profile that will be assigned when a new user registers using a passwordless verification method. The profiles selectable here are site ‘Members’.
* **Submit Verification Button Label:** The default value is set to “Submit Verification Code”, however it can be overridden as required. This button label is shown to the user when they try to register, and the form is awaiting the user to enter a code they have received via Email or SMS.
* **Verification Code Send Error:** If the form fails to send a verification code via the selected Verification Method, this message overrides the unhelpful system message shown to the user.  Use the default, or change as required.
* **Verification Code Validation Error:** If the form fails to validate the verification code entered by the user, this message overrides the unhelpful system message shown to the user. Use the default, or change as required.

> **NOTE:** *Remember to re-publish your site after making the above changes so that they take effect.*

**<u>Configuring CSS for Icons</u>**

The Self Registration and Login components allow the configuration of icons that appear within a configured field (Self Registration) or within the provided Username/Password fields (Login). The icon can be positioned using one of the provided CSS classes documented below. 

**<u>Self Registration classes</u>**

The following table documents the Custom Metadata configuration needed to display an icon in the specified position. Also set Show Field Icon to TRUE, and set an Icon Name to a valid SLDS utility icon e.g. “utility:email”.

| Label Variant | Desired Icon Position | Field Parent Class | Icon Class |
| :--- | :--- | :--- | :--- |
| Standard | Left | slds-input-has-icon_left | input-icon-label-shown-left |
| Standard | Right | slds-input-has-icon_right | input-icon-label-shown-right |
| Inline | Left | slds-input-has-icon_left | input-icon-label-inline-left |
| Inline | Right | slds-input-has-icon_right | input-icon-label-inline-right |
| Hidden | Left | slds-input-has-icon_left | Input-icon-label-hidden-left |
| Hidden | Right | slds-input-has-icon_right | input-icon-label-hidden-right |

A Field Parent Class is needed to add padding around the field’s icon to stop typed text overlaying the icon.

In addition to the Icon Class, you can use the class “top” for the Hidden variants above to place padding between each of the fields when no label is displayed.

**<u>Login classes</u>**

Similar to the Self Registration component, the Username and Password fields can also have icons but as the form is solely configured in the Experience Cloud builder, these settings are applied in the property panel, not Custom Metadata Types.

| Username / Password Label Variant | Desired Icon Position | Username / Password Parent Container CSS Class | Username / Password Field Icon CSS Class |
| :--- | :--- | :--- | :--- |
| Standard | Left | slds-input-has-icon_left | input-icon-label-shown-left |
| Standard | Right | slds-input-has-icon_right | input-icon-label-shown-right |
| Inline | Left | slds-input-has-icon_left | input-icon-label-inline-left |
| Inline | Right | slds-input-has-icon_right | input-icon-label-inline-right |
| Hidden | Left | slds-input-has-icon_left | Input-icon-label-hidden-left |
| Hidden | Right | slds-input-has-icon_right | input-icon-label-hidden-right |

For the Password Field, there can be two possible icons which show or hide the password value typed. There are parameters for each where the above classes are applied to:

* **Password Field: Show Icon Name**
* **Password Field: Hide Icon Name**

As per the Self Registration component, the **Parent Container CSS Class** is needed to add padding around the field’s icon to stop typed text overlaying the icon.

In addition to the Icon Class, you can use the class “top” for the Hidden variants above to place padding between each of the fields when no label is displayed.

Further styling can be configured via the Experience Builder CSS Override feature. However, this document does not cover that in detail. Refer to the Salesforce help for more information.

<u>**Create Log Entry for Self Registrations & Logins**</u>

By default, this feature is off for both components. Turn it on in Setup > Custom Experience Cloud Setting. Enable logging by setting the “Enable” value to TRUE. 

![image2.png](/docs/images/image2.png)

This setting creates noisy logging for each registration / login and thus it is not recommended to leave this on continuously. This setting is particularly useful when first configuring the components as it gives you a detailed trail of what happened without having to navigate complex Debug Logs.

A single log record is created at the end of processing the Self Registration form submission with details of:

* Validating Username - is the chosen name available or taken
* Validating Password - was it valid and met the SF org requirements
* Actual registration i.e. locating a record, creating a new record, creating an external user etc.
* Confirmation of sending/verifying a validation code (NOTE: Sending/Verification creates 2 separate records as it requires a 2nd form submit)

For Login, the record is more simple and logs only a success message, or in the instance of a failure the message that is configured in the Experience Cloud builder for the scenario encountered e.g. if the user is blocked the message will say “There was a problem logging {username} into the portal.” Followed by the message “Your account has been temporarily disabled. Please contact us for assistance.” assuming the default has not been changed.

There are two Log Types used - Error and Information. The Component Name is also stored. Use the Message field to understand the steps completed.

![image5.png](/docs/images/image5.png)

Some basic Reports & Dashboards on the error data are installed with the package and accessible via the Experience Cloud Logging app or via the Reports/Dashboards tabs directly. These can be used to quickly identify problems that arise and proactively investigate them.

![image8.png](/docs/images/image8.png)

Experience Cloud Log records are created via a Platform Event (Experience Cloud Event) & Flow subscription and are accessible to System Admins by default. Configure another Permission Set as required to give other users access.

**Expected Errors:**

The following errors are shown in Experience Cloud builder and are expected behaviour. The table below summarises the known errors:

| Error | Description |
| :--- | :--- |
| Only Contact or Account objects are supported with the Custom SOQL Query on this component. | If you try to query other object types over the ones supported e.g. Case, then you will see this message.<br>Update the Custom Query parameter to query Contacts or Accounts. |
| Person Accounts are not enabled on this org so you cannot use Accounts in a Custom Query. | If your Custom Query uses the Account object and Person Accounts are not configured in your org.<br>Either use Contacts, or configure Person Accounts before using this component. |
| Object Type to Create cannot be blank when the Create Record function is set to TRUE. | You’ve enabled the “Create Record During Registration (if not found) feature but not configured the Create Record Type picklist.<br>Change it from N/A to the required type - remember that Person Accounts must be enabled to use Person Accounts as a creatable record type with this component. |
| Please specify an Account Id parameter when creating a Contact. | When creating a new Contact, you must specify an Account Id to link that Contact to for sharing & visibility purposes.<br>The contact can be manually updated later to a new Account if required. |
| Account Id parameter must be a Salesforce 15 or 18 character reference | The Id you’ve entered is not 15 or 18 characters and therefore not the expected length for a Salesforce Id so it is likely incorrect. Please check the value, or navigate to the Account and use the Id shown in the browser URL. |
| The Account Id parameter must start with 001 (Account Object Type). | The Id you’ve entered does not start with the characters 001 and therefore not the expected format for a Salesforce Account Id so it is likely incorrect. Please check the value, or navigate to the Account and use the Id shown in the browser URL. |
| Person Accounts are not enabled on this org. | Enable Person Accounts if they are a suitable solution for your Org but consider the implications carefully and what it means for your org. This feature cannot be turned off in Salesforce once enabled so proceed with care. See [here](https://help.salesforce.com/s/articleView?id=sf.account_person_enable.htm&language=en_US&type=5). |
| Please select a Person Account Record Type from the list to create a Person Account during registration. | You’ve selected to create a Person Account if a record is not found during registration, but you have not selected the appropriate Record Type from the list. Configure this additional parameter to proceed. |

During registration, most errors are hidden from the registering user where possible with the generic message to hide technical Salesforce issues which may confuse the user. The user should see “An unknown error has occurred, please contact us for further assistance.” The best course of action is to turn on the Create Log Entry for Registrations feature and monitor for issues (see above for more information).

You may also see the error: You do not have access to the Apex class named 'SiteRegistrationController'. - to resolve this issue, simply assign the “Custom Self Registration - Guest Access” Permission Set to the Guest User.

<u>**Other known errors:**</u>

Failed to create external user for portal. Error: [We encountered an unknown error while processing this request.]

* This error is generally returned from Salesforce when something about the site the component is running on is not configured correctly. Things to check:
  * The site must be Active and Published. 
  * It must have a Profile added in the Workspaces > Members. This member must be set in Login & Registration under profile.
  * Self Registration must be turned on in Workspaces > Login & Registration (see pre-requisites)

Error sending a verification code. Please try again later. Error: Unable to generate security token

* This usually happens if you have requested too many verification codes for the same mobile number/email address in a short space of time. Simply wait, and try again later.

The guest user does not have access to some fields. These fields will not be mapped to the Person Account/Contact

* To fix this, check that you have added the read/edit access to the "Custom Self Registration - Guest Access" for the fields listed. Permission Set and ensure that it is assigned to the site's guest user.

A new user's attempt to register at PORTAL_NAME failed because the value for the profileID attribute is either null or invalid. Set the profileID for new users on the ChatterAnswersRegistration Visualforce page for the site associated with experience PORTAL_NAME or on the apex class associated with the Facebook authentication provider.

* This is not related to the component as such. In Workspaces > Registration and Login settings, ensure that an ID is set for the Profile field. This is used for non-passwordless setups only. For passwordless, the Profile selected in the component is used.

The site is not enabled for registration

* Ensure that the 'allow customers and partners to self register' is set in Workspaces > Registration page configuration.

There was a problem executing the specific query in the Custom Query property. Query used: SELECT Id,PersonMobilePhone FROM Account WHERE PersonMobilePhone = : MobilePhone LIMIT 1. Error: Key 'MobilePhone' does not exist in the bindMap

* The message will differ depending on the field that the component did not find. Essentially the problem is that the field referenced in the parameter of the query e.g. “:MobilePhone” has not be found on the form. Ensure that the variable name is the same name as the field in the Custom Metadata records.
# Configurable Self Registration & Login LWC for Experience Cloud - Admin Installation & Setup Guide - Winter 27 (Managed Package v2.0)

**<u>Summary</u>**

This package includes 2 components - **SF Labs: Custom Self Registration** and **SF Labs: Custom Login**. It is designed for use in Experience Cloud sites where the out of the box components do not meet your business needs and configurability is required. The components can be used together to complement each other, or individually.

From v2.0, all behavioural settings (queries, redirects, error messages, passwordless options, logging) are stored on Custom Metadata Type records, not in Experience Builder. The components expose no property-panel settings. This keeps the custom query, Account Id, profile and record type hidden from the guest user making the component secure.

The components have been designed to accommodate the average Salesforce Administrator who wishes to simply install and configure with no code involved. You are only required to know a little bit about SOQL queries for the Custom Self Registration component, everything else is deliberately admin friendly! The components offer many configuration options which are described throughout this document and they may or may not fit your use cases exactly, but aims to fill the gaps and extend existing functionality to provide a more flexible solution.

Leave comments on your thoughts for improvements, or if you find bugs then raise an Issue via the [GitHub repository](https://github.com/SalesforceLabs/Configurable-Self-Registration-for-Experience-Cloud) so I can investigate and fix. I will aim to maintain the solution as much as possible as time allows. Please note that unfortunately LWC development is not my full time job and this was created in my spare time.

**<u>Prerequisites</u>**

The package install requires that your Salesforce Org has the following features enabled before installing the AppExchange package:

NetworksEnabledOnce: This refers to Experience Cloud and enabling the Digital Experiences feature from Setup > Digital Experiences > Settings. Enable the setting, and save then try the installation again.

![image9.png](/docs/images/image9.png)

The Custom Self Registration component requires that Self Registration is enabled on your site. Within your site > Workspaces > Administration > Login & Registration ensure that you enable the “Allow customers and partners to self-register” setting:

![2024-09-06_11-51-53.png](/docs/images/2024-09-06_11-51-53.png)

**<u>Installation</u>**

From the AppExchange, click Get it Now on the listing. Install in your organisation for Admin Users. Once the package has been installed on your org, two Lightning Web Components will become available to you within the Experience Cloud Builder under **Custom Components**:

* **SF Labs: Custom Login** (`customLoginCmdt`)
* **SF Labs: Custom Self Registration** (`customSelfRegistrationCmdt`)

![image6.png](/docs/images/image6.png)

Navigate to the Login or Register page, then drag and drop the relevant **SF Labs** component onto the canvas. There is nothing to configure in the Experience Builder property panel. Configure the component on Custom Metadata as described below, then publish the site.

> **IMPORTANT — Upgrading from v1.x**  
> Previous components remain in the package but are **deprecated and no longer functional**. They show a warning on the page and ignore any Experience Builder properties. You must remove them and add the new components, and you must copy any customised settings onto Custom Metadata before you do so. Settings do not migrate automatically.  
>  
> | Deprecated (do not use) | Replace with |  
> | :--- | :--- |  
> | `@deprecated - Custom Login - DO NOT USE THIS COMPONENT` (`customLoginCPE`) | **SF Labs: Custom Login** (`customLoginCmdt`) |  
> | `@deprecated - Custom Self Registration - DO NOT USE THIS COMPONENT` (`customSelfRegistrationCPropEditor`) | **SF Labs: Custom Self Registration** (`customSelfRegistrationCmdt`) |  
> | `@deprecated - DO NOT USE THIS COMPONENT` (`customSelfRegistrationCPE`) | **SF Labs: Custom Self Registration** (`customSelfRegistrationCmdt`) |

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

The Custom Self Registration component runs as the Guest User when accessing it via an Experience Cloud site. The component has been secured so that it runs in a ‘with sharing’ context, but executes queries, and other system methods as needed in a ‘without sharing’ context. Use the **Access Level Mode** field on the Self Registration Settings Custom Metadata record with care - System Mode ignores Field Level/Object Level to the Guest User to run the specified query. User mode will enforce Field Level/Object Level Access as per your org settings. Criteria Based Sharing Rules can be used to share any relevant Accounts, Contacts or Cases with the Guest User to open up further access if needed.

**<u>Custom Experience Cloud Setting records</u>**

Behavioural settings for both components live on the **Custom Experience Cloud Setting** Custom Metadata Type. Setup > Custom Metadata Types > Custom Experience Cloud Setting > Manage Records. Two records are included with the package:

| Record label | Developer name | Type | Used by |
| :--- | :--- | :--- | :--- |
| Login Settings | `Login_Settings` | Login | SF Labs: Custom Login |
| Self Registration Settings | `Self_Registration_Settings` | Self Registration | SF Labs: Custom Self Registration |

The **Type** field on the record is what the component uses to load settings. Keep one record with Type = Login and one with Type = Self Registration. Changes to these records take effect without republishing the site.

![image.png](/docs/images/image.png)

**<u>Self Registration Settings</u>**

Edit the **Self Registration Settings** record. Fields are grouped below to match the previous Experience Builder tabs.

* **Base Settings**
  * **Custom Query:** Write a custom SOQL query to find a matching Contact, Account (if using Person Accounts) or Case to relate a newly registered Portal User to (External User). See below for more information. This is required to use the Self Registration component.
  * **Access Level Mode:** Controls the access level for the query above. Change to ‘User’ if the query should run as the Guest User or ‘System’ to run the query with elevated access and see all data.
  * **Send Email Confirmation:** When the user successfully registers, an email notification is sent to the user from Salesforce. You may wish to turn this off if using another tool such as Marketing Cloud to send out registration emails. You could use the “Is Customer Portal” checkbox to trigger a journey into Marketing Cloud. If enabled, change the content of the email easily by navigating to the template set in Welcome New Member setting within Experience Cloud.
  * **Button Label:** This is the text shown on the button when the page loads and before the button is clicked.
  * **Button Waiting Message:** This is the text shown briefly on the button once the form is submitted and before the page redirects (if the registration was successful).
  * **Portal Redirect:** After registration, the user is redirected to this Portal page. The default is “/” which takes the user to the configured Home Page. This could be another page such as the default Case List View using “case/Case/Default”. If browser page URL includes a `startURL` (or `startUrl`) query parameter that is a relative path that value is used instead. For example, if you provide a link to a Knowledge article that requires login to view, Experience Cloud will redirect to the login page (which can use the SF Labs: Custom Login component). The component will redirect the user to the startURL after a successful login, or if startURL is not provided and this setting is configured, the component will redirect here instead.
* **Create New Record**
  * **Create Record If Not Found:** If a record is not found using the above custom query, then a new record can be created and related to the External User instead.
  * **Object Create Type:** If the above setting is set to TRUE, set whether the component should create a Contact or Person Account. Note that Person Accounts must be switched on and configured before you can use this functionality otherwise you will experience all kinds of weird behaviour!
  * **Account Id:** If the “**Object Create Type**” setting is set to Contacts, then set the Account Id of an existing Account to link a Contact to. This ensures that visibility can be enforced for any Contacts that have self registered.
  * **Person Account Record Type:** If the “**Object Create Type**” setting is set to Person Accounts, then set the Developer Name of the Person Account Record Type in your Org. Person Accounts must already be enabled in the org for this option to be configured successfully.
* **Error Handling**
  * **Password Match Error:** When registering, if the Password and Confirm Password fields do not match then this message is displayed.
  * **Username Taken Message:** If the username chosen when registering is already taken, then display this message.
  * **No Record Found Error:** If a record is not found based on the submitted details and the configured custom query then this message is displayed.
  * **Multiple Records Found Error:** If more than one record is found based on the submitted details and the configured custom query then this message is displayed.
  * **Portal Login Error:** If there is a problem logging into the portal after registration, then this message is displayed.
  * **Error On Create:** If there is a problem creating an external user, then this message is displayed.
  * **Portal Registration Error:** If there is a problem during registration, then this message is displayed.
  * **Portal Registration User Exists:** If the matched record from the Custom Query is already registered for the portal, then this message is displayed.
* **Passwordless Login**
  * **Enable Passwordless Login:** Set to TRUE to enable the passwordless login feature. Additional setup is required, please see the Setting Up Passwordless Registration & Login section for more details.
  * **Passwordless Method:** Select either ‘Email’ or ‘SMS’. NOTE: If you wish to use SMS as a verification method, then an add-on licence must be purchased. See [here](https://help.salesforce.com/s/articleView?language=en_US&id=sf.security_mfa_sms_for_external_users.htm&type=5) for more information.
  * **Passwordless Profile:** Set the profile that will be assigned when a new user registers using a passwordless verification method. Use a site ‘Members’ profile.
  * **Button Awaiting Code Message:** The default value is “Submit Verification Code”. This button label is shown when the form is awaiting the user to enter a code they have received via Email or SMS.
  * **Portal Error Send Verification Code:** If the form fails to send a verification code via the selected Passwordless Method, this message overrides the unhelpful system message shown to the user. To understand the full message and debug, look at the Experience Cloud Logs custom object.
  * **Failed Code Verification Message:** If the form fails to validate the verification code entered by the user, this message overrides the unhelpful system message shown to the user. To understand the full message and debug, look at the Experience Cloud Logs custom object.
* **Logging**
  * **Enable Logging:** Turn on to write login/self-registration activity to the Experience Cloud Log object. See “Create Log Entry for Self Registrations & Logins” below.

**<u>Login Settings</u>**

Edit the **Login Settings** record.

* **Button Label:** Set to Login by default, but can be changed.
* **Button Waiting Message:** Set to “Logging in… Please Wait.” by default. Can be overridden as required.
* **Portal Redirect:** The URL that the user is redirected to after a successful login. The default is the home page (“/”). If the page URL includes a `startURL` (or `startUrl`) query parameter that is a relative path or stays on the same Experience Cloud site, that value is used instead. Protocol-relative and external absolute URLs are rejected.
* **Block User Error Message:** If an admin uses the “Freeze” button on a user and they try to login, this message is displayed.
* **Incorrect User Credentials Error:** If the user tries to login with incorrect credentials, or the account details they used are not recognised then this message is displayed.
* **User Locked Out Error Message:** If the user tries to login with incorrect credentials more than the profile’s specified password policy then they are temporarily locked out. When this is the case, this error message is displayed.
* **Enable Passwordless Login / Passwordless Method / Button Awaiting Code Message / Portal Error Send Verification Code / Failed Code Verification Message:** Same meaning as on Self Registration Settings. See the Setting Up Passwordless Registration & Login section.
* **Enable Logging:** Turn on to write login activity to the Experience Cloud Log object.

**<u>Basic Setup - Self Registration</u>**

When the package is first installed, the **Custom Query** field on the Self Registration Settings record is populated with a sample Person Account query. You must review and set this for your org before using the component. You can write your own SOQL query to identify an existing Contact, Person Account or Case during registration to link the registration to, if a record is not found then you could later decide to create a record. Updates are not supported to an existing record.

The query can be dynamic and supports values submitted on the registration form. For example, you can use the submitted email address of the user registering to find a Contact, Person Account or Case in Salesforce. To do this, include one of the following bind variables in your query:

* :FirstName
* :LastName
* :Username
* :Email

The query must return exactly 1 record to ensure a unique match. If the query finds more than 1 result, then the component will error during registration with the value set in **Multiple Records Found Error** on the Self Registration Settings record and the site visitor will be unable to register to your Experience Cloud portal. Due to this, use LIMIT 1 within your chosen query as per the examples. If more than one record is found, only the first one found is used, ignoring any others. 

> **Important**  
> *Do not use spaces between field names for the SELECT part of the SOQL statement otherwise the component will not validate the query correctly.*  
> *AccountId is a required field when querying the Contact object. If you omit the field from the Custom Query on the Self Registration Settings record, the Custom Self Registration component will error.*

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

The default behaviour of the component at this point is to display a message to the user as configured in the **No Record Found Error** field if your query returns no results, or if there is more than 1 result, then the **Multiple Records Found Error** field is shown instead.

The Custom Query can be run in User, or System Mode which affects the results that are found. Change the **Access Level Mode** field on the Self Registration Settings record accordingly. The registration form runs as a Guest User, and thus so does your Custom Query so you ***MUST*** carefully consider which option you wish to use based on the security measures enforced by your org.

<u>**Create Record If Not Found**</u>

This option does exactly what it says on the tin! If your Custom Query does not find a record and this mode is enabled, then a new record is created. This setting works in tandem with the **Object Create Type** field where you can choose to create a Contact linked to a pre-existing Account, or a Person Account (if your org is configured to support Person Accounts).

Turn this setting on by ticking **Create Record If Not Found**, then choose the appropriate object type to create.

If creating a Contact, ensure you have an Account to attach any new registrations to which will enforce any security settings configured in your org. Without setting an Account Id, the Contact remains private and may not be visible to your users - see [here](https://help.salesforce.com/s/articleView?id=sf.contacts_private.htm&type=5). Navigate to an Account, copy the Id from the browser URL bar (starting 001) into the **Account Id** field on the Self Registration Settings record.

![image4.png](/docs/images/image4.png)

If creating a Person Account, set **Person Account Record Type** to the Developer Name of the appropriate Person Account record type. You do not need to set the Account Id field for this object type.

**Send Email Confirmation**

When **Send Email Confirmation** is enabled on the Self Registration Settings record, the component sends an email from Salesforce upon successful registration using the Welcome Email template configured in Workspaces.

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
> *Whilst the component will let you hide all fields, some are required for a successful registration. This varies depending on the configuration settings on the Self Registration Settings record.*

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

The Custom Login component is configured in the same way as Custom Self Registration: there are no Experience Builder properties. Edit the **Login Settings** Custom Experience Cloud Setting record for button labels, redirect, error messages, passwordless options and logging.

From there, fields that are shown are controlled by the Custom Metadata Type called **Custom Login Configuration**. The same attributes are available for the login form fields as they are for the self registration component, most are ignored by login so check the settings carefully.

Login does not map submitted values to Contact, Account or User records. Extra custom fields you add will appear on the form if they are Active, but Apex ignores them unless the **Field API Name** is one of the names below.

**Field API Names used by login**

| Field API Name | Packaged record | When it is used |
| :--- | :--- | :--- |
| `Email` or `Username` | Email | Password login and passwordless Email. If both are present, Username is used first, otherwise Email. |
| `password` | Password | Password login only. Hide this record when using passwordless login. |
| `countryCode` | Country Code | Passwordless SMS. Use Field Type `picklist` and Field Picklist Options for the country list. |
| `MobilePhone` | MobilePhone | Passwordless SMS, together with Country Code. Inactive by default; set Active when using SMS. |
| `identifier` | Identifier | Always keep Active and hidden (`slds-hide`). Used to hold the verification Id after a code is sent. |
| `verificationCode` | Verification Code | Shown after a verification code is sent (passwordless). Starts hidden via `slds-hide` on Field Class. |

**Custom Login Configuration attributes that login uses** (per field record):

* **Active** and **Portal API Name** — whether the field is included for this site (`ALL` or the Site API Name).
* **Display Order** — order of fields on the form.
* **Field API Name** — must match a name in the table above for the value to be used at login.
* **Field Label**, **Field Type**, **Field Label Variant**, **Field Help Text**, **Field Placeholder** — how the input is shown.
* **Field Class** — CSS on the input. Use `slds-hide` to hide Identifier and Verification Code until needed. Do not remove `verificationCode` from the Verification Code record.
* **Field Parent Class**, **Field Show Icon**, **Field Icon Name**, **Field Icon Class**, **Field Toggle Type**, **Field Toggle Icon Name** — icons and password show/hide. See Configuring CSS for Icons.
* **Field Allow Auto Complete**
* **Field Required** and **Field Required Message**
* **Field Validation REGEX** and **Field REGEX Message**
* **Field Min Characters**, **Field Message Too Short**, **Field Max Characters**, **Field Message Too Long**
* **Field Picklist Options** — Country Code (and any other picklist you add)

**Ignored by login** (safe to leave blank): **Field Date Style**, **Minimum Value**, **Maximum Value**, **Field Under Minimum Range Message**, **Field Over Max Range Message**. These exist because the metadata type is shared with Self Registration. They are not used to create or update records on login.

<u>**Setting Up Passwordless Self Registration & Login**</u>

The journey to enable Passwordless features for these components begins with a portal user self registering for the portal. After they have registered with either an Email or Password, then they can login using that method going forwards. The user will receive a verification code to the email or as an SMS to the mobile phone number they provide.

> NOTE: The components can be configured to support ***either*** email OR mobile verification for the initial Self Registration. The user cannot self register again for a 2nd device. They need to do this once authenticated.

**<u>Custom Self Registration - Custom Metadata</u>**

The component should be configured in the following way to turn the feature on:

On the **Self Registration Settings** record, set **Enable Passwordless Login** to TRUE, choose **Passwordless Method** (Email or SMS), and set **Passwordless Profile** to a site Members profile.

In Custom Metadata Types > Custom Registration Configuration, turn on the following fields:

* Country Code (only when verification method = SMS)
* Mobile Phone (only when verification method = SMS)
* Email (only when verification method = Email)
* Verification Code
* Identifier

It is not a necessarily a requirement, but it is best to turn off all other fields. The recommendation is for the form to show only show the country code & mobile OR email fields. The verification code is shown only once the user fills out their contact details and clicks sign up. The identifier field is always hidden from view and is a system field required to make the passwordless functionality work. 

The premise of passwordless is to streamline the approach as much as possible and therefore capture minimal data at sign up. Whilst it can be done here, this data can always be captured later via a profile page, or login flow depending on the requirements.

**<u>Custom Self Registration - Self Registration Settings</u>**

On the Self Registration Settings record, set or review the following fields:

* **Enable Passwordless Login:** Set to TRUE to enable the passwordless login feature. 
* **Passwordless Method:** Select either ‘Email’ or ‘SMS’. NOTE: If you wish to use SMS as a verification method, then an add-on licence must be purchased. If you do not have the appropriate licence, then you will not see SMS as a usable option. See [here](https://help.salesforce.com/s/articleView?language=en_US&id=sf.security_mfa_sms_for_external_users.htm&type=5) for more information.
* **Passwordless Profile:** Set the profile that will be assigned when a new user registers using a passwordless verification method. Use a site ‘Members’ profile.
* **Button Awaiting Code Message:** The default value is “Submit Verification Code”, however it can be overridden as required. This button label is shown to the user when they try to register, and the form is awaiting the user to enter a code they have received via Email or SMS.
* **Portal Error Send Verification Code:** If the form fails to send a verification code via the selected Passwordless Method, this message overrides the unhelpful system message shown to the user. Use the default, or change as required.
* **Failed Code Verification Message:** If the form fails to validate the verification code entered by the user, this message overrides the unhelpful system message shown to the user. Use the default, or change as required.

> **NOTE:** *Custom Metadata changes take effect without republishing. You still need to publish the site after adding or replacing the LWC on the page for the first time.*

**<u>Custom Login - Custom Metadata</u>**

Once a user has registered using the Self Registration component, they can then login with that device going forwards as long as the Custom Login component is configured appropriately. The configuration is much the same as the Custom Self Registration setup. In Custom Metadata Type > Custom Login Configuration, ensure that the following fields are enabled:

* Country Code (only when verification method = SMS)
* Mobile Phone (only when verification method = SMS)
* Email (only when verification method = Email)
* Verification Code
* Identifier

**<u>Custom Login - Login Settings</u>**

Similar fields are available on the Login Settings record. Review the following:

* **Enable Passwordless Login:** Set to TRUE to enable the passwordless login feature. 
* **Passwordless Method:** Select either ‘Email’ or ‘SMS’. NOTE: If you wish to use SMS as a verification method, then an add-on licence must be purchased. If you do not have the appropriate licence, then you will not see SMS as a usable option. See [here](https://help.salesforce.com/s/articleView?language=en_US&id=sf.security_mfa_sms_for_external_users.htm&type=5) for more information.
* **Button Awaiting Code Message:** The default value is “Submit Verification Code”, however it can be overridden as required. This button label is shown when the form is awaiting the user to enter a code they have received via Email or SMS.
* **Portal Error Send Verification Code:** If the form fails to send a verification code via the selected Passwordless Method, this message overrides the unhelpful system message shown to the user. Use the default, or change as required.
* **Failed Code Verification Message:** If the form fails to validate the verification code entered by the user, this message overrides the unhelpful system message shown to the user. Use the default, or change as required.

> **NOTE:** *Custom Metadata changes take effect without republishing. You still need to publish the site after adding or replacing the LWC on the page.*

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

Similar to the Self Registration component, the Username and Password fields can also have icons. These settings are applied on **Custom Login Configuration** records (Field Parent Class, Field Icon Class, Field Icon Name, Field Toggle Icon Name), not in Experience Builder.

| Label Variant | Desired Icon Position | Field Parent Class | Icon Class |
| :--- | :--- | :--- | :--- |
| Standard | Left | slds-input-has-icon_left | input-icon-label-shown-left |
| Standard | Right | slds-input-has-icon_right | input-icon-label-shown-right |
| Inline | Left | slds-input-has-icon_left | input-icon-label-inline-left |
| Inline | Right | slds-input-has-icon_right | input-icon-label-inline-right |
| Hidden | Left | slds-input-has-icon_left | Input-icon-label-hidden-left |
| Hidden | Right | slds-input-has-icon_right | input-icon-label-hidden-right |

For the Password Field, there can be two possible icons which show or hide the password value typed. Use **Field Icon Name** (show) and **Field Toggle Icon Name** (hide) on the Password Custom Login Configuration record.

As per the Self Registration component, the **Field Parent Class** is needed to add padding around the field’s icon to stop typed text overlaying the icon.

In addition to the Icon Class, you can use the class “top” for the Hidden variants above to place padding between each of the fields when no label is displayed.

Further styling can be configured via the Experience Builder CSS Override feature. However, this document does not cover that in detail. Refer to the Salesforce help for more information.

<u>**Create Log Entry for Self Registrations & Logins**</u>

Logging is controlled by the **Enable Logging** checkbox on the **Login Settings** and **Self Registration Settings** Custom Experience Cloud Setting records. Turn it on for the component you want to trace. The packaged records have logging enabled; turn it off if you do not need a log for every attempt.

![image2.png](/docs/images/image2.png)

This setting creates noisy logging for each registration / login and thus it is not recommended to leave this on continuously in production. This setting is particularly useful when first configuring the components as it gives you a detailed trail of what happened without having to navigate complex Debug Logs.

A single log record is created at the end of processing the Self Registration form submission with details of:

* Validating Username - is the chosen name available or taken
* Validating Password - was it valid and met the SF org requirements
* Actual registration i.e. locating a record, creating a new record, creating an external user etc.
* Confirmation of sending/verifying a validation code (NOTE: Sending/Verification creates 2 separate records as it requires a 2nd form submit)

For Login, the record logs a success or failure message using the text configured on the Login Settings record for the scenario encountered e.g. if the user is blocked the message will say “There was a problem logging {username} into the portal.” Followed by the message “Your account has been temporarily disabled. Please contact us for assistance.” assuming the default has not been changed.

There are two Log Types used - Error and Information. The Component Name is also stored (Login or Self Registration). Each log also has an **Outcome** picklist so you can report on *why* the attempt succeeded or failed (for example Login Success, Invalid Password, Password Lockout, No Record Found, Registration Success). Use the Message field to understand the steps completed.

![image5.png](/docs/images/image5.png)

Experience Cloud Log records are created via a Platform Event (Experience Cloud Event) & Flow subscription and are accessible to System Admins by default. Configure another Permission Set as required to give other users access.

**<u>Experience Cloud Logging dashboard and reports</u>**

The **Experience Cloud Logging** dashboard is installed with the package and is available from the Experience Cloud Logging app (also embedded on the app home page) or from the Dashboards tab. It is rebuilt around the Outcome field so you can see volume, success vs failure, and the specific reason for failures.

![image8.png](/docs/images/image8.png)

**Dashboard widgets**

* **Successful Logins (Last 30 Days)** — Login component, outcome Login Success or Verification Success.
* **Failed Logins (Last 30 Days)** — Login component, log type Error, grouped by day and outcome.
* **Successful Self-Reg (Last 30 Days)** — Self Registration component, outcome Registration Success or Verification Success.
* **Failed Self-Reg (Last 30 Days)** — Self Registration component, log type Error, grouped by day and outcome.
* **Error vs Information by Day** — stacked column of log type by day (last 30 days).
* **Errors by Component** — donut of Error logs split between Login and Self Registration.
* **Outcomes (Last 30 Days)** — bar chart grouped by Outcome, then component. This is the main view for *why* attempts succeeded or failed.
* **Login Mix (Last 30 Days)** — donut of Login logs split by Error vs Information.
* **Repeat Login Failures** — Login Error logs that have a User Id, showing users who fail repeatedly and the outcome.
* **Recent Errors (Last 7 Days)** — table of the 10 newest Error logs (created date, component, outcome, message).

**Reports in the Experience Cloud Logging folder that are not on the dashboard**

* **Self-Reg Outcomes (Last 30 Days)** — outcome grouping for Self Registration only.
* **Logs by Type & Component (Last 30 Days)** — matrix of component vs Error/Information.
* **Missing Related Records (Last 30 Days)** — logs with no User, Account, or Contact. Useful for failed registrations that never created a person, or logins that never resolved a user.

Outcome values include: Login Success, Login Failed, Registration Success, Username Exists, Username Not Found, Invalid Password, User Frozen, Password Lockout, Password Validation Failed, Record Create Failed, User Create Failed, Record Delete Failed, Query Error, Configuration Error, No Record Found, Multiple Records Found, Verification Sent, Verification Send Failed, Verification Failed, Verification Success.

**Expected Errors:**

The following errors are shown when the Self Registration Settings record is misconfigured and are expected behaviour. The table below summarises the known errors:

| Error | Description |
| :--- | :--- |
| A Custom Query is required to use this component. | The Custom Query field on the Self Registration Settings record is blank. Enter a SOQL query that returns Contact, Account or Case. |
| Only Contact, Account or Case objects are supported with a Custom Query on this component. | If you try to query other object types, you will see this message. Update Custom Query to query Contacts, Accounts or Cases. |
| Person Accounts are not enabled on this org so you cannot use Accounts in a Custom Query. | If your Custom Query uses the Account object and Person Accounts are not configured in your org. Either use Contacts, or configure Person Accounts before using this component. |
| Object Create Type must be set when Create Record If Not Found is enabled. | You’ve enabled Create Record If Not Found but not set Object Create Type. Set it to Contact or Person Account - remember that Person Accounts must be enabled to use Person Accounts as a creatable record type with this component. |
| Please specify an Account Id on the Self Registration settings record when creating a Contact. | When creating a new Contact, you must specify an Account Id to link that Contact to for sharing & visibility purposes. The contact can be manually updated later to a new Account if required. |
| Account Id must be a Salesforce 15 or 18 character reference. | The Id you’ve entered is not 15 or 18 characters and therefore not the expected length for a Salesforce Id so it is likely incorrect. Please check the value, or navigate to the Account and use the Id shown in the browser URL. |
| Account Id must start with 001 (Account Object Type). | The Id you’ve entered does not start with the characters 001 and therefore not the expected format for a Salesforce Account Id so it is likely incorrect. Please check the value, or navigate to the Account and use the Id shown in the browser URL. |
| Person Accounts are not enabled on this org. | Enable Person Accounts if they are a suitable solution for your Org but consider the implications carefully and what it means for your org. This feature cannot be turned off in Salesforce once enabled so proceed with care. See [here](https://help.salesforce.com/s/articleView?id=sf.account_person_enable.htm&language=en_US&type=5). |
| Please set a Person Account Record Type to create a Person Account during registration. | You’ve selected to create a Person Account if a record is not found during registration, but you have not set Person Account Record Type on the Self Registration Settings record. Set the record type Developer Name to proceed. |

During registration, most errors are hidden from the registering user where possible with the generic message to hide technical Salesforce issues which may confuse the user. The user should see “An unknown error has occurred, please contact us for further assistance.” The best course of action is to turn on **Enable Logging** on the Self Registration Settings record and monitor for issues (see above for more information).

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

* This is not related to the component as such. In Workspaces > Registration and Login settings, ensure that an ID is set for the Profile field. This is used for non-passwordless setups only. For passwordless, the **Passwordless Profile** field on the Self Registration Settings record is used.

The site is not enabled for registration

* Ensure that the 'allow customers and partners to self register' is set in Workspaces > Registration page configuration.

There was a problem executing the specific query in the Custom Query. Query used: SELECT Id,PersonMobilePhone FROM Account WHERE PersonMobilePhone = : MobilePhone LIMIT 1. Error: Key 'MobilePhone' does not exist in the bindMap

* The message will differ depending on the field that the component did not find. Essentially the problem is that the field referenced as a bind variable in the query e.g. “:MobilePhone” has not been found on the form. Ensure that the variable name is the same as the Field API Name on the Custom Registration Configuration records.
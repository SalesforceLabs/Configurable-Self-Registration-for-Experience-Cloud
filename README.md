# Configurable Self Registration/Login for Experience Cloud

Clone this repository and deploy it to your org as an unmanaged package to make your own changes. Alternatively, install the latest released version from the App Exchange listing: https://appexchange.salesforce.com/appxListingDetail?listingId=c06efea1-214d-4dda-b87b-3e7186319593.

User Guide is available under the "docs" folder. See "INSTALLATION_GUIDE.md"

Release notes for v2.0 are below. Older versions are in [docs/PREVIOUS_RELEASE_NOTES.md](docs/PREVIOUS_RELEASE_NOTES.md). Latest version is v2.0 - Winter 27 Release.

#NOTES:

If deploying from the repository as an unmanaged package, ensure that the user you are running the deployment as has a role assigned to them on their User record otherwise Apex Tests will fail with "portal owner must have a role".

With the current unmanaged version, Apex tests fail if Person Accounts are not enabled in your org. The component will still support both Business Accounts/Contacts and Person Accounts, but tests will need to be amended depending on your org configuration.

---

# RELEASE CHANGES - v2.0 - Winter 27 Release

This is a breaking setup change for existing sites. Login and self-registration configuration has moved out of Experience Builder and onto Custom Metadata so that sensitive settings are never exposed to the guest user in the browser.

## Deprecated components — you must switch and reconfigure

After install or upgrade, the previous Experience Builder components stay on the page but **do not run**. They only show a deprecation notice. Builder properties on those components are **ignored**. Login and registration will not work until you replace them and copy any customised settings onto Custom Metadata.

| Deprecated component (API name) | Experience Builder label | Replace with (API name) | New Builder label |
| :--- | :--- | :--- | :--- |
| `customLoginCPE` | @deprecated - Custom Login - DO NOT USE THIS COMPONENT | `customLoginCmdt` | **SF Labs: Custom Login** |
| `customSelfRegistrationCPropEditor` | @deprecated - Custom Self Registration - DO NOT USE THIS COMPONENT | `customSelfRegistrationCmdt` | **SF Labs: Custom Self Registration** |
| `customSelfRegistrationCPE` | @deprecated - DO NOT USE THIS COMPONENT | `customSelfRegistrationCmdt` | **SF Labs: Custom Self Registration** |

`customSelfRegistrationCPE` is the older v1.86-era bundle. It is kept in the managed package so upgrades do not break; it is replaced by the same new Self Registration component.

The deprecated bundles cannot be removed from a managed package, so they remain as inert stubs. Their Experience Builder properties are retained only for package compatibility.

**Why this is required:**

1. **The old components are inert.** Leaving them on Login or Register pages means users see a warning instead of a working form. There is no fallback to the previous Builder-driven behaviour.
2. **Builder settings do not carry over.** Labels, error messages, redirects, passwordless options, custom query, access level, create-if-not-found, Account Id, record type, and similar values used to live on the component in Experience Builder. Those values are no longer read. Copy anything you customised onto Custom Metadata **before** you remove the old components.
3. **Configuration is server-side on purpose.** The new components expose **no** Experience Builder properties. Apex loads the full Custom Experience Cloud Setting record. The browser only receives display strings (button labels, waiting messages, password-match error). Custom query, Account Id, profile, and record type are never sent to the guest user.

**Reconfiguration is two steps:**

1. In Setup, edit the **Login Settings** and **Self Registration Settings** Custom Experience Cloud Setting records (and Custom Login Configuration / Custom Registration Configuration field records if you customised the form).
2. In Experience Builder, remove the deprecated component from the Login and/or Register page, add **SF Labs: Custom Login** or **SF Labs: Custom Self Registration**, and publish. There is nothing to set in the property panel.

If you only install the package and do not swap the components, existing sites keep the deprecated bundles and login/registration stop working. If you swap the components but do not copy settings into Custom Metadata, you get the packaged defaults (including the sample Person Account query on Self Registration Settings), not your previous Builder configuration.

## Custom Experience Cloud Setting records

| Record label | Developer name | Type | Used by |
| :--- | :--- | :--- | :--- |
| Login Settings | `Login_Settings` | Login | SF Labs: Custom Login |
| Self Registration Settings | `Self_Registration_Settings` | Self Registration | SF Labs: Custom Self Registration |

Form fields continue to be defined on **Custom Login Configuration** and **Custom Registration Configuration**.

## Logging outcomes and dashboard

Experience Cloud Log and Experience Cloud Event now include an **Outcome** picklist so reports can show *why* a login or registration succeeded or failed, not only Error vs Information.

Outcome values include: Login Success, Login Failed, Registration Success, Username Exists, Username Not Found, Invalid Password, User Frozen, Password Lockout, Password Validation Failed, Record Create Failed, User Create Failed, Record Delete Failed, Query Error, Configuration Error, No Record Found, Multiple Records Found, Verification Sent, Verification Send Failed, Verification Failed, Verification Success.

The **Experience Cloud Logging** dashboard has been rebuilt around this field. New reports (mostly last 30 days):

**Dashboard widgets**

* Successful Logins / Failed Logins / Successful Self-Reg / Failed Self-Reg (metric tiles)
* Error vs Information by Day (stacked column)
* Errors by Component (donut)
* Outcomes (Last 30 Days) (bar chart by outcome)
* Login Mix (Last 30 Days) (donut of Error vs Information for Login)
* Repeat Login Failures (top users with a User Id on Login errors)
* Recent Errors (table of the 10 newest Error logs, last 7 days)

**Reports in the folder, not on the dashboard**

* Self-Reg Outcomes (Last 30 Days)
* Logs by Type & Component (Last 30 Days)
* Missing Related Records (Last 30 Days) — logs with no User, Account, or Contact

Enable Logging is now the **Enable Logging** checkbox on the Login Settings and Self Registration Settings records (the previous separate logging-only Custom Experience Cloud Setting records are no longer used).

## Other changes

* After login (and after registration login), a safe Experience Cloud `startURL` query parameter is honoured when it is a relative path or stays on the same site. Otherwise the **Portal Redirect** value on the settings record is used.
* The installation and setup guide is now in the repository at `docs/INSTALLATION_GUIDE.md`.

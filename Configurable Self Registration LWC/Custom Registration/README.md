# Configurable Self Registration/Login for Experience Cloud

Clone this repository and deploy it to your org as an unmanaged package to make your own changes. Alternatively, install the latest released version from the App Exchange listing: https://appexchange.salesforce.com/appxListingDetail?listingId=c06efea1-214d-4dda-b87b-3e7186319593.

User Guide is available here: https://salesforce.quip.com/M0o9AYupf991

Release notes are available here: https://salesforce.quip.com/Af8CAQSB5eEA

#NOTES:

If deploying from the repository as an unmanaged package, ensure that the user you are running the deployment as has a role assigned to them on their User record otherwise Apex Tests will fail with "portal owner must have a role".

With the current unmanaged version, tests fail if Person Accounts are not enabled in your org. See open issues.

# to develop this package a dev org needs the following enabled

1. enable digital experiences
1. enable person accounts
1. assign your user a role (if you want to run the tests, which you do )
1. # assign yourself the pernmission sets from the package (if you want to run tests, which you do)

# Location-Aware
The set of scripts is designed to export modify and import locations into the config policy used to manage locationawareness configurations

To use unzip and run dmscript install.txt
It will create a directory cat sdroot\..\CA_FDU\LocationAware  There you will see a get and save dms script.  Edit the two scripts with the proper sql credentials for your implementation.
-----------------------------------------------------------------------------



To use it unzip the contents to a directory 
From a command prompt run dmscript "<directory of the unzipped files\InstallLocAware.txt"

It will create if it does not exist a directory ,CA_FDU\LocationAware at %sdroot%\..\

That is where all the files you need will be

Edit the 2 dms scripts with the proper mssql credentials.  If you are using the default instance with the mdb on the DM or EM and you have the default ca_itrm password no changes are required

This new version can read and modify configuration policies other than default.

To use the new scripts 
Run dmscript "%sdroot%\..\CA_FDU\LocationAware\GetLocationAwareTable.dms" <optional policy name>.  The policy must exist.  If you do not enter the policy name you will be prompted later.  If you enter an invalid policy name you will be notified and prompted to enter the correct one.

Logging is in the same directory

The output file you need is locations.csv

Edit it and save it with the same name in the same location

To import it run dmscript "%sdroot%\..\CA_FDU\LocationAware\updateLocationAwareTable.dms" <optional policy name>.  This can be the same policy it was exported from, it can be a different policy on the same domain or em or it can be on a different domain.  The only requirement is a policy with tha the name you specify must already exist.  It does not need to be populated in advance.

However the policy you import into must be sealed before running the script.

There are hard coded limits but they can be changed.  There can only be 1000 polices and a maximum of 1000 locations
To increase the number of policies on the first line of both DMS scripts you will see PolName[1000].  Make the number bigger
To increase the number of locations on the first line of both scrips there are 6 variables with [1000].  Change them all to the number you need.

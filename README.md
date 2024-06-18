# Documentation for using Installomator in WorkspaceONE UEM


<img src="images/workspaceone-logo.png">

Table of contents:
- [Documentation for using Installomator in WorkspaceONE UEM](#documentation-for-using-installomator-in-workspaceone-uem)
  - [Introduction](#introduction)
  - [Building Block : install Installomator](#building-block--install-installomator)
  - [Choice : use Script or App?](#choice--use-script-or-app)
    - [Scripts](#scripts)
    - [Internal App](#internal-app)
  - [create payload-free pkg](#create-payload-free-pkg)
  - [Versioning system](#versioning-system)
  - [Updating using Installomator](#updating-using-installomator)
  - [Requirements](#requirements)
  - [Links](#links)


## Introduction
WorkspaceONE UEM (in short WSO) has in some regards a different approach to install and update software than other MDM's.
Main points which effect the use of Installomator are:
-WSO cannot handle large scripts (i.e. Installomator), so you need to install Installomator locally.
-Patch management for 'internal' apps is based on version previous installations from UEM. (Not on version found on the Mac)

This means that if you install apps with Installomator, you have to manage your app's updates with a custom solution (which can be Installomator based :-)

## Building Block : install Installomator
Because we have to get Installomator on the Mac, the easiest solution is to use the ready made .pkg from Installomator project, and distribute that to all Mac's as a 'bootstrap package'. Advantage: this gets installed first during enrollment.
*In our org we deploy Installomator as bootstrap pkg, but since our org prefers local language, we distribute an updated version of Installomator with some translations and different defaults as a sub-version i.e. 10.5.3*

Since Installomator is installed locally, all we need to run on the clients is a short script like this:

```
#!/bin/zsh
/usr/local/Installomator/Installomator.sh adobecreativeclouddesktop
exit 0
```

*(you can get wild with options, we leave that up to you)*
How can we present this script to the user or make WSO run this script?

## Choice : use Script or App?

To make icons available in the Hub for Self-Service you can add a **script** or an **internal App** to the Hub. We will show both options.

### Scripts
Scripts can be run at specific moments, or on-demand from the Hub, with icon, description.
If you add a script to the Hub for self-service, the button is 'Run/Rerun'


Example in WSO:
**Add** a script for macOS :

Choose a name, Description and enable App Catalog Customisation, add logo similar to this:
<img src="images/script-iTerm-1.png">
Click **Next**

Choose Languare **Zsh**, execution context and timeout (the default 30 seconds is short) and copy the script (example [install-iTerm.sh](wso_scripts/install-iTerm.sh)) similar to this:
<img src="images/script-iTerm-2.png">
Click **Next**

There is no need to use variables, so 
<img src="images/script-iTerm-3.png">
Click **Save**

**Re-select** the script to create assignment:
<img src="images/Scripts-Install-or-update-iterm.png">
Click **Assign**

Choose a descriptive name, and the correct smart groups similar to this:
<img src="images/assign-iTerm-1.png">
Click **Next**

Choose **NO** triggers, but  **enable** Show in Hub (optional)
<img src="images/assign-iTerm-2.png">
Click **Add**

Done!

Go to a client to confirm this script is available in the Hub:
Open Intelligent Hub, and search for your *app-name*
<img src="images/hub-app-1.png">
Notice the title, icon and 'Run' button

If you click on the icon you can see the detailed view:
<img src="images/hub-app-2.png">
If you click 'Run' you may see a temporary dialog 'Installing ...your_title...' as this:
<img src="images/hub-app-3.png">
The app should be installed soon in /Applications/

Note: if you have run the script once, the button changes to 'Rerun'
<img src="images/hub-app-rerun.png">

other text ![Rerun](images/hub-app-rerun.png)



You can troubleshoot in the WSO by searching for the MacBook, and in the **scripts** section you will see the script with a status and last execution time:
<img src="images/UEM-log-1.png">
view the detailed logs by clicking on the **View** link below Log
<img src="images/UEM-log-2.png">
The logs are shown as one line.

You can troubleshoot locally by inspecting at the Installomator log at `/private/var/log/Installomator.log`


### Internal App
WSO can run several scripts for any internal (munki-style) software.
We decided to run a short script as per-install for an payload-free package.
Therefor our org decided to implement Installomator as an pre-install for a payload-free app to give the user a similar GUI experience, regardless the method used to install an app.


The main technology to install/update 'internal' apps (i.e. not the App store app's) is based on an integrated munki client. 

This integrated munki client requires the admin to upload the source (.dmg or .pkg) and a .plist file with metadata generated by the Workspace ONE Admin Assistant. 
If you want to use WSO for updating apps, remember that WSO will use it's own logs of installation commands to decide it WSO will update an App or not. NOT the actually installed version.
Example: You have a .pkg for Google Chrome v103, and installed that on a client. Using installomator (or the  Chrome updater) that app is updated to v114. If one would 'update' the Chrome pkg in WSO with v113, WSO will install v113 on the client, because it is an update to v103 previously installed. In reality this is a downgrade from v114 to v113.
Hence my recommendation to use a different versioning system for the dummy app.
* one
* two


## create payload-free pkg
We use munkipkg for this.
Basically you need to do these 3 steps:
1 create a new project with Munkipkg:

```
% ./munkipkg.py --create ..path/to../iTerm
```
2 Edit the info.plist and set the **identifier** to my.org.iTerm, and **version** to the current date (i.e. 24.06.18)
    example: 

 ```
    <?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>distribution_style</key>
	<false/>
	<key>identifier</key>
	<string>my.org.iTerm</string>
	<key>install_location</key>
	<string>/</string>
	<key>name</key>
	<string>iTerm-${version}.pkg</string>
	<key>ownership</key>
	<string>recommended</string>
	<key>postinstall_action</key>
	<string>none</string>
	<key>preserve_xattr</key>
	<false/>
	<key>suppress_bundle_relocation</key>
	<true/>
	<key>version</key>
	<string>24.06.18</string>
</dict>
</plist>
```
3 create a pkg with munkipkg:
   ``` 
   % ./munkipkg.py  ..path/to../iTerm
pkgbuild: Inferring bundle components from contents of ..path/to../iTerm/payload
pkgbuild: Writing new component property list to /var/folders/h9/5_fhws_n69504y0p2_yk1tf40000gr/T/tmp2iv56q4f/component.plist
pkgbuild: Reading components from /var/folders/h9/5_fhws_n69504y0p2_yk1tf40000gr/T/tmp2iv56q4f/component.plist
pkgbuild: Wrote package to ..path/to../iTerm/build/iTerm-24.06.18.pkg
```

4 Prepare this pkg for WSO with the WorkspaceONE Admin Assistant.
## Versioning system
We choose the version of the payload-free app to use the date, like 24.06.14. Usually this never is updated. Remember, if one edits the pre-install script, new installs will use this new pre-install script, while the 'app' version is the same.

## Updating using Installomator
Technically any installomator command will install or update the exisiting app. If you want user to initiate the updates, you can name the payload-free package 'Install or update App'. However, users will NOT get notified to install updates, since the version of payload-free app is not new.
Therefor we created a custom script that loops through a list of apps, and if an app of this list is installed, it will be updated with Installomator, similar in idea to App Auto-Patch.


## Requirements
* macOS 13 or higher
* WorkspaceONE UEM ??

## Links
Omnissa / VMware :
* [Introduction to VMware Workspace ONE Admin Assistant for macOS](https://docs.omnissa.com/bundle/Admin-AssistantVSaaS/page/AdminAssistantIntro.html)
* [macOS Device Enrollment - bootstrap package](https://docs.omnissa.com/nl-NL/bundle/macOS-Device-ManagementVSaaS/page/EnrollmentOverview.html#bootstrap_package_creation)

robjschroeder:  
* [App Auto-Patch (2.9.3) via swiftDialog (2.4.0)](https://techitout.xyz/2024/02/18/app-auto-patch-2-9-3-via-swiftdialog-2-4-0/)

Elliot Jordan 
* [YOU MIGHT LIKE MUNKIPKG](https://www.elliotjordan.com/posts/munkipkg-01-intro/)
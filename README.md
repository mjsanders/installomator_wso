# Documentation for using Installomator in WorkspaceONE UEM


<img src="images/Privileges_icon_unlocked.png" width="800">

test plaatje

![Privileges_icon_unlocked](images/Privileges_icon_unlocked.png)

yes
- [Introduction](#introduction)
- [Requirements](#requirements)

## Introduction
- The Support app is a macOS menu bar app built for organizations to:
* Help users and helpdesks to see basic diagnostic information at a glance and proactively notify them to easily fix small issues.
* Offer shortcuts to easily access support channels or other company resources such as a website or a file server
* Give users a modern and native macOS app with your corporate identity

The app is developed by Root3, specialized in managing Apple devices. Root3 offers managed workplaces, consultancy and support for organizations to get the most out of their Apple devices and is based in The Netherlands (Halfweg).

Root3 already had a basic in-house support app written in Objective-C and decided to completely rewrite it in Swift using SwiftUI with an all-new design that looks great on macOS Big Sur. We’ve learned that SwiftUI is the perfect way of creating great looking apps for all Apple platforms with minimal effort. In the development process we decided to make it generic so other organizations can take advantage of it and contribute to the Mac admins community.

The easiest and recommended way to configure the app is using a Configuration Profile and your MDM solution.

## Requirements
* macOS 11.0.1 or higher
* Any MDM solution supporting custom Configuration Profiles

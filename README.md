# Photo collection project
Revised 2026-08-13

## Intro
This repo contains the source code for a photo collection app with frontend and cloud backend.
The purpose is to create helpful tools to build datasets of photos as a group effort.
Collecting photos is a key activity for every data driven approach to computer vision.
This is a result from a project in the forestry value chain, but the result is applicable in any field.

## User documentation
End user documentation is not provided here. 

The app is primarily targeted to run on iPhone and Android phones.
In order to build and run the app a developer or maintainer needs to setup a backend 
and distribute the app to intended users. We do not intend for an end user of the app 
to build or run the app directly from this repository.

## Developer documentation
There are fundamentally two parts that work together, the user application and the cloud backend.
This repo is diveded into the main folders for separate parts.

- `kokoelma` is the backend that runs on __Supabase__.
- `photocollectionapp` is the user app built in __Flutter__.

See each folder for further documentation.

### Requirements

#### Supabase
The backend requires a __Supabase__ instance, which can be hosted by Supabase.com, self-hosted or 
a local instance for development and testing. We recommend installing the Supabase CLI tools.
Refer to the Supabase documentation.

#### Flutter
The phone app is built in __Flutter__ and the Dart programming language. Flutter can build cross-platform
apps that can run on multiple devices and operating systems. We primarily target iPhone and Android phones.
We recommend installing Flutter CLI tools.
See the photocollection app folder for further documentation and refer to the Flutter documentation.

#### VSCode
Using VSCode is not a requirement, but we have not tested any other means of Flutter debugging.
We have used Visual Studio Code with some extensions as the main code editor for this project. 

#### XCode
XCode is required to build Flutter projects for Apple devices like iPhone.

#### Apple Developer Program
To distribute apps to Apple devices through TestFlight or App Store, an active subscription to the
Apple Developer Program is required. This is however not required for a developer to test an app on 
their own iPhone/iPad.


### Setup
See each folder for setup instructions.

### Structure
Each top level folder in this repo is a separate part or project with its own requirements and tooling.

We try to follow a GitFlow branching pattern with long lived `main`and `develop` branches and short lived
feature branches that for off of develop. We use git tags to label version numbers of distributables.


## Resources

### Contributors

[Greger Burman](https://github.com/adgbu)
[Jonas Holmlund](https://github.com/JonasHolmlundAD)
[Peter Bomark](https://github.com/adpeb)

### Organisations

Adopticum has a [web page](https://www.adopticum.se) and a [GitHub page](https://github.com/adopticum).


## Status
🔰 This app is currenly an early working version for test and development.

### ToDo (recommended)
- Backup and restore procedures for stored data like (user accounts, photos and metadata).
- Admin UX for managing users and groups.

### Changelog (optional)


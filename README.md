# Project SlackUsers

The iOS app to search users in slack.

## Requirements

* Requires Xcode 14.1 or later.
* Requires device/simulator running on iOS 13 or later OS version.

## Key Features

* User can see past search results on `Recent Searches` screen which is the first screen that appears when launched.
* Search button is provided in top right corner in `Recent Searches` screen. On click user reaches `Search Users` screen.
* In `Search Users` screen user can search any text.
* App waits for 0.5 seconds after every key stroke and makes an API call to fetch users having display name or user name prefixed with searched text.
* The search results are `paginated with page size of 20`. i.e.
  First set of 20 records are displayed as soon as response comes via API call. When user scrolls to bottom. It shows next 20 records and so on.  
* If no records are received via API call. Then Alert indicating `No records found` is shown and the searched text is added in denial list.
  Every searched text existence is verified in denial list. If found in denial list alert indicating `No records found` is shown but no api call is made.
* If internet is turned off when user searched any text in `Search Users` screen. Alert indicating `No internet connection. Please search users when online.` is shown.
* If any error occurs in API call. Alert indicating `Something went wrong!` is shown.

## Technology Stack

* swift
* UIKit
* Combine
* Coredata

## Design Patterns

* MVVM - Coordinator
* Repository pattern
* Dependency injection


### MVVM - Coordinator

MVVM - Coordinator ( Model, View, View Model, Coordinator)
* Traditional MVVM pattern does a great job for dividing business and UI logic. It tackles Huge View Controllers problem. But navigation logic
  lies in view controllers which makes the flow tightly coupled. i.e screen 2 can only be presented from screen 1.
* The navigation logic can be moved out to coordinators.
* View Model only contains data that is required to be presented in view layer.
* When view demand dynamic data from either API or persistent store coordinator fetches the data from data source prepares the view model
  and injects to view layer. 
* It makes the request and response flow always unidirectional. i.e when view demands data coordinator provides by populating the view model.

#### Why MVVM - Coordinator pattern used?
* It clearly separates each layers responsibility. 
* View is responsible for showing UI and is not aware of data that it needs to render.
* View Model is responsible for providing the data and validate it on basis of business requirements.
* Repository layer acts as data source which either fetches data from API or persistent store.
* Model are plain objects.
* Coordinator is responsible for coordinating between these layers. 

### Repository pattern
* This pattern exposes a single interface to coordinators and doesn't reveal how data is stored & fetched.

### Dependency injection
* This pattern inverts the dependency between two objects. If object A depends on object B rather than using concrete instance of Object B.
  It uses an iterface which Object B adheres to.
* This also helps to inject mock object (adhering to Interface) instead of object B to object A.









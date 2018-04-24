# SwiftNIO IRC Web Client

A small chat-webapp written in plain JavaScript, not using any frameworks.
Well, we do use [JDENTICON](https://jdenticon.com) to produce some default
chat icons.

The app works standalone, the `Client.html` file can just be dragged into
a browser (make sure the/a IRC gateway is running).

To include it in the Swift IRCWebClient module, we wrap all the resource
files in a single Swift file (`ClientResources.swift`). That means, if the
client files are modified, you need to perform a `make` in the `Client`
subdirectory.

## Setup

This is not a work of beauty, but does the job well enough.
PRs are *very* welcome!
The goal is to keep it simple, but great.

### Model

There is a `ClientConnection` object which maintains the WebSocket connection
to the IRC bridge. The messages are transferred as JSON encoded IRCMessage
objects.

The `ChatItem` essentially contains the "view model". It contains the
information which is being rendered in the chat-view 
(sender, message, read etc).

### View Controllers

Of course those are not "real" view controllers, but they follow the same
idea :-)

There is the `MainVC` which represents the window and contains `MessagesVC`
for the chat view and the `SidebarVC` which contains queries ("private" messages 
with other users) and channels.

The `MainVC` also creates and maintains the connection, as well as the
dictionary of open channels and user queries.

### Styles

The CSS is a simple flexbox based setup.

Thanks go to [@slashmo](https://github.com/slashmo) for the original
flexbox layout and CSS setup!


### Who

Brought to you by
[ZeeZide](http://zeezide.de).
We like
[feedback](https://twitter.com/ar_institute),
GitHub stars,
cool [contract work](http://zeezide.com/en/services/services.html),
presumably any form of praise you can think of.

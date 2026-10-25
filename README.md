# Ion-DJ2GO-LED-Lightshow
Simple background powershell script to animate LEDs of Ion DJ2GO usb controllor over Midi commands whilst it's hooked upto a Windows PC and not in use. Helps to make the controller look more interesting whilst taking up desk/shelf space, as it has no default built-in animations.

Launching the .bat script to run the .PS1 script in a bypassed environment, this can be launched manually or as a startup task in task schedular/startup apps using SYSTEM user.

At the minute, script flashes the play, cue, sync and headphone buttons in a random fashion.

When the controller is required, the powershell script will need stopping, by either stopping the service or simply unplugging and plugging the USB controller back in.

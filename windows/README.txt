termkit for Windows
======================

Kimi Code with the termkit features (CloseRouter and 7api providers, live
balance and session cost in the footer, /wipe-all-sessions, ...).

Install or update
-----------------
1. Extract this zip (right-click > Extract All...).
2. Double-click "Install.cmd".
3. Paste your CloseRouter key and your 7api key when asked. Press Enter on an
   empty line to skip either one.
4. Open a NEW terminal, go to your project folder and type:  kimi

No admin rights or Node.js needed. kimi.exe goes to
%LOCALAPPDATA%\Programs\termkit and is added to your PATH. The keys are
saved as your user environment variables CLOSEROUTER_API_KEY and
SEVENAPI_API_KEY. Settings live in %USERPROFILE%\.kimi-code (an existing
config.toml is kept).

To change or remove a key later, run "Install.cmd" again
(Enter keeps a saved key, "-" removes it).

Kimi's built-in auto-update is turned off, because it would replace this
build with the plain official release. Never run "kimi upgrade" or
"npm install -g @moonshot-ai/kimi-code"; install a newer termkit zip
instead.

Uninstall
---------
Double-click "Uninstall.cmd", or use Settings > Apps >
Installed apps > "termkit".

Windows may warn that the files come from the internet or that kimi.exe is
from an unknown publisher (it is not code-signed). Choose "Run" / "More info >
Run anyway".

Kimi Code is MIT licensed by Moonshot AI, see LICENSE-upstream.txt.

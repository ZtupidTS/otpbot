-----Readme------
You should have the following files in the working directory for the bot:

Core Files:
otpbot.exe
otpbot.au3
otpbot.ini (optional)
utm.au3

Decoder Files:
otpxor.exe
otpnato.exe
data.bin
elpaso.bin
littlemissouri.bin
worm.ini
p1.txt
p2.txt
p3.txt
p4.txt



The bot needs permission to run otpxor.exe and otpnato.exe, and permission to read/write to files in its base directory (for message storage)

Further requirements may be necessary with feature additions.

Updated 8:28 PM 4/12/2013


-----Updates------
1.1 * file path and Run() changes for otpxor in decoding; did not run originally for unknown reasons. Runs fine now.
1.2 + parameter and more future-proof code for pastebindecode(),
    + Added a configuration variable for the default autodecoder keyfile
2.0 + Added commands for decoding xor messages: @elpaso @bluehill @littlemissouri (with command aliases) these all take pastebin URL's as the parameter
         and expect the data to be in the format XX XX XX XX... offset NNN...
2.1 * Prevented the Update command from caching output. it should now properly update every 15min (I hope)
    + Added keyfile size information to the @debug output
    * Fixed decoder commands not firing; switch/case was not comparing the command, but the entire post.
3.0 + Configuration variables are now loaded from an INI file if possible; this makes it possible to configure the program without editing the source.
         this configuration file is completely optional, as the default values will still be used if it is missing
    + Added @ITA2 @ITA2S @lengthstobits @flipbits @ztime commands
    + Added support to automatically call functions by a Commandname, if the function name is prefixed with "COMMAND_" (similar to Public functions in AutoBit)
4.0 + Added Extended CommandFunction support, which are commands which take all message parameters: who, where, what, and a commandarray.
         You can define one of this functions with the COMMANDX_ prefix.
    + Added the @WORM extended command function, which decodes 5-gram messages using the Worm-related replacement table (source: Book QR Code)
         Note: expects input like "FNAIU FNAIU XBAUL" length and spacing-wise.
    + Added the `commandchar` INI/configuration variable, so the default command character of "@" can be changed. (prefer you don't in #ARG)
    + Added support for OTPNATO 5gram decoder @5gramfind and @5gram (decode) commands.
4.1 * Fixed an issue with wikilink conversion crashing the bot
4.2 * Updated the News data URL to keep working (stopped working in 4.1), and added a "newsurl" configuration variable to the INI for future fixes not requiring an update.
5.0 + Added Commands: @UTM @LL for coordinate conversions.
5.1 * Fixed XOR Decoding from appending a nonsense character to the end.
5.2 * Bot now uses OTP Message decoding auto-correction (attempts to fix offset issues from human input error) provided by the newest OTPXOR version.
5.3 + @calc command added for simple numerical expressions (eg: 2/3+5-2^6) - note: letters and strings are not allowed for input sanitation reasons.
6.0 + Added support for a Host program (OtpHost) which can monitor/restart and automatically update OtpBot while it is running.
         Running OtpHost is completely optional, and running OtpBot alone will function as normal
         Note: if you use OTPHost, close OTPHost, not OtpBot. Otherwise otphost will just restart the bot.
6.1 + OtpHost now detects if OtpBot hangs up. (note: requires updated otpbot that can respond to localhost pings)
    + @tinyurl command which shorterns URLs
    + @update/news URL's are now automatically shortened when possible.




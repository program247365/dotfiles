#!/usr/bin/osascript

# Required parameters:
# @raycast.schemaVersion 1
# @raycast.title Get IP Address
# @raycast.mode compact
# @raycast.refreshTime 1h

# Optional parameters:
# @raycast.icon 🤖
# @raycast.packageName utils

# Documentation:
# @raycast.description Get IP Address
# @raycast.author John Buckley
# @raycast.authorURL https://github.com/nhojb

(*
script by Phil Stokes
www.applehelpwriter.com
2013
This script will deteremine the IP Addresses of your router, your node on the internal network (aka 'Internal IP') and your public internet IP address (aka 'External IP') and allow you to copy them for use in Terminal or other applications
The script is set to display 'No connection' after a pretty short 3-second timeout. Feel free to increase that at the line in the script after the comment "# CHANGE THE DELAY HERE…". Just change the number '3' to something longer (the number = seconds). Alternatively,  just keep hitting the 'Try Again' button when the app runs as necessary.
Enjoy! 
Phil  
*)
property theNetwork : ""
property theRouter : ""
property theLocalNode : ""
on getIP()
	try
		set myTemp to do shell script "mktemp -t txt"
		do shell script "curl -s http://checkip.dyndns.org &> " & myTemp & " &2> /dev/null"
		
		# CHANGE THE DELAY HERE…      
		delay 3
		set extIP to do shell script "sed 's/[a-zA-Z/<> :]//g' " & myTemp
		
		if extIP = "" then
			set my theNetwork to "No connection"
		else if extIP contains "=" then
			set theNetwork to "Can't get IP"
		else
			set theNetwork to extIP
		end if
	on error
		set theNetwork to "No connection"
	end try
end getIP
on getRouter()
	try
		set oldDelims to AppleScript's text item delimiters
		set AppleScript's text item delimiters to "gateway:"
		set theGateway to do shell script "route get default | grep gateway"
		set AppleScript's text item delimiters to oldDelims
		set theRouter to the last word of theGateway
	on error
		set my theRouter to "No connection"
	end try
end getRouter
on getLocalNode()
	try
		set theIP to (do shell script "ifconfig | grep inet | grep -v inet6 | cut -d\" \" -f2")
		set theLocalNode to the last word of theIP
	on error
		set theLocalNode to "Can't get Local IP"
	end try
end getLocalNode
end

-- log "Running..."

try
	getRouter()
	getIP()
	getLocalNode()
	log "Router: " & theRouter & ", Local: " & theLocalNode & ", Network: " & theNetwork
on error
	log "error"
end try
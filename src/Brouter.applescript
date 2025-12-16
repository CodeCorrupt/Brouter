on open location theURL
	my handleURL(theURL)
end open location

on open theItems
	repeat with anItem in theItems
		set theURL to (anItem as text)
		my handleURL(theURL)
	end repeat
end open

on handleURL(theURL)
	set shPath to POSIX path of ((path to me as text) & "Contents:MacOS:brouter")
	do shell script quoted form of shPath & " " & quoted form of theURL
end handleURL

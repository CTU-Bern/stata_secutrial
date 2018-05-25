
* Alan Haynes
* March 2017

* program to remove most system variables
cap program drop scrubvars
program define scrubvars 
	foreach v in "visitnumber" "visittype" "mnpptnid"  ///
		"mnpcvpid" "mnpvisno" "mnpvisfdt" "mnpfs0" ///
		"mnpfs1" "mnpfs2" "mnpfs3" "mnpfcs0" "mnpfcs1" "mnpfcs2" "mnpfcs3" "mnpfsqa" ///
		"mnpfsct" "mnpfssdv" "mnphide" "sigstatus" "sigreason" "mnpvsno" "mnpvslbl" ///
		"mnpaeid" "mnpaedate" "mnpaeno" "mnpaefuid" "mnpaefudt" "mnpsubdocid" "fgid" "position" {
		cap drop *`v'
	}   
end


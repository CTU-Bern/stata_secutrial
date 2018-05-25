
* Alan Haynes
* March 2017

* program to add centre ID to data set (relies on casenode and centres files in $orig)

cap program drop add_centre
program define add_centre 
	syntax , [Reformat]
	mmerge mnppid using "$orig/casenodes", ukeep(mnpctrid) unmatched(master)
	mmerge mnpctrid using "$orig/centres", ukeep(mnpctrname mnpcname) unmatched(master)
	if "`reformat'" != "" {
		split mnpctrname, gen(ctr) parse(", ")
		gen mnpctrname2 = ctr3 + ", " + ctr2
		replace mnpctrname = mnpctrname2
		drop ctr* mnpctrname2
	}
end



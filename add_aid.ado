
* Alan Haynes
* March 2017

* program to add alternative ID to stata data set (relies on casenode file in $orig)

cap program drop add_aid
program define add_aid 
	mmerge mnppid using "$orig/casenodes", ukeep(mnpaid) unmatched(master)
end


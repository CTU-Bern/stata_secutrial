
* Alan Haynes
* March 2017

* program to add randomization status

cap program drop add_rando
program define add_rando
	syntax , [UNMatched(str)]
	if "`unmatched'" == "" {
		local unmatched = "master"
	}
	mmerge mnppid using "$orig/random", ukeep(randomized regimen) unmatched(`unmatched')
end


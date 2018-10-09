/*
* 634 MASTERDAPT 
*  SecuTrial ZIP data import
*  Alan Haynes
*  Started 2017/02/03


support for audit trail export and query log added 20170330
global audit = 1
global query = 1
to export them too

*/

*cap program drop st_zip_import
*program define st_zip_import
*	syntax , [Unzip(string) Tmp(string) Orig(string) Audit()]

if "$unzip" == "" {
	di as error "Please define a global macro called unzip with a path for unzipping" 
	stop
}
if "$tmp" == "" {
	di as error "Please define a global macro called tmp for temporary files" 
	stop
}
if "$orig" == "" {
	di as error "Please define a global macro called orig for imported stata data files" 
	stop
}
if "$audit" == "" {
	global audit = 0
}
if "$queries" == "" {
	global queries = 0
}

window fopen zipfile "Select export data" ".zip"


cap mkdir "$unzip"
cd "$unzip"
unzipfile "$zipfile"
cd "$pp"

cap program drop secu_varclear
program define secu_varclear
* secutrial appends each row with a tab creating an empty variable
	qui ds 
	local varorder = r(varlist)
	foreach v in `=r(varlist)' {
		local vx = regexm("`v'", "^v[0-9]+$")
		if `vx' == 1 {
			*disp "dropping `v'"
			drop `v'
		}
	}
end

qui {
noi : di as txt "Collating files"
* work out file extension (.csv/.xls)
shell dir "$unzip" /a-d /b > "$tmp/files.txt" // create a list of the files in txt format (by calling the windows shell directly)
import delimited "$tmp/files.txt", clear
save "$tmp/filesInFolder", replace
gen pp = strrpos(v1, ".")
gen ss = substr(v1, pp, .)
gen n = 1
collapse (count) n, by(ss)
summ n 
egen nn = max(n)
keep if nn == n
local fileext = ss[1]
erase "$tmp/files.txt"

cd "$pp"
noi : di as txt "Defining file extension and filenames"
* file extension
di regexm("$zipfile", "P[0-9]+_[0-9]+-[0-9]+")
global fileext = regexs(0) + "`fileext'"
di "$fileext"

di regexm("$zipfile", "mnpp[0-9][0-9][0-9][0-9]")
*global fileext2 = regexs(0)
*di "$fileext2"

* export date (add as note to each file)
di regexm("$zipfile", "[0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9]")
global expdate = regexs(0)
di "$expdate"

/*delimiter*/
import delimited "$unzip/visitplan_$fileext", clear  rowrange(1:1) varnames(nonames)
gen sep = regexs(0) if regexm(v1, ";|	|,")
global sep = sep[1]

/* centres */
noi : di as txt "Importing system files"
foreach i in "centres" "casenodes" "visitplan" "cl" "questions" "forms" {
	import delimited "$unzip/`i'_$fileext", clear delim("$sep")
	secu_varclear
	note : Export date: $expdate
	save "$orig/`i'", replace
}

*import delimited "$unzip/centres_$fileext", clear delim("`sep'")
*secu_varclear
*save "$orig/centres", replace

/* casenodes */
*import delimited "$unzip/casenodes_$fileext", clear delim("`sep'")
*secu_varclear
*save "$orig/casenodes", replace

/* val labels */
*di "$sep"
}
qui {
di as result "Preparing value labels"
*import delimited "$unzip/visitplan_$fileext", clear delim("`sep'")
*secu_varclear
*save "$tmp/visitplan", replace
use "$orig/visitplan", clear
keep mnpvislabel mnpvisid
rename mnpvislabel keytext
rename mnpvisid keynr
gen cat = "mnpvisid_l"
save "$tmp/visitcode", replace

di "$sep"
*import delimited "$unzip/cl_$fileext", clear delim("`sep'")
*secu_varclear
*note : Export date: $expdate
*save "$tmp/cl", replace
use "$orig/cl", clear
*cat keynr keytext
*var cat
rename code keynr
rename value keytext 
gen point = strpos(column, ".")
gen var = substr(column, point+1, .)
gen cat = var + "_l"
gen form = substr(column, 1, point-1)
replace form = regexr(form, "mnpp[0-9][0-9][0-9][0-9]", "")
replace form = regexr(form, "^_", "")
preserve 
use "$orig/forms", clear
replace formtablename = regexr(formtablename, "mnpp[0-9][0-9][0-9][0-9]", "")
replace formtablename = regexr(formtablename, "^_", "")
levelsof formtablename, local(vallabforms)
restore
tempfile TMP
save "`TMP'"

foreach val of local vallabforms {
	di as text "form = `val'"
	use "`TMP'", clear
	keep if form == "`val'" | missing(form)
	keep cat keynr keytext
	append using "$tmp/visitcode"
	order cat keynr keytext
	save "$tmp/xlabels_`val'", replace
	if $audit == 1 {
		save "$tmp/xlabels_at`val'", replace
	}
	
	use "`TMP'", clear
	keep if form == "`val'" | missing(form)
	keep cat var
	bysort var : gen nth = _n
	keep if nth == 1
	drop nth
	set obs `=`=_N'+1'
	replace var = "mnpvisid" in `=_N'
	replace cat = "mnpvisid_l" in `=_N'
	save "$tmp/xlabelvars_`val'", replace
	if $audit == 1 {
		save "$tmp/xlabelvars_at`val'", replace
	}
	
}
use "`TMP'", clear
keep if missing(form)
keep cat keynr keytext
append using "$tmp/visitcode"
order cat keynr keytext
save "$tmp/xlabels_casenodes", replace
save "$tmp/xlabels_centres", replace
save "$tmp/xlabels_queries", replace
use "`TMP'", clear
keep if missing(form)
keep cat var
bysort var : gen nth = _n
keep if nth == 1
drop nth
set obs `=`=_N'+1'
replace var = "mnpvisid" in `=_N'
replace cat = "mnpvisid_l" in `=_N'
save "$tmp/xlabelvars_casenodes", replace
save "$tmp/xlabelvars_centres", replace
save "$tmp/xlabelvars_queries", replace

* System variables
clear
input str32 var str100 text , 
"mnpvisid"			"System: Visit identifier" 
"visitnumber"		"System: visit sequence"
"visittype"			"System: visit type (fixed/flexible/unscheduled/free"
"visitstartdate"	"System: Patient entry into project"
"mnppid"			"System: System Patient ID"
"mnpaid"			"System: Additional Patient ID"
"mnplabid"			"System: Additional Patient ID 2"
"mnp_regimen_gr"	"System: randomisation"
"mnpcnptnid"		"System: Center Patient ID"
"mnpctrid"			"System: Center ID"
"mnpdocid"			"System: eCRF ID"
"mnplastedit"		"System: date of last edit"
"mnpptnid"			"System: form last saved by"
"mnpcvpid"			"System: participant visit ID"
"mnpvisno"			"System: Individual number of visit for the given casenode."
"mnpvispdt"			"System: planned visit date"
"mnpvisfdt"			"System: date of first data entry"
"mnpfs0"			"System: Review level 1"
"mnpfs1"			"System: Review level 2"
"mnpfs2"			"System: Record manually frozen"
"mnpfs3"			"System: Record frozen by system"
"mnpfcs0"			"System: Completion status"
"mnpfcs1"			"System: Errors in record"
"mnpfcs2"			"System: Warnings in record"
"mnpfcs3"			"System: Data entry complete"
"mnpfsqa"			"System: Open query"
"mnpfsct"			"System: Comment on form status"
"mnpfssdv"			"System: source data verification status"
"mnphide"			"System: hidden form"
"sigstatus"			"System: signature status"
"sigreason"			"System: reason for modified data"
"mnpvsno"			"System: project version number at time eCRF stored"
"mnpvslbl"			"System: project version label at time eCRF stored"
"mnpaeid"			"System: Unique AE ID"
"mnpaedate"			"System: AE date"
"mnpaeno"			"System: AE number for the given casenode"
"mnpaefuid"			"System: The ID of a follow-up to the Adverse Event"
"mnpaefudt"			"System: Adverse Event follow up date"
"mnpsubdocid"		"System: subdocument ID"
"fgid"				"System: repetition id"
"position" 			"System: position in repetition of parent document"
"mnpcs0"			"System: Patient record valid"
"mnpcs1"			"System: Patient record set as anonymized"
"mnpcs2"			"System: Patient record frozen"
"mnpcs3"			"System: Patient record automatically frozen"
"mnpcs4"			"System: Patient deceased"
"mnpcs5"			"System: Patient frozen"
"mnpcs6"			"System: Patient to be deleted"
"mnpcs7"			"System: Patient has closed visit plan"
"mnpvisstartdate" 	"System: Patient entry into project"
end
save "$tmp/sysvars", replace
}
/* var labels & date variables */
qui : di as res "Figuring out which variables are date or datetime"
*qui {
import delimited "$unzip/items_$fileext", clear delim("$sep")
secu_varclear
duplicates drop ffcolname itemtype, force
note : Export date: $expdate
macro drop DMYvars MYvars DTvars
local on = `=_N'
forvalues i = 1/`on' {
	local ix = itemtype[`i']
	*di "`ix'"
	local dx = regexm("`ix'", "DD-MM-YYYY$")
	if `dx' == 1 {
		*di "...added to list"
		local vx = ffcolname[`i']
		global DMYvars = "$DMYvars `vx'"
		set obs `=`on'+1'
		replace ffcolname = "`vx'2" in `=_N'
		local lab = fflabel[`i']
		replace fflabel = "DMY: `lab'" in `=_N'
	}
	
}
disp "`DMYvars'"
forvalues i = 1/`on' {
	local ix = itemtype[`i']
	*di "`ix'"
	local dx = regexm("`ix'", " MM-YYYY$")
	if `dx' == 1 {
		*di "...added to list"
		local vx = ffcolname[`i']
		global MYvars = "$MYvars `vx'"
		set obs `=`on'+1'
		replace ffcolname = "`vx'2" in `=_N'
		local lab = fflabel[`i']
		replace fflabel = "MY: `lab'" in `=_N'
	}
	
}
disp "$DMYvars"
disp "$MYvars"
forvalues i = 1/`on' {
	local ix = itemtype[`i']
	*di "`ix'"
	local dx = regexm("`ix'", "DD-MM-YYYY HH:MM$")
	if `dx' == 1 {
		*di "...added to list"
		local vx = ffcolname[`i']
		global DTvars = "$DTvars `vx'"
		set obs `=`on'+1'
		replace ffcolname = "`vx'2" in `=_N'
		local lab = fflabel[`i']
		replace fflabel = "DMYhm: `lab'" in `=_N'
	}
	
}
save "$tmp/items", replace

noi : di as result "Preparing value labels"

*use "$tmp/items", clear
keep ffcolname fflabel fgid
rename ffcolname var
rename fflabel text
append using "$tmp/sysvars"
save "$tmp/varlabels", replace
mmerge fgid using "$orig/questions", ukeep(formid)
mmerge formid using "$orig/forms", ukeep(formtable)
replace formtable = regexr(formtable, "mnpp[0-9][0-9][0-9][0-9]", "")
replace formtable = regexr(formtable, "^_", "")

levelsof formtablename, local(varlabforms)
foreach labform of local varlabforms {
	preserve
	keep if formtablename == "`labform'" | missing(formtablename)
	keep var text
	save "$tmp/varlabels_`labform'", replace
	if $audit == 1 {
		save "$tmp/varlabels_at`labform'", replace
	}
	restore
}
keep if missing(formtablename)
keep var text
save "$tmp/varlabels_casenodes", replace
save "$tmp/varlabels_centres", replace
save "$tmp/varlabels_queries", replace


/* Import forms */
*di "`forms'" , _request(k)
noi : di as result "Collating list of forms"

import delimited "$unzip/forms_$fileext", clear delim("$sep")
secu_varclear
note : Export date: $expdate
bysort formtablename : gen nth = _n
keep if nth == 1

* remove forms that do not occur in the unzip folder
gen filename = formtablename + "_$fileext"
mmerge filename using "$tmp/filesInFolder", umatch(v1) unmatched(none)
drop _merge


if "$forms" == "" {
	local forms = "casenodes"
	
	forvalues i = 1(1)`=_N' {
		local forms = "`forms' " + formtablename[`i']
		if $audit == 1 {
			local forms = "`forms' at" + formtablename[`i']
		}
	}
	
}
*di "`forms'" , _request(k)
if "$forms" != "" {
	local forms = "casenodes "
	foreach i of global forms {
	
		preserve
			*local i = "e_stent_det"
			di "`i'"
			keep if regexm(formtablename, "`i'$")
			if `=_N' > 0 {
				duplicates drop formtablename formname, force
				list formtablename formname
				forvalues j = 1/`=_N' {
					di `j'
					local forms = "`forms' " + formtablename[`j']
					if $audit == 1 {
						local forms = "`forms' at" + formtablename[`j']
					}
				}
			}
			*di "FOO"
		restore
	}
}

if $queries == 1 {
	local forms = "`forms' queries"
}


save "$tmp/forms", replace
di "`forms'" 
* regular forms *
*local forms = "add_asp add_clop add add_pras add_tica ado1 cl_hist cons cv_hist dapt_calc demog elig_short end lab lab2 lab3 les1 les2 noac_api noac_dabi noac_edo noac_riva oac_ace oac_phen oac_war pci pci2 pci3 random_ass random sae_comp sae_cva sae_death sae_les sae" 
* extended forms (sub-forms)/recurring items
*local eforms = "adh_warf ble lab_det noac_api_det noac_dabi_det noac_edo_det noac_riva_det pci_det sae_transf stent_det adh_dapt_clop adh_dapt_det adh_dapt_pras adh_dapt_tic"
*di "`forms'", _request(k)
noi : di as res "Preparing forms" 
foreach form in `forms' "centres" {
	*local form = "mnpp0634_cons"
	noi : di "starting `form'"
	qui {
	import delimited "$unzip/`form'_$fileext", clear delim("$sep")
	note : Export date: $expdate
	note : Original file name: `form'
	local formi = regexr("`form'", "mnpp[0-9]+", "")
	local formi = regexr("`formi'", "^_", "")
	local formsi = "`formsi' `formi'"
	
	secu_varclear
	qui ds 
	local varorder = r(varlist)
	
	* DO stuff if there are observations
	if `=_N' > 0 {
		* system date variables
		cap  {
			gen  mnpvslbldt = regexs(0) if regexm(mnpvslbl, "[0-9][0-9].[0-9][0-9].[0-9][0-9][0-9][0-9]")
			gen  mnpvslbltime = regexs(0) if regexm(mnpvslbl, "[0-9][0-9]:[0-9][0-9]:[0-9][0-9]")
			drop mnpvslbl
			gen mnpvslbl = mnpvslbldt + " " + mnpvslbltime
			drop mnpvslbldt mnpvslbltime
		}
		foreach v in "mnplastedit" "mnpaefudt" "mnpaedate" "mnpvisfdt" {
			cap  {
				local v2 = "`v'2"
				gen `v2' = clock(`v', "YMD hms")
				format `v2' %tc
				drop `v'
				rename `v2' `v' 
			}
		}
		foreach v in "mnpvslbl" {
			cap  {
				local v2 = "`v'2"
				gen `v2' = clock(`v', "DMY hms")
				format `v2' %tc
				drop `v'
				rename `v2' `v' 
			}
		}
		foreach v in "mnpvispdt" {
			cap {
				local v2 = "`v'2"
				gen `v2' = date(`v', "YMD")
				format `v2' %td
				drop `v'
				rename `v2' `v' 
			}
		}
		
		
		* project date variables
		cap {
			foreach v in $DMYvars {
				*tostring consent_date, replace
				*gen consent_date2 = date(consent_date, "YMD")
				cap {
					tab `v' 
					tostring `v', replace
					gen `v'2 = date(`v', "YMD")
					format `v'2 %td
					*drop `v'
					rename `v' `v'_orig
					rename `v'2 `v'
				}
			}
			foreach v in $MYvars {
				cap {
					tab `v' 
					tostring `v', replace
					gen `v'2 = date(`v', "YM")
					format `v'2 %td
					*drop `v'
					rename `v' `v'_orig
					rename `v'2 `v'
				}
			}
			foreach v in $DTvars {
				cap {
					tab `v' 
					tostring `v', replace
					gen `v'2 = clock(`v', "YMD HM")
					format `v'2 %td
					*drop `v'
					rename `v' `v'_orig
					rename `v'2 `v'
				}
			}
		}
		
		* variable/value labels
		*local formi = regexr("`form'", "mnpp[0-9][0-9][0-9][0-9]", "")
		*local formi = regexr("`formi'", "^_", "")
		cap xvarlabel , var("$tmp/varlabels_`formi'")
		if _rc != 0 {
			local formx = regexr("`formi'", "^at_", "at")
			xvarlabel , var("$tmp/varlabels_`formx'")
		}
		cap xlabel , varinfo("$tmp/xlabelvars_`formi'") labinfo("$tmp/xlabels_`formi'")
		if _rc != 0 {
			local formx = regexr("`formi'", "^at_", "at")
			xlabel , varinfo("$tmp/xlabelvars_`formx'") labinfo("$tmp/xlabels_`formx'")
		}
	}
	
	order `varorder'
	
	save "$orig/`formi'", replace
	}
	noi : di "`formi' saved"
}

global forms = "`formsi'"

/* Visit information */ 
import delimited "$unzip/visitplanforms_$fileext", clear delim("$sep")
secu_varclear
mmerge mnpvisid using "$orig/visitplan"
mmerge formid using "$orig/forms"
order mnpvis* form*
sort mnpvisid
drop _merge
save "$dd/visit_form_info", replace

noi : di as result "Cleaning up"
/* Clean up unzip folder */
shell dir "$unzip" /a-d /b > "$tmp/files.txt" // create a list of the files in txt format (by calling the windows shell directly)
import delimited "$tmp/files.txt", clear
file open myfile using "$tmp/files.txt", read // open file; will be closed after completion of the loop
	scalar eofi = 0 // we need a global emf of file indicator , because r() objects will get lost (SIS)
	while eofi == 0 { // loop
			// define dataset name to be processed in current loop iteration put in `datsID'
			file read myfile datsID
			scalar eofi = r(eof) // necessary because r() objects will get lost too soon
			if eofi == 0 {
				global tempFileNam = "$unzip\" + "`datsID'"
				erase "$tempFileNam"
				}
		}
	//
file close myfile
erase "$tmp/files.txt"
/* Clean up tmp folder */
shell dir "$tmp" /a-d /b > "$pp/files.txt" // create a list of the files in txt format (by calling the windows shell directly)
import delimited "$pp/files.txt", clear
file open myfile using "$pp/files.txt", read // open file; will be closed after completion of the loop
	scalar eofi = 0 // we need a global emf of file indicator , because r() objects will get lost (SIS)
	while eofi == 0 { // loop
			// define dataset name to be processed in current loop iteration put in `datsID'
			file read myfile datsID
			scalar eofi = r(eof) // necessary because r() objects will get lost too soon
			if eofi == 0 {
				global tempFileNam = "$tmp\" + "`datsID'"
				erase "$tempFileNam"
				}
		}
	//
file close myfile
erase "$pp/files.txt"

macro drop sep


noi : di as result "List of forms saved in global 'forms'" _n(2) as error "Date variables are duplicated with the original remaining as a string" _n `"(the name is appended with "_orig"), and a new variable in the appropriate "' _n "date/datetime format e.g. %td" _n(2)

clear



cd "$pp"


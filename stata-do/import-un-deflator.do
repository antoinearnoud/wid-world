import delimited "$un_data/sna-main/deflator/deflator.csv", ///
	clear delimiter(";") encoding("utf8")

// Identify countries ------------------------------------------------------- //
countrycode countryorarea, generate(iso) from("un sna main")
drop countryorarea

// Deal with former economies
drop if (iso == "SD") & (year <= 2010)
replace iso = "SD" if (iso == "SD-FORMER")

// Sanity check: only one currency by country
replace currency = strtrim(stritrim(strlower(currency)))
egen ncu = nvals(currency), by(iso)
assert ncu == 1
drop ncu

rename implicitpricedeflator def_un
keep iso year currency def_un

// Convert to Israeli New Shekel for the State of Palestine
tempfile unsna
save "`unsna'"

import delimited "$oecd_data/exchange-rates/ils-usd.csv", clear
generate iso = "PS"
rename time year
rename value exch
keep iso year exch
tempfile exch
save "`exch'"

use "`unsna'", clear
merge n:1 iso year using "`exch'", nogenerate keep(master match)
replace def_un = def_un*exch if (iso == "PS")
replace currency = "new israeli sheqel" if (iso == "PS")
drop exch

// Re-normalize in 2005
quietly levelsof def_un if (iso == "PS") & (year == 2005), local(level2005)
replace def_un = 100*def_un/`level2005' if (iso == "PS")

// Correction in North Korea
replace def_un = 100*def_un if (year <= 2001) & (iso == "KP")

// Identify currencies ------------------------------------------------------ //
currencycode currency, generate(currency_iso) iso2c(iso) from("un sna main")
drop currency
rename currency_iso currency

// Correct fiscal year ------------------------------------------------------ //
egen id = group(iso)
xtset id year

generate newvalue = .

// See: http://unstats.un.org/unsd/snaama/notes.asp
replace newvalue = (1 - 0.75)*L.def_un + 0.75*def_un ///
	if inlist(iso, "IN", "MM", "NZ")
replace newvalue = (1 - 0.50)*L.def_un + 0.50*def_un ///
	if inlist(iso, "AU", "NI", "SD", "YD")
replace newvalue = (1 - 0.78)*L.def_un + 0.78*def_un ///
	if inlist(iso, "AF", "IR")
replace newvalue = (1 - 0.50)*def_un + 0.50*F.def_un ///
	if inlist(iso, "BD", "EG", "NR", "PK", "PR", "TO")
replace newvalue = (1 - 0.25)*def_un + 0.25*F.def_un ///
	if inlist(iso, "HT", "MH", "FM")
replace newvalue = 0.53*def_un + (1 - 0.53)*F.def_un ///
	if inlist(iso, "NP")
replace newvalue = 0.51*def_un + (1 - 0.51)*F.def_un ///
	if inlist(iso, "ET", "ET-FORMER")

egen hasnew = total(newvalue < .), by(id)
replace def_un = newvalue if (hasnew)
xtset, clear
drop id newvalue hasnew
keep if (def_un < .)

label data "Generated by import-un-deflator.do"
save "$work_data/un-deflator.dta", replace

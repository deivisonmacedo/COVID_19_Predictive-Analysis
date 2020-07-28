/* cas mysess; */
/* caslib _all_ assign; */

data wk00(replace=yes);
set covid.covid_acc;
if country not in ('Congo');
run;

proc sort data=wk00 out=wk01;
	by cycleday country;
run;

proc transpose data=wk01 out=wk02(replace=yes);
	by cycleday country;
	var cases deaths acc_cases acc_deaths
		pct_cases pct_deaths pct_acc_cases pct_acc_deaths
		rat_cases rat_deaths;
run;

proc transpose data=wk02 out=wk03(replace=yes) delim=_;
	by cycleday ;
	id _name_ country;
	var col1;
run;

libname sprecov '/sasdata/covid';
data sprecov.covid_acc_alt(replace=yes);
format FULLDATE yymmdd10.;
set wk03(drop=_name_);
fulldate = cycleday-1;
run;

proc casutil;
droptable incaslib=covid casdata='covid_acc_alt'
		  quiet;
load file="/sasdata/covid/covid_acc_alt.sas7bdat" 
	 outcaslib=covid casout="covid_acc_alt"
	 promote;
run;
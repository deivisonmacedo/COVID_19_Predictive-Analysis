cas mysess;
caslib _all_ assign;

/* define url to download */
%let dt = %sysfunc(date());
/* %let dt = %sysevalf(&dt.-1); */
%let dt = %sysfunc(putn(&dt., yymmdd10.));
%let url = "https://www.ecdc.europa.eu/sites/default/files/documents/COVID-19-geographic-disbtribution-worldwide-&dt..xlsx";
%put &url.;

filename covid temp;

proc http
	url=&url.
	method="GET"
	out=covid;
run;

/* import to the data into SAS */
options validvarname=any;
proc import 
	file=covid
	out=casuser.wk00 replace
	dbms=xlsx;
	*guessingrows=10000;
run;

/* save the data and load into CAS */
proc casutil;
droptable incaslib=covid casdata="covid"
		  quiet;
promote incaslib=casuser casdata="wk00"
		outcaslib=covid casout="covid";
save incaslib=covid casdata="covid"
	 outcaslib=covid casout="covid"
	 replace;
droptable incaslib=covid casdata="lookup_countries"
		  quiet;
load incaslib=covid casdata="LOOKUP_COUNTRIES.sashdat"
	 outcaslib=covid casout="lookup_countries"
	 promote;
droptable incaslib=covid casdata="pop"
		  quiet;
load incaslib=covid casdata="POP.sashdat"
	 outcaslib=covid casout="pop"
	 promote;
quit;

/* just the new obs of the table */
proc fedsql sessref=mysess;
select sum(1) from covid.covid;
select sum(1) from covid.lookup_countries;
select sum(1) from covid.pop;
quit;

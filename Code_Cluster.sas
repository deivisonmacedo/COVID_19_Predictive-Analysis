cas mysess;
caslib _all_ assign;

/*Create the growth rate variable and for this, you can use the table covid_acc3 created in "Code_incluir_sp_ciclos"*/
proc sort data=covid.covid_acc3 out=casuser.base_aux;
	by country cycleday;
run;

data casuser.base_aux;
	set casuser.base_aux;
	aux_lag=lag(acc_cases);

	taxa_cresc=(acc_cases/aux_lag)-1;

	if taxa_cresc=. then taxa_cresc=0;

	if cycleday=1 then taxa_cresc=0;
run; 

proc sort data=casuser.base_aux;
	by country cycleday;
run;

/*Create the aggregate variables (median of the growth rate, lethality rate and minimum and maximum cycle) for each country*/
proc fedsql sessref=mysess;
	create table casuser.base_aux2 {options replace=true} as select	
		country,
		mean(taxa_cresc) as media_cresc,
		min(cycleday) as min_ciclo,
		max(cycleday) as max_ciclo,
		max(acc_deaths) as max_deaths,
		max(acc_cases) as max_cases
	from casuser.base_aux
	group by country;
quit;

data casuser.base_aux2;
	set casuser.base_aux2;

	Taxa_letalidade=max_deaths/max_cases;
	Tempo_pandemia=max_ciclo-min_ciclo;

	keep country media_cresc Taxa_letalidade Tempo_pandemia;
run;

/*Save the table for SAS Visual Analytics*/
proc casutil;
	droptable incaslib=covid casdata="COVID_CLUSTER_VA2";
	promote incaslib=casuser casdata="base_aux2"
		outcaslib=covid casout="COVID_CLUSTER_VA2";
	save incaslib=covid casdata="COVID_CLUSTER_VA2"
		outcaslib=covid casout="COVID_CLUSTER_VA2"
		replace;
quit;

cas mysess;
caslib _all_ assign;

/*Here, it's necessary to obtain data about the population and confirmed cases and deaths for your state*/
/*Construir a base de São Paulo*/
/*Importar o csv do site do Ministério da Saúde - COVID_NUM_SP*/
proc fedsql sessref=mysess;
	create table casuser.CASOS_COVID_BRASIL {options replace=true} as select
		a.UF,
		a.Populacao,
		b.*
	from covid.COVID_CLUSTER_UF as a inner join covid.covid_uff as b
	on a.Estado=b.Estado;
quit;

/*Create the fields with new cases and deaths*/
data casuser.covid_sp;
	set casuser.casos_covid_brasil(where=(estado="SP"));
	if casosAcumulados=0 then delete;
run;

proc sort data=casuser.covid_sp;
	by casosAcumulados;
run;

data casuser.covid_sp;
	set casuser.covid_sp;
	caso_lag=lag(casosAcumulados);
	obitos_lag=lag(obitosAcumulados);

	casosNovos=casosAcumulados-caso_lag;
	obitosNovos=obitosAcumulados-obitos_lag;

	if casosNovos=. then casosNovos=casosAcumulados;
	if obitosNovos=. then obitosNovos=obitosAcumulados;
run;

/*Create the fields with cycle and percentage variables*/
data casuser.covid_sp2;
	set casuser.covid_sp;
	rename UF=COUNTRY;
	rename casosNovos=CASES;
	rename obitosNovos=DEATHS;
	rename casosAcumulados=acc_cases;
	rename obitosAcumulados=acc_deaths;

	CYCLEDAY=_n_;
	YEAR=year(data);
	MONTH=month(data);
	DAY=day(data);

	PCT_CASES=casosNovos/Populacao;
	PCT_DEATHS=obitosNovos/Populacao;
	PCT_ACC_CASES=casosAcumulados/Populacao;
	PCT_ACC_DEATHS=obitosAcumulados/Populacao;
run;

data casuser.covid_sp3;
	set casuser.covid_sp2;
	keep COUNTRY CYCLEDAY YEAR MONTH DAY CASES DEATHS ACC_CASES ACC_DEATHS PCT_CASES PCT_DEATHS PCT_ACC_CASES PCT_ACC_DEATHS;
run;

proc sort data=casuser.covid_sp3;
	by CYCLEDAY;
run;

/*Join São Paulo or your state with the other countries*/
data casuser.COVID_ACC3;
	set covid.COVID_ACC2;
	length COUNTRY2 $19;
	COUNTRY2=COUNTRY;
	drop COUNTRY;
	rename COUNTRY2=COUNTRY;
run;

data casuser.COVID_ACC3;
	set casuser.COVID_ACC3 casuser.covid_sp3;
run;

/*Save the table for SAS Visual Analytics*/
proc casutil;
	droptable incaslib=covid casdata="COVID_ACC3";
	promote incaslib=casuser casdata="COVID_ACC3"
		outcaslib=covid casout="COVID_ACC3";
	save incaslib=covid casdata="COVID_ACC3"
		outcaslib=covid casout="COVID_ACC3"
		replace;
quit;

	
cas mysess;
caslib _all_ assign;

/*You must obtain the Google data about mobility of people and GDP's informations*/
/*This code generates the scenario simulations with optimization*/
proc optmodel ;
var var_rec, trans, parq, work, mer_farm ;

min pib = 0.042759 - 0.074293*(0.300253 + 0.379567*(var_rec*trans) - 0.121650*parq - 0.091430*work) - 0.000813*135;

constraint 0.4=0.300253 + 0.379567*(var_rec*trans) - 0.121650*parq - 0.091430*work;
constraint  -0.949 <= var_rec <= 0.04 ; 
constraint  -0.858 <= trans <= 0.1083; 
constraint -0.331 <= mer_farm <= 0.0817; 
constraint -0.884 <= parq <= 0.1067; 
constraint -0.645 <= work <=0.135;

/*constraint pib =-0.0750*/;

solve;

print pib var_rec trans parq work mer_farm;
quit;



/*Join the simulations with health information*/
data casuser.scenariogrid_outputs;
	set covid.scenariogrid_outputs(where=(distancing_change=-0.1 and timestep=30));
	if distancing_initial in (0.4 0.5 0.6 0.7) then output;
run; 

proc transpose data=casuser.scenariogrid_outputs;
	by distancing_initial;
	var cases_30d cases_60d cases_90d cases_180d cases_270d cases_360d;
run;

data casuser.scenariogrid_outputs2;
	set work.data10;
	rename _NAME_=qtd_dias;
	rename col1=casos;
run;

proc fedsql sessref=mysess;
	create table casuser.teste {options replace=true} as select
	b.*,
	a.qtd_dias,
	a.casos
	from casuser.scenariogrid_outputs2 as a right join covid.base_cenarios as b
	on a.distancing_initial=b.isolamento;
quit;

proc casutil;
	droptable incaslib=covid casdata="base_cenarios_econ_saude";
	promote incaslib=casuser casdata="teste"
		outcaslib=covid casout="base_cenarios_econ_saude";
	save incaslib=covid casdata="base_cenarios_econ_saude"
		outcaslib=covid casout="base_cenarios_econ_saude"
		replace;
quit;
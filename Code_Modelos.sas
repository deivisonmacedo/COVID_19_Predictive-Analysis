cas mysess;
caslib _all_ assign;

/*Adjusting database fields*/
/*Before this step, import the updated data with the name BASE_FULL on the caslib covid*/

data casuser.base;
	set covid.BASE_FULL;
	Quarentena_16_CONV=put(Quarentena_16,1.);
	Notificacao=put(Efeito_not,1.);
	Shift_IC=put(Shift,1.);
	Shift_Mod2_EUA_CONV=put(Shift_Mod2_EUA,1.);
run;

data casuser.base;
	set casuser.base;
	drop Quarentena_16 Efeito_not Shift Shift_Mod2_EUA;
run; 

/*Splitting the training data: COVID_TRAIN (Modelo Itália), COVID_TRAIN2 (Modelo EUA 3), COVID_TRAIN3 (Modelo EUA 2), COVID_TRAIN4 (Modelo EUA 5) e COVID_TRAIN5 (Modelo EUA 6)*/
/*This is important when you have more models*/
data casuser.COVID_TRAIN casuser.COVID_TRAIN2 casuser.COVID_TRAIN3 casuser.COVID_TRAIN4 casuser.COVID_TRAIN5;
	set casuser.base;
	if DataBr <= "23Mar2020"d then output casuser.COVID_TRAIN;
	if DataBr <= "03Apr2020"d then output casuser.COVID_TRAIN2;
	if DataBr <= "03Apr2020"d then output casuser.COVID_TRAIN3;
	if (DataBr >= "16Apr2020"d and DataBr <= "30Apr2020"d) then output casuser.COVID_TRAIN4;
	if (DataBr >= "08May2020"d and DataBr <= "25May2020"d) then output casuser.COVID_TRAIN5; 
run;

/*Save your train data and use in any VDMML project*/
proc casutil;
	droptable incaslib=covid casdata="COVID_TRAIN";
	promote incaslib=casuser casdata="COVID_TRAIN"
		outcaslib=covid casout="COVID_TRAIN";
	save incaslib=covid casdata="COVID_TRAIN"
		outcaslib=covid casout="COVID_TRAIN"
		replace;
	droptable incaslib=covid casdata="COVID_TRAIN2";
	promote incaslib=casuser casdata="COVID_TRAIN2"
		outcaslib=covid casout="COVID_TRAIN2";
	save incaslib=covid casdata="COVID_TRAIN2"
		outcaslib=covid casout="COVID_TRAIN2"
		replace;
	droptable incaslib=covid casdata="COVID_TRAIN3";
	promote incaslib=casuser casdata="COVID_TRAIN3"
		outcaslib=covid casout="COVID_TRAIN3";
	save incaslib=covid casdata="COVID_TRAIN3"
		outcaslib=covid casout="COVID_TRAIN3"
		replace;
	droptable incaslib=covid casdata="COVID_TRAIN4";
	promote incaslib=casuser casdata="COVID_TRAIN4"
		outcaslib=covid casout="COVID_TRAIN4";
	save incaslib=covid casdata="COVID_TRAIN4"
		outcaslib=covid casout="COVID_TRAIN4"
		replace;
	promote incaslib=casuser casdata="COVID_TRAIN5"
		outcaslib=covid casout="COVID_TRAIN5";
	save incaslib=covid casdata="COVID_TRAIN5"
		outcaslib=covid casout="COVID_TRAIN5"
		replace;
quit;

/*Prepare the data for scoring on SAS Model Manager*/
proc casutil;
	droptable incaslib=covid casdata="COVID_TEST";
	promote incaslib=casuser casdata="BASE"
		outcaslib=covid casout="COVID_TEST";
	save incaslib=covid casdata="COVID_TEST"
		outcaslib=covid casdata="COVID_TEST"
		replace;
quit;

/*Prepare data for SAS Visual Analytics*/
/*Before step, it's necessary to change the names of the SAS Model Manager output tables, after scoring*/
/*From the using the Modelo EUA 5, don't run the parts below, that is, for your first model, don't run the parts below until the next comments*/
data casuser.Results_Modelo_Italia;
	set covid.Results_Modelo_Italia;
	if DataBr > "01Apr2020"d then do;
		P_CasosBr=(-402.324667)+(0.117007775*CasosIta);
	end;

	if DataBr >= "05Apr2020"d then delete;
run;

data casuser.Results_Modelo_EUA;
	set covid.Results_Modelo_EUA;
	if DataBr < "05Apr2020"d then delete;

	if DataBr >= "09Apr2020"d then delete;

	if (CasosEUA=. or CasosIta=.) then delete;
run;

data casuser.Results_Modelo_EUA_2;
	set covid.Results_Modelo_EUA_2;
	if DataBr < "09Apr2020"d then delete;

	if (CasosEUA=. or CasosIta=.) then delete;

	if DataBr >= "19Apr2020"d then delete;
run;

data casuser.Results_Modelo_EUA_2_IC;
	set covid.Results_Modelo_EUA_2_IC;
	if DataBr < "19Apr2020"d then delete;

	if (CasosEUA=. or CasosIta=.) then delete;
	
	P_CasosBr=(-71.45832617)+(0.071408418*CasosIta)+(0.053950805*CasosEUA)+(-856.2924225);
run;

data casuser.base2;
	set casuser.Results_Modelo_Italia
		casuser.Results_Modelo_EUA
		casuser.Results_Modelo_EUA_2
		casuser.Results_Modelo_EUA_2_IC;

	if P_CasosBr < 0 then P_CasosBr=0; 

	if DataBr < "05Apr2020"d then Sem_Quarentena=P_CasosBr+297.4768191;
	else if (DataBr >= "05Apr2020"d and DataBr < "09Apr2020"d) then Sem_Quarentena=P_CasosBr+413.4229179;
	else Sem_Quarentena=P_CasosBr+856.2924225;

	keep DataBr P_CasosBr Sem_Quarentena;
run;

proc fedsql sessref=mysess;
	create table casuser.Base_Final_VA {options replace=true} as 
	select a.*,
			b.P_CasosBr, 
			b.Sem_Quarentena
		from covid.COVID_TEST as a inner join casuser.base2 as b
		on a.DataBr=b.DataBr;
quit;

proc casutil;
	droptable incaslib=covid casdata="Base_Final_VA";
	promote incaslib=casuser casdata="Base_Final_VA"
		outcaslib=covid casout="Base_Final_VA";
	save incaslib=covid casdata="Base_Final_VA"
		outcaslib=covid casdata="Base_Final_VA"
		replace; 
quit;

/*A partir do uso do Modelo EUA 5 e Modelo EUA 6, executar as partes abaixo*/
/*To run the next steps, it's necessary to run the scoring and change the name of the SAS Model Manager scored table*/
/*data casuser.Results_Modelo_EUA_5;
	set covid.Results_modelo_EUA_5;
	if DataBr <= "25Apr2020"d then delete;
	if (CasosIta=. or CasosEUA=.) then delete;
	if DataBr >= "03May2020"d then P_CasosBr=P_CasosBr+2284.334109;
	if DataBr >= "07May2020"d then P_CasosBr=P_CasosBr+8111.413931;
run;*/

/*Do some adjustments in your data*/
data casuser.Results_Modelo_EUA_6;
	set covid.Results_Modelo_EUA_6;
	if DataBr <= "13May2020"d then delete;
	if DataBr >= "28May2020"d then P_CasosBr=P_CasosBr-8011.186614;
run;

data casuser.base_final_va;
	set covid.base_final_va;
	if DataBr >= "07May2020"d then CasosBr=135106;
	if DataBr >= "08May2020"d then CasosBr=145328;
	if DataBr >= "09May2020"d then CasosBr=155939;
	if DataBr >= "10May2020"d then CasosBr=162699;
	if DataBr >= "11May2020"d then CasosBr=168331;
	if DataBr >= "12May2020"d then CasosBr=177589;
	if DataBr >= "13May2020"d then CasosBr=188974;
run;

data casuser.base_final_va2;
	set casuser.base_final_va casuser.Results_Modelo_EUA_6;
	drop Sem_Quarentena;
run;

/*Save your data*/
proc casutil;
	droptable incaslib=covid casdata="Base_Final_VA";
	promote incaslib=casuser casdata="base_final_va2"
		outcaslib=covid casout="Base_Final_VA";
	save incaslib=covid casdata="Base_Final_VA"
		outcaslib=covid casdata="Base_Final_VA"
		replace; 
quit;


/*Social Isolation Simulation with Monte Carlo Simulation*/
/*Use the factor considering the % of social isolation obtained in the State of São Paulo, that is, in your state or country*/

proc delete data=casuser.simul_quar;
run;

data _null_;
 set covid.base_final_va end=eof;
 count+1;
 if eof then call symput('j',count);
run;

%MACRO simul_quar();

data casuser.simul_quar;
	a=1;
run;

%do n=1 %to 100;

	data casuser.aux_param;
		seed=rand('uniform',1,5000);
		call streaminit(seed);
		do i=1 to &j.;
			unif=rand('uniform');
			param=(-34513)*log(unif);
			output;
		end;
	run;

	proc sort data=casuser.aux_param out=casuser.aux_param;
		by param;
	run;

	data casuser.aux_param;
		set casuser.aux_param;
		i=_n_;
	run;

	data casuser.aux_curva;
		seed=rand('uniform',1,5000);
		call streaminit(seed);
		do i=1 to &j.;
			unif=rand('uniform');
			output;
		end;
	run;

	data casuser.aux_curva;
		set casuser.aux_curva;
		i=_n_;
	run;

	proc fedsql sessref=mysess;
		create table casuser.aux_all {options replace=true} as select
			a.i,
			a.param,
			b.unif
		from casuser.aux_param as a left join casuser.aux_curva as b
		on a.i=b.i;
	quit;

	data casuser.aux_all;
		set casuser.aux_all;
		curva_add=(-param)*log(unif);
		Simulacao=&n.;
	run;

	proc sort data=casuser.aux_all;
		by curva_add;
	run;

	data casuser.simul_quar;
		set casuser.simul_quar casuser.aux_all;
	run;

%end;

%MEND;
%simul_quar();

/*Obtain the maximum or average for your additional curve*/
proc fedsql sessref=mysess;
	create table casuser.simul_quar2 {options replace=true} as select
		a.i,
		max(a.curva_add) as curva_add
	from casuser.simul_quar as a
	where i > 0
	group by a.i;
quit;

proc sort data=casuser.simul_quar2;
	by curva_add;
run;

data casuser.simul_quar2;
	set casuser.simul_quar2;
	i=_n_;
run;

data casuser.teste;
	set covid.base_final_va;
	i=_n_;
run;

/*Join the tables with the index i*/
proc fedsql sessref=mysess;
	create table casuser.teste2 {options replace=true} as select
		a.*,
		b.curva_add
	from casuser.teste as a left join casuser.simul_quar2 as b
	on a.i=b.i;
quit;

/*Create the information "Sem_Quarentena", that is, the scenario without social isolation*/
data casuser.base_final_va;
	set casuser.teste2;
	if CasosEUA=. then delete;
	if DataBr >= "16Mar2020"d then do;
		Sem_Quarentena=P_CasosBr + curva_add;
	end;

	else Sem_Quarentena=P_CasosBr;

	drop i curva_add;
run;

/*Save your data for the report on SAS Visual Analytics*/
proc casutil;
	droptable incaslib=covid casdata="BASE_FINAL_VA";
	promote incaslib=casuser casdata="BASE_FINAL_VA"
		outcaslib=covid casout="BASE_FINAL_VA";
	save incaslib=covid casdata="BASE_FINAL_VA"
		outcaslib=covid casout="BASE_FINAL_VA"
		replace;
quit;

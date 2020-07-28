cas mysess;
caslib _all_ assign;

/*Dividir a base em Treinamento e Teste*/
data casuser.base_train_sp casuser.base_test_sp;
	set covid.base_projecao_sp;
	if DataBr <= '11Apr2020'd then output casuser.base_train_sp;
	else output casuser.base_test_sp;
run;

proc casutil;
	droptable incaslib=covid casdata="base_train_sp";
	promote incaslib=casuser casdata="base_train_sp"
		outcaslib=covid casout="base_train_sp";
	save incaslib=covid casdata="base_train_sp"
		outcaslib=covid casout="base_train_sp"
		replace;
	droptable incaslib=covid casdata="base_test_sp";
	promote incaslib=casuser casdata="base_test_sp"
		outcaslib=covid casout="base_test_sp";
	save incaslib=covid casdata="base_test_sp"
		outcaslib=covid casout="base_test_sp"
		replace;
quit;

/*Construir a base final para o VA*/
/*Antes dessa etapa é necessário alterar o nome da tabela de output do Model Manager*/
data casuser.base_train_sp;
	set covid.base_train_sp;
	P_CasosSP=.;
	if (CasosIta=. or CasosEUA=.) then delete;
run;

data casuser.base_escorada_sp;
	set covid.base_escorada_sp;
	if (CasosIta=. or CasosEUA=.) then delete;
run;

data casuser.base_final_sp_va;
	set casuser.base_train_sp
		casuser.base_escorada_sp;
run;


/*Calcular cenário sem isolamento social - considerar que São Paulo representa na média 42% dos casos desde
a adoção da quarentena, ou seja, com a ponderação de 856 (peso da quarentena) casos para o Brasil, São Paulo 
deve ter um aumento de 456 casos sem isolamento social*/
proc delete data=casuser.simul_quar;
run;

data _null_;
 set casuser.base_final_sp_va(where=(DataBr >= "16Mar2020"d)) end=eof;
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
			param=(-456)*log(unif);
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

proc fedsql sessref=mysess;
	create table casuser.simul_quar2 {options replace=true} as select
		a.i,
		max(a.curva_add) as max_curva_add,
		mean(a.curva_add) as mean_curva_add
	from casuser.simul_quar as a
	where i > 0
	group by a.i;
quit;

proc sort data=casuser.simul_quar2;
	by max_curva_add;
run;

data casuser.simul_quar2;
	set casuser.simul_quar2;
	i=_n_;
run;

data casuser.simul_quar3;
	set casuser.simul_quar2;
	if i < 28 then delete;
run;

data casuser.simul_quar3;
	set casuser.simul_quar3;
	j=_n_;
run;

data casuser.teste1 casuser.teste2;
	set casuser.base_final_sp_va;

	if P_CasosSP ne . then output casuser.teste1;
	else output casuser.teste2;
run;

data casuser.teste1;
	set casuser.teste1;
	i=_n_;
run;

data casuser.teste;
	set casuser.teste2
		casuser.teste1;
run;

proc fedsql sessref=mysess;
	create table casuser.teste2 {options replace=true} as select
		a.*,
		b.max_curva_add
	from casuser.teste as a left join casuser.simul_quar3 as b
	on a.i=b.j;
quit;

/*Ajuste de shift na curva de Casos*/
data casuser.teste2;
	set casuser.teste2;
	if DataBr >= "27Apr2020"d then P_CasosSP=P_CasosSP + 2000;
run;

data casuser.base_final_sp_va;
	set casuser.teste2;
	
	if DataBr < "16Mar2020"d then Sem_Quarentena=P_CasosSP;

	else Sem_Quarentena=P_CasosSP + max_curva_add;

	drop i j max_curva_add;
run;

proc casutil;
	droptable incaslib=covid casdata="base_final_sp_va";
	promote incaslib=casuser casdata="base_final_sp_va"
		outcaslib=covid casout="base_final_sp_va";
	save incaslib=covid casdata="base_final_sp_va"
		outcaslib=covid casout="base_final_sp_va"
		replace;
quit;


/*Preparar base para Modelo de Óbitos*/
data casuser.base_train_sp_obitos casuser.base_test_sp_obitos;
	set covid.base_projecao_sp_obitos;
	if Data <= "16Apr2020"d then output casuser.base_train_sp_obitos;
	else output casuser.base_test_sp_obitos;
run;

proc casutil;
	droptable incaslib=covid casdata="base_train_sp_obitos";
	promote incaslib=casuser casdata="base_train_sp_obitos"
		outcaslib=covid casout="base_train_sp_obitos";
	save incaslib=covid casdata="base_train_sp_obitos"
		outcaslib=covid casout="base_train_sp_obitos"
		replace;
	droptable incaslib=covid casdata="base_test_sp_obitos";
	promote incaslib=casuser casdata="base_test_sp_obitos"
		outcaslib=covid casout="base_test_sp_obitos";
	save incaslib=covid casdata="base_test_sp_obitos"
		outcaslib=covid casout="base_test_sp_obitos"
		replace;
quit;

/*Construir a base de escoragem*/
data casuser.base_test_sp_obitos;
	set covid.base_final_sp_va(where=(DataBr >= "12Apr2020"d));
	rename DataBr=Data;
	if DataBr > "27Apr2020"d then CasosSP=P_CasosSP;
	
	keep DataBr CasosSP Sem_Quarentena;
run; 

proc casutil;
	droptable incaslib=covid casdata="base_test_sp_obitos";
	promote incaslib=casuser casdata="base_test_sp_obitos"
		outcaslib=covid casout="base_test_sp_obitos";
	save incaslib=covid casdata="base_test_sp_obitos"
		outcaslib=covid casout="base_test_sp_obitos"
		replace;
quit;

/*Construir a base de óbitos final para o VA*/
/*Antes dessa etapa é necessário alterar o nome da base de output do Model Manager*/

data casuser.base_escorada_sp_obitos;
	set covid.base_escorada_sp_obitos;

	if Data >= "16Mar2020"d then Sem_Quarentena_Obitos=(-80.86222135) + 0.078234977*Sem_Quarentena;

	keep Data CasosSP P_ObitosSP Sem_Quarentena Sem_Quarentena_Obitos;
run;

/*Adicionar shift na curva de óbitos*/
data casuser.base_escorada_sp_obitos;
	set casuser.base_escorada_sp_obitos;
	if Data >= "28Apr2020"d then do;
		P_ObitosSP=P_ObitosSP+320;
		Sem_Quarentena_Obitos=Sem_Quarentena_Obitos+320;
	end;
run;

/*Montar a base final com projeções para Casos e Óbitos e respectivos cenários sem isolamento social*/
proc fedsql sessref=mysess;
	create table casuser.all_data {options replace=true} as select
		a.*,
		b.ObitosSP
	from covid.base_final_sp_va as a left join covid.base_projecao_sp_obitos as b
	on a.DataBr=b.Data;
quit;

data casuser.all_data;
	set casuser.all_data;
	if DataBr < "17Mar2020"d then ObitosSP=0;
	else if DataBr="17Mar2020"d then ObitosSP=1;
	else if DataBr="18Mar2020"d then ObitosSP=4;
	else if DataBr="19Mar2020"d then ObitosSP=4;
	else if DataBr="20Mar2020"d then ObitosSP=9;
	else if DataBr="21Mar2020"d then ObitosSP=15;
	else if DataBr="22Mar2020"d then ObitosSP=22;
	else if DataBr="23Mar2020"d then ObitosSP=30;
	else if DataBr="24Mar2020"d then ObitosSP=40;
	else if DataBr="25Mar2020"d then ObitosSP=48;
	else if DataBr="26Mar2020"d then ObitosSP=58;
	else if DataBr="27Mar2020"d then ObitosSP=68;
	else if DataBr="28Mar2020"d then ObitosSP=84;
	else if DataBr="29Mar2020"d then ObitosSP=98;
	else if DataBr="30Mar2020"d then ObitosSP=113;
run;

proc fedsql sessref=mysess;
	create table casuser.all_data {options replace=true} as select
		a.*,
		b.P_ObitosSP,
		b.Sem_Quarentena_Obitos
	from casuser.all_data as a left join casuser.base_escorada_sp_obitos as b
	on a.DataBr=b.Data;
quit;
	
proc casutil;
	droptable incaslib=covid casdata="base_final_sp_va";
	promote incaslib=casuser casdata="all_data"
		outcaslib=covid casout="base_final_sp_va";
	save incaslib=covid casdata="base_final_sp_va"
		outcaslib=covid casout="base_final_sp_va"
		replace;
quit;


/*Projetar para 4 semanas*/
/*Considerar a projeção da Mari do Forecast Server*/
/*Calcular óbitos*/
data casuser.forecast_sp;
	set covid.base_forecast_sp;
	rename Forecast_Casos=P_CasosSP;
	P_ObitosSP=(-80.86222135) + (0.078234977*Forecast_Casos);
run;

/*Simular Sem Quarentena*/
proc delete data=casuser.simul_quar;
run;

data _null_;
 set casuser.forecast_sp(where=(P_CasosSP ne .)) end=eof;
 count+1;
 if eof then call symput('j',count);
run;

%let j=%eval(&j. + 39);

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
			param=(-456)*log(unif);
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

proc fedsql sessref=mysess;
	create table casuser.simul_quar2 {options replace=true} as select
		a.i,
		max(a.curva_add) as max_curva_add,
		mean(a.curva_add) as mean_curva_add
	from casuser.simul_quar as a
	where i > 0
	group by a.i;
quit;

proc sort data=casuser.simul_quar2;
	by max_curva_add;
run;

data casuser.simul_quar2;
	set casuser.simul_quar2;
	i=_n_;
run;

data casuser.simul_quar3;
	set casuser.simul_quar2(where=(i >= 40));
	j=_n_;
run;

data casuser.forecast_sp;
	set casuser.forecast_sp;
	i=_n_;
run;

proc fedsql sessref=mysess;
	create table casuser.forecast_sp2 {options replace=true} as select
		a.*,
		b.max_curva_add
	from casuser.forecast_sp as a left join casuser.simul_quar3 as b
	on a.i=b.j;
quit;

data casuser.base_final_forecast_sp;
	set casuser.forecast_sp2;

	Sem_Quarentena=P_CasosSP + max_curva_add;
	Sem_Quarentena_Obitos=(-80.86222135) + (0.078234977*Sem_Quarentena);

	drop i j max_curva_add;
	rename P_CasosSP=FP_CasosSP;
	rename P_ObitosSP=FP_ObitosSP;
	rename Sem_Quarentena=FSem_Quarentena;
	rename Sem_Quarentena_Obitos=FSem_Quarentena_Obitos;
run;

/*Ajustar na mão a conexão das simulações e criar base final para o VA*/
data casuser.base_final_sp_va;
	set covid.base_final_sp_va casuser.base_final_forecast_sp(where=(DataBr > "04May2020"d));
run;

/*Ajustes finais*/
data casuser.base_final_sp_va2;
	set casuser.base_final_sp_va;
	if (DataBr >= "24Apr2020"d and DataBr <= "26Apr2020"d) then do;
		P_ObitosSP = P_ObitosSP + 110;
		Sem_Quarentena_Obitos = Sem_Quarentena_Obitos + 110;
	end;
	
	if DataBr >= "04May2020"d then do;
		FP_ObitosSP=FP_ObitosSP+320;
		FSem_Quarentena_Obitos=FSem_Quarentena_Obitos+320;
	end;
run;

proc casutil;
	droptable incaslib=covid casdata="base_final_sp_va";
	promote incaslib=casuser casdata="base_final_sp_va2"
		outcaslib=covid casout="base_final_sp_va";
	save incaslib=covid casdata="base_final_sp_va"
		outcaslib=covid casout="base_final_sp_va"
		replace;
quit;


/********************Atualização diária********************/
/*A partir do dia 29/04 de atualização, executar o código a partir daqui*/
/*Dividir a base em Treinamento e Teste para o Modelo 5*/

%let dt_inicio_proj=26Jun2020;
%let casos_anterior=248587;
%let obitos_anterior=13759;

data casuser.base_train_sp casuser.base_test_sp;
	set covid.base_projecao_sp;
	if (DataBr >= '20May2020'd and DataBr <= "04Jun2020"d) then output casuser.base_train_sp;
	if DataBr >= "27Apr2020"d then output casuser.base_test_sp;
run;

proc casutil;
	droptable incaslib=covid casdata="base_train_sp";
	promote incaslib=casuser casdata="base_train_sp"
		outcaslib=covid casout="base_train_sp";
	save incaslib=covid casdata="base_train_sp"
		outcaslib=covid casout="base_train_sp"
		replace;
	droptable incaslib=covid casdata="base_test_sp";
	promote incaslib=casuser casdata="base_test_sp"
		outcaslib=covid casout="base_test_sp";
	save incaslib=covid casdata="base_test_sp"
		outcaslib=covid casout="base_test_sp"
		replace;
quit;

/*Ajustar a base escorada*/
/*Antes dessa etapa, mudar o nome da base escorada do Model Manager ou executar a escoragem direto no código, como está feito abaixo (Modelo 5)*/
/*Antigo Modelo 3*/
/*data casuser.base_escorada_sp;
	set covid.base_test_sp;
	P_CasosSP=(20922.50404) + (-0.259194057*CasosIta) + (0.052464928*CasosEUA) + (7.53836E-09*CasosEUA_2);
run;*/

/*Antigo Modelo 5*/
/*data casuser.base_escorada_sp;
	set covid.base_test_sp;
	P_CasosSP=(3921.035496) + (3.05662E-08*CasosEUA_2) + (3985.355999) + (1927.015799);
run;*/

/*Atualizando com o novo Modelo 7*/
data casuser.base_escorada_sp;
	set covid.base_test_sp;
	P_CasosSP=(-252742.9538) + (0.219766349*CasosEUA) + (6359.855222) + (7348.12708);
run;


/*Antigo Modelo 3*/
/*data casuser.base_escorada_sp;
	set casuser.base_escorada_sp(where=(DataBr >= "&dt_inicio_proj."d));
	if DataBr >= "&dt_inicio_proj."d then P_CasosSP=P_CasosSP + 1972.155132 + 890.7858545 + 2712.513858 + 1299.754416 + 1647.051129;
	if (CasosIta=. or CasosEUA=.) then delete;
	drop G H I J K L;
run;*/

/*Atualizando com o novo Modelo 5*/
data casuser.base_escorada_sp;
	set casuser.base_escorada_sp(where=(DataBr >= "&dt_inicio_proj."d));
	if (CasosIta=. or CasosEUA=.) then delete;
	drop G H I J K L;
run;

/*Simular quarentena para casos*/
/*Calcular cenário de isolamento social - considerar o fator de crescimento de 8887 casos por dia,
baseado nas taxas de isolamento divulgadas pelo governo*/
proc delete data=casuser.simul_quar;
run;

data _null_;
 set covid.base_final_sp_va(where=(DataBr >= "16Mar2020"d and DataBr < "&dt_inicio_proj."d)) end=eof;
 count+1;
 if eof then call symput('j',count);
run;

%let j=%eval(&j. + 32);

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
			param=(-8887)*log(unif);
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

proc fedsql sessref=mysess;
	create table casuser.simul_quar2 {options replace=true} as select
		a.i,
		max(a.curva_add) as max_curva_add,
		mean(a.curva_add) as mean_curva_add
	from casuser.simul_quar as a
	where i > 0
	group by a.i;
quit;

proc sort data=casuser.simul_quar2;
	by max_curva_add;
run;

data casuser.simul_quar2;
	set casuser.simul_quar2;
	i=_n_;
run;

/*Calcular óbitos com fator de ajuste - Modelo Óbito 3*/
data casuser.base_escorada_sp_obitos;
	set casuser.base_escorada_sp;
	P_ObitosSP=(2231.626909) + (0.049073206*P_CasosSP) + (-109) + (-50) + (-380) + (-227.6859052);
run;

/*Acrescentar o forecast da Mari - Importar a planilha da Mari*/
data casuser.base_forecast_sp;
	set covid.base_forecast_sp;
	if (DataBr >= ("&dt_inicio_proj."d + 7) and DataBr <= ("&dt_inicio_proj."d + 31)) then output;
	rename Forecast_Casos=P_CasosSP;
run;

/*Aplicar Modelo Óbito 2*/
data casuser.base_escorada_sp_obitos2;
	set casuser.base_escorada_sp_obitos casuser.base_forecast_sp;
	keep DataBr CasosSP CasosIta CasosEUA CasosEUA_2 P_CasosSP P_ObitosSP;
	P_ObitosSP=(2231.626909) + (0.049073206*P_CasosSP) + (-109) + (-50) + (-380) + (-227.6859052);
run;

/*Agregar curva de Isolamento Social já simulada*/
data casuser.base_final_sp_va;
	set covid.base_final_sp_va(where=(DataBr >= "16Mar2020"d and DataBr < "&dt_inicio_proj."d)) casuser.base_escorada_sp_obitos2;
	if DataBr=("&dt_inicio_proj."d - 1)  then CasosSP=&casos_anterior.;
	if DataBr=("&dt_inicio_proj."d - 1) then ObitosSP=&obitos_anterior.;

	i=_n_;

	drop max_curva_add;
run;

proc fedsql sessref=mysess;
	create table casuser.base_final_sp_va2 {options replace=true} as select
	a.*,
	b.max_curva_add
	from casuser.base_final_sp_va as a left join casuser.simul_quar2 as b 
	on a.i=b.i;
quit;

/*Aplica Modelo Óbitos 2*/
data casuser.base_final_sp_va3;
	set casuser.base_final_sp_va2;
	if DataBr >= "&dt_inicio_proj."d then do;
		Sem_Quarentena=P_CasosSP + max_curva_add;
		Sem_Quarentena_Obitos=(2231.626909) + (0.049073206*Sem_Quarentena) + (-109) + (-50) + (-380) + (-227.6859052);
	end;
run;

/*Ajuste final - quando necessário nos valores do cenário sem quarentena*/
data casuser.base_final_sp_va3;
	set casuser.base_final_sp_va3;
	if DataBr = "09Jun2020"d then do;
		P_CasosSP=151879.2012;
		P_ObitosSP=9526.148525;
		CasosSP=150138;
		ObitosSP=9522;
		Sem_Quarentena=P_CasosSP+max_curva_add;
		Sem_Quarentena_Obitos=(2231.626909) + (0.049073206*Sem_Quarentena) + (-109) + (-50) + (-380) + (-227.6859052);
	end;
	if DataBr = "10Jun2020"d then do;
		P_CasosSP=156240.9039;
		P_ObitosSP=9740.191261;
		CasosSP=156316;
		ObitosSP=9862;
		Sem_Quarentena=P_CasosSP+max_curva_add;
		Sem_Quarentena_Obitos=(2231.626909) + (0.049073206*Sem_Quarentena) + (-109) + (-50) + (-380) + (-227.6859052);
	end;
	if DataBr = "11Jun2020"d then do;
		P_CasosSP=160906.3238;
		P_ObitosSP=9969.138369;
		CasosSP=162520;
		ObitosSP=10145;
		Sem_Quarentena=P_CasosSP+max_curva_add;
		Sem_Quarentena_Obitos=(2231.626909) + (0.049073206*Sem_Quarentena) + (-109) + (-50) + (-380) + (-227.6859052);
	end;
	if DataBr = "12Jun2020"d then do;
		P_CasosSP=169871.9118;
		P_ObitosSP=10409.10851;
		CasosSP=167900;
		ObitosSP=10368;
		Sem_Quarentena=P_CasosSP+max_curva_add;
		Sem_Quarentena_Obitos=(2231.626909) + (0.049073206*Sem_Quarentena) + (-109) + (-50) + (-380) + (-227.6859052);
	end;
	if DataBr = "13Jun2020"d then do;
		P_CasosSP=174736.4399;
		P_ObitosSP=10647.82651;
		CasosSP=172875;
		ObitosSP=10581;
		Sem_Quarentena=P_CasosSP+max_curva_add;
		Sem_Quarentena_Obitos=(2231.626909) + (0.049073206*Sem_Quarentena) + (-109) + (-50) + (-380) + (-227.6859052);
	end;
	if DataBr = "14Jun2020"d then do;
		P_CasosSP=178856.3997;
		P_ObitosSP=10850.00614;
		CasosSP=178202;
		ObitosSP=10694;
		Sem_Quarentena=P_CasosSP+max_curva_add;
		Sem_Quarentena_Obitos=(2231.626909) + (0.049073206*Sem_Quarentena) + (-109) + (-50) + (-380) + (-227.6859052);
	end;
	if DataBr = "15Jun2020"d then do;
		P_CasosSP=182949;
		P_ObitosSP=10670.82691;
		CasosSP=181460;
		ObitosSP=10767;
		Sem_Quarentena=P_CasosSP+max_curva_add;
		Sem_Quarentena_Obitos=(2231.626909) + (0.049073206*Sem_Quarentena) + (-109) + (-50) + (-380) + (-227.6859052);
	end;
	if DataBr = "16Jun2020"d then do;
		P_CasosSP=187030;
		P_ObitosSP=10871.10845;
		CasosSP=190285;
		ObitosSP=11132;
		Sem_Quarentena=P_CasosSP+max_curva_add;
		Sem_Quarentena_Obitos=(2231.626909) + (0.049073206*Sem_Quarentena) + (-109) + (-50) + (-380) + (-227.6859052);
	end;
	if DataBr = "17Jun2020"d then do;
		P_CasosSP=192883;
		P_ObitosSP=11158.35731;
		CasosSP=191517;
		ObitosSP=11521;
		Sem_Quarentena=P_CasosSP+max_curva_add;
		Sem_Quarentena_Obitos=(2231.626909) + (0.049073206*Sem_Quarentena) + (-109) + (-50) + (-380) + (-227.6859052);
	end;
	if DataBr = "18Jun2020"d then do;
		P_CasosSP=197859;
		P_ObitosSP=11402.52155;
		CasosSP=192628;
		ObitosSP=11846;
		Sem_Quarentena=P_CasosSP+max_curva_add;
		Sem_Quarentena_Obitos=(2231.626909) + (0.049073206*Sem_Quarentena) + (-109) + (-50) + (-380) + (-227.6859052);
	end;
	if DataBr = "19Jun2020"d then do;
		P_CasosSP=203530;
		P_ObitosSP=11680.82995;
		CasosSP=211658;
		ObitosSP=12232;
		Sem_Quarentena=P_CasosSP+max_curva_add;
		Sem_Quarentena_Obitos=(2231.626909) + (0.049073206*Sem_Quarentena) + (-109) + (-50) + (-380) + (-227.6859052);
	end;
	if DataBr = "20Jun2020"d then do;
		P_CasosSP=209118;
		P_ObitosSP=11955.06176;
		CasosSP=215793;
		ObitosSP=12494;
		Sem_Quarentena=P_CasosSP+max_curva_add;
		Sem_Quarentena_Obitos=(2231.626909) + (0.049073206*Sem_Quarentena) + (-109) + (-50) + (-380) + (-227.6859052);
	end;
	if DataBr = "21Jun2020"d then do;
		P_CasosSP=213295;
		P_ObitosSP=12160.03461;
		CasosSP=219185;
		ObitosSP=12588;
		Sem_Quarentena=P_CasosSP+max_curva_add;
		Sem_Quarentena_Obitos=(2231.626909) + (0.049073206*Sem_Quarentena) + (-109) + (-50) + (-380) + (-227.6859052);
	end;
	if DataBr = "22Jun2020"d then do;
		P_CasosSP=217586.4827;
		P_ObitosSP=12370.61548;
		CasosSP=221973;
		ObitosSP=12634;
		Sem_Quarentena=P_CasosSP+max_curva_add;
		Sem_Quarentena_Obitos=(2231.626909) + (0.049073206*Sem_Quarentena) + (-109) + (-50) + (-380) + (-227.6859052);
	end;
	if DataBr = "23Jun2020"d then do;
		P_CasosSP=223115.1448;
		P_ObitosSP=12641.92465;
		CasosSP=229475;
		ObitosSP=13068;
		Sem_Quarentena=P_CasosSP+max_curva_add;
		Sem_Quarentena_Obitos=(2231.626909) + (0.049073206*Sem_Quarentena) + (-109) + (-50) + (-380) + (-227.6859052);
	end;
	if DataBr = "24Jun2020"d then do;
		P_CasosSP=234088.555;
		P_ObitosSP=13180.42507;
		CasosSP=238822;
		ObitosSP=13352;
		Sem_Quarentena=P_CasosSP+max_curva_add;
		Sem_Quarentena_Obitos=(2231.626909) + (0.049073206*Sem_Quarentena) + (-109) + (-50) + (-380) + (-227.6859052);
	end;
	if DataBr = "25Jun2020"d then do;
		P_CasosSP=241238.8729;
		P_ObitosSP=13531.31409;
		CasosSP=248587;
		ObitosSP=13759;
		Sem_Quarentena=P_CasosSP+max_curva_add;
		Sem_Quarentena_Obitos=(2231.626909) + (0.049073206*Sem_Quarentena) + (-109) + (-50) + (-380) + (-227.6859052);
	end;
run;

proc casutil;
	droptable incaslib=covid casdata="base_final_sp_va";
	promote incaslib=casuser casdata="base_final_sp_va3"
		outcaslib=covid casout="base_final_sp_va";
	save incaslib=covid casdata="base_final_sp_va"
		outcaslib=covid casout="base_final_sp_va"
		replace;
quit;




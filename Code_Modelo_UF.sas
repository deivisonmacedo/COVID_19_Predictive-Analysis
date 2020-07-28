cas mysess;
caslib _all_ assign;

/*Construir a base de estados*/
/*Importar o csv do site do Ministério da Saúde - COVID_NUM_SP*/
/*Use the data with some informations like population, confirmed cases and deaths for states*/
proc fedsql sessref=mysess;
	create table casuser.CASOS_COVID_BRASIL {options replace=true} as select
		a.UF,
		a.Populacao,
		b.*
	from covid.COVID_CLUSTER_UF as a inner join covid.covid_uff_livia as b
	on a.estado=b.Estado;
quit;

data casuser.covid_estados;
	set casuser.casos_covid_brasil;
	if casosAcumulados=0 then delete;
run;

proc sort data=casuser.covid_estados;
	by estado descending casosAcumulados;
run;

/*Create incidence and lethality rates, both updated information (the last day)*/
/*Criar variáveis de Taxa de Incidência e Taxa de Letalidade, ambas informações atualizadas (último dia)*/
data casuser.base_teste;
	set casuser.covid_estados;
	Incidencia=novos_casos/Populacao;
	Letalidade=obitosAcumulados/casosAcumulados;
run;

data casuser.base_teste2;
	set casuser.base_teste;
	by estado descending casosAcumulados;
	retain count;
	if first.estado then count=1;
	else count=count+1;
run;

data casuser.base_teste3;
	set casuser.base_teste2;
	if count ne 1 then delete;
run;

/*Save the data*/
proc casutil;
	droptable incaslib=covid casdata="COVID_CLUSTER_UF";
	promote incaslib=casuser casdata="BASE_TESTE3"
		outcaslib=covid casout="COVID_CLUSTER_UF";
	save incaslib=covid casdata="COVID_CLUSTER_UF"
		outcaslib=covid casout="COVID_CLUSTER_UF"
		replace;
quit;

/*Now, calculate the cluster analysis with your data*/
/****************************************************************************/
/* Unsupervised Learning: Cluster Analysis                                  */
/****************************************************************************/
proc kclus data=covid.covid_cluster_uf standardize=STD impute=MEAN 
        distance=EUCLIDEAN maxiters=50 maxclusters=6;
	input Incidencia Letalidade;
	score out=casuser.results copyvars=(_all_);
	ods output clustersum=clus_clustersum;
run;

/****************************************************************************/
/* Visualize the results using a clustering plot for segment frequency      */
/****************************************************************************/
data clus_clustersum;
    set clus_clustersum;
	clusterLabel = catx(' ', 'Cluster', cluster);
run;

proc template;
    define statgraph simplepie;
	begingraph;
		entrytitle "Segment Frequency";
		layout region;
		piechart category=clusterLabel response=frequency;
		endlayout;
	endgraph;
    end;
run;

proc sgrender data=clus_clustersum template=simplepie;
run;

/****************************************************************************/
/* Visualize the results by identifying clusters in a PCA plot              */
/****************************************************************************/
proc sgplot data=casuser.results(keep=Incidencia Letalidade _cluster_id_);
	title "Identify Clusters in a PCA Plot";
	scatter x=Incidencia y=Letalidade / group=_cluster_id_;
run;
title;

/*Save the results for SAS Visual Analytics*/
proc casutil;
	droptable incaslib=covid casdata="COVID_CLUSTER_UF_RESULTS";
	promote incaslib=casuser casdata="RESULTS"
		outcaslib=covid casout="COVID_CLUSTER_UF_RESULTS";
	save incaslib=covid casdata="COVID_CLUSTER_UF_RESULTS"
		outcaslib=covid casout="COVID_CLUSTER_UF_RESULTS"
		replace;
quit;	
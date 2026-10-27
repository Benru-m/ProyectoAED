\NeedsTeXFormat{LaTeX2e}
\ProvidesClass{mdpi}[2026/10/27 MDPI dummy class to fix all rticles errors]

\LoadClass[10pt,a4paper]{article}

% 1. PAQUETES ESENCIALES PARA RMARKDOWN Y PANDOC
\RequirePackage{geometry}
\geometry{a4paper, margin=1in}
\RequirePackage{enumitem} % <-- Soluciona el error \setlist
\RequirePackage{longtable} % Para tablas generadas con kable
\RequirePackage{booktabs}
\RequirePackage{array}
\RequirePackage{multirow}
\RequirePackage{wrapfig}
\RequirePackage{colortbl}
\RequirePackage{pdflscape}
\RequirePackage{tabu}
\RequirePackage{threeparttable}
\RequirePackage{threeparttablex}
\RequirePackage[normalem]{ulem}
\RequirePackage{makecell}
\RequirePackage{xcolor}
\RequirePackage{float}
\RequirePackage{graphicx}
\RequirePackage{amsmath, amsfonts, amssymb}
\RequirePackage{hyperref}
\RequirePackage{authblk}
\RequirePackage{fancyhdr}
\RequirePackage{etoolbox}

% 2. PREVENCIÓN DE CONFLICTOS NATIVOS DE LA CLASE ARTICLE
\let\abstract\relax
\let\endabstract\relax
\let\corres\relax

% 3. COMANDOS ESPECÍFICOS DE MDPI 
% (Definidos para que Pandoc no lance "Undefined control sequence")
\newcommand{\firstpage}[1]{\gdef\@firstpage{#1}}
\newcommand{\lastpage}[1]{\gdef\@lastpage{#1}}
\newcommand{\authorid}[1]{\gdef\@authorid{#1}}
\newcommand{\LN}[1]{\gdef\@LN{#1}}
\newcommand{\journal}[1]{\gdef\@journal{#1}}
\newcommand{\volume}[1]{\gdef\@volume{#1}}
\newcommand{\issuenum}[1]{\gdef\@issuenum{#1}}
\newcommand{\articletype}[1]{\gdef\@articletype{#1}}
\newcommand{\pubyear}[1]{\gdef\@pubyear{#1}}
\newcommand{\copyrightyear}[1]{\gdef\@copyrightyear{#1}}
\newcommand{\externaleditor}[1]{\gdef\@externaleditor{#1}}
\newcommand{\history}[1]{\gdef\@history{#1}}
\newcommand{\datereceived}[1]{}
\newcommand{\dateaccepted}[1]{}
\newcommand{\datepublished}[1]{}
\newcommand{\dateupdated}[1]{}

\newcommand{\Title}[1]{\title{#1}}
\newcommand{\TitleAnnotation}[1]{}
\newcommand{\Author}[1]{\author{#1}}
\newcommand{\AuthorNames}[1]{}
\newcommand{\AuthorCitation}[1]{}
\newcommand{\address}[1]{}
\newcommand{\firstnote}[1]{}
\newcommand{\secondnote}[1]{}
\newcommand{\thirdnote}[1]{}

\newcommand{\simplesummary}[1]{}
\newcommand{\abstract}[1]{}
\newcommand{\keyword}[1]{}

\newcommand{\funding}[1]{}
\newcommand{\acknowledgments}[1]{}
\newcommand{\conflictsofinterest}[1]{}
\newcommand{\authorcontributions}[1]{}
\newcommand{\dataavailability}[1]{}
\newcommand{\sampleavailability}[1]{}
\newcommand{\institutionalreview}[1]{}
\newcommand{\informedconsent}[1]{}
\newcommand{\dataset}[1]{}
\newcommand{\datasetlicense}[1]{}

% FORMATO DE CABECERA Y PIE DE PÁGINA
\pagestyle{fancy}
\fancyhf{}
\fancyhead[C]{Proyecto AED - Análisis Exploratorio de Datos}
\fancyfoot[C]{\thepage}

\endinput
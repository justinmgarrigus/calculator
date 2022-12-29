%{

#include <stdlib.h>
#include <stdio.h>  
#include <string.h> 
#include "y.tab.h"

%} 
%%

[a-z] {
    yylval.name = strdup(yytext);
    return IDENTIFIER; 
}

[0-9]+ {
    yylval.num = atoi(yytext); 
    return NUMBER; 
}

[-+*/] { return *yytext; } 
[()]   { return *yytext; }
[\n]   { return *yytext; } 
[=]    { return *yytext; } 

[ \t] ; 

. { 
    printf("Unknown literal: '%c' (%d)\n", yytext[0], yytext[0]);
    return yytext[0]; 
}

%%
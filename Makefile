all:
	yacc -d src/calc.y 
	lex src/calc.l 
	gcc y.tab.c lex.yy.c

clean: 
	rm -f y.tab.c 
	rm -f y.tab.h
	rm -f lex.yy.c 	
	rm -f a.out 

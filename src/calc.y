%{

#include <stdio.h> 
#include <stdlib.h>
#include <string.h> 
#include <assert.h> 
#include "y.tab.h"

#define BUFFER_START_SIZE 8

int yylex(); 
int yyerror(char* s); 

enum expression_type {
    expression_type_number, 
    expression_type_identifier, 
    expression_type_op
}; 

union expression_value {
    int number; 
    char *name; 
    char op; 
};

struct expression {
    union expression_value val; 
    enum expression_type type; 
};

/*
struct buffer: A buffer meant to store a collection of items, with the ability 
    to be resized once the capacity is reached. 
<data>: The data stored within the buffer itself. 
<capacity>: The number of elements the buffer could possibly store before
    being completely full. 
<length>: The number of elements currently stored within the buffer. 
*/
struct buffer {
    void **data; 
    int capacity; 
    int length; 
}; 

struct buffer* buffer_create(int initial_capacity) {
    struct buffer *buffer = malloc(sizeof(struct buffer)); 
    buffer->data = malloc(sizeof(void*) * initial_capacity); 
    buffer->capacity = initial_capacity; 
    buffer->length = 0; 
}

void buffer_insert(struct buffer* buffer, void* item) {
    if (buffer->length == buffer->capacity) {
        buffer->capacity *= 2; 
        buffer->data = realloc(buffer->data, sizeof(void*) * buffer->capacity); 
    }
    buffer->data[buffer->length++] = item;  
}

struct buffer *expression_buffer;
struct buffer *statement_buffer;

struct var {
    char *name; 
    int value;
};

int symboltable_indexof(struct buffer* table, char* name) {
    for (int i = 0; i < table->length; i++) {
        struct var *v = table->data[i]; 
        if (strcmp(v->name, name) == 0)
            return i;
    }
    return -1; 
}

struct buffer *symbol_table; // Collection of struct var pointers

%}

%union {
    int num; 
    char *name; 
}

%token IDENTIFIER 
%token NUMBER

%left '+' '-' 
%left '*' '/'

%% 

program: 
    linelist
  | ; 

linelist: 
    expression {  
        buffer_insert(statement_buffer, expression_buffer); 
        expression_buffer = buffer_create(BUFFER_START_SIZE); 
    }
  | line linelist
  | line 
  ;

line: 
    expression '\n' { 
        buffer_insert(statement_buffer, expression_buffer); 
        expression_buffer = buffer_create(BUFFER_START_SIZE); 
    }
  | IDENTIFIER '=' NUMBER { 
        int index = symboltable_indexof(symbol_table, $<name>1);
        if (index == -1) {
            struct var *v = malloc(sizeof(struct var)); 
            v->name = malloc(strlen($<name>1) + 1); 
            strcpy(v->name, $<name>1); 
            v->value = $<num>3; 
            buffer_insert(symbol_table, v); 
        }
        else {
            struct var *v = symbol_table->data[index]; 
            v->value = $<num>3; 
        }
    }
  | '\n'
  ;

expression: 
    NUMBER {
        struct expression *ex = malloc(sizeof(struct expression));
        ex->val.number = $<num>1; 
        ex->type = expression_type_number; 
        
        buffer_insert(expression_buffer, ex); 
    }
  | IDENTIFIER {
        struct expression *ex = malloc(sizeof(struct expression));
        char *name = malloc(strlen($<name>1) + 1);
        strcpy(name, $<name>1);
        ex->val.name = name; 
        ex->type = expression_type_identifier; 
        
        buffer_insert(expression_buffer, ex); 
    }
  | expression '+' expression { 
        struct expression *ex = malloc(sizeof(struct expression)); 
        ex->val.op = '+'; 
        ex->type = expression_type_op; 
        
        buffer_insert(expression_buffer, ex); 
    }
  | expression '-' expression { 
        struct expression *ex = malloc(sizeof(struct expression)); 
        ex->val.op = '-'; 
        ex->type = expression_type_op; 
        
        buffer_insert(expression_buffer, ex); 
    }
  | expression '*' expression { 
        struct expression *ex = malloc(sizeof(struct expression)); 
        ex->val.op = '*'; 
        ex->type = expression_type_op; 
        
        buffer_insert(expression_buffer, ex); 
    }
  | expression '/' expression { 
        struct expression *ex = malloc(sizeof(struct expression)); 
        ex->val.op = '/'; 
        ex->type = expression_type_op; 
        
        buffer_insert(expression_buffer, ex); 
    }
  | '(' expression ')'
  ;
  
%% 

int main() {
    expression_buffer = buffer_create(BUFFER_START_SIZE); 
    statement_buffer = buffer_create(BUFFER_START_SIZE); 
    symbol_table = buffer_create(BUFFER_START_SIZE); 
    
    // Goal of yyparse: to generate a list of statements to execute. 
    int result = yyparse(); 
    
    if (result == 0) {
        // Find the longest expression 
        int longest_length = 0; 
        for (int s = 0; s < statement_buffer->length; s++) {
            struct buffer *exp = statement_buffer->data[s]; 
            if (exp->length > longest_length) 
                longest_length = exp->length; 
        }
        
        // Calculate the result of the expression (stored in postfix notation) 
        int *stack = malloc(sizeof(int) * longest_length); 
        int stack_index = 0; 
        for (int s = 0; s < statement_buffer->length; s++) {
            struct buffer *statement = statement_buffer->data[s];
            int index = 0; 
            for (int index = 0; index < statement->length; index++) {
                struct expression *exp = statement->data[index]; 
                if (exp->type == expression_type_number)
                    stack[stack_index++] = exp->val.number;
                else if (exp->type == expression_type_identifier) {
                    char *name = exp->val.name; 
                    int var_index = symboltable_indexof(symbol_table, name); 
                    if (var_index == -1) {
                        fprintf(
                            stderr, 
                            "Error: var %s does not exist!\n", 
                            name
                        );
                        exit(1); 
                    }
                    
                    struct var *v = symbol_table->data[var_index]; 
                    stack[stack_index++] = v->value; 
                }                
                else if (exp->type == expression_type_op) {
                    int op_right = stack[--stack_index]; 
                    int op_left  = stack[--stack_index]; 
                    int op_result; 
                    switch (exp->val.op) {
                        case '+': 
                            op_result = op_left + op_right; 
                            break; 
                        
                        case '-': 
                            op_result = op_left - op_right; 
                            break; 
                        
                        case '*': 
                            op_result = op_left * op_right; 
                            break; 
                        
                        case '/': 
                            op_result = op_left / op_right; 
                            break; 
                        
                        default:
                            fprintf(
                                stderr, 
                                "Expression corrupted! Unknown operator: %d\n", 
                                exp->val.op
                            ); 
                            exit(1); 
                    }
                    
                    stack[stack_index++] = op_result; 
                }
                else {
                    fprintf(
                        stderr, 
                        "Expression corrupted! Value type found: %d\n", 
                        exp->type
                    );
                    exit(1); 
                }
            }
            
            assert(stack_index == 1); 
            
            printf("= %d\n", stack[0]); 
            stack_index = 0;
        }
    }
    
    return result; 
}

int yyerror(char* s) {
    fprintf(stderr, "Error: %s\n", s); 
    return 1; 
}

int yywrap() {
    return 1; 
}
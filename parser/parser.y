%{
    #include "IdTable.h"
    #include "string.h"
    int success = 1;
    IdTable it;

    std::string nowConst = "";
%}

%code requires {
    /**
     * debug level:
     * 000 no debug
     * 001 error
     * 010 warning
     * 100 info
     * example : debug = 7, error + warning + info
     */


    #define ACC 1
    #include <iostream>
    #include <stdio.h>
    #include <stdlib.h>
    #include <stddef.h>
    #include "IdType.h"
    #include "debug.h"

    #define INFO(args...) do {char msg[1024]; sprintf(msg, ##args); info(__FILE__, __LINE__, msg);} while(0)
    #define WARN(args...) do {char msg[1024]; sprintf(msg, ##args); warn(__FILE__, __LINE__, msg);} while(0)
    #define ERR(args...) do {char msg[1024]; sprintf(msg, ##args); err(__FILE__, __LINE__, msg);} while(0)

    extern int yylex();
    int yyerror(const char *s);
    using namespace std;

    typedef struct info{
        TYPE type;

        /*
         * will raise error if set default to false
         * TODO: WHY?
         */
        bool is_const;

        /* array */
        int dim;
        period *prd;
        TYPE element_type;
    }info;

    typedef struct parameter{
        string name;
        bool is_var = false;
        TYPE type = _DEFAULT;
        parameter *next = nullptr;
        string text = "test";
    }parameter;

    void insert_symbol(string name, info t);
    void insert_procedure(string name, parameter *par);
    void insert_function(string name, parameter *par, TYPE rt);
    void par_append(parameter *p, string name, bool is_var = false);

    int get_first_digit(const string &s);
    int get_last_digit(const string &s);
#if DEBUG
    void print_par_list(parameter *p);
    void print_block_info(bool is_func, TYPE ret_type, parameter *p);
#endif
    TYPE get_type(char *s);
    TYPE cmp_type(TYPE t1, TYPE t2);
    int get_mulop_type(string *s);
    TYPE get_fun_type(string name);
    std::vector<Parameter> get_par_list(string id);
    parameter* get_id_info(string name);

// target code generation funciton start
    void wf(const char *s);
    void wf(const string &s);
    void wf(TYPE t);
    template<class T, class ...Args>
    void wf(T head, Args ...rest);

    string convert_relop(string s);
    string convert_type(TYPE t);
    string convert_type_printf(TYPE t);
// target code generation function end
}

%union
{
    info symbol_info;
    period prd;
    string *text;
    parameter *par = nullptr;
    char *num;
    char letter;
    string *addop;
    string *mulop;

}

%left PLUS ADDOP MULOP

%start programstruct
%token PROGRAM
%token CONST VAR
%token PROCEDURE FUNCTION
%token _BEGIN END ASSIGNOP IF THEN ELSE FOR TO DO NOT
%token READ WRITE ARRAY OF

%token <text> ID MULOP ADDOP PLUS UMINUS RELOP EQUAL DIGITSDOTDOTDIGITS
%token INTEGER REAL BOOLEAN CHAR
%token <num> NUM
%token <letter> QLQ

%type <symbol_info> L period type basic_type const_value
%type <par> idlist formal_parameter parameter_list
%type <par> parameter var_parameter value_parameter
%type <par> expression_list variable_list
%type <par> expression simple_expression term factor variable id_varpart

%%

programstruct       :   {wf("#include<stdio.h>\n");}program_head ';' program_body '.'
                    ;
program_head        :   PROGRAM ID '(' idlist ')'
                    |   PROGRAM ID
                    ;
program_body        :   const_declarations{ wf("\n"); } var_declarations{ wf("\n"); } subprogram_declarations{ wf("\nint main(){\n"); } compound_statement{ wf(";\nreturn 0;\n}\n"); }
                    ;
/* this is now only used for parameters */
idlist              :   idlist ',' ID
                        {

#if DEBUG
                            INFO("new id %s", (char *)$3->data());
#endif
                            par_append($1, *$3, false);
                            $$ = $1;
                        }
                    |   ID
                        {
#if DEBUG
                            INFO("new id %s", (char *)$1->data());
#endif
                            $$ = new parameter;
                            $$->name = *$1;
                            $$->is_var = false;
                            $$->next = nullptr;
                        }
                    |	error
                    	{
                    	    ERR("err id");
                    	}
                    ;
const_declarations  :   CONST const_declaration ';'
                    |
                    ;

const_declaration   :     ID EQUAL const_value{
                            insert_symbol(*$1, $3);
                            wf("const ",$3.type," ",*$1," = ",nowConst,";\n");
                        }
                |         const_declaration ';' ID EQUAL const_value{
                          insert_symbol(*$3, $5);
                          wf("const ",$5.type," ",*$3," = ",nowConst,";\n");
                        }
                    ;
const_value         :   PLUS NUM
                        {
                            $$.is_const = true;
                            $$.type = get_type($2);
                            nowConst=$2;
                        }
                    |   UMINUS NUM
                        {
                            $$.is_const = true;
                            $$.type = get_type($2);
                            nowConst=$2;
                            nowConst="-"+nowConst;
                        }
                    |  NUM
                        {
                            $$.is_const = true;
                            $$.type = get_type($1);
                            nowConst=$1;

                        }
/*
 * @QLQ: QUOTE LETTER QUOTE
 *
 * In this case, the parser do not deal with quote,
 * and thus QUOTE is removed from the token declaration.
 * QLQ is a <letter> token, so the value of the
 * letter (char) can be retrived from @QLQ directly
 */
                    |   QLQ
                        {
                            $$.is_const = true;
                            $$.type = _CHAR;
                            nowConst=$1;
                        }
                    ;
var_declarations    :   VAR var_declaration ';'
                    |
                    ;
                        /*
                         * L is type <info>, storing all the information of ID.
                         * By insert_symbol(), we insert the variable into the
                         * id table.
                         * Here ID can be basic type or array.
                         */
var_declaration     :   var_declaration ';' ID L
                        {
                            insert_symbol(*$3, $4);
                            if ($4.dim==0) wf(*$3,";\n");
                            else{
                                wf(*$3);
                                period *nowPrd=$4.prd;
                                while(nowPrd!=nullptr){
                                    wf("[",to_string(nowPrd->end-nowPrd->start+1),"]");
                                    nowPrd=nowPrd->next;
                                       }
                                wf(";\n");
                                  }
                        }
                    |   ID L
                        {
                            insert_symbol(*$1, $2);
                            if ($2.dim==0)wf(*$1,";\n");
                        }
                    ;
L                   :   ':' type
                        {
                                  $$ = $2;

                        }
                    |   ',' ID L
                        {
                            insert_symbol(*$2, $3);
                                  $$ = $3;
                            if ($3.dim==0)wf(*$2,", ");
                        }
type                :   basic_type
                        {
                            $$ = $1;
                       wf($$.type," ");
                        }
                    |   ARRAY '[' period ']' OF basic_type
                        {
                            $$ = $3;
                            $$.element_type = $6.type;
                       wf($$.element_type," ");
                        }
                    ;
basic_type          :   INTEGER
                        {
                            $$.type = _INTEGER;
                        }
                    |   REAL
                        {
                            $$.type = _REAL;
                        }
                    |   BOOLEAN
                        {
                            $$.type = _BOOLEAN;
                        }
                    |   CHAR
                        {
                            $$.type = _CHAR;
                        }
                    |	error
                    	{
                    	    ERR("unknown type");
                    	}
                    ;
/* period is <symbol_info>, it contains all informations including dimensions */
period              :   period ',' DIGITSDOTDOTDIGITS
                        {
                            $$.dim = $1.dim + 1;
                            period *p = init_period();
                            p->start = get_first_digit(*$3);
                            p->end = get_last_digit(*$3);
                            append_period($1.prd, p);
                            $$.prd = $1.prd;
                        }
                    |   DIGITSDOTDOTDIGITS
                        {
                            $$.dim = 1;
                            $$.prd = init_period();
                            $$.prd->start = get_first_digit(*$1);
                            $$.prd->end = get_last_digit(*$1);
                        }
                    ;
subprogram_declarations :   subprogram_declarations subprogram ';'
                            {
                                it.end_block();
                            }
                        |
                        ;
subprogram          :   subprogram_head ';'{wf("{\n");}  subprogram_body
                    ;
subprogram_head     :   PROCEDURE ID formal_parameter
                        {
#if DEBUG
                           cout << "inserting procedure " << *$2 << ":" << endl;
                           print_block_info(false, _VOID , $3);
#endif
                            insert_procedure(*$2, $3);
			                cout << "insert done" << endl;

                            wf("void ", *$2, "(");
                            bool first = true;
                            for (auto *cur = $3; cur; cur = cur->next)
                            {
                                if (first)
                                    first = false;
                                else
                                    wf(", ");
                                wf(cur->type, cur->is_var ? " *": " ", cur->name);
                            }
                            wf(")");
                        }
                    |   FUNCTION ID formal_parameter ':' basic_type
                        {
#if DEBUG
                            cout << "inserting function " << *$2 << ":" << endl;
                            print_block_info(true, $5.type, $3);

#endif
                            insert_function(*$2, $3, $5.type);
                            cout << "insert done" << endl;

                            wf($5.type, " ", *$2, "(");
                            bool first = true;
                            for (auto *cur = $3; cur; cur = cur->next)
                            {
                                if (first)
                                    first = false;
                                else
                                    wf(", ");
                                wf(cur->type, cur->is_var ? " *": " ", cur->name);
                            }
                            wf(")");
                        }
                    ;
formal_parameter    :   '(' parameter_list ')'
                        {
                            $$ = $2;
                        }
                    |
                        {
                            $$ = nullptr;
                        }
                    ;
parameter_list      :   parameter_list ';' parameter
                        {
                            parameter *tmp = $1;
                            while(tmp->next)
                                tmp = tmp->next;
                            tmp->next = $3;
                            $$ = $1;
                        }
                    |   parameter
                        {
                            $$ = $1;
#if DEBUG
                            INFO("append %s to parameter list\n", $1->is_var ? "var" : "non-var");
                            print_par_list($$);
#endif
                        }
                    ;
parameter           :   var_parameter
                        {
                            $$ = $1;
                        }
                    |   value_parameter
                        {
                            $$ = $1;
                        }
                    ;
var_parameter       :   VAR value_parameter
                        {
                            parameter *tmp = $2;
                            while(tmp){
                                tmp->is_var = true;
                                tmp = tmp->next;
                            }
                            $$ = $2;
                        }
                    ;
value_parameter     :   idlist ':' basic_type
                        {
                            parameter *tmp = $1;
                            while(tmp){
                                tmp->type = $3.type;
                                tmp = tmp->next;
                            }
                            $$ = $1;
                        }
                    ;
subprogram_body     :   const_declarations var_declarations compound_statement {wf("}\n");}
                    ;
compound_statement  :   _BEGIN statement_list END
                    ;
statement_list      :   statement_list ';'{wf(";\n");} statement
                    |   statement
                    ;
statement           :   variable ASSIGNOP expression{cout<<"ASSIGNOP"<<endl; }
                        {
                            auto is_func = get_id_info($1->name)->type == _FUNCTION;
                            if (is_func) wf("return ", $3->text);
                            else wf($1->name, "=", $3->text);
                        }
                    |   procedure_call
                        {

                        }
                    |   { wf("{\n");}
                        compound_statement
                        { wf(";}\n");}
                    |   IF expression THEN
                        {
                            wf("if(", $2->text, ")\n");
                        }
                        statement {wf(";\n");} else_part
                    |   FOR ID ASSIGNOP expression TO expression DO
                        {
                            wf("for(int", *$2, "=", $4->text, ";", *$2, "<", $6->text, ";", "++", *$2, ")\n{\n");
                        }
                        statement
                        {
                            wf(";\n}\n");
                        }
                    |   READ '(' variable_list ')'
                        {
                            string s, t;
                            bool first = true;
                            for (auto cur = $3; cur; cur = cur->next)
                            {
                                if (first)
                                    first = false;
                                else
                                {
                                    t += ", ";
                                }
                                s += convert_type_printf(cur->type);
                                t += "&" + cur->name;

                            }
                            wf("scanf(\"", s, "\", ", t, ")");
                        }
                    |   WRITE '(' expression_list ')'
                        {
                            string s, t;
                            bool first = true;
                            for (auto cur = $3; cur; cur = cur->next)
                            {
                                s += convert_type_printf(cur->type);
                                t += cur->text;
                                if (first)
                                    first = false;
                                else
                                {
                                    s += " ";
                                    t += ", ";
                                }
                            }
                            s += "\\n";
                            wf("printf(\"", s, "\",", t, ")");
                        }
                    |
                    ;
variable_list       :   variable_list ',' variable
                        {
                            parameter *tmp = $1;
                            while(tmp->next){
                                tmp = tmp->next;
                            }
                            tmp->next = $3;
                            $$ = $1;
                        }
                    |   variable
                        {
                            $$ = $1;
                        }
                    ;
variable            :   ID id_varpart
                        {
                            // TODO 判断ID is_var
                            $$ = get_id_info(*$1);
                            // cout<<"  variable/:" <<$$->type<<" "<<$$->is_var<<endl;
                        }
                    ;
id_varpart          :   '[' expression_list ']'
                    |
                    ;
procedure_call      :   ID {wf(*$1, "()");}
                    |   ID '(' expression_list ')'
                        {
                            wf(*$1, "(");
                            std::vector<Parameter> par_list = get_par_list(*$1);
                            int argc = 0;
                            for (auto *c = $3; c; c = c->next)
                            {
                                if (argc != 0)
                                    wf(", ");
                                wf((par_list[argc].is_var ? "&": "") + c->text);
                                ++argc;
                            }
                        }
                    ;
else_part           :   ELSE {wf("else\n");cout<<"ELSE"<<endl;} statement {wf(";\n");}
                    |
                    ;
expression_list     :   expression_list ',' expression
                        {
                            parameter *tmp = $1;
                            while(tmp->next){
                                tmp = tmp->next;
                            }
                            tmp->next = $3;
                            $$ = $1;
                        }
                    |   expression
                        {
                        }
                    ;
expression          :   simple_expression RELOP simple_expression
                        {
                            $$ = new parameter;
                            $$->type = _BOOLEAN;
                            cout<<"\nexpression "<<$$->type<<endl<<endl;
                            $$->text = $1->text + convert_relop(*$2) + $3->text;
                        }
                    |   simple_expression EQUAL simple_expression
                        {
                            $$ = new parameter;
                            $$->type = _BOOLEAN;
                            cout<<"\nexpression "<<$$->type<<endl<<endl;
                            $$->text = $1->text + convert_relop(*$2) + $3->text;
                        }
                    |   simple_expression
                        {
                            $$ = new parameter;
                            $$->type = $1->type;
                            cout<<"\nexpression "<<$$->type<<endl<<endl;
                            $$->text = $1->text;
                        }
                    ;
simple_expression   :   simple_expression ADDOP term
                        {
                            $$ = new parameter;
                            $$->is_var = $1->is_var | $3->is_var;
                            // Todo: 错误处理
                            $$->type = _BOOLEAN;
                            $$->text = $1->text + "|" + $3->text;
                        }
                    |   simple_expression PLUS term
                        {
                            $$ = new parameter;
                            $$->is_var = $1->is_var | $3->is_var;
                            // Todo: 错误处理
                            $$->type = cmp_type($1->type, $3->type);
                            $$->text = $1->text + "+" + $3->text;
                        }
                    |   simple_expression UMINUS term
                        {
                            $$ = new parameter;
                            $$->is_var = $1->is_var | $3->is_var;
                            // Todo: 错误处理
                            $$->type = cmp_type($1->type, $3->type);
                            $$->text = $1->text + "-" + $3->text;
                        }
                    |   term
                        {
                            $$ = new parameter;
                            $$->type = $1->type;
                            $$->text = $1->text;
                        }
                    ;
term                :   term MULOP factor
                        {
                            $$ = new parameter;
                            $$->is_var = $1->is_var | $3->is_var;
                            string* s = $2;
                            int i = get_mulop_type(s);
                            string mulop_s;
                            switch (i)
                            {
                            case 1: // and
                                // Todo: 错误处理
                                $$->type = _BOOLEAN;
                                mulop_s = "&";
                                break;
                            case 2: // div
                                // Todo: 错误处理
                                $$->type = cmp_type($1->type, $3->type);
                                mulop_s = "/";
                                break;
                            case 3: // mod
                                // Todo: 错误处理
                                $$->type = cmp_type($1->type, $3->type);
                                mulop_s = "%";
                                break;
                            default: // * /
                                // Todo: 错误处理
                                $$->type = cmp_type($1->type, $3->type);
                                mulop_s = *$2;
                                break;
                            }
                            $$->text = $1->text + mulop_s + $3->text;
                        }
                    |   factor
                        {
                            $$ = new parameter;
                            $$->type = $1->type;
                            $$->text = $1->text;
                        }
                    ;
factor              :   NUM
                        {
                            $$ = new parameter;
                            //$$->is_var = false;
                            $$->type = get_type($1);
                            cout<<"factor "<<$$->type<<endl;
                            $$->text = $1;
                        }
                    |   variable
                        {
                            $$ = new parameter;
                            $$ = $1;
                            if ($$->is_var) $$->text = "(*" + $1->name + ")";
                            else $$->text = $1->name;
                            cout<<"variable "<<$$->name<<" "<<$$->type<<" "<<$$->is_var<<endl;
                        }
                    |   ID '(' expression_list ')'
                        {
                            $$ = new parameter;
                            // 根据ID（函数）确定type
                            TYPE type;
                            type = get_id_info(*$1)->type;
                            if (type == _DEFAULT) {
                                ERR("use of undeclared identifier");
                                $$->type = _INTEGER;
                                $$->text = "";
                            } else if (type != _FUNCTION) {
                                ERR("called object is not a function or function pointer");
                                $$->type = _INTEGER;
                                $$->text = "";
                            } else {
                                $$->type = get_fun_type(*$1);
                                $$->text = *$1 + "(";
                                std::vector<Parameter> par_list = get_par_list(*$1);
                                int argc = 0;
                                for (auto *c = $3; c; c = c->next)
                                {
                                    if (argc != 0)
                                        $$->text += ", ";
                                    if (c->type != par_list[argc].get_type()) {
                                        cout<<c->type <<" "<<par_list[argc].get_type()<<endl;
                                        if (c->type ！= par_list[argc].get_type()) {
                                            ERR("Parameter types do not match");
                                        }
                                    }
                                    $$->text += (par_list[argc].is_var ? "&": "") + c->text;
                                    ++argc;
                                }
                                $$->text += ")";
                                if (argc != par_list.size()) {
                                    ERR("The number of parameters does not match！");
                                }
                            }
                        }
                    |   '(' expression ')'
                        {
                            $$ = new parameter;
                            $$->type = $2->type;
                            $$->text = "not implement";
                        }
                    |   NOT factor
                        {
                            $$ = new parameter;
                            if ($2->type != _BOOLEAN && $2->type != _INTEGER) {
                                ERR("factor -> NOT factor :  The 2nd factor must be bool");
                            }
                            $$->type = $2->type;
                            $$->text = "!" + $2->text;
                        }
                    |   UMINUS factor
                        {
                            $$ = new parameter;
                            $$->type = $2->type;
                            // Todo 类型检查
                            $$->text = "-" + $2->text;
                        }
                    ;

%%
int get_first_digit(const string &s){
    return stoi(s.substr(0,s.find(".")));
}
int get_last_digit(const string &s){
    return stoi(s.substr(s.rfind(".") + 1));
}
/*
 * insert_symbol:
 * when we know a symbol's name and all its information, we create this
 * symbol and insert it into the id table
 * @t: a info struct, stores all the information of the id
 * NOTE that it(id table) should be a global object
 * TODO: is there a way not to declare it as a global ofject? Can it be
 * declared in the main function?
 */
void insert_symbol(string name, info t){
    /* basic type */
    if (t.type >= _INTEGER and t.type <= _CHAR){
        BasicTypeId *id = new BasicTypeId(name, t.type, t.is_const);
        it.enter_id((Id*)id);
    } else if (t.type == _ARRAY){  /* array */
        ArrayId *id = new ArrayId(name, t.type, t.dim, t.prd);
        it.enter_id((Id*)id);
    }
}

/*
 * insert_procedure():
 * @par: parameter list
 */
void insert_procedure(string name, parameter *par){
    vector<Parameter> pl;
    parameter* par1 = par;
    while(par1){
        Parameter p = Parameter(par1->name, par1->type, par1->is_var);
        pl.push_back(p);
        par1 = par1->next;
    }
    ProcedureId *id = new ProcedureId(name, pl);
    it.enter_id((Id*)id);

    parameter* par2 = par;
    while(par2){
        Parameter *p = new Parameter(par2->name, par2->type, par2->is_var);
        it.enter_id((Id*)p);
        par2 = par2->next;
    }
}

/*
 * insert_function():
 * @par: parameter list
 * @rt: return type
 */
void insert_function(string name, parameter *par, TYPE rt){
    vector<Parameter> pl;
    parameter* par1 = par;
    while(par1){
        Parameter p = Parameter(par1->name, par1->type, par1->is_var);
        pl.push_back(p);
        par1 = par1->next;
    }
    FunctionId *id = new FunctionId(name, pl, rt);
    it.enter_id((Id*)id);

    parameter* par2 = par;
    while(par2){
        Parameter *p = new Parameter(par2->name, par2->type, par2->is_var);
        it.enter_id((Id*)p);
        par2 = par2->next;
    }
}

/*
 * find what type(integer / real) is the num
 * TODO: add boolean (true / false) here
 */
TYPE get_type(char *s){
    string ss = s;
    string::size_type idx;
    idx = ss.find(".");
    if (idx == string::npos){
        return _INTEGER;
    } else {
        return _REAL;
    }
}

/*
 * find which type return
 */
TYPE cmp_type(TYPE t1, TYPE t2){
    if (t1 == _BOOLEAN || t2 == _BOOLEAN) {
        return _BOOLEAN;
    } else if (t1 == _REAL || t2 == _REAL) {
        return _REAL;
    } else {
        return _INTEGER;
    }
}

int get_mulop_type(string* s){
    if (*s == "and") {
        return 1;
    } else if (*s == "div") {
        return 2;
    } else if (*s == "mod") {
        return 3;
    } else {
        return 4;
    }
}

/*
 * return function type by name
 */
TYPE get_fun_type(string name) {
    int index;
    index = it.find_id(name);
    if (index == -1) {
        return _DEFAULT;
    } else {
        Id* id = it.get_id(index);
//       TODO check if it is an instanceof block
        return ((Block*)id)->get_ret_type();
    }
}

/*
 * return id type and is_var by name
 */
parameter* get_id_info(string name) {
    int index;
    index = it.find_id(name);
    parameter* par = new parameter;
    if (index == -1) {
        par->name = name;
        par->type = _DEFAULT;
    } else {
        Id* id = it.get_id(index);
        par->name = name;
        par->type = id->get_type();
        try {
            par->is_var = ((Parameter*)id)->get_is_var();
        } catch(...) {
            par->is_var = false;
        }
    }
    return par;
}


void par_append(parameter *p, string name, bool is_var){
    parameter *tmp = p;
    while(tmp->next){
        tmp = tmp->next;
    }
    parameter *np = new parameter;
    np->next = nullptr;
    np->name = name;
    np->is_var = is_var;
    tmp->next = np;
}

#if DEBUG
void print_par_list(parameter *p){
    cout << "parameter list is now:" << endl;
    while(p){
        cout << "    [name: "   << p->name
             << ", is_var: "    << p->is_var
             << ", type: "      << p->type
             << ", has next: "  << !(p->next == nullptr)
             << "]" << endl;
        p = p->next;
    }
}

void print_block_info(bool is_func, TYPE ret_type, parameter *p){
    print_par_list(p);
    if (is_func)
        cout << "return type: " << ret_type << endl;
}
#endif

std::vector<Parameter> get_par_list(string id)
{
    int index = it.find_id(id);
    auto f = it.get_id(index);
    return static_cast<Block *>(f)->get_par_list();
}


// target code generation start
void wf(const char *s)
{
    extern FILE* yyout;
    fputs(s, yyout);
}

void wf(const string &s)
{
    wf(s.c_str());
}

void wf(TYPE t)
{
    wf(convert_type(t));
}

template<class T, class ...Args>
void wf(T head, Args ...rest)
{
    wf(head);
    wf(rest...);
}

string convert_relop(const string s)
{
    if (s == "=") return string("==");
    else if (s == "<>") return string("!=");
    else return s;
}

string convert_type(TYPE t)
{
    string ret;
    switch (t)
    {
    case _INTEGER:
        ret = "int";
        break;
    case _REAL:
        ret = "double";
        break;
    case _BOOLEAN:
        ret = "int";
        break;
    case _CHAR:
        ret = "char";
        break;
    default:
        yyerror("Unsupport Type");
    }
    return ret;
}

string convert_type_printf(TYPE t)
{
    string ret;
    switch (t)
    {
    case _INTEGER:
        ret = "%d";
        break;
    case _REAL:
        ret = "%f";
        break;
    case _BOOLEAN:
        ret = "%d";
        break;
    case _CHAR:
        ret = "%c";
        break;
    default:
        yyerror("Unsupport Type");
    }
    return ret;
}
// target code generation end

void return_help(char *exe_path)
{
    printf("\nUsage %s <input_file> [output_file] [options]...\n", exe_path);
    printf("Options:\n");
    printf("  -h, --help                Print the message and exit\n\n");
    exit(-1);
}

int main(int argc, char* argv[]){
    const char *optstring = "f:h";
    int opt;
    int option_index = 0;
    static struct option long_options[] = {
        {"help",  no_argument,       NULL, 'h'},
        {0, 0, 0, 0}
    };
    char *input_path = NULL, *output_path = NULL;
    if (argc == 1) return_help(argv[0]);
    while ( (opt = getopt_long(argc, argv, optstring, long_options, &option_index)) != -1) {
        if (opt == 'h' || opt == '?'){
            return_help(argv[0]);
        }
    }
    input_path = argv[1];
    FILE* fp = fopen(input_path,"r");
    if (fp == NULL){
        printf("Cannot open %s as input file\n", input_path);
        return -1;
    }
    extern FILE* yyin;
    extern FILE* yyout;
    yyin = fp;
    FILE *fp2 = NULL;
    if (argc >= 3 && argv[2][0] != '-')
    {
        fp2 = fopen(argv[2], "w");
        if (fp2 == NULL)
        {
            printf("Cannot create %s as output file\n", argv[2]);
            return -1;
        }
    }
    if (fp2 == NULL)
    {
        int len = strlen(input_path);
        input_path[len - 3] = 'c';
        input_path[len - 2] = 0;
        output_path = input_path;
        fp2 = fopen(output_path, "w");
        if (fp2 == NULL)
        {
            printf("Cannot create %s as output file\n", output_path);
            return -1;
        }
    }
    yyout = fp2;
    yyparse();
    if (success == 1)
        printf("Parsing doneee.\n");
    return 0;
}

int yyerror(const char *msg)
{
	static int err_no = 1;
	extern int yylineno;
	printf("Error %d, Line Number: %d %s\n", err_no++, yylineno, msg);
    success = 0;
	return 0;
}

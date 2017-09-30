
/*
 * CS-252
 * shell.y: parser for shell
 *
 * This parser compiles the following grammar:
 *
 *	cmd [arg]* [> filename]
 *
 * you must extend it to understand the complete shell grammar
 *
 */

%token	<string_val> WORD

%token 	NOTOKEN GREAT NEWLINE LESS GREATGREAT GREATAND GREATGREATAND PIPE AND

%union	{
	char   *string_val;
}

%{
	//#define yylex yylex
#include <stdio.h>
#include <string.h>
#include "command.h"
#include <regex.h>
#include <dirent.h>
#define MAXFILENAME 1024
#include <vector>
#include<stdlib.h>



using namespace std;
	void yyerror(const char * s);
	vector<char*> array;
	int flag =0;
	int f=0;
	int yylex();
	void expandWildcardsIfNecessary(char * arg);
	void expand(char* prefix, char* suffix);

	%}

	%%

	goal:	
	commands
	;

commands: 
command
| commands command 
;

command: simple_command
;



simple_command:	
pipe_list iomodifier_list background NEWLINE {
	//printf("   Yacc: Execute command\n");
	Command::_currentCommand.execute();
}
| NEWLINE 
| error NEWLINE { yyerrok; }
;

command_and_args:
command_word argument_list {
	//Command::_currentSimpleCommand = new SimpleCommand();
	Command::_currentCommand.insertSimpleCommand( Command::_currentSimpleCommand );
}
;
iomodifier_list:
iomodifier_list iomodifier_opt
|
;

pipe_list:
pipe_list PIPE command_and_args
|command_and_args
;

argument_list:
argument_list argument
| /* can be empty */
;

argument:
WORD {
	//printf("   Yacc: insert argument \"%s\"\n", $1);
	//Command::_currentSimpleCommand->insertArgument( $1 );
	expandWildcardsIfNecessary($1);
}
;

command_word:
WORD {
	//printf("   Yacc: insert command \"%s\"\n", $1);

	Command::_currentSimpleCommand = new SimpleCommand();
	Command::_currentSimpleCommand->insertArgument( $1 );
}
;

iomodifier_opt:

GREAT WORD {
	//printf("   Yacc: insert output \"%s\"\n", $2);
	Command::_currentCommand._outFile = $2;
	Command::_currentCommand._countOutFile++;
}
|
GREATGREAT WORD {
	//printf("   Yacc: insert output \"%s\"\n", $2);
	Command::_currentCommand._outFile = $2;
	Command::_currentCommand._append = 1;
}
|
GREATGREATAND WORD {
	//printf("   Yacc: insert output \"%s\"\n", $2);
	Command::_currentCommand._outFile = strdup($2);
	Command::_currentCommand._errFile = $2;
	Command::_currentCommand._append = 1;
}
|
GREATAND WORD {
	//printf("   Yacc: insert output \"%s\"\n", $2);
	Command::_currentCommand._outFile = strdup($2);
	Command::_currentCommand._errFile = $2;
}
|
LESS WORD {
	//printf("   Yacc: insert input \"%s\"\n", $2);
	Command::_currentCommand._inFile = $2;
}

;

background:
AND {
	Command::_currentCommand._background = 1;
}
|
;

%%

	void
yyerror(const char * s)
{
	fprintf(stderr,"%s", s);
}

void expandWildcardsIfNecessary(char * arg){
	
	
	//fprintf(stderr, "prefix:%s, suffix:%s\n", prefix, suffix);
	array.clear();
	if(strchr(arg, '*')==NULL && strchr(arg, '?')==NULL){
		Command::_currentSimpleCommand->insertArgument(arg);
		return;
	}

	expand(0,arg);
	int i=0;
	while(i<array.size()){
		Command::_currentSimpleCommand->insertArgument( strdup(array[i]) );
		i++;
	}


}
bool slash = false;
bool lifesaver = false;
void expand(char* prefix, char* suffix){
	if(!suffix){
		array.push_back(strdup(prefix));
		//Command::_currentSimpleCommand->insertArgument( strdup(prefix));
		return;
	}

	if(suffix[0] == '/'){
		slash = true;
	}

	char* s = strchr(suffix, '/');
	char component[MAXFILENAME];

	if(s != NULL){
		strncpy(component, suffix, s-suffix);
		f=1;
		component[s-suffix] = '\0';

		suffix = s+1; //advance suffix
		if(flag ==0){
			prefix = NULL;
			flag =1;
		}
	}
	else if(suffix == s){
	//	component[0] = '\0'; 
	//	component[1] = '\0';

		suffix = s+1;
	}
	else{
		strcpy(component, suffix);
		suffix =NULL;
	}

	char newP[MAXFILENAME];

	if(strchr(component,'*') ==NULL && strchr(component,'?')==NULL){
		if(!prefix){
			//sprintf(newP, "%s/%s", prefix, component);
			//lifesaver = true;
			sprintf(newP, "%s", component);

		}
		else{
			//sprintf(newP, "%s", component);
			sprintf(newP, "%s/%s", prefix, component);
			lifesaver = true;

		}
		expand(newP, suffix);
		return;
	}else if( slash == true){
		f=2;
		slash = false;
	}

	char * a = component;
	char * reg = (char *)malloc(2 * strlen(component) + 10);
	char * r = reg;
	*r = '^';
	r++;

	while (*a) {
	if (*a == '*') {
	*r = '.';
	r++;
	*r = '*';
	r++;
	}
	else if (*a == '?') {
	*r = '.';
	r++;
	}
	else if (*a == '.') {
	*r = '\\';
	r++;
	*r = '.';
	r++;
	}
	else {
	*r = *a;
	r++;
	}
	a++;
	}
	*r = '$';
	r++;
	*r = 0;

	regex_t re;
	int expbuf = regcomp(&re, reg, REG_EXTENDED | REG_NOSUB);
	if (expbuf != 0) {
	perror("regcomp");
	return;
	}

	char * dir;
	if(f ==2 && lifesaver == false){
		const char * dot = "/";
		dir = strdup(dot);
		f++;
	}
	else if(prefix == 0) {
		const char * dot = ".";
		dir = strdup(dot);
		//dir = ".";
	} else {
		dir = prefix;
	}

	DIR * dir2 = opendir(dir);
	if (dir2 == NULL) {
	return;
	}

	struct dirent * ent;
	
	while((ent = readdir(dir2))!= NULL){
		if(regexec(&re, ent->d_name,1,NULL,0)==0){
			if (ent->d_name[0] == '.') {
				if(component[0] == '.'){
					if(prefix){
						sprintf(newP, "%s/%s", prefix,ent->d_name);
					}
					else{
						//newP = ent->d_name;
						sprintf(newP, "%s", ent->d_name);

					}
					expand(newP, suffix);
				}

			}
			else{
				if(prefix){
					sprintf(newP, "%s/%s", prefix, ent->d_name);
				}
				else{
					//newP = ent->d_name;
					sprintf(newP, "%s", ent->d_name);
				}

				expand(newP, suffix);

			}
		}
	}
	int i,j,k;
	char * temp;	
	for(i =0; i<array.size()-1;i++){
		for(j=0; j<array.size() - i -1; j++){
			if (strcmp(array[j],array[j+1]) > 0){
				temp= array[j];
				array[j] = array[j+1];
				array[j+1] = temp;
			}
		}
	}
	
	closedir(dir2);
	

}

#if 0
main()
{
	yyparse();
}
#endif

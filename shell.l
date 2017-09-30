
/*
 *
 * CS-252 Fall 2013
 * shell.l: lexical analyzer for shell
 * You have to extend it.
 *
 */

%{

#include <string.h>
#include "y.tab.h"
#include <sys/wait.h>
#define SUBSHELL_LEN 2048
#include <unistd.h>

extern int loading;

extern "C" char * read_line();

int mygetc(FILE * f) {
	static char *p;
	char ch;
	if (!isatty(0)) {
		// stdin is not a tty. Call real getc
		return getc(f);
	}
	// stdin is a tty. Call our read_line.
	if (p==NULL || *p == 0) {
		char * s = read_line();
		p = s;
	}
	ch = *p;
	p++;
	return ch;
}

#undef getc
#define getc(f) mygetc(f)


static  void yyunput (int c,char *buf_ptr  );

void myunputc(int c) {
	unput(c);
}

%}


%x incl
%%
"source"      BEGIN(incl);	/* dealing with import */

<incl>[ \t]*      /* eat the whitespace */
<incl>[^ \t\n]+   { /* got the include file name */
    yyin = fopen( yytext, "r" );
    
    if ( ! yyin ) {
        perror("Unable to open file %s.\n");
    } 
    loading = 1; 	/* Disable printing prompts while reading contents from the file. */
    yypush_buffer_state(yy_create_buffer( yyin, YY_BUF_SIZE ));  /* Put current buffer on stack, and use the file */
    BEGIN(INITIAL);
}
     
<<EOF>> {
    yypop_buffer_state();
    loading = 0;    /* Enable printing prompts again.  This assumes that we only use import for one level. */
    if ( !YY_CURRENT_BUFFER ) {
        yyterminate();
    }
}  /* End of code supporting import. */

\n 	{
	return NEWLINE;
	}
[ \t] 	{
	/* Discard spaces and tabs */
}	

">" 	{
	return GREAT;
}


"<" {
	return LESS;
}

">>" {
	return GREATGREAT;
}
">&" {
	return GREATAND;
}

">>&"  {
	return GREATGREATAND;
}

"|" {
	return PIPE;
}

"&" {
	return AND;
}

[`]([^"']|a-zA-Z\\.)*[`] {
//subshell

char* str = strdup(yytext+1);
char* str2 = strdup(str);
int len = strlen(str2)-1;
str2[len] = '\n';

/* Set up temp string and pipes */
char tempstr[SUBSHELL_LEN];
int pipe_in[2], pipe_out[2]; 

if (pipe(pipe_in) < 0 || pipe(pipe_out) < 0) {
	perror("pipe");
	free(str2);
	return 1;
}

int temp[2];// temp_in and temp_out
temp[0]  = dup(0);
temp[1] =  dup(1);

dup2(pipe_in[1], 1); 
close(pipe_in[1]);

dup2(pipe_out[0], 0); 
close(pipe_out[0]);


pid_t pid; 

if((pid = fork()) <0){
	perror("fork");
	_exit(0);
}
else if(pid ==0){
	dup2(pipe_in[0], 0);
	close(pipe_in[0]);
	dup2(pipe_out[1], 1);
	close(pipe_out[1]);

	execlp("/proc/self/exe","/proc/self/exe",NULL);
	perror("execvp");
	_exit(1);
}
else{
	int i =0;
	while(i<len+1 && write(1,str2+i,1)){
		i++;
	}
	
	dup2(temp[1],1);
	close(temp[1]);
	close(pipe_out[1]);

	char* t = tempstr;
	
	for(char ch=0; read(0,&ch,1);t++){
		if(ch!='\n'){
			*t = ch;
		}
		else {
			*t = ' ';
		}
	}
	 for(t--;t>=tempstr;t--){
	 	unput(*t);
	 }

	//close files
	 dup2(temp[0],0);
	 close(temp[0]);
	 
}

	// Wait for all processes 
	waitpid(pid,NULL,0);
}


[^ \t\n\\]*\\[^ \n\t]*	{
	yylval.string_val = strdup(yytext);
	int i = 0, j = 0;
	char arg[strlen(yylval.string_val )];
	for ( i = 0; i < strlen(yylval.string_val ); i++) {

		if ( yylval.string_val[i] != '\\' )
			arg[j++] = yylval.string_val[i];	
		if ( yylval.string_val[i] == '\\' )
			arg[j++] = yylval.string_val[++i]; 

	}
	arg[j] = '\0';
	//fprintf(stderr, "temp:%s\n", arg);
	strcpy(yylval.string_val, arg);
	return WORD;

}

\"[^\"\n]*\"	{
yylval.string_val = strndup(&yytext[1], strlen(yytext) - 2);
return WORD;

}
[^ \t\n\\<>&|][^ \t\n\\<>&|]*  {

	/* Assume that file names have only alpha chars */
	yylval.string_val = strdup(yytext);
	return WORD;
}

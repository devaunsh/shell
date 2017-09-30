
/*
 * CS252: Shell project
 *
 * Template file.
 * You will need to add more code here to execute the command table.
 *
 * NOTE: You are responsible for fixing any bugs this code may have!
 *
 */

#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <sys/types.h>
#include <sys/wait.h>
#include <string.h>
#include <signal.h>
#include <fcntl.h>
#include <pwd.h>
#include "command.h"

int loading =0;

SimpleCommand::SimpleCommand()
{
	// Create available space for 5 arguments
	_numOfAvailableArguments = 5;
	_numOfArguments = 0;
	_arguments = (char **) malloc( _numOfAvailableArguments * sizeof( char * ) );
}

	void
SimpleCommand::insertArgument( char * argument )
{
	if ( _numOfAvailableArguments == _numOfArguments  + 1 ) {
		// Double the available space
		_numOfAvailableArguments *= 2;
		_arguments = (char **) realloc( _arguments,
				_numOfAvailableArguments * sizeof( char * ) );
	}
	if ( strcmp(argument, "~") == 0) 
		argument = strdup(getenv("HOME"));
	else if (argument[0] == '~') 
		argument = strdup(getpwnam(argument + 1)->pw_dir);

	int len = strlen(argument);
	int a = 0, b = -1;
	for ( int i = 0; i < len; i++ ) {
		if ( argument[i] == '$' && argument[i+1] == '{') {
			a = i+2;
			for ( int j = a; j < len; j++) {
				if ( argument[j] == '}') {
					b = j;
					break;
				}
			}
			if ( b > 0 ) {
				fprintf(stderr, "a:%d,b:%d\n", a, b);
				char var[b-a +1];
				memcpy(var, &argument[a], b-a);
				var[b-a] = '\0';
				fprintf(stderr, "var:%s\n", var);
				char * val = getenv(var);
				fprintf(stderr, "val:%s\n", val);
				char temp[ len + strlen(val) + 1];
				memcpy(temp, &argument[0], a - 2);
				strcat(temp, val);
				strncat(temp, &argument[b+1], len - b); 
				fprintf(stderr, "temp:%s\n", temp);
				argument = strdup(temp);
				i = 0;
				a = 0;
				b = -1;
			}
		} 


	}

	_arguments[ _numOfArguments ] = argument; 

	// Add NULL argument at the end
	_arguments[ _numOfArguments + 1] = NULL;

	_numOfArguments++;
}

Command::Command()
{
	// Create available space for one simple command
	_numOfAvailableSimpleCommands = 1;
	_simpleCommands = (SimpleCommand **)
		malloc( _numOfSimpleCommands * sizeof( SimpleCommand * ) );

	_numOfSimpleCommands = 0;
	_outFile = 0;
	_inFile = 0;
	_errFile = 0;
	_background = 0;
	_append = 0;
	_countOutFile = 0;
}

	void
Command::insertSimpleCommand( SimpleCommand * simpleCommand )
{
	if ( _numOfAvailableSimpleCommands == _numOfSimpleCommands ) {
		_numOfAvailableSimpleCommands *= 2;
		_simpleCommands = (SimpleCommand **) realloc( _simpleCommands,
				_numOfAvailableSimpleCommands * sizeof( SimpleCommand * ) );
	}

	_simpleCommands[ _numOfSimpleCommands ] = simpleCommand;
	_numOfSimpleCommands++;
}

	void
Command:: clear()
{
	for ( int i = 0; i < _numOfSimpleCommands; i++ ) {
		for ( int j = 0; j < _simpleCommands[ i ]->_numOfArguments; j ++ ) {
			free ( _simpleCommands[ i ]->_arguments[ j ] );
		}

		free ( _simpleCommands[ i ]->_arguments );
		free ( _simpleCommands[ i ] );
	}

	if ( _outFile ) {
		free( _outFile );
	}

	if ( _inFile ) {
		free( _inFile );
	}

	if ( _errFile ) {
		free( _errFile );
	}

	_numOfSimpleCommands = 0;
	_outFile = 0;
	_inFile = 0;
	_errFile = 0;
	_background = 0;
	_append = 0;
	_countOutFile = 0;
}

	void
Command::print()
{
	printf("\n\n");
	printf("              COMMAND TABLE                \n");
	printf("\n");
	printf("  #   Simple Commands\n");
	printf("  --- ----------------------------------------------------------\n");

	for ( int i = 0; i < _numOfSimpleCommands; i++ ) {
		printf("  %-3d ", i );
		for ( int j = 0; j < _simpleCommands[i]->_numOfArguments; j++ ) {
			printf("\"%s\" \t", _simpleCommands[i]->_arguments[ j ] );
		}
	}

	printf( "\n\n" );
	printf( "  Output       Input        Error        Background\n" );
	printf( "  ------------ ------------ ------------ ------------\n" );
	printf( "  %-12s %-12s %-12s %-12s\n", _outFile?_outFile:"default",
			_inFile?_inFile:"default", _errFile?_errFile:"default",
			_background?"YES":"NO");
	printf( "\n\n" );

}

	void
Command::execute()
{
	// Don't do anything if there are no simple commands
	if (!strcmp(_simpleCommands[0]->_arguments[0], "exit")) {
		printf("\nGood Bye!!\n\n");
		clear();
		exit(0);
	}
	if ( _numOfSimpleCommands == 0 ) {
		prompt();
		return;
	}
	if ( _countOutFile > 1) {
		printf("Ambiguous output redirect\n");
		prompt();
		return;
	}

	if(!strcmp(_simpleCommands[0]->_arguments[0], "unsetenv")){
		if(_simpleCommands[0]->_numOfArguments != 2) 
			unsetenv(NULL);
		else 
			unsetenv(_simpleCommands[0]->_arguments[1]);
		clear();
		prompt();
		return;
	}

	if(!strcmp(_simpleCommands[0]->_arguments[0], "setenv")){
		if(_simpleCommands[0]->_numOfArguments != 3) { 
			if (setenv(NULL, NULL, 0) == -1) 
				perror("setenv");
		}
		else if(setenv(_simpleCommands[0]->_arguments[1], _simpleCommands[0]->_arguments[2], 1)== -1)
			perror("setenv");
		clear();
		prompt();

		return;
	}

	if(strcmp(_simpleCommands[0]->_arguments[0], "cd") == 0){
		if(_simpleCommands[0]->_numOfArguments == 2) 
			chdir(_simpleCommands[0]->_arguments[1]);
		else if ( _simpleCommands[0]->_numOfArguments == 1) 
			chdir(getenv("HOME"));
		else 
			perror("cd");
		clear();
		prompt();
		return;
	}



	// Print contents of Command data structure
	//print();

	// Add execution here
	// For every simple command fork a new process
	// Setup i/o redirection
	// and call exec


	int tempin = dup(0);
	int tempout = dup(1);
	int temperr = dup(2);
	int fdin;
	int fderr;
	if (_inFile) 
		fdin = open(_inFile,O_RDONLY, 0777);
	else 
		fdin = dup(tempin);// Use default input

	if (_errFile && _append) 
		fderr = open(_errFile,O_CREAT | O_WRONLY | O_APPEND, 0777);
	else if ( _errFile && !_append) 
		fderr = open(_errFile,O_CREAT | O_WRONLY | O_TRUNC, 0777);
	else 
		fderr = dup(temperr);// Use default input
	dup2(fderr, 2);
	close(fderr);


	int ret;
	int fdout;
	int fdpipe[2];
	for ( int i = 0; i < _numOfSimpleCommands; i++ ) {
		//fprintf(stderr, "simple command %s\n", _simpleCommands[i]->_arguments[0]);
		dup2(fdin, 0);
		close(fdin);
		//setup output
		if ( i == _numOfSimpleCommands - 1) {
			if(_outFile && !_errFile && _append)
				fdout = open(_outFile, O_CREAT | O_WRONLY | O_APPEND, 0777); 
			else if (_outFile && !_errFile) 
				fdout = open(_outFile, O_CREAT | O_WRONLY | O_TRUNC, 0777); 
			else		  
				fdout=dup(tempout); //Use default output

		}
		else {
			pipe(fdpipe);
			fdout=fdpipe[1];
			fdin=fdpipe[0];
		}
		dup2(fdout,1); 
		close(fdout);
		ret = fork();
		if (ret == 0) {
			//fprintf(stderr, "simple command %s\n", _simpleCommands[i]->_arguments[0]);
			if ( !strcmp(_simpleCommands[i]->_arguments[0], "printenv") ) {
				char ** env = environ;
				while (*env) 
					printf("%s\n", *env++);
				exit(0);
			}

			execvp(_simpleCommands[i]->_arguments[0],_simpleCommands[i]->_arguments);
			perror("execvp");
			_exit(1); 
		}
		else if ( ret < 0) {
			perror("fork");
			return;
		}
	}
	dup2(tempin,0); 
	dup2(tempout,1); 
	dup2(temperr,2);
	close(tempin); 
	close(tempout);
	close(temperr);
	if (!_background) {
		waitpid(ret, NULL, 0);
	}
	// Clear to prepare for next command
	clear();

	// Print new prompt
	prompt();
}

// Shell implementation

	void
Command::prompt()
{	if (loading ==0){
		if ( isatty(0) ){
			printf("myshell>");
			fflush(stdout);
		}
	}
}

void sigctrlcHandler(int sig){
	printf("\n");
	Command::_currentCommand.prompt();
}

void sigzomHandler(int sig){
	for(; waitpid(-1,0,WNOHANG)>0; );
}

Command Command::_currentCommand;
SimpleCommand * Command::_currentSimpleCommand;



int yyparse(void);
main()
{
	struct sigaction sigctrlc;
	sigctrlc.sa_handler = sigctrlcHandler;
	sigemptyset(&sigctrlc.sa_mask);
	sigctrlc.sa_flags = SA_RESTART;
	int error = sigaction(SIGINT, &sigctrlc, NULL);
	if(error == -1){
		perror("sigctrlc");
		exit(1);
	}

	struct sigaction sigzom;
	sigzom.sa_handler = sigzomHandler;
	sigemptyset(&sigzom.sa_mask);
	sigzom.sa_flags = SA_RESTART;
	int err = sigaction(SIGCHLD, &sigzom, NULL);

	if(err==-1){
		perror("sigzom");
		exit(2);
	}


	Command::_currentCommand.prompt();
	yyparse();
}


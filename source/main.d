module main;
import ctfepp;
import std.stdio;

void main() {
	PPFile file = PPFile(`
#include "test.h"
#include <test2.h>
something
#if 1 + 1 == 2
    woot
#endif

#ifdef _WIN32
    is windows
#elif defined __unix__
    is unix
#endif

#define PI 3.14159
#undef PI
#define RADTODEG(x) ((x) * 57.29578)
`);
	executePPParser(file);
	writeln(file.toString());


	mixin(testMixin());
}

string testMixin() {
	PPFile file;
	EvaluateData edata;
	
	file = PPFile(`
#define TEXT "Hello to you!"
writeln( TEXT );
`);

	executePPParser(file);
	edata = EvaluateData(file);
	executeEvaulator(edata);

	return edata.output;
}
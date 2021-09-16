module ctfepp.evaluator;
import ctfepp.defs;
import std.string : indexOf, toLower, strip;

/**
 *
 * TODO:
 *      - Everything
 *      - Support predefined macros from:
 *        http://gcc.gnu.org/onlinedocs/cpp/Standard-Predefined-Macros.html#Standard-Predefined-Macros
 *      - Optionally support these predefined macros:
 *        http://gcc.gnu.org/onlinedocs/cpp/Common-Predefined-Macros.html#Common-Predefined-Macros
 */

struct EvaluateData {
	PPFile file;
	string output;

	string[string] defineValues;
}

/*pure*/ void executeEvaulator(ref EvaluateData data) {
	bool[] handledConditional;

	void handleLines(PPLine[] lines) {
		foreach(line; lines) {
			string handleValueSubsitutions(string text) {
				string ret = text;

				foreach(k, v; data.defineValues) {
					if (ret.indexOf(" " ~ k ~ " ") >= 0)
						ret = ret.replace(" " ~ k ~ " ", " " ~ v ~ " ");
					else if (ret.length >= k.length && ret[$ - k.length .. $] == k)
						ret = ret[0 .. $ - k.length] ~ v;
					else if (ret.length >= k.length && ret[0 .. k.length] == k)
						ret = v ~ ret[$ - k.length .. $];
				}

				return ret;
			}

			bool conditionCheck(string conditions) {
				string[] conditionals = conditions.split("&&", "||");
				bool[] orConditions = [true];

				foreach(c; conditions.splitDelimaters("&&", "||"))
					orConditions ~= c == "||";

				bool ret, changed;

				foreach(i, condition; conditionals) {
					condition = condition.strip();

					string[] lineA = condition.split(" ");
					if (lineA.length == 2) {
						if (lineA[0] == "defined" || lineA[0] == "!defined") {
							string value = lineA[1].replace("(", "").replace(")", "");
							bool cond = ((value in data.defineValues) !is null) ^ (lineA[0][0] == '!');
							if (!changed) {
								ret = cond;
								changed = true;
							} else {
								// if or'd
								if (orConditions[i])
									ret |= cond;
								else
									// if and'd
									ret &= cond;
							}
							continue;
						}
					}

					if (lineA.length >= 2) {
						enum size_t[string] valueOps = ["==" : 1, "!=" : 2, ">" : 3, "<" : 4, ">=" : 5, "<=" : 6];
						string[] values = conditions.split(valueOps.keys);
						size_t[] valueOpChecks = [];

						foreach(c; conditions.splitDelimaters(valueOps.keys))
							valueOpChecks ~= valueOps.get(c, 0);

						import expression;
						size_t index = 0;
						auto a = Expression!int(values[0]);
						auto b = Expression!int(values[1]);
						final switch(valueOpChecks[0])
						{
							case 0: break;
							static foreach(op, v; valueOps)
								case v: ret = mixin("a()", op, "b()"); break;
						}
					}
				}

				return ret;
			}

			switch(line.type) {
				case PPLineType.DefineVariable:
					data.defineValues[line.defineName] = line.defineValue;
					break;
				case PPLineType.Undefine:
					data.defineValues.remove(line.defineName);
					break;
				case PPLineType.ConditionalBlock:
					if (conditionCheck(line.conditionalBlock.conditional)) {
						handledConditional ~= true;
						handleLines(line.conditionalBlock.lines);
					} else
						handledConditional ~= false;
					break;
				case PPLineType.ConditionalElseBlock:
					if (handledConditional.length > 0) {
						if (!handledConditional[$-1]) {
							if (conditionCheck(line.conditionalBlock.conditional)) {
								handledConditional[$-1] = true;
								handleLines(line.conditionalBlock.lines);
							}
						}
					}
					break;
				case PPLineType.ElseConditionBlock:
					if (handledConditional.length > 0) {
						if (!handledConditional[$-1]) {
							handleLines(line.conditionalBlock.lines);
						}
					}
					break;
				case PPLineType.EndConditionalBlock:
					if (handledConditional.length > 0)
						handledConditional.length--;
					break;
				default:
					data.output ~= handleValueSubsitutions(line.text) ~ "\n";
					break;
			}
		}
	}

	handleLines(data.file.lines);
}

unittest {
	import ctfepp.parser;
	PPFile file;
	EvaluateData edata;

	// test 1

	file = PPFile(`
#define TEST1 "hi1"

sometext
$TEST1 = TEST1

#define TEST2 "hi2"

#ifdef TEST2
	$TEST2 defined
	$TEST2 = TEST2
#else
	$TEST2 undefined
#endif

#undef TEST2

#ifdef TEST2
	$TEST2 defined
	$TEST2 = TEST2
#else
	$TEST2 undefined
#endif

#ifndef MYNAME
	#define MYNAME "Richard"
#endif

Hello MYNAME
`);

	executePPParser(file);
	edata = EvaluateData(file);
	executeEvaulator(edata);

	assert("TEST1" in edata.defineValues);
	assert(edata.defineValues["TEST1"] == "\"hi1\"");

	assert("TEST2" !in edata.defineValues);

	assert(edata.output == `sometext
$TEST1 = "hi1"
$TEST2 defined
$TEST2 = "hi2"
$TEST2 undefined
Hello "Richard"
`);

	// test2

	file = PPFile(`
#define DEF1
#define DEF2

#if defined DEF1 && defined DEF2
	YAY
#else
	BOO1
#endif

#undef DEF2

#if defined DEF1 && defined DEF2
	BOO1
#elif defined DEF1
	YAY
#elif defined DEF2
	BOO2
#else
	BOO3
#endif

#if defined DEF1 || defined DEF2
	YAY
#else
	BOO
#endif
`);

	executePPParser(file);
	edata = EvaluateData(file);
	executeEvaulator(edata);

	assert(edata.output == `YAY
YAY
YAY
`);

	// test 3

	file = PPFile(`
#if 1 == 1
	YAY
#else
	BOO
#endif

#if 1 + 1 == 2
	YAY
#else
	BOO
#endif
`);

	executePPParser(file);
	edata = EvaluateData(file);
	executeEvaulator(edata);

	import std.stdio;
	writeln(file.toString());
	writeln(edata.output);

	assert(edata.output == `YAY
YAY
`);
}
module evaluator;
import defs;
import std.string : indexOf, toLower, strip;

/**
 * 
 * TODO:
 * 		- Everything
 * 		- Support predefined macros from:
 *        http://gcc.gnu.org/onlinedocs/cpp/Standard-Predefined-Macros.html#Standard-Predefined-Macros
 * 		- Optionally support these predefined macros:
 * 		  http://gcc.gnu.org/onlinedocs/cpp/Common-Predefined-Macros.html#Common-Predefined-Macros
 */

struct EvaluateData {
	PPFile file;
	string output;
	
	string[string] defineValues;
}

pure void executeEvaulator(ref EvaluateData data) {
	bool[] hasBeenHandledConditional;
	
	void handleLines(PPLine[] lines) {
		foreach(line; lines) {
			string handleValueSubsitutions(string text) {
				string ret = text;
				
				foreach(k, v; data.defineValues) {
					if (ret.indexOf(" " ~ k ~ " ") >= 0) {
						ret = ret.replace(" " ~ k ~ " ", " " ~ v ~ " ");
					} else if (ret.length >= k.length && ret[$ - k.length .. $] == k) {
						ret = ret[0 .. $ - k.length] ~ v;
					} else if (ret.length >= k.length && ret[0 .. k.length] == k) {
						ret = v ~ ret[$ - k.length .. $];
					}
				}
				
				return ret;
			}
			
			bool conditionCheck(string conditions) {
				string[] conditionals = conditions.split("&&", "||");
				bool[] orConditions;
				
				orConditions ~= true;
				
				foreach(c; conditions.splitDelimaters("&&", "||")) {
					orConditions ~= c == "||";
				}
				
				bool ret = false;
				bool changed = false;
				
				foreach(i, condition; conditionals) {
					condition = condition.strip();
					
					string[] lineA = condition.split(" ");
					if (lineA.length == 2) {
						if (lineA[0] == "defined") {
							string value = lineA[1].replace("(", "").replace(")", "");
							
							if (!changed) {
								ret = (value in data.defineValues) !is null;
								changed = true;
							} else {
								// if or'd
								if (orConditions[i]) {
									ret = (value in data.defineValues) !is null || ret;
								} else {
									// if and'd
									ret = (value in data.defineValues) !is null && ret;
								}
							}
						} else if (lineA[0] == "!defined") {
							string value = lineA[1].replace("(", "").replace(")", "");
							
							if (!changed) {
								ret = (value in data.defineValues) is null;
								changed = true;
							} else {
								// if or'd
								if (orConditions[i]) {
									ret = (value in data.defineValues) is null || ret;
								} else {
									// if and'd
									ret = (value in data.defineValues) is null && ret;
								}
							}
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
						hasBeenHandledConditional ~= true;
						handleLines(line.conditionalBlock.lines);
					} else {
						hasBeenHandledConditional ~= false;
					}
					break;
				case PPLineType.ConditionalElseBlock:
					if (hasBeenHandledConditional.length > 0) {
						if (!hasBeenHandledConditional[$-1]) {
							if (conditionCheck(line.conditionalBlock.conditional)) {
								hasBeenHandledConditional[$-1] = true;
								handleLines(line.conditionalBlock.lines);
							}
						}
					}
					break;
				case PPLineType.ElseConditionBlock:
					if (hasBeenHandledConditional.length > 0) {
						if (!hasBeenHandledConditional[$-1]) {
							handleLines(line.conditionalBlock.lines);
						}
					}
					break;
				case PPLineType.EndConditionalBlock:
					if (hasBeenHandledConditional.length > 0) {
						hasBeenHandledConditional.length--;
					}
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
	import parser;
	PPFile file;
	EvaluateData edata;
	
	
	// test 1
	
	
	file = PPFile("""
#define TEST1 \"hi1\"

sometext
$TEST1 = TEST1

#define TEST2 \"hi2\"

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
    #define MYNAME \"Richard\"
#endif

Hello MYNAME
""");
	
	executePPParser(file);
	edata = EvaluateData(file);
	executeEvaulator(edata);
	
	assert("TEST1" in edata.defineValues);
	assert(edata.defineValues["TEST1"] == "\"hi1\"");
	
	assert("TEST2" !in edata.defineValues);
	
	assert(edata.output == """sometext
$TEST1 = \"hi1\"
$TEST2 defined
$TEST2 = \"hi2\"
$TEST2 undefined
Hello \"Richard\"
""");
	
	
	// test2
	
	
	file = PPFile("""
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
""");
	
	executePPParser(file);
	edata = EvaluateData(file);
	executeEvaulator(edata);
	
	assert(edata.output == """YAY
YAY
YAY
""");
}

private {
	pure string[] split(string text, string[] delimaters...) {
		string[] ret;
		ptrdiff_t i;
		while((i = min(text.indexOfs(delimaters))) >= 0) {
			ret ~= text[0 .. i];
			text = text[i + lengthOfIndex(text, i, delimaters) .. $];
		}
		if (text.length > 0) {
			ret ~= text;	
		}
		return ret;
	}
	
	unittest {
		string test = "abcd|efgh|ijkl";
		assert(test.split("|") == ["abcd", "efgh", "ijkl"]);
		string test2 = "abcd||efgh||ijkl";
		assert(test2.split("||") == ["abcd", "efgh", "ijkl"]);
	}
	
	pure string[] splitDelimaters(string text, string[] delimaters...) {
		string[] ret;
		ptrdiff_t i;
		while((i = min(text.indexOfs(delimaters))) >= 0) {
			ret ~= text[i .. i + lengthOfIndex(text, i, delimaters)];
			text = text[i + lengthOfIndex(text, i, delimaters) .. $];
		}
		return ret;
	}
	
	unittest {
		assert(splitDelimaters("abc|def|ghi", "|") == ["|", "|"]);
		assert(splitDelimaters("abc/def|ghi", "|", "/") == ["/", "|"]);
		assert(splitDelimaters("a && b || c", "&&", "||") == ["&&", "||"]);
	}
	
	pure string[] notEmptyElements(string[] elements) {
		string[] ret;
		
		foreach(e; elements) {
			if (e != "")
				ret ~= e;
		}
		
		return ret;
	}
	
	pure string[] notCommentedElements(string[] elements) {
		string[] ret;
		
		foreach(e; elements) {
			if (e.length >= 2 && e[0 .. 2] == "--")
				return ret;
			ret ~= e;
		}
		
		return ret;
	}
	
	pure size_t[] indexOfs(string text, string[] delimiters) {
		size_t[] ret;
		
		foreach(delimiter; delimiters) {
			ret ~= text.indexOf(delimiter);
		}
		
		return ret;
	}
	
	pure size_t lengthOfIndex(string text, size_t index, string[] delimiters) {
		foreach(delimiter; delimiters) {
			if (text.indexOf(delimiter) == index) return delimiter.length;
		}
		assert(0);
	}
	
	pure size_t min(size_t[] nums...) {
		size_t ret = size_t.max;
		
		foreach(i; nums) {
			if (i < ret) {
				ret = i;
			}
		}
		
		return ret;
	}
	
	pure string replace(string text, string oldText, string newText, bool caseSensitive = true, bool first = false) {
		string ret;
		string tempData;
		bool stop;
		foreach(char c; text) {
			if (tempData.length > oldText.length && !stop) {
				ret ~= tempData;
				tempData = "";
			}
			if (((oldText[0 .. tempData.length] != tempData && caseSensitive) || (oldText[0 .. tempData.length].toLower() != tempData.toLower() && !caseSensitive)) && !stop) {
				ret ~= tempData;
				tempData = "";
			}
			tempData ~= c;
			if (((tempData == oldText && caseSensitive) || (tempData.toLower() == oldText.toLower() && !caseSensitive)) && !stop) {
				ret ~= newText;
				tempData = "";
				stop = first;
			}
		}
		if (tempData != "") {
			ret ~= tempData;	
		}
		return ret;
	}
	
	unittest {
		string test = "Hello World!";
		test = test.replace("Hello", "Hi");
		assert(test == "Hi World!");
		
		assert(replace("Hello World!", "o", "a") == "Hella Warld!");
		assert(replace("Hello World!", "!", "#") == "Hello World#");
	}
}
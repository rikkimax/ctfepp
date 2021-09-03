module ctfepp.defs;
import ctfepp.parser;

struct PPFile {
	string text;
	PPLine[] lines;

	pure string toString(size_t indent = 0) {
		string ret = getIndent(indent) ~ "{\n";

		foreach(line; lines)
			ret ~= line.toString(indent + 1) ~ "\n";

		ret ~= getIndent(indent) ~ "}\n";
		return ret;
	}
}

enum PPLineType {
	Unknown,
	Include,
	ConditionalBlock,
	ConditionalElseBlock,
	ElseConditionBlock,
	EndConditionalBlock,
	DefineFunction,
	DefineVariable,
	Undefine
}

struct PPLine {
	PPLineType type;
	string text,

		   includeFile;

	PPConditionalBlock conditionalBlock;

	string defineName;
	string[] defineArgs;
	string defineValue;

	pure string toString(size_t indent = 0) {
		string ret;

		final switch(type) {
			case PPLineType.ConditionalBlock:
				ret = getIndent(indent) ~ "Condition: " ~ conditionalBlock.conditional ~ " {\n";

				foreach(line; conditionalBlock.lines) {
					ret ~= line.toString(indent + 1) ~ "\n";
				}

				ret ~= getIndent(indent) ~ "}\n";
				break;
			case PPLineType.ConditionalElseBlock:
				ret = getIndent(indent) ~ "Else condition: " ~ conditionalBlock.conditional ~ " {\n";

				foreach(line; conditionalBlock.lines) {
					ret ~= line.toString(indent + 1) ~ "\n";
				}

				ret ~= getIndent(indent) ~ "}\n";
				break;
			case PPLineType.Include:
				ret ~= getIndent(indent) ~ "Include: " ~ includeFile ~ "\n";
				break;
			case PPLineType.EndConditionalBlock:
				ret ~= getIndent(indent) ~ "End condition\n";
				break;
			case PPLineType.ElseConditionBlock:
				ret ~= getIndent(indent) ~ "Else condition {\n";

				foreach(line; conditionalBlock.lines) {
					ret ~= line.toString(indent + 1) ~ "\n";
				}

				ret ~= getIndent(indent) ~ "}\n";
				break;
			case PPLineType.DefineFunction:
				ret = getIndent(indent) ~ "Define function: " ~ defineName ~ "(";

				foreach(arg; defineArgs) {
					ret ~= arg ~ ",";
				}
				if (ret[$-1] == ',') ret.length--;

				ret ~= ") {\n";

				ret ~= defineValue ~ "\n";
				ret ~= getIndent(indent) ~ "}\n";
				break;
			case PPLineType.DefineVariable:
				ret = getIndent(indent) ~ "Define variable: " ~ defineName ~ " {\n";
				ret ~= defineValue ~ "\n";
				ret ~= getIndent(indent) ~ "}\n";
				break;
			case PPLineType.Undefine:
				ret ~= getIndent(indent) ~ "Undefine: " ~ defineName ~ "\n";
				break;
			case PPLineType.Unknown:
				ret = getIndent(indent) ~ "Unknown: {\n";
				ret ~= text ~ "\n";
				ret ~= getIndent(indent) ~ "}\n";
				break;
		}

		return ret;
	}
}

class PPConditionalBlock {
	PPConditionalBlock preConditionalBlock;
	string conditional;
	PPLine[] lines;

	pure this(PPConditionalBlock preConditionalBlock, string conditional) {
		this.preConditionalBlock = preConditionalBlock;
		this.conditional = conditional;
	}
}

pure string getIndent(size_t size) nothrow {
	string ret;

	while (size-- > 0)
		ret ~= "    ";

	return ret;
}

package @safe:

import std.string : indexOf, toLower;

pure string[] split(string text, string[] delimaters...) {
	string[] ret;
	ptrdiff_t i;
	while((i = min(text.indexOfs(delimaters))) >= 0) {
		ret ~= text[0 .. i];
		text = text[i + lengthOfIndex(text, i, delimaters) .. $];
	}
	if (text.length > 0)
		ret ~= text;
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
		if (e.length >= 2 && e[0 .. 2] == "//")
			return ret;
		ret ~= e;
	}

	return ret;
}

pure size_t[] indexOfs(string text, string[] delimiters) {
	size_t[] ret;

	foreach(delimiter; delimiters)
		ret ~= text.indexOf(delimiter);

	return ret;
}

pure size_t lengthOfIndex(string text, size_t index, string[] delimiters) {
	foreach(delimiter; delimiters) {
		if (text.indexOf(delimiter) == index) return delimiter.length;
	}
	assert(0);
}

pure size_t min(size_t[] nums...) {
	auto ret = size_t.max;

	foreach(i; nums) {
		if (i < ret)
			ret = i;
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
	if (tempData != "")
		ret ~= tempData;
	return ret;
}

unittest {
	auto test = "Hello World!";
	test = test.replace("Hello", "Hi");
	assert(test == "Hi World!");

	assert(replace("Hello World!", "o", "a") == "Hella Warld!");
	assert(replace("Hello World!", "!", "#") == "Hello World#");
}
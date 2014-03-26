module defs;
import parser;

struct PPFile {
	string text;
	PPLine[] lines;
	
	pure string toString(size_t indent = 0) {
		string ret;
		ret = getIndent(indent) ~ "{\n";
		
		foreach(line; lines) {
			ret ~= line.toString(indent + 1) ~ "\n";
		}
		
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
	string text;
	
	string includeFile;
	
	PPConditionalBlock conditionalBlock;
	
	string defineName;
	string[] defineArgs;
	string defineValue;
	
	pure string toString(size_t indent = 0) {
		string ret;
		
		switch(type) {
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
			default:
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

pure string getIndent(size_t size) {
	string ret;
	
	for (size_t i=0; i < size; i++) {
		ret ~= "    ";
	}
	
	return ret;
}
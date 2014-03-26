module parser;
import defs;
import std.string : splitLines, strip, indexOf, toLower, join;
import std.conv : to;

/**
 * Parses a file to be macro preprocessed.
 * Turns it into a tokenised format.
 * 
 * TODO:
 * 		- Support multilined defines
 */
pure void executePPParser(ref PPFile data) {
	PPConditionalBlock currentConditionalBlock;
	
L1: foreach(line; data.text.splitLines()) {
		line = line.strip();
		string[] lineA = line.split(" ", "\t").notEmptyElements().notCommentedElements();
		if (lineA.length == 0) continue;
		
		void removeFirstLineA() {
			if (lineA.length > 1)
				lineA = lineA[1 .. $];
			else
				lineA = [];
		}
		
		void addLine(PPLine line) {
			if (currentConditionalBlock is null) {
				data.lines ~= line;
			} else {
				currentConditionalBlock.lines ~= line;
			}
		}
		
		if (lineA[0] == "#include" && lineA.length > 0) {
			if (lineA.length > 1 &&
			    (lineA[1][0] == '<' && lineA[1][$-1] == '>') ||
			    (lineA[1][0] == '"' && lineA[1][$-1] == '"')) {
				addLine(PPLine(PPLineType.Include, line, lineA[1][1 .. $-1]));
				continue;
			}
		}
		
		if (lineA.length > 1) {
			if (lineA[0] == "#if") {
				removeFirstLineA();
				auto cline = PPLine(PPLineType.ConditionalBlock, line);
				cline.conditionalBlock = new PPConditionalBlock(currentConditionalBlock, lineA.join(" ").removeCommentedSections);
				addLine(cline);
				currentConditionalBlock = cline.conditionalBlock;
				continue;
			} else if (lineA[0] == "#elif") {
				removeFirstLineA();
				auto cline = PPLine(PPLineType.ConditionalElseBlock, line);
				cline.conditionalBlock = new PPConditionalBlock(currentConditionalBlock !is null ? currentConditionalBlock.preConditionalBlock : null, lineA.join(" ").removeCommentedSections);
				addLine(cline);
				currentConditionalBlock = cline.conditionalBlock;
				continue;
			} else if (lineA[0] == "#ifdef") {
				lineA[0] = "defined";
				auto cline = PPLine(PPLineType.ConditionalBlock, line);
				cline.conditionalBlock = new PPConditionalBlock(currentConditionalBlock, lineA.join(" ").removeCommentedSections);
				addLine(cline);
				currentConditionalBlock = cline.conditionalBlock;
				continue;
			} else if (lineA[0] == "#undef") {
				auto cline = PPLine(PPLineType.Undefine, line);
				cline.defineName = lineA[1];
				
				addLine(cline);
				continue;
			}
		}
		
		if (lineA.length > 2) {
			if (lineA[0] == "#define") {
				removeFirstLineA();
				if (lineA[0].indexOf("(") > 0 && lineA[0][$-1] == ')') {
					auto cline = PPLine(PPLineType.DefineFunction, line);
					cline.defineName = lineA[0][0 .. lineA[0].indexOf("(")];
					foreach(arg; lineA[0][lineA[0].indexOf("(") + 1 .. $-1].split(",")) {
						cline.defineArgs ~= arg.strip();
					}
					cline.defineValue = lineA[1 .. $].join(" ").removeCommentedSections;
					addLine(cline);
				} else {
					auto cline = PPLine(PPLineType.DefineVariable, line);
					cline.defineName = lineA[0];
					cline.defineValue = lineA[1 .. $].join(" ").removeCommentedSections;
					addLine(cline);
				}
				continue;
			}
		}
		
		if (lineA[0] == "#else") {
			auto cline = PPLine(PPLineType.ElseConditionBlock, line);
			
			if (currentConditionalBlock !is null) {
				currentConditionalBlock = currentConditionalBlock.preConditionalBlock;
			} else {
				currentConditionalBlock = null;
			}
			
			if (currentConditionalBlock !is null) {
				if (currentConditionalBlock.preConditionalBlock !is null) {
					cline.conditionalBlock = new PPConditionalBlock(currentConditionalBlock.preConditionalBlock, "");
				} else {
					cline.conditionalBlock = new PPConditionalBlock(null, "");
				}
			} else {
				cline.conditionalBlock = new PPConditionalBlock(null, "");
			}
			addLine(cline);
			currentConditionalBlock = cline.conditionalBlock;
			continue;
		}
		
		if (lineA[0] == "#endif") {
			if (currentConditionalBlock !is null) {
				currentConditionalBlock = currentConditionalBlock.preConditionalBlock;
			} else {
				currentConditionalBlock = null;
			}
			addLine(PPLine(PPLineType.EndConditionalBlock, line));
			continue;
		}
		
		addLine(PPLine(PPLineType.Unknown, line));
	}
}

pure string removeCommentedSections(string text) {
	return text;
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
}